import type {AssignmentInfo,OrderRow} from './types';

export type MapPoint={latitude:number;longitude:number};

const visibleStatuses=new Set([
  'ASSIGNED','COURIER_ASSIGNED','ACCEPTED','ARRIVED_AT_MERCHANT',
  'PICKED_UP','IN_TRANSIT','ON_THE_WAY','ARRIVED_AT_CUSTOMER',
]);

export function canViewDeliveryLocation(order:Pick<OrderRow,'status'|'deliveryStatus'>) {
  return visibleStatuses.has(order.deliveryStatus??'')||visibleStatuses.has(order.status);
}

export function validPoint(latitude:number|null,longitude:number|null):MapPoint|null {
  if(latitude==null||longitude==null||!Number.isFinite(latitude)||!Number.isFinite(longitude))return null;
  if(latitude < -90||latitude > 90||longitude < -180||longitude > 180)return null;
  return {latitude,longitude};
}

export function locationPoints(info:AssignmentInfo) {
  return {
    courier:validPoint(info.latitude,info.longitude),
    customer:validPoint(info.customerLatitude,info.customerLongitude),
  };
}

export function mapViewport(points:MapPoint[]) {
  const latitudes=points.map(point=>point.latitude);
  const longitudes=points.map(point=>point.longitude);
  const minLat=Math.min(...latitudes),maxLat=Math.max(...latitudes);
  const minLon=Math.min(...longitudes),maxLon=Math.max(...longitudes);
  const latPadding=Math.max((maxLat-minLat)*.25,.005);
  const lonPadding=Math.max((maxLon-minLon)*.25,.005);
  return {south:minLat-latPadding,west:minLon-lonPadding,north:maxLat+latPadding,east:maxLon+lonPadding};
}

export function osmEmbedUrl(points:MapPoint[]) {
  const bounds=mapViewport(points);
  const bbox=[bounds.west,bounds.south,bounds.east,bounds.north].join(',');
  return `https://www.openstreetmap.org/export/embed.html?bbox=${encodeURIComponent(bbox)}&layer=mapnik`;
}

export function markerPosition(point:MapPoint,points:MapPoint[]) {
  const bounds=mapViewport(points);
  return {
    left:`${((point.longitude-bounds.west)/(bounds.east-bounds.west))*100}%`,
    top:`${((bounds.north-point.latitude)/(bounds.north-bounds.south))*100}%`,
  };
}

export function relativeLocationTime(value:string|null,now=Date.now()) {
  if(!value)return 'Sin actualización registrada';
  const elapsed=Math.max(0,now-new Date(value).getTime());
  if(!Number.isFinite(elapsed))return 'Hora de actualización no disponible';
  const seconds=Math.floor(elapsed/1000);
  if(seconds<60)return `hace ${seconds} segundos`;
  const minutes=Math.floor(seconds/60);
  if(minutes<60)return `hace ${minutes} min`;
  return new Date(value).toLocaleString('es-PE');
}
