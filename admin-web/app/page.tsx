import { getApiHealth } from '@/lib/api';

const cards = [
  ['Pedidos activos', '0', 'Operación inicial'],
  ['Comercios', '0', 'Pendiente de v0.3'],
  ['Repartidores', '0', 'Pendiente de v0.5'],
  ['Tiempo promedio', '—', 'Sin pedidos registrados'],
];

export default async function Home() {
  const health = await getApiHealth();

  return (
    <main className="shell">
      <aside className="sidebar">
        <div className="brand"><span>D</span><div>Delivery<strong>Platform</strong></div></div>
        <nav>
          <a className="active">Resumen</a><a>Pedidos</a><a>Comercios</a><a>Repartidores</a><a>Clientes</a><a>Configuración</a>
        </nav>
        <p className="version">Foundation v0.1</p>
      </aside>
      <section className="content">
        <header>
          <div><p className="eyebrow">OPERACIÓN</p><h1>Panel administrativo</h1><p>Base multicliente preparada para comenzar el desarrollo.</p></div>
          <div className={`status ${health ? 'online' : 'offline'}`}><i />{health ? `API ${health.version} conectada` : 'API sin conexión'}</div>
        </header>
        <div className="grid">
          {cards.map(([label, value, note]) => <article key={label}><p>{label}</p><strong>{value}</strong><small>{note}</small></article>)}
        </div>
        <section className="panel">
          <div><p className="eyebrow">PRIMERA ENTREGA</p><h2>Fundación técnica lista</h2></div>
          <div className="checklist">
            {['PostgreSQL y migraciones Flyway', 'Redis para caché y datos efímeros', 'MinIO para documentos e imágenes', 'Mailpit para pruebas de correo', 'Backend Spring Boot protegido', 'Panel Next.js responsive'].map(item => <div key={item}><b>✓</b>{item}</div>)}
          </div>
        </section>
      </section>
    </main>
  );
}
