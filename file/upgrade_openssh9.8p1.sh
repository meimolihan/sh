#!/bin/bash

# 颜色定义
gl_hui='\033[38;5;59m'     # 灰色
gl_hong='\033[38;5;9m'     # 红色
gl_lv='\033[38;5;10m'      # 绿色
gl_huang='\033[38;5;11m'   # 黄色
gl_lan='\033[38;5;32m'     # 蓝色
gl_bai='\033[38;5;15m'     # 白色
gl_zi='\033[38;5;13m'      # 紫色
gl_bufan='\033[38;5;14m'   # 亮青色

# 日志函数
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# 分割线函数
print_line() {
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
}

# 标题样式
print_title() {
    echo -e "${gl_zi}>>> ${1}${gl_bai}"
}

# 返回提示函数
cancel_return() {
    local menu_name="${1:-上一级选单}"
    echo -e "${gl_lv}即将返回到 ${gl_huang}${menu_name}${gl_lv}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    sleep 0.6
    echo ""
    clear
}

# 无效输入处理函数
handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回${gl_bai}"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回${gl_bai}"
    sleep 0.5
    return 2
}

# 无效Y/N输入处理函数
handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

# 错误处理函数
handle_error() {
    local exit_code=$?
    local error_message=$1
    local func_name=$2
    
    if [ $exit_code -ne 0 ]; then
        print_line
        log_error "执行失败: ${error_message}"
        echo -e "${gl_hui}函数: ${func_name}${gl_bai}"
        echo -e "${gl_hui}退出码: ${exit_code}${gl_bai}"
        echo -e "${gl_hui}时间: $(date)${gl_bai}"
        print_line
        
        # 等待用户输入
        echo -e "${gl_bai}按任意键查看详细错误信息${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n 1 -s -r
        echo ""
        
        # 显示最后5行日志
        if [ -f "/var/log/syslog" ]; then
            echo -e "${gl_hui}最后5行系统日志:${gl_bai}"
            tail -5 /var/log/syslog
        elif [ -f "/var/log/messages" ]; then
            echo -e "${gl_hui}最后5行系统日志:${gl_bai}"
            tail -5 /var/log/messages
        fi
        
        print_line
        echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n 1 -s -r
        exit $exit_code
    fi
}

# 设置最新OpenSSH版本号
set_latest_openssh_version() {
    log_info "正在获取最新OpenSSH版本号${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    OPENSSH_VERSION=$(curl -s https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/ 2>/dev/null | grep -oP 'openssh-\K[0-9]+\.[0-9]+p[0-9]+' | sort -V | tail -n 1)
    if [ -z "$OPENSSH_VERSION" ]; then
        log_error "无法获取OpenSSH版本号"
        echo -e "${gl_hui}可能原因:${gl_bai}"
        echo -e "${gl_hui}1. 网络连接问题${gl_bai}"
        echo -e "${gl_hui}2. 网站不可访问${gl_bai}"
        echo -e "${gl_hui}3. 格式解析错误${gl_bai}"
        return 1
    fi
    log_ok "最新OpenSSH版本: ${OPENSSH_VERSION}"
}

# 检测系统类型
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        log_info "检测到操作系统: ${OS}"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        log_info "检测到操作系统: CentOS/RHEL"
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        log_info "检测到操作系统: Debian"
    elif [ -f /etc/alpine-release ]; then
        OS="alpine"
        log_info "检测到操作系统: Alpine"
    else
        log_error "无法检测操作系统类型${gl_bai}"
        echo -e "${gl_hui}尝试使用uname命令: $(uname -a)${gl_bai}"
        return 1
    fi
}

# 等待并检查锁文件
wait_for_lock() {
    local max_wait=30
    local wait_count=0
    
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        wait_count=$((wait_count + 1))
        if [ $wait_count -ge $max_wait ]; then
            log_error "等待锁文件超时(30秒)，请检查是否有其他包管理进程运行"
            return 1
        fi
        log_warn "等待dpkg锁释放 (${wait_count}/${max_wait})${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        sleep 1
    done
}

