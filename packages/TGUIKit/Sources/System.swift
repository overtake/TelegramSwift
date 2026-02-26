//
//  System.swift
//  TGUIKit
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AVFoundation


public weak var mw:Window?

public var mainWindow:Window {
    if let window = NSApp.keyWindow as? Window {
        return window
    } else if let window = NSApp.mainWindow as? Window {
        return window
    } else if let mw = mw {
        return mw
    }
    fatalError("window not found")
}

public struct System {

    
    public static var legacyMenu: Bool = true
    
    private static var scaleFactor: Atomic<CGFloat> = Atomic(value: 2.0)
    private static var safeScaleFactor: CGFloat = 2.0
    public static func updateScaleFactor(_ value: CGFloat) {
        _ = scaleFactor.modify { _ in
            safeScaleFactor = value
            return value
        }
        
    }
    
    public static var batterylevel: Float {
        
        let device = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("IOPMPowerSource"))
        let batteryLevel: AnyObject? = IORegistryEntryCreateCFProperty(device, "Current Capacity" as CFString, kCFAllocatorDefault, 0).takeRetainedValue()
        IOObjectRelease(device)
        return batteryLevel as! Float
    }
    
    public static var isRetina:Bool {
        get {
            return safeScaleFactor >= 2.0
        }
    }
    
    public static var backingScale:CGFloat {
        return safeScaleFactor
    }
    
    public static var pixel:CGFloat {
        return 1 / safeScaleFactor
    }
    public static var aspectRatio: CGFloat {
        let frame = NSScreen.main?.frame ?? .zero
        let preferredAspectRatio = CGFloat(frame.width / frame.height)
        return preferredAspectRatio
    }
    
    public static var cameraAspectRatio: CGFloat {
        let device = AVCaptureDevice.default(for: .video)
        let description = device?.activeFormat.formatDescription
        if let description = description {
            let dimension = CMVideoFormatDescriptionGetDimensions(description)
            return CGFloat(dimension.width) / CGFloat(dimension.height)
        }
        return aspectRatio
    }
    
    public static var drawAsync:Bool {
        return false
    }
    
    public static var isScrollInverted: Bool {
        if UserDefaults.standard.value(forKey: "com.apple.swipescrolldirection") != nil {
            return UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection")
        } else {
            return true
        }
    }
    
    public static var supportsTransparentFontDrawing: Bool {
        if #available(OSX 10.15, *) {
            return true
        } else {
            return System.backingScale > 1.0
        }
    }
 
}

public var uiLocalizationFunc:((String)->String)?

public func localizedString(_ key:String) -> String {
    if let uiLocalizationFunc = uiLocalizationFunc {
        return uiLocalizationFunc(key)
    } else {
        return NSLocalizedString(key, comment: "")
    }
}

//public func localizedString(_ key:String, countable:Int = 0, apply:Bool = true) -> String {
//    let suffix:String
//    if countable == 1 {
//        suffix = ".singular"
//    } else if countable > 1 {
//        suffix = ".pluar"
//    } else {
//        suffix = ".zero"
//    }
//    if apply {
//        return String(format: localizedString(key + suffix), countable)
//    } else {
//        return localizedString(key + suffix)
//    }
//}

public func reverseIndexList<T>(_ list:[(Int,T,Int?)], _ previousCount:Int, _ updateCount:Int) -> [(Int,T,Int?)] {
    var reversed:[(Int,T,Int?)] = []
    
    for (int1,obj,int2) in list.reversed() {
        if let s = int2 {
            reversed.append((updateCount - int1 - 1,obj, previousCount - s - 1))
        } else {
            reversed.append((updateCount - int1 - 1,obj, nil))
        }
    }
    return reversed
}

public func reverseIndexList<T>(_ list:[(Int,T)], _ previousCount:Int, _ updateCount:Int) -> [(Int,T)] {
    var reversed:[(Int,T)] = []
    
    for (int1,obj) in list.reversed() {
        reversed.append((updateCount - int1 - 1,obj))
    }
    return reversed
}

public func reverseIndexList<T>(_ list:[(Int,T,Int)], _ previousCount:Int, _ updateCount:Int) -> [(Int,T,Int)] {
    var reversed:[(Int,T,Int)] = []
    
    for (int1,obj,int2) in list.reversed() {
       reversed.append((updateCount - int1 - 1,obj, previousCount - int2 - 1))
    }
    return reversed
}

public func reverseIndexList(_ list:[Int], _ count:Int) -> [Int] {
    var reversed:[(Int)] = []
    for int1 in list.reversed() {
        reversed.append(count - int1 - 1)
    }
    return reversed
}


public func delay(_ delay:Double, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}
public func delay(_ delay:Double, onQueue queue: DispatchQueue, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    queue.asyncAfter(deadline: when, execute: closure)
}
public func delaySignal(_ value:Double) -> Signal<NoValue, NoError> {
    return .complete() |> delay(value, queue: .mainQueue())
}




public func link(path:String?, ext:String) -> String? {
    var realPath:String? = path
    if let path = path, path.nsstring.pathExtension.length == 0 && FileManager.default.fileExists(atPath: path) {
        let path = path.nsstring.appendingPathExtension(ext)!
        if !FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.removeItem(atPath: path)
            try? FileManager.default.createSymbolicLink(atPath: path, withDestinationPath: realPath!)
        }
        realPath = path
    }
    return realPath
}

public func copyToTemp(path:String?, ext:String) -> String? {
    var realPath:String? = path
    if let path = path, path.nsstring.pathExtension.length == 0 && FileManager.default.fileExists(atPath: path) {
        let new = NSTemporaryDirectory() + path.nsstring.lastPathComponent.nsstring.appendingPathExtension(ext)!
        try? FileManager.default.copyItem(atPath: path, toPath: new)
        realPath = new
    }
    return realPath
}


public func fs(_ path:String) -> Int32? {
    
    if var attrs = try? FileManager.default.attributesOfItem(atPath: path) as NSDictionary {
    
        if attrs["NSFileType"] as? String == "NSFileTypeSymbolicLink" {
            if let path = try? FileManager.default.destinationOfSymbolicLink(atPath: path) {
                attrs = (try? FileManager.default.attributesOfItem(atPath: path) as NSDictionary) ?? attrs
            }
        }
        let size = attrs.fileSize()
    
        if size > UInt64(INT32_MAX) {
            return INT32_MAX
        }
        return Int32(size)
    }
    return nil
}

