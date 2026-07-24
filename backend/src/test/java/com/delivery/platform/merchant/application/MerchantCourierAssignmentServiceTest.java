package com.delivery.platform.merchant.application;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class MerchantCourierAssignmentServiceTest {
 @Test void assignmentButtonsFollowPreparationSequence(){assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("CONFIRMED"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("PREPARING"));assertTrue(MerchantCourierAssignmentService.isAssignableOrderStatus("READY"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("PENDING"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("DELIVERED"));}
 @Test void rejectionAndExpirationUseRequiredMessage(){assertEquals("Pedido no aceptado por el repartidor.",MerchantCourierAssignmentService.NOT_ACCEPTED);}
}
