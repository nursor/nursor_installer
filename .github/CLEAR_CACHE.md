# 清除 GitHub Actions 缓存

## 🔴 错误信息

如果你仍然看到以下错误：
```
Error: Unable to resolve action ilexn/innosetup-action, repository not found
```

即使工作流文件已经更新，这可能是因为：

1. **GitHub Actions 缓存**：GitHub 可能缓存了旧的 action 引用
2. **旧的工作流运行**：你看到的可能是之前的失败运行
3. **文件未正确提交**：工作流文件更改可能还没有提交到仓库

## ✅ 解决方案

### 步骤 1: 确认文件已更新

1. **检查工作流文件**
   - 确认 `.github/workflows/build-all-platforms.yml` 文件中没有 `ilexn/innosetup-action`
   - 确认有 `Setup Inno Setup` 步骤，使用 `run:` 而不是 `uses:`

2. **搜索确认**
   ```bash
   # 在仓库根目录运行
   grep -r "ilexn" .github/workflows/
   # 应该没有输出
   ```

### 步骤 2: 提交并推送更改

1. **提交更改**
   ```bash
   git add .github/workflows/build-all-platforms.yml
   git commit -m "Fix: Replace ilexn/innosetup-action with manual Inno Setup installation"
   git push
   ```

2. **验证文件已推送**
   - 在 GitHub 网页上查看 `.github/workflows/build-all-platforms.yml`
   - 确认文件内容已更新

### 步骤 3: 清除 Actions 缓存

1. **取消正在运行的工作流**
   - 前往 Actions 页面
   - 如果有正在运行的工作流，取消它们

2. **等待几秒钟**
   - 让 GitHub 更新缓存

### 步骤 4: 重新触发工作流

1. **使用 workflow_dispatch 手动触发**
   - 前往 Actions 页面
   - 选择 "Build All Platforms" 工作流
   - 点击 "Run workflow"
   - 输入版本号（例如：`v1.0.0`）
   - 点击 "Run workflow"

2. **或者创建一个新的 tag**
   ```bash
   git tag v1.0.0-test-fix
   git push origin v1.0.0-test-fix
   ```

## 🔍 验证修复

修复后，你应该看到：

1. **Setup Inno Setup 步骤**
   - 显示 "Downloading Inno Setup 6.2.2..."
   - 显示 "Installing Inno Setup..."
   - 显示 "Inno Setup installed successfully"

2. **没有错误**
   - 不应该看到 `ilexn/innosetup-action` 相关的错误
   - Windows 构建应该可以继续进行

## 📋 当前工作流文件状态

当前工作流文件应该包含：

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

**不是：**
```yaml
- name: Setup Inno Setup
  uses: ilexn/innosetup-action@v1.0.1  # ❌ 不应该有这个
```

## 🆘 如果仍然失败

如果按照上述步骤操作后仍然失败：

1. **检查 GitHub Actions 状态**
   - 访问：https://www.githubstatus.com/
   - 确认 GitHub Actions 服务正常

2. **检查文件内容**
   - 在 GitHub 网页上查看工作流文件的原始内容
   - 确认更改已正确提交

3. **创建新分支测试**
   ```bash
   git checkout -b test/fix-innosetup
   git push origin test/fix-innosetup
   ```
   - 在新分支上创建一个 tag 进行测试

4. **查看最新运行日志**
   - 确认你查看的是最新的工作流运行
   - 不是之前失败的运行

