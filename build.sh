#!/bin/bash

# 清理旧的构建文件
rm -rf build
mkdir -p build

# 构建 Nursor.app 组件包
pkgbuild --root Nursor.app \
         --identifier com.nursor.app \
         --version 1.0 \
         --install-location /Applications \
         build/nursor-app.pkg

# 创建临时目录用于 nursor-core 和 plist
mkdir -p build/root/tmp
cp nursor-core build/root/tmp/nursor-core
cp org.nursor.nursor-core.plist build/root/tmp/org.nursor.nursor-core.plist

# 构建 nursor-core 组件包
pkgbuild --root build/root \
         --identifier com.nursor.core \
         --version 1.0 \
         --install-location / \
         --scripts scripts \
         build/nursor-core.pkg

# 合成最终安装包
productbuild --distribution distribution.xml \
             --package-path build \
             --resources . \
             build/Nursor-Installer.pkg

echo "PKG 安装包已生成：build/Nursor-Installer.pkg"