# -*- coding: utf-8 -*-
"""
mejorar_generados.py (v2)
-------------------------
Aplica en tramites_generados.sql YA GENERADO (sin re-scraper todolo):

1. DESCRIPCIONES: para los bloques con url gob.pe, refetch la pagina y
   reconstruye la descripcion COMPLETA (si gob.pe truncaba con '...')
   usando el parrafo del cuerpo que la continia. Termina en punto logico,
   nunca en '...'. Para los demas bloques (url externa), la descripcion
   se sanea localmente (recortar_logico), SIN fetch.
2. TIPOS: reclasificacion con las reglas amplificadas (guias -> pasos de
   contenido, reportes -> fuente de datos/estadisticas) usando
   nombre + descripcion + senal de contenido real de la pagina.
3. REQUISITOS: elimina las filas placeholder ("Ver requisitos en la
   pagina oficial.") y renumera las demas por tramite. Sin requisitos
   reales -> cero filas.

Parseo por LINEAS (determinista): un grupo empieza en 'INSERT INTO
tramite ' y TODO hasta el proximo 'INSERT INTO tramite' le pertenece
(incluye SET @tid, requisitos, etiquetas y comentarios REVISAR).
Rendimiento: ~99 fetches x 1.2 seg ≈ 2-3 min.
"""

import os
import re
import time

import requests
from bs4 import BeautifulSoup

import generar_sql_tramites as g

CARPETA_SCRIPT = os.path.dirname(os.path.abspath(__file__))
ARCHIVO = os.path.join(CARPETA_SCRIPT, "tramites_generados.sql")
PAUSA = 1.2
PLACEHOLDER = "ver requisitos en la pagina oficial"

PATRON_FILA = re.compile(
    r"\),\n  '((?:[^']|'')*)',\n  '((?:[^']|'')*)',\n  '(https?://[^']+)',\n  '([A-Z]+)',\n  (\d+\.\d{2})\n"
)
PATRON_TIPO = re.compile(r"WHERE nombre = '([A-Z]+)'\)")
PATRON_REQUISITO = re.compile(
    r"INSERT INTO requisito \(id_tramite, orden, descripcion\) VALUES \(@tid, (\d+), '((?:[^']|'')*)'\);"
)


def senal_contenido(texto_bajo: str) -> str:
    if g.PATRON_GUIA_CONTENIDO.search(texto_bajo):
        return "GUIA"
    if g.PATRON_REPORTE_CONTENIDO.search(texto_bajo):
        return "REPORTE"
    return ""


def clasificar(nombre: str, desc: str, senal: str) -> str:
    """Escalera de 4 tipos con las reglas del generador v2."""
    if g.PATRON_GUIA.search(nombre) or senal == "GUIA":
        return "GUIA"
    if g.PATRON_REPORTE.search(nombre) or senal == "REPORTE":
        return "REPORTE"
    if (g.PATRON_ACCION_TRAMITE.search(nombre)
            or g.VERBOS_TRAMITE.search(nombre.strip())
            or g.SENALES_TRAMITE_TEXTO.search(desc)):
        return "TRAMITE"
    return "SERVICIO"


