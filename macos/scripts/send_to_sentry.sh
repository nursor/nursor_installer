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

# 函数：收集系统信息
collect_system_info() {
    local info_json="{"
    
    # 操作系统信息
    local os_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    local os_build=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")
    local os_name=$(sw_vers -productName 2>/dev/null || echo "macOS")
    info_json+="\"os\": {\"name\": \"$os_name\", \"version\": \"$os_version\", \"build\": \"$os_build\"},"
    
    # 硬件信息
    local cpu_type=$(uname -m 2>/dev/null || echo "unknown")
    local cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "unknown")
    local mem_total=$(sysctl -n hw.memsize 2>/dev/null)
    if [ -n "$mem_total" ]; then
        mem_total=$((mem_total / 1024 / 1024))
        mem_total="${mem_total}MB"
    else
        mem_total="unknown"
    fi
    info_json+="\"hardware\": {\"cpu_type\": \"$cpu_type\", \"cpu_cores\": \"$cpu_cores\", \"memory\": \"$mem_total\"},"
    
    # 用户信息
    local current_user=$(whoami 2>/dev/null || echo "unknown")
    local user_home="${HOME:-unknown}"
    local is_root=$([ "$(id -u)" -eq 0 ] && echo "true" || echo "false")
    info_json+="\"user\": {\"name\": \"$current_user\", \"home\": \"$user_home\", \"is_root\": $is_root},"
    
    # 环境变量（重要信息）
    local shell_name="${SHELL:-unknown}"
    local path_length=$(echo "$PATH" | wc -c)
    info_json+="\"environment\": {\"shell\": \"$shell_name\", \"path_length\": $path_length},"
    
    # 磁盘空间信息
    local disk_info=$(df -h / 2>/dev/null | tail -1 | awk '{print "{\"total\": \"" $2 "\", \"used\": \"" $3 "\", \"available\": \"" $4 "\", \"usage\": \"" $5 "\"}"}' || echo "{}")
    info_json+="\"disk\": $disk_info,"
    
    # 网络信息
    local hostname=$(hostname 2>/dev/null || echo "unknown")
    local primary_ip=$(ifconfig 2>/dev/null | grep "inet " | grep -v 127.0.0.1 | head -1 | awk '{print $2}' || echo "unknown")
    info_json+="\"network\": {\"hostname\": \"$hostname\", \"primary_ip\": \"$primary_ip\"},"
    
    # 安装相关路径
    local app_support_dir="/Library/Application Support/Nursor"
    local launchd_dir="/Library/LaunchDaemons"
    info_json+="\"paths\": {"
    info_json+="\"app_support\": \"$app_support_dir\","
    info_json+="\"app_support_exists\": $([ -d "$app_support_dir" ] && echo "true" || echo "false"),"
    info_json+="\"launchdaemons\": \"$launchd_dir\","
    info_json+="\"launchdaemons_exists\": $([ -d "$launchd_dir" ] && echo "true" || echo "false")"
    info_json+="},"
    
    # 时间信息
    local current_time=$(date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")
    local uptime=$(uptime 2>/dev/null | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs || echo "unknown")
    info_json+="\"time\": {\"current\": \"$current_time\", \"uptime\": \"$uptime\"}"
    
    info_json+="}"
    echo "$info_json"
}

# 函数：收集脚本执行上下文
collect_context_info() {
    local script_name="${1:-unknown}"
    local line_number="${2:-unknown}"
    local exit_code="${3:-0}"
    
    local context_json="{"
    
    # 脚本信息
    context_json+="\"script\": {\"name\": \"$script_name\", \"line\": \"$line_number\", \"exit_code\": $exit_code},"
    
    # 进程信息
    local pid=$$
    local ppid=$(ps -o ppid= -p $pid 2>/dev/null | xargs || echo "unknown")
    local cmd_line=$(ps -p $pid -o command= 2>/dev/null | head -1 || echo "unknown")
    context_json+="\"process\": {\"pid\": $pid, \"ppid\": \"$ppid\", \"command\": \"$cmd_line\"},"
    
    # 工作目录
    local pwd_dir="${PWD:-unknown}"
    context_json+="\"working_directory\": \"$pwd_dir\","
    
    # 调用栈（简化版）
    local stack_depth=$(echo "${BASH_LINENO[@]}" | wc -w 2>/dev/null || echo "0")
    context_json+="\"stack_depth\": $stack_depth,"
    
    # 环境变量（限制敏感信息）
    context_json+="\"env_vars\": {"
    context_json+="\"PWD\": \"$PWD\","
    context_json+="\"USER\": \"${USER:-unknown}\","
    context_json+="\"HOME\": \"${HOME:-unknown}\","
    context_json+="\"SHELL\": \"${SHELL:-unknown}\""
    context_json+="}"
    
    context_json+="}"
    echo "$context_json"
}

