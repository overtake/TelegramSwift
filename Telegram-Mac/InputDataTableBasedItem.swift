//
//  InputDataTableBasedItem.swift
//  Telegram
//
//  Created by Mike Renoir on 26.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class InputDataTableBasedItem : GeneralRowItem {
    
    struct Row {
        struct Right {
            struct Badge {
                var text: String
                var callback:()->Void
            }
            var name: TextViewLayout
            var leftView: ((NSView?)->NSView)?
            var rightView: ((NSView?)->NSView?)?
            var badge: Badge?
        }
        let left: TextViewLayout?
        let right: Right
        
        var height: CGFloat {
            return (left?.layoutSize.height ?? 16) + 8 + right.name.layoutSize.height
        }
        
        func measure(_ width: CGFloat, basic: CGFloat) {
            let additional: CGFloat
            if let badge = right.badge {
                let layout = TextViewLayout(.initialize(string: badge.text, font: .normal(.small)))
                layout.measure(width: .greatestFiniteMagnitude)
                additional = layout.layoutSize.width + 16
            } else {
                additional = 0
            }
            if left == nil {
                right.name.measure(width: basic - additional - 20)
            } else {
                right.name.measure(width: width - 20 - additional)
            }
        }
        func prepare(width: CGFloat) {
            left?.measure(width: width / 1.5 - 40)
        }
        var leftWidth: CGFloat {
            if let left {
                return 10 + left.layoutSize.width + 10
            } else {
                return 0
            }
        }
    }
    fileprivate let rows: [Row]
    fileprivate let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, rows: [Row], context: AccountContext) {
        self.rows = rows
        self.context = context
        super.init(initialSize, stableId: stableId, viewType: viewType)
        for row in rows {
            row.prepare(width: initialSize.width)
        }
        assert(rows.count != 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
               
        
        let maxLeft = rows.map { $0.leftWidth }.max()!
        
        for row in rows {
            row.measure(width - inset.left * 2 - maxLeft - 20 - 40 - 25, basic: width - inset.left * 2)
        }
        
        return true
    }
    
    override var height: CGFloat {
        return rows.reduce(0, { $0 + $1.height })
    }
    
    override func viewClass() -> AnyClass {
        return InputDataTableBasedItemView.self
    }
}


final class InputDataTableBasedItemView: TableRowView {
    
    private class RowView: View {
        
        private class BadgeView : Control {
            private let textView = TextView()
            required init(frame frameRect: NSRect) {
                super.init(frame: frameRect)
                addSubview(textView)
                textView.userInteractionEnabled = false
                textView.isSelectable = false
                textView.isEventLess = true
                self.scaleOnClick = true
            }
            
            required init?(coder: NSCoder) {
                fatalError("init(coder:) has not been implemented")
            }
            
            func set(badge: InputDataTableBasedItem.Row.Right.Badge) -> NSSize {
                let layout = TextViewLayout(.initialize(string: badge.text, color: theme.colors.accent, font: .normal(.small)))
                layout.measure(width: .greatestFiniteMagnitude)
                textView.update(layout)
                
                setSingle(handler: { _ in
                    badge.callback()
                }, for: .Click)
                
                self.backgroundColor = theme.colors.accent.withAlphaComponent(0.2)
                self.layer?.cornerRadius = (layout.layoutSize.height + 4) / 2
                
                return textView.frame.insetBy(dx: -5, dy: -2).size
            }
            
            override func layout() {
                super.layout()
                textView.center()
            }
        }
        
        private let leftView = TextView()
        private let rightView = InteractiveTextView()
        private let left = View()
        
        private var rightLeft: NSView?
        private var rightRight: NSView?
        private var rightBadge: BadgeView?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            addSubview(left)

            
            addSubview(leftView)
            addSubview(rightView)
            
            leftView.userInteractionEnabled = false
            leftView.isSelectable = false
            
            rightView.textView.userInteractionEnabled = true

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var row: InputDataTableBasedItem.Row?
        private var startRight: CGFloat = 0

        func update(_ row: InputDataTableBasedItem.Row, startRight: CGFloat, hasSeparator: Bool, context: AccountContext) {
            self.row = row
            self.startRight = row.left == nil ? 10 : startRight
            leftView.update(row.left)
            rightView.set(text: row.right.name, context: context)
            self.border = hasSeparator ? [.Bottom] : nil
            
            left.backgroundColor = theme.colors.border.withAlphaComponent(0.3)
            left.border = [.Right]
            left.borderColor = theme.colors.border
                        
            let rightLeft = row.right.leftView?(self.rightLeft)
            
            if rightLeft != self.rightLeft {
                self.rightLeft?.removeFromSuperview()
            }
            self.rightLeft = rightLeft
            if let rightLeft = rightLeft {
                addSubview(rightLeft)
            }
            
            let rightRight = row.right.rightView?(self.rightRight)
            
            if rightRight != self.rightRight {
                self.rightRight?.removeFromSuperview()
            }
            self.rightRight = rightRight
            if let rightRight = rightRight {
                addSubview(rightRight)
            }
            
            if let badge = row.right.badge {
                let current: BadgeView
                if let view = self.rightBadge {
                    current = view
                } else {
                    current = BadgeView(frame: .zero)
                    self.rightBadge = current
                    addSubview(current)
                }
                let size = current.set(badge: badge)
                current.setFrameSize(size)
            } else if let rightBadge {
                performSubviewRemoval(rightBadge, animated: false)
                self.rightBadge = nil
            }
            
            needsLayout = true

        }
        
        override func layout() {
            super.layout()
            leftView.centerY(x: 10)
            if let rightLeft = rightLeft {
                rightLeft.centerY(x: startRight)
                rightView.centerY(x: rightLeft.frame.maxX + 5)
            } else {
                rightView.centerY(x: startRight)
            }
            
            var rightOffset = rightView.frame.maxX + 6
            if let rightRight = rightRight {
                rightOffset -= 2
                rightRight.centerY(x: rightOffset)
                rightOffset += rightRight.frame.width + 2
            }
            
            if let rightBadge {
                rightBadge.centerY(x: rightOffset)
            }
            
           
            left.frame = NSMakeRect(0, 0, startRight - 10, frame.height)
        }
    }
    private let container = View()
    
    private let left = View()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(container)
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = .borderSize
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? InputDataTableBasedItem else {
            return
        }
        container.frame = bounds.insetBy(dx: item.inset.left, dy: 0)
        layoutRows(item.rows, item: item)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func updateColors() {
        container.backgroundColor = theme.colors.background
        container.layer?.borderColor = theme.colors.border.cgColor
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? InputDataTableBasedItem else {
            return
        }
        
        while self.container.subviews.count > item.rows.count {
            self.container.subviews.last?.removeFromSuperview()
        }
        while self.container.subviews.count < item.rows.count {
            self.container.addSubview(RowView(frame: NSMakeRect(0, 0, container.frame.width, 40)))
        }
        
        layoutRows(item.rows, item: item)
    }
    
    private func layoutRows(_ rows: [InputDataTableBasedItem.Row], item: InputDataTableBasedItem) {
        var y: CGFloat = 0
        let maxLeft = rows.map { $0.leftWidth }.max()!
        for (i, row) in rows.enumerated() {
            let view = container.subviews[i] as! RowView
            view.frame = NSMakeRect(0, y, container.frame.width, row.height)
            y += row.height
            view.update(row, startRight: maxLeft + 10, hasSeparator: i < rows.count - 1, context: item.context)
        }
        left.frame = NSMakeRect(container.frame.minX, 0, maxLeft, container.frame.height)
    }
}
