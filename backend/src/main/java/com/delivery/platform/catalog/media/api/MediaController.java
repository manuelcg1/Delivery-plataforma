package com.delivery.platform.catalog.media.api;

import com.delivery.platform.catalog.common.CatalogSupport;
import com.delivery.platform.catalog.media.infrastructure.MinioCatalogStorage;
import com.delivery.platform.common.ApiException;
import com.delivery.platform.identity.security.IdentityPrincipal;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/v1")
public class MediaController {
    private static final org.slf4j.Logger log = org.slf4j.LoggerFactory.getLogger(MediaController.class);
    private final JdbcClient db;
    private final CatalogSupport support;
    private final MinioCatalogStorage storage;

    public MediaController(JdbcClient db, CatalogSupport support, MinioCatalogStorage storage) {
        this.db = db; this.support = support; this.storage = storage;
    }

    public record Image(UUID id, UUID productId, String objectKey, String url, String altText,
                        int sortOrder, boolean primaryImage) { }
    public record OrderItem(UUID id, int sortOrder) { }
    public record Reorder(@NotEmpty List<OrderItem> images) { }

    @GetMapping("/products/{productId}/images")
    @PreAuthorize("hasAuthority('CATALOG_PRODUCTS_VIEW')")
    public List<Image> list(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID productId) {
        support.product(p, productId);
        return db.sql("select * from product_images where product_id=:p and tenant_id=:t order by sort_order,created_at")
                .param("p", productId).param("t", p.tenantId()).query((rs, n) -> image(rs)).list();
    }

    @PostMapping(value = "/products/{productId}/images", consumes = "multipart/form-data")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_UPLOAD')")
    public Image upload(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID productId,
                        @RequestPart("file") MultipartFile file, @RequestParam(defaultValue = "") String altText) {
        support.product(p, productId);
        int count = db.sql("select count(*) from product_images where tenant_id=:t and product_id=:p")
                .param("t", p.tenantId()).param("p", productId).query(Integer.class).single();
        if (count >= 8) throw new ApiException(HttpStatus.CONFLICT, "PRODUCT_IMAGE_LIMIT", "Un producto puede tener hasta 8 imágenes");
        String key = storage.put(p.tenantId(), "products/" + productId, file);
        deleteOnRollback(key);
        UUID id = UUID.randomUUID();
        try {
            db.sql("insert into product_images(id,tenant_id,product_id,object_key,alt_text,sort_order,primary_image) values(:i,:t,:p,:k,:a,:o,:m)")
                    .param("i", id).param("t", p.tenantId()).param("p", productId).param("k", key)
                    .param("a", altText).param("o", count).param("m", count == 0).update();
        } catch (RuntimeException error) { if (!TransactionSynchronizationManager.isSynchronizationActive()) safeDelete(key); throw error; }
        support.audit(p, "PRODUCT_IMAGE_UPLOADED", "PRODUCT_IMAGE", id);
        return one(p, id);
    }

    @PutMapping("/products/{productId}/images/order")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_UPLOAD')")
    public List<Image> reorder(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID productId,
                               @Valid @RequestBody Reorder request) {
        support.product(p, productId);
        for (OrderItem item : request.images()) {
            if (db.sql("update product_images set sort_order=:o where id=:i and product_id=:p and tenant_id=:t")
                    .param("o", item.sortOrder()).param("i", item.id()).param("p", productId)
                    .param("t", p.tenantId()).update() == 0) throw missing();
        }
        support.audit(p, "PRODUCT_IMAGES_REORDERED", "PRODUCT", productId);
        return list(p, productId);
    }

    @PutMapping("/products/{productId}/images/{imageId}/primary")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_UPLOAD')")
    public Image primary(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID productId,
                         @PathVariable UUID imageId) {
        support.product(p, productId);
        if (owned(p, productId, imageId) == 0) throw missing();
        db.sql("update product_images set primary_image=false where product_id=:p and tenant_id=:t")
                .param("p", productId).param("t", p.tenantId()).update();
        db.sql("update product_images set primary_image=true where id=:i and product_id=:p and tenant_id=:t")
                .param("i", imageId).param("p", productId).param("t", p.tenantId()).update();
        support.audit(p, "PRODUCT_PRIMARY_IMAGE_CHANGED", "PRODUCT_IMAGE", imageId);
        return one(p, imageId);
    }

    @DeleteMapping("/products/{productId}/images/{imageId}")
    @Transactional
    @PreAuthorize("hasAuthority('CATALOG_MEDIA_DELETE')")
    public void delete(@AuthenticationPrincipal IdentityPrincipal p, @PathVariable UUID productId,
                       @PathVariable UUID imageId) {
        support.product(p, productId);
        Image image = one(p, imageId);
        if (!image.productId().equals(productId)) throw missing();
        db.sql("delete from product_images where id=:i and tenant_id=:t").param("i", imageId).param("t", p.tenantId()).update();
        if (image.primaryImage()) db.sql("update product_images set primary_image=true where id=(select id from product_images where tenant_id=:t and product_id=:p order by sort_order,created_at limit 1) and tenant_id=:t").param("t",p.tenantId()).param("p", productId).update();
        deleteAfterCommit(image.objectKey());
        support.audit(p, "PRODUCT_IMAGE_DELETED", "PRODUCT_IMAGE", imageId);
    }

    private int owned(IdentityPrincipal p, UUID product, UUID image) {
        return db.sql("select count(*) from product_images where id=:i and product_id=:p and tenant_id=:t")
                .param("i", image).param("p", product).param("t", p.tenantId()).query(Integer.class).single();
    }
    private Image one(IdentityPrincipal p, UUID id) {
        return db.sql("select * from product_images where id=:i and tenant_id=:t").param("i", id).param("t", p.tenantId())
                .query((rs, n) -> image(rs)).optional().orElseThrow(this::missing);
    }
    private Image image(java.sql.ResultSet rs) throws java.sql.SQLException {
        String key = rs.getString("object_key");
        return new Image(rs.getObject("id", UUID.class), rs.getObject("product_id", UUID.class), key,
                storage.signedUrl(key), rs.getString("alt_text"), rs.getInt("sort_order"), rs.getBoolean("primary_image"));
    }
    private ApiException missing() { return new ApiException(HttpStatus.NOT_FOUND, "PRODUCT_IMAGE_NOT_FOUND", "Imagen no encontrada"); }
    private void deleteOnRollback(String key) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) return;
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCompletion(int status) { if (status != STATUS_COMMITTED) safeDelete(key); }
        });
    }
    private void deleteAfterCommit(String key) {
        if (!TransactionSynchronizationManager.isSynchronizationActive()) { safeDelete(key); return; }
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCommit() { safeDelete(key); }
        });
    }
    private void safeDelete(String key) {
        try { storage.delete(key); }
        catch (RuntimeException error) { log.warn("No se pudo limpiar la imagen de producto {}",key,error); }
    }
}
