'use client';

import { FormEvent, useState } from 'react';
import { useAuth } from '@/lib/auth';
import { ApiClientError } from '@/lib/api';

export default function ChangePasswordPage() {
  const { user, changePassword, logout } = useAuth();
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (newPassword !== confirm) return setError('Las contraseñas nuevas no coinciden.');
    setSaving(true); setError('');
    try { await changePassword(currentPassword, newPassword); }
    catch (cause) { setError(cause instanceof ApiClientError ? cause.message : 'No se pudo cambiar la contraseña.'); }
    finally { setSaving(false); }
  }
  if (!user) return <main className="loading">Cargando…</main>;
  return <main className="auth"><form className="card" onSubmit={submit}><h1>Cambia tu contraseña</h1><p>Por seguridad debes definir una contraseña nueva antes de continuar.</p>{error&&<div className="error" role="alert">{error}</div>}<label>Contraseña temporal<input type="password" value={currentPassword} onChange={e=>setCurrentPassword(e.target.value)} required /></label><label>Nueva contraseña<input type="password" minLength={10} value={newPassword} onChange={e=>setNewPassword(e.target.value)} required /></label><label>Confirmar contraseña<input type="password" minLength={10} value={confirm} onChange={e=>setConfirm(e.target.value)} required /></label><button disabled={saving}>{saving?'Guardando…':'Cambiar contraseña'}</button><button type="button" className="secondary" onClick={logout}>Cerrar sesión</button></form></main>;
}
