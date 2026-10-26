import { Link, useLocation, useNavigate } from 'react-router-dom';

const LINKS = [
  { id: 'tramite', label: 'Trámites', to: '/resultados?tipo=tramite' },
  { id: 'servicio', label: 'Servicios', to: '/resultados?tipo=servicio' },
  { id: 'reporte', label: 'Reportes', to: '/resultados?tipo=reporte' },
  { id: 'guia', label: 'Guías', to: '/resultados?tipo=guia' },
];

// Navegacion con rutas reales: Inicio -> "/" y categorias ->
// /resultados?tipo=... (antes los enlaces solo cambiaban estado interno).
export default function Navbar() {
  const navigate = useNavigate();
  const { search } = useLocation();
  const tipoActual = new URLSearchParams(search).get('tipo');

  return (
    <header className="navbar">
      <div className="navbar-inner">
        <button className="marca" onClick={() => navigate('/')} aria-label="Ir al inicio">
          <span className="marca-insignia">PE</span>
          <span>Portal Único de Trámites</span>
        </button>
        <nav className="nav-links" aria-label="Navegación principal">
          {LINKS.map((l) => (
            <Link
              key={l.id}
              to={l.to}
              className={tipoActual === l.id ? 'activo' : ''}
              aria-current={tipoActual === l.id ? 'page' : undefined}
            >
              {l.label}
            </Link>
          ))}
        </nav>
      </div>
    </header>
  );
}
