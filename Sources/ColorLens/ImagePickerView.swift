import AppKit
import SwiftUI
import ColorCore
import UniformTypeIdentifiers

struct ImagePickerView: View {
    let select: (ColorValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var image: SampleImage?
    @State private var zoom = 1.0
    @State private var message: String?
    @State private var hovered: ColorValue?
    @State private var point: CGPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("图片取色").font(.title2.bold())
                    Text("粘贴截图，放大后点击像素。图片只在内存中处理。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("粘贴图片 ⌘V", action: paste).keyboardShortcut("v", modifiers: .command)
                Button("打开图片…", action: open)
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            if let image {
                HStack {
                    Text("\(image.width) × \(image.height) 像素").foregroundStyle(.secondary)
                    Spacer()
                    Button("适合窗口") { fit(image) }
                    Button("100%") { zoom = 1 }
                    Slider(value: $zoom, in: 0.05...8).frame(width: 170)
                    Text("\(Int((zoom*100).rounded()))%").monospacedDigit().frame(width: 48, alignment: .trailing)
                }.font(.caption)
                ImageCanvas(image: image, zoom: zoom) { color, x, y, picked in
                    hovered = color
                    point = CGPoint(x: x, y: y)
                    if picked { select(color) }
                }
                .background(Color(white: 0.22))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "photo.on.rectangle.angled").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("复制一张截图，再按 ⌘V 粘贴")
                    Button("从剪贴板粘贴图片", action: paste)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
            HStack {
                if let message {
                    Text(message).font(.caption).foregroundStyle(.red)
                } else if let hovered, let point {
                    ZStack {
                        Checkerboard()
                        Color(.sRGB, red: Double(hovered.red)/255, green: Double(hovered.green)/255,
                              blue: Double(hovered.blue)/255, opacity: Double(hovered.alpha)/255)
                    }.frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 5))
                    Text("x: \(Int(point.x))  y: \(Int(point.y))   ARGB \(hovered.hex(.argb))")
                        .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Text("点击应用颜色").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(message ?? "移动鼠标预览像素颜色，点击后应用并记入历史。")
                        .font(.caption).foregroundStyle(message == nil ? Color.secondary : Color.red)
                }
            }.frame(height: 30)
        }.padding(22).frame(width: 820, height: 620)
    }

    private func load(_ source: NSImage?) {
        guard let source, let decoded = SampleImage(image: source) else {
            message = "没有可读取的图片，请复制截图或选择 PNG、JPEG 等图片文件。"
            return
        }
        image = decoded
        hovered = nil
        point = nil
        message = nil
        fit(decoded)
    }

    private func fit(_ image: SampleImage) {
        zoom = max(0.05, min(1, min(740 / Double(image.width), 420 / Double(image.height))))
    }

    private func paste() { load(NSImage(pasteboard: .general)) }
    private func open() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { load(NSImage(contentsOf: url)) }
    }
}

private struct ImageCanvas: NSViewRepresentable {
    let image: SampleImage
    let zoom: Double
    let sample: (ColorValue, Int, Int, Bool) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasHorizontalScroller = true
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = PixelCanvasView()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? PixelCanvasView else { return }
        if view.image !== image { view.selected = nil }
        view.image = image
        view.zoom = zoom
        view.sample = sample
        view.setFrameSize(NSSize(width: Double(image.width)*zoom, height: Double(image.height)*zoom))
        view.needsDisplay = true
    }
}

final class PixelCanvasView: NSView {
    var image: SampleImage?
    var zoom = 1.0
    var selected: CGPoint?
    var sample: ((ColorValue, Int, Int, Bool) -> Void)?
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        NSColor.white.setFill()
        dirtyRect.fill()
        NSGraphicsContext.current?.imageInterpolation = .none
        image?.image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        if let selected {
            let rect = NSRect(x: (selected.x+0.5)*zoom-6, y: (selected.y+0.5)*zoom-6, width: 12, height: 12)
            let outline = NSBezierPath(ovalIn: rect)
            NSColor.white.setStroke(); outline.lineWidth = 3; outline.stroke()
            NSColor.black.setStroke(); outline.lineWidth = 1; outline.stroke()
        }
    }

    override func mouseMoved(with event: NSEvent) { read(event, picked: false) }
    override func mouseDown(with event: NSEvent) { read(event, picked: true) }

    private func read(_ event: NSEvent, picked: Bool) {
        guard zoom > 0, let image else { return }
        let position = convert(event.locationInWindow, from: nil)
        guard position.x >= 0, position.y >= 0 else { return }
        let x = Int(floor(position.x/zoom)), y = Int(floor(position.y/zoom))
        guard let color = image.color(x: x, y: y) else { return }
        if picked { selected = CGPoint(x: x, y: y); needsDisplay = true }
        sample?(color, x, y, picked)
    }
}
