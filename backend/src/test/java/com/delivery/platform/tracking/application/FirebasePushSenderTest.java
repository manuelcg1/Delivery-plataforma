package com.delivery.platform.tracking.application;

import com.google.firebase.messaging.*;
import com.google.api.core.ApiFutures;
import org.junit.jupiter.api.*;
import org.mockito.MockedStatic;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import java.util.*;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

class FirebasePushSenderTest {
    private JdbcClient db;
    private FirebasePushSender sender;
    private DriverManagerDataSource source;
    private FirebaseMessaging messaging;
    private MockedStatic<FirebaseMessaging> firebase;
    private final UUID tenant=UUID.randomUUID(), user=UUID.randomUUID();

    @BeforeEach void setup() {
        source=new DriverManagerDataSource("jdbc:h2:mem:"+UUID.randomUUID()+";DB_CLOSE_DELAY=-1","sa","");
        db=JdbcClient.create(source);
        db.sql("create table device_tokens(tenant_id uuid,user_id uuid,token varchar,active boolean)").update();
        sender=new FirebasePushSender(db);
        messaging=mock(FirebaseMessaging.class);
        firebase=mockStatic(FirebaseMessaging.class);
        firebase.when(FirebaseMessaging::getInstance).thenReturn(messaging);
    }
    @AfterEach void cleanup() throws java.sql.SQLException {
        firebase.close();
        try(var connection=source.getConnection(); var statement=connection.createStatement()) {
            statement.execute("SHUTDOWN");
        }
    }
    private void token(UUID t,UUID u,String token,boolean active) {
        db.sql("insert into device_tokens values(?,?,?,?)").params(t,u,token,active).update();
    }
    private FirebasePushSender.Result send() {
        return sender.send(tenant,user,"COURIER_ARRIVED:delivery",Map.of("type","COURIER_ARRIVED","orderId","order"));
    }
    @Test void missingFirebaseIsRecordedWithoutThrowing() {
        firebase.when(FirebaseMessaging::getInstance).thenThrow(new IllegalStateException("not initialized"));
        assertThat(send()).isEqualTo(new FirebasePushSender.Result(false,"FIREBASE_NOT_CONFIGURED"));
    }
    @Test void doesNotSendToAnotherUserTenantOrInactiveDevice() {
        token(UUID.randomUUID(),user,"other-tenant",true);
        token(tenant,UUID.randomUUID(),"other-user",true);
        token(tenant,user,"inactive",false);
        assertThat(send()).isEqualTo(new FirebasePushSender.Result(false,"NO_ACTIVE_DEVICE_TOKEN"));
        verifyNoInteractions(messaging);
    }
    @Test void acceptanceIsNotOverwrittenByFailureOnAnotherDevice() throws Exception {
        token(tenant,user,"valid",true); token(tenant,user,"expired",true);
        FirebaseMessagingException error=mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.UNREGISTERED);
        when(messaging.sendAsync(any(Message.class))).thenReturn(ApiFutures.immediateFuture("accepted"),ApiFutures.immediateFailedFuture(error));
        assertThat(send().accepted()).isTrue();
        assertThat(db.sql("select count(*) from device_tokens where active=false").query(Integer.class).single()).isEqualTo(1);
    }
    @Test void payloadErrorsDoNotDisableAValidToken() throws Exception {
        token(tenant,user,"valid",true);
        FirebaseMessagingException error=mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.INVALID_ARGUMENT);
        when(messaging.sendAsync(any(Message.class))).thenReturn(ApiFutures.immediateFailedFuture(error));
        assertThat(send()).isEqualTo(new FirebasePushSender.Result(false,"INVALID_ARGUMENT"));
        assertThat(db.sql("select active from device_tokens").query(Boolean.class).single()).isTrue();
    }
}
