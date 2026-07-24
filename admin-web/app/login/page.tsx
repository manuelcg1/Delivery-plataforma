'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { useAuth } from '@/lib/auth';
import { FieldErrors } from '@/lib/api';

export default function Login() {
  const { login } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [tenantCode, setTenantCode] = useState('');
  const [errors, setErrors] = useState<FieldErrors>({});
  const [error, setError] = useState('');

  async function submit(event: FormEvent) {
    event.preventDefault();
    const validation: FieldErrors = {};
    if (!tenantCode.trim()) validation.tenantCode = 'Ingresa el código de la empresa';
    if (!email.trim()) validation.email = 'Ingresa el correo o nombre de usuario';
    if (!password) validation.password = 'Ingresa la contraseña';
    setErrors(validation);
    setError('');
    if (Object.keys(validation).length) return;
    try { await login({ email, password, tenantCode }); }
    catch (caught) { setError((caught as Error).message); }
  }

  const field = (name: string, label: string, value: string, setter: (value: string) => void, type = 'text') => <label>{label}<input type={type} value={value} aria-invalid={!!errors[name]} aria-describedby={errors[name] ? `${name}-error` : undefined} onChange={event => { setter(event.target.value); setErrors(current => ({ ...current, [name]: '' })); setError(''); }} />{errors[name] && <small className="field-error" id={`${name}-error`}>{errors[name]}</small>}</label>;
  return <main className="auth"><form onSubmit={submit} noValidate><h1>Iniciar sesión</h1><p>Administra tu operación de delivery.</p>{field('tenantCode', 'Empresa', tenantCode, setTenantCode)}{field('email', 'Correo o usuario', email, setEmail)}{field('password', 'Contraseña', password, setPassword, 'password')}{error && <div className="error">{error}</div>}<button>Ingresar</button><div className="links"><Link href="/forgot-password">Olvidé mi contraseña</Link><Link href="/register">Registrar empresa</Link></div></form></main>;
}
