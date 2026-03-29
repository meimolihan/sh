#!/bin/bash

# 颜色变量定义
gl_hui='\033[38;5;59m'       # 灰色
gl_hong='\033[38;5;9m'      # 红色
gl_lv='\033[38;5;10m'          # 绿色
gl_huang='\033[38;5;11m'  # 黄色
gl_lan='\033[38;5;32m'       # 蓝色
gl_bai='\033[38;5;15m'       # 白色
gl_zi='\033[38;5;13m'         # 紫色
gl_bufan='\033[38;5;14m'  # 亮青色

# 日志函数
log_info()  { echo -e "${gl_lan}[信息]${gl_bai} $*"; }
log_ok()    { echo -e "${gl_lv}[成功]${gl_bai} $*"; }
log_warn()  { echo -e "${gl_huang}[警告]${gl_bai} $*"; }
log_error() { echo -e "${gl_hong}[错误]${gl_bai} $*" >&2; }


# 工具函数
handle_invalid_input() {
    echo -ne "\r${gl_huang}无效的输入,请重新输入! ${gl_zi} 1 ${gl_huang} 秒后返回${gl_bai}"
    sleep 1
    echo -ne "\r${gl_lv}无效的输入,请重新输入! ${gl_zi}0${gl_lv} 秒后返回${gl_bai}"
    sleep 0.5
    echo -e "\r                                                   "
    return 2
}

handle_y_n() {
    echo -e "${gl_hong}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_hong}。${gl_bai}"
    sleep 1
    echo -e "${gl_huang}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_huang}。${gl_bai}"
    sleep 1
    echo -e "${gl_lv}无效的选择，请输入 ${gl_bai}(${gl_lv}y${gl_bai}或${gl_hong}N${gl_bai})${gl_lv}。${gl_bai}"
    sleep 0.5
    return 2
}

break_end() {
    echo -e "${gl_lv}操作完成${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    echo ""
    clear
}

exit_script() {
    clear
    exit 0
}

# 安全的 printf 函数，处理以0开头的数字
safe_printf() {
    local format="$1"
    local number="$2"
    
    # 如果是十进制格式，去除前导零
    if [[ "$format" == "%d" ]] || [[ "$format" == "%02d" ]] || [[ "$format" == "%03d" ]]; then
        # 去除前导零，避免被解释为八进制
        number=$(echo "$number" | sed 's/^0*//')
        if [ -z "$number" ]; then
            number=0
        fi
    fi
    
    printf "$format" "$number"
}

