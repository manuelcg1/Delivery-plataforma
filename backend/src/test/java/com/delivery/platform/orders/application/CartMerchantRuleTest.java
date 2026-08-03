package com.delivery.platform.orders.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.orders.application.OrdersRepository.ProductSnapshot;
import com.delivery.platform.orders.domain.OrderModels.Cart;
import com.delivery.platform.orders.domain.OrderModels.CartItem;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class CartMerchantRuleTest {
    private final OrdersRepository repository = mock(OrdersRepository.class);
    private final OrdersService service = new OrdersService(repository);
    private final UUID tenant = UUID.randomUUID();
    private final UUID customer = UUID.randomUUID();
    private final IdentityPrincipal principal = new IdentityPrincipal(customer, tenant, "demo", Set.of(), Set.of());

    @Test
    void emptyCartAllowsFirstProductFromAnotherMerchantAndBranch() {
        UUID oldCartId = UUID.randomUUID();
        UUID merchant = UUID.randomUUID();
        UUID branch = UUID.randomUUID();
        UUID product = UUID.randomUUID();
        Cart staleEmpty = cart(oldCartId, UUID.randomUUID(), UUID.randomUUID(), List.of());
        Cart freshEmpty = cart(UUID.randomUUID(), merchant, branch, List.of());
        Cart withProduct = cart(freshEmpty.id(), merchant, branch,
                List.of(item(freshEmpty.id(), product)));
        when(repository.product(tenant, merchant, branch, product)).thenReturn(product(product, merchant));
        when(repository.activeCart(tenant, customer)).thenReturn(Optional.of(staleEmpty));
        when(repository.createCart(tenant, customer, merchant, branch, "PEN")).thenReturn(freshEmpty);
        when(repository.cart(tenant, customer, freshEmpty.id())).thenReturn(withProduct);

        Cart result = service.add(principal, merchant, branch, product, 1, null);

        assertThat(result.items()).hasSize(1);
        assertThat(result.merchantId()).isEqualTo(merchant);
        assertThat(result.branchId()).isEqualTo(branch);
        verify(repository).checkoutCart(tenant, oldCartId);
        verify(repository).addItem(tenant, freshEmpty.id(), product, "Producto", 1,
                new BigDecimal("10.00"), null);
    }

    @Test
    void cartWithItemsBlocksAnotherBranchOfSameMerchant() {
        UUID merchant = UUID.randomUUID();
        UUID oldBranch = UUID.randomUUID();
        UUID newBranch = UUID.randomUUID();
        UUID product = UUID.randomUUID();
        Cart active = cart(UUID.randomUUID(), merchant, oldBranch,
                List.of(item(UUID.randomUUID(), UUID.randomUUID())));
        when(repository.product(tenant, merchant, newBranch, product)).thenReturn(product(product, merchant));
        when(repository.activeCart(tenant, customer)).thenReturn(Optional.of(active));

        assertThatThrownBy(() -> service.add(principal, merchant, newBranch, product, 1, null))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Ya tienes productos de otro comercio");
    }

    @Test
    void cartWithItemsBlocksAnotherMerchant() {
        UUID merchant = UUID.randomUUID();
        UUID branch = UUID.randomUUID();
        UUID product = UUID.randomUUID();
        Cart active = cart(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                List.of(item(UUID.randomUUID(), UUID.randomUUID())));
        when(repository.product(tenant, merchant, branch, product)).thenReturn(product(product, merchant));
        when(repository.activeCart(tenant, customer)).thenReturn(Optional.of(active));

        assertThatThrownBy(() -> service.add(principal, merchant, branch, product, 1, null))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("otro comercio");
    }

    @Test
    void clearCartClosesActiveCartAndRemovesAllContext() {
        Cart active = cart(UUID.randomUUID(), UUID.randomUUID(), UUID.randomUUID(),
                List.of(item(UUID.randomUUID(), UUID.randomUUID())));
        when(repository.activeCart(tenant, customer)).thenReturn(Optional.of(active));

        service.clear(principal);

        verify(repository).clearCart(tenant, active.id());
        verify(repository).checkoutCart(tenant, active.id());
    }

    private Cart cart(UUID id, UUID merchant, UUID branch, List<CartItem> items) {
        return new Cart(id, customer, merchant, branch, BigDecimal.ZERO, BigDecimal.ZERO,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, "PEN", "ACTIVE",
                items, Instant.now(), Instant.now());
    }

    private CartItem item(UUID cartId, UUID productId) {
        return new CartItem(UUID.randomUUID(), cartId, productId, "Producto", 1,
                new BigDecimal("10.00"), new BigDecimal("10.00"), null, Instant.now());
    }

    private ProductSnapshot product(UUID id, UUID merchant) {
        return new ProductSnapshot(id, merchant, "Producto", new BigDecimal("10.00"),
                "PEN", BigDecimal.ZERO, false, null, true, true,
                "PUBLISHED", "ACTIVE", "ACTIVE");
    }
}
