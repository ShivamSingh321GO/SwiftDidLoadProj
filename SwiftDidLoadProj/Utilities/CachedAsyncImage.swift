import SwiftUI

class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSURL, UIImage>()
    
    private init() {
        // Limit cache size to avoid memory bloat
        cache.countLimit = 100
    }
    
    func get(forKey key: String) -> UIImage? {
        guard let url = NSURL(string: key) else { return nil }
        return cache.object(forKey: url)
    }
    
    func set(_ image: UIImage, forKey key: String) {
        guard let url = NSURL(string: key) else { return }
        cache.setObject(image, forKey: url)
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    
    @State private var image: UIImage? = nil
    
    init(url: URL?, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task {
                        await loadImage()
                    }
            }
        }
    }
    
    private func loadImage() async {
        guard let url = url else { return }
        
        // 1. Check in-memory cache
        if let cached = ImageCache.shared.get(forKey: url.absoluteString) {
            await MainActor.run {
                self.image = cached
            }
            return
        }
        
        // 2. Fetch from network if not cached
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            // Optional: check HTTP response code
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let uiImage = UIImage(data: data) {
                
                ImageCache.shared.set(uiImage, forKey: url.absoluteString)
                
                await MainActor.run {
                    self.image = uiImage
                }
            }
        } catch {
            print("Failed to load image from \(url): \(error)")
        }
    }
}
