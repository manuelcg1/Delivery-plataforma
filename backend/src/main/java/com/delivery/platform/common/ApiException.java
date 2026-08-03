package com.delivery.platform.common;
import org.springframework.http.HttpStatus;
import java.util.Map;
public class ApiException extends RuntimeException {
  public final HttpStatus status; public final String code; public final Map<String,String> details;
  public ApiException(HttpStatus status,String code,String message){this(status,code,message,Map.of());}
  public ApiException(HttpStatus status,String code,String message,Map<String,String> details){super(message);this.status=status;this.code=code;this.details=Map.copyOf(details);}
}
