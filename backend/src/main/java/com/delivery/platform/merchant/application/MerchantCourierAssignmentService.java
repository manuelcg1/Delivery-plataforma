package com.delivery.platform.merchant.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.common.PageResponse;
import com.delivery.platform.delivery.application.CourierAssignmentStrategy;
import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.realtime.RealtimeGateway;
import com.delivery.platform.tracking.application.CourierNotificationService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class MerchantCourierAssignmentService {
    public static final String NOT_ACCEPTED = "Pedido no aceptado por el repartidor.";
    private static final Logger log = LoggerFactory.getLogger(MerchantCourierAssignmentService.class);

    public record AvailableCourier(UUID id,String code,String name,String vehicleType,String partialPlate,
                                   String status,BigDecimal distanceKm,int activeOrders,Instant lastConnection) {}
    public record AssignmentInfo(UUID deliveryId,UUID assignmentId,String assignmentStatus,String message,
                                 UUID courierId,String courierName,String vehicleType,String courierStatus,
                                 Instant assignedAt,Instant expiresAt,BigDecimal latitude,BigDecimal longitude,
                                 Instant lastLocationAt,BigDecimal customerLatitude,BigDecimal customerLongitude) {}

    private final JdbcClient db;
    private final CourierAssignmentStrategy assignmentStrategy;
    private final MerchantPortalService portal;
    private final RealtimeGateway realtime;
    private final CourierNotificationService courierNotifications;
    private final int timeoutSeconds;

    public MerchantCourierAssignmentService(JdbcClient db,CourierAssignmentStrategy assignmentStrategy,
            MerchantPortalService portal,RealtimeGateway realtime,CourierNotificationService courierNotifications,
            @Value("${merchant.courier-assignment-timeout-seconds:300}") int timeoutSeconds) {
        this.db=db;this.assignmentStrategy=assignmentStrategy;this.portal=portal;this.realtime=realtime;this.courierNotifications=courierNotifications;
        this.timeoutSeconds=Math.max(10,timeoutSeconds);
    }

    public AssignmentInfo info(IdentityPrincipal p,UUID orderId) {
        var scope=scope(p,orderId);
        return db.sql("""
            select d.id delivery_id,da.id assignment_id,da.status assignment_status,da.result_message,
              c.id courier_id,u.first_name||' '||u.last_name courier_name,c.vehicle_type,
              coalesce(ca.status,c.status) courier_status,da.assigned_at,da.expires_at,
              cl.latitude,cl.longitude,cl.received_at,
              coalesce(o.delivery_latitude,address.latitude) customer_latitude,
              coalesce(o.delivery_longitude,address.longitude) customer_longitude
            from deliveries d join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
            left join delivery_addresses address on address.id=d.delivery_address_id and address.tenant_id=d.tenant_id
            left join lateral(select * from delivery_assignments x where x.delivery_id=d.id
              and x.tenant_id=d.tenant_id order by x.assigned_at desc limit 1) da on true
            left join courier_profiles c on c.id=coalesce(da.courier_id,d.courier_id)
            left join users u on u.id=c.user_id left join courier_availability ca on ca.courier_id=c.id
            left join courier_locations cl on cl.courier_id=c.id
            where d.id=:delivery and d.tenant_id=:tenant
            """).param("delivery",scope.deliveryId()).param("tenant",p.tenantId()).query((r,n)->new AssignmentInfo(
                r.getObject("delivery_id",UUID.class),r.getObject("assignment_id",UUID.class),r.getString("assignment_status"),
                r.getString("result_message"),r.getObject("courier_id",UUID.class),r.getString("courier_name"),
                r.getString("vehicle_type"),r.getString("courier_status"),instant(r,"assigned_at"),instant(r,"expires_at"),
                r.getBigDecimal("latitude"),r.getBigDecimal("longitude"),instant(r,"received_at"),
                r.getBigDecimal("customer_latitude"),r.getBigDecimal("customer_longitude"))).single();
    }

    public PageResponse<AvailableCourier> available(IdentityPrincipal p,UUID orderId,String search,int page,int size) {
        var s=scope(p,orderId);int pg=Math.max(0,page),z=Math.min(100,Math.max(1,size));String q=search==null?"":search.trim();
        String where="""
          from courier_profiles c join users u on u.id=c.user_id join courier_availability a on a.courier_id=c.id
          left join courier_locations l on l.courier_id=c.id
          where c.tenant_id=:tenant and c.status='ACTIVE' and a.status='ONLINE'
            and c.current_active_deliveries<c.max_active_deliveries
            and (a.branch_id is null or a.branch_id=:branch)
            and (:search='' or lower(u.first_name||' '||u.last_name||' '||coalesce(c.vehicle_plate,'')||' '||c.vehicle_type||' '||c.id::text) like lower('%'||:search||'%'))
          """;
        var rows=db.sql("select c.id,c.id::text code,u.first_name||' '||u.last_name name,c.vehicle_type,c.vehicle_plate,a.status,c.current_active_deliveries,a.updated_at "+where+" order by a.updated_at desc limit :size offset :offset")
            .param("tenant",p.tenantId()).param("branch",s.branchId()).param("search",q).param("size",z).param("offset",pg*z)
            .query((r,n)->new AvailableCourier(r.getObject(1,UUID.class),r.getString(2),r.getString(3),r.getString(4),plate(r.getString(5)),r.getString(6),null,r.getInt(7),instant(r,8))).list();
        long total=db.sql("select count(*) "+where).param("tenant",p.tenantId()).param("branch",s.branchId()).param("search",q).query(Long.class).single();
        return PageResponse.of(rows,pg,z,total);
    }

    @Transactional public AssignmentInfo autoAssign(IdentityPrincipal p,UUID orderId) {
        var s=scope(p,orderId);UUID courier=assignmentStrategy.select(p.tenantId(),s.branchId(),null)
            .orElseThrow(()->new ApiException(HttpStatus.CONFLICT,"COURIER_NOT_AVAILABLE","No se encontraron repartidores disponibles."));
        return assign(p,s,courier,"AUTOMATIC",UUID.randomUUID().toString(),true);
    }

    @Transactional public AssignmentInfo manualAssign(IdentityPrincipal p,UUID orderId,UUID courier) {
        return assign(p,scope(p,orderId),courier,"MANUAL",UUID.randomUUID().toString(),true);
    }

    /** Compatibility entry point for the existing delivery assignment REST API. */
    @Transactional public void assignDelivery(IdentityPrincipal p,UUID deliveryId,UUID courier,String type,String idempotencyKey) {
        if(idempotencyKey==null||idempotencyKey.isBlank())
            throw new ApiException(HttpStatus.BAD_REQUEST,"IDEMPOTENCY_KEY_REQUIRED","Envía Idempotency-Key");
        Scope s=scopeByDelivery(p,deliveryId);
        if(s.courierId()!=null)return;
        if(courier==null) courier=assignmentStrategy.select(p.tenantId(),s.branchId(),null)
            .orElseThrow(()->conflict("COURIER_NOT_AVAILABLE","No hay repartidores disponibles"));
        assign(p,s,courier,type,idempotencyKey,false);
    }

    private AssignmentInfo assign(IdentityPrincipal p,Scope s,UUID courier,String type,String idempotencyKey,boolean requireReady) {
        if(requireReady&&!isAssignableOrderStatus(s.orderStatus()))
            throw conflict("ORDER_NOT_ASSIGNABLE","El pedido no está listo para asignar.");
        int active=db.sql("select count(*) from delivery_assignments where tenant_id=:tenant and delivery_id=:delivery and status='PENDING'")
            .param("tenant",p.tenantId()).param("delivery",s.deliveryId()).query(Integer.class).single();
        if(active>0)throw conflict("ORDER_ALREADY_ASSIGNED","El pedido ya fue asignado por otro usuario.");
        UUID courierUser=db.sql("""
            select c.user_id from courier_profiles c join courier_availability a on a.courier_id=c.id
            where c.id=:courier and c.tenant_id=:tenant and c.status='ACTIVE' and a.status='ONLINE'
              and c.current_active_deliveries<c.max_active_deliveries and (a.branch_id is null or a.branch_id=:branch)
            """).param("courier",courier).param("tenant",p.tenantId()).param("branch",s.branchId()).query(UUID.class).optional()
            .orElseThrow(()->conflict("COURIER_NOT_AVAILABLE","Repartidor no disponible."));
        UUID assignmentId=UUID.randomUUID();
        db.sql("""
            insert into delivery_assignments(id,tenant_id,delivery_id,courier_id,status,assignment_type,assigned_by,
              idempotency_key,expires_at,previous_order_status,result_message)
            values(:id,:tenant,:delivery,:courier,'PENDING',:type,:user,:key,
              now()+make_interval(secs=>:timeout),:previous,'Pedido enviado al repartidor. Esperando aceptación.')
            """).param("id",assignmentId).param("tenant",p.tenantId()).param("delivery",s.deliveryId())
            .param("courier",courier).param("type",type).param("user",p.userId()).param("key",idempotencyKey)
            .param("timeout",timeoutSeconds).param("previous",s.orderStatus()).update();
        db.sql("update deliveries set courier_id=:courier,status='ASSIGNED',assigned_at=now(),version=version+1,updated_at=now() where id=:delivery and tenant_id=:tenant")
            .param("courier",courier).param("delivery",s.deliveryId()).param("tenant",p.tenantId()).update();
        db.sql("insert into delivery_status_history(tenant_id,delivery_id,status,actor_id,actor_type,notes,old_status,correlation_id) values(:tenant,:delivery,'ASSIGNED',:user,'USER','Pedido asignado al repartidor.', 'PENDING',:correlation)")
            .param("tenant",p.tenantId()).param("delivery",s.deliveryId()).param("user",p.userId())
            .param("correlation",assignmentId.toString()).update();
        db.sql("update courier_profiles set current_active_deliveries=current_active_deliveries+1 where id=:courier and tenant_id=:tenant")
            .param("courier",courier).param("tenant",p.tenantId()).update();
        Map<String,Object> assignmentPayload=assignmentPayload(p.tenantId(),s.orderId(),s.deliveryId(),assignmentId);
        log.info("Courier assigned tenant={} order={} delivery={} courier={} assignment={}",p.tenantId(),s.orderId(),s.deliveryId(),courier,assignmentId);
        log.info("Publishing NEW_DELIVERY_ASSIGNMENT tenant={} delivery={} assignment={}",p.tenantId(),s.deliveryId(),assignmentId);
        courierNotifications.assignment(p.tenantId(),courierUser,assignmentPayload);
        realtime.tenant(p.tenantId(),"customers","ORDER_UPDATED",
            Map.of("orderId",s.orderId(),"deliveryId",s.deliveryId(),"status","ASSIGNED"));
        realtime.delivery(p.tenantId(),s.deliveryId(),"CourierAssigned",
            Map.of("orderId",s.orderId(),"deliveryId",s.deliveryId(),"status","ASSIGNED"));
        audit(p,s,"COURIER_ASSIGNMENT_PENDING",type,courier,s.orderStatus(),s.orderStatus(),"PENDING");
        event(p.tenantId(),s,"COURIER_ASSIGNMENT_PENDING");
        return info(p,s.orderId());
    }

    @Transactional public AssignmentInfo handToCourier(IdentityPrincipal p,UUID orderId) {
        Scope s=scope(p,orderId);
        int changed=db.sql("""
            update deliveries d set status='PICKED_UP',picked_up_at=now(),version=version+1,updated_at=now()
            where d.id=:delivery and d.tenant_id=:tenant and d.courier_id is not null
              and d.status in('ACCEPTED','ARRIVED_AT_MERCHANT') and exists(select 1 from delivery_assignments a
                where a.delivery_id=d.id and a.tenant_id=d.tenant_id and a.status='ACCEPTED')
            """).param("delivery",s.deliveryId()).param("tenant",p.tenantId()).update();
        if(changed==0)throw conflict("ORDER_HANDOFF_NOT_ALLOWED","El repartidor aún no aceptó o el pedido no está listo.");
        db.sql("update orders set status='PICKED_UP',version=version+1,updated_at=now() where id=:order and tenant_id=:tenant and status='READY'")
            .param("order",orderId).param("tenant",p.tenantId()).update();
        db.sql("insert into order_status_history(tenant_id,order_id,status,notes,changed_by) values(:tenant,:order,'PICKED_UP','Pedido entregado al repartidor.',:user)")
            .param("tenant",p.tenantId()).param("order",orderId).param("user",p.userId()).update();
        audit(p,s,"ORDER_HANDED_TO_COURIER","MANUAL",null,s.orderStatus(),"PICKED_UP","SUCCESS");
        event(p.tenantId(),s,"ORDER_HANDED_TO_COURIER");
        realtime.delivery(p.tenantId(),s.deliveryId(),"OrderPickedUp",
            Map.of("orderId",s.orderId(),"deliveryId",s.deliveryId(),"status","PICKED_UP"));
        return info(p,orderId);
    }

    @Scheduled(fixedDelay=10000)
    @Transactional public void reconcileAssignments() {
        List<UUID> expired=db.sql("select id from delivery_assignments where status='PENDING' and expires_at<=now() for update skip locked").query(UUID.class).list();
        expired.forEach(id->restore(id,"EXPIRED"));
        List<UUID> rejected=db.sql("select id from delivery_assignments where status='REJECTED' and result_message is distinct from :message for update skip locked").param("message",NOT_ACCEPTED).query(UUID.class).list();
        rejected.forEach(id->restore(id,"REJECTED"));
    }

    private void restore(UUID assignmentId,String result) {
        Object[] a=db.sql("""
            select a.tenant_id,a.delivery_id,a.courier_id,a.previous_order_status,d.order_id,a.assigned_by
            from delivery_assignments a join deliveries d on d.id=a.delivery_id where a.id=:id
            """).param("id",assignmentId).query((r,n)->new Object[]{r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getObject(3,UUID.class),r.getString(4),r.getObject(5,UUID.class),r.getObject(6,UUID.class)}).single();
        UUID tenant=(UUID)a[0],delivery=(UUID)a[1],courier=(UUID)a[2],order=(UUID)a[4],actor=(UUID)a[5];String previous=(String)a[3];
        db.sql("update delivery_assignments set status=:status,responded_at=coalesce(responded_at,now()),result_message=:message where id=:id")
            .param("status",result).param("message",NOT_ACCEPTED).param("id",assignmentId).update();
        db.sql("update deliveries set courier_id=null,status='PENDING',version=version+1,updated_at=now() where id=:id and tenant_id=:tenant")
            .param("id",delivery).param("tenant",tenant).update();
        db.sql("insert into delivery_status_history(tenant_id,delivery_id,status,actor_id,actor_type,notes,old_status,correlation_id) values(:tenant,:delivery,'PENDING',:user,'SYSTEM',:message,'ASSIGNED',:correlation)")
            .param("tenant",tenant).param("delivery",delivery).param("user",actor).param("message",NOT_ACCEPTED)
            .param("correlation",assignmentId.toString()).update();
        db.sql("update orders set status=:status,version=version+1,updated_at=now() where id=:id and tenant_id=:tenant")
            .param("status",previous).param("id",order).param("tenant",tenant).update();
        db.sql("update courier_profiles set current_active_deliveries=greatest(0,current_active_deliveries-1) where id=:id and tenant_id=:tenant")
            .param("id",courier).param("tenant",tenant).update();
        db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) values(:tenant,:user,:action,'DELIVERY_ASSIGNMENT',:id,jsonb_build_object('result',:result,'previousOrderStatus',:previous))")
            .param("tenant",tenant).param("user",actor).param("action","COURIER_ASSIGNMENT_"+result).param("id",assignmentId).param("result",result).param("previous",previous).update();
        realtime.tenant(tenant,"merchant","COURIER_ASSIGNMENT_"+result,Map.of("orderId",order,"message",NOT_ACCEPTED));
    }

    private Scope scope(IdentityPrincipal p,UUID orderId) {
        Scope s=findScope(p,orderId);portal.access(p,s.merchantId(),s.branchId());
        if(s.deliveryId()==null&&"READY".equals(s.orderStatus())){
            db.sql("""
                insert into deliveries(id,tenant_id,order_id,merchant_id,branch_id,customer_id,delivery_address_id,
                  address_snapshot,status,delivery_type,distance_km,estimated_duration_minutes,
                  delivery_fee,currency,delivery_notes)
                select gen_random_uuid(),o.tenant_id,o.id,o.merchant_id,o.branch_id,o.customer_id,o.delivery_address_id,
                  jsonb_build_object('addressLine',a.address_line,'district',a.district,'recipientName',a.recipient_name,'phone',a.phone),
                  'PENDING','PLATFORM_DELIVERY',o.delivery_distance_km,
                  coalesce(o.eta_maximum_minutes,b.preparation_time_minutes,30),o.delivery_fee,o.currency,o.notes
                from orders o join delivery_addresses a on a.id=o.delivery_address_id and a.tenant_id=o.tenant_id
                join branches b on b.id=o.branch_id and b.tenant_id=o.tenant_id
                where o.id=:order and o.tenant_id=:tenant and o.status='READY'
                  and not exists(select 1 from deliveries d where d.order_id=o.id and d.tenant_id=o.tenant_id
                    and d.status not in('DELIVERED','FAILED','CANCELLED','REJECTED','EXPIRED'))
                """).param("order",orderId).param("tenant",p.tenantId()).update();
            s=findScope(p,orderId);
        }
        return s;
    }
    private Scope findScope(IdentityPrincipal p,UUID orderId){return db.sql("""
        select o.id,o.merchant_id,o.branch_id,o.status,d.id delivery_id,d.courier_id from orders o
        left join lateral(select id,courier_id from deliveries where tenant_id=o.tenant_id and order_id=o.id
          and status not in('DELIVERED','FAILED','CANCELLED') order by created_at desc limit 1)d on true
        where o.id=:order and o.tenant_id=:tenant
        """).param("order",orderId).param("tenant",p.tenantId()).query((r,n)->new Scope(r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getObject(3,UUID.class),r.getString(4),r.getObject(5,UUID.class),r.getObject(6,UUID.class))).optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"ORDER_NOT_FOUND","Pedido no encontrado."));}
    private Scope scopeByDelivery(IdentityPrincipal p,UUID deliveryId){return db.sql("""
        select o.id,o.merchant_id,o.branch_id,o.status,d.id,d.courier_id
        from deliveries d join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
        where d.id=:delivery and d.tenant_id=:tenant
        """).param("delivery",deliveryId).param("tenant",p.tenantId()).query((r,n)->new Scope(
          r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getObject(3,UUID.class),r.getString(4),
          r.getObject(5,UUID.class),r.getObject(6,UUID.class))).optional().orElseThrow(()->
            new ApiException(HttpStatus.NOT_FOUND,"DELIVERY_NOT_FOUND","Entrega no encontrada"));}
    private Map<String,Object> assignmentPayload(UUID tenant,UUID order,UUID delivery,UUID assignment){
        return db.sql("""
          select m.name merchant_name,coalesce(u.first_name||' '||u.last_name,'Cliente') customer_name,
            coalesce(d.distance_km,0) distance_km,coalesce(d.estimated_duration_minutes,0) eta,
            o.total,o.currency,a.expires_at
          from deliveries d join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
          join merchants m on m.id=d.merchant_id and m.tenant_id=d.tenant_id
          left join users u on u.id=d.customer_id
          join delivery_assignments a on a.id=:assignment and a.tenant_id=d.tenant_id
          where d.id=:delivery and d.tenant_id=:tenant
          """).param("assignment",assignment).param("delivery",delivery).param("tenant",tenant).query((r,n)->{
            Map<String,Object> value=new HashMap<>();value.put("orderId",order);value.put("deliveryId",delivery);
            value.put("assignmentId",assignment);
            value.put("merchantName",r.getString("merchant_name"));value.put("customerName",r.getString("customer_name"));
            value.put("estimatedDistanceKm",r.getBigDecimal("distance_km"));value.put("estimatedTimeMinutes",r.getInt("eta"));
            value.put("total",r.getString("currency")+" "+r.getBigDecimal("total"));value.put("expiresAt",r.getTimestamp("expires_at").toInstant());return value;
          }).single();
    }
    private record Scope(UUID orderId,UUID merchantId,UUID branchId,String orderStatus,UUID deliveryId,UUID courierId) {}
    private void audit(IdentityPrincipal p,Scope s,String action,String type,UUID courier,String oldStatus,String newStatus,String result){db.sql("insert into audit_logs(tenant_id,user_id,action,entity_type,entity_id,metadata) values(:tenant,:user,:action,'ORDER',:order,jsonb_build_object('merchantId',:merchant,'assignmentType',:type,'courierId',:courier,'oldStatus',:old,'newStatus',:new,'result',:result))").param("tenant",p.tenantId()).param("user",p.userId()).param("action",action).param("order",s.orderId()).param("merchant",s.merchantId()).param("type",type).param("courier",courier).param("old",oldStatus).param("new",newStatus).param("result",result).update();}
    private void event(UUID tenant,Scope s,String name){realtime.tenant(tenant,"merchant/"+s.merchantId(),name,Map.of("orderId",s.orderId(),"deliveryId",s.deliveryId()));}
    private ApiException conflict(String code,String message){return new ApiException(HttpStatus.CONFLICT,code,message);}
    private static String plate(String value){return value==null||value.length()<3?value:"***"+value.substring(value.length()-3);}
    static boolean isAssignableOrderStatus(String status){return "READY".equals(status);}
    private static Instant instant(java.sql.ResultSet r,String name)throws java.sql.SQLException{var t=r.getTimestamp(name);return t==null?null:t.toInstant();}
    private static Instant instant(java.sql.ResultSet r,int index)throws java.sql.SQLException{var t=r.getTimestamp(index);return t==null?null:t.toInstant();}
}
