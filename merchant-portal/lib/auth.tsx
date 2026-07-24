'use client';
import {createContext,useContext,useEffect,useState} from 'react';import {useRouter} from 'next/navigation';import {api,restoreToken,setToken} from './api';
type Me={id:string;firstName:string;lastName:string;email:string;permissions:string[]};
type Auth={me:Me|null;ready:boolean;login:(v:{tenantCode:string;email:string;password:string})=>Promise<void>;logout:()=>Promise<void>};
const Context=createContext<Auth|null>(null);
export function AuthProvider({children}:{children:React.ReactNode}){const[me,setMe]=useState<Me|null>(null);const[ready,setReady]=useState(false);const router=useRouter();
 useEffect(()=>{restoreToken();api<Me>('/api/v1/auth/me').then(setMe).catch(()=>setToken(null)).finally(()=>setReady(true))},[]);
 async function login(values:{tenantCode:string;email:string;password:string}){const session=await api<{accessToken:string}>('/api/v1/auth/login',{method:'POST',body:JSON.stringify(values)},false);setToken(session.accessToken);const user=await api<Me>('/api/v1/auth/me');if(!user.permissions.includes('MERCHANT_PORTAL_ACCESS')){setToken(null);throw new Error('Tu usuario no tiene acceso al portal de comercios')}setMe(user);router.replace('/orders')}
 async function logout(){try{await api('/api/v1/auth/logout',{method:'POST'})}finally{setToken(null);setMe(null);router.replace('/login')}}
 return <Context.Provider value={{me,ready,login,logout}}>{children}</Context.Provider>}
export function useAuth(){const value=useContext(Context);if(!value)throw new Error('AuthProvider requerido');return value}
