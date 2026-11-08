package com.delivery.platform.payments.application;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import java.util.*;
import javax.imageio.ImageIO;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.*;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MerchantYapeService {
    public record Settings(boolean enabled, String phone, String holderName, String qrUrl, String version) {}
    public record Receiver(String phone, String holderName, String version) {}
    private record Stored(boolean enabled, String phone, String holder, String key, String version) {}
    private final JdbcClient db;
    private final CatalogSupport support;
    private final MinioCatalogStorage storage;
    @org.springframework.beans.factory.annotation.Value("${PAYMENT_PROVIDER:SIMULATED}")
    private String configuredProvider="SIMULATED";
    public MerchantYapeService(JdbcClient db, CatalogSupport support, MinioCatalogStorage storage) {
        this.db=db; this.support=support; this.storage=storage;
    }
    public Settings admin(IdentityPrincipal p, UUID merchant) { support.merchant(p,merchant); return response(stored(p,merchant)); }
    public Settings checkout(IdentityPrincipal p, UUID merchant) {
        merchant(p,merchant);
        if(!"SIMULATED".equalsIgnoreCase(configuredProvider)&&!"MANUAL_YAPE".equalsIgnoreCase(configuredProvider)) return new Settings(false,null,null,null,null);
        return response(stored(p,merchant));
    }
    private void merchant(IdentityPrincipal p, UUID merchant) {
        if(db.sql("select count(*) from merchants where id=:m and tenant_id=:t and status='ACTIVE'")
            .param("m",merchant).param("t",p.tenantId()).query(Integer.class).single()!=1)
            throw new ApiException(HttpStatus.NOT_FOUND,"MERCHANT_NOT_FOUND","Comercio no encontrado");
    }
    private Stored stored(IdentityPrincipal p, UUID merchant) {
        return db.sql("select * from merchant_yape_settings where tenant_id=:t and merchant_id=:m")
            .param("t",p.tenantId()).param("m",merchant)
            .query((r,n)->new Stored(r.getBoolean("enabled"),r.getString("phone"),r.getString("holder_name"),r.getString("qr_object_key"),r.getString("version")))
            .optional().orElse(new Stored(false,null,null,null,null));
    }
    private Settings response(Stored s) { return new Settings(s.enabled,s.phone,s.holder,s.key==null?null:storage.signedUrl(s.key),s.version); }
    public Receiver requireCurrent(IdentityPrincipal p, UUID merchant, String version) {
        merchant(p,merchant);
        if(!"SIMULATED".equalsIgnoreCase(configuredProvider)&&!"MANUAL_YAPE".equalsIgnoreCase(configuredProvider)) throw new ApiException(HttpStatus.CONFLICT,"YAPE_UNAVAILABLE","Yape no está disponible");
        Stored s=stored(p,merchant);
        if(!s.enabled||s.key==null) throw new ApiException(HttpStatus.CONFLICT,"YAPE_UNAVAILABLE","Yape no está disponible para este comercio");
        if(version==null||!version.equals(s.version)) throw new ApiException(HttpStatus.CONFLICT,"YAPE_SETTINGS_CHANGED","La configuración Yape cambió; vuelve a confirmar el pago");
        return new Receiver(s.phone,s.holder,s.version);
    }
    @Transactional
    public Settings save(IdentityPrincipal p, UUID merchant, boolean enabled, String phone, String holder, MultipartFile qr) {
        support.merchant(p,merchant);
        // Lock the merchant even when this is the first configuration, preventing lost QR replacements.
        db.sql("select id from merchants where id=:m and tenant_id=:t for update").param("m",merchant).param("t",p.tenantId()).query(UUID.class).optional()
            .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"MERCHANT_NOT_FOUND","Comercio no encontrado"));
        Stored old=stored(p,merchant);
        phone=phone==null||phone.isBlank()?null:phone.trim(); holder=holder==null||holder.isBlank()?null:holder.trim();
        if(phone!=null&&!phone.isEmpty()&&!phone.matches("9[0-9]{8}")) invalid("El número Yape debe tener 9 dígitos y comenzar con 9");
        if(holder!=null&&(holder.length()>160||holder.codePoints().anyMatch(Character::isISOControl))) invalid("El titular Yape no es válido");
        if(enabled&&(phone==null||!phone.matches("9[0-9]{8}")||holder==null||holder.isBlank())) invalid("Ingresa número y titular Yape");
        boolean replace=qr!=null&&!qr.isEmpty();
        if(qr!=null&&qr.isEmpty()) invalid("Selecciona una imagen QR válida");
        if(enabled&&!replace&&old.key==null) invalid("Carga el QR para habilitar Yape");
        if(replace) validateImage(qr);
        String key=replace?storage.put(p.tenantId(),"merchants/"+merchant+"/yape",qr):old.key;
        String version=UUID.randomUUID().toString();
        try {
            String sql=old.version==null
                ? "insert into merchant_yape_settings(tenant_id,merchant_id,enabled,phone,holder_name,qr_object_key,version) values(:t,:m,:e,:p,:h,:q,:v)"
                : "update merchant_yape_settings set enabled=:e,phone=:p,holder_name=:h,qr_object_key=:q,version=:v,updated_at=now() where tenant_id=:t and merchant_id=:m";
            db.sql(sql)
                .param("t",p.tenantId()).param("m",merchant).param("e",enabled).param("p",phone).param("h",holder).param("q",key).param("v",version).update();
            support.audit(p,"MERCHANT_YAPE_UPDATED","MERCHANT",merchant);
            if(replace) cleanup(old.key,key);
            return response(new Stored(enabled,phone,holder,key,version));
        } catch(RuntimeException e) { if(replace) safeDelete(key); throw e; }
    }
    private void validateImage(MultipartFile file) {
        if(file.getSize()>5*1024*1024||!Set.of("image/png","image/jpeg").contains(Objects.toString(file.getContentType(),""))) invalid("El QR debe ser PNG o JPEG y pesar como máximo 5 MB");
        try(var in=file.getInputStream(); var input=ImageIO.createImageInputStream(in)) {
            var readers=ImageIO.getImageReaders(input);
            if(!readers.hasNext()) { invalid("El archivo QR no es una imagen válida"); return; }
            var reader=readers.next();
            try {
                reader.setInput(input,true,true);
                String format=reader.getFormatName();
                if(!(format.equalsIgnoreCase("png")||format.equalsIgnoreCase("jpeg"))||reader.getWidth(0)>4096||reader.getHeight(0)>4096||reader.read(0)==null) invalid("El archivo QR no es una imagen válida o supera 4096 píxeles");
                if((format.equalsIgnoreCase("png")&&!"image/png".equals(file.getContentType()))||(format.equalsIgnoreCase("jpeg")&&!"image/jpeg".equals(file.getContentType()))) invalid("El formato real del QR no coincide con el archivo");
            } finally { reader.dispose(); }
        } catch(ApiException e) {throw e;} catch(Exception e) {invalid("El archivo QR no es una imagen válida");}
    }
    private static void invalid(String message) { throw new ApiException(HttpStatus.BAD_REQUEST,"YAPE_INVALID_SETTINGS",message); }
    private void cleanup(String previous,String current) {
        if(!TransactionSynchronizationManager.isSynchronizationActive()) {if(previous!=null)safeDelete(previous);return;}
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCommit(){if(previous!=null&&!previous.equals(current))safeDelete(previous);}
            @Override public void afterCompletion(int status){if(status!=STATUS_COMMITTED)safeDelete(current);}
        });
    }
    private void safeDelete(String key) { try {storage.delete(key);}catch(RuntimeException e){org.slf4j.LoggerFactory.getLogger(getClass()).warn("No se pudo limpiar QR Yape",e);} }
}
