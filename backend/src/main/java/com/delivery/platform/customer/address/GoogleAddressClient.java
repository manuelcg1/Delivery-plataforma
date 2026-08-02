package com.delivery.platform.customer.address;

import com.delivery.platform.common.ApiException;
import com.fasterxml.jackson.databind.JsonNode;
import io.micrometer.core.instrument.MeterRegistry;
import java.math.BigDecimal;
import java.time.Duration;
import java.util.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.*;

@Component
public class GoogleAddressClient {
    private static final org.slf4j.Logger log=org.slf4j.LoggerFactory.getLogger(GoogleAddressClient.class);
    public record Suggestion(String placeId,String primaryText,String secondaryText,String formattedText){}
    public record AddressResult(String placeId,String formattedAddress,BigDecimal latitude,BigDecimal longitude,String street,String streetNumber,String district,String city,String province,String region,String postalCode,String countryCode){}
    private final RestClient places;
    private final RestClient geocoding;
    private final String apiKey;
    private final String country;
    private final String language;
    private final boolean enabled;
    private final MeterRegistry metrics;

    public GoogleAddressClient(RestClient.Builder builder, MeterRegistry metrics,
            @Value("${google.places.api-key:}") String apiKey,
            @Value("${google.places.country:PE}") String country,
            @Value("${google.places.language:es}") String language,
            @Value("${google.places.enabled:false}") boolean enabled) {
        var factory=new SimpleClientHttpRequestFactory();factory.setConnectTimeout(Duration.ofSeconds(3));factory.setReadTimeout(Duration.ofSeconds(5));
        this.places=builder.clone().baseUrl("https://places.googleapis.com/v1").requestFactory(factory).defaultHeader(HttpHeaders.USER_AGENT,"Cerka-Delivery/1.0").build();
        this.geocoding=builder.clone().baseUrl("https://geocode.googleapis.com/v4").requestFactory(factory).defaultHeader(HttpHeaders.USER_AGENT,"Cerka-Delivery/1.0").build();
        this.metrics=metrics;this.apiKey=apiKey;this.country=country.toUpperCase(Locale.ROOT);this.language=language;this.enabled=enabled;
        if(enabled)log.info("Google address service enabled country={} language={}",this.country,this.language);
    }

    public List<Suggestion> autocomplete(String input,String sessionToken,BigDecimal latitude,BigDecimal longitude){
        required();metrics.counter("google_places_autocomplete_requests").increment();
        Map<String,Object> body=new LinkedHashMap<>();body.put("input",input);body.put("sessionToken",sessionToken);body.put("includedRegionCodes",List.of(country.toLowerCase(Locale.ROOT)));body.put("languageCode",language);
        if(latitude!=null&&longitude!=null)body.put("locationBias",Map.of("circle",Map.of("center",Map.of("latitude",latitude,"longitude",longitude),"radius",50000)));
        JsonNode root=call(()->places.post().uri("/places:autocomplete").header("X-Goog-Api-Key",apiKey).header("X-Goog-FieldMask","suggestions.placePrediction.placeId,suggestions.placePrediction.text,suggestions.placePrediction.structuredFormat").contentType(MediaType.APPLICATION_JSON).body(body).retrieve().body(JsonNode.class));
        List<Suggestion> out=new ArrayList<>();for(JsonNode item:root.path("suggestions")){JsonNode p=item.path("placePrediction");if(p.isMissingNode())continue;String formatted=text(p.path("text"),"text");String primary=text(p.path("structuredFormat").path("mainText"),"text");String secondary=text(p.path("structuredFormat").path("secondaryText"),"text");String id=p.path("placeId").asText();if(!id.isBlank())out.add(new Suggestion(id,primary.isBlank()?formatted:primary,secondary,formatted));if(out.size()==8)break;}return out;
    }

    public AddressResult details(String placeId,String sessionToken){required();metrics.counter("google_places_details_requests").increment();JsonNode root=call(()->places.get().uri(uri->uri.path("/places/{id}").queryParam("sessionToken",sessionToken).queryParam("languageCode",language).build(placeId)).header("X-Goog-Api-Key",apiKey).header("X-Goog-FieldMask","id,formattedAddress,location,addressComponents").retrieve().body(JsonNode.class));return normalize(root,placeId);}

    public AddressResult reverse(BigDecimal latitude,BigDecimal longitude){required();metrics.counter("google_geocoding_requests").increment();JsonNode root=call(()->geocoding.get().uri(uri->uri.path("/geocode/location/{location}").queryParam("languageCode",language).build(latitude+","+longitude)).header("X-Goog-Api-Key",apiKey).header("X-Goog-FieldMask","results.placeId,results.formattedAddress,results.location,results.addressComponents").retrieve().body(JsonNode.class));JsonNode result=root.path("results").path(0);if(result.isMissingNode())throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY,"ADDRESS_NOT_RESOLVED","No se pudo resolver la ubicación");return normalize(result,result.path("placeId").asText(null));}

    private AddressResult normalize(JsonNode root,String id){Map<String,String> parts=new HashMap<>();for(JsonNode c:root.path("addressComponents")){String value=c.path("longText").asText(c.path("long_name").asText());for(JsonNode type:c.path("types"))parts.put(type.asText(),value);}JsonNode location=root.path("location");String code=parts.getOrDefault("country",country);return new AddressResult(id,root.path("formattedAddress").asText(),decimal(location,"latitude","lat"),decimal(location,"longitude","lng"),parts.get("route"),parts.get("street_number"),first(parts,"sublocality_level_1","locality"),parts.get("locality"),parts.get("administrative_area_level_2"),parts.get("administrative_area_level_1"),parts.get("postal_code"),code.length()==2?code.toUpperCase(Locale.ROOT):country);}
    private <T>T call(java.util.function.Supplier<T> action){try{T result=action.get();if(result==null)throw new IllegalStateException("empty response");return result;}catch(ApiException e){throw e;}catch(RestClientException|IllegalStateException e){metrics.counter("google_places_errors").increment();throw new ApiException(HttpStatus.BAD_GATEWAY,"GOOGLE_PLACES_UNAVAILABLE","El servicio de direcciones no está disponible temporalmente");}}
    private void required(){if(!enabled)throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"ADDRESS_SERVICE_DISABLED","El servicio de direcciones está deshabilitado");if(apiKey.isBlank())throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"ADDRESS_SERVICE_DISABLED","El servicio de direcciones no está configurado");}
    private String text(JsonNode node,String field){return node.path(field).asText("");}private String first(Map<String,String> m,String a,String b){return m.getOrDefault(a,m.get(b));}private BigDecimal decimal(JsonNode n,String a,String b){JsonNode v=n.has(a)?n.get(a):n.get(b);if(v==null||!v.isNumber())throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY,"ADDRESS_NOT_RESOLVED","Google no devolvió coordenadas válidas");return v.decimalValue();}
}