# 修复dpkg中断问题
fix_dpkg() {
    log_info "尝试修复dpkg配置${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    if [ $? -eq 0 ]; then
        log_ok "dpkg修复完成"
    else
        log_error "dpkg修复失败"
        return 1
    fi
}

# 安装依赖包
install_dependencies() {
    log_info "开始安装编译依赖${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    case $OS in
        ubuntu|debian)
            wait_for_lock
            fix_dpkg
            DEBIAN_FRONTEND=noninteractive apt update
            if [ $? -ne 0 ]; then
                log_error "apt update失败"
                return 1
            fi
            DEBIAN_FRONTEND=noninteractive apt install -y build-essential zlib1g-dev libssl-dev libpam0g-dev wget ntpdate -o Dpkg::Options::="--force-confnew"
            ;;
        centos|rhel|almalinux|rocky)
            yum install -y epel-release
            yum groupinstall -y "Development Tools"
            yum install -y zlib-devel openssl-devel pam-devel wget ntpdate
            ;;
        fedora)
            dnf install -y epel-release
            dnf groupinstall -y "Development Tools"
            dnf install -y zlib-devel openssl-devel pam-devel wget ntpdate
            ;;
        alpine)
            apk add build-base zlib-dev openssl-dev pam-dev wget ntpdate
            ;;
        *)
            log_error "不支持的操作系统: ${OS}"
            return 1
            ;;
    esac
    
    handle_error "安装依赖包失败" "install_dependencies"
    log_ok "依赖安装完成"
}

# 下载、编译和安装OpenSSH
install_openssh() {
    log_info "开始下载OpenSSH ${OPENSSH_VERSION}${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    # 检查wget是否可用
    if ! command -v wget &> /dev/null; then
        log_error "wget命令未找到，请先安装wget"
        return 1
    fi
    
    wget --no-check-certificate --timeout=30 --tries=3 https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-${OPENSSH_VERSION}.tar.gz
    
    if [ $? -ne 0 ]; then
        log_error "OpenSSH下载失败"
        echo -e "${gl_hui}可能原因:${gl_bai}"
        echo -e "${gl_hui}1. 网络连接问题${gl_bai}"
        echo -e "${gl_hui}2. 版本号错误: ${OPENSSH_VERSION}${gl_bai}"
        echo -e "${gl_hui}3. 服务器不可访问${gl_bai}"
        return 1
    fi
    log_ok "OpenSSH下载完成"
    
    if [ ! -f "openssh-${OPENSSH_VERSION}.tar.gz" ]; then
        log_error "下载的文件不存在: openssh-${OPENSSH_VERSION}.tar.gz"
        return 1
    fi
    
    log_info "解压OpenSSH源码包${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    tar -xzf "openssh-${OPENSSH_VERSION}.tar.gz"
    
    if [ $? -ne 0 ]; then
        log_error "解压失败"
        return 1
    fi
    
    DIR_NAME="openssh-${OPENSSH_VERSION}"
    if [ ! -d "$DIR_NAME" ]; then
        log_error "解压后的目录不存在: ${DIR_NAME}"
        return 1
    fi
    
    cd "$DIR_NAME" || { log_error "无法进入目录: ${DIR_NAME}"; return 1; }
    
    log_info "配置编译选项${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    ./configure --prefix=/usr/local --sysconfdir=/etc/ssh
    
    handle_error "配置失败" "install_openssh.configure"
    
    log_info "编译OpenSSH${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    make -j$(nproc)
    
    handle_error "编译失败" "install_openssh.make"
    
    log_info "安装OpenSSH${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    make install
    
    handle_error "安装失败" "install_openssh.make_install"
    
    log_ok "OpenSSH安装完成"
}

