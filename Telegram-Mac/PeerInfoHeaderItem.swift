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

    fileprivate var firstTextEdited:String?
    fileprivate var lastTextEdited:String?
    
    override var height: CGFloat {
        switch self.viewType {
        case .legacy:
            return max(130.0, titleHeight + secondHeight + 60 + 4)
        case let .modern(_, insets):
            return max(photoDimension + insets.top + insets.bottom, titleHeight + secondHeight + 2 + insets.top + insets.bottom)
        }
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    fileprivate let photoDimension:CGFloat = 70.0
    fileprivate var textInset:CGFloat {
        switch viewType {
        case .legacy:
            return self.inset.left + photoDimension + 15.0
        case let .modern(_, insets):
            return insets.left + photoDimension + insets.left
        }
    }
    
    fileprivate var photo:Signal<(CGImage?, Bool), NoError>?
    fileprivate let statusLayout: TextViewLayout
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
    init(_ initialSize:NSSize, stableId:AnyHashable, context: AccountContext, peerView:PeerView, viewType: GeneralViewType = .legacy, editable:Bool = false, updatingPhotoState:PeerInfoUpdatingPhotoState? = nil, firstNameEditableText:String? = nil, lastNameEditableText:String? = nil, textChangeHandler:@escaping (String, String?)->Void = {_,_  in}) {
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
        statusLayout = TextViewLayout(result.status, maximumNumberOfLines: 1, alwaysStaticItems: true)
        super.init(initialSize, stableId: stableId, viewType: viewType)
        
        _ = self.makeSize(initialSize.width, oldWidth: 0)
        
    }
    
    fileprivate func calculateHeight() {
        _ = self.makeSize(width, oldWidth: 0)
    }
    
    override func viewClass() -> AnyClass {
        return PeerInfoHeaderView.self
    }
    
    override func makeSize(_ width: CGFloat, oldWidth:CGFloat) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        
        if let firstTextEdited = firstTextEdited {
            let textStorage = NSTextStorage(attributedString: .initialize(string: firstTextEdited, font: .normal(.huge), coreText: false))
            let textContainer:NSTextContainer
            switch viewType {
            case .legacy:
                textContainer = NSTextContainer(size: NSMakeSize(width - inset.right - textInset, .greatestFiniteMagnitude))
            case let .modern(_, insets):
                textContainer = NSTextContainer(size: NSMakeSize(width - textInset - insets.right - inset.left - inset.right, .greatestFiniteMagnitude))
            }
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            titleHeight = max(layoutManager.usedRect(for: textContainer).height, 34)
        } else {
            titleHeight = 0
        }
        
        if let lastTextEdited = lastTextEdited {
            let textStorage = NSTextStorage(attributedString: .initialize(string: lastTextEdited, font: .normal(.huge), coreText: false))
            let textContainer:NSTextContainer
            switch viewType {
            case .legacy:
                textContainer = NSTextContainer(size: NSMakeSize(width - inset.right - textInset, .greatestFiniteMagnitude))
            case let .modern(_, insets):
                textContainer = NSTextContainer(size: NSMakeSize(width - textInset - insets.right - inset.left - inset.right, .greatestFiniteMagnitude))
            }
            let layoutManager = NSLayoutManager()
            layoutManager.addTextContainer(textContainer)
            textStorage.addLayoutManager(layoutManager)
            layoutManager.ensureLayout(for: textContainer)
            secondHeight = max(layoutManager.usedRect(for: textContainer).height, 34)
        } else {
            secondHeight = 0
        }
        
        switch viewType {
        case .legacy:
            break
        case let .modern(_, inner):
            let textWidth = blockWidth - textInset - inner.right - (canCall ? 40 : 0) - (isScam ? theme.icons.scam.backingSize.width + 5 : 0)
            nameLayout.measure(width: textWidth)
            statusLayout.measure(width: textWidth)
        }
        return success
    }
}


