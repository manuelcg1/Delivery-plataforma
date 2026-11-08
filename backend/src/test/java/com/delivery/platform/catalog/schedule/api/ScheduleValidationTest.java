package com.delivery.platform.catalog.schedule.api;
import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.schedule.application.BranchHoursService;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import java.time.LocalTime;
import java.util.*;
import static org.mockito.Mockito.*;
import static org.junit.jupiter.api.Assertions.*;
class ScheduleValidationTest {
 @Test void rejectsInvalidRowsBeforeDelete(){JdbcClient db=mock(JdbcClient.class);CatalogSupport support=mock(CatalogSupport.class);var controller=new ScheduleController(db,support,mock(BranchHoursService.class));var p=new IdentityPrincipal(UUID.randomUUID(),UUID.randomUUID(),"demo",Set.of(),Set.of());UUID b=UUID.randomUUID();
 for(var row:List.of(new ScheduleController.BusinessHour(null,0,null,null,true,null,null),new ScheduleController.BusinessHour(null,8,null,null,true,null,null),new ScheduleController.BusinessHour(null,1,LocalTime.NOON,LocalTime.NOON,false,null,null),new ScheduleController.BusinessHour(null,1,LocalTime.of(9,0),LocalTime.of(15,0),false,LocalTime.NOON,LocalTime.of(18,0)),new ScheduleController.BusinessHour(null,1,LocalTime.NOON,null,false,null,null))) assertThrows(ApiException.class,()->controller.replaceBusinessHours(p,b,List.of(row)));
 var closed=new ScheduleController.BusinessHour(null,1,null,null,true,null,null);assertThrows(ApiException.class,()->controller.replaceBusinessHours(p,b,List.of(closed,closed)));verifyNoInteractions(db);
 }
 @Test void weeklyHoursPermitScopedPortalOperatorWhileSpecialHoursKeepPermissions() throws Exception {
 var read=ScheduleController.class.getMethod("businessHours",IdentityPrincipal.class,UUID.class).getAnnotation(org.springframework.security.access.prepost.PreAuthorize.class).value();
 var write=ScheduleController.class.getMethod("replaceBusinessHours",IdentityPrincipal.class,UUID.class,List.class).getAnnotation(org.springframework.security.access.prepost.PreAuthorize.class).value();
 assertEquals("hasAnyAuthority('CATALOG_HOURS_VIEW','MERCHANT_BRANCH_OPERATE')",read);
 assertEquals("hasAnyAuthority('CATALOG_HOURS_MANAGE','MERCHANT_BRANCH_OPERATE')",write);
 var special=ScheduleController.class.getMethod("specialHours",IdentityPrincipal.class,UUID.class).getAnnotation(org.springframework.security.access.prepost.PreAuthorize.class).value();
 assertEquals("hasAuthority('CATALOG_HOURS_VIEW')",special);
 }
}
