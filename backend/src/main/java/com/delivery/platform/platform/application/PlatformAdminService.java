package com.delivery.platform.platform.application;

import com.delivery.platform.common.PageResponse;
import com.delivery.platform.identity.security.IdentityPrincipal;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class PlatformAdminService {
    private final JdbcClient db;

    public PlatformAdminService(JdbcClient db) { this.db = db; }

    public record Overview(long tenants,long merchants,long branches,long customers,long couriers,long orders,
                           long activeOrders,BigDecimal grossSales,BigDecimal refunds) {}
    public record GlobalOrder(UUID id,String orderNumber,Instant createdAt,String status,String customer,
                              String tenant,String merchant,String branch,String courier,String paymentMethod,
                              BigDecimal total,BigDecimal commission,String paymentStatus,Integer preparationMinutes,
                              Integer deliveryMinutes,String origin,String notes,String city,String zone) {}
    public record MerchantRow(UUID id,String tenant,String name,String status,BigDecimal sales,long orders,long branches,
                              long users,long products,Instant lastAccess,String operationalStatus) {}
    public record CustomerRow(UUID id,String tenant,String name,String email,String status,long orders,
                              BigDecimal spent,Instant lastOrder,Instant lastAccess) {}
    public record CourierRow(UUID id,String tenant,String name,String status,String vehicle,String zone,
                             int activeOrders,long completedOrders,BigDecimal rating,Instant lastConnection) {}
    public record Setting(String key,String value,String category,String description,boolean sensitive,Instant updatedAt) {}
    public record TransactionRow(UUID id,String tenant,String merchant,String orderNumber,String type,
                                 BigDecimal amount,String currency,String status,Instant createdAt) {}
    public record TenantRow(UUID id,String code,String name,String status,long merchants,long branches,long users) {}
    public record BranchRow(UUID id,String tenant,String merchant,String name,String status,String city) {}
    public record RoleRow(UUID id,String tenant,String code,String name,boolean active,long permissions) {}
    public record PermissionRow(UUID id,String code,String module,String action,String description) {}
    public record AuditRow(UUID id,String tenant,String user,String action,String entityType,Instant createdAt) {}

    public Overview overview() {
        return db.sql("""
            select (select count(*) from tenants where code<>'platform'),
                   (select count(*) from merchants),(select count(*) from branches),
                   (select count(distinct customer_id) from orders),(select count(*) from courier_profiles),
                   (select count(*) from orders),
                   (select count(*) from orders where status not in('DELIVERED','CANCELLED','REJECTED')),
                   (select coalesce(sum(captured_amount-refunded_amount),0) from payments),
                   (select coalesce(sum(amount),0) from payment_refunds where status='PROCESSED')
            """).query((r,n)->new Overview(r.getLong(1),r.getLong(2),r.getLong(3),r.getLong(4),r.getLong(5),
                    r.getLong(6),r.getLong(7),r.getBigDecimal(8),r.getBigDecimal(9))).single();
    }

    public PageResponse<GlobalOrder> orders(UUID merchant,UUID branch,UUID customer,UUID courier,String status,
                                             String payment,String from,String to,String city,String zone,int page,int size) {
        int limit=Math.min(Math.max(size,1),100),current=Math.max(page,0);
        String where="""
            from orders o join tenants t on t.id=o.tenant_id join users cu on cu.id=o.customer_id
            join merchants m on m.id=o.merchant_id join branches b on b.id=o.branch_id
            left join deliveries d on d.order_id=o.id and d.tenant_id=o.tenant_id
            left join courier_profiles cp on cp.id=d.courier_id left join users co on co.id=cp.user_id
            left join delivery_addresses a on a.id=o.delivery_address_id
            left join delivery_zones z on z.tenant_id=o.tenant_id and z.merchant_id=o.merchant_id and (z.branch_id is null or z.branch_id=o.branch_id) and z.active
            left join lateral(select payment_method from payments p where p.order_id=o.id order by p.created_at desc limit 1) pay on true
            where (cast(:merchant as uuid) is null or o.merchant_id=:merchant)
              and (cast(:branch as uuid) is null or o.branch_id=:branch)
              and (cast(:customer as uuid) is null or o.customer_id=:customer)
              and (cast(:courier as uuid) is null or d.courier_id=:courier)
              and (cast(:status as varchar) is null or o.status=:status)
              and (cast(:payment as varchar) is null or o.payment_status=:payment)
              and (cast(:fromDate as varchar) is null or o.created_at>=cast(:fromDate as date))
              and (cast(:toDate as varchar) is null or o.created_at<cast(:toDate as date)+interval '1 day')
              and (:city='' or lower(coalesce(a.province,a.district,'')) like lower('%'||:city||'%'))
              and (:zone='' or lower(coalesce(z.name,'')) like lower('%'||:zone||'%'))
            """;
        String select="""
            select distinct o.id,o.order_number,o.created_at,o.status,cu.first_name||' '||cu.last_name customer,
              t.name tenant,m.name merchant,b.name branch,co.first_name||' '||co.last_name courier,pay.payment_method,
              o.total,o.total*(select setting_value::numeric/100 from platform_settings where setting_key='commission.default.percent') commission,
              o.payment_status,b.preparation_time_minutes,d.estimated_duration_minutes,'APP' origin,o.notes,
              coalesce(a.province,a.district) city,z.name zone
            """;
        var spec=params(db.sql(select+where+" order by o.created_at desc limit :limit offset :offset"),merchant,branch,customer,courier,status,payment,from,to,city,zone)
                .param("limit",limit).param("offset",current*limit);
        List<GlobalOrder> rows=spec.query((r,n)->new GlobalOrder(r.getObject(1,UUID.class),r.getString(2),r.getTimestamp(3).toInstant(),r.getString(4),r.getString(5),r.getString(6),r.getString(7),r.getString(8),r.getString(9),r.getString(10),r.getBigDecimal(11),r.getBigDecimal(12),r.getString(13),(Integer)r.getObject(14),(Integer)r.getObject(15),r.getString(16),r.getString(17),r.getString(18),r.getString(19))).list();
        long total=params(db.sql("select count(distinct o.id) "+where),merchant,branch,customer,courier,status,payment,from,to,city,zone).query(Long.class).single();
        return PageResponse.of(rows,current,limit,total);
    }

    private JdbcClient.StatementSpec params(JdbcClient.StatementSpec s,UUID merchant,UUID branch,UUID customer,UUID courier,String status,String payment,String from,String to,String city,String zone){
        return s.param("merchant",merchant).param("branch",branch).param("customer",customer).param("courier",courier)
                .param("status",blank(status)).param("payment",blank(payment)).param("fromDate",blank(from)).param("toDate",blank(to))
                .param("city",city==null?"":city.trim()).param("zone",zone==null?"":zone.trim());
    }

    public List<MerchantRow> merchants(){return db.sql("""
        select m.id,t.name,m.name,m.status,coalesce(fin.sales,0),coalesce(fin.orders,0),
          coalesce(branches.total,0),coalesce(members.total,0),coalesce(products.total,0),members.last_access,
          case when branches.active>0 then 'OPERATIVE' else 'CLOSED' end
        from merchants m join tenants t on t.id=m.tenant_id
        left join lateral(select coalesce(sum(p.captured_amount-p.refunded_amount),0) sales,count(distinct o.id) orders from orders o left join payments p on p.order_id=o.id where o.merchant_id=m.id) fin on true
        left join lateral(select count(*) total,count(*) filter(where status='ACTIVE') active from branches where merchant_id=m.id) branches on true
        left join lateral(select count(distinct mm.user_id) total,max(u.last_login_at) last_access from merchant_memberships mm join users u on u.id=mm.user_id where mm.merchant_id=m.id and mm.active) members on true
        left join lateral(select count(*) total from products where merchant_id=m.id) products on true
        order by m.created_at desc
        """).query((r,n)->new MerchantRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getBigDecimal(5),r.getLong(6),r.getLong(7),r.getLong(8),r.getLong(9),r.getTimestamp(10)==null?null:r.getTimestamp(10).toInstant(),r.getString(11))).list();}

    public List<CustomerRow> customers(){return db.sql("""
        select u.id,t.name,u.first_name||' '||u.last_name,u.email,u.status,count(o.id),coalesce(sum(o.total),0),max(o.created_at),u.last_login_at
        from users u join tenants t on t.id=u.tenant_id join user_roles ur on ur.user_id=u.id join roles r on r.id=ur.role_id and r.code='CUSTOMER'
        left join orders o on o.customer_id=u.id group by u.id,t.name order by u.created_at desc
        """).query((r,n)->new CustomerRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getLong(6),r.getBigDecimal(7),r.getTimestamp(8)==null?null:r.getTimestamp(8).toInstant(),r.getTimestamp(9)==null?null:r.getTimestamp(9).toInstant())).list();}

    public List<CourierRow> couriers(){return db.sql("""
        select c.id,t.name,u.first_name||' '||u.last_name,coalesce(a.status,c.status),c.vehicle_type,z.name,
          c.current_active_deliveries,count(d.id) filter(where d.status='DELIVERED'),coalesce(avg(rt.score),0),greatest(a.updated_at,max(cl.received_at))
        from courier_profiles c join tenants t on t.id=c.tenant_id join users u on u.id=c.user_id
        left join courier_availability a on a.courier_id=c.id left join delivery_zones z on z.id=a.zone_id
        left join deliveries d on d.courier_id=c.id left join order_ratings rt on rt.order_id=d.order_id
        left join courier_locations cl on cl.courier_id=c.id group by c.id,t.name,u.first_name,u.last_name,a.status,a.updated_at,z.name order by u.first_name
        """).query((r,n)->new CourierRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getString(6),r.getInt(7),r.getLong(8),r.getBigDecimal(9),r.getTimestamp(10)==null?null:r.getTimestamp(10).toInstant())).list();}

    public List<Setting> settings(){return db.sql("select * from platform_settings order by category,setting_key").query((r,n)->new Setting(r.getString("setting_key"),r.getString("setting_value"),r.getString("category"),r.getString("description"),r.getBoolean("sensitive"),r.getTimestamp("updated_at").toInstant())).list();}

    @Transactional public Setting setting(IdentityPrincipal p,String key,String value){db.sql("update platform_settings set setting_value=:value,updated_by=:user,updated_at=now() where setting_key=:key").param("value",value.trim()).param("user",p.userId()).param("key",key).update();db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,metadata) values(:tenant,:user,'PLATFORM_SETTING_UPDATED','PLATFORM_SETTING',jsonb_build_object('key',:key))").param("tenant",p.tenantId()).param("user",p.userId()).param("key",key).update();return settings().stream().filter(x->x.key().equals(key)).findFirst().orElseThrow();}

    public List<TransactionRow> transactions(){return db.sql("""
        select pt.id,t.name,m.name,o.order_number,pt.transaction_type,pt.amount,pt.currency,pt.status,pt.created_at
        from payment_transactions pt join tenants t on t.id=pt.tenant_id join payments p on p.id=pt.payment_id
        join merchants m on m.id=p.merchant_id join orders o on o.id=p.order_id order by pt.created_at desc limit 500
        """).query((r,n)->new TransactionRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getBigDecimal(6),r.getString(7),r.getString(8),r.getTimestamp(9).toInstant())).list();}

    public List<TenantRow> tenants(){return db.sql("""
        select t.id,t.code,t.name,t.status,count(distinct m.id),count(distinct b.id),count(distinct u.id)
        from tenants t left join merchants m on m.tenant_id=t.id left join branches b on b.tenant_id=t.id
        left join users u on u.tenant_id=t.id where t.code<>'platform' group by t.id order by t.name
        """).query((r,n)->new TenantRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getLong(5),r.getLong(6),r.getLong(7))).list();}
    public List<BranchRow> branches(){return db.sql("""
        select b.id,t.name,m.name,b.name,b.status,coalesce(b.province,b.district) from branches b join tenants t on t.id=b.tenant_id
        join merchants m on m.id=b.merchant_id order by t.name,m.name,b.name
        """).query((r,n)->new BranchRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getString(6))).list();}
    public List<RoleRow> roles(){return db.sql("""
        select r.id,coalesce(t.name,'GLOBAL'),r.code,r.name,r.active,count(rp.permission_id) from roles r
        left join tenants t on t.id=r.tenant_id left join role_permissions rp on rp.role_id=r.id group by r.id,t.name order by t.name nulls first,r.name
        """).query((r,n)->new RoleRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getBoolean(5),r.getLong(6))).list();}
    public List<PermissionRow> permissions(){return db.sql("select id,code,module,action,description from permissions order by module,code").query((r,n)->new PermissionRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5))).list();}
    public List<AuditRow> audit(){return db.sql("""
        select a.id,coalesce(t.name,'GLOBAL'),coalesce(u.email,'SYSTEM'),a.action,a.entity_type,a.created_at
        from audit_logs a left join tenants t on t.id=a.tenant_id left join users u on u.id=a.user_id order by a.created_at desc limit 500
        """).query((r,n)->new AuditRow(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),r.getString(5),r.getTimestamp(6).toInstant())).list();}

    private String blank(String value){return value==null||value.isBlank()?null:value.trim();}
}
