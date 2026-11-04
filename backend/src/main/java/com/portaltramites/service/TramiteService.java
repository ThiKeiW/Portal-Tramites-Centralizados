package com.portaltramites.service;

import com.portaltramites.error.RecursoNoEncontradoException;
import com.portaltramites.error.SolicitudInvalidaException;
import com.portaltramites.model.Modalidad;
import com.portaltramites.model.RequisitoVista;
import com.portaltramites.model.TramiteDetalle;
import com.portaltramites.model.TramiteLista;
import com.portaltramites.service.CatalogoService.Snapshot;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;


@Service
@RequiredArgsConstructor
public class TramiteService {

    private static final int LIMITE_RELACIONADOS_POR_DEFECTO = 3;

    private static final int PESO_NOMBRE = 5;
    private static final int PESO_ETIQUETA = 3;
    private static final int PESO_ENTIDAD = 2;
    private static final int PESO_DESCRIPCION = 1;

    /**
     * Muletillas y frases de cortesía típicas del usuario ("quisiera declarar",
     * "dame donde puedo...", "quiero ver cuando...") que no aportan al
     * matcheo. Declaradas en forma normalizada (minúsculas, sin acentos).
     */
    private static final Set<String> PALABRAS_VACIAS = Set.of(
            // artículos, preposiciones, pronombres, verbos copulativos
            "de", "del", "la", "el", "los", "las", "un", "una", "unos", "unas",
            "y", "o", "u", "al", "en", "con", "para", "por", "que", "se", "su",
            "sus", "mi", "mis", "tu", "tus", "lo", "me", "te", "le", "les",
            "nos", "es", "son", "hay", "si", "no", "ya", "esta", "estan", "estoy",
            // interrogativos y conectores
            "donde", "cuando", "como", "quien", "cual", "cuales", "cuanto",
            "cuantos", "porque", "sobre", "acerca",
            // verbos de intención / cortesía ("quisiera declarar...", "dame...")
            "quisiera", "desearia", "quiero", "queria", "gustaria", "necesito",
            "podria", "podrias", "deberia", "debe", "puedo", "puede", "pueden",
            "hacer", "hago", "dame", "darme", "buscame", "busca", "buscar",
            "muestrame", "mostrar", "traeme", "traer", "encontrar", "encuentro",
            "saber", "decir", "favor", "gracias", "hola", "seria", "sera",
            "hara", "tengo", "tenia", "ver", "mirar", "revisar", "chequear",
            "averiguar", "acceder", "dime", "digame", "ayudame", "deseo", "yo",
            // genéricos del dominio que no distinguen un trámite
            "consulta", "consultas", "consultar", "tramite", "tramites",
            "pagina", "oficial", "linea", "gob", "gobierno", "peru", "portal",
            "porfa", "porfavor", "dias", "tardes", "disculpa");

    private final CatalogoService catalogoService;