# 函数：收集文件系统状态
collect_filesystem_info() {
    local fs_json="{"
    
    # 检查关键文件是否存在
    local trust_ca_script="/Library/Application Support/Nursor/trust_ca_once.sh"
    local ca_pem="/Library/Application Support/Nursor/ca.pem"
    local core_binary="/Library/Application Support/Nursor/nursor-core"
    local plist_file="/Library/LaunchDaemons/org.nursor.nursor-core.plist"
    
    fs_json+="\"files\": {"
    fs_json+="\"trust_ca_script\": {"
    fs_json+="\"path\": \"$trust_ca_script\","
    fs_json+="\"exists\": $([ -f "$trust_ca_script" ] && echo "true" || echo "false"),"
    fs_json+="\"readable\": $([ -r "$trust_ca_script" ] && echo "true" || echo "false"),"
    fs_json+="\"executable\": $([ -x "$trust_ca_script" ] && echo "true" || echo "false")"
    fs_json+="},"
    
    fs_json+="\"ca_pem\": {"
    fs_json+="\"path\": \"$ca_pem\","
    fs_json+="\"exists\": $([ -f "$ca_pem" ] && echo "true" || echo "false"),"
    fs_json+="\"readable\": $([ -r "$ca_pem" ] && echo "true" || echo "false"),"
    fs_json+="\"size\": $([ -f "$ca_pem" ] && stat -f%z "$ca_pem" 2>/dev/null || echo "0")"
    fs_json+="},"
    
    fs_json+="\"core_binary\": {"
    fs_json+="\"path\": \"$core_binary\","
    fs_json+="\"exists\": $([ -f "$core_binary" ] && echo "true" || echo "false"),"
    fs_json+="\"executable\": $([ -x "$core_binary" ] && echo "true" || echo "false")"
    fs_json+="},"
    
    fs_json+="\"plist\": {"
    fs_json+="\"path\": \"$plist_file\","
    fs_json+="\"exists\": $([ -f "$plist_file" ] && echo "true" || echo "false"),"
    fs_json+="\"readable\": $([ -r "$plist_file" ] && echo "true" || echo "false")"
    fs_json+="}"
    
    fs_json+="},"
    
    # 目录权限
    local app_dir="/Library/Application Support/Nursor"
    fs_json+="\"directories\": {"
    fs_json+="\"app_support\": {"
    fs_json+="\"path\": \"$app_dir\","
    fs_json+="\"exists\": $([ -d "$app_dir" ] && echo "true" || echo "false"),"
    fs_json+="\"writable\": $([ -w "$app_dir" ] && echo "true" || echo "false"),"
    fs_json+="\"permissions\": \"$(stat -f%A "$app_dir" 2>/dev/null || echo "unknown")\""
    fs_json+="}"
    fs_json+="}"
    
    fs_json+="}"
    echo "$fs_json"
}

# 函数：收集服务状态
collect_service_info() {
    local service_json="{"
    
    # LaunchDaemon 状态
    local plist_label="org.nursor.nursor-core"
    local service_status=$(launchctl list "$plist_label" 2>&1)
    local is_loaded="false"
    if echo "$service_status" | grep -qv "Could not find"; then
        is_loaded="true"
    fi
    
    service_json+="\"launchd\": {"
    service_json+="\"label\": \"$plist_label\","
    service_json+="\"loaded\": $is_loaded,"
    service_json+="\"status\": $(echo "$service_status" | head -3 | jq -R -s . 2>/dev/null || echo "\"$service_status\"")"
    service_json+="},"
    
    # 相关进程
    local core_process=$(ps aux | grep -i nursor-core | grep -v grep | head -1 || echo "")
    service_json+="\"processes\": {"
    service_json+="\"nursor_core_running\": $([ -n "$core_process" ] && echo "true" || echo "false"),"
    if [ -n "$core_process" ]; then
        local core_pid=$(echo "$core_process" | awk '{print $2}')
        service_json+="\"core_pid\": \"$core_pid\","
    fi
    service_json+="\"process_info\": $(echo "$core_process" | jq -R . 2>/dev/null || echo "\"$core_process\"")"
    service_json+="}"
    
    service_json+="}"
    echo "$service_json"
}

