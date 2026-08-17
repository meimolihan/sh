package system

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// PortInfo 监听端口信息
type PortInfo struct {
	Protocol string `json:"protocol"`
	Address  string `json:"address"`
	Port     int    `json:"port"`
	PID      int    `json:"pid"`
	Process  string `json:"process"`
}

// mapSocketInodeToPID 扫描 /proc/<pid>/fd 的 socket 软链，建立 inode -> pid 映射。
func mapSocketInodeToPID() map[string]int {
	out := map[string]int{}
	dirs, err := os.ReadDir("/proc")
	if err != nil {
		return out
	}
	for _, d := range dirs {
		if !d.IsDir() {
			continue
		}
		pid, err := strconv.Atoi(d.Name())
		if err != nil {
			continue
		}
		fdDir := filepath.Join("/proc", d.Name(), "fd")
		links, err := os.ReadDir(fdDir)
		if err != nil {
			continue
		}
		for _, l := range links {
			target, err := os.Readlink(filepath.Join(fdDir, l.Name()))
			if err != nil {
				continue
			}
			if strings.HasPrefix(target, "socket:[") && strings.HasSuffix(target, "]") {
				inode := strings.TrimSuffix(strings.TrimPrefix(target, "socket:["), "]")
				if _, exists := out[inode]; !exists {
					out[inode] = pid
				}
			}
		}
	}
	return out
}

func hexPortToInt(hex string) int {
	n, _ := strconv.ParseUint(hex, 16, 16)
	return int(n)
}

func hexAddrToIP(hex string, v6 bool) string {
	if !v6 {
		return hexIPv4(hex)
	}
	// tcp6: 32 个十六进制字符，8 组 4 字符，大端序
	if len(hex) == 32 {
		var groups []string
		for i := 0; i < 8; i++ {
			g := hex[i*4 : i*4+4]
			groups = append(groups, g)
		}
		ip := net.ParseIP(strings.Join(groups, ":"))
		if ip != nil {
			if ip4 := ip.To4(); ip4 != nil {
				return ip4.String()
			}
			return ip.String()
		}
	}
	return hex
}

// hexIPv4 /proc/net/tcp 中为小端序 8 位十六进制。
func hexIPv4(hex string) string {
	if len(hex) != 8 {
		return hex
	}
	b := make([]byte, 4)
	for i := 0; i < 4; i++ {
		n, _ := strconv.ParseUint(hex[i*2:i*2+2], 16, 8)
		b[3-i] = byte(n)
	}
	return fmt.Sprintf("%d.%d.%d.%d", b[0], b[1], b[2], b[3])
}

func parseNetTable(path string, protocol string, v6 bool, inodePID map[string]int, out *[]PortInfo) {
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	first := true
	for sc.Scan() {
		if first {
			first = false
			continue
		}
		fields := strings.Fields(sc.Text())
		if len(fields) < 10 {
			continue
		}
		// fields[1] local_address, fields[3] st, fields[9] inode
		if fields[3] != "0A" { // LISTEN
			continue
		}
		addrPort := strings.SplitN(fields[1], ":", 2)
		if len(addrPort) != 2 {
			continue
		}
		ip := hexAddrToIP(addrPort[0], v6)
		port := hexPortToInt(addrPort[1])
		inode := fields[9]
		pid := inodePID[inode]
		procName := ""
		if pid > 0 {
			procName = readString(filepath.Join("/proc", strconv.Itoa(pid), "comm"))
		}
		*out = append(*out, PortInfo{
			Protocol: protocol,
			Address:  ip,
			Port:     port,
			PID:      pid,
			Process:  procName,
		})
	}
}

// ListeningPorts 监听端口列表（TCP/TCP6/UDP/UDP6）。
func ListeningPorts() []PortInfo {
	var out []PortInfo
	inodePID := mapSocketInodeToPID()
	parseNetTable("/proc/net/tcp", "tcp", false, inodePID, &out)
	parseNetTable("/proc/net/tcp6", "tcp6", true, inodePID, &out)
	parseNetTable("/proc/net/udp", "udp", false, inodePID, &out)
	parseNetTable("/proc/net/udp6", "udp6", true, inodePID, &out)
	return out
}
