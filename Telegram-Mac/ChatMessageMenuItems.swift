//
//  ChatMessageMenuItems.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.12.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import ObjcUtils
import Translate
import InAppSettings
import InputView

final class ChatMenuItemsData {
    let chatInteraction: ChatInteraction
    let message: Message
    let accountPeer: Peer
    let resourceData: MediaResourceData?
    let chatState: ChatState
    let chatMode: ChatMode
    let isLogInteraction: Bool
    let disableSelectAbility: Bool
    let canPinMessage: Bool
    let pinnedMessage: ChatPinnedMessage?
    let peer: Peer?
    let peerId: PeerId
    let fileFinderPath: String?
    let isStickerSaved: Bool?
    let savedStickersCount: Int
    let savedGifsCount: Int
    let dialogs: [Peer]
    let recentUsedPeers: [Peer]
    let favoritePeers: [Peer]
    let updatingMessageMedia: [MessageId: ChatUpdatingMessageMedia]
    let recentMedia: [RecentMediaItem]
    let additionalData: MessageEntryAdditionalData
    let availableReactions: AvailableReactions?
    let file: TelegramMediaFile?
    let image: TelegramMediaImage?
    let textLayout: (TextViewLayout?, LinkType?)?
    let notifications: NotificationSoundList?
    let cachedData: CachedPeerData?
    let groupped:[Message]?
    let folders: [(ChatListFilter, [Peer])]
    let isMediaStory: Bool
    let isRead: Bool
    init(chatInteraction: ChatInteraction, message: Message, accountPeer: Peer, resourceData: MediaResourceData?, chatState: ChatState, chatMode: ChatMode, disableSelectAbility: Bool, isLogInteraction: Bool, canPinMessage: Bool, pinnedMessage: ChatPinnedMessage?, peer: Peer?, peerId: PeerId, fileFinderPath: String?, isStickerSaved: Bool?, dialogs: [Peer], recentUsedPeers: [Peer], favoritePeers: [Peer], recentMedia: [RecentMediaItem], updatingMessageMedia: [MessageId: ChatUpdatingMessageMedia], additionalData: MessageEntryAdditionalData, file: TelegramMediaFile?, image: TelegramMediaImage?, textLayout: (TextViewLayout?, LinkType?)?, availableReactions: AvailableReactions?, notifications: NotificationSoundList?, cachedData: CachedPeerData?, savedStickersCount: Int, savedGifsCount: Int, groupped: [Message]?, folders: [(ChatListFilter, [Peer])], isMediaStory: Bool, isRead: Bool) {
        self.chatInteraction = chatInteraction
        self.message = message
        self.accountPeer = accountPeer
        self.resourceData = resourceData
        self.chatState = chatState
        self.chatMode = chatMode
        self.disableSelectAbility = disableSelectAbility
        self.isLogInteraction = isLogInteraction
        self.canPinMessage = canPinMessage
        self.pinnedMessage = pinnedMessage
        self.peer = peer
        self.peerId = peerId
        self.fileFinderPath = fileFinderPath
        self.isStickerSaved = isStickerSaved
        self.dialogs = dialogs
        self.recentUsedPeers = recentUsedPeers
        self.favoritePeers = favoritePeers
        self.recentMedia = recentMedia
        self.updatingMessageMedia = updatingMessageMedia
        self.additionalData = additionalData
        self.file = file
        self.image = image
        self.textLayout = textLayout
        self.availableReactions = availableReactions
        self.notifications = notifications
        self.cachedData = cachedData
        self.savedStickersCount = savedStickersCount
        self.savedGifsCount = savedGifsCount
        self.groupped = groupped
        self.folders = folders
        self.isMediaStory = isMediaStory
        self.isRead = isRead
    }
}
func chatMenuItemsData(for message: Message, textLayout: (TextViewLayout?, LinkType?)?, entry: ChatHistoryEntry?, chatInteraction: ChatInteraction) -> Signal<ChatMenuItemsData, NoError> {
    
    let context = chatInteraction.context
    let account = context.account
    let chatMode = chatInteraction.presentation.chatMode
    let chatState = chatInteraction.presentation.state
    let disableSelectAbility = chatInteraction.disableSelectAbility
    let isLogInteraction = chatInteraction.isLogInteraction
    let pinnedMessage = chatInteraction.presentation.pinnedMessageId
    let peerId = chatInteraction.peerId
    let peer = chatInteraction.peer
    let canPinMessage = chatInteraction.presentation.canPinMessage && peerId.namespace != Namespaces.Peer.SecretChat
    let additionalData = entry?.additionalData ?? MessageEntryAdditionalData()
    
    let storyMedia = message.media.first as? TelegramMediaStory
    let isMediaStory = storyMedia?.storyId.peerId == context.peerId ? false : storyMedia != nil
    
    
    let incoming: Bool = message.isIncoming(context.account, false)
    let isRead: Bool
    if case let .MessageEntry(_, _, _isRead, _, _, _, _) = entry {
        isRead = _isRead || incoming
    } else if case let .groupedPhotos(entries, _) = entry, case let .MessageEntry(_, _, _isRead, _, _, _, _) = entries.first {
        isRead = _isRead || incoming
    } else {
        isRead = incoming
    }
    
    var file: TelegramMediaFile? = nil
    var image: TelegramMediaImage? = nil
    if let media = message.anyMedia as? TelegramMediaFile {
        file = media
    } else if let media = message.anyMedia as? TelegramMediaImage {
        image = media
    } else if let media = message.anyMedia as? TelegramMediaWebpage {
        switch media.content {
        case let .Loaded(content):
            file = content.file
            if file == nil {
                image = content.image
            }
        default:
            break
        }
    }
    
    let request:(ChatListFilterPredicate?)->Signal<[Peer], NoError> = { predicate in
        return account.postbox.tailChatListView(groupId: .root, filterPredicate: predicate, count: 25, summaryComponents: .init())
            |> take(1) |> map { view in
                return view.0.entries.compactMap { entry in
                    switch entry {
                    case let .MessageEntry(data):
                        return data.renderedPeer.peer
                    default:
                        return nil
                    }
                }
            }
    }

    let _dialogs: Signal<[Peer], NoError> = request(nil)
    
    let _folders: Signal<[(ChatListFilter, [Peer])], NoError> = chatListFilterPreferences(engine: context.engine) |> mapToSignal { value in
        return combineLatest(value.list.filter { !$0.isAllChats }.map { item in
            return request(chatListFilterPredicate(for: item)) |> map {
                (item, $0)
            }
        })
    }
    
    
    let _recentUsedPeers: Signal<[Peer], NoError> = context.recentlyUserPeerIds |> mapToSignal { ids in
        return account.postbox.transaction { transaction in
            let peers = ids.compactMap { transaction.getPeer($0) }
            return Array(peers.map { $0 })
        }
    }
    let _favoritePeers: Signal<[Peer], NoError> = context.engine.peers.recentPeers() |> map { recent in
        switch recent {
        case .disabled:
            return []
        case let .peers(peers):
            return Array(peers.map { $0 })
        }
    }
    
    let _accountPeer = account.postbox.loadedPeerWithId(context.peerId) |> deliverOnMainQueue
    
    var _resourceData: Signal<MediaResourceData?, NoError> = .single(nil)
    var _fileFinderPath: Signal<String?, NoError> = .single(nil)
    var _getIsStickerSaved: Signal<Bool?, NoError> = .single(nil)
    var _recentMedia: Signal<[RecentMediaItem], NoError> = .single([])
    
    let _savedStickersCount: Signal<Int, NoError> = account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 100) |> take(1) |> map {
        $0.orderedItemListsViews[0].items.count
    }
    
    let _savedGifsCount: Signal<Int, NoError> = context.account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]) |> take(1) |> map {
        return ($0.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView).items.count
    }

    
    let _updatingMessageMedia = account.pendingUpdateMessageManager.updatingMessageMedia
        
    if let media = file {
        _resourceData = account.postbox.mediaBox.resourceData(media.resource) |> map(Optional.init)
        
        if media.isSticker {
            _getIsStickerSaved = account.postbox.transaction { transaction -> Bool? in
                return getIsStickerSaved(transaction: transaction, fileId: media.fileId)
            }
        }
        
        if media.isAnimated && media.isVideo {
            _recentMedia = account.postbox.transaction { transaction -> [RecentMediaItem] in
                transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudRecentGifs).compactMap { $0.contents.get(RecentMediaItem.self) }
            }
        }
        
        _fileFinderPath = fileFinderPath(media, account.postbox)
        
    } else if let media = image {
        if let resource = media.representations.last?.resource {
            _resourceData = account.postbox.mediaBox.resourceData(resource) |> map(Optional.init)
        }
    }
    
    let _groupped: Signal<[Message]?, NoError> = context.account.postbox.transaction { transaction in
        return transaction.getMessageGroup(message.id)
    }
    
    let cachedData = getCachedDataView(peerId: peerId, postbox: context.account.postbox) |> take(1)
    
    let combined = combineLatest(queue: .mainQueue(), _dialogs, _recentUsedPeers, _favoritePeers, _accountPeer, _resourceData, _fileFinderPath, _getIsStickerSaved, _recentMedia, _updatingMessageMedia, context.reactions.stateValue, context.engine.peers.notificationSoundList(), cachedData, _savedStickersCount, _savedGifsCount, _groupped, _folders)
    |> take(1)
    
    
    
    return combined |> map { dialogs, recentUsedPeers, favoritePeers, accountPeer, resourceData, fileFinderPath, isStickerSaved, recentMedia, updatingMessageMedia, availableReactions, notifications, cachedData, savedStickersCount, savedGifsCount, groupped, folders in
        return .init(chatInteraction: chatInteraction, message: message, accountPeer: accountPeer, resourceData: resourceData, chatState: chatState, chatMode: chatMode, disableSelectAbility: disableSelectAbility, isLogInteraction: isLogInteraction, canPinMessage: canPinMessage, pinnedMessage: pinnedMessage, peer: peer, peerId: peerId, fileFinderPath: fileFinderPath, isStickerSaved: isStickerSaved, dialogs: dialogs, recentUsedPeers: recentUsedPeers, favoritePeers: favoritePeers, recentMedia: recentMedia, updatingMessageMedia: updatingMessageMedia, additionalData: additionalData, file: file, image: image, textLayout: textLayout, availableReactions: availableReactions, notifications: notifications, cachedData: cachedData, savedStickersCount: savedStickersCount, savedGifsCount: savedGifsCount, groupped: groupped, folders: folders, isMediaStory: isMediaStory, isRead: isRead)
    }
}


