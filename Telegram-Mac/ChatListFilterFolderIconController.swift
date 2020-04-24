//
//  ChatListFilterFolderIconController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/04/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

final class ChatListFolderIconsView : View {
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initialize(callback: @escaping(FolderIcon)->Void) {
        removeAllSubviews()
        
        for icon in allSidebarFolderIcons {
            let control = ImageButton(frame: NSMakeRect(0, 0, 40, 40))
            control.set(image: icon.icon(for: .settings), for: .Normal)
            addSubview(control)
            control.set(handler: { _ in
                callback(icon)
            }, for: .Click)
        }
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        var x: CGFloat = 10
        var y: CGFloat = 10
        for (i, subview) in subviews.enumerated() {
            subview.setFrameOrigin(NSMakePoint(x, y))
            x += subview.frame.width
            if (i + 1) % 5 == 0 {
                x = 10
                y += subview.frame.height
            }
        }
    }
}

class ChatListFilterFolderIconController: TelegramGenericViewController<ChatListFolderIconsView> {
    private let select:(FolderIcon)->Void
    init(_ context: AccountContext, select: @escaping(FolderIcon)->Void) {
        self.select = select
        super.init(context)
        _frameRect = NSMakeRect(0, 0, 40 * 5 + 20, ceil(CGFloat(allSidebarFolderIcons.count) / 5) * 40 + 20)
        bar = .init(height: 0)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genericView.initialize(callback: { [weak self] value in
            self?.select(value)
            self?.closePopover()
        })
        readyOnce()
    }
}
