//
//  ChatListGraceRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 04.04.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatListGraceRowItem : GeneralRowItem {
    let title: TextViewLayout
    let info: TextViewLayout
    let context: AccountContext
    let canClose: Bool
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, canClose: Bool) {
        self.context = context
        self.canClose = canClose
        self.title = .init(.initialize(string: strings().chatListGracePeriodTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        self.info = .init(.initialize(string: strings().chatListGracePeriodInfo, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 2)
        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 20 - 15)
        self.info.measure(width: width - 20 - 15)
        return true
    }
    
    func invoke() {
        prem(with: PremiumBoardingController(context: context, source: .grace_period), for: context.window)
        let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.gracePremium.id).startStandalone()
    }
    
    func dismiss() {
    }
    
    override func viewClass() -> AnyClass {
        return ChatListGraceRowView.self
    }
    
    override var height: CGFloat {
        return 8 + title.layoutSize.height + 3 + info.layoutSize.height + 8
    }
}


private final class ChatListGraceRowView: TableRowView {
    private let titleView = TextView()
    private let infoView = TextView()
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
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false
        
        overlay.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListGraceRowItem {
                item.invoke()
            }

        }, for: .Click)
        
        dismiss.set(handler: { [weak self] control in
            if let item = self?.item as? ChatListGraceRowItem {
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
        
        guard let item = item as? ChatListGraceRowItem else {
            return
        }
        
        self.titleView.update(item.title)
        self.infoView.update(item.info)
        
        dismiss.set(image: NSImage(resource: .iconVoiceChatTooltipClose).precomposed(theme.colors.grayIcon), for: .Normal)
        dismiss.autohighlight = false
        dismiss.scaleOnClick = true
        dismiss.sizeToFit(NSMakeSize(10, 10))
        
        dismiss.isHidden = !item.canClose

        borderView.backgroundColor = theme.colors.border
    }
}
