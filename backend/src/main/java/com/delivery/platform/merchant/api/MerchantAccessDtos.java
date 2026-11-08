package com.delivery.platform.merchant.api;

import jakarta.validation.constraints.*;
import java.util.UUID;

public final class MerchantAccessDtos {
    private MerchantAccessDtos() {}
    public record Access(UUID id, String email, String firstName, String lastName, boolean editable, String reason) {}
    public record Update(@NotBlank @Email @Size(max=254) String email,
                         @NotBlank @Size(max=100) String firstName,
                         @NotBlank @Size(max=100) String lastName, String newPassword) {}
}
