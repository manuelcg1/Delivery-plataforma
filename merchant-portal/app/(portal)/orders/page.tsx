'use client';

import {FormEvent,useCallback,useEffect,useRef,useState} from 'react';
import {Bike,CheckCircle2,House,MapPin,RefreshCw,Search,X} from 'lucide-react';
import {api,ApiError} from '@/lib/api';
import {useMerchant} from '@/lib/merchant';
import {useAuth} from '@/lib/auth';
import {useMerchantRealtime,type RealtimeStatus} from '@/lib/merchant-realtime';
import {orderTone,playNewOrderSound,prepareNewOrderSound,rememberOrderIds,unseenNewOrderIds} from '@/lib/order-experience';
import {canViewDeliveryLocation,locationPoints,markerPosition,osmEmbedUrl,relativeLocationTime} from '@/lib/delivery-location';
import type{AssignmentInfo,AvailableCourier,OrderDetail,OrderRow,Page,StatusCount}from'@/lib/types';
import './orders.css';

const labels:Record<string,string>={PENDING:'Nuevo',CONFIRMED:'Aceptado',PREPARING:'En preparación',READY:'Preparado',SEARCHING_COURIER:'Buscando repartidor',ASSIGNED:'Repartidor asignado',COURIER_ASSIGNED:'Repartidor asignado',PICKED_UP:'Entregado al repartidor',ON_THE_WAY:'En camino',DELIVERED:'Entregado al cliente',REJECTED:'Rechazado',CANCELLED:'Cancelado'};
const states=['','PENDING','CONFIRMED','PREPARING','READY','SEARCHING_COURIER','COURIER_ASSIGNED','PICKED_UP','ON_THE_WAY','DELIVERED','REJECTED','CANCELLED'];
const money=(value:number,currency:string)=>new Intl.NumberFormat('es-PE',{style:'currency',currency}).format(value);
const age=(date:string)=>`${Math.max(0,Math.floor((Date.now()-new Date(date).getTime())/60000))} min`;

