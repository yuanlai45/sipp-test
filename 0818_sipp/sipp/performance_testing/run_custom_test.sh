#!/bin/bash

# 运行用户自定义的SIPP测试命令
# 这个脚本直接运行两个SIPP实例，循环指定次数
#
# 使用方法：
#   ./run_custom_test.sh [轮次] [容错模式]
#
# 参数说明：
#   轮次     - 测试轮次数 (默认: 2)
#   容错模式 - true=失败时继续, false=失败时停止 (默认: true)
#
# 示例：
#   ./run_custom_test.sh 10 true     # 运行10轮，失败时继续
#   ./run_custom_test.sh 5 false     # 运行5轮，失败时停止

# 注释掉严格模式，避免因为小错误导致脚本退出
# set -euo pipefail

# 設置適當的系統限制
echo "設置系統限制..."
ulimit -n 65536  # 設置文件描述符限制為 65536
echo "當前文件描述符限制: $(ulimit -n)"

echo "=== 自定义SIPP测试脚本 ==="

# 测试参数
ROUNDS=${1:-1}  # 默认2轮测试
CONTINUE_ON_FAILURE=${2:-"true"}  # 默认失败时继续测试
DELAY_BETWEEN_ROUNDS=30  # 轮次间隔时间

# 创建独立的日志目录
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_IP="10.18.1.199"
LOCAL_IP="10.18.2.59"
SCENIRIO_DIR="/home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios"
CONFIG_DIR="/home/sder/sipp-test/0818_sipp/sipp/test_suite/config"
LOG_BASE_DIR="/home/sder/sipp-test/0818_sipp/sipp/performance_testing/test_results"
TEST_LOG_DIR="${LOG_BASE_DIR}/custom_test_${TIMESTAMP}"

echo "创建测试日志目录: $TEST_LOG_DIR"
mkdir -p "$TEST_LOG_DIR"

# 定义本次运行的日志文件路径（所有轮次共享）
UAC_SCREEN_FILE="${TEST_LOG_DIR}/uac_screen.log"
UAC_ERROR_FILE="${TEST_LOG_DIR}/uac_errors.log"
UAS_SCREEN_FILE="${TEST_LOG_DIR}/uas_screen.log"
UAS_ERROR_FILE="${TEST_LOG_DIR}/uas_errors.log"

# UAC命令 (呼叫发起方)
UAC_CMD='sipp '"$REMOTE_IP:6060"' \
    -sf "'"$SCENIRIO_DIR/ims_call_uac.xml"'" \
    -inf "'"$CONFIG_DIR/uac_users.csv"'" \
    -i '"$LOCAL_IP"' -p 20000 -mp 60000 -t un \
    -r 250 -l 2500 -nd -aa -max_socket 8000 \
    -set call_hold_time 10000 \
    -fd 1 -timeout 30 \
    -recv_timeout 30000 \
    -m 2500 \
    -trace_screen -screen_file "'"$UAC_SCREEN_FILE"'" -screen_overwrite false \
    -trace_err -error_file "'"$UAC_ERROR_FILE"'" -error_overwrite false'

# -r 呼叫和注册速率   -l 用户数  
#-nd 不发送DNS请求 -aa 自动应答 -max_socket 最大连接数 
#-fd 文件描述符 -timeout 超时时间 -recv_timeout 接收超时时间 
#-m 最大呼叫数 -trace_screen 屏幕日志 -screen_file 屏幕日志文件 
#-screen_overwrite 是否覆盖 -trace_err 错误日志 
#-error_file 错误日志文件 -error_overwrite 是否覆盖

# UAS命令 (呼叫接收方)
UAS_CMD='sipp '"$REMOTE_IP:6060"' \
    -sf "'"$SCENIRIO_DIR/ims_call_uas.xml"'" \
    -oocsf "'"$SCENIRIO_DIR/ims_default_response_temp.xml"'" \
    -inf "'"$CONFIG_DIR/uas_users.csv"'" \
    -i '"$LOCAL_IP"' -p 10000 -mp 50000 -t un \
    -r 250 -l 2500 -timeout 30 -recv_timeout 30000 -nd -fd 1 -max_socket 8000 \
    -trace_screen -screen_file "'"$UAS_SCREEN_FILE"'" -screen_overwrite false -bg'

