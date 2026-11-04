import { useEffect, useMemo, useRef, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../api/portalApi';
import { TIPO_LABEL, categoriaDe, tipoId } from '../data/catalogo';
import { Casa, ChevronDer, ChevronIzq, Doc, Lupa, Mic, X } from '../components/iconos';

// El listado se pagina en bloques de 15; la pagina activa viaja en la URL
// (?page=N) para que el navegador (atrás) y la migaja del detalle regresar
// al mismo bloque donde estaba el último recurso abierto.
const POR_PAGINA = 15;

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

  // Publica la URL actual (con filtros) para que el detalle pueda regresar
  // al listado tal como estaba (la lee "Volver" / migajas de Detalle).
  useEffect(() => {
    sessionStorage.setItem('resultadosURL', searchParams.toString());
  }, [searchParams]);

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
    // Sin replace: cada ajuste de filtro crea su entrada en el historial para
    // que, al volver del detalle, la URL (y los filtros) se mantengan.
    setSearchParams(params);
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
      const s = t.entidadSiglas;
      if (s) m[s] = (m[s] ?? 0) + 1;
    });
    return m;
  }, [base]);

  const conteosTipo = useMemo(() => {
    const m = {};
    base.forEach((t) => {
      const id = tipoId(t.tipoNombre);
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
    // Se respeta el orden del backend: con q va por relevancia (puntaje
    // descendente); sin q viene ordenado alfabéticamente.
    return base.filter((t) => {
      const coincideTipo = tipos.size === 0 || tipos.has(tipoId(t.tipoNombre));
      const coincideEntidad = entidades.size === 0 || entidades.has(t.entidadSiglas);
      return coincideTipo && coincideEntidad;
    });
  }, [base, tipos, entidades]);

  // Paginación: la página activa vive en la URL (?page=N); al cambiar
  // filtros o buscar, los params se reescriben sin page y se vuelve a la
  // primera página. Si la URL pide una página fuera de rango, se ajusta.
  const totalPaginas = Math.max(1, Math.ceil(resultados.length / POR_PAGINA));
  const paginaURL = (() => {
    const n = parseInt(searchParams.get('page'), 10);
    return Number.isFinite(n) && n > 0 ? n : 1;
  })();
  const paginaActual = Math.min(paginaURL, totalPaginas);
  const visibles = resultados.slice((paginaActual - 1) * POR_PAGINA, paginaActual * POR_PAGINA);

  // Bloques de paginacion (1 ... alrededores de la pagina actual ... N) con "..."
  // cuando hay saltos, como en los buscadores clásicos.
  const bloquesPagina = useMemo(() => {
    if (totalPaginas <= 5) {
      return Array.from({ length: totalPaginas }, (_, i) => ({ tipo: 'pagina', n: i + 1 }));
    }
    const c = paginaActual;
    const boletos = new Set([1, totalPaginas, c - 1, c, c + 1].filter((n) => n >= 1 && n <= totalPaginas));
    const orden = [...boletos].sort((a, b) => a - b);
    const partes = [];
    let prevN = 0;
    for (const n of orden) {
      if (n - prevN > 1) partes.push({ tipo: 'puntos' });
      partes.push({ tipo: 'pagina', n });
      prevN = n;
    }
    return partes;
  }, [paginaActual, totalPaginas]);

  const irPagina = (n) => {
    setSearchParams((p) => {
      const q2 = new URLSearchParams(p);
      if (n > 1) q2.set('page', String(n));
      else q2.delete('page');
      return q2;
    });
    window.scrollTo(0, 0);
  };

  // Abre el detalle recordando el recurso: al regresar (atrás del navegador o
  // migaja del detalle) se recarga el listado con la misma página (URL) y se
  // hace scroll hasta ese recurso.
  const abrirDetalle = (id) => {
    sessionStorage.setItem('resultadosUltimoId', String(id));
    navigate(`/tramite/${id}`);
  };

  // Al volver del detalle: centra el último recurso abierto en la pantalla.
  useEffect(() => {
    if (estado !== 'listo') return;
    const ultimo = sessionStorage.getItem('resultadosUltimoId');
    if (!ultimo) return;
    sessionStorage.removeItem('resultadosUltimoId');
    const el = document.querySelector(`[data-res-id="${ultimo}"]`);
    if (el) el.scrollIntoView({ block: 'center' });
  }, [estado, paginaActual]);

  const entidadesVisibles = catalogoEntidades.filter((e) => (conteos[e.siglas] ?? 0) > 0);

  // Navegacion con flechas ↑/↓: recorren en bucle los controles del contenedor
  // activo (Enter/espacio activan el elemento igual que de costumbre).
  const moverFlecha = (selector) => (e) => {
    if (e.key !== 'ArrowDown' && e.key !== 'ArrowUp') return;
    const opciones = [...e.currentTarget.querySelectorAll(selector)];
    if (opciones.length === 0) return;
    e.preventDefault();
    const i = opciones.indexOf(document.activeElement);
    const siguiente = e.key === 'ArrowDown'
      ? (i + 1) % opciones.length
      : (i <= 0 ? opciones.length - 1 : i - 1);
    opciones[i === -1 ? 0 : siguiente].focus();
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
              <button type="button" className="btn-limpiar" aria-label="Limpiar búsqueda" onClick={() => { setTexto(''); setSearchParams((p) => { const q2 = new URLSearchParams(p); q2.delete('q'); return q2; }); }}>
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
        <aside className="filtros" aria-label="Filtros" onKeyDown={moverFlecha('input[type="checkbox"]')}>
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

        <section aria-live="polite" onKeyDown={moverFlecha('.resultado .btn-texto')}>
          <div className="resultados-cab">
            <p>Se encontraron <strong>{resultados.length} resultado{resultados.length === 1 ? '' : 's'}</strong>
              {query && <> para “{query}”</>}
              <span className="orden-fijo">{query ? '(ordenados por relevancia)' : '(ordenados A–Z)'}</span></p>
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

          {estado === 'listo' && visibles.map((t) => {
            const idTipo = tipoId(t.tipoNombre);
            return (
              <article key={t.id} className="tarjeta resultado" data-res-id={t.id}>
                <div className="resultado-cuerpo">
                  <h3>
                    <button className="btn-texto" style={{ fontSize: 'inherit', textAlign: 'left' }} onClick={() => abrirDetalle(t.id)}>
                      {t.nombre}
                    </button>
                    <span className={`insignia insignia-tipo ${idTipo === 'servicio' ? 'servicio' : ''}`}>{TIPO_LABEL[idTipo]}</span>
                    <span className="insignia insignia-ent">{t.entidadSiglas}</span>
                  </h3>
                  <p>{t.descripcion}</p>
                </div>
                <button className="btn-primario" onClick={() => abrirDetalle(t.id)}>
                  Ver detalles <ChevronDer size={16} />
                </button>
              </article>
            );
          })}

          {estado === 'listo' && totalPaginas > 1 && (
            <nav className="paginacion" aria-label="Paginacion de resultados">
              <button
                onClick={() => irPagina(paginaActual - 1)}
                disabled={paginaActual === 1}
                aria-label="Pagina anterior"
              >
                <ChevronIzq size={18} />
              </button>
              {bloquesPagina.map((b, i) =>
                b.tipo === 'pagina' ? (
                  <button
                    key={i}
                    className={b.n === paginaActual ? 'activo' : ''}
                    onClick={() => irPagina(b.n)}
                    aria-current={b.n === paginaActual ? 'page' : undefined}
                    aria-label={`Pagina ${b.n}`}
                  >
                    {b.n}
                  </button>
                ) : (
                  <span key={i} className="paginacion-puntos" aria-hidden="true">…</span>
                ),
              )}
              <button
                onClick={() => irPagina(paginaActual + 1)}
                disabled={paginaActual === totalPaginas}
                aria-label="Pagina siguiente"
              >
                <ChevronDer size={18} />
              </button>
            </nav>
          )}

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
