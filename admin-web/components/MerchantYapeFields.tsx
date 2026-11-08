'use client';
import {useEffect,useId,useState} from 'react';
import Image from 'next/image';
import {YapeDraft,YapeErrors} from '@/lib/merchant-yape';

export default function MerchantYapeFields({value,errors,onChange,disabled=false,canUpload=true}:{value:YapeDraft;errors:YapeErrors;onChange:(value:YapeDraft)=>void;disabled?:boolean;canUpload?:boolean}){
  const id=useId();
  const[preview,setPreview]=useState('');
  useEffect(()=>{if(!value.qr){setPreview('');return}const url=URL.createObjectURL(value.qr);setPreview(url);return()=>URL.revokeObjectURL(url)},[value.qr]);
  const error=(key:keyof YapeErrors)=>errors[key]&&<small id={`${id}-${key}-error`} className="field-error">{errors[key]}</small>;
  return <fieldset className="merchant-media-fields full" disabled={disabled}>
    <legend>Métodos de pago</legend>
    <label><input type="checkbox" checked={value.enabled} onChange={event=>onChange({...value,enabled:event.target.checked})}/>Habilitar Yape</label>
    {!value.enabled&&<p>Yape no estará disponible en el checkout de este comercio.</p>}
    {value.enabled&&<div className="merchant-media-grid">
      <label>Número Yape<input aria-label="Número Yape" inputMode="numeric" maxLength={9} value={value.phone} aria-invalid={!!errors.phone} aria-describedby={errors.phone?`${id}-phone-error`:undefined} onChange={event=>onChange({...value,phone:event.target.value})}/>{error('phone')}</label>
      <label>Titular Yape<input aria-label="Titular Yape" maxLength={160} value={value.holderName} aria-invalid={!!errors.holderName} aria-describedby={errors.holderName?`${id}-holderName-error`:undefined} onChange={event=>onChange({...value,holderName:event.target.value})}/>{error('holderName')}</label>
      <div><label>QR Yape<input type="file" accept="image/jpeg,image/png" disabled={!canUpload} aria-invalid={!!errors.qr} aria-describedby={`${id}-qr-help${errors.qr?` ${id}-qr-error`:''}`} onChange={event=>onChange({...value,qr:event.target.files?.[0]??null})}/></label><p id={`${id}-qr-help`}>JPEG o PNG de hasta 5 MB y 4096 píxeles por lado. Se conserva la imagen completa, sin recortar.</p>{!canUpload&&<p>Se requiere permiso para subir medios.</p>}{error('qr')}{(preview||value.qrUrl)&&<Image unoptimized src={preview||value.qrUrl!} alt="QR Yape del comercio" width={240} height={240} style={{objectFit:'contain',maxWidth:'100%'}}/>}</div>
    </div>}
  </fieldset>;
}
