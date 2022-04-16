//
//  Avatar_BgListView.swift
//  Telegram
//
//  Created by Mike Renoir on 15.04.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import AppKit


private final class Avatar_BgColorListItem : GeneralRowItem {
    let colors: [AvatarColor]
    init(_ initialSize: NSSize, height: CGFloat, colors: [AvatarColor], stableId: AnyHashable) {
        self.colors = colors
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    override func viewClass() -> AnyClass {
        return Avatar_BgColorListView.self
    }
}

private final class Avatar_BgColorListView : TableRowView {
    
    
    private class ColorPreviewView : Control {
        
        private var selectedView: View?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        func set(color: AvatarColor, animated: Bool) {
            switch color.content {
            case let .solid(color):
                self.backgroundColor = color
            default:
                break
            }
            if color.selected {
                let current: View
                if let view = self.selectedView {
                    current = view
                } else {
                    current = View(frame: frame.insetBy(dx: 2, dy: 2))
                    current.layer?.cornerRadius = current.frame.height / 2
                    self.addSubview(current)
                    self.selectedView = current
                    if animated {
                        current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2)
                    }
                }
                current.layer?.borderColor = theme.colors.background.cgColor
                current.layer?.borderWidth = 2
            } else if let view = self.selectedView {
                performSubviewRemoval(view, animated: animated, scale: true)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let scrollView = HorizontalScrollView()
    private let documentView = View()
    private let contentView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scrollView)
        documentView.addSubview(contentView)
        documentView.backgroundColor = .clear
        contentView.backgroundColor = .clear
        scrollView.backgroundColor = .clear
        scrollView.background = .clear
        scrollView.documentView = documentView
    }
    
    override func layout() {
        super.layout()
        
        var x: CGFloat = 0
        for view in contentView.subviews {
            view.setFrameOrigin(NSMakePoint(x, 0))
            x += view.frame.width
            x += 10
        }
        
        contentView.frame = NSMakeRect(20, 0, x - 10, frame.height)
        
        documentView.frame = NSMakeSize(x + 40, frame.height).bounds
        scrollView.frame = bounds.insetBy(dx: 0, dy: 0)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? Avatar_BgColorListItem else {
            return
        }
        
        while item.colors.count < contentView.subviews.count {
            contentView.subviews.last?.removeFromSuperview()
        }
        while item.colors.count > contentView.subviews.count {
            let view = ColorPreviewView(frame: NSMakeRect(0, 0, item.height, item.height))
            view.layer?.cornerRadius = item.height / 2
            contentView.addSubview(view)
        }
        
        for (i, view) in contentView.subviews.enumerated() {
            let view = view as! ColorPreviewView
            let color = item.colors[i]
            view.set(color: color, animated: animated)
        }
        
        layout()
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Avatar_BgListView : View {
   

    
    private let tableView = TableView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        tableView.getBackgroundColor = {
            theme.colors.listBackground
        }
    }
    
    
    override func layout() {
        super.layout()
        tableView.frame = bounds
    }
    
    func set(patterns: [TelegramMediaFile], colors: [AvatarColor], animated: Bool) {
        tableView.beginTableUpdates()
        tableView.removeAll()
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: arc4random64(), backgroundColor: .clear))
        
        _ = tableView.addItem(item: GeneralTextRowItem(frame.size, stableId: arc4random64(), text: .initialize(string: "PLAIN GRADIENT", color: theme.colors.listGrayText, font: .normal(12)), inset: NSEdgeInsets(), viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 20, 5, 0))))
        
        _ = tableView.addItem(item: Avatar_BgColorListItem(frame.size, height: 35, colors: colors, stableId: arc4random64()))
        
        
        _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 20, stableId: arc4random64(), backgroundColor: .clear))

        _ = tableView.addItem(item: GeneralTextRowItem(frame.size, stableId: arc4random64(), text: .initialize(string: "GRADIENT WITH PATTERN", color: theme.colors.listGrayText, font: .normal(12)), inset: NSEdgeInsets(), viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 20, 5, 0))))

        
        tableView.endTableUpdates()
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
