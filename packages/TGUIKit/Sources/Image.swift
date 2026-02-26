import Foundation
import ImageIO
import Accelerate
import AppKit


fileprivate func avatarBubbleMask(size: CGSize) -> CGImage {
    return generateImage(size, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(NSColor.white.cgColor)
        addAvatarBubblePath(context: context, rect: CGRect(origin: CGPoint(), size: size))
        context.fillPath()
    })!
}
    
public func addAvatarBubblePath(context: CGContext, rect: CGRect) {
    if let path = try? convertSvgPath("M60,30.274903 C60,46.843446 46.568544,60.274904 30,60.274904 C13.431458,60.274904 0,46.843446 0,30.274903 C0,23.634797 2.158635,17.499547 5.810547,12.529785 L6.036133,12.226074 C6.921364,10.896042 7.367402,8.104698 5.548828,5.316895 C3.606939,2.340088 1.186019,0.979668 2.399414,0.470215 C3.148032,0.156204 7.572027,0.000065 10.764648,1.790527 C12.148517,2.56662 13.2296,3.342422 14.09224,4.039734 C14.42622,4.309704 14.892063,4.349773 15.265962,4.138523 C19.618079,1.679604 24.644722,0.274902 30,0.274902 C46.568544,0.274902 60,13.70636 60,30.274903 Z ") {
        let sx = rect.width / 60.0
        let sy = rect.height / 60.0
        var transform = CGAffineTransform(
            a: sx, b: 0.0,
            c: 0.0, d: -sy,
            tx: rect.minX,
            ty: rect.minY + rect.height
        )
        let transformedPath = path.copy(using: &transform)!
        context.addPath(transformedPath)
    }
}
    

public func roundImage(_ data:Data, _ s:NSSize, cornerRadius:CGFloat = -1, reversed:Bool = false, scale:CGFloat = 1.0, bubble: Bool = false) -> CGImage? {
    return autoreleasepool {
        let image:CGImageSource? = CGImageSourceCreateWithData(data as CFData, nil)
        
        let size = NSMakeSize(s.width * scale, s.height * scale)
        
        let context = DrawingContext(size: size, scale: 1)
      
        
        context.withContext { ctx in
            ctx.clear(size.bounds)
            if let img = image {
                let cimage = CGImageSourceCreateImageAtIndex(img, 0, nil)
                if let c = cimage {
                    
                    if bubble {
                        let rect = CGRect(origin: CGPoint(), size: size)
                        ctx.translateBy(x: rect.midX, y: rect.midY)
                        ctx.scaleBy(x: 1.0, y: -1.0)
                        ctx.translateBy(x: -rect.midX, y: -rect.midY)
                        addAvatarBubblePath(context: ctx, rect: rect)
                        ctx.translateBy(x: rect.midX, y: rect.midY)
                        ctx.scaleBy(x: 1.0, y: -1.0)
                        ctx.translateBy(x: -rect.midX, y: -rect.midY)
                        ctx.clip()
                    } else {
                        if cornerRadius == -1 {
                            var startAngle: Float = Float(2 * Double.pi)
                            var endAngle: Float = 0.0
                            let radius:Float = Float(size.width/2.0)
                            let center = NSMakePoint(size.width/2.0, size.height/2.0)
                            
                            startAngle = startAngle - Float(Double.pi / 2)
                            endAngle = endAngle - Float(Double.pi / 2)
                            ctx.addArc(center: center, radius: CGFloat(radius), startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle), clockwise: false)
                        } else if cornerRadius > 0 {
                            var cornerRadius = cornerRadius * System.backingScale
                            let minx:CGFloat = 0, midx = size.width/2.0, maxx = size.width
                            let miny:CGFloat = 0, midy = size.height/2.0, maxy = size.height
                            
                            if size.width < 40, cornerRadius / 2 == size.width / 3 {
                                cornerRadius = size.width / 3
                            }
                            
                            ctx.move(to: NSMakePoint(minx, midy))
                            ctx.addArc(tangent1End: NSMakePoint(minx, miny), tangent2End: NSMakePoint(midx, miny), radius: cornerRadius)
                            ctx.addArc(tangent1End: NSMakePoint(maxx, miny), tangent2End: NSMakePoint(maxx, midy), radius: cornerRadius)
                            ctx.addArc(tangent1End: NSMakePoint(maxx, maxy), tangent2End: NSMakePoint(midx, maxy), radius: cornerRadius)
                            ctx.addArc(tangent1End: NSMakePoint(minx, maxy), tangent2End: NSMakePoint(minx, midy), radius: cornerRadius)
                        }
                        
                        if cornerRadius > 0 || cornerRadius == -1 {
                            ctx.closePath()
                            ctx.clip()
                        }
                    }
                    
                   
                    if reversed {
                        ctx.translateBy(x: size.width/2.0, y: size.height/2.0)
                        ctx.scaleBy(x: 1.0, y: -1.0)
                        ctx.translateBy(x: -(size.width/2.0), y: -(size.height/2.0))

                    }
                    if s.width != s.height {
                        ctx.draw(c, in: size.bounds.focus(size.aspectFilled(c.systemSize.aspectFitted(size))))
                    } else {
                        ctx.draw(c, in: size.bounds)
                    }
                }
            }
        }
        return context.generateImage()
    }
}




