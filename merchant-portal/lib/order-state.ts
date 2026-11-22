export const allowedOrderActions:Record<string,string[]>={PENDING:['CONFIRMED','REJECTED','CANCELLED'],CONFIRMED:['PREPARING','CANCELLED'],PREPARING:['READY','CANCELLED'],READY:['PICKED_UP','DELIVERED'],PICKED_UP:['ON_THE_WAY','DELIVERED'],ON_THE_WAY:['DELIVERED']};
export function canTransition(from:string,to:string){return allowedOrderActions[from]?.includes(to)??false}
/** Asignaciones que el comercio todavía puede cancelar o reasignar (antes de que el repartidor recoja el pedido). */
export function canChangeCourier(orderStatus:string,assignmentStatus:string|null|undefined){
  return orderStatus==='READY'&&(assignmentStatus==='PENDING'||assignmentStatus==='ACCEPTED');
}
export const assignmentStatusLabels:Record<string,string>={PENDING:'Esperando respuesta del repartidor',ACCEPTED:'Aceptado por el repartidor',REJECTED:'Rechazado por el repartidor',EXPIRED:'Sin respuesta (expirado)',CANCELLED:'Cancelado por el comercio'};
