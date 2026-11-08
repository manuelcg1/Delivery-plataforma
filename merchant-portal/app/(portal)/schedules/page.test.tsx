// @vitest-environment jsdom
import '@testing-library/jest-dom/vitest';
import {act,cleanup,fireEvent,render,screen,waitFor,within} from '@testing-library/react';
import {afterEach,beforeEach,expect,it,vi} from 'vitest';
import Schedules from './page';
const scope=vi.hoisted(()=>({merchantId:'m1',branchId:'',context:{merchants:[{id:'m1',branches:[{id:'b1',name:'Centro'},{id:'b2',name:'Norte'}]},{id:'m2',branches:[{id:'b3',name:'Otro comercio'}]}]}}));
vi.mock('@/lib/merchant',()=>({useMerchant:()=>scope}));
vi.mock('@/lib/api',()=>({api:vi.fn()}));
import {api} from '@/lib/api';
const request=vi.mocked(api);
beforeEach(()=>{scope.merchantId='m1';scope.branchId='';request.mockReset();request.mockResolvedValue([])});
afterEach(cleanup);
it('shows every authorized branch of the selected merchant and restricts selected scope',async()=>{
 const view=render(<Schedules/>);expect(await screen.findByRole('heading',{name:'Centro'})).toBeInTheDocument();expect(screen.getByRole('heading',{name:'Norte'})).toBeInTheDocument();expect(screen.queryByText('Otro comercio')).not.toBeInTheDocument();
 scope.branchId='b2';view.rerender(<Schedules/>);expect(screen.queryByRole('heading',{name:'Centro'})).not.toBeInTheDocument();expect(screen.getByRole('heading',{name:'Norte'})).toBeInTheDocument();
});
it('saves seven closed days explicitly and distinguishes unconfigured admission',async()=>{
 scope.branchId='b1';render(<Schedules/>);expect(await screen.findByText(/se aceptan pedidos hasta guardar/i)).toBeInTheDocument();fireEvent.click(screen.getByRole('button',{name:'Editar horario'}));fireEvent.click(screen.getByRole('button',{name:'Guardar horario'}));
 await waitFor(()=>expect(request).toHaveBeenCalledWith('/api/v1/branches/b1/business-hours',expect.objectContaining({method:'PUT'})));
 const body=JSON.parse(request.mock.calls.find(call=>call[1]?.method==='PUT')![1]!.body as string);expect(body).toHaveLength(7);expect(body.every((day:{closed:boolean;openTime:null})=>day.closed&&day.openTime===null)).toBe(true);
});
it('preserves a second shift and accepts overnight hours',async()=>{
 scope.branchId='b1';request.mockResolvedValue([{dayOfWeek:1,closed:false,openTime:'22:00:00',closeTime:'02:00:00',secondOpenTime:'04:00:00',secondCloseTime:'06:00:00'}]);render(<Schedules/>);fireEvent.click(await screen.findByRole('button',{name:'Editar horario'}));fireEvent.click(screen.getByRole('button',{name:'Guardar horario'}));
 await waitFor(()=>expect(request.mock.calls.some(call=>call[1]?.method==='PUT')).toBe(true));const body=JSON.parse(request.mock.calls.find(call=>call[1]?.method==='PUT')![1]!.body as string);expect(body[0]).toMatchObject({openTime:'22:00',closeTime:'02:00',secondOpenTime:'04:00',secondCloseTime:'06:00'});
});
it.each([['09:00','09:00'],['','18:00'],['10:00','13:00']])('rejects invalid or overlapping ranges %s %s',async(open,close)=>{
 scope.branchId='b1';request.mockResolvedValue([{dayOfWeek:1,closed:false,openTime:'09:00',closeTime:'12:00',secondOpenTime:'13:00',secondCloseTime:'18:00'}]);render(<Schedules/>);fireEvent.click(await screen.findByRole('button',{name:'Editar horario'}));const monday=screen.getByRole('group',{name:'Lunes'});fireEvent.change(within(monday).getByLabelText('Apertura'),{target:{value:open}});fireEvent.change(within(monday).getByLabelText('Cierre'),{target:{value:close}});if(open==='10:00')fireEvent.change(within(monday).getByLabelText('Segunda apertura'),{target:{value:'11:00'}});fireEvent.click(screen.getByRole('button',{name:'Guardar horario'}));expect(await screen.findByRole('alert')).toHaveTextContent(/Lunes/);expect(request.mock.calls.some(call=>call[1]?.method==='PUT')).toBe(false);
});
it('requires a successful load before editing and offers retry',async()=>{
 scope.branchId='b1';request.mockRejectedValueOnce(new Error('Sin conexión'));render(<Schedules/>);expect(await screen.findByRole('alert')).toHaveTextContent('Sin conexión');expect(screen.queryByRole('button',{name:'Editar horario'})).not.toBeInTheDocument();fireEvent.click(screen.getByRole('button',{name:'Reintentar'}));expect(await screen.findByRole('button',{name:'Editar horario'})).toBeInTheDocument();
});
it('ignores stale responses after changing merchant',async()=>{
 let resolve!:(value:unknown)=>void;request.mockImplementationOnce(()=>new Promise(done=>{resolve=done}));const view=render(<Schedules/>);scope.merchantId='m2';view.rerender(<Schedules/>);await screen.findByRole('heading',{name:'Otro comercio'});await act(async()=>resolve([{dayOfWeek:1,closed:false,openTime:'01:00',closeTime:'02:00'}]));expect(screen.queryByRole('heading',{name:'Centro'})).not.toBeInTheDocument();expect(screen.queryByText('01:00 – 02:00')).not.toBeInTheDocument();
});
it('ignores a late save after selecting another branch and prevents duplicate submissions',async()=>{
 scope.branchId='b1';let finish!:(value:unknown)=>void;request.mockImplementation((_path,options)=>options?.method==='PUT'?new Promise(resolve=>{finish=resolve}):Promise.resolve([]));const view=render(<Schedules/>);
 fireEvent.click(await screen.findByRole('button',{name:'Editar horario'}));fireEvent.click(screen.getByRole('button',{name:'Guardar horario'}));fireEvent.click(screen.getByRole('button',{name:'Guardando…'}));expect(request.mock.calls.filter(call=>call[1]?.method==='PUT')).toHaveLength(1);
 scope.branchId='b2';view.rerender(<Schedules/>);await screen.findByRole('button',{name:'Editar horario'});await act(async()=>finish([{dayOfWeek:1,closed:false,openTime:'01:00',closeTime:'02:00'}]));expect(screen.queryByText('Horario actualizado correctamente.')).not.toBeInTheDocument();expect(screen.queryByText('01:00 – 02:00')).not.toBeInTheDocument();expect(screen.getByRole('heading',{name:'Norte'})).toBeInTheDocument();
});
