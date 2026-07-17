package com.delivery.platform.identity.security;
import io.jsonwebtoken.*; import io.jsonwebtoken.security.Keys; import org.springframework.beans.factory.annotation.Value; import org.springframework.stereotype.Service;
import javax.crypto.SecretKey; import java.nio.charset.StandardCharsets; import java.time.*; import java.time.temporal.ChronoUnit; import java.util.*;
@Service public class JwtService {
 private final SecretKey key; private final long minutes;
 public JwtService(@Value("${identity.jwt-secret}")String secret,@Value("${identity.access-minutes}")long minutes){this.key=Keys.hmacShaKeyFor(Arrays.copyOf(secret.getBytes(StandardCharsets.UTF_8),32));this.minutes=minutes;}
 public String issue(IdentityPrincipal p){Instant now=Instant.now();return Jwts.builder().subject(p.userId().toString()).claim("userId",p.userId().toString()).claim("tenantId",p.tenantId().toString()).claim("tenantCode",p.tenantCode()).claim("roles",p.roles()).claim("permissions",p.permissions()).issuedAt(Date.from(now)).expiration(Date.from(now.plus(minutes,ChronoUnit.MINUTES))).signWith(key).compact();}
 @SuppressWarnings("unchecked") public IdentityPrincipal parse(String token){Claims c=Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();return new IdentityPrincipal(UUID.fromString(c.get("userId",String.class)),UUID.fromString(c.get("tenantId",String.class)),c.get("tenantCode",String.class),new HashSet<>((List<String>)c.get("roles",List.class)),new HashSet<>((List<String>)c.get("permissions",List.class)));}
 public long expiresIn(){return minutes*60;}
}
