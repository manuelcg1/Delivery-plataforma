import type { Metadata } from 'next';
import { GeistSans } from 'geist/font/sans';
import './styles.css';
import './identity.css';
import './catalog.css';
import {AuthProvider} from '@/lib/auth';

export const metadata: Metadata = {
  title: 'Delivery Platform',
  description: 'Panel administrativo multicliente',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es" className={GeistSans.variable}>
      <body><AuthProvider>{children}</AuthProvider></body>
    </html>
  );
}
