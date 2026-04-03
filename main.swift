import Cocoa
import UserNotifications

// ─── Configuration ───────────────────────────────────────────────────────────

struct AppConfig: Codable {
    var repos: [String]
    var pollInterval: TimeInterval?
    var pollActiveInterval: TimeInterval?
    var runsPerRepo: Int?
}

let CONFIG_DIR  = NSString(string: "~/.config/gh-actions-bar").expandingTildeInPath
let CONFIG_PATH = (CONFIG_DIR as NSString).appendingPathComponent("config.json")

var REPOS: [String] = []
var POLL_NORMAL: TimeInterval = 30
var POLL_ACTIVE: TimeInterval = 10
var RUNS_PER_REPO: Int = 10

func loadConfig() {
    guard let data = FileManager.default.contents(atPath: CONFIG_PATH),
          let c = try? JSONDecoder().decode(AppConfig.self, from: data) else { return }
    REPOS = c.repos
    POLL_NORMAL = c.pollInterval ?? 30
    POLL_ACTIVE = c.pollActiveInterval ?? 10
    RUNS_PER_REPO = c.runsPerRepo ?? 10
}

func saveConfig(repos: [String]) {
    try? FileManager.default.createDirectory(atPath: CONFIG_DIR, withIntermediateDirectories: true)
    let c = AppConfig(repos: repos, pollInterval: POLL_NORMAL, pollActiveInterval: POLL_ACTIVE, runsPerRepo: RUNS_PER_REPO)
    if let data = try? JSONEncoder().encode(c) {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let pretty = try? JSONSerialization.data(withJSONObject: json as Any, options: .prettyPrinted) {
            try? pretty.write(to: URL(fileURLWithPath: CONFIG_PATH))
        }
    }
    REPOS = repos
}

// Find gh CLI
let GH: String = {
    for p in ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] {
        if FileManager.default.isExecutableFile(atPath: p) { return p }
    }
    let proc = Process(); proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    proc.arguments = ["which", "gh"]
    let pipe = Pipe(); proc.standardOutput = pipe; proc.standardError = FileHandle.nullDevice
    try? proc.run(); proc.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return out.isEmpty ? "/opt/homebrew/bin/gh" : out
}()

let POP_W: CGFloat = 560
let POP_MAX_H: CGFloat = 700
let ROW_H: CGFloat = 56
let HDR_H: CGFloat = 32
let FTR_H: CGFloat = 40

let GH_ICON_B64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAeGVYSWZNTQAqAAAACAAEARoABQAAAAEAAAA+ARsABQAAAAEAAABGASgAAwAAAAEAAgAAh2kABAAAAAEAAABOAAAAAAAAAEgAAAABAAAASAAAAAEAA6ABAAMAAAABAAEAAKACAAQAAAABAAAAJKADAAQAAAABAAAAJAAAAAAZgdfLAAAACXBIWXMAAAsTAAALEwEAmpwYAAAEkUlEQVRYCbWYTYyNVxjH5/pWE0NKqI9LlFawqCDtQiZWIsFOWSBIdWdj126mkerSx6IhkQjx0W5KSOxI2liw8LXoYDBhYoj4iJoxPovb3+/2vjfnnnnvuDPzzj/5zXve5zznOc8973nPOe/k6nqhQqEwGvdGWADzYDZMhQZQHdAOLdAMl+BsLpfr5JqdSCQPO6EFOuAVvIV38AESWdZmnT5dcB9sm+9XRgTIwXhognvwHOystzLJTjCGsYyZ61VyNBgGc+AEtENWMpYxjT2spqRwrIf5sAOeQdYyprHtoz5OalBowMGsZ8FKWA/JZKWYmYxpbPv4otRn9+BUDAKH0uwfQaJ/KbwAr33Vexo6B98EAezDvuyzYmCK2WF0sh2H8DEZ6DochSvg5DQxJ6ry6kTXlpDUYSrWmUgr7IHzJRuXouzLPsd3GyKMvgHxBHZkNiTOlFfBX/APmMBjuAx/BjykbJ2v/QVYFbRfwr1LQSj7bEp8ilcMefC1jOWv+yp05t5JP1FCe1hO6vWN7NOxOcqx7Lu4TiXPbisN0yZwAburb6gX3DwqEdrDsvUPQd9aZN/mUOdEdjtYDaM0RBrM/dehjW2gAB8ktIflUr1+/qBQU7hJWxRHYl9mLo5QI5hh7Pge2wNwX8pKbQQyprFD+cM/g0YTWghDINYrDKehLa7ox/0T2h6DlykxhmNbYEJzIZlLoZ+NTjLsz0Jjf8rEek3738CY8eN0lOaZiEcIb0Lp3AXnQmMWZZL6mziO1LsonjnMNqGpEI/QG2wPaJztOYagJTmP7CNUMRf/pL3uoeNAlJ8TNB4h+2mIR2YgOk+L6VKT9iIVH1W88BlgBExmXRio0fuS+BWruJ2iDkeoHdIWuU+wL4JMxY80prFjmUO7CbnwxQuVzq7c31rIWMuJl5aQObSY0FVIGyEXqsX8om+4ZiJiuQ0tBadELBNqNqGL4IIVy0k3E9YSaBrEW0vsX/XetjAZh3XgJ5Qn01gmdKkOx9Hg503yRfGa8lN4Ap5r1C6YAQ0wElLfkLAHfAbDCLCNx45tUE0e6jyC+Paxhv/foWcfdRZ+gI1wFZJE71L+BdbAXEgb9iSeiXwOy+FnaIaeZN+7io1LCYUHNE+DZ8DjgK/+FYjlsXZ7OUBUsA70qVXlA1o5FC09wlqhfFTXwKGWO+D5OtFBChUnyXIgCtbBAahF9tmUtA/nwl6M88EFywVxEmyCbbACNsM4aAOPJW6S1WTd3WqVgd1F+QLYd6XI0tNj+BnkRPO7XNsQGAufgi+BS0KPwucn6Empn0HlEWJnN4FWejkCZr4FJsAh+ANug5uik/kGXIO+6jENf4VT0GrfSaByQhqo8L8Wtyjq6GP7Dlw3PKt4aHe9Ggq/Q18T8sceBvu4aZ9cy6pISCsOfjc1U9wP02AhxBPY594X3afRRTC2I1ORjAFdqbtJR3AE1sJuMFAXxMdOTFWlr4/CFdhHbYx98D1cT0sGe21ixPKwE5zkfuj9+LGW+GwFv0rdBWyb/1gb63u1PxHUpV26+IUe1KsK3zFU1kMnvjUfhf8D2aXnxu16TasAAAAASUVORK5CYII="

