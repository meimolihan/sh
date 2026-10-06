cat > test.sh <<'EOF'
#!/bin/bash

# 颜色变量定义
gl_hui='\e[37m'
gl_hong='\033[31m'
gl_lv='\033[32m'
gl_huang='\033[33m'
gl_lan='\033[34m'
gl_zi='\033[35m'
gl_bufan='\033[96m'
gl_bai='\033[0m'

# 日志函数
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

# 公共函数
handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回"
    sleep 1
    echo -e "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

exit_script() {
    clear
    exit 0
}

# 获取IP地址函数
ip_address() {
    ipv4_address=$(ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    if [ -z "$ipv4_address" ]; then
        ipv4_address=$(hostname -I 2>/dev/null | awk '{print $1}' | head -n 1)
    fi
    if [ -z "$ipv4_address" ]; then
        ipv4_address="127.0.0.1"
    fi
}

# 显示IP地址
show_ip() {
    ip_address
    echo -e "${gl_bufan}服务器IP地址:${gl_bai} $ipv4_address"
}

# 安装命令函数
install() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            log_info "正在安装 $cmd..."
            if command -v apt &> /dev/null; then
                apt update > /dev/null 2>&1 && apt install -y "$cmd" > /dev/null 2>&1
            elif command -v yum &> /dev/null; then
                yum install -y "$cmd" > /dev/null 2>&1
            fi
            if command -v "$cmd" &> /dev/null; then
                log_ok "$cmd 安装完成"
            else
                log_error "$cmd 安装失败"
            fi
        else
            log_info "$cmd 已经安装"
        fi
    done
}

# 检查磁盘空间函数
check_disk_space() {
    local required_gb="$1"
    local target_dir="$2"
    
    # 将GB转换为KB
    local required_kb=$((required_gb * 1024 * 1024))
    
    # 获取可用空间（KB）
    local available_kb=$(df -k "$target_dir" 2>/dev/null | awk 'NR==2 {print $4}')
    
    if [ -z "$available_kb" ]; then
        log_warn "无法检查磁盘空间，跳过检查"
        return 0
    fi
    
    if [ "$available_kb" -lt "$required_kb" ]; then
        log_error "磁盘空间不足！"
        log_error "需要: ${required_gb}GB"
        log_error "可用: $((available_kb / 1024 / 1024))GB"
        return 1
    else
        log_ok "磁盘空间检查通过"
        return 0
    fi
}

# 安装Docker函数
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "正在安装Docker..."
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
        systemctl start docker > /dev/null 2>&1
        systemctl enable docker > /dev/null 2>&1
        if command -v docker &> /dev/null; then
            log_ok "Docker 安装完成"
        else
            log_error "Docker 安装失败"
            exit 1
        fi
    else
        log_info "Docker 已经安装"
    fi
    
    # 检查docker-compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "正在安装docker-compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose > /dev/null 2>&1
        chmod +x /usr/local/bin/docker-compose
        if command -v docker-compose &> /dev/null; then
            log_ok "docker-compose 安装完成"
        else
            log_error "docker-compose 安装失败"
            exit 1
        fi
    else
        log_info "docker-compose 已经安装"
    fi
}

# 添加应用ID函数
add_app_id() {
    if [ ! -f "/vol1/1000/compose/appno.txt" ]; then
        mkdir -p /vol1/1000/compose
        touch /vol1/1000/compose/appno.txt
    fi
    
    if ! grep -q "^${app_id}$" /vol1/1000/compose/appno.txt 2>/dev/null; then
        echo "$app_id" >> /vol1/1000/compose/appno.txt
        log_ok "应用ID $app_id 已添加"
    fi
}

# 检查应用是否已安装（通过appno.txt）
check_app_installed() {
    local app_id="$1"
    if [ -f "/vol1/1000/compose/appno.txt" ]; then
        if grep -q "^${app_id}$" /vol1/1000/compose/appno.txt 2>/dev/null; then
            return 0  # 已安装
        fi
    fi
    return 1  # 未安装
}

