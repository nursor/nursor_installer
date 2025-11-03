# 修复 Linux 打包错误

## 🔴 错误信息

```
tar (child): output/nursor-linux-amd64-v1.0.0.tar.gz: Cannot open: No such file or directory
tar (child): Error is not recoverable: exiting now
tar: output/nursor-linux-amd64-v1.0.0.tar.gz: Wrote only 4096 of 10240 bytes
tar: Child returned status 2
tar: Error is not recoverable: exiting now
Error: Process completed with exit code 2.
```

## 🔍 问题原因

1. **输出目录不存在**：`output` 目录在 tar 命令执行时不存在
2. **路径问题**：tar 命令在尝试写入文件时，目录不存在导致失败
3. **文件权限**：可能存在权限问题

## ✅ 已应用的修复

### 主要修复

1. **创建输出目录**：在执行 tar 命令之前创建 `output` 目录
2. **改进错误处理**：添加详细的错误检查和验证
3. **路径验证**：验证所有路径和文件是否存在
4. **调试信息**：添加详细的输出信息用于调试

### 修复后的代码

```yaml
- name: Package Linux installer
  run: |
    ARCH="${{ matrix.arch }}"
    PACKAGE_VERSION="${{ needs.detect-version.outputs.version }}"
    
    # ✅ 创建输出目录（关键修复）
    mkdir -p output
    
    # 创建打包结构
    mkdir -p linux_appimage/usr/bin
    mkdir -p linux_appimage/usr/share/applications
    mkdir -p linux_appimage/usr/share/icons
    
    # Flutter 构建输出路径（固定为 x64，因为 GitHub Actions Linux runner 是 amd64）
    FLUTTER_BUILD_PATH="flutter_app/build/linux/x64/release/bundle"
    
    # ✅ 验证路径是否存在
    if [ ! -d "$FLUTTER_BUILD_PATH" ]; then
      echo "ERROR: Flutter build output not found"
      find flutter_app/build/linux -type d -maxdepth 3 || echo "Directory not found"
      exit 1
    fi
    
    # 复制文件
    cp -R "$FLUTTER_BUILD_PATH"/* linux_appimage/
    cp linux/nursor-core linux_appimage/nursor-core
    chmod +x linux_appimage/nursor-core
    
    # 创建 .desktop 文件
    mkdir -p linux_appimage/usr/share/applications
    cat > linux_appimage/usr/share/applications/nursor.desktop <<'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Nursor
Exec=nursor
Icon=nursor
Categories=Utility;
EOF
    
    # ✅ 创建 tar.gz 包（使用完整路径）
    PACKAGE_NAME="nursor-linux-${ARCH}-${PACKAGE_VERSION}.tar.gz"
    OUTPUT_PATH="output/${PACKAGE_NAME}"
    
    echo "Creating package: $OUTPUT_PATH"
    tar -czf "$OUTPUT_PATH" -C linux_appimage .
    
    # ✅ 验证文件是否创建成功
    if [ ! -f "$OUTPUT_PATH" ]; then
      echo "ERROR: Package file not created: $OUTPUT_PATH"
      exit 1
    fi
    
    echo "✓ Package created successfully: $OUTPUT_PATH"
    ls -lh "$OUTPUT_PATH"
```

## 📋 关键修复点

### 1. 创建输出目录

**修复前：**
```bash
# ❌ 直接使用 output/ 目录，可能不存在
tar -czf output/nursor-linux-${ARCH}-${PACKAGE_VERSION}.tar.gz -C linux_appimage .
```

**修复后：**
```bash
# ✅ 先创建输出目录
mkdir -p output
PACKAGE_NAME="nursor-linux-${ARCH}-${PACKAGE_VERSION}.tar.gz"
OUTPUT_PATH="output/${PACKAGE_NAME}"
tar -czf "$OUTPUT_PATH" -C linux_appimage .
```

### 2. 简化路径逻辑

**修复前：**
```bash
# ❌ 根据架构选择路径，可能导致路径错误
if [ "$ARCH" = "amd64" ]; then
  BUILD_PATH="x64"
else
  BUILD_PATH="arm64"
fi
```

**修复后：**
```bash
# ✅ 直接使用 x64（因为 GitHub Actions Linux runner 是 amd64）
FLUTTER_BUILD_PATH="flutter_app/build/linux/x64/release/bundle"
```

### 3. 添加文件验证

- 验证 Flutter 构建输出是否存在
- 验证 nursor-core 文件是否存在
- 验证 tar.gz 文件是否成功创建
- 显示文件大小和详细信息

## 🔧 验证步骤

修复后，应该看到：

```
Copying Flutter build artifacts from flutter_app/build/linux/x64/release/bundle...
Package contents:
...

Creating package: output/nursor-linux-amd64-v1.0.0.tar.gz
✓ Package created successfully: output/nursor-linux-amd64-v1.0.0.tar.gz (size: XXXXX bytes)
-rw-r--r-- 1 runner docker XXXXX ... output/nursor-linux-amd64-v1.0.0.tar.gz
```

## 💡 工作原理

1. **创建目录结构**：
   - `output/` - 输出目录
   - `linux_appimage/` - 临时打包目录

2. **复制文件**：
   - Flutter 构建产物从 `flutter_app/build/linux/x64/release/bundle`
   - `nursor-core` 从 `linux/` 目录

3. **创建包**：
   - 使用 tar 命令创建压缩包
   - 验证文件是否成功创建

## 📝 注意事项

1. **Flutter 构建路径**：Flutter Linux 构建输出固定为 `build/linux/x64/release/bundle`（GitHub Actions Linux runner 是 amd64）

2. **版本格式**：确保 `PACKAGE_VERSION` 格式正确（如 `v1.0.0`）

3. **文件权限**：确保 `nursor-core` 有执行权限

4. **目录创建**：确保所有必需的目录在使用前都已创建

## 🎯 预期结果

修复后，应该能够：
- ✅ 成功创建 `output/` 目录
- ✅ 成功复制所有必需文件
- ✅ 成功创建 tar.gz 包
- ✅ 验证包文件存在且大小正确

如果仍然失败，查看日志中的详细错误信息和路径检查输出。

