//
//  ForumTopicEmojiSelectRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 27.09.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ForumTopicEmojiSelectRowItem : GeneralRowItem {
    let getView: ()->NSView
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, getView: @escaping()->NSView, viewType: GeneralViewType) {
        self.getView = getView
        self.context = context
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return ForumTopicEmojiSelectRowView.self
    }
    
    
    
    override var height: CGFloat {
        if let table = self.table {
            var height: CGFloat = 0
            table.enumerateItems(with: { item in
                if item != self {
                    height += item.height
                }
                return true
            })
            return table.frame.height - height
        }
        return 250
    }
    override var instantlyResize: Bool {
        return true
    }
    override var reloadOnTableHeightChanged: Bool {
        return true
    }
}


private final class ForumTopicEmojiSelectRowView: GeneralContainableRowView {
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? ForumTopicEmojiSelectRowItem else {
            return
        }
        let view = item.getView()
        view.frame = self.containerView.bounds

    }
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? ForumTopicEmojiSelectRowItem else {
            return
        }
        let view = item.getView()
        addSubview(view)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
