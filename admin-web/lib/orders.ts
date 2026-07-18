export type CartItem={id:string;productId:string;productName:string;quantity:number;unitPrice:number;subtotal:number;notes?:string};
export type Cart={id:string;merchantId:string;branchId:string;subtotal:number;discount:number;tax:number;deliveryFee:number;total:number;currency:string;items:CartItem[]};
export type Address={id:string;label:string;recipientName:string;phone:string;addressLine:string;district?:string;reference?:string};
export type OrderHistory={id:string;status:OrderStatus;notes?:string;createdAt:string};
export type Order={id:string;orderNumber:string;merchantId:string;branchId:string;deliveryAddressId:string;status:OrderStatus;paymentStatus:string;subtotal:number;discount:number;tax:number;deliveryFee:number;total:number;currency:string;notes?:string;items:CartItem[];history:OrderHistory[];createdAt:string};
export type OrderStatus='DRAFT'|'PENDING'|'CONFIRMED'|'PREPARING'|'READY'|'ASSIGNED'|'PICKED_UP'|'ON_THE_WAY'|'DELIVERED'|'CANCELLED'|'REJECTED';
export const money=(value:number,currency='PEN')=>new Intl.NumberFormat('es-PE',{style:'currency',currency}).format(value);
export const statusLabel:Record<OrderStatus,string>={DRAFT:'Borrador',PENDING:'Pendiente',CONFIRMED:'Confirmado',PREPARING:'En preparación',READY:'Listo',ASSIGNED:'Asignado',PICKED_UP:'Recogido',ON_THE_WAY:'En camino',DELIVERED:'Entregado',CANCELLED:'Cancelado',REJECTED:'Rechazado'};
