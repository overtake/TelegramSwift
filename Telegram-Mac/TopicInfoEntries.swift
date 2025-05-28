//
//  TopicInfoEntries.swift
//  Telegram
//
//  Created by Mike Renoir on 04.10.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import Postbox
import SwiftSignalKit

final class TopicInfoArguments : PeerInfoArguments {
    
    fileprivate(set) var threadData: MessageHistoryThreadData?
    
    override func updateEditable(_ editable: Bool, peerView: PeerView, controller: PeerInfoController) -> Bool {
        
        if let threadData = threadData, let state = state as? TopicInfoState {
            let controller = ForumTopicInfoController(context: context, purpose: .edit(threadData, state.threadId), peerId: peerId)
            self.pullNavigation()?.push(controller)
        }
        
       // self.pullNavigation()?.push()
        return false
    }
    
    func share() {
        let peer = getPeerView(peerId: peerId, postbox: context.account.postbox) |> take(1) |> deliverOnMainQueue
        let context = self.context
        let state = self.state as! TopicInfoState
        let threadId = state.threadId
        _ = peer.start(next: { peer in
            if let peer = peer {
                var link: String = "https://t.me/c/\(peer.id.id._internalGetInt64Value())"
                if let address = peer.addressName, !address.isEmpty {
                    link = "https://t.me/\(address)"
                }
                link += "/\(threadId)"
                
                showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
            }
           
        })
    }
    
    override func toggleNotifications(_ currentlyMuted: Bool) {
        let state = state as! TopicInfoState
        
        toggleNotificationsDisposable.set(context.engine.peers.togglePeerMuted(peerId: peerId, threadId: state.threadId).start())
        
        pullNavigation()?.controller.show(toaster: ControllerToaster(text: currentlyMuted ? strings().toastUnmuted : strings().toastMuted))
    }
}

class TopicInfoState: PeerInfoState {
    
    struct EditingState: Equatable {
        
    }
    
    var editingState: EditingState?
    let threadId: Int64
    init(threadId: Int64) {
        self.editingState = nil
        self.threadId = threadId
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? TopicInfoState {
            return self == to
        }
        return false
    }
}



