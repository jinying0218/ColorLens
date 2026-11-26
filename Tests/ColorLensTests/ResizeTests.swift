import Testing
@testable import ColorLens

@Test
func opacityTicksRemainSpacedAndMatchTrackAfterResizing() {
    for width in [400.0, 564.0, 624.0, 900.0, 1320.0] {
        let metrics = OpacityTrackMetrics(width: width)
        let ticks = (0...10).map { metrics.x(for: Double($0*10)) }
        #expect(abs(ticks[0]-22) < 0.001)
        #expect(abs(ticks[10]-(width-22)) < 0.001)
        for index in 0..<10 { #expect(ticks[index+1] > ticks[index]) }
        for percent in 0...100 {
            #expect(abs(metrics.percent(at: metrics.x(for: Double(percent)))-Double(percent)) < 0.00001)
        }
        #expect(metrics.percent(at: -100) == 0)
        #expect(metrics.percent(at: width+100) == 100)
        #expect(abs(metrics.x(for: 50)-width/2) < 0.001)
    }
}
