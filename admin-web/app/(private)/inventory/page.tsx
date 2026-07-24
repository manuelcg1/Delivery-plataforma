'use client';

import Link from 'next/link';
import { FormEvent, useCallback, useEffect, useState } from 'react';
import { AlertTriangle, ArrowDown, ArrowUp, Boxes, PackagePlus, RefreshCw } from 'lucide-react';
import { api, ApiClientError } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { Pagination } from '@/components/Pagination';
import './inventory.css';

type Stock = { productId:string; productName:string; sku:string|null; quantity:number; lowStockThreshold:number|null; lowStock:boolean };
type Target = { productId:string; productName:string; sku:string|null; quantity:number; trackInventory:boolean };
type Movement = { id:string; productId:string|null; variantId:string|null; productName:string|null; movementType:string; quantity:number; previousQuantity:number; resultingQuantity:number; createdAt:string };
type Page<T> = { content:T[]; page:number; size:number; totalElements:number; totalPages:number; first:boolean; last:boolean };
const empty = <T,>():Page<T> => ({content:[],page:0,size:20,totalElements:0,totalPages:0,first:true,last:true});
const movementLabels:Record<string,string>={INITIAL:'Stock inicial',INCREASE:'Entrada',DECREASE:'Salida',ADJUSTMENT:'Ajuste',SALE:'Venta',RETURN:'Devolución',CANCELLATION:'Anulación'};

