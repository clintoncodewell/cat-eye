import Cocoa
import UserNotifications
import os

// ─── Configuration ───────────────────────────────────────────────────────────

struct AppConfig: Codable {
    var repos: [String]
    var pollInterval: TimeInterval?
    var pollActiveInterval: TimeInterval?
    var runsPerRepo: Int?
    var filterDefaultBranches: Bool?
}

let CONFIG_DIR  = NSString(string: "~/.config/cat-eye").expandingTildeInPath
let CONFIG_PATH = (CONFIG_DIR as NSString).appendingPathComponent("config.json")

var REPOS: [String] = []
var POLL_NORMAL: TimeInterval = 30
var POLL_ACTIVE: TimeInterval = 10
var RUNS_PER_REPO: Int = 10
var FILTER_DEFAULT_BRANCHES: Bool = false
let DEFAULT_BRANCHES: Set<String> = ["main", "develop"]

let repoPattern = try! NSRegularExpression(pattern: "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$")

let log = Logger(subsystem: "com.clintoncodewell.cat-eye", category: "app")

func isValidRepo(_ s: String) -> Bool {
    repoPattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
}

func loadConfig() {
    guard let data = FileManager.default.contents(atPath: CONFIG_PATH),
          let c = try? JSONDecoder().decode(AppConfig.self, from: data) else { return }
    REPOS = c.repos.filter { isValidRepo($0) }
    POLL_NORMAL = c.pollInterval ?? 30
    POLL_ACTIVE = c.pollActiveInterval ?? 10
    RUNS_PER_REPO = c.runsPerRepo ?? 10
    FILTER_DEFAULT_BRANCHES = c.filterDefaultBranches ?? false
}

func saveConfig(repos: [String]) {
    try? FileManager.default.createDirectory(atPath: CONFIG_DIR, withIntermediateDirectories: true)
    let c = AppConfig(repos: repos.filter { isValidRepo($0) }, pollInterval: POLL_NORMAL,
                      pollActiveInterval: POLL_ACTIVE, runsPerRepo: RUNS_PER_REPO,
                      filterDefaultBranches: FILTER_DEFAULT_BRANCHES)
    if let data = try? JSONEncoder().encode(c) {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let pretty = try? JSONSerialization.data(withJSONObject: json as Any, options: .prettyPrinted) {
            try? pretty.write(to: URL(fileURLWithPath: CONFIG_PATH))
        }
    }
    REPOS = repos
}

// Find gh CLI — hardcoded trusted paths only
let GH: String = {
    let trusted = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]
    for p in trusted {
        if FileManager.default.isExecutableFile(atPath: p) { return p }
    }
    return trusted[0] // Will show "gh not found" error on first fetch
}()

// Minimal env for gh CLI — PATH, HOME, LANG + gh auth/config vars
let ghEnv: [String: String] = {
    let env = ProcessInfo.processInfo.environment
    let allow = ["PATH", "HOME", "LANG", "SHELL",
                 "GH_TOKEN", "GITHUB_TOKEN", "GH_CONFIG_DIR",
                 "XDG_CONFIG_HOME", "XDG_DATA_HOME",
                 "GNUPGHOME", "SSH_AUTH_SOCK"]
    var result: [String: String] = [:]
    for key in allow { if let v = env[key] { result[key] = v } }
    if result["PATH"] == nil { result["PATH"] = "/usr/bin:/bin:/opt/homebrew/bin" }
    if result["HOME"] == nil { result["HOME"] = NSHomeDirectory() }
    return result
}()

let POP_W: CGFloat = 560
let POP_MAX_H: CGFloat = 700
let ROW_H: CGFloat = 56
let HDR_H: CGFloat = 32
let FTR_H: CGFloat = 40
let PAD: CGFloat = 12
let ICON_SZ: CGFloat = 20
let TEXT_X: CGFloat = 42     // PAD + ICON_SZ + 10

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
    let actorLogin: String?
}

struct PRAuthor: Decodable { let login: String }
struct PRLabel: Decodable { let name: String; let color: String? }
struct PR: Decodable {
    let number: Int
    let title: String
    let state: String
    let author: PRAuthor
    let headRefName: String
    let baseRefName: String
    let url: String
    let createdAt: String
    let updatedAt: String
    let reviewDecision: String?
    let additions: Int
    let deletions: Int
    let isDraft: Bool
    let labels: [PRLabel]
    let body: String?
}

enum PRAction {
    case approve(String?)
    case requestChanges(String)
    case comment(String)
    case merge(String)   // "-m", "-r", "-s"
    case close
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

private let _fetchErrQ = DispatchQueue(label: "com.clintoncodewell.cat-eye.fetchErr")
private var _lastFetchError: String? = nil
var lastFetchError: String? {
    get { _fetchErrQ.sync { _lastFetchError } }
    set { _fetchErrQ.sync { _lastFetchError = newValue } }
}

func ghShell(_ args: String...) -> Data? {
    guard FileManager.default.isExecutableFile(atPath: GH) else {
        let msg = "GitHub CLI not found at \(GH)"
        log.error("\(msg)")
        lastFetchError = msg
        return nil
    }
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: GH)
    proc.arguments = Array(args)
    proc.environment = ghEnv
    let outPipe = Pipe()
    let errPipe = Pipe()
    proc.standardOutput = outPipe
    proc.standardError = errPipe
    do {
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            log.warning("gh \(args.joined(separator: " ")) exited \(proc.terminationStatus): \(errStr)")
            if errStr.contains("auth") || errStr.contains("login") {
                lastFetchError = "Not authenticated. Run: gh auth login"
            } else if !errStr.isEmpty {
                lastFetchError = String(errStr.prefix(120))
            }
            return nil
        }
        lastFetchError = nil
        return outPipe.fileHandleForReading.readDataToEndOfFile()
    } catch {
        log.error("Failed to launch gh: \(error.localizedDescription)")
        lastFetchError = "Failed to run gh: \(error.localizedDescription)"
        return nil
    }
}

func ghStr(_ args: String...) -> String? {
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: GH)
    proc.arguments = Array(args)
    proc.environment = ghEnv
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
    let jq = "[.workflow_runs[] | {name, displayTitle: .display_title, status, conclusion, headBranch: .head_branch, event, url: .html_url, updatedAt: .updated_at, createdAt: .created_at, startedAt: .run_started_at, number: .run_number, workflowName: .name, actorLogin: .actor.login}]"
    guard let data = ghShell("api", "repos/\(repo)/actions/runs?per_page=\(RUNS_PER_REPO)", "--jq", jq)
    else { return [] }
    return (try? JSONDecoder().decode([Run].self, from: data)) ?? []
}

