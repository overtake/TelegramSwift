 //
//  ChatInterfaceStateContextQueries.swift
//  TelegramMac
//
//  Created by keepcoder on 22/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import SwiftSignalKit
import TelegramCore
import TGModernGrowingTextView
import Postbox
import InAppSettings
import TGUIKit
import InputView

extension WebpagePreviewResult {
    var result: TelegramMediaWebpage? {
        switch self {
        case .progress:
            return nil
        case let .result(webpage):
            return webpage?.webpage
        }
    }
}

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    let inputQuery = chatPresentationInterfaceState.inputContext
    switch chatPresentationInterfaceState.state {
    case .normal, .editing:
        if inputQuery != .none {
            
            if inputQuery == currentQuery, chatPresentationInterfaceState.inputContext == chatPresentationInterfaceState.effectiveInputContext {
                return nil
            } else {
                return makeInlineResult(inputQuery, chatPresentationInterfaceState: chatPresentationInterfaceState, currentQuery: currentQuery, context: context)
            }
        } else {
            return (nil, .single({ _ in return nil }))
        }
    default:
        return (nil, .single({ _ in return nil }))
    }
    
}

private func makeInlineResult(_ inputQuery: ChatPresentationInputQuery, chatPresentationInterfaceState: ChatPresentationInterfaceState, currentQuery: ChatPresentationInputQuery?,  context: AccountContext)  -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)?  {
    switch inputQuery {
    case .none:
        return (nil, .single({ _ in return nil }))
    case let .hashtag(query):
        
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
        if let currentQuery = currentQuery {
            switch currentQuery {
            case .hashtag:
                break
            default:
                signal = .single({ _ in return nil })
            }
        }
        
        let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = context.engine.messages.recentlyUsedHashtags() |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            let normalizedQuery = query.lowercased()
            var result: [String] = []
            for hashtag in hashtags {
                if hashtag.lowercased().hasPrefix(normalizedQuery) {
                    result.append(hashtag)
                }
            }
            return { _ in return .hashtags(result) }
        }
        
        return (inputQuery, signal |> then(hashtags))
        
    case let .stickers(query):
        
        return (inputQuery, context.account.postbox.transaction { transaction -> StickerSettings in
            let stickerSettings: StickerSettings = transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.stickerSettings)?.get(StickerSettings.self) ?? .defaultSettings
            return stickerSettings
        }
        |> mapToSignal { stickerSettings -> Signal<[FoundStickerItem], NoError> in
                let scope: SearchStickersScope
                switch stickerSettings.emojiStickerSuggestionMode {
                case .none:
                    scope = []
                case .all:
                    scope = [.installed, .remote]
                case .installed:
                    scope = [.installed]
                }
                return context.engine.stickers.searchStickers(query: [query], scope: scope) |> map { $0.items }
        }
        |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            return { _ in
                return .stickers(stickers)
            }
        })
        
