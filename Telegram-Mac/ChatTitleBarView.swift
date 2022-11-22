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
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.avatar(peer: reference, resource: file.resource)).start())
        } else {
            fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: MediaResourceReference.standalone(resource: file.resource)).start())
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
    private let avatarControl:AvatarControl = AvatarControl(font: .avatar(.header))
    private let badgeNode:GlobalBadgeNode
    private let disposable = MetaDisposable()
    private let closeButton = ImageButton()
    private var lastestUsersController: ViewController?
    private let fetchPeerAvatar = DisposableSet()
    
    private var inlineTopicPhotoLayer: InlineStickerItemLayer? = nil
    
    private var statusControl: PremiumStatusControl?
    
    private var videoAvatarView: VideoAvatarContainer?
    
    private var hasPhoto: Bool = false

    
    var connectionStatus:ConnectionStatus = .online(proxyAddress: nil) {
        didSet {
            if connectionStatus != oldValue {
                self.updateStatus(presentation: self.chatInteraction.presentation)
            }
        }
    }
    
    private struct Counters : Equatable {
        var replies: Int32?
        var online: Int32?
    }
    
    private var counters: Counters = Counters() {
        didSet {
            if oldValue != counters {
                updateTitle(presentation: chatInteraction.presentation)
            }
        }
    }

   
    var peerView:PeerView? {
        didSet {
            let context = chatInteraction.context
            updateStatus(presentation: chatInteraction.presentation)
            
            if oldValue == nil {
                let answersCount: Signal<Int32?, NoError>
                let onlineMemberCount:Signal<Int32?, NoError>

                let peerId = chatInteraction.peerId
                let threadId = chatInteraction.mode.threadId64
                let isThread = chatInteraction.mode.isThreadMode
                
                if let threadId = threadId {
                    switch chatInteraction.mode {
                    case let .thread(data, _):
                        if isThread {
                            answersCount = context.account.postbox.messageView(data.messageId)
                                |> map {
                                    $0.message?.attributes.compactMap { $0 as? ReplyThreadMessageAttribute }.first
                                }
                                |> map {
                                    $0?.count
                                }
                                |> deliverOnMainQueue
                        } else {
                            let countViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud)
                            let localCountViewKey: PostboxViewKey = .historyTagSummaryView(tag: MessageTags(), peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Local)
                            
                            answersCount = context.account.postbox.combinedView(keys: [countViewKey, localCountViewKey])
                            |> map { views -> Int32 in
                                var messageCount = 0
                                if let summaryView = views.views[countViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                                    if threadId == 1 {
                                        messageCount += Int(count)
                                    } else {
                                        messageCount += max(Int(count) - 1, 0)
                                    }
                                }
                                if let summaryView = views.views[localCountViewKey] as? MessageHistoryTagSummaryView, let count = summaryView.count {
                                    messageCount += Int(count)
                                }
                                return Int32(messageCount)
                            } |> map(Optional.init) |> deliverOnMainQueue
                        }
                    default:
                        answersCount = .single(nil)
                    }
                } else {
                    answersCount = .single(nil)
                }
                if let peerView = peerView, let peer = peerViewMainPeer(peerView), peer.isSupergroup || peer.isGigagroup {
                    if let cachedData = peerView.cachedData as? CachedChannelData {
                        if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                            onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                        } else {
                            onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: self.chatInteraction.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                        }

                    } else {
                        onlineMemberCount = .single(nil)
                    }
                } else {
                    onlineMemberCount = .single(nil)
                }
                
                self.counterDisposable.set(combineLatest(queue: .mainQueue(), onlineMemberCount, answersCount).start(next: { [weak self] online, answers in
                    let counters = Counters(replies: answers, online: online)
                    self?.counters = counters
                }))
            }
        }
    }

    
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
            self?.chatInteraction.update({$0.updatedSearchMode((!$0.isSearchMode.0, nil, nil))})
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
        addSubview(avatarControl)
        
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
    
    func updateSearchButton(hidden: Bool, animated: Bool) {
        searchButton.isHidden = hidden
        needsLayout = true
    }
    
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        if chatInteraction.presentation.mainPeer?.largeProfileImage?.resource.id.stringRepresentation == stableId.base as? String {
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
    private let counterDisposable = MetaDisposable()

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
        
        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode == .history, let peer = chatInteraction.presentation.mainPeer, peer.hasVideo {
           let signal = peerPhotos(context: chatInteraction.context, peerId: peer.id) |> deliverOnMainQueue
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
        if let photo = photo, let video = photo.image.videoRepresentations.first {
            file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: photo.image.representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: video.resource.size, attributes: [])
            seekTo = video.startTimestamp
        } else {
            seekTo = nil
            file = nil
        }
        
        if NSPointInRect(point, avatarControl.frame), chatInteraction.mode != .scheduled, chatInteraction.peerId != chatInteraction.context.peerId, let file = file, let peer = chatInteraction.presentation.mainPeer {
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
            control.updateWith(file: file, seekTo: seekTo, peer: peer, reference: PeerReference(peer), context: chatInteraction.context)
            
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
                showPhotosGallery(context: chatInteraction.context, peerId: peer.id, firstStableId: AnyHashable(large.resource.id.stringRepresentation), self, nil)
                return
            }
        }
        
        let openInfo:(ChatInteraction)->Void = { chatInteraction in
            if chatInteraction.mode == .history {
                if chatInteraction.presentation.reportMode != nil {

                } else if chatInteraction.peerId == repliesPeerId {
                    
                } else if chatInteraction.peerId == chatInteraction.context.peerId {
                    chatInteraction.context.bindings.rootNavigation().push(PeerMediaController(context: chatInteraction.context, peerId: chatInteraction.peerId))
                } else {
                    switch chatInteraction.chatLocation {
                    case let .peer(peerId):
                        chatInteraction.openInfo(peerId, false, nil, nil)
                    case .thread:
                        break
                    }
                }
            } else if chatInteraction.mode.isTopicMode {
                chatInteraction.openInfo(chatInteraction.peerId, false, nil, nil)
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
        fetchPeerAvatar.dispose()
        videoAvatarDisposable.dispose()
        counterDisposable.dispose()
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

        
        avatarControl.centerY(x: additionInset)
        searchButton.centerY(x:frame.width - searchButton.frame.width)
        callButton.centerY(x: searchButton.isHidden ? frame.width - callButton.frame.width : searchButton.frame.minX - callButton.frame.width - 20)
        
        if hasPhoto {
            activities.view?.setFrameOrigin(avatarControl.frame.maxX + 8, 25)
        } else if let titleRect = titleRect {
            activities.view?.setFrameOrigin(titleRect.minX, 25)
        }
        badgeNode.view!.setFrameOrigin(6,4)
        
        closeButton.centerY()
        
        if let statusControl = statusControl, let titleRect = titleRect {
            statusControl.setFrameOrigin(NSMakePoint(titleRect.maxX + 2, titleRect.minY + 1))
        }
        
        reportPlaceholder?.frame = bounds
        
        
        
        let input = self.inputActivities
        self.inputActivities = input

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
            
            checkPhoto(peerViewMainPeer(peerView))
            
            switch layoutState {
            case .single:
                self.badgeNode.view?.isHidden = false
                self.closeButton.isHidden = false
            default:
                self.badgeNode.view?.isHidden = true
                self.closeButton.isHidden = !hasBackButton
            }
            let mode = chatInteraction.mode
            

            self.hasPhoto = (!mode.isTopicMode && !mode.isThreadMode && mode != .pinned && mode != .scheduled)
            
            self.avatarControl.isHidden = !hasPhoto

            
            self.textInset = !hasPhoto && !mode.isTopicMode ? 24 : hasBackButton ? 66 : 46
            
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
                        callButton.isHidden = !peer.canCall || chatInteraction.peerId == chatInteraction.context.peerId || presentation.reportMode != nil
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
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 17, avatarControl.frame.size.height - 17)), cornerRadius: nil)) |> map {($0, false)})
                } else if peer.id == chatInteraction.context.peerId {
                    let icon = theme.icons.searchSaved
                    avatarControl.setSignal(generateEmptyPhoto(avatarControl.frame.size, type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(avatarControl.frame.size.width - 15, avatarControl.frame.size.height - 15)), cornerRadius: nil)) |> map {($0, false)})
                } else {
                    avatarControl.setPeer(account: chatInteraction.context.account, peer: peer)
                }
            }
            var statusControl: PremiumStatusControl? = nil
            if peerView.peers[peerView.peerId] is TelegramSecretChat {
                titleImage = (theme.icons.chatSecretTitle, .left(topInset: 0))
                callButton.set(image: theme.icons.chatCall, for: .Normal)
                callButton.set(image: theme.icons.chatCallActive, for: .Highlight)
            } else if let peer = peerViewMainPeer(peerView), chatInteraction.mode == .history {
                titleImage = nil
                
                let context = chatInteraction.context
                
                if chatInteraction.context.peerId != chatInteraction.peerId {
                    statusControl = PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, isSelected: false, cached: self.statusControl, animated: false)
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
            
            callButton.sizeToFit()

        }
        updateTitle(force, presentation: chatInteraction.presentation)

        self.updatePhoto(chatInteraction.presentation, animated: false)
        
        needsLayout = true
    }
    
    private func updatePhoto(_ presentation: ChatPresentationInterfaceState, animated: Bool) {
        let context = chatInteraction.context
        if let threadInfo = presentation.threadInfo, chatInteraction.mode.isTopicMode {
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
                    let file = ForumUI.makeIconFile(title: info.title, iconColor: info.iconColor, isGeneral: chatInteraction.mode.threadId64 == 1)
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
            var result = stringStatus(for: peerView, context: chatInteraction.context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: self.counters.online)
            
            if chatInteraction.mode == .pinned {
                result = result.withUpdatedTitle(strings().chatTitlePinnedMessagesCountable(presentation.pinnedMessageId?.totalCount ?? 0))
                status = nil
            } else if chatInteraction.context.peerId == peerView.peerId  {
                if chatInteraction.mode == .scheduled {
                    result = result.withUpdatedTitle(strings().chatTitleReminder)
                } else {
                    result = result.withUpdatedTitle(strings().peerSavedMessages)
                }
            } else if chatInteraction.mode == .scheduled {
                result = result.withUpdatedTitle(strings().chatTitleScheduledMessages)
            } else if case .thread(_, let mode) = chatInteraction.mode {
                switch mode {
                case .comments:
                    result = result.withUpdatedTitle(strings().chatTitleCommentsCountable(Int(self.counters.replies ?? 0)))
                case .replies:
                    result = result.withUpdatedTitle(strings().chatTitleRepliesCountable(Int(self.counters.replies ?? 0)))
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
                }
                switch mode {
                case .topic:
                    break
                default:
                    status = .initialize(string: result.title.string, color: theme.colors.grayText, font: .normal(12))
                    result = result.withUpdatedTitle(strings().chatTitleDiscussion)
                }
            }
            
            if chatInteraction.context.peerId == peerView.peerId {
                status = nil
            } else if (status == nil || !status!.isEqual(to: result.status) || force) && chatInteraction.mode != .scheduled && !chatInteraction.mode.isThreadMode && chatInteraction.mode != .pinned {
                status = result.status
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
