package system

import (
	"fmt"
	"os"
	"strings"
)

// BBRStatus BBR 状态
type BBRStatus struct {
	CurrentCongestion   string   `json:"current_congestion"`
	AvailableCongestion []string `json:"available_congestion"`
	BBRSupported        bool     `json:"bbr_supported"`
	BBREnabled          bool     `json:"bbr_enabled"`
	DefaultQdisc        string   `json:"default_qdisc"`
	ParamsEnabled       []string `json:"params_enabled"`
}

// BBR 当前状态。
func BBR() BBRStatus {
	st := BBRStatus{
		CurrentCongestion:   readString("/proc/sys/net/ipv4/tcp_congestion_control"),
		DefaultQdisc:        readString("/proc/sys/net/core/default_qdisc"),
		AvailableCongestion: strings.Fields(readString("/proc/sys/net/ipv4/tcp_available_congestion_control")),
	}
	for _, c := range st.AvailableCongestion {
		if c == "bbr" {
			st.BBRSupported = true
		}
	}
	st.BBREnabled = st.CurrentCongestion == "bbr"
	if st.CurrentCongestion == "bbr" {
		st.ParamsEnabled = append(st.ParamsEnabled, "tcp_congestion_control=bbr")
	}
	if st.DefaultQdisc == "fq" {
		st.ParamsEnabled = append(st.ParamsEnabled, "default_qdisc=fq")
	}
	if readString("/proc/sys/net/ipv4/tcp_notsent_lowat") == "16384" {
		st.ParamsEnabled = append(st.ParamsEnabled, "tcp_notsent_lowat=16384")
	}
	return st
}

// writeSysctl 写入内核参数并返回是否成功。
func writeSysctl(path, value string) error {
	return os.WriteFile(path, []byte(value), 0)
}

// EnableBBR 启用 BBR + fq。
func EnableBBR() error {
	st := BBR()
	if !st.BBRSupported {
		return fmt.Errorf("内核不支持 BBR（tcp_available_congestion_control 中无 bbr），请先更换内核")
	}
	if err := writeSysctl("/proc/sys/net/ipv4/tcp_congestion_control", "bbr"); err != nil {
		return fmt.Errorf("写入 tcp_congestion_control 失败（需要 root）：%v", err)
	}
	if err := writeSysctl("/proc/sys/net/core/default_qdisc", "fq"); err != nil {
		return fmt.Errorf("写入 default_qdisc 失败：%v", err)
	}
	_ = writeSysctl("/proc/sys/net/ipv4/tcp_notsent_lowat", "16384")
	return nil
}

// DisableBBR 关闭 BBR，恢复 cubic + pfifo_fast。
func DisableBBR() error {
	if err := writeSysctl("/proc/sys/net/ipv4/tcp_congestion_control", "cubic"); err != nil {
		return fmt.Errorf("写入 tcp_congestion_control 失败（需要 root）：%v", err)
	}
	if err := writeSysctl("/proc/sys/net/core/default_qdisc", "pfifo_fast"); err != nil {
		return fmt.Errorf("写入 default_qdisc 失败：%v", err)
	}
	return nil
}
