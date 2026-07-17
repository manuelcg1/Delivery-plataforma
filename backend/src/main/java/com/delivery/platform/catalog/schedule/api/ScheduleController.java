package com.delivery.platform.catalog.schedule.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;

@RestController
@RequestMapping("/api/v1/branches/{branchId}")
public class ScheduleController {
    private final JdbcClient db;
    private final CatalogSupport support;

    public ScheduleController(JdbcClient db, CatalogSupport support) {
        this.db = db;
        this.support = support;
    }

    public record BusinessHour(UUID id, @Min(1) @Max(7) int dayOfWeek, LocalTime openTime,
                               LocalTime closeTime, boolean closed, LocalTime secondOpenTime,
                               LocalTime secondCloseTime) {}
    public record SpecialHour(UUID id, @NotNull LocalDate specialDate, LocalTime openTime,
                              LocalTime closeTime, boolean closed, String reason) {}
    public record CurrentSchedule(LocalTime openTime, LocalTime closeTime) {}
    public record Availability(UUID branchId, boolean open, String status, OffsetDateTime nextOpeningAt,
                               CurrentSchedule currentSchedule) {}

    @GetMapping("/business-hours")
    @PreAuthorize("hasAuthority('CATALOG_HOURS_VIEW')")
    public List<BusinessHour> businessHours(@AuthenticationPrincipal IdentityPrincipal principal,
                                            @PathVariable UUID branchId) {
        support.branch(principal, branchId);
        return db.sql("select * from business_hours where tenant_id=:t and branch_id=:b order by day_of_week")
                .param("t", principal.tenantId()).param("b", branchId)
                .query((row, n) -> businessHour(row)).list();
    }

    @PutMapping("/business-hours")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_HOURS_MANAGE')")
    public List<BusinessHour> replaceBusinessHours(@AuthenticationPrincipal IdentityPrincipal principal,
                                                   @PathVariable UUID branchId,
                                                   @Valid @RequestBody List<BusinessHour> hours) {
        support.branch(principal, branchId);
        if (hours.size() > 7 || hours.stream().map(BusinessHour::dayOfWeek).distinct().count() != hours.size()) {
            throw invalidHours("Solo puede existir un horario por día");
        }
        hours.forEach(this::validateRanges);
        db.sql("delete from business_hours where tenant_id=:t and branch_id=:b")
                .param("t", principal.tenantId()).param("b", branchId).update();
        for (BusinessHour hour : hours) {
            db.sql("insert into business_hours(tenant_id,branch_id,day_of_week,open_time,close_time,closed,second_open_time,second_close_time) values(:t,:b,:d,:o,:c,:x,:so,:sc)")
                    .param("t", principal.tenantId()).param("b", branchId).param("d", hour.dayOfWeek())
                    .param("o", hour.openTime()).param("c", hour.closeTime()).param("x", hour.closed())
                    .param("so", hour.secondOpenTime()).param("sc", hour.secondCloseTime()).update();
        }
        support.audit(principal, "BUSINESS_HOURS_UPDATED", "BRANCH", branchId);
        return businessHours(principal, branchId);
    }

    @GetMapping("/special-hours")
    @PreAuthorize("hasAuthority('CATALOG_HOURS_VIEW')")
    public List<SpecialHour> specialHours(@AuthenticationPrincipal IdentityPrincipal principal,
                                          @PathVariable UUID branchId) {
        support.branch(principal, branchId);
        return db.sql("select * from branch_special_hours where tenant_id=:t and branch_id=:b order by special_date")
                .param("t", principal.tenantId()).param("b", branchId)
                .query((row, n) -> specialHour(row)).list();
    }

    @PostMapping("/special-hours")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_HOURS_MANAGE')")
    public SpecialHour createSpecialHour(@AuthenticationPrincipal IdentityPrincipal principal,
                                         @PathVariable UUID branchId, @Valid @RequestBody SpecialHour request) {
        support.branch(principal, branchId);
        validateSpecial(request);
        UUID id = UUID.randomUUID();
        try {
            insertSpecial(principal, branchId, id, request);
        } catch (org.springframework.dao.DataIntegrityViolationException exception) {
            throw new ApiException(HttpStatus.CONFLICT, "DUPLICATE_SPECIAL_DATE", "Ya existe un horario especial para esa fecha");
        }
        support.audit(principal, "SPECIAL_HOURS_CREATED", "BRANCH_SPECIAL_HOUR", id);
        return findSpecial(principal, branchId, id);
    }