// ─── Model ───────────────────────────────────────────────────────────────────

struct Run: Decodable {
    let name: String
    let displayTitle: String
    let status: String
    let conclusion: String?
    let headBranch: String
    let event: String
    let url: String
    let updatedAt: String
    let createdAt: String
    let startedAt: String?
    let number: Int
    let workflowName: String?
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

func ghShell(_ args: String...) -> Data? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: GH)
    proc.arguments = Array(args)
    proc.environment = ProcessInfo.processInfo.environment
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        return pipe.fileHandleForReading.readDataToEndOfFile()
    } catch { return nil }
}

func ghStr(_ args: String...) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: GH)
    proc.arguments = Array(args)
    proc.environment = ProcessInfo.processInfo.environment
    let pipe = Pipe()
    proc.standardOutput = pipe
    proc.standardError = FileHandle.nullDevice
    do {
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { return nil }
        let s = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s?.isEmpty == false ? s : nil
    } catch { return nil }
}

func fetchRuns(repo: String) -> [Run] {
    let fields = "name,displayTitle,status,conclusion,headBranch,event,url,updatedAt,createdAt,startedAt,number,workflowName"
    guard let data = ghShell("run", "list", "--repo", repo, "--limit", "\(RUNS_PER_REPO)", "--json", fields)
    else { return [] }
    return (try? JSONDecoder().decode([Run].self, from: data)) ?? []
}

func getGHUser() -> String? { ghStr("api", "user", "--jq", ".login") }

func fetchAvailableRepos() -> [String] {
    guard let out = ghStr("repo", "list", "--limit", "100", "--json", "nameWithOwner", "--jq", ".[].nameWithOwner")
    else { return [] }
    var repos = out.split(separator: "\n").map(String.init)
    // Also fetch org repos
    if let orgOut = ghStr("api", "user/orgs", "--jq", ".[].login") {
        for org in orgOut.split(separator: "\n") {
            if let orgRepos = ghStr("repo", "list", String(org), "--limit", "50",
                                    "--json", "nameWithOwner", "--jq", ".[].nameWithOwner") {
                repos.append(contentsOf: orgRepos.split(separator: "\n").map(String.init))
            }
        }
    }
    return Array(Set(repos)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
}

let isoFmt: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
}()
let isoFmtFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
}()

func parseISO(_ s: String?) -> Date? {
    guard let s = s, !s.isEmpty else { return nil }
    return isoFmtFrac.date(from: s) ?? isoFmt.date(from: s)
}

func fmtTimestamp(_ iso: String) -> String {
    guard let d = parseISO(iso) else { return "" }
    let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"; return f.string(from: d)
}

func fmtDuration(_ secs: TimeInterval) -> String {
    let s = Int(max(0, secs))
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s/60)m \(s%60)s" }
    return "\(s/3600)h \(s/60%60)m"
}

