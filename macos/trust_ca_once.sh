#!/bin/bash

CERT_PATH="/Library/Application Support/Nursor/ca.pem"
LOG_FILE="/tmp/nursor_trustca.log"
SCRIPT_NAME="trust_ca_once"

# 加载 Sentry 集成库（尝试多个可能的位置）
SENTRY_LIB_PATHS=(
    "/Library/Application Support/Nursor/send_to_sentry.sh"
    "$(dirname "$0")/send_to_sentry.sh"
    "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/send_to_sentry.sh"
)

SENTRY_LOADED=false
for sentry_path in "${SENTRY_LIB_PATHS[@]}"; do
    if [ -f "$sentry_path" ]; then
        export SCRIPT_NAME="$SCRIPT_NAME"
        if source "$sentry_path" 2>/dev/null; then
            SENTRY_LOADED=true
            echo "Sentry 库已加载: $sentry_path" >> "$LOG_FILE" 2>&1
            break
        else
            echo "警告: 无法加载 Sentry 库: $sentry_path" >> "$LOG_FILE" 2>&1
        fi
    fi
done

# 如果 Sentry 库加载成功，设置错误捕获
if [ "$SENTRY_LOADED" = true ] && command -v send_to_sentry >/dev/null 2>&1; then
    trap 'error_handler' ERR
    echo "Sentry 错误捕获已设置" >> "$LOG_FILE" 2>&1
else
    echo "警告: Sentry 库未加载或 send_to_sentry 函数不可用" >> "$LOG_FILE" 2>&1
    echo "SENTRY_LOADED=$SENTRY_LOADED" >> "$LOG_FILE" 2>&1
    echo "send_to_sentry available: $(command -v send_to_sentry)" >> "$LOG_FILE" 2>&1
fi

echo "===============================================" >> "$LOG_FILE"
echo "$(date): 开始安装证书..." >> "$LOG_FILE"
echo "证书路径: $CERT_PATH" >> "$LOG_FILE"

# 检查证书文件是否存在
if [ ! -f "$CERT_PATH" ]; then
    error_msg="证书文件不存在于 $CERT_PATH"
    echo "错误: $error_msg" >> "$LOG_FILE"
    echo "错误: $error_msg"
    
    # 发送错误到 Sentry
    echo "尝试发送证书文件不存在错误到 Sentry..." >> "$LOG_FILE" 2>&1
    if [ "$SENTRY_LOADED" = true ] && command -v send_to_sentry >/dev/null 2>&1; then
        export SENTRY_DEBUG=1
        send_to_sentry "exception" "error" "$error_msg" "{\"cert_path\": \"$CERT_PATH\", \"file_exists\": false}" 2>&1 | tee -a "$LOG_FILE"
        unset SENTRY_DEBUG
    else
        echo "警告: Sentry 未加载，无法发送错误" >> "$LOG_FILE" 2>&1
    fi
    
    exit 1
fi

# 使用 security add-certificates 命令添加证书（不需要用户交互）
# 这个命令只会将证书添加到系统钥匙链，但不会设置为信任的根证书
echo "添加证书到系统钥匙链..." >> "$LOG_FILE"
add_cert_output=$(security add-certificates "$CERT_PATH" 2>&1)
add_cert_exit_code=$?
echo "$add_cert_output" >> "$LOG_FILE"

if [ $add_cert_exit_code -eq 0 ]; then
    echo "证书已添加到系统钥匙链 ✅" >> "$LOG_FILE"
    
    # 尝试设置信任设置（这部分可能需要用户手动确认）
    echo "尝试设置证书为可信任..." >> "$LOG_FILE"
    trust_cert_output=$(security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CERT_PATH" 2>&1)
    trust_cert_exit_code=$?
    echo "$trust_cert_output" >> "$LOG_FILE"
    
    if [ $trust_cert_exit_code -eq 0 ]; then
        echo "证书已设置为可信任根证书 ✅" >> "$LOG_FILE"
        echo "证书安装成功 ✅" >> "$LOG_FILE"
        
        # 注意：成功时不需要发送到 Sentry（只发送错误和警告）
        exit 0
    else
        warning_msg="证书已添加但可能未设置为可信任"
        echo "警告: $warning_msg" >> "$LOG_FILE"
        echo "用户可能需要手动在 Keychain Access 中信任此证书" >> "$LOG_FILE"
        
        # 发送警告到 Sentry（这是预期的，因为 macOS 12+ 需要手动信任）
        if [ "$SENTRY_LOADED" = true ] && command -v send_to_sentry >/dev/null 2>&1; then
            send_to_sentry "message" "warning" "$warning_msg - 需要手动信任" "{\"cert_path\": \"$CERT_PATH\", \"trust_output\": \"$trust_cert_output\", \"exit_code\": $trust_cert_exit_code}"
        fi
        
        exit 0
    fi
else
    error_msg="证书安装失败 - security add-certificates 命令失败"
    echo "$error_msg ❌" >> "$LOG_FILE"
    echo "$error_msg"
    echo "输出: $add_cert_output" >> "$LOG_FILE"
    
    # 发送错误到 Sentry
    echo "尝试发送错误到 Sentry..." >> "$LOG_FILE" 2>&1
    echo "SENTRY_LOADED=$SENTRY_LOADED" >> "$LOG_FILE" 2>&1
    echo "send_to_sentry available: $(command -v send_to_sentry 2>&1)" >> "$LOG_FILE" 2>&1
    
    if [ "$SENTRY_LOADED" = true ] && command -v send_to_sentry >/dev/null 2>&1; then
        echo "正在发送错误到 Sentry..." >> "$LOG_FILE" 2>&1
        # 使用 SENTRY_DEBUG=1 临时启用调试
        export SENTRY_DEBUG=1
        send_to_sentry "exception" "error" "$error_msg" "{\"cert_path\": \"$CERT_PATH\", \"add_cert_output\": \"$add_cert_output\", \"exit_code\": $add_cert_exit_code}" 2>&1 | tee -a "$LOG_FILE"
        sentry_exit_code=$?
        echo "Sentry 发送结果: exit_code=$sentry_exit_code" >> "$LOG_FILE" 2>&1
        unset SENTRY_DEBUG
    else
        echo "错误: 无法发送到 Sentry - 库未加载或函数不可用" >> "$LOG_FILE" 2>&1
    fi
    
    exit 1
fi
