#!/bin/bash

# 设置工作目录
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 日志级别定义
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# 当前日志级别(默认为INFO)
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

# 日志颜色
LOG_COLOR_DEBUG="\033[0;37m"    # 灰色
LOG_COLOR_INFO="\033[0;32m"     # 绿色
LOG_COLOR_WARNING="\033[0;33m"  # 黄色
LOG_COLOR_ERROR="\033[0;31m"    # 红色
LOG_COLOR_FATAL="\033[1;31m"    # 亮红色
LOG_COLOR_RESET="\033[0m"       # 重置

# 增强版日志函数
function log() {
    local level=$1
    local message="${@:2}"
    local level_name=""
    local color=""
    
    # 根据级别设置参数
    case $level in
        $LOG_LEVEL_DEBUG)
            level_name="DEBUG"
            color=$LOG_COLOR_DEBUG
            ;;
        $LOG_LEVEL_INFO)
            level_name="INFO"
            color=$LOG_COLOR_INFO
            ;;
        $LOG_LEVEL_WARNING)
            level_name="WARNING"
            color=$LOG_COLOR_WARNING
            ;;
        $LOG_LEVEL_ERROR)
            level_name="ERROR"
            color=$LOG_COLOR_ERROR
            ;;
        $LOG_LEVEL_FATAL)
            level_name="FATAL"
            color=$LOG_COLOR_FATAL
            ;;
        *)
            level_name="UNKNOWN"
            color=$LOG_COLOR_RESET
            ;;
    esac
    
    # 检查日志级别
    if [ "$level" -ge "$CURRENT_LOG_LEVEL" ]; then
        # 获取调用函数名和行号
        local caller_info=""
        if [ "$level" -ge "$LOG_LEVEL_WARNING" ]; then
            caller_info="[$(caller 0 | awk '{print $2 ":" $1}')]"
        fi
        
        # 格式化时间戳
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
        
        # 输出日志
        echo -e "${color}[${timestamp}] [${level_name}]${caller_info} ${message}${LOG_COLOR_RESET}"
        
        # 如果是ERROR或FATAL级别，同时写入错误日志文件
        if [ "$level" -ge "$LOG_LEVEL_ERROR" ] && [ -n "$ERROR_LOG_FILE" ]; then
            echo "[${timestamp}] [${level_name}]${caller_info} ${message}" >> "$ERROR_LOG_FILE"
        fi
    fi
}

# 便捷日志函数
function log_debug() {
    log $LOG_LEVEL_DEBUG "$@"
}

function log_info() {
    log $LOG_LEVEL_INFO "$@"
}

function log_warning() {
    log $LOG_LEVEL_WARNING "$@"
}

function log_error() {
    log $LOG_LEVEL_ERROR "$@"
}

function log_fatal() {
    log $LOG_LEVEL_FATAL "$@"
    exit 1  # 致命错误自动退出
}

# 设置日志级别
function set_log_level() {
    case "${1,,}" in
        debug)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG
            ;;
        info)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
        warning)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING
            ;;
        error)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR
            ;;
        fatal)
            CURRENT_LOG_LEVEL=$LOG_LEVEL_FATAL
            ;;
        *)
            log_warning "未知日志级别: $1，使用默认级别(INFO)"
            CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO
            ;;
    esac
    
    log_info "日志级别设置为: $(get_log_level_name $CURRENT_LOG_LEVEL)"
}

# 获取日志级别名称
function get_log_level_name() {
    local level=$1
    case $level in
        $LOG_LEVEL_DEBUG)   echo "DEBUG" ;;
        $LOG_LEVEL_INFO)    echo "INFO" ;;
        $LOG_LEVEL_WARNING) echo "WARNING" ;;
        $LOG_LEVEL_ERROR)   echo "ERROR" ;;
        $LOG_LEVEL_FATAL)   echo "FATAL" ;;
        *)                  echo "UNKNOWN" ;;
    esac
}

# 初始化日志目录和文件
function init_logging() {
    local log_dir="${1:-$WORKSPACE/logs}"
    local error_log="${2:-$log_dir/errors.log}"
    
    # 创建日志目录
    mkdir -p "$log_dir"
    
    # 设置错误日志文件
    export ERROR_LOG_FILE="$error_log"
    
    # 清空错误日志
    > "$ERROR_LOG_FILE"
    
    log_info "日志系统初始化完成，错误日志: $ERROR_LOG_FILE"
}

