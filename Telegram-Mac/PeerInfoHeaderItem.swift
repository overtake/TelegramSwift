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
    fileprivate let nameLayout: TextViewLayout
    
    fileprivate var titleHeight: CGFloat = 15
    fileprivate var secondHeight: CGFloat = 0
    
    let context: AccountContext
    let peer:Peer?
    let isVerified: Bool
    let isScam: Bool
    let peerView:PeerView
    let result:PeerStatusStringResult
    let editable:Bool
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    let textChangeHandler:(String, String?)->Void
    let canCall:Bool
    init(_ initialSize:NSSize, stableId:AnyHashable, context: AccountContext, peerView:PeerView, editable:Bool = false, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, firstNameEditableText:String? = nil, lastNameEditableText:String? = nil, textChangeHandler:@escaping (String, String?)->Void = {_,_  in}) {
        let peer = peerViewMainPeer(peerView)
        self.peer = peer
        self.peerView = peerView
        self.editable = editable
        self.context = context
        self.updatingPhotoState = updatingPhotoState
        self.textChangeHandler = textChangeHandler
        self.firstTextEdited = firstNameEditableText
        self.lastTextEdited = lastNameEditableText
        
        self.canCall = peer != nil && (peer!.canCall && peer!.id != context.peerId && !editable)
        
        self.isVerified = peer?.isVerified ?? false
        self.isScam = peer?.isScam ?? false
        if let peer = peer {
            photo = peerAvatarImage(account: context.account, photo: .peer(peer, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions:NSMakeSize(photoDimension, photoDimension))
        }
        self.result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.huge), highlightIfActivity: false), expanded: true)
        
        
        nameLayout = TextViewLayout(result.title, maximumNumberOfLines: 1)
        
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
        let success = super.makeSize(width, oldWidth: oldWidth)
        nameLayout.measure(width: size.width - textInset - inset.right - (canCall ? 40 : 0) - (isScam ? theme.icons.scam.backingSize.width + 5 : 0))
        status = TextNode.layoutText(maybeNode: nil,  result.status, nil, 1, .end, NSMakeSize(size.width - textInset - inset.right - (canCall ? 40 : 0), size.height), nil, false, .left)
        return success
    }
}


class PeerInfoHeaderView: TableRowView, TGModernGrowingDelegate {
    
    private let image:AvatarControl = AvatarControl(font: .avatar(26.0))
    private let nameTextView = TextView()
    private let firstNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let lastNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSZeroRect)
    private let editableContainer:View = View()
    private let firstNameSeparator:View = View()
    private let lastNameSeparator:View = View()
    private let progressView:RadialProgressContainerView = RadialProgressContainerView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
    private let callButton:ImageButton = ImageButton()
    private let callDisposable = MetaDisposable()
    private let fetchPeerAvatar = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        image.frame = NSMakeRect(0, 0, 70, 70)
        addSubview(image)
        
        addSubview(nameTextView)
        
        image.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHeaderItem, let peer = item.peer, let _ = peer.largeProfileImage {
                showPhotosGallery(context: item.context, peerId: peer.id, firstStableId: item.stableId, item.table, nil)
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
                let context = item.context
                self?.callDisposable.set((phoneCall(account: context.account, sharedContext: context.sharedContext, peerId: peerId) |> deliverOnMainQueue).start(next: { result in
                    applyUIPCallResult(context.sharedContext, result)
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
        
        if let item = item as? PeerInfoHeaderItem, !item.editable {
            
            var nameY:CGFloat = focus(item.nameLayout.layoutSize).minY
            
            if let status = item.status {
                
                let t = item.nameLayout.layoutSize.height + status.0.size.height + 4.0
                nameY = (frame.height - t) / 2.0
                
                let sY = nameY + item.nameLayout.layoutSize.height + 4.0
                status.1.draw(NSMakeRect(item.textInset, sY, status.0.size.width, status.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backdorColor)
                
            }
            
            if item.isVerified {
                ctx.draw(theme.icons.peerInfoVerify, in: NSMakeRect(item.textInset + item.nameLayout.layoutSize.width + 3, nameY + 4, theme.icons.peerInfoVerify.backingSize.width, theme.icons.peerInfoVerify.backingSize.height))
            }
            if item.isScam {
                ctx.draw(theme.icons.scam, in: NSMakeRect(item.textInset + item.nameLayout.layoutSize.width + 3, nameY + 3, theme.icons.scam.backingSize.width, theme.icons.scam.backingSize.height))
            }
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
            
            
            nameTextView.update(item.nameLayout)
            nameTextView.isHidden = item.editable
          
            if let peer = item.peer {
                image.setPeer(account: item.context.account, peer: peer)
                
                if let largeProfileImage = peer.largeProfileImage {
                    if let peerReference = PeerReference(peer) {
                        fetchPeerAvatar.set(fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: largeProfileImage.resource)).start())
                    }
                }
                
                if let peer = peer as? TelegramUser {
                    firstNameTextView.setString(item.firstTextEdited ?? peer.firstName ?? "", animated: false)
                    lastNameTextView.setString(item.lastTextEdited ?? peer.lastName ?? "", animated: false)
                    firstNameTextView.setPlaceholderAttributedString(.initialize(string: tr(L10n.peerInfoFirstNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    lastNameTextView.setPlaceholderAttributedString(.initialize(string: tr(L10n.peerInfoLastNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    lastNameTextView.isHidden = false
                } else {
                    let titleText = item.firstTextEdited ?? peer.displayTitle
                    if titleText != firstNameTextView.string() {
                        firstNameTextView.setString(titleText, animated: false)
                    }
                    if peer.isChannel {
                        firstNameTextView.setPlaceholderAttributedString(.initialize(string: tr(L10n.peerInfoChannelNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    } else {
                        firstNameTextView.setPlaceholderAttributedString(.initialize(string: tr(L10n.peerInfoGroupNamePlaceholder), color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
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
                
            }
            firstNameTextView.textColor = theme.colors.text
            lastNameTextView.textColor = theme.colors.text
            firstNameTextView.background = theme.colors.background
            lastNameTextView.background = theme.colors.background
            
            firstNameSeparator.backgroundColor = theme.colors.border
            lastNameSeparator.backgroundColor = theme.colors.border
            
            needsLayout = true
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
            
            
            
            var nameY:CGFloat = focus(item.nameLayout.layoutSize).minY
            if let status = item.status {
                let t = item.nameLayout.layoutSize.height + status.0.size.height + 4.0
                nameY = (frame.height - t) / 2.0
            }
            nameTextView.setFrameOrigin(NSMakePoint(item.textInset, nameY))
            
        }
    }
    
    deinit {
        callDisposable.dispose()
        fetchPeerAvatar.dispose()
    }
}
