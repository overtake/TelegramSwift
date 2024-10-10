//
//  ChatListEmptyItem.swift
//  Telegram
//
//  Created by Mike Renoir on 26.06.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ChatListSpaceItem : GeneralRowItem {
    let getInterfaceState:()-> StoryListChatListRowItem.InterfaceState
    let getState:()->PeerListState
    let getDeltaProgress:()->CGFloat?
    let getNavigationHeight: ()->CGFloat
    init(_ initialSize: NSSize, stableId: AnyHashable, getState:@escaping()->PeerListState, getDeltaProgress:@escaping()->CGFloat?, getInterfaceState:@escaping()->StoryListChatListRowItem.InterfaceState, getNavigationHeight: @escaping()->CGFloat) {
        self.getInterfaceState = getInterfaceState
        self.getState = getState
        self.getDeltaProgress = getDeltaProgress
        self.getNavigationHeight = getNavigationHeight
        super.init(initialSize, stableId: stableId)
    }
    
    override var canBeAnchor: Bool {
        return false
    }
    
    override var height: CGFloat {
        guard let table = self.table else {
            return 1
        }
        return self.getNavigationHeight()
    }
    override func viewClass() -> AnyClass {
        return ChatListSpaceItemView.self
    }
}

private final class ChatListSpaceItemView : TableRowView {
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }

    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        

    }
}
