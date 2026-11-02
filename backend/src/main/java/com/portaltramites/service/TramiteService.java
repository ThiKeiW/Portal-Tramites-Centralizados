package com.portaltramites.service;

import com.portaltramites.error.RecursoNoEncontradoException;
import com.portaltramites.error.SolicitudInvalidaException;
import com.portaltramites.model.Modalidad;
import com.portaltramites.model.Requisito;
import com.portaltramites.model.Tramite;
import com.portaltramites.repository.RequisitoRepository;
import com.portaltramites.repository.TramiteRepository;
import jakarta.persistence.criteria.Predicate;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
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

    private final TramiteRepository tramiteRepository;
    private final RequisitoRepository requisitoRepository;

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
     */
    @Transactional(readOnly = true)
    public List<Tramite> buscar(String q, String entidad, String tipo, String modalidad) {
        List<String> palabras = (q == null || q.isBlank()) ? List.of() : extraerPalabrasClave(q);

        if (palabras.isEmpty()) {
            return tramiteRepository.findAll(specFrase(q, entidad, tipo, modalidad),
                    Sort.by(Sort.Direction.ASC, "nombre"));
        }

        Modalidad modalidadEnum = (modalidad != null && !modalidad.isBlank()) ? parsearModalidad(modalidad) : null;
        List<Tramite> activos = new ArrayList<>();
        Map<Integer, Campos> campos = new HashMap<>();
        for (Tramite t : tramiteRepository.findAll()) {
            if (Boolean.TRUE.equals(t.getActivo())) {
                activos.add(t);
                campos.put(t.getId(), camposDe(t));
            }
        }

        // IDF: el peso de cada palabra crece con su rareza en el catálogo.
        Map<String, Double> idf = new HashMap<>();
        for (String p : palabras) {
            int df = 0;
            for (Tramite t : activos) {
                if (pesoDe(campos.get(t.getId()), p) > 0) {
                    df += 1;
                }
            }
            idf.put(p, Math.log(1.0 + (activos.size() + 1.0) / (df + 1.0)));
        }

        Map<Integer, Double> puntajes = new HashMap<>();
        List<Tramite> encontrados = new ArrayList<>();
        for (Tramite t : activos) {
            if (!cumpleFiltros(t, entidad, tipo, modalidadEnum)) {
                continue;
            }
            Campos c = campos.get(t.getId());
            double puntaje = 0;
            for (String p : palabras) {
                puntaje += pesoDe(c, p) * idf.get(p);
            }
            if (puntaje > 0) {
                puntajes.put(t.getId(), puntaje);
                encontrados.add(t);
            }
        }
        return encontrados.stream()
                .sorted(Comparator
                        .comparingDouble((Tramite t) -> puntajes.get(t.getId())).reversed()
                        .thenComparing(Tramite::getNombre))
                .toList();
    }

    /** Filtros + LIKE de frase completa (comportamiento previo, sin palabras clave). */
    private Specification<Tramite> specFrase(String q, String entidad, String tipo, String modalidad) {
        return (root, query, cb) -> {
            List<Predicate> predicados = new ArrayList<>();
            predicados.add(cb.isTrue(root.get("activo")));
            if (q != null && !q.isBlank()) {
                String patron = "%" + q.trim().toLowerCase() + "%";
                predicados.add(cb.or(
                        cb.like(cb.lower(root.get("nombre")), patron),
                        cb.like(cb.lower(root.get("descripcion")), patron)));
            }
            if (entidad != null && !entidad.isBlank()) {
                predicados.add(cb.equal(
                        cb.lower(root.get("entidad").get("siglas")),
                        entidad.trim().toLowerCase()));
            }
            if (tipo != null && !tipo.isBlank()) {
                predicados.add(cb.equal(root.get("tipo").get("nombre"), tipo.trim().toUpperCase()));
            }
            if (modalidad != null && !modalidad.isBlank()) {
                predicados.add(cb.equal(root.get("modalidad"), parsearModalidad(modalidad)));
            }
            return cb.and(predicados.toArray(new Predicate[0]));
        };
    }

    private boolean cumpleFiltros(Tramite t, String entidad, String tipo, Modalidad modalidad) {
        if (entidad != null && !entidad.isBlank()
                && !t.getEntidad().getSiglas().equalsIgnoreCase(entidad.trim())) {
            return false;
        }
        if (tipo != null && !tipo.isBlank()
                && !t.getTipo().getNombre().equalsIgnoreCase(tipo.trim())) {
            return false;
        }
        return modalidad == null || t.getModalidad().equals(modalidad);
    }

    /** Campos normalizados del trámite para el matcheo (se calculan una vez). */
    private record Campos(String nombre, String descripcion, String entidad, String etiquetas) {
    }

    private Campos camposDe(Tramite t) {
        StringBuilder etiquetas = new StringBuilder();
        t.getEtiquetas().forEach(e -> etiquetas.append(normalizar(e.getNombre())).append(' '));
        return new Campos(
                normalizar(t.getNombre()),
                normalizar(t.getDescripcion()),
                normalizar(t.getEntidad().getSiglas() + " " + t.getEntidad().getNombre()),
                etiquetas.toString());
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
    private String normalizar(String texto) {
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

    @Transactional(readOnly = true)
    public Tramite obtenerPorId(Integer id) {
        return tramiteRepository.findById(id)
                .filter(Tramite::getActivo)
                .orElseThrow(() -> new RecursoNoEncontradoException(
                        "Trámite no encontrado con id: " + id));
    }

    @Transactional(readOnly = true)
    public List<Requisito> requisitos(Integer tramiteId) {
        obtenerPorId(tramiteId);
        return requisitoRepository.findByTramiteIdOrderByOrdenAsc(tramiteId);
    }

    /**
     * Documentos/trámites relacionados por etiquetas compartidas,
     * ordenados por la cantidad de etiquetas en común.
     */
    @Transactional(readOnly = true)
    public List<Tramite> relacionados(Integer tramiteId, Integer limite) {
        obtenerPorId(tramiteId);
        int efectivo = (limite == null) ? LIMITE_RELACIONADOS_POR_DEFECTO : limite;
        return tramiteRepository.findRelacionadosPorEtiquetas(tramiteId, efectivo);
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
