//
//  DiscussionHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit


class DiscussionHeaderItem: GeneralRowItem {
    fileprivate let icon: CGImage
    fileprivate let textLayout: TextViewLayout
    init(_ initialSize: NSSize, stableId: AnyHashable, icon: CGImage, text: NSAttributedString) {
        self.icon = icon
        self.textLayout = TextViewLayout(text, alignment: .center, alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId, inset: NSEdgeInsets(left: 30.0, right: 30.0, top: 10, bottom: 10))
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - inset.left - inset.right)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return DiscussionHeaderView.self
    }
    
    override var height: CGFloat {
        return inset.top + inset.bottom + icon.backingSize.height + inset.top + textLayout.layoutSize.height
    }
}


private final class DiscussionHeaderView : TableRowView {
    private let imageView: ImageView = ImageView()
    private let textView: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
    }
    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? DiscussionHeaderItem else { return }
        
        self.imageView.image = item.icon
        self.imageView.sizeToFit()
        
        self.textView.update(item.textLayout)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? DiscussionHeaderItem else { return }

        self.imageView.centerX(y: item.inset.top)
        self.textView.centerX(y: self.imageView.frame.maxY + item.inset.top)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
