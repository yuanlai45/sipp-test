#!/bin/bash

# 切换到正确的工作目录（相对于脚本位置）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 导入公共函数库
source "$SCRIPT_DIR/ims_common.sh"

# 切换到sipp根目录（包含sipp.dtd）
cd "$(dirname "$(dirname "$SCRIPT_DIR")")" || {
    echo "错误: 无法切换到工作目录"
    exit 1
}

# 设置调试日志文件
DEBUG_LOG_FILE="test_suite/logs/register_test/debug.log"

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
    local usage_text="  --scenario <类型>      测试场景类型 (basic 或 ipsec_auth)
  --local-ip <IP>        本地IP地址
  --remote-ip <IP:PORT>  远端IP地址和端口
  --initial-port <端口>  初始SIPp端口起始值
  --users <数量>         并发用户数量
  --rate <速率>          每秒新建呼叫数
  --duration <时长>      测试持续时间(秒)
  --instances <数量>     SIPp实例数量
  --reg-period <时长>    注册刷新周期(秒)
  --ipsec-key <密钥>     IPSec加密密钥(16进制)"
    
    show_usage "$0" "$usage_text"
}

# 参数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        --local-ip) LOCAL_IP="$2"; shift 2 ;;
        --remote-ip) 
            # 分离IP和端口
            REMOTE_IP=$(echo "$2" | cut -d':' -f1)
            REMOTE_PORT=$(echo "$2" | cut -d':' -f2)
            shift 2 ;;
        --initial-port) INITIAL_PORT="$2"; shift 2 ;;
        --users) TOTAL_USERS="$2"; shift 2 ;;
        --rate) CALL_RATE="$2"; shift 2 ;;
        --duration) TEST_DURATION="$2"; shift 2 ;;
        --scenario) SCENARIO="$2"; shift 2 ;;
        --instances) INSTANCES="$2"; shift 2 ;;
        --reg-period) REG_PERIOD="$2"; shift 2 ;;
        --ipsec-key) IPSEC_KEY="$2"; shift 2 ;;
        *) usage ;;
    esac
done

# 检查必需参数
if [ -z "$LOCAL_IP" ] || [ -z "$REMOTE_IP" ] || [ -z "$REMOTE_PORT" ] || [ -z "$TOTAL_USERS" ] || [ -z "$CALL_RATE" ] || [ -z "$TEST_DURATION" ]; then
    usage
fi

# 设置默认值
SCENARIO=${SCENARIO:-"basic"}
INSTANCES=${INSTANCES:-"1"}
REG_PERIOD=${REG_PERIOD:-"3600"}
INITIAL_PORT=${INITIAL_PORT:-"5060"}  # 默认使用5060作为起始端口

IPSEC_KEY=${IPSEC_KEY:-"000102030405060708090a0b0c0d0e0f"}
USERS_PER_INSTANCE=$((TOTAL_USERS / INSTANCES))
[ $USERS_PER_INSTANCE -eq 0 ] && USERS_PER_INSTANCE=1
RATE_PER_INSTANCE=$((CALL_RATE / INSTANCES))
[ $RATE_PER_INSTANCE -eq 0 ] && RATE_PER_INSTANCE=1

