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
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: TableScrollState, animated: Bool)
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



enum ChatHistoryViewScrollPosition {
    case unread(index: MessageIndex)
    case positionRestoration(index: MessageIndex, relativeOffset: CGFloat)
    case index(index: MessageHistoryAnchorIndex, position: TableScrollState, directionHint: ListViewScrollToItemDirectionHint, animated: Bool)
}

public struct ChatHistoryCombinedInitialData {
    let initialData: InitialMessageHistoryData?
    let buttonKeyboardMessage: Message?
    let cachedData: CachedPeerData?
    let readStateData: ChatHistoryCombinedInitialReadStateData?
}

enum ChatHistoryViewUpdateType {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalUnreadCount: Int32
}

enum ChatHistoryViewUpdate {
    case Loading(initialData: InitialMessageHistoryData?)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData)
}


func chatHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, peerId: PeerId, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData] = [], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    switch location {
    case let .Initial(count):
        var preloaded = false
        var fadeIn = false
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        if let tagMask = tagMask {
            
            signal = account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: MessageHistoryAnchorIndex.upperBound, anchorIndex: MessageHistoryAnchorIndex.upperBound, count: count, fixedCombinedReadState: nil, tagMask: tagMask, orderStatistics: orderStatistics)
        } else {
            signal = account.viewTracker.aroundMessageOfInterestHistoryViewForPeerId(peerId, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        }
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            var cachedData: CachedPeerData?
            var readStateData: ChatHistoryCombinedInitialReadStateData?
            for data in view.additionalData {
                switch data {
                case let .cachedPeerData(peerIdValue, value):
                    if peerIdValue == peerId {
                        cachedData = value
                    }
                case let .totalUnreadCount(totalUnreadCount):
                    if let readState = view.combinedReadState {
                        readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount)
                    }
                default:
                    break
                }
            }

            
            if preloaded {
                return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
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
                            if case .HoleEntry = view.entries[i] {
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
                                if let combinedReadState = view.combinedReadState, combinedReadState.count == incomingCount {
                                    
                                } else {
                                    fadeIn = true
                                    return .Loading(initialData: initialData)
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
                            return .Loading(initialData: initialData)
                        } else {
                            messageCount += 1
                        }
                        if messageCount >= 1 {
                            break
                        }
                    }
                }
                
                preloaded = true
                return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
            }
        }
    case let .InitialSearch(searchLocation, count):
        var preloaded = false
        var fadeIn = false
        
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        switch searchLocation {
        case let .index(index):
            
            signal = account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: count, fixedCombinedReadState: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case let .id(id):
            signal = account.viewTracker.aroundIdMessageHistoryViewForPeerId(peerId, count: count, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            var cachedData: CachedPeerData?
            var readStateData: ChatHistoryCombinedInitialReadStateData?
            for data in view.additionalData {
                switch data {
                case let .cachedPeerData(peerIdValue, value):
                    if peerIdValue == peerId {
                        cachedData = value
                    }
                case let .totalUnreadCount(totalUnreadCount):
                    if let readState = view.combinedReadState {
                        readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount)
                    }
                default:
                    break
                }
            }
            
            if preloaded {
                return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
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
                            return .Loading(initialData: initialData)
                        }
                    }
                }
                
                preloaded = true
               
                var scroll: TableScrollState
                if view.entries.count > targetIndex, let message = view.entries[targetIndex].message {
                    scroll = .center(id: ChatHistoryEntryId.message(message), animated: false, focus: true, inset: 0)
                } else {
                    scroll = .none(nil)
                }
                
                return .HistoryView(view: view, type: .Initial(fadeIn: fadeIn), scrollPosition: .index(index: anchorIndex, position: scroll, directionHint: .Down, animated: false), initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
            }
        }
    case let .Navigation(index, anchorIndex, count):
        var first = true
        return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            var cachedData: CachedPeerData?
            var readStateData: ChatHistoryCombinedInitialReadStateData?
            for data in view.additionalData {
                switch data {
                case let .cachedPeerData(peerIdValue, value):
                    if peerIdValue == peerId {
                        cachedData = value
                    }
                case let .totalUnreadCount(totalUnreadCount):
                    if let readState = view.combinedReadState {
                        readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount)
                    }
                default:
                    break
                }
            }
            
            let genericType: ViewUpdateType
            if first {
                first = false
                genericType = ViewUpdateType.UpdateVisible
            } else {
                genericType = updateType
            }
            return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: nil, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
        }
    case let .Scroll(index, anchorIndex, sourceIndex, scrollPosition, animated):
        let directionHint: ListViewScrollToItemDirectionHint = sourceIndex > index ? .Down : .Up
        let chatScrollPosition = ChatHistoryViewScrollPosition.index(index: index, position: scrollPosition, directionHint: directionHint, animated: animated)
        var first = true
        return account.viewTracker.aroundMessageHistoryViewForPeerId(peerId, index: index, anchorIndex: anchorIndex, count: 140, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData) |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            var cachedData: CachedPeerData?
            var readStateData: ChatHistoryCombinedInitialReadStateData?
            for data in view.additionalData {
                switch data {
                case let .cachedPeerData(peerIdValue, value):
                    if peerIdValue == peerId {
                        cachedData = value
                    }
                case let .totalUnreadCount(totalUnreadCount):
                    if let readState = view.combinedReadState {
                        readStateData = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: totalUnreadCount)
                    }
                default:
                    break
                }
            }
            
            let genericType: ViewUpdateType
            let scrollPosition: ChatHistoryViewScrollPosition? = first ? chatScrollPosition : nil
            if first {
                first = false
                genericType = ViewUpdateType.UpdateVisible
            } else {
                genericType = updateType
            }
            return .HistoryView(view: view, type: .Generic(type: genericType), scrollPosition: scrollPosition, initialData: ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, readStateData: readStateData))
        }
    }
}
