import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum BackgroundImageStore {
    static let maxStoredPixelSize: CGFloat = 2048

    static var directory: URL {
        let url = AppGroup.containerURL.appending(path: "Backgrounds", directoryHint: .isDirectory)
        if !FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func url(for id: String) -> URL {
        directory.appending(path: "\(id).jpg")
    }

    static func save(_ data: Data) throws -> String {
        guard let image = downsample(source: CGImageSourceCreateWithData(data as CFData, nil), maxPixelSize: maxStoredPixelSize) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let id = UUID().uuidString
        let destinationURL = url(for: id)
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return id
    }

    static func image(for id: String, maxPixelSize: CGFloat) -> UIImage? {
        let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil)
        return downsample(source: source, maxPixelSize: maxPixelSize).map { UIImage(cgImage: $0) }
    }

    static func framedImage(for id: String, framing: BackgroundFraming, containerSize: CGSize, pixelsPerPoint: CGFloat) -> UIImage? {
        guard containerSize.width > 0, containerSize.height > 0,
              let source = CGImageSourceCreateWithURL(url(for: id) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }

        let rect = framing.visibleRect(imageSize: CGSize(width: pixelWidth, height: pixelHeight), containerSize: containerSize)
        let neededWidth = containerSize.width * pixelsPerPoint / max(rect.width, 0.01)
        let neededHeight = containerSize.height * pixelsPerPoint / max(rect.height, 0.01)
        let maxPixel = min(1_600, max(neededWidth, neededHeight))
        guard let decoded = downsample(source: source, maxPixelSize: maxPixel) else { return nil }

        let width = CGFloat(decoded.width)
        let height = CGFloat(decoded.height)
        let crop = CGRect(x: rect.minX * width, y: rect.minY * height, width: rect.width * width, height: rect.height * height).integral
        guard let cropped = decoded.cropping(to: crop) else { return UIImage(cgImage: decoded) }
        return UIImage(cgImage: cropped)
    }

    /// Saves a rotated copy as a new photo and returns its id. The original is left for the caller to drop.
    static func saveRotated(_ id: String, quarterTurns: Int) -> String? {
        guard let rotated = image(for: id, maxPixelSize: maxStoredPixelSize)?.rotated(quarterTurns: quarterTurns),
              let data = rotated.jpegData(compressionQuality: 0.9) else { return nil }
        return try? save(data)
    }

    static func removeUnreferenced(keeping ids: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.pathExtension == "jpg" && !ids.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
    }

    static func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private static func downsample(source: CGImageSource?, maxPixelSize: CGFloat) -> CGImage? {
        guard let source else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

extension UIImage {
    func rotated(quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return self }
        let newSize = turns % 2 == 1 ? CGSize(width: size.height, height: size.width) : size
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: CGFloat(turns) * .pi / 2)
            draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }
}