# 函数：收集日志信息
collect_log_info() {
    local log_json="{"
    
    # 证书信任日志
    local trustca_log="/tmp/nursor_trustca.log"
    if [ -f "$trustca_log" ]; then
        local trustca_lines=$(tail -50 "$trustca_log" 2>/dev/null | head -20 || echo "")
        log_json+="\"trustca_log\": {\"path\": \"$trustca_log\", \"exists\": true, \"recent_lines\": $(echo "$trustca_lines" | jq -R -s . 2>/dev/null || echo "\"$trustca_lines\"")},"
    else
        log_json+="\"trustca_log\": {\"path\": \"$trustca_log\", \"exists\": false},"
    fi
    
    # 核心服务日志
    local core_log="/var/log/nursor-core.log"
    if [ -f "$core_log" ] && [ -r "$core_log" ]; then
        local core_lines=$(tail -50 "$core_log" 2>/dev/null | head -20 || echo "")
        log_json+="\"core_log\": {\"path\": \"$core_log\", \"exists\": true, \"recent_lines\": $(echo "$core_lines" | jq -R -s . 2>/dev/null || echo "\"$core_lines\"")},"
    else
        log_json+="\"core_log\": {\"path\": \"$core_log\", \"exists\": false, \"readable\": $([ -r "$core_log" ] && echo "true" || echo "false")},"
    fi
    
    # Sentry 错误日志
    local sentry_log="/tmp/nursor_sentry_error.log"
    if [ -f "$sentry_log" ]; then
        local sentry_lines=$(tail -20 "$sentry_log" 2>/dev/null || echo "")
        log_json+="\"sentry_error_log\": {\"path\": \"$sentry_log\", \"exists\": true, \"recent_lines\": $(echo "$sentry_lines" | jq -R -s . 2>/dev/null || echo "\"$sentry_lines\"")},"
    else
        log_json+="\"sentry_error_log\": {\"path\": \"$sentry_log\", \"exists\": false},"
    fi
    
    # 系统日志（最近的安装相关）
    local sys_log="/var/log/install.log"
    if [ -f "$sys_log" ] && [ -r "$sys_log" ]; then
        local sys_lines=$(grep -i "nursor\|org.nursor" "$sys_log" 2>/dev/null | tail -10 || echo "")
        log_json+="\"system_log\": {\"path\": \"$sys_log\", \"recent_nursor_lines\": $(echo "$sys_lines" | jq -R -s . 2>/dev/null || echo "\"$sys_lines\"")}"
    else
        log_json+="\"system_log\": {\"path\": \"$sys_log\", \"readable\": false}"
    fi
    
    log_json+="}"
    echo "$log_json"
}

# 函数：收集证书状态
collect_certificate_info() {
    local cert_json="{"
    
    local ca_path="/Library/Application Support/Nursor/ca.pem"
    
    # 证书文件信息
    cert_json+="\"cert_file\": {"
    cert_json+="\"path\": \"$ca_path\","
    cert_json+="\"exists\": $([ -f "$ca_path" ] && echo "true" || echo "false"),"
    if [ -f "$ca_path" ]; then
        cert_json+="\"size\": $(stat -f%z "$ca_path" 2>/dev/null || echo "0"),"
        cert_json+="\"readable\": $([ -r "$ca_path" ] && echo "true" || echo "false")"
    fi
    cert_json+="},"
    
    # 检查证书是否在钥匙串中
    local cert_in_keychain="false"
    if security find-certificate -c "nursor" -a /Library/Keychains/System.keychain >/dev/null 2>&1; then
        cert_in_keychain="true"
    fi
    cert_json+="\"in_keychain\": $cert_in_keychain"
    
    cert_json+="}"
    echo "$cert_json"
}

# 函数：发送 Sentry 事件
send_to_sentry() {
    local payload_type="${1:-message}"  # "message" 或 "exception" (用于构建 payload)
    local level="${2:-info}"            # "error", "info", "warning"
    local message="${3:-}"
    local user_extra="${4:-{}}"
    
    # Sentry Envelope item type 必须始终是 "event"
    # 这是 Envelope 格式要求，不是事件内容类型
    local envelope_item_type="event"
    
    # 只发送 warning 和 error 级别的事件
    if [ "$level" != "warning" ] && [ "$level" != "error" ]; then
        return 0
    fi
    
    # 自动收集诊断信息
    local system_info=$(collect_system_info)
    local context_info=$(collect_context_info "$SCRIPT_NAME" "${BASH_LINENO[0]}" 0)
    local filesystem_info=$(collect_filesystem_info)
    local service_info=$(collect_service_info)
    local log_info=$(collect_log_info)
    local cert_info=$(collect_certificate_info)
    
    # 合并所有额外信息
    # 注意：将诊断信息嵌套在 "diagnostics" 对象下，避免与 Sentry 保留字段冲突
    local enriched_extra
    enriched_extra=$(cat <<EOF
{
  "user_provided": $user_extra,
  "diagnostics": {
    "system_info": $system_info,
    "context_info": $context_info,
    "filesystem_info": $filesystem_info,
    "service_info": $service_info,
    "log_info": $log_info,
    "certificate_info": $cert_info
  }
}
EOF
)
    
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
    "script": "$SCRIPT_NAME",
    "level": "$level"
  },
  "extra": $enriched_extra,
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
    "script": "$SCRIPT_NAME",
    "level": "$level"
  },
  "extra": $enriched_extra,
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
    local func_name="${FUNCNAME[1]:-unknown}"
    
    # 收集错误上下文信息
    local error_context="{\"exit_code\": $exit_code, \"line\": $line_number, \"script\": \"$script_name\", \"function\": \"$func_name\""
    
    # 添加最近的命令历史（如果有）
    if [ -n "${BASH_COMMAND:-}" ]; then
        error_context+=", \"last_command\": \"${BASH_COMMAND}\""
    fi
    
    error_context+="}"
    
    # 发送错误事件（会自动收集所有诊断信息）
    send_to_sentry "exception" "error" "$SCRIPT_NAME 脚本执行失败 (退出码: $exit_code, 行号: $line_number, 函数: $func_name)" "$error_context"
    
    return $exit_code
}
