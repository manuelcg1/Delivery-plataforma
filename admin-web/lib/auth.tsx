'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { api, setAccessToken } from './api';

export type Me = {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  tenant: { id: string; code: string; name: string };
  roles: string[];
  permissions: string[];
  mustChangePassword: boolean;
};

type AuthContext = {
  user: Me | null;
  loading: boolean;
  login: (value: unknown) => Promise<void>;
  changePassword: (currentPassword: string, newPassword: string) => Promise<void>;
  logout: () => Promise<void>;
  can: (permission: string) => boolean;
};

const C = createContext<AuthContext>({
  user: null,
  loading: true,
  login: async () => {},
  changePassword: async () => {},
  logout: async () => {},
  can: () => false,
});

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<Me | null>(null);
  const [loading, setLoading] = useState(true);
  const router = useRouter();

  useEffect(() => {
    api<{ accessToken: string; user: Me }>('/api/v1/auth/refresh', { method: 'POST' })
      .then((session) => {
        setAccessToken(session.accessToken);
        setUser(session.user);
        if (session.user.mustChangePassword) router.replace('/change-password');
      })
      .catch(() => {})
      .finally(() => setLoading(false));
  }, [router]);

  async function login(value: unknown) {
    const session = await api<{ accessToken: string; user: Me }>(
      '/api/v1/auth/login',
      { method: 'POST', body: JSON.stringify(value) },
      false,
    );
    setAccessToken(session.accessToken);
    setUser(session.user);
    router.push(session.user.mustChangePassword ? '/change-password' : session.user.roles.includes('ROLE_PLATFORM_OWNER') ? '/platform' : '/dashboard');
  }

  async function changePassword(currentPassword: string, newPassword: string) {
    await api('/api/v1/auth/change-password', {
      method: 'POST',
      body: JSON.stringify({ currentPassword, newPassword }),
    });
    setUser((current) => current ? { ...current, mustChangePassword: false } : current);
    router.replace(user?.roles.includes('ROLE_PLATFORM_OWNER') ? '/platform' : '/dashboard');
  }

  async function logout() {
    await api('/api/v1/auth/logout', { method: 'POST' }).catch(() => {});
    setAccessToken(null);
    setUser(null);
    router.push('/login');
  }

  return <C.Provider value={{ user, loading, login, changePassword, logout, can: (permission) => !!user?.permissions.includes(permission) }}>{children}</C.Provider>;
}

export const useAuth = () => useContext(C);
