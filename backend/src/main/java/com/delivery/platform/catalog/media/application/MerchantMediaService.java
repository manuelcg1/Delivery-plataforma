package com.delivery.platform.catalog.media.application;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

@Service
public class MerchantMediaService {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(MerchantMediaService.class);
    public enum Type {
        LOGO("logo_object_key", "logo"),
        BANNER("banner_object_key", "banner");

        private final String column;
        private final String folder;

        Type(String column, String folder) {
            this.column = column;
            this.folder = folder;
        }
    }

    public record MerchantImage(String type, String url) { }

    private final JdbcClient db;
    private final CatalogSupport support;
    private final MinioCatalogStorage storage;

    public MerchantMediaService(JdbcClient db, CatalogSupport support, MinioCatalogStorage storage) {
        this.db = db;
        this.support = support;
        this.storage = storage;
    }

    @Transactional
    public MerchantImage upload(IdentityPrincipal principal, UUID merchantId, Type type, MultipartFile file) {
        support.merchant(principal, merchantId);
        String previousKey = db.sql("select " + type.column + " from merchants where id=:id and tenant_id=:tenant")
                .param("id", merchantId)
                .param("tenant", principal.tenantId())
                .query(String.class)
                .optional()
                .orElse(null);
        String newKey = storage.put(principal.tenantId(), "merchants/" + merchantId + "/" + type.folder, file);
        try {
            int updated = db.sql("update merchants set " + type.column + "=:key,updated_at=now() where id=:id and tenant_id=:tenant")
                    .param("key", newKey)
                    .param("id", merchantId)
                    .param("tenant", principal.tenantId())
                    .update();
            if (updated != 1) {
                throw new ApiException(HttpStatus.NOT_FOUND, "MERCHANT_NOT_FOUND", "Comercio no encontrado");
            }
            support.audit(principal, "MERCHANT_" + type.name() + "_UPLOADED", "MERCHANT", merchantId);
            cleanUpAfterTransaction(previousKey, newKey);
            return new MerchantImage(type.name(), storage.signedUrl(newKey));
        } catch (RuntimeException error) {
            safeDelete(newKey);
            throw error;
        }
    }

    private void cleanUpAfterTransaction(String previousKey, String newKey) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) {
            if (previousKey != null) safeDelete(previousKey);
            return;
        }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCommit() {
                if (previousKey != null && !previousKey.equals(newKey)) safeDelete(previousKey);
            }

            @Override public void afterCompletion(int status) {
                if (status != STATUS_COMMITTED) safeDelete(newKey);
            }
        });
    }

    private void safeDelete(String key) {
        try {
            storage.delete(key);
        } catch (RuntimeException error) {
            log.warn("No se pudo limpiar el objeto de media {}", key, error);
        }
    }
}