class PeerInfoHeaderView: GeneralRowView, TGModernGrowingDelegate {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private let image:AvatarControl = AvatarControl(font: .avatar(26.0))
    private let nameTextView = TextView()
    private let statusTextView = TextView()
    private let imageView = ImageView()
    private let firstNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSMakeRect(0, 0, 0, 34), unscrollable: true)
    private let lastNameTextView:TGModernGrowingTextView = TGModernGrowingTextView(frame: NSMakeRect(0, 0, 0, 34), unscrollable: true)
    private let editableContainer:View = View()
    private let firstNameSeparator:View = View()
    private let separatorView:View = View()
    private let progressView:RadialProgressContainerView = RadialProgressContainerView(theme: RadialProgressTheme(backgroundColor: .clear, foregroundColor: .white, icon: nil))
    private let callButton:ImageButton = ImageButton()
    private let callDisposable = MetaDisposable()
    private let fetchPeerAvatar = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        image.frame = NSMakeRect(0, 0, 70, 70)
        containerView.addSubview(image)
        
        containerView.addSubview(nameTextView)
        containerView.addSubview(statusTextView)
        image.set(handler: { [weak self] _ in
            if let item = self?.item as? PeerInfoHeaderItem, let peer = item.peer, let _ = peer.largeProfileImage {
                showPhotosGallery(context: item.context, peerId: peer.id, firstStableId: item.stableId, item.table, nil)
            }
        }, for: .Click)
        
        firstNameTextView.max_height = 10000
        lastNameTextView.max_height = 10000
        
        firstNameTextView.delegate = self
        firstNameTextView.textFont = .normal(.huge)
        
        lastNameTextView.delegate = self
        lastNameTextView.textFont = .normal(.huge)
        
        
        editableContainer.addSubview(firstNameTextView)
        editableContainer.addSubview(lastNameTextView)

        containerView.addSubview(imageView)

        editableContainer.addSubview(firstNameSeparator)
        
        
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
        
        containerView.addSubview(callButton)
        containerView.addSubview(separatorView)
        progressView.frame = image.bounds
        
        containerView.userInteractionEnabled = false
        containerView.displayDelegate = self
        containerView.addSubview(editableContainer)

        addSubview(containerView)
    }
    
    func textViewHeightChanged(_ height: CGFloat, animated: Bool) {
        if let item = item as? PeerInfoHeaderItem, let table = item.table {
            
            switch item.viewType {
            case .legacy:
                self.containerView.change(size: NSMakeSize(frame.width, item.height), animated: animated)
            case .modern:
                self.containerView.change(size: NSMakeSize(item.blockWidth, item.height - item.inset.bottom - item.inset.top), animated: animated, corners: item.viewType.corners)
                firstNameSeparator.change(pos: NSMakePoint(4, item.titleHeight + 1), animated: animated)
                lastNameTextView._change(pos: NSMakePoint(0, item.titleHeight + 2), animated: animated)
                self.separatorView.change(pos: NSMakePoint(self.separatorView.frame.minX, self.containerView.frame.height - .borderSize), animated: animated)
            }

            table.noteHeightOfRow(item.index, animated)
            change(size: NSMakeSize(frame.width, item.height), animated: animated)
        }
    }
    
    func maxCharactersLimit(_ textView: TGModernGrowingTextView!) -> Int32 {
        guard let item = item as? PeerInfoHeaderItem else {return 100}
        if item.peer is TelegramUser {
            return 128
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
            if !firstNameTextView.isHidden {
                item.firstTextEdited = firstNameTextView.string()
            }
            if !lastNameTextView.isHidden {
                item.lastTextEdited = lastNameTextView.string()
            }

            let titleHeight = item.titleHeight
            let secondHeight = item.secondHeight
            let prevHeight = item.height
            item.calculateHeight()
            if (titleHeight != item.titleHeight || secondHeight != item.secondHeight) && prevHeight == item.height {
                textViewHeightChanged(0, animated: true)
            }
            self.needsLayout = true
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
    
    override func updateColors() {
        if let item = item as? PeerInfoHeaderItem {
            self.containerView.background = backdorColor
            editableContainer.backgroundColor = backdorColor
            firstNameTextView.textColor = theme.colors.text
            lastNameTextView.textColor = theme.colors.text
            firstNameTextView.background = backdorColor
            lastNameTextView.background = backdorColor
            firstNameSeparator.backgroundColor = theme.colors.border
            separatorView.backgroundColor = theme.colors.border
            self.background = item.viewType.rowBackground
        }
    }
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        if let item = item as? PeerInfoHeaderItem, layer == containerView.layer {
            if !item.editable {
            }
        }
        
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? PeerInfoHeaderItem {
            
            callButton.set(image: theme.icons.peerInfoCall, for: .Normal)
            _ = callButton.sizeToFit()
            
            separatorView.isHidden = !item.viewType.hasBorder
            
            switch item.viewType {
            case .legacy:
                self.containerView.change(size: NSMakeSize(frame.width, item.height), animated: animated, corners: item.viewType.corners)
            case .modern:
                self.containerView.change(size: NSMakeSize(item.blockWidth, item.height - item.inset.bottom - item.inset.top), animated: animated, corners: item.viewType.corners)
            }
            
            if animated {
                if item.editable {
                    self.editableContainer.isHidden = false
                }
                self.editableContainer.layer?.animateAlpha(from: !item.editable ? 1 : 0, to: item.editable ? 1 : 0, duration: 0.2, completion: { [weak self] completed in
                    if completed {
                        self?.editableContainer.isHidden = !item.editable
                    }
                })
                
            } else {
                editableContainer.isHidden = !item.editable
                self.editableContainer.layer?.removeAllAnimations()
            }
            self.editableContainer.layer?.opacity = item.editable ? 1 : 0
            
            firstNameSeparator.isHidden = item.secondHeight == 0
            
            
            
            
            if item.isVerified {
                imageView.image = theme.icons.peerInfoVerifyProfile
            } else if item.isScam {
                imageView.image = theme.icons.chatScam
            } else {
                imageView.image = nil
            }
            imageView.sizeToFit()
            
            imageView.isHidden = imageView.image == nil || item.editable
            
            let containerRect: NSRect
            switch item.viewType {
            case .legacy:
                containerRect = self.bounds
            case .modern:
                containerRect = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, item.height - item.inset.bottom - item.inset.top)
            }
            containerView.change(size: containerRect.size, animated: animated)
            containerView.change(pos: containerRect.origin, animated: animated)
            containerView.setCorners(item.viewType.corners, animated: animated)
            separatorView._change(opacity: item.viewType.hasBorder ? 1.0 : 0.0, animated: animated)
            
            nameTextView.update(item.nameLayout)
            nameTextView.isHidden = item.editable
            
            statusTextView.update(item.statusLayout)
            statusTextView.isHidden = item.editable

            self.needsLayout = true
          
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
                        firstNameTextView.setPlaceholderAttributedString(.initialize(string: L10n.peerInfoChannelNamePlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
                    } else {
                        firstNameTextView.setPlaceholderAttributedString(.initialize(string: L10n.peerInfoGroupNamePlaceholder, color: theme.colors.grayText, font: .normal(.header), coreText: false), update: false)
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
                
                
            }
            
            needsLayout = true
            containerView.needsDisplay = true
        }
    }
    
    override func layout() {
        super.layout()
        if let item = item as? PeerInfoHeaderItem {
            switch item.viewType {
            case .legacy:
                self.containerView.frame = bounds
                break
            case let .modern(_, innerInset):
                self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)

                
                image.frame = NSMakeRect(innerInset.left, innerInset.top, image.frame.width, image.frame.height)
                
                editableContainer.setFrameSize(NSMakeSize(containerView.frame.width - item.textInset - innerInset.right, item.titleHeight + item.secondHeight + 4))
                editableContainer.centerY(x: item.textInset)
                
                firstNameTextView.setFrameSize(NSMakeSize(editableContainer.frame.width, item.titleHeight))
                lastNameTextView.setFrameSize(NSMakeSize(editableContainer.frame.width, item.secondHeight))
                
                
                firstNameTextView.setFrameOrigin(0, 0)
                firstNameSeparator.frame = NSMakeRect(4, firstNameTextView.frame.maxY + 1, editableContainer.frame.width, .borderSize)
                lastNameTextView.setFrameOrigin(0, firstNameTextView.frame.maxY + 2)
                
                separatorView.frame = NSMakeRect(innerInset.left, containerView.frame.height - .borderSize, containerView.frame.width - innerInset.left - innerInset.right, .borderSize)

                callButton.centerY(x: containerView.frame.width - callButton.frame.width - innerInset.right)
                
                var nameY:CGFloat = focus(item.nameLayout.layoutSize).minY
                let t = item.nameLayout.layoutSize.height + item.statusLayout.layoutSize.height + 4.0
                nameY = (containerView.frame.height - t) / 2.0

                nameTextView.setFrameOrigin(NSMakePoint(item.textInset, nameY))
                statusTextView.setFrameOrigin(NSMakePoint(item.textInset, nameTextView.frame.maxY + 2))
                imageView.setFrameOrigin(NSMakePoint(item.textInset + item.nameLayout.layoutSize.width + 3, nameY + 3))

            }
        }
    }
    
    deinit {
        callDisposable.dispose()
        fetchPeerAvatar.dispose()
    }
}
