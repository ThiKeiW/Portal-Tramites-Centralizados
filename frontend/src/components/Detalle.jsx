import { TIPO_LABEL, TRAMITES, entidadPorSiglas } from '../data/placeholders';
import { ChevronDer, Escudo, Externo, Globo, Info, Tarjeta } from './iconos';

export default function Detalle({ id, onVolver, onAbrirDetalle, onInicio }) {
  const tramite = TRAMITES.find((t) => t.id === id) ?? TRAMITES[0];
  const entidad = entidadPorSiglas(tramite.entidad);
  const relacionados = TRAMITES.filter((t) => t.id !== tramite.id && t.entidad === tramite.entidad).slice(0, 3);
  const relleno = relacionados.length < 3
    ? [...relacionados, ...TRAMITES.filter((t) => t.id !== tramite.id && t.entidad !== tramite.entidad)].slice(0, 3)
    : relacionados;

  return (
    <div className="contenedor">
      <nav className="migas" aria-label="Migas de pan">
        <button onClick={onInicio}>Inicio</button>
        <ChevronDer size={14} />
        <button onClick={onVolver}>Trámites</button>
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
          <p className="descripcion">{tramite.descripcionLarga}</p>
          <hr />
          <div className="ficha-doble">
            <div className="ficha">
              <span className="icono-cuadro"><Tarjeta size={22} /></span>
              <span><small>Costo</small><strong>{tramite.costo}</strong></span>
            </div>
            <div className="ficha">
              <span className="icono-cuadro"><Globo size={22} /></span>
              <span><small>Modalidad disponible</small><strong>{tramite.modalidad}</strong></span>
            </div>
          </div>
          <hr />
          <h2>Requisitos</h2>
          <ol className="lista-requisitos">
            {tramite.requisitos.map((r, i) => (
              <li key={i}><span className="numero" aria-hidden="true">{i + 1}</span><span>{r}</span></li>
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
          <section className="tarjeta tarjeta-ayuda" aria-labelledby="tit-ayuda">
            <h3 id="tit-ayuda"><Info size={20} /> ¿Necesitas ayuda?</h3>
            <p>Si tienes dudas sobre este trámite, comunícate con la central telefónica de atención al ciudadano de {tramite.entidad}.</p>
            <p><strong className="linea">Línea gratuita: 1818</strong></p>
          </section>
        </aside>
      </div>
    </div>
  );
}
