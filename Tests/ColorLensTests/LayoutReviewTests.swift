import AppKit
import SwiftUI
import Testing
import ColorCore
@testable import ColorLens

/// Opt-in captures for visual review, using isolated color storage.
@Test(.enabled(if: ProcessInfo.processInfo.environment["COLORLENS_CAPTURE_UI"] == "1"))
@MainActor
func captureBackgroundAndComparisonLayouts() throws {
    _ = NSApplication.shared
    let domain = "ColorLensLayoutTests." + UUID().uuidString
    let defaults = try #require(UserDefaults(suiteName: domain))
    defer { defaults.removePersistentDomain(forName: domain) }
    let store = ColorStore(defaults: defaults)
    store.record(ColorValue(red: 255, green: 0, blue: 0, alpha: 128))

    func capture<V: View>(_ view: V, size: NSSize, name: String) throws {
        // AppKit cacheDisplay omits layer-backed SwiftUI text. ImageRenderer covers
        // SwiftUI layout; native controls still require an actual-app spot check.
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height, alignment: .top)
            .background(Color(nsColor: .windowBackgroundColor)))
        renderer.scale = 2
        let cg = try #require(renderer.cgImage)
        let bitmap = NSBitmapImageRep(cgImage: cg)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name))
        #expect(bitmap.pixelsWide > 0 && bitmap.pixelsHigh > 0)
    }

    try capture(ContentView().mainContent.environmentObject(store), size: NSSize(width: 620, height: 1040), name: "colorlens-main-layout.png")
    try capture(ColorCompareView(initial: .init(red: 255, green: 0, blue: 0, alpha: 128), apply: { _ in }),
                size: NSSize(width: 780, height: 620), name: "colorlens-comparison-layout.png")
}
