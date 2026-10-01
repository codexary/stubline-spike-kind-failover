#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/tools.sh
mkdir -p .kube
export KUBECONFIG="$PWD/.kube/config"
cleanup() { [[ ${success:-0} == 1 ]] || .tools/kind delete cluster --name stubline-failover >/dev/null 2>&1 || true; }
trap cleanup EXIT
.tools/kind create cluster --name stubline-failover --config kind.yaml \
  --image 'kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5'
.tools/kubectl get nodes -o wide
success=1
