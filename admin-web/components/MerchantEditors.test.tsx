import {render,screen,fireEvent,waitFor,act} from '@testing-library/react';
import {describe,it,expect,vi,beforeEach} from 'vitest';
import {api,ApiClientError} from '@/lib/api';
import MerchantDetailsEditor from './MerchantDetailsEditor';
import MerchantMediaEditor from './MerchantMediaEditor';
vi.mock('@/lib/api',async original=>({...await original<typeof import('@/lib/api')>(),api:vi.fn()}));
const merchant={id:'one',name:'Tienda',code:'tienda',legalName:'Tienda SAC',merchantType:'GROCERY',email:'a@b.pe',phone:'123',defaultCurrency:'PEN',timezone:'America/Lima',description:'Descripción',status:'ACTIVE',logoObjectKey:'key',bannerObjectKey:null};
describe('merchant editing',()=>{beforeEach(()=>vi.mocked(api).mockReset());
 it('ignores an old save after navigation and prevents double submit',async()=>{
 let finish!:(value:unknown)=>void;vi.mocked(api).mockImplementationOnce(()=>new Promise(resolve=>{finish=resolve}));const saved=vi.fn();const view=render(<MerchantDetailsEditor merchant={merchant} canEdit onSaved={saved}/>);
 fireEvent.click(screen.getByRole('button',{name:'Guardar datos'}));fireEvent.click(screen.getByRole('button',{name:'Guardando…'}));expect(vi.mocked(api)).toHaveBeenCalledTimes(1);
 view.rerender(<MerchantDetailsEditor merchant={{...merchant,id:'two',name:'Segundo'}} canEdit onSaved={saved}/>);await act(async()=>finish({...merchant,name:'Anterior'}));expect(saved).not.toHaveBeenCalled();expect(screen.getByLabelText('Nombre comercial')).toHaveValue('Segundo');
 });
 it('uploads only the chosen image as multipart and retains the replacement after failure',async()=>{
 URL.createObjectURL=vi.fn(()=> 'blob:logo');URL.revokeObjectURL=vi.fn();vi.mocked(api).mockResolvedValueOnce({url:null}).mockResolvedValueOnce({url:null}).mockRejectedValueOnce(new ApiClientError('Carga fallida')).mockResolvedValueOnce({url:'https://signed.test/new'});
 render(<MerchantMediaEditor merchantId="one" canUpload/>);await waitFor(()=>expect(screen.getByLabelText('Logo comercial')).not.toBeDisabled());fireEvent.change(screen.getByLabelText('Logo comercial'),{target:{files:[new File(['png'],'logo.png',{type:'image/png'})]}});fireEvent.click(screen.getByRole('button',{name:'Guardar logo'}));await screen.findByText('Carga fallida');expect(screen.getByAltText('Vista previa del logo')).toBeInTheDocument();
 expect(vi.mocked(api).mock.calls[2][0]).toBe('/api/v1/merchants/one/logo');expect((vi.mocked(api).mock.calls[2][1]?.body as FormData).get('file')).toBeInstanceOf(File);fireEvent.click(screen.getByRole('button',{name:'Guardar logo'}));await screen.findByText('Logo guardado.');expect(screen.getByAltText('Logo actual')).toHaveAttribute('src','https://signed.test/new');
 });

 it('prefills and saves only general fields',async()=>{
 const saved=vi.fn();vi.mocked(api).mockResolvedValueOnce({...merchant,name:'Nuevo'});render(<MerchantDetailsEditor merchant={merchant} canEdit onSaved={saved}/>);
 expect(screen.getByLabelText('Razón social')).toHaveValue('Tienda SAC');fireEvent.change(screen.getByLabelText('Nombre comercial'),{target:{value:'Nuevo'}});fireEvent.click(screen.getByRole('button',{name:'Guardar datos'}));await waitFor(()=>expect(saved).toHaveBeenCalled());
 const [path,init]=vi.mocked(api).mock.calls[0];expect(path).toBe('/api/v1/merchants/one');expect(init?.method).toBe('PUT');const body=JSON.parse(init?.body as string);expect(body.name).toBe('Nuevo');expect(body).not.toHaveProperty('portalAccess');expect(body).not.toHaveProperty('status');
 });
 it('retains failed edits and cancels; view-only is disabled',async()=>{
 vi.mocked(api).mockRejectedValueOnce(new ApiClientError('Código duplicado'));const view=render(<MerchantDetailsEditor merchant={merchant} canEdit onSaved={vi.fn()}/>);fireEvent.change(screen.getByLabelText('Código'),{target:{value:'nuevo'}});fireEvent.click(screen.getByRole('button',{name:'Guardar datos'}));await screen.findByText('Código duplicado');expect(screen.getByLabelText('Código')).toHaveValue('nuevo');fireEvent.click(screen.getByRole('button',{name:'Cancelar cambios'}));expect(screen.getByLabelText('Código')).toHaveValue('tienda');view.rerender(<MerchantDetailsEditor merchant={merchant} canEdit={false} onSaved={vi.fn()}/>);expect(screen.getByLabelText('Código')).toBeDisabled();
 });
 it('resolves existing media and rejects unsupported replacements',async()=>{
 vi.mocked(api).mockResolvedValue({url:'https://signed.test/existing'});render(<MerchantMediaEditor merchantId="one" canUpload/>);expect(await screen.findByAltText('Logo actual')).toHaveAttribute('src','https://signed.test/existing');fireEvent.change(screen.getByLabelText('Logo comercial'),{target:{files:[new File(['bad'],'x.txt',{type:'text/plain'})]}});expect(await screen.findByRole('alert')).toHaveTextContent(/JPEG|PNG|WebP/);expect(screen.getByRole('button',{name:'Guardar logo'})).toBeDisabled();
 });
});
