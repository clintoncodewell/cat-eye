import AppKit

/// Keyboard focus for accessory (LSUIElement) menu-bar apps. Call `FocusKit.install()` once at launch.
///
/// Fixes two things the menu-bar apps share:
///  1. DEAD KEYBOARD AFTER HIDE. An accessory app that activated to show a window stays the
///     active app after that window hides or closes. It has no key window, so every key dings and
///     another app's visible panel cannot get the keyboard back. `handBackIfIdle()` gives activation
///     back to the app the user came from, when a panel is dismissed or any window (Settings, pop-out) closes.
///     A hide caused by losing key does not hand back (focus may now sit in another app's
///     nonactivating panel, such as Spotlight). If that leaves us active with nothing key, the first
///     key the user types reaches us, which proves no other panel holds the keyboard: the keyDown
///     monitor then hands back and drops the keys typed until the hand-back lands, instead of
///     letting every key ding.
///  2. DEAD PANEL. A visible nonactivating panel that lost key ignores clicks. `KeyablePanel.sendEvent`
///     re-claims key on a left click.
/// ⌘X/C/V/A/Z (⇧⌘Z redo) also walk the panel's responder chain, so they do not depend on the main menu,
/// which an inactive app never consults.
@MainActor
enum FocusKit {
    static var log: (String) -> Void = { _ in }
    /// The last other app that was active. When we are active, that is the app we took focus from.
    private(set) static var returnTo: NSRunningApplication?
    private static var installed = false
    private static var checkPending = false
    private static var recheck: DispatchWorkItem?
    /// True while a menu (status-item or context menu) is open. Menu windows cannot become key, so without this
    /// a hand-back during menu tracking would look idle and close the menu the user just opened. A Bool, not a count:
    /// AppKit posts the tracking notifications for the root menu only, and a missed end recovers on the next close.
    private static var menuTracking = false
    /// Windows that never hold the keyboard for the user even though they could become key, such as an
    /// always-visible indicator or a meeting overlay. They must not stop a hand-back while they are on screen.
    /// When one of them is key, `NSApp.keyWindow` is set, so the app is not idle anyway.
    static var ignoredForIdle: (NSWindow) -> Bool = { _ in false }

