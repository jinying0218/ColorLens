import AppKit
import SwiftUI

struct OpacityTrackMetrics {
    let width: CGFloat
    let inset: CGFloat = 22
    var travel: CGFloat { max(1, width-inset*2) }
    func x(for percent: Double) -> CGFloat { inset + travel*CGFloat(min(100, max(0, percent)))/100 }
    func percent(at x: CGFloat) -> Double { Double(min(1, max(0, (x-inset)/travel)))*100 }
}

/// Track, thumb and clickable ticks share one coordinate system at every width.
struct OpacitySlider: View {
    var percent: Double
    var precise: Bool
    var enabled: Bool
    var onChange: (Double) -> Void
    @FocusState private var focused: Bool

    private var displayedPercent: Double { precise ? percent : percent.rounded() }

    var body: some View {
        GeometryReader { geometry in
            let metrics = OpacityTrackMetrics(width: geometry.size.width)
            ZStack(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                        .frame(width: metrics.travel, height: 4).position(x: geometry.size.width/2, y: 12)
                    Capsule().fill(Color.accentColor)
                        .frame(width: max(0, metrics.x(for: displayedPercent)-metrics.inset), height: 4)
                        .position(x: (metrics.inset+metrics.x(for: displayedPercent))/2, y: 12)
                    Circle().fill(Color(nsColor: .controlBackgroundColor))
                        .overlay(Circle().stroke(focused ? Color.accentColor : Color.black.opacity(0.15), lineWidth: focused ? 2 : 0.5))
                        .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                        .frame(width: 16, height: 16).position(x: metrics.x(for: displayedPercent), y: 12)
                }
                .frame(width: geometry.size.width, height: 24)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    guard enabled else { return }
                    focused = true
                    setPercent(metrics.percent(at: event.location.x))
                })
                ForEach(0...10, id: \.self) { index in
                    let value = index*10
                    Button { setPercent(Double(value)) } label: {
                        VStack(spacing: 3) {
                            Rectangle().frame(width: 1, height: 5)
                            Text("\(value)%").font(.system(size: 10)).monospacedDigit()
                        }.frame(width: 44, height: 24).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Int(displayedPercent.rounded()) == value ? Color.accentColor : Color.secondary)
                    .accessibilityLabel("设置透明度为 \(value)%")
                    .position(x: metrics.x(for: Double(value)), y: 36)
                }
            }
        }
        .frame(height: 48).disabled(!enabled).opacity(enabled ? 1 : 0.45)
        .focusable(enabled).focused($focused)
        .onMoveCommand { direction in
            guard enabled else { return }
            let step = precise ? 100.0/255 : 1
            if direction == .left || direction == .down { setPercent(displayedPercent-step) }
            if direction == .right || direction == .up { setPercent(displayedPercent+step) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("透明度")
        .accessibilityValue(String(format: precise ? "%.1f%%" : "%.0f%%", displayedPercent))
        .accessibilityAdjustableAction { direction in
            guard enabled else { return }
            let step = precise ? 100.0/255 : 1
            if direction == .increment { setPercent(displayedPercent+step) }
            if direction == .decrement { setPercent(displayedPercent-step) }
        }
    }

    private func setPercent(_ value: Double) {
        guard enabled else { return }
        let bounded = min(100, max(0, value))
        onChange(precise ? (bounded/100*255).rounded()/255*100 : bounded.rounded())
    }
}
