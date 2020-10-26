//
//  ChatGroupedItem.swift
//  Telegram
//
//  Created by keepcoder on 31/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

class ChatGroupedItem: ChatRowItem {

    fileprivate(set) var parameters: [ChatMediaLayoutParameters] = []
    fileprivate let layout: GroupedLayout
    
    override var messages: [Message] {
        return layout.messages
    }
    
    var layoutType: GroupedMediaType {
        return layout.type
    }
   
    
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ context: AccountContext, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings, theme: TelegramPresentationTheme) {
        
        var captionLayouts: [ChatRowItem.RowCaption] = []
        
        if case let .groupedPhotos(messages, _) = entry {
            
            let messages = messages.map{$0.message!}.filter({!$0.media.isEmpty})
            let prettyCount = messages.filter { $0.media.first!.isInteractiveMedia }.count
            self.layout = GroupedLayout(messages, type: prettyCount != messages.count ? .files : .photoOrVideo)
            
            var captionMessages: [Message] = []
            switch layout.type {
            case .photoOrVideo:
                for message in messages {
                    if !captionMessages.isEmpty, !message.text.isEmpty {
                        captionMessages.removeAll()
                        break
                    }
                    if !message.text.isEmpty {
                        captionMessages.append(message)
                    }
                }
            case .files:
                captionMessages = messages.filter { !$0.text.isEmpty }
            }
            
            
            for message in captionMessages {
                
                let isIncoming: Bool = message.isIncoming(context.account, entry.renderType == .bubble)

                var caption:NSMutableAttributedString = NSMutableAttributedString()
                NSAttributedString.initialize()
                _ = caption.append(string: message.text, color: theme.chat.textColor(isIncoming, entry.renderType == .bubble), font: NSFont.normal(theme.fontSize))
                var types:ParsingType = [.Links, .Mentions, .Hashtags]
                
                if let peer = messageMainPeer(message) as? TelegramUser {
                    if peer.botInfo != nil {
                        types.insert(.Commands)
                    }
                } else if let peer = messageMainPeer(message) as? TelegramChannel {
                    switch peer.info {
                    case .group:
                        types.insert(.Commands)
                    default:
                        break
                    }
                } else {
                    types.insert(.Commands)
                }
                
                var hasEntities: Bool = false
                for attr in message.attributes {
                    if attr is TextEntitiesMessageAttribute {
                        hasEntities = true
                        break
                    }
                }
                if hasEntities {
                    caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, context: context, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), monospacedPre: theme.chat.monospacedPreColor(isIncoming, entry.renderType == .bubble), monospacedCode: theme.chat.monospacedCodeColor(isIncoming, entry.renderType == .bubble), openBank: chatInteraction.openBank).mutableCopy() as! NSMutableAttributedString
                }
                
                if !hasEntities || message.flags.contains(.Failed) || message.flags.contains(.Unsent) || message.flags.contains(.Sending) {
                    caption.detectLinks(type: types, context: context, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo:chatInteraction.openInfo, hashtag: context.sharedContext.bindings.globalSearch, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy)
                }
                let layout: ChatRowItem.RowCaption = .init(id: message.stableId, offset: .zero, layout: TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble, alwaysStaticItems: true))
                layout.layout.interactions = globalLinkExecutor
                captionLayouts.append(layout)
            }
            
        } else {
            fatalError("")
        }
        
        super.init(initialSize, chatInteraction, context, entry, downloadSettings, theme: theme)
        
         self.captionLayouts = captionLayouts
                
        for (i, message) in layout.messages.enumerated() {
            
            switch layout.type {
            case .files:
                
               // self.parameters.append(ChatMediaLayoutParameters.layout(for: (message.media.first as! TelegramMediaFile), isWebpage: false, chatInteraction: chatInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType), automaticDownload: downloadSettings.isDownloable(message), isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), isFile: true, autoplayMedia: entry.autoplayMedia, isChatRelated: true))

                
                self.parameters.append(ChatMediaLayoutParameters.layout(for: (message.media.first as! TelegramMediaFile), isWebpage: chatInteraction.isLogInteraction, chatInteraction: chatInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType), automaticDownload: downloadSettings.isDownloable(message), isIncoming: message.isIncoming(context.account, entry.renderType == .bubble), autoplayMedia: entry.autoplayMedia))
            case .photoOrVideo:
                self.parameters.append(ChatMediaGalleryParameters(showMedia: { [weak self] message in
                    guard let `self` = self else {return}
                    
                    var type:GalleryAppearType = .history
                    if let parameters = self.parameters[i] as? ChatMediaGalleryParameters, parameters.isWebpage {
                        type = .alone
                    } else if message.containsSecretMedia {
                        type = .secret
                    }
                    if self.chatInteraction.mode.threadId?.peerId == message.id.peerId {
                        type = .messages(self.messages)
                    }
                    showChatGallery(context: context, message: message, self.table, self.parameters[i], type: type)
                    
                    }, showMessage: { [weak self] message in
                        self?.chatInteraction.focusMessageId(nil, message.id, .CenterEmpty)
                    }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: context.account, renderType: entry.renderType), media: message.media.first!, automaticDownload: downloadSettings.isDownloable(message), autoplayMedia: entry.autoplayMedia))
                
                self.parameters[i].automaticDownloadFunc = { message in
                    return downloadSettings.isDownloable(message)
                }
            }
            self.parameters[i].chatLocationInput = chatInteraction.chatLocationInput
           
        }
        
        if isBubbleFullFilled, layout.messages.count == 1  {
            var positionFlags: LayoutPositionFlags = []
            if captionLayouts.isEmpty {
                positionFlags.insert(.bottom)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            if authorText == nil && replyModel == nil && forwardNameLayout == nil {
                positionFlags.insert(.top)
                positionFlags.insert(.left)
                positionFlags.insert(.right)
            }
            self.positionFlags = positionFlags
        }
        
        switch self.layout.type {
        case .files:
            var positionFlags: LayoutPositionFlags = []
            positionFlags.insert(.bottom)
            positionFlags.insert(.top)
            positionFlags.insert(.left)
            positionFlags.insert(.right)
            self.positionFlags = positionFlags
        default:
            break
        }
    }
    
    override func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(context, message, layout.messages)), for: mainWindow)
        }

    }
    
    override var hasBubble: Bool {
        get {
            if isBubbled, self.layout.type == .files {
                return true
            }
            return isBubbled && (!captionLayouts.isEmpty || message?.replyAttribute != nil || forwardNameLayout != nil || layout.messages.count == 1 || commentsBubbleData != nil)
        }
        set {
            super.hasBubble = newValue
        }
    }
    
    override var isBubbleFullFilled: Bool {
        return isBubbled && self.layout.type != .files
    }
    
    var mediaBubbleCornerInset: CGFloat {
        return 1
    }
    
    override var bubbleFrame: NSRect {
        var frame = super.bubbleFrame
        
        if isBubbleFullFilled {
            frame.size.width = contentSize.width + additionBubbleInset
            if hasBubble {
                frame.size.width += self.mediaBubbleCornerInset * 2
            }
        }
        
        return frame
    }
    
    override var defaultContentTopOffset: CGFloat {
        if isBubbled && !hasBubble {
            return 2
        }
        return super.defaultContentTopOffset
    }
    
    fileprivate var positionFlags: LayoutPositionFlags?
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        //
        if hasBubble {
            if  forwardNameLayout != nil {
                offset.y += defaultContentInnerInset
            } else if authorText == nil && replyModel == nil, !isBubbleFullFilled  {
                offset.y += (defaultContentInnerInset + 6)
            }
        }
        
        if hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil {
            offset.y -= (defaultContentInnerInset + self.mediaBubbleCornerInset * 2 - 1)
        } else if hasBubble && authorText != nil {
            offset.y += 2
        }
        return offset
    }
    
    override var elementsContentInset: CGFloat {
        if hasBubble && isBubbleFullFilled {
            return bubbleContentInset
        }
        return super.elementsContentInset
    }
    
    override var _defaultHeight: CGFloat {
        if hasBubble && isBubbleFullFilled && captionLayouts.isEmpty {
            return contentOffset.y + defaultContentInnerInset - mediaBubbleCornerInset * 2
        } else if hasBubble && !isBubbleFullFilled {
            return super._defaultHeight + 5
        }
        
        return super._defaultHeight
    }
    
    override var realContentSize: NSSize {
        var size = super.realContentSize
        
        if isBubbleFullFilled {
            size.width -= bubbleContentInset * 2
        }
        return size
    }
    
    override var additionalLineForDateInBubbleState: CGFloat? {
        if let caption = captionLayouts.first(where: { $0.id == lastMessage?.stableId })?.layout {
            if let line = caption.lines.last, line.frame.width > realContentSize.width - (rightSize.width + insetBetweenContentAndDate) {
                return rightSize.height
            }
        }
        return super.additionalLineForDateInBubbleState
    }
    
    override var isFixedRightPosition: Bool {
        return true
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        var _width: CGFloat = 0
        switch layout.type {
        case .files:
            for parameter in parameters {
                let value = parameter.makeLabelsForWidth(min(width, 360))
                _width = max(_width, value)
            }
        case .photoOrVideo:
            _width = min(width, 360)
        }
       
        layout.measure(NSMakeSize(_width, min(_width, 320)), spacing: hasBubble ? 2 : 4)
        
        
        var maxContentWidth = layout.dimensions.width
        if hasBubble {
            maxContentWidth -= bubbleDefaultInnerInset
        }
        for layout in captionLayouts {
            if layout.layout.layoutSize == .zero {
                layout.layout.measure(width: maxContentWidth)
            }
        }
        self.captionLayouts = layout.applyCaptions(captionLayouts)
        return layout.dimensions
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let result = super.makeSize(width, oldWidth: oldWidth)
        return result
    }
    
    override var topInset:CGFloat {
        return 4
    }
    
    func contentNode(for index: Int) -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: layout.messages[index].media[0])
    }

    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var _message: Message? = nil
        let context = self.context
        
        for i in 0 ..< layout.count {
            if NSPointInRect(location, layout.frame(at: i)) {
                _message = layout.messages[i]
                break
            }
        }
        if let message = _message {
            return chatMenuItems(for: message, chatInteraction: self.chatInteraction)
        }
        
        guard let message = layout.messages.first else {
            return .single([])
        }
        
        var items: [ContextMenuItem] = []
        
        if canReplyMessage(message, peerId: chatInteraction.peerId, mode: chatInteraction.mode)  {
            items.append(ContextMenuItem(L10n.messageContextReply1, handler: { [weak chatInteraction] in
                chatInteraction?.setupReplyMessage(message.id)
            }))
        }
        
        if chatInteraction.mode == .scheduled, let peer = chatInteraction.peer {
            items.append(ContextMenuItem(L10n.chatContextScheduledSendNow, handler: {
                _ = sendScheduledMessageNowInteractively(postbox: context.account.postbox, messageId: message.id).start()
            }))
            items.append(ContextMenuItem(L10n.chatContextScheduledReschedule, handler: {
                showModal(with: ScheduledMessageModalController(context: context, defaultDate: Date(timeIntervalSince1970: TimeInterval(message.timestamp)), peerId: peer.id, scheduleAt: { date in
                    _ = showModalProgress(signal: requestEditMessage(account: context.account, messageId: message.id, text: message.text, media: .keep, scheduleTime: Int32(date.timeIntervalSince1970)), for: context.window).start()
                }), for: context.window)
            }))
            items.append(ContextSeparatorItem())
        }
        
        
        items.append(ContextMenuItem(tr(L10n.messageContextSelect), handler: { [weak self] in
            guard let `self` = self else {return}
            let messageIds = self.layout.messages.map{$0.id}
            self.chatInteraction.withToggledSelectedMessage({ current in
                var current = current
                for id in messageIds {
                    current = current.withToggledSelectedMessage(id)
                }
                return current
            })
        }))
        
        var canDelete = true
        for i in 0 ..< layout.count {
            if !canDeleteMessage(layout.messages[i], account: context.account, mode: chatInteraction.mode)  {
                canDelete = false
                break
            }
        }
        
        var canPin = true
        for i in 0 ..< layout.count {
            if let peer = peer {
                if !canPinMessage(layout.messages[i], for: peer, account: context.account)  {
                    canPin = false
                    break
                }
            }
        }
        
        let chatInteraction = self.chatInteraction
        let account = self.context.account
        
        if let peer = message.peers[message.id.peerId] as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)), chatInteraction.mode == .history {
            if !message.flags.contains(.Unsent) && !message.flags.contains(.Failed) {
                items.append(ContextMenuItem(tr(L10n.messageContextPin), handler: {
                    if peer.isSupergroup {
                        modernConfirm(for: mainWindow, account: account, peerId: nil, header: L10n.messageContextConfirmPin1, information: nil, thridTitle: L10n.messageContextConfirmNotifyPin, successHandler: { result in
                            chatInteraction.updatePinned(message.id, false, result != .thrid, false)
                        })
                    } else {
                        chatInteraction.updatePinned(message.id, false, true, false)
                    }
                }))
            }
        } else if message.id.peerId == account.peerId, chatInteraction.mode == .history {
            items.append(ContextMenuItem(L10n.messageContextPin, handler: {
                chatInteraction.updatePinned(message.id, false, true, false)
            }))
        } else if let peer = message.peers[message.id.peerId] as? TelegramGroup, peer.canPinMessage, chatInteraction.mode == .history {
            items.append(ContextMenuItem(L10n.messageContextPin, handler: {
                modernConfirm(for: mainWindow, account: account, peerId: nil, header: L10n.messageContextConfirmPin1, information: nil, thridTitle: L10n.messageContextConfirmNotifyPin, successHandler: { result in
                    chatInteraction.updatePinned(message.id, false, result == .thrid, false)
                })
            }))
        }

        
        if canDelete {
            items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: { [weak self] in
                guard let `self` = self else {return}
                self.chatInteraction.deleteMessages(self.layout.messages.map{$0.id})
            }))
        }
        
        if let message = layout.messages.first, let peer = peer, canReplyMessage(message, peerId: peer.id, mode: chatInteraction.mode) {
            items.append(ContextMenuItem(L10n.messageContextReply1, handler: { [weak self] in
                self?.chatInteraction.setupReplyMessage(message.id)
            }))
        }
        
        if let message = layout.messages.last, !message.flags.contains(.Failed), !message.flags.contains(.Unsent), chatInteraction.mode == .history {
            if let peer = message.peers[message.id.peerId] as? TelegramChannel {
                items.append(ContextMenuItem(L10n.messageContextCopyMessageLink1, handler: {
                    _ = showModalProgress(signal: exportMessageLink(account: context.account, peerId: peer.id, messageId: message.id), for: context.window).start(next: { link in
                        if let link = link {
                            copyToClipboard(link)
                        }
                    })
                }))
            }
        }
        
        var editMessage: Message? = nil
        for message in layout.messages {
            if let _ = editMessage, !message.text.isEmpty {
                editMessage = nil
                break
            }
            if !message.text.isEmpty {
                editMessage = message
            }
        }
        if let editMessage = editMessage {
            if canEditMessage(editMessage, context: context) {
                items.append(ContextMenuItem(tr(L10n.messageContextEdit), handler: { [weak self] in
                    self?.chatInteraction.beginEditingMessage(editMessage)
                }))
            }
        }
        var canForward: Bool = true
        for message in layout.messages {
            if !canForwardMessage(message, account: context.account) {
                canForward = false
                break
            }
        }
        
        if canForward {
            items.append(ContextMenuItem(tr(L10n.messageContextForward), handler: { [weak self] in
                guard let `self` = self else {return}
                self.chatInteraction.forwardMessages(self.layout.messages.map {$0.id})
            }))
        }
        
        return .single(items) |> map { [weak self] items in
            var items = items
            if let captionLayout = self?.captionLayouts.first(where: { $0.id == _message?.stableId}) {
                let text = captionLayout.layout.attributedString.string
                items.insert(ContextMenuItem(tr(L10n.textCopy), handler: {
                    copyToClipboard(text)
                }), at: 1)
                
//                if let view = self?.view as? ChatRowView, let textView = view.captionView, let window = textView.window {
//                    let point = textView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
//                    if let layout = textView.layout {
//                        if let (link, _, range, _) = layout.link(at: point) {
//                            var text:String = layout.attributedString.string.nsstring.substring(with: range)
//                            if let link = link as? inAppLink {
//                                if case let .external(link, _) = link {
//                                    text = link
//                                }
//                            }
//                            
//                            for i in 0 ..< items.count {
//                                if items[i].title == tr(L10n.messageContextCopyMessageLink1) {
//                                    items.remove(at: i)
//                                    break
//                                }
//                            }
//                            
//                            items.insert(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: {
//                                copyToClipboard(text)
//                            }), at: 1)
//                        }
//                    }
//                }
            }
            
            return items
        }
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatGroupedView.self
    }
    
}

