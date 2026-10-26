import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../api/portalApi';
import { TIPO_LABEL, categoriaDe, tipoId } from '../data/catalogo';
import { Casa, ChevronDer, Doc, Lupa, Mic, X } from '../components/iconos';

// La pagina se deriva de la URL (/resultados?q=&tipo=&entidad=): los filtros
// y la busqueda se sincronizan con searchParams (antes venian del estado App).
export default function Resultados({ onVoz, onInicio }) {
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const [nonce, setNonce] = useState(0);

  const query = searchParams.get('q') ?? '';
  const tipoInicial = searchParams.get('tipo');
  const entidadInicial = searchParams.get('entidad');

  const [texto, setTexto] = useState(query);
  const [tipos, setTipos] = useState(() => new Set(tipoInicial ? tipoInicial.split(',') : []));
  const [entidades, setEntidades] = useState(() => new Set(entidadInicial ? entidadInicial.split(',') : []));
  const [base, setBase] = useState([]);
  const [catalogoEntidades, setCatalogoEntidades] = useState([]);
  const [catalogoTipos, setCatalogoTipos] = useState([]);
  const [estado, setEstado] = useState('cargando');
  const [error, setError] = useState('');

  // Reset de los filtros locales si se llega con otros params (nueva navegacion).
  const paramsClave = `${tipoInicial ?? ''}|${entidadInicial ?? ''}`;
  const paramsClavePrev = useRef(paramsClave);
  useEffect(() => {
    if (paramsClave !== paramsClavePrev.current) {
      paramsClavePrev.current = paramsClave;
      setTipos(new Set(tipoInicial ? tipoInicial.split(',') : []));
      setEntidades(new Set(entidadInicial ? entidadInicial.split(',') : []));
    }
  }, [paramsClave, tipoInicial, entidadInicial]);

  // Sincroniza URL con la q: al cambiar q reinicia los textos.
  useEffect(() => {
    setTexto(query);
  }, [query]);

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
  }, [query, nonce]);

  const actualizarParams = (nuevosTipos, nuevasEntidades) => {
    const params = new URLSearchParams();
    if (query) params.set('q', query);
    if (nuevosTipos.size > 0) params.set('tipo', [...nuevosTipos].join(','));
    if (nuevasEntidades.size > 0) params.set('entidad', [...nuevasEntidades].join(','));
    setSearchParams(params, { replace: true });
  };

  const alternarEntidad = (sigla) => {
    const n = new Set(entidades);
    if (n.has(sigla)) n.delete(sigla);
    else n.add(sigla);
    setEntidades(n);
    actualizarParams(tipos, n);
  };

  const alternarTipo = (id) => {
    const n = new Set(tipos);
    if (n.has(id)) n.delete(id);
    else n.add(id);
    setTipos(n);
    actualizarParams(n, entidades);
  };

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
    actualizarParams(new Set(), new Set());
  };

  const submit = (e) => {
    e.preventDefault();
    const nuevoQuery = texto.trim();
    const params = new URLSearchParams();
    if (nuevoQuery) params.set('q', nuevoQuery);
    if (tipos.size > 0) params.set('tipo', [...tipos].join(','));
    if (entidades.size > 0) params.set('entidad', [...entidades].join(','));
    setSearchParams(params);
  };

  const resultados = useMemo(() => {
    const lista = base.filter((t) => {
      const coincideTipo = tipos.size === 0 || tipos.has(tipoId(t.tipo?.nombre));
      const coincideEntidad = entidades.size === 0 || entidades.has(t.entidad?.siglas);
      return coincideTipo && coincideEntidad;
    });
    return [...lista].sort((a, b) => a.nombre.localeCompare(b.nombre, 'es'));
  }, [base, tipos, entidades]);

  const entidadesVisibles = catalogoEntidades.filter((e) => (conteos[e.siglas] ?? 0) > 0);

  const abrirDetalle = (id) => navigate(`/tramite/${id}`);

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
                  onChange={() => alternarEntidad(e.siglas)}
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
                    onChange={() => alternarTipo(meta.id)}
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
                <button className="btn-primario" onClick={() => setNonce((n) => n + 1)}>Reintentar</button>
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
                    <button className="btn-texto" style={{ fontSize: 'inherit', textAlign: 'left' }} onClick={() => abrirDetalle(t.id)}>
                      {t.nombre}
                    </button>
                    <span className={`insignia insignia-tipo ${idTipo === 'servicio' ? 'servicio' : ''}`}>{TIPO_LABEL[idTipo]}</span>
                    <span className="insignia insignia-ent">{t.entidad?.siglas}</span>
                  </h3>
                  <p>{t.descripcion}</p>
                </div>
                <button className="btn-primario" onClick={() => abrirDetalle(t.id)}>
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
