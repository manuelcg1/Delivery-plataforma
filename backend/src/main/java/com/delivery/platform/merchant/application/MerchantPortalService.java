package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.common.PageResponse;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.*;

@Service
public class MerchantPortalService {
    private final JdbcClient db;
    private final RealtimeGateway realtime;

    public MerchantPortalService(JdbcClient db, RealtimeGateway realtime) {
        this.db = db;
        this.realtime = realtime;
    }

    public record Branch(UUID id, String name, String status, Instant pausedUntil, String pauseReason) {}
    public record Merchant(UUID id, String name, String role, List<Branch> branches) {}
    public record Context(UUID userId, UUID tenantId, List<Merchant> merchants) {}
    public record OrderRow(UUID id, String orderNumber, UUID merchantId, UUID branchId, String branchName,
                           String customerName, String status, String paymentStatus, BigDecimal total,
                           String currency, int version, Instant createdAt, Instant updatedAt,
                           String deliveryStatus,String courierName,String paymentMethod) {}
    public record OrderItem(String productName, int quantity, BigDecimal unitPrice, BigDecimal subtotal, String notes) {}
    public record OrderDetail(OrderRow order, String phone, String address, String district, String notes,
                              List<OrderItem> items) {}
    public record StatusMetric(String status, long orders, BigDecimal total) {}
    public record DailyMetric(String date, long orders, BigDecimal total) {}
    public record Report(long totalOrders, long completedOrders, long cancelledOrders, BigDecimal grossSales,
                         BigDecimal averageTicket, List<StatusMetric> byStatus, List<DailyMetric> daily) {}
    public record StatusCount(String status,long count) {}

    public Context context(IdentityPrincipal principal) {
        if (principal.roles().contains("ROLE_PLATFORM_OWNER")) {
            throw new ApiException(HttpStatus.FORBIDDEN, "PLATFORM_OWNER_PORTAL_FORBIDDEN",
                "Este usuario pertenece a la administración de la plataforma.");
        }
        List<Merchant> merchants = db.sql("""
            select distinct m.id,m.name,coalesce(mm.role_code,'TENANT_ADMIN') role_code
            from merchants m
            left join merchant_memberships mm on mm.merchant_id=m.id and mm.user_id=:user and mm.active
            where m.tenant_id=:tenant and (:admin or mm.id is not null)
            order by m.name
            """).param("user", principal.userId()).param("tenant", principal.tenantId())
            .param("admin", admin(principal)).query((rs, n) -> new Merchant(
                rs.getObject("id", UUID.class), rs.getString("name"), rs.getString("role_code"),
                branches(principal, rs.getObject("id", UUID.class)))).list();
        return new Context(principal.userId(), principal.tenantId(), merchants);
    }

    public PageResponse<OrderRow> orders(IdentityPrincipal principal, UUID merchantId, UUID branchId,
                                          String status, String search, int page, int size) {
        access(principal, merchantId, branchId);
        int safeSize = Math.min(Math.max(size, 1), 100);
        int safePage = Math.max(page, 0);
        String normalized = search == null ? "" : search.trim();
        String state = status == null ? "" : status.trim().toUpperCase(Locale.ROOT);
        String where = """
            from orders o join branches b on b.id=o.branch_id
            join users u on u.id=o.customer_id
            where o.tenant_id=:tenant and o.merchant_id=:merchant
              and (cast(:branch as uuid) is null or o.branch_id=:branch)
              and (:status='' or (case
                when o.status in ('READY','ASSIGNED') and (select da.status from deliveries d join delivery_assignments da on da.delivery_id=d.id where d.order_id=o.id order by da.assigned_at desc limit 1)='PENDING' then 'SEARCHING_COURIER'
                when o.status in ('READY','ASSIGNED') and (select da.status from deliveries d join delivery_assignments da on da.delivery_id=d.id where d.order_id=o.id order by da.assigned_at desc limit 1)='ACCEPTED' then 'COURIER_ASSIGNED'
                else o.status end)=:status)
              and (:search='' or lower(o.order_number||' '||u.first_name||' '||u.last_name||' '||coalesce((select cu.first_name||' '||cu.last_name from deliveries d join courier_profiles cp on cp.id=d.courier_id join users cu on cu.id=cp.user_id where d.order_id=o.id order by d.created_at desc limit 1),'')) like lower('%'||:search||'%'))
            """;
        long total = query(where, principal, merchantId, branchId, state, normalized,
            "select count(*) " + where).query(Long.class).single();
        List<OrderRow> rows = query(where, principal, merchantId, branchId, state, normalized,
            "select o.*,b.name branch_name,u.first_name||' '||u.last_name customer_name," +
                "(select d.status from deliveries d where d.order_id=o.id and d.tenant_id=o.tenant_id order by d.created_at desc limit 1) delivery_status," +
                "(select cu.first_name||' '||cu.last_name from deliveries d join courier_profiles cp on cp.id=d.courier_id join users cu on cu.id=cp.user_id where d.order_id=o.id and d.tenant_id=o.tenant_id order by d.created_at desc limit 1) courier_name," +
                "(select payment_method from payments where order_id=o.id order by created_at desc limit 1) payment_method," +
                "case when o.status in ('READY','ASSIGNED') and (select da.status from deliveries d join delivery_assignments da on da.delivery_id=d.id where d.order_id=o.id order by da.assigned_at desc limit 1)='PENDING' then 'SEARCHING_COURIER' when o.status in ('READY','ASSIGNED') and (select da.status from deliveries d join delivery_assignments da on da.delivery_id=d.id where d.order_id=o.id order by da.assigned_at desc limit 1)='ACCEPTED' then 'COURIER_ASSIGNED' else o.status end effective_status " + where +
                " order by case o.status when 'PENDING' then 0 when 'CONFIRMED' then 1 when 'PREPARING' then 2 when 'READY' then 3 else 4 end,o.created_at asc limit :limit offset :offset")
            .param("limit", safeSize).param("offset", safePage * safeSize).query(this::row).list();
        return PageResponse.of(rows, safePage, safeSize, total);
    }

