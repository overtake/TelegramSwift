//
//  StoryChatListView.swift
//  Telegram
//
//  Created by Mike Renoir on 08.05.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import SwiftSignalKit
import Postbox


private struct StoryChatListEntry : Equatable, Comparable, Identifiable {
    let item: EngineStorySubscriptions.Item
    let index: Int
    let appearance: Appearance
    static func <(lhs: StoryChatListEntry, rhs: StoryChatListEntry) -> Bool {
        return lhs.index < rhs.index
    }
    var stableId: AnyHashable {
        return item.peer.id
    }
    var id: PeerId {
        return item.peer.id
    }
    var hasUnseen: Bool {
        return self.item.hasUnseen
    }
}



final class StoryListChatListRowItem : TableRowItem {
    private let _stableId: AnyHashable
    let context: AccountContext
    let state: EngineStorySubscriptions
    let open: (StoryInitialIndex?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: EngineStorySubscriptions, open:@escaping(StoryInitialIndex?)->Void) {
        self._stableId = stableId
        self.context = context
        self.state = state
        
        self.open = open
        super.init(initialSize)
    }
    
    
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height: CGFloat {
        return 86
    }
    
    override func viewClass() -> AnyClass {
        return StoryListChatListRowView.self
    }
    
    override var animatable: Bool {
        return true
    }
}


private final class StoryListChatListRowView: TableRowView {
    
    private let tableView: HorizontalTableView
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        tableView = HorizontalTableView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(borderView)
        
        tableView.getBackgroundColor = {
            .clear
        }
        
        tableView.setScrollHandler({ [weak self] position in
            switch position.direction {
            case .bottom:
                if let item = self?.item as? StoryListChatListRowItem {
                    if let _ = item.state.hasMoreToken {
                        item.context.account.storySubscriptionsContext?.loadMore()
                    }
                }
            default:
                break
            }
        })
    }
    
    override var backdorColor: NSColor {
        return .clear
    }

    override func layout() {
        super.layout()
        tableView.frame = bounds
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var current: [StoryChatListEntry] = []
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryListChatListRowItem else {
            return
        }
        
        borderView.backgroundColor = theme.colors.border
        
        CATransaction.begin()


        var entries:[StoryChatListEntry] = []
        var index: Int = 0
        
        if let item = item.state.accountItem, item.storyCount > 0 {
            entries.append(.init(item: item, index: index, appearance: appAppearance))
            index += 1
        }
        
        for item in item.state.items {
            if item.storyCount > 0 {
                entries.append(.init(item: item, index: index, appearance: appAppearance))
                index += 1
            }
        }

        let initialSize = NSMakeSize(item.height, item.height)
        let context = item.context

        let (deleted, inserted, updated) = proccessEntriesWithoutReverse(self.current, right: entries, { entry in
            return StoryListEntryRowItem(initialSize, entry: entry, context: context, open: item.open)
        })
        let transition = TableUpdateTransition(deleted: deleted, inserted: inserted, updated: updated, animated: true)

        self.tableView.merge(with: transition)

        self.current = entries
        
        if tableView.documentSize.height < tableView.frame.width * 2 {
            if let _ = item.state.hasMoreToken {
                item.context.account.storySubscriptionsContext?.loadMore()
            }
        }

        CATransaction.commit()
    }
}

private final class StoryListEntryRowItem : TableRowItem {
    let entry: StoryChatListEntry
    let context: AccountContext
    let open:(StoryInitialIndex?)->Void
    init(_ initialSize: NSSize, entry: StoryChatListEntry, context: AccountContext, open: @escaping(StoryInitialIndex?)->Void) {
        self.entry = entry
        self.context = context
        self.open = open
        super.init(initialSize)
    }
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items: [ContextMenuItem] = []
        items.append(.init("View Profile", handler: {
            
        }, itemImage: MenuAnimation.menu_open_profile.value))
        
        items.append(.init("Mute", handler: {
            
        }, itemImage: MenuAnimation.menu_mute.value))
        
        items.append(.init("Hide", handler: {
            
        }, itemImage: MenuAnimation.menu_hide.value))

        return .single(items)
    }
    
    func callopenStory() {
        let table = self.table
        self.open(.init(peerId: entry.id, id: nil, messageId: nil, takeControl: { [weak table] peerId, _, storyId in
            var view: NSView?
            table?.enumerateItems(with: { item in
                if let item = item as? StoryListEntryRowItem {
                    view = item.takeControl(peerId, storyId)
                }
                return view == nil
            })
            return view
        }))
    }
    
    private func takeControl(_ peerId: PeerId, _ storyId: Int32?) -> NSView? {
        (self.view as? StoryListEntryRowView)?.takeControl(peerId)
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return StoryListEntryRowView.self
    }
    
    override var height: CGFloat {
        return 70
    }

    override var width: CGFloat {
        return 86
    }
}


private final class StoryListEntryRowView : HorizontalRowView {
    private let imageView = AvatarControl(font: .avatar(15))
    private let textView = TextView()
    private let view = View(frame: NSMakeRect(0, 0, 50, 50))
    private let overlay = Control(frame: NSMakeRect(0, 0, 70, 86))
    private let stateView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        imageView.setFrameSize(NSMakeSize(44, 44))
        addSubview(overlay)
        
        
        stateView.isEventLess = true
        
        imageView.userInteractionEnabled = false
        view.isEventLess = true
        
        overlay.addSubview(view)
        overlay.addSubview(textView)
        
        view.addSubview(stateView)
        
        overlay.scaleOnClick = true
        
        view.addSubview(imageView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        overlay.set(handler: { [weak self] _ in
            if let item = self?.item as? StoryListEntryRowItem {
                item.callopenStory()
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    func takeControl(_ peerId: PeerId) -> NSView? {
        if let tableView = self.item?.table {
            let view = tableView.item(stableId: AnyHashable(peerId))?.view as? StoryListEntryRowView
            return view?.imageView
        }
        return nil
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryListEntryRowItem else {
            return
        }
        imageView.setPeer(account: item.context.account, peer: item.entry.item.peer._asPeer())
        
        let name: String
        if item.entry.id == item.context.peerId {
            name = "My Story"
            stateView.isHidden = true
        } else {
            name = item.entry.item.peer._asPeer().compactDisplayTitle
            stateView.isHidden = false
        }
        
        let layout = TextViewLayout.init(.initialize(string: name, color: theme.colors.text, font: .normal(10)), maximumNumberOfLines: 1, truncationType: .middle)
        layout.measure(width: item.height - 4)
        textView.update(layout)
        
        stateView.image = item.entry.hasUnseen ? theme.icons.story_unseen : theme.icons.story_seen
        
        
        
    }
    
    override func layout() {
        super.layout()
        imageView.centerX(y: 3)
        view.centerX(y: 10)
        stateView.frame = imageView.frame.insetBy(dx: -3, dy: -3)
        textView.centerX(y: view.frame.maxY + 4)
    }
    
}
