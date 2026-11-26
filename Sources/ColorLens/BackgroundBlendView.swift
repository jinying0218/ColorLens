import AppKit
import SwiftUI
import ColorCore

extension ColorValue {
    var displayColor: Color {
        Color(.sRGB, red: Double(red)/255, green: Double(green)/255,
              blue: Double(blue)/255, opacity: Double(alpha)/255)
    }
}

struct BackgroundBlendView: View {
    @EnvironmentObject private var store: ColorStore
    let foreground: ColorValue
    let valid: Bool
    @AppStorage("blendBackgroundRGB") private var backgroundText = "#FFFFFF"
    @State private var copied = false

    private var background: ColorValue? { ColorValue.parse(backgroundText, format: .rgb) }
    private var result: ColorValue? { valid ? background.map { foreground.composited(over: $0) } : nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("自定义背景").font(.headline)
                Spacer()
                ColorPicker("选择背景色", selection: Binding(get: {
                    (background ?? ColorValue(red: 255, green: 255, blue: 255)).displayColor
                }, set: { chosen in
                    guard let color = NSColor(chosen).usingColorSpace(.sRGB) else { return }
                    func byte(_ channel: CGFloat) -> UInt8 { UInt8((min(1, max(0, channel))*255).rounded()) }
                    backgroundText = ColorValue(red: byte(color.redComponent), green: byte(color.greenComponent),
                                                blue: byte(color.blueComponent)).hex(.rgb)
                }), supportsOpacity: false).labelsHidden()
                TextField("#RRGGBB", text: $backgroundText)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.roundedBorder).frame(width: 120)
                    .accessibilityLabel("背景 RGB 颜色")
            }
            HStack(spacing: 14) {
                if let result {
                    RoundedRectangle(cornerRadius: 8).fill(result.displayColor).frame(width: 96, height: 48)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.gray.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("叠加结果  \(result.hex(.rgb))").font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                        Text("当前颜色叠加到背景 · 输出不透明 RGB")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Button(copied ? "已复制" : "复制结果") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.hex(.rgb), forType: .string)
                        store.record(result)
                        copied = true
                    }
                } else {
                    Text(valid ? "背景色请输入 6 位 RGB，例如 #F5F5F5。" : "请先输入有效的前景颜色。")
                        .font(.caption).foregroundStyle(.red).frame(height: 48)
                }
            }
            Text("按 sRGB 通道进行 Alpha 叠加，结果取整至 8 位。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        .onChange(of: foreground) { _ in copied = false }
        .onChange(of: backgroundText) { _ in copied = false }
    }
}
