import {merchantImageError} from './merchant-image-validation';

export type YapeSettings={enabled:boolean;phone:string|null;holderName:string|null;qrUrl:string|null;version:string|null};
export type YapeDraft={enabled:boolean;phone:string;holderName:string;qrUrl:string|null;qr:File|null};
export type YapeErrors=Partial<Record<'phone'|'holderName'|'qr',string>>;
export const emptyYape:YapeDraft={enabled:false,phone:'',holderName:'',qrUrl:null,qr:null};
export async function validateYapeQrImage(file:File|null):Promise<string>{
  if(!file)return '';
  const basic=validateYape({...emptyYape,qr:file}).qr;
  if(basic)return basic;
  try{
    const bytes=await new Promise<Uint8Array>((resolve,reject)=>{
      const reader=new FileReader();
      reader.onload=()=>resolve(new Uint8Array(reader.result as ArrayBuffer));
      reader.onerror=()=>reject(new Error('unreadable'));
      reader.readAsArrayBuffer(file.slice(0,12));
    });
    const png=[137,80,78,71,13,10,26,10].every((byte,index)=>bytes[index]===byte);
    const jpeg=bytes[0]===255&&bytes[1]===216&&bytes[2]===255;
    if((file.type==='image/png'&&!png)||(file.type==='image/jpeg'&&!jpeg))return 'Selecciona una imagen QR válida PNG o JPEG';
    const url=URL.createObjectURL(file);
    try{return await new Promise<string>(resolve=>{
      const image=new Image();
      image.onload=()=>resolve(image.naturalWidth<1||image.naturalHeight<1?'Selecciona una imagen QR válida':image.naturalWidth>4096||image.naturalHeight>4096?'El QR no debe superar 4096 píxeles por lado':'');
      image.onerror=()=>resolve('Selecciona una imagen QR válida');
      image.src=url;
    })}finally{URL.revokeObjectURL(url)}
  }catch{return 'No se pudo leer la imagen QR; selecciona una imagen válida'}
}
export function validateYape(value:YapeDraft):YapeErrors{
  const errors:YapeErrors={};
  if(value.qr){const message=['image/jpeg','image/png'].includes(value.qr.type)?merchantImageError(value.qr):'Usa una imagen JPEG o PNG para el QR';if(message)errors.qr=message}
  if(!value.enabled)return errors;
  if(!/^9\d{8}$/.test(value.phone.trim()))errors.phone='Ingresa un celular de 9 dígitos que empiece con 9';
  if(!value.holderName.trim())errors.holderName='Ingresa el nombre del titular';
  else if(value.holderName.trim().length>160)errors.holderName='El titular no debe superar 160 caracteres';
  if(!value.qr&&!value.qrUrl)errors.qr='Selecciona el QR Yape de este comercio';
  return errors;
}
export function yapeFormData(value:YapeDraft){
  const body=new FormData();
  body.append('enabled',String(value.enabled));body.append('phone',value.phone.trim());body.append('holderName',value.holderName.trim());
  if(value.qr)body.append('qr',value.qr);
  return body;
}
export function yapeDraft(settings:YapeSettings):YapeDraft{return {...emptyYape,enabled:settings.enabled,phone:settings.phone??'',holderName:settings.holderName??'',qrUrl:settings.qrUrl}}
