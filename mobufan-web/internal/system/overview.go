package system

import (
	"io"
	"net/http"
	"regexp"
	"strings"
	"sync"
	"time"
)

var (
	ipMu      sync.Mutex
	ipValue   string
	ipFetched time.Time
)

var ipv4Re = regexp.MustCompile(`\b([0-9]{1,3}\.){3}[0-9]{1,3}\b`)

var ipServices = []string{
	"https://api.ipify.org",
	"https://checkip.amazonaws.com",
	"https://ipv4.icanhazip.com",
	"https://v4.ident.me",
}

func isPrivateIP(ip string) bool {
	parts := strings.Split(ip, ".")
	if len(parts) != 4 {
		return false
	}
	// 忽略明显非法 IP
	for _, p := range parts {
		if len(p) == 0 || len(p) > 3 {
			return true
		}
	}
	switch parts[0] {
	case "10", "127", "0", "255":
		return true
	case "192":
		return parts[1] == "168"
	case "172":
		if len(parts[1]) == 2 && parts[1][0] == '1' && parts[1][1] >= '6' && parts[1][1] <= '9' {
			return true
		}
		if len(parts[1]) == 2 && parts[1][0] == '2' && parts[1][1] >= '0' && parts[1][1] <= '1' {
			return true
		}
	case "169":
		return parts[1] == "254"
	}
	return false
}

// PublicIP 获取公网 IPv4，带 10 分钟缓存。
func PublicIP() string {
	ipMu.Lock()
	defer ipMu.Unlock()
	if ipValue != "" && time.Since(ipFetched) < 10*time.Minute {
		return ipValue
	}
	client := &http.Client{Timeout: 5 * time.Second}
	for _, url := range ipServices {
		resp, err := client.Get(url)
		if err != nil {
			continue
		}
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		resp.Body.Close()
		m := ipv4Re.FindString(string(b))
		if m != "" && !isPrivateIP(m) {
			ipValue = m
			ipFetched = time.Now()
			return m
		}
	}
	if ipValue != "" {
		return ipValue + "（离线）"
	}
	return "无法获取"
}

// Overview 组装系统总览信息。
func Overview() Info {
	model, phys, logical := CPUInfo()
	secs, human := Uptime()
	l1, l5, l15 := LoadAvg()
	gw, _ := DefaultGateway()
	info := Info{
		OSName:      OSName(),
		Kernel:      Kernel(),
		Arch:        Arch(),
		Hostname:    Hostname(),
		Uptime:      human,
		UptimeSec:   secs,
		CPUModel:    model,
		LogicalCPU:  logical,
		PhysicalCPU: phys,
		Load1:       l1,
		Load5:       l5,
		Load15:      l15,
		Processes:   ProcessCount(),
		Timezone:    Timezone(),
		CurrentTime: time.Now().Format("2006-01-02 15:04:05"),
		InternalIP:  InternalIP(),
		DNS:         DNS(),
		Gateway:     gw,
		TCPCong:     readString("/proc/sys/net/ipv4/tcp_congestion_control"),
		Qdisc:       readString("/proc/sys/net/core/default_qdisc"),
		Connections: Connections(),
	}
	if gw == "" {
		info.Gateway = "无法获取"
	}
	return info
}
