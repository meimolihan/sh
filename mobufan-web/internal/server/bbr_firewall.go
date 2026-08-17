package server

import (
	"encoding/json"
	"net/http"

	"mobufan/internal/system"
)

func (s *Server) handleBBRStatus(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, 200, system.BBR())
}

func (s *Server) handleBBREnable(w http.ResponseWriter, r *http.Request) {
	if err := system.EnableBBR(); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "status": system.BBR()})
}

func (s *Server) handleBBRDisable(w http.ResponseWriter, r *http.Request) {
	if err := system.DisableBBR(); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "status": system.BBR()})
}

func (s *Server) handleFirewallChain(w http.ResponseWriter, r *http.Request) {
	chain := r.URL.Query().Get("name")
	if chain == "" {
		chain = "INPUT"
	}
	fc, err := system.FirewallChainInfo(chain)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, fc)
}

type portReq struct {
	Port     string `json:"port"`
	Protocol string `json:"protocol"`
}

func (s *Server) handleFirewallOpen(w http.ResponseWriter, r *http.Request) {
	var req portReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Port == "" {
		writeErr(w, 400, "参数错误：需要 {\"port\":\"8080\",\"protocol\":\"tcp\"}")
		return
	}
	if err := system.FirewallOpenPort(req.Port, req.Protocol); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "port": req.Port, "protocol": req.Protocol})
}

func (s *Server) handleFirewallClose(w http.ResponseWriter, r *http.Request) {
	var req portReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Port == "" {
		writeErr(w, 400, "参数错误：需要 {\"port\":\"8080\",\"protocol\":\"tcp\"}")
		return
	}
	if err := system.FirewallClosePort(req.Port, req.Protocol); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "port": req.Port, "protocol": req.Protocol})
}

type ipReq struct {
	IP string `json:"ip"`
}

func (s *Server) handleFirewallAllowIP(w http.ResponseWriter, r *http.Request) {
	var req ipReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IP == "" {
		writeErr(w, 400, "参数错误：需要 {\"ip\":\"1.2.3.4\"}")
		return
	}
	if err := system.FirewallAllowIP(req.IP); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "ip": req.IP})
}

func (s *Server) handleFirewallBlockIP(w http.ResponseWriter, r *http.Request) {
	var req ipReq
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.IP == "" {
		writeErr(w, 400, "参数错误：需要 {\"ip\":\"1.2.3.4\"}")
		return
	}
	if err := system.FirewallBlockIP(req.IP); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "ip": req.IP})
}

func (s *Server) handleFirewallSave(w http.ResponseWriter, r *http.Request) {
	if err := system.FirewallSave(); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true})
}
