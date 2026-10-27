#!/usr/bin/env python3
"""
generar_sql_tramites.py  (v2 - con deduplicacion contra la BD)
-----------------------------------------------------------------------
Recorre la pagina "tramites-y-servicios" de las 20 entidades definidas
en ENTIDADES_PRINCIPALES_SIGLAS, extrae TODOS los tramites/servicios
listados ahi (con paginacion) y genera un archivo .sql con sentencias
INSERT compatibles con tu esquema (bd/bd_tramites.sql).

NUEVO en v2:
- DEDUPLICACION AUTOMATICA contra bd_tramites.sql Y contra el propio
  tramites_generados.sql (si re-corres el script, lo que ya existe NO
  se vuelve a insertar). Tres claves de dedup:
    1. id numerico de gob.pe (gob.pe/99724-actualizar-pin... -> 99724)
    2. URL normalizada (sin scheme, sin www, sin slash final)
    3. nombre normalizado (sin acentos/puntuacion, minusculas),
       comparado entidad por entidad
  Con esto: cero verificacion manual de URLs, cero duplicados en la BD.
- REQUISITOS LIMPIOS: se descartan los items basura que venian siendo
  scrapeados como "requisitos" (Facebook/Twitter/Whatsapp/Email/etc, la
  lista de redes sociales del footer de gob.pe) y los textos menores a
  8 caracteres. Si la pagina no detalla requisitos REALES, NO se listan:
  no se generan filas de requisito ni placeholders.
- PAGINACION: la pagina "tramites-y-servicios" se recorre hasta 5 paginas
  (?page=2,3,...), no solo la primera.
- COSTO "gratuito": si la pagina dice "gratuito/gratis/sin costo", el
  costo se asume 0.00 CONFIABLE (antes entraba como "verificar TUPA").

LO QUE SIGUE SIENDO HEURISTICO (y por que no se puede evadir sin Leer
la pagina a mano o una API que gob.pe no ofrece):
- descripcion       -> meta description de la pagina (texto real del
                       sitio, no inventado; viene truncado con "..." por
                       el propio gob.pe)
- tipo_contenido    -> por keyword del nombre (4 tipos validos del
                       esquema: TRAMITE, SERVICIO, REPORTE, GUIA; senales
                       de TUPA/aranceles/pagos suben a TRAMITE)
- modalidad         -> por keyword del texto
- etiquetas         -> por keyword, con lista auditada a mano
Todo lo asumido sale con un comentario "-- REVISAR:" para que decidas,
pero NADA requiere edicion manual para que el INSERT funcione.

OJO: asume el esquema NORMALIZADO con tabla `requisito` ligada a
`tramite` con ON DELETE CASCADE (bd/bd_tramites.sql ya lo tiene).

El .sql generado usa `SET @tid = LAST_INSERT_ID();` justo despues de
cada INSERT INTO tramite, y reusa @tid para requisito Y etiqueta.

Dependencias: pip install requests beautifulsoup4
"""

import csv
import os
import re
import time
import unicodedata
from urllib.parse import urljoin, urlparse

import requests
from bs4 import BeautifulSoup

# ------------------------------------------------------------------
# Rutas. La carpeta Proyecto-Hombre-Maquina es hermana de este script
# (D:\ciclo 8\Interaccion Hombre-Maquina\<script> y ...\Proyecto-Hombre-Maquina\bd\)
# ------------------------------------------------------------------
CARPETA_SCRIPT = os.path.dirname(os.path.abspath(__file__))


def _buscar_seed() -> str:
    """Resuelve bd/bd_tramites.sql desde el layout donde viva el script
    (carpeta padre del repo, raiz del repo o dentro de bd/)."""
    candidatos = [
        os.path.join(CARPETA_SCRIPT, "Proyecto-Hombre-Maquina", "bd", "bd_tramites.sql"),
        os.path.join(CARPETA_SCRIPT, "bd", "bd_tramites.sql"),
        os.path.join(os.path.dirname(CARPETA_SCRIPT), "bd", "bd_tramites.sql"),
    ]
    for c in candidatos:
        if os.path.isfile(c):
            return c
    return candidatos[0]


SQL_SEMBRADOS = _buscar_seed()
SQL_GENERADOS_PROPIO = "tramites_generados.sql"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "es-PE,es;q=0.9",
}
PAUSA_ENTRE_REQUESTS = 1.2
TIMEOUT = 20
GOBPE_BASE = "https://www.gob.pe"
FUNCIONARIOS_CSV_URL = "https://funcionarios.peruencifras.pe/data/20260908-funcionarios-peru.csv"
DOMINIOS_IGNORAR = {
    "facebook.com", "twitter.com", "x.com", "whatsapp.com", "wa.me",
    "api.whatsapp.com", "instagram.com", "youtube.com", "tiktok.com",
    "linkedin.com", "t.me", "maps.google.com", "goo.gl", "docs.google.com",
    "drive.google.com", "forms.gle", "microsoft.com", "google.com",
    "apple.com", "adobe.com",
}

