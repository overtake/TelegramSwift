import Foundation
import SwiftSignalKitMac
import PostboxMac
import ImageIO
import TelegramCoreMac
import TGUIKit
import Accelerate


public  func peerAvatarImage(account: Account, peer: Peer, displayDimensions: CGSize = CGSize(width: 50, height: 50)) -> Signal<CGImage?, NoError>? {
    var location: TelegramCloudMediaLocation?
    
    if let user = peer as? TelegramUser {
        if let photo = user.photo.first {
            location = photo.location.cloudLocation
        }
    } else if let group = peer as? TelegramGroup {
        if let photo = group.photo.first {
            location = photo.location.cloudLocation
        }
    } else if let channel = peer as? TelegramChannel {
        if let photo = channel.photo.first {
            location = photo.location.cloudLocation
        }
    }
    
    if let location = location {
        return deferred { () -> Signal<CGImage?, NoError> in
            return cachedCloudFileLocation(location)
                |> `catch` { _ in
                    return multipartDownloadFromCloudLocation(account: account, location: location, size: nil)
                        |> afterNext { data in
                            cacheCloudFileLocation(location, data: data)
                    }
                }
                |> runOn(account.graphicsThreadPool) |> deliverOn(account.graphicsThreadPool)
                |> map { data -> CGImage? in
                    
                    return roundImage(data,displayDimensions)
            }
            } |> runOn(account.graphicsThreadPool)
    } else {
        return nil
    }
}

private let screenQueue = Queue(name: "ScreenQueue")


public func roundImage(_ data:Data, _ s:NSSize, cornerRadius:CGFloat = -1, reversed:Bool = false) -> CGImage? {
    var image:CGImageSource? = CGImageSourceCreateWithData(data as CFData, nil)
    
    var size = s;
    
   size =   NSMakeSize(s.width * 2.0, s.height * 2.0)

    var context:CGContext? = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: Int(4*size.width), space: NSColorSpace.genericRGB.cgColorSpace!, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
    
    
    if let ctx = context {
        if let img = image {
            let cimage = CGImageSourceCreateImageAtIndex(img, 0, nil)
            if let c = cimage {
                
                if cornerRadius == -1 {
                    var startAngle: Float = Float(2 * M_PI)
                    var endAngle: Float = 0.0
                    let radius:Float = Float(size.width/2.0)
                    let center = NSMakePoint(size.width/2.0, size.height/2.0)
                    
                    startAngle = startAngle - Float(M_PI_2)
                    endAngle = endAngle - Float(M_PI_2)
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




