#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
node=stubline-failover-worker
./scripts/load-client.sh
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
