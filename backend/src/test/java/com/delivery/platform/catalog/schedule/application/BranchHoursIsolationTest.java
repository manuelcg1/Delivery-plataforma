package com.delivery.platform.catalog.schedule.application;
import com.delivery.platform.common.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import java.time.*;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
class BranchHoursIsolationTest {
 @Test void isolatesTenantAndMerchantAndUsesInjectedClock(){
 var db=JdbcClient.create(new DriverManagerDataSource("jdbc:h2:mem:hours_"+UUID.randomUUID()+";DB_CLOSE_DELAY=-1","sa",""));
 db.sql("create table merchants(id uuid,tenant_id uuid,status varchar)").update();
 db.sql("create table branches(id uuid,tenant_id uuid,merchant_id uuid,status varchar,timezone varchar,paused_until timestamp with time zone)").update();
 db.sql("create table business_hours(tenant_id uuid,branch_id uuid,day_of_week int,closed boolean,open_time time,close_time time,second_open_time time,second_close_time time)").update();
 db.sql("create table branch_special_hours(tenant_id uuid,branch_id uuid,special_date date,closed boolean,open_time time,close_time time)").update();
 UUID tenant=UUID.randomUUID(),other=UUID.randomUUID(),merchant=UUID.randomUUID(),branch=UUID.randomUUID();
 db.sql("insert into merchants values(:m,:t,'ACTIVE')").param("m",merchant).param("t",tenant).update();
 db.sql("insert into branches values(:b,:t,:m,'ACTIVE','America/Lima',null)").param("b",branch).param("t",tenant).param("m",merchant).update();
 var service=new BranchHoursService(db,Clock.fixed(Instant.parse("2026-11-09T14:00:00Z"),ZoneOffset.UTC));
 assertThrows(ApiException.class,()->service.availability(other,branch));
 assertThrows(ApiException.class,()->service.availability(tenant,UUID.randomUUID(),branch));
 db.sql("insert into business_hours values(:t,:b,1,false,'09:00','10:00',null,null)").param("t",other).param("b",branch).update();
 assertEquals("UNCONFIGURED",service.availability(tenant,branch).status());
 db.sql("insert into business_hours values(:t,:b,1,false,'09:00','10:00',null,null)").param("t",tenant).param("b",branch).update();
 assertTrue(service.availability(tenant,merchant,branch).open());
 db.sql("insert into branch_special_hours values(:t,:b,'2026-11-09',true,null,null)").param("t",other).param("b",branch).update();
 assertTrue(service.availability(tenant,branch).open());
 db.sql("update branches set paused_until='2026-11-09 14:30:00+00'").update();
 var paused=service.availability(tenant,branch);assertFalse(paused.open());assertEquals("TEMPORARILY_CLOSED",paused.status());assertEquals(Instant.parse("2026-11-09T14:30:00Z"),paused.nextOpeningAt().toInstant());
 assertThrows(ApiException.class,()->service.requireOpen(tenant,merchant,branch));
 db.sql("update branches set paused_until='2026-11-09 16:00:00+00'").update();
 assertEquals(Instant.parse("2026-11-16T14:00:00Z"),service.availability(tenant,branch).nextOpeningAt().toInstant());
 db.sql("update branches set paused_until='2026-11-09 13:59:00+00'").update();
 assertTrue(service.availability(tenant,branch).open());
 db.sql("update merchants set tenant_id=:t").param("t",other).update();
 assertThrows(ApiException.class,()->service.availability(tenant,branch));
 }
}
