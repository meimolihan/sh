package system

import (
	"bufio"
	"os"
	"strconv"
	"strings"
	"time"
)

type cpuTimes struct {
	idle  uint64
	total uint64
}

func readCPUTimes() cpuTimes {
	f, err := os.Open("/proc/stat")
	if err != nil {
		return cpuTimes{}
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		if !strings.HasPrefix(line, "cpu ") {
			continue
		}
		f := strings.Fields(line)
		var total uint64
		for _, v := range f[1:] {
			n, _ := strconv.ParseUint(v, 10, 64)
			total += n
		}
		idle := uint64(0)
		if len(f) >= 5 {
			idle, _ = strconv.ParseUint(f[4], 10, 64)
		}
		var iowait uint64
		if len(f) >= 6 {
			iowait, _ = strconv.ParseUint(f[5], 10, 64)
		}
		return cpuTimes{idle: idle + iowait, total: total}
	}
	return cpuTimes{}
}

// CPUUsage 两次采样计算 CPU 使用率（0-100）。
func CPUUsage() float64 {
	prev := readCPUTimes()
	time.Sleep(200 * time.Millisecond)
	cur := readCPUTimes()
	dTotal := cur.total - prev.total
	if dTotal == 0 {
		return 0
	}
	dIdle := cur.idle - prev.idle
	return (1 - float64(dIdle)/float64(dTotal)) * 100
}

// CPUStat 单核信息
type CPUStat struct {
	Core         int     `json:"core"`
	UsagePercent float64 `json:"usage_percent"`
}
