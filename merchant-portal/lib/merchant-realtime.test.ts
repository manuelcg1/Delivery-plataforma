import{afterEach,describe,expect,it}from'vitest';
import{realtimeUrl}from'./merchant-realtime';

describe('configuración realtime del comercio',()=>{
  const original=process.env.NEXT_PUBLIC_WS_URL;
  afterEach(()=>{process.env.NEXT_PUBLIC_WS_URL=original});
  it('usa directamente el endpoint STOMP existente',()=>{
    process.env.NEXT_PUBLIC_WS_URL='wss://api.cerka.site/api/v1/realtime';
    expect(realtimeUrl()).toBe('wss://api.cerka.site/api/v1/realtime');
  });
  it('normaliza la antigua configuración /ws',()=>{
    process.env.NEXT_PUBLIC_WS_URL='wss://api.cerka.site/ws';
    expect(realtimeUrl()).toBe('wss://api.cerka.site/api/v1/realtime');
  });
});
