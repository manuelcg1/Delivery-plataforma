package com.delivery.platform.tracking.customer;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Repository
public class JdbcCustomerOrderTrackingRepository implements CustomerOrderTrackingRepository {
    private final JdbcClient db;

    public JdbcCustomerOrderTrackingRepository(JdbcClient db) { this.db = db; }

    @Override
    public Optional<TrackingSnapshot> findOwned(UUID tenantId, UUID customerId, UUID orderId) {
        return db.sql("""
                select d.order_id,d.id delivery_id,d.status,d.courier_id,
                       trim(concat(u.first_name,' ',u.last_name)) courier_name,
                       h.latitude,h.longitude,h.speed,h.heading,h.accuracy,h.altitude,
                       h.gps_timestamp,h.received_at
                  from deliveries d
                  join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
                  left join courier_profiles c on c.id=d.courier_id and c.tenant_id=d.tenant_id
                  left join users u on u.id=c.user_id and u.tenant_id=d.tenant_id
                  left join lateral (
                    select latitude,longitude,speed,heading,accuracy,altitude,gps_timestamp,received_at
                      from courier_location_history
                     where tenant_id=d.tenant_id and delivery_id=d.id
                     order by gps_timestamp desc limit 1
                  ) h on true
                 where d.tenant_id=:tenant and d.order_id=:order
                   and o.customer_id=:customer and d.customer_id=:customer
                 order by d.created_at desc limit 1
                """).param("tenant", tenantId).param("order", orderId).param("customer", customerId)
                .query((rs, n) -> new TrackingSnapshot(
                        rs.getObject("order_id", UUID.class), rs.getObject("delivery_id", UUID.class),
                        rs.getString("status"), rs.getObject("courier_id", UUID.class), rs.getString("courier_name"),
                        number(rs, "latitude"), number(rs, "longitude"), number(rs, "speed"),
                        number(rs, "heading"), number(rs, "accuracy"), number(rs, "altitude"),
                        instant(rs, "gps_timestamp"), instant(rs, "received_at"))).optional();
    }

    private static Double number(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        var value = rs.getBigDecimal(column);
        return value == null ? null : value.doubleValue();
    }

    private static Instant instant(java.sql.ResultSet rs, String column) throws java.sql.SQLException {
        var value = rs.getTimestamp(column);
        return value == null ? null : value.toInstant();
    }
}