    public List<StatusCount> statusCounts(IdentityPrincipal p,UUID merchantId,UUID branchId){
        access(p,merchantId,branchId);
        return db.sql("""
            select case when o.status in ('READY','ASSIGNED') and a.status='PENDING' then 'SEARCHING_COURIER'
                        when o.status in ('READY','ASSIGNED') and a.status='ACCEPTED' then 'COURIER_ASSIGNED'
                        else o.status end effective_status,count(*)
            from orders o left join lateral(
              select da.status from deliveries d join delivery_assignments da on da.delivery_id=d.id
              where d.order_id=o.id and d.tenant_id=o.tenant_id order by da.assigned_at desc limit 1
            )a on true
            where o.tenant_id=:tenant and o.merchant_id=:merchant
              and (cast(:branch as uuid) is null or o.branch_id=:branch)
            group by effective_status order by effective_status
            """).param("tenant",p.tenantId()).param("merchant",merchantId).param("branch",branchId)
            .query((r,n)->new StatusCount(r.getString(1),r.getLong(2))).list();
    }

    public OrderDetail order(IdentityPrincipal principal, UUID id) {
        OrderRow row = db.sql("""
            select o.*,b.name branch_name,u.first_name||' '||u.last_name customer_name
            from orders o join branches b on b.id=o.branch_id join users u on u.id=o.customer_id
            where o.id=:id and o.tenant_id=:tenant
            """).param("id", id).param("tenant", principal.tenantId()).query(this::row).optional()
            .orElseThrow(() -> notFound("Pedido no encontrado"));
        access(principal, row.merchantId(), row.branchId());
        return db.sql("""
            select da.phone,da.address_line,da.district,o.notes from orders o
            join delivery_addresses da on da.id=o.delivery_address_id
            where o.id=:id and o.tenant_id=:tenant
            """).param("id", id).param("tenant", principal.tenantId()).query((rs, n) -> new OrderDetail(row,
                rs.getString("phone"), rs.getString("address_line"), rs.getString("district"), rs.getString("notes"), items(principal, id))).single();
    }

    public Report report(IdentityPrincipal principal, UUID merchantId, UUID branchId, int days) {
        access(principal, merchantId, branchId);
        Timestamp since = reportSince(days, Instant.now());
        String where = " from orders where tenant_id=:tenant and merchant_id=:merchant and (cast(:branch as uuid) is null or branch_id=:branch) and created_at>=:since ";
        Object[] summary = db.sql("select count(*),count(*) filter(where status='DELIVERED'),count(*) filter(where status in('CANCELLED','REJECTED')),coalesce(sum(total) filter(where status not in('CANCELLED','REJECTED')),0),coalesce(avg(total) filter(where status not in('CANCELLED','REJECTED')),0)" + where)
            .param("tenant", principal.tenantId()).param("merchant", merchantId).param("branch", branchId).param("since", since)
            .query((rs,n) -> new Object[]{rs.getLong(1),rs.getLong(2),rs.getLong(3),rs.getBigDecimal(4),rs.getBigDecimal(5)}).single();
        List<StatusMetric> statuses = db.sql("select status,count(*),coalesce(sum(total),0)" + where + " group by status order by count(*) desc")
            .param("tenant", principal.tenantId()).param("merchant", merchantId).param("branch", branchId).param("since", since)
            .query((rs,n) -> new StatusMetric(rs.getString(1),rs.getLong(2),rs.getBigDecimal(3))).list();
        List<DailyMetric> daily = db.sql("select to_char(created_at at time zone 'America/Lima','YYYY-MM-DD'),count(*),coalesce(sum(total) filter(where status not in('CANCELLED','REJECTED')),0)" + where + " group by 1 order by 1")
            .param("tenant", principal.tenantId()).param("merchant", merchantId).param("branch", branchId).param("since", since)
            .query((rs,n) -> new DailyMetric(rs.getString(1),rs.getLong(2),rs.getBigDecimal(3))).list();
        return new Report((long)summary[0],(long)summary[1],(long)summary[2],(BigDecimal)summary[3],(BigDecimal)summary[4],statuses,daily);
    }

