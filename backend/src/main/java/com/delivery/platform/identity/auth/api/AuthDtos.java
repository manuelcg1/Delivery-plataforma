package com.delivery.platform.identity.auth.api;
import jakarta.validation.constraints.*; import java.util.*;
public final class AuthDtos {private AuthDtos(){}
 public record RegisterTenant(
   @NotBlank(message="Ingresa el nombre de la empresa") @Size(max=160,message="Usa un nombre de hasta 160 caracteres") String tenantName,
   @NotBlank(message="Ingresa el código de la empresa") @Pattern(regexp="[a-z0-9]+(?:-[a-z0-9]+)*",message="Usa minúsculas, números y guiones, por ejemplo: elite-delivery") String tenantCode,
   @NotBlank(message="Ingresa el nombre del administrador") String adminFirstName,
   @NotBlank(message="Ingresa el apellido del administrador") String adminLastName,
   @Email(message="Ingresa un correo electrónico válido") @NotBlank(message="Ingresa el correo electrónico") String adminEmail,
   @Size(min=10,message="La contraseña debe tener al menos 10 caracteres") @NotBlank(message="Ingresa una contraseña") String adminPassword){}
 public record Login(
   @NotBlank(message="Ingresa el correo o nombre de usuario") String email,
   @NotBlank(message="Ingresa la contraseña") String password,
   @NotBlank(message="Ingresa el código de la empresa") String tenantCode){}
 public record RegisterCustomer(
   @NotBlank(message="Ingresa el código de la empresa") String tenantCode,
   @NotBlank(message="Ingresa tu nombre") @Size(max=100) String firstName,
   @NotBlank(message="Ingresa tu apellido") @Size(max=100) String lastName,
   @Email(message="Ingresa un correo electrónico válido") @NotBlank(message="Ingresa tu correo electrónico") String email,
   @Size(min=10,message="La contraseña debe tener al menos 10 caracteres") @NotBlank(message="Ingresa una contraseña") String password){}
 public record Refresh(String refreshToken){} public record Forgot(@NotBlank String tenantCode,@Email @NotBlank String email){}
 public record ChangePassword(@NotBlank String currentPassword,@Size(min=10) @NotBlank String newPassword){}
 public record Reset(@NotBlank String token,@Size(min=10) @NotBlank String newPassword){}
 public record Tokens(String accessToken,long expiresIn,Object user){} public record Tenant(UUID id,String code,String name){}
 public record Me(UUID id,Tenant tenant,String firstName,String lastName,String email,Set<String> roles,Set<String> permissions,boolean mustChangePassword){}
}
