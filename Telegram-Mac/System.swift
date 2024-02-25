//
//  SystemQueue.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore

import TGUIKit
import Postbox
import CoreMediaIO
import Localization

public let resourcesQueue = Queue(name: "ResourcesQueue", qos: .utility)
public let prepareQueue = Queue(name: "PrepareQueue", qos: .utility)
public let messagesViewQueue = Queue(name: "messagesViewQueue", qos: .utility)

public let appName = "Telegram"
public let kMediaImageExt = "jpg";
public let kMediaGifExt = "mov";
public let kMediaVideoExt = "mp4";



var systemAppearance: NSAppearance {
    if #available(OSX 10.14, *) {
        return NSApp.effectiveAppearance
    } else {
        return NSAppearance.current
    }
}


public func deliverOnPrepareQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(prepareQueue)
}
public func deliverOnMessagesViewQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(messagesViewQueue)
}

public func deliverOnResourceQueue<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return signal |> deliverOn(resourcesQueue)
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




func DALDevices() -> [AVCaptureDevice] {
    let video = AVCaptureDevice.devices(for: .video)
    let muxed:[AVCaptureDevice] = AVCaptureDevice.devices(for: .muxed) //[]//
    // && $0.hasMediaType(.video)
    
    
    return (video + muxed).filter { $0.isConnected && !$0.isSuspended }
}

func shouldBeMirrored(_ device: AVCaptureDevice) -> Bool {
    
    if !device.hasMediaType(.video) {
        return false
    }
    
    var latency_pa = CMIOObjectPropertyAddress(
               mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyLatency),
               mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
               mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
           )
    var dataSize = UInt32(0)
    
    let id = device.value(forKey: "_connectionID") as? CMIOObjectID

    if let id = id {
        if CMIOObjectGetPropertyDataSize(id, &latency_pa, 0, nil, &dataSize) == OSStatus(kCMIOHardwareNoError) {
            return false
        } else {
           return true
        }
    }
    return true
}



func strings() -> L10n.Type {
    return L10n.self
}
