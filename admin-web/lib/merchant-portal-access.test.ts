import {describe,it,expect} from 'vitest';
import {validatePortalAccount} from './merchant-portal-access';

const account={email:'shop@example.test',firstName:'Ana',lastName:'Perez',password:'safe-password-123',confirmation:'safe-password-123'};
describe('merchant portal account',()=>{
  it('accepts a complete account',()=>expect(validatePortalAccount(account)).toEqual({}));
  it('requires the responsible person and email',()=>{
    const errors=validatePortalAccount({...account,email:'invalid',firstName:' ',lastName:''});
    expect(Object.keys(errors)).toEqual(expect.arrayContaining(['email','firstName','lastName']));
  });
  it('rejects mismatched confirmation',()=>expect(validatePortalAccount({...account,confirmation:'different'})).toHaveProperty('confirmation'));
  it('rejects short passwords',()=>expect(validatePortalAccount({...account,password:'short'})).toHaveProperty('password'));
  it('rejects passwords exceeding BCrypt UTF8 limit',()=>expect(validatePortalAccount({...account,password:'á'.repeat(40)})).toHaveProperty('password'));
});
