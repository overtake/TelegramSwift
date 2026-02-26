//
//  ForumUIMethods.swift
//  Telegram
//
//  Created by Mike Renoir on 03.10.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit
import AppKit


struct ForumUI {
    
    static let topicColors: [([UInt32], [UInt32])] = [
                           ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
                           ([0x6FB9F0, 0x0261E4], [0x026CB5, 0x064BB7]),
                           ([0xFFD67E, 0xFC8601], [0xDA9400, 0xFA5F00]),
                           ([0xCB86DB, 0x9338AF], [0x812E98, 0x6F2B87]),
                           ([0x8EEE98, 0x02B504], [0x02A01B, 0x009716]),
                           ([0xFF93B2, 0xE23264], [0xFC447A, 0xC80C46]),
                           ([0xFB6F5F, 0xD72615], [0xDC1908, 0xB61506])
                       ]
    
 
    static func randomTopicColor() -> Int32 {
        return Int32(topicColors[Int.random(in: 0 ..< topicColors.count)].0[0])
    }
    
    static func topicColor(_ iconColor: Int32 = 0) -> ([NSColor], [NSColor]) {
        let values = topicColors.first(where: { value in
            let contains = value.0.contains(where: {
                $0 == iconColor
            })
            return contains
        })
        let colors = values ?? topicColors[0]
        return (colors.0.map { NSColor($0) }, colors.1.map { NSColor($0) })
    }
    
