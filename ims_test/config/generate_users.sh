#!/bin/bash

# 定義檔案路徑
UAC_CSV="/home/sder/sipp-test/ims_test/config/uac_users.csv"
UAS_CSV="/home/sder/sipp-test/ims_test/config/uas_users.csv"

# 清空目標檔案
> "$UAC_CSV"
> "$UAS_CSV"

# 添加表頭
echo "SEQUENTIAL" > "$UAC_CSV"
echo "SEQUENTIAL" > "$UAS_CSV"

# 設定起始值
uac_imsi_base=460110000010000
uas_imsi_base=460110000015000
uac_msisdn_base=13507310000
uas_msisdn_base=13507315000
domain="ims.mnc011.mcc460.3gppnetwork.org"
total=5000

# 固定參數值
server_port="5060"
k="12345678901234567890123456789012"
op="212e3b94279cb0f8095a55e8ef5569f7"
amf="8000"

# 生成UAC用戶資料 (主叫: IMSI 460110000010001-460110000015000)
# SPI範圍: 0x00000001-0x00002710 (client奇數, server偶數)
for ((i=1; i<=total; i++)); do
    imsi=$((uac_imsi_base + i))
    msisdn=$((uac_msisdn_base + i))
    callee_msisdn=$((uas_msisdn_base + i))
    client_spi=$(printf "0x%08x" $((2 * i - 1)))
    server_spi=$(printf "0x%08x" $((2 * i)))
    echo "${imsi};${domain};${client_spi};${server_spi};${server_port};${k};${op};${amf};uac;${msisdn};${callee_msisdn}" >> "$UAC_CSV"
    if ((i % 1000 == 0)); then
        echo "UAC 已生成 ${i}/${total} ($(( i * 100 / total ))%)"
    fi
done

# 生成UAS用戶資料 (被叫: IMSI 460110000015001-460110000020000)
# SPI範圍: 0x00002711-0x00004E22 (client奇數, server偶數, 不與UAC重疊)
for ((i=1; i<=total; i++)); do
    imsi=$((uas_imsi_base + i))
    msisdn=$((uas_msisdn_base + i))
    client_spi=$(printf "0x%08x" $((2 * total + 2 * i - 1)))
    server_spi=$(printf "0x%08x" $((2 * total + 2 * i)))
    echo "${imsi};${domain};${client_spi};${server_spi};${server_port};${k};${op};${amf};uas;${msisdn}" >> "$UAS_CSV"
    if ((i % 1000 == 0)); then
        echo "UAS 已生成 ${i}/${total} ($(( i * 100 / total ))%)"
    fi
done

echo "完成!"
echo "UAC ${total} 用戶 (IMSI $((uac_imsi_base+1))-$((uac_imsi_base+total)), MSISDN $((uac_msisdn_base+1))-$((uac_msisdn_base+total))): $UAC_CSV"
echo "UAS ${total} 用戶 (IMSI $((uas_imsi_base+1))-$((uas_imsi_base+total)), MSISDN $((uas_msisdn_base+1))-$((uas_msisdn_base+total))): $UAS_CSV"
echo "總共生成了 ${total} 對使用者（${total}個使用者）"