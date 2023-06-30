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
    init(_ initialSize: NSSize, stableId: AnyHashable, getState:@escaping()->PeerListState, getDeltaProgress:@escaping()->CGFloat?, getInterfaceState:@escaping()->StoryListChatListRowItem.InterfaceState) {
        self.getInterfaceState = getInterfaceState
        self.getState = getState
        self.getDeltaProgress = getDeltaProgress
        super.init(initialSize, stableId: stableId)
    }
    
    
    
    override var height: CGFloat {
        guard let table = self.table else {
            return 1
        }
        let state = getState()
        var height: CGFloat = 50
        if state.mode == .plain, state.splitState != .minimisize {
            if let progress = getDeltaProgress() {
                height += 40 * progress
            } else if state.appear == .normal {
                height += 40
            }
            if !state.filterData.tabs.isEmpty, !state.filterData.sidebar, state.searchState == .None {
                if let progress = getDeltaProgress() {
                    height += 36 * progress
                } else if state.appear == .normal {
                    height += 36
                }
            }
        }
        height += getInterfaceState().navigationHeight
        if getInterfaceState().initFromEvent == false, state.hasStories {
            height += min(table.documentOffset.y, 0)
        }
        return height
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
