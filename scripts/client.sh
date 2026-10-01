#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
.tools/kubectl port-forward service/pod-server 18084:80 >/tmp/stubline-kind-port-forward.log 2>&1 &
forward=$!
trap 'kill "$forward" 2>/dev/null || true; wait "$forward" 2>/dev/null || true' EXIT
sleep 2
while kill -0 "$forward" 2>/dev/null; do
  code=$(curl --silent --max-time 1 -o /tmp/stubline-kind-response -w '%{http_code}' http://localhost:18084/ || echo 000)
  body=$(cat /tmp/stubline-kind-response 2>/dev/null || true)
  printf '%s status=%s pod=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$code" "$body"
  sleep 0.1
done
