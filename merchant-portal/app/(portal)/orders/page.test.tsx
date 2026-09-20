// @vitest-environment jsdom

import '@testing-library/jest-dom/vitest';
import {act,cleanup,fireEvent,render,screen,waitFor,within} from '@testing-library/react';
import {createElement} from 'react';
import {afterEach,describe,expect,it,vi} from 'vitest';
import Orders from './page';

const state=vi.hoisted(()=>({
  assignmentStatus:'PENDING',
  message:'Pedido enviado al repartidor. Esperando aceptación.',
  realtimeCallback:null as null|(()=>void),
  courierLatitude:-12.1,
  customerLatitude:-12.2,
  mapProps:null as null|{courier:{latitude:number;longitude:number}|null;customer:{latitude:number;longitude:number}|null},
  customized:false,
}));

vi.mock('next/dynamic',()=>({
  default:()=> (props:typeof state.mapProps)=>{state.mapProps=props;return null},
}));

vi.mock('@/lib/merchant',()=>({
  useMerchant:()=>({
    context:{tenantId:'tenant-1'},
    merchantId:'merchant-1',
    branchId:'branch-1',
  }),
}));

vi.mock('@/lib/auth',()=>({
  useAuth:()=>({me:{permissions:['MERCHANT_DELIVERY_ASSIGN']}}),
}));

vi.mock('@/lib/merchant-realtime',()=>({
  useMerchantRealtime:(_tenant:string,_merchant:string,callback:()=>void)=>{
    state.realtimeCallback=callback;
    return 'connected';
  },
}));

vi.mock('@/lib/order-experience',()=>({
  orderTone:()=> 'active',
  playNewOrderSound:vi.fn(),
  prepareNewOrderSound:vi.fn(),
  rememberOrderIds:vi.fn(),
  unseenNewOrderIds:()=>[],
}));

vi.mock('@/lib/api',()=>({
  ApiError:class ApiError extends Error {status=500},
  api:vi.fn(async(path:string)=>{
    const items=state.customized?[
      {id:'item-1',productName:'Helado',quantity:2,unitPrice:12.5,subtotal:25,notes:'Sin cucharita',options:[
        {optionGroupId:'flavors',optionItemId:'strawberry',groupName:'Sabores',itemName:'Fresa',priceAdjustment:0},
        {optionGroupId:'extras',optionItemId:'chocolate',groupName:'Extras',itemName:'Chocolate',priceAdjustment:2.5},
      ]},
      {id:'item-2',productName:'Helado',quantity:1,unitPrice:10,subtotal:10,notes:null,options:[
        {optionGroupId:'flavors',optionItemId:'vanilla',groupName:'Sabores',itemName:'Vainilla',priceAdjustment:0},
      ]},
      {id:'item-3',productName:'Agua',quantity:1,unitPrice:3,subtotal:3,notes:null,options:[]},
    ]:[{id:'plain',productName:'Producto',quantity:1,unitPrice:20,subtotal:20,notes:null,options:[]}];
    const order={
      id:'order-1',orderNumber:'CERKA-100',merchantId:'merchant-1',
      branchId:'branch-1',branchName:'Centro',customerName:'Cliente',
      status:'READY',paymentStatus:'PAID',total:20,currency:'PEN',version:1,
      createdAt:'2026-08-15T12:00:00Z',updatedAt:'2026-08-15T12:00:00Z',
      deliveryStatus:'ASSIGNED',courierName:'Ana Repartidora',paymentMethod:'CARD',
      items,
    };
    if(path.includes('/delivery/assignment'))return {
      deliveryId:'delivery-1',assignmentId:'assignment-1',
      assignmentStatus:state.assignmentStatus,message:state.message,
      courierId:'courier-1',courierName:'Ana Repartidora',vehicleType:'MOTORCYCLE',
      courierStatus:'ONLINE',assignedAt:null,expiresAt:null,latitude:state.courierLatitude,
      longitude:-77.1,lastLocationAt:'2026-08-15T12:00:00Z',customerLatitude:state.customerLatitude,customerLongitude:-77.2,
    };
    if(path==='/api/v1/merchant/orders/order-1')return {
      order,phone:'999999999',address:'Av. Principal 123',district:'Centro',
      notes:state.customized?'Tocar el timbre':null,items,
    };
    if(path.includes('/status-counts'))return [{status:'READY',count:1}];
    if(path.startsWith('/api/v1/merchant/orders?'))return {
      content:[order],page:0,size:20,totalElements:1,totalPages:1,first:true,last:true,
    };
    throw new Error(`Solicitud inesperada: ${path}`);
  }),
}));