func runDuration(_ r: Run) -> String {
    guard let s = parseISO(r.startedAt) ?? parseISO(r.createdAt),
          let e = parseISO(r.updatedAt) else { return "" }
    return fmtDuration(e.timeIntervalSince(s))
}

func runElapsed(_ r: Run) -> TimeInterval {
    guard let s = parseISO(r.startedAt) ?? parseISO(r.createdAt) else { return 0 }
    return -s.timeIntervalSinceNow
}

func estimatedTotal(for run: Run, history: [Run]) -> TimeInterval? {
    let wf = run.workflowName ?? run.name
    let completed = history.filter { ($0.workflowName ?? $0.name) == wf && $0.status == "completed" }
    let durs = completed.compactMap { r -> TimeInterval? in
        guard let s = parseISO(r.startedAt) ?? parseISO(r.createdAt),
              let e = parseISO(r.updatedAt) else { return nil }
        let d = e.timeIntervalSince(s); return d > 0 ? d : nil
    }
    guard !durs.isEmpty else { return nil }
    return durs.reduce(0, +) / Double(durs.count)
}

func sfName(_ r: Run) -> String {
    switch r.status {
    case "in_progress": return "hourglass.circle.fill"
    case "queued", "waiting", "pending": return "clock.fill"
    case "completed":
        switch r.conclusion ?? "" {
        case "success": return "checkmark.circle.fill"
        case "failure": return "xmark.circle.fill"
        case "cancelled": return "minus.circle.fill"
        case "skipped": return "forward.fill"
        default: return "questionmark.circle"
        }
    default: return "questionmark.circle"
    }
}

func sfColor(_ r: Run) -> NSColor {
    switch r.status {
    case "in_progress": return .systemOrange
    case "queued", "waiting", "pending": return .systemYellow
    case "completed":
        switch r.conclusion ?? "" {
        case "success": return .systemGreen
        case "failure": return .systemRed
        default: return .systemGray
        }
    default: return .secondaryLabelColor
    }
}

func overallColor(_ g: [(String, [Run])]) -> NSColor {
    let all = g.flatMap { $0.1 }
    if all.isEmpty { return .secondaryLabelColor }
    if all.contains(where: { $0.status == "in_progress" || $0.status == "queued" }) { return .systemOrange }
    let key = all.filter {
        let wf = ($0.workflowName ?? $0.name).lowercased()
        return wf.contains("deploy") || wf.contains("smoke")
    }
    if let top = (key.isEmpty ? all : key).first, top.conclusion == "failure" { return .systemRed }
    return .systemGreen
}

func hasActive(_ g: [(String, [Run])]) -> Bool {
    g.flatMap { $0.1 }.contains { $0.status == "in_progress" || $0.status == "queued" }
}

// ─── Icon ────────────────────────────────────────────────────────────────────

func loadGHIcon() -> NSImage? {
    guard let data = Data(base64Encoded: GH_ICON_B64), let img = NSImage(data: data) else { return nil }
    img.isTemplate = true
    img.size = NSSize(width: 18, height: 18)
    return img
}

