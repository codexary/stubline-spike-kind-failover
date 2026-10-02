#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker build --load -f Dockerfile.client -t stubline-kind-client:0.1.0 .
.tools/kind load docker-image stubline-kind-client:0.1.0 --name stubline-failover
