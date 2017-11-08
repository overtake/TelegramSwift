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

enum AccountInfoItemState {
    case normal
    case edit
}

class AccountInfoItem: TableRowItem {
    
    let saveCallback:()->Void
    var firstName:String
    var lastName:String
    
    let account: Account
    let peer: TelegramUser
    let connectionStatus: ConnectionStatus
    var state:AccountInfoItemState
    let statusLayout:(TextNodeLayout, TextNode)
    let nameLayout:(TextNodeLayout, TextNode)
    let editCallback:()->Void
    let imageCallback:()->Void
    private let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
    
    override var height:CGFloat {
        return 100
    }
    
    init(_ initialSize:NSSize, stableId:AnyHashable, account: Account, peer: TelegramUser, state:AccountInfoItemState, connectionStatus: ConnectionStatus, saveCallback:@escaping()->Void, editCallback:@escaping()->Void, imageCallback:@escaping()->Void) {
        self.saveCallback = saveCallback
        self.editCallback = editCallback
        self.imageCallback = imageCallback
        self.account = account
        self._stableId = stableId
        self.peer = peer
        self.state = state
        self.connectionStatus = connectionStatus
        self.firstName = peer.firstName ?? ""
        self.lastName = peer.lastName ?? ""
        let statusAttributed:NSAttributedString
        
        switch connectionStatus {
        case .connecting(let toProxy):
            statusAttributed = .initialize(string: toProxy ? tr(.connectingStatusConnectingToProxy) : tr(.connectingStatusConnecting), color: theme.colors.grayText, font: .normal(.text))
        case .online:
            statusAttributed = .initialize(string: tr(.connectingStatusOnline), color: theme.colors.blueUI, font: .normal(.text))
        case .updating:
            statusAttributed = .initialize(string: tr(.connectingStatusUpdating), color: theme.colors.grayText, font: .normal(.text))
        case .waitingForNetwork:
            statusAttributed = .initialize(string: tr(.connectingStatusWaitingNetwork), color: theme.colors.grayText, font: .normal(.text))
        }
        
        statusLayout = TextNode.layoutText(maybeNode: nil,  statusAttributed, nil, 1, .end, NSMakeSize(initialSize.width - 140, 20), nil, false, .left)
        nameLayout = TextNode.layoutText(maybeNode: nil,  .initialize(string: peer.displayTitle, color: theme.colors.text, font: .normal(.title)), nil, 1, .end, NSMakeSize(initialSize.width - 140, 20), nil, false, .left)
        
        super.init(initialSize)
    }
    
    override func viewClass() -> AnyClass {
        return AccountInfoView.self
    }
    
}

class AccountInfoView : TableRowView, TGModernGrowingDelegate {
    
    
    let avatarView:AvatarControl
    let firstNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    let lastNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let editButton: ImageButton = ImageButton()
    private let updoadPhotoCap:ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        avatarView = AvatarControl(font: .avatar(.custom(22)))
        avatarView.setFrameSize(NSMakeSize(60, 60))
        super.init(frame: frameRect)

        avatarView.animated = true
        
        addSubview(avatarView)
        addSubview(firstNameTextView)
        addSubview(lastNameTextView)
        addSubview(editButton)
        
        updoadPhotoCap.backgroundColor = NSColor.black.withAlphaComponent(0.4)
        updoadPhotoCap.setFrameSize(avatarView.frame.size)
        updoadPhotoCap.layer?.cornerRadius = updoadPhotoCap.frame.width / 2
        updoadPhotoCap.set(image: ControlStyle(highlightColor: .white).highlight(image: theme.icons.chatAttachCamera), for: .Normal)
        updoadPhotoCap.set(image: ControlStyle(highlightColor: theme.colors.blueIcon).highlight(image: theme.icons.chatAttachCamera), for: .Highlight)

        avatarView.addSubview(updoadPhotoCap)
        
        avatarView.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem, let _ = item.peer.largeProfileImage {
                showPhotosGallery(account: item.account, peerId: item.peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        firstNameTextView.textColor = theme.colors.text
        lastNameTextView.textColor = theme.colors.text

        firstNameTextView.delegate = self
        firstNameTextView.textFont = .normal(.title)
        firstNameTextView.min_height = 17
        firstNameTextView.isSingleLine = true
        firstNameTextView.max_height = 17
        
        lastNameTextView.delegate = self
        lastNameTextView.textFont = .normal(.title)
        lastNameTextView.min_height = 17
        lastNameTextView.max_height = 17
        lastNameTextView.isSingleLine = true
        
        editButton.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem {
                item.editCallback()
            }
        }, for: .Click)
        
