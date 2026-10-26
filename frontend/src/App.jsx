import { useEffect, useState } from 'react';
import { Route, Routes, useLocation, useNavigate } from 'react-router-dom';
import { AccessibilityProvider } from './context/AccessibilityContext';
import Navbar from './components/Navbar';
import Home from './pages/Home';
import Resultados from './pages/Resultados';
import Detalle from './pages/Detalle';
import ModalVoz from './components/ModalVoz';
import PanelAccesibilidad from './components/PanelAccesibilidad';
import BotonFlotante from './components/BotonFlotante';
import { Casa, Doc } from './components/iconos';

// Rutas de la aplicacion (antes SPA por estado en App):
//   /                -> Home
//   /resultados      -> Resultados (query params: q, tipo, entidad)
//   /tramite/:id     -> Detalle
function NoEncontrado() {
  return (
    <div className="contenedor" style={{ paddingBottom: '4rem' }}>
      <div className="tarjeta estado-vacio" style={{ marginTop: '2rem' }}>
        <span className="resultado-icono" style={{ margin: '0 auto' }}><Doc size={26} /></span>
        <h3>Pagina no encontrada</h3>
        <p>La direccion que buscas no existe. Vuelve al inicio para continuar.</p>
        <p style={{ marginTop: '1rem' }}>
          <a className="btn-volver" href="/"><Casa size={18} /> Volver al inicio</a>
        </p>
      </div>
    </div>
  );
}

export default function App() {
  const navigate = useNavigate();
  const { pathname } = useLocation();
  const [vozAbierta, setVozAbierta] = useState(false);
  const [a11yAbierto, setA11yAbierto] = useState(false);

  // Volver arriba al cambiar de ruta (antes: useEffect sobre `vista`).
  useEffect(() => {
    window.scrollTo(0, 0);
  }, [pathname]);

  const irResultados = (query = '', tipo = null, entidad = null) => {
    const params = new URLSearchParams();
    if (query) params.set('q', query);
    if (tipo) params.set('tipo', tipo);
    if (entidad) params.set('entidad', entidad);
    navigate(`/resultados${params.toString() ? '?' + params.toString() : ''}`);
  };

  const abrirVozYIr = (texto) => {
    setVozAbierta(false);
    irResultados(texto.trim());
  };

  return (
    <AccessibilityProvider>
      {pathname !== '/' && <Navbar />}

      <Routes>
        <Route path="/" element={<Home onVoz={() => setVozAbierta(true)} />} />
        <Route
          path="/resultados"
          element={
            <Resultados
              onVoz={() => setVozAbierta(true)}
              onInicio={() => navigate('/')}
            />
          }
        />
        <Route
          path="/tramite/:id"
          element={
            <Detalle
              onInicio={() => navigate('/')}
            />
          }
        />
        <Route path="*" element={<NoEncontrado />} />
      </Routes>

      <BotonFlotante onClick={() => setA11yAbierto(true)} />
      {a11yAbierto && <PanelAccesibilidad onCerrar={() => setA11yAbierto(false)} />}
      {vozAbierta && (
        <ModalVoz
          onCerrar={() => setVozAbierta(false)}
          onResultado={abrirVozYIr}
        />
      )}
    </AccessibilityProvider>
  );
}
