import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Prepares a local meal photo for the photo-scanning endpoint.
public enum PhotoScanImage {
    /// Matches the food-photo treatment used by January's iOS application.
    public static let defaultMaxDimension = 1_000
    public static let defaultCompressionQuality = 0.7

    /// Returns a correctly oriented, aspect-preserving JPEG suitable for upload.
    public static func jpegData(
        from imageData: Data,
        maxDimension: Int = defaultMaxDimension,
        compressionQuality: Double = defaultCompressionQuality
    ) throws -> Data {
        guard maxDimension > 0,
              (0...1).contains(compressionQuality),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil)
        else {
            throw PhotoScanImageError.invalidImage
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? Int ?? maxDimension
        let height = properties?[kCGImagePropertyPixelHeight] as? Int ?? maxDimension
        let thumbnailDimension = min(max(width, height), maxDimension)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailDimension,
        ]

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoScanImageError.invalidImage
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotoScanImageError.encodingFailed
        }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: compressionQuality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoScanImageError.encodingFailed
        }
        return output as Data
    }

    /// Returns a JPEG data URI ready for ``ScanFoodPhotoRequest``.
    public static func dataURI(
        from imageData: Data,
        maxDimension: Int = defaultMaxDimension,
        compressionQuality: Double = defaultCompressionQuality
    ) throws -> String {
        let jpeg = try jpegData(
            from: imageData,
            maxDimension: maxDimension,
            compressionQuality: compressionQuality
        )
        return "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
    }
}

public enum PhotoScanImageError: Error, Hashable, Sendable {
    case invalidImage
    case encodingFailed
}
