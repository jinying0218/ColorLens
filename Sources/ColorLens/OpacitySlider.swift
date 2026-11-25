import AppKit
import SwiftUI

/// The native cell owns both the thumb travel and the tick positions.
struct OpacitySlider: NSViewRepresentable {
    var percent: Double
    var precise: Bool
    var enabled: Bool
    var onChange: (Double) -> Void

    func makeNSView(context: Context) -> OpacitySliderView { OpacitySliderView() }

    func updateNSView(_ view: OpacitySliderView, context: Context) {
        view.precise = precise
        view.onChange = onChange
        view.slider.isEnabled = enabled
        view.slider.doubleValue = precise ? percent : percent.rounded()
        view.slider.altIncrementValue = precise ? 100 / 255 : 1
        for button in view.buttons { button.isEnabled = enabled }
    }
}

final class OpacitySliderView: NSView {
    let slider = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private(set) var buttons: [NSButton] = []
    var precise = false
    var onChange: ((Double) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        slider.numberOfTickMarks = 11
        slider.tickMarkPosition = .below
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.setAccessibilityLabel("透明度")
        addSubview(slider)
        for index in 0...10 {
            let button = NSButton(title: "\(index * 10)%", target: self, action: #selector(tickClicked(_:)))
            button.tag = index
            button.isBordered = false
            button.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            button.contentTintColor = .secondaryLabelColor
            button.setAccessibilityLabel("设置透明度为 \(index * 10)%")
            buttons.append(button)
            addSubview(button)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        // Reserve enough room for the end labels, then use the cell's real ticks.
        slider.frame = NSRect(x: 16, y: 24, width: max(0, bounds.width - 32), height: 24)
        guard let cell = slider.cell as? NSSliderCell else { return }
        for (index, button) in buttons.enumerated() {
            let tick = convert(cell.rectOfTickMark(at: index), from: slider)
            button.frame = NSRect(x: tick.midX - 22, y: 0, width: 44, height: 22)
        }
    }

    @objc private func sliderChanged() {
        let raw = slider.doubleValue
        let percent = precise ? (raw / 100 * 255).rounded() / 255 * 100 : raw.rounded()
        slider.doubleValue = percent
        onChange?(percent)
    }

    @objc private func tickClicked(_ sender: NSButton) {
        let percent = Double(sender.tag * 10)
        slider.doubleValue = percent
        onChange?(percent)
    }
}
