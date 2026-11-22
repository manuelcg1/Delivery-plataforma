'use client';

import {useEffect,useState} from 'react';
import Link from 'next/link';
import {useParams} from 'next/navigation';
import {API_URL} from '@/lib/api';
import {legalDocuments,parseLegalMarkdown,type LegalBlock} from '@/lib/legal-markdown';

type LegalDocument={title:string;version:string;content:string};

export default function LegalPage(){
  const{slug}=useParams<{slug:string}>();
  const[document,setDocument]=useState<LegalDocument|null>(null);
  const[error,setError]=useState('');
  useEffect(()=>{
    let active=true;
    setDocument(null);setError('');
    fetch(`${API_URL}/api/v1/public/legal/${encodeURIComponent(slug)}`)
      .then(async response=>{if(!response.ok)throw new Error('No encontramos este documento.');return response.json() as Promise<LegalDocument>})
      .then(value=>{if(active)setDocument(value)})
      .catch(cause=>{if(active)setError((cause as Error).message||'No pudimos cargar el documento.')});
    return()=>{active=false};
  },[slug]);
  return <main className="legal-page">
    <nav aria-label="Documentos legales">{legalDocuments.map(item=><Link key={item.slug} href={`/legal/${item.slug}`} aria-current={item.slug===slug?'page':undefined}>{item.title}</Link>)}<Link href="/login">Volver al portal</Link></nav>
    {error&&<div className="alert" role="alert">{error}</div>}
    {!document&&!error&&<p>Cargando documento…</p>}
    {document&&<article>{parseLegalMarkdown(document.content).map((block,index)=><Block key={index} block={block}/>)}</article>}
  </main>;
}

function Block({block}:{block:LegalBlock}){
  switch(block.kind){
    case 'h1':return <h1>{block.text}</h1>;
    case 'h2':return <h2>{block.text}</h2>;
    case 'li':return <p className="legal-item">• {block.text}</p>;
    case 'note':return <p className="legal-note">{block.text}</p>;
    default:return <p>{block.text}</p>;
  }
}