    static Timestamp reportSince(int days, Instant now) {
        int safeDays = Math.min(Math.max(days, 1), 365);
        return Timestamp.from(now.minusSeconds(safeDays * 86_400L));
    }

    @Transactional
    public OrderDetail transition(IdentityPrincipal principal, UUID id, String requested, int expectedVersion, String reason) {
        OrderDetail current = order(principal, id);
        String next = requested.toUpperCase(Locale.ROOT);
        validateTransition(current.order.status, next);
        if ("REJECTED".equals(next) && (reason == null || reason.isBlank()))
            throw new ApiException(HttpStatus.BAD_REQUEST, "REJECTION_REASON_REQUIRED", "Indica el motivo del rechazo");
        int changed = db.sql("""
            update orders set status=:status,version=version+1,updated_at=now(),
              accepted_at=case when :status='CONFIRMED' then now() else accepted_at end,
              ready_at=case when :status='READY' then now() else ready_at end,
              rejection_reason=case when :status='REJECTED' then :reason else rejection_reason end
            where id=:id and tenant_id=:tenant and version=:version
            """).param("status", next).param("reason", clean(reason)).param("id", id)
            .param("tenant", principal.tenantId()).param("version", expectedVersion).update();
        if (changed == 0) throw new ApiException(HttpStatus.CONFLICT, "ORDER_VERSION_CONFLICT", "El pedido cambió; actualiza la pantalla e inténtalo nuevamente");
        db.sql("insert into order_status_history(tenant_id,order_id,status,notes,changed_by) values(:tenant,:id,:status,:notes,:user)")
            .param("tenant", principal.tenantId()).param("id", id).param("status", next).param("notes", clean(reason))
            .param("user", principal.userId()).update();
        OrderDetail updated = order(principal, id);
        realtime.tenant(principal.tenantId(), "merchant/" + current.order.merchantId(), "ORDER_UPDATED", updated.order);
        realtime.tenant(principal.tenantId(), "customers", "ORDER_UPDATED", updated.order);
        return updated;
    }

    @Transactional
    public Branch pause(IdentityPrincipal principal, UUID branchId, Integer minutes, String reason) {
        UUID merchantId = db.sql("select merchant_id from branches where id=:id and tenant_id=:tenant")
            .param("id", branchId).param("tenant", principal.tenantId()).query(UUID.class).optional()
            .orElseThrow(() -> notFound("Sucursal no encontrada"));
        access(principal, merchantId, branchId);
        if (minutes != null && (minutes < 1 || minutes > 1440))
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_PAUSE_DURATION", "La pausa debe durar entre 1 y 1440 minutos");
        if (minutes == null) {
            db.sql("update branches set paused_until=null,pause_reason=null,updated_at=now() where id=:id")
                .param("id", branchId).update();
        } else {
            db.sql("update branches set paused_until=now()+make_interval(mins=>:minutes),pause_reason=:reason,updated_at=now() where id=:id")
                .param("minutes", minutes).param("reason", clean(reason)).param("id", branchId).update();
        }
        return branches(principal, merchantId).stream().filter(b -> b.id().equals(branchId)).findFirst().orElseThrow();
    }

    static void validateTransition(String current, String next) {
        Map<String, Set<String>> allowed = Map.of(
            "PENDING", Set.of("CONFIRMED", "REJECTED", "CANCELLED"),
            "CONFIRMED", Set.of("PREPARING", "CANCELLED"),
            "PREPARING", Set.of("READY", "CANCELLED"),
            "READY", Set.of("PICKED_UP", "DELIVERED"),
            "PICKED_UP", Set.of("ON_THE_WAY", "DELIVERED"),
            "ON_THE_WAY", Set.of("DELIVERED")
        );
        if (!allowed.getOrDefault(current, Set.of()).contains(next))
            throw new ApiException(HttpStatus.CONFLICT, "INVALID_ORDER_TRANSITION", "No se puede cambiar el pedido de " + current + " a " + next);
    }

