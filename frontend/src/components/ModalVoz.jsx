import { useEffect, useRef, useState } from 'react';
import { api } from '../api/portalApi';
import { Check, Mic, X } from './iconos';

// Búsqueda por voz real: captura PCM con Web Audio API, lo empaqueta como WAV
// en el cliente y lo envía al backend (DeepGram es-419 + keyterms).
// Se usa WAV en lugar de MediaRecorder/webm porque algunos navegadores
// generan un stream webm que DeepGram rechaza como "corrupt or unsupported".
const MAX_SEGUNDOS = 15;

function codificarWav(muestras, tasa) {
  const n = muestras.length;
  const total = 44 + n * 2;
  const buf = new ArrayBuffer(total);
  const v = new DataView(buf);
  const texto = (off, s) => {
    for (let i = 0; i < s.length; i += 1) v.setUint8(off + i, s.charCodeAt(i));
  };
  texto(0, 'RIFF');
  v.setUint32(4, total - 8, true);
  texto(8, 'WAVE');
  texto(12, 'fmt ');
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true); // PCM
  v.setUint16(22, 1, true); // mono
  v.setUint32(24, tasa, true);
  v.setUint32(28, tasa * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  texto(36, 'data');
  v.setUint32(40, n * 2, true);
  let off = 44;
  for (let i = 0; i < n; i += 1, off += 2) {
    const m = Math.max(-1, Math.min(1, muestras[i]));
    v.setInt16(off, m < 0 ? m * 0x8000 : m * 0x7FFF, true);
  }
  return new Blob([buf], { type: 'audio/wav' });
}

export default function ModalVoz({ onCerrar, onResultado }) {
  const [fase, setFase] = useState('permiso'); // permiso | grabando | enviando | confirmando | error
  const [texto, setTexto] = useState('');
  const [segundos, setSegundos] = useState(0);
  const [progreso, setProgreso] = useState(0);
  const [error, setError] = useState('');
  const [aviso, setAviso] = useState('');
  const inicioRef = useRef(0);
  const timersRef = useRef([]);
  const vivoRef = useRef(true);
  const grabandoRef = useRef(false);
  const ctxRef = useRef(null);
  const streamRef = useRef(null);
  const procRef = useRef(null);
  const pcmRef = useRef([]);
  const tasaRef = useRef(16000);

  const apagarAudio = () => {
    grabandoRef.current = false;
    try { procRef.current?.disconnect(); } catch { /* ya desconectado */ }
    try { streamRef.current?.getTracks().forEach((tr) => tr.stop()); } catch { /* ya detenido */ }
    procRef.current = null;
    streamRef.current = null;
    const ctx = ctxRef.current;
    ctxRef.current = null;
    if (ctx && ctx.state !== 'closed') {
      try { ctx.close(); } catch { /* ya cerrado */ }
    }
  };

  const limpiar = () => {
    timersRef.current.forEach((t) => { clearTimeout(t); clearInterval(t); });
    timersRef.current = [];
    apagarAudio();
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
    setAviso('');
    let stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true },
      });
    } catch {
      fallar('No se pudo acceder al micrófono. Revisa los permisos del navegador.');
      return;
    }
    if (!vivoRef.current) {
      stream.getTracks().forEach((tr) => tr.stop());
      return;
    }
    let ctx;
    try {
      ctx = new (window.AudioContext || window.webkitAudioContext)();
      if (ctx.state === 'suspended') await ctx.resume();
    } catch {
      stream.getTracks().forEach((tr) => tr.stop());
      fallar('No se pudo iniciar el audio del navegador.');
      return;
    }
    if (!vivoRef.current || ctx.state === 'closed') {
      stream.getTracks().forEach((tr) => tr.stop());
      if (ctx.state !== 'closed') ctx.close();
      return;
    }
    const fuente = ctx.createMediaStreamSource(stream);
    // El sink con ganancia 0 mantiene vivo el ScriptProcessor sin escuchar
    // la propia voz por los altavoces.
    const silencio = ctx.createGain();
    silencio.gain.value = 0;
    const proc = ctx.createScriptProcessor(4096, 1, 1);
    pcmRef.current = [];
    tasaRef.current = ctx.sampleRate;
    const maxMuestras = (MAX_SEGUNDOS + 5) * tasaRef.current;
    proc.onaudioprocess = (e) => {
      if (!grabandoRef.current || pcmRef.current.reduce((a, c) => a + c.length, 0) >= maxMuestras) return;
      pcmRef.current.push(new Float32Array(e.inputBuffer.getChannelData(0)));
    };
    fuente.connect(proc);
    proc.connect(silencio);
    silencio.connect(ctx.destination);
    procRef.current = proc;
    streamRef.current = stream;
    ctxRef.current = ctx;
    grabandoRef.current = true;
    inicioRef.current = Date.now();
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
    // Menos de 1 segundo no da material suficiente para transcribir.
    if (Date.now() - inicioRef.current < 1000) {
      setAviso('Habla un poco más… (al menos 1 segundo)');
      const t = setTimeout(() => setAviso(''), 2200);
      timersRef.current.push(t);
      return;
    }
    timersRef.current.forEach((t) => { clearTimeout(t); clearInterval(t); });
    timersRef.current = [];
    grabandoRef.current = false;
    const partes = pcmRef.current;
    const tasa = tasaRef.current;
    apagarAudio();
    const total = partes.reduce((a, c) => a + c.length, 0);
    if (total < tasa / 2) {
      fallar('La grabación fue demasiado corta. Inténtalo de nuevo hablando durante 1–3 segundos.');
      return;
    }
    const muestras = new Float32Array(total);
    let off = 0;
    for (const p of partes) {
      muestras.set(p, off);
      off += p.length;
    }
    setFase('enviando');
    enviar(codificarWav(muestras, tasa));
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
          {aviso && <span className="estado" role="status">{aviso}</span>}
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
