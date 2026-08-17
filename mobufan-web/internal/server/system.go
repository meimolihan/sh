package server

import (
	"net/http"
	"strconv"

	"mobufan/internal/system"
)

func (s *Server) handleSystemInfo(w http.ResponseWriter, r *http.Request) {
	info := system.Overview()
	info.PublicIP = system.PublicIP()
	writeJSON(w, 200, info)
}

func (s *Server) handlePublicIP(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, map[string]string{"ip": system.PublicIP()})
}

func (s *Server) handleSystemCPU(w http.ResponseWriter, r *http.Request) {
	usage := system.CPUUsage()
	model, phys, logical := system.CPUInfo()
	writeJSON(w, 200, map[string]any{
		"usage_percent": round(usage),
		"cpu_model":     model,
		"physical_cpu":  phys,
		"logical_cpu":   logical,
	})
}

func (s *Server) handleSystemMemory(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, system.Memory())
}

func (s *Server) handleSystemDisk(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, system.Disk())
}

func (s *Server) handleSystemNetwork(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, system.Network())
}

func (s *Server) handleSystemProcesses(w http.ResponseWriter, r *http.Request) {
	limit := 30
	sortBy := "cpu"
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	if v := r.URL.Query().Get("sort"); v == "mem" {
		sortBy = "mem"
	}
	writeJSON(w, 200, system.Processes(limit, sortBy))
}

func (s *Server) handleSystemPorts(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, system.ListeningPorts())
}

func round(v float64) float64 {
	return float64(int(v*10+0.5)) / 10
}
