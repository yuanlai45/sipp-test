#!/bin/bash

# 导入公共函数库
source "$(dirname "$0")/ims_common.sh"

# 设置调试日志文件
DEBUG_LOG_FILE="test_suite/logs/call_test/debug.log"

# 在脚本开头添加全局变量声明
declare -g UAC_USERS=0
declare -g UAS_USERS=0
declare -g WORKSPACE="test_suite"

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
    echo "  --initial-port <端口>       初始SIPp端口起始值"
    echo "  --initial-media-port <端口> 初始媒体端口起始值"
    echo "  --users <用户数量>          用户数量"
    echo "  --rate <呼叫速率>           呼叫速率（每秒呼叫数）"
    echo "  --duration <测试时长>       测试持续时间（秒）"
    echo "  --call-hold <通话保持时间>  通话保持时间（秒）"
    echo "  --call-wait <接听等待时间>  接听等待时间（秒）"
    echo "  --call-again <是否再次呼叫> 是否在通话结束后再次发起呼叫（0或1）"
    echo "  --csv-file <CSV文件路径>    用户数据CSV文件路径"
    echo "  --auth <认证方式>           认证方式（none, ipsec, digest）"
    echo "  --initial-imsi <IMSI>       起始IMSI号码"
    echo "  --initial-msisdn <MSISDN>   起始MSISDN号码"
    echo "  --help                      显示此帮助信息"
}

# 默认参数
LOCAL_IP=""
REMOTE_IP=""
REMOTE_PORT=""
INITIAL_PORT=5060
INITIAL_MEDIA_PORT=10000
USERS=1
RATE=1
DURATION=60
CALL_HOLD_TIME=5
CALL_WAIT_TIME=5
CALL_AGAIN=0
CSV_FILE=""
AUTH="none"
MAX_SOCKET=4000
INITIAL_IMSI=462200000000000
INITIAL_MSISDN=220000

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --local-ip)
            LOCAL_IP="$2"
            shift 2
            ;;
        --remote-ip)
            # 分离IP和端口
            REMOTE_IP=$(echo "$2" | cut -d':' -f1)
            REMOTE_PORT=$(echo "$2" | cut -d':' -f2)
            shift 2
            ;;
        --initial-port)
            INITIAL_PORT="$2"
            shift 2
            ;;
        --initial-media-port)
            INITIAL_MEDIA_PORT="$2"
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
        --initial-imsi)
            INITIAL_IMSI="$2"
            shift 2
            ;;
        --initial-msisdn)
            INITIAL_MSISDN="$2"
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
if [[ -z "$LOCAL_IP" || -z "$REMOTE_IP" || -z "$REMOTE_PORT" ]]; then
    echo "错误: 必须指定本地IP和远端IP:端口"
    usage
    exit 1
fi

