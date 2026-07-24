'use client';
export const API_URL='/backend';
let token:string|null=null;
export class ApiError extends Error{constructor(message:string,public status:number,public code?:string){super(message)}}
export function setToken(value:string|null){token=value;if(typeof window!=='undefined'){if(value)sessionStorage.setItem('merchant_token',value);else sessionStorage.removeItem('merchant_token')}}
export function restoreToken(){if(typeof window!=='undefined')token=sessionStorage.getItem('merchant_token');return token}
export function getToken(){return token}
export async function api<T>(path:string,init:RequestInit={},retry=true):Promise<T>{
 const headers=new Headers(init.headers);if(token)headers.set('Authorization',`Bearer ${token}`);if(init.body)headers.set('Content-Type','application/json');
 let response:Response;
 try{response=await fetch(`${API_URL}${path}`,{...init,headers,credentials:'include'})}catch{throw new ApiError('No se pudo contactar al servidor. Verifica que el backend esté activo.',0,'NETWORK_ERROR')}
 if(response.status===401&&retry){const refreshed=await fetch(`${API_URL}/api/v1/auth/refresh`,{method:'POST',credentials:'include'});if(refreshed.ok){const data=await refreshed.json();setToken(data.accessToken);return api<T>(path,init,false)}}
 const text=await response.text();let payload:Record<string,unknown>={};try{payload=text?JSON.parse(text):{}}catch{payload={}}
 if(!response.ok)throw new ApiError(String(payload.message??'No se pudo completar la operación'),response.status,String(payload.code??''));
 return (text?payload:null) as T;
}