# 修改start_sipp_instance函数，添加IPSec支持
start_sipp_instance() {
    local instance_id=$1
    local port=$2
    local users=$3
    local rate=$4    
    local csv_file="test_suite/config/users_${instance_id}.csv"
    local scenario_file
    local log_dir="test_suite/logs/register_test"
    local log_file="${log_dir}/sipp_${instance_id}"
    
    # 创建日志目录
    mkdir -p "$log_dir"
    
    # 根据场景类型选择正确的场景文件
    if [ "$SCENARIO" = "ipsec_auth" ]; then
        # 确保Redis正在运行
        if ! redis-cli ping > /dev/null 2>&1; then
            echo "Redis服务未运行，正在启动..."
            systemctl start redis-server
            sleep 2
        
            if ! redis-cli ping > /dev/null 2>&1; then
                echo "无法启动Redis服务，测试无法继续"
                exit 1
            fi
        fi

        scenario_file="test_suite/scenarios/ims_register_ipsec_auth.xml"
        # 为每个用户设置IPSec SA
        local success_count=0
        local total_count=0
        debug_log "正在设置IPSec SA..."
        while IFS=';' read -r imsi domain client_spi server_spi server_port k opc amf msisdn; do
            if [ "$imsi" != "SEQUENTIAL" ] && [ "$imsi" != "username" ]; then
                total_count=$((total_count + 1))
                if setup_ipsec "$client_spi" "$server_spi" "$LOCAL_IP" "$REMOTE_IP" "$IPSEC_KEY"; then
                    success_count=$((success_count + 1))
                fi
            fi
        done < "$csv_file"
        debug_log "IPSec SA设置完成: 成功 $success_count/$total_count"
        
        if [ $success_count -ne $total_count ]; then
            debug_log "警告: 部分IPSec SA设置失败"
        fi
    else
        scenario_file="test_suite/scenarios/ims_register_basic.xml"
    fi
    
    debug_log "启动SIPp实例 $instance_id (端口: $port, 用户数: $users, 速率: $rate)"
    
    # 获取当前文件描述符限制
    local max_socket=$(($(ulimit -n) - 100))  # 预留100个文件描述符给其他用途
    
    # 启动SIPp
    sipp -sf "$scenario_file" \
         -oocsf "test_suite/scenarios/ims_default_response.xml" \
         -inf "$csv_file" \
         -i "$LOCAL_IP" \
         -p "$port" \
         -t un \
         -r "$rate" \
         -m "$users" \
         -l "$users" \
         -d "$TEST_DURATION" \
         -trace_err \
         -error_file ${log_file}_errors.log \
         -trace_stat \
         -stf ${log_file}_stats.csv \
         -trace_screen \
         -screen_file ${log_file}_screen.log \
         -trace_msg \
         -message_file ${log_file}_messages.log \
         -trace_logs \
         -log_file ${log_file}_actions.log \
         -trace_calldebug \
         -calldebug_file ${log_file}_calldebug.log \
         -key reg_period "$REG_PERIOD" \
         -key field_file_name "$csv_file" \
         -max_socket "$max_socket" \
         -recv_timeout 10000 \
         -timeout 0 \
         -aa \
         "${REMOTE_IP}:${REMOTE_PORT}"
}

# 主函数
main() {
    debug_log "开始 ${SCENARIO} 注册测试..."
    
    # 打印调试信息
    debug_log "调试信息:"
    debug_log "  总用户数: $TOTAL_USERS"
    debug_log "  实例数量: $INSTANCES"
    debug_log "  每个实例的用户数: $USERS_PER_INSTANCE"
    debug_log "  总呼叫速率: $CALL_RATE"
    debug_log "  每个实例的呼叫速率: $RATE_PER_INSTANCE"
    
    # 增加文件描述符限制
    local current_limit=$(ulimit -n)
    local required_limit=$((TOTAL_USERS + 1000))  # 每个用户一个socket，额外预留1000个
    if [ $current_limit -lt $required_limit ]; then
        debug_log "当前文件描述符限制($current_limit)太低，尝试增加到$required_limit"
        ulimit -n $required_limit || debug_log "警告: 无法增加文件描述符限制，将使用max_socket参数限制"
    fi
    
    # 创建必要的目录
    mkdir -p test_suite/{logs/register_test,config}
    
    # 清理旧的日志文件
    rm -f test_suite/logs/register_test/sipp_*_*.log
    rm -f test_suite/logs/register_test/sipp_*.csv
    
    # 确保清理现有环境
    cleanup
    
    # 创建用户配置
    local start_user=0
    local end_user=$((USERS_PER_INSTANCE - 1))
    create_csv "test_suite/config/users_0.csv" $USERS_PER_INSTANCE "$SCENARIO" || {
        debug_log "创建用户配置文件失败，退出测试"
        cleanup
        exit 1
    }
    
    # 启动SIPp实例
    start_sipp_instance 0 $INITIAL_PORT $USERS_PER_INSTANCE $RATE_PER_INSTANCE
    
    # 如果是IPSec认证模式，提示用户
    if [ "$SCENARIO" = "ipsec_auth" ]; then
        debug_log "IPSec认证模式：SIPp将自动更新CSV文件中的服务器端口"
        debug_log "更新日志将写入 /tmp/sipp_port_update.log"
    fi
    
    debug_log "日志保存在: test_suite/logs/register_test/"
}

# 设置清理陷阱
trap cleanup EXIT

# 执行主函数
main 