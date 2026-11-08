import {act,cleanup,fireEvent,render,screen,waitFor} from '@testing-library/react';
import {afterEach,describe,expect,it,vi} from 'vitest';
import {api,ApiClientError} from '@/lib/api';
import MerchantPortalAccessEditor from './MerchantPortalAccessEditor';
vi.mock('@/lib/api',async original=>({...await original<typeof import('@/lib/api')>(),api:vi.fn()}));
const account={id:'user-1',email:'ana@example.com',firstName:'Ana',lastName:'Pérez',editable:true,reason:null};
afterEach(()=>{cleanup();vi.resetAllMocks()});
describe('merchant portal access editor',()=>{
  it('prefills public account details and omits a blank password when saving',async()=>{
    vi.mocked(api).mockResolvedValueOnce([account]).mockResolvedValueOnce({...account,firstName:'Andrea'});
    render(<MerchantPortalAccessEditor merchantId="one" canEdit/>);
    expect(await screen.findByLabelText('Correo de acceso')).toHaveValue(account.email);
    expect(screen.getByLabelText('Nueva contraseña')).toHaveValue('');
    fireEvent.change(screen.getByLabelText('Nombres del responsable'),{target:{value:'Andrea'}});
    fireEvent.click(screen.getByRole('button',{name:'Guardar acceso'}));
    await screen.findByText('Acceso actualizado.');
    expect(JSON.parse(vi.mocked(api).mock.calls[1][1]?.body as string)).toEqual({email:account.email,firstName:'Andrea',lastName:'Pérez'});
  });
  it('requires confirmation and clears changed passwords after success',async()=>{
    vi.mocked(api).mockResolvedValueOnce([account]).mockResolvedValueOnce(account);
    render(<MerchantPortalAccessEditor merchantId="one" canEdit/>);
    fireEvent.change(await screen.findByLabelText('Nueva contraseña'),{target:{value:'secure-pass-123'}});
    fireEvent.click(screen.getByRole('button',{name:'Guardar acceso'}));
    expect(await screen.findByText('Las contraseñas no coinciden')).toBeInTheDocument();
    expect(api).toHaveBeenCalledTimes(1);
    fireEvent.change(screen.getByLabelText('Confirmar nueva contraseña'),{target:{value:'secure-pass-123'}});
    fireEvent.click(screen.getByRole('button',{name:'Guardar acceso'}));
    await screen.findByText('Acceso actualizado.');
    expect(JSON.parse(vi.mocked(api).mock.calls[1][1]?.body as string).newPassword).toBe('secure-pass-123');
    expect(screen.getByLabelText('Nueva contraseña')).toHaveValue('');
    expect(screen.getByLabelText('Confirmar nueva contraseña')).toHaveValue('');
  });
  it('disables editing without permissions or for a shared identity',async()=>{
    vi.mocked(api).mockResolvedValueOnce([account]);
    const view=render(<MerchantPortalAccessEditor merchantId="one" canEdit={false}/>);
    expect(await screen.findByLabelText('Correo de acceso')).toBeDisabled();
    expect(screen.queryByRole('button',{name:'Guardar acceso'})).not.toBeInTheDocument();
    vi.mocked(api).mockResolvedValueOnce([{...account,editable:false,reason:'SHARED_PORTAL_IDENTITY'}]);
    view.rerender(<MerchantPortalAccessEditor merchantId="two" canEdit/>);
    expect(await screen.findByText(/cuenta está compartida/)).toBeInTheDocument();
    expect(screen.getByLabelText('Correo de acceso')).toBeDisabled();
  });
  it('shows load errors with explicit retry and an empty state',async()=>{
    vi.mocked(api).mockRejectedValueOnce(new ApiClientError('Sin conexión')).mockResolvedValueOnce([]);
    render(<MerchantPortalAccessEditor merchantId="one" canEdit/>);
    expect(await screen.findByRole('alert')).toHaveTextContent('Sin conexión');
    expect(screen.queryByLabelText('Correo de acceso')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button',{name:'Reintentar'}));
    expect(await screen.findByText('Este comercio no tiene cuentas de acceso al portal.')).toBeInTheDocument();
  });
  it('locks duplicate submissions and retains the draft on server error',async()=>{
    let reject!:(error:unknown)=>void;
    vi.mocked(api).mockResolvedValueOnce([account]).mockImplementationOnce(()=>new Promise((_,fail)=>{reject=fail}));
    render(<MerchantPortalAccessEditor merchantId="one" canEdit/>);
    fireEvent.change(await screen.findByLabelText('Correo de acceso'),{target:{value:'new@example.com'}});
    const button=screen.getByRole('button',{name:'Guardar acceso'});
    fireEvent.click(button);fireEvent.click(button);
    expect(api).toHaveBeenCalledTimes(2);
    await act(async()=>reject(new ApiClientError('Correo ya registrado',{email:'Correo ya registrado'})));
    expect(await screen.findAllByText('Correo ya registrado')).not.toHaveLength(0);
    expect(screen.getByLabelText('Correo de acceso')).toHaveValue('new@example.com');
  });
  it('discards old loads and secrets when the merchant changes',async()=>{
    let finish!:(value:unknown)=>void;
    vi.mocked(api).mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve})).mockResolvedValueOnce([{...account,email:'new@example.com'}]);
    const view=render(<MerchantPortalAccessEditor merchantId="old" canEdit/>);
    view.rerender(<MerchantPortalAccessEditor merchantId="new" canEdit/>);
    expect(await screen.findByLabelText('Correo de acceso')).toHaveValue('new@example.com');
    await act(async()=>finish([account]));
    await waitFor(()=>expect(screen.getByLabelText('Correo de acceso')).toHaveValue('new@example.com'));
    fireEvent.change(screen.getByLabelText('Nueva contraseña'),{target:{value:'secret-12345'}});
    vi.mocked(api).mockResolvedValueOnce([account]);
    view.rerender(<MerchantPortalAccessEditor merchantId="third" canEdit/>);
    expect(await screen.findByLabelText('Nueva contraseña')).toHaveValue('');
  });
  it('rejects invalid email, empty names and passwords outside character and byte limits',async()=>{
    vi.mocked(api).mockResolvedValueOnce([account]);
    render(<MerchantPortalAccessEditor merchantId="one" canEdit/>);
    fireEvent.change(await screen.findByLabelText('Correo de acceso'),{target:{value:'invalid'}});
    fireEvent.change(screen.getByLabelText('Nombres del responsable'),{target:{value:' '}});
    fireEvent.change(screen.getByLabelText('Apellidos del responsable'),{target:{value:' '}});
    for(const password of ['short','界'.repeat(25),' '.repeat(10)]){
      fireEvent.change(screen.getByLabelText('Nueva contraseña'),{target:{value:password}});
      fireEvent.change(screen.getByLabelText('Confirmar nueva contraseña'),{target:{value:password}});
      fireEvent.click(screen.getByRole('button',{name:'Guardar acceso'}));
      expect(screen.getByText('Ingresa un correo válido para acceder al portal')).toBeInTheDocument();
      expect(screen.getByText('Ingresa el nombre del responsable (máximo 100 caracteres)')).toBeInTheDocument();
      expect(screen.getByText('Ingresa el apellido del responsable (máximo 100 caracteres)')).toBeInTheDocument();
      expect(screen.getByText('Usa al menos 10 caracteres y un máximo de 72 bytes')).toBeInTheDocument();
    }
    expect(api).toHaveBeenCalledTimes(1);
  });
  it('ignores a completed save belonging to a previous merchant',async()=>{
    let finish!:(value:unknown)=>void;
    vi.mocked(api).mockResolvedValueOnce([account]).mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve})).mockResolvedValueOnce([{...account,email:'next@example.com'}]);
    const view=render(<MerchantPortalAccessEditor merchantId="old" canEdit/>);
    fireEvent.click(await screen.findByRole('button',{name:'Guardar acceso'}));
    view.rerender(<MerchantPortalAccessEditor merchantId="next" canEdit/>);
    expect(await screen.findByLabelText('Correo de acceso')).toHaveValue('next@example.com');
    await act(async()=>finish(account));
    expect(screen.queryByText('Acceso actualizado.')).not.toBeInTheDocument();
    expect(screen.getByLabelText('Correo de acceso')).toHaveValue('next@example.com');
  });
});