func fetchPRs(repo: String) -> [PR] {
    let fields = "number,title,state,author,headRefName,baseRefName,url,createdAt,updatedAt,reviewDecision,additions,deletions,isDraft,labels,body"
    guard let data = ghShell("pr", "list", "--repo", repo, "--limit", "20", "--state", "open",
                             "--search", "review-requested:@me", "--json", fields)
    else { return [] }
    return (try? JSONDecoder().decode([PR].self, from: data)) ?? []
}

func executePRAction(repo: String, number: Int, action: PRAction, completion: @escaping () -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
        let n = "\(number)", r = repo
        switch action {
        case .approve(let body):
            if let b = body, !b.isEmpty {
                _ = ghShell("pr", "review", "--approve", "-b", b, "-R", r, n)
            } else {
                _ = ghShell("pr", "review", "--approve", "-R", r, n)
            }
        case .requestChanges(let body):
            _ = ghShell("pr", "review", "--request-changes", "-b", body, "-R", r, n)
        case .comment(let body):
            _ = ghShell("pr", "comment", "-b", body, "-R", r, n)
        case .merge(let method):
            _ = ghShell("pr", "merge", method, "-R", r, n)
        case .close:
            _ = ghShell("pr", "close", "-R", r, n)
        }
        DispatchQueue.main.async { completion() }
    }
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

let timestampFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"; return f
}()

func fmtTimestamp(_ iso: String) -> String {
    guard let d = parseISO(iso) else { return "" }
    return timestampFmt.string(from: d)
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
    // Rolling 3-day window of completed runs of the same workflow.
    let cutoff = Date().addingTimeInterval(-3 * 24 * 3600)
    let completed = history.filter { r in
        guard (r.workflowName ?? r.name) == wf, r.status == "completed",
              let s = parseISO(r.startedAt) ?? parseISO(r.createdAt) else { return false }
        return s >= cutoff
    }
    let durs = completed.compactMap { r -> TimeInterval? in
        guard let s = parseISO(r.startedAt) ?? parseISO(r.createdAt),
              let e = parseISO(r.updatedAt) else { return nil }
        let d = e.timeIntervalSince(s); return d > 0 ? d : nil
    }
    guard !durs.isEmpty else { return nil }
    return durs.reduce(0, +) / Double(durs.count)
}

let startedFmt: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
}()

