# IMS SIPp 测试使用说明

工作目录：`cd /home/sder/sipp-test/ims_test`  
P-CSCF：`10.18.1.132:5060` | 本机 IP：`10.18.2.59` | 用户池：5000 UAC + 5000 UAS

---

## 1. 单用户注册

注册 1 个用户，收到 200 OK 即成功，不注销。

```bash
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_register_once.xml \
  -inf config/test_single_uac.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -m 1 -nd
```

---

## 2. 批量注册/注销

- **单轮**：注册 → 保持 hold_time → 注销 → 结束（`ims_register_batch.xml`）
- **循环**：注册 → 保持 → 注销 → 等待 → 重复（`ims_register_cycle.xml`）

### 2000 用户

```bash
# 生成 CSV
head -1 config/uac_users.csv > /tmp/uac_2000.csv
tail -n +2 config/uac_users.csv | head -2000 >> /tmp/uac_2000.csv

# 单轮
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_2000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 50 -l 2000 -m 2000 \
  -key hold_time 60000 \
  -nd

# 循环
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.1.132:5060 \
  --rate 50 --limit 2000 --hold 60000 --pause 30000 --rounds 10
# --hold 60000   注册后保持 60s 再注销（注册→注销间隔）
# --pause 30000  注销后等 30s 再开始下一轮（轮次间隔）
# --rounds 10    循环 10 轮后停止（0 = 无限循环）
# --timeout N    可选，运行 N 秒后自动停止
# --rate 50      每秒启动 50 个注册
# --limit 2000   同时在线用户数
```

### 5000 用户

```bash
# 生成 CSV
head -1 config/uac_users.csv > /tmp/uac_5000.csv
tail -n +2 config/uac_users.csv | head -5000 >> /tmp/uac_5000.csv

# 单轮
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_5000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 500 -l 5000 -m 5000 \
  -key hold_time 30000 \
  -nd

# 循环（参数含义同上）
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.1.132:5060 \
  --rate 500 --limit 5000 --hold 20000 --pause 20000 --rounds 2
```

### 8000 用户（UAC 5000 + UAS 前 3000 合并）

```bash
# 生成 CSV
head -1 config/uac_users.csv > /tmp/uac_8000.csv
tail -n +2 config/uac_users.csv >> /tmp/uac_8000.csv
tail -n +2 config/uas_users.csv | head -3000 >> /tmp/uac_8000.csv

# 单轮
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_8000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 100 -l 8000 -m 8000 \
  -key hold_time 100000 \
  -nd

# 循环（参数含义同上；需先生成 CSV）
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.1.132:5060 \
  --rate 100 --limit 8000 --hold 60000 --pause 30000 --rounds 10 \
  --csv /tmp/uac_8000.csv
```

> IMSI 范围：460110000010001~460110000018000（HSS 已开户）

### 10000 用户（UAC 5000 + UAS 5000 全部合并）

```bash
# 生成 CSV
head -1 config/uac_users.csv > /tmp/uac_10000.csv
tail -n +2 config/uac_users.csv >> /tmp/uac_10000.csv
tail -n +2 config/uas_users.csv >> /tmp/uac_10000.csv

# 单轮
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_10000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 1000 -l 10000 -m 10000 \
  -key hold_time 120000 \
  -nd

# 循环（参数含义同上；需先生成 CSV）
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.1.132:5060 \
  --rate 1000 --limit 10000 --hold 20000 --pause 20000 --rounds 10 \
  --csv /tmp/uac_10000.csv
```

> IMSI 范围：460110000010001~460110000020000（需 HSS 全部开户）

### 参数调整

**单轮参数：**

| 改什么 | 怎么改 |
|--------|--------|
| 用户数 | CSV 用 `head -N`，命令改 `-l N -m N` |
| 启动速率 | `-r 50`（慢）/ `-r 100`（快） |
| 注册保持时长 | `-key hold_time 120000`（120s），默认 60s |
| 保持时长计算 | `hold_time ≥ 用户数 ÷ rate × 1000` |

**循环参数：**

| 改什么 | 怎么改 |
|--------|--------|
| 在线用户数 | `--limit 500` / `--limit 2000` |
| 注册→注销间隔 | `--hold 5000`（5s）/ `--hold 30000`（30s） |
| 轮次间隔 | `--pause 1000`（1s）/ `--pause 5000`（5s） |
| 循环轮数 | `--rounds 10`（跑 10 轮停止），不加则无限 |
| 限时运行 | `--timeout 300`（5min 后停止） |

### 健康指标

- `Retrans` > 0 → IMS 响应慢
- `Failed call` > 0 → 200 OK 超时
- `200 <---` < `REGISTER --->` → 有请求丢失

