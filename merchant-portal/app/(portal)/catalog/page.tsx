'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useMerchant } from '@/lib/merchant';
import type { Page } from '@/lib/types';

type Product = { id:string; name:string; basePrice:number; currency:string; status:string; available:boolean };

export default function Catalog() {
  const { merchantId } = useMerchant();
  const [data, setData] = useState<Product[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!merchantId) { setData([]); return; }
    setLoading(true);
    setError('');
    api<Page<Product>>(`/api/v1/merchants/${merchantId}/products?size=100`)
      .then(page => setData(page.content ?? []))
      .catch(caught => { setData([]); setError((caught as Error).message); })
      .finally(() => setLoading(false));
  }, [merchantId]);

  return <section className="page">
    <div className="title"><div><h1>Catálogo</h1><p>Productos reales del comercio seleccionado</p></div></div>
    {error && <div className="alert" role="alert">{error}</div>}
    <div className="table">
      <div className="tr head"><span>Producto</span><span>Estado</span><span>Precio</span></div>
      {data.map(product => <div className="tr" key={product.id}>
        <strong>{product.name}</strong><span className="status">{product.status}</span>
        <span>{new Intl.NumberFormat('es-PE', { style:'currency', currency:product.currency || 'PEN' }).format(Number(product.basePrice) || 0)}</span>
      </div>)}
      {!loading && data.length === 0 && <div className="empty"><p>No hay productos registrados en este comercio.</p></div>}
      {loading && <div className="empty"><p>Cargando catálogo…</p></div>}
    </div>
  </section>;
}
