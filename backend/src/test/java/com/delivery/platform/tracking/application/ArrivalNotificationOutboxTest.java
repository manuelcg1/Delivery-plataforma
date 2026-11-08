package com.delivery.platform.tracking.application;

import com.delivery.platform.tracking.realtime.RealtimeGateway;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.*;
import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionTemplate;
import javax.sql.DataSource;
import java.time.Instant;
import java.sql.Timestamp;
import java.util.*;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class ArrivalNotificationOutboxTest {
    private AnnotationConfigApplicationContext context;
    private JdbcClient db;
    private TransactionTemplate transaction;
    private ArrivalNotificationOutbox outbox;
    private final UUID tenant = UUID.randomUUID(), customer = UUID.randomUUID();
    private final UUID delivery = UUID.randomUUID(), order = UUID.randomUUID(), courier = UUID.randomUUID();

    @Configuration @EnableTransactionManagement
    static class Config {
        @Bean DataSource source() {
            String url=System.getProperty("arrival.test.jdbcUrl");
            if(url!=null) {
                String schema="arrival_test_"+UUID.randomUUID().toString().replace("-","");
                var source=new DriverManagerDataSource(url,"postgres","");
                JdbcClient.create(source).sql("create schema "+schema).update();
                Properties properties=new Properties();
                properties.setProperty("currentSchema",schema);
                source.setConnectionProperties(properties);
                return source;
            }
            return new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
        }
        @Bean JdbcClient db(DataSource source) { return JdbcClient.create(source); }
        @Bean PlatformTransactionManager manager(DataSource source) { return new DataSourceTransactionManager(source); }
        @Bean FirebasePushSender sender() { return mock(FirebasePushSender.class); }
        @Bean RealtimeGateway realtime() { return mock(RealtimeGateway.class); }
        @Bean SimpleMeterRegistry metrics() { return new SimpleMeterRegistry(); }
        @Bean ArrivalNotificationOutbox outbox(JdbcClient db, PlatformTransactionManager manager, FirebasePushSender sender, SimpleMeterRegistry metrics) {
            return new ArrivalNotificationOutbox(db, manager, sender, metrics);
        }
        @Bean CourierNotificationService notifications(JdbcClient db, RealtimeGateway realtime,
                org.springframework.context.ApplicationEventPublisher events, SimpleMeterRegistry metrics) {
            return new CourierNotificationService(db, realtime, events, metrics);
        }
        @Bean CourierArrivalEventListener listener(CourierNotificationService notifications, ArrivalNotificationOutbox outbox) {
            return new CourierArrivalEventListener(notifications, outbox);
        }
    }

    @BeforeEach void setup() {
        context = new AnnotationConfigApplicationContext(Config.class);
        db = context.getBean(JdbcClient.class);
        transaction = new TransactionTemplate(context.getBean(PlatformTransactionManager.class));
        outbox = context.getBean(ArrivalNotificationOutbox.class);
        db.sql("create table deliveries(id uuid primary key, tenant_id uuid, order_id uuid, customer_id uuid, courier_id uuid, merchant_id uuid, status varchar, arrival_notified_at timestamp with time zone)").update();
        db.sql("create table courier_profiles(id uuid, tenant_id uuid, user_id uuid)").update();
        db.sql("create table courier_arrival_audit(tenant_id uuid, delivery_id uuid, notified_at timestamp with time zone)").update();
        db.sql("""
            create table notifications(id uuid default gen_random_uuid() primary key, tenant_id uuid, user_id uuid,
            delivery_id uuid, event_type varchar, title varchar, body varchar, channel varchar, status varchar,
            deduplication_key varchar, created_at timestamp with time zone default current_timestamp,
            sent_at timestamp with time zone, attempt_count int default 0, last_attempt_at timestamp with time zone,
            claim_token uuid, claim_until timestamp with time zone, next_attempt_at timestamp with time zone,
            last_error varchar(200), unique(tenant_id,user_id,deduplication_key))
            """.replace("gen_random_uuid()", System.getProperty("arrival.test.jdbcUrl")==null ? "random_uuid()" : "gen_random_uuid()")).update();
        db.sql("insert into deliveries(id,tenant_id,order_id,customer_id,courier_id,merchant_id,status) values(?,?,?,?,?,?,'IN_TRANSIT')")
            .params(delivery, tenant, order, customer, courier, UUID.randomUUID()).update();
        db.sql("insert into courier_profiles values(?,?,?)").params(courier, tenant, UUID.randomUUID()).update();
        db.sql("insert into courier_arrival_audit(tenant_id,delivery_id) values(?,?)").params(tenant,delivery).update();
        when(context.getBean(FirebasePushSender.class).send(any(),any(),anyString(),anyMap()))
            .thenReturn(new FirebasePushSender.Result(true, null));
    }
    @AfterEach void cleanup() throws java.sql.SQLException {
        if (db!=null) {
            if(System.getProperty("arrival.test.jdbcUrl")==null) {
                try(var connection=context.getBean(DataSource.class).getConnection(); var statement=connection.createStatement()) {
                    statement.execute("SHUTDOWN");
                }
            }
            else {
                String schema=db.sql("select current_schema()").query(String.class).single();
                if(!schema.matches("arrival_test_[a-f0-9]{32}")) throw new IllegalStateException("Unexpected test schema");
                db.sql("drop schema "+schema+" cascade").update();
            }
        }
        if(context!=null) context.close();
    }

    private void arrive() {
        transaction.executeWithoutResult(s -> {
            db.sql("update deliveries set status='ARRIVED_AT_CUSTOMER' where id=?").param(delivery).update();
            context.publishEvent(new CourierArrivalEvent(tenant, delivery, order, customer, courier, null, Instant.now(), "MANUAL"));
        });
    }
    private String status() { return db.sql("select status from notifications").query(String.class).single(); }

    @Test void commitsPendingNoticeWithArrivalAndSendsOnlyFromWorker() {
        arrive();
        assertThat(status()).isEqualTo("PENDING");
        verifyNoInteractions(context.getBean(FirebasePushSender.class));
        outbox.processPending();
        assertThat(status()).isEqualTo("SENT");
        assertThat(db.sql("select arrival_notified_at from deliveries").query(Timestamp.class).single()).isNotNull();
        verify(context.getBean(FirebasePushSender.class)).send(eq(tenant), eq(customer), eq("COURIER_ARRIVED:"+delivery),
            argThat(p -> order.toString().equals(p.get("orderId").toString()) && "COURIER_ARRIVED".equals(p.get("type"))));
    }
    @Test void rollbackDoesNotPublishOrLeaveNotice() {
        transaction.executeWithoutResult(s -> {
            context.publishEvent(new CourierArrivalEvent(tenant, delivery, order, customer, courier, null, Instant.now(), "MANUAL"));
            s.setRollbackOnly();
        });
        assertThat(db.sql("select count(*) from notifications").query(Integer.class).single()).isZero();
        verifyNoInteractions(context.getBean(RealtimeGateway.class));
    }
    @Test void duplicateEventQueuesOnlyOneNotice() {
        arrive(); arrive();
        outbox.processPending(); outbox.processPending();
        assertThat(db.sql("select count(*) from notifications").query(Integer.class).single()).isEqualTo(1);
        verify(context.getBean(FirebasePushSender.class), times(1)).send(any(),any(),anyString(),anyMap());
    }
    @Test void retriesFailureButHonorsDelayAndStopsAfterAcceptance() {
        when(context.getBean(FirebasePushSender.class).send(any(),any(),anyString(),anyMap()))
            .thenReturn(new FirebasePushSender.Result(false,"UNAVAILABLE"),new FirebasePushSender.Result(true,null));
        arrive(); outbox.processPending(); outbox.processPending();
        assertThat(status()).isEqualTo("FAILED");
        assertThat(db.sql("select attempt_count from notifications").query(Integer.class).single()).isEqualTo(1);
        db.sql("update notifications set next_attempt_at=?").param(Timestamp.from(Instant.now().minusSeconds(1))).update();
        outbox.processPending(); outbox.processPending();
        assertThat(status()).isEqualTo("SENT");
        assertThat(db.sql("select attempt_count from notifications").query(Integer.class).single()).isEqualTo(2);
    }
    @Test void restartRecoversExpiredLeaseButDoesNotStealActiveClaim() {
        arrive();
        db.sql("update notifications set claim_token=?,claim_until=?").params(UUID.randomUUID(), Timestamp.from(Instant.now().plusSeconds(60))).update();
        outbox.processPending();
        assertThat(status()).isEqualTo("PENDING");
        db.sql("update notifications set claim_until=?").param(Timestamp.from(Instant.now().minusSeconds(1))).update();
        outbox.processPending();
        assertThat(status()).isEqualTo("SENT");
    }
    @Test void exhaustedAttemptsAndExpiredNoticesAreNotSent() {
        arrive();
        db.sql("update notifications set attempt_count=5").update();
        outbox.processPending();
        assertThat(status()).isEqualTo("FAILED");
        verifyNoInteractions(context.getBean(FirebasePushSender.class));
    }
    @Test void anotherTenantCannotQueueThisDelivery() {
        assertThatThrownBy(() -> transaction.executeWithoutResult(s ->
            outbox.enqueue(new CourierArrivalEvent(UUID.randomUUID(),delivery,order,customer,courier,null,Instant.now(),"MANUAL"))))
            .isInstanceOf(RuntimeException.class);
        assertThat(db.sql("select count(*) from notifications").query(Integer.class).single()).isZero();
    }

    @Test void expiredArrivalIsNotPushedLongAfterDelivery() {
        arrive();
        db.sql("update notifications set created_at=?").param(Timestamp.from(Instant.now().minusSeconds(901))).update();
        outbox.processPending();
        assertThat(status()).isEqualTo("FAILED");
        assertThat(db.sql("select last_error from notifications").query(String.class).single()).isEqualTo("EXPIRED");
        verifyNoInteractions(context.getBean(FirebasePushSender.class));
    }

    @Test void twoWorkersCannotSendTheSameClaimAndNetworkRunsOutsideTransaction() throws Exception {
        arrive();
        CountDownLatch sending=new CountDownLatch(1), release=new CountDownLatch(1);
        when(context.getBean(FirebasePushSender.class).send(any(),any(),anyString(),anyMap())).thenAnswer(call -> {
            assertThat(org.springframework.transaction.support.TransactionSynchronizationManager.isActualTransactionActive()).isFalse();
            sending.countDown();
            assertThat(release.await(10,TimeUnit.SECONDS)).isTrue();
            return new FirebasePushSender.Result(true,null);
        });
        try(var executor=Executors.newSingleThreadExecutor()) {
            Future<?> first=executor.submit(outbox::processPending);
            try {
                assertThat(sending.await(10,TimeUnit.SECONDS)).isTrue();
                outbox.processPending();
            } finally { release.countDown(); }
            first.get(10,TimeUnit.SECONDS);
        }
        assertThat(status()).isEqualTo("SENT");
        verify(context.getBean(FirebasePushSender.class),times(1)).send(any(),any(),anyString(),anyMap());
    }

    @Test void persistenceFailureRollsBackArrivalInsteadOfLosingItsNotification() {
        db.sql("drop table notifications").update();
        assertThatThrownBy(this::arrive).isInstanceOf(RuntimeException.class);
        assertThat(db.sql("select status from deliveries").query(String.class).single()).isEqualTo("IN_TRANSIT");
        verifyNoInteractions(context.getBean(RealtimeGateway.class));
    }

    @Test void realtimeFailureDoesNotUndoArrivalOrPreventPush() {
        doThrow(new IllegalStateException("socket unavailable")).when(context.getBean(RealtimeGateway.class))
            .customerOrder(any(),any(),any());
        arrive();
        assertThat(status()).isEqualTo("PENDING");
        outbox.processPending();
        assertThat(status()).isEqualTo("SENT");
    }
}
