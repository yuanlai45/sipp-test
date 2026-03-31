#!/bin/bash

# 定義檔案路徑
UAC_CSV="/home/sder/sipp-test/0818_sipp/sipp/test_suite/config/uac_users.csv"
UAS_CSV="/home/sder/sipp-test/0818_sipp/sipp/test_suite/config/uas_users.csv"

# 清空目標檔案
> "$UAC_CSV"
> "$UAS_CSV"

# 添加表頭
echo "SEQUENTIAL" > "$UAC_CSV"
echo "SEQUENTIAL" > "$UAS_CSV"

# 設定起始值
start_imsi="460119000000000"
start_msisdn="600000"  # 修改為新的起始電話號碼
domain="ims.mnc011.mcc460.3gppnetwork.org"

# 固定參數值
server_port="5060"
k="31323334353637383930313233343536"
op="19DF73C9C56A90EE581D52F1EBD53E72"
amf="8000"

# 生成使用者資料
for ((i=1; i<=4000; i+=2)); do
    # 基數用戶 (UAC)
    imsi_uac=$((start_imsi + i))
    msisdn_uac=$((start_msisdn + i))
    
    # 對應的偶數用戶 (UAS)
    imsi_uas=$((start_imsi + i + 1))
    msisdn_uas=$((start_msisdn + i + 1))
    
    # 生成IPSec認證參數
    client_spi_uac="0x$(openssl rand -hex 4)"
    server_spi_uac="0x$(openssl rand -hex 4)"
    client_spi_uas="0x$(openssl rand -hex 4)"
    server_spi_uas="0x$(openssl rand -hex 4)"
    
    # UAC用戶資料 (增加目標MSISDN為第11個欄位)
    echo "${imsi_uac};${domain};${client_spi_uac};${server_spi_uac};${server_port};${k};${op};${amf};uac;${msisdn_uac};${msisdn_uas}" >> "$UAC_CSV"
    
    # UAS用戶資料
    echo "${imsi_uas};${domain};${client_spi_uas};${server_spi_uas};${server_port};${k};${op};${amf};uas;${msisdn_uas}" >> "$UAS_CSV"
    
    # 顯示進度
    if ((i % 400 == 1)); then
        echo "已生成 $((i/2+1)) 對使用者 ($(( i * 100 / 4000 ))%)"
    fi
done

echo "完成!"
echo "UAC使用者 (奇數): $UAC_CSV"
echo "UAS使用者 (偶數): $UAS_CSV"
echo "總共生成了 2000 對使用者（4000個使用者）"