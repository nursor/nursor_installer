# GitHub Actions CI/CD 快速设置指南

## 🚀 快速开始

### 第一步：创建Personal Access Token

1. 访问：https://github.com/settings/tokens
2. 点击 "Generate new token" → "Generate new token (classic)"
3. 输入名称，例如：`nursor-ci-token`
4. 选择过期时间（建议选择90天或更长）
5. 勾选以下权限：
   - ✅ `repo` (全部)
   - ✅ `workflow`
6. 点击 "Generate token"
7. **重要**：立即复制token，因为之后无法再次查看

### 第二步：在nursor_install仓库配置Secret

1. 打开 `nursor/nursor_install` 仓库
2. 前往 Settings → Secrets and variables → Actions
3. 点击 "New repository secret"
4. Name: `PACKAGING_REPO_TOKEN`
5. Secret: 粘贴第一步创建的token
6. 点击 "Add secret"

### 第三步：在nursor-flutter-app仓库配置

1. 打开 `nursor/nursor-flutter-app` 仓库
2. 复制文件 `.github/workflows/example-trigger-flutter.yml` 到该仓库的 `.github/workflows/trigger-packaging.yml`
3. 在仓库的 Settings → Secrets and variables → Actions 中添加 `PACKAGING_REPO_TOKEN`
4. 如果仓库是私有的，确保token有访问权限

### 第四步：在nursor-core2仓库配置

1. 打开 `nursor/nursor-core2` 仓库
2. 复制文件 `.github/workflows/example-trigger-core.yml` 到该仓库的 `.github/workflows/trigger-packaging.yml`
3. 在仓库的 Settings → Secrets and variables → Actions 中添加 `PACKAGING_REPO_TOKEN`
4. 如果仓库是私有的，确保token有访问权限

### 第五步：测试

#### 测试方法1：在当前仓库打tag

```bash
cd nursor_install
git tag v1.0.0-test
git push origin v1.0.0-test
```

#### 测试方法2：在Flutter仓库打tag

```bash
cd nursor-flutter-app
git tag v1.0.0-test
git push origin v1.0.0-test
```

然后前往 `nursor_install` 仓库的 Actions 页面查看构建状态。

## 📋 仓库结构要求

### nursor-core2仓库的Release要求

当你创建Release时，需要包含以下文件：

```
v1.0.0/
├── core-darwin-amd64
├── core-darwin-arm64
├── core-windows-amd64
├── core-linux-amd64
└── core-linux-arm64
```

这些文件应该是：
- 可执行的二进制文件
- 具有正确的架构（amd64/arm64）
- 文件名必须完全匹配（区分大小写）

### nursor-flutter-app仓库要求

- 必须包含有效的Flutter项目
- 能够成功执行 `flutter build macos/windows/linux --release`
- Tag必须指向有效的commit

### nursor_install仓库要求

- 包含 `macos/build_installer.sh` 脚本
- 包含 `nursor_win_installer.iss` Inno Setup脚本
- 包含必要的配置文件（plist文件等）
- **macOS构建所需的文件**：
  - `macos/org.nursor.nursor-core.plist`
  - `macos/org.nursor.trustca.plist`
  - `macos/trust_ca_once.sh`
  - `macos/scripts/preinstall`
  - `macos/scripts/postinstall`
  - `macos/scripts/send_to_sentry.sh`
  - `macos/ca.pem` (如果构建脚本需要，请确保此文件存在)

## 🔍 常见问题

### Q1: 构建失败，提示"Permission denied"

**A:** 检查：
1. PAT是否正确配置
2. PAT是否有足够权限
3. 仓库是否为私有（如果是，需要token有访问权限）

### Q2: 下载nursor-core失败

**A:** 检查：
1. Core仓库是否创建了Release
2. Release中的文件名称是否正确
3. Tag名称是否匹配

### Q3: Flutter构建失败

**A:** 检查：
1. Flutter版本是否兼容
2. 依赖是否正确安装
3. 构建命令是否成功

### Q4: 如何查看详细的构建日志？

**A:** 前往仓库的 Actions 页面，点击失败的workflow，查看详细日志。

## 🎯 工作流说明

### 触发方式

1. **Tag推送**：在任何配置的仓库中推送tag，格式为 `v*`
2. **Repository Dispatch**：其他仓库通过API触发
3. **手动触发**：在GitHub Actions页面手动运行

### 构建矩阵

- **macOS**: amd64, arm64
- **Windows**: amd64
- **Linux**: amd64, arm64

总共会生成 **5个安装包**。

### 版本号传递

工作流会自动从以下来源获取版本号：
1. Tag名称（如果是tag触发）
2. `repository_dispatch`的`client_payload`
3. 手动输入的版本号（手动触发时）

## 📝 配置检查清单

在开始使用之前，请确认：

- [ ] 已创建Personal Access Token
- [ ] 已在所有三个仓库中配置 `PACKAGING_REPO_TOKEN`
- [ ] 已在 `nursor-flutter-app` 仓库添加 `trigger-packaging.yml`
- [ ] 已在 `nursor-core2` 仓库添加 `trigger-packaging.yml`
- [ ] `nursor-core2` 仓库的Release包含所有必需的二进制文件
- [ ] 所有仓库的tag命名遵循 `v*` 格式

## 🚨 重要提示

1. **Token安全**：不要将token提交到代码仓库
2. **版本一致性**：建议所有仓库使用相同的tag名称
3. **构建时间**：完整构建可能需要15-30分钟
4. **成本**：GitHub Actions对私有仓库有限制，请注意使用量

