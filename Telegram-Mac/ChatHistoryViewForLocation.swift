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
import SyncCore
import SwiftSignalKit
import TGUIKit

enum ChatHistoryInitialSearchLocation {
    case index(MessageIndex)
    case id(MessageId)
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
            return false
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
    let limitsConfiguration: LimitsConfiguration
    let autoplayMedia: AutoplayMediaPreferences
    let autodownloadSettings: AutomaticMediaDownloadSettings
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
    case Loading(initialData: ChatHistoryCombinedInitialData, type: ChatHistoryViewUpdateType)
    case HistoryView(view: MessageHistoryView, type: ChatHistoryViewUpdateType, scrollPosition: ChatHistoryViewScrollPosition?, initialData: ChatHistoryCombinedInitialData)
}


func chatHistoryViewForLocation(_ location: ChatHistoryLocation, account: Account, chatLocation: ChatLocation, fixedCombinedReadStates: (()->MessageHistoryViewReadState?)?, tagMask: MessageTags?, mode: ChatMode = .history, additionalData: [AdditionalMessageHistoryViewData] = [], orderStatistics: MessageHistoryViewOrderStatistics = []) -> Signal<ChatHistoryViewUpdate, NoError> {
    
    

    
    switch location {
    case let .Initial(count):
        var preloaded = false
        var fadeIn = false
        let signal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
        
        switch mode {
        case .history:
            if let tagMask = tagMask {
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: .upperBound, anchorIndex: .upperBound, count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics)
            } else {
                signal = account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(chatLocation, count: count, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocation)
        }
        
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: chatLocation)
            let combinedInitialData = ChatHistoryCombinedInitialData(initialData: initialData, buttonKeyboardMessage: view.topTaggedMessages.first, cachedData: cachedData, cachedDataMessages: cachedDataMessages, readStateData: readStateData, limitsConfiguration: limitsConfiguration, autoplayMedia: autoplayMedia, autodownloadSettings: autodownloadSettings)

            
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
                            if case let .peer(peerId) = chatLocation, let combinedReadStates = view.fixedReadStates, case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId], readState.count == incomingCount {
                            } else {
                                fadeIn = true
                                return .Loading(initialData: combinedInitialData, type: .Generic(type: updateType))
                            }
                        }
                    }

                } else if let historyScrollState = (initialData?.chatInterfaceState as? ChatInterfaceState)?.historyScrollState {
                    scrollPosition = .positionRestoration(index: historyScrollState.messageIndex, relativeOffset: CGFloat(historyScrollState.relativeOffset))
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
        case .history:
            switch searchLocation {
            case let .index(index):
                signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: MessageHistoryAnchorIndex.message(index), anchorIndex: MessageHistoryAnchorIndex.message(index), count: count, fixedCombinedReadStates: nil, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            case let .id(id):
                signal = account.viewTracker.aroundIdMessageHistoryViewForLocation(chatLocation, count: count, messageId: id, tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
            }
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocation)
        }
        
        
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: chatLocation)
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
        case .history:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadStates: fixedCombinedReadStates?(), tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocation)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: chatLocation)
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
        case .history:
            signal = account.viewTracker.aroundMessageHistoryViewForLocation(chatLocation, index: index, anchorIndex: anchorIndex, count: count, fixedCombinedReadStates: fixedCombinedReadStates?(), tagMask: tagMask, orderStatistics: orderStatistics, additionalData: additionalData)
        case .scheduled:
            signal = account.viewTracker.scheduledMessagesViewForLocation(chatLocation)
        }
        
        return signal |> map { view, updateType, initialData -> ChatHistoryViewUpdate in
            let (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings) = extractAdditionalData(view: view, chatLocation: chatLocation)
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
    cachedDataMessages: [MessageId: Message]?,
    readStateData: [PeerId: ChatHistoryCombinedInitialReadStateData]?,
    limitsConfiguration: LimitsConfiguration,
    autoplayMedia: AutoplayMediaPreferences,
    autodownloadSettings: AutomaticMediaDownloadSettings
    ) {
        var cachedData: CachedPeerData?
        var cachedDataMessages: [MessageId: Message]?
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
                    cachedDataMessages = value
                }
            case let .preferencesEntry(key, value):
                if key == PreferencesKeys.limitsConfiguration {
                    limitsConfiguration = value as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
                }
                if key == ApplicationSpecificPreferencesKeys.autoplayMedia {
                    autoplayMedia = value as? AutoplayMediaPreferences ?? AutoplayMediaPreferences.defaultSettings
                    
                }
                
                if key == ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings {
                    autodownloadSettings = value as? AutomaticMediaDownloadSettings ?? AutomaticMediaDownloadSettings.defaultSettings
                }
            case let .totalUnreadState(unreadState):
                
                switch chatLocation {
                case let .peer(peerId):
                    break
                    if let combinedReadStates = view.fixedReadStates {
                        if case let .peer(readStates) = combinedReadStates, let readState = readStates[peerId] {
                            readStateData[peerId] = ChatHistoryCombinedInitialReadStateData(unreadCount: readState.count, totalUnreadCount: 0, notificationSettings: notificationSettings)
                        }
                    }
                }
            default:
                break
            }
        }
        
        autoplayMedia = autoplayMedia.withUpdatedAutoplayPreloadVideos(autoplayMedia.preloadVideos && autodownloadSettings.automaticDownload && (autodownloadSettings.categories.video.fileSize ?? 0) >= 5 * 1024 * 1024)

        
        return (cachedData, cachedDataMessages, readStateData, limitsConfiguration, autoplayMedia, autodownloadSettings)
}
