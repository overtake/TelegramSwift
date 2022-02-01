//
//  ChatInlineReactionMenuItem.swift
//  Telegram
//
//  Created by Mike Renoir on 01.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

class ChatInlineReactionMenuItem : ContextMenuItem {
    
    private let context: AccountContext
    private let _handler:(String) -> Void
    private let reactions: [AvailableReactions.Reaction]
    init(context: AccountContext, reactions: [AvailableReactions.Reaction], handler: @escaping(String) -> Void) {
        self.context = context
        self._handler = handler
        self.reactions = reactions
        super.init("")
    }
    
    required init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func rowItem(presentation: AppMenu.Presentation, interaction: AppMenuBasicItem.Interaction) -> TableRowItem {
        return ChatInlineReactionMenuRowItem(.zero, item: self, interaction: interaction, presentation: presentation, context: context, handler: _handler, reactions: self.reactions)
    }
}


private final class ChatInlineReactionMenuRowItem : AppMenuRowItem {
    fileprivate let context: AccountContext
    fileprivate let _handler:(String) -> Void
    fileprivate let reactions: [AvailableReactions.Reaction]
    init(_ initialSize: NSSize, item: ContextMenuItem, interaction: AppMenuBasicItem.Interaction, presentation: AppMenu.Presentation, context: AccountContext, handler: @escaping(String) -> Void, reactions: [AvailableReactions.Reaction]) {
        
        self.context = context
        self._handler = handler
        self.reactions = reactions
        super.init(initialSize, item: item, interaction: interaction, presentation: presentation)
        
    }

    deinit {
    }

    override var effectiveSize: NSSize {
        let size = super.effectiveSize
        var width = ContextAddReactionsListView.width(for: reactions) + 8
        width = min(width, 30 * 7 + 20)
        return NSMakeSize(width, size.height)
    }
    
    override var height: CGFloat {
        return 30
    }
    
    override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        return true
    }
    
    override func viewClass() -> AnyClass {
        return ChatInlineReactionMenuRowView.self
    }
}

private final class ChatInlineReactionMenuRowView : AppMenuBasicItemView {
    private var reactions: ContextAddReactionsListView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

    }
    
    override func layout() {
        super.layout()
        reactions?.frame = contentSize.bounds
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ChatInlineReactionMenuRowItem else {
            return
        }
        if self.reactions == nil {
            var width = ContextAddReactionsListView.width(for: item.reactions)
            width = min(width, 30 * 6 + 15)
            let reactionsView = ContextAddReactionsListView(frame: NSMakeRect(0, 0, width, 30), context: item.context, list: item.reactions, add: { [weak item] value in
                item?._handler(value)
                AppMenu.closeAll()
            }, radiusLayer: false)
            self.reactions = reactionsView
            addSubview(reactionsView)
        }
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
