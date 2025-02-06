#!/bin/bash

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si)
        VER=$(lsb_release -sr)
    else
        echo "无法检测到系统类型！"
        exit 1
    fi
}

# 安装SSH服务
install_ssh() {
    echo "正在安装SSH服务..."
    if [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian GNU/Linux" ] || [ "$OS" == "Debian" ]; then
        sudo apt-get update
        sudo apt-get install -y openssh-server
    elif [ "$OS" == "CentOS Linux" ] || [ "$OS" == "Fedora" ]; then
        sudo yum install -y openssh-server
    else
        echo "不支持的系统类型！"
        exit 1
    fi
}

# 修改SSH配置文件
configure_ssh() {
    echo "正在修改SSH配置文件..."
    if [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian GNU/Linux" ] || [ "$OS" == "Debian" ]; then
        # Debian/Ubuntu配置
        sudo sed -i.bak -e '/Port 22/ a Port 22' \
            -e '/PermitRootLogin/ a PermitRootLogin yes' \
            -e '/GSSAPIAuthentication/ a GSSAPIAuthentication no' \
            -e '/UseDNS/ a UseDNS no' \
            -e '/ClientAliveInterval/ a ClientAliveInterval 10' \
            -e '/ClientAliveCountMax/ a ClientAliveCountMax 999' /etc/ssh/sshd_config
    elif [ "$OS" == "CentOS Linux" ] || [ "$OS" == "Fedora" ]; then
        # CentOS/Fedora配置
        sudo sed -i.bak -e '/Port 22/ a Port 22' \
            -e '/PermitRootLogin/ a PermitRootLogin yes' \
            -e '/ClientAliveInterval/ a ClientAliveInterval 10' \
            -e '/ClientAliveCountMax/ a ClientAliveCountMax 999' /etc/ssh/sshd_config
    else
        echo "不支持的系统类型！"
        exit 1
    fi
}

# 启动并启用SSH服务
start_ssh() {
    echo "正在启动SSH服务..."
    if [ "$OS" == "Ubuntu" ] || [ "$OS" == "Debian GNU/Linux" ] || [ "$OS" == "Debian" ]; then
        sudo systemctl enable --now ssh
    elif [ "$OS" == "CentOS Linux" ] || [ "$OS" == "Fedora" ]; then
        sudo systemctl enable --now sshd
    else
        echo "不支持的系统类型！"
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
}

# 主函数
main() {
    detect_os
    echo "检测到系统：$OS 版本：$VER"
    if ! command -v sshd >/dev/null 2>&1; then
        install_ssh
    else
        echo "SSH服务已安装。"
    fi
    configure_ssh
    start_ssh
    echo "SSH服务已启动并设置为开机自启。"
    get_internal_ip
    echo "内网IP地址：$internal_ip"
}

# 执行主函数
main