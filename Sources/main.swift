// DeepSeek Harness 桌面版（macOS，轻量）
// - 启动即拉起 `dsh web`（若无实例），关闭窗口即停止自己拉起的服务。
// - 内置 WKWebView 展示 http://127.0.0.1:<port>/（默认 3080）。
// - 图标：黑色鲸鱼（DeepSeek 官方鲸鱼标志的单色版，见 assets/）。
//
// 配置（UserDefaults，域名 local.deepseek-harness.desktop）：
//   defaults write local.deepseek-harness.desktop dsBin   "/path/to/dsh"
//   defaults write local.deepseek-harness.desktop dshHome "/path/to/.dsh"
//   defaults write local.deepseek-harness.desktop port    -int 3080
// 默认值：dsBin = ~/.npm-global/bin/dsh，dshHome = ~/.dsh，port = 3080。

import Cocoa
import WebKit
import Darwin

final class AppDelegate: NSObject, NSApplicationDelegate, WKUIDelegate, WKNavigationDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var serverProcess: Process?
    private var healthTimer: DispatchSourceTimer?
    private var startedByUs = false
    private var serverPid: Int32 = 0

    private let defaults = UserDefaults.standard
    private var appURL: URL = URL(string: "http://127.0.0.1:3080/")!
    private var dsBin = NSHomeDirectory() + "/.npm-global/bin/dsh"
    private var dshHome = NSHomeDirectory() + "/.dsh"

    // MARK: - 配置
    private func loadConfig() {
        if let port = defaults.object(forKey: "port") as? Int, port > 0, port < 65536 {
            appURL = URL(string: "http://127.0.0.1:\(port)/")!
        }
        if let bin = defaults.string(forKey: "dsBin"), !bin.isEmpty {
            dsBin = bin
        }
        if let home = defaults.string(forKey: "dshHome"), !home.isEmpty {
            dshHome = home
        }
    }

    // MARK: - 测试模式：DSH_DESKTOP_TEST=1 时只做健康检查并退出，不显示窗口
    private func runTestMode() -> Never {
        let sema = DispatchSemaphore(value: 0)
        var healthy = false
        var detail = ""
        checkHealth { ok, code, err in
            healthy = ok
            if ok { detail = "HTTP \(code)" } else { detail = err ?? "connection failed" }
            sema.signal()
        }
        _ = sema.wait(timeout: .now() + 10)
        if healthy {
            print("HEALTHY \(detail)")
            exit(0)
        } else {
            print("UNHEALTHY \(detail)")
            exit(1)
        }
    }

    // MARK: - 生命周期
    func applicationDidFinishLaunching(_ notification: Notification) {
        loadConfig()
        if ProcessInfo.processInfo.environment["DSH_DESKTOP_TEST"] == "1" {
            runTestMode()
        }
        buildMenu()
        setupWindow()
        attachOrStart()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopServerIfOurs()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - 菜单（Edit 菜单是 WKWebView 快捷键可用的关键）
    private func buildMenu() {
        let mainMenu = NSMenu()

        // App
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 DeepSeek Harness",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 DeepSeek Harness",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 DeepSeek Harness",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // 编辑（撤销/剪切/拷贝/粘贴/全选 —— 没有这些菜单项，WKWebView 里的快捷键全部失效）
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "删除", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        // 显示
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "显示")
        viewMenu.addItem(withTitle: "重新载入页面",
                         action: #selector(reloadPage(_:)),
                         keyEquivalent: "r")
        viewMenuItem.submenu = viewMenu

        // 窗口
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭窗口",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }

    @objc private func reloadPage(_ sender: Any?) {
        webView?.reload()
    }

    // MARK: - 窗口与 WebView
    private func setupWindow() {
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 840),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "DeepSeek Harness"
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("DeepSeekHarnessWindow")
        window.makeKeyAndOrderFront(nil)
    }

    private func loadApp() {
        webView.load(URLRequest(url: appURL))
    }

    private func showStartupError(_ message: String) {
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, sans-serif; display: flex; align-items: center;
               justify-content: center; height: 100vh; margin: 0; background: #f5f5f7; }
        .box { max-width: 480px; padding: 32px; background: #fff; border-radius: 12px;
               box-shadow: 0 4px 24px rgba(0,0,0,.08); color: #333; }
        h1 { font-size: 18px; } p { font-size: 13px; line-height: 1.6; color: #666; }
        code { background: #f0f0f2; padding: 2px 6px; border-radius: 4px; }
        button { margin-top: 8px; padding: 8px 16px; border: none; border-radius: 8px;
                 background: #4d6bfe; color: #fff; cursor: pointer; font-size: 13px; }
        </style></head><body><div class="box">
        <h1>DeepSeek Harness 启动失败</h1>
        <p>\(message)</p>
        <p>诊断：可在终端运行 <code>dsh web</code> 查看详细输出；日志位于
           <code>~/.dsh/logs/desktop-web.log</code>。</p>
        <button onclick="location.reload()">重试</button>
        </div></body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - 服务发现 / 拉起 / 停止
    private func checkHealth(_ completion: @escaping (Bool, Int, String?) -> Void) {
        var request = URLRequest(url: appURL)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse {
                let ok = (200 ... 399).contains(http.statusCode)
                completion(ok, http.statusCode, nil)
            } else {
                completion(false, 0, error?.localizedDescription ?? "no response")
            }
        }
        task.resume()
    }

    private func attachOrStart() {
        checkHealth { healthy, _, _ in
            if healthy {
                self.adoptRecordedPid()
                DispatchQueue.main.async { self.loadApp() }
            } else {
                self.spawnServerIfPossible()
                self.pollUntilHealthy()
            }
        }
    }

    private func logDir() -> URL {
        let dir = URL(fileURLWithPath: self.dshHome).appendingPathComponent("logs")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func pidFilePath() -> String {
        return logDir().appendingPathComponent("desktop-web.pid").path
    }

    private func childEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        if env["DSH_HOME"] == nil || env["DSH_HOME"]!.isEmpty {
            env["DSH_HOME"] = self.dshHome
        }
        if env["LANG"] == nil || env["LANG"]!.isEmpty {
            env["LANG"] = "zh_CN.UTF-8"
        }
        return env
    }

    private func spawnServerIfPossible() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = [self.dsBin, "web"]
        proc.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        proc.environment = childEnvironment()

        let logURL = logDir().appendingPathComponent("desktop-web.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        if let fh = try? FileHandle(forWritingTo: logURL) {
            proc.standardOutput = fh
            proc.standardError = fh
        }

        do {
            try proc.run()
            serverProcess = proc
            startedByUs = true
            serverPid = proc.processIdentifier
            try? String(proc.processIdentifier).write(toFile: pidFilePath(), atomically: true, encoding: .utf8)
        } catch {
            DispatchQueue.main.async {
                self.showStartupError("无法启动服务：\(error.localizedDescription)。请确认 dsBin 配置正确（默认 ~/.npm-global/bin/dsh）。")
            }
        }
    }

    private func pollUntilHealthy() {
        var attempts = 0
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 1.0, repeating: 1.0)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            attempts += 1
            self.checkHealth { healthy, _, _ in
                if healthy {
                    timer.cancel()
                    DispatchQueue.main.async { self.loadApp() }
                } else if attempts >= 60 {
                    timer.cancel()
                    DispatchQueue.main.async {
                        self.showStartupError("服务在 60 秒内未就绪，请查看日志后重试。")
                    }
                }
            }
        }
        healthTimer = timer
        timer.resume()
    }

    private func adoptRecordedPid() {
        guard let content = try? String(contentsOfFile: pidFilePath(), encoding: .utf8) else { return }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(trimmed), pid > 0, kill(pid, 0) == 0 else { return }
        serverPid = pid
        startedByUs = true
    }

    private func stopServerIfOurs() {
        guard startedByUs else { return }
        if let proc = serverProcess, proc.isRunning {
            proc.terminate()
            let deadline = Date().addingTimeInterval(3)
            while proc.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            if proc.isRunning {
                kill(proc.processIdentifier, SIGKILL)
            }
        } else if serverPid > 0, kill(serverPid, 0) == 0 {
            kill(serverPid, SIGTERM)
        }
        try? FileManager.default.removeItem(atPath: pidFilePath())
    }

    // MARK: - WKUIDelegate：新标签页（target=_blank）交给系统浏览器
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
