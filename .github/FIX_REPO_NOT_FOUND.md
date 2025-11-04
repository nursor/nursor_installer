# 修复 "Repository not found, OR token has insufficient permissions" 错误

## 🔴 错误信息

```
Error: Repository not found, OR token has insufficient permissions
```

## 🔍 问题诊断

这个错误通常由以下几个原因引起：

### 1. 仓库名称错误

**检查：** 确认仓库名称是否正确
- ✅ 正确：`nursor/nursor_install`
- ❌ 错误：`nursor/nursor_installer` (多了 "er")

**解决方案：**
在 `trigger-packaging.yml` 文件中确认：
```yaml
repository: nursor/nursor_install  # 注意是 install，不是 installer
```

### 2. Token 权限不足

**检查：** Token 必须有以下权限
- ✅ `repo` (完整仓库访问) - **必需**
- ✅ `workflow` (工作流访问) - 可选但推荐

**解决方案：**

1. **检查当前 Token 权限**
   - 前往：https://github.com/settings/tokens
   - 找到你的 token，查看权限列表
   - 确认 `repo` 权限已勾选

2. **如果权限不足，重新创建 Token**
   ```bash
   1. 前往 https://github.com/settings/tokens
   2. 点击 "Generate new token" → "Generate new token (classic)"
   3. 输入名称：nursor-ci-token
   4. 选择过期时间（建议90天或更长）
   5. 勾选权限：
      - ✅ repo (完整仓库访问)
      - ✅ workflow (工作流访问)
   6. 点击 "Generate token"
   7. 复制 token（只显示一次）
   8. 更新仓库 Secret
   ```

### 3. 仓库访问权限

**问题：** 如果目标仓库是私有的，token 必须有访问权限

**检查步骤：**
1. 确认目标仓库 `nursor/nursor_install` 是否存在
2. 确认仓库是否为私有
3. 如果是私有仓库，确认 token 创建者是否有访问权限

**解决方案：**
- 如果仓库是私有的，确保 token 创建者有该仓库的访问权限
- 如果是组织仓库，可能需要组织级别的权限

### 4. Secret 未正确配置

**检查：** Secret 名称和值是否正确

**解决方案：**
1. 前往触发仓库（`nursor-flutter-app` 或 `nursor-core2`）
2. Settings → Secrets and variables → Actions
3. 确认存在 `PACKAGING_REPO_TOKEN` secret
4. 如果不存在或值错误，更新或创建它

## ✅ 完整修复步骤

### 步骤 1：验证仓库名称

在 `nursor-flutter-app` 或 `nursor-core2` 仓库的 `.github/workflows/trigger-packaging.yml` 文件中：

```yaml
- name: Trigger packaging repository build
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.PACKAGING_REPO_TOKEN }}
    repository: nursor/nursor_install  # ← 确认是 install，不是 installer
    event-type: build-trigger
    client-payload: |
      {
        "version": "${{ steps.get_tag.outputs.tag }}",
        "flutter_ref": "${{ steps.get_tag.outputs.tag }}",
        "core_ref": "${{ steps.get_tag.outputs.tag }}",
        "triggered_by": "nursor-flutter-app",
        "triggered_repo": "${{ github.repository }}"
      }
```

### 步骤 2：创建或更新 Token

1. **创建新 Token**
   - 访问：https://github.com/settings/tokens
   - 点击 "Generate new token (classic)"
   - 名称：`nursor-ci-token`
   - 权限：勾选 `repo` (全部) 和 `workflow`
   - 生成并复制 token

2. **更新 Secret**
   - 前往触发仓库的 Settings → Secrets and variables → Actions
   - 找到或创建 `PACKAGING_REPO_TOKEN`
   - 更新值为新创建的 token

### 步骤 3：验证仓库存在

1. 在浏览器中访问：https://github.com/nursor/nursor_install
2. 确认仓库存在且可以访问
3. 如果仓库不存在，需要先创建它

### 步骤 4：测试

1. 在触发仓库创建一个测试 tag：
   ```bash
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```

2. 检查 Actions 页面：
   - 触发仓库的 Actions 页面（应该看到 "Trigger Packaging Build" 工作流运行）
   - `nursor/nursor_install` 仓库的 Actions 页面（应该看到 "Build All Platforms" 工作流运行）

## 📋 检查清单

在报告问题之前，请确认：

- [ ] 仓库名称正确：`nursor/nursor_install`（不是 `installer`）
- [ ] Token 有 `repo` 权限
- [ ] Token 有 `workflow` 权限（推荐）
- [ ] Secret `PACKAGING_REPO_TOKEN` 已配置
- [ ] Secret 值是正确的 token
- [ ] 目标仓库 `nursor/nursor_install` 存在
- [ ] 如果仓库是私有的，token 有访问权限
- [ ] 工作流文件 `.github/workflows/trigger-packaging.yml` 存在
- [ ] 工作流文件中 `repository` 参数正确

## 🔧 常见问题

### Q1: 如何确认仓库名称？

**A:** 
- 在浏览器中打开 GitHub 仓库
- URL 格式：`https://github.com/{owner}/{repo}`
- 例如：`https://github.com/nursor/nursor_install`
- 仓库名称就是 `nursor/nursor_install`

### Q2: Token 权限需要哪些？

**A:**
- **必需：** `repo` (完整仓库访问)
- **推荐：** `workflow` (工作流访问)
- 其他权限不需要

### Q3: 如何测试 Token 是否有效？

**A:**
可以使用 GitHub CLI 测试：
```bash
# 使用 token 访问仓库信息
gh api repos/nursor/nursor_install --token YOUR_TOKEN

# 如果返回仓库信息，说明 token 有效
```

### Q4: 如果仓库是组织仓库怎么办？

**A:**
- 确保 token 创建者有组织成员的权限
- 可能需要在组织设置中授权 token
- 确认组织允许使用 Personal Access Token

## 🆘 如果仍然失败

如果以上步骤都无法解决问题：

1. **查看详细错误日志**
   - 前往 Actions 页面
   - 点击失败的工作流
   - 查看详细的错误信息

2. **尝试手动触发**
   - 在 GitHub 网页中手动运行 workflow_dispatch
   - 查看是否有不同的错误信息

3. **检查 GitHub 状态**
   - 访问：https://www.githubstatus.com/
   - 确认 GitHub Actions 服务正常

4. **联系支持**
   - 如果是组织仓库，联系组织管理员
   - 检查是否有组织级别的限制

## 📚 相关文档

- `.github/SETUP_GUIDE.md` - 快速设置指南
- `.github/FIX_REPOSITORY_DISPATCH.md` - Repository Dispatch 修复指南
- `.github/TROUBLESHOOTING.md` - 故障排除指南

