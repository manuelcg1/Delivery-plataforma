'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { useMerchant } from '@/lib/merchant';
import type { Page } from '@/lib/types';

type Stock = {
  productId:string;
  productName:string;
  sku:string | null;
  quantity:number;
  lowStockThreshold:number | null;
  lowStock:boolean;
};

export default function Inventory() {
  const { merchantId } = useMerchant();
  const [data, setData] = useState<Stock[]>([]);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!merchantId) { setData([]); return; }
    setLoading(true);
    setError('');
    api<Page<Stock>>(`/api/v1/inventory?merchantId=${merchantId}&size=100`)
      .then(page => setData(page.content ?? []))
      .catch(caught => { setData([]); setError((caught as Error).message); })
      .finally(() => setLoading(false));
  }, [merchantId]);

  return <section className="page">
    <div className="title"><div><h1>Inventario</h1><p>Stock y alertas de disponibilidad</p></div></div>
    {error && <div className="alert" role="alert">{error}</div>}
    <div className="table">
      <div className="tr head"><span>Producto</span><span>SKU</span><span>Stock</span></div>
      {data.map(stock => <div className="tr" key={stock.productId}>
        <strong>{stock.productName}</strong><span>{stock.sku || '—'}</span>
        <span className={stock.lowStock ? 'low' : ''}>{Number(stock.quantity)}</span>
      </div>)}
      {!loading && data.length === 0 && <div className="empty"><p>No hay productos con control de inventario.</p></div>}
      {loading && <div className="empty"><p>Cargando inventario…</p></div>}
    </div>
  </section>;
}