// "Started 11:56 am" / "Started yesterday 3:04 pm" / "Started May 12, 9:01 am"
func fmtStartedAt(_ iso: String?) -> String {
    guard let d = parseISO(iso) else { return "" }
    let cal = Calendar.current
    if cal.isDateInToday(d) { return "Started \(startedFmt.string(from: d))" }
    if cal.isDateInYesterday(d) { return "Started yesterday \(startedFmt.string(from: d))" }
    return "Started \(timestampFmt.string(from: d))"
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

// ─── PR Helpers ──────────────────────────────────────────────────────────────

func prReviewIcon(_ pr: PR) -> String {
    if pr.isDraft { return "pencil.circle" }
    switch pr.reviewDecision ?? "" {
    case "APPROVED": return "checkmark.circle.fill"
    case "CHANGES_REQUESTED": return "xmark.circle.fill"
    case "REVIEW_REQUIRED": return "circle.badge.questionmark"
    default: return "circle.dashed"
    }
}

func prReviewColor(_ pr: PR) -> NSColor {
    if pr.isDraft { return .systemGray }
    switch pr.reviewDecision ?? "" {
    case "APPROVED": return .systemGreen
    case "CHANGES_REQUESTED": return .systemRed
    case "REVIEW_REQUIRED": return .systemYellow
    default: return .secondaryLabelColor
    }
}

func prRelativeTime(_ iso: String) -> String {
    guard let d = parseISO(iso) else { return "" }
    let secs = -d.timeIntervalSinceNow
    if secs < 60 { return "just now" }
    if secs < 3600 { return "\(Int(secs/60))m ago" }
    if secs < 86400 { return "\(Int(secs/3600))h ago" }
    return "\(Int(secs/86400))d ago"
}

let PR_ROW_H: CGFloat = 56

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

    init(group: [Run], history: [Run], w: CGFloat) {
        let primary = RunRow.pickPrimary(group)
        self.urlStr = primary.url
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: ROW_H))
        wantsLayer = true
        build(group: group, primary: primary, history: history, w: w)
    }
    required init?(coder: NSCoder) { fatalError() }

    // Pick the run that drives the status icon, click target, and elapsed/ETA.
    // Priority: in_progress (longest-running) > queued > completed-failure > anything else.
    static func pickPrimary(_ group: [Run]) -> Run {
        let inProg = group.filter { $0.status == "in_progress" }
        if let r = inProg.max(by: { runElapsed($0) < runElapsed($1) }) { return r }
        if let r = group.first(where: { $0.status == "queued" }) { return r }
        if let r = group.first(where: { $0.status == "completed" && $0.conclusion == "failure" }) { return r }
        return group[0]
    }

    func build(group: [Run], primary: Run, history: [Run], w: CGFloat) {
        let pad: CGFloat = 12, iconSz: CGFloat = 20
        let textX = pad + iconSz + 10, copyW: CGFloat = 28
        let rightW: CGFloat = 165          // fixed allocation for start time + duration
        let rightX = w - rightW - copyW - 4
        let textW = rightX - textX - 8     // leave 8px gap before the right column

        let iv = NSImageView(frame: NSRect(x: pad, y: (ROW_H - iconSz) / 2, width: iconSz, height: iconSz))
        let statusDesc = "\(primary.status) \(primary.conclusion ?? "")"
        if let img = NSImage(systemSymbolName: sfName(primary), accessibilityDescription: statusDesc) {
            iv.image = img; iv.contentTintColor = sfColor(primary)
            iv.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        }
        addSubview(iv)

        let title = lbl(String(primary.displayTitle.prefix(80)), .systemFont(ofSize: 12.5, weight: .semibold))
        title.frame = NSRect(x: textX, y: ROW_H - 24, width: textW, height: 18)
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        // Subtitle: branch + event + actor. For groups, the workflow list collapses to "N workflows"
        // and a small stack chip with a (done/total) progress counter sits at the front.
        let actor = primary.actorLogin.map { " by \($0)" } ?? ""
        let branch = primary.headBranch.isEmpty ? "" : " \u{00B7} \(primary.headBranch)"
        var subX = textX
        var subRemaining = textW

        if group.count > 1 {
            let done = group.filter { $0.status == "completed" }.count
            let chip = makeGroupChip(done: done, total: group.count)
            chip.frame.origin = NSPoint(x: subX, y: 6)
            addSubview(chip)
            subX += chip.frame.width + 6
            subRemaining -= chip.frame.width + 6
        }

        let wf = primary.workflowName ?? primary.name
        let prefix = group.count > 1
            ? "\(group.count) workflows"
            : "\(wf) #\(primary.number)"
        let sub = lbl("\(prefix)\(branch) \u{00B7} \(primary.event)\(actor)",
                      .systemFont(ofSize: 11), .secondaryLabelColor)
        sub.frame = NSRect(x: subX, y: 6, width: subRemaining, height: 16)
        sub.lineBreakMode = .byTruncatingTail
        addSubview(sub)

        // Time column. For groups: earliest start, longest elapsed (driven by primary).
        let groupStart = group.compactMap { parseISO($0.startedAt) ?? parseISO($0.createdAt) }.min()
        let startedISO: String? = groupStart.map { isoFmt.string(from: $0) } ?? (primary.startedAt ?? primary.createdAt)

        let anyActive = group.contains { $0.status == "in_progress" || $0.status == "queued" }
        if anyActive {
            let elapsed = runElapsed(primary)
            let started = lbl(fmtStartedAt(startedISO), .systemFont(ofSize: 10.5), .secondaryLabelColor)
            started.alignment = .right
            started.frame = NSRect(x: rightX, y: ROW_H - 23, width: rightW, height: 14)
            addSubview(started)

            let el = lbl("\(fmtDuration(elapsed)) elapsed",
                         .monospacedDigitSystemFont(ofSize: 10.5, weight: .medium), .systemOrange)
            el.alignment = .right
            el.frame = NSRect(x: rightX, y: 22, width: rightW, height: 14)
            addSubview(el)

            var etaText = "estimating..."
            if let est = estimatedTotal(for: primary, history: history) {
                let rem = max(0, est - elapsed)
                etaText = rem > 0 ? "~\(fmtDuration(rem)) remaining" : "finishing..."
            }
            let eta = lbl(etaText, .systemFont(ofSize: 10), .secondaryLabelColor)
            eta.alignment = .right
            eta.frame = NSRect(x: rightX, y: 6, width: rightW, height: 14)
            addSubview(eta)
        } else {
            let started = lbl(fmtStartedAt(startedISO), .systemFont(ofSize: 10.5), .secondaryLabelColor)
            started.alignment = .right
            started.frame = NSRect(x: rightX, y: ROW_H - 23, width: rightW, height: 14)
            addSubview(started)

            // For groups: total wall-clock from earliest start to latest end.
            let durText: String
            if group.count > 1,
               let s = groupStart,
               let e = group.compactMap({ parseISO($0.updatedAt) }).max() {
                durText = fmtDuration(e.timeIntervalSince(s))
            } else {
                durText = runDuration(primary)
            }
            let dur = lbl(durText, .systemFont(ofSize: 10), .secondaryLabelColor)
            dur.alignment = .right
            dur.frame = NSRect(x: rightX, y: 6, width: rightW, height: 14)
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

    // Subtle "stack + (done/total)" indicator for grouped workflow runs.
    func makeGroupChip(done: Int, total: Int) -> NSView {
        let countText = "\(done)/\(total)"
        let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        let textW = (countText as NSString).size(withAttributes: [.font: font]).width
        let iconW: CGFloat = 11, gap: CGFloat = 3, padX: CGFloat = 5
        let w = padX + iconW + gap + textW + padX
        let chip = NSView(frame: NSRect(x: 0, y: 0, width: w, height: 16))

        let iv = NSImageView(frame: NSRect(x: padX, y: 2, width: iconW, height: 11))
        if let img = NSImage(systemSymbolName: "square.stack.3d.up.fill", accessibilityDescription: "\(total) workflows") {
            iv.image = img; iv.contentTintColor = .secondaryLabelColor
            iv.symbolConfiguration = .init(pointSize: 9, weight: .medium)
        }
        chip.addSubview(iv)

        let l = NSTextField(labelWithString: countText)
        l.font = font; l.textColor = .secondaryLabelColor
        l.frame = NSRect(x: padX + iconW + gap, y: 0, width: textW + 1, height: 14)
        chip.addSubview(l)
        chip.toolTip = "\(done) of \(total) workflows complete"
        return chip
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
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15).cgColor
        }
    }
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = nil
        }
    }
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).cgColor
    }
    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15; ctx.allowsImplicitAnimation = true; layer?.backgroundColor = nil
        }
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else { return }
        for sub in subviews where sub is NSButton { if sub.frame.contains(loc) { return } }
        if let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
    }

    // Keyboard accessibility
    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType {
        get { .exterior }
        set {}
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { // Return or Space
            if let url = URL(string: urlStr) { NSWorkspace.shared.open(url) }
        } else { super.keyDown(with: event) }
    }
}

// ─── PR Row View ─────────────────────────────────────────────────────────────

class PRRow: NSView {
    let urlStr: String
    var onToggle: (() -> Void)?
    var trackingArea: NSTrackingArea?

