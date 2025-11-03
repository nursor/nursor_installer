#!/bin/bash

# --- 检查是否以 root 权限运行 ---
if [ "$(id -u)" -ne 0 ]; then
   echo "此脚本需要以 root 权限运行。请使用 'sudo ./build_installer.sh' 执行。"
   exit 1
fi

# --- 定义变量 ---
INSTALLER_NAME="NursorInstaller"
APP_NAME="Nursor.app"
CORE_BINARY_NAME="nursor-core"
CA_PEM_NAME="ca.pem"
LAUNCHD_PLIST_NAME="org.nursor.nursor-core.plist"
TRUSTCA_PLIST_NAME="org.nursor.trustca.plist"
CA_ONCE_SH_NAME="trust_ca_once.sh"

# **重要：pkgbuild 的 identifier 必须与 Nursor.app/Contents/Info.plist 中的 CFBundleIdentifier 保持一致**
# 根据 Nursor.app/Contents/Info.plist，CFBundleIdentifier 为 org.nursor.nursorApp
APP_IDENTIFIER="org.nursor.nursorApp"

# 临时工作目录
BUILD_DIR="${PWD}/build_temp"
OUTPUT_DIR="${PWD}/output" # 最终 .pkg 的输出目录

# 清理旧的构建文件
echo "清理旧的构建文件..."
rm -rf "$BUILD_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

echo "--- 开始构建 Nursor 统一安装包 (含即时重签名) ---"

# --- 创建 Nursor.app 的临时干净副本并清理、重签名 ---
# 这一步是为了确保打包的 Nursor.app 不带任何可能导致 PackageKit 混淆的原始构建路径信息。
echo "创建 Nursor.app 的干净副本..."
TEMP_APP_COPY_PATH="${BUILD_DIR}/temp_nursor_app_clean/${APP_NAME}"
mkdir -p "$(dirname "${TEMP_APP_COPY_PATH}")" # 创建父目录

if [ ! -d "${APP_NAME}" ]; then
    echo "ERROR: Original Nursor.app not found in the current directory (${PWD}/${APP_NAME}). Please ensure it's here before running the script."
    exit 1
fi

# 使用 rsync 复制以保留更多属性，并确保复制成功
rsync -a "${APP_NAME}" "$(dirname "${TEMP_APP_COPY_PATH}")/" || { echo "ERROR: Failed to copy original Nursor.app to temporary clean directory."; exit 1; }

# 清理干净副本的扩展属性
echo "清理 Nursor.app 干净副本的扩展属性..."
sudo xattr -rc "${TEMP_APP_COPY_PATH}" || { echo "ERROR: Failed to clean extended attributes for temporary clean ${APP_NAME}. Check permissions."; exit 1; }

# 移除应用程序包内的 _CodeSignature 目录 (强烈推荐，避免签名问题)
echo "移除 Nursor.app 干净副本内的 _CodeSignature 目录..."
if [ -d "${TEMP_APP_COPY_PATH}/Contents/_CodeSignature" ]; then
    sudo rm -rf "${TEMP_APP_COPY_PATH}/Contents/_CodeSignature" || { echo "ERROR: Failed to remove _CodeSignature from temporary clean ${APP_NAME}."; exit 1; }
fi

# **新增：对干净副本进行即时签名 (ad-hoc signing)**
# 这可能会覆盖或清除导致 PackageKit 重定位的深层嵌入路径信息。
echo "对 Nursor.app 干净副本进行即时签名 (ad-hoc signing)..."
# 使用 '-' 进行即时签名，'--deep' 递归签名内部所有可执行文件和框架
sudo codesign --force --deep --sign - "${TEMP_APP_COPY_PATH}"
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to ad-hoc sign temporary clean ${APP_NAME}. Check codesign utility and permissions."
    exit 1
fi

# 确保复制后的 Nursor.app 具有正确的权限
echo "设置 Nursor.app 干净副本的权限..."
chmod -R 755 "${TEMP_APP_COPY_PATH}" || { echo "ERROR: Failed to set permissions for temporary clean Nursor.app."; exit 1; }
chmod +x "${TEMP_APP_COPY_PATH}/Contents/MacOS/"* || { echo "WARNING: Could not set execute permissions for all binaries in temporary clean Nursor.app. This might be normal if some are not executables."; }


# --- 1. 创建 Nursor.app 组件包 ---
echo "构建 Nursor.app 组件包..."

# 创建一个临时的文件系统根目录，用于 pkgbuild
# 这里的结构将直接映射到安装目标 /
APP_PAYLOAD_ROOT="${BUILD_DIR}/app_payload_root"
mkdir -p "${APP_PAYLOAD_ROOT}/Applications" # 在临时根目录下创建 /Applications 目录

# 复制 Nursor.app (已清理、重签名) 到临时根目录的 /Applications 路径下
echo "复制 Nursor.app 干净副本到临时 payload 根目录..."
rsync -a "${TEMP_APP_COPY_PATH}" "${APP_PAYLOAD_ROOT}/Applications/" || { echo "ERROR: Failed to copy clean Nursor.app to temporary payload root directory."; exit 1; }


# 使用 --root 方式打包 Nursor.app
# --root 指定了包的“内容”来源 (${APP_PAYLOAD_ROOT})
# --install-location "/" 意味着 ${APP_PAYLOAD_ROOT} 中的内容将直接复制到目标系统的根目录
# 因此，${APP_PAYLOAD_ROOT}/Applications/Nursor.app 将被安装到 /Applications/Nursor.app
pkgbuild \
    --root "${APP_PAYLOAD_ROOT}" \
    --install-location "/" \
    --identifier "${APP_IDENTIFIER}" \
    --version "1.0" \
    --ownership "recommended" \
    "${BUILD_DIR}/org.nursor.NursorApp.pkg"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build NursorApp.pkg"
    exit 1
