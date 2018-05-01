//
//  PreHistoryControllerStructures.swift
//  Telegram
//
//  Created by keepcoder on 10/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac

final class PreHistoryArguments {
    fileprivate let account: Account
    fileprivate let preHistory:(Bool)->Void
    init(account:Account, preHistory:@escaping(Bool)->Void) {
        self.account = account
        self.preHistory = preHistory
    }
}

enum PreHistoryEntryId : Hashable {
    case type(Int32)
    case text(Int32)
    case section(Int32)
    var hashValue: Int {
        switch self {
        case .type(let index):
            return Int(index)
        case .text(let index):
            return Int(index)
        case .section(let index):
            return Int(index)
        }
    }
}

func ==(lhs: PreHistoryEntryId, rhs: PreHistoryEntryId) -> Bool {
    switch lhs {
    case .type(let index):
        if case .type(index) = rhs {
            return true
        } else {
            return false
        }
    case .text(let index):
        if case .text(index) = rhs {
            return true
        } else {
            return false
        }
    case .section(let index):
        if case .section(index) = rhs {
            return true
        } else {
            return false
        }
    }
}

enum PreHistoryEntry : TableItemListNodeEntry {
    case section(Int32)
    case type(sectionId:Int32, index: Int32, text: String, enabled: Bool, selected: Bool)
    case text(sectionId:Int32, index: Int32, text: String)
    
    var stableId: PreHistoryEntryId {
        switch self {
        case .type(_, let index, _, _, _):
            return .type(index)
        case .text(_, let index, _):
            return .text(index)
        case .section(let index):
            return .section(index)
        }
    }
    
    var index:Int32 {
        switch self {
        case let .type(sectionId, index, _, _, _):
            return (sectionId * 1000) + index
        case let .text(sectionId, index, _):
            return (sectionId * 1000) + index
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func item(_ arguments: PreHistoryArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .type(_, _, text, enabled, selected):
            return GeneralInteractedRowItem.init(initialSize, stableId: stableId, name: text, type: .selectable(enabled), action: {
                arguments.preHistory(enabled)
            })
        case let .text(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        }
    }
    
}

func <(lhs: PreHistoryEntry, rhs: PreHistoryEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs: PreHistoryEntry, rhs: PreHistoryEntry) -> Bool {
    switch lhs {
    case let .type(section, index, text, enabled, selected: Bool):
        if case .type(section, index, text, enabled, selected: Bool) = rhs {
            return true
        } else {
            return false
        }
    case let .text(section, index, text):
        if case .text(section, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .section(index):
        if case .section(index) = rhs {
            return true
        } else {
            return false
        }
    }
}

final class PreHistoryControllerState : Equatable {
    let enabled: Bool?
    init(enabled:Bool? = nil) {
        self.enabled = enabled
    }
    func withUpdatedEnabled(_ enabled: Bool) -> PreHistoryControllerState {
        return PreHistoryControllerState(enabled: enabled)
    }
}
func ==(lhs: PreHistoryControllerState, rhs: PreHistoryControllerState) -> Bool {
    return lhs.enabled == rhs.enabled
}
