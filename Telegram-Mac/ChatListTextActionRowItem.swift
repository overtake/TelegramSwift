//
//  ChatListStarsNeedRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08.07.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit

final class ChatListTextActionRowItem : GeneralRowItem {
    let title: TextViewLayout
    let info: TextViewLayout
    let context: AccountContext
    let canDismiss: Bool
    let dismiss: ()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, title: NSAttributedString, info: NSAttributedString, canDismiss: Bool, action: @escaping()->Void, dismiss:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        self.title = .init(title, maximumNumberOfLines: 1)
        self.info = .init(info)
        self.canDismiss = canDismiss
        
        self.info.interactions = globalLinkExecutor
        
        super.init(initialSize, stableId: stableId, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 20 - 15)
        self.info.measure(width: width - 20 - 15)
        return true
    }
    
    func invoke() {
        action()
    }
    
    
    override func viewClass() -> AnyClass {
        return ChatListTextActionRowView.self
    }
    
    override var height: CGFloat {
        return 8 + title.layoutSize.height + 3 + info.layoutSize.height + 8
    }
}


private final class ChatListTextActionRowView: TableRowView {
    private let titleView = InteractiveTextView()
    private let infoView = InteractiveTextView()
    private let overlay = Control()
    private let dismiss = ImageButton()
    private let borderView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(titleView)
        addSubview(infoView)
        
        addSubview(borderView)
        addSubview(overlay)
        addSubview(dismiss)
        titleView.userInteractionEnabled = false
        
        infoView.userInteractionEnabled = false
        
        
        overlay.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListTextActionRowItem {
                item.invoke()
            }

        }, for: .Click)
        
        dismiss.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListTextActionRowItem {
                item.dismiss()
            }
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        overlay.frame = bounds
        titleView.setFrameOrigin(NSMakePoint(10, 8))
        infoView.setFrameOrigin(NSMakePoint(10, frame.height - infoView.frame.height - 8))
        borderView.frame = NSMakeRect(0, frame.height - .borderSize, frame.width, .borderSize)

        dismiss.centerY(x: frame.width - 10 - dismiss.frame.width)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListTextActionRowItem else {
            return
        }
        
        overlay.set(background: theme.colors.grayForeground.withAlphaComponent(0.1), for: .Highlight)
        overlay.set(background: .clear, for: .Hover)
        overlay.set(background: .clear, for: .Normal)

        dismiss.isHidden = !item.canDismiss
        
//        if !item.canDismiss {
//            overlay.userInteractionEnabled = false
//            overlay.isEventLess = true
//            infoView.userInteractionEnabled = true
//            infoView.textView.userInteractionEnabled = true
//        }
//        
        self.titleView.set(text: item.title, context: item.context)
        self.infoView.set(text: item.info, context: item.context)
        
        dismiss.set(image: NSImage(resource: .iconVoiceChatTooltipClose).precomposed(theme.colors.grayIcon), for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit(NSMakeSize(10, 10))
        
        borderView.backgroundColor = theme.colors.border
    }
}