# 检查CSV文件是否存在
if [[ -z "$CSV_FILE" ]]; then
    # 如果未指定CSV文件，则创建一个
    CSV_FILE="$WORKSPACE/config/users_data.csv"
    create_csv "$CSV_FILE" "$USERS" "$AUTH" "$INITIAL_IMSI" "$INITIAL_MSISDN"
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
    
    # 临时存储所有用户数据
    local temp_file=$(mktemp)
    tail -n +2 "$csv_file" > "$temp_file"
    
    # 创建临时数组来存储所有用户的MSISDN
    declare -a all_msisdns
    declare -a all_roles
    
    # 第一次遍历，收集所有用户的MSISDN和角色
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        all_msisdns+=("$msisdn")
        all_roles+=("$role")
    done < "$temp_file"
    
    # 第二次遍历，生成UAC和UAS的CSV文件
    local index=0
    while IFS=';' read -r imsi domain client_spi server_spi server_port k op amf role msisdn; do
        if [[ "$role" == "uac" ]]; then
            # 获取上一个用户的MSISDN作为被叫号码
            local prev_index=$((index - 1))
            local called_number=""
            
            # 如果是第一个用户，则取最后一个用户的MSISDN
            if [[ $prev_index -lt 0 ]]; then
                prev_index=$((${#all_msisdns[@]} - 1))
            fi
            
            called_number="${all_msisdns[$prev_index]}"
            
            # 添加到UAC CSV，包括被叫号码
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn;$called_number" >> "$uac_csv"
        elif [[ "$role" == "uas" ]]; then
            # 添加到UAS CSV
            echo "$imsi;$domain;$client_spi;$server_spi;$server_port;$k;$op;$amf;$role;$msisdn" >> "$uas_csv"
        fi
        
        ((index++))
    done < "$temp_file"
    
    # 清理临时文件
    rm -f "$temp_file"
    
    # 计算最终的UAC和UAS用户数量（减去标题行）
    local uac_count=$(($(wc -l < "$uac_csv") - 1))
    local uas_count=$(($(wc -l < "$uas_csv") - 1))
    
    echo "从CSV文件中提取了 $uac_count 个UAC用户和 $uas_count 个UAS用户" >&2
    
    # 返回用户数量，这样父shell可以获取
    echo "$uac_csv" "$uas_csv" "$uac_count" "$uas_count"
}

# 准备测试环境
function prepare_test_env() {
    # 创建必要的目录
    mkdir -p "$WORKSPACE/config"
    mkdir -p "$WORKSPACE/logs/call_test/uac"
    mkdir -p "$WORKSPACE/logs/call_test/uas"
    mkdir -p "$WORKSPACE/pids"
    
    # 设置目录权限
    chmod 777 "$WORKSPACE/config"
    chmod 777 "$WORKSPACE/logs"
    chmod 777 "$WORKSPACE/logs/call_test"
    chmod 777 "$WORKSPACE/logs/call_test/uac"
    chmod 777 "$WORKSPACE/logs/call_test/uas"
    chmod 777 "$WORKSPACE/pids"
    
    # 清理旧的日志文件和PID文件
    rm -f "$WORKSPACE/logs/call_test/uac/"*
    rm -f "$WORKSPACE/logs/call_test/uas/"*
    rm -f "$WORKSPACE/pids/"*
    
    # 创建空的日志文件并设置权限
    touch "$WORKSPACE/logs/call_test/uas/uas_screen.log"
    touch "$WORKSPACE/logs/call_test/uas/uas_errors.log"
    touch "$WORKSPACE/logs/call_test/uas/uas_stats.csv"
    touch "$WORKSPACE/logs/call_test/uac/uac_screen.log"
    touch "$WORKSPACE/logs/call_test/uac/uac_errors.log"
    touch "$WORKSPACE/logs/call_test/uac/uac_stats.csv"
    touch "$WORKSPACE/logs/call_test/uac/uac_register_screen.log"
    touch "$WORKSPACE/logs/call_test/uac/uac_register_errors.log"
    touch "$WORKSPACE/logs/call_test/uac/uac_register_stats.csv"
    
    # 设置日志文件权限
    chmod 777 "$WORKSPACE/logs/call_test/uas/"*
    chmod 777 "$WORKSPACE/logs/call_test/uac/"*
    
    # 从CSV文件提取用户
    local result
    result=$(extract_users_from_csv "$CSV_FILE")
    read -r uac_csv uas_csv UAC_USERS UAS_USERS <<< "$result"
    
    # 计算端口
    local uas_port=$INITIAL_PORT
    local uac_port=$((uas_port + UAS_USERS + 2))
    local uas_media_port=$INITIAL_MEDIA_PORT
    local uac_media_port=$((uas_media_port + UAS_USERS + 2))
    
    # 返回所需的值
    echo "$uac_csv" "$uas_csv" "$uac_port" "$uas_port" "$uac_media_port" "$uas_media_port" "$UAC_USERS" "$UAS_USERS"
}

# 主函数
function main() {
    # 打印配置信息
    log_info "IMS通话测试配置:"
    log_info "- 本地IP: $LOCAL_IP"
    log_info "- 远端IP: ${REMOTE_IP}:${REMOTE_PORT}"
    log_info "- 用户数: $USERS"
    log_info "- UAC用户数: 将提取约 $((USERS/2)) 个"
    log_info "- UAS用户数: 将提取约 $((USERS/2)) 个"
    log_info "- 呼叫速率: $RATE 呼叫/秒"
    log_info "- 测试持续时间: $DURATION 秒"
    log_info "- 通话保持时间: $CALL_HOLD_TIME 秒"
    log_info "- 接听等待时间: $CALL_WAIT_TIME 秒 (XML中为: $((CALL_WAIT_TIME * 1000)) 毫秒)"
    
    # 准备测试环境
    local result
    result=$(prepare_test_env)
    read -r uac_csv uas_csv uac_port uas_port uac_media_port uas_media_port UAC_USERS UAS_USERS <<< "$result"
    
    # 检查环境准备是否成功
    if [[ ! -d "$WORKSPACE/logs/call_test/uas" ]] || [[ ! -d "$WORKSPACE/logs/call_test/uac" ]]; then
        log_error "错误: 测试环境准备失败，日志目录创建失败"
        return 1
    fi
    
    # 检查必要的日志文件是否存在
    local required_files=(
        "$WORKSPACE/logs/call_test/uas/uas_screen.log"
        "$WORKSPACE/logs/call_test/uas/uas_errors.log"
        "$WORKSPACE/logs/call_test/uas/uas_stats.csv"
        "$WORKSPACE/logs/call_test/uac/uac_screen.log"
        "$WORKSPACE/logs/call_test/uac/uac_errors.log"
        "$WORKSPACE/logs/call_test/uac/uac_stats.csv"
        "$WORKSPACE/logs/call_test/uac/uac_register_screen.log"
        "$WORKSPACE/logs/call_test/uac/uac_register_errors.log"
        "$WORKSPACE/logs/call_test/uac/uac_register_stats.csv"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "错误: 日志文件 $file 创建失败"
            return 1
        fi
    done
    
    log_info "测试环境准备完成，所有日志目录和文件已创建"
    
    if [[ "$UAC_USERS" -eq 0 ]] || [[ "$UAS_USERS" -eq 0 ]]; then
        log_error "错误: 从CSV文件中未提取到有效用户数据"
        return 1
    fi
    
    log_info "UAC用户数: $UAC_USERS (CSV文件: $uac_csv)"
    log_info "UAS用户数: $UAS_USERS (CSV文件: $uas_csv)"
    
    # 创建临时的默认响应场景文件，替换等待时间
    local default_response_template="$WORKSPACE/scenarios/ims_default_response.xml"
    local default_response_temp="$WORKSPACE/scenarios/ims_default_response_temp.xml"
    local wait_time_ms=$((CALL_WAIT_TIME * 1000))
    
    sed "s/<pause label=\"wait_for_answer\" milliseconds=\"[0-9]*\"/<pause label=\"wait_for_answer\" milliseconds=\"$wait_time_ms\"/g" \
        "$default_response_template" > "$default_response_temp"
    
    # 构造UAS命令
    local uas_cmd="sipp ${REMOTE_IP}:${REMOTE_PORT} \
        -sf \"$WORKSPACE/scenarios/ims_call_uas.xml\" \
        -oocsf \"$default_response_temp\" \
        -inf \"$uas_csv\" \
        -i $LOCAL_IP \
        -p $uas_port \
        -mp $uas_media_port \
        -t un \
        -r $RATE \
        -l $UAS_USERS \
        -timeout $DURATION \
        -nd \
        -fd 1 \
        -trace_screen -screen_file \"$WORKSPACE/logs/call_test/uas/uas_screen.log\" \
        -trace_err -error_file \"$WORKSPACE/logs/call_test/uas/uas_errors.log\""
    
    # 构造UAC命令
    local uac_cmd="sipp ${REMOTE_IP}:${REMOTE_PORT} \
        -sf \"$WORKSPACE/scenarios/ims_call_uac.xml\" \
        -inf \"$uac_csv\" \
        -i $LOCAL_IP \
        -p $uac_port \
        -mp $uac_media_port \
        -t un \
        -r $RATE \
        -l $UAC_USERS"
    
    # 如果call_again为0，则设置timeout；否则不设置timeout让其无限运行
    if [[ "$CALL_AGAIN" -eq 0 ]]; then
        uac_cmd="$uac_cmd \
        -timeout $DURATION"
    fi
    
    uac_cmd="$uac_cmd \
        -nd -aa \
        -max_socket $MAX_SOCKET \
        -set call_hold_time $((CALL_HOLD_TIME * 1000)) \
        -set call_again $CALL_AGAIN \
        -fd 1 \
        -trace_screen -screen_file \"$WORKSPACE/logs/call_test/uac/uac_screen.log\" \
        -trace_err -error_file \"$WORKSPACE/logs/call_test/uac/uac_errors.log\""

    # 构造UAC注册命令（使用相同的端口文件，但使用TCP传输）
    local uac_register_cmd="sipp ${REMOTE_IP}:${REMOTE_PORT} \
        -sf \"$WORKSPACE/scenarios/ims_call_uac_register.xml\" \
        -inf \"$uac_csv\" \
        -i $LOCAL_IP \
        -p $uac_port \
        -t tn \
        -r $RATE \
        -l $UAC_USERS \
        -timeout $DURATION \
        -nd \
        -max_socket $MAX_SOCKET \
        -fd 1 \
        -trace_screen -screen_file \"$WORKSPACE/logs/call_test/uac/uac_register_screen.log\" \
        -trace_err -error_file \"$WORKSPACE/logs/call_test/uac/uac_register_errors.log\""

    # 显示命令
    echo ""
    echo "============================"
    echo "请按照以下步骤测试IMS通话:"
    echo "============================"
    echo ""
    echo "1. 打开一个终端窗口，运行UAS实例:"
    echo "----------------------------------------"
    echo "$uas_cmd"
    echo ""
    echo "2. 打开另一个终端窗口，运行UAC注册实例:"
    echo "----------------------------------------"
    echo "$uac_register_cmd"
    echo ""
    echo "3. 等待3秒，确保UAS和UAC注册已启动"
    echo ""
    echo "4. 打开第三个终端窗口，运行UAC通话实例:"
    echo "----------------------------------------"
    echo "$uac_cmd"
    echo ""
    echo "注意:"
    echo "- 所有命令都将在前台运行，显示实时状态"
    if [[ "$CALL_AGAIN" -eq 0 ]]; then
    echo "- 测试将在${DURATION}秒后自动结束"
    else
        echo "- UAC通话将持续运行直到手动停止（call_again=$CALL_AGAIN）"
        echo "- UAS和UAC注册将在${DURATION}秒后自动结束"
    fi
    echo "- 按Ctrl+C可手动停止测试"
    echo "- 测试日志保存在: $WORKSPACE/logs/call_test/ 目录"
    echo "- Screen跟踪日志: uas_screen.log, uac_screen.log, uac_register_screen.log"
    echo "- 错误日志: uas_errors.log, uac_errors.log, uac_register_errors.log"
    echo "- 统计数据CSV: uas_stats.csv, uac_stats.csv, uac_register_stats.csv"
    echo ""
    echo "============================"
}

# 执行主函数
main 