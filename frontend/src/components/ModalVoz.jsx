import { useEffect, useRef, useState } from 'react';
import { api } from '../api/portalApi';
import { Check, Mic, X } from './iconos';

// Búsqueda por voz real: graba con el micrófono (MediaRecorder), envía el
// audio al backend (DeepGram es-419 + keyterms) y redirige con la transcripción.
const MAX_SEGUNDOS = 15;

function elegirMimeType() {
  if (typeof MediaRecorder === 'undefined') return '';
  const candidatos = ['audio/webm;codecs=opus', 'audio/webm', 'audio/mp4'];
  return candidatos.find((t) => MediaRecorder.isTypeSupported(t)) ?? '';
}

export default function ModalVoz({ onCerrar, onResultado }) {
  const [fase, setFase] = useState('permiso'); // permiso | grabando | enviando | confirmando | error
  const [texto, setTexto] = useState('');
  const [segundos, setSegundos] = useState(0);
  const [progreso, setProgreso] = useState(0);
  const [error, setError] = useState('');
  const recorderRef = useRef(null);
  const partesRef = useRef([]);
  const timersRef = useRef([]);
  const vivoRef = useRef(true);

  const limpiar = () => {
    timersRef.current.forEach((t) => { clearTimeout(t); clearInterval(t); });
    timersRef.current = [];
    try { recorderRef.current?.stream?.getTracks().forEach((tr) => tr.stop()); } catch { /* ya detenido */ }
    recorderRef.current = null;
  };

  useEffect(() => {
    vivoRef.current = true;
    iniciar();
    const key = (e) => { if (e.key === 'Escape') onCerrar(); };
    window.addEventListener('keydown', key);
    return () => {
      vivoRef.current = false;
      window.removeEventListener('keydown', key);
      limpiar();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fallar = (mensaje) => {
    if (!vivoRef.current) return;
    limpiar();
    setError(mensaje);
    setFase('error');
  };

  const iniciar = async () => {
    setError('');
    setTexto('');
    setSegundos(0);
    setProgreso(0);
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    } catch {
      fallar('No se pudo acceder al micrófono. Revisa los permisos del navegador.');
      return;
    }
    if (!vivoRef.current) {
      stream.getTracks().forEach((tr) => tr.stop());
      return;
    }
    const mimeType = elegirMimeType();
    const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
    partesRef.current = [];
    recorder.ondataavailable = (e) => {
      if (e.data && e.data.size > 0) partesRef.current.push(e.data);
    };
    recorder.onstop = () => enviar(new Blob(partesRef.current, { type: recorder.mimeType || 'audio/webm' }));
    recorderRef.current = recorder;
    recorder.start(250);
    setFase('grabando');

    const tick = setInterval(() => {
      setSegundos((s) => {
        if (s + 1 >= MAX_SEGUNDOS) {
          clearInterval(tick);
          detener();
        }
        return s + 1;
      });
    }, 1000);
    timersRef.current.push(tick);
  };

  const detener = () => {
    timersRef.current.forEach((t) => { clearTimeout(t); clearInterval(t); });
    timersRef.current = [];
    if (recorderRef.current && recorderRef.current.state !== 'inactive') {
      setFase('enviando');
      recorderRef.current.stop();
    }
  };

  const enviar = async (blob) => {
    if (!vivoRef.current) return;
    if (!blob || blob.size === 0) {
      fallar('La grabación quedó vacía. Inténtalo de nuevo.');
      return;
    }
    setFase('enviando');
    try {
      const r = await api.transcribirVoz(blob);
      if (!vivoRef.current) return;
      setTexto(r.transcripcion);
      setFase('confirmando');
      const inicio = Date.now();
      const avance = setInterval(() => {
        const p = Math.min(100, ((Date.now() - inicio) / 2200) * 100);
        setProgreso(p);
        if (p >= 100) {
          clearInterval(avance);
          timersRef.current.push(setTimeout(() => {
            if (vivoRef.current) onResultado(r.transcripcion);
          }, 450));
        }
      }, 100);
      timersRef.current.push(avance);
    } catch (e) {
      fallar(e.message);
    }
  };

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
              {fase === 'grabando' ? (
                <button className="mic-centro" onClick={detener} aria-label="Detener y buscar">
                  <Mic size={30} />
                </button>
              ) : (
                <span className="mic-centro" aria-hidden="true">
                  <Mic size={30} />
                </span>
              )}
            </div>
          </div>
        </div>

        <div className="transcripcion" aria-live="polite">
          {fase === 'permiso' && <span className="estado">SOLICITANDO MICRÓFONO…</span>}
          {fase === 'grabando' && <span className="estado">ESCUCHANDO… {segundos}s (toca el micrófono para buscar)</span>}
          {fase === 'enviando' && <span className="estado">TRANSCRIBIENDO…</span>}
          {fase === 'confirmando' && <span className="estado">ESCUCHANDO…</span>}
          {texto && <blockquote>“{texto}”</blockquote>}
          {fase === 'error' && <span className="estado">ERROR</span>}
        </div>

        {fase === 'confirmando' && (
          <div className="tarjeta-confirmacion" role="status">
            <Check size={20} />
            <span>Entendido: {texto} → Redirigiendo</span>
          </div>
        )}
        {(fase === 'confirmando') && (
          <div className="barra-progreso" aria-hidden="true"><div style={{ width: `${progreso}%` }} /></div>
        )}

        {fase === 'error' && (
          <div className="tarjeta-confirmacion" role="alert" style={{ display: 'block' }}>
            {error}
            <div className="acciones-modal" style={{ marginTop: '0.75rem' }}>
              <button className="btn-primario" onClick={iniciar}>Reintentar</button>
            </div>
          </div>
        )}

        <div className="acciones-modal">
          <button className="btn-texto" onClick={onCerrar}>Cancelar</button>
        </div>
      </div>
    </div>
  );
}
