# SIPP高性能压测完整方案

## 🎯 方案概述

这套方案提供了一个完整的SIPP高性能压测解决方案，包括：
- 双实例自动化测试管理
- 完整的性能数据收集
- 实时监控和结果分析
- 可视化报告生成

## 📁 文件结构

```
sipp/
├── performance_test_manager.sh          # 主测试管理脚本
├── analyze_performance_results.py       # 结果分析工具
├── performance_testing_guide.md         # 使用指南(本文件)
├── performance_test_results_schema.md   # 数据结构说明
└── performance_results/                 # 测试结果目录
    ├── test_run_20241208_143022/        # 单次测试结果
    │   ├── uac/                         # UAC实例日志
    │   │   ├── stats.csv               # 统计数据
    │   │   ├── screen.log              # 屏幕输出
    │   │   ├── errors.log              # 错误日志
    │   │   └── console.log             # 控制台输出
    │   ├── uas/                         # UAS实例日志
    │   └── analysis/                    # 分析结果
    │       ├── detailed_analysis.json   # 详细分析
    │       ├── performance_snapshots.json # 性能快照
    │       └── performance_report.html  # 性能报告
    ├── performance_summary.json         # 汇总报告
    ├── performance_report.html          # HTML报告
    └── performance_trends.png           # 趋势图表
```

## 🚀 快速开始

### 1. 基本使用

```bash
# 运行单轮测试
./performance_test_manager.sh \
    "sipp -sf test_suite/scenarios/ims_call_uac.xml -inf test_suite/config/uac_users.csv -i 10.18.2.12 -p 12002 127.0.0.1:5060" \
    "sipp -sf test_suite/scenarios/ims_call_uas.xml -inf test_suite/config/uas_users.csv -i 10.18.2.12 -p 5060"

# 运行多轮测试(5轮)
./performance_test_manager.sh \
    "sipp -sf test_suite/scenarios/ims_call_uac.xml -inf test_suite/config/uac_users.csv -i 10.18.2.12 -p 12002 127.0.0.1:5060" \
    "sipp -sf test_suite/scenarios/ims_call_uas.xml -inf test_suite/config/uas_users.csv -i 10.18.2.12 -p 5060" \
    5
```

### 2. 高性能压测配置示例

```bash
# 高并发压测配置
UAC_CMD="sipp -sf test_suite/scenarios/ims_call_uac.xml \
    -inf test_suite/config/uac_users.csv \
    -i 10.18.2.12 -p 12002 \
    -r 200 -l 5000 \
    -max_socket 10000 \
    -t un \
    127.0.0.1:5060"

UAS_CMD="sipp -sf test_suite/scenarios/ims_call_uas.xml \
    -inf test_suite/config/uas_users.csv \
    -i 10.18.2.12 -p 5060 \
    -max_socket 10000 \
    -t un"

# 执行10轮压测
./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" 10
```

### 3. 结果分析

```bash
# 分析所有测试结果
./analyze_performance_results.py performance_results/

# 分析单个测试
./analyze_performance_results.py performance_results/ --single test_run_20241208_143022
```

## 📊 关键性能指标

### 1. 呼叫统计指标
- **总呼叫数 (TotalCallCreated)**: 测试期间创建的总呼叫数
- **成功呼叫数 (SuccessfulCall)**: 成功完成的呼叫数
- **失败呼叫数 (FailedCall)**: 失败的呼叫数
- **成功率**: 成功呼叫数/总呼叫数 × 100%
- **当前并发数 (CurrentCall)**: 当前正在进行的呼叫数

### 2. 性能指标
- **呼叫速率 (CallRate)**: 每秒处理的呼叫数 (calls/s)
- **响应时间**: 各阶段的响应时间统计
- **吞吐量**: 消息处理速度 (messages/s)

### 3. 错误分析
- **传输错误**: 网络传输层面的错误
- **协议错误**: SIP协议层面的错误
- **超时错误**: 响应超时错误
- **意外消息错误**: 收到非预期的SIP消息

## 🔧 高级配置

### 1. 自定义日志频率

```bash
# 修改统计记录频率(默认10秒)
export MONITOR_INTERVAL=5  # 5秒监控间隔
export RESTART_DELAY=60    # 60秒重启间隔

./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" 3
```

### 2. 自定义结果目录

```bash
# 指定结果保存目录
export RESULTS_BASE_DIR="/path/to/custom/results"
./performance_test_manager.sh "$UAC_CMD" "$UAS_CMD"
```

### 3. 压测参数优化建议

#### 高并发场景
```bash
# 适用于高并发场景的参数
-r 500              # 呼叫速率: 500 calls/s
-l 10000            # 最大呼叫数: 10000
-max_socket 20000   # 最大socket数: 20000
-recv_timeout 5000  # 接收超时: 5秒
-timeout 30         # 测试超时: 30秒
```

#### 长时间稳定性测试
```bash
# 适用于长时间稳定性测试的参数
-r 100              # 较低呼叫速率: 100 calls/s
-d 3600000          # 测试持续时间: 1小时
-timeout 0          # 无超时限制
-aa                 # 自动应答
```

