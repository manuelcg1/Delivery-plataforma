import {render,screen,fireEvent} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import MerchantPortalAccessFields from './MerchantPortalAccessFields';
import {emptyPortalAccount} from '@/lib/merchant-portal-access';

describe('portal access fields',()=>{
  it('hides credential fields when account creation is disabled',()=>{
    render(<MerchantPortalAccessFields enabled={false} disabled={false} value={emptyPortalAccount} errors={{}} onEnable={vi.fn()} onChange={vi.fn()}/>);
    expect(screen.queryByLabelText('Contraseña de acceso')).not.toBeInTheDocument();
  });
  it('protects password input and disables credentials after merchant creation',()=>{
    render(<MerchantPortalAccessFields enabled disabled value={emptyPortalAccount} errors={{}} onEnable={vi.fn()} onChange={vi.fn()}/>);
    expect(screen.getByLabelText('Contraseña de acceso')).toHaveAttribute('type','password');
    expect(screen.getByLabelText('Correo de acceso')).toBeDisabled();
    expect(screen.getByLabelText('Confirmar contraseña')).toBeDisabled();
  });
  it('allows a separate access email without changing commercial contact data',()=>{
    const change=vi.fn();
    render(<MerchantPortalAccessFields enabled disabled={false} value={emptyPortalAccount} errors={{}} onEnable={vi.fn()} onChange={change}/>);
    fireEvent.change(screen.getByLabelText('Correo de acceso'),{target:{value:'operator@example.test'}});
    expect(change).toHaveBeenCalledWith({...emptyPortalAccount,email:'operator@example.test'});
  });
});
