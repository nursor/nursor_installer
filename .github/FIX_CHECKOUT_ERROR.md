# 修复 checkout 错误

## 🔴 错误信息

```
The process '/opt/homebrew/bin/git' failed with exit code 1
Error: The process '/opt/homebrew/bin/git' failed with exit code 1
```

或

```
Error: fatal: repository 'https://github.com/nursor/nursor-flutter-app/' not found
```

## 🔍 问题原因

1. **Ref 格式问题**：`actions/checkout@v4` 在尝试匹配 tag 时失败
2. **Token 权限不足**：`GITHUB_TOKEN` 可能无法访问目标仓库
3. **Tag 不存在**：指定的 tag 可能不存在于目标仓库

## ✅ 已应用的修复

### 1. 使用正确的 Token

**修复前：**
```yaml
token: ${{ secrets.GITHUB_TOKEN }}
```

**修复后：**
```yaml
token: ${{ secrets.PACKAGING_REPO_TOKEN }}
```

### 2. 添加 fetch-depth 参数

**修复：**
```yaml
- name: Download Flutter App
  uses: actions/checkout@v4
  with:
    repository: ${{ env.FLUTTER_REPO }}
    ref: ${{ needs.detect-version.outputs.flutter_ref }}
    path: flutter_app
    token: ${{ secrets.PACKAGING_REPO_TOKEN }}
    fetch-depth: 0  # 获取所有历史记录，包括所有 tags
```

### 3. 优化 Ref 处理

- 清理 ref 格式（移除 `refs/tags/` 前缀）
- 确保使用完整的 tag 名称
- 添加调试输出

## 📋 检查清单

### 1. 确认 Secret 配置

- [ ] `PACKAGING_REPO_TOKEN` 已配置
- [ ] Token 有 `repo` 权限
- [ ] Token 能访问 `nursor/nursor-flutter-app` 仓库

### 2. 确认 Tag 存在

- [ ] 在 `nursor-flutter-app` 仓库中检查 tag 是否存在
- [ ] Tag 名称格式正确（如 `v1.0.0`）
- [ ] 如果使用 commit SHA，确保 SHA 有效

### 3. 检查 Ref 值

查看工作流日志中的调试输出：
```
Final Flutter ref: v1.0.0
Final Core ref: v1.0.0
```

确认 ref 值是完整的 tag 名称，而不是部分匹配。

## 🔧 进一步排查

### 如果仍然失败

1. **检查仓库访问权限**
   ```bash
   # 在本地测试 token
   curl -H "Authorization: token YOUR_TOKEN" \
        https://api.github.com/repos/nursor/nursor-flutter-app
   ```

2. **检查 Tag 是否存在**
   ```bash
   curl -H "Authorization: token YOUR_TOKEN" \
        https://api.github.com/repos/nursor/nursor-flutter-app/git/refs/tags/v1.0.0
   ```

3. **查看详细错误日志**
   - 前往 Actions 页面
   - 展开 "Download Flutter App" 步骤
   - 查看完整的错误信息

### 如果 Tag 不存在

可以使用 commit SHA 代替 tag：

```yaml
# 在 workflow_dispatch 或 repository_dispatch 中
flutter_tag: "abc123def456..."  # commit SHA
```

## 💡 提示

- `fetch-depth: 0` 会获取所有历史记录，这可能增加下载时间
- 如果只需要特定 tag，可以考虑使用 `fetch-depth: 1` 并指定完整 tag 名称
- 确保 tag 名称完整且正确（区分大小写）

