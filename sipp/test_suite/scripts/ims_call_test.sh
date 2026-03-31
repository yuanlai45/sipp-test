#!/bin/bash

# 导入公共函数库
source "$(dirname "$0")/ims_common.sh"

# 设置调试日志文件
DEBUG_LOG_FILE="test_suite/logs/call_test/debug.log"

# 在脚本开头添加全局变量声明
declare -g UAC_USERS=0
declare -g UAS_USERS=0

# 调试日志函数
debug_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] DEBUG: $*" | tee -a "$DEBUG_LOG_FILE"
}

# 确保日志目录存在
mkdir -p "$(dirname "$DEBUG_LOG_FILE")"
# 清空旧的调试日志
> "$DEBUG_LOG_FILE"

# 显示使用方法
usage() {
    echo "使用方法: $0 [选项]"
    echo "选项:"
    echo "  --local-ip <本地IP>         本地IP地址"
    echo "  --remote-ip <远端IP:端口>   远端IP地址和端口"
    echo "  --initial-port <端口>  初始SIPp端口起始值"
    echo "  --users <用户数量>          用户数量"
    echo "  --rate <呼叫速率>           呼叫速率（每秒呼叫数）"
    echo "  --duration <测试时长>       测试持续时间（秒）"
    echo "  --call-hold <通话保持时间>  通话保持时间（秒）"
    echo "  --call-wait <接听等待时间>  接听等待时间（秒）"
    echo "  --call-again <是否再次呼叫> 是否在通话结束后再次发起呼叫（0或1）"
    echo "  --csv-file <CSV文件路径>    用户数据CSV文件路径"
    echo "  --auth <认证方式>           认证方式（none, ipsec, digest）"
    echo "  --help                      显示此帮助信息"
}

# 默认参数
LOCAL_IP=""
REMOTE_IP=""
INITIAL_PORT=5060
USERS=1
RATE=1
DURATION=60000
CALL_HOLD_TIME=5000
CALL_WAIT_TIME=1000
CALL_AGAIN=0
CSV_FILE=""
AUTH="none"

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local-ip)
            LOCAL_IP="$2"
            shift 2
            ;;
        --remote-ip)
            REMOTE_IP="$2"
            shift 2
            ;;
        --initial-port)
            INITIAL_PORT="$2"
            shift 2
            ;;
        --users)
            USERS="$2"
            shift 2
            ;;
        --rate)
            RATE="$2"
            shift 2
            ;;
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --call-hold)
            CALL_HOLD_TIME="$2"
            shift 2
            ;;
        --call-wait)
            CALL_WAIT_TIME="$2"
            shift 2
            ;;
        --call-again)
            CALL_AGAIN="$2"
            shift 2
            ;;
        --csv-file)
            CSV_FILE="$2"
            shift 2
            ;;
        --auth)
            AUTH="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            usage
            exit 1
            ;;
    esac
done

# 检查必要参数
if [[ -z "$LOCAL_IP" || -z "$REMOTE_IP" ]]; then
    echo "错误: 必须指定本地IP和远端IP"
    usage
    exit 1
fi

# 检查CSV文件是否存在
if [[ -z "$CSV_FILE" ]]; then
    # 如果未指定CSV文件，则创建一个
    CSV_FILE="$WORKSPACE/config/users_data.csv"
    create_csv "$CSV_FILE" "$USERS" "$AUTH"
elif [[ ! -f "$CSV_FILE" ]]; then
    echo "错误: CSV文件 $CSV_FILE 不存在"
    exit 1
fi

