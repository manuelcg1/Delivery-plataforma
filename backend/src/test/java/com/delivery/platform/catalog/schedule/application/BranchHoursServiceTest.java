package com.delivery.platform.catalog.schedule.application;
import org.junit.jupiter.api.Test;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
class BranchHoursServiceTest {
 private final UUID id=UUID.randomUUID();
 private BranchHoursService.Availability at(String time,List<BranchHoursService.DayHours> week,List<BranchHoursService.SpecialHours> special){return BranchHoursService.evaluate(id,"ACTIVE","ACTIVE","America/Lima",Instant.parse(time),week,special);}
 private BranchHoursService.DayHours day(int day,String open,String close,String secondOpen,String secondClose){return new BranchHoursService.DayHours(day,false,LocalTime.parse(open),LocalTime.parse(close),secondOpen==null?null:LocalTime.parse(secondOpen),secondClose==null?null:LocalTime.parse(secondClose));}
 @Test void boundariesSecondShiftAndTimezone(){var week=List.of(day(1,"09:00","12:00","14:00","18:00"));assertTrue(at("2026-11-09T14:00:00Z",week,List.of()).open());assertFalse(at("2026-11-09T17:00:00Z",week,List.of()).open());assertEquals(OffsetDateTime.parse("2026-11-09T14:00:00-05:00"),at("2026-11-09T17:00:00Z",week,List.of()).nextOpeningAt());assertTrue(at("2026-11-09T19:00:00Z",week,List.of()).open());assertFalse(at("2026-11-09T23:00:00Z",week,List.of()).open());}
 @Test void sundayCarriesOnlyIntoMondayMorning(){var week=List.of(day(7,"22:00","02:00",null,null));assertTrue(at("2026-11-09T06:00:00Z",week,List.of()).open());assertFalse(at("2026-11-08T06:00:00Z",week,List.of()).open());assertFalse(at("2026-11-09T07:00:00Z",week,List.of()).open());}
 @Test void specialClosedCancelsCarry(){var week=List.of(day(7,"22:00","02:00",null,null));assertFalse(at("2026-11-09T06:00:00Z",week,List.of(new BranchHoursService.SpecialHours(LocalDate.parse("2026-11-09"),true,null,null))).open());}
 @Test void unconfiguredAndInactive(){assertEquals("UNCONFIGURED",at("2026-11-09T14:00:00Z",List.of(),List.of()).status());assertTrue(at("2026-11-09T14:00:00Z",List.of(),List.of()).open());assertFalse(BranchHoursService.evaluate(id,"ACTIVE","INACTIVE","America/Lima",Instant.now(),List.of(),List.of()).open());assertFalse(at("2026-11-10T14:00:00Z",List.of(day(1,"09:00","18:00",null,null)),List.of()).open());}
 @Test void specialOpeningOverridesWeeklyAndCarries(){var special=List.of(new BranchHoursService.SpecialHours(LocalDate.parse("2026-11-08"),false,LocalTime.of(22,0),LocalTime.of(2,0)));assertTrue(at("2026-11-09T06:00:00Z",List.of(),special).open());assertFalse(at("2026-11-09T06:00:00Z",List.of(),List.of(new BranchHoursService.SpecialHours(LocalDate.parse("2026-11-09"),false,LocalTime.of(12,0),LocalTime.of(14,0)))).open());}
 @Test void configuredClosedWeekAndPausedBranch(){var closed=java.util.stream.IntStream.rangeClosed(1,7).mapToObj(d->new BranchHoursService.DayHours(d,true,null,null,null,null)).toList();assertFalse(at("2026-11-09T14:00:00Z",closed,List.of()).open());assertNull(at("2026-11-09T14:00:00Z",closed,List.of()).nextOpeningAt());assertEquals("TEMPORARILY_CLOSED",BranchHoursService.evaluate(id,"TEMPORARILY_CLOSED","ACTIVE","America/Lima",Instant.now(),List.of(),List.of()).status());}
}
