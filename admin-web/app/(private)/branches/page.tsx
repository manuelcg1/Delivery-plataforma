'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import { Building2, MapPin, Plus, X } from 'lucide-react';
import { api, ApiClientError, FieldErrors } from '@/lib/api';
import { useAuth } from '@/lib/auth';

type Merchant = { id: string; name: string; code: string; status: string };
type Branch = { id: string; merchantId: string; name: string; code: string; addressLine: string; district: string; phone: string; status: string; timezone: string };
type Page<T> = { content: T[] };

const initial = { merchantId: '', code: '', name: '', addressLine: '', district: '', phone: '', timezone: 'America/Lima' };

export default function BranchesPage() {
  const { can } = useAuth();
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [merchantId, setMerchantId] = useState('');
  const [form, setForm] = useState(initial);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [errors, setErrors] = useState<FieldErrors>({});

  const loadBranches = useCallback(async (merchantIds: string[]) => {
    const lists = await Promise.all(merchantIds.map((id) => api<Branch[]>(`/api/v1/merchants/${id}/branches`)));
    setBranches(lists.flat());
  }, []);

  useEffect(() => {
    api<Page<Merchant>>('/api/v1/merchants?size=100')
      .then(async ({ content }) => { setMerchants(content); await loadBranches(content.map((merchant) => merchant.id)); })
      .catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudieron cargar las sucursales.'))
      .finally(() => setLoading(false));
  }, [loadBranches]);

  function change(field: keyof typeof form, value: string) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: '' }));
  }

  async function create(event: FormEvent) {
    event.preventDefault();
    const nextErrors: FieldErrors = {};
    if (!form.merchantId) nextErrors.merchantId = 'Selecciona el comercio al que pertenecerá la sucursal.';
    if (!form.name.trim()) nextErrors.name = 'Ingresa el nombre de la sucursal.';
    if (!form.code.trim()) nextErrors.code = 'Ingresa un código único.';
    else if (!/^[a-z0-9-]+$/.test(form.code)) nextErrors.code = 'Usa minúsculas, números y guiones.';
    if (!form.addressLine.trim()) nextErrors.addressLine = 'Ingresa la dirección de la sucursal.';
    if (!form.timezone.trim()) nextErrors.timezone = 'Ingresa una zona horaria válida.';
    setErrors(nextErrors);
    if (Object.keys(nextErrors).length) return;
    setSaving(true); setError('');
    try {
      await api(`/api/v1/merchants/${form.merchantId}/branches`, { method: 'POST', body: JSON.stringify({ ...form, latitude: null, longitude: null }) });
      setForm(initial); setShowForm(false);
      await loadBranches(merchants.map((merchant) => merchant.id));
    } catch (cause) {
      if (cause instanceof ApiClientError) { setError(cause.message); setErrors(cause.details); }
      else setError('No se pudo crear la sucursal.');
    } finally { setSaving(false); }
  }

  const visible = merchantId ? branches.filter((branch) => branch.merchantId === merchantId) : branches;
  const merchantName = (id: string) => merchants.find((merchant) => merchant.id === id)?.name ?? 'Comercio';

  return <>
    <div className="title branch-title"><div><p className="eyebrow">CATÁLOGO</p><h1>Sucursales</h1><p className="muted">Administra ubicaciones, direcciones y disponibilidad por comercio.</p></div>{can('CATALOG_BRANCHES_CREATE') && <button onClick={() => setShowForm(true)}><Plus size={18} />Nueva sucursal</button>}</div>
    {error && <div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {showForm && <form className="panel catalog-form branch-form" onSubmit={create} noValidate>
      <div className="branch-form-heading full"><div><h2>Nueva sucursal</h2><p>Completa los datos de la ubicación.</p></div><button type="button" className="button-link" aria-label="Cerrar formulario" onClick={() => { setShowForm(false); setErrors({}); }}><X size={20} /></button></div>
      <label>Comercio<select value={form.merchantId} aria-invalid={!!errors.merchantId} onChange={(event) => change('merchantId', event.target.value)}><option value="">Seleccionar comercio</option>{merchants.map((merchant) => <option key={merchant.id} value={merchant.id}>{merchant.name}</option>)}</select>{errors.merchantId && <small className="field-error">{errors.merchantId}</small>}</label>
      <label>Nombre<input value={form.name} aria-invalid={!!errors.name} onChange={(event) => change('name', event.target.value)} />{errors.name && <small className="field-error">{errors.name}</small>}</label>
      <label>Código<input value={form.code} aria-invalid={!!errors.code} placeholder="miraflores-centro" onChange={(event) => change('code', event.target.value.toLowerCase())} />{errors.code && <small className="field-error">{errors.code}</small>}</label>
      <label>Distrito<input value={form.district} onChange={(event) => change('district', event.target.value)} /></label>
      <label className="full">Dirección<input value={form.addressLine} aria-invalid={!!errors.addressLine} onChange={(event) => change('addressLine', event.target.value)} />{errors.addressLine && <small className="field-error">{errors.addressLine}</small>}</label>
      <label>Teléfono<input value={form.phone} onChange={(event) => change('phone', event.target.value)} /></label>
      <label>Zona horaria<input value={form.timezone} aria-invalid={!!errors.timezone} onChange={(event) => change('timezone', event.target.value)} />{errors.timezone && <small className="field-error">{errors.timezone}</small>}</label>
      <div className="form-actions"><button type="button" className="secondary" onClick={() => { setShowForm(false); setErrors({}); }}>Cancelar</button><button disabled={saving}>{saving ? 'Guardando…' : 'Crear sucursal'}</button></div>
    </form>}
    <div className="toolbar branch-filter"><label>Filtrar por comercio<select value={merchantId} onChange={(event) => setMerchantId(event.target.value)}><option value="">Todos los comercios</option>{merchants.map((merchant) => <option key={merchant.id} value={merchant.id}>{merchant.name}</option>)}</select></label></div>
    <section className="branch-grid">{loading ? <div className="panel empty">Cargando sucursales…</div> : visible.length === 0 ? <div className="panel empty"><Building2 size={34} /><strong>Sin sucursales</strong><span>{merchants.length ? 'Crea la primera sucursal para este comercio.' : 'Primero debes crear un comercio.'}</span></div> : visible.map((branch) => <article className="panel branch-card" key={branch.id}><div className="branch-card-heading"><div className="branch-icon"><Building2 size={20} /></div><span className={`badge ${branch.status.toLowerCase()}`}>{branch.status}</span></div><div><h2>{branch.name}</h2><p>{merchantName(branch.merchantId)} · {branch.code}</p></div><div className="branch-address"><MapPin size={17} /><span>{branch.addressLine}{branch.district ? `, ${branch.district}` : ''}</span></div><Link href={`/merchants/${branch.merchantId}/branches`}>Ver detalle del comercio</Link></article>)}</section>
  </>;
}
