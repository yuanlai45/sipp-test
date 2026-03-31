#!/bin/bash

# SIPP高性能压测管理脚本
# 功能：运行双实例SIPP测试，监控并记录性能数据

set -euo pipefail

# 配置参数
WORKSPACE="${WORKSPACE:-$(pwd)}"
RESULTS_BASE_DIR="${WORKSPACE}/performance_results"
RESTART_DELAY=30  # 重启间隔时间(秒)
MONITOR_INTERVAL=5  # 监控间隔(秒)

# 全局变量
UAC_PID=""
UAS_PID=""
CURRENT_TEST_DIR=""
TEST_START_TIME=""

# 创建测试结果目录
create_test_directory() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    CURRENT_TEST_DIR="${RESULTS_BASE_DIR}/test_run_${timestamp}"
    mkdir -p "${CURRENT_TEST_DIR}"/{uac,uas,analysis}
    echo "${CURRENT_TEST_DIR}"
}

# 启动UAC实例
start_uac_instance() {
    local test_dir="$1"
    local uac_cmd="$2"
    
    echo "启动UAC实例..."
    
    # 添加日志参数到UAC命令
    local enhanced_cmd="${uac_cmd} \
        -trace_stat -stf ${test_dir}/uac/stats.csv \
        -trace_screen -screen_file ${test_dir}/uac/screen.log \
        -trace_err -error_file ${test_dir}/uac/errors.log \
        -trace_rtt -rtt_freq 100 \
        -fd 10"
    
    # 后台启动UAC
    eval "${enhanced_cmd}" > "${test_dir}/uac/console.log" 2>&1 &
    UAC_PID=$!
    
    echo "UAC实例已启动，PID: ${UAC_PID}"
    echo "${UAC_PID}" > "${test_dir}/uac/pid"
}

# 启动UAS实例
start_uas_instance() {
    local test_dir="$1"
    local uas_cmd="$2"
    
    echo "启动UAS实例..."
    
    # 添加日志参数到UAS命令
    local enhanced_cmd="${uas_cmd} \
        -trace_stat -stf ${test_dir}/uas/stats.csv \
        -trace_screen -screen_file ${test_dir}/uas/screen.log \
        -trace_err -error_file ${test_dir}/uas/errors.log \
        -trace_rtt -rtt_freq 100 \
        -fd 10"
    
    # 后台启动UAS
    eval "${enhanced_cmd}" > "${test_dir}/uas/console.log" 2>&1 &
    UAS_PID=$!
    
    echo "UAS实例已启动，PID: ${UAS_PID}"
    echo "${UAS_PID}" > "${test_dir}/uas/pid"
}

# 监控实例状态
monitor_instances() {
    while true; do
        sleep ${MONITOR_INTERVAL}
        
        # 检查UAC状态
        if ! kill -0 "${UAC_PID}" 2>/dev/null; then
            echo "检测到UAC实例(PID: ${UAC_PID})已结束"
            return 1
        fi
        
        # 检查UAS状态
        if ! kill -0 "${UAS_PID}" 2>/dev/null; then
            echo "检测到UAS实例(PID: ${UAS_PID})已结束"
            return 2
        fi
        
        # 记录实时性能数据
        record_performance_snapshot
    done
}

# 记录性能快照
record_performance_snapshot() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local snapshot_file="${CURRENT_TEST_DIR}/analysis/performance_snapshots.json"
    
    # 获取系统资源使用情况
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    local memory_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    
    # 构建JSON快照
    cat >> "${snapshot_file}" << EOF
{
  "timestamp": "${timestamp}",
  "uac_pid": ${UAC_PID},
  "uas_pid": ${UAS_PID},
  "system_resources": {
    "cpu_usage_percent": ${cpu_usage:-0},
    "memory_usage_percent": ${memory_info:-0}
  }
},
EOF
}

# 停止所有实例
stop_all_instances() {
    echo "停止所有SIPP实例..."
    
    if [[ -n "${UAC_PID}" ]] && kill -0 "${UAC_PID}" 2>/dev/null; then
        echo "停止UAC实例(PID: ${UAC_PID})"
        kill -TERM "${UAC_PID}" 2>/dev/null || true
        wait "${UAC_PID}" 2>/dev/null || true
    fi
    
    if [[ -n "${UAS_PID}" ]] && kill -0 "${UAS_PID}" 2>/dev/null; then
        echo "停止UAS实例(PID: ${UAS_PID})"
        kill -TERM "${UAS_PID}" 2>/dev/null || true
        wait "${UAS_PID}" 2>/dev/null || true
    fi
}

# 分析测试结果
analyze_test_results() {
    local test_dir="$1"
    local analysis_dir="${test_dir}/analysis"
    
    echo "分析测试结果..."
    
    # 创建测试摘要
    create_test_summary "${test_dir}"
    
    # 解析统计数据
    parse_statistics_data "${test_dir}"
    
    # 生成性能报告
    generate_performance_report "${test_dir}"
}

# 创建测试摘要
create_test_summary() {
    local test_dir="$1"
    local summary_file="${test_dir}/analysis/test_summary.json"
    local test_end_time=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat > "${summary_file}" << EOF
{
  "test_run_id": "$(basename ${test_dir})",
  "start_time": "${TEST_START_TIME}",
  "end_time": "${test_end_time}",
  "duration_seconds": $(($(date +%s) - $(date -d "${TEST_START_TIME}" +%s))),
  "test_files": {
    "uac_stats": "uac/stats.csv",
    "uas_stats": "uas/stats.csv",
    "uac_screen": "uac/screen.log",
    "uas_screen": "uas/screen.log",
    "uac_errors": "uac/errors.log",
    "uas_errors": "uas/errors.log"
  }
}
EOF
}

