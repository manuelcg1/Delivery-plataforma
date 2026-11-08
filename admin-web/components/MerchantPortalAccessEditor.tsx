'use client';
import {FormEvent,useEffect,useId,useRef,useState} from 'react';
import {api,ApiClientError,FieldErrors} from '@/lib/api';

type PortalAccess={id:string;email:string;firstName:string;lastName:string;editable:boolean;reason:string|null};
type Props={merchantId:string;canEdit:boolean};

export default function MerchantPortalAccessEditor(props:Props){
  // A merchant change destroys every draft, password and in-flight result owner.
  return <PortalAccessList key={props.merchantId} {...props}/>;
}

function PortalAccessList({merchantId,canEdit}:Props){
  const[accounts,setAccounts]=useState<PortalAccess[]|null>(null);
  const[error,setError]=useState('');
  const[attempt,setAttempt]=useState(0);
  useEffect(()=>{
    let active=true;
    api<PortalAccess[]>(`/api/v1/merchants/${merchantId}/portal-access`)
      .then(result=>{if(active)setAccounts(result)})
      .catch(cause=>{if(active)setError(cause instanceof ApiClientError?cause.message:'No se pudieron cargar los accesos al portal.')});
    return()=>{active=false};
  },[merchantId,attempt]);
  return <section className="panel"><h2>Acceso al portal del comercio</h2>
    {error&&<><p role="alert" className="form-alert">{error}</p><button type="button" onClick={()=>{setError('');setAttempt(value=>value+1)}}>Reintentar</button></>}
    {!accounts&&!error&&<p role="status">Cargando accesos…</p>}
    {accounts?.length===0&&<p>Este comercio no tiene cuentas de acceso al portal.</p>}
    {accounts?.map(account=><PortalAccessForm key={account.id} merchantId={merchantId} account={account} canEdit={canEdit}/>)}
  </section>;
}

function PortalAccessForm({merchantId,account,canEdit}:{merchantId:string;account:PortalAccess;canEdit:boolean}){
  const[email,setEmail]=useState(account.email),[firstName,setFirstName]=useState(account.firstName),[lastName,setLastName]=useState(account.lastName);
  const[password,setPassword]=useState(''),[confirmation,setConfirmation]=useState('');
  const[errors,setErrors]=useState<FieldErrors>({}),[error,setError]=useState(''),[saved,setSaved]=useState(false),[busy,setBusy]=useState(false);
  const active=useRef(true),locked=useRef(false),prefix=useId();
  useEffect(()=>{active.current=true;return()=>{active.current=false}},[]);
  const editable=canEdit&&account.editable;
  async function submit(event:FormEvent){
    event.preventDefault();
    if(!editable||locked.current||!active.current)return;
    const validation:FieldErrors={};
    if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim())||email.trim().length>254)validation.email='Ingresa un correo válido para acceder al portal';
    if(!firstName.trim()||firstName.trim().length>100)validation.firstName='Ingresa el nombre del responsable (máximo 100 caracteres)';
    if(!lastName.trim()||lastName.trim().length>100)validation.lastName='Ingresa el apellido del responsable (máximo 100 caracteres)';
    if(password&&(!password.trim()||password.length<10||new TextEncoder().encode(password).length>72))validation.newPassword='Usa al menos 10 caracteres y un máximo de 72 bytes';
    if(password!==confirmation)validation.confirmation='Las contraseñas no coinciden';
    setErrors(validation);setError('');setSaved(false);
    if(Object.keys(validation).length)return;
    locked.current=true;setBusy(true);
    try{
      await api(`/api/v1/merchants/${merchantId}/portal-access/${account.id}`,{method:'PUT',body:JSON.stringify({email:email.trim(),firstName:firstName.trim(),lastName:lastName.trim(),...(password?{newPassword:password}:{})})});
      if(!active.current)return;
      setPassword('');setConfirmation('');setSaved(true);
    }catch(cause){
      if(!active.current)return;
      setError(cause instanceof ApiClientError?cause.message:'No se pudo actualizar el acceso.');
      if(cause instanceof ApiClientError)setErrors(cause.details);
    }finally{locked.current=false;if(active.current)setBusy(false)}
  }
  const fields=[
    {name:'email',label:'Correo de acceso',value:email,set:setEmail,type:'email'},
    {name:'firstName',label:'Nombres del responsable',value:firstName,set:setFirstName,type:'text'},
    {name:'lastName',label:'Apellidos del responsable',value:lastName,set:setLastName,type:'text'},
    {name:'newPassword',label:'Nueva contraseña',value:password,set:setPassword,type:'password'},
    {name:'confirmation',label:'Confirmar nueva contraseña',value:confirmation,set:setConfirmation,type:'password'},
  ];
  return <form className="catalog-form" onSubmit={submit} noValidate aria-label={`Acceso de ${account.email}`}>
    {!account.editable&&<p>Esta cuenta está compartida con otros comercios o tiene permisos adicionales. No se puede editar desde este comercio.</p>}
    {fields.map(field=><div key={field.name} className="field"><label htmlFor={`${prefix}-${field.name}`}>{field.label}</label>
      <input id={`${prefix}-${field.name}`} type={field.type} value={field.value} disabled={!editable||busy} autoComplete={field.type==='password'?'new-password':field.name==='email'?'email':undefined} aria-invalid={!!errors[field.name]} aria-describedby={errors[field.name]?`${prefix}-${field.name}-error`:undefined} onChange={event=>{field.set(event.target.value);setErrors({});setSaved(false)}}/>
      {errors[field.name]&&<span id={`${prefix}-${field.name}-error`}>{errors[field.name]}</span>}
    </div>)}
    <p>Deja la nueva contraseña vacía para conservar la actual. Al cambiarla, usa al menos 10 caracteres y un máximo de 72 bytes.</p>
    {error&&<p role="alert" className="form-alert">{error}</p>}
    {saved&&<p role="status">Acceso actualizado.</p>}
    {editable&&<button disabled={busy}>{busy?'Guardando…':'Guardar acceso'}</button>}
  </form>;
}
