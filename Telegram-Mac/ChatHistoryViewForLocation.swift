//
//  ChatHistoryViewForLocation.swift
//  Telegram-Mac
//
//  Created by keepcoder on 10/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import Postbox
import TelegramCore
import InAppSettings
import SwiftSignalKit
import TGUIKit

enum ChatHistoryInitialSearchLocation {
    case index(MessageIndex)
    case id(MessageId)
}


struct ChatHistoryLocationInput: Equatable {
    var content: ChatHistoryLocation
    var id: Int32

    init(content: ChatHistoryLocation, id: Int32) {
        self.content = content
        self.id = id
    }
}

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int, side: TableSavingSide)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: TableScrollState, count: Int, animated: Bool)
    
    var count: Int {
        switch self {
        case let .Initial(count):
            return count
        case let .InitialSearch(_, count):
            return count
        case let .Navigation(_, _, count, _):
            return count
        case let .Scroll(_, _, _, _, count, _):
            return count
        }
    }
    
    var side: TableSavingSide? {
        switch self {
        case let .Navigation(_, _, _, side):
            return side
        default:
            return nil
        }
    }
}

func ==(lhs: ChatHistoryLocation, rhs: ChatHistoryLocation) -> Bool {
    switch lhs {
    case let .Navigation(lhsIndex, lhsAnchorIndex, lhsCount, lhsSide):
        switch rhs {
        case let .Navigation(rhsIndex, rhsAnchorIndex, rhsCount, rhsSide) where lhsIndex == rhsIndex && lhsAnchorIndex == rhsAnchorIndex && lhsCount == rhsCount && lhsSide == rhsSide:
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
    let cachedDataMessages:[MessageId: [Message]]?
    let readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?
    let limitsConfiguration: LimitsConfiguration
    let autoplayMedia: AutoplayMediaPreferences
    let autodownloadSettings: AutomaticMediaDownloadSettings
}

enum ChatHistoryViewUpdateType : Equatable {
    case Initial(fadeIn: Bool)
    case Generic(type: ViewUpdateType)
}

public struct ChatHistoryCombinedInitialReadStateData {
    public let unreadCount: Int32
    public let totalUnreadCount: Int32
    public let notificationSettings: PeerNotificationSettings?
}



enum ChatHistoryViewUpdate {
    case Loading(initialData: ChatHistoryCombinedInitialData, type: ChatHistoryViewUpdateType)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData)
}


func chatHistoryViewForLocation(_ location: ChatHistoryLocation, context: AccountContext, chatLocation _chatLocation: ChatLocation, fixedCombinedReadStates: (()->MessageHistoryViewReadState?)?, tagMask: MessageTags?, mode: ChatMode = .history, additionalData: [AdditionalMessageHistoryViewData] = [], orderStatistics: MessageHistoryViewOrderStatistics = [], chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic(value: nil), chatLocationInput: ChatLocationInput? = nil) -> Signal<ChatHistoryViewUpdate, NoError> {
    
    
    let account = context.account
    
    let chatLocationInput = chatLocationInput ?? context.chatLocationInput(for: _chatLocation, contextHolder: chatLocationContextHolder)
    
    
    switch location {
    case let .Initial(count):
        var preloaded = false
        var fadeIn = false
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        
        switch mode {
        case .history, .thread, .pinned:
            if let tagMask = tagMask {
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics)
            } else {
                //aroundMessageHistoryViewForLocation
                signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocationInput, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        }
        
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: _chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)

            
            if preloaded {
                //NSLog("entriescount: \(view.entries.count)")
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
                    
                    let maxIndex = targetIndex + count / 2
                    let minIndex = targetIndex - count / 2
                    if minIndex <= 0 && view.holeEarlier {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    if maxIndex >= targetIndex {
                        if view.holeLater {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                        if view.holeEarlier {
                            var incomingCount: Int32 = 0
                            inner: for entry in view.entries.reversed() {
                                if entry.message.flags.contains(.Incoming) {
                                    incomingCount += 1
                                }
                            }
                            if case let .peer(peerId) = _chatLocation, let combinedReadStates = view.fixedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId], readState.count == incomingCount {
                            } else {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        }
                    }
                } else if let opaqueState = (initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState) {
                    
                    let interfaceState = ChatInterfaceState.parse(opaqueState, peerId: _chatLocation.peerId, context: context)
                    
                    if let historyScrollState = interfaceState?.historyScrollState {
                        scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                    }
                } else {
                    if view.entries.isEmpty && (view.holeEarlier || view.holeLater) {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
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
        
        switch mode {
        case .history, .thread, .pinned:
            switch searchLocation {
            case let .index(index):
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            case let .id(id):
                signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(chatLocationInput, count: count, ignoreRelatedChats: false, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        }
        
        
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: _chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)

            
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
                
                
                if !view.entries.isEmpty {
                    let minIndex = max(0, targetIndex - count / 2)
                    let maxIndex = min(view.entries.count, targetIndex + count / 2)
                    if minIndex == 0 && view.holeEarlier {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    if maxIndex == view.entries.count && view.holeLater {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                } else if view.holeEarlier || view.holeLater {
                    fadeIn = true
                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                }
                

                var reportUpdateType: ChatHistoryViewUpdateType = .Initial(fadeIn: fadeIn)
                if case .FillHole = updateType {
                    reportUpdateType = .Generic(type: updateType)
                }

                preloaded = true
               
                var scroll: TableScrollState
                if view.entries.count > targetIndex {
                    let focusMessage = view.entries[targetIndex].message
                    let mustToFocus: Bool
                    switch searchLocation {
                    case let .index(index):
                        mustToFocus = view.entries[targetIndex].index == index
                    case let .id(id):
                        mustToFocus = view.entries[targetIndex].message.id == id
                    }
                    scroll = .center(id: ChatHistoryEntryId.message(focusMessage), innerId: nil, animated: false, focus: .init(focus: mustToFocus), inset: 0)
                } else {
                    scroll = .none(nil)
                }
                
                return .HistoryView(view: view, type: reportUpdateType, scrollPosition: .index(index: anchorIndex, position: scroll, directionHint: .Down, animated: false), initialData: combinedInitialData)
            }
        }
    case let .Navigation(index, anchorIndex, count, _):
        var first = true
        
        let signal:Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        switch mode {
        case .history, .thread, .pinned:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadStates: fixedCombinedReadStates?(), tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: _chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)
            
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
        
        let signal:Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        switch mode {
        case .history, .thread, .pinned:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadStates: fixedCombinedReadStates?(), tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: _chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)
            
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
    cachedDataMessages: [MessageId: [Message]]?,
    readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?,
    limitsConfiguration: LimitsConfiguration,
    autoplayMedia: AutoplayMediaPreferences,
    autodownloadSettings: AutomaticMediaDownloadSettings
    ) {
        var cachedData: CachedPeerData?
        var cachedDataMessages: [MessageId: [Message]]?
        var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData] = [:]
        var notificationSettings: PeerNotificationSettings?
        var limitsConfiguration: LimitsConfiguration = LimitsConfiguration.defaultValue
        var autoplayMedia: AutoplayMediaPreferences = AutoplayMediaPreferences.defaultSettings
        var autodownloadSettings: AutomaticMediaDownloadSettings = AutomaticMediaDownloadSettings.defaultSettings
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
                    cachedDataMessages = value?.mapValues { [$0] }
                }
            case let .message(messageId, messages):
                cachedDataMessages = [messageId : messages]
            case let .preferencesEntry(key, value):
                if key == PreferencesKeys.limitsConfiguration {
                    limitsConfiguration = value?.get(LimitsConfiguration.self) ?? .defaultValue
                }
                if key == ApplicationSpecificPreferencesKeys.autoplayMedia {
                    autoplayMedia = value?.get(AutoplayMediaPreferences.self) ?? .defaultSettings
                    
                }
                
                if key == ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings {
                    autodownloadSettings = value?.get(AutomaticMediaDownloadSettings.self) ?? .defaultSettings
                }
            case let .totalUnreadState(unreadState):
                if let combinedReadStates = view.fixedReadStates {
                    if case let .peer(peerId) = chatLocation, case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                        readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: 0, notificationSettings: notificationSettings)
                    }
                }
            default:
                break
            }
        }
        
        autoplayMedia = autoplayMedia.withUpdatedAutoplayPreloadVideos(autoplayMedia.preloadVideos && autodownloadSettings.automaticDownload && (autodownloadSettings.categories.video.fileSize ?? 0) >= 5 * 1024 * 1024)

        
        return (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings)
}


