#if canImport(CoreGraphics)
import CoreGraphics
#endif
import Foundation

struct BackgroundFraming: Codable, Hashable {
    static let maximumZoom: Double = 4
    static let centered = BackgroundFraming()

    var focusX: Double = 0.5
    var focusY: Double = 0.5
    var zoom: Double = 1

    init(focusX: Double = 0.5, focusY: Double = 0.5, zoom: Double = 1) {
        self.focusX = min(max(focusX, 0), 1)
        self.focusY = min(max(focusY, 0), 1)
        self.zoom = min(max(zoom, 1), Self.maximumZoom)
    }

    func visibleRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        let fill = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height) * zoom
        let width = min(1, containerSize.width / (imageSize.width * fill))
        let height = min(1, containerSize.height / (imageSize.height * fill))
        let x = min(max(focusX - width / 2, 0), 1 - width)
        let y = min(max(focusY - height / 2, 0), 1 - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    func panned(by translation: CGSize, imageSize: CGSize, containerSize: CGSize) -> BackgroundFraming {
        let rect = visibleRect(imageSize: imageSize, containerSize: containerSize)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return BackgroundFraming(
            focusX: center.x - translation.width / containerSize.width * rect.width,
            focusY: center.y - translation.height / containerSize.height * rect.height,
            zoom: zoom
        )
    }

    func zoomed(to newZoom: Double, imageSize: CGSize, containerSize: CGSize) -> BackgroundFraming {
        let rect = visibleRect(imageSize: imageSize, containerSize: containerSize)
        return BackgroundFraming(focusX: rect.midX, focusY: rect.midY, zoom: newZoom)
    }
}