    @PutMapping("/special-hours/{id}")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_HOURS_MANAGE')")
    public SpecialHour updateSpecialHour(@AuthenticationPrincipal IdentityPrincipal principal,
                                         @PathVariable UUID branchId, @PathVariable UUID id,
                                         @Valid @RequestBody SpecialHour request) {
        findSpecial(principal, branchId, id);
        validateSpecial(request);
        db.sql("update branch_special_hours set special_date=:d,open_time=:o,close_time=:c,closed=:x,reason=:r,updated_at=now() where id=:i and tenant_id=:t and branch_id=:b")
                .param("d", request.specialDate()).param("o", request.openTime()).param("c", request.closeTime())
                .param("x", request.closed()).param("r", request.reason()).param("i", id)
                .param("t", principal.tenantId()).param("b", branchId).update();
        support.audit(principal, "SPECIAL_HOURS_UPDATED", "BRANCH_SPECIAL_HOUR", id);
        return findSpecial(principal, branchId, id);
    }

    @DeleteMapping("/special-hours/{id}")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_HOURS_MANAGE')")
    public void deleteSpecialHour(@AuthenticationPrincipal IdentityPrincipal principal,
                                  @PathVariable UUID branchId, @PathVariable UUID id) {
        findSpecial(principal, branchId, id);
        db.sql("delete from branch_special_hours where id=:i and tenant_id=:t and branch_id=:b")
                .param("i", id).param("t", principal.tenantId()).param("b", branchId).update();
        support.audit(principal, "SPECIAL_HOURS_DELETED", "BRANCH_SPECIAL_HOUR", id);
    }

    @GetMapping("/availability")
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_VIEW')")
    public Availability availability(@AuthenticationPrincipal IdentityPrincipal principal,
                                     @PathVariable UUID branchId) {
        support.branch(principal, branchId);
        return calculateAvailability(branchId);
    }

