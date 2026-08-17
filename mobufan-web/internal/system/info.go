// Package system 提供系统信息采集，全部基于 /proc、/sys 与标准库，零外部依赖。
package system

import (
	"bufio"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func readString(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readFirstLine(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	if sc.Scan() {
		return strings.TrimSpace(sc.Text())
	}
	return ""
}

// Info 系统总览信息
type Info struct {
	OSName      string   `json:"os_name"`
	Kernel      string   `json:"kernel"`
	Arch        string   `json:"arch"`
	Hostname    string   `json:"hostname"`
	Uptime      string   `json:"uptime"`
	UptimeSec   float64  `json:"uptime_sec"`
	CPUModel    string   `json:"cpu_model"`
	LogicalCPU  int      `json:"logical_cpu"`
	PhysicalCPU int      `json:"physical_cpu"`
	Load1       float64  `json:"load1"`
	Load5       float64  `json:"load5"`
	Load15      float64  `json:"load15"`
	Processes   int      `json:"processes"`
	Timezone    string   `json:"timezone"`
	CurrentTime string   `json:"current_time"`
	PublicIP    string   `json:"public_ip"`
	InternalIP  string   `json:"internal_ip"`
	DNS         []string `json:"dns"`
	Gateway     string   `json:"gateway"`
	TCPCong     string   `json:"tcp_congestion"`
	Qdisc       string   `json:"qdisc"`
	Connections int      `json:"connections"`
}

// OSName 从 /etc/os-release 解析发行版名称。
func OSName() string {
	if b, err := os.ReadFile("/etc/os-release"); err == nil {
		for _, line := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(line, "PRETTY_NAME=") {
				v := strings.TrimPrefix(line, "PRETTY_NAME=")
				v = strings.Trim(v, `"'`)
				return v
			}
		}
	}
	if b, err := os.ReadFile("/etc/redhat-release"); err == nil {
		return strings.TrimSpace(string(b))
	}
	return "未知系统"
}

// Kernel 内核版本。
func Kernel() string {
	if v := readString("/proc/sys/kernel/osrelease"); v != "" {
		return v
	}
	return readString("/proc/version")
}

// Arch CPU 架构。
func Arch() string {
	if m := readString("/proc/sys/kernel/arch"); m != "" {
		return m
	}
	return readString("/etc/os-release")
}

// Hostname 主机名。
func Hostname() string {
	if v := readString("/proc/sys/kernel/hostname"); v != "" {
		return v
	}
	return readString("/etc/hostname")
}

// Uptime 运行时长（秒）与人类可读格式。
func Uptime() (float64, string) {
	line := readFirstLine("/proc/uptime")
	secs, _ := strconv.ParseFloat(strings.Fields(line)[0], 64)
	if secs <= 0 {
		return 0, "无法获取"
	}
	days := int(secs / 86400)
	hours := int(secs/3600) % 24
	mins := int(secs/60) % 60
	if days > 0 {
		return secs, fmt.Sprintf("%d天%d时%d分", days, hours, mins)
	}
	return secs, fmt.Sprintf("%d时%d分", hours, mins)
}

// CPUInfo 解析 /proc/cpuinfo。
func CPUInfo() (model string, physical, logical int) {
	model = "未知CPU"
	physicalIDs := map[string]struct{}{}
	cores := map[string]int{}
	fs, err := os.Open("/proc/cpuinfo")
	if err != nil {
		return model, 0, 0
	}
	defer fs.Close()
	sc := bufio.NewScanner(fs)
	curPID := ""
	for sc.Scan() {
		line := sc.Text()
		if strings.HasPrefix(line, "model name") {
			model = strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
		}
		if strings.HasPrefix(line, "processor") {
			curPID = strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
			logical++
		}
		if strings.HasPrefix(line, "physical id") {
			pid := strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
			physicalIDs[pid] = struct{}{}
		}
		if strings.HasPrefix(line, "core id") {
			cid := strings.TrimSpace(strings.SplitN(line, ":", 2)[1])
			cores[curPID] = cores[curPID]
			_ = cid
		}
	}
	physical = len(physicalIDs)
	if physical == 0 {
		physical = logical
	}
	return model, physical, logical
}

// LoadAvg 系统负载。
func LoadAvg() (float64, float64, float64) {
	f := strings.Fields(readFirstLine("/proc/loadavg"))
	if len(f) < 3 {
		return 0, 0, 0
	}
	l1, _ := strconv.ParseFloat(f[0], 64)
	l5, _ := strconv.ParseFloat(f[1], 64)
	l15, _ := strconv.ParseFloat(f[2], 64)
	return l1, l5, l15
}

// ProcessCount 进程数。
func ProcessCount() int {
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return 0
	}
	n := 0
	for _, e := range entries {
		if e.IsDir() {
			if _, err := strconv.Atoi(e.Name()); err == nil {
				n++
			}
		}
	}
	return n
}

// Timezone 时区。
func Timezone() string {
	if v := readString("/etc/timezone"); v != "" {
		return v
	}
	link, err := os.Readlink("/etc/localtime")
	if err == nil {
		if i := strings.Index(link, "zoneinfo/"); i >= 0 {
			return link[i+len("zoneinfo/"):]
		}
	}
	return readString("/proc/sys/kernel/timezone")
}

// DNS 解析 /etc/resolv.conf。
func DNS() []string {
	var out []string
	b, err := os.ReadFile("/etc/resolv.conf")
	if err != nil {
		return out
	}
	for _, line := range strings.Split(string(b), "\n") {
		f := strings.Fields(line)
		if len(f) == 2 && f[0] == "nameserver" {
			out = append(out, f[1])
		}
	}
	return out
}

// InternalIP 内网 IP（首个非回环地址）。
func InternalIP() string {
	addrs := GetAddresses()
	for _, a := range addrs {
		if a.IsLoopback() || a.IsLinkLocalUnicast() {
			continue
		}
		if ip4 := a.To4(); ip4 != nil {
			return a.String()
		}
	}
	for _, a := range addrs {
		if a.IsLoopback() || a.IsLinkLocalUnicast() {
			continue
		}
		return a.String()
	}
	return ""
}

// Connections 已建立 TCP 连接数（尽力而为，可能返回 -1 表示不可用）。
func Connections() int {
	n := 0
	for _, proto := range []string{"tcp", "tcp6"} {
		b, err := os.ReadFile("/proc/net/" + proto)
		if err != nil {
			continue
		}
		for _, line := range strings.Split(string(b), "\n")[1:] {
			f := strings.Fields(line)
			if len(f) >= 4 && f[3] == "01" {
				n++
			}
		}
	}
	return n
}