    init(_ pr: PR, repo: String, w: CGFloat, expanded: Bool) {
        self.urlStr = pr.url
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: PR_ROW_H))
        wantsLayer = true
        if expanded { layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.1).cgColor }
        build(pr, repo: repo, w: w)
    }
    required init?(coder: NSCoder) { fatalError() }

    func build(_ pr: PR, repo: String, w: CGFloat) {
        let pad: CGFloat = 12, iconSz: CGFloat = 20
        let textX = pad + iconSz + 10, linkW: CGFloat = 28, copyW: CGFloat = 28
        let rightW: CGFloat = 140
        let textW = w - textX - rightW - linkW - copyW

        // Review status icon
        let iv = NSImageView(frame: NSRect(x: pad, y: (PR_ROW_H - iconSz) / 2, width: iconSz, height: iconSz))
        let reviewDesc = pr.isDraft ? "Draft" : (pr.reviewDecision ?? "Pending review")
        if let img = NSImage(systemSymbolName: prReviewIcon(pr), accessibilityDescription: reviewDesc) {
            iv.image = img; iv.contentTintColor = prReviewColor(pr)
            iv.symbolConfiguration = .init(pointSize: 14, weight: .semibold)
        }
        addSubview(iv)

        // Title
        let title = lbl(String(pr.title.prefix(70)), .systemFont(ofSize: 12.5, weight: .semibold))
        title.frame = NSRect(x: textX, y: PR_ROW_H - 24, width: textW, height: 18)
        title.lineBreakMode = .byTruncatingTail
        addSubview(title)

        // Subtitle: #number by author + branch (bold number)
        let sub = NSTextField(labelWithString: "")
        let subAttr = NSMutableAttributedString()
        subAttr.append(NSAttributedString(string: "#\(pr.number)", attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.labelColor,
        ]))
        subAttr.append(NSAttributedString(string: " by \(pr.author.login)", attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        sub.attributedStringValue = subAttr
        sub.frame = NSRect(x: textX, y: 6, width: textW * 0.5, height: 16)
        sub.lineBreakMode = .byTruncatingTail; sub.maximumNumberOfLines = 1
        addSubview(sub)

        // Branch badge
        let branchText = String(pr.headRefName.prefix(18))
        let badge = Badge(branchText)
        badge.frame.origin = NSPoint(x: textX + textW * 0.5, y: 8)
        addSubview(badge)

        // Right side: +/- and time
        let rX = w - rightW - linkW - copyW
        let diffText = "+\(pr.additions) -\(pr.deletions)"
        let diffLabel = lbl(diffText, .monospacedDigitSystemFont(ofSize: 10, weight: .medium), .secondaryLabelColor)
        diffLabel.alignment = .right
        diffLabel.frame = NSRect(x: rX, y: PR_ROW_H - 22, width: rightW - 4, height: 14)
        addSubview(diffLabel)

        let timeLabel = lbl(prRelativeTime(pr.updatedAt), .systemFont(ofSize: 10), .secondaryLabelColor)
        timeLabel.alignment = .right
        timeLabel.frame = NSRect(x: rX, y: 6, width: rightW - 4, height: 14)
        addSubview(timeLabel)

        // Draft badge
        if pr.isDraft {
            let draft = lbl("Draft", .systemFont(ofSize: 9, weight: .medium), .systemGray)
            draft.frame = NSRect(x: rX, y: PR_ROW_H / 2 - 6, width: 32, height: 12)
            addSubview(draft)
        }

        // Open in GitHub button
        let linkBtn = NSButton(frame: NSRect(x: w - linkW - copyW - 4, y: (PR_ROW_H - 24) / 2, width: linkW, height: 24))
        if let img = NSImage(systemSymbolName: "arrow.up.right.square", accessibilityDescription: "Open in GitHub") { linkBtn.image = img }
        linkBtn.bezelStyle = .recessed; linkBtn.isBordered = false; linkBtn.imagePosition = .imageOnly
        linkBtn.target = self; linkBtn.action = #selector(openURL)
        addSubview(linkBtn)

        // Copy URL button
        let cpBtn = NSButton(frame: NSRect(x: w - copyW - 4, y: (PR_ROW_H - 24) / 2, width: copyW, height: 24))
        if let img = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy URL") { cpBtn.image = img }
        cpBtn.bezelStyle = .recessed; cpBtn.isBordered = false; cpBtn.imagePosition = .imageOnly
        cpBtn.target = self; cpBtn.action = #selector(copyURL); cpBtn.toolTip = "Copy PR URL"
        addSubview(cpBtn)

        // Separator
        let sep = NSView(frame: NSRect(x: textX, y: 0, width: w - textX - pad, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep)
    }

    func lbl(_ text: String, _ font: NSFont, _ color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(labelWithString: text)
        l.font = font; l.textColor = color; l.maximumNumberOfLines = 1
        l.cell?.truncatesLastVisibleLine = true; return l
    }

    @objc func openURL() { if let u = URL(string: urlStr) { NSWorkspace.shared.open(u) } }
    @objc func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urlStr, forType: .string)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(trackingArea!)
    }
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15; ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.15).cgColor
        }
    }
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15; ctx.allowsImplicitAnimation = true; layer?.backgroundColor = nil
        }
    }
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.25).cgColor
    }
    override func mouseUp(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15; ctx.allowsImplicitAnimation = true; layer?.backgroundColor = nil
        }
        let loc = convert(event.locationInWindow, from: nil)
        guard bounds.contains(loc) else { return }
        for sub in subviews where sub is NSButton { if sub.frame.contains(loc) { return } }
        onToggle?()
    }

    // Keyboard accessibility
    override var acceptsFirstResponder: Bool { true }
    override var focusRingType: NSFocusRingType {
        get { .exterior }
        set {}
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { onToggle?() }
        else { super.keyDown(with: event) }
    }
}

// ─── PR Detail View ──────────────────────────────────────────────────────────

class PRDetailView: NSView {
    var onAction: ((PRAction) -> Void)?
    var confirmingClose = false
    var commentField: NSTextField!

