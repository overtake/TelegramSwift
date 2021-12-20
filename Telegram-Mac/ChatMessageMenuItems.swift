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
    
    init(chatInteraction: ChatInteraction, message: Message, accountPeer: Peer, resourceData: MediaResourceData?, chatState: ChatState, chatMode: ChatMode, disableSelectAbility: Bool, isLogInteraction: Bool, canPinMessage: Bool, pinnedMessage: ChatPinnedMessage?, peer: Peer?, peerId: PeerId, fileFinderPath: String?, isStickerSaved: Bool?, dialogs: [Peer], recentUsedPeers: [Peer], favoritePeers: [Peer], recentMedia: [RecentMediaItem], updatingMessageMedia: [MessageId: ChatUpdatingMessageMedia], additionalData: MessageEntryAdditionalData, file: TelegramMediaFile?, image: TelegramMediaImage?, textLayout: (TextViewLayout?, LinkType?)?, availableReactions: AvailableReactions?) {
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
    let canPinMessage = chatInteraction.presentation.canPinMessage
    let additionalData = entry?.additionalData ?? MessageEntryAdditionalData()
    
    
    var file: TelegramMediaFile? = nil
    var image: TelegramMediaImage? = nil
    if let media = message.media.first as? TelegramMediaFile {
        file = media
    } else if let media = message.media.first as? TelegramMediaImage {
        image = media
    } else if let media = message.media.first as? TelegramMediaWebpage {
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

    let _dialogs: Signal<[Peer], NoError> = account.postbox.tailChatListView(groupId: .root, count: 25, summaryComponents: .init())
        |> map { view in
            return view.0.entries.compactMap { entry in
                switch entry {
                case let .MessageEntry(_, _, _, _, _, renderedPeer, _, _, _, _):
                    return renderedPeer.peer
                default:
                    return nil
                }
            }
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
    
    let combined = combineLatest(queue: .mainQueue(), _dialogs, _recentUsedPeers, _favoritePeers, _accountPeer, _resourceData, _fileFinderPath, _getIsStickerSaved, _recentMedia, _updatingMessageMedia, context.reactions.stateValue)
    |> take(1)
    
    
    return combined |> map { dialogs, recentUsedPeers, favoritePeers, accountPeer, resourceData, fileFinderPath, isStickerSaved, recentMedia, updatingMessageMedia, availableReactions in
        return .init(chatInteraction: chatInteraction, message: message, accountPeer: accountPeer, resourceData: resourceData, chatState: chatState, chatMode: chatMode, disableSelectAbility: disableSelectAbility, isLogInteraction: isLogInteraction, canPinMessage: canPinMessage, pinnedMessage: pinnedMessage, peer: peer, peerId: peerId, fileFinderPath: fileFinderPath, isStickerSaved: isStickerSaved, dialogs: dialogs, recentUsedPeers: recentUsedPeers, favoritePeers: favoritePeers, recentMedia: recentMedia, updatingMessageMedia: updatingMessageMedia, additionalData: additionalData, file: file, image: image, textLayout: textLayout, availableReactions: availableReactions)
    }
}


func chatMenuItems(for message: Message, entry: ChatHistoryEntry?, textLayout: (TextViewLayout?, LinkType?)?, chatInteraction: ChatInteraction) -> Signal<[ContextMenuItem], NoError> {
    
    
    return chatMenuItemsData(for: message, textLayout: textLayout, entry: entry, chatInteraction: chatInteraction) |> map { data in

        let peer = data.message.peers[data.message.id.peerId]
        let isNotFailed = !message.flags.contains(.Failed) && !message.flags.contains(.Unsent) && !data.message.flags.contains(.Sending)
        let protected = data.message.containsSecretMedia || data.message.isCopyProtected()
        let peerId = data.peerId
        let messageId = data.message.id
        let appConfiguration = data.chatInteraction.context.appConfiguration
        let context = data.chatInteraction.context
        let account = context.account
        let isService = data.message.media.first is TelegramMediaAction
        
        var items:[ContextMenuItem] = []
        
        var firstBlock:[ContextMenuItem] = []
        var secondBlock:[ContextMenuItem] = []
        var add_secondBlock:[ContextMenuItem] = []
        var thirdBlock:[ContextMenuItem] = []
        var fourthBlock:[ContextMenuItem] = []
        var fifthBlock:[ContextMenuItem] = []
        
        
        if data.message.adAttribute != nil {
            items.append(ContextMenuItem(strings().chatMessageSponsoredWhat, handler: {
                let link = "https://promote.telegram.org"
                confirm(for: context.window, information: strings().chatMessageAdText(link), cancelTitle: "", thridTitle: strings().chatMessageAdReadMore, successHandler: { result in
                    switch result {
                    case .thrid:
                     let link = inAppLink.external(link: link, false)
                     execute(inapp: link)
                    default:
                        break
                    }
                })
            }))
            return items
        }
        
        if data.disableSelectAbility, data.isLogInteraction || data.chatState == .selecting || data.chatMode == .preview {
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

                modernConfirm(for: context.window, account: account, peerId: author.id, header: header, information: info, okTitle: ok, cancelTitle: cancel, thridTitle: third, thridAutoOn: true, successHandler: { result in
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
            firstBlock.append(ContextMenuItem(strings().chatContextScheduledReschedule, handler: { [weak data] in
                showModal(with: DateSelectorModalController(context: context, defaultDate: Date(timeIntervalSince1970: TimeInterval(message.timestamp)), mode: .schedule(peer.id), selectedAt: { [weak data] date in
                    if let data = data {
                        _ = showModalProgress(signal: context.engine.messages.requestEditMessage(messageId: messageId, text: data.message.text, media: .keep, entities: data.message.textEntities, scheduleTime: Int32(min(date.timeIntervalSince1970, Double(scheduleWhenOnlineTimestamp)))), for: context.window).start()
                    }
               }), for: context.window)
            }, itemImage: MenuAnimation.menu_schedule_message.value))
        }
        
        
        if canReplyMessage(data.message, peerId: data.peerId, mode: data.chatMode)  {
            firstBlock.append(ContextMenuItem(strings().messageContextReply1, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.setupReplyMessage(data.message.id)
                }
            }, itemImage: MenuAnimation.menu_reply.value, keyEquivalent: .cmdr))
        }
        
        
        if let poll = data.message.media.first as? TelegramMediaPoll {
            if !poll.isClosed && isNotFailed {
                if let _ = poll.results.voters?.first(where: {$0.selected}), poll.kind != .quiz {
                    let isLoading = data.additionalData.pollStateData.isLoading
                    add_secondBlock.append(ContextMenuItem(strings().chatPollUnvote, handler: { [weak data] in
                        if !isLoading, let data = data, isNotFailed {
                            data.chatInteraction.vote(messageId, [], true)
                        }
                    }, itemImage: MenuAnimation.menu_retract_vote.value))
                }
                if data.message.forwardInfo == nil {
                    var canClose: Bool = data.message.author?.id == context.peerId
                    if let peer = data.peer as? TelegramChannel {
                        canClose = peer.hasPermission(.sendMessages) || peer.hasPermission(.editAllMessages)
                    }
                    if canClose {
                        add_secondBlock.append(ContextMenuItem(poll.kind == .quiz ? strings().chatQuizStop : strings().chatPollStop, handler: { [weak data] in
                            confirm(for: context.window, header: poll.kind == .quiz ? strings().chatQuizStopConfirmHeader : strings().chatPollStopConfirmHeader, information: poll.kind == .quiz ? strings().chatQuizStopConfirmText : strings().chatPollStopConfirmText, okTitle: strings().alertConfirmStop, successHandler: { [weak data] _ in
                                if let data = data {
                                    data.chatInteraction.closePoll(messageId)
                                }
                            })
                        }, itemImage: MenuAnimation.menu_stop_poll.value))
                    }
                }
            }
            
        }
        
        if data.chatMode.threadId == nil, let peer = peer, peer.isSupergroup {
            if let attr = data.message.replyThread, attr.count > 0 {
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
                secondBlock.append(ContextMenuItem(text, handler: { [weak data] in
                    if let data = data {
                        data.chatInteraction.openReplyThread(messageId, !modeIsReplies, true, modeIsReplies ? .replies(origin: messageId) : .comments(origin: messageId))
                    }
                }, itemImage: MenuAnimation.menu_view_replies.value))
            }
        }
        
        if !data.message.isCopyProtected() {
            if let textLayout = data.textLayout?.0 {
                if !textLayout.selectedRange.hasSelectText {
                    thirdBlock.append(ContextMenuItem(strings().chatContextCopyText, handler: { [weak textLayout] in
                        if let textLayout = textLayout {
                            if !globalLinkExecutor.copyAttributedString(textLayout.attributedString) {
                                copyToClipboard(textLayout.attributedString.string)
                            }
                        }
                    }, itemImage: MenuAnimation.menu_copy.value))
                } else {
                    let text: String
                    if let linkType = data.textLayout?.1 {
                        text = copyContextText(from: linkType)
                    } else {
                        text = strings().chatCopySelectedText
                    }
                    thirdBlock.append(ContextMenuItem(text, handler: { [weak textLayout] in
                        if let textLayout = textLayout {
                            let result = textLayout.interactions.copy?()
                            let attr = textLayout.attributedString
                            if let result = result, !result {
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
                        }
                    }, itemImage: MenuAnimation.menu_copy.value))
                }
            }
        }
       
        
        if let peer = peer as? TelegramChannel, !isService {
            if isNotFailed, !message.isScheduledMessage {
                thirdBlock.append(ContextMenuItem(strings().messageContextCopyMessageLink1, handler: { [weak data] in
                    if let data = data {
                        _ = showModalProgress(signal: context.engine.messages.exportMessageLink(peerId: peer.id, messageId: messageId, isThread: data.chatMode.threadId != nil), for: context.window).start(next: { link in
                            if let link = link {
                                copyToClipboard(link)
                            }
                        })
                    }
                    
                }, itemImage: MenuAnimation.menu_copy_link.value))
            }
        }
        
        if canEditMessage(data.message, chatInteraction: data.chatInteraction, context: context), data.chatMode != .pinned, !isService {
            secondBlock.append(ContextMenuItem(strings().messageContextEdit, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.beginEditingMessage(data.message)
                }
            }, itemImage: MenuAnimation.menu_edit.value, keyEquivalent: .cmde))
        }
        
        if !data.message.isScheduledMessage, let peer = peer, !peer.isDeleted, isNotFailed, data.peerId == data.message.id.peerId, !isService {
            
            let needUnpin = data.pinnedMessage?.others.contains(data.message.id) == true
            let pinAndOld: Bool
            if let pinnedMessage = data.pinnedMessage, let last = pinnedMessage.others.last {
                pinAndOld = last > data.message.id
            } else {
                pinAndOld = false
            }
            let pinText = data.message.tags.contains(.pinned) ? strings().messageContextUnpin : strings().messageContextPin
            
            let pinImage = data.message.tags.contains(.pinned) ? MenuAnimation.menu_unpin.value : MenuAnimation.menu_pin.value

            if let peer = peer as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
                if isNotFailed {
                    if !data.chatMode.isThreadMode, (needUnpin || data.chatMode != .pinned) {
                        secondBlock.append(ContextMenuItem(pinText, handler: { [weak data] in
                            if peer.isSupergroup, !needUnpin, let data = data {
                                let info = pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1
                                
                                modernConfirm(for: context.window, information: info, okTitle:  strings().messageContextPin, thridTitle: pinAndOld ? nil : strings().messageContextConfirmNotifyPin, successHandler: { result in
                                    data.chatInteraction.updatePinned(data.message.id, needUnpin, result != .thrid, false)
                                })
                            } else if let data = data {
                                data.chatInteraction.updatePinned(data.message.id, needUnpin, true, false)
                            }
                        }, itemImage: pinImage))
                    }
                }
            } else if data.message.id.peerId == context.peerId {
                secondBlock.append(ContextMenuItem(pinText, handler: { [weak data] in
                    if let data = data {
                        data.chatInteraction.updatePinned(data.message.id, needUnpin, true, false)
                    }
                }, itemImage: pinImage))
            } else if let peer = peer as? TelegramGroup, peer.canPinMessage, (needUnpin || data.chatMode != .pinned) {
                secondBlock.append(ContextMenuItem(pinText, handler: { [weak data] in
                    if !needUnpin, let data = data {
                        modernConfirm(for: context.window, account: account, peerId: nil, information: pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1, okTitle: strings().messageContextPin, thridTitle: pinAndOld ? nil : strings().messageContextConfirmNotifyPin, successHandler: { result in
                            data.chatInteraction.updatePinned(data.message.id, needUnpin, result == .thrid, false)
                        })
                    } else if let data = data {
                        data.chatInteraction.updatePinned(data.message.id, needUnpin, false, false)
                    }
                }, itemImage: pinImage))
            } else if data.canPinMessage, let peer = data.peer, (needUnpin || data.chatMode != .pinned) {
                secondBlock.append(ContextMenuItem(pinText, handler: { [weak data] in
                    if !needUnpin, let data = data {
                        modernConfirm(for: context.window, account: account, peerId: nil, information: pinAndOld ? strings().chatConfirmPinOld : strings().messageContextConfirmPin1, okTitle: strings().messageContextPin, thridTitle: strings().chatConfirmPinFor(peer.displayTitle), thridAutoOn: false, successHandler: { result in
                            data.chatInteraction.updatePinned(data.message.id, needUnpin, false, result != .thrid)
                        })
                    } else if let data = data {
                        data.chatInteraction.updatePinned(data.message.id, needUnpin, false, false)
                    }
                }, itemImage: pinImage))
            }
        }
        
        if canForwardMessage(data.message, chatInteraction: data.chatInteraction), !isService {
            let forwardItem = ContextMenuItem(strings().messageContextForward, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.forwardMessages([data.message.id])
                }
            }, itemImage: MenuAnimation.menu_forward.value)
            let forwardMenu = ContextMenu()
            
            let forwardObject = ForwardMessagesObject(context, messageIds: [message.id])
            
            let recent = data.recentUsedPeers.filter {
                $0.id != context.peerId && $0.canSendMessage()
            }.prefix(5)
            
            let favorite = data.favoritePeers.filter {
                !recent.map { $0.id }.contains($0.id) && $0.id != context.peerId && $0.canSendMessage()
            }.prefix(5)
            
            let dialogs = data.dialogs.reversed().filter {
                !(recent + favorite).map { $0.id }.contains($0.id)
                    && $0.id != context.peerId
                    && $0.canSendMessage()
            }.prefix(5)
            
            var items:[ContextMenuItem] = []
            
            
            func makeItem(_ peer: Peer) -> ContextMenuItem {
                let title = peer.id == context.peerId ? strings().peerSavedMessages : peer.displayTitle.prefixWithDots(20)
                let item = ContextMenuItem(title, handler: {
                    _ = forwardObject.perform(to: [peer.id]).start()
                })
                let signal:Signal<(CGImage?, Bool), NoError>
                if peer.id == context.peerId {
                    let icon = theme.icons.searchSaved
                    signal = generateEmptyPhoto(NSMakeSize(18, 18), type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(10, 10)), cornerRadius: nil)) |> deliverOnMainQueue |> map { ($0, true) }
                } else {
                    signal = peerAvatarImage(account: account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, message), displayDimensions: NSMakeSize(18 * System.backingScale, 18 * System.backingScale), font: .avatar(13), genCap: true, synchronousLoad: false) |> deliverOnMainQueue
                }
                _ = signal.start(next: { [weak item] image, _ in
                    if let image = image {
                        item?.image = NSImage(cgImage: image, size: NSMakeSize(18, 18))
                    }
                })
                return item
            }
            
            
            items.append(makeItem(data.accountPeer))
            if !recent.isEmpty || !dialogs.isEmpty || !favorite.isEmpty {
                items.append(ContextSeparatorItem())
            }
            for peer in recent {
                items.append(makeItem(peer))
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
                items.append(makeItem(peer))
            }
            if !items.isEmpty {
                items.append(ContextSeparatorItem())
                let more = ContextMenuItem(strings().chatContextForwardMore, handler: { [unowned chatInteraction] in
                    chatInteraction.forwardMessages([message.id])
                })
                items.append(more)
            }
            for item in items {
                forwardMenu.addItem(item)
            }
           
            forwardItem.submenu = forwardMenu
            secondBlock.append(forwardItem)
        } else if data.message.id.peerId.namespace == Namespaces.Peer.SecretChat, !data.message.containsSecretMedia {
            secondBlock.append(ContextMenuItem(strings().messageContextShare, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.forwardMessages([data.message.id])
                }
            }))
        }

        
        
        if data.chatMode.threadId != data.message.id, !isService {
            secondBlock.append(ContextMenuItem(strings().messageContextSelect, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.withToggledSelectedMessage({
                        $0.withToggledSelectedMessage(data.message.id)
                    })
                }
            }, itemImage: MenuAnimation.menu_select_messages.value))
        }
        
        if let resourceData = data.resourceData, !protected, !isService {
            if let file = data.file {
                if file.isVideo && file.isAnimated {
                    if data.recentMedia.contains(where: {$0.media.id == file.fileId}) {
                        thirdBlock.append(ContextMenuItem(strings().messageContextRemoveGif, handler: {
                            _ = removeSavedGif(postbox: account.postbox, mediaId: file.fileId).start()
                        }, itemImage: MenuAnimation.menu_remove_gif.value))
                    } else {
                        thirdBlock.append(ContextMenuItem(strings().messageContextSaveGif, handler: { [weak data] in
                            if let data = data {
                                _ = addSavedGif(postbox: account.postbox, fileReference: FileMediaReference.message(message: MessageReference(data.message), media: file)).start()
                            }
                        }, itemImage: MenuAnimation.menu_add_gif.value))
                    }
                }
                if file.isSticker, let saved = data.isStickerSaved {
                    let image = saved ? MenuAnimation.menu_remove_from_favorites.value : MenuAnimation.menu_add_to_favorites.value
                    thirdBlock.append(ContextMenuItem(!saved ? strings().chatContextAddFavoriteSticker : strings().chatContextRemoveFavoriteSticker, handler: {
                        if !saved {
                            _ = addSavedSticker(postbox: account.postbox, network: account.network, file: file).start()
                        } else {
                            _ = removeSavedSticker(postbox: account.postbox, mediaId: file.fileId).start()
                        }
                    }, itemImage: image))
                }
                
                if resourceData.complete {
                    thirdBlock.append(ContextMenuItem(strings().chatContextSaveMedia, handler: {
                        saveAs(file, account: account)
                    }, itemImage: MenuAnimation.menu_save_as.value, keyEquivalent: .cmds))
                   
                    if let downloadPath = data.fileFinderPath {
                        if !file.isVoice {
                            let path: String
                            if FileManager.default.fileExists(atPath: downloadPath) {
                                path = downloadPath
                            } else {
                                path = resourceData.path + "." + fileExtenstion(file)
                                try? FileManager.default.removeItem(atPath: path)
                                try? FileManager.default.linkItem(atPath: resourceData.path, toPath: path)
                            }
                            let result = ObjcUtils.apps(forFileUrl: path)
                            if let result = result, !result.isEmpty {
                                let item = ContextMenuItem(strings().messageContextOpenWith, handler: {}, itemImage: MenuAnimation.menu_open_with.value)
                                let menu = ContextMenu()
                                item.submenu = menu
                                for item in result {
                                    menu.addItem(ContextMenuItem(item.fullname, handler: {
                                        NSWorkspace.shared.openFile(path, withApplication: item.app.path)
                                    }, image: item.icon))
                                }
                                thirdBlock.append(item)
                            }
                        }
                    }
                }
               
            } else if data.image != nil {
                if resourceData.complete {
                    let text = data.message.text.isEmpty ? strings().chatContextCopy : strings().chatContextCopyMedia
                    thirdBlock.append(ContextMenuItem(text, handler: {
                        if let path = link(path: resourceData.path, ext: "jpg") {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.writeObjects([NSURL(fileURLWithPath: path)])
                            showModalText(for: context.window, text: strings().contextAlertCopied)
                        }
                    }, itemImage: MenuAnimation.menu_copy_media.value, keyEquivalent: .cmdc))
                    thirdBlock.append(ContextMenuItem(strings().chatContextSaveMedia, handler: {
                        savePanel(file: resourceData.path, ext: "jpg", for: mainWindow)
                    }, itemImage: MenuAnimation.menu_save_as.value, keyEquivalent: .cmds))
                }
            }
        }
        
        if (MessageReadMenuItem.canViewReadStats(message: data.message, chatInteraction: data.chatInteraction, appConfig: appConfiguration)) {
            fourthBlock.append(MessageReadMenuItem(context: context, chatInteraction: data.chatInteraction, message: message, availableReactions: data.availableReactions))
        }
        
