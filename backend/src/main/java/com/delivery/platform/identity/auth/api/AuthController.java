package com.delivery.platform.identity.auth.api;
import com.delivery.platform.identity.auth.application.AuthService; import com.delivery.platform.identity.security.IdentityPrincipal; import jakarta.servlet.http.*; import jakarta.validation.Valid; import org.springframework.beans.factory.annotation.Value; import org.springframework.http.*; import org.springframework.security.core.annotation.AuthenticationPrincipal; import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/auth") public class AuthController {private final AuthService service;@Value("${identity.cookie-secure}")boolean secure;@Value("${identity.refresh-days}")long days;public AuthController(AuthService s){service=s;}
 @PostMapping("/register-tenant") ResponseEntity<?> register(@Valid @RequestBody AuthDtos.RegisterTenant q,HttpServletRequest r){return response(service.register(q,ip(r),r.getHeader("User-Agent")));}
 @PostMapping("/login") ResponseEntity<?> login(@Valid @RequestBody AuthDtos.Login q,HttpServletRequest r){return response(service.login(q,ip(r),r.getHeader("User-Agent")));}
 @PostMapping("/refresh") ResponseEntity<?> refresh(@RequestBody(required=false) AuthDtos.Refresh q,@CookieValue(name="refresh_token",required=false)String cookie,HttpServletRequest r){return response(service.refresh(cookie!=null?cookie:q==null?null:q.refreshToken(),ip(r),r.getHeader("User-Agent")));}
 @PostMapping("/logout") ResponseEntity<Void> logout(@CookieValue(name="refresh_token",required=false)String raw,@AuthenticationPrincipal IdentityPrincipal p,HttpServletRequest r){service.logout(raw,p,ip(r),r.getHeader("User-Agent"));return ResponseEntity.noContent().header(HttpHeaders.SET_COOKIE,cookie("",0).toString()).build();}
 @PostMapping("/forgot-password") void forgot(@Valid @RequestBody AuthDtos.Forgot q,HttpServletRequest r){service.forgot(q,ip(r),r.getHeader("User-Agent"));}
 @PostMapping("/reset-password") void reset(@Valid @RequestBody AuthDtos.Reset q,HttpServletRequest r){service.reset(q,ip(r),r.getHeader("User-Agent"));}
 @GetMapping("/me") AuthDtos.Me me(@AuthenticationPrincipal IdentityPrincipal p){return service.me(p);}
 private ResponseEntity<?> response(AuthService.Session s){return ResponseEntity.ok().header(HttpHeaders.SET_COOKIE,cookie(s.refreshToken(),days*86400).toString()).body(s.response());}
 private ResponseCookie cookie(String v,long age){return ResponseCookie.from("refresh_token",v).httpOnly(true).secure(secure).sameSite("Lax").path("/api/v1/auth").maxAge(age).build();}private String ip(HttpServletRequest r){return r.getRemoteAddr();}
}
