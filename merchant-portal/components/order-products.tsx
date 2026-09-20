'use client';

import {useId,useState} from 'react';
import type {OrderItem,OrderOption} from '@/lib/types';

const money=(value:number,currency:string)=>new Intl.NumberFormat('es-PE',{style:'currency',currency}).format(value);

export default function OrderProducts({items,currency,compact=false}:{items?:OrderItem[];currency:string;compact?:boolean}){
  const [expanded,setExpanded]=useState(false);
  const listId=useId();
  if(!items)return <span className="order-products-empty">Consulta el detalle del pedido</span>;
  if(!items.length)return <span className="order-products-empty">Sin productos registrados</span>;
  const hiddenCount=compact?Math.max(0,items.length-2):0;
  const visible=hiddenCount&&!expanded?items.slice(0,2):items;
  return <div className={`order-products${compact?' order-products-compact':''}`}>
    <ul id={listId} className="order-product-list">
      {visible.map((item,index)=><li key={item.id??index} className="order-product">
        <div className="order-product-heading">
          <strong>{item.quantity} × {item.productName}</strong>
          {!compact&&<b>{money(item.subtotal,currency)}</b>}
        </div>
        <SelectedOptions options={item.options??[]} currency={currency}/>
        {item.notes?.trim()&&<p className="order-product-note"><strong>Nota: </strong><span>{item.notes}</span></p>}
      </li>)}
    </ul>
    {hiddenCount>0&&<button type="button" className="secondary compact order-products-toggle" aria-expanded={expanded} aria-controls={listId} onClick={()=>setExpanded(value=>!value)}>
      {expanded?'Mostrar menos productos':`Ver ${hiddenCount} producto${hiddenCount===1?'':'s'} más`}
    </button>}
  </div>;
}

function SelectedOptions({options,currency}:{options:OrderOption[];currency:string}){
  const groups=new Map<string,{name:string;options:OrderOption[]}>();
  for(const option of options){
    const group=groups.get(option.optionGroupId)??{name:option.groupName,options:[]};
    group.options.push(option);
    groups.set(option.optionGroupId,group);
  }
  return <>{Array.from(groups,([id,group])=><div className="order-option-group" key={id}>
    <span className="order-option-group-name">{group.name}</span>
    <ul>{group.options.map(option=><li key={option.optionItemId}>
      <span>{option.itemName}</span>
      <small>{option.priceAdjustment===0?'Gratis':`+${money(option.priceAdjustment,currency)} por unidad`}</small>
    </li>)}</ul>
  </div>)}</>;
}
