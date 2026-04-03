import Cocoa
import UserNotifications

// ─── Configuration ───────────────────────────────────────────────────────────

struct AppConfig: Decodable {
    let repos: [String]
    var pollInterval: TimeInterval?
    var pollActiveInterval: TimeInterval?
    var runsPerRepo: Int?
}

let CONFIG_DIR  = NSString(string: "~/.config/gh-actions-bar").expandingTildeInPath
let CONFIG_PATH = (CONFIG_DIR as NSString).appendingPathComponent("config.json")

let config: AppConfig = {
    if let data = FileManager.default.contents(atPath: CONFIG_PATH),
       let c = try? JSONDecoder().decode(AppConfig.self, from: data) { return c }
    // First run — create a sample config
    try? FileManager.default.createDirectory(atPath: CONFIG_DIR, withIntermediateDirectories: true)
    let sample = """
    {
        "repos": ["owner/repo1", "owner/repo2"],
        "pollInterval": 30,
        "pollActiveInterval": 10,
        "runsPerRepo": 10
    }
    """
    try? sample.write(toFile: CONFIG_PATH, atomically: true, encoding: .utf8)
    return AppConfig(repos: [])
}()

let REPOS       = config.repos
let POLL_NORMAL = config.pollInterval ?? 30
let POLL_ACTIVE = config.pollActiveInterval ?? 10
let RUNS_PER_REPO = config.runsPerRepo ?? 10
let GH = "/opt/homebrew/bin/gh"
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

func fetchRuns(repo: String) -> [Run] {
    let fields = "name,displayTitle,status,conclusion,headBranch,event,url,updatedAt,createdAt,startedAt,number,workflowName"
    guard let data = ghShell("run", "list", "--repo", repo, "--limit", "\(RUNS_PER_REPO)", "--json", fields)
    else { return [] }
    return (try? JSONDecoder().decode([Run].self, from: data)) ?? []
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
        let pad: CGFloat = 12
        let iconSz: CGFloat = 20
        let textX = pad + iconSz + 10
        let copyW: CGFloat = 28
        let rightZone: CGFloat = 160
        let textW = w - textX - rightZone - copyW

        // Status icon
        let iv = NSImageView(frame: NSRect(x: pad, y: (ROW_H - iconSz) / 2, width: iconSz, height: iconSz))
        if let img = NSImage(systemSymbolName: sfName(run), accessibilityDescription: nil) {
            iv.image = img
            iv.contentTintColor = sfColor(run)
            iv.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        }
        addSubview(iv)

        // Title
        let title = lbl(String(run.displayTitle.prefix(70)), .systemFont(ofSize: 12.5, weight: .semibold))
        title.frame = NSRect(x: textX, y: ROW_H - 24, width: textW, height: 18)
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        // Subtitle
        let wf = run.workflowName ?? run.name
        let sub = lbl("\(wf) #\(run.number) \u{00B7} \(run.event)", .systemFont(ofSize: 11), .secondaryLabelColor)
        sub.frame = NSRect(x: textX, y: 6, width: textW, height: 16)
        sub.lineBreakMode = .byTruncatingTail
        addSubview(sub)

        // Branch badge
        let badge = Badge(String(run.headBranch.prefix(20)))
        badge.frame.origin = NSPoint(x: w - rightZone - copyW, y: ROW_H / 2 + 2)
        addSubview(badge)

        let rX = badge.frame.maxX + 6
        let rW = w - rX - copyW - 4

        if run.status == "in_progress" || run.status == "queued" {
            let elapsed = runElapsed(run)
            let el = lbl("\(fmtDuration(elapsed)) elapsed", .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium), .systemOrange)
            el.alignment = .right
            el.frame = NSRect(x: rX, y: ROW_H - 23, width: rW, height: 14)
            addSubview(el)

            var etaText = "estimating..."
            if let est = estimatedTotal(for: run, history: history) {
                let rem = max(0, est - elapsed)
                etaText = rem > 0 ? "~\(fmtDuration(rem)) remaining" : "finishing..."
            }
            let eta = lbl(etaText, .systemFont(ofSize: 10), .tertiaryLabelColor)
            eta.alignment = .right
            eta.frame = NSRect(x: rX, y: 6, width: rW, height: 14)
            addSubview(eta)
        } else {
            let ts = lbl(fmtTimestamp(run.updatedAt), .systemFont(ofSize: 10.5), .secondaryLabelColor)
            ts.alignment = .right
            ts.frame = NSRect(x: rX, y: ROW_H - 23, width: rW, height: 14)
            addSubview(ts)

            let dur = lbl("\u{23F1} \(runDuration(run))", .systemFont(ofSize: 10), .tertiaryLabelColor)
            dur.alignment = .right
            dur.frame = NSRect(x: rX, y: 6, width: rW, height: 14)
            addSubview(dur)
        }

        // Copy URL button
        let cp = NSButton(frame: NSRect(x: w - copyW - 4, y: (ROW_H - 24) / 2, width: copyW, height: 24))
        if let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy URL") {
            cp.image = img
        }
        cp.bezelStyle = .recessed
        cp.isBordered = false
        cp.imagePosition = .imageOnly
        cp.target = self
        cp.action = #selector(copyURL(_:))
        cp.toolTip = "Copy run URL"
        addSubview(cp)

        // Separator
        let sep = NSView(frame: NSRect(x: textX, y: 0, width: w - textX - pad, height: 0.5))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep)
    }

    func lbl(_ text: String, _ font: NSFont, _ color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font; l.textColor = color; l.maximumNumberOfLines = 1
        l.cell?.truncatesLastVisibleLine = true
        return l
    }

    @objc func copyURL(_ sender: Any?) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlStr, forType: .string)
        if let btn = sender as? NSButton,
           let img = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil) {
            let orig = btn.image
            btn.image = img; btn.contentTintColor = .systemGreen
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                btn.image = orig; btn.contentTintColor = nil
            }
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
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
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