# 增强的智能提取集数函数 - 返回所有可能的识别结果
enhanced_extract_episode_info() {
    local filename="$1"
    local results=()
    
    # 1. 尝试匹配 S01E26 格式
    if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee]([0-9]{1,3}) ]]; then
        local season="${BASH_REMATCH[1]}"
        local episode="${BASH_REMATCH[2]}"
        results+=("S${season}E${episode}:${season}:${episode}:SxE格式")
    fi
    
    # 2. 匹配 EP26 或 EP26- 格式
    if [[ "$filename" =~ [Ee][Pp]([0-9]{1,3})[^0-9] ]]; then
        local episode="${BASH_REMATCH[1]}"
        results+=("EP${episode}:01:${episode}:EP格式")
    fi
    
    # 3. 匹配 第26集 格式
    if [[ "$filename" =~ 第([0-9]{1,3})[集話话] ]]; then
        local episode="${BASH_REMATCH[1]}"
        results+=("第${episode}集:01:${episode}:中文第X集")
    fi
    
    # 4. 匹配 -26- 或 .26. 格式
    if [[ "$filename" =~ [^0-9]([0-9]{1,3})[^0-9] ]]; then
        local num="${BASH_REMATCH[1]}"
        # 排除年份（通常是4位数）
        if [ "$num" -lt 1000 ] || [ "$num" -gt 2100 ]; then
            results+=("${num}:01:${num}:数字格式")
        fi
    fi
    
    # 5. 匹配文件名开头的数字
    if [[ "$filename" =~ ^([0-9]{1,3}) ]]; then
        local episode="${BASH_REMATCH[1]}"
        results+=("${episode}:01:${episode}:开头数字")
    fi
    
    # 6. 匹配文件名结尾的数字
    if [[ "$filename" =~ ([0-9]{1,3})\.[^.]*$ ]]; then
        local episode="${BASH_REMATCH[1]}"
        results+=("${episode}:01:${episode}:结尾数字")
    fi
    
    # 如果没有识别结果，返回默认
    if [ ${#results[@]} -eq 0 ]; then
        results+=("0:01:1:未识别")
    fi
    
    # 返回所有结果
    printf "%s\n" "${results[@]}"
}

# 分析文件名模式
analyze_filename_patterns() {
    local files=("$@")
    
    echo -e "${gl_zi}>>> 智能模式分析${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 使用普通数组统计模式
    local pattern_array=()
    local example_array=()
    local count_array=()
    
    for file in "${files[@]}"; do
        local filename=$(basename -- "$file")
        local results=($(enhanced_extract_episode_info "$filename"))
        
        for result in "${results[@]}"; do
            IFS=':' read -r pattern season episode type <<< "$result"
            if [ "$type" != "未识别" ]; then
                # 查找是否已存在该类型
                local found=0
                for i in "${!pattern_array[@]}"; do
                    if [ "${pattern_array[i]}" = "$type" ]; then
                        count_array[i]=$((count_array[i] + 1))
                        found=1
                        break
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    pattern_array+=("$type")
                    example_array+=("$filename")
                    count_array+=(1)
                fi
                break
            fi
        done
    done
    
    # 显示模式统计
    if [ ${#pattern_array[@]} -eq 0 ]; then
        echo -e "${gl_huang}未检测到有效的剧集编号模式${gl_bai}"
    else
        echo -e "${gl_bai}检测到的剧集编号模式:${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        for ((i=0; i<${#pattern_array[@]}; i++)); do
            local type="${pattern_array[i]}"
            local count="${count_array[i]}"
            local example="${example_array[i]}"
            local percentage=$((count * 100 / ${#files[@]}))
            local index=$((i+1))
            
            if [ $percentage -ge 50 ]; then
                echo -e "  ${gl_lv}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)"
            else
                echo -e "  ${gl_huang}${index}.${gl_bai} ${gl_bufan}${type}${gl_bai} (${percentage}% 文件)"
            fi
            echo -e "     示例: ${gl_hui}${example}${gl_bai}"
        done
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    return 0
}

# 自动检测最佳重命名方案
auto_detect_rename_plan() {
    local files=("$@")
    local plans=()
    clear
    echo -e "${gl_zi}>>> 自动检测重命名方案${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 方案1: 保持原季号（如果检测到）
    local season_array=()
    local season_count_array=()
    
    for file in "${files[@]}"; do
        local filename=$(basename -- "$file")
        if [[ "$filename" =~ [Ss]([0-9]{1,2})[Ee] ]]; then
            local season="${BASH_REMATCH[1]}"
            
            local found=0
            for i in "${!season_array[@]}"; do
                if [ "${season_array[i]}" = "$season" ]; then
                    season_count_array[i]=$((season_count_array[i] + 1))
                    found=1
                    break
                fi
            done
            
            if [ $found -eq 0 ]; then
                season_array+=("$season")
                season_count_array+=(1)
            fi
        fi
    done
    
    if [ ${#season_array[@]} -gt 0 ]; then
        local best_season=""
        local best_count=0
        for i in "${!season_array[@]}"; do
            if [ ${season_count_array[i]} -gt $best_count ]; then
                best_count=${season_count_array[i]}
                best_season="${season_array[i]}"
            fi
        done
        
        if [ -n "$best_season" ]; then
            local formatted_season=$(safe_printf "%02d" "$best_season")
            plans+=("保持原季号|S${formatted_season}|检测到S${formatted_season}格式|高")
        fi
    fi
    
    # 方案2: 从文件名提取前缀
    if [ ${#files[@]} -gt 0 ]; then
        local sample_file=$(basename -- "${files[0]}")
        
        # 尝试提取中文剧名
        if [[ "$sample_file" =~ ^([^0-9.-[:space:]]+)[^0-9]* ]]; then
            local chinese_name="${BASH_REMATCH[1]}"
            chinese_name=$(echo "$chinese_name" | sed 's/^[[:space:][:punct:]]*//;s/[[:space:][:punct:]]*$//')
            if [ -n "$chinese_name" ] && [ ${#chinese_name} -ge 2 ]; then
                plans+=("中文剧名|${chinese_name}|从文件名提取中文名|中")
            fi
        fi
        
        # 尝试提取英文剧名
        if [[ "$sample_file" =~ \.([A-Za-z][A-Za-z. ]+?)[^A-Za-z] ]]; then
            local english_name="${BASH_REMATCH[1]}"
            english_name=$(echo "$english_name" | sed 's/\./ /g;s/ $//')
            if [ -n "$english_name" ]; then
                plans+=("英文剧名|${english_name}|从文件名提取英文名|中")
            fi
        fi
    fi
    
    # 显示检测到的方案
    if [ ${#plans[@]} -eq 0 ]; then
        echo -e "${gl_huang}未检测到有效的重命名方案${gl_bai}"
        return 1
    fi
    
    echo -e "${gl_bai}检测到的重命名方案:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    for ((i=0; i<${#plans[@]}; i++)); do
        IFS='|' read -r type value description confidence <<< "${plans[$i]}"
        local index=$((i+1))
        
        case $confidence in
            高) color="${gl_lv}" ;;
            中) color="${gl_huang}" ;;
            *)  color="${gl_hong}" ;;
        esac
        
        echo -e "  ${gl_bufan}${index}.${gl_bai} ${color}${type}${gl_bai}"
        echo -e "     值: ${gl_bufan}${value}${gl_bai}"
        echo -e "     说明: ${gl_hui}${description}${gl_bai}"
        echo -e "     置信度: ${color}${confidence}${gl_bai}"
        echo ""
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    return 0
}

# 电视剧文件重命名函数（终极版）
rename_tv_files_ultimate() {
    # 支持的视频文件扩展名
    local VIDEO_EXTS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")
    local PREFIX=""
    local SEASON="01"
    local START_EP="1"
    local preview_mode=1
    local rename_count=0
    local auto_detected=0
    local detection_results=()
    
    # 扫描文件函数
    scan_video_files() {
        local -n files_ref=$1
        local -n episode_info_ref=$2
        local -n pattern_types_ref=$3
        
        # 生成扩展名匹配字符串
        local ext_pattern=""
        for ext in "${VIDEO_EXTS[@]}"; do
            if [ -z "$ext_pattern" ]; then
                ext_pattern="-name \"*.$ext\""
            else
                ext_pattern="$ext_pattern -o -name \"*.$ext\""
            fi
        done
        
        # 收集文件
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                local filename=$(basename -- "$file")
                local extension="${filename##*.}"
                
                # 获取所有可能的识别结果
                local results=($(enhanced_extract_episode_info "$filename"))
                local found=0
                
                for result in "${results[@]}"; do
                    IFS=':' read -r pattern season episode type <<< "$result"
                    if [ "$episode" != "0" ] && { [ "$episode" != "1" ] || [ "$type" != "未识别" ]; }; then
                        files_ref+=("$file")
                        episode_info_ref+=("$episode:$season:$type")
                        pattern_types_ref+=("$type")
                        found=1
                        break
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    # 无法识别集数的文件
                    log_warn "无法识别集数: $filename"
                fi
            fi
        done < <(eval "find . -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null" | sort -V)
    }
    
    while true; do
        clear
        echo -e "${gl_zi}>>> 电视剧文件重命名（终极版）${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        # 显示当前设置
        if [ -n "$PREFIX" ]; then
            echo -e "${gl_bufan}当前设置:${gl_bai}"
            echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX"
            echo -e "  ${gl_bufan}季号:${gl_bai} S$SEASON"
            echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" $START_EP)"
            if [ $auto_detected -eq 1 ]; then
                echo -e "  ${gl_lv}✓ 智能检测已应用${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        fi
        
        # 扫描文件
        log_info "扫描当前目录视频文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        local files=()
        local episode_info=()
        local pattern_types=()
        
        scan_video_files files episode_info pattern_types
        
        if [ ${#files[@]} -eq 0 ]; then
            log_error "未找到可识别的视频文件！"
            echo -e "${gl_bai}支持格式: ${gl_bufan}${VIDEO_EXTS[*]}${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ")" -n 1
            return
        fi
        
        # 按集数排序文件
        if [ ${#files[@]} -gt 0 ]; then
            # 创建临时数组用于排序
            local sorted_files=()
            local sorted_episodes=()
            
            # 按集数排序
            while IFS= read -r line; do
                IFS=':' read -r episode season type <<< "$line"
                for i in "${!files[@]}"; do
                    if [[ "${episode_info[$i]}" == "$line" ]]; then
                        sorted_episodes+=("$episode:$season:$type")
                        sorted_files+=("${files[$i]}")
                        break
                    fi
                done
            done < <(printf "%s\n" "${episode_info[@]}" | sort -t: -k1,1n)
            
            files=("${sorted_files[@]}")
            episode_info=("${sorted_episodes[@]}")
        fi
        
        # 显示找到的文件
        echo -e "${gl_bufan}找到 ${#files[@]} 个可识别文件:${gl_bai}"
        for ((i=0; i<${#files[@]}; i++)); do
            local filename=$(basename -- "${files[$i]}")
            IFS=':' read -r episode season type <<< "${episode_info[$i]}"
            echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i+1))).${gl_bai} E$(safe_printf "%02d" "$episode") [${type}] - $filename"
        done
        
        # 分析文件模式
        if [ $auto_detected -eq 0 ] && [ ${#files[@]} -gt 0 ]; then
            echo -e ""
            echo -e "${gl_bai}检测到的模式分布:${gl_bai}"
            
            # 使用普通数组统计
            local pattern_array=()
            local count_array=()
            
            for pattern in "${pattern_types[@]}"; do
                local found=0
                for i in "${!pattern_array[@]}"; do
                    if [ "${pattern_array[i]}" = "$pattern" ]; then
                        count_array[i]=$((count_array[i] + 1))
                        found=1
                        break
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    pattern_array+=("$pattern")
                    count_array+=(1)
                fi
            done
            
            for i in "${!pattern_array[@]}"; do
                local pattern="${pattern_array[i]}"
                local count="${count_array[i]}"
                local percentage=$((count * 100 / ${#files[@]}))
                echo -e "  ${gl_bufan}${pattern}:${gl_bai} ${count} 文件 (${percentage}%)"
            done
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        # 菜单选项
        echo -e "${gl_bufan}1.  ${gl_bai}智能检测最佳方案"
        echo -e "${gl_bufan}2.  ${gl_bai}设置剧集前缀"
        echo -e "${gl_bufan}3.  ${gl_bai}设置季号"
        echo -e "${gl_bufan}4.  ${gl_bai}设置起始集数"
        echo -e "${gl_bufan}5.  ${gl_bai}详细模式分析"
        echo -e "${gl_bufan}6.  ${gl_bai}预览重命名结果"
        
        if [ $preview_mode -eq 1 ] && [ -n "$PREFIX" ]; then
            echo -e "${gl_bufan}7.  ${gl_lv}执行重命名${gl_bai}"
        else
            echo -e "${gl_bufan}7.  ${gl_bai}执行重命名"
        fi
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单"
        echo -e "${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
        1)
            clear
            echo -e "${gl_zi}>>> 智能检测最佳方案${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # 运行自动检测
            auto_detect_rename_plan "${files[@]}"
            
            if [ $? -eq 0 ]; then
                echo -e ""
                echo -e "${gl_bai}是否应用检测到的方案?${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                
                read -r -e -p "$(echo -e "${gl_bai}应用检测结果? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" apply_choice
                
                case "$apply_choice" in
                [Yy])
                    auto_detected=1
                    
                    # 尝试自动提取剧名前缀
                    if [ ${#files[@]} -gt 0 ]; then
                        local sample_file=$(basename -- "${files[0]}")
                        
                        # 尝试提取中文名
                        if [[ "$sample_file" =~ ^([^0-9.-[:space:]]+)[^0-9]* ]]; then
                            local extracted_prefix="${BASH_REMATCH[1]}"
                            extracted_prefix=$(echo "$extracted_prefix" | sed 's/[[:space:][:punct:]]*$//')
                            if [ ${#extracted_prefix} -ge 2 ]; then
                                PREFIX="$extracted_prefix"
                                log_ok "自动设置剧集前缀: $PREFIX"
                            fi
                        fi
                        
                        # 自动检测季号
                        local season_array=()
                        local season_count_array=()
                        
                        for info in "${episode_info[@]}"; do
                            IFS=':' read -r episode season type <<< "$info"
                            if [ "$season" != "01" ]; then
                                local found=0
                                for i in "${!season_array[@]}"; do
                                    if [ "${season_array[i]}" = "$season" ]; then
                                        season_count_array[i]=$((season_count_array[i] + 1))
                                        found=1
                                        break
                                    fi
                                done
                                
                                if [ $found -eq 0 ]; then
                                    season_array+=("$season")
                                    season_count_array+=(1)
                                fi
                            fi
                        done
                        
                        if [ ${#season_array[@]} -gt 0 ]; then
                            local best_season=""
                            local best_count=0
                            for i in "${!season_array[@]}"; do
                                if [ ${season_count_array[i]} -gt $best_count ]; then
                                    best_count=${season_count_array[i]}
                                    best_season="${season_array[i]}"
                                fi
                            done
                            
                            if [ -n "$best_season" ]; then
                                SEASON=$(safe_printf "%02d" "$best_season")
                                log_ok "自动设置季号: S$SEASON"
                            fi
                        fi
                    fi
                    
                    log_ok "智能检测已应用！"
                    preview_mode=0
                    ;;
                    
                [Nn])
                    log_info "已取消应用检测结果"
                    ;;
                    
                *)
                    handle_y_n
                    ;;
                esac
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
            
        2)
            clear
            echo -e "${gl_zi}>>> 设置剧集前缀${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # ========== 新增：从所有文件中提取前缀候选并统计频率 ==========
            # 定义提取前缀候选的函数
            extract_prefix_candidate() {
                local filename="$1"
                local basename="${filename%.*}"  # 去掉扩展名
                # 获取第一个识别的集数模式（如果有）
                local results=($(enhanced_extract_episode_info "$filename"))
                if [ ${#results[@]} -gt 0 ]; then
                    IFS=':' read -r pattern season episode type <<< "${results[0]}"
                    if [ "$type" != "未识别" ] && [ -n "$pattern" ]; then
                        # 将模式中的特殊字符转义，用于sed
                        # 简单处理：直接移除匹配到的模式及其前后的常见分隔符
                        # 使用sed替换，注意模式中可能包含点、括号等
                        # 这里简化：将pattern作为普通字符串移除，并去掉前后的分隔符
                        local cleaned=$(echo "$basename" | sed -E "s/[._ -]*${pattern}[._ -]*//g")
                        # 如果清理后为空，则回退到basename
                        if [ -n "$cleaned" ]; then
                            # 去除首尾多余分隔符
                            cleaned=$(echo "$cleaned" | sed 's/^[._ -]*//;s/[._ -]*$//')
                            # 去除可能残留的分辨率标签（如1080p、2160p等），但为了简单，不做了
                            if [ -n "$cleaned" ] && [ ${#cleaned} -ge 2 ]; then
                                echo "$cleaned"
                                return
                            fi
                        fi
                    fi
                fi
                # 如果没有识别到集数或清理后为空，则直接返回basename（但去掉开头结尾的杂音）
                local fallback=$(echo "$basename" | sed 's/^[._ -]*//;s/[._ -]*$//')
                if [ -n "$fallback" ] && [ ${#fallback} -ge 2 ]; then
                    echo "$fallback"
                else
                    # 极短或无，返回空
                    echo ""
                fi
            }
            
            # 收集所有候选
            local candidates=()
            local counts=()
            local total_files=${#files[@]}
            
            for file in "${files[@]}"; do
                local filename=$(basename -- "$file")
                local candidate=$(extract_prefix_candidate "$filename")
                if [ -z "$candidate" ]; then
                    continue
                fi
                # 检查是否已存在
                local found=-1
                for idx in "${!candidates[@]}"; do
                    if [ "${candidates[$idx]}" = "$candidate" ]; then
                        found=$idx
                        break
                    fi
                done
                if [ $found -ge 0 ]; then
                    counts[$found]=$((counts[$found] + 1))
                else
                    candidates+=("$candidate")
                    counts+=(1)
                fi
            done
            
            # 如果没有提取到任何候选，使用默认值
            if [ ${#candidates[@]} -eq 0 ]; then
                candidates=("电视剧")
                counts=($total_files)
                log_warn "无法自动识别前缀，使用默认值: 电视剧"
            fi
            
            # 按计数降序排序（简单冒泡，候选不多）
            # 同时保持关联
            for ((i=0; i<${#candidates[@]}-1; i++)); do
                for ((j=i+1; j<${#candidates[@]}; j++)); do
                    if [ ${counts[$j]} -gt ${counts[$i]} ]; then
                        # 交换
                        tmp_c="${candidates[$i]}"
                        tmp_n="${counts[$i]}"
                        candidates[$i]="${candidates[$j]}"
                        counts[$i]="${counts[$j]}"
                        candidates[$j]="$tmp_c"
                        counts[$j]="$tmp_n"
                    fi
                done
            done
            
            # 限制显示前10个（太多用户不好选）
            local display_limit=10
            if [ ${#candidates[@]} -gt $display_limit ]; then
                candidates=("${candidates[@]:0:$display_limit}")
                counts=("${counts[@]:0:$display_limit}")
            fi
            
            # 显示候选列表
            echo -e "${gl_bai}从文件名中提取到的剧名前缀:${gl_bai}"
            for i in "${!candidates[@]}"; do
                local idx=$((i+1))
                local percentage=$(( counts[i] * 100 / total_files ))
                echo -e "  ${gl_bufan}${idx}.${gl_bai} ${gl_lv}${candidates[$i]}${gl_bai} (出现 ${counts[$i]} 次, ${percentage}%)"
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bai}推荐: ${gl_lv}${candidates[0]}${gl_bai} (${gl_huang}回车直接使用推荐${gl_bai})"
            echo -e "${gl_bai}示例: ${gl_bufan}${candidates[0]}-S${SEASON}E01.扩展名${gl_bai}"
            echo -e "${gl_bai}指定: ${gl_bai}手动输入自定义前缀"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}请输入序号或自定义前缀 (${gl_huang}0${gl_bai}返回): ")" input_prefix
            
            if [ "$input_prefix" = "0" ]; then
                continue
            fi
            
            # 检查输入是否为数字（序号）
            if [[ "$input_prefix" =~ ^[0-9]+$ ]] && [ "$input_prefix" -ge 1 ] && [ "$input_prefix" -le ${#candidates[@]} ]; then
                # 选择序号
                PREFIX="${candidates[$((input_prefix-1))]}"
                log_ok "剧集前缀已设置为: $PREFIX (通过序号选择)"
            elif [ -z "$input_prefix" ]; then
                # 回车使用推荐
                PREFIX="${candidates[0]}"
                log_ok "剧集前缀已设置为: $PREFIX (使用推荐)"
            else
                # 手动输入
                PREFIX="$input_prefix"
                log_ok "剧集前缀已设置为: $PREFIX (手动输入)"
            fi
            
            preview_mode=0
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
            
        3)
            echo -e ""
            echo -e "${gl_zi}>>> 设置季号${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # 显示检测到的季号统计
            local season_array=()
            local season_count_array=()
            
            for info in "${episode_info[@]}"; do
                IFS=':' read -r episode season type <<< "$info"
                if [ "$season" != "01" ]; then
                    local found=0
                    for i in "${!season_array[@]}"; do
                        if [ "${season_array[i]}" = "$season" ]; then
                            season_count_array[i]=$((season_count_array[i] + 1))
                            found=1
                            break
                        fi
                    done
                    
                    if [ $found -eq 0 ]; then
                        season_array+=("$season")
                        season_count_array+=(1)
                    fi
                fi
            done
            
            if [ ${#season_array[@]} -gt 0 ]; then
                echo -e "${gl_bai}从文件名检测到季号:${gl_bai}"
                for i in "${!season_array[@]}"; do
                    local season="${season_array[i]}"
                    local count="${season_count_array[i]}"
                    local percentage=$((count * 100 / ${#files[@]}))
                    echo -e "  ${gl_bufan}S${season}:${gl_bai} ${count} 文件 (${percentage}%)"
                done
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            fi
            
            echo -e "${gl_bai}当前季号: ${gl_bufan}S${SEASON}${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}01${gl_bai} 表示第 ${gl_bufan}1${gl_bai} 季 (将显示为 S01)"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入季号 (当前: ${gl_lv}S${SEASON}${gl_bai}，回车保持，${gl_huang}0${gl_bai}返回): ")" input_season
            
            if [ "$input_season" = "0" ]; then
                continue
            fi
            
            if [ -z "$input_season" ]; then
                # 回车保持
                echo -e "${gl_bai}保持当前季号: S${SEASON}${gl_bai}"
                continue
            fi
            
            if [[ "$input_season" =~ ^[0-9]{1,2}$ ]]; then
                SEASON=$(safe_printf "%02d" "$input_season")
                log_ok "季号已设置为: S$SEASON"
                preview_mode=0
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                log_error "请输入有效的数字 (1-99)！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi
            ;;
            
        4)
            echo -e ""
            echo -e "${gl_zi}>>> 设置起始集数${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # 显示识别的集数范围
            if [ ${#episode_info[@]} -gt 0 ]; then
                local first_info="${episode_info[0]}"
                local last_info="${episode_info[-1]}"
                IFS=':' read -r first_ep first_season first_type <<< "$first_info"
                IFS=':' read -r last_ep last_season last_type <<< "$last_info"
                
                echo -e "${gl_bai}识别的集数范围:${gl_bai}"
                echo -e "  ${gl_bufan}最小:${gl_bai} E$(safe_printf "%02d" "$first_ep") (${first_type})"
                echo -e "  ${gl_bufan}最大:${gl_bai} E$(safe_printf "%02d" "$last_ep") (${last_type})"
                echo -e "  ${gl_bufan}建议:${gl_bai} 从 E$(safe_printf "%02d" "$first_ep") 开始"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            fi
            
            echo -e "${gl_bai}当前起始集数: ${gl_bufan}E$(safe_printf "%02d" "$START_EP")${gl_bai}"
            echo -e "${gl_bai}示例: ${gl_bufan}26${gl_bai} 表示从第 ${gl_bufan}26${gl_bai} 集开始编号"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            read -r -e -p "$(echo -e "${gl_bai}请输入起始集数 (当前: ${gl_lv}E$(safe_printf "%02d" "$START_EP")${gl_bai}，回车保持，${gl_huang}0${gl_bai}返回): ")" input_start
            
            if [ "$input_start" = "0" ]; then
                continue
            fi
            
            if [ -z "$input_start" ]; then
                # 回车保持
                echo -e "${gl_bai}保持当前起始集数: E$(safe_printf "%02d" "$START_EP")${gl_bai}"
                continue
            fi
            
            if [[ "$input_start" =~ ^[0-9]{1,3}$ ]] && [ "$input_start" -ge 1 ]; then
                START_EP="$input_start"
                log_ok "起始集数已设置为: E$(safe_printf "%02d" "$START_EP")"
                preview_mode=0
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            else
                log_error "请输入有效的集数 (1-999)！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
            fi
            ;;
            
        5)
            clear
            analyze_filename_patterns "${files[@]}"
            
            # 显示详细的文件分析
            echo -e ""
            echo -e "${gl_zi}>>> 详细文件分析${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            echo -e "${gl_bai}文件分析详情:${gl_bai}"
            for ((i=0; i<${#files[@]} && i<10; i++)); do
                local filename=$(basename -- "${files[$i]}")
                IFS=':' read -r episode season type <<< "${episode_info[$i]}"
                echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i+1))).${gl_bai} $filename"
                echo -e "      识别为: ${type}"
                echo -e "      季号: S${season}"
                echo -e "      集数: E$(safe_printf "%02d" "$episode")"
                echo ""
            done
            
            if [ ${#files[@]} -gt 10 ]; then
                echo -e "  ${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} 还有 $((${#files[@]} - 10)) 个文件未显示${gl_bai}"
            fi
            
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
            
        6)
            if [ -z "$PREFIX" ]; then
                log_error "请先设置剧集前缀！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            
            clear
            echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            echo -e "${gl_bufan}当前设置:${gl_bai}"
            echo -e "  ${gl_bufan}剧集前缀:${gl_bai} $PREFIX"
            echo -e "  ${gl_bufan}季号:${gl_bai} S$SEASON"
            echo -e "  ${gl_bufan}起始集数:${gl_bai} E$(safe_printf "%02d" "$START_EP")"
            if [ $auto_detected -eq 1 ]; then
                echo -e "  ${gl_lv}✓ 智能检测已应用${gl_bai}"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            local current_ep=$START_EP
            detection_results=()
            local summary_array=()
            local summary_count_array=()
            
            echo -e "${gl_bai}重命名预览:${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            for ((i=0; i<${#files[@]}; i++)); do
                local file="${files[$i]}"
                local filename=$(basename -- "$file")
                local extension="${filename##*.}"
                IFS=':' read -r original_ep original_season type <<< "${episode_info[$i]}"
                local formatted_ep=$(safe_printf "%02d" "$current_ep")
                local new_name="${PREFIX}-S${SEASON}E${formatted_ep}.${extension}"
                
                # 记录统计信息
                local found=0
                for j in "${!summary_array[@]}"; do
                    if [ "${summary_array[j]}" = "$type" ]; then
                        summary_count_array[j]=$((summary_count_array[j] + 1))
                        found=1
                        break
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    summary_array+=("$type")
                    summary_count_array+=(1)
                fi
                
                echo -e "  ${gl_bufan}[$(safe_printf "%02d" $((i+1)))]${gl_bai}"
                echo -e "    原文件: ${gl_hui}$filename${gl_bai}"
                echo -e "    识别为: ${type} (E$(safe_printf "%02d" "$original_ep"))"
                echo -e "    新文件: ${gl_lv}$new_name${gl_bai}"
                echo ""
                
                detection_results+=("$file:$new_name:$type:$original_ep")
                ((current_ep++))
            done
            
            # 显示统计信息
            if [ ${#summary_array[@]} -gt 0 ]; then
                echo -e "${gl_bai}识别模式统计:${gl_bai}"
                for i in "${!summary_array[@]}"; do
                    local type="${summary_array[i]}"
                    local count="${summary_count_array[i]}"
                    local percentage=$((count * 100 / ${#files[@]}))
                    echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件 (${percentage}%)"
                done
            fi
            
            preview_mode=1
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # 计算识别准确率
            local accurate_count=0
            for i in "${!summary_array[@]}"; do
                local type="${summary_array[i]}"
                if [[ "$type" == "SxE格式" ]] || [[ "$type" == "EP格式" ]] || [[ "$type" == "中文第X集" ]]; then
                    accurate_count=$((accurate_count + summary_count_array[i]))
                fi
            done
            
            local accuracy=0
            if [ ${#files[@]} -gt 0 ]; then
                accuracy=$((accurate_count * 100 / ${#files[@]}))
            fi
            
            log_info "预览完成，共 ${#detection_results[@]} 个文件"
            if [ ${#files[@]} -gt 0 ]; then
                log_info "识别准确率: ${accuracy}%"
            fi
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            ;;
            
        7)
            if [ $preview_mode -eq 0 ]; then
                log_error "请先预览重命名结果！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            
            if [ ${#detection_results[@]} -eq 0 ]; then
                log_error "没有可重命名的文件！"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                continue
            fi
            
            clear
            echo -e "${gl_zi}>>> 确认重命名${gl_bai}"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            # 显示重命名统计
            local type_array=()
            local type_count_array=()
            
            for item in "${detection_results[@]}"; do
                IFS=':' read -r old_file new_name type original_ep <<< "$item"
                
                local found=0
                for i in "${!type_array[@]}"; do
                    if [ "${type_array[i]}" = "$type" ]; then
                        type_count_array[i]=$((type_count_array[i] + 1))
                        found=1
                        break
                    fi
                done
                
                if [ $found -eq 0 ]; then
                    type_array+=("$type")
                    type_count_array+=(1)
                fi
            done
            
            echo -e "${gl_bai}重命名统计:${gl_bai}"
            echo -e "  ${gl_bufan}总文件数:${gl_bai} ${#detection_results[@]}"
            for i in "${!type_array[@]}"; do
                local type="${type_array[i]}"
                local count="${type_count_array[i]}"
                echo -e "  ${gl_bufan}${type}:${gl_bai} ${count} 文件"
            done
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            
            read -r -e -p "$(echo -e "${gl_bai}确定要执行重命名吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
            
            case "$confirm" in
            [Yy])
                log_info "开始重命名${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
                rename_count=0
                local success_count=0
                local fail_count=0
                
                for item in "${detection_results[@]}"; do
                    IFS=':' read -r old_file new_name type original_ep <<< "$item"
                    
                    if [ -f "$old_file" ]; then
                        echo -e "${gl_bai}处理: ${gl_hui}$(basename "$old_file")${gl_bai}"
                        echo -e "  识别: ${type} (E$(safe_printf "%02d" "$original_ep"))"
                        
                        if mv -- "$old_file" "./$new_name" 2>/dev/null; then
                            echo -e "  ${gl_lv}✓ 重命名为: $new_name${gl_bai}"
                            ((success_count++))
                        else
                            echo -e "  ${gl_hong}✗ 重命名失败${gl_bai}"
                            ((fail_count++))
                        fi
                    else
                        echo -e "${gl_huang}⚠ 文件不存在: $(basename "$old_file")${gl_bai}"
                        ((fail_count++))
                    fi
                    echo ""
                done
                
                rename_count=$success_count
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                echo -e "${gl_lv}成功:${gl_bai} $success_count 个文件"
                echo -e "${gl_hong}失败:${gl_bai} $fail_count 个文件"
                log_ok "重命名完成！"
                
                preview_mode=0
                auto_detected=0
                detection_results=()
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
                
            [Nn])
                log_info "已取消重命名操作"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                break_end
                ;;
                
            *)
                handle_y_n
                ;;
            esac
            ;;
            
        0)
            if [ $rename_count -gt 0 ]; then
                log_ok "操作完成，已重命名 $rename_count 个文件"
            fi
            return
            ;;
        00 | 000 | 0000) exit_script ;;
        *)
            handle_invalid_input
            ;;
        esac
    done
}

# 批量测试不同识别模式
test_all_recognition_modes() {
    clear
    echo -e "${gl_zi}>>> 批量测试识别模式${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 测试用例
    local test_cases=(
        "电视剧集.How.Dare.You.S01E26.2026.2160p.IQ.WEB-DL.H265.DDP5.1-ColorWEB.mkv|SxE格式|S01E26"
        "EP26-剧情发展.mp4|EP格式|EP26"
        "第26集.电视剧名.avi|中文第X集|第26集"
        "26-剧集名.mov|数字格式|26"
        "01.第一集.mkv|开头数字|01"
        "S1E1.测试.mkv|SxE格式|S1E1"
        "Episode.1.mkv|EP格式|EP1"
        "test-26-video.mkv|数字格式|26"
        "2026.2160p.WEB-DL.mkv|未识别|未识别"
        "电影名.1080p.mp4|未识别|未识别"
    )
    
    echo -e "${gl_bai}测试识别引擎准确性:${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    local total_cases=${#test_cases[@]}
    local correct_cases=0
    local partially_correct=0
    
    for test_case in "${test_cases[@]}"; do
        IFS='|' read -r filename expected_type expected_pattern <<< "$test_case"
        
        echo -e "  ${gl_bufan}测试文件:${gl_bai} ${gl_hui}$filename${gl_bai}"
        
        # 运行识别
        local results=($(enhanced_extract_episode_info "$filename"))
        local first_result="${results[0]}"
        IFS=':' read -r pattern season episode type <<< "$first_result"
        
        if [ "$type" = "$expected_type" ]; then
            echo -e "  ${gl_lv}✓ 正确识别: ${type} (${pattern})${gl_bai}"
            ((correct_cases++))
        elif [ "$type" != "未识别" ] && [ "$expected_type" != "未识别" ]; then
            echo -e "  ${gl_huang}⚠ 部分识别: ${type} (预期: ${expected_type})${gl_bai}"
            ((partially_correct++))
        else
            echo -e "  ${gl_hong}✗ 识别错误: ${type} (预期: ${expected_type})${gl_bai}"
        fi
        
        # 显示所有可能的识别结果
        if [ ${#results[@]} -gt 1 ]; then
            echo -e "  ${gl_bai}所有可能的识别:${gl_bai}"
            for result in "${results[@]}"; do
                IFS=':' read -r p s e t <<< "$result"
                echo -e "    - ${t}: ${p} (S${s}E${e})"
            done
        fi
        
        echo ""
    done
    
    local accuracy=0
    local partial_accuracy=0
    if [ $total_cases -gt 0 ]; then
        accuracy=$((correct_cases * 100 / total_cases))
        partial_accuracy=$(((correct_cases + partially_correct) * 100 / total_cases))
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}识别准确率统计:${gl_bai}"
    echo -e "  ${gl_bufan}测试用例:${gl_bai} $total_cases 个"
    echo -e "  ${gl_lv}完全正确:${gl_bai} $correct_cases 个"
    echo -e "  ${gl_huang}部分正确:${gl_bai} $partially_correct 个"
    echo -e "  ${gl_bufan}完全准确率:${gl_bai} ${accuracy}%"
    echo -e "  ${gl_bufan}部分准确率:${gl_bai} ${partial_accuracy}%"
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 创建多种格式测试文件
create_mixed_test_files() {
    echo -e ""
    echo -e "${gl_zi}>>> 创建多种格式测试文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}要创建多少个测试文件? (默认: ${gl_lv}16${gl_bai}, ${gl_huang}0${gl_bai}返回): ")" file_count
    
    if [ "$file_count" = "0" ]; then
        return
    fi
    
    # 处理空输入，使用默认值16
    if [ -z "$file_count" ]; then
        file_count=16
        log_info "使用默认值: ${gl_lv}16${gl_bai} 个文件"
    fi
    
    if ! [[ "$file_count" =~ ^[0-9]+$ ]] || [ "$file_count" -lt 1 ]; then
        log_error "请输入有效的数字！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
    fi
    
    log_info "${gl_bai}正在创建 ${gl_huang}$file_count ${gl_bai}个测试文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    for i in $(seq 1 $file_count); do
        case $((i % 6)) in
            0) filename="S01E$(printf "%02d" $i).2026.2160p.WEB-DL.mkv" ;;
            1) filename="EP$(printf "%02d" $i)-剧情发展.mp4" ;;
            2) filename="第$(printf "%d" $i)集.电视剧名.avi" ;;
            3) filename="$(printf "%02d" $i)-剧集名.mov" ;;
            4) filename="电视剧.S01E$(printf "%02d" $i).WEBRip.wmv" ;;
            5) filename="test$(printf "%d" $i).480p.mpeg" ;;
        esac
        
        touch "$filename"
        echo -e "  ${gl_lv}创建:${gl_bai} $filename"
    done
    
    log_ok "${gl_bai}创建完成！共创建 ${gl_lv}$file_count ${gl_bai}个测试文件"
    log_info "包含多种识别格式"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 查看当前文件函数
show_current_files() {

    # echo -e "${gl_bufan}视频文件:${gl_bai}"
    local video_count=0
    
    for ext in mp4 mkv avi mov wmv flv webm m4v mpg mpeg kvm; do
        for file in *."$ext"; do
            if [ -f "$file" ]; then
                echo -e "  ${gl_bufan}▶${gl_bai} $file"
                ((video_count++))
            fi
        done 2>/dev/null || true
    done
    
    if [ $video_count -eq 0 ]; then
        echo -e "  ${gl_huang}无视频文件${gl_bai}"
    fi
    
    echo -e ""
    echo -e "${gl_huang}文件统计:${gl_bai}"
    echo -e "  ${gl_bai}视频文件:${gl_lv} $video_count ${gl_bai}个"
}

# 删除测试文件函数
delete_test_files() {
    echo -e ""
    echo -e "${gl_zi}>>> 删除测试文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}确定要删除所有测试文件吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
    
    case "$confirm" in
    [Yy])
        local count=0
        for ext in mp4 mkv avi mov wmv flv webm m4v mpg mpeg kvm; do
            for file in *."$ext"; do
                if [ -f "$file" ]; then
                    rm -f "$file"
                    echo -e "  ${gl_hong}删除:${gl_bai} $file"
                    ((count++))
                fi
            done 2>/dev/null || true
        done
        
        if [ $count -gt 0 ]; then
            log_ok "删除完成！共删除 $count 个文件"
        else
            log_warn "没有找到测试文件"
        fi
        ;;
        
    [Nn])
        log_info "已取消删除操作"
        ;;
        
    *)
        handle_y_n
        ;;
    esac
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    break_end
}

# 快速重命名功能
quick_rename() {
    clear
    echo -e "${gl_zi}>>> 快速重命名${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 支持的视频文件扩展名
    local VIDEO_EXTS=("mp4" "mkv" "avi" "mov" "wmv" "flv" "webm" "m4v" "mpg" "mpeg" "kvm")
    
    # 生成扩展名匹配字符串
    local ext_pattern=""
    for ext in "${VIDEO_EXTS[@]}"; do
        if [ -z "$ext_pattern" ]; then
            ext_pattern="-name \"*.$ext\""
        else
            ext_pattern="$ext_pattern -o -name \"*.$ext\""
        fi
    done
    
    # 收集文件
    log_info "扫描当前目录视频文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    local files=()
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            files+=("$file")
        fi
    done < <(eval "find . -maxdepth 1 -type f \( $ext_pattern \) 2>/dev/null" | sort -V)
    
    if [ ${#files[@]} -eq 0 ]; then
        log_error "未找到视频文件！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}请按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} ")" -n 1
        return
    fi
    
    echo -e "${gl_bai}找到 ${#files[@]} 个视频文件:${gl_bai}"
    for ((i=0; i<${#files[@]}; i++)); do
        local filename=$(basename -- "${files[$i]}")
        echo -e "  ${gl_bufan}$(safe_printf "%02d" $((i+1))).${gl_bai} $filename"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 询问重命名格式
    echo -e "${gl_bai}请选择重命名方式:${gl_bai}"
    echo -e "  ${gl_bufan}1.${gl_bai} 自动识别剧集编号并重命名"
    echo -e "  ${gl_bufan}2.${gl_bai} 手动输入前缀和起始集数"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    read -r -e -p "$(echo -e "${gl_bai}请输入你的选择 (${gl_huang}0${gl_bai}返回): ")" rename_method
    
    if [ "$rename_method" = "0" ]; then
        return
    fi
    
    case $rename_method in
    1)
        # 自动识别模式
        rename_tv_files_ultimate
        ;;
    2)
        # 手动模式
        clear
        echo -e "${gl_zi}>>> 手动重命名设置${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入剧集前缀: ")" prefix
        if [ -z "$prefix" ]; then
            log_error "剧集前缀不能为空！"
            echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
            break_end
            return
        fi
        
        read -r -e -p "$(echo -e "${gl_bai}请输入季号 (默认 ${gl_lv}01${gl_bai}): ")" season
        season="${season:-01}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入起始集数 (默认 ${gl_lv}1${gl_bai}): ")" start_ep
        start_ep="${start_ep:-1}"
        
        # 预览
        clear
        echo -e "${gl_zi}>>> 预览重命名结果${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}将重命名 ${#files[@]} 个文件:${gl_bai}"
        
        for ((i=0; i<${#files[@]}; i++)); do
            local file="${files[$i]}"
            local filename=$(basename -- "$file")
            local extension="${filename##*.}"
            local episode=$((start_ep + i))
            local formatted_ep=$(safe_printf "%02d" "$episode")
            local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"
            
            echo -e "  ${gl_hui}$filename${gl_bai}"
            echo -e "  ${gl_lv}→ $new_name${gl_bai}"
            echo ""
        done
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}确定要执行重命名吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm
        
        case "$confirm" in
        [Yy])
            log_info "开始重命名${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            local success_count=0
            
            for ((i=0; i<${#files[@]}; i++)); do
                local file="${files[$i]}"
                local filename=$(basename -- "$file")
                local extension="${filename##*.}"
                local episode=$((start_ep + i))
                local formatted_ep=$(safe_printf "%02d" "$episode")
                local new_name="${prefix}-S${season}E${formatted_ep}.${extension}"
                
                if mv -- "$file" "./$new_name" 2>/dev/null; then
                    echo -e "  ${gl_lv}✓ $filename → $new_name${gl_bai}"
                    ((success_count++))
                else
                    echo -e "  ${gl_hong}✗ 重命名失败: $filename${gl_bai}"
                fi
            done
            
            log_ok "重命名完成！成功 $success_count 个文件"
            ;;
            
        [Nn])
            log_info "已取消重命名操作"
            ;;
            
        *)
            log_error "无效的选择！"
            ;;
        esac
        
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        ;;
        
    *)
        log_error "无效的选择！"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        break_end
        return
        ;;
    esac
}

# 交互式移动视频文件函数
move_videos_interactive() {
    clear
    if [ -z "$(ls -A)" ]; then
        echo -e ""
        echo -e "${gl_zi}>>> 移动视频文件${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}当前目录 ${gl_lv}$(pwd) ${gl_huang}为空${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bai}按任意键返回${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
        read -r -n1 -s
         return
     fi
    local source_dir="$(pwd)"
    echo -e "${gl_huang}>>> 当前目录${gl_lv}${source_dir}${gl_huang}文件列表${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    # ls --color=auto -xA
    show_current_files
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e ""
    echo -e "${gl_zi}>>> 移动视频文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}将移动${gl_lv}${source_dir}${gl_huang}目录下的所有视频文件${gl_bai}"
    echo -e "${gl_lv}/vol2/1000/media/电视剧集/国产剧/xxx/Season 1${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 2. 询问目标目录
    while true; do
        read -r -e -p "$(echo -e "${gl_bai}请输入目标目录 (${gl_huang}0${gl_bai}返回): ")" target_dir
        
        # 检查是否返回
        if [ "$target_dir" = "0" ]; then
            log_info "操作已取消"
            return 0
        fi
        
        # 检查输入是否为空
        if [ -z "$target_dir" ]; then
            log_error "目标目录不能为空, 请重新输入"
            echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
            read -r -n 1 -s
            continue
        fi
        break
    done
    
    # 检查是否需要创建目录
    if [ ! -d "$target_dir" ]; then
        read -r -e -p "$(echo -e "${gl_bai}目录不存在, 是否创建? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" create_dir
        case "$create_dir" in
            [Yy])
                mkdir -p "$target_dir"
                if [ $? -ne 0 ]; then
                    log_error "创建目录失败！"
                    return 1
                fi
                log_ok "目录已创建: ${target_dir}"
                ;;
            [Nn]|"")
                log_error "操作取消: 目录不存在"
                return 1
                ;;
            *)
                handle_y_n
                return 1
                ;;
        esac
    else
        log_info "目标目录已存在: ${target_dir}"
    fi
    
    clear
    echo -e "${gl_huang}>>> 将移动${gl_lv}${source_dir}${gl_huang}目录下的所有视频文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 3. 扫描视频文件
    log_info "正在扫描视频文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
    
    # 视频文件扩展名数组
    local video_extensions=("mp4" "avi" "mkv" "mov" "wmv" "flv" "webm" 
                           "m4v" "mpg" "mpeg" "3gp" "mts" "m2ts" 
                           "ts" "vob" "ogg" "ogv" "divx" "f4v")
    
    local found_files=()
    local found_count=0
    
    # 查找视频文件
    for ext in "${video_extensions[@]}"; do
        while IFS= read -r -d '' file; do
            if [ -f "$file" ]; then
                found_files+=("$file")
                ((found_count++))
            fi
        done < <(find "$source_dir" -maxdepth 1 -type f -iname "*.$ext" -print0 2>/dev/null)
    done
    
    if [ $found_count -eq 0 ]; then
        log_warn "未找到任何视频文件"
        return 0
    fi
    
    # 显示找到的文件
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_huang}找到的文件${gl_bai}"
    
    for file in "${found_files[@]}"; do
        filename=$(basename "$file")
        echo -e "  ${gl_hui}${filename}${gl_bai}"
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_lv}共找到 ${gl_huang}${found_count} ${gl_lv}个视频文件${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 4. 确认移动
    read -r -e -p "$(echo -e "${gl_bai}确认移动到 '${gl_huang}${target_dir}${gl_bai}'目录吗? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" confirm_move
    case "$confirm_move" in
        [Yy])
            echo -e "${gl_bai}正在移动文件${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
            ;;
        [Nn]|"")
            log_info "操作已取消"
            return 0
            ;;
        *)
            handle_y_n
            return 1
            ;;
    esac
    
    # 5. 执行移动操作
    local moved_count=0
    local failed_count=0
    
    for file in "${found_files[@]}"; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            
            # 检查目标文件是否已存在
            if [ -f "$target_dir/$filename" ]; then
                log_warn "目标文件已存在, 跳过: ${filename}"
                ((failed_count++))
                continue
            fi
            
            # 移动文件
            if mv "$file" "$target_dir/" 2>/dev/null; then
                ((moved_count++))
                echo -e "  ${gl_lv}✓${gl_bai} 移动: ${filename}"
            else
                log_error "移动失败: ${filename}"
                ((failed_count++))
            fi
        fi
    done
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 6. 显示结果
    if [ $moved_count -gt 0 ]; then
        log_ok "移动完成!"
        echo -e "${gl_lv}移动成功: ${moved_count} 个文件${gl_bai}"
        echo -e "${gl_lan}目标目录: ${target_dir}${gl_bai}"
        
        if [ $failed_count -gt 0 ]; then
            echo -e "${gl_huang}移动失败: ${failed_count} 个文件${gl_bai}"
        fi
        
        # 询问是否打开目录
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        read -r -e -p "$(echo -e "${gl_bai}是否切换到目标目录? (${gl_lv}y${gl_bai}/${gl_hong}N${gl_bai}): ")" open_dir
        case "$open_dir" in
            [Yy])
                clear
                cd "$target_dir"
                local source_dir="$(pwd)"
                echo -e "${gl_huang}>>> 当前目录${gl_lv}${source_dir}${gl_huang}文件列表${gl_bai}"
                echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
                show_current_files
                ;;
        esac
    else
        log_error "没有文件被移动"
    fi
    
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    echo -e "${gl_bai}按任意键继续${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai} \c"
    read -r -n 1 -s
    clear
}

# 主菜单
main_menu() {
    while true; do
        clear
        echo -e "${gl_zi}>>> 刮削目录结构示例${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}庆余年/${gl_bai}                      ${gl_hui}<-- ${gl_lan}电视剧根目录${gl_hui} (可含年份：庆余年 (2024))${gl_bai}"
        echo -e "${gl_bufan}     ├──${gl_lv}Season 01/${gl_bai}           ${gl_hui}<-- ${gl_lan}第一季文件夹${gl_hui} (标准命名：Season XX)${gl_bai}"
        echo -e "${gl_bufan}     │   ├──${gl_huang}庆余年-S01E01.mkv${gl_bai}"
        echo -e "${gl_bufan}     │   ├──${gl_huang}庆余年-S01E02.mkv${gl_bai}"
        echo -e "${gl_bufan}     │   └──${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}     └──${gl_lv}Season 02/${gl_bai}           ${gl_hui}<-- ${gl_lan}第二季文件夹${gl_hui} (标准命名：Season XX)${gl_bai}"
        echo -e "${gl_bufan}         ├──${gl_huang}庆余年-S02E01.mkv${gl_bai}"
        echo -e "${gl_bufan}         ├──${gl_huang}庆余年-S02E02.mkv${gl_bai}"
        echo -e "${gl_bufan}         └──${gl_hong}.${gl_huang}.${gl_lv}.${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        local source_dir="$(pwd)"
        echo -e "${gl_huang}>>> 当前目录${gl_lv}${source_dir}${gl_huang}文件列表${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        # ls --color=auto -xA
        show_current_files
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e ""
        echo -e "${gl_zi}>>> 电视剧文件重命名终极版${gl_bai}"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_bufan}1.  ${gl_bai}快速重命名           ${gl_bufan}2.  ${gl_bai}详细重命名"
        echo -e "${gl_bufan}3.  ${gl_bai}创建测试文件         ${gl_bufan}4.  ${gl_bai}删除测试文件"
        echo -e "${gl_bufan}5.  ${gl_bai}移动视频文件         ${gl_bufan}6.  ${gl_bai}测试识别模式"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        echo -e "${gl_huang}0.  ${gl_bai}返回上一级选单       ${gl_hong}00. ${gl_bai}退出脚本"
        echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
        
        read -r -e -p "$(echo -e "${gl_bai}请输入你的选择: ")" choice
        
        case $choice in
        1) quick_rename ;;
        2) rename_tv_files_ultimate ;;
        3) create_mixed_test_files ;;
        4) delete_test_files ;;
        5) move_videos_interactive ;;
        6) test_all_recognition_modes ;;
        0) break ;; 
        00 | 000 | 0000) exit_script ;;
        *) handle_invalid_input ;;
        esac
    done
}

# 脚本入口
main() {
    clear
    echo -e "${gl_zi}=======================================${gl_bai}"
    echo -e "${gl_zi}  电视剧文件重命名终极版${gl_bai}"
    echo -e "${gl_zi}=======================================${gl_bai}"
    echo -e ""
    echo -e "${gl_bai}当前目录: ${gl_bufan}$(pwd)${gl_bai}"
    echo -e "${gl_bai}脚本版本: ${gl_bufan}4.0.0（终极版）${gl_bai}"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 检查所需命令
    if ! command -v find &> /dev/null; then
        log_error "缺少必要的命令: find"
        exit 1
    fi
    
    if ! command -v sort &> /dev/null; then
        log_error "缺少必要的命令: sort"
        exit 1
    fi
    
    echo -e "${gl_bai}主要功能:${gl_bai}"
    echo -e "  ${gl_bufan}•${gl_bai} 快速重命名 - 智能识别一键操作"
    echo -e "  ${gl_bufan}•${gl_bai} 专业模式 - 详细设置和高级功能"
    echo -e "  ${gl_bufan}•${gl_bai} 智能多模式识别（6种格式）"
    echo -e "  ${gl_bufan}•${gl_bai} 自动检测最佳重命名方案"
    echo -e "  ${gl_bufan}•${gl_bai} 详细模式分析和统计"
    echo -e "  ${gl_bufan}•${gl_bai} 识别准确率评估"
    echo -e "  ${gl_bufan}•${gl_bai} 批量测试识别模式"
    echo -e "${gl_bufan}————————————————————————————————————————————————${gl_bai}"
    
    # 进入主菜单
    main_menu
}

# 运行主函数
main