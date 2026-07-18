'use client';

import { FormEvent, useCallback, useEffect, useState } from 'react';
import { Folder, FolderTree, Plus, X } from 'lucide-react';
import { api, ApiClientError, FieldErrors } from '@/lib/api';
import { useAuth } from '@/lib/auth';

type Merchant = { id: string; name: string; code: string };
type Category = { id: string; merchantId: string; parentId: string | null; code: string; name: string; description: string; sortOrder: number; active: boolean };
type Page<T> = { content: T[] };
const initial = { merchantId: '', parentId: '', code: '', name: '', description: '', sortOrder: 0 };

export default function CategoriesPage() {
  const { can } = useAuth();
  const [merchants, setMerchants] = useState<Merchant[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [merchantId, setMerchantId] = useState('');
  const [form, setForm] = useState(initial);
  const [showForm, setShowForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [errors, setErrors] = useState<FieldErrors>({});

  const loadCategories = useCallback(async (ids: string[]) => {
    const data = await Promise.all(ids.map((id) => api<Category[]>(`/api/v1/merchants/${id}/categories`)));
    setCategories(data.flat());
  }, []);

  useEffect(() => {
    api<Page<Merchant>>('/api/v1/merchants?size=100').then(async ({ content }) => {
      setMerchants(content);
      await loadCategories(content.map((merchant) => merchant.id));
    }).catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudieron cargar las categorías.')).finally(() => setLoading(false));
  }, [loadCategories]);

  function change(field: keyof typeof form, value: string | number) {
    setForm((current) => ({ ...current, [field]: value }));
    setErrors((current) => ({ ...current, [field]: '' }));
  }

  async function create(event: FormEvent) {
    event.preventDefault();
    const next: FieldErrors = {};
    if (!form.merchantId) next.merchantId = 'Selecciona el comercio de la categoría.';
    if (!form.name.trim()) next.name = 'Ingresa el nombre de la categoría.';
    if (!form.code.trim()) next.code = 'Ingresa un código único.';
    else if (!/^[a-z0-9-]+$/.test(form.code)) next.code = 'Usa minúsculas, números y guiones.';
    setErrors(next);
    if (Object.keys(next).length) return;
    setSaving(true); setError('');
    try {
      await api(`/api/v1/merchants/${form.merchantId}/categories`, { method: 'POST', body: JSON.stringify({ ...form, parentId: form.parentId || null }) });
      setForm(initial); setShowForm(false);
      await loadCategories(merchants.map((merchant) => merchant.id));
    } catch (cause) {
      if (cause instanceof ApiClientError) { setError(cause.message); setErrors(cause.details); }
      else setError('No se pudo crear la categoría.');
    } finally { setSaving(false); }
  }

  async function toggle(category: Category) {
    setError('');
    try {
      await api(`/api/v1/categories/${category.id}/status`, { method: 'PATCH', body: JSON.stringify({ active: !category.active }) });
      setCategories((current) => current.map((item) => item.id === category.id ? { ...item, active: !item.active } : item));
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'No se pudo cambiar el estado.'); }
  }

  const visible = (merchantId ? categories.filter((category) => category.merchantId === merchantId) : categories).sort((a, b) => a.sortOrder - b.sortOrder || a.name.localeCompare(b.name));
  const parents = categories.filter((category) => category.merchantId === form.merchantId && !category.parentId && category.active);
  const merchantName = (id: string) => merchants.find((merchant) => merchant.id === id)?.name ?? 'Comercio';

  return <>
    <div className="title category-title"><div><p className="eyebrow">CATÁLOGO</p><h1>Categorías</h1><p className="muted">Organiza los productos en categorías y subcategorías por comercio.</p></div>{can('CATALOG_CATEGORIES_CREATE') && <button onClick={() => setShowForm(true)}><Plus size={18} />Nueva categoría</button>}</div>
    {error && <div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {showForm && <form className="panel catalog-form category-form" onSubmit={create} noValidate>
      <div className="category-form-heading full"><div><h2>Nueva categoría</h2><p>Puede ser principal o depender de otra categoría.</p></div><button type="button" className="button-link" aria-label="Cerrar formulario" onClick={() => { setShowForm(false); setErrors({}); }}><X size={20} /></button></div>
      <label>Comercio<select value={form.merchantId} aria-invalid={!!errors.merchantId} onChange={(event) => { change('merchantId', event.target.value); change('parentId', ''); }}><option value="">Seleccionar comercio</option>{merchants.map((merchant) => <option value={merchant.id} key={merchant.id}>{merchant.name}</option>)}</select>{errors.merchantId && <small className="field-error">{errors.merchantId}</small>}</label>
      <label>Categoría superior<select value={form.parentId} disabled={!form.merchantId} onChange={(event) => change('parentId', event.target.value)}><option value="">Ninguna (categoría principal)</option>{parents.map((category) => <option value={category.id} key={category.id}>{category.name}</option>)}</select></label>
      <label>Nombre<input value={form.name} aria-invalid={!!errors.name} onChange={(event) => change('name', event.target.value)} />{errors.name && <small className="field-error">{errors.name}</small>}</label>
      <label>Código<input value={form.code} aria-invalid={!!errors.code} placeholder="platos-principales" onChange={(event) => change('code', event.target.value.toLowerCase())} />{errors.code && <small className="field-error">{errors.code}</small>}</label>
      <label className="full">Descripción<textarea value={form.description} onChange={(event) => change('description', event.target.value)} /></label>
      <label>Orden de visualización<input type="number" min="0" value={form.sortOrder} onChange={(event) => change('sortOrder', Number(event.target.value))} /></label>
      <div className="form-actions"><button type="button" className="secondary" onClick={() => { setShowForm(false); setErrors({}); }}>Cancelar</button><button disabled={saving}>{saving ? 'Guardando…' : 'Crear categoría'}</button></div>
    </form>}
    <div className="toolbar category-filter"><label>Filtrar por comercio<select value={merchantId} onChange={(event) => setMerchantId(event.target.value)}><option value="">Todos los comercios</option>{merchants.map((merchant) => <option value={merchant.id} key={merchant.id}>{merchant.name}</option>)}</select></label></div>
    <section className="panel category-list">{loading ? <div className="empty">Cargando categorías…</div> : visible.length === 0 ? <div className="empty"><FolderTree size={34} /><strong>Sin categorías</strong><span>{merchants.length ? 'Crea la primera categoría para organizar tus productos.' : 'Primero debes crear un comercio.'}</span></div> : visible.map((category) => <article className={`category-row ${category.parentId ? 'category-row-child' : ''}`} key={category.id}><div className="category-folder"><Folder size={19} /></div><div className="category-info"><strong>{category.name}</strong><small>{merchantName(category.merchantId)} · {category.code}</small>{category.description && <span>{category.description}</span>}</div><span className={`badge ${category.active ? 'active' : 'inactive'}`}>{category.active ? 'ACTIVA' : 'INACTIVA'}</span>{can('CATALOG_CATEGORIES_UPDATE') && <button className="category-status" onClick={() => toggle(category)}>{category.active ? 'Desactivar' : 'Activar'}</button>}</article>)}</section>
  </>;
}
