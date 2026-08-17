// mobufan-web: 基于 Go 的服务器管理面板（单文件静态二进制）。
// 提供 REST API + 内嵌 Web 管理界面，纯标准库实现，零第三方依赖。
package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"mobufan/internal/docker"
	"mobufan/internal/server"
)

var version = "1.0.0"

func main() {
	var (
		listen  = flag.String("listen", ":2413", "HTTP 监听地址，如 :2413 或 0.0.0.0:2413")
		token   = flag.String("token", "", "访问令牌（默认读环境变量 MOBUFAN_TOKEN，未设置则自动生成并打印）")
		sock    = flag.String("docker-sock", "/var/run/docker.sock", "Docker 守护进程 socket 路径，空则禁用 Docker 功能")
		noToken = flag.Bool("no-token", false, "禁用认证（仅限受信网络环境使用，不推荐）")
		showVer = flag.Bool("v", false, "打印版本号")
	)
	flag.Parse()

	if *showVer {
		fmt.Println("mobufan-web", version)
		return
	}

	if !*noToken {
		if *token == "" {
			*token = os.Getenv("MOBUFAN_TOKEN")
		}
		if *token == "" {
			*token = server.GenerateToken()
			fmt.Printf("[mobufan-web] 未设置 MOBUFAN_TOKEN，已自动生成访问令牌：\n  %s\n  请妥善保存，忘记后重启服务即可重新生成\n", *token)
		}
	} else {
		fmt.Println("[mobufan-web] 警告：认证已关闭，请确认仅在内网可信环境使用")
	}

	dc := docker.New(*sock)
	srv := server.New(*token, dc, webFS)

	httpServer := &http.Server{
		Addr:              *listen,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 10 * time.Second,
	}

	fmt.Printf("[mobufan-web] v%s 面板已启动: http://localhost%s\n", version, *listen)
	fmt.Printf("[mobufan-web] Docker socket: %s\n", *sock)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
