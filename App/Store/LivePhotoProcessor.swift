import Accelerate
import AVFoundation
import Photos
import PhotosUI
import UIKit

enum LivePhotoProcessor {
    enum ProcessingError: Error {
        case missingVideo
        case noFrames
    }

    static func pairedVideoURL(for livePhoto: PHLivePhoto) async throws -> URL {
        let resources = PHAssetResource.assetResources(for: livePhoto)
        guard let video = resources.first(where: { $0.type == .pairedVideo }) else {
            throw ProcessingError.missingVideo
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
        try await PHAssetResourceManager.default().writeData(for: video, toFile: url, options: nil)
        return url
    }

    static func duration(of url: URL) async throws -> Double {
        try await AVURLAsset(url: url).load(.duration).seconds
    }

    static func frame(from url: URL, at seconds: Double, maxDimension: CGFloat = 2048) async throws -> UIImage {
        let generator = makeGenerator(for: url, maxDimension: maxDimension, exact: true)
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        return UIImage(cgImage: image)
    }

    static func thumbnails(from url: URL, count: Int) async -> [UIImage] {
        guard let duration = try? await duration(of: url), duration > 0 else { return [] }
        let generator = makeGenerator(for: url, maxDimension: 160, exact: false)
        var images: [UIImage] = []
        for index in 0..<count {
            let seconds = duration * Double(index) / Double(max(count - 1, 1))
            if let result = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)) {
                images.append(UIImage(cgImage: result.image))
            }
        }
        return images
    }

    static func longExposure(from url: URL, frameCount: Int = 40, maxDimension: CGFloat = 1440) async throws -> UIImage {
        let duration = try await duration(of: url)
        let generator = makeGenerator(for: url, maxDimension: maxDimension, exact: false)

        var width = 0
        var height = 0
        var accumulator: [Float] = []
        var frameValues: [Float] = []
        var bytes: [UInt8] = []
        var count = 0

        for index in 0..<frameCount {
            let seconds = duration * Double(index) / Double(max(frameCount - 1, 1))
            guard let image = try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image else { continue }
            if width == 0 {
                width = image.width
                height = image.height
                accumulator = [Float](repeating: 0, count: width * height * 4)
                frameValues = accumulator
                bytes = [UInt8](repeating: 0, count: width * height * 4)
            }
            guard image.width == width, image.height == height else { continue }
            draw(image, into: &bytes, width: width, height: height)
            vDSP.convertElements(of: bytes, to: &frameValues)
            vDSP.add(accumulator, frameValues, result: &accumulator)
            count += 1
        }

        guard count > 0 else { throw ProcessingError.noFrames }
        vDSP.divide(accumulator, Float(count), result: &accumulator)
        vDSP.convertElements(of: accumulator, to: &bytes, rounding: .towardNearestInteger)

        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let result = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else { throw ProcessingError.noFrames }
        return UIImage(cgImage: result)
    }

    private static func makeGenerator(for url: URL, maxDimension: CGFloat, exact: Bool) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maxDimension, height: maxDimension)
        if exact {
            generator.requestedTimeToleranceBefore = .zero
            generator.requestedTimeToleranceAfter = .zero
        }
        return generator
    }

    private static func draw(_ image: CGImage, into bytes: inout [UInt8], width: Int, height: Int) {
        bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
