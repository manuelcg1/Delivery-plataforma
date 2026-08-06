package com.delivery.platform.tracking.application;

import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Timestamp;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
public class CourierArrivalDetectionService {
    private static final Logger log = LoggerFactory.getLogger(CourierArrivalDetectionService.class);
    private final JdbcClient db;
    private final ApplicationEventPublisher events;
    private final MeterRegistry metrics;
    private final double radius;
    private final int requiredPoints;
    private final long dwellSeconds;
    private final double maxAccuracy;
    private final long maxAgeSeconds;

    record Candidate(UUID orderId, UUID customerId, String status, BigDecimal latitude, BigDecimal longitude) {}
    record Point(BigDecimal latitude, BigDecimal longitude, BigDecimal accuracy, Instant gpsTimestamp) {}

    public CourierArrivalDetectionService(JdbcClient db, ApplicationEventPublisher events, MeterRegistry metrics,
            @Value("${tracking.arrival.radius-meters:100}") double radius,
            @Value("${tracking.arrival.required-points:3}") int requiredPoints,
            @Value("${tracking.arrival.dwell-seconds:20}") long dwellSeconds,
            @Value("${tracking.arrival.max-accuracy-meters:50}") double maxAccuracy,
            @Value("${tracking.arrival.max-location-age-seconds:60}") long maxAgeSeconds) {
        this.db=db; this.events=events; this.metrics=metrics; this.radius=radius;
        this.requiredPoints=requiredPoints; this.dwellSeconds=dwellSeconds;
        this.maxAccuracy=maxAccuracy; this.maxAgeSeconds=maxAgeSeconds;
    }

    @Transactional
    public boolean detect(UUID tenantId, UUID deliveryId, UUID courierId, UUID locationId,
                          BigDecimal latitude, BigDecimal longitude, BigDecimal accuracy, Instant gpsTimestamp) {
        if (!valid(latitude, longitude, accuracy, gpsTimestamp)) return false;
        Candidate candidate = candidate(tenantId, deliveryId, courierId);
        if (candidate == null || candidate.latitude()==null || candidate.longitude()==null) return false;
        double distance = meters(latitude, longitude, candidate.latitude(), candidate.longitude());
        metrics.summary("courier_arrival_detection_distance_meters").record(distance);
        if (distance > radius) return false;

        List<Point> points = db.sql("""
            select latitude,longitude,accuracy,gps_timestamp from courier_location_history
            where tenant_id=:t and delivery_id=:d and courier_id=:c
              and accuracy<=:accuracy and gps_timestamp>=now()-(:age * interval '1 second')
            order by gps_timestamp desc limit 100
            """).param("t",tenantId).param("d",deliveryId).param("c",courierId)
            .param("accuracy",maxAccuracy).param("age",Math.max(maxAgeSeconds,dwellSeconds+10))
            .query((r,n)->new Point(r.getBigDecimal(1),r.getBigDecimal(2),r.getBigDecimal(3),r.getTimestamp(4).toInstant())).list();
        int consecutive=0;
        boolean countingConsecutive=true;
        Instant enteredAt=null;
        for (Point point:points) {
            double pointDistance=meters(point.latitude(),point.longitude(),candidate.latitude(),candidate.longitude());
            if (pointDistance>radius+40) break; // hysteresis: only a clear exit resets the dwell window
            if (pointDistance<=radius) {
                if(countingConsecutive) consecutive++;
                enteredAt=point.gpsTimestamp();
            } else countingConsecutive=false;
        }
        boolean confirmed=consecutive>=requiredPoints || (enteredAt!=null && Duration.between(enteredAt,gpsTimestamp).getSeconds()>=dwellSeconds);
        if (!confirmed) return false;
        return confirm(tenantId,deliveryId,courierId,locationId,candidate,distance,"GEOFENCE");
    }