// ─── Branch Badge ────────────────────────────────────────────────────────────

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

// ─── Section Header ──────────────────────────────────────────────────────────

class Header: NSView {
    init(_ repo: String, w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: HDR_H))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
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

// ─── Empty / Loading ─────────────────────────────────────────────────────────

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

// ─── Footer ──────────────────────────────────────────────────────────────────

class Footer: NSView {
    init(_ w: CGFloat, updated: Date) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: FTR_H))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
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
        ts.frame = NSRect(x: 90, y: 11, width: w - 180, height: 16)
        addSubview(ts)
        let qb = NSButton(title: "Quit", target: NSApp.delegate, action: #selector(GHActionsBar.quitApp))
        qb.bezelStyle = .inline; qb.font = .systemFont(ofSize: 11)
        qb.frame = NSRect(x: w - 56, y: 8, width: 48, height: 24)
        addSubview(qb)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// ─── Flipped View ────────────────────────────────────────────────────────────

class Flipped: NSView { override var isFlipped: Bool { true } }

// ─── Popover Content ─────────────────────────────────────────────────────────

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
            rows.append(EmptyRow("No repos configured.", w: w))
            rows.append(EmptyRow("Edit ~/.config/gh-actions-bar/config.json", w: w))
        } else if loading && grouped.isEmpty {
            rows.append(EmptyRow("Loading actions...", w: w))
        } else {
            for (repo, runs) in grouped {
                rows.append(Header(repo, w: w))
                if runs.isEmpty {
                    rows.append(EmptyRow("No recent runs", w: w))
                } else {
                    for run in runs {
                        rows.append(RunRow(run, history: runs, w: w))
                    }
                }
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
        sv.hasVerticalScroller = true
        sv.drawsBackground = false
        sv.documentView = doc
        sv.autohidesScrollers = true
        self.view = sv
        self.preferredContentSize = NSSize(width: w, height: visH)
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
    var prevStatuses: [String: String] = [:]  // run url -> status

    func applicationDidFinishLaunching(_ note: Notification) {
        ghIcon = loadGHIcon()

        // Request notification permission
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

        refresh()
        scheduleTimer()
    }

    // MARK: - Polling

    func scheduleTimer() {
        timer?.invalidate()
        let interval = hasActive(grouped) ? POLL_ACTIVE : POLL_NORMAL
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh(completion: (() -> Void)? = nil) {
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

    // MARK: - Icon (tint + animation)

    func updateIcon() {
        let color = overallColor(grouped)
        let active = hasActive(grouped)

        if active {
            startAnimation(color)
        } else {
            stopAnimation()
            statusItem.button?.image = tintedIcon(ghIcon, color)
            statusItem.button?.alphaValue = 1.0
        }
    }

    func startAnimation(_ color: NSColor) {
        // Set base icon color
        statusItem.button?.image = tintedIcon(ghIcon, color)
        guard animTimer == nil else { return }
        animPhase = 0
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, let btn = self.statusItem.button else { return }
            self.animPhase += 0.06
            let alpha = 0.45 + 0.55 * (0.5 + 0.5 * sin(self.animPhase * 3.0))
            btn.alphaValue = CGFloat(alpha)
        }
    }

    func stopAnimation() {
        animTimer?.invalidate()
        animTimer = nil
    }

    // MARK: - Notifications

    func detectTransitions(_ newGrouped: [(String, [Run])]) {
        guard !firstLoad else {
            // First load: just record state, don't notify
            for run in newGrouped.flatMap({ $0.1 }) {
                prevStatuses[run.url] = run.status
            }
            return
        }

        let newRuns = newGrouped.flatMap { $0.1 }
        for run in newRuns {
            let old = prevStatuses[run.url]
            let wf = run.workflowName ?? run.name

            // Started: wasn't in_progress before, now is
            if run.status == "in_progress" && old != "in_progress" {
                notify(
                    title: "\u{25B6}\u{FE0F} Action Started",
                    body: "\(wf) on \(run.headBranch)",
                    id: "start-\(run.url)"
                )
            }

            // Completed: was in_progress or queued, now completed
            if run.status == "completed" && (old == "in_progress" || old == "queued") {
                let ok = run.conclusion == "success"
                notify(
                    title: ok ? "\u{2705} Action Passed" : "\u{274C} Action Failed",
                    body: "\(wf) on \(run.headBranch) \u{2014} \(runDuration(run))",
                    id: "end-\(run.url)"
                )
            }
        }

        // Rebuild state
        prevStatuses = [:]
        for run in newRuns { prevStatuses[run.url] = run.status }
    }

    func notify(title: String, body: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    // Notification clicked → open popover
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler handler: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.closeTime = .distantPast
            self.toggle()
        }
        handler()
    }

    // Show notifications even when app is frontmost
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }

    // MARK: - Popover

    @objc func toggle() {
        if popover.isShown {
            popover.close()
        } else if Date().timeIntervalSince(closeTime) > 0.3 {
            popover.contentViewController = ListVC(grouped, updated: lastUpdate, loading: firstLoad)
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
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

    func popoverDidClose(_ notification: Notification) { closeTime = Date() }
}

// ─── Main ────────────────────────────────────────────────────────────────────

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = GHActionsBar()
app.delegate = delegate
app.run()
