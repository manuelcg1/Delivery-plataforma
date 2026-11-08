'use client';
import {useEffect,useRef,useState} from 'react';
import {Clock3,Pencil,Save,X} from 'lucide-react';
import {api} from '@/lib/api';
import {useMerchant} from '@/lib/merchant';
import {ModulePage} from '@/components/module-page';
import type {Branch} from '@/lib/types';
import './schedules.css';
type Hour={dayOfWeek:number;openTime:string|null;closeTime:string|null;closed:boolean;secondOpenTime?:string|null;secondCloseTime?:string|null};
const days=['Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'];
const time=(value:string|null|undefined)=>value?.slice(0,5)??'';
const completeWeek=(hours:Hour[]):Hour[]=>days.map((_,index)=>{const hour=hours.find(item=>item.dayOfWeek===index+1);return hour?{...hour,openTime:time(hour.openTime),closeTime:time(hour.closeTime),secondOpenTime:time(hour.secondOpenTime),secondCloseTime:time(hour.secondCloseTime)}:{dayOfWeek:index+1,closed:true,openTime:'',closeTime:'',secondOpenTime:'',secondCloseTime:''}});
function interval(open:string|null|undefined,close:string|null|undefined):[number,number]|null{
 if(!open||!close||!/^\d{2}:\d{2}$/.test(open)||!/^\d{2}:\d{2}$/.test(close)||open===close)return null;
 const minutes=(value:string)=>Number(value.slice(0,2))*60+Number(value.slice(3));const start=minutes(open),end=minutes(close);return [start,end>start?end:end+1440];
}
function invalidDay(hours:Hour[]){return hours.find(hour=>{if(hour.closed)return false;const first=interval(hour.openTime,hour.closeTime);if(!first)return true;if(!hour.secondOpenTime&&!hour.secondCloseTime)return false;const second=interval(hour.secondOpenTime,hour.secondCloseTime);if(!second)return true;return [-1440,0,1440].some(offset=>first[0]<second[1]+offset&&second[0]+offset<first[1])})}
function BranchSchedule({branch}:{branch:Branch}){
 const [hours,setHours]=useState<Hour[]|null>(null),[draft,setDraft]=useState<Hour[]>([]),[configured,setConfigured]=useState(false);
 const [editing,setEditing]=useState(false),[loading,setLoading]=useState(true),[saving,setSaving]=useState(false),[error,setError]=useState(''),[success,setSuccess]=useState(''),[attempt,setAttempt]=useState(0);
 const generation=useRef(0),busy=useRef(false);
 useEffect(()=>{const current=++generation.current;setLoading(true);setError('');setHours(null);setEditing(false);setSuccess('');api<Hour[]>(`/api/v1/branches/${branch.id}/business-hours`).then(result=>{if(current!==generation.current)return;setHours(completeWeek(result));setConfigured(result.length>0)}).catch(caught=>{if(current===generation.current)setError((caught as Error).message)}).finally(()=>{if(current===generation.current)setLoading(false)});return()=>{generation.current=current+1}},[branch.id,attempt]);
 function update(day:number,values:Partial<Hour>){setDraft(current=>current.map(hour=>hour.dayOfWeek===day?{...hour,...values}:hour))}
 async function save(){
  if(busy.current||!hours)return;const invalid=invalidDay(draft);if(invalid){setError(`Revisa las horas de ${days[invalid.dayOfWeek-1]}: completa los rangos, usa horas distintas y evita solapamientos.`);return}
  busy.current=true;setSaving(true);setError('');setSuccess('');const current=generation.current;
  const payload=draft.map(hour=>({dayOfWeek:hour.dayOfWeek,closed:hour.closed,openTime:hour.closed?null:hour.openTime,closeTime:hour.closed?null:hour.closeTime,secondOpenTime:hour.closed?null:hour.secondOpenTime||null,secondCloseTime:hour.closed?null:hour.secondCloseTime||null}));
  try{const saved=await api<Hour[]>(`/api/v1/branches/${branch.id}/business-hours`,{method:'PUT',body:JSON.stringify(payload)});if(current!==generation.current)return;setHours(completeWeek(saved));setConfigured(true);setEditing(false);setSuccess('Horario actualizado correctamente.')}
  catch(caught){if(current===generation.current)setError((caught as Error).message)}finally{if(current===generation.current){busy.current=false;setSaving(false)}}
 }
 return <section className="branch-schedule" aria-label={`Horario de ${branch.name}`}>
  <div className="title schedule-actions"><div><h2>{branch.name}</h2><p>Zona horaria de la sucursal</p></div>{hours&&!editing&&!loading&&<button onClick={()=>{setDraft(hours.map(hour=>({...hour})));setEditing(true);setError('');setSuccess('')}}><Pencil/>Editar horario</button>}</div>
  {error&&<div className="alert" role="alert">{error}</div>}{success&&<div className="success" role="status">{success}</div>}
  {loading?<p role="status">Cargando horario…</p>:!hours?<button onClick={()=>setAttempt(value=>value+1)}>Reintentar</button>:<>
   {!configured&&<p className="schedule-notice">Sin horario configurado: se aceptan pedidos hasta guardar un horario. Guardar los siete días cerrados impedirá recibir pedidos.</p>}
   <p className="schedule-help">Si el cierre es anterior a la apertura, el turno continúa al día siguiente.</p>
   <div className="table schedule-table">{(editing?draft:hours).map(hour=><fieldset className="schedule-row" key={hour.dayOfWeek} disabled={saving}>
    <legend>{days[hour.dayOfWeek-1]}</legend>
    {editing?<><label className="closed-toggle"><input type="checkbox" checked={!hour.closed} onChange={event=>update(hour.dayOfWeek,{closed:!event.target.checked})}/>Abierto</label>
     <label>Apertura<input type="time" disabled={hour.closed} value={time(hour.openTime)} onChange={event=>update(hour.dayOfWeek,{openTime:event.target.value})}/></label>
     <label>Cierre<input type="time" disabled={hour.closed} value={time(hour.closeTime)} onChange={event=>update(hour.dayOfWeek,{closeTime:event.target.value})}/></label>
     <label className="closed-toggle"><input type="checkbox" disabled={hour.closed} checked={!!(hour.secondOpenTime||hour.secondCloseTime)} onChange={event=>update(hour.dayOfWeek,event.target.checked?{secondOpenTime:'19:00',secondCloseTime:'22:00'}:{secondOpenTime:'',secondCloseTime:''})}/>Segundo turno</label>
     {!!(hour.secondOpenTime||hour.secondCloseTime)&&<><label>Segunda apertura<input type="time" disabled={hour.closed} value={time(hour.secondOpenTime)} onChange={event=>update(hour.dayOfWeek,{secondOpenTime:event.target.value})}/></label><label>Segundo cierre<input type="time" disabled={hour.closed} value={time(hour.secondCloseTime)} onChange={event=>update(hour.dayOfWeek,{secondCloseTime:event.target.value})}/></label></>}
    </>:<span>{!configured?'Sin configurar':hour.closed?'Cerrado':`${time(hour.openTime)} – ${time(hour.closeTime)}${hour.secondOpenTime?` / ${time(hour.secondOpenTime)} – ${time(hour.secondCloseTime)}`:''}`}</span>}
   </fieldset>)}{editing&&<div className="form-actions"><button className="secondary" disabled={saving} onClick={()=>{setEditing(false);setError('')}}><X/>Cancelar</button><button disabled={saving} onClick={save}><Save/>{saving?'Guardando…':'Guardar horario'}</button></div>}</div>
  </>}
 </section>
}
export default function Schedules(){
 const {context,merchantId,branchId}=useMerchant();const merchant=context?.merchants.find(item=>item.id===merchantId);const branches=merchant?.branches.filter(branch=>!branchId||branch.id===branchId)??[];
 return <ModulePage title="Horarios" description="Horario regular de atención" icon={Clock3}><p className="schedule-help">Configura y guarda el horario de cada sucursal.</p>{branches.map(branch=><BranchSchedule key={`${merchantId}:${branchId}:${branch.id}`} branch={branch}/>)}{!branches.length&&<div className="empty"><Clock3/><h2>{context?'No hay sucursales autorizadas en este contexto':'Cargando sucursales…'}</h2></div>}</ModulePage>
}
