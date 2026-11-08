import {PortalAccountForm,PortalAccountErrors} from '@/lib/merchant-portal-access';

type Props={enabled:boolean;disabled:boolean;value:PortalAccountForm;errors:PortalAccountErrors;onEnable:(value:boolean)=>void;onChange:(value:PortalAccountForm)=>void};
export default function MerchantPortalAccessFields({enabled,disabled,value,errors,onEnable,onChange}:Props){
  function field(key:keyof PortalAccountForm,label:string,type='text'){
    const errorId=`portal-${key}-error`;
    return <label>{label}<input name={`portal-${key}`} type={type} value={value[key]} disabled={disabled}
      autoComplete={type==='password'?'new-password':'off'} required={enabled}
      aria-invalid={!!errors[key]} aria-describedby={errors[key]?errorId:undefined}
      onChange={event=>onChange({...value,[key]:event.target.value})}/>
      {errors[key]&&<small id={errorId} className="field-error">{errors[key]}</small>}</label>;
  }
  return <fieldset className="full"><legend>Acceso al portal de comercio</legend>
    <label><input type="checkbox" checked={enabled} disabled={disabled} onChange={event=>onEnable(event.target.checked)}/> Crear cuenta para gestionar los pedidos de este comercio</label>
    {enabled&&<><p>El responsable tendrá acceso únicamente a este comercio y sus sucursales. Usa un correo que todavía no tenga una cuenta. El correo de contacto no modificará este acceso.</p>
      {field('email','Correo de acceso','email')}{field('firstName','Nombre del responsable')}{field('lastName','Apellido del responsable')}
      {field('password','Contraseña de acceso','password')}{field('confirmation','Confirmar contraseña','password')}
      <p>El comercio se crea como borrador. Actívalo y configura una sucursal para comenzar a operar pedidos.</p></>}
  </fieldset>;
}
