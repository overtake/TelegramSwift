//
//  QRCode.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import CoreImage
import SwiftSignalKitMac
import TGUIKit


func qrCode(string: String, color: NSColor, backgroundColor: NSColor? = nil, scale: CGFloat = 0.0) -> Signal<ImageDataTransformation, NoError> {
    return Signal<Data, NoError> { subscriber in
        if let data = string.data(using: .isoLatin1, allowLossyConversion: false) {
            subscriber.putNext(data)
        }
        subscriber.putCompletion()
        return EmptyDisposable
    }
    |> map { data in
        return ImageDataTransformation(data: ImageRenderData.init(nil, data, true), execute: { arguments, data in
            
            let context = DrawingContext(size: arguments.drawingSize, scale: scale, clear: true)

            
            let filter = CIFilter(name: "CIQRCodeGenerator")
            if let filter = filter {
                
                filter.setValue(data.fullSizeData!, forKey: "inputMessage")
                filter.setValue("L", forKey: "inputCorrectionLevel")
                
                if let inputImage = filter.outputImage {
                    let drawingRect = arguments.drawingRect
                    let fittedSize = arguments.imageSize.aspectFilled(arguments.boundingSize).fitted(arguments.imageSize)
                    let fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
                    
                    let scale = arguments.drawingRect.size.width / inputImage.extent.width * context.scale
                    let transformed = inputImage.transformed(by: CGAffineTransform.init(scaleX: scale, y: scale))
                    
                    
                    let invertFilter = CIFilter(name: "CIColorInvert")
                    invertFilter?.setValue(transformed, forKey: kCIInputImageKey)
                    let alphaFilter = CIFilter(name: "CIMaskToAlpha")
                    alphaFilter?.setValue(invertFilter?.outputImage, forKey: kCIInputImageKey)
                    //
                    var image: CGImage?
                    let ciContext = CIContext(options: [CIContextOption.useSoftwareRenderer : NSNumber(value: true)])
                    if let finalImage = alphaFilter?.outputImage, let cgImage = ciContext.createCGImage(finalImage, from: finalImage.extent) {
                        image = cgImage
                    }
                    
                    context.withContext { c in
                        if let backgroundColor = backgroundColor {
                            c.setFillColor(backgroundColor.cgColor)
                            c.fill(drawingRect)
                        }
                        
                        c.setBlendMode(.normal)
                        if let image = image {
                            c.saveGState()
                            //                        c.translateBy(x: fittedRect.midX, y: fittedRect.midY)
                            //                        c.scaleBy(x: 1.0, y: -1.0)
                            //                        c.translateBy(x: -fittedRect.midX, y: -fittedRect.midY)
                            
                            c.clip(to: fittedRect, mask: image)
                            c.setFillColor(color.cgColor)
                            c.fill(fittedRect)
                            c.restoreGState()
                        }
                        if let backgroundColor = backgroundColor {
                            c.setFillColor(backgroundColor.cgColor)
                        } else {
                            c.setBlendMode(.clear)
                            c.setFillColor(NSColor.clear.cgColor)
                        }
                    }
                }
            }
    
            return context
        })
    } |> runOn(graphicsThreadPool)
}
