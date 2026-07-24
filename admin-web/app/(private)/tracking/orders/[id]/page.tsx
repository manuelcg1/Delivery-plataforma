'use client';

import Link from 'next/link';
import { FormEvent, use, useCallback, useEffect, useState } from 'react';
import { ArrowLeft, Battery, Clock3, KeyRound, MapPin, MessageCircle, QrCode, ShieldCheck, Upload } from 'lucide-react';
import { api, ApiClientError } from '@/lib/api';
import type { ChatMessage, DeliveryProof, Tracking } from '@/lib/tracking';
import './order-tracking.css';

export default function OrderTracking({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  const [tracking, setTracking] = useState<Tracking | null>(null);
  const [proofs, setProofs] = useState<DeliveryProof[]>([]);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [message, setMessage] = useState('');
  const [proofType, setProofType] = useState('PHOTO');
  const [file, setFile] = useState<File | null>(null);
  const [temporary, setTemporary] = useState('');
  const [error, setError] = useState('');

  const load = useCallback(async () => {
    try {
      const current = await api<Tracking>(`/api/v1/orders/${id}/tracking`);
      setTracking(current);
      const [availableProofs, chat] = await Promise.all([
        api<DeliveryProof[]>(`/api/v1/orders/${id}/proof`).catch(() => []),
        api<ChatMessage[]>(`/api/v1/chat/history?deliveryId=${current.deliveryId}`).catch(() => []),
      ]);
      setProofs(availableProofs); setMessages(chat); setError('');
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'No se pudo cargar el tracking.'); }
  }, [id]);
  useEffect(() => { void load(); const timer=window.setInterval(()=>void load(),5000); return()=>window.clearInterval(timer); }, [load]);

  async function upload(event: FormEvent) {
    event.preventDefault(); if (!file) return;
    const body = new FormData(); body.append('file', file);
    try { await api(`/api/v1/orders/${id}/proof?type=${proofType}`, { method:'POST', body }); setFile(null); await load(); }
    catch(cause){setError(cause instanceof ApiClientError?cause.message:'No se pudo subir la prueba.');}
  }
  async function generate(kind:'otp'|'qr'){try{const result=await api<{value:string}>(`/api/v1/orders/${id}/${kind}`,{method:'POST'});setTemporary(result.value);}catch(cause){setError(cause instanceof Error?cause.message:'No se pudo generar el código.');}}
  async function send(event:FormEvent){event.preventDefault();if(!tracking||!message.trim())return;try{await api('/api/v1/chat/messages',{method:'POST',body:JSON.stringify({deliveryId:tracking.deliveryId,channel:'CUSTOMER_COURIER',message:message.trim()})});setMessage('');await load();}catch(cause){setError(cause instanceof Error?cause.message:'No se pudo enviar el mensaje.');}}

  if (!tracking && !error) return <div className="ui-loader">Cargando seguimiento…</div>;
  return <>
    <Link className="button-link payment-back" href="/deliveries"><ArrowLeft size={17}/>Volver a entregas</Link>
    <div className="title"><div><p className="eyebrow">TRACKING</p><h1>Seguimiento del pedido</h1><p className="muted">Posición, ETA, evidencias y comunicación en una sola vista.</p></div>{tracking&&<span className={`order-status order-status--${tracking.status.toLowerCase()}`}>{tracking.status}</span>}</div>
    {error&&<div className="form-alert" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {tracking&&<div className="order-tracking-layout"><section className="stack"><div className="panel tracking-live-card"><div className="tracking-courier"><span><strong>{tracking.courierName??'Sin repartidor asignado'}</strong><small>{tracking.vehicleType??tracking.deliveryType}</small></span><span><Clock3/>ETA {tracking.eta?.estimatedMinutes||'—'} min</span></div><div className="tracking-coordinate-map"><i/><div>{tracking.location?<><strong><MapPin/>Ubicación actual</strong><span>{Number(tracking.location.latitude).toFixed(6)}, {Number(tracking.location.longitude).toFixed(6)}</span><small>Precisión ±{tracking.location.accuracy} m · <Battery size={13}/>{tracking.location.batteryLevel??'—'}%</small></>:<><strong>Esperando ubicación GPS</strong><span>El repartidor aún no transmite su posición.</span></>}</div></div><dl className="detail-list"><div><dt>Destino</dt><dd>{tracking.addressLine??'—'}, {tracking.district??'—'}</dd></div><div><dt>Distancia restante</dt><dd>{tracking.eta?.distanceRemainingKm??'—'} km</dd></div><div><dt>Última actualización</dt><dd>{new Date(tracking.location?.receivedAt??tracking.updatedAt).toLocaleString('es-PE')}</dd></div></dl></div>
      <div className="panel"><div className="dashboard-section-heading"><div><h2>Pruebas de entrega</h2><p>Fotografías, firmas y validaciones.</p></div><ShieldCheck/></div><div className="proof-grid">{proofs.map((proof)=><article key={proof.id}>{proof.url?<a href={proof.url} target="_blank" rel="noreferrer"><img src={proof.url} alt={`Prueba ${proof.proofType}`}/></a>:<ShieldCheck/>}<strong>{proof.proofType}</strong><small>{new Date(proof.createdAt).toLocaleString('es-PE')}</small></article>)}</div><form className="proof-upload" onSubmit={upload}><select value={proofType} onChange={(event)=>setProofType(event.target.value)}><option value="PHOTO">Fotografía</option><option value="SIGNATURE">Firma</option></select><input type="file" accept="image/jpeg,image/png,image/webp" onChange={(event)=>setFile(event.target.files?.[0]??null)}/><button disabled={!file}><Upload size={16}/>Subir prueba</button></form></div></section>
      <aside className="stack"><section className="panel code-actions"><h2>Confirmación segura</h2><p className="muted">Genera un código temporal para validar la entrega.</p><button className="secondary" onClick={()=>generate('otp')}><KeyRound size={17}/>Generar OTP</button><button className="secondary" onClick={()=>generate('qr')}><QrCode size={17}/>Generar token QR</button>{temporary&&<div className="temporary-code"><span>Código temporal</span><strong>{temporary}</strong><small>Compártelo únicamente con la persona autorizada.</small></div>}</section><section className="panel delivery-chat"><div className="dashboard-section-heading"><div><h2>Chat</h2><p>Cliente y repartidor.</p></div><MessageCircle/></div><div className="chat-list">{messages.length===0?<p className="muted">Todavía no hay mensajes.</p>:messages.map((item)=><div className={item.senderType==='ADMIN'?'mine':''} key={item.id}><strong>{item.senderType}</strong><span>{item.message}</span><time>{new Date(item.createdAt).toLocaleTimeString('es-PE')}</time></div>)}</div><form onSubmit={send}><input value={message} maxLength={1000} placeholder="Escribe un mensaje" onChange={(event)=>setMessage(event.target.value)}/><button disabled={!message.trim()}>Enviar</button></form></section></aside></div>}
  </>;
}