# 从CSV文件中提取UAC和UAS用户
function extract_users_from_csv() {
    local csv_file="$1"
    local uac_csv="$WORKSPACE/config/uac_users.csv"
    local uas_csv="$WORKSPACE/config/uas_users.csv"
    
    # 清空现有文件
    > "$uac_csv"
    > "$uas_csv"
    
    # 添加CSV文件头
    echo "SEQUENTIAL" > "$uac_csv"
    echo "SEQUENTIAL" > "$uas_csv"
    
    # 首先计算总用户数（减去标题行）
    local total_users=$(($(wc -l < "$csv_file") - 1))
    # 计算UAC和UAS用户数
    local uac_count=$((total_users / 2))
    local uas_count=$((total_users - uac_count))
    
    # 临时存储所有用户数据
    local temp_file=$(mktemp)
    tail -n +2 "$csv_file" > "$temp_file"
    
    # 创建临时文件存储UAS用户
    local temp_uas_file=$(mktemp)
    tail -n "$uas_count" "$temp_file" > "$temp_uas_file"
    
    # 处理UAS用户并收集msisdn
    declare -a uas_msisdns
    local line_num=0
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;uas;$msisdn" >> "$uas_csv"
        uas_msisdns[$line_num]="$msisdn"
        ((line_num++))
    done < "$temp_uas_file"
    
    # 处理UAC用户
    line_num=0
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        if [ $line_num -lt $uac_count ]; then
            local called_number="${uas_msisdns[$line_num]}"
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;uac;$msisdn;$called_number" >> "$uac_csv"
            ((line_num++))
        fi
    done < "$temp_file"
    
    # 清理临时文件
    rm -f "$temp_file" "$temp_uas_file"
    
    # 计算最终的UAC和UAS用户数量（减去标题行）
    UAC_USERS=$(($(wc -l < "$uac_csv") - 1))
    UAS_USERS=$(($(wc -l < "$uas_csv") - 1))
    
    echo "从CSV文件中提取了 $UAC_USERS 个UAC用户和 $UAS_USERS 个UAS用户" >&2
    
    # 返回格式修改为: "uac_csv_path uas_csv_path uac_count uas_count"
    echo "$uac_csv $uas_csv $UAC_USERS $UAS_USERS"
}

# 启动UAS注册实例
function start_uas_register_instance() {
    local uas_csv="$1"
    local port="$2"
    local uas_count="$3"
    
    # 创建日志目录
    mkdir -p "$WORKSPACE/logs/register_test/uas"
    
    # 使用setsid创建新的进程组运行sipp，重定向所有输出
    setsid sipp -sf "$WORKSPACE/scenarios/ims_register_basic.xml" \
         -oocsf "$WORKSPACE/scenarios/ims_default_response.xml" \
         -inf "$uas_csv" \
         -i "$LOCAL_IP" \
         -p "$port" \
         -t un \
         -r "$RATE" \
         -m "$uas_count" \
         -l "$uas_count" \
         -fd 1 \
         -key reg_period 600000 \
         -key field_file_name "$uas_csv" \
         "$REMOTE_IP" \
         -trace_err -error_file "$WORKSPACE/logs/register_test/uas/uas_reg_errors.log" \
         -trace_msg -message_file "$WORKSPACE/logs/register_test/uas/uas_reg_messages.log" \
         -trace_screen -screen_file "$WORKSPACE/logs/register_test/uas/uas_reg_screen.log" \
         -trace_stat -stf "$WORKSPACE/logs/register_test/uas/uas_reg_stats.csv" \
         -trace_logs -log_file "$WORKSPACE/logs/register_test/uas/uas_reg_actions.log" \
         > "$WORKSPACE/logs/register_test/uas/uas_reg_stdout.log" \
         2> "$WORKSPACE/logs/register_test/uas/uas_reg_stderr.log" &
    
    # 获取进程组ID
    local pid=$!
    echo $pid > "$WORKSPACE/pids/uas_reg.pid"
    
    # 等待进程完全启动
    sleep 2
    
    # 启动监控进程，使用进程组ID发送信号
    (while kill -0 -$pid 2>/dev/null; do
        # 发送SIGUSR2信号
        kill -SIGUSR2 -$pid 2>/dev/null
        # 等待足够的时间让SIPp完成写入
        sleep 5
    done) > /dev/null 2>&1 &
    echo $! > "$WORKSPACE/pids/uas_reg_monitor.pid"
    
    echo "$pid"
}

