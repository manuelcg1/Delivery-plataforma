export const allowedOrderActions:Record<string,string[]>={PENDING:['CONFIRMED','REJECTED','CANCELLED'],CONFIRMED:['PREPARING','CANCELLED'],PREPARING:['READY','CANCELLED'],READY:['PICKED_UP','DELIVERED'],PICKED_UP:['ON_THE_WAY','DELIVERED'],ON_THE_WAY:['DELIVERED']};
export function canTransition(from:string,to:string){return allowedOrderActions[from]?.includes(to)??false}
