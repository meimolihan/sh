#!/bin/bash

list_color_init() {
    export gl_hui=$'\033[38;5;59m'
    export gl_hong=$'\033[38;5;9m'
    export gl_lv=$'\033[38;5;10m'
    export gl_huang=$'\033[38;5;11m'
    export gl_lan=$'\033[38;5;32m'
    export gl_bai=$'\033[38;5;15m'
    export gl_zi=$'\033[38;5;13m'
    export gl_bufan=$'\033[38;5;14m'
    export reset=$'\033[0m'
}
list_color_init

log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

download_core() {
    local save_path="$1"
    
    log_info "正在从主源下载: https://gitee.com/meimolihan/sh/raw/master/mobufan.sh"
    curl -sSL -A "Mozilla/5.0" --max-time 10 \
    https://gitee.com/meimolihan/sh/raw/master/mobufan.sh -o "$save_path"

    if [[ ! -s "$save_path" ]]; then
        log_warn "主源下载失败或文件为空，切换到备用源下载"
        log_info "正在从备用源下载: https://sh.meimolihan.eu.org/mobufan.sh"
        curl -sSL -A "Mozilla/5.0" --max-time 30 \
        https://sh.meimolihan.eu.org/mobufan.sh -o "$save_path"
    fi

    [[ -s "$save_path" ]] && return 0 || return 1
}

sh_download() {
    rm -rf /root/mobufan.sh /usr/local/bin/m /usr/bin/m
    local script_path="$HOME/mobufan.sh"
    ISTOREOS=0

    if [[ -s /etc/os-release ]]; then
        . /etc/os-release
        [[ "$ID" == "istoreos" ]] && ISTOREOS=1
    fi

    if [[ "$1" =~ ^(cn|en|tw|jp|kr|ru|ir)$ ]]; then
        if ! download_core "$script_path"; then
            log_error "脚本下载失败！"
            return 1
        fi
        chmod +x "$script_path"
        exec "$script_path" "${@:2}"
    fi

    local country=$(curl -s --max-time 2 ipinfo.io/country 2>/dev/null || echo "unknown")
    local ipv6_address=$(curl -s --max-time 2 https://v6.ipinfo.io/ip 2>/dev/null || echo "")
    log_info "网络地区: $country | IPv6检测: ${ipv6_address:-无}"

    log_info "开始下载主脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    if ! download_core "$script_path"; then
        log_error "所有下载源均下载失败，请检查网络！"
        exit 1
    fi
    chmod +x "$script_path"
    log_ok "脚本下载完成"

    local link_paths=("/usr/local/bin/m" "/usr/bin/m")
    local link_success=0
    for link in "${link_paths[@]}"; do
        rm -f "$link"
        if ln -sf "$script_path" "$link" 2>/dev/null; then
            log_ok "快捷命令已创建: m -> $script_path"
            link_success=1
            break
        fi
    done

    if [[ $link_success -eq 0 ]]; then
        log_warn "无法创建全局快捷命令，可直接执行: $script_path"
    fi

    if command -v m &>/dev/null; then
        log_ok "快捷命令 m 可直接使用"
    else
        log_warn "m 命令未生效，可执行 source /etc/profile 或重新登录"
    fi

    log_info "正在启动主脚本 ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    exec "$script_path" "$@"
}

sh_download "$@"