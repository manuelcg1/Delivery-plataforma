package com.delivery.platform.identity.security;
import java.security.Principal;
import java.util.*;
public record IdentityPrincipal(UUID userId,UUID tenantId,String tenantCode,Set<String> roles,Set<String> permissions) implements Principal {
    @Override public String getName(){return userId.toString();}
}
