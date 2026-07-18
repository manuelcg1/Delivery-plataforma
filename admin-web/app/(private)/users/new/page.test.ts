import { describe, expect, it } from 'vitest';
import { validateNewUser, type NewUserData } from '@/lib/user-validation';

const valid: NewUserData = {
  firstName: 'María',
  lastName: 'González',
  email: 'maria@empresa.com',
  phone: '+51 999 999 999',
  password: 'temporal-123',
};

describe('validateNewUser', () => {
  it('accepts valid user data', () => {
    expect(validateNewUser(valid)).toEqual({});
  });

  it('returns a specific message for each invalid field', () => {
    const errors = validateNewUser({ firstName: '', lastName: '', email: 'correo', phone: 'abc', password: 'short' });
    expect(errors).toMatchObject({
      firstName: expect.any(String),
      lastName: expect.any(String),
      email: expect.any(String),
      phone: expect.any(String),
      password: expect.any(String),
    });
  });
});
