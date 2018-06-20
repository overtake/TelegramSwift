//
//  ChatHistoryViewForLocation.swift
//  Telegram-Mac
//
//  Created by keepcoder on 10/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit

enum ChatHistoryInitialSearchLocation {
    case index(MessageIndex)
    case id(MessageId)
}

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: TableScrollState, count: Int, animated: Bool)
    
    var count: Int {
        switch self {
        case let .Initial(count):
            return count
        case let .InitialSearch(_, count):
            return count
        case let .Navigation(_, _, count):
            return count
        case let .Scroll(_, _, _, _, count, _):
            return count
        }
    }
}

func ==(lhs: ChatHistoryLocation, rhs: ChatHistoryLocation) -> Bool {
    switch lhs {
    case let .Navigation(lhsIndex, lhsAnchorIndex, lhsCount):
        switch rhs {
        case let .Navigation(rhsIndex, rhsAnchorIndex, rhsCount) where lhsIndex == rhsIndex && lhsAnchorIndex == rhsAnchorIndex && lhsCount == rhsCount:
            return true
        default:
            return false
        }
    default:
        return false
    }
}



enum ChatHistoryViewScrollPosition : Equatable {
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(index: MessageHistoryAnchorIndex, position: TableScrollState, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

func ==(lhs: ChatHistoryViewScrollPosition, rhs: ChatHistoryViewScrollPosition) -> Bool {
    switch lhs {
    case let .unread(index):
        if case .unread(index: index) = rhs {
            return true
        } else {
            return false
        }
    case let .positionRestoration(index, relativeOffset):
        if case .positionRestoration(index: index, relativeOffset: relativeOffset) = rhs {
            return true
        } else {
            return false
        }
    case let .index(index, position, directionHint, animated):
        if case .index(index: index, position: position, directionHint: directionHint, animated: animated) = rhs {
            return true
        } else {
            return false
        }
    }
}

public struct ChatHistoryCombinedInitialData {
    let initialData: InitialMessageHistoryData?
    let buttonKeyboardMessage: Message?
    let cachedData: CachedPeerData?
    let cachedDataMessages:[MessageId: Message]?
    let readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalUnreadCount: Int32
    public let notificationSettings: PeerNotificationSettings?
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: ChatHistoryCombinedInitialData)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData)
}


func chatHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, chatLocation: ChatLocation, fixedCombinedReadStates: MessageHistoryViewReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData] = [], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    
    switch location {
    case let .Initial(count):
        var preloaded = false
        var fadeIn = false
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        if let tagMask = tagMask {
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, count: count, clipHoles: true, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        } else {
            signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocation, count: count, clipHoles: true, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        }
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)

            
            if preloaded {
                return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: combinedInitialData)
            } else {
                var scrollPosition: ChatHistoryViewScrollPosition?
                
                if let maxReadIndex = view.maxReadIndex, tagMask == nil {
                    let aroundIndex = maxReadIndex
                    scrollPosition = .unread(index: maxReadIndex)
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if view.entries[i].index >= aroundIndex {
                            targetIndex = i
                            break
                        }
                    }
                    
                    let maxIndex = min(view.entries.count, targetIndex + count / 2)
                    if maxIndex >= targetIndex {
                        for i in targetIndex ..< maxIndex {
                            if case let .HoleEntry(hole) = view.entries[i] {
                                var incomingCount: Int32 = 0
                                inner: for entry in view.entries.reversed() {
                                    switch entry {
                                    case .HoleEntry:
                                        break inner
                                    case let .MessageEntry(message, _, _, _):
                                        if message.flags.contains(.Incoming) {
                                            incomingCount += 1
                                        }
                                    }
                                }
                                if let combinedReadStates = view.combinedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[hole.0.maxIndex.id.peerId], readState.count == incomingCount {
                                } else {
                                    fadeIn = true
                                    return .Loading(initialData: combinedInitialData)
                                }
                            }
                        }
                    }
                } else if let historyScrollState = (initialData?.chatInterfaceState as? ChatInterfaceState)?.historyScrollState {
                    scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                } else {
                    var messageCount = 0
                    for entry in view.entries.reversed() {
                        if case .HoleEntry = entry {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData)
                        } else {
                            messageCount += 1
                        }
                        if messageCount >= 1 {
                            break
                        }
                    }
                }
                
                preloaded = true
                return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, initialData: combinedInitialData)
            }
        }
    case let .InitialSearch(searchLocation, count):
        var preloaded = false
        var fadeIn = false
        
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        switch searchLocation {
        case let .index(index):
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: count, clipHoles: true, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case let .id(id):
            signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(chatLocation, count: count, clipHoles: true, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)

            
            if preloaded {
                return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: combinedInitialData)
            } else {
                let anchorIndex = view.anchorIndex
                
                var targetIndex = 0
                for i in 0 ..< view.entries.count {
                    //if view.entries[i].index >= anchorIndex
                    if anchorIndex.isLessOrEqual(to: view.entries[i].index) {
                        targetIndex = i
                        break
                    }
                }
                
                
                let maxIndex = min(view.entries.count, targetIndex + count / 2)
                if maxIndex >= targetIndex {
                    for i in targetIndex ..< maxIndex {
                        if case .HoleEntry = view.entries[i] {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData)
                        }
                    }
                }
                
                preloaded = true
               
                var scroll: TableScrollState
                if view.entries.count > targetIndex, let message = view.entries[targetIndex].message {
                    scroll = .center(id: ChatHistoryEntryId.message(message), innerId: nil, animated: false, focus: true, inset: 0)
                } else {
                    scroll = .none(nil)
                }
                
                return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .index(index: anchorIndex, position: scroll, directionHint: .Down, animated: false), initialData: combinedInitialData)
            }
        }
    case let .Navigation(index, anchorIndex, count):
        var first = true
        
        return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: count, clipHoles: true, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
            
            let genericType: ViewUpdateType
            if first {
                first = false
                genericType = ViewUpdateType.UpdateVisible
            } else {
                genericType = updateType
            }
            return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, initialData: combinedInitialData)
        }
    case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, count, animated):
        let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
        let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
        var first = true
        
        return account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: count, clipHoles: true, fixedCombinedReadStates: fixedCombinedReadStates, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData) = extractAdditionalData(view: view, chatLocation: chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData)
            
            let genericType: ViewUpdateType
            let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
            if first {
                first = false
                genericType = ViewUpdateType.UpdateVisible
            } else {
                genericType = updateType
            }
            return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, initialData: combinedInitialData)
        }
    }
}

private func extractAdditionalData(view: MessageHistoryView, chatLocation: ChatLocation) -> (
    cachedData: CachedPeerData?,
    cachedDataMessages: [MessageId: Message]?,
    readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    ) {
        var cachedData: CachedPeerData?
        var cachedDataMessages: [MessageId: Message]?
        var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData] = [:]
        var notificationSettings: PeerNotificationSettings?
        
        loop: for data in view.additionalData {
            switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
                break loop
            default:
                break
            }
        }
        
        for data in view.additionalData {
            switch data {
            case let .peerNotificationSettings(value):
                notificationSettings = value
            case let .cachedPeerData(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    cachedData = value
                }
            case let .cachedPeerDataMessages(peerIdValue, value):
                if case .peer(peerIdValue) = chatLocation {
                    cachedDataMessages = value
                }
            case let .totalUnreadState(unreadState):
                
                switch chatLocation {
                case let .peer(peerId):
                    if let combinedReadStates = view.combinedReadStates {
                        if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                            readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: unreadState.absoluteCounters.messageCount, notificationSettings: notificationSettings)
                        }
                    }
                case .group:
                    break
                }
            default:
                break
            }
        }
        
        return (cachedData, cachedDataMessages, readStateData)
}
