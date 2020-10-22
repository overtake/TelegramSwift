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
    
    private(set) var backButton: ImageButton?
    
    var isSingleLayout: Bool = false {
        didSet {
            updateBackButton()
        }
    }
    
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
    
    private func updateBackButton() {
        if isSingleLayout {
            let button: ImageButton
            if let b = self.backButton {
                button = b
            } else {
                button = ImageButton()
                self.backButton = button
                addSubview(button)
            }
            button.autohighlight = false
            button.set(image: theme.icons.chatNavigationBack, for: .Normal)
            _ = button.sizeToFit()
        } else {
            backButton?.removeFromSuperview()
            backButton = nil
        }
        needsLayout = true
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
            
            let offset: CGFloat = backButton != nil ? 16 : 0
            
            textViewLayout.measure(width: frame.width)
            let f = focus(textViewLayout.layoutSize, inset:NSEdgeInsets(left: 12, top: 3))
            indicator.centerY(x: offset)
            
            textView.update(textViewLayout)
            
            if let disableProxyButton = disableProxyButton {
                disableProxyButton.setFrameOrigin(indicator.frame.maxX + 3, floorToScreenPixels(backingScaleFactor, frame.height / 2) + 2)
                textView.setFrameOrigin(indicator.frame.maxX + 8, floorToScreenPixels(backingScaleFactor, frame.height / 2) - textView.frame.height + 2)
            } else {
                textView.setFrameOrigin(NSMakePoint(indicator.frame.maxX + 4, f.origin.y))
            }
            backButton?.centerY(x: 0)
        }
        
    }
    
}