        updoadPhotoCap.set(handler: { [weak self] _ in
            if let item = self?.item as? AccountInfoItem {
                item.imageCallback()
            }
        }, for: .Click)
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override var firstResponder: NSResponder? {
        if window?.firstResponder == lastNameTextView.inputView || window?.firstResponder == firstNameTextView.inputView {
            return window?.firstResponder
        }
        return self.firstNameTextView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
    }
    
    func maxCharactersLimit() -> Int32 {
        return 30
    }
    
    func textViewSize() -> NSSize {
        return NSMakeSize(frame.width - (avatarView.frame.maxX + 10), 17)
    }
    
    func textViewEnterPressed(_ event:NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
            if let item = item as? AccountInfoItem {
                item.firstName = self.firstNameTextView.string()
                item.lastName = self.lastNameTextView.string()
                item.saveCallback()
            }
            return true
        }
        return false
    }
    
    func textViewIsTypingEnabled() -> Bool {
        return true
    }
    
    func textViewNeedClose(_ textView: Any) {
        
    }
    
    func textViewTextDidChange(_ string: String) {
        if let item = item as? AccountInfoItem {
            item.firstName = self.firstNameTextView.string()
            item.lastName = self.lastNameTextView.string()
        }
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }

    
    
    override func set(item: TableRowItem, animated: Bool) {
        super.set(item: item)
        
        if let item = item as? AccountInfoItem {
            editButton.set(image: theme.icons.settingsEditInfo, for: .Normal)
            editButton.sizeToFit()
            firstNameTextView.textColor = theme.colors.text
            lastNameTextView.textColor = theme.colors.text
            avatarView.setPeer(account: item.account, peer: item.peer)
            firstNameTextView.setString(item.peer.firstName ?? "")
            lastNameTextView.setString(item.peer.lastName ?? "")
            
            if item.state != .normal {
                updoadPhotoCap.isHidden = false
            }
            
            if item.state == .normal {
                editButton.isHidden = false
            }

            
            updoadPhotoCap.change(opacity: item.state == .normal ? 0 : 1, animated: animated, completion: { [weak self, weak item] completed in
                if completed, let item = item {
                    self?.updoadPhotoCap.isHidden = item.state == .normal
                }
            })
            
            editButton.change(opacity: item.state != .normal ? 0 : 1, animated: animated, completion: { [weak self, weak item] completed in
                if completed, let item = item {
                    self?.editButton.isHidden = item.state != .normal
                }
            })
            
            firstNameTextView.isHidden = item.state == .normal
            lastNameTextView.isHidden = item.state == .normal
            needsDisplay = true
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(theme.colors.border.cgColor)
        ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
        
        if let item = item as? AccountInfoItem {
            if item.state == .normal {
                var tY = NSMinY(focus(item.nameLayout.0.size))
                
                let t = item.nameLayout.0.size.height + item.statusLayout.0.size.height + 4.0
                tY = (NSHeight(self.frame) - t) / 2.0
                
                let sY = tY + item.statusLayout.0.size.height + 4.0
                item.statusLayout.1.draw(NSMakeRect(100, floorToScreenPixels(sY), item.statusLayout.0.size.width, item.statusLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                
                item.nameLayout.1.draw(NSMakeRect(100, floorToScreenPixels(tY), item.nameLayout.0.size.width, item.nameLayout.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
            } else {
                ctx.fill(NSMakeRect((avatarView.frame.maxX + 12), 46, frame.width - (avatarView.frame.maxX + 20), .borderSize))
                ctx.fill(NSMakeRect((avatarView.frame.maxX + 12), 74, frame.width - (avatarView.frame.maxX + 20), .borderSize))
            }
            
        }
    }
    
    override func layout() {
        super.layout()
        avatarView.centerY(x:16)
        firstNameTextView.setFrameSize(frame.width - (avatarView.frame.maxX + 16), 17)
        lastNameTextView.setFrameSize(frame.width - (avatarView.frame.maxX + 16), 17)
        
        firstNameTextView.setFrameOrigin((avatarView.frame.maxX + 10), 27)
        lastNameTextView.setFrameOrigin((avatarView.frame.maxX + 10), 55)
        editButton.centerY(x: frame.width - editButton.frame.width - 19)
    }
    
    
    override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        return avatarView
    }
    
    override func copy() -> Any {
        return avatarView.copy()
    }
    
}
