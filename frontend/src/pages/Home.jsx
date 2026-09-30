import { useState } from 'react';
import { BUSQUEDAS_POPULARES, CATEGORIAS, entidadPorSiglas } from '../data/placeholders';
import { Doc, Engranaje, Grafico, Libro, Lupa, Mic } from '../components/iconos';

const ICONOS_CATEGORIA = { doc: Doc, gear: Engranaje, chart: Grafico, book: Libro };

export default function Home({ onBuscar, onVoz, onCategoria, onEntidad }) {
  const [texto, setTexto] = useState('');

  const buscar = (e) => {
    e.preventDefault();
    onBuscar(texto.trim());
  };

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
        <div className="busquedas-populares">
          <span>Búsquedas populares:</span>
          {BUSQUEDAS_POPULARES.map((b) => (
            <button key={b} className="chip" onClick={() => onBuscar(b)}>{b}</button>
          ))}
        </div>
      </section>

      <div className="contenedor">
        <section className="seccion" aria-labelledby="tit-categorias">
          <h2 id="tit-categorias">Explora por categorías principales</h2>
          <div className="grid-4">
            {CATEGORIAS.map((c) => {
              const Icono = ICONOS_CATEGORIA[c.icono];
              return (
                <button key={c.id} className="tarjeta clicable" onClick={() => onCategoria(c.id)}>
                  <span className="icono-cuadro"><Icono size={24} /></span>
                  <h3>{c.nombre}</h3>
                  <p>{c.descripcion}</p>
                </button>
              );
            })}
          </div>
        </section>

        <section className="seccion" aria-labelledby="tit-entidades" style={{ paddingBottom: '4rem' }}>
          <h2 id="tit-entidades">Trámites rápidos de entidades destacadas</h2>
          <div className="grid-4">
            {['SUNAT', 'MINEDU', 'SUNARP', 'ESSALUD'].map((siglas) => {
              const e = entidadPorSiglas(siglas);
              return (
                <button key={siglas} className="tarjeta clicable" onClick={() => onEntidad(siglas)}>
                  <span className="entidad-cab">
                    <span className="entidad-logo" style={{ background: e.color }} aria-hidden="true">
                      {siglas[0]}
                    </span>
                    <span>
                      <strong>{e.siglas}</strong>
                      <span>{e.rubro}</span>
                    </span>
                  </span>
                </button>
              );
            })}
          </div>
        </section>
      </div>
    </>
  );
}
