'use client';

import {ChangeEvent,FormEvent,useEffect,useRef,useState} from 'react';
import {useRouter} from 'next/navigation';
import Image from 'next/image';
import {api,ApiClientError,FieldErrors} from '@/lib/api';
import {useAuth} from '@/lib/auth';
import {merchantTypes} from '@/lib/merchant-types';
import {merchantImageError} from '@/lib/merchant-image-validation';
import MerchantPortalAccessFields from '@/components/MerchantPortalAccessFields';
import {emptyPortalAccount,validatePortalAccount,PortalAccountErrors} from '@/lib/merchant-portal-access';
import MerchantYapeFields from '@/components/MerchantYapeFields';
import {emptyYape,validateYape,validateYapeQrImage,yapeFormData,YapeErrors} from '@/lib/merchant-yape';

const initial={code:'',name:'',legalName:'',description:'',merchantType:'RESTAURANT',email:'',phone:'',defaultCurrency:'PEN',timezone:'America/Lima'};
export default function NewMerchant(){
  const[d,setD]=useState(initial);
  const[portalEnabled,setPortalEnabled]=useState(true);
  const[portal,setPortal]=useState(emptyPortalAccount);
  const[portalErrors,setPortalErrors]=useState<PortalAccountErrors>({});
  const[errors,setErrors]=useState<FieldErrors>({});
  const[busy,setBusy]=useState(false);
  const submitting=useRef(false);
  const[createdId,setCreatedId]=useState<string|null>(null);
  const[yape,setYape]=useState(emptyYape);
  const[yapeErrors,setYapeErrors]=useState<YapeErrors>({});
  const[logo,setLogo]=useState<File|null>(null);
  const[banner,setBanner]=useState<File|null>(null);
  const[logoPreview,setLogoPreview]=useState('');
  const[bannerPreview,setBannerPreview]=useState('');
  const router=useRouter();
  const{can}=useAuth();
  const canUpload=can('CATALOG_MEDIA_UPLOAD');
  const canProvision=can('IDENTITY_USERS_CREATE')&&can('IDENTITY_ROLES_ASSIGN');

  useEffect(()=>()=>{
    if(logoPreview)URL.revokeObjectURL(logoPreview);
    if(bannerPreview)URL.revokeObjectURL(bannerPreview);
  },[logoPreview,bannerPreview]);

  function chooseImage(kind:'logo'|'banner',event:ChangeEvent<HTMLInputElement>){
    const file=event.target.files?.[0]??null;
    if(!file){
      if(kind==='logo'){setLogo(null);setLogoPreview('')}else{setBanner(null);setBannerPreview('')}
      return;
    }
    const message=merchantImageError(file);
    setErrors(current=>({...current,[kind]:message}));
    if(message){event.target.value='';return}
    const preview=URL.createObjectURL(file);
    if(kind==='logo'){setLogo(file);setLogoPreview(preview)}else{setBanner(file);setBannerPreview(preview)}
  }

  async function upload(id:string,kind:'logo'|'banner',file:File){
    const body=new FormData();
    body.append('file',file);
    await api(`/api/v1/merchants/${id}/${kind}`,{method:'POST',body});
  }

  async function submit(event:FormEvent){
    event.preventDefault();
    if(submitting.current)return;
    const validation:FieldErrors={};
    if(!d.name.trim())validation.name='Ingresa el nombre comercial';
    if(!d.code.trim())validation.code='Ingresa un código único';
    if(!/^[a-z0-9-]+$/.test(d.code))validation.code='Usa minúsculas, números y guiones';
    if(errors.logo)validation.logo=errors.logo;
    if(errors.banner)validation.banner=errors.banner;
    setErrors(validation);
    const account={...portal,email:portal.email.trim()||d.email.trim()};
    const accessErrors=!createdId&&canProvision&&portalEnabled?validatePortalAccount(account):{};
    setPortalErrors(accessErrors);
    const paymentErrors=validateYape(yape);
    setYapeErrors(paymentErrors);
    if(Object.keys(validation).length||Object.keys(accessErrors).length||Object.keys(paymentErrors).length)return;
    submitting.current=true;setBusy(true);
    let id=createdId;
    try{
      const qrError=await validateYapeQrImage(yape.qr);
      if(qrError){setYapeErrors({qr:qrError});return}
      id=id??(await api<{id:string}>('/api/v1/merchants',{method:'POST',body:JSON.stringify({...d,portalAccess:canProvision&&portalEnabled?{email:account.email,firstName:account.firstName.trim(),lastName:account.lastName.trim(),password:account.password}:undefined})})).id;
      setCreatedId(id);
      setPortal(current=>({...current,password:'',confirmation:''}));
      if(logo){await upload(id,'logo',logo);setLogo(null)}
      if(banner){await upload(id,'banner',banner);setBanner(null)}
      if(yape.enabled)await api(`/api/v1/merchants/${id}/payment-methods/yape`,{method:'PUT',body:yapeFormData(yape)});
      router.push(`/merchants/${id}`);
    }catch(cause){
      const message=cause instanceof ApiClientError?cause.message:'No se pudo crear el comercio.';
      setErrors(current=>({...current,submit:id?`${message} El comercio ya fue creado; puedes reintentar la carga.`:message}));
    }finally{submitting.current=false;setBusy(false)}
  }

  const input=(key:keyof typeof d,label:string)=><label>{label}<input value={d[key]} disabled={busy||!!createdId} aria-invalid={!!errors[key]} onChange={event=>{setD({...d,[key]:event.target.value});setErrors({...errors,[key]:''})}}/>{errors[key]&&<small className="field-error">{errors[key]}</small>}</label>;

  return <>
    <div><p className="eyebrow">CATÁLOGO</p><h1>Nuevo comercio</h1></div>
    <form className="panel catalog-form" onSubmit={submit}>
      {input('name','Nombre comercial')}{input('code','Código')}{input('legalName','Razón social')}
      <label>Tipo<select value={d.merchantType} disabled={busy||!!createdId} onChange={event=>setD({...d,merchantType:event.target.value})}>{merchantTypes.map(({value,label})=><option key={value} value={value}>{label}</option>)}</select></label>
      {input('email','Correo')}{input('phone','Teléfono')}{input('defaultCurrency','Moneda ISO')}{input('timezone','Zona horaria')}
      <label className="full">Descripción<textarea value={d.description} disabled={busy||!!createdId} onChange={event=>setD({...d,description:event.target.value})}/></label>
      {canProvision&&<MerchantPortalAccessFields enabled={portalEnabled} disabled={busy||!!createdId} value={{...portal,email:portal.email||d.email}} errors={portalErrors} onEnable={setPortalEnabled} onChange={setPortal}/>}
      {canUpload&&<fieldset className="merchant-media-fields full" disabled={busy}>
        <legend>Identidad visual (opcional)</legend>
        <p>JPEG, PNG o WebP de hasta 5 MB. El logo se recorta en formato cuadrado y el banner se adapta a formato horizontal.</p>
        <div className="merchant-media-grid">
          <label>Logo comercial<input type="file" accept="image/jpeg,image/png,image/webp" onChange={event=>chooseImage('logo',event)}/>{errors.logo&&<small className="field-error">{errors.logo}</small>}{logoPreview&&<Image unoptimized width={112} height={112} className="merchant-logo-preview" src={logoPreview} alt="Vista previa del logo"/>}</label>
          <label>Banner comercial<input type="file" accept="image/jpeg,image/png,image/webp" onChange={event=>chooseImage('banner',event)}/>{errors.banner&&<small className="field-error">{errors.banner}</small>}{bannerPreview&&<Image unoptimized width={800} height={300} className="merchant-banner-preview" src={bannerPreview} alt="Vista previa del banner"/>}</label>
        </div>
      </fieldset>}
      <MerchantYapeFields value={yape} errors={yapeErrors} disabled={busy} canUpload={canUpload} onChange={value=>{setYape(value);setYapeErrors({})}}/>
      {errors.submit&&<div className="form-alert full" role="alert">{errors.submit}</div>}
      <div className="form-actions"><button type="button" className="secondary" disabled={busy} onClick={()=>router.push(createdId?`/merchants/${createdId}`:'/merchants')}>Cancelar</button><button disabled={busy}>{busy?'Guardando…':createdId?'Reintentar carga':'Crear comercio'}</button></div>
    </form>
  </>;
}
