#!/bin/bash

sh_download() {
    rm -rf /root/mobufan.sh /usr/local/bin/m
    local script_path="$HOME/mobufan.sh"
    if [[ "$1" =~ ^(cn|en|tw|jp|kr|ru|ir)$ ]]; then
        local lang="$1"
        curl -sS -o "$script_path" "https://gitee.com/meimolihan/sh/raw/master/mobufan.sh" || return 1
        chmod +x "$script_path"
        "$script_path" "${@:2}"  # ✅ 传递除了语言参数以外的其余参数
        return
    fi

    # 检测国家/IPv6
    local country=$(curl -s --max-time 1 ipinfo.io/country || echo "unknown")
    local ipv6_address=$(curl -s --max-time 1 https://v6.ipinfo.io/ip || echo "")

    if [ "$country" = "CN" ] || [ -n "$ipv6_address" ]; then
        curl -sS -o "$script_path" "https://gitee.com/meimolihan/sh/raw/master/mobufan.sh"
    else
        curl -sS -o "$script_path" "https://gitee.com/meimolihan/sh/raw/master/mobufan.sh"
    fi

    chmod +x "$script_path"
    "$script_path" "$@"
}

sh_download "$@"


exec /bin/bash
