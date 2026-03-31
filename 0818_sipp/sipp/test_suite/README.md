# IMS测试套件

## 简介
本测试套件用于IMS系统的性能测试，基于SIPp工具实现，支持注册测试和呼叫测试。

## 功能特点
- 完全符合IMS标准的SIP消息流和头域
- 自动生成用户信息，支持大规模并发测试
- 支持双协议测试（IPv4和IPv6）
- 支持IPSec和Digest认证
- 支持自动分配主叫(UAC)和被叫(UAS)角色
- 模块化代码设计，易于扩展和维护

## 目录结构
- `config/`: 配置文件目录
- `logs/`: 日志文件目录
- `scenarios/`: SIPp场景文件目录
  - `ims_register.xml`: IMS注册场景文件
  - `ims_call_uac.xml`: IMS呼叫UAC场景文件（符合IMS标准）
  - `ims_call_uas.xml`: IMS呼叫UAS场景文件（符合IMS标准）
  - `ims_default_response.xml`: 默认响应场景文件
- `scripts/`: 测试脚本目录
  - `ims_common.sh`: 公共函数库
  - `ims_register_test.sh`: 注册测试脚本
  - `ims_call_test.sh`: 呼叫测试脚本

## 代码结构
- 脚本采用模块化设计，将公共函数抽取到`ims_common.sh`中
- 场景文件使用XML格式，符合SIPp规范
- 测试脚本使用Bash编写，支持参数化配置

## 使用方法

### 双协议测试
```bash
bash scripts/ims_register_test.sh --local-ip <本地IPv4> --local-ipv6 <本地IPv6> --remote-ip <远端IPv4:端口> --remote-ipv6 <远端IPv6:端口> --users <用户数量> --scenario <场景类型>
```

### 注册测试
```bash
bash scripts/ims_register_test.sh --local-ip <本地IP> --remote-ip <远端IP:端口> --users <用户数量> --scenario <场景类型>
```

### 呼叫测试
```bash
bash scripts/ims_call_test.sh --local-ip <本地IP> --remote-ip <远端IP:端口> --users <用户数量> --rate <呼叫速率> --call-hold <通话保持时间> --call-wait <接听等待时间> --call-again <是否再次发起通话>
```

## 参数说明

### 注册测试参数
- `--local-ip`: 本地IPv4地址
- `--local-ipv6`: 本地IPv6地址（可选，用于双协议测试）
- `--remote-ip`: 远端IPv4地址和端口，格式为`IP:PORT`
- `--remote-ipv6`: 远端IPv6地址和端口，格式为`IP:PORT`（可选，用于双协议测试）
- `--users`: 并发用户数量
- `--scenario`: 测试场景类型，可选值为`basic`（基本认证）或`ipsec_auth`（IPSec认证）
- `--duration`: 测试持续时间（秒），默认为60秒
- `--rate`: 每秒注册请求数，默认为1

### 呼叫测试参数
- `--local-ip`: 本地IP地址
- `--remote-ip`: 远端IP地址和端口，格式为`IP:PORT`
- `--users`: 用户数量
- `--rate`: 每秒新建呼叫数
- `--duration`: 测试持续时间（秒），默认为60秒
- `--call-hold`: 通话保持时间（秒），默认为5秒
- `--call-wait`: 接听等待时间（秒），默认为1秒
- `--call-again`: 是否在通话结束后再次发起通话，可选值为0（否）或1（是），默认为0
- `--csv-file`: 用户数据CSV文件路径，默认自动生成
- `--auth`: 认证方式，可选值为`none`（无认证）、`ipsec`（IPSec认证）或`digest`（Digest认证），默认为`none`

## 主叫和被叫分配机制
测试套件采用基于用户ID的自动角色分配机制：
- 奇数ID的用户被分配为主叫(UAC)角色
- 偶数ID的用户被分配为被叫(UAS)角色
- 用户角色信息存储在CSV文件中，格式为：`msisdn;domain;client_spi;server_spi;k;op;amf;role`
- 呼叫测试时，系统会自动为每个主叫分配一个被叫号码，无需手动指定

