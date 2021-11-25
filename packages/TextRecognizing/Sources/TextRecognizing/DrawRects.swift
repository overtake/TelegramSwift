//
//  File.swift
//  
//
//  Created by Mikhail Filimonov on 22.11.2021.
//

import Foundation
import TGUIKit
import Cocoa

private extension NSPoint {
    func apply(_ size: NSSize, _ multiplier: CGPoint = NSMakePoint(1, 1)) -> CGPoint {
        return NSMakePoint(self.x * size.width * multiplier.x, self.y * size.height * multiplier.y)
    }
}

@available(macOS 10.15, *)
private extension TextRecognizing.Result.Detected {
    func path(_ size: NSSize, viewSize: NSSize) -> CGPath {
        let path = CGMutablePath()
        let multiplier = NSMakePoint(viewSize.width / size.width, viewSize.height / size.height)
        path.move(to: self.topLeft.apply(size, multiplier))
        path.addLine(to: self.topRight.apply(size, multiplier))
        path.addLine(to: self.bottomRight.apply(size, multiplier))
        path.addLine(to: self.bottomLeft.apply(size, multiplier))
        path.addLine(to: self.topLeft.apply(size, multiplier))
        return path
    }
    func rect(_ size: NSSize, viewSize: NSSize) -> CGRect {
        let multiplier = NSMakePoint(viewSize.width / size.width, viewSize.height / size.height)
        return NSMakeRect(self.boundingBox.minX * size.width * multiplier.x, self.boundingBox.minY * size.height * multiplier.y, self.boundingBox.width * size.width * multiplier.x, self.boundingBox.height * size.height * multiplier.y)
    }
}


@available(macOS 10.15, *)
public extension TextRecognizing.Result {
    func drawSelectableRects(viewSize: NSSize) -> CGImage? {
        switch self {
        case let .finish(image, text):
            return generateImage(image.size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
                ctx.draw(image, in: size.bounds)
                for value in text {
                    ctx.saveGState()
                    ctx.setFillColor(NSColor.selectText.withAlphaComponent(0.5).cgColor)
                    ctx.addPath(value.path(size, viewSize: viewSize))
                    ctx.fillPath()
                    ctx.restoreGState()
                }
            }, scale: 1.0)!
        default:
            return nil
        }
    }
    
    func selectablePaths(viewSize: NSSize) -> [CGPath] {
        switch self {
        case let .finish(image, text):
            var paths:[CGPath] = []
            for value in text {
                paths.append(value.path(image.size, viewSize: viewSize))
            }
            return paths
        default:
            return []
        }
    }
    
    func select(from: CGPoint, to: CGPoint, viewSize: NSSize) -> TextRecognizing.Result {
        switch self {
        case let .finish(image, text):
            var result: [TextRecognizing.Result.Detected] = []
            let selected = NSMakeRect(min(from.x, to.x), min(from.y, to.y), max(from.x, to.x) - min(from.x, to.x), max(from.y, to.y) - min(from.y, to.y))
            let size = image.size
            for text in text {
                let rect = text.rect(size, viewSize: viewSize)
                if selected.intersects(rect) {
                    let center = NSMakeRect(rect.midX, rect.midY, 1, 1).insetBy(dx: -2, dy: -2)
                    if selected.intersects(center) {
                        result.append(text)
                    }
                }
            }
            return .finish(image: image, text: result)
        default:
            return self
        }
        
      
    }
}
