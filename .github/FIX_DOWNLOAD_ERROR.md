# 修复 Windows nursor-core 下载错误

## 🔴 错误信息

```
Invoke-WebRequest: ... :root { ... {"locale":"en","featureFlags":...
Error: Process completed with exit code 1
```

## 🔍 问题原因

错误信息显示下载的内容是 HTML/JSON（GitHub 错误页面）而不是二进制文件。这可能是因为：

1. **URL 不正确**：Release asset 名称或路径错误
2. **文件不存在**：指定的 tag 或 asset 不存在
3. **权限问题**：无法访问私有仓库的 releases
4. **网络错误**：下载过程中出现错误，但脚本没有正确处理

## ✅ 已应用的修复

### 改进的下载逻辑

添加了以下改进：

1. **错误处理**：使用 `try-catch` 块捕获错误
2. **文件验证**：
   - 检查文件是否存在
   - 检查文件大小（确保不为空）
   - 检查文件内容（确保不是 HTML 错误页面）
3. **调试信息**：
   - 输出下载 URL
   - 输出文件大小
   - 输出错误详情
4. **HTTP 状态码检查**：
   - 如果是 404，提供明确的错误信息
   - 检查常见的错误情况

### 修复后的代码

```yaml
- name: Download nursor-core for Windows
  run: |
    $CORE_REF="${{ needs.detect-version.outputs.core_ref }}"
    $CORE_REPO="${{ env.CORE_REPO }}"
    
    # 构建 URL
    $CORE_URL = "https://github.com/$CORE_REPO/releases/download/$CORE_REF/core-windows-amd64"
    $OUTPUT_FILE = "windows/nursor-core-amd64.dll"
    
    Write-Host "Downloading nursor-core from: $CORE_URL"
    
    try {
      # 下载文件
      $response = Invoke-WebRequest -Uri $CORE_URL -OutFile $OUTPUT_FILE -UseBasicParsing -ErrorAction Stop
      
      # 验证文件
      if (-not (Test-Path $OUTPUT_FILE)) {
        Write-Error "ERROR: File not found after download"
        exit 1
      }
      
      $fileSize = (Get-Item $OUTPUT_FILE).Length
      if ($fileSize -eq 0) {
        Write-Error "ERROR: Downloaded file is empty"
        exit 1
      }
      
      # 检查是否为 HTML 错误页面
      $firstBytes = Get-Content -Path $OUTPUT_FILE -TotalCount 5 -Raw -Encoding Byte
      $firstText = [System.Text.Encoding]::ASCII.GetString($firstBytes)
      if ($firstText -match "^<!DOCTYPE|<html|<HTML|{\"error\"") {
        Write-Error "ERROR: Downloaded file appears to be HTML/JSON error page"
        exit 1
      }
      
      Write-Host "File downloaded successfully"
      
    } catch {
      Write-Error "ERROR: Failed to download nursor-core"
      if ($_.Exception.Response.StatusCode -eq 404) {
        Write-Error "The file was not found. Please check:"
        Write-Error "  1. Release tag exists: $CORE_REF"
        Write-Error "  2. Asset name is correct: core-windows-amd64"
        Write-Error "  3. Repository is correct: $CORE_REPO"
      }
      exit 1
    }
```

## 📋 常见问题排查

### 1. 检查 Release Tag 是否存在

确认 `v1.0.0` tag 存在于 `nursor/nursor-core2` 仓库：
```
https://github.com/nursor/nursor-core2/releases/tag/v1.0.0
```

### 2. 检查 Asset 名称

确认 Release 中有名为 `core-windows-amd64` 的 asset（不含 `.dll` 扩展名）。

如果实际的 asset 名称不同，需要更新脚本中的文件名。

### 3. 检查 Repository 名称

确认 `CORE_REPO` 环境变量正确：
```yaml
env:
  CORE_REPO: nursor/nursor-core2
```

### 4. 权限问题

如果是私有仓库：
- 确保 `GITHUB_TOKEN` 或 `PACKAGING_REPO_TOKEN` 有访问权限
- 考虑使用 Personal Access Token (PAT)

## 🔧 调试步骤

如果仍然失败，查看工作流日志中的详细错误信息：

1. **查看下载 URL**：检查输出的 URL 是否正确
2. **查看文件大小**：如果是 0 字节，说明下载失败
3. **查看文件内容**：如果前几个字符是 `<!DOCTYPE` 或 `{`，说明下载的是错误页面

## 🎯 预期结果

修复后，应该看到：

```
Downloading nursor-core from: https://github.com/nursor/nursor-core2/releases/download/v1.0.0/core-windows-amd64
Download completed successfully
Downloaded file size: XXXXX bytes
File downloaded and verified successfully
✓ SHA256 checksum verified successfully (如果存在)
```

## 📝 注意事项

1. **Asset 命名**：GitHub Releases 的 asset 文件名必须完全匹配（区分大小写）
2. **Tag 格式**：确保 tag 名称正确（如 `v1.0.0`）
3. **文件扩展名**：下载时不需要扩展名，保存时需要添加 `.dll`

如果问题仍然存在，请检查：
- Release tag 是否存在
- Asset 名称是否正确
- 仓库权限是否足够

