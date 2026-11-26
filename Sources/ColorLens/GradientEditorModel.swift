import SwiftUI
import ColorCore

struct GradientStopDraft: Identifiable, Equatable {
    let id: UUID
    var text: String
    var format: HexFormat = .argb
    var position: Double
    var color: ColorValue? { ColorValue.parse(text, format: format) }
    init(color: ColorValue, position: Double) {
        id = UUID(); text = color.hex(.argb); self.position = position
    }
}

@MainActor
final class GradientEditorModel: ObservableObject {
    @Published var stops: [GradientStopDraft]
    @Published var selectedID: UUID
    @Published var angle = 90.0

    init() {
        let values = [GradientStopDraft(color: .init(red: 0, green: 122, blue: 255), position: 0),
                      GradientStopDraft(color: .init(red: 255, green: 65, blue: 135), position: 100)]
        stops = values; selectedID = values[0].id
    }

    var selected: GradientStopDraft? { stops.first { $0.id == selectedID } }
    var ordered: [GradientStopDraft] {
        stops.enumerated().sorted {
            $0.element.position == $1.element.position ? $0.offset < $1.offset : $0.element.position < $1.element.position
        }.map(\.element)
    }
    var definition: LinearGradientDefinition? {
        let values = stops.compactMap { draft in draft.color.map { GradientStop(color: $0, location: draft.position/100) } }
        guard values.count == stops.count else { return nil }
        return LinearGradientDefinition(stops: values, angle: angle)
    }

    func updateSelected(_ change: (inout GradientStopDraft) -> Void) {
        guard let index = stops.firstIndex(where: { $0.id == selectedID }) else { return }
        change(&stops[index])
    }

    func setColor(_ color: ColorValue) {
        updateSelected {
            if $0.format == .rgb && color.alpha != 255 { $0.format = .argb }
            $0.text = color.hex($0.format)
        }
    }

    func add(color: ColorValue) {
        guard stops.count < 8 else { return }
        let positions = [0.0] + ordered.map(\.position) + [100.0]
        let gap = zip(positions, positions.dropFirst()).max { $0.1-$0.0 < $1.1-$1.0 }
        let stop = GradientStopDraft(color: color, position: ((gap?.0 ?? 0)+(gap?.1 ?? 100))/2)
        stops.append(stop); selectedID = stop.id
    }

    func removeSelected() {
        guard stops.count > 2 else { return }
        stops.removeAll { $0.id == selectedID }
        selectedID = ordered[0].id
    }

    func reverse() {
        stops = stops.reversed().map { value in
            var copy = value; copy.position = 100-value.position; return copy
        }
    }
}