# 重启SSH服务
restart_ssh() {
    log_info "备份原ssh二进制文件"
    if [ -f "/usr/bin/ssh" ]; then
        mv /usr/bin/ssh /usr/bin/ssh.bak
        log_ok "已备份原ssh到 /usr/bin/ssh.bak"
    fi
    
    if [ -f "/usr/local/bin/ssh" ]; then
        ln -sf /usr/local/bin/ssh /usr/bin/ssh
        log_ok "已创建符号链接"
    else
        log_error "新版本ssh未找到: /usr/local/bin/ssh"
        return 1
    fi
    
    log_info "重启SSH服务${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    # 尝试多种服务管理方式
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        # 使用systemctl
        if systemctl restart ssh 2>/dev/null; then
            log_ok "SSH服务重启完成 (systemctl ssh)"
        elif systemctl restart sshd 2>/dev/null; then
            log_ok "SSH服务重启完成 (systemctl sshd)"
        else
            log_warn "systemctl重启失败，尝试service命令"
        fi
    fi
    
    # 尝试service命令
    if command -v service &> /dev/null; then
        if service ssh restart 2>/dev/null; then
            log_ok "SSH服务重启完成 (service ssh)"
        elif service sshd restart 2>/dev/null; then
            log_ok "SSH服务重启完成 (service sshd)"
        else
            log_warn "service重启失败"
        fi
    fi
    
    # 尝试直接kill并重启
    if [ -f "/usr/local/sbin/sshd" ]; then
        pkill sshd 2>/dev/null
        sleep 2
        /usr/local/sbin/sshd -f /etc/ssh/sshd_config
        if [ $? -eq 0 ]; then
            log_ok "SSH服务已启动"
        else
            log_error "SSH服务启动失败，请手动检查"
            return 1
        fi
    fi
}

# 设置路径优先级
set_path_priority() {
    NEW_SSH_PATH=$(which sshd 2>/dev/null)
    if [ -z "$NEW_SSH_PATH" ]; then
        NEW_SSH_PATH=$(find /usr/local -name sshd 2>/dev/null | head -1)
    fi
    
    if [ -z "$NEW_SSH_PATH" ]; then
        log_warn "未找到新版本sshd,跳过路径设置"
        return
    fi
    
    NEW_SSH_DIR=$(dirname "$NEW_SSH_PATH")
    if [[ ":$PATH:" != *":$NEW_SSH_DIR:"* ]]; then
        export PATH="$NEW_SSH_DIR:$PATH"
        echo "export PATH=\"$NEW_SSH_DIR:\$PATH\"" >> ~/.bashrc
        log_ok "已设置路径优先级: ${NEW_SSH_DIR}"
    fi
}

# 验证更新
verify_installation() {
    print_line
    log_info "SSH版本验证:"
    
    echo -e "${gl_hui}客户端版本:${gl_bai}"
    ssh -V 2>&1 || echo -e "${gl_hong}无法获取ssh版本${gl_bai}"
    
    echo -e "\n${gl_hui}服务端版本:${gl_bai}"
    sshd -V 2>&1 | head -1 || echo -e "${gl_hong}无法获取sshd版本${gl_bai}"
    
    echo -e "\n${gl_hui}可执行文件路径:${gl_bai}"
    which ssh && which sshd
    print_line
}

# 清理下载的文件
clean_up() {
    cd .. 2>/dev/null || return
    if [ -d "openssh-${OPENSSH_VERSION}" ]; then
        rm -rf "openssh-${OPENSSH_VERSION}"
        log_ok "已清理源码目录"
    fi
    
    if [ -f "openssh-${OPENSSH_VERSION}.tar.gz" ]; then
        rm -f "openssh-${OPENSSH_VERSION}.tar.gz"
        log_ok "已清理压缩包"
    fi
}

