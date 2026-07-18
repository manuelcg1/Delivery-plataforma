import type { FieldErrors } from './api';

export type NewUserData = {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone: string;
};

export function validateNewUser(data: NewUserData): FieldErrors {
  const errors: FieldErrors = {};
  if (!data.firstName.trim()) errors.firstName = 'Ingresa el nombre del usuario.';
  if (!data.lastName.trim()) errors.lastName = 'Ingresa el apellido del usuario.';
  if (!data.email.trim()) errors.email = 'Ingresa un correo electrónico.';
  else if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email)) errors.email = 'Ingresa un correo electrónico válido.';
  if (!data.password) errors.password = 'Crea una contraseña temporal.';
  else if (data.password.length < 10) errors.password = 'La contraseña debe tener al menos 10 caracteres.';
  if (data.phone.trim() && !/^[+\d][\d\s()-]{6,39}$/.test(data.phone.trim())) errors.phone = 'Ingresa un teléfono válido; puedes usar +, espacios o guiones.';
  return errors;
}