func preloadedChatHistoryViewForLocation(_ location: ChatHistoryLocation, context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tagMask: MessageTags?, additionalData: [AdditionalMessageHistoryViewData]) -> Signal<ChatHistoryViewUpdate, NoError> {
    return (chatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, fixedCombinedReadStates: nil, tagMask: tagMask, additionalData: additionalData, chatLocationContextHolder: chatLocationContextHolder)
        |> castError(Bool.self)
        |> mapToSignal { update -> Signal<ChatHistoryViewUpdate, Bool> in
            switch update {
            case let .Loading(_, value):
                if case .Generic(.FillHole) = value {
                    return .fail(true)
                }
            case let .HistoryView(_, value, _, _):
                if case .Generic(.FillHole) = value {
                    return .fail(true)
                }
            }
            return .single(update)
        })
        |> restartIfError
}




struct ThreadInfo {
    var message: ChatReplyThreadMessage
    var isChannelPost: Bool
    var isEmpty: Bool
    var scrollToLowerBoundMessage: MessageIndex?
    var contextHolder: Atomic<ChatLocationContextHolder?>
}

enum ThreadSubject {
    case channelPost(MessageId)
    case groupMessage(MessageId)
}


func fetchAndPreloadReplyThreadInfo(context: AccountContext, subject: ThreadSubject, atMessageId: MessageId? = nil, preload: Bool = true) -> Signal<ThreadInfo, FetchChannelReplyThreadMessageError> {
    let message: Signal<ChatReplyThreadMessage, FetchChannelReplyThreadMessageError>
    switch subject {
    case .channelPost(let messageId), .groupMessage(let messageId):
        message = context.engine.messages.fetchChannelReplyThreadMessage(messageId: messageId, atMessageId: atMessageId)
    }
    
    return message
    |> mapToSignal { replyThreadMessage -> Signal<ThreadInfo, FetchChannelReplyThreadMessageError> in
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        
        let input: ChatHistoryLocation
        var scrollToLowerBoundMessage: MessageIndex?
        switch replyThreadMessage.initialAnchor {
        case .automatic:
            if let atMessageId = atMessageId {
                input = .InitialSearch(location: .id(atMessageId), count: 40)
            } else {
                input = .Initial(count: 40)
            }
        case let .lowerBoundMessage(index):
            input = .Navigation(index: .message(index), anchorIndex: .message(index), count: 40, side: .upper)
            scrollToLowerBoundMessage = index
        }
        
        if replyThreadMessage.isNotAvailable {
            return .single(ThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: false,
                scrollToLowerBoundMessage: nil,
                contextHolder: chatLocationContextHolder
            ))
        }
        
        if preload {
            let preloadSignal = preloadedChatHistoryViewForLocation(
                input,
                context: context,
                chatLocation: .thread(replyThreadMessage),
                chatLocationContextHolder: chatLocationContextHolder,
                tagMask: nil,
                additionalData: []
            )
            return preloadSignal
            |> map { historyView -> Bool? in
                switch historyView {
                case .Loading:
                    return nil
                case let .HistoryView(view, _, _, _):
                    return view.entries.isEmpty
                }
            }
            |> mapToSignal { value -> Signal<Bool, NoError> in
                if let value = value {
                    return .single(value)
                } else {
                    return .complete()
                }
            }
            |> take(1)
            |> map { isEmpty -> ThreadInfo in
                return ThreadInfo(
                    message: replyThreadMessage,
                    isChannelPost: replyThreadMessage.isChannelPost,
                    isEmpty: isEmpty,
                    scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                    contextHolder: chatLocationContextHolder
                )
            }
            |> castError(FetchChannelReplyThreadMessageError.self)
        } else {
            return .single(ThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isEmpty: false,
                scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                contextHolder: chatLocationContextHolder
            ))
        }
    }
}

