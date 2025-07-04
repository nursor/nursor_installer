#!/bin/bash

# --- 定义变量 ---
INSTALLER_NAME="NursorInstaller"
APP_NAME="Nursor.app"
CORE_BINARY_NAME="nursor-core"
LAUNCHD_PLIST_NAME="org.nursor.nursor-core.plist"

# 临时工作目录
BUILD_DIR="${PWD}/build_temp"
OUTPUT_DIR="${PWD}/output" # 最终 .pkg 的输出目录

# 清理旧的构建文件
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

echo "--- 开始构建 Nursor 安装包 ---"

# --- 1. 创建 Nursor.app 组件包 ---
echo "构建 Nursor.app 组件包..."
pkgbuild \
    --component "${APP_NAME}" \
    --install-location "/Applications" \
    --identifier "org.nursor.NursorApp" \
    --version "1.0" \
    --ownership "preserve" \
    "${BUILD_DIR}/org.nursor.NursorApp.pkg" # <-- 确保文件名与 identifier 匹配

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build NursorApp.pkg"
    exit 1
fi

# --- 2. 创建 nursor-core 和 plist 组件包 ---
echo "构建 nursor-core 及 Launchd Plist 组件包..."

# 创建一个临时的根目录结构，用于 pkgbuild
PAYLOAD_DIR="${BUILD_DIR}/payload_core"
mkdir -p "${PAYLOAD_DIR}/Library/Application Support/Nursor"
mkdir -p "${PAYLOAD_DIR}/Library/LaunchDaemons"

# 复制文件到临时结构
cp "${CORE_BINARY_NAME}" "${PAYLOAD_DIR}/Library/Application Support/Nursor/${CORE_BINARY_NAME}"
cp "${LAUNCHD_PLIST_NAME}" "${PAYLOAD_DIR}/Library/LaunchDaemons/${LAUNCHD_PLIST_NAME}"

chmod +x "scripts/preinstall"
chmod +x "scripts/postinstall"

# --scripts 参数指定脚本目录
pkgbuild \
    --root "${PAYLOAD_DIR}" \
    --install-location "/" \
    --identifier "org.nursor.nursor-core.daemon" \
    --version "1.0" \
    --ownership recommended \
    --scripts "scripts" \
    "${BUILD_DIR}/org.nursor.nursor-core.daemon.pkg"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build NursorCoreDaemon.pkg"
    exit 1
fi

# --- 3. 创建分发配置文件 (distribution.xml) ---
echo "创建 distribution.xml..."
cat > "${BUILD_DIR}/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2.0">
    <title>Nursor Installer</title>

    <options customize="no" require-scripts="false" rootVolumeOnly="true" hostArchitectures="x86_64"/>

    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>

    <choices-outline>
        <line choice="default"/>
        <line choice="app"/>
        <line choice="daemon"/>
    </choices-outline>

    <choice id="default" title="Nursor">
        <pkg-ref id="org.nursor.NursorApp">org.nursor.NursorApp.pkg</pkg-ref>
        <pkg-ref id="org.nursor.nursor-core.daemon">org.nursor.nursor-core.daemon.pkg</pkg-ref>
    </choice>

    <choice id="app" title="Nursor Application">
        <pkg-ref id="org.nursor.NursorApp">org.nursor.NursorApp.pkg</pkg-ref>
    </choice>

    <choice id="daemon" title="Nursor Core Service (Requires Root)">
        <pkg-ref id="org.nursor.nursor-core.daemon">org.nursor.nursor-core.daemon.pkg</pkg-ref>
    </choice>

    <pkg-ref id="org.nursor.NursorApp" version="1.0" />
    <pkg-ref id="org.nursor.nursor-core.daemon" version="1.0" />
</installer-gui-script>
EOF


# --- 4. 添加欢迎和结束页面 (保持不变) ---
echo "创建欢迎和结束页面..."
cat > "${BUILD_DIR}/welcome.html" <<EOF
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
    <h1>欢迎使用 Nursor 安装程序</h1>
    <p>此程序将安装 Nursor 应用程序及其核心服务。</p>
    <p><strong>重要提示：</strong></p>
    <ul>
        <li>为了使核心服务正常运行，您可能需要<b>关闭系统完整性保护 (SIP)</b>。</li>
        <li>安装过程中将提示您输入管理员密码。</li>
        <li>安装完成后，首次运行 Nursor.app 时，您可能需要在<b>“系统设置”->“隐私与安全性”</b>中手动允许它运行。</li>
        <li>如果您遇到问题，请检查日志文件 <code>/var/log/nursor-core.log</code>。</li>
    </ul>
    <p>点击“继续”开始安装。</p>
</body>
</html>
EOF

cat > "${BUILD_DIR}/conclusion.html" <<EOF
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body>
    <h1>Nursor 安装完成</h1>
    <p>Nursor 应用程序已成功安装到您的<b>“应用程序”</b>文件夹。</p>
    <p>核心服务 <code>org.nursor.nursor-core</code> 已注册并启动。</p>
    <p>如果您在启动应用程序后遇到任何功能问题，请检查以下事项：</p>
    <ul>
        <li>确保 SIP 已关闭。</li>
        <li>首次运行 Nursor.app 时，请确保在<b>“系统设置”->“隐私与安全性”</b>中允许了它。</li>
        <li>检查核心服务的日志文件：<code>/var/log/nursor-core.log</code>。</li>
    </ul>
    <p>感谢您的使用！</p>
</body>
</html>
EOF


# --- 5. 组合所有组件包成最终的 .pkg (保持不变) ---
echo "组合所有组件包成最终的 .pkg 文件..."
productbuild \
    --distribution "${BUILD_DIR}/distribution.xml" \
    --resources "${BUILD_DIR}" \
    --package-path "${BUILD_DIR}" \
    "${OUTPUT_DIR}/${INSTALLER_NAME}.pkg"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build final .pkg"
    exit 1
fi

echo "--- Nursor 安装包构建完成！---"
echo "您可以在 '${OUTPUT_DIR}/${INSTALLER_NAME}.pkg' 找到安装包。"

# 清理临时文件 (可选)
# rm -rf "$BUILD_DIR"
echo "临时构建文件已清理。"

exit 0