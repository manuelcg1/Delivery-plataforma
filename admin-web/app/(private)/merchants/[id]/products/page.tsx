'use client';

import Link from 'next/link';
import { use, useCallback, useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Pagination } from '@/components/Pagination';

type Product = { id:string; name:string; slug:string; productType:string; basePrice:number; currency:string; status:string; available:boolean };
type Page<T> = { content:T[]; page:number; size:number; totalElements:number; totalPages:number; first:boolean; last:boolean };

export default function Products({ params }: { params:Promise<{id:string}> }) {
  const { id } = use(params);
  const [result, setResult] = useState<Page<Product>>({ content:[], page:0, size:20, totalElements:0, totalPages:0, first:true, last:true });
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(0);
  const load = useCallback(() => api<Page<Product>>(`/api/v1/merchants/${id}/products?page=${page}&size=20&search=${encodeURIComponent(search)}`).then(setResult), [id, page, search]);
  useEffect(() => { void load(); }, [load]);

  return <>
    <div className="title"><div><p className="eyebrow">CATÁLOGO</p><h1>Productos</h1><p>{result.totalElements} productos registrados</p></div><Link className="button" href={`/products/new?merchantId=${id}`}>Nuevo producto</Link></div>
    <section className="panel">
      <label>Buscar producto<input value={search} onChange={event => { setSearch(event.target.value); setPage(0); }} placeholder="Nombre o SKU" /></label>
    </section>
    <section className="panel table">{result.content.length===0?<div className="empty">No hay productos para los filtros seleccionados.</div>:result.content.map(product=><Link className="tr" href={`/products/${product.id}`} key={product.id}><span><strong>{product.name}</strong><small>{product.slug}</small></span><span>{product.productType}</span><span>{product.currency} {product.basePrice}</span><span className={`badge ${product.status.toLowerCase()}`}>{product.status}</span></Link>)}</section>
    <Pagination page={result.page} totalPages={result.totalPages} first={result.first} last={result.last} onPageChange={setPage} />
  </>;
}
