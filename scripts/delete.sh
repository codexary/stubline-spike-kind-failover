#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
.tools/kind delete cluster --name stubline-failover
rm -rf .kube