# 日志文件轮转函数
function rotate_logs() {
    local log_file="$1"
    local max_size="${2:-10485760}"  # 默认10MB
    local max_backups="${3:-5}"      # 默认保留5个备份
    
    # 检查日志文件是否存在
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    # 获取文件大小
    local file_size=$(stat -c %s "$log_file")
    
    # 检查是否需要轮转
    if [ "$file_size" -gt "$max_size" ]; then
        log_debug "轮转日志文件: $log_file (大小: $file_size 字节)"
        
        # 删除最老的备份
        if [ -f "${log_file}.${max_backups}" ]; then
            rm -f "${log_file}.${max_backups}"
        fi
        
        # 将现有备份递增
        for ((i=max_backups-1; i>=1; i--)); do
            local j=$((i+1))
            if [ -f "${log_file}.${i}" ]; then
                mv "${log_file}.${i}" "${log_file}.${j}"
            fi
        done
        
        # 将当前日志备份为.1
        mv "$log_file" "${log_file}.1"
        
        # 创建新的空日志文件
        touch "$log_file"
        
        log_debug "日志文件轮转完成"
    fi
}

# SIP错误分类
function classify_sip_error() {
    local error_code=$1
    
    if [ -z "$error_code" ] || ! [[ "$error_code" =~ ^[0-9]+$ ]]; then
        echo "未知错误"
        return
    fi
    
    # 提取错误类别
    local category=${error_code:0:1}
    
    case $category in
        1)
            echo "信息性响应"
            ;;
        2)
            echo "成功响应"
            ;;
        3)
            echo "重定向响应"
            ;;
        4)
            echo "客户端错误"
            ;;
        5)
            echo "服务器错误"
            ;;
        6)
            echo "全局错误"
            ;;
        *)
            echo "未知错误类别"
            ;;
    esac
}

# SIP错误码描述
function get_sip_error_description() {
    local error_code=$1
    
    case $error_code in
        400) echo "错误请求" ;;
        401) echo "未授权" ;;
        403) echo "禁止" ;;
        404) echo "未找到" ;;
        408) echo "请求超时" ;;
        480) echo "暂时不可用" ;;
        486) echo "忙碌" ;;
        487) echo "请求终止" ;;
        500) echo "服务器内部错误" ;;
        503) echo "服务不可用" ;;
        504) echo "服务器超时" ;;
        *)   echo "SIP错误 $error_code" ;;
    esac
}

# 解析SIPp错误日志
function parse_sipp_error_log() {
    local error_log="$1"
    local output_file="${2:-${error_log}.analysis}"
    
    log_info "分析SIPp错误日志: $error_log"
    
    # 初始化计数器
    local total_errors=0
    declare -A error_counts
    
    # 创建输出文件
    > "$output_file"
    echo "SIPp错误分析报告" >> "$output_file"
    echo "生成时间: $(date '+%Y-%m-%d %H:%M:%S')" >> "$output_file"
    echo "----------------------------------------" >> "$output_file"
    
    # 读取和分析错误日志
    while IFS= read -r line; do
        # 检查是否包含SIP响应码
        if [[ "$line" =~ "SIP/2.0 "([0-9]{3}) ]]; then
            local error_code="${BASH_REMATCH[1]}"
            local error_class=$(classify_sip_error "$error_code")
            local error_desc=$(get_sip_error_description "$error_code")
            
            # 如果是4xx, 5xx或6xx，计数为错误
            if [[ "$error_code" =~ ^[4-6][0-9]{2}$ ]]; then
                ((total_errors++))
                
                # 增加特定错误码的计数
                if [ -z "${error_counts[$error_code]}" ]; then
                    error_counts[$error_code]=1
                else
                    ((error_counts[$error_code]++))
                fi
                
                # 记录详细信息到输出文件
                echo "错误: $error_code ($error_desc) - $line" >> "$output_file"
            fi
        elif [[ "$line" =~ "Unexpected message" ]]; then
            ((total_errors++))
            echo "未预期消息: $line" >> "$output_file"
        fi
    done < "$error_log"
    
    # 写入摘要信息
    echo "" >> "$output_file"
    echo "错误摘要:" >> "$output_file"
    echo "----------------------------------------" >> "$output_file"
    echo "总错误数: $total_errors" >> "$output_file"
    echo "" >> "$output_file"
    echo "按错误码统计:" >> "$output_file"
    
    for error_code in "${!error_counts[@]}"; do
        local count=${error_counts[$error_code]}
        local desc=$(get_sip_error_description "$error_code")
        local percentage=$(awk "BEGIN {printf \"%.2f\", ($count/$total_errors)*100}")
        
        echo "$error_code ($desc): $count 次 ($percentage%)" >> "$output_file"
    done
    
    log_info "错误分析完成，输出到: $output_file"
    
    # 如果错误数量超过阈值，发出警告
    if [ "$total_errors" -gt 100 ]; then
        log_warning "检测到大量错误 ($total_errors)，请查看分析报告: $output_file"
    fi
    
    return $total_errors
}

