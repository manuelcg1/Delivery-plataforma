package com.delivery.platform.catalog.merchant.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.validation.Validation;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.assertj.core.api.Assertions.assertThat;

class MerchantTypeValidationTest {
    @ParameterizedTest
    @ValueSource(strings={"RESTAURANT","GROCERY","PHARMACY","RETAIL","DARK_STORE","OTHER",
            "POLLERIA","BURGERS","CHIFA","ICE_CREAM","BODEGA","SERVICES"})
    void acceptsSupportedTypes(String type) throws Exception {
        assertType(type,true);
    }

    @ParameterizedTest
    @ValueSource(strings={"UNKNOWN","Farmacia","", "RESTAURANT|CHIFA"})
    void rejectsUnsupportedTypes(String type) throws Exception {
        assertType(type,false);
    }

    private void assertType(String type,boolean valid) throws Exception {
        var request=new ObjectMapper().readValue("""
            {"code":"test","name":"Test","merchantType":"%s","defaultCurrency":"PEN","timezone":"America/Lima"}
            """.formatted(type),MerchantController.Save.class);
        try(var factory=Validation.buildDefaultValidatorFactory()) {
            assertThat(factory.getValidator().validateProperty(request,"merchantType").isEmpty()).isEqualTo(valid);
        }
    }
}
