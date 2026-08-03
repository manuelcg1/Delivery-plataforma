package com.delivery.platform.common;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.*; import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.MethodArgumentNotValidException; import org.springframework.web.bind.annotation.*;
import java.time.Instant; import java.util.*; import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage.MediaException;
@RestControllerAdvice public class GlobalExceptionHandler {
 private static final org.slf4j.Logger log=org.slf4j.LoggerFactory.getLogger(GlobalExceptionHandler.class);
 @ExceptionHandler(ApiException.class) ResponseEntity<ApiError> api(ApiException e,HttpServletRequest r){return body(e.status,e.code,e.getMessage(),r,e.details);}
 @ExceptionHandler(MediaException.class) ResponseEntity<ApiError> media(MediaException e,HttpServletRequest r){return body(HttpStatus.BAD_REQUEST,e.code,e.getMessage(),r,Map.of());}
 @ExceptionHandler(MethodArgumentNotValidException.class) ResponseEntity<ApiError> validation(MethodArgumentNotValidException e,HttpServletRequest r){Map<String,String>d=new LinkedHashMap<>();e.getBindingResult().getFieldErrors().forEach(x->d.putIfAbsent(x.getField(),x.getDefaultMessage()));return body(HttpStatus.BAD_REQUEST,"VALIDATION_ERROR","La solicitud contiene datos inválidos",r,d);}
 @ExceptionHandler(AccessDeniedException.class) ResponseEntity<ApiError> denied(AccessDeniedException e,HttpServletRequest r){return body(HttpStatus.FORBIDDEN,"ACCESS_DENIED","No tiene permiso para esta operación",r,Map.of());}
 @ExceptionHandler(Exception.class) ResponseEntity<ApiError> unknown(Exception e,HttpServletRequest r){log.error("Unhandled API error on {}",r.getRequestURI(),e);return body(HttpStatus.INTERNAL_SERVER_ERROR,"INTERNAL_ERROR","Ocurrió un error inesperado",r,Map.of());}
 private ResponseEntity<ApiError> body(HttpStatus s,String c,String m,HttpServletRequest r,Map<String,String>d){return ResponseEntity.status(s).body(new ApiError(Instant.now(),s.value(),c,m,r.getRequestURI(),d));}
}
