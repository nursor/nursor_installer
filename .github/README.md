# GitHub Actions CI/CD 配置总结

## 📁 文件说明

### 主工作流文件
- **`build-all-platforms.yml`** - 主工作流文件，监听tag和repository_dispatch事件，构建所有平台的安装包

### 辅助工作流示例文件（需要复制到其他仓库）
- **`example-trigger-flutter.yml`** - 用于`nursor-flutter-app`仓库，当创建tag时触发主工作流
- **`example-trigger-core.yml`** - 用于`nursor-core2`仓库，当创建tag时触发主工作流

### 文档文件
- **`CICD_README.md`** - 详细的CI/CD配置文档，包含架构说明、配置步骤、故障排除等
- **`SETUP_GUIDE.md`** - 快速设置指南，帮助快速配置CI/CD

## 🚀 快速开始

1. **创建Personal Access Token** (PAT)
   - 前往 https://github.com/settings/tokens
   - 创建classic token，授予`repo`和`workflow`权限

2. **配置Secret**
   - 在三个仓库中都添加secret：`PACKAGING_REPO_TOKEN`
   - 值为步骤1创建的PAT

3. **复制工作流文件**
   - 将`example-trigger-flutter.yml`复制到`nursor-flutter-app`仓库的`.github/workflows/`
   - 将`example-trigger-core.yml`复制到`nursor-core2`仓库的`.github/workflows/`

4. **测试**
   - 在任意仓库创建tag（格式：`v*`）
   - 前往`nursor_install`仓库的Actions页面查看构建状态

## 🎯 工作原理

### 触发方式

1. **Tag推送**：在任何仓库中推送tag（格式：`v*`）
   - 当前仓库的tag → 直接触发构建
   - 其他仓库的tag → 通过`repository_dispatch`触发

2. **Repository Dispatch**：其他仓库通过API触发
   - `nursor-flutter-app`创建tag → 触发`nursor_install`构建
   - `nursor-core2`创建tag → 触发`nursor_install`构建

3. **手动触发**：在GitHub Actions页面手动运行

### 构建流程

1. **版本检测**：从tag或输入中获取版本号
2. **下载依赖**：
   - 从`nursor-flutter-app`仓库下载Flutter应用
   - 从`nursor-core2`仓库的Release下载nursor-core二进制文件
3. **构建安装包**：
   - macOS: amd64和arm64两个版本
   - Windows: amd64版本
   - Linux: amd64和arm64两个版本
4. **上传Artifact**：安装包上传到GitHub Artifacts（保留30天）
5. **创建Release**：如果是tag触发的构建，自动创建GitHub Release并上传文件

## 📦 构建输出

### macOS
- `NursorInstaller-amd64.pkg`
- `NursorInstaller-arm64.pkg`

### Windows
- `NursorInstaller.exe`

### Linux
- `nursor-linux-amd64-{version}.tar.gz`
- `nursor-linux-arm64-{version}.tar.gz`

## ⚙️ 配置要求

### nursor-core2仓库的Release要求

Release中必须包含以下文件（文件名区分大小写）：
- `core-darwin-amd64`
- `core-darwin-arm64`
- `core-windows-amd64`
- `core-linux-amd64`
- `core-linux-arm64`

### 环境变量

可以在`build-all-platforms.yml`中修改：
```yaml
env:
  CORE_REPO: nursor/nursor-core2      # 已配置：https://github.com/nursor/nursor-core2
  FLUTTER_REPO: nursor/nursor-flutter-app  # 已配置：https://github.com/nursor/nursor-flutter-app
```

**当前配置的仓库地址：**
- Core仓库：`nursor/nursor-core2` (https://github.com/nursor/nursor-core2)
- Flutter仓库：`nursor/nursor-flutter-app` (https://github.com/nursor/nursor-flutter-app)
- 打包仓库：`nursor/nursor_install` (当前仓库)

### Flutter版本

可以在`build-all-platforms.yml`中修改：
```yaml
flutter-version: '3.24.0'  # 根据你的Flutter版本调整
```

## 🔍 常见问题

### Q: 如何查看构建日志？
A: 前往仓库的Actions页面，点击对应的workflow run，查看详细日志。

### Q: 构建失败怎么办？
A: 查看详细文档：`.github/CICD_README.md`中的"故障排除"部分。

### Q: 如何手动触发构建？
A: 前往Actions页面，选择"Build All Platforms"工作流，点击"Run workflow"。

### Q: 可以修改构建参数吗？
A: 可以，在手动触发时或通过`repository_dispatch`的`client_payload`传递自定义参数。

## 📚 更多信息

- 详细配置文档：`.github/CICD_README.md`
- 快速设置指南：`.github/SETUP_GUIDE.md`

