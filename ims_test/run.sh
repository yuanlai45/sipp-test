#!/bin/bash
# ============================================================
# IMS SIPp 测试快捷启动脚本
# 用法: ./run.sh <场景> [选项]
#
# 场景:
#   register_once     单次注册测试 (快速验证)
#   register_cycle    循环注册/注销压力测试
#   register_basic    持续注册保活测试
#   register_ipsec    IPSec AKA 注册测试
#   call              呼叫测试 (需同时启动 uac + uas)
#
# 示例:
#   ./run.sh register_once  -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 -m 1
#   ./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 10 --limit 500 --hold 5000 --pause 1000
#   ./run.sh register_basic -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 10 --limit 500
# ============================================================

SIPP="$(dirname "$0")/sipp"
SCENARIOS="$(dirname "$0")/scenarios"
CONFIG="$(dirname "$0")/config"

SCENARIO="$1"; shift

LOCAL_IP="10.18.2.59"
LOCAL_PORT="10000"
REMOTE="10.18.2.132:5060"
RATE=10
LIMIT=500
CALLS=0          # 0 = 无限循环
HOLD=5000        # register_cycle: 注册保持时长 (ms)
PAUSE=1000       # register_cycle: 注销后等待时长 (ms)
ROUNDS=0         # register_cycle: 循环轮数 (0=无限)
CSV="$CONFIG/uac_users.csv"
TIMEOUT=""

# 解析通用参数
while [[ $# -gt 0 ]]; do
  case "$1" in
    -i|--local-ip)    LOCAL_IP="$2";   shift 2 ;;
    -p|--port)        LOCAL_PORT="$2"; shift 2 ;;
    -r|--remote)      REMOTE="$2";     shift 2 ;;
    --rate)           RATE="$2";       shift 2 ;;
    --limit|-l)       LIMIT="$2";      shift 2 ;;
    -m|--calls)       CALLS="$2";      shift 2 ;;
    --hold)           HOLD="$2";       shift 2 ;;
    --pause)          PAUSE="$2";      shift 2 ;;
    --rounds)         ROUNDS="$2";     shift 2 ;;
    --csv)            CSV="$2";        shift 2 ;;
    --timeout)        TIMEOUT="-timeout $2"; shift 2 ;;
    *) echo "未知选项: $1"; exit 1 ;;
  esac
done

# 构建 -m 参数 (0 表示不传，即无限)
M_ARG=""
[[ "$CALLS" -gt 0 ]] && M_ARG="-m $CALLS"

case "$SCENARIO" in
  register_once)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_register_once.xml" \
      -inf "$CONFIG/test_single_uac.csv" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      $M_ARG $TIMEOUT -recv_timeout 10000 -nd
    ;;

  register_cycle)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_register_cycle.xml" \
      -inf "$CSV" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      -r "$RATE" -l "$LIMIT" \
      -key reg_hold_time "$HOLD" \
      -key dereg_pause "$PAUSE" \
      -key max_rounds "$ROUNDS" \
      $M_ARG $TIMEOUT -nd
    ;;

  register_basic)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_register_basic.xml" \
      -inf "$CSV" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      -r "$RATE" -l "$LIMIT" \
      $M_ARG $TIMEOUT -nd
    ;;

  register_ipsec)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_register_ipsec_auth.xml" \
      -inf "$CSV" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      -r "$RATE" -l "$LIMIT" \
      $M_ARG $TIMEOUT -nd
    ;;

  call_uac)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_call_uac.xml" \
      -inf "$CSV" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      -r "$RATE" -l "$LIMIT" \
      $M_ARG $TIMEOUT -nd
    ;;

  call_uas)
    "$SIPP" "$REMOTE" \
      -sf "$SCENARIOS/ims_call_uas.xml" \
      -inf "$CONFIG/uas_users.csv" \
      -i "$LOCAL_IP" -p "$LOCAL_PORT" -t un \
      -l "$LIMIT" \
      $M_ARG $TIMEOUT -nd
    ;;

  *)
    echo "用法: $0 <场景> [选项]"
    echo "场景: register_once | register_cycle | register_basic | register_ipsec | call_uac | call_uas"
    echo "选项:"
    echo "  -i <ip>        本地IP (默认: $LOCAL_IP)"
    echo "  -p <port>      本地端口 (默认: $LOCAL_PORT)"
    echo "  -r <ip:port>   远端地址 (默认: $REMOTE)"
    echo "  --rate <n>     呼叫速率 cps (默认: $RATE)"
    echo "  --limit <n>    最大并发 (默认: $LIMIT)"
    echo "  -m <n>         总呼叫数 (默认: 无限)"
    echo "  --hold <ms>    注册保持时长 ms, 用于 register_cycle (默认: $HOLD)"
    echo "  --pause <ms>   注销后等待 ms, 用于 register_cycle (默认: $PAUSE)"
    echo "  --rounds <n>   循环轮数, 0=无限 (默认: $ROUNDS)"
    echo "  --csv <file>   指定 CSV 文件 (默认: config/uac_users.csv)"
    echo "  --timeout <s>  测试超时秒数"
    exit 1
    ;;
esac
