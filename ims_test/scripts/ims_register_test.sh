#!/bin/bash

# ================================
# IMS 注册测试脚本
# ================================

# 导入公共函数库
source "$(dirname "$0")/ims_common.sh"

# 检查参数值是否有效
check_parameter_value() {
    local option="$1"
    local value="$2"
    
    if [ -z "$value" ]; then
        echo "错误: 选项 '$option' 需要参数值"
        usage
        exit 1
    fi
    
    if [[ "$value" =~ ^-- ]]; then
        echo "错误: 选项 '$option' 需要参数值，但提供的是另一个选项 '$value'"
        usage
        exit 1
    fi
}

# 显示使用方法
usage() {
    local usage_text="  --scenario <类型>      测试场景类型 (basic 或 ipsec_auth)
  --local-ip <IP>        本地IP地址
  --remote-ip <IP:端口>  远程IP地址和端口
  --initial-port <端口>  起始端口号
  --users <数量>         总用户数
  --rate <速率>          呼叫速率 (calls/s)
  --duration <秒>        测试持续时间
  --reg-period <秒>      注册刷新周期 (默认: 300)
  --reg-count <次数>     每用户注册次数 (默认: 1)
  --ipsec-key <密钥>     IPSec密钥 (IPSec模式时使用)
  --initial-imsi <号码>  起始IMSI号码 (默认: 460000000000001)
  --initial-msisdn <号码> 起始MSISDN号码 (默认: 14500000001)
  --instances <数量>     SIPp实例数 (默认: 1)
  --log-level <级别>     日志级别 (1-7, 默认: 3)
  -h, --help             显示此帮助信息

示例:
  # 基本注册测试
  $0 --scenario basic --local-ip 192.168.1.10 --remote-ip 192.168.1.1:5060 \\
     --initial-port 5070 --users 100 --rate 10 --duration 30

  # IPSec注册测试
  $0 --scenario ipsec_auth --local-ip 192.168.1.10 --remote-ip 192.168.1.1:5060 \\
     --initial-port 5070 --users 50 --rate 5 --duration 60 --ipsec-key 123456789012"

    echo "$usage_text"
}

# 初始化变量
SCENARIO=""
LOCAL_IP=""
REMOTE_IP=""
REMOTE_PORT=""
INITIAL_PORT=""
TOTAL_USERS=""
CALL_RATE=""
TEST_DURATION=""
REG_PERIOD=300
REG_COUNT=1
IPSEC_KEY=""
INITIAL_IMSI="462200000000000"
INITIAL_MSISDN="220000"
INSTANCES=1
LOG_LEVEL=3

# 解析命令行参数
while [ $# -gt 0 ]; do
    case $1 in
        --scenario)
            check_parameter_value "$1" "$2"
            SCENARIO="$2"
            shift 2
            ;;
        --local-ip)
            check_parameter_value "$1" "$2"
            LOCAL_IP="$2"
            shift 2
            ;;
        --remote-ip)
            check_parameter_value "$1" "$2"
            if [[ "$2" =~ ^([^:]+):([0-9]+)$ ]]; then
                REMOTE_IP="${BASH_REMATCH[1]}"
                REMOTE_PORT="${BASH_REMATCH[2]}"
            else
                REMOTE_IP="$2"
                REMOTE_PORT="5060"  # 默认端口
            fi
            shift 2
            ;;
        --initial-port)
            check_parameter_value "$1" "$2"
            INITIAL_PORT="$2"
            shift 2
            ;;
        --users)
            check_parameter_value "$1" "$2"
            TOTAL_USERS="$2"
            shift 2
            ;;
        --rate)
            check_parameter_value "$1" "$2"
            CALL_RATE="$2"
            shift 2
            ;;
        --duration)
            check_parameter_value "$1" "$2"
            TEST_DURATION="$2"
            shift 2
            ;;
        --reg-period)
            check_parameter_value "$1" "$2"
            REG_PERIOD="$2"
            shift 2
            ;;
        --reg-count)
            check_parameter_value "$1" "$2"
            REG_COUNT="$2"
            shift 2
            ;;
        --ipsec-key)
            check_parameter_value "$1" "$2"
            IPSEC_KEY="$2"
            shift 2
            ;;
        --initial-imsi)
            check_parameter_value "$1" "$2"
            INITIAL_IMSI="$2"
            shift 2
            ;;
        --initial-msisdn)
            check_parameter_value "$1" "$2"
            INITIAL_MSISDN="$2"
            shift 2
            ;;
        --instances)
            check_parameter_value "$1" "$2"
            INSTANCES="$2"
            shift 2
            ;;
        --log-level)
            check_parameter_value "$1" "$2"
            set_log_level "$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "错误: 不认识的选项 '$1'"
            usage
            exit 1
            ;;
    esac