# Verbos/frases que SI indican un boton de accion real ("ve y hazlo aqui"),
# no un enlace incidental de la pagina (compartir, mapa, descarga de driver).
# Solo un link que matchee esto se acepta como url_oficial externa.
PATRON_CTA = re.compile(
    r"ir a|ir al|realizar el tr[aá]mite|iniciar tr[aá]mite|ingres[ae] (a|al)|"
    r"accede(r)? (a|al)|acceder aqu[ií]|ir al sitio|plataforma virtual|"
    r"portal (de|del)|haz clic aqu[ií]|ver plataforma|ir a la plataforma",
    re.IGNORECASE,
)

# Heuristica de clasificacion por palabras del NOMBRE del tramite/servicio.
# SOLO 4 tipos validos (los sembrados en tipo_contenido): TRAMITE, SERVICIO,
# REPORTE, GUIA. No existe DOCUMENTO (daria error de FK).
PATRON_GUIA = re.compile(
    r"\bgu[ií]a\b|\bmanual(?:es)?\b|c[oó]mo |paso a paso|\btutorial\b|"
    r"\bpreguntas? (más )?frecuentes\b|\bdudas frecuentes\b|aprende(r)?|"
    r"inf[oó]rmate|\bdescubre\b|orientaci[oó]n|consejo(s)? pr[aá]ctico|"
    r"qu[eé] debes saber|\bconoce\b|\bconocer el proceso",
    re.IGNORECASE,
)
PATRON_REPORTE = re.compile(
    r"\breporte(s)?\b|\bestad[ií]stica(s)?\b|resultados? de|\bbolet[ií]n(es)?\b|"
    r"\binforme(s)?\b|cifras (de |del |sobre )?|\bdatos abiertos\b|"
    r"\bhist[oó]rico(nacional)? de resultados|observatorio|rendici[oó]n de cuentas|"
    r"anuario|\bcompendio\b|monitoreo",
    re.IGNORECASE,
)
VERBOS_TRAMITE = re.compile(
    r"^(solicitar|obtener|tramitar|renovar|inscrib|registrar|presentar|"
    r"actualizar|denunciar|declarar|pagar|rectificar|duplicar|expedir|emitir)",
    re.IGNORECASE,
)
VERBOS_SERVICIO = re.compile(
    r"^(consultar|acceder|verificar|revisar|ver |buscar|validar|comprobar)",
    re.IGNORECASE,
)

# Verbs Most "Gestion" (get things done / modify your data) seen throughout gob.pe,
# PART OF THE NAME (not necessarily at the beginning).
# Some examples: "Block my Electronic Passport", "Complete sworn declaration...",
# "Make your pre-registration in MigraCheck", "Create your user in Migracheck".
PATRON_ACCION_TRAMITE = re.compile(
    r"\b(bloquear|reponer|duplicar|renovar|tramitar|solicitar|inscribir|registrar|"
    r"declarar|declaraci[oó]n jurada|presentar|pagar|obtener|certificar|emisi[oó]n|"
    r"expedir|emitir|rectificar|actualizar|reprogramar|afiliar|acreditar|"
    r"preregistro|pre-registro|denunciar|agendar|realiza(r)? tu|crea(r)? tu|"
    r"cambiar|cambiar contrase|devolver|reclamar|apelar)\b",
    re.IGNORECASE,
)
# Signals in the text that REAL KEYS: TUPA, tel. real, "make your payment"
SENALES_TRAMITE_TEXTO = re.compile(
    r"\b(tupa|arancel|tarifa del tr[aá]mite|realiza tu pago|pago del tr[aá]mite|"
    r"formul(iar)? tu (solicitud|declaraci[oó]n))\b",
    re.IGNORECASE,
)
# Contenido REAL de la pagina (texto del cuerpo, no solo el nombre):
# guias con pasos, reportes con datos/fuente de datos del pie de gob.pe.
PATRON_GUIA_CONTENIDO = re.compile(
    r"qu[eé] debes (hacer|saber|conocer)|antes de empezar|\bpaso \d\b|"
    r"simulador de|instrucciones para (completar|llenar|presentar)",
    re.IGNORECASE,
)
PATRON_REPORTE_CONTENIDO = re.compile(
    r"fuente de datos|datos abiertos|\bestad[ií]stica(s)? del|"
    r"observatorio (nacional|de)|rendici[oó]n de cuentas|monitoreo",
    re.IGNORECASE,
)

