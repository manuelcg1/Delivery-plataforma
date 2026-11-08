import {render,screen,fireEvent} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import MerchantYapeFields from './MerchantYapeFields';
import {emptyYape} from '@/lib/merchant-yape';

describe('merchant Yape fields',()=>{
  it('starts disabled and toggles explicitly',()=>{
    const change=vi.fn();
    render(<MerchantYapeFields value={emptyYape} errors={{}} onChange={change}/>);
    expect(screen.queryByLabelText('Número Yape')).not.toBeInTheDocument();
    fireEvent.click(screen.getByLabelText('Habilitar Yape'));
    expect(change).toHaveBeenCalledWith({...emptyYape,enabled:true});
  });
  it('shows an uncropped QR and connects field errors accessibly',()=>{
    render(<MerchantYapeFields value={{...emptyYape,enabled:true,qrUrl:'https://signed.test/qr'}} errors={{phone:'Número inválido'}} onChange={vi.fn()}/>);
    expect(screen.getByAltText('QR Yape del comercio')).toHaveStyle({objectFit:'contain'});
    expect(screen.getByLabelText('Número Yape')).toHaveAccessibleDescription('Número inválido');
  });
});
