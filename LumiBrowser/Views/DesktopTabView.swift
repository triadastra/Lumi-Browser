import SwiftUI
import AppKit

// MARK: - Desktop Tab View
// Shows a live capture of the primary display.
// Clicking the screen activates "Control Mode": all mouse/keyboard events are
// forwarded to the actual desktop via CGEvent. Press ESC (or the toolbar button)
// to exit Control Mode and return to browser navigation.

struct DesktopTabView: View {
    @StateObject private var capture = DesktopCaptureService()
    @State private var isControlMode = false
    @State private var cursorViewPos: CGPoint = .zero
    @State private var isCursorInside = false
    @State private var isDragging = false
    @State private var viewSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                if !capture.hasScreenPermission {
                    // Step 1: Permission prompt
                    DesktopPermissionView(capture: capture)
                } else {
                    // Live screen content
                    let imgRect = capture.imageRect(in: geo.size)

                    ZStack {
                        if let frame = capture.currentFrame {
                            Image(decorative: frame, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            ProgressView("Loading desktop…")
                                .foregroundColor(.white)
                        }

                        // Virtual cursor ring (shows where clicks will land)
                        if isControlMode && isCursorInside && imgRect.contains(cursorViewPos) {
                            ZStack {
                                Circle()
                                    .strokeBorder(Color.white, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                    .shadow(color: .black.opacity(0.5), radius: 4)
                                Circle()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 22, height: 22)
                            }
                            .position(cursorViewPos)
                            .allowsHitTesting(false)
                            .animation(.none, value: cursorViewPos)
                        }

                        // Transparent NSView overlay: captures mouse/keyboard events
                        DesktopInteractionLayer(
                            isActive: isControlMode,
                            onMouseMoved: { pt in
                                cursorViewPos = pt
                                isCursorInside = true
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendMouseMove(to: screenPt)
                                }
                            },
                            onMouseEntered: { isCursorInside = true },
                            onMouseExited: { isCursorInside = false },
                            onLeftDown: { pt in
                                isDragging = true
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendLeftMouseDown(at: screenPt)
                                }
                            },
                            onLeftUp: { pt in
                                isDragging = false
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendLeftMouseUp(at: screenPt)
                                }
                            },
                            onLeftDragged: { pt in
                                cursorViewPos = pt
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendLeftMouseDragged(to: screenPt)
                                }
                            },
                            onRightDown: { pt in
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendRightMouseDown(at: screenPt)
                                }
                            },
                            onRightUp: { pt in
                                if let screenPt = capture.viewToScreen(pt, in: imgRect) {
                                    capture.sendRightMouseUp(at: screenPt)
                                }
                            },
                            onScroll: { dx, dy in
                                capture.sendScroll(deltaX: Int32(dx), deltaY: Int32(dy))
                            },
                            onClickToActivate: {
                                withAnimation(.easeInOut(duration: 0.15)) { isControlMode = true }
                            },
                            onEscape: {
                                withAnimation(.easeInOut(duration: 0.15)) { isControlMode = false }
                            }
                        )
                    }
                }

                // MARK: - Status Overlays

                VStack(spacing: 0) {
                    // Control mode banner
                    if isControlMode {
                        HStack(spacing: 10) {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 7, height: 7)
                                Text("Desktop Control Active")
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            if !capture.hasAccessibilityPermission {
                                Button("Grant Accessibility Access") {
                                    capture.requestAccessibilityPermission()
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.mini)
                                .tint(.orange)
                            }

                            Button("Stop (ESC)") {
                                withAnimation(.easeInOut(duration: 0.15)) { isControlMode = false }
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(Color.white.opacity(0.2))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.9))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    Spacer()

                    // "Click to control" hint
                    if !isControlMode && capture.hasScreenPermission && capture.currentFrame != nil {
                        HStack(spacing: 6) {
                            Image(systemName: "cursorarrow.click")
                                .font(.caption)
                            Text("Click anywhere to control the desktop")
                                .font(.caption)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isControlMode)
            }
            .onAppear {
                capture.refreshPermissions()
                if capture.hasScreenPermission {
                    capture.startCapture()
                }
            }
            .onDisappear {
                capture.stopCapture()
                isControlMode = false
            }
        }
    }
}

// MARK: - Permission Setup View