func tintedIcon(_ base: NSImage?, _ color: NSColor) -> NSImage {
    guard let base = base else { return NSImage() }
    let img = NSImage(size: base.size, flipped: false) { rect in
        base.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    img.isTemplate = false
    return img
}

// ─── Run Row View ────────────────────────────────────────────────────────────

class RunRow: NSView {
    let urlStr: String
    var trackingArea: NSTrackingArea?

    init(_ run: Run, history: [Run], w: CGFloat) {
        self.urlStr = run.url
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: ROW_H))
        wantsLayer = true
        build(run, history: history, w: w)
    }
    required init?(coder: NSCoder) { fatalError() }

    func build(_ run: Run, history: [Run], w: CGFloat) {
        let pad: CGFloat = 12, iconSz: CGFloat = 20
        let textX = pad + iconSz + 10, copyW: CGFloat = 28, rightZone: CGFloat = 160
        let textW = w - textX - rightZone - copyW

        let iv = NSImageView(frame: NSRect(x: pad, y: (ROW_H - iconSz) / 2, width: iconSz, height: iconSz))
        if let img = NSImage(systemSymbolName: sfName(run), accessibilityDescription: nil) {
            iv.image = img; iv.contentTintColor = sfColor(run)
            iv.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        }
        addSubview(iv)

        let title = lbl(String(run.displayTitle.prefix(70)), .systemFont(ofSize: 12.5, weight: .semibold))
        title.frame = NSRect(x: textX, y: ROW_H - 24, width: textW, height: 18)
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        let wf = run.workflowName ?? run.name
        let sub = lbl("\(wf) #\(run.number) \u{00B7} \(run.event)", .systemFont(ofSize: 11), .secondaryLabelColor)
        sub.frame = NSRect(x: textX, y: 6, width: textW, height: 16)
        sub.lineBreakMode = .byTruncatingTail
        addSubview(sub)

        let badge = Badge(String(run.headBranch.prefix(20)))
        badge.frame.origin = NSPoint(x: w - rightZone - copyW, y: ROW_H / 2 + 2)
        addSubview(badge)

        let rX = badge.frame.maxX + 6, rW = w - rX - copyW - 4

        if run.status == "in_progress" || run.status == "queued" {
            let elapsed = runElapsed(run)
            let el = lbl("\(fmtDuration(elapsed)) elapsed", .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium), .systemOrange)
            el.alignment = .right; el.frame = NSRect(x: rX, y: ROW_H - 23, width: rW, height: 14)
            addSubview(el)
            var etaText = "estimating..."
            if let est = estimatedTotal(for: run, history: history) {
                let rem = max(0, est - elapsed)
                etaText = rem > 0 ? "~\(fmtDuration(rem)) remaining" : "finishing..."
            }
            let eta = lbl(etaText, .systemFont(ofSize: 10), .tertiaryLabelColor)
            eta.alignment = .right; eta.frame = NSRect(x: rX, y: 6, width: rW, height: 14)
            addSubview(eta)
        } else {
            let ts = lbl(fmtTimestamp(run.updatedAt), .systemFont(ofSize: 10.5), .secondaryLabelColor)
            ts.alignment = .right; ts.frame = NSRect(x: rX, y: ROW_H - 23, width: rW, height: 14)
            addSubview(ts)
            let dur = lbl("\u{23F1} \(runDuration(run))", .systemFont(ofSize: 10), .tertiaryLabelColor)
            dur.alignment = .right; dur.frame = NSRect(x: rX, y: 6, width: rW, height: 14)
            addSubview(dur)
        }

        let cp = NSButton(frame: NSRect(x: w - copyW - 4, y: (ROW_H - 24) / 2, width: copyW, height: 24))
        if let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy URL") { cp.image = img }
        cp.bezelStyle = .recessed; cp.isBordered = false; cp.imagePosition = .imageOnly
        cp.target = self; cp.action = #selector(copyURL(_:)); cp.toolTip = "Copy run URL"
        addSubview(cp)

        let sep = NSView(frame: NSRect(x: textX, y: 0, width: w - textX - pad, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep)
    }

    func lbl(_ text: String, _ font: NSFont, _ color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font; l.textColor = color; l.maximumNumberOfLines = 1
        l.cell?.truncatesLastVisibleLine = true; return l
    }

    @objc func copyURL(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlStr, forType: .string)
        if let btn = sender as? NSButton,
           let img = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) {
            let orig = btn.image; btn.image = img; btn.contentTintColor = .systemGreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { btn.image = orig; btn.contentTintColor = nil }
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }
    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15).cgColor
    }
    override func mouseExited(with event: NSEvent) { layer?.backgroundColor = nil }
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).cgColor
    }
    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = nil
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else { return }
        for sub in subviews where sub is NSButton { if sub.frame.contains(loc) { return } }
        if let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
    }
}

// ─── Shared Views ────────────────────────────────────────────────────────────

class Badge: NSView {
    let text: String
    init(_ text: String) {
        self.text = text
        let a: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)]
        let sz = (text as NSString).size(withAttributes: a)
        super.init(frame: NSRect(x: 0, y: 0, width: sz.width + 14, height: 20))
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 0.5, dy: 0.5)
        let p = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
        NSColor.controlBackgroundColor.withAlphaComponent(0.85).setFill(); p.fill()
        NSColor.separatorColor.setStroke(); p.lineWidth = 0.5; p.stroke()
        let a: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]
        let sz = (text as NSString).size(withAttributes: a)
        (text as NSString).draw(at: NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2), withAttributes: a)
    }
}

class Header: NSView {
    init(_ repo: String, w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: HDR_H))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let short = repo.components(separatedBy: "/").last ?? repo
        let l = NSTextField(labelWithString: short.uppercased())
        l.font = .systemFont(ofSize: 11, weight: .bold); l.textColor = .secondaryLabelColor
        l.frame = NSRect(x: 12, y: 6, width: w - 130, height: 20)
        addSubview(l)
        let link = NSTextField(labelWithString: "Open Actions \u{2197}")
        link.font = .systemFont(ofSize: 10, weight: .medium); link.textColor = .linkColor
        link.frame = NSRect(x: w - 105, y: 8, width: 93, height: 16); link.alignment = .right
        addSubview(link)
        let click = Clicker("https://github.com/\(repo)/actions")
        click.frame = NSRect(x: w - 110, y: 0, width: 110, height: HDR_H)
        addSubview(click)
    }
    required init?(coder: NSCoder) { fatalError() }
}

