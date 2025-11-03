# 修复 Repository Dispatch Token 错误

## 🔴 错误信息

```
Error: Parameter token or opts.auth is required
```

## ✅ 解决方案

`peter-evans/repository-dispatch@v3` action 需要 `token` 参数。请确保在 `with` 部分包含 `token`。

### 正确的配置

```yaml
- name: Trigger packaging repository build
  uses: peter-evans/repository-dispatch@v3
  with:
    token: ${{ secrets.PACKAGING_REPO_TOKEN }}  # ← 必须有这一行！
    repository: nursor/nursor_install
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

### ❌ 错误的配置（缺少 token）

```yaml
- name: Trigger packaging repository build
  uses: peter-evans/repository-dispatch@v3
  with:
    # token: ${{ secrets.PACKAGING_REPO_TOKEN }}  ← 缺少这一行！
    repository: nursor/nursor_install
    event-type: build-trigger
    client-payload: {
      ...
    }
```

## 📋 检查清单

1. **确认 token 参数存在**
   - 在 `with` 部分必须有 `token: ${{ secrets.PACKAGING_REPO_TOKEN }}`
   - token 必须在 `repository` 之前或之后（顺序不重要）

2. **确认 Secret 已配置**
   - 前往仓库 Settings → Secrets and variables → Actions
   - 确认 `PACKAGING_REPO_TOKEN` secret 存在
   - 如果不是，请参考 `.github/SETUP_GUIDE.md` 配置

3. **确认 Token 权限**
   - Token 必须有 `repo` 权限
   - Token 必须有 `workflow` 权限（如适用）
   - 如果仓库是私有的，token 必须有访问权限

## 🔧 完整示例

### 对于 nursor-flutter-app 仓库

文件：`.github/workflows/trigger-packaging.yml`

```yaml
name: Trigger Packaging Build

on:
  push:
    tags:
      - 'v*'

jobs:
  trigger-packaging:
    runs-on: ubuntu-latest
    steps:
      - name: Get tag name
        id: get_tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
      
      - name: Trigger packaging repository build
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.PACKAGING_REPO_TOKEN }}
          repository: nursor/nursor_install
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

### 对于 nursor-core2 仓库

文件：`.github/workflows/trigger-packaging.yml`

```yaml
name: Trigger Packaging Build

on:
  push:
    tags:
      - 'v*'

jobs:
  trigger-packaging:
    runs-on: ubuntu-latest
    steps:
      - name: Get tag name
        id: get_tag
        run: echo "tag=${GITHUB_REF#refs/tags/}" >> $GITHUB_OUTPUT
      
      - name: Trigger packaging repository build
        uses: peter-evans/repository-dispatch@v3
        with:
          token: ${{ secrets.PACKAGING_REPO_TOKEN }}
          repository: nursor/nursor_install
          event-type: build-trigger
          client-payload: |
            {
              "version": "${{ steps.get_tag.outputs.tag }}",
              "flutter_ref": "${{ steps.get_tag.outputs.tag }}",
              "core_ref": "${{ steps.get_tag.outputs.tag }}",
              "triggered_by": "nursor-core2",
              "triggered_repo": "${{ github.repository }}"
            }
```

## ⚠️ 常见错误

### 错误1：Token secret 未配置

**错误信息：**
```
Error: Resource not accessible by integration
```

**解决方案：**
- 在仓库中添加 `PACKAGING_REPO_TOKEN` secret
- 参考 `.github/SETUP_GUIDE.md` 第1-2步

### 错误2：Token 权限不足

**错误信息：**
```
Error: Bad credentials
```

**解决方案：**
- 检查 token 是否有 `repo` 权限
- 如果仓库是私有的，确认 token 有访问权限
- 重新创建 token 并确保权限正确

### 错误3：仓库名称错误

**错误信息：**
```
Error: Not Found
```

**解决方案：**
- 检查 `repository` 参数中的仓库名称是否正确
- 格式：`owner/repo-name`
- 确认目标仓库存在且可访问

## 📝 注意事项

1. **Token 安全性**
   - 不要将 token 提交到代码仓库
   - 始终使用 `secrets` 引用 token
   - 定期轮换 token（建议每90天）

2. **仓库访问**
   - 如果目标仓库是私有的，token 必须有访问权限
   - 如果使用组织仓库，确认 token 有组织级别的权限

3. **测试**
   - 在目标仓库创建测试 tag 进行验证
   - 检查目标仓库的 Actions 页面确认事件已触发

## 🔗 相关文档

- `.github/SETUP_GUIDE.md` - 快速设置指南
- `.github/CICD_README.md` - 详细配置文档
- `.github/TROUBLESHOOTING.md` - 故障排除指南

