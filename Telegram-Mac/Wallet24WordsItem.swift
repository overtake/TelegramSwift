//
//  Wallet24WordsItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


class Wallet24WordsItem: GeneralRowItem {
    fileprivate let leftViewLayout: TextViewLayout
    fileprivate let rightViewLayout: TextViewLayout
    fileprivate let wordsList: String
    fileprivate let copy:(String)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, words: [String], viewType: GeneralViewType, copy:@escaping(String)->Void) {
        
        let left = words.prefix(12)
        let right = words.suffix(12)

        let leftAttributed: NSMutableAttributedString = NSMutableAttributedString()
        for (i, word) in left.enumerated() {
            _ = leftAttributed.append(string: "\(i + 1). ", color: theme.colors.grayText, font: .normal(.text))
            _ = leftAttributed.append(string: word, color: theme.colors.text, font: .medium(.text))
            if i != left.count - 1 {
                _ = leftAttributed.append(string: "\n", color: theme.colors.text, font: .normal(.text))
            }
        }
        let rightAttributed: NSMutableAttributedString = NSMutableAttributedString()
        for (i, word) in right.enumerated() {
            _ = rightAttributed.append(string: "\(i + 1 + left.count). ", color: theme.colors.grayText, font: .normal(.text))
            _ = rightAttributed.append(string: word, color: theme.colors.text, font: .medium(.text))
            if i != right.count - 1 {
                _ = rightAttributed.append(string: "\n", color: theme.colors.text, font: .normal(.text))
            }
        }
        
        self.leftViewLayout = TextViewLayout(leftAttributed, lineSpacing: 5, alwaysStaticItems: true)
        self.rightViewLayout = TextViewLayout(rightAttributed, lineSpacing: 5, alwaysStaticItems: true)

        self.leftViewLayout.measure(width: .greatestFiniteMagnitude)
        self.rightViewLayout.measure(width: .greatestFiniteMagnitude)
        
        self.wordsList = words.joined(separator: " ")
        self.copy = copy
        super.init(initialSize, height: max(self.leftViewLayout.layoutSize.height, self.rightViewLayout.layoutSize.height) + viewType.innerInset.top + viewType.innerInset.bottom, stableId: stableId, viewType: viewType)
        }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        return true
    }
    
    override var blockWidth: CGFloat {
        return 280
    }
    
    override func viewClass() -> AnyClass {
        return Wallet24WordsView.self
    }
}


private final class Wallet24WordsView : TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let leftTextView = TextView()
    private let rightTextView = TextView()
    private let wordsContainer = Control()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        leftTextView.isSelectable = false
        rightTextView.isSelectable = false
        leftTextView.userInteractionEnabled = false
        rightTextView.userInteractionEnabled = false
        
        wordsContainer.addSubview(leftTextView)
        wordsContainer.addSubview(rightTextView)
        self.addSubview(containerView)
        
        containerView.addSubview(wordsContainer)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? Wallet24WordsItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.leftTextView.background = backdorColor
        self.rightTextView.background = backdorColor
        self.containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? Wallet24WordsItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        wordsContainer.setFrameSize(NSMakeSize(250, max(leftTextView.frame.height, rightTextView.frame.height)))
        
        wordsContainer.center()
        
        leftTextView.centerY(x: 0)
        rightTextView.centerY(x: wordsContainer.frame.width - rightTextView.frame.width)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Wallet24WordsItem else {
            return
        }
        let wordsList = item.wordsList
        let copy = item.copy
        wordsContainer.removeAllHandlers()
        
        wordsContainer.set(handler: { control in
            if let event = NSApp.currentEvent {
                ContextMenu.show(items: [ContextMenuItem(L10n.walletSplashSave24WordsCopy, handler: {
                    copy(wordsList)
                })], view: control, event: event)
            }
        }, for: .RightDown)
        
        leftTextView.update(item.leftViewLayout)
        rightTextView.update(item.rightViewLayout)
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