# 指数退避重试函数
function retry_with_backoff() {
    local cmd="$1"           # 要执行的命令
    local max_attempts="${2:-5}"   # 最大尝试次数(默认5次)
    local initial_wait="${3:-1}"   # 初始等待秒数(默认1秒)
    local max_wait="${4:-60}"      # 最大等待秒数(默认60秒)
    local timeout="${5:-0}"        # 命令超时时间(默认无超时)
    
    local attempt=1
    local wait=$initial_wait
    local result=0
    
    while [ $attempt -le $max_attempts ]; do
        log_debug "尝试执行命令(第$attempt/$max_attempts次): $cmd"
        
        # 执行命令，可选添加超时
        if [ $timeout -gt 0 ]; then
            timeout $timeout bash -c "$cmd"
            result=$?
        else
            eval "$cmd"
            result=$?
        fi
        
        # 检查结果
        if [ $result -eq 0 ]; then
            log_debug "命令执行成功"
            return 0
        fi
        
        # 计算下一次等待时间(指数退避)
        log_warning "命令执行失败(退出码:$result)，等待$wait秒后重试..."
        sleep $wait
        
        # 增加等待时间，但不超过最大值
        wait=$(( wait * 2 ))
        if [ $wait -gt $max_wait ]; then
            wait=$max_wait
        fi
        
        ((attempt++))
    done
    
    log_error "命令执行失败，已达到最大尝试次数($max_attempts)"
    return $result
}

# 处理SIPp常见错误
function handle_sipp_error() {
    local exit_code=$1
    local pid=$2
    local scenario_name="${3:-unknown}"
    
    case $exit_code in
        0)
            log_info "SIPp进程($scenario_name, PID:$pid)正常退出"
            return 0
            ;;
        1)
            log_error "SIPp进程($scenario_name, PID:$pid)出现至少一个错误调用"
            ;;
        97)
            log_error "SIPp进程($scenario_name, PID:$pid)出现内部错误"
            ;;
        99)
            log_error "SIPp进程($scenario_name, PID:$pid)由于未知消息而退出"
            ;;
        -15)
            log_warning "SIPp进程($scenario_name, PID:$pid)被终止信号中断"
            ;;
        *)
            log_error "SIPp进程($scenario_name, PID:$pid)未知退出码: $exit_code"
            ;;
    esac
    
    # 尝试获取更多错误信息
    if [ -f "$WORKSPACE/logs/*/sipp_*_errors.log" ]; then
        log_info "分析错误日志以获取更多信息..."
        local latest_error_log=$(ls -t "$WORKSPACE/logs/*/sipp_*_errors.log" | head -1)
        if [ -n "$latest_error_log" ]; then
            parse_sipp_error_log "$latest_error_log"
        fi
    fi
    
    return $exit_code
}

