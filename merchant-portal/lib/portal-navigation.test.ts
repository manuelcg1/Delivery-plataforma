import {describe,it,expect} from 'vitest';
import {canOpenPortalPage} from './portal-navigation';
describe('scoped merchant navigation',()=>{
  const operator=['MERCHANT_PORTAL_ACCESS','MERCHANT_ORDERS_VIEW','MERCHANT_BRANCH_OPERATE'];
  it('shows assigned operational pages',()=>{
    expect(canOpenPortalPage('/orders',operator)).toBe(true);
    expect(canOpenPortalPage('/branches',operator)).toBe(true);
    expect(canOpenPortalPage('/schedules',operator)).toBe(true);
  });
  it('does not expose tenant management pages to the new operator',()=>{
    for(const page of ['/catalog','/team','/settings','/payments','/reports'])expect(canOpenPortalPage(page,operator)).toBe(false);
  });
  it('preserves pages for authorized administrators',()=>expect(canOpenPortalPage('/team',['IDENTITY_USERS_VIEW'])).toBe(true));
  it('allows the existing hours permission and rejects unrelated grants',()=>{
    expect(canOpenPortalPage('/schedules',['CATALOG_HOURS_VIEW'])).toBe(true);
    expect(canOpenPortalPage('/schedules',['MERCHANT_ORDERS_VIEW'])).toBe(false);
  });
});
