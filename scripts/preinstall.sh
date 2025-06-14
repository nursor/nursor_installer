#!/bin/bash

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误：安装需要 sudo 权限，请以管理员身份运行安装程序。"
    exit 1
fi

# 检查 SIP 状态
sip_status=$(csrutil status | grep "System Integrity Protection status" | awk '{print $5}' | tr -d '.')
if [ "$sip_status" = "enabled" ]; then
    echo "警告：检测到 System Integrity Protection (SIP) 已启用。"
    echo "nursor-core 需要 root 权限创建 TUN 设备，SIP 可能导致权限问题。"
    echo "请在恢复模式下运行 'csrutil disable' 禁用 SIP，然后重启并重新运行安装程序。"
    read -p "是否继续安装？(y/n): " choice
    if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
        echo "安装已取消。"
        exit 1
    fi
fi

# 创建必要的目录
mkdir -p /usr/local/bin
mkdir -p /Library/LaunchDaemons
mkdir -p /var/log

exit 0