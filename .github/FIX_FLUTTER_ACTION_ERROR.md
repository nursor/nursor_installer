# 修复 Flutter Action 版本错误

## 🔴 错误信息

```
Unable to determine Flutter version for channel: stable version: stable architecture: x64
Error: Process completed with exit code 1.
```

## 🔍 问题原因

`subosito/flutter-action@v2` 的 `flutter-version` 参数不能设置为 `'stable'`。该参数需要：
- **具体的版本号**（如 `'3.27.0'`）
- **或者不指定**（仅指定 `channel`）

如果同时指定 `flutter-version: 'stable'` 和 `channel: 'stable'`，action 无法确定要使用哪个版本。

## ✅ 已应用的修复

### 移除 `flutter-version` 参数

**修复前：**
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: 'stable'  # ❌ 错误：不能使用 'stable' 作为版本号
    channel: 'stable'
```

**修复后：**
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: 'stable'  # ✅ 正确：只指定通道，自动使用最新版本
```

### 工作原理

- **只指定 `channel: 'stable'`**：action 会自动下载并使用该通道的**最新版本**
- **自动更新**：每次运行时都会使用最新的稳定版本
- **兼容性**：最新稳定版本通常包含最新的 Dart SDK（支持 3.8.1+）

## 📋 影响范围

已修复所有三个平台：
- ✅ **macOS** (amd64 和 arm64)
- ✅ **Windows**
- ✅ **Linux**

## 💡 其他选项

### 选项 1：仅指定通道（推荐）

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: 'stable'  # 自动使用最新稳定版本
```

**优点：**
- 自动使用最新版本
- 包含最新的 Dart SDK
- 无需手动更新版本号

### 选项 2：指定具体版本号

如果需要固定版本（确保可复现性）：

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.29.2'  # 具体的版本号
    channel: 'stable'
```

**注意**：确保指定的版本支持 Dart SDK 3.8.1+。

### 选项 3：使用 latest 标签

```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: 'latest'  # 使用最新的可用版本
    channel: 'stable'
```

## 🔧 验证修复

重新运行工作流后，应该看到：

```
✓ Setting up Flutter stable channel...
✓ Flutter version: 3.x.x
✓ Dart SDK version: 3.8.1+ (满足要求)
✓ Resolving dependencies... [成功]
```

## 📝 注意事项

1. **缓存影响**：
   - 更改配置后，缓存可能会失效
   - GitHub Actions 会自动重新下载 Flutter SDK

2. **版本兼容性**：
   - 确保 `nursor-flutter-app` 项目也使用兼容的 Flutter/Dart 版本
   - 检查 `pubspec.yaml` 中的 `environment.sdk` 约束

3. **如果需要固定版本**：
   - 可以使用具体的版本号（如 `'3.29.2'`）
   - 但需要定期检查并更新，以确保支持最新的 Dart SDK

## 🎯 预期结果

修复后，所有平台都应该能够：
- ✅ 成功安装 Flutter SDK
- ✅ 成功解析依赖（`flutter pub get`）
- ✅ 成功构建 Flutter 应用
- ✅ 创建安装包

## 🔍 如果仍有问题

1. **检查日志**：查看完整的错误信息
2. **清除缓存**：在 Actions 设置中清除 Flutter 缓存
3. **检查架构**：确保架构参数正确（macOS 使用 `x64` 或 `arm64`）

