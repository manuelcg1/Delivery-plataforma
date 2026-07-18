'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  ArrowRight,
  Bike,
  Boxes,
  CircleDollarSign,
  PackageCheck,
  ReceiptText,
  RefreshCw,
  ShoppingBag,
  Users,
} from 'lucide-react';
import { api } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { money, statusLabel, type Order } from '@/lib/orders';
import type { Courier, Delivery, Page, Payment } from '@/lib/operations';
import './dashboard.css';

type Stock = {
  productId: string;
  productName: string;
  quantity: number;
  lowStock: boolean;
};
type User = { id: string; status: string };
type Activity = {
  id: string;
  title: string;
  detail: string;
  date: string;
  href: string;
  type: 'order' | 'payment' | 'delivery';
};

export default function Dashboard() {
  const { user, can } = useAuth();
  const [orders, setOrders] = useState<Order[]>([]);
  const [payments, setPayments] = useState<Payment[]>([]);
  const [deliveries, setDeliveries] = useState<Delivery[]>([]);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [stock, setStock] = useState<Stock[]>([]);
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [reload, setReload] = useState(0);

  useEffect(() => {
    const requests: Promise<unknown>[] = [];
    if (can('ORDERS_VIEW'))
      requests.push(api<Order[]>('/api/v1/orders').then(setOrders));
    if (can('PAYMENT_VIEW'))
      requests.push(
        api<Page<Payment>>('/api/v1/payments?page=0&size=100').then((page) =>
          setPayments(page.content),
        ),
      );
    if (can('DELIVERY_VIEW'))
      requests.push(
        api<Page<Delivery>>('/api/v1/deliveries?page=0&size=100').then(
          (page) => setDeliveries(page.content),
        ),
      );
    if (can('COURIER_VIEW'))
      requests.push(api<Courier[]>('/api/v1/couriers').then(setCouriers));
    if (can('CATALOG_INVENTORY_VIEW'))
      requests.push(
        api<Page<Stock>>('/api/v1/inventory?page=0&size=100').then((page) =>
          setStock(page.content),
        ),
      );
    if (can('IDENTITY_USERS_VIEW'))
      requests.push(api<User[]>('/api/v1/users').then(setUsers));

    setLoading(true);
    setError('');
    Promise.allSettled(requests)
      .then((results) => {
        if (results.some((result) => result.status === 'rejected'))
          setError('Algunos indicadores no pudieron actualizarse.');
      })
      .finally(() => setLoading(false));
  }, [can, reload]);

  const today = useMemo(() => {
    const now = new Date();
    return (value: string) => {
      const date = new Date(value);
      return (
        date.getFullYear() === now.getFullYear() &&
        date.getMonth() === now.getMonth() &&
        date.getDate() === now.getDate()
      );
    };
  }, []);

  const paidToday = payments.filter(
    (payment) => payment.status === 'PAID' && today(payment.createdAt),
  );
  const salesToday = paidToday.reduce(
    (total, payment) => total + Number(payment.capturedAmount),
    0,
  );
  const activeDeliveries = deliveries.filter((delivery) =>
    [
      'PENDING',
      'SEARCHING_COURIER',
      'ASSIGNED',
      'ACCEPTED',
      'ARRIVED_AT_MERCHANT',
      'PICKED_UP',
      'IN_TRANSIT',
      'ARRIVED_AT_CUSTOMER',
    ].includes(delivery.status),
  );
  const unassigned = deliveries.filter(
    (delivery) =>
      !delivery.courierId &&
      delivery.deliveryType !== 'PICKUP' &&
      ['PENDING', 'SEARCHING_COURIER'].includes(delivery.status),
  );
  const failedPayments = payments.filter((payment) => payment.status === 'FAILED');
  const lowStock = stock.filter((item) => item.lowStock);
  const availableCouriers = couriers.filter(
    (courier) => courier.status === 'ACTIVE' && courier.availability === 'ONLINE',
  );

  const activity = useMemo<Activity[]>(
    () =>
      [
        ...orders.map((order) => ({
          id: `order-${order.id}`,
          title: order.orderNumber,
          detail: `${statusLabel[order.status]} · ${money(order.total, order.currency)}`,
          date: order.createdAt,
          href: `/orders/${order.id}`,
          type: 'order' as const,
        })),
        ...payments.map((payment) => ({
          id: `payment-${payment.id}`,
          title: `Pago ${payment.status}`,
          detail: `${payment.paymentMethod} · ${money(payment.amount, payment.currency)}`,
          date: payment.createdAt,
          href: `/payments/${payment.id}`,
          type: 'payment' as const,
        })),
        ...deliveries.map((delivery) => ({
          id: `delivery-${delivery.id}`,
          title: `Entrega ${delivery.status}`,
          detail: delivery.deliveryType.replaceAll('_', ' '),
          date: delivery.createdAt,
          href: `/deliveries/${delivery.id}`,
          type: 'delivery' as const,
        })),
      ]
        .sort((a, b) => +new Date(b.date) - +new Date(a.date))
        .slice(0, 6),
    [deliveries, orders, payments],
  );

  return (
    <>
      <header className="dashboard-heading">
        <div>
          <p className="eyebrow">RESUMEN OPERATIVO</p>
          <h1>Hola, {user?.firstName}</h1>
          <p className="muted">
            Estado de {user?.tenant.name} actualizado en tiempo real.
          </p>
        </div>
        <button
          className="secondary dashboard-refresh"
          disabled={loading}
          onClick={() => setReload((value) => value + 1)}
        >
          <RefreshCw size={17} className={loading ? 'is-spinning' : ''} />
          Actualizar
        </button>
      </header>

      {error && (
        <div className="form-alert" role="alert">
          <strong>Información parcialmente disponible</strong>
          <span>{error}</span>
        </div>
      )}

      <section className="dashboard-metrics" aria-label="Indicadores principales">
        {can('ORDERS_VIEW') && (
          <Link href="/orders" className="panel dashboard-metric">
            <ShoppingBag />
            <span>Pedidos de hoy</span>
            <strong>{orders.filter((order) => today(order.createdAt)).length}</strong>
            <small>{orders.filter((order) => order.status === 'CONFIRMED').length} confirmados</small>
          </Link>
        )}
        {can('PAYMENT_VIEW') && (
          <Link href="/payments" className="panel dashboard-metric">
            <CircleDollarSign />
            <span>Ventas de hoy</span>
            <strong>{money(salesToday)}</strong>
            <small>{paidToday.length} pagos confirmados</small>
          </Link>
        )}
        {can('DELIVERY_VIEW') && (
          <Link href="/deliveries" className="panel dashboard-metric">
            <PackageCheck />
            <span>Entregas activas</span>
            <strong>{activeDeliveries.length}</strong>
            <small>{unassigned.length} sin repartidor</small>
          </Link>
        )}
        {can('COURIER_VIEW') && (
          <Link href="/couriers" className="panel dashboard-metric">
            <Bike />
            <span>Repartidores disponibles</span>
            <strong>{availableCouriers.length}</strong>
            <small>{couriers.length} registrados</small>
          </Link>
        )}
        {can('CATALOG_INVENTORY_VIEW') && (
          <Link href="/inventory" className="panel dashboard-metric">
            <Boxes />
            <span>Stock bajo</span>
            <strong>{lowStock.length}</strong>
            <small>{stock.length} productos controlados</small>
          </Link>
        )}
        {can('IDENTITY_USERS_VIEW') && (
          <Link href="/users" className="panel dashboard-metric">
            <Users />
            <span>Usuarios activos</span>
            <strong>{users.filter((item) => item.status === 'ACTIVE').length}</strong>
            <small>{users.length} usuarios registrados</small>
          </Link>
        )}
      </section>

      <div className="dashboard-columns">
        <section className="panel dashboard-activity">
          <div className="dashboard-section-heading">
            <div>
              <h2>Actividad reciente</h2>
              <p>Últimos movimientos operativos.</p>
            </div>
            <ReceiptText />
          </div>
          {loading && !activity.length ? (
            <div className="ui-loader">Cargando actividad…</div>
          ) : !activity.length ? (
            <div className="empty">Aún no hay actividad registrada.</div>
          ) : (
            <div className="dashboard-activity-list">
              {activity.map((item) => (
                <Link href={item.href} key={item.id}>
                  <i className={`activity-icon activity-icon--${item.type}`} />
                  <span>
                    <strong>{item.title}</strong>
                    <small>{item.detail}</small>
                  </span>
                  <time>{new Date(item.date).toLocaleString('es-PE')}</time>
                  <ArrowRight size={16} />
                </Link>
              ))}
            </div>
          )}
        </section>

        <aside className="stack">
          <section className="panel dashboard-alerts">
            <div className="dashboard-section-heading">
              <div>
                <h2>Requiere atención</h2>
                <p>Situaciones que pueden bloquear la operación.</p>
              </div>
              <AlertTriangle />
            </div>
            {can('DELIVERY_VIEW') && (
              <Link href="/deliveries">
                <span>Entregas sin repartidor</span><strong>{unassigned.length}</strong>
              </Link>
            )}
            {can('PAYMENT_VIEW') && (
              <Link href="/payments?status=FAILED">
                <span>Pagos fallidos</span><strong>{failedPayments.length}</strong>
              </Link>
            )}
            {can('CATALOG_INVENTORY_VIEW') && (
              <Link href="/inventory">
                <span>Productos con stock bajo</span><strong>{lowStock.length}</strong>
              </Link>
            )}
          </section>

          <section className="panel dashboard-actions">
            <h2>Acciones rápidas</h2>
            {can('ORDERS_CART_VIEW') && <Link href="/cart">Crear pedido <ArrowRight size={16} /></Link>}
            {can('DELIVERY_CREATE') && <Link href="/deliveries/new">Crear entrega <ArrowRight size={16} /></Link>}
            {can('COURIER_MANAGE') && <Link href="/couriers">Agregar repartidor <ArrowRight size={16} /></Link>}
            {can('CATALOG_MERCHANTS_CREATE') && <Link href="/merchants/new">Agregar comercio <ArrowRight size={16} /></Link>}
          </section>
        </aside>
      </div>
    </>
  );
}
