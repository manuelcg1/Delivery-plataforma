package com.delivery.platform.customer.address;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.customer.address.GoogleAddressClient.*;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.time.Duration;
import java.util.*;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

@Service
public class AddressLookupService {
    private final GoogleAddressClient google;private final StringRedisTemplate redis;private final ObjectMapper json;private final MeterRegistry metrics;
    public AddressLookupService(GoogleAddressClient google,StringRedisTemplate redis,ObjectMapper json,MeterRegistry metrics){this.google=google;this.redis=redis;this.json=json;this.metrics=metrics;}
    public List<Suggestion> autocomplete(IdentityPrincipal p,HttpServletRequest request,String query,String token,BigDecimal lat,BigDecimal lng){String q=query==null?"":query.trim().replaceAll("\\s+"," ");if(q.length()<3||q.length()>120)throw new ApiException(HttpStatus.BAD_REQUEST,"ADDRESS_QUERY_INVALID","La búsqueda debe tener entre 3 y 120 caracteres");token(token);coordinates(lat,lng,true);limit(p,request,"autocomplete",30);return google.autocomplete(q,token,lat,lng);}
    public AddressResult details(IdentityPrincipal p,HttpServletRequest request,String placeId,String token){if(placeId==null||!placeId.matches("[A-Za-z0-9_-]{3,255}"))throw new ApiException(HttpStatus.BAD_REQUEST,"ADDRESS_QUERY_INVALID","placeId inválido");token(token);limit(p,request,"details",10);String key="address:place:"+placeId;try{String cached=redis.opsForValue().get(key);if(cached!=null)return json.readValue(cached,AddressResult.class);}catch(Exception ignored){}AddressResult value=google.details(placeId,token);cache(key,value,Duration.ofMinutes(30));return value;}
    public AddressResult reverse(IdentityPrincipal p,HttpServletRequest request,BigDecimal lat,BigDecimal lng){coordinates(lat,lng,false);limit(p,request,"reverse",15);String key="address:reverse:"+lat.setScale(4,java.math.RoundingMode.HALF_UP)+":"+lng.setScale(4,java.math.RoundingMode.HALF_UP);try{String cached=redis.opsForValue().get(key);if(cached!=null)return json.readValue(cached,AddressResult.class);}catch(Exception ignored){}AddressResult value=google.reverse(lat,lng);cache(key,value,Duration.ofMinutes(10));return value;}
    private void limit(IdentityPrincipal p,HttpServletRequest request,String operation,int maximum){String ip=Optional.ofNullable(request.getHeader("X-Forwarded-For")).map(x->x.split(",")[0].trim()).orElse(request.getRemoteAddr());for(String scope:List.of("tenant:"+p.tenantId(),"user:"+p.userId(),"ip:"+Integer.toHexString(ip.hashCode()))){String key="rate:address:"+operation+":"+scope;try{Long count=redis.opsForValue().increment(key);if(count!=null&&count==1)redis.expire(key,Duration.ofMinutes(1));if(count!=null&&count>maximum){metrics.counter("address_search_rate_limited","operation",operation).increment();throw new ApiException(HttpStatus.TOO_MANY_REQUESTS,"ADDRESS_SEARCH_RATE_LIMITED","Demasiadas solicitudes de direcciones; intenta nuevamente en un minuto");}}catch(ApiException e){throw e;}catch(Exception ignored){}}}
    private void cache(String key,Object value,Duration ttl){try{redis.opsForValue().set(key,json.writeValueAsString(value),ttl);}catch(Exception ignored){}}
    private void token(String value){try{UUID.fromString(value);}catch(Exception e){throw new ApiException(HttpStatus.BAD_REQUEST,"ADDRESS_QUERY_INVALID","sessionToken debe ser un UUID válido");}}
    private void coordinates(BigDecimal lat,BigDecimal lng,boolean optional){if(optional&&lat==null&&lng==null)return;if(lat==null||lng==null||lat.abs().compareTo(BigDecimal.valueOf(90))>0||lng.abs().compareTo(BigDecimal.valueOf(180))>0)throw new ApiException(HttpStatus.BAD_REQUEST,"ADDRESS_QUERY_INVALID","Coordenadas inválidas");}
}
