package com.delivery.platform.payments.application;

import com.delivery.platform.identity.security.IdentityPrincipal;
import com.delivery.platform.payments.api.MerchantYapeController;
import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.*;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import static org.assertj.core.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(SpringExtension.class)
@ContextConfiguration(classes=MerchantYapeSecurityTest.Config.class)
class MerchantYapeSecurityTest {
    @Configuration @EnableMethodSecurity static class Config {
        @Bean MerchantYapeService service(){return mock(MerchantYapeService.class);}
        @Bean MerchantYapeController controller(MerchantYapeService service){return new MerchantYapeController(service);}
    }
    @Autowired MerchantYapeController controller;
    @Autowired MerchantYapeService service;
    final UUID merchant=UUID.randomUUID();
    final IdentityPrincipal principal=new IdentityPrincipal(UUID.randomUUID(),UUID.randomUUID(),"test",Set.of(),Set.of());
    void login(String... authorities){SecurityContextHolder.getContext().setAuthentication(new UsernamePasswordAuthenticationToken(principal,null,Arrays.stream(authorities).map(SimpleGrantedAuthority::new).toList()));}
    @AfterEach void cleanup(){SecurityContextHolder.clearContext();reset(service);}
    @Test void checkoutRequiresCustomerRole(){
        login("CATALOG_MERCHANTS_VIEW");
        assertThatThrownBy(()->controller.checkout(principal,merchant)).isInstanceOf(AccessDeniedException.class);
        login("ROLE_CUSTOMER");controller.checkout(principal,merchant);
        verify(service).checkout(principal,merchant);
    }
    @Test void configurationRequiresCreateOrUpdateAndMediaWhenUploading(){
        login("CATALOG_MERCHANTS_VIEW");
        assertThatThrownBy(()->controller.save(principal,merchant,false,null,null,null)).isInstanceOf(AccessDeniedException.class);
        login("CATALOG_MERCHANTS_CREATE");controller.save(principal,merchant,false,null,null,null);
        var qr=new MockMultipartFile("qr","test.png","image/png",new byte[]{1});
        assertThatThrownBy(()->controller.save(principal,merchant,true,"987654321","Test",qr)).isInstanceOf(AccessDeniedException.class);
        login("CATALOG_MERCHANTS_UPDATE","CATALOG_MEDIA_UPLOAD");controller.save(principal,merchant,true,"987654321","Test",qr);
        verify(service).save(principal,merchant,true,"987654321","Test",qr);
    }
}
