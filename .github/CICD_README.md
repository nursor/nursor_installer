# GitHub Actions CI/CD 配置指南

本指南说明如何配置多仓库联动的自动构建流程。

## 📋 概述

这个CI/CD系统支持当以下任一仓库创建tag时，自动触发所有平台的安装包构建：
- **nursor_install** (打包仓库) - https://github.com/nursor/nursor_install
- **nursor-flutter-app** (Flutter应用) - https://github.com/nursor/nursor-flutter-app
- **nursor-core2** (Go核心服务) - https://github.com/nursor/nursor-core2

## 🏗️ 架构说明

### 方案1：Repository Dispatch（推荐）

这是GitHub Actions原生支持的跨仓库触发方案。

#### 工作原理：
1. 在`nursor-flutter-app`和`nursor-core2`仓库中，当创建tag时触发workflow
2. 这些workflow使用`repository_dispatch`事件触发`nursor_install`仓库的构建
3. `nursor_install`仓库的workflow监听`repository_dispatch`事件并执行构建

#### 优点：
- ✅ GitHub原生支持
- ✅ 无需额外配置
- ✅ 可以传递版本信息
- ✅ 支持手动触发

#### 缺点：
- ⚠️ 需要配置Personal Access Token (PAT)

### 方案2：Webhook + GitHub API

使用Webhook在tag创建时调用GitHub API触发构建。

#### 优点：
- ✅ 更灵活的控制
- ✅ 可以添加自定义逻辑

#### 缺点：
- ⚠️ 需要外部服务器
- ⚠️ 配置更复杂

## 🔧 配置步骤

### 步骤1：创建Personal Access Token

1. 前往 GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. 生成新token，授予以下权限：
   - `repo` (完整仓库访问)
   - `workflow` (工作流访问)

### 步骤2：在nursor_install仓库配置Secret

1. 前往 `nursor_install` 仓库的 Settings → Secrets and variables → Actions
2. 添加名为 `PACKAGING_REPO_TOKEN` 的secret，值为步骤1创建的PAT

### 步骤3：在nursor-flutter-app仓库配置Secret

1. 在 `nursor-flutter-app` 仓库中添加同样的secret：`PACKAGING_REPO_TOKEN`
2. 将 `example-trigger-flutter.yml` 文件复制到 `.github/workflows/` 目录

### 步骤4：在nursor-core2仓库配置Secret

1. 在 `nursor-core2` 仓库中添加同样的secret：`PACKAGING_REPO_TOKEN`
2. 将 `example-trigger-core.yml` 文件复制到 `.github/workflows/` 目录

### 步骤5：在主仓库配置工作流

`build-all-platforms.yml` 已经配置好了，它会：
- 监听当前仓库的tag事件
- 监听其他仓库的`repository_dispatch`事件
- 支持手动触发

## 🚀 使用方法

### 方法1：在当前仓库打tag

```bash
git tag v1.0.0
git push origin v1.0.0
```

### 方法2：在Flutter仓库打tag

```bash
cd nursor-flutter-app
git tag v1.0.0
git push origin v1.0.0
```

会自动触发打包仓库的构建。

### 方法3：在Core仓库打tag

```bash
cd nursor-core2
git tag v1.0.0
git push origin v1.0.0
```

会自动触发打包仓库的构建。

### 方法4：手动触发

1. 前往GitHub Actions页面
2. 选择"Build All Platforms"工作流
3. 点击"Run workflow"
4. 输入版本号和可选的refs

## 📦 构建输出

构建完成后，安装包会：
1. 作为Artifact上传（保留30天）
2. 如果是tag触发的构建，会自动创建GitHub Release并上传文件

### macOS
- `NursorInstaller-amd64.pkg`
- `NursorInstaller-arm64.pkg`

### Windows
- `NursorInstaller.exe`

### Linux
- `nursor-linux-amd64-{version}.tar.gz`
- `nursor-linux-arm64-{version}.tar.gz`

## 🔍 故障排除

### 问题1：Repository dispatch未触发

**检查清单：**
- ✅ PAT是否正确配置
- ✅ PAT是否有`repo`和`workflow`权限
- ✅ 触发仓库的workflow是否成功运行
- ✅ 目标仓库名称是否正确

### 问题2：下载nursor-core失败

**可能原因：**
- Core仓库的Release未创建
- Release中的文件名称不匹配
- 网络问题

**解决方案：**
- 确保Core仓库的Release已创建
- 检查文件名称格式：`core-darwin-amd64`, `core-darwin-arm64`, `core-windows-amd64`, `core-linux-amd64`, `core-linux-arm64`

### 问题3：Flutter应用下载失败

**可能原因：**
- Tag不存在
- 仓库访问权限问题

**解决方案：**
- 使用commit SHA代替tag
- 检查仓库访问权限

## 📝 环境变量配置

在主工作流文件中，你可以修改以下环境变量：

```yaml
env:
  CORE_REPO: nursor/nursor-core2      # Core仓库名称 - https://github.com/nursor/nursor-core2
  FLUTTER_REPO: nursor/nursor-flutter-app  # Flutter仓库名称 - https://github.com/nursor/nursor-flutter-app
```

**当前配置的仓库地址：**
- Core仓库：`nursor/nursor-core2` → https://github.com/nursor/nursor-core2
- Flutter仓库：`nursor/nursor-flutter-app` → https://github.com/nursor/nursor-flutter-app
- 打包仓库：`nursor/nursor_install` → 当前仓库

## 🔐 安全建议

1. **PAT权限最小化**：只授予必要的权限
2. **使用Fine-grained tokens**（如果可用）：更细粒度的权限控制
3. **定期轮换PAT**：定期更新token
4. **限制仓库访问**：只允许访问必要的仓库

## 🎯 最佳实践

1. **版本号规范**：使用语义化版本号，如`v1.0.0`
2. **Tag命名**：所有仓库使用相同的tag名称
3. **构建顺序**：建议先构建Core，再构建Flutter，最后构建安装包
4. **测试**：在创建Release之前，先在测试分支测试构建流程

## 📚 相关文档

- [GitHub Actions文档](https://docs.github.com/en/actions)
- [Repository Dispatch事件](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#repository_dispatch)
- [Personal Access Tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)

