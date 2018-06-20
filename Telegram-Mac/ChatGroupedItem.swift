//
//  ChatGroupedItem.swift
//  Telegram
//
//  Created by keepcoder on 31/10/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

class ChatGroupedItem: ChatRowItem {

    fileprivate var parameters: ChatMediaGalleryParameters?
    fileprivate let layout: GroupedLayout
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ entry: ChatHistoryEntry, _ downloadSettings: AutomaticMediaDownloadSettings) {
        
        var captionLayout: TextViewLayout?
        
        if case let .groupedPhotos(messages, _) = entry {
            
            let messages = messages.map{$0.message!}.filter({!$0.media.isEmpty})
            self.layout = GroupedLayout(messages)
            
            var captionMessage: Message? = nil
            for message in messages {
                if let _ = captionMessage, !message.text.isEmpty {
                    captionMessage = nil
                    break
                }
                if !message.text.isEmpty {
                    captionMessage = message
                }
            }
            
            if let message = captionMessage {
                
                let isIncoming: Bool = message.isIncoming(account, entry.renderType == .bubble)

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
                    caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.sendPlainText, hashtag: account.context.globalSearch ?? {_ in }, applyProxy: chatInteraction.applyProxy, textColor: theme.chat.textColor(isIncoming, entry.renderType == .bubble), linkColor: theme.chat.linkColor(isIncoming, entry.renderType == .bubble)).mutableCopy() as! NSMutableAttributedString
                }
                
                
                caption.detectLinks(type: types, account: account, color: theme.chat.linkColor(isIncoming, entry.renderType == .bubble), openInfo:chatInteraction.openInfo, hashtag: account.context.globalSearch ?? {_ in }, command: chatInteraction.sendPlainText, applyProxy: chatInteraction.applyProxy)
                captionLayout = TextViewLayout(caption, alignment: .left, selectText: theme.chat.selectText(isIncoming, entry.renderType == .bubble), strokeLinks: entry.renderType == .bubble, alwaysStaticItems: true)
                captionLayout?.interactions = globalLinkExecutor
                
            }
            
        } else {
            fatalError("")
        }
        
        super.init(initialSize, chatInteraction, account, entry, downloadSettings)
        
         self.captionLayout = captionLayout
        
        guard let message = message else {return}
        
        self.parameters = ChatMediaGalleryParameters(showMedia: { [weak self] message in
            guard let `self` = self else {return}
            
            var type:GalleryAppearType = .history
            if let parameters = self.parameters, parameters.isWebpage {
                type = .alone
            } else if message.containsSecretMedia {
                type = .secret
            }
            showChatGallery(account: account, message: message, self.table, self.parameters, type: type)
            
        }, showMessage: { [weak self] message in
                self?.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: true, focus: true, inset: 0))
        }, isWebpage: chatInteraction.isLogInteraction, presentation: .make(for: message, account: account, renderType: entry.renderType), media: message.media.first!, automaticDownload: downloadSettings.isDownloable(message))
        
        self.parameters?.automaticDownloadFunc = { message in
            return downloadSettings.isDownloable(message)
        }
        
        if isBubbleFullFilled, layout.messages.count == 1  {
            var positionFlags: GroupLayoutPositionFlags = []
            if captionLayout == nil {
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
    }
    
    override func share() {
        if let message = message {
            showModal(with: ShareModalController(ShareMessageObject(account, message, layout.messages)), for: mainWindow)
        }

    }
    
    override var hasBubble: Bool {
        return isBubbled && (captionLayout != nil || message?.replyAttribute != nil || forwardNameLayout != nil || layout.messages.count == 1)
    }
    
    override var isBubbleFullFilled: Bool {
        return isBubbled
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
    
    fileprivate var positionFlags: GroupLayoutPositionFlags?
    
    override var contentOffset: NSPoint {
        var offset = super.contentOffset
        //
        if hasBubble {
            if  forwardNameLayout != nil {
                offset.y += defaultContentInnerInset
            } else if authorText == nil, !isBubbleFullFilled  {
                offset.y += (defaultContentInnerInset + 2)
            }
        }
        
        if hasBubble && authorText == nil && replyModel == nil && forwardNameLayout == nil {
            offset.y -= (defaultContentInnerInset + self.mediaBubbleCornerInset * 2 - 1)
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
        if hasBubble && isBubbleFullFilled && captionLayout == nil {
            return contentOffset.y + defaultContentInnerInset - mediaBubbleCornerInset * 2
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
        if let caption = captionLayout {
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
        layout.measure(NSMakeSize(min(width, 320), min(width, 320)), spacing: hasBubble ? 2 : 4)
        return layout.dimensions
    }
    
    override var topInset:CGFloat {
        return 4
    }
    
    func contentNode(for index: Int) -> ChatMediaContentView.Type {
        return ChatLayoutUtils.contentNode(for: layout.messages[index].media[0])
    }

    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        var message: Message? = nil
        for i in 0 ..< layout.count {
            if NSPointInRect(location, layout.frame(at: i)) {
                message = layout.messages[i]
                break
            }
        }
        if let message = message {
            return chatMenuItems(for: message, account: account, chatInteraction: chatInteraction)
        }
        
        var items: [ContextMenuItem] = []
        
        items.append(ContextMenuItem(tr(L10n.messageContextSelect), handler: { [weak self] in
            guard let `self` = self else {return}
            let messageIds = self.layout.messages.map{$0.id}
            self.chatInteraction.update({ current in
                var current = current
                for id in messageIds {
                    current = current.withToggledSelectedMessage(id)
                }
                return current
            })
        }))
        
        var canDelete = true
        for i in 0 ..< layout.count {
            if !canDeleteMessage(layout.messages[i], account: account)  {
                canDelete = false
                break
            }
        }
        
        if canDelete {
            items.append(ContextMenuItem(tr(L10n.messageContextDelete), handler: { [weak self] in
                guard let `self` = self else {return}
                self.chatInteraction.deleteMessages(self.layout.messages.map{$0.id})
            }))
        }
        
        if let message = layout.messages.first, let peer = peer, peer.canSendMessage, chatInteraction.peerId == message.id.peerId {
            items.append(ContextMenuItem(tr(L10n.messageContextReply1) + (FastSettings.tooltipAbility(for: .edit) ? " (\(tr(L10n.messageContextReplyHelp)))" : ""), handler: { [weak self] in
                self?.chatInteraction.setupReplyMessage(message.id)
            }))
        }
        
        if let message = layout.messages.last {
            if let peer = message.peers[message.id.peerId] as? TelegramChannel, let address = peer.addressName {
                
                items.append(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: {
                    copyToClipboard("t.me/\(address)/\(message.id.id)")
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
            if canEditMessage(editMessage, account:account) {
                items.append(ContextMenuItem(tr(L10n.messageContextEdit), handler: { [weak self] in
                    self?.chatInteraction.beginEditingMessage(editMessage)
                }))
            }
        }
        var canForward: Bool = true
        for message in layout.messages {
            if !canForwardMessage(message, account: account) {
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
            if let captionLayout = self?.captionLayout {
                let text = captionLayout.attributedString.string
                items.insert(ContextMenuItem(tr(L10n.textCopy), handler: {
                    copyToClipboard(text)
                }), at: 1)
                
                if let view = self?.view as? ChatRowView, let textView = view.captionView, let window = textView.window {
                    let point = textView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    if let layout = textView.layout {
                        if let (link, _, range, _) = layout.link(at: point) {
                            var text:String = layout.attributedString.string.nsstring.substring(with: range)
                            if let link = link as? inAppLink {
                                if case let .external(link, _) = link {
                                    text = link
                                }
                            }
                            
                            for i in 0 ..< items.count {
                                if items[i].title == tr(L10n.messageContextCopyMessageLink1) {
                                    items.remove(at: i)
                                    break
                                }
                            }
                            
                            items.insert(ContextMenuItem(tr(L10n.messageContextCopyMessageLink1), handler: {
                                copyToClipboard(text)
                            }), at: 1)
                        }
                    }
                }
            }
            
            return items
        }
    }
    
    override func viewClass() -> AnyClass {
        return ChatGroupedView.self
    }
    
}

private class ChatGroupedView : ChatRowView {
    
    private var contents: [ChatMediaContentView] = []
    private var selectionBackground: CornerView = CornerView()
    

    override func updateColors() {
        super.updateColors()
        selectionBackground.layer?.cornerRadius = .cornerRadius
        selectionBackground.background = theme.colors.blackTransparent
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
                            selectingControl = SelectingControl(unselectedImage: theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected)
                        }
                        selectingControl?.setFrameOrigin(5, 5)
                        content.addSubview(selectingControl!)
                    }
                }
            } else {
                for content in contents {
                    let subviews = content.subviews
                    for subview in subviews {
                        if subview is SelectingControl {
                            subview.removeFromSuperview()
                            break
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
            
            for i in 0 ..< contents.count {
                if !contents[i].isKind(of: item.contentNode(for: i))  {
                    let node = item.contentNode(for: i)
                    let view = node.init(frame:NSZeroRect)
                    replaceSubview(contents[i], with: view)
                    contents[i] = view
                }
            }
        } else if contents.count < item.layout.count {
            let contentCount = contents.count
            for i in contentCount ..< item.layout.count {
                let node = item.contentNode(for: i)
                let view = node.init(frame:NSZeroRect)
                //view.progressDimension = NSMakeSize(20, 20)
                contents.append(view)
            }
        }
        
        for content in contents {
            addSubview(content)
        }
        
        assert(contents.count == item.layout.count)
        
        for i in 0 ..< item.layout.count {
            contents[i].change(size: item.layout.frame(at: i).size, animated: animated)
            var positionFlags: GroupLayoutPositionFlags = item.isBubbled ? item.positionFlags ?? item.layout.position(at: i) : []

            if item.hasBubble  {
                if item.captionLayout != nil {
                    positionFlags.remove(.bottom)
                }
                if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                    positionFlags.remove(.top)
                }
            }

            
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, account: item.account, parent: item.layout.messages[i], table: item.table, parameters: item.parameters, animated: animated, positionFlags: positionFlags)
            
            contents[i].change(pos: item.layout.frame(at: i).origin, animated: animated)
        }
        super.set(item: item, animated: animated)

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
                    item.chatInteraction.update({ current in
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
            item.chatInteraction.update({ current in
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
            item.chatInteraction.update({ current in
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
                    item.chatInteraction.update({
                        $0.withToggledSelectedMessage(item.layout.messages[i].id)
                    })
                    selected = true
                    break
                }
            }
        }
        

        if !selected {
            let select = !isHasSelectedItem
            item.chatInteraction.update({ current in
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
                        return content
                    }
                }
            default:
                break
            }
        }
        
        return super.interactionContentView(for: innerId, animateIn: animateIn)
    }
    
    override func interactionControllerDidFinishAnimation(interactive: Bool, innerId: AnyHashable) {
        guard let item = item as? ChatRowItem else {return}
//        if let innerId = innerId.base as? ChatHistoryEntryId, interactive {
//            switch innerId {
//            case .message(let message):
//                for content in contents {
//                    if content.parent?.id == message.id {
//                        content.interactionControllerDidFinishAnimation(interactive: interactive)
//                        let rect = rightView.convert(rightView.bounds, to: content.superview)
//                        if NSIntersectsRect(rect, content.frame), item.isStateOverlayLayout {
//                            animateInStateView()
//                        }
//                    }
//                }
//            default:
//                break
//            }
//        }
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
    
    override func focusAnimation(_ innerId: AnyHashable?) {
        if let innerId = innerId {
            guard let item = item as? ChatGroupedItem else {return}

            for i in 0 ..< item.layout.count {
                if AnyHashable(ChatHistoryEntryId.message(item.layout.messages[i])) == innerId {
                    selectionBackground.removeFromSuperview()
                    selectionBackground.setFrameSize(item.layout.frame(at: i).size)
                    
                    var positionFlags: GroupLayoutPositionFlags = item.isBubbled ? item.positionFlags ?? item.layout.position(at: i) : []
                    
                    if item.hasBubble  {
                        if item.captionLayout != nil {
                            positionFlags.remove(.bottom)
                        }
                        if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                            positionFlags.remove(.top)
                        }
                    }
                    selectionBackground.layer?.opacity = 0

                    selectionBackground.positionFlags = positionFlags
                    contents[i].addSubview(selectionBackground)
                    
                    let animation: CABasicAnimation = makeSpringAnimation("opacity")
                    
                    animation.fromValue = selectionBackground.layer?.presentation()?.opacity ?? 0
                    animation.toValue = 1.0
                    animation.autoreverses = true
                    animation.isRemovedOnCompletion = true
                    animation.fillMode = kCAFillModeForwards
                    
                    animation.delegate = CALayerAnimationDelegate(completion: { [weak self] completed in
                        if completed {
                            self?.selectionBackground.removeFromSuperview()
                        }
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
                selectionBackground.removeFromSuperview()
                selectionBackground.layer?.opacity = 1.0
                selectionBackground.setFrameSize(item.layout.frame(at: i).size)
                
                var positionFlags: GroupLayoutPositionFlags = item.isBubbled ? item.positionFlags ?? item.layout.position(at: i) : []
                
                if item.hasBubble  {
                    if item.captionLayout != nil {
                        positionFlags.remove(.bottom)
                    }
                    if item.authorText != nil || item.replyModel != nil || item.forwardNameLayout != nil {
                        positionFlags.remove(.top)
                    }
                }
                
                selectionBackground.positionFlags = positionFlags
                contents[i].addSubview(selectionBackground)
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
    
    override var contentFrame: NSRect {
        var rect = super.contentFrame
        
        guard let item = item as? ChatGroupedItem else { return rect }
        
        if item.isBubbled, item.isBubbleFullFilled {
            rect.origin.x -= item.bubbleContentInset
            if item.hasBubble {
                rect.origin.x += item.mediaBubbleCornerInset
            }
        }
        
        return rect
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
                    subview.setFrameOrigin(5, 5)
                    break
                }
            }
        }
        
    }
    
}
