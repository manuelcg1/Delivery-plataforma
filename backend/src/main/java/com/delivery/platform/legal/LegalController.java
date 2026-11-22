package com.delivery.platform.legal;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Documentos legales públicos: se consultan antes de iniciar sesión. */
@RestController
@RequestMapping("/api/v1/public/legal")
public class LegalController {
    @GetMapping
    Map<String, String> current() {
        return LegalDocuments.summary();
    }

    @GetMapping("/{slug}")
    LegalDocuments.Document document(@PathVariable String slug) {
        return LegalDocuments.load(LegalDocuments.Type.fromSlug(slug));
    }
}
