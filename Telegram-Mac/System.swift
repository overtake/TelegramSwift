//
//  SystemQueue.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TelegramCoreMac
import TGUIKit
import PostboxMac
private let _dQueue = Queue.init(name: "chatListQueue")
private let _sQueue = Queue.init(name: "ChatQueue")

public let resourcesQueue = Queue(name: "ResourcesQueue")
public let prepareQueue = Queue(name: "PrepareQueue")
public let messagesViewQueue = Queue(name: "messagesViewQueue")

public let appName = "Telegram"
public let kMediaImageExt = "jpg";
public let kMediaGifExt = "mov";
public let kMediaVideoExt = "mp4";

public weak var mw:Window?

var mainWindow:Window {
    if let window = NSApp.keyWindow as? Window {
        return window
    } else if let window = NSApp.mainWindow as? Window {
        return window
    } else if let mw = mw {
        return mw
    }
    fatalError("window not found")
}


public func deliverOnPrepareQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(prepareQueue)
}


func proccessEntriesWithoutReverse<T,R>(_ left:[R]?,right:[R],_ convertEntry:@escaping (R) -> T) -> ([Int],[(Int,T)],[(Int,T)]) where R:Comparable, R:Identifiable {
    return proccessEntries(false, left, right: right, convertEntry)
}

func proccessEntries<T,R>(_ left:[R]?,right:[R],_ convertEntry:@escaping (R) -> T) -> ([Int],[(Int,T)],[(Int,T)]) where R:Comparable, R:Identifiable {
    return proccessEntries(true, left, right: right, convertEntry)
}

fileprivate func proccessEntries<T,R>(_ reverse:Bool = true, _ left:[R]?,right:[R],_ convertEntry:@escaping (R) -> T) -> ([Int],[(Int,T)],[(Int,T)]) where R:Comparable, R:Identifiable {
    if let left = left  {
        
        let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: left, rightList: right)
        
        var insertedItems:[(Int,T)] = []
        var updatedItems:[(Int,T)] = []
        
        var newItems:[R.T:T] = [:]
        
        for (idx, entry, _) in indicesAndItems {
            let item:T = newItems[entry.stableId] ?? convertEntry(entry)
            newItems[entry.stableId] = item
            insertedItems.append((idx,item))
        }
        
        for (idx, entry, _) in updateIndices {
            let item:T = newItems[entry.stableId] ?? convertEntry(entry)
            newItems[entry.stableId] = item
            updatedItems.append((idx,item))
        }
        
        
        let removed = reverse ? reverseIndexList(deleteIndices, left.count) : deleteIndices
        let inserted = reverse ? reverseIndexList(insertedItems, left.count, right.count) : insertedItems
        let updated = reverse ? reverseIndexList(updatedItems, left.count, right.count) : updatedItems
        
        if !(removed.count > 0 || inserted.count > 0 || updated.count > 0) {
            assert(left == right)
        }
        
        return (removed,inserted,updated)
    } else {
        
        var list:[(Int,T)] = []
        
        for entry in (reverse ? right.reversed() : right) {
            list.append((list.count,convertEntry(entry)))
        }
        
        return ([],list,[])
        
    }
}



func link(path:String?, ext:String) -> String? {
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

func delay(_ delay:Double, closure:@escaping ()->()) {
    let when = DispatchTime.now() + delay
    DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
}


func fs(_ path:String) -> Int32? {
    
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



