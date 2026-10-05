[English](FINDINGS.md) | 简体中文

# 实验结论

## 观察

三节点 kind 集群里，突然停掉 worker 会让买家请求失败，直到节点故障被发现、端点移除并完成补副本。这里的 `unreachable` NoExecute 容忍时间为十秒。记录中的有计划 drain 配合至少保留两个可用副本的 PDB、五秒 `preStop` 和优雅停机，采样请求没有失败。PDB 只约束自愿驱逐，不能保护突然断电。

## 对后端的影响

后端演练应把节点突发故障与有计划 drain 分开看。这些时间和失败数来自本地集群，不能当成生产可用性承诺；有状态副本的接管还需要 fencing。参见[后端 ADR 0014：Release, observe and drill](https://github.com/codexary/stubline-backend/blob/main/docs/adr/0014-release-observe-and-drill.md)。
