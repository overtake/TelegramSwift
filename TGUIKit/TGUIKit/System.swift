//
//  System.swift
//  TGUIKit
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

public struct System {

    public static var scaleFactor: Atomic<CGFloat> = Atomic(value: 2.0)
    
    public static var isRetina:Bool {
        get {
            return scaleFactor.modify({$0}) == 2.0
        }
    }
    
    public static var backingScale:CGFloat {
        return CGFloat(scaleFactor.modify({$0}))
    }
    
    public static var drawAsync:Bool {
        return false
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