enum TopicInfoEntry: PeerInfoEntry {
    case info(section:Int, view: PeerView, threadPeer: EnginePeer?, editingState: Bool, threadData: MessageHistoryThreadData, threadId: Int64, viewType: GeneralViewType)
    case addressName(section:Int, name:String, viewType: GeneralViewType)
    case media(section:Int, controller: PeerMediaController, isVisible: Bool, viewType: GeneralViewType)
    case section(Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> TopicInfoEntry {
        switch self {
        case let .info(section, view, threadPeer, editingState, threadData, threadId, _): return .info(section: section, view: view, threadPeer: threadPeer, editingState: editingState, threadData: threadData, threadId: threadId, viewType: viewType)
        case let .addressName(section, name, _): return .addressName(section: section, name: name, viewType: viewType)
        case let .media(section, controller, isVisible, _): return  .media(section: section, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section: return self
        }
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? TopicInfoEntry else {
            return false
        }
        
        switch self {
        case let .info(lhsSection, lhsPeerView, lhsThreadPeer, lhsEditingState, lhsThreadData, lhsThreadId, lhsViewType):
            switch entry {
            case let .info(rhsSection, rhsPeerView, rhsThreadPeer, rhsEditingState, rhsThreadData, rhsThreadId, rhsViewType):
                
                if lhsThreadPeer != rhsThreadPeer {
                    return false
                }
                
                if lhsThreadData != rhsThreadData {
                    return false
                }
                if lhsThreadId != rhsThreadId {
                    return false
                }
                if lhsSection != rhsSection {
                    return false
                }
                if lhsViewType != rhsViewType {
                    return false
                }
                
                if lhsEditingState != rhsEditingState {
                    return false
                }
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                let lhsNotificationSettings = lhsPeerView.notificationSettings
                
                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                let rhsNotificationSettings = rhsPeerView.notificationSettings
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer == nil) != (rhsPeer != nil) {
                    return false
                }
                
                if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                    if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                        return false
                    }
                } else if (lhsNotificationSettings == nil) != (rhsNotificationSettings == nil) {
                    return false
                }
                if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                    if !lhsCachedData.isEqual(to: rhsCachedData) {
                        return false
                    }
                } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case let .addressName(section, addressName, viewType):
            if case .addressName(section, addressName, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .media(sectionId, _, isVisible, viewType):
            if case .media(sectionId, _, isVisible, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .section(lhsId):
            switch entry {
            case let .section(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        switch self {
        default:
            return IntPeerInfoEntryStableId(value: stableIndex)
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .addressName:
            return 1
        case .media:
            return 2
        case let .section(id):
            return (id + 1) * 100000 - id
        }
    }
    
    var sectionId: Int {
        switch self {
        case let .info(sectionId, _, _, _, _, _, _):
            return sectionId
        case let .addressName(sectionId, _, _):
            return sectionId
        case let .media(sectionId, _, _, _):
            return sectionId
        case let .section(sectionId):
            return sectionId
        }
    }
    
    var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _, _, _, _):
            return (sectionId * 100000) + stableIndex
        case let .addressName(sectionId, _, _):
            return (sectionId * 100000) + stableIndex
        case let .media(sectionId, _, _, _):
            return (sectionId * 100000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 100000 - sectionId
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? TopicInfoEntry else {
            return false
        }
        
        return self.sortIndex < other.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! TopicInfoArguments
        switch self {
        case let .info(_, peerView, threadPeer, editable, threadData, threadId, viewType):
            return PeerInfoHeadItem(initialSize, stableId: stableId.hashValue, context: arguments.context, arguments: arguments, peerView: peerView, threadData: threadData, threadId: threadId, viewType: viewType, editing: editable, threadPeer: threadPeer)
        case let .addressName(_, value, viewType):
            let link = "https://t.me/c/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: strings().peerInfoSharelink, copyMenuText: strings().textCopyLabelShareLink, text: link, context: arguments.context, viewType: viewType, isTextSelectable: false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: link)), for: arguments.context.window)
            }, selectFullWord: true, _copyToClipboard: {
                arguments.copy(link)
            })
        case let .media(_, controller, isVisible, viewType):
            return PeerMediaBlockRowItem(initialSize, stableId: stableId.hashValue, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId.hashValue, viewType: .separator)
        }
    }
}

enum TopicInfoSection : Int {
    case header = 1
    case info = 2
    case desc = 3
    case media = 4
}


func topicInfoEntries(view: PeerView, threadData: MessageHistoryThreadData, threadPeer: EnginePeer?, arguments: PeerInfoArguments, mediaTabsData: PeerMediaTabsData) -> [PeerInfoEntry] {
    var entries: [TopicInfoEntry] = []
    if let group = peerViewMainPeer(view), let arguments = arguments as? TopicInfoArguments, let state = arguments.state as? TopicInfoState {
        
        arguments.threadData = threadData
                
        var infoBlock: [TopicInfoEntry] = []
        var aboutBlock: [TopicInfoEntry] = []
        func applyBlock(_ block:[TopicInfoEntry]) {
            var block = block
            for (i, item) in block.enumerated() {
                block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
            }
            entries.append(contentsOf: block)
        }
        
        infoBlock.append(.info(section: TopicInfoSection.header.rawValue, view: view, threadPeer: threadPeer, editingState: false, threadData: threadData, threadId: state.threadId, viewType: .singleItem))
        
        
        applyBlock(infoBlock)
        
        
        
        let addressName: String = group.addressName ?? "\(group.id.id._internalGetInt64Value())"
        
        if !addressName.isEmpty {
            aboutBlock.append(.addressName(section: TopicInfoSection.desc.rawValue, name: "\(addressName)/\(state.threadId)", viewType: .singleItem))
        }
        
        applyBlock(aboutBlock)

        if mediaTabsData.loaded && !mediaTabsData.collections.isEmpty, let controller = arguments.mediaController() {
            entries.append(.media(section: TopicInfoSection.media.rawValue, controller: controller, isVisible: state.editingState == nil, viewType: .singleItem))
        }
        
        var items:[TopicInfoEntry] = []
        var sectionId:Int = 0
        for entry in entries {
            if entry.sectionId == TopicInfoSection.media.rawValue {
                sectionId = entry.sectionId
            } else if entry.sectionId != sectionId {
                items.append(.section(sectionId))
                sectionId = entry.sectionId
            }
            items.append(entry)
        }
        sectionId += 1
        items.append(.section(sectionId))
        
        entries = items
    }
    
    return entries.sorted(by: { p1, p2 -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
