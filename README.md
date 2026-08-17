🌏 [English](./README.en.md) | 简体中文

# DeepSeek Harness Desktop 轻量版（macOS）

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-lightgrey.svg)](#前置条件)
[![Unofficial](https://img.shields.io/badge/status-unofficial-orange.svg)](#声明)

一个**轻量级**的 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web GUI 的 macOS 桌面包装：原生 Swift + WKWebView，体积约 250 KB（无 Electron）。

**启动即启动，关闭即关闭**——双击应用自动拉起 `dsh web` 服务并显示界面；关闭窗口即自动停止服务。不用再开终端。

应用界面（菜单、提示页）自动跟随系统语言在中文 / English 之间切换。

## 声明

> ⚠️ **本项目为非官方社区项目**，与深度求索（DeepSeek）公司没有任何关联，也未获得其认可或背书。
> 「DeepSeek」名称与鲸鱼标志是深度求索（DeepSeek）的商标；本仓库仅在兼容性说明中使用这些名称，
> 不代表任何官方关系。应用图标基于 LobeHub lobe-icons 的 DeepSeek 图标（MIT 许可）修改为黑色，仅用于本地展示；
> 如需再分发，建议替换为自己的图形。

## 特性

- 双击启动：自动检测 `127.0.0.1:3080`，未运行则后台拉起 `dsh web`（日志写入 `~/.dsh/logs/desktop-web.log`）
- 关闭窗口 = 退出应用 = 停止自己拉起的服务（从终端手动启动的服务不受影响）
- 崩溃/异常退出后重新打开可自动接管自己之前拉起的服务（pid 记录）
- 完整的标准菜单：编辑（撤销/剪切/拷贝/粘贴/全选）、显示（⌘R 重新载入）、窗口（⌘M/⌘W）
- 页面内 `target="_blank"` 链接交给系统默认浏览器打开
- 黑色鲸鱼应用图标（全套分辨率 .icns）
- 中文 / English 界面自动切换（跟随系统语言）

## 前置条件

- **macOS 12+**（Apple Silicon / Intel 均可）
- **Xcode Command Line Tools**（提供 `swiftc` 编译器）：
  ```sh
  xcode-select --install
  ```
- **Node.js 22.19+ 或 24+**（DeepSeek Harness 的运行环境）
- **`dsh` CLI**，二选一安装：

  **方式一：npm 安装（推荐）**
  ```sh
  npm install -g @deepseek-ai/dsh
  # 验证：
  dsh web --help
  ```
  若 npm 全局目录不在默认位置，可用 `npm config get prefix` 查看，
  并把真实路径配置到本应用的 `dsBin`（见下方配置）。

  **方式二：源码安装**
  ```sh
  git clone https://github.com/deepseek-ai/deepseek-harness.git ~/deepseek-harness
  cd ~/deepseek-harness
  pnpm install
  pnpm run build
  pnpm dsh web     # 验证能启动（Ctrl+C 退出）
  ```
  然后建一个全局包装脚本（`~/.npm-global/bin/dsh`，需在 PATH 中）：
  ```sh
  mkdir -p ~/.npm-global/bin
  cat > ~/.npm-global/bin/dsh <<'EOF'
  #!/bin/bash
  cd "$HOME/deepseek-harness" || exit 1
  exec node --import tsx/esm apps/cli/src/bin.ts "$@"
  EOF
  chmod +x ~/.npm-global/bin/dsh
  ```
  （`pnpm` 可通过 Corepack 启用：`corepack enable pnpm`。）

## 构建与安装

```bash
./build.sh            # 编译并打包到 build/DeepSeek Harness.app
./build.sh --install  # 打包并安装到 ~/Applications
```

打开 `~/Applications/DeepSeek Harness.app`（或拖入 Dock/启动台）。

## 配置

应用通过 UserDefaults 读取配置（域名 `local.deepseek-harness.desktop`）：

```bash
defaults write local.deepseek-harness.desktop dsBin   "/path/to/dsh"   # dsh 可执行文件，默认 ~/.npm-global/bin/dsh
defaults write local.deepseek-harness.desktop dshHome "/path/to/.dsh"  # DSH_HOME，默认 ~/.dsh
defaults write local.deepseek-harness.desktop port    -int 3080        # Web 端口，默认 3080
defaults delete local.deepseek-harness.desktop dsBin                    # 恢复默认
```

## 工作原理

1. 启动时对 `http://127.0.0.1:<port>/` 做健康检查；
2. 已就绪 → 直接加载页面（附加模式，退出不影响现有服务）；未就绪 → 以子进程方式拉起 `dsh web`，每秒探测直到就绪（60 秒超时）；
3. 应用退出时对**自己拉起的**服务发 SIGTERM（3 秒宽限后 SIGKILL）；
4. 界面由 WKWebView 展示，网页外链在系统浏览器打开。

## 目录结构

```
Sources/main.swift      # 全部源码（单文件，无第三方依赖）
Info.plist              # 应用清单
assets/AppIcon.icns     # 应用图标（黑色鲸鱼）
assets/whale-black.svg  # 图标源文件（基于 LobeHub lobe-icons 的 DeepSeek 图标，MIT）
build.sh                # 一键构建/安装脚本
.github/workflows/      # GitHub Actions：macOS 自动构建校验
```

## 图标

`assets/whale-black.svg` 源自 [LobeHub lobe-icons](https://github.com/lobehub/lobe-icons)（MIT 许可），已改为纯黑色。鲸鱼标志是 DeepSeek 的商标，仅用于本地应用展示；如需分发，建议替换为自己的图形。

## License

[MIT](LICENSE)
