#!/bin/bash
###
 # @Author: gao
 # @Date: 2025-02-27 02:51:50
 # @Description: 
 # @LastEditors: gao
 # @LastEditTime: 2025-03-05 01:53:55
### 
# 文件：test_suite/scripts/save_security_server.sh

# 参数解析
USERNAME="$1"
# 将第2个参数及之后的所有参数作为一个整体处理
shift 1
SECURITY_SERVER="$*"

# 确保安装了redis-cli
if ! command -v redis-cli &> /dev/null; then
    echo "错误：未找到redis-cli，请安装Redis客户端" >&2
    exit 1
fi

# 生成唯一键（使用组合键确保唯一性）
KEY="sipp:security:${USERNAME}"

# 将Security-Server信息保存到Redis
# 设置过期时间为1小时（3600秒），可以根据需要调整
redis-cli SET "$KEY" "$SECURITY_SERVER" EX 3600 > /dev/null
if [ $? -ne 0 ]; then
    echo "错误：无法将数据保存到Redis" >&2
    exit 1
fi

exit 0
