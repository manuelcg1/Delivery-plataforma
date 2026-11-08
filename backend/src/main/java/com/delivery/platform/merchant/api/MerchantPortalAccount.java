package com.delivery.platform.merchant.api;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.*;

public record MerchantPortalAccount(
        @NotBlank @Email @Size(max=254) String email,
        @NotBlank @Size(max=100) String firstName,
        @NotBlank @Size(max=100) String lastName,
        @JsonProperty(access=JsonProperty.Access.WRITE_ONLY)
        @NotBlank @Size(min=10,max=72) String password) {
    @Override public String toString() { return "MerchantPortalAccount[REDACTED]"; }
}
