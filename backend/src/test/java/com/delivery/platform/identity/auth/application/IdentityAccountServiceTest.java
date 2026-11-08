package com.delivery.platform.identity.auth.application;

import com.delivery.platform.common.ApiException;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class IdentityAccountServiceTest {
    private JdbcClient db;
    private DriverManagerDataSource source;
    private IdentityAccountService service;

    @BeforeEach
    void setUp() {
        source = new DriverManagerDataSource(
                "jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1", "sa", "");
        db = JdbcClient.create(source);
        db.sql("""
                create table identity_accounts(
                  id uuid default random_uuid() primary key, email varchar(254) unique, legacy_email varchar(254),
                  password_hash varchar(100), status varchar(20), email_conflict boolean)
                """).update();
        service = new IdentityAccountService(db, new BCryptPasswordEncoder());
    }

    @AfterEach
    void tearDown() throws Exception {
        try (var connection = source.getConnection(); var statement = connection.createStatement()) {
            statement.execute("SHUTDOWN");
        }
    }

    @Test
    void verifiedCredentialReusesGlobalIdentityAcrossMembershipRegistrations() {
        var first = service.verifyOrCreate("Person@Example.test", "correct-password");
        var second = service.verifyOrCreate("person@example.test", "correct-password");

        assertEquals(first.id(), second.id());
    }

    @Test
    void existingIdentityCannotBeLinkedWithAnotherPassword() {
        service.verifyOrCreate("person@example.test", "correct-password");

        assertThrows(ApiException.class,
                () -> service.verifyOrCreate("person@example.test", "different-password"));
        assertThrows(ApiException.class,
                () -> service.createForManagedUser("person@example.test", "temporary-password"));
    }
}