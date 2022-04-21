//
//  TranslateTableRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.01.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class TranslateTableRowItem : GeneralRowItem {
    let textLayout: TextViewLayout
    private(set) var revealed: Bool
    let reveal: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, text: String, revealed: Bool = false, viewType: GeneralViewType, reveal: @escaping()->Void) {
        self.reveal = reveal
        self.revealed = revealed
        self.textLayout = .init(.initialize(string: text, color: theme.colors.text, font: .normal(.text)), maximumNumberOfLines: revealed ? Int32.max : 2)
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override var height: CGFloat {
        return textLayout.layoutSize.height + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        textLayout.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        if textLayout.isPerfectSized {
            revealed = true
        }
        return true
    }
    
    override func viewClass() -> AnyClass {
        return TranslateTableRowView.self
    }
}


private final class MoreView : Control {
    private var more: TextView = TextView()
    private let shadowView = ShadowView()
    private let back: View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(back)
        addSubview(shadowView)
        addSubview(more)
        
//        let layer = CAGradientLayer()
//        layer.type = .radial
//        self.layer = layer
        
//        layer.colors = [theme.colors.background.withAlphaComponent(0).cgColor, theme.colors.background.cgColor];
//
//        layer.startPoint = CGPoint(x: 0.5, y: 0.5)
//        layer.endPoint = CGPoint(x: 0.0, y: 1)

        
        more.isSelectable = false
        more.userInteractionEnabled = false
        let layout = TextViewLayout(.initialize(string: strings().translateShowMore, color: theme.colors.accent, font: .medium(.text)))
        layout.measure(width: .greatestFiniteMagnitude)
        more.update(layout)
        
//        backgroundColor = theme.colors.background
        
        
        self.setFrameSize(NSMakeSize(layout.layoutSize.width + 30, layout.layoutSize.height + 2))
        
        scaleOnClick = true
        shadowView.shadowBackground = theme.colors.background
        shadowView.direction = .horizontal(true)
        back.backgroundColor = theme.colors.background

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        shadowView.frame = NSMakeRect(0, 0, 30, frame.height)
        back.frame = NSMakeRect(shadowView.frame.maxX, 0, frame.width - shadowView.frame.maxX, frame.height)
        more.centerY(x: frame.width - more.frame.width)
    }
}

private final class TranslateTableRowView : GeneralContainableRowView {
    private let textView = TextView()
    private var more: MoreView? = nil
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        guard let item = item as? TranslateTableRowItem else {
            return
        }
        transition.updateFrame(view: textView, frame: CGRect(origin: CGPoint(x: item.viewType.innerInset.left, y: item.viewType.innerInset.top), size: textView.frame.size))
        
        if let more = more {
            transition.updateFrame(view: more, frame: CGRect(origin: CGPoint(x: containerView.frame.width - item.viewType.innerInset.left - more.frame.width, y: containerView.frame.height - item.viewType.innerInset.top - more.frame.height + 1), size: more.frame.size))
        }
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? TranslateTableRowItem else {
            return
        }
        textView.update(item.textLayout)
        
        if !item.revealed {
            let current: MoreView
            if let view = self.more {
                current = view
            } else {
                let view = MoreView(frame: .zero)
                current = view
                addSubview(current)
                self.more = view
                current.set(handler: { [weak self] _ in
                    if let item = self?.item as? TranslateTableRowItem {
                        item.reveal()
                    }
                }, for: .Click)
            }
        } else if let view = self.more {
            self.more = nil
            performSubviewRemoval(view, animated: animated)
        }
    }
}
