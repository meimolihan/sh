// Package docker 通过 unix socket 直连 Docker Engine API，纯标准库实现。
package docker

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

// Client Docker API 客户端
type Client struct {
	sockPath string
	http     *http.Client
	enabled  bool
}

// New 创建客户端；sockPath 为空则禁用。
func New(sockPath string) *Client {
	c := &Client{sockPath: sockPath}
	if sockPath == "" {
		return c
	}
	c.http = &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				d := net.Dialer{}
				return d.DialContext(ctx, "unix", sockPath)
			},
		},
	}
	c.enabled = true
	return c
}

// Enabled 是否可用（socket 路径存在且已初始化）。
func (c *Client) Enabled() bool {
	if !c.enabled {
		return false
	}
	if _, err := os.Stat(c.sockPath); err != nil {
		return false
	}
	return true
}

func (c *Client) baseURL() string {
	return "http://docker"
}

func (c *Client) do(ctx context.Context, method, path string, query url.Values, body io.Reader) ([]byte, error) {
	if !c.Enabled() {
		return nil, fmt.Errorf("Docker 不可用（socket: %s）", c.sockPath)
	}
	u := c.baseURL() + path
	if len(query) > 0 {
		u += "?" + query.Encode()
	}
	req, err := http.NewRequestWithContext(ctx, method, u, body)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("连接 Docker 失败：%v", err)
	}
	defer resp.Body.Close()
	b, err := io.ReadAll(io.LimitReader(resp.Body, 64<<20))
	if err != nil {
		return nil, err
	}
	if resp.StatusCode >= 400 {
		msg := strings.TrimSpace(string(b))
		if msg == "" {
			msg = resp.Status
		}
		return nil, fmt.Errorf("Docker API %d: %s", resp.StatusCode, msg)
	}
	return b, nil
}

// --- 数据结构 ---

// PortMap 端口映射
type PortMap struct {
	IP          string `json:"ip"`
	PrivatePort uint16 `json:"private_port"`
	PublicPort  uint16 `json:"public_port"`
	Type        string `json:"type"`
}

// rawPort 与 Docker API 原始字段完全一致的端口结构（Docker 返回大写键名）。
type rawPort struct {
	IP          string `json:"IP"`
	PrivatePort uint16 `json:"PrivatePort"`
	PublicPort  uint16 `json:"PublicPort"`
	Type        string `json:"Type"`
}

// Container 容器概要
type Container struct {
	ID      string    `json:"id"`
	ShortID string    `json:"short_id"`
	Names   string    `json:"names"`
	Image   string    `json:"image"`
	Command string    `json:"command"`
	Created int64     `json:"created"`
	State   string    `json:"state"`
	Status  string    `json:"status"`
	Ports   []PortMap `json:"ports"`
}

type rawContainer struct {
	Id      string    `json:"Id"`
	Names   []string  `json:"Names"`
	Image   string    `json:"Image"`
	Command string    `json:"Command"`
	Created int64     `json:"Created"`
	State   string    `json:"State"`
	Status  string    `json:"Status"`
	Ports   []rawPort `json:"Ports"`
}

// Containers 容器列表。
func (c *Client) Containers(ctx context.Context, all bool) ([]Container, error) {
	q := url.Values{}
	if all {
		q.Set("all", "1")
	}
	b, err := c.do(ctx, "GET", "/containers/json", q, nil)
	if err != nil {
		return nil, err
	}
	var raws []rawContainer
	if err := json.Unmarshal(b, &raws); err != nil {
		return nil, err
	}
	out := make([]Container, 0, len(raws))
	for _, r := range raws {
		names := strings.Join(r.Names, ", ")
		ports := make([]PortMap, 0, len(r.Ports))
		for _, p := range r.Ports {
			ports = append(ports, PortMap{
				IP:          p.IP,
				PrivatePort: p.PrivatePort,
				PublicPort:  p.PublicPort,
				Type:        p.Type,
			})
		}
		out = append(out, Container{
			ID:      r.Id,
			ShortID: shortID(r.Id),
			Names:   names,
			Image:   r.Image,
			Command: r.Command,
			Created: r.Created,
			State:   r.State,
			Status:  r.Status,
			Ports:   ports,
		})
	}
	return out, nil
}

// ContainerAction 容器动作。
func (c *Client) ContainerAction(ctx context.Context, id, action string) error {
	switch action {
	case "start", "stop", "restart", "kill":
		_, err := c.do(ctx, "POST", "/containers/"+id+"/"+action, nil, nil)
		return err
	case "remove":
		q := url.Values{"force": {"1"}, "v": {"1"}}
		_, err := c.do(ctx, "DELETE", "/containers/"+id, q, nil)
		return err
	case "pause":
		_, err := c.do(ctx, "POST", "/containers/"+id+"/pause", nil, nil)
		return err
	case "unpause":
		_, err := c.do(ctx, "POST", "/containers/"+id+"/unpause", nil, nil)
		return err
	default:
		return fmt.Errorf("未知动作: %s", action)
	}
}

