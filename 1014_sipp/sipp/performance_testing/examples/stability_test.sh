#!/bin/bash

# SIPP稳定性测试示例
# 适用于长时间稳定性验证和内存泄漏检测

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERFORMANCE_DIR="$(dirname "$SCRIPT_DIR")"
SIPP_ROOT="$(dirname "$PERFORMANCE_DIR")"

echo "=== SIPP长期稳定性测试 ==="
echo "测试场景: IMS系统长期稳定性验证"
echo "测试强度: 中等强度长时间运行"
echo ""

# 稳定性测试参数
CALL_RATE=50        # 50 calls/s (中等强度)
TEST_DURATION=3600  # 每轮测试1小时
CALL_DURATION=60    # 每个呼叫持续60秒
CONCURRENT_LIMIT=500   # 最大并发500个呼叫
TEST_ROUNDS=24      # 测试24轮 (24小时)
MAX_SOCKETS=5000    # 最大socket数

echo "📊 稳定性测试配置:"
echo "- 呼叫速率: ${CALL_RATE} calls/s"
echo "- 单轮测试时长: $((TEST_DURATION / 60)) 分钟"
echo "- 呼叫持续时间: ${CALL_DURATION}s"
echo "- 最大并发: ${CONCURRENT_LIMIT} calls"
echo "- 总测试轮次: ${TEST_ROUNDS}"
echo "- 预计总测试时间: $((TEST_ROUNDS * TEST_DURATION / 3600)) 小时"
echo ""

echo "🔍 稳定性测试目标:"
echo "1. 验证系统长期运行稳定性"
echo "2. 检测内存泄漏问题"
echo "3. 监控性能衰减情况"
echo "4. 验证错误恢复能力"
echo ""

# 检查磁盘空间
AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
REQUIRED_SPACE=$((TEST_ROUNDS * 100 * 1024))  # 估算每轮需要100MB
if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    echo "⚠️  警告: 磁盘空间可能不足"
    echo "可用空间: $((AVAILABLE_SPACE / 1024))MB"
    echo "预计需要: $((REQUIRED_SPACE / 1024))MB"
    echo ""
fi

# UAC配置 - 稳定性测试发起方
UAC_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uac.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uac_users.csv \
    -i 10.18.2.12 \
    -p 12002 \
    -r ${CALL_RATE} \
    -l ${CONCURRENT_LIMIT} \
    -d ${TEST_DURATION}000 \
    -t un \
    -timeout 0 \
    -max_socket ${MAX_SOCKETS} \
    -recv_timeout 15000 \
    -send_timeout 15000 \
    -set call_hold_time $((CALL_DURATION * 1000)) \
    -set call_again 1 \
    -aa \
    127.0.0.1:5060"

# UAS配置 - 稳定性测试接收方
UAS_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uas.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uas_users.csv \
    -i 10.18.2.12 \
    -p 5060 \
    -t un \
    -timeout 0 \
    -max_socket ${MAX_SOCKETS} \
    -recv_timeout 15000 \
    -aa"

echo "确认测试配置无误后继续..."
read -p "开始长期稳定性测试? 这将运行 ${TEST_ROUNDS} 小时 (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "测试已取消"
    exit 0
fi

# 创建稳定性测试专用结果目录
STABILITY_RESULTS_DIR="stability_test_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$PERFORMANCE_DIR/performance_results/$STABILITY_RESULTS_DIR"

# 设置环境变量
export RESULTS_BASE_DIR="$PERFORMANCE_DIR/performance_results/$STABILITY_RESULTS_DIR"
export MONITOR_INTERVAL=30   # 30秒监控间隔
export RESTART_DELAY=120     # 2分钟重启间隔

echo ""
echo "🚀 开始执行长期稳定性测试..."
echo "测试结果将保存在: $STABILITY_RESULTS_DIR"
echo "开始时间: $(date)"
echo ""

cd "$PERFORMANCE_DIR"

# 后台运行测试并记录PID
nohup ./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" "$TEST_ROUNDS" > "$RESULTS_BASE_DIR/stability_test.log" 2>&1 &
TEST_PID=$!

echo "稳定性测试已在后台启动 (PID: $TEST_PID)"
echo "日志文件: $RESULTS_BASE_DIR/stability_test.log"
echo ""

# 创建监控脚本
cat > "$RESULTS_BASE_DIR/monitor_stability.sh" << EOF
#!/bin/bash
# 稳定性测试监控脚本

echo "=== 稳定性测试监控 ==="
echo "测试PID: $TEST_PID"
echo "开始时间: $(date)"
echo ""

while kill -0 $TEST_PID 2>/dev/null; do
    echo "$(date): 测试进行中..."
    
    # 检查系统资源
    echo "内存使用: \$(free -h | grep Mem | awk '{print \$3"/"\$2}')"
    echo "CPU使用: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | sed 's/%us,//')"
    
    # 检查测试进程资源使用
    if pgrep -f sipp > /dev/null; then
        echo "SIPP进程数: \$(pgrep -f sipp | wc -l)"
        echo "SIPP内存使用: \$(ps -o pid,vsz,rss,comm -p \$(pgrep -f sipp | head -1) | tail -1)"
    fi
    
    echo "---"
    sleep 300  # 每5分钟检查一次
done

echo "$(date): 稳定性测试完成"
EOF

chmod +x "$RESULTS_BASE_DIR/monitor_stability.sh"

echo "监控命令:"
echo "  实时监控: $RESULTS_BASE_DIR/monitor_stability.sh"
echo "  查看日志: tail -f $RESULTS_BASE_DIR/stability_test.log"
echo "  停止测试: kill $TEST_PID"
echo ""

echo "测试完成后分析结果:"
echo "  ./analyze_performance_results.py $RESULTS_BASE_DIR/"
echo ""

echo "稳定性测试关键指标:"
echo "1. 成功率应保持稳定 (> 98%)"
echo "2. 内存使用应保持稳定 (无明显增长)"
echo "3. 响应时间应保持稳定"
echo "4. 错误率应保持在低水平 (< 0.5%)"
echo ""
