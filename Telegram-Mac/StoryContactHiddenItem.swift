//
//  StoryContactHiddenItem.swift
//  Telegram
//
//  Created by Mike Renoir on 19.06.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramCore


final class StoryContactHiddenItem : GeneralRowItem {
    fileprivate let open:(StoryInitialIndex?, Bool)->Void
    fileprivate let story: EngineStorySubscriptions.Item
    fileprivate let context: AccountContext
    fileprivate let title: TextViewLayout
    fileprivate let status: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, story: EngineStorySubscriptions.Item, open:@escaping(StoryInitialIndex?, Bool)->Void) {
        self.open = open
        self.context = context
        self.story = story
        self.title = .init(.initialize(string: story.peer._asPeer().displayTitle, color: theme.colors.text, font: .medium(.title)))
        //TODOLANG
        self.status = .init(.initialize(string: "\(story.storyCount) stories", color: theme.colors.grayText, font: .normal(.text)))
        super.init(initialSize, height: 50.0, stableId: stableId)
        
        _ = makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 10 - 36 - 10 - 10)
        self.status.measure(width: width - 10 - 36 - 10 - 10)

        return true
    }
    
    override func viewClass() -> AnyClass {
        return StoryContactHiddenItemView.self
    }
}


private final class StoryContactHiddenItemView: TableRowView {
    private let titleView = TextView()
    private let statusView = TextView()
    private let avatarView = AvatarControl(font: .avatar(12))
    private let stateView = View()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatarView.setFrameSize(NSMakeSize(30, 30))
        addSubview(borderView)
        addSubview(titleView)
        addSubview(statusView)
        addSubview(stateView)
        addSubview(avatarView)
        stateView.setFrameSize(NSMakeSize(36, 36))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryContactHiddenItem else {
            return
        }
        titleView.update(item.title)
        statusView.update(item.status)
        avatarView.setPeer(account: item.context.account, peer: item.story.peer._asPeer())
        
    }
    
    override func layout() {
        super.layout()
        avatarView.centerY(x: 10)
        titleView.setFrameOrigin(NSMakePoint(avatarView.frame.maxX + 10, 4))
        statusView.setFrameOrigin(NSMakePoint(avatarView.frame.maxX + 10, 4))
    }
}