fi

# --- 2. 创建 nursor-core 和 plist 组件包 ---
echo "构建 nursor-core 及 Launchd Plist 组件包..."

# 创建一个临时的根目录结构，用于 pkgbuild
CORE_PAYLOAD_ROOT="${BUILD_DIR}/core_payload_root"
mkdir -p "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor"
mkdir -p "${CORE_PAYLOAD_ROOT}/Library/LaunchDaemons"

# 复制文件到临时结构
cp "${CORE_BINARY_NAME}" "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor/${CORE_BINARY_NAME}" || { echo "ERROR: Failed to copy ${CORE_BINARY_NAME}."; exit 1; }
cp "${LAUNCHD_PLIST_NAME}" "${CORE_PAYLOAD_ROOT}/Library/LaunchDaemons/${LAUNCHD_PLIST_NAME}" || { echo "ERROR: Failed to copy ${LAUNCHD_PLIST_NAME}."; exit 1; }
cp "${CA_PEM_NAME}" "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor/${CA_PEM_NAME}" || { echo "ERROR: Failed to copy ${CA_PEM_NAME}."; exit 1; }
cp "${CA_ONCE_SH_NAME}" "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor/${CA_ONCE_SH_NAME}" || { echo "ERROR: Failed to copy ${CA_ONCE_SH_NAME}."; exit 1; }

# 复制 Sentry 集成库到安装目录，以便 trust_ca_once.sh 可以加载它
SENTRY_LIB_NAME="scripts/send_to_sentry.sh"
if [ -f "${SENTRY_LIB_NAME}" ]; then
    cp "${SENTRY_LIB_NAME}" "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor/send_to_sentry.sh" || { echo "WARNING: Failed to copy ${SENTRY_LIB_NAME}. Sentry integration may not work in trust_ca_once.sh."; }
    chmod +x "${CORE_PAYLOAD_ROOT}/Library/Application Support/Nursor/send_to_sentry.sh" || { echo "WARNING: Failed to set execute permissions for send_to_sentry.sh."; }
else
    echo "WARNING: ${SENTRY_LIB_NAME} not found. Sentry integration may not work in trust_ca_once.sh."
fi

# 确保脚本目录存在且脚本可执行
if [ ! -d "scripts" ]; then
    echo "ERROR: 'scripts' directory not found. Please ensure it exists and contains preinstall/postinstall scripts."
    exit 1
fi
chmod +x "scripts/preinstall" || { echo "ERROR: Failed to set execute permissions for scripts/preinstall."; exit 1; }
chmod +x "scripts/postinstall" || { echo "ERROR: Failed to set execute permissions for scripts/postinstall."; exit 1; }

# --scripts 参数指定脚本目录
pkgbuild \
    --root "${CORE_PAYLOAD_ROOT}" \
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

    <options customize="no" require-scripts="true" rootVolumeOnly="true" hostArchitectures="arm64,x86_64"/>

    <welcome file="welcome.html" mime-type="text/html"/>
    <conclusion file="conclusion.html" mime-type="text/html"/>

    <choices-outline>
        <line choice="default"/>
        <line choice="app"/>
        <line choice="daemon"/>
    </choices-outline>

    <choice id="default" title="Nursor">
        <pkg-ref id="${APP_IDENTIFIER}">org.nursor.NursorApp.pkg</pkg-ref>
        <pkg-ref id="org.nursor.nursor-core.daemon">org.nursor.nursor-core.daemon.pkg</pkg-ref>
    </choice>

    <choice id="app" title="Nursor Application">
        <pkg-ref id="${APP_IDENTIFIER}">org.nursor.NursorApp.pkg</pkg-ref>
    </choice>

    <choice id="daemon" title="Nursor Core Service (Requires Root)">
        <pkg-ref id="org.nursor.nursor-core.daemon">org.nursor.nursor-core.daemon.pkg</pkg-ref>
    </choice>

    <pkg-ref id="${APP_IDENTIFIER}" version="1.0" />
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
        <li>如果应用程序未出现在 Launchpad 中，请尝试重启您的 Mac，或在终端中运行 <code>killall Dock</code> 来刷新 Launchpad 索引。</li>
    </ul>
    <p>感谢您的使用！</p>
</body>
</html>
EOF


# --- 5. 构建最终的安装包 ---
echo "构建最终的安装包..."
productbuild \
    --distribution "${BUILD_DIR}/distribution.xml" \
    --resources "${BUILD_DIR}" \
    --package-path "${BUILD_DIR}" \
    "${OUTPUT_DIR}/${INSTALLER_NAME}.pkg"

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to build final installer package."
    exit 1
fi

echo "--- Nursor 统一安装包构建完成：${OUTPUT_DIR}/${INSTALLER_NAME}.pkg ---"

# 提示用户进行下一步操作
echo "请使用 'sudo installer -pkg \"${OUTPUT_DIR}/${INSTALLER_NAME}.pkg\" -target /' 进行测试安装。"
echo "安装完成后，请按照上述排查步骤检查 Nursor.app 是否出现在 Launchpad 中。"

# 清理临时文件
echo "清理临时文件..."
rm -rf "$BUILD_DIR"
