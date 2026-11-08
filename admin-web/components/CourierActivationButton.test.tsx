import {fireEvent,render,screen,waitFor} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import {api} from '@/lib/api';
import CourierActivationButton from './CourierActivationButton';
vi.mock('@/lib/api',()=>({api:vi.fn()}));
describe('courier activation',()=>{
  it('only offers activation for inactive couriers',()=>{
    render(<CourierActivationButton id="courier" status="ACTIVE" onActivated={vi.fn()}/>);
    expect(screen.queryByRole('button')).not.toBeInTheDocument();
  });
  it('posts activation once and refreshes only after success',async()=>{
    const refresh=vi.fn().mockResolvedValue(undefined);
    vi.mocked(api).mockResolvedValueOnce({status:'ACTIVE'});
    render(<CourierActivationButton id="courier" status="INACTIVE" onActivated={refresh}/>);
    fireEvent.click(screen.getByRole('button',{name:'Activar repartidor'}));
    await waitFor(()=>expect(refresh).toHaveBeenCalledOnce());
    expect(api).toHaveBeenCalledWith('/api/v1/couriers/courier/activate',{method:'POST'});
  });
  it('keeps approval available for retry after failure',async()=>{
    vi.mocked(api).mockRejectedValueOnce(new Error('Sin permiso'));
    const refresh=vi.fn();
    render(<CourierActivationButton id="courier" status="INACTIVE" onActivated={refresh}/>);
    fireEvent.click(screen.getByRole('button',{name:'Activar repartidor'}));
    expect(await screen.findByRole('alert')).toHaveTextContent('Sin permiso');
    expect(refresh).not.toHaveBeenCalled();
    expect(screen.getByRole('button',{name:'Activar repartidor'})).toBeEnabled();
  });
});