//        return (inputQuery, searchStickers(account: account, query: query) |> map { stickers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
//            return { _ in return .stickers(stickers) }
//        })
    case let .emoji(query, firstWord):
        if !query.isEmpty {
            let signal = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, engine: context.engine, sharedContext: context.sharedContext, query: query, completeMatch: query.length < 3, checkPrediction: firstWord) |> mapToSignal { results in
                return context.engine.stickers.searchEmoji(emojiString: results)
                |> map { ($0.isFinalResult ? results : [], $0.items) }
            } |> deliverOnResourceQueue |> delay(firstWord ? 0.3 : 0, queue: .concurrentDefaultQueue())

            if firstWord {
                return (inputQuery, .single({ _ in return nil }) |> then(signal |> map { matches -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(matches.0, matches.1, firstWord) }
                }))
            } else {
                return (inputQuery, signal |> map { matches -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(matches.0, matches.1, firstWord) }
                })
            }
        } else {
            
            let animated = combineLatest(queue: resourcesQueue, context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 200) |> map {
                $0.entries.compactMap({ $0.item as? StickerPackItem}).map { $0.file }
            }, context.account.viewTracker.featuredEmojiPacks()) |> map {
                Array($0 + $1.reduce([], { current, value in
                    return current + value.topItems.map { $0.file }
                }).prefix(400))
            }

            
            if firstWord {
                return (nil, .single({ _ in return nil }))
            } else {
                return (inputQuery, combineLatest(recentUsedEmoji(postbox: context.account.postbox), animated) |> map { emojis, animated -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    
                    var toRemove: [String] = []
                    var selected: [TelegramMediaFile] = []
                    for sort in emojis.animated {
                        let file = animated.filter({ $0.fileId == sort}).first
                        if let file = file {
                            selected.append(file)
                            if let text = file.customEmojiText {
                                toRemove.append(text.fixed)
                            }
                        }
                    }
                    let emojies = emojis.emojies.filter { value in
                        return !toRemove.contains(value.fixed)
                    }
                    
                    return { _ in return .emoji(emojies, selected, firstWord) }
                })
            }
        }
    case let .mention(query: query, includeRecent: includeRecent):
        let normalizedQuery = query.lowercased()
        
        if let global = chatPresentationInterfaceState.peer {
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let currentQuery = currentQuery {
                switch currentQuery {
                case .mention:
                    break
                default:
                    signal = .single({ _ in return nil })
                }
            }
            
            var inlineSignal: Signal<[(Peer, Double)], NoError> = .single([])
            if includeRecent {
                inlineSignal = context.engine.peers.recentlyUsedInlineBots() |> take(1) |> map {
                    $0.map { ($0.0._asPeer(), $0.1) }
                }
            }
            
            let location = chatPresentationInterfaceState.chatLocation
            
            let members: Signal<[Peer], NoError> = searchPeerMembers(context: context, peerId: global.id, chatLocation: chatPresentationInterfaceState.chatLocation, query: query)
            
            let participants = combineLatest(inlineSignal, members |> take(1) |> mapToSignal { participants -> Signal<[Peer], NoError> in
                return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peerId: global.id, threadId: location.threadId), count: 100, tag: nil, orderStatistics: [], additionalData: []) |> take(1) |> map { view in
                    let latestIds:[PeerId] = view.0.entries.reversed().compactMap({ entry in
                        if entry.message.extendedMedia is TelegramMediaAction {
                            return nil
                        }
                        return entry.message.author?.id
                    })
                    
                    let sorted = participants.sorted{ lhs, rhs in
                        let lhsIndex = latestIds.firstIndex(where: {$0 == lhs.id})
                        let rhsIndex = latestIds.firstIndex(where: {$0 == rhs.id})
                        if let lhsIndex = lhsIndex, let rhsIndex = rhsIndex  {
                            return lhsIndex < rhsIndex
                        } else if lhsIndex == nil && rhsIndex != nil {
                            return false
                        } else if lhsIndex != nil && rhsIndex == nil {
                            return true
                        } else {
                            return lhs.displayTitle < rhs.displayTitle
                        }
                        
                    }
                    
                    return sorted
                }
                
                })
                |> map { recent, participants -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    
                    let filteredRecent = recent.filter ({ recent in
                        if recent.1 < 0.14 {
                            return false
                        }
                        if recent.0.indexName.matchesByTokens(normalizedQuery) {
                            return true
                        }
                        if let addressName = recent.0.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                            return true
                        }
                        return false
                    }).map {$0.0}
                    
                    let filteredParticipants = participants.filter ({ peer in
                        if peer.id == context.peerId {
                            return false
                        }
                        if peer.rawDisplayTitle.isEmpty {
                            return false
                        }
                        
                        if global.isChannel, let peer = peer as? TelegramUser, peer.botInfo?.inlinePlaceholder == nil {
                            return false
                        }
                        if peer.indexName.matchesByTokens(normalizedQuery) {
                            return true
                        }
                        if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                            return true
                        }
                        return peer.addressName == nil && normalizedQuery.isEmpty
                    })
                    
                    return { _ in return .mentions(filteredRecent + filteredParticipants) }
            }
            
            return (inputQuery, signal |> then(participants))
        } else {
            return (nil, .single({ _ in return nil }))
        }
    case let .command(query):
        let normalizedQuery = query.lowercased()
        
        if let peer = chatPresentationInterfaceState.peer {
            var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
            if let currentQuery = currentQuery {
                switch currentQuery {
                case .command:
                    break
                default:
                    signal = .single({ _ in return nil })
                }
            }
            let participants = context.engine.peers.peerCommands(id: peer.id)
                |> map { commands -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let filteredCommands = commands.commands.filter { command in
                        if command.command.text.hasPrefix(normalizedQuery) {
                            return true
                        }
                        return false
                    }
                    let sortedCommands = filteredCommands
                    return { _ in return .commands(sortedCommands) }
            }
            
            return (inputQuery, signal |> then(participants))
        } else {
            return (nil, .single({ _ in return nil }))
        }
    case let .contextRequest(addressName, query):
        guard let chatPeer = chatPresentationInterfaceState.peer else {
            return (nil, .single({ _ in return nil }))
        }
        
        var delayRequest = true
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ _ in return nil })
        if let currentQuery = currentQuery {
            switch currentQuery {
            case let .contextRequest(currentAddressName, currentContextQuery) where currentAddressName == addressName:
                if currentContextQuery.isEmpty != query.isEmpty {
                    delayRequest = false
                }
            default:
                delayRequest = false
                signal = .single({ _ in return nil })
            }
        }
        let contextBot = context.engine.peers.resolvePeerByName(name: addressName)
            |> mapToSignal { result -> Signal<Peer?, NoError> in
                switch result {
                case .progress:
                    return .never()
                case let .result(peer):
                    return .single(peer?._asPeer())
                }
                
            }
            |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
                if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                    let contextResults = context.engine.messages.requestChatContextResults(botId: user.id, peerId: chatPeer.id, query: query, offset: "")
                        |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                            return { _ in
                                return .contextRequestResult(user, results?.results)
                            }
                    }
                    
                    let botResult: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .single({ previousResult in
                        var passthroughPreviousResult: ChatContextResultCollection?
                        if let previousResult = previousResult {
                            if case let .contextRequestResult(previousUser, previousResults) = previousResult {
                                if previousUser.id == user.id {
                                    passthroughPreviousResult = previousResults
                                }
                            }
                        }
                        return .contextRequestResult(user, passthroughPreviousResult)
                    })
                    
                    let maybeDelayedContextResults: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>
                    if delayRequest {
                        maybeDelayedContextResults = contextResults |> `catch` { _ in return .complete() } |> delay(0.4, queue: Queue.concurrentDefaultQueue())
                    } else {
                        maybeDelayedContextResults = contextResults |> `catch` { _ in return .complete() }
                    }
                    
                    return botResult |> then(maybeDelayedContextResults)
                } else {
                    let inputQuery = inputContextQueryForChatPresentationIntefaceState(chatPresentationInterfaceState, includeContext: false)
                    
                    let result = makeInlineResult(inputQuery, chatPresentationInterfaceState: chatPresentationInterfaceState, currentQuery: nil, context: context)?.1
                    
                    if let result = result {
                        return result
                    } else {
                        return .single({ _ in return nil })
                    }
                }
        }
        
        return (inputQuery, signal |> then(contextBot))
    }
}

