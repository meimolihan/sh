#!/bin/bash

# 检测系统版本
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        echo "无法检测系统版本，请手动检查并安装NFS服务。"
        exit 1
    fi
}

# 获取内网IP地址
get_internal_ip() {
    if [[ "$OS" == *"Debian"* || "$OS" == "Ubuntu" ]]; then
        internal_ip=$(hostname -I | awk '{print $1}')
    elif [[ "$OS" == "CentOS" || "$OS" == "Red Hat Enterprise Linux" || "$OS" == "Fedora" ]]; then
        internal_ip=$(ip route get 1 | awk '{print $NF; exit}')
    else
        echo "无法获取内网IP地址。"
        internal_ip="未知"
    fi
    echo "内网IP地址：$internal_ip"
}

# 安装NFS服务
install_nfs() {
    echo "检测到系统：$OS 版本：$VER"
    if [[ "$OS" == *"Debian"* || "$OS" == "Ubuntu" ]]; then
        sudo apt update
        sudo apt install -y nfs-kernel-server
    elif [[ "$OS" == "CentOS" || "$OS" == "Red Hat Enterprise Linux" ]]; then
        sudo yum install -y nfs-utils
        sudo systemctl enable nfs-server.service
    elif [[ "$OS" == "Fedora" ]]; then
        sudo dnf install -y nfs-utils
        sudo systemctl enable nfs-server.service
    else
        echo "不支持的系统：$OS"
        exit 1
    fi
}

# 配置NFS共享
setup_nfs() {
    echo "请输入共享文件夹路径（例如：/home/user/shared）："
    read -r share_path
    if [ ! -d "$share_path" ]; then
        echo "指定的路径不存在，正在创建..."
        sudo mkdir -p "$share_path"
        sudo chmod 777 "$share_path"  # 赋予新建文件夹777权限
        echo "已为共享文件夹 $share_path 赋予777权限。"
    fi

    # 默认允许所有客户端访问
    client_ip="*"

    # 配置NFS共享
    sudo tee -a /etc/exports <<EOF

$share_path    $client_ip(rw,fsid=0,no_subtree_check,no_root_squash,insecure,sync)
EOF

    # 重新启动NFS服务
    if [[ "$OS" == *"Debian"* || "$OS" == "Ubuntu" ]]; then
        sudo systemctl restart nfs-kernel-server
    elif [[ "$OS" == "CentOS" || "$OS" == "Red Hat Enterprise Linux" || "$OS" == "Fedora" ]]; then
        sudo systemctl restart nfs-server
    fi

    echo "NFS共享已配置完成！"
    echo "服务端使用sudo showmount -e查看本机NFS共享目录"
    echo "共享路径：$share_path"
    echo "内网IP地址：$internal_ip"
    echo "允许访问的客户端：所有客户端（*）"
    echo "在客户端上，可以使用以下命令挂载共享："
    echo "sudo mount $internal_ip:$share_path /mnt"
}

# 主程序
detect_os
get_internal_ip
install_nfs
setup_nfs