import { CATEGORIAS, MODALIDAD_LABEL, TIPO_LABEL, TRAMITES, entidadPorSiglas, formatoCosto, requisitosDe } from '../data/placeholders';
import { Casa, ChevronDer, Escudo, Externo, Globo, Tarjeta } from '../components/iconos';

export default function Detalle({ id, onVolver, onAbrirDetalle, onInicio }) {
  const tramite = TRAMITES.find((t) => t.id === id) ?? TRAMITES[0];
  const entidad = entidadPorSiglas(tramite.entidad);
  const categoria = CATEGORIAS.find((c) => c.id === tramite.tipo)?.nombre ?? 'Trámites';
  const relacionados = TRAMITES.filter((t) => t.id !== tramite.id && t.entidad === tramite.entidad).slice(0, 3);
  const relleno = relacionados.length < 3
    ? [...relacionados, ...TRAMITES.filter((t) => t.id !== tramite.id && t.entidad !== tramite.entidad)].slice(0, 3)
    : relacionados;

  return (
    <div className="contenedor">
      <nav className="migas" aria-label="Migas de pan">
        <button className="btn-volver btn-volver-compacto" onClick={onInicio}><Casa size={16} /> Inicio</button>
        <ChevronDer size={14} />
        <button onClick={() => onVolver(tramite.tipo)}>{categoria}</button>
        <ChevronDer size={14} />
        <strong aria-current="page">{tramite.nombre}</strong>
      </nav>

      <div className="layout-detalle">
        <article className="tarjeta detalle">
          <div className="detalle-cab-insignias">
            <span className="insignia insignia-tipo">{TIPO_LABEL[tramite.tipo]}</span>
            <span className="insignia insignia-ent"><Escudo size={12} /> {entidad?.nombre ?? tramite.entidad} - {tramite.entidad}</span>
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
              <span><small>Modalidad disponible</small><strong>{MODALIDAD_LABEL[tramite.modalidad]}</strong></span>
            </div>
          </div>
          <hr />
          <h2>Requisitos</h2>
          <ol className="lista-requisitos">
            {requisitosDe(tramite.id).map((r) => (
              <li key={r.id}><span className="numero" aria-hidden="true">{r.orden}</span><span>{r.descripcion}</span></li>
            ))}
          </ol>
          <hr />
          <a className="btn-primario btn-sitio" href={tramite.urlOficial} target="_blank" rel="noreferrer">
            Ir al sitio oficial <Externo size={16} />
          </a>
        </article>

        <aside className="barra-lateral">
          <section className="tarjeta" style={{ marginBottom: '1.25rem' }} aria-labelledby="tit-rel">
            <h2 id="tit-rel">Trámites relacionados</h2>
            {relleno.map((r) => (
              <button key={r.id} className="relacionado" onClick={() => onAbrirDetalle(r.id)}>
                <strong>{r.nombre}</strong>
                <span>{entidadPorSiglas(r.entidad)?.nombre ?? r.entidad} - {r.entidad}</span>
              </button>
            ))}
          </section>
        </aside>
      </div>
    </div>
  );
}
