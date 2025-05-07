//
//  MonoforumVerticalView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.05.2025.
//  Copyright © 2025 Telegram. All rights reserved.
//

import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

struct MonoforumItem : Equatable {
    var id: Int64
    var file: TelegramMediaFile
    var title: String
}

private struct MonoforumEntry : Comparable, Identifiable {
    static func < (lhs: MonoforumEntry, rhs: MonoforumEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    let item: MonoforumItem
    let index: Int
    let selected: Bool
    var stableId: AnyHashable {
        return item.id
    }
    
    fileprivate func item(initialSize: NSSize, context: AccountContext) -> Monoforum_VerticalItem {
        return Monoforum_VerticalItem(initialSize, stableId: stableId, item: self.item, context: context, selected: selected)
    }
}

private final class Monoforum_VerticalItem : TableRowItem {
    fileprivate let nameLayout: TextViewLayout
    fileprivate let context: AccountContext
    fileprivate let item: MonoforumItem
    fileprivate let selected: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, item: MonoforumItem, context: AccountContext, selected: Bool) {
        self.nameLayout = .init(.initialize(string: item.title, color: selected ? theme.colors.accent : theme.colors.listGrayText, font: .normal(.text)), truncationType: .middle, alignment: .center)
        self.nameLayout.measure(width: 70)
        self.selected = selected
        self.context = context
        self.item = item
        super.init(initialSize, stableId: stableId)
    }
    
    
    override var height: CGFloat {
        return 60
    }
    
    override func viewClass() -> AnyClass {
        return Monoforum_VerticalView.self
    }
}

private final class Monoforum_VerticalView : TableRowView {
    private let textView = TextView()
    private let animatedView = MediaAnimatedStickerView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(animatedView)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        border = [.Right]
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Monoforum_VerticalItem else {
            return
        }
        
        self.textView.update(item.nameLayout)
        self.animatedView.update(with: item.item.file, size: NSMakeSize(30, 30), context: item.context, table: item.table, animated: animated)
        self.needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        self.animatedView.centerX(y: 3)
        self.textView.centerX(y: frame.height - self.textView.frame.height - 3)
    }
}

class MonoforumVerticalView : View {
    private let tableView: TableView = TableView(frame: .zero)
    
    private var entries: [MonoforumEntry] = []
    
    private let selectionView: View = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        
        addSubview(selectionView)
        
        selectionView.layer?.cornerRadius = .cornerRadius
        
        updateLocalizationAndTheme(theme: theme)
        
        tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] scroll in
            self?.updateSelectionRect()
        }))
        
        self.layout()
    }
    
    private func updateSelectionRect(animated: Bool = false) {
        
        guard let selected = entries.first(where: { $0.selected }) else {
            return
        }
        guard let item = self.tableView.item(stableId: selected.stableId) else {
            return
        }
        guard tableView.contentView.bounds != .zero else {
            return
        }
        
        let scroll = self.tableView.scrollPosition().current
        let scrollY = scroll.rect.minY - tableView.frame.height
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        
        let rect = tableView.rectOf(item: item)
        
        transition.updateFrame(view: self.selectionView, frame:  NSMakeRect(-4, rect.origin.y + 5 - scrollY, 8, 50))
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        self.backgroundColor = theme.colors.background
        self.selectionView.backgroundColor = theme.colors.accent
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(items: [MonoforumItem], selected: Int64, chatInteraction: ChatInteraction, animated: Bool) {
        
        var entries: [MonoforumEntry] = []
        
        for (index, item) in items.enumerated() {
            entries.append(.init(item: item, index: index, selected: item.id == selected))
        }
        
        let (deleteIndices, indicesAndItems, updateIndices) = proccessEntriesWithoutReverse(self.entries, right: entries, { entry in
            return entry.item(initialSize: .zero, context: chatInteraction.context)
        })
        
        let transition = TableUpdateTransition(deleted: deleteIndices, inserted: indicesAndItems, updated: updateIndices, animated: animated, grouping: true)
        
        tableView.merge(with: transition, appearAnimated: false)
        
        self.entries = entries
        
        self.updateSelectionRect()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        self.updateSelectionRect()
    }
    
    override func layout() {
        super.layout()
        self.tableView.frame = bounds
        
        self.updateSelectionRect()
    }
}
