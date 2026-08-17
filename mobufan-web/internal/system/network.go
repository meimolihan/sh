package system

import (
	"bufio"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// NetIf 网络接口信息
type NetIf struct {
	Name      string `json:"name"`
	State     string `json:"state"`
	MAC       string `json:"mac"`
	IPv4      string `json:"ipv4"`
	MTU       string `json:"mtu"`
	Speed     string `json:"speed"`
	RxBytes   uint64 `json:"rx_bytes"`
	TxBytes   uint64 `json:"tx_bytes"`
	IsDefault bool   `json:"is_default"`
}

// GetAddresses 返回本机全部 IP 地址。
func GetAddresses() []net.IP {
	var out []net.IP
	ifaces, err := net.Interfaces()
	if err != nil {
		return out
	}
	for _, ifc := range ifaces {
		addrs, err := ifc.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			ipnet, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			out = append(out, ipnet.IP)
		}
	}
	return out
}

func readNetDev() map[string][2]uint64 {
	out := map[string][2]uint64{}
	f, err := os.Open("/proc/net/dev")
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if !strings.Contains(line, ":") {
			continue
		}
		parts := strings.SplitN(line, ":", 2)
		name := strings.TrimSpace(parts[0])
		fields := strings.Fields(parts[1])
		if len(fields) < 16 {
			continue
		}
		rx, _ := strconv.ParseUint(fields[0], 10, 64)
		tx, _ := strconv.ParseUint(fields[8], 10, 64)
		out[name] = [2]uint64{rx, tx}
	}
	return out
}

// Network 网络接口列表。
func Network() []NetIf {
	var out []NetIf
	dir, err := os.ReadDir("/sys/class/net")
	if err != nil {
		return out
	}
	traffic := readNetDev()
	defaultIface := ""
	if def, ok := DefaultInterface(); ok {
		defaultIface = def
	}
	for _, e := range dir {
		name := e.Name()
		base := filepath.Join("/sys/class/net", name)
		state := readString(filepath.Join(base, "operstate"))
		if state == "" {
			state = "unknown"
		}
		mac := readString(filepath.Join(base, "address"))
		mtu := readString(filepath.Join(base, "mtu"))
		speed := "N/A"
		if s := readString(filepath.Join(base, "speed")); s != "" && s != "-1" {
			speed = s + "Mb/s"
		}

		ipv4 := ""
		iface, err := net.InterfaceByName(name)
		if err == nil {
			addrs, _ := iface.Addrs()
			for _, a := range addrs {
				ipnet, ok := a.(*net.IPNet)
				if !ok {
					continue
				}
				if ip4 := ipnet.IP.To4(); ip4 != nil {
					ipv4 = ipnet.IP.String()
					break
				}
			}
		}

		ni := NetIf{
			Name:      name,
			State:     state,
			MAC:       mac,
			IPv4:      ipv4,
			MTU:       mtu,
			Speed:     speed,
			IsDefault: name == defaultIface,
		}
		if t, ok := traffic[name]; ok {
			ni.RxBytes = t[0]
			ni.TxBytes = t[1]
		}
		out = append(out, ni)
	}
	return out
}
