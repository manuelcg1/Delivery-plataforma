'use client';
import {FormEvent,useCallback,useEffect,useRef,useState} from 'react';
import {api,ApiClientError} from '@/lib/api';
import {emptyYape,validateYape,validateYapeQrImage,yapeDraft,yapeFormData,YapeErrors,YapeSettings} from '@/lib/merchant-yape';
import MerchantYapeFields from './MerchantYapeFields';

export default function MerchantYapeSettings({merchantId,canEdit,canUpload}:{merchantId:string;canEdit:boolean;canUpload:boolean}){
  const[value,setValue]=useState(emptyYape),[errors,setErrors]=useState<YapeErrors>({});
  const[loaded,setLoaded]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(''),[saved,setSaved]=useState(false);
  const generation=useRef(0);
  const submitting=useRef(false);
  const invalidate=useCallback(()=>{generation.current++},[]);
  const load=useCallback(async()=>{
    const request=++generation.current;
    setLoaded(false);setBusy(true);setError('');
    try{const settings=await api<YapeSettings>(`/api/v1/merchants/${merchantId}/payment-methods/yape`);if(request!==generation.current)return;setValue(yapeDraft(settings));setLoaded(true)}
    catch(cause){if(request===generation.current)setError(cause instanceof ApiClientError?cause.message:'No se pudo cargar Yape.')}
    finally{if(request===generation.current)setBusy(false)}
  },[merchantId]);
  useEffect(()=>{void load();return invalidate},[load,invalidate]);
  async function submit(event:FormEvent){
    event.preventDefault();if(!canEdit||busy||submitting.current)return;
    const validation=validateYape(value);setErrors(validation);setSaved(false);setError('');
    if(Object.keys(validation).length)return;
    submitting.current=true;setBusy(true);
    const request=++generation.current;
    try{const qrError=await validateYapeQrImage(value.qr);if(request!==generation.current)return;if(qrError){setErrors({qr:qrError});return}const result=await api<YapeSettings>(`/api/v1/merchants/${merchantId}/payment-methods/yape`,{method:'PUT',body:yapeFormData(value)});if(request!==generation.current)return;setValue(yapeDraft(result));setSaved(true)}
    catch(cause){if(request!==generation.current)return;setError(cause instanceof ApiClientError?cause.message:'No se pudo guardar Yape.');if(cause instanceof ApiClientError)setErrors(cause.details)}
    finally{submitting.current=false;if(request===generation.current)setBusy(false)}
  }
  return <section className="panel"><h2>Pagos del comercio</h2>
    {!loaded&&busy&&<p role="status">Cargando Yape…</p>}
    {error&&<p className="form-alert" role="alert">{error}</p>}
    {!loaded&&!busy&&<button type="button" onClick={()=>void load()}>Reintentar</button>}
    {loaded&&<form className="catalog-form" onSubmit={submit}>
      <MerchantYapeFields value={value} errors={errors} onChange={draft=>{setValue(draft);setErrors({});setSaved(false)}} disabled={busy||!canEdit} canUpload={canUpload}/>
      {saved&&<p role="status">Configuración Yape guardada.</p>}
      {canEdit&&<button disabled={busy}>{busy?'Guardando…':'Guardar Yape'}</button>}
    </form>}
  </section>;
}
