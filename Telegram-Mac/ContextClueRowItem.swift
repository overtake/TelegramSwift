//
//  ContextClueRowItem.swift
//  Telegram
//
//  Created by keepcoder on 20/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import InAppSettings
import TelegramCore
import Postbox

class ContextClueRowItem: TableRowItem {

    enum Source : Equatable {
        case emoji(String)
        case animated(TelegramMediaFile)
    }
    
    private let _stableId:AnyHashable
    let clues:[String]
    var selectedIndex:Int? = nil {
        didSet {
            var bp = 0
            bp += 1
        }
    }

    override var stableId: AnyHashable {
        return _stableId
    }
    fileprivate let context: AccountContext
    fileprivate let canDisablePrediction: Bool
    fileprivate let callback:((Source)->Void)?
    fileprivate let selected: Source?
    let animated: [TelegramMediaFile]
    fileprivate let presentation: TelegramPresentationTheme?
    
    let sources: [ContextClueRowItem.Source]
    
    init(_ initialSize: NSSize, stableId:AnyHashable, context: AccountContext, clues: [String], animated: [TelegramMediaFile], selected: Source?, canDisablePrediction: Bool, callback:((Source)->Void)? = nil, presentation: TelegramPresentationTheme?) {
        self.animated = context.isPremium ? Array(animated.prefix(30)) : Array(animated.filter { !$0.isPremiumEmoji }.prefix(30))
        self._stableId = stableId
        self.clues = clues
        self.context = context
        self.callback = callback
        self.selected = selected
        self.presentation = presentation
        
        self.sources = self.animated.map { .animated($0) } + self.clues.map { .emoji($0) }

        if let selected = selected, let index = sources.firstIndex(of: selected) {
            self.selectedIndex = index
        }
        
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

final class AnimatedClueRowItem : TableRowItem {
    private let _stableId = arc4random()
    override var stableId: AnyHashable {
        return _stableId
    }
    let clue: TelegramMediaFile
    let context: AccountContext
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, context: AccountContext, clue: TelegramMediaFile, presentation: TelegramPresentationTheme = theme) {
        self.clue = clue
        self.context = context
        self.presentation = presentation
        super.init(initialSize)
    }
    
    
    override func viewClass() -> AnyClass {
        return AnimatedClueRowView.self
    }
    
    override var height: CGFloat {
        return 40
    }
    override var width: CGFloat {
        return 40
    }
}

private final class AnimatedClueRowView: HorizontalRowView {
    private var sticker: InlineStickerItemLayer?
    private let containerView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(containerView)
        containerView.layer?.cornerRadius = .cornerRadius
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AnimatedClueRowItem else {
            return
        }
        
        if self.sticker?.file != item.clue {
            self.sticker?.removeFromSuperlayer()
            
            let size = NSMakeSize(item.height - 10, item.height - 10)
            
            let sticker = InlineStickerItemLayer(account: item.context.account, file: item.clue, size: size)
            sticker.superview = self
            sticker.isPlayable = true
            self.sticker = sticker
            
            containerView.layer?.addSublayer(sticker)
            containerView.frame = bounds.insetBy(dx: 4, dy: 4)

            sticker.frame = containerView.focus(size)
        }
    }
    
    override func updateAnimatableContent() -> Void {
        if let value = self.sticker, let superview = value.superview {
            var isKeyWindow: Bool = false
            if let window = window {
                if !window.canBecomeKey {
                    isKeyWindow = true
                } else {
                    isKeyWindow = window.isKeyWindow
                }
            }
            value.isPlayable = NSIntersectsRect(value.frame, superview.visibleRect) && isKeyWindow && !isEmojiLite
        }
    }
    
    override var isEmojiLite: Bool {
        return isLite(.emoji)
    }
    
    
    override func layout() {
        super.layout()
        containerView.frame = bounds.insetBy(dx: 4, dy: 4)
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = self.item as? AnimatedClueRowItem else {
            return
        }
        containerView.backgroundColor = item.isSelected ? item.presentation.colors.accent : .clear
    }
}


private final class ClueRowItem : TableRowItem {
    private let _stableId = arc4random()
    override var stableId: AnyHashable {
        return _stableId
    }
    let layout: TextViewLayout
    let presentation: TelegramPresentationTheme
    init(_ initialSize: NSSize, clue: String, presentation: TelegramPresentationTheme) {
        self.layout = TextViewLayout(.initialize(string: clue, color: nil, font: .normal(24)))
        self.presentation = presentation
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
        return .clear
    }
    
