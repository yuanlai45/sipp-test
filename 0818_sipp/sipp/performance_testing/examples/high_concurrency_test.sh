#!/bin/bash

# SIPP高并发性能测试示例
# 适用于系统承载能力评估和性能瓶颈发现

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERFORMANCE_DIR="$(dirname "$SCRIPT_DIR")"
SIPP_ROOT="$(dirname "$PERFORMANCE_DIR")"

echo "=== SIPP高并发性能测试 ==="
echo "测试场景: IMS系统高并发压力测试"
echo "测试强度: 高强度 (适合性能极限测试)"
echo ""

# 高并发测试参数
CALL_RATE=200       # 200 calls/s
MAX_CALLS=5000      # 总共5000个呼叫
CONCURRENT_LIMIT=1000  # 最大并发1000个呼叫
CALL_DURATION=30    # 每个呼叫持续30秒
TEST_ROUNDS=5       # 测试5轮
MAX_SOCKETS=10000   # 最大socket数

echo "⚠️  高并发测试注意事项:"
echo "1. 确保系统有足够资源 (建议16GB+ RAM)"
echo "2. 检查文件描述符限制: ulimit -n"
echo "3. 监控网络带宽使用情况"
echo "4. 避免在生产环境执行"
echo ""

# 检查系统配置
echo "检查系统配置..."

# 检查文件描述符限制
FD_LIMIT=$(ulimit -n)
if [ "$FD_LIMIT" -lt 65536 ]; then
    echo "⚠️  警告: 文件描述符限制较低 ($FD_LIMIT)"
    echo "建议执行: ulimit -n 65536"
    echo ""
fi

# 检查可用内存
AVAILABLE_MEM=$(free -m | awk 'NR==2{print $7}')
if [ "$AVAILABLE_MEM" -lt 4096 ]; then
    echo "⚠️  警告: 可用内存较低 (${AVAILABLE_MEM}MB)"
    echo "建议释放更多内存用于测试"
    echo ""
fi

# UAC配置 - 高并发发起方
UAC_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uac.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uac_users.csv \
    -i 10.18.2.12 \
    -p 12002 \
    -r ${CALL_RATE} \
    -l ${CONCURRENT_LIMIT} \
    -m ${MAX_CALLS} \
    -d $((CALL_DURATION * 1000)) \
    -t un \
    -timeout 180 \
    -max_socket ${MAX_SOCKETS} \
    -recv_timeout 10000 \
    -send_timeout 10000 \
    -set call_hold_time $((CALL_DURATION * 1000)) \
    -nd \
    127.0.0.1:5060"

# UAS配置 - 高并发接收方
UAS_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uas.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uas_users.csv \
    -i 10.18.2.12 \
    -p 5060 \
    -t un \
    -timeout 300 \
    -max_socket ${MAX_SOCKETS} \
    -recv_timeout 10000 \
    -nd"

echo "高并发测试配置:"
echo "- 呼叫速率: ${CALL_RATE} calls/s"
echo "- 最大并发: ${CONCURRENT_LIMIT} calls"
echo "- 总呼叫数: ${MAX_CALLS}"
echo "- 呼叫持续时间: ${CALL_DURATION}s"
echo "- 最大Socket数: ${MAX_SOCKETS}"
echo "- 测试轮次: ${TEST_ROUNDS}"
echo ""

read -p "确认开始高并发测试? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "测试已取消"
    exit 0
fi

# 运行测试
echo "开始执行高并发性能测试..."
echo "预计测试时间: $((TEST_ROUNDS * (MAX_CALLS / CALL_RATE + CALL_DURATION + 30) / 60)) 分钟"
echo ""

cd "$PERFORMANCE_DIR"

# 设置环境变量以优化性能
export MONITOR_INTERVAL=10  # 增加监控间隔以减少开销
export RESTART_DELAY=60     # 增加重启间隔以确保系统恢复

./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" "$TEST_ROUNDS"

echo ""
echo "=== 高并发测试完成 ==="
echo "查看结果: ./analyze_performance_results.py performance_results/"
echo ""
echo "关键指标检查:"
echo "1. 成功率应 > 95%"
echo "2. 平均响应时间应合理"
echo "3. 错误率应 < 1%"
echo "4. 系统资源使用应在安全范围内"
echo ""
