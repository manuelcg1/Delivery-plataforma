'use client';

import Link from 'next/link';
import { use, useEffect, useState } from 'react';
import { ArrowLeft, Clock3, Crosshair, MapPin, Navigation } from 'lucide-react';
import { api } from '@/lib/api';
import type { CourierLocation } from '@/lib/tracking';
import './history.css';

export default function CourierHistory({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [rows, setRows] = useState<CourierLocation[]>([]);
  const [error, setError] = useState('');
  useEffect(() => { api<CourierLocation[]>(`/api/v1/tracking/couriers/${id}/history`).then(setRows).catch((cause) => setError(cause instanceof Error ? cause.message : 'No se pudo cargar el historial.')); }, [id]);
  return <>
    <Link className="button-link payment-back" href="/tracking"><ArrowLeft size={17}/>Volver al mapa</Link>
    <div><p className="eyebrow">HISTORIAL GPS</p><h1>Recorrido del repartidor</h1><p className="muted">Registro permanente de posiciones recibidas.</p></div>
    {error && <div className="form-alert" role="alert"><strong>No se pudo cargar el recorrido</strong><span>{error}</span></div>}
    <section className="panel tracking-history">{rows.length===0?<div className="empty">No hay posiciones registradas para este repartidor.</div>:rows.map((point)=><article key={point.id}><i/><span><strong><MapPin size={15}/>{Number(point.latitude).toFixed(6)}, {Number(point.longitude).toFixed(6)}</strong><small><Clock3 size={14}/>{new Date(point.gpsTimestamp).toLocaleString('es-PE')}</small></span><span><Crosshair size={15}/>Precisión ±{point.accuracy} m</span><span><Navigation size={15}/>Velocidad {point.speed??0} km/h</span><a href={`https://www.openstreetmap.org/?mlat=${point.latitude}&mlon=${point.longitude}#map=17/${point.latitude}/${point.longitude}`} target="_blank" rel="noreferrer">Ver posición</a></article>)}</section>
  </>;
}
