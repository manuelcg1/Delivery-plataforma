package com.delivery.platform.orders.domain;
import java.math.BigDecimal;import java.time.Instant;import java.util.*;
public final class OrderModels {private OrderModels(){}
 public record Cart(UUID id,UUID customerId,UUID merchantId,UUID branchId,BigDecimal subtotal,BigDecimal discount,BigDecimal tax,BigDecimal deliveryFee,BigDecimal total,String currency,String status,List<CartItem> items,Instant createdAt,Instant updatedAt){}
 public record CartItem(UUID id,UUID cartId,UUID productId,String productName,int quantity,BigDecimal unitPrice,BigDecimal subtotal,String notes,Instant createdAt){}
 public record Order(UUID id,String orderNumber,UUID customerId,UUID merchantId,UUID branchId,UUID deliveryAddressId,OrderStatus status,String paymentStatus,BigDecimal subtotal,BigDecimal discount,BigDecimal tax,BigDecimal deliveryFee,BigDecimal total,String currency,String notes,List<OrderItem> items,List<OrderStatusHistory> history,boolean ratingSubmitted,Instant createdAt,Instant updatedAt){}
 public record OrderItem(UUID id,UUID orderId,UUID productId,String productName,int quantity,BigDecimal unitPrice,BigDecimal subtotal,String notes){}
 public record DeliveryAddress(UUID id,String label,String recipientName,String phone,String addressLine,String district,String province,String department,String countryCode,String postalCode,BigDecimal latitude,BigDecimal longitude,String reference,boolean active){}
 public record OrderStatusHistory(UUID id,OrderStatus status,String notes,Instant createdAt){}
 public record OrderSummary(BigDecimal subtotal,BigDecimal discount,BigDecimal tax,BigDecimal deliveryFee,BigDecimal total,String currency){}
}
