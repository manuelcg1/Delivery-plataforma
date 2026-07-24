'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { api } from '@/lib/api';
import './platform.css';

type Overview={tenants:number;merchants:number;branches:number;customers:number;couriers:number;orders:number;activeOrders:number;grossSales:number;refunds:number};
const money=(value:number)=>new Intl.NumberFormat('es-PE',{style:'currency',currency:'PEN'}).format(value||0);
export default function PlatformDashboard(){const[data,setData]=useState<Overview|null>(null);const[error,setError]=useState('');useEffect(()=>{api<Overview>('/api/v1/platform/overview').then(setData).catch(e=>setError(e.message))},[]);return <><header className="platform-head"><div><small>PLATFORM OWNER</small><h1>Administración global</h1><p>Visión consolidada de toda la plataforma.</p></div><Link className="button" href="/platform/orders">Ver pedidos</Link></header>{error&&<div className="error">{error}</div>}{!data?<div className="ui-loader">Cargando indicadores…</div>:<section className="platform-grid">{[['Tenants',data.tenants],['Comercios',data.merchants],['Sucursales',data.branches],['Clientes',data.customers],['Repartidores',data.couriers],['Pedidos',data.orders],['Pedidos activos',data.activeOrders],['Venta neta',money(data.grossSales)],['Reembolsos',money(data.refunds)]].map(([label,value])=><article className="panel platform-stat" key={label}><span>{label}</span><strong>{value}</strong></article>)}</section>}</>}