# 优化后的检查应用状态函数
check_compose_status() {
    local compose_dir="$1"
    if [ -d "$compose_dir" ] && [ -f "$compose_dir/docker-compose.yml" ]; then
        cd "$compose_dir" 2>/dev/null || return 1
        local services=$(docker compose ps --services 2>/dev/null)
        if [ -n "$services" ]; then
            while IFS= read -r service; do
                local status=$(docker compose ps "$service" --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4 2>/dev/null || echo "unknown")
                if [ "$status" = "running" ]; then
                    echo -e "${gl_lv}✓ ${service} (运行中)${gl_bai}"
                elif [ -n "$status" ]; then
                    echo -e "${gl_hui}✗ ${service} (${status})${gl_bai}"
                else
                    echo -e "${gl_hui}✗ ${service} (状态未知)${gl_bai}"
                fi
            done <<< "$services"
        else
            echo -e "${gl_hui}容器未创建${gl_bai}"
        fi
        cd - > /dev/null 2>&1
    else
        echo -e "${gl_hui}未安装${gl_bai}"
    fi
}

# 检查Docker Compose应用状态
check_docker_compose_app() {
    local app_dir="/vol1/1000/compose/$compose_dir_name"
    if [ -d "$app_dir" ] && [ -f "$app_dir/docker-compose.yml" ]; then
        echo -e "${gl_lv}已安装${gl_bai}"
        return 0
    else
        echo -e "${gl_hui}未安装${gl_bai}"
        return 1
    fi
}

# 显示当前端口
show_current_port() {
    if [ -f "/vol1/1000/compose/${compose_dir_name}_port.conf" ]; then
        local current_port=$(cat "/vol1/1000/compose/${compose_dir_name}_port.conf" 2>/dev/null)
        if [ -n "$current_port" ]; then
            echo -e "${gl_bufan}当前端口:${gl_bai} $current_port"
        fi
    fi
}

# 显示访问地址
show_access_url() {
    ip_address
    if [ -f "/vol1/1000/compose/${compose_dir_name}_port.conf" ]; then
        local current_port=$(cat "/vol1/1000/compose/${compose_dir_name}_port.conf" 2>/dev/null)
        if [ -n "$current_port" ]; then
            echo -e "${gl_bufan}访问地址:${gl_bai} http://${ipv4_address}:${current_port}"
        fi
    fi
}

# 简单直接的端口修改函数
modify_compose_port() {
    local new_port="$1"
    local compose_file="docker-compose.yml"
    
    log_info "正在修改端口为: ${new_port}"
    
    # 备份原文件
    cp "$compose_file" "${compose_file}.backup" 2>/dev/null
    
    # 检查是否使用模板文件
    if [ -f "docker-compose.yml.template" ]; then
        log_info "使用模板文件生成新配置..."
        # 使用模板文件生成新的docker-compose.yml
        local template_content=$(cat "docker-compose.yml.template")
        
        # 根据应用类型进行不同的替换
        case $compose_dir_name in
        "qbittorrent")
            # 替换qbittorrent模板中的变量
            echo "$template_content" | \
                sed "s/\${HOST_PORT:-8080}/$new_port/g" | \
                sed "s/\${HOST_PORT}/$new_port/g" > "$compose_file"
            ;;
        "xunlei")
            # 替换xunlei模板中的变量
            echo "$template_content" | \
                sed "s/\${HOST_PORT:-2345}/$new_port/g" | \
                sed "s/\${HOST_PORT}/$new_port/g" > "$compose_file"
            ;;
        *)
            # 通用替换
            echo "$template_content" | \
                sed "s/\${HOST_PORT:-${default_port}}/$new_port/g" | \
                sed "s/\${HOST_PORT}/$new_port/g" > "$compose_file"
            ;;
        esac
        log_ok "已从模板生成新配置"
    else
        # 没有模板文件，直接修改现有的docker-compose.yml
        log_info "未找到模板文件，直接修改现有配置..."
        
        # 保存模板文件供以后使用
        cp "$compose_file" "docker-compose.yml.template" 2>/dev/null
        
        # 简单直接的端口修改逻辑
        case $compose_dir_name in
        "qbittorrent")
            # qBittorrent特殊处理
            # 1. 修改端口映射中的主机端口
            if grep -q "[0-9]*:8080" "$compose_file"; then
                sed -i "s/\"[0-9]*:8080\"/\"${new_port}:8080\"/g" "$compose_file" 2>/dev/null
                sed -i "s/ [0-9]*:8080/ ${new_port}:8080/g" "$compose_file" 2>/dev/null
                sed -i "s/-[[:space:]]*[0-9]*:8080/- ${new_port}:8080/g" "$compose_file" 2>/dev/null
            fi
            
            # 2. 修改WEBUI_PORT环境变量为8080（容器内部端口）
            sed -i "s/WEBUI_PORT=[0-9]*/WEBUI_PORT=8080/g" "$compose_file" 2>/dev/null
            sed -i "s/WEBUI_PORT=\${HOST_PORT}/WEBUI_PORT=8080/g" "$compose_file" 2>/dev/null
            ;;
            
        "xunlei")
            # Xunlei特殊处理
            if grep -q "[0-9]*:2345" "$compose_file"; then
                sed -i "s/\"[0-9]*:2345\"/\"${new_port}:2345\"/g" "$compose_file" 2>/dev/null
                sed -i "s/ [0-9]*:2345/ ${new_port}:2345/g" "$compose_file" 2>/dev/null
                sed -i "s/-[[:space:]]*[0-9]*:2345/- ${new_port}:2345/g" "$compose_file" 2>/dev/null
            fi
            ;;
            
        *)
            # 通用处理：查找并修改端口映射
            # 查找第一个端口映射行并修改
            local port_line=$(grep -n "[0-9]*:${default_port}" "$compose_file" | head -1)
            if [ -n "$port_line" ]; then
                local line_num=$(echo "$port_line" | cut -d':' -f1)
                sed -i "${line_num}s/[0-9]*:${default_port}/${new_port}:${default_port}/g" "$compose_file" 2>/dev/null
            fi
            ;;
        esac
    fi
    
    # 如果有.env文件，也更新
    if [ -f ".env" ]; then
        sed -i "s/^HOST_PORT=[0-9]*/HOST_PORT=${new_port}/g" .env 2>/dev/null
        sed -i "s/^PORT=[0-9]*/PORT=${new_port}/g" .env 2>/dev/null
    fi
    
    log_ok "端口修改完成"
    return 0
}

