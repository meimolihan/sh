#!/bin/bash

sh_download() {
    rm -rf /root/mobufan.sh /usr/local/bin/m
    local script_path="$HOME/mobufan.sh"
    
    # 判断系统类型
    if [ -s /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            istoreos) ISTOREOS=1 ;;
            *)        ISTOREOS=0 ;;
        esac
    else
        ISTOREOS=0
    fi
    
    if [[ "$1" =~ ^(cn|en|tw|jp|kr|ru|ir)$ ]]; then
        local lang="$1"
        curl -sS -o "$script_path" "https://gitee.com/meimolihan/sh/raw/master/mobufan.sh" || return 1
        chmod +x "$script_path"
        "$script_path" "${@:2}"
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
    
    # 兼容iStoreOS创建快捷方式
    local link_path="/usr/local/bin/m"
    
    # 删除可能已存在的软链接
    if [ -L "$link_path" ] || [ -f "$link_path" ]; then
        rm -f "$link_path"
    fi
    
    # 创建软链接
    if ln -sf "$script_path" "$link_path"; then
        echo "快捷命令已创建: 'm' -> $script_path"
    else
        echo "警告：创建软链接失败，尝试其他路径..."
        # 尝试 /usr/bin
        if ln -sf "$script_path" "/usr/bin/m"; then
            link_path="/usr/bin/m"
            echo "快捷命令已创建: '/usr/bin/m' -> $script_path"
        else
            echo "错误：无法创建软链接，请手动执行: $script_path"
        fi
    fi
    
    # 检查PATH是否包含软链接路径
    local link_dir=$(dirname "$link_path")
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$(echo "$link_dir" | sed 's/[\/&]/\\&/g')$"; then
        echo "注意：$link_dir 不在PATH中，可能需要添加到PATH或使用完整路径"
    fi
    
    # 测试命令是否可用
    if command -v m >/dev/null 2>&1; then
        echo "✓ 快捷命令 'm' 已可用"
    else
        echo "⚠  'm' 命令未找到，可能需要重新登录或执行: source /etc/profile"
        echo "   或者直接使用: $script_path"
    fi
    
    # 执行脚本
    echo -e "\n执行脚本..."
    "$script_path" "$@"
}

sh_download "$@"

exec /bin/bash