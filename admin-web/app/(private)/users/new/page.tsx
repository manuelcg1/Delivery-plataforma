'use client';

import { FormEvent, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Check, ShieldCheck } from 'lucide-react';
import { ApiClientError, api, type FieldErrors } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { validateNewUser, type NewUserData } from '@/lib/user-validation';
import '../role-assignment.css';

type Role = { id: string; code: string; name: string; description?: string; systemRole: boolean; active: boolean; permissions: string[] };
const initialData: NewUserData = { email: '', password: '', firstName: '', lastName: '', phone: '' };
const fields: Array<{ key: keyof NewUserData; label: string; type: string; placeholder: string; helper?: string }> = [
  { key: 'firstName', label: 'Nombre', type: 'text', placeholder: 'Ej. María' },
  { key: 'lastName', label: 'Apellido', type: 'text', placeholder: 'Ej. González' },
  { key: 'email', label: 'Correo electrónico', type: 'email', placeholder: 'nombre@empresa.com' },
  { key: 'phone', label: 'Teléfono', type: 'tel', placeholder: '+51 999 999 999', helper: 'Opcional' },
  { key: 'password', label: 'Contraseña temporal', type: 'password', placeholder: 'Mínimo 10 caracteres', helper: 'El usuario podrá usarla para su primer acceso.' },
];

export default function NewUser() {
  const { can } = useAuth();
  const [data, setData] = useState(initialData);
  const [roles, setRoles] = useState<Role[]>([]);
  const [roleIds, setRoleIds] = useState<string[]>([]);
  const [errors, setErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);
  const router = useRouter();

  useEffect(() => {
    if (can('IDENTITY_ROLES_ASSIGN'))
      api<Role[]>('/api/v1/roles').then((rows) => setRoles(rows.filter((role) => role.active))).catch((cause) => setFormError(cause instanceof Error ? cause.message : 'No se pudieron cargar los roles.'));
  }, [can]);

  function toggleRole(id: string) {
    setRoleIds((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
    setErrors((current) => ({ ...current, roleIds: '' }));
  }

  async function submit(event: FormEvent) {
    event.preventDefault();
    const validation = validateNewUser(data);
    if (can('IDENTITY_ROLES_ASSIGN') && !roleIds.length) validation.roleIds = 'Selecciona al menos un rol para el usuario.';
    setErrors(validation); setFormError('');
    if (Object.keys(validation).length) return;
    setBusy(true);
    try {
      await api('/api/v1/users', { method: 'POST', body: JSON.stringify({ ...data, roleIds }) });
      router.push('/users');
    } catch (error) {
      if (error instanceof ApiClientError) { setErrors(error.details); setFormError(error.message); }
      else setFormError('No se pudo crear el usuario. Inténtalo nuevamente.');
    } finally { setBusy(false); }
  }

  return <>
    <div className="user-form-heading"><p className="eyebrow">IDENTIDAD</p><h1>Nuevo usuario</h1><p>Crea una cuenta y define qué funciones podrá utilizar.</p></div>
    <form className="panel user-form" onSubmit={submit} noValidate>
      {formError && <div className="form-alert" role="alert"><strong>No pudimos crear el usuario</strong><span>{formError}</span></div>}
      <div className="user-form-grid">
        {fields.map((field) => { const error=errors[field.key],errorId=`${field.key}-error`,helperId=`${field.key}-helper`;return <label className={field.key==='password'?'full':''} key={field.key} htmlFor={field.key}><span className="field-label">{field.label}{field.key!=='phone'&&<span aria-hidden="true"> *</span>}</span><input id={field.key} name={field.key} type={field.type} autoComplete={field.key==='password'?'new-password':field.key} placeholder={field.placeholder} value={data[field.key]} disabled={busy} aria-invalid={!!error} aria-describedby={error?errorId:field.helper?helperId:undefined} onChange={(event)=>{setData((current)=>({...current,[field.key]:event.target.value}));setErrors((current)=>({...current,[field.key]:''}));setFormError('');}}/>{error?<small className="field-error" id={errorId}>{error}</small>:field.helper?<small className="field-helper" id={helperId}>{field.helper}</small>:null}</label>;})}
      </div>

      {can('IDENTITY_ROLES_ASSIGN') && <section className="role-assignment"><div className="role-assignment-heading"><ShieldCheck/><div><h2>Rol y permisos</h2><p>Selecciona uno o más perfiles según las responsabilidades del usuario.</p></div></div><div className="role-choice-grid">{roles.map((role)=><button type="button" className={`role-choice ${roleIds.includes(role.id)?'selected':''}`} aria-pressed={roleIds.includes(role.id)} disabled={busy} onClick={()=>toggleRole(role.id)} key={role.id}><span className="role-choice-check">{roleIds.includes(role.id)&&<Check size={15}/>}</span><span><strong>{role.name}</strong><small>{role.description||role.code}</small><em>{role.permissions.length} permisos</em></span></button>)}</div>{!roles.length&&<small className="field-helper">No hay roles activos disponibles.</small>}{errors.roleIds&&<small className="field-error">{errors.roleIds}</small>}</section>}

      <div className="form-actions user-form-actions"><button type="button" className="ui-button ui-button--outline" disabled={busy} onClick={()=>router.push('/users')}>Cancelar</button><button type="submit" disabled={busy} aria-busy={busy}>{busy?'Creando usuario…':'Crear usuario'}</button></div>
    </form>
  </>;
}
