'use client';

import { FormEvent, use, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, Save, ShieldCheck } from 'lucide-react';
import { api, ApiClientError } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import '../role-assignment.css';

type User = { id: string; firstName: string; lastName: string; phone?: string; email: string; status: string; roles: string[] };
type Role = { id: string; code: string; name: string; description?: string; systemRole: boolean; active: boolean; permissions: string[] };

export default function EditUser({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const { can } = useAuth();
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [roles, setRoles] = useState<Role[]>([]);
  const [roleIds, setRoleIds] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    Promise.all([api<User>(`/api/v1/users/${id}`), api<Role[]>('/api/v1/roles')])
      .then(([current, available]) => {
        setUser(current); setRoles(available.filter((role) => role.active));
        setRoleIds(available.filter((role) => current.roles.includes(role.code)).map((role) => role.id));
      })
      .catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudo cargar el usuario.'));
  }, [id]);

  function toggleRole(roleId: string) {
    setRoleIds((current) => current.includes(roleId) ? current.filter((value) => value !== roleId) : [...current, roleId]);
    setSuccess('');
  }

  async function saveProfile(event: FormEvent) {
    event.preventDefault(); if (!user) return; setBusy(true); setError(''); setSuccess('');
    try {
      const updated = await api<User>(`/api/v1/users/${id}`, { method: 'PUT', body: JSON.stringify({ firstName: user.firstName, lastName: user.lastName, phone: user.phone }) });
      setUser(updated); setSuccess('Los datos del usuario se guardaron correctamente.');
    } catch (cause) { setError(cause instanceof ApiClientError ? cause.message : 'No se pudieron guardar los datos.'); }
    finally { setBusy(false); }
  }

  async function saveRoles() {
    if (!roleIds.length) { setError('Selecciona al menos un rol para el usuario.'); return; }
    setBusy(true); setError(''); setSuccess('');
    try {
      const updated = await api<User>(`/api/v1/users/${id}/roles`, { method: 'PUT', body: JSON.stringify({ roleIds }) });
      setUser(updated); setSuccess('Los roles y permisos se actualizaron correctamente.');
    } catch (cause) { setError(cause instanceof ApiClientError ? cause.message : 'No se pudieron actualizar los roles.'); }
    finally { setBusy(false); }
  }

  if (!user) return error ? <div className="form-alert" role="alert"><strong>No se pudo cargar el usuario</strong><span>{error}</span></div> : <div className="ui-loader">Cargando usuario…</div>;
  return <>
    <div className="title"><div><p className="eyebrow">IDENTIDAD</p><h1>Editar usuario</h1><p className="muted">Actualiza sus datos y responsabilidades dentro de la plataforma.</p></div></div>
    {error&&<div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {success&&<div className="role-success" role="status"><Check size={18}/><span>{success}</span></div>}
    <div className="user-edit-layout">
      <form className="panel user-edit-form" onSubmit={saveProfile}>
        <h2>Información personal</h2>
        <div className="user-edit-meta"><span>{user.email}</span><strong>{user.status}</strong></div>
        <label>Nombre<input value={user.firstName} disabled={busy||!can('IDENTITY_USERS_UPDATE')} onChange={(event)=>setUser({...user,firstName:event.target.value})}/></label>
        <label>Apellido<input value={user.lastName} disabled={busy||!can('IDENTITY_USERS_UPDATE')} onChange={(event)=>setUser({...user,lastName:event.target.value})}/></label>
        <label>Teléfono<input value={user.phone??''} disabled={busy||!can('IDENTITY_USERS_UPDATE')} onChange={(event)=>setUser({...user,phone:event.target.value})}/></label>
        <div className="form-actions"><button type="button" className="secondary" onClick={()=>router.push('/users')}>Cancelar</button>{can('IDENTITY_USERS_UPDATE')&&<button disabled={busy}><Save size={16}/>Guardar datos</button>}</div>
      </form>

      <section className="panel role-assignment">
        <div className="role-assignment-heading"><ShieldCheck/><div><h2>Roles asignados</h2><p>Los permisos se combinan cuando seleccionas más de un rol.</p></div></div>
        <div className="role-choice-grid">{roles.map((role)=><button type="button" className={`role-choice ${roleIds.includes(role.id)?'selected':''}`} aria-pressed={roleIds.includes(role.id)} disabled={busy||!can('IDENTITY_ROLES_ASSIGN')} onClick={()=>toggleRole(role.id)} key={role.id}><span className="role-choice-check">{roleIds.includes(role.id)&&<Check size={15}/>}</span><span><strong>{role.name}</strong><small>{role.description||role.code}</small><em>{role.permissions.length} permisos</em></span></button>)}</div>
        {!can('IDENTITY_ROLES_ASSIGN')&&<small className="field-helper">No tienes permiso para cambiar roles.</small>}
        {can('IDENTITY_ROLES_ASSIGN')&&<div className="role-save-actions"><button className="secondary" type="button" disabled={busy} onClick={()=>router.push('/users')}>Cancelar</button><button type="button" disabled={busy||!roleIds.length} onClick={saveRoles}><ShieldCheck size={16}/>Guardar roles</button></div>}
      </section>
    </div>
  </>;
}
