/* mobufan-web 前端逻辑 */
(function () {
  "use strict";

  var TOKEN_KEY = "mobufan_token";
  var token = localStorage.getItem(TOKEN_KEY) || "";
  var currentPage = "overview";
  var timers = {};
  var procSort = "cpu";

  var $ = function (sel) { return document.querySelector(sel); };
  var $$ = function (sel) { return Array.prototype.slice.call(document.querySelectorAll(sel)); };

  /* ---------- 工具 ---------- */
  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function humanSize(n) {
    if (n == null || isNaN(n)) return "-";
    if (n < 1024) return n + " B";
    var u = ["K", "M", "G", "T", "P"];
    var f = n, i = -1;
    do { f /= 1024; i++; } while (f >= 1024 && i < u.length - 1);
    return f.toFixed(1) + " " + u[i];
  }
  function humanDate(ts) {
    if (!ts) return "-";
    var d = new Date(ts * 1000);
    var diff = Math.floor((Date.now() - ts * 1000) / 1000);
    if (diff < 60) return "刚刚";
    if (diff < 3600) return Math.floor(diff / 60) + " 分钟前";
    if (diff < 86400) return Math.floor(diff / 3600) + " 小时前";
    if (diff < 86400 * 30) return Math.floor(diff / 86400) + " 天前";
    return d.toLocaleDateString();
  }
  function toast(msg, type) {
    var el = document.createElement("div");
    el.className = "toast " + (type || "ok");
    el.textContent = msg;
    $("#toast").appendChild(el);
    setTimeout(function () { el.remove(); }, 4000);
  }

  /* ---------- API ---------- */
  function api(path, opts) {
    opts = opts || {};
    var headers = { "Content-Type": "application/json" };
    if (token) headers["Authorization"] = "Bearer " + token;
    return fetch(path, {
      method: opts.method || "GET",
      headers: headers,
      body: opts.body ? JSON.stringify(opts.body) : undefined,
    }).then(function (resp) {
      return resp.json().catch(function () { return {}; }).then(function (data) {
        if (!resp.ok) {
          var err = new Error(data.error || ("请求失败 HTTP " + resp.status));
          err.status = resp.status;
          throw err;
        }
        return data;
      });
    });
  }

  /* ---------- 认证 ---------- */
  function showLogin() {
    $("#login-overlay").classList.remove("hidden");
    $("#app").classList.add("hidden");
  }
  function showApp() {
    $("#login-overlay").classList.add("hidden");
    $("#app").classList.remove("hidden");
    navigate(currentPage);
    startAll();
  }
  $("#login-btn").addEventListener("click", function () {
    var t = $("#token-input").value.trim();
    if (!t) { $("#login-err").textContent = "请输入访问令牌"; return; }
    token = t;
    api("/api/system/info").then(function () {
      localStorage.setItem(TOKEN_KEY, token);
      $("#login-err").textContent = "";
      showApp();
      toast("登录成功");
    }).catch(function (e) {
      $("#login-err").textContent = e.message || "登录失败";
      token = "";
    });
  });
  $("#token-input").addEventListener("keydown", function (e) {
    if (e.key === "Enter") $("#login-btn").click();
  });
  $("#logout-btn").addEventListener("click", function () {
    token = "";
    localStorage.removeItem(TOKEN_KEY);
    stopAll();
    showLogin();
  });

  /* ---------- 导航 ---------- */
  function navigate(page) {
    currentPage = page;
    $$(".nav-item").forEach(function (n) {
      n.classList.toggle("active", n.dataset.page === page);
    });
    $$(".page").forEach(function (p) { p.classList.add("hidden"); });
    $("#page-" + page).classList.remove("hidden");
    var titles = { overview: "总览", docker: "Docker 管理", bbr: "BBR / 网络", firewall: "端口 / 防火墙", process: "进程" };
    $("#page-title").textContent = titles[page] || page;
  }
  $$(".nav-item").forEach(function (n) {
    n.addEventListener("click", function () {
      navigate(n.dataset.page);
      location.hash = n.dataset.page;
    });
  });

  /* ---------- 定时刷新 ---------- */
  var loaders = {
    overview: loadOverview,
    docker: loadDockerAll,
    bbr: loadBBR,
    firewall: loadFirewall,
    process: loadProcess,
  };
  function startAll() {
    stopAll();
    Object.keys(loaders).forEach(function (p) {
      loaders[p]();
      timers[p] = setInterval(loaders[p], 5000);
    });
    timers.clock = setInterval(tick, 1000);
  }
  function stopAll() {
    Object.keys(timers).forEach(function (k) { clearInterval(timers[k]); });
    timers = {};
  }
  $("#refresh-btn").addEventListener("click", function () {
    if (loaders[currentPage]) loaders[currentPage]();
    toast("已刷新", "ok");
  });

  function tick() {
    var d = new Date();
    $("#clock").textContent = d.toLocaleString("zh-CN", { hour12: false });
  }

  /* ---------- 总览 ---------- */
  function loadOverview() {
    api("/api/system/info").then(function (info) {
      var hostname = info.hostname || "-";
      $("#host-info").textContent = hostname + " · " + (info.os_name || "-") + " · " + (info.internal_ip || "-") + " · 公网 " + (info.public_ip || "-");
      $("#ov-cpu-model").textContent = (info.cpu_model || "-") + " · " + (info.physical_cpu || 0) + "核/" + (info.logical_cpu || 0) + "线程";
      $("#ov-load").textContent = (info.load1 || 0).toFixed(2);
      $("#ov-load-bar").style.width = Math.min(100, (info.load1 / Math.max(1, info.logical_cpu)) * 100) + "%";
      $("#ov-load-sub").textContent = "1min " + info.load1.toFixed(2) + " · 5min " + info.load5.toFixed(2) + " · 15min " + info.load15.toFixed(2);

      var items = [
        ["操作系统", info.os_name],
        ["内核版本", info.kernel],
        ["架构", info.arch],
        ["主机名", info.hostname],
        ["运行时长", info.uptime],
        ["CPU 型号", info.cpu_model],
        ["CPU 核心", info.physical_cpu + " 物理 / " + info.logical_cpu + " 逻辑"],
        ["系统负载", info.load1.toFixed(2) + " / " + info.load5.toFixed(2) + " / " + info.load15.toFixed(2)],
        ["进程数", info.processes],
        ["内网 IP", info.internal_ip],
        ["公网 IP", info.public_ip],
        ["默认网关", info.gateway],
        ["DNS", (info.dns || []).join(", ") || "-"],
        ["时区", info.timezone],
        ["当前时间", info.current_time],
        ["TCP 拥塞控制", info.tcp_congestion],
        ["队列规则", info.qdisc],
        ["TCP 连接数", info.connections],
      ];
      $("#ov-info").innerHTML = items.map(function (it) {
        return '<div class="info-item"><div class="k">' + esc(it[0]) + '</div><div class="v">' + esc(it[1]) + "</div></div>";
      }).join("");
    }).catch(function (e) { $("#host-info").textContent = "加载失败: " + e.message; });

    api("/api/system/cpu").then(function (d) {
      $("#ov-cpu").textContent = (d.usage_percent || 0).toFixed(1) + "%";
      setBar("#ov-cpu-bar", d.usage_percent || 0);
      if (d.cpu_model) $("#ov-cpu-model").textContent = d.cpu_model;
    }).catch(function () {});

    api("/api/system/memory").then(function (m) {
      $("#ov-mem").textContent = humanSize(m.used) + " / " + humanSize(m.total);
      setBar("#ov-mem-bar", m.usage_percent || 0);
      $("#ov-mem-sub").textContent = "使用率 " + (m.usage_percent || 0).toFixed(1) + "% · Swap " + humanSize(m.swap_used) + "/" + humanSize(m.swap_total);
    }).catch(function () {});

    api("/api/system/disk").then(function (disks) {
      var root = null, rows = "";
      (disks || []).forEach(function (d) {
        if (!root && (d.mount === "/" || d.device === "/")) root = d;
        rows += "<tr><td class='mono'>" + esc(d.device) + "</td><td>" + esc(d.mount) + "</td><td>" + esc(d.fstype) +
          "</td><td>" + humanSize(d.total) + "</td><td>" + humanSize(d.used) + "</td><td>" + humanSize(d.free) +
          "</td><td>" + pctCell(d.usage_percent) + "</td></tr>";
      });
      $("#ov-disk-table").innerHTML = rows;
      if (root) {
        $("#ov-disk").textContent = humanSize(root.used) + " / " + humanSize(root.total);
        setBar("#ov-disk-bar", root.usage_percent || 0);
        $("#ov-disk-sub").textContent = (root.usage_percent || 0).toFixed(1) + "% · 可用 " + humanSize(root.free);
      }
    }).catch(function () {});

    api("/api/system/network").then(function (nets) {
      var rows = "";
      (nets || []).forEach(function (n) {
        rows += "<tr><td>" + esc(n.name) + "</td><td>" + stateBadge(n.state) + "</td><td>" + esc(n.ipv4 || "-") +
          "</td><td class='mono'>" + esc(n.mac || "-") + "</td><td>" + esc(n.mtu || "-") + "</td><td>" + esc(n.speed || "-") +
          "</td><td>" + humanSize(n.rx_bytes || 0) + " ↓ / " + humanSize(n.tx_bytes || 0) + " ↑</td></tr>";
      });
      $("#ov-net-table").innerHTML = rows;
    }).catch(function () {});
  }

  function setBar(sel, pct) {
    var el = $(sel);
    pct = Math.max(0, Math.min(100, pct));
    el.style.width = pct.toFixed(1) + "%";
    el.classList.toggle("warn", pct >= 70 && pct < 90);
    el.classList.toggle("danger", pct >= 90);
  }
  function pctCell(pct) {
    pct = pct || 0;
    var color = pct >= 90 ? "red" : pct >= 70 ? "yellow" : "green";
    return '<span class="badge ' + color + '">' + pct.toFixed(1) + "%</span>";
  }
  function stateBadge(state) {
    state = state || "unknown";
    var cls = "green", txt = state;
    if (state === "down") { cls = "gray"; txt = "down"; }
    else if (state === "unknown") { cls = "red"; txt = "unknown"; }
    else if (state !== "up") { cls = "yellow"; }
    return '<span class="badge ' + cls + '">' + esc(txt) + "</span>";
  }

  /* ---------- Docker ---------- */
  function dockerBanner(enabled, err) {
    var b = $("#docker-banner");
    if (enabled) {
      b.className = "docker-banner ok";
      b.textContent = "Docker 已连接，可通过面板管理宿主机的容器、镜像、卷与网络。";
    } else {
      b.className = "docker-banner err";
      b.textContent = "Docker 不可用：" + (err || "无法连接，请检查容器是否挂载 /var/run/docker.sock 或以 root 运行。");
    }
  }

  function loadDockerAll() {
    api("/api/docker/info").then(function (info) {
      dockerBanner(true);
      $("#dk-ver").textContent = info.server_version || "-";
      $("#dk-containers").textContent = (info.containers_running || 0) + " 运行 / " + (info.containers || 0) + " 总";
      $("#dk-images").textContent = info.images || "-";
      $("#dk-driver").textContent = info.driver || "-";
    }).catch(function (e) {
      dockerBanner(false, e.message);
      return;
    });
    loadDockerContainers();
    loadDockerImages();
    loadDockerVolumes();
    loadDockerNetworks();
    loadDockerStats();
    loadDockerDF();
  }

  function loadDockerContainers() {
    api("/api/docker/containers?all=1").then(function (list) {
      var rows = "";
      (list || []).forEach(function (c) {
        var stateCls = c.state === "running" ? "green" : c.state === "exited" ? "red" : "yellow";
        var ports = (c.ports || []).map(function (p) {
          return p.public_port ? esc(p.ip || "*") + ":" + p.public_port + "→" + p.private_port + "/" + p.type : "";
        }).filter(Boolean).join("<br>") || "-";
        var running = c.state === "running";
        rows += "<tr><td class='mono'>" + esc(c.short_id) + "</td><td>" + esc(c.names.replace(/^\//, "")) +
          "</td><td class='mono'>" + esc(c.image) + "</td><td><span class='badge " + stateCls + "'>" + esc(c.status) + "</span></td>" +
          "<td>" + ports + "</td><td class='mono'>" +
          actBtn("start", c.id, running, "启动") +
          actBtn("stop", c.id, !running, "停止") +
          actBtn("restart", c.id, false, "重启") +
          actBtn("remove", c.id, false, "删除") +
          "</td></tr>";
      });
      $("#docker-containers").innerHTML = rows || emptyRow("没有容器");
    }).catch(function (e) { $("#docker-containers").innerHTML = emptyRow(e.message); });
  }

  function loadDockerImages() {
    api("/api/docker/images").then(function (list) {
      var rows = "";
      (list || []).forEach(function (im) {
        var tags = (im.repo_tags || []).join(", ") || "&lt;none&gt;";
        rows += "<tr><td class='mono'>" + esc(im.short_id) + "</td><td class='mono'>" + tags +
          "</td><td>" + humanSize(im.size) + "</td><td class='mono'>" +
          actBtn("rmi", im.id, false, "删除") + "</td></tr>";
      });
      $("#docker-images").innerHTML = rows || emptyRow("没有镜像");
    }).catch(function (e) { $("#docker-images").innerHTML = emptyRow(e.message); });
  }

  function loadDockerVolumes() {
    api("/api/docker/volumes").then(function (list) {
      var rows = "";
      (list || []).forEach(function (v) {
        rows += "<tr><td>" + esc(v.name) + "</td><td>" + esc(v.driver) + "</td><td class='mono'>" + esc(v.mountpoint) +
          "</td><td class='mono'>" + actBtn("rmv", v.name, false, "删除") + "</td></tr>";
      });
      $("#docker-volumes").innerHTML = rows || emptyRow("没有卷");
    }).catch(function (e) { $("#docker-volumes").innerHTML = emptyRow(e.message); });
  }

  function loadDockerNetworks() {
    api("/api/docker/networks").then(function (list) {
      var rows = "";
      (list || []).forEach(function (n) {
        rows += "<tr><td class='mono'>" + esc(n.short_id) + "</td><td>" + esc(n.name) + "</td><td>" + esc(n.driver) +
          "</td><td>" + esc(n.scope) + "</td><td class='mono'>" + actBtn("rmn", n.id, false, "删除") + "</td></tr>";
      });
      $("#docker-networks").innerHTML = rows || emptyRow("没有网络");
    }).catch(function (e) { $("#docker-networks").innerHTML = emptyRow(e.message); });
  }

  function loadDockerStats() {
    api("/api/docker/stats").then(function (list) {
      var rows = "";
      (list || []).forEach(function (s) {
        rows += "<tr><td>" + esc(s.name || s.id) + "</td><td>" + (s.cpu_percent || 0).toFixed(1) + "%</td><td>" +
          humanSize(s.mem_usage) + "</td><td>" + (s.mem_percent || 0).toFixed(1) + "%</td><td>" + esc(s.net_io) +
          "</td><td>" + esc(s.block_io) + "</td><td>" + (s.pids || 0) + "</td></tr>";
      });
      $("#docker-stats").innerHTML = rows || emptyRow("没有运行中的容器");
    }).catch(function (e) { $("#docker-stats").innerHTML = emptyRow(e.message); });
  }

  function loadDockerDF() {
    api("/api/docker/df").then(function (df) {
      var b = $("#docker-banner");
      b.textContent += " 磁盘占用：镜像 " + humanSize(df.images) + " · 容器 " + humanSize(df.containers) +
        " · 卷 " + humanSize(df.volumes) + " · 构建缓存 " + humanSize(df.build_cache);
    }).catch(function () {});
  }

  function actBtn(kind, id, disabled, label) {
    return '<button class="btn btn-ghost btn-sm act" data-kind="' + kind + '" data-id="' + esc(id) + '"' +
      (disabled ? " disabled" : "") + ">" + label + "</button> ";
  }
  function emptyRow(msg) {
    return '<tr><td colspan="8" style="text-align:center;color:var(--text-dim);padding:20px">' + esc(msg) + "</td></tr>";
  }

  // 事件委托：容器/镜像/卷/网络操作
  document.addEventListener("click", function (e) {
    var btn = e.target.closest(".act");
    if (!btn) return;
    var kind = btn.dataset.kind, id = btn.dataset.id;
    var path, body, okMsg;
    if (kind === "start" || kind === "stop" || kind === "restart" || kind === "remove") {
      path = "/api/docker/containers/" + encodeURIComponent(id) + "/action";
      body = { action: kind };
      okMsg = { start: "容器已启动", stop: "容器已停止", restart: "容器已重启", remove: "容器已删除" }[kind];
    } else if (kind === "rmi") {
      path = "/api/docker/images/" + encodeURIComponent(id) + "?force=1";
      okMsg = "镜像已删除";
    } else if (kind === "rmv") {
      path = "/api/docker/volumes/" + encodeURIComponent(id) + "?force=1";
      okMsg = "卷已删除";
    } else if (kind === "rmn") {
      path = "/api/docker/networks/" + encodeURIComponent(id);
      okMsg = "网络已删除";
    } else { return; }
    btn.disabled = true;
    api(path, kind === "rmi" || kind === "rmv" || kind === "rmn" ? { method: "DELETE" } : { method: "POST", body: body })
      .then(function () { toast(okMsg, "ok"); loadDockerAll(); })
      .catch(function (err) { toast(err.message, "err"); btn.disabled = false; });
  });

  $("#docker-prune-btn").addEventListener("click", function () {
    if (!confirm("确认清理所有悬空的容器/镜像/网络/构建缓存？")) return;
    ["containers", "images", "networks", "build"].forEach(function (t) {
      api("/api/docker/prune", { method: "POST", body: { target: t } })
        .then(function (d) { toast("清理 " + t + " 完成，回收 " + humanSize(d.space_reclaimed), "ok"); loadDockerAll(); })
        .catch(function (err) { toast(err.message, "err"); });
    });
  });

  // Tabs
  $$(".tab").forEach(function (t) {
    t.addEventListener("click", function () {
      $$(".tab").forEach(function (x) { x.classList.remove("active"); });
      t.classList.add("active");
      $$(".tab-body").forEach(function (x) { x.classList.add("hidden"); });
      $("#tab-" + t.dataset.tab).classList.remove("hidden");
    });
  });

  /* ---------- BBR ---------- */
  function loadBBR() {
    api("/api/bbr/status").then(function (st) {
      $("#bbr-status").innerHTML =
        bbrItem("当前算法", esc(st.current_congestion || "-")) +
        bbrItem("队列规则 (qdisc)", esc(st.default_qdisc || "-")) +
        bbrItem("内核支持 BBR", st.bbr_supported ? '<span class="badge green">是</span>' : '<span class="badge red">否</span>') +
        bbrItem("BBR 已启用", st.bbr_enabled ? '<span class="badge green">是</span>' : '<span class="badge yellow">否</span>') +
        bbrItem("可用算法", esc((st.available_congestion || []).join(", "))) +
        bbrItem("已生效参数", esc((st.params_enabled || []).join(", ") || "无"));
      $("#bbr-enable").disabled = st.bbr_enabled;
      $("#bbr-disable").disabled = !st.bbr_enabled;
    }).catch(function (e) {
      $("#bbr-status").innerHTML = '<div class="stat-sub" style="color:var(--red)">' + esc(e.message) + "</div>";
    });

    api("/api/system/network").then(function (nets) {
      var rows = "";
      (nets || []).forEach(function (n) {
        rows += "<tr><td>" + esc(n.name) + "</td><td>" + stateBadge(n.state) + "</td><td>" + esc(n.ipv4 || "-") +
          "</td><td class='mono'>" + esc(n.mac || "-") + "</td><td>" + esc(n.mtu || "-") + "</td><td>" + esc(n.speed || "-") +
          "</td><td>" + humanSize(n.rx_bytes || 0) + " ↓ / " + humanSize(n.tx_bytes || 0) + " ↑</td><td>" +
          (n.is_default ? '<span class="badge cyan">默认</span>' : "-") + "</td></tr>";
      });
      $("#bbr-net-table").innerHTML = rows || emptyRow("无网络接口");
    }).catch(function () {});
  }
  function bbrItem(l, v) {
    return '<div class="bbr-item"><div class="l">' + esc(l) + '</div><div class="v">' + v + "</div></div>";
  }
  function bbrAction(path, okMsg) {
    return api(path, { method: "POST" }).then(function () {
      toast(okMsg, "ok");
      loadBBR();
    }).catch(function (e) { toast(e.message, "err"); });
  }
  $("#bbr-enable").addEventListener("click", function () { bbrAction("/api/bbr/enable", "BBR 已启用"); });
  $("#bbr-disable").addEventListener("click", function () { bbrAction("/api/bbr/disable", "BBR 已关闭"); });

  /* ---------- 防火墙 ---------- */
  function loadFirewall() {
    api("/api/system/ports").then(function (ports) {
      var rows = "";
      (ports || []).forEach(function (p) {
        rows += "<tr><td class='mono'>" + esc(p.protocol) + "</td><td class='mono'>" + esc(p.address) +
          "</td><td>" + p.port + "</td><td>" + (p.pid || "-") + "</td><td>" + esc(p.process || "-") + "</td></tr>";
      });
      $("#fw-ports").innerHTML = rows || emptyRow("无监听端口");
    }).catch(function (e) { $("#fw-ports").innerHTML = emptyRow(e.message); });

    api("/api/firewall/chain?name=INPUT").then(function (fc) {
      $("#fw-raw").textContent = fc.raw || "（无规则）";
    }).catch(function (e) {
      $("#fw-raw").textContent = "读取失败: " + e.message;
    });
  }
  function fwAction(path, body, okMsg) {
    return api(path, { method: "POST", body: body }).then(function () {
      toast(okMsg, "ok");
      loadFirewall();
    }).catch(function (e) { toast(e.message, "err"); });
  }
  $("#fw-open").addEventListener("click", function () {
    var port = $("#fw-port").value.trim();
    if (!port) { toast("请输入端口号", "warn"); return; }
    fwAction("/api/firewall/port/open", { port: port, protocol: $("#fw-proto").value }, "端口 " + port + " 已开放");
  });
  $("#fw-close").addEventListener("click", function () {
    var port = $("#fw-port").value.trim();
    if (!port) { toast("请输入端口号", "warn"); return; }
    fwAction("/api/firewall/port/close", { port: port, protocol: $("#fw-proto").value }, "端口 " + port + " 已关闭");
  });
  $("#fw-allow").addEventListener("click", function () {
    var ip = $("#fw-ip").value.trim();
    if (!ip) { toast("请输入 IP", "warn"); return; }
    fwAction("/api/firewall/ip/allow", { ip: ip }, "已放行 IP " + ip);
  });
  $("#fw-block").addEventListener("click", function () {
    var ip = $("#fw-ip").value.trim();
    if (!ip) { toast("请输入 IP", "warn"); return; }
    fwAction("/api/firewall/ip/block", { ip: ip }, "已阻止 IP " + ip);
  });
  $("#fw-save").addEventListener("click", function () {
    fwAction("/api/firewall/save", {}, "防火墙规则已保存");
  });

  /* ---------- 进程 ---------- */
  function loadProcess() {
    api("/api/system/processes?limit=40&sort=" + procSort).then(function (list) {
      var rows = "";
      (list || []).forEach(function (p) {
        var stateCls = { R: "green", S: "blue", D: "yellow", Z: "red", T: "gray" }[p.state] || "cyan";
        rows += "<tr><td>" + p.pid + "</td><td>" + esc(p.user || "-") + "</td><td>" + (p.cpu_percent || 0).toFixed(1) +
          "%</td><td>" + (p.mem_percent || 0).toFixed(1) + "%</td><td>" + humanSize(p.rss_bytes) +
          "</td><td><span class='badge " + stateCls + "'>" + esc(p.state || "-") + "</span></td><td class='mono'>" +
          esc(p.name || "-") + "</td></tr>";
      });
      $("#proc-table").innerHTML = rows || emptyRow("无进程");
    }).catch(function (e) { $("#proc-table").innerHTML = emptyRow(e.message); });
  }
  $("#proc-sort-cpu").addEventListener("click", function () { procSort = "cpu"; loadProcess(); });
  $("#proc-sort-mem").addEventListener("click", function () { procSort = "mem"; loadProcess(); });

  /* ---------- 初始化 ---------- */
  if (location.hash && location.hash.length > 1) {
    currentPage = location.hash.slice(1);
  }
  if (token) {
    api("/api/system/info").then(showApp).catch(function () { showLogin(); });
  } else {
    showLogin();
  }
})();
