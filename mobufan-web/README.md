# mobufan-web — 服务器管理面板

将 [mobufan.sh](../README.md) 工具箱重构为 **Go 单一静态二进制 + Docker 镜像 + Web 管理界面**。
纯标准库实现，零第三方依赖；前端资源通过 `go:embed` 打进二进制，部署即一个文件。

## 功能

- **总览**：系统信息（OS/内核/主机名/时区/网关/DNS）、CPU、内存、磁盘、网络接口、公网 IP、负载
- **Docker 管理**：容器启停/重启/删除、镜像/卷/网络列表与删除、实时统计、`docker system df`、一键清理悬空资源
- **BBR / 网络**：查看与启用/关闭 BBR（`tcp_congestion_control` / `default_qdisc`），网络接口流量
- **端口 / 防火墙**：监听端口（含 PID/进程）、iptables INPUT 规则查看、开放/关闭端口、放行/阻止 IP、规则保存
- **进程**：按 CPU / 内存排序的进程列表

## 快速开始（二进制）

```bash
make build                       # 需要本机 Go 1.22+
./bin/mobufan -listen :2413      # 自动生成访问令牌并打印

# 或用 docker 交叉编译，无需本地 Go
make linux-amd64                 # 产出 bin/mobufan-linux-amd64
```

启动后用浏览器访问 `http://服务器IP:2413`，输入令牌登录。

### 命令行参数

```
-listen string         HTTP 监听地址 (默认 ":2413")
-token string          访问令牌（默认读环境变量 MOBUFAN_TOKEN，未设置自动生成）
-docker-sock string    Docker socket 路径，留空禁用 Docker 功能 (默认 /var/run/docker.sock)
-no-token              关闭认证（仅限内网可信环境）
-v                     打印版本
```

## Docker 镜像（宿主机管理）

```bash
make docker            # 或 docker build -t mobufan .
```

### 方式一：docker run

```bash
docker run -d --name mobufan \
  --restart unless-stopped \
  --privileged \
  --network host \
  --pid host \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /:/host:ro \
  -e MOBUFAN_TOKEN=请改成强密码 \
  mobufan:latest
```

### 方式二：docker compose

```bash
docker compose up -d
```

`docker-compose.yml` 已预置特权、host 网络、宿主机进程与 docker.sock 挂载；只需把 `MOBUFAN_TOKEN` 改成强密码即可。

挂载说明：

| 挂载 | 作用 |
|------|------|
| `/var/run/docker.sock` | 管理宿主机 Docker |
| `--privileged` + 容器内 iptables | 管理宿主机防火墙 |
| `--network host` | 端口映射与宿主一致 |
| `--pid host` | 让 `/proc` 反映宿主机进程 |
| `-v /:/host:ro` | 只读访问宿主机文件系统（供后续扩展） |

> 防火墙/BBR 等写操作需要 root 权限，请以特权容器运行。

## API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/system/info` | 系统总览 |
| GET | `/api/system/cpu` `/memory` `/disk` `/network` `/processes` `/ports` `/publicip` | 分项采集 |
| GET | `/api/bbr/status` | BBR 状态 |
| POST | `/api/bbr/enable` `/api/bbr/disable` | 启停 BBR |
| GET | `/api/firewall/chain?name=INPUT` | iptables 链 |
| POST | `/api/firewall/port/open` `/port/close` | 开放/关闭端口 `{"port":"8080","protocol":"tcp"}` |
| POST | `/api/firewall/ip/allow` `/ip/block` | 放行/阻止 IP `{"ip":"1.2.3.4"}` |
| GET | `/api/docker/containers` `/images` `/volumes` `/networks` `/stats` `/info` `/df` | Docker 资源列表 |
| POST | `/api/docker/containers/{id}/action` | `{"action":"start\|stop\|restart\|kill\|remove"}` |
| DELETE | `/api/docker/images/{id}` `/volumes/{name}` `/networks/{id}` | 删除资源 |
| POST | `/api/docker/prune` | `{"target":"images"}` 清理悬空资源 |

认证方式：`Authorization: Bearer <token>`。

## 项目结构

```
mobufan-web/
├── main.go              # 入口：参数解析 + 启动服务
├── assets.go            # go:embed 前端资源
├── internal/
│   ├── system/          # 系统信息采集（/proc、/sys、iptables）
│   ├── docker/          # Docker Engine API 客户端（unix socket）
│   └── server/          # HTTP 路由、认证、各模块 handler
├── web/                 # 前端（index.html / style.css / app.js）
├── Dockerfile           # 多阶段构建，特权宿主管理容器
├── Makefile             # 本地构建 + Docker 交叉编译 + 镜像
└── go.mod
```

## 说明

- 与 mobufan.sh 一致，本面板面向个人服务器的运维场景，请勿暴露到公网。
- 自动生成令牌的服务，重启后会生成新令牌；建议通过 `MOBUFAN_TOKEN` 固定。
