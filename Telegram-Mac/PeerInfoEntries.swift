//
//  PeerInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import TGUIKit



protocol PeerInfoSection {
    var rawValue: UInt32 { get }
    func isEqual(to: PeerInfoSection) -> Bool
    func isOrderedBefore(_ section: PeerInfoSection) -> Bool
}

class PeerInfoState : Equatable {
    
    static func ==(lhs:PeerInfoState, rhs:PeerInfoState) -> Bool {
        return false
    }
}

protocol PeerInfoEntryStableId {
    func isEqual(to: PeerInfoEntryStableId) -> Bool
    var hashValue: Int { get }
}

struct IntPeerInfoEntryStableId: PeerInfoEntryStableId {
    let value: Int
    
    func isEqual(to: PeerInfoEntryStableId) -> Bool {
        if let to = to as? IntPeerInfoEntryStableId, to.value == self.value {
            return true
        } else {
            return false
        }
    }
    
    var hashValue: Int {
        return self.value.hashValue
    }
}

final class PeerInfoUpdatingPhotoState : Equatable {
    let progress:Float
    let cancel:()->Void
    
    init(progress: Float, cancel: @escaping()->Void) {
        self.progress = progress
        self.cancel = cancel
    }
    
    func withUpdatedProgress(_ progress: Float) -> PeerInfoUpdatingPhotoState {
        return PeerInfoUpdatingPhotoState(progress: progress, cancel: self.cancel)
    }
    
    static func ==(lhs:PeerInfoUpdatingPhotoState, rhs: PeerInfoUpdatingPhotoState) -> Bool {
        return lhs.progress == rhs.progress
    }
}


protocol PeerInfoEntry {
    var stableId: PeerInfoEntryStableId { get }
    func isEqual(to: PeerInfoEntry) -> Bool
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem
}


func peerInfoEntries(view: PeerView, arguments: PeerInfoArguments, inputActivities: [PeerId: PeerInputActivity]) -> [PeerInfoEntry] {
    if peerViewMainPeer(view) is TelegramUser {
        return userInfoEntries(view: view, arguments: arguments)
    } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
        switch channel.info {
        case .broadcast:
            return channelInfoEntries(view: view, arguments: arguments)
        case .group:
            return groupInfoEntries(view: view, arguments: arguments, inputActivities: inputActivities)
        }
    } else if peerViewMainPeer(view) is TelegramGroup {
        return groupInfoEntries(view: view, arguments: arguments, inputActivities: inputActivities)
    }
    return []
}
