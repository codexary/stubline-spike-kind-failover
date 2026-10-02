[English](README.md) | 简体中文

# kind 节点故障小项目

BuildKit 先复制 POM，再在 `/root/.m2` 缓存 Maven wrapper 和依赖；源码变更时可复用依赖解析。重复构建更快、下载更少，CI 成本也更低。


这个独立小项目把 Stubline 的本地副本故障演练扩展到真实的三节点 Kubernetes cluster：一个 control plane、两个 worker。版本固定为 kind v0.33.0、Kubernetes node image v1.37.0（固定 digest）、kubectl v1.37.1 和 Java 21。`scripts/tools.sh` 将 kind、kubectl 下载到忽略的 `.tools/`，用内置 SHA-256 校验 macOS/Linux、arm64/amd64 的二进制文件，不做全局安装。每个脚本设置 `KUBECONFIG=$PWD/.kube/config`，不读写用户的普通 kubeconfig。

在本仓库根目录、Docker 已启动时运行：

```sh
./mvnw -q verify
./scripts/create.sh
./scripts/deploy.sh
./scripts/client.sh
./scripts/node-failure.sh
./scripts/planned-drain.sh
./scripts/delete.sh
```

无状态 server 返回 pod 名。三个 Deployment 副本分散到两个 worker；readiness 和 liveness probe 控制 Service endpoints 与重启。`client.sh` 每 100 ms 打印时间、HTTP 状态及 pod 名；用 Ctrl-C 停止。`node-failure.sh` 停止一个 worker 的 Docker 容器，测量 Kubernetes 将节点标成 `NotReady`、三个副本在存活节点重新就绪的时间，并统计 client 失败请求。退出（包括错误退出）时会启动被停止的 worker。`planned-drain.sh` 有计划地 cordon 和 evict，等待替补，断言零失败请求，退出时 uncordon。PodDisruptionBudget 要求自愿驱逐期间至少两个副本可用；它不保护突发节点故障。

两个演练都用固定 BusyBox base 的 `Dockerfile.client` 构建单平台的 `stubline-kind-client:0.1.0` image，并将它加载到 kind。client Pod 使用 `imagePullPolicy: Never`。单独运行 `client.sh` 前，先在本仓库根目录运行 `./scripts/load-client.sh`。

节点停止后不再发送 heartbeat。Kubernetes 等待检测超时才标记 `NotReady`；随后 pod 对 `node.kubernetes.io/unreachable` 的 NoExecute toleration 保留 10 秒，再被驱逐。普通默认值为 300 秒，会让这个演示长得多。实测时间及失败请求数取决于本机。PDB 只保证自愿驱逐不会使可用副本少于两个，不能保证真实故障中完全没有 HTTP 错误。与 Compose 的 inventory 副本 kill 相比，本项目增加节点 heartbeat 检测、taint 驱逐和在另一 worker 上重新调度。结论用于 Stubline 本地演练中的故障检测和值班讨论。

不可达节点上的旧 pod 可能在 kubelet 恢复前一直保持 `Terminating`：control plane 无法知道断联机器上的进程是否仍活着。force deletion 只删除 API object，不会停止活进程。stateful workload 在替代实例接管存储或领导权前必须 fencing。`preStop` 等待五秒让 endpoint 更新传播，SIGTERM shutdown hook 排空进行中的请求。

响应服务在本地运行时默认绑定回环地址。kind Deployment 仅在 Pod 内设置 `SPIKE_BIND_ADDRESS=0.0.0.0`，让集群 Service 可以访问；不会发布宿主机端口。

## 许可证

本仓库采用 [MIT License](LICENSE)。

## 关于本仓库

本仓库包含一项针对 Stubline 的独立实验。README 说明运行命令与观察结果。

本仓库的代码与文档借助 AI 工具编写；记录的输出都来自实际运行。
