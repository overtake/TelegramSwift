//
//  ContextClueRowItem.swift
//  Telegram
//
//  Created by keepcoder on 20/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class ContextClueRowItem: TableRowItem {

    private let _stableId:AnyHashable
    let clues:[String]
    var selectedIndex:Int? = nil

    override var stableId: AnyHashable {
        return _stableId
    }
    fileprivate let context: AccountContext
    fileprivate let canDisablePrediction: Bool
    init(_ initialSize: NSSize, stableId:AnyHashable, context: AccountContext, clues: [String], canDisablePrediction: Bool) {
        self._stableId = stableId
        self.clues = clues
        self.context = context
        self.canDisablePrediction = canDisablePrediction
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    
    override var height: CGFloat {
        return 40
    }
    
    override func viewClass() -> AnyClass {
        return ContextClueRowView.self
    }
    
}

private final class ClueRowItem : TableRowItem {
    private let _stableId = arc4random()
    override var stableId: AnyHashable {
        return _stableId
    }
    let layout: TextViewLayout
    
    init(_ initialSize: NSSize, clue: String) {
        self.layout = TextViewLayout(.initialize(string: clue, color: nil, font: .normal(17)))
        super.init(initialSize)
        layout.measure(width: .greatestFiniteMagnitude)
    }
    
    
    override func viewClass() -> AnyClass {
        return ClueRowView.self
    }
    
    override var height: CGFloat {
        return 40
    }
    override var width: CGFloat {
        return 40
    }
}

private final class ClueRowView : HorizontalRowView {
    private let textView: TextView = TextView()
    private let containerView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(containerView)
        addSubview(textView)
        containerView.layer?.cornerRadius = .cornerRadius
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        super.updateColors()
        containerView.backgroundColor = item?.isSelected == true ? theme.colors.accent : theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        if let item = item as? ClueRowItem {
            textView.update(item.layout)
        }
    }
    
    override func layout() {
        super.layout()
        containerView.frame = NSMakeRect(4, 4, frame.width - 8, frame.height - 8)
        textView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class ContextClueRowView : TableRowView, TableViewDelegate {
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let clues = self.item as? ContextClueRowItem {
            clues.selectedIndex = row
            if byClick, let window = window as? Window {
                window.sendKeyEvent(.Return, modifierFlags: [])
            }
        }
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    private let button = ImageButton()
    
    private let tableView = HorizontalTableView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        tableView.delegate = self
        addSubview(button)
        
        button.set(handler: { [weak self] _ in
            self?.disablePrediction()
        }, for: .Click)
    }
    
    private func disablePrediction() {
        guard let window = self.window as? Window, let item = item as? ContextClueRowItem else { return }
        let sharedContext = item.context.sharedContext
        confirm(for: window, information: L10n.generalSettingsEmojiPredictionDisableText, okTitle: L10n.generalSettingsEmojiPredictionDisable, successHandler: { _ in
            _ = updateBaseAppSettingsInteractively(accountManager: sharedContext.accountManager, { current in
                return current.withUpdatedPredictEmoji(false)
            }).start()
        })
    }
    
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 0, frame.width - (button.isHidden ? 0 : button.frame.width), bounds.height)
        button.centerY(x: frame.width - button.frame.width)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        
        
        button.set(image: theme.icons.disableEmojiPrediction, for: .Normal)
        _ = button.sizeToFit(NSZeroSize, NSMakeSize(40, 40), thatFit: true)
        
        tableView.beginTableUpdates()
        tableView.removeAll(redraw: true, animation: .none)
        if let item = item as? ContextClueRowItem {
            
            button.isHidden = !item.canDisablePrediction
            
            for clue in item.clues {
                _ = tableView.addItem(item: ClueRowItem(bounds.size, clue: clue), animation: .none)
            }
            if let selectedIndex = item.selectedIndex {
                let item = tableView.item(at: selectedIndex)
                _ = tableView.select(item: item)
            }
        }
        tableView.endTableUpdates()
        
        if let selectedItem = tableView.selectedItem() {
            tableView.scroll(to: .center(id: selectedItem.stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
        }
        
        needsLayout = true
    }
}