def main():
    with open(ARCHIVO, encoding="utf-8") as f:
        texto = f.read()
    with open(ARCHIVO + ".bak_mejorar", "w", encoding="utf-8") as f:
        f.write(texto)

    estadisticas = {"desc_completadas": 0, "cambios_tipo": 0,
                    "req_ph_removidos": 0, "req_renumerados": 0}

    lineas = texto.splitlines(keepends=True)
    cabecera, grupos, actual = [], [], None
    for ln in lineas:
        if ln.startswith("INSERT INTO tramite "):
            if actual:
                grupos.append(actual)
            actual = [ln]
        elif actual:
            actual.append(ln)
        else:
            cabecera.append(ln)
    if actual:
        grupos.append(actual)
    print(f"Bloques: {len(grupos)}")

    grupos_nuevos = []
    for i, grupo in enumerate(grupos, start=1):
        t = "".join(grupo)
        mfila = PATRON_FILA.search(t)
        if not mfila:
            print(f"  [aviso] bloque {i} sin formato esperado")
            grupos_nuevos.append(grupo)
            continue
        nombre, desc_vieja, url, dummy = (mfila.group(1), mfila.group(2),
                                          mfila.group(3), mfila.group(4))
        desc_vieja_txt = desc_vieja.replace("''", "'")

        senal = ""
        desc_nueva = desc_vieja_txt
        if re.search(r"^https?://(?:www\.)?gob\.pe/\d+", url):
            r = g._get(url)
            time.sleep(PAUSA)
            if r is not None:
                soup = BeautifulSoup(r.text, "html.parser")
                parrafos = [
                    p.get_text(" ", strip=True) for p in soup.find_all("p")
                    if len(p.get_text(strip=True)) > 80
                ]
                meta = soup.find("meta", attrs={"name": "description"})
                desc_meta = (meta.get("content") or "").strip() if meta else ""
                desc_nueva = g.construir_descripcion(desc_meta, parrafos)
                senal = senal_contenido(soup.get_text(" ", strip=True).lower())
        else:
            senal = senal_contenido(f"{nombre} {desc_vieja_txt}".lower())

        desc_saneada = g.recortar_logico(desc_nueva)
        if desc_saneada and desc_saneada != desc_vieja_txt:
            nuevo = t.replace(f"'{mfila.group(2)}',",
                              f"'{g.sql_escapar(desc_saneada)}',", 1)
            if nuevo != t:
                t = nuevo
                estadisticas["desc_completadas"] += 1

        mtipo = PATRON_TIPO.search(t)
        if mtipo:
            viejo = mtipo.group(1)
            nuevo_tipo = clasificar(nombre, desc_saneada, senal)
            if nuevo_tipo != viejo:
                t = t.replace(f"WHERE nombre = '{viejo}'",
                              f"WHERE nombre = '{nuevo_tipo}'", 1)
                estadisticas["cambios_tipo"] += 1
                print(f"  [tipo] {viejo} -> {nuevo_tipo} | {nombre[:55]}")

        # requisitos: filas que empiezan con INSERT INTO requisito
        filas_req = []
        otras = []
        for ln in t.splitlines(keepends=True):
            if ln.startswith("INSERT INTO requisito "):
                m = PATRON_REQUISITO.match(ln.strip())
                if m and g.normalizar_texto(m.group(2)) == PLACEHOLDER:
                    estadisticas["req_ph_removidos"] += 1
                else:
                    filas_req.append(ln)
            else:
                otras.append(ln)
        if filas_req:
            reconstruidas = []
            for j, ln in enumerate(filas_req, start=1):
                m = PATRON_REQUISITO.match(ln.strip())
                nuevo_num = f", {j}, '"
                nueva = re.sub(r", \d+, '", nuevo_num, ln, count=1)
                reconstruidas.append(nueva)
                if nueva != ln:
                    estadisticas["req_renumerados"] += 1
            otras.extend(reconstruidas)
        t = "".join(otras)

        grupos_nuevos.append(t.splitlines(keepends=True))
        if i % 25 == 0:
            print(f"  ...{i}/{len(grupos)}")

    salida = "".join(cabecera)
    for grupo in grupos_nuevos:
        salida += "".join(grupo)
    with open(ARCHIVO, "w", encoding="utf-8") as f:
        f.write(salida)

    print("\n--- RESUMEN ---")
    for k, v in estadisticas.items():
        print(f"  {k}: {v}")

    from collections import Counter
    tipos = Counter(PATRON_TIPO.findall(salida))
    print("--- distribucion final ---")
    for tipo, cnt in tipos.most_common():
        print(f"  {tipo:10} {cnt}")
    invalidos = set(tipos) - {"TRAMITE", "SERVICIO", "REPORTE", "GUIA"}
    print("tipos invalidos:", invalidos or "ninguno")
    residuales = len(re.findall(r"\.\.\.',\n", salida))
    print(f"descripciones que siguen en '...': {residuales}")


if __name__ == "__main__":
    main()