    override func updateColors() {
        super.updateColors()
        guard let item = item as? ClueRowItem else {
            return
        }
        containerView.backgroundColor = item.isSelected ? item.presentation.colors.accent : .clear
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
    
    enum Entry : Comparable, Identifiable {
        case common(String, Int)
        case animated(TelegramMediaFile, Int)
        
        static func <(lhs: Entry, rhs: Entry) -> Bool {
            return lhs.index < rhs.index
        }
        
        var index: Int {
            switch self {
            case .common(_, let index):
                return index
            case .animated(_, let index):
                return index
            }
        }
        var stableId: AnyHashable {
            switch self {
            case .common(let string, _):
                return string
            case .animated(let file, _):
                return file.fileId.id
            }
        }
        
        func makeItem(_ size: NSSize, context: AccountContext, presentation: TelegramPresentationTheme) -> TableRowItem {
            switch self {
            case let .common(clue, _):
                return ClueRowItem(size, clue: clue, presentation: presentation)
            case let .animated(file, _):
                return AnimatedClueRowItem(size, context: context, clue: file, presentation: presentation)
            }
        }
    }
    
    func selectionDidChange(row: Int, item: TableRowItem, byClick: Bool, isNew: Bool) {
        if let clues = self.item as? ContextClueRowItem {
            clues.selectedIndex = row
            if byClick, let window = window as? Window {
                if let callback = clues.callback {
                    let sources:[ContextClueRowItem.Source] = clues.sources
                    callback(sources[row])
                } else {
                    window.sendKeyEvent(.Return, modifierFlags: [])
                }
            } else if !byClick {
                tableView.scroll(to: .center(id: item.stableId, innerId: nil, animated: false, focus: .init(focus: false), inset: 0), toVisible: true)
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
        
        tableView.getBackgroundColor = {
            .clear
        }
        
        button.set(handler: { [weak self] _ in
            self?.disablePrediction()
        }, for: .Click)
    }
    
    private func disablePrediction() {
        guard let window = self.window as? Window, let item = item as? ContextClueRowItem else { return }
        let sharedContext = item.context.sharedContext
        verifyAlert_button(for: window, information: strings().generalSettingsEmojiPredictionDisableText, ok: strings().generalSettingsEmojiPredictionDisable, successHandler: { _ in
            _ = updateBaseAppSettingsInteractively(accountManager: sharedContext.accountManager, { current in
                return current.withUpdatedPredictEmoji(false)
            }).start()
        })
    }
    
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 0, frame.width - (button.isHidden ? 0 : button.frame.width), frame.height)
        button.centerY(x: frame.width - button.frame.width)
    }
    
    override func updateColors() {
        super.updateColors()
    }
    
    private var items:[Entry] = []
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        
        
       
        if let item = item as? ContextClueRowItem {
            
            let presentation = item.presentation ?? theme

            
            button.set(image: presentation.icons.disableEmojiPrediction, for: .Normal)
            _ = button.sizeToFit(NSZeroSize, NSMakeSize(40, 40), thatFit: true)
            
            button.isHidden = !item.canDisablePrediction
            
            var index: Int = 0
            var items:[Entry] = []
            
            for clue in item.animated {
                items.append(.animated(clue, index))
                index += 1
            }
            
            for clue in item.clues {
                items.append(.common(clue, index))
                index += 1
            }
            
            
            let context = item.context
            
            
            tableView.beginTableUpdates()
            
            
            let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: self.items, rightList: items)
            
            for rdx in deleteIndices.reversed() {
                tableView.remove(at: rdx, animation: animated ? .effectFade : .none)
                self.items.remove(at: rdx)
            }
            
            for (idx, item, _) in indicesAndItems {
                _ = tableView.insert(item: item.makeItem(bounds.size, context: context, presentation: presentation), at: idx, animation: animated ? .effectFade : .none)
                self.items.insert(item, at: idx)
            }
            for (idx, item, _) in updateIndices {
                let item =  item
                tableView.replace(item: item.makeItem(bounds.size, context: context, presentation: presentation), at: idx, animated: animated)
                self.items[idx] = item
            }
  
            tableView.endTableUpdates()
            
            if let selectedIndex = item.selectedIndex {
                let item = tableView.optionalItem(at: selectedIndex)
                if let item = item {
                    _ = tableView.select(item: item)
                }
            } else {
                tableView.cancelSelection()
            }
        }
        
        if let selectedItem = tableView.selectedItem() {
            tableView.scroll(to: .center(id: selectedItem.stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0), toVisible: true)
        }
        
        needsLayout = true
    }
}