# 检查OpenSSH版本并修复
check_openssh_version() {
    clear
    print_title "SSH高危漏洞修复工具"
    echo -e "${gl_bai}视频介绍: https://www.bilibili.com/video/BV1dm421G7dy?t=0.1${gl_bai}"
    print_line
    
    # 检查curl是否可用
    if ! command -v curl &> /dev/null; then
        log_error "curl命令未找到，请先安装curl"
        echo -e "${gl_hui}Ubuntu/Debian: apt install curl${gl_bai}"
        echo -e "${gl_hui}CentOS/RHEL: yum install curl${gl_bai}"
        echo -e "${gl_hui}Alpine: apk add curl${gl_bai}"
        print_line
        echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n 1 -s -r
        exit 1
    fi
    
    # 检查当前SSH版本
    if ! command -v ssh &> /dev/null; then
        log_error "ssh命令未找到，请先安装OpenSSH"
        print_line
        echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n 1 -s -r
        exit 1
    fi
    
    current_version=$(ssh -V 2>&1 | grep -oE '[0-9]+\.[0-9]+[^ ]*' | head -1)
    
    if [ -z "$current_version" ]; then
        log_error "无法获取当前SSH版本"
        echo -e "${gl_hui}ssh -V 输出: $(ssh -V 2>&1)${gl_bai}"
        current_version="未知"
    fi
    
    min_version=8.5
    max_version=9.8
    
    # 提取主版本号进行比较
    main_version=$(echo "$current_version" | grep -oE '^[0-9]+\.[0-9]+')
    
    if [ -n "$main_version" ]; then
        if awk -v ver="$main_version" -v min="$min_version" -v max="$max_version" 'BEGIN{if(ver>=min && ver<=max) exit 0; else exit 1}'; then
            log_warn "SSH版本: ${current_version} 在8.5到9.8之间，存在安全风险，需要修复${gl_bai}"
            print_line
            
            read -r -e -p "$(echo -e "${gl_bai}确定继续修复吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
                [Yy])
                    log_info "开始修复流程${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                    print_line
                    
                    # 设置错误捕获
                    set -e
                    trap 'handle_error "脚本执行出错" "main"' ERR
                    
                    detect_os || exit 1
                    set_latest_openssh_version || exit 1
                    install_dependencies || exit 1
                    install_openssh || exit 1
                    restart_ssh || exit 1
                    set_path_priority
                    verify_installation
                    clean_up
                    
                    log_ok "SSH漏洞修复完成"
                    print_line
                    echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                    read -r -n 1 -s -r
                    ;;
                [Nn])
                    log_info "已取消修复操作"
                    cancel_return
                    return 0
                    ;;
                *)
                    handle_y_n
                    return 1
                    ;;
            esac
        else
            log_ok "SSH版本: ${current_version} 不在受影响范围(8.5-9.8)，无需修复${gl_bai}"
            print_line
            echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s -r
            return 0
        fi
    else
        log_warn "无法解析SSH版本: ${current_version}"
        print_line
        read -r -e -p "$(echo -e "${gl_bai}无法确定版本是否受影响，是否继续修复? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
        case "$choice" in
            [Yy])
                log_info "开始修复流程${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                print_line
                
                detect_os || exit 1
                set_latest_openssh_version || exit 1
                install_dependencies || exit 1
                install_openssh || exit 1
                restart_ssh || exit 1
                set_path_priority
                verify_installation
                clean_up
                
                log_ok "SSH更新完成"
                print_line
                echo -e "${gl_bai}按任意键退出${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
                read -r -n 1 -s -r
                ;;
            [Nn])
                log_info "已取消操作"
                cancel_return
                return 0
                ;;
            *)
                handle_y_n
                return 1
                ;;
        esac
    fi
}

# 主函数
main() {
    # 创建日志文件
    LOG_FILE="/tmp/ssh_fix_$(date +%Y%m%d_%H%M%S).log"
    exec 2>&1 | tee -a "$LOG_FILE"
    
    # 显示日志文件位置
    echo -e "${gl_hui}详细日志保存到: ${LOG_FILE}${gl_bai}"
    
    check_openssh_version
}

# 脚本入口
main "$@"