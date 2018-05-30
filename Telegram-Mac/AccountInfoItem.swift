//
//  AccountInfoItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 09/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac



class AccountInfoItem: GeneralRowItem {
    
    fileprivate let textLayout: TextViewLayout
    fileprivate let activeTextlayout: TextViewLayout
    fileprivate let account: Account
    fileprivate let peer: TelegramUser

    
    init(_ initialSize:NSSize, stableId:AnyHashable, account: Account, peer: TelegramUser, action: @escaping()->Void) {
        self.account = account
        self.peer = peer
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: peer.displayTitle, color: theme.colors.text, font: .medium(.title))
        if let phone = peer.phone {
            _ = attr.append(string: "\n")
            _ = attr.append(string: formatPhoneNumber(phone), color: theme.colors.grayText, font: .normal(.text))
        }
        if let username = peer.username {
            _ = attr.append(string: "\n")
            _ = attr.append(string: "@\(username)", color: theme.colors.grayText, font: .normal(.text))
        }
        
        textLayout = TextViewLayout(attr, maximumNumberOfLines: 4)
        
        let active = attr.mutableCopy() as! NSMutableAttributedString
        active.addAttribute(.foregroundColor, value: NSColor.white, range: active.range)
        activeTextlayout = TextViewLayout(active, maximumNumberOfLines: 4)
        super.init(initialSize, height: 90, stableId: stableId, action: action)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat) -> Bool {
        
        textLayout.measure(width: width - 100)
        activeTextlayout.measure(width: width - 100)
        return super.makeSize(width, oldWidth: oldWidth)
    }
    
    override func viewClass() -> AnyClass {
        return AccountInfoView.self
    }
    
}

class AccountInfoView : TableRowView {
    
    
    private let avatarView:AvatarControl
    private let textView: TextView = TextView()
    private let actionView: ImageView = ImageView()
    required init(frame frameRect: NSRect) {
        avatarView = AvatarControl(font: .avatar(22.0))
        avatarView.setFrameSize(NSMakeSize(60, 60))
        super.init(frame: frameRect)

        avatarView.animated = true
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        addSubview(avatarView)
        addSubview(actionView)
        addSubview(textView)
        
        avatarView.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem, let _ = item.peer.largeProfileImage {
                showPhotosGallery(account: item.account, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        
    }
    
    override func mouseUp(with event: NSEvent) {
        if let item = item as? AccountInfoItem, mouseInside() {
            item.action()
        }
    }
    
    override var backdorColor: NSColor {
        return isSelect ? theme.colors.blueSelect : theme.colors.background
    }
    


    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? AccountInfoItem {
            actionView.image = item.isSelected ? nil : theme.icons.generalNext
            actionView.sizeToFit()
            avatarView.setPeer(account: item.account, peer: item.peer)
            textView.update(isSelect ? item.activeTextlayout : item.textLayout)
            needsDisplay = true
        }
    }
    
    override func updateColors() {
        super.updateColors()
        textView.backgroundColor = backdorColor
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
    }
    
    override func layout() {
        super.layout()
        avatarView.centerY(x:16)
        textView.centerY(x: avatarView.frame.maxX + 25)
        actionView.centerY(x: frame.width - actionView.frame.width - 10)
    }
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return avatarView
    }
    
    override func copy() -> Any {
        return avatarView.copy()
    }
    
}

