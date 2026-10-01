#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
node=stubline-failover-worker
log=$(mktemp)
./scripts/client.sh > "$log" & client=$!
cleanup() { docker start "$node" >/dev/null 2>&1 || true; kill "$client" 2>/dev/null || true; wait "$client" 2>/dev/null || true; rm -f "$log"; }
trap cleanup EXIT
sleep 5
start=$(date +%s)
docker stop "$node" >/dev/null
not_ready=
for i in {1..120}; do
  condition=$(.tools/kubectl get node "$node" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
  if [[ "$condition" != True ]]; then not_ready=$(date +%s); break; fi
  sleep 1
done
[[ -n "$not_ready" ]] || { echo 'Node never became NotReady' >&2; exit 1; }
replaced=
for i in {1..120}; do
  ready=$(.tools/kubectl get deployment pod-server -o jsonpath='{.status.readyReplicas}')
  on_failed=$(.tools/kubectl get pods -l app=pod-server -o wide | grep -c "$node" || true)
  if [[ "$ready" == 3 && "$on_failed" == 0 ]]; then replaced=$(date +%s); break; fi
  sleep 1
done
[[ -n "$replaced" ]] || { echo 'Pods were not replaced' >&2; exit 1; }
errors=$(grep -vc 'status=200' "$log" || true)
printf 'NotReady after %ss; replacement after %ss; failed client requests=%s\n' "$((not_ready-start))" "$((replaced-start))" "$errors"
cat "$log"
