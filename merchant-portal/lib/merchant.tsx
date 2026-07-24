'use client';
import {createContext,useCallback,useContext,useEffect,useMemo,useState}from'react';import{api}from'./api';import type{MerchantContext}from'./types';import{useAuth}from'./auth';
type Scope={context:MerchantContext|null;merchantId:string;branchId:string;setMerchantId:(id:string)=>void;setBranchId:(id:string)=>void;reload:()=>Promise<void>};const ScopeContext=createContext<Scope|null>(null);
export function MerchantProvider({children}:{children:React.ReactNode}){const{me}=useAuth();const[context,setContext]=useState<MerchantContext|null>(null);const[merchantId,setMerchant]=useState('');const[branchId,setBranch]=useState('');
 const reload=useCallback(async()=>{const value=await api<MerchantContext>('/api/v1/merchant/context');setContext(value);const merchant=value.merchants.find(x=>x.id===merchantId)??value.merchants[0];setMerchant(merchant?.id??'');if(!merchant?.branches.some(x=>x.id===branchId))setBranch(merchant?.branches[0]?.id??'')},[merchantId,branchId]);
 useEffect(()=>{if(me)reload().catch(()=>setContext({userId:me.id,tenantId:'',merchants:[]}))},[me,reload]);
 const setMerchantId=useCallback((id:string)=>{setMerchant(id);const merchant=context?.merchants.find(x=>x.id===id);setBranch(merchant?.branches[0]?.id??'')},[context]);
 const value=useMemo(()=>({context,merchantId,branchId,setMerchantId,setBranchId:setBranch,reload}),[context,merchantId,branchId,setMerchantId,reload]);return <ScopeContext.Provider value={value}>{children}</ScopeContext.Provider>}
export function useMerchant(){const value=useContext(ScopeContext);if(!value)throw new Error('MerchantProvider requerido');return value}
