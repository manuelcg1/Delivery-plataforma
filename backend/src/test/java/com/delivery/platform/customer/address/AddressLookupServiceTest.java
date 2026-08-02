package com.delivery.platform.customer.address;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

class AddressLookupServiceTest {
    private final GoogleAddressClient google=mock(GoogleAddressClient.class);
    private final StringRedisTemplate redis=mock(StringRedisTemplate.class);
    @SuppressWarnings("unchecked") private final ValueOperations<String,String> values=mock(ValueOperations.class);
    private final HttpServletRequest request=mock(HttpServletRequest.class);
    private final IdentityPrincipal principal=new IdentityPrincipal(UUID.randomUUID(),UUID.randomUUID(),"tenant",Set.of(),Set.of());
    private AddressLookupService service;
    @BeforeEach void setup(){when(redis.opsForValue()).thenReturn(values);when(values.increment(anyString())).thenReturn(1L);when(request.getRemoteAddr()).thenReturn("127.0.0.1");service=new AddressLookupService(google,redis,new ObjectMapper(),new SimpleMeterRegistry());}
    @Test void rejectsShortAutocompleteWithoutCallingGoogle(){assertThatThrownBy(()->service.autocomplete(principal,request,"ab",UUID.randomUUID().toString(),null,null)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("ADDRESS_QUERY_INVALID");verifyNoInteractions(google);}
    @Test void forwardsNormalizedAutocompleteAndSessionToken(){String token=UUID.randomUUID().toString();when(google.autocomplete(anyString(),anyString(),any(),any())).thenReturn(List.of());service.autocomplete(principal,request,"  avenida   ejercito ",token,new BigDecimal("-16.39"),new BigDecimal("-71.54"));verify(google).autocomplete("avenida ejercito",token,new BigDecimal("-16.39"),new BigDecimal("-71.54"));}
    @Test void rejectsInvalidReverseCoordinates(){assertThatThrownBy(()->service.reverse(principal,request,new BigDecimal("91"),BigDecimal.ZERO)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("ADDRESS_QUERY_INVALID");verifyNoInteractions(google);}
    @Test void returns429WhenUserLimitIsExceeded(){when(values.increment(anyString())).thenReturn(31L);assertThatThrownBy(()->service.autocomplete(principal,request,"avenida",UUID.randomUUID().toString(),null,null)).isInstanceOf(ApiException.class).extracting("code").isEqualTo("ADDRESS_SEARCH_RATE_LIMITED");verifyNoInteractions(google);}
}
