//
//  PollResultStickItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/01/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class PollResultStickItem: TableStickItem {
    
    let leftLayout:TextViewLayout
    let rightLayout: TextViewLayout
    let viewType: GeneralViewType
    let inset: NSEdgeInsets
    let collapse: (()->Void)?
    let _stableId: AnyHashable
    init(_ initialSize:NSSize, stableId: AnyHashable, left: String, right: String, collapse: (()->Void)?, viewType: GeneralViewType) {
        self.viewType = viewType
        self._stableId = stableId
        self.inset = NSEdgeInsets(left: 30, right: 30)
        self.collapse = collapse
        self.leftLayout = TextViewLayout(.initialize(string: left, color: theme.colors.listGrayText, font: .normal(11.5)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
        
        if let collapse = collapse {
            
            let attrs = parseMarkdownIntoAttributedString(L10n.pollResultsCollapse, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(11.5), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(11.5), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .normal(11.5), textColor: theme.colors.link), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents,  { _ in }))
            }))
            
            self.rightLayout = TextViewLayout(attrs, maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
            self.rightLayout.interactions = TextViewInteractions(processURL: { _ in
                collapse()
            })
        } else {
            self.rightLayout = TextViewLayout(.initialize(string: right, color: theme.colors.listGrayText, font: .normal(11.5)), maximumNumberOfLines: 1, truncationType: .end, alignment: .center)
        }
        

        
        super.init(initialSize)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    

    
    override var canBeAnchor: Bool {
        return false
    }
    
    required init(_ initialSize: NSSize) {
        self.viewType = .legacy
        self.leftLayout = TextViewLayout(NSAttributedString())
        self.rightLayout = TextViewLayout(NSAttributedString())
        self.inset = NSEdgeInsets(left: 30, right: 30)
        self.collapse = nil
        self._stableId = arc4random()
        super.init(initialSize)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        rightLayout.measure(width: .greatestFiniteMagnitude)
        
        let blockWidth = min(600, width - inset.left - inset.right)
        leftLayout.measure(width: blockWidth - rightLayout.layoutSize.width - viewType.innerInset.left * 2)
        
        return success
    }
    
    override var stableId: AnyHashable {
        return self._stableId
    }
    
    override var height: CGFloat {
        return 30
    }
    
    override func viewClass() -> AnyClass {
        return PollResultStickView.self
    }
    
}


private final class PollResultStickView : TableStickView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let textView = TextView()
    private let rightView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
        containerView.addSubview(self.textView)
        containerView.addSubview(self.rightView)
        self.textView.disableBackgroundDrawing = true
        self.textView.isSelectable = false
        self.textView.userInteractionEnabled = false
        
        
        self.rightView.disableBackgroundDrawing = true
        self.rightView.isSelectable = false
        
    }
    
    override var header: Bool {
        didSet {
            updateColors()
        }
    }
    
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        guard let item = item as? PollResultStickItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? PollResultStickItem else {
            return
        }
        
        let blockWidth = min(600, frame.width - item.inset.left - item.inset.right)
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), item.inset.top, blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners([])
        
        textView.centerY(x: item.viewType.innerInset.left)
        rightView.centerY(x: self.containerView.frame.width - item.viewType.innerInset.left - rightView.frame.width)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PollResultStickItem else {
            return
        }
        self.textView.update(item.leftLayout)
        self.rightView.update(item.rightLayout)

        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
