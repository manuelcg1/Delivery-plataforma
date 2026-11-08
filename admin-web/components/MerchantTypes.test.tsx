import {render,screen} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import NewMerchant from '@/app/(private)/merchants/new/page';

vi.mock('next/navigation',()=>({useRouter:()=>({push:vi.fn()})}));
vi.mock('@/lib/auth',()=>({useAuth:()=>({can:()=>false})}));

describe('merchant type selection',()=>{
  it('displays Spanish labels while submitting stable codes',()=>{
    render(<NewMerchant/>);
    const options:Record<string,string>={Restaurante:'RESTAURANT',Farmacia:'PHARMACY',
      'Pollería':'POLLERIA',Hamburguesas:'BURGERS',Chifa:'CHIFA','Heladería':'ICE_CREAM',
      Bodegas:'BODEGA',Servicios:'SERVICES'};
    for(const [label,code] of Object.entries(options)) {
      expect(screen.getByRole('option',{name:label})).toHaveValue(code);
    }
    expect(screen.queryByRole('option',{name:'RESTAURANT'})).not.toBeInTheDocument();
  });
});
