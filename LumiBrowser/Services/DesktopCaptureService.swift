import Foundation
import AppKit
import CoreGraphics

// MARK: - Desktop Capture Service
// Captures the primary display at ~30fps using CGDisplayCreateImage.
// Forwards synthetic mouse/keyboard events via CGEvent (requires Accessibility permission).
// Screen recording permission is requested via CGRequestScreenCaptureAccess().
final class DesktopCaptureService: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var isCapturing: Bool = false
    @Published var hasScreenPermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    private var captureTimer: DispatchSourceTimer?
    private let captureQueue = DispatchQueue(label: "com.lumi.desktop-capture", qos: .userInteractive)
    let targetFPS: Double = 30

    init() {
        refreshPermissions()
    }

    // MARK: - Permissions

    func refreshPermissions() {
        hasScreenPermission = CGPreflightScreenCaptureAccess()
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func requestScreenPermission() {
        CGRequestScreenCaptureAccess()
        // Re-check after a brief delay (the system prompt is async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            self.hasScreenPermission = CGPreflightScreenCaptureAccess()
            if self.hasScreenPermission && !self.isCapturing {
                self.startCapture()
            }
        }
    }

    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.hasAccessibilityPermission = AXIsProcessTrusted()
        }
    }

    // MARK: - Capture Lifecycle

    func startCapture() {
        guard hasScreenPermission, !isCapturing else { return }
        isCapturing = true

        let timer = DispatchSource.makeTimerSource(queue: captureQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / targetFPS, leeway: .milliseconds(5))
        timer.setEventHandler { [weak self] in
            self?.captureFrame()
        }
        timer.resume()
        captureTimer = timer
    }

    func stopCapture() {
        captureTimer?.cancel()
        captureTimer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isCapturing = false
            self?.currentFrame = nil
        }
    }

    private func captureFrame() {
        let displayID = CGMainDisplayID()
        guard let image = CGDisplayCreateImage(displayID) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
        }
    }

    // MARK: - Screen Geometry

    /// Logical (point) size of the primary display — used for CGEvent coordinates
    var screenLogicalSize: CGSize {
        CGDisplayBounds(CGMainDisplayID()).size
    }

    /// Computes where the screen image appears inside a view of `viewSize`
    /// when displayed with .aspectRatio(contentMode: .fit)
    func imageRect(in viewSize: CGSize) -> CGRect {
        let scr = screenLogicalSize
        let screenAspect = scr.width / scr.height
        let viewAspect = viewSize.width / viewSize.height
        if screenAspect > viewAspect {
            let h = viewSize.width / screenAspect
            return CGRect(x: 0, y: (viewSize.height - h) / 2, width: viewSize.width, height: h)
        } else {
            let w = viewSize.height * screenAspect
            return CGRect(x: (viewSize.width - w) / 2, y: 0, width: w, height: viewSize.height)
        }
    }

    /// Convert a point inside the view (top-left origin) to logical screen coordinates
    func viewToScreen(_ viewPoint: CGPoint, in imageRect: CGRect) -> CGPoint? {
        guard imageRect.contains(viewPoint) else { return nil }
        let scr = screenLogicalSize
        let relX = (viewPoint.x - imageRect.minX) / imageRect.width
        let relY = (viewPoint.y - imageRect.minY) / imageRect.height
        return CGPoint(
            x: max(0, min(scr.width - 1,  relX * scr.width)),
            y: max(0, min(scr.height - 1, relY * scr.height))
        )
    }

    // MARK: - Synthetic Mouse Events (requires Accessibility permission)

    func sendMouseMove(to point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func sendLeftMouseDown(at point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func sendLeftMouseUp(at point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func sendLeftMouseDragged(to point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged,
                mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    func sendRightMouseDown(at point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown,
                mouseCursorPosition: point, mouseButton: .right)?.post(tap: .cghidEventTap)
    }

    func sendRightMouseUp(at point: CGPoint) {
        guard hasAccessibilityPermission else { return }
        CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp,
                mouseCursorPosition: point, mouseButton: .right)?.post(tap: .cghidEventTap)
    }

    func sendScroll(deltaX: Int32, deltaY: Int32) {
        guard hasAccessibilityPermission else { return }
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                wheelCount: 2, wheel1: deltaY, wheel2: deltaX, wheel3: 0)?.post(tap: .cghidEventTap)
    }
}
