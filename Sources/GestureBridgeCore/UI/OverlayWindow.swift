import AppKit
import SwiftUI

protocol GestureOverlayControlling: AnyObject {
    func show(snapshot: GestureOverlaySnapshot)
    func hide(after delay: TimeInterval)
    func hideImmediately()
}

final class OverlayWindowController: GestureOverlayControlling {
    private let model = GestureOverlayModel()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    func show(snapshot: GestureOverlaySnapshot) {
        hideWorkItem?.cancel()

        if panel == nil {
            panel = makePanel()
        }

        model.snapshot = snapshot
        positionPanel(near: snapshot.currentPoint)
        panel?.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval = 0.2) {
        hideWorkItem?.cancel()

        let item = DispatchWorkItem { [weak self] in
            self?.hideImmediately()
        }

        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func hideImmediately() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 236, height: 154),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView: GestureOverlayView(model: model))
        return panel
    }

    private func positionPanel(near point: CGPoint?) {
        guard let panel else { return }

        let panelSize = panel.frame.size
        let screenPoint = point.map(Self.appKitScreenPoint(from:)) ?? NSEvent.mouseLocation
        let screen = Self.screen(containing: screenPoint) ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin: CGPoint

        if let point {
            let screenPoint = Self.appKitScreenPoint(from: point)
            let proposed = CGPoint(
                x: screenPoint.x + 22,
                y: screenPoint.y - panelSize.height - 22
            )

            origin = CGPoint(
                x: min(max(proposed.x, visibleFrame.minX + 12), visibleFrame.maxX - panelSize.width - 12),
                y: min(max(proposed.y, visibleFrame.minY + 12), visibleFrame.maxY - panelSize.height - 12)
            )
        } else {
            origin = CGPoint(
                x: visibleFrame.midX - panelSize.width / 2,
                y: visibleFrame.maxY - panelSize.height - 72
            )
        }

        panel.setFrameOrigin(origin)
    }

    private static func appKitScreenPoint(from eventPoint: CGPoint) -> CGPoint {
        let primaryScreen = NSScreen.screens.first ?? NSScreen.main
        let primaryHeight = primaryScreen?.frame.height ?? 0

        return CGPoint(
            x: eventPoint.x,
            y: primaryHeight - eventPoint.y
        )
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            screen.frame.insetBy(dx: -1, dy: -1).contains(point)
        }
    }
}

private final class GestureOverlayModel: ObservableObject {
    @Published var snapshot = GestureOverlaySnapshot(
        points: [],
        token: "",
        actionLabel: nil,
        didExceedThreshold: false
    )
}

private struct GestureOverlayView: View {
    @ObservedObject var model: GestureOverlayModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(model.snapshot.token.isEmpty ? "..." : model.snapshot.token)
                    .font(.system(size: 30, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                Text(model.snapshot.didExceedThreshold ? "Active" : "Ready")
                    .font(.caption)
                    .foregroundStyle(model.snapshot.didExceedThreshold ? .green : .secondary)
            }

            GesturePathPreview(points: model.snapshot.points)
                .frame(height: 58)

            Text(model.snapshot.actionLabel ?? "No action matched")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.snapshot.actionLabel == nil ? .secondary : .primary)
                .lineLimit(1)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

private struct GesturePathPreview: View {
    let points: [CGPoint]

    var body: some View {
        Canvas { context, size in
            guard points.count > 1 else {
                let rect = CGRect(x: size.width / 2 - 2, y: size.height / 2 - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: rect), with: .color(.secondary))
                return
            }

            let normalized = normalize(points: points, in: size)
            var path = Path()
            path.move(to: normalized[0])

            for point in normalized.dropFirst() {
                path.addLine(to: point)
            }

            context.stroke(
                path,
                with: .color(.accentColor),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )

            if let first = normalized.first {
                context.fill(Path(ellipseIn: centeredRect(at: first, size: 6)), with: .color(.secondary))
            }

            if let last = normalized.last {
                context.fill(Path(ellipseIn: centeredRect(at: last, size: 8)), with: .color(.accentColor))
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private func normalize(points: [CGPoint], in size: CGSize) -> [CGPoint] {
        let minX = points.map(\.x).min() ?? 0
        let maxX = points.map(\.x).max() ?? 1
        let minY = points.map(\.y).min() ?? 0
        let maxY = points.map(\.y).max() ?? 1
        let width = max(maxX - minX, 1)
        let height = max(maxY - minY, 1)
        let inset: CGFloat = 12
        let scale = min((size.width - inset * 2) / width, (size.height - inset * 2) / height)

        return points.map { point in
            CGPoint(
                x: (point.x - minX) * scale + inset,
                y: (point.y - minY) * scale + inset
            )
        }
    }

    private func centeredRect(at point: CGPoint, size: CGFloat) -> CGRect {
        CGRect(
            x: point.x - size / 2,
            y: point.y - size / 2,
            width: size,
            height: size
        )
    }
}
