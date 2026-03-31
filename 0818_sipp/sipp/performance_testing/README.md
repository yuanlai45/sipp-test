# SIPP性能测试工具套件

这个目录包含了用于SIPP高性能压测的完整工具套件。

## 📁 目录结构

```
performance_testing/
├── README.md                           # 本文件 - 工具套件说明
├── performance_test_manager.sh         # 主测试管理脚本
├── analyze_performance_results.py      # 结果分析工具
├── performance_testing_guide.md        # 详细使用指南
├── performance_test_results_schema.md  # 数据结构说明
└── examples/                           # 使用示例(待创建)
    ├── basic_test.sh                   # 基础测试示例
    ├── high_concurrency_test.sh        # 高并发测试示例
    └── stability_test.sh               # 稳定性测试示例
```

## 🚀 快速开始

### 1. 基本使用
```bash
cd performance_testing

# 运行单轮测试
./performance_test_manager.sh \
    "sipp -sf ../test_suite/scenarios/ims_call_uac.xml -inf ../test_suite/config/uac_users.csv -i 10.18.2.12 -p 12002 127.0.0.1:5060" \
    "sipp -sf ../test_suite/scenarios/ims_call_uas.xml -inf ../test_suite/config/uas_users.csv -i 10.18.2.12 -p 5060"
```

### 2. 结果分析
```bash
# 分析测试结果
./analyze_performance_results.py performance_results/
```

## 📖 详细文档

- **[performance_testing_guide.md](./performance_testing_guide.md)** - 完整的使用指南，包含配置说明、最佳实践等
- **[performance_test_results_schema.md](./performance_test_results_schema.md)** - 测试结果数据结构说明

## 🛠️ 工具说明

### performance_test_manager.sh
- **功能**: 双实例SIPP测试管理
- **特性**: 自动启动/停止、实时监控、多轮测试、结果收集
- **用法**: `./performance_test_manager.sh <UAC_CMD> <UAS_CMD> [轮次]`

### analyze_performance_results.py
- **功能**: 测试结果分析和报告生成
- **特性**: 统计分析、趋势图表、HTML报告、JSON数据导出
- **依赖**: `pip install pandas matplotlib`
- **用法**: `./analyze_performance_results.py <结果目录>`

## 📊 输出结果

测试完成后，结果将保存在 `performance_results/` 目录下：

- **原始数据**: CSV统计文件、日志文件
- **分析报告**: JSON汇总、HTML报告
- **可视化图表**: 性能趋势图

## ⚠️ 注意事项

1. **系统要求**: 确保有足够的文件描述符限制 (`ulimit -n 65536`)
2. **网络环境**: 确保测试网络环境稳定，防火墙配置正确
3. **资源监控**: 大规模测试时注意监控系统资源使用情况
4. **测试隔离**: 避免在生产环境进行高强度压测

## 🔧 环境配置

```bash
# 设置文件描述符限制
ulimit -n 65536

# 安装Python依赖(用于结果分析)
pip3 install pandas matplotlib

# 检查SIPP版本
sipp -v
```

## 📞 技术支持

如遇问题，请检查：
1. 日志文件中的错误信息
2. 系统资源使用情况
3. 网络连接状态
4. SIPP配置参数

---

**版本**: 1.0  
**更新时间**: 2024-12-08  
**适用于**: SIPP 3.x 及以上版本
