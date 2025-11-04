# Windows 安装程序构建指南

## 📋 概述

本文档说明如何在 CI/CD 中自动构建 Windows 安装程序。

## 🏗️ 构建流程

### 步骤 1: 下载 Flutter 应用
- 使用 `actions/checkout@v4` 从 `nursor-flutter-app` 仓库下载源代码
- 自动处理身份验证（支持私有仓库）

### 步骤 2: 构建 Flutter 应用
- 执行 `flutter build windows --release`
- 构建输出位于：`flutter_app/build/windows/x64/runner/Release`

### 步骤 3: 下载 nursor-core
- 从 `nursor-core2` 仓库的 Release 下载 `core-windows-amd64`
- 可选：验证 SHA256 checksum

### 步骤 4: 准备构建环境
将所有必需文件复制到 `windows_build` 目录：

**从 Flutter 构建产物复制：**
- `nursor_app.exe`（或其他名称的主可执行文件）
- `flutter_windows.dll`
- 所有 Flutter plugin DLLs
- `data/` 目录及其内容

**从当前项目的 `windows/` 目录复制：**
- `nursor-core-amd64.dll` - 核心服务 DLL
- `wintun.dll` - WinTun 网络驱动（如果存在，覆盖 Flutter 构建中的版本）
- `ca.pem` - CA 证书文件
- `logo.ico` - 安装程序图标

### 步骤 5: 构建安装程序
- 在 `windows_build` 目录中执行 Inno Setup
- 自动更新 Inno Setup 脚本中的路径和版本号
- 自动检测可执行文件名并更新脚本

## 🔧 Inno Setup 脚本配置

### 动态配置项

以下配置项会在 CI/CD 中自动更新：

```iss
#define MySourcePath "."      ; CI/CD 设置为当前构建目录
#define MyAppVersion "1.0.0"  ; CI/CD 从 tag 获取版本号
#define MyIconPath "logo.ico" ; CI/CD 确保图标在构建目录
#define MyAppExeName "..."    ; CI/CD 自动检测可执行文件名
```

### 必需文件

Inno Setup 脚本期望以下文件在 `MySourcePath` 目录中：

**必需：**
- 主可执行文件（`.exe`）- 自动检测
- `logo.ico` - 安装程序图标
- `ca.pem` - CA 证书
- `wintun.dll` - WinTun 驱动
- `nursor-core-amd64.dll` - 核心服务

**Flutter 依赖（可选，通常存在）：**
- `flutter_windows.dll`
- `nursorcore_plugin.dll`
- `screen_retriever_plugin.dll`
- `sentry.dll`
- `tray_manager_plugin.dll`
- `window_manager_plugin.dll`

**可选：**
- `data/` 目录 - Flutter 应用数据

## 📁 目录结构

### 构建前的结构

```
.
├── flutter_app/
│   └── build/
│       └── windows/
│           └── x64/
│               └── runner/
│                   └── Release/
│                       ├── nursor_app.exe
│                       ├── flutter_windows.dll
│                       ├── *.dll
│                       └── data/
├── windows/
│   ├── nursor-core-amd64.dll
│   ├── wintun.dll
│   ├── ca.pem
│   └── logo.ico
└── nursor_win_installer.iss
```

### 构建时的结构

```
.
├── windows_build/          (构建目录)
│   ├── nursor_app.exe      (来自 Flutter)
│   ├── flutter_windows.dll  (来自 Flutter)
│   ├── *.dll               (来自 Flutter)
│   ├── nursor-core-amd64.dll (来自 windows/)
│   ├── wintun.dll          (来自 windows/，覆盖 Flutter 版本)
│   ├── ca.pem              (来自 windows/)
│   ├── logo.ico            (来自 windows/)
│   ├── data/               (来自 Flutter)
│   └── nursor_win_installer.iss (更新后的脚本)
└── output/                 (安装程序输出)
    └── NursorInstaller.exe
```

## ✅ 工作流步骤详解

### 1. Prepare Windows build environment

```powershell
# 复制 Flutter 构建产物
Copy-Item -Recurse "flutter_app\build\windows\x64\runner\Release\*" "windows_build\"

# 复制额外文件
Copy-Item "windows\nursor-core-amd64.dll" "windows_build\"
Copy-Item "windows\wintun.dll" "windows_build\" -Force
Copy-Item "windows\ca.pem" "windows_build\" -Force
Copy-Item "windows\logo.ico" "windows_build\" -Force
```

### 2. Build Windows installer

```powershell
# 在 windows_build 目录中
# 1. 检测可执行文件名
# 2. 更新 Inno Setup 脚本（路径、版本、可执行文件名）
# 3. 验证所有必需文件存在
# 4. 执行 ISCC 构建安装程序
```

## 🔍 故障排除

### 错误：Required file not found

**可能原因：**
1. Flutter 构建失败
2. `windows/` 目录中缺少文件
3. 文件路径不正确

**解决方案：**
- 检查构建日志中的文件列表
- 确认所有文件都存在于预期位置
- 检查文件权限

### 错误：Inno Setup compilation failed

**可能原因：**
1. Inno Setup 脚本语法错误
2. 必需文件缺失
3. 路径问题

**解决方案：**
- 查看 ISCC 的详细错误输出
- 检查更新后的 `.iss` 文件内容
- 验证所有文件路径正确

### 错误：可执行文件检测失败

**可能原因：**
- Flutter 构建没有生成 `.exe` 文件
- 可执行文件名不符合预期

**解决方案：**
- 检查 Flutter 构建日志
- 查看构建目录中的 `.exe` 文件列表
- 如果文件名不是 `nursor_app.exe`，脚本会自动更新

## 📝 注意事项

1. **文件覆盖顺序**
   - `windows/` 目录中的文件会覆盖 Flutter 构建中的同名文件
   - 这对于 `wintun.dll` 很重要，可能需要特定版本

2. **版本号格式**
   - Tag 格式：`v1.0.0`
   - Inno Setup 版本号：`1.0.0`（自动移除 'v' 前缀）

3. **可执行文件名**
   - 脚本会自动检测主可执行文件
   - 如果文件名不是 `nursor_app.exe`，会自动更新 Inno Setup 脚本

4. **输出位置**
   - 安装程序输出到：`output/NursorInstaller.exe`
   - 使用 `/O` 参数指定输出目录

## 🔗 相关文档

- `nursor_win_installer.iss` - Inno Setup 脚本
- `.github/workflows/build-all-platforms.yml` - CI/CD 工作流
- `.github/FIX_DOWNLOAD_ERRORS.md` - 下载错误修复指南