afterEach(()=>{
  cleanup();
  state.assignmentStatus='PENDING';
  state.message='Pedido enviado al repartidor. Esperando aceptación.';
  state.realtimeCallback=null;
  state.courierLatitude=-12.1;
  state.customerLatitude=-12.2;
  state.mapProps=null;
  state.customized=false;
});

describe('opciones del pedido',()=>{
  it('muestra las selecciones por producto en la tabla y todas las notas en el detalle',async()=>{
    state.customized=true;
    render(createElement(Orders));
    const table=await screen.findByRole('table');
    await within(table).findByText('2 × Helado');
    expect(within(table).getByRole('columnheader',{name:'Productos y opciones'})).toBeInTheDocument();
    expect(within(table).getByText('Fresa')).toBeInTheDocument();
    expect(within(table).getByText('Chocolate')).toBeInTheDocument();
    expect(within(table).getAllByText('Gratis')).toHaveLength(2);
    expect(within(table).getByText(/2[.,]50.*por unidad/)).toBeInTheDocument();
    expect(within(table).getByText('Sin cucharita')).toBeInTheDocument();
    expect(within(table).getByText('Vainilla')).toBeInTheDocument();
    fireEvent.click(within(table).getByRole('button',{name:'Ver 1 producto más'}));
    expect(within(table).getByText('1 × Agua')).toBeInTheDocument();
    fireEvent.click(within(table).getByRole('button',{name:'Mostrar menos productos'}));
    expect(within(table).queryByText('1 × Agua')).not.toBeInTheDocument();

    fireEvent.click(screen.getByRole('button',{name:'Ver detalle'}));
    const detail=await screen.findByRole('complementary');
    expect(await within(detail).findByText('Fresa')).toBeInTheDocument();
    expect(within(detail).getByText('Vainilla')).toBeInTheDocument();
    expect(within(detail).getByText('1 × Agua')).toBeInTheDocument();
    expect(within(detail).getByText('Sin cucharita')).toBeInTheDocument();
    expect(within(detail).getByText('Tocar el timbre')).toBeInTheDocument();
    expect(within(detail).queryByRole('button',{name:/producto más/})).not.toBeInTheDocument();
  });

  it('conserva los pedidos sin opciones y su subtotal',async()=>{
    render(createElement(Orders));
    const table=await screen.findByRole('table');
    expect(await within(table).findByText('1 × Producto')).toBeInTheDocument();
    expect(within(table).queryByText('Gratis')).not.toBeInTheDocument();
    fireEvent.click(screen.getByRole('button',{name:'Ver detalle'}));
    const detail=await screen.findByRole('complementary');
    expect(await within(detail).findByText('1 × Producto')).toBeInTheDocument();
    expect(within(detail).getAllByText(/20[.,]00/)).toHaveLength(2);
  });
});

describe('detalle de asignación del pedido',()=>{
  it.each([
    ['ACCEPTED','Entrega aceptada por el repartidor.'],
    ['REJECTED','Entrega rechazada por el repartidor.'],
  ])('actualiza el mensaje abierto cuando la asignación cambia a %s',async(status,message)=>{
    render(createElement(Orders));
    fireEvent.click(await screen.findByRole('button',{name:'Ver detalle'}));
    expect(await screen.findByText(state.message)).toBeInTheDocument();

    state.assignmentStatus=status;
    state.message=message;
    await act(async()=>{state.realtimeCallback?.()});

    expect(await screen.findByText(message)).toBeInTheDocument();
    expect(screen.queryByText('Pedido enviado al repartidor. Esperando aceptación.')).not.toBeInTheDocument();
    expect(screen.getByText(status)).toBeInTheDocument();
  });

  it('actualiza solo la última coordenada del repartidor',async()=>{
    render(createElement(Orders));
    fireEvent.click(await screen.findByRole('button',{name:'Ver ubicación'}));
    await waitFor(()=>expect(state.mapProps?.courier?.latitude).toBe(-12.1));
    expect(state.mapProps?.customer?.latitude).toBe(-12.2);

    state.courierLatitude=-12.15;
    await act(async()=>{state.realtimeCallback?.()});

    await waitFor(()=>expect(state.mapProps?.courier?.latitude).toBe(-12.15));
    expect(state.mapProps?.customer?.latitude).toBe(-12.2);
  });
});
