package com.delivery.platform.tracking.infrastructure;

import com.delivery.platform.common.ApiException;
import io.minio.*;
import io.minio.http.Method;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Component
public class ProofStorage {
    private final MinioClient client;
    private final MinioClient signer;
    private final String bucket;
    private final long maximumBytes;

    public ProofStorage(@Value("${MINIO_ENDPOINT:http://localhost:9000}") String endpoint,
                        @Value("${MINIO_PUBLIC_ENDPOINT:http://localhost:9000}") String publicEndpoint,
                        @Value("${MINIO_ACCESS_KEY:delivery}") String access,
                        @Value("${MINIO_SECRET_KEY:delivery_minio_password}") String secret,
                        @Value("${MINIO_BUCKET_PROOFS:delivery-proofs}") String bucket,
                        @Value("${PROOF_MAX_IMAGE_SIZE_MB:8}") long maximumMb) {
        client = MinioClient.builder().endpoint(endpoint).credentials(access, secret).build();
        signer = MinioClient.builder().endpoint(publicEndpoint).credentials(access, secret).build();
        this.bucket = bucket;
        this.maximumBytes = maximumMb * 1024 * 1024;
    }

    @PostConstruct
    void initialize() {
        try {
            if (!client.bucketExists(BucketExistsArgs.builder().bucket(bucket).build()))
                client.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        } catch (Exception exception) {
            throw new IllegalStateException("No se pudo inicializar el bucket de pruebas de entrega", exception);
        }
    }

    public String put(UUID tenantId, UUID deliveryId, String type, MultipartFile file) {
        String contentType = file.getContentType();
        if (!Set.of("image/jpeg", "image/png", "image/webp").contains(contentType))
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROOF_TYPE_NOT_ALLOWED", "Solo se permiten imágenes JPEG, PNG o WebP");
        if (file.isEmpty() || file.getSize() > maximumBytes)
            throw new ApiException(HttpStatus.BAD_REQUEST, "PROOF_TOO_LARGE", "La prueba supera el tamaño máximo permitido");
        String extension = contentType.equals("image/jpeg") ? "jpg" : contentType.equals("image/png") ? "png" : "webp";
        String key = "tenant/" + tenantId + "/deliveries/" + deliveryId + "/" + type.toLowerCase() + "/" + UUID.randomUUID() + "." + extension;
        try (InputStream input = file.getInputStream()) {
            client.putObject(PutObjectArgs.builder().bucket(bucket).object(key)
                    .stream(input, file.getSize(), -1).contentType(contentType).build());
            return key;
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "PROOF_UPLOAD_FAILED", "No se pudo guardar la prueba de entrega");
        }
    }

    public String signedUrl(String key) {
        if (key == null) return null;
        try {
            return signer.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder().bucket(bucket).object(key)
                    .method(Method.GET).expiry(15, TimeUnit.MINUTES).build());
        } catch (Exception exception) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "PROOF_URL_FAILED", "No se pudo consultar la prueba de entrega");
        }
    }
}
