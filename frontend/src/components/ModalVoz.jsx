import { useEffect, useRef, useState } from 'react';
import { Check, Mic, X } from './iconos';

// Simulación visual del flujo de voz (la integración real con Deepgram
// vivirá en la rama feature/busqueda-voz): escucha -> transcribe -> confirma -> redirige.
const EJEMPLOS = [
  'generar certificado único laboral',
  'duplicado de dni',
  'consulta ruc',
];

export default function ModalVoz({ onCerrar, onResultado }) {
  const [fase, setFase] = useState('escuchando');
  const [texto, setTexto] = useState('');
  const [progreso, setProgreso] = useState(0);
  const timers = useRef([]);

  useEffect(() => {
    const ejemplo = EJEMPLOS[Math.floor(Math.random() * EJEMPLOS.length)];
    timers.current.push(setTimeout(() => {
      setTexto(ejemplo);
      setFase('confirmando');
    }, 1600));

    const inicio = Date.now();
    const tick = setInterval(() => {
      const p = Math.min(100, ((Date.now() - inicio) / 2600) * 100);
      setProgreso(p);
      if (p >= 100) {
        clearInterval(tick);
        timers.current.push(setTimeout(() => onResultado(ejemplo), 450));
      }
    }, 100);
    timers.current.push(tick);

    const key = (e) => { if (e.key === 'Escape') onCerrar(); };
    window.addEventListener('keydown', key);
    return () => {
      timers.current.forEach((t) => { clearTimeout(t); clearInterval(t); });
      window.removeEventListener('keydown', key);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="velo" role="dialog" aria-modal="true" aria-label="Búsqueda por voz" onClick={onCerrar}>
      <div className="modal-voz" onClick={(e) => e.stopPropagation()}>
        <div className="modal-voz-cab">
          <h2>Búsqueda por Voz</h2>
          <button className="btn-cerrar" onClick={onCerrar} aria-label="Cerrar búsqueda por voz">
            <X size={18} />
          </button>
        </div>

        <div className="ondas" aria-hidden="true">
          <div className="onda">
            <div className="onda onda-2">
              <button className="mic-centro" onClick={onCerrar} aria-label="Detener escucha">
                <Mic size={30} />
              </button>
            </div>
          </div>
        </div>

        <div className="transcripcion" aria-live="polite">
          <span className="estado">{fase === 'escuchando' ? 'ESCUCHANDO…' : 'ESCUCHANDO…'}</span>
          {texto && <blockquote>“{texto}”</blockquote>}
        </div>

        {fase === 'confirmando' && (
          <div className="tarjeta-confirmacion" role="status">
            <Check size={20} />
            <span>Entendido: {texto} → Redirigiendo</span>
          </div>
        )}
        <div className="barra-progreso" aria-hidden="true"><div style={{ width: `${progreso}%` }} /></div>

        <div className="acciones-modal">
          <button className="btn-texto" onClick={onCerrar}>Cancelar</button>
        </div>
      </div>
    </div>
  );
}
