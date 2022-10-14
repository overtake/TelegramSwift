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

final class SearchTopicRowItem: GeneralRowItem {
    let item: EngineChatList.Item
    fileprivate let context: AccountContext
    fileprivate let nameLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, item: EngineChatList.Item, context: AccountContext) {
        self.item = item
        self.context = context
        self.nameLayout = .init(.initialize(string: item.threadData?.info.title, color: theme.colors.text, font: .medium(.text)))
        super.init(initialSize, height: 50, stableId: stableId, type: .none, viewType: .legacy, border: [.Bottom])
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.nameLayout.measure(width: width - 50 - 10)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return SearchTopicRowView.self
    }
}

private class SearchTopicRowView : TableRowView {
    private var inlineTopicPhotoLayer: InlineStickerItemLayer?
    private let nameView = TextView()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(nameView)
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        addSubview(borderView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateColors() {
        super.updateColors()
        borderView.backgroundColor = theme.colors.border
    }
    
    override var backdorColor: NSColor {
        return isSelect ? theme.colors.accentSelect : theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SearchTopicRowItem else {
            return
        }
        
        self.nameView.update(item.nameLayout)
        
        borderView.isHidden = isSelect
        
        if let info = item.item.threadData?.info {
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
                    current = .init(account: item.context.account, inlinePacksContext: item.context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .playCount(2))
                } else {
                    let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor)
                    current = .init(account: item.context.account, file: file, size: size, playPolicy: .playCount(2))
                }
                current.superview = self
                self.layer?.addSublayer(current)
                self.inlineTopicPhotoLayer = current
                
                current.frame = CGRect(origin: CGPoint(x: 10, y: 10), size: size)
            }
        }
        
    }
    
    override func layout() {
        super.layout()
        
        nameView.centerY(x: 50)
        borderView.frame = NSMakeRect(50, frame.height - .borderSize, frame.width - 50, .borderSize)
    }
    
    override func updateAnimatableContent() -> Void {
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
                value.isPlayable = superview.visibleRect != .zero && isKeyWindow
            }
        }
        if let value = inlineTopicPhotoLayer {
            checkValue(value)
        }
    }
}
