import Cocoa
import SwiftSignalKitMac

private final class PresentationsResourceCacheHolder {
    var images: [Int32: CGImage] = [:]
}

private final class PresentationsResourceAnyCacheHolder {
    var objects: [Int32: AnyObject] = [:]
}

public final class PresentationsResourceCache {
    
    public init() {
        
    }
    
    private let imageCache = Atomic<PresentationsResourceCacheHolder>(value: PresentationsResourceCacheHolder())
    private let objectCache = Atomic<PresentationsResourceAnyCacheHolder>(value: PresentationsResourceAnyCacheHolder())
    
    public func image(_ key: Int32, _ generate: () -> CGImage) -> CGImage {
        let result = self.imageCache.with { holder -> CGImage? in
            return holder.images[key]
        }
        if let result = result {
            return result
        } else {
            let image = generate()
            self.imageCache.with { holder -> Void in
                holder.images[key] = image
            }
            return image
        }
    }
    
    public func object(_ key: Int32, _ generate: () -> AnyObject) -> AnyObject {
        let result = self.objectCache.with { holder -> AnyObject? in
            return holder.objects[key]
        }
        if let result = result {
            return result
        } else {
            let object = generate()
            self.objectCache.with { holder -> Void in
                holder.objects[key] = object
            }
            return object
        }
    }
}