# Etiquetado automatico por keyword. RUIDO se limpia ANTES de matchear.
RUIDO_ETIQUETAS = re.compile(r"unidades? impositivas? tributarias?|\buit\b", re.IGNORECASE)
TAGS_CONOCIDOS = {
    "dni": r"\bdni\b",
    "identidad": r"reconocimiento de paternidad|constancia de (nacimiento|matrimonio|defunci[oó]n)|acta de (nacimiento|matrimonio|defunci[oó]n)|libreta electoral",
    "citas": r"\bcita(s)?\b|agendar",
    "pagos": r"\bpago(s)?\b|\byape\b|agente bcp|p[aá]galo|ticket",
    "reclamos": r"reclam|denuncia",
    "transparencia": r"informaci[oó]n p[uú]blica|transparencia",
    "impuestos": r"\bimpuesto(s)?\b|tributari|\bigv\b|\brenta\b|\brus\b|\bruc\b|declarar y pagar",
    "aduanas": r"aduaner|despacho aduanero|teledespacho",
    "salud": r"\bsalud\b|essalud|m[eé]dic|padomi|acreditaci[oó]n de.*seguro",
    "vehicular": r"veh[ií]cul|\btiv\b|inmatriculaci[oó]n",
    "registros": r"\bregistr|partida (registral)?|directorio nacional de personas jur[ií]dicas",
    "empresas": r"\bempresa(s)?\b|persona jur[ií]dica|raz[oó]n social",
    "contrataciones": r"convocatoria|licitaci[oó]n|procedimiento de selecci[oó]n",
    "plataforma-virtual": r"plataforma|mesa de partes virtual|buz[oó]n sol|\bchat\b|repositorio institucional|cat[aá]logo en l[ií]nea",
    "capacitacion": r"certificaci[oó]n de competencias|capacitaci[oó]n|evaluaci[oó]n de competencias",
    "electoral": r"electoral|elecciones",
    "seguridad": r"pin de seguridad|robo de",
    "pasaporte": r"pasaporte",
    "migraciones": r"migracion|extranjer",
    "educacion": r"educaci[oó]n|estudios|t[ií]tulo|grado acad[eé]mico",
}

# Requisitos-basura: items de una sola palabra corresponden a la lista de
# redes sociales del footer de gob.pe, NO a requisitos del tramite.
REQUISITO_BASURA = re.compile(r"^\s*(facebook|twitter|whatsapp|email|linkedin|youtube|x|instagram|copiar enlace|whatsapp\s?\d*)\s*$", re.IGNORECASE)

# Techo por entidad para no correr horas sin control.
MAX_TRAMITES_POR_ENTIDAD = 25
MAX_PAGINAS_LISTA = 5

# Entidades ya sembradas en bd/bd_tramites.sql (no se re-insertan en la
# tabla entidad, solo se usan sus tramites)
ENTIDADES_YA_SEMBRADAS = {"SUNAT", "MINEDU", "RENIEC", "ESSALUD", "SUNARP", "MIGRACIONES"}

# Las 20 entidades mas usadas por el ciudadano peruano. El SLUG real de
# cada una se resuelve desde entidades_gobpe.csv por sigla.
ENTIDADES_PRINCIPALES_SIGLAS = [
    "RENIEC", "SUNAT", "MIGRACIONES", "ESSALUD", "SUNARP", "MINEDU",
    "MTC", "MININTER", "PJ", "MINJUS", "SIS", "MINSA", "ONP", "MIDIS",
    "SUNAFIL", "MTPE", "INDECOPI", "SBS", "JNE", "ONPE",
]

ARCHIVO_ENTIDADES = "entidades_gobpe.csv"
ARCHIVO_SQL_SALIDA = "tramites_generados.sql"
ARCHIVO_PROGRESO = "entidades_completadas.txt"


# ------------------------------------------------------------------
# NORMALIZACION Y DEDUPLICACION
# ------------------------------------------------------------------

def normalizar_texto(s: str) -> str:
    """Minusculas, sin acentos, solo [a-z0-9 ] y espacios colapsados."""
    s = unicodedata.normalize("NFKD", s or "")
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    return re.sub(r"\s+", " ", re.sub(r"[^a-z0-9]+", " ", s)).strip()


def clave_url(url: str) -> str:
    """Clave estable de URL: sin scheme, sin www inicial, sin slash final,
    minusculas (dominio). Mantiene query string: es esencial para apps reales."""
    u = (url or "").strip().lower()
    u = re.sub(r"^https?://", "", u)
    if u.startswith("www."):
        u = u[4:]
    return u.rstrip("/")


def id_gobpe(url: str):
    """gob.pe/99724-actualizar-pin... -> '99724'. Es el ID estable del
    trámite en gob.pe y NO cambia aunque cambie el slug."""
    m = re.search(r"gob\.pe/(\d+)-", (url or "").lower())
    return m.group(1) if m else None


