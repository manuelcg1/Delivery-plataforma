export const merchantTypes = [
  {value:'RESTAURANT',label:'Restaurante'},
  {value:'GROCERY',label:'Supermercado'},
  {value:'PHARMACY',label:'Farmacia'},
  {value:'RETAIL',label:'Tienda minorista'},
  {value:'DARK_STORE',label:'Tienda de despacho'},
  {value:'POLLERIA',label:'Pollería'},
  {value:'BURGERS',label:'Hamburguesas'},
  {value:'CHIFA',label:'Chifa'},
  {value:'ICE_CREAM',label:'Heladería'},
  {value:'BODEGA',label:'Bodegas'},
  {value:'SERVICES',label:'Servicios'},
  {value:'OTHER',label:'Otro'},
] as const;

export function merchantTypeLabel(value:string):string {
  return merchantTypes.find(type=>type.value===value)?.label ?? 'Tipo no disponible';
}
