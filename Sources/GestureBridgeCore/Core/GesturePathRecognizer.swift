import CoreGraphics

struct GesturePathState: Equatable {
    var startPoint: CGPoint
    var lastPoint: CGPoint
    var directions: [Direction]
    var didExceedThreshold: Bool

    var token: String {
        directions.map(\.rawValue).joined()
    }
}

enum GesturePathRecognizer {
    static func begin(at point: CGPoint) -> GesturePathState {
        GesturePathState(
            startPoint: point,
            lastPoint: point,
            directions: [],
            didExceedThreshold: false
        )
    }

    static func append(
        point: CGPoint,
        to state: inout GesturePathState,
        config: RecognitionConfig
    ) {
        let dx = point.x - state.lastPoint.x
        let dy = point.y - state.lastPoint.y
        let distance = hypot(dx, dy)

        if distance >= config.segmentThresholdPx,
           let direction = Direction.classify(
                dx: dx,
                dy: dy,
                jitterTolerance: config.jitterTolerancePx
           ) {
            if state.directions.last != direction {
                state.directions.append(direction)
            }

            state.lastPoint = point
        }

        let totalDistance = hypot(
            point.x - state.startPoint.x,
            point.y - state.startPoint.y
        )

        if totalDistance >= config.minimumMovementPx {
            state.didExceedThreshold = true
        }
    }

    static func token(
        for points: [CGPoint],
        config: RecognitionConfig
    ) -> String {
        guard let first = points.first else {
            return ""
        }

        var state = begin(at: first)

        for point in points.dropFirst() {
            append(point: point, to: &state, config: config)
        }

        return state.didExceedThreshold ? state.token : ""
    }
}
