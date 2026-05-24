import CoreGraphics

extension TriggerConfig {
    static let defaultOtherButtonNumber = 3

    var resolvedOtherButtonNumber: Int {
        max(Self.defaultOtherButtonNumber, otherButtonNumber ?? Self.defaultOtherButtonNumber)
    }

    var triggerDescription: String {
        var parts: [String] = []

        if !requiredModifiers.isEmpty {
            parts.append(
                ModifierKey.displayOrder
                    .filter { requiredModifiers.contains($0) }
                    .map(\.symbol)
                    .joined()
            )
        }

        switch button {
        case .right:
            parts.append(MouseButton.right.displayName)
        case .middle:
            parts.append(MouseButton.middle.displayName)
        case .other:
            parts.append("Mouse button \(resolvedOtherButtonNumber)")
        case .altLeftDrag:
            parts.append(MouseButton.altLeftDrag.displayName)
        }

        return parts.joined(separator: " + ")
    }

    func gesturePhase(
        for type: CGEventType,
        event: CGEvent,
        requireModifiers: Bool = true
    ) -> GesturePhase? {
        guard !requireModifiers || hasRequiredModifiers(event.flags) else {
            return nil
        }

        switch button {
        case .right:
            return rightMousePhase(for: type)
        case .middle:
            guard otherMouseButtonNumber(for: type, event: event) == 2 else {
                return nil
            }

            return otherMousePhase(for: type)
        case .other:
            guard otherMouseButtonNumber(for: type, event: event) == resolvedOtherButtonNumber else {
                return nil
            }

            return otherMousePhase(for: type)
        case .altLeftDrag:
            return nil
        }
    }

    private func hasRequiredModifiers(_ flags: CGEventFlags) -> Bool {
        let requiredFlags = CGEventFlags.from(requiredModifiers)
        return flags.intersection(requiredFlags) == requiredFlags
    }

    private func rightMousePhase(for type: CGEventType) -> GesturePhase? {
        switch type {
        case .rightMouseDown:
            return .down
        case .rightMouseDragged:
            return .dragged
        case .rightMouseUp:
            return .up
        default:
            return nil
        }
    }

    private func otherMousePhase(for type: CGEventType) -> GesturePhase? {
        switch type {
        case .otherMouseDown:
            return .down
        case .otherMouseDragged:
            return .dragged
        case .otherMouseUp:
            return .up
        default:
            return nil
        }
    }

    private func otherMouseButtonNumber(for type: CGEventType, event: CGEvent) -> Int? {
        guard otherMousePhase(for: type) != nil else {
            return nil
        }

        return Int(event.getIntegerValueField(.mouseEventButtonNumber))
    }
}