# 启动UAC注册实例
function start_uac_register_instance() {
    local uac_csv="$1"
    local port="$2"
    local uac_count="$3"
    
    # 创建日志目录
    mkdir -p "$WORKSPACE/logs/register_test/uac"
    
    # 使用setsid创建新的进程组运行sipp，重定向所有输出
    setsid sipp -sf "$WORKSPACE/scenarios/ims_register_basic.xml" \
         -inf "$uac_csv" \
         -i "$LOCAL_IP" \
         -p "$port" \
         -t un \
         -r "$RATE" \
         -m "$uac_count" \
         -l "$uac_count" \
         -fd 1 \
         -key reg_period 600000 \
         -key field_file_name "$uac_csv" \
         -recv_timeout 10000 \
         -timeout 10 \
         -aa \
         "$REMOTE_IP" \
         -trace_err -error_file "$WORKSPACE/logs/register_test/uac/uac_reg_errors.log" \
         -trace_msg -message_file "$WORKSPACE/logs/register_test/uac/uac_reg_messages.log" \
         -trace_screen -screen_file "$WORKSPACE/logs/register_test/uac/uac_reg_screen.log" \
         -trace_stat -stf "$WORKSPACE/logs/register_test/uac/uac_reg_stats.csv" \
         -trace_logs -log_file "$WORKSPACE/logs/register_test/uac/uac_reg_actions.log" \
         > "$WORKSPACE/logs/register_test/uac/uac_reg_stdout.log" \
         2> "$WORKSPACE/logs/register_test/uac/uac_reg_stderr.log" &
    
    # 获取进程组ID
    local pid=$!
    echo $pid > "$WORKSPACE/pids/uac_reg.pid"
    
    # 等待进程完全启动
    sleep 2
    
    # 启动监控进程，使用进程组ID发送信号
    (while kill -0 -$pid 2>/dev/null; do
        # 发送SIGUSR2信号
        kill -SIGUSR2 -$pid 2>/dev/null
        # 等待足够的时间让SIPp完成写入
        sleep 5
    done) > /dev/null 2>&1 &
    echo $! > "$WORKSPACE/pids/uac_reg_monitor.pid"
    
    echo "$pid"
}

