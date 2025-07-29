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
import TelegramMedia
import SwiftSignalKit
import AVFoundation


private final class SelectMessagesPlaceholderView: View {
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        background = theme.colors.background
        let layout = TextViewLayout(.initialize(string: strings().chatTitleReportMessages, color: theme.colors.text, font: .medium(.header)))
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
    }
    
    override func layout() {
        super.layout()
        textView.centerY(x: 0)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
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
    
    func updateWith(file: TelegramMediaFile, seekTo: TimeInterval?, peer: Peer, reference: PeerReference?, context: AccountContext) {
       // player.update(FileMediaReference.standalone(media: file), context: context)
        if let reference = reference {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: MediaResourceReference.avatar(peer: reference, resource: file.resource)).start())
        } else {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(peer.id), userContentType: .avatar, reference: MediaResourceReference.standalone(resource: file.resource)).start())
        }
        
        if peer.isForum {
            circle.layer?.cornerRadius = bounds.width / 3
        } else {
            circle.layer?.cornerRadius = bounds.width / 2
        }
        
        let mediaReference: MediaResourceReference
        if let reference = reference {
            mediaReference = MediaResourceReference.avatar(peer: reference, resource: file.resource)
        } else {
            mediaReference = MediaResourceReference.standalone(resource: file.resource)
        }
        
        let mediaPlayer = MediaPlayer(postbox: context.account.postbox, userLocation: .peer(peer.id), userContentType: .avatar, reference: mediaReference, streamable: true, video: true, preferSoftwareDecoding: false, enableSound: false, fetchAutomatically: false)
        
        
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
   
    
    private var layoutState:SplitViewState {
        return chatInteraction.context.layout
    }
    private var hasBackButton: Bool {
        if let controller = controller {
            return controller is ChatAdditionController || controller is ChatScheduleController || layoutState == .single
        }
        return false
    }
    private var reportPlaceholder: SelectMessagesPlaceholderView?
    private let activities:ChatActivitiesModel
    private let searchButton:ImageButton = ImageButton()
    private let callButton:ImageButton = ImageButton()
    private let chatInteraction:ChatInteraction
    private let avatarControl:AvatarStoryControl = AvatarStoryControl(font: .avatar(12), size: NSMakeSize(36, 36))
    private let badgeNode:GlobalBadgeNode
    private let disposable = MetaDisposable()
    private let closeButton = ImageButton()
    private var lastestUsersController: ViewController?
    private let fetchPeerAvatar = DisposableSet()
    
    private var inlineTopicPhotoLayer: InlineStickerItemLayer? = nil
    
    private var statusControl: PremiumStatusControl?
    private var leftStatusControl: PremiumStatusControl?

    private var videoAvatarView: VideoAvatarContainer?
    
    private var hasPhoto: Bool = false
    
    private let photoContainer: Control = Control(frame: NSMakeRect(0, 0, 36, 36))
    
    
    
    var connectionStatus:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            if connectionStatus != oldValue {
                self.updateStatus(presentation: self.chatInteraction.presentation)
            }
        }
    }
    

    private var counters: ChatTitleCounters = ChatTitleCounters() {
        didSet {
            if oldValue != counters {
                updateTitle(presentation: chatInteraction.presentation)
            }
        }
    }

    private func updatePeerView(_ peerView: PeerView?, animated: Bool) {
        let oldValue = self.peerView
        self.peerView = peerView
        let context = chatInteraction.context
        if let oldValue = oldValue, let newValue = peerView  {
            let peerEqual = PeerEquatable(peerViewMainPeer(oldValue)) == PeerEquatable(peerViewMainPeer(newValue))
            let cachedEqual = CachedDataEquatable(oldValue.cachedData) == CachedDataEquatable(newValue.cachedData)
            var presenceEqual: Bool = true
            if oldValue.peerPresences.count != newValue.peerPresences.count {
                presenceEqual = false
            } else {
                for (key, lhsValue) in oldValue.peerPresences {
                    let rhsValue = newValue.peerPresences[key]
                    if let rhsValue = rhsValue, !lhsValue.isEqual(to: rhsValue) {
                        presenceEqual = false
                    } else if rhsValue == nil {
                        presenceEqual = false
                    }
                    if !presenceEqual {
                        break
                    }
                }
            }

            if !peerEqual || !cachedEqual || !presenceEqual || self.chatInteraction.mode.customChatLink != nil {
                updateStatus(presentation: chatInteraction.presentation)
            }
        } else {
            updateStatus(presentation: chatInteraction.presentation)
        }
    }
    func update(_ peerView: PeerView?, story: PeerExpiringStoryListContext.State?, counters: ChatTitleCounters, animated: Bool) {
        self.counters = counters
        self.updatePeerView(peerView, animated: animated)
        self.updateStoryState(story, animated: animated)
    }
    
    var hasStories: Bool {
        if let storyState = story, !storyState.items.isEmpty {
            return true
        }
        return false
    }
    
    private func updateStoryState(_ story: PeerExpiringStoryListContext.State?, animated: Bool) {
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate
        if self.story != story {
            if let storyState = story, !storyState.items.isEmpty {
                let peer: Peer? = peerView != nil ? peerViewMainPeer(peerView!) : nil
                
                let compoment = AvatarStoryIndicatorComponent(state: storyState, presentation: theme, isRoundedRect: peer?.isForum == true)
                avatarControl.update(component: compoment, availableSize: NSMakeSize(30, 30), transition: transition)
            } else {
                avatarControl.update(component: nil, availableSize: NSMakeSize(36, 36), transition: transition)
            }
        }
        self.story = story
        
    }
   
    private var peerView:PeerView?
    private var story: PeerExpiringStoryListContext.State?
    
    var inputActivities:(PeerId, [(Peer, PeerInputActivity)])? {
        didSet {
            if let inputActivities = inputActivities, self.chatInteraction.mode != .scheduled && self.chatInteraction.mode != .pinned  {
                activities.update(with: inputActivities, for: max(frame.width - inset, 160), theme:theme.activity(key: 4, foregroundColor: theme.colors.accent, backgroundColor: theme.colors.background), layout: { [weak self] show in
                    guard let `self` = self else { return }
                    self.hiddenStatus = show
                                        
                    if let view = self.activities.view {
                        if self.animates {
                            if show {
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
                    self.needsLayout = true
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
            self?.chatInteraction.update { current in
                current.updatedSearchMode(.init(inSearch: !current.searchMode.inSearch))
            }
        }, for: .Click)
        
        addSubview(searchButton)
        
        self.presenceManager = PeerPresenceStatusManager(update: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.updateStatus(presentation: strongSelf.chatInteraction.presentation)
        })
        
        callButton.set(handler: { [weak self] _ in
            guard let chatInteraction = self?.chatInteraction else {
                return
            }
            if let groupCall = chatInteraction.presentation.groupCall {
                chatInteraction.joinGroupCall(groupCall.activeCall, groupCall.joinHash)
            } else {
                chatInteraction.call()
            }
        }, for: .Click)
        
        activities.view?.isHidden = true
        callButton.isHidden = true
        addSubview(callButton)
        
        avatarControl.setFrameSize(36,36)
        photoContainer.addSubview(avatarControl)
        
        addSubview(photoContainer)
        
        photoContainer.set(handler: { [weak self] _ in
            self?.openPhoto()
        }, for: .Click)
        
        disposable.set(chatInteraction.context.layoutValue.start(next: { [weak self] state in
            if let state = self?.chatInteraction.presentation {
                self?.updateStatus(presentation: state)
            }
        }))
            
        closeButton.autohighlight = false
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        closeButton.set(handler: { [weak self] _ in
            self?.chatInteraction.context.bindings.rootNavigation().back()
        }, for: .Click)
        _ = closeButton.sizeToFit()
        closeButton.setFrameSize(closeButton.frame.width, frame.height)
        addSubview(closeButton)
        
        avatarControl.userInteractionEnabled = false

        addSubview(badgeNode.view!)
        
        updateLocalizationAndTheme(theme: theme)
        
        self.continuesAction = true
        
        self.updateStatus(presentation: self.chatInteraction.presentation)
        
    }
    
    private func openPhoto() {
        if self.hasStories {
            
            chatInteraction.openStories({ [weak self] peerId, _, _ in
                if self?.chatInteraction.peerId == peerId {
                    return self?.avatarControl
                } else {
                    return nil
                }
            }, { [weak self] signal in
                self?.setOpenProgress(signal)
            })
        } else {
            if chatInteraction.mode == .history, chatInteraction.peerId != chatInteraction.context.peerId {
                if let peer = chatInteraction.presentation.mainPeer, let large = peer.largeProfileImage {
                    showPhotosGallery(context: chatInteraction.context, peerId: peer.id, firstStableId: AnyHashable(large.resource.id.stringRepresentation), self, nil)
                    return
                }
            }
        }
        
    }
    
    private func setOpenProgress(_ signal: Signal<Never, NoError>) {
        SetOpenStoryDisposable(self.avatarControl.pushLoadingStatus(signal: signal))
    }
    
    func updateSearchButton(hidden: Bool, animated: Bool) {
        searchButton.isHidden = hidden
        needsLayout = true
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if chatInteraction.presentation.mainPeer?.largeProfileImage?.resource.id.stringRepresentation == stableId.base as? String {
            return avatarControl.avatar
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
    
    

    private var currentPhoto: TelegramPeerPhoto?
    
    private var mouseDownWindowFrame: NSRect? = nil

    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        mouseDownWindowFrame = window?.frame
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        
        if mouseDownWindowFrame != window?.frame {
            return
        }
        
        let point = convert(event.locationInWindow, from: nil)

        let openInfo:(ChatInteraction)->Void = { chatInteraction in
            if chatInteraction.mode == .history {
                if chatInteraction.presentation.reportMode != nil {

                } else if chatInteraction.peerId == repliesPeerId {
                    
                } else if chatInteraction.peerId == chatInteraction.context.peerId {
                    chatInteraction.context.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId, isBot: false))
                } else {
                    switch chatInteraction.chatLocation {
                    case let .peer(peerId):
                        chatInteraction.openInfo(peerId, false, nil, nil)
                    case let .thread(data):
                        if data.isMonoforumPost {
                            chatInteraction.openInfo(PeerId(data.threadId), false, nil, nil)
                        } else {
                            chatInteraction.openInfo(data.peerId, false, nil, nil)
                        }
                    }
                }
            } else if chatInteraction.presentation.isTopicMode {
                chatInteraction.openInfo(chatInteraction.peerId, false, nil, nil)
            } else if chatInteraction.mode.isSavedMessagesThread, let threadId = chatInteraction.chatLocation.threadId {
                chatInteraction.openInfo(PeerId(threadId), false, nil, nil)
            }
        }
        
        if hasBackButton {
            if point.x > 20 {
               openInfo(chatInteraction)
            } else {
                chatInteraction.context.bindings.rootNavigation().back()
            }
        } else {
            openInfo(chatInteraction)
        }
    }
    
    deinit {
        disposable.dispose()
        NotificationCenter.default.removeObserver(self)
    }
    
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateListeners()
        updateAnimatableContent()
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateListeners()
        updateAnimatableContent()
    }
    
    
    private func updateListeners() {
        let center = NotificationCenter.default
        if let window = window {
            center.removeObserver(self)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didBecomeKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSWindow.didResignKeyNotification, object: window)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self.enclosingScrollView?.documentView)
            center.addObserver(self, selector: #selector(updateAnimatableContent), name: NSView.frameDidChangeNotification, object: self)
        } else {
            center.removeObserver(self)
        }
    }
    
    @objc func updateAnimatableContent() -> Void {
        
        let checkValue:(InlineStickerItemLayer)->Void = { value in
            DispatchQueue.main.async {
                if let superview = value.superview {
                    var isKeyWindow: Bool = false
                    if let window = superview.window {
                        if !window.canBecomeKey {
                            isKeyWindow = true
                        } else {
                            isKeyWindow = window.isKeyWindow
                        }
                    }
                    value.isPlayable = superview.visibleRect != .zero && isKeyWindow
                }
            }
        }
     
        if let value = inlineTopicPhotoLayer {
            checkValue(value)
        }
    }
    
    override func layout() {
        super.layout()
        
        let additionInset:CGFloat = hasBackButton ? 20 : 2
        
        if let photo = inlineTopicPhotoLayer {
            photo.frame = NSMakeRect(additionInset, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - photo.frame.height) / 2), photo.frame.width, photo.frame.height)
        }

        
        photoContainer.centerY(x: additionInset)
        searchButton.centerY(x:frame.width - searchButton.frame.width)
        callButton.centerY(x: searchButton.isHidden ? frame.width - callButton.frame.width : searchButton.frame.minX - callButton.frame.width - 20)
        
        if hasPhoto {
            activities.view?.setFrameOrigin(photoContainer.frame.maxX + 8, 25)
        } else if let titleRect = titleRect {
            activities.view?.setFrameOrigin(titleRect.minX, 25)
        }
        badgeNode.view!.setFrameOrigin(6,4)
        
        closeButton.centerY()
        
        if let statusControl = statusControl, let titleRect = titleRect {
            statusControl.setFrameOrigin(NSMakePoint(titleRect.maxX + 2, titleRect.minY + 1))
        }
        
        if let statusControl = leftStatusControl, let titleRect = titleRect {
            statusControl.setFrameOrigin(NSMakePoint(titleRect.minX - statusControl.frame.width - 2, titleRect.minY + 1))
        }
        
        reportPlaceholder?.frame = bounds
        
        
    }
    

    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }

    override var inset:CGFloat {
        return 36 + 50 + (callButton.isHidden ? 10 : callButton.frame.width + 35) + (statusControl?.frame.width ?? 0)
    }
    
    
    private var currentRepresentations: [TelegramMediaImageRepresentation] = []
    


    func updateStatus(_ force:Bool = false, presentation: ChatPresentationInterfaceState) {

        if presentation.reportMode != nil {
            if self.reportPlaceholder == nil {
                self.reportPlaceholder = SelectMessagesPlaceholderView(frame: bounds)
                addSubview(self.reportPlaceholder!)
            }
        } else {
            self.reportPlaceholder?.removeFromSuperview()
            self.reportPlaceholder = nil
        }

        if let peerView = self.peerView {
                        
            switch layoutState {
            case .single:
                self.badgeNode.view?.isHidden = false
                self.closeButton.isHidden = false
            default:
                self.badgeNode.view?.isHidden = true
                self.closeButton.isHidden = !hasBackButton
            }
            let mode = chatInteraction.mode
            

            self.hasPhoto = (!presentation.isTopicMode && !mode.isThreadMode && mode != .pinned && mode != .scheduled) && mode.customChatContents == nil && mode.customChatLink == nil
            
            self.photoContainer.isHidden = !hasPhoto

            
            self.textInset = !hasPhoto && !presentation.isTopicMode ? 24 : hasBackButton ? 66 : 46
            
            
            switch chatInteraction.mode {
            case .history:
                if let peer = peerViewMainPeer(peerView) {
                    if peer.isGroup || peer.isSupergroup || peer.isChannel {
                        if let groupCall = presentation.groupCall {
                            if let data = groupCall.data, data.participantCount == 0 && groupCall.activeCall.scheduleTimestamp == nil {
                                callButton.isHidden = presentation.reportMode != nil
                            } else {
                                callButton.isHidden = true
                            }
                        } else {
                            callButton.isHidden = true
                        }
                    } else {
                        callButton.isHidden = !peer.canCall || chatInteraction.peerId == chatInteraction.context.peerId || presentation.reportMode != nil || chatInteraction.isMonoforum
                    }
                    
                    
                } else {
                    callButton.isHidden = true
                }
                
            default:
                callButton.isHidden = true
            }

            
            if let peer = peerViewMainPeer(peerView) {
                if peer.id == repliesPeerId {
                    let icon = theme.icons.chat_replies_avatar
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 17, avatarControl.frame.size.height - 17)), cornerRadius: nil), bubble: false) |> map {($0, false)})
                } else if peer.id.isAnonymousSavedMessages {
                    let icon = theme.icons.chat_hidden_author
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 5, avatarControl.frame.size.height - 5)), cornerRadius: nil), bubble: false) |> map {($0, false)})
                } else if peer.id == chatInteraction.context.peerId, chatInteraction.mode.isSavedMessagesThread {
                    let icon = theme.icons.chat_my_notes
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 5, avatarControl.frame.size.height - 5)), cornerRadius: nil), bubble: false) |> map {($0, false)})
                } else if peer.id == chatInteraction.context.peerId {
                    let icon = theme.icons.searchSaved
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 15, avatarControl.frame.size.height - 15)), cornerRadius: nil), bubble: false) |> map {($0, false)})
                } else {
                    if peer.isMonoForum, let mainForumPeer = peerViewMonoforumMainPeer(peerView) {
                        avatarControl.setState(account: chatInteraction.context.account, state: .PeerAvatar(peer, mainForumPeer.displayLetters, mainForumPeer.smallProfileImage, mainForumPeer.nameColor, nil, nil, peer.groupAccess.canManageDirect, nil))
                    } else {
                        avatarControl.setPeer(account: chatInteraction.context.account, peer: peer)
                    }
                }
            }
            var statusControl: PremiumStatusControl? = nil
            var leftStatusControl: PremiumStatusControl? = nil
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left(topInset: 0))
                callButton.set(image: theme.icons.chatCall, for: .Normal)
                callButton.set(image: theme.icons.chatCallActive, for: .Highlight)
            } else if let peer = peerViewMainPeer(peerView), chatInteraction.mode == .history || chatInteraction.mode.isSavedMessagesThread {
                titleImage = nil
                
                let context = chatInteraction.context
                
                if let peer = (peerViewMonoforumMainPeer(peerView) ?? peerViewMainPeer(peerView)) {
                    if chatInteraction.context.peerId != chatInteraction.peerId || chatInteraction.mode.isSavedMessagesThread, presentation.reportMode == nil {
                        statusControl = PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, left: false, isSelected: false, cached: self.statusControl, animated: false)
                    }
                    
                    if chatInteraction.context.peerId != chatInteraction.peerId || chatInteraction.mode.isSavedMessagesThread, presentation.reportMode == nil {
                        leftStatusControl = PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, left: true, isSelected: false, cached: self.leftStatusControl, animated: false)
                    }
                }
                
                
                if peer.isGroup || peer.isSupergroup || peer.isChannel {
                    callButton.set(image: theme.icons.chat_voice_chat, for: .Normal)
                    callButton.set(image: theme.icons.chat_voice_chat_active, for: .Highlight)
                } else {
                    callButton.set(image: theme.icons.chatCall, for: .Normal)
                    callButton.set(image: theme.icons.chatCallActive, for: .Highlight)
                }
            } else {
                titleImage = nil
            }
            
            if let statusControl = statusControl {
                self.statusControl = statusControl
                self.addSubview(statusControl)
            } else if let view = self.statusControl {
                performSubviewRemoval(view, animated: false)
                self.statusControl = nil
            }
            
            if let statusControl = leftStatusControl {
                self.leftStatusControl = statusControl
                self.addSubview(statusControl)
            } else if let view = self.leftStatusControl {
                performSubviewRemoval(view, animated: false)
                self.leftStatusControl = nil
            }
            
            self.titleInset = leftStatusControl != nil ? leftStatusControl!.frame.width + 2 : 0

            
            callButton.sizeToFit()

        }
        self.updateTitle(force, presentation: presentation)
        self.updatePhoto(presentation, animated: false)

        needsLayout = true
    }
    
    
    private func updatePhoto(_ presentation: ChatPresentationInterfaceState, animated: Bool) {
        let context = chatInteraction.context
        if let threadInfo = presentation.threadInfo, presentation.isTopicMode {
            let size = NSMakeSize(30, 30)
            let current: InlineStickerItemLayer
            if let layer = self.inlineTopicPhotoLayer, layer.file?.fileId.id == threadInfo.info.icon {
                current = layer
            } else {
                if let layer = inlineTopicPhotoLayer {
                    performSublayerRemoval(layer, animated: animated)
                    self.inlineTopicPhotoLayer = nil
                }
                let info = threadInfo.info
                if let fileId = info.icon {
                    current = .init(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: size, playPolicy: .playCount(2))
                } else {
                    let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: presentation.chatLocation.threadId == 1)
                    current = .init(account: context.account, file: file, size: size, playPolicy: .playCount(2))
                }
                current.superview = containerView
                self.containerView.layer?.addSublayer(current)
                self.inlineTopicPhotoLayer = current
            }
        } else {
            if let layer = inlineTopicPhotoLayer {
                performSublayerRemoval(layer, animated: animated)
                self.inlineTopicPhotoLayer = nil
            }
        }
        self.updateAnimatableContent()
    }
    
    private func updateTitle(_ force: Bool = false, presentation: ChatPresentationInterfaceState) {
        if let peerView = self.peerView, let peer = peerViewMainPeer(peerView) {
            var result = stringStatus(for: peerView, context: chatInteraction.context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: self.counters.online, ignoreActivity: presentation.chatMode.isSavedMessagesThread || presentation.chatMode.customChatLink != nil || presentation.isMonoforum)
            
            if presentation.isMonoforum {
                if !presentation.monoforumTopics.isEmpty, presentation.chatLocation.threadId == nil {
                    result = result
                        .withUpdatedStatus(strings().chatTitleChatsCountable(presentation.monoforumTopics.count))
                } else {
                    result = result
                        .withUpdatedStatus(strings().chatTitleTopicCountable(Int(self.counters.replies ?? 0)))
                }
            } else if let customLinkContents = chatInteraction.mode.customChatLink {
                result = result.withUpdatedTitle(customLinkContents.name.isEmpty ? customLinkContents.link : customLinkContents.name).withUpdatedStatus(customLinkContents.name.isEmpty ? "" : customLinkContents.link)
            } else if let customChatContents = chatInteraction.mode.customChatContents {
                result = result.withUpdatedTitle(customChatContents.kind.text).withUpdatedStatus("")
            } else if chatInteraction.mode == .pinned {
                result = result.withUpdatedTitle(strings().chatTitlePinnedMessagesCountable(presentation.pinnedMessageId?.totalCount ?? 0)).withUpdatedStatus("")
            } else if chatInteraction.mode == .scheduled {
                result = result.withUpdatedTitle(strings().chatTitleScheduledMessages).withUpdatedStatus("")
            } else if let threadInfo = presentation.threadInfo, presentation.isTopicMode {
                if let count = self.counters.replies, count > 0 {
                    result = result
                        .withUpdatedTitle(threadInfo.info.title)
                        .withUpdatedStatus(strings().chatTitleTopicCountable(Int(count)))
                } else {
                    result = result
                        .withUpdatedTitle(threadInfo.info.title)
                        .withUpdatedStatus(strings().peerInfoTopicStatusIn(peer.displayTitle))
                }
            } else if case let .thread(mode) = chatInteraction.mode, case let .thread(data) = chatInteraction.chatLocation {
                switch mode {
                case .comments:
                    result = result.withUpdatedTitle(strings().chatTitleDiscussion).withUpdatedStatus(strings().chatTitleCommentsCountable(Int(self.counters.replies ?? 0)))
                case .replies:
                    result = result.withUpdatedTitle(strings().chatTitleDiscussion).withUpdatedStatus(strings().chatTitleRepliesCountable(Int(self.counters.replies ?? 0)))
                case .topic:
                    if let count = self.counters.replies, count > 0 {
                        result = result
                            .withUpdatedTitle(presentation.threadInfo?.info.title ?? "")
                            .withUpdatedStatus(strings().chatTitleTopicCountable(Int(count)))
                    } else {
                        result = result
                            .withUpdatedTitle(presentation.threadInfo?.info.title ?? "")
                            .withUpdatedStatus(strings().peerInfoTopicStatusIn(peer.displayTitle))
                    }
                case .savedMessages:
                    if let count = self.counters.replies, count > 0 {
                        result = result
                            .withUpdatedStatus(strings().chatTitleTopicCountable(Int(count)))
                    } else {
                        result = result
                            .withUpdatedTitle(presentation.threadInfo?.info.title ?? "")
                            .withUpdatedStatus(strings().peerInfoTopicStatusIn(peer.displayTitle))
                    }
                    if PeerId(data.threadId) == chatInteraction.context.peerId {
                        result = result.withUpdatedTitle(strings().peerMyNotes)
                    }
                case .saved:
                    break
                }
 
            } else if chatInteraction.context.peerId == peerView.peerId  {
                if chatInteraction.mode == .scheduled {
                    result = result.withUpdatedTitle(strings().chatTitleReminder).withUpdatedStatus("")
                } else {
                    result = result.withUpdatedTitle(strings().peerSavedMessages).withUpdatedStatus("")
                }
            }
            
            if (status == nil || !status!.isEqual(to: result.status) || force) {
                status = result.status.string.isEmpty ? nil : result.status
            }
            switch connectionStatus {
            case let .connecting(proxy, _):
                status = .initialize(string: (proxy != nil ? strings().chatConnectingStatusConnectingToProxy : strings().chatConnectingStatusConnecting).lowercased(), color: theme.colors.grayText, font: .normal(.short))
            case .updating:
                status = .initialize(string: strings().chatConnectingStatusUpdating.lowercased(), color: theme.colors.grayText, font: .normal(.short))
            case .waitingForNetwork:
                status = .initialize(string: strings().chatConnectingStatusWaitingNetwork.lowercased(), color: theme.colors.grayText, font: .normal(.short))
            case .online:
                break
            }
            
            if text == nil || !text!.isEqual(to: result.title) || force {
                text = result.title
            }
            if let presence = result.presence {
                self.presenceManager?.reset(presence: presence, timeDifference: Int32(chatInteraction.context.timeDifference))
            }
        }
  
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = (theme as! TelegramPresentationTheme)
        searchButton.set(image: theme.icons.chatSearch, for: .Normal)
        searchButton.set(image: theme.icons.chatSearchActive, for: .Highlight)

        _ = searchButton.sizeToFit()
        
        closeButton.set(image: theme.icons.chatNavigationBack, for: .Normal)
        let inputActivities = self.inputActivities
        self.inputActivities = inputActivities
        
        updateStatus(true, presentation: chatInteraction.presentation)
    }
}