echo "测试配置:"
echo "- 测试轮次: $ROUNDS"
echo "- 呼叫速率: 250 calls/s"
echo "- 最大呼叫数: 2500"
echo "- 轮次间隔: ${DELAY_BETWEEN_ROUNDS}s" 
if [ "$CONTINUE_ON_FAILURE" = "true" ]; then
    echo "- 容错模式: 启用 (失败时继续测试)"
else
    echo "- 容错模式: 禁用 (失败时停止测试)"
fi
echo "- 日志目录: $TEST_LOG_DIR"
echo ""
echo "日志文件:"
echo "- UAC Screen: $UAC_SCREEN_FILE"
echo "- UAC Error:  $UAC_ERROR_FILE"
echo "- UAS Screen: $UAS_SCREEN_FILE"
echo "- UAS Error:  $UAS_ERROR_FILE"
echo ""

# 清理函数
cleanup() {
    echo "清理SIPP进程..."
    
    # 找到所有相关的SIPP进程 (UAC和UAS)
    UAC_PIDS=$(pgrep -f "sipp.*$REMOTE_IP.*ims_call_uac" 2>/dev/null || true)
    UAS_PIDS=$(pgrep -f "sipp.*$REMOTE_IP.*ims_call_uas" 2>/dev/null || true)
    ALL_SIPP_PIDS="$UAC_PIDS $UAS_PIDS"
    
    if [ -n "$ALL_SIPP_PIDS" ]; then
        echo "发现SIPP进程: $ALL_SIPP_PIDS"
        
        # 首先发送TERM信号给所有进程
        for pid in $ALL_SIPP_PIDS; do
            if [ -n "$pid" ] && kill -0 $pid 2>/dev/null; then
                echo "温和停止进程 $pid"
                kill -TERM $pid 2>/dev/null || true
            fi
        done
        
        # 等待进程自然退出
        echo "等待进程自然退出..."
        sleep 5
        
        # 检查哪些进程还在运行，强制杀死
        for pid in $ALL_SIPP_PIDS; do
            if [ -n "$pid" ] && kill -0 $pid 2>/dev/null; then
                echo "强制停止进程 $pid"
                kill -9 $pid 2>/dev/null || true
            fi
        done
        
        # 再次等待确保进程完全退出
        sleep 2
    fi
    
    # 最后兜底清理：清理任何可能遗漏的SIPP进程
    pkill -9 -f "sipp.*$REMOTE_IP" 2>/dev/null || true
    
    echo "进程清理完成"
}

# 设置信号处理 (只在中断时清理，不在正常退出时清理)
trap cleanup INT TERM

# 统计变量
TOTAL_SUCCESS=0
TOTAL_FAILED=0
FAILED_ROUNDS=()

