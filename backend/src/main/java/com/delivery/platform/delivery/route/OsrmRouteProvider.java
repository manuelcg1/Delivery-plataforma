package com.delivery.platform.delivery.route;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

@Component
public class OsrmRouteProvider implements RouteProvider {
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
    private final ObjectMapper json;
    private final String baseUrl;

    public OsrmRouteProvider(ObjectMapper json,
            @Value("${routing.osrm.base-url:https://router.project-osrm.org}") String baseUrl) {
        this.json = json;
        this.baseUrl = baseUrl.replaceAll("/+$", "");
    }

    @Override public String code() { return "OSRM"; }

    @Override
    public RouteResult route(BigDecimal originLat, BigDecimal originLon,
                             BigDecimal destinationLat, BigDecimal destinationLon) {
        try {
            URI uri = URI.create("%s/route/v1/driving/%s,%s;%s,%s?overview=full&geometries=polyline"
                    .formatted(baseUrl, originLon, originLat, destinationLon, destinationLat));
            HttpRequest request = HttpRequest.newBuilder(uri).timeout(Duration.ofSeconds(8)).GET().build();
            HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() / 100 != 2) throw new IllegalStateException("OSRM HTTP " + response.statusCode());
            JsonNode route = json.readTree(response.body()).path("routes").path(0);
            String polyline = route.path("geometry").asText();
            if (polyline.isBlank()) throw new IllegalStateException("OSRM returned no route");
            return new RouteResult(polyline, route.path("distance").asDouble(), route.path("duration").asDouble());
        } catch (Exception error) {
            throw new IllegalStateException("OSRM route request failed", error);
        }
    }
}
