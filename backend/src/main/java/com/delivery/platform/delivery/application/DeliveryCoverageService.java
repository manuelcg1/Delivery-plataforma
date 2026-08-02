package com.delivery.platform.delivery.application;

import com.delivery.platform.common.ApiException;
import java.math.*;
import java.util.*;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class DeliveryCoverageService {
    private final JdbcClient db;
    public DeliveryCoverageService(JdbcClient db){this.db=db;}
    public record Quote(boolean eligible,UUID zoneId,BigDecimal distanceKm,int estimatedMinutes,BigDecimal deliveryFee,String currency,BigDecimal minimumOrderAmount,String reasonCode,String message){}
    private record Destination(String district,BigDecimal latitude,BigDecimal longitude){}

    public Quote quote(UUID tenant,UUID customer,UUID merchant,UUID branch,UUID address,BigDecimal subtotal){
        Destination destination=db.sql("select district,latitude,longitude from delivery_addresses where id=:a and tenant_id=:t and customer_id=:u and active")
                .param("a",address).param("t",tenant).param("u",customer)
                .query((r,n)->new Destination(r.getString("district"),r.getBigDecimal("latitude"),r.getBigDecimal("longitude"))).optional()
                .orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"ADDRESS_NOT_FOUND","Dirección no encontrada"));
        if(destination.latitude()==null||destination.longitude()==null)throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY,"ADDRESS_NOT_RESOLVED","La dirección no tiene coordenadas válidas");
        var zone=db.sql("select z.id,z.minimum_order_amount,z.base_delivery_fee,z.currency,z.estimated_minutes,coalesce(r.base_fee,z.base_delivery_fee) base_fee,coalesce(r.fee_per_km,0) fee_km,r.minimum_fee,r.maximum_fee,r.free_delivery_threshold from delivery_zones z left join lateral(select * from delivery_rates where delivery_zone_id=z.id and active order by created_at desc limit 1)r on true where z.tenant_id=:t and z.merchant_id=:m and (z.branch_id is null or z.branch_id=:b) and z.active and lower(z.areas) like lower('%'||:d||'%') order by (z.branch_id is not null) desc limit 1")
                .param("t",tenant).param("m",merchant).param("b",branch).param("d",destination.district()==null?"":destination.district())
                .query((x,n)->new Object[]{x.getObject("id",UUID.class),x.getBigDecimal("minimum_order_amount"),x.getBigDecimal("base_fee"),x.getBigDecimal("fee_km"),x.getBigDecimal("minimum_fee"),x.getBigDecimal("maximum_fee"),x.getBigDecimal("free_delivery_threshold"),x.getString("currency"),x.getInt("estimated_minutes")}).optional();
        if(zone.isEmpty())return new Quote(false,null,null,0,null,null,null,"DELIVERY_OUT_OF_COVERAGE","Dirección fuera de cobertura");
        Object[] z=zone.get();BigDecimal min=(BigDecimal)z[1];
        if(subtotal.compareTo(min)<0)return new Quote(false,(UUID)z[0],null,(int)z[8],null,(String)z[7],min,"DELIVERY_MINIMUM_NOT_REACHED","No alcanza el pedido mínimo");
        BigDecimal distance=branchDistance(tenant,branch,destination);BigDecimal fee=((BigDecimal)z[2]).add(distance.multiply((BigDecimal)z[3]));
        if(z[4]!=null)fee=fee.max((BigDecimal)z[4]);if(z[5]!=null)fee=fee.min((BigDecimal)z[5]);if(z[6]!=null&&subtotal.compareTo((BigDecimal)z[6])>=0)fee=BigDecimal.ZERO;
        return new Quote(true,(UUID)z[0],distance,(int)z[8],fee.setScale(2,RoundingMode.HALF_UP),(String)z[7],min,null,"Cobertura disponible");
    }
    private BigDecimal branchDistance(UUID tenant,UUID branch,Destination destination){return db.sql("select latitude,longitude from branches where id=:b and tenant_id=:t").param("b",branch).param("t",tenant).query((r,n)->{BigDecimal lat=r.getBigDecimal("latitude"),lng=r.getBigDecimal("longitude");if(lat==null||lng==null)return BigDecimal.ZERO;double earth=6371,la1=Math.toRadians(lat.doubleValue()),la2=Math.toRadians(destination.latitude().doubleValue()),dlat=la2-la1,dlng=Math.toRadians(destination.longitude().doubleValue()-lng.doubleValue());double a=Math.sin(dlat/2)*Math.sin(dlat/2)+Math.cos(la1)*Math.cos(la2)*Math.sin(dlng/2)*Math.sin(dlng/2);return BigDecimal.valueOf(earth*2*Math.atan2(Math.sqrt(a),Math.sqrt(1-a))).setScale(2,RoundingMode.HALF_UP);}).optional().orElse(BigDecimal.ZERO);}
}