    static func makeIconFile(title: String, iconColor: Int32 = 0, isGeneral: Bool = false) -> TelegramMediaFile {
        let colors: ([NSColor], [NSColor]) = topicColor(iconColor)
        
        if isGeneral {
            return TelegramMediaFile(fileId: .init(namespace: 0, id: 523134), partialReference: nil, resource: LocalBundleResource(name: "Icon_Topic_General", ext: "", color: theme.chatList.badgeMutedBackgroundColor), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "bundle/jpeg", size: nil, attributes: [], alternativeRepresentations: [])
        }
        
        let resource = ForumTopicIconResource(title: title.prefix(1), bgColors: colors.0, strokeColors: colors.1, iconColor: iconColor)
        let id = Int64(resource.id.stringRepresentation.hashValue)
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "bundle/topic", size: nil, attributes: [], alternativeRepresentations: [])
    }
    
    
    static func open(_ peerId: PeerId, addition: Bool, context: AccountContext, threadId: Int64? = nil) {

        let signal: Signal<Bool, NoError>
        
        if let threadId = threadId {
            signal = openTopic(threadId, peerId: peerId, context: context) |> map { _ in context.layout == .dual }
        } else {
            let viewAsMessages: Signal<(Bool?, Bool?), NoError> = combineLatest(getCachedDataView(peerId: peerId, postbox: context.account.postbox) |> map { $0 as? CachedChannelData }, context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
            |> map { ($0?.viewForumAsMessages.knownValue, $1?._asPeer().displayForumAsTabs) }
            |> deliverOnMainQueue
            |> take(1)
            
            signal = viewAsMessages |> mapToSignal { value, displayAsTabs in
                let insertChat:(Bool)->Signal<Bool, NoError> = { displayAsTabs in
                    let ready = Promise<Bool>()
                    let controller: ChatController
                    if addition {
                        controller = ChatAdditionController(context: context, chatLocation: .peer(peerId))
                    } else {
                        controller = ChatController(context: context, chatLocation: .peer(peerId))
                    }
                    context.bindings.rootNavigation().push(controller)
                    ready.set(controller.ready.get() |> map { displayAsTabs ? false : context.layout == .single ? false : $0 })
                    return ready.get() |> take(1)
                }
                
                if displayAsTabs == true {
                    return insertChat(true)
                } else if let value = value {
                    if !value {
                        return .single(true)
                    } else {
                       return insertChat(false)
                    }
                } else {
                    return .single(true)
                }
            }
        }
        
        _ = signal.start(next: { value in
            if value {
                var parentIsArchive = false
                let navigation = context.bindings.mainController().effectiveNavigation
                if let controller = navigation.controller as? ChatListController {
                    if controller.mode.isForumLike {
                        if context.layout == .single {
                            context.bindings.rootNavigation().gotoEmpty()
                        } else {
                            if controller.isLoaded() {
                                controller.view.shake(beep: false)
                            }
                        }
                        return
                    }
                    parentIsArchive = controller.mode.groupId == .archive
                }
                
                let mode: PeerListMode = peerId == context.peerId ? .savedMessagesChats(peerId: peerId) : .forum(peerId, false, parentIsArchive)
                navigation.push(ChatListController(context, modal: false, mode: mode))
                if context.layout == .single {
                    context.bindings.rootNavigation().gotoEmpty()
                }
            }
        })
       
    }
    static func openTopic(_ threadId: Int64, peerId: PeerId, context: AccountContext, messageId: MessageId? = nil, animated: Bool = false, addition: Bool = false, initialAction: ChatInitialAction? = nil, isMonoforum: Bool = false) -> Signal<Bool, NoError> {
        
        let controller = context.bindings.rootNavigation().controller as? ChatController
        
        if let controller = controller, controller.chatLocation.peerId == peerId, controller.chatLocation.threadId == threadId {
            if let messageId = messageId {
                controller.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .CenterEmpty)
            } else {
                controller.scrollup()
            }
            if let initialAction = initialAction {
                controller.chatInteraction.invokeInitialAction(animated: true,action: initialAction)
            }
            return controller.ready.get()
        }
        
        let threadMessageId = makeThreadIdMessageId(peerId: peerId, threadId: threadId)
        let context = context
        let signal: Signal<ThreadInfo?, FetchChannelReplyThreadMessageError>
        
        if isMonoforum {
            signal = .single(nil)
        } else {
            signal = fetchAndPreloadReplyThreadInfo(context: context, subject: .groupMessage(threadMessageId), preload: false) |> map(Optional.init)
            |> deliverOnMainQueue
            
        }
        
        _ = context.engine.peers.updateForumViewAsMessages(peerId: peerId, value: false).start()
        
        let ready: Promise<Bool> = Promise()
        
        _ = signal.start(next: { result in
            
            let updatedMode: ChatMode
            
            
            let controller: ChatController
            
            let chatLocation: ChatLocation
            
            let chatLocationContextHolder = result?.contextHolder ?? Atomic<ChatLocationContextHolder?>(value: nil)

            
            if let result {
                chatLocation = .thread(result.message)
                updatedMode = .thread(mode:  .topic(origin: threadMessageId))
            } else {
                chatLocation = .makeSaved(peerId, peerId: PeerId(threadId), isMonoforum: true)
                updatedMode = .history
            }
            if addition {
                controller = ChatAdditionController(context: context, chatLocation: chatLocation, mode: updatedMode, focusTarget: .init(messageId: messageId), initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder)
            } else {
                controller = ChatController(context: context, chatLocation: chatLocation, mode: updatedMode, focusTarget: .init(messageId: messageId), initialAction: initialAction, chatLocationContextHolder: chatLocationContextHolder)
            }
            
            context.bindings.rootNavigation().push(controller, style: animated ? .push : nil)
            
            ready.set(controller.ready.get())
        }, error: { error in
            ready.set(.single(false))
        })
        
        return ready.get()
    }
    
    static func openSavedMessages(_ threadId: Int64, context: AccountContext, messageId: MessageId? = nil, animated: Bool = false, addition: Bool = false, initialAction: ChatInitialAction? = nil) -> Signal<Bool, NoError> {
        
        let controller = context.bindings.rootNavigation().controller as? ChatController
        
        if let controller = controller, controller.chatLocation.peerId == context.peerId, controller.chatLocation.threadId == threadId {
            if let messageId = messageId {
                controller.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .CenterEmpty)
            } else {
                controller.scrollup()
            }
            if let initialAction = initialAction {
                controller.chatInteraction.invokeInitialAction(animated: true,action: initialAction)
            }
            return controller.ready.get()
        }
        
        let threadMessage = ChatReplyThreadMessage(peerId: context.peerId, threadId: threadId, channelMessageId: nil, isChannelPost: false, isForumPost: false, isMonoforumPost: false, maxMessage: nil, maxReadIncomingMessageId: nil, maxReadOutgoingMessageId: nil, unreadCount: 0, initialFilledHoles: IndexSet(), initialAnchor: .automatic, isNotAvailable: false)
        let threadMessageId = makeThreadIdMessageId(peerId: context.peerId, threadId: threadId)

        
        let newController: ChatController
        
                
        if addition {
            newController = ChatAdditionController(context: context, chatLocation: .thread(threadMessage), mode: .thread(mode: .savedMessages(origin: threadMessageId)), focusTarget: .init(messageId: messageId))
        } else {
            newController = ChatController(context: context, chatLocation: .thread(threadMessage), mode: .thread(mode: .savedMessages(origin: threadMessageId)), focusTarget: .init(messageId: messageId))
        }
        
        context.bindings.rootNavigation().push(newController, style: animated ? .push : nil)
        
        
        return newController.ready.get()
    }
    
    static func addMembers(_ peerId: PeerId, context: AccountContext) {
        
    }
    static func openInfo(_ peerId: PeerId, context: AccountContext) {
        let navigation = context.bindings.rootNavigation()
        if let current = navigation.controller as? PeerInfoController {
            if current.peerId == peerId, current.threadInfo == nil {
                return
            }
        }
        PeerInfoController.push(navigation: navigation, context: context, peerId: peerId)
    }
    static func openTopicInfo(_ threadId: Int64, peerId: PeerId, context: AccountContext) {
        let navigation = context.bindings.rootNavigation()
        PeerInfoController.push(navigation: navigation, context: context, peerId: peerId)
    }
    static func createTopic(_ peerId: PeerId, context: AccountContext) {
        let navigation = context.bindings.rootNavigation()
        navigation.push(ForumTopicInfoController(context: context, purpose: .create, peerId: peerId))
    }
    static func editTopic(_ peerId: PeerId, data: MessageHistoryThreadData, threadId: Int64, context: AccountContext) {
        let navigation = context.bindings.rootNavigation()
        navigation.push(ForumTopicInfoController(context: context, purpose: .edit(data, threadId), peerId: peerId))
    }
}


