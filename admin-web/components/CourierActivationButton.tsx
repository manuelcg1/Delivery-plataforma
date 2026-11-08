'use client';
import {useRef,useState} from 'react';
import {api} from '@/lib/api';

export default function CourierActivationButton({id,status,onActivated}:{id:string;status:string;onActivated:()=>Promise<void>}){
  const[busy,setBusy]=useState(false),[error,setError]=useState('');
  const locked=useRef(false);
  if(status!=='INACTIVE')return null;
  async function activate(){
    if(locked.current)return;
    locked.current=true;setBusy(true);setError('');
    try{await api(`/api/v1/couriers/${id}/activate`,{method:'POST'});await onActivated()}
    catch(cause){setError(cause instanceof Error?cause.message:'No se pudo activar el repartidor.')}
    finally{locked.current=false;setBusy(false)}
  }
  return <div><button type="button" disabled={busy} onClick={()=>void activate()}>{busy?'Activando…':'Activar repartidor'}</button>{error&&<small className="field-error" role="alert">{error}</small>}</div>;
}
