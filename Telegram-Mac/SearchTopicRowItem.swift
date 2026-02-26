//
//  SearchTopicRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 14.10.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import TelegramMedia

final class SearchTopicRowItem: GeneralRowItem {
    let item: EngineChatList.Item
    fileprivate let context: AccountContext
    fileprivate let nameLayout: TextViewLayout
    fileprivate let nameSelectedLayout: TextViewLayout
    fileprivate let presentation: TelegramPresentationTheme?
    init(_ initialSize: NSSize, stableId: AnyHashable, item: EngineChatList.Item, context: AccountContext, action: @escaping()->Void = {}, presentation: TelegramPresentationTheme? = nil) {
        self.item = item
        self.context = context
        self.presentation = presentation
        
        let theme = presentation ?? theme
        
        let title = item.threadData?.info.title ?? item.renderedPeer.chatOrMonoforumMainPeer?._asPeer().displayTitle
        
        self.nameLayout = .init(.initialize(string: title, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.nameSelectedLayout = .init(.initialize(string: title, color: theme.colors.underSelectedColor, font: .medium(.text)), maximumNumberOfLines: 1)
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: .legacy, action: action, border: [.Bottom])
        _ = makeSize(initialSize.width)
    }
    
    var threadId: Int64? {
        switch item.id {
        case let .forum(threadId):
            return threadId
        case let .chatList(peerId):
            return peerId.toInt64()
        }
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.nameLayout.measure(width: width - 50 - 10)
        self.nameSelectedLayout.measure(width: width - 50 - 10)

        return true
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
    
    override func viewClass() -> AnyClass {
        return SearchTopicRowView.self
    }
}

private class SearchTopicRowView : TableRowView {
    private var inlineTopicPhotoLayer: InlineStickerItemLayer?
    private var avatarControl: AvatarControl?
    private let nameView = TextView()
    private let borderView = View()
    private let containerView = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        self.addSubview(nameView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        self.addSubview(borderView)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededDown()
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            self?.invokeIfNeededUp()
        }, for: .Up)
    }
    
    private func invokeIfNeededUp() {
        if let event = NSApp.currentEvent {
            super.mouseUp(with: event)
            if let item = item as? GeneralRowItem, let table = item.table, table.alwaysOpenRowsOnMouseUp, mouseInside() {
                invokeAction(item, clickCount: event.clickCount)
            }
        }
    }
    
    func invokeAction(_ item: GeneralRowItem, clickCount: Int) {
        if clickCount <= 1 {
            item.action()
        }
    }
    
    private func invokeIfNeededDown() {
        if let event = NSApp.currentEvent {
            super.mouseDown(with: event)
            if let item = item as? GeneralRowItem, let table = item.table, !table.alwaysOpenRowsOnMouseUp, let event = NSApp.currentEvent, mouseInside() {
                if item.enabled {
                    invokeAction(item, clickCount: event.clickCount)
                }
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = self.item as? SearchTopicRowItem else {
            return
        }
        let theme = item.presentation ?? theme
        borderView.backgroundColor = theme.colors.border
    }
    
    override var backdorColor: NSColor {
        guard let item = self.item as? SearchTopicRowItem else {
            return isSelect ? theme.colors.accentSelect : theme.colors.background
        }
        let theme = item.presentation ?? theme
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SearchTopicRowItem else {
            return
        }
        
        
        self.nameView.update(item.isSelected ? item.nameSelectedLayout : item.nameLayout)
        
        borderView.isHidden = isSelect
        
        if let info = item.item.threadData?.info {
            
            if let view = self.avatarControl {
                performSubviewRemoval(view, animated: animated)
                self.avatarControl = nil
            }
            
            let size = NSMakeSize(30, 30)
            let current: InlineStickerItemLayer
            if let layer = self.inlineTopicPhotoLayer, layer.file?.fileId.id == info.icon {
                current = layer
            } else {
                if let layer = inlineTopicPhotoLayer {
                    performSublayerRemoval(layer, animated: animated)
                    self.inlineTopicPhotoLayer = nil
                }
                if let fileId = info.icon {
                    current = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .framesCount(1))
                } else {
                    let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: item.threadId ==  1)
                    current = .init(account: item.context.account, file: file, size: size, playPolicy: .playCount(2))
                }
                current.superview = containerView
                self.layer?.addSublayer(current)
                self.inlineTopicPhotoLayer = current
                
                current.frame = CGRect(origin: CGPoint(x: 10, y: 10), size: size)
            }
        } else {
            if let inlineTopicPhotoLayer {
                performSublayerRemoval(inlineTopicPhotoLayer, animated: animated)
                self.inlineTopicPhotoLayer = nil
            }
            
            let current: AvatarControl
            if let view = self.avatarControl {
                current = view
            } else {
                current = AvatarControl(font: .avatar(4))
                current.setFrameSize(NSMakeSize(30, 30))
                current.setFrameOrigin(NSMakePoint(10, 10))
                self.avatarControl = current
                addSubview(current)
            }
            current.setPeer(account: item.context.account, peer: item.item.renderedPeer.chatOrMonoforumMainPeer?._asPeer())
        }
        
    }
    
    override func layout() {
        super.layout()
        containerView.frame = bounds
        nameView.centerY(x: 50)
        borderView.frame = NSMakeRect(50, frame.height - .borderSize, frame.width - 50, .borderSize)
    }
    
    override func updateAnimatableContent() -> Void {
        let isLite: Bool = self.isEmojiLite
        let checkValue:(InlineStickerItemLayer)->Void = { value in
            if let superview = value.superview {
                var isKeyWindow: Bool = false
                if let window = superview.window {
                    if !window.canBecomeKey {
                        isKeyWindow = true
                    } else {
                        isKeyWindow = window.isKeyWindow
                    }
                }
                value.isPlayable = superview.visibleRect != .zero && isKeyWindow && !isLite
            }
        }
        if let value = inlineTopicPhotoLayer {
            checkValue(value)
        }
    }
    
    override var isEmojiLite: Bool {
        if let item = item as? SearchTopicRowItem {
            return item.context.isLite(.emoji)
        }
        return super.isEmojiLite
    }
}
