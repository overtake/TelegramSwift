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
    init(_ initialSize: NSSize, stableId: AnyHashable, account: Account, authorization: WebAuthorization, peer: Peer, viewType: GeneralViewType, logout:@escaping()->Void) {
        self.logoutInteraction = logout
        self.account = account
        self.photo = .PeerAvatar(peer, peer.displayLetters, peer.smallProfileImage, nil)
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
        super.init(initialSize, height: 80, stableId: stableId, viewType: viewType, inset: NSEdgeInsetsMake(0, 30, 0, 30))
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        dateLayout.measure(width: .greatestFiniteMagnitude)
        nameLayout.measure(width: width - (inset.left + inset.right) - 20 - dateLayout.layoutSize.width)
        statusLayout.measure(width: width - (inset.left + inset.right))
        
        return success
    }
    
    override func viewClass() -> AnyClass {
        return WebAuthorizationRowView.self
    }
    
}


private class WebAuthorizationRowView : TableRowView, ViewDisplayDelegate {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let botNameView: TextView = TextView()
    private let statusTextView: TextView = TextView()
    private let dateView: TextView = TextView()
    private let photoView: AvatarControl = AvatarControl(font: .avatar(8))
    private let logoutButton: TitleButton = TitleButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        botNameView.isSelectable = false
        botNameView.userInteractionEnabled = false
        containerView.addSubview(botNameView)
        containerView.addSubview(statusTextView)
        containerView.addSubview(dateView)
        containerView.addSubview(photoView)
        containerView.addSubview(logoutButton)
        photoView.setFrameSize(16, 16)
        
        
        addSubview(containerView)
        
        containerView.displayDelegate = self
        
        logoutButton.set(handler: { [weak self] _ in
            guard let item = self?.item as? WebAuthorizationRowItem else {return}
            item.logoutInteraction()
        }, for: .Click)
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? WebAuthorizationRowItem else {return}
        
        switch item.viewType {
        case .legacy:
            self.containerView.frame = bounds
            self.containerView.setCorners([])
            photoView.setFrameOrigin(item.inset.left, item.inset.top + 2)
            botNameView.setFrameOrigin(photoView.frame.maxX + 4, item.inset.top)
            statusTextView.setFrameOrigin(item.inset.left, botNameView.frame.maxY + 4)
            dateView.setFrameOrigin(self.containerView.frame.width - item.inset.right - dateView.frame.width, item.inset.top)
            logoutButton.setFrameOrigin(self.containerView.frame.width - logoutButton.frame.width - 25, self.containerView.frame.height - logoutButton.frame.height - 10)
        case let .modern(position, innerInsets):
            self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
            self.containerView.setCorners(position.corners)
            photoView.setFrameOrigin(innerInsets.left, innerInsets.top + 2)
            botNameView.setFrameOrigin(photoView.frame.maxX + 4, innerInsets.top)
            statusTextView.setFrameOrigin(innerInsets.left, botNameView.frame.maxY + 8)
            dateView.setFrameOrigin(self.containerView.frame.width - innerInsets.right - dateView.frame.width, innerInsets.top)
            logoutButton.setFrameOrigin(self.containerView.frame.width - logoutButton.frame.width - innerInsets.right + 4, self.containerView.frame.height - logoutButton.frame.height - 10)
        }

        
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        guard let item = item as? WebAuthorizationRowItem, layer == containerView.layer else {return}

        ctx.setFillColor(theme.colors.border.cgColor)

        switch item.viewType {
        case .legacy:
            ctx.fill(NSMakeRect(item.inset.left, frame.height - .borderSize, frame.width - item.inset.left, .borderSize))
        case let .modern(position, insets):
            if position.border {
                ctx.fill(NSMakeRect(insets.left, containerView.frame.height - .borderSize, containerView.frame.width - insets.left, .borderSize))
            }
        }
        
    }
    
    override func updateColors() {
        guard let item = item as? WebAuthorizationRowItem else {return}
        logoutButton.set(background: backdorColor, for: .Normal)
        botNameView.backgroundColor = backdorColor
        statusTextView.backgroundColor = backdorColor
        dateView.backgroundColor = backdorColor
        containerView.backgroundColor = backdorColor
        self.background = item.viewType.rowBackground
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WebAuthorizationRowItem else {return}
        
        switch item.viewType {
        case .legacy:
            containerView.setCorners([], animated: animated)
        case let .modern(position, _):
            containerView.setCorners(position.corners, animated: animated)
        }
        
        self.photoView.setState(account: item.account, state: item.photo)
        self.botNameView.update(item.nameLayout)
        self.statusTextView.update(item.statusLayout)
        self.dateView.update(item.dateLayout)
        
        logoutButton.set(color: theme.colors.accent, for: .Normal)
        logoutButton.set(font: .medium(.text), for: .Normal)
        logoutButton.set(text: L10n.webAuthorizationsLogout, for: .Normal)
        _ = logoutButton.sizeToFit()
        
        needsLayout = true
    }
}
