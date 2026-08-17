package system

import (
	"bufio"
	"os"
	"strconv"
	"strings"
)

// DefaultInterface 通过 /proc/net/route 解析默认出口网卡。
func DefaultInterface() (string, bool) {
	f, err := os.Open("/proc/net/route")
	if err != nil {
		return "", false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 4 || fields[0] == "Iface" {
			continue
		}
		if fields[1] == "00000000" && fields[3] == "0003" { // destination 0.0.0.0, flags RTF_GATEWAY
			return fields[0], true
		}
	}
	return "", false
}

// DefaultGateway 通过 /proc/net/route 解析默认网关 IP（IPv4）。
func DefaultGateway() (string, bool) {
	f, err := os.Open("/proc/net/route")
	if err != nil {
		return "", false
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 3 || fields[0] == "Iface" {
			continue
		}
		if fields[1] == "00000000" {
			return hexIPToDot(fields[2]), true
		}
	}
	return "", false
}

// hexIPToDot 将 /proc/net/route 中倒序十六进制 IP 转为点分十进制。
func hexIPToDot(hex string) string {
	if len(hex) != 8 {
		return hex
	}
	// 每两位一段，按小端序排列
	parts := make([]string, 4)
	for i := 0; i < 4; i++ {
		v, _ := strconvParseHex(hex[6-2*i : 8-2*i])
		parts[i] = strconv.Itoa(v)
	}
	return strings.Join(parts, ".")
}

func strconvParseHex(s string) (int, bool) {
	n := 0
	for _, c := range s {
		n *= 16
		switch {
		case c >= '0' && c <= '9':
			n += int(c - '0')
		case c >= 'a' && c <= 'f':
			n += int(c-'a') + 10
		case c >= 'A' && c <= 'F':
			n += int(c-'A') + 10
		default:
			return 0, false
		}
	}
	return n, true
}
