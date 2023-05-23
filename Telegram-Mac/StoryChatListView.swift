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


final class StoryListChatListRowItem : TableRowItem {
    private let _stableId: AnyHashable
    let context: AccountContext
    let state: StoryListContext.State
    let open: (StoryInitialIndex?)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, state: StoryListContext.State, open:@escaping(StoryInitialIndex?)->Void) {
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
    }

    override func layout() {
        super.layout()
        tableView.frame = bounds
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var current: [StoryListEntry] = []
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StoryListChatListRowItem else {
            return
        }
        
        borderView.backgroundColor = theme.colors.border
        
        CATransaction.begin()
        
        
        var entries:[StoryListEntry] = []
        var index: Int = 0
        for itemSet in item.state.itemSets {
            if !itemSet.items.isEmpty {
                entries.append(.init(item: itemSet, index: index))
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
        
        CATransaction.commit()
    }
}

private final class StoryListEntryRowItem : TableRowItem {
    let entry: StoryListEntry
    let context: AccountContext
    let open:(StoryInitialIndex?)->Void
    init(_ initialSize: NSSize, entry: StoryListEntry, context: AccountContext, open: @escaping(StoryInitialIndex?)->Void) {
        self.entry = entry
        self.context = context
        self.open = open
        super.init(initialSize)
    }
    override var stableId: AnyHashable {
        return entry.stableId
    }
    
    func callopen(_ takeControl: @escaping(PeerId, Int32?)->NSView?) {
        self.open(.init(peerId: entry.id, id: nil, takeControl: takeControl))
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
                item.callopen({ peerId, _ in
                    return self?.takeControl(peerId)
                })
            }
        }, for: .Click)
    }
    
    private func takeControl(_ peerId: PeerId) -> NSView? {
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
        imageView.setPeer(account: item.context.account, peer: item.entry.item.peer?._asPeer())
        
        let name: String
        if item.entry.item.peerId == item.context.peerId {
            name = "My Story"
            stateView.isHidden = true
        } else {
            name = item.entry.item.peer?._asPeer().compactDisplayTitle ?? ""
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