# 开始测试循环
for ((round=1; round<=ROUNDS; round++)); do
    echo "=== 开始第 $round/$ROUNDS 轮测试 ==="
    echo "时间: $(date)"
    
    # 清理可能存在的进程
    if [ $round -gt 1 ]; then
        echo "第 $round 轮开始前清理残留进程..."
        cleanup
    fi
    
    echo "启动UAS实例..."
    # 启动UAS并获取其真实PID
    eval "$UAS_CMD" &
    UAS_LAUNCHER_PID=$!
    echo "UAS启动器 PID: $UAS_LAUNCHER_PID"
    
    # 等待UAS启动，然后找到真实的UAS进程PID
    sleep 3
    
    # 通过进程特征找到真实的UAS进程
    UAS_REAL_PID=""
    for attempt in {1..5}; do
        # 查找包含UAS特征的SIPP进程
        UAS_REAL_PID=$(pgrep -f "sipp.*$REMOTE_IP.*ims_call_uas" 2>/dev/null | head -1)
        if [ -n "$UAS_REAL_PID" ]; then
            break
        fi
        echo "等待UAS进程启动... (尝试 $attempt/5)"
        sleep 1
    done
    
    if [ -z "$UAS_REAL_PID" ]; then
        echo "错误: 无法找到UAS进程"
        echo "检查UAS错误日志: $UAS_ERROR_FILE"
        # 显示当前所有SIPP进程便于调试
        echo "当前SIPP进程:"
        pgrep -af "sipp.*$REMOTE_IP" || echo "无SIPP进程"
        continue
    fi
    
    echo "UAS真实进程 PID: $UAS_REAL_PID"
    # 保存真实PID以便后续管理
    UAS_PID=$UAS_REAL_PID
    
    echo "启动UAC实例..."
    eval "$UAC_CMD" &
    UAC_PID=$!
    echo "UAC PID: $UAC_PID"
    
    # 等待UAC完成
    echo "等待UAC测试完成..."
    wait $UAC_PID
    UAC_EXIT_CODE=$?
    
    echo "UAC测试完成，退出码: $UAC_EXIT_CODE"
    
    # 记录测试结果但继续执行
    if [ $UAC_EXIT_CODE -eq 0 ]; then
        echo "✓ 第 $round 轮UAC测试成功"
        ((TOTAL_SUCCESS++))
    else
        echo "✗ 第 $round 轮UAC测试失败 (退出码: $UAC_EXIT_CODE)"
        echo "  错误日志: $UAC_ERROR_FILE"
        ((TOTAL_FAILED++))
        FAILED_ROUNDS+=($round)
        
        if [ "$CONTINUE_ON_FAILURE" = "true" ]; then
            echo "  容错模式: 继续执行下一轮测试..."
        else
            echo "  严格模式: 停止测试"
            break
        fi
    fi
    
    # 停止UAS进程
    echo "停止UAS实例..."
    if kill -0 $UAS_PID 2>/dev/null; then
        echo "正在停止UAS进程 $UAS_PID..."
        kill -TERM $UAS_PID 2>/dev/null || true
        
        # 等待进程退出，最多等待10秒
        for i in {1..10}; do
            if ! kill -0 $UAS_PID 2>/dev/null; then
                echo "UAS进程已正常退出"
                break
            fi
            sleep 1
        done
        
        # 如果进程还在运行，强制杀死
        if kill -0 $UAS_PID 2>/dev/null; then
            echo "UAS进程未响应SIGTERM，使用SIGKILL强制停止..."
            kill -9 $UAS_PID 2>/dev/null || true
            sleep 2
        fi
        
        echo "UAS进程已停止"
    else
        echo "UAS进程已经结束"
    fi
    
    # 确保所有相关进程都被清理
    echo "验证进程清理状态..."
    REMAINING_PIDS=$(pgrep -f "sipp.*$REMOTE_IP" 2>/dev/null || true)
    if [ -n "$REMAINING_PIDS" ]; then
        echo "发现残留进程: $REMAINING_PIDS，执行清理..."
        cleanup
    else
        echo "所有进程已正确清理"
    fi
    
    echo "第 $round 轮测试完成"
    echo "当前进度: $round/$ROUNDS ($(echo "scale=1; $round * 100 / $ROUNDS" | bc -l)%)"
    echo "当前统计: ✅$TOTAL_SUCCESS ❌$TOTAL_FAILED (成功率: $(echo "scale=1; $TOTAL_SUCCESS * 100 / $round" | bc -l)%)"
    echo ""
    
    # 如果不是最后一轮，等待间隔时间
    if [ $round -lt $ROUNDS ]; then
        echo "等待 ${DELAY_BETWEEN_ROUNDS} 秒后开始下一轮..."
        sleep $DELAY_BETWEEN_ROUNDS
    else
        echo "已完成最后一轮测试"
    fi
done

echo "测试循环已结束"

echo ""
echo "🏁 快速摘要: $TOTAL_SUCCESS/$ROUNDS 轮成功 ($(echo "scale=1; $TOTAL_SUCCESS * 100 / $ROUNDS" | bc -l)%)"
echo ""

echo "=== 所有测试完成 ==="
echo "结束时间: $(date)"
echo ""

# 计算总体成功率
SUCCESS_RATE=$(echo "scale=2; $TOTAL_SUCCESS * 100 / $ROUNDS" | bc -l)