    init(_ pr: PR, repo: String, w: CGFloat) {
        super.init(frame: .zero)
        wantsLayer = true
        // Inverse-of-background tint so the expanded panel is distinct from the doc bg in both modes.
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        let pad: CGFloat = 42, rPad: CGFloat = 16
        let contentW = w - pad - rPad
        var y: CGFloat = 8

        // Body text
        let bodyText = String((pr.body ?? "No description.").prefix(500))
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11.5)]
        let bodyRect = (bodyText as NSString).boundingRect(
            with: NSSize(width: contentW, height: 100),
            options: [.usesLineFragmentOrigin], attributes: bodyAttrs)
        let bodyH = min(ceil(bodyRect.height) + 4, 100)
        let bodyLabel = NSTextField(wrappingLabelWithString: bodyText)
        bodyLabel.font = .systemFont(ofSize: 11.5); bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.frame = NSRect(x: pad, y: y, width: contentW, height: bodyH)
        bodyLabel.maximumNumberOfLines = 6
        addSubview(bodyLabel)
        y += bodyH + 8

        // Labels
        if !pr.labels.isEmpty {
            var lx: CGFloat = pad
            for label in pr.labels.prefix(5) {
                let lb = Badge(label.name)
                lb.frame.origin = NSPoint(x: lx, y: y)
                addSubview(lb)
                lx += lb.frame.width + 6
            }
            y += 24
        }

        // Separator
        let sep1 = NSView(frame: NSRect(x: pad, y: y, width: contentW, height: 0.5))
        sep1.wantsLayer = true; sep1.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep1); y += 8

        // Action buttons row
        let btnH: CGFloat = 24
        var bx: CGFloat = pad

        let approveBtn = makeBtn("Approve", color: .systemGreen, x: bx, y: y, h: btnH)
        approveBtn.target = self; approveBtn.action = #selector(doApprove)
        addSubview(approveBtn); bx += approveBtn.frame.width + 6

        let changesBtn = makeBtn("Changes", color: .systemOrange, x: bx, y: y, h: btnH)
        changesBtn.target = self; changesBtn.action = #selector(doRequestChanges)
        addSubview(changesBtn); bx += changesBtn.frame.width + 6

        let mergePopup = NSPopUpButton(frame: NSRect(x: bx, y: y, width: 130, height: btnH), pullsDown: false)
        mergePopup.addItems(withTitles: ["Merge commit", "Rebase", "Squash"])
        mergePopup.font = .systemFont(ofSize: 11)
        addSubview(mergePopup); mergePopup.tag = 100; bx += 136

        let mergeBtn = makeBtn("Merge", color: .systemPurple, x: bx, y: y, h: btnH)
        mergeBtn.target = self; mergeBtn.action = #selector(doMerge)
        addSubview(mergeBtn); bx += mergeBtn.frame.width + 6

        let closeBtn = makeBtn("Close", color: .systemRed, x: bx, y: y, h: btnH)
        closeBtn.target = self; closeBtn.action = #selector(doClose(_:))
        closeBtn.tag = 200
        addSubview(closeBtn)
        y += btnH + 10

        // Comment field + submit
        let sep2 = NSView(frame: NSRect(x: pad, y: y, width: contentW, height: 0.5))
        sep2.wantsLayer = true; sep2.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep2); y += 8

        let cf = NSTextField(frame: NSRect(x: pad, y: y, width: contentW - 80, height: 24))
        cf.placeholderString = "Leave a comment..."
        cf.font = .systemFont(ofSize: 11.5)
        addSubview(cf); commentField = cf

        let submitBtn = makeBtn("Comment", color: .linkColor, x: pad + contentW - 72, y: y, h: 24)
        submitBtn.target = self; submitBtn.action = #selector(doComment)
        addSubview(submitBtn)
        y += 32

        self.frame = NSRect(x: 0, y: 0, width: w, height: y)
    }
    required init?(coder: NSCoder) { fatalError() }

    func makeBtn(_ title: String, color: NSColor, x: CGFloat, y: CGFloat, h: CGFloat) -> NSButton {
        let b = NSButton(title: title, target: nil, action: nil)
        b.bezelStyle = .inline; b.font = .systemFont(ofSize: 11, weight: .medium)
        b.contentTintColor = color
        let tw = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium)]).width
        b.frame = NSRect(x: x, y: y, width: tw + 20, height: h)
        return b
    }

    func disableActions(_ message: String) {
        for sub in subviews where sub is NSButton {
            (sub as! NSButton).isEnabled = false
        }
        commentField.isEnabled = false
        commentField.stringValue = ""
        commentField.placeholderString = message
    }

    @objc func doApprove() {
        let body = commentField.stringValue.isEmpty ? nil : commentField.stringValue
        disableActions("Approving...")
        onAction?(.approve(body))
    }
    @objc func doRequestChanges() {
        let body = commentField.stringValue
        guard !body.isEmpty else { commentField.placeholderString = "Required: describe changes needed"; return }
        disableActions("Submitting review...")
        onAction?(.requestChanges(body))
    }
    @objc func doComment() {
        let body = commentField.stringValue
        guard !body.isEmpty else { return }
        disableActions("Posting comment...")
        onAction?(.comment(body))
    }
    @objc func doMerge() {
        let popup = subviews.compactMap { $0 as? NSPopUpButton }.first(where: { $0.tag == 100 })
        let methods = ["-m", "-r", "-s"]
        let method = methods[popup?.indexOfSelectedItem ?? 0]
        disableActions("Merging...")
        onAction?(.merge(method))
    }
    @objc func doClose(_ sender: NSButton) {
        if confirmingClose {
            onAction?(.close)
        } else {
            confirmingClose = true
            sender.title = "Sure?"; sender.contentTintColor = .white
            sender.layer?.backgroundColor = NSColor.systemRed.cgColor; sender.layer?.cornerRadius = 4
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self, self.confirmingClose else { return }
                self.confirmingClose = false
                sender.title = "Close"; sender.contentTintColor = .systemRed
                sender.layer?.backgroundColor = nil
            }
        }
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
        // Inverse-of-background fill so the badge is visible in both modes:
        // dark fill in light mode, light fill in dark mode.
        NSColor.labelColor.withAlphaComponent(0.08).setFill(); p.fill()
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
        let link = NSTextField(labelWithString: "Open Actions")
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
    init(_ text: String, w: CGFloat, icon: String? = nil) {
        let h: CGFloat = icon != nil ? 52 : 36
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h))
        if let iconName = icon {
            let iv = NSImageView(frame: NSRect(x: 16, y: (h - 20) / 2, width: 20, height: 20))
            if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
                iv.image = img; iv.contentTintColor = .secondaryLabelColor
                iv.symbolConfiguration = .init(pointSize: 14, weight: .regular)
            }
            addSubview(iv)
        }
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabelColor
        l.frame = NSRect(x: 42, y: (h - 20) / 2, width: w - 54, height: 20)
        addSubview(l)
    }
    required init?(coder: NSCoder) { fatalError() }
}

class Flipped: NSView { override var isFlipped: Bool { true } }

class LoadingRow: NSView {
    init(w: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: 48))
        let spinner = NSProgressIndicator(frame: NSRect(x: 16, y: 14, width: 20, height: 20))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.startAnimation(nil)
        addSubview(spinner)
        let l = NSTextField(labelWithString: "Loading...")
        l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabelColor
        l.frame = NSRect(x: 44, y: 14, width: w - 56, height: 20)
        addSubview(l)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// ─── Footer ──────────────────────────────────────────────────────────────────

