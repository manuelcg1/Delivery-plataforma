'use client';

import { use, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, ChevronLeft, Save, ShieldCheck } from 'lucide-react';
import { api, ApiClientError } from '@/lib/api';
import { useAuth } from '@/lib/auth';

type Role = {
  id: string;
  name: string;
  code: string;
  description: string;
  systemRole: boolean;
  active: boolean;
  permissions: string[];
};

type Permission = {
  id: string;
  code: string;
  action: string;
  description: string;
};

type PermissionCatalog = Record<string, Permission[]>;

export default function RoleDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const router = useRouter();
  const { can } = useAuth();
  const [role, setRole] = useState<Role | null>(null);
  const [catalog, setCatalog] = useState<PermissionCatalog>({});
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [initial, setInitial] = useState<Set<string>>(new Set());
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    Promise.all([
      api<Role>(`/api/v1/roles/${id}`),
      api<PermissionCatalog>('/api/v1/roles/permissions/catalog'),
    ])
      .then(([roleData, catalogData]) => {
        setRole(roleData);
        setCatalog(catalogData);
        const ids = new Set(
          Object.values(catalogData)
            .flat()
            .filter((permission) => roleData.permissions.includes(permission.code))
            .map((permission) => permission.id),
        );
        setSelected(ids);
        setInitial(new Set(ids));
      })
      .catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudo cargar el rol.'))
      .finally(() => setLoading(false));
  }, [id]);

  const editable = can('IDENTITY_ROLES_UPDATE') && !role?.systemRole;
  const changed = useMemo(
    () => selected.size !== initial.size || [...selected].some((permissionId) => !initial.has(permissionId)),
    [selected, initial],
  );

  function toggle(permissionId: string) {
    if (!editable) return;
    setSuccess('');
    setSelected((current) => {
      const next = new Set(current);
      if (next.has(permissionId)) next.delete(permissionId);
      else next.add(permissionId);
      return next;
    });
  }

  function toggleModule(permissions: Permission[]) {
    if (!editable) return;
    setSuccess('');
    setSelected((current) => {
      const next = new Set(current);
      const allSelected = permissions.every((permission) => next.has(permission.id));
      permissions.forEach((permission) => allSelected ? next.delete(permission.id) : next.add(permission.id));
      return next;
    });
  }

  async function save() {
    setSaving(true);
    setError('');
    setSuccess('');
    try {
      const updated = await api<Role>(`/api/v1/roles/${id}/permissions`, {
        method: 'PUT',
        body: JSON.stringify({ permissionIds: [...selected] }),
      });
      setRole(updated);
      setInitial(new Set(selected));
      setSuccess('Los permisos del rol se guardaron correctamente.');
    } catch (cause) {
      setError(cause instanceof ApiClientError ? cause.message : 'No se pudieron guardar los permisos.');
    } finally {
      setSaving(false);
    }
  }

  if (loading) return <div className="panel">Cargando permisos…</div>;

  return <>
    <div className="role-heading">
      <button type="button" className="button-link" onClick={() => router.push('/roles')}>
        <ChevronLeft size={18} /> Volver a roles
      </button>
      <div className="title">
        <div>
          <p className="eyebrow">IDENTIDAD Y ACCESO</p>
          <h1>{role?.name ?? 'Rol'}</h1>
          <p className="muted">{role?.description || 'Sin descripción'} · {role?.code}</p>
        </div>
        <span className={`badge ${role?.active ? 'active' : 'inactive'}`}>{role?.active ? 'ACTIVO' : 'INACTIVO'}</span>
      </div>
    </div>

    {error && <div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {success && <div className="role-success" role="status"><Check size={18} /><span>{success}</span></div>}
    {role?.systemRole && <div className="role-notice"><ShieldCheck size={20} /><div><strong>Rol protegido del sistema</strong><span>Sus permisos se muestran como referencia y no pueden modificarse.</span></div></div>}

    <section className="permission-panel panel">
      <div className="permission-heading">
        <div><h2>Permisos asignados</h2><p>Selecciona qué acciones podrán realizar los usuarios que tengan este rol.</p></div>
        <strong>{selected.size} seleccionados</strong>
      </div>
      <div className="permission-modules">
        {Object.entries(catalog).map(([module, permissions]) => {
          const moduleSelected = permissions.every((permission) => selected.has(permission.id));
          return <fieldset className="permission-module" key={module}>
            <legend>
              <label className="permission-module-toggle">
                <input type="checkbox" checked={moduleSelected} disabled={!editable} onChange={() => toggleModule(permissions)} />
                <span>{module}</span><small>{permissions.filter((permission) => selected.has(permission.id)).length}/{permissions.length}</small>
              </label>
            </legend>
            <div className="permission-list">
              {permissions.map((permission) => <label className="permission-item" key={permission.id}>
                <input type="checkbox" checked={selected.has(permission.id)} disabled={!editable} onChange={() => toggle(permission.id)} />
                <span><strong>{permission.description || permission.action}</strong><small>{permission.code}</small></span>
              </label>)}
            </div>
          </fieldset>;
        })}
      </div>
      {editable && <div className="form-actions role-actions">
        <button type="button" className="secondary" onClick={() => router.push('/roles')}>Cancelar</button>
        <button type="button" disabled={!changed || saving} onClick={save}><Save size={17} />{saving ? 'Guardando…' : 'Guardar permisos'}</button>
      </div>}
    </section>
  </>;
}
