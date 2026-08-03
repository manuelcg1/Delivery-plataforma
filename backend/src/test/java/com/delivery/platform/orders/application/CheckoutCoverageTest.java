package com.delivery.platform.orders.application;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;
import com.delivery.platform.delivery.application.DeliveryCoverageService;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.orders.domain.OrderModels.Cart;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import org.junit.jupiter.api.Test;

class CheckoutCoverageTest {
    @Test void rejectsCoverageOutsideConfiguredZone(){OrdersRepository repo=mock(OrdersRepository.class);DeliveryCoverageService coverage=mock(DeliveryCoverageService.class);OrdersService service=new OrdersService(repo,coverage,new SimpleMeterRegistry());UUID tenant=UUID.randomUUID(),customer=UUID.randomUUID(),merchant=UUID.randomUUID(),branch=UUID.randomUUID(),address=UUID.randomUUID();IdentityPrincipal principal=new IdentityPrincipal(customer,tenant,"tenant",Set.of(),Set.of());Cart cart=new Cart(UUID.randomUUID(),customer,merchant,branch,new BigDecimal("20"),BigDecimal.ZERO,BigDecimal.ZERO,BigDecimal.ZERO,new BigDecimal("20"),"PEN","ACTIVE",List.of(),Instant.now(),Instant.now());when(repo.activeCart(tenant,customer)).thenReturn(Optional.of(cart));when(coverage.quote(tenant,customer,merchant,branch,address,new BigDecimal("20"))).thenReturn(new DeliveryCoverageService.Quote(false,null,null,0,null,null,null,"OUTSIDE_COVERAGE","Este comercio todavía no realiza entregas en esta ubicación."));var result=service.coverage(principal,merchant,address);assertThat(result.covered()).isFalse();assertThat(result.reasonCode()).isEqualTo("OUTSIDE_COVERAGE");assertThat(result.message()).contains("todavía no realiza entregas");verify(repo).address(tenant,customer,address);}
}