# 安装前配置处理
prepare_compose_config() {
    local docker_port="$1"
    
    # 下载原始配置文件并保存为模板
    log_info "下载docker-compose配置文件..."
    wget -q -O docker-compose.yml.template "$compose_file_url"
    if [ $? -ne 0 ]; then
        log_error "下载docker-compose.yml失败"
        return 1
    fi
    
    # 从模板生成实际配置文件
    log_info "生成docker-compose.yml配置文件..."
    
    # 读取模板内容
    local template_content=$(cat docker-compose.yml.template)
    
    # 根据应用类型进行不同的替换
    case $compose_dir_name in
    "qbittorrent")
        # qBittorrent特殊处理
        # 替换端口变量
        echo "$template_content" | \
            sed "s/\${HOST_PORT:-8080}/$docker_port/g" | \
            sed "s/\${HOST_PORT}/$docker_port/g" | \
            sed "s/WEBUI_PORT=\${HOST_PORT}/WEBUI_PORT=8080/g" > docker-compose.yml
        ;;
        
    "xunlei")
        # Xunlei特殊处理
        echo "$template_content" | \
            sed "s/\${HOST_PORT:-2345}/$docker_port/g" | \
            sed "s/\${HOST_PORT}/$docker_port/g" > docker-compose.yml
        ;;
        
    *)
        # 通用替换
        echo "$template_content" | \
            sed "s/\${HOST_PORT:-${default_port}}/$docker_port/g" | \
            sed "s/\${HOST_PORT}/$docker_port/g" > docker-compose.yml
        ;;
    esac
    
    # 下载环境配置文件（如果有）
    if [ -n "$env_file_url" ]; then
        log_info "下载环境配置文件..."
        wget -q -O .env "$env_file_url"
        # 替换.env文件中的端口
        if [ -f ".env" ]; then
            sed -i "s/^HOST_PORT=[0-9]*/HOST_PORT=$docker_port/g" .env 2>/dev/null
        fi
    fi
    
    return 0
}

