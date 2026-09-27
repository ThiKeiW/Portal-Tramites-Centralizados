const LINKS = [
  { id: 'inicio', label: 'Inicio' },
  { id: 'tramite', label: 'Trámites' },
  { id: 'servicio', label: 'Servicios' },
  { id: 'reporte', label: 'Reportes' },
  { id: 'guia', label: 'Guías' },
];

export default function Navbar({ activo, onNavegar }) {
  return (
    <header className="navbar">
      <div className="navbar-inner">
        <button className="marca" onClick={() => onNavegar('inicio')} aria-label="Ir al inicio">
          <span className="marca-insignia">PE</span>
          <span>Portal Único de Trámites</span>
        </button>
        <nav className="nav-links" aria-label="Navegación principal">
          {LINKS.map((l) => (
            <button
              key={l.id}
              className={activo === (l.id) && activo !== 'inicio' ? 'activo' : ''}
              aria-current={activo === l.id ? 'page' : undefined}
              onClick={() => onNavegar(l.id)}
            >
              {l.label}
            </button>
          ))}
        </nav>
      </div>
    </header>
  );
}
