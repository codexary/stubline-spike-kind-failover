English | [简体中文](README.zh-CN.md)

# kind node failover spike

BuildKit caches the Maven wrapper and dependencies under `/root/.m2` after copying the POM, so source edits reuse dependency resolution. Repeated builds are faster, download less, and cost less in CI.


This independent spike extends Stubline's local replica drill to a real three-node Kubernetes cluster: one control plane and two workers. It uses kind v0.33.0, Kubernetes node image v1.37.0 (pinned digest), kubectl v1.37.1, and Java 21. `scripts/tools.sh` downloads the kind and kubectl binaries into ignored `.tools/` and verifies hard-coded SHA-256 checksums for macOS/Linux on arm64/amd64. No system-wide install is made. Every script exports `KUBECONFIG=$PWD/.kube/config`, so it never reads or writes the user's normal kubeconfig.

From this repository root, with Docker running:

```sh
./mvnw -q verify
./scripts/create.sh
./scripts/deploy.sh
./scripts/client.sh
./scripts/node-failure.sh
./scripts/planned-drain.sh
./scripts/delete.sh
```

The stateless server returns its pod name. Three Deployment replicas are spread 2+1 across the two workers; `nodeTaintsPolicy: Honor` excludes the tainted control plane from topology domains. readiness and liveness probes control endpoints and restarts. An in-cluster client Pod calls `http://pod-server` through the Service and kube-proxy. `client.sh` prints a timestamp, HTTP status and pod name every 100 ms. Use Ctrl-C to stop it. `node-failure.sh` stops one worker's Docker container, measures time until Kubernetes marks the node `NotReady`, then until three non-terminating replicas are ready on surviving nodes, and counts client failures. It starts the stopped worker again on exit, including errors. `planned-drain.sh` cordons and evicts gracefully, waits for replacement and asserts zero failed requests; it uncordons on exit. A five-second `preStop` delay lets endpoint updates propagate before SIGTERM; the JVM shutdown hook drains in-flight requests. The PodDisruptionBudget requires two available replicas during a voluntary eviction. It does not protect against sudden node failure.

The two drills build `Dockerfile.client` from the pinned BusyBox base and load the resulting single-platform `stubline-kind-client:0.1.0` image into kind. The client Pod uses `imagePullPolicy: Never`. To run `client.sh` by itself, first run `./scripts/load-client.sh` from this repository root.

A stopped node stops sending heartbeats. Kubernetes waits for its detection timeout before marking it `NotReady`; then the pod's `node.kubernetes.io/unreachable` NoExecute toleration lasts 10 seconds before eviction. The normal default toleration is 300 seconds, which would make this demo take much longer. The elapsed measurements and failed-request count depend on the local machine. The PDB guarantees only that voluntary eviction cannot take available replicas below two; it cannot guarantee zero HTTP errors during an actual crash. Compared with Compose's inventory replica kill, this drill adds node heartbeat detection, taint-based eviction and rescheduling onto another worker. The conclusion feeds the failure-detection and on-call discussion of Stubline's local release and drill workflow.

Pods on an unreachable node can remain `Terminating` until its kubelet returns: the control plane cannot know whether processes on a disconnected machine are still running. Force deletion removes the API object but does not stop a live process. Stateful workloads need fencing before replacement can safely take ownership of storage or leadership.

The responder defaults to loopback for local runs. The kind Deployment sets `SPIKE_BIND_ADDRESS=0.0.0.0` inside its pod so the cluster Service can reach it; no host port is published.

## License

This repository is licensed under the [MIT License](LICENSE).

## About this repository

This repository contains a focused Stubline experiment. The README documents its commands and observed results.

The code and documents in this repository were written with the help of AI tools; every recorded output comes from actually running them.
