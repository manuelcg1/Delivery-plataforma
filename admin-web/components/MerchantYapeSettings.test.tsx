import {render,screen,fireEvent,waitFor,act} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import MerchantYapeSettings from './MerchantYapeSettings';
import {api,ApiClientError} from '@/lib/api';
vi.mock('@/lib/api',async original=>({...await original<typeof import('@/lib/api')>(),api:vi.fn()}));
describe('existing merchant Yape settings',()=>{
  it('rejects a corrupt replacement before PUT and preserves unsaved text',async()=>{
    URL.createObjectURL=vi.fn(()=> 'blob:corrupt');URL.revokeObjectURL=vi.fn();
    vi.mocked(api).mockResolvedValueOnce({enabled:true,phone:'912345678',holderName:'Ana',qrUrl:'https://signed.test/qr',version:'v1'});
    render(<MerchantYapeSettings merchantId="merchant-corrupt" canEdit canUpload/>);
    fireEvent.change(await screen.findByLabelText('Titular Yape'),{target:{value:'Texto pendiente'}});
    fireEvent.change(screen.getByLabelText('QR Yape'),{target:{files:[new File(['corrupt'],'qr.png',{type:'image/png'})]}});
    fireEvent.click(screen.getByRole('button',{name:'Guardar Yape'}));
    expect(await screen.findByText(/imagen QR válida/)).toBeInTheDocument();
    expect(screen.getByLabelText('Titular Yape')).toHaveValue('Texto pendiente');
    expect(vi.mocked(api).mock.calls.filter(([,init])=>init?.method==='PUT')).toHaveLength(0);
  });
  it('ignores an old merchant response after navigation',async()=>{
    let finishOld!:(value:unknown)=>void;
    vi.mocked(api).mockImplementationOnce(()=>new Promise(resolve=>{finishOld=resolve})).mockResolvedValueOnce({enabled:true,phone:'912345678',holderName:'Nuevo comercio',qrUrl:'https://signed.test/new',version:'v2'});
    const view=render(<MerchantYapeSettings merchantId="old" canEdit canUpload/>);
    view.rerender(<MerchantYapeSettings merchantId="new" canEdit canUpload/>);
    expect(await screen.findByLabelText('Titular Yape')).toHaveValue('Nuevo comercio');
    await act(async()=>finishOld({enabled:true,phone:'912345679',holderName:'Comercio anterior',qrUrl:'https://signed.test/old',version:'v1'}));
    expect(screen.getByLabelText('Titular Yape')).toHaveValue('Nuevo comercio');
  });
  it('requires an explicit retry on load error instead of allowing overwrite with defaults',async()=>{
    vi.mocked(api).mockRejectedValueOnce(new ApiClientError('Error de conexión')).mockResolvedValueOnce({enabled:false,phone:null,holderName:null,qrUrl:null,version:null});
    render(<MerchantYapeSettings merchantId="merchant-1" canEdit canUpload/>);
    await screen.findByRole('alert');
    expect(screen.queryByRole('button',{name:'Guardar Yape'})).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button',{name:'Reintentar'}));
    expect(await screen.findByLabelText('Habilitar Yape')).not.toBeChecked();
  });
  it('keeps the existing QR on text changes and retains unsaved text on failure',async()=>{
    vi.mocked(api).mockResolvedValueOnce({enabled:true,phone:'912345678',holderName:'Ana',qrUrl:'https://signed.test/qr',version:'v1'}).mockRejectedValueOnce(new ApiClientError('No se pudo guardar'));
    render(<MerchantYapeSettings merchantId="merchant-2" canEdit canUpload={false}/>);
    const holder=await screen.findByLabelText('Titular Yape');
    fireEvent.change(holder,{target:{value:'Ana Pérez'}});
    fireEvent.click(screen.getByRole('button',{name:'Guardar Yape'}));
    await waitFor(()=>expect(screen.getByRole('alert')).toHaveTextContent('No se pudo guardar'));
    expect(holder).toHaveValue('Ana Pérez');
    const body=vi.mocked(api).mock.calls.at(-1)?.[1]?.body as FormData;
    expect(body.get('holderName')).toBe('Ana Pérez');
    expect(body.has('qr')).toBe(false);
  });
});
