#!/bin/bash

# 设置工作目录
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 日志函数
function log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# 创建用户数据CSV文件
function create_csv() {
    local csv_file="$1"
    local user_count="$2"
    local auth_type="${3:-none}"
    
    log "创建用户数据CSV文件: $csv_file (用户数量: $user_count, 认证类型: $auth_type)"
    
    # 创建目录（如果不存在）
    mkdir -p "$(dirname "$csv_file")"
    
    # 清空CSV文件
    > "$csv_file"
    
    # 添加CSV文件头
    echo "SEQUENTIAL" > "$csv_file"
    
    # 生成用户数据
    for ((i=1; i<=user_count; i++)); do
        # 生成IMSI (15位数字，MCC=460, MNC=01)
        local imsi=$((460119000000000 + i))
        
        # 生成域名
        local domain="ims.mnc011.mcc460.3gppnetwork.org"
        
        # 生成IPSec认证参数（如果需要）
        local client_spi="0x$(openssl rand -hex 4)"
        local server_spi="0x$(openssl rand -hex 4)"
        
        # 服务端端口，默认为5060
        local server_port="5060"
        
        # 生成认证密钥（如果需要）
        local k="31323334353637383930313233343536"
        local op="19DF73C9C56A90EE581D52F1EBD53E72"
        local amf="8000"
        
        # 确定角色（奇数为UAS，偶数为UAC）
        local role
        if ((i % 2 == 1)); then
            role="uas"
        else
            role="uac"
        fi
        
        # 生成MSISDN（手机号，支持更大范围）
        local msisdn=$((600000 + i))
        
        # 根据认证类型生成不同格式的CSV行
        if [[ "$auth_type" == "ipsec" ]]; then
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn" >> "$csv_file"
        else
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn" >> "$csv_file"
        fi
    done
    
    log "用户数据CSV文件创建完成: $csv_file"
}

# 更新CSV文件中的服务器端口
function update_server_port() {
    local csv_file="$1"
    local imsi="$2"
    local new_port="$3"
    
    log "更新用户 IMSI:$imsi 的服务器端口为 $new_port"
    
    # 检查CSV文件是否存在
    if [[ ! -f "$csv_file" ]]; then
        log "错误: CSV文件不存在: $csv_file"
        return 1
    fi
    
    # 创建临时文件
    local temp_file="${csv_file}.tmp"
    
    # 读取CSV文件并更新指定IMSI的服务器端口
    while IFS=';' read -r line; do
        if [[ "$line" == "SEQUENTIAL" ]]; then
            echo "$line" > "$temp_file"
            continue
        fi
        
        # 解析CSV行
        local csv_imsi=$(echo "$line" | cut -d';' -f1)
        
        if [[ "$csv_imsi" == "$imsi" ]]; then
            # 更新服务器端口
            local domain=$(echo "$line" | cut -d';' -f2)
            local client_spi=$(echo "$line" | cut -d';' -f3)
            local server_spi=$(echo "$line" | cut -d';' -f4)
            local k=$(echo "$line" | cut -d';' -f6)
            local op=$(echo "$line" | cut -d';' -f7)
            local amf=$(echo "$line" | cut -d';' -f8)
            local role=$(echo "$line" | cut -d';' -f9)
            local msisdn=$(echo "$line" | cut -d';' -f10)
            
            # 构建新行
            echo "$imsi;$domain;$client_spi;$server_spi;$new_port;$k;$op;$amf;$role;$msisdn" >> "$temp_file"
            log "已更新用户 IMSI:$imsi 的服务器端口为 $new_port"
        else
            # 保持原行不变
            echo "$line" >> "$temp_file"
        fi
    done < "$csv_file"
    
    # 替换原文件
    mv "$temp_file" "$csv_file"
    
    log "CSV文件更新完成: $csv_file"
    return 0
}

# 设置IPSec
function setup_ipsec() {
    local csv_file="$1"
    local local_ip="$2"
    local remote_ip="$3"
    
    log "设置IPSec (本地IP: $local_ip, 远端IP: $remote_ip)"
    
    # 检查CSV文件是否存在
    if [[ ! -f "$csv_file" ]]; then
        log "错误: CSV文件不存在: $csv_file"
        return 1
    fi
    
    # 读取CSV文件并设置IPSec
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        # 跳过标题行或空行
        if [[ -z "$imsi" || "$imsi" == "SEQUENTIAL" ]]; then
            continue
        fi
        
        # 设置IPSec SA
        log "为用户 IMSI:$imsi MSISDN:$msisdn 设置IPSec SA"
        
        # 删除现有的IPSec策略（如果存在）
        ip xfrm policy flush
        ip xfrm state flush
        
        # 设置出站SA
        ip xfrm state add src "$local_ip" dst "$remote_ip" proto esp spi "$client_spi" \
            enc "aes" "$k" auth "sha1" "$op" mode transport
        
        # 设置入站SA
        ip xfrm state add src "$remote_ip" dst "$local_ip" proto esp spi "$server_spi" \
            enc "aes" "$k" auth "sha1" "$op" mode transport
        
        # 设置出站策略
        ip xfrm policy add src "$local_ip" dst "$remote_ip" dir out \
            tmpl src "$local_ip" dst "$remote_ip" proto esp spi "$client_spi" mode transport
        
        # 设置入站策略
        ip xfrm policy add src "$remote_ip" dst "$local_ip" dir in \
            tmpl src "$remote_ip" dst "$local_ip" proto esp spi "$server_spi" mode transport
        
        # 只设置第一个用户的IPSec（用于测试）
        break
    done < "$csv_file"
    
    log "IPSec设置完成"
}

# 清理进程
function cleanup() {
    log "清理进程..."
    
    # 杀死所有SIPp进程
    pkill -9 -f "sipp" 2>/dev/null || true
    
    # 清理IPSec策略和状态
    ip xfrm policy flush 2>/dev/null || true
    ip xfrm state flush 2>/dev/null || true
    
    log "清理完成"
}

# 显示使用方法
function show_usage() {
    local script_name="$1"
    local usage_text="$2"
    
    echo "使用方法: $script_name [选项]"
    echo "选项:"
    echo "$usage_text"
    echo "  --help                显示此帮助信息"
}

# 设置退出时的清理
trap cleanup EXIT 