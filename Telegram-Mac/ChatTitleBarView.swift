//
//  ChatTitleView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 08/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import AVFoundation
private class ConnectionStatusView : View {
    private var textViewLayout:TextViewLayout?
    private var disableProxyButton: TitleButton?
    
    var disableProxy:(()->Void)?
    
    var status:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            let attr:NSAttributedString
            
            if case let .connecting(proxy, _) = status {
                if let _ = proxy {
                    if disableProxyButton == nil {
                        disableProxyButton = TitleButton()
                    }
                    disableProxyButton?.set(color: theme.colors.grayText, for: .Normal)
                    disableProxyButton?.set(font: .medium(.text), for: .Normal)
                    disableProxyButton?.set(text: tr(L10n.connectingStatusDisableProxy), for: .Normal)
                    _ = disableProxyButton?.sizeToFit()
                    addSubview(disableProxyButton!)
                    
                    disableProxyButton?.set(handler: { [weak self] _ in
                        self?.disableProxy?()
                        }, for: .Click)
                } else {
                    disableProxyButton?.removeFromSuperview()
                    disableProxyButton = nil
                }
            } else {
                disableProxyButton?.removeFromSuperview()
                disableProxyButton = nil
            }
            
            switch status {
            case let .connecting(proxy, _):
                attr = .initialize(string: proxy != nil ? L10n.chatConnectingStatusConnectingToProxy : L10n.chatConnectingStatusConnecting, color: theme.colors.text, font: .medium(.header))
            case .updating:
                attr = .initialize(string: L10n.chatConnectingStatusUpdating, color: theme.colors.text, font: .medium(.header))
            case .waitingForNetwork:
                attr = .initialize(string: L10n.chatConnectingStatusWaitingNetwork, color: theme.colors.text, font: .medium(.header))
            case .online:
                attr = NSAttributedString()
            }
            textViewLayout = TextViewLayout(attr, maximumNumberOfLines: 1)
            needsLayout = true
        }
    }
    private let textView:TextView = TextView()
    private let indicator:ProgressIndicator = ProgressIndicator()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        addSubview(indicator)
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.background
        textView.backgroundColor = theme.colors.background
        disableProxyButton?.set(background: theme.colors.background, for: .Normal)
        indicator.progressColor = theme.colors.text
        let status = self.status
        self.status = status
    }

    deinit {
        //indicator.animates = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate override func layout() {
        super.layout()
        
        if let textViewLayout = textViewLayout {
            textViewLayout.measure(width: frame.width)
            let f = focus(textViewLayout.layoutSize, inset:NSEdgeInsets(left: 12, top: 3))
            indicator.centerY(x:0)
            
            
            textView.update(textViewLayout)
            
            if let disableProxyButton = disableProxyButton {
                disableProxyButton.setFrameOrigin(indicator.frame.maxX + 3, floorToScreenPixels(backingScaleFactor, frame.height / 2) + 2)
                textView.setFrameOrigin(indicator.frame.maxX + 8, floorToScreenPixels(backingScaleFactor, frame.height / 2) - textView.frame.height + 2)
            } else {
                textView.setFrameOrigin(NSMakePoint(indicator.frame.maxX + 4, f.origin.y))
            }
            
        }
        
    }
    
}


class ChatTitleBarView: TitledBarView, InteractionContentViewProtocol {
   
    
    
