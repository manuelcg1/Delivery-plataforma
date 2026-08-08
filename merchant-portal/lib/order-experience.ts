import type {OrderRow} from './types';

export type OrderTone='new'|'progress'|'ready'|'transit'|'delivered'|'issue'|'neutral';

export function orderTone(status:string):OrderTone {
  if(status==='PENDING') return 'new';
  if(status==='CONFIRMED'||status==='PREPARING') return 'progress';
  if(status==='READY'||status==='SEARCHING_COURIER') return 'ready';
  if(status==='ASSIGNED'||status==='COURIER_ASSIGNED'||status==='PICKED_UP'||status==='ON_THE_WAY') return 'transit';
  if(status==='DELIVERED') return 'delivered';
  if(status==='REJECTED'||status==='CANCELLED') return 'issue';
  return 'neutral';
}

export function unseenNewOrderIds(rows:OrderRow[],seen:ReadonlySet<string>):string[] {
  return rows.filter(order=>order.status==='PENDING'&&!seen.has(order.id)).map(order=>order.id);
}

export function rememberOrderIds(storage:Storage,key:string,ids:Iterable<string>) {
  const current=new Set<string>();
  try { for(const id of JSON.parse(storage.getItem(key)??'[]') as string[]) current.add(id); } catch {}
  for(const id of ids) current.add(id);
  storage.setItem(key,JSON.stringify([...current].slice(-500)));
}

let audioContext:AudioContext|null=null;

function contextForSound() {
  const AudioContextClass=window.AudioContext;
  if(!AudioContextClass) return null;
  audioContext??=new AudioContextClass();
  return audioContext;
}

export function prepareNewOrderSound() {
  const context=contextForSound();
  if(context?.state==='suspended')void context.resume();
}

export function playNewOrderSound() {
  const context=contextForSound();
  if(!context) return;
  if(context.state==='suspended')void context.resume();
  const gain=context.createGain();
  gain.gain.setValueAtTime(.0001,context.currentTime);
  gain.gain.exponentialRampToValueAtTime(.3,context.currentTime+.02);
  gain.gain.exponentialRampToValueAtTime(.0001,context.currentTime+.65);
  gain.connect(context.destination);
  [0,0.24].forEach((delay,index)=>{
    const oscillator=context.createOscillator();
    oscillator.type='sine';
    oscillator.frequency.value=index===0?880:1175;
    oscillator.connect(gain);
    oscillator.start(context.currentTime+delay);
    oscillator.stop(context.currentTime+delay+.2);
  });
}
