import CoreGraphics
import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self { case .assertion(let message): return message }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.assertion(message) }
}

@main
private struct DockGeometryTests {
    static func main() throws {
        let viewport = CGSize(width: 800, height: 600)
        let horizontalDock = CGSize(width: 240, height: 60)
        let verticalDock = CGSize(width: 60, height: 240)
        let expectedCenters: [DockEdge: CGPoint] = [
            .top: CGPoint(x: 400, y: 44),
            .bottom: CGPoint(x: 400, y: 556),
            .left: CGPoint(x: 44, y: 300),
            .right: CGPoint(x: 756, y: 300),
        ]
        for edge in DockEdge.allCases {
            try expect(edge.isVertical == (edge == .left || edge == .right), "Incorrect axis for \(edge)")
            let dockSize = edge.isVertical ? verticalDock : horizontalDock
            let center = DockGeometry.center(for: edge, in: viewport, dockSize: dockSize)
            try expect(center == expectedCenters[edge], "Incorrect center for \(edge): \(center)")
            try expect(DockGeometry.nearestEdge(to: center, in: viewport, preferred: .top) == edge,
                       "Failed to find \(edge) from its dock center")
            let encoded = try JSONEncoder().encode(edge)
            let decoded = try JSONDecoder().decode(DockEdge.self, from: encoded)
            try expect(decoded == edge, "Persisted edge did not roundtrip")
        }

        // All edges are equidistant in a square viewport, so the current edge wins.
        let square = CGSize(width: 400, height: 400)
        for edge in DockEdge.allCases {
            try expect(DockGeometry.nearestEdge(to: CGPoint(x: 200, y: 200), in: square, preferred: edge) == edge,
                       "Center tie did not preserve \(edge)")
        }
        let corners: [(CGPoint, DockEdge, DockEdge)] = [
            (.zero, .top, .left),
            (CGPoint(x: 400, y: 0), .top, .right),
            (CGPoint(x: 0, y: 400), .bottom, .left),
            (CGPoint(x: 400, y: 400), .bottom, .right),
        ]
        for (corner, first, second) in corners {
            for preferred in [first, second] {
                try expect(DockGeometry.nearestEdge(to: corner, in: square, preferred: preferred) == preferred,
                           "Corner tie did not preserve \(preferred)")
            }
        }
        try expect(DockGeometry.nearestEdge(to: .zero, in: square, preferred: .bottom) == .top,
                   "Unrelated corner tie should use stable edge order")
        try expect(DockGeometry.nearestEdge(to: CGPoint(x: 20, y: 36), in: square, preferred: .top) == .top,
                   "16-point hysteresis should preserve the current edge")
        try expect(DockGeometry.nearestEdge(to: CGPoint(x: 20, y: 37), in: square, preferred: .top) == .left,
                   "Movement beyond hysteresis should change the edge")

        let outside: [(CGPoint, DockEdge)] = [
            (CGPoint(x: -100, y: 300), .left),
            (CGPoint(x: 1000, y: 300), .right),
            (CGPoint(x: 400, y: -100), .top),
            (CGPoint(x: 400, y: 800), .bottom),
        ]
        for (point, expected) in outside {
            try expect(DockGeometry.nearestEdge(to: point, in: viewport, preferred: .top) == expected,
                       "Wrong edge for offscreen point \(point)")
        }
        try expect(DockGeometry.nearestEdge(to: CGPoint(x: -100, y: -200), in: viewport, preferred: .left) == .left,
                   "Offscreen corner should preserve an adjacent edge")

        try expect(DockGeometry.clampedCenter(CGPoint(x: -300, y: 900), in: viewport, dockSize: horizontalDock)
                   == CGPoint(x: 128, y: 562), "Offscreen center did not respect default margins")
        try expect(DockGeometry.clampedCenter(CGPoint(x: 400, y: 300), in: viewport, dockSize: horizontalDock)
                   == CGPoint(x: 400, y: 300), "An interior center should not move")
        try expect(DockGeometry.center(for: .right, in: viewport, dockSize: verticalDock, inset: 24)
                   == CGPoint(x: 746, y: 300), "Custom edge inset ignored")
        try expect(DockGeometry.clampedCenter(CGPoint(x: -100, y: -100), in: viewport, dockSize: horizontalDock, inset: -5)
                   == CGPoint(x: 120, y: 30), "Negative inset should behave like zero")

        let smallViewport = CGSize(width: 100, height: 40)
        for edge in DockEdge.allCases {
            try expect(DockGeometry.center(for: edge, in: smallViewport, dockSize: horizontalDock)
                       == CGPoint(x: 50, y: 20), "Oversized dock should center for \(edge)")
        }
        try expect(DockGeometry.clampedCenter(CGPoint(x: 999, y: -999), in: CGSize(width: 100, height: 600), dockSize: horizontalDock)
                   == CGPoint(x: 50, y: 38), "Only the undersized axis should be centered")
        try expect(DockGeometry.clampedCenter(CGPoint(x: 99, y: 99), in: .zero, dockSize: verticalDock) == .zero,
                   "Zero viewport should produce the origin")
        try expect(DockGeometry.center(for: .top, in: CGSize(width: 256, height: 76), dockSize: horizontalDock, inset: 8)
                   == CGPoint(x: 128, y: 38), "An exact-fitting dock should have exact margins")

        print("PASS: dock edges and axes, persisted edges, preferred corner ties, 16-point hysteresis, offscreen snapping, margins and undersized viewports.")
    }
}
