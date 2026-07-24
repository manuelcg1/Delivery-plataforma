'use client';

import { useEffect, useState } from 'react';
import { Clock3, Pencil, Save, X } from 'lucide-react';
import { api } from '@/lib/api';
import { useMerchant } from '@/lib/merchant';
import { ModulePage } from '@/components/module-page';
import './schedules.css';

type Hour = { id?:string|null; dayOfWeek:number; openTime:string|null; closeTime:string|null; closed:boolean; secondOpenTime?:string|null; secondCloseTime?:string|null };
const days=['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
const emptyWeek=():Hour[]=>days.map((_,index)=>({dayOfWeek:index+1,openTime:'09:00',closeTime:'18:00',closed:true,secondOpenTime:null,secondCloseTime:null}));
const completeWeek=(hours:Hour[])=>emptyWeek().map(fallback=>hours.find(hour=>hour.dayOfWeek===fallback.dayOfWeek)??fallback);

export default function Schedules(){
 const{branchId}=useMerchant();const[hours,setHours]=useState<Hour[]>(emptyWeek);const[draft,setDraft]=useState<Hour[]>(emptyWeek);const[editing,setEditing]=useState(false);const[loading,setLoading]=useState(false);const[saving,setSaving]=useState(false);const[error,setError]=useState('');const[success,setSuccess]=useState('');
 useEffect(()=>{setEditing(false);setSuccess('');setError('');if(!branchId){setHours(emptyWeek());return}setLoading(true);api<Hour[]>(`/api/v1/branches/${branchId}/business-hours`).then(result=>setHours(completeWeek(result))).catch(caught=>setError((caught as Error).message)).finally(()=>setLoading(false))},[branchId]);
 function beginEdit(){setDraft(hours.map(hour=>({...hour})));setEditing(true);setError('');setSuccess('')}
 function update(day:number,values:Partial<Hour>){setDraft(current=>current.map(hour=>hour.dayOfWeek===day?{...hour,...values}:hour))}
 async function save(){if(!branchId)return;const invalid=draft.find(hour=>!hour.closed&&(!hour.openTime||!hour.closeTime||hour.openTime===hour.closeTime));if(invalid){setError(`Revisa las horas de ${days[invalid.dayOfWeek-1]}.`);return}setSaving(true);setError('');setSuccess('');try{const payload=draft.map(hour=>({dayOfWeek:hour.dayOfWeek,openTime:hour.closed?null:hour.openTime,closeTime:hour.closed?null:hour.closeTime,closed:hour.closed,secondOpenTime:null,secondCloseTime:null}));const saved=await api<Hour[]>(`/api/v1/branches/${branchId}/business-hours`,{method:'PUT',body:JSON.stringify(payload)});setHours(completeWeek(saved));setEditing(false);setSuccess('Horario actualizado correctamente.')}catch(caught){setError((caught as Error).message)}finally{setSaving(false)}}
 return <ModulePage title="Horarios"description="Horario regular de atención"icon={Clock3}><div className="title schedule-actions"><span>{editing?'Configura la atención de cada día.':'Horario de la sucursal seleccionada.'}</span>{branchId&&!editing&&<button onClick={beginEdit}><Pencil/>Editar horario</button>}</div>{error&&<div className="alert"role="alert">{error}</div>}{success&&<div className="success"role="status">{success}</div>}{!branchId?<div className="empty"><Clock3/><h2>Selecciona una sucursal</h2></div>:<div className="table schedule-table">{loading?<div className="empty"><p>Cargando horario…</p></div>:(editing?draft:hours).map((hour,index)=><div className="schedule-row"key={hour.dayOfWeek}><strong>{days[index]}</strong>{editing?<><label className="closed-toggle"><input type="checkbox"checked={!hour.closed}onChange={event=>update(hour.dayOfWeek,{closed:!event.target.checked})}/>Abierto</label><label>Apertura<input type="time"disabled={hour.closed}value={hour.openTime?.slice(0,5)??'09:00'}onChange={event=>update(hour.dayOfWeek,{openTime:event.target.value})}/></label><label>Cierre<input type="time"disabled={hour.closed}value={hour.closeTime?.slice(0,5)??'18:00'}onChange={event=>update(hour.dayOfWeek,{closeTime:event.target.value})}/></label></>:<span>{hour.closed?'Cerrado':`${hour.openTime?.slice(0,5)} – ${hour.closeTime?.slice(0,5)}`}</span>}</div>)}{editing&&<div className="form-actions"><button className="secondary"onClick={()=>setEditing(false)}disabled={saving}><X/>Cancelar</button><button onClick={save}disabled={saving}><Save/>{saving?'Guardando…':'Guardar horario'}</button></div>}</div>}</ModulePage>
}
