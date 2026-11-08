export default function CustomerContact({phone}:{phone?:string|null}){
  const value=phone?.trim();
  return <div className="customer-contact">
    {value?<>{/^\+519\d{8}$/.test(value)
      ?<a href={`tel:${value}`} aria-label={`Llamar al cliente: ${value}`}>{value}</a>
      :<span>{value}</span>}</>:<span>No registrado</span>}
  </div>;
}