# 检查SIPp场景是否存在问题
function validate_sipp_scenario() {
    local scenario_file="$1"
    
    log_info "验证SIPp场景文件: $scenario_file"
    
    if [ ! -f "$scenario_file" ]; then
        log_error "场景文件不存在: $scenario_file"
        return 1
    fi
    
    # 检查XML语法 (如果xmllint可用)
    if command -v xmllint &> /dev/null; then
        xmllint --noout "$scenario_file" 2>/dev/null
        if [ $? -ne 0 ]; then
            log_error "场景文件XML语法错误: $scenario_file"
            xmllint --noout "$scenario_file"  # 显示详细错误
            return 2
        fi
    else
        log_warning "xmllint命令不可用，跳过XML语法检查"
    fi
    
    # 检查常见问题
    local issues=0
    
    # 检查是否有recv但没有timeout属性
    if grep -q "<recv" "$scenario_file" && ! grep -q "<recv.*timeout=" "$scenario_file"; then
        log_warning "场景文件中的recv元素没有指定timeout属性，可能导致永久挂起"
        ((issues++))
    fi
    
    # 检查是否有send但没有retrans属性
    if grep -q "<send" "$scenario_file" && ! grep -q "<send.*retrans=" "$scenario_file"; then
        log_warning "场景文件中的send元素没有指定retrans属性，可能影响可靠性"
        ((issues++))
    fi
    
    if [ $issues -gt 0 ]; then
        log_warning "场景文件存在$issues个潜在问题，但仍然可用"
    else
        log_info "场景文件验证通过"
    fi
    
    return 0
}

# 初始化错误统计
function init_error_stats() {
    # 创建统计文件
    ERROR_STATS_FILE="${WORKSPACE}/logs/error_stats.csv"
    > "$ERROR_STATS_FILE"
    
    # 添加CSV头
    echo "时间戳,错误类型,错误码,描述,场景,详情" >> "$ERROR_STATS_FILE"
    
    log_debug "错误统计初始化完成: $ERROR_STATS_FILE"
}

# 记录错误统计
function record_error() {
    local error_type="$1"
    local error_code="$2"
    local description="$3"
    local scenario="$4"
    local details="$5"
    
    # 检查统计文件是否已初始化
    if [ -z "$ERROR_STATS_FILE" ] || [ ! -f "$ERROR_STATS_FILE" ]; then
        init_error_stats
    fi
    
    # 添加错误记录
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "\"$timestamp\",\"$error_type\",\"$error_code\",\"$description\",\"$scenario\",\"$details\"" >> "$ERROR_STATS_FILE"
    
    # 同时记录到日志
    log_error "[$error_type] $description ($error_code) - $details"
}

