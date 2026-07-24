'use client';

import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { useRouter } from 'next/navigation';
import { useEffect } from 'react';

export default function Private({ children }: { children: React.ReactNode }) {
  const { user, loading, logout, can } = useAuth();
  const router = useRouter();
  useEffect(() => {
    if (!loading && !user) router.replace('/login');
    if (!loading && user?.mustChangePassword) router.replace('/change-password');
  }, [loading, user, router]);
  if (loading || !user || user.mustChangePassword) return <main className="loading">Cargando…</main>;
  const owner = user.roles.includes('ROLE_PLATFORM_OWNER');
  return <main className="shell"><aside className="sidebar"><div className="brand"><span>D</span><div>Delivery<strong>Platform</strong></div></div><nav>
    {owner ? <><small className="nav-title">ADMINISTRACIÓN GLOBAL</small><Link href="/platform">Resumen global</Link><Link href="/platform/orders">Pedidos</Link><Link href="/platform/merchants">Comercios</Link><Link href="/platform/customers">Clientes</Link><Link href="/platform/couriers">Repartidores</Link><Link href="/platform/transactions">Transacciones</Link><Link href="/platform/settings">Configuración</Link></> : <><Link href="/dashboard">Resumen</Link>{can('ORDERS_CART_VIEW')&&<><small className="nav-title">COMPRAS</small><Link href="/cart">Carrito</Link><Link href="/orders">Mis pedidos</Link></>}{can('PAYMENT_VIEW')&&<><small className="nav-title">OPERACIONES</small><Link href="/payments">Pagos</Link></>}{can('DELIVERY_VIEW')&&<><Link href="/deliveries">Entregas</Link>{can('COURIER_VIEW')&&<Link href="/couriers">Repartidores</Link>}{can('DELIVERY_ZONE_VIEW')&&<Link href="/delivery-zones">Zonas y tarifas</Link>}{can('TRACKING_VIEW')&&<Link href="/tracking">Tracking en vivo</Link>}</>}{can('CATALOG_MERCHANTS_VIEW')&&<><small className="nav-title">CATÁLOGO</small><Link href="/merchants">Comercios</Link></>}{can('CATALOG_BRANCHES_VIEW')&&<Link href="/branches">Sucursales</Link>}{can('CATALOG_CATEGORIES_VIEW')&&<Link href="/categories">Categorías</Link>}{can('CATALOG_INVENTORY_VIEW')&&<Link href="/inventory">Inventario</Link>}{can('IDENTITY_USERS_VIEW')&&<Link href="/users">Usuarios</Link>}{can('IDENTITY_ROLES_VIEW')&&<Link href="/roles">Roles</Link>}{can('IDENTITY_AUDIT_VIEW')&&<Link href="/audit">Auditoría</Link>}</>}
    <Link href="/profile">Perfil</Link></nav><button className="secondary" onClick={logout}>Cerrar sesión</button></aside><section className="content">{children}</section></main>;
}
