import Testing
import ColorCore
@testable import ColorLens

@Test @MainActor
func gradientNodesAddIntoGapsAndRespectLimits() throws {
    let model = GradientEditorModel()
    let current = ColorValue(red: 22, green: 33, blue: 44, alpha: 128)
    model.add(color: current)
    #expect(model.selected?.position == 50)
    #expect(model.selected?.color == current)
    for _ in 0..<10 { model.add(color: current) }
    #expect(model.stops.count == 8)
    #expect(Set(model.stops.map(\.id)).count == 8)
    for _ in 0..<10 { model.removeSelected() }
    #expect(model.stops.count == 2)
    #expect(model.selected != nil)
}

@Test @MainActor
func gradientReversePreservesColorsAndReflectsPositions() throws {
    let model = GradientEditorModel()
    model.updateSelected { $0.position = 20 }
    let original = model.stops
    let selected = model.selectedID
    model.reverse()
    #expect(model.stops[1].id == original[0].id)
    #expect(model.stops[1].position == 80)
    #expect(model.selectedID == selected)
    model.reverse()
    #expect(model.stops == original)
}

@Test @MainActor
func invalidGradientColorDisablesDefinitionAndAlphaSurvivesRGBMode() throws {
    let model = GradientEditorModel()
    model.updateSelected { $0.text = "#WRONG" }
    #expect(model.definition == nil)
    model.updateSelected { $0.format = .rgb }
    let half = ColorValue(red: 255, green: 0, blue: 0, alpha: 128)
    model.setColor(half)
    #expect(model.selected?.format == .argb)
    #expect(model.selected?.color == half)
    #expect(model.definition != nil)
}
