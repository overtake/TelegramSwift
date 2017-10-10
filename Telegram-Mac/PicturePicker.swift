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
            let image = picker.outputImage()
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
    taker.beginSheet(for: window, withDelegate: observer, didEnd: #selector(PickerObserver.validated(_:_:_:)), contextInfo: nil)
}
