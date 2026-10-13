import { useEffect, useMemo, useState } from 'react';
import { api } from '../api/portalApi';
import { TIPO_LABEL, categoriaDe, tipoId } from '../data/catalogo';
import { Casa, ChevronDer, Doc, Lupa, Mic, X } from '../components/iconos';

export default function Resultados({ queryInicial, tipoInicial, entidadInicial, onAbrirDetalle, onVoz, onInicio }) {
  const [query, setQuery] = useState(queryInicial ?? '');
  const [texto, setTexto] = useState(queryInicial ?? '');
  const [tipos, setTipos] = useState(() => (tipoInicial ? new Set([tipoInicial]) : new Set()));
  const [entidades, setEntidades] = useState(() => (entidadInicial ? new Set([entidadInicial]) : new Set()));
  const [base, setBase] = useState([]);
  const [catalogoEntidades, setCatalogoEntidades] = useState([]);
  const [catalogoTipos, setCatalogoTipos] = useState([]);
  const [estado, setEstado] = useState('cargando');
  const [error, setError] = useState('');

  useEffect(() => {
    let vivo = true;
    setEstado('cargando');
    setError('');
    Promise.all([api.buscarTramites(query), api.entidades(), api.tipos()])
      .then(([tramites, ents, tips]) => {
        if (!vivo) return;
        setBase(tramites);
        setCatalogoEntidades(ents);
        setCatalogoTipos(tips);
        setEstado('listo');
      })
      .catch((e) => {
        if (!vivo) return;
        setError(e.message);
        setEstado('error');
      });
    return () => { vivo = false; };
  }, [query]);

  const alternar = (set, setSet, valor) => {
    setSet((prev) => {
      const n = new Set(prev);
      if (n.has(valor)) n.delete(valor);
      else n.add(valor);
      return n;
    });
  };

  const resultados = useMemo(() => {
    const lista = base.filter((t) => {
      const coincideTipo = tipos.size === 0 || tipos.has(tipoId(t.tipo?.nombre));
      const coincideEntidad = entidades.size === 0 || entidades.has(t.entidad?.siglas);
      return coincideTipo && coincideEntidad;
    });
    return [...lista].sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
  }, [base, tipos, entidades]);

  const conteos = useMemo(() => {
    const m = {};
    base.forEach((t) => {
      const s = t.entidad?.siglas;
      if (s) m[s] = (m[s] ?? 0) + 1;
    });
    return m;
  }, [base]);

  const conteosTipo = useMemo(() => {
    const m = {};
    base.forEach((t) => {
      const id = tipoId(t.tipo?.nombre);
      m[id] = (m[id] ?? 0) + 1;
    });
    return m;
  }, [base]);

  const limpiarFiltros = () => {
    setTipos(new Set());
    setEntidades(new Set());
  };

  const submit = (e) => {
    e.preventDefault();
    setQuery(texto.trim());
  };

  const entidadesVisibles = catalogoEntidades.filter((e) => (conteos[e.siglas] ?? 0) > 0);

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
            <button className="btn-limpiar-todo" onClick={limpiarFiltros}>Limpiar todo</button>
          </div>

          <div className="grupo-filtro">
            <h3>Entidad emisora</h3>
            {estado === 'cargando' && <p className="conteo">Cargando…</p>}
            {entidadesVisibles.map((e) => (
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
            {catalogoTipos.map((t) => {
              const meta = categoriaDe(t.nombre);
              return (
                <label key={t.id} className="opcion">
                  <input
                    type="checkbox"
                    checked={tipos.has(meta.id)}
                    onChange={() => alternar(tipos, setTipos, meta.id)}
                  />
                  {meta.nombre}
                  <span className="conteo">({conteosTipo[meta.id] ?? 0})</span>
                </label>
              );
            })}
          </div>
        </aside>

        <section aria-live="polite">
          <div className="resultados-cab">
            <p>Se encontraron <strong>{resultados.length} resultado{resultados.length === 1 ? '' : 's'}</strong>
              {query && <> para “{query}”</>} <span className="orden-fijo">(ordenados A–Z)</span></p>
          </div>

          {estado === 'cargando' && (
            <div className="cargando" role="status"><span className="rueda" aria-hidden="true" /><span>Buscando trámites…</span></div>
          )}

          {estado === 'error' && (
            <div className="tarjeta estado-vacio" role="alert">
              <h3>No se pudo cargar la búsqueda</h3>
              <p>{error}</p>
              <p style={{ marginTop: '1rem' }}>
                <button className="btn-primario" onClick={() => setQuery((q) => q)}>Reintentar</button>
              </p>
            </div>
          )}

          {estado === 'listo' && resultados.map((t) => {
            const idTipo = tipoId(t.tipo?.nombre);
            return (
              <article key={t.id} className="tarjeta resultado">
                <span className="resultado-icono"><Doc size={24} /></span>
                <div className="resultado-cuerpo">
                  <h3>
                    <button className="btn-texto" style={{ fontSize: 'inherit', textAlign: 'left' }} onClick={() => onAbrirDetalle(t.id)}>
                      {t.nombre}
                    </button>
                    <span className={`insignia insignia-tipo ${idTipo === 'servicio' ? 'servicio' : ''}`}>{TIPO_LABEL[idTipo]}</span>
                    <span className="insignia insignia-ent">{t.entidad?.siglas}</span>
                  </h3>
                  <p>{t.descripcion}</p>
                </div>
                <button className="btn-primario" onClick={() => onAbrirDetalle(t.id)}>
                  Ver detalles <ChevronDer size={16} />
                </button>
              </article>
            );
          })}

          {estado === 'listo' && resultados.length === 0 && (
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
