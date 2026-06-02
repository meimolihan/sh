# MOBUFAN.SH — 个人 Linux 服务器工具箱

> 基于 [kejilion.sh](https://github.com/kejilion/sh) 二次开发的个人一键脚本工具集，包含系统管理、Docker、Nginx、Fail2ban、BBR 网络优化、媒体文件管理等模块。

## 快速安装

```bash
# curl
bash <(curl -sL gitee.com/meimolihan/sh/raw/master/install/mobufan.sh)
bash <(curl -sL sh.meimolihan.eu.org/install/mobufan.sh)

# wget
bash <(wget -qO- gitee.com/meimolihan/sh/raw/master/install/mobufan.sh)
bash <(wget -qO- sh.meimolihan.eu.org/install/mobufan.sh)
```

安装后执行 `mobufan` 即可进入交互菜单。

## 模块一览

| 模块 | 路径 | 说明 |
|------|------|------|
| `mobufan.sh` | `/` | 主脚本 — 菜单驱动的系统管理工具箱 (v1.6.4.2) |
| `install/` | `install/` | 一键安装脚本，从 Gitee 拉取主脚本 |
| `bbr/` | `bbr/` | BBR/BBRplus/Lotserver TCP 拥塞控制管理 |
| `color/` | `color/` | 终端 256 色彩表生成器 |
| `compose/` | `compose/` | Docker Compose 配置（迅雷、qBittorrent）及 docker-compose 二进制 |
| `f2b/` | `f2b/` | Fail2ban 配置（SSH + 7 个 Nginx 防护规则） |
| `nginx/` | `nginx/` | Nginx 主配置 + SSL + 站点配置 + 自定义欢迎页 |
| `file/` | `file/` | 系统工具脚本（如 OpenSSH 升级修复） |
| `tv/` | `tv/` | TV 剧集批量重命名脚本（适配 Plex/Emby/Jellyfin） |

## 模块详情

### `mobufan.sh` — 主工具箱

单文件 Bash 菜单脚本，功能涵盖：
- 系统信息查看、资源监控
- Docker 管理（安装、容器、镜像、网络）
- Nginx 配置生成与管理
- Fail2ban 安装与规则配置
- BBR 网络优化
- 文件压缩与解压
- PVE / FnOS 系统命令
- Git 工具与环境变量管理
- 脚本自更新

### `bbr/` — BBR 网络优化

`tcpx.sh` (v100.0.4.15 by 千影/cx9208/YLX) — 一键部署 BBR、BBRplus、Lotserver，支持 CentOS/Debian/Ubuntu/Oracle Linux。

### `compose/` — Docker Compose 服务

- **迅雷 NAS** (`cnk3x/xunlei`) — 资源受限容器，支持变量端口
- **qBittorrent** (`linuxserver/qbittorrent`) — BT 下载客户端
- 提供 v5.0.0 / v5.0.2 / v5.1.0 的 docker-compose Linux x86_64 二进制

### `f2b/` — Fail2ban 防护

- SSH 防护：CentOS 专用 + 通用 aggressive 模式，bantime 递增（最高 24h）
- Nginx 防护：7 个独立 jail（CC 攻击、418 茶壶、错误请求、恶意爬虫、目录扫描、权限拒绝、HTTP 认证）
- 自定义 filter：PVE API 防暴力破解、LuCI 管理后台防护

### `nginx/` — Nginx 配置

- Epoll 模型，65535 连接，TLSv1.2/TLSv1.3，强加密套件，HSTS
- 端口 80 默认站：拦截恶意爬虫 + 自定义欢迎页
- 端口 666 SSL 默认站：SNI 分离，404 兜底
- 自适应绿色主题欢迎页，动画背景，响应式设计

### `file/` — 系统工具

`upgrade_openssh9.8p1.sh` — 修复 OpenSSH 8.5–9.8 漏洞（CVE），自动下载编译安装。

### `tv/` — TV 剧集重命名

`tv_rename_ultimate.sh` — 交互式批量重命名，支持 6 种编号模式：
- `S01E01` / `EP01` / `第01集` / 中间数字 / 前导数字 / 末尾数字
- 预览确认 + 精度统计，适配 Plex/Emby/Jellyfin

## 项目结构

```
├── mobufan.sh                  # 主工具箱脚本
├── install/
│   ├── mobufan.sh              # 安装脚本
│   └── mobufan.md
├── bbr/
│   ├── tcpx.sh                 # BBR 管理
│   └── README.md
├── color/
│   ├── 256color.sh             # 256 色彩表
│   └── 256color.md
├── compose/
│   ├── compose-test.sh
│   ├── xunlei/                 # 迅雷 Docker Compose
│   ├── qbittorrent/            # qBittorrent Docker Compose
│   └── download/               # docker-compose 二进制
├── f2b/
│   ├── jail.d/                 # 监狱配置
│   ├── filter.d/               # 自定义过滤器
│   └── centos-ssh.conf
├── nginx/
│   ├── nginx.conf
│   ├── sites-enabled/
│   ├── html/
│   └── keyfile/                # SSL 证书
├── file/
│   └── upgrade_openssh9.8p1.sh
├── tv/
│   ├── tv_rename_ultimate.sh
│   └── tv_rename_ultimate.md
└── log/
    └── mobufan_sh_log.txt      # 更新日志
```

## ⚠️ 重要声明

- 本脚本基于 [kejilion.sh](https://github.com/kejilion/sh) 进行二次开发
- **大量配置与逻辑仅适配本人的本地环境**（目录结构、服务器 IP、个人偏好等）
- **未做通用性兼容处理**，不保证在其他设备或系统中正常运行
- **若执意使用，请自行承担全部风险**
