package com.delivery.platform.tracking.api;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.tracking.application.CourierNotificationService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/v1/couriers/me/device-tokens")
public class DeviceTokenController {
  public record TokenRequest(@NotBlank String token,@Pattern(regexp="ANDROID|IOS") String platform) {}
  private final CourierNotificationService notifications;
  public DeviceTokenController(CourierNotificationService notifications){this.notifications=notifications;}
  @PostMapping @ResponseStatus(HttpStatus.NO_CONTENT) @PreAuthorize("hasAuthority('COURIER_VIEW')")
  void register(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody TokenRequest r){notifications.register(p,r.token(),r.platform());}
  @DeleteMapping @ResponseStatus(HttpStatus.NO_CONTENT) @PreAuthorize("hasAuthority('COURIER_VIEW')")
  void unregister(@AuthenticationPrincipal IdentityPrincipal p,@Valid @RequestBody TokenRequest r){notifications.unregister(p,r.token());}
}