# 解析统计数据
parse_statistics_data() {
    local test_dir="$1"
    local analysis_dir="${test_dir}/analysis"
    
    # 解析UAC统计数据
    if [[ -f "${test_dir}/uac/stats.csv" ]]; then
        echo "解析UAC统计数据..."
        python3 -c "
import csv
import json
import sys

def parse_stats_csv(file_path):
    with open(file_path, 'r') as f:
        reader = csv.DictReader(f, delimiter=';')
        rows = list(reader)
        if rows:
            last_row = rows[-1]
            return {
                'total_calls': int(last_row.get('TotalCallCreated', 0)),
                'successful_calls': int(last_row.get('SuccessfulCall', 0)),
                'failed_calls': int(last_row.get('FailedCall', 0)),
                'current_calls': int(last_row.get('CurrentCall', 0)),
                'call_rate': float(last_row.get('CallRate', 0))
            }
    return {}

uac_stats = parse_stats_csv('${test_dir}/uac/stats.csv')
with open('${analysis_dir}/uac_summary.json', 'w') as f:
    json.dump(uac_stats, f, indent=2)
" 2>/dev/null || echo "UAC统计数据解析失败"
    fi
    
    # 解析UAS统计数据
    if [[ -f "${test_dir}/uas/stats.csv" ]]; then
        echo "解析UAS统计数据..."
        python3 -c "
import csv
import json

def parse_stats_csv(file_path):
    with open(file_path, 'r') as f:
        reader = csv.DictReader(f, delimiter=';')
        rows = list(reader)
        if rows:
            last_row = rows[-1]
            return {
                'total_calls': int(last_row.get('TotalCallCreated', 0)),
                'successful_calls': int(last_row.get('SuccessfulCall', 0)),
                'failed_calls': int(last_row.get('FailedCall', 0)),
                'current_calls': int(last_row.get('CurrentCall', 0)),
                'incoming_calls': int(last_row.get('IncomingCall', 0))
            }
    return {}

uas_stats = parse_stats_csv('${test_dir}/uas/stats.csv')
with open('${analysis_dir}/uas_summary.json', 'w') as f:
    json.dump(uas_stats, f, indent=2)
" 2>/dev/null || echo "UAS统计数据解析失败"
    fi
}

# 生成性能报告
generate_performance_report() {
    local test_dir="$1"
    local report_file="${test_dir}/analysis/performance_report.html"
    
    echo "生成性能报告: ${report_file}"
    
    cat > "${report_file}" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>SIPP性能测试报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 10px; border-radius: 5px; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background-color: #e8f4f8; border-radius: 3px; }
        .error { color: red; }
        .success { color: green; }
    </style>
</head>
<body>
    <div class="header">
        <h1>SIPP高性能压测报告</h1>
        <p>测试ID: $(basename ${test_dir})</p>
        <p>生成时间: $(date)</p>
    </div>
    
    <div class="section">
        <h2>测试概览</h2>
        <div id="test-overview">
            <!-- 测试概览数据将通过JavaScript加载 -->
        </div>
    </div>
    
    <div class="section">
        <h2>性能指标</h2>
        <div id="performance-metrics">
            <!-- 性能指标将通过JavaScript加载 -->
        </div>
    </div>
    
    <div class="section">
        <h2>错误分析</h2>
        <div id="error-analysis">
            <!-- 错误分析将通过JavaScript加载 -->
        </div>
    </div>
</body>
</html>
EOF
}

# 主函数
main() {
    if [[ $# -lt 2 ]]; then
        echo "用法: $0 <UAC_COMMAND> <UAS_COMMAND> [循环次数]"
        echo "示例: $0 'sipp -sf uac.xml 127.0.0.1' 'sipp -sf uas.xml -p 5060' 5"
        exit 1
    fi
    
    local uac_command="$1"
    local uas_command="$2"
    local max_loops="${3:-1}"
    
    echo "=== SIPP高性能压测管理器 ==="
    echo "UAC命令: ${uac_command}"
    echo "UAS命令: ${uas_command}"
    echo "测试轮次: ${max_loops}"
    echo ""
    
    # 创建结果基础目录
    mkdir -p "${RESULTS_BASE_DIR}"
    
    # 信号处理
    trap 'stop_all_instances; exit 1' INT TERM
    
    for ((loop=1; loop<=max_loops; loop++)); do
        echo "=== 开始第 ${loop}/${max_loops} 轮测试 ==="
        
        # 创建测试目录
        CURRENT_TEST_DIR=$(create_test_directory)
        TEST_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
        
        echo "测试目录: ${CURRENT_TEST_DIR}"
        
        # 启动实例
        start_uas_instance "${CURRENT_TEST_DIR}" "${uas_command}"
        sleep 2  # 等待UAS启动
        start_uac_instance "${CURRENT_TEST_DIR}" "${uac_command}"
        
        # 监控实例
        monitor_instances
        monitor_result=$?
        
        # 停止实例
        stop_all_instances
        
        # 分析结果
        analyze_test_results "${CURRENT_TEST_DIR}"
        
        echo "第 ${loop} 轮测试完成，结果保存在: ${CURRENT_TEST_DIR}"
        
        # 如果不是最后一轮，等待重启
        if [[ ${loop} -lt ${max_loops} ]]; then
            echo "等待 ${RESTART_DELAY} 秒后开始下一轮测试..."
            sleep ${RESTART_DELAY}
        fi
    done
    
    echo "=== 所有测试轮次完成 ==="
    echo "结果保存在: ${RESULTS_BASE_DIR}"
}

# 执行主函数
main "$@"
