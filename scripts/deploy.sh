#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export KUBECONFIG="$PWD/.kube/config"
cleanup() { [[ ${success:-0} == 1 ]] || .tools/kubectl delete -f k8s/deployment.yaml --ignore-not-found >/dev/null 2>&1 || true; }
trap cleanup EXIT
./mvnw -q verify
docker build -t stubline-kind-failover:0.1.0 .
.tools/kind load docker-image stubline-kind-failover:0.1.0 --name stubline-failover
.tools/kubectl apply -f k8s/deployment.yaml
.tools/kubectl rollout status deployment/pod-server --timeout=180s
workers=$(.tools/kubectl get pods -l app=pod-server -o json | python3 -c 'import json,sys; print(" ".join(sorted({p["spec"]["nodeName"] for p in json.load(sys.stdin)["items"]})))')
[[ "$workers" == "stubline-failover-worker stubline-failover-worker2" ]] || { echo "Replicas are not spread across both workers: $workers" >&2; exit 1; }
.tools/kubectl get pods -o wide
success=1