class Clicker: NSView {
    let url: String
    init(_ url: String) { self.url = url; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

class EmptyRow: NSView {
    init(_ text: String, w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: 36))
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 12); l.textColor = .tertiaryLabelColor
        l.frame = NSRect(x: 42, y: 8, width: w - 54, height: 20)
        addSubview(l)
    }
    required init?(coder: NSCoder) { fatalError() }
}

class Flipped: NSView { override var isFlipped: Bool { true } }

// ─── Footer ──────────────────────────────────────────────────────────────────

class Footer: NSView {
    init(_ w: CGFloat, updated: Date) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: FTR_H))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let sep = NSView(frame: NSRect(x: 0, y: FTR_H - 0.5, width: w, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep)

        let rb = NSButton(title: "\u{21BB} Refresh", target: NSApp.delegate, action: #selector(GHActionsBar.doRefresh))
        rb.bezelStyle = .inline; rb.font = .systemFont(ofSize: 11)
        rb.frame = NSRect(x: 8, y: 8, width: 80, height: 24)
        addSubview(rb)

        let f = DateFormatter(); f.dateFormat = "h:mm:ss a"
        let ts = NSTextField(labelWithString: "Updated \(f.string(from: updated))")
        ts.font = .systemFont(ofSize: 10); ts.textColor = .tertiaryLabelColor; ts.alignment = .center
        ts.frame = NSRect(x: 90, y: 11, width: w - 230, height: 16)
        addSubview(ts)

        // Settings gear
        let gear = NSButton(frame: NSRect(x: w - 100, y: 8, width: 36, height: 24))
        if let img = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings") { gear.image = img }
        gear.bezelStyle = .inline; gear.imagePosition = .imageOnly
        gear.target = NSApp.delegate; gear.action = #selector(GHActionsBar.showSettings)
        gear.toolTip = "Settings"
        addSubview(gear)

        let qb = NSButton(title: "Quit", target: NSApp.delegate, action: #selector(GHActionsBar.quitApp))
        qb.bezelStyle = .inline; qb.font = .systemFont(ofSize: 11)
        qb.frame = NSRect(x: w - 56, y: 8, width: 48, height: 24)
        addSubview(qb)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// ─── List View ───────────────────────────────────────────────────────────────

class ListVC: NSViewController {
    let grouped: [(String, [Run])]
    let updated: Date
    let loading: Bool

    init(_ grouped: [(String, [Run])], updated: Date, loading: Bool) {
        self.grouped = grouped; self.updated = updated; self.loading = loading
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let w = POP_W
        var rows: [NSView] = []

        if REPOS.isEmpty {
            rows.append(EmptyRow("No repos configured. Open Settings to get started.", w: w))
        } else if loading && grouped.isEmpty {
            rows.append(EmptyRow("Loading actions...", w: w))
        } else {
            for (repo, runs) in grouped {
                rows.append(Header(repo, w: w))
                if runs.isEmpty { rows.append(EmptyRow("No recent runs", w: w)) }
                else { for run in runs { rows.append(RunRow(run, history: runs, w: w)) } }
            }
        }
        rows.append(Footer(w, updated: updated))

        let totalH = rows.reduce(0) { $0 + $1.frame.height }
        let doc = Flipped(frame: NSRect(x: 0, y: 0, width: w, height: totalH))
        doc.wantsLayer = true
        doc.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
        var y: CGFloat = 0
        for row in rows { row.frame.origin = NSPoint(x: 0, y: y); doc.addSubview(row); y += row.frame.height }

        let visH = min(totalH, POP_MAX_H)
        let sv = NSScrollView(frame: NSRect(x: 0, y: 0, width: w, height: visH))
        sv.hasVerticalScroller = true; sv.drawsBackground = false
        sv.documentView = doc; sv.autohidesScrollers = true
        self.view = sv
        self.preferredContentSize = NSSize(width: w, height: visH)
    }
}

// ─── Settings View ───────────────────────────────────────────────────────────

class SettingsVC: NSViewController {
    var selected: Set<String>
    var available: [String] = []
    var username: String?
    var checkboxes: [NSButton] = []
    var repoScroll: NSScrollView?
    var repoDoc: Flipped?
    var statusLabel: NSTextField?
    var addField: NSTextField?
    var loadingLabel: NSTextField?

    init(current: Set<String>) {
        self.selected = current
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let w = POP_W
        let container = Flipped(frame: NSRect(x: 0, y: 0, width: w, height: 500))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.65).cgColor
        var y: CGFloat = 0

        // ── Nav bar ──
        let nav = NSView(frame: NSRect(x: 0, y: 0, width: w, height: 44))
        nav.wantsLayer = true; nav.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let back = NSButton(title: "\u{2190} Back", target: NSApp.delegate, action: #selector(GHActionsBar.showList))
        back.bezelStyle = .inline; back.font = .systemFont(ofSize: 12)
        back.frame = NSRect(x: 8, y: 10, width: 70, height: 24)
        nav.addSubview(back)
        let tl = NSTextField(labelWithString: "SETTINGS")
        tl.font = .systemFont(ofSize: 13, weight: .bold); tl.textColor = .labelColor; tl.alignment = .center
        tl.frame = NSRect(x: 80, y: 12, width: w - 160, height: 20)
        nav.addSubview(tl)
        container.addSubview(nav); y += 44

        // ── Separator ──
        let s1 = sepLine(y: y, w: w); container.addSubview(s1); y += 0.5

        // ── Account section ──
        let accHdr = sectionHeader("GITHUB ACCOUNT", y: y, w: w)
        container.addSubview(accHdr); y += 28

        let accRow = NSView(frame: NSRect(x: 0, y: y, width: w, height: 40))
        let sl = NSTextField(labelWithString: "Checking...")
        sl.font = .systemFont(ofSize: 12); sl.textColor = .secondaryLabelColor
        sl.frame = NSRect(x: 16, y: 10, width: w - 180, height: 20)
        accRow.addSubview(sl)
        statusLabel = sl

        let loginBtn = NSButton(title: "Login...", target: self, action: #selector(doLogin))
        loginBtn.bezelStyle = .inline; loginBtn.font = .systemFont(ofSize: 11)
        loginBtn.frame = NSRect(x: w - 160, y: 10, width: 64, height: 24)
        loginBtn.tag = 1
        accRow.addSubview(loginBtn)

        let logoutBtn = NSButton(title: "Logout", target: self, action: #selector(doLogout))
        logoutBtn.bezelStyle = .inline; logoutBtn.font = .systemFont(ofSize: 11)
        logoutBtn.frame = NSRect(x: w - 88, y: 10, width: 64, height: 24)
        logoutBtn.tag = 2
        accRow.addSubview(logoutBtn)

        container.addSubview(accRow); y += 40
        let s2 = sepLine(y: y, w: w); container.addSubview(s2); y += 0.5

        // ── Repos section ──
        let repoHdr = sectionHeader("SELECT REPOS TO TRACK", y: y, w: w)
        let refreshBtn = NSButton(title: "\u{21BB} Refresh", target: self, action: #selector(fetchRepos))
        refreshBtn.bezelStyle = .inline; refreshBtn.font = .systemFont(ofSize: 10)
        refreshBtn.frame = NSRect(x: w - 80, y: 6, width: 68, height: 20)
        repoHdr.addSubview(refreshBtn)
        container.addSubview(repoHdr); y += 28

        let ll = NSTextField(labelWithString: "Loading repos...")
        ll.font = .systemFont(ofSize: 11); ll.textColor = .tertiaryLabelColor
        ll.frame = NSRect(x: 16, y: y + 8, width: 200, height: 16)
        container.addSubview(ll)
        loadingLabel = ll

        let scrollH: CGFloat = 260
        let rd = Flipped(frame: NSRect(x: 0, y: 0, width: w, height: scrollH))
        let rs = NSScrollView(frame: NSRect(x: 0, y: y, width: w, height: scrollH))
        rs.hasVerticalScroller = true; rs.drawsBackground = false
        rs.documentView = rd; rs.autohidesScrollers = true
        container.addSubview(rs)
        repoScroll = rs; repoDoc = rd
        y += scrollH

        let s3 = sepLine(y: y, w: w); container.addSubview(s3); y += 0.5

        // ── Add repo manually ──
        let addHdr = sectionHeader("ADD REPO MANUALLY", y: y, w: w)
        container.addSubview(addHdr); y += 28

        let addRow = NSView(frame: NSRect(x: 0, y: y, width: w, height: 36))
        let tf = NSTextField(frame: NSRect(x: 16, y: 6, width: w - 110, height: 24))
        tf.placeholderString = "owner/repo"
        tf.font = .systemFont(ofSize: 12)
        addRow.addSubview(tf)
        addField = tf
        let addBtn = NSButton(title: "Add", target: self, action: #selector(addManualRepo))
        addBtn.bezelStyle = .inline; addBtn.font = .systemFont(ofSize: 11)
        addBtn.frame = NSRect(x: w - 80, y: 6, width: 56, height: 24)
        addRow.addSubview(addBtn)
        container.addSubview(addRow); y += 36

        let s4 = sepLine(y: y, w: w); container.addSubview(s4); y += 0.5

        // ── Save button ──
        let saveRow = NSView(frame: NSRect(x: 0, y: y, width: w, height: 48))
        saveRow.wantsLayer = true; saveRow.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let saveBtn = NSButton(title: "Save & Apply", target: self, action: #selector(doSave))
        saveBtn.bezelStyle = .inline; saveBtn.font = .systemFont(ofSize: 12, weight: .semibold)
        saveBtn.frame = NSRect(x: w / 2 - 60, y: 12, width: 120, height: 28)
        saveRow.addSubview(saveBtn)
        container.addSubview(saveRow); y += 48

        container.frame.size.height = y
        self.view = container
        self.preferredContentSize = NSSize(width: w, height: min(y, POP_MAX_H))

        // Load data in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let user = getGHUser()
            let repos = fetchAvailableRepos()
            DispatchQueue.main.async {
                self?.username = user
                self?.available = repos
                self?.updateAuthUI()
                self?.rebuildRepoList()
            }
        }
    }

    func sectionHeader(_ title: String, y: CGFloat, w: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: y, width: w, height: 28))
        v.wantsLayer = true; v.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7).cgColor
        let l = NSTextField(labelWithString: title)
        l.font = .systemFont(ofSize: 10, weight: .bold); l.textColor = .secondaryLabelColor
        l.frame = NSRect(x: 16, y: 6, width: w - 100, height: 16)
        v.addSubview(l)
        return v
    }

    func sepLine(y: CGFloat, w: CGFloat) -> NSView {
        let v = NSView(frame: NSRect(x: 0, y: y, width: w, height: 0.5))
        v.wantsLayer = true; v.layer?.backgroundColor = NSColor.separatorColor.cgColor
        return v
    }

    func updateAuthUI() {
        if let user = username {
            statusLabel?.stringValue = "\u{2705}  Logged in as \(user)"
            statusLabel?.textColor = .labelColor
        } else {
            statusLabel?.stringValue = "\u{274C}  Not authenticated"
            statusLabel?.textColor = .systemRed
        }
    }

    func rebuildRepoList() {
        guard let doc = repoDoc else { return }
        loadingLabel?.isHidden = true
        doc.subviews.forEach { $0.removeFromSuperview() }
        checkboxes = []

        // Merge available repos with currently selected (in case some aren't in the fetched list)
        var allRepos = available
        for r in selected { if !allRepos.contains(r) { allRepos.append(r) } }

        let rowH: CGFloat = 26
        var y: CGFloat = 4
        for repo in allRepos {
            let cb = NSButton(checkboxWithTitle: "  \(repo)", target: self, action: #selector(toggleRepo(_:)))
            cb.font = .systemFont(ofSize: 12)
            cb.state = selected.contains(repo) ? .on : .off
            cb.frame = NSRect(x: 12, y: y, width: POP_W - 24, height: rowH)
            cb.identifier = NSUserInterfaceItemIdentifier(repo)
            doc.addSubview(cb)
            checkboxes.append(cb)
            y += rowH
        }

        if allRepos.isEmpty {
            let l = NSTextField(labelWithString: username == nil ? "Login to see your repos" : "No repos found")
            l.font = .systemFont(ofSize: 12); l.textColor = .tertiaryLabelColor
            l.frame = NSRect(x: 16, y: 8, width: 300, height: 20)
            doc.addSubview(l)
            y = 36
        }

        doc.frame.size.height = max(y + 4, repoScroll?.frame.height ?? 260)
    }

    @objc func toggleRepo(_ sender: NSButton) {
        guard let repo = sender.identifier?.rawValue else { return }
        if sender.state == .on { selected.insert(repo) } else { selected.remove(repo) }
    }

    @objc func addManualRepo() {
        guard let text = addField?.stringValue.trimmingCharacters(in: .whitespaces),
              !text.isEmpty, text.contains("/") else { return }
        selected.insert(text)
        if !available.contains(text) { available.append(text) }
        addField?.stringValue = ""
        rebuildRepoList()
    }

    @objc func fetchRepos() {
        loadingLabel?.isHidden = false
        loadingLabel?.stringValue = "Refreshing..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let user = getGHUser()
            let repos = fetchAvailableRepos()
            DispatchQueue.main.async {
                self?.username = user
                self?.available = repos
                self?.updateAuthUI()
                self?.rebuildRepoList()
            }
        }
    }

    @objc func doLogin() {
        let script = "tell application \"Terminal\" to do script \"gh auth login --web -p https\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    @objc func doLogout() {
        let script = "tell application \"Terminal\" to do script \"gh auth logout\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
    }

    @objc func doSave() {
        let repos = Array(selected).sorted()
        saveConfig(repos: repos)
        (NSApp.delegate as? GHActionsBar)?.onConfigSaved()
    }
}

// ─── App ─────────────────────────────────────────────────────────────────────

class GHActionsBar: NSObject, NSApplicationDelegate, NSPopoverDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var timer: Timer?
    var animTimer: Timer?
    var animPhase: CGFloat = 0
    var grouped: [(String, [Run])] = []
    var lastUpdate = Date()
    var closeTime = Date.distantPast
    var firstLoad = true
    var ghIcon: NSImage?
    var prevStatuses: [String: String] = [:]

    func applicationDidFinishLaunching(_ note: Notification) {
        loadConfig()
        ghIcon = loadGHIcon()

        let nc = UNUserNotificationCenter.current()
        nc.delegate = self
        nc.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = tintedIcon(ghIcon, .secondaryLabelColor)
            btn.imagePosition = .imageOnly
            btn.target = self
            btn.action = #selector(toggle)
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        if REPOS.isEmpty {
            // First run: open popover with settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.closeTime = .distantPast
                self.showSettings()
                self.toggle()
            }
        } else {
            refresh()
        }
        scheduleTimer()
    }

    // MARK: - Polling

    func scheduleTimer() {
        timer?.invalidate()
        guard !REPOS.isEmpty else { return }
        let interval = hasActive(grouped) ? POLL_ACTIVE : POLL_NORMAL
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh(completion: (() -> Void)? = nil) {
        guard !REPOS.isEmpty else { completion?(); return }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var res = Array(repeating: (String, [Run])("", []), count: REPOS.count)
            let group = DispatchGroup()
            for (i, repo) in REPOS.enumerated() {
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    res[i] = (repo, fetchRuns(repo: repo))
                    group.leave()
                }
            }
            group.wait()
            DispatchQueue.main.async {
                self.detectTransitions(res)
                self.grouped = res
                self.lastUpdate = Date()
                self.firstLoad = false
                self.updateIcon()
                self.scheduleTimer()
                completion?()
            }
        }
    }

    func onConfigSaved() {
        prevStatuses = [:]
        firstLoad = true
        grouped = []
        popover.close()
        refresh { [weak self] in
            guard let self = self else { return }
            self.closeTime = .distantPast
            self.toggle()
        }
    }

    // MARK: - Icon

    func updateIcon() {
        let color = overallColor(grouped)
        let active = hasActive(grouped)
        if active { startAnimation(color) }
        else {
            stopAnimation()
            statusItem.button?.image = tintedIcon(ghIcon, color)
            statusItem.button?.alphaValue = 1.0
        }
    }

    func startAnimation(_ color: NSColor) {
        statusItem.button?.image = tintedIcon(ghIcon, color)
        guard animTimer == nil else { return }
        animPhase = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, let btn = self.statusItem.button else { return }
            self.animPhase += 0.06
            btn.alphaValue = CGFloat(0.45 + 0.55 * (0.5 + 0.5 * sin(self.animPhase * 3.0)))
        }
    }

    func stopAnimation() { animTimer?.invalidate(); animTimer = nil }

    // MARK: - Notifications

    func detectTransitions(_ newGrouped: [(String, [Run])]) {
        guard !firstLoad else {
            for run in newGrouped.flatMap({ $0.1 }) { prevStatuses[run.url] = run.status }
            return
        }
        let newRuns = newGrouped.flatMap { $0.1 }
        for run in newRuns {
            let old = prevStatuses[run.url]
            let wf = run.workflowName ?? run.name
            if run.status == "in_progress" && old != "in_progress" {
                notify(title: "\u{25B6}\u{FE0F} Action Started", body: "\(wf) on \(run.headBranch)", id: "start-\(run.url)")
            }
            if run.status == "completed" && (old == "in_progress" || old == "queued") {
                let ok = run.conclusion == "success"
                notify(title: ok ? "\u{2705} Action Passed" : "\u{274C} Action Failed",
                       body: "\(wf) on \(run.headBranch) \u{2014} \(runDuration(run))", id: "end-\(run.url)")
            }
        }
        prevStatuses = [:]; for run in newRuns { prevStatuses[run.url] = run.status }
    }

    func notify(title: String, body: String, id: String) {
        let c = UNMutableNotificationContent(); c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        DispatchQueue.main.async { self.closeTime = .distantPast; self.toggle() }
        handler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    // MARK: - Popover

    @objc func toggle() {
        if popover.isShown { popover.close() }
        else if Date().timeIntervalSince(closeTime) > 0.3 {
            if popover.contentViewController == nil || popover.contentViewController is ListVC {
                popover.contentViewController = ListVC(grouped, updated: lastUpdate, loading: firstLoad)
            }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
    }

    @objc func showSettings() {
        popover.contentViewController = SettingsVC(current: Set(REPOS))
        if !popover.isShown {
            closeTime = .distantPast
            toggle()
        }
    }

    @objc func showList() {
        popover.contentViewController = ListVC(grouped, updated: lastUpdate, loading: firstLoad)
    }

    @objc func doRefresh() {
        popover.close()
        refresh { [weak self] in
            guard let self = self else { return }
            self.closeTime = .distantPast
            self.toggle()
        }
    }

    @objc func quitApp() { NSApp.terminate(nil) }

    func popoverDidClose(_ notification: Notification) {
        closeTime = Date()
        popover.contentViewController = nil  // Release settings view if open
    }
}

// ─── Main ────────────────────────────────────────────────────────────────────

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = GHActionsBar()
app.delegate = delegate
app.run()
