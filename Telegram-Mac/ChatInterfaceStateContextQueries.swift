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
import SyncCore
import Postbox

func contextQueryResultStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, context: AccountContext, currentQuery: ChatPresentationInputQuery?) -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)? {
    let inputQuery = chatPresentationInterfaceState.inputContext
    if inputQuery != .none {
        if inputQuery == currentQuery {
            return nil
        } else {
            return makeInlineResult(inputQuery, chatPresentationInterfaceState: chatPresentationInterfaceState, currentQuery: currentQuery, context: context)
            
        }
    } else {
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
        
        let hashtags: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = recentlyUsedHashtags(postbox: context.account.postbox) |> map { hashtags -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
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
            let stickerSettings: StickerSettings = (transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.stickerSettings) as? StickerSettings) ?? .defaultSettings
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
                return searchStickers(account: context.account, query: query, scope: scope)
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
            let signal = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, sharedContext: context.sharedContext, query: query, completeMatch: query.length < 3, checkPrediction: firstWord) |> delay(firstWord ? 0.3 : 0, queue: .concurrentDefaultQueue())

            if firstWord {
                return (inputQuery, .single({ _ in return nil }) |> then(combineLatest(signal, recentUsedEmoji(postbox: context.account.postbox)) |> map { matches, emojies -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let sorted = matches.sorted(by: { lhs, rhs in
                        let lhsIndex = emojies.emojies.firstIndex(of: lhs) ?? Int.max
                        let rhsIndex = emojies.emojies.firstIndex(of: rhs) ?? Int.max
                        return lhsIndex < rhsIndex
                    })
                    
                    return { _ in return .emoji(sorted, firstWord) }
                }))
            } else {
                return (inputQuery, combineLatest(signal, recentUsedEmoji(postbox: context.account.postbox)) |> map { matches, emojies -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let sorted = matches.sorted(by: { lhs, rhs in
                        let lhsIndex = emojies.emojies.firstIndex(of: lhs) ?? Int.max
                        let rhsIndex = emojies.emojies.firstIndex(of: rhs) ?? Int.max
                        return lhsIndex < rhsIndex
                    })
                    
                    
                    return { _ in return .emoji(sorted, firstWord) }
                })
            }
           
            
        } else {
            if firstWord {
                return (nil, .single({ _ in return nil }))
            } else {
                return (inputQuery, recentUsedEmoji(postbox: context.account.postbox) |> map { emojis -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(emojis.emojies, firstWord) }
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
                inlineSignal = recentlyUsedInlineBots(postbox: context.account.postbox) |> take(1)
            }
            
            let participants = combineLatest(inlineSignal, searchPeerMembers(context: context, peerId: global.id, query: query) |> take(1) |> mapToSignal { participants -> Signal<[Peer], NoError> in
                return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(global.id), count: 100, tagMask: nil, orderStatistics: [], additionalData: []) |> take(1) |> map { view in
                    let latestIds:[PeerId] = view.0.entries.reversed().compactMap({ entry in
                        if entry.message.media.first is TelegramMediaAction {
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
            
            let participants = peerCommands(account: context.account, id: peer.id)
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
        var signal: Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> = .complete()
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
        
        let contextBot = resolvePeerByName(account: context.account, name: addressName)
            |> mapToSignal { peerId -> Signal<Peer?, NoError> in
                if let peerId = peerId {
                    return context.account.postbox.loadedPeerWithId(peerId)
                        |> map { peer -> Peer? in
                            return peer
                        }
                        |> take(1)
                } else {
                    return .single(nil)
                }
            }
            |> mapToSignal { peer -> Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError> in
                if let user = peer as? TelegramUser, let botInfo = user.botInfo, let _ = botInfo.inlinePlaceholder {
                    let contextResults = requestChatContextResults(account: context.account, botId: user.id, peerId: chatPeer.id, query: query, offset: "")
                        |> map { results -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                            return { _ in
                                return .contextRequestResult(user, results)
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
                    
                    switch inputQuery {
                    case let .mention(query: query, includeRecent: _):
                        let normalizedQuery = query.lowercased()
                        
                        if let global = chatPresentationInterfaceState.peer {
                            return searchPeerMembers(context: context, peerId: global.id, query: normalizedQuery) |> take(1) |> mapToSignal { participants -> Signal<[Peer], NoError> in
                                return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(global.id), count: 100, tagMask: nil, orderStatistics: [], additionalData: []) |> take(1) |> map { view in
                                    let latestIds:[PeerId] = view.0.entries.reversed().compactMap({ entry in
                                        if entry.message.media.first is TelegramMediaAction {
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
                                
                            } |> map { participants -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                                    let filteredParticipants = participants.filter ({ peer in
                                        if peer.id == context.peerId {
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
                                    
                                    return { _ in return .mentions(filteredParticipants) }
                            }
                        }
                        
                    default:
                        break
                    }
                    return .single({_ in return nil})
                }
        }
        
        return (inputQuery, signal |> then(contextBot))
    }
}

enum ContextQueryForSearchMentionFilter {
    case plain(includeNameless: Bool, includeInlineBots: Bool)
    case filterSelf(includeNameless: Bool, includeInlineBots: Bool)
}


func chatContextQueryForSearchMention(peer: Peer, _ inputQuery: ChatPresentationInputQuery, currentQuery: ChatPresentationInputQuery?, context: AccountContext, filter: ContextQueryForSearchMentionFilter = .plain(includeNameless: true, includeInlineBots: false))  -> (ChatPresentationInputQuery?, Signal<(ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?, NoError>)?  {
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
        
        let participants = searchPeerMembers(context: context, peerId: peer.id, query: normalizedQuery) |> take(1) |> mapToSignal { participants -> Signal<[Peer], NoError> in
            return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peer.id), count: 100, tagMask: nil, orderStatistics: [], additionalData: []) |> take(1) |> map { view in
                let latestIds:[PeerId] = view.0.entries.reversed().compactMap({ entry in
                    if entry.message.media.first is TelegramMediaAction {
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
            
        } |> map { participants -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
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
                    if peer.displayTitle == L10n.peerDeletedUser {
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
        
        return (inputQuery, signal |> then(participants))
    case let .emoji(query, firstWord):
        if !query.isEmpty {
            let signal = context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, sharedContext: context.sharedContext, query: query, completeMatch: query.length < 3, checkPrediction: firstWord) |> delay(firstWord ? 0.3 : 0, queue: .concurrentDefaultQueue())
            
            if firstWord {
                return (inputQuery, .single({ _ in return nil }) |> then(combineLatest(signal, recentUsedEmoji(postbox: context.account.postbox)) |> map { matches, emojies -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let sorted = matches.sorted(by: { lhs, rhs in
                        let lhsIndex = emojies.emojies.firstIndex(of: lhs) ?? Int.max
                        let rhsIndex = emojies.emojies.firstIndex(of: rhs) ?? Int.max
                        return lhsIndex < rhsIndex
                    })
                    
                    return { _ in return .emoji(sorted, firstWord) }
                    }))
            } else {
                return (inputQuery, combineLatest(signal, recentUsedEmoji(postbox: context.account.postbox)) |> map { matches, emojies -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    let sorted = matches.sorted(by: { lhs, rhs in
                        let lhsIndex = emojies.emojies.firstIndex(of: lhs) ?? Int.max
                        let rhsIndex = emojies.emojies.firstIndex(of: rhs) ?? Int.max
                        return lhsIndex < rhsIndex
                    })
                    
                    
                    return { _ in return .emoji(sorted, firstWord) }
                    })
            }
            
            
        } else {
            if firstWord {
                return (nil, .single({ _ in return nil }))
            } else {
                return (inputQuery, recentUsedEmoji(postbox: context.account.postbox) |> map { emojis -> (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult? in
                    return { _ in return .emoji(emojis.emojies, firstWord) }
                    })
            }
        }
    default:
        return (nil, .single({ _ in return nil }))
    }
}


private let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType([.link]).rawValue)

func urlPreviewStateForChatInterfacePresentationState(_ chatPresentationInterfaceState: ChatPresentationInterfaceState, account: Account, currentQuery: String?) -> Signal<(String?, Signal<(TelegramMediaWebpage?) -> TelegramMediaWebpage?, NoError>)?, NoError> {
    
    return Signal { subscriber in
        
        if chatPresentationInterfaceState.state == .editing, let media = chatPresentationInterfaceState.interfaceState.editState?.message.media.first {
            if media is TelegramMediaFile || media is TelegramMediaImage {
                subscriber.putNext((nil, .single({ _ in return nil })))
                subscriber.putCompletion()
            }
        }
        
        
        if let peer = chatPresentationInterfaceState.peer, peer.webUrlRestricted {
            subscriber.putNext((nil, .single({ _ in return nil })))
            subscriber.putCompletion()
        }
        
        if let dataDetector = dataDetector {
            
            var detectedUrl: String?

            var detectedRange: NSRange = NSMakeRange(NSNotFound, 0)
            let text = chatPresentationInterfaceState.effectiveInput.inputText.prefix(4096)
            
            var attr = chatPresentationInterfaceState.effectiveInput.attributedString
            attr = attr.attributedSubstring(from: NSMakeRange(0, min(attr.length, 4096)))
            attr.enumerateAttribute(NSAttributedString.Key(rawValue: TGCustomLinkAttributeName), in: attr.range, options: NSAttributedString.EnumerationOptions(rawValue: 0), using: { (value, range, stop) in
                
                if let tag = value as? TGInputTextTag, let url = tag.attachment as? String {
                    detectedUrl = url
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
            
            if detectedUrl != currentQuery {
                if let detectedUrl = detectedUrl {
                    subscriber.putNext((detectedUrl, webpagePreview(account: account, url: detectedUrl) |> map { value in
                        return { _ in return value }
                    }))
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
