'use client';

import Link from 'next/link';
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Battery, Bike, Crosshair, History, MapPin, RefreshCw, Route } from 'lucide-react';
import { api } from '@/lib/api';
import type { Courier } from '@/lib/operations';
import type { CourierLocation } from '@/lib/tracking';
import './tracking.css';

export default function TrackingMap() {
  const [locations, setLocations] = useState<CourierLocation[]>([]);
  const [couriers, setCouriers] = useState<Courier[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const [points, profiles] = await Promise.all([
        api<CourierLocation[]>('/api/v1/tracking/couriers'),
        api<Courier[]>('/api/v1/couriers'),
      ]);
      setLocations(points);
      setCouriers(profiles);
      setError('');
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'No se pudo actualizar el mapa.');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
    const timer = window.setInterval(() => void load(), 5000);
    return () => window.clearInterval(timer);
  }, [load]);

  const online = couriers.filter((courier) => courier.availability === 'ONLINE').length;
  const active = useMemo(
    () => locations.filter((point) => Date.now() - +new Date(point.receivedAt) < 120000),
    [locations],
  );
  const positions = useMemo(() => {
    if (!locations.length) return new Map<string, { left: number; top: number }>();
    const latitudes = locations.map((point) => Number(point.latitude));
    const longitudes = locations.map((point) => Number(point.longitude));
    const minLat = Math.min(...latitudes), maxLat = Math.max(...latitudes);
    const minLon = Math.min(...longitudes), maxLon = Math.max(...longitudes);
    return new Map(
      locations.map((point) => [point.id, {
        left: 12 + ((Number(point.longitude) - minLon) / Math.max(maxLon - minLon, 0.00001)) * 76,
        top: 12 + ((maxLat - Number(point.latitude)) / Math.max(maxLat - minLat, 0.00001)) * 76,
      }]),
    );
  }, [locations]);

  return <>
    <div className="title tracking-title">
      <div><p className="eyebrow">TIEMPO REAL</p><h1>Mapa general</h1><p className="muted">Ubicación de repartidores actualizada cada 5 segundos.</p></div>
      <button className="secondary" onClick={() => void load()} disabled={loading}><RefreshCw size={17}/>Actualizar</button>
    </div>
    {error && <div className="form-alert" role="alert"><strong>No se pudo actualizar el tracking</strong><span>{error}</span></div>}
    <section className="tracking-summary">
      <article className="panel"><Bike/><span>En línea</span><strong>{online}</strong></article>
      <article className="panel"><Crosshair/><span>Transmitiendo</span><strong>{active.length}</strong></article>
      <article className="panel"><Route/><span>Ubicaciones</span><strong>{locations.length}</strong></article>
    </section>
    <section className="panel live-map" aria-label="Mapa de repartidores">
      <div className="map-grid"/>
      {locations.length === 0 ? (
        <div className="map-empty"><MapPin/><strong>Sin ubicaciones GPS</strong><span>Los marcadores aparecerán cuando un repartidor comparta su ubicación.</span></div>
      ) : locations.map((point) => {
        const profile = couriers.find((item) => item.id === point.courierId);
        const position = positions.get(point.id) ?? { left: 50, top: 50 };
        return <a className="map-marker" style={{ left: `${position.left}%`, top: `${position.top}%` }} href={`https://www.openstreetmap.org/?mlat=${point.latitude}&mlon=${point.longitude}#map=16/${point.latitude}/${point.longitude}`} target="_blank" rel="noreferrer" title={`${profile?.name ?? 'Repartidor'}: ${point.latitude}, ${point.longitude}`} key={point.id}><Bike size={18}/></a>;
      })}
      <span className="map-provider">OpenStreetMap · vista de coordenadas</span>
    </section>
    <section className="panel tracking-table">
      <div className="dashboard-section-heading"><div><h2>Repartidores localizados</h2><p>Precisión, batería y última transmisión.</p></div><History/></div>
      {locations.length === 0 ? <div className="empty">No se han recibido ubicaciones.</div> : locations.map((point) => {
        const courier = couriers.find((item) => item.id === point.courierId);
        return <div className="tracking-row" key={point.id}>
          <span><strong>{courier?.name ?? point.courierId.slice(0, 8)}</strong><small>{courier?.vehicleType ?? 'Vehículo no identificado'}</small></span>
          <span><MapPin size={15}/>{Number(point.latitude).toFixed(5)}, {Number(point.longitude).toFixed(5)}</span>
          <span><Crosshair size={15}/>± {point.accuracy} m</span><span><Battery size={15}/>{point.batteryLevel ?? '—'}%</span>
          <time>{new Date(point.receivedAt).toLocaleString('es-PE')}</time><Link href={`/tracking/couriers/${point.courierId}`}>Historial</Link>
        </div>;
      })}
    </section>
  </>;
}
