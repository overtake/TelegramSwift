//
//  DiscussionHeaderItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import TGUIKit
import Foundation
import TelegramMedia

class AnimatedStickerHeaderItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let textLayout: TextViewLayout
    fileprivate let sticker: LocalAnimatedSticker
    let stickerSize: NSSize
    let bgColor: NSColor?
    let modify:[String]?
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, sticker: LocalAnimatedSticker, text: NSAttributedString, stickerSize: NSSize = NSMakeSize(120, 120), bgColor: NSColor? = nil, modify:[String]? = nil) {
        self.context = context
        self.sticker = sticker
        self.stickerSize = stickerSize
        self.bgColor = bgColor
        self.modify = modify
        self.textLayout = TextViewLayout(text, alignment: .center, alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId, inset: NSEdgeInsets(left: 20, right: 20, top: 0, bottom: 10))
        
        self.textLayout.interactions = globalLinkExecutor
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        textLayout.measure(width: width - inset.left - inset.right)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return AnimtedStickerHeaderView.self
    }
    
    override var height: CGFloat {
        return inset.top + inset.bottom + stickerSize.height + inset.top + textLayout.layoutSize.height
    }
}


private final class AnimtedStickerHeaderView : TableRowView {
    private let imageView: MediaAnimatedStickerView = MediaAnimatedStickerView(frame: .zero)
    private let textView: TextView = TextView()
    private var bgView: View?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        
        textView.isSelectable = false
        textView.userInteractionEnabled = true
    }
    
    override var backdorColor: NSColor {
        return theme.colors.listBackground
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? AnimatedStickerHeaderItem else { return }
        
        let params = item.sticker.parameters
        
        if let modify = item.modify, let color = item.bgColor {
            params.colors = modify.map {
                .init(keyPath: $0, color: color)
            }
        }
        
        imageView.update(with: item.sticker.file, size: item.stickerSize, context: item.context, parent: nil, table: item.table, parameters: params, animated: animated, positionFlags: nil, approximateSynchronousValue: false)
        
//        self.imageView.image = item.icon
//        self.imageView.sizeToFit()
        
        self.textView.update(item.textLayout)
        
        if let bgColor = item.bgColor {
            if self.bgView == nil {
                self.bgView = View()
                self.addSubview(self.bgView!, positioned: .below, relativeTo: self.imageView)
            }
            self.bgView?.backgroundColor = bgColor
            self.bgView?.setFrameSize(item.stickerSize)
            self.bgView?.layer?.cornerRadius = 10
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? AnimatedStickerHeaderItem else { return }

        self.imageView.centerX(y: item.inset.top)
        self.textView.centerX(y: self.imageView.frame.maxY + item.inset.bottom)
        
        self.bgView?.frame = self.imageView.frame
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
