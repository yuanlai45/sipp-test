# IMS SIPp 测试使用说明

工作目录：`cd /home/sder/sipp-test/ims_test`  
P-CSCF：`10.18.2.132:5060` | 本机 IP：`10.18.2.59` | 用户池：5000 UAC + 5000 UAS

---

## 1. 单用户注册

注册 1 个用户，收到 200 OK 即成功，不注销。

```bash
./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_once.xml \
  -inf config/test_single_uac.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -m 1 -nd
```

---

## 2. 批量注册/注销（单轮）

N 用户注册 → 保持 60s（确保全部注册完） → 全部注销 → 结束。

### 2000 用户

```bash
head -1 config/uac_users.csv > /tmp/uac_2000.csv
tail -n +2 config/uac_users.csv | head -2000 >> /tmp/uac_2000.csv

./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_2000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 50 -l 2000 -m 2000 \
  -key hold_time 60000 \
  -nd
```

### 5000 用户

```bash
head -1 config/uac_users.csv > /tmp/uac_5000.csv
tail -n +2 config/uac_users.csv | head -5000 >> /tmp/uac_5000.csv

./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_5000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 100 -l 5000 -m 5000 \
  -key hold_time 60000 \
  -nd
```

### 8000 用户（UAC 5000 + UAS 前 3000 合并）

```bash
head -1 config/uac_users.csv > /tmp/uac_8000.csv
tail -n +2 config/uac_users.csv >> /tmp/uac_8000.csv
tail -n +2 config/uas_users.csv | head -3000 >> /tmp/uac_8000.csv

./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_8000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 100 -l 8000 -m 8000 \
  -key hold_time 100000 \
  -nd
```

> IMSI 范围：460110000010001~460110000018000（HSS 已开户）  
> hold_time=100s：8000用户/100cps=80s注册完，留20s余量再开始注销。

### 10000 用户（UAC 5000 + UAS 5000 全部合并）

```bash
head -1 config/uac_users.csv > /tmp/uac_10000.csv
tail -n +2 config/uac_users.csv >> /tmp/uac_10000.csv
tail -n +2 config/uas_users.csv >> /tmp/uac_10000.csv

./sipp 10.18.2.132:5060 \
  -sf scenarios/ims_register_batch.xml \
  -inf /tmp/uac_10000.csv \
  -i 10.18.2.59 -p 10000 -t un \
  -r 100 -l 10000 -m 10000 \
  -key hold_time 120000 \
  -nd
```

> IMSI 范围：460110000010001~460110000020000（需 HSS 全部开户）  
> hold_time=120s：10000用户/100cps=100s注册完，留20s余量再开始注销。

### 参数调整

| 改什么 | 怎么改 |
|--------|--------|
| 用户数 | CSV 用 `head -N`，命令改 `-l N -m N` |
| 启动速率 | `-r 50`（慢）/ `-r 100`（快） |
| 注册保持时长 | 加 `-key hold_time 120000`（120s），不加则默认 60s |
| 注册保持时长计算 | `hold_time ≥ 用户数 ÷ rate × 1000`（确保注册注销不重叠） |

---

## 3. 循环注册/注销（持续压测）

同一批用户不断循环：注册 → 保持 → 注销 → 等待 → 重复。

### 1000 用户循环

```bash
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 100 --limit 1000 --hold 10000 --pause 2000
```

### 5000 用户循环

```bash
./run.sh register_cycle -i 10.18.2.59 -p 10000 -r 10.18.2.132:5060 \
  --rate 100 --limit 5000 --hold 10000 --pause 2000
```

### 参数调整

| 改什么 | 怎么改 |
|--------|--------|
| 在线用户数 | `--limit 500` / `--limit 2000` |
| 注册保持时长 | `--hold 5000`（5s）/ `--hold 30000`（30s） |
| 注销后等待 | `--pause 1000`（1s）/ `--pause 5000`（5s） |
| 限时运行 | 加 `--timeout 300`（5min 后停止） |

### 健康指标

- `Retrans` > 0 → IMS 响应慢
- `Failed call` > 0 → 200 OK 超时
- `200 <---` < `REGISTER --->` → 有请求丢失

---

## 环境信息

| 项目 | 值 |
|------|-----|
| 本机 IP | `10.18.2.59` |
| P-CSCF | `10.18.2.132:5060` |
| UAC IMSI | `460110000010001` ~ `460110000015000` |
| UAS IMSI | `460110000015001` ~ `460110000020000` |
| Domain | `ims.mnc011.mcc460.3gppnetwork.org` |

重新生成用户 CSV：`bash config/generate_users.sh`
