'use client';

import {Client} from '@stomp/stompjs';
import {useEffect,useRef,useState} from 'react';
import {getToken} from './api';

export type RealtimeStatus='connected'|'reconnecting'|'offline';

export function realtimeUrl():string {
  const configured=process.env.NEXT_PUBLIC_WS_URL;
  if(configured) return configured.replace(/\/ws$/,'/api/v1/realtime');
  if(typeof window==='undefined') return 'ws://localhost:8080/api/v1/realtime';
  const protocol=window.location.protocol==='https:'?'wss:':'ws:';
  return `${protocol}//${window.location.host}/api/v1/realtime`;
}

export function useMerchantRealtime(tenantId:string,merchantId:string,onEvent:()=>void) {
  const[status,setStatus]=useState<RealtimeStatus>('offline');
  const callback=useRef(onEvent);
  callback.current=onEvent;
  useEffect(()=>{
    if(!tenantId||!merchantId||!getToken()){setStatus('offline');return;}
    let active=true;
    const client=new Client({
      brokerURL:realtimeUrl(),
      connectHeaders:{Authorization:`Bearer ${getToken()}`},
      reconnectDelay:3000,
      connectionTimeout:8000,
      heartbeatIncoming:10000,
      heartbeatOutgoing:10000,
      onConnect:()=>{
        if(!active)return;
        setStatus('connected');
        client.subscribe(`/topic/tenants/${tenantId}/merchant/${merchantId}`,
          ()=>callback.current());
      },
      beforeConnect:async()=>{if(active)setStatus('reconnecting');},
      onWebSocketClose:()=>{if(active)setStatus('reconnecting');},
      onWebSocketError:()=>{if(active)setStatus('reconnecting');},
      onStompError:()=>{if(active)setStatus('offline');},
    });
    client.activate();
    return()=>{active=false;void client.deactivate();};
  },[tenantId,merchantId]);
  return status;
}