func chatMenuItems(for message: Message, entry: ChatHistoryEntry?, textLayout: (TextViewLayout?, LinkType?)?, chatInteraction: ChatInteraction, useGroupIfNeeded: Bool = true) -> Signal<[ContextMenuItem], NoError> {
    
    if chatInteraction.isLogInteraction {
        let context = chatInteraction.context
        if let adminLog = entry?.additionalData.eventLog {
            let config = AntiSpamBotConfiguration.with(appConfiguration: context.appConfiguration)
            if adminLog.peerId == config.antiSpamBotId {
                return.single([ContextMenuItem(strings().chatContextReportFalsePositive, handler: {
                    
                    _ = context.engine.peers.reportAntiSpamFalsePositive(peerId: message.id.peerId, messageId: message.id).start()
                    
                    showModalText(for: context.window, text: strings().chatContextReportFalsePositiveThanks)
                    
                }, itemImage: MenuAnimation.menu_report_false_positive.value)])
            }
        }
        return .single([])
    } else if chatInteraction.disableSelectAbility {
        return .single([])
    }
    
    return chatMenuItemsData(for: message, textLayout: textLayout, entry: entry, chatInteraction: chatInteraction) |> map { data in
        
        let peer = data.message.peers[data.message.id.peerId]
        let isNotFailed = !message.flags.contains(.Failed) && !message.flags.contains(.Unsent) && !data.message.flags.contains(.Sending)
        let protected = data.message.containsSecretMedia || data.message.isCopyProtected()
        let peerId = data.peerId
        let messageId = data.message.id
        let appConfiguration = data.chatInteraction.context.appConfiguration
        let context = data.chatInteraction.context
        let account = context.account
        let mode = chatInteraction.mode
        var isService = data.message.extendedMedia is TelegramMediaAction || mode.isSavedMode
        
        if !isService, let story = data.message.media.first as? TelegramMediaStory {
            isService = story.isMention
        }
        
        var items:[ContextMenuItem] = []
        var zeroBlock:[ContextMenuItem] = []
        var firstBlock:[ContextMenuItem] = []
        var secondBlock:[ContextMenuItem] = []
        var add_secondBlock:[ContextMenuItem] = []
        var thirdBlock:[ContextMenuItem] = []
        var fourthBlock:[ContextMenuItem] = []
        var fifthBlock:[ContextMenuItem] = []
        var sixBlock:[ContextMenuItem] = []
        
        
        if let layout = textLayout?.0, !layout.selectedRange.range.isEmpty, mode != .pinned, mode != .scheduled, !mode.isSavedMode {
            firstBlock.append(ContextMenuItem(strings().chatMessageContextQuote, handler: {
                
                let quote_length_max = context.appConfiguration.getGeneralValue("quote_length_max", orElse: 1024)
                if layout.selectedString.length > quote_length_max {
                    alert(for: context.window, info: strings().chatMessageContextQuoteLimitExceed)
                } else {
                    let attributed = enititesAttributedStringForText(layout.selectedString).trimmed
                    let entities = messageTextEntitiesInRange(entities: ChatTextInputState(attributedText: attributed, selectionRange: 0..<0).messageTextEntities(), range: attributed.range, onlyQuoteable: true)
                    
                    let quote = EngineMessageReplyQuote(text: attributed.string, offset: nil, entities: entities, media: message.media.first)
                    chatInteraction.setupReplyMessage(message, .init(messageId: message.id, quote: quote))

                }
                
            }, itemImage: MenuAnimation.menu_quote.value))
        }
        
        
        if let adAttribute = data.message.adAttribute {
            
            if adAttribute.sponsorInfo != nil || adAttribute.additionalInfo != nil {
                
                
                let submenu = ContextMenu()
                let subItem = ContextMenuItem(strings().chatMessageSponsoredAdvertiser, itemImage: MenuAnimation.menu_channel.value)
                
                if let text = adAttribute.sponsorInfo {
                    submenu.addItem(ContextMenuItem(text, handler: {
                        copyToClipboard(text)
                        showModalText(for: context.window, text: strings().contextAlertCopied)
                    }, removeTail: false))
                }
                if let text = adAttribute.additionalInfo {
                    if !submenu.items.isEmpty {
                        submenu.addItem(ContextSeparatorItem())
                    }
                    submenu.addItem(ContextMenuItem(text, handler: {
                        copyToClipboard(text)
                        showModalText(for: context.window, text: strings().contextAlertCopied)
                    }, removeTail: false))
                }
                
             
                
                subItem.submenu = submenu
                
                items.append(subItem)
                
                items.append(ContextSeparatorItem())

            }
            
            if adAttribute.canReport {
                
                items.append(ContextMenuItem(strings().chatMessageSponsoredAbout, handler: {
                    showModal(with: FragmentAdsInfoController(context: context), for: context.window)
                }, itemImage: MenuAnimation.menu_show_info.value))
                
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().chatMessageSponsoredReport, handler: {
                    _ = showModalProgress(signal: context.engine.messages.reportAdMessage(peerId: data.peerId, opaqueId: adAttribute.opaqueId, option: nil), for: context.window).startStandalone(next: { result in
                        switch result {
                        case .reported:
                            showModalText(for: context.window, text: strings().chatMessageSponsoredReportAready)
                        case .adsHidden:
                            break
                        case let .options(title, options):
                            showComplicatedReport(context: context, title: title, info: strings().chatMessageSponsoredReportLearnMore, data: .init(list: options.map { .init(string: $0.text, id: $0.option) }, title: strings().chatMessageSponsoredReportOptionTitle), report: { report in
                                return context.engine.messages.reportAdMessage(peerId: data.peerId, opaqueId: adAttribute.opaqueId, option: report.id) |> `catch` { error in
                                    return .single(.reported)
                                } |> deliverOnMainQueue |> map { result in
                                    switch result {
                                    case let .options(_, options):
                                        return .init(list: options.map { .init(string: $0.text, id: $0.option) }, title: report.string)
                                    case .reported:
                                        showModalText(for: context.window, text: strings().chatMessageSponsoredReportSuccess)
                                        chatInteraction.removeAd(adAttribute.opaqueId)
                                        return nil
                                    case .adsHidden:
                                        return nil
                                    }
                                }
                                
                            })
                        }
                    }, error: { error in
                        switch error {
                        case .premiumRequired:
                            showModal(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
                        case .generic:
                            break
                        }
                    })
                }, itemImage: MenuAnimation.menu_restrict.value))
            } else {
                items.append(ContextMenuItem(strings().chatMessageSponsoredWhat, handler: {
                    let link = "https://promote.telegram.org"
                    verifyAlert_button(for: context.window, information: strings().chatMessageAdText(link), cancel: "", option: strings().chatMessageAdReadMore, successHandler: { result in
                        switch result {
                        case .thrid:
                         let link = inAppLink.external(link: link, false)
                         execute(inapp: link)
                        default:
                            break
                        }
                    })
                }, itemImage: MenuAnimation.menu_report.value))

            }
            
            
            if !context.premiumIsBlocked {
                items.append(ContextMenuItem(strings().chatContextHideAd, handler: {
                    showModal(with: PremiumBoardingController(context: context, source: .no_ads, openFeatures: true), for: context.window)
                }, itemImage: MenuAnimation.menu_clear_history.value))
            }
            
             
            
            
            return items
        }
        
        if data.disableSelectAbility, data.isLogInteraction || data.chatState == .selecting {
            return []
        }
        
        if messageId.peerId == repliesPeerId, let author = data.message.chatPeer(context.peerId), author.id != context.peerId, !isService {
            let text = author.isUser ? strings().chatContextBlockUser : strings().chatContextBlockGroup
            firstBlock.append(ContextMenuItem(text, handler: {
                let header = author.isUser ? strings().chatContextBlockUserHeader : strings().chatContextBlockGroupHeader
                let info = author.isUser ? strings().chatContextBlockUserInfo(author.displayTitle) : strings().chatContextBlockGroupInfo(author.displayTitle)
                let third = author.isUser ? strings().chatContextBlockUserThird : strings().chatContextBlockGroupThird
                let ok = author.isUser ? strings().chatContextBlockUserOK : strings().chatContextBlockGroupOK
                let cancel = author.isUser ? strings().chatContextBlockUserCancel : strings().chatContextBlockGroupCancel

                verifyAlert(for: context.window, header: header, information: info, ok: ok, cancel: cancel, option: third, optionIsSelected: true, successHandler: { result in
                    switch result {
                    case .thrid:
                        let block: Signal<Never, NoError> = context.blockedPeersContext.add(peerId: author.id) |> `catch` { _ in return .complete() }
                        _ = showModalProgress(signal: combineLatest(context.engine.peers.reportPeerMessages(messageIds: [messageId], reason: .spam, message: ""), block), for: context.window).start()
                    case .basic:
                        _ = showModalProgress(signal: context.blockedPeersContext.add(peerId: author.id), for: context.window).start()
                    }
                })
            }, itemImage: MenuAnimation.menu_restrict.value))
        }

        if data.message.isScheduledMessage, let peer = data.peer, !isService {
            firstBlock.append(ContextMenuItem(strings().chatContextScheduledSendNow, handler: {
                _ = context.engine.messages.sendScheduledMessageNowInteractively(messageId: messageId).start()
            }, itemImage: MenuAnimation.menu_send_now.value))
            firstBlock.append(ContextMenuItem(strings().chatContextScheduledReschedule, handler: {
                showModal(with: DateSelectorModalController(context: context, defaultDate: Date(timeIntervalSince1970: TimeInterval(message.timestamp)), mode: .schedule(peer.id), selectedAt: { date in
                    _ = showModalProgress(signal: context.engine.messages.requestEditMessage(messageId: messageId, text: data.message.text, media: .keep, entities: data.message.textEntities, inlineStickers: data.message.associatedMedia, scheduleTime: Int32(min(date.timeIntervalSince1970, Double(scheduleWhenOnlineTimestamp)))), for: context.window).start()
               }), for: context.window)
            }, itemImage: MenuAnimation.menu_schedule_message.value))
        }
        
        
        if canReplyMessage(data.message, peerId: data.peerId, mode: data.chatMode, threadData: chatInteraction.presentation.threadInfo)  {
            firstBlock.append(ContextMenuItem(strings().messageContextReply1, handler: {
                data.chatInteraction.setupReplyMessage(data.message, .init(messageId: data.message.id, quote: nil))
            }, itemImage: MenuAnimation.menu_reply.value, keyEquivalent: .cmdr))
        }
        
        
        if let poll = data.message.anyMedia as? TelegramMediaPoll {
            if !poll.isClosed && isNotFailed {
                if let _ = poll.results.voters?.first(where: {$0.selected}), poll.kind != .quiz {
                    let isLoading = data.additionalData.pollStateData.isLoading
                    add_secondBlock.append(ContextMenuItem(strings().chatPollUnvote, handler: {
                        if !isLoading, isNotFailed {
                            data.chatInteraction.vote(messageId, [], true)
                        }
                    }, itemImage: MenuAnimation.menu_retract_vote.value))
                }
                if data.message.forwardInfo == nil {
                    let canClose: Bool = canEditMessage(data.message, chatInteraction: data.chatInteraction, context: context, ignorePoll: true)
                    if canClose {
                        add_secondBlock.append(ContextMenuItem(poll.kind == .quiz ? strings().chatQuizStop : strings().chatPollStop, handler: { [weak chatInteraction] in
                            verifyAlert_button(for: context.window, header: poll.kind == .quiz ? strings().chatQuizStopConfirmHeader : strings().chatPollStopConfirmHeader, information: poll.kind == .quiz ? strings().chatQuizStopConfirmText : strings().chatPollStopConfirmText, ok: strings().alertConfirmStop, successHandler: { [weak chatInteraction] _ in
                                chatInteraction?.closePoll(messageId)
                            })
                        }, itemImage: MenuAnimation.menu_stop_poll.value))
                    }
                }
            }
            
        }
        
        if data.chatMode.threadId == nil, let peer = peer, peer.isSupergroup {
            if let attr = data.message.threadAttr, attr.count > 0, mode != .scheduled {
                var messageId: MessageId = message.id
                var modeIsReplies = true
                if let source = message.sourceReference {
                    messageId = source.messageId
                    if let peer = message.peers[source.messageId.peerId] {
                        if peer.isChannel {
                            modeIsReplies = false
                        }
                    }
                }
                let text = modeIsReplies ? strings().messageContextViewRepliesCountable(Int(attr.count)) : strings().messageContextViewCommentsCountable(Int(attr.count))
                secondBlock.append(ContextMenuItem(text, handler: {
                    data.chatInteraction.openReplyThread(messageId, !modeIsReplies, true, modeIsReplies ? .replies(origin: messageId) : .comments(origin: messageId))
                }, itemImage: MenuAnimation.menu_view_replies.value))
            }
        }
        
        var muteTranslate = false
        if let translate = entry?.additionalData.translate {
            switch translate {
            case .loading:
                break
            case let .complete(toLang):
                if let _ = message.translationAttribute(toLang: toLang) {
                    muteTranslate = true
                }
            }
        }
        
    //    if !data.message.isCopyProtected() {
        if let textLayout = data.textLayout?.0, mode.customChatContents == nil {
            
            if !textLayout.selectedRange.hasSelectText {
                let text = message.text
                let language = Translate.detectLanguage(for: text)
                
                let toLang = context.sharedContext.baseSettings.doNotTranslate.union([appAppearance.languageCode])
                if language == nil || !toLang.contains(language!), !muteTranslate, !isService {
                    thirdBlock.append(ContextMenuItem(strings().chatContextTranslate, handler: {
                        showModal(with: TranslateModalController(context: context, from: language, toLang: appAppearance.languageCode, text: text), for: context.window)
                        data.chatInteraction.enableTranslatePaywall()
                    }, itemImage: MenuAnimation.menu_translate.value))
                }
                if !data.message.isCopyProtected() {
                    thirdBlock.append(ContextMenuItem(strings().chatContextCopyText, handler: { [weak textLayout] in
                        if let textLayout = textLayout {
                            if !globalLinkExecutor.copyAttributedString(textLayout.attributedString) {
                                copyToClipboard(textLayout.attributedString.string)
                            }
                        }
                    }, itemImage: MenuAnimation.menu_copy.value))
                }
            } else {
                let text: String
                if let linkType = data.textLayout?.1, !data.message.isCopyProtected() {
                    text = copyContextText(from: linkType)
                    thirdBlock.append(ContextMenuItem(text, handler: { [weak textLayout] in
                        if let textLayout = textLayout {
                            let attr = textLayout.attributedString.mutableCopy() as! NSMutableAttributedString
                            attr.enumerateAttributes(in: attr.range, options: [], using: { data, range, _ in
                                if let value = data[TextInputAttributes.embedded] as? InlineStickerItem {
                                    switch value.source {
                                    case let .attribute(value):
                                        attr.replaceCharacters(in: range, with: value.emoji)
                                    default:
                                        break
                                    }
                                }
                            })
                            var effectiveRange = textLayout.selectedRange.range
                            let selectedText = attr.attributedSubstring(from: textLayout.selectedRange.range)
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.declareTypes([.string], owner: textLayout)
                            let attribute = attr.attribute(NSAttributedString.Key.link, at: textLayout.selectedRange.range.location, effectiveRange: &effectiveRange)
                            if let attribute = attribute as? inAppLink {
                                pb.setString(attribute.link.isEmpty ? selectedText.string : attribute.link, forType: .string)
                            } else {
                                pb.setString(selectedText.string, forType: .string)
                            }
                        }
                        
                    }, itemImage: MenuAnimation.menu_copy.value))
                } else if !data.message.isCopyProtected() {
                    let attr = textLayout.attributedString.mutableCopy() as! NSMutableAttributedString
                    attr.enumerateAttributes(in: attr.range, options: [], using: { data, range, _ in
                        if let value = data[TextInputAttributes.embedded] as? InlineStickerItem {
                            switch value.source {
                            case let .attribute(value):
                                attr.replaceCharacters(in: range, with: value.emoji)
                            default:
                                break
                            }
                        }
                    })
                    if let range = attr.range.intersection(textLayout.selectedRange.range) {
                        let selectedText = attr.attributedSubstring(from: range)
                        let text = selectedText.string
                        let language = Translate.detectLanguage(for: text)
                        let toLang = context.sharedContext.baseSettings.doNotTranslate.union([appAppearance.languageCode])
                        if language == nil || !toLang.contains(language!), !muteTranslate, !isService {
                            thirdBlock.append(ContextMenuItem(strings().chatContextTranslate, handler: {
                                showModal(with: TranslateModalController(context: context, from: language, toLang: appAppearance.languageCode, text: text), for: context.window)
                                data.chatInteraction.enableTranslatePaywall()
                            }, itemImage: MenuAnimation.menu_translate.value))
                        }
                        thirdBlock.append(ContextMenuItem(strings().chatCopySelectedText, handler: { [weak textLayout] in
                            if let textLayout = textLayout {
                                let attr = textLayout.attributedString
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.declareTypes([.string], owner: textLayout)
                                var effectiveRange = textLayout.selectedRange.range
                                let selectedText = attr.attributedSubstring(from: textLayout.selectedRange.range)
                                let isCopied = globalLinkExecutor.copyAttributedString(selectedText)
                                if !isCopied {
                                    let attribute = attr.attribute(NSAttributedString.Key.link, at: textLayout.selectedRange.range.location, effectiveRange: &effectiveRange)
                                    if let attribute = attribute as? inAppLink {
                                        pb.setString(attribute.link.isEmpty ? selectedText.string : attribute.link, forType: .string)
                                    } else {
                                        pb.setString(selectedText.string, forType: .string)
                                    }
                                }
                            }
                        }, itemImage: MenuAnimation.menu_copy.value))

                    }
                }
            }
        }
        if let state = data.message.audioTranscription {
            if !state.text.isEmpty && !state.isPending {
                let text = state.text
                let language = Translate.detectLanguage(for: text)
                let toLang = context.sharedContext.baseSettings.doNotTranslate.union([appAppearance.languageCode])
                if language == nil || !toLang.contains(language!), !isService {
                    thirdBlock.append(ContextMenuItem(strings().chatContextTranslate, handler: {
                        showModal(with: TranslateModalController(context: context, from: language, toLang: appAppearance.languageCode, text: text), for: context.window)
                        data.chatInteraction.enableTranslatePaywall()
                    }, itemImage: MenuAnimation.menu_translate.value))
                }
            }
        }
        
        if let peer = peer as? TelegramChannel, !isService {
            if isNotFailed, !message.isScheduledMessage {
                thirdBlock.append(ContextMenuItem(strings().messageContextCopyMessageLink1, handler: {
                    _ = showModalProgress(signal: context.engine.messages.exportMessageLink(peerId: peer.id, messageId: messageId, isThread: data.chatMode.threadId != nil), for: context.window).start(next: { link in
                        if let link = link {
                            copyToClipboard(link)
                        }
                        showSuccess(window: context.window)
                    })
                }, itemImage: MenuAnimation.menu_copy_link.value))
            }
        }
        
        if canEditMessage(data.message, chatInteraction: data.chatInteraction, context: context), !isService {
            let edit = ContextMenuItem(strings().messageContextEdit, handler: {
                data.chatInteraction.beginEditingMessage(data.message)
            }, itemImage: MenuAnimation.menu_edit.value, keyEquivalent: .cmde)
            
            if let groupped = data.groupped, groupped.count > 1, let media = message.media.first as? TelegramMediaFile {
                if !media.isVideo {
                    let menu = ContextMenu()
                    for message in groupped {
                        if let fileName = message.file?.fileName {
                            menu.addItem(ContextMenuItem(fileName, handler: {
                                data.chatInteraction.beginEditingMessage(message)
                            }))
                        }
                    }
                    edit.submenu = menu
                }
            }
            
            secondBlock.append(edit)
            
            
        }
        
        if !data.message.isScheduledMessage, let peer = peer, !peer.isDeleted, isNotFailed, data.peerId == data.message.id.peerId, !isService, mode.customChatContents == nil {
            
            let needUnpin = data.pinnedMessage?.others.contains(data.message.id) == true
            let pinAndOld: Bool
            if let pinnedMessage = data.pinnedMessage, let last = pinnedMessage.others.last {
                pinAndOld = last > data.message.id
            } else {
                pinAndOld = false
            }
            let pinText = data.message.tags.contains(.pinned) ? strings().messageContextUnpin : strings().messageContextPin
            
            let pinImage = data.message.tags.contains(.pinned) ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value
            
            let canSendMessage = peer.canSendMessage(data.chatMode.isThreadMode || data.chatMode.isTopicMode, media: data.message.media.first, threadData: data.chatInteraction.presentation.threadInfo)

            if let peer = peer as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)), canSendMessage {
                if isNotFailed {
                    if !data.chatMode.isThreadMode, (needUnpin || data.chatMode != .pinned) {
                        secondBlock.append(ContextMenuItem(pinText, handler: {
                            if peer.isSupergroup, !needUnpin {
                                let info = pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1
                                
                                verifyAlert(for: context.window, information: info, ok:  strings().messageContextPin, option: pinAndOld ? nil : strings().messageContextConfirmNotifyPin, successHandler: { result in
                                    data.chatInteraction.updatePinned(data.message.id, needUnpin, result != .thrid, false)
                                })
                            } else {
                                data.chatInteraction.updatePinned(data.message.id, needUnpin, true, false)
                            }
                        }, itemImage: pinImage))
                    }
                }
            } else if data.message.id.peerId == context.peerId {
                secondBlock.append(ContextMenuItem(pinText, handler: {
                    data.chatInteraction.updatePinned(data.message.id, needUnpin, true, false)
                }, itemImage: pinImage))
            } else if let peer = peer as? TelegramGroup, peer.canPinMessage, (needUnpin || data.chatMode != .pinned) {
                secondBlock.append(ContextMenuItem(pinText, handler: {
                    if !needUnpin {
                        verifyAlert(for: context.window, information: pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1, ok: strings().messageContextPin, option: pinAndOld ? nil : strings().messageContextConfirmNotifyPin, successHandler: { result in
                            data.chatInteraction.updatePinned(data.message.id, needUnpin, result == .thrid, false)
                        })
                    } else {
                        data.chatInteraction.updatePinned(data.message.id, needUnpin, false, false)
                    }
                }, itemImage: pinImage))
            } else if data.canPinMessage, let peer = data.peer, (needUnpin || data.chatMode != .pinned) {
                secondBlock.append(ContextMenuItem(pinText, handler: {
                    if !needUnpin {
                        verifyAlert(for: context.window, information: pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1, ok: strings().messageContextPin, option: strings().chatConfirmPinFor(peer.displayTitle), optionIsSelected: false, successHandler: { result in
                            data.chatInteraction.updatePinned(data.message.id, needUnpin, false, result != .thrid)
                        })
                    } else {
                        data.chatInteraction.updatePinned(data.message.id, needUnpin, false, false)
                    }
                }, itemImage: pinImage))
            }
        }
        
        if canForwardMessage(data.message, chatInteraction: data.chatInteraction), !isService {
            let msgs = useGroupIfNeeded ? (data.groupped ?? [data.message]) : [data.message]
            let forwardItem = ContextMenuItem(strings().messageContextForward, handler: {
                data.chatInteraction.forwardMessages(msgs)
            }, itemImage: MenuAnimation.menu_forward.value)
            let forwardMenu = ContextMenu()
            
            
            let forwardObject = ForwardMessagesObject(context, messages: [data.message], album: useGroupIfNeeded)
            
            let recent = data.recentUsedPeers.filter {
                $0.id != context.peerId && $0.canSendMessage(media: message.media.first) && !$0.isDeleted
            }.prefix(5)
            
            let favorite = data.favoritePeers.filter {
                !recent.map { $0.id }.contains($0.id)
                && $0.id != context.peerId
                && $0.canSendMessage(media: message.media.first)
                && !$0.isDeleted
            }.prefix(5)
            
            let dialogs = data.dialogs.reversed().filter {
                !(recent + favorite).map { $0.id }.contains($0.id)
                    && $0.id != context.peerId
                    && $0.canSendMessage(media: message.media.first)
                    && !$0.isDeleted
            }.prefix(5)
            
            var items:[ContextMenuItem] = []
            
            
            func makeItem(_ peer: Peer) -> ContextMenuItem {
                let title = peer.id == context.peerId ? strings().peerSavedMessages : peer.displayTitle.prefixWithDots(20)
                let item = ReactionPeerMenu(title: title, handler: {
                    _ = forwardObject.perform(to: [peer.id], threadId: nil).start()
                }, peer: peer, context: context, reaction: nil, message: message, destination: .forward(callback: { threadId in
                    _ = forwardObject.perform(to: [peer.id], threadId: makeThreadIdMessageId(peerId: peer.id, threadId: threadId)).start()
                }))

                ContextMenuItem.makeItemAvatar(item, account: context.account, peer: peer, source: .peer(peer, peer.smallProfileImage, peer.nameColor, peer.displayLetters, nil))
                
                return item
            }
            
            
            items.append(makeItem(data.accountPeer))
            if !recent.isEmpty || !dialogs.isEmpty || !favorite.isEmpty {
                items.append(ContextSeparatorItem())
            }
            for peer in recent {
                if peer.id.namespace != Namespaces.Peer.SecretChat {
                    items.append(makeItem(peer))
                }
            }
            if !recent.isEmpty {
                items.append(ContextSeparatorItem())
            }
            for peer in favorite {
                items.append(makeItem(peer))
            }
            if (!favorite.isEmpty || !recent.isEmpty) && !dialogs.isEmpty {
                items.append(ContextSeparatorItem())
            }
            for peer in dialogs {
                if peer.id.namespace != Namespaces.Peer.SecretChat {
                    items.append(makeItem(peer))
                }
            }
            if !items.isEmpty {
                
                if !data.folders.isEmpty {
                    items.append(ContextSeparatorItem())
                    let folders = ContextMenuItem(strings().chatContextFolders, itemImage: MenuAnimation.menu_folder.value)
                    
                    let folderSubmenu = ContextMenu()
                    for folder in data.folders {
                        let item = ContextMenuItem(folder.0.title, itemImage: FolderIcon(folder.0).emoticon.drawable.value)
                        let submenu = ContextMenu()
                        
                        for peer in folder.1 {
                            submenu.addItem(makeItem(peer))
                        }
                        item.submenu = submenu
                        folderSubmenu.addItem(item)
                    }
                    folders.submenu = folderSubmenu
                    items.append(folders)
                }
                
                let more = ContextMenuItem(strings().chatContextForwardMore, handler: { [unowned chatInteraction] in
                    chatInteraction.forwardMessages([message])
                }, itemImage: MenuAnimation.menu_more.value)
                items.append(more)
            }
            for item in items {
                forwardMenu.addItem(item)
            }
           
            forwardItem.submenu = forwardMenu
            secondBlock.append(forwardItem)
        }
        /*
         else if data.message.id.peerId.namespace == Namespaces.Peer.SecretChat, !data.message.containsSecretMedia {
             secondBlock.append(ContextMenuItem(strings().messageContextShare, handler: {
                 if let data = data {
                     data.chatInteraction.forwardMessages([data.message.id])
                 }
             }))
         }
         */

        
        
        if data.chatMode.threadId != data.message.id, !isService {
            secondBlock.append(ContextMenuItem(strings().messageContextSelect, handler: {
                data.chatInteraction.withToggledSelectedMessage({
                    $0.withToggledSelectedMessage(data.message.id)
                })
            }, itemImage: MenuAnimation.menu_select_messages.value))
        }
        
        if let channel = data.message.peers[message.id.peerId] as? TelegramChannel, channel.isChannel {
            var views: Int = 0
            for attribute in message.attributes {
                if let attribute = attribute as? ViewCountMessageAttribute {
                    views = attribute.count
                }
            }
            
            if let cachedData = data.cachedData as? CachedChannelData, views >= 100 {
                if cachedData.flags.contains(.canViewStats) {
                    thirdBlock.append(ContextMenuItem.init(strings().chatContextViewStatistics, handler: {
                        context.bindings.rootNavigation().push(MessageStatsController(context, subject: .messageId(messageId)))
                    }, itemImage: MenuAnimation.menu_statistics.value))
                }
            }
        }
        
     
        
        if let resourceData = data.resourceData, !protected {
            if let file = data.file {
                if file.isVideo && file.isAnimated {
                    if data.recentMedia.contains(where: {$0.media.id == file.fileId}) {
                        thirdBlock.append(ContextMenuItem(strings().messageContextRemoveGif, handler: {
                            showModalText(for: context.window, text: strings().chatContextGifRemoved)
                            _ = removeSavedGif(postbox: account.postbox, mediaId: file.fileId).start()
                        }, itemImage: MenuAnimation.menu_remove_gif.value))
                    } else {
                        thirdBlock.append(ContextMenuItem(strings().messageContextSaveGif, handler: {
                            
                            let limit = context.isPremium ? context.premiumLimits.saved_gifs_limit_premium : context.premiumLimits.saved_gifs_limit_default
                            if limit <= data.savedGifsCount, !context.isPremium, !context.premiumIsBlocked {
                                showModalText(for: context.window, text: strings().chatContextFavoriteGifsLimitInfo("\(context.premiumLimits.saved_gifs_limit_premium)"), title: strings().chatContextFavoriteGifsLimitTitle, callback: { value in
                                    showPremiumLimit(context: context, type: .savedGifs)
                                })
                            } else {
                                showModalText(for: context.window, text: strings().chatContextGifAdded)
                            }
                            _ = addSavedGif(postbox: account.postbox, fileReference: FileMediaReference.message(message: MessageReference(data.message), media: file)).start()
                        }, itemImage: MenuAnimation.menu_add_gif.value))
                    }
                }
                if file.isSticker, let saved = data.isStickerSaved {
                    
                    if let reference = file.stickerReference {
                        thirdBlock.append(ContextMenuItem(strings().contextViewStickerSet, handler: {
                            showModal(with: StickerPackPreviewModalController(context, peerId: peerId, references: [.stickers(reference)]), for: context.window)
                        }, itemImage: MenuAnimation.menu_view_sticker_set.value))
                    }
                    
                    let image = saved ? MenuAnimation.menu_remove_from_favorites.value : MenuAnimation.menu_add_to_favorites.value
                    thirdBlock.append(ContextMenuItem(!saved ? strings().chatContextAddFavoriteSticker : strings().chatContextRemoveFavoriteSticker, handler: {
                        if !saved {
                            let limit = context.isPremium ? context.premiumLimits.stickers_faved_limit_premium : context.premiumLimits.stickers_faved_limit_default
                            if limit >= data.savedStickersCount, !context.isPremium, !context.premiumIsBlocked {
                                showModalText(for: context.window, text: strings().chatContextFavoriteStickersLimitInfo("\(context.premiumLimits.stickers_faved_limit_premium)"), title: strings().chatContextFavoriteStickersLimitTitle, callback: { value in
                                    showPremiumLimit(context: context, type: .faveStickers)
                                })
                            } else {
                                showModalText(for: context.window, text: strings().chatContextStickerAddedToFavorites)
                            }
                            _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                        } else {
                            showModalText(for: context.window, text: strings().chatContextStickerRemovedFromFavorites)
                            _ = removeSavedSticker(postbox: account.postbox, mediaId: file.fileId).start()
                        }
                    }, itemImage: image))
                }
                
                if resourceData.complete {
                    if let file = data.file, file.isMusic || file.isVoice, let list = data.notifications {
                        let settings = NotificationSoundSettings.extract(from: context.appConfiguration)
                        let size = file.size ?? 0
                        let contains = list.sounds.contains(where: { $0.file.fileId.id == file.fileId.id })
                        let duration = file.duration ?? 0
                        if size < settings.maxSize, Int(duration) < settings.maxDuration, list.sounds.count < settings.maxSavedCount, !contains {
                            thirdBlock.append(ContextMenuItem(strings().chatContextSaveRingtoneAdd, handler: {
                                let signal = context.engine.peers.saveNotificationSound(file: .message(message: .init(message), media: file))
                                _ = showModalProgress(signal: signal, for: context.window).start(error: { error in
                                    alert(for: context.window, info: strings().unknownError)
                                }, completed: {
                                    showModalText(for: context.window, text: strings().chatContextSaveRingtoneAddSuccess)
                                })
                                
                            }, itemImage: MenuAnimation.menu_note_download.value))
                        } else if contains {
                            thirdBlock.append(ContextMenuItem(strings().chatContextSaveRingtoneRemove, handler: {
                                let signal = context.engine.peers.removeNotificationSound(file: .message(message: .init(message), media: file))
                                _ = showModalProgress(signal: signal, for: context.window).start(error: { error in
                                    alert(for: context.window, info: strings().unknownError)
                                }, completed: {
                                    showModalText(for: context.window, text: strings().chatContextSaveRingtoneRemoveSuccess)
                                })
                                
                            }, itemImage: MenuAnimation.menu_note_slash.value))
                        }
                    }
                    if !data.isMediaStory {
                        thirdBlock.append(ContextMenuItem(strings().chatContextSaveMedia, handler: {
                            saveAs(file, account: account)
                        }, itemImage: MenuAnimation.menu_save_as.value, keyEquivalent: .cmds))
                    }
                    
                    if let downloadPath = data.fileFinderPath {
//                        if !file.isVoice {
//                            let path: String
//                            if FileManager.default.fileExists(atPath: downloadPath) {
//                                path = downloadPath
//                            } else {
//                                path = resourceData.path + "." + fileExtenstion(file)
//                                try? FileManager.default.removeItem(atPath: path)
//                                try? FileManager.default.linkItem(atPath: resourceData.path, toPath: path)
//                            }
//                            let result = ObjcUtils.apps(forFileUrl: path)
//                            if let result = result, !result.isEmpty {
//                                let item = ContextMenuItem(strings().messageContextOpenWith, handler: {}, itemImage: MenuAnimation.menu_open_with.value)
//                                let menu = ContextMenu()
//                                item.submenu = menu
//                                for item in result {
//                                    menu.addItem(ContextMenuItem(item.fullname, handler: {
//                                        NSWorkspace.shared.openFile(path, withApplication: item.app.path)
//                                    }, image: item.icon))
//                                }
//                                thirdBlock.append(item)
//                                
//                            } else {
//                                try? FileManager.default.removeItem(atPath: path)
//                            }
//                        }
                    }
                }
               
            } else if data.image != nil, !data.isMediaStory {
                if resourceData.complete {
                    let text = strings().chatContextCopyMedia
                    thirdBlock.append(ContextMenuItem(text, handler: {
                        if let path = link(path: resourceData.path, ext: "jpg") {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.writeObjects([NSURL(fileURLWithPath: path)])
                            showModalText(for: context.window, text: strings().contextAlertCopied)
                        }
                    }, itemImage: MenuAnimation.menu_copy_media.value, keyEquivalent: .cmdc))
                    thirdBlock.append(ContextMenuItem(strings().chatContextSaveMedia, handler: {
                        savePanel(file: resourceData.path, ext: "jpg", for: context.window)
                    }, itemImage: MenuAnimation.menu_save_as.value, keyEquivalent: .cmds))
                }
            }
        }
        
        if (MessageReadMenuItem.canViewReadStats(message: data.message, chatInteraction: data.chatInteraction, appConfig: appConfiguration)), data.isRead {
            if data.message.id.peerId.namespace == Namespaces.Peer.CloudUser  {
                fourthBlock.append(MessageReadMenuItem(context: context, chatInteraction: data.chatInteraction, message: message, availableReactions: data.availableReactions))
            } else {
                fourthBlock.append(MessageReadMenuItem(context: context, chatInteraction: data.chatInteraction, message: message, availableReactions: data.availableReactions))
            }
        }
        
