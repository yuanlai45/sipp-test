# IMS SIPp 测试使用说明

工作目录：`/home/sder/sipp-test/ims_test`  
P-CSCF：`10.18.2.132:5060` | 本机 IP：`10.18.2.59`  
用户池：UAC `460110000010001~15000`（5000个），UAS `460110000015001~20000`（5000个）

---

## 场景零：单用户注册验证

**场景文件**：`scenarios/ims_register_once.xml`  
**流程**：1 个用户注册 → 收到 200 OK → 结束（不注销、不循环）

```bash
./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_once.xml \
  -inf config/test_single_uac.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -m 1 -nd
```

> 成功标志：`200 <---------- 1`，`Failed call: 0`

---

## 场景一：单轮批量注册/注销

**场景文件**：`scenarios/ims_register_batch.xml`  
**流程**：N 用户注册 → 保持 `hold_time` ms → 全部注销 → **结束不循环**

### 命令模板

```bash
# 第一步：生成 N 用户的 CSV（替换 200 为实际数量）
head -1 config/uac_users.csv > /tmp/uac_200.csv
tail -n +2 config/uac_users.csv | head -200 >> /tmp/uac_200.csv

# 第二步：执行
./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_200.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 10 -l 200 -m 200 \
  -key hold_time 10000 \
  -nd
```

### 参数说明

| 参数 | 含义 | 典型值 |
|------|------|--------|
| `-m N` | 总用户数 | `-m 200` |
| `-l N` | 最大并发，须 ≥ `-m` | `-l 200` |
| `-r N` | 启动速率 cps（越大上线越快） | `-r 10` |
| `-key hold_time N` | 注册→注销间隔（毫秒） | `-key hold_time 10000` |
| `-inf <csv>` | 用户数据文件 | `-inf /tmp/uac_200.csv` |

### 常用调整

```bash
# 改用户数：替换所有 200 为目标数（如 1000）
head -1 config/uac_users.csv > /tmp/uac_1000.csv
tail -n +2 config/uac_users.csv | head -1000 >> /tmp/uac_1000.csv
./sipp 10.18.2.132:5060 -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_1000.csv -i 10.18.2.59 -p 10000 -t un \
  -r 50 -l 1000 -m 1000 -key hold_time 10000 -nd

# 改注册保持时间（注册→注销间隔）
-key hold_time 5000    # 5s
-key hold_time 30000   # 30s
-key hold_time 300000  # 5min

# 指定用第 201~400 号用户
tail -n +2 config/uac_users.csv | sed -n '201,400p' > /tmp/uac_range.csv
sed -i '1s/^/SEQUENTIAL\n/' /tmp/uac_range.csv
./sipp 10.18.2.132:5060 -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_range.csv -i 10.18.2.59 -p 10000 -t un \
  -r 10 -l 200 -m 200 -key hold_time 10000 -nd
```

---

## 场景二：循环注册/注销压测

**场景文件**：`scenarios/ims_register_cycle.xml`  
**流程**：注册 → 保持 `hold` ms → 注销 → 等待 `pause` ms → **循环**（同一批用户持续cycling）

> **注意**：`-l N` 决定同时活跃的唯一用户数。每个 call 绑定 CSV 中的一行，永久循环，不会换用户。

### 命令模板

```bash
./run.sh register_cycle \
  -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 50 --limit 500 --hold 10000 --pause 2000
```

### 参数说明

| 参数 | 含义 | 典型值 |
|------|------|--------|
| `--rate N` | 每秒新建 call 数（cps） | `--rate 50` |
| `--limit N` | 同时在线用户数上限（= 唯一 IMSI 数） | `--limit 500` |
| `--hold N` | 注册保持时长（ms） | `--hold 10000` |
| `--pause N` | 注销后等待时长（ms） | `--pause 2000` |
| `--timeout N` | 测试总时长（秒），不加则持续运行 | `--timeout 300` |

### 并发计算

```
同时在线用户数 = --limit 的值（每个 slot 持有一个 IMSI，永久循环）
稳态注册速率 ≈ limit / (hold + pause) × 1000  次/秒
```

### 常用档位（hold=10s, pause=2s）

```bash
# 500 用户在线循环（持续运行）
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 50 --limit 500 --hold 10000 --pause 2000

# 1000 用户在线循环（运行 5min）
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 100 --limit 1000 --hold 10000 --pause 2000 --timeout 300

# 5000 用户全部在线循环
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 100 --limit 5000 --hold 10000 --pause 2000
```

### 常用调整

```bash
# 改在线用户数（如 1000 用户）：改 --limit
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 100 --limit 1000 --hold 10000 --pause 2000

# 改注册保持时间（注册→注销间隔）：改 --hold
--hold 5000    # 5s
--hold 30000   # 30s
--hold 300000  # 5min

# 改注销后等待时间：改 --pause
--pause 1000   # 1s
--pause 5000   # 5s

# 加时间限制（运行 5min 后自动停止）：加 --timeout
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 50 --limit 500 --hold 10000 --pause 2000 --timeout 300

# 指定用第 N~M 号用户：先生成子集 CSV，再用 --csv 指定
tail -n +2 config/uac_users.csv | sed -n '1001,2000p' > /tmp/cycle_range.csv
sed -i '1s/^/SEQUENTIAL\n/' /tmp/cycle_range.csv
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 50 --limit 1000 --hold 10000 --pause 2000 --csv /tmp/cycle_range.csv
```

### 健康指标

sipp 统计屏幕中，以下情况说明 IMS 有压力：
- `Retrans` 列 > 0（重传增多）
- `Failed call` > 0（200 OK 超时）
- `200 <---` 数量 < `REGISTER --->` 数量

---

## 环境 / 用户数据

| 项目 | 值 |
|------|-----|
| 本机 IP | `10.18.2.59` |
| P-CSCF | `10.18.2.132:5060` |
| UAC IMSI | `460110000010001` ~ `460110000015000` |
| UAS IMSI | `460110000015001` ~ `460110000020000` |
| K | `12345678901234567890123456789012` |
| OP | `212e3b94279cb0f8095a55e8ef5569f7` |
| Domain | `ims.mnc011.mcc460.3gppnetwork.org` |

重新生成用户 CSV：

```bash
bash config/generate_users.sh
```
