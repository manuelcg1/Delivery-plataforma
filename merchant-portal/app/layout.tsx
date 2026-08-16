import 'leaflet/dist/leaflet.css';import './styles.css';import {AuthProvider}from'@/lib/auth';import type{Metadata}from'next';
export const metadata:Metadata={title:'Portal de comercios',description:'Operación en tiempo real'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="es"><body><AuthProvider>{children}</AuthProvider></body></html>}
