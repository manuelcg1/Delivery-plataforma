import{describe,expect,it}from'vitest';
import{canViewDeliveryLocation,locationPoints,relativeLocationTime}from'./delivery-location';
import type{AssignmentInfo}from'./types';

const info=(values:Partial<AssignmentInfo>={})=>({
  deliveryId:'delivery',assignmentId:null,assignmentStatus:'ACCEPTED',message:null,
  courierId:'courier',courierName:'Ana',vehicleType:'MOTORCYCLE',courierStatus:'ONLINE',
  assignedAt:null,expiresAt:null,latitude:-12.1,longitude:-77.1,lastLocationAt:'2026-08-08T12:00:00Z',
  customerLatitude:-12.2,customerLongitude:-77.2,...values,
}) as AssignmentInfo;

describe('ubicación rápida de la entrega',()=>{
  it('solo aparece durante estados activos',()=>{
    expect(canViewDeliveryLocation({status:'READY',deliveryStatus:'ASSIGNED'})).toBe(true);
    expect(canViewDeliveryLocation({status:'ON_THE_WAY',deliveryStatus:null})).toBe(true);
    expect(canViewDeliveryLocation({status:'DELIVERED',deliveryStatus:'DELIVERED'})).toBe(false);
    expect(canViewDeliveryLocation({status:'CANCELLED',deliveryStatus:null})).toBe(false);
  });
  it('descarta coordenadas ausentes o inválidas sin perder el otro marcador',()=>{
    expect(locationPoints(info({latitude:91}))).toEqual({courier:null,customer:{latitude:-12.2,longitude:-77.2}});
    expect(locationPoints(info({customerLatitude:null,customerLongitude:null})).courier).toEqual({latitude:-12.1,longitude:-77.1});
  });
  it('actualiza el repartidor sin alterar la ubicación del cliente',()=>{
    const initial=locationPoints(info());
    const updated=locationPoints(info({latitude:-12.15,longitude:-77.15}));
    expect(updated.courier).toEqual({latitude:-12.15,longitude:-77.15});
    expect(updated.customer).toEqual(initial.customer);
  });
  it('muestra la antigüedad de la última ubicación',()=>{
    expect(relativeLocationTime('2026-08-08T12:00:00Z',Date.parse('2026-08-08T12:00:12Z'))).toBe('hace 12 segundos');
  });
});
