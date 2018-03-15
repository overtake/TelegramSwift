//
//  WebAuthorizationRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class WebAuthorizationRowItem: GeneralRowItem {

    fileprivate let account: Account
    fileprivate let nameLayout: TextViewLayout
    fileprivate let photo: AvatarNodeState
    fileprivate let statusLayout: TextViewLayout
    fileprivate let dateLayout: TextViewLayout
    fileprivate let logoutInteraction:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, authorization: WebAuthorization, peer: Peer, logout:@escaping()->Void) {
        self.logoutInteraction = logout
        self.account = account
        self.photo = .PeerAvatar(peer.id, peer.displayLetters, peer.smallProfileImage)
        self.nameLayout = TextViewLayout(.initialize(string: peer.displayTitle, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        let statusAttr = NSMutableAttributedString()
        
        _ = statusAttr.append(string: authorization.domain, color: theme.colors.text, font: .normal(.text))
        _ = statusAttr.append(string: ", ", color: theme.colors.grayText)
        _ = statusAttr.append(string: authorization.browser, color: theme.colors.text, font: .normal(.text))
        _ = statusAttr.append(string: ", ", color: theme.colors.grayText)
        _ = statusAttr.append(string: authorization.platform, color: theme.colors.text, font: .normal(.text))
        
        _ = statusAttr.append(string: "\n")
        
        _ = statusAttr.append(string: authorization.ip, color: theme.colors.grayText, font: .normal(.text))
        _ = statusAttr.append(string: " ● ", color: theme.colors.grayText)
        _ = statusAttr.append(string: authorization.region, color: theme.colors.grayText, font: .normal(.text))
        
        self.statusLayout = TextViewLayout(statusAttr, maximumNumberOfLines: 2)
        self.dateLayout = TextViewLayout(.initialize(string: DateUtils.string(forMessageListDate: authorization.dateActive), color: theme.colors.grayText, font: .normal(.text)))
        super.init(initialSize, height: 70, stableId: stableId, inset: NSEdgeInsetsMake(7, 30, 3, 30))
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        
        dateLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: width - (inset.left + inset.right) - 20 - dateLayout.layoutSize.width)
        statusLayout.measure(width: width - (inset.left + inset.right))
        
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return WebAuthorizationRowView.self
    }
    
}


private class WebAuthorizationRowView : TableRowView {
    private let botNameView: TextView = TextView()
    private let statusTextView: TextView = TextView()
    private let dateView: TextView = TextView()
    private let photoView: AvatarControl = AvatarControl(font: .avatar(8))
    private let logoutButton: TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        botNameView.isSelectable = false
        botNameView.userInteractionEnabled = false
        addSubview(botNameView)
        addSubview(statusTextView)
        addSubview(dateView)
        addSubview(photoView)
        addSubview(logoutButton)
        photoView.setFrameSize(16, 16)
        
        
        logoutButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? WebAuthorizationRowItem else {return}
            item.logoutInteraction()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WebAuthorizationRowItem else {return}

        photoView.setFrameOrigin(item.inset.left, item.inset.top + 2)
        botNameView.setFrameOrigin(photoView.frame.maxX + 4, item.inset.top)
        statusTextView.setFrameOrigin(item.inset.left, botNameView.frame.maxY + 4)
        dateView.setFrameOrigin(frame.width - item.inset.right - dateView.frame.width, item.inset.top)
        
        logoutButton.setFrameOrigin(frame.width - logoutButton.frame.width - 25, frame.height - logoutButton.frame.height - 10)
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        guard let item = item as? WebAuthorizationRowItem else {return}

        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left, .borderSize))
        
    }
    
    override func updateColors() {
        logoutButton.set(background: theme.colors.background, for: .Normal)
        botNameView.backgroundColor = theme.colors.background
        statusTextView.backgroundColor = theme.colors.background
        dateView.backgroundColor = theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WebAuthorizationRowItem else {return}
        
        self.photoView.setState(account: item.account, state: item.photo)
        self.botNameView.update(item.nameLayout)
        self.statusTextView.update(item.statusLayout)
        self.dateView.update(item.dateLayout)
        
        logoutButton.set(color: theme.colors.blueUI, for: .Normal)
        logoutButton.set(font: .medium(.text), for: .Normal)
        logoutButton.set(text: L10n.webAuthorizationsLogout, for: .Normal)
        _ = logoutButton.sizeToFit()
        
        needsLayout = true
    }
}
