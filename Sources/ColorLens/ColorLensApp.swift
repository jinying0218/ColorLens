import AppKit
import SwiftUI
import ColorCore

@main
struct ColorLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup("ColorLens") { ContentView() }
            .windowResizability(.contentSize)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @State private var input = "#80007AFF"
    @State private var format: HexFormat = .argb
    @State private var value = ColorValue(red: 0, green: 122, blue: 255, alpha: 128)
    @State private var error: String?
    @State private var copied: String?
    @State private var sampler = NSColorSampler()
    @AppStorage("preciseAlpha") private var preciseAlpha = false

    private var color: Color {
        Color(.sRGB, red: Double(value.red)/255, green: Double(value.green)/255,
              blue: Double(value.blue)/255, opacity: Double(value.alpha)/255)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ColorLens").font(.largeTitle.bold())
                    Text("颜色预览 · 屏幕取色 · 格式转换").foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: sample) { Label("屏幕取色", systemImage: "eyedropper") }
                    .controlSize(.large)
            }
            VStack(alignment: .leading, spacing: 10) {
                Picker("输入格式", selection: $format) {
                    ForEach(HexFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                TextField("输入十六进制颜色", text: $input)
                    .font(.system(size: 20, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: input) { _ in parse() }
                    .onChange(of: format) { _ in parse() }
                Text(error ?? "支持 #、0x 和 Objective-C 字符串；6 位为 RGB，8 位按所选格式解析。")
                    .font(.caption).foregroundStyle(error == nil ? Color.secondary : Color.red)
            }
            HStack(spacing: 12) {
                preview("透明背景", background: nil)
                preview("白色背景", background: .white)
                preview("黑色背景", background: .black)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("透明度")
                    Spacer()
                    Text(String(format: preciseAlpha ? "%.1f%%  ·  A = %02X" : "%.0f%%  ·  A = %02X", Double(value.alpha)/255*100, Int(value.alpha)))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: {
                    preciseAlpha ? Double(value.alpha) : (Double(value.alpha)/255*100).rounded()
                }, set: {
                    setAlpha(UInt8((preciseAlpha ? $0 : $0/100*255).rounded()))
                }), in: 0...(preciseAlpha ? 255 : 100), step: 1)
                .disabled(error != nil)
                HStack(spacing: 0) {
                    ForEach(0...10, id: \.self) { index in
                        let percent = index * 10
                        Button {
                            setAlpha(UInt8((Double(percent)/100*255).rounded()))
                        } label: {
                            VStack(spacing: 4) {
                                Rectangle().frame(width: 1, height: 6)
                                Text("\(percent)%").font(.system(size: 10)).monospacedDigit()
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Int((Double(value.alpha)/255*100).rounded()) == percent ? Color.accentColor : Color.secondary)
                        .accessibilityLabel("设置透明度为 \(percent)%")
                    }
                }
                .disabled(error != nil)
                Toggle("精确透明度", isOn: $preciseAlpha)
                    .toggleStyle(.checkbox).font(.caption)
                    .help("开启后按 Alpha 原始值 0～255 调整，并显示一位小数。切换开关不会改变当前颜色。")
            }
            VStack(spacing: 10) {
                ForEach(HexFormat.allCases, id: \.self) { item in
                    HStack {
                        Text(item.rawValue).frame(width: 56, alignment: .leading).foregroundStyle(.secondary)
                        Text(value.hex(item)).font(.system(.title3, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Button(copied == item.rawValue ? "已复制" : "复制") { copy(value.hex(item), key: item.rawValue) }
                    }
                }
                Divider()
                HStack {
                    Text("R \(value.red)   G \(value.green)   B \(value.blue)   A \(value.alpha)")
                        .font(.system(.body, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Button(copied == "objc" ? "已复制" : "复制 OC 字符串") {
                        copy("@\"\(value.hex(.argb))\"", key: "objc")
                    }
                }
            }
            .padding(16).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            .disabled(error != nil).opacity(error == nil ? 1 : 0.45)
            Text("sRGB · 屏幕取色得到的是合成后的颜色，透明度默认 100%，可手动调整。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 620)
    }

    private func preview(_ title: String, background: Color?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let background { background } else { Checkerboard() }
                color
                if error != nil { Text("输入无效").padding(6).background(.regularMaterial, in: Capsule()) }
            }
            .frame(height: 110).clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.gray.opacity(0.25)))
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func parse() {
        copied = nil
        if let parsed = ColorValue.parse(input, format: format) { value = parsed; error = nil }
        else { error = format == .rgb ? "请输入 6 位十六进制 RGB。" : "请输入 6 位 RGB 或 8 位 \(format.rawValue)；8 位颜色的透明度位置由所选格式决定。" }
    }

    private func copy(_ text: String, key: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copied = key
    }

    private func setAlpha(_ alpha: UInt8) {
        value.alpha = alpha
        if format == .rgb { format = .argb }
        input = value.hex(format)
        error = nil
        copied = nil
    }

    private func sample() {
        sampler.show { selected in
            guard let selected, let rgb = selected.usingColorSpace(.sRGB) else { return }
            func byte(_ channel: CGFloat) -> UInt8 { UInt8((min(1, max(0, channel))*255).rounded()) }
            let sampled = ColorValue(red: byte(rgb.redComponent), green: byte(rgb.greenComponent), blue: byte(rgb.blueComponent))
            Task { @MainActor in
                value = sampled
                input = sampled.hex(format)
                error = nil
                copied = nil
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let tile: CGFloat = 10
            for row in 0..<Int(ceil(size.height / tile)) {
                for col in 0..<Int(ceil(size.width / tile)) {
                    let rect = CGRect(x: CGFloat(col)*tile, y: CGFloat(row)*tile, width: tile, height: tile)
                    context.fill(Path(rect), with: .color((row+col).isMultiple(of: 2) ? .white : Color(white: 0.78)))
                }
            }
        }
    }
}