def extraer_claves_existentes(*rutas_sql) -> tuple[set, set, set]:
    """Recorre los .sql existentes y devuelve (ids_gobpe, urls, nombres)
    ya insertados. nombres = pares (SIGLA, nombre_normalizado)."""
    ids, urls, nombres = set(), set(), set()
    patron_url = re.compile(r"'(https?://[^'\s]+)'")
    patron_bloque = re.compile(r"INSERT INTO tramite\s*\(.*?\);", re.DOTALL)
    patron_sigla = re.compile(r"siglas\s*=\s*'([^']+)'")
    patron_nombre = re.compile(
        r"WHERE nombre\s*=\s*'[A-Z]+'\)\s*,\s*'((?:[^']|'')*)'", re.DOTALL
    )
    for ruta in rutas_sql:
        if not ruta or not os.path.exists(ruta):
            continue
        with open(ruta, encoding="utf-8") as f:
            texto = f.read()
        for url in patron_url.findall(texto):
            urls.add(clave_url(url))
            g = id_gobpe(url)
            if g:
                ids.add(g)
        for bloque in patron_bloque.findall(texto):
            m_sigla, m_nombre = patron_sigla.search(bloque), patron_nombre.search(bloque)
            if m_sigla and m_nombre:
                nombres.add((m_sigla.group(1), normalizar_texto(m_nombre.group(1).replace("''", "'"))))
                # el nombre tambien da un id si es pagina gob.pe (no siempre)
    return ids, urls, nombres


class Deduper:
    """Guarda las claves de lo ya insertado (BD sembrada + este run) y
    consulta si (url Pagina, url Resuelta, nombre, sigla) ya existe.
    Tambien registra claves nuevas para dedup intra-run."""

    def __init__(self):
        self.ids, self.urls, self.nombres = extraer_claves_existentes(
            SQL_SEMBRADOS, archivo_propio()
        )

    def ya_existe(self, sigla: str, nombre: str, *urls: str) -> str | None:
        """Devuelve razon si es duplicado, o None si es nuevo.
        Chequea id gob.pe y URL de CADA url pasada + nombre normalizado."""
        for u in urls:
            if not u:
                continue
            g = id_gobpe(u)
            if g and g in self.ids:
                return f"id gob.pe {g} ya insertado"
            c = clave_url(u)
            if c in self.urls:
                return "url ya insertada"
        nombre_norm = normalizar_texto(nombre)
        if len(nombre_norm) >= 12 and (sigla, nombre_norm) in self.nombres:
            return "mismo nombre ya insertado en esa entidad"
        return None

    def registrar(self, sigla: str, nombre: str, *urls: str):
        nombre_norm = normalizar_texto(nombre)
        if len(nombre_norm) >= 12:
            self.nombres.add((sigla, nombre_norm))
        for u in urls:
            if not u:
                continue
            g = id_gobpe(u)
            if g:
                self.ids.add(g)
            self.urls.add(clave_url(u))


def archivo_propio() -> str | None:
    """tramites_generados.sql de este mismo script (acumulativo)."""
    ruta = os.path.join(CARPETA_SCRIPT, SQL_GENERADOS_PROPIO)
    return ruta if os.path.exists(ruta) else None


# ------------------------------------------------------------------
# EXTRACCION
# ------------------------------------------------------------------

def calcular_etiquetas(nombre: str, descripcion: str) -> list[str]:
    texto = RUIDO_ETIQUETAS.sub(" ", f"{nombre} {descripcion}".lower())
    return [tag for tag, patron in TAGS_CONOCIDOS.items() if re.search(patron, texto, re.IGNORECASE)]


def _get(url: str):
    try:
        r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
    except requests.RequestException as e:
        print(f"  [ERROR conexion] {url} -> {e}")
        return None
    if r.status_code != 200:
        print(f"  [HTTP {r.status_code}] {url}")
        return None
    return r


def sql_escapar(texto: str) -> str:
    return (texto or "").replace("'", "''").strip()


PALABRAS_CORTES = {
    "y", "o", "e", "u", "ni", "que", "de", "del", "la", "el", "los", "las",
    "un", "una", "con", "para", "por", "sin", "a", "en", "al", "como", "se",
    "su", "sus", "es", "son", "pero", "más", "mas", "entre", "sobre", "través",
}


