import type { Metadata } from 'next';
import './styles.css';

export const metadata: Metadata = {
  title: 'Delivery Platform',
  description: 'Panel administrativo multicliente',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
