//
//  PicturePicker.swift
//  TelegramMac
//
//  Created by keepcoder on 05/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Quartz

fileprivate class PickerObserver {
    fileprivate var completion:(NSImage?) -> Void = {_ in}
    
    @objc fileprivate func validated(_ picker:IKPictureTaker, _ code:Int, _ contextInfo:Any?) {
        if code == NSApplication.ModalResponse.OK.rawValue {
            var image = picker.outputImage()
            if let img = image {
                let size = img.size.aspectFilled(NSMakeSize(640, 640))
                let resized = generateImage(size, contextGenerator: { size, ctx in
                    ctx.draw(img.precomposed(), in: NSMakeRect(0, 0, size.width, size.height))
                })!
                image = NSImage(cgImage: resized, size: size)
            }
            completion(image)
        }
    }
}

private let observer:PickerObserver = {
    let observer = PickerObserver()
    return observer
}()
func pickImage(for window:Window, maxSize:NSSize = NSMakeSize(640, 640), fileFirst: Bool = false, completion:@escaping (NSImage?) -> Void) {
    let taker:IKPictureTaker = IKPictureTaker.pictureTaker()
    taker.setValue(NSNumber(value: true), forKey: IKPictureTakerShowEffectsKey)
    taker.setValue(NSValue(size: maxSize), forKey: IKPictureTakerOutputImageMaxSizeKey)
    if fileFirst {
    }
    observer.completion = completion
    
    if let window = NSApp.window(withWindowNumber: taker.windowNumber) {
        window.appearance = theme.appearance
    }


    taker.beginSheet(for: window, withDelegate: observer, didEnd: #selector(PickerObserver.validated(_:_:_:)), contextInfo: nil)
    
    
    
        //.appearance = theme.appearance

}