// Image 镜像概要
type Image struct {
	ID       string   `json:"id"`
	ShortID  string   `json:"short_id"`
	RepoTags []string `json:"repo_tags"`
	Created  int64    `json:"created"`
	Size     int64    `json:"size"`
}

type rawImage struct {
	Id       string   `json:"Id"`
	RepoTags []string `json:"RepoTags"`
	Created  int64    `json:"Created"`
	Size     int64    `json:"Size"`
}

// Images 镜像列表。
func (c *Client) Images(ctx context.Context) ([]Image, error) {
	b, err := c.do(ctx, "GET", "/images/json", nil, nil)
	if err != nil {
		return nil, err
	}
	var raws []rawImage
	if err := json.Unmarshal(b, &raws); err != nil {
		return nil, err
	}
	out := make([]Image, 0, len(raws))
	for _, r := range raws {
		tags := r.RepoTags
		if tags == nil {
			tags = []string{}
		}
		out = append(out, Image{
			ID:       r.Id,
			ShortID:  shortID(r.Id),
			RepoTags: tags,
			Created:  r.Created,
			Size:     r.Size,
		})
	}
	return out, nil
}

// ImageRemove 删除镜像。
func (c *Client) ImageRemove(ctx context.Context, id string, force bool) error {
	q := url.Values{}
	if force {
		q.Set("force", "1")
	}
	_, err := c.do(ctx, "DELETE", "/images/"+id, q, nil)
	return err
}

// Volume 卷
type Volume struct {
	Name       string `json:"name"`
	Driver     string `json:"driver"`
	Mountpoint string `json:"mountpoint"`
	Size       string `json:"size"`
}

type rawVolume struct {
	Name       string `json:"Name"`
	Driver     string `json:"Driver"`
	Mountpoint string `json:"Mountpoint"`
}

type volumeListResp struct {
	Volumes []rawVolume `json:"Volumes"`
}

// Volumes 卷列表。
func (c *Client) Volumes(ctx context.Context) ([]Volume, error) {
	b, err := c.do(ctx, "GET", "/volumes", nil, nil)
	if err != nil {
		return nil, err
	}
	var resp volumeListResp
	if err := json.Unmarshal(b, &resp); err != nil {
		return nil, err
	}
	out := make([]Volume, 0, len(resp.Volumes))
	for _, v := range resp.Volumes {
		out = append(out, Volume{Name: v.Name, Driver: v.Driver, Mountpoint: v.Mountpoint})
	}
	return out, nil
}

// VolumeRemove 删除卷。
func (c *Client) VolumeRemove(ctx context.Context, name string, force bool) error {
	q := url.Values{}
	if force {
		q.Set("force", "1")
	}
	_, err := c.do(ctx, "DELETE", "/volumes/"+name, q, nil)
	return err
}

// Network Docker 网络
type Network struct {
	ID         string `json:"id"`
	ShortID    string `json:"short_id"`
	Name       string `json:"name"`
	Driver     string `json:"driver"`
	Scope      string `json:"scope"`
	Attachable bool   `json:"attachable"`
}

type rawNetwork struct {
	Id     string `json:"Id"`
	Name   string `json:"Name"`
	Driver string `json:"Driver"`
	Scope  string `json:"Scope"`
}

// Networks 网络列表。
func (c *Client) Networks(ctx context.Context) ([]Network, error) {
	b, err := c.do(ctx, "GET", "/networks", nil, nil)
	if err != nil {
		return nil, err
	}
	var raws []rawNetwork
	if err := json.Unmarshal(b, &raws); err != nil {
		return nil, err
	}
	out := make([]Network, 0, len(raws))
	for _, r := range raws {
		out = append(out, Network{
			ID:      r.Id,
			ShortID: shortID(r.Id),
			Name:    r.Name,
			Driver:  r.Driver,
			Scope:   r.Scope,
		})
	}
	return out, nil
}

// NetworkRemove 删除网络。
func (c *Client) NetworkRemove(ctx context.Context, id string) error {
	_, err := c.do(ctx, "DELETE", "/networks/"+id, nil, nil)
	return err
}

// ContainerStats 容器实时统计
type ContainerStats struct {
	ID         string  `json:"id"`
	Name       string  `json:"name"`
	CPU        float64 `json:"cpu_percent"`
	Mem        uint64  `json:"mem_usage"`
	MemPct     float64 `json:"mem_percent"`
	NetIO      string  `json:"net_io"`
	BlockIO    string  `json:"block_io"`
	PIDs       int     `json:"pids"`
	OnlineCPUs uint32  `json:"online_cpus"`
}

