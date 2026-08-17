package server

import (
	"encoding/json"
	"net/http"

	"mobufan/internal/docker"
)

type dockerHandlers struct {
	c *docker.Client
}

func (s *Server) handleDockerRoutes() *dockerHandlers {
	return &dockerHandlers{c: s.docker}
}

func (h *dockerHandlers) containerList(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用，请检查 socket 路径")
		return
	}
	all := r.URL.Query().Get("all") == "1"
	list, err := h.c.Containers(r.Context(), all)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, list)
}

func (h *dockerHandlers) containerAction(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	id := r.PathValue("id")
	action := r.URL.Query().Get("action")
	if action == "" {
		var body struct {
			Action string `json:"action"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		action = body.Action
	}
	if action == "" {
		writeErr(w, 400, "缺少动作参数 action")
		return
	}
	if err := h.c.ContainerAction(r.Context(), id, action); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "id": id, "action": action})
}

func (h *dockerHandlers) imageList(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	list, err := h.c.Images(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, list)
}

func (h *dockerHandlers) imageRemove(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	id := r.PathValue("id")
	force := r.URL.Query().Get("force") == "1"
	if err := h.c.ImageRemove(r.Context(), id, force); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true})
}

func (h *dockerHandlers) volumeList(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	list, err := h.c.Volumes(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, list)
}

func (h *dockerHandlers) volumeRemove(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	name := r.PathValue("name")
	force := r.URL.Query().Get("force") == "1"
	if err := h.c.VolumeRemove(r.Context(), name, force); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true})
}

func (h *dockerHandlers) networkList(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	list, err := h.c.Networks(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, list)
}

func (h *dockerHandlers) networkRemove(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	id := r.PathValue("id")
	if err := h.c.NetworkRemove(r.Context(), id); err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true})
}

func (h *dockerHandlers) stats(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	list, err := h.c.Stats(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, list)
}

func (h *dockerHandlers) info(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	info, err := h.c.EngineInfo(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, info)
}

func (h *dockerHandlers) df(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	df, err := h.c.DiskUsage(r.Context())
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, df)
}

func (h *dockerHandlers) prune(w http.ResponseWriter, r *http.Request) {
	if !h.c.Enabled() {
		writeErr(w, 503, "Docker 不可用")
		return
	}
	var body struct {
		Target string `json:"target"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Target == "" {
		writeErr(w, 400, "参数错误：需要 {\"target\":\"images\"}")
		return
	}
	res, err := h.c.Prune(r.Context(), body.Target)
	if err != nil {
		writeErr(w, 500, err.Error())
		return
	}
	writeJSON(w, 200, map[string]any{"ok": true, "space_reclaimed": res.SpaceReclaimed})
}
