package com.elsworne.stubline.spike.kindfailover;

import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;

/** Stateless HTTP responder that identifies its serving pod. */
public final class PodServer implements AutoCloseable {
  private final HttpServer server;
  private final AtomicBoolean ready = new AtomicBoolean(true);

  public PodServer(int port, String podName) throws IOException {
    server =
        HttpServer.create(
            new InetSocketAddress(
                System.getenv().getOrDefault("SPIKE_BIND_ADDRESS", "127.0.0.1"), port),
            0);
    server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());
    server.createContext(
        "/",
        exchange -> {
          String path = exchange.getRequestURI().getPath();
          if (!path.equals("/") && !path.equals("/ready") && !path.equals("/health")) {
            exchange.sendResponseHeaders(404, -1);
            exchange.close();
            return;
          }
          if (path.equals("/ready") && !ready.get()) {
            exchange.sendResponseHeaders(503, -1);
            exchange.close();
            return;
          }
          byte[] body =
              (path.equals("/") ? podName + "\n" : "ok\n").getBytes(StandardCharsets.UTF_8);
          exchange.sendResponseHeaders(200, body.length);
          try (var output = exchange.getResponseBody()) {
            output.write(body);
          }
        });
  }

  public void start() {
    server.start();
  }

  public int port() {
    return server.getAddress().getPort();
  }

  @Override
  public void close() {
    ready.set(false);
    server.stop(5);
  }

  public static void main(String[] args) throws Exception {
    try (var server =
        new PodServer(8080, System.getenv().getOrDefault("HOSTNAME", "unknown-pod"))) {
      server.start();
      Runtime.getRuntime().addShutdownHook(new Thread(server::close));
      new java.util.concurrent.CountDownLatch(1).await();
    }
  }
}
