#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
node=stubline-failover-worker
docker pull busybox:1.37.0-musl@sha256:8fddc201ee902ceabe7f766612d597201b70592e95451c9410f446440ef4786f >/dev/null
.tools/kind load docker-image busybox:1.37.0-musl@sha256:8fddc201ee902ceabe7f766612d597201b70592e95451c9410f446440ef4786f --name stubline-failover
log=$(mktemp)
./scripts/client.sh > "$log" & client=$!
cleanup() { docker start "$node" >/dev/null 2>&1 || true; kill "$client" 2>/dev/null || true; wait "$client" 2>/dev/null || true; rm -f "$log"; }
trap cleanup EXIT
connected=
for i in {1..60}; do
  if grep -q 'status=200' "$log"; then connected=1; break; fi
  sleep 1
done
[[ -n "$connected" ]] || { echo 'Client never reached the Service within 60s' >&2; exit 1; }
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
  ready=$(.tools/kubectl get pods -l app=pod-server -o json | python3 -c 'import json,sys; pods=json.load(sys.stdin)["items"]; print(sum(p.get("metadata",{}).get("deletionTimestamp") is None and any(c.get("type")=="Ready" and c.get("status")=="True" for c in p.get("status",{}).get("conditions",[])) for p in pods))')
  if [[ "$ready" == 3 ]]; then replaced=$(date +%s); break; fi
  sleep 1
done
[[ -n "$replaced" ]] || { echo 'Pods were not replaced' >&2; exit 1; }
errors=$(grep -vc 'status=200' "$log" || true)
terminating=$(.tools/kubectl get pods -l app=pod-server -o json | python3 -c 'import json,sys; print(sum(p.get("metadata",{}).get("deletionTimestamp") is not None for p in json.load(sys.stdin)["items"]))')
printf 'NotReady after %ss; replacement after %ss; old Terminating pods=%s after %ss; failed client requests=%s\n' "$((not_ready-start))" "$((replaced-start))" "$terminating" "$(( $(date +%s)-start ))" "$errors"
cat "$log"
