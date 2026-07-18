'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { MapPinned, Plus } from 'lucide-react';
import { api, ApiClientError, FieldErrors } from '@/lib/api';
import type { Zone } from '@/lib/operations';
import { money } from '@/lib/orders';

type Merchant = { id: string; name: string; code: string; status: string };
type Branch = { id: string; name: string; code: string; status: string };
type Page<T> = { content: T[] };
type ZoneForm = { merchantId: string; branchId: string; name: string; areas: string; minimum: number; fee: number; minutes: number; description: string };
const initial: ZoneForm = { merchantId: '', branchId: '', name: '', areas: '', minimum: 0, fee: 5, minutes: 30, description: '' };

export default function Zones() {
  const [data, setData] = useState<Zone[]>([]);
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [form, setForm] = useState<ZoneForm>(initial);
  const [errors, setErrors] = useState<FieldErrors>({});
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [saving, setSaving] = useState(false);

  const load = useCallback(() => api<Zone[]>('/api/v1/delivery-zones').then(setData), []);
  useEffect(() => {
    void load().catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudieron cargar las zonas.'));
    api<Page<Merchant>>('/api/v1/merchants?size=100').then((page) => setMerchants(page.content)).catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudieron cargar los comercios.'));
  }, [load]);

  useEffect(() => {
    if (!form.merchantId) { setBranches([]); return; }
    api<Branch[]>(`/api/v1/merchants/${form.merchantId}/branches`)
      .then(setBranches)
      .catch((cause) => { setBranches([]); setError(cause instanceof Error ? cause.message : 'No se pudieron cargar las sucursales.'); });
  }, [form.merchantId]);

  function change<K extends keyof ZoneForm>(field: K, value: ZoneForm[K]) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: '' }));
    setSuccess('');
  }

  async function create(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const next: FieldErrors = {};
    if (!form.merchantId) next.merchantId = 'Selecciona un comercio.';
    if (!form.branchId) next.branchId = 'Selecciona una sucursal.';
    if (!form.name.trim()) next.name = 'Ingresa el nombre de la zona.';
    if (!form.areas.trim()) next.areas = 'Ingresa al menos un distrito.';
    if (form.minimum < 0) next.minimum = 'El pedido mínimo no puede ser negativo.';
    if (form.fee < 0) next.fee = 'La tarifa no puede ser negativa.';
    if (form.minutes < 1) next.minutes = 'El tiempo debe ser de al menos 1 minuto.';
    setErrors(next);
    if (Object.keys(next).length) return;
    setSaving(true); setError(''); setSuccess('');
    try {
      await api('/api/v1/delivery-zones', { method: 'POST', body: JSON.stringify({ merchantId: form.merchantId, branchId: form.branchId, name: form.name.trim(), description: form.description.trim(), zoneType: 'DISTRICT', areas: form.areas.trim(), active: true, minimumOrderAmount: form.minimum, baseDeliveryFee: form.fee, currency: 'PEN', estimatedMinutes: form.minutes }) });
      setForm(initial); setBranches([]); setSuccess('La zona de entrega se creó correctamente.'); await load();
    } catch (cause) {
      if (cause instanceof ApiClientError) { setError(cause.message); setErrors(cause.details); }
      else setError('No se pudo crear la zona. Intenta nuevamente.');
    } finally { setSaving(false); }
  }

  async function disable(id: string) {
    if (!confirm('¿Desactivar esta zona de entrega?')) return;
    try { await api(`/api/v1/delivery-zones/${id}`, { method: 'DELETE' }); await load(); }
    catch (cause) { setError(cause instanceof Error ? cause.message : 'No se pudo desactivar la zona.'); }
  }

  const merchantName = (id: string) => merchants.find((merchant) => merchant.id === id)?.name;
  return <>
    <div className="title"><div><p className="eyebrow">LOGÍSTICA</p><h1>Zonas y tarifas</h1><p className="muted">Define la cobertura por distritos y la tarifa de entrega.</p></div></div>
    {error && <div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {success && <div className="role-success" role="status"><Plus size={18} /><span>{success}</span></div>}
    <form className="panel catalog-form zone-form" onSubmit={create} noValidate>
      <label>Comercio<select value={form.merchantId} aria-invalid={!!errors.merchantId} onChange={(event) => { change('merchantId', event.target.value); change('branchId', ''); }}><option value="">Seleccionar comercio</option>{merchants.map((merchant) => <option key={merchant.id} value={merchant.id}>{merchant.name} · {merchant.status}</option>)}</select>{errors.merchantId && <small className="field-error">{errors.merchantId}</small>}{!merchants.length && <small className="field-helper">No hay comercios registrados. Crea uno desde el módulo Comercios.</small>}</label>
      <label>Sucursal<select value={form.branchId} disabled={!form.merchantId} aria-invalid={!!errors.branchId} onChange={(event) => change('branchId', event.target.value)}><option value="">{form.merchantId ? 'Seleccionar sucursal' : 'Selecciona primero un comercio'}</option>{branches.map((branch) => <option key={branch.id} value={branch.id}>{branch.name} · {branch.status}</option>)}</select>{errors.branchId && <small className="field-error">{errors.branchId}</small>}{form.merchantId && !branches.length && <small className="field-helper">Este comercio no tiene sucursales. Crea una desde el módulo Sucursales.</small>}</label>
      <label>Nombre<input value={form.name} aria-invalid={!!errors.name} placeholder="Zona Miraflores" onChange={(event) => change('name', event.target.value)} />{errors.name && <small className="field-error">{errors.name}</small>}</label>
      <label>Distritos<input value={form.areas} aria-invalid={!!errors.areas} placeholder="Miraflores, San Isidro" onChange={(event) => change('areas', event.target.value)} />{errors.areas && <small className="field-error">{errors.areas}</small>}</label>
      <label>Pedido mínimo<input type="number" min="0" step="0.01" value={form.minimum} aria-invalid={!!errors.minimum} onChange={(event) => change('minimum', Number(event.target.value))} />{errors.minimum && <small className="field-error">{errors.minimum}</small>}</label>
      <label>Tarifa base<input type="number" min="0" step="0.01" value={form.fee} aria-invalid={!!errors.fee} onChange={(event) => change('fee', Number(event.target.value))} />{errors.fee && <small className="field-error">{errors.fee}</small>}</label>
      <label>Tiempo estimado (minutos)<input type="number" min="1" value={form.minutes} aria-invalid={!!errors.minutes} onChange={(event) => change('minutes', Number(event.target.value))} />{errors.minutes && <small className="field-error">{errors.minutes}</small>}</label>
      <label className="full">Descripción<textarea value={form.description} placeholder="Información adicional sobre la cobertura" onChange={(event) => change('description', event.target.value)} /></label>
      <div className="form-actions"><button type="button" className="secondary" onClick={() => { setForm(initial); setBranches([]); setErrors({}); setError(''); }}>Cancelar</button><button disabled={saving || !merchants.length}>{saving ? 'Creando…' : 'Crear zona'}</button></div>
    </form>
    <div className="catalog-cards">{data.length === 0 ? <div className="panel empty zone-empty"><MapPinned size={34} /><strong>Sin zonas de entrega</strong><span>Crea la primera zona para definir tu cobertura.</span></div> : data.map((zone) => <article className="panel action-card" key={zone.id}><span className={`order-status ${zone.active ? '' : 'order-status--cancelled'}`}>{zone.active ? 'ACTIVA' : 'INACTIVA'}</span><strong>{zone.name}</strong>{merchantName(zone.merchantId) && <span>{merchantName(zone.merchantId)}</span>}<span>{zone.areas}</span><span>Desde {money(zone.baseDeliveryFee, zone.currency)} · {zone.estimatedMinutes} min</span>{zone.active && <button className="danger" onClick={() => disable(zone.id)}>Desactivar</button>}</article>)}</div>
  </>;
}
