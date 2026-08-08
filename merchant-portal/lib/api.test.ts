import {afterEach,describe,expect,it,vi} from 'vitest';
import {api,ApiError,setToken} from './api';

describe('api request timeout',()=>{
 afterEach(()=>{vi.useRealTimers();vi.unstubAllGlobals();setToken(null)});

 it('termina de forma controlada cuando el backend no responde',async()=>{
  vi.useFakeTimers();
  vi.stubGlobal('fetch',vi.fn((_input:RequestInfo|URL,init?:RequestInit)=>new Promise<Response>((_resolve,reject)=>{
   init?.signal?.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError')),{once:true});
  })));
  const pending=api('/api/v1/auth/me',{},false);
  const assertion=expect(pending).rejects.toMatchObject<Partial<ApiError>>({code:'REQUEST_TIMEOUT',status:0});
  await vi.advanceTimersByTimeAsync(15_000);
  await assertion;
 });
});
