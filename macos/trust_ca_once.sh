#!/bin/bash

CERT_PATH="/Library/Application Support/Nursor/ca.pem"
LOG_FILE="/tmp/nursor_trustca.log"

echo "===============================================" >> "$LOG_FILE"
echo "$(date): 开始安装证书..." >> "$LOG_FILE"
echo "证书路径: $CERT_PATH" >> "$LOG_FILE"

# 检查证书文件是否存在
if [ ! -f "$CERT_PATH" ]; then
    echo "错误: 证书文件不存在于 $CERT_PATH" >> "$LOG_FILE"
    echo "错误: 证书文件不存在于 $CERT_PATH"
    exit 1
fi

# 使用 security add-certificates 命令添加证书（不需要用户交互）
# 这个命令只会将证书添加到系统钥匙链，但不会设置为信任的根证书
echo "添加证书到系统钥匙链..." >> "$LOG_FILE"
security add-certificates "$CERT_PATH" 2>&1 >> "$LOG_FILE"

if [ $? -eq 0 ]; then
    echo "证书已添加到系统钥匙链 ✅" >> "$LOG_FILE"
    
    # 尝试设置信任设置（这部分可能需要用户手动确认）
    echo "尝试设置证书为可信任..." >> "$LOG_FILE"
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH" 2>&1 >> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        echo "证书已设置为可信任根证书 ✅" >> "$LOG_FILE"
        echo "证书安装成功 ✅" >> "$LOG_FILE"
        exit 0
    else
        echo "警告: 证书已添加但可能未设置为可信任" >> "$LOG_FILE"
        echo "用户可能需要手动在 Keychain Access 中信任此证书" >> "$LOG_FILE"
        exit 0
    fi
else
    echo "证书安装失败 ❌" >> "$LOG_FILE"
    exit 1
fi