# Docker Compose应用管理主函数
docker_compose_app() {
    local sub_choice=""
    while true; do
        clear
        echo -e "${gl_zi}>>> $app_name${gl_bai}"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        
        # 显示应用状态
        check_docker_compose_app
        
        # 显示应用信息
        echo -e "${gl_bufan}应用名称:${gl_bai} $app_name"
        echo -e "${gl_bufan}应用描述:${gl_bai} $app_text"
        echo -e "${gl_bufan}官方介绍:${gl_bai} $app_url"
        
        # 显示端口信息
        show_current_port
        
        # 显示访问地址
        show_access_url
        
        # 检查应用状态
        echo -e "${gl_bufan}容器状态:${gl_bai}"
        check_compose_status "/vol1/1000/compose/$compose_dir_name"
        
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}安装应用"
        echo -e "${gl_bufan}2.  ${gl_bai}启动应用"
        echo -e "${gl_bufan}3.  ${gl_bai}停止应用"
        echo -e "${gl_bufan}4.  ${gl_bai}重启应用"
        echo -e "${gl_bufan}5.  ${gl_bai}查看日志"
        echo -e "${gl_bufan}6.  ${gl_bai}更新应用"
        echo -e "${gl_bufan}7.  ${gl_bai}卸载应用"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "${gl_bufan}8.  ${gl_bai}修改端口"
        echo -e "${gl_bufan}9.  ${gl_bai}查看配置"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
            # 安装应用
            if [ -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_warn "应用已存在，请先卸载再重新安装"
                break_end
                continue
            fi
            
            # 检查磁盘空间
            if ! check_disk_space "$app_size" "/vol1/1000/compose"; then
                log_error "磁盘空间不足，安装中止"
                break_end
                continue
            fi
            
            # 询问端口
            read -r -e -p "请输入应用对外服务端口，回车默认使用${default_port}端口: " custom_port
            local docker_port=${custom_port:-${default_port}}
            
            # 安装必要组件
            install wget curl
            install_docker
            
            # 创建应用目录
            mkdir -p "/vol1/1000/compose/$compose_dir_name"
            cd "/vol1/1000/compose/$compose_dir_name" || {
                log_error "无法进入应用目录"
                break_end
                continue
            }
            
            # 准备配置文件（使用模板方式）
            if ! prepare_compose_config "$docker_port"; then
                log_error "配置文件准备失败"
                break_end
                continue
            fi
            
            # 启动应用
            log_info "正在启动应用..."
            docker compose up -d
            
            if [ $? -eq 0 ]; then
                log_ok "应用安装成功！"
                add_app_id
                
                # 保存端口到配置文件
                echo "$docker_port" > "/vol1/1000/compose/${compose_dir_name}_port.conf"
                
                # 显示访问信息
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                show_access_url
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                
                # 执行自定义安装后函数
                if [ -n "$post_install_func" ]; then
                    $post_install_func
                fi
                
                # 显示容器状态
                echo -e "${gl_bufan}容器状态:${gl_bai}"
                check_compose_status "/vol1/1000/compose/$compose_dir_name"
            else
                log_error "应用启动失败，请检查日志"
                echo -e "${gl_huang}提示: 尝试运行 'docker compose logs' 查看错误信息${gl_bai}"
            fi
            ;;
            
        2)
            # 启动应用
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装，请先安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                log_info "正在启动应用..."
                docker compose up -d
                if [ $? -eq 0 ]; then
                    log_ok "应用启动成功！"
                    echo -e "${gl_bufan}容器状态:${gl_bai}"
                    check_compose_status "/vol1/1000/compose/$compose_dir_name"
                else
                    log_error "应用启动失败"
                fi
            fi
            ;;
            
        3)
            # 停止应用
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                log_info "正在停止应用..."
                docker compose down
                if [ $? -eq 0 ]; then
                    log_ok "应用已停止"
                else
                    log_error "停止应用失败"
                fi
            fi
            ;;
            
        4)
            # 重启应用
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                log_info "正在重启应用..."
                docker compose restart
                if [ $? -eq 0 ]; then
                    log_ok "应用重启成功！"
                else
                    log_error "重启应用失败"
                fi
            fi
            ;;
            
        5)
            # 查看日志
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                echo -e "${gl_huang}按 Ctrl+C 退出日志查看${gl_bai}"
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                docker compose logs -f --tail=20
            fi
            ;;
            
        6)
            # 更新应用
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                log_info "正在更新应用..."
                
                # 停止应用
                docker compose down
                
                # 拉取最新镜像
                docker compose pull
                
                # 重新启动
                docker compose up -d
                
                if [ $? -eq 0 ]; then
                    log_ok "应用更新成功！"
                else
                    log_error "应用更新失败"
                fi
            fi
            ;;
            
        7)
            # 卸载应用
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                echo -e "${gl_hong}警告：这将删除所有应用数据、容器和镜像！${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}确认要卸载吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                case "$confirm" in
                [Yy])
                    cd "/vol1/1000/compose/$compose_dir_name" || {
                        log_error "无法进入应用目录"
                        break_end
                        continue
                    }
                    log_info "正在卸载应用..."
                    
                    # 1. 停止并删除容器和卷
                    docker compose down -v
                    
                    # 2. 删除镜像
                    if [ -n "$docker_images" ]; then
                        for image in $docker_images; do
                            log_info "正在删除镜像: $image"
                            docker rmi -f "$image" 2>/dev/null || true
                        done
                    fi
                    
                    cd /vol1/1000/compose || exit
                    rm -rf "$compose_dir_name"
                    rm -f "/vol1/1000/compose/${compose_dir_name}_port.conf"
                    
                    # 从appno.txt中删除应用ID
                    if [ -f "/vol1/1000/compose/appno.txt" ]; then
                        sed -i "/\b${app_id}\b/d" /vol1/1000/compose/appno.txt
                    fi
                    
                    log_ok "应用已卸载"
                    ;;
                *)
                    log_info "取消卸载"
                    ;;
                esac
            fi
            ;;
            
        8)
            # 修改端口
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                cd "/vol1/1000/compose/$compose_dir_name" || {
                    log_error "无法进入应用目录"
                    break_end
                    continue
                }
                
                # 获取当前端口
                local current_port=$(cat "/vol1/1000/compose/${compose_dir_name}_port.conf" 2>/dev/null || echo "$default_port")
                
                # 询问新端口
                read -r -e -p "请输入新的应用端口，当前为${current_port}: " new_port
                if [ -n "$new_port" ] && [ "$new_port" != "$current_port" ]; then
                    # 停止应用
                    docker compose down
                    
                    # 确保有模板文件（如果不存在，创建当前文件为模板）
                    if [ ! -f "docker-compose.yml.template" ]; then
                        # 尝试恢复模板
                        if [ -f "docker-compose.yml" ]; then
                            log_info "创建模板文件..."
                            cp docker-compose.yml docker-compose.yml.template
                        fi
                    fi
                    
                    # 修改端口
                    modify_compose_port "$new_port"
                    
                    # 保存新端口
                    echo "$new_port" > "/vol1/1000/compose/${compose_dir_name}_port.conf"
                    
                    # 重启应用
                    docker compose up -d
                    
                    if [ $? -eq 0 ]; then
                        log_ok "端口已修改为: $new_port"
                        show_access_url
                    else
                        log_error "端口修改失败"
                    fi
                else
                    log_info "端口未更改"
                fi
            fi
            ;;
            
        9)
            # 查看配置
            if [ ! -d "/vol1/1000/compose/$compose_dir_name" ]; then
                log_error "应用未安装"
            else
                echo -e "${gl_huang}当前应用配置信息:${gl_bai}"
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                echo -e "${gl_bai}存储目录: /vol1/1000/compose/$compose_dir_name"
                show_current_port
                show_access_url
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                echo -e "${gl_bai}docker-compose.yml内容:"
                cat "/vol1/1000/compose/$compose_dir_name/docker-compose.yml" 2>/dev/null | head -20
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                echo -e "${gl_bai}模板文件:"
                if [ -f "/vol1/1000/compose/$compose_dir_name/docker-compose.yml.template" ]; then
                    echo "存在模板文件，可用于端口修改"
                else
                    echo "无模板文件"
                fi
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                echo -e "${gl_bai}容器状态:"
                docker ps -a | grep "$compose_dir_name" || echo "未找到相关容器"
                echo -e "${gl_bufan}————————————————————————${gl_bai}"
                if [ -n "$docker_images" ]; then
                    echo -e "${gl_bai}使用的镜像:"
                    for image in $docker_images; do
                        echo "  - $image"
                    done
                fi
            fi
            ;;
            
        0)
            break
            ;;
            
        00|000|0000)
            exit_script
            ;;
            
        *)
            handle_invalid_input
            ;;
        esac
        
        break_end
    done
}

