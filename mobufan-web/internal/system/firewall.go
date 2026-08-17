package system

import (
	"os"
	"os/exec"
	"strings"
)

// FirewallRule 一条 iptables 规则
type FirewallRule struct {
	Num      int    `json:"num"`
	Target   string `json:"target"`
	Protocol string `json:"protocol"`
	Source   string `json:"source"`
	Dest     string `json:"dest"`
	Port     string `json:"port"`
}

// FirewallChain 一个 iptables 链
type FirewallChain struct {
	Name   string         `json:"name"`
	Policy string         `json:"policy"`
	Rules  []FirewallRule `json:"rules"`
	Raw    string         `json:"raw"`
}

func iptablesExists() bool {
	_, err := exec.LookPath("iptables")
	return err == nil
}

// FirewallChainInfo 获取指定链规则（需要 root）。
func FirewallChainInfo(chain string) (FirewallChain, error) {
	var fc FirewallChain
	fc.Name = chain
	if !iptablesExists() {
		return fc, errorsNew("系统未安装 iptables")
	}
	out, err := exec.Command("iptables", "-L", chain, "-n", "--line-numbers").Output()
	if err != nil {
		return fc, errorsNew("读取 iptables 失败（需要 root 权限）: " + string(stderrString(err)))
	}
	fc.Raw = strings.TrimRight(string(out), "\n")

	lines := strings.Split(fc.Raw, "\n")
	for i, line := range lines {
		f := strings.Fields(line)
		if i == 0 && len(f) >= 2 {
			pol := ""
			for _, part := range f {
				if strings.HasPrefix(part, "policy") {
					pol = "自定义"
				}
			}
			_ = pol
			if strings.Contains(line, "policy ACCEPT") {
				fc.Policy = "ACCEPT"
			} else if strings.Contains(line, "policy DROP") {
				fc.Policy = "DROP"
			} else if strings.Contains(line, "policy REJECT") {
				fc.Policy = "REJECT"
			}
		}
		if len(f) >= 6 {
			if n, err := atoi(f[0]); err == nil {
				r := FirewallRule{
					Num:      n,
					Target:   f[1],
					Protocol: f[2],
					Source:   f[4],
					Dest:     f[5],
				}
				for _, p := range f[6:] {
					if strings.HasPrefix(p, "dpt:") {
						r.Port = strings.TrimPrefix(p, "dpt:")
						break
					}
					if strings.HasPrefix(p, "spt:") {
						r.Port = strings.TrimPrefix(p, "spt:")
						break
					}
					if strings.HasPrefix(p, "multiport") {
						r.Port = "多端口"
						break
					}
				}
				if r.Port == "" {
					for _, p := range f[6:] {
						if strings.HasPrefix(p, "dport") {
							parts := strings.SplitN(p, " ", 2)
							r.Port = parts[len(parts)-1]
							break
						}
					}
				}
				fc.Rules = append(fc.Rules, r)
			}
		}
	}
	return fc, nil
}

// FirewallOpenPort 开放端口。
func FirewallOpenPort(port string, proto string) error {
	if !iptablesExists() {
		return errorsNew("系统未安装 iptables")
	}
	if proto == "" {
		proto = "tcp"
	}
	args := []string{"-I", "INPUT", "-p", proto, "--dport", port, "-j", "ACCEPT"}
	return runIptables(args)
}

// FirewallClosePort 关闭端口。
func FirewallClosePort(port string, proto string) error {
	if !iptablesExists() {
		return errorsNew("系统未安装 iptables")
	}
	if proto == "" {
		proto = "tcp"
	}
	args := []string{"-D", "INPUT", "-p", proto, "--dport", port, "-j", "ACCEPT"}
	return runIptables(args)
}

// FirewallAllowIP 放行 IP。
func FirewallAllowIP(ip string) error {
	if !iptablesExists() {
		return errorsNew("系统未安装 iptables")
	}
	return runIptables([]string{"-I", "INPUT", "-s", ip, "-j", "ACCEPT"})
}

// FirewallBlockIP 阻止 IP。
func FirewallBlockIP(ip string) error {
	if !iptablesExists() {
		return errorsNew("系统未安装 iptables")
	}
	return runIptables([]string{"-I", "INPUT", "-s", ip, "-j", "DROP"})
}

// FirewallSave 保存规则（尝试常见路径）。
func FirewallSave() error {
	if !iptablesExists() {
		return errorsNew("系统未安装 iptables")
	}
	targets := []string{"/etc/iptables/rules.v4", "/etc/sysconfig/iptables", "/etc/iptables.rules"}
	cmd := exec.Command("iptables-save")
	var sb strings.Builder
	cmd.Stdout = &sb
	if err := cmd.Run(); err != nil {
		return errorsNew("iptables-save 执行失败: " + err.Error())
	}
	for _, t := range targets {
		if err := os.WriteFile(t, []byte(sb.String()), 0o600); err == nil {
			return nil
		}
	}
	return errorsNew("无法写入规则文件，请手动运行 iptables-save")
}

func runIptables(args []string) error {
	out, err := exec.Command("iptables", args...).CombinedOutput()
	if err != nil {
		msg := strings.TrimSpace(string(out))
		if msg != "" {
			return errorsNew("iptables " + strings.Join(args, " ") + ": " + msg)
		}
		return errorsNew("iptables " + strings.Join(args, " ") + ": " + err.Error())
	}
	return nil
}

func errorsNew(s string) error {
	return &errString{s}
}

type errString struct{ s string }

func (e *errString) Error() string { return e.s }

func stderrString(err error) string {
	if ee, ok := err.(*exec.ExitError); ok {
		return strings.TrimSpace(string(ee.Stderr))
	}
	return ""
}

func atoi(s string) (int, error) {
	n := 0
	if s == "" {
		return 0, errorsNew("empty")
	}
	for _, c := range s {
		if c < '0' || c > '9' {
			return 0, errorsNew("not a number")
		}
		n = n*10 + int(c-'0')
	}
	return n, nil
}