type rawStats struct {
	CPUStats struct {
		CPUUsage struct {
			TotalUsage uint64 `json:"total_usage"`
		} `json:"cpu_usage"`
		ThrottlingData struct {
			Periods uint64 `json:"periods"`
		} `json:"throttling_data"`
		SystemCPUUsage uint64 `json:"system_cpu_usage"`
		OnlineCPUs     uint32 `json:"online_cpus"`
	} `json:"cpu_stats"`
	PreCPUStats struct {
		CPUUsage struct {
			TotalUsage uint64 `json:"total_usage"`
		} `json:"cpu_usage"`
		SystemCPUUsage uint64 `json:"system_cpu_usage"`
	} `json:"precpu_stats"`
	MemoryStats struct {
		Usage uint64 `json:"usage"`
		Limit uint64 `json:"limit"`
	} `json:"memory_stats"`
	Networks struct {
		Eth0 *struct {
			RxBytes uint64 `json:"rx_bytes"`
			TxBytes uint64 `json:"tx_bytes"`
		} `json:"eth0"`
		Eth1 *struct {
			RxBytes uint64 `json:"rx_bytes"`
			TxBytes uint64 `json:"tx_bytes"`
		} `json:"eth1"`
	} `json:"networks"`
	PidsStats struct {
		Current int `json:"current"`
	} `json:"pids_stats"`
	BlockioStats struct {
		IoServiceBytesRecursive []struct {
			Value uint64 `json:"value"`
		} `json:"io_service_bytes_recursive"`
	} `json:"blkio_stats"`
}

// ContainerStatsOne 获取单个容器实时统计。
func (c *Client) ContainerStatsOne(ctx context.Context, id string) (ContainerStats, error) {
	var cs ContainerStats
	q := url.Values{"stream": {"false"}}
	b, err := c.do(ctx, "GET", "/containers/"+id+"/stats", q, nil)
	if err != nil {
		return cs, err
	}
	var rs rawStats
	if err := json.Unmarshal(b, &rs); err != nil {
		return cs, err
	}
	cpuDelta := rs.CPUStats.CPUUsage.TotalUsage - rs.PreCPUStats.CPUUsage.TotalUsage
	sysDelta := rs.CPUStats.SystemCPUUsage - rs.PreCPUStats.SystemCPUUsage
	ncpu := rs.CPUStats.OnlineCPUs
	if ncpu == 0 {
		ncpu = 1
	}
	if sysDelta > 0 && cpuDelta > 0 {
		cs.CPU = float64(cpuDelta) / float64(sysDelta) * float64(ncpu) * 100
	}
	cs.Mem = rs.MemoryStats.Usage
	if rs.MemoryStats.Limit > 0 {
		cs.MemPct = float64(rs.MemoryStats.Usage) / float64(rs.MemoryStats.Limit) * 100
	}
	var rx, tx uint64
	if rs.Networks.Eth0 != nil {
		rx += rs.Networks.Eth0.RxBytes
		tx += rs.Networks.Eth0.TxBytes
	}
	if rs.Networks.Eth1 != nil {
		rx += rs.Networks.Eth1.RxBytes
		tx += rs.Networks.Eth1.TxBytes
	}
	cs.NetIO = fmt.Sprintf("%s↓ / %s↑", humanSize(rx), humanSize(tx))
	var blk uint64
	for _, v := range rs.BlockioStats.IoServiceBytesRecursive {
		blk += v.Value
	}
	cs.BlockIO = humanSize(blk)
	cs.PIDs = rs.PidsStats.Current
	cs.ID = shortID(id)
	return cs, nil
}

// Stats 全部运行中容器统计。
func (c *Client) Stats(ctx context.Context) ([]ContainerStats, error) {
	containers, err := c.Containers(ctx, false)
	if err != nil {
		return nil, err
	}
	var out []ContainerStats
	for _, ct := range containers {
		if ct.State != "running" {
			continue
		}
		cs, err := c.ContainerStatsOne(ctx, ct.ID)
		if err != nil {
			continue
		}
		cs.Name = ct.Names
		out = append(out, cs)
	}
	return out, nil
}

// Info Docker 引擎信息
type Info struct {
	ServerVersion string `json:"server_version"`
	Containers    int    `json:"containers"`
	Running       int    `json:"containers_running"`
	Paused        int    `json:"containers_paused"`
	Stopped       int    `json:"containers_stopped"`
	Images        int    `json:"images"`
	Driver        string `json:"driver"`
	MemTotal      uint64 `json:"mem_total"`
	NCPU          int    `json:"ncpu"`
	OS            string `json:"os"`
	Arch          string `json:"arch"`
	KernelVersion string `json:"kernel_version"`
}

