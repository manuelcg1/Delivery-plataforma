package com.delivery.platform.payments.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.payments.domain.PaymentTypes.Method;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class YapePaymentTest {
    JdbcClient db;
    PaymentProvider provider;
    MerchantYapeService settings;
    PaymentService service;
    UUID tenant=UUID.randomUUID(), merchant=UUID.randomUUID(), order=UUID.randomUUID(), user=UUID.randomUUID();
    IdentityPrincipal p;
    @BeforeEach void setup(){
        db=JdbcClient.create(new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1","sa",""));
        db.sql("create table orders(id uuid,tenant_id uuid,customer_id uuid,merchant_id uuid,total decimal(12,2),currency varchar,status varchar,payment_status varchar default 'PENDING')").update();
        db.sql("create table payments(id uuid,tenant_id uuid,order_id uuid,customer_id uuid,merchant_id uuid,payment_method varchar,provider varchar,status varchar,currency varchar,amount decimal(12,2),idempotency_key varchar,provider_reference varchar,authorized_amount decimal default 0,captured_amount decimal default 0,refunded_amount decimal default 0,provider_payment_id varchar,failure_code varchar,failure_message varchar,created_at timestamp default now(),yape_settings_version varchar,yape_receiver_phone varchar,yape_receiver_holder varchar,customer_declared_at timestamp)").update();
        db.sql("create table audit_logs(tenant_id uuid,user_id uuid,action varchar,entity_type varchar,entity_id uuid)").update();
        db.sql("insert into orders values(?,?,?,?,25,'PEN','PENDING','PENDING')").params(order,tenant,user,merchant).update();
        provider=mock(PaymentProvider.class);when(provider.code()).thenReturn("SIMULATED");
        settings=mock(MerchantYapeService.class);
        when(settings.requireCurrent(any(),eq(merchant),eq("v1"))).thenReturn(new MerchantYapeService.Receiver("987654321","Titular","v1"));
        p=new IdentityPrincipal(user,tenant,"test",Set.of("CUSTOMER"),Set.of());
        service=new PaymentService(db,List.of(provider),"SIMULATED",settings);
    }
    @Test void declarationIsPendingAndSnapshotsReceiverWithoutSimulatedApproval(){
        var payment=service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1");
        assertThat(payment.status().name()).isEqualTo("PENDING");
        assertThat(payment.provider()).isEqualTo("MANUAL_YAPE");
        assertThat(payment.capturedAmount()).isZero();
        assertThat(db.sql("select yape_receiver_phone from payments").query(String.class).single()).isEqualTo("987654321");
        assertThat(db.sql("select yape_settings_version from payments").query(String.class).single()).isEqualTo("v1");
        assertThat(db.sql("select payment_status from orders").query(String.class).single()).isEqualTo("PENDING");
        assertThatThrownBy(()->service.confirm(p,payment.id())).isInstanceOf(ApiException.class);
        verify(provider,never()).process(any(),any(),any());
    }
    @Test void requiresDeclarationVersionCurrencyAndOrderOwnership(){
        assertThatThrownBy(()->service.create(p,order,Method.valueOf("YAPE"),null,"key",false,"v1")).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->service.create(p,order,Method.valueOf("YAPE"),null,"key",true,null)).isInstanceOf(ApiException.class);
        db.sql("update orders set currency='USD'").update();
        assertThatThrownBy(()->service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1")).isInstanceOf(ApiException.class);
        db.sql("update orders set currency='PEN',status='CANCELLED'").update();
        assertThatThrownBy(()->service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1")).isInstanceOf(ApiException.class);
        db.sql("update orders set currency='PEN',customer_id=?").param(UUID.randomUUID()).update();
        assertThatThrownBy(()->service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1")).isInstanceOf(ApiException.class);
        assertThat(db.sql("select count(*) from payments").query(Integer.class).single()).isZero();
    }
    @Test void idempotencyReturnsOnlySameOrderMethodAndCustomer(){
        var first=service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1");
        assertThat(service.create(p,order,Method.valueOf("YAPE"),null,"key",true,"v1").id()).isEqualTo(first.id());
        assertThatThrownBy(()->service.create(p,order,Method.CASH_ON_DELIVERY,null,"key")).isInstanceOf(ApiException.class);
        UUID second=UUID.randomUUID(); db.sql("insert into orders values(?,?,?,?,25,'PEN','PENDING','PENDING')").params(second,tenant,user,merchant).update();
        assertThatThrownBy(()->service.create(p,second,Method.valueOf("YAPE"),null,"key",true,"v1")).isInstanceOf(ApiException.class);
    }
    @Test void manualModeCreatesPendingYapeAndCashWithoutSimulatedProcessing(){
        service=new PaymentService(db,List.of(provider),"MANUAL_YAPE",settings);
        var yape=service.create(p,order,Method.YAPE,null,"manual-yape",true,"v1");
        var cash=service.create(p,order,Method.CASH_ON_DELIVERY,null,"manual-cash");
        assertThat(yape.status().name()).isEqualTo("PENDING");
        assertThat(cash.status().name()).isEqualTo("PENDING");
        assertThat(yape.capturedAmount()).isZero();
        assertThat(cash.capturedAmount()).isZero();
        assertThatThrownBy(()->service.confirm(p,yape.id())).isInstanceOf(ApiException.class);
        assertThatThrownBy(()->service.confirm(p,cash.id())).isInstanceOf(ApiException.class)
            .hasMessageContaining("simulados");
        verify(provider,never()).process(any(),any(),any());
    }
    @Test void cashOnlyCannotSimulateAnExistingCashPayment(){
        var cash=service.create(p,order,Method.CASH_ON_DELIVERY,null,"cash");
        service=new PaymentService(db,List.of(provider),"CASH_ONLY",settings);
        assertThatThrownBy(()->service.confirm(p,cash.id())).isInstanceOf(ApiException.class)
            .hasMessageContaining("simulados");
        verify(provider,never()).process(any(),any(),any());
    }
    @Test void manualModeCannotProcessAnExistingSimulatedCardPayment(){
        var payment=service.create(p,order,Method.CASH_ON_DELIVERY,null,"existing");
        db.sql("update payments set payment_method='CARD',provider='SIMULATED'").update();
        service=new PaymentService(db,List.of(provider),"MANUAL_YAPE",settings);
        assertThatThrownBy(()->service.confirm(p,payment.id())).isInstanceOf(ApiException.class)
            .hasMessageContaining("simulados");
        assertThat(service.one(p,payment.id()).status().name()).isEqualTo("PENDING");
        verify(provider,never()).process(any(),any(),any());
    }
}