## 测试示例

### 基本注册测试（100个用户）
```bash
sudo bash test_suite/scripts/ims_register_test.sh --local-ip 10.18.2.12 --remote-ip 10.18.1.239:5060 --initial-port 10000 --rate 1000 --users 500 --scenario basic --duration 20 --reg-count 2
```

### IPSec认证注册测试（50个用户）
```bash
bash scripts/ims_register_test.sh --local-ip 192.168.1.100 --remote-ip 192.168.1.200:5060 --users 50 --scenario ipsec_auth
```

### 呼叫测试（20个用户，每秒2个新呼叫）
```bash
bash scripts/ims_call_test.sh --local-ip 192.168.1.100 --remote-ip 192.168.1.200:5060 --users 20 --rate 2 --call-hold 10 --call-wait 2
```
```bash
sudo bash test_suite/scripts/ims_call_test.sh --local-ip 10.18.2.12 --remote-ip 10.18.1.239:5060 --users 4000 --rate 500 --call-hold 10 --call-wait 5 --call-again 1 --auth none --initial-port 10000 --initial-media-port 50000
```

## IMS标准合规性
本测试套件完全符合IMS标准规范，包括：

### UAC场景文件合规性
- 包含必要的IMS头域：P-Preferred-Identity、P-Access-Network-Info、Privacy、P-Charging-Vector等
- 支持183 Session Progress和PRACK可靠临时响应机制
- 支持IMS扩展：precondition、100rel、timer等
- SDP媒体协商支持多种编解码器和电话事件

### UAS场景文件合规性
- 包含必要的IMS头域：P-Asserted-Identity、P-Access-Network-Info、P-Charging-Vector等
- 支持183 Session Progress和PRACK可靠临时响应机制
- 支持IMS扩展：precondition、100rel等
- SDP媒体协商支持多种编解码器和电话事件

### IMS消息流程
1. UAC发送INVITE请求
2. UAS回复100 Trying
3. UAS回复183 Session Progress（带SDP）
4. UAC发送PRACK
5. UAS回复200 OK for PRACK
6. UAS回复180 Ringing
7. UAS回复200 OK for INVITE（带SDP）
8. UAC发送ACK
9. 通话保持一段时间
10. UAC发送BYE
11. UAS回复200 OK for BYE

## 注意事项
- 测试前请确保SIPp已正确安装
- 对于IPSec认证测试，需要root权限运行脚本
- 大规模测试可能需要调整系统参数，如文件描述符限制等
- 测试结果保存在logs目录下，包括错误日志、消息跟踪和统计信息

## IPSec认证和Security-Verify支持

本测试套件现已支持在IPSec认证模式下自动从Redis读取Security-Server信息，并在SIP消息中添加Security-Verify字段。

### 功能特点

- 根据认证类型（auth参数）自动决定是否添加Security-Verify字段
- 当auth=ipsec时，自动从Redis读取security_server信息
- 当auth不是ipsec时，不添加Security-Verify字段
- 支持在UAC和UAS场景中使用Security-Verify字段

### 使用方法

使用`--auth ipsec`参数运行呼叫测试脚本：

```bash
bash scripts/ims_call_test.sh --local-ip 192.168.1.100 --remote-ip 192.168.1.200:5060 --users 20 --rate 2 --auth ipsec
```

### 实现细节

1. 测试脚本会自动检测auth参数是否为ipsec
2. 如果是ipsec，会从Redis读取或生成Security-Server信息
3. 在SIP消息中根据需要添加Security-Verify字段
4. Redis中的键格式为：`sipp:security:<imsi>:<domain>:<client_spi>:<server_spi>`

### 注意事项

- 使用IPSec认证模式需要确保Redis服务正在运行
- 如果Redis中没有找到对应的Security-Server信息，将使用默认值
- 可以通过修改`get_security_server.sh`脚本自定义Security-Server信息的获取方式 