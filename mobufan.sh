#!/bin/bash
sh_v="1.0.1"

gl_hui='\e[37m'       # 定义灰色（或浅白）字体的ANSI转义序列
gl_hong='\033[31m'    # 定义红色字体的ANSI转义序列
gl_lv='\033[32m'      # 定义绿色字体的ANSI转义序列
gl_huang='\033[33m'   # 定义黄色字体的ANSI转义序列
gl_lan='\033[34m'     # 定义蓝色字体的ANSI转义序列
gl_bai='\033[0m'      # 定义重置终端颜色的ANSI转义序列（恢复默认样式）
gl_zi='\033[35m'      # 定义紫色（或品红）字体的ANSI转义序列
gl_bufan='\033[96m'   # 定义亮青色（或浅蓝）字体的ANSI转义序列

canshu="default"
# permission_granted="true"
# ENABLE_STATS="true"

###### 日志函数（中文标签，彩色输出）
log_info() { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok() { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn() { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }

###### 根据参数设置全局代理和执行标志的配置函数。
quanju_canshu() {
    if [ "$canshu" = "CN" ]; then
        zhushi=0
        gh_proxy="https://gh.kejilion.pro/"
    elif [ "$canshu" = "V6" ]; then
        zhushi=1
        gh_proxy="https://gh.kejilion.pro/"
    else
        zhushi=1 # 0 表示执行，1 表示不执行
        gh_proxy="https://"
    fi
}
quanju_canshu

canshu_v6() {
    if grep -q '^canshu="V6"' /usr/local/bin/m >/dev/null 2>&1; then
        sed -i 's/^canshu="default"/canshu="V6"/' ~/mobufan.sh
    fi
}

CheckFirstRun_true() {
    if grep -q '^permission_granted="true"' /usr/local/bin/m >/dev/null 2>&1; then
        sed -i 's/^permission_granted="false"/permission_granted="true"/' ~/mobufan.sh
    fi
}

yinsiyuanquan2() {
    if grep -q '^ENABLE_STATS="false"' /usr/local/bin/m >/dev/null 2>&1; then
        sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/mobufan.sh
    fi
}

# 执行配置同步函数
canshu_v6
CheckFirstRun_true
yinsiyuanquan2

# 清理旧别名并部署新脚本
sed -i '/^alias m=/d' ~/.bashrc >/dev/null 2>&1
sed -i '/^alias m=/d' ~/.profile >/dev/null 2>&1
sed -i '/^alias m=/d' ~/.bash_profile >/dev/null 2>&1
cp -f ./mobufan.sh ~/mobufan.sh >/dev/null 2>&1
cp -f ~/mobufan.sh /usr/local/bin/m >/dev/null 2>&1
source ~/.bashrc

###### 提示用户同意条款
CheckUserAgreement() {
    local config="$HOME/.mobufan_license"

    # 已同意则直接返回
    [[ -f "$config" && "$(cat "$config")" == "agreed" ]] && return

    # 未同意，开始交互
    clear
    echo -e "${gl_bufan}欢迎使用 mobufan 脚本工具箱${gl_bai}"
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"
    echo -e "${gl_huang}首次使用，请先阅读并同意用户许可协议：${gl_bai}"
    echo -e "${gl_lv}https://sh.mobufan.eu.org:666/${gl_bai}"
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"
    read -r -e -p "$(echo -e "${gl_bai}是否同意以上条款？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" input

    if [[ "$input" =~ ^[Yy]$ ]]; then
        echo "agreed" >"$config"
        echo -e "${gl_bufan}感谢你的同意！${gl_bai}"
    else
        echo -e "${gl_hong}你必须同意条款才能继续使用。${gl_bai}"
        exit 1
    fi
}
CheckUserAgreement

###### 公用函数_检查软件‮否是‬安装
check_and_install(){
    local pkg=$1
    [[ -z $pkg ]] && { log_error "未提供包名"; return 2; }

    local ver=""
    if command -v "$pkg" &>/dev/null; then
        ver=$("$pkg" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
    fi
    if [[ -z $ver ]]; then
        if command -v dpkg-query &>/dev/null; then
            ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null) || true
        elif command -v rpm &>/dev/null; then
            ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null) || true
        fi
    fi
    if [[ -n $ver ]]; then
        printf '%b%s 已安装，版本 %s%b\n' "$gl_huang" "$pkg" "$ver" "$gl_bai"
        return 0
    fi

    # 新增：y/n 确认
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}未检测到 $pkg，是否现在安装? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" ans
        case ${ans,,} in
            y|yes) break ;;
            n|no)  log_warn "已取消安装 $pkg"; return 1 ;;
            *)     echo -e "${gl_bai}无效输入，请输入 (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): " ;;
        esac
    done

    printf '%b即将自动安装 %s...%b\n' "$gl_huang" "$pkg" "$gl_bai"
    install "$pkg"
    local rc=$?
    if (( rc == 0 )) && command -v "$pkg" &>/dev/null; then
        return 0
    else
        log_error "${pkg} 安装失败"
        return 1
    fi
}


###### 函数_mobufan.sh提示更新
mobufan_sh_update() {
    local sh_v_new
    sh_v_new=$(curl -s https://gitee.com/meimolihan/sh/raw/master/mobufan.sh |
        grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)

    # 只有发现新版本才提示
    if [ "$sh_v" != "$sh_v_new" ]; then
        echo -e "${gl_hong}发现新版本！${gl_bai}"

        # 定义文本和变量
        local current_text="${gl_bai}当前版本 ${gl_huang}v$sh_v"
        local latest_text="${gl_bai}最新版本号 ${gl_lv}v$sh_v_new"
        local input_text="${gl_bai}请你输入${gl_huang} 666"
        local update_text="${gl_bai}更新至新版 ${gl_lv}v$sh_v_new"

        # 计算显示宽度（去除颜色代码后的实际文本长度）
        calc_display_width() {
            echo "$1" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g' | wc -m
        }

        # 计算两列的宽度
        local col1_width1 col2_width1 col1_width2 col2_width2
        col1_width1=$(calc_display_width "$current_text")
        col2_width1=$(calc_display_width "$latest_text")
        col1_width2=$(calc_display_width "$input_text")
        col2_width2=$(calc_display_width "$update_text")

        # 找出每列的最大宽度
        local max_col1_width max_col2_width
        max_col1_width=$((col1_width1 > col1_width2 ? col1_width1 : col1_width2))
        max_col2_width=$((col2_width1 > col2_width2 ? col2_width1 : col2_width2))

        # 填充空格使每列对齐
        local pad_col1_1 pad_col1_2
        pad_col1_1=$((max_col1_width - col1_width1))
        pad_col1_2=$((max_col1_width - col1_width2))

        # 输出对齐的两列
        echo -e "${current_text}$(printf '%*s' $pad_col1_1)    ${latest_text}${gl_bai}"
        echo -e "${input_text}$(printf '%*s' $pad_col1_2)    ${update_text}${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
    fi
}

# 定义一个函数来执行命令
run_command() {
    if [ "$zhushi" -eq 0 ]; then
        "$@"
    fi
}

####### 函数：获取内网IP地址
get_internal_ip() {
    local ip=""
    # 尝试多种方法获取内网IP
    if command -v hostname >/dev/null 2>&1; then
        ip=$(hostname -I | awk '{print $1}')
    elif command -v ip >/dev/null 2>&1; then
        ip=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    elif command -v ifconfig >/dev/null 2>&1; then
        ip=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1)
    fi
    echo "$ip"
}


###### 修改文件权限
file_chmod() {
    while :; do
        clear
        echo
        log_info "当前目录文件列表："
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo
        ls --color=auto -x
        echo
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo
        echo -e "${gl_zi}>>> 修改文件权限${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入文件名 (输入 ${gl_hong}0${gl_bai} 返回上级菜单): ")" filename

        # 输入 0 直接返回上级菜单
        [[ "$filename" == "0" ]] && break

        # --- 文件存在性检查 ---
        [[ -e "$filename" ]] || {
            log_error "文件不存在: $filename"
            continue
        }

        # --- 显示当前权限 ---
        curr_oct=$(stat -c "%a" "$filename")
        curr_sym=$(stat -c "%A" "$filename")
        echo -e ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bai}当前 ${gl_huang}${filename}${gl_bai} 权限: ${curr_sym}  (${gl_huang}${curr_oct}${gl_bai})"
        echo -e ""

        # --- 循环读入并校验新权限 ---
        while :; do
            read -r -e -p "$(echo -e "${gl_bai}请输入新权限 (如 ${gl_huang}755${gl_bai} 或  ${gl_lv}+x${gl_bai}/${gl_hui}-x${gl_bai}等): ")" new_perm

            # 正则校验：纯八进制 000-777 或符号模式
            if [[ $new_perm =~ ^[0-7]{1,3}$|^[ugoa]*[+-=][rwxXstugo]*$ ]]; then
                break # 输入合法，跳出内层循环
            else
                log_error "输入格式错误！请重新输入（例如 644、755、+x、g-w 等）"
            fi
        done

        # --- 真正执行 chmod ---
        if chmod "$new_perm" "$filename" 2>/dev/null; then
            sync
            new_oct=$(stat -c "%a" "$filename")
            new_sym=$(stat -c "%A" "$filename")
            echo -e ""
            log_ok "权限已修改！"
            echo -e ""
            echo -e "${gl_bai}修改后 ${gl_huang}${filename}${gl_bai} 权限: ${new_sym}  (${gl_huang}${new_oct}${gl_bai})"
        else
            echo -e ""
            log_error "修改失败，请检查文件系统权限或输入格式"
        fi
        echo -e "${gl_bufan}------------------------${gl_bai}"
        break_end
        continue
    done
}

###### 文件搜索
search_file_here() {
    local keyword
    local non_interactive=false
    
    # 检查是否有参数传入（排除第一个参数如果是函数名本身）
    if [[ $# -gt 0 ]]; then
        # 如果第一个参数是函数名本身，则跳过
        if [[ "$1" == "search_file_here" ]]; then
            shift
        fi
        # 取剩余参数作为关键词
        if [[ $# -gt 0 ]]; then
            keyword="$*"
            non_interactive=true
        fi
    fi
    
    while true; do
        if [[ "$non_interactive" == false ]]; then
            clear
            echo -e ""
            echo -e "${gl_zi}>>> 文件模糊搜索${gl_bai}"
            echo -e "${gl_bufan}------------------------------------${gl_bai}"

            log_info "当前目录: $(pwd)"
            echo
            ls --color=auto -x
            echo
            echo -e "${gl_bufan}------------------------------------${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入搜索关键词 (支持模糊匹配) (${gl_huang}0${gl_bai} 返回): ")" keyword
            [[ "$keyword" == "0" ]] && break
            [[ -z "$keyword" ]] && {
                log_error "关键词不能为空！"
                sleep 1.5
                continue
            }
        fi

        local here="$(pwd)"
        local found=0

        if [[ "$non_interactive" == false ]]; then
            log_info "正在执行模糊搜索 \"${keyword}\" ..."
            echo
            echo -e "${gl_bufan}------------------------------------${gl_bai}"
        fi

        # 多种模糊搜索方法
        local search_results=()
        
        # 方法1: 基本模糊匹配（包含子字符串）
        while IFS= read -r -d '' file; do
            search_results+=("$file")
        done < <(find "$here" -iname "*${keyword}*" -type f -print0 2>/dev/null)

        # 方法2: 正则表达式匹配
        while IFS= read -r -d '' file; do
            if [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                search_results+=("$file")
            fi
        done < <(find "$here" -type f -iregex ".*${keyword}.*" -print0 2>/dev/null)

        # 方法3: 使用ag/silver searcher（如果可用）- 更强的模糊搜索
        if command -v ag &>/dev/null; then
            while IFS= read -r -d '' file; do
                if [[ ! " ${search_results[@]} " =~ " ${file} " ]]; then
                    search_results+=("$file")
                fi
            done < <(ag -l -g ".*${keyword}.*" "$here" 2>/dev/null | tr '\n' '\0')
        fi

        # 去重并排序
        local unique_results=()
        while IFS= read -r -d '' file; do
            unique_results+=("$file")
        done < <(printf "%s\0" "${search_results[@]}" | sort -uz)

        # 显示结果
        if [[ ${#unique_results[@]} -gt 0 ]]; then
            if [[ "$non_interactive" == true ]]; then
                echo "找到 ${#unique_results[@]} 个匹配的文件："
            else
                log_ok "找到 ${#unique_results[@]} 个匹配的文件："
            fi
            echo
            for file in "${unique_results[@]}"; do
                local abs_path="$(readlink -f "$file" 2>/dev/null || echo "$file")"
                if [[ "$non_interactive" == true ]]; then
                    echo "$abs_path"
                else
                    echo -e "${gl_lv}${abs_path}${gl_bai}"
                    
                    # 显示文件详细信息
                    if [[ -r "$file" ]]; then
                        local file_info=$(ls -lh "$file" 2>/dev/null)
                        local size=$(echo "$file_info" | awk '{print $5}')
                        local time_info=$(ls -l --time-style=long-iso "$file" 2>/dev/null | awk '{print $6, $7}')
                        local permissions=$(ls -l "$file" 2>/dev/null | awk '{print $1}')
                        
                        echo -e "  ${gl_hui}权限: $permissions | 大小: $size | 修改: $time_info${gl_bai}"
                        
                        # 如果是文本文件，显示前几行预览
                        if file "$file" 2>/dev/null | grep -q "text"; then
                            echo -e "  ${gl_zi}预览: $(head -1 "$file" 2>/dev/null | cut -c-50)...${gl_bai}"
                        fi
                    else
                        echo -e "  ${gl_hui}[无法读取文件详细信息]${gl_bai}"
                    fi
                    echo
                fi
                ((found++))
            done
        else
            if [[ "$non_interactive" == true ]]; then
                echo "未找到包含 \"${keyword}\" 的文件。"
            else
                log_warn "未找到包含 \"${keyword}\" 的文件。"
                echo
                log_info "搜索建议："
                echo -e "  ${gl_hui}• 尝试不同的关键词"
                echo -e "  ${gl_hui}• 使用更通用的词汇"
                echo -e "  ${gl_hui}• 检查文件是否在其他位置${gl_bai}"
                
                # 显示类似文件建议
                log_info "类似文件："
                find "$here" -type f -name "*" | head -10 | while read -r similar; do
                    echo -e "  ${gl_hui}$(basename "$similar")${gl_bai}"
                done
            fi
        fi
        
        if [[ "$non_interactive" == false ]]; then
            echo -e "${gl_bufan}------------------------------------${gl_bai}"
        fi

        # 如果是传参模式，执行一次就退出
        if [[ "$non_interactive" == true ]]; then
            break
        fi

        echo -e "${gl_lv}操作完成${gl_bai}"
        read -n 1 -s -r -p "$(echo -e "${gl_huang}按任意键继续搜索…${gl_bai}")"
        echo
    done
}
###### 文件内容搜索
search_here() {
    local keyword
    local non_interactive=false
    
    # 检查是否有参数传入
    if [[ $# -gt 0 ]]; then
        keyword="$*"
        non_interactive=true
    fi
    
    while true; do # ← 1. 无限循环
        if [[ "$non_interactive" == false ]]; then
            clear
            echo -e ""
            echo -e "${gl_zi}>>> 当前目录内容搜索${gl_bai}"
            echo -e "${gl_bufan}------------------------------------${gl_bai}"

            log_info "当前目录文件列表："
            echo
            ls --color=auto -x
            echo
            echo -e "${gl_bufan}------------------------------------${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入要搜索的关键词 (${gl_huang}0${gl_bai} 返回): ")" keyword
            [[ "$keyword" == "0" ]] && break # ← 2. 用户输入 0 就跳出循环
            [[ -z "$keyword" ]] && {
                log_error "关键词不能为空！"
                sleep 1.5
                continue
            }
        fi

        local here="$(pwd)"
        local found=0

        log_info "正在扫描当前目录 ..."
        mapfile -t lines < <(grep -in --color=always -H "$keyword" * 2>/dev/null)

        if ((${#lines[@]})); then
            for line in "${lines[@]}"; do
                IFS=: read -r file line_num content <<<"$line"
                echo
                echo -e "${gl_bufan}------------------------------------${gl_bai}"
                log_ok "${here}/${file}"
                log_ok "第 ${gl_zi}${line_num}${gl_lv} 行"
                log_ok "${gl_hui}${content}${gl_bai}"
                echo -e "${gl_bufan}------------------------------------${gl_bai}"
                ((found++))
            done
        else
            echo
            log_warn "未在当前目录任何文件内找到匹配内容。"
        fi

        # 如果是传参模式，执行一次就退出
        if [[ "$non_interactive" == true ]]; then
            break
        fi

        echo -e "${gl_lv}操作完成${gl_bai}"
        read -n 1 -s -r -p "$(echo -e "${gl_huang}按任意键继续搜索…${gl_bai}")"
        echo
    done # ← 3. 循环结束
}

###### 增强版安全读取函数（支持默认值、验证、退出功能、和数字范围检查）
safe_read() {
    local prompt="$1"
    local var_name="$2"
    local validation="${3:-any}" # 验证类型：number / file / dir / any
    local default="$4"
    local min="${5:-}"
    local max="${6:-}"

    while :; do
        local full_prompt="${prompt}"
        [[ -n $default ]] && full_prompt+=" [默认: ${default}]"
        full_prompt+=": "

        local raw
        IFS= read -r -e -p "$full_prompt" raw || return 1 # 保留空格
        [[ -z $raw && -n $default ]] && raw="$default"
        [[ -z $raw ]] && echo "错误：输入不能为空，请重新输入" && continue
        [[ $raw =~ ^(q|quit|exit)$ ]] && echo "退出操作" && return 1

        case "$validation" in
        number)
            [[ $raw =~ ^[0-9]+$ ]] || {
                echo "错误：请输入有效的数字"
                return
            }
            [[ -n $min && $raw -lt $min ]] && {
                echo "错误：数字不能小于 $min"
                return
            }
            [[ -n $max && $raw -gt $max ]] && {
                echo "错误：数字不能大于 $max"
                return
            }
            ;;
        file)
            local expanded
            eval "expanded=\"$raw\""
            [[ -f $expanded ]] || {
                echo "错误：文件 '$raw' 不存在"
                return
            }
            ;;
        dir)
            local expanded
            eval "expanded=\"$raw\""
            [[ -d $expanded ]] || {
                echo "错误：目录 '$raw' 不存在"
                return
            }
            ;;
        any) ;; # 只检查非空
        *)
            echo "错误：未知的验证类型: $validation"
            return 1
            ;;
        esac
        printf -v "$var_name" "%s" "$raw" # 原样赋值
        return 0
    done
}

###### 智能获取本机IPv4和IPv6地址的网络信息收集函数。
ip_address() {

    # --------- 只留本地地址兜底 ---------
    get_local_ip() {
        ip route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^ ]+' ||
            hostname -I 2>/dev/null | awk '{print $1}' ||
            ifconfig 2>/dev/null | awk '/inet / && $2!="127.0.0.1"{print $2; exit}' ||
            ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | head -n1
    }

    ipv4_address=$(get_local_ip) # 永远本地地址，永不落空
    ipv6_address=""              # 需要再补
    isp_info="N/A"
    country="N/A"
    city="N/A"
}
###### 跨Linux发行版的通用软件包安装函数，能够自动检测并适配不同系统的包管理器进行软件安装。
install() {
    [[ $# -eq 0 ]] && {
        log_error "未提供软件包参数!"
        return 1
    }

    local pkg mgr ver
    for pkg in "$@"; do
        ver=""
        if command -v "$pkg" &>/dev/null; then
            ver=$("$pkg" --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
        fi
        if [[ -z "$ver" ]]; then
            if command -v dpkg-query &>/dev/null; then
                ver=$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null) || true
            elif command -v rpm &>/dev/null; then
                ver=$(rpm -q --qf '%{VERSION}' "$pkg" 2>/dev/null) || true
            fi
        fi
        if [[ -n "$ver" ]]; then
            printf '%b%s%b %b已安装%b %b版本%b %b%s%b\n' \
                   "$gl_huang" "$pkg" "$gl_bai" \
                   "$gl_lv" "$gl_bai" \
                   "$gl_bai" "$gl_bai" \
                   "$gl_lv" "$ver" "$gl_bai"
            continue
        fi
        printf '%b正在安装 %s...%b\n' "$gl_huang" "$pkg" "$gl_bai"
        for mgr in dnf yum apt apk pacman zypper opkg pkg; do
            case $mgr in
            dnf) command -v dnf &>/dev/null && {
                dnf -y update
                dnf install -y epel-release
                dnf install -y "$pkg"
                continue 2
            } ;;
            yum) command -v yum &>/dev/null && {
                yum -y update
                yum install -y epel-release
                yum install -y "$pkg"
                continue 2
            } ;;
            apt) command -v apt &>/dev/null && {
                apt update -y
                apt install -y "$pkg"
                continue 2
            } ;;
            apk) command -v apk &>/dev/null && {
                apk update
                apk add "$pkg"
                continue 2
            } ;;
            pacman) command -v pacman &>/dev/null && {
                pacman -Syu --noconfirm
                pacman -S --noconfirm "$pkg"
                continue 2
            } ;;
            zypper) command -v zypper &>/dev/null && {
                zypper refresh
                zypper install -y "$pkg"
                continue 2
            } ;;
            opkg) command -v opkg &>/dev/null && {
                opkg update
                opkg install "$pkg"
                continue 2
            } ;;
            pkg) command -v pkg &>/dev/null && {
                pkg update
                pkg install -y "$pkg"
                continue 2
            } ;;
            esac
        done
    done
}

check_disk_space() {
    local required_gb=$1
    local path=${2:-/}

    mkdir -p "$path"

    local required_space_mb
    required_space_mb=$((required_gb * 1024))
    local available_space_mb
    available_space_mb=$(df -m "$path" | awk 'NR==2 {print $4}')

    if [ "$available_space_mb" -lt "$required_space_mb" ]; then
        echo -e "${gl_huang}提示: ${gl_bai}磁盘空间不足！"
        echo "当前可用空间: $((available_space_mb / 1024))G"
        echo "最小需求空间: ${required_gb}G"
        echo "无法继续安装，请清理磁盘空间后重试。"
        break_end
        mobufan
    fi
}

install_dependency() {
    install wget unzip tar jq grep

    check_swap
    auto_optimize_dns
    prefer_ipv4

}

remove() {
    if [ $# -eq 0 ]; then
        echo "未提供软件包参数!"
        return 1
    fi

    for package in "$@"; do
        echo -e "${gl_huang}正在卸载 $package...${gl_bai}"
        if command -v dnf &>/dev/null; then
            dnf remove -y "$package"
        elif command -v yum &>/dev/null; then
            yum remove -y "$package"
        elif command -v apt &>/dev/null; then
            apt purge -y "$package"
        elif command -v apk &>/dev/null; then
            apk del "$package"
        elif command -v pacman &>/dev/null; then
            pacman -Rns --noconfirm "$package"
        elif command -v zypper &>/dev/null; then
            zypper remove -y "$package"
        elif command -v opkg &>/dev/null; then
            opkg remove "$package"
        elif command -v pkg &>/dev/null; then
            pkg delete -y "$package"
        else
            echo "未知的包管理器!"
            return 1
        fi
    done
}

# 通用 systemctl 函数，适用于各种发行版
systemctl() {
    local COMMAND="$1"
    local SERVICE_NAME="$2"

    if command -v apk &>/dev/null; then
        service "$SERVICE_NAME" "$COMMAND"
    else
        /bin/systemctl "$COMMAND" "$SERVICE_NAME"
    fi
}

# 重启服务
restart() {
    systemctl restart "$1"
    if cmd; then
        echo "$1 服务已重启。"
    else
        echo "错误：重启 $1 服务失败。"
    fi
}

# 启动服务
start() {
   systemctl start "$1"
    if cmd; then
        echo "$1 服务已启动。"
    else
        echo "错误：启动 $1 服务失败。"
    fi
}

# 停止服务
stop() {
    systemctl stop "$1"
    if cmd; then
        echo "$1 服务已停止。"
    else
        echo "错误：停止 $1 服务失败。"
    fi
}

# 查看服务状态
status() {
    systemctl status "$1"
    if cmd; then
        echo "$1 服务状态已显示。"
    else
        echo "错误：无法显示 $1 服务状态。"
    fi
}

enable() {
    local SERVICE_NAME="$1"
    if command -v apk &>/dev/null; then
        rc-update add "$SERVICE_NAME" default
    else
        /bin/systemctl enable "$SERVICE_NAME"
    fi

    echo -e "${gl_huang}$SERVICE_NAME ${gl_lv}已设置为开机自启。${gl_bai}"
}

###### 按任意键继续...
break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo "按任意键继续..."
    read -r -n 1 -s -r -p ""
    echo ""
    clear
}

###### 无效的输入,请重新输入!
handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入，请重新输入！${gl_zi} 1 ${gl_huang}秒后返回${gl_bai}"
    sleep 1
    echo -e  "\r${gl_lv}无效的输入，请重新输入！${gl_zi} 0 ${gl_lv}秒后返回${gl_bai}"
    sleep 0.5
    return 2        # 2 表示“输入非法”
}

###### 退出脚本
exit_script() {
    clear
    # echo -ne "\r${gl_hong}感谢使用，再见！ ${gl_zi}2${gl_hong} 秒后自动退出${gl_bai}"
    # sleep 1
    # echo -ne "\r${gl_huang}感谢使用，再见！ ${gl_zi}1${gl_huang} 秒后自动退出${gl_bai}"
    # sleep 1
    # echo -e "\r${gl_lv}感谢使用，再见！ ${gl_zi}0${gl_lv} 秒后自动退出${gl_bai}"
    # sleep 0.5
    # clear
    exit 0
}

mobufan() {
    cd ~
    mobufan_sh
}

stop_containers_or_kill_process() {
    local port=$1
    local containers
    containers=$(docker ps --filter "publish=$port" --format "{{.ID}}" 2>/dev/null)
    if [ -n "$containers" ]; then
        docker stop "$containers"
    else
        install lsof
        for pid in $(lsof -t -i:"$port"); do
            kill -9 "$pid"
        done
    fi
}

check_port() {
    stop_containers_or_kill_process 80
    stop_containers_or_kill_process 443
}

install_add_docker_cn() {

    local country
    country=$(curl -s ipinfo.io/country)
    if [ "$country" = "CN" ]; then
        cat >/etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
	"https://docker.1ms.run",
	"https://docker.m.ixdev.cn",
	"https://hub.rat.dev",
	"https://dockerproxy.net",
	"https://docker-registry.nmqu.com",
	"https://docker.amingg.com",
	"https://docker.hlmirror.com",
	"https://hub1.nat.tf",
	"https://hub2.nat.tf",
	"https://hub3.nat.tf",
	"https://docker.m.daocloud.io",
	"https://docker.kejilion.pro",
	"https://docker.367231.xyz",
	"https://hub.1panel.dev",
	"https://dockerproxy.cool",
	"https://docker.apiba.cn",
	"https://proxy.vvvv.ee"
  ]
}
EOF
    fi

    enable docker
    start docker
    restart docker

}

install_add_docker_guanfang() {
    local country
    country=$(curl -s ipinfo.io/country)
    if [ "$country" = "CN" ]; then
        cd ~
        curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/install && chmod +x install
        sh install --mirror Aliyun
        rm -f install
    else
        curl -fsSL https://get.docker.com | sh
    fi
    install_add_docker_cn

}

install_add_docker() {
    echo -e "${gl_huang}正在安装docker环境...${gl_bai}"
    if [ -f /etc/os-release ] && grep -q "Fedora" /etc/os-release; then
        install_add_docker_guanfang
    elif command -v dnf &>/dev/null; then
        dnf update -y
        dnf install -y yum-utils device-mapper-persistent-data lvm2
        rm -f /etc/yum.repos.d/docker*.repo >/dev/null
        country=$(curl -s ipinfo.io/country)
        arch=$(uname -m)
        if [ "$country" = "CN" ]; then
            curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo | tee /etc/yum.repos.d/docker-ce.repo >/dev/null
        else
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null
        fi
        dnf install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn

    elif [ -f /etc/os-release ] && grep -q "Kali" /etc/os-release; then
        apt update
        apt upgrade -y
        apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
        rm -f /usr/share/keyrings/docker-archive-keyring.gpg
        local country=$(curl -s ipinfo.io/country)
        local arch=$(uname -m)
        if [ "$country" = "CN" ]; then
            if [ "$arch" = "x86_64" ]; then
                sed -i '/^deb \[arch=amd64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list >/dev/null
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            elif [ "$arch" = "aarch64" ]; then
                sed -i '/^deb \[arch=arm64 signed-by=\/etc\/apt\/keyrings\/docker-archive-keyring.gpg\] https:\/\/mirrors.aliyun.com\/docker-ce\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list >/dev/null
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://mirrors.aliyun.com/docker-ce/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            fi
        else
            if [ "$arch" = "x86_64" ]; then
                sed -i '/^deb \[arch=amd64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list >/dev/null
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
                echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            elif [ "$arch" = "aarch64" ]; then
                sed -i '/^deb \[arch=arm64 signed-by=\/usr\/share\/keyrings\/docker-archive-keyring.gpg\] https:\/\/download.docker.com\/linux\/debian bullseye stable/d' /etc/apt/sources.list.d/docker.list >/dev/null
                mkdir -p /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker-archive-keyring.gpg >/dev/null
                echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bullseye stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null
            fi
        fi
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io
        install_add_docker_cn

    elif command -v apt &>/dev/null || command -v yum &>/dev/null; then
        install_add_docker_guanfang
    else
        install docker docker-compose
        install_add_docker_cn

    fi
    sleep 2
}

install_docker() {
    if ! command -v docker &>/dev/null; then
        install_add_docker
    fi
}

docker_ps() {
    while true; do
        clear
        echo -e "${gl_bufan}Docker容器列表${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo ""
        docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"
        echo ""
        echo -e "${gl_zi}>>> 容器操作${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}创建新的容器"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}2. ${gl_bai}启动指定容器             ${gl_bufan}6. ${gl_bai}启动所有容器"
        echo -e "${gl_bufan}3. ${gl_bai}停止指定容器             ${gl_bufan}7. ${gl_bai}停止所有容器"
        echo -e "${gl_bufan}4. ${gl_bai}删除指定容器             ${gl_bufan}8. ${gl_bai}删除所有容器"
        echo -e "${gl_bufan}5. ${gl_bai}重启指定容器             ${gl_bufan}9. ${gl_bai}重启所有容器"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}进入指定容器           ${gl_bufan}12. ${gl_bai}查看容器日志"
        echo -e "${gl_bufan}13. ${gl_bai}查看容器网络           ${gl_bufan}14. ${gl_bai}查看容器占用"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}15. ${gl_bai}开启容器端口访问       ${gl_bufan}16. ${gl_bai}关闭容器端口访问"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            read -r -e -p "请输入创建命令: " dockername
            $dockername
            ;;
        2)
            read -r -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
            docker start "$dockername"
            ;;
        3)
            read -r -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
            docker stop "$dockername"
            ;;
        4)
            read -r -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
            docker rm -f "$dockername"
            ;;
        5)
            read -r -e -p "请输入容器名（多个容器名请用空格分隔）: " dockername
            docker restart "$dockername"
            ;;
        6)
            docker start "$(docker ps -a -q)"
            ;;
        7)
            docker stop "$(docker ps -q)"
            ;;
        8)
            read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有容器吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                # docker rm -f $(docker ps -a -q)
                docker ps -a -q | xargs -r docker rm -f
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        9)
            docker restart "$(docker ps -q)"
            ;;
        11)
            read -r -e -p "请输入容器名: " dockername
            docker exec -it "$dockername" /bin/sh
            break_end
            ;;
        12)
            read -r -e -p "请输入容器名: " dockername
            docker logs "$dockername"
            break_end
            ;;
        13)
            echo ""
            container_ids=$(docker ps -q)
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
            printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"
            for container_id in $container_ids; do
                local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")
                local container_name=$(echo "$container_info" | awk '{print $1}')
                local network_info
                network_info=$(echo "$container_info" | cut -d' ' -f2-)
                while IFS= read -r -r line; do
                    local network_name=$(echo "$line" | awk '{print $1}')
                    local ip_address=$(echo "$line" | awk '{print $2}')
                    printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
                done <<<"$network_info"
            done
            break_end
            ;;
        14)
            docker stats --no-stream
            break_end
            ;;
        15)
            read -r -e -p "请输入容器名: " docker_name
            ip_address
            clear_container_rules "$docker_name" "$ipv4_address"
            local docker_port
            docker_port=$(docker port "$docker_name" | awk -F'[:]' '/->/ {print $NF}' | uniq)
            check_docker_app_ip
            break_end
            ;;
        16)
            read -r -e -p "请输入容器名: " docker_name
            ip_address
            block_container_port "$docker_name" "$ipv4_address"
            local docker_port=$(docker port "$docker_name" | awk -F'[:]' '/->/ {print $NF}' | uniq)
            check_docker_app_ip
            break_end
            ;;
        0) break ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

docker_image() {
    while true; do
        clear
        echo -e "${gl_bufan}Docker镜像列表${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo ""
        docker image ls
        echo ""
        echo -e "${gl_zi}>>> 镜像操作${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}获取指定镜像             ${gl_bufan}3. ${gl_bai}删除指定镜像"
        echo -e "${gl_bufan}2. ${gl_bai}更新指定镜像             ${gl_bufan}4. ${gl_bai}删除所有镜像"
        echo -e "${gl_bufan}5. ${gl_bai}打包指定镜像             ${gl_bufan}6. ${gl_bai}加载指定镜像"
        echo -e "${gl_bufan}7. ${gl_bai}为镜像打标签             "
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            read -r -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
            for name in $imagenames; do
                echo -e "${gl_huang}正在获取镜像: $name${gl_bai}"
                docker pull "$name"
            done
            ;;
        2)
            read -r -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
            for name in $imagenames; do
                echo -e "${gl_huang}正在更新镜像: $name${gl_bai}"
                docker pull "$name"
            done
            ;;
        3)
            echo -e "${gl_bai}删除指定镜像格式：${gl_huang}nginx:tag${gl_bai}"
            read -r -e -p "请输入镜像名（多个镜像名请用空格分隔）: " imagenames
            for name in $imagenames; do
                docker rmi -f "$name"
            done
            ;;
        4)
            read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有镜像吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                docker rmi -f "$(docker images -q)"
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        5)
            clear
            docker_image_pack
            break_end
            # bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/docker-image/pack-image.sh)
            ;;
        6)
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/docker-image/load-images.sh)
            break_end
            ;;
        7)
            while true; do
                clear
                echo ""
                echo -e "${gl_huang}本地镜像列表：${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e ""
                docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}"
                echo -e ""
                echo -e "${gl_bufan}------------------------${gl_bai}"
                # 输入源镜像
                read -r -e -p "$(echo -e "${gl_bai}请输入源镜像名称 (格式: ${gl_huang}nginx:tag${gl_bai} 或 ${gl_huang}image_id${gl_bai}, 输入 ${gl_hong}0${gl_bai} 返回上级): ")" source_image

                # 输入 0 返回上级菜单
                if [[ "$source_image" == "0" ]]; then
                    break
                fi

                # 验证源镜像是否存在
                if ! docker image inspect "$source_image" &>/dev/null; then
                    echo -ne "\r${gl_hong}错误:${gl_bai} 源镜像 ${gl_hong}'$source_image'${gl_bai} 不存在! ${gl_zi} 2 ${gl_bai} 秒后重新输入"
                    sleep 2
                    continue # 继续循环，重新显示当前界面
                fi

                # 输入目标镜像信息
                read -r -e -p "$(echo -e "${gl_bai}请输入目标镜像名称 (${gl_huang}不含标签${gl_bai}): ")" target_name
                read -r -e -p "$(echo -e "${gl_bai}请输入目标镜像标签 [${gl_huang}默认: latest]${gl_bai}: ")" target_tag
                target_tag=${target_tag:-latest}

                # 完整的目标镜像名称
                target_image="$target_name:$target_tag"

                echo ""
                echo "即将执行: docker tag $source_image $target_image"
                read -r -e -p "$(echo -e "${gl_bai}确认执行? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm

                if [[ $confirm == "y" || $confirm == "Y" ]]; then
                    if docker tag "$source_image" "$target_image"; then
                        echo -e "${gl_lv}标签创建成功!"
                        echo -e "${gl_bufan}新镜像: $target_image"
                    else
                        echo -e "${gl_hong}标签创建失败!"
                    fi
                else
                    echo "操作已取消"
                fi

                # 操作完成后询问是否继续
                echo ""
                break_end
            done
            ;;
        0) break ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

###### 检查 crontab 是否已安装，如果未安装则自动安装。
check_crontab_installed() {
    if ! command -v crontab >/dev/null 2>&1; then
        install_crontab
    fi
}

install_crontab() {

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
        ubuntu | debian | kali)
            apt update
            apt install -y cron
            systemctl enable cron
            systemctl start cron
            ;;
        centos | rhel | almalinux | rocky | fedora)
            yum install -y cronie
            systemctl enable crond
            systemctl start crond
            ;;
        alpine)
            apk add --no-cache cronie
            rc-update add crond
            rc-service crond start
            ;;
        arch | manjaro)
            pacman -S --noconfirm cronie
            systemctl enable cronie
            systemctl start cronie
            ;;
        opensuse | suse | opensuse-tumbleweed)
            zypper install -y cron
            systemctl enable cron
            systemctl start cron
            ;;
        iStoreOS | openwrt | ImmortalWrt | lede)
            opkg update
            opkg install cron
            /etc/init.d/cron enable
            /etc/init.d/cron start
            ;;
        FreeBSD)
            pkg install -y cronie
            sysrc cron_enable="YES"
            service cron start
            ;;
        *)
            echo "不支持的发行版: $ID"
            return
            ;;
        esac
    else
        echo "无法确定操作系统。"
        return
    fi

    echo -e "${gl_lv}crontab 已安装且 cron 服务正在运行。${gl_bai}"
}

docker_ipv6_on() {
    root_use
    install jq

    local CONFIG_FILE="/etc/docker/daemon.json"
    local REQUIRED_IPV6_CONFIG='{"ipv6": true, "fixed-cidr-v6": "2001:db8:1::/64"}'

    # 检查配置文件是否存在，如果不存在则创建文件并写入默认设置
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$REQUIRED_IPV6_CONFIG" | jq . >"$CONFIG_FILE"
        restart docker
    else
        # 使用jq处理配置文件的更新
        local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

        # 检查当前配置是否已经有 ipv6 设置
        local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq '.ipv6 // false')

        # 更新配置，开启 IPv6
        if [[ "$CURRENT_IPV6" == "false" ]]; then
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {ipv6: true, "fixed-cidr-v6": "2001:db8:1::/64"}')
        else
            UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq '. + {"fixed-cidr-v6": "2001:db8:1::/64"}')
        fi

        # 对比原始配置与新配置
        if [[ "$ORIGINAL_CONFIG" == "$UPDATED_CONFIG" ]]; then
            echo -e "${gl_huang}当前已开启ipv6访问${gl_bai}"
        else
            echo "$UPDATED_CONFIG" | jq . >"$CONFIG_FILE"
            restart docker
        fi
    fi
}

docker_ipv6_off() {
    root_use
    install jq

    local CONFIG_FILE="/etc/docker/daemon.json"

    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${gl_hong}配置文件不存在${gl_bai}"
        return
    fi

    # 读取当前配置
    local ORIGINAL_CONFIG=$(<"$CONFIG_FILE")

    # 使用jq处理配置文件的更新
    local UPDATED_CONFIG=$(echo "$ORIGINAL_CONFIG" | jq 'del(.["fixed-cidr-v6"]) | .ipv6 = false')

    # 检查当前的 ipv6 状态
    local CURRENT_IPV6=$(echo "$ORIGINAL_CONFIG" | jq -r '.ipv6 // false')

    # 对比原始配置与新配置
    if [[ "$CURRENT_IPV6" == "false" ]]; then
        echo -e "${gl_huang}当前已关闭ipv6访问${gl_bai}"
    else
        echo "$UPDATED_CONFIG" | jq . >"$CONFIG_FILE"
        restart docker
        echo -e "${gl_huang}已成功关闭ipv6访问${gl_bai}"
    fi
}

save_iptables_rules() {
    mkdir -p /etc/iptables
    touch /etc/iptables/rules.v4
    iptables-save >/etc/iptables/rules.v4
    check_crontab_installed
    crontab -l | grep -v 'iptables-restore' | crontab - >/dev/null 2>&1
    (
        crontab -l
        echo '@reboot iptables-restore < /etc/iptables/rules.v4'
    ) | crontab - >/dev/null 2>&1

}

iptables_open() {
    install iptables
    save_iptables_rules
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -F

    ip6tables -P INPUT ACCEPT
    ip6tables -P FORWARD ACCEPT
    ip6tables -P OUTPUT ACCEPT
    ip6tables -F
}

open_port() {
    local ports=("$@") # 将传入的参数转换为数组
    if [ ${#ports[@]} -eq 0 ]; then
        echo "请提供至少一个端口号"
        return 1
    fi

    install iptables

    for port in "${ports[@]}"; do
        # 删除已存在的关闭规则
        iptables -D INPUT -p tcp --dport "$port" -j DROP 2>/dev/null
        iptables -D INPUT -p udp --dport "$port" -j DROP 2>/dev/null

        # 添加打开规则
        if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
        fi

        if ! iptables -C INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport "$port" -j ACCEPT
            echo "已打开端口 ${port}"
        fi
    done
    save_iptables_rules
}

close_port() {
    local ports=("$@") # 将传入的参数转换为数组
    if [ ${#ports[@]} -eq 0 ]; then
        echo "请提供至少一个端口号"
        return 1
    fi

    install iptables

    for port in "${ports[@]}"; do
        # 删除已存在的打开规则
        iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null

        # 添加关闭规则
        if ! iptables -C INPUT -p tcp --dport "$port" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p tcp --dport "$port" -j DROP
        fi

        if ! iptables -C INPUT -p udp --dport "$port" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -p udp --dport "$port" -j DROP
            echo "已关闭端口 $port"
        fi
    done

    # 删除已存在的规则（如果有）
    iptables -D INPUT -i lo -j ACCEPT 2>/dev/null
    iptables -D FORWARD -i lo -j ACCEPT 2>/dev/null

    # 插入新规则到第一条
    iptables -I INPUT 1 -i lo -j ACCEPT
    iptables -I FORWARD 1 -i lo -j ACCEPT

    save_iptables_rules
}

allow_ip() {
    local ips=("$@") # 将传入的参数转换为数组
    if [ ${#ips[@]} -eq 0 ]; then
        echo "请提供至少一个IP地址或IP段"
        return 1
    fi

    install iptables

    for ip in "${ips[@]}"; do
        # 删除已存在的阻止规则
        iptables -D INPUT -s "$ip" -j DROP 2>/dev/null

        # 添加允许规则
        if ! iptables -C INPUT -s "$ip" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT 1 -s "$ip" -j ACCEPT
            echo "已放行IP $ip"
        fi
    done

    save_iptables_rules
}

block_ip() {
    local ips=("$@") # 将传入的参数转换为数组
    if [ ${#ips[@]} -eq 0 ]; then
        echo "请提供至少一个IP地址或IP段"
        return 1
    fi

    install iptables

    for ip in "${ips[@]}"; do
        # 删除已存在的允许规则
        iptables -D INPUT -s "$ip" -j ACCEPT 2>/dev/null

        # 添加阻止规则
        if ! iptables -C INPUT -s "$ip" -j DROP 2>/dev/null; then
            iptables -I INPUT 1 -s "$ip" -j DROP
            echo "已阻止IP $ip"
        fi
    done

    save_iptables_rules
}

enable_ddos_defense() {
    # 开启防御 DDoS
    iptables -A DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A DOCKER-USER -p tcp --syn -j DROP
    iptables -A DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A DOCKER-USER -p udp -j DROP
    iptables -A INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT
    iptables -A INPUT -p tcp --syn -j DROP
    iptables -A INPUT -p udp -m limit --limit 3000/s -j ACCEPT
    iptables -A INPUT -p udp -j DROP
}

###### 关闭DDoS防御
disable_ddos_defense() {
    iptables -D DOCKER-USER -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p tcp --syn -j DROP 2>/dev/null
    iptables -D DOCKER-USER -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D DOCKER-USER -p udp -j DROP 2>/dev/null
    iptables -D INPUT -p tcp --syn -m limit --limit 500/s --limit-burst 100 -j ACCEPT 2>/dev/null
    iptables -D INPUT -p tcp --syn -j DROP 2>/dev/null
    iptables -D INPUT -p udp -m limit --limit 3000/s -j ACCEPT 2>/dev/null
    iptables -D INPUT -p udp -j DROP 2>/dev/null
}

###### 管理国家IP规则的函数
manage_country_rules() {
    local action="$1"
    shift # 去掉第一个参数，剩下的全是国家代码

    install ipset

    for country_code in "$@"; do
        local ipset_name="${country_code,,}_block"
        local download_url="http://www.ipdeny.com/ipblocks/data/countries/${country_code,,}.zone"

        case "$action" in
        block)
            if ! ipset list "$ipset_name" &>/dev/null; then
                ipset create "$ipset_name" hash:net
            fi

            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                echo "错误：下载 $country_code 的 IP 区域文件失败"
                return
            fi

            while IFS= read -r -r ip; do
                ipset add "$ipset_name" "$ip" 2>/dev/null
            done <"${country_code,,}.zone"

            iptables -I INPUT -m set --match-set "$ipset_name" src -j DROP

            echo "已成功阻止 $country_code 的 IP 地址"
            rm "${country_code,,}.zone"
            ;;

        allow)
            if ! ipset list "$ipset_name" &>/dev/null; then
                ipset create "$ipset_name" hash:net
            fi

            if ! wget -q "$download_url" -O "${country_code,,}.zone"; then
                echo "错误：下载 $country_code 的 IP 区域文件失败"
                return
            fi

            ipset flush "$ipset_name"
            while IFS= read -r -r ip; do
                ipset add "$ipset_name" "$ip" 2>/dev/null
            done <"${country_code,,}.zone"

            iptables -P INPUT DROP
            iptables -A INPUT -m set --match-set "$ipset_name" src -j ACCEPT

            echo "已成功允许 $country_code 的 IP 地址"
            rm "${country_code,,}.zone"
            ;;

        unblock)
            iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null

            if ipset list "$ipset_name" &>/dev/null; then
                ipset destroy "$ipset_name"
            fi

            echo "已成功解除 $country_code 的 IP 地址限制"
            ;;
        *)
            echo "用法: manage_country_rules {block|allow|unblock} <country_code...>"
            ;;
        esac
    done
}

iptables_panel() {
    root_use
    install iptables
    save_iptables_rules
    while true; do
        clear
        echo ""
        echo -e "${gl_zi}>>> 高级防火墙管理${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        iptables -L INPUT
        echo ""
        echo "防火墙管理"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}开放指定端口                 ${gl_bufan}2.  ${gl_bai}关闭指定端口"
        echo -e "${gl_bufan}3.  ${gl_bai}开放所有端口                 ${gl_bufan}4.  ${gl_bai}关闭所有端口"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}IP白名单                  	 ${gl_bufan}6.  ${gl_bai}IP黑名单"
        echo -e "${gl_bufan}7.  ${gl_bai}清除指定IP"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}允许PING                  	 ${gl_bufan}12. ${gl_bai}禁止PING"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}13. ${gl_bai}启动DDOS防御                 ${gl_bufan}14. ${gl_bai}关闭DDOS防御"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}15. ${gl_bai}阻止指定国家IP               ${gl_bufan}16. ${gl_bai}仅允许指定国家IP"
        echo -e "${gl_bufan}17. ${gl_bai}解除指定国家IP限制"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            read -r -e -p "请输入开放的端口号: " o_port
            open_port "$o_port"
            ;;
        2)
            read -r -e -p "请输入关闭的端口号: " c_port
            close_port "$c_port"
            ;;
        3)
            # 开放所有端口
            current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
            iptables -F
            iptables -X
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A FORWARD -i lo -j ACCEPT
            iptables -A INPUT -p tcp --dport "$current_port" -j ACCEPT
            iptables-save >/etc/iptables/rules.v4
            ;;
        4)
            # 关闭所有端口
            current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')
            iptables -F
            iptables -X
            iptables -P INPUT DROP
            iptables -P FORWARD DROP
            iptables -P OUTPUT ACCEPT
            iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
            iptables -A INPUT -i lo -j ACCEPT
            iptables -A FORWARD -i lo -j ACCEPT
            iptables -A INPUT -p tcp --dport "$current_port" -j ACCEPT
            iptables-save >/etc/iptables/rules.v4
            ;;
        5)
            # IP 白名单
            read -r -e -p "请输入放行的IP或IP段: " o_ip
            allow_ip "$o_ip"
            ;;
        6)
            # IP 黑名单
            read -r -e -p "请输入封锁的IP或IP段: " c_ip
            block_ip "$c_ip"
            ;;
        7)
            # 清除指定 IP
            read -r -e -p "请输入清除的IP: " d_ip
            iptables -D INPUT -s "$d_ip" -j ACCEPT 2>/dev/null
            iptables -D INPUT -s "$d_ip" -j DROP 2>/dev/null
            iptables-save >/etc/iptables/rules.v4
            ;;
        11)
            # 允许 PING
            iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT
            iptables -A OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT
            iptables-save >/etc/iptables/rules.v4
            ;;
        12)
            # 禁用 PING
            iptables -D INPUT -p icmp --icmp-type echo-request -j ACCEPT 2>/dev/null
            iptables -D OUTPUT -p icmp --icmp-type echo-reply -j ACCEPT 2>/dev/null
            iptables-save >/etc/iptables/rules.v4
            ;;
        13)
            enable_ddos_defense
            ;;
        14)
            disable_ddos_defense
            ;;
        15)
            read -r -e -p "请输入阻止的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code
            manage_country_rules block "$country_code"
            ;;
        16)
            read -r -e -p "请输入允许的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code
            manage_country_rules allow "$country_code"
            ;;
        17)
            read -r -e -p "请输入清除的国家代码（多个国家代码可用空格隔开如 CN US JP）: " country_code
            manage_country_rules unblock "$country_code"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

add_swap() {
    local new_swap=$1 # 获取传入的参数

    # 获取当前系统中所有的 swap 分区
    local swap_partitions=$(grep -E '^/dev/' /proc/swaps | awk '{print $1}')

    # 遍历并删除所有的 swap 分区
    for partition in $swap_partitions; do
        swapoff "$partition"
        wipefs -a "$partition"
        mkswap -f "$partition"
    done

    # 确保 /swapfile 不再被使用
    swapoff /swapfile

    # 删除旧的 /swapfile
    rm -f /swapfile

    # 创建新的 swap 分区
    fallocate -l "${new_swap}"M /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    sed -i '/\/swapfile/d' /etc/fstab
    echo "/swapfile swap swap defaults 0 0" >>/etc/fstab

    if [ -f /etc/alpine-release ]; then
        echo "nohup swapon /swapfile" >/etc/local.d/swap.start
        chmod +x /etc/local.d/swap.start
        rc-update add local
    fi

    echo -e "虚拟内存大小已调整为${gl_huang}${new_swap}${gl_bai}M"
}

check_swap() {

    local swap_total=$(free -m | awk 'NR==3{print $2}')

    # 判断是否需要创建虚拟内存
    [ "$swap_total" -gt 0 ] || add_swap 1024

}

ldnmp_v() {
    # ① Nginx 版本（本地）
    local nginx_version=$(nginx -v 2>&1 | grep -oP 'nginx/\K[0-9]+\.[0-9]+\.[0-9]+')
    echo -n -e "nginx : ${gl_huang}v$nginx_version${gl_bai}"

    # ② MySQL / MariaDB 版本（本地）
    local dbrootpasswd=$(grep -oP 'password=\K.*' /root/.my.cnf 2>/dev/null)
    local mysql_version=$(mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -e 'SELECT VERSION();' 2>/dev/null | tail -n 1)
    echo -n -e "            mysql : ${gl_huang}v$mysql_version${gl_bai}"

    # ③ PHP-FPM 版本（本地）
    local php_version=$(php -v 2>/dev/null | grep -oP 'PHP \K[0-9]+\.[0-9]+\.[0-9]+')
    echo -n -e "            php : ${gl_huang}v$php_version${gl_bai}"

    # ④ Redis 版本（本地）
    local redis_version=$(redis-server -v 2>&1 | grep -oP 'v=?\K[0-9]+\.[0-9]+')
    echo -e "            redis : ${gl_huang}v$redis_version${gl_bai}"

    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo ""
}

install_ldnmp_conf() {

    # 创建必要的目录和文件
    cd /home && mkdir -p web/html web/mysql web/certs web/conf.d web/stream.d web/redis web/log/nginx && touch web/docker-compose.yml
    wget -O /etc/nginx/nginx.conf ${gh_proxy}gitee.com/meimolihan/script/raw/master/nginx/nginx.conf
    # wget -O /etc/nginx/conf.d/default.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/default10.conf

    default_server_ssl

    # 下载 docker-compose.yml 文件并进行替换
    wget -O /etc/nginx/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml
    dbrootpasswd=$(openssl rand -base64 16)
    dbuse=$(openssl rand -hex 4)
    dbusepasswd=$(openssl rand -base64 8)

    # 在 docker-compose.yml 文件中进行替换
    sed -i "s#webroot#$dbrootpasswd#g" /etc/nginx/docker-compose.yml
    sed -i "s#kejilionYYDS#$dbusepasswd#g" /etc/nginx/docker-compose.yml
    sed -i "s#kejilion#$dbuse#g" /etc/nginx/docker-compose.yml

}

update_docker_compose_with_db_creds() {

    cp /etc/nginx/docker-compose.yml /etc/nginx/docker-compose1.yml

    if ! grep -q "stream" /etc/nginx/docker-compose.yml; then
        wget -O /etc/nginx/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/LNMP-docker-compose-10.yml

        dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /etc/nginx/docker-compose1.yml | tr -d '[:space:]')
        dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /etc/nginx/docker-compose1.yml | tr -d '[:space:]')
        dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /etc/nginx/docker-compose1.yml | tr -d '[:space:]')

        sed -i "s#webroot#$dbrootpasswd#g" /etc/nginx/docker-compose.yml
        sed -i "s#kejilionYYDS#$dbusepasswd#g" /etc/nginx/docker-compose.yml
        sed -i "s#kejilion#$dbuse#g" /etc/nginx/docker-compose.yml
    fi

    if grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose1.yml; then
        sed -i 's|kjlion/nginx:alpine|nginx:alpine|g' /etc/nginx/docker-compose.yml >/dev/null 2>&1
        sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /etc/nginx/docker-compose.yml >/dev/null 2>&1
    fi

}

auto_optimize_dns() {
    # 获取国家代码（如 CN、US 等）
    local country=$(curl -s ipinfo.io/country)

    # 根据国家设置 DNS
    if [ "$country" = "CN" ]; then
        local dns1_ipv4="223.5.5.5"
        local dns2_ipv4="183.60.83.19"
        local dns1_ipv6="2400:3200::1"
        local dns2_ipv6="2400:da00::6666"
    else
        local dns1_ipv4="1.1.1.1"
        local dns2_ipv4="8.8.8.8"
        local dns1_ipv6="2606:4700:4700::1111"
        local dns2_ipv6="2001:4860:4860::8888"
    fi

    # 调用设置 DNS 的函数（需你定义）
    set_dns "$dns1_ipv4" "$dns2_ipv4" "$dns1_ipv6" "$dns2_ipv6"
}

prefer_ipv4() {
    grep -q '^precedence ::ffff:0:0/96  100' /etc/gai.conf 2>/dev/null ||
        echo 'precedence ::ffff:0:0/96  100' >>/etc/gai.conf
    echo "已切换为 IPv4 优先"
}

install_ldnmp() {

    update_docker_compose_with_db_creds

    cd /etc/nginx && docker compose up -d
    sleep 1
    crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
    (
        crontab -l 2>/dev/null
        echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf'
    ) | crontab -

    fix_phpfpm_conf php
    fix_phpfpm_conf php74

    # mysql调优
    wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
    docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
    rm -rf /home/custom_mysql_config.cnf

    restart_ldnmp

    clear
    echo "LDNMP环境安装完毕"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    ldnmp_v
}

install_certbot() {

    cd ~
    curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/auto_cert_renewal.sh
    chmod +x auto_cert_renewal.sh

    check_crontab_installed
    local cron_job="0 0 * * * ~/auto_cert_renewal.sh"
    crontab -l 2>/dev/null | grep -vF "$cron_job" | crontab -
    (
        crontab -l 2>/dev/null
        echo "$cron_job"
    ) | crontab -
    echo "续签任务已更新"
}

install_ssltls() {
    docker stop nginx >/dev/null 2>&1
    check_port >/dev/null 2>&1
    cd ~

    # local file_path="/etc/letsencrypt/live/"$yuming"/fullchain.pem"
    local file_path="/etc/letsencrypt/live/${yuming}/fullchain.pem"
    if [ ! -f "$file_path" ]; then
        local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
        local ipv6_pattern='^(([0-9A-Fa-f]{1,4}:){1,7}:|([0-9A-Fa-f]{1,4}:){7,7}[0-9A-Fa-f]{1,4}|::1)$'
        # local ipv6_pattern='^([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}$'
        # local ipv6_pattern='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))))$'
        if [[ ("$yuming" =~ $ipv4_pattern || "$yuming" =~ $ipv6_pattern) ]]; then
            mkdir -p /etc/letsencrypt/live/"$yuming"/
            if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
                openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/letsencrypt/live/"$yuming"/privkey.pem -out /etc/letsencrypt/live/"$yuming"/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
            else
                openssl genpkey -algorithm Ed25519 -out /etc/letsencrypt/live/"$yuming"/privkey.pem
                openssl req -x509 -key /etc/letsencrypt/live/"$yuming"/privkey.pem -out /etc/letsencrypt/live/"$yuming"/fullchain.pem -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
            fi
        else
            docker run -it --rm -p 80:80 -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot certonly --standalone -d ""$yuming"" --email your@email.com --agree-tos --no-eff-email --force-renewal --key-type ecdsa
        fi
    fi
    mkdir -p /etc/nginx/keyfile/
    cp "/etc/letsencrypt/live/$yuming/fullchain.pem" "/etc/nginx/keyfile/${yuming}_cert.pem" >/dev/null 2>&1
    cp "/etc/letsencrypt/live/"$yuming"/privkey.pem" "/etc/nginx/keyfile/${yuming}_key.pem" >/dev/null 2>&1

    docker start nginx >/dev/null 2>&1
}

install_ssltls_text() {
    echo -e "${gl_huang}"$yuming" 公钥信息${gl_bai}"
    cat /etc/letsencrypt/live/"$yuming"/fullchain.pem
    echo ""
    echo -e "${gl_huang}"$yuming" 私钥信息${gl_bai}"
    cat /etc/letsencrypt/live/"$yuming"/privkey.pem
    echo ""
    echo -e "${gl_huang}证书存放路径${gl_bai}"
    echo "公钥: /etc/letsencrypt/live/"$yuming"/fullchain.pem"
    echo "私钥: /etc/letsencrypt/live/"$yuming"/privkey.pem"
    echo ""
}

add_ssl() {
    echo -e "${gl_huang}快速申请SSL证书，过期前自动续签${gl_bai}"
    yuming="${1:-}"
    if [ -z ""$yuming"" ]; then
        add_yuming
    fi
    install_docker
    install_certbot
    docker run -it --rm -v /etc/letsencrypt/:/etc/letsencrypt certbot/certbot delete --cert-name ""$yuming"" -n 2>/dev/null
    install_ssltls
    certs_status
    install_ssltls_text
    ssl_ps
}

ssl_ps() {
    echo -e "${gl_huang}已申请的证书到期情况${gl_bai}"
    echo "站点信息                      证书到期时间"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    for cert_dir in /etc/letsencrypt/live/*; do
        local cert_file="$cert_dir/fullchain.pem"
        if [ -f "$cert_file" ]; then
            local domain
            domain=$(basename "$cert_dir")
            local expire_date
            expire_date=$(openssl x509 -noout -enddate -in "$cert_file" | awk -F'=' '{print $2}')
            local formatted_date
            formatted_date=$(date -d "$expire_date" '+%Y-%m-%d')
            printf "%-30s%s\n" "$domain" "$formatted_date"
        fi
    done
    echo ""
}

default_server_ssl() {
    install openssl

    if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 -keyout /etc/nginx/keyfile/default_server.key -out /etc/nginx/keyfile/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
    else
        openssl genpkey -algorithm Ed25519 -out /etc/nginx/keyfile/default_server.key
        openssl req -x509 -key /etc/nginx/keyfile/default_server.key -out /etc/nginx/keyfile/default_server.crt -days 5475 -subj "/C=US/ST=State/L=City/O=Organization/OU=Organizational Unit/CN=Common Name"
    fi

    openssl rand -out /etc/nginx/keyfile/ticket12.key 48
    openssl rand -out /etc/nginx/keyfile/ticket13.key 80
}

certs_status() {

    sleep 1

    local file_path="/etc/letsencrypt/live/"$yuming"/fullchain.pem"
    if [ -f "$file_path" ]; then
        echo -e "${gl_hong}注意: ${gl_bai}证书申请失败，请检查以下可能原因并重试："
        echo -e "1. 域名拼写错误 ➠ 请检查域名输入是否正确"
        echo -e "2. DNS解析问题 ➠ 确认域名已正确解析到本服务器IP"
        echo -e "3. 网络配置问题 ➠ 如使用Cloudflare Warp等虚拟网络请暂时关闭"
        echo -e "4. 防火墙限制 ➠ 检查80/443端口是否开放，确保验证可访问"
        echo -e "5. 申请次数超限 ➠ Let's Encrypt有每周限额(5次/域名/周)"
        echo -e "6. 国内备案限制 ➠ 中国大陆环境请确认域名是否备案"
        break_end
        clear
        echo "请再次尝试部署 $webname"
        add_yuming
        install_ssltls
        certs_status
    fi
}

repeat_add_yuming() {
    if [ -e /etc/nginx/conf.d/"$yuming".conf ]; then
        web_del "${yuming}" >/dev/null 2>&1
    fi
}

add_yuming() {
    ip_address
    echo -e "先将域名解析到本机IP: ${gl_huang}$ipv4_address  $ipv6_address${gl_bai}"
    read -r -e -p "请输入你的IP或者解析过的域名: " yuming
}

add_db() {
    dbname=$(echo ""$yuming"" | sed -e 's/[^A-Za-z0-9]/_/g')
    dbname="${dbname}"

    dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
    dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
    dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
    docker exec mysql mysql -u root -p"$dbrootpasswd" -e "CREATE DATABASE $dbname; GRANT ALL PRIVILEGES ON $dbname.* TO \"$dbuse\"@\"%\";"
}

reverse_proxy() {
    ip_address
    wget -O /etc/nginx/conf.d/"$yuming".conf ${gh_proxy}gitee.com/meimolihan/script/raw/master/nginx/reverse-proxy.conf
    sed -i "s/yuming.com/"$yuming"/g" /etc/nginx/conf.d/"$yuming".conf
    sed -i "s/0.0.0.0/$ipv4_address/g" /etc/nginx/conf.d/"$yuming".conf
    sed -i "s|0000|$duankou|g" /etc/nginx/conf.d/"$yuming".conf
    nginx_http_on
    docker exec nginx nginx -s reload
}

restart_redis() {
    rm -rf /etc/nginx/redis/*
    docker exec redis redis-cli FLUSHALL >/dev/null 2>&1
    # docker exec -it redis redis-cli CONFIG SET maxmemory 1gb > /dev/null 2>&1
    # docker exec -it redis redis-cli CONFIG SET maxmemory-policy allkeys-lru > /dev/null 2>&1
}

restart_ldnmp() {
    restart_redis
    docker exec nginx chown -R nginx:nginx /var/www/html >/dev/null 2>&1
    docker exec nginx mkdir -p /var/cache/nginx/proxy >/dev/null 2>&1
    docker exec nginx mkdir -p /var/cache/nginx/fastcgi >/dev/null 2>&1
    docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy >/dev/null 2>&1
    docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi >/dev/null 2>&1
    docker exec php chown -R www-data:www-data /var/www/html >/dev/null 2>&1
    docker exec php74 chown -R www-data:www-data /var/www/html >/dev/null 2>&1
    cd /etc/nginx && docker compose restart nginx php php74

}

nginx_upgrade() {
    local ldnmp_pods="nginx"
    cd /etc/nginx/
    docker rm -f $ldnmp_pods >/dev/null 2>&1
    docker images --filter=reference="kjlion/${ldnmp_pods}*" -q | xargs docker rmi >/dev/null 2>&1
    docker images --filter=reference="${ldnmp_pods}*" -q | xargs docker rmi >/dev/null 2>&1
    docker compose up -d --force-recreate $ldnmp_pods
    crontab -l 2>/dev/null | grep -v 'logrotate' | crontab -
    (
        crontab -l 2>/dev/null
        echo '0 2 * * * docker exec nginx apk add logrotate && docker exec nginx logrotate -f /etc/logrotate.conf'
    ) | crontab -
    docker exec nginx chown -R nginx:nginx /var/www/html
    docker exec nginx mkdir -p /var/cache/nginx/proxy
    docker exec nginx mkdir -p /var/cache/nginx/fastcgi
    docker exec nginx chown -R nginx:nginx /var/cache/nginx/proxy
    docker exec nginx chown -R nginx:nginx /var/cache/nginx/fastcgi
    docker restart $ldnmp_pods >/dev/null 2>&1

    echo "更新${ldnmp_pods}完成"
}

phpmyadmin_upgrade() {
    local ldnmp_pods="phpmyadmin"
    local docker_port=8877
    local dbuse
    dbuse=$(grep -oP 'MYSQL_USER:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
    local dbusepasswd
    dbusepasswd=$(grep -oP 'MYSQL_PASSWORD:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
    cd /etc/nginx/
    docker rm -f $ldnmp_pods >/dev/null 2>&1
    docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi >/dev/null 2>&1
    curl -sS -O https://raw.githubusercontent.com/kejilion/docker/refs/heads/main/docker-compose.phpmyadmin.yml
    docker compose -f docker-compose.phpmyadmin.yml up -d
    clear
    ip_address

    check_docker_app_ip
    echo "登录信息: "
    echo "用户名: $dbuse"
    echo "密码: $dbusepasswd"
    echo
}

cf_purge_cache() {
    local CONFIG_FILE="/etc/nginx/config/cf-purge-cache.txt"
    local API_TOKEN
    local EMAIL
    local ZONE_IDS

    # 检查配置文件是否存在
    if [ -f "$CONFIG_FILE" ]; then
        # 从配置文件读取 API_TOKEN 和 zone_id
        # read -r API_TOKEN EMAIL ZONE_IDS <"$CONFIG_FILE"
        read -r -r API_TOKEN EMAIL ZONE_IDS <"$CONFIG_FILE"
        # 将 ZONE_IDS 转换为数组
        ZONE_IDS=($ZONE_IDS)
    else
        # 提示用户是否清理缓存
        read -r -e -p "$(echo -e "${gl_bai}需要清理 Cloudflare 的缓存吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" answer
        if [[ "$answer" == "y" ]]; then
            echo "CF信息保存在$CONFIG_FILE，可以后期修改CF信息"
            read -r -e -p "请输入你的 API_TOKEN: " API_TOKEN
            read -r -e -p "请输入你的CF用户名: " EMAIL
            read -r -e -p "请输入 zone_id（多个用空格分隔）: " -a ZONE_IDS

            mkdir -p /etc/nginx/config/
            echo "$API_TOKEN $EMAIL ${ZONE_IDS[*]}" >"$CONFIG_FILE"
        fi
    fi

    # 循环遍历每个 zone_id 并执行清除缓存命令
    for ZONE_ID in "${ZONE_IDS[@]}"; do
        echo "正在清除缓存 for zone_id: $ZONE_ID"
        curl -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/purge_cache" \
            -H "X-Auth-Email: $EMAIL" \
            -H "X-Auth-Key: $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data '{"purge_everything":true}'
    done
    echo "缓存清除请求已发送完毕。"
}

web_cache() {
    cf_purge_cache
    cd /etc/nginx && docker compose restart
    restart_redis
}

web_del() {
    yuming_list="${1:-}"
    if [ -z ""$yuming"_list" ]; then
        read -r -e -p "删除站点数据，请输入你的域名（多个域名用空格隔开）: " yuming_list
        if [[ -z ""$yuming"_list" ]]; then
            return
        fi
    fi

    for yuming in "$yuming"_list; do
        echo "正在删除域名: "$yuming""
        rm -r "/etc/nginx/html/"$yuming"" >/dev/null 2>&1
        rm "/etc/nginx/conf.d/"$yuming".conf" >/dev/null 2>&1
        rm "/etc/nginx/keyfile/${yuming}_key.pem" >/dev/null 2>&1
        rm "/etc/nginx/keyfile/${yuming}_cert.pem" >/dev/null 2>&1

        # 将域名转换为数据库名
        dbname=$(echo ""$yuming"" | sed -e 's/[^A-Za-z0-9]/_/g')
        dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')

        # 删除数据库前检查是否存在，避免报错
        echo "正在删除数据库: $dbname"
        docker exec mysql mysql -u root -p"$dbrootpasswd" -e "DROP DATABASE ${dbname};" >/dev/null 2>&1
    done

    docker exec nginx nginx -s reload
}

nginx_waf() {
    local mode=$1

    if ! grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        wget -O /etc/nginx/nginx.conf "${gh_proxy}gitee.com/meimolihan/script/raw/master/nginx/nginx.conf"
    fi

    # 根据 mode 参数来决定开启或关闭 WAF
    if [ "$mode" == "on" ]; then
        # 开启 WAF：去掉注释
        sed -i 's|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# modsecurity on;|\1modsecurity on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /etc/nginx/nginx.conf >/dev/null 2>&1
    elif [ "$mode" == "off" ]; then
        # 关闭 WAF：加上注释
        sed -i 's|^load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|# load_module /etc/nginx/modules/ngx_http_modsecurity_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)modsecurity on;|\1# modsecurity on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|\1# modsecurity_rules_file /etc/nginx/modsec/modsecurity.conf;|' /etc/nginx/nginx.conf >/dev/null 2>&1
    else
        echo "无效的参数：使用 'on' 或 'off'"
        return 1
    fi

    # 检查 nginx 镜像并根据情况处理
    if grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        docker exec nginx nginx -s reload
    else
        sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /etc/nginx/docker-compose.yml
        nginx_upgrade
    fi

}

check_waf_status() {
    if grep -q "^\s*#\s*modsecurity on;" /etc/nginx/nginx.conf; then
        waf_status=""
    elif grep -q "modsecurity on;" /etc/nginx/nginx.conf; then
        waf_status=" WAF已开启"
    else
        waf_status=""
    fi
}

check_cf_mode() {
    if [ -f "/etc/fail2ban/action.d/cloudflare-docker.conf" ]; then
        CFmessage=" cf模式已开启"
    else
        CFmessage=""
    fi
}

nginx_http_on() {
    local ipv4_pattern='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'
    local ipv6_pattern='^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|(2[0-4][0-9]|[01]?[0-9][0-9]?))))$'
    if [[ ("$yuming" =~ $ipv4_pattern || "$yuming" =~ $ipv6_pattern) ]]; then
        sed -i '/if (\$scheme = http) {/,/}/s/^/#/' /etc/nginx/conf.d/"${yuming}".conf
    fi
}

patch_wp_memory_limit() {
    local MEMORY_LIMIT="${1:-256M}"     # 第一个参数，默认256M
    local MAX_MEMORY_LIMIT="${2:-256M}" # 第二个参数，默认256M
    local TARGET_DIR="/etc/nginx/html"  # 路径写死

    find "$TARGET_DIR" -type f -name "wp-config.php" | while read -r -r FILE; do
        # 删除旧定义
        sed -i "/define(['\"]WP_MEMORY_LIMIT['\"].*/d" "$FILE"
        sed -i "/define(['\"]WP_MAX_MEMORY_LIMIT['\"].*/d" "$FILE"

        # 插入新定义，放在含 "Happy publishing" 的行前
        awk -v insert="define('WP_MEMORY_LIMIT', '$MEMORY_LIMIT');\ndefine('WP_MAX_MEMORY_LIMIT', '$MAX_MEMORY_LIMIT');" \
            '
	  /Happy publishing/ {
		print insert
	  }
	  { print }
	' "$FILE" >"$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"

        echo "[+] Replaced WP_MEMORY_LIMIT in $FILE"
    done
}

patch_wp_debug() {
    local DEBUG="${1:-false}"          # 第一个参数，默认false
    local DEBUG_DISPLAY="${2:-false}"  # 第二个参数，默认false
    local DEBUG_LOG="${3:-false}"      # 第三个参数，默认false
    local TARGET_DIR="/etc/nginx/html" # 路径写死

    find "$TARGET_DIR" -type f -name "wp-config.php" | while read -r -r FILE; do
        # 删除旧定义
        sed -i "/define(['\"]WP_DEBUG['\"].*/d" "$FILE"
        sed -i "/define(['\"]WP_DEBUG_DISPLAY['\"].*/d" "$FILE"
        sed -i "/define(['\"]WP_DEBUG_LOG['\"].*/d" "$FILE"

        # 插入新定义，放在含 "Happy publishing" 的行前
        awk -v insert="define('WP_DEBUG_DISPLAY', $DEBUG_DISPLAY);\ndefine('WP_DEBUG_LOG', $DEBUG_LOG);" \
            '
	  /Happy publishing/ {
		print insert
	  }
	  { print }
	' "$FILE" >"$FILE.tmp" && mv -f "$FILE.tmp" "$FILE"

        echo "[+] Replaced WP_DEBUG settings in $FILE"
    done
}

nginx_br() {

    local mode=$1

    if ! grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        # wget -O /etc/nginx/nginx.conf "${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/nginx10.conf"
        wget -O /etc/nginx/nginx.conf "https://gitee.com/meimolihan/script/raw/master/nginx/nginx.conf"
    fi

    if [ "$mode" == "on" ]; then
        # 开启 Brotli：去掉注释
        sed -i 's|# load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|# load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1

        sed -i 's|^\(\s*\)# brotli on;|\1brotli on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_static on;|\1brotli_static on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_comp_level \(.*\);|\1brotli_comp_level \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_buffers \(.*\);|\1brotli_buffers \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_min_length \(.*\);|\1brotli_min_length \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_window \(.*\);|\1brotli_window \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# brotli_types \(.*\);|\1brotli_types \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i '/brotli_types/,+6 s/^\(\s*\)#\s*/\1/' /etc/nginx/nginx.conf

    elif [ "$mode" == "off" ]; then
        # 关闭 Brotli：加上注释
        sed -i 's|^load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|# load_module /etc/nginx/modules/ngx_http_brotli_filter_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|# load_module /etc/nginx/modules/ngx_http_brotli_static_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1

        sed -i 's|^\(\s*\)brotli on;|\1# brotli on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_static on;|\1# brotli_static on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_comp_level \(.*\);|\1# brotli_comp_level \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_buffers \(.*\);|\1# brotli_buffers \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_min_length \(.*\);|\1# brotli_min_length \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_window \(.*\);|\1# brotli_window \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)brotli_types \(.*\);|\1# brotli_types \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i '/brotli_types/,+6 {
			/^[[:space:]]*[^#[:space:]]/ s/^\(\s*\)/\1# /
		}' /etc/nginx/nginx.conf

    else
        echo "无效的参数：使用 'on' 或 'off'"
        return 1
    fi

    # 检查 nginx 镜像并根据情况处理
    if grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        docker exec nginx nginx -s reload
    else
        sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /etc/nginx/docker-compose.yml
        nginx_upgrade
    fi
}

nginx_zstd() {

    local mode=$1

    if ! grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        wget -O /etc/nginx/nginx.conf "${gh_proxy}gitee.com/meimolihan/script/raw/master/nginx/nginx.conf"
    fi

    if [ "$mode" == "on" ]; then
        # 开启 Zstd：去掉注释
        sed -i 's|# load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|# load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1

        sed -i 's|^\(\s*\)# zstd on;|\1zstd on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# zstd_static on;|\1zstd_static on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# zstd_comp_level \(.*\);|\1zstd_comp_level \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# zstd_buffers \(.*\);|\1zstd_buffers \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# zstd_min_length \(.*\);|\1zstd_min_length \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)# zstd_types \(.*\);|\1zstd_types \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i '/zstd_types/,+6 s/^\(\s*\)#\s*/\1/' /etc/nginx/nginx.conf

    elif [ "$mode" == "off" ]; then
        # 关闭 Zstd：加上注释
        sed -i 's|^load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|# load_module /etc/nginx/modules/ngx_http_zstd_filter_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|# load_module /etc/nginx/modules/ngx_http_zstd_static_module.so;|' /etc/nginx/nginx.conf >/dev/null 2>&1

        sed -i 's|^\(\s*\)zstd on;|\1# zstd on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)zstd_static on;|\1# zstd_static on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)zstd_comp_level \(.*\);|\1# zstd_comp_level \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)zstd_buffers \(.*\);|\1# zstd_buffers \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)zstd_min_length \(.*\);|\1# zstd_min_length \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i 's|^\(\s*\)zstd_types \(.*\);|\1# zstd_types \2;|' /etc/nginx/nginx.conf >/dev/null 2>&1
        sed -i '/zstd_types/,+6 {
			/^[[:space:]]*[^#[:space:]]/ s/^\(\s*\)/\1# /
		}' /etc/nginx/nginx.conf

    else
        echo "无效的参数：使用 'on' 或 'off'"
        return 1
    fi

    # 检查 nginx 镜像并根据情况处理
    if grep -q "kjlion/nginx:alpine" /etc/nginx/docker-compose.yml; then
        docker exec nginx nginx -s reload
    else
        sed -i 's|nginx:alpine|kjlion/nginx:alpine|g' /etc/nginx/docker-compose.yml
        nginx_upgrade
    fi
}

nginx_gzip() {

    local mode=$1
    if [ "$mode" == "on" ]; then
        sed -i 's|^\(\s*\)# gzip on;|\1gzip on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
    elif [ "$mode" == "off" ]; then
        sed -i 's|^\(\s*\)gzip on;|\1# gzip on;|' /etc/nginx/nginx.conf >/dev/null 2>&1
    else
        echo "无效的参数：使用 'on' 或 'off'"
        return 1
    fi

    docker exec nginx nginx -s reload
}

web_security() {
    while true; do
        check_f2b_status
        check_waf_status
        check_cf_mode
        f2b_autostart
        clear
        echo -e "${gl_zi}>>> 服务器网站防御${gl_bai}"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "服务器网站防御程序：${check_f2b_status}${gl_lv}${CFmessage}${waf_status}${gl_bai}"
        fb_ver=$(fail2ban-client version 2>/dev/null || echo -e "${gl_hui}未安装")
        echo -e "${gl_bai}网站防御程序版本号：${gl_lv}${fb_ver}"
        boot_en=$(systemctl is-enabled fail2ban 2>/dev/null)
        case "$boot_en" in
        enabled) boot_zh="${gl_lv}已开启" ;;
        disabled) boot_zh="${gl_hui}已禁用" ;;
        *) boot_zh="${gl_hui}未知" ;;
        esac
        echo -e "${gl_bai}网站防御程序自启动：${boot_zh}"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装防御程序        ${gl_bufan}2. ${gl_bai}检查服务状态"
        echo -e "${gl_bufan}3. ${gl_bai}重启防御程序        ${gl_bufan}4. ${gl_bai}检查配置语法"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}5. ${gl_bai}查看SSH拦截记录     ${gl_bufan}6. ${gl_bai}查看网站拦截记录"
        echo -e "${gl_bufan}7. ${gl_bai}查看防御规则列表    ${gl_bufan}8. ${gl_bai}查看日志实时监控"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}配置黑名单         ${gl_bufan}12. ${gl_bai}清除所有拉黑的IP"
        echo -e "${gl_bufan}13. ${gl_bai}手动永久封禁       ${gl_bufan}14. ${gl_bai}手动解除封禁"
        echo -e "${gl_bufan}15. ${gl_bai}被封禁的 IP 列表   ${gl_bufan}16. ${gl_bai}查看剩余封禁时间"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}17. ${gl_bai}配置白名单         ${gl_bufan}18. ${gl_bai}查看所有监狱的白名单"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}cloudflare模式     ${gl_bufan}22. ${gl_bai}高负载开启5秒盾"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}31. ${gl_bai}开启WAF            ${gl_bufan}32. ${gl_bai}关闭WAF"
        echo -e "${gl_bufan}33. ${gl_bai}开启DDOS防御       ${gl_bufan}34. ${gl_bai}关闭DDOS防御"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}99. ${gl_bai}卸载防御程序"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            # 安装防御程序
            clear
            echo -e "${gl_zi}>>> 安装防御程序${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            f2b_install_sshd
            echo -e ""
            log_info 下载依赖文件
            echo -e "${gl_bufan}------------------------${gl_bai}"
            cd /etc/fail2ban/filter.d
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/fail2ban-nginx-cc.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-418.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-403.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-deny.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-unauthorized.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-bad-request.conf
            wget https://gitee.com/meimolihan/sh/raw/master/f2b/filter.d/nginx-pve.conf

            mkdir -p /var/log/nginx && touch /var/log/nginx/access.log /var/log/nginx/error.log
            mkdir -p /etc/nginx && touch /etc/nginx/nginx.conf

            cd /etc/fail2ban/jail.d/
            curl -sS -O https://gitee.com/meimolihan/sh/raw/master/f2b/jail.d/nginx-cc.conf
            sed -i "/cloudflare/d" /etc/fail2ban/jail.d/nginx-cc.conf

            f2b_status
            f2b_autostart
            echo -e ""
            log_info fail2ban 服务状态
            echo -e "${gl_bufan}------------------------${gl_bai}"
            fail2ban-client -t && systemctl restart fail2ban && systemctl status fail2ban
            echo -e "${gl_bufan}------------------------${gl_bai}"
            break_end
            ;;
        2)
            # 查看防御程序服务状态
            systemctl status fail2ban
            break_end
            ;;
        3)
            #  重启防御程序
            fail2ban-client -t && systemctl restart fail2ban
            break_end
            ;;
        4)
            # 检查语法
            fail2ban-client -t
            break_end
            ;;
        5)
            # 查看SSH拦截记录
            echo -e "${gl_bufan}------------------------${gl_bai}"
            f2b_sshd
            echo -e "${gl_bufan}------------------------${gl_bai}"
            break_end
            ;;
	6)
		# 查看网站拦截记录
		clear
		local jails=(
			fail2ban-nginx-cc
			nginx-418
			nginx-bad-request
			nginx-badbots
			nginx-botsearch
			nginx-deny
			nginx-http-auth
			nginx-unauthorized
			php-url-fopen
			nginx-pve
			nginx-403
		)

		for jail in "${jails[@]}"; do
			echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
			fail2ban-client status "$jail"
		done
		echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
		break_end
		;;
        7)
            # 查看防御规则列表 
            fail2ban-client status
            break_end
            ;;
        8)
            # 查看日志实时监控
            tail -f /var/log/fail2ban.log
            ;;
        11)
            # 配置黑名单
            install nano
            nano /etc/fail2ban/jail.d/nginx-cc.conf
            f2b_status
            web_security
            ;;
        12)
            # 清除所有拉黑的IP
            read -r -e -p "$(echo -e "${gl_bai}确定清空所有封禁？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" sure
            [[ $sure == y ]] && fail2ban-client set recidive unban --all
            ;;
        13)
            # 手动永久封禁
            read -r -e -p "请输入要批量封禁的 IP（空格分隔）: " ips
            fail2ban-client set recidive banip $ips
            fail2ban-client -t && systemctl restart fail2ban # 验证封禁
            break_end
            ;;
        14)
            # 手动解除封禁
            read -r -e -p "请输入要永久解封的 IP: " ip
            # 1. 先清掉“累犯”记录，防止它立刻再次封
            fail2ban-client set recidive unbanip "$ip"
            # 2. 再一次性解封所有普通 jail
            fail2ban-client unban "$ip"
            fail2ban-client -t && systemctl restart fail2ban # 验证封禁
            break_end
            ;;
        15)
            # 被封禁的 IP 列表
            fail2ban-client status recidive # 验证封禁
            break_end
            ;;
        16)
            # 查看剩余封禁时间
            read -r -e -p "请输入要查询的 IP: " ip
            if ! fail2ban-client status recidive | grep -qw "$ip"; then
                echo "IP $ip 未被 recidive 监狱关押"
            else
                remain=$(fail2ban-client get recidive bantime "$ip" 2>/dev/null)
                case "$remain" in
                -1) echo "IP $ip 已被永久封禁" ;;
                0) echo "IP $ip 关押中，剩余时间：< 1 秒" ;;
                *) printf "IP %s 剩余封禁时间：%s 秒（约 %d 小时）\n" \
                    "$ip" "$remain" $((remain / 3600)) ;;
                esac
            fi
            break_end
            ;;
        17)
            # 配置白名单
            install nano
            nano /etc/fail2ban/jail.d/nginx-cc.conf
            f2b_status
            web_security
            ;;
        18)
            # 查看所有监狱的白名单
            clear
            for j in $(fail2ban-client status | awk -F: '/Jail list/ {gsub(/,/,""); print $2}'); do
                echo "=== $j ==="
                sudo fail2ban-client get "$j" ignoreip
            done
            break_end
            ;;
        21)
            echo "到cf后台右上角我的个人资料，选择左侧API令牌，获取Global API Key"
            echo "https://dash.cloudflare.com/login"
            read -r -e -p "输入CF的账号: " cfuser
            read -r -e -p "输入CF的Global API Key: " cftoken

            wget -O /etc/nginx/conf.d/default.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/default11.conf
            docker exec nginx nginx -s reload

            cd /etc/fail2ban/jail.d/
            curl -sS -O https://gitee.com/meimolihan/fail2ban/raw/master/nginx-docker-cc.conf

            cd /etc/fail2ban/action.d
            curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/config/main/fail2ban/cloudflare-docker.conf

            sed -i "s/kejilion@outlook.com/$cfuser/g" /etc/fail2ban/action.d/cloudflare-docker.conf
            sed -i "s/APIKEY00000/$cftoken/g" /etc/fail2ban/action.d/cloudflare-docker.conf
            f2b_status

            echo "已配置cloudflare模式，可在cf后台，站点-安全性-事件中查看拦截记录"
            ;;
        22)
            echo -e "${gl_huang}网站每5分钟自动检测，当达检测到高负载会自动开盾，低负载也会自动关闭5秒盾。${gl_bai}"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "获取CF参数: "
            echo -e "到cf后台右上角我的个人资料，选择左侧API令牌，获取${gl_huang}Global API Key${gl_bai}"
            echo -e "到cf后台域名概要页面右下方获取${gl_huang}区域ID${gl_bai}"
            echo "https://dash.cloudflare.com/login"
            echo -e "${gl_huang}------------------------${gl_bai}"
            read -r -e -p "输入CF的账号: " cfuser
            read -r -e -p "输入CF的Global API Key: " cftoken
            read -r -e -p "输入CF中域名的区域ID: " cfzonID

            cd ~
            install jq bc
            check_crontab_installed
            curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/CF-Under-Attack.sh
            chmod +x CF-Under-Attack.sh
            sed -i "s/AAAA/$cfuser/g" ~/CF-Under-Attack.sh
            sed -i "s/BBBB/$cftoken/g" ~/CF-Under-Attack.sh
            sed -i "s/CCCC/$cfzonID/g" ~/CF-Under-Attack.sh

            local cron_job="*/5 * * * * ~/CF-Under-Attack.sh"

            local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

            if [ -z "$existing_cron" ]; then
                (
                    crontab -l 2>/dev/null
                    echo "$cron_job"
                ) | crontab -
                echo "高负载自动开盾脚本已添加"
            else
                echo "自动开盾脚本已存在，无需添加"
            fi
            ;;
        31)
            nginx_waf on
            echo "站点WAF已开启"
            ;;
        32)
            nginx_waf off
            echo "站点WAF已关闭"
            ;;
        33)
            enable_ddos_defense
            ;;
        34)
            disable_ddos_defense
            ;;
        99)
            remove fail2ban
            rm -rf /etc/fail2ban
            crontab -l | grep -v "CF-Under-Attack.sh" | crontab - 2>/dev/null
            echo "Fail2Ban防御程序已卸载"
            break
            ;;
        0)
            break
            ;;
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

check_nginx_mode() {

    CONFIG_FILE="/etc/nginx/nginx.conf"

    # 获取当前的 worker_processes 设置值
    current_value=$(grep -E '^\s*worker_processes\s+[0-9]+;' "$CONFIG_FILE" | awk '{print $2}' | tr -d ';')

    # 根据值设置模式信息
    if [ "$current_value" = "8" ]; then
        mode_info=" 高性能模式"
    else
        mode_info=" 标准模式"
    fi
}

check_nginx_compression() {

    CONFIG_FILE="/etc/nginx/nginx.conf"

    # 检查 zstd 是否开启且未被注释（整行以 zstd on; 开头）
    if grep -qE '^\s*zstd\s+on;' "$CONFIG_FILE"; then
        zstd_status=" zstd压缩已开启"
    else
        zstd_status=""
    fi

    # 检查 brotli 是否开启且未被注释
    if grep -qE '^\s*brotli\s+on;' "$CONFIG_FILE"; then
        br_status=" br压缩已开启"
    else
        br_status=""
    fi

    # 检查 gzip 是否开启且未被注释
    if grep -qE '^\s*gzip\s+on;' "$CONFIG_FILE"; then
        gzip_status=" gzip压缩已开启"
    else
        gzip_status=""
    fi
}

web_optimization() {
    while true; do
        check_nginx_mode
        check_nginx_compression
        clear
        echo -e "${gl_zi}>>> 优化LDNMP环境${gl_lv}${mode_info}${gzip_status}${br_status}${zstd_status}${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}标准模式              ${gl_bufan}2. ${gl_bai}高性能模式 (推荐2H4G以上)"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}3. ${gl_bai}开启gzip压缩          ${gl_bufan}4. ${gl_bai}关闭gzip压缩"
        echo -e "${gl_bufan}5. ${gl_bai}开启br压缩            ${gl_bufan}6. ${gl_bai}关闭br压缩"
        echo -e "${gl_bufan}7. ${gl_bai}开启zstd压缩          ${gl_bufan}8. ${gl_bai}关闭zstd压缩"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            local cpu_cores
            cpu_cores=$(nproc)
            local connections=$((1024 * ${cpu_cores}))
            sed -i "s/worker_processes.*/worker_processes ${cpu_cores};/" /etc/nginx/nginx.conf
            sed -i "s/worker_connections.*/worker_connections ${connections};/" /etc/nginx/nginx.conf

            # php调优
            wget -O /home/optimized_php.ini ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
            docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
            docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
            rm -rf /home/optimized_php.ini

            # php调优
            wget -O /home/www.conf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/www-1.conf
            docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
            docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
            rm -rf /home/www.conf

            patch_wp_memory_limit
            # patch_wp_debug
            patch_wp_debug "$some_value"

            fix_phpfpm_conf php
            fix_phpfpm_conf php74

            # mysql调优
            wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config-1.cnf
            docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
            rm -rf /home/custom_mysql_config.cnf

            cd /etc/nginx && docker compose restart

            restart_redis
            optimize_balanced

            echo "LDNMP环境已设置成 标准模式"
            ;;
        2)
            # nginx调优
            local cpu_cores
            cpu_cores=$(nproc)
            local connections=$((2048 * ${cpu_cores}))
            sed -i "s/worker_processes.*/worker_processes ${cpu_cores};/" /etc/nginx/nginx.conf
            sed -i "s/worker_connections.*/worker_connections ${connections};/" /etc/nginx/nginx.conf

            # php调优
            wget -O /home/optimized_php.ini ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/optimized_php.ini
            docker cp /home/optimized_php.ini php:/usr/local/etc/php/conf.d/optimized_php.ini
            docker cp /home/optimized_php.ini php74:/usr/local/etc/php/conf.d/optimized_php.ini
            rm -rf /home/optimized_php.ini

            # php调优
            wget -O /home/www.conf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/www.conf
            docker cp /home/www.conf php:/usr/local/etc/php-fpm.d/www.conf
            docker cp /home/www.conf php74:/usr/local/etc/php-fpm.d/www.conf
            rm -rf /home/www.conf

            patch_wp_memory_limit 512M 512M
            # patch_wp_debug
            patch_wp_debug "$some_value"

            fix_phpfpm_conf php
            fix_phpfpm_conf php74

            # mysql调优
            wget -O /home/custom_mysql_config.cnf ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/custom_mysql_config.cnf
            docker cp /home/custom_mysql_config.cnf mysql:/etc/mysql/conf.d/
            rm -rf /home/custom_mysql_config.cnf

            cd /etc/nginx && docker compose restart

            restart_redis
            optimize_web_server

            echo "LDNMP环境已设置成 高性能模式"
            ;;
        3)
            nginx_gzip on
            ;;
        4)
            nginx_gzip off
            ;;
        5)
            nginx_br on
            ;;
        6)
            nginx_br off
            ;;
        7)
            nginx_zstd on
            ;;
        8)
            nginx_zstd off
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

check_docker_app() {
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
        check_docker="${gl_lv}已安装${gl_bai}"
    else
        check_docker="${gl_hui}未安装${gl_bai}"
    fi
}

check_docker_app_ip() {
    echo -e ""
    echo -e "${gl_bai}访问地址:${gl_lv}" 
    ip_address

    if [ -n "$ipv4_address" ]; then
        echo "http://$ipv4_address:${docker_port}"
    fi

    if [ -n "$ipv6_address" ]; then
        echo "http://[$ipv6_address]:${docker_port}"
    fi

    local search_pattern1="$ipv4_address:${docker_port}"
    local search_pattern2="127.0.0.1:${docker_port}"

    for file in /etc/nginx/conf.d/*; do
        if [ -f "$file" ]; then
            if grep -q "$search_pattern1" "$file" 2>/dev/null || grep -q "$search_pattern2" "$file" 2>/dev/null; then
                echo "https://$(basename "$file" | sed 's/\.conf$//')"
            fi
        fi
    done
}

check_docker_image_update() {
    local container_name=$1
    local country=$(curl -s ipinfo.io/country)
    if [[ "$country" == "CN" ]]; then
        update_status=""
        return
    fi

    # 获取容器的创建时间和镜像名称
    local container_info
    container_info=$(docker inspect --format='{{.Created}},{{.Config.Image}}' "$container_name" 2>/dev/null)
    local container_created
    container_created=$(echo "$container_info" | cut -d',' -f1)
    local image_name
    image_name=$(echo "$container_info" | cut -d',' -f2)

    # 提取镜像仓库和标签
    local image_repo=${image_name%%:*}
    local image_tag=${image_name##*:}

    # 默认标签为 latest
    [[ "$image_repo" == "$image_tag" ]] && image_tag="latest"

    # 添加对官方镜像的支持
    [[ "$image_repo" != */* ]] && image_repo="library/$image_repo"

    # 从 Docker Hub API 获取镜像发布时间
    local hub_info last_updated
    hub_info=$(curl -s "https://hub.docker.com/v2/repositories/$image_repo/tags/$image_tag")
    last_updated=$(echo "$hub_info" | jq -r '.last_updated' 2>/dev/null)

    # 验证获取的时间
    if [[ -n "$last_updated" && "$last_updated" != "null" ]]; then
        local container_created_ts last_updated_ts
        container_created_ts=$(date -d "$container_created" +%s 2>/dev/null)
        last_updated_ts=$(date -d "$last_updated" +%s 2>/dev/null)

        # 比较时间戳
        if [[ $container_created_ts -lt $last_updated_ts ]]; then
            update_status="${gl_huang}发现新版本!${gl_bai}"
        else
            update_status=""
        fi
    else
        update_status=""
    fi

}

block_container_port() {
    local container_name_or_id=$1
    local allowed_ip=$2

    # 获取容器的 IP 地址
    local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

    if [ -z "$container_ip" ]; then
        return 1
    fi

    install iptables

    # 检查并封禁其他所有 IP
    if ! iptables -C DOCKER-USER -p tcp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -d "$container_ip" -j DROP
    fi

    # 检查并放行指定 IP
    if ! iptables -C DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi

    # 检查并放行本地网络 127.0.0.0/8
    if ! iptables -C DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    # 检查并封禁其他所有 IP
    if ! iptables -C DOCKER-USER -p udp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -I DOCKER-USER -p udp -d "$container_ip" -j DROP
    fi

    # 检查并放行指定 IP
    if ! iptables -C DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi

    # 检查并放行本地网络 127.0.0.0/8
    if ! iptables -C DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    if ! iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -I DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
    fi

    echo "已阻止IP+端口访问该服务"
    save_iptables_rules
}

clear_container_rules() {
    local container_name_or_id=$1
    local allowed_ip=$2

    # 获取容器的 IP 地址
    local container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container_name_or_id")

    if [ -z "$container_ip" ]; then
        return 1
    fi

    install iptables

    # 清除封禁其他所有 IP 的规则
    if iptables -C DOCKER-USER -p tcp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -D DOCKER-USER -p tcp -d "$container_ip" -j DROP
    fi

    # 清除放行指定 IP 的规则
    if iptables -C DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -D DOCKER-USER -p tcp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi

    # 清除放行本地网络 127.0.0.0/8 的规则
    if iptables -C DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -D DOCKER-USER -p tcp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    # 清除封禁其他所有 IP 的规则
    if iptables -C DOCKER-USER -p udp -d "$container_ip" -j DROP &>/dev/null; then
        iptables -D DOCKER-USER -p udp -d "$container_ip" -j DROP
    fi

    # 清除放行指定 IP 的规则
    if iptables -C DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -D DOCKER-USER -p udp -s "$allowed_ip" -d "$container_ip" -j ACCEPT
    fi

    # 清除放行本地网络 127.0.0.0/8 的规则
    if iptables -C DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -D DOCKER-USER -p udp -s 127.0.0.0/8 -d "$container_ip" -j ACCEPT
    fi

    if iptables -C DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT &>/dev/null; then
        iptables -D DOCKER-USER -m state --state ESTABLISHED,RELATED -d "$container_ip" -j ACCEPT
    fi

    echo "已允许IP+端口访问该服务"
    save_iptables_rules
}

block_host_port() {
    local port=$1
    local allowed_ip=$2

    if [[ -z "$port" || -z "$allowed_ip" ]]; then
        echo "错误：请提供端口号和允许访问的 IP。"
        echo "用法: block_host_port <端口号> <允许的IP>"
        return 1
    fi

    install iptables

    # 拒绝其他所有 IP 访问
    if ! iptables -C INPUT -p tcp --dport "$port" -j DROP &>/dev/null; then
        iptables -I INPUT -p tcp --dport "$port" -j DROP
    fi

    # 允许指定 IP 访问
    if ! iptables -C INPUT -p tcp --dport ""$port"" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p tcp --dport ""$port"" -s "$allowed_ip" -j ACCEPT
    fi

    # 允许本机访问
    if ! iptables -C INPUT -p tcp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p tcp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT
    fi

    # 拒绝其他所有 IP 访问
    if ! iptables -C INPUT -p udp --dport ""$port"" -j DROP &>/dev/null; then
        iptables -I INPUT -p udp --dport ""$port"" -j DROP
    fi

    # 允许指定 IP 访问
    if ! iptables -C INPUT -p udp --dport ""$port"" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p udp --dport ""$port"" -s "$allowed_ip" -j ACCEPT
    fi

    # 允许本机访问
    if ! iptables -C INPUT -p udp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -I INPUT -p udp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT
    fi

    # 允许已建立和相关连接的流量
    if ! iptables -C INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT &>/dev/null; then
        iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    fi

    echo "已阻止IP+端口访问该服务"
    save_iptables_rules
}

clear_host_port_rules() {
    local port=$1
    local allowed_ip=$2

    if [[ -z "$port" || -z "$allowed_ip" ]]; then
        echo "错误：请提供端口号和允许访问的 IP。"
        echo "用法: clear_host_port_rules <端口号> <允许的IP>"
        return 1
    fi

    install iptables

    # 清除封禁所有其他 IP 访问的规则
    if iptables -C INPUT -p tcp --dport ""$port"" -j DROP &>/dev/null; then
        iptables -D INPUT -p tcp --dport ""$port"" -j DROP
    fi

    # 清除允许本机访问的规则
    if iptables -C INPUT -p tcp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -D INPUT -p tcp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT
    fi

    # 清除允许指定 IP 访问的规则
    if iptables -C INPUT -p tcp --dport ""$port"" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -D INPUT -p tcp --dport ""$port"" -s "$allowed_ip" -j ACCEPT
    fi

    # 清除封禁所有其他 IP 访问的规则
    if iptables -C INPUT -p udp --dport ""$port"" -j DROP &>/dev/null; then
        iptables -D INPUT -p udp --dport ""$port"" -j DROP
    fi

    # 清除允许本机访问的规则
    if iptables -C INPUT -p udp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT &>/dev/null; then
        iptables -D INPUT -p udp --dport ""$port"" -s 127.0.0.0/8 -j ACCEPT
    fi

    # 清除允许指定 IP 访问的规则
    if iptables -C INPUT -p udp --dport ""$port"" -s "$allowed_ip" -j ACCEPT &>/dev/null; then
        iptables -D INPUT -p udp --dport ""$port"" -s "$allowed_ip" -j ACCEPT
    fi

    echo "已允许IP+端口访问该服务"
    save_iptables_rules

}

setup_docker_dir() {

    mkdir -p /home /home/docker 2>/dev/null

    if [ -d "/vol1/1000/" ] && [ ! -d "/vol1/1000/docker" ]; then
        cp -f /home/docker /home/docker1 2>/dev/null
        rm -rf /home/docker 2>/dev/null
        mkdir -p /vol1/1000/docker 2>/dev/null
        ln -s /vol1/1000/docker /home/docker 2>/dev/null
    fi

    if [ -d "/volume1/" ] && [ ! -d "/volume1/docker" ]; then
        cp -f /home/docker /home/docker1 2>/dev/null
        rm -rf /home/docker 2>/dev/null
        mkdir -p /volume1/docker 2>/dev/null
        ln -s /volume1/docker /home/docker 2>/dev/null
    fi

}

add_app_id() {
    mkdir -p /home/docker
    touch /home/docker/appno.txt
    grep -qxF "${app_id}" /home/docker/appno.txt || echo "${app_id}" >>/home/docker/appno.txt

}

docker_app() {
    while true; do
	clear
	check_docker_app
	check_docker_image_update $docker_name
	echo -e "$docker_name $check_docker $update_status"
	echo -e "$docker_describe"
	echo -e "$docker_url"
	echo -e "容器状态：$(
	docker inspect -f \
	'{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
	"$docker_name" 2>/dev/null || printf "${gl_hui}容器 ${gl_huang}%s${gl_hui} 不存在${gl_bai}" "$docker_name"
	)"

        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
	if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
		if [ ! -f "/home/docker/${docker_name}_port.conf" ]; then
			local docker_port=$(docker port "$docker_name" | head -n1 | awk -F'[:]' '/->/ {print $NF; exit}')
			docker_port=${docker_port:-0000}
			echo "$docker_port" > "/home/docker/${docker_name}_port.conf"
		fi
		local docker_port=$(cat "/home/docker/${docker_name}_port.conf")
		check_docker_app_ip
	fi
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}安装             ${gl_bufan}2.  ${gl_bai}更新"
        echo -e "${gl_bufan}3.  ${gl_bai}卸载             ${gl_bufan}4.  ${gl_bai}日志"
        echo -e "${gl_bufan}5.  ${gl_bai}停止容器         ${gl_bufan}6.  ${gl_bai}重启容器"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}添加域名访问     ${gl_bufan}12. ${gl_bai}删除域名访问"
        echo -e "${gl_bufan}13. ${gl_bai}允许IP+端口访问  ${gl_bufan}14. ${gl_bai}阻止IP+端口访问"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)
            setup_docker_dir
            check_disk_space $app_size /home/docker
            read -r -e -p "输入应用对外服务端口，回车默认使用${docker_port}端口: " app_port
            local app_port=${app_port:-${docker_port}}
            local docker_port=$app_port

            install jq
            install_docker
            docker_rum
            echo "$docker_port" >"/home/docker/${docker_name}_port.conf"
            add_app_id
            clear
            echo ""$docker_name" 已经安装完成"
            check_docker_app_ip
            echo ""
            $docker_use
            $docker_passwd
            ;;
        2)
            docker rm -f "$docker_name"
            docker rmi -f "$docker_img"
            docker_rum
            add_app_id
            clear
            echo ""$docker_name" 已经安装完成"
            check_docker_app_ip
            echo ""
            $docker_use
            $docker_passwd
            ;;
        3)
            docker rm -f "$docker_name"
            docker rmi -f "$docker_img"
            rm -rf "/home/docker/"$docker_name""
            rm -f /home/docker/${docker_name}_port.conf

            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            echo "应用已卸载"
            ;;
        4)
            docker logs "$docker_name"
            break_end
            ;;
        5)
            # 停止容器
            docker stop "$docker_name"
            break_end
            ;;
        6)
            # 重启容器
            docker restart "$docker_name"
            break_end
            ;;
        11)
            echo "${docker_name}域名访问设置"
            add_yuming
            ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
            block_container_port "$docker_name" "$ipv4_address"
            ;;
        12)
            echo "域名格式 example.com 不带https://"
            web_del
            ;;
        13)
            clear_container_rules "$docker_name" "$ipv4_address"
            ;;
        14)
            block_container_port "$docker_name" "$ipv4_address"
            ;;
        0) linux_panel ;;
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
	*)
	break
	;;
    esac
    break_end
done
}

docker_app_plus() {
    while true; do
        clear
        check_docker_app
        check_docker_image_update "$docker_name"
        echo -e "$app_name $check_docker $update_status"
        echo "$app_text"
        echo "$app_url"
        if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
            if [ ! -f "/home/docker/${docker_name}_port.conf" ]; then
                local docker_port=$(docker port "$docker_name" | head -n1 | awk -F'[:]' '/->/ {print $NF; exit}')
                docker_port=${docker_port:-0000}
                echo "$docker_port" >"/home/docker/${docker_name}_port.conf"
            fi
            local docker_port=$(cat "/home/docker/${docker_name}_port.conf")
            check_docker_app_ip
        fi
        echo ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装             ${gl_bufan}2. ${gl_bai}更新             ${gl_bufan}3. ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}5. ${gl_bai}添加域名访问     ${gl_bufan}6. ${gl_bai}删除域名访问"
        echo -e "${gl_bufan}7. ${gl_bai}允许IP+端口访问  ${gl_bufan}8. ${gl_bai}阻止IP+端口访问"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice
        case $choice in
        1)
            setup_docker_dir
            check_disk_space $app_size /home/docker
            read -r -e -p "输入应用对外服务端口，回车默认使用${docker_port}端口: " app_port
            local app_port=${app_port:-${docker_port}}
            local docker_port=$app_port
            install jq
            install_docker
            docker_app_install
            echo "$docker_port" >"/home/docker/${docker_name}_port.conf"
            add_app_id
            ;;
        2)
            docker_app_update
            add_app_id
            ;;
        3)
            docker_app_uninstall
            rm -f /home/docker/${docker_name}_port.conf

            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            ;;
        5)
            echo "${docker_name}域名访问设置"
            add_yuming
            ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
            block_container_port "$docker_name" "$ipv4_address"
            ;;
        6)
            echo "域名格式 example.com 不带https://"
            web_del
            ;;
        7)
            clear_container_rules "$docker_name" "$ipv4_address"
            ;;
        8)
            block_container_port "$docker_name" "$ipv4_address"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

prometheus_install() {

    local PROMETHEUS_DIR="/home/docker/monitoring/prometheus"
    local GRAFANA_DIR="/home/docker/monitoring/grafana"
    local NETWORK_NAME="monitoring"

    # Create necessary directories
    mkdir -p $PROMETHEUS_DIR
    mkdir -p $GRAFANA_DIR

    # Set correct ownership for Grafana directory
    chown -R 472:472 $GRAFANA_DIR

    if [ ! -f "$PROMETHEUS_DIR/prometheus.yml" ]; then
        curl -o "$PROMETHEUS_DIR/prometheus.yml" ${gh_proxy}raw.githubusercontent.com/kejilion/config/refs/heads/main/prometheus/prometheus.yml
    fi

    # Create Docker network for monitoring
    docker network create $NETWORK_NAME

    # Run Node Exporter container
    docker run -d \
        --name=node-exporter \
        --network $NETWORK_NAME \
        --restart=always \
        prom/node-exporter

    # Run Prometheus container
    docker run -d \
        --name prometheus \
        -v $PROMETHEUS_DIR/prometheus.yml:/etc/prometheus/prometheus.yml \
        -v $PROMETHEUS_DIR/data:/prometheus \
        --network $NETWORK_NAME \
        --restart=always \
        --user 0:0 \
        prom/prometheus:latest

    # Run Grafana container
    docker run -d \
        --name grafana \
        -p "${docker_port}":3000 \
        -v $GRAFANA_DIR:/var/lib/grafana \
        --network $NETWORK_NAME \
        --restart=always \
        grafana/grafana:latest

}

tmux_run() {
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
    # if [ $? != 0 ]; then
    if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        # Session doesn't exist, create a new one
        tmux new -s "$SESSION_NAME"
    else
        tmux attach-session -t "$SESSION_NAME"
    fi
}

tmux_run_d() {

    local base_name="tmuxd"
    local tmuxd_ID=1

    # 检查会话是否存在的函数
    session_exists() {
        tmux has-session -t "$1" 2>/dev/null
    }

    # 循环直到找到一个不存在的会话名称
    while session_exists "$base_name-$tmuxd_ID"; do
        local tmuxd_ID=$((tmuxd_ID + 1))
    done

    # 创建新的 tmux 会话
    tmux new -d -s "$base_name-$tmuxd_ID" "$tmuxd"

}

f2b_status() {
    fail2ban-client reload
    sleep 3
    fail2ban-client status
}

# f2b_status_xxx() {
#     fail2ban-client status "$xxx"
# }

check_f2b_status() {
    if command -v fail2ban-client >/dev/null 2>&1; then
        check_f2b_status="${gl_lv}已安装${gl_bai}"
    else
        check_f2b_status="${gl_hui}未安装${gl_bai}"
    fi
}

f2b_install_sshd() {
    docker rm -f fail2ban >/dev/null 2>&1
    install fail2ban
    # start fail2ban 
    systemctl start fail2ban
    enable fail2ban

    if command -v dnf &>/dev/null; then
        cd /etc/fail2ban/jail.d/
        curl -sS -O https://gitee.com/meimolihan/sh/raw/master/f2b/centos-ssh.conf
    fi
}

# f2b_sshd() {
#     if grep -q 'Alpine' /etc/issue; then
#         xxx=alpine-sshd
#         f2b_status_xxx
#     else
#         xxx=sshd
#         f2b_status_xxx
#     fi
# }

f2b_sshd() {
    local jail
    if grep -qi 'Alpine' /etc/issue 2>/dev/null; then
        jail=alpine-sshd
    else
        jail=sshd
    fi
    fail2ban-client status "$jail"
}

f2b_autostart() {
    status=$(systemctl is-enabled fail2ban 2>/dev/null || echo "unknown")

    if [[ $status == "enabled" ]]; then
        echo -e "\n[${gl_lv}✔${gl_bai}] 无需重复操作，${gl_huang}fail2ban ${gl_lv}已是开机自启状态。${gl_bai}"
    else
        echo -e "\n${gl_bai}正在设置 ${gl_huang}fail2ban${gl_bai} 开机自启，请稍候..."
        if systemctl enable fail2ban >/dev/null 2>&1; then
            echo -e "\n[${gl_lv}✔${gl_bai}] 设置成功！fail2ban 已设为开机自启。"
        else
            echo -e "\n[${gl_hong}✔${gl_bai}] 设置失败，请检查是否安装 fail2ban 或以 root 身份运行。"
        fi
    fi
}

server_reboot() {

    read -r -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}现在重启服务器吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" rboot
    case "$rboot" in
    [Yy])
        echo "已重启"
        reboot
        ;;
    *)
        echo "已取消"
        ;;
    esac

}

output_status() {
    output=$(awk 'BEGIN { rx_total = 0; tx_total = 0 }
		$1 ~ /^(eth|ens|enp|eno)[0-9]+/ {
			rx_total += $2
			tx_total += $10
		}
		END {
			rx_units = "Bytes";
			tx_units = "Bytes";
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "K"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "M"; }
			if (rx_total > 1024) { rx_total /= 1024; rx_units = "G"; }

			if (tx_total > 1024) { tx_total /= 1024; tx_units = "K"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "M"; }
			if (tx_total > 1024) { tx_total /= 1024; tx_units = "G"; }

			printf("%.2f%s %.2f%s\n", rx_total, rx_units, tx_total, tx_units);
		}' /proc/net/dev)

    rx=$(echo "$output" | awk '{print $1}')
    tx=$(echo "$output" | awk '{print $2}')

}

ldnmp_install_status_one() {

    if docker inspect "php" &>/dev/null; then
        clear
        echo -e "${gl_huang}提示: ${gl_bai}建站环境已安装。无需再次安装！"
        break_end
        linux_ldnmp
    fi

}

ldnmp_install_all() {
    cd ~
    ## "安装LDNMP环境"
    root_use
    clear
    echo -e "${gl_huang}LDNMP环境未安装，开始安装LDNMP环境...${gl_bai}"
    check_disk_space 3 /home
    check_port
    install_dependency
    install_docker
    install_certbot
    install_ldnmp_conf
    install_ldnmp

}

nginx_install_all() {
    cd ~
    ## "安装nginx环境"
    root_use
    clear
    echo -e "${gl_huang}nginx未安装，开始安装nginx环境...${gl_bai}"
    check_disk_space 1 /home
    check_port
    install_dependency
    install_docker
    install_certbot
    install_ldnmp_conf
    nginx_upgrade
    clear
    local nginx_version
    nginx_version=$(docker exec nginx nginx -v 2>&1)
    local nginx_version
    nginx_version=$(echo "$nginx_version" | grep -oP "nginx/\K[0-9]+\.[0-9]+\.[0-9]+")
    echo "nginx已安装完成"
    echo -e "当前版本: ${gl_huang}v$nginx_version${gl_bai}"
    echo ""

}

ldnmp_install_status() {

    if ! docker inspect "php" &>/dev/null; then
        ldnmp_install_all
    fi

}

nginx_install_status() {

    if ! docker inspect "nginx" &>/dev/null; then
        nginx_install_all
    fi

}

ldnmp_web_on() {
    clear
    echo "您的 $webname 搭建好了！"
    echo "https://${yuming}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo "$webname 安装信息如下: "

}

nginx_web_on() {
    clear
    echo "您的 $webname 搭建好了！"
    echo "https://$yuming"

}

ldnmp_wp() {
    clear
    # wordpress
    webname="WordPress"
    yuming="${1:-}"
    echo "开始部署 $webname"
    if [ -z ""$yuming"" ]; then
        add_yuming
    fi
    repeat_add_yuming
    ldnmp_install_status
    install_ssltls
    certs_status
    add_db
    wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
    wget -O /etc/nginx/conf.d/"$yuming".conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/wordpress.com.conf
    sed -i "s/yuming.com/"$yuming"/g" /etc/nginx/conf.d/"$yuming".conf
    nginx_http_on

    cd /etc/nginx/html
    mkdir "$yuming"
    cd "$yuming"
    wget -O latest.zip ${gh_proxy}github.com/kejilion/Website_source_code/raw/refs/heads/main/wp-latest.zip
    unzip latest.zip
    rm latest.zip
    echo "define('FS_METHOD', 'direct'); define('WP_REDIS_HOST', 'redis'); define('WP_REDIS_PORT', '6379'); define('WP_REDIS_MAXTTL', 86400); define('WP_CACHE_KEY_SALT', '${yuming}_');" >>/etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php
    sed -i "s|database_name_here|$dbname|g" "/etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php"
    sed -i "s|username_here|$dbuse|g" "/etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php"
    sed -i "s|password_here|$dbusepasswd|g" "/etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php"
    sed -i "s|localhost|mysql|g"" /etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php"
    cp "/etc/nginx/html/"$yuming"/wordpress/wp-config-sample.php" "/etc/nginx/html/"$yuming"/wordpress/wp-config.php"

    restart_ldnmp
    nginx_web_on

}

ldnmp_Proxy() {
    clear
    webname="反向代理-IP+端口"
    yuming="${1:-}"
    reverseproxy="${2:-}"
    port="${3:-}"

    echo "开始部署 $webname"
    if [ -z ""$yuming"" ]; then
        add_yuming
    fi
    if [ -z "$reverseproxy" ]; then
        read -r -e -p "请输入你的反代IP: " reverseproxy
    fi

    if [ -z ""$port"" ]; then
        read -r -e -p "请输入你的反代端口: " port
    fi
    nginx_install_status
    install_ssltls
    certs_status
    wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
    wget -O /etc/nginx/conf.d/"$yuming".conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy.conf
    sed -i "s/yuming.com/"$yuming"/g" /etc/nginx/conf.d/"$yuming".conf
    sed -i "s/0.0.0.0/$reverseproxy/g" /etc/nginx/conf.d/"$yuming".conf
    sed -i "s|0000|"$port"|g" /etc/nginx/conf.d/"$yuming".conf
    nginx_http_on
    docker exec nginx nginx -s reload
    nginx_web_on
}

ldnmp_Proxy_backend() {
    clear
    webname="反向代理-负载均衡"

    echo "开始部署 $webname"
    if [ -z ""$yuming"" ]; then
        add_yuming
    fi

    if [ -z "$reverseproxy_port" ]; then
        read -r -e -p "请输入你的多个反代IP+端口用空格隔开（例如 127.0.0.1:3000 127.0.0.1:3002）： " reverseproxy_port
    fi

    nginx_install_status
    install_ssltls
    certs_status
    wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
    wget -O /etc/nginx/conf.d/"$yuming".conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-backend.conf

    backend=$(tr -dc 'A-Za-z' </dev/urandom | head -c 8)
    sed -i "s/backend_yuming_com/backend_$backend/g" /etc/nginx/conf.d/""$yuming"".conf

    sed -i "s/yuming.com/"$yuming"/g" /etc/nginx/conf.d/"$yuming".conf

    upstream_servers=""
    for server in $reverseproxy_port; do
        upstream_servers="$upstream_servers    server $server;\n"
    done

    sed -i "s/# 动态添加/$upstream_servers/g" /etc/nginx/conf.d/"$yuming".conf

    nginx_http_on
    docker exec nginx nginx -s reload
    nginx_web_on
}

list_stream_services() {

    STREAM_DIR="/etc/nginx/stream.d"
    printf "%-25s %-18s %-25s %-20s\n" "服务名" "通信类型" "本机地址" "后端地址"

    if [ -z "$(ls -A "$STREAM_DIR")" ]; then
        return
    fi

    for conf in "$STREAM_DIR"/*; do
        # 服务名取文件名
        service_name=$(basename "$conf" .conf)

        # 获取 upstream 块中的 server 后端 IP:端口
        backend=$(grep -Po '(?<=server )[^;]+' "$conf" | head -n1)

        # 获取 listen 端口
        listen_port=$(grep -Po '(?<=listen )[^;]+' "$conf" | head -n1)

        # 默认本地 IP
        ip_address
        local_ip="$ipv4_address"

        # 获取通信类型，优先从文件名后缀或内容判断
        if grep -qi 'udp;' "$conf"; then
            proto="udp"
        else
            proto="tcp"
        fi

        # 拼接监听 IP:端口
        local_addr="$local_ip:$listen_port"

        printf "%-22s %-14s %-21s %-20s\n" "$service_name" "$proto" "$local_addr" "$backend"
    done
}

stream_panel() {
    local app_id="104"
    local docker_name="nginx"

    while true; do
        clear
        check_docker_app
        check_docker_image_update "$docker_name"
        echo -e "Stream四层代理转发工具 $check_docker $update_status"
        echo "NGINX Stream 是 NGINX 的 TCP/UDP 代理模块，用于实现高性能的 传输层流量转发和负载均衡。"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        if [ -d "/etc/nginx/stream.d" ]; then
            list_stream_services
        fi
        echo ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装               ${gl_bufan}2. ${gl_bai}更新               ${gl_bufan}3. ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}4. ${gl_bai}添加转发服务       ${gl_bufan}5. ${gl_bai}修改转发服务       ${gl_bufan}6. ${gl_bai}删除转发服务"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice
        case $choice in
        1)
            nginx_install_status
            add_app_id
            ;;
        2)
            update_docker_compose_with_db_creds
            nginx_upgrade
            add_app_id
            ;;
        3)
            read -r -e -p "$(echo -e "${gl_bai}确定要删除 nginx 容器吗？这可能会影响网站功能！ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                docker rm -f nginx
                sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
                echo "nginx 容器已删除。"
            else
                echo "操作已取消。"
            fi
            ;;
        4)
            ldnmp_Proxy_backend_stream
            add_app_id
            ;;
        5)
            read -r -e -p "请输入你要编辑的服务名: " stream_name
            install nano
            nano /etc/nginx/stream.d/"$stream_name".conf
            docker restart nginx
            ;;
        6)
            read -r -e -p "请输入你要删除的服务名: " stream_name
            rm /etc/nginx/stream.d/"$stream_name".conf >/dev/null 2>&1
            docker restart nginx
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

ldnmp_Proxy_backend_stream() {
    clear
    webname="Stream四层代理-负载均衡"

    echo "开始部署 $webname"

    # 获取代理名称
    read -r -rp "请输入代理转发名称 (如 mysql_proxy): " proxy_name
    if [ -z "$proxy_name" ]; then
        echo "名称不能为空"
        return 1
    fi

    # 获取监听端口
    read -r -rp "请输入本机监听端口 (如 3306): " listen_port
    if ! [[ "$listen_port" =~ ^[0-9]+$ ]]; then
        echo "端口必须是数字"
        return 1
    fi

    echo "请选择协议类型："
    echo -e "${gl_bufan}1. ${gl_bai}TCP    ${gl_bufan}2. ${gl_bai}UDP"
    read -r -rp "请输入序号 [1-2]: " proto_choice

    case "$proto_choice" in
    1)
        proto="tcp"
        listen_suffix=""
        ;;
    2)
        proto="udp"
        listen_suffix=" udp"
        ;;
    *)
        echo "无效选择"
        return 1
        ;;
    esac

    read -r -e -p "请输入你的一个或者多个后端IP+端口用空格隔开（例如 10.13.0.2:3306 10.13.0.3:3306）： " reverseproxy_port

    nginx_install_status
    cd /home && mkdir -p web/stream.d
    grep -q '^[[:space:]]*stream[[:space:]]*{' /etc/nginx/nginx.conf || echo -e '\nstream {\n    include /etc/nginx/stream.d/*.conf;\n}' | tee -a /etc/nginx/nginx.conf
    wget -O /etc/nginx/stream.d/"$proxy_name".conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-backend-stream.conf

    backend=$(tr -dc 'A-Za-z' </dev/urandom | head -c 8)
    sed -i "s/backend_yuming_com/${proxy_name}_${backend}/g" /etc/nginx/stream.d/"$proxy_name".conf
    sed -i "s|listen 80|listen $listen_port $listen_suffix|g" /etc/nginx/stream.d/"$proxy_name".conf
    sed -i "s|listen \[::\]:|listen [::]:${listen_port} ${listen_suffix}|g" "/etc/nginx/stream.d/${proxy_name}.conf"

    upstream_servers=""
    for server in $reverseproxy_port; do
        upstream_servers="$upstream_servers    server $server;\n"
    done

    sed -i "s/# 动态添加/$upstream_servers/g" /etc/nginx/stream.d/"$proxy_name".conf

    docker exec nginx nginx -s reload
    clear
    echo "您的 $webname 搭建好了！"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo "访问地址:"
    ip_address
    if [ -n "$ipv4_address" ]; then
        echo "$ipv4_address:${listen_port}"
    fi
    if [ -n "$ipv6_address" ]; then
        echo "$ipv6_address:${listen_port}"
    fi
    echo ""
}

find_container_by_host_port() {
    port="$1"
    docker_name=$(docker ps --format '{{.ID}} {{.Names}}' | while read -r id name; do
        if docker port "$id" | grep -q ":"$port""; then
            echo "$name"
            break
        fi
    done)
}

ldnmp_web_status() {
    root_use
    while true; do
        # ① 统计站点数（/etc/nginx/conf.d 下 .conf 文件）
        local site_count
        site_count=$(find /etc/nginx/conf.d/ -name "*.conf" -type f 2>/dev/null | wc -l)
        local output="${gl_lv}${site_count}${gl_bai}"

        # ② 本地数据库数（无容器）—— 原逻辑不动
        local db_count=0
        if command -v mysql &>/dev/null; then
            local dbrootpasswd=$(grep -oP 'password=\K.*' /root/.my.cnf 2>/dev/null)
            db_count=$(mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -e 'SHOW DATABASES;' 2>/dev/null |
                       grep -Ev 'Database|information_schema|mysql|performance_schema|sys' | wc -l)
        fi
        local db_output="${gl_lv}${db_count}${gl_bai}"

        clear
        echo "LDNMP环境"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        ldnmp_v

        # 站点列表标题
        echo -e "站点: ${output}                      证书到期时间"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 遍历所有 .conf 文件，提取 server_name 作为站点名，再读对应证书有效期
        for conf in /etc/nginx/conf.d/*.conf; do
            [ -f "$conf" ] || continue
            # 取第一个 server_name 作为域名（简单场景够用）
            local domain=$(grep -m1 -oP 'server_name\s+\K[^;]+' "$conf" | awk '{print $1}')
            [ -z "$domain" ] && domain=$(basename "$conf" .conf)   # 兜底：用文件名
            # local cert_file="/etc/nginx/keyfile/${domain}.pem"
            local cert_file="/etc/nginx/keyfile/mobufan.eu.org.pem"
            local expire_date="未配置证书"
            if [ -f "$cert_file" ]; then
                expire_date=$(openssl x509 -noout -enddate -in "$cert_file" 2>/dev/null | awk -F'=' '{print $2}')
                expire_date=$(date -d "$expire_date" '+%Y-%m-%d' 2>/dev/null || echo "格式错误")
            fi
            printf "%-30s%s\n" "$domain" "$expire_date"
        done

        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo ""
        echo -e "${gl_bufan}数据库: ${db_output}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -e 'SHOW DATABASES;' 2>/dev/null |
            grep -Ev 'Database|information_schema|mysql|performance_schema|sys'

        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo ""
        echo -e "${gl_bufan}站点目录"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "数据 ${gl_hui}/etc/nginx/html${gl_bai}     证书 ${gl_hui}/etc/nginx/keyfile${gl_bai}     配置 ${gl_hui}/etc/nginx/conf.d${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo ""
        echo "操作"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}申请/更新域名证书               ${gl_bufan}2.  ${gl_bai}克隆站点域名"
        echo -e "${gl_bufan}3.  ${gl_bai}清理站点缓存                    ${gl_bufan}4.  ${gl_bai}创建关联站点"
        echo -e "${gl_bufan}5.  ${gl_bai}查看访问日志                    ${gl_bufan}6.  ${gl_bai}查看错误日志"
        echo -e "${gl_bufan}7.  ${gl_bai}编辑全局配置                    ${gl_bufan}8.  ${gl_bai}编辑站点配置"
        echo -e "${gl_bufan}9.  ${gl_bai}管理站点数据库                  ${gl_bufan}10. ${gl_bai}查看站点分析报告"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}20. ${gl_bai}删除指定站点数据"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        read -rp "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            read -rp "请输入你的域名: " yuming
            # 使用系统 certbot 申请证书
            certbot certonly --webroot -w /var/www/html -d "$yuming" --agree-tos --non-interactive --email admin@"$yuming"
            # 把证书拷到统一目录
            install -m 644 "/etc/letsencrypt/live/$yuming/fullchain.pem" "/etc/nginx/keyfile/${yuming}_cert.pem"
            install -m 600 "/etc/letsencrypt/live/$yuming/privkey.pem"   "/etc/nginx/keyfile/${yuming}_key.pem"
            # 生成 / 更新 nginx 配置
            install_ssltls
            certs_status
            systemctl reload nginx
            ;;
        2)
            read -rp "请输入旧域名: " oddyuming
            read -rp "请输入新域名: " yuming
            # 证书克隆
            certbot certonly --webroot -w /var/www/html -d "$yuming" --agree-tos --non-interactive --email admin@"$yuming"
            install -m 644 "/etc/letsencrypt/live/$yuming/fullchain.pem" "/etc/nginx/keyfile/${yuming}_cert.pem"
            install -m 600 "/etc/letsencrypt/live/$yuming/privkey.pem"   "/etc/nginx/keyfile/${yuming}_key.pem"
            certs_status

            # MySQL 克隆
            add_db
            local odd_dbname="${oddyuming//[^A-Za-z0-9]/_}"
            local dbname="${yuming//[^A-Za-z0-9]/_}"
            mysqldump -u root ${dbrootpasswd:+-p"$dbrootpasswd"} "$odd_dbname" | mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} "$dbname"

            # 批量替换库内旧域名 → 新域名
            local tables=$(mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -D "$dbname" -e 'SHOW TABLES;' 2>/dev/null | awk 'NR>1{print $1}')
            for table in $tables; do
                local columns=$(mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -D "$dbname" -e "SHOW COLUMNS FROM $table;" 2>/dev/null | awk 'NR>1{print $1}')
                for column in $columns; do
                    mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -D "$dbname" \
                          -e "UPDATE $table SET $column = REPLACE($column, '$oddyuming', '$yuming') WHERE $column LIKE '%$oddyuming%';" 2>/dev/null
                done
            done

            # 网站目录克隆
            cp -r /etc/nginx/html/"$oddyuming" /etc/nginx/html/"$yuming"
            find /etc/nginx/html/"$yuming" -type f -exec sed -i "s/$odd_dbname/$dbname/g" {} +
            find /etc/nginx/html/"$yuming" -type f -exec sed -i "s/$oddyuming/$yuming/g"   {} +

            # 配置克隆
            cp /etc/nginx/conf.d/"$oddyuming".conf /etc/nginx/conf.d/"$yuming".conf
            sed -i "s/$oddyuming/$yuming/g"                     /etc/nginx/conf.d/"$yuming".conf
            sed -i "s|/etc/nginx/keyfile/${oddyuming}_cert.pem|/etc/nginx/keyfile/${yuming}_cert.pem|g" /etc/nginx/conf.d/"$yuming".conf
            sed -i "s|/etc/nginx/keyfile/${oddyuming}_key.pem|/etc/nginx/keyfile/${yuming}_key.pem|g"   /etc/nginx/conf.d/"$yuming".conf

            systemctl reload nginx
            ;;
        3)
            web_cache
            ;;
        4)
            echo -e "为现有的站点再关联一个新域名用于访问"
            read -rp "请输入现有的域名: " oddyuming
            read -rp "请输入新域名: " yuming
            certbot certonly --webroot -w /var/www/html -d "$yuming" --agree-tos --non-interactive --email admin@"$yuming"
            install -m 644 "/etc/letsencrypt/live/$yuming/fullchain.pem" "/etc/nginx/keyfile/${yuming}_cert.pem"
            install -m 600 "/etc/letsencrypt/live/$yuming/privkey.pem"   "/etc/nginx/keyfile/${yuming}_key.pem"

            cp /etc/nginx/conf.d/"$oddyuming".conf /etc/nginx/conf.d/"$yuming".conf
            sed -i "s|server_name $oddyuming|server_name $yuming|g" /etc/nginx/conf.d/"$yuming".conf
            sed -i "s|/etc/nginx/keyfile/${oddyuming}_cert.pem|/etc/nginx/keyfile/${yuming}_cert.pem|g" /etc/nginx/conf.d/"$yuming".conf
            sed -i "s|/etc/nginx/keyfile/${oddyuming}_key.pem|/etc/nginx/keyfile/${yuming}_key.pem|g"   /etc/nginx/conf.d/"$yuming".conf

            systemctl reload nginx
            ;;
        5)
            tail -n 200 /var/log/nginx/access.log
            break_end
            ;;
        6)
            tail -n 200 /var/log/nginx/error.log
            break_end
            ;;
        7)
            read -r -e -p "编辑站点配置，请输入你要编辑的域名: " yuming
            install nano
            nano /etc/nginx/conf.d/"$yuming".conf
            # 重载配置（系统服务）
            systemctl reload nginx
            break_end
            ;;
        8)
            read -r -e -p "编辑站点配置，请输入你要编辑的域名: " yuming
            $EDITOR /etc/nginx/conf.d/"$yuming".conf
            systemctl reload nginx
            ;;
        9)
            # 管理站点数据库
            # 直接打开本地 phpMyAdmin（若已装）
            echo "正在尝试打开 phpMyAdmin ..."
            xdg-open http://localhost/phpmyadmin 2>/dev/null || echo "请手动访问 http://<你的IP>/phpmyadmin"
            ;;
        10)
            # 本地 goaccess 实时分析
            install goaccess
            goaccess /var/log/nginx/access.log --log-format=COMBINED
            ;;
        20)
            web_del
            read -rp "请输入要删除证书的域名: " yuming
            certbot delete --cert-name "$yuming" 2>/dev/null
            ;;
        0) break ;;
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}


check_panel_app() {
    if $lujing >/dev/null 2>&1; then
        check_panel="${gl_lv}已安装${gl_bai}"
    else
        check_panel=""
    fi
}

install_panel() {
    ## "${panelname}管理"
    while true; do
        clear
        check_panel_app
        echo -e "$panelname $check_panel"
        echo "${panelname}是一款时下流行且强大的运维管理面板。"
        echo "官网介绍: $panelurl "

        echo ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装            ${gl_bufan}2. ${gl_bai}管理            ${gl_bufan}3. ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)
            check_disk_space 1
            install wget
            iptables_open
            panel_app_install
            add_app_id
            ;;
        2)
            panel_app_manage
            add_app_id
            ;;
        3)
            panel_app_uninstall
            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

check_frp_app() {

    if [ -d "/home/frp/" ]; then
        check_frp="${gl_lv}已安装${gl_bai}"
    else
        check_frp="${gl_hui}未安装${gl_bai}"
    fi

}

donlond_frp() {
    role="$1"
    config_file="/home/frp/${role}.toml"

    docker run -d \
        --name "$role" \
        --restart=always \
        --network host \
        -v "$config_file":"/frp/${role}.toml" \
        kjlion/frp:alpine \
        "/frp/${role}" -c "/frp/${role}.toml"

}

generate_frps_config() {

    # 生成随机端口和凭证
    local bind_port=8055
    local dashboard_port=8056
    local token
    token=$(openssl rand -hex 16)
    local dashboard_user="user_$(openssl rand -hex 4)"
    local dashboard_pwd=$(openssl rand -hex 8)

    mkdir -p /home/frp
    touch /home/frp/frps.toml
    cat <<EOF >/home/frp/frps.toml
[common]
bind_port = $bind_port
authentication_method = token
token = $token
dashboard_port = $dashboard_port
dashboard_user = $dashboard_user
dashboard_pwd = $dashboard_pwd
EOF

    donlond_frp frps

    # 输出生成的信息
    ip_address
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo "客户端部署时需要用的参数"
    echo "服务IP: $ipv4_address"
    echo "token: $token"
    echo
    echo "FRP面板信息"
    echo "FRP面板地址: http://$ipv4_address:$dashboard_port"
    echo "FRP面板用户名: $dashboard_user"
    echo "FRP面板密码: $dashboard_pwd"
    echo

    open_port 8055 8056

}

configure_frpc() {
    read -r -e -p "请输入外网对接IP: " server_addr
    read -r -e -p "请输入外网对接token: " token
    echo

    mkdir -p /home/frp
    touch /home/frp/frpc.toml
    cat <<EOF >/home/frp/frpc.toml
[common]
server_addr = ${server_addr}
server_port = 8055
token = ${token}

EOF

    donlond_frp frpc

    open_port 8055

}

add_forwarding_service() {
    # 提示用户输入服务名称和转发信息
    read -r -e -p "请输入服务名称: " service_name
    read -r -e -p "请输入转发类型 (tcp/udp) [回车默认tcp]: " service_type
    local service_type=${service_type:-tcp}
    read -r -e -p "请输入内网IP [回车默认127.0.0.1]: " local_ip
    local local_ip=${local_ip:-127.0.0.1}
    read -r -e -p "请输入内网端口: " local_port
    read -r -e -p "请输入外网端口: " remote_port

    # 将用户输入写入配置文件
    cat <<EOF >>/home/frp/frpc.toml
[$service_name]
type = ${service_type}
local_ip = ${local_ip}
local_port = ${local_port}
remote_port = ${remote_port}

EOF

    # 输出生成的信息
    echo "服务 $service_name 已成功添加到 frpc.toml"

    docker restart frpc

    open_port "$local_port"

}

delete_forwarding_service() {
    # 提示用户输入需要删除的服务名称
    read -r -e -p "请输入需要删除的服务名称: " service_name
    # 使用 sed 删除该服务及其相关配置
    sed -i "/\[$service_name\]/,/^$/d" /home/frp/frpc.toml
    echo "服务 $service_name 已成功从 frpc.toml 删除"

    docker restart frpc

}

list_forwarding_services() {
    local config_file="$1"

    # 打印表头
    printf "%-20s %-25s %-30s %-10s\n" "服务名称" "内网地址" "外网地址" "协议"

    awk '
	BEGIN {
		server_addr=""
		server_port=""
		current_service=""
	}

	/^server_addr = / {
		gsub(/"|'"'"'/, "", $3)
		server_addr=$3
	}

	/^server_port = / {
		gsub(/"|'"'"'/, "", $3)
		server_port=$3
	}

	/^\[.*\]/ {
		# 如果已有服务信息，在处理新服务之前打印当前服务
		if (current_service != "" && current_service != "common" && local_ip != "" && local_port != "") {
			printf "%-16s %-21s %-26s %-10s\n", \
				current_service, \
				local_ip ":" local_port, \
				server_addr ":" remote_port, \
				type
		}

		# 更新当前服务名称
		if ($1 != "[common]") {
			gsub(/[\[\]]/, "", $1)
			current_service=$1
			# 清除之前的值
			local_ip=""
			local_port=""
			remote_port=""
			type=""
		}
	}

	/^local_ip = / {
		gsub(/"|'"'"'/, "", $3)
		local_ip=$3
	}

	/^local_port = / {
		gsub(/"|'"'"'/, "", $3)
		local_port=$3
	}

	/^remote_port = / {
		gsub(/"|'"'"'/, "", $3)
		remote_port=$3
	}

	/^type = / {
		gsub(/"|'"'"'/, "", $3)
		type=$3
	}

	END {
		# 打印最后一个服务的信息
		if (current_service != "" && current_service != "common" && local_ip != "" && local_port != "") {
			printf "%-16s %-21s %-26s %-10s\n", \
				current_service, \
				local_ip ":" local_port, \
				server_addr ":" remote_port, \
				type
		}
	}' "$config_file"
}

# 获取 FRP 服务端端口
get_frp_ports() {
    mapfile -t ports < <(ss -tulnape | grep frps | awk '{print $5}' | awk -F':' '{print $NF}' | sort -u)
}

# 生成访问地址
generate_access_urls() {
    # 首先获取所有端口
    get_frp_ports

    # 检查是否有非 8055/8056 的端口
    local has_valid_ports=false
    for port in "${ports[@]}"; do
        if [[ "$port" != "8055" && "$port" != "8056" ]]; then
            has_valid_ports=true
            break
        fi
    done

    # 只在有有效端口时显示标题和内容
    if [ "$has_valid_ports" = true ]; then
        echo "FRP服务对外访问地址:"

        # 处理 IPv4 地址
        for port in "${ports[@]}"; do
            if [[ "$port" != "8055" && "$port" != "8056" ]]; then
                echo "http://${ipv4_address}:${port}"
            fi
        done

        # 处理 IPv6 地址（如果存在）
        if [ -n "$ipv6_address" ]; then
            for port in "${ports[@]}"; do
                if [[ "$port" != "8055" && "$port" != "8056" ]]; then
                    echo "http://[${ipv6_address}]:${port}"
                fi
            done
        fi

        # 处理 HTTPS 配置
        for port in "${ports[@]}"; do
            if [[ "$port" != "8055" && "$port" != "8056" ]]; then
                local frps_search_pattern="${ipv4_address}:${port}"
                local frps_search_pattern2="127.0.0.1:${port}"
                for file in /etc/nginx/conf.d/*.conf; do
                    if [ -f "$file" ]; then
                        if grep -q "$frps_search_pattern" "$file" 2>/dev/null || grep -q "$frps_search_pattern2" "$file" 2>/dev/null; then
                            echo "https://$(basename "$file" .conf)"
                        fi
                    fi
                done
            fi
        done
    fi
}

frps_main_ports() {
    ip_address
    generate_access_urls
}

frps_panel() {
    local app_id="55"
    local docker_name="frps"
    local docker_port=8056
    while true; do
        clear
        check_frp_app
        check_docker_image_update "$docker_name"
        echo -e "FRP服务端 $check_frp $update_status"
        echo "构建FRP内网穿透服务环境，将无公网IP的设备暴露到互联网"
        echo "官网介绍: https://github.com/fatedier/frp/"
        echo "视频教学: https://www.bilibili.com/video/BV1yMw6e2EwL?t=124.0"
        if [ -d "/home/frp/" ]; then
            check_docker_app_ip
            frps_main_ports
        fi
        echo ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装                  ${gl_bufan}2. ${gl_bai}更新                  ${gl_bufan}3. ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}5. ${gl_bai}内网服务域名访问      ${gl_bufan}6. ${gl_bai}删除域名访问"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}7. ${gl_bai}允许IP+端口访问       ${gl_bufan}8. ${gl_bai}阻止IP+端口访问"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}刷新服务状态         ${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice
        case $choice in
        1)
            install jq grep ss
            install_docker
            generate_frps_config
            add_app_id
            echo "FRP服务端已经安装完成"
            ;;
        2)
            crontab -l | grep -v 'frps' | crontab - >/dev/null 2>&1
            tmux kill-session -t frps >/dev/null 2>&1
            docker rm -f frps && docker rmi kjlion/frp:alpine >/dev/null 2>&1
            [ -f /home/frp/frps.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frps.toml /home/frp/frps.toml
            donlond_frp frps

            add_app_id
            echo "FRP服务端已经更新完成"
            ;;
        3)
            crontab -l | grep -v 'frps' | crontab - >/dev/null 2>&1
            tmux kill-session -t frps >/dev/null 2>&1
            docker rm -f frps && docker rmi kjlion/frp:alpine
            rm -rf /home/frp

            close_port 8055 8056

            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            echo "应用已卸载"
            ;;
        5)
            echo "将内网穿透服务反代成域名访问"
            add_yuming
            read -r -e -p "请输入你的内网穿透服务端口: " frps_port
            ldnmp_Proxy "${yuming}" 127.0.0.1 "${frps_port}"
            block_host_port "$frps_port" "$ipv4_address"
            ;;
        6)
            echo "域名格式 example.com 不带https://"
            web_del
            ;;
        7)
            read -r -e -p "请输入需要放行的端口: " frps_port
            clear_host_port_rules "$frps_port" "$ipv4_address"
            ;;
        8)
            echo "如果你已经反代域名访问了，可用此功能阻止IP+端口访问，这样更安全。"
            read -r -e -p "请输入需要阻止的端口: " frps_port
            block_host_port "$frps_port" "$ipv4_address"
            ;;
        00)
            echo "已经刷新FRP服务状态"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

frpc_panel() {
    local app_id="56"
    local docker_name="frpc"
    local docker_port=8055
    while true; do
        clear
        check_frp_app
        check_docker_image_update "$docker_name"
        echo -e "FRP客户端 $check_frp $update_status"
        echo "与服务端对接，对接后可创建内网穿透服务到互联网访问"
        echo "官网介绍: https://github.com/fatedier/frp/"
        echo "视频教学: https://www.bilibili.com/video/BV1yMw6e2EwL?t=173.9"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        if [ -d "/home/frp/" ]; then
            [ -f /home/frp/frpc.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frpc.toml /home/frp/frpc.toml
            list_forwarding_services "/home/frp/frpc.toml"
        fi
        echo ""
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}安装               ${gl_bufan}2. ${gl_bai}更新               ${gl_bufan}3. ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}4. ${gl_bai}添加对外服务       ${gl_bufan}5. ${gl_bai}删除对外服务       ${gl_bufan}6. ${gl_bai}手动配置服务"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice
        case $choice in
        1)
            install jq grep ss
            install_docker
            configure_frpc

            add_app_id
            echo "FRP客户端已经安装完成"
            ;;
        2)
            crontab -l | grep -v 'frpc' | crontab - >/dev/null 2>&1
            tmux kill-session -t frpc >/dev/null 2>&1
            docker rm -f frpc && docker rmi kjlion/frp:alpine >/dev/null 2>&1
            [ -f /home/frp/frpc.toml ] || cp /home/frp/frp_0.61.0_linux_amd64/frpc.toml /home/frp/frpc.toml
            donlond_frp frpc

            add_app_id
            echo "FRP客户端已经更新完成"
            ;;
        3)
            crontab -l | grep -v 'frpc' | crontab - >/dev/null 2>&1
            tmux kill-session -t frpc >/dev/null 2>&1
            docker rm -f frpc && docker rmi kjlion/frp:alpine
            rm -rf /home/frp
            close_port 8055

            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            echo "应用已卸载"
            ;;
        4)
            add_forwarding_service
            ;;
        5)
            delete_forwarding_service
            ;;
        6)
            install nano
            nano /home/frp/frpc.toml
            docker restart frpc
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

yt_menu_pro() {

    local app_id="66"
    local VIDEO_DIR="/home/yt-dlp"
    local URL_FILE="$VIDEO_DIR/urls.txt"
    local ARCHIVE_FILE="$VIDEO_DIR/archive.txt"

    mkdir -p "$VIDEO_DIR"

    while true; do

        if [ -x "/usr/local/bin/yt-dlp" ]; then
            local YTDLP_STATUS="${gl_lv}已安装${gl_bai}"
        else
            local YTDLP_STATUS="${gl_hui}未安装${gl_bai}"
        fi

        clear
        echo -e "yt-dlp $YTDLP_STATUS"
        echo -e "yt-dlp 是一个功能强大的视频下载工具，支持 YouTube、Bilibili、Twitter 等数千站点。"
        echo -e "官网地址：https://github.com/yt-dlp/yt-dlp"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo "已下载视频列表:"
        ls -td "$VIDEO_DIR"/*/ 2>/dev/null || echo "（暂无）"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}安装               2.  ${gl_bai}更新               3.  ${gl_bai}卸载"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}单个视频下载       6.  ${gl_bai}批量视频下载       7.  ${gl_bai}自定义参数下载"
        echo -e "${gl_bufan}8.  ${gl_bai}下载为MP3音频      9.  ${gl_bai}删除视频目录       10. ${gl_bai}Cookie管理（开发中）"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入选项编号: " choice

        case $choice in
        1)
            echo "正在安装 yt-dlp..."
            install ffmpeg
            curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
            chmod a+rx /usr/local/bin/yt-dlp

            add_app_id
            echo "安装完成。按任意键继续..."
            read -r
            ;;
        2)
            echo "正在更新 yt-dlp..."
            yt-dlp -U

            add_app_id
            echo "更新完成。按任意键继续..."
            read -r
            ;;
        3)
            echo "正在卸载 yt-dlp..."
            rm -f /usr/local/bin/yt-dlp

            sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
            echo "卸载完成。按任意键继续..."
            read -r
            ;;
        5)
            read -r -e -p "请输入视频链接: " url
            yt-dlp -P "$VIDEO_DIR" -f "bv*+ba/b" --merge-output-format mp4 \
                --write-subs --sub-langs all \
                --write-thumbnail --embed-thumbnail \
                --write-info-json \
                -o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
                --no-overwrites --no-post-overwrites "$url"
            read -r -e -p "下载完成，按任意键继续..."
            ;;
        6)
            install nano
            if [ ! -f "$URL_FILE" ]; then
                echo -e "# 输入多个视频链接地址\n# https://www.bilibili.com/bangumi/play/ep733316?spm_id_from=333.337.0.0&from_spmid=666.25.episode.0" >"$URL_FILE"
            fi
            nano $URL_FILE
            echo "现在开始批量下载..."
            yt-dlp -P "$VIDEO_DIR" -f "bv*+ba/b" --merge-output-format mp4 \
                --write-subs --sub-langs all \
                --write-thumbnail --embed-thumbnail \
                --write-info-json \
                -a "$URL_FILE" \
                -o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
                --no-overwrites --no-post-overwrites
            read -r -e -p "批量下载完成，按任意键继续..."
            ;;
        7)
            read -r -e -p "请输入完整 yt-dlp 参数（不含 yt-dlp）: " custom
            yt-dlp -P "$VIDEO_DIR" "$custom" \
                --write-subs --sub-langs all \
                --write-thumbnail --embed-thumbnail \
                --write-info-json \
                -o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
                --no-overwrites --no-post-overwrites
            read -r -e -p "执行完成，按任意键继续..."
            ;;
        8)
            read -r -e -p "请输入视频链接: " url
            yt-dlp -P "$VIDEO_DIR" -x --audio-format mp3 \
                --write-subs --sub-langs all \
                --write-thumbnail --embed-thumbnail \
                --write-info-json \
                -o "$VIDEO_DIR/%(title)s/%(title)s.%(ext)s" \
                --no-overwrites --no-post-overwrites "$url"
            read -r -e -p "音频下载完成，按任意键继续..."
            ;;

        9)
            read -r -e -p "请输入删除视频名称: " rmdir
            rm -rf "${VIDEO_DIR:?}/$rmdir"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

current_timezone() {
    if grep -q 'Alpine' /etc/issue; then
        date +"%Z %z"
    else
        timedatectl | grep "Time zone" | awk '{print $3}'
    fi

}

set_timedate() {
    local shiqu="$1"
    if grep -q 'Alpine' /etc/issue; then
        install tzdata
        cp /usr/share/zoneinfo/"${shiqu}" /etc/localtime
        hwclock --systohc
    else
        timedatectl set-timezone "${shiqu}"
    fi
}

# 修复dpkg中断问题
fix_dpkg() {
    pkill -9 -f 'apt|dpkg'
    rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
    DEBIAN_FRONTEND=noninteractive dpkg --configure -a
}

linux_update() {
    echo -e "${gl_huang}正在系统更新...${gl_bai}"
    if command -v dnf &>/dev/null; then
        dnf -y update
    elif command -v yum &>/dev/null; then
        yum -y update
    elif command -v apt &>/dev/null; then
        fix_dpkg
        DEBIAN_FRONTEND=noninteractive apt update -y
        DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
    elif command -v apk &>/dev/null; then
        apk update && apk upgrade
    elif command -v pacman &>/dev/null; then
        pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        zypper refresh
        zypper update
    elif command -v opkg &>/dev/null; then
        opkg update
    else
        echo "未知的包管理器!"
        return
    fi
}

linux_clean() {
    echo -e "${gl_huang}正在系统清理...${gl_bai}"
    if command -v dnf &>/dev/null; then
        rpm --rebuilddb
        dnf autoremove -y
        dnf clean all
        dnf makecache
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v yum &>/dev/null; then
        rpm --rebuilddb
        yum autoremove -y
        yum clean all
        yum makecache
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v apt &>/dev/null; then
        fix_dpkg
        apt autoremove --purge -y
        apt clean -y
        apt autoclean -y
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v apk &>/dev/null; then
        echo "清理包管理器缓存..."
        apk cache clean
        echo "删除系统日志..."
        rm -rf /var/log/*
        echo "删除APK缓存..."
        rm -rf /var/cache/apk/*
        echo "删除临时文件..."
        rm -rf /tmp/*

    elif command -v pacman &>/dev/null; then
        pacman -Rns "$(pacman -Qdtq)" --noconfirm
        pacman -Scc --noconfirm
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v zypper &>/dev/null; then
        zypper clean --all
        zypper refresh
        journalctl --rotate
        journalctl --vacuum-time=1s
        journalctl --vacuum-size=500M

    elif command -v opkg &>/dev/null; then
        echo "删除系统日志..."
        rm -rf /var/log/*
        echo "删除临时文件..."
        rm -rf /tmp/*

    elif command -v pkg &>/dev/null; then
        echo "清理未使用的依赖..."
        pkg autoremove -y
        echo "清理包管理器缓存..."
        pkg clean -y
        echo "删除系统日志..."
        rm -rf /var/log/*
        echo "删除临时文件..."
        rm -rf /tmp/*

    else
        echo "未知的包管理器!"
        return
    fi
    return
}

bbr_on() {

    cat >/etc/sysctl.conf <<EOF
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p

}

set_dns() {

    ip_address

    chattr -i /etc/resolv.conf
    rm /etc/resolv.conf
    touch /etc/resolv.conf

    if [ -n "$ipv4_address" ]; then
        echo "nameserver $dns1_ipv4" >>/etc/resolv.conf
        echo "nameserver $dns2_ipv4" >>/etc/resolv.conf
    fi

    if [ -n "$ipv6_address" ]; then
        echo "nameserver $dns1_ipv6" >>/etc/resolv.conf
        echo "nameserver $dns2_ipv6" >>/etc/resolv.conf
    fi

    chattr +i /etc/resolv.conf

}

set_dns_ui() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> 优化DNS地址${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo "当前DNS地址"
        echo -e "${gl_lv}$(cat /etc/resolv.conf)${gl_reset}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}国外DNS优化: "
        echo -e "${gl_huang} v4: 1.1.1.1 8.8.8.8"
        echo -e "${gl_huang} v6: 2606:4700:4700::1111 2001:4860:4860::8888"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}2.  ${gl_bai}国内DNS优化: "
        echo -e "${gl_huang} v4: 223.5.5.5 183.60.83.19"
        echo -e "${gl_huang} v6: 2400:3200::1 2400:da00::6666"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}手动编辑DNS配置"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " Limiting
        case "$Limiting" in
        1)
            local dns1_ipv4="1.1.1.1"
            local dns2_ipv4="8.8.8.8"
            local dns1_ipv6="2606:4700:4700::1111"
            local dns2_ipv6="2001:4860:4860::8888"
            set_dns
            ;;
        2)
            local dns1_ipv4="223.5.5.5"
            local dns2_ipv4="183.60.83.19"
            local dns1_ipv6="2400:3200::1"
            local dns2_ipv6="2400:da00::6666"
            set_dns
            ;;
        3)
            install nano
            chattr -i /etc/resolv.conf
            nano /etc/resolv.conf
            chattr +i /etc/resolv.conf
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

restart_ssh() {
    restart sshd ssh >/dev/null 2>&1

}

correct_ssh_config() {

    local sshd_config="/etc/ssh/sshd_config"

    # 如果找到 PasswordAuthentication 设置为 yes
    if grep -Eq "^PasswordAuthentication\s+yes" "$sshd_config"; then
        sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' "$sshd_config"
        sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' "$sshd_config"
    fi

    # 如果找到 PubkeyAuthentication 设置为 yes
    if grep -Eq "^PubkeyAuthentication\s+yes" "$sshd_config"; then
        sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
            -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
            -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
            -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' "$sshd_config"
    fi

    # 如果 PasswordAuthentication 和 PubkeyAuthentication 都没有匹配，则设置默认值
    if ! grep -Eq "^PasswordAuthentication\s+yes" "$sshd_config" && ! grep -Eq "^PubkeyAuthentication\s+yes" "$sshd_config"; then
        sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' "$sshd_config"
        sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' "$sshd_config"
    fi

}

new_ssh_port() {

    # 备份 SSH 配置文件
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    sed -i 's/^\s*#\?\s*Port/Port/' /etc/ssh/sshd_config
    sed -i "s/Port [0-9]\+/Port $new_port/g" /etc/ssh/sshd_config

    correct_ssh_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*

    restart_ssh
    open_port "$new_port"
    remove iptables-persistent ufw firewalld iptables-services >/dev/null 2>&1

    echo "SSH 端口已修改为: $new_port"

    sleep 1

}

add_sshkey() {
    chmod 700 ~/
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    ssh-keygen -t ed25519 -C "xxxx@gmail.com" -f /root/.ssh/sshkey -N ""
    cat ~/.ssh/sshkey.pub >>~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    ip_address
    echo -e "私钥信息已生成，务必复制保存，可保存成 ${gl_huang}${ipv4_address}_ssh.key${gl_bai} 文件，用于以后的SSH登录"

    echo -e "${gl_huang}------------------------${gl_bai}"
    cat ~/.ssh/sshkey
    echo -e "${gl_huang}------------------------${gl_bai}"

    sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
        -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
        -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
        -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    restart_ssh
    echo -e "${gl_lv}ROOT私钥登录已开启，已关闭ROOT密码登录，重连将会生效${gl_bai}"

}

import_sshkey() {

    read -r -e -p "请输入您的SSH公钥内容（通常以 'ssh-rsa' 或 'ssh-ed25519' 开头）: " public_key

    if [[ -z "$public_key" ]]; then
        echo -e "${gl_hong}错误：未输入公钥内容。${gl_bai}"
        return 1
    fi

    chmod 700 ~/
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/authorized_keys
    echo "$public_key" >>~/.ssh/authorized_keys
    chmod 600 ~/.ssh/authorized_keys

    sed -i -e 's/^\s*#\?\s*PermitRootLogin .*/PermitRootLogin prohibit-password/' \
        -e 's/^\s*#\?\s*PasswordAuthentication .*/PasswordAuthentication no/' \
        -e 's/^\s*#\?\s*PubkeyAuthentication .*/PubkeyAuthentication yes/' \
        -e 's/^\s*#\?\s*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    restart_ssh
    echo -e "${gl_lv}公钥已成功导入，ROOT私钥登录已开启，已关闭ROOT密码登录，重连将会生效${gl_bai}"

}

add_sshpasswd() {

    echo "设置你的ROOT密码"
    passwd
    sed -i 's/^\s*#\?\s*PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
    sed -i 's/^\s*#\?\s*PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
    rm -rf /etc/ssh/sshd_config.d/* /etc/ssh/ssh_config.d/*
    restart_ssh
    echo -e "${gl_lv}ROOT登录设置完毕！${gl_bai}"

}

root_use() {
    clear
    [ "$EUID" -ne 0 ] && echo -e "${gl_huang}提示: ${gl_bai}该功能需要root用户才能运行！" && break_end && mobufan
}

dd_xitong() {
    dd_xitong_MollyLau() {
        wget --no-check-certificate -qO InstallNET.sh "${gh_proxy}raw.githubusercontent.com/leitbogioro/Tools/master/Linux_reinstall/InstallNET.sh" && chmod a+x InstallNET.sh

    }

    dd_xitong_bin456789() {
        curl -O ${gh_proxy}raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh
    }

    dd_xitong_1() {
        echo -e "重装后初始用户名: ${gl_huang}root${gl_bai}  初始密码: ${gl_huang}LeitboGi0ro${gl_bai}  初始端口: ${gl_huang}22${gl_bai}"
        echo -e "按任意键继续..."
        read -r -n 1 -s -r -p ""
        install wget
        dd_xitong_MollyLau
    }

    dd_xitong_2() {
        echo -e "重装后初始用户名: ${gl_huang}Administrator${gl_bai}  初始密码: ${gl_huang}Teddysun.com${gl_bai}  初始端口: ${gl_huang}3389${gl_bai}"
        echo -e "按任意键继续..."
        read -r -n 1 -s -r -p ""
        install wget
        dd_xitong_MollyLau
    }

    dd_xitong_3() {
        echo -e "重装后初始用户名: ${gl_huang}root${gl_bai}  初始密码: ${gl_huang}123@@@${gl_bai}  初始端口: ${gl_huang}22${gl_bai}"
        echo -e "按任意键继续..."
        read -r -n 1 -s -r -p ""
        dd_xitong_bin456789
    }

    dd_xitong_4() {
        echo -e "重装后初始用户名: ${gl_huang}Administrator${gl_bai}  初始密码: ${gl_huang}123@@@${gl_bai}  初始端口: ${gl_huang}3389${gl_bai}"
        echo -e "按任意键继续..."
        read -r -n 1 -s -r -p ""
        dd_xitong_bin456789
    }

    while true; do
        root_use
        echo -e "${gl_zi}>>> 重装系统${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_hong}注意: ${gl_bai}重装有风险失联，不放心者慎用。重装预计花费15分钟，请提前备份数据。"
        echo -e "${gl_hui}感谢leitbogioro大佬和bin456789大佬的脚本支持！${gl_bai} "
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}Debian 13                  ${gl_bufan}2. ${gl_bai}Debian 12"
        echo -e "${gl_bufan}3. ${gl_bai}Debian 11                  ${gl_bufan}4. ${gl_bai}Debian 10"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}Ubuntu 24.04              ${gl_bufan}12. ${gl_bai}Ubuntu 22.04"
        echo -e "${gl_bufan}13. ${gl_bai}Ubuntu 20.04              ${gl_bufan}14. ${gl_bai}Ubuntu 18.04"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}Rocky Linux 10            ${gl_bufan}22. ${gl_bai}Rocky Linux 9"
        echo -e "${gl_bufan}23. ${gl_bai}Alma Linux 10             ${gl_bufan}24. ${gl_bai}Alma Linux 9"
        echo -e "${gl_bufan}25. ${gl_bai}oracle Linux 10           ${gl_bufan}26. ${gl_bai}oracle Linux 9"
        echo -e "${gl_bufan}27. ${gl_bai}Fedora Linux 42           ${gl_bufan}28. ${gl_bai}Fedora Linux 41"
        echo -e "${gl_bufan}29. ${gl_bai}CentOS 10                 ${gl_bufan}30. ${gl_bai}CentOS 9"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}31. ${gl_bai}Alpine Linux              ${gl_bufan}32. ${gl_bai}Arch Linux"
        echo -e "${gl_bufan}33. ${gl_bai}Kali Linux                ${gl_bufan}34. ${gl_bai}openEuler"
        echo -e "${gl_bufan}35. ${gl_bai}openSUSE Tumbleweed       ${gl_bufan}36. ${gl_bai}fnos飞牛公测版"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}41. ${gl_bai}Windows 11                ${gl_bufan}42. ${gl_bai}Windows 10"
        echo -e "${gl_bufan}43. ${gl_bai}Windows 7                 ${gl_bufan}44. ${gl_bai}Windows Server 2025"
        echo -e "${gl_bufan}45. ${gl_bai}Windows Server 2022       ${gl_bufan}46. ${gl_bai}Windows Server 2019"
        echo -e "${gl_bufan}47. ${gl_bai}Windows 11 ARM"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请选择要重装的系统: " sys_choice
        case "$sys_choice" in

        1)
            dd_xitong_3
            bash reinstall.sh debian 13
            reboot
            exit
            ;;
        2)
            dd_xitong_1
            bash InstallNET.sh -debian 12
            reboot
            exit
            ;;
        3)
            dd_xitong_1
            bash InstallNET.sh -debian 11
            reboot
            exit
            ;;
        4)
            dd_xitong_1
            bash InstallNET.sh -debian 10
            reboot
            exit
            ;;
        11)
            dd_xitong_1
            bash InstallNET.sh -ubuntu 24.04
            reboot
            exit
            ;;
        12)
            dd_xitong_1
            bash InstallNET.sh -ubuntu 22.04
            reboot
            exit
            ;;
        13)
            dd_xitong_1
            bash InstallNET.sh -ubuntu 20.04
            reboot
            exit
            ;;
        14)
            dd_xitong_1
            bash InstallNET.sh -ubuntu 18.04
            reboot
            exit
            ;;
        21)
            dd_xitong_3
            bash reinstall.sh rocky
            reboot
            exit
            ;;
        22)
            dd_xitong_3
            bash reinstall.sh rocky 9
            reboot
            exit
            ;;
        23)
            dd_xitong_3
            bash reinstall.sh almalinux
            reboot
            exit
            ;;
        24)
            dd_xitong_3
            bash reinstall.sh almalinux 9
            reboot
            exit
            ;;
        25)
            dd_xitong_3
            bash reinstall.sh oracle
            reboot
            exit
            ;;
        26)
            dd_xitong_3
            bash reinstall.sh oracle 9
            reboot
            exit
            ;;
        27)
            dd_xitong_3
            bash reinstall.sh fedora
            reboot
            exit
            ;;
        28)
            dd_xitong_3
            bash reinstall.sh fedora 41
            reboot
            exit
            ;;
        29)
            dd_xitong_3
            bash reinstall.sh centos 10
            reboot
            exit
            ;;
        30)
            dd_xitong_3
            bash reinstall.sh centos 9
            reboot
            exit
            ;;
        31)
            dd_xitong_1
            bash InstallNET.sh -alpine
            reboot
            exit
            ;;
        32)
            dd_xitong_3
            bash reinstall.sh arch
            reboot
            exit
            ;;
        33)
            dd_xitong_3
            bash reinstall.sh kali
            reboot
            exit
            ;;
        34)
            dd_xitong_3
            bash reinstall.sh openeuler
            reboot
            exit
            ;;
        35)
            dd_xitong_3
            bash reinstall.sh opensuse
            reboot
            exit
            ;;
        36)
            dd_xitong_3
            bash reinstall.sh fnos
            reboot
            exit
            ;;
        41)
            dd_xitong_2
            bash InstallNET.sh -windows 11 -lang "cn"
            reboot
            exit
            ;;
        42)
            dd_xitong_2
            bash InstallNET.sh -windows 10 -lang "cn"
            reboot
            exit
            ;;
        43)
            dd_xitong_4
            bash reinstall.sh windows --iso="https://drive.massgrave.dev/cn_windows_7_professional_with_sp1_x64_dvd_u_677031.iso" --image-name='Windows 7 PROFESSIONAL'
            reboot
            exit
            ;;
        44)
            dd_xitong_2
            bash InstallNET.sh -windows 2025 -lang "cn"
            reboot
            exit
            ;;

        45)
            dd_xitong_2
            bash InstallNET.sh -windows 2022 -lang "cn"
            reboot
            exit
            ;;

        46)
            dd_xitong_2
            bash InstallNET.sh -windows 2019 -lang "cn"
            reboot
            exit
            ;;

        47)
            dd_xitong_4
            bash reinstall.sh dd --img https://r2.hotdog.eu.org/win11-arm-with-pagefile-15g.xz
            reboot
            exit
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

bbrv3() {
    root_use

    local cpu_arch=$(uname -m)
    if [ "$cpu_arch" = "aarch64" ]; then
        bash <(curl -sL jhb.ovh/jb/bbrv3arm.sh)
        break_end
        linux_Settings "$@"
    fi

    if dpkg -l | grep -q 'linux-xanmod'; then
        while true; do
            clear
            local kernel_version=$(uname -r)
            echo "您已安装xanmod的BBRv3内核"
            echo "当前内核版本: $kernel_version"

            echo ""
            echo "内核管理"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}更新BBRv3内核              ${gl_bufan}2. ${gl_bai}卸载BBRv3内核"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请输入你的选择: " sub_choice

            case $sub_choice in
            1)
                apt purge -y 'linux-*xanmod1*'
                update-grub

                # wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
                wget -qO - ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

                # 步骤3：添加存储库
                echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

                # version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
                local version=$(wget -q ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

                apt update -y
                apt install -y linux-xanmod-x64v"$version"

                echo "XanMod内核已更新。重启后生效"
                rm -f /etc/apt/sources.list.d/xanmod-release.list
                rm -f check_x86-64_psabi.sh*

                server_reboot
                ;;
            2)
                apt purge -y 'linux-*xanmod1*'
                update-grub
                echo "XanMod内核已卸载。重启后生效"
                server_reboot
                ;;
            0)
                break
                ;; # 立即终止整个循环，跳出循环体
            00 | 000 | 0000)
                exit_script
                ;; # 感谢使用，再见！ N 秒后自动退出
            *)
                handle_invalid_input
                ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
            esac
        done
    else

        clear
        echo "设置BBR3加速"
        echo "视频介绍: https://www.bilibili.com/video/BV14K421x7BS?t=0.1"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo "仅支持Debian/Ubuntu"
        echo "请备份数据，将为你升级Linux内核开启BBR3"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确定继续吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

        case "$choice" in
        [Yy])
            check_disk_space 3
            if [ -r /etc/os-release ]; then
                . /etc/os-release
                if [ "$ID" != "debian" ] && [ "$ID" != "ubuntu" ]; then
                    echo "当前环境不支持，仅支持Debian和Ubuntu系统"
                    break_end
                    linux_Settings "$@"
                fi
            else
                echo "无法确定操作系统类型"
                break_end
                linux_Settings "$@"
            fi

            check_swap
            install wget gnupg

            # wget -qO - https://dl.xanmod.org/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes
            wget -qO - ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/archive.key | gpg --dearmor -o /usr/share/keyrings/xanmod-archive-keyring.gpg --yes

            # 步骤3：添加存储库
            echo 'deb [signed-by=/usr/share/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org releases main' | tee /etc/apt/sources.list.d/xanmod-release.list

            # version=$(wget -q https://dl.xanmod.org/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')
            local version=$(wget -q ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/check_x86-64_psabi.sh && chmod +x check_x86-64_psabi.sh && ./check_x86-64_psabi.sh | grep -oP 'x86-64-v\K\d+|x86-64-v\d+')

            apt update -y
            apt install -y linux-xanmod-x64v"$version"

            bbr_on

            echo "XanMod内核安装并BBR3启用成功。重启后生效"
            rm -f /etc/apt/sources.list.d/xanmod-release.list
            rm -f check_x86-64_psabi.sh*
            server_reboot

            ;;
        [Nn])
            echo "已取消"
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
        esac
    fi
}

elrepo_install() {
    # 导入 ELRepo GPG 公钥
    echo "导入 ELRepo GPG 公钥..."
    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    # 检测系统版本
    local os_version=$(rpm -q --qf "%{VERSION}" $(rpm -qf /etc/os-release) 2>/dev/null | awk -F '.' '{print $1}')
    local os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
    # 确保我们在一个支持的操作系统上运行
    if [[ "$os_name" != *"Red Hat"* && "$os_name" != *"AlmaLinux"* && "$os_name" != *"Rocky"* && "$os_name" != *"Oracle"* && "$os_name" != *"CentOS"* ]]; then
        echo "不支持的操作系统：$os_name"
        break_end
        linux_Settings "$@"
    fi
    # 打印检测到的操作系统信息
    echo "检测到的操作系统: $os_name $os_version"
    # 根据系统版本安装对应的 ELRepo 仓库配置
    if [[ "$os_version" == 8 ]]; then
        echo "安装 ELRepo 仓库配置 (版本 8)..."
        yum -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
    elif [[ "$os_version" == 9 ]]; then
        echo "安装 ELRepo 仓库配置 (版本 9)..."
        yum -y install https://www.elrepo.org/elrepo-release-9.el9.elrepo.noarch.rpm
    elif [[ "$os_version" == 10 ]]; then
        echo "安装 ELRepo 仓库配置 (版本 10)..."
        yum -y install https://www.elrepo.org/elrepo-release-10.el10.elrepo.noarch.rpm
    else
        echo "不支持的系统版本：$os_version"
        break_end
        linux_Settings "$@"
    fi
    # 启用 ELRepo 内核仓库并安装最新的主线内核
    echo "启用 ELRepo 内核仓库并安装最新的主线内核..."
    # yum -y --enablerepo=elrepo-kernel install kernel-ml
    yum --nogpgcheck -y --enablerepo=elrepo-kernel install kernel-ml
    echo "已安装 ELRepo 仓库配置并更新到最新主线内核。"
    server_reboot

}

elrepo() {
    root_use
    #
    if uname -r | grep -q 'elrepo'; then
        while true; do
            clear
            kernel_version=$(uname -r)
            echo "您已安装elrepo内核"
            echo "当前内核版本: $kernel_version"

            echo ""
            echo -e "${gl_zi}>>> 内核管理${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}更新elrepo内核              ${gl_bufan}2. ${gl_bai}卸载elrepo内核"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请输入你的选择: " sub_choice

            case $sub_choice in
            1)
                dnf remove -y elrepo-release
                rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
                elrepo_install
                server_reboot
                ;;
            2)
                dnf remove -y elrepo-release
                rpm -qa | grep elrepo | grep kernel | xargs rpm -e --nodeps
                echo "elrepo内核已卸载。重启后生效"
                server_reboot
                ;;
            0)
                break
                ;; # 立即终止整个循环，跳出循环体
            00 | 000 | 0000)
                exit_script
                ;; # 感谢使用，再见！ N 秒后自动退出
            *)
                handle_invalid_input
                ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
            esac
        done
    else

        clear
        echo "请备份数据，将为你升级Linux内核"
        echo "视频介绍: https://www.bilibili.com/video/BV1mH4y1w7qA?t=529.2"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo "仅支持红帽系列发行版 CentOS/RedHat/Alma/Rocky/oracle "
        echo "升级Linux内核可提升系统性能和安全，建议有条件的尝试，生产环境谨慎升级！"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确定继续吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

        case "$choice" in
        [Yy])
            check_swap
            elrepo_install
            server_reboot
            ;;
        [Nn])
            echo "已取消"
            ;;
        *)
            echo "无效的选择，请输入 Y 或 N。"
            ;;
        esac
    fi
}

clamav_freshclam() {
    echo -e "${gl_huang}正在更新病毒库...${gl_bai}"
    docker run --rm \
        --name clamav \
        --mount source=clam_db,target=/var/lib/clamav \
        clamav/clamav-debian:latest \
        freshclam
}

clamav_scan() {
    if [ $# -eq 0 ]; then
        echo "请指定要扫描的目录。"
        return
    fi

    echo -e "${gl_huang}正在扫描目录$@... ${gl_bai}"

    # 构建 mount 参数
    local MOUNT_PARAMS=""
    for dir in "$@"; do
        MOUNT_PARAMS+="--mount type=bind,source=${dir},target=/mnt/host${dir} "
    done

    # 构建 clamscan 命令参数
    local SCAN_PARAMS=""
    for dir in "$@"; do
        SCAN_PARAMS+="/mnt/host${dir} "
    done

    mkdir -p /home/docker/clamav/log/ >/dev/null 2>&1
    >/home/docker/clamav/log/scan.log >/dev/null 2>&1

    # 执行 Docker 命令
    docker run -it --rm \
        --name clamav \
        --mount source=clam_db,target=/var/lib/clamav \
        "$MOUNT_PARAMS" \
        -v /home/docker/clamav/log/:/var/log/clamav/ \
        clamav/clamav-debian:latest \
        clamscan -r --log=/var/log/clamav/scan.log "$SCAN_PARAMS"

    echo -e "${gl_lv}$@ 扫描完成，病毒报告存放在${gl_huang}/home/docker/clamav/log/scan.log${gl_bai}"
    echo -e "${gl_lv}如果有病毒请在${gl_huang}scan.log${gl_lv}文件中搜索FOUND关键字确认病毒位置 ${gl_bai}"

}

clamav() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> clamav病毒扫描工具${gl_bai}"
        echo -e "${gl_bai}视频介绍: ${gl_lv}https://www.bilibili.com/video/BV1TqvZe4EQm?t=0.1"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo "是一个开源的防病毒软件工具，主要用于检测和删除各种类型的恶意软件。"
        echo "包括病毒、特洛伊木马、间谍软件、恶意脚本和其他有害软件。"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_lv}1. 全盘扫描 ${gl_bai}             ${gl_huang}2. 重要目录扫描 ${gl_bai}            ${gl_bufan} 3. 自定义目录扫描 ${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            install_docker
            docker volume create clam_db >/dev/null 2>&1
            clamav_freshclam
            clamav_scan /
            break_end
            ;;
        2)
            install_docker
            docker volume create clam_db >/dev/null 2>&1
            clamav_freshclam
            clamav_scan /etc /var /usr /home /root
            break_end
            ;;
        3)
            read -r -e -p "请输入要扫描的目录，用空格分隔（例如：/etc /var /usr /home /root）: " directories
            install_docker
            clamav_freshclam
            clamav_scan "$directories"
            break_end
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 高性能模式优化函数
optimize_high_performance() {
    echo -e "${gl_lv}切换到${tiaoyou_moshi}...${gl_bai}"

    echo -e "${gl_lv}优化文件描述符...${gl_bai}"
    ulimit -n 65535

    echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
    sysctl -w vm.swappiness=10 2>/dev/null
    sysctl -w vm.dirty_ratio=15 2>/dev/null
    sysctl -w vm.dirty_background_ratio=5 2>/dev/null
    sysctl -w vm.overcommit_memory=1 2>/dev/null
    sysctl -w vm.min_free_kbytes=65536 2>/dev/null

    echo -e "${gl_lv}优化网络设置...${gl_bai}"
    sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sysctl -w net.core.netdev_max_backlog=250000 2>/dev/null
    sysctl -w net.core.somaxconn=4096 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

    echo -e "${gl_lv}优化缓存管理...${gl_bai}"
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

    echo -e "${gl_lv}优化CPU设置...${gl_bai}"
    sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

    echo -e "${gl_lv}其他优化...${gl_bai}"
    # 禁用透明大页面，减少延迟
    echo never >/sys/kernel/mm/transparent_hugepage/enabled
    # 禁用 NUMA balancing
    sysctl -w kernel.numa_balancing=0 2>/dev/null

}

# 均衡模式优化函数
optimize_balanced() {
    echo -e "${gl_lv}切换到均衡模式...${gl_bai}"

    echo -e "${gl_lv}优化文件描述符...${gl_bai}"
    ulimit -n 32768

    echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
    sysctl -w vm.swappiness=30 2>/dev/null
    sysctl -w vm.dirty_ratio=20 2>/dev/null
    sysctl -w vm.dirty_background_ratio=10 2>/dev/null
    sysctl -w vm.overcommit_memory=0 2>/dev/null
    sysctl -w vm.min_free_kbytes=32768 2>/dev/null

    echo -e "${gl_lv}优化网络设置...${gl_bai}"
    sysctl -w net.core.rmem_max=8388608 2>/dev/null
    sysctl -w net.core.wmem_max=8388608 2>/dev/null
    sysctl -w net.core.netdev_max_backlog=125000 2>/dev/null
    sysctl -w net.core.somaxconn=2048 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem='4096 87380 8388608' 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem='4096 32768 8388608' 2>/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=4096 2>/dev/null
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
    sysctl -w net.ipv4.ip_local_port_range='1024 49151' 2>/dev/null

    echo -e "${gl_lv}优化缓存管理...${gl_bai}"
    sysctl -w vm.vfs_cache_pressure=75 2>/dev/null

    echo -e "${gl_lv}优化CPU设置...${gl_bai}"
    sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

    echo -e "${gl_lv}其他优化...${gl_bai}"
    # 还原透明大页面
    echo always >/sys/kernel/mm/transparent_hugepage/enabled
    # 还原 NUMA balancing
    sysctl -w kernel.numa_balancing=1 2>/dev/null

}

# 还原默认设置函数
restore_defaults() {
    echo -e "${gl_lv}还原到默认设置...${gl_bai}"

    echo -e "${gl_lv}还原文件描述符...${gl_bai}"
    ulimit -n 1024

    echo -e "${gl_lv}还原虚拟内存...${gl_bai}"
    sysctl -w vm.swappiness=60 2>/dev/null
    sysctl -w vm.dirty_ratio=20 2>/dev/null
    sysctl -w vm.dirty_background_ratio=10 2>/dev/null
    sysctl -w vm.overcommit_memory=0 2>/dev/null
    sysctl -w vm.min_free_kbytes=16384 2>/dev/null

    echo -e "${gl_lv}还原网络设置...${gl_bai}"
    sysctl -w net.core.rmem_max=212992 2>/dev/null
    sysctl -w net.core.wmem_max=212992 2>/dev/null
    sysctl -w net.core.netdev_max_backlog=1000 2>/dev/null
    sysctl -w net.core.somaxconn=128 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem='4096 87380 6291456' 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem='4096 16384 4194304' 2>/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=cubic 2>/dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=2048 2>/dev/null
    sysctl -w net.ipv4.tcp_tw_reuse=0 2>/dev/null
    sysctl -w net.ipv4.ip_local_port_range='32768 60999' 2>/dev/null

    echo -e "${gl_lv}还原缓存管理...${gl_bai}"
    sysctl -w vm.vfs_cache_pressure=100 2>/dev/null

    echo -e "${gl_lv}还原CPU设置...${gl_bai}"
    sysctl -w kernel.sched_autogroup_enabled=1 2>/dev/null

    echo -e "${gl_lv}还原其他优化...${gl_bai}"
    # 还原透明大页面
    echo always >/sys/kernel/mm/transparent_hugepage/enabled
    # 还原 NUMA balancing
    sysctl -w kernel.numa_balancing=1 2>/dev/null

}

# 网站搭建优化函数
optimize_web_server() {
    echo -e "${gl_lv}切换到网站搭建优化模式...${gl_bai}"

    echo -e "${gl_lv}优化文件描述符...${gl_bai}"
    ulimit -n 65535

    echo -e "${gl_lv}优化虚拟内存...${gl_bai}"
    sysctl -w vm.swappiness=10 2>/dev/null
    sysctl -w vm.dirty_ratio=20 2>/dev/null
    sysctl -w vm.dirty_background_ratio=10 2>/dev/null
    sysctl -w vm.overcommit_memory=1 2>/dev/null
    sysctl -w vm.min_free_kbytes=65536 2>/dev/null

    echo -e "${gl_lv}优化网络设置...${gl_bai}"
    sysctl -w net.core.rmem_max=16777216 2>/dev/null
    sysctl -w net.core.wmem_max=16777216 2>/dev/null
    sysctl -w net.core.netdev_max_backlog=5000 2>/dev/null
    sysctl -w net.core.somaxconn=4096 2>/dev/null
    sysctl -w net.ipv4.tcp_rmem='4096 87380 16777216' 2>/dev/null
    sysctl -w net.ipv4.tcp_wmem='4096 65536 16777216' 2>/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null
    sysctl -w net.ipv4.tcp_max_syn_backlog=8192 2>/dev/null
    sysctl -w net.ipv4.tcp_tw_reuse=1 2>/dev/null
    sysctl -w net.ipv4.ip_local_port_range='1024 65535' 2>/dev/null

    echo -e "${gl_lv}优化缓存管理...${gl_bai}"
    sysctl -w vm.vfs_cache_pressure=50 2>/dev/null

    echo -e "${gl_lv}优化CPU设置...${gl_bai}"
    sysctl -w kernel.sched_autogroup_enabled=0 2>/dev/null

    echo -e "${gl_lv}其他优化...${gl_bai}"
    # 禁用透明大页面，减少延迟
    echo never >/sys/kernel/mm/transparent_hugepage/enabled
    # 禁用 NUMA balancing
    sysctl -w kernel.numa_balancing=0 2>/dev/null

}

Kernel_optimize() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> Linux系统内核参数优化${gl_bai}"
        echo -e "${gl_bai}视频介绍: ${gl_lv}https://www.bilibili.com/video/BV1Kb421J7yg?t=0.1"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo "提供多种系统参数调优模式，用户可以根据自身使用场景进行选择切换。"
        echo -e "${gl_huang}提示: ${gl_bai}生产环境请谨慎使用！"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}高性能优化模式：     ${gl_huang}最大化系统性能，优化文件描述符、虚拟内存、网络设置、缓存管理和CPU设置。"
        echo -e "${gl_bufan}2. ${gl_bai}均衡优化模式：       ${gl_huang}在性能与资源消耗之间取得平衡，适合日常使用。"
        echo -e "${gl_bufan}3. ${gl_bai}网站优化模式：       ${gl_huang}针对网站服务器进行优化，提高并发连接处理能力、响应速度和整体性能。"
        echo -e "${gl_bufan}4. ${gl_bai}直播优化模式：       ${gl_huang}针对直播推流的特殊需求进行优化，减少延迟，提高传输性能。"
        echo -e "${gl_bufan}5. ${gl_bai}游戏服优化模式：     ${gl_huang}针对游戏服务器进行优化，提高并发处理能力和响应速度。"
        echo -e "${gl_bufan}6. ${gl_bai}还原默认设置：       ${gl_huang}将系统设置还原为默认配置。"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}0. 返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            cd ~
            clear
            local tiaoyou_moshi="高性能优化模式"
            optimize_high_performance
            ;;
        2)
            cd ~
            clear
            optimize_balanced
            ;;
        3)
            cd ~
            clear
            optimize_web_server
            ;;
        4)
            cd ~
            clear
            local tiaoyou_moshi="直播优化模式"
            optimize_high_performance
            ;;
        5)
            cd ~
            clear
            local tiaoyou_moshi="游戏服优化模式"
            optimize_high_performance
            ;;
        6)
            cd ~
            clear
            restore_defaults
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

update_locale() {
    local lang=$1
    local locale_file=$2

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
        debian | ubuntu | kali)
            install locales
            sed -i "s/^\s*#\?\s*${locale_file}/${locale_file}/" /etc/locale.gen
            locale-gen
            echo "LANG=${lang}" >/etc/default/locale
            export LANG=${lang}
            echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
            hash -r
            break_end

            ;;
        centos | rhel | almalinux | rocky | fedora)
            install glibc-langpack-zh
            localectl set-locale LANG="${lang}"
            echo "LANG=${lang}" | tee /etc/locale.conf
            echo -e "${gl_lv}系统语言已经修改为: $lang 重新连接SSH生效。${gl_bai}"
            hash -r
            break_end
            ;;
        *)
            echo "不支持的系统: $ID"
            break_end
            ;;
        esac
    else
        echo "不支持的系统，无法识别系统类型。"
        break_end
    fi
}

linux_language() {
    root_use
    ## "切换系统语言"
    while true; do
        clear
        echo "当前系统语言: $LANG"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}英文          ${gl_bufan}2. ${gl_bai}简体中文          ${gl_bufan}3. ${gl_bai}繁体中文"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice

        case $choice in
        1)
            update_locale "en_US.UTF-8" "en_US.UTF-8"
            ;;
        2)
            update_locale "zh_CN.UTF-8" "zh_CN.UTF-8"
            ;;
        3)
            update_locale "zh_TW.UTF-8" "zh_TW.UTF-8"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

shell_bianse_profile() {

    if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
        sed -i '/^PS1=/d' ~/.bashrc
        echo "${bianse}" >>~/.bashrc
    else
        sed -i '/^PS1=/d' ~/.profile
        echo "${bianse}" >>~/.profile
        # source ~/.profile
    fi
    echo -e "${gl_lv}变更完成。重新连接SSH后可查看变化！${gl_bai}"

    hash -r
    break_end

}

shell_bianse() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> 命令行美化工具${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. \033[1;32mroot \033[1;34mlocalhost \033[1;31m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}2. \033[1;35mroot \033[1;36mlocalhost \033[1;33m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}3. \033[1;31mroot \033[1;32mlocalhost \033[1;34m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}4. \033[1;36mroot \033[1;33mlocalhost \033[1;37m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}5. \033[1;37mroot \033[1;31mlocalhost \033[1;32m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}6. \033[1;33mroot \033[1;34mlocalhost \033[1;35m~ \033[0m${gl_bai}#"
        echo -e "${gl_bufan}7. ${gl_bai}root localhost ~ #"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice

        case $choice in
        1)
            local bianse="PS1='\[\033[1;32m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;31m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        2)
            local bianse="PS1='\[\033[1;35m\]\u\[\033[0m\]@\[\033[1;36m\]\h\[\033[0m\] \[\033[1;33m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        3)
            local bianse="PS1='\[\033[1;31m\]\u\[\033[0m\]@\[\033[1;32m\]\h\[\033[0m\] \[\033[1;34m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        4)
            local bianse="PS1='\[\033[1;36m\]\u\[\033[0m\]@\[\033[1;33m\]\h\[\033[0m\] \[\033[1;37m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        5)
            local bianse="PS1='\[\033[1;37m\]\u\[\033[0m\]@\[\033[1;31m\]\h\[\033[0m\] \[\033[1;32m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        6)
            local bianse="PS1='\[\033[1;33m\]\u\[\033[0m\]@\[\033[1;34m\]\h\[\033[0m\] \[\033[1;35m\]\w\[\033[0m\] # '"
            shell_bianse_profile
            ;;
        7)
            local bianse=""
            shell_bianse_profile
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

linux_trash() {
    root_use

    local bashrc_profile="/root/.bashrc"
    local TRASH_DIR="$HOME/.local/share/Trash/files"

    while true; do

        local trash_status
        if ! grep -q "trash-put" "$bashrc_profile"; then
            trash_status="${gl_hui}未启用${gl_bai}"
        else
            trash_status="${gl_lv}已启用${gl_bai}"
        fi

        clear
        echo -e "${gl_bufan}>>> 当前回收站 ${trash_status}"
        echo -e "启用后rm删除的文件先进入回收站，防止误删重要文件！"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        ls -l --color=auto "$TRASH_DIR" 2>/dev/null || echo "回收站为空"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}启用回收站          ${gl_bufan}2. ${gl_bai}关闭回收站"
        echo -e "${gl_bufan}3. ${gl_bai}还原内容            ${gl_bufan}4. ${gl_bai}清空回收站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "输入你的选择: " choice

        case $choice in
        1)
            install trash-cli
            sed -i '/alias rm/d' "$bashrc_profile"
            echo "alias rm='trash-put'" >>"$bashrc_profile"
            source "$bashrc_profile"
            echo "回收站已启用，删除的文件将移至回收站。"
            sleep 2
            ;;
        2)
            remove trash-cli
            sed -i '/alias rm/d' "$bashrc_profile"
            echo "alias rm='rm -i'" >>"$bashrc_profile"
            source "$bashrc_profile"
            echo "回收站已关闭，文件将直接删除。"
            sleep 2
            ;;
        3)
            read -r -e -p "输入要还原的文件名: " file_to_restore
            if [ -e "$TRASH_DIR/$file_to_restore" ]; then
                mv "$TRASH_DIR/$file_to_restore" "$HOME/"
                echo "$file_to_restore 已还原到主目录。"
            else
                echo "文件不存在。"
            fi
            ;;
        4)
            read -r -e -p "$(echo -e "${gl_bai}确认清空回收站？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            if [[ "$confirm" == "y" ]]; then
                trash-empty
                echo "回收站已清空。"
            fi
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

linux_fav() {
    ## "命令收藏夹"
    bash <(curl -l -s ${gh_proxy}raw.githubusercontent.com/byJoey/cmdbox/refs/heads/main/install.sh)
}

# 创建备份
create_backup() {
    local TIMESTAMP=$(date +"%Y%m%d%H%M%S")

    # 提示用户输入备份目录
    echo "创建备份示例："
    echo "  - 备份单个目录: /var/www"
    echo "  - 备份多个目录: /etc /home /var/log"
    echo "  - 直接回车将使用默认目录 (/etc /usr /home)"
    read -r -e -p "请输入要备份的目录（多个目录用空格分隔，直接回车则使用默认目录）：" input

    # 如果用户没有输入目录，则使用默认目录
    if [ -z "$input" ]; then
        BACKUP_PATHS=(
            "/etc"  # 配置文件和软件包配置
            "/usr"  # 已安装的软件文件
            "/home" # 用户数据
        )
    else
        # 将用户输入的目录按空格分隔成数组
        IFS=' ' read -r -r -a BACKUP_PATHS <<<"$input"
    fi

    # 生成备份文件前缀
    local PREFIX=""
    for path in "${BACKUP_PATHS[@]}"; do
        # 提取目录名称并去除斜杠
        dir_name=$(basename "$path")
        PREFIX+="${dir_name}_"
    done

    # 去除最后一个下划线
    local PREFIX=${PREFIX%_}

    # 生成备份文件名
    local BACKUP_NAME="${PREFIX}_$TIMESTAMP.tar.gz"

    # 打印用户选择的目录
    echo "您选择的备份目录为："
    for path in "${BACKUP_PATHS[@]}"; do
        echo "- $path"
    done

    # 创建备份
    echo "正在创建备份 $BACKUP_NAME..."
    install tar
    tar -czvf "$BACKUP_DIR/$BACKUP_NAME" "${BACKUP_PATHS[@]}"

    # 检查命令是否成功
    if cmd; then
        echo "备份创建成功: $BACKUP_DIR/$BACKUP_NAME"
    else
        echo "备份创建失败！"
        exit 1
    fi
}

# 恢复备份
restore_backup() {
    # 选择要恢复的备份
    read -r -e -p "请输入要恢复的备份文件名: " BACKUP_NAME

    # 检查备份文件是否存在
    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
        echo "备份文件不存在！"
        exit 1
    fi

    echo "正在恢复备份 $BACKUP_NAME..."
    tar -xzvf "$BACKUP_DIR/$BACKUP_NAME" -C /

    if cmd; then
        echo "备份恢复成功！"
    else
        echo "备份恢复失败！"
        exit 1
    fi
}

# 列出备份
list_backups() {
    echo "可用的备份："
    ls -1 "$BACKUP_DIR"
}

# 删除备份
delete_backup() {

    read -r -e -p "请输入要删除的备份文件名: " BACKUP_NAME

    # 检查备份文件是否存在
    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
        echo "备份文件不存在！"
        exit 1
    fi

    # 删除备份
    rm -f "$BACKUP_DIR/$BACKUP_NAME"

    if cmd; then
        echo "备份删除成功！"
    else
        echo "备份删除失败！"
        exit 1
    fi
}

# 备份主菜单
linux_backup() {
    BACKUP_DIR="/backups"
    mkdir -p "$BACKUP_DIR"
    while true; do
        clear
        echo -e "${gl_zi}>>> 系统备份功能${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        list_backups
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}创建备份        ${gl_bufan}2. ${gl_bai}恢复备份        ${gl_bufan}3. ${gl_bai}删除备份"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) create_backup ;;
        2) restore_backup ;;
        3) delete_backup ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 显示连接列表
list_connections() {
    echo "已保存的连接:"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    awk -F'|' '{print NR " - " $1 " (" $2 ")"}' "$CONFIG_FILE"
    echo -e "${gl_bufan}------------------------${gl_bai}"
}

# 添加新连接
add_connection() {
    echo "创建新连接示例："
    echo "  - 连接名称: my_server"
    echo "  - IP地址: 192.168.1.100"
    echo "  - 用户名: root"
    echo "  - 端口: 22"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    read -r -e -p "请输入连接名称: " name
    read -r -e -p "请输入IP地址: " ip
    read -r -e -p "请输入用户名 (默认: root): " user
    local user=${user:-root} # 如果用户未输入，则使用默认值 root
    read -r -e -p "请输入端口号 (默认: 22): " port
    local port=${port:-22} # 如果用户未输入，则使用默认值 22

    echo "请选择身份验证方式:"
    echo -e "${gl_bufan}1. ${gl_bai}密码"
    echo -e "${gl_bufan}2. ${gl_bai}密钥"
    read -r -e -p "请输入选择 (1/2): " auth_choice

    case $auth_choice in
    1)
        read -r -s -p "请输入密码: " password_or_key
        echo # 换行
        ;;
    2)
        echo "请粘贴密钥内容 (粘贴完成后按两次回车)："
        local password_or_key=""
        while IFS= read -r -r line; do
            # 如果输入为空行且密钥内容已经包含了开头，则结束输入
            if [[ -z "$line" && "$password_or_key" == *"-----BEGIN"* ]]; then
                break
            fi
            # 如果是第一行或已经开始输入密钥内容，则继续添加
            if [[ -n "$line" || "$password_or_key" == *"-----BEGIN"* ]]; then
                local password_or_key+="${line}"$'\n'
            fi
        done

        # 检查是否是密钥内容
        if [[ "$password_or_key" == *"-----BEGIN"* && "$password_or_key" == *"PRIVATE KEY-----"* ]]; then
            local key_file="$KEY_DIR/$name.key"
            echo -n "$password_or_key" >"$key_file"
            chmod 600 "$key_file"
            local password_or_key="$key_file"
        fi
        ;;
    *)
        echo "无效的选择！"
        return
        ;;
    esac

    echo "$name|$ip|$user|"$port"|$password_or_key" >>"$CONFIG_FILE"
    echo "连接已保存!"
}

# 删除连接
delete_connection() {
    read -r -e -p "请输入要删除的连接编号: " num

    local connection=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$connection" ]]; then
        echo "错误：未找到对应的连接。"
        return
    fi

    IFS='|' read -r -r name ip user port password_or_key <<<"$connection"

    # 如果连接使用的是密钥文件，则删除该密钥文件
    if [[ "$password_or_key" == "$KEY_DIR"* ]]; then
        rm -f "$password_or_key"
    fi

    sed -i "${num}d" "$CONFIG_FILE"
    echo "连接已删除!"
}

# 使用连接
use_connection() {
    read -r -e -p "请输入要使用的连接编号: " num

    local connection=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$connection" ]]; then
        echo "错误：未找到对应的连接。"
        return
    fi

    IFS='|' read -r -r name ip user port password_or_key <<<"$connection"

    echo "正在连接到 $name ($ip)..."
    if [[ -f "$password_or_key" ]]; then
        # 使用密钥连接
        ssh -o StrictHostKeyChecking=no -i "$password_or_key" -p ""$port"" "$user@$ip"
        if [[ $? -ne 0 ]]; then
            echo "连接失败！请检查以下内容："
            echo -e "${gl_bufan}1. ${gl_bai}密钥文件路径是否正确：$password_or_key"
            echo -e "${gl_bufan}2. ${gl_bai}密钥文件权限是否正确（应为 600）。"
            echo -e "${gl_bufan}3. ${gl_bai}目标服务器是否允许使用密钥登录。"
        fi
    else
        # 使用密码连接
        if ! command -v sshpass &>/dev/null; then
            echo "错误：未安装 sshpass，请先安装 sshpass。"
            echo "安装方法："
            echo "  - Ubuntu/Debian: apt install sshpass"
            echo "  - CentOS/RHEL: yum install sshpass"
            return
        fi
        sshpass -p "$password_or_key" ssh -o StrictHostKeyChecking=no -p ""$port"" "$user@$ip"
        if [[ $? -ne 0 ]]; then
            echo -e "${gl_bufan}连接失败！请检查以下内容：${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}用户名和密码是否正确。"
            echo -e "${gl_bufan}2. ${gl_bai}目标服务器是否允许密码登录。"
            echo -e "${gl_bufan}3. ${gl_bai}目标服务器的 SSH 服务是否正常运行。"
        fi
    fi
}

ssh_manager() {

    CONFIG_FILE="$HOME/.ssh_connections"
    KEY_DIR="$HOME/.ssh/ssh_manager_keys"

    # 检查配置文件和密钥目录是否存在，如果不存在则创建
    if [[ ! -f "$CONFIG_FILE" ]]; then
        touch "$CONFIG_FILE"
    fi

    if [[ ! -d "$KEY_DIR" ]]; then
        mkdir -p "$KEY_DIR"
        chmod 700 "$KEY_DIR"
    fi

    while true; do
        clear
        echo "SSH 远程连接工具"
        echo "可以通过SSH连接到其他Linux系统上"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        list_connections
        echo -e "${gl_bufan}1. ${gl_bai}创建新连接        ${gl_bufan}2. ${gl_bai}使用连接        ${gl_bufan}3. ${gl_bai}删除连接"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) add_connection ;;
        2) use_connection ;;
        3) delete_connection ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 列出可用的硬盘分区
list_partitions() {
    echo "可用的硬盘分区："
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep -v "sr\|loop"
}

# 挂载分区
mount_partition() {

    read -r -e -p "请输入要挂载的分区名称（例如 sda1）: " PARTITION

    # 检查分区是否存在
    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        echo "分区不存在！"
        return
    fi

    # 检查分区是否已经挂载
    if lsblk -o MOUNTPOINT | grep -w "$PARTITION" >/dev/null; then
        echo "分区已经挂载！"
        return
    fi

    # 创建挂载点
    MOUNT_POINT="/mnt/$PARTITION"
    mkdir -p "$MOUNT_POINT"

    # 挂载分区
    mount "/dev/$PARTITION" "$MOUNT_POINT"

    if cmd; then
        echo "分区挂载成功: $MOUNT_POINT"
    else
        echo "分区挂载失败！"
        rmdir "$MOUNT_POINT"
    fi
}

# 卸载分区
unmount_partition() {
    read -r -e -p "请输入要卸载的分区名称（例如 sda1）: " PARTITION

    # 检查分区是否已经挂载
    MOUNT_POINT=$(lsblk -o MOUNTPOINT | grep -w "$PARTITION")
    if [ -z "$MOUNT_POINT" ]; then
        echo "分区未挂载！"
        return
    fi

    # 卸载分区
    umount "/dev/$PARTITION"

    if cmd; then
        echo "分区卸载成功: $MOUNT_POINT"
        rmdir "$MOUNT_POINT"
    else
        echo "分区卸载失败！"
    fi
}

# 列出已挂载的分区
list_mounted_partitions() {
    echo "已挂载的分区："
    df -h | grep -v "tmpfs\|udev\|overlay"
}

# 格式化分区
format_partition() {
    read -r -e -p "请输入要格式化的分区名称（例如 sda1）: " PARTITION

    # 检查分区是否存在
    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        echo "分区不存在！"
        return
    fi

    # 检查分区是否已经挂载
    if lsblk -o MOUNTPOINT | grep -w "$PARTITION" >/dev/null; then
        echo "分区已经挂载，请先卸载！"
        return
    fi

    # 选择文件系统类型
    echo "请选择文件系统类型："
    echo -e "${gl_bufan}1. ${gl_bai}ext4"
    echo -e "${gl_bufan}2. ${gl_bai}xfs"
    echo -e "${gl_bufan}3. ${gl_bai}ntfs"
    echo -e "${gl_bufan}4. ${gl_bai}vfat"
    read -r -e -p "请输入你的选择: " FS_CHOICE

    case $FS_CHOICE in
    1) FS_TYPE="ext4" ;;
    2) FS_TYPE="xfs" ;;
    3) FS_TYPE="ntfs" ;;
    4) FS_TYPE="vfat" ;;
    *)
        echo "无效的选择！"
        return
        ;;
    esac

    # 确认格式化
    read -r -e -p "$(echo -e "${gl_bai}确认格式化分区 /dev/$PARTITION 为 $FS_TYPE 吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "操作已取消。"
        return
    fi

    # 格式化分区
    echo "正在格式化分区 /dev/$PARTITION 为 $FS_TYPE ..."
    mkfs.$FS_TYPE "/dev/$PARTITION"

    if cmd; then
        echo "分区格式化成功！"
    else
        echo "分区格式化失败！"
    fi
}

# 检查分区状态
check_partition() {
    read -r -e -p "请输入要检查的分区名称（例如 sda1）: " PARTITION

    # 检查分区是否存在
    if ! lsblk -o NAME | grep -w "$PARTITION" >/dev/null; then
        echo "分区不存在！"
        return
    fi

    # 检查分区状态
    echo "检查分区 /dev/$PARTITION 的状态："
    fsck "/dev/$PARTITION"
}

# 主菜单
disk_manager() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 硬盘分区管理${gl_bai}"
        echo -e "${gl_huang}该功能内部测试阶段，请勿在生产环境使用。${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        list_partitions
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}挂载分区        ${gl_bufan}2. ${gl_bai}卸载分区        ${gl_bufan}3. ${gl_bai}查看已挂载分区"
        echo -e "${gl_bufan}4. ${gl_bai}格式化分区      ${gl_bufan}5. ${gl_bai}检查分区状态"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) mount_partition ;;
        2) unmount_partition ;;
        3) list_mounted_partitions ;;
        4) format_partition ;;
        5) check_partition ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 显示任务列表
list_tasks() {
    echo "已保存的同步任务:"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    awk -F'|' '{print NR " - " $1 " ( " $2 " -> " $3":"$4 " )"}' "$CONFIG_FILE"
    echo -e "${gl_bufan}------------------------${gl_bai}"
}

# 添加新任务
add_task() {
    echo "创建新同步任务示例："
    echo "  - 任务名称: backup_www"
    echo "  - 本地目录: /var/www"
    echo "  - 远程地址: user@192.168.1.100"
    echo "  - 远程目录: /backup/www"
    echo "  - 端口号 (默认 22)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    read -r -e -p "请输入任务名称: " name
    read -r -e -p "请输入本地目录: " local_path
    read -r -e -p "请输入远程目录: " remote_path
    read -r -e -p "请输入远程用户@IP: " remote
    read -r -e -p "请输入 SSH 端口 (默认 22): " port
    port=${port:-22}

    echo "请选择身份验证方式:"
    echo -e "${gl_bufan}1. ${gl_bai}密码"
    echo -e "${gl_bufan}2. ${gl_bai}密钥"
    read -r -e -p "请选择 (1/2): " auth_choice

    case $auth_choice in
    1)
        read -r -s -p "请输入密码: " password_or_key
        echo # 换行
        auth_method="password"
        ;;
    2)
        echo "请粘贴密钥内容 (粘贴完成后按两次回车)："
        local password_or_key=""
        while IFS= read -r -r line; do
            # 如果输入为空行且密钥内容已经包含了开头，则结束输入
            if [[ -z "$line" && "$password_or_key" == *"-----BEGIN"* ]]; then
                break
            fi
            # 如果是第一行或已经开始输入密钥内容，则继续添加
            if [[ -n "$line" || "$password_or_key" == *"-----BEGIN"* ]]; then
                password_or_key+="${line}"$'\n'
            fi
        done

        # 检查是否是密钥内容
        if [[ "$password_or_key" == *"-----BEGIN"* && "$password_or_key" == *"PRIVATE KEY-----"* ]]; then
            local key_file="$KEY_DIR/${name}_sync.key"
            echo -n "$password_or_key" >"$key_file"
            chmod 600 "$key_file"
            password_or_key="$key_file"
            auth_method="key"
        else
            echo "无效的密钥内容！"
            return
        fi
        ;;
    *)
        echo "无效的选择！"
        return
        ;;
    esac

    echo "请选择同步模式:"
    echo -e "${gl_bufan}1. ${gl_bai}标准模式 (-avz)"
    echo -e "${gl_bufan}2. ${gl_bai}删除目标文件 (-avz --delete)"
    read -r -e -p "请选择 (1/2): " mode
    case $mode in
    1) options="-avz" ;;
    2) options="-avz --delete" ;;
    *)
        echo "无效选择，使用默认 -avz"
        options="-avz"
        ;;
    esac

    echo "$name|$local_path|$remote|$remote_path|"$port"|$options|$auth_method|$password_or_key" >>"$CONFIG_FILE"

    install rsync rsync

    echo "任务已保存!"
}

# 删除任务
delete_task() {
    read -r -e -p "请输入要删除的任务编号: " num

    local task=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$task" ]]; then
        echo "错误：未找到对应的任务。"
        return
    fi

    IFS='|' read -r -r name local_path remote remote_path port options auth_method password_or_key <<<"$task"

    # 如果任务使用的是密钥文件，则删除该密钥文件
    if [[ "$auth_method" == "key" && "$password_or_key" == "$KEY_DIR"* ]]; then
        rm -f "$password_or_key"
    fi

    sed -i "${num}d" "$CONFIG_FILE"
    echo "任务已删除!"
}

run_task() {

    CONFIG_FILE="$HOME/.rsync_tasks"
    CRON_FILE="$HOME/.rsync_cron"

    # 解析参数
    local direction="push" # 默认是推送到远端
    local num

    if [[ "$1" == "push" || "$1" == "pull" ]]; then
        direction="$1"
        num="$2"
    else
        num="$1"
    fi

    # 如果没有传入任务编号，提示用户输入
    if [[ -z "$num" ]]; then
        read -r -e -p "请输入要执行的任务编号: " num
    fi

    local task=$(sed -n "${num}p" "$CONFIG_FILE")
    if [[ -z "$task" ]]; then
        echo "错误: 未找到该任务!"
        return
    fi

    IFS='|' read -r -r name local_path remote remote_path port options auth_method password_or_key <<<"$task"

    # 根据同步方向调整源和目标路径
    if [[ "$direction" == "pull" ]]; then
        echo "正在拉取同步到本地: $remote:$local_path -> $remote_path"
        source="$remote:$local_path"
        destination="$remote_path"
    else
        echo "正在推送同步到远端: $local_path -> $remote:$remote_path"
        source="$local_path"
        destination="$remote:$remote_path"
    fi

    # 添加 SSH 连接通用参数
    local ssh_options="-p "$port" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    if [[ "$auth_method" == "password" ]]; then
        if ! command -v sshpass &>/dev/null; then
            echo "错误：未安装 sshpass，请先安装 sshpass。"
            echo "安装方法："
            echo "  - Ubuntu/Debian: apt install sshpass"
            echo "  - CentOS/RHEL: yum install sshpass"
            return
        fi
        sshpass -p "$password_or_key" rsync "$options" -e "ssh $ssh_options" "$source" "$destination"
    else
        # 检查密钥文件是否存在和权限是否正确
        if [[ ! -f "$password_or_key" ]]; then
            echo "错误：密钥文件不存在：$password_or_key"
            return
        fi

        if [[ "$(stat -c %a "$password_or_key")" != "600" ]]; then
            echo "警告：密钥文件权限不正确，正在修复..."
            chmod 600 "$password_or_key"
        fi

        rsync "$options" -e "ssh -i $password_or_key $ssh_options" "$source" "$destination"
    fi

    if [[ $? -eq 0 ]]; then
        echo "同步完成!"
    else
        echo "同步失败! 请检查以下内容："
        echo -e "${gl_bufan}1. ${gl_bai}网络连接是否正常"
        echo -e "${gl_bufan}2. ${gl_bai}远程主机是否可访问"
        echo -e "${gl_bufan}3. ${gl_bai}认证信息是否正确"
        echo -e "${gl_bufan}4. ${gl_bai}本地和远程目录是否有正确的访问权限"
    fi
}

# 创建定时任务
schedule_task() {

    read -r -e -p "请输入要定时同步的任务编号: " num
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误: 请输入有效的任务编号！"
        return
    fi

    echo "请选择定时执行间隔："
    echo -e "${gl_bufan}1. ${gl_bai}每小时执行一次"
    echo -e "${gl_bufan}2. ${gl_bai}每天执行一次"
    echo -e "${gl_bufan}3. ${gl_bai}每周执行一次"
    read -r -e -p "请输入选项 (1/2/3): " interval

    local random_minute
    random_minute=$(shuf -i 0-59 -n 1) # 生成 0-59 之间的随机分钟数
    local cron_time=""
    case "$interval" in
    1) cron_time="$random_minute * * * *" ;; # 每小时，随机分钟执行
    2) cron_time="$random_minute 0 * * *" ;; # 每天，随机分钟执行
    3) cron_time="$random_minute 0 * * 1" ;; # 每周，随机分钟执行
    *)
        echo "错误: 请输入有效的选项！"
        return
        ;;
    esac

    local cron_job="$cron_time k rsync_run $num"
    local cron_job="$cron_time k rsync_run $num"

    # 检查是否已存在相同任务
    if crontab -l | grep -q "k rsync_run $num"; then
        echo "错误: 该任务的定时同步已存在！"
        return
    fi

    # 创建到用户的 crontab
    (
        crontab -l 2>/dev/null
        echo "$cron_job"
    ) | crontab -
    echo "定时任务已创建: $cron_job"
}

# 查看定时任务
view_tasks() {
    echo "当前的定时任务:"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    crontab -l | grep "k rsync_run"
    echo -e "${gl_bufan}------------------------${gl_bai}"
}

# 删除定时任务
delete_task_schedule() {
    read -r -e -p "请输入要删除的任务编号: " num
    if ! [[ "$num" =~ ^[0-9]+$ ]]; then
        echo "错误: 请输入有效的任务编号！"
        return
    fi

    crontab -l | grep -v "k rsync_run $num" | crontab -
    echo "已删除任务编号 $num 的定时任务"
}

# 任务管理主菜单
rsync_manager() {
    CONFIG_FILE="$HOME/.rsync_tasks"
    CRON_FILE="$HOME/.rsync_cron"

    while true; do
        clear
        echo -e "${gl_zi}>>> Rsync 远程同步工具${gl_bai}"
        echo "远程目录之间同步，支持增量同步，高效稳定。"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        list_tasks
        echo
        view_tasks
        echo
        echo -e "${gl_bufan}1. ${gl_bai}创建新任务                 2. ${gl_bai}删除任务"
        echo -e "${gl_bufan}3. ${gl_bai}执行本地同步到远端         4. ${gl_bai}执行远端同步到本地"
        echo -e "${gl_bufan}5. ${gl_bai}创建定时任务               6. ${gl_bai}删除定时任务"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1) add_task ;;
        2) delete_task ;;
        3) run_task push ;;
        4) run_task pull ;;
        5) schedule_task ;;
        6) delete_task_schedule ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

###### 函数_系统信息
linux_info() {

    # 获取系统信息函数 - 只返回纯净数据
    get_local_ip() {
        ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | cut -d'/' -f1 | head -n1 || echo "无法获取"
    }

    get_cpu_usage() {
        top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{printf "%.2f%%", 100 - $8}' 2>/dev/null || echo "无法获取"
    }

    get_uptime() {
        uptime_seconds=$(awk '{print int($1)}' /proc/uptime 2>/dev/null)
        if [ -n "$uptime_seconds" ]; then
            days=$((uptime_seconds / 86400))
            hours=$(((uptime_seconds % 86400) / 3600))
            minutes=$(((uptime_seconds % 3600) / 60))
            if [ $days -gt 0 ]; then
                echo "${days}天${hours}时${minutes}分"
            else
                echo "${hours}时${minutes}分"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取默认网关
    get_default_gateway() {
        local gateway
        gateway=$(ip route show default 2>/dev/null | awk '/default/ {print $3}' | head -n1)
        if [ -n "$gateway" ]; then
            echo "$gateway"
        else
            echo "无法获取"
        fi
    }

    # 获取磁盘占用
    get_disk_usage() {
        local disk_info
        disk_info=$(df -h / 2>/dev/null | awk 'NR==2 {print $3"/"$2 " ("$5")"}')
        if [ -n "$disk_info" ]; then
            echo "$disk_info"
        else
            echo "无法获取"
        fi
    }

    # 获取操作系统信息
    get_os_info() {
        if [ -f /etc/os-release ]; then
            source /etc/os-release
            echo "$PRETTY_NAME"
        elif [ -f /etc/redhat-release ]; then
            cat /etc/redhat-release
        elif [ -f /etc/issue ]; then
            head -n1 /etc/issue | sed 's/\\n//g; s/\\l//g'
        else
            echo "未知系统"
        fi
    }

    # 获取内存使用情况
    get_memory_usage() {
        if command -v free >/dev/null 2>&1; then
            result=$(free -h 2>/dev/null | awk 'NR==2{printf "%.2fG/%.2fG (%.2f%%)", $3/1024, $2/1024, $3/$2*100}' 2>/dev/null)
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "无法获取"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取CPU型号
    get_cpu_model() {
        if [ -f /proc/cpuinfo ]; then
            model=$(grep -m1 "model name" /proc/cpuinfo | cut -d':' -f2 | sed 's/^[ \t]*//')
            if [ -n "$model" ]; then
                echo "$model" | head -c 40
            else
                echo "未知CPU"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取CPU核心数
    get_cpu_cores() {
        if [ -f /proc/cpuinfo ]; then
            physical_cores=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l 2>/dev/null)
            logical_cores=$(grep -c "processor" /proc/cpuinfo 2>/dev/null)
            if [ -n "$physical_cores" ] && [ -n "$logical_cores" ]; then
                echo "${physical_cores}物理/${logical_cores}逻辑"
            else
                echo "无法获取"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取系统负载
    get_system_load() {
        if [ -f /proc/loadavg ]; then
            load=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')
            if [ -n "$load" ]; then
                echo "$load"
            else
                echo "无法获取"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取网络算法信息（子网掩码）
    get_netmask() {
        local ip_route
        ip_route=$(ip -o -4 route show 2>/dev/null | head -n1)
        if [[ $ip_route =~ /([0-9]+) ]]; then
            cidr="${BASH_REMATCH[1]}"
            # 将CIDR转换为点分十进制子网掩码
            mask=$((0xffffffff << (32 - cidr) & 0xffffffff))
            echo "$(((mask >> 24) & 0xff)).$(((mask >> 16) & 0xff)).$(((mask >> 8) & 0xff)).$((mask & 0xff))"
        else
            # 备用方法
            result=$(ip -o -4 addr show 2>/dev/null | awk '/scope global/ {print $4}' | cut -d'/' -f2 | head -n1)
            if [ -n "$result" ]; then
                mask=$((0xffffffff << (32 - result) & 0xffffffff))
                echo "$(((mask >> 24) & 0xff)).$(((mask >> 16) & 0xff)).$(((mask >> 8) & 0xff)).$((mask & 0xff))"
            else
                echo "无法获取"
            fi
        fi
    }

    # 获取DNS服务器
    get_dns_servers() {
        if [ -f /etc/resolv.conf ]; then
            result=$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "无法获取"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取网络接口信息
    get_network_interfaces() {
        result=$(ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | head -n3 | tr '\n' ',' | sed 's/,$//')
        if [ -n "$result" ]; then
            echo "$result"
        else
            echo "无法获取"
        fi
    }

    # 获取网络连接状态
    get_network_connections() {
        local count=""
        if command -v ss >/dev/null 2>&1; then
            count=$(ss -tun state established 2>/dev/null | tail -n +2 | wc -l 2>/dev/null)
        elif command -v netstat >/dev/null 2>&1; then
            count=$(netstat -tun 2>/dev/null | grep ESTABLISHED | wc -l 2>/dev/null)
        fi

        if [ -n "$count" ] && [ "$count" -eq "$count" ] 2>/dev/null && [ "$count" -ge 0 ]; then
            echo "$count"
        else
            echo "无法获取"
        fi
    }

    # 获取TCP拥塞控制算法信息（特别关注BBR）
    get_tcp_congestion() {
        local current_congestion available_congestion bbr_status

        # 获取当前使用的拥塞控制算法
        if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
            current_congestion=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)
        else
            current_congestion="未知"
        fi

        # 检查是否可用BBR
        if [ -f /proc/sys/net/ipv4/tcp_available_congestion_control ]; then
            available_congestion=$(cat /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null)
            if echo "$available_congestion" | grep -q "bbr"; then
                bbr_status="可用"
            else
                bbr_status="不可用"
            fi
        else
            bbr_status="未知"
        fi

        # 检查BBR是否已启用
        if [ "$current_congestion" = "bbr" ]; then
            echo "BBR(已启用)"
        else
            # 如果当前不是BBR，但BBR可用，则显示当前算法和BBR状态
            if [ "$bbr_status" = "可用" ]; then
                echo "${current_congestion}(BBR可用)"
            else
                echo "${current_congestion}"
            fi
        fi
    }

    # 获取队列规则（特别关注fq）
    get_qdisc() {
        local default_qdisc
        if [ -f /proc/sys/net/core/default_qdisc ]; then
            default_qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null)
            if [ -n "$default_qdisc" ]; then
                echo "$default_qdisc"
            else
                echo "未知"
            fi
        else
            echo "未知"
        fi
    }

    # 检查BBR内核参数
    check_bbr_parameters() {
        local bbr_params=()

        # 检查BBR相关参数
        if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
            local current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null)
            [ "$current_cc" = "bbr" ] && bbr_params+=("tcp_congestion_control=bbr")
        fi

        if [ -f /proc/sys/net/core/default_qdisc ]; then
            local current_qdisc=$(cat /proc/sys/net/core/default_qdisc 2>/dev/null)
            [ "$current_qdisc" = "fq" ] && bbr_params+=("default_qdisc=fq")
        fi

        # 检查其他BBR相关参数
        if [ -f /proc/sys/net/ipv4/tcp_notsent_lowat ]; then
            local notsent_lowat=$(cat /proc/sys/net/ipv4/tcp_notsent_lowat 2>/dev/null)
            [ "$notsent_lowat" = "16384" ] && bbr_params+=("tcp_notsent_lowat=16384")
        fi

        if [ ${#bbr_params[@]} -gt 0 ]; then
            printf "%s" "${bbr_params[*]}" | tr ' ' ','
        else
            echo "无BBR参数"
        fi
    }

    # 获取当前用户
    get_current_user() {
        if command -v whoami >/dev/null 2>&1; then
            result=$(whoami 2>/dev/null)
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "未知用户"
            fi
        else
            echo "未知用户"
        fi
    }

    # 获取登录用户数
    get_logged_in_users() {
        if command -v who >/dev/null 2>&1; then
            users=$(who | wc -l 2>/dev/null)
            if [ -n "$users" ]; then
                echo "$users"
            else
                echo "0"
            fi
        else
            echo "未知"
        fi
    }

    # 获取进程数
    get_process_count() {
        if [ -d /proc ]; then
            count=$(ls -1 /proc | grep -E '^[0-9]+$' | wc -l 2>/dev/null)
            if [ -n "$count" ]; then
                echo "$count"
            else
                echo "无法获取"
            fi
        else
            echo "无法获取"
        fi
    }

    # 获取时区信息
    get_timezone() {
        if [ -f /etc/timezone ]; then
            result=$(cat /etc/timezone 2>/dev/null)
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "未知时区"
            fi
        elif command -v timedatectl >/dev/null 2>&1; then
            result=$(timedatectl status 2>/dev/null | grep "Time zone" | awk '{print $3}')
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "未知时区"
            fi
        else
            result=$(date +%Z 2>/dev/null)
            if [ -n "$result" ]; then
                echo "$result"
            else
                echo "未知时区"
            fi
        fi
    }

    # 获取当前时间
    get_current_time() {
        result=$(date "+%Y-%m-%d %H:%M:%S" 2>/dev/null)
        if [ -n "$result" ]; then
            echo "$result"
        else
            echo "无法获取"
        fi
    }

    # 辅助函数：根据结果决定颜色
    colorize_output() {
        local label="$1"
        local value="$2"
        if [ "$value" = "无法获取" ] || [ "$value" = "未知" ] || [ "$value" = "未知系统" ] || [ "$value" = "未知CPU" ] || [ "$value" = "未知用户" ] || [ "$value" = "未知时区" ]; then
            echo -e "${gl_bufan}${label} : ${gl_huang}${value}${gl_bai}"
        else
            echo -e "${gl_bufan}${label} : ${gl_bai}${value}"
        fi
    }

    # 系统信息
    echo -e "${gl_zi}>>> 系统信息${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "操作系统" "$(get_os_info)"
    colorize_output "主机名称" "$(hostname)"
    colorize_output "内核版本" "$(uname -r)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "CPU 架构" "$(uname -m)"
    colorize_output "CPU 型号" "$(get_cpu_model)"
    colorize_output "CPU 核心" "$(get_cpu_cores)"
    colorize_output "CPU 占用" "$(get_cpu_usage)"
    colorize_output "系统负载" "$(get_system_load)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "内存使用" "$(get_memory_usage)"
    colorize_output "磁盘占用" "$(get_disk_usage)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "网络接口" "$(get_network_interfaces)"
    colorize_output "IPv4地址" "$(get_local_ip)"
    colorize_output "子网掩码" "$(get_netmask)"
    colorize_output "默认网关" "$(get_default_gateway)"
    colorize_output "DNS 地址" "$(get_dns_servers)"
    colorize_output "网络算法" "$(get_tcp_congestion)"
    colorize_output "队列规则" "$(get_qdisc)"
    colorize_output "BBR 参数" "$(check_bbr_parameters)"
    colorize_output "连接数量" "$(get_network_connections)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "当前用户" "$(get_current_user)"
    colorize_output "登录用户" "$(get_logged_in_users)"
    colorize_output "进程数量" "$(get_process_count)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    colorize_output "运行时间" "$(get_uptime)"
    colorize_output "系统时区" "$(get_timezone)"
    colorize_output "当前时间" "$(get_current_time)"
    echo -e "${gl_bufan}------------------------${gl_bai}"
}

linux_tools() {

    while true; do
        clear
        echo -e "基础工具"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}1.  ${gl_bai}curl下载工具 ${gl_huang}★${gl_bai}       ${gl_bufan}2.   ${gl_bai}wget下载工具 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}sudo超级管理权限工具 ${gl_bufan}4.   ${gl_bai}socat通信连接工具"
        echo -e "${gl_bufan}5.  ${gl_bai}htop系统监控工具     ${gl_bufan}6.   ${gl_bai}iftop网络流量监控工具"
        echo -e "${gl_bufan}7.  ${gl_bai}unzipZIP压缩解压工具 ${gl_bufan}8.   ${gl_bai}tarGZ压缩解压工具"
        echo -e "${gl_bufan}9.  ${gl_bai}tmux多路后台运行工具 ${gl_bufan}10.  ${gl_bai}ffmpeg视频编码直播推流"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}11. ${gl_bai}btop现代化监控工具   ${gl_bufan}12.  ${gl_bai}ranger文件管理工具"
        echo -e "${gl_bufan}13. ${gl_bai}ncdu磁盘占用查看工具 ${gl_bufan}14.  ${gl_bai}fzf全局搜索工具"
        echo -e "${gl_bufan}15. ${gl_bai}vim文本编辑器        ${gl_bufan}16.  ${gl_bai}nano文本编辑器 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}17. ${gl_bai}git版本控制系统"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}21. ${gl_bai}黑客帝国屏保         ${gl_bufan}22.  ${gl_bai}跑火车屏保"
        echo -e "${gl_bufan}26. ${gl_bai}俄罗斯方块小游戏     ${gl_bufan}27.  ${gl_bai}贪吃蛇小游戏"
        echo -e "${gl_bufan}28. ${gl_bai}太空入侵者小游戏"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}31. ${gl_bai}全部安装             ${gl_bufan}32.  ${gl_bai}全部安装（不含屏保和游戏）${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}33. ${gl_bai}全部卸载"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}41. ${gl_bai}安装指定工具         ${gl_bufan}42.  ${gl_bai}卸载指定工具"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
            clear
            install curl
            clear
            echo "工具已安装，使用方法如下："
            curl --help
            ;;
        2)
            clear
            install wget
            clear
            echo "工具已安装，使用方法如下："
            wget --help
            ;;
        3)
            clear
            install sudo
            clear
            echo "工具已安装，使用方法如下："
            sudo --help
            ;;
        4)
            clear
            install socat
            clear
            echo "工具已安装，使用方法如下："
            socat -h
            ;;
        5)
            clear
            install htop
            clear
            htop
            ;;
        6)
            clear
            install iftop
            clear
            iftop
            ;;
        7)
            clear
            install unzip
            clear
            echo "工具已安装，使用方法如下："
            unzip
            ;;
        8)
            clear
            install tar
            clear
            echo "工具已安装，使用方法如下："
            tar --help
            ;;
        9)
            clear
            install tmux
            clear
            echo "工具已安装，使用方法如下："
            tmux --help
            ;;
        10)
            clear
            install ffmpeg
            clear
            echo "工具已安装，使用方法如下："
            ffmpeg --help
            ;;
        11)
            clear
            install btop
            clear
            btop
            ;;
        12)
            clear
            install ranger
            cd /
            clear
            ranger
            cd ~
            ;;
        13)
            clear
            install ncdu
            cd /
            clear
            ncdu
            cd ~
            ;;
        14)
            clear
            install fzf
            cd /
            clear
            fzf
            cd ~
            ;;
        15)
            clear
            install vim
            cd /
            clear
            vim -h
            cd ~
            ;;
        16)
            clear
            install nano
            cd /
            clear
            nano -h
            cd ~
            ;;
        17)
            clear
            install git
            cd /
            clear
            git --help
            cd ~
            ;;
        21)
            clear
            install cmatrix
            clear
            cmatrix
            ;;
        22)
            clear
            install sl
            clear
            sl
            ;;
        26)
            clear
            install bastet
            clear
            bastet
            ;;
        27)
            clear
            install nsnake
            clear
            nsnake
            ;;
        28)
            clear
            install ninvaders
            clear
            ninvaders
            ;;
        31)
            clear
            install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
            ;;
        32)
            clear
            install curl wget sudo socat htop iftop unzip tar tmux ffmpeg btop ranger ncdu fzf vim nano git
            ;;
        33)
            clear
            remove htop iftop tmux ffmpeg btop ranger ncdu fzf cmatrix sl bastet nsnake ninvaders vim nano git
            ;;

        41)
            clear
            read -r -e -p "请输入安装的工具名（wget curl sudo htop）: " installname
            install "$installname"
            ;;
        42)
            clear
            read -r -e -p "请输入卸载的工具名（htop ufw tmux cmatrix）: " removename
            remove "$removename"
            ;;
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        0) mobufan ;;
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

linux_bbr() {
    clear
    if [ -f "/etc/alpine-release" ]; then
        while true; do
            clear
            local congestion_algorithm=$(sysctl -n net.ipv4.tcp_congestion_control)
            local queue_algorithm=$(sysctl -n net.core.default_qdisc)
            echo "当前TCP阻塞算法: $congestion_algorithm $queue_algorithm"
            echo ""
            echo -e "${gl_zi}>>> BBR管理${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}开启BBRv3              ${gl_bufan}2. ${gl_bai}关闭BBRv3（会重启）"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请输入你的选择: " sub_choice

            case $sub_choice in
            1)
                bbr_on
                ;;
            2)
                sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf
                sysctl -p
                server_reboot
                ;;
            0) break ;; # 立即终止整个循环，跳出循环体
            00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
            *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
            esac
        done
    else
        install wget
        wget --no-check-certificate -O tcpx.sh ${gh_proxy}raw.githubusercontent.com/ylx2016/Linux-NetSpeed/master/tcpx.sh
        chmod +x tcpx.sh
        ./tcpx.sh
    fi
}

docker_ssh_migration() {
    is_compose_container() {
        local container=$1
        docker inspect "$container" | jq -e '.[0].Config.Labels["com.docker.compose.project"]' >/dev/null 2>&1
    }

    list_backups() {
        local BACKUP_ROOT="/tmp"
        echo -e "${gl_bufan}当前备份列表:${gl_bai}"
        ls -1dt ${BACKUP_ROOT}/docker_backup_* 2>/dev/null || echo "无备份"
    }

    # ----------------------------
    # 备份
    # ----------------------------
    backup_docker() {

        echo -e "${gl_bufan}正在备份 Docker 容器...${gl_bai}"
        docker ps --format '{{.Names}}'
        read -r -e -p "请输入要备份的容器名（多个空格分隔，回车备份全部运行中容器）: " containers

        install tar jq gzip
        install_docker

        local BACKUP_ROOT="/tmp"
        local DATE_STR=$(date +%Y%m%d_%H%M%S)
        local TARGET_CONTAINERS=()
        if [ -z "$containers" ]; then
            mapfile -t TARGET_CONTAINERS < <(docker ps --format '{{.Names}}')
        else
            read -r -ra TARGET_CONTAINERS <<<"$containers"
        fi
        [[ ${#TARGET_CONTAINERS[@]} -eq 0 ]] && {
            echo -e "${gl_huang}没有找到容器${gl_bai}"
            return
        }

        local BACKUP_DIR="${BACKUP_ROOT}/docker_backup_${DATE_STR}"
        mkdir -p "$BACKUP_DIR"

        local RESTORE_SCRIPT="${BACKUP_DIR}/docker_restore.sh"
        echo "#!/bin/bash" >"$RESTORE_SCRIPT"
        echo "set -e" >>"$RESTORE_SCRIPT"
        echo "# 自动生成的还原脚本" >>"$RESTORE_SCRIPT"

        # 记录已打包过的 Compose 项目路径，避免重复打包
        declare -A PACKED_COMPOSE_PATHS=()

        for c in "${TARGET_CONTAINERS[@]}"; do
            echo -e "${gl_lv}备份容器: $c${gl_bai}"
            local inspect_file="${BACKUP_DIR}/${c}_inspect.json"
            docker inspect "$c" >"$inspect_file"

            if is_compose_container "$c"; then
                echo -e "${gl_bufan}检测到 $c 是 docker-compose 容器${gl_bai}"
                local project_dir=$(docker inspect "$c" | jq -r '.[0].Config.Labels["com.docker.compose.project.working_dir"] // empty')
                local project_name=$(docker inspect "$c" | jq -r '.[0].Config.Labels["com.docker.compose.project"] // empty')

                if [ -z "$project_dir" ]; then
                    read -r -e -p "未检测到 compose 目录，请手动输入路径: " project_dir
                fi

                # 如果该 Compose 项目已经打包过，跳过
                if [[ -n "${PACKED_COMPOSE_PATHS[$project_dir]}" ]]; then
                    echo -e "${gl_bufan}Compose 项目 [$project_name] 已备份过，跳过重复打包...${gl_bai}"
                    return
                fi

                if [ -f "$project_dir/docker-compose.yml" ]; then
                    echo "compose" >"${BACKUP_DIR}/backup_type_${project_name}"
                    echo "$project_dir" >"${BACKUP_DIR}/compose_path_${project_name}.txt"
                    tar -czf "${BACKUP_DIR}/compose_project_${project_name}.tar.gz" -C "$project_dir" .
                    echo "# docker-compose 恢复: $project_name" >>"$RESTORE_SCRIPT"
                    echo "cd \"$project_dir\" && docker compose up -d" >>"$RESTORE_SCRIPT"
                    PACKED_COMPOSE_PATHS["$project_dir"]=1
                    echo -e "${gl_lv}Compose 项目 [$project_name] 已打包: ${project_dir}${gl_bai}"
                else
                    echo -e "${gl_huang}未找到 docker-compose.yml，跳过此容器...${gl_bai}"
                fi
            else
                # 普通容器备份卷
                local VOL_PATHS
                VOL_PATHS=$(docker inspect "$c" --format '{{range .Mounts}}{{.Source}} {{end}}')
                for path in $VOL_PATHS; do
                    echo "打包卷: $path"
                    tar -czpf "${BACKUP_DIR}/${c}_$(basename "$path").tar.gz" -C / "$(echo "$path" | sed 's/^\///')"
                done

                # 端口
                local PORT_ARGS=""
                mapfile -t PORTS < <(jq -r '.[0].HostConfig.PortBindings | to_entries[] | "\(.value[0].HostPort):\(.key | split("/")[0])"' "$inspect_file" 2>/dev/null)
                for p in "${PORTS[@]}"; do PORT_ARGS+="-p $p "; done

                # 环境变量
                local ENV_VARS=""
                mapfile -t ENVS < <(jq -r '.[0].Config.Env[] | @sh' "$inspect_file")
                for e in "${ENVS[@]}"; do ENV_VARS+="-e $e "; done

                # 卷映射
                local VOL_ARGS=""
                for path in $VOL_PATHS; do VOL_ARGS+="-v $path:$path "; done

                # 镜像
                local IMAGE
                IMAGE=$(jq -r '.[0].Config.Image' "$inspect_file")

                echo -e "\n# 还原容器: $c" >>"$RESTORE_SCRIPT"
                echo "docker run -d --name $c $PORT_ARGS $VOL_ARGS $ENV_VARS $IMAGE" >>"$RESTORE_SCRIPT"
            fi
        done

        # 备份 /home/docker 下的所有文件（不含子目录）
        if [ -d "/home/docker" ]; then
            echo -e "${gl_bufan}备份 /home/docker 下的文件...${gl_bai}"
            find /home/docker -maxdepth 1 -type f | tar -czf "${BACKUP_DIR}/home_docker_files.tar.gz" -T -
            echo -e "${gl_lv}/home/docker 下的文件已打包到: ${BACKUP_DIR}/home_docker_files.tar.gz${gl_bai}"
        fi

        chmod +x "$RESTORE_SCRIPT"
        echo -e "${gl_lv}备份完成: ${BACKUP_DIR}${gl_bai}"
        echo -e "${gl_lv}可用还原脚本: ${RESTORE_SCRIPT}${gl_bai}"

    }

    # ----------------------------
    # 还原
    # ----------------------------
    restore_docker() {

        read -r -e -p "请输入要还原的备份目录: " BACKUP_DIR
        [[ ! -d "$BACKUP_DIR" ]] && {
            echo -e "${gl_huang}备份目录不存在${gl_bai}"
            return
        }

        echo -e "${gl_bufan}开始执行还原操作...${gl_bai}"

        install tar jq gzip
        install_docker

        # --------- 优先还原 Compose 项目 ---------
        for f in "$BACKUP_DIR"/backup_type_*; do
            [[ ! -f "$f" ]] && continue
            if grep -q "compose" "$f"; then
                project_name=$(basename "$f" | sed 's/backup_type_//')
                path_file="$BACKUP_DIR/compose_path_${project_name}.txt"
                [[ -f "$path_file" ]] && original_path=$(cat "$path_file") || original_path=""
                [[ -z "$original_path" ]] && read -r -e -p "未找到原始路径，请输入还原目录路径: " original_path

                # 检查该 compose 项目的容器是否已经在运行
                running_count=$(docker ps --filter "label=com.docker.compose.project=$project_name" --format '{{.Names}}' | wc -l)
                if [[ "$running_count" -gt 0 ]]; then
                    echo -e "${gl_bufan}Compose 项目 [$project_name] 已有容器在运行，跳过还原...${gl_bai}"
                    return
                fi

                read -r -e -p "$(echo -e "${gl_bai}确认还原 Compose 项目 [$project_name] 到路径 [$original_path] ? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
                [[ "$confirm" != "y" ]] && read -r -e -p "请输入新的还原路径: " original_path

                mkdir -p "$original_path"
                tar -xzf "$BACKUP_DIR/compose_project_${project_name}.tar.gz" -C "$original_path"
                echo -e "${gl_lv}Compose 项目 [$project_name] 已解压到: $original_path${gl_bai}"

                cd "$original_path" || return
                docker compose down || true
                docker compose up -d
                echo -e "${gl_lv}Compose 项目 [$project_name] 还原完成！${gl_bai}"
            fi
        done

        # --------- 继续还原普通容器 ---------
        echo -e "${gl_bufan}检查并还原普通 Docker 容器...${gl_bai}"
        local has_container=false
        for json in "$BACKUP_DIR"/*_inspect.json; do
            [[ ! -f "$json" ]] && continue
            has_container=true
            container=$(basename "$json" | sed 's/_inspect.json//')
            echo -e "${gl_lv}处理容器: $container${gl_bai}"

            # 检查容器是否已经存在且正在运行
            if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
                echo -e "${gl_bufan}容器 [$container] 已在运行，跳过还原...${gl_bai}"
                return
            fi

            IMAGE=$(jq -r '.[0].Config.Image' "$json")
            [[ -z "$IMAGE" || "$IMAGE" == "null" ]] && {
                echo -e "${gl_huang}未找到镜像信息，跳过: $container${gl_bai}"
                return
            }

            # 端口映射
            PORT_ARGS=""
            mapfile -t PORTS < <(jq -r '.[0].HostConfig.PortBindings | to_entries[]? | "\(.value[0].HostPort):\(.key | split("/")[0])"' "$json")
            for p in "${PORTS[@]}"; do
                [[ -n "$p" ]] && PORT_ARGS="$PORT_ARGS -p $p"
            done

            # 环境变量
            ENV_ARGS=""
            mapfile -t ENVS < <(jq -r '.[0].Config.Env[]' "$json")
            for e in "${ENVS[@]}"; do
                ENV_ARGS="$ENV_ARGS -e \"$e\""
            done

            # 卷映射 + 卷数据恢复
            VOL_ARGS=""
            mapfile -t VOLS < <(jq -r '.[0].Mounts[] | "\(.Source):\(.Destination)"' "$json")
            for v in "${VOLS[@]}"; do
                VOL_SRC=$(echo "$v" | cut -d':' -f1)
                VOL_DST=$(echo "$v" | cut -d':' -f2)
                mkdir -p "$VOL_SRC"
                VOL_ARGS="$VOL_ARGS -v $VOL_SRC:$VOL_DST"

                VOL_FILE="$BACKUP_DIR/${container}_$(basename "$VOL_SRC").tar.gz"
                if [[ -f "$VOL_FILE" ]]; then
                    echo "恢复卷数据: $VOL_SRC"
                    tar -xzf "$VOL_FILE" -C /
                fi
            done

            # 删除已存在但未运行的容器
            if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
                echo -e "${gl_bufan}容器 [$container] 存在但未运行，删除旧容器...${gl_bai}"
                docker rm -f "$container"
            fi

            # 启动容器
            echo "执行还原命令: docker run -d --name \"$container\" $PORT_ARGS $VOL_ARGS $ENV_ARGS \"$IMAGE\""
            eval "docker run -d --name \"$container\" $PORT_ARGS $VOL_ARGS $ENV_ARGS \"$IMAGE\""
        done

        [[ "$has_container" == false ]] && echo -e "${gl_bufan}未找到普通容器的备份信息${gl_bai}"

        # 还原 /home/docker 下的文件
        if [ -f "$BACKUP_DIR/home_docker_files.tar.gz" ]; then
            echo -e "${gl_bufan}正在还原 /home/docker 下的文件...${gl_bai}"
            mkdir -p /home/docker
            tar -xzf "$BACKUP_DIR/home_docker_files.tar.gz" -C /
            echo -e "${gl_lv}/home/docker 下的文件已还原完成${gl_bai}"
        else
            echo -e "${gl_bufan}未找到 /home/docker 下文件的备份，跳过...${gl_bai}"
        fi

    }

    # ----------------------------
    # 迁移
    # ----------------------------
    migrate_docker() {
        #
        install jq
        read -r -e -p "请输入要迁移的备份目录: " BACKUP_DIR
        [[ ! -d "$BACKUP_DIR" ]] && {
            echo -e "${gl_huang}备份目录不存在${gl_bai}"
            return
        }

        read -r -e -p "目标服务器IP: " TARGET_IP
        read -r -e -p "目标服务器SSH用户名: " TARGET_USER
        read -r -e -p "目标服务器SSH端口 [默认22]: " TARGET_PORT
        local TARGET_PORT=${TARGET_PORT:-22}

        local LATEST_TAR="$BACKUP_DIR"

        echo -e "${gl_bufan}传输备份中...${gl_bai}"
        if [[ -z "$TARGET_PASS" ]]; then
            # 使用密钥登录
            scp -P "$TARGET_PORT" -o StrictHostKeyChecking=no -r "$LATEST_TAR" "$TARGET_USER@$TARGET_IP:/tmp/"
        fi

    }

    # ----------------------------
    # 删除备份
    # ----------------------------
    delete_backup() {
        #
        read -r -e -p "请输入要删除的备份目录: " BACKUP_DIR
        [[ ! -d "$BACKUP_DIR" ]] && {
            echo -e "${gl_huang}备份目录不存在${gl_bai}"
            return
        }
        rm -rf "$BACKUP_DIR"
        echo -e "${gl_lv}已删除备份: ${BACKUP_DIR}${gl_bai}"
    }

    # ----------------------------
    # 主菜单
    # ----------------------------
    main_menu() {
        #
        while true; do
            clear
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "Docker备份/迁移/还原工具"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            list_backups
            echo -e ""
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "1. 备份docker项目"
            echo -e "2. 迁移docker项目"
            echo -e "3. 还原docker项目"
            echo -e "4. 删除docker项目的备份文件"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "0. 返回上一级菜单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请选择: " choice
            case $choice in
            1) backup_docker ;;
            2) migrate_docker ;;
            3) restore_docker ;;
            4) delete_backup ;;
            00 | 000 | 0000)
                clear
                exit
                ;;
            0) return ;;
            *) echo -e "${gl_huang}无效选项${gl_bai}" ;;
            esac
            break_end
        done
    }

    main_menu
}

linux_docker() {
    while true; do
        clear
        echo -e "Docker管理"
        docker_tato
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}1.  ${gl_bai}安装更新Docker环境 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}2.  ${gl_bai}查看Docker全局状态 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}3.  ${gl_bai}Docker容器管理 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}4.  ${gl_bai}Docker镜像管理"
        echo -e "${gl_bufan}5.  ${gl_bai}Docker网络管理"
        echo -e "${gl_bufan}6.  ${gl_bai}Docker卷管理"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}7.  ${gl_bai}清理无用的docker容器和镜像网络数据卷"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}8.  ${gl_bai}更换Docker源"
        echo -e "${gl_bufan}9.  ${gl_bai}编辑daemon.json文件"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}11. ${gl_bai}开启Docker-ipv6访问"
        echo -e "${gl_bufan}12. ${gl_bai}关闭Docker-ipv6访问"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}19. ${gl_bai}备份/迁移/还原Docker环境"
        echo -e "${gl_bufan}20. ${gl_bai}卸载Docker环境"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            # 安装更新Docker环境
            clear
            install_add_docker
            ;;
        2)
            # Docker全局状态
            clear
            echo -e "${gl_zi}>>> Docker全局状态${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            local container_count image_count network_count volume_count
            container_count=$(docker ps -a -q 2>/dev/null | wc -l)
            image_count=$(docker images -q 2>/dev/null | wc -l)
            network_count=$(docker network ls -q 2>/dev/null | wc -l)
            volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

            echo "Docker版本"
            docker -v
            docker compose version
            echo ""
            echo -e "Docker镜像: ${gl_lv}$image_count${gl_bai} "
            docker image ls
            echo ""
            echo -e "Docker容器: ${gl_lv}$container_count${gl_bai}"
            docker ps -a
            echo ""
            echo -e "Docker卷: ${gl_lv}$volume_count${gl_bai}"
            docker volume ls
            echo ""
            echo -e "Docker网络: ${gl_lv}$network_count${gl_bai}"
            docker network ls
            echo ""
            echo -e "${gl_bufan}------------------------${gl_bai}"
            ;;
        3)
            docker_ps
            ;;
        4)
            docker_image
            ;;
        5)
            while true; do
                clear
                echo -e "${gl_bufan}Docker网络列表${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo ""
                docker network ls
                echo ""
                echo -e "${gl_bufan}------------------------${gl_bai}"
                container_ids=$(docker ps -q)
                printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

                for container_id in $container_ids; do
                    local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

                    local container_name=$(echo "$container_info" | awk '{print $1}')
                    local network_info=$(echo "$container_info" | cut -d' ' -f2-)

                    while IFS= read -r -r line; do
                        local network_name=$(echo "$line" | awk '{print $1}')
                        local ip_address=$(echo "$line" | awk '{print $2}')

                        printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
                    done <<<"$network_info"
                done

                echo ""
                echo -e "${gl_zi}>>> 网络操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bufan}创建网络"
                echo -e "${gl_bufan}2. ${gl_bufan}加入网络"
                echo -e "${gl_bufan}3. ${gl_bufan}退出网络"
                echo -e "${gl_bufan}4. ${gl_bufan}删除网络"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bufan}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    read -r -e -p "设置新网络名: " dockernetwork
                    docker network create "$dockernetwork"
                    ;;
                2)
                    read -r -e -p "加入网络名: " dockernetwork
                    read -r -e -p "那些容器加入该网络（多个容器名请用空格分隔）: " dockernames

                    for dockername in $dockernames; do
                        docker network connect "$dockernetwork" "$dockername"
                    done
                    ;;
                3)
                    read -r -e -p "退出网络名: " dockernetwork
                    read -r -e -p "那些容器退出该网络（多个容器名请用空格分隔）: " dockernames

                    for dockername in $dockernames; do
                        docker network disconnect "$dockernetwork" "$dockername"
                    done
                    ;;
                4)
                    read -r -e -p "请输入要删除的网络名: " dockernetwork
                    docker network rm "$dockernetwork"
                    ;;
                00 | 000 | 0000)
                    clear
                    exit
                    ;;
                0)
                    break # 跳出循环，退出菜单
                    ;;
                *)
                    echo -e "${gl_hong}无效的输入,请重新输入!"
                    sleep 2  # 暂停 2 秒，可以看到提示信息。
                    continue # 继续循环，不退出
                    ;;
                esac
            done
            ;;

        6)
            while true; do
                clear
                echo -e "${gl_bufan}Docker卷列表${gl_bai}"
                echo ""
                docker volume ls
                echo ""
                echo -e "${gl_zi}>>> 卷操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}创建新卷"
                echo -e "${gl_bufan}2. ${gl_bai}删除指定卷"
                echo -e "${gl_bufan}3. ${gl_bai}删除所有卷"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    read -r -e -p "设置新卷名: " dockerjuan
                    docker volume create "$dockerjuan"
                    ;;
                2)
                    read -r -e -p "输入删除卷名（多个卷名请用空格分隔）: " dockerjuans
                    for dockerjuan in $dockerjuans; do
                        docker volume rm "$dockerjuan"
                    done
                    ;;
                3)
                    read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有未使用的卷吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
                    case "$choice" in
                    [Yy])
                        docker volume prune -f
                        ;;
                    [Nn]) ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                    esac
                    ;;
                00 | 000 | 0000)
                    clear
                    exit
                    ;;
                0)
                    return 0 # 跳出循环，退出菜单
                    ;;
                *)
                    echo -e "${gl_hong}无效的输入,请重新输入!"
                    sleep 2  # 暂停 2 秒，可以看到提示信息。
                    continue # 继续循环，不退出
                    ;;
                esac
            done
            ;;
        7)
            clear
            read -r -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}将清理无用的镜像容器网络，包括停止的容器，确定清理吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                docker system prune -af --volumes
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        8)
            clear
            bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
            ;;
        9)
            clear
            install nano
            mkdir -p /etc/docker && nano /etc/docker/daemon.json
            restart docker
            ;;
        11)
            clear
            docker_ipv6_on
            ;;

        12)
            clear
            docker_ipv6_off
            ;;
        19)
            docker_ssh_migration
            ;;
        20)
            clear
            read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定卸载docker环境吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                docker ps -a -q | xargs -r docker rm -f && docker images -q | xargs -r docker rmi && docker network prune -f && docker volume prune -f
                remove docker docker-compose docker-ce docker-ce-cli containerd.io
                rm -f /etc/docker/daemon.json
                hash -r
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        00 | 000 | 0000)
            clear
            exit
            ;;
        0)
            mobufan
            ;;
        *)
            echo -e "${gl_hong}无效的输入,请重新输入!"
            sleep 2  # 暂停 2 秒，可以看到提示信息。
            continue # 继续循环，不退出
            ;;
        esac
    done
}

docker_tato() {

    local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
    local image_count=$(docker images -q 2>/dev/null | wc -l)
    local network_count=$(docker network ls -q 2>/dev/null | wc -l)
    local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

    if command -v docker &>/dev/null; then
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_lv}环境已经安装${gl_bai}  容器: ${gl_lv}$container_count${gl_bai}  镜像: ${gl_lv}$image_count${gl_bai}  网络: ${gl_lv}$network_count${gl_bai}  卷: ${gl_lv}$volume_count${gl_bai}"
    fi
}

ldnmp_tato() {
    # ------ ① 站点数 ------
    local conf_count=0
    [[ -d /etc/nginx/conf.d ]]       && conf_count=$(ls /etc/nginx/conf.d/*.conf 2>/dev/null | wc -l)
    [[ -d /etc/nginx/sites-enabled ]] && conf_count=$(( conf_count + $(ls /etc/nginx/sites-enabled/*.conf 2>/dev/null | wc -l) ))

    # ------ ② 数据库数 ------
    local db_count=0
    if command -v mysql &>/dev/null; then
        local dbrootpasswd=$(grep -oP 'password=\K.*' /root/.my.cnf 2>/dev/null)
        db_count=$(mysql -u root ${dbrootpasswd:+-p"$dbrootpasswd"} -e 'SHOW DATABASES;' 2>/dev/null |
                   grep -Ev 'Database|information_schema|mysql|performance_schema|sys' | wc -l)
    fi

    # ------ ③ 输出（完全沿用外部颜色变量） ------
    if systemctl is-active nginx >/dev/null 2>&1; then
        command printf '%b------------------------%b\n' "$gl_bufan" "$gl_bai" >&1
        command printf '%b环境：%b已安装%b  站点：%b%d%b  数据库：%b%d%b\n' \
               "$gl_bai" "$gl_lv" "$gl_bai" \
               "$gl_lv" "$conf_count" "$gl_bai" \
               "$gl_lv" "$db_count" "$gl_bai" >&1
    fi
}


fix_phpfpm_conf() {
    local container_name=$1
    docker exec "$container_name" sh -c "mkdir -p /run/$container_name && chmod 777 /run/$container_name"
    docker exec "$container_name" sh -c "sed -i '1i [global]\\ndaemonize = no' /usr/local/etc/php-fpm.d/www.conf"
    docker exec "$container_name" sh -c "sed -i '/^listen =/d' /usr/local/etc/php-fpm.d/www.conf"
    docker exec "$container_name" sh -c "echo -e '\nlisten = /run/$container_name/php-fpm.sock\nlisten.owner = www-data\nlisten.group = www-data\nlisten.mode = 0777' >> /usr/local/etc/php-fpm.d/www.conf"
    docker exec "$container_name" sh -c "rm -f /usr/local/etc/php-fpm.d/zz-docker.conf"

    find /etc/nginx/conf.d/ -type f -name "*.conf" -exec sed -i "s#fastcgi_pass ${container_name}:9000;#fastcgi_pass unix:/run/${container_name}/php-fpm.sock;#g" {} \;

}

linux_panel() {
    local sub_choice="$1"
    while true; do
        if [ -z "$sub_choice" ]; then
            clear
            echo -e "${gl_zi}>>> 应用市场${gl_bai}"
            echo -e "${gl_bufan}------------------------------------------------"

            local app_numbers=$([ -f /home/docker/appno.txt ] && cat /home/docker/appno.txt || echo "")

            # 用循环设置颜色
            for i in {1..150}; do
                if echo "$app_numbers" | grep -q "^$i$"; then
                    declare "color$i=${gl_lv}"
                else
                    declare "color$i=${gl_bai}"
                fi
            done

            echo -e "${gl_bufan}1.   ${color1}宝塔面板官方版           ${gl_bufan}2.   ${color2}aaPanel宝塔国际版"
            echo -e "${gl_bufan}3.   ${color3}1Panel新一代管理面板     ${gl_bufan}4.   ${color4}NginxProxyManager可视化面板"
            echo -e "${gl_bufan}5.   ${color5}OpenList多存储文件程序   ${gl_bufan}6.   ${color6}Ubuntu远程桌面网页版"
            echo -e "${gl_bufan}7.   ${color7}哪吒探针VPS监控面板      ${gl_bufan}8.   ${color8}QB离线BT磁力下载面板"
            echo -e "${gl_bufan}9.   ${color9}Poste.io邮件服务器程序   ${gl_bufan}10.  ${color10}RocketChat多人在线聊天系统"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}11.  ${color11}禅道项目管理软件         ${gl_bufan}12.  ${color12}青龙面板定时任务管理平台"
            echo -e "${gl_bufan}13.  ${color13}Cloudreve网盘 ${gl_huang}★${gl_bai}          ${gl_bufan}14.  ${color14}简单图床图片管理程序"
            echo -e "${gl_bufan}15.  ${color15}emby多媒体管理系统       ${gl_bufan}16.  ${color16}Speedtest测速面板"
            echo -e "${gl_bufan}17.  ${color17}AdGuardHome去广告软件    ${gl_bufan}18.  ${color18}onlyoffice在线办公OFFICE"
            echo -e "${gl_bufan}19.  ${color19}雷池WAF防火墙面板        ${gl_bufan}20.  ${color20}portainer容器管理面板"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}21.  ${color21}VScode网页版             ${gl_bufan}22.  ${color22}UptimeKuma监控工具"
            echo -e "${gl_bufan}23.  ${color23}Memos网页备忘录          ${gl_bufan}24.  ${color24}Webtop远程桌面网页版 ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}25.  ${color25}Nextcloud网盘            ${gl_bufan}26.  ${color26}QD-Today定时任务管理框架"
            echo -e "${gl_bufan}27.  ${color27}Dockge容器堆栈管理面板   ${gl_bufan}28.  ${color28}LibreSpeed测速工具"
            echo -e "${gl_bufan}29.  ${color29}searxng聚合搜索站 ${gl_huang}★${gl_bai}      ${gl_bufan}30.  ${color30}PhotoPrism私有相册系统"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}31.  ${color31}StirlingPDF工具大全      ${gl_bufan}32.  ${color32}drawio免费的在线图表软件 ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}33.  ${color33}Sun-Panel导航面板        ${gl_bufan}34.  ${color34}Pingvin-Share文件分享平台"
            echo -e "${gl_bufan}35.  ${color35}极简朋友圈               ${gl_bufan}36.  ${color36}LobeChatAI聊天聚合网站"
            echo -e "${gl_bufan}37.  ${color37}MyIP工具箱 ${gl_huang}★${gl_bai}             ${gl_bufan}38.  ${color38}小雅alist全家桶"
            echo -e "${gl_bufan}39.  ${color39}Bililive直播录制工具     ${gl_bufan}40.  ${color40}webssh网页版SSH连接工具"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}41.  ${color41}耗子管理面板             ${gl_bufan}42.  ${color42}Nexterm远程连接工具"
            echo -e "${gl_bufan}43.  ${color43}RustDesk远程桌面(服务端) ${gl_bufan}44.  ${color44}RustDesk远程桌面(中继端) ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}45.  ${color45}Docker加速站             ${gl_bufan}46.  ${color46}GitHub加速站 ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}47.  ${color47}普罗米修斯监控           ${gl_bufan}48.  ${color48}普罗米修斯(主机监控)"
            echo -e "${gl_bufan}49.  ${color49}普罗米修斯(容器监控)     ${gl_bufan}50.  ${color50}补货监控工具"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}51.  ${color51}PVE开小鸡面板	      ${gl_bufan}52.  ${color52}DPanel容器管理面板"
            echo -e "${gl_bufan}53.  ${color53}llama3聊天AI大模型       ${gl_bufan}54.  ${color54}AMH主机建站管理面板"
            echo -e "${gl_bufan}55.  ${color55}FRP内网穿透(服务端) ${gl_huang}★${gl_bai}    ${gl_bufan}56.  ${color56}FRP内网穿透(客户端) ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}57.  ${color57}Deepseek聊天AI大模型     ${gl_bufan}58.  ${color58}Dify大模型知识库 ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}59.  ${color59}NewAPI大模型资产管理     ${gl_bufan}60.  ${color60}JumpServer开源堡垒机"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}61.  ${color61}在线翻译服务器	      ${gl_bufan}62.  ${color62}RAGFlow大模型知识库"
            echo -e "${gl_bufan}63.  ${color63}OpenWebUI自托管AI平台 ${gl_huang}★${gl_bai}  ${gl_bufan}64.  ${color64}it-tools工具箱"
            echo -e "${gl_bufan}65.  ${color65}n8n自动化工作流平台 ${gl_huang}★${gl_bai}    ${gl_bufan}66.  ${color66}yt-dlp视频下载工具"
            echo -e "${gl_bufan}67.  ${color67}ddns-go动态DNS管理工具   ${gl_bufan}68.  ${color68}AllinSSL证书管理平台"
            echo -e "${gl_bufan}69.  ${color69}SFTPGo文件传输工具       ${gl_bufan}70.  ${color70}AstrBot聊天机器人框架"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}71.  ${color71}Navidrome私有音乐服务器  ${gl_bufan}72.  ${color72}bitwarden密码管理器 ${gl_huang}★${gl_bai}"
            echo -e "${gl_bufan}73.  ${color73}LibreTV私有影视          ${gl_bufan}74.  ${color74}MoonTV私有影视"
            echo -e "${gl_bufan}75.  ${color75}Melody音乐精灵           ${gl_bufan}76.  ${color76}在线DOS老游戏"
            echo -e "${gl_bufan}77.  ${color77}迅雷离线下载工具         ${gl_bufan}78.  ${color78}PandaWiki智能文档管理系统"
            echo -e "${gl_bufan}79.  ${color79}Beszel服务器监控         ${gl_bufan}80.  ${color80}linkwarden书签管理"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}81.  ${color81}JitsiMeet视频会议        ${gl_bufan}82.  ${color82}gpt-load高性能AI透明代理"
            echo -e "${gl_bufan}83.  ${color83}komari服务器监控工具     ${gl_bufan}84.  ${color84}Wallos个人财务管理工具"
            echo -e "${gl_bufan}85.  ${color85}immich图片视频管理器     ${gl_bufan}86.  ${color86}jellyfin媒体管理系统"
            echo -e "${gl_bufan}87.  ${color87}SyncTV一起看片神器       ${gl_bufan}88.  ${color88}Owncast自托管直播平台"
            echo -e "${gl_bufan}89.  ${color89}FileCodeBox文件快递      ${gl_bufan}90.  ${color90}matrix去中心化聊天协议"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}91.  ${color91}gitea私有代码仓库        ${gl_bufan}92.  ${color92}FileBrowser文件管理器"
            echo -e "${gl_bufan}93.  ${color93}Dufs极简静态文件服务器   ${gl_bufan}94.  ${color94}Gopeed高速下载工具"
            echo -e "${gl_bufan}95.  ${color95}paperless文档管理平台    ${gl_bufan}96.  ${color96}2FAuth自托管二步验证器"
            echo -e "${gl_bufan}97.  ${color97}WireGuard组网(服务端)    ${gl_bufan}98.  ${color98}WireGuard组网(客户端)"
            echo -e "${gl_bufan}99.  ${color99}DSM群晖虚拟机            ${gl_bufan}100. ${color100}Syncthing点对点文件同步工具"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}101. ${color101}AI视频生成工具           ${gl_bufan}102. ${color102}VoceChat多人在线聊天系统"
            echo -e "${gl_bufan}103. ${color103}Umami网站统计工具        ${gl_bufan}104. ${color104}Stream四层代理转发工具"
            echo -e "${gl_bufan}105. ${color105}思源笔记                 ${gl_bufan}106. ${color106}Drawnix开源白板工具"
            echo -e "${gl_bufan}107. ${color107}PanSou网盘搜索           ${gl_bufan}108. ${color108}LangBot聊天机器人"
            echo -e "${gl_bufan}109. ${color109}md云文档                 ${gl_bufan}110. ${color110}小爱音箱操控面板"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}111. ${color111}taosync网盘同步工具      ${gl_bufan}112. ${color112}musicn音乐下载工具"
            echo -e "${gl_bufan}113. ${color113}aipan网盘搜索工具        ${gl_bufan}114. ${color114}vert文件格式转换器"
            echo -e "${gl_bufan}115. ${color115}easynode网页SSH工具      ${gl_bufan}116. ${color116}mind-map思维导图"
            echo -e "${gl_bufan}117. ${color117}random随机壁纸           ${gl_bufan}118. ${color118}hd-Icons高清图标库"
            echo -e "${gl_bufan}119. ${color119}MeTube视频下载工具       ${gl_bufan}120. ${color120}fndesk飞牛桌面图标管理"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}b.  ${gl_bai}备份全部应用数据          ${gl_bufan}r.   ${gl_bai}还原全部应用数据"
            echo -e "${gl_bufan}------------------------------------------------"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请输入你的选择: " sub_choice
        fi

        case $sub_choice in
        1 | bt | baota)
            local app_id="1"
            local lujing='[ -d "/www/server/panel" ]'
            local panelname="宝塔面板"
            local panelurl="https://www.bt.cn/new/index.html"

            panel_app_install() {
                if [ -f /usr/bin/curl ]; then curl -sSO https://download.bt.cn/install/install_panel.sh; else wget -O install_panel.sh https://download.bt.cn/install/install_panel.sh; fi
                bash install_panel.sh ed8484bec
            }

            panel_app_manage() {
                bt
            }

            panel_app_uninstall() {
                curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh >/dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh
                chmod +x bt-uninstall.sh
                ./bt-uninstall.sh
            }
            install_panel
            ;;
        2 | aapanel)

            local app_id="2"
            local lujing='[ -d "/www/server/panel" ]'
            local panelname="aapanel"
            local panelurl="https://www.aapanel.com/new/index.html"

            panel_app_install() {
                URL=https://www.aapanel.com/script/install_7.0_en.sh && if [ -f /usr/bin/curl ]; then curl -ksSO "$URL"; else wget --no-check-certificate -O install_7.0_en.sh "$URL"; fi
                bash install_7.0_en.sh aapanel
            }

            panel_app_manage() {
                bt
            }

            panel_app_uninstall() {
                curl -o bt-uninstall.sh http://download.bt.cn/install/bt-uninstall.sh >/dev/null 2>&1 && chmod +x bt-uninstall.sh && ./bt-uninstall.sh
                chmod +x bt-uninstall.sh
                ./bt-uninstall.sh
            }
            install_panel
            ;;
        3 | 1p | 1panel)

            local app_id="3"
            local lujing="command -v 1pctl"
            local panelname="1Panel"
            local panelurl="https://1panel.cn/"

            panel_app_install() {
                install bash
                bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/v2/quick_start.sh)"
            }

            panel_app_manage() {
                1pctl user-info
                1pctl update password
            }

            panel_app_uninstall() {
                1pctl uninstall
            }
            install_panel
            ;;
        4 | npm)
            local app_id="4"
            local docker_name="npm"
            local docker_img="jc21/nginx-proxy-manager:latest"
            local docker_port=81

            docker_rum() {

                docker run -d \
                    --name="$docker_name" \
                    -p "${docker_port}":81 \
                    -p 80:80 \
                    -p 443:443 \
                    -v /home/docker/npm/data:/data \
                    -v /home/docker/npm/letsencrypt:/etc/letsencrypt \
                    --restart=always \
                    $docker_img

            }
            local docker_describe="一个Nginx反向代理工具面板，不支持添加域名访问。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://nginxproxymanager.com/${gl_bai}"
            local docker_use="echo \"初始用户名: admin@example.com\""
            local docker_passwd="echo \"初始密码: changeme\""
            local app_size="1"

            docker_app
            ;;
        5 | openlist)
            local app_id="5"
            local docker_name="openlist"
            local docker_img="openlistteam/openlist:latest-aria2"
            local docker_port=5244

            docker_rum() {

                mkdir -p /home/docker/openlist
                chmod -R 777 /home/docker/openlist

                docker run -d \
                    --restart=always \
                    -v /home/docker/openlist:/opt/openlist/data \
                    -p "${docker_port}":5244 \
                    -e PUID=0 \
                    -e PGID=0 \
                    -e UMASK=022 \
                    --name="openlist" \
                    openlistteam/openlist:latest-aria2

            }

            local docker_describe="一个支持多种存储，支持网页浏览和 WebDAV 的文件列表程序，由 gin 和 Solidjs 驱动"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/OpenListTeam/OpenList${gl_bai}"
            local docker_use="docker exec -it openlist ./openlist admin random"
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        6 | webtop-ubuntu)
            local app_id="6"
            local docker_name="webtop-ubuntu"
            local docker_img="lscr.io/linuxserver/webtop:ubuntu-kde"
            local docker_port=3006

            docker_rum() {

                read -r -e -p "设置登录用户名: " admin
                read -r -e -p "设置登录用户密码: " admin_password
                docker run -d \
                    --name=webtop-ubuntu \
                    --security-opt seccomp=unconfined \
                    -e PUID=1000 \
                    -e PGID=1000 \
                    -e TZ=Etc/UTC \
                    -e SUBFOLDER=/ \
                    -e TITLE=Webtop \
                    -e CUSTOM_USER="${admin}" \
                    -e PASSWORD="${admin_password}" \
                    -p "${docker_port}":3000 \
                    -v /home/docker/webtop/data:/config \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    --shm-size="1gb" \
                    --restart=always \
                    lscr.io/linuxserver/webtop:ubuntu-kde

            }

            local docker_describe="webtop基于Ubuntu的容器。若IP无法访问，请添加域名访问。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://docs.linuxserver.io/images/docker-webtop/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app
            ;;
        7 | nezha)
            clear

            local app_id="7"
            local docker_name="nezha-dashboard"
            local docker_port=8008
            while true; do
                check_docker_app
                check_docker_image_update "$docker_name"
                clear
                echo -e "哪吒监控 $check_docker $update_status"
                echo "开源、轻量、易用的服务器监控与运维工具"
                echo "官网搭建文档: https://nezha.wiki/guide/dashboard.html"
                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
                    local docker_port
                    local docker_port=$(docker port "$docker_name" | awk -F'[:]' '/->/ {print $NF}' | uniq)
                    check_docker_app_ip
                fi
                echo ""
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}使用"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "输入你的选择: " choice

                case $choice in
                1)
                    check_disk_space 1
                    install unzip jq
                    install_docker
                    curl -sL ${gh_proxy}raw.githubusercontent.com/nezhahq/scripts/refs/heads/main/install.sh -o nezha.sh && chmod +x nezha.sh && ./nezha.sh
                    local docker_port=$(docker port "$docker_name" | awk -F'[:]' '/->/ {print $NF}' | uniq)
                    check_docker_app_ip
                    ;;
                0) break ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
                *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
                break_end
            done
            ;;

        8 | qb | QB)

		local app_id="8"
		local docker_name="qbittorrent"
		local docker_img="lscr.io/linuxserver/qbittorrent:latest"
		local docker_port=8081

		docker_rum() {

			docker run -d \
			  --name=qbittorrent \
			  -e PUID=1000 \
			  -e PGID=1000 \
			  -e TZ=Etc/UTC \
			  -e WEBUI_PORT=${docker_port} \
			  -e TORRENTING_PORT=56881 \
			  -p ${docker_port}:${docker_port} \
			  -p 56881:56881 \
			  -p 56881:56881/udp \
			  -v /home/docker/qbittorrent/config:/config \
			  -v /home/docker/qbittorrent/downloads:/downloads \
			  --restart=always \
			  lscr.io/linuxserver/qbittorrent:latest

		}

		local docker_describe="qbittorrent离线BT磁力下载服务"
		local docker_url="${gl_bai}官网介绍: ${gl_lv} https://hub.docker.com/r/linuxserver/qbittorrent${gl_bai}"
		local docker_use="sleep 3"
		local docker_passwd="docker logs qbittorrent"
		local app_size="1"
		docker_app

		  ;;
        9 | mail)
            clear
            install telnet
            local app_id="9"
            local docker_name=“mailserver”
            while true; do
                check_docker_app
                check_docker_image_update "$docker_name"

                clear
                echo -e "邮局服务 $check_docker $update_status"
                echo "poste.io 是一个开源的邮件服务器解决方案，"
                echo "视频介绍: https://www.bilibili.com/video/BV1wv421C71t?t=0.1"

                echo ""
                echo "端口检测"
                port=25
                timeout=3
                if echo "quit" | timeout $timeout telnet smtp.qq.com "$port" | grep 'Connected'; then
                    echo -e "${gl_lv}端口 "$port" 当前可用${gl_bai}"
                else
                    echo -e "${gl_hong}端口 "$port" 当前不可用${gl_bai}"
                fi
                echo ""

                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
                    yuming=$(cat /home/docker/mail.txt)
                    echo "访问地址: "
                    echo "https://$yuming"
                fi

                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}安装           ${gl_bufan}2. ${gl_bai}更新           ${gl_bufan}3. ${gl_bai}卸载"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "输入你的选择: " choice

                case $choice in
                1)
                    setup_docker_dir
                    check_disk_space 2 /home/docker
                    read -r -e -p "请设置邮箱域名 例如 mail.yuming.com : " yuming
                    mkdir -p /home/docker
                    echo ""$yuming"" >/home/docker/mail.txt
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    ip_address
                    echo "先解析这些DNS记录"
                    echo "A           mail            $ipv4_address"
                    echo "CNAME       imap            "$yuming""
                    echo "CNAME       pop             "$yuming""
                    echo "CNAME       smtp            "$yuming""
                    echo "MX          @               "$yuming""
                    echo "TXT         @               v=spf1 mx ~all"
                    echo "TXT         ?               ?"
                    echo ""
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo "按任意键继续..."
                    read -r -n 1 -s -r -p ""

                    install jq
                    install_docker

                    docker run \
                        --net=host \
                        -e TZ=Europe/Prague \
                        -v /home/docker/mail:/data \
                        --name "mailserver" \
                        -h ""$yuming"" \
                        --restart=always \
                        -d analogic/poste.io

                    add_app_id

                    clear
                    echo "poste.io已经安装完成"
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo "您可以使用以下地址访问poste.io:"
                    echo "https://$yuming"
                    echo ""
                    ;;

                2)
                    docker rm -f mailserver
                    docker rmi -f analogic/poste.i
                    yuming=$(cat /home/docker/mail.txt)
                    docker run \
                        --net=host \
                        -e TZ=Europe/Prague \
                        -v /home/docker/mail:/data \
                        --name "mailserver" \
                        -h ""$yuming"" \
                        --restart=always \
                        -d analogic/poste.i

                    add_app_id

                    clear
                    echo "poste.io已经安装完成"
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo "您可以使用以下地址访问poste.io:"
                    echo "https://$yuming"
                    echo ""
                    ;;
                3)
                    docker rm -f mailserver
                    docker rmi -f analogic/poste.io
                    rm /home/docker/mail.txt
                    rm -rf /home/docker/mail

                    sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
                    echo "应用已卸载"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        10 | rocketchat)

            local app_id="10"
            local app_name="Rocket.Chat聊天系统"
            local app_text="Rocket.Chat 是一个开源的团队通讯平台，支持实时聊天、音视频通话、文件共享等多种功能，"
            local app_url="官方介绍: https://www.rocket.chat/"
            local docker_name="rocketchat"
            local docker_port="3897"
            local app_size="2"

            docker_app_install() {
                docker run --name db -d --restart=always \
                    -v /home/docker/mongo/dump:/dump \
                    mongo:latest --replSet rs5 --oplogSize 256
                sleep 1
                docker exec -it db mongosh --eval "printjson(rs.initiate())"
                sleep 5
                docker run --name rocketchat --restart=always -p "${docker_port}":3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat

                clear
                ip_address
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                docker rm -f rocketchat
                docker rmi -f rocket.chat:latest
                docker run --name rocketchat --restart=always -p "${docker_port}":3000 --link db --env ROOT_URL=http://localhost --env MONGO_OPLOG_URL=mongodb://db:27017/rs5 -d rocket.chat
                clear
                ip_address
                echo "rocket.chat已经安装完成"
                check_docker_app_ip
            }

            docker_app_uninstall() {
                docker rm -f rocketchat
                docker rmi -f rocket.chat
                docker rm -f db
                docker rmi -f mongo:latest
                rm -rf /home/docker/mongo
                echo "应用已卸载"
            }

            docker_app_plus
            ;;

        11 | zentao)
            local app_id="11"
            local docker_name="zentao-server"
            local docker_img="idoop/zentao:latest"
            local docker_port=82

            docker_rum() {

                docker run -d -p "${docker_port}":80 \
                    -e ADMINER_USER="root" -e ADMINER_PASSWD="password" \
                    -e BIND_ADDRESS="false" \
                    -v /home/docker/zentao-server/:/opt/zbox/ \
                    --add-host smtp.exmail.qq.com:163.177.90.125 \
                    --name zentao-server \
                    --restart=always \
                    idoop/zentao:latest

            }

            local docker_describe="禅道是通用的项目管理软件"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.zentao.net/${gl_bai}"
            local docker_use="echo \"初始用户名: admin\""
            local docker_passwd="echo \"初始密码: 123456\""
            local app_size="2"
            docker_app
            ;;
        12 | qinglong)
            local app_id="12"
            local docker_name="qinglong"
            local docker_img="whyour/qinglong:latest"
            local docker_port=5700

            docker_rum() {

                docker run -d \
                    -v /home/docker/qinglong/data:/ql/data \
                    -p "${docker_port}":5700 \
                    --name qinglong \
                    --hostname qinglong \
                    --restart=always \
                    whyour/qinglong:latest

            }

            local docker_describe="青龙面板是一个定时任务管理平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/whyour/qinglong${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        13 | cloudreve)

            local app_id="13"
            local app_name="cloudreve网盘"
            local app_text="cloudreve是一个支持多家云存储的网盘系统"
            local app_url="视频介绍: https://www.bilibili.com/video/BV13F4m1c7h7?t=0.1"
            local docker_name="cloudreve"
            local docker_port="5212"
            local app_size="2"

            docker_app_install() {
                cd /home/ && mkdir -p docker/cloud && cd docker/cloud && mkdir temp_data && mkdir -vp cloudreve/{uploads,avatar} && touch cloudreve/conf.ini && touch cloudreve/cloudreve.db && mkdir -p aria2/config && mkdir -p data/aria2 && chmod -R 777 data/aria2
                curl -o /home/docker/cloud/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/cloudreve-docker-compose.yml
                sed -i "s/5212:5212/${docker_port}:5212/g" /home/docker/cloud/docker-compose.yml
                cd /home/docker/cloud/
                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/cloud/ && docker compose down --rmi all
                cd /home/docker/cloud/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/cloud/ && docker compose down --rmi all
                rm -rf /home/docker/cloud
                echo "应用已卸载"
            }

            docker_app_plus
            ;;

        14 | easyimage)
            local app_id="14"
            local docker_name="easyimage"
            local docker_img="ddsderek/easyimage:latest"
            local docker_port=8014
            docker_rum() {

                docker run -d \
                    --name easyimage \
                    -p "${docker_port}":80 \
                    -e TZ=Asia/Shanghai \
                    -e PUID=1000 \
                    -e PGID=1000 \
                    -v /home/docker/easyimage/config:/app/web/config \
                    -v /home/docker/easyimage/i:/app/web/i \
                    --restart=always \
                    ddsderek/easyimage:latest

            }

            local docker_describe="简单图床是一个简单的图床程序"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/icret/EasyImages2.0${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        15 | emby)
            local app_id="15"
            local docker_name="emby"
            local docker_img="linuxserver/emby:latest"
            local docker_port=8015

            docker_rum() {

                docker run -d --name=emby --restart=always \
                    -v /home/docker/emby/config:/config \
                    -v /home/docker/emby/share1:/mnt/share1 \
                    -v /home/docker/emby/share2:/mnt/share2 \
                    -v /mnt/notify:/mnt/notify \
                    -p "${docker_port}":8096 \
                    -e UID=1000 -e GID=100 -e GIDLIST=100 \
                    linuxserver/emby:latest

            }

            local docker_describe="emby是一个主从式架构的媒体服务器软件，可以用来整理服务器上的视频和音频，并将音频和视频流式传输到客户端设备"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://emby.media/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        16 | looking)
            local app_id="16"
            local docker_name="looking-glass"
            local docker_img="wikihostinc/looking-glass-server"
            local docker_port=8016

            docker_rum() {

                docker run -d --name looking-glass --restart=always -p "${docker_port}":80 wikihostinc/looking-glass-server

            }

            local docker_describe="Speedtest测速面板是一个VPS网速测试工具，多项测试功能，还可以实时监控VPS进出站流量"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/wikihost-opensource/als${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;
        17 | adguardhome)

            local app_id="17"
            local docker_name="adguardhome"
            local docker_img="adguard/adguardhome"
            local docker_port=8017

            docker_rum() {

                docker run -d \
                    --name adguardhome \
                    -v /home/docker/adguardhome/work:/opt/adguardhome/work \
                    -v /home/docker/adguardhome/conf:/opt/adguardhome/conf \
                    -p 53:53/tcp \
                    -p 53:53/udp \
                    -p "${docker_port}":3000/tcp \
                    --restart=always \
                    adguard/adguardhome

            }

            local docker_describe="AdGuardHome是一款全网广告拦截与反跟踪软件，未来将不止是一个DNS服务器。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://hub.docker.com/r/adguard/adguardhome${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        18 | onlyoffice)

            local app_id="18"
            local docker_name="onlyoffice"
            local docker_img="onlyoffice/documentserver"
            local docker_port=8018

            docker_rum() {

                docker run -d -p "${docker_port}":80 \
                    --restart=always \
                    --name onlyoffice \
                    -v /home/docker/onlyoffice/DocumentServer/logs:/var/log/onlyoffice \
                    -v /home/docker/onlyoffice/DocumentServer/data:/var/www/onlyoffice/Data \
                    onlyoffice/documentserver

            }

            local docker_describe="onlyoffice是一款开源的在线office工具，太强大了！"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.onlyoffice.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app

            ;;

        19 | safeline)

            local app_id="19"
            local docker_name=safeline-mgt
            local docker_port=9443
            while true; do
                check_docker_app
                clear
                echo -e "${gl_zi}>>> 雷池服务 $check_docker${gl_bai}"
                echo "雷池是长亭科技开发的WAF站点防火墙程序面板，可以反代站点进行自动化防御"
                echo "视频介绍: https://www.bilibili.com/video/BV1mZ421T74c?t=0.1"
                if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "$docker_name"; then
                    check_docker_app_ip
                fi
                echo ""

                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}安装           ${gl_bufan}2. ${gl_bai}更新"
                echo -e "${gl_bufan}3. ${gl_bai}重置密码           ${gl_bufan}4. ${gl_bai}卸载"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "输入你的选择: " choice

                case $choice in
                1)
                    install_docker
                    check_disk_space 5
                    bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/setup.sh)"

                    add_app_id
                    clear
                    echo "雷池WAF面板已经安装完成"
                    check_docker_app_ip
                    docker exec safeline-mgt resetadmin

                    ;;

                2)
                    bash -c "$(curl -fsSLk https://waf-ce.chaitin.cn/release/latest/upgrade.sh)"
                    docker rmi "$(docker images | grep "safeline" | grep "none" | awk '{print $3}')"
                    echo ""

                    add_app_id
                    clear
                    echo "雷池WAF面板已经更新完成"
                    check_docker_app_ip
                    ;;
                3)
                    docker exec safeline-mgt resetadmin
                    ;;
                4)
                    cd /data/safeline
                    docker compose down --rmi all

                    sed -i "/\b${app_id}\b/d" /home/docker/appno.txt
                    echo "如果你是默认安装目录那现在项目已经卸载。如果你是自定义安装目录你需要到安装目录下自行执行:"
                    echo "docker compose down && docker compose down --rmi all"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
                break_end
            done
            ;;
        20 | portainer)
            local app_id="20"
            local docker_name="portainer"
            local docker_img="portainer/portainer"
            local docker_port=8020

            docker_rum() {

                docker run -d \
                    --name portainer \
                    -p "${docker_port}":9000 \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v /home/docker/portainer:/data \
                    --restart=always \
                    portainer/portainer

            }

            local docker_describe="portainer是一个轻量级的docker容器管理面板"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.portainer.io/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        21 | vscode)
            local app_id="21"
            local docker_name="vscode-web"
            local docker_img="codercom/code-server"
            local docker_port=8021

            docker_rum() {

                docker run -d -p "${docker_port}":8080 -v /home/docker/vscode-web:/home/coder/.local/share/code-server --name vscode-web --restart=always codercom/code-server

            }

            local docker_describe="VScode是一款强大的在线代码编写工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/coder/code-server${gl_bai}"
            local docker_use="sleep 3"
            local docker_passwd="docker exec vscode-web cat /home/coder/.config/code-server/config.yaml"
            local app_size="1"
            docker_app
            ;;
        22 | uptime-kuma)
            local app_id="22"
            local docker_name="uptime-kuma"
            local docker_img="louislam/uptime-kuma:latest"
            local docker_port=8022

            docker_rum() {

                docker run -d \
                    --name=uptime-kuma \
                    -p "${docker_port}":3001 \
                    -v /home/docker/uptime-kuma/uptime-kuma-data:/app/data \
                    --restart=always \
                    louislam/uptime-kuma:latest

            }

            local docker_describe="Uptime Kuma 易于使用的自托管监控工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/louislam/uptime-kuma${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        23 | memos)
            local app_id="23"
            local docker_name="memos"
            local docker_img="ghcr.io/usememos/memos:latest"
            local docker_port=8023

            docker_rum() {

                docker run -d --name memos -p "${docker_port}":5230 -v /home/docker/memos:/var/opt/memos --restart=always ghcr.io/usememos/memos:latest

            }

            local docker_describe="Memos是一款轻量级、自托管的备忘录中心"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/usememos/memos${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        24 | webtop)
            local app_id="24"
            local docker_name="webtop"
            local docker_img="lscr.io/linuxserver/webtop:latest"
            local docker_port=8024

            docker_rum() {

                read -r -e -p "设置登录用户名: " admin
                read -r -e -p "设置登录用户密码: " admin_password
                docker run -d \
                    --name=webtop \
                    --security-opt seccomp=unconfined \
                    -e PUID=1000 \
                    -e PGID=1000 \
                    -e TZ=Etc/UTC \
                    -e SUBFOLDER=/ \
                    -e TITLE=Webtop \
                    -e CUSTOM_USER="${admin}" \
                    -e PASSWORD="${admin_password}" \
                    -e LC_ALL=zh_CN.UTF-8 \
                    -e DOCKER_MODS=linuxserver/mods:universal-package-install \
                    -e INSTALL_PACKAGES=font-noto-cjk \
                    -p "${docker_port}":3000 \
                    -v /home/docker/webtop/data:/config \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    --shm-size="1gb" \
                    --restart=always \
                    lscr.io/linuxserver/webtop:latest

            }

            local docker_describe="webtop基于Alpine的中文版容器。若IP无法访问，请添加域名访问。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://docs.linuxserver.io/images/docker-webtop/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app
            ;;
        25 | nextcloud)
            local app_id="25"
            local docker_name="nextcloud"
            local docker_img="nextcloud:latest"
            local docker_port=8025
            local rootpasswd=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)

            docker_rum() {

                docker run -d --name nextcloud --restart=always -p "${docker_port}":80 -v /home/docker/nextcloud:/var/www/html -e NEXTCLOUD_ADMIN_USER=nextcloud -e NEXTCLOUD_ADMIN_PASSWORD="$rootpasswd" nextcloud

            }

            local docker_describe="Nextcloud拥有超过 400,000 个部署，是您可以下载的最受欢迎的本地内容协作平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://nextcloud.com/${gl_bai}"
            local docker_use="echo \"账号: nextcloud  密码: $rootpasswd\""
            local docker_passwd=""
            local app_size="3"
            docker_app
            ;;
        26 | qd)
            local app_id="26"
            local docker_name="qd"
            local docker_img="qdtoday/qd:latest"
            local docker_port=8026

            docker_rum() {

                docker run -d --name qd -p "${docker_port}":80 -v /home/docker/qd/config:/usr/src/app/config qdtoday/qd

            }

            local docker_describe="QD-Today是一个HTTP请求定时任务自动执行框架"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://qd-today.github.io/qd/zh_CN/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        27 | dockge)
            local app_id="27"
            local docker_name="dockge"
            local docker_img="louislam/dockge:latest"
            local docker_port=8027

            docker_rum() {

                docker run -d --name dockge --restart=always -p "${docker_port}":5001 -v /var/run/docker.sock:/var/run/docker.sock -v /home/docker/dockge/data:/app/data -v /home/docker/dockge/stacks:/home/docker/dockge/stacks -e DOCKGE_STACKS_DIR=/home/docker/dockge/stacks louislam/dockge

            }

            local docker_describe="dockge是一个可视化的docker-compose容器管理面板"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/louislam/dockge${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        28 | speedtest)
            local app_id="28"
            local docker_name="speedtest"
            local docker_img="ghcr.io/librespeed/speedtest"
            local docker_port=8028

            docker_rum() {

                docker run -d -p "${docker_port}":8080 --name speedtest --restart=always ghcr.io/librespeed/speedtest

            }

            local docker_describe="librespeed是用Javascript实现的轻量级速度测试工具，即开即用"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/librespeed/speedtest${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        29 | searxng)
            local app_id="29"
            local docker_name="searxng"
            local docker_img="searxng/searxng"
            local docker_port=8029

            docker_rum() {

                docker run -d \
                    --name searxng \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    -v "/home/docker/searxng:/etc/searxng" \
                    searxng/searxng

            }

            local docker_describe="searxng是一个私有且隐私的搜索引擎站点"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://hub.docker.com/r/alandoyle/searxng${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        30 | photoprism)
            local app_id="30"
            local docker_name="photoprism"
            local docker_img="photoprism/photoprism:latest"
            local docker_port=8030
            local rootpasswd=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)

            docker_rum() {

                docker run -d \
                    --name photoprism \
                    --restart=always \
                    --security-opt seccomp=unconfined \
                    --security-opt apparmor=unconfined \
                    -p "${docker_port}":2342 \
                    -e PHOTOPRISM_UPLOAD_NSFW="true" \
                    -e PHOTOPRISM_ADMIN_PASSWORD="$rootpasswd" \
                    -v /home/docker/photoprism/storage:/photoprism/storage \
                    -v /home/docker/photoprism/Pictures:/photoprism/originals \
                    photoprism/photoprism

            }

            local docker_describe="photoprism非常强大的私有相册系统"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.photoprism.app/${gl_bai}"
            local docker_use="echo \"账号: admin  密码: $rootpasswd\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        31 | s-pdf)
            local app_id="31"
            local docker_name="s-pdf"
            local docker_img="frooodle/s-pdf:latest"
            local docker_port=8031

            docker_rum() {

                docker run -d \
                    --name s-pdf \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    -v /home/docker/s-pdf/trainingData:/usr/share/tesseract-ocr/5/tessdata \
                    -v /home/docker/s-pdf/extraConfigs:/configs \
                    -v /home/docker/s-pdf/logs:/logs \
                    -e DOCKER_ENABLE_SECURITY=false \
                    frooodle/s-pdf:latest
            }

            local docker_describe="这是一个强大的本地托管基于 Web 的 PDF 操作工具，使用 docker，允许您对 PDF 文件执行各种操作，例如拆分合并、转换、重新组织、添加图像、旋转、压缩等。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/Stirling-Tools/Stirling-PDF${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        32 | drawio)
            local app_id="32"
            local docker_name="drawio"
            local docker_img="jgraph/drawio"
            local docker_port=8032

            docker_rum() {

                docker run -d --restart=always --name drawio -p "${docker_port}":8080 -v /home/docker/drawio:/var/lib/drawio jgraph/drawio

            }

            local docker_describe="这是一个强大图表绘制软件。思维导图，拓扑图，流程图，都能画"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.drawio.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        33 | sun-panel)
            local app_id="33"
            local docker_name="sun-panel"
            local docker_img="hslr/sun-panel"
            local docker_port=8033

            docker_rum() {
                docker run -d --restart=always -p "${docker_port}":3002 \
                    -v /home/docker/sun-panel/conf:/app/conf \
                    -v /home/docker/sun-panel/uploads:/app/uploads \
                    -v /home/docker/sun-panel/database:/app/database \
                    --name sun-panel \
                    hslr/sun-panel
            }

            local docker_describe="Sun-Panel服务器、NAS导航面板、Homepage、浏览器首页"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://doc.sun-panel.top/zh_cn/${gl_bai}"
            local docker_use="echo \"账号: admin@sun.cc  密码: 12345678\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        34 | pingvin-share)
            local app_id="34"
            local docker_name="pingvin-share"
            local docker_img="stonith404/pingvin-share"
            local docker_port=8034

            docker_rum() {
                docker run -d \
                    --name pingvin-share \
                    --restart=always \
                    -p "${docker_port}":3000 \
                    -v /home/docker/pingvin-share/data:/opt/app/backend/data \
                    stonith404/pingvin-share
            }

            local docker_describe="Pingvin Share 是一个可自建的文件分享平台，是 WeTransfer 的一个替代品"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/stonith404/pingvin-share${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        35 | moments)
            local app_id="35"
            local docker_name="moments"
            local docker_img="kingwrcy/moments:latest"
            local docker_port=8035

            docker_rum() {
                docker run -d --restart=always \
                    -p "${docker_port}":3000 \
                    -v /home/docker/moments/data:/app/data \
                    -v /etc/localtime:/etc/localtime:ro \
                    -v /etc/timezone:/etc/timezone:ro \
                    --name moments \
                    kingwrcy/moments:latest
            }

            local docker_describe="极简朋友圈，高仿微信朋友圈，记录你的美好生活"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/kingwrcy/moments?tab=readme-ov-file${gl_bai}"
            local docker_use="echo \"账号: admin  密码: a123456\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        36 | lobe-chat)
            local app_id="36"
            local docker_name="lobe-chat"
            local docker_img="lobehub/lobe-chat:latest"
            local docker_port=8036

            docker_rum() {
                docker run -d -p "${docker_port}":3210 \
                    --name lobe-chat \
                    --restart=always \
                    lobehub/lobe-chat
            }

            local docker_describe="LobeChat聚合市面上主流的AI大模型，ChatGPT/Claude/Gemini/Groq/Ollama"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/lobehub/lobe-chat${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app
            ;;
        37 | myip)
            local app_id="37"
            local docker_name="myip"
            local docker_img="jason5ng32/myip:latest"
            local docker_port=8037

            docker_rum() {
                docker run -d -p "${docker_port}":18966 --name myip jason5ng32/myip:latest
            }

            local docker_describe="是一个多功能IP工具箱，可以查看自己IP信息及连通性，用网页面板呈现"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/jason5ng32/MyIP/blob/main/README_ZH.md${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        38 | xiaoya)
            clear
            install_docker
            check_disk_space 1
            bash -c "$(curl --insecure -fsSL https://ddsrem.com/xiaoya_install.sh)"
            ;;

        39 | bililive)
            if [ ! -d /home/docker/bililive-go/ ]; then
                mkdir -p /home/docker/bililive-go/ >/dev/null 2>&1
                wget -O /home/docker/bililive-go/config.yml ${gh_proxy}raw.githubusercontent.com/hr3lxphr6j/bililive-go/master/config.yml >/dev/null 2>&1
            fi

            local app_id="39"
            local docker_name="bililive-go"
            local docker_img="chigusa/bililive-go"
            local docker_port=8039

            docker_rum() {
                docker run --restart=always --name bililive-go -v /home/docker/bililive-go/config.yml:/etc/bililive-go/config.yml -v /home/docker/bililive-go/Videos:/srv/bililive -p "${docker_port}":8080 -d chigusa/bililive-go
            }

            local docker_describe="Bililive-go是一个支持多种直播平台的直播录制工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/hr3lxphr6j/bililive-go${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        40 | webssh)
            local app_id="40"
            local docker_name="webssh"
            local docker_img="jrohy/webssh"
            local docker_port=8040
            docker_rum() {
                docker run -d -p "${docker_port}":5032 --restart=always --name webssh -e TZ=Asia/Shanghai jrohy/webssh
            }

            local docker_describe="简易在线ssh连接工具和sftp工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/Jrohy/webssh${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        41 | haozi)

            local app_id="41"
            local lujing='[ -d "/www/server/panel" ]'
            local panelname="耗子面板"
            local panelurl="官方地址: ${gh_proxy}github.com/TheTNB/panel"

            panel_app_install() {
                mkdir -p ~/haozi && cd ~/haozi && curl -fsLm 10 -o install.sh https://dl.cdn.haozi.net/panel/install.sh && bash install.sh
                cd ~
            }

            panel_app_manage() {
                panel-cli
            }

            panel_app_uninstall() {
                mkdir -p ~/haozi && cd ~/haozi && curl -fsLm 10 -o uninstall.sh https://dl.cdn.haozi.net/panel/uninstall.sh && bash uninstall.sh
                cd ~
            }

            install_panel
            ;;
        42 | nexterm)
            local app_id="42"
            local docker_name="nexterm"
            local docker_img="germannewsmaker/nexterm:latest"
            local docker_port=8042

            docker_rum() {
                ENCRYPTION_KEY=$(openssl rand -hex 32)
                docker run -d \
                    --name nexterm \
                    -e ENCRYPTION_KEY="${ENCRYPTION_KEY}" \
                    -p "${docker_port}":6989 \
                    -v /home/docker/nexterm:/app/data \
                    --restart=always \
                    germannewsmaker/nexterm:latest
            }

            local docker_describe="nexterm是一款强大的在线SSH/VNC/RDP连接工具。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/gnmyt/Nexterm${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        43 | hbbs)
            local app_id="43"
            local docker_name="hbbs"
            local docker_img="rustdesk/rustdesk-server"
            local docker_port=0000

            docker_rum() {
                docker run --name hbbs -v /home/docker/hbbs/data:/root -td --net=host --restart=always rustdesk/rustdesk-server hbbs
            }

            local docker_describe="rustdesk开源的远程桌面(服务端)，类似自己的向日葵私服。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://rustdesk.com/zh-cn/${gl_bai}"
            local docker_use="docker logs hbbs"
            local docker_passwd="echo \"把你的IP和key记录下，会在远程桌面客户端中用到。去44选项装中继端吧！\""
            local app_size="1"
            docker_app
            ;;
        44 | hbbr)
            local app_id="44"
            local docker_name="hbbr"
            local docker_img="rustdesk/rustdesk-server"
            local docker_port=0000

            docker_rum() {
                docker run --name hbbr -v /home/docker/hbbr/data:/root -td --net=host --restart=always rustdesk/rustdesk-server hbbr
            }

            local docker_describe="rustdesk开源的远程桌面(中继端)，类似自己的向日葵私服。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://rustdesk.com/zh-cn/${gl_bai}"
            local docker_use="echo \"前往官网下载远程桌面的客户端: https://rustdesk.com/zh-cn/\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        45 | registry)
            local app_id="45"
            local docker_name="registry"
            local docker_img="registry:2"
            local docker_port=8045

            docker_rum() {
                docker run -d \
                    -p "${docker_port}":5000 \
                    --name registry \
                    -v /home/docker/registry:/var/lib/registry \
                    -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
                    --restart=always \
                    registry:2
            }

            local docker_describe="Docker Registry 是一个用于存储和分发 Docker 镜像的服务。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://hub.docker.com/_/registry${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app
            ;;

        46 | ghproxy)
            local app_id="46"
            local docker_name="ghproxy"
            local docker_img="wjqserver/ghproxy:latest"
            local docker_port=8046

            docker_rum() {
                docker run -d --name ghproxy --restart=always -p "${docker_port}":8080 -v /home/docker/ghproxy/config:/data/ghproxy/config wjqserver/ghproxy:latest
            }

            local docker_describe="使用Go实现的GHProxy，用于加速部分地区Github仓库的拉取。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/WJQSERVER-STUDIO/ghproxy${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        47 | prometheus | grafana)

            local app_id="47"
            local app_name="普罗米修斯监控"
            local app_text="Prometheus+Grafana企业级监控系统"
            local app_url="官网介绍: https://prometheus.io"
            local docker_name="grafana"
            local docker_port="8047"
            local app_size="2"

            docker_app_install() {
                prometheus_install
                clear
                ip_address
                echo "已经安装完成"
                check_docker_app_ip
                echo "初始用户名密码均为: admin"
            }

            docker_app_update() {
                docker rm -f node-exporter prometheus grafana
                docker rmi -f prom/node-exporter
                docker rmi -f prom/prometheus:latest
                docker rmi -f grafana/grafana:latest
                docker_app_install
            }

            docker_app_uninstall() {
                docker rm -f node-exporter prometheus grafana
                docker rmi -f prom/node-exporter
                docker rmi -f prom/prometheus:latest
                docker rmi -f grafana/grafana:latest

                rm -rf /home/docker/monitoring
                echo "应用已卸载"
            }

            docker_app_plus
            ;;
        48 | node-exporter)
            local app_id="48"
            local docker_name="node-exporter"
            local docker_img="prom/node-exporter"
            local docker_port=8048

            docker_rum() {
                docker run -d \
                    --name=node-exporter \
                    -p "${docker_port}":9100 \
                    --restart=always \
                    prom/node-exporter
            }

            local docker_describe="这是一个普罗米修斯的主机数据采集组件，请部署在被监控主机上。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/prometheus/node_exporter${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        49 | cadvisor)
            local app_id="49"
            local docker_name="cadvisor"
            local docker_img="gcr.io/cadvisor/cadvisor:latest"
            local docker_port=8049

            docker_rum() {
                docker run -d \
                    --name=cadvisor \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    --volume=/:/rootfs:ro \
                    --volume=/var/run:/var/run:rw \
                    --volume=/sys:/sys:ro \
                    --volume=/var/lib/docker/:/var/lib/docker:ro \
                    gcr.io/cadvisor/cadvisor:latest \
                    -housekeeping_interval=10s \
                    -docker_only=true
            }

            local docker_describe="这是一个普罗米修斯的容器数据采集组件，请部署在被监控主机上。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/google/cadvisor${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        50 | changedetection)
            local app_id="50"
            local docker_name="changedetection"
            local docker_img="dgtlmoon/changedetection.io:latest"
            local docker_port=8050

            docker_rum() {
                docker run -d --restart=always -p "${docker_port}":5000 \
                    -v /home/docker/datastore:/datastore \
                    --name changedetection dgtlmoon/changedetection.io:latest
            }

            local docker_describe="这是一款网站变化检测、补货监控和通知的小工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/dgtlmoon/changedetection.io${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        51 | pve)
            clear
            check_disk_space 1
            curl -L ${gh_proxy}raw.githubusercontent.com/oneclickvirt/pve/main/scripts/install_pve.sh -o install_pve.sh && chmod +x install_pve.sh && bash install_pve.sh
            ;;

        52 | dpanel)
            local app_id="52"
            local docker_name="dpanel"
            local docker_img="dpanel/dpanel:lite"
            local docker_port=8052

            docker_rum() {
                docker run -it -d --name dpanel --restart=always \
                    -p "${docker_port}":8080 -e APP_NAME=dpanel \
                    -v /var/run/docker.sock:/var/run/docker.sock \
                    -v /home/docker/dpanel:/dpanel \
                    dpanel/dpanel:lite
            }

            local docker_describe="Docker可视化面板系统，提供完善的docker管理功能。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/donknap/dpanel${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        53 | llama3)
            local app_id="53"
            local docker_name="ollama"
            local docker_img="ghcr.io/open-webui/open-webui:ollama"
            local docker_port=8053

            docker_rum() {
                docker run -d -p "${docker_port}":8080 -v /home/docker/ollama:/root/.ollama -v /home/docker/ollama/open-webui:/app/backend/data --name ollama --restart=always ghcr.io/open-webui/open-webui:ollama
            }

            local docker_describe="OpenWebUI一款大语言模型网页框架，接入全新的llama3大语言模型"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/open-webui/open-webui${gl_bai}"
            local docker_use="docker exec ollama ollama run llama3.2:1b"
            local docker_passwd=""
            local app_size="5"
            docker_app
            ;;

        54 | amh)
            local app_id="54"
            local lujing='[ -d "/www/server/panel" ]'
            local panelname="AMH面板"
            local panelurl="官方地址: https://amh.sh/index.htm?amh"

            panel_app_install() {
                cd ~
                wget https://dl.amh.sh/amh.sh && bash amh.sh
            }

            panel_app_manage() {
                panel_app_install
            }

            panel_app_uninstall() {
                panel_app_install
            }

            install_panel
            ;;

        55 | frps)
            frps_panel
            ;;

        56 | frpc)
            frpc_panel
            ;;

        57 | deepseek)
            local app_id="57"
            local docker_name="ollama"
            local docker_img="ghcr.io/open-webui/open-webui:ollama"
            local docker_port=8053

            docker_rum() {
                docker run -d -p "${docker_port}":8080 -v /home/docker/ollama:/root/.ollama -v /home/docker/ollama/open-webui:/app/backend/data --name ollama --restart=always ghcr.io/open-webui/open-webui:ollama
            }

            local docker_describe="OpenWebUI一款大语言模型网页框架，接入全新的DeepSeek R1大语言模型"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/open-webui/open-webui${gl_bai}"
            local docker_use="docker exec ollama ollama run deepseek-r1:1.5b"
            local docker_passwd=""
            local app_size="5"
            docker_app
            ;;

        58 | dify)
            local app_id="58"
            local app_name="Dify知识库"
            local app_text="是一款开源的大语言模型(LLM) 应用开发平台。自托管训练数据用于AI生成"
            local app_url="官方网站: https://docs.dify.ai/zh-hans"
            local docker_name="docker-nginx-1"
            local docker_port="8058"
            local app_size="3"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/langgenius/dify.git && cd dify/docker && cp .env.example .env
                # sed -i 's/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=${docker_port}/; s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8858/' /home/docker/dify/docker/.env
                sed -i "s/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=${docker_port}/; s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8858/" /home/docker/dify/docker/.env

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/dify/docker/ && docker compose down --rmi all
                cd /home/docker/dify/
                git pull origin main
                sed -i 's/^EXPOSE_NGINX_PORT=.*/EXPOSE_NGINX_PORT=8058/; s/^EXPOSE_NGINX_SSL_PORT=.*/EXPOSE_NGINX_SSL_PORT=8858/' /home/docker/dify/docker/.env
                cd /home/docker/dify/docker/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/dify/docker/ && docker compose down --rmi all
                rm -rf /home/docker/dify
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        59 | new-api)
            local app_id="59"
            local app_name="NewAPI"
            local app_text="新一代大模型网关与AI资产管理系统"
            local app_url="官方网站: https://github.com/Calcium-Ion/new-api"
            local docker_name="new-api"
            local docker_port="8059"
            local app_size="3"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/Calcium-Ion/new-api.git && cd new-api

                sed -i -e "s/- \"3000:3000\"/- \"${docker_port}:3000\"/g" \
                    -e 's/container_name: redis/container_name: redis-new-api/g' \
                    -e 's/container_name: mysql/container_name: mysql-new-api/g' \
                    docker-compose.yml

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/new-api/ && docker compose down --rmi all
                cd /home/docker/new-api/
                git pull origin main
                sed -i -e "s/- \"3000:3000\"/- \"${docker_port}:3000\"/g" \
                    -e 's/container_name: redis/container_name: redis-new-api/g' \
                    -e 's/container_name: mysql/container_name: mysql-new-api/g' \
                    docker-compose.yml

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip

            }

            docker_app_uninstall() {
                cd /home/docker/new-api/ && docker compose down --rmi all
                rm -rf /home/docker/new-api
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        60 | jms)

            local app_id="60"
            local app_name="JumpServer开源堡垒机"
            local app_text="是一个开源的特权访问管理 (PAM) 工具，该程序占用80端口不支持添加域名访问了"
            local app_url="官方介绍: https://github.com/jumpserver/jumpserver"
            local docker_name="jms_web"
            local docker_port="80"
            local app_size="2"

            docker_app_install() {
                curl -sSL ${gh_proxy}github.com/jumpserver/jumpserver/releases/latest/download/quick_start.sh | bash
                clear
                echo "已经安装完成"
                check_docker_app_ip
                echo "初始用户名: admin"
                echo "初始密码: ChangeMe"
            }

            docker_app_update() {
                cd /opt/jumpserver-installer*/
                ./jmsctl.sh upgrade
                echo "应用已更新"
            }

            docker_app_uninstall() {
                cd /opt/jumpserver-installer*/
                ./jmsctl.sh uninstall
                cd /opt
                rm -rf jumpserver-installer*/
                rm -rf jumpserver
                echo "应用已卸载"
            }

            docker_app_plus
            ;;

        61 | libretranslate)
            local app_id="61"
            local docker_name="libretranslate"
            local docker_img="libretranslate/libretranslate:latest"
            local docker_port=8061

            docker_rum() {

                docker run -d \
                    -p "${docker_port}":5000 \
                    --name libretranslate \
                    libretranslate/libretranslate \
                    --load-only ko,zt,zh,en,ja,pt,es,fr,de,ru

            }

            local docker_describe="免费开源机器翻译 API，完全自托管，它的翻译引擎由开源Argos Translate库提供支持。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/LibreTranslate/LibreTranslate${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="5"
            docker_app
            ;;

        62 | ragflow)
            local app_id="62"
            local app_name="RAGFlow知识库"
            local app_text="基于深度文档理解的开源 RAG（检索增强生成）引擎"
            local app_url="官方网站: https://github.com/infiniflow/ragflow"
            local docker_name="ragflow-server"
            local docker_port="8062"
            local app_size="8"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/infiniflow/ragflow.git && cd ragflow/docker
                sed -i "s/- 80:80/- ${docker_port}:80/; /- 443:443/d" docker-compose.yml
                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/ragflow/docker/ && docker compose down --rmi all
                cd /home/docker/ragflow/
                git pull origin main
                cd /home/docker/ragflow/docker/
                sed -i "s/- 80:80/- ${docker_port}:80/; /- 443:443/d" docker-compose.yml
                docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/ragflow/docker/ && docker compose down --rmi all
                rm -rf /home/docker/ragflow
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        63 | open-webui)
            local app_id="63"
            local docker_name="open-webui"
            local docker_img="ghcr.io/open-webui/open-webui:main"
            local docker_port=8063

            docker_rum() {
                docker run -d -p "${docker_port}":8080 -v /home/docker/open-webui:/app/backend/data --name open-webui --restart=always ghcr.io/open-webui/open-webui:main
            }

            local docker_describe="OpenWebUI一款大语言模型网页框架，官方精简版本，支持各大模型API接入"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/open-webui/open-webui${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="3"
            docker_app
            ;;

        64 | it-tools)
            local app_id="64"
            local docker_name="it-tools"
            local docker_img="corentinth/it-tools:latest"
            local docker_port=8064

            docker_rum() {
                docker run -d --name it-tools --restart=always -p "${docker_port}":80 corentinth/it-tools:latest
            }

            local docker_describe="对开发人员和 IT 工作者来说非常有用的工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/CorentinTh/it-tools${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        65 | n8n)
            local app_id="65"
            local docker_name="n8n"
            local docker_img="docker.n8n.io/n8nio/n8n"
            local docker_port=8065

            docker_rum() {
                add_yuming
                mkdir -p /home/docker/n8n
                chmod -R 777 /home/docker/n8n

                docker run -d --name n8n \
                    --restart=always \
                    -p "${docker_port}":5678 \
                    -v /home/docker/n8n:/home/node/.n8n \
                    -e N8N_HOST="${yuming}" \
                    -e N8N_PORT=5678 \
                    -e N8N_PROTOCOL=https \
                    -e WEBHOOK_URL=https://"${yuming}"/ \
                    docker.n8n.io/n8nio/n8n

                ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
                block_container_port "$docker_name" "$ipv4_address"
            }

            local docker_describe="是一款功能强大的自动化工作流平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/n8n-io/n8n${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        66 | yt)
            yt_menu_pro
            ;;

        67 | ddns)
            local app_id="67"
            local docker_name="ddns-go"
            local docker_img="jeessy/ddns-go"
            local docker_port=8067

            docker_rum() {
                docker run -d \
                    --name ddns-go \
                    --restart=always \
                    -p "${docker_port}":9876 \
                    -v /home/docker/ddns-go:/root \
                    jeessy/ddns-go
            }

            local docker_describe="自动将你的公网 IP（IPv4/IPv6）实时更新到各大 DNS 服务商，实现动态域名解析。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/jeessy2/ddns-go${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        68 | allinssl)
            local app_id="68"
            local docker_name="allinssl"
            local docker_img="allinssl/allinssl:latest"
            local docker_port=8068

            docker_rum() {
                docker run -itd --name allinssl -p "${docker_port}":8888 -v /home/docker/allinssl/data:/www/allinssl/data -e ALLINSSL_USER=allinssl -e ALLINSSL_PWD=allinssldocker -e ALLINSSL_URL=allinssl allinssl/allinssl:latest
            }

            local docker_describe="开源免费的 SSL 证书自动化管理平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://allinssl.com${gl_bai}"
            local docker_use="echo \"安全入口: /allinssl\""
            local docker_passwd="echo \"用户名: allinssl  密码: allinssldocker\""
            local app_size="1"
            docker_app
            ;;

        69 | sftpgo)
            local app_id="69"
            local docker_name="sftpgo"
            local docker_img="drakkan/sftpgo:latest"
            local docker_port=8069

            docker_rum() {

                mkdir -p /home/docker/sftpgo/data
                mkdir -p /home/docker/sftpgo/config
                chown -R 1000:1000 /home/docker/sftpgo

                docker run -d \
                    --name sftpgo \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    -p 22022:2022 \
                    --mount type=bind,source=/home/docker/sftpgo/data,target=/srv/sftpgo \
                    --mount type=bind,source=/home/docker/sftpgo/config,target=/var/lib/sftpgo \
                    drakkan/sftpgo:latest
            }

            local docker_describe="开源免费随时随地SFTP FTP WebDAV 文件传输工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://sftpgo.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        70 | astrbot)
            local app_id="70"
            local docker_name="astrbot"
            local docker_img="soulter/astrbot:latest"
            local docker_port=8070

            docker_rum() {

                mkdir -p /home/docker/astrbot/data
                docker run -d \
                    -p "${docker_port}":6185 \
                    -p 6195:6195 \
                    -p 6196:6196 \
                    -p 6199:6199 \
                    -p 11451:11451 \
                    -v /home/docker/astrbot/data:/AstrBot/data \
                    --restart=always \
                    --name astrbot \
                    soulter/astrbot:latest
            }

            local docker_describe="开源AI聊天机器人框架，支持微信，QQ，TG接入AI大模型"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://astrbot.app/${gl_bai}"
            local docker_use="echo \"用户名: astrbot  密码: astrbot\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        71 | navidrome)
            local app_id="71"
            local docker_name="navidrome"
            local docker_img="deluan/navidrome:latest"
            local docker_port=8071

            docker_rum() {
                docker run -d \
                    --name navidrome \
                    --restart=always \
                    --user $(id -u):$(id -g) \
                    -v /home/docker/navidrome/music:/music \
                    -v /home/docker/navidrome/data:/data \
                    -p "${docker_port}":4533 \
                    -e ND_LOGLEVEL=info \
                    deluan/navidrome:latest
            }

            local docker_describe="是一个轻量、高性能的音乐流媒体服务器"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.navidrome.org/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        72 | bitwarden)
            local app_id="72"
            local docker_name="bitwarden"
            local docker_img="vaultwarden/server"
            local docker_port=8072

            docker_rum() {
                docker run -d \
                    --name bitwarden \
                    --restart=always \
                    -p "${docker_port}":80 \
                    -v /home/docker/bitwarden/data:/data \
                    vaultwarden/server
            }

            local docker_describe="一个你可以控制数据的密码管理器"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://bitwarden.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        73 | libretv)
            local app_id="73"
            local docker_name="libretv"
            local docker_img="bestzwei/libretv:latest"
            local docker_port=8073

            docker_rum() {
                read -r -e -p "设置LibreTV的登录密码: " app_passwd

                docker run -d \
                    --name libretv \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    -e PASSWORD="${app_passwd}" \
                    bestzwei/libretv:latest
            }

            local docker_describe="免费在线视频搜索与观看平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/LibreSpark/LibreTV${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        74 | moontv)

            local app_id="74"

            local app_name="moontv私有影视"
            local app_text="免费在线视频搜索与观看平台"
            local app_url="视频介绍: https://github.com/MoonTechLab/LunaTV"
            local docker_name="moontv-core"
            local docker_port="8074"
            local app_size="2"

            docker_app_install() {
                read -r -e -p "设置登录用户名: " admin
                read -r -e -p "设置登录用户密码: " admin_password
                read -r -e -p "输入授权码: " shouquanma

                mkdir -p /home/docker/moontv
                mkdir -p /home/docker/moontv/config
                mkdir -p /home/docker/moontv/data
                cd /home/docker/moontv

                curl -o /home/docker/moontv/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/moontv-docker-compose.yml
                sed -i "s/3000:3000/${docker_port}:3000/g" /home/docker/moontv/docker-compose.yml
                sed -i "s|admin_password|${admin_password}|g" /home/docker/moontv/docker-compose.yml
                sed -i "s|admin|${admin}|g" /home/docker/moontv/docker-compose.yml
                sed -i "s|shouquanma|${shouquanma}|g" /home/docker/moontv/docker-compose.yml
                cd /home/docker/moontv/
                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/moontv/ && docker compose down --rmi all
                cd /home/docker/moontv/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/moontv/ && docker compose down --rmi all
                rm -rf /home/docker/moontv
                echo "应用已卸载"
            }
            docker_app_plus
            ;;
        75 | melody)

            local app_id="75"
            local docker_name="melody"
            local docker_img="foamzou/melody:latest"
            local docker_port=8075

            docker_rum() {
                docker run -d \
                    --name melody \
                    --restart=always \
                    -p "${docker_port}":5566 \
                    -v /home/docker/melody/.profile:/app/backend/.profile \
                    foamzou/melody:latest
            }

            local docker_describe="你的音乐精灵，旨在帮助你更好地管理音乐。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/foamzou/melody${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        76 | dosgame)

            local app_id="76"
            local docker_name="dosgame"
            local docker_img="oldiy/dosgame-web-docker:latest"
            local docker_port=8076

            docker_rum() {
                docker run -d \
                    --name dosgame \
                    --restart=always \
                    -p "${docker_port}":262 \
                    oldiy/dosgame-web-docker:latest
            }

            local docker_describe="是一个中文DOS游戏合集网站"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/rwv/chinese-dos-games${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="2"
            docker_app
            ;;
        77 | xunlei)
            local app_id="77"
            local docker_name="xunlei"
            local docker_img="cnk3x/xunlei"
            local docker_port=8077

            docker_rum() {

                read -r -e -p "设置登录用户名: " app_use
                read -r -e -p "设置登录密码: " app_passwd

                docker run -d \
                    --name xunlei \
                    --restart=always \
                    --privileged \
                    -e XL_DASHBOARD_USERNAME="${app_use}" \
                    -e XL_DASHBOARD_PASSWORD="${app_passwd}" \
                    -v /home/docker/xunlei/data:/xunlei/data \
                    -v /home/docker/xunlei/downloads:/xunlei/downloads \
                    -p "${docker_port}":2345 \
                    cnk3x/xunlei
            }

            local docker_describe="迅雷你的离线高速BT磁力下载工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/cnk3x/xunlei${gl_bai}"
            local docker_use="echo \"手机登录迅雷，再输入邀请码，邀请码: 迅雷牛通\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        78 | PandaWiki)

            local app_id="78"
            local app_name="PandaWiki"
            local app_text="PandaWiki是一款AI大模型驱动的开源智能文档管理系统，强烈建议不要自定义端口部署。"
            local app_url="官方介绍: https://github.com/chaitin/PandaWiki"
            local docker_name="panda-wiki-nginx"
            local docker_port="2443"
            local app_size="2"

            docker_app_install() {
                bash -c "$(curl -fsSLk https://release.baizhi.cloud/panda-wiki/manager.sh)"
            }

            docker_app_update() {
                docker_app_install
            }

            docker_app_uninstall() {
                docker_app_install
            }

            docker_app_plus
            ;;
        79 | beszel)

            local app_id="79"
            local docker_name="beszel"
            local docker_img="henrygd/beszel"
            local docker_port=8079

            docker_rum() {
                mkdir -p /home/docker/beszel &&
                    docker run -d \
                        --name beszel \
                        --restart=always \
                        -v /home/docker/beszel:/beszel_data \
                        -p "${docker_port}":8090 \
                        henrygd/beszel
            }

            local docker_describe="Beszel轻量易用的服务器监控"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://beszel.dev/zh/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        80 | linkwarden)
            local app_id="80"
            local app_name="linkwarden书签管理"
            local app_text="一个开源的自托管书签管理平台，支持标签、搜索和团队协作。"
            local app_url="官方网站: https://linkwarden.app/"
            local docker_name="linkwarden-linkwarden-1"
            local docker_port="8080"
            local app_size="3"

            docker_app_install() {
                install git openssl
                mkdir -p /home/docker/linkwarden && cd /home/docker/linkwarden

                # 下载官方 docker-compose 和 env 文件
                curl -O ${gh_proxy}raw.githubusercontent.com/linkwarden/linkwarden/refs/heads/main/docker-compose.yml
                curl -L ${gh_proxy}raw.githubusercontent.com/linkwarden/linkwarden/refs/heads/main/.env.sample -o ".env"

                # 生成随机密钥与密码
                local ADMIN_EMAIL="admin@example.com"
                local ADMIN_PASSWORD=$(openssl rand -hex 8)

                sed -i "s|^NEXTAUTH_URL=.*|NEXTAUTH_URL=http://localhost:${docker_port}/api/v1/auth|g" .env
                sed -i "s|^NEXTAUTH_SECRET=.*|NEXTAUTH_SECRET=$(openssl rand -hex 32)|g" .env
                sed -i "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(openssl rand -hex 16)|g" .env
                sed -i "s|^MEILI_MASTER_KEY=.*|MEILI_MASTER_KEY=$(openssl rand -hex 32)|g" .env

                # 追加管理员账号信息
                echo "ADMIN_EMAIL=${ADMIN_EMAIL}" >>.env
                echo "ADMIN_PASSWORD=${ADMIN_PASSWORD}" >>.env

                sed -i "s/3000:3000/${docker_port}:3000/g" /home/docker/linkwarden/docker-compose.yml

                # 启动容器
                docker compose up -d

                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/linkwarden && docker compose down --rmi all
                curl -O ${gh_proxy}raw.githubusercontent.com/linkwarden/linkwarden/refs/heads/main/docker-compose.yml
                curl -L ${gh_proxy}raw.githubusercontent.com/linkwarden/linkwarden/refs/heads/main/.env.sample -o ".env.new"

                # 保留原本的变量
                source .env
                mv .env.new .env
                echo "NEXTAUTH_URL=$NEXTAUTH_URL" >>.env
                echo "NEXTAUTH_SECRET=$NEXTAUTH_SECRET" >>.env
                echo "POSTGRES_PASSWORD=$POSTGRES_PASSWORD" >>.env
                echo "MEILI_MASTER_KEY=$MEILI_MASTER_KEY" >>.env
                echo "ADMIN_EMAIL=$ADMIN_EMAIL" >>.env
                echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" >>.env
                sed -i "s/3000:3000/${docker_port}:3000/g" /home/docker/linkwarden/docker-compose.yml

                docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/linkwarden && docker compose down --rmi all
                rm -rf /home/docker/linkwarden
                echo "应用已卸载"
            }
            docker_app_plus
            ;;
        81 | jitsi)
            local app_id="81"
            local app_name="JitsiMeet视频会议"
            local app_text="一个开源的安全视频会议解决方案，支持多人在线会议、屏幕共享与加密通信。"
            local app_url="官方网站: https://jitsi.org/"
            local docker_name="jitsi"
            local docker_port="8081"
            local app_size="3"

            docker_app_install() {
                add_yuming
                mkdir -p /home/docker/jitsi && cd /home/docker/jitsi
                wget "$(wget -q -O - https://api.github.com/repos/jitsi/docker-jitsi-meet/releases/latest | grep zip | cut -d\" -f4)"
                unzip "$(ls -t | head -n 1)"
                cd "$(find . -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
                cp env.example .env
                ./gen-passwords.sh
                mkdir -p ~/.jitsi-meet-cfg/{web,transcripts,prosody/config,prosody/prosody-plugins-custom,jicofo,jvb,jigasi,jibri}
                sed -i "s|^HTTP_PORT=.*|HTTP_PORT=${docker_port}|" .env
                sed -i "s|^#PUBLIC_URL=https://meet.example.com:\${HTTPS_PORT}|PUBLIC_URL=https://"$yuming":443|" .env
                docker compose up -d

                ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
                block_container_port "$docker_name" "$ipv4_address"
            }

            docker_app_update() {
                cd /home/docker/jitsi
                cd "$(find . -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
                docker compose down --rmi all
                docker compose up -d

            }

            docker_app_uninstall() {
                cd /home/docker/jitsi
                cd "$(find . -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
                docker compose down --rmi all
                rm -rf /home/docker/jitsi
                echo "应用已卸载"
            }

            docker_app_plus
            ;;
        82 | gpt-load)

            local app_id="82"
            local docker_name="gpt-load"
            local docker_img="tbphp/gpt-load:latest"
            local docker_port=8082

            docker_rum() {

                read -r -e -p "设置${docker_name}的登录密钥（sk-开头字母和数字组合）如: sk-159kejilionyyds163: " app_passwd

                mkdir -p /home/docker/gpt-load &&
                    docker run -d --name gpt-load \
                        -p "${docker_port}":3001 \
                        -e AUTH_KEY="${app_passwd}" \
                        -v "/home/docker/gpt-load/data":/app/data \
                        tbphp/gpt-load:latest
            }

            local docker_describe="高性能AI接口透明代理服务"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.gpt-load.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        83 | komari)
            local app_id="83"
            local docker_name="komari"
            local docker_img="ghcr.io/komari-monitor/komari:latest"
            local docker_port=8083

            docker_rum() {
                mkdir -p /home/docker/komari &&
                    docker run -d \
                        --name komari \
                        -p "${docker_port}":25774 \
                        -v /home/docker/komari:/app/data \
                        -e ADMIN_USERNAME=admin \
                        -e ADMIN_PASSWORD=1212156 \
                        --restart=always \
                        ghcr.io/komari-monitor/komari:latest
            }

            local docker_describe="轻量级的自托管服务器监控工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/komari-monitor/komari/tree/main${gl_bai}"
            local docker_use="echo \"默认账号: admin  默认密码: 1212156\""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        84 | wallos)

            local app_id="84"
            local docker_name="wallos"
            local docker_img="bellamy/wallos:latest"
            local docker_port=8084

            docker_rum() {
                mkdir -p /home/docker/wallos &&
                    docker run -d --name wallos \
                        -v /home/docker/wallos/db:/var/www/html/db \
                        -v /home/docker/wallos/logos:/var/www/html/images/uploads/logos \
                        -e TZ=UTC \
                        -p "${docker_port}":80 \
                        --restart=always \
                        bellamy/wallos:latest
            }

            local docker_describe="开源个人订阅追踪器，可用于财务管理"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/ellite/Wallos${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        85 | immich)

            local app_id="85"
            local app_name="immich图片视频管理器"
            local app_text="高性能自托管照片和视频管理解决方案。"
            local app_url="官网介绍: https://github.com/immich-app/immich"
            local docker_name="immich_server"
            local docker_port="8085"
            local app_size="3"

            docker_app_install() {
                install git openssl wget
                mkdir -p /home/docker/${docker_name} && cd /home/docker/${docker_name}

                wget -O docker-compose.yml ${gh_proxy}github.com/immich-app/immich/releases/latest/download/docker-compose.yml
                wget -O .env ${gh_proxy}github.com/immich-app/immich/releases/latest/download/example.env
                sed -i "s/2283:2283/${docker_port}:2283/g" /home/docker/${docker_name}/docker-compose.yml

                docker compose up -d

                clear
                echo "已经安装完成"
                check_docker_app_ip

            }

            docker_app_update() {
                cd /home/docker/${docker_name} && docker compose down --rmi all
                docker_app_install
            }

            docker_app_uninstall() {
                cd /home/docker/${docker_name} && docker compose down --rmi all
                rm -rf /home/docker/${docker_name}
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        86 | jellyfin)

            local app_id="86"
            local docker_name="jellyfin"
            local docker_img="jellyfin/jellyfin"
            local docker_port=8086

            docker_rum() {

                mkdir -p /home/docker/jellyfin/media
                chmod -R 777 /home/docker/jellyfin

                docker run -d \
                    --name jellyfin \
                    --user root \
                    --volume /home/docker/jellyfin/config:/config \
                    --volume /home/docker/jellyfin/cache:/cache \
                    --mount type=bind,source=/home/docker/jellyfin/media,target=/media \
                    -p "${docker_port}":8096 \
                    -p 7359:7359/udp \
                    --restart=always \
                    jellyfin/jellyfin
            }

            local docker_describe="是一款开源媒体服务器软件"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://jellyfin.org/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        87 | synctv)

            local app_id="87"
            local docker_name="synctv"
            local docker_img="synctvorg/synctv"
            local docker_port=8087

            docker_rum() {

                docker run -d \
                    --name synctv \
                    -v /home/docker/synctv:/root/.synctv \
                    -p "${docker_port}":8080 \
                    --restart=always \
                    synctvorg/synctv
            }

            local docker_describe="远程一起观看电影和直播的程序。它提供了同步观影、直播、聊天等功能"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/synctv-org/synctv${gl_bai}"
            local docker_use="echo \"初始账号和密码: root  登陆后请及时修改登录密码\""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        88 | owncast)

            local app_id="88"
            local docker_name="owncast"
            local docker_img="owncast/owncast:latest"
            local docker_port=8088

            docker_rum() {
                docker run -d \
                    --name owncast \
                    -p "${docker_port}":8080 \
                    -p 1935:1935 \
                    -v /home/docker/owncast/data:/app/data \
                    --restart=always \
                    owncast/owncast:latest
            }

            local docker_describe="开源、免费的自建直播平台"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://owncast.online${gl_bai}"
            local docker_use="echo \"访问地址后面带 /admin 访问管理员页面\""
            local docker_passwd="echo \"初始账号: admin  初始密码: abc123  登陆后请及时修改登录密码\""
            local app_size="1"
            docker_app

            ;;

        89 | file-code-box)

            local app_id="89"
            local docker_name="file-code-box"
            local docker_img="lanol/filecodebox:latest"
            local docker_port=8089

            docker_rum() {
                docker run -d \
                    --name file-code-box \
                    -p "${docker_port}":12345 \
                    -v /home/docker/file-code-box/data:/app/data \
                    --restart=always \
                    lanol/filecodebox:latest
            }

            local docker_describe="匿名口令分享文本和文件，像拿快递一样取文件"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/vastsa/FileCodeBox${gl_bai}"
            local docker_use="echo \"访问地址后面带 /#/admin 访问管理员页面\""
            local docker_passwd="echo \"管理员密码: FileCodeBox2023\""
            local app_size="1"
            docker_app

            ;;

        90 | matrix)

            local app_id="90"
            local docker_name="matrix"
            local docker_img="matrixdotorg/synapse:latest"
            local docker_port=8090

            docker_rum() {

                add_yuming

                if [ ! -d /home/docker/matrix/data ]; then
                    docker run -it --rm \
                        -v /home/docker/matrix/data:/data \
                        -e SYNAPSE_SERVER_NAME="${yuming}" \
                        -e SYNAPSE_REPORT_STATS=yes \
                        --name matrix \
                        matrixdotorg/synapse:latest generate
                fi

                docker run -d \
                    --name matrix \
                    -v /home/docker/matrix/data:/data \
                    -p "${docker_port}":8008 \
                    --restart=always \
                    matrixdotorg/synapse:latest

                echo "创建初始用户或管理员。请设置以下内容用户名和密码以及是否为管理员。"
                docker exec -it matrix register_new_matrix_user \
                    http://localhost:8008 \
                    -c /data/homeserver.yaml

                sed -i '/^enable_registration:/d' /home/docker/matrix/data/homeserver.yaml
                sed -i '/^# vim:ft=yaml/i enable_registration: true' /home/docker/matrix/data/homeserver.yaml
                sed -i '/^enable_registration_without_verification:/d' /home/docker/matrix/data/homeserver.yaml
                sed -i '/^# vim:ft=yaml/i enable_registration_without_verification: true' /home/docker/matrix/data/homeserver.yaml

                docker restart matrix

                ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
                block_container_port "$docker_name" "$ipv4_address"
            }

            local docker_describe="Matrix是一个去中心化的聊天协议"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://matrix.org/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        91 | gitea)

            local app_id="91"

            local app_name="gitea私有代码仓库"
            local app_text="免费新一代的代码托管平台，提供接近 GitHub 的使用体验。"
            local app_url="视频介绍: https://github.com/go-gitea/gitea"
            local docker_name="gitea"
            local docker_port="8091"
            local app_size="2"

            docker_app_install() {

                mkdir -p /home/docker/gitea
                mkdir -p /home/docker/gitea/gitea
                mkdir -p /home/docker/gitea/data
                mkdir -p /home/docker/gitea/postgres
                cd /home/docker/gitea

                curl -o /home/docker/gitea/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/gitea-docker-compose.yml
                sed -i "s/3000:3000/${docker_port}:3000/g" /home/docker/gitea/docker-compose.yml
                cd /home/docker/gitea/
                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/gitea/ && docker compose down --rmi all
                cd /home/docker/gitea/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/gitea/ && docker compose down --rmi all
                rm -rf /home/docker/gitea
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        92 | filebrowser)

            local app_id="92"
            local docker_name="filebrowser"
            local docker_img="hurlenko/filebrowser"
            local docker_port=8092

            docker_rum() {
                docker run -d \
                    --name filebrowser \
                    --restart=always \
                    -p "${docker_port}":8080 \
                    -v /home/docker/filebrowser/data:/data \
                    -v /home/docker/filebrowser/config:/config \
                    -e FB_BASEURL=/filebrowser \
                    hurlenko/filebrowser
            }

            local docker_describe="是一个基于Web的文件管理器"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://filebrowser.org/${gl_bai}"
            local docker_use="docker logs filebrowser"
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        93 | dufs)

            local app_id="93"
            local docker_name="dufs"
            local docker_img="sigoden/dufs"
            local docker_port=8093

            docker_rum() {
                docker run -d \
                    --name ${docker_name} \
                    --restart=always \
                    -v /home/docker/${docker_name}:/data \
                    -p "${docker_port}":5000 \
                    ${docker_img} /data -A
            }

            local docker_describe="极简静态文件服务器，支持上传下载"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/sigoden/dufs${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        94 | gopeed)

            local app_id="94"
            local docker_name="gopeed"
            local docker_img="liwei2633/gopeed"
            local docker_port=8094

            docker_rum() {
                read -r -e -p "设置登录用户名: " app_use
                read -r -e -p "设置登录密码: " app_passwd

                docker run -d \
                    --name ${docker_name} \
                    --restart=always \
                    -v /home/docker/${docker_name}/downloads:/app/Downloads \
                    -v /home/docker/${docker_name}/storage:/app/storage \
                    -p "${docker_port}":9999 \
                    ${docker_img} -u "${app_use}" -p "${app_passwd}"
            }

            local docker_describe="分布式高速下载工具，支持多种协议"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/GopeedLab/gopeed${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        95 | paperless)

            local app_id="95"

            local app_name="paperless文档管理平台"
            local app_text="开源的电子文档管理系统，它的主要用途是把你的纸质文件数字化并管理起来。"
            local app_url="视频介绍: https://docs.paperless-ngx.com/"
            local docker_name="paperless-webserver-1"
            local docker_port="8095"
            local app_size="2"

            docker_app_install() {
                mkdir -p /home/docker/paperless
                mkdir -p /home/docker/paperless/export
                mkdir -p /home/docker/paperless/consume
                cd /home/docker/paperless

                curl -o /home/docker/paperless/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/paperless-ngx/paperless-ngx/refs/heads/main/docker/compose/docker-compose.postgres-tika.yml
                curl -o /home/docker/paperless/docker-compose.env ${gh_proxy}raw.githubusercontent.com/paperless-ngx/paperless-ngx/refs/heads/main/docker/compose/.env

                sed -i "s/8000:8000/${docker_port}:8000/g" /home/docker/paperless/docker-compose.yml
                cd /home/docker/paperless
                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/paperless/ && docker compose down --rmi all
                docker_app_install
            }

            docker_app_uninstall() {
                cd /home/docker/paperless/ && docker compose down --rmi all
                rm -rf /home/docker/paperless
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        96 | 2fauth)

            local app_id="96"

            local app_name="2FAuth自托管二步验证器"
            local app_text="自托管的双重身份验证 (2FA) 账户管理和验证码生成工具。"
            local app_url="官网: https://github.com/Bubka/2FAuth"
            local docker_name="2fauth"
            local docker_port="8096"
            local app_size="1"

            docker_app_install() {
                add_yuming

                mkdir -p /home/docker/2fauth
                mkdir -p /home/docker/2fauth/data
                chmod -R 777 /home/docker/2fauth/
                cd /home/docker/2fauth

                curl -o /home/docker/2fauth/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/2fauth-docker-compose.yml

                sed -i "s/8000:8000/${docker_port}:8000/g" /home/docker/2fauth/docker-compose.yml
                sed -i "s/yuming.com/${yuming}/g" /home/docker/2fauth/docker-compose.yml
                cd /home/docker/2fauth
                docker compose up -d

                ldnmp_Proxy "${yuming}" 127.0.0.1 "${docker_port}"
                block_container_port "$docker_name" "$ipv4_address"

                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/2fauth/ && docker compose down --rmi all
                docker_app_install
            }

            docker_app_uninstall() {
                cd /home/docker/2fauth/ && docker compose down --rmi all
                rm -rf /home/docker/2fauth
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        97 | wgs)

            local app_id="97"
            local docker_name="wireguard"
            local docker_img="lscr.io/linuxserver/wireguard:latest"
            local docker_port=8097

            docker_rum() {

                read -r -e -p "请输入组网的客户端数量 (默认 5): " COUNT
                COUNT=${COUNT:-5}
                read -r -e -p "请输入 WireGuard 网段 (默认 10.13.13.0): " NETWORK
                NETWORK=${NETWORK:-10.13.13.0}

                PEERS=$(seq -f "wg%02g" 1 "$COUNT" | paste -sd,)

                ip link delete wg0 &>/dev/null

                ip_address
                docker run -d \
                    --name=wireguard \
                    --network host \
                    --cap-add=NET_ADMIN \
                    --cap-add=SYS_MODULE \
                    -e PUID=1000 \
                    -e PGID=1000 \
                    -e TZ=Etc/UTC \
                    -e SERVERURL="${ipv4_address}" \
                    -e SERVERPORT=51820 \
                    -e PEERS="${PEERS}" \
                    -e INTERNAL_SUBNET="${NETWORK}" \
                    -e ALLOWEDIPS="${NETWORK}"/24 \
                    -e PERSISTENTKEEPALIVE_PEERS=all \
                    -e LOG_CONFS=true \
                    -v /home/docker/wireguard/config:/config \
                    -v /lib/modules:/lib/modules \
                    --restart=always \
                    lscr.io/linuxserver/wireguard:latest

                sleep 3

                docker exec wireguard sh -c "
		f='/config/wg_confs/wg0.conf'
		sed -i 's/51820/${docker_port}/g' \$f
		"

                docker exec wireguard sh -c "
		for d in /config/peer_*; do
		  sed -i 's/51820/${docker_port}/g' \$d/*.conf
		done
		"

                docker exec wireguard sh -c '
		for d in /config/peer_*; do
		  sed -i "/^DNS/d" "$d"/*.conf
		done
		'

                docker exec wireguard sh -c '
		for d in /config/peer_*; do
		  for f in "$d"/*.conf; do
			grep -q "^PersistentKeepalive" "$f" || \
			sed -i "/^AllowedIPs/ a PersistentKeepalive = 25" "$f"
		  done
		done
		'

                docker exec -it wireguard bash -c '
		for d in /config/peer_*; do
		  cd "$d" || continue
		  conf_file=$(ls *.conf)
		  base_name="${conf_file%.conf}"
		  qrencode -o "$base_name.png" < "$conf_file"
		done
		'

                docker restart wireguard

                sleep 2
                echo
                echo -e "${gl_huang}所有客户端二维码配置: ${gl_bai}"
                docker exec -it wireguard bash -c 'for i in $(ls /config | grep peer_ | sed "s/peer_//"); do echo "--- $i ---"; /app/show-peer $i; done'
                sleep 2
                echo
                echo -e "${gl_huang}所有客户端配置代码: ${gl_bai}"
                docker exec wireguard sh -c 'for d in /config/peer_*; do echo "# $(basename $d) "; cat $d/*.conf; echo; done'
                sleep 2
                echo -e "${gl_lv}${COUNT}个客户端配置全部输出，使用方法如下：${gl_bai}"
                echo -e "${gl_lv}1. 手机下载wg的APP，扫描上方二维码，可以快速连接网络${gl_bai}"
                echo -e "${gl_lv}2. Windows下载客户端，复制配置代码连接网络。${gl_bai}"
                echo -e "${gl_lv}3. Linux用脚本部署WG客户端，复制配置代码连接网络。${gl_bai}"
                echo -e "${gl_lv}官方客户端下载方式: https://www.wireguard.com/install/${gl_bai}"
                break_end

            }

            local docker_describe="现代化、高性能的虚拟专用网络工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.wireguard.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        98 | wgc)

            local app_id="98"
            local docker_name="wireguardc"
            local docker_img="kjlion/wireguard:alpine"
            local docker_port=51820

            docker_rum() {
                mkdir -p /home/docker/wireguard/config/

                local CONFIG_FILE="/home/docker/wireguard/config/wg0.conf"

                # 创建目录（如果不存在）
                mkdir -p "$(dirname "$CONFIG_FILE")"

                echo "请粘贴你的客户端配置，连续按两次回车保存："

                # 初始化变量
                input=""
                empty_line_count=0

                # 逐行读取用户输入
                while IFS= read -r -r line; do
                    if [[ -z "$line" ]]; then
                        ((empty_line_count++))
                        if [[ $empty_line_count -ge 2 ]]; then
                            break
                        fi
                    else
                        empty_line_count=0
                        input+="$line"$'\n'
                    fi
                done

                # 写入配置文件
                echo "$input" >"$CONFIG_FILE"

                echo "客户端配置已保存到 $CONFIG_FILE"

                ip link delete wg0 &>/dev/null

                docker run -d \
                    --name wireguardc \
                    --network host \
                    --cap-add NET_ADMIN \
                    --cap-add SYS_MODULE \
                    -v /home/docker/wireguard/config:/config \
                    -v /lib/modules:/lib/modules:ro \
                    --restart=always \
                    kjlion/wireguard:alpine

                sleep 3

                docker logs wireguardc

                break_end
            }

            local docker_describe="现代化、高性能的虚拟专用网络工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://www.wireguard.com/${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        99 | dsm)

            local app_id="99"

            local app_name="dsm群晖虚拟机"
            local app_text="Docker容器中的虚拟DSM"
            local app_url="官网: https://github.com/vdsm/virtual-dsm"
            local docker_name="dsm"
            local docker_port="8099"
            local app_size="16"

            docker_app_install() {

                read -r -e -p "设置 CPU 核数 (默认 2): " CPU_CORES
                local CPU_CORES=${CPU_CORES:-2}

                read -r -e -p "设置内存大小 (默认 4G): " RAM_SIZE
                local RAM_SIZE=${RAM_SIZE:-4}

                mkdir -p /home/docker/dsm
                mkdir -p /home/docker/dsm/dev
                chmod -R 777 /home/docker/dsm/
                cd /home/docker/dsm

                curl -o /home/docker/dsm/docker-compose.yml ${gh_proxy}raw.githubusercontent.com/kejilion/docker/main/dsm-docker-compose.yml

                sed -i "s/5000:5000/${docker_port}:5000/g" /home/docker/dsm/docker-compose.yml
                sed -i "s|CPU_CORES: "2"|CPU_CORES: ""${CPU_CORES}""|g" /home/docker/dsm/docker-compose.yml
                sed -i "s|RAM_SIZE: "2G"|RAM_SIZE: ""${RAM_SIZE}"G"|g" /home/docker/dsm/docker-compose.yml
                cd /home/docker/dsm
                docker compose up -d

                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/dsm/ && docker compose down --rmi all
                docker_app_install
            }

            docker_app_uninstall() {
                cd /home/docker/dsm/ && docker compose down --rmi all
                rm -rf /home/docker/dsm
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        100 | syncthing)

            local app_id="100"
            local docker_name="syncthing"
            local docker_img="syncthing/syncthing:latest"
            local docker_port=8100

            docker_rum() {
                docker run -d \
                    --name=syncthing \
                    --hostname=my-syncthing \
                    --restart=always \
                    -p "${docker_port}":8384 \
                    -p 22000:22000/tcp \
                    -p 22000:22000/udp \
                    -p 21027:21027/udp \
                    -v /home/docker/syncthing:/var/syncthing \
                    syncthing/syncthing:latest
            }

            local docker_describe="开源的点对点文件同步工具，类似于 Dropbox、Resilio Sync，但完全去中心化。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/syncthing/syncthing${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;

        101 | moneyprinterturbo)
            local app_id="101"
            local app_name="AI视频生成工具"
            local app_text="MoneyPrinterTurbo是一款使用AI大模型合成高清短视频的工具"
            local app_url="官方网站: https://github.com/harry0703/MoneyPrinterTurbo"
            local docker_name="moneyprinterturbo"
            local docker_port="8101"
            local app_size="3"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/harry0703/MoneyPrinterTurbo.git && cd MoneyPrinterTurbo/
                sed -i "s/8501:8501/${docker_port}:8501/g" /home/docker/MoneyPrinterTurbo/docker-compose.yml

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/MoneyPrinterTurbo/ && docker compose down --rmi all
                cd /home/docker/MoneyPrinterTurbo/
                git pull origin main
                sed -i "s/8501:8501/${docker_port}:8501/g" /home/docker/MoneyPrinterTurbo/docker-compose.yml
                cd /home/docker/MoneyPrinterTurbo/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/MoneyPrinterTurbo/ && docker compose down --rmi all
                rm -rf /home/docker/MoneyPrinterTurbo
                echo "应用已卸载"
            }

            docker_app_plus

            ;;

        102 | vocechat)

            local app_id="102"
            local docker_name="vocechat-server"
            local docker_img="privoce/vocechat-server:latest"
            local docker_port=8102

            docker_rum() {

                docker run -d --restart=always \
                    -p "${docker_port}":3000 \
                    --name vocechat-server \
                    -v /home/docker/vocechat/data:/home/vocechat-server/data \
                    privoce/vocechat-server:latest

            }

            local docker_describe="是一款支持独立部署的个人云社交媒体聊天服务"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/Privoce/vocechat-web${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        103 | umami)
            local app_id="103"
            local app_name="Umami网站统计工具"
            local app_text="开源、轻量、隐私友好的网站分析工具，类似于GoogleAnalytics。"
            local app_url="官方网站: https://github.com/umami-software/umami"
            local docker_name="umami-umami-1"
            local docker_port="8103"
            local app_size="1"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/umami-software/umami.git && cd umami
                sed -i "s/3000:3000/${docker_port}:3000/g" /home/docker/umami/docker-compose.yml

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
                echo "初始用户名: admin"
                echo "初始密码: umami"
            }

            docker_app_update() {
                cd /home/docker/umami/ && docker compose down --rmi all
                cd /home/docker/umami/
                git pull origin main
                sed -i "s/8501:8501/${docker_port}:8501/g" /home/docker/umami/docker-compose.yml
                cd /home/docker/umami/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/umami/ && docker compose down --rmi all
                rm -rf /home/docker/umami
                echo "应用已卸载"
            }

            docker_app_plus
            ;;
        104 | nginx-stream)
            stream_panel
            ;;
        105 | siyuan)

            local app_id="105"
            local docker_name="siyuan"
            local docker_img="b3log/siyuan"
            local docker_port=8105

            docker_rum() {
                read -r -e -p "设置登录密码: " app_passwd

                docker run -d \
                    --name siyuan \
                    --restart=always \
                    -v /home/docker/siyuan/workspace:/siyuan/workspace \
                    -p "${docker_port}":6806 \
                    -e PUID=1001 \
                    -e PGID=1002 \
                    b3log/siyuan \
                    --workspace=/siyuan/workspace/ \
                    --accessAuthCode="${app_passwd}"
            }

            local docker_describe="思源笔记是一款隐私优先的知识管理系统"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/siyuan-note/siyuan${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        106 | drawnix)

            local app_id="106"
            local docker_name="drawnix"
            local docker_img="pubuzhixing/drawnix"
            local docker_port=8106

            docker_rum() {
                docker run -d \
                    --restart=always \
                    --name drawnix \
                    -p "${docker_port}":80 \
                    pubuzhixing/drawnix
            }

            local docker_describe="是一款强大的开源白板工具，集成思维导图、流程图等。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/plait-board/drawnix${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;
        107 | pansou)

            local app_id="107"
            local docker_name="pansou"
            local docker_img="ghcr.io/fish2018/pansou-web"
            local docker_port=8107

            docker_rum() {
                docker run -d \
                    --name pansou \
                    --restart=always \
                    -p "${docker_port}":80 \
                    -v /home/docker/pansou/data:/app/data \
                    -v /home/docker/pansou/logs:/app/logs \
                    -e ENABLED_PLUGINS="hunhepan,jikepan,panwiki,pansearch,panta,qupansou,
susu,thepiratebay,wanou,xuexizhinan,panyq,zhizhen,labi,muou,ouge,shandian,
duoduo,huban,cyg,erxiao,miaoso,fox4k,pianku,clmao,wuji,cldi,xiaozhang,
libvio,leijing,xb6v,xys,ddys,hdmoli,yuhuage,u3c3,javdb,clxiong,jutoushe,
sdso,xiaoji,xdyh,haisou,bixin,djgou,nyaa,xinjuc,aikanzy,qupanshe,xdpan,
discourse,yunsou,ahhhhfs,nsgame,gying" \
                    ghcr.io/fish2018/pansou-web
            }

            local docker_describe="PanSou是一个高性能的网盘资源搜索API服务。"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} https://github.com/fish2018/pansou${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app

            ;;
        108 | langbot)
            local app_id="108"
            local app_name="LangBot聊天机器人"
            local app_text="是一个开源的大语言模型原生即时通信机器人开发平台"
            local app_url="官方网站: https://github.com/langbot-app/LangBot"
            local docker_name="langbot_plugin_runtime"
            local docker_port="8108"
            local app_size="1"

            docker_app_install() {
                install git
                mkdir -p /home/docker/ && cd /home/docker/ && git clone https://github.com/langbot-app/LangBot && cd LangBot/docker
                sed -i "s/5300:5300/${docker_port}:5300/g" /home/docker/LangBot/docker/docker-compose.yaml

                docker compose up -d
                clear
                echo "已经安装完成"
                check_docker_app_ip
            }

            docker_app_update() {
                cd /home/docker/LangBot/docker && docker compose down --rmi all
                cd /home/docker/LangBot/
                git pull origin main
                sed -i "s/5300:5300/${docker_port}:5300/g" /home/docker/LangBot/docker/docker-compose.yaml
                cd /home/docker/LangBot/docker/ && docker compose up -d
            }

            docker_app_uninstall() {
                cd /home/docker/LangBot/docker/ && docker compose down --rmi all
                rm -rf /home/docker/LangBot
                echo "应用已卸载"
            }

            docker_app_plus
            ;;
        109 | md)
            # md云文档
            local app_id="109"
            local docker_name="md"
            local docker_img="streamerzero/md"
            local docker_port=9900

            docker_rum() {

                docker run -d \
                    -v /home/docker/md/data:/md/data \
                    -p "${docker_port}":9900 \
                    --name md \
                    --hostname md \
                    --restart=always \
                    streamerzero/md

            }

            local docker_describe="md 云文档"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}gitee.com/streamerzero/md${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        110 | xiaomusic)
            # 小爱音箱操控面板
            local app_id="110"
            local docker_name="xiaomusic"
            local docker_img="docker.hanxi.cc/hanxi/xiaomusic"
            local docker_port=8090

            docker_rum() {

                docker run -d \
                    -v /home/docker/xiaomusic/music:/app/music \
                    -v /home/docker/xiaomusic/conf:/app/conf \
                    -p "${docker_port}":8090 \
                    -e XIAOMUSIC_PUBLIC_PORT="${docker_port}" \
                    --name "${docker_name}" \
                    --hostname "${docker_name}" \
                    --restart=always \
                    "${docker_img}"

                sleep 3

                cd /home/docker/xiaomusic/music
                wget -c https://gitee.com/meimolihan/sh/raw/master/music/海边探戈-王鹤棣.mp3
                wget -c https://gitee.com/meimolihan/sh/raw/master/music/生活没有说明书-洛什么洛.mp3

                break_end
            }

            local docker_describe="小爱音箱操控面板"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}xdocs.hanxi.cc${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        111 | taosync)
            # taosync网盘同步工具
            local app_id="111"
            local docker_name="taosync"
            local docker_img="dr34m/tao-sync:latest"
            local docker_port=8023

            docker_rum() {

                docker run -d \
                    -v /home/docker/taosync/data:/app/data \
                    -v /home/docker/taosync/config:/app/config \
                    -p "${docker_port}":8023 \
                    -e TZ=Asia/Shanghai \
                    -e SYNC_INTERVAL=3600 \
                    -e LOG_LEVEL=info \
                    --cpus 1.0 \
                    --memory-reservation 512M \
                    -m 1G \
                    --name taosync \
                    --hostname taosync \
                    --restart=always \
                    dr34m/tao-sync:latest
            }

            local docker_describe="taosync网盘同步工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/dr34m-cn/taosync${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        112 | musicn)
            # musicn音乐下载工具
            local app_id="112"
            local docker_name="musicn"
            local docker_img="ghcr.io/wy580477/musicn-container:latest"
            local docker_port=7478

            docker_rum() {

                docker run -d \
                    -v /home/docker/musicn/data:/data \
                    -p "${docker_port}":7478 \
                    --name musicn \
                    --hostname musicn \
                    --restart=always \
                    ghcr.io/wy580477/musicn-container:latest \
                    msc -q
            }

            local docker_describe="musicn音乐下载工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/wy580477/musicn-container${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        113 | aipan)
            # aipan网盘搜索工具
            local app_id="113"
            local docker_name="aipan"
            local docker_img="unilei/aipan-netdisk-search-simple:latest"
            local docker_port=3000

            docker_rum() {

                docker run -d \
                    -p "${docker_port}":3000 \
                    --name aipan \
                    --hostname aipan \
                    -e TZ=Asia/Shanghai \
                    -e DATABASE_URL=file:/app/prisma/db.sqlite \
                    --restart=always \
                    unilei/aipan-netdisk-search-simple:latest
            }

            local docker_describe="aipan网盘搜索工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/unilei/aipan-netdisk-search${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        114 | vert)
            # vert文件格式转换器
            local app_id="114"
            local docker_name="vert"
            local docker_img="ghcr.io/vert-sh/vert:latest"
            local docker_port=80

            docker_rum() {

                docker run -d \
                    -v /home/docker/vert/data:/app/data \
                    -p "${docker_port}":80 \
                    --name vert \
                    --hostname vert \
                    -e PUB_HOSTNAME=$ipv4_address:${docker_port} \
                    -e PUB_PLAUSIBLE_URL= \
                    -e PUB_ENV=production \
                    -e PUB_VERTD_URL=http://vertd:24153 \
                    -e PUB_DISABLE_ALL_EXTERNAL_REQUESTS=true \
                    -e PUB_DONATION_URL=https://donations.vert.sh \
                    -e PUB_STRIPE_KEY=pk_live_51RDVmAGSdrargQwzVNnbc28nlmzA30krLWk1fefCMpUPiSRPkavMMbGqa8A3lUaOCMlsUEVy2CWDYg0iospp392frr \
                    ghcr.io/vert-sh/vert:latest
            }

            local docker_describe="vert文件格式转换器"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/VERT-sh/VERT${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        115 | easynode)
            # easynode网页SSH工具 
            local app_id="115"
            local docker_name="easynode"
            local docker_img="chaoszhu/easynode"
            local docker_port=8082

            docker_rum() {

                docker run -d \
                    -v /home/docker/easynode/db:/easynode/app/db \
                    -p "${docker_port}":8082 \
                    --name easynode \
                    --hostname easynode \
                    -e TZ=Asia/Shanghai \
                    -e DEBUG=0 \
                    chaoszhu/easynode
            }

            local docker_describe="easynode网页SSH工具 "
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/chaos-zhu/easynode${gl_bai}"
            local docker_use="sleep 3"
            local docker_passwd="docker logs easynode"
            local app_size="1"
            docker_app
            ;;
        116 | mind-map)
            # mind-map思维导图
            local app_id="116"
            local docker_name="mind-map"
            local docker_img="shuiche/mind-map"
            local docker_port=8080

            docker_rum() {

                docker run -d \
                    -v /home/docker/vert/data:/app/data \
                    -p "${docker_port}":8080 \
                    --name mind-map \
                    --hostname mind-map \
                    shuiche/mind-map
            }

            local docker_describe="mind-map思维导图"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/wanglin2/mind-map${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        117 | random)
            # random随机壁纸
            local app_id="117"
            local docker_name="random"
            local docker_img="neixin/random-pic-api"
            local docker_port=80

            docker_rum() {

                docker run -d \
                   -v /home/docker/random/portrait:/var/www/html/portrait \
                   -v /home/docker/random/landscape:/var/www/html/landscape \
                   -v /home/docker/random/photos:/var/www/html/photos \
                    -p "${docker_port}":80 \
                    --name random \
                    --hostname random \
                   neixin/random-pic-api
            }

            # 下载依赖文件
            safe_wget(){
              local url=$1
              local file=${url##*/}
              if [[ -f $file ]]; then
                echo "[SKIP] $file 已存在"
              else
                wget -c "$url"
              fi
            }
            # 主流程
            mkdir -p /home/docker/random/{portrait,landscape,photos}
            cd /home/docker/random

            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/index.php
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/classify.py

            cd portrait
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/portrait/index.php
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/portrait/sj-001.webp
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/portrait/sj-002.webp

            cd ../landscape
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/landscape/index.php
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/landscape/pc-001.webp
            safe_wget gitee.com/meimolihan/script/raw/master/nginx/random/landscape/pc-002.webp

            local docker_describe="random随机壁纸"
            local docker_url="${gl_bai}官网介绍: ${gl_lv}${gh_proxy}github.com/meimolihan/random-pic-api${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;

        118 | hd-Icons)
            # hd-Icons高清图标库
            local app_id="118"
            local docker_name="hd-Icons"
            local docker_img="xushier/hd-icons:latest"
            local docker_port=50560

            docker_rum() {

                docker run -d \
                    -v /home/docker/hd-Icons/icons:/app/icons \
                    -p "${docker_port}":50560 \
                    -e TITLE=墨不凡图标库 \
                    --name hd-Icons \
                    --hostname hd-Icons \
                    xushier/hd-icons:latest
            }

            local docker_describe="hd-Icons高清图标库"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/xushier/HD-Icons${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        119 | metube)
            # MeTube是一个视频下载工具
            local app_id="119"
            local docker_name="metube"
            local docker_img="ghcr.io/alexta69/metube"
            local docker_port=8081

            docker_rum() {

                docker run -d \
                    -v /home/docker/metube/downloads:/downloads \
                    -p "${docker_port}":8081 \
                    --name metube \
                    --hostname metube \
                    ghcr.io/alexta69/metube
            }

            local docker_describe="MeTube是一个视频下载工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/alexta69/metube${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        120 | fndesk)
            # fndesk飞牛桌面图标管理工具
            local app_id="120"
            local docker_name="metube"
            local docker_img="imgzcq/fndesk:latest"
            local docker_port=9990

            docker_rum() {

                docker run -d \
                    -v /usr/trim/www:/fnw \
                    -v /usr/trim/share/.restore:/res \
                    -v /usr/local/apps/@appcenter/trim.media:/trim.media \
                    -v /home/docker/fndesk/deskdata:/deskdata \
                    -e TZ=Asia/Shanghai
                    -p "${docker_port}":9990 \
                    --name fndesk \
                    --hostname fndesk \
                    imgzcq/fndesk:latest
            }

            local docker_describe="fndesk飞牛桌面图标管理工具"
            local docker_url="${gl_bai}官网介绍: ${gl_lv} ${gh_proxy}github.com/IMGZCQ/fndesk${gl_bai}"
            local docker_use=""
            local docker_passwd=""
            local app_size="1"
            docker_app
            ;;
        b)
            clear
            local backup_filename="app_$(date +"%Y%m%d%H%M%S").tar.gz"
            echo -e "${gl_huang}正在备份 $backup_filename ...${gl_bai}"
            cd / && tar czvf "$backup_filename" home

            while true; do
                clear
                echo "备份文件已创建: /$backup_filename"
                read -r -e -p "$(echo -e "${gl_bai}要传送备份数据到远程服务器吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
                case "$choice" in
                [Yy])
                    read -r -e -p "请输入远端服务器IP:  " remote_ip
                    read -r -e -p "目标服务器SSH端口 [默认22]: " TARGET_PORT
                    local TARGET_PORT=${TARGET_PORT:-22}

                    if [ -z "$remote_ip" ]; then
                        echo "错误: 请输入远端服务器IP。"
                        return
                    fi
                    local latest_tar
                    latest_tar=$(find / -maxdepth 1 -name "app*.tar.gz" -printf "%T@ %p\n" | sort -nr | head -1 | cut -d' ' -f2-)
                    if [ -n "$latest_tar" ]; then
                        ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
                        sleep 2 # 添加等待时间
                        scp -P "$TARGET_PORT" -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/"
                        echo "文件已传送至远程服务器/根目录。"
                    else
                        echo "未找到要传送的文件。"
                    fi
                    break
                    ;;
                *)
                    echo "注意: 目前备份仅包含docker项目，不包含宝塔，1panel等建站面板的数据备份。"
                    break
                    ;;
                esac
            done
            ;;
        r)
            root_use
            echo "可用的应用备份"
            echo -e "${gl_huang}------------------------${gl_bai}"
            ls -lt /app*.gz | awk '{print $NF}'
            echo ""
            read -r -e -p "回车键还原最新的备份，输入备份文件名还原指定的备份，输入0退出：" filename

            if [ "$filename" == "0" ]; then
                break_end
                linux_panel
            fi

            # 如果用户没有输入文件名，使用最新的压缩包
            if [ -z "$filename" ]; then
                local filename=$(ls -t /app*.tar.gz | head -1)
            fi

            if [ -n "$filename" ]; then
                echo -e "${gl_huang}正在解压 $filename ...${gl_bai}"
                cd / && tar -xzf "$filename"
                echo "应用数据已还原，目前请手动进入指定应用菜单，更新应用，即可还原应用。"
            else
                echo "没有找到压缩包。"
            fi
            ;;
        0)
            mobufan
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
	 *)
           ;;
	esac
	break_end
	sub_choice=""
done
}

linux_ldnmp() {
    while true; do
        clear
        echo -e "${gl_zi}>>> LDNMP建站${gl_bai}"
        ldnmp_tato
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}1.  ${gl_bai}安装LDNMP环境 ${gl_huang}★${gl_bai}           ${gl_bufan}2.  ${gl_bai}安装WordPress ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}安装Discuz论坛            ${gl_bufan}4.  ${gl_bai}安装可道云桌面"
        echo -e "${gl_bufan}5.  ${gl_bai}安装苹果CMS影视站         ${gl_bufan}6.  ${gl_bai}安装独角数发卡网"
        echo -e "${gl_bufan}7.  ${gl_bai}安装flarum论坛网站        ${gl_bufan}8.  ${gl_bai}安装typecho轻量博客网站"
        echo -e "${gl_bufan}9.  ${gl_bai}安装LinkStack共享链接平台 ${gl_bufan}20. ${gl_bai}自定义动态站点"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}21. ${gl_bai}仅安装nginx ${gl_huang}★${gl_bai}             ${gl_bufan}22. ${gl_bai}站点重定向"
        echo -e "${gl_bufan}23. ${gl_bai}站点反向代理-IP+端口 ${gl_huang}★${gl_bai}    ${gl_bufan}24. ${gl_bai}站点反向代理-域名"
        echo -e "${gl_bufan}25. ${gl_bai}安装Bitwarden密码管理平台 ${gl_bufan}26. ${gl_bai}安装Halo博客网站"
        echo -e "${gl_bufan}27. ${gl_bai}安装AI绘画提示词生成器    ${gl_bufan}28. ${gl_bai}站点反向代理-负载均衡"
        echo -e "${gl_bufan}29. ${gl_bai}Stream四层代理转发        ${gl_bufan}30. ${gl_bai}自定义静态站点"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}31. ${gl_bai}站点数据管理 ${gl_huang}★${gl_bai}            ${gl_bufan}32. ${gl_bai}备份全站数据"
        echo -e "${gl_bufan}33. ${gl_bai}定时远程备份              ${gl_bufan}34. ${gl_bai}还原全站数据"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}35. ${gl_bai}防护LDNMP环境             ${gl_bufan}36. ${gl_bai}优化LDNMP环境"
        echo -e "${gl_bufan}37. ${gl_bai}更新LDNMP环境             ${gl_bufan}38. ${gl_bai}卸载LDNMP环境"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
            ldnmp_install_status_one
            ldnmp_install_all
            ;;
        2)
            ldnmp_wp
            ;;
        3)
            clear
            # Discuz论坛
            webname="Discuz论坛"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/discuz.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            wget -O latest.zip ${gh_proxy}github.com/kejilion/Website_source_code/raw/main/Discuz_X3.5_SC_UTF8_20250901.zip
            unzip latest.zip
            rm latest.zip

            restart_ldnmp

            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "表前缀: discuz_"
            ;;
        4)
            clear
            # 可道云桌面
            webname="可道云桌面"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/kdy.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            wget -O latest.zip ${gh_proxy}github.com/kalcaddle/kodbox/archive/refs/tags/1.50.02.zip
            unzip -o latest.zip
            rm latest.zip
            mv /etc/nginx/html/$yuming/kodbox* /etc/nginx/html/$yuming/kodbox
            restart_ldnmp

            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "数据库名: $dbname"
            echo "redis主机: redis"

            ;;
        5)
            clear
            # 苹果CMS
            webname="苹果CMS"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/maccms.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            # wget ${gh_proxy}github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && rm maccms10.zip
            wget ${gh_proxy}github.com/magicblack/maccms_down/raw/master/maccms10.zip && unzip maccms10.zip && mv maccms10-*/* . && rm -r maccms10-* && rm maccms10.zip
            cd /etc/nginx/html/$yuming/template/ && wget ${gh_proxy}github.com/kejilion/Website_source_code/raw/main/DYXS2.zip && unzip DYXS2.zip && rm /etc/nginx/html/$yuming/template/DYXS2.zip
            cp /etc/nginx/html/$yuming/template/DYXS2/asset/admin/Dyxs2.php /etc/nginx/html/$yuming/application/admin/controller
            cp /etc/nginx/html/$yuming/template/DYXS2/asset/admin/dycms.html /etc/nginx/html/$yuming/application/admin/view/system
            mv /etc/nginx/html/$yuming/admin.php /etc/nginx/html/$yuming/vip.php && wget -O /etc/nginx/html/$yuming/application/extra/maccms.php ${gh_proxy}raw.githubusercontent.com/kejilion/Website_source_code/main/maccms.php

            restart_ldnmp

            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "数据库端口: 3306"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "数据库前缀: mac_"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "安装成功后登录后台地址"
            echo "https://$yuming/vip.php"

            ;;
        6)
            clear
            # 独脚数卡
            webname="独脚数卡"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/dujiaoka.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            wget ${gh_proxy}github.com/assimon/dujiaoka/releases/download/2.0.6/2.0.6-antibody.tar.gz && tar -zxvf 2.0.6-antibody.tar.gz && rm 2.0.6-antibody.tar.gz

            restart_ldnmp

            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "数据库端口: 3306"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo ""
            echo "redis地址: redis"
            echo "redis密码: 默认不填写"
            echo "redis端口: 6379"
            echo ""
            echo "网站url: https://$yuming"
            echo "后台登录路径: /admin"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "用户名: admin"
            echo "密码: admin"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "登录时右上角如果出现红色error0请使用如下命令: "
            echo "我也很气愤独角数卡为啥这么麻烦，会有这样的问题！"
            echo "sed -i 's/ADMIN_HTTPS=false/ADMIN_HTTPS=true/g' /etc/nginx/html/$yuming/dujiaoka/.env"

            ;;
        7)
            clear
            # flarum论坛
            webname="flarum论坛"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/flarum.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            docker exec php rm -f /usr/local/etc/php/conf.d/optimized_php.ini

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming

            docker exec php sh -c "php -r \"copy('https://getcomposer.org/installer', 'composer-setup.php');\""
            docker exec php sh -c "php composer-setup.php"
            docker exec php sh -c "php -r \"unlink('composer-setup.php');\""
            docker exec php sh -c "mv composer.phar /usr/local/bin/composer"

            docker exec php composer create-project flarum/flarum /var/www/html/$yuming
            docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum-lang/chinese-simplified"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require flarum/extension-manager:*"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/polls"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/sitemap"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/oauth"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require fof/best-answer:*"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require v17development/flarum-seo"
            docker exec php sh -c "cd /var/www/html/$yuming && composer require clarkwinkelmann/flarum-ext-emojionearea"

            restart_ldnmp

            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "表前缀: flarum_"
            echo "管理员信息自行设置"

            ;;

        8)
            clear
            # typecho
            webname="typecho"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/typecho.com.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            wget -O latest.zip ${gh_proxy}github.com/typecho/typecho/releases/latest/download/typecho.zip
            unzip latest.zip
            rm latest.zip

            restart_ldnmp

            clear
            ldnmp_web_on
            echo "数据库前缀: typecho_"
            echo "数据库地址: mysql"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "数据库名: $dbname"

            ;;

        9)
            clear
            # LinkStack
            webname="LinkStack"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/refs/heads/main/index_php.conf
            sed -i "s|/var/www/html/yuming.com/|/var/www/html/yuming.com/linkstack|g" /etc/nginx/conf.d/$yuming.conf
            sed -i "s|yuming.com|$yuming|g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming
            wget -O latest.zip ${gh_proxy}github.com/linkstackorg/linkstack/releases/latest/download/linkstack.zip
            unzip latest.zip
            rm latest.zip

            restart_ldnmp

            clear
            ldnmp_web_on
            echo "数据库地址: mysql"
            echo "数据库端口: 3306"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            ;;

        20)
            clear
            webname="PHP动态站点"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            ldnmp_install_status
            install_ssltls
            certs_status
            add_db
            wget -O /etc/nginx/conf.d/map.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/map.conf
            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/index_php.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming

            clear
            echo -e "[${gl_huang}1/6${gl_bai}] 上传PHP源码"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "目前只允许上传zip格式的源码包，请将源码包放到/etc/nginx/html/${yuming}目录下"
            read -e -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

            if [ -n "$url_download" ]; then
                wget "$url_download"
            fi

            unzip $(ls -t *.zip | head -n 1)
            rm -f $(ls -t *.zip | head -n 1)

            clear
            echo -e "[${gl_huang}2/6${gl_bai}] index.php所在路径"
            echo -e "${gl_huang}------------------------${gl_bai}"
            # find "$(realpath .)" -name "index.php" -print
            find "$(realpath .)" -name "index.php" -print | xargs -I {} dirname {}

            read -e -p "请输入index.php的路径，类似（/etc/nginx/html/$yuming/wordpress/）： " index_lujing

            sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /etc/nginx/conf.d/$yuming.conf
            sed -i "s#/etc/nginx/#/var/www/#g" /etc/nginx/conf.d/$yuming.conf

            clear
            echo -e "[${gl_huang}3/6${gl_bai}] 请选择PHP版本"
            echo -e "${gl_huang}------------------------${gl_bai}"
            read -e -p "1. php最新版 | 2. php7.4 : " pho_v
            case "$pho_v" in
            1)
                sed -i "s#php:9000#php:9000#g" /etc/nginx/conf.d/$yuming.conf
                local PHP_Version="php"
                ;;
            2)
                sed -i "s#php:9000#php74:9000#g" /etc/nginx/conf.d/$yuming.conf
                local PHP_Version="php74"
                ;;
            *)
                echo "无效的选择，请重新输入。"
                ;;
            esac

            clear
            echo -e "[${gl_huang}4/6${gl_bai}] 安装指定扩展"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "已经安装的扩展"
            docker exec php php -m

            read -e -p "$(echo -e "输入需要安装的扩展名称，如 ${gl_huang}SourceGuardian imap ftp${gl_bai} 等等。直接回车将跳过安装 ： ")" php_extensions
            if [ -n "$php_extensions" ]; then
                docker exec $PHP_Version install-php-extensions $php_extensions
            fi

            clear
            echo -e "[${gl_huang}5/6${gl_bai}] 编辑站点配置"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "按任意键继续，可以详细设置站点配置，如伪静态等内容"
            read -n 1 -s -r -p ""
            install nano
            nano /etc/nginx/conf.d/$yuming.conf

            clear
            echo -e "[${gl_huang}6/6${gl_bai}] 数据库管理"
            echo -e "${gl_huang}------------------------${gl_bai}"
            read -e -p "1. 我搭建新站        2. 我搭建老站有数据库备份： " use_db
            case $use_db in
            1)
                echo
                ;;
            2)
                echo "数据库备份必须是.gz结尾的压缩包。请放到/home/目录下，支持宝塔/1panel备份数据导入。"
                read -e -p "也可以输入下载链接，远程下载备份数据，直接回车将跳过远程下载： " url_download_db

                cd /home/
                if [ -n "$url_download_db" ]; then
                    wget "$url_download_db"
                fi
                gunzip $(ls -t *.gz | head -n 1)
                latest_sql=$(ls -t *.sql | head -n 1)
                dbrootpasswd=$(grep -oP 'MYSQL_ROOT_PASSWORD:\s*\K.*' /etc/nginx/docker-compose.yml | tr -d '[:space:]')
                docker exec -i mysql mysql -u root -p"$dbrootpasswd" $dbname <"/home/$latest_sql"
                echo "数据库导入的表数据"
                docker exec -i mysql mysql -u root -p"$dbrootpasswd" -e "USE $dbname; SHOW TABLES;"
                rm -f *.sql
                echo "数据库导入完成"
                ;;
            *)
                echo
                ;;
            esac

            docker exec php rm -f /usr/local/etc/php/conf.d/optimized_php.ini

            restart_ldnmp
            ldnmp_web_on
            prefix="web$(shuf -i 10-99 -n 1)_"
            echo "数据库地址: mysql"
            echo "数据库名: $dbname"
            echo "用户名: $dbuse"
            echo "密码: $dbusepasswd"
            echo "表前缀: $prefix"
            echo "管理员登录信息自行设置"

            ;;

        21)
            # 仅安装nginx
            # ldnmp_install_status_one
            # nginx_install_all
            install nginx
            ;;

        22)
            clear
            webname="站点重定向"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            read -e -p "请输入跳转域名: " reverseproxy
            nginx_install_status
            install_ssltls
            certs_status

            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/rewrite.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            sed -i "s/baidu.com/$reverseproxy/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            docker exec nginx nginx -s reload

            nginx_web_on

            ;;

        23)
            ldnmp_Proxy
            find_container_by_host_port "$port"
            if [ -z "$docker_name" ]; then
                close_port "$port"
                echo "已阻止IP+端口访问该服务"
            else
                ip_address
                block_container_port "$docker_name" "$ipv4_address"
            fi

            ;;

        24)
            clear
            webname="反向代理-域名"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            echo -e "域名格式: ${gl_huang}google.com${gl_bai}"
            read -e -p "请输入你的反代域名: " fandai_yuming
            nginx_install_status
            install_ssltls
            certs_status

            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/reverse-proxy-domain.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            sed -i "s|fandaicom|$fandai_yuming|g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            docker exec nginx nginx -s reload

            nginx_web_on

            ;;

        25)
            clear
            webname="Bitwarden"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            nginx_install_status
            install_ssltls
            certs_status

            docker run -d \
                --name bitwarden \
                --restart=always \
                -p 3280:80 \
                -v /etc/nginx/html/$yuming/bitwarden/data:/data \
                vaultwarden/server
            duankou=3280
            reverse_proxy

            nginx_web_on

            ;;

        26)
            clear
            webname="halo"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            nginx_install_status
            install_ssltls
            certs_status

            docker run -d --name halo --restart=always -p 8010:8090 -v /etc/nginx/html/$yuming/.halo2:/root/.halo2 halohub/halo:2
            duankou=8010
            reverse_proxy

            nginx_web_on

            ;;

        27)
            clear
            webname="AI绘画提示词生成器"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            nginx_install_status
            install_ssltls
            certs_status

            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/html.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming

            wget ${gh_proxy}github.com/kejilion/Website_source_code/raw/refs/heads/main/ai_prompt_generator.zip
            unzip $(ls -t *.zip | head -n 1)
            rm -f $(ls -t *.zip | head -n 1)

            docker exec nginx chmod -R nginx:nginx /var/www/html
            docker exec nginx nginx -s reload

            nginx_web_on

            ;;

        28)
            ldnmp_Proxy_backend
            ;;

        29)
            stream_panel
            ;;

        30)
            clear
            webname="静态站点"
            send_stats "安装$webname"
            echo "开始部署 $webname"
            add_yuming
            repeat_add_yuming
            nginx_install_status
            install_ssltls
            certs_status

            wget -O /etc/nginx/conf.d/$yuming.conf ${gh_proxy}raw.githubusercontent.com/kejilion/nginx/main/html.conf
            sed -i "s/yuming.com/$yuming/g" /etc/nginx/conf.d/$yuming.conf
            nginx_http_on

            cd /etc/nginx/html
            mkdir $yuming
            cd $yuming

            clear
            echo -e "[${gl_huang}1/2${gl_bai}] 上传静态源码"
            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "目前只允许上传zip格式的源码包，请将源码包放到/etc/nginx/html/${yuming}目录下"
            read -e -p "也可以输入下载链接，远程下载源码包，直接回车将跳过远程下载： " url_download

            if [ -n "$url_download" ]; then
                wget "$url_download"
            fi

            unzip $(ls -t *.zip | head -n 1)
            rm -f $(ls -t *.zip | head -n 1)

            clear
            echo -e "[${gl_huang}2/2${gl_bai}] index.html所在路径"
            echo -e "${gl_huang}------------------------${gl_bai}"
            # find "$(realpath .)" -name "index.html" -print
            find "$(realpath .)" -name "index.html" -print | xargs -I {} dirname {}

            read -e -p "请输入index.html的路径，类似（/etc/nginx/html/$yuming/index/）： " index_lujing

            sed -i "s#root /var/www/html/$yuming/#root $index_lujing#g" /etc/nginx/conf.d/$yuming.conf
            sed -i "s#/etc/nginx/#/var/www/#g" /etc/nginx/conf.d/$yuming.conf

            docker exec nginx chmod -R nginx:nginx /var/www/html
            docker exec nginx nginx -s reload

            nginx_web_on
            ;;
        31)
            ldnmp_web_status
            ;;
        32)
            clear
            send_stats "LDNMP环境备份"

            local backup_filename="web_$(date +"%Y%m%d%H%M%S").tar.gz"
            echo -e "${gl_huang}正在备份 $backup_filename ...${gl_bai}"
            cd /home/ && tar czvf "$backup_filename" web

            while true; do
                clear
                echo -e "${gl_bai}备份文件已创建: ${gl_huang}/home/$backup_filename${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bai}要传送备份数据到远程服务器吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
                case "$choice" in
                [Yy])
                    read -e -p "请输入远端服务器IP:  " remote_ip
                    read -e -p "目标服务器SSH端口 [默认22]: " TARGET_PORT
                    local TARGET_PORT=${TARGET_PORT:-22}
                    if [ -z "$remote_ip" ]; then
                        echo "错误: 请输入远端服务器IP。"
                        continue
                    fi
                    local latest_tar=$(ls -t /home/*.tar.gz | head -1)
                    if [ -n "$latest_tar" ]; then
                        ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
                        sleep 2 # 添加等待时间
                        scp -P "$TARGET_PORT" -o StrictHostKeyChecking=no "$latest_tar" "root@$remote_ip:/home/"
                        echo "文件已传送至远程服务器home目录。"
                    else
                        echo "未找到要传送的文件。"
                    fi
                    break
                    ;;
                [Nn]) break ;;
                *) echo "无效的选择，请输入 Y 或 N。"
                    ;;
                esac
            done
            ;;

        33)
            clear
            send_stats "定时远程备份"
            read -e -p "输入远程服务器IP: " useip
            read -e -p "输入远程服务器密码: " usepasswd

            cd ~
            wget -O ${useip}_beifen.sh ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/beifen.sh >/dev/null 2>&1
            chmod +x ${useip}_beifen.sh

            sed -i "s/0.0.0.0/$useip/g" ${useip}_beifen.sh
            sed -i "s/123456/$usepasswd/g" ${useip}_beifen.sh

            echo -e "${gl_huang}------------------------${gl_bai}"
            echo "1. 每周备份                 2. 每天备份"
            read -e -p "请输入你的选择: " dingshi

            case $dingshi in
            1)
                check_crontab_installed
                read -e -p "选择每周备份的星期几 (0-6，0代表星期日): " weekday
                (
                    crontab -l
                    echo "0 0 * * $weekday ./${useip}_beifen.sh"
                ) | crontab - >/dev/null 2>&1
                ;;
            2)
                check_crontab_installed
                read -e -p "选择每天备份的时间（小时，0-23）: " hour
                (
                    crontab -l
                    echo "0 $hour * * * ./${useip}_beifen.sh"
                ) | crontab - >/dev/null 2>&1
                ;;
            *)
                break # 跳出
                ;;
            esac

            install sshpass

            ;;

        34)
            root_use
            send_stats "LDNMP环境还原"
            echo "可用的站点备份"
            echo -e "${gl_huang}------------------------${gl_bai}"
            ls -lt /home/*.gz | awk '{print $NF}'
            echo ""
            read -e -p "回车键还原最新的备份，输入备份文件名还原指定的备份，输入0退出：" filename

            if [ "$filename" == "0" ]; then
                break_end
                linux_ldnmp
            fi

            # 如果用户没有输入文件名，使用最新的压缩包
            if [ -z "$filename" ]; then
                local filename=$(ls -t /home/*.tar.gz | head -1)
            fi

            if [ -n "$filename" ]; then
                cd /etc/nginx/ >/dev/null 2>&1
                docker compose down >/dev/null 2>&1
                rm -rf /etc/nginx >/dev/null 2>&1

                echo -e "${gl_huang}正在解压 $filename ...${gl_bai}"
                cd /home/ && tar -xzf "$filename"

                check_port
                install_dependency
                install_docker
                install_certbot
                install_ldnmp
            else
                echo "没有找到压缩包。"
            fi

            ;;

        35)
            web_security
            ;;
        36)
            web_optimization
            ;;
        37)
            root_use
            while true; do
                clear
                send_stats "更新LDNMP环境"
                echo "更新LDNMP环境"
                echo -e "${gl_huang}------------------------${gl_bai}"
                ldnmp_v
                echo "发现新版本的组件"
                echo -e "${gl_huang}------------------------${gl_bai}"
                check_docker_image_update nginx
                if [ -n "$update_status" ]; then
                    echo -e "${gl_huang}nginx $update_status${gl_bai}"
                fi
                check_docker_image_update php
                if [ -n "$update_status" ]; then
                    echo -e "${gl_huang}php $update_status${gl_bai}"
                fi
                check_docker_image_update mysql
                if [ -n "$update_status" ]; then
                    echo -e "${gl_huang}mysql $update_status${gl_bai}"
                fi
                check_docker_image_update redis
                if [ -n "$update_status" ]; then
                    echo -e "${gl_huang}redis $update_status${gl_bai}"
                fi
                echo -e "${gl_huang}------------------------${gl_bai}"
                echo
                echo "1. 更新nginx               2. 更新mysql              3. 更新php              4. 更新redis"
                echo -e "${gl_huang}------------------------${gl_bai}"
                echo "5. 更新完整环境"
                echo -e "${gl_huang}------------------------${gl_bai}"
                echo "0. 返回上一级选单"
                echo -e "${gl_huang}------------------------${gl_bai}"
                read -e -p "请输入你的选择: " sub_choice
                case $sub_choice in
                1)
                    nginx_upgrade

                    ;;

                2)
                    local ldnmp_pods="mysql"
                    read -e -p "请输入${ldnmp_pods}版本号 （如: 8.0 8.3 8.4 9.0）（回车获取最新版）: " version
                    local version=${version:-latest}

                    cd /etc/nginx/
                    cp /etc/nginx/docker-compose.yml /etc/nginx/docker-compose1.yml
                    sed -i "s/image: mysql/image: mysql:${version}/" /etc/nginx/docker-compose.yml
                    docker rm -f $ldnmp_pods
                    docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi >/dev/null 2>&1
                    docker compose up -d --force-recreate $ldnmp_pods
                    docker restart $ldnmp_pods
                    cp /etc/nginx/docker-compose1.yml /etc/nginx/docker-compose.yml
                    send_stats "更新$ldnmp_pods"
                    echo "更新${ldnmp_pods}完成"

                    ;;
                3)
                    local ldnmp_pods="php"
                    read -e -p "请输入${ldnmp_pods}版本号 （如: 7.4 8.0 8.1 8.2 8.3）（回车获取最新版）: " version
                    local version=${version:-8.3}
                    cd /etc/nginx/
                    cp /etc/nginx/docker-compose.yml /etc/nginx/docker-compose1.yml
                    sed -i "s/kjlion\///g" /etc/nginx/docker-compose.yml >/dev/null 2>&1
                    sed -i "s/image: php:fpm-alpine/image: php:${version}-fpm-alpine/" /etc/nginx/docker-compose.yml
                    docker rm -f $ldnmp_pods
                    docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi >/dev/null 2>&1
                    docker images --filter=reference="kjlion/${ldnmp_pods}*" -q | xargs docker rmi >/dev/null 2>&1
                    docker compose up -d --force-recreate $ldnmp_pods
                    docker exec php chown -R www-data:www-data /var/www/html

                    run_command docker exec php sed -i "s/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g" /etc/apk/repositories >/dev/null 2>&1

                    docker exec php apk update
                    curl -sL ${gh_proxy}github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions -o /usr/local/bin/install-php-extensions
                    docker exec php mkdir -p /usr/local/bin/
                    docker cp /usr/local/bin/install-php-extensions php:/usr/local/bin/
                    docker exec php chmod +x /usr/local/bin/install-php-extensions
                    docker exec php install-php-extensions mysqli pdo_mysql gd intl zip exif bcmath opcache redis imagick soap

                    docker exec php sh -c 'echo "upload_max_filesize=50M " > /usr/local/etc/php/conf.d/uploads.ini' >/dev/null 2>&1
                    docker exec php sh -c 'echo "post_max_size=50M " > /usr/local/etc/php/conf.d/post.ini' >/dev/null 2>&1
                    docker exec php sh -c 'echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory.ini' >/dev/null 2>&1
                    docker exec php sh -c 'echo "max_execution_time=1200" > /usr/local/etc/php/conf.d/max_execution_time.ini' >/dev/null 2>&1
                    docker exec php sh -c 'echo "max_input_time=600" > /usr/local/etc/php/conf.d/max_input_time.ini' >/dev/null 2>&1
                    docker exec php sh -c 'echo "max_input_vars=5000" > /usr/local/etc/php/conf.d/max_input_vars.ini' >/dev/null 2>&1

                    fix_phpfpm_con $ldnmp_pods

                    docker restart $ldnmp_pods >/dev/null 2>&1
                    cp /etc/nginx/docker-compose1.yml /etc/nginx/docker-compose.yml
                    send_stats "更新$ldnmp_pods"
                    echo "更新${ldnmp_pods}完成"

                    ;;
                4)
                    local ldnmp_pods="redis"
                    cd /etc/nginx/
                    docker rm -f $ldnmp_pods
                    docker images --filter=reference="$ldnmp_pods*" -q | xargs docker rmi >/dev/null 2>&1
                    docker compose up -d --force-recreate $ldnmp_pods
                    docker restart $ldnmp_pods >/dev/null 2>&1
                    restart_redis
                    send_stats "更新$ldnmp_pods"
                    echo "更新${ldnmp_pods}完成"

                    ;;
                5)
                    read -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}长时间不更新环境的用户，请慎重更新LDNMP环境，会有数据库更新失败的风险。确定更新LDNMP环境吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
                    case "$choice" in
                    [Yy])
                        send_stats "完整更新LDNMP环境"
                        cd /etc/nginx/
                        docker compose down --rmi all

                        check_port
                        install_dependency
                        install_docker
                        install_certbot
                        install_ldnmp
                        ;;
                    *) ;;
                    esac
                    ;;
                *)
                    break
                    ;;
                esac
                break_end
            done

            ;;

        38)
            root_use
            send_stats "卸载LDNMP环境"
            read -e -p "$(echo -e "${gl_hong}强烈建议：${gl_bai}先备份全部网站数据，再卸载LDNMP环境。确定删除所有网站数据吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                cd /etc/nginx/
                docker compose down --rmi all
                docker compose -f docker-compose.phpmyadmin.yml down >/dev/null 2>&1
                docker compose -f docker-compose.phpmyadmin.yml down --rmi all >/dev/null 2>&1
                rm -rf /etc/nginx
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;

        0) mobufan ;;
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}


########################################
# 公共函数：挂载远程 Samba/CIFS 共享
# 依赖变量/函数：
#   gl_xxx 颜色变量、log_info/log_ok/log_warn/log_error
#   handle_invalid_input / exit_script
# 用法：直接调用  mount_cifs_share  即可（无参数）
########################################
mount_cifs_share() {
    # 1. 安装必要工具
    if ! command -v mount.cifs &>/dev/null || ! command -v smbclient &>/dev/null; then
        log_info "正在安装必要的CIFS工具..."
        if command -v apt &>/dev/null; then
            apt update && apt install cifs-utils smbclient -y
        elif command -v yum &>/dev/null; then
            yum install cifs-utils samba-client -y
        elif command -v dnf &>/dev/null; then
            dnf install cifs-utils samba-client -y
        else
            log_error "不支持的包管理器，请手动安装 cifs-utils 与 smbclient"
            return 1
        fi
        log_ok "CIFS 工具安装完成"
    else
        log_ok "必要的 CIFS 工具已安装"
    fi

    # 2. 输入服务器 IP 并检测连通性
    read -r -e -p "$(echo -e "${gl_bai}请输入 Samba 服务器 IP 地址: ")" server_ip
    log_info "测试网络连通性..."
    if ! ping -c 1 -W 1 "$server_ip" &>/dev/null; then
        log_warn "无法 ping 通服务器 $server_ip"
        read -r -e -p "$(echo -e "${gl_bai}是否继续? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" continue_anyway
        [[ ! $continue_anyway =~ ^[Yy]$ ]] && return 1
    else
        log_ok "网络连通性正常"
    fi

    # 3. 列举共享
    echo -e "${gl_bufan}------------------------------------${gl_bai}"
    log_info "正在查看 Samba 服务器信息..."
    shares_list=$(smbclient -L "//$server_ip" -N 2>/dev/null \
                  | grep -E "^\s*[^[:space:]]+\s+Disk\s+" | awk '{print $1}')
    log_info "可用共享列表："
    echo "$shares_list" | while read -r share; do echo "     - $share"; done
    echo -e "${gl_bufan}------------------------------------${gl_bai}"

    # 4. 选择共享
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入 Samba 共享名称 (输入 '${gl_huang}quit${gl_bai}' 退出): ")" share_name
        [[ $share_name == "quit" ]] && { log_info "操作已取消"; return 0; }
        echo "$shares_list" | grep -q "^$share_name$" && { log_ok "共享名称验证成功"; break; }
        log_error "共享名称 '$share_name' 不存在，请重新输入"
    done

    # 5. 认证信息
    read -r -e -p "$(echo -e "${gl_bai}请输入 Samba 用户名 (留空使用匿名访问): ")" samba_user
    if [[ -n $samba_user ]]; then
        read -r -s -p "$(echo -e "${gl_bai}请输入 Samba 密码: ")" samba_pass
        echo
    fi

    # 6. 本地挂载点
    read -r -e -p "$(echo -e "${gl_bai}请输入本地挂载目录路径 (默认为 /mnt/${share_name}): ")" mount_dir
    mount_dir=${mount_dir:-/mnt/${share_name}}
    log_info "创建挂载目录：$mount_dir"
    mkdir -p "$mount_dir" && chmod 755 "$mount_dir"

    # 7. 测试连接
    log_info "测试 Samba 连接..."
    if [[ -n $samba_user ]]; then
        test_result=$(echo "exit" | smbclient "//$server_ip/$share_name" -U "$samba_user" "$samba_pass" -c "ls" 2>&1)
    else
        test_result=$(echo "exit" | smbclient "//$server_ip/$share_name" -N -c "ls" 2>&1)
    fi

    if grep -q "NT_STATUS_ACCESS_DENIED" <<<"$test_result"; then
        log_error "连接测试失败：访问被拒绝"
        read -r -e -p "$(echo -e "${gl_bai}是否继续尝试挂载? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" continue_mount
        [[ ! $continue_mount =~ ^[Yy]$ ]] && return 1
    elif grep -q "NT_STATUS_BAD_NETWORK_NAME" <<<"$test_result"; then
        log_error "连接测试失败：共享名称错误"; return 1
    elif grep -q "session setup failed" <<<"$test_result"; then
        log_error "连接测试失败：会话建立失败"; return 1
    else
        log_ok "连接测试成功"
    fi

    # 8. 执行挂载
    log_info "正在挂载 Samba 共享..."
    if [[ -n $samba_user ]]; then
        cred_file=$(mktemp)
        echo -e "username=$samba_user\npassword=$samba_pass" > "$cred_file"
        chmod 600 "$cred_file"
        mount -t cifs "//$server_ip/$share_name" "$mount_dir" \
              -o credentials="$cred_file",uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0
        rm -f "$cred_file"
    else
        mount -t cifs "//$server_ip/$share_name" "$mount_dir" \
              -o guest,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0
    fi

    # 9. 检查挂载结果
    if mountpoint -q "$mount_dir"; then
        echo -e "${gl_bufan}------------------------------------${gl_bai}"
        log_ok "Samba 共享挂载成功！"
        echo -e "${gl_bai}服务器：//$server_ip/$share_name"
        echo -e "${gl_bai}挂载点：$mount_dir"
        echo -e "${gl_bai}用户名：${samba_user:-匿名}"
        echo -e "${gl_bufan}------------------------------------${gl_bai}"
        df -h | grep "$mount_dir"
    else
        log_error "挂载失败，请检查 dmesg 或上述提示"
        dmesg | tail -10
        return 1
    fi

    # 10. 可选：写入 /etc/fstab
    read -r -e -p "$(echo -e "${gl_bai}是否添加到 /etc/fstab 实现开机自动挂载? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" add_fstab
    if [[ $add_fstab =~ ^[Yy]$ ]]; then
        if [[ -n $samba_user ]]; then
            cred_dir="/etc/samba/credentials"
            mkdir -p "$cred_dir"
            cred_file="$cred_dir/${server_ip}_${share_name}"
            echo -e "username=$samba_user\npassword=$samba_pass" > "$cred_file"
            chmod 600 "$cred_file"
            fstab_entry="//$server_ip/$share_name $mount_dir cifs credentials=$cred_file,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0 0 0"
        else
            fstab_entry="//$server_ip/$share_name $mount_dir cifs guest,uid=$(id -u),gid=$(id -g),file_mode=0644,dir_mode=0755,vers=3.0 0 0"
        fi
        grep -q "$fstab_entry" /etc/fstab || echo "$fstab_entry" >> /etc/fstab
        log_ok "已写入 /etc/fstab"
    fi
}



########################################
# 公共函数：卸载已挂载的 Samba/CIFS 目录
#        并清理 /etc/fstab 对应条目
# 依赖：全局颜色变量、日志函数
# 用法：直接调用  unmount_samba_shares  即可
########################################
unmount_samba_shares() {
    log_info "开始扫描已挂载的 Samba/CIFS 共享..."

    # 1. 获取当前已挂载的 CIFS 列表
    mapfile -t mounted_shares < <(mount | awk -F' on ' '$0~" type cifs "{
        split($2,arr," type"); gsub(/ /,"",arr[1]); print arr[1]}')

    if ((${#mounted_shares[@]} == 0)); then
        log_ok "当前没有挂载任何 Samba/CIFS 共享"
        return 0
    fi

    # 2. 交互选择要卸载的挂载点
    echo -e "${gl_bufan}------------------------------------${gl_bai}"
    log_info "已发现以下挂载点："
    for idx in "${!mounted_shares[@]}"; do
        echo -e "${gl_bufan}$((idx+1)).${gl_bai} ${mounted_shares[idx]}"
    done
    echo -e "${gl_bufan}0. ${gl_bai}返回上一级菜单"
    echo -e "${gl_bufan}------------------------------------${gl_bai}"

    while true; do
        read -r -p "$(echo -e "${gl_bai}请选择要卸载的序号 (输入 0 返回): ")" choice
        case $choice in
            0) return 0 ;;
            *[0-9]*)
                if ((choice>0 && choice<=${#mounted_shares[@]})); then
                    target_mount="${mounted_shares[$((choice-1))]}"
                    break
                else
                    handle_invalid_input
                fi ;;
            *) handle_invalid_input ;;
        esac
    done

    # 3. 卸载
    log_info "正在卸载：$target_mount"
    if umount "$target_mount" 2>/dev/null; then
        log_ok "卸载成功"
    else
        log_warn "卸载失败，尝试强制卸载..."
        umount -l "$target_mount" 2>/dev/null && log_ok "强制卸载完成" || {
            log_error "强制卸载也失败，请检查占用情况"; return 1; }
    fi

    # 4. 清理 /etc/fstab
    log_info "清理 /etc/fstab 对应条目..."
    # 先备份
    cp /etc/fstab /etc/fstab.bak.$(date +%F_%T) 2>/dev/null || true

    # 删除匹配行（兼容空格差异）
    sed -i "\|^//[^[:space:]]*[[:space:]]*$target_mount[[:space:]]*cifs|d" /etc/fstab
    log_ok "已移除 /etc/fstab 对应开机挂载项"

    echo -e "${gl_bufan}------------------------------------${gl_bai}"
    log_ok "卸载并清理完成！"
}







########################################
# 公共函数：一键完成 Samba 共享配置
# 依赖：全局颜色变量、日志函数、handle_invalid_input、exit_script
# 用法：直接调用  config_samba_share  即可
########################################
config_samba_share() {
    # 1. 安装 Samba
    log_info "正在安装 Samba 服务..."
    if command -v apt &>/dev/null; then
        apt update >/dev/null 2>&1 && apt install samba -y >/dev/null 2>&1
    elif command -v yum &>/dev/null; then
        yum install samba -y >/dev/null 2>&1
    elif command -v dnf &>/dev/null; then
        dnf install samba -y >/dev/null 2>&1
    else
        log_error "不支持的包管理器"; return 1
    fi
    log_ok "Samba 安装成功"

    # 2. 共享目录
    read -r -e -p "$(echo -e "${gl_bai}请输入共享目录路径（默认为 /mnt）: ")" input
    share_dir="${input:-/mnt}"
    [[ $share_dir =~ ^/.* ]] || { log_error "目录必须以 / 开头"; return 1; }
    mkdir -p "$share_dir" && chmod 777 "$share_dir"
    log_ok "共享目录已创建：$share_dir"

    # 3. Samba 用户
    read -r -e -p "$(echo -e "${gl_bai}请输入 Samba 用户名（默认为 root）: ")" input
    samba_user="${input:-root}"
    [[ $samba_user =~ ^[a-z_][a-z0-9_-]*$ ]] || { log_error "用户名格式非法"; return 1; }

    user_created=false
    if ! id "$samba_user" &>/dev/null; then
        useradd "$samba_user" && user_created=true
        log_ok "系统用户创建：$samba_user"
    else
        log_ok "使用已有系统用户：$samba_user"
    fi

    # 4. 设置密码
    if $user_created; then
        while true; do
            read -r -s -p "$(echo -e "${gl_bai}请输入 Samba 密码: ")" samba_pass
            echo
            read -r -s -p "$(echo -e "${gl_bai}请确认密码: ")" samba_pass_confirm
            echo
            [[ $samba_pass == "$samba_pass_confirm" && -n $samba_pass ]] && break
            log_error "密码为空或不匹配，请重新输入！"
        done
        echo -e "$samba_pass\n$samba_pass" | smbpasswd -a -s "$samba_user"
        log_ok "Samba 用户密码已设置"
    else
        while true; do
            read -r -p "$(echo -e "${gl_bai}是否修改 '$samba_user' 的 Samba 密码? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" change
            case ${change,,} in
                y|yes)
                    while true; do
                        read -r -s -p "$(echo -e "${gl_bai}请输入新密码: ")" samba_pass
                        echo
                        read -r -s -p "$(echo -e "${gl_bai}确认新密码: ")" samba_pass_confirm
                        echo
                        [[ $samba_pass == "$samba_pass_confirm" && -n $samba_pass ]] && break
                        log_error "密码为空或不匹配，请重新输入！"
                    done
                    echo -e "$samba_pass\n$samba_pass" | smbpasswd -s "$samba_user"
                    log_ok "Samba 密码已更新"
                    break
                    ;;
                n|no)
                    log_ok "保持原有密码"
                    break
                    ;;
                *) handle_invalid_input ;;
            esac
        done
    fi

    # 5. 共享名
    default_share_name=$(basename "$share_dir")
    [[ -z $default_share_name || $default_share_name == "/" ]] && default_share_name="share"
    while true; do
        echo -e "${gl_bufan}------------------------------------${gl_bai}"
        log_info "当前默认共享名：$default_share_name"
        read -r -p "$(echo -e "${gl_bai}是否修改共享名？回车或输 n 使用默认，y 自定义，q 退出: ")" ans
        case ${ans,,} in
            ""|n|no)  share_name=$default_share_name; log_ok "使用默认共享名：$share_name"; break ;;
            y|yes)
                read -r -p "$(echo -e "${gl_bai}请输入新的共享名: ")" custom_name
                [[ -z $custom_name ]] && { log_error "共享名不能为空"; continue; }
                share_name=$custom_name; log_ok "已设置自定义共享名：$share_name"; break
                ;;
            q|quit) log_info "用户主动退出"; exit 0 ;;
            *) handle_invalid_input ;;
        esac
    done

    # 6. 写入配置
    log_info "正在更新 Samba 配置..."
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak 2>/dev/null || true
    cat >> /etc/samba/smb.conf <<EOF
[$share_name]
    comment = Samba Share
    path = $share_dir
    guest ok = no
    read only = no
    writable = yes
    browseable = yes
    create mask = 0777
    directory mask = 0777
    force user = $samba_user
    force group = $samba_user
    valid users = root, $samba_user
    vfs objects = catia fruit streams_xattr
    fruit:encoding = native
    fruit:metadata = stream
    fruit:veto_appledouble = no
EOF
    log_ok "Samba 配置已更新"

    # 7. 重启服务
    log_info "正在重启 Samba 服务..."
    if command -v systemctl &>/dev/null; then
        systemctl restart smbd nmbd 2>/dev/null && { log_ok "Samba 服务重启成功"; } || log_warn "systemctl 重启失败，请手动重启"
    elif command -v service &>/dev/null; then
        service smbd restart 2>/dev/null && { log_ok "Samba 服务重启成功"; } || log_warn "service 重启失败，请手动重启"
    fi

    # 8. 输出连接信息
    ip_address=$(ip route get 1 2>/dev/null | awk '{print $7}' | head -1)
    [[ -z $ip_address ]] && ip_address=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo -e "${gl_bufan}------------------------------------${gl_bai}"
    log_ok "Samba 共享配置完成！"
    echo -e "${gl_bai}主机IP：${gl_huang}${ip_address:-无法获取}"
    echo -e "${gl_bai}共享目录：${gl_huang}$share_dir"
    echo -e "${gl_bai}共享名：${gl_huang}$share_name"
    echo -e "${gl_bai}用户名：${gl_huang}$samba_user"
    echo -e "${gl_bai}Win11 访问：${gl_huang}\\\\${ip:-服务器IP}\\$share_name"
    echo -e "${gl_bai}Linux 测试：${gl_huang}smbclient //${ip:-服务器IP}/$share_name -U $samba_user"
    echo -e "${gl_bufan}------------------------------------${gl_bai}"
}

menu_samba_manager() {
    while true; do
        clear
        echo -e "${gl_zi}>>> Samba 共享管理${gl_bai}"
        echo -e "${gl_bufan}------------------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}配置 Samba 共享（安装/创建/设置）"
        echo -e "${gl_bufan}2. ${gl_bai}挂载远程 Samba/CIFS 共享"
        echo -e "${gl_bufan}3. ${gl_bai}卸载已挂载的 Samba 共享"
        echo -e "${gl_bufan}------------------------------------${gl_bai}"
	echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------------------${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}请选择操作: ")" choice
        case $choice in
            1) config_samba_share      ;;
            2) mount_cifs_share        ;;
            3) unmount_samba_shares    ;;
            00|000|0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
            0) break                   ;;
            *) handle_invalid_input    ;;
        esac
        echo
        read -r -p "$(echo -e "${gl_bai}按任意键继续...")" -n 1 -s
    done
}


linux_Settings() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 系统工具${gl_bai}"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}1.  ${gl_bai}设置脚本启动快捷键  ${gl_bufan}2.  ${gl_bai}修改登录密码"
        echo -e "${gl_bufan}3.  ${gl_bai}ROOT密码登录模式    ${gl_bufan}4.  ${gl_bai}安装Python指定版本"
        echo -e "${gl_bufan}5.  ${gl_bai}开放所有端口        ${gl_bufan}6.  ${gl_bai}修改SSH连接端口"
        echo -e "${gl_bufan}7.  ${gl_bai}优化DNS地址         ${gl_bufan}8.  ${gl_bai}一键重装系统 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}9.  ${gl_bai}禁用ROOT创建新账户  ${gl_bufan}10. ${gl_bai}切换优先ipv4/ipv6"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}11. ${gl_bai}查看端口占用状态    ${gl_bufan}12. ${gl_bai}修改虚拟内存大小"
        echo -e "${gl_bufan}13. ${gl_bai}用户管理            ${gl_bufan}14. ${gl_bai}用户/密码生成器"
        echo -e "${gl_bufan}15. ${gl_bai}系统时区调整        ${gl_bufan}16. ${gl_bai}设置BBR3加速"
        echo -e "${gl_bufan}17. ${gl_bai}防火墙高级管理器    ${gl_bufan}18. ${gl_bai}修改主机名"
        echo -e "${gl_bufan}19. ${gl_bai}切换系统更新源      ${gl_bufan}20. ${gl_bai}定时任务管理"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}21. ${gl_bai}本机host解析        ${gl_bufan}22. ${gl_bai}SSH防御程序"
        echo -e "${gl_bufan}23. ${gl_bai}限流自动关机        ${gl_bufan}24. ${gl_bai}ROOT私钥登录模式"
        echo -e "${gl_bufan}25. ${gl_bai}TG-bot系统监控预警  ${gl_bufan}26. ${gl_bai}修复OpenSSH高危漏洞"
        echo -e "${gl_bufan}27. ${gl_bai}红帽系Linux内核升级 ${gl_bufan}28. ${gl_bai}Linux系统内核参数优化"
        echo -e "${gl_bufan}29. ${gl_bai}病毒扫描工具 ${gl_huang}★${gl_bai}      ${gl_bufan}30. ${gl_bai}文件管理器"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}31. ${gl_bai}切换系统语言        ${gl_bufan}32. ${gl_bai}命令行美化工具 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}33. ${gl_bai}设置系统回收站      ${gl_bufan}34. ${gl_bai}系统备份与恢复"
        echo -e "${gl_bufan}35. ${gl_bai}ssh远程连接工具     ${gl_bufan}36. ${gl_bai}硬盘分区管理工具"
        echo -e "${gl_bufan}37. ${gl_bai}命令行历史记录      ${gl_bufan}38. ${gl_bai}rsync远程同步工具"
        echo -e "${gl_bufan}39. ${gl_bai}命令收藏夹 ${gl_huang}★${gl_bai}        ${gl_bufan}40. ${gl_bai}Samba共享配置 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}41. ${gl_bai}留言板              ${gl_bufan}66. ${gl_bai}一条龙系统调优 ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}99. ${gl_bai}重启服务器          ${gl_bufan}100.${gl_bai}隐私与安全"
        echo -e "${gl_bufan}101.${gl_bai}m命令高级用法 ${gl_huang}★${gl_bai}     ${gl_bufan}102.${gl_bai}卸载mobufan脚本"
        echo -e "${gl_bufan}------------------------------------------------"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
            while true; do
                clear
                read -r -e -p "$(echo -e "${gl_bai}请输入你的快捷按键（输入${gl_bufan}0${gl_bai}退出）: ")" kuaijiejian
                if [ "$kuaijiejian" == "0" ]; then
                    break_end
                    linux_Settings "$@"
                fi
                find /usr/local/bin/ -type l -exec bash -c 'test "$(readlink -f {})" = "/usr/local/bin/m" && rm -f {}' \;
                ln -s /usr/local/bin/m /usr/local/bin/"$kuaijiejian"
                echo "快捷键已设置"
                break_end
                linux_Settings "$@"
            done
            ;;
        2)
            clear
            echo "设置你的登录密码"
            passwd
            ;;
        3)
            root_use
            add_sshpasswd
            ;;
        4)
            root_use
            echo -e "${gl_zi}>>> python版本管理${gl_bai}"
            echo -e "${gl_bai}视频介绍: ${gl_lv}https://www.bilibili.com/video/BV1Pm42157cK?t=0.1"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo "该功能可无缝安装python官方支持的任何版本！"
            local VERSION=$(python3 -V 2>&1 | awk '{print $2}')
            echo -e "当前python版本号: ${gl_huang}$VERSION${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bai}推荐版本:  ${gl_lv}3.12    3.11    3.10    3.9    3.8    2.7"
            echo -e "${gl_bai}查询更多版本: ${gl_lv}https://www.python.org/downloads/"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}输入你要安装的${gl_lv}python${gl_bai}版本号 (输入 ${gl_hong}0${gl_bai} 退出): ")" py_new_v

            if [[ "$py_new_v" == "0" ]]; then
                break_end
                linux_Settings "$@"
            fi

            if ! grep -q 'export PYENV_ROOT="\$HOME/.pyenv"' ~/.bashrc; then
                if command -v yum &>/dev/null; then
                    yum update -y && yum install git -y
                    yum groupinstall "Development Tools" -y
                    yum install openssl-devel bzip2-devel libffi-devel ncurses-devel zlib-devel readline-devel sqlite-devel xz-devel findutils -y

                    curl -O https://www.openssl.org/source/openssl-1.1.1u.tar.gz
                    tar -xzf openssl-1.1.1u.tar.gz
                    cd openssl-1.1.1u
                    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
                    make
                    make install
                    echo "/usr/local/openssl/lib" >/etc/ld.so.conf.d/openssl-1.1.1u.conf
                    ldconfig -v
                    cd ..

                    export LDFLAGS="-L/usr/local/openssl/lib"
                    export CPPFLAGS="-I/usr/local/openssl/include"
                    export PKG_CONFIG_PATH="/usr/local/openssl/lib/pkgconfig"

                elif command -v apt &>/dev/null; then
                    apt update -y && apt install git -y
                    apt install build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev libgdbm-dev libnss3-dev libedit-dev -y
                elif command -v apk &>/dev/null; then
                    apk update && apk add git
                    apk add --no-cache bash gcc musl-dev libffi-dev openssl-dev bzip2-dev zlib-dev readline-dev sqlite-dev libc6-compat linux-headers make xz-dev build-base ncurses-dev
                else
                    echo "未知的包管理器!"
                    return
                fi

                curl https://pyenv.run | bash
                cat <<EOF >>~/.bashrc

export PYENV_ROOT="\$HOME/.pyenv"
if [[ -d "\$PYENV_ROOT/bin" ]]; then
  export PATH="\$PYENV_ROOT/bin:\$PATH"
fi
eval "\$(pyenv init --path)"
eval "\$(pyenv init -)"
eval "\$(pyenv virtualenv-init -)"

EOF

            fi

            sleep 1
            source ~/.bashrc
            sleep 1
            pyenv install "$py_new_v"
            pyenv global "$py_new_v"

            rm -rf /tmp/python-build.*
            rm -rf $(pyenv root)/cache/*

            local VERSION=$(python -V 2>&1 | awk '{print $2}')
            echo -e "当前python版本号: ${gl_huang}$VERSION${gl_bai}"
            ;;
        5)
            root_use
            iptables_open
            remove iptables-persistent ufw firewalld iptables-services >/dev/null 2>&1
            echo "端口已全部开放"
            ;;
        6)
            root_use
            while true; do
                clear
                sed -i 's/#Port/Port/' /etc/ssh/sshd_config

                # 读取当前的 SSH 端口号
                local current_port=$(grep -E '^ *Port [0-9]+' /etc/ssh/sshd_config | awk '{print $2}')

                # 打印当前的 SSH 端口号
                echo -e "当前的 SSH 端口号是:  ${gl_huang}$current_port ${gl_bai}"

                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo "端口号范围1到65535之间的数字。（输入0退出）"

                # 提示用户输入新的 SSH 端口号
                read -r -e -p "请输入新的 SSH 端口号: " new_port

                # 判断端口号是否在有效范围内
                if [[ $new_port =~ ^[0-9]+$ ]]; then # 检查输入是否为数字
                    if [[ $new_port -ge 1 && $new_port -le 65535 ]]; then
                        new_ssh_port
                    elif [[ $new_port -eq 0 ]]; then
                        break
                    else
                        echo "端口号无效，请输入1到65535之间的数字。"
                        break_end
                    fi
                else
                    echo "输入无效，请输入数字。"
                    break_end
                fi
            done
            ;;
        7)
            set_dns_ui
            ;;
        8)
            dd_xitong
            ;;
        9)
            root_use
            read -r -e -p "请输入新用户名（输入0退出）: " new_username
            if [ "$new_username" == "0" ]; then
                break_end
                linux_Settings "$@"
            fi
            useradd -m -s /bin/bash "$new_username"
            passwd "$new_username"
            install sudo
            echo "$new_username ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
            passwd -l root
            echo "操作已完成。"
            ;;
        10)
            root_use
            while true; do
                clear
                echo -e "${gl_zi}>>> 设置v4/v6优先级${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"

                if grep -Eq '^\s*precedence\s+::ffff:0:0/96\s+100\s*$' /etc/gai.conf 2>/dev/null; then
                    echo -e "当前网络优先级设置: ${gl_huang}IPv4${gl_bai} 优先"
                else
                    echo -e "当前网络优先级设置: ${gl_huang}IPv6${gl_bai} 优先"
                fi

                echo ""
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}IPv4 优先          ${gl_bufan}2. IPv6 优先          ${gl_bufan}3. ${gl_bai}IPv6 修复工具"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "选择优先的网络: " choice

                case $choice in
                1)
                    prefer_ipv4
                    ;;
                2)
                    rm -f /etc/gai.conf
                    echo "已切换为 IPv6 优先"
                    ;;
                3)
                    clear
                    bash <(curl -L -s jhb.ovh/jb/v6.sh)
                    echo "该功能由jhb大神提供，感谢他！"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        11)
            clear
            ss -tulnape
            break_end
            ;;
        12)
            root_use
            while true; do
                clear
                echo -e "${gl_zi}>>> 设置虚拟内存${gl_bai}"
                local swap_used=$(free -m | awk 'NR==3{print $3}')
                local swap_total=$(free -m | awk 'NR==3{print $2}')
                local swap_info=$(free -m | awk 'NR==3{used=$3; total=$2; if (total == 0) {percentage=0} else {percentage=used*100/total}; printf "%dM/%dM (%d%%)", used, total, percentage}')
                echo -e "当前虚拟内存: ${gl_huang}$swap_info${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}分配1024M         ${gl_bufan}2. ${gl_bai}分配2048M         ${gl_bufan}3. ${gl_bai}分配4096M         ${gl_bufan}4. ${gl_bai}自定义大小"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " choice

                case "$choice" in
                1)
                    add_swap 1024
                    ;;
                2)
                    add_swap 2048
                    ;;
                3)
                    add_swap 4096
                    ;;
                4)
                    read -r -e -p "请输入虚拟内存大小（单位M）: " new_swap
                    add_swap "$new_swap"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        13)
            while true; do
                root_use
                echo -e "${gl_huang}用户列表${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                printf "%-24s %-34s %-20s %-10s\n" "用户名" "用户权限" "用户组" "sudo权限"
                while IFS=: read -r -r username _ userid groupid _ _ homedir shell; do
                    local groups=$(groups "$username" | cut -d : -f 2)
                    local sudo_status=$(sudo -n -lU "$username" 2>/dev/null | grep -q '(ALL : ALL)' && echo "Yes" || echo "No")
                    printf "%-20s %-30s %-20s %-10s\n" "$username" "$homedir" "$groups" "$sudo_status"
                done </etc/passwd

                echo ""
                echo -e "${gl_zi}>>> 账户操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}创建普通账户             ${gl_bufan}2. ${gl_bai}创建高级账户"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}3. ${gl_bai}赋予最高权限             ${gl_bufan}4. ${gl_bai}取消最高权限"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}5. ${gl_bai}删除账号"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    # 提示用户输入新用户名
                    read -r -e -p "请输入新用户名: " new_username
                    # 创建新用户并设置密码
                    useradd -m -s /bin/bash "$new_username"
                    passwd "$new_username"
                    echo "操作已完成。"
                    ;;
                2)
                    # 提示用户输入新用户名
                    read -r -e -p "请输入新用户名: " new_username
                    # 创建新用户并设置密码
                    useradd -m -s /bin/bash "$new_username"
                    passwd "$new_username"
                    # 赋予新用户sudo权限
                    echo "$new_username ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
                    install sudo
                    echo "操作已完成。"
                    ;;
                3)
                    read -r -e -p "请输入用户名: " username
                    # 赋予新用户sudo权限
                    echo "$username ALL=(ALL:ALL) ALL" | tee -a /etc/sudoers
                    install sudo
                    ;;
                4)
                    read -r -e -p "请输入用户名: " username
                    # 从sudoers文件中移除用户的sudo权限
                    sed -i "/^$username\sALL=(ALL:ALL)\sALL/d" /etc/sudoers
                    ;;
                5)
                    read -r -e -p "请输入要删除的用户名: " username
                    # 删除用户及其主目录
                    userdel -r "$username"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        14)
            clear
            echo "随机用户名"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            for i in {1..5}; do
                username="user$(tr </dev/urandom -dc _a-z0-9 | head -c6)"
                echo "随机用户名 $i: $username"
            done

            echo ""
            echo "随机姓名"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            local first_names=("John" "Jane" "Michael" "Emily" "David" "Sophia" "William" "Olivia" "James" "Emma" "Ava" "Liam" "Mia" "Noah" "Isabella")
            local last_names=("Smith" "Johnson" "Brown" "Davis" "Wilson" "Miller" "Jones" "Garcia" "Martinez" "Williams" "Lee" "Gonzalez" "Rodriguez" "Hernandez")

            # 生成5个随机用户姓名
            for i in {1..5}; do
                local first_name_index=$((RANDOM % ${#first_names[@]}))
                local last_name_index=$((RANDOM % ${#last_names[@]}))
                local user_name="${first_names[$first_name_index]} ${last_names[$last_name_index]}"
                echo "随机用户姓名 $i: $user_name"
            done

            echo ""
            echo "随机UUID"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            for i in {1..5}; do
                uuid=$(cat /proc/sys/kernel/random/uuid)
                echo "随机UUID $i: $uuid"
            done

            echo ""
            echo "16位随机密码"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            for i in {1..5}; do
                local password
                password=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c16)
                echo "随机密码 $i: $password"
            done

            echo ""
            echo "32位随机密码"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            for i in {1..5}; do
                local password=$(tr </dev/urandom -dc _A-Z-a-z-0-9 | head -c32)
                echo "随机密码 $i: $password"
            done
            echo ""
            ;;
        15)
            root_use
            while true; do
                clear
                echo -e "${gl_bufan}系统时间信息${gl_bai}"

                # 获取当前系统时区
                local timezone=$(current_timezone)

                # 获取当前系统时间
                local current_time=$(date +"%Y-%m-%d %H:%M:%S")

                # 显示时区和时间
                echo "当前系统时区：$timezone"
                echo "当前系统时间：$current_time"

                echo ""
                echo -e "${gl_zi}>>> 时区切换${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}亚洲"
                echo -e "${gl_bufan}1.  ${gl_bai}中国上海时间             ${gl_bufan}2.  ${gl_bai}中国香港时间"
                echo -e "${gl_bufan}3.  ${gl_bai}日本东京时间             ${gl_bufan}4.  ${gl_bai}韩国首尔时间"
                echo -e "${gl_bufan}5.  ${gl_bai}新加坡时间               ${gl_bufan}6.  ${gl_bai}印度加尔各答时间"
                echo -e "${gl_bufan}7.  ${gl_bai}阿联酋迪拜时间           ${gl_bufan}8.  ${gl_bai}澳大利亚悉尼时间"
                echo -e "${gl_bufan}9.  ${gl_bai}泰国曼谷时间"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}欧洲"
                echo -e "${gl_bufan}11. ${gl_bai}英国伦敦时间             ${gl_bufan}12. ${gl_bai}法国巴黎时间"
                echo -e "${gl_bufan}13. ${gl_bai}德国柏林时间             ${gl_bufan}14. ${gl_bai}俄罗斯莫斯科时间"
                echo -e "${gl_bufan}15. ${gl_bai}荷兰尤特赖赫特时间       ${gl_bufan}16. ${gl_bai}西班牙马德里时间"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}美洲"
                echo -e "${gl_bufan}21. ${gl_bai}美国西部时间             ${gl_bufan}22. ${gl_bai}美国东部时间"
                echo -e "${gl_bufan}23. ${gl_bai}加拿大时间               ${gl_bufan}24. ${gl_bai}墨西哥时间"
                echo -e "${gl_bufan}25. ${gl_bai}巴西时间                 ${gl_bufan}26. ${gl_bai}阿根廷时间"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo "31. UTC全球标准时间"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bufan}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1) set_timedate Asia/Shanghai ;;
                2) set_timedate Asia/Hong_Kong ;;
                3) set_timedate Asia/Tokyo ;;
                4) set_timedate Asia/Seoul ;;
                5) set_timedate Asia/Singapore ;;
                6) set_timedate Asia/Kolkata ;;
                7) set_timedate Asia/Dubai ;;
                8) set_timedate Australia/Sydney ;;
                9) set_timedate Asia/Bangkok ;;
                11) set_timedate Europe/London ;;
                12) set_timedate Europe/Paris ;;
                13) set_timedate Europe/Berlin ;;
                14) set_timedate Europe/Moscow ;;
                15) set_timedate Europe/Amsterdam ;;
                16) set_timedate Europe/Madrid ;;
                21) set_timedate America/Los_Angeles ;;
                22) set_timedate America/New_York ;;
                23) set_timedate America/Vancouver ;;
                24) set_timedate America/Mexico_City ;;
                25) set_timedate America/Sao_Paulo ;;
                26) set_timedate America/Argentina/Buenos_Aires ;;
                31) set_timedate UTC ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        16)
            bbrv3
            ;;
        17)
            iptables_panel
            ;;
        18)
            root_use
            while true; do
                clear
                local current_hostname=$(uname -n)
                echo -e "当前主机名: ${gl_huang}$current_hostname${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入新的主机名（输入0退出）: " new_hostname
                if [ -n "$new_hostname" ] && [ "$new_hostname" != "0" ]; then
                    if [ -f /etc/alpine-release ]; then
                        # Alpine
                        echo "$new_hostname" >/etc/hostname
                        hostname "$new_hostname"
                    else
                        # 其他系统，如 Debian, Ubuntu, CentOS 等
                        hostnamectl set-hostname "$new_hostname"
                        sed -i "s/$current_hostname/$new_hostname/g" /etc/hostname
                        systemctl restart systemd-hostnamed
                    fi

                    if grep -q "127.0.0.1" /etc/hosts; then
                        sed -i "s/127.0.0.1 .*/127.0.0.1       $new_hostname localhost localhost.localdomain/g" /etc/hosts
                    else
                        echo "127.0.0.1       $new_hostname localhost localhost.localdomain" >>/etc/hosts
                    fi

                    if grep -q "^::1" /etc/hosts; then
                        sed -i "s/^::1 .*/::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback/g" /etc/hosts
                    else
                        echo "::1             $new_hostname localhost localhost.localdomain ipv6-localhost ipv6-loopback" >>/etc/hosts
                    fi

                    echo "主机名已更改为: $new_hostname"
                    sleep 1
                else
                    echo "已退出，未更改主机名。"
                    break
                fi
            done
            ;;
        19)
            root_use
            clear
            echo ""
            echo -e "${gl_zi}>>> 选择更新源区域${gl_bai}"
            echo -e "接入LinuxMirrors切换系统更新源"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai}中国大陆【默认】          ${gl_bufan}2. ${gl_bai}中国大陆【教育网】          ${gl_bufan}3. ${gl_bai}海外地区"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "输入你的选择: " choice

            case $choice in
            1)
                bash <(curl -sSL https://linuxmirrors.cn/main.sh)
                ;;
            2)
                bash <(curl -sSL https://linuxmirrors.cn/main.sh) --edu
                ;;
            3)
                bash <(curl -sSL https://linuxmirrors.cn/main.sh) --abroad
                ;;
            0) break ;; # 立即终止整个循环，跳出循环体
            00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
            *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
            esac
            ;;
        20)
            while true; do
                clear
                check_crontab_installed
                clear
                echo -e "${gl_bufan}定时任务列表${gl_bai}"
                crontab -l
                echo ""
                echo -e "${gl_zi}>>> 定时任务操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}添加定时任务              ${gl_bufan}2. ${gl_bai}删除定时任务              ${gl_bufan}3. ${gl_bai}编辑定时任务"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    read -r -e -p "请输入新任务的执行命令: " newquest
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo -e "${gl_bufan}1. ${gl_bai}每月任务                 ${gl_bufan}2. ${gl_bai}每周任务"
                    echo -e "${gl_bufan}3. ${gl_bai}每天任务                 ${gl_bufan}4. ${gl_bai}每小时任务"
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    read -r -e -p "请输入你的选择: " dingshi

                    case $dingshi in
                    1)
                        read -r -e -p "$(echo -e "${gl_bai}选择每月的几号执行任务？ (${gl_hong}1-30${gl_bai}): ")" day
                        (
                            crontab -l
                            echo "0 0 $day * * $newquest"
                        ) | crontab - >/dev/null 2>&1
                        ;;
                    2)
                        read -r -e -p "选择周几执行任务？ (0-6，0代表星期日): " weekday
                        (
                            crontab -l
                            echo "0 0 * * $weekday $newquest"
                        ) | crontab - >/dev/null 2>&1
                        ;;
                    3)
                        read -r -e -p "选择每天几点执行任务？（小时，0-23）: " hour
                        (
                            crontab -l
                            echo "0 $hour * * * $newquest"
                        ) | crontab - >/dev/null 2>&1
                        ;;
                    4)
                        read -r -e -p "输入每小时的第几分钟执行任务？（分钟，0-60）: " minute
                        (
                            crontab -l
                            echo "$minute * * * * $newquest"
                        ) | crontab - >/dev/null 2>&1
                        ;;
                    0)
                        break
                        ;; # 立即终止整个循环，跳出循环体
                    00 | 000 | 0000)
                        exit_script
                        ;; # 感谢使用，再见！ N 秒后自动退出
                    *)
                        handle_invalid_input
                        ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                    esac
                    ;;
                2)
                    read -r -e -p "请输入需要删除任务的关键字: " kquest
                    crontab -l | grep -v "$kquest" | crontab -
                    ;;
                3)
                    crontab -e
                    ;;
                *)
                    break # 跳出循环，退出菜单
                    ;;
                esac
            done
            ;;
        21)
            root_use
            while true; do
                clear
                echo ""
                echo -e "${gl_bufan}本机host解析列表${gl_bai}"
                echo "如果你在这里添加解析匹配，将不再使用动态解析了"
                cat /etc/hosts
                echo ""
                echo -e "${gl_zi}>>> host操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}添加新的解析              ${gl_bufan}2. ${gl_bai}删除解析地址"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " host_dns

                case $host_dns in
                1)
                    read -r -e -p "请输入新的解析记录 格式: 110.25.5.33 kejilion.pro : " addhost
                    echo "$addhost" >>/etc/hosts
                    ;;
                2)
                    read -r -e -p "请输入需要删除的解析内容关键字: " delhost
                    sed -i "/$delhost/d" /etc/hosts
                    ;;
                0) break ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
                *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;

        22)
            root_use
            while true; do
                check_f2b_status
                echo -e "SSH防御程序 $check_f2b_status"
                echo -e "fail2ban是一个SSH防止暴力破解工具"
                echo -e "${gl_bufan}官网介绍: ${gl_bai}${gh_proxy}github.com/fail2ban/fail2ban"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}安装防御程序"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}2. ${gl_bai}查看SSH拦截记录"
                echo -e "${gl_bufan}3. ${gl_bai}日志实时监控"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}9. ${gl_bai}卸载防御程序"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice
                case $sub_choice in
                1)
                    f2b_install_sshd
                    cd ~
                    f2b_status
                    break_end
                    ;;
                2)
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    f2b_sshd
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    break_end
                    ;;
                3)
                    tail -f /var/log/fail2ban.log
                    break
                    ;;
                9)
                    remove fail2ban
                    rm -rf /etc/fail2ban
                    echo "Fail2Ban防御程序已卸载"
                    break
                    ;;
                0) break ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
                *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;

        23)
            root_use
            while true; do
                clear
                echo "限流关机功能"
                echo "视频介绍: https://www.bilibili.com/video/BV1mC411j7Qd?t=0.1"
                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                echo "当前流量使用情况，重启服务器流量计算会清零！"
                output_status
                echo -e "${gl_bufan}总接收: ${gl_bai}$rx"
                echo -e "${gl_bufan}总发送: ${gl_bai}$tx"

                # 检查是否存在 Limiting_Shut_down.sh 文件
                if [ -f ~/Limiting_Shut_down.sh ]; then
                    # 获取 threshold_gb 的值
                    local rx_threshold_gb=$(grep -oP 'rx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
                    local tx_threshold_gb=$(grep -oP 'tx_threshold_gb=\K\d+' ~/Limiting_Shut_down.sh)
                    echo -e "${gl_lv}当前设置的进站限流阈值为: ${gl_huang}${rx_threshold_gb}${gl_lv}G${gl_bai}"
                    echo -e "${gl_lv}当前设置的出站限流阈值为: ${gl_huang}${tx_threshold_gb}${gl_lv}GB${gl_bai}"
                else
                    echo -e "${gl_hui}当前未启用限流关机功能${gl_bai}"
                fi

                echo
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "系统每分钟会检测实际流量是否到达阈值，到达后会自动关闭服务器！"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}开启限流关机功能          ${gl_bufan}2. ${gl_bai}停用限流关机功能"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " Limiting

                case "$Limiting" in
                1)
                    # 输入新的虚拟内存大小
                    echo "如果实际服务器就100G流量，可设置阈值为95G，提前关机，以免出现流量误差或溢出。"
                    read -r -e -p "请输入进站流量阈值（单位为G，默认100G）: " rx_threshold_gb
                    rx_threshold_gb=${rx_threshold_gb:-100}
                    read -r -e -p "请输入出站流量阈值（单位为G，默认100G）: " tx_threshold_gb
                    tx_threshold_gb=${tx_threshold_gb:-100}
                    read -r -e -p "请输入流量重置日期（默认每月1日重置）: " cz_day
                    cz_day=${cz_day:-1}

                    cd ~
                    curl -Ss -o ~/Limiting_Shut_down.sh ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/Limiting_Shut_down1.sh
                    chmod +x ~/Limiting_Shut_down.sh
                    sed -i "s/110/$rx_threshold_gb/g" ~/Limiting_Shut_down.sh
                    sed -i "s/120/$tx_threshold_gb/g" ~/Limiting_Shut_down.sh
                    check_crontab_installed
                    crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
                    (
                        crontab -l
                        echo "* * * * * ~/Limiting_Shut_down.sh"
                    ) | crontab - >/dev/null 2>&1
                    crontab -l | grep -v 'reboot' | crontab -
                    (
                        crontab -l
                        echo "0 1 $cz_day * * reboot"
                    ) | crontab - >/dev/null 2>&1
                    echo "限流关机已设置"
                    ;;
                2)
                    check_crontab_installed
                    crontab -l | grep -v '~/Limiting_Shut_down.sh' | crontab -
                    crontab -l | grep -v 'reboot' | crontab -
                    rm ~/Limiting_Shut_down.sh
                    echo "已关闭限流关机功能"
                    ;;
                0) break ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
                *) handle_invalid_input  ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;
        24)

            root_use
            while true; do
                clear
                echo -e "${gl_zi}>>> ROOT私钥登录模式${gl_bai}"
                echo "视频介绍: https://www.bilibili.com/video/BV1Q4421X78n?t=209.4"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo "将会生成密钥对，更安全的方式SSH登录"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}生成新密钥              ${gl_bufan}2. ${gl_bai}导入已有密钥              ${gl_bufan}3. ${gl_bai}查看本机密钥"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " host_dns

                case $host_dns in
                1)
                    add_sshkey
                    break_end
                    ;;
                2)
                    import_sshkey
                    break_end
                    ;;
                3)
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo "公钥信息"
                    cat ~/.ssh/authorized_keys
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    echo "私钥信息"
                    cat ~/.ssh/sshkey
                    echo -e "${gl_bufan}------------------------${gl_bai}"
                    break_end
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;

        25)
            root_use
            echo "TG-bot监控预警功能"
            echo "视频介绍: https://youtu.be/vLL-eb3Z_TY"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo "您需要配置tg机器人API和接收预警的用户ID，即可实现本机CPU，内存，硬盘，流量，SSH登录的实时监控预警"
            echo "到达阈值后会向用户发预警消息"
            echo -e "${gl_hui}-关于流量，重启服务器将重新计算-${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确定继续吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

            case "$choice" in
            [Yy])
                cd ~
                install nano tmux bc jq
                check_crontab_installed
                if [ -f ~/TG-check-notify.sh ]; then
                    chmod +x ~/TG-check-notify.sh
                    nano ~/TG-check-notify.sh
                else
                    curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/TG-check-notify.sh
                    chmod +x ~/TG-check-notify.sh
                    nano ~/TG-check-notify.sh
                fi
                tmux kill-session -t TG-check-notify >/dev/null 2>&1
                tmux new -d -s TG-check-notify "~/TG-check-notify.sh"
                crontab -l | grep -v '~/TG-check-notify.sh' | crontab - >/dev/null 2>&1
                (
                    crontab -l
                    echo "@reboot tmux new -d -s TG-check-notify '~/TG-check-notify.sh'"
                ) | crontab - >/dev/null 2>&1

                curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/TG-SSH-check-notify.sh >/dev/null 2>&1
                sed -i "3i$(grep '^TELEGRAM_BOT_TOKEN=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh >/dev/null 2>&1
                sed -i "4i$(grep '^CHAT_ID=' ~/TG-check-notify.sh)" TG-SSH-check-notify.sh
                chmod +x ~/TG-SSH-check-notify.sh

                # 添加到 ~/.profile 文件中
                if ! grep -q 'bash ~/TG-SSH-check-notify.sh' ~/.profile >/dev/null 2>&1; then
                    echo 'bash ~/TG-SSH-check-notify.sh' >>~/.profile
                    if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
                        echo 'source ~/.profile' >>~/.bashrc
                    fi
                fi

                source ~/.profile

                clear
                echo -e "${gl_lv}TG-bot预警系统已启动"
                echo -e "${gl_hui}你还可以将root目录中的TG-check-notify.sh预警文件放到其他机器上直接使用！${gl_bai}"
                ;;
            [Nn])
                echo "已取消"
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        26)
            root_use
            cd ~
            curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/sh/main/upgrade_openssh9.8p1.sh
            chmod +x ~/upgrade_openssh9.8p1.sh
            ~/upgrade_openssh9.8p1.sh
            rm -f ~/upgrade_openssh9.8p1.sh
            ;;
        27)
            elrepo
            ;;
        28)
            Kernel_optimize
            ;;
        29)
            clamav
            ;;
        30)
            linux_file "$@"
            ;;
        31)
            linux_language
            ;;
        32)
            shell_bianse
            ;;
        33)
            linux_trash
            ;;
        34)
            linux_backup
            ;;
        35)
            ssh_manager
            ;;
        36)
            disk_manager
            ;;
        37)
            clear
            get_history_file() {
                for file in "$HOME"/.bash_history "$HOME"/.ash_history "$HOME"/.zsh_history "$HOME"/.local/share/fish/fish_history; do
                    [ -f "$file" ] && {
                        echo "$file"
                        return
                    }
                done
                return 1
            }
            history_file=$(get_history_file) && cat -n "$history_file"
            ;;
        38)
            rsync_manager
            ;;
        39)
            clear
            linux_fav
            ;;
        40)
            # Samba共享配置
            clear
            menu_samba_manager
            ;;
        41)
            clear
            echo "访问科技lion官方留言板，您对脚本有任何想法欢迎留言交流！"
            echo "https://board.kejilion.pro"
            echo "公共密码: mobufan.sh"
            ;;
        66)
            root_use
            echo "一条龙系统调优"
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
            echo "将对以下内容进行操作与优化"
            echo -e "${gl_bufan}1. ${gl_bai}更新系统到最新"
            echo -e "${gl_bufan}2. ${gl_bai}清理系统垃圾文件"
            echo -e "${gl_bufan}3. ${gl_bai}设置虚拟内存${gl_huang}1G${gl_bai}"
            echo -e "${gl_bufan}4. ${gl_bai}设置SSH端口号为${gl_huang}22${gl_bai}"
            echo -e "${gl_bufan}5. ${gl_bai}启动fail2ban防御SSH暴力破解"
            echo -e "${gl_bufan}6. ${gl_bai}开放所有端口"
            echo -e "${gl_bufan}7. ${gl_bai}开启${gl_huang}BBR${gl_bai}加速"
            echo -e "${gl_bufan}8. ${gl_bai}设置时区到${gl_huang}上海${gl_bai}"
            echo -e "${gl_bufan}9. ${gl_bai}自动优化DNS地址${gl_huang}海外: 1.1.1.1 8.8.8.8  国内: 223.5.5.5 ${gl_bai}"
            echo -e "${gl_bufan}10. ${gl_bai}设置网络为${gl_huang}ipv4优先${gl_bai}"
            echo -e "${gl_bufan}11. ${gl_bai}安装基础工具${gl_huang}docker wget sudo tar unzip socat btop nano vim${gl_bai}"
            echo -e "${gl_bufan}12. ${gl_bai}Linux系统内核参数优化切换到${gl_huang}均衡优化模式${gl_bai}"
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}确定一键保养吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

            case "$choice" in
            [Yy])
                clear
                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                linux_update
                echo -e "[${gl_lv}OK${gl_bai}] 1/12. 更新系统到最新"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                linux_clean
                echo -e "[${gl_lv}OK${gl_bai}] 2/12. 清理系统垃圾文件"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                add_swap 1024
                echo -e "[${gl_lv}OK${gl_bai}] 3/12. 设置虚拟内存${gl_huang}1G${gl_bai}"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                local new_port=22
                new_ssh_port
                echo -e "[${gl_lv}OK${gl_bai}] 4/12. 设置SSH端口号为${gl_huang}22${gl_bai}"
                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                f2b_install_sshd
                cd ~
                f2b_status
                echo -e "[${gl_lv}OK${gl_bai}] 5/12. 启动fail2ban防御SSH暴力破解"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                echo -e "[${gl_lv}OK${gl_bai}] 6/12. 开放所有端口"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                bbr_on
                echo -e "[${gl_lv}OK${gl_bai}] 7/12. 开启${gl_huang}BBR${gl_bai}加速"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                set_timedate Asia/Shanghai
                echo -e "[${gl_lv}OK${gl_bai}] 8/12. 设置时区到${gl_huang}上海${gl_bai}"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                auto_optimize_dns
                echo -e "[${gl_lv}OK${gl_bai}] 9/12. 自动优化DNS地址${gl_huang}${gl_bai}"
                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                prefer_ipv4
                echo -e "[${gl_lv}OK${gl_bai}] 10/12. 设置网络为${gl_huang}ipv4优先${gl_bai}}"

                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
                install_docker
                install wget sudo tar unzip socat btop nano vim
                echo -e "[${gl_lv}OK${gl_bai}] 11/12. 安装基础工具${gl_huang}docker wget sudo tar unzip socat btop nano vim${gl_bai}"
                echo -e "${gl_bufan}------------------------------------------------${gl_bai}"

                optimize_balanced
                echo -e "[${gl_lv}OK${gl_bai}] 12/12. Linux系统内核参数优化"
                echo -e "${gl_lv}一条龙系统调优已完成${gl_bai}"
                ;;
            [Nn])
                echo "已取消"
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        99)
            clear
            server_reboot
            ;;
        100)
            root_use
            while true; do
                clear
                if grep -q '^ENABLE_STATS="true"' /usr/local/bin/m >/dev/null 2>&1; then
                    local status_message="${gl_lv}正在采集数据${gl_bai}"
                elif grep -q '^ENABLE_STATS="false"' /usr/local/bin/m >/dev/null 2>&1; then
                    local status_message="${gl_hui}采集已关闭${gl_bai}"
                else
                    local status_message="无法确定的状态"
                fi

                echo -e "${gl_zi}>>> 隐私与安全${gl_bai}"
                echo "脚本将收集用户使用功能的数据，优化脚本体验，制作更多好玩好用的功能"
                echo "将收集脚本版本号，使用的时间，系统版本，CPU架构，机器所属国家和使用的功能的名称，"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "当前状态: $status_message"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}开启采集"
                echo -e "${gl_bufan}2. ${gl_bai}关闭采集"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice
                case $sub_choice in
                1)
                    cd ~
                    sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' /usr/local/bin/m
                    sed -i 's/^ENABLE_STATS="false"/ENABLE_STATS="true"/' ~/mobufan.sh
                    echo "已开启采集"
                    ;;
                2)
                    cd ~
                    sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' /usr/local/bin/m
                    sed -i 's/^ENABLE_STATS="true"/ENABLE_STATS="false"/' ~/mobufan.sh
                    echo "已关闭采集"
                    ;;
                0)
                    break
                    ;; # 立即终止整个循环，跳出循环体
                00 | 000 | 0000)
                    exit_script
                    ;; # 感谢使用，再见！ N 秒后自动退出
                *)
                    handle_invalid_input
                    ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
                esac
            done
            ;;

        101)
            clear
            m_info
            break_end
            ;;
        102)
            clear
            echo -e "${gl_zi}>>> 卸载mobufan.sh脚本${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo "将彻底卸载mobufan脚本，不影响你其他功能"
            read -r -e -p "$(echo -e "${gl_bai}确定继续吗？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice

            case "$choice" in
            [Yy])
                clear
                (crontab -l | grep -v "mobufan.sh") | crontab -
                rm -f /usr/local/bin/m
                rm /root/mobufan.sh
                rm /root/.mobufan_license
                echo "脚本已卸载，再见！"
                break_end
                clear
                exit
                ;;
            [Nn])
                echo "已取消"
                ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 函数：创建并编辑文件（增强版，支持更好的回退功能）
create_file() {
    while :; do
        echo -e "${gl_bufan}创建文件${gl_bai}"
        echo -e "${gl_huang}------------------------${gl_bai}"

        local file_name
        safe_read "请输入文件名（q 退出）" file_name || return
        [[ $file_name == [qQ] ]] && return

        if [[ -e $file_name ]]; then
            echo -e "${gl_hong}文件已存在：$file_name${gl_bai}"
            local overwrite
            # safe_read "是否覆盖？（y/n）" overwrite || continue
            safe_read "$(echo -e "${gl_bai}是否覆盖？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" overwrite || continue
            [[ $overwrite != [yY] ]] && continue
        fi

        echo -e "${gl_huang}将创建文件：$file_name${gl_bai}"
        echo -e "${gl_bufan}开始输入内容（单行输入 EOF 结束，空格/空行均保留）:${gl_bai}"

        local tmp line_count=0
        tmp=$(mktemp)
        while IFS= read -r -e -p "> " line; do
            [[ $line == EOF ]] && break
            printf '%s\n' "$line" >>"$tmp" # 关键：保留前导空格与空行
            ((line_count++))
        done

        if ((line_count == 0)); then
            touch "$file_name"
            echo -e "${gl_bufan}创建空文件完成${gl_bai}"
        else
            mv "$tmp" "$file_name"
            echo -e "${gl_huang}文件创建成功，共写入 $line_count 行${gl_bai}"
        fi
        [[ -s $file_name ]] && cat -n "$file_name"

        # 脚本文件执行权限提示
        if [[ $file_name =~ \.(sh|py|pl)$ ]]; then
            local add_exec
            safe_read "$(echo -e "${gl_bai}检测到脚本文件，是否添加执行权限？ (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" add_exec || continue

            [[ $add_exec == [yY] ]] && chmod +x "$file_name"
        fi

        echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}"
        read -r -r -n 1 -s # -n 1 只读一个字符，-s 不回显
        break
    done
}

linux_file() {
    root_use
    while true; do
        clear
        echo -e "${gl_zi}>>> 文件管理器${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        ls --color=auto -x
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}进入目录        ${gl_bufan}2.  ${gl_bai}创建目录           ${gl_bufan}3.  ${gl_bai}修改目录权限"
        echo -e "${gl_bufan}4.  ${gl_bai}重命名目录      ${gl_bufan}5.  ${gl_bai}删除目录           ${gl_bufan}6.  ${gl_bai}返回上一级目录"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}创建文件        ${gl_bufan}12. ${gl_bai}编辑文件           ${gl_bufan}13. ${gl_bai}修改文件权限"
        echo -e "${gl_bufan}14. ${gl_bai}重命名文件      ${gl_bufan}15. ${gl_bai}删除文件           ${gl_bufan}16. ${gl_bai}查看文件内容"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}21. ${gl_bai}压缩文件目录    ${gl_bufan}22. ${gl_bai}解压文件目录       ${gl_bufan}23. ${gl_bai}解压压缩工具"
        echo -e "${gl_bufan}24. ${gl_bai}移动文件目录    ${gl_bufan}25. ${gl_bai}复制文件目录       ${gl_bufan}26. ${gl_bai}文件下载工具"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}31. ${gl_bai}文件搜索        ${gl_bufan}32. ${gl_bai}文件内容搜索       ${gl_bufan}33. ${gl_bai}创建并编辑文件"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}88. ${gl_bai}传送文件至远端服务器"
        echo -e "${gl_bufan}99. ${gl_bai}文件回收站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " Limiting

        case "$Limiting" in
        1)
            # 进入目录
            read -r -e -p "请输入目录名: " dirname
            cd "$dirname" 2>/dev/null || echo "无法进入目录"
            ;;
        2)
            # 创建目录
            read -r -e -p "请输入要创建的目录名: " dirname
            mkdir -p "$dirname" && echo "目录已创建" || echo "创建失败"
            ;;
        3)
            # 修改目录权限
            read -r -e -p "请输入目录名: " dirname
            read -r -e -p "请输入权限 (如 755): " perm
            chmod "$perm" "$dirname" && echo "权限已修改" || echo "修改失败"
            ;;
        4)
            # 重命名目录
            read -r -e -p "请输入当前目录名: " current_name
            read -r -e -p "请输入新目录名: " new_name
            mv "$current_name" "$new_name" && echo "目录已重命名" || echo "重命名失败"
            ;;
        5)
            # 删除目录
            read -r -e -p "请输入要删除的目录名（多个目录请用空格分隔）: " dirnames
            for dir in $dirnames; do
                if [ -d "$dir" ]; then
                    rm -rf "$dir" && echo "目录 '$dir' 已删除" || echo "目录 '$dir' 删除失败"
                else
                    echo "目录 '$dir' 不存在或不是目录"
                fi
            done
            ;;
        6)
            # 返回上一级选单目录
            cd ..
            ;;
        11)
            # 创建文件
            read -r -e -p "请输入要创建的文件名: " filename
            touch "$filename" && echo "文件已创建" || echo "创建失败"
            ;;
        12)
            # 编辑文件
            read -r -e -p "请输入要编辑的文件名: " filename
            install nano
            nano "$filename"
            ;;
        13)
            # 修改文件权限
            file_chmod
            ;;
        14)
            # 重命名文件
            read -r -e -p "请输入当前文件名: " current_name
            read -r -e -p "请输入新文件名: " new_name
            mv "$current_name" "$new_name" && echo "文件已重命名" || echo "重命名失败"
            ;;
        15)
            # 删除文件
            read -r -e -p "请输入要删除的文件名（多个文件请用空格分隔）: " filenames
            for file in $filenames; do
                if [ -e "$file" ]; then
                    rm -f "$file" && echo "文件 '$file' 已删除" || echo "文件 '$file' 删除失败"
                else
                    echo "文件 '$file' 不存在"
                fi
            done
            ;;
        16)
            # 查看文件内容
            read -r -e -p "请输入要查看的文件名: " filename
            cat "$filename"
            break_end
            ;;
        21)
            # 压缩文件/目录
            read -r -e -p "请输入要压缩的文件/目录名: " name
            install tar
            tar -czvf "$name.tar.gz" "$name" && echo "已压缩为 $name.tar.gz" || echo "压缩失败"
            ;;
        22)
            # 解压文件/目录
            read -r -e -p "请输入要解压的文件名 (.tar.gz): " filename
            install tar
            tar -xzvf "$filename" && echo "已解压 $filename" || echo "解压失败"
            ;;
        23)
            # 解压压缩工具
            clear
            if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
                compress_tool "$@"
            fi
            ;;
        24)
            # 移动文件或目录
            read -r -e -p "请输入要移动的文件或目录路径: " src_path
            if [ ! -e "$src_path" ]; then
                echo "错误: 文件或目录不存在。"
                return
            fi

            read -r -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
            if [ -z "$dest_path" ]; then
                echo "错误: 请输入目标路径。"
                return
            fi

            mv "$src_path" "$dest_path" && echo "文件或目录已移动到 $dest_path" || echo "移动文件或目录失败"
            ;;
        25)
            # 复制文件目录
            read -r -e -p "请输入要复制的文件或目录路径: " src_path
            if [ ! -e "$src_path" ]; then
                echo "错误: 文件或目录不存在。"
                return
            fi

            read -r -e -p "请输入目标路径 (包括新文件名或目录名): " dest_path
            if [ -z "$dest_path" ]; then
                echo "错误: 请输入目标路径。"
                return
            fi

            # 使用 -r 选项以递归方式复制目录
            cp -r "$src_path" "$dest_path" && echo "文件或目录已复制到 $dest_path" || echo "复制文件或目录失败"
            ;;
        26)
            # 文件下载工具
            download_file
            ;;
        31)
            # 文件搜索（递归模糊）
            search_file_here
            #local key
            #safe_read "请输入文件名关键字（可模糊）" key || continue
            #echo -e "${gl_huang}搜索结果（绝对路径）：${gl_bai}"
            # 直接使用find输出，不在文件名中高亮
            #find "$(pwd)" -iname "*${key}*" 2>/dev/null
            #break_end
            ;;
        32)
            # 文件内容搜索
            search_here
            ;;
        33)
            # 创建并编辑文件
            create_file
            ;;
        88)
            # 传送文件至远端服务器
            read -r -e -p "请输入要传送的文件路径: " file_to_transfer
            if [ ! -f "$file_to_transfer" ]; then
                echo "错误: 文件不存在。"
                return
            fi

            read -r -e -p "请输入远端服务器IP: " remote_ip
            if [ -z "$remote_ip" ]; then
                echo "错误: 请输入远端服务器IP。"
                return
            fi

            read -r -e -p "请输入远端服务器用户名 (默认root): " remote_user
            remote_user=${remote_user:-root}

            read -r -e -p "请输入远端服务器密码: " -s remote_password
            echo
            if [ -z "$remote_password" ]; then
                echo "错误: 请输入远端服务器密码。"
                return
            fi

            read -r -e -p "请输入登录端口 (默认22): " remote_port
            remote_port=${remote_port:-22}

            # 清除已知主机的旧条目
            ssh-keygen -f "/root/.ssh/known_hosts" -R "$remote_ip"
            sleep 2 # 等待时间

            # 使用scp传输文件
            scp -P "$remote_port" -o StrictHostKeyChecking=no "$file_to_transfer" "$remote_user@$remote_ip:/home/" <<EOF
$remote_password
EOF

            if cmd; then
                echo "文件已传送至远程服务器home目录。"
            else
                echo "文件传送失败。"
            fi
            break_end
            ;;
        99)
            # 文件回收站
            manage_trash_menu
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

cluster_python3() {
    install python3 python3-paramiko
    cd ~/cluster/
    curl -sS -O ${gh_proxy}raw.githubusercontent.com/kejilion/python-for-vps/main/cluster/"$py_task"
    python3 ~/cluster/"$py_task"
}

run_commands_on_servers() {

    install sshpass

    local SERVERS_FILE="$HOME/cluster/servers.py"
    local SERVERS=$(grep -oP '{"name": "\K[^"]+|"hostname": "\K[^"]+|"port": \K[^,]+|"username": "\K[^"]+|"password": "\K[^"]+' "$SERVERS_FILE")

    # 将提取的信息转换为数组
    IFS=$'\n' read -r -r -d '' -a SERVER_ARRAY <<<"$SERVERS"

    # 遍历服务器并执行命令
    for ((i = 0; i < ${#SERVER_ARRAY[@]}; i += 5)); do
        local name=${SERVER_ARRAY[i]}
        local hostname=${SERVER_ARRAY[i + 1]}
        local port=${SERVER_ARRAY[i + 2]}
        local username=${SERVER_ARRAY[i + 3]}
        local password=${SERVER_ARRAY[i + 4]}
        echo
        echo -e "${gl_huang}连接到 $name ($hostname)...${gl_bai}"
        # sshpass -p "$password" ssh -o StrictHostKeyChecking=no "$username@$hostname" -p "$port" "$1"
        sshpass -p "$password" ssh -t -o StrictHostKeyChecking=no "$username@$hostname" -p ""$port"" "$1"
    done
    echo
    break_end
}

###### mobufan.sh 脚本更新
mobufan_update() {
    cd ~
    while true; do
        clear
        echo -e "${gl_zi}>>> 更新日志${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo "全部日志: https://gitee.com/meimolihan/sh/raw/master/log/mobufan_sh_log.txt"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        curl -s https://gitee.com/meimolihan/sh/raw/master/log/mobufan_sh_log.txt | tail -n 30

        # 获取远程版本号
        local sh_v_new
        sh_v_new=$(curl -s https://gitee.com/meimolihan/sh/raw/master/mobufan.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
        if [ "$sh_v" = "$sh_v_new" ]; then
            echo -e "${gl_lv}你已经是最新版本！${gl_huang}v$sh_v${gl_bai}"
        else
            echo -e "${gl_lv}发现新版本！${gl_bai}"
            echo -e "当前版本 ${gl_lv}v$sh_v${gl_bai}        最新版本 ${gl_huang}v$sh_v_new${gl_bai}"
        fi

        local cron_job="mobufan.sh"
        local existing_cron=$(crontab -l 2>/dev/null | grep -F "$cron_job")

        if [ -n "$existing_cron" ]; then
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_lv}自动更新已开启，每天凌晨 ${gl_huang}2${gl_bai} 点脚本会自动更新！${gl_bai}"
        fi

        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai}现在更新               ${gl_bufan}2. ${gl_bai}强制更新"
        echo -e "${gl_bufan}3. ${gl_bai}开启自动更新           ${gl_bufan}4. ${gl_bai}关闭自动更新"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00.${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice
        case "$choice" in
        1)
            clear
            local sh_v_new
            sh_v_new=$(curl -s https://gitee.com/meimolihan/sh/raw/master/mobufan.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
            curl -sS --connect-timeout 10 -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh || curl -sS --connect-timeout 10 -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            # curl -sS -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            canshu_v6
            CheckFirstRun_true
            yinsiyuanquan2
            cp -f ~/mobufan.sh /usr/local/bin/m >/dev/null 2>&1
            echo -e "${gl_bai}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
            # 倒计时 3 秒
            echo -ne "${gl_bai}即将启动新版本脚本，倒计时: ${gl_hong}2${gl_bai} 秒"
            sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_huang}2${gl_bai} 秒"
            sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_lv}1${gl_bai} 秒"
            sleep 1
            echo -e "\r${gl_bai}正在启动新版本脚本...${gl_bai}"
            bash ~/mobufan.sh
            exit
            ;;
        2 | up)
            clear
            local sh_v_new
            sh_v_new=$(curl -s https://gitee.com/meimolihan/sh/raw/master/mobufan.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
            curl -sS --connect-timeout 10 -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh || curl -sS --connect-timeout 10 -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            # curl -sS -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            canshu_v6
            CheckFirstRun_true
            yinsiyuanquan2
            cp -f ~/mobufan.sh /usr/local/bin/m >/dev/null 2>&1
            echo -e "${gl_bai}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
            # 倒计时 3 秒
            echo -ne "${gl_bai}即将启动新版本脚本，倒计时: ${gl_hong}2${gl_bai} 秒"
            sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_huang}2${gl_bai} 秒"
            sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_lv}1${gl_bai} 秒"
            sleep 1
            echo -e "\r${gl_bai}正在启动新版本脚本...${gl_bai}"
            bash ~/mobufan.sh
            exit
            ;;
        3)
            clear
            local country=$(curl -s ipinfo.io/country)
            local ipv6_address=$(curl -s --max-time 1 ipv6.ip.sb)
            if [ "$country" = "CN" ]; then
                SH_Update_task="curl -sS -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh && chmod +x mobufan.sh && sed -i 's/canshu=\"default\"/canshu=\"CN\"/g' ./mobufan.sh"
            elif [ -n "$ipv6_address" ]; then
                SH_Update_task="curl -sS -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh && chmod +x mobufan.sh && sed -i 's/canshu=\"default\"/canshu=\"V6\"/g' ./mobufan.sh"
            else
                SH_Update_task="curl -sS -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh && chmod +x mobufan.sh"
            fi
            check_crontab_installed
            (crontab -l | grep -v "mobufan.sh") | crontab -
            (
                crontab -l 2>/dev/null
                echo "$(shuf -i 0-59 -n 1) 2 * * * bash -c \"$SH_Update_task\""
            ) | crontab -
            echo -e "${gl_lv}自动更新已开启，每天凌晨2点脚本会自动更新！${gl_bai}"
            sleep 3  # 暂停 3 秒，可以看到提示信息。
            continue # 继续循环，不退出
            ;;
        4)
            clear
            (crontab -l | grep -v "mobufan.sh") | crontab -
            echo -e "${gl_lv}自动更新已关闭${gl_bai}"
            sleep 3  # 暂停 3 秒，可以看到提示信息。
            continue # 继续循环，不退出
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

###### PVE 关闭已经开启的实例
pve_shutdown_selector() {
    # 仅获取数据，不做任何输出
    get_running_instances() {
        RUNNING_INSTANCES=()
        INSTANCE_TYPES=()
        INSTANCE_IDS=()
        INSTANCE_NAMES=()

        local instances
        instances=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null)
        [ $? -ne 0 ] && {
            echo -e "${gl_hong}错误: 无法获取实例信息，请检查PVE环境${gl_bai}" >&2
            return 1
        }

        local count=0
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local vmid type status name
            vmid=$(echo "$line" | jq -r '.vmid')
            type=$(echo "$line" | jq -r '.type')
            status=$(echo "$line" | jq -r '.status')
            name=$(echo "$line" | jq -r '.name')

            if [ "$status" = "running" ]; then
                RUNNING_INSTANCES+=("$count")
                INSTANCE_IDS+=("$vmid")
                INSTANCE_TYPES+=("$type")
                INSTANCE_NAMES+=("$name")
                ((count++))
            fi
        done < <(echo "$instances" | jq -c '.[]')
        return 0
    }

    # ---------- 清屏 + 展示列表 ----------
    show_running_instances() {
        [ ${#RUNNING_INSTANCES[@]} -eq 0 ] && {
            echo -e "${gl_huang}没有找到运行中的虚拟机或LXC容器${gl_bai}"
            return 1
        }

        clear
        echo -e "${gl_zi}>>> 运行中的实例列表:${gl_bai}"
        echo -e "${gl_lan}-----------------------------------------------${gl_bai}"

        # 表头
        printf "${gl_huang}%-4s  ${gl_bai}%-10s  ${gl_huang}%-6s  ${gl_bai}%-20s${gl_bai}\n" "序号" "类型" "ID" "名称"

        # 数据行
        for i in "${!RUNNING_INSTANCES[@]}"; do
            [ "${INSTANCE_TYPES[$i]}" = "qemu" ] && local t="虚拟机" || t="LXC容器"
            local pad=""
            case "$t" in
            虚拟机) pad="   " ;;
            *) pad="  " ;;
            esac
            printf "${gl_huang}%2d)  ${gl_bai}%s%-*s  ${gl_huang}%-6s  ${gl_bai}%-20s${gl_bai}\n" \
                "$((i + 1))" "$t" $((6 - ${#t} - ${#pad})) "$pad" "${INSTANCE_IDS[$i]}" "${INSTANCE_NAMES[$i]}"
        done
        echo -e "${gl_lan}-----------------------------------------------${gl_bai}"
        return 0
    }

    # ---------- 关闭选定的实例 ----------
    shutdown_instance() {
        local index=$1
        local instance_id="${INSTANCE_IDS[$index]}"
        local instance_type="${INSTANCE_TYPES[$index]}"
        local instance_name="${INSTANCE_NAMES[$index]}"

        local type_str
        [ "$instance_type" = "qemu" ] && type_str="虚拟机" || type_str="LXC容器"

        echo -e "\n${gl_huang}你选择了:${gl_bai}"
        echo -e "  ${type_str} - ID: ${gl_huang}$instance_id${gl_bai} 名称: ${gl_huang}$instance_name${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认要关闭这个实例吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
        [yY] | [yY][eE][sS])
            echo -e "${gl_lan}正在关闭实例...${gl_bai}"
            if [ "$instance_type" = "qemu" ]; then
                qm shutdown "$instance_id" &&
                    echo -e "${gl_lv}虚拟机 $instance_id 关闭命令已发送${gl_bai}" ||
                    {
                        echo -e "${gl_hong}关闭虚拟机 $instance_id 失败${gl_bai}"
                        return 1
                    }
            else
                pct shutdown "$instance_id" &&
                    echo -e "${gl_lv}LXC容器 $instance_id 关闭命令已发送${gl_bai}" ||
                    {
                        echo -e "${gl_hong}关闭LXC容器 $instance_id 失败${gl_bai}"
                        return 1
                    }
            fi
            ;;
        *)
            echo -e "${gl_huang}操作已取消${gl_bai}"
            return 2
            ;;
        esac
        return 0
    }

    # ---------------- 主入口 ----------------
    get_running_instances || return 1
    show_running_instances || return 1

    while :; do
        read -r -e -p "$(echo -e "${gl_bai}请输入要${gl_huang}关闭${gl_bai}的实例序号 (输入 ${gl_huang}0${gl_bai} 返回): ")" choice
        case $choice in
        0)
            return 0
            ;;
        '' | *[!0-9]*)
            echo -e "${gl_hong}错误: 请输入有效的数字序号${gl_bai}"
            return
            ;;
        *)
            local index=$((choice - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#RUNNING_INSTANCES[@]}" ]; then
                shutdown_instance "$index"
                if [ $? -eq 0 ]; then
                    # 倒计时 3 秒，按键可跳过
                    for i in 5 4 3 2 1; do
                        printf "\r${gl_huang}%d 秒后自动返回实例列表…${gl_bai}" "$i"
                        read -n 1 -s -t 1 && break
                    done
                    printf "\r\033[K"
                    read -t 0.001 -n 1000 2>/dev/null
                    # 重新获取并展示
                    get_running_instances >/dev/null || break
                    show_running_instances || break
                fi
            else
                echo -e "${gl_hong}错误: 序号 ${choice} 不在有效范围内${gl_bai}"
            fi
            ;;
        esac
    done
}

###### PVE 开启已经关闭的实例
pve_start_selector() {
    # 仅获取数据，不做任何输出
    get_stopped_instances() {
        STOPPED_INSTANCES=()
        INSTANCE_TYPES=()
        INSTANCE_IDS=()
        INSTANCE_NAMES=()

        local instances
        instances=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null)
        [ $? -ne 0 ] && {
            echo -e "${gl_hong}错误: 无法获取实例信息，请检查PVE环境${gl_bai}" >&2
            return 1
        }

        local count=0
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local vmid type status name
            vmid=$(echo "$line" | jq -r '.vmid')
            type=$(echo "$line" | jq -r '.type')
            status=$(echo "$line" | jq -r '.status')
            name=$(echo "$line" | jq -r '.name')

            if [ "$status" = "stopped" ]; then
                STOPPED_INSTANCES+=("$count")
                INSTANCE_IDS+=("$vmid")
                INSTANCE_TYPES+=("$type")
                INSTANCE_NAMES+=("$name")
                ((count++))
            fi
        done < <(echo "$instances" | jq -c '.[]')
        return 0
    }

    # ---------- 清屏 + 展示列表 ----------
    show_stopped_instances() {
        [ ${#STOPPED_INSTANCES[@]} -eq 0 ] && {
            echo -e "${gl_huang}没有找到已停止的虚拟机或LXC容器${gl_bai}"
            return 1
        }

        clear
        echo -e "${gl_zi}>>> 已停止的实例列表:${gl_bai}"
        echo -e "${gl_lan}-----------------------------------------------${gl_bai}"

        printf "${gl_huang}%-4s  ${gl_lv}%-10s  ${gl_huang}%-6s  ${gl_lv}%-20s${gl_bai}\n" "序号" "类型" "ID" "名称"

        for i in "${!STOPPED_INSTANCES[@]}"; do
            [ "${INSTANCE_TYPES[$i]}" = "qemu" ] && local t="虚拟机" || t="LXC容器"
            local pad=""
            case "$t" in
            虚拟机) pad="   " ;;
            *) pad="  " ;;
            esac
            printf "${gl_huang}%2d)  ${gl_lv}%s%-*s  ${gl_huang}%-6s  ${gl_lv}%-20s${gl_bai}\n" \
                "$((i + 1))" "$t" $((6 - ${#t} - ${#pad})) "$pad" "${INSTANCE_IDS[$i]}" "${INSTANCE_NAMES[$i]}"
        done
        echo -e "${gl_lan}-----------------------------------------------${gl_bai}"
        return 0
    }

    # ---------- 启动选中的实例 ----------
    start_instance() {
        local index=$1
        local instance_id="${INSTANCE_IDS[$index]}"
        local instance_type="${INSTANCE_TYPES[$index]}"
        local instance_name="${INSTANCE_NAMES[$index]}"

        local type_str
        [ "$instance_type" = "qemu" ] && type_str="虚拟机" || type_str="LXC容器"

        echo -e "\n${gl_huang}你选择了:${gl_bai}"
        echo -e "  ${type_str} - ID: ${gl_huang}$instance_id${gl_bai} 名称: ${gl_huang}$instance_name${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认要启动这个实例吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
        [yY] | [yY][eE][sS])
            echo -e "${gl_lan}正在启动实例...${gl_bai}"
            if [ "$instance_type" = "qemu" ]; then
                qm start "$instance_id" &&
                    echo -e "${gl_lv}虚拟机 $instance_id 启动命令已发送${gl_bai}" ||
                    {
                        echo -e "${gl_hong}启动虚拟机 $instance_id 失败${gl_bai}"
                        return 1
                    }
            else
                pct start "$instance_id" &&
                    echo -e "${gl_lv}LXC容器 $instance_id 启动命令已发送${gl_bai}" ||
                    {
                        echo -e "${gl_hong}启动LXC容器 $instance_id 失败${gl_bai}"
                        return 1
                    }
            fi
            ;;
        *)
            echo -e "${gl_huang}操作已取消${gl_bai}"
            return 2
            ;;
        esac
        return 0
    }

    # ---------------- 主入口 ----------------
    get_stopped_instances || return 1
    show_stopped_instances || return 1

    while :; do
        read -r -e -p "$(echo -e "${gl_bai}请输入要${gl_huang}启动${gl_bai}的实例序号 (输入 ${gl_huang}0${gl_bai} 返回): ")" choice
        case $choice in
        0)
            return 0
            ;;
        '' | *[!0-9]*)
            echo -e "${gl_hong}错误: 请输入有效的数字序号${gl_bai}"
            return
            ;;
        *)
            local index=$((choice - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#STOPPED_INSTANCES[@]}" ]; then
                start_instance "$index"
                if [ $? -eq 0 ]; then
                    # 倒计时 5 秒，按键可跳过
                    for i in 5 4 3 2 1; do
                        printf "\r${gl_huang}%d 秒后自动返回实例列表…${gl_bai}" "$i"
                        read -n 1 -s -t 1 && break
                    done
                    printf "\r\033[K"
                    read -t 0.001 -n 1000 2>/dev/null
                    # 重新获取数据再展示
                    get_stopped_instances >/dev/null || break
                    show_stopped_instances || break
                fi
            else
                echo -e "${gl_hong}错误: 序号 ${choice} 不在有效范围内${gl_bai}"
            fi
            ;;
        esac
    done
}

pve_restart_selector() {

    # 仅获取数据，不做任何输出
    get_all_instances() {
        ALL_INSTANCES=()
        INSTANCE_TYPES=()
        INSTANCE_IDS=()
        INSTANCE_NAMES=()
        INSTANCE_STATUSES=()

        local instances
        instances=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null)
        [ $? -ne 0 ] && {
            echo -e "${gl_hong}错误: 无法获取实例信息，请检查PVE环境${gl_bai}" >&2
            return 1
        }

        local count=0
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            local vmid type status name
            vmid=$(echo "$line" | jq -r '.vmid')
            type=$(echo "$line" | jq -r '.type')
            status=$(echo "$line" | jq -r '.status')
            name=$(echo "$line" | jq -r '.name')

            ALL_INSTANCES+=("$count")
            INSTANCE_IDS+=("$vmid")
            INSTANCE_TYPES+=("$type")
            INSTANCE_NAMES+=("$name")
            INSTANCE_STATUSES+=("$status")
            ((count++))
        done < <(echo "$instances" | jq -c '.[]')
        return 0
    }

    # ---------- 清屏 + 展示列表 ----------
    show_all_instances() {
        [ ${#ALL_INSTANCES[@]} -eq 0 ] && {
            echo -e "${gl_huang}没有找到任何虚拟机或LXC容器${gl_bai}"
            return 1
        }

        clear
        echo -e "${gl_zi}>>> 所有实例列表:${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        local instances_per_line=3
        local total_instances=${#ALL_INSTANCES[@]}
        local max_width=0
        for ((i = 0; i < total_instances; i++)); do
            local type_str=$([ "${INSTANCE_TYPES[$i]}" = "qemu" ] && echo "VM" || echo "LXC")
            local current_text="${type_str}:${INSTANCE_IDS[$i]}"
            local text_length=${#current_text}
            [ $text_length -gt $max_width ] && max_width=$text_length
        done
        max_width=$((max_width + 4))

        for ((i = 0; i < total_instances; i += instances_per_line)); do
            for ((j = 0; j < instances_per_line; j++)); do
                local index=$((i + j))
                [ $index -ge $total_instances ] && break
                local type_str=$([ "${INSTANCE_TYPES[$index]}" = "qemu" ] && echo "VM" || echo "LXC")
                local status_color status_symbol
                if [ "${INSTANCE_STATUSES[$index]}" = "running" ]; then
                    status_color="${gl_lv}"
                    status_symbol="●"
                else
                    status_color="${gl_hong}"
                    status_symbol="○"
                fi
                printf "${gl_huang}%2d) " "$((index + 1))"
                printf "${status_color}${status_symbol}${gl_bai}%s:${gl_huang}%s${gl_bai}" "$type_str" "${INSTANCE_IDS[$index]}"
                local current_text="${type_str}:${INSTANCE_IDS[$index]}"
                local padding=$((max_width - ${#current_text}))
                printf "%*s" $padding ""
            done
            echo
        done
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_lv}●${gl_bai} 运行中  ${gl_hong}○${gl_bai} 已停止  ${gl_lan}VM${gl_bai}:虚拟机  ${gl_lan}LXC${gl_bai}:容器"
        return 0
    }

    # ---------- 等待实例状态变为目标状态（无中间进度打印） ----------
    wait_for_status() {
        local vmid=$1 want=$2 timeout=${3:-30}
        local tick=0 stat
        while ((tick < timeout)); do
            sleep 1
            stat=$(pvesh get /cluster/resources --type vm --output-format json 2>/dev/null |
                jq -r --arg id "$vmid" '.[] | select(.vmid|tostring==$id) | .status')
            [ "$stat" = "$want" ] && return 0
            ((tick++))
        done
        return 0
    }

    # ---------- 重启/启动实例 ----------
    restart_instance() {
        local index=$1
        local instance_id="${INSTANCE_IDS[$index]}"
        local instance_type="${INSTANCE_TYPES[$index]}"
        local instance_status="${INSTANCE_STATUSES[$index]}"

        local type_str=$([ "$instance_type" = "qemu" ] && echo "虚拟机" || echo "LXC容器")
        local operation=$([ "$instance_status" = "running" ] && echo "重启" || echo "启动")

        echo -e "\n${gl_huang}实例详情:${gl_bai}"
        echo -e "  ${gl_lan}类型:${gl_bai} $type_str"
        echo -e "  ${gl_lan}ID:${gl_bai} ${gl_huang}$instance_id${gl_bai}"
        echo -e "  ${gl_lan}名称:${gl_bai} ${gl_huang}${INSTANCE_NAMES[$index]}${gl_bai}"
        echo -e "  ${gl_lan}状态:${gl_bai} $([ "$instance_status" = "running" ] && echo -e "${gl_lv}运行中" || echo -e "${gl_hong}已停止")${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认要${gl_huang}${operation}${gl_bai}这个实例吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        case "$confirm" in
        [yY] | [yY][eE][sS])
            echo -e "${gl_lan}正在${operation}实例...${gl_bai}"
            if [ "$instance_status" = "running" ]; then
                # 重启
                if [ "$instance_type" = "qemu" ]; then
                    qm reboot "$instance_id" &&
                        echo -e "${gl_lv}虚拟机 $instance_id 重启命令已发送${gl_bai}" ||
                        {
                            echo -e "${gl_hong}重启虚拟机 $instance_id 失败${gl_bai}"
                            return 1
                        }
                else
                    pct reboot "$instance_id" && {
                        echo -e "${gl_lv}LXC容器 $instance_id 重启命令已发送${gl_bai}"
                    } || {
                        echo -e "${gl_hong}重启LXC容器 $instance_id 失败，尝试停止/启动...${gl_bai}"
                        pct shutdown "$instance_id" && pct start "$instance_id" &&
                            echo -e "${gl_lv}LXC容器 $instance_id 通过停止/启动方式重启成功${gl_bai}" ||
                            {
                                echo -e "${gl_hong}重启LXC容器 $instance_id 完全失败${gl_bai}"
                                return 1
                            }
                    }
                fi
                wait_for_status "$instance_id" "running"
            else
                # 启动
                if [ "$instance_type" = "qemu" ]; then
                    qm start "$instance_id" &&
                        echo -e "${gl_lv}虚拟机 $instance_id 启动命令已发送${gl_bai}" ||
                        {
                            echo -e "${gl_hong}启动虚拟机 $instance_id 失败${gl_bai}"
                            return 1
                        }
                else
                    pct start "$instance_id" && {
                        echo -e "${gl_lv}LXC容器 $instance_id 启动命令已发送${gl_bai}"
                    } || {
                        read -r -e -p "$(echo -e "${gl_huang}是否尝试强制启动? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" force

                        [[ $force =~ [yY] ]] && {
                            pct start "$instance_id" --force && f
                            echo -e "${gl_lv}LXC容器 $instance_id 强制启动成功${gl_bai}" ||
                                {
                                    echo -e "${gl_hong}强制启动也失败了${gl_bai}"
                                    return 1
                                }
                        } || return 1
                    }
                fi
                wait_for_status "$instance_id" "running"
            fi
            ;;
        *)
            echo -e "${gl_huang}操作已取消${gl_bai}"
            return 2
            ;;
        esac
        return 0
    }

    # ---------------- 主入口 ----------------
    get_all_instances || return 1
    show_all_instances || return 1

    while true; do
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请输入要操作的实例序号 (输入 ${gl_huang}0${gl_bai} 退出): ")" choice
        case "$choice" in
        0)
            echo -e "${gl_huang}退出程序${gl_bai}"
            break
            ;;
        [1-9] | [1-9][0-9]*)
            local index=$((choice - 1))
            if [ "$index" -ge 0 ] && [ "$index" -lt "${#ALL_INSTANCES[@]}" ]; then
                restart_instance "$index"
                # 5 秒倒计时，可按键跳过
                for i in 5 4 3 2 1; do
                    printf "\r${gl_huang}%d 秒后自动返回实例列表…${gl_bai}" "$i"
                    read -n 1 -s -t 1 && break
                done
                printf "\r\033[K"
                read -t 0.001 -n 1000 2>/dev/null
                # 刷新列表
                get_all_instances >/dev/null || break
                show_all_instances || break
            else
                echo -e "${gl_hong}错误: 序号 ${choice} 不在有效范围内${gl_bai}"
            fi
            ;;
        *)
            echo -e "${gl_hong}错误: 请输入有效的数字序号${gl_bai}"
            ;;
        esac
    done
}

pve_instance_management() {
    while true; do
        clear
        echo -e "${gl_zi}>>> PVE手动管理实例${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1. ${gl_bai} 启动虚拟机"
        echo -e "${gl_bufan}2. ${gl_bai} 关闭虚拟机" 
        echo -e "${gl_bufan}3. ${gl_bai} 启动LXC容器"
        echo -e "${gl_bufan}4. ${gl_bai} 关闭LXC容器"
        echo -e "${gl_bufan}------------------------${gl_bai}"
	echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0. ${gl_bai} 返回主菜单 "
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -e -p "请输入你的选择: " choice

        case $choice in
                1)
                    # 启动虚拟机
                    safe_read "$(echo -e "${gl_bufan}请输入要启动的虚拟机ID(多个用空格隔开，输入 ${gl_huang}0${gl_bai} 返回菜单")" vm_ids
                    if [ "$vm_ids" = "0" ]; then
                        echo -e "${gl_bufan}返回菜单...${gl_bai}"
                        continue
                    fi

                    if [ -n "$vm_ids" ]; then
                        for vm_id in $vm_ids; do
                            if [[ "$vm_id" =~ ^[0-9]+$ ]]; then
                                echo -e "${gl_bufan}启动虚拟机: $vm_id${gl_bai}"
                                qm start "$vm_id"
                            else
                                echo -e "${gl_hong}错误: $vm_id 不是有效的虚拟机ID${gl_bai}"
                            fi
                        done
                    else
                        echo -e "${gl_bufan}错误: 未输入虚拟机ID${gl_bai}"
                    fi

                    read -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")" -n 1 -s
                    ;;
                2)
                    # 关闭虚拟机
                    safe_read "$(echo -e "${gl_bufan}请输入要关闭的虚拟机ID(多个用空格隔开，输入 ${gl_huang}0${gl_bai} 返回菜单")" vm_ids
                    if [ "$vm_ids" = "0" ]; then
                        echo -e "${gl_bufan}返回菜单...${gl_bai}"
                        continue
                    fi

                    if [ -n "$vm_ids" ]; then
                        for vm_id in $vm_ids; do
                            if [[ "$vm_id" =~ ^[0-9]+$ ]]; then
                                echo -e "${gl_bufan}关闭虚拟机: $vm_id${gl_bai}"
                                qm stop "$vm_id"
                            else
                                echo -e "${gl_hong}错误: $vm_id 不是有效的虚拟机ID${gl_bai}"
                            fi
                        done
                    else
                        echo -e "${gl_bufan}错误: 未输入虚拟机ID${gl_bai}"
                    fi
                    read -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")" -n 1 -s
                    ;;
                3)
                    # 启动LXC容器
                    safe_read "$(echo -e "${gl_bufan}请输入要启动的容器ID(多个用空格隔开，输入 ${gl_huang}0${gl_bai} 返回菜单")" ct_ids
                    if [ "$ct_ids" = "0" ]; then
                        echo -e "${gl_bufan}返回菜单...${gl_bai}"
                        continue
                    fi

                    if [ -n "$ct_ids" ]; then
                        for ct_id in $ct_ids; do
                            if [[ "$ct_id" =~ ^[0-9]+$ ]]; then
                                echo -e "${gl_bufan}启动容器: $ct_id${gl_bai}"
                                pct start "$ct_id"
                            else
                                echo -e "${gl_hong}错误: $ct_id 不是有效的容器ID${gl_bai}"
                            fi
                        done
                    else
                        echo -e "${gl_bufan}错误: 未输入容器ID${gl_bai}"
                    fi
                    read -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")" -n 1 -s
                    ;;
                4)
                    # 关闭LXC容器
                    safe_read "$(echo -e "${gl_bufan}请输入要关闭的容器ID(多个用空格隔开，输入 ${gl_huang}0${gl_bai} 返回菜单")" ct_ids
                    if [ "$ct_ids" = "0" ]; then
                        echo -e "${gl_bufan}返回菜单...${gl_bai}"
                        continue
                    fi

                    if [ -n "$ct_ids" ]; then
                        for ct_id in $ct_ids; do
                            if [[ "$ct_id" =~ ^[0-9]+$ ]]; then
                                echo -e "${gl_bufan}关闭容器: $ct_id${gl_bai}"
                                pct shutdown "$ct_id"
                            else
                                echo -e "${gl_hong}错误: $ct_id 不是有效的容器ID${gl_bai}"
                            fi
                        done
                    else
                        echo -e "${gl_bufan}错误: 未输入容器ID${gl_bai}"
                    fi
                    read -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")" -n 1 -s
                    ;;
                0) break ;;
                00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
                *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
  done
}

###### 函数_PVE命令
linux_pve_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> ${gl_huang}PVE  ${gl_zi}管理${gl_bai}"
        echo -e "${gl_zi}>>> 当前主机名：${gl_lv}$(hostname -s)${gl_bai}"
        # echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)"
        # echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}查看所有虚拟机"
        echo -e "${gl_bufan}2.  ${gl_bai}PVE手动管理实例"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai}交互式关闭虚拟机"
        echo -e "${gl_bufan}4.  ${gl_bai}交互式开启虚拟机"
        echo -e "${gl_bufan}5.  ${gl_bai}交互式重启虚拟机"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}6.  ${gl_bai}管理备份目录${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai}管理固件目录${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}8.  ${gl_bai}PVE 更新并清理系统"
        echo -e "${gl_bufan}9.  ${gl_bai}PVE 优化脚本"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            pvesh get /cluster/resources
            break_end
            ;;
        2)
            # PVE手动管理实例
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            pve_instance_management
            ;;
        3)
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
                return
            fi

            clear
            # 检查是否安装 jq
            if ! command -v jq &>/dev/null; then
                echo -e "${gl_huang}检测到 jq 未安装，这是运行PVE管理功能必需的组件${gl_bai}"
                echo -e "${gl_lan}jq 是一个JSON处理工具，用于解析PVE的API输出${gl_bai}"
                echo

                # 检测Linux发行版
                if [ -f /etc/os-release ]; then
                    . /etc/os-release
                    case $ID in
                    debian | ubuntu)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "可以使用命令安装: ${gl_lv}apt update && apt install -y jq${gl_bai}"
                        ;;
                    centos | rhel | fedora)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        if command -v dnf &>/dev/null; then
                            echo -e "可以使用命令安装: ${gl_lv}dnf install -y jq${gl_bai}"
                        else
                            echo -e "可以使用命令安装: ${gl_lv}yum install -y jq${gl_bai}"
                        fi
                        ;;
                    *)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "请使用系统包管理器安装 jq 工具${gl_bai}"
                        ;;
                    esac
                else
                    echo -e "${gl_huang}无法检测系统发行版${gl_bai}"
                    echo -e "请手动安装 jq 工具${gl_bai}"
                fi

                echo
                read -r -e -p "$(echo -e "${gl_huang}是否立即安装 jq? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_choice
                case "$install_choice" in
                [yY] | [yY][eE][sS])
                    echo -e "${gl_lan}开始安装 jq...${gl_bai}"
                    if command -v apt &>/dev/null; then
                        apt update && apt install -y jq
                    elif command -v dnf &>/dev/null; then
                        dnf install -y jq
                    elif command -v yum &>/dev/null; then
                        yum install -y jq
                    else
                        echo -e "${gl_hong}无法自动安装 jq，请手动安装${gl_bai}"
                        read -r -e -p "按任意键继续..."
                        return
                    fi

                    # 检查安装是否成功
                    if command -v jq &>/dev/null; then
                        echo -e "${gl_lv}jq 安装成功！${gl_bai}"
                        read -r -e -p "按任意键继续执行PVE管理功能..."
                    else
                        echo -e "${gl_hong}jq 安装失败，PVE管理功能可能无法正常工作${gl_bai}"
                        read -r -e -p "按任意键继续..."
                    fi
                    ;;
                *)
                    echo -e "${gl_huang}跳过 jq 安装，PVE管理功能可能无法正常工作${gl_bai}"
                    read -r -e -p "按任意键继续..."
                    ;;
                esac
            fi

            clear
            pve_shutdown_selector
            ;;
        4)
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi

            clear
            # 检查是否安装 jq
            if ! command -v jq &>/dev/null; then
                echo -e "${gl_huang}检测到 jq 未安装，这是运行PVE管理功能必需的组件${gl_bai}"
                echo -e "${gl_lan}jq 是一个JSON处理工具，用于解析PVE的API输出${gl_bai}"
                echo

                # 检测Linux发行版
                if [ -f /etc/os-release ]; then
                    . /etc/os-release
                    case $ID in
                    debian | ubuntu)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "可以使用命令安装: ${gl_lv}apt update && apt install -y jq${gl_bai}"
                        ;;
                    centos | rhel | fedora)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        if command -v dnf &>/dev/null; then
                            echo -e "可以使用命令安装: ${gl_lv}dnf install -y jq${gl_bai}"
                        else
                            echo -e "可以使用命令安装: ${gl_lv}yum install -y jq${gl_bai}"
                        fi
                        ;;
                    *)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "请使用系统包管理器安装 jq 工具${gl_bai}"
                        ;;
                    esac
                else
                    echo -e "${gl_huang}无法检测系统发行版${gl_bai}"
                    echo -e "请手动安装 jq 工具${gl_bai}"
                fi

                echo
                read -r -e -p "$(echo -e "${gl_huang}是否立即安装 jq? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_choice
                case "$install_choice" in
                [yY] | [yY][eE][sS])
                    echo -e "${gl_lan}开始安装 jq...${gl_bai}"
                    if command -v apt &>/dev/null; then
                        apt update && apt install -y jq
                    elif command -v dnf &>/dev/null; then
                        dnf install -y jq
                    elif command -v yum &>/dev/null; then
                        yum install -y jq
                    else
                        echo -e "${gl_hong}无法自动安装 jq，请手动安装${gl_bai}"
                        read -r -e -p "按任意键继续..."
                        return
                    fi

                    # 检查安装是否成功
                    if command -v jq &>/dev/null; then
                        echo -e "${gl_lv}jq 安装成功！${gl_bai}"
                        read -r -e -p "按任意键继续执行PVE管理功能..."
                    else
                        echo -e "${gl_hong}jq 安装失败，PVE管理功能可能无法正常工作${gl_bai}"
                        read -r -e -p "按任意键继续..."
                    fi
                    ;;
                *)
                    echo -e "${gl_huang}跳过 jq 安装，PVE管理功能可能无法正常工作${gl_bai}"
                    read -r -e -p "按任意键继续..."
                    ;;
                esac
            fi

            clear
            pve_start_selector
            ;;
        5)
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi

            clear
            # 检查是否安装 jq
            if ! command -v jq &>/dev/null; then
                echo -e "${gl_huang}检测到 jq 未安装，这是运行PVE管理功能必需的组件${gl_bai}"
                echo -e "${gl_lan}jq 是一个JSON处理工具，用于解析PVE的API输出${gl_bai}"
                echo

                # 检测Linux发行版
                if [ -f /etc/os-release ]; then
                    . /etc/os-release
                    case $ID in
                    debian | ubuntu)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "可以使用命令安装: ${gl_lv}apt update && apt install -y jq${gl_bai}"
                        ;;
                    centos | rhel | fedora)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        if command -v dnf &>/dev/null; then
                            echo -e "可以使用命令安装: ${gl_lv}dnf install -y jq${gl_bai}"
                        else
                            echo -e "可以使用命令安装: ${gl_lv}yum install -y jq${gl_bai}"
                        fi
                        ;;
                    *)
                        echo -e "${gl_huang}检测到系统为: $PRETTY_NAME${gl_bai}"
                        echo -e "请使用系统包管理器安装 jq 工具${gl_bai}"
                        ;;
                    esac
                else
                    echo -e "${gl_huang}无法检测系统发行版${gl_bai}"
                    echo -e "请手动安装 jq 工具${gl_bai}"
                fi

                echo
                read -r -e -p "$(echo -e "${gl_bai}是否立即安装 jq? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ${gl_bai}")" install_choice
                case "$install_choice" in
                [yY] | [yY][eE][sS])
                    echo -e "${gl_lan}开始安装 jq...${gl_bai}"
                    if command -v apt &>/dev/null; then
                        apt update && apt install -y jq
                    elif command -v dnf &>/dev/null; then
                        dnf install -y jq
                    elif command -v yum &>/dev/null; then
                        yum install -y jq
                    else
                        echo -e "${gl_hong}无法自动安装 jq，请手动安装${gl_bai}"
                        read -r -e -p "按任意键继续..."
                        return
                    fi

                    # 检查安装是否成功
                    if command -v jq &>/dev/null; then
                        echo -e "${gl_lv}jq 安装成功！${gl_bai}"
                        read -r -e -p "按任意键继续执行PVE管理功能..."
                    else
                        echo -e "${gl_hong}jq 安装失败，PVE管理功能可能无法正常工作${gl_bai}"
                        read -r -e -p "按任意键继续..."
                    fi
                    ;;
                *)
                    echo -e "${gl_huang}跳过 jq 安装，PVE管理功能可能无法正常工作${gl_bai}"
                    read -r -e -p "按任意键继续..."
                    ;;
                esac
            fi

            clear
            pve_restart_selector
            ;;
        6)
            # 管理备份目录
            if [ ! -d "/var/lib/vz/dump" ]; then
                echo -e "${gl_hong}错误：目录 ${gl_huang}/var/lib/vz/dump${gl_hong}不存在！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            echo -e "${gl_zi}>>> 管理备份目录${gl_bai}"
            cd /var/lib/vz/dump && linux_file "$@"
            ;;
        7)
            # 管理固件目录
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：目录 ${gl_huang}/var/lib/vz/template/iso ${gl_hong}不存在！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            echo -e "${gl_zi}>>> 管理固件目录${gl_bai}"
            cd /var/lib/vz/template/iso && linux_file
            ;;
        8)
            # PVE 更新并清理系统
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            sudo apt update && sudo apt -y dist-upgrade && sudo apt autoremove --purge && sudo apt clean
            break_end
            ;;
        9)
            if [ ! -d "/var/lib/vz/template/iso" ]; then
                echo -e "${gl_hong}错误：您这不是PVE系统！${gl_bai}"
                sleep 2  # 暂停 2 秒，可以看到提示信息。
                continue # 继续循环，不退出
            fi
            clear
            wget -q -O /root/pve_source.tar.gz 'https://gitee.com/meimolihan/script/raw/master/sh/pve/pve_source.tar.gz' && tar zxvf /root/pve_source.tar.gz && /root/./pve_source
            break_end
            ;;
        0) mobufan ;;
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 函数：子菜单 Compose容器管理
show_compose_project_menu() {
    local base_path
    base_path="$(pwd)" # 使用当前目录作为基础路径
    if [ ! -d "$base_path" ]; then
        echo -e "${gl_huang}错误: 路径 $base_path 不存在${gl_bai}"
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -r -n 1 -s
        return 1
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> Compose 项目列表${gl_bai}"
        # echo -e "${gl_bufan}Compose 项目列表 - ${gl_huang}$base_path${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 获取目录列表并排序
        local projects=()
        local count=0

        # 读取目录，排除隐藏目录
        for dir in "$base_path"/*/; do
            if [ -d "$dir" ]; then
                local dir_name=$(basename "$dir")
                # 排除以 . 开头的隐藏目录
                if [[ ! "$dir_name" =~ ^\. ]]; then
                    projects+=("$dir_name")
                fi
            fi
        done

        # 按字母顺序排序
        # IFS=$'\n' projects=($(sort <<<"${projects[*]}"))
        mapfile -t projects < <(printf '%s\n' "${projects[@]}" | sort)
        unset IFS

        # 显示项目列表，横向排列
        count=0
        local items_per_line=4 # 每行显示4个项目
        local max_length=0

        # 计算最长项目名的长度，用于对齐
        for project in "${projects[@]}"; do
            local len=${#project}
            if [ "$len" -gt "$max_length" ]; then
                max_length=$len
            fi
        done

        max_length=$((max_length + 4)) # 增加一些间距

        for project in "${projects[@]}"; do
            count=$((count + 1))
            # 使用黄色显示序号，白色显示项目名
            printf "${gl_bufan}%2d.${gl_bai} %-${max_length}s" "$count" "$project"

            # 每行显示指定数量的项目后换行
            if [ $((count % items_per_line)) -eq 0 ]; then
                echo ""
            fi
        done

        # 如果最后一行不满，确保换行
        if [ $((count % items_per_line)) -ne 0 ]; then
            echo ""
        fi

        echo -e "${gl_bufan}------------------------${gl_bai}"

        local project_choice
        read -r -e -p "$(echo -e "${gl_bai}请输入(${gl_bufan}序号${gl_bai}) （输入${gl_bufan}0${gl_bai} 返回）请选择: ")" project_choice

        # 检查是否要退出
        if [ "$project_choice" = "q" ] || [ "$project_choice" = "quit" ] || [ "$project_choice" = "exit" ]; then
            echo -e "${gl_huang}退出操作${gl_bai}"
            return 1
        fi

        # 如果是0，立即返回，不经过任何确认
        if [ "$project_choice" = "0" ]; then
            # 直接返回上一级菜单，不显示任何提示
            return 0
        fi

        # 验证输入是否为有效数字
        if ! [[ "$project_choice" =~ ^[0-9]+$ ]] || [ "$project_choice" -lt 1 ] || [ "$project_choice" -gt $count ]; then
            echo -e "${gl_huang}无效的选择，请重新输入${gl_bai}"
            sleep 1
            return
        fi

        # 处理有效选择
        local selected_project="${projects[$((project_choice - 1))]}"
        local full_path="$base_path/$selected_project"

        # 检查目录是否存在并可以进入
        if [ ! -d "$full_path" ]; then
            echo -e "${gl_hong}错误: 目录 '$full_path' 不存在${gl_bai}"
            echo -e "${gl_bufan}按任意键继续...${gl_bai}"
            read -r -r -n 1 -s
            return
        fi

        # 尝试进入目录
        if cd "$full_path" 2>/dev/null; then
            echo -e "${gl_lv}已选择项目: $selected_project"
            echo -e "${gl_lan}项目路径: $full_path${gl_bai}"
            show_compose_commands_menu
            # 返回项目列表后，回到基础路径
            cd "$base_path"
        else
            echo -e "${gl_hong}错误: 无法进入目录 '$full_path'${gl_bai}"
            echo -e "${gl_bufan}按任意键继续...${gl_bai}"
            read -r -r -n 1 -s
        fi
    done
}

###### 函数：显示Compose命令菜单
show_compose_commands_menu() {
    local current_dir="$(pwd)"

    while true; do
        clear
        echo -e ""

        local current_dir_name=$(basename "$PWD")

        echo -e "${gl_zi}>>> Compose项目菜单${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}当前工作目录: ${gl_huang}$current_dir${gl_bai}"
        echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        echo -e "${gl_bufan}项目名称: ${gl_huang}$current_dir_name${gl_bai}"
	echo -e "${gl_bufan}容器状态：$(
	docker inspect -f \
	'{{if .State.Running}}'"$gl_lv"'已启动'"$gl_bai"'{{else}}'"$gl_hui"'已停止'"$gl_bai"'{{end}}' \
	"$current_dir_name" 2>/dev/null || printf "${gl_hui}容器 ${gl_huang}%s${gl_hui} 不存在${gl_bai}" "$current_dir_name"
	)"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"

        # echo -e "${gl_huang}请选择要执行的 Compose 命令：${gl_bai}"

        # 使用横向排列显示命令选项
        echo -e "${gl_bufan}1.  ${gl_bai}启动${gl_huang}$current_dir_name${gl_bai}服务      ${gl_bufan}2.  ${gl_bai}停止${gl_huang}$current_dir_name${gl_bai}服务"
        echo -e "${gl_bufan}3.  ${gl_bai}重启${gl_huang}$current_dir_name${gl_bai}服务      ${gl_bufan}4.  ${gl_bai}更新${gl_huang}$current_dir_name${gl_bai}容器"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}查看${gl_huang}$current_dir_name${gl_bai}配置      ${gl_bufan}6.  ${gl_bai}编辑${gl_huang}$current_dir_name${gl_bai}配置"
        echo -e "${gl_bufan}7.  ${gl_huang}$current_dir_name${gl_bai}服务状态      ${gl_bufan}8.  ${gl_bai}${gl_huang}$current_dir_name${gl_bai}服务日志"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}99. ${gl_bai}重新构建${gl_huang}$current_dir_name${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回项目列表"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 修复这里：使用正确的参数顺序调用 safe_read
        if ! safe_read "请输入选择" cmd_choice "number" "" 0 9; then
            return
        fi

        case $cmd_choice in
        1)
            # 启动服务
            echo -e "${gl_lv}正在启动服务...${gl_bai}"
            docker-compose up -d
            break_end
            ;;
        2)
            # 停止服务
            echo -e "${gl_huang}正在停止服务...${gl_bai}"
            docker-compose down
            break_end
            ;;
        3)
            # 重启服务
            echo -e "${gl_lan}正在重启服务...${gl_bai}"
            docker-compose restart
            break_end
            ;;
        4)
            # 更新容器
            echo -e "${gl_zi}正在更新容器...${gl_bai}"
            docker-compose down && docker-compose pull && docker-compose up -d && docker image prune -f
            break_end
            ;;
        5)
            # 查看配置文件
            echo -e "${gl_bufan}正在显示配置文件内容...${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                cat docker-compose.yml
            else
                echo -e "${gl_hong}错误: docker-compose.yml 文件不存在${gl_bai}"
            fi
            break_end
            ;;
        6)
            # 编辑配置文件
            echo -e "${gl_huang}正在打开配置文件编辑器...${gl_bai}"
            if [ -f "docker-compose.yml" ]; then
                nano docker-compose.yml
            else
                echo -e "${gl_hong}错误: docker-compose.yml 文件不存在${gl_bai}"
            fi
            break_end
            ;;
        7)
            # 查看服务状态
            echo -e "${gl_lv}正在显示服务状态...${gl_bai}"
            docker-compose ps
            break_end
            ;;
        8)
            # 查看服务日志
            echo -e "${gl_lan}正在显示服务日志...${gl_bai}"
            docker-compose logs
            break_end
            ;;
        99)
            # 重新构建并启动
            echo -e "${gl_zi}正在重新构建并启动服务...${gl_bai}"
            docker-compose up -d --build
            break_end
            ;;
        0) break ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 函数：Git克隆Docker项目
git_clone_docker_projects() {
    # 定义所有仓库的数组
    declare -A repositories=(
        [1]="git@gitee.com:meimolihan/1panel.git"
        [2]="git@gitee.com:meimolihan/dpanel.git"
        [3]="git@gitee.com:meimolihan/sun-panel.git"
        [4]="git@gitee.com:meimolihan/sun-panel-helper.git"
        [5]="git@gitee.com:meimolihan/halo.git"
        [6]="git@gitee.com:meimolihan/hexo.git"
        [7]="git@gitee.com:meimolihan/md.git"
        [8]="git@gitee.com:meimolihan/mindoc.git"
        [9]="git@gitee.com:meimolihan/aipan.git"
        [10]="git@gitee.com:meimolihan/libretv.git"
        [11]="git@gitee.com:meimolihan/moontv.git"
        [12]="git@gitee.com:meimolihan/nastools.git"
        [13]="git@gitee.com:meimolihan/emby.git"
        [14]="git@gitee.com:meimolihan/tvhelper.git"
        [15]="git@gitee.com:meimolihan/musicn.git"
        [16]="git@gitee.com:meimolihan/navidrome.git"
        [17]="git@gitee.com:meimolihan/xiaomusic.git"
        [18]="git@gitee.com:meimolihan/xunlei.git"
        [19]="git@gitee.com:meimolihan/qbittorrent.git"
        [20]="git@gitee.com:meimolihan/transmission.git"
        [21]="git@gitee.com:meimolihan/metube.git"
        [22]="git@gitee.com:meimolihan/cloud-saver.git"
        [23]="git@gitee.com:meimolihan/pansou.git"
        [24]="git@gitee.com:meimolihan/openlist.git"
        [25]="git@gitee.com:meimolihan/nginx-file.git"
        [26]="git@gitee.com:meimolihan/dufs.git"
        [27]="git@gitee.com:meimolihan/taosync.git"
        [28]="git@gitee.com:meimolihan/nginx-dock-builder.git"
        [29]="git@gitee.com:meimolihan/it-tools.git"
        [30]="git@gitee.com:meimolihan/random-pic-api.git"
        [31]="git@gitee.com:meimolihan/mind-map.git"
        [32]="git@gitee.com:meimolihan/easyvoice.git"
        [33]="git@gitee.com:meimolihan/reubah.git"
        [34]="git@gitee.com:meimolihan/easynode.git"
        [35]="git@gitee.com:meimolihan/istoreos.git"
        [36]="git@gitee.com:meimolihan/kspeeder.git"
        [37]="git@gitee.com:meimolihan/uptime-kuma.git"
        [38]="git@gitee.com:meimolihan/speedtest.git"
        [39]="git@gitee.com:meimolihan/watchtower.git"
        [40]="git@gitee.com:meimolihan/gitea.git"
        [41]="git@gitee.com:meimolihan/webtop-ubuntu.git"
        [42]="git@gitee.com:meimolihan/webtop-alpine.git"
    )

    while true; do
        clear
        echo -e "${gl_zi}>>> Git克隆Docker项目${gl_bai}"
        echo -e "${gl_bufan}---------------------- 面板管理类 ----------------------${gl_bai}"
        echo -e "${gl_bufan}1.   ${gl_bai}服务管理1panel               ${gl_bufan}2.   ${gl_bai}容器管理dpanel${gl_bai}"
        echo -e "${gl_bufan}3.   ${gl_bai}导航面板sun-panel            ${gl_bufan}4.   ${gl_bai}导航面板helper${gl_bai}"

        echo -e "${gl_bufan}---------------------- 博客与文档 ----------------------${gl_bai}"
        echo -e "${gl_bufan}5.   ${gl_bai}博客系统halo                 ${gl_bufan}6.   ${gl_bai}博客系统hexo${gl_bai}"
        echo -e "${gl_bufan}7.   ${gl_bai}云文档md                     ${gl_bufan}8.   ${gl_bai}文档管理mindoc${gl_bai}"

        echo -e "${gl_bufan}---------------------- 影视媒体类 ----------------------${gl_bai}"
        echo -e "${gl_bufan}9.   ${gl_bai}爱盼影视                     ${gl_bufan}10.  ${gl_bai}影视聚合libretv${gl_bai}"
        echo -e "${gl_bufan}11.  ${gl_bai}影视聚合moontv               ${gl_bufan}12.  ${gl_bai}影视刮削nastools${gl_bai}"
        echo -e "${gl_bufan}13.  ${gl_bai}媒体服务emby                 ${gl_bufan}14.  ${gl_bai}电视助手tvhelper${gl_bai}"

        echo -e "${gl_bufan}---------------------- 音乐播放类 ----------------------${gl_bai}"
        echo -e "${gl_bufan}15.  ${gl_bai}音乐下载musicn               ${gl_bufan}16.  ${gl_bai}音乐播放navidrome${gl_bai}"
        echo -e "${gl_bufan}17.  ${gl_bai}小米音乐xiaomusic"

        echo -e "${gl_bufan}---------------------- 下载工具类 ----------------------${gl_bai}"
        echo -e "${gl_bufan}18.  ${gl_bai}下载器xunlei                 ${gl_bufan}19.  ${gl_bai}下载器qbittorrent${gl_bai}"
        echo -e "${gl_bufan}20.  ${gl_bai}下载器transmission           ${gl_bufan}21.  ${gl_bai}视频下载metube${gl_bai}"

        echo -e "${gl_bufan}---------------------- 网盘与文件 ----------------------${gl_bai}"
        echo -e "${gl_bufan}22.  ${gl_bai}网盘搜索cloud-saver          ${gl_bufan}23.  ${gl_bai}网盘搜索pansou${gl_bai}"
        echo -e "${gl_bufan}24.  ${gl_bai}网盘挂载openlist             ${gl_bufan}25.  ${gl_bai}文件服务nginx-file${gl_bai}"
        echo -e "${gl_bufan}26.  ${gl_bai}文件服务dufs                 ${gl_bufan}27.  ${gl_bai}云盘同步taosync${gl_bai}"

        echo -e "${gl_bufan}---------------------- 实用工具类 ----------------------${gl_bai}"
        echo -e "${gl_bufan}28.  ${gl_bai}配置编辑                     ${gl_bufan}29.  ${gl_bai}工具箱ittools${gl_bai}"
        echo -e "${gl_bufan}30.  ${gl_bai}随机图片random-pic-api       ${gl_bufan}31.  ${gl_bai}思维导图mind-map${gl_bai}"
        echo -e "${gl_bufan}32.  ${gl_bai}语音文字easyvoice            ${gl_bufan}33.  ${gl_bai}格式转换reubah${gl_bai}"
        echo -e "${gl_bufan}34.  ${gl_bai}终端工具easynode"

        echo -e "${gl_bufan}---------------------- 网络与系统 ----------------------${gl_bai}"
        echo -e "${gl_bufan}35.  ${gl_bai}路由系统istoreos             ${gl_bufan}36.  ${gl_bai}网络加速kspeeder${gl_bai}"
        echo -e "${gl_bufan}37.  ${gl_bai}网站监控uptime-kuma          ${gl_bufan}38.  ${gl_bai}内网测速speedtest${gl_bai}"
        echo -e "${gl_bufan}39.  ${gl_bai}容器更新watchtower           ${gl_bufan}40.  ${gl_bai}代码托管gitea${gl_bai}"
        echo -e "${gl_bufan}41.  ${gl_bai}远程桌面ubuntu               ${gl_bufan}42.  ${gl_bai}远程桌面alpine${gl_bai}"
        echo -e "${gl_bufan}--------------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}88.  ${gl_bai}自定义仓库克隆${gl_bai}"
        echo -e "${gl_bufan}99.  ${gl_bai}克隆全部仓库${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00.  ${gl_bai}退出脚本${gl_bai}"
        echo -e "${gl_bufan}0.   ${gl_bai}返回上一级菜单${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "$(echo -e "请输入你的选择: ")" sub_choice

        case $sub_choice in
        1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39 | 40 | 41 | 42)
            clear
            echo -e "${gl_huang}正在克隆项目 $sub_choice...${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            if git clone "${repositories[$sub_choice]}"; then
                echo -e "${gl_lv}项目 $sub_choice 克隆成功！${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
            else
                echo -e "${gl_hong}项目 $sub_choice 克隆失败！${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
            fi
            read -r -e -p "$(echo -e "${gl_bai}按任意键继续...${gl_bai}")"
            ;;
        88)
            clear
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}自定义仓库克隆${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -rp "$(echo -e "${gl_bufan}请输入Git仓库的URL或git clone命令: ${gl_bai}")" repoUrl
            if [ -z "$repoUrl" ]; then
                echo -e "${gl_hong}错误：未输入有效的URL${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")"
                return
            fi
            local cleanUrl=${repoUrl#*git clone }
            cleanUrl=${cleanUrl//[\"\'\']/}
            local repoName=$(basename "$cleanUrl" .git)

            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}即将克隆仓库: $repoName${gl_bai}"
            echo -e "${gl_bufan}仓库地址: $cleanUrl${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"

            if [ -d "$repoName" ]; then
                echo -e "${gl_huang}警告：仓库目录 '$repoName' 已存在${gl_bai}"
                read -r -rp "$(echo -e "${gl_bufan}是否强制重新克隆? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}) ：")" overwrite
                if [[ ${overwrite,,} != "y" ]]; then
                    echo -e "${gl_lv}已取消克隆${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")"
                    return
                fi
                rm -rf "$repoName"
            fi

            git clone "$cleanUrl"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            if [ $? -ne 0 ]; then
                echo -e "${gl_hong}仓库 '$repoName' 克隆失败，请检查URL是否正确或网络连接。${gl_bai}"
            else
                echo -e "${gl_lv}仓库 '$repoName' 克隆成功！${gl_bai}"
            fi
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}按任意键继续...${gl_bai}")"
            ;;
        99)
            echo -e "${gl_huang}正在克隆全部仓库...${gl_bai}"
            echo -e "${gl_huang}这可能需要一些时间，请耐心等待...${gl_bai}"
            echo -e "${gl_bufan}----------------------------------------${gl_bai}"

            success_count=0
            fail_count=0

            for i in {1..42}; do
                repo_name=$(basename "${repositories[$i]}" .git)
                echo -n "$(echo -e "${gl_huang}克隆 $repo_name ... ${gl_bai}")"
                if git clone "${repositories[$i]}" 2>/dev/null; then
                    echo -e "${gl_lv}成功${gl_bai}"
                    ((success_count++))
                else
                    echo -e "${gl_hong}失败${gl_bai}"
                    ((fail_count++))
                fi
            done

            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "克隆完成: ${gl_lv}成功 $success_count${gl_bai}, ${gl_hong}失败 $fail_count${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bufan}按任意键继续...${gl_bai}")"
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}


###### 检查docker状态
docker_status() {
    # 1. 命令是否存在
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${gl_zi}>>> ${gl_huang}Docker${gl_zi}状态：${gl_hong}未安装${gl_bai}"
        return 1
    fi

    # 2. 直接问 daemon 要版本，能答就说明“已启动”
    #    比猜 init 系统更通用，2 秒超时防止挂死
    if timeout 2 docker version >/dev/null 2>&1; then
        echo -e "${gl_zi}>>> ${gl_huang}Docker${gl_zi}状态：${gl_lv}已启动${gl_bai}"
        return 0
    fi

    # 3. 命令存在但 daemon 无响应 → 已停止
    echo -e "${gl_zi}>>> ${gl_huang}Docker${gl_zi}状态：{gl_hui}已停止{gl_bai}"
    return 2
}
###### 函数_FnOS命令
linux_fnos_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> ${gl_huang}FnOS ${gl_zi}管理${gl_bai}"
        docker_status
        # echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        # echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}Compose容器管理   ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}2.  ${gl_bai}Docker全局状态    ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}3.  ${gl_bai}Docker容器管理    ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}4.  ${gl_bai}Docker镜像管理"
        echo -e "${gl_bufan}5.  ${gl_bai}Docker网络管理"
        echo -e "${gl_bufan}6.  ${gl_bai}Docker卷管理"
        echo -e "${gl_bufan}------------------------"
        echo -e "${gl_bufan}7.  ${gl_bai}清理无用的docker容器和镜像网络数据卷"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}9.  ${gl_bai}克隆Docker项目"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice

        case $sub_choice in
        1)
            # Compose容器管理
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            if [ ! -d "/vol1/1000/compose" ]; then
                echo -e "${gl_huang}错误：目录 /vol1/1000/compose 不存在。${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi
            clear
            cd /vol1/1000/compose
            if show_compose_project_menu; then
                :
            else
                break_end
            fi
            ;;
        2)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            clear
            local container_count=$(docker ps -a -q 2>/dev/null | wc -l)
            local image_count=$(docker images -q 2>/dev/null | wc -l)
            local network_count=$(docker network ls -q 2>/dev/null | wc -l)
            local volume_count=$(docker volume ls -q 2>/dev/null | wc -l)

            echo "Docker版本"
            docker -v
            docker compose version

            echo ""
            echo -e "Docker镜像: ${gl_lv}$image_count${gl_bai} "
            docker image ls
            echo ""
            echo -e "Docker容器: ${gl_lv}$container_count${gl_bai}"
            docker ps -a
            echo ""
            echo -e "Docker卷: ${gl_lv}$volume_count${gl_bai}"
            docker volume ls
            echo ""
            echo -e "Docker网络: ${gl_lv}$network_count${gl_bai}"
            docker network ls
            echo ""
            break_end
            ;;
        3)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            docker_ps
            ;;
        4)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            docker_image
            ;;
        5)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            while true; do
                clear
                echo -e "${gl_bufan}Docker网络列表${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo ""
                docker network ls
                echo ""
                echo -e "${gl_bufan}------------------------${gl_bai}"
                container_ids=$(docker ps -q)
                printf "%-25s %-25s %-25s\n" "容器名称" "网络名称" "IP地址"

                for container_id in $container_ids; do
                    local container_info=$(docker inspect --format '{{ .Name }}{{ range $network, $config := .NetworkSettings.Networks }} {{ $network }} {{ $config.IPAddress }}{{ end }}' "$container_id")

                    local container_name=$(echo "$container_info" | awk '{print $1}')
                    local network_info=$(echo "$container_info" | cut -d' ' -f2-)

                    while IFS= read -r -r line; do
                        local network_name=$(echo "$line" | awk '{print $1}')
                        local ip_address=$(echo "$line" | awk '{print $2}')

                        printf "%-20s %-20s %-15s\n" "$container_name" "$network_name" "$ip_address"
                    done <<<"$network_info"
                done

                echo ""
                echo -e "${gl_zi}>>> 网络操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}创建网络"
                echo -e "${gl_bufan}2. ${gl_bai}加入网络"
                echo -e "${gl_bufan}3. ${gl_bai}退出网络"
                echo -e "${gl_bufan}4. ${gl_bai}删除网络"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    read -r -e -p "设置新网络名: " dockernetwork
                    docker network create "$dockernetwork"
                    break_end
                    ;;
                2)
                    read -r -e -p "加入网络名: " dockernetwork
                    read -r -e -p "那些容器加入该网络（多个容器名请用空格分隔）: " dockernames

                    for dockername in $dockernames; do
                        docker network connect "$dockernetwork" "$dockername"
                    done
                    break_end
                    ;;
                3)
                    read -r -e -p "退出网络名: " dockernetwork
                    read -r -e -p "那些容器退出该网络（多个容器名请用空格分隔）: " dockernames

                    for dockername in $dockernames; do
                        docker network disconnect "$dockernetwork" "$dockername"
                    done
                    break_end
                    ;;
                4)
                    read -r -e -p "请输入要删除的网络名: " dockernetwork
                    docker network rm "$dockernetwork"
                    break_end
                    ;;
                00 | 000 | 0000)
                    clear
                    exit
                    ;;
                0) break ;;
                *)
                    echo -e "${gl_hong}无效的输入,请重新输入!"
                    sleep 2  # 暂停 2 秒，可以看到提示信息。
                    continue # 继续循环，不退出
                    ;;
                esac
            done
            ;;
        6)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            while true; do
                clear
                echo -e "${gl_bufan}Docker卷列表${gl_bai}"
                echo ""
                docker volume ls
                echo ""
                echo -e "${gl_zi}>>> 卷操作${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}1. ${gl_bai}创建新卷"
                echo -e "${gl_bufan}2. ${gl_bai}删除指定卷"
                echo -e "${gl_bufan}3. ${gl_bai}删除所有卷"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
                echo -e "${gl_bufan}0. ${gl_bai}返回上一级选单"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "请输入你的选择: " sub_choice

                case $sub_choice in
                1)
                    read -r -e -p "设置新卷名: " dockerjuan
                    docker volume create "$dockerjuan"
                    break_end
                    ;;
                2)
                    read -r -e -p "输入删除卷名（多个卷名请用空格分隔）: " dockerjuans

                    for dockerjuan in $dockerjuans; do
                        docker volume rm "$dockerjuan"
                    done
                    break_end
                    ;;
                3)
                    read -r -e -p "$(echo -e "${gl_hong}注意: ${gl_bai}确定删除所有未使用的卷吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
                    case "$choice" in
                    [Yy])
                        docker volume prune -f
                        ;;
                    [Nn]) ;;
                    *)
                        echo "无效的选择，请输入 Y 或 N。"
                        ;;
                    esac
                    break_end
                    ;;
                00 | 000 | 0000)
                    clear
                    exit
                    ;;
                0) break ;;
                *)
                    echo -e "${gl_hong}无效的输入,请重新输入!"
                    sleep 2  # 暂停 2 秒，可以看到提示信息。
                    continue # 继续循环，不退出
                    ;;
                esac
            done
            ;;
        7)
            # 检查 Docker 是否安装
            if ! command -v docker &>/dev/null; then
                echo -e "${gl_huang}检测到系统未安装 Docker${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}是否立即安装 Docker？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" install_docker

                if [ "$install_docker" = "y" ] || [ "$install_docker" = "Y" ]; then
                    echo -e "${gl_huang}正在安装 Docker...${gl_bai}"
                    if bash <(curl -sL kejilion.sh) docker install; then
                        echo -e "${gl_lv}Docker 安装成功！${gl_bai}"
                        # 等待一段时间让 Docker 服务完全启动
                        sleep 3
                    else
                        echo -e "${gl_hong}Docker 安装失败，请手动安装后重试${gl_bai}"
                        read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                        return
                    fi
                else
                    echo -e "${gl_huang}已取消安装，返回主菜单${gl_bai}"
                    read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                    return
                fi
            fi

            # 检查 Docker 服务是否运行
            if ! docker info &>/dev/null; then
                echo -e "${gl_hong}Docker 服务未运行，请先启动 Docker 服务${gl_bai}"
                read -r -e -p "$(echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}")"
                return
            fi

            clear
            read -r -e -p "$(echo -e "${gl_huang}提示: ${gl_bai}将清理无用的镜像容器网络，包括停止的容器，确定清理吗？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" choice
            case "$choice" in
            [Yy])
                docker system prune -af --volumes
                ;;
            [Nn]) ;;
            *)
                echo "无效的选择，请输入 Y 或 N。"
                ;;
            esac
            break_end
            ;;
        9)
            # 克隆Docker项目
            git_clone_docker_projects
            # bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/compose/git_clone_docker.sh)
            ;;
        0)
            mobufan
            ;;
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 添加提示信息，N 秒后继续
        esac
    done
}

###### 证书检查公共函数
cert_check() {
  local cert=${1:-}
  [[ -z $cert ]] && { log_error "用法：cert_check <证书文件路径>"; return 1; }
  [[ ! -f $cert ]] && { log_error "文件 $cert 不存在！"; return 2; }

  local start_sec end_sec now_sec left_days
  start_sec=$(openssl x509 -in "$cert" -noout -startdate | cut -d= -f2 | xargs -I{} date -d "{}" +%s)
  end_sec=$(openssl x509 -in "$cert" -noout -enddate   | cut -d= -f2 | xargs -I{} date -d "{}" +%s)
  now_sec=$(date +%s)
  left_days=$(( (end_sec - now_sec) / 86400 ))

  local start_str end_str
  start_str=$(date -d "@$start_sec" +"%Y年%m月%d日 %H:%M:%S")
  end_str=$(date -d "@$end_sec"   +"%Y年%m月%d日 %H:%M:%S")

  local COLOR STATUS
  if (( left_days < 0 )); then
    COLOR=$gl_hong; STATUS='【已过期】'
  elif (( left_days <= 30 )); then
    COLOR=$gl_huang; STATUS='【即将到期】'
  else
    COLOR=$gl_lv; STATUS='【正常】'
  fi

  local cert_file_name
            cert_file_name=${cert##*/}
  echo -e ""
  echo -e "${gl_zi}>>> ${gl_huang}$cert_file_name ${gl_zi}证书过期时间${gl_bai}"
  echo -e "${gl_bufan}------------------------${gl_bai}"
  echo -e "${gl_bai}生效时间：${COLOR}$start_str${gl_bai}"
  echo -e "${gl_bai}到期时间：${COLOR}$end_str${gl_bai}"
  echo -e "${gl_bai}剩余天数：${COLOR}$left_days 天 $STATUS${gl_bai}"
  echo -e "${gl_bai}文件路径：${gl_huang}$cert${gl_bai}"
  echo -e "${gl_bufan}------------------------${gl_bai}"
}


###### 自动修复nginx日志权限
ngx_log_auto_perm() {
    clear
    echo -e ""
    echo -e "${gl_zi}>>> 修复nginx日志权限${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    # ---------- 1. 识别 Nginx 运行用户 ----------
    log_info "识别 Nginx 运行用户 …"
    local NG_USER
    NG_USER=$(awk '$1=="user"{print $2}' /etc/nginx/nginx.conf 2>/dev/null | tr -d ';')
    [[ -z "$NG_USER" ]] && NG_USER=$(systemctl show -p User --value nginx 2>/dev/null)
    [[ -z "$NG_USER" || "$NG_USER" == "n/a" ]] && NG_USER=$(ps -eo user,comm | awk '$2=="nginx" && $1!="root"{print $1; exit}')
    [[ -z "$NG_USER" ]] && { log_error "无法识别 Nginx 运行用户"; return 1; }
    log_ok "Nginx 运行用户：$NG_USER"

    echo -e "${gl_bufan}------------------------${gl_bai}"
    # ---------- 2. 提取所有日志路径 ----------
    log_info "提取日志路径 …"
    local NGINX_CONF=${NGINX_CONF:-/etc/nginx/nginx.conf}
    mapfile -t confs < <(
        (
            echo "$NGINX_CONF"
            grep -hE 'include\s+[^;]+;' "$NGINX_CONF" 2>/dev/null |
            sed -r 's/.*include\s+([^;]+).*/\1/' |
            while read -r inc; do
                [[ ${inc:0:1} != "/" ]] && inc=$(dirname "$NGINX_CONF")/$inc
                for f in $inc; do [[ -f "$f" ]] && echo "$f"; done
            done
        ) | sort -u
    )
    local tmp
    tmp=$(mktemp)
    cat "${confs[@]}" 2>/dev/null >"$tmp"
    mapfile -t LOGS < <(
        grep -hE '^\s*(access_log|error_log)\s+' "$tmp" 2>/dev/null |
        grep -vE '\s+(off|stderr)\s*;' | awk '{print $2}' | sed 's/;$//' | sort -u
    )
    rm -f "$tmp"
    ((${#LOGS[@]}==0)) && { log_warn "未发现任何日志路径"; return 0; }
    log_ok "共发现 ${#LOGS[@]} 条日志"

    echo -e "${gl_bufan}------------------------${gl_bai}"
    # ---------- 3. 加权限 ----------
    for log in "${LOGS[@]}"; do
        [[ ! -f "$log" ]] && { log_warn "文件不存在，跳过：$log"; continue; }
        local dir
        dir=$(dirname "$log")
        log_info "$log  →  dir:$dir"
        chown root:"$NG_USER" "$dir" "$log"
        chmod 755 "$dir"
        chmod 640 "$log"
    done

    echo -e "${gl_bufan}------------------------${gl_bai}"
    log_ok "权限修复完成！目录 755，文件 640，属主 root，属组 $NG_USER"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    return 0
}

###### 查看所有nginx服务
extract_nginx_links_simple() {
    local conf_dir="$1"
    
    if [[ ! -d "$conf_dir" ]]; then
        echo "错误: 目录 '$conf_dir' 不存在"
        return 1
    fi
    
    echo -e "正在扫描目录: ${gl_huang}$conf_dir${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    
    for conf_file in "$conf_dir"/*.conf; do
        [[ ! -f "$conf_file" ]] && continue
        
        echo -e "处理文件: ${gl_huang}$(basename "$conf_file")${gl_bai}"
        
        # 逐行读取文件，手动解析server块
        local in_server=0
        local server_name=""
        local listen_port=""
        local has_ssl=0
        
        while IFS= read -r line; do
            # 检测server块开始
            if [[ "$line" =~ ^[[:space:]]*server[[:space:]]*\{ ]]; then
                in_server=1
                server_name=""
                listen_port=""
                has_ssl=0
                continue
            fi
            
            # 检测server块结束
            if [[ "$in_server" -eq 1 && "$line" =~ ^[[:space:]]*\}[[:space:]]*$ ]]; then
                if [[ -n "$server_name" && -n "$listen_port" ]]; then
                    local protocol="http"
                    if [[ "$has_ssl" -eq 1 ]]; then
                        protocol="https"
                    fi
                    
                    if [[ "$listen_port" == "80" && "$protocol" == "http" ]]; then
                        echo "链接: ${protocol}://${server_name}"
                    elif [[ "$listen_port" == "443" && "$protocol" == "https" ]]; then
                        echo "链接: ${protocol}://${server_name}"
                    else
                        echo -e "链接: ${gl_lv}${protocol}://${server_name}:${listen_port}${gl_bai}"
                    fi
                fi
                in_server=0
                continue
            fi
            
            # 在server块内解析配置
            if [[ "$in_server" -eq 1 ]]; then
                # 提取server_name
                if [[ "$line" =~ ^[[:space:]]*server_name[[:space:]]+([^;]+) ]]; then
                    server_name="${BASH_REMATCH[1]}"
                    # 移除可能的多余空格
                    server_name=$(echo "$server_name" | xargs)
                fi
                
                # 提取listen和端口
                if [[ "$line" =~ ^[[:space:]]*listen[[:space:]]+([^;]+) ]]; then
                    local listen_value="${BASH_REMATCH[1]}"
                    # 检查ssl
                    if [[ "$listen_value" == *"ssl"* ]]; then
                        has_ssl=1
                    fi
                    # 提取端口号
                    if [[ "$listen_value" =~ :([0-9]+) ]]; then
                        listen_port="${BASH_REMATCH[1]}"
                    elif [[ "$listen_value" =~ ^[[:space:]]*([0-9]+) ]]; then
                        listen_port="${BASH_REMATCH[1]}"
                    fi
                fi
            fi
        done < "$conf_file"
        echo -e "${gl_bufan}------------------------${gl_bai}"
    done
}

###### 打印“已启动/已停止/未安装”以及版本号
view_nginx_status(){
    # 1. 先检查二进制是否存在
    if ! command -v nginx &>/dev/null; then
        echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}状态：${gl_hong}未安装${gl_bai}"
        return
    fi

    # 2. 再判断 systemd 是否可用
    if ! command -v systemctl &>/dev/null; then
        echo "systemctl 不可用，退而使用 ps 检测"
        if pgrep -x nginx &>/dev/null; then
            echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}状态：${gl_lv}已启动${gl_bai}"
        else
            echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}状态：${gl_hui}已停止${gl_bai}"
        fi
        return
    fi

    # 3. systemctl 可用，走官方 is-active
    local active=$(systemctl is-active nginx 2>/dev/null)
    local ver=$(nginx -v 2>&1 | grep -oP 'nginx/\K[^ ]+')
    case "$active" in
        active)  echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}状态：${gl_lv}已启动${gl_bai}   ${gl_bai}版本: ${gl_lv}$ver${gl_bai}" ;;
        inactive|failed|*) echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}状态：${gl_hui}已停止${gl_bai}   ${gl_bai}版本: ${gl_lv}$ver${gl_bai}" ;;
    esac
}

# 函数：显示Nginx命令
linux_nginx_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> ${gl_huang}Nginx${gl_zi}管理${gl_bai}"
        view_nginx_status
        # echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        # echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}停止Nginx              ${gl_bufan}2.  ${gl_bai}启动Nginx"
        echo -e "${gl_bufan}3.  ${gl_bai}测试Nginx并重启        ${gl_bufan}4.  ${gl_bai}查看Nginx运行状态"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai}查看80端口占用         ${gl_bufan}6.  ${gl_bai}搜索监听80端口的配置"
        echo -e "${gl_bufan}7.  ${gl_bai}管理conf.d目录         ${gl_bufan}8.  ${gl_bai}管理html目录"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}11. ${gl_bai}访问日志实时监控       ${gl_bufan}12. ${gl_bai}错误日志实时监控"
        echo -e "${gl_bufan}13. ${gl_bai}查看证书路径           ${gl_bufan}14. ${gl_bai}查看证书过期时间"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}15. ${gl_bai}查看nginx监听端口      ${gl_bufan}16. ${gl_bai}自动修复nginx日志权限"
        echo -e "${gl_bufan}17. ${gl_bai}搜索配置文件           ${gl_bufan}18. ${gl_bai}编辑配置文件"
        echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
        echo -e "${gl_bufan}77. ${gl_bai}查看所有nginx服务      ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}88. ${gl_bai}查看所有证书过期时间   ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}99. ${gl_bai}配置个人网站脚本       ${gl_huang}★${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        read -r -e -p "请输入你的选择: " choice
        case $choice in
        1)
            # 停止Nginx
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}Nginx状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            systemctl stop nginx
            echo -e "${gl_bufan}Nginx已停止${gl_bai}"
            break_end
            ;;
        2)
            # 启动Nginx
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}Nginx状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            systemctl start nginx
            echo -e "${gl_bufan}Nginx已启动${gl_bai}"
            break_end
            ;;
        3)
            # 测试Nginx并重启
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}Nginx状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            nginx -t && systemctl restart nginx
            break_end
            ;;
        4)
            # 查看Nginx运行状态
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            systemctl status nginx
            break_end
            ;;
        5)
            # 查看 80 端口占用
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}Nginx状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            ss -tulnp | grep ":80 "
            break_end
            ;;
        6)
            # 搜索监听80端口的配置
            if ! command -v nginx &>/dev/null; then
                echo -e "${gl_bai}Nginx状态：${gl_hong}未安装${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                linux_nginx_menu
            fi
            grep -R 'listen.*80' /etc/nginx/
            break_end
            ;;
        7)
            # 管理conf.d目录
            if [ ! -d "/etc/nginx/conf.d" ]; then
                echo -e "${gl_huang}错误：目录 /etc/nginx/conf.d 不存在。${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                echo
                linux_nginx_menu
            fi
            clear
            cd /etc/nginx/conf.d && linux_file "$@"
            ;;
        8)
            # 管理html目录
            if [ ! -d "/etc/nginx/html" ]; then
                echo -e "${gl_huang}错误：目录 /etc/nginx/html 不存在。${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                echo
                linux_nginx_menu
            fi
            clear
            cd /etc/nginx/html && linux_file "$@"
            ;;
        11)
            # 访问日志实时监控
            if [ ! -f "/var/log/nginx/access.log" ]; then
                echo -e "${gl_huang}错误：访问日志文件 /var/log/nginx/access.log 不存在。${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                echo
                linux_nginx_menu
            fi
            clear
            tail -f /var/log/nginx/access.log
            ;;
        12)
            # 错误日志实时监控
            if [ ! -f "/var/log/nginx/error.log" ]; then
                echo -e "${gl_huang}错误：错误日志文件/var/log/nginx/error.log 不存在。${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                echo
                linux_nginx_menu
            fi
            clear
            tail -f /var/log/nginx/error.log
            ;;
        13)
            # 查看证书路径
            if [ ! -d "/etc/nginx" ]; then
                echo -e "${gl_huang}错误：目录 /etc/nginx 不存在。${gl_bai}"
                read -r -n1 -s -p "按任意键返回..."
                echo
                linux_nginx_menu
            fi
            find /etc/nginx -type f -iname '*.pem' -print
            break_end
            ;;
        14)
            # 查看证书过期时间
            read -r -e -p "输入证书路径 (如：/etc/nginx/keyfile/xxx.pem): " certificate
            clear
            cert_check "$certificate"
            break_end
            ;;
        15)
            # 查看nginx监听端口
            clear
            sudo ss -tulnp | grep nginx
            break_end
            ;;
        16)
            # 自动修复nginx日志权限
            ngx_log_auto_perm
            break_end
            ;;
        17)
            # 搜索配置文件
            read -r -e -p "请输入关键字: " keyword
            find /etc/nginx -type f -iname '*.conf' \
                -exec grep -iHn --color=always "${keyword}" {} +
            break_end
            ;;
        18)
            # 编辑配置文件
            install nano
            read -r -e -p "请输入配置文件路径: " keyword
            nano "${keyword}" 
            break_end
            ;;
        77)
            # 查看所有nginx服务
            clear
            extract_nginx_links_simple "/etc/nginx/conf.d"
            break_end
            ;;
        88)
            # 查看所有证书过期时间
            clear
            local pem_files
            pem_files=$(find /etc/nginx -type f -iname '*.pem' 2>/dev/null)
            if [[ -z $pem_files ]]; then
                log_warn "未在 /etc/nginx 下找到任何 *.pem 证书文件"
            else
                while IFS= read -r cert; do
                    cert_check "$cert"
                done <<< "$pem_files"
            fi
            break_end
            ;;
        99)
            # 配置个人网站脚本
            if [ ! -d "/etc/nginx/html" ]; then
                echo -e "${gl_huang}错误：目录 /etc/nginx/html 不存在。${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                read -r -e -p "按任意键返回主菜单..."
                return
            fi
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/nginx/create_nginx_conf.sh)
            break_end
            ;;
        0) break ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

###### 检查Git状态
git_status() {
    # 1. 命令是否存在
    if ! command -v git >/dev/null 2>&1; then
        echo -e "${gl_zi}>>> ${gl_bai}Git  状态：${gl_hong}未安装${gl_bai}"
        return 1
    fi

    # 2. 是否能成功调用 git 版本（验证 git 可用）
    if git --version >/dev/null 2>&1; then
        echo -e "${gl_zi}>>> ${gl_huang}Git  ${gl_zi}状态：${gl_lv}已启动${gl_bai}"
        return 0
    else
        echo -e "${gl_zi}>>> ${gl_huang}Git  ${gl_zi}状态：${gl_hui}已停止${gl_bai}"
        return 2
    fi
}

###### 函数：显示 Git脚本
linux_git_menu() {
    while true; do
        clear
        echo -e ""
        echo -e "${gl_zi}>>> ${gl_huang}Git  ${gl_zi}管理${gl_bai}"
        git_status
        # echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        # echo -e "${gl_bufan}内网 IP 地址: ${gl_huang}$(get_internal_ip)${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}推送更新"
        echo -e "${gl_bufan}2.  ${gl_bai}拉取更新"
        echo -e "${gl_bufan}3.  ${gl_bai}Git项目管理工具"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}4.  ${gl_bai}Gitee配置SSH"
        echo -e "${gl_bufan}5.  ${gl_bai}GitHub配置SSH"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}6.  ${gl_bai}Gitee新仓库初始化"
        echo -e "${gl_bufan}7.  ${gl_bai}GitHub新仓库初始化"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}8.  ${gl_bai}修改为ssh连接"
        echo -e "${gl_bufan}9.  ${gl_bai}修改为https连接"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai}返回主菜单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " choice

        case $choice in
        1)
            # 推送更新
            check_and_install git || continue   # 检查 Git 是否安装
            # 检查当前目录是否为 Git 仓库
            if ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_hong}错误：当前目录不是 Git 仓库！${gl_bai}"
                echo -e "${gl_huang}请确保在 Git 仓库目录中执行此操作。${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                sleep 3 # 暂停 3 秒，可以看到提示信息。
                linux_git_menu
            fi
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/git_push.sh)
            break_end
            ;;
        2)
            # 拉取更新
            check_and_install git || continue   # 检查 Git 是否安装
            # 检查当前目录是否为 Git 仓库
            if ! git rev-parse --git-dir >/dev/null 2>&1; then
                echo -e "${gl_bufan}------------------------${gl_bai}"
                echo -e "${gl_hong}错误：当前目录不是 Git 仓库！${gl_bai}"
                echo -e "${gl_huang}请确保在 Git 仓库目录中执行此操作。${gl_bai}"
                echo -e "${gl_bufan}------------------------${gl_bai}"
                sleep 3 # 暂停 3 秒，可以看到提示信息。
                linux_git_menu
            fi
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/git_update.sh)
            break_end
            ;;
        3)
            # Git项目管理工具
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL https://gitee.com/meimolihan/script/raw/master/sh/git/git-manager-tool.sh)
            ;;
        4)
            # Gitee配置SSH
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git-ssh/gitee-ssh-init.sh)
            break_end
            ;;
        5)
            # GitHub配置SSH
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git-ssh/github-ssh-init.sh)
            break_end
            ;;
        6)
            # Gitee新仓库初始化
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/gitee_new_godown.sh)
            break_end
            ;;
        7)
            # GitHub新仓库初始化
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/github_new_godown.sh)
            break_end
            ;;
        8)
            # 修改为ssh连接
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/git_ssh_config.sh)
            break_end
            ;;
        9)
            # 修改为https连接
            check_and_install git || continue   # 检查 Git 是否安装
            clear
            bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/git/git_https_config.sh)
            break_end
            ;;
        0) break ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

# 安装回收站功能
install_trash() {
    local trash_cmd=""

    # 检测系统并设置相应的回收站命令
    if command -v trash-put &>/dev/null; then
        trash_cmd="trash-put"
        echo -e "${gl_lv}检测到已安装 trash-cli 回收站工具${gl_bai}"
    elif command -v gio &>/dev/null; then
        trash_cmd="gio trash"
        echo -e "${gl_lv}检测到已安装 gio 回收站工具${gl_bai}"
    else
        echo -e "${gl_huang}未找到回收站工具，正在尝试安装...${gl_bai}"

        # 根据不同的包管理器安装回收站工具
        if command -v apt &>/dev/null; then
            echo -e "${gl_lan}检测到 Debian/Ubuntu 系统，安装 trash-cli...${gl_bai}"
            sudo apt update && sudo apt install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v yum &>/dev/null; then
            echo -e "${gl_lan}检测到 CentOS/RHEL 系统，安装 trash-cli...${gl_bai}"
            sudo yum install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v dnf &>/dev/null; then
            echo -e "${gl_lan}检测到 Fedora 系统，安装 trash-cli...${gl_bai}"
            sudo dnf install -y trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        elif command -v pacman &>/dev/null; then
            echo -e "${gl_lan}检测到 Arch Linux 系统，安装 trash-cli...${gl_bai}"
            sudo pacman -S --noconfirm trash-cli
            if command -v trash-put &>/dev/null; then
                trash_cmd="trash-put"
            fi
        else
            echo -e "${gl_hong}无法自动安装回收站工具，请手动安装 trash-cli${gl_bai}"
            return 1
        fi
    fi

    # 设置全局变量供其他函数使用
    if [[ -n "$trash_cmd" ]]; then
        TRASH_CMD="$trash_cmd"
        echo -e "${gl_lv}回收站功能已启用: $TRASH_CMD${gl_bai}"
        return 0
    else
        echo -e "${gl_hong}回收站工具安装失败${gl_bai}"
        return 1
    fi
}

# 删除文件函数（使用回收站）
delete_file_with_trash() {
    local file="$1"

    # 检查文件名是否为空
    if [[ -z "$file" ]]; then
        echo -e "${gl_hong}错误：文件名参数为空${gl_bai}"
        return 1
    fi

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_huang}回收站未初始化，尝试自动安装...${gl_bai}"
        install_trash || {
            echo -e "${gl_hong}回收站安装失败，将使用直接删除${gl_bai}"
            return 1
        }
    fi

    if [[ -e "$file" ]]; then
        echo -e "${gl_lan}正在移动到回收站: $file${gl_bai}"
        if eval "$TRASH_CMD \"$file\""; then
            echo -e "${gl_lv}✓ 已移动到回收站: $file${gl_bai}"
            return 0
        else
            echo -e "${gl_hong}✗ 移动到回收站失败: $file${gl_bai}"
            return 1
        fi
    else
        echo -e "${gl_huang}文件不存在: $file${gl_bai}"
        return 1
    fi
}

# 获取回收站内容列表
get_trash_list() {
    local trash_items=()

    if [[ -z "$TRASH_CMD" ]]; then
        echo "[]"
        return
    fi

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        if [[ -d "$trash_dir/files" ]]; then
            local count=1
            for item in "$trash_dir/files"/*; do
                if [[ -e "$item" ]]; then
                    local filename=$(basename "$item")
                    local info_file="$trash_dir/info/${filename}.trashinfo"
                    local original_path=""
                    local deletion_date=""

                    if [[ -f "$info_file" ]]; then
                        original_path=$(grep "^Path=" "$info_file" | cut -d= -f2-)
                        deletion_date=$(grep "^DeletionDate=" "$info_file" | cut -d= -f2-)
                    fi

                    trash_items+=("{\"index\":$count,\"name\":\"$filename\",\"original_path\":\"$original_path\",\"deletion_date\":\"$deletion_date\"}")
                    ((count++))
                fi
            done
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
        local count=1
        while IFS= read -r -r line; do
            if [[ -n "$line" ]]; then
                # 解析 trash-list 输出格式：YYYY-MM-DD HH:MM:SS /path/to/file
                local deletion_date=$(echo "$line" | awk '{print $1 " " $2}')
                local original_path=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//')
                local filename=$(basename "$original_path")

                trash_items+=("{\"index\":$count,\"name\":\"$filename\",\"original_path\":\"$original_path\",\"deletion_date\":\"$deletion_date\"}")
                ((count++))
            fi
        done < <(trash-list 2>/dev/null)
    fi

    # 输出JSON格式的列表
    if [[ ${#trash_items[@]} -eq 0 ]]; then
        echo "[]"
    else
        echo "[$(
            IFS=,
            echo "${trash_items[*]}"
        )]"
    fi
}

# 显示回收站内容和统计信息
show_trash_contents_and_stats() {
    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_huang}回收站未启用${gl_bai}"
        return
    fi

    local trash_json=$(get_trash_list)
    local item_count=0

    # 计算项目数量
    if command -v jq &>/dev/null; then
        item_count=$(echo "$trash_json" | jq length)
    else
        # 如果没有jq，手动计算
        item_count=$(echo "$trash_json" | grep -o '"index"' | wc -l)
    fi

    if [[ $item_count -eq 0 ]]; then
        echo -e "${gl_huang}回收站为空${gl_bai}"
        return
    fi

    # 显示回收站内容（横向排列）
    echo -e "${gl_bufan}回收站中的文件:${gl_bai}"
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"
    echo

    # 收集所有文件名
    local files=()
    if command -v jq &>/dev/null; then
        while IFS= read -r -r line; do
            files+=("$line")
        done < <(echo "$trash_json" | jq -r '.[] | "\(.index). \(.name)"')
    else
        # 如果没有jq，使用其他方法
        local index=1
        if [[ "$TRASH_CMD" == "gio trash" ]]; then
            local trash_dir="$HOME/.local/share/Trash/files"
            for item in "$trash_dir"/*; do
                if [[ -e "$item" ]]; then
                    local filename=$(basename "$item")
                    files+=("$index. $filename")
                    ((index++))
                fi
            done
        elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
            while IFS= read -r -r line; do
                if [[ -n "$line" ]]; then
                    local filename=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//' | xargs basename)
                    files+=("$index. $filename")
                    ((index++))
                fi
            done < <(trash-list)
        fi
    fi

    # 横向排列显示
    local count=0
    local items_per_line=4 # 每行显示4个项目
    local max_length=0

    # 计算最长项目名的长度，用于对齐
    for file in "${files[@]}"; do
        local len=${#file}
        if [ "$len" -gt "$max_length" ]; then
            max_length=$len
        fi
    done

    max_length=$((max_length + 4)) # 增加一些间距

    for i in "${!files[@]}"; do
        count=$((count + 1))
        # 使用黄色显示序号，白色显示文件名
        printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$count" "${files[i]#*. }"

        # 每行显示指定数量的项目后换行
        if [ $((count % items_per_line)) -eq 0 ]; then
            echo ""
        fi
    done

    # 如果最后一行不满，确保换行
    if [ $((count % items_per_line)) -ne 0 ]; then
        echo ""
    fi

    echo
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"

    # 显示统计信息
    echo -e "${gl_bufan}统计信息:${gl_bai}"

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash/files"
        if [[ -d "$trash_dir" ]]; then
            local file_count=$(find "$trash_dir" -type f | wc -l)
            local dir_count=$(find "$trash_dir" -type d | wc -l)
            local total_size=$(du -sh "$trash_dir" 2>/dev/null | cut -f1)

            echo -e "  ${gl_bufan}文件数量:${gl_bai} ${gl_huang}$file_count${gl_bai}"
            echo -e "  ${gl_bufan}目录数量:${gl_bai} ${gl_huang}$((dir_count - 1))${gl_bai}"
            echo -e "  ${gl_bufan}总大小:${gl_bai} ${gl_huang}$total_size${gl_bai}"
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        if command -v trash-list &>/dev/null; then
            local file_count=$(trash-list | wc -l)
            echo -e "  ${gl_bufan}文件数量:${gl_bai} ${gl_huang}$file_count${gl_bai}"
        fi
    fi
}
# 启用回收站
enable_trash() {
    echo
    echo -e "${gl_zi}=== 启用回收站 ===${gl_bai}"

    if [[ -n "$TRASH_CMD" ]]; then
        echo -e "${gl_lv}回收站已经启用${gl_bai}"
        echo -e "${gl_lv}当前回收站工具: $TRASH_CMD${gl_bai}"
    else
        if install_trash; then
            echo -e "${gl_lv}回收站启用成功${gl_bai}"
        else
            echo -e "${gl_hong}回收站启用失败${gl_bai}"
        fi
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 关闭回收站
disable_trash() {
    echo
    echo -e "${gl_zi}=== 关闭回收站 ===${gl_bai}"

    if [[ -n "$TRASH_CMD" ]]; then
        unset TRASH_CMD
        echo -e "${gl_lv}回收站已关闭${gl_bai}"
        echo -e "${gl_huang}现在删除文件将直接永久删除，请谨慎操作！${gl_bai}"
    else
        echo -e "${gl_huang}回收站已经是关闭状态${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 清空回收站
empty_trash() {
    echo
    echo -e "${gl_zi}=== 清空回收站 ===${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    fi

    read -r -e -p "$(echo -e "${gl_bai}确认要永久清空回收站中的所有内容? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消清空操作${gl_bai}"
        return
    fi

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        if [[ -d "$trash_dir" ]]; then
            rm -rf "$trash_dir/files/"* 2>/dev/null
            rm -rf "$trash_dir/info/"* 2>/dev/null
            echo -e "${gl_lv}回收站已清空${gl_bai}"
        else
            echo -e "${gl_huang}回收站目录不存在${gl_bai}"
        fi
    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        if command -v trash-empty &>/dev/null; then
            trash-empty
            echo -e "${gl_lv}回收站已清空${gl_bai}"
        else
            echo -e "${gl_hong}trash-empty 命令不可用${gl_bai}"
        fi
    else
        echo -e "${gl_hong}不支持的回收站工具: $TRASH_CMD${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 交互式恢复回收站文件
restore_trash_interactive() {
    echo
    echo -e "${gl_zi}=== 恢复回收站文件 ===${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    fi

    # 获取回收站内容
    local trash_json=$(get_trash_list)
    local item_count=0

    # 计算项目数量
    if command -v jq &>/dev/null; then
        item_count=$(echo "$trash_json" | jq length)
    else
        item_count=$(echo "$trash_json" | grep -o '"index"' | wc -l)
    fi

    if [[ $item_count -eq 0 ]]; then
        echo -e "${gl_huang}回收站为空，没有文件可恢复${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    fi

    # 显示可恢复的文件列表
    echo -e "${gl_bufan}可恢复的文件:${gl_bai}"
    echo -e "${gl_bufan}----------------------------------------${gl_bai}"

    if command -v jq &>/dev/null; then
        echo "$trash_json" | jq -r '.[] | "\(.index). \(.name)"' | while read -r -r line; do
            local index=$(echo "$line" | cut -d. -f1)
            local filename=$(echo "$line" | cut -d. -f2- | sed 's/^ *//')
            echo -e "  ${gl_huang}$index.${gl_bai} $filename"
        done
    else
        local index=1
        if [[ "$TRASH_CMD" == "gio trash" ]]; then
            local trash_dir="$HOME/.local/share/Trash/files"
            for item in "$trash_dir"/*; do
                if [[ -e "$item" ]]; then
                    local filename=$(basename "$item")
                    echo -e "  ${gl_huang}$index.${gl_bai} $filename"
                    ((index++))
                fi
            done
        elif [[ "$TRASH_CMD" == "trash-put" ]] && command -v trash-list &>/dev/null; then
            trash-list | while read -r -r line; do
                if [[ -n "$line" ]]; then
                    local filename=$(echo "$line" | awk '{$1=$2=""; print substr($0,3)}' | sed 's/^ *//' | xargs basename)
                    echo -e "  ${gl_huang}$index.${gl_bai} $filename"
                    ((index++))
                fi
            done
        fi
    fi

    echo -e "${gl_bufan}----------------------------------------${gl_bai}"
    echo -e "${gl_huang}提示：可输入多个序号，用空格分隔；0 或留空取消${gl_bai}"

    # 获取用户输入（支持回退）
    echo -ne "${gl_bufan}请输入要恢复的文件序号: ${gl_bai}"
    read -r -e raw
    [[ -z "$raw" || "$raw" == "0" ]] && return

    # 解析用户输入
    local to_restore=()
    read -r -ra tokens <<<"$raw"

    for tok in "${tokens[@]}"; do
        [[ -z "$tok" ]] && continue

        if [[ $tok =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= item_count)); then
            to_restore+=("$tok")
        else
            echo -e "${gl_hong}跳过无效序号: $tok${gl_bai}"
        fi
    done

    ((${#to_restore[@]} == 0)) && {
        echo -e "${gl_huang}没有选择有效的文件，按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    }

    # 二次确认
    echo
    echo -e "${gl_hong}即将恢复以下 ${#to_restore[@]} 个文件：${gl_bai}"
    for index in "${to_restore[@]}"; do
        if command -v jq &>/dev/null; then
            local filename=$(echo "$trash_json" | jq -r ".[] | select(.index==$index) | .name")
            echo -e "  ${gl_huang}$index. $filename${gl_bai}"
        else
            echo -e "  ${gl_huang}$index. 文件${gl_bai}"
        fi
    done

    read -r -e -p "$(echo -e "${gl_bai}确认恢复这些文件? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || return

    # 执行恢复
    local ok=0 fail=0
    for index in "${to_restore[@]}"; do
        if restore_single_file "$index"; then
            ((ok++))
        else
            ((fail++))
        fi
    done

    echo
    if ((ok > 0)); then
        echo -e "${gl_lv}✓ 成功恢复 $ok 个文件${gl_bai}"
    fi
    if ((fail > 0)); then
        echo -e "${gl_hong}✗ $fail 个文件恢复失败${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 恢复单个文件
restore_single_file() {
    local index="$1"

    if [[ "$TRASH_CMD" == "gio trash" ]]; then
        local trash_dir="$HOME/.local/share/Trash"
        local files_dir="$trash_dir/files"
        local info_dir="$trash_dir/info"

        # 获取文件名
        local filename=""
        local count=1
        for item in "$files_dir"/*; do
            if [[ -e "$item" ]]; then
                if [[ $count -eq $index ]]; then
                    filename=$(basename "$item")
                    break
                fi
                ((count++))
            fi
        done

        if [[ -z "$filename" ]]; then
            echo -e "${gl_hong}无法找到文件: 序号 $index${gl_bai}"
            return 1
        fi

        local file_path="$files_dir/$filename"
        local info_file="$info_dir/${filename}.trashinfo"
        local original_path=""

        if [[ -f "$info_file" ]]; then
            original_path=$(grep "^Path=" "$info_file" | cut -d= -f2-)
        fi

        if [[ -n "$original_path" && -e "$file_path" ]]; then
            # 确保目标目录存在
            local target_dir=$(dirname "$original_path")
            mkdir -p "$target_dir"

            # 移动文件回原位置
            if mv "$file_path" "$original_path" 2>/dev/null; then
                # 删除.trashinfo文件
                rm -f "$info_file"
                echo -e "${gl_lv}✓ 已恢复: $filename${gl_bai}"
                return 0
            else
                echo -e "${gl_hong}✗ 恢复失败: $filename${gl_bai}"
                return 1
            fi
        else
            echo -e "${gl_hong}✗ 文件信息不完整: $filename${gl_bai}"
            return 1
        fi

    elif [[ "$TRASH_CMD" == "trash-put" ]]; then
        if command -v trash-restore &>/dev/null; then
            # 使用trash-restore命令恢复特定文件
            echo -e "${gl_huang}请手动在接下来的界面中选择要恢复的文件...${gl_bai}"
            trash-restore
            return $?
        else
            echo -e "${gl_hong}trash-restore 命令不可用${gl_bai}"
            return 1
        fi
    else
        echo -e "${gl_hong}不支持的回收站工具${gl_bai}"
        return 1
    fi
}

# 刷新回收站状态
refresh_trash() {
    echo
    echo -e "${gl_zi}=== 刷新回收站状态 ===${gl_bai}"

    unset TRASH_CMD
    if install_trash; then
        echo -e "${gl_lv}回收站状态已刷新${gl_bai}"
        echo -e "${gl_lv}当前回收站工具: $TRASH_CMD${gl_bai}"
    else
        echo -e "${gl_hong}回收站功能不可用${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 测试回收站功能
test_trash_function() {
    echo
    echo -e "${gl_zi}=== 测试回收站功能 ===${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    fi

    local test_file=".trash_test_$(date +%s)"
    echo -e "${gl_huang}创建测试文件: $test_file${gl_bai}"
    touch "$test_file"

    if [[ -e "$test_file" ]]; then
        echo -e "${gl_lv}测试文件创建成功${gl_bai}"
        echo -e "${gl_huang}尝试移动到回收站...${gl_bai}"

        if delete_file_with_trash "$test_file"; then
            echo -e "${gl_lv}测试成功：文件已移动到回收站${gl_bai}"
        else
            echo -e "${gl_hong}测试失败：文件未能移动到回收站${gl_bai}"
        fi
    else
        echo -e "${gl_hong}测试文件创建失败${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 配置rm命令重定向到回收站
setup_rm_redirect() {
    echo
    echo -e "${gl_zi}=== 配置 rm 命令重定向到回收站 ===${gl_bai}"

    if [[ -z "$TRASH_CMD" ]]; then
        echo -e "${gl_hong}回收站未启用，请先启用回收站${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
    fi

    echo -e "${gl_huang}此功能将创建一个别名，将 rm 命令重定向到回收站${gl_bai}"
    echo -e "${gl_huang}这样使用 rm 删除的文件也会进入回收站${gl_bai}"
    echo
    echo -e "${gl_hong}警告：这可能会影响系统脚本和其他应用程序的行为${gl_bai}"
    echo -e "${gl_huang}建议仅在交互式shell中使用此功能${gl_bai}"
    echo

    read -r -e -p "$(echo -e "${gl_bai}确认配置 rm 命令重定向? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${gl_huang}已取消配置${gl_bai}"
        return
    fi

    # 检测用户的shell
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        echo -e "${gl_huang}请手动在您的shell配置文件中添加以下别名:${gl_bai}"
        echo "alias rm='$TRASH_CMD'"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
        ;;
    esac

    # 检查是否已经配置
    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_huang}检测到已存在 rm 别名配置${gl_bai}"
        echo -e "${gl_huang}当前配置: $(grep "alias rm=" "$config_file")${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}是否覆盖现有配置? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消配置${gl_bai}"
            return
        fi

        # 删除现有的rm别名
        sed -i '/alias rm=/d' "$config_file"
    fi

    # 添加新的rm别名
    echo "alias rm='$TRASH_CMD'" >>"$config_file"

    if [[ $? -eq 0 ]]; then
        echo -e "${gl_lv}✓ 已成功配置 rm 命令重定向${gl_bai}"
        echo -e "${gl_huang}配置已添加到: $config_file${gl_bai}"
        echo -e "${gl_huang}请重新登录或运行: source $config_file${gl_bai}"
        echo
        echo -e "${gl_lv}现在使用 rm 命令删除的文件将进入回收站${gl_bai}"
    else
        echo -e "${gl_hong}✗ 配置失败${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 移除rm命令重定向
remove_rm_redirect() {
    echo
    echo -e "${gl_zi}=== 移除 rm 命令重定向 ===${gl_bai}"

    # 检测用户的shell
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        echo -e "${gl_huang}请手动从您的shell配置文件中移除 rm 别名${gl_bai}"
        echo
        echo -e "${gl_bufan}按任意键继续...${gl_bai}"
        read -r -n1 -s
        return
        ;;
    esac

    # 检查是否已经配置
    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_huang}检测到 rm 别名配置: $(grep "alias rm=" "$config_file")${gl_bai}"

        read -r -e -p "$(echo -e "${gl_bai}确认移除 rm 命令重定向? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${gl_huang}已取消操作${gl_bai}"
            return
        fi

        # 删除现有的rm别名
        sed -i '/alias rm=/d' "$config_file"

        if [[ $? -eq 0 ]]; then
            echo -e "${gl_lv}✓ 已成功移除 rm 命令重定向${gl_bai}"
            echo -e "${gl_huang}请重新登录或运行: source $config_file${gl_bai}"
            echo
            echo -e "${gl_lv}现在 rm 命令将恢复为系统默认行为${gl_bai}"
        else
            echo -e "${gl_hong}✗ 移除失败${gl_bai}"
        fi
    else
        echo -e "${gl_huang}未找到 rm 命令重定向配置${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 检查rm命令重定向状态
check_rm_redirect() {
    echo
    echo -e "${gl_zi}=== rm 命令重定向状态 ===${gl_bai}"

    # 检测用户的shell
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        echo -e "${gl_hong}不支持的shell: $user_shell${gl_bai}"
        return
        ;;
    esac

    # 检查是否已经配置
    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_lv}✓ rm 命令重定向已启用${gl_bai}"
        echo -e "${gl_huang}当前配置: $(grep "alias rm=" "$config_file")${gl_bai}"
        echo
        echo -e "${gl_lv}使用 rm 命令删除的文件将进入回收站${gl_bai}"
    else
        echo -e "${gl_huang}✗ rm 命令重定向未启用${gl_bai}"
        echo
        echo -e "${gl_huang}使用 rm 命令删除的文件将永久删除${gl_bai}"
        echo -e "${gl_huang}不会进入回收站${gl_bai}"
    fi

    echo
    echo -e "${gl_bufan}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 静默检查rm重定向状态
check_rm_redirect_silent() {
    local user_shell=$(basename "$SHELL")
    local config_file=""

    case "$user_shell" in
    bash)
        config_file="$HOME/.bashrc"
        ;;
    zsh)
        config_file="$HOME/.zshrc"
        ;;
    *)
        return
        ;;
    esac

    if grep -q "alias rm=" "$config_file" 2>/dev/null; then
        echo -e "${gl_lv}rm 重定向: 已启用${gl_bai}"
    else
        echo -e "${gl_huang}rm 重定向: 未启用${gl_bai}"
    fi
}

###### 回收站管理菜单
manage_trash_menu() {

    # 自动初始化回收站（静默）
    install_trash &>/dev/null

    # 确保TRASH_CMD变量存在
    if [[ -z "$TRASH_CMD" ]]; then
        # 尝试初始化回收站
        install_trash >/dev/null 2>&1
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> 回收站管理${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 显示回收站状态
        if [[ -n "$TRASH_CMD" ]]; then
            echo -e "${gl_lv}回收站状态: 已启用 ($TRASH_CMD)${gl_bai}"
        else
            echo -e "${gl_hong}回收站状态: 未启用${gl_bai}"
        fi

        # 显示rm重定向状态
        check_rm_redirect_silent
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 默认显示回收站内容和统计信息
        show_trash_contents_and_stats

        # 显示菜单选项
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai} 关闭回收站"
        echo -e "${gl_bufan}2.  ${gl_bai} 开启回收站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}3.  ${gl_bai} 清空回收站"
        echo -e "${gl_bufan}4.  ${gl_bai} 恢复回收站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}5.  ${gl_bai} 刷新回收站"
        echo -e "${gl_bufan}6.  ${gl_bai} 测试回收站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}7.  ${gl_bai} 配置rm重定向"
        echo -e "${gl_bufan}8.  ${gl_bai} 移除rm重定向"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}00.  ${gl_bai}退出脚本"
        echo -e "${gl_bufan}0.  ${gl_bai} 返回上一级选单"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -e -p "请输入你的选择: " sub_choice
        case $sub_choice in
        1)
            disable_trash
            ;;
        2)
            enable_trash
            ;;
        3)
            empty_trash
            ;;
        4)
            restore_trash_interactive
            ;;
        5)
            refresh_trash
            ;;
        6)
            test_trash_function
            ;;
        7)
            setup_rm_redirect
            ;;
        8)
            remove_rm_redirect
            ;;
        0)
            break
            ;; # 立即终止整个循环，跳出循环体
        00 | 000 | 0000)
            exit_script
            ;; # 感谢使用，再见！ N 秒后自动退出
        *)
            handle_invalid_input
            ;; # 无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

###### 交互式删除函数
interactive_delete() {
    # 尝试初始化回收站
    if [[ -z "$TRASH_CMD" ]]; then
        install_trash
    fi

    while true; do
        clear
        echo -e "${gl_zi}>>> 删除模式${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        # 显示当前使用的删除方式
        if [[ -n "$TRASH_CMD" ]]; then
            echo -e "${gl_lv}使用回收站删除（安全模式）${gl_bai}"
        else
            echo -e "${gl_huang}使用直接删除（请谨慎操作）${gl_bai}"
        fi

        # ---- 生成文件/目录列表 ----
        local list=()
        while IFS= read -r -r -d '' item; do
            list+=("$item")
        done < <(
            find . -maxdepth 1 -type f -printf '%P\0' 2>/dev/null
            find . -maxdepth 1 -type d ! -name '.' -printf '%P\0' 2>/dev/null
        )

        if ((${#list[@]} == 0)); then
            echo -e "${gl_huang}(当前目录无文件或目录)${gl_bai}"
            echo -e "${gl_bufan}按任意键返回主菜单...${gl_bai}"
            read -r -n1 -s
            return
        fi

        # ---- 横向排版显示 ----
        echo -e "${gl_bufan}当前目录下的文件/目录：${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        local count=0 items_per_line=4 max_length=0
        for item in "${list[@]}"; do
            ((${#item} > max_length)) && max_length=${#item}
        done
        max_length=$((max_length + 4))
        for i in "${!list[@]}"; do
            count=$((count + 1))
            printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$((i + 1))" "${list[i]}"
            ((count % items_per_line == 0)) && echo
        done
        ((count % items_per_line)) && echo
        echo -e "${gl_bufan}------------------------${gl_bai}"

        if [[ -n "$TRASH_CMD" ]]; then
            echo -e "${gl_lv}安全模式：文件将移动到回收站，可恢复${gl_bai}"
        else
            echo -e "${gl_hong}警告：删除操作不可恢复，请谨慎操作！${gl_bai}"
        fi
        echo -e "${gl_huang}提示：多个序号或文件名，用空格分隔；0 或留空返回主菜单${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        local raw
        read -r -e -p "请输入（多选用空格分隔）: " -e raw
        [[ -z $raw || $raw == "0" ]] && return

        # ---- 解析用户输入 ----
        local to_del=() tok idx
        # 使用数组来存储输入，正确处理带空格的参数
        read -r -ra tokens <<<"$raw"

        for tok in "${tokens[@]}"; do
            # 跳过空令牌
            [[ -z "$tok" ]] && continue

            if [[ $tok =~ ^[0-9]+$ ]] && ((tok >= 1 && tok <= ${#list[@]})); then
                local selected_item="${list[$((tok - 1))]}"
                # 检查项目是否仍然存在
                if [[ -e "$selected_item" ]]; then
                    to_del+=("$selected_item")
                else
                    echo -e "${gl_hong}文件不存在，跳过: $selected_item${gl_bai}"
                fi
            elif [[ -e "$tok" ]]; then
                to_del+=("$tok")
            else
                echo -e "${gl_hong}跳过无效输入或文件不存在: $tok${gl_bai}"
            fi
        done

        ((${#to_del[@]} == 0)) && {
            echo -e "${gl_huang}没有有效的文件可删除，按任意键继续...${gl_bai}"
            read -r -n1 -s
            return
        }

        # ---- 二次确认 ----
        echo
        echo -e "${gl_hong}即将删除以下 ${#to_del[@]} 项：${gl_bai}"
        for item in "${to_del[@]}"; do
            echo -e "  ${gl_huang}$item${gl_bai}"
        done
        echo

        if [[ -n "$TRASH_CMD" ]]; then
            read -r -e -p "$(echo -e "${gl_bai}确认移动到回收站? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        else
            read -r -e -p "$(echo -e "${gl_bai}确认永久删除? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" -n1 -r
        fi
        echo
        [[ $REPLY =~ ^[Yy]$ ]] || continue

        # ---- 执行删除 ----
        local ok=0 fail=0
        for item in "${to_del[@]}"; do
            if [[ -n "$TRASH_CMD" ]]; then
                if delete_file_with_trash "$item"; then
                    ((ok++))
                else
                    ((fail++))
                fi
            else
                # 如果没有回收站，使用原来的删除逻辑
                if delete_file_with_trash "$item"; then
                    ((ok++))
                else
                    ((fail++))
                fi
            fi
        done

        echo
        if [[ -n "$TRASH_CMD" ]]; then
            if ((ok > 0)); then
                echo -e "${gl_lv}✓ 成功移动 $ok 项到回收站${gl_bai}"
            fi
            if ((fail > 0)); then
                echo -e "${gl_hong}✗ $fail 项移动失败${gl_bai}"
            fi
        else
            if ((ok > 0)); then
                echo -e "${gl_lv}✓ 成功删除 $ok 项${gl_bai}"
            fi
            if ((fail > 0)); then
                echo -e "${gl_hong}✗ $fail 项删除失败${gl_bai}"
            fi
        fi

        echo -e "${gl_bufan}按任意键刷新目录...${gl_bai}"
        read -r -n1 -s
    done
}

######## 交互式压缩 - 横向排列
interactive_compress() {
    clear
    echo -e "${gl_zi}>>> 压缩模式${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
    local list=() item i choice target fmt_idx format

    # 使用更简单的方法获取文件和目录列表
    for item in *; do
        # 排除隐藏文件、目录和压缩文件
        if [[ "$item" != .* && -e "$item" ]]; then
            # 排除常见的压缩格式
            if [[ ! "$item" =~ \.(zip|7z|tar|tar\.gz|tar\.bz2|tar\.xz|tgz|tbz2|txz|rar|gz|bz2|xz)$ ]]; then
                list+=("$item")
            fi
        fi
    done

    # 添加子目录（非隐藏）
    for item in */; do
        if [[ -d "$item" && "$item" != .*/ && "$item" != "./" ]]; then
            # 去掉末尾的斜杠
            item="${item%/}"
            list+=("$item")
        fi
    done

    # 按字母顺序排序
    IFS=$'\n' list=($(sort <<<"${list[*]}"))
    unset IFS

    if ((${#list[@]} == 0)); then
        echo -e "${gl_huang}(当前目录无可压缩的文件/目录)${gl_bai}"
        echo -e "${gl_bufan}按任意键返回...${gl_bai}"
        read -r -n1 -s
        return
    else
        echo -e "${gl_bufan}当前目录下的文件/目录：${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 横向排列显示
        local count=0
        local items_per_line=4 # 每行显示4个项目
        local max_length=0

        # 计算最长项目名的长度，用于对齐
        for item in "${list[@]}"; do
            local len=${#item}
            if [ "$len" -gt "$max_length" ]; then
                max_length=$len
            fi
        done

        max_length=$((max_length + 4)) # 增加一些间距

        for i in "${!list[@]}"; do
            count=$((count + 1))
            # 使用黄色显示序号，白色显示项目名
            printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$count" "${list[i]}"

            # 每行显示指定数量的项目后换行
            if [ $((count % items_per_line)) -eq 0 ]; then
                echo ""
            fi
        done

        # 如果最后一行不满，确保换行
        if [ $((count % items_per_line)) -ne 0 ]; then
            echo ""
        fi
        echo -e "${gl_bufan}------------------------${gl_bai}"
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入文件名/目录名 (${gl_huang}留空取消${gl_bai}): ")" choice

    [[ -z "$choice" ]] && {
        echo -e "${gl_huang}已取消${gl_bai}"
        return
    }

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        target="${list[$((choice - 1))]}"
    else
        target="$choice"
    fi

    [[ -e "$target" ]] || {
        echo -e "${gl_hong}错误：'$target' 不存在！${gl_bai}"
        return
    }

    echo -e "${gl_huang}请选择压缩格式：${gl_bai}"
    # 横向排列显示格式选项
    echo -e "${gl_huang}1.${gl_bai} zip        ${gl_huang}2.${gl_bai} 7z         ${gl_huang}3.${gl_bai} tar.gz"
    echo -e "${gl_huang}4.${gl_bai} tar.xz     ${gl_huang}5.${gl_bai} tar.bz2    ${gl_huang}6.${gl_bai} tar"
    safe_read "输入序号 [1-6]: " fmt_idx "number"

    case "$fmt_idx" in
    1) format="zip" ;;
    2) format="7z" ;;
    3) format="tar.gz" ;;
    4) format="tar.xz" ;;
    5) format="tar.bz2" ;;
    6) format="tar" ;;
    *)
        echo -e "${gl_hong}无效序号！${gl_bai}"
        return
        ;;
    esac

    # 调用独立的压缩函数
    compress_file "$target" "$format" "."
}

###### 解压文件 - 独立函数
extract_file() {
    local archive="$1" output_dir="${2:-.}" auto_yes="${3:-false}"

    [[ -f "$archive" ]] || {
        echo -e "${gl_hong}错误：'$archive' 不存在！${gl_bai}"
        return 1
    }

    [[ -d "$output_dir" ]] || {
        echo -e "${gl_huang}创建目录：$output_dir${gl_bai}"
        mkdir -p "$output_dir"
    }

    local cmd=() confirm
    case "$archive" in
    *.zip)
        if [[ "$auto_yes" == "true" ]]; then
            cmd=("unzip" "-o" "-q") # 自动覆盖所有文件
        else
            cmd=("unzip" "-q") # 交互式处理重复文件
        fi
        command -v unzip &>/dev/null || {
            echo -e "${gl_hong}错误：unzip 命令未安装！${gl_bai}"
            return 1
        }
        ;;
    *.7z)
        cmd=("7z" "x" "-y")
        command -v 7z &>/dev/null || {
            echo -e "${gl_hong}错误：7z 命令未安装！${gl_bai}"
            return 1
        }
        ;;
    *.tar) cmd=("tar" "-xf") ;;
    *.tar.gz | *.tgz) cmd=("tar" "-zxf") ;;
    *.tar.bz2 | *.tbz2) cmd=("tar" "-jxf") ;;
    *.tar.xz | *.txz) cmd=("tar" "-Jxf") ;;
    *.rar)
        if command -v unrar &>/dev/null; then
            cmd=("unrar" "x" "-inul")
        elif command -v rar &>/dev/null; then
            cmd=("rar" "x" "-inul")
        else
            echo -e "${gl_hong}错误：unrar 或 rar 命令未安装！${gl_bai}"
            return 1
        fi
        ;;
    *.gz)
        [[ "$auto_yes" != "true" ]] && {
            # safe_read "解压.gz文件将覆盖原文件，是否继续？[y/N]: " confirm "any"
            safe_read "$(echo -e "${gl_bai}解压.gz文件将覆盖原文件，是否继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm "any"
            [[ $confirm =~ ^[Yy]$ ]] || {
                echo -e "${gl_huang}已取消${gl_bai}"
                return 0
            }
        }
        cmd=("gzip" "-d")
        ;;
    *.bz2)
        [[ "$auto_yes" != "true" ]] && {
            # safe_read "解压.bz2文件将覆盖原文件，是否继续？[y/N]: " confirm "any"
            safe_read "$(echo -e "${gl_bai}解压.bz2文件将覆盖原文件，是否继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm "any"
            [[ $confirm =~ ^[Yy]$ ]] || {
                echo -e "${gl_huang}已取消${gl_bai}"
                return 0
            }
        }
        cmd=("bzip2" "-d")
        ;;
    *.xz)
        [[ "$auto_yes" != "true" ]] && {
            # safe_read "解压.xz文件将覆盖原文件，是否继续？[y/N]: " confirm "any"
            safe_read "$(echo -e "${gl_bai}解压.xz文件将覆盖原文件，是否继续？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm "any"
            [[ $confirm =~ ^[Yy]$ ]] || {
                echo -e "${gl_huang}已取消${gl_bai}"
                return 0
            }
        }
        cmd=("xz" "-d")
        ;;
    *)
        echo -e "${gl_hong}不支持的压缩格式：$archive${gl_bai}"
        return 1
        ;;
    esac

    echo -e "${gl_lv}正在解压：$archive → $output_dir${gl_bai}"

    # 处理解压过程中的重复文件
    if [[ "$archive" == *.zip && "$auto_yes" != "true" ]]; then
        echo -e "${gl_huang}如果遇到重复文件，请选择操作：${gl_bai}"
        echo -e "${gl_huang}[y] 覆盖当前文件${gl_bai}"
        echo -e "${gl_huang}[n] 跳过当前文件${gl_bai}"
        echo -e "${gl_huang}[A] 覆盖所有重复文件${gl_bai}"
        echo -e "${gl_huang}[N] 跳过所有重复文件${gl_bai}"
        echo -e "${gl_huang}[r] 重命名当前文件${gl_bai}"
    fi

    local result=0
    case "$archive" in
    *.zip)
        "${cmd[@]}" "$archive" -d "$output_dir"
        result=$?
        ;;
    *.7z)
        "${cmd[@]}" "$archive" "-o$output_dir"
        result=$?
        ;;
    *.tar | *.tar.gz | *.tar.bz2 | *.tar.xz | *.tgz | *.tbz2 | *.txz)
        "${cmd[@]}" "$archive" -C "$output_dir"
        result=$?
        ;;
    *.rar)
        "${cmd[@]}" "$archive" "$output_dir/"
        result=$?
        ;;
    *.gz | *.bz2 | *.xz)
        "${cmd[@]}" "$archive"
        result=$?
        ;;
    esac

    if [[ $result -eq 0 ]]; then
        echo -e "${gl_lv}解压完成！${gl_bai}"
        return 0
    else
        echo -e "${gl_hong}解压失败！${gl_bai}"
        return 1
    fi
}

###### 交互式压缩
interactive_compress() {
    clear
    echo -e "${gl_zi}>>> 压缩模式${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
    local list=() item i choice target fmt_idx format

    # 使用更简单的方法获取文件和目录列表
    for item in *; do
        # 排除隐藏文件、目录和压缩文件
        if [[ "$item" != .* && -e "$item" ]]; then
            # 排除常见的压缩格式
            if [[ ! "$item" =~ \.(zip|7z|tar|tar\.gz|tar\.bz2|tar\.xz|tgz|tbz2|txz|rar|gz|bz2|xz)$ ]]; then
                list+=("$item")
            fi
        fi
    done

    # 添加子目录（非隐藏）
    for item in */; do
        if [[ -d "$item" && "$item" != .*/ && "$item" != "./" ]]; then
            # 去掉末尾的斜杠
            item="${item%/}"
            list+=("$item")
        fi
    done

    # 按字母顺序排序
    IFS=$'\n' list=($(sort <<<"${list[*]}"))
    unset IFS

    if ((${#list[@]} == 0)); then
        echo -e "${gl_huang}(当前目录无可压缩的文件/目录)${gl_bai}"
        echo -e "${gl_bufan}按任意键返回...${gl_bai}"
        read -r -n1 -s
        return
    else
        echo -e "${gl_bufan}当前目录下的文件/目录：${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 横向排列显示
        local count=0
        local items_per_line=4 # 每行显示4个项目
        local max_length=0

        # 计算最长项目名的长度，用于对齐
        for item in "${list[@]}"; do
            local len=${#item}
            if [ "$len" -gt "$max_length" ]; then
                max_length=$len
            fi
        done

        max_length=$((max_length + 4)) # 增加一些间距

        for i in "${!list[@]}"; do
            count=$((count + 1))
            # 使用黄色显示序号，白色显示项目名
            printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$count" "${list[i]}"

            # 每行显示指定数量的项目后换行
            if [ $((count % items_per_line)) -eq 0 ]; then
                echo ""
            fi
        done

        # 如果最后一行不满，确保换行
        if [ $((count % items_per_line)) -ne 0 ]; then
            echo ""
        fi
        echo -e "${gl_bufan}------------------------${gl_bai}"
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入文件名/目录名 (${gl_huang}留空取消${gl_bai}): ")" choice

    [[ -z "$choice" ]] && {
        echo -e "${gl_huang}已取消${gl_bai}"
        return
    }

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        target="${list[$((choice - 1))]}"
    else
        target="$choice"
    fi

    [[ -e "$target" ]] || {
        echo -e "${gl_hong}错误：'$target' 不存在！${gl_bai}"
        return
    }

    echo -e "${gl_huang}请选择压缩格式：${gl_bai}"
    # 横向排列显示格式选项
    echo -e "${gl_huang}1.${gl_bai} zip        ${gl_huang}2.${gl_bai} 7z         ${gl_huang}3.${gl_bai} tar.gz"
    echo -e "${gl_huang}4.${gl_bai} tar.xz     ${gl_huang}5.${gl_bai} tar.bz2    ${gl_huang}6.${gl_bai} tar"
    safe_read "输入序号 [1-6]: " fmt_idx "number"

    case "$fmt_idx" in
    1) format="zip" ;;
    2) format="7z" ;;
    3) format="tar.gz" ;;
    4) format="tar.xz" ;;
    5) format="tar.bz2" ;;
    6) format="tar" ;;
    *)
        echo -e "${gl_hong}无效序号！${gl_bai}"
        return
        ;;
    esac

    # 调用独立的压缩函数
    compress_file "$target" "$format" "."
}

###### 交互式解压
interactive_extract() {
    clear
    echo -e "${gl_zi}>>> 解压模式${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
    local list=() file i choice archive dest

    # 修复：使用更安全的方法获取压缩包文件
    local extensions=("zip" "7z" "tar" "tar.gz" "tar.bz2" "tar.xz" "tgz" "tbz2" "txz" "rar" "gz" "bz2" "xz")
    for ext in "${extensions[@]}"; do
        for file in *."$ext"; do
            if [[ -f "$file" ]]; then
                list+=("$file")
            fi
        done
    done

    # 如果没有压缩包文件，显示提示并等待用户操作
    if ((${#list[@]} == 0)); then
        echo -e "${gl_huang}当前目录无压缩包文件${gl_bai}"
        echo -e "${gl_huang}------------------------${gl_bai}"
        echo -e "${gl_bufan}按任意键返回...${gl_bai}"
        read -r -n1 -s
        return
    else
        echo -e "${gl_bufan}当前目录下的压缩包：${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 横向排列显示
        local count=0
        local items_per_line=4 # 每行显示4个项目
        local max_length=0

        # 计算最长文件名的长度，用于对齐
        for file in "${list[@]}"; do
            local len=${#file}
            if [ "$len" -gt "$max_length" ]; then
                max_length=$len
            fi
        done

        max_length=$((max_length + 4)) # 增加一些间距

        for i in "${!list[@]}"; do
            count=$((count + 1))
            # 使用黄色显示序号，白色显示文件名
            printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$count" "${list[i]}"

            # 每行显示指定数量的项目后换行
            if [ $((count % items_per_line)) -eq 0 ]; then
                echo ""
            fi
        done

        # 如果最后一行不满，确保换行
        if [ $((count % items_per_line)) -ne 0 ]; then
            echo ""
        fi
        echo -e "${gl_bufan}------------------------${gl_bai}"
    fi

    read -r -e -p "$(echo -e "${gl_bai}请输入序号选择，或手动输入文件名/目录名 (${gl_huang}留空取消${gl_bai}): ")" choice

    [[ -z "$choice" ]] && {
        echo -e "${gl_huang}已取消${gl_bai}"
        return
    }

    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
        archive="${list[$((choice - 1))]}"
    else
        archive="$choice"
    fi

    [[ -f "$archive" ]] || {
        echo -e "${gl_hong}错误：'$archive' 不存在！${gl_bai}"
        return
    }

    read -r -e -p "$(echo -e "${gl_bufan}请输入解压目标目录（${gl_huang}留空则当前目录${gl_bai}): ")" choice
    dest=${dest:-.}

    extract_file "$archive" "$dest" "false"
}

# 快速解压当前目录下的压缩文件
quick_extract() {
    echo -e "${gl_zi}>>> 快速解压模式${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"

    # 显示当前目录下的所有压缩文件
    local list=() file i choice archive dest

    # 获取压缩包文件
    local extensions=("zip" "7z" "tar" "tar.gz" "tar.bz2" "tar.xz" "tgz" "tbz2" "txz" "rar" "gz" "bz2" "xz")
    for ext in "${extensions[@]}"; do
        for file in *."$ext"; do
            if [[ -f "$file" ]]; then
                list+=("$file")
            fi
        done
    done

    if ((${#list[@]} == 0)); then
        echo -e "${gl_huang}当前目录无压缩包文件${gl_bai}"
        echo -e "${gl_bufan}按任意键返回...${gl_bai}"
        read -r -n1 -s
        return
    fi

    # 如果有多个压缩文件，让用户选择
    if ((${#list[@]} > 1)); then
        echo -e "${gl_bufan}发现多个压缩文件：${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"

        # 横向排列显示
        local count=0
        local items_per_line=4
        local max_length=0

        for file in "${list[@]}"; do
            local len=${#file}
            if [ "$len" -gt "$max_length" ]; then
                max_length=$len
            fi
        done

        max_length=$((max_length + 4))

        for i in "${!list[@]}"; do
            count=$((count + 1))
            printf "${gl_huang}%2d.${gl_bai} %-${max_length}s" "$count" "${list[i]}"
            if [ $((count % items_per_line)) -eq 0 ]; then
                echo ""
            fi
        done

        if [ $((count % items_per_line)) -ne 0 ]; then
            echo ""
        fi
        echo -e "${gl_bufan}------------------------${gl_bai}"

        read -r -e -p "请选择要解压的文件序号（留空取消）: " choice
        [[ -z "$choice" ]] && {
            echo -e "${gl_huang}已取消${gl_bai}"
            return
        }

        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#list[@]})); then
            archive="${list[$((choice - 1))]}"
        else
            echo -e "${gl_hong}无效序号！${gl_bai}"
            return
        fi
    else
        # 如果只有一个压缩文件，直接使用
        archive="${list[0]}"
        echo -e "${gl_lv}发现压缩文件: $archive${gl_bai}"
        echo -e "${gl_huang}将自动解压此文件${gl_bai}"
    fi

    [[ -f "$archive" ]] || {
        echo -e "${gl_hong}错误：'$archive' 不存在！${gl_bai}"
        return
    }

    # 询问解压目录
    read -r -e -p "请输入解压目标目录（留空则当前目录）: " dest
    dest=${dest:-.}

    # 调用解压函数
    extract_file "$archive" "$dest" "false"

    echo -e "${gl_bai}按任意键继续...${gl_bai}"
    read -r -n1 -s
}

# 解压指定文件
extract_specific() {
    local archive="$1"
    local dest="${2:-.}"

    if [[ -z "$archive" ]]; then
        echo -e "${gl_hong}错误：请指定要解压的文件${gl_bai}"
        return 1
    fi

    [[ -f "$archive" ]] || {
        echo -e "${gl_hong}错误：'$archive' 不存在！${gl_bai}"
        return 1
    }

    echo -e "${gl_lv}正在解压: $archive → $dest${gl_bai}"
    extract_file "$archive" "$dest" "false"
}

###### 函数_解压压缩工具
compress_tool() {
    # 使用主脚本定义的颜色变量

    # 变量定义
    local install_only=false compress_file="" extract_file="" compress_format=""
    local output_dir="" auto_yes=false system_type=""

    # 设置 Tab 补全
    setup_completion() {
        local current_word="${COMP_WORDS[COMP_CWORD]}"
        local previous_word="${COMP_WORDS[COMP_CWORD - 1]}"

        case "${previous_word}" in
        --compress | --extract)
            # 文件和目录补全
            COMPREPLY=($(compgen -f -- "${current_word}"))
            ;;
        --format)
            # 压缩格式补全
            local formats=("zip" "7z" "tar.gz" "tar.xz" "tar.bz2" "tar")
            COMPREPLY=($(compgen -W "${formats[*]}" -- "${current_word}"))
            ;;
        --output)
            # 目录补全
            COMPREPLY=($(compgen -d -- "${current_word}"))
            ;;
        *)
            # 选项补全
            local options=("--install-only" "--compress" "--extract" "--format" "--output" "--auto-yes" "-h" "--help")
            COMPREPLY=($(compgen -W "${options[*]}" -- "${current_word}"))
            ;;
        esac
    }

    # 注册补全函数（仅在直接调用时）
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        complete -F setup_completion compress_tool
    fi

    # 显示帮助
    _show_help() {
        cat <<EOF
Linux 压缩解压工具

用法:
  compress_tool [选项]

选项:
  --install-only     仅安装必要软件，不启动菜单
  --compress FILE    压缩指定文件/目录
  --extract FILE     解压指定文件  
  --format FORMAT    指定压缩格式 (zip, 7z, tar.gz, tar.xz, tar.bz2, tar)
  --output DIR       指定输出目录
  --auto-yes         自动确认所有提示
  -h, --help         显示此帮助信息

示例:
  compress_tool --install-only
  compress_tool --compress /path/to/file --format zip
  compress_tool --extract archive.zip --output /tmp
  compress_tool --extract file.tar.gz --auto-yes
  compress_tool  # 进入交互模式

支持的压缩格式:
  zip, 7z, tar, tar.gz, tar.bz2, tar.xz, rar, gz, bz2, xz

交互模式特性:
  - Tab 键补全文件和目录名
  - 支持使用方向键回退和编辑
  - 输入验证和错误提示
  - 文件/目录删除功能
EOF
    }

    # 检测系统类型
    _detect_system() {
        if [[ -f /etc/os-release ]]; then
            source /etc/os-release
            echo "$ID"
        elif command -v lsb_release &>/dev/null; then
            lsb_release -si | tr '[:upper:]' '[:lower:]'
        else
            echo "unknown"
        fi
    }

    # 安装必要软件
    _install_software() {
        local system="$1"
        local packages=()

        # 检测缺失的命令
        if ! command -v zip &>/dev/null || ! command -v unzip &>/dev/null; then
            packages+=("zip" "unzip")
        fi

        if ! command -v 7z &>/dev/null; then
            packages+=("p7zip-full")
        fi

        if ! command -v rar &>/dev/null && ! command -v unrar &>/dev/null; then
            packages+=("unrar")
        fi

        if ! command -v xz &>/dev/null; then
            packages+=("xz-utils")
        fi

        if ! command -v bzip2 &>/dev/null; then
            packages+=("bzip2")
        fi

        if ! command -v gzip &>/dev/null; then
            packages+=("gzip")
        fi

        if [[ ${#packages[@]} -eq 0 ]]; then
            echo -e "${gl_lv}所有必要软件已安装！${gl_bai}"
            return 0
        fi

        echo -e "${gl_huang}需要安装以下软件：${gl_bai}"
        printf "  ${gl_lv}•${gl_bai} %s\n" "${packages[@]}"

        # 非root用户提示
        if [[ $EUID -ne 0 ]]; then
            echo -e "${gl_huang}提示：非root用户，跳过自动安装软件${gl_bai}"
            echo -e "${gl_huang}如果遇到命令未找到错误，请以root权限运行${gl_bai}"
            return 1
        fi

        case "$system" in
        ubuntu | debian | linuxmint | kali)
            echo -e "${gl_huang}使用 apt 安装...${gl_bai}"
            apt update && apt install -y "${packages[@]}" || return 1
            ;;
        centos | rhel | fedora | rocky | almalinux)
            echo -e "${gl_huang}使用 yum/dnf 安装...${gl_bai}"
            if command -v dnf &>/dev/null; then
                dnf install -y "${packages[@]}" || return 1
            else
                yum install -y "${packages[@]}" || return 1
            fi
            ;;
        arch | manjaro)
            echo -e "${gl_huang}使用 pacman 安装...${gl_bai}"
            pacman -Sy --noconfirm "${packages[@]}" || return 1
            ;;
        opensuse*)
            echo -e "${gl_huang}使用 zypper 安装...${gl_bai}"
            zypper install -y "${packages[@]}" || return 1
            ;;
        *)
            echo -e "${gl_hong}无法自动安装软件，请手动安装：${gl_bai}"
            printf "  ${gl_huang}•${gl_bai} %s\n" "${packages[@]}"
            return 1
            ;;
        esac

        echo -e "${gl_lv}软件安装成功！${gl_bai}"
        return 0
    }

    # 交互式菜单
    interactive_menu() {
        while true; do
            clear
            echo -e ""
            echo -e "${gl_zi}>>> Linux压缩/解压工具${gl_bai}"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            ls --color=auto -x
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}1. ${gl_bai} 压缩文件/目录"
            echo -e "${gl_bufan}2. ${gl_bai} 解压文件"
            echo -e "${gl_bufan}3. ${gl_bai} 删除文件/目录"
            echo -e "${gl_bufan}4. ${gl_bai} 文件回收站"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            echo -e "${gl_bufan}00. ${gl_bai}退出脚本"
            echo -e "${gl_bufan}0. ${gl_bai} 返回上一级选单"
            echo -e "${gl_bufan}------------------------${gl_bai}"
            read -r -e -p "请输入你的选择: " choice
            case $choice in
            1) interactive_compress ;;
            2) interactive_extract ;;
            3) interactive_delete ;;
            4) manage_trash_menu ;;
            00 | 000 | 0000)
                clear
                exit
                ;;
            0)
                echo -e "${gl_huang}感谢使用，再见！${gl_bai}"
                return 0
                ;;
            *) echo -e "${gl_hong}无效选择，请重试！${gl_bai}" ;;
            esac
        done
    }

    # 参数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
        --install-only)
            install_only=true
            shift
            ;;
        --compress)
            compress_file="$2"
            shift 2
            ;;
        --extract)
            extract_file="$2"
            shift 2
            ;;
        --format)
            compress_format="$2"
            shift 2
            ;;
        --output)
            output_dir="$2"
            shift 2
            ;;
        --auto-yes)
            auto_yes=true
            shift
            ;;
        -h | --help)
            _show_help
            return 0
            ;;
        *)
            echo -e "${gl_hong}未知参数: $1${gl_bai}"
            _show_help
            return 1
            ;;
        esac
    done

    # 检测系统并安装软件
    echo -e "${gl_lan}检测系统环境...${gl_bai}"
    system_type=$(_detect_system)
    echo -e "${gl_lv}检测到系统类型：$system_type${gl_bai}"

    if ! _install_software "$system_type"; then
        echo -e "${gl_hong}软件安装失败，无法继续${gl_bai}"
        return 1
    fi

    # 如果指定了仅安装，则退出
    if [[ "$install_only" == true ]]; then
        echo -e "${gl_lv}软件安装完成${gl_bai}"
        return 0
    fi

    # 非交互模式：压缩
    if [[ -n "$compress_file" ]]; then
        compress_file "$compress_file" "$compress_format" "$output_dir"
        return $?
    fi

    # 非交互模式：解压
    if [[ -n "$extract_file" ]]; then
        extract_file "$extract_file" "$output_dir" "$auto_yes"
        return $?
    fi

    # 交互模式：显示菜单
    interactive_menu
}

######## 函数_打包Docker镜像
docker_image_pack() {
    set -euo pipefail # 严格错误处理

    # 1. 列出镜像
    echo -e "${gl_huang}本地镜像列表：${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"
    docker images --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}"

    # ---------- 2. 获取镜像 ----------
    while true; do
        echo -e "${gl_bufan}------------------------${gl_bai}"
        read -r -erp "$(echo -e "${gl_bai}请输入打包的镜像名称和版本（格式 ${gl_huang}nginx:tag${gl_bai}，输入 ${gl_huang}0${gl_bai} 返回上级菜单）：") " IMG
        [ "$IMG" = "0" ] && {
            set +euo pipefail
            return 0
        } # 直接返回
        [ -z "$IMG" ] && {
            echo -e "${gl_hong}输入不能为空！${gl_bai}"
            return
        }
        docker image inspect "$IMG" &>/dev/null && break || echo -e "${gl_hong}镜像 '$IMG' 不存在！${gl_bai}"
    done

    # ---------- 3. 获取打包格式 ----------
    while true; do
        read -r -erp "$(echo -e "${gl_bufan}选择打包格式 ${gl_huang}1${gl_bai} .tar  ${gl_huang}2${gl_bai} .tar.gz（输入 ${gl_huang}1${gl_bai} 或 ${gl_huang}2${gl_bai}，输入 ${gl_huang}0${gl_bai} 返回）：") " FMT
        [ "$FMT" = "0" ] && {
            set +euo pipefail
            return 0
        }
        case "$FMT" in 1)
            EXT="tar"
            break
            ;;
        2)
            EXT="tar.gz"
            break
            ;;
        *) echo -e "${gl_hong}输入错误！${gl_bai}" ;; esac
    done

    # ---------- 4. 获取文件名 ----------
    while true; do
        read -r -erp "$(echo -e "${gl_bufan}请输入打包文件名（${gl_huang}不含扩展名${gl_bai}，输入 ${gl_huang}0${gl_bai} 返回）：") " FNAME
        [ "$FNAME" = "0" ] && {
            set +euo pipefail
            return 0
        }
        [ -z "$FNAME" ] && {
            echo -e "${gl_hong}文件名不能为空！${gl_bai}"
            return
        }
        [[ "$FNAME" =~ [^a-zA-Z0-9._-] ]] && {
            echo -e "${gl_hong}文件名含非法字符！${gl_bai}"
            return
        }
        [ -f "${FNAME}.${EXT}" ] && {
            read -r -erp "$(echo -e "${gl_huang}文件已存在，是否覆盖？(${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" OVER
            [[ "$OVER" =~ [yY] ]] && break || continue
        } || break
    done

    OUT="${FNAME}.${EXT}"

    # 5. 打包
    echo -e "${gl_huang}正在打包 → ${OUT}${gl_bai}"
    if [[ "$EXT" == "tar.gz" ]]; then
        docker save "$IMG" | gzip -c >"$OUT"
    else
        docker save -o "$OUT" "$IMG"
    fi

    FILE_PATH=$(realpath "$OUT")
    FILE_SIZE=$(du -h "$OUT" | cut -f1)

    # 6. 静默校验
    echo -e "${gl_huang}正在静默校验 …${gl_bai}"
    if [[ "$EXT" == "tar.gz" ]]; then
        if gzip -t "$OUT" && gunzip -kc "$OUT" | docker load | grep -q "Loaded image:"; then
            LOADED=$(gunzip -kc "$OUT" | docker load | awk '/Loaded image:/ {print $3}')
            echo -e "${gl_lv}校验通过：${OUT} 完整无损${gl_bai}"
            echo -e "${gl_lv}检验后镜像名称与版本：${LOADED}${gl_bai}"
        else
            echo -e "${gl_hong}校验失败：${OUT} 文件损坏${gl_bai}"
            set +euo pipefail
            return 1
        fi
    else
        if docker load -i "$OUT" | grep -q "Loaded image:"; then
            LOADED=$(docker load -i "$OUT" | awk '/Loaded image:/ {print $3}')
            echo -e "${gl_lv}校验通过：${OUT} 完整无损${gl_bai}"
            echo -e "${gl_lv}检验后镜像名称与版本：${LOADED}${gl_bai}"
        else
            echo -e "${gl_hong}校验失败：${OUT} 文件损坏${gl_bai}"
            set +euo pipefail
            return 1
        fi
    fi

    # 7. 完成提示
    echo -e "${gl_bufan}------------------------${gl_bai}"
    echo -e "${gl_lv}打包完成！${gl_bai}"
    echo -e "${gl_lv}文件存放位置：${FILE_PATH}${gl_bai}"
    echo -e "${gl_lv}文件大小：${FILE_SIZE}${gl_bai}"
    echo -e "${gl_lv}如需加载镜像，请执行：${gl_bai}"
    echo -e "${gl_lv}docker load -i ${OUT}${gl_bai}"
    echo -e "${gl_bufan}------------------------${gl_bai}"

    set +euo pipefail
}

###### 文件下载
download_file() {
    # ---- 1. 若命令行带参数，直接取第一个当URL ----
    if [[ -n "$1" ]]; then
        url=$1
        echo -e "${gl_huang}命令行检测到URL：${gl_lv}$url${gl_bai}"
        sleep 1
    else
        # ---- 2. 无参数则走原来的交互询问 ----
        while true; do
            clear
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
            echo -e "${gl_lan}当前目录文件列表：${gl_bai}"
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
            ls -lh --color=auto -x # 横向排列
            echo -e "${gl_bufan}------------------------------------------------${gl_bai}"

            read -r -e -p "$(echo -e "${gl_bai}请输入下载链接（输入 ${gl_huang}0${gl_bai} 退出）：")" url
            [[ "$url" == "0" || "$url" == "00" ]] && echo -e "${gl_hui}退出下载功能。${gl_bai}" && return
            [[ -z "$url" ]] && echo -e "${gl_hong}错误：链接不能为空！${gl_bai}" && read -p "按任意键继续..." && continue
            break
        done
    fi

    # ---- 3. 文件名处理 ----
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    filename=$(basename "$url" | sed 's/?.*$//')
    [[ -z "$filename" || "$filename" == "/" ]] && filename="downloaded_file"
    echo -e "${gl_huang}下载文件默认名称为: ${gl_lv}$filename${gl_bai}"
    echo -e "${gl_huang}是否修改文件名？(直接回车使用默认名称): ${gl_bai}"
    read -r new_filename
    [[ -n "$new_filename" ]] && filename="$new_filename"

    # ---- 4. 开始下载 ----
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_zi}开始下载文件...${gl_bai}"
    download_success=false

    if command -v wget &>/dev/null; then
        echo -e "${gl_zi}尝试使用 wget 下载...${gl_bai}"
        wget -O "$filename" "$url" &>/dev/null && download_success=true && echo -e "${gl_lv}✓ wget 下载成功！${gl_bai}" || echo -e "${gl_hong}✗ wget 下载失败${gl_bai}"
    fi

    if [[ "$download_success" == "false" ]] && command -v curl &>/dev/null; then
        echo -e "${gl_zi}尝试使用 curl 下载...${gl_bai}"
        curl -L -o "$filename" "$url" &>/dev/null && download_success=true && echo -e "${gl_lv}✓ curl 下载成功！${gl_bai}" || echo -e "${gl_hong}✗ curl 下载失败${gl_bai}"
    fi

    if [[ "$download_success" == "false" ]]; then
        echo -e "${gl_hong}错误：所有下载工具都失败！请检查链接和网络连接。${gl_bai}"
        read -p "按任意键继续..."
        return
    fi

    # ---- 5. 显示文件信息 ----
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_lan}下载完成！文件信息：${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    if [[ -f "$filename" ]]; then
        file_path=$(realpath "$filename")
        file_size=$(ls -lh "$filename" | awk '{print $5}')
        file_type=$(file -b "$filename")
        mod_time=$(stat -c "%y" "$filename" | cut -d'.' -f1)
        md5=$(md5sum "$filename" | cut -d' ' -f1)
        echo -e "${gl_lv}文件路径: ${gl_bai}$file_path"
        echo -e "${gl_lv}文件大小: ${gl_bai}$file_size"
        echo -e "${gl_lv}文件类型: ${gl_bai}$file_type"
        echo -e "${gl_lv}修改时间: ${gl_bai}$mod_time"
        echo -e "${gl_lv}MD5校验: ${gl_bai}$md5"
    else
        echo -e "${gl_hong}错误：无法找到下载的文件${gl_bai}"
    fi

    # ---- 6. 刷新列表并暂停 ----
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_huang}按任意键返回并刷新文件列表...${gl_bai}"
    read -n1 -s
    clear
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_lan}更新后的目录文件列表：${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    ls -lh --color=auto -x
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_huang}按任意键继续...${gl_bai}"
    read -n1 -s
}

mobufan_sh() {
    while true; do
        clear
        echo -e "${gl_zi}>>> mobufan 脚本工具箱 ${gl_huang}v$sh_v${gl_bai}"
        echo -e "${gl_bufan}命令行输入${gl_huang}m${gl_bufan}快速启动脚本${gl_bai}"
        echo -e "${gl_bufan}命令行输入${gl_huang}m h${gl_bufan}快捷键说明${gl_bai}"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}1.   ${gl_bai}系统信息"
        echo -e "${gl_bufan}2.   ${gl_bai}系统更新"
        echo -e "${gl_bufan}3.   ${gl_bai}系统清理"
        echo -e "${gl_bufan}4.   ${gl_bai}基础工具"
        echo -e "${gl_bufan}5.   ${gl_bai}BBR管理"
        echo -e "${gl_bufan}6.   ${gl_bai}Docker管理"
        echo -e "${gl_bufan}7.   ${gl_bai}应用市场"
        echo -e "${gl_bufan}8.   ${gl_bai}系统工具"
        echo -e "${gl_bufan}9.   ${gl_bai}LDNMP建站"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}10.  ${gl_huang}PVE  ${gl_bai}管理"
        echo -e "${gl_bufan}11.  ${gl_huang}FnOS ${gl_bai}管理"
        echo -e "${gl_bufan}12.  ${gl_huang}Nginx${gl_bai}管理"
        echo -e "${gl_bufan}13.  ${gl_huang}Git  ${gl_bai}管理"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}99.  ${gl_bai}网站防御"
        echo -e "${gl_bufan}00.  ${gl_bai}脚本更新"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        echo -e "${gl_bufan}0.   ${gl_bai}退出脚本"
        echo -e "${gl_bufan}------------------------${gl_bai}"
        mobufan_sh_update
        read -r -e -p "请输入你的选择: " choice

        case $choice in
        1)
            clear
            linux_info
            break_end
            ;;
        2)
             # 系统更新
            clear
            linux_update
            break_end
            ;; 
        3)
            # 系统清理
            clear
            linux_clean
            break_end
            ;; 
        4) linux_tools ;;
        5) linux_bbr ;;
        6) linux_docker ;;
        7) linux_panel ;;
        8) linux_Settings ;;
        9) linux_ldnmp ;;
        10) linux_pve_menu ;;
        11) linux_fnos_menu ;;
        12) linux_nginx_menu ;;
        13) linux_git_menu ;;
        99) web_security ;;
        00) mobufan_update ;;
        666)
            clear
            cd ~
            local sh_v_new
            sh_v_new=$(curl -s https://gitee.com/meimolihan/sh/raw/master/mobufan.sh | grep -o 'sh_v="[0-9.]*"' | cut -d '"' -f 2)
            curl -sS --connect-timeout 10 -O https://gitee.com/meimolihan/sh/raw/master/mobufan.sh || curl -sS --connect-timeout 10 -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            # curl -sS -O https://script.meimolihan.eu.org/sh/tool/mobufan.sh && chmod +x mobufan.sh
            canshu_v6
            CheckFirstRun_true
            yinsiyuanquan2
            cp -f ~/mobufan.sh /usr/local/bin/m >/dev/null 2>&1
            echo -e "${gl_bai}脚本已更新到最新版本！${gl_huang}v$sh_v_new${gl_bai}"
            # 倒计时 3 秒
            # echo -ne "${gl_bai}即将启动新版本脚本，倒计时: ${gl_hong}2${gl_bai} 秒"
            # sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_huang}1${gl_bai} 秒"
            sleep 1
            echo -ne "\r${gl_bai}即将启动新版本脚本，倒计时: ${gl_lv}0${gl_bai} 秒"
            sleep 0.5
            echo -e "\r${gl_bai}正在启动新版本脚本...${gl_bai}"
            bash ~/mobufan.sh
            exit
            ;;
        0) exit_script ;; # 感谢使用，再见！ N 秒后自动退出
        *) handle_invalid_input ;; #无效的输入,请重新输入! 2 秒后返回，继续执行循环的下一次迭代。
        esac
    done
}

m_info() {
    # 统一配色：功能项目用青色(bufan)，命令行输入用黄色(huang)，关键字用绿色(lv)
    echo -e "${gl_zi}>>> 以下是 ${gl_huang}m${gl_zi} 命令参考示例："
    echo -e "${gl_bufan}视频介绍: ${gl_lv}https://www.bilibili.com/video/BV1ib421E7it?t=0.1"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}功能项目${gl_bai}            ${gl_huang}命令行输入${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}启动脚本${gl_bai}            ${gl_huang}m${gl_bai}"
    echo -e "${gl_bufan}说明文档${gl_bai}            ${gl_huang}m h${gl_hong} | ${gl_huang}m 说明${gl_bai}"
    echo -e "${gl_bufan}安装软件${gl_bai}            ${gl_huang}m install ${gl_lv}nano wget ${gl_hong}| ${gl_huang}m add ${gl_lv}nano wget ${gl_hong}| ${gl_huang}m 安装 ${gl_lv}nano wget${gl_bai}"
    echo -e "${gl_bufan}卸载软件${gl_bai}            ${gl_huang}m remove ${gl_lv}nano wget ${gl_hong}| ${gl_huang}m del ${gl_lv}nano wget ${gl_hong}| ${gl_huang}m uninstall ${gl_lv}nano wget ${gl_hong}| ${gl_huang}m 卸载 ${gl_lv}nano wget${gl_bai}"
    echo -e "${gl_bufan}更新系统${gl_bai}            ${gl_huang}m update ${gl_hong}| ${gl_huang}m 更新${gl_bai}"
    echo -e "${gl_bufan}更新脚本${gl_bai}            ${gl_huang}m g ${gl_hong}| ${gl_huang}m up${gl_bai}"
    echo -e "${gl_bufan}网站防御${gl_bai}            ${gl_huang}m f2b ${gl_hong}| ${gl_huang}m 网站防御${gl_bai}"
    echo -e "${gl_bufan}FnOS容器${gl_bai}            ${gl_huang}m fnos ${gl_hong}| ${gl_huang}m 飞牛${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}压缩解压${gl_bai}            ${gl_huang}m zip ${gl_hong}| ${gl_huang}m gz ${gl_hong}| ${gl_huang}m rar${gl_bai}"
    echo -e "${gl_bufan}文件压缩${gl_bai}            ${gl_huang}m ys ${gl_hong}| ${gl_huang}m 压缩${gl_bai}"
    echo -e "${gl_bufan}文件解压${gl_bai}            ${gl_huang}m jy ${gl_hong}| ${gl_huang}m 解压${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}文件管理${gl_bai}            ${gl_huang}m f ${gl_hong}| ${gl_huang}m file ${gl_hong}| ${gl_huang}m 文件管理${gl_bai}"
    echo -e "${gl_bufan}文件删除${gl_bai}            ${gl_huang}m sc ${gl_hong}| ${gl_huang}m 删除 ${gl_hong}| ${gl_huang}m 删除文件${gl_bai}"
    echo -e "${gl_bufan}文件下载${gl_bai}            ${gl_huang}m xz ${gl_lv}<URL> ${gl_hong}| ${gl_huang}m 下载 ${gl_lv}<URL> ${gl_hong}| ${gl_huang}m xz ${gl_lv}<URL>${gl_bai}"
    echo -e "${gl_bufan}文件搜索${gl_bai}            ${gl_huang}m fss ${gl_lv}关键字 ${gl_hong}| ${gl_huang}m 文件搜索 ${gl_lv}关键字${gl_bai}"
    echo -e "${gl_bufan}内容搜索${gl_bai}            ${gl_huang}m ss ${gl_lv}关键字 ${gl_hong}| ${gl_huang}m ssnr ${gl_lv}关键字 ${gl_bai} ${gl_hong}| ${gl_huang}m 搜索 ${gl_lv}关键字${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}修改文件权限${gl_bai}        ${gl_huang}m qx ${gl_hong}| ${gl_huang}m 文件权限${gl_bai}"
    echo -e "${gl_bufan}清理系统垃圾${gl_bai}        ${gl_huang}m clean ${gl_hong}| ${gl_huang}m 清理${gl_bai}"
    echo -e "${gl_bufan}重装系统面板${gl_bai}        ${gl_huang}m dd ${gl_hong}| ${gl_huang}m 重装${gl_bai}"
    echo -e "${gl_bufan}bbr3控制面板${gl_bai}        ${gl_huang}m bbr3 ${gl_hong}| ${gl_huang}m bbrv3${gl_bai}"
    echo -e "${gl_bufan}内核调优面板${gl_bai}        ${gl_huang}m nhyh ${gl_hong}| ${gl_huang}m 内核优化${gl_bai}"
    echo -e "${gl_bufan}设置虚拟内存${gl_bai}        ${gl_huang}m swap 2048${gl_bai}"
    echo -e "${gl_bufan}设置虚拟时区${gl_bai}        ${gl_huang}m time Asia/Shanghai ${gl_hong}| ${gl_huang}m 时区 Asia/Shanghai${gl_bai}"
    echo -e "${gl_bufan}系统回收站${gl_bai}          ${gl_huang}m trash ${gl_hong}| ${gl_huang}m hsz ${gl_hong}| ${gl_huang}m 回收站${gl_bai}"
    echo -e "${gl_bufan}系统备份功能${gl_bai}        ${gl_huang}m backup ${gl_hong}| ${gl_huang}m bf ${gl_hong}| ${gl_huang}m 备份${gl_bai}"
    echo -e "${gl_bufan}SSH远程连接工具${gl_bai}     ${gl_huang}m ssh ${gl_hong}| ${gl_huang}m 远程连接${gl_bai}"
    echo -e "${gl_bufan}rsync远程同步工具${gl_bai}   ${gl_huang}m rsync ${gl_hong}| ${gl_huang}m 远程同步${gl_bai}"
    echo -e "${gl_bufan}硬盘管理工具${gl_bai}        ${gl_huang}m disk ${gl_hong}| ${gl_huang}m 硬盘管理${gl_bai}"
    echo -e "${gl_bufan}内网穿透（服务端）${gl_bai}  ${gl_huang}m frps${gl_bai}"
    echo -e "${gl_bufan}内网穿透（客户端）${gl_bai}  ${gl_huang}m frpc${gl_bai}"
    echo -e "${gl_bufan}软件启动${gl_bai}            ${gl_huang}m start sshd ${gl_hong}| ${gl_huang}m 启动 sshd${gl_bai}"
    echo -e "${gl_bufan}软件停止${gl_bai}            ${gl_huang}m stop sshd ${gl_hong}| ${gl_huang}m 停止 sshd${gl_bai}"
    echo -e "${gl_bufan}软件重启${gl_bai}            ${gl_huang}m restart sshd ${gl_hong}| ${gl_huang}m 重启 sshd${gl_bai}"
    echo -e "${gl_bufan}软件状态查看${gl_bai}        ${gl_huang}m status sshd ${gl_hong}| ${gl_huang}m 状态 sshd${gl_bai}"
    echo -e "${gl_bufan}软件开机启动${gl_bai}        ${gl_huang}m enable docker ${gl_hong}| ${gl_huang}m autostart docker ${gl_hong}| ${gl_huang}m 开机启动 docker${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
    echo -e "${gl_bufan}域名证书申请${gl_bai}        ${gl_huang}m ssl${gl_bai}"
    echo -e "${gl_bufan}域名证书到期查询${gl_bai}    ${gl_huang}m ssl ps${gl_bai}"
    echo -e "${gl_bufan}Docker管理面板${gl_bai}      ${gl_huang}m docker${gl_bai}"
    echo -e "${gl_bufan}Docker环境安装${gl_bai}      ${gl_huang}m docker install ${gl_hong}| ${gl_huang}m docker 安装${gl_bai}"
    echo -e "${gl_bufan}Docker容器管理${gl_bai}      ${gl_huang}m docker ps ${gl_hong}| ${gl_huang}m docker 容器${gl_bai}"
    echo -e "${gl_bufan}Docker镜像管理${gl_bai}      ${gl_huang}m docker img ${gl_hong}| ${gl_huang}m docker 镜像${gl_bai}"
    echo -e "${gl_bufan}LDNMP站点管理${gl_bai}       ${gl_huang}m web${gl_bai}"
    echo -e "${gl_bufan}LDNMP缓存清理${gl_bai}       ${gl_huang}m web cache${gl_bai}"
    echo -e "${gl_bufan}安装WordPress${gl_bai}       ${gl_huang}m wp ${gl_hong}| ${gl_huang}m wordpress ${gl_hong}| ${gl_huang}m wp <域名>${gl_bai}"
    echo -e "${gl_bufan}安装反向代理${gl_bai}        ${gl_huang}m fd ${gl_hong}| ${gl_huang}m rp ${gl_hong}| ${gl_huang}m 反代 ${gl_hong}| ${gl_huang}m fd <域名>${gl_bai}"
    echo -e "${gl_bufan}安装负载均衡${gl_bai}        ${gl_huang}m loadbalance ${gl_hong}| ${gl_huang}m 负载均衡${gl_bai}"
    echo -e "${gl_bufan}安装L4负载均衡${gl_bai}      ${gl_huang}m stream ${gl_hong}| ${gl_huang}m L4负载均衡${gl_bai}"
    echo -e "${gl_bufan}防火墙面板${gl_bai}          ${gl_huang}m fhq ${gl_hong}| ${gl_huang}m 防火墙${gl_bai}"
    echo -e "${gl_bufan}开放端口${gl_bai}            ${gl_huang}m open 8080 ${gl_hong}| ${gl_huang}m 打开端口 8080${gl_bai}"
    echo -e "${gl_bufan}关闭端口${gl_bai}            ${gl_huang}m close 7800 ${gl_hong}| ${gl_huang}m 关闭端口 7800${gl_bai}"
    echo -e "${gl_bufan}放行IP${gl_bai}              ${gl_huang}m allowip 127.0.0.0/8 ${gl_hong}| ${gl_huang}m 放行IP 127.0.0.0/8${gl_bai}"
    echo -e "${gl_bufan}阻止IP${gl_bai}              ${gl_huang}m blockip 177.5.25.36 ${gl_hong}| ${gl_huang}m 阻止IP 177.5.25.36${gl_bai}"
    echo -e "${gl_bufan}命令收藏夹${gl_bai}          ${gl_huang}m fav ${gl_hong}| ${gl_huang}m 命令收藏夹${gl_bai}"
    echo -e "${gl_bufan}应用市场管理${gl_bai}        ${gl_huang}m app${gl_bai}"
    echo -e "${gl_bufan}应用编号快捷管理${gl_bai}    ${gl_huang}m app 26 ${gl_hong}| ${gl_huang}m app 1panel ${gl_hong}| ${gl_huang}m app npm${gl_bai}"
    echo -e "${gl_bufan}显示系统信息${gl_bai}        ${gl_huang}m info${gl_bai}"
    echo -e "${gl_bufan}------------------------------------------------${gl_bai}"
}

if [ "$#" -eq 0 ]; then
    # 如果没有参数，运行交互式逻辑
    mobufan_sh
else
    # 如果有参数，执行相应函数
    case $1 in
    install | add | 安装)
        shift
        install "$@"
        ;;
    u | up)
        echo -e "${gl_bai}正在强制更新 ${gl_bufan}mobufan.sh${gl_bai} 脚本...${gl_bai}"
        bash <(curl -sL gitee.com/meimolihan/script/raw/master/sh/install/mobufan.sh)
        ;;
    f | file | 文件管理)
        shift
        echo -e "${gl_bufan}当前工作目录: ${gl_huang}$(pwd)${gl_bai}"
        linux_file "$@"
        ;;
    h | 说明)
        clear
        m_info
        ;;
    qx | 文件权限)
        # 修改文件权限（非文件夹）
        file_chmod
        ;;
    ss | ssnr | 搜索)
        # 文件内容搜索（非文件夹）
        search_here "${@:2}"
        ;;
    fss | 文件搜索)
        # 文件搜索
        search_file_here "${@:2}"
        ;;
    zip | gz | rar)
        # 文件解压/压缩小工具
        clear
        compress_tool
        ;;
    sc | 删除 | 删除文件)
        clear
        interactive_delete
        ;;
    fnos | 飞牛)
        # FnOS容器
        # Compose容器管理
        clear
        cd /vol1/1000/compose
        if show_compose_project_menu; then
            :
        else
            break_end
        fi
        ;;
    f2b | 网站防御)
        clear
        web_security
        ;;
    jy | 解压)
        clear
        interactive_extract
        ;;
    ys | 压缩)
        clear
        interactive_compress
        ;;
    xz | 下载)
        clear
        download_file "$2" # 只把第2个参数传进去，其余忽略
        # 用法: m xz [URL]  或直接  m xz 进入主菜单
        ;;
    remove | del | uninstall | 卸载)
        shift
        remove "$@"
        ;;
    update | 更新)
        linux_update
        ;;
    clean | 清理)
        linux_clean
        ;;
    dd | 重装)
        dd_xitong
        ;;
    bbr3 | bbrv3)
        bbrv3
        ;;
    nhyh | 内核优化)
        Kernel_optimize
        ;;
    trash | hsz | 回收站)
        manage_trash_menu
        ;;
    backup | bf | 备份)
        linux_backup
        ;;
    ssh | 远程连接)
        ssh_manager
        ;;
    rsync | 远程同步)
        rsync_manager
        ;;
    rsync_run)
        shift
        run_task "$@"
        ;;
    disk | 硬盘管理)
        disk_manager
        ;;
    wp | wordpress)
        shift
        ldnmp_wp "$@"
        ;;
    fd | rp | 反代)
        shift
        ldnmp_Proxy "$@"
        find_container_by_host_port ""$port""
        if [ -z ""$docker_name"" ]; then
            close_port ""$port""
            echo "已阻止IP+端口访问该服务"
        else
            ip_address
            block_container_port "$docker_name" "$ipv4_address"
        fi
        ;;
    loadbalance | 负载均衡)
        ldnmp_Proxy_backend
        ;;
    stream | L4负载均衡)
        ldnmp_Proxy_backend_stream
        ;;
    swap)
        shift
        add_swap "$@"
        ;;
    time | 时区)
        shift
        set_timedate "$@"
        ;;
    iptables_open)
        iptables_open
        ;;
    frps)
        frps_panel
        ;;
    frpc)
        frpc_panel
        ;;
    打开端口 | dkdk)
        shift
        open_port "$@"
        ;;
    关闭端口 | gbdk)
        shift
        close_port "$@"
        ;;
    放行IP | fxip)
        shift
        allow_ip "$@"
        ;;
    阻止IP | zzip)
        shift
        block_ip "$@"
        ;;
    防火墙 | fhq)
        iptables_panel
        ;;
    命令收藏夹 | fav)
        linux_fav
        ;;
    status | 状态)
        shift
        status "$@"
        ;;
    start | 启动)
        shift
        start "$@"
        ;;
    stop | 停止)
        shift
        stop "$@"
        ;;
    restart | 重启)
        shift
        restart "$@"
        ;;
    enable | autostart | 开机启动)
        shift
        enable "$@"
        ;;
    ssl)
        shift
        if [ "$1" = "ps" ]; then
            ssl_ps
        elif [ -z "$1" ]; then
            add_ssl
        elif [ -n "$1" ]; then
            add_ssl "$1"
        else
            m_info
        fi
        ;;
    docker)
        shift
        case $1 in
        install | 安装)
            install_docker
            ;;
        ps | 容器)
            docker_ps
            ;;
        img | 镜像)
            docker_image
            ;;
        *)
            clear
            m_info
            ;;
        esac
        ;;
    web)
        shift
        if [ "$1" = "cache" ]; then
            web_cache
        elif [ "$1" = "sec" ]; then
            web_security
        elif [ "$1" = "opt" ]; then
            web_optimization
        elif [ -z "$1" ]; then
            ldnmp_web_status
        else
            m_info
        fi
        ;;
    app)
        shift
        #
        linux_panel "$@"
        ;;
    info)
        linux_info
        ;;
    *)
        m_info
        ;;
    esac
fi
