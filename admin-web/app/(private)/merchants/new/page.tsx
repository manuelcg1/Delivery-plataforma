'use client';

import {ChangeEvent,FormEvent,useEffect,useState} from 'react';
import {useRouter} from 'next/navigation';
import Image from 'next/image';
import {api,ApiClientError,FieldErrors} from '@/lib/api';
import {useAuth} from '@/lib/auth';
import {merchantImageError} from '@/lib/merchant-image-validation';

const initial={code:'',name:'',legalName:'',description:'',merchantType:'RESTAURANT',email:'',phone:'',defaultCurrency:'PEN',timezone:'America/Lima'};
export default function NewMerchant(){
  const[d,setD]=useState(initial);
  const[errors,setErrors]=useState<FieldErrors>({});
  const[busy,setBusy]=useState(false);
  const[createdId,setCreatedId]=useState<string|null>(null);
  const[logo,setLogo]=useState<File|null>(null);
  const[banner,setBanner]=useState<File|null>(null);
  const[logoPreview,setLogoPreview]=useState('');
  const[bannerPreview,setBannerPreview]=useState('');
  const router=useRouter();
  const{can}=useAuth();
  const canUpload=can('CATALOG_MEDIA_UPLOAD');

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
    const validation:FieldErrors={};
    if(!d.name.trim())validation.name='Ingresa el nombre comercial';
    if(!d.code.trim())validation.code='Ingresa un código único';
    if(!/^[a-z0-9-]+$/.test(d.code))validation.code='Usa minúsculas, números y guiones';
    if(errors.logo)validation.logo=errors.logo;
    if(errors.banner)validation.banner=errors.banner;
    setErrors(validation);
    if(Object.keys(validation).length)return;
    setBusy(true);
    let id=createdId;
    try{
      id=id??(await api<{id:string}>('/api/v1/merchants',{method:'POST',body:JSON.stringify(d)})).id;
      setCreatedId(id);
      if(logo){await upload(id,'logo',logo);setLogo(null)}
      if(banner){await upload(id,'banner',banner);setBanner(null)}
      router.push(`/merchants/${id}`);
    }catch(cause){
      const message=cause instanceof ApiClientError?cause.message:'No se pudo crear el comercio.';
      setErrors(current=>({...current,submit:id?`${message} El comercio ya fue creado; puedes reintentar la carga.`:message}));
    }finally{setBusy(false)}
  }

  const input=(key:keyof typeof d,label:string)=><label>{label}<input value={d[key]} disabled={!!createdId} aria-invalid={!!errors[key]} onChange={event=>{setD({...d,[key]:event.target.value});setErrors({...errors,[key]:''})}}/>{errors[key]&&<small className="field-error">{errors[key]}</small>}</label>;

  return <>
    <div><p className="eyebrow">CATÁLOGO</p><h1>Nuevo comercio</h1></div>
    <form className="panel catalog-form" onSubmit={submit}>
      {input('name','Nombre comercial')}{input('code','Código')}{input('legalName','Razón social')}
      <label>Tipo<select value={d.merchantType} disabled={!!createdId} onChange={event=>setD({...d,merchantType:event.target.value})}>{['RESTAURANT','GROCERY','PHARMACY','RETAIL','DARK_STORE','OTHER'].map(value=><option key={value}>{value}</option>)}</select></label>
      {input('email','Correo')}{input('phone','Teléfono')}{input('defaultCurrency','Moneda ISO')}{input('timezone','Zona horaria')}
      <label className="full">Descripción<textarea value={d.description} disabled={!!createdId} onChange={event=>setD({...d,description:event.target.value})}/></label>
      {canUpload&&<fieldset className="merchant-media-fields full">
        <legend>Identidad visual (opcional)</legend>
        <p>JPEG, PNG o WebP de hasta 5 MB. El logo se recorta en formato cuadrado y el banner se adapta a formato horizontal.</p>
        <div className="merchant-media-grid">
          <label>Logo comercial<input type="file" accept="image/jpeg,image/png,image/webp" onChange={event=>chooseImage('logo',event)}/>{errors.logo&&<small className="field-error">{errors.logo}</small>}{logoPreview&&<Image unoptimized width={112} height={112} className="merchant-logo-preview" src={logoPreview} alt="Vista previa del logo"/>}</label>
          <label>Banner comercial<input type="file" accept="image/jpeg,image/png,image/webp" onChange={event=>chooseImage('banner',event)}/>{errors.banner&&<small className="field-error">{errors.banner}</small>}{bannerPreview&&<Image unoptimized width={800} height={300} className="merchant-banner-preview" src={bannerPreview} alt="Vista previa del banner"/>}</label>
        </div>
      </fieldset>}
      {errors.submit&&<div className="form-alert full" role="alert">{errors.submit}</div>}
      <div className="form-actions"><button type="button" className="secondary" disabled={busy} onClick={()=>router.push(createdId?`/merchants/${createdId}`:'/merchants')}>Cancelar</button><button disabled={busy}>{busy?'Guardando…':createdId?'Reintentar carga':'Crear comercio'}</button></div>
    </form>
  </>;
}
