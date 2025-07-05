#!/bin/bash

CERT_PATH="/Library/Application\\ Support/Nursor/nursor-ca.pem"
LOG_FILE="/tmp/nursor_trustca.log"

echo "开始安装证书..." >> "$LOG_FILE"

# 通过 AppleScript 提权
osascript -e "do shell script \"security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain '/Library/Application Support/Nursor/ca.pem'\" with administrator privileges"


if [ $? -eq 0 ]; then
  echo "证书安装成功 ✅" >> "$LOG_FILE"
else
  echo "证书安装失败 ❌" >> "$LOG_FILE"
fi