# 启动UAC通话实例
function start_uac_call_instance() {
    local uac_csv="$1"
    local port="$2"
    local uac_count="$3"
    
    # 创建日志目录
    mkdir -p "$WORKSPACE/logs/call_test/uac"
    
    # 创建临时文件
    local temp_csv=$(mktemp)
    echo "SEQUENTIAL" > "$temp_csv"
    
    # 读取原始CSV文件（跳过头行）并处理每一行
    tail -n +2 "$uac_csv" | while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn called_number; do
        # 从Redis获取security-server信息
        security_server=$(redis-cli get "sipp:security:${imsi}")
        if [ -n "$security_server" ]; then
            # 将security_server中的分号替换为竖线，以避免CSV分隔符冲突
            security_server_modified=$(echo "$security_server" | sed 's/;/|/g')
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn;$called_number;$security_server_modified" >> "$temp_csv"
        else
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn;$called_number" >> "$temp_csv"
        fi
    done
    
    # 用临时文件替换原始文件
    mv "$temp_csv" "$uac_csv"

    # 使用setsid创建新的进程组运行sipp，重定向所有输出
    setsid sipp -sf "$WORKSPACE/scenarios/ims_call_uac.xml" \
         -inf "$uac_csv" \
         -users "$uac_count" \
         -m "$uac_count" \
         -r "$RATE" \
         -i "$LOCAL_IP" \
         -p "$port" \
         "$REMOTE_IP" \
         -trace_err -error_file "$WORKSPACE/logs/call_test/uac/uac_errors.log" \
         -trace_msg -message_file "$WORKSPACE/logs/call_test/uac/uac_messages.log" \
         -trace_screen -screen_file "$WORKSPACE/logs/call_test/uac/uac_screen.log" \
         -trace_stat -stf "$WORKSPACE/logs/call_test/uac/uac_stats.csv" \
         -trace_calldebug -calldebug_file "$WORKSPACE/logs/call_test/uac/uac_calldebug.log" \
         -trace_logs -log_file "$WORKSPACE/logs/call_test/uac/uac_actions.log" \
         -trace_rtt \
         -rtt_freq 1 \
         -fd 1 \
         -t tn \
         -aa \
         -timeout 0 \
         -set call_hold_time "$CALL_HOLD_TIME" \
         -set call_again "$CALL_AGAIN" \
         > "$WORKSPACE/logs/call_test/uac/uac_stdout.log" \
         2> "$WORKSPACE/logs/call_test/uac/uac_stderr.log" &
         
    # 获取进程组ID
    local pid=$!
    echo $pid > "$WORKSPACE/pids/uac_call.pid"
    
    # 等待进程完全启动
    sleep 2
    
    # 启动监控进程，使用进程组ID发送信号
    (while kill -0 -$pid 2>/dev/null; do
        # 发送SIGUSR2信号
        kill -SIGUSR2 -$pid 2>/dev/null
        # 等待足够的时间让SIPp完成写入
        sleep 5
    done) > /dev/null 2>&1 &
    echo $! > "$WORKSPACE/pids/uac_call_monitor.pid"
    
    echo "$pid"
}

# 定期导出屏幕日志的函数
function periodic_screen_dump() {
    local pids=("$@")
    while true; do
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                kill -SIGUSR2 "$pid"
            fi
        done
        sleep 5  # 每5秒更新一次屏幕日志
    done
}

# 清理函数
function cleanup_and_exit() {
    echo "正在清理..."
    
    # 停止所有监控进程
    for pid_file in "$WORKSPACE/pids/"*_monitor.pid; do
        if [ -f "$pid_file" ]; then
            echo "停止监控进程: $(cat "$pid_file")"
            kill $(cat "$pid_file") 2>/dev/null
            rm -f "$pid_file"
        fi
    done
    
    # 发送SIGUSR2信号到所有SIPp进程组
    for pid_file in "$WORKSPACE/pids/"*.pid; do
        if [ -f "$pid_file" ] && [[ "$pid_file" != *"_monitor.pid" ]]; then
            local pgid=$(cat "$pid_file")
            echo "发送SIGUSR2信号到进程组: -$pgid"
            kill -SIGUSR2 -$pgid 2>/dev/null
        fi
    done
    sleep 2
    
    # 发送SIGUSR1信号到所有SIPp进程组
    for pid_file in "$WORKSPACE/pids/"*.pid; do
        if [ -f "$pid_file" ] && [[ "$pid_file" != *"_monitor.pid" ]]; then
            local pgid=$(cat "$pid_file")
            echo "发送SIGUSR1信号到进程组: -$pgid"
            kill -SIGUSR1 -$pgid 2>/dev/null
        fi
    done
    
    # 等待所有进程退出（最多等待10秒）
    local wait_count=0
    while [ $wait_count -lt 10 ]; do
        local all_exited=true
        for pid_file in "$WORKSPACE/pids/"*.pid; do
            if [ -f "$pid_file" ] && [[ "$pid_file" != *"_monitor.pid" ]]; then
                local pgid=$(cat "$pid_file")
                if kill -0 -$pgid 2>/dev/null; then
                    all_exited=false
                    break
                fi
            fi
        done
        
        if $all_exited; then
            break
        fi
        
        sleep 1
        ((wait_count++))
    done
    
    # 如果还有进程在运行，强制终止
    local force_kill=false
    for pid_file in "$WORKSPACE/pids/"*.pid; do
        if [ -f "$pid_file" ] && [[ "$pid_file" != *"_monitor.pid" ]]; then
            local pgid=$(cat "$pid_file")
            if kill -0 -$pgid 2>/dev/null; then
                echo "警告：进程组 $pgid 未能正常退出，强制终止..."
                kill -9 -$pgid 2>/dev/null
                force_kill=true
            fi
        fi
        rm -f "$pid_file"
    done
    
    if $force_kill; then
        echo "部分进程被强制终止，日志可能不完整"
    else
        echo "所有进程已正常退出"
    fi
    
    exit 0
}

