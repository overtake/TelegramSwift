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

    fileprivate let layout: GroupedLayout
    override init(_ initialSize: NSSize, _ chatInteraction: ChatInteraction, _ account: Account, _ entry: ChatHistoryEntry) {
        
        var captionLayout: TextViewLayout?
        
        if case let .groupedPhotos(messages, _) = entry {
            
            let messages = messages.map{$0.message!}
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
                var caption:NSMutableAttributedString = NSMutableAttributedString()
                NSAttributedString.initialize()
                _ = caption.append(string: message.text, color: theme.colors.text, font: NSFont.normal(.custom(theme.fontSize)))
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
                    caption = ChatMessageItem.applyMessageEntities(with: message.attributes, for: message.text.fixed, account:account, fontSize: theme.fontSize, openInfo:chatInteraction.openInfo, botCommand:chatInteraction.forceSendMessage, hashtag:chatInteraction.modalSearch, applyProxy: chatInteraction.applyProxy).mutableCopy() as! NSMutableAttributedString
                }
                caption.detectLinks(type: types, account: account, openInfo:chatInteraction.openInfo, hashtag: chatInteraction.modalSearch, command: chatInteraction.forceSendMessage)
                captionLayout = TextViewLayout(caption, alignment: .left)
                captionLayout?.interactions = globalLinkExecutor
                
            }
            
        } else {
            fatalError("")
        }
        
        super.init(initialSize, chatInteraction, account, entry)
        
        self.captionLayout = captionLayout
    }
    
    override func makeContentSize(_ width: CGFloat) -> NSSize {
        layout.measure(NSMakeSize(min(width, 320), min(width, 320)))
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
        if let message = message, let peer = peer {
            return chatMenuItems(for: message, account: account, chatInteraction: chatInteraction, peer: peer)
        }
        
        var items: [ContextMenuItem] = []
        
        items.append(ContextMenuItem(tr(.messageContextSelect), handler: { [weak self] in
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
            items.append(ContextMenuItem(tr(.messageContextDelete), handler: { [weak self] in
                guard let `self` = self else {return}
                self.chatInteraction.deleteMessages(self.layout.messages.map{$0.id})
            }))
        }
        
        return .single(items)
    }
    
    override func viewClass() -> AnyClass {
        return ChatGroupedView.self
    }
    
}

private class ChatGroupedView : ChatRowView {
    
    private var contents: [ChatMediaContentView] = []
    private var selectionBackground: View = View()
    

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
        return !NSPointInRect(point, contentView.frame)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        
    }
    
    override func updateSelectingState(_ animated: Bool, selectingMode: Bool, item: ChatRowItem?) {
        
        
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
        super.updateSelectingState(animated, selectingMode: selectingMode, item: item)
    }
    
    override func updateSelectionViewAfterUpdateState(animated: Bool) {
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
            
            contents[i].update(with: item.layout.messages[i].media[0], size: item.layout.frame(at: i).size, account: item.account, parent: item.layout.messages[i], table: item.table, positionFlags: item.layout.position(at: i))
            
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
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i)) {
                let id = item.layout.messages[i].id
                item.chatInteraction.update({ current in
                    if (select && !current.isSelectedMessageId(id)) || (!select && current.isSelectedMessageId(id)) {
                        return current.withToggledSelectedMessage(id)
                    }
                    return current
                })
                break
            }
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
        
        var selected: Bool = false
        for i in 0 ..< item.layout.count {
            if NSPointInRect(location, item.layout.frame(at: i)) {
                item.chatInteraction.update({
                    $0.withToggledSelectedMessage(item.layout.messages[i].id)
                })
                selected = true
                break
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
    
    override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        
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
        
        return super.interactionContentView(for: innerId)
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
        
        if let _ = contextMenu {
            return theme.colors.selectMessage
        }
        guard let item = item as? ChatGroupedItem else {
            return theme.colors.background
        }
        
        for message in item.layout.messages {
            if item.chatInteraction.presentation.isSelectedMessageId(message.id) {
                return theme.colors.selectMessage
            }
        }
        
        return theme.colors.background
    }
    
    
    
    override func onShowContextMenu() {
        guard let window = window as? Window else {return}
        guard let item = item as? ChatGroupedItem else {return}
        
        let point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        var selected: Bool = false
        
        for i in 0 ..< item.layout.count {
            if NSPointInRect(point, item.layout.frame(at: i)) {
                selectionBackground.removeFromSuperview()
                selectionBackground.setFrameSize(item.layout.frame(at: i).size)
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
        return false
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
