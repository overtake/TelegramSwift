//
//  PeerInfoHeaderItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
class PeerInfoHeaderItem: GeneralRowItem {

    fileprivate let firstTextEdited:String?
    fileprivate let lastTextEdited:String?
    
    override var height: CGFloat {
        return max(130.0, titleHeight + secondHeight + 60 + 8)
    }
    
    override var instantlyResize: Bool {
        return super.instantlyResize
    }
    
    fileprivate let photoDimension:CGFloat = 70.0
    fileprivate let textMargin:CGFloat = 15.0
    fileprivate var textInset:CGFloat {
        return self.inset.left + photoDimension + textMargin
    }
    
    fileprivate var photo:Signal<(CGImage?, Bool), NoError>?
    fileprivate var status:(TextNodeLayout, TextNode)?
    fileprivate var name:(TextNodeLayout, TextNode)?
    
    fileprivate var titleHeight: CGFloat = 15
    fileprivate var secondHeight: CGFloat = 0
    
    let account:Account
    let peer:Peer?
    let isVerified: Bool
    let peerView:PeerView
    let result:PeerStatusStringResult
    let editable:Bool
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    let textChangeHandler:(String, String?)->Void
    let canCall:Bool
    init(_ initialSize:NSSize, stableId:AnyHashable, account:Account, peerView:PeerView, editable:Bool = false, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, firstNameEditableText:String? = nil, lastNameEditableText:String? = nil, textChangeHandler:@escaping (String, String?)->Void = {_,_  in}) {
        let peer = peerViewMainPeer(peerView)
        self.peer = peer
        self.peerView = peerView
        self.editable = editable
        self.account = account
        self.updatingPhotoState = updatingPhotoState
        self.textChangeHandler = textChangeHandler
        self.firstTextEdited = firstNameEditableText
        self.lastTextEdited = lastNameEditableText
        
        canCall = peer != nil && (peer!.canCall && peer!.id != account.peerId && !editable)
        
        isVerified = peer?.isVerified ?? false
        
        if let peer = peer {
            photo = peerAvatarImage(account: account, photo: .peer(peer.id, peer.smallProfileImage, peer.displayLetters), displayDimensions:NSMakeSize(photoDimension, photoDimension))
        }
        self.result = stringStatus(for: peerView, theme: PeerStatusStringTheme(titleFont: .medium(.huge), highlightIfActivity: false))
        
        super.init(initialSize, stableId:stableId)
        
        if let firstNameEditableText = firstNameEditableText {
            let textStorage = NSTextStorage(attributedString: .initialize(string: firstNameEditableText, font: .medium(.huge), coreText: false))
            let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.right - textInset, .greatestFiniteMagnitude))
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            
            titleHeight = layoutManager.usedRect(for: textContainer).height
        } else {
            titleHeight = 0
        }
        
        if let lastNameEditableText = lastNameEditableText {
            let textStorage = NSTextStorage(attributedString: .initialize(string: lastNameEditableText, font: .medium(.huge), coreText: false))
            let textContainer = NSTextContainer(size: NSMakeSize(initialSize.width - inset.right - textInset, .greatestFiniteMagnitude))
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            
            secondHeight = layoutManager.usedRect(for: textContainer).height
        } else {
            secondHeight = 0
        }
        
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoHeaderView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        name = TextNode.layoutText(maybeNode: nil,  result.title, nil, 1, .end, NSMakeSize(size.width - textInset - inset.right - (canCall ? 40 : 0), size.height), nil, false, .left)
        status = TextNode.layoutText(maybeNode: nil,  result.status, nil, 1, .end, NSMakeSize(size.width - textInset - inset.right - (canCall ? 40 : 0), size.height), nil, false, .left)

        return super.makeSize(width, oldWidth: oldWidth)
    }
}


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
        firstNameTextView.textFont = .medium(.huge)
        
        firstNameTextView.isSingleLine = true
        
        lastNameTextView.delegate = self
        lastNameTextView.textFont = .medium(.huge)
        
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
        if let item = item as? PeerInfoHeaderItem, let table = item.table {
            item.titleHeight = firstNameTextView.frame.height
            item.secondHeight = lastNameTextView.frame.height
            table.noteHeightOfRow(item.index, animated)
        }
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        guard let item = item as? PeerInfoHeaderItem else {return 100}
        if item.peer is TelegramUser {
            return 128 - Int32(firstNameTextView.string().length) - Int32(lastNameTextView.string().length)
        }
        return 255
    }
    
    func textViewSize(_ textView: TGModernGrowingTextView!) -> NSSize {
        if let item = item as? PeerInfoHeaderItem {
            return NSMakeSize(frame.width - item.textInset - item.inset.right, textView.frame.height)
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
    
    
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
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
                status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                
            }
            
            if item.isVerified {
                ctx.draw(theme.icons.peerInfoVerify, in: NSMakeRect(item.textInset + name.0.size.width + 3, nameY + 4, theme.icons.peerInfoVerify.backingSize.width, theme.icons.peerInfoVerify.backingSize.height))
            }
            
            name.1.draw(NSMakeRect(item.textInset, nameY, name.0.size.width, name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
        }
        
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? PeerInfoHeaderItem {
            image.frame = NSMakeRect(item.inset.left, item.inset.left, image.frame.width, image.frame.height)
            
            callButton.set(image: theme.icons.peerInfoCall, for: .Normal)
            _ = callButton.sizeToFit()
            
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
            
            editableContainer.setFrameSize(NSMakeSize(frame.width - item.textInset - item.inset.right, (lastNameTextView.isHidden ? firstNameTextView.frame.height : lastNameTextView.frame.height + firstNameTextView.frame.height) + 4))
            
            firstNameTextView.setFrameSize(editableContainer.frame.width, firstNameTextView.frame.height)
            lastNameTextView.setFrameSize(editableContainer.frame.width, lastNameTextView.frame.height)
            
            firstNameSeparator.frame = NSMakeRect(4, firstNameTextView.frame.maxY, editableContainer.frame.width, .borderSize)
            firstNameTextView.setFrameOrigin(0, 0)
            lastNameTextView.setFrameOrigin(0, firstNameTextView.frame.maxY + 3)
            
            lastNameSeparator.frame = NSMakeRect(4, lastNameTextView.frame.maxY, editableContainer.frame.width, .borderSize)
            
            callButton.centerY(x: frame.width - callButton.frame.width - 30)
            editableContainer.centerY(x: item.textInset)
        }
    }
    
    deinit {
        callDisposable.dispose()
    }
}
