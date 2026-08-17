package system

import (
	"bufio"
	"os"
	"strings"
	"syscall"
)

// DiskStat 磁盘分区信息（字节）
type DiskStat struct {
	Device   string  `json:"device"`
	Mount    string  `json:"mount"`
	FSType   string  `json:"fstype"`
	Total    uint64  `json:"total"`
	Used     uint64  `json:"used"`
	Free     uint64  `json:"free"`
	UsagePct float64 `json:"usage_percent"`
}

type mountEntry struct {
	device string
	mount  string
	fstype string
}

func readMounts() []mountEntry {
	var out []mountEntry
	f, err := os.Open("/proc/mounts")
	if err != nil {
		return out
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) < 3 {
			continue
		}
		out = append(out, mountEntry{device: f[0], mount: f[1], fstype: f[2]})
	}
	return out
}

// Disk 所有磁盘分区使用情况，去除 tmpfs/overlay 等伪文件系统。
func Disk() []DiskStat {
	var out []DiskStat
	for _, m := range readMounts() {
		if strings.HasPrefix(m.fstype, "tmpfs") ||
			strings.HasPrefix(m.fstype, "devtmpfs") ||
			m.fstype == "overlay" ||
			m.fstype == "squashfs" ||
			m.fstype == "proc" ||
			m.fstype == "sysfs" ||
			m.fstype == "cgroup" ||
			m.fstype == "cgroup2" ||
			m.fstype == "autofs" ||
			m.fstype == "securityfs" ||
			m.fstype == "devpts" ||
			m.fstype == "debugfs" ||
			m.fstype == "pstore" ||
			m.fstype == "mqueue" ||
			m.fstype == "hugetlbfs" ||
			m.fstype == "configfs" ||
			m.fstype == "nsfs" {
			continue
		}
		var st syscall.Statfs_t
		if err := syscall.Statfs(m.mount, &st); err != nil {
			continue
		}
		total := st.Blocks * uint64(st.Bsize)
		free := st.Bavail * uint64(st.Bsize)
		if total == 0 {
			continue
		}
		used := total - free
		dev := m.device
		if dev == "rootfs" || strings.HasPrefix(dev, "/dev/") {
			// 保留原样
		}
		out = append(out, DiskStat{
			Device:   dev,
			Mount:    m.mount,
			FSType:   m.fstype,
			Total:    total,
			Used:     used,
			Free:     free,
			UsagePct: float64(used) / float64(total) * 100,
		})
	}
	return out
}
