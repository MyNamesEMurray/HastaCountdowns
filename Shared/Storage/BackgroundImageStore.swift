import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

enum BackgroundImageStore {
    static let maxStoredPixelSize: CGFloat = 1400

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

    static func delete(_ id: String) {
        try? FileManager.default.removeItem(at: url(for: id))
    }

    static func deleteUnused(keeping ids: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for file in files where !ids.contains(file.deletingPathExtension().lastPathComponent) {
            try? FileManager.default.removeItem(at: file)
        }
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
