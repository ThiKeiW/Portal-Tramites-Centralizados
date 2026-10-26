import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../api/portalApi';
import { CATEGORIA_META, ENTIDADES_DESTACADAS, categoriaDe, colorEntidad } from '../data/catalogo';
import { Doc, Engranaje, Grafico, Libro, Lupa, Mic } from '../components/iconos';

const ICONOS_CATEGORIA = { doc: Doc, gear: Engranaje, chart: Grafico, book: Libro };

export default function Home({ onVoz }) {
  const navigate = useNavigate();
  const [texto, setTexto] = useState('');
  const [entidades, setEntidades] = useState([]);
  const [tipos, setTipos] = useState([]);
  const [estado, setEstado] = useState('cargando');
  const [error, setError] = useState('');

  const cargar = () => {
    setEstado('cargando');
    setError('');
    Promise.all([api.entidades(), api.tipos()])
      .then(([ents, tips]) => {
        setEntidades(ents);
        setTipos(tips);
        setEstado('listo');
      })
      .catch((e) => {
        setError(e.message);
        setEstado('error');
      });
  };

  useEffect(cargar, []);

  const irResultados = (params) => {
    const qs = new URLSearchParams(
      Object.entries(params).filter(([, v]) => v),
    ).toString();
    navigate(`/resultados${qs ? '?' + qs : ''}`);
  };

  const buscar = (e) => {
    e.preventDefault();
    irResultados({ q: texto.trim() });
  };

  const destacadas = ENTIDADES_DESTACADAS.map((siglas) =>
    entidades.find((e) => e.siglas === siglas),
  ).filter(Boolean);

  return (
    <>
      <section className="hero">
        <h1>¿Qué necesitas resolver hoy en el Estado Peruano?</h1>
        <p>Accede a más de 5,000 trámites, servicios, reportes y guías oficiales de todas las entidades públicas de manera fácil.</p>
        <form className="barra-busqueda" role="search" onSubmit={buscar}>
          <Lupa size={22} />
          <input
            type="search"
            value={texto}
            onChange={(e) => setTexto(e.target.value)}
            placeholder="Busca tu trámite, servicio, reporte o guía..."
            aria-label="Buscar trámite, servicio, reporte o guía"
          />
          <button type="button" className="btn-mic" onClick={onVoz} aria-label="Buscar por voz">
            <Mic size={20} />
          </button>
          <button type="submit" className="btn-primario">Buscar</button>
        </form>
      </section>

      <div className="contenedor">
        <section className="seccion" aria-labelledby="tit-categorias">
          <h2 id="tit-categorias">Explora por categorías principales</h2>
          {estado === 'cargando' && (
            <div className="cargando" role="status"><span className="rueda" aria-hidden="true" /><span>Cargando categorías…</span></div>
          )}
          {estado === 'error' && (
            <div className="tarjeta estado-vacio" role="alert">
              <h3>No se pudo cargar el catálogo</h3>
              <p>{error}</p>
              <p style={{ marginTop: '1rem' }}>
                <button className="btn-primario" onClick={cargar}>Reintentar</button>
              </p>
            </div>
          )}
          {estado === 'listo' && (
            <div className="grid-4">
              {tipos.map((t) => {
                const meta = categoriaDe(t.nombre);
                const Icono = ICONOS_CATEGORIA[meta.icono] ?? Doc;
                return (
                  <button key={t.id} className="tarjeta clicable" onClick={() => irResultados({ tipo: meta.id })}>
                    <span className="icono-cuadro"><Icono size={24} /></span>
                    <h3>{meta.nombre}</h3>
                    <p>{meta.descripcion || t.descripcion}</p>
                  </button>
                );
              })}
            </div>
          )}
        </section>

        <section className="seccion" aria-labelledby="tit-entidades" style={{ paddingBottom: '4rem' }}>
          <h2 id="tit-entidades">Trámites rápidos de entidades destacadas</h2>
          {estado === 'cargando' && (
            <div className="cargando" role="status"><span className="rueda" aria-hidden="true" /><span>Cargando entidades…</span></div>
          )}
          {estado === 'listo' && (
            <div className="grid-4">
              {destacadas.map((e) => (
                <button key={e.siglas} className="tarjeta clicable" onClick={() => irResultados({ entidad: e.siglas })}>
                  <span className="entidad-cab">
                    <span className="entidad-logo" style={{ background: colorEntidad(e.siglas) }} aria-hidden="true">
                      {e.siglas[0]}
                    </span>
                    <span>
                      <strong>{e.siglas}</strong>
                      <span>{e.sector}</span>
                    </span>
                  </span>
                </button>
              ))}
            </div>
          )}
        </section>
      </div>
    </>
  );
}
