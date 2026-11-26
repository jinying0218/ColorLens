import AppKit
import SwiftUI
import ColorCore

struct ColorCompareView: View {
    let initial: ColorValue
    let apply: (ColorValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var referenceText: String
    @State private var actualText: String
    @State private var referenceFormat: HexFormat = .argb
    @State private var actualFormat: HexFormat = .argb
    @State private var backdrop = "白色"
    @State private var copied = false

    init(initial: ColorValue, actual: ColorValue? = nil, apply: @escaping (ColorValue) -> Void) {
        self.initial = initial
        self.apply = apply
        _referenceText = State(initialValue: initial.hex(.argb))
        _actualText = State(initialValue: (actual ?? initial).hex(.argb))
    }

    private var reference: ColorValue? { ColorValue.parse(referenceText, format: referenceFormat) }
    private var actual: ColorValue? { ColorValue.parse(actualText, format: actualFormat) }
    private var background: ColorValue? {
        backdrop == "棋盘格" ? nil : (backdrop == "白色" ? ColorValue(red: 255, green: 255, blue: 255) : ColorValue(red: 0, green: 0, blue: 0))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("两色对比").font(.title2.bold())
                Spacer()
                Button("交换 A / B") {
                    swap(&referenceText, &actualText)
                    swap(&referenceFormat, &actualFormat)
                }
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            HStack {
                Picker("共同背景", selection: $backdrop) {
                    ForEach(["白色", "黑色", "棋盘格"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).frame(width: 350)
                Spacer()
                Text("两侧使用相同背景").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 18) {
                CompareColorCard(title: "A · 设计值 / 参考色", text: $referenceText,
                                 format: $referenceFormat, background: background, initial: initial) { color in
                    apply(color); dismiss()
                }
                CompareColorCard(title: "B · 实际值 / 待比较色", text: $actualText,
                                 format: $actualFormat, background: background, initial: initial) { color in
                    apply(color); dismiss()
                }
            }
            if let reference, let actual {
                comparison(reference, actual)
            } else {
                Text("请输入两组有效颜色；8 位字符串分别按各自选择的 ARGB / RGBA 解析。")
                    .foregroundStyle(.red).font(.caption)
                    .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
            }
            Text("差值为 B − A；RGB 和 Alpha 为原始 0～255 通道差，不透明度以百分点比较。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(24).frame(minWidth: 700, idealWidth: 780, maxWidth: .infinity,
                          minHeight: 580, idealHeight: 640, maxHeight: .infinity, alignment: .top)
        .onChange(of: referenceText) { _ in copied = false }
        .onChange(of: actualText) { _ in copied = false }
        .onChange(of: referenceFormat) { _ in copied = false }
        .onChange(of: actualFormat) { _ in copied = false }
    }

    private func comparison(_ a: ColorValue, _ b: ColorValue) -> some View {
        let difference = ColorDifference(reference: a, actual: b)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(a == b ? "RGBA 完全相同" : "RGBA 数值不同", systemImage: a == b ? "equal.circle" : "circle.lefthalf.filled")
                    .font(.headline)
                Spacer()
                Button(copied ? "已复制" : "复制对比结果") {
                    let report = "A ARGB: \(a.hex(.argb))\nB ARGB: \(b.hex(.argb))\n差值 B-A: R \(difference.red), G \(difference.green), B \(difference.blue), A \(difference.alpha)\n不透明度差: \(String(format: "%+.1f", difference.opacityPoints)) 个百分点"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report, forType: .string)
                    copied = true
                }
            }
            Grid(alignment: .leading, horizontalSpacing: 32, verticalSpacing: 8) {
                GridRow { Text("通道"); Text("A"); Text("B"); Text("B − A") }.foregroundStyle(.secondary)
                deltaRow("R", a.red, b.red, difference.red)
                deltaRow("G", a.green, b.green, difference.green)
                deltaRow("B", a.blue, b.blue, difference.blue)
                deltaRow("Alpha", a.alpha, b.alpha, difference.alpha)
                GridRow {
                    Text("不透明度")
                    Text(String(format: "%.1f%%", Double(a.alpha)/255*100))
                    Text(String(format: "%.1f%%", Double(b.alpha)/255*100))
                    Text(String(format: "%+.1f 个百分点", difference.opacityPoints))
                }
            }.font(.system(.body, design: .monospaced)).textSelection(.enabled)
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func deltaRow(_ label: String, _ a: UInt8, _ b: UInt8, _ delta: Int) -> some View {
        GridRow { Text(label); Text("\(a)"); Text("\(b)"); Text(String(format: "%+d", delta)) }
    }
}

private struct CompareColorCard: View {
    let title: String
    @Binding var text: String
    @Binding var format: HexFormat
    let background: ColorValue?
    let initial: ColorValue
    let apply: (ColorValue) -> Void
    private var color: ColorValue? { ColorValue.parse(text, format: format) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Picker("输入格式", selection: $format) {
                ForEach(HexFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            TextField("颜色字符串", text: $text).textFieldStyle(.roundedBorder)
                .font(.system(.title3, design: .monospaced)).accessibilityLabel(title)
            ZStack {
                if let color {
                    if let background { color.composited(over: background).displayColor }
                    else { Checkerboard(); color.displayColor }
                } else {
                    Color.secondary.opacity(0.1)
                    Text("颜色格式无效").font(.caption).foregroundStyle(.red)
                }
            }.frame(height: 100).clipShape(RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("填入当前颜色") {
                    if format == .rgb && initial.alpha != 255 { format = .argb }
                    text = initial.hex(format)
                }
                Spacer()
                Button("应用此颜色") { if let color { apply(color) } }.disabled(color == nil)
            }.font(.caption)
        }.frame(maxWidth: .infinity)
    }
}