---

## 3. 呼叫测试（UAC ↔ UAS）

UAS 先起（被叫侧），UAC 后起（主叫侧）。每条命令自带 `LOGDIR` 初始化，可直接复制执行。

### UAS（被叫，先起）

```bash
export LOGDIR=logs/call_test_period/custom_test_$(date +%Y%m%d_%H%M%S) && mkdir -p "$LOGDIR" && \
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_call_uas.xml \
  -oocsf scenarios/ims_default_response.xml \
  -inf config/uas_users.csv \
  -i 10.18.2.59 -p 10000 -mp 50000 -t un \
  -r 1 -l 1 -timeout 100 -recv_timeout 15000 -nd -fd 1 -max_socket 4000 \
  -trace_screen -screen_file "$LOGDIR/uas_screen.log" -screen_overwrite false
```

### UAC（主叫，后起）

```bash
export LOGDIR=logs/call_test_period/custom_test_$(date +%Y%m%d_%H%M%S) && mkdir -p "$LOGDIR" && \
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_call_uac.xml \
  -inf config/uac_users.csv \
  -i 10.18.2.59 -p 20000 -mp 60000 -t un \
  -r 1 -l 1 -nd -aa -max_socket 4000 \
  -set call_hold_time 10000 \
  -fd 1 -timeout 100 \
  -recv_timeout 15000 \
  -m 1 \
  -trace_screen -screen_file "$LOGDIR/uac_screen.log" -screen_overwrite false \
  -trace_err   -error_file  "$LOGDIR/uac_errors.log" -error_overwrite false
```

### 2000 用户压测（单轮）

> 每个 SIPp 实例独立完成 REGISTER → 等待 40s → INVITE → BYE。
> UAS 需先起并注册完毕，UAC 再起。

**UAS（先起）**

```bash
export LOGDIR=logs/call_test_period/stress_$(date +%Y%m%d_%H%M%S) && mkdir -p "$LOGDIR" && \
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_call_uas.xml \
  -oocsf scenarios/ims_default_response.xml \
  -inf config/uas_users.csv \
  -i 10.18.2.59 -p 10000 -mp 50000 -t un \
  -r 100 -l 2000 -timeout 300 -recv_timeout 15000 -nd -fd 1 -max_socket 4000 \
  -trace_screen -screen_file "$LOGDIR/uas_screen.log" -screen_overwrite false
```

**UAC（后起）**

```bash
export LOGDIR=logs/call_test_period/stress_$(date +%Y%m%d_%H%M%S) && mkdir -p "$LOGDIR" && \
./sipp 10.18.1.132:5060 \
  -sf scenarios/ims_call_uac.xml \
  -inf config/uac_users.csv \
  -i 10.18.2.59 -p 20000 -mp 60000 -t un \
  -r 100 -l 2000 -nd -aa -max_socket 4000 \
  -set call_hold_time 10000 \
  -fd 1 -timeout 200 \
  -recv_timeout 15000 \
  -m 2000 \
  -trace_screen -screen_file "$LOGDIR/uac_screen.log" -screen_overwrite false \
  -trace_err   -error_file  "$LOGDIR/uac_errors.log" -error_overwrite false
```

### 关键参数说明

| 参数 | 含义 |
|------|------|
| `-oocsf` | out-of-call 场景，用于 UAS 响应计划外请求 |
| `-mp`    | RTP/媒体端口起始（UAC/UAS 必须错开） |
| `-p`     | 信令端口（UAC=20000、UAS=10000，避免冲突） |
| `-aa`    | 自动回 200 OK 响应（UAC 侧处理 INVITE 之外请求） |
| `-fd 1`  | 日志刷新间隔 1s |
| `-nd`    | 关闭默认行为（不自动回 200 到计划外请求） |
| `-set call_hold_time 10000` | 通话保持 10s 后挂断 |
| `-m 2000` | 总共发起 2000 通呼叫 |
| `-recv_timeout 15000` | 15s 未收到预期响应即失败 |
| `-max_socket 4000` | 最大并发 socket |

> 已从粘贴命令改动：`-i 10.18.2.12` → `-i 10.18.2.59`（本机）。

---

## 环境信息

| 项目 | 值 |
|------|-----|
| 本机 IP | `10.18.2.59` |
| P-CSCF | `10.18.1.132:5060` |
| UAC IMSI | `460110000010001` ~ `460110000015000` |
| UAS IMSI | `460110000015001` ~ `460110000020000` |
| Domain | `ims.mnc011.mcc460.3gppnetwork.org` |

重新生成用户 CSV：`bash config/generate_users.sh`
