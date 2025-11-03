# 修复 Flutter 版本兼容性问题

## 🔴 错误信息

```
The current Dart SDK version is 3.6.0.

Because nursor_app depends on nursorcore from path which requires SDK version ^3.8.1, version solving failed.

You can try the following suggestion:
* Try using the Flutter SDK version: 3.35.7.
Failed to update packages.
Error: Process completed with exit code 1.
```

## 🔍 问题原因

- **当前使用的 Flutter 版本**：`3.27.0`（对应 Dart SDK 3.6.0）
- **依赖要求**：`nursorcore` 包需要 Dart SDK `^3.8.1`
- **版本不兼容**：Flutter 3.27.0 的 Dart SDK 版本低于依赖要求

## ✅ 已应用的修复

### 更新 Flutter 版本配置

将所有平台的 Flutter 版本从固定的 `3.27.0` 更新为 `stable`：

**修复前：**
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: '3.27.0'  # 最新stable版本
```

**修复后：**
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    flutter-version: 'stable'  # 使用最新稳定版本（支持 Dart 3.8.1+）
```

### 影响范围

已更新以下三个平台的 Flutter 配置：
- ✅ **macOS** (amd64 和 arm64)
- ✅ **Windows**
- ✅ **Linux**

## 💡 为什么使用 `stable` 而不是固定版本？

1. **自动更新**：`stable` 会自动使用最新的稳定版本，包含最新的 Dart SDK
2. **兼容性**：最新稳定版本通常支持最新的 Dart SDK（包括 3.8.1+）
3. **维护简单**：无需频繁手动更新 Flutter 版本号
4. **稳定性**：稳定通道经过充分测试，适合生产环境

## 📋 验证修复

重新运行工作流后，应该看到：

```
✓ Flutter version installed: 3.x.x (或更高)
✓ Dart SDK version: 3.8.1 (或更高)
✓ Resolving dependencies... [成功]
✓ Building Flutter app...
```

## 🔧 如果需要固定版本

如果将来需要固定特定的 Flutter 版本，请确保该版本支持 Dart SDK 3.8.1+。

可以使用以下命令查找支持 Dart 3.8.1 的 Flutter 版本：

```bash
# 列出所有 Flutter 版本及其 Dart SDK 版本
flutter --version

# 或查看 Flutter 版本历史
# https://docs.flutter.dev/release/archive
```

## 📝 注意事项

1. **缓存影响**：更改 Flutter 版本后，可能需要清除缓存
   - GitHub Actions 会自动处理缓存失效
   - 本地开发时，运行 `flutter clean` 和 `flutter pub get`

2. **版本兼容性**：
   - 确保 `nursor-flutter-app` 项目也使用兼容的 Flutter 版本
   - 检查 `pubspec.yaml` 中的 `environment.sdk` 约束

3. **回滚选项**：
   - 如果 `stable` 版本有问题，可以指定一个已知稳定的版本
   - 例如：`flutter-version: '3.24.0'`（如果该版本支持 Dart 3.8.1）

## 🎯 预期结果

修复后，所有平台都应该能够：
- ✅ 成功解析依赖（`flutter pub get`）
- ✅ 成功构建 Flutter 应用
- ✅ 创建安装包

如果仍有问题，请检查：
- Flutter 版本是否正确安装
- Dart SDK 版本是否满足要求（3.8.1+）
- 依赖项版本是否兼容

