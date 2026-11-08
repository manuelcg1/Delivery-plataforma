package com.delivery.platform.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.concurrent.ThreadPoolTaskScheduler;

@Configuration
public class ArrivalNotificationSchedulerConfig {
    @Bean
    ThreadPoolTaskScheduler arrivalNotificationScheduler() {
        var scheduler=new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(1);
        scheduler.setThreadNamePrefix("arrival-outbox-");
        return scheduler;
    }

    // Preserve a separate default scheduler for assignment reconciliation and other jobs.
    @Bean
    ThreadPoolTaskScheduler taskScheduler() {
        var scheduler=new ThreadPoolTaskScheduler();
        scheduler.setPoolSize(1);
        scheduler.setThreadNamePrefix("platform-scheduler-");
        return scheduler;
    }
}
