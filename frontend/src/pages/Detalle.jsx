import { useEffect, useState } from 'react';
import { api } from '../api/portalApi';
import { MODALIDAD_LABEL, TIPO_LABEL, categoriaDe, formatoCosto, tipoId } from '../data/catalogo';
import { Casa, ChevronDer, Escudo, Externo, Globo, Tarjeta } from '../components/iconos';

export default function Detalle({ id, onVolver, onAbrirDetalle, onInicio }) {
  const [tramite, setTramite] = useState(null);
  const [relacionados, setRelacionados] = useState([]);
  const [estado, setEstado] = useState('cargando');
  const [error, setError] = useState('');

  useEffect(() => {
    let vivo = true;
    setEstado('cargando');
    setError('');
    Promise.all([api.tramite(id), api.relacionados(id, 3)])
      .then(([t, rels]) => {
        if (!vivo) return;
        setTramite(t);
        setRelacionados(rels);
        setEstado('listo');
      })
      .catch((e) => {
        if (!vivo) return;
        setError(e.message);
        setEstado('error');
      });
    return () => { vivo = false; };
  }, [id]);

  if (estado === 'cargando') {
    return (
      <div className="contenedor" style={{ paddingBottom: '4rem' }}>
        <div className="cargando" role="status"><span className="rueda" aria-hidden="true" /><span>Cargando detalle…</span></div>
      </div>
    );
  }

  if (estado === 'error' || !tramite) {
    return (
      <div className="contenedor" style={{ paddingBottom: '4rem' }}>
        <div className="tarjeta estado-vacio" role="alert" style={{ marginTop: '2rem' }}>
          <h3>No se pudo cargar el detalle</h3>
          <p>{error || 'El recurso solicitado no existe.'}</p>
          <p style={{ marginTop: '1rem' }}>
            <button className="btn-volver" onClick={onInicio}><Casa size={18} /> Volver al inicio</button>
          </p>
        </div>
      </div>
    );
  }

  const idTipo = tipoId(tramite.tipo?.nombre);
  const categoria = categoriaDe(tramite.tipo?.nombre);
  const requisitos = [...(tramite.requisitos ?? [])].sort((a, b) => a.orden - b.orden);

  return (
    <div className="contenedor">
      <nav className="migas" aria-label="Migas de pan">
        <button className="btn-volver btn-volver-compacto" onClick={onInicio}><Casa size={16} /> Inicio</button>
        <ChevronDer size={14} />
        <button onClick={() => onVolver(idTipo)}>{categoria.nombre}</button>
        <ChevronDer size={14} />
        <strong aria-current="page">{tramite.nombre}</strong>
      </nav>

      <div className="layout-detalle">
        <article className="tarjeta detalle">
          <div className="detalle-cab-insignias">
            <span className="insignia insignia-tipo">{TIPO_LABEL[idTipo]}</span>
            <span className="insignia insignia-ent"><Escudo size={12} /> {tramite.entidad?.nombre} - {tramite.entidad?.siglas}</span>
          </div>
          <h1>{tramite.nombre}</h1>
          <hr />
          <h2>Descripción</h2>
          <p className="descripcion">{tramite.descripcion}</p>
          <hr />
          <div className="ficha-doble">
            <div className="ficha">
              <span className="icono-cuadro"><Tarjeta size={22} /></span>
              <span><small>Costo</small><strong>{formatoCosto(tramite.costo)}</strong></span>
            </div>
            <div className="ficha">
              <span className="icono-cuadro"><Globo size={22} /></span>
              <span><small>Modalidad disponible</small><strong>{MODALIDAD_LABEL[tramite.modalidad] ?? tramite.modalidad}</strong></span>
            </div>
          </div>
          <hr />
          <h2>Requisitos</h2>
          {requisitos.length === 0 ? (
            <p className="descripcion">Este recurso no registra requisitos.</p>
          ) : (
            <ol className="lista-requisitos">
              {requisitos.map((r) => (
                <li key={r.id}><span className="numero" aria-hidden="true">{r.orden}</span><span>{r.descripcion}</span></li>
              ))}
            </ol>
          )}
          <hr />
          <a className="btn-primario btn-sitio" href={tramite.urlOficial} target="_blank" rel="noreferrer">
            Ir al sitio oficial <Externo size={16} />
          </a>
        </article>

        <aside className="barra-lateral">
          <section className="tarjeta" style={{ marginBottom: '1.25rem' }} aria-labelledby="tit-rel">
            <h2 id="tit-rel">Trámites relacionados</h2>
            {relacionados.length === 0 && (
              <p className="descripcion">Sin documentos relacionados por etiquetas.</p>
            )}
            {relacionados.map((r) => (
              <button key={r.id} className="relacionado" onClick={() => onAbrirDetalle(r.id)}>
                <strong>{r.nombre}</strong>
                <span>{r.entidad?.nombre} - {r.entidad?.siglas}</span>
              </button>
            ))}
          </section>
        </aside>
      </div>
    </div>
  );
}