func generateTopicIcon(size: NSSize, backgroundColors: [NSColor], strokeColors: [NSColor], title: String) -> DrawingContext {
    
    let title = title.isEmpty ? "A" : title.prefix(1).uppercased()
    
    let realSize = NSMakeSize(min(size.width, size.height), min(size.width, size.height))
    
    let context = DrawingContext(size: realSize, scale: 0, clear: false)
    context.withFlippedContext(isHighQuality: true, horizontal: false, vertical: true, { context in
        context.clear(CGRect(origin: .zero, size: realSize))
        
//        context.setFillColor(NSColor.random.cgColor)
//        context.fill(size.bounds)
        
        context.saveGState()
        
        let size = CGSize(width: 32.0, height: 32.0)
                
        let scale: CGFloat = realSize.width / size.width
        context.scaleBy(x: scale, y: scale)
                
        context.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        context.translateBy(x: -14.0 - 1, y: -14.0 - 1)

        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        context.clip()
        
        let colorsArray = backgroundColors.map { $0.cgColor } as NSArray
        var locations: [CGFloat] = [0.0, 1.0]
        let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        
        context.resetClip()
        
        let _ = try? drawSvgPath(context, path: "M24.1835,4.71703 C21.7304,2.42169 18.2984,0.995605 14.5,0.995605 C7.04416,0.995605 1.0,6.49029 1.0,13.2683 C1.0,17.1341 2.80572,20.3028 5.87839,22.5523 C6.27132,22.84 6.63324,24.4385 5.75738,25.7811 C5.39922,26.3301 5.00492,26.7573 4.70138,27.0861 C4.26262,27.5614 4.01347,27.8313 4.33716,27.967 C4.67478,28.1086 6.66968,28.1787 8.10952,27.3712 C9.23649,26.7392 9.91903,26.1087 10.3787,25.6842 C10.7588,25.3331 10.9864,25.1228 11.187,25.1688 C11.9059,25.3337 12.6478,25.4461 13.4075,25.5015 C13.4178,25.5022 13.4282,25.503 13.4386,25.5037 C13.7888,25.5284 14.1428,25.5411 14.5,25.5411 C21.9558,25.5411 28.0,20.0464 28.0,13.2683 C28.0,9.94336 26.5455,6.92722 24.1835,4.71703 ")
        context.closePath()
        if let path = context.path {
            let strokePath = path.copy(strokingWithWidth: 1.0, lineCap: .round, lineJoin: .round, miterLimit: 0.0)
            context.beginPath()
            context.addPath(strokePath)
            context.clip()
            
            let colorsArray = strokeColors.map { $0.cgColor } as NSArray
            var locations: [CGFloat] = [0.0, 1.0]
            let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
        }
        
        context.restoreGState()
        
        let fontSize = round(15.0 * scale)

        
        let attributedString = NSAttributedString(string: title, attributes: [NSAttributedString.Key.font: NSFont.avatar(fontSize), NSAttributedString.Key.foregroundColor: NSColor.white])
        
        let line = CTLineCreateWithAttributedString(attributedString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        
       
        var lineOffset = CGPoint(x: 0, y: floor(realSize.height * 0.05) + 1)
        
        if realSize.height == 19 {
            lineOffset.y += 1
        }
        let lineOrigin = CGPoint(x: round(-lineBounds.origin.x + (realSize.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: round(-lineBounds.origin.y + (realSize.height - lineBounds.size.height) / 2.0) + lineOffset.y - 1)
        
        context.translateBy(x: realSize.width / 2.0, y: realSize.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -realSize.width / 2.0, y: -realSize.height / 2.0)
        
        context.translateBy(x: lineOrigin.x, y: lineOrigin.y)
        CTLineDraw(line, context)
        context.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)

    })
    return context

}

