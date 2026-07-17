package com.delivery.platform.catalog.cache;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class CatalogCacheTest {
    @Test void servesCachedCatalogWithoutCallingDatabaseLoader() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked") ValueOperations<String,String> values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        when(values.get(anyString())).thenReturn(null, "[\"cached\"]");
        CatalogCache cache = new CatalogCache(redis, new ObjectMapper(), 60);

        List<String> result = cache.getOrLoad(UUID.randomUUID(), "products", new TypeReference<>() {},
                () -> { throw new AssertionError("loader should not execute"); });

        assertThat(result).containsExactly("cached");
    }

    @Test void invalidationIncrementsTenantVersion() {
        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        @SuppressWarnings("unchecked") ValueOperations<String,String> values = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(values);
        UUID tenant = UUID.randomUUID();
        new CatalogCache(redis, new ObjectMapper(), 60).invalidate(tenant);
        verify(values).increment("catalog:tenant:" + tenant + ":version");
    }
}
