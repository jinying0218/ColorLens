import AppKit
import SwiftUI
import ColorCore

struct GradientEditorView: View {
    @ObservedObject var model: GradientEditorModel
    let currentColor: ColorValue
    @AppStorage("gradientBackdrop") private var backdrop = "棋盘格"
    @AppStorage("gradientCodeFormat") private var codeFormat: GradientCode = .objectiveC
    @State private var copied = false

    var body: some View {
        ScrollView { content }
        .onChange(of: model.stops) { _ in copied = false }
        .onChange(of: model.angle) { _ in copied = false }
        .onChange(of: codeFormat) { _ in copied = false }
    }

    var content: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("线性渐变").font(.title2.bold())
                        Text("选择节点，设置颜色、位置和透明度。切换工作区会保留本次编辑。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("反转渐变") { model.reverse() }
                }
                preview
                nodeStrip
                angleControls
                selectedEditor
                codeSection
            }.padding(24)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("实时预览").font(.headline)
                Spacer()
                Picker("背景", selection: $backdrop) {
                    ForEach(["棋盘格", "白色", "黑色"], id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.segmented).frame(width: 280)
            }
            GeometryReader { geometry in
                ZStack {
                    if backdrop == "棋盘格" { Checkerboard() }
                    else { backdrop == "白色" ? Color.white : Color.black }
                    if let definition = model.definition {
                        let points = definition.points(width: geometry.size.width, height: geometry.size.height)
                        LinearGradient(stops: definition.stops.map { .init(color: $0.color.displayColor, location: $0.location) },
                                       startPoint: UnitPoint(x: points.start.x, y: points.start.y),
                                       endPoint: UnitPoint(x: points.end.x, y: points.end.y))
                    } else {
                        Text("节点颜色格式无效，请修正后预览和复制代码。")
                            .font(.caption).padding(10).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }.frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.gray.opacity(0.25)))
        }
    }

    private var nodeStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("颜色节点 · \(model.stops.count)/8").font(.headline)
                Spacer()
                Button("添加节点") { model.add(color: currentColor) }.disabled(model.stops.count >= 8)
                    .help("在最大空档添加当前颜色")
                Button("删除选中节点") { model.removeSelected() }.disabled(model.stops.count <= 2)
            }
            HStack(spacing: 8) {
                ForEach(model.ordered) { stop in
                    Button { model.selectedID = stop.id } label: {
                        VStack(spacing: 5) {
                            ZStack {
                                Checkerboard()
                                if let color = stop.color { color.displayColor }
                            }.frame(height: 22).clipShape(RoundedRectangle(cornerRadius: 4))
                            Text(String(format: "%.1f%%", stop.position)).font(.caption).monospacedDigit()
                            Text(stop.color?.hex(.rgb) ?? "格式无效").font(.system(size: 10, design: .monospaced))
                        }.padding(8).frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(model.selectedID == stop.id ? Color.accentColor : .clear, lineWidth: 2))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("渐变节点，位置 \(Int(stop.position))%")
                }
            }
        }
    }

    private var angleControls: some View {
        HStack(spacing: 12) {
            Picker("方向", selection: Binding(get: {
                [0.0, 45.0, 90.0, 135.0, 180.0, 270.0].contains(model.angle) ? model.angle : -1
            }, set: { if $0 >= 0 { model.angle = $0 } })) {
                Text("向上 ↑").tag(0.0)
                Text("右上 ↗").tag(45.0)
                Text("水平 →").tag(90.0)
                Text("右下 ↘").tag(135.0)
                Text("垂直 ↓").tag(180.0)
                Text("向左 ←").tag(270.0)
                Text("自定义").tag(-1.0)
            }.frame(width: 170)
            Slider(value: Binding(get: { model.angle }, set: { model.angle = $0.rounded() }), in: 0...360)
                .accessibilityLabel("渐变角度")
            TextField("角度", value: Binding(get: { model.angle }, set: {
                if $0.isFinite { model.angle = min(360, max(0, $0)) }
            }), format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder).frame(width: 65).accessibilityLabel("渐变角度数值")
            Text("°").foregroundStyle(.secondary)
            Text("0°向上，顺时针").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var selectedEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选中节点").font(.headline)
                Picker("颜色格式", selection: Binding(get: { model.selected?.format ?? .argb }, set: { value in
                    model.updateSelected { $0.format = value }
                })) {
                    ForEach(HexFormat.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 270)
                TextField("颜色字符串", text: Binding(get: { model.selected?.text ?? "" }, set: { value in
                    model.updateSelected { $0.text = value }
                })).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced))
                    .accessibilityLabel("节点颜色字符串")
                ColorPicker("节点颜色", selection: Binding(get: {
                    (model.selected?.color ?? ColorValue(red: 0, green: 0, blue: 0)).displayColor
                }, set: { selected in
                    guard let color = NSColor(selected).usingColorSpace(.sRGB) else { return }
                    func byte(_ component: CGFloat) -> UInt8 { UInt8((min(1, max(0, component))*255).rounded()) }
                    model.setColor(ColorValue(red: byte(color.redComponent), green: byte(color.greenComponent),
                                              blue: byte(color.blueComponent), alpha: byte(color.alphaComponent)))
                }), supportsOpacity: true).labelsHidden()
                Button("使用当前颜色") { model.setColor(currentColor) }
            }
            HStack(spacing: 14) {
                Text("位置").frame(width: 36, alignment: .leading)
                Slider(value: Binding(get: { model.selected?.position ?? 0 }, set: { value in
                    model.updateSelected { $0.position = value.rounded() }
                }), in: 0...100).accessibilityLabel("节点位置")
                TextField("位置", value: Binding(get: { model.selected?.position ?? 0 }, set: { value in
                    if value.isFinite { model.updateSelected { $0.position = min(100, max(0, value)) } }
                }), format: .number.precision(.fractionLength(0...1)))
                    .textFieldStyle(.roundedBorder).frame(width: 65).accessibilityLabel("节点位置百分比")
                Text("%").foregroundStyle(.secondary)
                Text("透明度").frame(width: 48)
                Slider(value: Binding(get: { (Double(model.selected?.color?.alpha ?? 255)/255*100).rounded() }, set: { value in
                    guard var color = model.selected?.color else { return }
                    color.alpha = UInt8((value.rounded()/100*255).rounded())
                    model.setColor(color)
                }), in: 0...100).disabled(model.selected?.color == nil).accessibilityLabel("节点透明度")
                Text(String(format: "%.0f%%", Double(model.selected?.color?.alpha ?? 255)/255*100))
                    .monospacedDigit().frame(width: 42, alignment: .trailing)
            }
            Text(model.selected?.color == nil ? "颜色格式无效：请输入 6 位 RGB，或按所选格式输入 8 位颜色。" : "节点按位置自动排序；相同位置可形成硬切换。导出代码保留原始 Alpha 精度。")
                .font(.caption2).foregroundStyle(model.selected?.color == nil ? Color.red : Color.secondary)
        }.padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("导出代码", selection: $codeFormat) {
                    ForEach(GradientCode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.frame(width: 270)
                Spacer()
                Button(copied ? "已复制" : "复制渐变代码") {
                    guard let definition = model.definition else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(codeFormat.render(definition), forType: .string)
                    copied = true
                }.disabled(model.definition == nil)
            }
            ScrollView([.horizontal, .vertical]) {
                Text(model.definition.map { codeFormat.render($0) } ?? "修正节点颜色后生成代码。")
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }.frame(height: 150).background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            Text("预览背景不写入代码。iOS 图层代码须在容器尺寸变化时更新 frame 和起止点；渐变节点只保留在当前窗口。")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
