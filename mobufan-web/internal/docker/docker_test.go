package docker

import (
	"context"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

// startFakeDocker 启动一个模拟 Docker Engine API 的 unix socket 服务。
func startFakeDocker(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	sock := filepath.Join(dir, "docker.sock")
	os.Remove(sock)
	ln, err := net.Listen("unix", sock)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ln.Close() })

	mux := http.NewServeMux()

	mux.HandleFunc("GET /containers/json", func(w http.ResponseWriter, r *http.Request) {
		list := []map[string]any{{
			"Id":      "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
			"Names":   []string{"/web"},
			"Image":   "nginx:latest",
			"Command": "nginx -g daemon off;",
			"Created": 1700000000,
			"State":   "running",
			"Status":  "Up 2 minutes",
			"Ports":   []map[string]any{{"IP": "0.0.0.0", "PrivatePort": 80, "PublicPort": 8080, "Type": "tcp"}},
		}}
		json.NewEncoder(w).Encode(list)
	})

	mux.HandleFunc("POST /containers/{id}/{action}", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(204)
	})

	mux.HandleFunc("DELETE /containers/{id}", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(204)
	})

	mux.HandleFunc("GET /images/json", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]map[string]any{
			{"Id": "abcdefabcdefabcdefabcdefabcdefabcdef", "RepoTags": []string{"nginx:latest"}, "Created": 1700000000, "Size": 1000},
		})
	})

	mux.HandleFunc("GET /volumes", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"Volumes": []map[string]any{
			{"Name": "data", "Driver": "local", "Mountpoint": "/var/lib/docker/volumes/data/_data"},
		}})
	})

	mux.HandleFunc("GET /networks", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode([]map[string]any{
			{"Id": "netid", "Name": "bridge", "Driver": "bridge", "Scope": "local"},
		})
	})

	mux.HandleFunc("GET /info", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"ServerVersion": "26.1.0", "Containers": 2, "ContainersRunning": 1,
			"ContainersPaused": 0, "ContainersStopped": 1, "Images": 5,
			"Driver": "overlay2", "MemTotal": 8000000000, "NCPU": 4,
			"OperatingSystem": "TestOS", "Architecture": "x86_64", "KernelVersion": "6.0",
		})
	})

	mux.HandleFunc("GET /containers/{id}/stats", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"cpu_stats": map[string]any{
				"cpu_usage":        map[string]any{"total_usage": 2000},
				"system_cpu_usage": 10000,
				"online_cpus":      4,
			},
			"precpu_stats": map[string]any{
				"cpu_usage":        map[string]any{"total_usage": 1000},
				"system_cpu_usage": 9000,
			},
			"memory_stats": map[string]any{"usage": 5000000, "limit": 8000000000},
			"networks":     map[string]any{"eth0": map[string]any{"rx_bytes": 100, "tx_bytes": 200}},
			"pids_stats":   map[string]any{"current": 3},
			"blkio_stats":  map[string]any{},
		})
	})

	mux.HandleFunc("GET /system/df", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{
			"LayersSize": 100,
			"Images":     []map[string]any{{"Size": 50}},
			"Containers": []map[string]any{{"SizeRw": 5, "SizeRootFs": 5}},
			"Volumes":    []map[string]any{{"Size": 30}},
			"BuildCache": []map[string]any{{"Size": 10}},
		})
	})

	mux.HandleFunc("POST /containers/prune", func(w http.ResponseWriter, r *http.Request) {
		json.NewEncoder(w).Encode(map[string]any{"SpaceReclaimed": 42})
	})

	srv := &http.Server{Handler: mux}
	go srv.Serve(ln)
	t.Cleanup(func() { srv.Close() })
	return sock
}

func TestContainers(t *testing.T) {
	c := New(startFakeDocker(t))
	ctx := context.Background()

	list, err := c.Containers(ctx, true)
	if err != nil {
		t.Fatal(err)
	}
	if len(list) != 1 || list[0].State != "running" || list[0].ShortID != "0123456789ab" {
		t.Fatalf("unexpected containers: %+v", list)
	}
	if list[0].Ports[0].PublicPort != 8080 {
		t.Fatalf("unexpected ports: %+v", list[0].Ports)
	}
}

func TestContainerActionAndRemove(t *testing.T) {
	c := New(startFakeDocker(t))
	ctx := context.Background()
	if err := c.ContainerAction(ctx, "abc", "stop"); err != nil {
		t.Fatal(err)
	}
	if err := c.ContainerAction(ctx, "abc", "remove"); err != nil {
		t.Fatal(err)
	}
	if err := c.ContainerAction(ctx, "abc", "bogus"); err == nil {
		t.Fatal("expected error for unknown action")
	}
}

func TestImagesVolumesNetworks(t *testing.T) {
	c := New(startFakeDocker(t))
	ctx := context.Background()

	imgs, err := c.Images(ctx)
	if err != nil || len(imgs) != 1 || imgs[0].RepoTags[0] != "nginx:latest" {
		t.Fatalf("images: %+v err=%v", imgs, err)
	}
	vols, err := c.Volumes(ctx)
	if err != nil || len(vols) != 1 || vols[0].Name != "data" {
		t.Fatalf("volumes: %+v err=%v", vols, err)
	}
	nets, err := c.Networks(ctx)
	if err != nil || len(nets) != 1 || nets[0].Driver != "bridge" {
		t.Fatalf("networks: %+v err=%v", nets, err)
	}
}

func TestInfoStatsDFPrune(t *testing.T) {
	c := New(startFakeDocker(t))
	ctx := context.Background()

	info, err := c.EngineInfo(ctx)
	if err != nil || info.ServerVersion != "26.1.0" || info.Running != 1 {
		t.Fatalf("info: %+v err=%v", info, err)
	}
	stats, err := c.Stats(ctx)
	if err != nil || len(stats) != 1 || stats[0].CPU <= 0 {
		t.Fatalf("stats: %+v err=%v", stats, err)
	}
	df, err := c.DiskUsage(ctx)
	if err != nil {
		t.Fatal(err)
	}
	total := df.Images + df.Containers + df.Volumes + df.BuildCache + df.LayersSize
	if total != 200 {
		t.Fatalf("df totals wrong: %+v", df)
	}
	res, err := c.Prune(ctx, "containers")
	if err != nil || res.SpaceReclaimed != 42 {
		t.Fatalf("prune: %+v err=%v", res, err)
	}
}

func TestDisabled(t *testing.T) {
	c := New("")
	if c.Enabled() {
		t.Fatal("should be disabled with empty sock path")
	}
	if _, err := c.Containers(context.Background(), true); err == nil {
		t.Fatal("expected error on disabled client")
	}
	// socket 文件不存在时应判定不可用
	c2 := New("/nonexistent/docker.sock")
	if c2.Enabled() {
		t.Fatal("should be disabled when socket file missing")
	}
}
