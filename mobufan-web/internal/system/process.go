package system

import (
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const userHZ = 100.0

// Proc 进程信息
type Proc struct {
	PID     int     `json:"pid"`
	PPID    int     `json:"ppid"`
	User    string  `json:"user"`
	Name    string  `json:"name"`
	Command string  `json:"command"`
	State   string  `json:"state"`
	CPU     float64 `json:"cpu_percent"`
	Mem     float64 `json:"mem_percent"`
	RSS     uint64  `json:"rss_bytes"`
}

func pidDirs() []int {
	var out []int
	entries, err := os.ReadDir("/proc")
	if err != nil {
		return out
	}
	for _, e := range entries {
		if !e.IsDir() {
			continue
		}
		if pid, err := strconv.Atoi(e.Name()); err == nil {
			out = append(out, pid)
		}
	}
	return out
}

// readProcStat 解析 /proc/<pid>/stat 关键字段。
func readProcStat(pid int) (comm string, ppid int, utime, stime uint64, rssPages uint64, state string, ok bool) {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "stat"))
	if err != nil {
		return "", 0, 0, 0, 0, "", false
	}
	s := string(b)
	right := strings.LastIndexByte(s, ')')
	if right < 0 {
		return "", 0, 0, 0, 0, "", false
	}
	comm = strings.TrimSpace(s[strings.IndexByte(s, '(')+1 : right])
	rest := strings.Fields(s[right+1:])
	if len(rest) < 22 {
		return comm, 0, 0, 0, 0, "", false
	}
	state = rest[0]
	ppid, _ = strconv.Atoi(rest[1])
	utime, _ = strconv.ParseUint(rest[11], 10, 64)    // field 14
	stime, _ = strconv.ParseUint(rest[12], 10, 64)    // field 15
	rssPages, _ = strconv.ParseUint(rest[21], 10, 64) // field 24
	return comm, ppid, utime, stime, rssPages, state, true
}

func readProcUid(pid int) string {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "status"))
	if err != nil {
		return ""
	}
	for _, line := range strings.Split(string(b), "\n") {
		if strings.HasPrefix(line, "Uid:") {
			f := strings.Fields(line)
			if len(f) >= 2 {
				return f[1]
			}
		}
	}
	return ""
}

func readProcCmdline(pid int) string {
	b, err := os.ReadFile(filepath.Join("/proc", strconv.Itoa(pid), "cmdline"))
	if err != nil || len(b) == 0 {
		return ""
	}
	parts := strings.Split(string(b), "\x00")
	var out []string
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return strings.Join(out, " ")
}

// snapshotProc 采集一次进程 CPU 时间快照。
func snapshotProc() map[int]uint64 {
	out := map[int]uint64{}
	for _, pid := range pidDirs() {
		_, _, ut, st, _, _, ok := readProcStat(pid)
		if ok {
			out[pid] = ut + st
		}
	}
	return out
}

// Processes 返回进程列表，sortBy 为 "cpu" 或 "mem"。
func Processes(limit int, sortBy string) []Proc {
	if limit <= 0 {
		limit = 30
	}
	prev := snapshotProc()
	time.Sleep(150 * time.Millisecond)
	pageSize := uint64(os.Getpagesize())

	var procs []Proc
	for _, pid := range pidDirs() {
		comm, ppid, ut, st, rssPages, state, ok := readProcStat(pid)
		if !ok {
			continue
		}
		cpuTime, existed := prev[pid]
		if !existed {
			continue // 采样期间新起的进程，跳过
		}
		cur := ut + st
		dt := cur - cpuTime
		cpuPct := float64(dt) / userHZ / 0.15 * 100
		uid := readProcUid(pid)
		cmd := readProcCmdline(pid)
		name := comm
		if cmd != "" {
			name = cmd
		}
		procs = append(procs, Proc{
			PID:     pid,
			PPID:    ppid,
			User:    uid,
			Name:    name,
			Command: cmd,
			State:   state,
			CPU:     round1(cpuPct),
			RSS:     rssPages * pageSize,
		})
	}

	if sortBy == "mem" {
		sort.Slice(procs, func(i, j int) bool { return procs[i].RSS > procs[j].RSS })
	} else {
		sort.Slice(procs, func(i, j int) bool { return procs[i].CPU > procs[j].CPU })
	}
	if len(procs) > limit {
		procs = procs[:limit]
	}

	// 计算内存占比
	memTotal := Memory().Total
	for i := range procs {
		if memTotal > 0 {
			procs[i].Mem = round1(float64(procs[i].RSS) / float64(memTotal) * 100)
		}
	}
	return procs
}

func round1(v float64) float64 {
	return float64(int(v*10+0.5)) / 10
}