//        #if DEBUG
//        fourthBlock.append(MessageReadMenuItem(context: context, chatInteraction: data.chatInteraction, message: message))
//        #endif
        
        if canReportMessage(data.message, account), data.chatMode != .pinned {
            
            let report = ContextMenuItem(strings().messageContextReport, itemImage: MenuAnimation.menu_report.value)
            
            
            let submenu = ContextMenu()
                        
            let options:[ReportReason] = [.spam, .violence, .porno, .childAbuse, .copyright]
            let animation:[LocalAnimatedSticker] = [.menu_delete, .menu_violence, .menu_pornography, .menu_restrict, .menu_copyright]
            
            for i in 0 ..< options.count {
                submenu.addItem(ContextMenuItem(options[i].title, handler: {
                    _ = showModalProgress(signal: context.engine.peers.reportPeerMessages(messageIds: [messageId], reason: options[i], message: ""), for: context.window).start(completed: {
                        showModalText(for: context.window, text: strings().messageContextReportAlertOK)
                    })
                }, itemImage: animation[i].value))
            }
            report.submenu = submenu
            
            fifthBlock.append(report)
        }
        if let peer = data.peer as? TelegramChannel, peer.isSupergroup, data.chatMode == .history {
            if peer.hasPermission(.banMembers), let author = data.message.author {
                if author.id != context.peerId, data.message.flags.contains(.Incoming) {
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
            fifthBlock.append(ContextMenuItem(strings().messageContextDelete, handler: { [weak data] in
                if let data = data {
                    data.chatInteraction.deleteMessages([data.message.id])
                }
            }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
        }
        
        let blocks:[[ContextMenuItem]] = [firstBlock,
                                          add_secondBlock,
                                          thirdBlock,
                                          secondBlock,
                                          fourthBlock,
                                          fifthBlock].filter { !$0.isEmpty }
        
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


/*
 #if BETA || ALPHA || DEBUG
 if file.isAnimatedSticker, let data = try? Data(contentsOf: URL(fileURLWithPath: data.path)) {
     items.append(ContextMenuItem("Copy thumbnail (Dev.)", handler: {
         _ = getAnimatedStickerThumb(data: data).start(next: { path in
             if let path = path {
                 let pb = NSPasteboard.general
                 pb.clearContents()
                 pb.writeObjects([NSURL(fileURLWithPath: path)])
             }
         })
     }))
 }
 #endif
 
 */
