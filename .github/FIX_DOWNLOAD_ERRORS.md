# 修复下载和 Inno Setup 错误

## 🔴 错误 1: Flutter App 下载失败

**错误信息：**
```
fatal: could not read Username for 'https://github.com': Device not configured
Error: Process completed with exit code 128.
```

**原因：**
- 如果 `nursor-flutter-app` 仓库是私有的，使用 HTTPS URL 克隆时需要身份验证
- GitHub Actions 的默认 `GITHUB_TOKEN` 没有正确使用

**解决方案：**
已更新所有平台的 Flutter App 下载步骤，现在会：
1. 检查 `GITHUB_TOKEN` 是否存在
2. 如果存在，使用 token 进行身份验证：`https://$TOKEN@github.com/owner/repo.git`
3. 如果不存在（公开仓库），使用普通 HTTPS URL

**修复后的代码：**
- macOS/Linux: 使用 `https://${{ secrets.GITHUB_TOKEN }}@github.com/...` 格式
- Windows: 使用 PowerShell 变量和条件检查

---

## 🔴 错误 2: Inno Setup Action 找不到

**错误信息：**
```
Error: Unable to resolve action ilexn/innosetup-action, repository not found
```

**原因：**
- `ilexn/innosetup-action` 仓库可能不存在或已被删除
- Action 可能已迁移或不再维护

**解决方案：**
已改为手动安装 Inno Setup，不再依赖第三方 action。

**修复后的步骤：**
1. 下载 Inno Setup 安装程序（版本 6.2.2）
2. 使用静默安装方式安装
3. 添加到 PATH 环境变量
4. 验证安装是否成功

**修复后的代码：**
```yaml
- name: Setup Inno Setup
  run: |
    # 下载并安装 Inno Setup
    $innosetupVersion = "6.2.2"
    $innosetupUrl = "https://files.jrsoftware.org/is/6/innosetup-$innosetupVersion.exe"
    $installerPath = "$env:TEMP\innosetup-installer.exe"
    
    Write-Host "Downloading Inno Setup $innosetupVersion..."
    Invoke-WebRequest -Uri $innosetupUrl -OutFile $installerPath
    
    Write-Host "Installing Inno Setup..."
    Start-Process -FilePath $installerPath -ArgumentList "/SILENT", "/DIR=C:\Program Files (x86)\Inno Setup 6" -Wait
    
    Write-Host "Adding Inno Setup to PATH..."
    $env:PATH += ";C:\Program Files (x86)\Inno Setup 6"
    Add-Content -Path $env:GITHUB_ENV -Value "PATH=$env:PATH;C:\Program Files (x86)\Inno Setup 6"
    
    # 验证安装
    if (Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe") {
      Write-Host "Inno Setup installed successfully"
      & "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /?
    } else {
      Write-Error "Inno Setup installation failed"
      exit 1
    }
```

**更新后的构建步骤：**
```yaml
- name: Build Windows installer
  run: |
    # 使用完整路径调用 ISCC
    $isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (Test-Path $isccPath) {
      & $isccPath nursor_win_installer.iss
    } else {
      Write-Error "ISCC.exe not found at $isccPath"
      exit 1
    }
```

---

## ✅ 已修复的平台

### macOS (amd64 & arm64)
- ✅ 使用 GITHUB_TOKEN 进行身份验证
- ✅ 支持私有和公开仓库

### Windows (amd64)
- ✅ 使用 GITHUB_TOKEN 进行身份验证
- ✅ 手动安装 Inno Setup
- ✅ 使用完整路径调用 ISCC

### Linux (amd64)
- ✅ 使用 GITHUB_TOKEN 进行身份验证
- ✅ 支持私有和公开仓库

---

## 📋 注意事项

### GITHUB_TOKEN 权限

`GITHUB_TOKEN` 是 GitHub Actions 自动提供的，具有以下特性：
- ✅ 对当前仓库有完整访问权限
- ✅ 对同一组织的其他仓库有读取权限（如果仓库是公开的）
- ⚠️ 如果是跨组织的私有仓库，可能需要使用 Personal Access Token (PAT)

### 如果仓库是跨组织的私有仓库

如果 `nursor-flutter-app` 仓库是另一个组织的私有仓库，可能需要：

1. **创建 Personal Access Token (PAT)**
   - 前往：https://github.com/settings/tokens
   - 创建具有 `repo` 权限的 token

2. **添加 Secret**
   - 在 `nursor_install` 仓库中添加 secret：`FLUTTER_REPO_TOKEN`
   - 值：创建的 PAT

3. **更新工作流**
   - 在 Flutter App 下载步骤中使用 `${{ secrets.FLUTTER_REPO_TOKEN }}` 代替 `${{ secrets.GITHUB_TOKEN }}`

### Inno Setup 版本

当前使用 Inno Setup 6.2.2，如需更新版本：
- 修改 `$innosetupVersion` 变量
- 确保下载 URL 正确

---

## 🧪 测试

修复后，可以：

1. **测试 Flutter App 下载**
   - 检查构建日志，确认仓库克隆成功
   - 确认没有身份验证错误

2. **测试 Inno Setup 安装**
   - 检查构建日志，确认 Inno Setup 安装成功
   - 确认 `ISCC.exe` 可执行

3. **测试 Windows 安装器构建**
   - 确认安装器文件生成成功
   - 确认文件存在于 `output/` 目录

---

## 📚 相关文档

- `.github/TROUBLESHOOTING.md` - 故障排除指南
- `.github/FIX_REPOSITORY_DISPATCH.md` - Repository Dispatch 修复指南
- `.github/FIX_REPO_NOT_FOUND.md` - 仓库未找到错误修复

