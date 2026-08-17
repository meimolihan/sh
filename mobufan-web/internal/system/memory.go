package system

import (
	"bufio"
	"os"
	"strconv"
	"strings"
)

// MemInfo 内存信息（字节）
type MemInfo struct {
	Total        uint64  `json:"total"`
	Used         uint64  `json:"used"`
	Free         uint64  `json:"free"`
	Available    uint64  `json:"available"`
	Buffers      uint64  `json:"buffers"`
	Cached       uint64  `json:"cached"`
	SwapTotal    uint64  `json:"swap_total"`
	SwapUsed     uint64  `json:"swap_used"`
	UsagePct     float64 `json:"usage_percent"`
	SwapUsagePct float64 `json:"swap_usage_percent"`
}

func parseMemInfo() map[string]uint64 {
	out := map[string]uint64{}
	f, err := os.Open("/proc/meminfo")
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 2 {
			continue
		}
		key := strings.TrimSuffix(fields[0], ":")
		v, err := strconv.ParseUint(fields[1], 10, 64)
		if err != nil {
			continue
		}
		out[key] = v * 1024 // kB -> bytes
	}
	return out
}

// Memory 内存使用情况。
func Memory() MemInfo {
	m := parseMemInfo()
	info := MemInfo{
		Total:     m["MemTotal"],
		Free:      m["MemFree"],
		Available: m["MemAvailable"],
		Buffers:   m["Buffers"],
		Cached:    m["Cached"],
		SwapTotal: m["SwapTotal"],
	}
	if info.Total > 0 {
		if info.Available > 0 {
			info.Used = info.Total - info.Available
		} else {
			info.Used = info.Total - info.Free
		}
		info.UsagePct = float64(info.Used) / float64(info.Total) * 100
	}
	if info.SwapTotal > 0 {
		info.SwapUsed = info.SwapTotal - m["SwapFree"]
		info.SwapUsagePct = float64(info.SwapUsed) / float64(info.SwapTotal) * 100
	}
	return info
}