struct DesktopPermissionView: View {
    @ObservedObject var capture: DesktopCaptureService

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            // Monitor icon
            Image(systemName: "desktopcomputer")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(spacing: 8) {
                Text("Desktop Viewer & Controller")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("View and control your macOS desktop inside this browser tab.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Permission cards
            VStack(spacing: 12) {
                PermissionCard(
                    icon: "eye.circle.fill",
                    iconColor: .blue,
                    title: "Screen Recording",
                    detail: "Lets Lumi display your live desktop in this tab",
                    isGranted: capture.hasScreenPermission,
                    buttonLabel: "Grant Screen Recording",
                    action: { capture.requestScreenPermission() }
                )

                PermissionCard(
                    icon: "cursorarrow.click.2",
                    iconColor: .purple,
                    title: "Accessibility Access",
                    detail: "Lets Lumi send clicks and keystrokes to your desktop",
                    isGranted: capture.hasAccessibilityPermission,
                    buttonLabel: "Grant Accessibility",
                    action: { capture.requestAccessibilityPermission() }
                )
            }
            .frame(maxWidth: 520)

            if capture.hasScreenPermission {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                    Text("Screen recording granted — loading desktop…")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }

            Spacer()
        }
        .padding(40)
        // Poll for permission changes (e.g. after user grants in System Settings)
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            capture.refreshPermissions()
        }
    }
}

struct PermissionCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let detail: String
    let isGranted: Bool
    let buttonLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : icon)
                .font(.system(size: 26))
                .foregroundColor(isGranted ? .green : iconColor)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isGranted {
                Button(buttonLabel, action: action)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(iconColor)
            } else {
                Text("Granted")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            isGranted ? Color.green.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1
        ))
    }
}

// MARK: - NSView Interaction Layer
// Uses a transparent NSView on top of the screen image to capture all
// mouse and keyboard events with proper coordinate handling (AppKit uses
// bottom-left origin, so we flip Y to match SwiftUI's top-left origin).

struct DesktopInteractionLayer: NSViewRepresentable {
    let isActive: Bool

    var onMouseMoved: (CGPoint) -> Void
    var onMouseEntered: () -> Void
    var onMouseExited: () -> Void
    var onLeftDown: (CGPoint) -> Void
    var onLeftUp: (CGPoint) -> Void
    var onLeftDragged: (CGPoint) -> Void
    var onRightDown: (CGPoint) -> Void
    var onRightUp: (CGPoint) -> Void
    var onScroll: (Int32, Int32) -> Void
    var onClickToActivate: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> DesktopEventView {
        let view = DesktopEventView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: DesktopEventView, context: Context) {
        nsView.isActive = isActive
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator {
        var parent: DesktopInteractionLayer
        init(parent: DesktopInteractionLayer) { self.parent = parent }
    }
}

// MARK: - DesktopEventView (NSView subclass)

final class DesktopEventView: NSView {
    weak var coordinator: DesktopInteractionLayer.Coordinator?
    var isActive = false

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    // Convert AppKit window coords (bottom-left origin) → view → top-left origin
    private func swiftUIPoint(from event: NSEvent) -> CGPoint {
        let loc = convert(event.locationInWindow, from: nil)
        return CGPoint(x: loc.x, y: bounds.height - loc.y)
    }

    override func mouseMoved(with event: NSEvent) {
        guard isActive else { return }
        coordinator?.parent.onMouseMoved(swiftUIPoint(from: event))
    }

    override func mouseEntered(with event: NSEvent) {
        coordinator?.parent.onMouseEntered()
        if isActive { NSCursor.crosshair.push() }
    }

    override func mouseExited(with event: NSEvent) {
        coordinator?.parent.onMouseExited()
        if isActive { NSCursor.pop() }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = swiftUIPoint(from: event)
        if isActive {
            coordinator?.parent.onLeftDown(pt)
        } else {
            coordinator?.parent.onClickToActivate()
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard isActive else { return }
        coordinator?.parent.onLeftUp(swiftUIPoint(from: event))
    }

    override func mouseDragged(with event: NSEvent) {
        guard isActive else { return }
        coordinator?.parent.onLeftDragged(swiftUIPoint(from: event))
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isActive else { return }
        coordinator?.parent.onRightDown(swiftUIPoint(from: event))
    }

    override func rightMouseUp(with event: NSEvent) {
        guard isActive else { return }
        coordinator?.parent.onRightUp(swiftUIPoint(from: event))
    }

    override func scrollWheel(with event: NSEvent) {
        guard isActive else { return }
        let dx = Int32(event.scrollingDeltaX)
        let dy = Int32(event.scrollingDeltaY)
        coordinator?.parent.onScroll(dx, dy)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC
            coordinator?.parent.onEscape()
        }
        // Other keys could be forwarded via CGEvent if needed
    }

    override func cursorUpdate(with event: NSEvent) {
        if isActive { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
    }

    // Make the view transparent so the SwiftUI image shows through
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}
