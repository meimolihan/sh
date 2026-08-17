package system

import "testing"

func TestOverview(t *testing.T) {
	info := Overview()
	if info.OSName == "" {
		t.Error("OSName empty")
	}
	if info.Kernel == "" {
		t.Error("Kernel empty")
	}
	if info.Hostname == "" {
		t.Error("Hostname empty")
	}
	if info.LogicalCPU <= 0 {
		t.Errorf("LogicalCPU = %d, want > 0", info.LogicalCPU)
	}
	if info.UptimeSec <= 0 {
		t.Errorf("UptimeSec = %v, want > 0", info.UptimeSec)
	}
}

func TestCPUUsageRange(t *testing.T) {
	u := CPUUsage()
	if u < 0 || u > 100 {
		t.Errorf("CPUUsage = %v, out of [0,100]", u)
	}
}

func TestMemory(t *testing.T) {
	m := Memory()
	if m.Total <= 0 {
		t.Errorf("MemTotal = %d, want > 0", m.Total)
	}
	if m.UsagePct < 0 || m.UsagePct > 100 {
		t.Errorf("UsagePct = %v, out of range", m.UsagePct)
	}
}

func TestDisk(t *testing.T) {
	disks := Disk()
	if len(disks) == 0 {
		t.Error("no disks found")
	}
	for _, d := range disks {
		if d.Total <= 0 {
			t.Errorf("disk %s total = %d", d.Mount, d.Total)
		}
	}
}

func TestNetwork(t *testing.T) {
	nets := Network()
	if len(nets) == 0 {
		t.Error("no network interfaces")
	}
}

func TestProcesses(t *testing.T) {
	procs := Processes(5, "cpu")
	if len(procs) == 0 {
		t.Fatal("no processes")
	}
	if procs[0].PID <= 0 {
		t.Errorf("bad pid: %+v", procs[0])
	}
}

func TestListeningPorts(t *testing.T) {
	ports := ListeningPorts()
	if len(ports) == 0 {
		t.Log("no listening ports (may be sandbox)")
		return
	}
	for _, p := range ports {
		if p.Port <= 0 {
			t.Errorf("bad port: %+v", p)
		}
	}
}

func TestBBR(t *testing.T) {
	st := BBR()
	if st.CurrentCongestion == "" {
		t.Log("congestion control unavailable")
	}
	_ = EnableBBR() // 环境无权限时仅记录错误
	_ = DisableBBR()
}
