# IMS SIPp 测试使用说明

## 环境信息

| 参数 | 值 |
|------|-----|
| 本地 IP | `10.18.2.59` |
| 远端地址 | `10.18.2.132:5060` |
| 本地起始端口 | `10000` |
| 传输协议 | UDP (`-t un`) |
| UAC IMSI 范围 | `460110000010001` – `460110000015000` (5000 用户) |
| UAC MSISDN 范围 | `13507310001` – `13507315000` |
| UAS IMSI 范围 | `460110000015001` – `460110000020000` (5000 用户) |
| UAS MSISDN 范围 | `13507315001` – `13507320000` |
| K 密钥 | `12345678901234567890123456789012` |
| OP | `212e3b94279cb0f8095a55e8ef5569f7` |
| AMF | `8000` |
| Domain | `ims.mnc011.mcc460.3gppnetwork.org` |

---

## 快速开始

```bash
cd /home/sder/sipp-test/ims_test
```

---

## 场景一：单次注册验证

用于快速验证注册流程是否正常。发送 1 条 REGISTER，收到 200 OK 即成功。

```bash
./run.sh register_once -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 -m 1
```

**参数说明：**

| 参数 | 值 | 说明 |
|------|----|------|
| `-i` | `10.18.2.59` | 本地 IP |
| `-p` | `10000` | 本地端口 |
| `-r` | `10.18.2.132:5060` | 远端 P-CSCF/I-CSCF 地址 |
| `-m` | `1` | 总呼叫数（1 = 单次） |

**预期输出：**
```
0 : REGISTER ---------->   1
1 :      100 <----------   1
2 :      200 <----------   1
Successful call: 1
```

---

## 场景二：循环注册/注销压力测试

持续循环执行：注册 → 保持 → 注销 → 等待 → 再次注册，用于压力测试。

```bash
./run.sh register_cycle \
  -i 10.18.2.59 \
  -p 10000 \
  -r 10.18.2.132:5060 \
  --rate 10 \
  --limit 500 \
  --hold 5000 \
  --pause 1000
```

**参数说明：**

| 参数 | 值 | 说明 |
|------|----|------|
| `-i` | `10.18.2.59` | 本地 IP |
| `-p` | `10000` | 本地端口 |
| `-r` | `10.18.2.132:5060` | 远端地址 |
| `--rate` | `10` | 新建注册速率（calls/s） |
| `--limit` | `500` | 最大并发用户数 |
| `--hold` | `5000` | 注册成功后保持时长（毫秒） |
| `--pause` | `1000` | 注销成功后等待时长（毫秒） |

**流程：**
```
REGISTER (Expires:3600) → 100 → 200 OK
  ↓ 等待 --hold ms
REGISTER (Expires:0, Unregister) → 100 → 200 OK
  ↓ 等待 --pause ms
  └─ 循环
```

**调整并发压力：**

```bash
# 轻压: 5 cps, 100 并发
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 5 --limit 100 --hold 5000 --pause 1000

# 中压: 10 cps, 500 并发 (默认)
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 10 --limit 500 --hold 5000 --pause 1000

# 高压: 50 cps, 2000 并发
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 50 --limit 2000 --hold 3000 --pause 500
```

**加超时自动退出（秒）：**
```bash
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 10 --limit 500 --hold 5000 --pause 1000 --timeout 300
```

---

## 场景三：持续注册保活

注册后周期性刷新注册，模拟在网用户。

```bash
./run.sh register_basic -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 10 --limit 500
```

---

## 场景四：IPSec AKA 注册

带 IPSec Security-Client 协商和 AKAv1-MD5 鉴权的注册流程。

```bash
./run.sh register_ipsec -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 --rate 5 --limit 100
```

---

## 用户数据管理

### 重新生成 CSV

```bash
cd /home/sder/sipp-test/ims_test
bash config/generate_users.sh
```

生成结果：
- `config/uac_users.csv` — 5000 主叫用户
- `config/uas_users.csv` — 5000 被叫用户

### 单次测试专用 CSV

`config/test_single_uac.csv` — 固定单用户，用于快速验证：
```
460110000010001;ims.mnc011.mcc460.3gppnetwork.org;0x00000001;0x00000002;5060;...
```

---

## 目录结构

```
ims_test/
├── sipp              → 符号链接到 sipp 二进制
├── run.sh            快捷启动脚本
├── USAGE.md          本文档
├── scenarios/        SIPp 场景 XML
│   ├── ims_register_once.xml       单次注册
│   ├── ims_register_cycle.xml      循环注册/注销
│   ├── ims_register_basic.xml      持续保活注册
│   ├── ims_register_ipsec_auth.xml IPSec AKA 注册
│   ├── ims_call_uac.xml            主叫呼叫
│   ├── ims_call_uas.xml            被叫接听
│   └── ims_default_response.xml    默认响应
├── config/
│   ├── generate_users.sh   用户数据生成脚本
│   ├── uac_users.csv       主叫用户 (5000)
│   ├── uas_users.csv       被叫用户 (5000)
│   ├── test_single_uac.csv 单用户测试
│   └── test_config.env     环境配置
├── scripts/          高级测试脚本
└── logs/             测试日志输出
```
