import {describe,it,expect,vi,afterEach} from 'vitest';
import {emptyYape,validateYape,validateYapeQrImage,yapeFormData} from './merchant-yape';
afterEach(()=>vi.unstubAllGlobals());

describe('merchant Yape settings',()=>{
  it('decodes real format signatures, accepts the size boundary and releases image URLs',async()=>{
    URL.createObjectURL=vi.fn(()=> 'blob:decode');URL.revokeObjectURL=vi.fn();
    vi.stubGlobal('Image',class{naturalWidth=4096;naturalHeight=4096;onload:(()=>void)|null=null;set src(value:string){void value;queueMicrotask(()=>this.onload?.())}});
    expect(await validateYapeQrImage(new File([new Uint8Array([255,216,255,224])],'qr.jpg',{type:'image/jpeg'}))).toBe('');
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:decode');
    expect(await validateYapeQrImage(null)).toBe('');
  });
  it('rejects a PNG signature when the browser cannot decode its contents',async()=>{
    URL.createObjectURL=vi.fn(()=> 'blob:decode');URL.revokeObjectURL=vi.fn();
    vi.stubGlobal('Image',class{onerror:(()=>void)|null=null;set src(value:string){void value;queueMicrotask(()=>this.onerror?.())}});
    expect(await validateYapeQrImage(new File([new Uint8Array([137,80,78,71,13,10,26,10])],'qr.png',{type:'image/png'}))).toMatch(/imagen QR válida/);
    expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:decode');
  });
  it('allows disabled merchants without inventing payment data',()=>{
    expect(validateYape(emptyYape)).toEqual({});
  });
  it('requires a Peruvian mobile, holder and QR when enabled',()=>{
    expect(validateYape({...emptyYape,enabled:true,phone:'812345678'})).toEqual({phone:expect.any(String),holderName:expect.any(String),qr:expect.any(String)});
    expect(validateYape({...emptyYape,enabled:true,phone:'912345678',holderName:' Ana ',qrUrl:'https://signed.test/qr'})).toEqual({});
  });
  it('rejects unsupported and oversized QR files',()=>{
    for(const qr of [new File(['x'],'qr.svg',{type:'image/svg+xml'}),new File(['x'],'qr.webp',{type:'image/webp'}),new File([new Uint8Array(5*1024*1024+1)],'qr.png',{type:'image/png'})]){
      expect(validateYape({...emptyYape,enabled:true,phone:'912345678',holderName:'Ana',qr}).qr).toBeTruthy();
    }
  });
  it('serializes only the endpoint fields and preserves uploaded QR on text updates',()=>{
    const body=yapeFormData({...emptyYape,enabled:true,phone:'912345678',holderName:' Ana ',qrUrl:'https://signed.test/qr'});
    expect([...body.keys()]).toEqual(['enabled','phone','holderName']);
    expect(body.get('holderName')).toBe('Ana');
  });
});
