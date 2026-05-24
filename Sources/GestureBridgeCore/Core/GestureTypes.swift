import CoreGraphics
import Foundation

enum Direction: String, Equatable {
    case left = "L"
    case right = "R"
    case up = "U"
    case down = "D"

    static func classify(dx: CGFloat, dy: CGFloat, jitterTolerance: CGFloat) -> Direction? {
        let absX = abs(dx)
        let absY = abs(dy)

        guard max(absX, absY) >= jitterTolerance else {
            return nil
        }

        if absX >= absY {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}

enum GesturePhase: Equatable {
    case down
    case dragged
    case up
}

struct GestureSession {
    let bundleId: String
    let startPoint: CGPoint
    var lastPoint: CGPoint
    let startedAt: Date
    let originalDownEvent: CGEvent
    var points: [CGPoint]
    var directions: [Direction]
    var didExceedThreshold: Bool

    var token: String {
        directions.map(\.rawValue).joined()
    }
}

struct GestureOverlaySnapshot: Equatable {
    var points: [CGPoint]
    var token: String
    var actionLabel: String?
    var didExceedThreshold: Bool

    var currentPoint: CGPoint? {
        points.last
    }
}

enum GestureDecision: Equatable {
    case passThrough
    case swallow
    case dispatch(GestureAction)
    case replayClick(originalDown: CGEvent, up: CGEvent)

    static func == (lhs: GestureDecision, rhs: GestureDecision) -> Bool {
        switch (lhs, rhs) {
        case (.passThrough, .passThrough), (.swallow, .swallow):
            return true
        case (.dispatch(let left), .dispatch(let right)):
            return left == right
        case (.replayClick, .replayClick):
            return true
        default:
            return false
        }
    }
}
