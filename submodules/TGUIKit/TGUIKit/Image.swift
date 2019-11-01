import Foundation
import ImageIO
import Accelerate




public func roundImage(_ data:Data, _ s:NSSize, cornerRadius:CGFloat = -1, reversed:Bool = false, scale:CGFloat = 1.0) -> CGImage? {
    let image:CGImageSource? = CGImageSourceCreateWithData(data as CFData, nil)
    
    let size = NSMakeSize(s.width * scale, s.height * scale)

    let context:CGContext? = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(4*size.width), space: NSColorSpace.genericRGB.cgColorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    
    
    if let ctx = context {
        if let img = image {
            let cimage = CGImageSourceCreateImageAtIndex(img, 0, nil)
            if let c = cimage {
                
                if cornerRadius == -1 {
                    var startAngle: Float = Float(2 * Double.pi)
                    var endAngle: Float = 0.0
                    let radius:Float = Float(size.width/2.0)
                    let center = NSMakePoint(size.width/2.0, size.height/2.0)
                    
                    startAngle = startAngle - Float(Double.pi / 2)
                    endAngle = endAngle - Float(Double.pi / 2)
                    ctx.addArc(center: center, radius: CGFloat(radius), startAngle: CGFloat(startAngle), endAngle: CGFloat(endAngle), clockwise: false)
                } else if cornerRadius > 0 {
                    
                    let minx:CGFloat = 0, midx = size.width/2.0, maxx = size.width
                    let miny:CGFloat = 0, midy = size.height/2.0, maxy = size.height
                    
                
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
               
                if reversed {
                    ctx.translateBy(x: size.width/2.0, y: size.height/2.0)
                    ctx.scaleBy(x: 1.0, y: -1.0)
                    ctx.translateBy(x: -(size.width/2.0), y: -(size.height/2.0))

                }
                ctx.draw(c, in: NSMakeRect(0, 0, size.width, size.height))
                

                return ctx.makeImage()
                
            }
    
        }
    }
    
    return nil
}