def recortar_logico(texto: str, max_chars: int = 700) -> str:
    """Corta al final de frase o clausula logica. JAMAS sale con '...':
    se recorta en el ultimo punto/punto y coma y se retrocede si quedo
    colgando una palabra de enlace (y, de, para, con, ...) o un fragmento
    viñeta pegado ('Si.', 'Esta.')."""
    t = re.sub(r"\s+", " ", (texto or "").strip())
    if not t:
        return ""
    # frases pegadas por colapsado de listas: "personales.Si" -> "personales. Si"
    # (considera letras, digitos, parentesis y corchetes antes del punto)
    t = re.sub(r"([\wáéíóúñ\)\]])\.([A-ZÁÉÍÓÚÑ])", r"\1. \2", t)
    # dos puntos pegados a la siguiente Mayuscula: "casos:Si" -> "casos: Si"
    t = re.sub(r":([A-ZÁÉÍÓÚÑ])", r": \1", t)
    # puntos suspensivos finales (truncamiento de gob.pe) se eliminan;
    # el cierre lo decide la funcion final, nunca con '...'
    t = re.sub(r"(\s*(\.\.\.|…))+$", "", t).strip()
    t = t.rstrip(",;:- ")
    if len(t) > max_chars:
        trozo = t[:max_chars]
        pos = max(trozo.rfind(". "), trozo.rfind("; "), -1)
        if pos >= 200:
            t = trozo[:pos + 1].strip()
        else:
            pos = trozo.rfind(" ")
            t = trozo[:max(pos, 0)].rstrip(",;:- ")
    # retrocede frases mientras la ultima frase sea un fragmento colgante
    # (viñeta aislada o conector suelto) y mientras quede frase previa
    frases = [f.strip() for f in re.split(r"(?<=[.!?;:]) +", t) if f.strip()]
    COLGANTE = re.compile(
        r"^(si|esta$s?|estos|estas|también|tambien|además|adicionalmente|"
        r"como|asimismo|por ejemplo|no olvide|recuerd|puedes?|echa un vistazo|"
        r"o)\b|^[a-z]{1,3}$",
        re.IGNORECASE,
    )
    saltos = 0
    while len(frases) > 1 and saltos < 4:
        utl = frases[-1]
        es_corta = len(utl) < 25
        es_colgante = bool(COLGANTE.match(utl))
        if es_corta or es_colgante:
            frases.pop()
            saltos += 1
        else:
            break
    t = "; ".join(frases) if False else " ".join(frases)
    # cierre logico: si quedo una frase-auxiliar terminada en ':' (lista
    # colapsada cuyo contenido fue descartado), cierra con punto
    if t and t[-1] == ":":
        t = t.rstrip(": ") + "."
    if t and t[-1] not in ".!?:\"'’" + chr(8221) + chr(8217) + chr(8222) + chr(8220):
        t = t.rstrip(",;: - ") + "."
    return t


def construir_descripcion(desc_meta: str, parrafos: list[str]) -> str:
    """Descripcion final: usa meta de gob.pe; si viene truncada ('...'),
    busca el parrafo del cuerpo que empiece igual y usa su texto completo.
    Siempre termina de forma logica (recortar_logico), nunca en '...'."""
    base = (desc_meta or "").strip()
    if not base and parrafos:
        base = parrafos[0]
    if not base:
        return ""
    base = re.sub(r"\s+", " ", base).strip()
    if re.search(r"(\.\.\.|…)$", base):
        prefijo = normalizar_texto(re.sub(r"(\.\.\.|…)$", "", base))[:50]
        for p in parrafos:
            if normalizar_texto(p).startswith(prefijo) and len(normalizar_texto(p)) > len(normalizar_texto(base)):
                base = re.sub(r"\s+", " ", p).strip()
                break
    return recortar_logico(base)


def exportar_entidades_gobpe(destino: str) -> None:
    print("Descargando dataset de instituciones (Peru en Cifras)...")
    r = _get(FUNCIONARIOS_CSV_URL)
    if r is None:
        raise SystemExit("No se pudo descargar el dataset de instituciones.")
    r.encoding = "utf-8-sig"
    lector = csv.DictReader(r.text.splitlines(), delimiter=";")
    vistos = {}
    patron_slug = re.compile(r"/institucion/([a-z0-9-]+)/")
    for fila in lector:
        m = patron_slug.search(fila.get("ficha_gobpe", "") or "")
        if not m:
            continue
        slug = m.group(1)
        if slug not in vistos:
            vistos[slug] = {
                "slug": slug,
                "institucion": fila.get("institucion", "").strip(),
                "sigla": fila.get("sigla", "").strip(),
                "sector": fila.get("sector", "").strip(),
            }
    with open(destino, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["slug", "institucion", "sigla", "sector"])
        w.writeheader()
        w.writerows(vistos.values())
    print(f"{len(vistos)} instituciones -> {destino}")


def cargar_entidades() -> dict:
    ruta = os.path.join(CARPETA_SCRIPT, ARCHIVO_ENTIDADES)
    if not os.path.exists(ruta):
        exportar_entidades_gobpe(ruta)
    with open(ruta, encoding="utf-8") as f:
        return {row["sigla"].upper(): row for row in csv.DictReader(f) if row.get("sigla")}