echo "==============================================="
echo "              📊 测试总结报告"
echo "==============================================="
echo ""
echo "🕐 测试时间范围:"
echo "   开始时间: $TIMESTAMP"
echo "   结束时间: $(date +%Y%m%d_%H%M%S)"
echo ""
echo "📈 测试配置:"
echo "   总轮次数: $ROUNDS"
echo "   呼叫速率: 250 calls/s"
echo "   单轮呼叫数: 2500"
echo "   容错模式: $CONTINUE_ON_FAILURE"
echo ""
echo "📊 测试结果统计:"
echo "   ✅ 成功轮次: $TOTAL_SUCCESS"
echo "   ❌ 失败轮次: $TOTAL_FAILED"
echo "   📈 总体成功率: $SUCCESS_RATE%"
echo ""

# 判断测试质量
if (( $(echo "$SUCCESS_RATE >= 95" | bc -l) )); then
    echo "🎉 测试质量评估: 优秀 (成功率 ≥ 95%)"
elif (( $(echo "$SUCCESS_RATE >= 80" | bc -l) )); then
    echo "👍 测试质量评估: 良好 (成功率 ≥ 80%)"
elif (( $(echo "$SUCCESS_RATE >= 60" | bc -l) )); then
    echo "⚠️  测试质量评估: 一般 (成功率 ≥ 60%)"
else
    echo "❌ 测试质量评估: 较差 (成功率 < 60%)"
fi

echo ""
if [ ${#FAILED_ROUNDS[@]} -gt 0 ]; then
    echo "❌ 失败轮次详情: ${FAILED_ROUNDS[*]}"
    echo ""
    echo "💡 建议检查项目:"
    echo "   • 网络连接稳定性"
    echo "   • 服务器负载情况"
    echo "   • SIPP配置参数"
    echo "   • 错误日志: $UAC_ERROR_FILE"
else
    echo "🎯 所有轮次均成功完成！"
fi
echo ""
echo "==============================================="
echo "              📁 测试文件信息"
echo "==============================================="
echo ""
echo "📂 测试结果目录: $TEST_LOG_DIR"
echo ""
echo "📄 日志文件列表:"
echo "   📊 UAC 屏幕日志: $UAC_SCREEN_FILE"
echo "   🚨 UAC 错误日志: $UAC_ERROR_FILE"
echo "   📊 UAS 屏幕日志: $UAS_SCREEN_FILE"
echo "   🚨 UAS 错误日志: $UAS_ERROR_FILE"
echo ""

# 检查日志文件大小
if [ -f "$UAC_ERROR_FILE" ]; then
    ERROR_SIZE=$(wc -l < "$UAC_ERROR_FILE" 2>/dev/null || echo "0")
    if [ "$ERROR_SIZE" -gt 100 ]; then
        echo "⚠️  UAC错误日志较大 ($ERROR_SIZE 行)，建议重点检查"
    else
        echo "✅ UAC错误日志大小正常 ($ERROR_SIZE 行)"
    fi
fi

echo ""
echo "🔍 快速检查命令:"
echo "   查看目录: ls -la $TEST_LOG_DIR/"
echo "   错误统计: grep -c 'timeout\\|error\\|fail' $UAC_ERROR_FILE"
echo "   成功统计: grep -c 'Successful' $UAC_SCREEN_FILE"
echo ""

# 生成简要的执行总结
echo "==============================================="
echo "              🏁 执行总结"
echo "==============================================="
if [ $TOTAL_FAILED -eq 0 ]; then
    echo "🎉 完美执行！所有 $ROUNDS 轮测试均成功完成"
    echo "💪 系统稳定性表现优异"
elif [ $TOTAL_SUCCESS -gt $TOTAL_FAILED ]; then
    echo "👍 总体良好！$ROUNDS 轮测试中 $TOTAL_SUCCESS 轮成功"
    echo "🔧 建议查看失败轮次原因并优化"
else
    echo "⚠️  需要关注！$ROUNDS 轮测试中 $TOTAL_FAILED 轮失败"
    echo "🛠️  建议检查系统配置和网络环境"
fi

echo ""
echo "📝 注意: 详细的测试数据和错误信息请查看上述日志文件"
echo "==============================================="

# 最终清理所有SIPP进程
echo ""
echo "执行最终清理..."
cleanup
