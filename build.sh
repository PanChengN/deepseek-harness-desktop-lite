#!/bin/bash
# 构建 DeepSeek Harness 桌面版（macOS）
# 用法：
#   ./build.sh             # 编译并打包到 build/DeepSeek Harness.app
#   ./build.sh --install   # 打包并安装到 ~/Applications
set -euo pipefail

cd "$(dirname "$0")"

APP="DeepSeek Harness"
BUILD_DIR="build"
MODULE_CACHE="$BUILD_DIR/module-cache"
BUNDLE="$BUILD_DIR/$APP.app"

mkdir -p "$BUILD_DIR" "$MODULE_CACHE"

echo "==> 编译 Swift 源码"
swiftc -O \
  -module-cache-path "$MODULE_CACHE" \
  -framework Cocoa -framework WebKit \
  Sources/main.swift -o "$BUILD_DIR/DeepSeekHarness"

echo "==> 打包 $BUNDLE"
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BUILD_DIR/DeepSeekHarness" "$BUNDLE/Contents/MacOS/"
cp assets/AppIcon.icns "$BUNDLE/Contents/Resources/"
cp Info.plist "$BUNDLE/Contents/"
chmod +x "$BUNDLE/Contents/MacOS/DeepSeekHarness"

echo "==> 健康检查（附加模式）"
if DSH_DESKTOP_TEST=1 "$BUNDLE/Contents/MacOS/DeepSeekHarness" 2>/dev/null; then
  echo "==> 完成：$BUNDLE"
else
  echo "注意：当前没有运行中的服务，应用将在首次启动时自动拉起 dsh web（正常）。" >&2
fi

if [[ "${1:-}" == "--install" ]]; then
  echo "==> 安装到 ~/Applications"
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/$APP.app"
  cp -R "$BUNDLE" "$HOME/Applications/"
  echo "==> 已安装：~/Applications/$APP.app"
fi
