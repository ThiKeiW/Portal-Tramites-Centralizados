import { Acceso } from './iconos';

export default function BotonFlotante({ onClick }) {
  return (
    <button className="btn-flotante" onClick={onClick} aria-label="Abrir menú de accesibilidad" title="Accesibilidad">
      <Acceso size={26} />
    </button>
  );
}
