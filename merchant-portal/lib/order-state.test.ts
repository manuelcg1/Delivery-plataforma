import{describe,expect,it}from'vitest';import{canTransition}from'./order-state';describe('flujo de pedidos',()=>{it('permite el recorrido operativo',()=>{expect(canTransition('PENDING','CONFIRMED')).toBe(true);expect(canTransition('CONFIRMED','PREPARING')).toBe(true);expect(canTransition('PREPARING','READY')).toBe(true)});it('impide saltos y estados finales',()=>{expect(canTransition('PENDING','READY')).toBe(false);expect(canTransition('DELIVERED','PREPARING')).toBe(false)})});
import{canChangeCourier,assignmentStatusLabels}from'./order-state';
describe('cambio de repartidor',()=>{
  it('permite cancelar o reasignar mientras el pedido no fue recogido',()=>{expect(canChangeCourier('READY','PENDING')).toBe(true);expect(canChangeCourier('READY','ACCEPTED')).toBe(true)});
  it('lo impide sin asignación vigente o después del recojo',()=>{expect(canChangeCourier('READY','REJECTED')).toBe(false);expect(canChangeCourier('READY',null)).toBe(false);expect(canChangeCourier('PICKED_UP','ACCEPTED')).toBe(false);expect(canChangeCourier('ON_THE_WAY','ACCEPTED')).toBe(false)});
  it('muestra el rechazo del repartidor en español',()=>{expect(assignmentStatusLabels.REJECTED).toBe('Rechazado por el repartidor')});
});
