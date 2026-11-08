package com.delivery.platform.catalog.schedule.application;

import com.delivery.platform.common.ApiException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import java.time.*;
import java.util.*;

@Service
public class BranchHoursService {
 private final JdbcClient db;
 private final Clock clock;
 public BranchHoursService(JdbcClient db,Clock clock){this.db=db;this.clock=clock;}
 public record CurrentSchedule(LocalTime openTime,LocalTime closeTime) {}
 public record Availability(UUID branchId,boolean open,String status,String timezone,OffsetDateTime nextOpeningAt,CurrentSchedule currentSchedule) {}
 public record DayHours(int day,boolean closed,LocalTime open,LocalTime close,LocalTime secondOpen,LocalTime secondClose) {}
 public record SpecialHours(LocalDate date,boolean closed,LocalTime open,LocalTime close) {}
 private record Branch(UUID merchant,String status,String merchantStatus,String timezone,Instant pausedUntil) {}
 private record Interval(ZonedDateTime start,ZonedDateTime end,CurrentSchedule schedule) {}
 public Availability availability(UUID tenant,UUID branch){return availability(tenant,null,branch);}
 public Availability availability(UUID tenant,UUID merchant,UUID branch){
  Branch b=db.sql("select b.merchant_id,b.status,m.status merchant_status,b.timezone,b.paused_until from branches b join merchants m on m.id=b.merchant_id and m.tenant_id=b.tenant_id where b.tenant_id=:t and b.id=:b")
   .param("t",tenant).param("b",branch).query((r,n)->new Branch(r.getObject("merchant_id",UUID.class),r.getString("status"),r.getString("merchant_status"),r.getString("timezone"),r.getTimestamp("paused_until")==null?null:r.getTimestamp("paused_until").toInstant())).optional().orElseThrow(()->new ApiException(HttpStatus.NOT_FOUND,"BRANCH_NOT_FOUND","Sucursal no encontrada"));
  if(merchant!=null&&!merchant.equals(b.merchant()))throw new ApiException(HttpStatus.NOT_FOUND,"BRANCH_NOT_FOUND","Sucursal no encontrada");
  var week=db.sql("select * from business_hours where tenant_id=:t and branch_id=:b").param("t",tenant).param("b",branch).query((r,n)->new DayHours(r.getInt("day_of_week"),r.getBoolean("closed"),r.getObject("open_time",LocalTime.class),r.getObject("close_time",LocalTime.class),r.getObject("second_open_time",LocalTime.class),r.getObject("second_close_time",LocalTime.class))).list();
  var specials=db.sql("select * from branch_special_hours where tenant_id=:t and branch_id=:b").param("t",tenant).param("b",branch).query((r,n)->new SpecialHours(r.getObject("special_date",LocalDate.class),r.getBoolean("closed"),r.getObject("open_time",LocalTime.class),r.getObject("close_time",LocalTime.class))).list();
  Instant now=clock.instant();
  if("ACTIVE".equals(b.status()) && "ACTIVE".equals(b.merchantStatus()) && b.pausedUntil()!=null && b.pausedUntil().isAfter(now)) {
   Availability resumed=evaluate(branch,b.status(),b.merchantStatus(),b.timezone(),b.pausedUntil(),week,specials);
   OffsetDateTime next=resumed.open()?b.pausedUntil().atZone(ZoneId.of(b.timezone())).toOffsetDateTime():resumed.nextOpeningAt();
   return new Availability(branch,false,"TEMPORARILY_CLOSED",b.timezone(),next,null);
  }
  return evaluate(branch,b.status(),b.merchantStatus(),b.timezone(),now,week,specials);
 }
 public void requireOpen(UUID tenant,UUID merchant,UUID branch){if(!availability(tenant,merchant,branch).open())throw new ApiException(HttpStatus.CONFLICT,"OUTSIDE_BUSINESS_HOURS","Fuera de horario de atención");}
 public static Availability evaluate(UUID branch,String status,String merchantStatus,String timezone,Instant instant,List<DayHours> week,List<SpecialHours> specials){
  ZoneId zone;
  try { zone=ZoneId.of(timezone); } catch(DateTimeException | NullPointerException e) { throw new ApiException(HttpStatus.BAD_REQUEST,"INVALID_BUSINESS_HOURS","La zona horaria de la sucursal no es válida"); }
  ZonedDateTime now=instant.atZone(zone);LocalDate today=now.toLocalDate();
  if(!"ACTIVE".equals(merchantStatus)||!"ACTIVE".equals(status))return new Availability(branch,false,"TEMPORARILY_CLOSED".equals(status)?status:"CLOSED",timezone,null,null);
  Map<LocalDate,SpecialHours> dates=new HashMap<>();specials.forEach(s->dates.put(s.date(),s));
  boolean previousApplicable=dates.containsKey(today.minusDays(1))&&!intervals(today.minusDays(1),zone,week,dates).stream().filter(i->i.end().isAfter(now)).toList().isEmpty();
  if(week.isEmpty()&&!dates.containsKey(today)&&!previousApplicable)return new Availability(branch,true,"UNCONFIGURED",timezone,null,null);
  var candidates=new ArrayList<Interval>();
  if(!dates.containsKey(today))candidates.addAll(intervals(today.minusDays(1),zone,week,dates));
  candidates.addAll(intervals(today,zone,week,dates));
  for(var i:candidates)if(!now.isBefore(i.start())&&now.isBefore(i.end()))return new Availability(branch,true,"OPEN",timezone,null,i.schedule());
  OffsetDateTime next=null;
  // A weekly opening repeats within seven days; also examine each exception and
  // the week following it, without walking every date up to distant exceptions.
  SortedSet<LocalDate> openingDates=new TreeSet<>();
  for(int day=0;day<=7;day++)openingDates.add(today.plusDays(day));
  for(var special:specials)if(!special.date().isBefore(today))for(int day=0;day<=7;day++)openingDates.add(special.date().plusDays(day));
  for(LocalDate d:openingDates){
   if(week.isEmpty() && !dates.containsKey(d)) {
    OffsetDateTime candidate=d.atStartOfDay(zone).toOffsetDateTime();
    if(candidate.isAfter(now.toOffsetDateTime()) && (next==null || candidate.isBefore(next)))next=candidate;
   }
   for(var i:intervals(d,zone,week,dates))if(i.start().isAfter(now)&&(next==null||i.start().toInstant().isBefore(next.toInstant())))next=i.start().toOffsetDateTime();
  }
  return new Availability(branch,false,"OUTSIDE_BUSINESS_HOURS",timezone,next,null);
 }
 private static List<Interval> intervals(LocalDate date,ZoneId zone,List<DayHours> week,Map<LocalDate,SpecialHours> specials){
  List<Interval> result=new ArrayList<>();SpecialHours special=specials.get(date);
  if(special!=null){if(!special.closed())add(result,date,zone,special.open(),special.close());return result;}
  week.stream().filter(d->d.day()==date.getDayOfWeek().getValue()&&!d.closed()).forEach(d->{add(result,date,zone,d.open(),d.close());add(result,date,zone,d.secondOpen(),d.secondClose());});return result;
 }
 private static void add(List<Interval> result,LocalDate date,ZoneId zone,LocalTime open,LocalTime close){if(open==null||close==null||open.equals(close))return;result.add(new Interval(date.atTime(open).atZone(zone),(close.isAfter(open)?date:date.plusDays(1)).atTime(close).atZone(zone),new CurrentSchedule(open,close)));}
}