    /**
     * Búsqueda con filtros opcionales: entidad (siglas), tipo
     * (TRAMITE/SERVICIO/REPORTE/GUIA) y modalidad. El texto libre se resuelve
     * por palabras clave con puntaje de relevancia: se descartan muletillas,
     * cada trámite puntúa según dónde coinciden sus palabras (nombre &gt;
     * etiquetas &gt; entidad &gt; descripción) y cada palabra pesa según su
     * selectividad (IDF): las que aparecen en casi todos los trámites
     * ("información") valen poco y las selectivas ("financiera") valen mucho.
     * La coincidencia es relajada (basta una palabra) y los resultados van
     * ordenados por puntaje descendente, no alfabéticamente.
     *
     * Toda la búsqueda se resuelve en memoria contra el snapshot del
      * CatalogoService: con BD en la nube esto equivale a CERO consultas SQL
     * por petición (antes eran unos 550 por el N+1 de las colecciones EAGER).
     */
    public List<TramiteLista> buscar(String q, String entidad, String tipo, String modalidad) {
        List<String> palabras = (q == null || q.isBlank()) ? List.of() : extraerPalabrasClave(q);
        Modalidad modalidadEnum = (modalidad != null && !modalidad.isBlank()) ? parsearModalidad(modalidad) : null;

        Snapshot snap = catalogoService.snapshot();
        List<TramiteLista> filas = snap.activos();
        Map<Integer, List<String>> etiquetasDe = snap.etiquetasPor();

        // Sin palabras clave: filtros directos y orden A–Z (comportamiento
        // previo; si llega texto puro de muletillas, filtra por la frase
        // completa en nombre/descripción).
        if (palabras.isEmpty()) {
            String patron = (q == null) ? null : normalizar(q.trim());
            List<TramiteLista> encontrados = new ArrayList<>();
            for (TramiteLista t : filas) {
                if (!cumpleFiltros(t, entidad, tipo, modalidadEnum)) {
                    continue;
                }
                if (patron != null && !patron.isBlank()
                        && !normalizar(t.nombre()).contains(patron)
                        && !normalizar(t.descripcion() == null ? "" : t.descripcion()).contains(patron)) {
                    continue;
                }
                encontrados.add(t);
            }
            return encontrados;
        }

        // IDF: el peso de cada palabra crece con su rareza en el catálogo.
        List<Campos> catálogo = new ArrayList<>(filas.size());
        for (TramiteLista t : filas) {
            catálogo.add(new Campos(t, etiquetasDe.getOrDefault(t.id(), List.of())));
        }
        Map<String, Double> idf = new HashMap<>();
        for (String p : palabras) {
            int df = 0;
            for (Campos c : catálogo) {
                if (pesoDe(c, p) > 0) {
                    df += 1;
                }
            }
            idf.put(p, Math.log(1.0 + (catálogo.size() + 1.0) / (df + 1.0)));
        }

        Map<TramiteLista, Double> puntajes = new HashMap<>();
        for (Campos c : catálogo) {
            if (!cumpleFiltros(c.fila(), entidad, tipo, modalidadEnum)) {
                continue;
            }
            double puntaje = 0;
            for (String p : palabras) {
                puntaje += pesoDe(c, p) * idf.get(p);
            }
            if (puntaje > 0) {
                puntajes.put(c.fila(), puntaje);
            }
        }
        return catálogo.stream()
                .map(Campos::fila)
                .filter(puntajes::containsKey)
                .sorted(Comparator
                        .comparingDouble((TramiteLista t) -> puntajes.get(t)).reversed()
                        .thenComparing(TramiteLista::nombre))
                .toList();
    }

    private boolean cumpleFiltros(TramiteLista t, String entidad, String tipo, Modalidad modalidad) {
        if (entidad != null && !entidad.isBlank()
                && !t.entidadSiglas().equalsIgnoreCase(entidad.trim())) {
            return false;
        }
        if (tipo != null && !tipo.isBlank()
                && !t.tipoNombre().equalsIgnoreCase(tipo.trim())) {
            return false;
        }
        return modalidad == null || t.modalidad().equals(modalidad);
    }

    /** Campos normalizados de una fila para el matcheo (se calculan una vez). */
    private record Campos(TramiteLista fila, String nombre, String descripcion,
                          String entidad, String etiquetas) {
        private Campos(TramiteLista fila, List<String> etiquetas) {
            this(fila,
                    normalizar(fila.nombre()),
                    normalizar(fila.descripcion() == null ? "" : fila.descripcion()),
                    normalizar(fila.entidadSiglas() + " " + fila.entidadNombre()),
                    String.join(" ", etiquetas.stream().map(TramiteService::normalizar).toList()) + " ");
        }
    }

    /** Peso base de la coincidencia más fuerte de una palabra (0 si no hay). */
    private int pesoDe(Campos c, String p) {
        if (c.nombre().contains(p)) {
            return PESO_NOMBRE;
        }
        if (c.etiquetas().contains(p)) {
            return PESO_ETIQUETA;
        }
        if (c.entidad().contains(p)) {
            return PESO_ENTIDAD;
        }
        if (c.descripcion().contains(p)) {
            return PESO_DESCRIPCION;
        }
        return 0;
    }

    /** Tokeniza el texto libre, quita muletillas y aplica stemming ligero. */
    private List<String> extraerPalabrasClave(String q) {
        List<String> palabras = new ArrayList<>();
        for (String bruta : q.trim().split("[^\\p{L}\\p{N}]+")) {
            if (bruta.isBlank()) {
                continue;
            }
            String token = normalizar(bruta);
            if (token.length() < 3 || PALABRAS_VACIAS.contains(token)) {
                continue;
            }
            token = stemar(token);
            if (!palabras.contains(token)) {
                palabras.add(token);
            }
        }
        return palabras;
    }

