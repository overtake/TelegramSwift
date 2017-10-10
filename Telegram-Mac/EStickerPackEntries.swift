//
//  StickerPackEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 25/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit





enum ChatMediaInputPanelEntry: Comparable, Identifiable {
    case stickerPack(index:Int, stableId: ChatMediaGridCollectionStableId, info: StickerPackCollectionInfo, topItem: StickerPackItem?)
    case recent
    case saved
    case specificPack(info: StickerPackCollectionInfo, peer: Peer)
    var stableId: ChatMediaGridCollectionStableId {
        switch self {
        case let .stickerPack(data):
            return data.stableId
        case .recent:
            return .recent
        case .saved:
            return .saved
        case let .specificPack(info, _):
            return .specificPack(info.id)
            
        }
    }
    
    static func ==(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
        case let .stickerPack(lhsIndex, lhsStableId, lhsInfo, lhsTopItem):
            if case let .stickerPack(rhsIndex, rhsStableId, rhsInfo, rhsTopItem) = rhs {
                return lhsIndex == rhsIndex && lhsStableId == rhsStableId && lhsInfo == rhsInfo && lhsTopItem == rhsTopItem
            } else {
                return false
            }
        case .recent:
            if case .recent = rhs {
                return true
            } else {
                return false
            }
        case let .specificPack(lhsInfo, lhsPeer):
            if case let .specificPack(rhsInfo, rhsPeer) = rhs {
                return lhsInfo == rhsInfo && lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        case .saved:
            if case .saved = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ChatMediaInputPanelEntry, rhs: ChatMediaInputPanelEntry) -> Bool {
        switch lhs {
        case let .stickerPack(lhsIndex, _, lhsInfo, _):
            switch rhs {
            case let .stickerPack(rhsIndex, _, rhsInfo, _):
                if lhsIndex == rhsIndex {
                    return lhsInfo.id.id > rhsInfo.id.id
                } else {
                    return lhsIndex > rhsIndex
                }
            default:
                return true
            }
        case .recent:
            switch rhs {
            case .saved:
                return true
            default:
                return false
            }
        case .specificPack:
            switch rhs {
            case .stickerPack:
                return false
            default:
                return true
            }
        case .saved:
            switch rhs {
            case .saved:
                return true
            default:
                return false
            }
        }
    }
    

}
