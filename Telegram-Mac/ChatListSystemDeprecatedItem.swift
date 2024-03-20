//
//  ChatListSystemDeprecatedItem.swift
//  Telegram
//
//  Created by Mike Renoir on 21.03.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit

final class ChatListSystemDeprecatedItem : GeneralRowItem {
    fileprivate let title: TextViewLayout
    fileprivate let text: TextViewLayout
    fileprivate let hideAction:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, hideAction: @escaping()->Void) {
        self.hideAction = hideAction
        self.title = .init(.initialize(string: strings().deprecatedTitle, color: theme.colors.text, font: .medium(.title)))
        self.text = .init(.initialize(string: strings().deprecatedText, color: theme.colors.grayText, font: .normal(.text)))

        super.init(initialSize, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        title.measure(width: width - 40)
        text.measure(width: width - 40)

        return true
    }
    
    override var height: CGFloat {
        return 10 + title.layoutSize.height + 6 + text.layoutSize.height + 10
    }
    
    override func viewClass() -> AnyClass {
        return ChatListSystemDeprecatedItemView.self
    }
}

private final class ChatListSystemDeprecatedItemView : TableRowView {
    private let title = TextView()
    private let text = TextView()
    private let control = Control()
    private let next = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(control)
        addSubview(title)
        addSubview(text)
        addSubview(next)
        
        next.isEventLess = true
        
        title.isSelectable = false
        title.userInteractionEnabled = false
        title.isEventLess = true
        
        text.isSelectable = false
        text.userInteractionEnabled = false
        text.isEventLess = true
        
        control.border = [.Bottom]
        
        control.set(handler: { [weak self] control in
            if let window = control._window {
                verifyAlert_button(for: window, header: strings().deprecatedAlertTitle, information: strings().deprecatedAlertText, cancel: "", option: strings().deprecatedAlertThird, successHandler: { result in
                    if result == .thrid {
                        if let item = self?.item as? ChatListSystemDeprecatedItem {
                            item.hideAction()
                        }
                    }
                })
            }
        }, for: .Click)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        transition.updateFrame(view: title, frame: CGRect(origin: NSMakePoint(10, 10), size: title.frame.size))
        transition.updateFrame(view: text, frame: CGRect(origin: NSMakePoint(10, title.frame.maxY + 6), size: text.frame.size))
        
        transition.updateFrame(view: next, frame: next.centerFrameY(x: size.width - 10 - next.frame.width))
        transition.updateFrame(view: control, frame: size.bounds)

    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? ChatListSystemDeprecatedItem else {
            return
        }
        title.update(item.title)
        text.update(item.text)
        
        control.set(background: theme.colors.background, for: .Normal)
        control.set(background: theme.colors.grayTransparent, for: .Highlight)

        control.borderColor = theme.colors.border
        next.image = theme.icons.generalNext
        next.sizeToFit()
        
        needsLayout = true
    }
}