def obtener_items_pagina(slug: str) -> list[tuple[str, str]]:
    """Recorre la lista de tramites-y-servicios con PAGINACION
    (?page=2,3,...) hasta MAX_PAGINAS_LISTA o hasta que una pagina
    devuelva 0 items nuevos. Respeta MAX_TRAMITES_POR_ENTIDAD."""
    for variante in ("tramites-y-servicios", "tramites"):
        items, vistos = [], set()
        for page in range(1, MAX_PAGINAS_LISTA + 1):
            url = f"{GOBPE_BASE}/institucion/{slug}/{variante}"
            if page > 1:
                url += f"?page={page}"
            r = _get(url)
            time.sleep(PAUSA_ENTRE_REQUESTS)
            if r is None:
                break
            soup = BeautifulSoup(r.text, "html.parser")
            nuevos = 0
            for a in soup.find_all("a", href=re.compile(r"^/\d+-[a-z0-9-]+")):
                texto = a.get_text(strip=True)
                href = urljoin(GOBPE_BASE, a["href"])
                if texto and href not in vistos:
                    vistos.add(href)
                    items.append((texto, href))
                    nuevos += 1
            if nuevos == 0:
                break
        if items:
            return items[:MAX_TRAMITES_POR_ENTIDAD]
    return []


def limpiar_requisitos(puntos: list[str]) -> list[str]:
    """Descarta requisitos-basura (redes sociales del footer) y textos
    de menos de 8 caracteres. Vacia = no se listan requisitos."""
    return [
        p for p in puntos
        if len(p) >= 8 and not REQUISITO_BASURA.search(p)
    ]


def extraer_detalle(url_detalle: str) -> dict:
    """Devuelve descripcion, requisitos, url_oficial, tipo, modalidad,
    costo -- cada uno con su nivel de confianza documentado arriba."""
    r = _get(url_detalle)
    time.sleep(PAUSA_ENTRE_REQUESTS)
    resultado = {
        "descripcion": "", "requisitos": [], "url_oficial": url_detalle,
        "url_confiable": False,
        "tipo": "SERVICIO", "tipo_confiable": False,
        "modalidad": "VIRTUAL", "modalidad_confiable": False,
        "costo": 0.00, "costo_confiable": False,
    }
    if r is None:
        return resultado

    soup = BeautifulSoup(r.text, "html.parser")
    texto_completo = soup.get_text(" ", strip=True)

    # descripcion: meta de gob.pe; si viene truncada, se completa con el
    # parrafo del cuerpo que la empieza. SIEMPRE termina logica, nunca '...'
    parrafos = [
        p.get_text(" ", strip=True) for p in soup.find_all("p")
        if len(p.get_text(strip=True)) > 80
    ]
    meta = soup.find("meta", attrs={"name": "description"})
    desc_meta = (meta.get("content") or "").strip() if meta else ""
    resultado["descripcion"] = construir_descripcion(desc_meta, parrafos)

    # requisitos: heading h2-h4 que contenga "requisito" + lista siguiente,
    # limpiada de items-basura (redes sociales del footer).
    heading = soup.find(
        lambda tag: tag.name in ("h2", "h3", "h4")
        and "requisito" in tag.get_text(strip=True).lower()
    )
    if heading:
        lista = heading.find_next(["ul", "ol"])
        if lista:
            puntos = [li.get_text(strip=True) for li in lista.find_all("li") if li.get_text(strip=True)]
            resultado["requisitos"] = limpiar_requisitos(puntos)
    # si no hay requisitos reales, QUEDAN VACIOS: no se insertan filas ni
    # placeholders ("Ver requisitos en la pagina oficial." ya no se genera).

    # enlace externo oficial -- SOLO si el link tiene pinta de boton de
    # accion real (PATRON_CTA en su texto visible). Si no hay CTA claro,
    # el default seguro es la propia pagina de gob.pe.
    for a in soup.find_all("a", href=True):
        href = a["href"].strip()
        texto_link = a.get_text(strip=True)
        if not re.match(r"^https?://[^\s<>\"']+$", href):
            continue  # descarta hrefs con markup roto
        dominio = urlparse(href).netloc.replace("www.", "")
        if dominio == "gob.pe" or dominio in DOMINIOS_IGNORAR:
            continue  # "gob.pe" a secas es el portal; reniec.gob.pe SI es valido
        if not PATRON_CTA.search(texto_link):
            continue  # link externo incidental, no el CTA
        resultado["url_oficial"] = href
        resultado["url_confiable"] = True
        break

    # tipo: 5 categorias. REPORTE/DOCUMENTO/GUIA por keyword del nombre;
    # TRAMITE/SERVICIO por el verbo inicial del nombre.
    nombre_item = soup.find("h1")
    nombre_item = nombre_item.get_text(strip=True) if nombre_item else ""
    if PATRON_GUIA.search(nombre_item):
        resultado["tipo"], resultado["tipo_confiable"] = "GUIA", True
    elif PATRON_REPORTE.search(nombre_item):
        resultado["tipo"], resultado["tipo_confiable"] = "REPORTE", True
    elif (PATRON_ACCION_TRAMITE.search(nombre_item)
          or SENALES_TRAMITE_TEXTO.search(baja)):
        resultado["tipo"], resultado["tipo_confiable"] = "TRAMITE", True
    elif PATRON_GUIA_CONTENIDO.search(baja):
        resultado["tipo"], resultado["tipo_confiable"] = "GUIA", True
    elif PATRON_REPORTE_CONTENIDO.search(baja):
        resultado["tipo"], resultado["tipo_confiable"] = "REPORTE", True
    elif VERBOS_TRAMITE.search(nombre_item.strip()):
        resultado["tipo"], resultado["tipo_confiable"] = "TRAMITE", True
    elif VERBOS_SERVICIO.search(nombre_item.strip()):
        resultado["tipo"], resultado["tipo_confiable"] = "SERVICIO", True

    baja = texto_completo.lower()

    # modalidad
    if "semipresencial" in baja:
        resultado["modalidad"], resultado["modalidad_confiable"] = "SEMIPRESENCIAL", True
    elif "presencial" in baja:
        resultado["modalidad"], resultado["modalidad_confiable"] = "PRESENCIAL", True
    elif "virtual" in baja:
        resultado["modalidad"], resultado["modalidad_confiable"] = "VIRTUAL", True

    # costo "gratuito" explícito en el texto => 0.00 CONFIABLE
    if re.search(r"\b(gratuit|es gratis|sin costo)", baja):
        resultado["costo"], resultado["costo_confiable"] = 0.00, True
    else:
        # patrones "S/ 12.00" / "S/. 12"
        m = re.search(r"S/\.?\s?(\d+(?:[.,]\d{1,2})?)", texto_completo)
        if m:
            resultado["costo"] = float(m.group(1).replace(",", "."))
            resultado["costo_confiable"] = True

    return resultado


