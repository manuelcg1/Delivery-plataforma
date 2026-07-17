'use client';

import { FormEvent, useState } from 'react';
import { ApiClientError, api, FieldErrors, setAccessToken } from '@/lib/api';
import { useRouter } from 'next/navigation';

const initialData = { tenantName: '', tenantCode: '', adminFirstName: '', adminLastName: '', adminEmail: '', adminPassword: '' };
const labels: Record<keyof typeof initialData, string> = { tenantName: 'Empresa', tenantCode: 'Código', adminFirstName: 'Nombre', adminLastName: 'Apellido', adminEmail: 'Correo', adminPassword: 'Contraseña' };

function validate(data: typeof initialData): FieldErrors {
  const errors: FieldErrors = {};
  if (!data.tenantName.trim()) errors.tenantName = 'Ingresa el nombre de la empresa';
  if (!data.tenantCode.trim()) errors.tenantCode = 'Ingresa el código de la empresa';
  else if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(data.tenantCode)) errors.tenantCode = 'Usa minúsculas, números y guiones, por ejemplo: elite-delivery';
  if (!data.adminFirstName.trim()) errors.adminFirstName = 'Ingresa el nombre del administrador';
  if (!data.adminLastName.trim()) errors.adminLastName = 'Ingresa el apellido del administrador';
  if (!data.adminEmail.trim()) errors.adminEmail = 'Ingresa el correo electrónico';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.adminEmail)) errors.adminEmail = 'Ingresa un correo electrónico válido';
  if (!data.adminPassword) errors.adminPassword = 'Ingresa una contraseña';
  else if (data.adminPassword.length < 10) errors.adminPassword = 'La contraseña debe tener al menos 10 caracteres';
  return errors;
}

export default function Register() {
  const [data, setData] = useState(initialData);
  const [errors, setErrors] = useState<FieldErrors>({});
  const [error, setError] = useState('');
  const router = useRouter();

  async function submit(event: FormEvent) {
    event.preventDefault();
    const validation = validate(data);
    setErrors(validation);
    setError('');
    if (Object.keys(validation).length) return;
    try {
      const result = await api<{ accessToken: string }>('/api/v1/auth/register-tenant', { method: 'POST', body: JSON.stringify(data) }, false);
      setAccessToken(result.accessToken);
      router.push('/dashboard');
    } catch (caught) {
      if (caught instanceof ApiClientError) {
        setErrors(caught.details);
        if (!Object.keys(caught.details).length) setError(caught.message);
      } else setError('No se pudo registrar la empresa');
    }
  }

  return <main className="auth"><form onSubmit={submit} noValidate><h1>Crear empresa</h1>{Object.entries(data).map(([key, value]) => { const field = key as keyof typeof initialData; return <label key={field}>{labels[field]}<input aria-invalid={!!errors[field]} aria-describedby={errors[field] ? `${field}-error` : undefined} type={field.includes('Password') ? 'password' : field.includes('Email') ? 'email' : 'text'} value={value} onChange={event => { setData({ ...data, [field]: event.target.value }); setErrors(current => ({ ...current, [field]: '' })); }} />{errors[field] && <small className="field-error" id={`${field}-error`}>{errors[field]}</small>}</label>; })}{error && <div className="error">{error}</div>}<button>Registrar</button></form></main>;
}
