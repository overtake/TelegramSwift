//
//  PeerMediaCollectionInterfaceState.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox
import TGUIKit

final class PeerMediaCollectionInteraction : InterfaceObserver {
    private(set) var interfaceState:PeerMediaCollectionInterfaceState
    
    func update(animated:Bool = false, _ f:(PeerMediaCollectionInterfaceState)->PeerMediaCollectionInterfaceState)->Void {
        let oldValue = interfaceState
        interfaceState = f(interfaceState)
        if oldValue != interfaceState {
            notifyObservers(value: interfaceState, oldValue:oldValue, animated: animated)
        }
    }
    
    var deleteSelected:()->Void = {}
    var forwardSelected:()->Void = {}
    
    override init() {
        self.interfaceState = PeerMediaCollectionInterfaceState()
    }
}

enum PeerMediaCollectionMode : Int32 {
    case savedMessages = -4
    case members = -3
    case stories = -2
    case photoOrVideo = -1
    case saved = 0
    case file = 1
    case webpage = 2
    case music = 3
    case voice = 4
    case commonGroups = 5
    case gifs = 6
    case similarChannels = 7
    var tagsValue:MessageTags {
        switch self {
        case .photoOrVideo:
            return .photoOrVideo
        case .file:
            return .file
        case .music:
            return .music
        case .webpage:
            return .webPage
        case .voice:
            return .voiceOrInstantVideo
        case .members:
           return []
        case .commonGroups:
            return []
        case .gifs:
            return .gif
        case .stories:
            return []
        case .similarChannels:
            return []
        case .savedMessages:
            return []
        case .saved:
            return []
        }
    }
}


struct PeerMediaCollectionInterfaceState: Equatable {
    let peer: Peer?
    let selectionState: ChatInterfaceSelectionState?
    let mode: PeerMediaCollectionMode
    let selectingMode: Bool
    
    init() {
        self.peer = nil
        self.selectionState = nil
        self.mode = .photoOrVideo
        self.selectingMode = false
    }
    
    init(peer: Peer?, selectionState: ChatInterfaceSelectionState?, mode: PeerMediaCollectionMode, selectingMode: Bool) {
        self.peer = peer
        self.selectionState = selectionState
        self.mode = mode
        self.selectingMode = selectingMode
    }
    
    static func ==(lhs: PeerMediaCollectionInterfaceState, rhs: PeerMediaCollectionInterfaceState) -> Bool {
        if let peer = lhs.peer {
            if rhs.peer == nil || !peer.isEqual(rhs.peer!) {
                return false
            }
        } else if let _ = rhs.peer {
            return false
        }
        
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        
        if lhs.mode != rhs.mode {
            return false
        }
        
        if lhs.selectingMode != rhs.selectingMode {
            return false
        }
        
        return true
    }
    
   
    
    func isSelectedMessageId(_ messageId:MessageId) -> Bool {
        if let selectionState = selectionState {
            return selectionState.selectedIds.contains(messageId)
        }
        return false
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        selectedIds.insert(messageId)
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds, lastSelectedId: nil), mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> PeerMediaCollectionInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.contains(messageId) {
            let _ = selectedIds.remove(messageId)
        } else {
            selectedIds.insert(messageId)
        }
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds, lastSelectedId: nil), mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState ?? ChatInterfaceSelectionState(selectedIds: Set(), lastSelectedId: nil), mode: self.mode, selectingMode: true)
    }
    
    func withoutSelectionState() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: nil, mode: self.mode, selectingMode: false)
    }
    
    func withUpdatedPeer(_ peer: Peer?) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: peer, selectionState: self.selectionState, mode: self.mode, selectingMode: self.selectingMode)
    }
    
    func withToggledSelectingMode() -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: self.mode, selectingMode: !self.selectingMode)
    }
    
    func withMode(_ mode: PeerMediaCollectionMode) -> PeerMediaCollectionInterfaceState {
        return PeerMediaCollectionInterfaceState(peer: self.peer, selectionState: self.selectionState, mode: mode, selectingMode: self.selectingMode)
    }
}

