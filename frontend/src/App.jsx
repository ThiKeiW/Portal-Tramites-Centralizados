import { useEffect, useState } from 'react';
import { AccessibilityProvider } from './context/AccessibilityContext';
import Navbar from './components/Navbar';
import Home from './pages/Home';
import Resultados from './pages/Resultados';
import Detalle from './pages/Detalle';
import ModalVoz from './components/ModalVoz';
import PanelAccesibilidad from './components/PanelAccesibilidad';
import BotonFlotante from './components/BotonFlotante';

export default function App() {
  const [vista, setVista] = useState({ nombre: 'home' });
  const [vozAbierta, setVozAbierta] = useState(false);
  const [a11yAbierto, setA11yAbierto] = useState(false);

  useEffect(() => {
    window.scrollTo(0, 0);
  }, [vista]);

  const irInicio = () => setVista({ nombre: 'home' });
  const irResultados = (query = '', tipo = null, entidad = null) =>
    setVista({ nombre: 'resultados', query, tipo, entidad, clave: Date.now() });
  const irDetalle = (id) => setVista({ nombre: 'detalle', id });

  const navegarNavbar = (destino) => {
    if (destino === 'inicio') irInicio();
    else irResultados('', destino, null);
  };

  const navbarActivo =
    vista.nombre === 'home' ? 'inicio' : vista.nombre === 'detalle' ? 'tramite' : vista.tipo ?? 'inicio';

  return (
    <AccessibilityProvider>
      {vista.nombre !== 'home' && <Navbar activo={navbarActivo} onNavegar={navegarNavbar} />}

      {vista.nombre === 'home' && (
        <Home
          onBuscar={(q) => irResultados(q)}
          onVoz={() => setVozAbierta(true)}
          onCategoria={(tipo) => irResultados('', tipo, null)}
          onEntidad={(siglas) => irResultados('', null, siglas)}
        />
      )}

      {vista.nombre === 'resultados' && (
        <Resultados
          key={vista.clave}
          queryInicial={vista.query}
          tipoInicial={vista.tipo}
          entidadInicial={vista.entidad}
          onAbrirDetalle={irDetalle}
          onVoz={() => setVozAbierta(true)}
          onInicio={irInicio}
        />
      )}

      {vista.nombre === 'detalle' && (
        <Detalle
          id={vista.id}
          onVolver={() => irResultados('')}
          onAbrirDetalle={irDetalle}
          onInicio={irInicio}
        />
      )}

      <BotonFlotante onClick={() => setA11yAbierto(true)} />
      {a11yAbierto && <PanelAccesibilidad onCerrar={() => setA11yAbierto(false)} />}
      {vozAbierta && (
        <ModalVoz
          onCerrar={() => setVozAbierta(false)}
          onResultado={(texto) => {
            setVozAbierta(false);
            irResultados(texto);
          }}
        />
      )}
    </AccessibilityProvider>
  );
}
