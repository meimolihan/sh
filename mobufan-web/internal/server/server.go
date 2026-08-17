// Package server 提供 HTTP 服务、认证与全部 API 路由。
package server

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"io/fs"
	"log"
	"net/http"
	"strings"

	"mobufan/internal/docker"
)

// Server HTTP 服务
type Server struct {
	token  string
	docker *docker.Client
	web    fs.FS
}

// New 创建服务实例。
func New(token string, dc *docker.Client, web fs.FS) *Server {
	return &Server{token: token, docker: dc, web: web}
}

// GenerateToken 生成随机访问令牌。
func GenerateToken() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

// auth 认证中间件。
func (s *Server) auth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if s.token != "" {
			auth := r.Header.Get("Authorization")
			bearer := strings.TrimPrefix(auth, "Bearer ")
			// 兼容 ?token= 查询参数（供简单脚本使用）
			q := r.URL.Query().Get("token")
			if bearer != s.token && q != s.token {
				writeErr(w, http.StatusUnauthorized, "未授权：token 无效或缺失")
				return
			}
		}
		next(w, r)
	}
}

// Handler 注册全部路由。
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()

	// 静态资源
	webSub, err := fs.Sub(s.web, "web")
	if err != nil {
		log.Fatalf("嵌入资源加载失败: %v", err)
	}
	fileServer := http.FileServer(http.FS(webSub))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// 根路径直接返回 index.html（FileServer 会重定向 /index.html 到 ./，导致循环）
		if r.URL.Path == "/" {
			if b, err := fs.ReadFile(webSub, "index.html"); err == nil {
				w.Header().Set("Content-Type", "text/html; charset=utf-8")
				_, _ = w.Write(b)
				return
			}
		}
		fileServer.ServeHTTP(w, r)
	})

	// 健康检查（无需认证）
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"status": "ok", "docker": s.docker.Enabled()})
	})

	// 系统
	mux.HandleFunc("GET /api/system/info", s.auth(s.handleSystemInfo))
	mux.HandleFunc("GET /api/system/cpu", s.auth(s.handleSystemCPU))
	mux.HandleFunc("GET /api/system/memory", s.auth(s.handleSystemMemory))
	mux.HandleFunc("GET /api/system/disk", s.auth(s.handleSystemDisk))
	mux.HandleFunc("GET /api/system/network", s.auth(s.handleSystemNetwork))
	mux.HandleFunc("GET /api/system/processes", s.auth(s.handleSystemProcesses))
	mux.HandleFunc("GET /api/system/ports", s.auth(s.handleSystemPorts))
	mux.HandleFunc("GET /api/system/publicip", s.auth(s.handlePublicIP))

	// BBR
	mux.HandleFunc("GET /api/bbr/status", s.auth(s.handleBBRStatus))
	mux.HandleFunc("POST /api/bbr/enable", s.auth(s.handleBBREnable))
	mux.HandleFunc("POST /api/bbr/disable", s.auth(s.handleBBRDisable))

	// 防火墙
	mux.HandleFunc("GET /api/firewall/chain", s.auth(s.handleFirewallChain))
	mux.HandleFunc("POST /api/firewall/port/open", s.auth(s.handleFirewallOpen))
	mux.HandleFunc("POST /api/firewall/port/close", s.auth(s.handleFirewallClose))
	mux.HandleFunc("POST /api/firewall/ip/allow", s.auth(s.handleFirewallAllowIP))
	mux.HandleFunc("POST /api/firewall/ip/block", s.auth(s.handleFirewallBlockIP))
	mux.HandleFunc("POST /api/firewall/save", s.auth(s.handleFirewallSave))

	// Docker
	dockerMux := s.handleDockerRoutes()
	mux.HandleFunc("GET /api/docker/containers", s.auth(dockerMux.containerList))
	mux.HandleFunc("POST /api/docker/containers/{id}/action", s.auth(dockerMux.containerAction))
	mux.HandleFunc("GET /api/docker/images", s.auth(dockerMux.imageList))
	mux.HandleFunc("DELETE /api/docker/images/{id}", s.auth(dockerMux.imageRemove))
	mux.HandleFunc("GET /api/docker/volumes", s.auth(dockerMux.volumeList))
	mux.HandleFunc("DELETE /api/docker/volumes/{name}", s.auth(dockerMux.volumeRemove))
	mux.HandleFunc("GET /api/docker/networks", s.auth(dockerMux.networkList))
	mux.HandleFunc("DELETE /api/docker/networks/{id}", s.auth(dockerMux.networkRemove))
	mux.HandleFunc("GET /api/docker/stats", s.auth(dockerMux.stats))
	mux.HandleFunc("GET /api/docker/info", s.auth(dockerMux.info))
	mux.HandleFunc("GET /api/docker/df", s.auth(dockerMux.df))
	mux.HandleFunc("POST /api/docker/prune", s.auth(dockerMux.prune))

	return mux
}
