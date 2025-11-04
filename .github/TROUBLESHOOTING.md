# 故障排除指南

本文档帮助解决CI/CD工作流中常见的错误和问题。

## 🔴 常见错误

### 错误：Parameter token or opts.auth is required

**问题描述：**
```
Error: Parameter token or opts.auth is required
```

**原因：**
`softprops/action-gh-release` action 需要 token 参数，但未正确配置。

**解决方案：**
在 `action-gh-release` 的 `with` 部分添加 `token` 参数：

```yaml
- name: Create GitHub Release
  uses: softprops/action-gh-release@v1
  with:
    token: ${{ secrets.GITHUB_TOKEN }}  # 必须添加这一行
    files: output/*.pkg
    tag_name: v1.0.0
```

**注意：**
- 不能使用 `env` 来设置 `GITHUB_TOKEN`
- 必须在 `with` 中使用 `token` 参数
- `secrets.GITHUB_TOKEN` 是 GitHub 自动提供的，无需额外配置

**已修复版本：**
工作流文件已更新，所有 `action-gh-release` 步骤都已正确配置 `token` 参数。

---

### 错误：Repository dispatch 未触发

**问题描述：**
其他仓库创建 tag 后，主仓库的构建未触发。

**可能原因：**
1. `PACKAGING_REPO_TOKEN` secret 未配置
2. Token 权限不足
3. 仓库名称不正确

**解决方案：**

1. **检查 Secret 配置**
   - 前往仓库 Settings → Secrets and variables → Actions
   - 确认 `PACKAGING_REPO_TOKEN` 存在

2. **检查 Token 权限**
   - Token 需要 `repo` 和 `workflow` 权限
   - 如果仓库是私有的，token 必须有访问权限

3. **检查仓库名称**
   - 确认 `example-trigger-*.yml` 中的 `repository` 字段正确
   - 格式：`owner/repo-name`

4. **检查工作流文件**
   - 确认已复制到 `.github/workflows/` 目录
   - 确认文件名正确（不是 `.example` 后缀）

---

### 错误：SHA256 checksum verification failed

**问题描述：**
```
ERROR: SHA256 checksum verification failed
```

**原因：**
下载的二进制文件的 SHA256 hash 与 checksum 文件不匹配。

**解决方案：**

1. **检查 checksum 文件格式**
   - 文件应包含 SHA256 hash（32字符十六进制）
   - 格式：`{hash}` 或 `{hash}  {filename}`

2. **验证 Release 文件**
   - 确认 Release 中的二进制文件和 checksum 文件匹配
   - 重新计算并上传 checksum 文件

3. **临时禁用验证**
   - 如果 Release 中没有 checksum 文件，会显示警告但继续构建
   - 不需要禁用，会自动跳过验证

---

### 错误：Flutter build failed

**问题描述：**
Flutter 构建失败。

**可能原因：**
1. Flutter 版本不兼容
2. 依赖问题
3. 平台特定问题

**解决方案：**

1. **检查 Flutter 版本**
   - 当前配置：Flutter 3.27.0
   - 如需更改，修改 `flutter-version` 参数

2. **检查依赖**
   - 确认 `pubspec.yaml` 中的依赖有效
   - 检查是否有平台特定的依赖问题

3. **检查构建日志**
   - 查看详细的错误信息
   - 确认是否缺少平台特定的依赖

4. **清理缓存**
   - 删除 `.dart_tool` 和 `build` 目录
   - 重新运行 `flutter pub get`

---

### 错误：nursor-core download failed

**问题描述：**
无法从 Release 下载 nursor-core 二进制文件。

**可能原因：**
1. Release 不存在
2. 文件名称不匹配
3. 网络问题

**解决方案：**

1. **检查 Release**
   - 确认 `nursor-core2` 仓库中有对应版本的 Release
   - 确认 Release 中包含所有必需的二进制文件

2. **检查文件名称**
   - 必须完全匹配（区分大小写）
   - 格式：`core-{platform}-{arch}`

3. **检查 URL**
   - 确认 URL 格式正确
   - 格式：`https://github.com/nursor/nursor-core2/releases/download/{version}/core-{platform}-{arch}`

4. **检查 Tag**
   - 确认 tag 名称正确
   - 如果使用 commit SHA，确保 Release 使用相同的标识

---

### 错误：Required files not found (macOS)

**问题描述：**
```
ERROR: 以下必需文件未找到:
  - nursor-core
  - Nursor.app
  ...
```

**原因：**
构建步骤中缺少必需的文件。

**解决方案：**

1. **检查 Flutter 构建输出**
   - 确认 `Nursor.app` 已正确构建
   - 路径：`flutter_app/build/macos/Build/Products/Release/Nursor.app`

2. **检查 nursor-core 下载**
   - 确认下载步骤成功执行
   - 检查文件是否存在于 `macos/` 目录

3. **检查配置文件**
   - 确认所有 plist 和脚本文件存在于 `macos/` 目录
   - 确认文件权限正确

---

### 错误：Permission denied (macOS)

**问题描述：**
构建脚本需要 root 权限。

**解决方案：**

1. **CI 环境**
   - GitHub Actions 的 macOS runner 支持 `sudo`
   - 工作流中已使用 `sudo ./build_installer.sh`

2. **本地环境**
   - 使用 `sudo ./build_installer.sh` 运行
   - 确认用户有管理员权限

---

## 📋 检查清单

在报告问题之前，请确认：

- [ ] Secret `PACKAGING_REPO_TOKEN` 已配置（如需要）
- [ ] Secret `GITHUB_TOKEN` 可用（GitHub 自动提供）
- [ ] 工作流文件语法正确（已通过 linter 检查）
- [ ] Release 中包含所有必需的文件
- [ ] Tag 名称格式正确（`v*` 格式）
- [ ] 仓库名称和路径正确
- [ ] Flutter 项目可以本地构建成功

---

## 🆘 获取帮助

如果以上解决方案都无法解决问题：

1. **查看详细日志**
   - 前往 Actions 页面
   - 点击失败的 workflow
   - 展开失败的 step 查看详细错误信息

2. **检查工作流语法**
   - 使用 GitHub Actions 语法检查工具
   - 确认 YAML 格式正确

3. **参考文档**
   - `.github/CICD_README.md` - 详细配置文档
   - `.github/SETUP_GUIDE.md` - 快速设置指南
   - `.github/IMPROVEMENTS.md` - 改进说明

4. **常见问题**
   - 检查 GitHub Actions 状态页面
   - 查看是否有已知的服务中断

---

## 💡 提示

- 使用 `workflow_dispatch` 手动触发测试
- 先测试单个平台构建，再测试全部平台
- 检查构建日志中的警告信息
- 确认所有依赖的版本兼容性

