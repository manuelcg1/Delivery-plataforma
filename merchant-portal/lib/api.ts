'use client';
export const API_URL='/backend';
let token:string|null=null;
export class ApiError extends Error{constructor(message:string,public status:number,public code?:string){super(message)}}
const REQUEST_TIMEOUT_MS=15_000;
async function request(input:RequestInfo|URL,init:RequestInit={}){
 const controller=new AbortController();const abort=()=>controller.abort();const timeout=globalThis.setTimeout(abort,REQUEST_TIMEOUT_MS);
 init.signal?.addEventListener('abort',abort,{once:true});
 try{return await fetch(input,{...init,signal:controller.signal})}
 catch(error){if(controller.signal.aborted&&!init.signal?.aborted)throw new ApiError('El servidor tardó demasiado en responder. Intenta nuevamente.',0,'REQUEST_TIMEOUT');throw error}
 finally{globalThis.clearTimeout(timeout);init.signal?.removeEventListener('abort',abort)}
}
export function setToken(value:string|null){token=value;if(typeof window!=='undefined'){if(value)sessionStorage.setItem('merchant_token',value);else sessionStorage.removeItem('merchant_token')}}
export function restoreToken(){if(typeof window!=='undefined')token=sessionStorage.getItem('merchant_token');return token}
export function getToken(){return token}
export async function api<T>(path:string,init:RequestInit={},retry=true):Promise<T>{
 const headers=new Headers(init.headers);if(token)headers.set('Authorization',`Bearer ${token}`);if(init.body)headers.set('Content-Type','application/json');
 let response:Response;
 try{response=await request(`${API_URL}${path}`,{...init,headers,credentials:'include'})}catch(error){if(error instanceof ApiError)throw error;throw new ApiError('No se pudo contactar al servidor. Verifica que el backend esté activo.',0,'NETWORK_ERROR')}
 if(response.status===401&&retry){const refreshed=await request(`${API_URL}/api/v1/auth/refresh`,{method:'POST',credentials:'include'});if(refreshed.ok){const data=await refreshed.json();setToken(data.accessToken);return api<T>(path,init,false)}}
 const text=await response.text();let payload:Record<string,unknown>={};try{payload=text?JSON.parse(text):{}}catch{payload={}}
 if(!response.ok)throw new ApiError(String(payload.message??'No se pudo completar la operación'),response.status,String(payload.code??''));
 return (text?payload:null) as T;
}