type rawInfo struct {
	ServerVersion     string `json:"ServerVersion"`
	Containers        int    `json:"Containers"`
	ContainersRunning int    `json:"ContainersRunning"`
	ContainersPaused  int    `json:"ContainersPaused"`
	ContainersStopped int    `json:"ContainersStopped"`
	Images            int    `json:"Images"`
	Driver            string `json:"Driver"`
	MemTotal          uint64 `json:"MemTotal"`
	NCPU              int    `json:"NCPU"`
	OperatingSystem   string `json:"OperatingSystem"`
	Architecture      string `json:"Architecture"`
	KernelVersion     string `json:"KernelVersion"`
}

// EngineInfo 引擎信息。
func (c *Client) EngineInfo(ctx context.Context) (Info, error) {
	var info Info
	b, err := c.do(ctx, "GET", "/info", nil, nil)
	if err != nil {
		return info, err
	}
	var ri rawInfo
	if err := json.Unmarshal(b, &ri); err != nil {
		return info, err
	}
	info = Info{
		ServerVersion: ri.ServerVersion,
		Containers:    ri.Containers,
		Running:       ri.ContainersRunning,
		Paused:        ri.ContainersPaused,
		Stopped:       ri.ContainersStopped,
		Images:        ri.Images,
		Driver:        ri.Driver,
		MemTotal:      ri.MemTotal,
		NCPU:          ri.NCPU,
		OS:            ri.OperatingSystem,
		Arch:          ri.Architecture,
		KernelVersion: ri.KernelVersion,
	}
	return info, nil
}

// SystemDF docker system df
type SystemDF struct {
	LayersSize int64 `json:"layers_size"`
	Images     int64 `json:"images"`
	Containers int64 `json:"containers"`
	Volumes    int64 `json:"volumes"`
	BuildCache int64 `json:"build_cache"`
}

type rawDF struct {
	LayersSize int64 `json:"LayersSize"`
	Images     []struct {
		Size int64 `json:"Size"`
	} `json:"Images"`
	Containers []struct {
		SizeRw     int64 `json:"SizeRw"`
		SizeRootFs int64 `json:"SizeRootFs"`
	} `json:"Containers"`
	Volumes []struct {
		Size int64 `json:"Size"`
	} `json:"Volumes"`
	BuildCache []struct {
		Size int64 `json:"Size"`
	} `json:"BuildCache"`
}

// DiskUsage 磁盘占用汇总。
func (c *Client) DiskUsage(ctx context.Context) (SystemDF, error) {
	var df SystemDF
	b, err := c.do(ctx, "GET", "/system/df", nil, nil)
	if err != nil {
		return df, err
	}
	var rd rawDF
	if err := json.Unmarshal(b, &rd); err != nil {
		return df, err
	}
	df.LayersSize = rd.LayersSize
	for _, i := range rd.Images {
		df.Images += i.Size
	}
	for _, ct := range rd.Containers {
		df.Containers += ct.SizeRw + ct.SizeRootFs
	}
	for _, v := range rd.Volumes {
		df.Volumes += v.Size
	}
	for _, bc := range rd.BuildCache {
		df.BuildCache += bc.Size
	}
	return df, nil
}

// PruneResult 清理结果
type PruneResult struct {
	SpaceReclaimed int64 `json:"space_reclaimed"`
}

type rawPrune struct {
	SpaceReclaimed int64 `json:"SpaceReclaimed"`
}

// Prune 清理悬空资源。
func (c *Client) Prune(ctx context.Context, target string) (PruneResult, error) {
	var res PruneResult
	path := ""
	switch target {
	case "containers":
		path = "/containers/prune"
	case "images":
		path = "/images/prune"
	case "volumes":
		path = "/volumes/prune"
	case "networks":
		path = "/networks/prune"
	case "build":
		path = "/build/prune"
	default:
		return res, fmt.Errorf("未知清理目标: %s", target)
	}
	b, err := c.do(ctx, "POST", path, nil, nil)
	if err != nil {
		return res, err
	}
	var rp rawPrune
	_ = json.Unmarshal(b, &rp)
	res.SpaceReclaimed = rp.SpaceReclaimed
	return res, nil
}

func shortID(id string) string {
	if len(id) > 12 {
		return id[:12]
	}
	return id
}

func humanSize(b uint64) string {
	if b < 1024 {
		return fmt.Sprintf("%dB", b)
	}
	f := float64(b)
	for _, u := range []string{"K", "M", "G", "T", "P"} {
		f /= 1024
		if f < 1024 {
			return fmt.Sprintf("%.1f%s", f, u)
		}
	}
	return fmt.Sprintf("%.1fE", f/1024)
}
