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
            let name: TextViewLayout
            var leftView: ((NSView?)->NSView)?
        }
        let left: TextViewLayout
        let right: Right
        
        var height: CGFloat {
            return 24 + right.name.layoutSize.height
        }
        
        func measure(_ width: CGFloat) {
            right.name.measure(width: width - 20)
        }
        func prepare() {
            left.measure(width: .greatestFiniteMagnitude)
        }
        var leftWidth: CGFloat {
            return 10 + left.layoutSize.width + 10
        }
    }
    fileprivate let rows: [Row]
    
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, rows: [Row]) {
        self.rows = rows
        super.init(initialSize, stableId: stableId, viewType: viewType)
        for row in rows {
            row.prepare()
        }
        assert(rows.count != 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
               
        
        let maxLeft = rows.map { $0.leftWidth }.max()!
        
        for row in rows {
            row.measure(width - inset.left * 2 - maxLeft - 20 - 40 - 25)
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
        private let leftView = TextView()
        private let rightView = TextView()
        private let left = View()
        
        private var rightLeft: NSView?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            
            addSubview(left)

            
            addSubview(leftView)
            addSubview(rightView)
            
            leftView.userInteractionEnabled = false
            leftView.isSelectable = false
            
            rightView.isSelectable = false

        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private var row: InputDataTableBasedItem.Row?
        private var startRight: CGFloat = 0

        func update(_ row: InputDataTableBasedItem.Row, startRight: CGFloat, hasSeparator: Bool) {
            self.row = row
            self.startRight = startRight
            leftView.update(row.left)
            rightView.update(row.right.name)
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
        layoutRows(item.rows)
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
        
        layoutRows(item.rows)
    }
    
    private func layoutRows(_ rows: [InputDataTableBasedItem.Row]) {
        var y: CGFloat = 0
        let maxLeft = rows.map { $0.leftWidth }.max()!
        for (i, row) in rows.enumerated() {
            let view = container.subviews[i] as! RowView
            view.frame = NSMakeRect(0, y, container.frame.width, row.height)
            y += row.height
            view.update(row, startRight: maxLeft + 10, hasSeparator: i < rows.count - 1)
        }
        left.frame = NSMakeRect(container.frame.minX, 0, maxLeft, container.frame.height)
    }
}