export default function Orders(){
  const{context,merchantId,branchId}=useMerchant();
  const{me}=useAuth();
  const[rows,setRows]=useState<OrderRow[]>([]);
  const[counts,setCounts]=useState<StatusCount[]>([]);
  const[detail,setDetail]=useState<OrderDetail|null>(null);
  const[assignment,setAssignment]=useState<AssignmentInfo|null>(null);
  const[state,setState]=useState('');
  const[search,setSearch]=useState('');
  const[page,setPage]=useState(0);
  const[pages,setPages]=useState(0);
  const[loading,setLoading]=useState(false);
  const[error,setError]=useState('');
  const[showCouriers,setShowCouriers]=useState(false);
  const[courierSearch,setCourierSearch]=useState('');
  const[couriers,setCouriers]=useState<AvailableCourier[]>([]);
  const[assignedCourier,setAssignedCourier]=useState<string|null>(null);
  const[locationOrder,setLocationOrder]=useState<OrderRow|null>(null);
  const[location,setLocation]=useState<AssignmentInfo|null>(null);
  const[locationLoading,setLocationLoading]=useState(false);
  const[locationError,setLocationError]=useState('');
  const initialized=useRef(false);
  const seenOrders=useRef(new Set<string>());
  const can=(permission:string)=>!!me?.permissions.includes(permission);
  const seenKey=`merchant-orders-seen:${merchantId}`;

  const load=useCallback(async()=>{
    if(!merchantId)return;
    setLoading(true);
    try{
      const query=new URLSearchParams({merchantId,page:String(page),size:'20'});
      if(branchId)query.set('branchId',branchId);
      if(state)query.set('status',state);
      if(search)query.set('search',search);
      const newOrdersQuery=new URLSearchParams({merchantId,status:'PENDING',page:'0',size:'20'});
      if(branchId)newOrdersQuery.set('branchId',branchId);
      const[list,statusCounts,newOrders]=await Promise.all([
        api<Page<OrderRow>>(`/api/v1/merchant/orders?${query}`),
        api<StatusCount[]>(`/api/v1/merchant/orders/status-counts?merchantId=${merchantId}${branchId?`&branchId=${branchId}`:''}`),
        api<Page<OrderRow>>(`/api/v1/merchant/orders?${newOrdersQuery}`),
      ]);
      if(!initialized.current){
        try{for(const id of JSON.parse(sessionStorage.getItem(seenKey)??'[]') as string[])seenOrders.current.add(id);}catch{}
        for(const order of newOrders.content)seenOrders.current.add(order.id);
        rememberOrderIds(sessionStorage,seenKey,seenOrders.current);
        initialized.current=true;
      }else{
        const newIds=unseenNewOrderIds(newOrders.content,seenOrders.current);
        if(newIds.length)playNewOrderSound();
        for(const order of newOrders.content)seenOrders.current.add(order.id);
        rememberOrderIds(sessionStorage,seenKey,seenOrders.current);
      }
      setRows(list.content);setPages(list.totalPages);setCounts(statusCounts);setError('');
    }catch(cause){setError((cause as Error).message)}finally{setLoading(false)}
  },[merchantId,branchId,state,search,page,seenKey]);

  const realtime=useMerchantRealtime(context?.tenantId??'',merchantId,load);
  useEffect(()=>{
    initialized.current=false;seenOrders.current=new Set();
    void load();
    const refresh=()=>{if(document.visibilityState==='visible')void load()};
    const timer=setInterval(refresh,10000);
    document.addEventListener('visibilitychange',refresh);window.addEventListener('focus',refresh);
    return()=>{clearInterval(timer);document.removeEventListener('visibilitychange',refresh);window.removeEventListener('focus',refresh)};
  },[load]);
  useEffect(()=>{
    const unlock=()=>prepareNewOrderSound();
    window.addEventListener('pointerdown',unlock,{once:true});
    window.addEventListener('keydown',unlock,{once:true});
    return()=>{window.removeEventListener('pointerdown',unlock);window.removeEventListener('keydown',unlock)};
  },[]);

  async function open(id:string){
    setError('');
    try{
      const order=await api<OrderDetail>(`/api/v1/merchant/orders/${id}`);
      setDetail(order);
      setAssignment(await api<AssignmentInfo>(`/api/v1/merchant/orders/${id}/delivery/assignment`).catch(()=>null));
    }catch(cause){setError((cause as Error).message)}
  }

  async function refreshLocation(orderId:string){
    setLocationLoading(true);setLocationError('');
    try{setLocation(await api<AssignmentInfo>(`/api/v1/merchant/orders/${orderId}/delivery/assignment`))}
    catch(cause){setLocation(null);setLocationError((cause as Error).message)}
    finally{setLocationLoading(false)}
  }

  function openLocation(order:OrderRow){
    setLocationOrder(order);setLocation(null);void refreshLocation(order.id);
  }

  async function acceptOrder(){
    if(!detail)return;
    try{
      let current=detail;
      const remaining=current.order.status==='PENDING'?['CONFIRMED','PREPARING','READY']:
        current.order.status==='CONFIRMED'?['PREPARING','READY']:current.order.status==='PREPARING'?['READY']:[];
      for(const status of remaining){
        current=await api<OrderDetail>(`/api/v1/merchant/orders/${current.order.id}/status`,{
          method:'PATCH',body:JSON.stringify({status,expectedVersion:current.order.version}),
        });
      }
      setDetail(current);await load();
    }catch(cause){setError((cause as Error).message)}
  }

  async function assign(kind:'auto'|'manual',courierId?:string){
    if(!detail)return;
    try{
      const selectedName=couriers.find(item=>item.id===courierId)?.name;
      const result=await api<AssignmentInfo>(`/api/v1/merchant/orders/${detail.order.id}/delivery/${kind==='auto'?'auto-assign':'manual-assign'}`,{
        method:'POST',body:kind==='manual'?JSON.stringify({courierId}):undefined,
      });
      setAssignment(result);setShowCouriers(false);
      setAssignedCourier(result.courierName??selectedName??'El repartidor disponible');
      await open(detail.order.id);await load();
    }catch(cause){
      setError(cause instanceof ApiError&&cause.status===409&&cause.message.includes('asignado')?'El pedido ya fue asignado por otro usuario.':(cause as Error).message);
    }
  }

  async function findCouriers(event?:FormEvent){
    event?.preventDefault();if(!detail)return;
    try{
      const query=new URLSearchParams({search:courierSearch,size:'20'});
      const result=await api<Page<AvailableCourier>>(`/api/v1/merchant/orders/${detail.order.id}/delivery/available-couriers?${query}`);
      setCouriers(result.content);setShowCouriers(true);
    }catch(cause){setError((cause as Error).message)}
  }

  const total=counts.reduce((sum,item)=>sum+item.count,0);
  const count=(status:string)=>counts.find(item=>item.status===status)?.count??0;
  return <section className="page">
    <div className="title"><div><h1>Pedidos</h1><p>Actualización automática en tiempo real</p></div><div className="order-heading-actions"><ConnectionStatus status={realtime}/><button className="secondary" onClick={load}><RefreshCw className={loading?'spin':''}/>Actualizar</button></div></div>
    <div className="order-counts"><button className={!state?'selected':''} onClick={()=>{setState('');setPage(0)}}>Todos <b>{total}</b></button>{states.slice(1).map(status=><button key={status} className={state===status?'selected':''} onClick={()=>{setState(status);setPage(0)}}>{labels[status]??status} <b>{count(status)}</b></button>)}</div>
    <div className="order-filters"><label>Estado del pedido<select value={state} onChange={event=>{setState(event.target.value);setPage(0)}}>{states.map(status=><option key={status} value={status}>{status?labels[status]??status:'Todos'}</option>)}</select></label><label className="toolbar"><Search/><input aria-label="Buscar pedidos" placeholder="Pedido, cliente o repartidor" value={search} onChange={event=>{setSearch(event.target.value);setPage(0)}}/></label></div>
    {error&&<div className="alert" role="alert">{error}</div>}
    {loading&&!rows.length?<div className="empty">Cargando pedidos…</div>:<div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Pedido</th><th>Fecha y hora</th><th>Cliente</th><th>Sucursal</th><th>Total</th><th>Estado</th><th>Entrega</th><th>Repartidor</th><th>Pago</th><th>Tiempo</th><th>Acción</th></tr></thead><tbody>{rows.map(order=>{const tone=orderTone(order.status);return <tr key={order.id} className={`order-row order-row-${tone}`}><td><strong>#{order.orderNumber}</strong></td><td>{new Date(order.createdAt).toLocaleString('es-PE')}</td><td>{order.customerName}</td><td>{order.branchName}</td><td>{money(order.total,order.currency)}</td><td><OrderStatus status={order.status}/></td><td>{order.deliveryStatus?labels[order.deliveryStatus]??order.deliveryStatus:'—'}</td><td>{order.courierName??'Sin asignar'}</td><td>{order.paymentMethod??order.paymentStatus}</td><td>{age(order.createdAt)}</td><td><div className="order-row-actions"><button className="secondary compact" onClick={()=>open(order.id)}>Ver detalle</button>{canViewDeliveryLocation(order)&&<button className="location-button compact" onClick={()=>openLocation(order)}><MapPin/>Ver ubicación</button>}</div></td></tr>})}</tbody></table>{!rows.length&&<div className="empty">No hay pedidos con el estado seleccionado.</div>}</div>}
    <div className="pagination"><button className="secondary" disabled={page===0} onClick={()=>setPage(value=>value-1)}>Anterior</button><span>Página {page+1} de {Math.max(1,pages)}</span><button className="secondary" disabled={page+1>=pages} onClick={()=>setPage(value=>value+1)}>Siguiente</button></div>
    {detail&&<div className="drawer-backdrop" onClick={()=>setDetail(null)}><aside className="drawer order-detail" onClick={event=>event.stopPropagation()}><button className="close" aria-label="Cerrar" onClick={()=>setDetail(null)}><X/></button><h2>Pedido #{detail.order.orderNumber}</h2><OrderStatus status={detail.order.status}/><div className="customer"><strong>{detail.order.customerName}</strong><span>{detail.phone}</span><span>{detail.address}, {detail.district}</span></div><h3>Productos</h3>{detail.items.map((item,index)=><div className="item" key={index}><span>{item.quantity} × {item.productName}</span><b>{money(item.subtotal,detail.order.currency)}</b></div>)}<div className="total"><span>Total</span><strong>{money(detail.order.total,detail.order.currency)}</strong></div><section className="assignment"><h3>Asignación de repartidor</h3><dl><div><dt>Estado</dt><dd>{assignment?.assignmentStatus??'Sin asignación'}</dd></div><div><dt>Repartidor</dt><dd>{assignment?.courierName??'—'}</dd></div><div><dt>Vehículo</dt><dd>{assignment?.vehicleType??'—'}</dd></div><div><dt>Disponibilidad</dt><dd>{assignment?.courierStatus??'—'}</dd></div></dl>{assignment?.message&&<p className="assignment-message">{assignment.message}</p>}<div className="actions">{can('MERCHANT_DELIVERY_ASSIGN')&&detail.order.status==='READY'&&assignment?.assignmentStatus!=='PENDING'&&assignment?.assignmentStatus!=='ACCEPTED'&&<><button onClick={()=>assign('auto')}>Asignar repartidor</button><button className="secondary" onClick={()=>findCouriers()}>Elegir repartidor</button></>}</div></section><Actions status={detail.order.status} run={acceptOrder}/></aside></div>}
    {showCouriers&&<div className="modal-backdrop" onClick={()=>setShowCouriers(false)}><section className="courier-modal" onClick={event=>event.stopPropagation()}><button className="close" onClick={()=>setShowCouriers(false)}><X/></button><h2>Repartidores disponibles</h2><form className="toolbar" onSubmit={findCouriers}><Search/><input placeholder="Nombre, código, placa o vehículo" value={courierSearch} onChange={event=>setCourierSearch(event.target.value)}/></form><div className="orders-table-wrap"><table className="orders-table"><thead><tr><th>Repartidor</th><th>Vehículo</th><th>Estado</th><th>Distancia</th><th>Pedidos activos</th><th>Acción</th></tr></thead><tbody>{couriers.map(courier=><tr key={courier.id}><td>{courier.name}<br/><small>{courier.code.slice(0,8)}</small></td><td>{courier.vehicleType}<br/><small>{courier.partialPlate??'Sin placa'}</small></td><td>{courier.status}</td><td>{courier.distanceKm?`${courier.distanceKm} km`:'—'}</td><td>{courier.activeOrders}</td><td><button onClick={()=>assign('manual',courier.id)}>Seleccionar</button></td></tr>)}</tbody></table>{!couriers.length&&<div className="empty">No se encontraron repartidores disponibles.</div>}</div></section></div>}
    {locationOrder&&<DeliveryLocationModal order={locationOrder} info={location} loading={locationLoading} error={locationError} onRefresh={()=>refreshLocation(locationOrder.id)} onClose={()=>{setLocationOrder(null);setLocation(null);setLocationError('')}}/>}
    {assignedCourier&&<div className="modal-backdrop success-backdrop" onClick={()=>setAssignedCourier(null)}><section className="assignment-success" role="dialog" aria-modal="true" aria-labelledby="assignment-success-title" onClick={event=>event.stopPropagation()}><span className="success-icon"><CheckCircle2/></span><h2 id="assignment-success-title">Repartidor asignado</h2><strong>{assignedCourier}</strong><p>recibirá este pedido.</p><div className="success-actions"><button onClick={()=>setAssignedCourier(null)}>Ver pedido</button><button className="secondary" onClick={()=>setAssignedCourier(null)}>Cerrar</button></div></section></div>}
  </section>;
}

function DeliveryLocationModal({order,info,loading,error,onRefresh,onClose}:{order:OrderRow;info:AssignmentInfo|null;loading:boolean;error:string;onRefresh:()=>void;onClose:()=>void}){
  const points=info?locationPoints(info):{courier:null,customer:null};
  const visible=[points.courier,points.customer].filter(point=>point!==null);
  return <div className="modal-backdrop location-backdrop" onClick={onClose}>
    <section className="delivery-location-modal" role="dialog" aria-modal="true" aria-labelledby="delivery-location-title" onClick={event=>event.stopPropagation()}>
      <header><div><span className="location-eyebrow">PEDIDO #{order.orderNumber}</span><h2 id="delivery-location-title">Ubicación de la entrega</h2></div><button className="close" aria-label="Cerrar ubicación" onClick={onClose}><X/></button></header>
      <div className="location-legend"><span><i className="courier-dot"><Bike/></i>Repartidor</span><span><i className="customer-dot"><House/></i>Cliente</span></div>
      {error&&<div className="alert" role="alert">{error}</div>}
      {loading&&!info?<div className="location-loading"><RefreshCw className="spin"/>Consultando ubicación más reciente…</div>:visible.length>0?<div className="delivery-map">
        <iframe title="Mapa de ubicación de la entrega" src={osmEmbedUrl(visible)}/>
        {points.courier&&<span className="delivery-marker courier-marker" style={markerPosition(points.courier,visible)} title="Repartidor"><Bike/></span>}
        {points.customer&&<span className="delivery-marker customer-marker" style={markerPosition(points.customer,visible)} title="Cliente"><House/></span>}
        <span className="map-attribution">OpenStreetMap</span>
      </div>:!error&&<div className="location-empty"><MapPin/><strong>Ubicaciones no disponibles</strong><span>El mapa aparecerá cuando existan coordenadas válidas.</span></div>}
      <div className="location-statuses">
        <p className={points.courier?'available':'unavailable'}><Bike/><span><strong>{points.courier?'Repartidor localizado':'Ubicación del repartidor no disponible'}</strong>{points.courier&&<small>Última actualización: {relativeLocationTime(info?.lastLocationAt??null)}</small>}</span></p>
        <p className={points.customer?'available':'unavailable'}><House/><span><strong>{points.customer?'Cliente localizado':'Ubicación del cliente no disponible'}</strong></span></p>
      </div>
      <footer><button className="secondary" onClick={onRefresh} disabled={loading}><RefreshCw className={loading?'spin':''}/>Actualizar ubicación</button><button onClick={onClose}>Cerrar</button></footer>
    </section>
  </div>;
}

function ConnectionStatus({status}:{status:RealtimeStatus}){
  const text=status==='connected'?'Conectado':status==='reconnecting'?'Reconectando':'Sin conexión';
  return <span className={`connection-status connection-${status}`} role="status"><i/>{text}</span>;
}

function OrderStatus({status}:{status:string}){
  return <span className={`order-state order-state-${orderTone(status)}`}><i/>{labels[status]??status}</span>;
}

function Actions({status,run}:{status:string;run:()=>void}){
  if(['PENDING','CONFIRMED','PREPARING'].includes(status))return <div className="actions"><button onClick={run}>Aceptar pedido</button></div>;
  return null;
}