    /** Minúsculas y sin acentos para comparar sin importar tildes. */
    private static String normalizar(String texto) {
        if (texto == null) {
            return "";
        }
        return Normalizer.normalize(texto, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "")
                .toLowerCase(Locale.ROOT)
                .trim();
    }

    /**
     * Stemming ligero: plurales y verbos en infinitivo se reducen para que
     * "declarar" coincida con "declaración" y "impuestos" con "impuesto".
     */
    private String stemar(String token) {
        if (token.length() >= 6) {
            if (token.endsWith("es")) {
                return token.substring(0, token.length() - 2);
            }
            if (token.endsWith("ar") || token.endsWith("er") || token.endsWith("ir")) {
                return token.substring(0, token.length() - 2);
            }
        }
        if (token.length() >= 4 && token.endsWith("s")) {
            return token.substring(0, token.length() - 1);
        }
        return token;
    }

    /** Detalle completo (requisitos incluidos) desde el catálogo en memoria. */
    public TramiteDetalle detalle(Integer id) {
        Snapshot snap = catalogoService.snapshot();
        TramiteLista fila = snap.activos().stream()
                .filter(t -> t.id().equals(id))
                .findFirst()
                .orElseThrow(() -> new RecursoNoEncontradoException(
                        "Trámite no encontrado con id: " + id));
        List<RequisitoVista> requisitos = snap.requisitosPor()
                .getOrDefault(id, List.of())
                .stream()
                .map(r -> new RequisitoVista(r.idRequisito(), r.orden(), r.descripcion()))
                .toList();
        return new TramiteDetalle(
                fila.id(), fila.nombre(), fila.descripcion(), fila.urlOficial(),
                fila.modalidad(), fila.costo(), fila.entidadSiglas(), fila.entidadNombre(),
                fila.tipoNombre(), requisitos);
    }

    /** Requisitos ligeros de un trámite, desde el catálogo en memoria. */
    public List<RequisitoVista> requisitos(Integer tramiteId) {
        return detalle(tramiteId).requisitos();
    }

    /**
     * Documentos/trámites relacionados por etiquetas compartidas, ordenados
     * por la cantidad de etiquetas en común. Se calcula en memoria contra el
     * catálogo (el mismo conteo que hacía la consulta SQL con GROUP BY, ahora
     * sin consultas por petición).
     */
    public List<TramiteLista> relacionados(Integer tramiteId, Integer limite) {
        Snapshot snap = catalogoService.snapshot();
        int efectivo = (limite == null) ? LIMITE_RELACIONADOS_POR_DEFECTO : limite;
        List<String> base = snap.etiquetasPor().getOrDefault(tramiteId, List.of());
        if (base.isEmpty()) {
            return List.of();
        }
        Set<String> etiquetasBase = new HashSet<>(base);
        Map<TramiteLista, Long> compartidas = new HashMap<>();
        for (TramiteLista t : snap.activos()) {
            if (t.id().equals(tramiteId)) {
                continue;
            }
            long enComun = snap.etiquetasPor()
                    .getOrDefault(t.id(), List.of())
                    .stream()
                    .filter(etiquetasBase::contains)
                    .count();
            if (enComun > 0) {
                compartidas.put(t, enComun);
            }
        }
        return compartidas.entrySet().stream()
                .sorted(Comparator
                        .comparingLong(Map.Entry<TramiteLista, Long>::getValue).reversed()
                        .thenComparing(e -> e.getKey().nombre()))
                .limit(efectivo)
                .map(Map.Entry::getKey)
                .toList();
    }

    private Modalidad parsearModalidad(String valor) {
        for (Modalidad m : Modalidad.values()) {
            if (m.name().equalsIgnoreCase(valor.trim())) {
                return m;
            }
        }
        throw new SolicitudInvalidaException(
                "Modalidad inválida: '" + valor + "'. Valores permitidos: VIRTUAL, PRESENCIAL, SEMIPRESENCIAL");
    }
}
