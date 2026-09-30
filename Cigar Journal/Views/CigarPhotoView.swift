// CigarPhotoView
// Shows a cigar photo (or a placeholder). Images are downsampled to the size they're
// displayed at, off the main thread, and cached, so scrolling never decodes full JPEGs.

import ImageIO
import SwiftUI
import UIKit

struct CigarPhotoView: View {
    let photo: Data?
    /// The largest side, in points, the photo is displayed at.
    var maxPointSize: CGFloat = 400
    var contentMode: ContentMode = .fill
    var background: Color = Color(.brown)

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            background

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if photo == nil {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.accentDark)
            }
        }
        .clipped()
        .task(id: loadKey) {
            image = await PhotoThumbnailCache.image(for: photo, maxPixelSize: maxPointSize * displayScale)
        }
    }

    private var loadKey: Int {
        var hasher = Hasher()
        hasher.combine(photo?.count)
        hasher.combine(photo?.prefix(64))
        hasher.combine(maxPointSize)
        return hasher.finalize()
    }
}

nonisolated enum PhotoThumbnailCache {
    // NSCache is thread-safe; it just isn't annotated Sendable.
    nonisolated(unsafe) private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        return cache
    }()

    @concurrent
    static func image(for data: Data?, maxPixelSize: CGFloat) async -> UIImage? {
        guard let data else { return nil }

        // Photos are stored whole, so size + a slice of the bytes identifies them well enough.
        var hasher = Hasher()
        hasher.combine(data.count)
        hasher.combine(data.prefix(256))
        hasher.combine(data.suffix(256))
        let key = "\(hasher.finalize())-\(Int(maxPixelSize))" as NSString

        if let cached = cache.object(forKey: key) { return cached }

        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else {
            return nil
        }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }

        let image = UIImage(cgImage: thumbnail)
        cache.setObject(image, forKey: key)
        return image
    }
}
