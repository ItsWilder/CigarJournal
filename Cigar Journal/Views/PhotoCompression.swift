import UIKit

enum PhotoCompression {
    static func compressedData(from data: Data?, maxDimension: CGFloat = 1800, quality: CGFloat = 0.75) -> Data? {
        guard let data, let image = UIImage(data: data) else { return data }
        let resized = resizedImage(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality) ?? data
    }

    private static func resizedImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
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
