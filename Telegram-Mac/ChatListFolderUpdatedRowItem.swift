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
    let hide: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, updates: ChatFolderUpdates, action: @escaping()->Void, hide: @escaping()->Void) {
        
        self.hide = hide
        let text = strings().chatListFolderUpdatesTitleCountable(updates.availableChatsToJoin)
        
        self.title = .init(.initialize(string: text, color: theme.colors.accent, font: .medium(.title)))

        super.init(initialSize, stableId: stableId, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        title.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return 20 + title.layoutSize.height
    }
    
    override func viewClass() -> AnyClass {
        return ChatListFolderUpdatedRowItemView.self
    }
}

private final class ChatListFolderUpdatedRowItemView : TableRowView {
    private let title = TextView()
    private let control = Control()
    private let next = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        addSubview(title)
        addSubview(next)
        
        
        title.isSelectable = false
        title.userInteractionEnabled = false
        title.isEventLess = true
        
        
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
        
        transition.updateFrame(view: title, frame: title.centerFrame())
        transition.updateFrame(view: next, frame: next.centerFrameY(x: size.width - 10 - next.frame.width))
        transition.updateFrame(view: control, frame: size.bounds)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListFolderUpdatedRowItem else {
            return
        }
        title.update(item.title)
        
        control.set(background: theme.colors.background, for: .Normal)
        control.set(background: theme.colors.grayTransparent, for: .Highlight)

        control.borderColor = theme.colors.border
        next.set(image: theme.icons.modalClose, for: .Normal)
        next.sizeToFit()
        
        needsLayout = true
    }
}
