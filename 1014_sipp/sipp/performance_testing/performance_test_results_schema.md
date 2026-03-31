# SIPP高性能压测结果数据结构

## 1. 测试运行元数据
```json
{
  "test_run_id": "perf_test_20241208_143022",
  "start_time": "2024-12-08 14:30:22",
  "end_time": "2024-12-08 14:35:45",
  "duration_seconds": 323,
  "test_config": {
    "call_rate": 100,
    "max_calls": 1000,
    "call_duration": 30,
    "concurrent_calls": 500,
    "scenario_file": "ims_call_uac.xml"
  }
}
```

## 2. 实时性能指标
```json
{
  "performance_metrics": {
    "call_statistics": {
      "total_calls_created": 1000,
      "successful_calls": 987,
      "failed_calls": 13,
      "success_rate": 98.7,
      "peak_concurrent_calls": 487
    },
    "response_times": {
      "avg_setup_time_ms": 245.3,
      "avg_call_duration_ms": 30124.7,
      "95th_percentile_setup_ms": 456.2,
      "max_setup_time_ms": 1234.5
    },
    "throughput": {
      "actual_call_rate": 98.5,
      "peak_call_rate": 105.2,
      "messages_per_second": 1247.3
    }
  }
}
```

## 3. 错误分析
```json
{
  "error_analysis": {
    "error_categories": {
      "timeout_errors": 8,
      "transport_errors": 3,
      "protocol_errors": 2,
      "unexpected_message_errors": 0
    },
    "error_rate_trend": [
      {"timestamp": "14:30:22", "error_count": 0},
      {"timestamp": "14:31:22", "error_count": 2},
      {"timestamp": "14:32:22", "error_count": 5}
    ]
  }
}
```

## 4. 系统资源使用
```json
{
  "system_resources": {
    "cpu_usage_percent": 45.2,
    "memory_usage_mb": 1024.5,
    "network_io": {
      "bytes_sent": 15728640,
      "bytes_received": 12582912,
      "packets_sent": 8456,
      "packets_received": 7234
    }
  }
}
```
