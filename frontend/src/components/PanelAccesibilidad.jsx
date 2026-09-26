import { CONTRASTES, CURSORES, TAMANOS_TEXTO, labelDe, useAccessibility } from '../a11y/AccessibilityContext';
import { Acceso, CursorFlecha, TextoAa, X } from './iconos';

function Grupo({ titulo, icono, valor, opciones, segmentos, activoClase, onElegir }) {
  return (
    <section className="grupo-a11y" aria-label={titulo}>
      <div className="grupo-a11y-cab">
        <span className="icono-cuadro" style={{ width: '2.25rem', height: '2.25rem' }}>{icono}</span>
        <strong>{titulo}</strong>
        <span className={`valor-actual ${activoClase === 'activo-ambar' ? 'valor-ambar' : 'valor-verde'}`}>
          {valor}
        </span>
      </div>
      <div className="segmentos" role="group" aria-label={`Elegir ${titulo.toLowerCase()}`}>
        {opciones.map((o, i) => (
          <button
            key={o.id}
            className={`segmento ${o.label === valor ? activoClase : ''}`}
            onClick={() => onElegir(o.id)}
            aria-pressed={o.label === valor}
            aria-label={`${titulo}: ${o.label}`}
            title={o.label}
          />
        ))}
      </div>
      <div className="segmento-etiquetas" aria-hidden="true">
        {opciones.map((o) => <span key={o.id}>{o.label}</span>)}
      </div>
    </section>
  );
}

export default function PanelAccesibilidad({ onCerrar }) {
  const { contraste, tamanoTexto, cursor, set, restablecer } = useAccessibility();

  return (
    <div className="velo" style={{ placeItems: 'stretch', justifyItems: 'end', padding: 0 }} onClick={onCerrar}>
      <aside
        className="cajon" role="dialog" aria-modal="true" aria-label="Menú de accesibilidad"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="cajon-cab">
          <Acceso size={22} />
          <h2>Menú de Accesibilidad</h2>
          <button className="btn-cerrar" onClick={onCerrar} aria-label="Cerrar menú de accesibilidad">
            <X size={18} />
          </button>
        </div>
        <div className="cajon-cuerpo">
          <p>Personaliza tu experiencia de navegación según tus necesidades. Los cambios se aplicarán instantáneamente.</p>

          <Grupo
            titulo="Tamaño de texto"
            icono={<TextoAa />}
            valor={labelDe(TAMANOS_TEXTO, tamanoTexto)}
            opciones={TAMANOS_TEXTO}
            activoClase="activo-verde"
            onElegir={(id) => set({ tamanoTexto: id })}
          />
          <Grupo
            titulo="Contrastes"
            icono={<X size={20} />}
            valor={labelDe(CONTRASTES, contraste)}
            opciones={CONTRASTES}
            activoClase="activo-ambar"
            onElegir={(id) => set({ contraste: id })}
          />
          <Grupo
            titulo="Cursor"
            icono={<CursorFlecha size={20} />}
            valor={labelDe(CURSORES, cursor)}
            opciones={CURSORES}
            segmentos={2}
            activoClase="activo-verde"
            onElegir={(id) => set({ cursor: id })}
          />
        </div>
        <div className="cajon-pie">
          <button className="btn-primario" style={{ width: '100%' }} onClick={restablecer}>
            Restablecer valores
          </button>
        </div>
      </aside>
    </div>
  );
}
