#!/bin/bash

# SIPP性能测试快速启动脚本
# 从项目根目录快速访问性能测试工具

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERFORMANCE_DIR="${SCRIPT_DIR}/performance_testing"

# 检查性能测试目录是否存在
if [[ ! -d "$PERFORMANCE_DIR" ]]; then
    echo "错误: 性能测试目录不存在: $PERFORMANCE_DIR"
    exit 1
fi

# 显示使用帮助
show_help() {
    echo "SIPP性能测试工具 - 快速启动脚本"
    echo ""
    echo "用法:"
    echo "  $0 <command> [options]"
    echo ""
    echo "可用命令:"
    echo "  basic       - 运行基础性能测试"
    echo "  stress      - 运行高并发压力测试"
    echo "  stability   - 运行长期稳定性测试"
    echo "  custom      - 运行自定义测试"
    echo "  analyze     - 分析测试结果"
    echo "  help        - 显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 basic                    # 运行基础测试"
    echo "  $0 stress                   # 运行高并发测试"
    echo "  $0 analyze                  # 分析所有测试结果"
    echo "  $0 custom 'UAC_CMD' 'UAS_CMD' 5  # 自定义测试5轮"
    echo ""
    echo "详细文档: ./performance_testing/README.md"
}

# 切换到性能测试目录
cd "$PERFORMANCE_DIR"

case "${1:-help}" in
    "basic")
        echo "启动基础性能测试..."
        ./examples/basic_test.sh
        ;;
    "stress"|"high-concurrency")
        echo "启动高并发压力测试..."
        ./examples/high_concurrency_test.sh
        ;;
    "stability"|"long-term")
        echo "启动长期稳定性测试..."
        ./examples/stability_test.sh
        ;;
    "custom")
        if [[ $# -lt 3 ]]; then
            echo "错误: 自定义测试需要UAC和UAS命令参数"
            echo "用法: $0 custom 'UAC_COMMAND' 'UAS_COMMAND' [轮次]"
            exit 1
        fi
        
        UAC_CMD="$2"
        UAS_CMD="$3"
        ROUNDS="${4:-1}"
        
        echo "启动自定义性能测试..."
        echo "UAC命令: $UAC_CMD"
        echo "UAS命令: $UAS_CMD"
        echo "测试轮次: $ROUNDS"
        
        ./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" "$ROUNDS"
        ;;
    "analyze")
        echo "分析测试结果..."
        if [[ -d "performance_results" ]]; then
            ./analyze_performance_results.py performance_results/
        else
            echo "未找到测试结果目录"
            exit 1
        fi
        ;;
    "help"|"-h"|"--help")
        show_help
        ;;
    *)
        echo "错误: 未知命令 '$1'"
        echo ""
        show_help
        exit 1
        ;;
esac