    @Transactional
    public boolean manual(IdentityPrincipal principal, UUID orderId) {
        Object[] row=db.sql("""
            select d.id,d.order_id,d.customer_id,d.courier_id,d.status from deliveries d
            join courier_profiles c on c.id=d.courier_id and c.tenant_id=d.tenant_id
            where d.tenant_id=:t and d.order_id=:o and c.user_id=:u
            order by d.created_at desc limit 1 for update of d
            """).param("t",principal.tenantId()).param("o",orderId).param("u",principal.userId())
            .query((r,n)->new Object[]{r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getObject(3,UUID.class),r.getObject(4,UUID.class),r.getString(5)})
            .optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"DELIVERY_NOT_FOUND","Entrega activa no encontrada"));
        if (!List.of("PICKED_UP","IN_TRANSIT","ARRIVED_AT_CUSTOMER").contains(row[4]))
            throw new ApiException(HttpStatus.CONFLICT,"DELIVERY_NOT_ACTIVE","La entrega no permite registrar llegada");
        Candidate candidate=new Candidate((UUID)row[1],(UUID)row[2],(String)row[4],null,null);
        return confirm(principal.tenantId(),(UUID)row[0],(UUID)row[3],null,candidate,Double.NaN,"MANUAL");
    }

    private Candidate candidate(UUID tenant,UUID delivery,UUID courier) {
        return db.sql("""
            select d.order_id,d.customer_id,d.status,o.delivery_latitude,o.delivery_longitude
            from deliveries d join orders o on o.id=d.order_id and o.tenant_id=d.tenant_id
            where d.tenant_id=:t and d.id=:d and d.courier_id=:c
              and d.status in ('PICKED_UP','IN_TRANSIT') and d.arrival_detected_at is null
            for update of d
            """).param("t",tenant).param("d",delivery).param("c",courier)
            .query((r,n)->new Candidate(r.getObject(1,UUID.class),r.getObject(2,UUID.class),r.getString(3),r.getBigDecimal(4),r.getBigDecimal(5)))
            .optional().orElse(null);
    }

    private boolean confirm(UUID tenant,UUID delivery,UUID courier,UUID location,Candidate c,double distance,String method) {
        BigDecimal meters=Double.isNaN(distance)?null:BigDecimal.valueOf(distance).setScale(2,RoundingMode.HALF_UP);
        int changed=db.sql("""
            update deliveries set status='ARRIVED_AT_CUSTOMER',arrival_detected_at=now(),arrival_distance_meters=:distance,
              arrival_method=:method,arrival_location_id=:location,version=version+1,updated_at=now()
            where tenant_id=:t and id=:d and courier_id=:c and arrival_detected_at is null
              and status in ('PICKED_UP','IN_TRANSIT')
            """).param("distance",meters).param("method",method).param("location",location)
            .param("t",tenant).param("d",delivery).param("c",courier).update();
        if(changed==0) return false;
        db.sql("insert into delivery_status_history(id,tenant_id,delivery_id,status,actor_type,notes,old_status,correlation_id) values(gen_random_uuid(),:t,:d,'ARRIVED_AT_CUSTOMER','SYSTEM',:notes,:old,:correlation)")
            .param("t",tenant).param("d",delivery).param("notes","Llegada detectada: "+method)
            .param("old",c.status()).param("correlation",UUID.randomUUID().toString()).update();
        db.sql("insert into tracking_events(tenant_id,delivery_id,courier_id,event_type,payload) values(:t,:d,:c,'CourierArrived',cast(:payload as jsonb))")
            .param("t",tenant).param("d",delivery).param("c",courier).param("payload","{\"method\":\""+method+"\"}").update();
        Instant detected=Instant.now();
        events.publishEvent(new CourierArrivalEvent(tenant,delivery,c.orderId(),c.customerId(),courier,meters,detected,method));
        metrics.counter(method.equals("MANUAL")?"courier_arrival_manual_total":"courier_arrival_detected_total").increment();
        log.info("Courier arrival deliveryId={} courierId={} distance={} method={} result=confirmed",delivery,courier,meters,method);
        return true;
    }

    private boolean valid(BigDecimal lat,BigDecimal lon,BigDecimal accuracy,Instant timestamp) {
        return lat!=null&&lon!=null&&accuracy!=null&&timestamp!=null&&lat.abs().doubleValue()<=90&&lon.abs().doubleValue()<=180
            &&accuracy.doubleValue()<=maxAccuracy&&!timestamp.isBefore(Instant.now().minusSeconds(maxAgeSeconds))
            &&!timestamp.isAfter(Instant.now().plusSeconds(30));
    }
    static double meters(BigDecimal lat1,BigDecimal lon1,BigDecimal lat2,BigDecimal lon2) {
        double p1=Math.toRadians(lat1.doubleValue()),p2=Math.toRadians(lat2.doubleValue());
        double dp=Math.toRadians(lat2.subtract(lat1).doubleValue()),dl=Math.toRadians(lon2.subtract(lon1).doubleValue());
        double a=Math.sin(dp/2)*Math.sin(dp/2)+Math.cos(p1)*Math.cos(p2)*Math.sin(dl/2)*Math.sin(dl/2);
        return 6_371_000*2*Math.atan2(Math.sqrt(a),Math.sqrt(1-a));
    }
}