def cargar_completadas() -> set:
    ruta = os.path.join(CARPETA_SCRIPT, ARCHIVO_PROGRESO)
    if not os.path.exists(ruta):
        return set()
    with open(ruta, encoding="utf-8") as f:
        return {l.strip() for l in f if l.strip()}


def marcar_completada(sigla: str) -> None:
    ruta = os.path.join(CARPETA_SCRIPT, ARCHIVO_PROGRESO)
    with open(ruta, "a", encoding="utf-8") as f:
        f.write(sigla + "\n")


def generar_sql():
    entidades = cargar_entidades()
    completadas = cargar_completadas()
    dedup = Deduper()
    n_dup_total = 0
    ruta_salida = os.path.join(CARPETA_SCRIPT, ARCHIVO_SQL_SALIDA)
    primera_vez = not os.path.exists(ruta_salida)
    print(f"Dedup inicial: {len(dedup.ids)} ids gob.pe, {len(dedup.urls)} urls, "
          f"{len(dedup.nombres)} nombres (leidos de bd_tramites.sql + {SQL_GENERADOS_PROPIO})")

    with open(ruta_salida, "a", encoding="utf-8") as sql:
        if primera_vez:
            sql.write("-- Generado automaticamente con dedup contra bd_tramites.sql.\n")
            sql.write("-- Revisar todo lo marcado con -- REVISAR:\n")
            sql.write("USE portal_tramites_db;\n\n")

        for sigla in ENTIDADES_PRINCIPALES_SIGLAS:
            if sigla in completadas:
                print(f"{sigla}: ya procesada, se salta (borra su linea de {ARCHIVO_PROGRESO} para repetir)")
                continue

            entidad = entidades.get(sigla)
            if not entidad:
                print(f"{sigla}: no encontrada en {ARCHIVO_ENTIDADES}, se salta")
                continue

            slug = entidad["slug"]
            print(f"\n{sigla} ({slug})...")

            if sigla not in ENTIDADES_YA_SEMBRADAS:
                sql.write(f"-- REVISAR: completar descripcion y sitio_web real de {sigla}\n")
                sql.write(
                    "INSERT INTO entidad (nombre, siglas, sector, descripcion, sitio_web) VALUES "
                    f"('{sql_escapar(entidad['institucion'])}', '{sql_escapar(sigla)}', "
                    f"'{sql_escapar(entidad['sector'])}', 'Pendiente de descripcion.', "
                    f"'{GOBPE_BASE}/institucion/{slug}');\n\n"
                )

            items = obtener_items_pagina(slug)
            if not items:
                print("  sin items encontrados (pagina no accesible o vacia)")
                sql.write(f"-- AVISO: {sigla} ({slug}) no genero NINGUN tramite/servicio -- ")
                sql.write("pagina tramites-y-servicios inaccesible o vacia, revisar el slug a mano\n\n")
                marcar_completada(sigla)
                continue

            etiquetas_nuevas_este_run = set()
            n_dup_entidad = 0
            for texto, url_pagina in items:
                # DEDUP PRE: con la URL de la lista y el nombre del item,
                # ANTES de gastar un request en la pagina de detalle.
                razon = dedup.ya_existe(sigla, texto, url_pagina)
                if razon:
                    n_dup_entidad += 1
                    print(f"  [DUP] {texto[:70]} -> {razon}")
                    continue

                d = extraer_detalle(url_pagina)
                # DEDUP POST: con la URL oficial resuelta (puede ser distinta
                # a la de gob.pe, ej. un sistema externo de la entidad) y el
                # nombre. Si matchea lo existente, se descarta el item entero.
                razon = dedup.ya_existe(sigla, texto, url_pagina, d["url_oficial"])
                if razon:
                    n_dup_entidad += 1
                    print(f"  [DUP] {texto[:70]} -> {razon}")
                    continue
                dedup.registrar(sigla, texto, url_pagina, d["url_oficial"])

                notas = []
                if not d["url_confiable"]:
                    notas.append("no se encontro un boton de accion (CTA) externo claro, se dejo la propia pagina de gob.pe como url_oficial")
                if not d["tipo_confiable"]:
                    notas.append("tipo asumido SERVICIO por defecto, ningun patron de nombre matcheo -- clasifica a mano")
                if not d["modalidad_confiable"]:
                    notas.append("modalidad asumida VIRTUAL, no se encontro en el texto")
                if not d["costo_confiable"]:
                    notas.append("costo asumido 0.00, no se encontro monto ni 'gratuito' -- verificar TUPA")
                if notas:
                    sql.write(f"-- REVISAR ({sigla} / {texto[:60]}): " + "; ".join(notas) + "\n")

                sql.write(
                    "INSERT INTO tramite (id_entidad, id_tipo, nombre, descripcion, url_oficial, modalidad, costo) VALUES (\n"
                    f"  (SELECT id_entidad FROM entidad WHERE siglas = '{sql_escapar(sigla)}'),\n"
                    f"  (SELECT id_tipo FROM tipo_contenido WHERE nombre = '{d['tipo']}'),\n"
                    f"  '{sql_escapar(texto)}',\n"
                    f"  '{sql_escapar(d['descripcion'])}',\n"
                    f"  '{sql_escapar(d['url_oficial'])}',\n"
                    f"  '{d['modalidad']}',\n"
                    f"  {d['costo']:.2f}\n"
                    ");\n"
                )
                # LAST_INSERT_ID() se reasigna con CADA insert -- por eso se
                # fija UNA vez en @tid y se reusa para requisito y etiqueta.
                sql.write("SET @tid = LAST_INSERT_ID();\n")

                for i, req in enumerate(d["requisitos"], start=1):
                    sql.write(
                        "INSERT INTO requisito (id_tramite, orden, descripcion) VALUES "
                        f"(@tid, {i}, '{sql_escapar(req[:300])}');\n"
                    )
                # si d["requisitos"] esta vacio NO se insertan filas de
                # requisito para ese tramite (regla del usuario)

                etiquetas = calcular_etiquetas(texto, d["descripcion"])
                if not etiquetas:
                    sql.write(f"-- REVISAR ({sigla} / {texto[:60]}): ninguna etiqueta matcheo, asignar a mano si aplica\n")
                for tag in etiquetas:
                    if tag not in etiquetas_nuevas_este_run:
                        etiquetas_nuevas_este_run.add(tag)
                        sql.write(f"INSERT IGNORE INTO etiqueta (nombre) VALUES ('{tag}');\n")
                    sql.write(
                        "INSERT IGNORE INTO tramite_etiqueta (id_tramite, id_etiqueta) VALUES "
                        f"(@tid, (SELECT id_etiqueta FROM etiqueta WHERE nombre = '{tag}'));\n"
                    )

                sql.write("\n")
                print(f"  + {texto[:70]} [{', '.join(etiquetas) or 'sin etiqueta'}]")

            sql.flush()
            marcar_completada(sigla)
            n_dup_total += n_dup_entidad
            print(f"  {sigla} listo: {MAX_TRAMITES_POR_ENTIDAD - n_dup_entidad} nuevos (aprox), {n_dup_entidad} duplicados omitidos")

    print(f"\nListo -> {ARCHIVO_SQL_SALIDA}")
    print(f"Duplicados omitidos en total: {n_dup_total}")
    print("Busca '-- REVISAR' en el archivo antes de ejecutarlo contra tu BD.")


if __name__ == "__main__":
    generar_sql()
