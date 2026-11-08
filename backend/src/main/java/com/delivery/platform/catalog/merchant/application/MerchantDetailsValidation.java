package com.delivery.platform.catalog.merchant.application;

import com.delivery.platform.catalog.merchant.api.MerchantController.Save;
import com.delivery.platform.common.ApiException;
import org.springframework.http.HttpStatus;
import java.time.DateTimeException;
import java.time.ZoneId;
import java.util.Map;

public final class MerchantDetailsValidation {
 private MerchantDetailsValidation() {}
 public static void validate(Save value){
  if(value.code()==null||!value.code().matches("[a-z0-9-]{1,80}"))invalid("code","Usa minúsculas, números y guiones (máximo 80 caracteres).");
  if(value.name()==null||value.name().isBlank()||value.name().length()>160)invalid("name","Ingresa el nombre comercial (máximo 160 caracteres).");
  if(value.legalName()!=null&&value.legalName().length()>160)invalid("legalName","La razón social admite hasta 160 caracteres.");
  if(value.email()!=null&&!value.email().isBlank()&&(!value.email().matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")||value.email().length()>254))invalid("email","Ingresa un correo válido.");
  if(value.phone()!=null&&value.phone().length()>40)invalid("phone","El teléfono admite hasta 40 caracteres.");
  if(value.defaultCurrency()==null||!value.defaultCurrency().matches("[A-Z]{3}"))invalid("defaultCurrency","Ingresa una moneda ISO de tres letras mayúsculas.");
  if(value.merchantType()==null||!value.merchantType().matches("RESTAURANT|GROCERY|PHARMACY|RETAIL|DARK_STORE|OTHER|POLLERIA|BURGERS|CHIFA|ICE_CREAM|BODEGA|SERVICES"))invalid("merchantType","Selecciona un tipo de comercio válido.");
  try{ZoneId.of(value.timezone());}catch(DateTimeException|NullPointerException error){invalid("timezone","Ingresa una zona horaria válida, por ejemplo America/Lima.");}
  if(value.portalAccess()!=null)invalid("portalAccess","Edita el acceso desde su sección independiente.");
 }
 private static void invalid(String field,String message){throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_MERCHANT",message,Map.of(field,message));}
}