class Footer: NSView {
    init(_ w: CGFloat, updated: Date) {
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: FTR_H))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let sep = NSView(frame: NSRect(x: 0, y: FTR_H - 0.5, width: w, height: 0.5))
        sep.wantsLayer = true; sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        addSubview(sep)

        let rb = NSButton(title: "Refresh", target: NSApp.delegate, action: #selector(GHActionsBar.doRefresh))
        rb.bezelStyle = .inline; rb.font = .systemFont(ofSize: 11)
        rb.frame = NSRect(x: 8, y: 8, width: 80, height: 24)
        addSubview(rb)

        let f = DateFormatter(); f.dateFormat = "h:mm:ss a"
        let ts = NSTextField(labelWithString: "Updated \(f.string(from: updated))")
        ts.font = .systemFont(ofSize: 10); ts.textColor = .secondaryLabelColor; ts.alignment = .center
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

// ─── Tab View (Actions + PRs) ────────────────────────────────────────────────

let TAB_H: CGFloat = 36

class TabVC: NSViewController {
    let grouped: [(String, [Run])]
    let prGrouped: [(String, [PR])]
    let updated: Date
    let loading: Bool
    var selectedTab: Int
    var selectedRepo: String?
    var expandedPR: String?
    var scrollView: NSScrollView!
    var doc: Flipped!

    init(grouped: [(String, [Run])], prGrouped: [(String, [PR])], updated: Date, loading: Bool,
         tab: Int, repo: String?, expandedPR: String? = nil) {
        self.grouped = grouped; self.prGrouped = prGrouped
        self.updated = updated; self.loading = loading
        self.selectedTab = tab; self.selectedRepo = repo; self.expandedPR = expandedPR
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let w = POP_W
        let container = Flipped(frame: NSRect(x: 0, y: 0, width: w, height: POP_MAX_H))
        container.wantsLayer = true

        // ── Top bar: tabs + repo filter ──
        let topBar = NSView(frame: NSRect(x: 0, y: 0, width: w, height: TAB_H))
        topBar.wantsLayer = true
        topBar.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor

        let seg = NSSegmentedControl(labels: ["Actions", "Pull Requests"], trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
        seg.selectedSegment = selectedTab
        seg.frame = NSRect(x: 12, y: 6, width: 200, height: 24)
        seg.font = .systemFont(ofSize: 11, weight: .medium)
        topBar.addSubview(seg)

        // Main/develop-only checkbox (Actions tab only)
        if selectedTab == 0 {
            let cb = NSButton(checkboxWithTitle: "Main/develop only",
                              target: self, action: #selector(toggleBranchFilter(_:)))
            cb.font = .systemFont(ofSize: 11)
            cb.state = FILTER_DEFAULT_BRANCHES ? .on : .off
            cb.frame = NSRect(x: 220, y: 8, width: 140, height: 20)
            cb.toolTip = "Hide workflow runs from branches other than main or develop"
            topBar.addSubview(cb)
        }

        let repoFilter = NSPopUpButton(frame: NSRect(x: w - 200, y: 6, width: 188, height: 24), pullsDown: false)
        repoFilter.font = .systemFont(ofSize: 11)
        repoFilter.addItem(withTitle: "All Repos")
        for repo in REPOS { repoFilter.addItem(withTitle: repo.components(separatedBy: "/").last ?? repo) }
        if let sel = selectedRepo, let idx = REPOS.firstIndex(of: sel) { repoFilter.selectItem(at: idx + 1) }
        else { repoFilter.selectItem(at: 0) }
        repoFilter.target = self; repoFilter.action = #selector(repoChanged(_:))
        repoFilter.tag = 300
        topBar.addSubview(repoFilter)
        container.addSubview(topBar)

        // ── Footer (fixed at bottom) ──
        let footer = Footer(w, updated: updated)

        // ── Scroll content ──
        let scrollH = POP_MAX_H - TAB_H - FTR_H
        scrollView = NSScrollView(frame: NSRect(x: 0, y: TAB_H, width: w, height: scrollH))
        scrollView.hasVerticalScroller = true; scrollView.drawsBackground = false; scrollView.autohidesScrollers = true
        doc = Flipped(frame: NSRect(x: 0, y: 0, width: w, height: scrollH))
        doc.wantsLayer = true
        doc.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor
        scrollView.documentView = doc
        container.addSubview(scrollView)

        rebuildContent()

        // Size the popover based on content
        let contentH = doc.frame.height
        let visScrollH = min(contentH, scrollH)
        let totalH = TAB_H + visScrollH + FTR_H
        scrollView.frame.size.height = visScrollH
        footer.frame.origin.y = TAB_H + visScrollH
        container.addSubview(footer)
        container.frame.size.height = totalH

        self.view = container
        self.preferredContentSize = NSSize(width: w, height: totalH)
    }

    func rebuildContent() {
        doc.subviews.forEach { $0.removeFromSuperview() }
        let w = POP_W
        var rows: [NSView] = []

        if REPOS.isEmpty {
            rows.append(EmptyRow("No repos configured. Open Settings to get started.", w: w, icon: "gearshape"))
        } else if selectedTab == 0 {
            rows = buildActionsContent(w)
        } else {
            rows = buildPRContent(w)
        }

        var y: CGFloat = 0
        for row in rows { row.frame.origin = NSPoint(x: 0, y: y); doc.addSubview(row); y += row.frame.height }
        doc.frame.size.height = max(y, 60)
    }

    func filteredGrouped() -> [(String, [Run])] {
        guard let sel = selectedRepo else { return grouped }
        return grouped.filter { $0.0 == sel }
    }

    func filteredPRs() -> [(String, [PR])] {
        guard let sel = selectedRepo else { return prGrouped }
        return prGrouped.filter { $0.0 == sel }
    }

    func buildActionsContent(_ w: CGFloat) -> [NSView] {
        var rows: [NSView] = []
        let data = filteredGrouped()
        if let err = lastFetchError {
            rows.append(EmptyRow(err, w: w, icon: "exclamationmark.triangle"))
            return rows
        }
        if loading && data.isEmpty {
            rows.append(LoadingRow(w: w)); return rows
        }
        for (repo, runs) in data {
            rows.append(Header(repo, w: w))
            let visible = FILTER_DEFAULT_BRANCHES
                ? runs.filter { DEFAULT_BRANCHES.contains($0.headBranch) }
                : runs
            if visible.isEmpty {
                let msg = FILTER_DEFAULT_BRANCHES && !runs.isEmpty
                    ? "No recent runs on main or develop"
                    : "No recent runs"
                rows.append(EmptyRow(msg, w: w))
            } else {
                let sorted = visible.sorted { a, b in
                    let aActive = a.status == "in_progress" || a.status == "queued"
                    let bActive = b.status == "in_progress" || b.status == "queued"
                    if aActive != bActive { return aActive }
                    return false  // preserve API order otherwise
                }
                // Group runs from the same push (same commit message + branch + event + actor)
                // into a single row. Different workflows triggered by one commit collapse.
                var groups: [[Run]] = []
                var indexByKey: [String: Int] = [:]
                for run in sorted {
                    let key = "\(run.displayTitle)|\(run.headBranch)|\(run.event)|\(run.actorLogin ?? "")"
                    if let i = indexByKey[key] { groups[i].append(run) }
                    else { indexByKey[key] = groups.count; groups.append([run]) }
                }
                for group in groups {
                    rows.append(RunRow(group: group, history: visible, w: w))
                }
            }
        }
        if rows.isEmpty { rows.append(EmptyRow("No actions to show", w: w)) }
        return rows
    }

    func buildPRContent(_ w: CGFloat) -> [NSView] {
        var rows: [NSView] = []
        let data = filteredPRs()
        let hasPRs = data.contains { !$0.1.isEmpty }
        if !hasPRs {
            rows.append(EmptyRow("No pull requests awaiting your review", w: w, icon: "checkmark.seal"))
            return rows
        }
        for (repo, prs) in data {
            if prs.isEmpty { continue }
            rows.append(Header(repo, w: w))
            for pr in prs {
                let key = "\(repo)#\(pr.number)"
                let isExpanded = expandedPR == key
                let row = PRRow(pr, repo: repo, w: w, expanded: isExpanded)
                row.onToggle = { [weak self] in
                    guard let self = self else { return }
                    self.expandedPR = self.expandedPR == key ? nil : key
                    // Semitransient when expanded (prevents accidental close while typing comment)
                    let appDel = NSApp.delegate as? GHActionsBar
                    appDel?.popover.behavior = self.expandedPR != nil ? .semitransient : .transient
                    self.rebuildContent()
                }
                rows.append(row)
                if isExpanded {
                    let detail = PRDetailView(pr, repo: repo, w: w)
                    detail.onAction = { [weak self] action in
                        self?.handlePRAction(repo: repo, pr: pr, action: action)
                    }
                    rows.append(detail)
                }
            }
        }
        return rows
    }

    func handlePRAction(repo: String, pr: PR, action: PRAction) {
        executePRAction(repo: repo, number: pr.number, action: action) {
            (NSApp.delegate as? GHActionsBar)?.doRefresh()
        }
    }

    @objc func tabChanged(_ sender: NSSegmentedControl) {
        selectedTab = sender.selectedSegment
        (NSApp.delegate as? GHActionsBar)?.selectedTab = selectedTab
        expandedPR = nil
        // Rebuild the whole view so the checkbox shows/hides with the tab.
        loadView()
    }

    @objc func toggleBranchFilter(_ sender: NSButton) {
        FILTER_DEFAULT_BRANCHES = (sender.state == .on)
        saveConfig(repos: REPOS)
        rebuildContent()
    }

    @objc func repoChanged(_ sender: NSPopUpButton) {
        if sender.indexOfSelectedItem == 0 {
            selectedRepo = nil
        } else {
            let idx = sender.indexOfSelectedItem - 1
            if idx < REPOS.count { selectedRepo = REPOS[idx] }
        }
        (NSApp.delegate as? GHActionsBar)?.selectedRepo = selectedRepo
        expandedPR = nil
        rebuildContent()
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
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.85).cgColor
        var y: CGFloat = 0

        // ── Nav bar ──
        let nav = NSView(frame: NSRect(x: 0, y: 0, width: w, height: 44))
        nav.wantsLayer = true; nav.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.9).cgColor
        let back = NSButton(title: "Back", target: NSApp.delegate, action: #selector(GHActionsBar.showList))
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
        let refreshBtn = NSButton(title: "Refresh", target: self, action: #selector(fetchRepos))
        refreshBtn.bezelStyle = .inline; refreshBtn.font = .systemFont(ofSize: 10)
        refreshBtn.frame = NSRect(x: w - 80, y: 6, width: 68, height: 20)
        repoHdr.addSubview(refreshBtn)
        container.addSubview(repoHdr); y += 28

        let ll = NSTextField(labelWithString: "Loading repos...")
        ll.font = .systemFont(ofSize: 11); ll.textColor = .secondaryLabelColor
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
        guard let sl = statusLabel else { return }
        if let user = username {
            let attr = NSMutableAttributedString()
            attr.append(NSAttributedString(string: "Authenticated as ", attributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
            attr.append(NSAttributedString(string: user, attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: NSColor.labelColor,
            ]))
            sl.attributedStringValue = attr
        } else {
            sl.stringValue = "Not authenticated — click Login"
            sl.textColor = .systemRed
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
            l.font = .systemFont(ofSize: 12); l.textColor = .secondaryLabelColor
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
              !text.isEmpty, isValidRepo(text) else {
            addField?.placeholderString = "Format: owner/repo (letters, numbers, hyphens)"
            return
        }
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
    var prGrouped: [(String, [PR])] = []
    var lastUpdate = Date()
    var closeTime = Date.distantPast
    var firstLoad = true
    var ghIcon: NSImage?
    var prevStatuses: [String: String] = [:]
    var selectedTab: Int = 0
    var selectedRepo: String? = nil
    var appearanceObs: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ note: Notification) {
        log.info("Cat Eye launching — repos: \(REPOS.count), poll: \(POLL_NORMAL)s/\(POLL_ACTIVE)s")
        loadConfig()
        log.info("Config loaded — tracking \(REPOS.count) repos: \(REPOS.joined(separator: ", "))")
        ghIcon = loadGHIcon()

        let nc = UNUserNotificationCenter.current()
        nc.delegate = self
        nc.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted { log.info("Notification permission granted") }
            else { log.warning("Notification permission denied: \(error?.localizedDescription ?? "user declined")") }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.image = tintedIcon(ghIcon, .secondaryLabelColor)
            btn.imagePosition = .imageOnly
            btn.target = self
            btn.action = #selector(toggle)
            // Re-render the cached tinted icon when the system flips light/dark.
            appearanceObs = btn.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.updateIcon() }
            }
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        applySystemAppearance()   // pins NSApp.appearance + popover.appearance from defaults

        // System-wide light/dark toggle. NSApp.effectiveAppearance is unreliable for
        // .accessory apps, so we listen for the canonical distributed notification.
        DistributedNotificationCenter.default.addObserver(
            self, selector: #selector(systemAppearanceChanged),
            name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), object: nil)

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
        let repos = REPOS  // snapshot on calling thread
        let start = Date()
        log.debug("Refresh starting for \(repos.count) repos")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var runRes = Array(repeating: (String, [Run])("", []), count: repos.count)
            var prRes = Array(repeating: (String, [PR])("", []), count: repos.count)
            let collectQ = DispatchQueue(label: "com.clintoncodewell.cat-eye.collect")
            let group = DispatchGroup()
            for (i, repo) in repos.enumerated() {
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    let runs = fetchRuns(repo: repo)
                    collectQ.sync { runRes[i] = (repo, runs) }
                    group.leave()
                }
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    let prs = fetchPRs(repo: repo)
                    collectQ.sync { prRes[i] = (repo, prs) }
                    group.leave()
                }
            }
            group.wait()
            let elapsed = Date().timeIntervalSince(start)
            let totalRuns = runRes.reduce(0) { $0 + $1.1.count }
            let totalPRs = prRes.reduce(0) { $0 + $1.1.count }
            log.info("Refresh done in \(String(format: "%.1f", elapsed))s — \(totalRuns) runs, \(totalPRs) PRs")
            DispatchQueue.main.async {
                self.detectTransitions(runRes)
                self.grouped = runRes
                self.prGrouped = prRes
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
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            guard let self = self, let btn = self.statusItem.button else { return }
            self.animPhase += 0.15
            // Smooth 2-second breathing cycle (~7fps, sufficient for 18px icon)
            btn.alphaValue = CGFloat(0.4 + 0.6 * (0.5 + 0.5 * sin(self.animPhase * .pi)))
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
                log.info("Transition: \(wf) on \(run.headBranch) → in_progress (was \(old ?? "new"))")
                notify(title: "\u{25B6}\u{FE0F} Action Started", body: "\(wf) on \(run.headBranch)", id: "start-\(run.url)")
            }
            if run.status == "completed" && (old == "in_progress" || old == "queued") {
                let ok = run.conclusion == "success"
                log.info("Transition: \(wf) on \(run.headBranch) → \(run.conclusion ?? "unknown") (was \(old ?? "new"))")
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

    func makeTabVC() -> TabVC {
        TabVC(grouped: grouped, prGrouped: prGrouped, updated: lastUpdate, loading: firstLoad,
              tab: selectedTab, repo: selectedRepo)
    }

    @objc func toggle() {
        if popover.isShown { popover.close() }
        else if Date().timeIntervalSince(closeTime) > 0.3 {
            // Pin appearance BEFORE constructing the view tree so .cgColor resolves correctly.
            applySystemAppearance()
            if popover.contentViewController == nil || popover.contentViewController is TabVC {
                buildWithAppearance { self.popover.contentViewController = self.makeTabVC() }
            }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .minY)
        }
    }

    /// True if the system is currently in Dark Mode. Reads CFPreferences directly because
    /// UserDefaults.standard caches the value and serves stale results immediately after
    /// the user flips appearance.
    func isSystemDarkMode() -> Bool {
        let v = CFPreferencesCopyAppValue("AppleInterfaceStyle" as CFString,
                                          kCFPreferencesAnyApplication) as? String
        return v == "Dark"
    }

    func applySystemAppearance() {
        let appearance = NSAppearance(named: isSystemDarkMode() ? .darkAqua : .aqua)
        // NSApp.appearance pins how `NSColor.X.cgColor` resolves process-wide.
        NSApp.appearance = appearance
        popover.appearance = appearance
    }

    /// Construct views inside an explicit drawing-appearance context so every
    /// `NSColor.X.cgColor` accessed during construction resolves with the right colors.
    /// Without this, `layer.backgroundColor` ends up baked in whichever appearance the
    /// process happened to last be drawing under.
    func buildWithAppearance(_ block: () -> Void) {
        let appearance = NSApp.appearance ?? NSApp.effectiveAppearance
        if #available(macOS 11.0, *) {
            appearance.performAsCurrentDrawingAppearance { block() }
        } else {
            let prev = NSAppearance.current
            NSAppearance.current = appearance
            block()
            NSAppearance.current = prev
        }
    }

    @objc func systemAppearanceChanged() {
        // Distributed notifications can arrive on a background thread; also CFPreferences
        // may not have flushed yet — a tiny hop to the next main runloop is reliable.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.applySystemAppearance()
            self.updateIcon()
            // Discard the stale view tree (its CGColors are baked in the OLD appearance).
            // Next show reconstructs under the new drawing context.
            let wasShownAsSettings = self.popover.contentViewController is SettingsVC
            let wasShown = self.popover.isShown
            self.popover.close()
            self.popover.contentViewController = nil
            if wasShown {
                self.closeTime = .distantPast
                if wasShownAsSettings { self.showSettings() }
                else { self.toggle() }
            }
        }
    }

    @objc func showSettings() {
        applySystemAppearance()
        buildWithAppearance { self.popover.contentViewController = SettingsVC(current: Set(REPOS)) }
        if !popover.isShown {
            closeTime = .distantPast
            toggle()
        }
    }

    @objc func showList() {
        applySystemAppearance()
        buildWithAppearance { self.popover.contentViewController = self.makeTabVC() }
    }

    @objc func doRefresh() {
        popover.close()
        refresh { [weak self] in
            guard let self = self else { return }
            self.closeTime = .distantPast
            self.toggle()
        }
    }

    @objc func quitApp() { log.info("Cat Eye quitting"); NSApp.terminate(nil) }

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