    public Availability calculateAvailability(UUID branchId) {
        var branch = db.sql("select status,timezone from branches where id=:b")
                .param("b", branchId).query((row, n) -> new Object[]{row.getString(1), row.getString(2)})
                .optional().orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "BRANCH_NOT_FOUND", "Sucursal no encontrada"));
        String status = (String) branch[0];
        ZoneId zone;
        try { zone = ZoneId.of((String) branch[1]); }
        catch (DateTimeException exception) { throw invalidHours("La zona horaria de la sucursal no es válida"); }
        OffsetDateTime now = OffsetDateTime.now(zone);
        if ("TEMPORARILY_CLOSED".equals(status)) return new Availability(branchId, false, "TEMPORARILY_CLOSED", null, null);
        if (!"ACTIVE".equals(status)) return new Availability(branchId, false, "CLOSED", null, null);

        LocalDate date = now.toLocalDate();
        LocalTime time = now.toLocalTime();
        Optional<SpecialHour> special = db.sql("select * from branch_special_hours where branch_id=:b and special_date=:d")
                .param("b", branchId).param("d", date).query((row, n) -> specialHour(row)).optional();
        CurrentSchedule current = special.map(x -> new CurrentSchedule(x.openTime(), x.closeTime()))
                .orElseGet(() -> scheduleFor(branchId, date.getDayOfWeek().getValue()));
        boolean closed = special.map(SpecialHour::closed).orElse(false);
        boolean open = !closed && current != null && inside(time, current.openTime(), current.closeTime());
        return new Availability(branchId, open, open ? "OPEN" : "OUTSIDE_BUSINESS_HOURS",
                open ? null : nextOpening(branchId, now, zone), open ? current : null);
    }

    private OffsetDateTime nextOpening(UUID branchId, OffsetDateTime now, ZoneId zone) {
        for (int add = 0; add <= 7; add++) {
            LocalDate date = now.toLocalDate().plusDays(add);
            Optional<SpecialHour> special = db.sql("select * from branch_special_hours where branch_id=:b and special_date=:d")
                    .param("b", branchId).param("d", date).query((row, n) -> specialHour(row)).optional();
            if (special.isPresent()) {
                if (!special.get().closed() && special.get().openTime() != null) {
                    var candidate = ZonedDateTime.of(date, special.get().openTime(), zone).toOffsetDateTime();
                    if (candidate.isAfter(now)) return candidate;
                }
                continue;
            }
            CurrentSchedule schedule = scheduleFor(branchId, date.getDayOfWeek().getValue());
            if (schedule != null && schedule.openTime() != null) {
                var candidate = ZonedDateTime.of(date, schedule.openTime(), zone).toOffsetDateTime();
                if (candidate.isAfter(now)) return candidate;
            }
        }
        return null;
    }

    private CurrentSchedule scheduleFor(UUID branchId, int day) {
        return db.sql("select open_time,close_time,closed from business_hours where branch_id=:b and day_of_week=:d")
                .param("b", branchId).param("d", day).query((row, n) -> row.getBoolean("closed") ? null : new CurrentSchedule(row.getObject("open_time", LocalTime.class), row.getObject("close_time", LocalTime.class)))
                .optional().orElse(null);
    }

    private boolean inside(LocalTime now, LocalTime open, LocalTime close) {
        if (open == null || close == null) return false;
        if (close.isAfter(open)) return !now.isBefore(open) && now.isBefore(close);
        return !now.isBefore(open) || now.isBefore(close); // cruza medianoche
    }

    private void validateRanges(BusinessHour hour) {
        if (hour.closed()) return;
        if (hour.openTime() == null || hour.closeTime() == null) throw invalidHours("Indica apertura y cierre, o marca el día como cerrado");
        if ((hour.secondOpenTime() == null) != (hour.secondCloseTime() == null)) throw invalidHours("Completa ambas horas del segundo turno");
    }
    private void validateSpecial(SpecialHour hour) {
        if (!hour.closed() && (hour.openTime() == null || hour.closeTime() == null)) throw invalidHours("Indica apertura y cierre, o marca la fecha como cerrada");
    }
    private void insertSpecial(IdentityPrincipal p, UUID branchId, UUID id, SpecialHour request) {
        db.sql("insert into branch_special_hours(id,tenant_id,branch_id,special_date,open_time,close_time,closed,reason) values(:i,:t,:b,:d,:o,:c,:x,:r)")
                .param("i", id).param("t", p.tenantId()).param("b", branchId).param("d", request.specialDate())
                .param("o", request.openTime()).param("c", request.closeTime()).param("x", request.closed()).param("r", request.reason()).update();
    }
    private SpecialHour findSpecial(IdentityPrincipal p, UUID branchId, UUID id) {
        return db.sql("select * from branch_special_hours where id=:i and tenant_id=:t and branch_id=:b")
                .param("i", id).param("t", p.tenantId()).param("b", branchId).query((row, n) -> specialHour(row)).optional()
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "SPECIAL_HOURS_NOT_FOUND", "Horario especial no encontrado"));
    }
    private BusinessHour businessHour(ResultSet row) throws SQLException {return new BusinessHour(row.getObject("id", UUID.class),row.getInt("day_of_week"),row.getObject("open_time", LocalTime.class),row.getObject("close_time", LocalTime.class),row.getBoolean("closed"),row.getObject("second_open_time", LocalTime.class),row.getObject("second_close_time", LocalTime.class));}
    private SpecialHour specialHour(ResultSet row) throws SQLException {return new SpecialHour(row.getObject("id", UUID.class),row.getObject("special_date", LocalDate.class),row.getObject("open_time", LocalTime.class),row.getObject("close_time", LocalTime.class),row.getBoolean("closed"),row.getString("reason"));}
    private ApiException invalidHours(String message) {return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_BUSINESS_HOURS", message);}
}