enum ContextQueryForSearchMentionFilter {
    case plain(includeNameless: Bool, includeInlineBots: Bool)
    case filterSelf(includeNameless: Bool, includeInlineBots: Bool)
}


func chatContextQueryForSearchMention(chatLocations: [ChatLocation], _ inputQuery: ChatPresentationInputQuery, currentQuery: ChatPresentationInputQuery?, context: AccountContext, filter: ContextQueryForSearchMentionFilter = .plain(includeNameless: true, includeInlineBots: false))  -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)?  {
    switch inputQuery {
    case let .mention(query: query, includeRecent: _):
        let normalizedQuery = query.lowercased()
        
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
        if let currentQuery = currentQuery {
            switch currentQuery {
            case .mention:
                break
            default:
                signal = .single({ _ in return nil })
            }
        }
        
        let participants: Signal<[Peer], NoError> = combineLatest(chatLocations.map { chatLocation in
            searchPeerMembers(context: context, peerId: chatLocation.peerId, chatLocation: chatLocation, query: normalizedQuery) |> take(1) |> mapToSignal { participants -> Signal<[Peer], NoError> in
                return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peerId: chatLocation.peerId, threadId: chatLocation.threadId), count: 100, tag: nil, orderStatistics: [], additionalData: []) |> take(1) |> map { view in
                    let latestIds:[PeerId] = view.0.entries.reversed().compactMap({ entry in
                        if entry.message.extendedMedia is TelegramMediaAction {
                            return nil
                        }
                        return entry.message.author?.id
                    })
                    
                    var sorted = participants.sorted{ lhs, rhs in
                        let lhsIndex = latestIds.firstIndex(where: {$0 == lhs.id})
                        let rhsIndex = latestIds.firstIndex(where: {$0 == rhs.id})
                        if let lhsIndex = lhsIndex, let rhsIndex = rhsIndex  {
                            return lhsIndex < rhsIndex
                        } else if lhsIndex == nil && rhsIndex != nil {
                            return false
                        } else if lhsIndex != nil && rhsIndex == nil {
                            return true
                        } else {
                            return lhs.displayTitle < rhs.displayTitle
                        }
                        
                    }
                    
                    if let index = sorted.firstIndex(where: {$0.id == context.peerId}) {
                        sorted.move(at: index, to: 0)
                    }
                    
                    return sorted
                }
                
            }
        }) |> map { values in
            var result:[Peer] = []
            for value in values {
                result.append(contentsOf: value)
            }
            return uniquePeers(from: result)
        }
        
        let peers = combineLatest(chatLocations.map { context.account.postbox.loadedPeerWithId($0.peerId) })
        
        let result = combineLatest(participants, peers) |> map { participants, peers -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
            
            var participants = participants
            
            for peer in peers {
                if peer.isSupergroup {
                    participants.append(peer)
                }
            }
            
            let filteredParticipants = participants.filter { peer in
                
                switch filter {
                case let .plain(includeNameless, includeInlineBots):
                    if !includeNameless, peer.addressName == nil || peer.addressName!.isEmpty {
                        return false
                    }
                    if !includeInlineBots, let peer = peer as? TelegramUser, peer.botInfo?.inlinePlaceholder != nil {
                        return false
                    }
                case let .filterSelf(includeNameless, includeInlineBots):
                    if !includeNameless, peer.addressName == nil || peer.addressName!.isEmpty {
                        return false
                    }
                    if peer.id == context.peerId {
                        return false
                    }
                    
                    if !includeInlineBots, let peer = peer as? TelegramUser, peer.botInfo?.inlinePlaceholder != nil {
                        return false
                    }
                }
                if peer.displayTitle == strings().peerDeletedUser {
                    return false
                }
                if peer.indexName.matchesByTokens(normalizedQuery) {
                    return true
                }
                if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                    return true
                }
                
                return peer.addressName == nil && normalizedQuery.isEmpty
            }
            
            return { _ in return .mentions(filteredParticipants) }
        }
        
        return (inputQuery, signal |> then(result))
    case let .emoji(query, firstWord):
        
        if !query.isEmpty {
            let signal = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, engine: context.engine, sharedContext: context.sharedContext, query: query, completeMatch: query.length < 3, checkPrediction: firstWord) |> mapToSignal { results in
                return context.engine.stickers.searchEmoji(emojiString: results)
                |> map { ($0.isFinalResult ? results : [], $0.items) }
            } |> deliverOnResourceQueue |> delay(firstWord ? 0.3 : 0, queue: .concurrentDefaultQueue())

            if firstWord {
                return (inputQuery, .single({ _ in return nil }) |> then(signal |> map { matches -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(matches.0, matches.1, firstWord) }
                }))
            } else {
                return (inputQuery, signal |> map { matches -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(matches.0, matches.1, firstWord) }
                })
            }
        } else {
            
            let animated = combineLatest(queue: resourcesQueue, context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [], namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 200) |> map {
                $0.entries.compactMap({ $0.item as? StickerPackItem}).map { $0.file }
            }, context.account.viewTracker.featuredEmojiPacks()) |> map {
                Array($0 + $1.reduce([], { current, value in
                    return current + value.topItems.map { $0.file }
                }).prefix(400))
            }

            
            if firstWord {
                return (nil, .single({ _ in return nil }))
            } else {
                return (inputQuery, combineLatest(recentUsedEmoji(postbox: context.account.postbox), animated) |> map { emojis, animated -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    
                    var toRemove: [String] = []
                    var selected: [TelegramMediaFile] = []
                    for sort in emojis.animated {
                        let file = animated.filter({ $0.fileId == sort}).first
                        if let file = file {
                            selected.append(file)
                            if let text = file.customEmojiText {
                                toRemove.append(text.fixed)
                            }
                        }
                    }
                    let emojies = emojis.emojies.filter { value in
                        return !toRemove.contains(value.fixed)
                    }
                    
                    return { _ in return .emoji(emojies, selected, firstWord) }
                })
            }
        }
    default:
        return (nil, .single({ _ in return nil }))
    }
}


