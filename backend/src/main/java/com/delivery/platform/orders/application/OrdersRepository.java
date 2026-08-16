package com.delivery.platform.orders.application;
import com.delivery.platform.orders.domain.OrderModels.*;import com.delivery.platform.delivery.application.DeliveryCoverageService;import java.math.BigDecimal;import java.util.*;
public interface OrdersRepository {
 Optional<Cart> activeCart(UUID tenantId,UUID customerId); Cart cart(UUID tenantId,UUID customerId,UUID id); Cart createCart(UUID tenantId,UUID customerId,UUID merchantId,UUID branchId,String currency);
 void addItem(UUID tenantId,UUID cartId,UUID productId,String name,int quantity,BigDecimal basePrice,List<OptionSelection> options,String signature,String notes);void updateItem(UUID tenantId,UUID cartId,UUID itemId,int quantity,String notes);void deleteItem(UUID tenantId,UUID cartId,UUID itemId);void clearCart(UUID tenantId,UUID cartId);void saveTotals(UUID tenantId,UUID cartId,OrderSummary totals);
 ProductSnapshot product(UUID tenantId,UUID merchantId,UUID branchId,UUID productId);DeliveryAddress address(UUID tenantId,UUID customerId,UUID addressId);List<DeliveryAddress> addresses(UUID tenantId,UUID customerId);DeliveryAddress createAddress(UUID tenantId,UUID customerId,DeliveryAddress address);
 Order createOrder(UUID tenantId,UUID customerId,Cart cart,UUID addressId,String notes,DeliveryCoverageService.Quote quote);void snapshotOrderItems(UUID tenantId,UUID orderId,UUID cartId);List<Order> orders(UUID tenantId,UUID customerId);Order order(UUID tenantId,UUID customerId,UUID orderId);void updateStatus(UUID tenantId,UUID customerId,UUID orderId,com.delivery.platform.orders.domain.OrderStatus status,String notes);void checkoutCart(UUID tenantId,UUID cartId);void audit(UUID tenantId,UUID userId,String action,String type,UUID id);
 record ProductSnapshot(UUID id,UUID merchantId,String name,BigDecimal price,String currency,BigDecimal taxRate,boolean trackInventory,BigDecimal stock,boolean productAvailable,boolean branchAvailable,String productStatus,String merchantStatus,String branchStatus){}
 List<OptionGroupSnapshot> optionGroups(UUID tenantId,UUID productId);
 record OptionGroupSnapshot(UUID id,String name,String selectionType,boolean required,int minimumSelections,Integer maximumSelections,List<OptionSelection> items){}
 record OptionSelection(UUID groupId,UUID itemId,String groupName,String itemName,BigDecimal priceAdjustment){}
}
