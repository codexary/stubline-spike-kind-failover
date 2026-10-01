#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
node=stubline-failover-worker
docker pull busybox:1.37.0-musl@sha256:8fddc201ee902ceabe7f766612d597201b70592e95451c9410f446440ef4786f >/dev/null
.tools/kind load docker-image busybox:1.37.0-musl@sha256:8fddc201ee902ceabe7f766612d597201b70592e95451c9410f446440ef4786f --name stubline-failover
log=$(mktemp)
./scripts/client.sh > "$log" & client=$!
cleanup() { .tools/kubectl uncordon "$node" >/dev/null 2>&1 || true; kill "$client" 2>/dev/null || true; wait "$client" 2>/dev/null || true; rm -f "$log"; }
trap cleanup EXIT
connected=
for i in {1..60}; do
  if grep -q 'status=200' "$log"; then connected=1; break; fi
  sleep 1
done
[[ -n "$connected" ]] || { echo 'Client never reached the Service within 60s' >&2; exit 1; }
.tools/kubectl drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=180s
.tools/kubectl rollout status deployment/pod-server --timeout=180s
sleep 5
errors=$(grep -vc 'status=200' "$log" || true)
printf 'Planned drain failed client requests=%s\n' "$errors"
cat "$log"
[[ "$errors" == 0 ]]
