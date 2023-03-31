//
//  ChatListFolderUpdatedRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 30.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatListFolderUpdatedRowItem : GeneralRowItem {
    fileprivate let title: TextViewLayout
    fileprivate let text: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, updates: ChatFolderUpdates, action: @escaping()->Void) {
        
        let text = strings().chatListFolderUpdatesTitleCountable(updates.availableChatsToJoin)
        
        let attr = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
                
        self.title = .init(attr)
        self.text = .init(.initialize(string: strings().chatListFolderUpdatesInfo, color: theme.colors.grayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        title.measure(width: width - 40)
        text.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return 10 + title.layoutSize.height + 4 + text.layoutSize.height + 10
    }
    
    override func viewClass() -> AnyClass {
        return ChatListFolderUpdatedRowItemView.self
    }
}

private final class ChatListFolderUpdatedRowItemView : TableRowView {
    private let title = TextView()
    private let text = TextView()
    private let control = Control()
    private let next = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        addSubview(title)
        addSubview(text)
        addSubview(next)
        
        next.isEventLess = true
        
        title.isSelectable = false
        title.userInteractionEnabled = false
        title.isEventLess = true
        
        text.isSelectable = false
        text.userInteractionEnabled = false
        text.isEventLess = true
        
        control.border = [.Bottom]
        
        control.set(handler: { [weak self] control in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: title, frame: CGRect(origin: NSMakePoint(10, 10), size: title.frame.size))
        transition.updateFrame(view: text, frame: CGRect(origin: NSMakePoint(10, title.frame.maxY + 4), size: text.frame.size))
        
        transition.updateFrame(view: next, frame: next.centerFrameY(x: size.width - 10 - next.frame.width))
        transition.updateFrame(view: control, frame: size.bounds)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListFolderUpdatedRowItem else {
            return
        }
        title.update(item.title)
        text.update(item.text)
        
        control.set(background: theme.colors.background, for: .Normal)
        control.set(background: theme.colors.grayTransparent, for: .Highlight)

        control.borderColor = theme.colors.border
        next.image = theme.icons.generalNext
        next.sizeToFit()
        
        needsLayout = true
    }
}
