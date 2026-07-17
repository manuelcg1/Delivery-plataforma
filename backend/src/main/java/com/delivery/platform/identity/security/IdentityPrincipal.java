package com.delivery.platform.identity.security;
import java.util.*;
public record IdentityPrincipal(UUID userId,UUID tenantId,String tenantCode,Set<String> roles,Set<String> permissions) {}