    static func install() {
        guard !installed else { return }
        installed = true
        note(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { n in
            let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { note(app) }
        }
        // A window the user closes (Settings, pop-outs) is key when it closes and can leave us active
        // with nothing to type into. A window that closes because it lost key is not key: focus went to
        // something the user chose, possibly another app's nonactivating panel (Spotlight), and handing
        // activation away would close that panel. Not didResignKey, for the same reason.
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { n in
            let wasKey = (n.object as? NSWindow)?.isKeyWindow ?? false
            MainActor.assumeIsolated { if wasKey { scheduleHandBack() } }
        }
        NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { menuTracking = true }
        }
        NotificationCenter.default.addObserver(forName: NSMenu.didEndTrackingNotification, object: nil, queue: .main) { _ in
            // No hand-back here: the chosen item may be opening a window or another app (Join meeting),
            // and a hand-back would race it. If nothing took the keyboard, the keyDown net below recovers.
            MainActor.assumeIsolated { menuTracking = false }
        }
        // Safety net for every path that did not hand back: a key that reaches us while we are active
        // with no key window would only ding, and no other app's panel can hold the keyboard.
        // Keys aimed at a visible window, and ⌘ shortcuts (the main menu's ⌘, and ⌘Q), go on as usual. So does a
        // key while a visible window could take the keyboard (a pinned panel that lost key): the app's own
        // handlers and the click re-claim deal with that, as before.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard !event.modifierFlags.contains(.command) else { return event }
            let windowNumber = event.windowNumber
            let stray = MainActor.assumeIsolated { () -> Bool in
                guard NSApp.window(withWindowNumber: windowNumber)?.isVisible != true, isIdle else { return false }
                log("focus: key with no key window")
                handBack()
                return true
            }
            return stray ? nil : event
        }
    }

    private static func note(_ app: NSRunningApplication?) {
        if let app, app.processIdentifier != getpid() { returnTo = app }
    }

    /// Check on the next run-loop pass, once per burst, after the closing window is really gone,
    /// and once more after close animations (popovers, fades) have finished.
    static func scheduleHandBack() {
        guard !checkPending else { return }
        checkPending = true
        DispatchQueue.main.async { MainActor.assumeIsolated { checkPending = false; handBackIfIdle() } }
        // One pending recheck at a time, so a burst of closes does not queue a burst of checks.
        recheck?.cancel()
        let item = DispatchWorkItem { MainActor.assumeIsolated { recheck = nil; handBackIfIdle() } }
        recheck = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
    }

    /// If we are the active app with no key window and nothing visible that could take the keyboard,
    /// give activation back to the app the user came from.
    static func handBackIfIdle() {
        // NSApp.isActive is our own state and updates synchronously, unlike NSWorkspace.frontmostApplication.
        // A visible window on another Space cannot take the keyboard here, so it does not count.
        guard isIdle else { return }
        handBack()
    }

    /// Active, with no key window, no modal, no open menu and nothing visible here that could take the keyboard.
    private static var isIdle: Bool {
        NSApp.isActive && NSApp.keyWindow == nil && NSApp.modalWindow == nil && !menuTracking
            && !NSApp.windows.contains(where: { $0.isVisible && $0.isOnActiveSpace && $0.canBecomeKey && !ignoredForIdle($0) })
    }

    /// Give activation back to the app the user came from now, whatever windows we have open.
    /// For flows that must leave this app at once, such as pasting into the previous app.
    /// Returns false when there was no app to return to (we only deactivated, or were not active):
    /// the next active app is then whatever macOS picks.
    @discardableResult
    static func handBack() -> Bool {
        guard NSApp.isActive else { return false }
        if let back = returnTo, !back.isTerminated, !back.isHidden {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: back)
                back.activate()
            } else {
                back.activate(options: [])
            }
            log("focus: handed activation back to \(back.localizedName ?? "?")")
            return true
        }
        NSApp.deactivate()
        log("focus: deactivated (no app to hand back to)")
        return false
    }

    /// The edit action ⌘X/C/V/A/Z (and ⇧⌘Z redo) stands for, or nil for any other combo. ⇧⌘V is not paste.
    nonisolated static func editSelector(key: String, modifiers: NSEvent.ModifierFlags) -> Selector? {
        // Only ⌘ ⇧ ⌥ ⌃ count: Caps Lock, fn and the keypad flag must not stop ⌘C from matching.
        let m = modifiers.intersection([.command, .shift, .option, .control])
        guard m == .command || m == [.command, .shift] else { return nil }
        let k = key.lowercased()
        if k == "z" { return Selector(m.contains(.shift) ? "redo:" : "undo:") }
        guard m == .command else { return nil }
        return ["x": #selector(NSText.cut(_:)), "c": #selector(NSText.copy(_:)), "v": #selector(NSText.paste(_:)),
                "a": #selector(NSText.selectAll(_:))][k]
    }

    /// Send an edit action up the window's responder chain (first responder, views, window, window delegate),
    /// the way a menu item would. Returns false when nothing handles it.
    static func sendEditAction(_ sel: Selector, in window: NSWindow) -> Bool {
        (window.firstResponder ?? window).tryToPerform(sel, with: nil)
    }

    /// For apps whose text fields live outside a KeyablePanel (an NSPopover, say): route edit keys
    /// to the key window's responder chain before the event is dispatched.
    static func installEditKeyMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Pass only Sendable values into the main-actor block; NSEvent is not Sendable.
            guard let k = event.charactersIgnoringModifiers else { return event }
            let flags = event.modifierFlags, windowNumber = event.windowNumber
            let handled = MainActor.assumeIsolated { () -> Bool in
                guard let sel = editSelector(key: k, modifiers: flags),
                      let w = NSApp.window(withWindowNumber: windowNumber) ?? NSApp.keyWindow else { return false }
                return sendEditAction(sel, in: w)
            }
            return handled ? nil : event
        }
    }
}

class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }

    /// Show the panel and give it the keyboard. `activate: false` keeps the user's app frontmost.
    func present(activate: Bool) {
        makeKeyAndOrderFront(nil)
        if activate { NSApp.activate(ignoringOtherApps: true) }
    }

    /// Hide the panel; if that leaves us active with nothing to type into, give focus back.
    /// Pass `handBack: false` when the hide is a reaction to losing key (click outside, resign key):
    /// focus already went somewhere the user chose, possibly another app's nonactivating panel.
    func dismiss(handBack: Bool = true) {
        orderOut(nil)
        if handBack { FocusKit.scheduleHandBack() }
    }

    override func sendEvent(_ event: NSEvent) {
        if !isKeyWindow, event.type == .leftMouseDown {
            makeKeyAndOrderFront(nil)
            if !isKeyWindow { NSApp.activate(ignoringOtherApps: true); makeKey() }
            FocusKit.log("focus: click re-claimed key -> isKey=\(isKeyWindow)")
        }
        super.sendEvent(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if super.performKeyEquivalent(with: event) { return true }
        guard event.type == .keyDown, let k = event.charactersIgnoringModifiers,
              let sel = FocusKit.editSelector(key: k, modifiers: event.modifierFlags) else { return false }
        return FocusKit.sendEditAction(sel, in: self)
    }
}
