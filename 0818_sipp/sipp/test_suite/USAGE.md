# SIPp IMS 测试套件使用手册

## 目录

- [项目结构](#项目结构)
- [相关文件说明](#相关文件说明)
- [CSV 用户数据格式](#csv-用户数据格式)
- [SIPp 关键参数说明](#sipp-关键参数说明)
- [测试场景：注册消息测试](#测试场景注册消息测试)
- [测试场景：呼叫测试（UAC + UAS）](#测试场景呼叫测试uac--uas)
- [快速启动脚本方式](#快速启动脚本方式)
- [日志与调试](#日志与调试)
- [常见问题](#常见问题)

---

## 项目结构

```
/home/sder/sipp-test/0818_sipp/sipp/
├── sipp                          # SIPp 可执行文件
├── test_suite/
│   ├── config/
│   │   ├── uac_users.csv         # UAC 用户数据（主叫方）
│   │   ├── uas_users.csv         # UAS 用户数据（被叫方）
│   │   ├── users_0.csv           # 注册测试用用户数据
│   │   ├── test_config.env       # 测试环境变量配置
│   │   └── generate_users.sh     # 用户数据生成脚本
│   ├── scenarios/
│   │   ├── ims_register_basic.xml         # 基本注册场景（含刷新+SUBSCRIBE）
│   │   ├── ims_register_ipsec_auth.xml    # IPSec AKA 认证注册场景
│   │   ├── ims_call_uac_register.xml      # 仅注册/刷新场景（供注册测试用）
│   │   ├── ims_call_uac.xml               # 呼叫测试 UAC 场景（含先注册再呼叫）
│   │   ├── ims_call_uas.xml               # 呼叫测试 UAS 场景（含先注册再接听）
│   │   ├── ims_default_response.xml       # UAS 侧默认应答场景（完整流程）
│   │   └── ims_default_response_temp.xml  # UAS 侧简化应答场景（临时版本）
│   ├── scripts/
│   │   ├── ims_register_test.sh  # 注册测试启动脚本
│   │   ├── ims_call_test.sh      # 呼叫测试启动脚本
│   │   ├── ims_common.sh         # 公共函数库
│   │   ├── monitor_redis.sh      # Redis 监控脚本
│   │   ├── save_security_server.sh
│   │   └── view_reports.sh       # 测试报告查看脚本
│   └── logs/                     # 测试日志输出目录
```

---

## 相关文件说明

### 场景文件（scenarios/）

| 文件 | 用途 | 使用场景 |
|---|---|---|
| `ims_register_basic.xml` | 基本注册（无认证），含 SUBSCRIBE/NOTIFY 刷新 | 注册功能测试 |
| `ims_register_ipsec_auth.xml` | IPSec + AKAv1-MD5 双步认证注册 | IPSec 认证注册测试 |
| `ims_call_uac_register.xml` | 仅注册/刷新（不发起呼叫）| 纯注册保活测试 |
| `ims_call_uac.xml` | 先注册再发起 INVITE 呼叫（UAC 主叫）| 呼叫性能测试 |
| `ims_call_uas.xml` | 先注册再等待接听（UAS 被叫）| 呼叫性能测试 |
| `ims_default_response_temp.xml` | UAS 侧自动回复（接收 INVITE → 应答整个呼叫流程）| 配合 UAC 呼叫测试使用 |

### 配置文件（config/）

| 文件 | 用途 |
|---|---|
| `uac_users.csv` | UAC 主叫用户列表，含 IMSI/MSISDN/域/SPI/密钥等字段 |
| `uas_users.csv` | UAS 被叫用户列表 |
| `users_0.csv` | 注册测试单实例用户列表 |
| `test_config.env` | 本地/远端 IP、速率、时长等基础环境变量 |
| `generate_users.sh` | 批量生成 UAC/UAS 用户 CSV 的脚本 |

---

## CSV 用户数据格式

CSV 文件第一行为模式声明，支持 `SEQUENTIAL`（顺序）或 `RANDOM`（随机）。

### UAC 用户文件（`uac_users.csv`）字段定义

```
SEQUENTIAL
<field0>;<field1>;<field2>;<field3>;<field4>;<field5>;<field6>;<field7>;<field8>;<field9>;<field10>
```

| 字段 | 变量 | 含义 | 示例 |
|---|---|---|---|
| field0 | `[field0]` | IMSI（用户标识） | `460119000000001` |
| field1 | `[field1]` | SIP 域名 | `ims.mnc011.mcc460.3gppnetwork.org` |
| field2 | `[field2]` | Client SPI（IPSec 用）| `0x1a2b3c4d` |
| field3 | `[field3]` | Server SPI（IPSec 用）| `0x5e6f7a8b` |
| field4 | `[field4]` | 服务器端口 | `5060` |
| field5 | `[field5]` | AKA 密钥 K | `31323334353637383930313233343536` |
| field6 | `[field6]` | AKA OP 值 | `19DF73C9C56A90EE581D52F1EBD53E72` |
| field7 | `[field7]` | AMF 值 | `8000` |
| field8 | `[field8]` | 角色标识 | `uac` |
| field9 | `[field9]` | 主叫 MSISDN | `600001` |
| field10 | `[field10]` | 被叫 MSISDN | `600002` |

### UAS 用户文件（`uas_users.csv`）字段定义

| 字段 | 变量 | 含义 |
|---|---|---|
| field0 | `[field0]` | IMSI |
| field1 | `[field1]` | SIP 域名 |
| field2~field7 | 同 UAC | SPI/密钥等 |
| field8 | `[field8]` | 角色标识（`uas`） |
| field9 | `[field9]` | 本端 MSISDN |

### 重新生成用户数据

```bash
cd /home/sder/sipp-test/0818_sipp/sipp
bash test_suite/config/generate_users.sh
```

> 默认生成 2000 对用户（4000 个），起始 IMSI `460119000000001`，起始 MSISDN `600001`。

---

## SIPp 关键参数说明

| 参数 | 含义 |
|---|---|
| `<IP>:<PORT>` | 远端 SIP 服务器地址（第一个位置参数）|
| `-sf <file>` | 主场景文件（Scenario File）|
| `-oocsf <file>` | 接收到非预期请求时使用的备用场景文件（Out-Of-Call Scenario）|
| `-inf <file>` | 注入用户数据的 CSV 文件（Injection File）|
| `-i <IP>` | 本地绑定 IP |
| `-p <port>` | 本地 SIP 信令端口 |
| `-mp <port>` | 媒体（RTP）起始端口 |
| `-t un` | 传输方式：UDP 无重传（`un` = UDP Non-reliable）|
| `-r <N>` | 每秒新建呼叫/注册速率 |
| `-l <N>` | 最大并发呼叫数 |
| `-m <N>` | 总呼叫数上限（达到后退出）|
| `-timeout <sec>` | 全局超时（秒），超时后 SIPp 退出 |
| `-recv_timeout <ms>` | 单个 `recv` 步骤等待超时（毫秒）|
| `-nd` | 无延迟模式（No Delay），不等待统计屏幕刷新 |
| `-aa` | 自动回复 200 OK（Auto Answer，用于 UAS 简单测试）|
| `-fd <N>` | 统计刷新频率（秒）|
| `-max_socket <N>` | 最大 socket 数量限制 |
| `-set <key> <value>` | 设置全局变量，供场景文件中 `[key]` 使用 |
| `-trace_screen` | 启用屏幕日志 |
| `-screen_file <file>` | 屏幕日志输出文件 |
| `-screen_overwrite false` | 不覆盖已有日志（追加模式）|
| `-trace_err` | 启用错误日志 |
| `-error_file <file>` | 错误日志输出文件 |
| `-error_overwrite false` | 不覆盖已有错误日志 |

---

## 测试场景：注册消息测试

### 场景说明

注册测试发送 `REGISTER` 请求到 IMS 核心网，可选包含后续 `SUBSCRIBE`（reg 事件）和周期刷新注册。

有两种注册场景文件可选：

| 场景文件 | 流程 |
|---|---|
| `ims_register_basic.xml` | REGISTER → 200 OK → SUBSCRIBE → 200 OK → NOTIFY → 200 OK → 周期刷新 → 最终注销 |
| `ims_register_ipsec_auth.xml` | REGISTER → 401 Unauthorized → REGISTER（AKA 认证）→ 200 OK → 周期刷新 |

---

### 方式一：直接用 SIPp 命令（基本注册）

```bash
/home/sder/sipp-test/0818_sipp/sipp/sipp 10.18.2.25:6060 \
    -sf /home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios/ims_register_basic.xml \
    -oocsf /home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios/ims_default_response_temp.xml \
    -inf /home/sder/sipp-test/0818_sipp/sipp/test_suite/config/users_0.csv \
    -i 10.18.2.59 -p 10000 -mp 50000 -t un \
    -r 10 -l 100 \
    -timeout 60 -recv_timeout 10000 \
    -nd -fd 1 -max_socket 4000 \
    -set reg_count 3 \
    -trace_screen -screen_file /tmp/register_screen.log -screen_overwrite false \
    -trace_err   -error_file  /tmp/register_errors.log  -error_overwrite false
```

**关键配置点：**

| 需修改的参数 | 说明 |
|---|---|
| `10.18.2.25:6060` | 改为实际 IMS 服务器（P-CSCF / S-CSCF）地址和端口 |
| `-i 10.18.2.59` | 改为本机实际 IP |
| `-p 10000` | 本地 SIP 端口，避免与其他进程冲突 |
| `-mp 50000` | 媒体端口起始值 |
| `-r 10` | 注册速率（每秒 10 个新注册）|
| `-l 100` | 最大并发注册数 |
| `-timeout 60` | 测试持续 60 秒 |
| `-inf users_0.csv` | 注册测试用用户文件 |
| `-set reg_count 3` | 每个用户最多刷新注册 3 次（`ims_register_basic.xml` 专用参数）|

---

### 方式二：使用脚本（推荐）

#### 基本注册（无认证）

```bash
cd /home/sder/sipp-test/0818_sipp/sipp

sudo bash test_suite/scripts/ims_register_test.sh \
    --scenario basic \
    --local-ip 10.18.2.59 \
    --remote-ip 10.18.2.25:6060 \
    --initial-port 10000 \
    --users 100 \
    --rate 10 \
    --duration 60 \
    --reg-count 3
```

#### IPSec AKA 认证注册

```bash
cd /home/sder/sipp-test/0818_sipp/sipp

sudo bash test_suite/scripts/ims_register_test.sh \
    --scenario ipsec_auth \
    --local-ip 10.18.2.59 \
    --remote-ip 10.18.2.25:6060 \
    --initial-port 10000 \
    --users 50 \
    --rate 5 \
    --duration 60
```

> IPSec 模式需要 root 权限，且依赖 Redis 服务运行（用于存储 Security-Server 信息）。

#### 脚本参数说明

| 参数 | 说明 | 默认值 |
|---|---|---|
| `--scenario` | `basic`（基本）或 `ipsec_auth`（IPSec 认证）| 必填 |
| `--local-ip` | 本地 IP | 必填 |
| `--remote-ip` | 远端 IP:端口 | 必填 |
| `--initial-port` | 起始 SIP 端口 | 必填 |
| `--users` | 并发用户数 | 必填 |
| `--rate` | 每秒注册数 | 必填 |
| `--duration` | 测试持续时间（秒）| 必填 |
| `--reg-period` | 注册刷新周期（秒）| `300` |
| `--reg-count` | 每用户注册刷新次数 | `1` |
| `--instances` | SIPp 并发实例数 | `1` |
| `--initial-imsi` | 起始 IMSI | `462200000000000` |
| `--initial-msisdn` | 起始 MSISDN | `220000` |

---

### 场景内部流程（ims_register_basic.xml）

```
SIPp                          IMS 核心网 (P-CSCF/S-CSCF)
  |                                    |
  |--- REGISTER (Expires: 18000) ----> |
  |<-- 100 Trying (可选) ------------- |
  |<-- 200 OK (含 Expires) ----------- |   ← 提取 expires，计算刷新时间
  |                                    |
  |--- SUBSCRIBE (Event: reg) -------> |   ← 订阅注册状态
  |<-- 200 OK ------------------------ |
  |<-- NOTIFY ------------------------ |
  |--- 200 OK (for NOTIFY) ---------> |
  |                                    |
  | [等待 expires/2 时间]              |
  |                                    |
  |--- REGISTER (刷新) ------------->  |   ← 周期刷新（循环）
  |<-- 200 OK ------------------------ |
  |                                    |
  | [达到 reg_count 次后]              |
  |                                    |
  |--- REGISTER (Expires: 0) -------> |   ← 注销
  |<-- 200 OK ------------------------ |
```

---

## 测试场景：呼叫测试（UAC + UAS）

呼叫测试需要同时启动 **UAS（被叫）** 和 **UAC（主叫）** 两个 SIPp 实例，且使用不同的 IP 端口。

### 第一步：启动 UAS（被叫端）

```bash
/home/sder/sipp-test/0818_sipp/sipp/sipp 10.18.2.25:6060 \
    -sf /home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios/ims_call_uas.xml \
    -oocsf /home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios/ims_default_response_temp.xml \
    -inf /home/sder/sipp-test/0818_sipp/sipp/test_suite/config/uas_users.csv \
    -i 10.18.2.59 -p 10000 -mp 50000 -t un \
    -r 200 -l 1000 -timeout 11 -recv_timeout 60000 -nd -fd 1 -max_socket 8000 \
    -trace_screen -screen_file /tmp/uas_screen.log -screen_overwrite false \
    -trace_err -error_file /tmp/uas_errors.log -error_overwrite false
```

### 第二步：启动 UAC（主叫端）

```bash
/home/sder/sipp-test/0818_sipp/sipp/sipp 10.18.2.25:6060 \
    -sf /home/sder/sipp-test/0818_sipp/sipp/test_suite/scenarios/ims_call_uac.xml \
    -inf /home/sder/sipp-test/0818_sipp/sipp/test_suite/config/uac_users.csv \
    -i 10.18.2.59 -p 20000 -mp 60000 -t un \
    -r 200 -l 1000 -nd -aa -max_socket 8000 \
    -set call_hold_time 10000 \
    -fd 1 -timeout 11 \
    -recv_timeout 15000 \
    -m 1000 \
    -trace_screen -screen_file /tmp/uac_screen.log -screen_overwrite false \
    -trace_err -error_file /tmp/uac_errors.log -error_overwrite false
```

**注意：**
- UAS 使用端口 `-p 10000`，媒体端口 `-mp 50000`
- UAC 使用端口 `-p 20000`，媒体端口 `-mp 60000`（端口范围不能重叠）
- `-set call_hold_time 10000` 设置通话保持时间为 10000ms（10 秒）
- `-m 1000` 表示 UAC 完成 1000 次呼叫后自动退出
- UAS 先于 UAC 启动，确保被叫端就绪

### 呼叫流程（ims_call_uac.xml）

```
UAC (主叫)                         IMS 核心网                       UAS (被叫)
   |                                    |                                |
   |--- REGISTER ---------------------->|                                |
   |<-- 200 OK (注册成功) ------------- |                                |
   | [等待 15 秒]                       |                                |
   |--- INVITE -----------------------> |--------INVITE----------------> |
   |<-- 100 Trying -------------------- |                                |
   |<-- 183 Session Progress (SDP) ---- |<-- 183 Session Progress ------ |
   |--- PRACK -----------------------> |                                |
   |<-- 200 OK (PRACK) ---------------- |                                |
   |--- UPDATE (SDP 协商) -----------> |                                |
   |<-- 200 OK (UPDATE) --------------- |                                |
   |<-- 180 Ringing ------------------- |<-- 180 Ringing --------------- |
   |<-- 200 OK (接听) ----------------- |<-- 200 OK -------------------- |
   |--- ACK -------------------------> |                                |
   | [通话保持 call_hold_time ms]       |                                |
   |--- BYE -------------------------> |--------BYE-------------------> |
   |<-- 200 OK ------------------------ |<-- 200 OK -------------------- |
```

---

## 快速启动脚本方式

```bash
cd /home/sder/sipp-test/0818_sipp/sipp

# 呼叫测试（完整参数示例）
sudo bash test_suite/scripts/ims_call_test.sh \
    --local-ip 10.18.2.59 \
    --remote-ip 10.18.2.25:6060 \
    --users 4000 \
    --rate 500 \
    --call-hold 10 \
    --call-wait 5 \
    --call-again 1 \
    --auth none \
    --initial-port 10000 \
    --initial-media-port 50000
```

---

## 日志与调试

### 实时查看运行日志

```bash
# 查看 UAS 屏幕输出
tail -f /tmp/uas_screen.log

# 查看 UAC 屏幕输出
tail -f /tmp/uac_screen.log

# 查看错误
cat /tmp/uas_errors.log
cat /tmp/uac_errors.log
```

### 测试内部统计日志

脚本启动的实例会在 `test_suite/logs/` 下生成日志：

```
test_suite/logs/
├── register_test/
│   ├── sipp_0_screen.log    # SIPp 统计屏幕
│   └── sipp_0_error.log     # 错误日志
```

---

## 常见问题

### 1. 端口冲突

**现象：** `bind: Address already in use`

**解决：**
```bash
# 查找占用端口的进程
sudo ss -tulnp | grep 10000
# 或
sudo fuser 10000/udp
```
更换 `-p` 参数为未占用端口。

---

### 2. 注册无响应（recv_timeout 超时）

**可能原因：**
- 远端服务器地址/端口错误
- 防火墙阻断 UDP

**验证连通性：**
```bash
# 用 nmap 检查 UDP 端口
nmap -sU -p 6060 10.18.2.25
```

---

### 3. 修改注册域名

场景文件中的域名 `ims.mnc011.mcc460.3gppnetwork.org` 从 CSV 的 `[field1]` 读取，  
修改 `users_0.csv` / `uac_users.csv` / `uas_users.csv` 中对应列即可，无需修改场景文件。

---

### 4. 调整注册有效期（Expires）

`ims_register_basic.xml` 中硬编码为 `Expires: 18000`，如需修改：

打开 `test_suite/scenarios/ims_register_basic.xml`，修改第 31 行和第 124 行的 `Expires` 值：

```xml
Expires: 3600
```

---

### 5. 重新生成用户数据

修改 `generate_users.sh` 中的起始值后执行：

```bash
bash /home/sder/sipp-test/0818_sipp/sipp/test_suite/config/generate_users.sh
```

| 变量 | 说明 |
|---|---|
| `start_imsi` | 起始 IMSI，默认 `460119000000000` |
| `start_msisdn` | 起始 MSISDN，默认 `600000` |
| `domain` | SIP 域名 |
| `k` / `op` / `amf` | AKA 认证参数（所有用户共用）|
