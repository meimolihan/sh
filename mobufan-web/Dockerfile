# syntax=docker/dockerfile:1

# ---------- 构建阶段 ----------
FROM golang:1.22-alpine AS builder

ARG VERSION=1.0.0
WORKDIR /build

# 先拷贝 go.mod 以利用缓存
COPY go.mod ./
COPY main.go assets.go ./
COPY internal ./internal
COPY web ./web

RUN CGO_ENABLED=0 GOOS=linux go build -trimpath \
    -ldflags "-s -w -X main.version=${VERSION}" \
    -o mobufan .

# ---------- 运行阶段 ----------
# 使用 alpine 以便在容器内直接调用 iptables 管理宿主机防火墙
FROM alpine:3.20

RUN apk add --no-cache \
        iptables \
        ca-certificates \
        tzdata \
    && mkdir -p /data

COPY --from=builder /build/mobufan /usr/local/bin/mobufan

ENV MOBUFAN_TOKEN=""
EXPOSE 2413

# 默认通过 --privileged + 挂载 /var/run/docker.sock 管理宿主机
CMD ["mobufan", "-listen", ":2413"]
