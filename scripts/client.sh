#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
name="pod-client-$$"
cleanup() { .tools/kubectl delete pod "$name" --ignore-not-found --wait=false >/dev/null 2>&1 || true; }
trap cleanup EXIT
.tools/kubectl run "$name" --image=busybox:1.37.0-musl --restart=Never --overrides='{"spec":{"nodeSelector":{"kubernetes.io/hostname":"stubline-failover-worker2"}}}' --command -- sh -c '
  while true; do
    if body=$(wget -q -T 1 -O - http://pod-server/); then status=200; else status=000; body=; fi
    printf "%s status=%s pod=%s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$status" "$body"
    sleep 0.1
  done' >/dev/null
.tools/kubectl wait --for=jsonpath='{.status.phase}'=Running "pod/$name" --timeout=60s >/dev/null
.tools/kubectl logs -f "pod/$name" --timestamps=false
