package com.delivery.platform.merchant.application;
import org.junit.jupiter.api.Test;
import java.util.Arrays;
import static org.junit.jupiter.api.Assertions.*;
class MerchantCourierAssignmentServiceTest {
 @Test void assignmentButtonsFollowPreparationSequence(){assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("CONFIRMED"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("PREPARING"));assertTrue(MerchantCourierAssignmentService.isAssignableOrderStatus("READY"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("PENDING"));assertFalse(MerchantCourierAssignmentService.isAssignableOrderStatus("DELIVERED"));}
 @Test void rejectionAndExpirationUseRequiredMessage(){assertEquals("Pedido no aceptado por el repartidor.",MerchantCourierAssignmentService.NOT_ACCEPTED);}
 @Test void assignmentInfoExposesCourierAndCustomerCoordinates(){var names=Arrays.stream(MerchantCourierAssignmentService.AssignmentInfo.class.getRecordComponents()).map(component->component.getName()).toList();assertTrue(names.containsAll(java.util.List.of("latitude","longitude","lastLocationAt","customerLatitude","customerLongitude")));}
}