#### 极限性能测试
```bash
# 适用于极限性能测试的参数
-r 1000             # 极高呼叫速率: 1000 calls/s
-l 50000            # 大量呼叫: 50000
-max_socket 65000   # 最大socket数
-t un               # UDP无连接模式
-nd                 # 不显示详细信息
```

## 📈 结果解读

### 1. 成功率评估标准
- **优秀 (> 95%)**: 系统表现良好，可承受当前压力
- **良好 (90-95%)**: 系统基本稳定，但有改进空间
- **一般 (80-90%)**: 系统压力较大，需要优化
- **较差 (< 80%)**: 系统无法承受当前压力，需要调整

### 2. 呼叫速率分析
- **实际速率 vs 目标速率**: 比较实际达到的呼叫速率与设置的目标速率
- **速率稳定性**: 观察呼叫速率在测试过程中的波动情况
- **峰值处理能力**: 系统能处理的最大呼叫速率

### 3. 错误模式识别
- **传输错误过多**: 可能是网络带宽或延迟问题
- **超时错误增加**: 可能是服务端处理能力不足
- **协议错误**: 可能是配置或兼容性问题

## 🛠️ 故障排查

### 1. 常见问题

#### 测试无法启动
```bash
# 检查端口占用
netstat -tulpn | grep :5060

# 检查防火墙
sudo ufw status

# 检查SIPP版本
sipp -v
```

#### 成功率异常低
```bash
# 检查错误日志
tail -f performance_results/test_run_*/uac/errors.log
tail -f performance_results/test_run_*/uas/errors.log

# 检查系统资源
top -p $(pgrep sipp)
```

#### 性能数据缺失
```bash
# 检查CSV文件
ls -la performance_results/test_run_*/*/stats.csv

# 检查权限
chmod -R 755 performance_results/
```

### 2. 性能调优建议

#### 系统层面
```bash
# 增加文件描述符限制
ulimit -n 65536

# 调整网络参数
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
sysctl -p
```

#### SIPP参数调优
```bash
# 针对高并发优化
-max_socket 65000    # 最大socket数
-recv_timeout 10000  # 接收超时
-send_timeout 10000  # 发送超时
-max_reconnect 3     # 最大重连次数
```

## 📋 最佳实践

### 1. 测试规划
1. **基线测试**: 先进行低压力测试，建立性能基线
2. **渐进加压**: 逐步增加压力，找到性能拐点
3. **稳定性测试**: 在目标压力下进行长时间测试
4. **极限测试**: 测试系统的最大承载能力

### 2. 数据收集
1. **多轮测试**: 进行多轮测试以获得统计学意义的结果
2. **环境一致性**: 确保每轮测试的环境条件一致
3. **监控系统资源**: 同时监控CPU、内存、网络等系统资源
4. **记录测试条件**: 详细记录每次测试的配置参数

### 3. 结果分析
1. **趋势分析**: 关注性能指标的变化趋势
2. **异常识别**: 及时识别和分析异常数据点
3. **对比分析**: 对比不同配置下的测试结果
4. **报告生成**: 生成详细的测试报告供决策参考

## 🔄 自动化集成

### 1. CI/CD集成示例

```bash
#!/bin/bash
# ci_performance_test.sh

# 设置测试参数
TEST_DURATION=300  # 5分钟测试
CALL_RATE=100     # 100 calls/s

# 运行性能测试
./performance_test_manager.sh \
    "sipp -sf scenarios/test.xml -r $CALL_RATE -d $TEST_DURATION 127.0.0.1:5060" \
    "sipp -sf scenarios/uas.xml -p 5060" \
    3

# 分析结果
./analyze_performance_results.py performance_results/

# 检查成功率阈值
SUCCESS_RATE=$(python3 -c "
import json
with open('performance_results/performance_summary.json') as f:
    data = json.load(f)
    print(data['overall_performance']['avg_success_rate'])
")

if (( $(echo "$SUCCESS_RATE < 95" | bc -l) )); then
    echo "性能测试失败: 成功率 $SUCCESS_RATE% < 95%"
    exit 1
fi

echo "性能测试通过: 成功率 $SUCCESS_RATE%"
```

### 2. 定时测试脚本

```bash
#!/bin/bash
# scheduled_performance_test.sh

# 每日性能测试
0 2 * * * /path/to/performance_test_manager.sh "$UAC_CMD" "$UAS_CMD" 5

# 每周详细测试
0 3 * * 0 /path/to/performance_test_manager.sh "$STRESS_UAC_CMD" "$STRESS_UAS_CMD" 10
```

## 📞 技术支持

如果在使用过程中遇到问题，请：

1. 检查日志文件中的错误信息
2. 确认SIPP版本和配置参数
3. 验证网络连接和防火墙设置
4. 查看系统资源使用情况

---

**注意**: 进行高性能压测时，请确保：
- 有足够的系统资源 (CPU、内存、网络带宽)
- 不会对生产环境造成影响
- 遵守相关的测试和安全政策
