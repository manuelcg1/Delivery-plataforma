'use client';

import {useEffect,useRef} from 'react';
import {CircleMarker,MapContainer,TileLayer,Tooltip,useMap} from 'react-leaflet';
import type{LatLngBoundsExpression,LatLngExpression}from'leaflet';
import type{MapPoint}from'@/lib/delivery-location';

function InitialViewport({points}:{points:MapPoint[]}){
  const map=useMap();
  const fitted=useRef(false);
  useEffect(()=>{
    map.invalidateSize();
    if(fitted.current||points.length===0)return;
    if(points.length===1){
      map.setView([points[0].latitude,points[0].longitude],15);
    }else{
      const bounds=points.map(point=>[point.latitude,point.longitude]) as LatLngBoundsExpression;
      map.fitBounds(bounds,{padding:[36,36],maxZoom:16});
    }
    fitted.current=true;
  },[map,points]);
  return null;
}

export default function DeliveryMap({courier,customer}:{courier:MapPoint|null;customer:MapPoint|null}){
  const points=[courier,customer].filter((point):point is MapPoint=>point!==null);
  const initial=(points[0]
    ?[points[0].latitude,points[0].longitude]
    :[-12.0464,-77.0428]) as LatLngExpression;
  return <div className="delivery-map" aria-label="Mapa de ubicación de la entrega">
    <MapContainer center={initial} zoom={14} scrollWheelZoom attributionControl>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <InitialViewport points={points}/>
      {customer&&<CircleMarker
        center={[customer.latitude,customer.longitude]}
        radius={11}
        pathOptions={{color:'#fff',weight:3,fillColor:'#06163a',fillOpacity:1}}
      ><Tooltip permanent direction="top" offset={[0,-10]}>Cliente</Tooltip></CircleMarker>}
      {courier&&<CircleMarker
        center={[courier.latitude,courier.longitude]}
        radius={11}
        pathOptions={{color:'#fff',weight:3,fillColor:'#ff7c00',fillOpacity:1}}
      ><Tooltip permanent direction="top" offset={[0,-10]}>Repartidor</Tooltip></CircleMarker>}
    </MapContainer>
  </div>;
}