# 预定义应用配置函数
setup_compose_app_config() {
    local app_type="$1"
    
    case $app_type in
    "xunlei")
        # Xunlei下载器
        app_id="1"
        app_name="迅雷下载器"
        app_text="迅雷离线下载工具，支持BT、磁力链接等多种下载方式"
        app_url="https://github.com/cnk3x/xunlei"
        compose_dir_name="xunlei"
        default_port="2345"
        container_port="2345"  # 容器内部端口
        app_size="1"
        compose_file_url="https://gitee.com/meimolihan/sh/raw/master/compose/xunlei/docker-compose.yml"
        env_file_url=""
        docker_images="cnk3x/xunlei"
        
        # 自定义安装后函数
        post_install_func() {
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
            echo -e "${gl_lv}安装完成提示:${gl_bai}"
            echo -e "${gl_bai}1. 首次访问需要使用手机迅雷App扫码登录"
            echo -e "${gl_bai}2. 登录后可能需要输入邀请码: 迅雷牛通"
            echo -e "${gl_bai}3. 下载目录: /vol1/1000/compose/xunlei/downloads"
            echo -e "${gl_bai}4. 配置文件: /vol1/1000/compose/xunlei/config"
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
        }
        ;;
        
    "qbittorrent")
        # qbittorrent下载器
        app_id="2"
        app_name="qBittorrent下载器"
        app_text="qBittorrent 是一个开源免费的 BitTorrent 客户端，功能强大，支持磁力链接和种子文件下载"
        app_url="官方网站: https://www.qbittorrent.org/"
        compose_dir_name="qbittorrent"
        default_port="8080"
        container_port="8080"  # 容器内部端口
        app_size="1"
        compose_file_url="https://gitee.com/meimolihan/sh/raw/master/compose/qbittorrent/docker-compose.yml"
        env_file_url=""
        docker_images="lscr.io/linuxserver/qbittorrent:latest"
        
        # 自定义安装后函数
        post_install_func() {
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
            echo -e "${gl_lv}qBittorrent 安装完成！${gl_bai}"
            echo -e "${gl_bai}1. 默认用户名: admin"
            echo -e "${gl_bai}2. 默认密码: adminadmin"
            echo -e "${gl_bai}3. 登录后建议立即修改密码"
            echo -e "${gl_bai}4. 下载目录: /vol1/1000/compose/qbittorrent/downloads"
            echo -e "${gl_bai}5. 配置文件: /vol1/1000/compose/qbittorrent/config"
            echo -e "${gl_bai}6. BT端口: 6881 (确保防火墙已开放)"
            echo -e "${gl_bai}7. 支持功能: 磁力链接、种子文件、RSS订阅、搜索引擎"
            echo -e "${gl_bufan}————————————————————————${gl_bai}"
        }
        ;;
    *)
        log_error "未知的应用类型"
        return 1
        ;;
    esac
}

