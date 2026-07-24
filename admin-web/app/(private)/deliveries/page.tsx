'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import {
  Bike,
  CheckCircle2,
  Clock3,
  PackageSearch,
  Plus,
  RotateCcw,
  Truck,
  UserRoundPlus,
} from 'lucide-react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import type { Delivery, Page } from '@/lib/operations';
import { money } from '@/lib/orders';
import { Pagination } from '@/components/Pagination';

const statuses = [
  'PENDING', 'SEARCHING_COURIER', 'ASSIGNED', 'ACCEPTED',
  'ARRIVED_AT_MERCHANT', 'PICKED_UP', 'IN_TRANSIT',
  'ARRIVED_AT_CUSTOMER', 'DELIVERED', 'FAILED', 'CANCELLED',
  'REJECTED', 'EXPIRED',
];

const labels: Record<string, string> = {
  PENDING: 'Pendiente', SEARCHING_COURIER: 'Buscando repartidor',
  ASSIGNED: 'Asignada', ACCEPTED: 'Aceptada',
  ARRIVED_AT_MERCHANT: 'En el comercio', PICKED_UP: 'Recogida',
  IN_TRANSIT: 'En camino', ARRIVED_AT_CUSTOMER: 'En destino',
  DELIVERED: 'Entregada', FAILED: 'Fallida', CANCELLED: 'Cancelada',
  REJECTED: 'Rechazada', EXPIRED: 'Expirada',
  MERCHANT_DELIVERY: 'Entrega del comercio',
  PLATFORM_DELIVERY: 'Entrega de plataforma', PICKUP: 'Recojo en tienda',
};

export default function Deliveries() {
  const { can } = useAuth();
  const [data, setData] = useState<Page<Delivery> | null>(null);
  const [page, setPage] = useState(0);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  const load = useCallback(() => {
    setLoading(true);
    setError('');
    return api<Page<Delivery>>(
      `/api/v1/deliveries?page=${page}&size=20${status ? `&status=${status}` : ''}`,
    )
      .then(setData)
      .catch((cause) => setError(
        cause instanceof Error ? cause.message : 'No se pudieron cargar las entregas.',
      ))
      .finally(() => setLoading(false));
  }, [page, status]);

  useEffect(() => { void load(); }, [load]);

  const metrics = useMemo(() => ({
    pending: data?.content.filter((item) =>
      ['PENDING', 'SEARCHING_COURIER'].includes(item.status)).length ?? 0,
    active: data?.content.filter((item) =>
      ['ASSIGNED', 'ACCEPTED', 'ARRIVED_AT_MERCHANT', 'PICKED_UP',
        'IN_TRANSIT', 'ARRIVED_AT_CUSTOMER'].includes(item.status)).length ?? 0,
    done: data?.content.filter((item) => item.status === 'DELIVERED').length ?? 0,
  }), [data]);

  return <>
    <div className="title">
      <div>
        <p className="eyebrow">LOGÍSTICA</p>
        <h1>Entregas</h1>
        <p className="muted">Abre una entrega pendiente para asignar manualmente un repartidor.</p>
      </div>
      {can('DELIVERY_CREATE') && <Link className="button" href="/deliveries/new">
        <Plus size={17} />Nueva entrega
      </Link>}
    </div>

    <section className="delivery-summary">
      <article className="panel"><Truck /><span>Total encontrado</span><strong>{data?.totalElements ?? 0}</strong></article>
      <article className="panel"><Clock3 /><span>Pendientes</span><strong>{metrics.pending}</strong></article>
      <article className="panel"><Bike /><span>En curso</span><strong>{metrics.active}</strong></article>
      <article className="panel"><CheckCircle2 /><span>Entregadas</span><strong>{metrics.done}</strong></article>
    </section>

    {error && <div className="form-alert" role="alert">
      <strong>No se pudieron cargar las entregas</strong><span>{error}</span>
    </div>}

    <div className="operations-filters">
      <label>Estado
        <select value={status} onChange={(event) => { setStatus(event.target.value); setPage(0); }}>
          <option value="">Todos los estados</option>
          {statuses.map((value) => <option value={value} key={value}>{labels[value]}</option>)}
        </select>
      </label>
      {status && <button className="secondary payment-clear" onClick={() => { setStatus(''); setPage(0); }}>
        <RotateCcw size={16} />Limpiar filtro
      </button>}
    </div>

    <section className="panel table">
      {loading ? <div className="ui-loader">Cargando entregas…</div>
        : data?.content.length === 0 ? <div className="empty">
          <PackageSearch size={36} />
          <strong>{status ? 'No hay entregas con este estado' : 'Todavía no hay entregas'}</strong>
          <span>{status ? 'Selecciona otro estado.' : 'Crea una entrega a partir de un pedido pagado o contra entrega.'}</span>
          {status ? <button onClick={() => setStatus('')}>Mostrar todas</button>
            : can('DELIVERY_CREATE') && <Link className="button" href="/deliveries/new">Crear entrega</Link>}
        </div> : data?.content.map((item) => {
          const canAssign = can('DELIVERY_ASSIGN') && !item.courierId
            && item.deliveryType !== 'PICKUP'
            && ['PENDING', 'SEARCHING_COURIER'].includes(item.status);
          return <Link className="tr operation-row" href={`/deliveries/${item.id}`} key={item.id}>
            <span>
              <strong>Pedido {item.orderId.slice(0, 8)}</strong>
              <small>{labels[item.deliveryType] ?? item.deliveryType}</small>
            </span>
            <span>{item.estimatedDurationMinutes ?? '—'} min · {item.distanceKm ?? '—'} km</span>
            <span>{money(item.deliveryFee, item.currency)}</span>
            <span>
              <span className={`order-status order-status--${item.status.toLowerCase()}`}>
                {labels[item.status] ?? item.status}
              </span>
              {canAssign && <small><UserRoundPlus size={14} /> Abrir para asignar</small>}
            </span>
          </Link>;
        })}
    </section>

    {data && data.totalPages > 1 && <Pagination
      page={data.page} totalPages={data.totalPages} first={data.first}
      last={data.last} onPageChange={setPage}
    />}
  </>;
}
