export type PortalAccountForm={email:string;firstName:string;lastName:string;password:string;confirmation:string};
export type PortalAccountErrors=Partial<Record<keyof PortalAccountForm,string>>;
export const emptyPortalAccount:PortalAccountForm={email:'',firstName:'',lastName:'',password:'',confirmation:''};
export function validatePortalAccount(value:PortalAccountForm):PortalAccountErrors {
  const errors:PortalAccountErrors={};
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value.email.trim())||value.email.trim().length>254)errors.email='Ingresa un correo válido para acceder al portal';
  if(!value.firstName.trim()||value.firstName.trim().length>100)errors.firstName='Ingresa el nombre del responsable (máximo 100 caracteres)';
  if(!value.lastName.trim()||value.lastName.trim().length>100)errors.lastName='Ingresa el apellido del responsable (máximo 100 caracteres)';
  if(value.password.length<10||new TextEncoder().encode(value.password).length>72)errors.password='Usa al menos 10 caracteres y un máximo de 72 bytes';
  if(value.password!==value.confirmation)errors.confirmation='Las contraseñas no coinciden';
  return errors;
}
