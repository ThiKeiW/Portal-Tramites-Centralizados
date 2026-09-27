import { useMemo, useState } from 'react';
import { CATEGORIAS, ENTIDADES, TIPO_LABEL, TRAMITES } from '../data/placeholders';
import { Casa, ChevronDer, Doc, Lupa, Mic, X } from '../components/iconos';

function contarPorEntidad(lista) {
  const m = {};
  lista.forEach((t) => { m[t.entidad] = (m[t.entidad] ?? 0) + 1; });
  return m;
}

export default function Resultados({ queryInicial, tipoInicial, entidadInicial, onAbrirDetalle, onVoz, onInicio }) {
  const [query, setQuery] = useState(queryInicial ?? '');
  const [texto, setTexto] = useState(queryInicial ?? '');
  const [tipos, setTipos] = useState(() => (tipoInicial ? new Set([tipoInicial]) : new Set()));
  const [entidades, setEntidades] = useState(() => (entidadInicial ? new Set([entidadInicial]) : new Set()));
  const [orden, setOrden] = useState('solicitado');

  const alternar = (set, setSet, valor) => {
    setSet((prev) => {
      const n = new Set(prev);
      if (n.has(valor)) n.delete(valor);
      else n.add(valor);
      return n;
    });
  };

  const resultados = useMemo(() => {
    const q = query.trim().toLowerCase();
    let lista = TRAMITES.filter((t) => {
      const coincideTexto =
        !q ||
        t.nombre.toLowerCase().includes(q) ||
        t.descripcion.toLowerCase().includes(q) ||
        t.entidad.toLowerCase().includes(q);
      const coincideTipo = tipos.size === 0 || tipos.has(t.tipo);
      const coincideEntidad = entidades.size === 0 || entidades.has(t.entidad);
      return coincideTexto && coincideTipo && coincideEntidad;
    });
    if (orden === 'az') lista = [...lista].sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
    return lista;
  }, [query, tipos, entidades, orden]);

  const conteos = useMemo(() => contarPorEntidad(TRAMITES), []);
  const conteosTipo = useMemo(() => {
    const m = {};
    TRAMITES.forEach((t) => { m[t.tipo] = (m[t.tipo] ?? 0) + 1; });
    return m;
  }, []);

  const limpiarFiltros = () => {
    setTipos(new Set());
    setEntidades(new Set());
  };

  const submit = (e) => {
    e.preventDefault();
    setQuery(texto.trim());
  };

  return (
    <>
      <div className="subbarra">
        <form className="subbarra-inner" role="search" onSubmit={submit}>
          <div className="caja-busqueda">
            <Lupa size={20} />
            <input
              type="search"
              value={texto}
              onChange={(e) => setTexto(e.target.value)}
              placeholder="Busca tu trámite, servicio o documento..."
              aria-label="Buscar trámite, servicio o documento"
            />
            {texto && (
              <button type="button" className="btn-limpiar" aria-label="Limpiar búsqueda" onClick={() => { setTexto(''); setQuery(''); }}>
                <X size={20} />
              </button>
            )}
          </div>
          <button type="button" className="btn-mic-claro" onClick={onVoz} aria-label="Buscar por voz">
            <Mic size={20} />
          </button>
          <button type="submit" className="btn-buscar-texto">Buscar</button>
        </form>
      </div>

      <div className="layout-resultados">
        <aside className="filtros" aria-label="Filtros">
          <div className="filtros-cab">
            <h2>Filtrar resultados</h2>
            <button className="btn-texto" onClick={limpiarFiltros}>Limpiar todo</button>
          </div>

          <div className="grupo-filtro">
            <h3>Entidad emisora</h3>
            {ENTIDADES.map((e) => (
              <label key={e.siglas} className="opcion">
                <input
                  type="checkbox"
                  checked={entidades.has(e.siglas)}
                  onChange={() => alternar(entidades, setEntidades, e.siglas)}
                />
                {e.siglas}
                <span className="conteo">({conteos[e.siglas] ?? 0})</span>
              </label>
            ))}
          </div>

          <hr className="separador" />

          <div className="grupo-filtro">
            <h3>Tipo de recurso</h3>
            {CATEGORIAS.map((c) => (
              <label key={c.id} className="opcion">
                <input
                  type="checkbox"
                  checked={tipos.has(c.id)}
                  onChange={() => alternar(tipos, setTipos, c.id)}
                />
                {c.nombre}
                <span className="conteo">({conteosTipo[c.id] ?? 0})</span>
              </label>
            ))}
          </div>
        </aside>

        <section aria-live="polite">
          <div className="resultados-cab">
            <p>Se encontraron <strong>{resultados.length} resultado{resultados.length === 1 ? '' : 's'}</strong>
              {query && <> para “{query}”</>}</p>
            <label className="ordenar">
              Ordenar por:
              <select value={orden} onChange={(e) => setOrden(e.target.value)}>
                <option value="solicitado">Más solicitado</option>
                <option value="az">Nombre (A–Z)</option>
              </select>
            </label>
          </div>

          {resultados.map((t) => (
            <article key={t.id} className="tarjeta resultado">
              <span className="resultado-icono"><Doc size={24} /></span>
              <div className="resultado-cuerpo">
                <h3>
                  <button className="btn-texto" style={{ fontSize: 'inherit', textAlign: 'left' }} onClick={() => onAbrirDetalle(t.id)}>
                    {t.nombre}
                  </button>
                  <span className={`insignia insignia-tipo ${t.tipo === 'servicio' ? 'servicio' : ''}`}>{TIPO_LABEL[t.tipo]}</span>
                  <span className="insignia insignia-ent">{t.entidad}</span>
                </h3>
                <p>{t.descripcion}</p>
              </div>
              <button className="btn-primario" onClick={() => onAbrirDetalle(t.id)}>
                Ver detalles <ChevronDer size={16} />
              </button>
            </article>
          ))}

          {resultados.length === 0 && (
            <div className="tarjeta estado-vacio">
              <span className="resultado-icono" style={{ margin: '0 auto' }}><Doc size={26} /></span>
              <h3>¿No encontraste lo que buscabas?</h3>
              <p>No se encontraron resultados para tu búsqueda. Intenta con otros términos o revisa los filtros.</p>
              <p style={{ marginTop: '1rem' }}>
                <button className="btn-volver" onClick={onInicio}><Casa size={18} /> Volver al inicio</button>
              </p>
            </div>
          )}
        </section>
      </div>
    </>
  );
}
