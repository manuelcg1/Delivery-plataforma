'use client';

import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ApiClientError, api, type FieldErrors } from '@/lib/api';
import { validateNewUser, type NewUserData } from '@/lib/user-validation';

const initialData: NewUserData = { email: '', password: '', firstName: '', lastName: '', phone: '' };

const fields: Array<{ key: keyof NewUserData; label: string; type: string; placeholder: string; helper?: string }> = [
  { key: 'firstName', label: 'Nombre', type: 'text', placeholder: 'Ej. María' },
  { key: 'lastName', label: 'Apellido', type: 'text', placeholder: 'Ej. González' },
  { key: 'email', label: 'Correo electrónico', type: 'email', placeholder: 'nombre@empresa.com' },
  { key: 'phone', label: 'Teléfono', type: 'tel', placeholder: '+51 999 999 999', helper: 'Opcional' },
  { key: 'password', label: 'Contraseña temporal', type: 'password', placeholder: 'Mínimo 10 caracteres', helper: 'El usuario podrá usarla para su primer acceso.' },
];

export default function NewUser() {
  const [data, setData] = useState(initialData);
  const [errors, setErrors] = useState<FieldErrors>({});
  const [formError, setFormError] = useState('');
  const [busy, setBusy] = useState(false);
  const router = useRouter();

  async function submit(event: FormEvent) {
    event.preventDefault();
    const validation = validateNewUser(data);
    setErrors(validation);
    setFormError('');
    if (Object.keys(validation).length) return;

    setBusy(true);
    try {
      await api('/api/v1/users', { method: 'POST', body: JSON.stringify({ ...data, roleIds: [] }) });
      router.push('/users');
    } catch (error) {
      if (error instanceof ApiClientError) {
        setErrors(error.details);
        setFormError(error.message);
      } else {
        setFormError('No se pudo crear el usuario. Inténtalo nuevamente.');
      }
    } finally {
      setBusy(false);
    }
  }

  return <>
    <div className="user-form-heading">
      <p className="eyebrow">IDENTIDAD</p>
      <h1>Nuevo usuario</h1>
      <p>Crea una cuenta para una persona de tu organización.</p>
    </div>
    <form className="panel user-form" onSubmit={submit} noValidate>
      {formError && <div className="form-alert" role="alert"><strong>No pudimos crear el usuario</strong><span>{formError}</span></div>}
      <div className="user-form-grid">
        {fields.map(field => {
          const error = errors[field.key];
          const errorId = `${field.key}-error`;
          const helperId = `${field.key}-helper`;
          return <label className={field.key === 'password' ? 'full' : ''} key={field.key} htmlFor={field.key}>
            <span className="field-label">{field.label}{field.key !== 'phone' && <span aria-hidden="true"> *</span>}</span>
            <input
              id={field.key}
              name={field.key}
              type={field.type}
              autoComplete={field.key === 'password' ? 'new-password' : field.key}
              placeholder={field.placeholder}
              value={data[field.key]}
              disabled={busy}
              aria-invalid={!!error}
              aria-describedby={error ? errorId : field.helper ? helperId : undefined}
              onChange={event => {
                setData(current => ({ ...current, [field.key]: event.target.value }));
                setErrors(current => ({ ...current, [field.key]: '' }));
                setFormError('');
              }}
            />
            {error ? <small className="field-error" id={errorId}>{error}</small> : field.helper ? <small className="field-helper" id={helperId}>{field.helper}</small> : null}
          </label>;
        })}
      </div>
      <div className="form-actions user-form-actions">
        <button type="button" className="ui-button ui-button--outline" disabled={busy} onClick={() => router.push('/users')}>Cancelar</button>
        <button type="submit" disabled={busy} aria-busy={busy}>{busy ? 'Creando usuario…' : 'Crear usuario'}</button>
      </div>
    </form>
  </>;
}
