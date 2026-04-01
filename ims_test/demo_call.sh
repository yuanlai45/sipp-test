#!/bin/bash
# ============================================================
# IMS 单呼叫 Demo 脚本
# 用法: ./demo_call.sh [远端地址] [本地IP]
#   默认: ./demo_call.sh 10.18.2.132:5060 10.18.2.59
#
# 流程:
#   1. 注册 UAS (IMSI 460110000015001, MSISDN 13507315001, port 10001)
#   2. 启动 UAS 监听 INVITE (background, port 10001)
#   3. UAC 注册 + 发起呼叫 (IMSI 460110000010001 → 13507315001, port 10000)
#   4. 通话 5 秒后 UAC 挂断
# ============================================================

SIPP="$(dirname "$0")/sipp"
SCENARIOS="$(dirname "$0")/scenarios"
CONFIG="$(dirname "$0")/config"

REMOTE="${1:-10.18.2.132:5060}"
LOCAL_IP="${2:-10.18.2.59}"

UAC_PORT=10000
UAS_PORT=10001

# 退出时自动清理后台进程
cleanup() {
  kill $UAS_PID 2>/dev/null
  fuser -k ${UAC_PORT}/udp 2>/dev/null
  fuser -k ${UAS_PORT}/udp 2>/dev/null
}
trap cleanup EXIT INT TERM

# 清理可能残留占用端口的上一次进程
echo "清理进程占用的端口 $UAC_PORT/$UAS_PORT..."
fuser -k ${UAC_PORT}/udp 2>/dev/null; fuser -k ${UAS_PORT}/udp 2>/dev/null
sleep 1

echo "============================================"
echo " IMS 单呼叫 Demo"
echo " 远端: $REMOTE    本地: $LOCAL_IP"
echo " UAC: 460110000010001 (MSISDN 13507310001) port $UAC_PORT"
echo " UAS: 460110000015001 (MSISDN 13507315001) port $UAS_PORT"
echo "============================================"

# ---------- Step 1: 启动 UAS（注册 + 等待来电）----------
echo ""
echo "[1/2] 启动 UAS (注册 + 等待来电, port $UAS_PORT)..."
"$SIPP" "$REMOTE" \
  -sf "$SCENARIOS/ims_uas_combined.xml" \
  -oocsf "$SCENARIOS/ims_call_uas_demo.xml" \
  -inf "$CONFIG/test_single_uas.csv" \
  -i "$LOCAL_IP" -p "$UAS_PORT" -t u1 \
  -m 1 -timeout 90 -nd &
UAS_PID=$!
echo "UAS 已启动 (PID: $UAS_PID)"

# 等待 UAS 注册完成（ims_uas_combined.xml 注册约需 2 秒）
sleep 4

# ---------- Step 2: UAC 注册 + 发起呼叫 ----------
echo ""
echo "[2/2] UAC 注册并发起呼叫..."
"$SIPP" "$REMOTE" \
  -sf "$SCENARIOS/ims_call_uac_demo.xml" \
  -inf "$CONFIG/test_single_uac.csv" \
  -i "$LOCAL_IP" -p "$UAC_PORT" -t u1 \
  -m 1 -nd

UAC_STATUS=$?

echo "等待 UAS 呼叫处理完成..."
wait $UAS_PID
UAS_STATUS=$?

echo ""
echo "============================================"
if [ $UAC_STATUS -eq 0 ] && [ $UAS_STATUS -eq 0 ]; then
  echo " Demo 成功完成 ✓"
else
  echo " Demo 结束 (UAC: $UAC_STATUS, UAS: $UAS_STATUS)"
fi
echo "============================================"
