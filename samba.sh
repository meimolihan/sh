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
        echo "无法检测系统版本，请手动检查并安装Samba。"
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

# 安装Samba
install_samba() {
    echo "检测到系统：$OS 版本：$VER"
    if [[ "$OS" == *"Debian"* || "$OS" == "Ubuntu" ]]; then
        sudo apt update
        sudo apt install -y samba
    elif [[ "$OS" == "CentOS" || "$OS" == "Red Hat Enterprise Linux" ]]; then
        sudo yum install -y samba samba-client samba-common
    elif [[ "$OS" == "Fedora" ]]; then
        sudo dnf install -y samba
    else
        echo "不支持的系统：$OS"
        exit 1
    fi
}

# 配置Samba共享
setup_samba() {
    echo "请输入共享文件夹路径（例如：/home/user/shared）："
    read -r share_path
    if [ ! -d "$share_path" ]; then
        echo "指定的路径不存在，正在创建..."
        sudo mkdir -p "$share_path"
        sudo chmod 777 "$share_path"  # 赋予新建文件夹777权限
        echo "已为共享文件夹 $share_path 赋予777权限。"
    fi

    # 确保root用户已启用Samba访问
    if ! sudo smbpasswd -e root; then
        echo "root用户已启用Samba访问。"
    else
        echo "root用户已存在，无需再次启用。"
    fi

    echo "请输入Samba共享用户名（非root用户）："
    read -r samba_user
    echo "请输入Samba共享密码："
    read -r -s samba_password

    # 添加或更新Samba用户
    if sudo smbpasswd -a "$samba_user" <<< "$samba_password
$samba_password"; then
        echo "Samba用户 $samba_user 已添加或更新。"
    else
        echo "添加或更新Samba用户 $samba_user 失败，请检查用户名是否已存在。"
    fi

    # 配置Samba共享
    sudo tee -a /etc/samba/smb.conf <<EOF

[$(basename "$share_path")]
     ## 指定共享是否应该在网络邻居中被浏览到，yes显示共享名称，no隐藏共享名称。
     browseable = yes
     ## 是否允许用户写入此共享，yes为可写入，no为不可写入。
     writable = yes
     ## 不允许匿名用户
     guest ok = no
     ## 指定共享用户是否可读写，yes为只读，no为读写。
     read only = no
     ## 新建文件的默认权限掩码
     create mask = 0777
     ## 新建目录的默认权限掩码
     directory mask = 0777
     ## 要求密码访问
     password required = yes
     ## 共享是否可用， yes为显示共享，no 为隐藏共享
     available = yes
     ## 这些VFS模块可以增强Samba服务器的功能
     vfs objects = catia fruit streams_xattr
     valid users = root, $samba_user
EOF

    # 重新启动Samba服务
    sudo systemctl restart smbd
    sudo systemctl enable smbd

    echo "Samba共享已配置完成！"
    echo "共享路径：$share_path"
    echo "内网IP地址：$internal_ip"
    echo "在资源管理器中输入：\\\\$internal_ip\\$(basename "$share_path")"
    echo "访问时使用用户名：root 或 $samba_user"
}

# 主程序
detect_os
get_internal_ip
install_samba
setup_samba