//
//  SearchStoryFoundItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore
import Postbox

final class SearchStoryFoundItem : GeneralRowItem {
    fileprivate let list: SearchStoryListContext.State
    fileprivate let context: AccountContext
    
    fileprivate let headerLayout: TextViewLayout
    fileprivate let infoLayout: TextViewLayout
    
    fileprivate let item: StoryListChatListRowItem
    
    init(_ initialSize: NSSize, stableId: AnyHashable, list: SearchStoryListContext.State, context: AccountContext, query: String, action:@escaping()->Void) {
        self.list = list
        self.context = context
        
        let items: [EngineStorySubscriptions.Item] = list.items.prefix(3).compactMap { item in
            if let peer = item.peer {
                return .init(peer: peer, hasUnseen: true, hasUnseenCloseFriends: false, hasPending: false, storyCount: 1, unseenCount: 0, lastTimestamp: 0)
            } else {
                return nil
            }
        }
        
        self.item = StoryListChatListRowItem(initialSize, stableId: 0, context: context, isArchive: false, state: .init(accountItem: nil, items: items, hasMoreToken: nil), open: { _, _, _ in }, getInterfaceState: { return .concealed }, reveal: {})
        
        self.headerLayout = .init(.initialize(string: strings().hashtagSearchStoriesFoundCountable(list.totalCount), color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.infoLayout = .init(.initialize(string: strings().hashtagSearchStoriesFoundInfo(query), color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        
        super.init(initialSize, height: 50, stableId: stableId, action: action, inset: .init())
    }
    
    override func viewClass() -> AnyClass {
        return SearchStoryFoundView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        self.headerLayout.measure(width: width - 80)
        self.infoLayout.measure(width: width - 80)
        
        self.item.makeSize(width)

        return true
    }
}


private final class SearchStoryFoundView: GeneralContainableRowView {
    private let headerView = TextView()
    private let infoView = TextView()
    private let storiesView: StoryListChatListRowView = .init(frame: .zero)
    private let overlay = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(headerView)
        addSubview(infoView)
        
        addSubview(storiesView)
        
        addSubview(overlay)
        
        headerView.userInteractionEnabled = false
        headerView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? GeneralRowItem {
                item.action()
            }
        }, for: .Click)
        
        
        containerView.scaleOnClick = true
    }
    
    override func layout() {
        super.layout()
        headerView.setFrameOrigin(NSMakePoint(70, 7))
        infoView.setFrameOrigin(NSMakePoint(70, frame.height - infoView.frame.height - 7))
        overlay.frame = bounds
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SearchStoryFoundItem else {
            return
        }
        
        self.headerView.update(item.headerLayout)
        self.infoView.update(item.infoLayout)
        
        var x: CGFloat = 0
        if item.item.itemsCount == 1 {
            x = (70 - 26) / 2 - 10
        } else if item.item.itemsCount == 2 {
            x = (70 - 26 - 13) / 2 - 10
        }
        
        storiesView.frame = NSMakeRect(x, 10, 70, item.item.height)
        storiesView.set(item: item.item, animated: animated)
        
        needsLayout = true
    }
}
