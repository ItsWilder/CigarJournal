// PhotoCompression
// Photos are resized and JPEG-compressed once, when picked, before they're stored.

import UIKit

nonisolated enum PhotoCompression {
    static let maxDimension: CGFloat = 1800
    static let quality: CGFloat = 0.75

    /// Compresses picked image data off the main thread.
    @concurrent
    static func compressedData(from data: Data) async -> Data {
        guard let image = UIImage(data: data) else { return data }
        return compressedData(from: image) ?? data
    }

    static func compressedData(from image: UIImage) -> Data? {
        resizedImage(image).jpegData(compressionQuality: quality)
    }

    private static func resizedImage(_ image: UIImage) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1

        return UIGraphicsImageRenderer(size: newSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