export default function Inventory() {
  const { can } = useAuth();
  const canAdjust = can('CATALOG_INVENTORY_ADJUST');
  const [stock,setStock]=useState<Page<Stock>>(empty());
  const [targets,setTargets]=useState<Target[]>([]);
  const [movements,setMovements]=useState<Page<Movement>>(empty());
  const [stockPage,setStockPage]=useState(0);
  const [movementPage,setMovementPage]=useState(0);
  const [search,setSearch]=useState('');
  const [type,setType]=useState('');
  const [loading,setLoading]=useState(true);
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState('');
  const [success,setSuccess]=useState('');

  const loadStock=useCallback(async()=>setStock(await api<Page<Stock>>(`/api/v1/inventory?page=${stockPage}&size=20&search=${encodeURIComponent(search)}`)),[stockPage,search]);
  const loadMovements=useCallback(async()=>setMovements(await api<Page<Movement>>(`/api/v1/inventory/movements?page=${movementPage}&size=20${type?`&movementType=${type}`:''}`)),[movementPage,type]);
  const loadTargets=useCallback(async()=>{if(canAdjust)setTargets(await api<Target[]>('/api/v1/inventory/targets'))},[canAdjust]);
  const loadAll=useCallback(async()=>{setLoading(true);setError('');try{await Promise.all([loadStock(),loadMovements(),loadTargets()])}catch(e){setError(e instanceof Error?e.message:'No se pudo cargar el inventario')}finally{setLoading(false)}},[loadStock,loadMovements,loadTargets]);
  useEffect(()=>{void loadAll()},[loadAll]);

  async function adjust(event:FormEvent<HTMLFormElement>){
    event.preventDefault();setBusy(true);setError('');setSuccess('');
    const formElement=event.currentTarget;
    const form=new FormData(formElement);
    try{
      await api('/api/v1/inventory/adjustments',{method:'POST',body:JSON.stringify({productId:form.get('productId'),variantId:null,branchId:null,movementType:form.get('movementType'),quantity:Number(form.get('quantity')),notes:form.get('notes')})});
      formElement.reset();await loadAll();setSuccess('El inventario se actualizó correctamente.');
    }catch(e){setError(e instanceof ApiClientError?e.message:'No se pudo registrar el ajuste')}finally{setBusy(false)}
  }

  return <>
    <div className="title inventory-title"><div><p className="eyebrow">CATÁLOGO</p><h1>Inventario</h1><p>Control de existencias y trazabilidad de movimientos.</p></div>{canAdjust&&<button className="secondary" onClick={()=>{setSuccess('');void loadAll()}} disabled={loading}><RefreshCw size={17}/> Actualizar</button>}</div>
    {error&&<div className="error" role="alert"><strong>No se pudo completar la operación</strong><span>{error}</span></div>}
    {success&&<div className="success" role="status">{success}</div>}

    <section className="inventory-summary">
      <article className="panel"><Boxes/><span>Productos controlados</span><strong>{stock.totalElements}</strong></article>
      <article className="panel"><AlertTriangle/><span>Stock bajo en esta página</span><strong>{stock.content.filter(x=>x.lowStock).length}</strong></article>
      <article className="panel"><PackagePlus/><span>Movimientos registrados</span><strong>{movements.totalElements}</strong></article>
    </section>

    {canAdjust&&<form className="panel inventory-adjustment" onSubmit={adjust}>
      <div><h2>Registrar movimiento</h2><p>Selecciona un producto para activar o actualizar su control de stock.</p></div>
      <label>Producto<select name="productId" required defaultValue=""><option value="" disabled>Seleccionar producto</option>{targets.map(x=><option value={x.productId} key={x.productId}>{x.productName}{x.sku?` · ${x.sku}`:''} · Stock ${x.quantity}{!x.trackInventory?' · Sin control':''}</option>)}</select></label>
      <label>Tipo<select name="movementType" required defaultValue="INCREASE"><option value="INCREASE">Entrada de stock</option><option value="DECREASE">Salida de stock</option><option value="ADJUSTMENT">Establecer cantidad exacta</option><option value="INITIAL">Sumar stock inicial</option></select></label>
      <label>Cantidad<input name="quantity" type="number" min="0.001" step="0.001" required placeholder="0.000"/></label>
      <label className="inventory-notes">Motivo o referencia<input name="notes" maxLength={255} placeholder="Ej. recepción de proveedor, conteo físico"/></label>
      <div className="form-actions"><button type="submit" disabled={busy||targets.length===0}>{busy?'Guardando…':'Registrar movimiento'}</button></div>
    </form>}

    <div className="inventory-section-heading"><div><h2>Existencias</h2><p>{stock.totalElements} productos con inventario controlado</p></div><input aria-label="Buscar inventario" placeholder="Buscar por nombre o SKU" value={search} onChange={e=>{setSearch(e.target.value);setStockPage(0)}}/></div>
    <section className="panel table inventory-table">{loading?<div className="empty">Cargando inventario…</div>:stock.content.length===0?<div className="empty inventory-empty"><Boxes/><strong>No hay productos con inventario controlado</strong><span>{targets.length?'Usa “Registrar movimiento” para activar el control de un producto existente.':'Primero crea un producto y activa la opción “Controlar inventario”.'}</span>{targets.length===0&&<Link className="button" href="/merchants">Ir a comercios</Link>}</div>:stock.content.map(x=><div className="tr inventory-row" key={x.productId}><span><strong>{x.productName}</strong><small>{x.sku||'Sin SKU'}</small></span><span><small>Stock actual</small><strong>{x.quantity}</strong></span><span><small>Stock mínimo</small><strong>{x.lowStockThreshold??'—'}</strong></span><span className={`badge ${x.lowStock?'suspended':'active'}`}>{x.lowStock?'STOCK BAJO':'DISPONIBLE'}</span></div>)}</section>
    <Pagination page={stock.page} totalPages={stock.totalPages} first={stock.first} last={stock.last} onPageChange={setStockPage}/>

    <div className="inventory-section-heading"><div><h2>Movimientos</h2><p>{movements.totalElements} movimientos registrados</p></div><select aria-label="Tipo de movimiento" value={type} onChange={e=>{setType(e.target.value);setMovementPage(0)}}><option value="">Todos los tipos</option>{Object.keys(movementLabels).map(x=><option key={x} value={x}>{movementLabels[x]}</option>)}</select></div>
    <section className="panel table">{loading?<div className="empty">Cargando movimientos…</div>:movements.content.length===0?<div className="empty">No hay movimientos para el filtro seleccionado.</div>:movements.content.map(x=><div className="tr movement-row" key={x.id}><span>{x.movementType==='DECREASE'||x.movementType==='SALE'?<ArrowDown/>:<ArrowUp/>}<span><strong>{movementLabels[x.movementType]??x.movementType}</strong><small>{new Date(x.createdAt).toLocaleString('es-PE')}</small></span></span><strong>{x.quantity}</strong><span>{x.previousQuantity} → {x.resultingQuantity}</span><small>{x.productName??(x.productId?'Producto':'Variante')}</small></div>)}</section>
    <Pagination page={movements.page} totalPages={movements.totalPages} first={movements.first} last={movements.last} onPageChange={setMovementPage}/>
  </>;
}
