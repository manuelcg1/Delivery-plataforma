package com.delivery.platform.catalog.media.infrastructure;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.HexFormat;
import java.util.Map;
import java.util.stream.Collectors;

import static org.junit.jupiter.api.Assertions.assertEquals;

class MinioCatalogStorageTest {
    private static final String SECRET = "test-secret-not-a-real-credential";

    @ParameterizedTest
    @CsvSource({
        "http://localhost:9000,tenant/test/products/photo.jpg",
        "https://images.example.test,tenant/test/merchants/logo.png",
        "https://images.example.test:9443,tenant/test/merchants/banner with space.png"
    })
    void signatureAuthenticatesThePublicHostAndExactObjectPath(String publicEndpoint, String key) throws Exception {
        // The internal endpoint only supplies the bucket region. No real storage is needed.
        var server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/", exchange -> {
            byte[] response = "<LocationConstraint xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">us-east-1</LocationConstraint>".getBytes(StandardCharsets.UTF_8);
            exchange.getResponseHeaders().set("Content-Type", "application/xml");
            exchange.sendResponseHeaders(200, response.length);
            try (var output = exchange.getResponseBody()) { output.write(response); }
        });
        server.start();
        try {
            var storage = new MinioCatalogStorage("http://127.0.0.1:" + server.getAddress().getPort(),
                    publicEndpoint, "test-access", SECRET, "delivery-catalog", 5, "us-east-1");
            URI url = URI.create(storage.signedUrl(key));
            assertEquals(URI.create(publicEndpoint).getAuthority(), url.getAuthority());
            assertEquals("/delivery-catalog/" + key, url.getPath());
            Map<String, String> query = Arrays.stream(url.getRawQuery().split("&"))
                    .map(pair -> pair.split("=", 2)).collect(Collectors.toMap(pair -> pair[0], pair ->
                            URLDecoder.decode(pair[1], StandardCharsets.UTF_8)));
            assertEquals("900", query.get("X-Amz-Expires"));
            assertEquals("host", query.get("X-Amz-SignedHeaders"));
            String canonicalQuery = Arrays.stream(url.getRawQuery().split("&"))
                    .filter(pair -> !pair.startsWith("X-Amz-Signature=")).sorted().collect(Collectors.joining("&"));
            String canonicalRequest = "GET\n" + url.getRawPath() + "\n" + canonicalQuery
                    + "\nhost:" + url.getAuthority() + "\n\nhost\nUNSIGNED-PAYLOAD";
            String[] credential = query.get("X-Amz-Credential").split("/");
            String scope = String.join("/", Arrays.copyOfRange(credential, 1, credential.length));
            String stringToSign = "AWS4-HMAC-SHA256\n" + query.get("X-Amz-Date") + "\n" + scope + "\n"
                    + HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(canonicalRequest.getBytes(StandardCharsets.UTF_8)));
            byte[] signingKey = ("AWS4" + SECRET).getBytes(StandardCharsets.UTF_8);
            for (int i = 1; i < credential.length; i++) signingKey = hmac(signingKey, credential[i]);
            assertEquals(HexFormat.of().formatHex(hmac(signingKey, stringToSign)), query.get("X-Amz-Signature"),
                    "The signature must authenticate the public URL exactly as the mobile client receives it");
        } finally {
            server.stop(0);
        }
    }

    private static byte[] hmac(byte[] key, String value) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        mac.init(new SecretKeySpec(key, "HmacSHA256"));
        return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
    }
}
