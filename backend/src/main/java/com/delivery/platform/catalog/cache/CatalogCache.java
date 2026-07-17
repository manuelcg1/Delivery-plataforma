package com.delivery.platform.catalog.cache;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Duration;
import java.util.UUID;
import java.util.function.Supplier;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

@Component
public class CatalogCache {
    private final StringRedisTemplate redis;
    private final ObjectMapper json;
    private final Duration ttl;

    public CatalogCache(StringRedisTemplate redis, ObjectMapper json,
            @Value("${CATALOG_CACHE_TTL_SECONDS:300}") long seconds) {
        this.redis = redis;
        this.json = json;
        this.ttl = Duration.ofSeconds(Math.max(seconds, 1));
    }

    public <T> T getOrLoad(UUID tenantId, String resource, TypeReference<T> type, Supplier<T> loader) {
        String key = key(tenantId, resource);
        try {
            String cached = redis.opsForValue().get(key);
            if (cached != null) return json.readValue(cached, type);
        } catch (Exception ignored) { }
        T value = loader.get();
        try {
            redis.opsForValue().set(key, json.writeValueAsString(value), ttl);
        } catch (Exception ignored) { }
        return value;
    }

    public void invalidate(UUID tenantId) {
        try { redis.opsForValue().increment(versionKey(tenantId)); } catch (Exception ignored) { }
    }

    private String key(UUID tenantId, String resource) {
        String version = "0";
        try {
            String stored = redis.opsForValue().get(versionKey(tenantId));
            if (stored != null) version = stored;
        } catch (Exception ignored) { }
        return "catalog:tenant:" + tenantId + ":v" + version + ":" + resource;
    }

    private String versionKey(UUID tenantId) { return "catalog:tenant:" + tenantId + ":version"; }
}
