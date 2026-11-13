'use client';

import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { useRouter } from 'next/navigation';
import { useEffect, useState } from 'react';
import { api } from '@/lib/api';

type TenantOption = { id: string; code: string; name: string; status: string };

export default function Private({ children }: { children: React.ReactNode }) {
  const { user, loading, logout, can, switchTenant } = useAuth();
  const router = useRouter();
  const [tenants, setTenants] = useState<TenantOption[]>([]);
  useEffect(() => {
    if (!loading && !user) router.replace('/login');
    if (!loading && user?.mustChangePassword) router.replace('/change-password');
  }, [loading, user, router]);
  useEffect(() => {
    if (!user?.roles.includes('ROLE_PLATFORM_OWNER')) return;
    api<TenantOption[]>('/api/v1/platform/tenants')
      .then(setTenants)
      .catch(() => setTenants([]));
  }, [user?.roles]);
  if (loading || !user || user.mustChangePassword) return <main className="loading">Cargando…</main>;
  const owner = user.roles.includes('ROLE_PLATFORM_OWNER');
  const operationalContext = owner && user.tenant.code !== 'platform';
  const operationalNavigation = <>
    <small className="nav-title">OPERACIÓN · {user.tenant.code}</small>
    <Link href="/dashboard">Resumen operativo</Link>
    {can('ORDERS_CART_VIEW') && <><Link href="/cart">Carrito</Link><Link href="/orders">Pedidos</Link></>}
    {can('PAYMENT_VIEW') && <Link href="/payments">Pagos</Link>}
    {can('DELIVERY_VIEW') && <><Link href="/deliveries">Entregas</Link>{can('COURIER_VIEW') && <Link href="/couriers">Repartidores</Link>}{can('DELIVERY_ZONE_VIEW') && <Link href="/delivery-zones">Zonas y tarifas</Link>}{can('TRACKING_VIEW') && <Link href="/tracking">Tracking en vivo</Link>}</>}
    {can('CATALOG_MERCHANTS_VIEW') && <><small className="nav-title">CATÁLOGO</small><Link href="/merchants">Comercios</Link></>}
    {can('CATALOG_BRANCHES_VIEW') && <Link href="/branches">Sucursales</Link>}
    {can('CATALOG_CATEGORIES_VIEW') && <Link href="/categories">Categorías</Link>}
    {can('CATALOG_INVENTORY_VIEW') && <Link href="/inventory">Inventario</Link>}
    {can('IDENTITY_USERS_VIEW') && <Link href="/users">Usuarios</Link>}
    {can('IDENTITY_ROLES_VIEW') && <Link href="/roles">Roles</Link>}
    {can('IDENTITY_AUDIT_VIEW') && <Link href="/audit">Auditoría</Link>}
  </>;
  return <main className="shell"><aside className="sidebar"><div className="brand"><span>D</span><div>Delivery<strong>Platform</strong></div></div>
    {owner && <label className="tenant-context">Contexto operativo<select aria-label="Contexto operativo" value={operationalContext ? user.tenant.code : 'platform'} onChange={event => { void switchTenant(event.target.value); }}><option value="platform">Plataforma</option>{tenants.map(tenant => <option key={tenant.id} value={tenant.code}>{tenant.name}</option>)}</select></label>}
    <nav>
      {owner && <><small className="nav-title">ADMINISTRACIÓN GLOBAL</small><Link href="/platform">Resumen global</Link><Link href="/platform/orders">Pedidos globales</Link><Link href="/platform/merchants">Comercios globales</Link><Link href="/platform/customers">Clientes</Link><Link href="/platform/couriers">Repartidores</Link><Link href="/platform/transactions">Transacciones</Link><Link href="/platform/settings">Configuración</Link></>}
      {operationalNavigation}
      <Link href="/profile">Perfil</Link>
    </nav><button className="secondary" onClick={logout}>Cerrar sesión</button></aside><section className="content">{children}</section></main>;
}
