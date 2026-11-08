package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;

import java.util.Set;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.mock;

class MerchantOrderOptionsTest {
    private final UUID tenant = UUID.randomUUID(), merchant = UUID.randomUUID(), branch = UUID.randomUUID();
    private final UUID user = UUID.randomUUID(), customer = UUID.randomUUID(), address = UUID.randomUUID();
    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    private JdbcClient db;
    private MerchantPortalService service;
    private IdentityPrincipal principal;
    private String postgresSchema;
    private javax.sql.DataSource dataSource;

    @BeforeEach void setup() {
        // Optional PostgreSQL run against a dedicated test database; every test owns its schema.
        String postgresUrl = System.getProperty("merchant.test.jdbcUrl");
        DriverManagerDataSource source;
        if (postgresUrl == null) {
            source = new DriverManagerDataSource("jdbc:h2:mem:" + UUID.randomUUID() + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1;NON_KEYWORDS=USER", "sa", "");
        } else {
            postgresSchema = "order_options_" + UUID.randomUUID().toString().replace("-", "");
            source = new DriverManagerDataSource(postgresUrl,
                System.getenv().getOrDefault("MERCHANT_TEST_DB_USER", "postgres"),
                System.getenv().getOrDefault("MERCHANT_TEST_DB_PASSWORD", ""));
            JdbcClient.create(source).sql("create schema " + postgresSchema).update();
            var properties = new java.util.Properties();
            properties.setProperty("currentSchema", postgresSchema);
            source.setConnectionProperties(properties);
        }
        dataSource = source;
        new ResourceDatabasePopulator(new ClassPathResource("merchant-order-options.sql")).execute(source);
        db = JdbcClient.create(source);
        service = new MerchantPortalService(db, mock(RealtimeGateway.class));
        principal = new IdentityPrincipal(user, tenant, "test", Set.of("MERCHANT_OPERATOR"), Set.of("MERCHANT_ORDERS_VIEW"));
        db.sql("insert into merchants(id,tenant_id) values (?,?)").params(merchant, tenant).update();
        db.sql("insert into branches values (?,?,?,?)").params(branch, tenant, merchant, "Centro").update();
        db.sql("insert into users(id,first_name,last_name,tenant_id,phone) values (?,?,?,?,?)")
            .params(customer, "Cliente", "Prueba", tenant, "+51912345678").update();
        db.sql("insert into delivery_addresses values (?,?,?,?)").params(address, "999999999", "Calle 1", "Centro").update();
        UUID membership = UUID.randomUUID();
        db.sql("insert into merchant_memberships values (?,?,?,?,true)").params(membership, tenant, merchant, user).update();
        db.sql("insert into merchant_branch_assignments values (?,?)").params(membership, branch).update();
    }

    @AfterEach void cleanup() throws java.sql.SQLException {
        if (db == null) return;
        if (postgresSchema == null) {
            // H2 closes the connection on SHUTDOWN; JdbcTemplate may subsequently read warnings
            // from that closed connection when another test enabled debug logging.
            try (var connection=dataSource.getConnection(); var statement=connection.createStatement()) {
                statement.execute("SHUTDOWN");
            }
        }
        else db.sql("drop schema " + postgresSchema + " cascade").update();
    }

    @Test void accountPhoneIsReturnedInListAndDetailWithoutReplacingDeliveryPhone() {
        UUID id = order(tenant, merchant, branch, "011");
        JsonNode detail = json.valueToTree(service.order(principal, id));
        assertEquals("+51912345678", detail.path("order").path("customerPhone").asText());
        assertEquals("999999999", detail.path("phone").asText());
        JsonNode row = json.valueToTree(service.orders(principal, merchant, branch, null, null, 0, 20).content().get(0));
        assertEquals("+51912345678", row.path("customerPhone").asText());
    }

    @Test void previousCustomerWithoutPhoneRemainsReadable() {
        UUID id = order(tenant, merchant, branch, "012");
        db.sql("update users set phone=null where id=?").param(customer).update();
        JsonNode detail = json.valueToTree(service.order(principal, id));
        assertTrue(detail.path("order").path("customerPhone").isNull());
        assertEquals("999999999", detail.path("phone").asText());
    }

    @Test void contactFromAnotherTenantCannotBeExposedThroughCorruptOrder() {
        UUID id = order(tenant, merchant, branch, "013");
        db.sql("update users set tenant_id=? where id=?").params(UUID.randomUUID(),customer).update();
        assertThrows(ApiException.class, () -> service.order(principal, id));
        assertTrue(service.orders(principal, merchant, branch, null, null, 0, 20).content().isEmpty());
    }

    @Test void detailPreservesHistoricalOptionsAndSeparatesSameProductSelections() {
        UUID order = order(tenant, merchant, branch, "001");
        UUID first = item(tenant, order, 2, "12.50", "25.00", "Sin cucharita");
        UUID second = item(tenant, order, 1, "10.00", "10.00", null);
        option(tenant, first, "Sabores", "Fresa histórica", "0.00");
        option(tenant, first, "Extras", "Chocolate histórico", "2.50");
        option(tenant, second, "Sabores", "Vainilla", "0.00");
        // A corrupt cross-tenant option must never become visible through the join.
        option(UUID.randomUUID(), first, "Secreto", "Otra empresa", "1.00");

        JsonNode result = json.valueToTree(service.order(principal, order));
        JsonNode items = result.path("items");
        assertEquals(2, items.size());
        JsonNode firstItem = find(items, first);
        assertEquals(2, firstItem.path("quantity").asInt());
        assertEquals("Sin cucharita", firstItem.path("notes").asText());
        assertEquals(25.0, firstItem.path("subtotal").asDouble());
        assertEquals(2, firstItem.path("options").size());
        assertTrue(firstItem.path("options").toString().contains("Fresa histórica"));
        assertTrue(firstItem.path("options").toString().contains("Chocolate histórico"));
        for (JsonNode option : firstItem.path("options")) {
            assertEquals(option.path("itemName").asText().equals("Fresa histórica") ? 0.0 : 2.5,
                option.path("priceAdjustment").asDouble());
        }
        assertFalse(items.toString().contains("Otra empresa"));
        assertEquals("Vainilla", find(items, second).path("options").get(0).path("itemName").asText());
        assertEquals("Tocar el timbre", result.path("notes").asText());
    }

    @Test void listReturnsOptionsOnlyForTheRequestedPageAndAuthorizedBranch() {
        UUID first = order(tenant, merchant, branch, "001");
        UUID firstItem = item(tenant, first, 1, "10", "10", null);
        option(tenant, firstItem, "Sabores", "Fresa", "0");
        UUID second = order(tenant, merchant, branch, "002");
        item(tenant, second, 1, "10", "10", null);
        UUID forbiddenBranch = UUID.randomUUID();
        db.sql("insert into branches values (?,?,?,?)").params(forbiddenBranch, tenant, merchant, "No asignada").update();
        UUID forbidden = order(tenant, merchant, forbiddenBranch, "003");
        item(tenant, forbidden, 1, "10", "10", "Privado");
        order(UUID.randomUUID(), merchant, branch, "004");
        UUID otherMerchant = UUID.randomUUID();
        db.sql("insert into merchants(id,tenant_id) values (?,?)").params(otherMerchant, tenant).update();
        order(tenant, otherMerchant, branch, "005");

        var page = service.orders(principal, merchant, null, null, null, 0, 1);
        assertEquals(2, page.totalElements());
        assertEquals(1, page.content().size());
        JsonNode row = json.valueToTree(page.content().get(0));
        assertEquals(first.toString(), row.path("id").asText());
        assertEquals("Fresa", row.path("items").get(0).path("options").get(0).path("itemName").asText());
        assertEquals(1, row.path("items").size());
        var next = service.orders(principal, merchant, branch, null, null, 1, 1);
        JsonNode nextRow = json.valueToTree(next.content().get(0));
        assertEquals(second.toString(), nextRow.path("id").asText());
        assertEquals(0, nextRow.path("items").get(0).path("options").size());
        assertTrue(service.orders(principal, merchant, branch, null, null, 5, 1).content().isEmpty());
    }

    @Test void detailRejectsAnotherTenantMerchantAndUnassignedBranch() {
        assertThrows(ApiException.class, () -> service.order(principal, order(UUID.randomUUID(), merchant, branch, "001")));
        UUID otherMerchant = UUID.randomUUID();
        db.sql("insert into merchants(id,tenant_id) values (?,?)").params(otherMerchant, tenant).update();
        assertThrows(ApiException.class, () -> service.order(principal, order(tenant, otherMerchant, branch, "002")));
        UUID otherBranch = UUID.randomUUID();
        db.sql("insert into branches values (?,?,?,?)").params(otherBranch, tenant, merchant, "Privada").update();
        assertThrows(ApiException.class, () -> service.order(principal, order(tenant, merchant, otherBranch, "003")));
    }

    @Test void administratorsStillSeeAllBranchesAndOrdersWithoutItemsRemainReadable() {
        UUID otherBranch = UUID.randomUUID();
        db.sql("insert into branches values (?,?,?,?)").params(otherBranch, tenant, merchant, "Otra sucursal").update();
        UUID order = order(tenant, merchant, otherBranch, "001");
        var admin = new IdentityPrincipal(user, tenant, "test", Set.of("TENANT_ADMIN"), Set.of());
        var result = service.orders(admin, merchant, null, null, null, 0, 20);
        assertEquals(1, result.totalElements());
        assertEquals(order, result.content().get(0).id());
        assertTrue(result.content().get(0).items().isEmpty());
        assertTrue(service.order(admin, order).items().isEmpty());
        assertTrue(service.orders(principal, merchant, null, null, null, 0, 20).content().isEmpty());
    }

    @Test
    @EnabledIfSystemProperty(named = "merchant.test.jdbcUrl", matches = "jdbc:postgresql:.*")
    void postgresStatusCountsUseTheSameBranchScopeAsTheList() {
        order(tenant, merchant, branch, "001");
        UUID otherBranch = UUID.randomUUID();
        db.sql("insert into branches values (?,?,?,?)").params(otherBranch, tenant, merchant, "Privada").update();
        order(tenant, merchant, otherBranch, "002");
        assertEquals(1, service.statusCounts(principal, merchant, null).get(0).count());
        var admin = new IdentityPrincipal(user, tenant, "test", Set.of("TENANT_ADMIN"), Set.of());
        assertEquals(2, service.statusCounts(admin, merchant, null).get(0).count());
    }

    private UUID order(UUID owner, UUID shop, UUID location, String number) {
        UUID id = UUID.randomUUID();
        db.sql("insert into orders values (?,?,?,?,?,?,?,'PENDING','PAID',35,'PEN',1,?,?,?)")
            .params(id, owner, shop, location, customer, address, number,
                java.time.OffsetDateTime.parse("2026-09-19T12:00:00Z").plusSeconds(Integer.parseInt(number)),
                java.time.OffsetDateTime.parse("2026-09-19T12:00:00Z"), "Tocar el timbre").update();
        return id;
    }

    private UUID item(UUID owner, UUID order, int quantity, String unit, String subtotal, String notes) {
        UUID id = UUID.randomUUID();
        db.sql("insert into order_items values (?,?,?,'Helado',?,?,?,?)")
            .params(id, owner, order, quantity, new java.math.BigDecimal(unit), new java.math.BigDecimal(subtotal), notes).update();
        return id;
    }

    private void option(UUID owner, UUID item, String group, String name, String price) {
        db.sql("insert into order_item_options values (?,?,?,?,?,?,?,?)")
            .params(UUID.randomUUID(), owner, item, UUID.randomUUID(), UUID.randomUUID(), group, name, new java.math.BigDecimal(price)).update();
    }

    private JsonNode find(JsonNode items, UUID id) {
        for (JsonNode item : items) if (id.toString().equals(item.path("id").asText())) return item;
        fail("Missing item " + id);
        return null;
    }
}