# 生成错误统计报告
function generate_error_report() {
    local stats_file="${1:-$ERROR_STATS_FILE}"
    local output_file="${2:-${stats_file%.csv}_report.html}"
    
    log_info "生成错误统计报告: $output_file"
    
    if [ ! -f "$stats_file" ]; then
        log_error "错误统计文件不存在: $stats_file"
        return 1
    fi
    
    # 计算错误分布
    declare -A type_count
    declare -A code_count
    declare -A scenario_count
    
    # 跳过标题行
    local total_errors=0
    tail -n +2 "$stats_file" | while IFS=, read -r timestamp error_type error_code description scenario details; do
        # 处理CSV格式
        error_type=$(echo $error_type | tr -d '"')
        error_code=$(echo $error_code | tr -d '"')
        scenario=$(echo $scenario | tr -d '"')
        
        # 增加计数
        ((total_errors++))
        
        if [ -z "${type_count[$error_type]}" ]; then
            type_count[$error_type]=1
        else
            ((type_count[$error_type]++))
        fi
        
        if [ -z "${code_count[$error_code]}" ]; then
            code_count[$error_code]=1
        else
            ((code_count[$error_code]++))
        fi
        
        if [ -z "${scenario_count[$scenario]}" ]; then
            scenario_count[$scenario]=1
        else
            ((scenario_count[$scenario]++))
        fi
    done
    
    # 生成HTML报告
    cat > "$output_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="UTF-8">
    <title>SIPp错误统计报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #2c3e50; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .chart { width: 100%; height: 300px; margin: 20px 0; }
        .error { color: #e74c3c; }
        .warning { color: #f39c12; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>SIPp错误统计报告</h1>
    <p>生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
    <p>总错误数: $total_errors</p>
    
    <h2>错误类型分布</h2>
    <div class="chart">
        <canvas id="errorTypeChart"></canvas>
    </div>
    
    <h2>错误码分布</h2>
    <div class="chart">
        <canvas id="errorCodeChart"></canvas>
    </div>
    
    <h2>场景分布</h2>
    <div class="chart">
        <canvas id="scenarioChart"></canvas>
    </div>
    
    <h2>详细错误列表</h2>
    <table>
        <tr>
            <th>时间</th>
            <th>错误类型</th>
            <th>错误码</th>
            <th>描述</th>
            <th>场景</th>
            <th>详情</th>
        </tr>
EOF
    
    # 添加详细错误记录
    tail -n +2 "$stats_file" | while IFS=, read -r timestamp error_type error_code description scenario details; do
        timestamp=$(echo $timestamp | tr -d '"')
        error_type=$(echo $error_type | tr -d '"')
        error_code=$(echo $error_code | tr -d '"')
        description=$(echo $description | tr -d '"')
        scenario=$(echo $scenario | tr -d '"')
        details=$(echo $details | tr -d '"')
        
        cat >> "$output_file" << EOF
        <tr>
            <td>$timestamp</td>
            <td>$error_type</td>
            <td>$error_code</td>
            <td>$description</td>
            <td>$scenario</td>
            <td>$details</td>
        </tr>
EOF
    done
    
    # 完成HTML文件
    cat >> "$output_file" << EOF
    </table>
    
    <script>
        // 错误类型图表
        const typeCtx = document.getElementById('errorTypeChart').getContext('2d');
        new Chart(typeCtx, {
            type: 'pie',
            data: {
                labels: [${!type_count[@]}],
                datasets: [{
                    data: [${type_count[@]}],
                    backgroundColor: [
                        '#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6',
                        '#e67e22', '#1abc9c', '#34495e', '#d35400', '#c0392b'
                    ]
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: '错误类型分布'
                    }
                }
            }
        });
        
        // 错误码图表
        const codeCtx = document.getElementById('errorCodeChart').getContext('2d');
        new Chart(codeCtx, {
            type: 'bar',
            data: {
                labels: [${!code_count[@]}],
                datasets: [{
                    label: '错误次数',
                    data: [${code_count[@]}],
                    backgroundColor: '#3498db'
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: '错误码分布'
                    }
                }
            }
        });
        
        // 场景图表
        const scenarioCtx = document.getElementById('scenarioChart').getContext('2d');
        new Chart(scenarioCtx, {
            type: 'doughnut',
            data: {
                labels: [${!scenario_count[@]}],
                datasets: [{
                    data: [${scenario_count[@]}],
                    backgroundColor: [
                        '#2ecc71', '#e74c3c', '#3498db', '#f39c12', '#9b59b6',
                        '#e67e22', '#1abc9c', '#34495e', '#d35400', '#c0392b'
                    ]
                }]
            },
            options: {
                responsive: true,
                plugins: {
                    title: {
                        display: true,
                        text: '场景分布'
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log_info "错误报告已生成: $output_file"
    return 0
}

# 创建用户数据CSV文件
function create_csv() {
    local csv_file="$1"
    local user_count="$2"
    local auth_type="${3:-none}"
    local start_imsi="${4:-462200000000000}"
    local start_msisdn="${5:-220000}"
    
    log_info "创建用户数据CSV文件: $csv_file (用户数量: $user_count, 认证类型: $auth_type)"
    
    # 创建目录（如果不存在）
    mkdir -p "$(dirname "$csv_file")"
    
    # 清空CSV文件
    > "$csv_file"
    
    # 添加CSV文件头
    echo "SEQUENTIAL" > "$csv_file"
    
    # 生成用户数据
    for ((i=1; i<=user_count; i++)); do
        # 生成IMSI (15位数字，MCC=460, MNC=01)
        local imsi=$((start_imsi + i))
        
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
        local msisdn=$((start_msisdn + i))
        
        # 根据认证类型生成不同格式的CSV行
        if [[ "$auth_type" == "ipsec" ]]; then
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn" >> "$csv_file"
        else
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn" >> "$csv_file"
        fi
    done
    
    log_info "用户数据CSV文件创建完成: $csv_file"
}

# 更新CSV文件中的服务器端口
function update_server_port() {
    local csv_file="$1"
    local imsi="$2"
    local new_port="$3"
    
    log_info "更新用户 IMSI:$imsi 的服务器端口为 $new_port"
    
    # 检查CSV文件是否存在
    if [[ ! -f "$csv_file" ]]; then
        log_error "错误: CSV文件不存在: $csv_file"
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
            log_info "已更新用户 IMSI:$imsi 的服务器端口为 $new_port"
        else
            # 保持原行不变
            echo "$line" >> "$temp_file"
        fi
    done < "$csv_file"
    
    # 替换原文件
    mv "$temp_file" "$csv_file"
    
    log_info "CSV文件更新完成: $csv_file"
    return 0
}

# 设置IPSec
function setup_ipsec() {
    local csv_file="$1"
    local local_ip="$2"
    local remote_ip="$3"
    local count=0
    
    log_info "设置IPSec (本地IP: $local_ip, 远端IP: $remote_ip)" >&2
    
    if [[ ! -f "$csv_file" ]]; then
        log_error "错误: CSV文件不存在: $csv_file" >&2
        echo 0
        return 1
    fi
    
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        if [[ -z "$imsi" || "$imsi" == "SEQUENTIAL" ]]; then
            continue
        fi
        log_info "为用户 IMSI:$imsi MSISDN:$msisdn 设置IPSec SA" >&2
        
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
        
        count=$((count+1))
    done < "$csv_file"

    log_info "IPSec设置完成" >&2
    echo $count
    return 0
}

# 清理进程
function cleanup() {
    log_info "清理进程..."
    
    # 终止所有SIPp进程
    pkill -f "sipp -sf" || true
    
    # 确保没有残留的SIPp进程
    for pid in $(pgrep -f "sipp.*-p $INITIAL_PORT"); do
        log_warning "发现残留的SIPp进程(PID: $pid)，强制终止"
        kill -9 $pid 2>/dev/null || true
    done
    
    # 等待端口释放
    for i in {1..5}; do
        if ! netstat -tuln | grep -q ":$INITIAL_PORT "; then
            break
        fi
        log_info "等待端口 $INITIAL_PORT 释放... ($i)"
        sleep 2
    done
    
    # 清理其他资源监控进程
    if [ -f "test_suite/pids/resource_monitor.pid" ]; then
        kill $(cat "test_suite/pids/resource_monitor.pid") 2>/dev/null || true
    fi
    
    log_info "清理完成"
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

# 资源监控函数
function monitor_resources() {
    local pid="$1"       # 要监控的进程PID
    local interval="$2"  # 监控间隔(秒)
    local log_file="$3"  # 日志文件
    local max_cpu="$4"   # CPU使用率阈值(%)
    local max_mem="$5"   # 内存使用率阈值(%)
    local max_fd="$6"    # 文件描述符阈值
    
    # 设置默认值
    interval=${interval:-5}
    log_file=${log_file:-"$WORKSPACE/logs/resource_monitor.log"}
    max_cpu=${max_cpu:-90}
    max_mem=${max_mem:-80}
    max_fd=${max_fd:-1000}
    
    # 创建日志目录
    mkdir -p "$(dirname "$log_file")"
    
    log_info "启动资源监控(PID: $pid, 间隔: ${interval}s, 日志: $log_file)"
    
    # 记录监控头信息
    echo "时间戳,PID,CPU(%),内存(%),文件描述符数,负载,警告" > "$log_file"
    
    # 后台运行监控循环
    (
        while kill -0 $pid 2>/dev/null; do
            # 获取当前时间戳
            local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
            
            # 获取CPU使用率(%)
            local cpu_usage=$(ps -p $pid -o %cpu= | tr -d ' ')
            
            # 获取内存使用率(%)
            local mem_usage=$(ps -p $pid -o %mem= | tr -d ' ')
            
            # 获取文件描述符数量
            local fd_count=$(ls -l /proc/$pid/fd 2>/dev/null | wc -l)
            
            # 获取系统负载
            local load_avg=$(cat /proc/loadavg | awk '{print $1}')
            
            # 检查是否超过阈值
            local warning=""
            if (( $(echo "$cpu_usage > $max_cpu" | bc -l) )); then
                warning="CPU超过阈值"
                log_warning "警告: PID $pid CPU使用率($cpu_usage%) 超过阈值($max_cpu%)"
            fi
            
            if (( $(echo "$mem_usage > $max_mem" | bc -l) )); then
                warning="${warning:+$warning; }内存超过阈值"
                log_warning "警告: PID $pid 内存使用率($mem_usage%) 超过阈值($max_mem%)"
            fi
            
            if [ "$fd_count" -gt "$max_fd" ]; then
                warning="${warning:+$warning; }文件描述符超过阈值"
                log_warning "警告: PID $pid 文件描述符($fd_count) 超过阈值($max_fd)"
            fi
            
            # 写入日志
            echo "$timestamp,$pid,$cpu_usage,$mem_usage,$fd_count,$load_avg,\"$warning\"" >> "$log_file"
            
            sleep $interval
        done
        
        log_info "进程 $pid 不再存在，资源监控已停止"
    ) &
    
    # 返回监控进程的PID
    echo $!
}

# 自动清理函数 - 当资源超过阈值时执行
function auto_cleanup_resources() {
    local pid="$1"        # 主进程PID
    local monitor_pid="$2" # 监控进程PID
    local max_cpu="$3"    # CPU阈值(%)
    local max_mem="$4"    # 内存阈值(%)
    local max_fd="$5"     # 文件描述符阈值
    
    # 设置默认阈值
    max_cpu=${max_cpu:-95}
    max_mem=${max_mem:-90}
    max_fd=${max_fd:-4000}
    
    log_info "启动自动资源清理(PID: $pid, 监控PID: $monitor_pid)"
    
    # 后台监控并清理
    (
        while kill -0 $pid 2>/dev/null && kill -0 $monitor_pid 2>/dev/null; do
            # 获取CPU使用率
            local cpu_usage=$(ps -p $pid -o %cpu= | tr -d ' ')
            
            # 获取内存使用率
            local mem_usage=$(ps -p $pid -o %mem= | tr -d ' ')
            
            # 获取文件描述符数量
            local fd_count=$(ls -l /proc/$pid/fd 2>/dev/null | wc -l)
            
            # 检查是否需要清理
            local need_cleanup=false
            
            if (( $(echo "$cpu_usage > $max_cpu" | bc -l) )); then
                log_fatal "严重警告: CPU使用率($cpu_usage%) 超过临界阈值($max_cpu%)，触发自动清理"
                need_cleanup=true
            fi
            
            if (( $(echo "$mem_usage > $max_mem" | bc -l) )); then
                log_fatal "严重警告: 内存使用率($mem_usage%) 超过临界阈值($max_mem%)，触发自动清理"
                need_cleanup=true
            fi
            
            if [ "$fd_count" -gt "$max_fd" ]; then
                log_fatal "严重警告: 文件描述符($fd_count) 超过临界阈值($max_fd)，触发自动清理"
                need_cleanup=true
            fi
            
            # 执行清理操作
            if $need_cleanup; then
                log "执行自动资源清理..."
                
                # 1. 向进程发送SIGUSR1信号（SIPp中用于停止流量生成）
                kill -SIGUSR1 $pid 2>/dev/null
                log "已发送SIGUSR1信号到PID $pid"
                
                # 2. 等待短暂时间让信号生效
                sleep 5
                
                # 3. 如果资源仍然超过阈值，发送终止信号
                local current_cpu=$(ps -p $pid -o %cpu= | tr -d ' ')
                if (( $(echo "$current_cpu > $max_cpu" | bc -l) )); then
                    log "资源使用仍然过高，发送终止信号..."
                    kill -TERM $pid 2>/dev/null
                    
                    # 等待进程终止
                    local wait_count=0
                    while kill -0 $pid 2>/dev/null && [ $wait_count -lt 10 ]; do
        sleep 1
                        ((wait_count++))
                    done
                    
                    # 如果进程仍然存在，强制终止
                    if kill -0 $pid 2>/dev/null; then
                        log "进程未能正常终止，强制终止..."
                        kill -9 $pid 2>/dev/null
                    fi
                    
                    log "清理完成，退出监控"
                    exit 0
                fi
                
                log "资源使用已下降，继续监控"
            fi
            
            sleep 10
        done
        
        log "主进程或监控进程已终止，退出自动清理"
    ) &
    
    # 返回清理进程的PID
    echo $!
}

# 生成资源使用报告
function generate_resource_report() {
    local log_file="$1"
    local report_file="$2"
    
    # 默认报告文件
    report_file=${report_file:-"${log_file%.log}_report.html"}
    
    log "生成资源使用报告: $report_file"
    
    # 创建报告目录
    mkdir -p "$(dirname "$report_file")"
    
    # 生成报告头部
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta charset="UTF-8">
    <title>SIPp资源使用报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #2c3e50; }
        table { border-collapse: collapse; width: 100%; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .warning { color: #e74c3c; font-weight: bold; }
        .chart { width: 100%; height: 400px; margin: 20px 0; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>SIPp资源使用报告</h1>
    <p>生成时间: $(date '+%Y-%m-%d %H:%M:%S')</p>
    
    <h2>资源使用摘要</h2>
    <div class="chart">
        <canvas id="resourceChart"></canvas>
    </div>
    
    <h2>详细数据</h2>
    <table>
        <tr>
            <th>时间</th>
            <th>PID</th>
            <th>CPU(%)</th>
            <th>内存(%)</th>
            <th>文件描述符</th>
            <th>系统负载</th>
            <th>警告</th>
        </tr>
EOF
    
    # 解析日志文件并添加数据行
    local timestamps=()
    local cpu_data=()
    local mem_data=()
    local fd_data=()
    
    # 跳过标题行
    local first_line=true
    
    while IFS=',' read -r timestamp pid cpu mem fd load warning; do
        # 跳过标题行
        if $first_line; then
            first_line=false
            continue
        fi
        
        # 添加表格行
        echo "<tr>" >> "$report_file"
        echo "  <td>$timestamp</td>" >> "$report_file"
        echo "  <td>$pid</td>" >> "$report_file"
        echo "  <td>$cpu</td>" >> "$report_file"
        echo "  <td>$mem</td>" >> "$report_file"
        echo "  <td>$fd</td>" >> "$report_file"
        echo "  <td>$load</td>" >> "$report_file"
        
        if [ -n "$warning" ] && [ "$warning" != "\"\"" ]; then
            echo "  <td class=\"warning\">$warning</td>" >> "$report_file"
        else
            echo "  <td></td>" >> "$report_file"
        fi
        
        echo "</tr>" >> "$report_file"
        
        # 收集图表数据
        timestamps+=("\"$timestamp\"")
        cpu_data+=("$cpu")
        mem_data+=("$mem")
        fd_data+=("$fd")
    done < "$log_file"
    
    # 完成表格
    echo "</table>" >> "$report_file"
    
    # 添加图表JavaScript
    cat >> "$report_file" << EOF
    <script>
        // 解析数据
        const timestamps = [${timestamps[@]}];
        const cpuData = [${cpu_data[@]}];
        const memData = [${mem_data[@]}];
        const fdData = [${fd_data[@]}];
        
        // 创建图表
        const ctx = document.getElementById('resourceChart').getContext('2d');
        const chart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: timestamps,
                datasets: [
                    {
                        label: 'CPU使用率(%)',
                        data: cpuData,
                        borderColor: 'rgba(255, 99, 132, 1)',
                        backgroundColor: 'rgba(255, 99, 132, 0.2)',
                        tension: 0.1
                    },
                    {
                        label: '内存使用率(%)',
                        data: memData,
                        borderColor: 'rgba(54, 162, 235, 1)',
                        backgroundColor: 'rgba(54, 162, 235, 0.2)',
                        tension: 0.1
                    },
                    {
                        label: '文件描述符(缩放后)',
                        data: fdData.map(fd => fd / 100), // 缩放以适应图表
                        borderColor: 'rgba(75, 192, 192, 1)',
                        backgroundColor: 'rgba(75, 192, 192, 0.2)',
                        tension: 0.1
                    }
                ]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    </script>
</body>
</html>
EOF
    
    log "资源使用报告已生成: $report_file"
}

# 设置退出时的清理
trap cleanup EXIT 

# 检查工具依赖
function check_dependencies() {
    local required_tools=("$@")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            log_warning "缺少依赖工具: $tool"
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warning "以下依赖工具不可用: ${missing_tools[*]}"
        return 1
    fi
    
    log_info "所有依赖工具都可用"
    return 0
} 