# 仓库配置信息

本文档列出了CI/CD系统中使用的所有仓库及其配置信息。

## 📦 仓库列表

### 1. 打包仓库 (nursor_install)

**仓库地址：** https://github.com/nursor/nursor_install

**作用：** 包含所有平台的构建脚本和安装包生成逻辑

**工作流文件：**
- `.github/workflows/build-all-platforms.yml` - 主构建工作流

**必需文件：**
- `macos/build_installer.sh` - macOS安装包构建脚本
- `nursor_win_installer.iss` - Windows安装包构建脚本（Inno Setup）
- `macos/org.nursor.nursor-core.plist` - macOS LaunchDaemon配置
- `macos/org.nursor.trustca.plist` - macOS证书信任配置
- `macos/trust_ca_once.sh` - 证书信任脚本
- `macos/scripts/preinstall` - macOS安装前脚本
- `macos/scripts/postinstall` - macOS安装后脚本
- `macos/scripts/send_to_sentry.sh` - Sentry集成脚本
- `macos/ca.pem` - CA证书文件（如需要）

### 2. Flutter应用仓库 (nursor-flutter-app)

**仓库地址：** https://github.com/nursor/nursor-flutter-app

**作用：** 包含Flutter应用源代码

**工作流文件（需要添加）：**
- `.github/workflows/trigger-packaging.yml` - 从 `example-trigger-flutter.yml` 复制

**构建输出：**
- macOS: `build/macos/Build/Products/Release/Nursor.app`
- Windows: `build/windows/x64/runner/Release/`
- Linux: `build/linux/x64/release/bundle/`

### 3. Core服务仓库 (nursor-core2)

**仓库地址：** https://github.com/nursor/nursor-core2

**作用：** 包含Go编写的核心服务二进制文件

**工作流文件（需要添加）：**
- `.github/workflows/trigger-packaging.yml` - 从 `example-trigger-core.yml` 复制

**Release要求：**
每次Release必须包含以下文件（文件名区分大小写）：

```
v{version}/
├── core-darwin-amd64      # macOS Intel (x86_64)
├── core-darwin-arm64      # macOS Apple Silicon (ARM64)
├── core-windows-amd64     # Windows x64
├── core-linux-amd64       # Linux x86_64
└── core-linux-arm64       # Linux ARM64
```

**下载URL格式：**
```
https://github.com/nursor/nursor-core2/releases/download/v{version}/core-darwin-{arch}
```

示例：
- https://github.com/nursor/nursor-core2/releases/download/v1.0.0/core-darwin-arm64
- https://github.com/nursor/nursor-core2/releases/download/v1.0.0/core-darwin-amd64

## 🔗 仓库关系图

```
nursor-core2 (创建tag v1.0.0)
    ↓
    ├─→ 触发 nursor_install 构建
    └─→ 提供 core-darwin-{arch} 二进制文件

nursor-flutter-app (创建tag v1.0.0)
    ↓
    ├─→ 触发 nursor_install 构建
    └─→ 提供 Nursor.app 应用

nursor_install (创建tag v1.0.0)
    ↓
    └─→ 直接触发构建
        ├─→ 下载 nursor-core 二进制文件
        ├─→ 下载 nursor-flutter-app 源代码
        └─→ 构建所有平台的安装包
```

## 🔐 Secret配置

所有三个仓库都需要配置以下Secret：

**Secret名称：** `PACKAGING_REPO_TOKEN`

**值：** Personal Access Token (PAT)，需要以下权限：
- `repo` (完整仓库访问)
- `workflow` (工作流访问)

**配置位置：**
- Settings → Secrets and variables → Actions → New repository secret

## 📝 配置检查清单

在开始使用CI/CD之前，请确认：

### nursor-core2仓库
- [ ] 已创建Personal Access Token
- [ ] 已配置 `PACKAGING_REPO_TOKEN` secret
- [ ] 已将 `example-trigger-core.yml` 复制到 `.github/workflows/trigger-packaging.yml`
- [ ] Release中包含所有必需的二进制文件
- [ ] 二进制文件命名符合要求

### nursor-flutter-app仓库
- [ ] 已配置 `PACKAGING_REPO_TOKEN` secret
- [ ] 已将 `example-trigger-flutter.yml` 复制到 `.github/workflows/trigger-packaging.yml`
- [ ] Flutter项目可以成功构建

### nursor_install仓库
- [ ] 已配置 `PACKAGING_REPO_TOKEN` secret
- [ ] 包含所有必需的构建文件
- [ ] `build-all-platforms.yml` 工作流文件存在
- [ ] macOS目录包含所有必需的配置文件
- [ ] `ca.pem` 文件存在（如需要）

## 🚀 测试流程

1. **在nursor-core2创建tag**
   ```bash
   cd nursor-core2
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```
   检查：`nursor_install` 仓库的Actions页面应该出现新的构建任务

2. **在nursor-flutter-app创建tag**
   ```bash
   cd nursor-flutter-app
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```
   检查：`nursor_install` 仓库的Actions页面应该出现新的构建任务

3. **在nursor_install创建tag**
   ```bash
   cd nursor_install
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```
   检查：当前仓库的Actions页面应该出现新的构建任务

## 📞 支持

如有问题，请查看：
- `.github/CICD_README.md` - 详细配置文档
- `.github/SETUP_GUIDE.md` - 快速设置指南
- `.github/README.md` - 总结文档