class ChatGroupedView : ChatRowView , ModalPreviewRowViewProtocol {
    
    private(set) var contents: [ChatMediaContentView] = []
    private var selectionBackground: CornerView = CornerView()
    
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        guard let item = item as? ChatGroupedItem, let window = window as? Window else { return nil }
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i)) {
                let contentNode = contents[i]
                if contentNode is ChatGIFContentView {
                    if let file = contentNode.media as? TelegramMediaFile {
                        let reference = contentNode.parent != nil ? FileMediaReference.message(message: MessageReference(contentNode.parent!), media: file) : FileMediaReference.standalone(media: file)
                        return (.file(reference, GifPreviewModalView.self), contentNode)
                    }
                } else if contentNode is ChatInteractiveContentView {
                    if let image = contentNode.media as? TelegramMediaImage {
                        let reference = contentNode.parent != nil ? ImageMediaReference.message(message: MessageReference(contentNode.parent!), media: image) : ImageMediaReference.standalone(media: image)
                        return (.image(reference, ImagePreviewModalView.self), contentNode)
                    }
                }
            }
        }
        
        return nil
    }
    
    override func forceClick(in location: NSPoint) {
        if previewMediaIfPossible() {
            
        } else {
            super.forceClick(in: location)
        }
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let item = item as? ChatGroupedItem, let window = window as? Window else { return false }
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        if contentView.mouseInside() {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i)) {
                    let result = contents[i].previewMediaIfPossible()
                    return result
                }
            }
        }
        return false
    }

    override func updateColors() {
        super.updateColors()
    }
    
    override func notify(with value: Any, oldValue: Any, animated: Bool) {
        super.notify(with: value, oldValue: oldValue, animated: animated)
    }
    
    override func canDropSelection(in location: NSPoint) -> Bool {
        let point = self.convert(location, from: nil)
        return true//!NSPointInRect(point, contentView.frame)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func updateMouse() {
        super.updateMouse()
        for content in contents {
            content.updateMouse()
        }
    }
    
    
    private func selectedIcon(_ item: ChatGroupedItem) -> CGImage {
        return theme.icons.chatGroupToggleSelected
    }
    
    private func unselectedIcon(_ item: ChatGroupedItem) -> CGImage {
        //theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected
        switch item.layout.type {
        case .files:
            return item.isBubbled ? (item.isIncoming ? theme.icons.group_selection_foreground_bubble_incoming : theme.icons.group_selection_foreground_bubble_outgoing) : theme.icons.group_selection_foreground
        case .photoOrVideo:
            return theme.icons.chatGroupToggleSelected
        }
    }
    
    override func updateSelectingState(_ animated: Bool, selectingMode: Bool, item: ChatRowItem?, needUpdateColors: Bool) {
        
        
        if let item = item as? ChatGroupedItem {
            
            if selectingMode {
                if contents.count > 1 {
                    for content in contents {
                        let subviews = content.subviews
                        var selectingControl: SelectingControl?
                        for subview in subviews {
                            if subview is SelectingControl {
                                selectingControl = subview as? SelectingControl
                                break
                            }
                        }
                        if selectingControl == nil {
                            selectingControl = SelectingControl(unselectedImage: unselectedIcon(item), selectedImage: selectedIcon(item))
                            content.addSubview(selectingControl!)
                            if animated {
                                selectingControl?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                                selectingControl?.layer?.animateScaleSpring(from: 0.2, to: 1.0, duration: 0.2)
                            }
                        }
                        if let selectingControl = selectingControl {
                            selectingControl.setFrameOrigin(selectionOrigin(content))
                        }
                    }
                }
            } else {
                for content in contents {
                    let subviews = content.subviews
                    for subview in subviews {
                        if subview is SelectingControl {
                            if animated {
                                subview.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false)
                                subview.layer?.animateScaleSpring(from: 1, to: 0.2, duration: 0.2, removeOnCompletion: false, completion: { [weak subview] completed in
                                    subview?.removeFromSuperview()
                                })
                            } else {
                                subview.removeFromSuperview()
                            }
                        }
                    }
                }
            }
            if let selectionState = item.chatInteraction.presentation.selectionState {
                for i in 0 ..< contents.count {
                    loop: for subview in contents[i].subviews {
                        if let select = subview as? SelectingControl {
                            select.set(selected: selectionState.selectedIds.contains(item.layout.messages[i].id), animated: animated)
                            break loop
                        }
                    }
                }
            }
        }
        super.updateSelectingState(animated, selectingMode: selectingMode, item: item, needUpdateColors: needUpdateColors)
    }
    
    override func updateSelectionViewAfterUpdateState(item: ChatRowItem, animated: Bool) {
        guard let item = item as? ChatGroupedItem else {return}
        guard let selectingView = selectingView  else {return}

        

        var selected: Bool = true
        for message in item.layout.messages {
            if !item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                selected = false
                break
            }
        }
        selectingView.set(selected: selected, animated: animated)
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        
        guard let item = item as? ChatGroupedItem else {return}
        

        
        if contents.count > item.layout.count {
            let contentCount = contents.count
            let layoutCount = item.layout.count
            
            for i in layoutCount ..< contentCount {
                contents[i].removeFromSuperview()
            }
            contents = contents.subarray(with: NSMakeRange(0, layoutCount))
        } else if contents.count < item.layout.count {
            let contentCount = contents.count
            for i in contentCount ..< item.layout.count {
                let node = item.contentNode(for: i)
                let view = node.init(frame:NSZeroRect)
                contents.append(view)
            }
        }
        
        for i in 0 ..< contents.count {
            if contents[i].className != item.contentNode(for: i).className()  {
                let node = item.contentNode(for: i)
                let view = node.init(frame:NSZeroRect)
                contents[i] = view
            }
        }
        
        self.contentView.removeAllSubviews()
        
        for content in contents {
            addSubview(content)
        }
        
        super.set(item: item, animated: animated)

        assert(contents.count == item.layout.count)
        
        let approximateSynchronousValue = item.approximateSynchronousValue
        
        contentView.frame = self.contentFrame(item)
        
        var offset: CGFloat = 0
        
        for i in 0 ..< item.layout.count {
            contents[i].change(size: item.layout.frame(at: i).size, animated: animated)
            var positionFlags: LayoutPositionFlags = item.isBubbled ? item.positionFlags ?? item.layout.position(at: i) : []

            if item.hasBubble  {
                if item.captionLayouts.first(where: { $0.id == item.lastMessage?.stableId }) != nil || item.commentsBubbleData != nil {
                    positionFlags.remove(.bottom)
                }
                if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                    positionFlags.remove(.top)
                }
            }

            
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, context: item.context, parent: item.layout.messages[i], table: item.table, parameters: item.parameters[i], animated: animated, positionFlags: positionFlags, approximateSynchronousValue: approximateSynchronousValue)
            
            contents[i].change(pos: item.layout.frame(at: i).origin.offsetBy(dx: 0, dy: offset), animated: animated)
            
        }

        needsLayout = true
    }

    override var needsDisplay: Bool {
        get {
            return super.needsDisplay
        }
        set {
            super.needsDisplay = newValue
            for content in contents {
                content.needsDisplay = newValue
            }
        }
    }
    override var backgroundColor: NSColor {
        didSet {
            for content in contents {
                content.backgroundColor = backdorColor
            }
        }
    }
    
    
    override func toggleSelected(_ select: Bool, in point: NSPoint) {
        guard let item = item as? ChatGroupedItem else { return }
        
        let location = contentView.convert(point, from: nil)
        var applied: Bool = contentView.mouseInside()
        if contentView.mouseInside() {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i)) {
                    let id = item.layout.messages[i].id
                    item.chatInteraction.withToggledSelectedMessage({ current in
                        if (select && !current.isSelectedMessageId(id)) || (!select && current.isSelectedMessageId(id)) {
                            return current.withToggledSelectedMessage(id)
                        }
                        return current
                    })
                    applied = true
                    break
                }
            }
        }
        
        if !applied {
            item.chatInteraction.withToggledSelectedMessage({ current in
                return item.layout.messages.reduce(current, { current, message -> ChatPresentationInterfaceState in
                    if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                        return current.withToggledSelectedMessage(message.id)
                    }
                    return current
                })
            })
        }
        
    }
    
    
    
    override func forceSelectItem(_ item: ChatRowItem, onRightClick: Bool) {
        
        guard let item = item as? ChatGroupedItem else {return}
        guard let window = window as? Window else {return}

        if onRightClick {
            item.chatInteraction.withToggledSelectedMessage({ current in
                var current: ChatPresentationInterfaceState = current
                for message in item.layout.messages {
                    current = current.withToggledSelectedMessage(message.id)
                }
                return current
            })
            return
        }
        
        guard item.chatInteraction.presentation.state == .selecting else {return}
        
        let location = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var selected: Bool = contentView.mouseInside()
        if contentView.mouseInside() {
            for i in 0 ..< item.layout.count {
                if NSPointInRect(location, item.layout.frame(at: i)) {
                    item.chatInteraction.withToggledSelectedMessage({
                        $0.withToggledSelectedMessage(item.layout.messages[i].id)
                    })
                    selected = true
                    break
                }
            }
        }
        

        if !selected {
            let select = !isHasSelectedItem
            item.chatInteraction.withToggledSelectedMessage({ current in
                return item.layout.messages.reduce(current, { current, message -> ChatPresentationInterfaceState in
                    if (select && !current.isSelectedMessageId(message.id)) || (!select && current.isSelectedMessageId(message.id)) {
                        return current.withToggledSelectedMessage(message.id)
                    }
                    return current
                })
            })
        }
        
    }
    
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        if newSuperview == nil {
            for content in contents {
                content.willRemove()
            }
        }
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        
        if let innerId = innerId.base as? ChatHistoryEntryId {
            switch innerId {
            case .message(let message):
                for content in contents {
                    if content.parent?.id == message.id {
                        return content.interactionContentView(for: innerId, animateIn: animateIn)
                    }
                }
            default:
                break
            }
        }
        
        return super.interactionContentView(for: innerId, animateIn: animateIn)
    }
    
    override func interactionControllerDidFinishAnimation(interactive: Bool, innerId: AnyHashable) {

    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        
        guard let item = item as? ChatRowItem else {return}
        if let innerId = innerId.base as? ChatHistoryEntryId {
            switch innerId {
            case .message(let message):
                for content in contents {
                    if content.parent?.id == message.id {
                        let rect = rightView.convert(rightView.bounds, to: content.superview)
                        if NSIntersectsRect(rect, content.frame), item.isStateOverlayLayout {
                            let rightView = ChatRightView(frame: NSZeroRect)
                            rightView.set(item: item, animated: false)
                            var rect = self.rightView.convert(self.rightView.bounds, to: content)
                            
                            if content.visibleRect.minY < rect.midY && content.visibleRect.minY + content.visibleRect.height > rect.midY {
                                rect.origin.y = content.frame.height - rect.maxY
                                rightView.frame = rect
                                view.addSubview(rightView)
                            }
                           
                        }
                        content.addAccesoryOnCopiedView(view: view)

                    }
                }
            default:
                break
            }
        }
        
        
    }
    
    
    override func isSelectInGroup(_ location: NSPoint) -> Bool {
        guard let item = item as? ChatGroupedItem else {return false}
        
        guard item.chatInteraction.presentation.state == .selecting else {return false}
        
        let location = contentView.convert(location, from: nil)
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i)) {
                return item.chatInteraction.presentation.isSelectedMessageId(item.layout.messages[i].id)
            }
        }
        return false
    }
    
    private var isHasSelectedItem: Bool {
        guard let item = item as? ChatGroupedItem else {
            return false
        }
        for message in item.layout.messages {
            if item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                return true
            }
        }
        return false
    }
    
    override var backdorColor: NSColor {
        guard let item = item as? ChatGroupedItem, !item.isBubbled else {
            return super.backdorColor
        }
        
        
        if let _ = contextMenu {
            return theme.colors.selectMessage
        }

        
        for message in item.layout.messages {
            if item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                return theme.colors.selectMessage
            }
        }
        
        return super.backdorColor
    }
    
    
    private func highlightFrameAndColor(_ item: ChatGroupedItem, at index: Int) -> (color: NSColor, frame: NSRect, flags: LayoutPositionFlags, superview: NSView) {
        switch item.layout.type {
        case .photoOrVideo:
            return (color: NSColor.black.withAlphaComponent(0.4), frame: item.layout.frame(at: index), flags: item.isBubbled ? item.positionFlags ?? item.layout.position(at: index) : [], superview: self.contentView)
        case .files:
            var frame = item.layout.frame(at: index)
            let contentFrame = self.contentFrame(item)
            let bubbleFrame = self.bubbleFrame(item)
            if item.hasBubble {
                
                frame.origin.x = 0
                frame.size.width = bubbleFrame.width
                
                var caption: CGFloat = 0
                
                if let layout = item.captionLayouts.first(where: { $0.id == item.layout.messages[index].stableId })  {
                    caption = layout.layout.layoutSize.height + 6
                }
                
                
                frame.size.height += 8
                if index == 0 {
                    frame.size.height += contentFrame.minY
                } else if index == item.layout.count - 1 {
                    frame.origin.y += contentFrame.minY
                    frame.size.height += contentFrame.minY
                } else {
                    frame.origin.y += contentFrame.minY
                }
                
                frame.size.height += caption

                
                frame.origin.y = bubbleFrame.height - frame.maxY + 6
                
                return (item.isIncoming ? theme.colors.bubbleBackground_incoming.darker().withAlphaComponent(0.5) : theme.colors.bubbleBackgroundTop_outgoing.darker().withAlphaComponent(0.5)
                    , frame: frame, flags: [], superview: self.bubbleView)
            } else {
                
                frame.origin.x = 0
                frame.size.width = self.frame.width
                frame.size.height += 8
                if index == 0 {
                    frame.size.height += contentFrame.minY
                } else if index == item.layout.count - 1 {
                    frame.origin.y += contentFrame.minY
                    if item.captionLayouts.first(where: { $0.id == item.lastMessage?.stableId }) == nil {
                        frame.size.height += contentFrame.minY
                    }
                }
                frame.origin.y -= 4
                
                return (color: theme.colors.accentIcon.withAlphaComponent(0.15), frame: frame, flags: [], superview: self.rowView)
            }
        }
    }
    
    override func focusAnimation(_ innerId: AnyHashable?) {
        if let innerId = innerId {
            guard let item = item as? ChatGroupedItem else {return}

            for i in 0 ..< item.layout.count {
                if AnyHashable(ChatHistoryEntryId.message(item.layout.messages[i])) == innerId {
                    
                    let data = highlightFrameAndColor(item, at: i)
                    
                    selectionBackground.removeFromSuperview()
                    selectionBackground.frame = data.frame
                    selectionBackground.backgroundColor = data.color
                    
                    var positionFlags: LayoutPositionFlags = data.flags
                    
                    if item.hasBubble  {
                        if item.captionLayouts.first(where: { $0.id == item.lastMessage?.stableId }) == nil {
                            positionFlags.remove(.bottom)
                        }
                        if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                            positionFlags.remove(.top)
                        }
                    }
                    selectionBackground.layer?.opacity = 0

                    selectionBackground.positionFlags = positionFlags
                    data.superview.addSubview(selectionBackground)
                    
                    let animation: CABasicAnimation = makeSpringAnimation("opacity")
                    
                    animation.fromValue = selectionBackground.layer?.presentation()?.opacity ?? 0
                    animation.toValue = 1.0
                    animation.autoreverses = true
                    animation.isRemovedOnCompletion = true
                    animation.fillMode = .forwards
                    animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
                        self?.selectionBackground.removeFromSuperview()
                    })
                    animation.isAdditive = false
                    
                    selectionBackground.layer?.add(animation, forKey: "opacity")
                    
                    break
                }
            }
        } else {
            super.focusAnimation(innerId)
        }
    }
    
    
    override func onShowContextMenu() {
        guard let window = window as? Window else {return}
        guard let item = item as? ChatGroupedItem else {return}
        
        let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var selected: Bool = false
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i)) {
                
                let data = highlightFrameAndColor(item, at: i)
                selectionBackground.removeFromSuperview()
                selectionBackground.layer?.opacity = 1.0
                selectionBackground.frame = data.frame
                selectionBackground.backgroundColor = data.color
                var positionFlags: LayoutPositionFlags = data.flags
                
                if item.hasBubble  {
                    if item.captionLayouts.first(where: { $0.id == item.lastMessage?.stableId }) != nil {
                        positionFlags.remove(.bottom)
                    }
                    if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                        positionFlags.remove(.top)
                    }
                }
                
                selectionBackground.positionFlags = positionFlags
                data.superview.addSubview(selectionBackground)
                selected = true
                break
            }
        }
        
        if !selected {
            super.onShowContextMenu()
        }
    }
    
    override func onCloseContextMenu() {
        super.onCloseContextMenu()
        selectionBackground.removeFromSuperview()
    }
    
    override func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        let point = contentView.convert(location, from: nil)
        for content in contents {
            if NSPointInRect(point, content.frame) {
                return false
            }
        }
        return true
    }
    
    override func contentFrame(_ item: ChatRowItem) -> NSRect {
        var rect = super.contentFrame(item)
        guard let item = item as? ChatGroupedItem else {
            return rect
        }
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        
        return rect
    }
    
    func selectionOrigin(_ content: ChatMediaContentView) -> CGPoint {
        guard let item = item as? ChatGroupedItem else {return .zero}

        switch item.layout.type {
        case .files:
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    if content is ChatAudioContentView {
                        return NSMakePoint(26, 18)
                    } else if let content = content as? ChatFileContentView {
                        if content.isHasThumb {
                            return NSMakePoint(40, 6)
                        } else {
                            return NSMakePoint(26, 18)
                        }
                    }
                }
            }
        case .photoOrVideo:
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    return NSMakePoint(content.frame.width - subview.frame.width - 5, 5)
                }
            }
        }
        return .zero
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ChatGroupedItem else {return}

        assert(contents.count == item.layout.count)
        
        for i in 0 ..< item.layout.count {
            contents[i].setFrameOrigin(item.layout.frame(at: i).origin)
        }
        
        for content in contents {
            let subviews = content.subviews
            for subview in subviews {
                if subview is SelectingControl {
                    subview.setFrameOrigin(selectionOrigin(content))
                    break
                }
            }
        }
        
    }
    
}
