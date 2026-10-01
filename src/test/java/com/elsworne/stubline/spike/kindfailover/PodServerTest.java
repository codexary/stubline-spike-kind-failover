package com.elsworne.stubline.spike.kindfailover;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;

/** The response identifies the exact server instance. */
final class PodServerTest {
  @Test
  void answersWithPodName() throws Exception {
    try (var server = new PodServer(0, "pod-a");
        var client = HttpClient.newHttpClient()) {
      server.start();
      var response =
          client.send(
              HttpRequest.newBuilder(URI.create("http://localhost:" + server.port())).GET().build(),
              HttpResponse.BodyHandlers.ofString());
      assertEquals(200, response.statusCode());
      assertEquals("pod-a\n", response.body());
    }
  }
}
