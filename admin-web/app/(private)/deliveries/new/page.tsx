'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import Link from 'next/link';
import { ArrowLeft, Truck } from 'lucide-react';
import { api, ApiClientError, FieldErrors } from '@/lib/api';
import { money, type Order } from '@/lib/orders';

const unavailableStatuses = ['CANCELLED', 'REJECTED', 'DELIVERED'];

export default function NewDelivery() {
  const router = useRouter();
  const [orders, setOrders] = useState<Order[]>([]);
  const [orderId, setOrderId] = useState('');
  const [type, setType] = useState('PLATFORM_DELIVERY');
  const [pickupNotes, setPickupNotes] = useState('');
  const [deliveryNotes, setDeliveryNotes] = useState('');
  const [errors, setErrors] = useState<FieldErrors>({});
  const [loadError, setLoadError] = useState('');
  const [submitError, setSubmitError] = useState('');
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api<Order[]>('/api/v1/orders')
      .then((rows) =>
        setOrders(
          rows.filter((order) => !unavailableStatuses.includes(order.status)),
        ),
      )
      .catch((cause) =>
        setLoadError(
          cause instanceof Error
            ? cause.message
            : 'No se pudieron cargar los pedidos.',
        ),
      )
      .finally(() => setLoading(false));
  }, []);

  async function create(event: FormEvent) {
    event.preventDefault();
    const next: FieldErrors = {};
    if (!orderId) next.orderId = 'Selecciona el pedido que se entregará.';
    setErrors(next);
    if (Object.keys(next).length) return;

    setBusy(true);
    setSubmitError('');
    try {
      const delivery = await api<{ id: string }>(
        `/api/v1/orders/${orderId}/delivery`,
        {
          method: 'POST',
          headers: { 'Idempotency-Key': crypto.randomUUID() },
          body: JSON.stringify({
            deliveryType: type,
            pickupNotes: pickupNotes.trim(),
            deliveryNotes: deliveryNotes.trim(),
          }),
        },
      );
      router.push(`/deliveries/${delivery.id}`);
    } catch (cause) {
      setSubmitError(
        cause instanceof ApiClientError
          ? cause.message
          : 'No se pudo crear la entrega.',
      );
    } finally {
      setBusy(false);
    }
  }

  const selected = orders.find((order) => order.id === orderId);

  return (
    <>
      <Link className="button-link payment-back" href="/deliveries">
        <ArrowLeft size={17} /> Volver a entregas
      </Link>
      <div>
        <p className="eyebrow">LOGÍSTICA</p>
        <h1>Nueva entrega</h1>
        <p className="muted">
          Crea la operación logística para un pedido confirmado.
        </p>
      </div>

      {loadError && (
        <div className="form-alert" role="alert">
          <strong>No se pudieron cargar los pedidos</strong>
          <span>{loadError}</span>
        </div>
      )}
      {submitError && (
        <div className="form-alert" role="alert">
          <strong>No se pudo crear la entrega</strong>
          <span>{submitError}</span>
        </div>
      )}

      <form className="panel create-delivery-form" onSubmit={create} noValidate>
        <div className="create-delivery-heading">
          <Truck size={24} />
          <div>
            <h2>Datos de la entrega</h2>
            <p>
              El pedido debe estar pagado o tener pago contra entrega pendiente.
            </p>
          </div>
        </div>

        <label>
          Pedido
          <select
            value={orderId}
            disabled={loading}
            aria-invalid={!!errors.orderId}
            onChange={(event) => {
              setOrderId(event.target.value);
              setErrors({});
            }}
          >
            <option value="">
              {loading ? 'Cargando pedidos…' : 'Seleccionar pedido'}
            </option>
            {orders.map((order) => (
              <option value={order.id} key={order.id}>
                {order.orderNumber} · {money(order.total, order.currency)} ·{' '}
                {order.paymentStatus}
              </option>
            ))}
          </select>
          {errors.orderId && (
            <small className="field-error">{errors.orderId}</small>
          )}
          {!loading && !loadError && !orders.length && (
            <small className="field-helper">
              No existen pedidos disponibles. Primero completa un pedido y su
              pago.
            </small>
          )}
        </label>

        {selected && (
          <div className="selected-order">
            <span>
              <strong>{selected.orderNumber}</strong>
              <small>
                {selected.items.length} productos · {selected.status}
              </small>
            </span>
            <strong>{money(selected.total, selected.currency)}</strong>
          </div>
        )}

        <label>
          Tipo de entrega
          <select value={type} onChange={(event) => setType(event.target.value)}>
            <option value="PLATFORM_DELIVERY">Entrega de plataforma</option>
            <option value="MERCHANT_DELIVERY">Entrega del comercio</option>
            <option value="PICKUP">Recojo en tienda</option>
          </select>
        </label>
        <label>
          Notas para el recojo
          <textarea
            value={pickupNotes}
            maxLength={500}
            placeholder="Indicaciones para recoger el pedido"
            onChange={(event) => setPickupNotes(event.target.value)}
          />
        </label>
        <label>
          Notas para la entrega
          <textarea
            value={deliveryNotes}
            maxLength={500}
            placeholder="Indicaciones para el repartidor"
            onChange={(event) => setDeliveryNotes(event.target.value)}
          />
        </label>
        <div className="form-actions">
          <button
            type="button"
            className="secondary"
            onClick={() => router.push('/deliveries')}
          >
            Cancelar
          </button>
          <button disabled={busy || !orders.length}>
            {busy ? 'Creando…' : 'Crear entrega'}
          </button>
        </div>
      </form>
    </>
  );
}
