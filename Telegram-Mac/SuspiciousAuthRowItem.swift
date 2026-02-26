//
//  SuspiciousAuthRowItem.swift
//  Telegram
//
//  Created by Mike Renoir on 01.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import TelegramCore

final class SuspiciousAuthRowItem: GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let session: NewSessionReview
    fileprivate let accept:(NewSessionReview)->Void
    fileprivate let revoke:(NewSessionReview)->Void
    
    fileprivate let title: TextViewLayout
    fileprivate let info: TextViewLayout

    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, session: NewSessionReview, accept:@escaping(NewSessionReview)->Void, revoke:@escaping(NewSessionReview)->Void) {
        self.context = context
        self.session = session
        self.revoke = revoke
        self.accept = accept
        
        self.title = .init(.initialize(string: strings().newSessionReviewItemTitle, color: theme.colors.text, font: .medium(.title)), alignment: .center)
        
        self.info = .init(.initialize(string: strings().newSessionReviewItemText(session.device, session.location), color: theme.colors.grayText, font: .normal(.text)), alignment: .center)

        
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        
        height += 10
        height += title.layoutSize.height
        height += 4
        height += info.layoutSize.height
        height += 10
        height += 20
        
        height += 10
        
        return height
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title.measure(width: width - 40)
        self.info.measure(width: width - 40)

        return true
    }
    
    func _revoke() {
        self.revoke(self.session)
    }
    func _accept() {
        self.accept(self.session)
    }
    
    override func viewClass() -> AnyClass {
        return SuspiciousAuthRowView.self
    }
}


private final class SuspiciousAuthRowView : GeneralRowView {
    private let titleView = TextView()
    private let infoView = TextView()
    private let accept = TextButton()
    private let revoke = TextButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        addSubview(titleView)
        addSubview(infoView)
        addSubview(accept)
        addSubview(revoke)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        infoView.userInteractionEnabled = false
        infoView.isSelectable = false


        accept.scaleOnClick = true
        accept.autoSizeToFit = false
        
        revoke.scaleOnClick = true
        revoke.autoSizeToFit = false
        
        accept.set(handler: { [weak self] _ in
            if let item = self?.item as? SuspiciousAuthRowItem {
                item._accept()
            }
        }, for: .Click)
        
        revoke.set(handler: { [weak self] _ in
            if let item = self?.item as? SuspiciousAuthRowItem {
                item._revoke()
            }
        }, for: .Click)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.grayBackground
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? SuspiciousAuthRowItem else {
            return
        }
        
        titleView.update(item.title)
        infoView.update(item.info)
        
        accept.set(font: .medium(.text), for: .Normal)
        accept.set(text: strings().newSessionItsMe, for: .Normal)
        accept.set(color: theme.colors.accent, for: .Normal)
        accept.sizeToFit()
        
        revoke.set(font: .medium(.text), for: .Normal)
        revoke.set(text: strings().newSessionIsntMe, for: .Normal)
        revoke.set(color: theme.colors.redUI, for: .Normal)
        revoke.sizeToFit()
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        
        titleView.centerX(y: 10)
        infoView.centerX(y: titleView.frame.maxY + 4)
        
        accept.setFrameOrigin(NSMakePoint(floorToScreenPixels(backingScaleFactor, (frame.width / 2 - accept.frame.width) / 2), infoView.frame.maxY + 10))
        
        revoke.setFrameOrigin(NSMakePoint(floorToScreenPixels(backingScaleFactor, frame.width / 2 + (frame.width / 2 - accept.frame.width) / 2), infoView.frame.maxY + 10))

    }
}
