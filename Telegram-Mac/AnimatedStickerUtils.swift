//
//  AnimatedStickerUtils.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 27/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import SwiftSignalKit
import AVFoundation
import TGUIKit

private func verifyLottieItems(_ items: [Any]?, shapes: Bool = true) -> Bool {
    if let items = items {
        for case let item as [AnyHashable: Any] in items {
            if let type = item["ty"] as? String {
                if type == "rp" || type == "sr" || type == "mm" || type == "gs" {
                    return false
                }
            }
            
            if shapes, let subitems = item["it"] as? [Any] {
                if !verifyLottieItems(subitems, shapes: false) {
                    return false
                }
            }
        }
    }
    return true;
}

private func verifyLottieLayers(_ layers: [AnyHashable: Any]?) -> Bool {
    return true
}

func validateStickerComposition(json: [AnyHashable: Any]) -> Bool {
    guard let tgs = json["tgs"] as? Int, tgs == 1 else {
        return false
    }
    
    return true
}

private let writeQueue = DispatchQueue(label: "assetWriterQueue")


private func fillPixelBufferFromImage(_ image: CGImage, pixelBuffer: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
    let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer)
    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
    context?.draw(image, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
    CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
}
