# 修复 --target-platform 选项错误

## 🔴 错误信息

```
Could not find an option named "--target-platform".
Run 'flutter -h' (or 'flutter <command> -h') for available flutter commands and options.
Error: Process completed with exit code 64.
```

## 🔍 问题原因

`flutter build` 命令不支持 `--target-platform` 选项。Flutter 会根据运行器的架构自动构建对应架构的版本。

### 错误的用法

```bash
flutter build macos --release --target-platform=darwin-x64  # ❌ 不支持
flutter build linux --release --target-platform=linux-x64    # ❌ 不支持
```

## ✅ 已应用的修复

### 1. macOS 构建命令

**修复前：**
```yaml
- name: Build Flutter App for macOS
  run: |
    flutter pub get
    if [ "${{ matrix.arch }}" = "amd64" ]; then
      flutter build macos --release --target-platform=darwin-x64  # ❌
    else
      flutter build macos --release --target-platform=darwin-arm64  # ❌
    fi
```

**修复后：**
```yaml
- name: Build Flutter App for macOS
  run: |
    flutter pub get
    # Flutter 会根据运行器的架构自动构建对应架构的版本
    flutter build macos --release  # ✅
```

### 2. Linux 构建命令

**修复前：**
```yaml
- name: Build Flutter App for Linux
  run: |
    flutter pub get
    if [ "${{ matrix.arch }}" = "amd64" ]; then
      flutter build linux --release --target-platform=linux-x64  # ❌
    else
      flutter build linux --release --target-platform=linux-arm64  # ❌
    fi
```

**修复后：**
```yaml
- name: Build Flutter App for Linux
  run: |
    flutter pub get
    # Flutter 会根据运行器的架构自动构建对应架构的版本
    flutter build linux --release  # ✅
```

## 💡 工作原理

Flutter 构建命令会根据运行器的架构自动选择目标架构：

- **macOS**: 
  - 在 Intel (x64) runner 上运行 → 自动构建 x64 版本
  - 在 Apple Silicon (arm64) runner 上运行 → 自动构建 arm64 版本

- **Linux**:
  - GitHub Actions Linux runner 通常是 amd64
  - 自动构建 x64 版本

- **Windows**:
  - GitHub Actions Windows runner 是 amd64
  - 自动构建 x64 版本

## 📋 架构配置

### macOS 多架构构建

如果要构建多个架构（amd64 和 arm64），需要使用矩阵策略：

```yaml
strategy:
  matrix:
    arch: [amd64, arm64]
```

GitHub Actions 的 macOS runner 会根据可用性自动选择合适的架构。通常：
- `macos-14` 可能是 Apple Silicon (arm64)
- 如果需要 Intel (amd64)，可能需要使用特定的 runner 标签

### 实际行为

- **matrix.arch = amd64**: 期望在 Intel macOS runner 上运行，构建 x64 版本
- **matrix.arch = arm64**: 期望在 Apple Silicon macOS runner 上运行，构建 arm64 版本

如果 GitHub Actions 的 macOS runner 只有一种架构可用，可能需要：
1. 使用 universal binary（如果 Flutter 支持）
2. 使用自托管 runner
3. 或者只构建一个架构

## 🔧 验证修复

重新运行工作流后，应该看到：

```
✓ Resolving dependencies...
✓ Building macOS application...
✓ Build succeeded
```

## 📝 注意事项

1. **架构自动检测**: Flutter 会自动检测运行器的架构并构建对应的版本

2. **多架构支持**: 如果需要同时支持多个架构：
   - macOS: 可以构建 universal binary（如果 Flutter 支持）
   - Linux: 目前 GitHub Actions 只支持 amd64 runner
   - Windows: GitHub Actions 只支持 amd64 runner

3. **依赖警告**: 关于 "23 packages have newer versions" 的警告是信息性的，不影响构建。如果需要更新依赖，可以在 Flutter 项目中运行 `flutter pub upgrade`。

## 🎯 预期结果

修复后，所有平台都应该能够：
- ✅ 成功运行 `flutter pub get`
- ✅ 成功构建 Flutter 应用（无 `--target-platform` 错误）
- ✅ 生成正确架构的构建产物
- ✅ 创建安装包

