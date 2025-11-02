#!/bin/bash

# Sentry 集成库文件
# 使用方法: source "$(dirname "$0")/send_to_sentry.sh"

# 从环境变量或默认值获取配置
SENTRY_DSN="${SENTRY_DSN:-https://37c242e193956fc1a46aa03455629958@sentry.nursor.org/16}"
RELEASE_VERSION="${RELEASE_VERSION:-1.0}"
SCRIPT_NAME="${SCRIPT_NAME:-installer}"

# 从 DSN 解析 Sentry 配置
# DSN 格式: https://<key>@<host>/<project_id>
parse_sentry_dsn() {
    local dsn="$1"
    # 提取 key (在 @ 之前的部分)
    SENTRY_KEY=$(echo "$dsn" | sed -n 's|https://\([^@]*\)@.*|\1|p')
    # 提取 host
    SENTRY_HOST=$(echo "$dsn" | sed -n 's|https://[^@]*@\([^/]*\)/.*|\1|p')
    # 提取 project_id
    SENTRY_PROJECT_ID=$(echo "$dsn" | sed -n 's|https://[^@]*@[^/]*/\([0-9]*\)|\1|p')
    
    # 如果 host 是 ingest.sentry.io 格式，提取 org_id
    if echo "$SENTRY_HOST" | grep -q "ingest.sentry.io"; then
        SENTRY_ORG_ID=$(echo "$SENTRY_HOST" | sed -n 's|o\([0-9]*\)\.ingest\.sentry\.io|\1|p')
        # 构建 ingest URL (Sentry Cloud)
        SENTRY_INGEST_URL="https://o${SENTRY_ORG_ID}.ingest.sentry.io/api/${SENTRY_PROJECT_ID}/envelope/"
    else
        # 对于自定义域名 (Self-hosted Sentry)，使用 DSN 路径
        SENTRY_ORG_ID="${SENTRY_ORG_ID:-custom}"
        # Self-hosted Sentry 使用不同的路径
        SENTRY_INGEST_URL="https://${SENTRY_HOST}/api/${SENTRY_PROJECT_ID}/envelope/"
    fi
}

# 初始化 Sentry 配置
parse_sentry_dsn "$SENTRY_DSN"