    private var isSingleLayout:Bool = false
    private var connectionStatusView:ConnectionStatusView? = nil
    private let activities:ChatActivitiesModel
    private let searchButton:ImageButton = ImageButton()
    private let callButton:ImageButton = ImageButton()
    private let chatInteraction:ChatInteraction
    private let avatarControl:AvatarControl = AvatarControl(font: .avatar(.header))
    private let badgeNode:GlobalBadgeNode
    private let disposable = MetaDisposable()
    private let closeButton = ImageButton()
    private var lastestUsersController: ViewController?
    private let fetchPeerAvatar: MetaDisposable = MetaDisposable()
    var connectionStatus:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            if connectionStatus != oldValue {
                if case .online = connectionStatus {
                    
                    //containerView.change(pos: NSMakePoint(0, 0), animated: true)
                    if let connectionStatusView = connectionStatusView {
                        
                        connectionStatusView.change(pos: NSMakePoint(0, -frame.height), animated: true)
                        connectionStatusView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion:false, completion:{ [weak self] completed in
                            self?.connectionStatusView?.removeFromSuperview()
                            self?.connectionStatusView = nil
                        })
                        
                    }
                    
                } else {
                    if connectionStatusView == nil {
                        connectionStatusView = ConnectionStatusView(frame: NSMakeRect(0, -frame.height, frame.width, frame.height))
                        connectionStatusView?.disableProxy = chatInteraction.disableProxy
                        addSubview(connectionStatusView!)
                        connectionStatusView?.change(pos: NSMakePoint(0,0), animated: true)
                      //  containerView.change(pos: NSMakePoint(0, frame.height), animated: true)
                    }
                    
                    connectionStatusView?.status = connectionStatus

                }
            }
        }
    }
   
    var postboxView:PostboxView? {
        didSet {
           updateStatus()
        }
    }
    
    var onlineMemberCount:Int32? = nil {
        didSet {
            updateStatus()
        }
    }
    
    
    
    var inputActivities:(PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let inputActivities = inputActivities, self.chatInteraction.mode == .history  {
                activities.update(with: inputActivities, for: max(frame.width - 80, 160), theme:theme.activity(key: 4, foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background), layout: { [weak self] show in
                    guard let `self` = self else { return }
                    self.needsLayout = true
                    self.hiddenStatus = show
                    self.setNeedsDisplay()
                    if let view = self.activities.view {
                        if self.animates {
                            if show {
                                if view.isHidden {
                                    
                                }
                                view.isHidden = false
                                view.change(opacity: 1, duration: 0.2)
                            } else {
                                view.change(opacity: 0, completion: { [weak view] completed in
                                    if completed {
                                        view?.isHidden = true
                                    }
                                })
                            }
                           
                        } else {
                            view.layer?.opacity = 1
                            view.layer?.removeAllAnimations()
                            view.isHidden = !show
                        }
                    }
                    
                })
            } else {
                activities.clean()
            }
        }
    }
    
    
    var presenceManager:PeerPresenceStatusManager?
    
    init(controller: ViewController, _ chatInteraction:ChatInteraction) {
        activities = ChatActivitiesModel()
        self.chatInteraction = chatInteraction
        
        searchButton.disableActions()
        callButton.disableActions()
        
        
        badgeNode = GlobalBadgeNode(chatInteraction.context.account, sharedContext: chatInteraction.context.sharedContext, excludePeerId: self.chatInteraction.peerId, view: View(), layoutChanged: {
        })
        

        super.init(controller: controller, textInset: 46)
        
        addSubview(activities.view!)

        
        searchButton.set(handler: { [weak self] _ in
            self?.chatInteraction.update({$0.updatedSearchMode((!$0.isSearchMode.0, nil))})
        }, for: .Click)
        
        addSubview(searchButton)
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            self?.updateStatus()
        })
        
        callButton.set(handler: { _ in
           chatInteraction.call()
        }, for: .Click)
        
        activities.view?.isHidden = true
        callButton.isHidden = true
        addSubview(callButton)
        
        avatarControl.setFrameSize(36,36)
        addSubview(avatarControl)
        
        disposable.set(chatInteraction.context.sharedContext.layoutHandler.get().start(next: { [weak self] state in
            if let strongSelf = self {
                switch state {
                case .single:
                    strongSelf.isSingleLayout = true
                    strongSelf.badgeNode.view?.isHidden = false
                    strongSelf.closeButton.isHidden = false
                    strongSelf.searchButton.isHidden = false
                    strongSelf.avatarControl.isHidden = false
                default:
                    strongSelf.isSingleLayout = strongSelf.controller?.className != "Telegram.ChatController" //( is ChatAdditionController) || (strongSelf.controller is ChatSwitchInlineController) || (strongSelf.controller is ChatScheduleController)
                    strongSelf.badgeNode.view?.isHidden = true
                    strongSelf.closeButton.isHidden = strongSelf.controller?.className == "Telegram.ChatController"
                    strongSelf.searchButton.isHidden = strongSelf.controller is ChatScheduleController
                    strongSelf.avatarControl.isHidden = strongSelf.controller is ChatScheduleController
                }
                strongSelf.textInset = strongSelf.avatarControl.isHidden ? 24 : strongSelf.isSingleLayout ? 66 : 46
                strongSelf.needsLayout = true
            }
        }))
            
        
        closeButton.autohighlight = false
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        closeButton.set(handler: { [weak self] _ in
            self?.chatInteraction.context.sharedContext.bindings.rootNavigation().back()
        }, for: .Click)
        _ = closeButton.sizeToFit()
        closeButton.setFrameSize(closeButton.frame.width, frame.height)
        addSubview(closeButton)
        
        avatarControl.userInteractionEnabled = false

        addSubview(badgeNode.view!)
        
        updateLocalizationAndTheme(theme: theme)
        
        self.continuesAction = true
        
    }
    
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.connectionStatusView?.setFrameSize(newSize)
        let input = self.inputActivities
        self.inputActivities = input
        
    }
    
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if chatInteraction.peer?.largeProfileImage?.resource.id.uniqueId == stableId.base as? String {
            return avatarControl
        }
        return nil
    }
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        
    }
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        
    }
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        return nil
    }
    public func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        let point = convert(event.locationInWindow, from: nil)

        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode != .scheduled {
            if let peer = chatInteraction.peer, let large = peer.largeProfileImage {
                showPhotosGallery(context: chatInteraction.context, peerId: chatInteraction.peerId, firstStableId: AnyHashable(large.resource.id.uniqueId), self, nil)
                return
            }
        }
        
        if isSingleLayout {
            if point.x > 20 {
                if chatInteraction.mode != .scheduled {
                    if chatInteraction.peerId == chatInteraction.context.peerId {
                        chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId, tagMask: .photoOrVideo))
                    } else {
                        switch chatInteraction.chatLocation {
                        case let .peer(peerId):
                            chatInteraction.openInfo(peerId, false, nil, nil)
                        }
                    }
                }
               
            } else {
                chatInteraction.context.sharedContext.bindings.rootNavigation().back()
            }
        } else {
            if chatInteraction.peerId == chatInteraction.context.peerId {
                chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId, tagMask: .photoOrVideo))
            } else {
                switch chatInteraction.chatLocation {
                case let .peer(peerId):
                    chatInteraction.openInfo(peerId, false, nil, nil)
                }
            }
        }
    }
    
    deinit {
        disposable.dispose()
        fetchPeerAvatar.dispose()
    }
    
    
    override func layout() {
        super.layout()
        
        let additionInset:CGFloat = isSingleLayout ? 20 : 0
        
        avatarControl.centerY(x: additionInset)
        searchButton.centerY(x:frame.width - searchButton.frame.width)
        callButton.centerY(x: searchButton.isHidden ? frame.width - callButton.frame.width : searchButton.frame.minX - callButton.frame.width - 20)
        activities.view?.setFrameOrigin(avatarControl.frame.maxX + 8, 25)
        badgeNode.view!.setFrameOrigin(6,4)
        
        closeButton.centerY()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override var inset:CGFloat {
        return 36 + 50 + (callButton.isHidden ? 20 : callButton.frame.width + 30)
    }
    


    func updateStatus(_ force:Bool = false) {
        var shouldUpdateLayout = false
        if let peerView = self.postboxView as? PeerView {
            
            switch chatInteraction.mode {
            case .history:
                if let peer = peerViewMainPeer(peerView) {
                    callButton.isHidden = !peer.canCall || chatInteraction.peerId == chatInteraction.context.peerId
                } else {
                    callButton.isHidden = true
                }
            case .scheduled:
                callButton.isHidden = true
            }
            
            
            if let peer = peerViewMainPeer(peerView) {
                if peer.id == chatInteraction.context.peerId {
                    let icon = theme.icons.searchSaved
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 15, avatarControl.frame.size.height - 15)), cornerRadius: nil)) |> map {($0, false)})
                } else {
                    avatarControl.setPeer(account: chatInteraction.context.account, peer: peer)
                    if let largeProfileImage = peer.largeProfileImage {
                       // let image = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [largeProfileImage], immediateThumbnailData: nil, reference: nil, partialReference: nil)
                        if let peerReference = PeerReference(peer) {
                            fetchPeerAvatar.set(fetchedMediaResource(mediaBox: chatInteraction.context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: largeProfileImage.resource)).start())
                        }
                      //  fetchPeerAvatar.set(chatMessagePhotoInteractiveFetched(account: chatInteraction.context.account, imageReference: ImageMediaReference.standalone(media: image), toRepresentationSize: NSMakeSize(640, 640)).start())
                    }
                }
            }
            
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left)
            } else if let peer = peerViewMainPeer(peerView) {
                if peer.isVerified {
                    titleImage = (theme.icons.verifiedImage, .right)
                } else if peer.isScam {
                    titleImage = (theme.icons.scam, .right)
                } else {
                    titleImage = nil
                }
            } else {
                titleImage = nil
            }
            
            var result = stringStatus(for: peerView, context: chatInteraction.context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: self.onlineMemberCount)
            
            if chatInteraction.context.peerId == peerView.peerId  {
                if chatInteraction.mode == .scheduled {
                    result = result.withUpdatedTitle(L10n.chatTitleReminder)
                } else {
                    result = result.withUpdatedTitle(L10n.peerSavedMessages)
                }
            } else if chatInteraction.mode == .scheduled {
                result = result.withUpdatedTitle(L10n.chatTitleScheduledMessages)
            }
            
            
            if chatInteraction.context.peerId == peerView.peerId {
                status = nil
            } else if (status == nil || !status!.isEqual(to: result.status) || force) && chatInteraction.mode != .scheduled {
                status = result.status
                shouldUpdateLayout = true
            }
            
            if text == nil || !text!.isEqual(to: result.title) || force {
                text = result.title
                shouldUpdateLayout = true
            }
            
            if let presence = result.presence {
                self.presenceManager?.reset(presence: presence, timeDifference: Int32(chatInteraction.context.timeDifference))
            }
            if shouldUpdateLayout {
                self.setNeedsDisplay()
            }
        } 
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        searchButton.set(image: theme.icons.chatSearch, for: .Normal)
        searchButton.set(image: theme.icons.chatSearchActive, for: .Highlight)

        
        _ = searchButton.sizeToFit()
        
        callButton.set(image: theme.icons.chatCall, for: .Normal)
        _ = callButton.sizeToFit()
        
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
        
        if let peerView = postboxView as? PeerView {
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left)
            } else if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left)
            } else if let peer = peerViewMainPeer(peerView) {
                if peer.isVerified {
                    titleImage = (theme.icons.verifiedImage, .right)
                } else if peer.isScam {
                    titleImage = (theme.icons.scam, .right)
                } else {
                    titleImage = nil
                }
            } else {
                titleImage = nil
            }
        } else {
            titleImage = nil
        }
    }
}
