import CoreGraphics
import Foundation

enum DockEdge: String, Codable, CaseIterable {
    case top, bottom, left, right

    var isVertical: Bool {
        self == .left || self == .right
    }
}

/// Layout in viewport coordinates, with the origin at the top-left corner.
enum DockGeometry {
    static func center(
        for edge: DockEdge,
        in viewport: CGSize,
        dockSize: CGSize,
        inset: CGFloat = 14
    ) -> CGPoint {
        let width = max(0, viewport.width)
        let height = max(0, viewport.height)
        let margin = max(0, inset)
        let halfWidth = max(0, dockSize.width) / 2
        let halfHeight = max(0, dockSize.height) / 2
        let point: CGPoint
        switch edge {
        case .top:
            point = CGPoint(x: width / 2, y: margin + halfHeight)
        case .bottom:
            point = CGPoint(x: width / 2, y: height - margin - halfHeight)
        case .left:
            point = CGPoint(x: margin + halfWidth, y: height / 2)
        case .right:
            point = CGPoint(x: width - margin - halfWidth, y: height / 2)
        }
        return clampedCenter(point, in: viewport, dockSize: dockSize, inset: margin)
    }

    static func nearestEdge(
        to point: CGPoint,
        in viewport: CGSize,
        preferred: DockEdge
    ) -> DockEdge {
        let width = max(0, viewport.width)
        let height = max(0, viewport.height)
        let x = min(max(0, point.x), width)
        let y = min(max(0, point.y), height)
        func distance(to edge: DockEdge) -> CGFloat {
            switch edge {
            case .top: return y
            case .bottom: return height - y
            case .left: return x
            case .right: return width - x
            }
        }

        // CaseIterable order gives an explicit, repeatable result for other exact ties.
        let closest = DockEdge.allCases.reduce(DockEdge.top) { best, candidate in
            distance(to: candidate) < distance(to: best) ? candidate : best
        }
        return distance(to: preferred) <= distance(to: closest) + 16 ? preferred : closest
    }

    static func clampedCenter(
        _ point: CGPoint,
        in viewport: CGSize,
        dockSize: CGSize,
        inset: CGFloat = 8
    ) -> CGPoint {
        func clamp(_ value: CGFloat, viewportLength: CGFloat, dockLength: CGFloat) -> CGFloat {
            let length = max(0, viewportLength)
            let padding = max(0, dockLength) / 2 + max(0, inset)
            // If the requested margins cannot fit, center the dock along this axis.
            guard length >= padding * 2 else { return length / 2 }
            return min(max(value, padding), length - padding)
        }
        return CGPoint(
            x: clamp(point.x, viewportLength: viewport.width, dockLength: dockSize.width),
            y: clamp(point.y, viewportLength: viewport.height, dockLength: dockSize.height)
        )
    }
}