# 函数：发送 Sentry 事件
send_to_sentry() {
    local payload_type="${1:-message}"  # "message" 或 "exception" (用于构建 payload)
    local level="${2:-info}"            # "error", "info", "warning"
    local message="${3:-}"
    local extra="${4:-{}}"
    
    # Sentry Envelope item type 必须始终是 "event"
    # 这是 Envelope 格式要求，不是事件内容类型
    local envelope_item_type="event"
    
    # 只发送 warning 和 error 级别的事件
    if [ "$level" != "warning" ] && [ "$level" != "error" ]; then
        return 0
    fi
    
    # 生成事件 ID
    local event_id=$(date +%s%N 2>/dev/null | md5 | head -c 32)
    [ -z "$event_id" ] && event_id=$(uuidgen 2>/dev/null | tr -d '-' | head -c 32)
    [ -z "$event_id" ] && event_id=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n' | head -c 32)
    
    local timestamp=$(date +%s)
    # timestamp 必须是 RFC 3339 格式的字符串
    local timestamp_rfc3339=$(date -u -r "$timestamp" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u "+%Y-%m-%dT%H:%M:%SZ")
    
    # 构建事件 payload
    local event_payload
    if [ "$payload_type" = "exception" ]; then
        event_payload=$(cat <<EOF
{
  "exception": {
    "values": [{
      "type": "InstallScriptError",
      "value": $(echo "$message" | jq -R . 2>/dev/null || echo "\"$message\"")
    }]
  },
  "level": "$level",
  "release": "$RELEASE_VERSION",
  "platform": "other",
  "sdk": {
    "name": "nursor-installer",
    "version": "1.0"
  },
  "tags": {
    "installer": "nursor-pkg",
    "os": "macOS",
    "script": "$SCRIPT_NAME"
  },
  "extra": $extra,
  "timestamp": $timestamp,
  "event_id": "$event_id"
}
EOF
)
    else
        event_payload=$(cat <<EOF
{
  "message": {
    "formatted": $(echo "$message" | jq -R . 2>/dev/null || echo "\"$message\"")
  },
  "level": "$level",
  "release": "$RELEASE_VERSION",
  "platform": "other",
  "sdk": {
    "name": "nursor-installer",
    "version": "1.0"
  },
  "tags": {
    "installer": "nursor-pkg",
    "os": "macOS",
    "script": "$SCRIPT_NAME"
  },
  "extra": $extra,
  "timestamp": $timestamp,
  "event_id": "$event_id"
}
EOF
)
    fi
    
    # 构建 Envelope (header + payload)
    # sent_at 必须是 RFC 3339 格式的日期时间字符串，不是 Unix 时间戳
    local sent_at_rfc3339=$(date -u -r "$timestamp" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u "+%Y-%m-%dT%H:%M:%SZ")
    local envelope_header="{\"event_id\":\"$event_id\",\"sent_at\":\"$sent_at_rfc3339\"}"
    
    # 计算 payload 长度（实际的字节数）
    local payload_length=$(echo -n "$event_payload" | wc -c | tr -d ' ')
    
    # 发送到 Sentry (Envelope 格式: header\nitem_header\npayload)
    # 注意：Sentry Envelope 格式要求使用实际的换行符
    # item_header 的 type 必须始终是 "event"，不是 "message" 或 "exception"
    local item_header="{\"type\":\"$envelope_item_type\",\"length\":$payload_length}"
    
    # 使用 printf 构建 envelope，确保换行符正确
    local envelope
    envelope=$(printf '%s\n%s\n%s' "$envelope_header" "$item_header" "$event_payload")
    
    # 调试输出（可以通过环境变量 SENTRY_DEBUG=1 启用）
    if [ "${SENTRY_DEBUG:-0}" = "1" ]; then
        echo "=== Sentry Debug ===" >&2
        echo "URL: $SENTRY_INGEST_URL" >&2
        echo "Key: ${SENTRY_KEY:0:10}..." >&2
        echo "Project ID: $SENTRY_PROJECT_ID" >&2
        echo "Event ID: $event_id" >&2
        echo "Envelope header: $envelope_header" >&2
        echo "Item header: $item_header" >&2
        echo "Payload length: $payload_length" >&2
        echo "Payload (前200字符): ${event_payload:0:200}..." >&2
        echo "=== End Debug ===" >&2
    fi
    
    # 执行 curl 请求并捕获输出
    # 注意：对于自签名证书或内网部署，添加 -k 选项跳过 SSL 验证
    # 可以通过 SENTRY_VERIFY_SSL=1 启用验证，默认为跳过验证（因为内网环境）
    local curl_verify_ssl="${SENTRY_VERIFY_SSL:-0}"
    local curl_output
    local curl_exit_code
    
    # 构建 curl 命令
    if [ "$curl_verify_ssl" = "1" ]; then
        # 启用 SSL 验证
        curl_output=$(curl -v -X POST \
             -H "X-Sentry-Auth: Sentry sentry_version=7, sentry_timestamp=$timestamp, sentry_key=$SENTRY_KEY, sentry_client=nursor-installer/1.0" \
             -H "Content-Type: text/plain" \
             --data-binary "$envelope" \
             "$SENTRY_INGEST_URL" 2>&1)
    else
        # 跳过 SSL 验证（适用于内网/自签名证书）
        curl_output=$(curl -v -k -X POST \
             -H "X-Sentry-Auth: Sentry sentry_version=7, sentry_timestamp=$timestamp, sentry_key=$SENTRY_KEY, sentry_client=nursor-installer/1.0" \
             -H "Content-Type: text/plain" \
             --data-binary "$envelope" \
             "$SENTRY_INGEST_URL" 2>&1)
    fi
    curl_exit_code=$?
    
    # 提取 HTTP 状态码
    local http_code=$(echo "$curl_output" | grep -i "< HTTP" | tail -1 | awk '{print $3}' || echo "unknown")
    
    # 调试模式下输出完整响应
    if [ "${SENTRY_DEBUG:-0}" = "1" ]; then
        echo "=== Curl Response ===" >&2
        echo "$curl_output" >&2
        echo "Exit code: $curl_exit_code" >&2
        echo "HTTP Code: $http_code" >&2
        echo "=== End Response ===" >&2
    fi
    
    # 检查是否成功（HTTP 200）
    if [ $curl_exit_code -eq 0 ] && echo "$http_code" | grep -qE "^(200|204)$"; then
        if [ "${SENTRY_DEBUG:-0}" = "1" ]; then
            echo "✅ Sentry 事件发送成功" >&2
        fi
        return 0
    else
        # 失败时输出错误信息
        echo "❌ Sentry 发送失败 - HTTP: $http_code, Exit: $curl_exit_code" >&2
        if [ "${SENTRY_DEBUG:-0}" != "1" ]; then
            echo "提示: 设置 SENTRY_DEBUG=1 查看详细信息" >&2
        fi
        # 记录到日志文件
        echo "$(date): ERROR - Sentry send failed. HTTP: $http_code, Exit: $curl_exit_code" >> /tmp/nursor_sentry_error.log 2>&1
        echo "URL: $SENTRY_INGEST_URL" >> /tmp/nursor_sentry_error.log 2>&1
        echo "Response: $curl_output" >> /tmp/nursor_sentry_error.log 2>&1
        return 1
    fi
}

# 安全的命令执行包装函数
# 用法: safe_exec "命令" "描述"
safe_exec() {
    local cmd="$1"
    local description="${2:-执行命令: $cmd}"
    local output
    
    # 执行命令并捕获输出
    output=$(eval "$cmd" 2>&1)
    local exit_code=$?
    
    # 检查输出中是否包含 WARNING 或 ERROR
    if echo "$output" | grep -qiE "(WARNING|ERROR|错误|警告)"; then
        local level="warning"
        if echo "$output" | grep -qiE "(ERROR|错误|失败|failed)"; then
            level="error"
        fi
        local extra=$(echo "$output" | jq -R -s . 2>/dev/null || echo "{\"output\": \"$output\"}")
        send_to_sentry "message" "$level" "$description: $output" "$extra"
    fi
    
    # 如果命令失败，发送错误
    if [ $exit_code -ne 0 ]; then
        local extra=$(echo "$output" | jq -R -s . 2>/dev/null || echo "{\"output\": \"$output\", \"exit_code\": $exit_code}")
        send_to_sentry "exception" "error" "$description 失败 (退出码: $exit_code)" "$extra"
    fi
    
    # 返回命令的退出码
    return $exit_code
}

# 错误处理函数（用于 trap）
error_handler() {
    local exit_code=$?
    local line_number="${BASH_LINENO[0]}"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    # 只发送 error 级别的事件
    local extra="{\"exit_code\": $exit_code, \"line\": $line_number, \"script\": \"$script_name\"}"
    send_to_sentry "exception" "error" "$SCRIPT_NAME 脚本执行失败 (退出码: $exit_code, 行号: $line_number)" "$extra"
    
    return $exit_code
}
