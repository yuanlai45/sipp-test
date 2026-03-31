#!/bin/bash

# SIPP基础性能测试示例
# 适用于初步性能评估和功能验证

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERFORMANCE_DIR="$(dirname "$SCRIPT_DIR")"
SIPP_ROOT="$(dirname "$PERFORMANCE_DIR")"

echo "=== SIPP基础性能测试 ==="
echo "测试场景: IMS呼叫基础功能"
echo "测试强度: 低强度 (适合功能验证)"
echo ""

# 基础测试参数
CALL_RATE=10        # 10 calls/s
MAX_CALLS=100       # 总共100个呼叫
CALL_DURATION=10    # 每个呼叫持续10秒
TEST_ROUNDS=3       # 测试3轮

# UAC配置 - 呼叫发起方
UAC_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uac.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uac_users.csv \
    -i 10.18.2.12 \
    -p 12002 \
    -r ${CALL_RATE} \
    -m ${MAX_CALLS} \
    -d $((CALL_DURATION * 1000)) \
    -t un \
    -timeout 60 \
    -set call_hold_time $((CALL_DURATION * 1000)) \
    127.0.0.1:5060"

# UAS配置 - 呼叫接收方
UAS_CMD="sipp -sf ${SIPP_ROOT}/test_suite/scenarios/ims_call_uas.xml \
    -inf ${SIPP_ROOT}/test_suite/config/uas_users.csv \
    -i 10.18.2.12 \
    -p 5060 \
    -t un \
    -timeout 120"

echo "测试配置:"
echo "- 呼叫速率: ${CALL_RATE} calls/s"
echo "- 最大呼叫数: ${MAX_CALLS}"
echo "- 呼叫持续时间: ${CALL_DURATION}s"
echo "- 测试轮次: ${TEST_ROUNDS}"
echo ""

# 运行测试
echo "开始执行基础性能测试..."
cd "$PERFORMANCE_DIR"

./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" "$TEST_ROUNDS"

echo ""
echo "=== 基础测试完成 ==="
echo "查看结果: ./analyze_performance_results.py performance_results/"
echo ""