//        #if DEBUG
//        fourthBlock.append(MessageReadMenuItem(context: context, chatInteraction: data.chatInteraction, message: message))
//        #endif
        
        if canReportMessage(data.message, context), data.chatMode != .pinned {
            
            let report = ContextMenuItem(strings().messageContextReport, itemImage: MenuAnimation.menu_report.value)
            
            
            let submenu = ContextMenu()
                        
            let options:[ReportReason] = [.spam, .violence, .porno, .childAbuse, .copyright, .personalDetails, .illegalDrugs]
            let animation:[LocalAnimatedSticker] = [.menu_delete, .menu_violence, .menu_pornography, .menu_restrict, .menu_copyright, .menu_open_profile, .menu_drugs]
            
            for i in 0 ..< options.count {
                submenu.addItem(ContextMenuItem(options[i].title, handler: {
                    _ = showModalProgress(signal: context.engine.peers.reportPeerMessages(messageIds: [messageId], reason: options[i], message: ""), for: context.window).start(completed: {
                        showModalText(for: context.window, text: strings().messageContextReportAlertOK)
                    })
                }, itemImage: animation[i].value))
            }
            
            submenu.addItem(ContextMenuItem(strings().reportReasonOther, handler: {
                showModal(with: ReportDetailsController(context: context, reason: .init(reason: .custom, comment: ""), updated: { value in
                    _ = showModalProgress(signal: context.engine.peers.reportPeerMessages(messageIds: [messageId], reason: .custom, message: value.comment), for: context.window).start(completed: {
                        showModalText(for: context.window, text: strings().messageContextReportAlertOK)
                    })
                }), for: context.window)
            }, itemImage: MenuAnimation.menu_read.value))
            report.submenu = submenu
            
            fifthBlock.append(report)
        }
        if let peer = data.peer as? TelegramChannel, peer.isSupergroup, data.chatMode == .history {
            if peer.groupAccess.canEditMembers, let author = data.message.author {
                if author.id != context.peerId, data.message.flags.contains(.Incoming), author.isUser || author.isBot {
                    fifthBlock.append(ContextMenuItem(strings().chatContextRestrict, handler: {
                        _ = showModalProgress(signal: context.engine.peers.fetchChannelParticipant(peerId: chatInteraction.peerId, participantId: author.id), for: context.window).start(next: { participant in
                            if let participant = participant {
                                switch participant {
                                case let .member(memberId, _, _, _, _):
                                    showModal(with: RestrictedModalViewController(context, peerId: peerId, memberId: memberId, initialParticipant: participant, updated: { updatedRights in
                                        _ = context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peerId, memberId: author.id, bannedRights: updatedRights).start()
                                    }), for: context.window)
                                default:
                                    break
                                }
                            }
                        })
                    }, itemImage: MenuAnimation.menu_restrict.value))
                }
            }
        }
        
        if data.updatingMessageMedia[messageId] != nil {
            fifthBlock.append(ContextMenuItem(strings().chatContextCancelEditing, handler: {
                account.pendingUpdateMessageManager.cancel(messageId: messageId)
            }, itemImage: MenuAnimation.menu_clear_history.value))
        }

        if canDeleteMessage(data.message, account: account, mode: data.chatMode) {
            fifthBlock.append(ContextMenuItem(strings().messageContextDelete, handler: {
                data.chatInteraction.deleteMessages([data.message.id])
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
        }
        
        #if BETA || DEBUG
        if let mediaId = message.media.first?.id {
            fifthBlock.append(ContextSeparatorItem())
            fifthBlock.append(ContextMenuItem("Copy Media Id (dev)", handler: {
                copyToClipboard("\(mediaId.id)")
                showModalText(for: context.window, text: "Copied")
            }, itemMode: .normal, itemImage: MenuAnimation.menu_copy.value))
            
        }
        #endif
        
        
        if let attr = message.textEntities, !isService {
            var references: [StickerPackReference] = attr.entities.compactMap({ value in
                if case let .CustomEmoji(reference, _) = value.type {
                    return reference
                } else {
                    return nil
                }
            })
            
            references += message.associatedMedia.compactMap {
                ($0.value as? TelegramMediaFile)?.emojiReference
            }
            references = references.uniqueElements
            
            let sources: [StickerPackPreviewSource] = references.map {
                .emoji($0)
            }
            
            if !sources.isEmpty {
                
                let text = strings().chatContextMessageContainsEmojiCountable(sources.count)
                
                let item = MessageContainsPacksMenuItem(title: text, handler: {
                    showModal(with: StickerPackPreviewModalController(context, peerId: peerId, references: sources), for: context.window)
                }, packs: references, context: context)
                
                sixBlock.append(item)
                
//                sixBlock.append(ContextMenuItem(strings().chatContextViewEmojiSetNewCountable(sources.count), handler: {
//                    showModal(with: StickerPackPreviewModalController(context, peerId: peerId, references: sources), for: context.window)
//                }, itemImage: MenuAnimation.menu_smile.value))
            }
        }
        
        let blocks:[[ContextMenuItem]] = [zeroBlock, firstBlock,
                                          add_secondBlock,
                                          thirdBlock,
                                          secondBlock,
                                          fourthBlock,
                                          fifthBlock,
                                          sixBlock].filter { !$0.isEmpty }
        
        for (i, block) in blocks.enumerated() {
            if i == 0 {
                items.append(contentsOf: block)
            } else {
                items.append(ContextSeparatorItem())
                items.append(contentsOf: block)
            }
        }
        for item in items {
            item.contextObject = data
        }
        return items
    }

}

