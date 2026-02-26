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

enum ChatHistoryInitialSearchLocation : Equatable {
    case index(MessageIndex, String?)
    case id(MessageId, String?)
}


struct ChatHistoryLocationInput: Equatable {
    var content: ChatHistoryLocation
    var id: Int32
    var tag: HistoryViewInputTag?
    var chatLocation: ChatLocation
    init(content: ChatHistoryLocation, chatLocation: ChatLocation, tag: HistoryViewInputTag?, id: Int32) {
        self.content = content
        self.chatLocation = chatLocation
        self.id = id
        self.tag = tag
    }
}

enum ChatHistoryLocation: Equatable {
    case Initial(count: Int, scrollPosition: TableScrollState?)
    case InitialSearch(location: ChatHistoryInitialSearchLocation, count: Int)
    case Navigation(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, count: Int, side: TableSavingSide)
    case Scroll(index: MessageHistoryAnchorIndex, anchorIndex: MessageHistoryAnchorIndex, sourceIndex: MessageHistoryAnchorIndex, scrollPosition: TableScrollState, count: Int, animated: Bool)
    var count: Int {
        switch self {
        case let .Initial(count, _):
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



enum ChatHistoryViewScrollPosition : Equatable {
    case unread(index: MessageIndex)
    case scroll(TableScrollState)
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
    case let .scroll(value):
        if case .scroll(value) = rhs {
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
    var initialData: InitialMessageHistoryData? = nil
    var buttonKeyboardMessage: Message? = nil
    var cachedData: CachedPeerData? = nil
    var cachedDataMessages:[MessageId: [Message]]? = nil
    var readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]? = nil
    var limitsConfiguration: LimitsConfiguration = .defaultValue
    var autoplayMedia: AutoplayMediaPreferences = .defaultSettings
    var autodownloadSettings: AutomaticMediaDownloadSettings = .defaultSettings
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


func chatHistoryViewForLocation(_ location: ChatHistoryLocation, context: AccountContext, chatLocation _chatLocation: ChatLocation, fixedCombinedReadStates: (()->MessageHistoryViewReadState?)?, tag: HistoryViewInputTag?, mode: ChatMode = .history, additionalData: [AdditionalMessageHistoryViewData] = [], orderStatistics: MessageHistoryViewOrderStatistics = [], chatLocationContextHolder: Atomic<ChatLocationContextHolder?> = Atomic(value: nil), chatLocationInput: ChatLocationInput? = nil) -> Signal<ChatHistoryViewUpdate, NoError> {
    
    
    let account = context.account
    
    let chatLocationInput = chatLocationInput ?? context.chatLocationInput(for: _chatLocation, contextHolder: chatLocationContextHolder)
    
    let ignoreRelatedChats: Bool
    if let tag = tag, case .tag(.pinned) = tag {
        ignoreRelatedChats = true
    } else {
        ignoreRelatedChats = false
    }
    
    switch mode {
    case .customChatContents(let contents):
        return contents.historyView |> map { view in
            return .HistoryView(view: view.0, type: .Generic(type: view.1), scrollPosition: nil, initialData: .init())
        }
    default:
        break
    }

    
    switch location {
    case let .Initial(count, scroll):
        var preloaded = false
        var fadeIn = false
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        
        switch mode {
        case .history, .thread, .pinned, .customChatContents, .preview:
            if let tag = tag {
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: .upperBound, anchorIndex: .upperBound, count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: nil, tag: tag, orderStatistics: orderStatistics)
            } else {
                signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocationInput, count: count, tag: tag, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        case .customLink:
            signal = .single((MessageHistoryView(tag: nil, namespaces: .all, entries: [], holeEarlier: false, holeLater: false, isLoading: false), ViewUpdateType.Generic, nil))
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: _chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)

            
            if preloaded {
                //NSLog("entriescount: \(view.entries.count)")
                return .HistoryView(view: view, type: .Generic(type: updateType), scrollPosition: nil, initialData: combinedInitialData)
            } else {
                if view.isLoading {
                    return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                }

                var scrollPosition: ChatHistoryViewScrollPosition?
                
                
                let canScrollToRead: Bool
                if case let .thread(message) = _chatLocation, !message.isForumPost {
                    canScrollToRead = true
                } else if view.isAddedToChatList {
                    canScrollToRead = true
                } else {
                    canScrollToRead = false
                }

                if tag == nil, case let .thread(message) = _chatLocation, message.isForumPost, view.maxReadIndex == nil {
                    if case let .message(index) = view.anchorIndex {
                        //index(index: .message(index), position: .bottom(0.0), directionHint: .Up)
                        scrollPosition = .index(index: .message(index), position: .top(id: AnyHashable(0), innerId: nil, animated: false, focus: .init(focus: false), inset: 0), directionHint: .Up, animated: false)
                    }
                }

                
                if let maxReadIndex = view.maxReadIndex, tag == nil, canScrollToRead {
                    let aroundIndex = maxReadIndex
                    scrollPosition = .unread(index: maxReadIndex)
                    
                    var targetIndex = 0
                    for i in 0 ..< view.entries.count {
                        if view.entries[i].index >= aroundIndex {
                            targetIndex = i
                            break
                        }
                    }
                    
                    let maxIndex = targetIndex + 40
                    let minIndex = targetIndex - 40
                    if minIndex <= 0 && view.holeEarlier {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    if maxIndex >= view.entries.count {
                        if view.holeLater {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                        if view.holeEarlier {
                            var incomingCount: Int32 = 0
                            inner: for entry in view.entries.reversed() {
                                if !entry.message.flags.intersection(.IsIncomingMask).isEmpty {
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
                } else if view.isAddedToChatList, tag == nil, let opaqueState = (initialData?.storedInterfaceState).flatMap(_internal_decodeStoredChatInterfaceState) {
                    
                    let interfaceState = ChatInterfaceState.parse(opaqueState, peerId: _chatLocation.peerId, context: context)
                    
                    if let historyScrollState = interfaceState?.historyScrollState {
                        scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
                    }
                } else {
                    if !view.isAddedToChatList {
                        if view.holeEarlier && view.entries.count <= 2 {
                            fadeIn = true
                            return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                        }
                    }
                    if view.entries.isEmpty && (view.holeEarlier || view.holeLater) {
                        fadeIn = true
                        return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                    }
                    
                }

                if let scrollState = scroll, updateType == .Initial, scrollPosition == nil {
                    scrollPosition = .scroll(scrollState)
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
        case .history, .thread, .pinned, .customChatContents, .preview:
            switch searchLocation {
            case let .index(index, _):
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: nil, tag: tag, orderStatistics: orderStatistics, additionalData: additionalData)
            case let .id(id, _):
                signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(chatLocationInput, count: count, ignoreRelatedChats: ignoreRelatedChats, messageId: id, tag: tag, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        case .customLink:
            signal = .complete()
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
                    let text: String?
                    switch searchLocation {
                    case let .index(index, string):
                        mustToFocus = view.entries[targetIndex].index == index
                        text = string
                    case let .id(id, string):
                        mustToFocus = view.entries[targetIndex].message.id == id
                        text = string
                    }
                    scroll = .center(id: ChatHistoryEntryId.message(focusMessage), innerId: nil, animated: false, focus: .init(focus: mustToFocus, string: text), inset: 0)
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
        case .history, .thread, .pinned, .customChatContents, .preview:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: index, anchorIndex: anchorIndex, count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates?(), tag: tag, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        case .customLink:
            signal = .complete()
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
        case .history, .thread, .pinned, .customChatContents, .preview:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocationInput, index: index, anchorIndex: anchorIndex, count: count, ignoreRelatedChats: ignoreRelatedChats, fixedCombinedReadStates: fixedCombinedReadStates?(), tag: tag, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocationInput)
        case .customLink:
            signal = .complete()
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


func preloadedChatHistoryViewForLocation(_ location: ChatHistoryLocation, context: AccountContext, chatLocation: ChatLocation, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tag: HistoryViewInputTag?, additionalData: [AdditionalMessageHistoryViewData]) -> Signal<ChatHistoryViewUpdate, NoError> {
    return (chatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, fixedCombinedReadStates: nil, tag: tag, additionalData: additionalData, chatLocationContextHolder: chatLocationContextHolder)
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
    var isMonoforumPost: Bool
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
                input = .InitialSearch(location: .id(atMessageId, nil), count: 40)
            } else {
                input = .Initial(count: 40, scrollPosition: nil)
            }
        case let .lowerBoundMessage(index):
            input = .Navigation(index: .message(index), anchorIndex: .message(index), count: 40, side: .upper)
            scrollToLowerBoundMessage = index
        }
        
        if replyThreadMessage.isNotAvailable {
            return .single(ThreadInfo(
                message: replyThreadMessage,
                isChannelPost: replyThreadMessage.isChannelPost,
                isMonoforumPost: replyThreadMessage.isMonoforumPost,
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
                tag: nil,
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
                    isMonoforumPost: replyThreadMessage.isMonoforumPost,
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
                isMonoforumPost: replyThreadMessage.isMonoforumPost,
                isEmpty: false,
                scrollToLowerBoundMessage: scrollToLowerBoundMessage,
                contextHolder: chatLocationContextHolder
            ))
        }
    }
}

