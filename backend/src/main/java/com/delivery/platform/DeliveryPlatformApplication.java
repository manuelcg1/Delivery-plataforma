package com.delivery.platform;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class DeliveryPlatformApplication {
    public static void main(String[] args) {
        SpringApplication.run(DeliveryPlatformApplication.class, args);
    }
}
