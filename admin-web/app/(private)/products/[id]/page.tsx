'use client';

import { FormEvent, use, useCallback, useEffect, useState } from 'react';
import { api, ApiClientError } from '@/lib/api';

type Product={id:string;name:string;slug:string;description:string;productType:string;basePrice:number;currency:string;status:string;available:boolean;featured:boolean};
type Variant={id:string;sku:string;name:string;price:number;stockQuantity:number;available:boolean};
type Image={id:string;url:string;altText:string;primaryImage:boolean;sortOrder:number};
type Tab='general'|'variants'|'images';

export default function ProductEditor({params}:{params:Promise<{id:string}>}) {
  const {id}=use(params); const[p,setP]=useState<Product|null>(null); const[variants,setVariants]=useState<Variant[]>([]);
  const[images,setImages]=useState<Image[]>([]); const[tab,setTab]=useState<Tab>('general'); const[busy,setBusy]=useState(false); const[message,setMessage]=useState('');
  const load=useCallback(async()=>{const[product,productVariants,productImages]=await Promise.all([api<Product>(`/api/v1/products/${id}`),api<Variant[]>(`/api/v1/products/${id}/variants`),api<Image[]>(`/api/v1/products/${id}/images`)]);setP(product);setVariants(productVariants);setImages(productImages)},[id]);
  useEffect(()=>{void load()},[load]);
  async function action(value:'publish'|'unpublish'|'archive'){setBusy(true);setMessage('');try{setP(await api<Product>(`/api/v1/products/${id}/${value}`,{method:'POST'}))}catch(error){setMessage(error instanceof Error?error.message:'No se pudo actualizar')}finally{setBusy(false)}}
  async function addVariant(event:FormEvent<HTMLFormElement>){event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);try{await api(`/api/v1/products/${id}/variants`,{method:'POST',body:JSON.stringify({name:form.get('name'),sku:form.get('sku'),price:Number(form.get('price')),stockQuantity:Number(form.get('stock')),available:true,sortOrder:variants.length})});event.currentTarget.reset();await load()}catch(error){setMessage(error instanceof ApiClientError?error.message:'No se pudo crear la variante')}finally{setBusy(false)}}
  async function upload(event:FormEvent<HTMLFormElement>){event.preventDefault();const form=new FormData(event.currentTarget);setBusy(true);try{await api(`/api/v1/products/${id}/images`,{method:'POST',body:form});event.currentTarget.reset();await load()}catch(error){setMessage(error instanceof Error?error.message:'No se pudo subir la imagen')}finally{setBusy(false)}}
  async function removeImage(imageId:string){await api(`/api/v1/products/${id}/images/${imageId}`,{method:'DELETE'});await load()}
  async function makePrimary(imageId:string){await api(`/api/v1/products/${id}/images/${imageId}/primary`,{method:'PUT'});await load()}
  if(!p)return <div className="empty">Cargando producto…</div>;
  return <><div className="title"><div><p className="eyebrow">{p.productType}</p><h1>{p.name}</h1><p>{p.description}</p></div><span className={`badge ${p.status.toLowerCase()}`}>{p.status}</span></div>
    <div className="tabs" role="tablist"><button className={tab==='general'?'active':''} onClick={()=>setTab('general')}>Información general</button><button className={tab==='variants'?'active':''} onClick={()=>setTab('variants')}>Variantes ({variants.length})</button><button className={tab==='images'?'active':''} onClick={()=>setTab('images')}>Imágenes ({images.length})</button></div>
    {message&&<div className="error" role="alert">{message}</div>}
    {tab==='general'&&<section className="panel"><h2>{p.currency} {p.basePrice}</h2><p>Slug: {p.slug}</p><p>{p.available?'Disponible':'No disponible'} · {p.featured?'Destacado':'Estándar'}</p><div className="form-actions">{p.status!=='PUBLISHED'&&<button disabled={busy} onClick={()=>action('publish')}>Publicar</button>}{p.status==='PUBLISHED'&&<button disabled={busy} onClick={()=>action('unpublish')}>Despublicar</button>}<button className="danger" disabled={busy} onClick={()=>action('archive')}>Archivar</button></div></section>}
    {tab==='variants'&&<><form className="panel form" onSubmit={addVariant}><h2>Nueva variante</h2><div className="form-grid"><label>Nombre<input name="name" required/></label><label>SKU<input name="sku"/></label><label>Precio<input name="price" type="number" min="0" step="0.01" required/></label><label>Stock<input name="stock" type="number" min="0" step="0.01" defaultValue="0" required/></label></div><button disabled={busy}>Agregar variante</button></form><section className="panel table">{variants.map(v=><div className="tr" key={v.id}><strong>{v.name}</strong><span>{v.sku||'Sin SKU'}</span><span>{p.currency} {v.price}</span><span>Stock {v.stockQuantity}</span></div>)}</section></>}
    {tab==='images'&&<><form className="panel form" onSubmit={upload}><h2>Agregar imagen</h2><p>JPEG, PNG o WebP; máximo 5 MB y 8 imágenes por producto.</p><label>Archivo<input name="file" type="file" accept="image/jpeg,image/png,image/webp" required/></label><label>Texto alternativo<input name="altText" maxLength={255}/></label><button disabled={busy||images.length>=8}>Subir imagen</button></form><section className="panel image-grid">{images.length===0?<div className="empty">Aún no hay imágenes.</div>:images.map(image=><article key={image.id}><img src={image.url} alt={image.altText||p.name}/><strong>{image.primaryImage?'Imagen principal':'Imagen secundaria'}</strong><div className="form-actions">{!image.primaryImage&&<button onClick={()=>makePrimary(image.id)}>Hacer principal</button>}<button className="danger" onClick={()=>removeImage(image.id)}>Eliminar</button></div></article>)}</section></>}
  </>;
}
