import AppKit
import SwiftUI
import Testing
import ColorCore
@testable import ColorLens

/// Captures actual native windows, with demo-only storage and no user's clipboard.
@Test(.enabled(if: ProcessInfo.processInfo.environment["COLORLENS_DOCS_OUTPUT"] != nil))
@MainActor
func captureDocumentationAndVerifyResizing() throws {
    _ = NSApplication.shared
    let folder = URL(fileURLWithPath: try #require(ProcessInfo.processInfo.environment["COLORLENS_DOCS_OUTPUT"]))
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let domain = "ColorLensDocumentation." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    defaults.set("CSS", forKey: "gradientCodeFormat")
    let store = ColorStore(defaults: defaults)
    for color in [ColorValue(red: 255, green: 107, blue: 53), .init(red: 120, green: 45, blue: 210),
                  .init(red: 0, green: 122, blue: 255, alpha: 128)] { store.record(color) }
    store.toggleFavorite(.init(red: 120, green: 45, blue: 210))

    func screenshot(_ window: NSWindow, _ name: String) throws {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.4))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l", String(window.windowNumber), folder.appendingPathComponent(name).path]
        try process.run(); process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path))
    }

    func makeWindow<V: View>(_ view: V, size: NSSize, title: String = "ColorLens") -> (NSWindow, NSHostingView<V>) {
        let host = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = title
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        return (window, host)
    }

    let (colors, host) = makeWindow(ContentView().environmentObject(store).defaultAppStorage(defaults),
                                   size: NSSize(width: 1000, height: 980))
    defer { colors.orderOut(nil) }
    for size in [NSSize(width: 680, height: 480), NSSize(width: 1000, height: 820), NSSize(width: 1320, height: 900)] {
        colors.setContentSize(size)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
        #expect(abs(host.bounds.width-size.width) < 1)
        #expect(abs(host.bounds.height-size.height) < 1)
        #expect(host.fittingSize.width <= 681, "Content must not impose the former fixed 861pt width")
        print("Verified responsive content: \(Int(host.bounds.width)) × \(Int(host.bounds.height))")
    }
    colors.setContentSize(NSSize(width: 1000, height: 980))
    try screenshot(colors, "colors.png")
    colors.orderOut(nil)

    let gradient = GradientEditorModel()
    gradient.angle = 135
    gradient.add(color: .init(red: 255, green: 200, blue: 0, alpha: 128))
    gradient.add(color: .init(red: 120, green: 45, blue: 210))
    let (gradientWindow, _) = makeWindow(ContentView(initialWorkspace: "渐变色", gradient: gradient)
        .environmentObject(store).defaultAppStorage(defaults), size: NSSize(width: 1000, height: 940))
    try screenshot(gradientWindow, "gradient.png")
    gradientWindow.orderOut(nil)

    let (comparison, _) = makeWindow(ColorCompareView(initial: .init(red: 0, green: 122, blue: 255, alpha: 128),
                      actual: .init(red: 0, green: 112, blue: 245, alpha: 204), apply: { _ in }),
                      size: NSSize(width: 900, height: 680), title: "ColorLens · 两色对比")
    try screenshot(comparison, "comparison.png")
    comparison.orderOut(nil)

    if let path = ProcessInfo.processInfo.environment["COLORLENS_DOCS_IMAGE"], let image = NSImage(contentsOfFile: path) {
        let (picker, _) = makeWindow(ImagePickerView(initialImage: image, select: { _ in }),
                                    size: NSSize(width: 920, height: 660), title: "ColorLens · 图片取色")
        try screenshot(picker, "image-picker.png")
        picker.orderOut(nil)
    }
}
