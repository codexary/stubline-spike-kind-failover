English | [简体中文](FINDINGS.zh-CN.md)

# Findings

## What we observed

In the three-node kind cluster, an abrupt worker stop caused buyer-visible failed requests until node detection, endpoint removal, and replacement. The `unreachable` NoExecute toleration is ten seconds here. Planned drain with a PDB requiring two available replicas, a five-second `preStop`, and graceful shutdown had zero sampled failed requests in the recorded run. The PDB covers voluntary eviction, not an abrupt node loss.

## Backend decision

The backend release drill should treat node failure as a separate operational case from planned drain. Measurements depend on the local cluster and do not establish a production availability target. Stateful replacement would also require fencing. See [backend ADR 0014 — Release, observe and drill](https://github.com/codexary/stubline-backend/blob/main/docs/adr/0014-release-observe-and-drill.md).