private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

 func urlPreviewStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQuery: String?, disableEditingPreview: ((String)->Void)? = nil) -> Signal<(String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)?, NoError> {
    
    return Signal { subscriber in
        
        var detector = dataDetector

        
        if chatPresentationInterfaceState.state == .editing, let media = chatPresentationInterfaceState.interfaceState.editState?.message.anyMedia {
            if media is TelegramMediaFile || media is TelegramMediaImage {
                subscriber.putNext((nil, .single({ _ in return nil })))
                subscriber.putCompletion()
                detector = nil
            }
        }
        
        if let peer = chatPresentationInterfaceState.peer, peer.webUrlRestricted {
            subscriber.putNext((nil, .single({ _ in return nil })))
            subscriber.putCompletion()
            detector = nil
        }
        
        if chatPresentationInterfaceState.state == .editing, let media = chatPresentationInterfaceState.interfaceState.editState?.message.anyMedia {
            if let media = media as? TelegramMediaWebpage {
                let url: String?
                switch media.content {
                case let .Loaded(content):
                    url = content.url
                case let .Pending(content):
                    url = content.1
                }
                subscriber.putNext((url, .single({ _ in return media })))
                subscriber.putCompletion()
                detector = nil
            }
        }
        
        if let dataDetector = detector {
            
            var detectedUrl: String?

            var detectedRange: NSRange = NSMakeRange(NSNotFound, 0)
            let text = chatPresentationInterfaceState.effectiveInput.inputText.prefix(4096)
            
            var attr = chatPresentationInterfaceState.effectiveInput.attributedString()
            attr = attr.attributedSubstring(from: NSMakeRange(0, min(attr.length, 4096)))
            
            attr.enumerateAttribute(TextInputAttributes.textUrl, in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                
                if let tag = value as? TextInputTextUrlAttribute {
                    detectedUrl = tag.url
                    detectedRange = range
                }
                let s: ObjCBool = (detectedUrl != nil) ? true : false
                stop.pointee = s
                
            })
            
            let utf16 = text.utf16
            let matches = dataDetector.matches(in: text, options: [], range: NSRange(location: 0, length: utf16.count))
            if let match = matches.first {
                let urlText = (text as NSString).substring(with: match.range)
                if match.range.location < detectedRange.location {
                    detectedUrl = urlText
                }
            }
            
            if let disableEditingPreview = disableEditingPreview {
                if let editState = chatPresentationInterfaceState.interfaceState.editState {
                    if editState.message.media.isEmpty, let detectedUrl = detectedUrl  {
                        disableEditingPreview(detectedUrl)
                        subscriber.putNext((nil, .single({ _ in return nil })))
                        subscriber.putCompletion()
                        return EmptyDisposable
                    }
                }
            }
            
            if detectedUrl != currentQuery {
                if let detectedUrl = detectedUrl {
                    let link = inApp(for: detectedUrl.nsstring, context: context, peerId: nil, openInfo: { _, _, _, _ in }, hashtag: { _ in }, command: { _ in }, applyProxy: { _ in }, confirm: false)
                    
                    
                    let invoke:(inAppLink)->Void = { link in
                        switch link {
                        case let .external(detectedUrl, _), let .joinchat(detectedUrl, _, _, _), let .wallpaper(detectedUrl, _, _), let .theme(detectedUrl, _, _), let .instantView(detectedUrl, _, _):
                            subscriber.putNext((detectedUrl, webpagePreview(account: context.account, urls: [detectedUrl]) |> filter { $0 != .progress } |> map { value in
                                return { _ in return value.result }
                            }))
                        case let .followResolvedName(_, username, _, _, _, _):
                            if username.hasPrefix("_private_") {
                                subscriber.putNext((nil, .single({ _ in return nil })))
                                subscriber.putCompletion()
                            } else {
                                subscriber.putNext((detectedUrl, webpagePreview(account: context.account, urls: [detectedUrl]) |> filter { $0 != .progress } |> map { value in
                                    return { _ in return value.result }
                                }))
                            }
                        default:
                            subscriber.putNext((nil, .single({ _ in return nil })))
                            subscriber.putCompletion()
                        }
                    }
                    
                    if chatPresentationInterfaceState.chatLocation.peerId.namespace == Namespaces.Peer.SecretChat {
                        let value = FastSettings.isSecretChatWebPreviewAvailable(for: context.account.id.int64)
                        
                        if let value = value {
                            if !value {
                                subscriber.putNext((nil, .single({ _ in return nil })))
                                subscriber.putCompletion()
                                return EmptyDisposable
                            } else {
                                invoke(link)
                            }
                        } else {
                            
                            var canLoad: Bool = false
                            switch link {
                            case .external:
                                canLoad = true
                            case let .followResolvedName(_, username, _, _, _, _):
                                if !username.hasPrefix("_private_") {
                                    canLoad = true
                                }
                            default:
                                canLoad = false
                            }
                            
                            if canLoad {
                               verifyAlert_button(for: context.window, header: strings().chatSecretChatPreviewHeader, information: strings().chatSecretChatPreviewText, ok: strings().chatSecretChatPreviewOK, cancel: strings().chatSecretChatPreviewNO, successHandler: { result in
                                    FastSettings.setSecretChatWebPreviewAvailable(for: context.account.id.int64, value: true)
                                    invoke(link)
                               }, cancelHandler: {
                                    FastSettings.setSecretChatWebPreviewAvailable(for: context.account.id.int64, value: false)
                                    subscriber.putNext((nil, .single({ _ in return nil })))
                                    subscriber.putCompletion()
                               })
                            }
                            
                        }
                    } else {
                        invoke(link)
                    }
                    
                    
                } else {
                    subscriber.putNext((nil, .single({ _ in return nil })))
                    subscriber.putCompletion()
                }
            } else {
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        } else {
            subscriber.putNext((nil, .single({ _ in return nil })))
            subscriber.putCompletion()
        }
        
        return ActionDisposable {
            
        }
    }
    
    
}
