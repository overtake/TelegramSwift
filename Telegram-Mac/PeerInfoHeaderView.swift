//
//  PeerInfoHeaderView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac



class PeerInfoHeaderView: TableRowView, TGModernGrowingDelegate {

    private let image:AvatarControl = AvatarControl(font: .avatar(26.0))
    
    private let firstNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let lastNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let editableContainer:View = View()
    private let firstNameSeparator:View = View()
    private let lastNameSeparator:View = View()
    private let progressView:RadialProgressContainerView = RadialProgressContainerView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
    private let callButton:ImageButton = ImageButton()
    private let callDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        image.frame = NSMakeRect(0, 0, 70, 70)
        addSubview(image)
        
        image.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHeaderItem, let peer = item.peer, let _ = peer.largeProfileImage {
                showPhotosGallery(account: item.account, peerId: peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        
        firstNameTextView.delegate = self
        firstNameTextView.textFont = .normal(.huge)
    
        firstNameTextView.min_height = 22
        firstNameTextView.isSingleLine = true
        firstNameTextView.max_height = 22
        
        lastNameTextView.delegate = self
        lastNameTextView.textFont = .normal(.huge)
        
        lastNameTextView.min_height = 22
        lastNameTextView.max_height = 22
        lastNameTextView.isSingleLine = true
        
        editableContainer.addSubview(firstNameTextView)
        editableContainer.addSubview(lastNameTextView)
        
        
        editableContainer.addSubview(firstNameSeparator)
        editableContainer.addSubview(lastNameSeparator)

        addSubview(editableContainer)
        
        progressView.progress.fetchControls = FetchControls(fetch: { [weak self] in
            if let item = self?.item as? PeerInfoHeaderItem {
                item.updatingPhotoState?.cancel()
            }
        })
        
   
        
        callButton.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHeaderItem, let peerId = item.peer?.id  {
                let account = item.account
                self?.callDisposable.set((phoneCall(account, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                    applyUIPCallResult(account, result)
                }))
            }
        }, for: .SingleClick)
        
        addSubview(callButton)
        
        progressView.frame = image.bounds
       // image.addSubview(progressView)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        
    }
    
    func maxCharactersLimit() -> Int32 {
        return 30
    }
    
    func textViewSize() -> NSSize {
        if let item = item as? PeerInfoHeaderItem {
            return NSMakeSize(frame.width - item.textInset - item.inset.right, 22)
        }
        return NSZeroSize
    }
    
    func textViewEnterPressed(_ event:NSEvent) -> Bool {
        if FastSettings.checkSendingAbility(for: event) {
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
        if let item = item as? PeerInfoHeaderItem {
            item.textChangeHandler(firstNameTextView.string(), lastNameTextView.isHidden ? nil : lastNameTextView.string())
        }
    }
    
    func textViewTextDidChangeSelectedRange(_ range: NSRange) {
        
    }
    
    func textViewDidPaste(_ pasteboard: NSPasteboard) -> Bool {
        return false
    }
    

    
    override func interactionContentView(for innerId: AnyHashable ) -> NSView {
        return image
    }
    
    override func copy() -> Any {
        return image.copy()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? PeerInfoHeaderItem, let name = item.name, !item.editable {
            
            var nameY:CGFloat = focus(name.0.size).minY
            
            if let status = item.status {
                
                let t = name.0.size.height + status.0.size.height + 4.0
                nameY = (frame.height - t) / 2.0
                
                let sY = nameY + name.0.size.height + 4.0
                status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
                
            }
            
            if item.isVerified {
                ctx.draw(theme.icons.peerInfoVerify, in: NSMakeRect(item.textInset + name.0.size.width + 3, nameY + 4, theme.icons.peerInfoVerify.backingSize.width, theme.icons.peerInfoVerify.backingSize.height))
            }
            
            name.1.draw(NSMakeRect(item.textInset, nameY, name.0.size.width, name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
        }
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? PeerInfoHeaderItem {
            image.frame = NSMakeRect(item.inset.left, (frame.height - image.frame.height)/2.0, image.frame.width, image.frame.height)
            
            callButton.set(image: theme.icons.peerInfoCall, for: .Normal)
            callButton.sizeToFit()
            
            editableContainer.isHidden = !item.editable
            editableContainer.backgroundColor = theme.colors.background
            
            firstNameTextView.textColor = theme.colors.text
            lastNameTextView.textColor = theme.colors.text
            firstNameTextView.background = theme.colors.background
            lastNameTextView.background = theme.colors.background
            
            firstNameSeparator.backgroundColor = theme.colors.border
            lastNameSeparator.backgroundColor = theme.colors.border
            if let peer = item.peer {
                image.setPeer(account: item.account, peer: peer)
                if let peer = peer as? TelegramUser {
                    firstNameTextView.setString(item.firstTextEdited ?? peer.firstName ?? "", animated: false)
                    lastNameTextView.setString(item.lastTextEdited ?? peer.lastName ?? "", animated: false)
                    
                    firstNameTextView.setPlaceholderAttributedString(NSAttributedString.initialize(string: tr(L10n.peerInfoFirstNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    lastNameTextView.setPlaceholderAttributedString(NSAttributedString.initialize(string: tr(L10n.peerInfoLastNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    
                    lastNameTextView.isHidden = false
                } else {
                    firstNameTextView.setString(item.firstTextEdited ?? peer.displayTitle, animated: false)
                    
                    if peer.isChannel {
                        firstNameTextView.setPlaceholderAttributedString(NSAttributedString.initialize(string: tr(L10n.peerInfoChannelNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    } else {
                        firstNameTextView.setPlaceholderAttributedString(NSAttributedString.initialize(string: tr(L10n.peerInfoGroupNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    }
                    lastNameTextView.isHidden = true
                }
                
                if let uploadState = item.updatingPhotoState {
                    if progressView.superview == nil {
                        image.addSubview(progressView)
                        progressView.layer?.opacity = 0
                    }
                    progressView.change(opacity: 1, animated: animated)
                    progressView.progress.state = .Fetching(progress: uploadState.progress, force: false)
                } else {
                    if animated {
                        progressView.change(opacity: 0, animated: animated, removeOnCompletion: false, completion: { [weak self] complete in
                            if complete {
                                self?.progressView.removeFromSuperview()
                                self?.progressView.layer?.removeAllAnimations()
                            }
                        })
                    } else {
                        progressView.removeFromSuperview()
                    }
                }
                
                callButton.isHidden = !item.canCall
                
                lastNameSeparator.isHidden = lastNameTextView.isHidden
                needsLayout = true
            }
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerInfoHeaderItem {
            
            editableContainer.setFrameSize(NSMakeSize(frame.width - item.textInset - item.inset.right, lastNameTextView.isHidden ? 25 : 56))
            
            firstNameTextView.setFrameSize(editableContainer.frame.width, 22)
            lastNameTextView.setFrameSize(editableContainer.frame.width, 22)
            
            firstNameSeparator.frame = NSMakeRect(4, 24, editableContainer.frame.width, .borderSize)
            firstNameTextView.setFrameOrigin(0, 0)
            lastNameTextView.setFrameOrigin(0, 30)
            
            lastNameSeparator.frame = NSMakeRect(4, 55, editableContainer.frame.width, .borderSize)

            callButton.centerY(x: frame.width - callButton.frame.width - 30)
            editableContainer.centerY(x: item.textInset)
        }
    }
    
    deinit {
        callDisposable.dispose()
    }
    
    
}