# 主菜单
compose_app_manager() {
    while true; do
        clear
        echo -e "${gl_zi}>>> Docker Compose应用管理器${gl_bai}"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        
        # 定义应用列表
        local app_list=("xunlei:迅雷下载器" "qbittorrent:qBittorrent下载器")
        
        # 显示应用菜单（已安装的显示绿色）
        for i in "${!app_list[@]}"; do
            local app_type=$(echo "${app_list[$i]}" | cut -d':' -f1)
            local app_display=$(echo "${app_list[$i]}" | cut -d':' -f2)
            
            # 设置应用配置以获取app_id
            setup_compose_app_config "$app_type"
            
            # 检查应用是否已安装
            if check_app_installed "$app_id"; then
                # 已安装，显示绿色
                echo -e "${gl_bufan}$((i+1)).  ${gl_lv}${app_display}${gl_bai}"
            else
                # 未安装，显示白色
                echo -e "${gl_bufan}$((i+1)).  ${gl_bai}${app_display}"
            fi
        done
        
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}————————————————————————${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        
        case $choice in
        1)
            setup_compose_app_config "xunlei"
            docker_compose_app
            ;;
        2)
            setup_compose_app_config "qbittorrent"
            docker_compose_app
            ;;
        0)
            break
            ;;
        00|000|0000)
            exit_script
            ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

# 主函数
main() {
    # 检查是否为root用户
    if [ "$(id -u)" != "0" ]; then
        log_error "请使用root用户运行此脚本"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p /vol1/1000/compose
    
    # 进入菜单
    compose_app_manager
}

# 启动脚本
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi
EOF