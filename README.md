# Nursor 安装程序

## 概述

此仓库主要负责的是给nursor-core和nursor-app项目打包用的，将这些项目打包之后形成一个安装包，用户执行安装之后，会安装好对应的依赖，以及证书。主要功能有：
1. windows
    1. 打包所有应用程序文件
    2. 将 wintun.dll 移动到 C:\Windows\System32，有时是C:\\windows\syswow64，两者都是一样作用的
    3. 安装并信任 ca.pem 证书
    4. 创建开始菜单和可选的桌面快捷方式
    
1. macos
    1. 安装证书
    2. 将可执行文件移动到/Libirary/Application Support/Nursor下，同时也会移动trust_ca.sh和异常上报脚本；
    3. 移动完成后会尝试启动这个可执行文件；
    
1. linux
    1. 常规操作，由于tun是系统自带的，最为轻松
    

## 重要说明

### 运行方式

#### 方法1：手动以管理员身份运行
1. 右键点击 `NursorInstaller.exe`
2. 选择"以管理员身份运行"

#### 方法2：使用提供的脚本
- **批处理文件**：双击运行 `run_as_admin.bat`
- **PowerShell脚本**：右键点击 `run_as_admin.ps1` 选择"使用PowerShell运行"

#### 方法3：命令行
```cmd
# 以管理员身份打开命令提示符，然后运行：
NursorInstaller.exe
```

## 问题记录

### 权限错误
如果遇到"拒绝访问"或"权限不足"错误：
1. 确保以管理员身份运行安装程序
2. 检查Windows UAC设置是否启用
3. 尝试使用提供的启动脚本

### wintun.dll 安装失败
如果 wintun.dll 无法复制到 System32：
1. 确保没有其他程序正在使用 wintun.dll
2. 重启计算机后重试
3. 检查防病毒软件是否阻止了操作

### 证书安装失败
如果证书安装失败：
1. 确保以管理员身份运行
2. 检查 ca.pem 文件是否存在且有效
3. 手动运行 `certutil -addstore Root ca.pem`
4. 目前脚本的启动逻辑是，安装结束后自动运行；同时在flutter中也会调用bash命令来提权，来执行trustca的脚本。

## 测试安装

测试安装的时候，需要删除flutter的build，installer项目中的各种app，之后才能安装并且出现在launchpad中，似乎有一个全局唯一的限制。

## 文件说明

- `nursor_win_installer.iss` - 主要的 Inno Setup 脚本
- `installer.manifest` - Windows 清单文件，声明管理员权限要求
- `run_as_admin.bat` - 批处理启动脚本
- `run_as_admin.ps1` - PowerShell 启动脚本
- `macos/build_installer.sh` - macos的安装文件生成工具

Windows下需要下载innostep打包工具来打包「方案选单」

## macOS 特定说明

### 证书信任问题（macOS 12+）

在 **macOS 12 (Monterey) 和 macOS 13 (Ventura) 及以上版本**，由于 Apple 加强了系统安全策略，**完全自动化的证书信任设置是不可能的**。

**问题原因：**
- macOS 12/13+ 禁止在没有用户交互的情况下修改证书信任设置（trustRoot）
- `security add-trusted-cert` 命令在无 GUI 的环境中会失败
- 这是 Apple 为防止恶意软件自动安装证书而实施的安全措施

**解决方案：**

1. **自动安装**：脚本会将证书添加到系统钥匙链（`security add-certificates`）
2. **手动信任**：用户需要手动在 "钥匙串访问" 应用中设置证书为 "始终信任"

**手动信任证书的步骤：**
1. 打开 "钥匙串访问" 应用（Applications > Utilities > Keychain Access）
2. 在左侧选择 "系统" 钥匙链
3. 在右侧找到 `ca.pem` 或 Nursor 相关的证书
4. 双击证书，展开 "信任" 部分
5. 将 "使用此证书时" 设置为 "始终信任"
6. 关闭窗口并输入管理员密码

**日志文件位置：**
- 证书安装日志：`/tmp/nursor_trustca.log`
- 服务日志：`/var/log/nursor-core.log`