    private List<Branch> branches(IdentityPrincipal p, UUID merchantId) {
        return db.sql("""
            select b.id,b.name,b.status,b.paused_until,b.pause_reason from branches b
            left join merchant_memberships mm on mm.merchant_id=b.merchant_id and mm.user_id=:user and mm.active
            left join merchant_branch_assignments mba on mba.membership_id=mm.id and mba.branch_id=b.id
            where b.tenant_id=:tenant and b.merchant_id=:merchant and (:admin or mba.branch_id is not null)
            order by b.name
            """).param("user", p.userId()).param("tenant", p.tenantId()).param("merchant", merchantId)
            .param("admin", admin(p)).query((rs, n) -> new Branch(rs.getObject("id", UUID.class), rs.getString("name"),
                rs.getString("status"), instant(rs, "paused_until"), rs.getString("pause_reason"))).list();
    }

    void access(IdentityPrincipal p, UUID merchantId, UUID branchId) {
        if (admin(p)) {
            int count = db.sql("select count(*) from merchants where id=:merchant and tenant_id=:tenant")
                .param("merchant", merchantId).param("tenant", p.tenantId()).query(Integer.class).single();
            if (count == 0) throw notFound("Comercio no encontrado");
            if (branchId != null && db.sql("select count(*) from branches where id=:branch and merchant_id=:merchant and tenant_id=:tenant")
                .param("branch", branchId).param("merchant", merchantId).param("tenant", p.tenantId()).query(Integer.class).single() == 0)
                throw notFound("Sucursal no encontrada");
            return;
        }
        int count = db.sql("""
            select count(*) from merchant_memberships mm
            left join merchant_branch_assignments mba on mba.membership_id=mm.id
            where mm.tenant_id=:tenant and mm.user_id=:user and mm.merchant_id=:merchant and mm.active
              and (:branch is null or mba.branch_id=:branch)
            """).param("tenant", p.tenantId()).param("user", p.userId()).param("merchant", merchantId)
            .param("branch", branchId).query(Integer.class).single();
        if (count == 0) throw notFound("Comercio o sucursal no asignada");
    }

    private JdbcClient.StatementSpec query(String where, IdentityPrincipal p, UUID merchant, UUID branch, String status, String search, String sql) {
        return db.sql(sql).param("tenant", p.tenantId()).param("merchant", merchant).param("branch", branch)
            .param("status", status).param("search", search);
    }

    private List<OrderItem> items(IdentityPrincipal p, UUID orderId) {
        return db.sql("select product_name,quantity,unit_price,subtotal,notes from order_items where tenant_id=:tenant and order_id=:id order by product_name")
            .param("tenant", p.tenantId()).param("id", orderId).query((rs, n) -> new OrderItem(rs.getString(1), rs.getInt(2),
                rs.getBigDecimal(3), rs.getBigDecimal(4), rs.getString(5))).list();
    }

    private OrderRow row(ResultSet rs, int n) throws SQLException {
        return new OrderRow(rs.getObject("id", UUID.class), rs.getString("order_number"), rs.getObject("merchant_id", UUID.class),
            rs.getObject("branch_id", UUID.class), rs.getString("branch_name"), rs.getString("customer_name"), effectiveStatus(rs),
            rs.getString("payment_status"), rs.getBigDecimal("total"), rs.getString("currency"), rs.getInt("version"),
            instant(rs, "created_at"), instant(rs, "updated_at"),
            column(rs,"delivery_status"),column(rs,"courier_name"),column(rs,"payment_method"));
    }

    private Instant instant(ResultSet rs, String column) throws SQLException {
        OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
        return value == null ? null : value.toInstant();
    }

    private String column(ResultSet rs,String name){try{return rs.getString(name);}catch(SQLException ignored){return null;}}
    private String effectiveStatus(ResultSet rs)throws SQLException{String value=column(rs,"effective_status");return value==null?rs.getString("status"):value;}

    private boolean admin(IdentityPrincipal p) { return p.roles().contains("TENANT_ADMIN") || p.roles().contains("PLATFORM_ADMIN"); }
    private String clean(String value) { return value == null || value.isBlank() ? null : value.trim(); }
    private ApiException notFound(String message) { return new ApiException(HttpStatus.NOT_FOUND, "MERCHANT_RESOURCE_NOT_FOUND", message); }
}
