package com.delivery.platform.catalog.schedule.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.schedule.application.BranchHoursService;
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
import java.util.*;

@RestController
@RequestMapping("/api/v1/branches/{branchId}")
public class ScheduleController {
    private final JdbcClient db;
    private final CatalogSupport support;
    private final BranchHoursService hours;

    public ScheduleController(JdbcClient db, CatalogSupport support, BranchHoursService hours) {
        this.db = db;
        this.support = support;
        this.hours = hours;
    }

    public record BusinessHour(UUID id, @Min(1) @Max(7) int dayOfWeek, LocalTime openTime,
                               LocalTime closeTime, boolean closed, LocalTime secondOpenTime,
                               LocalTime secondCloseTime) {}
    public record SpecialHour(UUID id, @NotNull LocalDate specialDate, LocalTime openTime,
                              LocalTime closeTime, boolean closed, String reason) {}
    @GetMapping("/business-hours")
    @PreAuthorize("hasAnyAuthority('CATALOG_HOURS_VIEW','MERCHANT_BRANCH_OPERATE')")
    public List<BusinessHour> businessHours(@AuthenticationPrincipal IdentityPrincipal principal,
                                            @PathVariable UUID branchId) {
        support.branch(principal, branchId);
        return db.sql("select * from business_hours where tenant_id=:t and branch_id=:b order by day_of_week")
                .param("t", principal.tenantId()).param("b", branchId)
                .query((row, n) -> businessHour(row)).list();
    }

    @PutMapping("/business-hours")
    @Transactional
    @PreAuthorize("hasAnyAuthority('CATALOG_HOURS_MANAGE','MERCHANT_BRANCH_OPERATE')")
    public List<BusinessHour> replaceBusinessHours(@AuthenticationPrincipal IdentityPrincipal principal,
                                                   @PathVariable UUID branchId,
                                                   @Valid @RequestBody List<BusinessHour> hours) {
        support.branch(principal, branchId);
        if (hours == null || hours.stream().anyMatch(Objects::isNull) || hours.size() > 7 || hours.stream().map(BusinessHour::dayOfWeek).distinct().count() != hours.size()) {
            throw invalidHours("Solo puede existir un horario por día");
        }
        hours.forEach(this::validateRanges);
        hours = hours.stream().map(h -> h.closed() ? new BusinessHour(h.id(),h.dayOfWeek(),null,null,true,null,null) : h).toList();
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
        support.branch(principal, branchId);
        findSpecial(principal, branchId, id);
        validateSpecial(request);
        db.sql("update branch_special_hours set special_date=:d,open_time=:o,close_time=:c,closed=:x,reason=:r,updated_at=now() where id=:i and tenant_id=:t and branch_id=:b")
                .param("d", request.specialDate()).param("o", request.closed()?null:request.openTime()).param("c", request.closed()?null:request.closeTime())
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
        support.branch(principal, branchId);
        findSpecial(principal, branchId, id);
        db.sql("delete from branch_special_hours where id=:i and tenant_id=:t and branch_id=:b")
                .param("i", id).param("t", principal.tenantId()).param("b", branchId).update();
        support.audit(principal, "SPECIAL_HOURS_DELETED", "BRANCH_SPECIAL_HOUR", id);
    }

    @GetMapping("/availability")
    @PreAuthorize("hasAuthority('CATALOG_BRANCHES_VIEW')")
    public BranchHoursService.Availability availability(@AuthenticationPrincipal IdentityPrincipal principal,
                                     @PathVariable UUID branchId) {
        support.branch(principal, branchId);
        return hours.availability(principal.tenantId(), branchId);
    }

    private void validateRanges(BusinessHour hour) {
        if (hour.dayOfWeek() < 1 || hour.dayOfWeek() > 7) throw invalidHours("Día de semana inválido");
        if (hour.closed()) return;
        if (hour.openTime() == null || hour.closeTime() == null) throw invalidHours("Indica apertura y cierre, o marca el día como cerrado");
        if ((hour.secondOpenTime() == null) != (hour.secondCloseTime() == null)) throw invalidHours("Completa ambas horas del segundo turno");
        if (hour.openTime().equals(hour.closeTime())) throw invalidHours("Apertura y cierre deben ser distintos");
        if (hour.secondOpenTime() != null) {
            if (hour.secondOpenTime().equals(hour.secondCloseTime())) throw invalidHours("Apertura y cierre deben ser distintos");
            int a=hour.openTime().toSecondOfDay(), b=hour.closeTime().toSecondOfDay(); if(b<=a)b+=86400;
            int c=hour.secondOpenTime().toSecondOfDay(), d=hour.secondCloseTime().toSecondOfDay(); if(d<=c)d+=86400;
            for(int offset : new int[]{-86400,0,86400}) if(a<d+offset && c+offset<b) throw invalidHours("Los turnos no pueden solaparse");
        }
    }
    private void validateSpecial(SpecialHour hour) {
        if (!hour.closed() && hour.openTime()!=null && hour.openTime().equals(hour.closeTime())) throw invalidHours("Apertura y cierre deben ser distintos");
        if (!hour.closed() && (hour.openTime() == null || hour.closeTime() == null)) throw invalidHours("Indica apertura y cierre, o marca la fecha como cerrada");
    }
    private void insertSpecial(IdentityPrincipal p, UUID branchId, UUID id, SpecialHour request) {
        db.sql("insert into branch_special_hours(id,tenant_id,branch_id,special_date,open_time,close_time,closed,reason) values(:i,:t,:b,:d,:o,:c,:x,:r)")
                .param("i", id).param("t", p.tenantId()).param("b", branchId).param("d", request.specialDate())
                .param("o", request.closed()?null:request.openTime()).param("c", request.closed()?null:request.closeTime()).param("x", request.closed()).param("r", request.reason()).update();
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