# 添加信号处理函数
function handle_signal() {
    echo "接收到信号，开始清理..."
    cleanup_and_exit
}

# 设置信号处理
trap handle_signal SIGINT SIGTERM

# 修改主函数
function main() {
    # 创建日志目录
    mkdir -p "$WORKSPACE/config"
    mkdir -p "$WORKSPACE/logs/register_test/uac"
    mkdir -p "$WORKSPACE/logs/register_test/uas"
    mkdir -p "$WORKSPACE/logs/call_test/uac"
    mkdir -p "$WORKSPACE/pids"  # 添加pids目录
    
    # 清理旧的日志文件和PID文件
    rm -f "$WORKSPACE/logs/register_test/uac/"*
    rm -f "$WORKSPACE/logs/register_test/uas/"*
    rm -f "$WORKSPACE/logs/call_test/uac/"*
    rm -f "$WORKSPACE/pids/"*
    
    # 读取所有返回值
    local csv_info
    csv_info=$(extract_users_from_csv "$CSV_FILE")
    local uac_csv=$(echo "$csv_info" | cut -d' ' -f1)
    local uas_csv=$(echo "$csv_info" | cut -d' ' -f2)
    UAC_USERS=$(echo "$csv_info" | cut -d' ' -f3)  # 直接设置全局变量
    UAS_USERS=$(echo "$csv_info" | cut -d' ' -f4)  # 直接设置全局变量
    
    # 计算端口（使用全局变量）
    local uac_port=5060  # UAC注册和通话实例共用此端口
    local uas_port=$((uac_port + UAC_USERS + 1))
    
    # 打印详细的配置信息
    echo "用户配置信息："
    echo "UAC用户数: $UAC_USERS"
    echo "UAS用户数: $UAS_USERS"
    echo "端口配置："
    echo "UAC端口(注册和通话): $uac_port"
    echo "UAS注册端口: $uas_port"
    
    # 验证用户数
    if [ "$UAC_USERS" -eq 0 ] || [ "$UAS_USERS" -eq 0 ]; then
        echo "错误：UAC或UAS用户数为0"
        cleanup_and_exit
        exit 1
    fi
    
    # 启动UAC注册实例
    echo "正在启动UAC注册实例..."
    local uac_reg_pid=$(start_uac_register_instance "$uac_csv" "$uac_port" "$UAC_USERS")
    if [ -z "$uac_reg_pid" ]; then
        echo "启动UAC注册实例失败"
        cleanup_and_exit
        exit 1
    fi
    echo "UAC注册实例已启动，PID: $uac_reg_pid"
    sleep 2  # 等待进程完全启动

    # 启动UAS注册实例
    echo "正在启动UAS注册实例..."
    local uas_reg_pid=$(start_uas_register_instance "$uas_csv" "$uas_port" "$UAS_USERS")
    if [ -z "$uas_reg_pid" ]; then
        echo "启动UAS注册实例失败"
        cleanup_and_exit
        exit 1
    fi
    echo "UAS注册实例已启动，PID: $uas_reg_pid"
    sleep 2  # 等待进程完全启动
    
    # 等待注册完成
    echo "等待注册完成..."
    sleep 10
    
    # 启动UAC通话实例
    echo "正在启动UAC通话实例..."
    local uac_call_pid=$(start_uac_call_instance "$uac_csv" "$uac_port" "$UAC_USERS")
    if [ -z "$uac_call_pid" ]; then
        echo "启动UAC通话实例失败"
        cleanup_and_exit
        exit 1
    fi
    echo "UAC通话实例已启动，PID: $uac_call_pid"
    sleep 2  # 等待进程完全启动

    # 验证所有进程是否正在运行
    echo "验证所有进程状态..."
    for pid in $uac_reg_pid $uas_reg_pid $uac_call_pid; do
        if ! kill -0 $pid 2>/dev/null; then
            echo "错误：进程 $pid 未在运行"
            cleanup_and_exit
            exit 1
        fi
    done
    echo "所有进程运行正常"

    # 监控所有进程
    echo "所有实例已启动，按Ctrl+C终止测试..."
    
    # 监控进程并实时显示日志
    while true; do
        local all_running=true
        for pid in $uac_reg_pid $uas_reg_pid $uac_call_pid; do
            if ! kill -0 $pid 2>/dev/null; then
                echo "检测到进程 $pid 已停止"
                all_running=false
                break
            fi
        done
        
        if ! $all_running; then
            echo "检测到某个实例已停止，终止所有实例..."
            cleanup_and_exit
            break
        fi
        
        # 清屏并将光标移动到顶部
        clear
        
        # 显示当前时间和运行状态
        echo -e "\033[1m=== 测试运行状态 ($(date '+%Y-%m-%d %H:%M:%S')) ===\033[0m"
        echo "UAC注册进程: $uac_reg_pid"
        echo "UAS注册进程: $uas_reg_pid"
        echo "UAC呼叫进程: $uac_call_pid"
        echo -e "\n"
        
        # 显示最新的屏幕日志
        for type in uac uas; do
            local log_file="$WORKSPACE/logs/register_test/${type}/${type}_reg_screen.log"
            if [ -f "$log_file" ]; then
                echo -e "\033[1;32m=== ${type} 注册状态 ===\033[0m"
                echo -e "\033[1m----------------------------------------\033[0m"
                # 提取并显示Scenario Screen的第一个页面
                awk '/Scenario Screen/{p=1;print;next} /Change Screen/{p=0} p' "$log_file" | head -n 25
                echo -e "\033[1m----------------------------------------\033[0m"
                echo -e "\n"
            fi
        done
        
        local call_log="$WORKSPACE/logs/call_test/uac/uac_screen.log"
        if [ -f "$call_log" ]; then
            echo -e "\033[1;32m=== UAC 呼叫状态 ===\033[0m"
            echo -e "\033[1m----------------------------------------\033[0m"
            # 提取并显示Scenario Screen的第一个页面
            awk '/Scenario Screen/{p=1;print;next} /Change Screen/{p=0} p' "$call_log" | head -n 25
            echo -e "\033[1m----------------------------------------\033[0m"
            echo -e "\n"
        fi
        
        # 显示错误信息（如果有）
        for type in uac uas; do
            local error_file="$WORKSPACE/logs/register_test/${type}/${type}_reg_errors.log"
            if [ -f "$error_file" ] && [ -s "$error_file" ]; then
                echo -e "\033[1;31m=== ${type} 注册错误 ===\033[0m"
                tail -n 1 "$error_file"  # 只显示最后一个错误
                echo -e "\n"
            fi
        done
        
        local call_error_file="$WORKSPACE/logs/call_test/uac/uac_errors.log"
        if [ -f "$call_error_file" ] && [ -s "$call_error_file" ]; then
            echo -e "\033[1;31m=== UAC 呼叫错误 ===\033[0m"
            tail -n 1 "$call_error_file"  # 只显示最后一个错误
            echo -e "\n"
        fi
        
        sleep 5  # 每5秒更新一次显示
    done
}

# 执行主函数
main 