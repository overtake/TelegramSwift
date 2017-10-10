//
//  ChatUserPopover.swift
//  Telegram
//
//  Created by keepcoder on 5/6/17.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac





private class ChatUserPopoverView : View {
    private let avatar:AvatarControl = AvatarControl(font: .avatar(.text))
    private let nameView:TextView = TextView()
    private let lastSeen:TextView = TextView()
    private let callButton: ImageButton = ImageButton()
    private let messageButton:ImageButton = ImageButton()
    private let infoButton:ImageButton = ImageButton()
    private let buttonsContainer:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        avatar.setFrameSize(NSMakeSize(40, 40))
        addSubview(avatar)
        addSubview(nameView)
        addSubview(lastSeen)
        addSubview(buttonsContainer)
        buttonsContainer.addSubview(callButton)
        buttonsContainer.addSubview(messageButton)
        buttonsContainer.addSubview(infoButton)
        
        
        callButton.set(image: #imageLiteral(resourceName: "Icon_DetailedCall").precomposed(.blueUI), for: .Normal)
        callButton.setFrameSize(NSMakeSize(26, 26))
        callButton.layer?.cornerRadius = 13
        callButton.layer?.borderColor = NSColor(0xe7e7ec).cgColor
        callButton.layer?.borderWidth = 1
        callButton.set(background: NSColor(0xf8f8fe), for: .Normal)
        
        
        messageButton.set(image: #imageLiteral(resourceName: "Icon_DetailedMessage").precomposed(.blueUI), for: .Normal)
        messageButton.setFrameSize(NSMakeSize(26, 26))
        messageButton.layer?.cornerRadius = 13
        messageButton.layer?.borderColor = NSColor(0xe7e7ec).cgColor
        messageButton.layer?.borderWidth = 1
        messageButton.set(background: NSColor(0xf8f8fe), for: .Normal)
        
        
        infoButton.set(image: #imageLiteral(resourceName: "Icon_DetailedInfo").precomposed(.blueUI), for: .Normal)
        infoButton.setFrameSize(NSMakeSize(26, 26))
        infoButton.layer?.cornerRadius = 13
        infoButton.layer?.borderColor = NSColor(0xe7e7ec).cgColor
        infoButton.layer?.borderWidth = 1
        infoButton.set(background: NSColor(0xf8f8fe), for: .Normal)
        
        messageButton.setFrameOrigin(0, 0)
        callButton.setFrameOrigin(messageButton.frame.maxX + 20, 0)
        infoButton.setFrameOrigin(callButton.frame.maxX + 20, 0)
        
        buttonsContainer.setFrameSize(infoButton.frame.maxX, 26)
        
        nameView.userInteractionEnabled = false
        lastSeen.userInteractionEnabled = false
    }
    
    override func layout() {
        super.layout()
        avatar.setFrameOrigin(10, 10)
        nameView.setFrameOrigin(avatar.frame.maxX + 10, 10 + 20 - nameView.frame.height - 2)
        lastSeen.setFrameOrigin(avatar.frame.maxX + 10, 10 + 20 + 2)
        
        buttonsContainer.centerX(y: 55)
        
        
    }
    
    func update(with peerView:PeerView, account:Account) {
        if let peer = peerViewMainPeer(peerView) {
            avatar.setPeer(account: account, peer: peer)
            let result = stringStatus(for: peerView)
            let statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1)
            let titleLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
            statusLayout.measure(width: frame.width - 80)
            titleLayout.measure(width: frame.width - 80)
            nameView.update(titleLayout)
            lastSeen.update(statusLayout)
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private class ChatUserPopover: NSObject {
    private let controller:NSViewController = NSViewController()
    private let ready:Promise<Bool> = Promise()
    private let popover:NSPopover
    private let account:Account
    private let peerId:PeerId
    private weak var parentView:NSView?
    private let peerDisposable = MetaDisposable()
    init(account:Account, peerId:PeerId, parentView:NSView) {
        self.account = account
        self.peerId = peerId
        self.popover = NSPopover()
        self.controller.view = ChatUserPopoverView(frame: NSMakeRect(0, 0, 200, 90))
        self.popover.contentViewController = controller
        
        self.popover.behavior = .transient
        self.parentView = parentView
    }
    
    private var view:ChatUserPopoverView {
        return controller.view as! ChatUserPopoverView
    }
    
    deinit {
        peerDisposable.dispose()
        mainWindow.removeAllHandlers(for: self)
    }
    
    func show() {
        if let parentView = parentView {
            popover.show(relativeTo: NSMakeRect(0, 0, 200, 200), of: parentView, preferredEdge: .maxX)
            peerDisposable.set((account.viewTracker.peerView(peerId) |> deliverOnMainQueue).start(next: { [weak self] peerView in
                if let strongSelf = self {
                    strongSelf.view.update(with: peerView, account: strongSelf.account)
                }
            }))
        }
    }
    
    func close() {
        popover.close()
    }
}

private var popover:ChatUserPopover?
func showDetailInfoPopover(forPeerId peerId:PeerId, account: Account, fromView:NSView) {
  //  popover = ChatUserPopover(account: account, peerId: peerId, parentView: fromView)
  //  popover?.show()
    
    
//    
//    mainWindow.set(handler: { () -> KeyHandlerResult in
//        popover?.close()
//        return .invoked
//    }, with: popover!, for: .Escape, priority: .modal)
//    mainWindow.set(handler: { () -> KeyHandlerResult in
//        popover?.close()
//        return .invoked
//    }, with: popover!, for: .Space, priority: .modal)
}

