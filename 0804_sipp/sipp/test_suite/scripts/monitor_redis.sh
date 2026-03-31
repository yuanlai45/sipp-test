#!/bin/bash
###
 # @Author: gao
 # @Date: 2025-02-27 02:55:04
 # @Description: 
 # @LastEditors: gao
 # @LastEditTime: 2025-02-27 02:55:51
### 
# 文件：test_suite/scripts/monitor_redis.sh

# 监控Redis并记录到日志
LOG_FILE="/var/log/sipp_redis_monitor.log"

echo "$(date): Redis监控开始" >> "$LOG_FILE"

# 检查Redis是否正在运行
if ! redis-cli ping > /dev/null 2>&1; then
  echo "$(date): Redis连接失败，尝试重启服务" >> "$LOG_FILE"
  systemctl restart redis-server
  sleep 3
  
  # 再次检查
  if ! redis-cli ping > /dev/null 2>&1; then
    echo "$(date): Redis重启失败，请手动干预" >> "$LOG_FILE"
    exit 1
  fi
  
  echo "$(date): Redis服务已成功重启" >> "$LOG_FILE"
fi

# 检查Redis内存使用情况
MEM_USED=$(redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '[:space:]')
echo "$(date): Redis当前内存使用: $MEM_USED" >> "$LOG_FILE"

# 检查密钥总数
KEY_COUNT=$(redis-cli dbsize)
echo "$(date): Redis当前键总数: $KEY_COUNT" >> "$LOG_FILE"

exit 0
