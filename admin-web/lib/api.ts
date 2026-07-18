'use client';

export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:8080';
let accessToken: string | null = null;

export type FieldErrors = Record<string, string>;

export class ApiClientError extends Error {
  constructor(message: string, public readonly details: FieldErrors = {}) {
    super(message);
    this.name = 'ApiClientError';
  }
}

export function setAccessToken(value: string | null) {
  accessToken = value;
}

export async function api<T>(path: string, init: RequestInit = {}, retry = true): Promise<T> {
  const headers = new Headers(init.headers);
  if (accessToken) headers.set('Authorization', `Bearer ${accessToken}`);
  if (init.body && !(init.body instanceof FormData)) headers.set('Content-Type', 'application/json');

  const response = await fetch(`${API_URL}${path}`, { ...init, headers, credentials: 'include' });
  if (response.status === 401 && retry && path !== '/api/v1/auth/refresh') {
    const refreshed = await fetch(`${API_URL}/api/v1/auth/refresh`, { method: 'POST', credentials: 'include' });
    if (refreshed.ok) {
      const data = await refreshed.json();
      setAccessToken(data.accessToken);
      return api<T>(path, init, false);
    }
  }

  if (!response.ok) {
    const text = await response.text();
    const payload = text ? JSON.parse(text) : {};
    throw new ApiClientError(payload.message ?? 'No se pudo completar la operación', payload.details ?? {});
  }
  if (response.status === 204) return undefined as T;
  const text = await response.text();
  return (text ? JSON.parse(text) : null) as T;
}
