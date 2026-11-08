package com.delivery.platform.orders.application;
import com.delivery.platform.catalog.schedule.application.BranchHoursService;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.orders.domain.OrderModels.Cart;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import java.util.*;
import java.math.BigDecimal;
import java.time.Instant;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
class OrdersBusinessHoursTest {
 private final OrdersRepository repo=mock(OrdersRepository.class);
 private final BranchHoursService hours=mock(BranchHoursService.class);
 private final OrdersService service=new OrdersService(repo,null,null,hours);
 private final UUID tenant=UUID.randomUUID(), user=UUID.randomUUID(),merchant=UUID.randomUUID(),branch=UUID.randomUUID();
 private final IdentityPrincipal p=new IdentityPrincipal(user,tenant,"demo",Set.of(),Set.of());
 private void closed(){doThrow(new ApiException(HttpStatus.CONFLICT,"OUTSIDE_BUSINESS_HOURS","Fuera de horario de atención")).when(hours).requireOpen(tenant,merchant,branch);}
 private void cart(){when(repo.activeCart(tenant,user)).thenReturn(Optional.of(new Cart(UUID.randomUUID(),user,merchant,branch,BigDecimal.ZERO,BigDecimal.ZERO,BigDecimal.ZERO,BigDecimal.ZERO,BigDecimal.ZERO,"PEN","ACTIVE",List.of(),Instant.now(),Instant.now())));}
 @Test void rejectsAddBeforeReadingOrWritingCart(){closed();assertThrows(ApiException.class,()->service.add(p,merchant,branch,UUID.randomUUID(),1,null));verifyNoInteractions(repo);}
 @Test void rejectsUpdateCoverageCheckoutBeforeWrites(){closed();cart();assertThrows(ApiException.class,()->service.update(p,UUID.randomUUID(),1,null));assertThrows(ApiException.class,()->service.coverage(p,merchant,UUID.randomUUID()));assertThrows(ApiException.class,()->service.checkout(p,UUID.randomUUID(),null));verify(repo,times(3)).activeCart(tenant,user);verifyNoMoreInteractions(repo);}
 @Test void clearRemainsAllowedWhenClosed(){cart();service.clear(p);verifyNoInteractions(hours);verify(repo).clearCart(eq(tenant),any());}
}