done

# 检查必需参数
if [ -z "$LOCAL_IP" ] || [ -z "$REMOTE_IP" ] || [ -z "$REMOTE_PORT" ] || [ -z "$TOTAL_USERS" ] || [ -z "$CALL_RATE" ] || [ -z "$TEST_DURATION" ]; then
    echo "错误: 缺少必需参数"
    usage
    exit 1
fi

# 计算每个实例的用户数和速率
USERS_PER_INSTANCE=$((TOTAL_USERS / INSTANCES))
RATE_PER_INSTANCE=$((CALL_RATE / INSTANCES))

# 启动SIPp实例函数
start_sipp_instance() {
    local instance_id=$1
    local port=$2
    local users=$3
    local rate=$4    
    local csv_file="config/users_${instance_id}.csv"
    local scenario_file
    local log_dir="logs/register_test"
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

        scenario_file="scenarios/ims_register_ipsec_auth.xml"
        # 为每个用户设置IPSec SA
        echo "正在设置IPSec SA..."
        setup_ipsec "$csv_file" "$LOCAL_IP" "$REMOTE_IP"
    else
        scenario_file="scenarios/ims_register_basic.xml"
    fi
    
    echo "启动SIPp实例 $instance_id (端口: $port, 用户数: $users, 速率: $rate)"
    
    # 使用简单的SIPp命令启动
    sipp "${REMOTE_IP}:${REMOTE_PORT}" \
         -sf "$scenario_file" \
         -oocsf "scenarios/ims_default_response.xml" \
         -inf "$csv_file" \
         -i "$LOCAL_IP" \
         -p "$port" \
         -t un \
         -r "$rate" \
         -l "$users" \
         -nd \
         -timeout $TEST_DURATION \
         -trace_screen \
         -screen_file "${log_file}_screen.log" \
         -trace_err \
         -error_file "${log_file}_error.log" \
         -trace_stat \
         -key reg_period "$REG_PERIOD" \
         -set reg_count "$REG_COUNT" \
         -max_socket 4000 \
         -recv_timeout 10000
    
    return $?
}

# 主函数
main() {
    # 初始化日志和错误统计
    init_logging "logs/register_test"
    init_error_stats
    
    log_info "开始 ${SCENARIO} 注册测试..."
    
    # 检查基本依赖
    check_dependencies "sipp" "grep" "awk" "bc"
    
    # 验证场景文件
    local scenario_file
    if [ "$SCENARIO" = "ipsec_auth" ]; then
        scenario_file="scenarios/ims_register_ipsec_auth.xml"
    else
        scenario_file="scenarios/ims_register_basic.xml"
    fi
    
    validate_sipp_scenario "$scenario_file"
    
    # 创建必要的目录
    mkdir -p {logs/register_test,config,pids}
    
    # 确保清理现有环境
    cleanup
    
    # 创建用户配置
    create_csv "config/users_0.csv" $USERS_PER_INSTANCE "$SCENARIO" "$INITIAL_IMSI" "$INITIAL_MSISDN" || {
        log_error "创建用户配置文件失败，退出测试"
        cleanup
        exit 1
    }
    
    # 启动SIPp实例
    start_sipp_instance 0 $INITIAL_PORT $USERS_PER_INSTANCE $RATE_PER_INSTANCE
    local sipp_status=$?
    
    # 处理SIPp退出码
    handle_sipp_error "$sipp_status" "" "$SCENARIO"
    
    # 生成错误统计报告
    generate_error_report
    
    log_info "注册测试完成，退出状态: $sipp_status"
    
    # 清理
    cleanup
    
    return $sipp_status
}

# 执行主函数
main "$@" 