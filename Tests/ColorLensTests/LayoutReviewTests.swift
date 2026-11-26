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

@Test(.enabled(if: ProcessInfo.processInfo.environment["COLORLENS_CAPTURE_UI"] == "1"))
@MainActor
func captureGradientLayoutAndExportCompilerFixtures() throws {
    let model = GradientEditorModel()
    model.angle = 135
    model.add(color: ColorValue(red: 255, green: 200, blue: 0, alpha: 128))
    model.add(color: ColorValue(red: 120, green: 45, blue: 210))
    let definition = try #require(model.definition)
    let folder = FileManager.default.temporaryDirectory
    for (format, name) in [(GradientCode.objectiveC, "colorlens-gradient.m"), (.swift, "colorlens-gradient-swift.swift"),
                            (.swiftUI, "colorlens-gradient-swiftui.swift"), (.css, "colorlens-gradient.css")] {
        try format.render(definition).write(to: folder.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    let renderer = ImageRenderer(content: GradientEditorView(model: model, currentColor: .init(red: 255, green: 0, blue: 0))
        .content.frame(width: 861, height: 1040, alignment: .top).background(Color(nsColor: .windowBackgroundColor)))
    renderer.scale = 2
    let bitmap = NSBitmapImageRep(cgImage: try #require(renderer.cgImage))
    try #require(bitmap.representation(using: .png, properties: [:]))
        .write(to: folder.appendingPathComponent("colorlens-gradient-layout.png"))
}
