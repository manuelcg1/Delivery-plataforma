import{describe,expect,it}from'vitest';
import{orderTone,rememberOrderIds,unseenNewOrderIds}from'./order-experience';
import type{OrderRow}from'./types';

const row=(id:string,status:string)=>({id,status} as OrderRow);
describe('experiencia de pedidos',()=>{
  it('aplica semáforo nuevo, entregado y neutral',()=>{
    expect(orderTone('PENDING')).toBe('new');
    expect(orderTone('DELIVERED')).toBe('delivered');
    expect(orderTone('PREPARING')).toBe('neutral');
  });
  it('detecta solo pedidos nuevos pendientes y evita duplicados',()=>{
    expect(unseenNewOrderIds([row('1','PENDING'),row('2','DELIVERED')],new Set())).toEqual(['1']);
    expect(unseenNewOrderIds([row('1','PENDING')],new Set(['1']))).toEqual([]);
  });
  it('persiste ids sin duplicarlos durante reconexiones',()=>{
    const storage=new Map<string,string>();
    const fake={getItem:(key:string)=>storage.get(key)??null,setItem:(key:string,value:string)=>void storage.set(key,value)} as Storage;
    rememberOrderIds(fake,'orders',['1','1','2']);
    rememberOrderIds(fake,'orders',['2','3']);
    expect(JSON.parse(storage.get('orders')!)).toEqual(['1','2','3']);
  });
});
