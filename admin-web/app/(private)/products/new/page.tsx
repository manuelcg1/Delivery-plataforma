'use client';

import Image from 'next/image';
import Link from 'next/link';
import {ChangeEvent,FormEvent,useEffect,useRef,useState} from 'react';
import {useRouter} from 'next/navigation';
import {api,ApiClientError} from '@/lib/api';
import {useAuth} from '@/lib/auth';
import {catalogImagesError} from '@/lib/merchant-image-validation';

type PendingImage={file:File;preview:string};
type PendingOption={name:string;priceAdjustment:number};

export default function NewProduct(){
  const[merchantId,setMerchant]=useState('');
  useEffect(()=>setMerchant(new URLSearchParams(location.search).get('merchantId')??''),[]);
  const[d,setD]=useState({name:'',slug:'',sku:'',description:'',productType:'SIMPLE',basePrice:0,currency:'PEN',trackInventory:false,stockQuantity:0,available:true,featured:false,categoryId:null});
  const[images,setImages]=useState<PendingImage[]>([]);
  const previews=useRef<string[]>([]);
  const[createdId,setCreatedId]=useState<string|null>(null);
  const[withOptions,setWithOptions]=useState(false);
  const[optionGroup,setOptionGroup]=useState({name:'Opcionales',selectionType:'MULTIPLE',required:false});
  const[optionItems,setOptionItems]=useState<PendingOption[]>([{name:'',priceAdjustment:0}]);
  const createdOptionGroup=useRef<string|null>(null);
  const createdOptionItems=useRef(0);
  const[busy,setBusy]=useState(false);
  const[error,setError]=useState('');
  const router=useRouter();
  const{can}=useAuth();
  const canUpload=can('CATALOG_MEDIA_UPLOAD');
  const canManageOptions=can('CATALOG_OPTIONS_MANAGE');

  useEffect(()=>()=>previews.current.forEach(URL.revokeObjectURL),[]);

  function chooseImages(event:ChangeEvent<HTMLInputElement>){
    const selected=Array.from(event.target.files??[]);
    setError('');
    const invalid=catalogImagesError(selected);
    if(invalid){setError(invalid);event.target.value='';return}
    previews.current.forEach(URL.revokeObjectURL);
    const pending=selected.map(file=>({file,preview:URL.createObjectURL(file)}));
    previews.current=pending.map(image=>image.preview);
    setImages(pending);
  }

  async function upload(productId:string,image:PendingImage){
    const body=new FormData();
    body.append('file',image.file);
    body.append('altText',d.name);
    await api(`/api/v1/products/${productId}/images`,{method:'POST',body});
  }

  async function submit(event:FormEvent){
    event.preventDefault();setBusy(true);setError('');
    let productId=createdId;
    try{
      productId=productId??(await api<{id:string}>(`/api/v1/merchants/${merchantId}/products`,{method:'POST',body:JSON.stringify(d)})).id;
      setCreatedId(productId);
      for(const image of [...images]){
        await upload(productId,image);
        URL.revokeObjectURL(image.preview);
        previews.current=previews.current.filter(preview=>preview!==image.preview);
        setImages(current=>current.filter(candidate=>candidate!==image));
      }
      if(withOptions&&canManageOptions){
        const validItems=optionItems.filter(item=>item.name.trim());
        if(validItems.length===0)throw new Error('Agrega al menos un opcional.');
        const groupId=createdOptionGroup.current??(await api<{id:string}>(`/api/v1/merchants/${merchantId}/option-groups`,{method:'POST',body:JSON.stringify({name:optionGroup.name,description:'Creado junto con el producto',selectionType:optionGroup.selectionType,required:optionGroup.required,minimumSelections:optionGroup.required?1:0,maximumSelections:optionGroup.selectionType==='SINGLE'?1:null,active:true})})).id;
        createdOptionGroup.current=groupId;
        for(let index=createdOptionItems.current;index<validItems.length;index++){
          await api(`/api/v1/option-groups/${groupId}/items`,{method:'POST',body:JSON.stringify({...validItems[index],available:true,sortOrder:index})});
          createdOptionItems.current=index+1;
        }
        await api(`/api/v1/products/${productId}/option-groups`,{method:'PUT',body:JSON.stringify({optionGroupIds:[groupId]})});
      }
      router.push(`/products/${productId}`);
    }catch(cause){
      const message=cause instanceof ApiClientError?cause.message:'No se pudo crear el producto';
      setError(productId?`${message} El producto ya fue creado; puedes reintentar las imágenes pendientes.`:message);
    }finally{setBusy(false)}
  }

  return <>
    <p className="eyebrow">CATÁLOGO</p><h1>Nuevo producto</h1>
    {error&&<div className="error" role="alert">{error}</div>}
    <form className="panel catalog-form" onSubmit={submit}>
      <label>Nombre<input value={d.name} disabled={!!createdId} onChange={event=>setD({...d,name:event.target.value})} required/></label>
      <label>Slug<input value={d.slug} disabled={!!createdId} onChange={event=>setD({...d,slug:event.target.value})} placeholder="Se genera desde el nombre"/></label>
      <label>SKU<input value={d.sku} disabled={!!createdId} onChange={event=>setD({...d,sku:event.target.value})}/></label>
      <label>Tipo<select value={d.productType} disabled={!!createdId} onChange={event=>setD({...d,productType:event.target.value})}>{['SIMPLE','VARIABLE','COMBO','SERVICE'].map(value=><option key={value}>{value}</option>)}</select></label>
      <label>Precio<input type="number" min="0" step="0.01" value={d.basePrice} disabled={!!createdId} onChange={event=>setD({...d,basePrice:Number(event.target.value)})}/></label>
      <label>Moneda<input value={d.currency} maxLength={3} disabled={!!createdId} onChange={event=>setD({...d,currency:event.target.value.toUpperCase()})}/></label>
      <label className="full">Descripción<textarea value={d.description} disabled={!!createdId} onChange={event=>setD({...d,description:event.target.value})}/></label>
      <label className="option-choice full"><input type="checkbox" checked={d.trackInventory} disabled={!!createdId} onChange={event=>setD({...d,trackInventory:event.target.checked})}/><span><strong>Controlar inventario</strong><small>Incluye este producto en el módulo Inventario y valida sus existencias.</small></span></label>
      {d.trackInventory&&<label>Stock inicial<input type="number" min="0" step="0.001" value={d.stockQuantity} disabled={!!createdId} onChange={event=>setD({...d,stockQuantity:Number(event.target.value)})} required/></label>}
      {canUpload&&<fieldset className="product-create-images full">
        <legend>Imágenes del producto (opcional)</legend>
        <p>Selecciona hasta 8 archivos JPEG, PNG o WebP de máximo 5 MB. La primera será la imagen principal.</p>
        <input type="file" multiple accept="image/jpeg,image/png,image/webp" onChange={chooseImages}/>
        {images.length>0&&<div className="product-create-preview">{images.map((image,index)=><figure key={`${image.file.name}-${image.file.lastModified}`}><Image unoptimized width={180} height={135} src={image.preview} alt={`Vista previa ${index+1}`}/><figcaption>{index===0?'Principal':`Imagen ${index+1}`}</figcaption></figure>)}</div>}
      </fieldset>}
      {canManageOptions&&<fieldset className="product-create-images full">
        <legend>Opcionales del producto</legend>
        <label className="option-choice"><input type="checkbox" checked={withOptions} onChange={event=>setWithOptions(event.target.checked)}/><span><strong>Crear opcionales ahora</strong><small>Podrás administrarlos también desde el detalle del producto.</small></span></label>
        {withOptions&&<div className="stack">
          <label>Nombre del grupo<input value={optionGroup.name} onChange={event=>setOptionGroup({...optionGroup,name:event.target.value})} required/></label>
          <label>Tipo<select value={optionGroup.selectionType} onChange={event=>setOptionGroup({...optionGroup,selectionType:event.target.value})}><option value="SINGLE">Selección única</option><option value="MULTIPLE">Selección múltiple</option></select></label>
          <label className="option-choice"><input type="checkbox" checked={optionGroup.required} onChange={event=>setOptionGroup({...optionGroup,required:event.target.checked})}/><span><strong>Selección obligatoria</strong><small>Debe elegirse antes de agregar al carrito.</small></span></label>
          {optionItems.map((item,index)=><div className="inline-form" key={index}><label>Nombre<input value={item.name} onChange={event=>setOptionItems(current=>current.map((value,i)=>i===index?{...value,name:event.target.value}:value))} required/></label><label>Precio adicional<input type="number" min="0" step="0.01" value={item.priceAdjustment} onChange={event=>setOptionItems(current=>current.map((value,i)=>i===index?{...value,priceAdjustment:Number(event.target.value)}:value))}/></label>{optionItems.length>1&&<button type="button" className="danger" onClick={()=>setOptionItems(current=>current.filter((_,i)=>i!==index))}>Quitar</button>}</div>)}
          <button type="button" className="secondary" onClick={()=>setOptionItems(current=>[...current,{name:'',priceAdjustment:0}])}>Agregar opcional</button>
        </div>}
      </fieldset>}
      <div className="form-actions"><Link className="button secondary" href={createdId?`/products/${createdId}`:merchantId?`/merchants/${merchantId}/products`:'/merchants'}>Cancelar</Link><button disabled={busy||!merchantId}>{busy?'Guardando…':createdId?'Reintentar imágenes':'Crear producto'}</button></div>
    </form>
  </>;
}