private final class VideoAvatarProgressView: View {
    private let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 20, 20))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.progressView)
        backgroundColor = .blackTransparent
        progressView.progressColor = .white
        layer?.cornerRadius = frameRect.width / 2
    }
    
    override func layout() {
        progressView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class VideoAvatarContainer : View {
    let circle: View = View()
    
    private var mediaPlayer: MediaPlayer?
    private var view: MediaPlayerView?
    
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()

    private var progressView: VideoAvatarProgressView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(circle)
        circle.frame = bounds
        
        circle.layer?.cornerRadius = bounds.width / 2
        circle.layer?.borderWidth = 1
        circle.layer?.borderColor = theme.colors.accent.cgColor
        

        isEventLess = true

    }
    
    func animateIn() {
      //  circle.layer?.animateScaleCenter(from: 0.2, to: 1.0, duration: 0.2)
    }
    func animateOut() {
       // circle.layer?.animateScaleCenter(from: 1.0, to: 0.2, duration: 0.2)
    }
    
    func updateWith(file: TelegramMediaFile, seekTo: TimeInterval?, reference: PeerReference?, context: AccountContext) {
       // player.update(FileMediaReference.standalone(media: file), context: context)
        if let reference = reference {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.avatar(peer: reference, resource: file.resource)).start())
        } else {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: file.resource)).start())
        }
        
        let mediaReference: MediaResourceReference
        if let reference = reference {
            mediaReference = MediaResourceReference.avatar(peer: reference, resource: file.resource)
        } else {
            mediaReference = MediaResourceReference.standalone(resource: file.resource)
        }
        
        let mediaPlayer = MediaPlayer(postbox: context.account.postbox, reference: mediaReference, streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: false)
        
        
        let view = MediaPlayerView()
        
        view.setVideoLayerGravity(.resizeAspectFill)
        
        mediaPlayer.attachPlayerView(view)
        
        mediaPlayer.actionAtEnd = .loop(nil)
        
        view.frame = NSMakeRect(2, 2, frame.width - 4, frame.height - 4)
        view.layer?.cornerRadius = bounds.width / 2

        addSubview(view)
        
        self.mediaPlayer = mediaPlayer
        self.view = view
        
        mediaPlayer.play()
        if let seekTo = seekTo {
            mediaPlayer.seek(timestamp: seekTo)
        }
        
        let statusSignal = context.account.postbox.mediaBox.resourceStatus(file.resource) |> deliverOnMainQueue
        
        statusDisposable.set(statusSignal.start(next: { [weak self] status in
            switch status {
            case .Local:
                if let progressView = self?.progressView {
                    self?.progressView = nil
                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressView] _ in
                        progressView?.removeFromSuperview()
                    })
                }
            default:
                if self?.progressView == nil, let frame = self?.frame {
                    let view = VideoAvatarProgressView(frame: NSMakeRect(2, 2, frame.width - 4, frame.height - 4))
                    self?.progressView = view
                    self?.addSubview(view)
                    view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
        }))
        
    }
    
    deinit {
        fetchDisposable.dispose()
        statusDisposable.dispose()
    }
    
    override func layout() {
        super.layout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class ChatTitleBarView: TitledBarView, InteractionContentViewProtocol {
   
    
    private var isSingleLayout:Bool = false {
        didSet {
            connectionStatusView?.isSingleLayout = isSingleLayout
            connectionStatusView?.backButton?.removeAllHandlers()
            connectionStatusView?.backButton?.set(handler: { [weak self] _ in
                self?.chatInteraction.context.sharedContext.bindings.rootNavigation().back()
            }, for: .Click)
        }
    }
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
    private let fetchPeerAvatar = DisposableSet()
    
    private var videoAvatarView: VideoAvatarContainer?
    
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
                        connectionStatusView?.isSingleLayout = isSingleLayout
                        connectionStatusView?.disableProxy = chatInteraction.disableProxy
                        addSubview(connectionStatusView!)
                        connectionStatusView?.change(pos: NSMakePoint(0,0), animated: true)
                    }
                    connectionStatusView?.status = connectionStatus
                    applyVideoAvatarIfNeeded(nil)
                }
            }
        }
    }
    
    private var rootRepliesCount: Int = 0 {
        didSet {
            updateTitle()
        }
    }
   
    var postboxView:PostboxView? {
        didSet {
           updateStatus()
            switch chatInteraction.mode {
            case let .replyThread(data, _):
                let answersCount = chatInteraction.context.account.postbox.messageView(data.messageId)
                    |> map {
                        $0.message?.attributes.compactMap { $0 as? ReplyThreadMessageAttribute }.first
                    }
                    |> map {
                        Int($0?.count ?? 0)
                    }
                    |> deliverOnMainQueue
                
                answersCountDisposable.set(answersCount.start(next: { [weak self] count in
                    self?.rootRepliesCount = count
                }))
            default:
                answersCountDisposable.set(nil)
            }
            
        }
    }
    
    var onlineMemberCount:Int32? = nil {
        didSet {
            updateStatus()
        }
    }
    
    
    
    var inputActivities:(PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let inputActivities = inputActivities, self.chatInteraction.mode != .scheduled  {
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
        
        videoAvatarDisposable.set(peerPhotos(account: chatInteraction.context.account, peerId: chatInteraction.chatLocation.peerId).start())
        
        badgeNode = GlobalBadgeNode(chatInteraction.context.account, sharedContext: chatInteraction.context.sharedContext, excludePeerId: self.chatInteraction.peerId, view: View(), layoutChanged: {
        })
        
        super.init(controller: controller, textInset: 46)
        
        addSubview(activities.view!)

        
        searchButton.set(handler: { [weak self] _ in
            self?.chatInteraction.update({$0.updatedSearchMode((!$0.isSearchMode.0, nil, nil))})
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
                default:
                    strongSelf.isSingleLayout = strongSelf.controller?.className != "Telegram.ChatController" 
                    strongSelf.badgeNode.view?.isHidden = true
                    strongSelf.closeButton.isHidden = strongSelf.controller?.className == "Telegram.ChatController" && strongSelf.chatInteraction.mode.threadId == nil
                }
                strongSelf.avatarControl.isHidden = strongSelf.controller is ChatScheduleController || strongSelf.chatInteraction.mode.threadId != nil || strongSelf.chatInteraction.mode == .pinned

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
    
    func updateSearchButton(hidden: Bool, animated: Bool) {
        (animated ? searchButton.animator() : searchButton).isHidden = hidden
    }
    
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        self.connectionStatusView?.setFrameSize(newSize)
        let input = self.inputActivities
        self.inputActivities = input
        
    }
    
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if chatInteraction.presentation.mainPeer?.largeProfileImage?.resource.id.uniqueId == stableId.base as? String {
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
    
    private let videoAvatarDisposable = MetaDisposable()
    private let answersCountDisposable = MetaDisposable()
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        applyVideoAvatarIfNeeded(nil)
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        applyVideoAvatarIfNeeded(nil)
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        
        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode == .history, let peer = chatInteraction.presentation.mainPeer {
           let signal = peerPhotos(account: chatInteraction.context.account, peerId: peer.id) |> deliverOnMainQueue
            videoAvatarDisposable.set(signal.start(next: { [weak self] photos in
                self?.applyVideoAvatarIfNeeded(photos.first)
            }))
        } else {
            videoAvatarDisposable.set(nil)
            applyVideoAvatarIfNeeded(nil)
        }
    }
    
    private var currentPhoto: TelegramPeerPhoto?
    
    private func applyVideoAvatarIfNeeded(_ photo: TelegramPeerPhoto?) {
        guard let window = self.window as? Window, currentPhoto?.image != photo?.image else {
            return
        }
        
        currentPhoto = photo
        
        let point = convert(window.mouseLocationOutsideOfEventStream, from: nil)


        let file: TelegramMediaFile?
        let seekTo: TimeInterval?
        if let photo = photo, let video = photo.image.videoRepresentations.last {
            file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: photo.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
            seekTo = video.startTimestamp
        } else {
            seekTo = nil
            file = nil
        }
        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode != .scheduled, chatInteraction.peerId != chatInteraction.context.peerId, self.connectionStatusView == nil, let file = file, let peer = chatInteraction.presentation.mainPeer {
            let control: VideoAvatarContainer
            if let view = self.videoAvatarView {
                control = view
            } else {
                control = VideoAvatarContainer(frame: NSMakeRect(avatarControl.frame.minX - 2, avatarControl.frame.minY - 2, avatarControl.frame.width + 4, avatarControl.frame.height + 4))
                addSubview(control, positioned: .below, relativeTo: badgeNode.view)
                control.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                control.animateIn()
                self.videoAvatarView = control
            }
            control.updateWith(file: file, seekTo: seekTo, reference: PeerReference(peer), context: chatInteraction.context)
            
        } else {
            if let view = self.videoAvatarView {
                self.videoAvatarView = nil
                view.animateOut()
                view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                    view?.removeFromSuperview()
                })
            }
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        let point = convert(event.locationInWindow, from: nil)

        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode == .history, chatInteraction.peerId != chatInteraction.context.peerId {
            if let peer = chatInteraction.presentation.mainPeer, let large = peer.largeProfileImage {
                showPhotosGallery(context: chatInteraction.context, peerId: peer.id, firstStableId: AnyHashable(large.resource.id.uniqueId), self, nil)
                return
            }
        }
        
        if isSingleLayout {
            if point.x > 20 {
                if chatInteraction.mode == .history {
                    if chatInteraction.peerId == repliesPeerId {
                        
                    } else if chatInteraction.peerId == chatInteraction.context.peerId {
                        chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId))
                    } else {
                        switch chatInteraction.chatLocation {
                        case let .peer(peerId):
                            chatInteraction.openInfo(peerId, false, nil, nil)
                        case .replyThread:
                            break
                        }
                    }
                }
               
            } else {
                chatInteraction.context.sharedContext.bindings.rootNavigation().back()
            }
        } else {
            if chatInteraction.peerId == repliesPeerId {
                
            } else if chatInteraction.peerId == chatInteraction.context.peerId {
                chatInteraction.context.sharedContext.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId))
            } else {
                switch chatInteraction.chatLocation {
                case let .peer(peerId):
                    chatInteraction.openInfo(peerId, false, nil, nil)
                case .replyThread:
                    break
                }
            }
        }
    }
    
    deinit {
        disposable.dispose()
        fetchPeerAvatar.dispose()
        videoAvatarDisposable.dispose()
        answersCountDisposable.dispose()
    }
    
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
    override func layout() {
        super.layout()
        
        let additionInset:CGFloat = isSingleLayout ? 20 : 2
        
        avatarControl.centerY(x: additionInset)
        searchButton.centerY(x:frame.width - searchButton.frame.width)
        callButton.centerY(x: searchButton.isHidden ? frame.width - callButton.frame.width : searchButton.frame.minX - callButton.frame.width - 20)
        if !avatarControl.isHidden {
            activities.view?.setFrameOrigin(avatarControl.frame.maxX + 8, 25)
        } else {
            activities.view?.setFrameOrigin(24, 25)
        }
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
    
    
    private var currentRepresentations: [TelegramMediaImageRepresentation] = []
    
    private func checkPhoto(_ peer: Peer?) {
        if let peer = peer {
            var representations:[TelegramMediaImageRepresentation] = []//peer.profileImageRepresentations
            if let representation = peer.smallProfileImage {
                representations.append(representation)
            }
            if let representation = peer.largeProfileImage {
                representations.append(representation)
            }
            
            if self.currentRepresentations != representations {
                applyVideoAvatarIfNeeded(nil)
                videoAvatarDisposable.set(peerPhotos(account: chatInteraction.context.account, peerId: peer.id, force: true).start())
                
                
                if let peerReference = PeerReference(peer) {
                    if let largeProfileImage = peer.largeProfileImage {
                        fetchPeerAvatar.add(fetchedMediaResource(mediaBox: chatInteraction.context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: largeProfileImage.resource)).start())
                    }
                    if let smallProfileImage = peer.smallProfileImage {
                        fetchPeerAvatar.add(fetchedMediaResource(mediaBox: chatInteraction.context.account.postbox.mediaBox, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource)).start())
                    }
                }
            }
            self.currentRepresentations = representations
        }
    }


    func updateStatus(_ force:Bool = false) {
        if let peerView = self.postboxView as? PeerView {
            
            checkPhoto(peerViewMainPeer(peerView))
            
            switch chatInteraction.mode {
            case .history:
                if let peer = peerViewMainPeer(peerView) {
                    callButton.isHidden = !peer.canCall || chatInteraction.peerId == chatInteraction.context.peerId
                } else {
                    callButton.isHidden = true
                }
            case .scheduled:
                callButton.isHidden = true
            case .replyThread:
                callButton.isHidden = true
            case .pinned:
                callButton.isHidden = true
            }
            
            
            if let peer = peerViewMainPeer(peerView) {
                if peer.id == repliesPeerId {
                    let icon = theme.icons.chat_replies_avatar
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 17, avatarControl.frame.size.height - 17)), cornerRadius: nil)) |> map {($0, false)})
                } else if peer.id == chatInteraction.context.peerId {
                    let icon = theme.icons.searchSaved
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 15, avatarControl.frame.size.height - 15)), cornerRadius: nil)) |> map {($0, false)})
                } else {
                    avatarControl.setPeer(account: chatInteraction.context.account, peer: peer)
                }
            }
            
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left)
            } else if let peer = peerViewMainPeer(peerView), chatInteraction.mode == .history {
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
            
            updateTitle(force)
        } 
    }
    
    private func updateTitle(_ force: Bool = false) {
        var shouldUpdateLayout = false
        if let peerView = self.postboxView as? PeerView {
            var result = stringStatus(for: peerView, context: chatInteraction.context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: self.onlineMemberCount)
            
            if chatInteraction.mode == .pinned {
                result = result.withUpdatedTitle(L10n.chatTitlePinnedMessagesCountable(chatInteraction.presentation.pinnedMessageId?.totalCount ?? 0))
                status = nil
            } else if chatInteraction.context.peerId == peerView.peerId  {
                if chatInteraction.mode == .scheduled {
                    result = result.withUpdatedTitle(L10n.chatTitleReminder)
                } else {
                    result = result.withUpdatedTitle(L10n.peerSavedMessages)
                }
            } else if chatInteraction.mode == .scheduled {
                result = result.withUpdatedTitle(L10n.chatTitleScheduledMessages)
            } else if case .replyThread(_, let mode) = chatInteraction.mode {
                switch mode {
                case .comments:
                    result = result.withUpdatedTitle(L10n.chatTitleCommentsCountable(self.rootRepliesCount))
                case .replies:
                    result = result.withUpdatedTitle(L10n.chatTitleRepliesCountable(self.rootRepliesCount))
                }
                status = .initialize(string: result.title.string, color: theme.colors.grayText, font: .normal(12))
                result = result.withUpdatedTitle(L10n.chatTitleDiscussion)
            }
            
            if chatInteraction.context.peerId == peerView.peerId {
                status = nil
            } else if (status == nil || !status!.isEqual(to: result.status) || force) && chatInteraction.mode != .scheduled && chatInteraction.mode.threadId == nil && chatInteraction.mode != .pinned {
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
        }
        
        if shouldUpdateLayout {
            setNeedsDisplay()
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
