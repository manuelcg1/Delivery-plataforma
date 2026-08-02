package com.delivery.platform.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

@Configuration
public class FirebaseConfig {
  public FirebaseConfig(@Value("${notifications.firebase-enabled:false}") boolean enabled,
      @Value("${notifications.firebase-project-id:}") String projectId,
      @Value("${notifications.firebase-service-account-base64:}") String encodedCredentials) throws IOException {
    if (!enabled || !FirebaseApp.getApps().isEmpty()) return;
    GoogleCredentials credentials = encodedCredentials == null || encodedCredentials.isBlank()
      ? GoogleCredentials.getApplicationDefault()
      : GoogleCredentials.fromStream(new ByteArrayInputStream(
          Base64.getDecoder().decode(encodedCredentials.getBytes(StandardCharsets.UTF_8))));
    FirebaseOptions.Builder options = FirebaseOptions.builder().setCredentials(credentials);
    if (projectId != null && !projectId.isBlank()) options.setProjectId(projectId);
    FirebaseApp.initializeApp(options.build());
  }
}
