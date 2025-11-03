# 修复 build_installer.sh 命令未找到错误

## 🔴 错误信息

```
sudo: ./build_installer.sh: command not found
Error: Process completed with exit code 1.
```

## 🔍 问题原因

1. **脚本文件不存在**：`build_installer.sh` 可能不在预期位置
2. **执行权限缺失**：脚本文件可能没有执行权限
3. **路径问题**：工作目录可能不正确

## ✅ 已应用的修复

### 1. 在文件检查中添加脚本检查

在 "Prepare macOS build environment" 步骤中：
- 添加 `build_installer.sh` 到必需文件列表
- 检查脚本是否存在
- 设置执行权限
- 显示调试信息

```yaml
REQUIRED_FILES=(
  "build_installer.sh"  # ✅ 新增检查
  "nursor-core"
  "Nursor.app"
  # ... 其他文件
)

# 确保 build_installer.sh 有执行权限
if [ -f "build_installer.sh" ]; then
  chmod +x build_installer.sh
  echo "✓ build_installer.sh 已设置执行权限"
  ls -l build_installer.sh
fi
```

### 2. 在执行前再次验证

在 "Build macOS installer" 步骤中：
- 再次检查脚本是否存在
- 确认执行权限
- 显示当前目录和内容（用于调试）
- 验证输出目录

```yaml
- name: Build macOS installer
  working-directory: ./macos
  run: |
    # 再次确认脚本存在
    if [ ! -f "build_installer.sh" ]; then
      echo "ERROR: build_installer.sh not found in current directory"
      echo "Current directory: $(pwd)"
      ls -lah
      exit 1
    fi
    
    # 确保有执行权限
    if [ ! -x "build_installer.sh" ]; then
      chmod +x build_installer.sh
    fi
    
    # 执行脚本
    sudo ./build_installer.sh
```

## 📋 文件位置

脚本应该位于仓库的 `macos/` 目录中：

```
nursor_install/
└── macos/
    └── build_installer.sh  ← 应该在这里
```

当 `working-directory: ./macos` 时，脚本应该可以通过 `./build_installer.sh` 访问。

## 🔧 验证步骤

### 1. 检查脚本是否存在

在 "Prepare macOS build environment" 步骤中，会输出：
```
检查必需文件...
✓ build_installer.sh 已设置执行权限
-rwxr-xr-x  1 runner  staff  XXXXX  build_installer.sh
所有必需文件检查通过！
```

### 2. 检查执行权限

脚本文件应该有 `x` (执行) 权限：
```bash
-rwxr-xr-x  1 runner  staff  XXXXX  build_installer.sh
```

### 3. 检查当前目录

如果仍然失败，会显示：
```
Current directory: /path/to/macos
Directory contents:
total XX
drwxr-xr-x  ... build_installer.sh
```

## 💡 工作原理

1. **Checkout 仓库**：`build_installer.sh` 从仓库 checkout 到 `macos/` 目录
2. **设置工作目录**：`working-directory: ./macos` 将当前目录设置为 `macos/`
3. **检查文件**：验证脚本是否存在
4. **设置权限**：`chmod +x build_installer.sh` 赋予执行权限
5. **执行脚本**：`sudo ./build_installer.sh` 以 root 权限执行

## 🎯 预期结果

修复后，应该看到：

```
检查必需文件...
✓ build_installer.sh 已设置执行权限
-rwxr-xr-x  1 runner  staff  XXXXX  build_installer.sh
所有必需文件检查通过！

...

Executing build_installer.sh...
Building macOS installer...
✓ Installer created successfully
```

## 📝 注意事项

1. **脚本位置**：确保 `build_installer.sh` 在仓库的 `macos/` 目录中
2. **执行权限**：脚本需要执行权限（`chmod +x`）
3. **文件格式**：确保脚本使用 Unix 行尾（LF），而不是 Windows 行尾（CRLF）
4. **Shebang**：脚本应该有正确的 shebang：`#!/bin/bash`

## 🔍 如果仍然失败

如果仍然出现 "command not found" 错误：

1. **检查脚本内容**：
   - 查看工作流日志中的 "Prepare macOS build environment" 步骤
   - 确认脚本是否在必需文件列表中

2. **检查文件格式**：
   - 确保脚本使用 LF 行尾
   - 检查 shebang 是否正确

3. **检查路径**：
   - 确认 `working-directory: ./macos` 正确
   - 查看日志中的 "Current directory" 输出

4. **检查 Git 权限**：
   - 确保脚本文件已提交到仓库
   - 检查 `.gitattributes` 或 `.gitignore` 是否排除了脚本

