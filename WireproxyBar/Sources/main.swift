import AppKit
import Foundation

// MARK: - Config

let wireproxyBin  = "/Users/sammers/Git/ext/wireproxy-awg/wireproxy"
let sourceConf    = "/Users/sammers/Git/ext/wireproxy-awg/de.conf"
let destConfig    = "/Users/sammers/Git/ext/wireproxy-awg/config"
let logFilePath   = "/tmp/wireproxy.log"
let tmuxSession   = "wireproxy"
let tmux          = "/opt/homebrew/bin/tmux"
let socksAddr     = "127.0.0.1:25344"
let httpAddr      = "127.0.0.1:25345"
let endpoint      = "162.249.127.106:43524"

let proxyAppend = """

[Socks5]
BindAddress = \(socksAddr)

[http]
BindAddress = \(httpAddr)
"""

// MARK: - Shell helpers

@discardableResult
func shell(_ cmd: String) -> (Int32, String) {
    let p = Process()
    let pipe = Pipe()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", cmd]
    p.standardOutput = pipe
    p.standardError  = pipe
    try? p.run()
    p.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (p.terminationStatus, String(data: data, encoding: .utf8) ?? "")
}

func isWireproxyRunning() -> Bool {
    // Check both tmux session and actual wireproxy process
    let (tmuxStatus, _) = shell("\(tmux) has-session -t \(tmuxSession) 2>/dev/null")
    if tmuxStatus == 0 { return true }
    // Fallback: check if wireproxy process is alive on our ports
    let (pgrepStatus, _) = shell("pgrep -f 'wireproxy.*-c.*config' >/dev/null 2>&1")
    return pgrepStatus == 0
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {

    var statusItem: NSStatusItem!
    var monitorTimer: Timer?

    // Menu items we update dynamically
    var statusMenuItem: NSMenuItem!
    var endpointMenuItem: NSMenuItem!
    var socksMenuItem: NSMenuItem!
    var httpMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        prepareConfig()
        launchWireproxy()
        updateStatus()   // refresh now that tmux session is up
        startMonitor()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitorTimer?.invalidate()
        // Don't kill tmux session on quit — let it keep running
    }

    // MARK: Config

    func prepareConfig() {
        do {
            var content = try String(contentsOfFile: sourceConf, encoding: .utf8)
            content += proxyAppend
            try content.write(toFile: destConfig, atomically: true, encoding: .utf8)
        } catch {
            NSLog("WireproxyBar: failed to write config: \(error)")
        }
    }

    // MARK: Tmux process management

    func launchWireproxy() {
        // Kill existing session if any
        shell("\(tmux) kill-session -t \(tmuxSession) 2>/dev/null")
        // Kill stale processes on our ports
        shell("lsof -ti :25344 -ti :25345 | xargs kill -9 2>/dev/null")
        usleep(500_000) // 0.5s

        // Start wireproxy inside a new tmux session
        // Pipe through tee so we also have a log file
        let cmd = "\(wireproxyBin) -c \(destConfig) 2>&1 | tee \(logFilePath)"
        shell("\(tmux) new-session -d -s \(tmuxSession) '\(cmd)'")
    }

    // MARK: Status Item

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()
        menu.minimumWidth = 220

        // ── Status header ──
        statusMenuItem = NSMenuItem(title: "  Starting…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        // ── Connection info ──
        let infoHeader = NSMenuItem(title: "CONNECTION", action: nil, keyEquivalent: "")
        infoHeader.isEnabled = false
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        infoHeader.attributedTitle = NSAttributedString(string: "CONNECTION", attributes: headerAttrs)
        menu.addItem(infoHeader)

        endpointMenuItem = makeInfoItem(icon: "globe", text: "Endpoint: \(endpoint)")
        menu.addItem(endpointMenuItem)

        socksMenuItem = makeInfoItem(icon: "network", text: "SOCKS5:   \(socksAddr)")
        menu.addItem(socksMenuItem)

        httpMenuItem = makeInfoItem(icon: "link", text: "HTTP:       \(httpAddr)")
        menu.addItem(httpMenuItem)

        menu.addItem(.separator())

        // ── Actions ──
        let attachItem = NSMenuItem(title: "Attach Session in iTerm", action: #selector(attachSession), keyEquivalent: "l")
        attachItem.target = self
        if let img = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil) {
            img.isTemplate = true
            attachItem.image = img
        }
        menu.addItem(attachItem)

        let updateItem = NSMenuItem(title: "Update Config & Restart", action: #selector(updateConfigAndRestart), keyEquivalent: "r")
        updateItem.target = self
        if let img = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil) {
            img.isTemplate = true
            updateItem.image = img
        }
        menu.addItem(updateItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit WireproxyBar", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        if let img = NSImage(systemSymbolName: "power", accessibilityDescription: nil) {
            img.isTemplate = true
            quitItem.image = img
        }
        menu.addItem(quitItem)

        statusItem.menu = menu
        updateStatus()
    }

    func makeInfoItem(icon: String, text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: nil) {
            img.isTemplate = true
            item.image = img
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        item.attributedTitle = NSAttributedString(string: text, attributes: attrs)
        return item
    }

    func makeColoredDot(color: NSColor, size: CGFloat = 18) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let inset: CGFloat = 3
            let circleRect = rect.insetBy(dx: inset, dy: inset)
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: circleRect)
            return true
        }
        img.isTemplate = false
        return img
    }

    func updateStatus() {
        let running = isWireproxyRunning()

        // ── Menu bar icon: bright colored dot ──
        if let button = statusItem.button {
            let color: NSColor = running
                ? NSColor(red: 0.2, green: 0.85, blue: 0.3, alpha: 1.0)   // bright green
                : NSColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1.0)  // bright red
            button.image = makeColoredDot(color: color)
            button.title = " VPN"
        }

        // ── Status line in dropdown ──
        let statusText = running ? "  Connected" : "  Disconnected"
        let statusColor: NSColor = running ? .systemGreen : .systemRed
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: statusColor
        ]
        statusMenuItem.attributedTitle = NSAttributedString(string: statusText, attributes: attrs)
        statusMenuItem.image = makeColoredDot(color: statusColor, size: 14)
    }

    func startMonitor() {
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }

    // MARK: Actions

    @objc func attachSession() {
        let script = """
        tell application "iTerm"
            activate
            set newWindow to (create window with default profile)
            tell current session of newWindow
                write text "\(tmux) attach -t \(tmuxSession)"
            end tell
        end tell
        """
        var err: NSDictionary?
        if let s = NSAppleScript(source: script) {
            s.executeAndReturnError(&err)
        }
        if let err = err {
            NSLog("WireproxyBar: AppleScript error: \(err)")
        }
    }

    @objc func updateConfigAndRestart() {
        prepareConfig()       // 1. copy de.conf -> config + append proxy sections
        launchWireproxy()     // 2. kill old tmux session, start fresh
        updateStatus()        // 3. refresh menu bar icon
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
