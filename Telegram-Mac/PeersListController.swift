//
//  PeersListController.swift
//  TelegramMac
//
//  Created by keepcoder on 29/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import Reactions
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let joinGroupCall:(ChatActiveGroupCallInfo)->Void
    let joinGroup:(PeerId)->Void
    init(context: AccountContext, joinGroupCall:@escaping(ChatActiveGroupCallInfo)->Void, joinGroup:@escaping(PeerId)->Void) {
        self.context = context
        self.joinGroupCall = joinGroupCall
        self.joinGroup = joinGroup
    }
}


final class RevealAllChatsView : Control {
    let textView: TextView = TextView()

    var layoutState: SplitViewState = .dual {
        didSet {
            needsLayout = true
        }
    }
    
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        addSubview(textView)
        
        let layout = TextViewLayout(.initialize(string: strings().chatListCloseFilter, color: .white, font: .medium(.title)))
        layout.measure(width: max(280, frame.width))
        textView.update(layout)
        
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 5
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.1)
        shadow.shadowOffset = NSMakeSize(0, 2)
        self.shadow = shadow
        set(background: theme.colors.accent, for: .Normal)
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }
    
    override var backgroundColor: NSColor {
        didSet {
            textView.backgroundColor = backgroundColor
        }
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        needsLayout = true
    }
    
    
    
    override func layout() {
        super.layout()
        textView.center()
        
        layer?.cornerRadius = frame.height / 2
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class FilterTabsView : View {
    let tabs: ScrollableSegmentView = ScrollableSegmentView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tabs)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        tabs.frame = bounds
    }
}

struct PeerListState : Equatable {
    struct InputActivities : Equatable {
        struct Activity : Equatable {
            let peer: PeerEquatable
            let activity: PeerInputActivity
            init(_ peer: Peer, _ activity: PeerInputActivity) {
                self.peer = PeerEquatable(peer)
                self.activity = activity
            }
        }
        var activities: [PeerActivitySpace: [Activity]]
    }
    struct ForumData : Equatable {
        static func == (lhs: PeerListState.ForumData, rhs: PeerListState.ForumData) -> Bool {
            if lhs.peer != rhs.peer {
                return false
            }
            if let lhsCached = lhs.peerView.cachedData, let rhsCached = rhs.peerView.cachedData {
                if !lhsCached.isEqual(to: rhsCached) {
                    return false
                }
            } else if (lhs.peerView.cachedData != nil) != (rhs.peerView.cachedData != nil) {
                return false
            }
            if lhs.call != rhs.call {
                return false
            }
            if lhs.online != rhs.online {
                return false
            }
            return true
        }
        
        let peer: TelegramChannel
        let peerView: PeerView
        let online: Int32
        let call: ChatActiveGroupCallInfo?
    }
    
    var proxySettings: ProxySettings
    var connectionStatus: ConnectionStatus
    var splitState: SplitViewState
    var searchState: SearchFieldState = .None
    var peer: PeerEquatable?
    var forumPeer: ForumData?
    var mode: PeerListMode
    var activities: InputActivities
}

class PeerListContainerView : View {
    
    private final class ProxyView : Control {
        fileprivate let button:ImageButton = ImageButton()
        private var connecting: ProgressIndicator?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(button)
            button.userInteractionEnabled = false
            button.isEventLess = true
        }
        
        func update(_ pref: ProxySettings, connection: ConnectionStatus, animated: Bool) {
            switch connection {
            case .connecting, .waitingForNetwork:
                if pref.enabled {
                    let current: ProgressIndicator
                    if let view = self.connecting {
                        current = view
                    } else {
                        current = ProgressIndicator(frame: focus(NSMakeSize(11, 11)))
                        self.connecting = current
                        addSubview(current)
                    }
                    current.userInteractionEnabled = false
                    current.isEventLess = true
                    current.progressColor = theme.colors.accentIcon
                } else if let view = connecting {
                    performSubviewRemoval(view, animated: animated)
                    self.connecting = nil
                }
                
                button.set(image: pref.enabled ? theme.icons.proxyState : theme.icons.proxyEnable, for: .Normal)
            case .online, .updating:
                if let view = connecting {
                    performSubviewRemoval(view, animated: animated)
                    self.connecting = nil
                }
                if pref.enabled  {
                    button.set(image: theme.icons.proxyEnabled, for: .Normal)
                } else {
                    button.set(image: theme.icons.proxyEnable, for: .Normal)
                }
            }
            button.sizeToFit()
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            button.center()
            if let connecting = connecting {
                var rect = connecting.centerFrame()
                if backingScaleFactor == 2.0 {
                    rect.origin.x -= 0.5
                    rect.origin.y -= 0.5
                }
                connecting.frame = rect
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
            connecting?.progressColor = theme.colors.accentIcon
        }
    }
    
    private final class StatusView : Control {
        fileprivate var button:PremiumStatusControl?
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
        }
        
        private var peer: Peer?
        private weak var effectPanel: Window?
        
        func update(_ peer: Peer, context: AccountContext, animated: Bool) {
            
            
            var interactiveStatus: Reactions.InteractiveStatus? = nil
            if visibleRect != .zero, window != nil, let interactive = context.reactions.interactiveStatus {
                interactiveStatus = interactive
            }
            if let view = self.button, interactiveStatus != nil, interactiveStatus?.fileId != nil {
                performSubviewRemoval(view, animated: animated, duration: 0.3)
                self.button = nil
            }
            
            let control = PremiumStatusControl.control(peer, account: context.account, inlinePacksContext: context.inlinePacksContext, isSelected: false, isBig: true, playTwice: true, cached: self.button, animated: animated)
            if let control = control {
                self.button = control
                addSubview(control)
                control.center()
            } else {
                self.button?.removeFromSuperview()
                self.button = nil
            }
            self.peer = peer
            
            if let interactive = interactiveStatus {
                self.playAnimation(interactive, context: context)
            }
        }
        
        private func playAnimation(_  status: Reactions.InteractiveStatus, context: AccountContext) {
            guard let control = self.button, let window = self.window else {
                return
            }
            
            guard let fileId = status.fileId else {
                return
            }
            
            control.isHidden = true
            
            let play:(StatusView)->Void = { [weak control] superview in
                
                guard let control = control else {
                    return
                }
                control.isHidden = false
                
                let panel = Window(contentRect: NSMakeRect(0, 0, 160, 120), styleMask: [.fullSizeContentView], backing: .buffered, defer: false)
                panel._canBecomeMain = false
                panel._canBecomeKey = false
                panel.ignoresMouseEvents = true
                panel.level = .popUpMenu
                panel.backgroundColor = .clear
                panel.isOpaque = false
                panel.hasShadow = false

                let player = CustomReactionEffectView(frame: NSMakeSize(160, 120).bounds, context: context, fileId: fileId)
                
                player.isEventLess = true
                
                player.triggerOnFinish = { [weak panel] in
                    if let panel = panel  {
                        panel.parent?.removeChildWindow(panel)
                        panel.orderOut(nil)
                    }
                }
                superview.effectPanel = panel
                        
                let controlRect = superview.convert(control.frame, to: nil)
                
                var rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
                
                
                rect = window.convertToScreen(rect)
                
                panel.setFrame(rect, display: true)
                
                panel.contentView?.addSubview(player)
                
                window.addChildWindow(panel, ordered: .above)
            }
            if let fromRect = status.rect {
                let layer = InlineStickerItemLayer(account: context.account, inlinePacksContext: context.inlinePacksContext, emoji: .init(fileId: fileId, file: nil, emoji: ""), size: control.frame.size)
                
                let toRect = control.convert(control.frame.size.bounds, to: nil)
                
                let from = fromRect.origin.offsetBy(dx: fromRect.width / 2, dy: fromRect.height / 2)
                let to = toRect.origin.offsetBy(dx: toRect.width / 2, dy: toRect.height / 2)
                
                let completed: (Bool)->Void = { [weak self] _ in
                    DispatchQueue.main.async {
                        if let container = self {
                            play(container)
                            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                        }
                    }
                }
                parabollicReactionAnimation(layer, fromPoint: from, toPoint: to, window: context.window, completion: completed)
            } else {
                play(self)
            }
        }
        
      
        override func layout() {
            super.layout()
            button?.center()
        }
        
        deinit {
            if let panel = effectPanel {
                panel.parent?.removeChildWindow(panel)
                panel.orderOut(nil)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
        }
    }
    
    private final class ActionView : Control {
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
            border = [.Top, .Right]
        }
        
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
            textView.backgroundColor = theme.colors.background
        }
        func update(action: @escaping(PeerId)->Void, peerId: PeerId, title: String) {
            let layout = TextViewLayout(.initialize(string: title, color: theme.colors.accent, font: .normal(.text)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            self.set(background: theme.colors.background, for: .Normal)
            self.set(background: theme.colors.grayBackground, for: .Highlight)

            self.removeAllHandlers()
            self.set(handler: { _ in
                action(peerId)
            }, for: .Click)
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            textView.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    private var callView: ChatGroupCallView?
    
    private let backgroundView = BackgroundView(frame: NSZeroRect)
    
    let tableView = TableView(frame:NSZeroRect, drawBorder: true)
    private let containerView: View = View()
    
    let searchView:SearchView = SearchView(frame:NSMakeRect(10, 0, 0, 0))
    let compose:ImageButton = ImageButton()
    
    private var premiumStatus: StatusView?
    private var downloads: DownloadsControl?
    private var proxy: ProxyView?
    
    private var actionView: ActionView?
    
    
    fileprivate var showDownloads:(()->Void)? = nil
    fileprivate var hideDownloads:(()->Void)? = nil
    

    var mode: PeerListMode = .plain {
        didSet {
            switch mode {
            case .folder:
                compose.isHidden = true
            case .plain:
                compose.isHidden = false
            case .filter:
                compose.isHidden = true
            case .forum:
                compose.isHidden = true
            }
            updateLayout(self.frame.size, transition: .immediate)
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.border = [.Right]
        compose.autohighlight = false
        autoresizesSubviews = false
        addSubview(containerView)
        addSubview(tableView)
        containerView.addSubview(compose)
        containerView.addSubview(searchView)
        addSubview(backgroundView)
        backgroundView.isHidden = true
        
        tableView.getBackgroundColor = {
            .clear
        }
        updateLocalizationAndTheme(theme: theme)
        
    }
    
    private var state: PeerListState?
    
    
    var openProxy:((Control)->Void)? = nil
    var openStatus:((Control)->Void)? = nil

    fileprivate func updateState(_ state: PeerListState, arguments: Arguments, animated: Bool) {
        
        let animated = animated && self.state?.splitState == state.splitState && self.state != nil
        self.state = state
        
        var voiceChat: ChatActiveGroupCallInfo?
        if state.forumPeer?.call?.data?.groupCall == nil {
            if let data = state.forumPeer?.call?.data, data.participantCount == 0 && state.forumPeer?.call?.activeCall.scheduleTimestamp == nil {
                voiceChat = nil
            } else {
                voiceChat = state.forumPeer?.call
            }
        } else {
            voiceChat = nil
        }
        
        if let info = voiceChat, state.splitState != .minimisize {
            let current: ChatGroupCallView
            let rect = NSMakeRect(0, -44, frame.width, 44)
            if let view = self.callView {
                current = view
            } else {
                current = .init({ _, _ in
                    arguments.joinGroupCall(info)
                }, context: arguments.context, state: .none(info), frame: rect)
                self.callView = current
                containerView.addSubview(current)
                
            }
            current.border = [.Right, .Bottom]
            current.update(info, animated: animated)
            
        } else if let view = self.callView {
            performSubviewRemoval(view, animated: animated)
            self.callView = nil
        }
        
        if let peer = state.forumPeer?.peer, peer.participationStatus == .left, state.splitState != .minimisize {
            let current: ActionView
            if let view = self.actionView {
                current = view
            } else {
                current = ActionView(frame: NSMakeRect(0, frame.height - 50, frame.width, 50))
                self.actionView = current
                addSubview(current)
                
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(action: arguments.joinGroup, peerId: peer.id, title: strings().chatInputJoin)
        } else if let view = self.actionView {
            performSubviewRemoval(view, animated: animated)
            self.actionView = nil
        }
        
        self.searchView.isHidden = state.splitState == .minimisize
        
        let componentSize = NSMakeSize(40, 30)
        
        var controlPoint = NSMakePoint(frame.width - 12 - compose.frame.width, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - componentSize.height)/2.0))
        
        let hasControls = state.splitState != .minimisize && state.searchState != .Focus && mode.isPlain
        
        let hasProxy = (!state.proxySettings.servers.isEmpty || state.proxySettings.effectiveActiveServer != nil) && hasControls
        
        let hasStatus = state.peer?.peer.isPremium ?? false && hasControls
        
        if hasProxy {
            controlPoint.x -= componentSize.width
            
            let current: ProxyView
            if let view = self.proxy {
                current = view
            } else {
                current = ProxyView(frame: CGRect(origin: controlPoint, size: componentSize))
                self.proxy = current
                self.containerView.addSubview(current, positioned: .below, relativeTo: searchView)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.set(handler: { [weak self] control in
                    self?.openProxy?(control)
                }, for: .Click)
            }
            current.update(state.proxySettings, connection: state.connectionStatus, animated: animated)
            
        } else if let view = self.proxy {
            performSubviewRemoval(view, animated: animated)
            self.proxy = nil
        }
        
        if hasStatus, let peer = state.peer?.peer {
            
            controlPoint.x -= componentSize.width
            
            let current: StatusView
            if let view = self.premiumStatus {
                current = view
            } else {
                current = StatusView(frame: CGRect(origin: controlPoint, size: componentSize))
                self.premiumStatus = current
                self.containerView.addSubview(current, positioned: .below, relativeTo: searchView)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.set(handler: { [weak self] control in
                    self?.openStatus?(control)
                }, for: .Click)
            }
            current.update(peer, context: arguments.context, animated: animated)
            
        } else if let view = self.premiumStatus {
            performSubviewRemoval(view, animated: animated)
            self.premiumStatus = nil
        }
        
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
  
        self.updateLayout(self.frame.size, transition: transition)
    }
    
    
    private func updateTags(_ state: PeerListState,updateSearchTags: @escaping(SearchTags)->Void, updatePeerTag:@escaping(@escaping(Peer?)->Void)->Void, updateMessageTags: @escaping(@escaping(MessageTags?)->Void)->Void) {
        var currentTag: MessageTags?
        var currentPeerTag: Peer?
        let tags:[(MessageTags?, String, CGImage)] = [(nil, strings().searchFilterClearFilter, theme.icons.search_filter),
                                            (.photo, strings().searchFilterPhotos, theme.icons.search_filter_media),
                                            (.video, strings().searchFilterVideos, theme.icons.search_filter_media),
                                            (.webPage, strings().searchFilterLinks, theme.icons.search_filter_links),
                                            (.music, strings().searchFilterMusic, theme.icons.search_filter_music),
                                            (.voiceOrInstantVideo, strings().searchFilterVoice, theme.icons.search_filter_music),
                                            (.gif, strings().searchFilterGIFs, theme.icons.search_filter_media),
                                            (.file, strings().searchFilterFiles, theme.icons.search_filter_files)]
        
        let collectTags: ()-> ([String], CGImage) = {
            var values: [String] = []
            let image: CGImage

            if let tag = currentPeerTag {
                values.append(tag.compactDisplayTitle.prefix(10))
            }
            if let tag = currentTag {
                if let found = tags.first(where: { $0.0 == tag }) {
                    values.append(found.1)
                    image = found.2
                } else {
                    image = theme.icons.search_filter
                }
            } else {
                image = theme.icons.search_filter
            }
            return (values, image)
        }
        
        switch state.searchState {
        case .Focus:
            if searchView.customSearchControl == nil {
                searchView.customSearchControl = CustomSearchController(clickHandler: { [weak self] control, updateTitle in
                    
                    var items: [ContextMenuItem] = []

                    if state.forumPeer == nil {
                        items.append(ContextMenuItem(strings().chatListDownloadsTag, handler: { [weak self] in
                            updateSearchTags(SearchTags(messageTags: nil, peerTag: nil))
                            self?.showDownloads?()
                        }, itemImage: MenuAnimation.menu_save_as.value))
                    }
                    
                    for tag in tags {
                        var append: Bool = false
                        if currentTag != tag.0 {
                            append = true
                        }
                        
                        if append {
                            if let messagetag = tag.0 {
                                let itemImage: MenuAnimation?
                                switch messagetag {
                                case .photo:
                                    itemImage = .menu_shared_media
                                case .video:
                                    itemImage = .menu_video
                                case .webPage:
                                    itemImage = .menu_copy_link
                                case .voiceOrInstantVideo:
                                    itemImage = .menu_voice
                                case .gif:
                                    itemImage = .menu_add_gif
                                case .file:
                                    itemImage = .menu_file
                                default:
                                    itemImage = nil
                                }
                                if let itemImage = itemImage {
                                    items.append(ContextMenuItem(tag.1, handler: { [weak self] in
                                        currentTag = tag.0
                                        updateSearchTags(SearchTags(messageTags: currentTag, peerTag: currentPeerTag?.id))
                                        let collected = collectTags()
                                        updateTitle(collected.0, collected.1)
                                        self?.hideDownloads?()
                                    }, itemImage: itemImage.value))
                                }
                            }
                            
                        }
                    }
                    
                    let menu = ContextMenu()
                    for item in items {
                        menu.addItem(item)
                    }
                    
                    let value = AppMenu(menu: menu)
                    if let event = NSApp.currentEvent {
                        value.show(event: event, view: control)
                    }
                }, deleteTag: { [weak self] index in
                    var count: Int = 0
                    if currentTag != nil {
                        count += 1
                    }
                    if currentPeerTag != nil {
                        count += 1
                    }
                    if index == 1 || count == 1 {
                        currentTag = nil
                    }
                    if index == 0 {
                        currentPeerTag = nil
                    }
                    let collected = collectTags()
                    updateSearchTags(SearchTags(messageTags: currentTag, peerTag: currentPeerTag?.id))
                    self?.searchView.updateTags(collected.0, collected.1)
                    self?.hideDownloads?()
                }, icon: theme.icons.search_filter)
            }
            
            updatePeerTag( { [weak self] updatedPeerTag in
                guard let `self` = self else {
                    return
                }
                currentPeerTag = updatedPeerTag
                updateSearchTags(SearchTags(messageTags: currentTag, peerTag: currentPeerTag?.id))
                self.searchView.setString("")
                let collected = collectTags()
                self.searchView.updateTags(collected.0, collected.1)
            })
            
            updateMessageTags( { [weak self] updatedMessageTags in
                guard let `self` = self else {
                    return
                }
                currentTag = updatedMessageTags
                updateSearchTags(SearchTags(messageTags: currentTag, peerTag: currentPeerTag?.id))
                let collected = collectTags()
                self.searchView.updateTags(collected.0, collected.1)
            })
            
        case .None:
            searchView.customSearchControl = nil
        }
    }
    
    fileprivate func searchStateChanged(_ state: PeerListState, arguments: Arguments, animated: Bool, updateSearchTags: @escaping(SearchTags)->Void, updatePeerTag:@escaping(@escaping(Peer?)->Void)->Void, updateMessageTags: @escaping(@escaping(MessageTags?)->Void)->Void) {
                        
        self.updateTags(state, updateSearchTags: updateSearchTags, updatePeerTag: updatePeerTag, updateMessageTags: updateMessageTags)

        self.updateState(state, arguments: arguments, animated: animated)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        compose.set(background: .clear, for: .Normal)
        compose.set(background: .clear, for: .Hover)
        compose.set(background: theme.colors.accent, for: .Highlight)
        compose.set(image: theme.icons.composeNewChat, for: .Normal)
        compose.set(image: theme.icons.composeNewChat, for: .Hover)
        compose.set(image: theme.icons.composeNewChatActive, for: .Highlight)
        compose.layer?.cornerRadius = .cornerRadius
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        self.updateLayout(frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        guard let state = self.state else {
            return
        }
        
        var offset: CGFloat
        switch theme.controllerBackgroundMode {
        case .background:
            offset = 50
        case .tiled:
            offset = 50
        default:
            offset = 50
        }
        
        if state.splitState == .minimisize {
            switch self.mode {
            case .folder, .forum:
                offset = 0
            default:
                break
            }
        }
        var inset: CGFloat = 0
        if let callView = self.callView {
            offset += callView.frame.height
            inset = callView.frame.height
            transition.updateFrame(view: callView, frame: NSMakeRect(0, 0, size.width, callView.frame.height))
        }
        
        let componentSize = NSMakeSize(40, 30)
        
        transition.updateFrame(view: self.containerView, frame: NSMakeRect(0, 0, size.width, offset))

        var searchWidth = (size.width - 10 * 2)
        
        if state.searchState != .Focus && state.mode.isPlain {
            searchWidth -= (componentSize.width + 12)
        }
        if let _ = self.proxy {
            searchWidth -= componentSize.width
        }
        if let _ = self.premiumStatus {
            searchWidth -= componentSize.width
        }
        
        let searchRect = NSMakeRect(10, floorToScreenPixels(backingScaleFactor, inset + (offset - inset - componentSize.height)/2.0), searchWidth, componentSize.height)
        
        transition.updateFrame(view: searchView, frame: searchRect)
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, offset, size.width, size.height - offset))

        transition.updateFrame(view: backgroundView, frame: size.bounds)
        
        if let downloads = downloads {
            let rect = NSMakeRect(0, size.height - downloads.frame.height, size.width - .borderSize, downloads.frame.height)
            transition.updateFrame(view: downloads, frame: rect)
        }
        if state.splitState == .minimisize {
            transition.updateFrame(view: compose, frame: compose.centerFrame())
        } else {
            
            var controlPoint = NSMakePoint(size.width - 12, floorToScreenPixels(backingScaleFactor, (offset - componentSize.height)/2.0))

            controlPoint.x -= componentSize.width
            
            transition.updateFrame(view: compose, frame: CGRect(origin: controlPoint, size: componentSize))
                        
            if let view = proxy {
                controlPoint.x -= componentSize.width
                transition.updateFrame(view: view, frame: CGRect(origin: controlPoint, size: componentSize))
            }
            if let view = premiumStatus {
                controlPoint.x -= componentSize.width
                transition.updateFrame(view: view, frame: CGRect(origin: controlPoint, size: componentSize))
            }
        }
        if let actionView = self.actionView {
            transition.updateFrame(view: actionView, frame: CGRect(origin: CGPoint(x: 0, y: size.height - actionView.frame.height), size: actionView.frame.size))
        }
    }
    
    func updateDownloads(_ state: DownloadsSummary.State, context: AccountContext, arguments: DownloadsControlArguments, animated: Bool) {
        if !state.isEmpty {
            let current: DownloadsControl
            if let view = self.downloads {
                current = view
            } else {
                current = DownloadsControl(frame: NSMakeRect(0, frame.height - 30, frame.width - .borderSize, 30))
                self.downloads = current
                addSubview(current, positioned: .above, relativeTo: self.tableView)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animatePosition(from: NSMakePoint(current.frame.minX, current.frame.maxY), to: current.frame.origin)
                }
            }
            current.update(state, context: context, arguments: arguments, animated: animated)
            current.removeAllHandlers()
            current.set(handler: { _ in
                arguments.open()
            }, for: .Click)
        } else if let view = self.downloads {
            self.downloads = nil
            performSubviewPosRemoval(view, pos: NSMakePoint(0, frame.maxY), animated: true)
        }
    }
    
}


enum PeerListMode : Equatable {
    case plain
    case folder(EngineChatList.Group)
    case filter(Int32)
    case forum(PeerId)
    var isPlain:Bool {
        switch self {
        case .plain:
            return true
        default:
            return false
        }
    }
    var groupId: EngineChatList.Group {
        switch self {
        case let .folder(groupId):
            return groupId
        default:
            return .root
        }
    }
    var filterId: Int32? {
        switch self {
        case let .filter(id):
            return id
        default:
            return nil
        }
    }
    var location: ChatListControllerLocation {
        switch self {
        case .plain:
            return .chatList(groupId: .root)
        case let .folder(group):
            return .chatList(groupId: group._asGroup())
        case let .forum(peerId):
            return .forum(peerId: peerId)
        case let .filter(filterId):
            return .chatList(groupId: .group(filterId))
        }
    }
}


class PeersListController: TelegramGenericViewController<PeerListContainerView>, TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private  let stateValue: Atomic<PeerListState?> = Atomic(value: nil)
    private let stateSignal: ValuePromise<PeerListState?> = ValuePromise(nil, ignoreRepeated: true)
    var stateUpdater: Signal<PeerListState?, NoError> {
        return stateSignal.get()
    }
    
    
    private let progressDisposable = MetaDisposable()
    private let createSecretChatDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let followGlobal:Bool
    private let searchOptions: AppSearchOptions
    
    private var downloadsController: ViewController?
    
    let mode:PeerListMode
    private(set) var searchController:SearchController? {
        didSet {
            if let controller = searchController {
                genericView.customHandler.size = { [weak controller, weak self] size in
                    let frame = self?.genericView.tableView.frame ?? size.bounds
                    controller?.view.frame = frame
                }
                progressDisposable.set((controller.isLoading.get() |> deliverOnMainQueue).start(next: { [weak self] isLoading in
                    self?.genericView.searchView.isLoading = isLoading
                }))
            }
        }
    }
    
    let topics: ForumChannelTopics?
    
    init(_ context: AccountContext, followGlobal:Bool = true, mode: PeerListMode = .plain, searchOptions: AppSearchOptions = [.chats, .messages]) {
        self.followGlobal = followGlobal
        self.mode = mode
        self.searchOptions = searchOptions
        switch mode {
        case let .forum(peerId):
            self.topics = ForumChannelTopics(account: context.account, peerId: peerId)
        default:
            self.topics = nil
        }
        super.init(context)
        self.bar = .init(height: !mode.isPlain ? 50 : 0)
    }
    
    override var redirectUserInterfaceCalls: Bool {
        return true
    }
    
    override var responderPriority: HandlerPriority {
        return .low
    }
    
    deinit {
        progressDisposable.dispose()
        createSecretChatDisposable.dispose()
        actionsDisposable.dispose()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    func showDownloads(animated: Bool) {
        
        self.genericView.searchView.change(state: .Focus,  true)

        let controller: ViewController
        if let current = self.downloadsController {
            controller = current
        } else {
            controller = DownloadsController(context: context, searchValue: self.genericView.searchView.searchValue |> map { $0.request })
            self.downloadsController = controller
            
            controller.frame = genericView.tableView.frame
            addSubview(controller.view)
            
            if animated {
                controller.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                controller.view.layer?.animateScaleSpring(from: 1.1, to: 1, duration: 0.2)
            }
        }
        self.genericView.searchView.updateTags([strings().chatListDownloadsTag], theme.icons.search_filter_downloads)

    }
    
    private func hideDownloads(animated: Bool) {
        if let downloadsController = downloadsController {
            downloadsController.viewWillDisappear(animated)
            self.downloadsController = nil
            downloadsController.viewDidDisappear(animated)
            
            let view = downloadsController.view
            downloadsController.view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                view?.removeFromSuperview()
            })
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context
        let mode = self.mode

        
        genericView.showDownloads = { [weak self] in
            self?.showDownloads(animated: true)
        }
        genericView.hideDownloads = { [weak self] in
            self?.hideDownloads(animated: true)
        }
        
        
        let actionsDisposable = self.actionsDisposable
        
        actionsDisposable.add((context.cancelGlobalSearch.get() |> deliverOnMainQueue).start(next: { [weak self] animated in
            self?.genericView.searchView.cancel(animated)
        }))
        
        genericView.mode = mode
        
        if followGlobal {
            actionsDisposable.add((context.globalPeerHandler.get() |> deliverOnMainQueue).start(next: { [weak self] location in
                guard let `self` = self else {return}
                self.changeSelection(location)
                if location == nil {
                    if !self.genericView.searchView.isEmpty {
                        _ = self.window?.makeFirstResponder(self.genericView.searchView.input)
                    }
                }
            }))
        }
        
        if self.navigationController?.modalAction is FWDNavigationAction {
            self.setCenterTitle(strings().chatForwardActionHeader)
        }
        
        if self.navigationController?.modalAction is ShareInlineResultNavigationAction {
            self.setCenterTitle(strings().chatShareInlineResultActionHeader)
        }
        
        genericView.tableView.delegate = self
        
        let state = self.stateSignal
        let stateValue = self.stateValue
       
        let updateState:((PeerListState?)->PeerListState?) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        

        let layoutSignal = context.layoutValue
        let proxy = proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { ps -> Signal<(ProxySettings, ConnectionStatus), NoError> in
            return context.account.network.connectionStatus |> map { status -> (ProxySettings, ConnectionStatus) in
                return (ps, status)
            }
        }
        let peer: Signal<PeerEquatable?, NoError> = context.account.postbox.peerView(id: context.peerId) |> map { view in
            if let peer = peerViewMainPeer(view) {
                return PeerEquatable(peer)
            } else {
                return nil
            }
        }
        let forumPeer: Signal<PeerListState.ForumData?, NoError>

        if case let .forum(peerId) = self.mode {
            
            let signal = combineLatest(context.account.postbox.peerView(id: peerId), getGroupCallPanelData(context: context, peerId: peerId))
            forumPeer = signal |> mapToSignal { view, call in
                if let peer = peerViewMainPeer(view) as? TelegramChannel, let cachedData = view.cachedData as? CachedChannelData, peer.isForum {
                    
                    let info: ChatActiveGroupCallInfo?
                    if let activeCall = cachedData.activeCall {
                        info = .init(activeCall: activeCall, data: call, callJoinPeerId: cachedData.callJoinPeerId, joinHash: nil, isLive: peer.isChannel || peer.isGigagroup)
                    } else {
                        info = nil
                    }
                    
                    let membersCount = cachedData.participantsSummary.memberCount ?? 0
                    let online: Signal<Int32, NoError>
                    if membersCount < 200 {
                        online = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: peerId)
                    } else {
                        online = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: peerId)
                    }
                    return online |> map {
                        return .init(peer: peer, peerView: view, online: $0, call: info)
                    }
                } else {
                    return .single(nil)
                }
            }
            
        } else {
            forumPeer = .single(nil)
        }
        let postbox = context.account.postbox
        let previousPeerCache = Atomic<[PeerId: Peer]>(value: [:])
        let previousActivities = Atomic<PeerListState.InputActivities?>(value: nil)
        let inputActivities = context.account.allPeerInputActivities()
                                           |> mapToSignal { activitiesByPeerId -> Signal<[PeerActivitySpace: [PeerListState.InputActivities.Activity]], NoError> in
                var foundAllPeers = true
                var cachedResult: [PeerActivitySpace: [PeerListState.InputActivities.Activity]] = [:]
                previousPeerCache.with { dict -> Void in
                    for (chatPeerId, activities) in activitiesByPeerId {
                        
                        var cachedChatResult: [PeerListState.InputActivities.Activity] = []
                        for (peerId, activity) in activities {
                            if let peer = dict[peerId] {
                                cachedChatResult.append(PeerListState.InputActivities.Activity(peer, activity))
                            } else {
                                foundAllPeers = false
                                break
                            }
                            cachedResult[chatPeerId] = cachedChatResult
                        }
                    }
                }
                if foundAllPeers {
                    return .single(cachedResult)
                } else {
                    return postbox.transaction { transaction -> [PeerActivitySpace: [PeerListState.InputActivities.Activity]] in
                        var result: [PeerActivitySpace: [PeerListState.InputActivities.Activity]] = [:]
                        var peerCache: [PeerId: Peer] = [:]
                        for (chatPeerId, activities) in activitiesByPeerId {
                            
                            var chatResult: [PeerListState.InputActivities.Activity] = []
                            for (peerId, activity) in activities {
                                if let peer = transaction.getPeer(peerId) {
                                    chatResult.append(PeerListState.InputActivities.Activity(peer, activity))
                                    peerCache[peerId] = peer
                                }
                            }
                            result[chatPeerId] = chatResult
                        }
                        let _ = previousPeerCache.swap(peerCache)
                        return result
                    }
                }
            }
            |> map { activities -> PeerListState.InputActivities in
                return previousActivities.modify { current in
                    var updated = false
                    let currentList: [PeerActivitySpace: [PeerListState.InputActivities.Activity]] = current?.activities ?? [:]
                    if currentList.count != activities.count {
                        updated = true
                    } else {
                        outer: for (space, currentValue) in currentList {
                            if let value = activities[space] {
                                if currentValue.count != value.count {
                                    updated = true
                                    break outer
                                } else {
                                    for i in 0 ..< currentValue.count {
                                        if currentValue[i] != value[i] {
                                            updated = true
                                            break outer
                                        }
                                    }
                                }
                            } else {
                                updated = true
                                break outer
                            }
                        }
                    }
                    if updated {
                        if activities.isEmpty {
                            return .init(activities: [:])
                        } else {
                            return .init(activities: activities)
                        }
                    } else {
                        return current
                    }
                } ?? .init(activities: [:])
            }
        
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), proxy, layoutSignal, peer, forumPeer, inputActivities, appearanceSignal).start(next: { pref, layout, peer, forumPeer, inputActivities, _ in
            updateState { state in
                let state: PeerListState = .init(proxySettings: pref.0, connectionStatus: pref.1, splitState: layout, searchState: state?.searchState ?? .None, peer: peer, forumPeer: forumPeer, mode: mode, activities: inputActivities)
                return state
            }
        }))
        
        let pushController:(ViewController)->Void = { [weak self] c in
            self?.context.bindings.rootNavigation().push(c)
        }
                
        let openProxySettings:()->Void = { [weak self] in
            if let controller = self?.context.bindings.rootNavigation().controller as? InputDataController {
                if controller.identifier == "proxy" {
                    return
                }
            }
            let controller = proxyListController(accountManager: context.sharedContext.accountManager, network: context.account.network, share: { servers in
                var message: String = ""
                for server in servers {
                    message += server.link + "\n\n"
                }
                message = message.trimmed

                showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: context.window)
            }, pushController: { controller in
                 pushController(controller)
            })
            pushController(controller)
        }
        
        
        genericView.openProxy = { _ in
            openProxySettings()
        }
        
        genericView.openStatus = { control in
            let peer = stateValue.with { $0?.peer?.peer }
            if let peer = peer as? TelegramUser {
                let callback:(TelegramMediaFile, Int32?, CGRect?)->Void = { file, timeout, fromRect in
                    context.reactions.setStatus(file, peer: peer, timestamp: context.timestamp, timeout: timeout, fromRect: fromRect)
                }
                if control.popover == nil {
                    showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
                }
            }
        }

        genericView.compose.contextMenu = { [weak self] in
            let items = [ContextMenuItem(strings().composePopoverNewGroup, handler: { [weak self] in
                self?.context.composeCreateGroup()
            }, itemImage: MenuAnimation.menu_create_group.value),
            ContextMenuItem(strings().composePopoverNewSecretChat, handler: { [weak self] in
                self?.context.composeCreateSecretChat()
            }, itemImage: MenuAnimation.menu_lock.value),
            ContextMenuItem(strings().composePopoverNewChannel, handler: { [weak self] in
                self?.context.composeCreateChannel()
            }, itemImage: MenuAnimation.menu_channel.value)];
            
            let menu = ContextMenu()
            for item in items {
                menu.addItem(item)
            }
            return menu
        }
        
        genericView.searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            switch state.state {
            case .Focus:
                assert(self?.searchController == nil)
                self?.showSearchController(animated: animated)
                
            case .None:
                self?.hideSearchController(animated: animated)
            }
            updateState { current in
                var current = current
                current?.searchState = state.state
                return current
            }
        }, { [weak self] state in
            updateState { current in
                var current = current
                current?.searchState = state.state
                return current
            }
            self?.searchController?.request(with: state.request)
        }, responderModified: { [weak self] state in
            self?.context.isInGlobalSearch = state.responder
        })
        
        let stateSignal = state.get()
        |> filter { $0 != nil }
        |> map { $0! }
        
        let previousState: Atomic<PeerListState?> = Atomic(value: nil)
        
        
        let arguments = Arguments(context: context, joinGroupCall: { info in
            if case let .forum(peerId) = mode {
                let join:(PeerId, Date?, Bool)->Void = { joinAs, _, _ in
                    _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: joinAs, initialCall: info.activeCall, initialInfo: info.data?.info, joinHash: nil), for: context.window).start(next: { result in
                        switch result {
                        case let .samePeer(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        case let .success(callContext):
                            applyGroupCallResult(context.sharedContext, callContext)
                        default:
                            alert(for: context.window, info: strings().errorAnError)
                        }
                    })
                }
                if let callJoinPeerId = info.callJoinPeerId {
                    join(callJoinPeerId, nil, false)
                } else {
                    selectGroupCallJoiner(context: context, peerId: peerId, completion: join)
                }
            }
        }, joinGroup: { peerId in
            joinChannel(context: context, peerId: peerId)
        })
        
        self.takeArguments = { [weak arguments] in
            return arguments
        }
        
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.updateState(state, previous: previousState.swap(state), arguments: arguments)
        }))
        
        centerBarView.set(handler: { _ in
            switch mode {
            case let .forum(peerId):
                ForumUI.openInfo(peerId, context: context)
            default:
                break
            }
        }, for: .Click)
    }
    
    private var state: PeerListState? {
        return self.stateValue.with { $0 }
    }
    
    private func updateState(_ state: PeerListState, previous: PeerListState?, arguments: Arguments) {
        if previous?.forumPeer != state.forumPeer {
            if state.forumPeer == nil {
                switch self.mode {
                case let .forum(peerId):
                    if state.splitState == .single {
                        let controller = ChatController(context: context, chatLocation: .peer(peerId))
                        self.navigationController?.push(controller)
                        self.navigationController?.removeImmediately(self, depencyReady: controller)
                    } else {
                        self.navigationController?.back()
                    }
                default:
                    break
                }
                return
            }
        }
        if previous?.splitState != state.splitState {
            if  case .minimisize = state.splitState {
                if self.genericView.searchView.state == .Focus {
                    self.genericView.searchView.change(state: .None,  false)
                }
            }
            self.checkSearchMedia()
            self.genericView.tableView.alwaysOpenRowsOnMouseUp = state.splitState == .single
            self.genericView.tableView.reloadData()
            self.requestUpdateBackBar()
        }
              
        setCenterTitle(self.defaultBarTitle)
        if let forum = state.forumPeer {
            let title = stringStatus(for: forum.peerView, context: context, onlineMemberCount: forum.online, expanded: true)
            setCenterStatus(title.status.string)
        } else {
            setCenterStatus(nil)
        }
        
        self.genericView.searchStateChanged(state, arguments: arguments, animated: true, updateSearchTags: { [weak self] tags in
            self?.searchController?.updateSearchTags(tags)
            self?.sharedMediaWithToken(tags)
        }, updatePeerTag: { [weak self] f in
            self?.searchController?.setPeerAsTag = f
        }, updateMessageTags: { [weak self] f in
            self?.updateSearchMessageTags = f
        })
        
        if let forum = state.forumPeer {
            if forum.peer.participationStatus == .left && previous?.forumPeer?.peer.participationStatus == .member {
                self.navigationController?.back()
            }
        }
    }
    
    private var topicRightBar: ImageButton?
    
    override func requestUpdateRightBar() {
        super.requestUpdateRightBar()
        topicRightBar?.style = navigationButtonStyle
        topicRightBar?.set(image: theme.icons.chatActions, for: .Normal)
        topicRightBar?.set(image: theme.icons.chatActionsActive, for: .Highlight)
        topicRightBar?.setFrameSize(70, 50)
        topicRightBar?.center()
    }
    
    private var takeArguments:()->Arguments? = {
        return nil
    }
    
    override func getRightBarViewOnce() -> BarView {
        switch self.mode {
        case .forum:
            let bar = BarView(70, controller: self)
            let button = ImageButton()
            bar.addSubview(button)
            let context = self.context
                
            self.topicRightBar = button
            
            button.contextMenu = { [weak self] in
                let menu = ContextMenu()
                
                if let peer = self?.state?.forumPeer {
                    var items: [ContextMenuItem] = []
                    
                    let chatController = context.bindings.rootNavigation().controller as? ChatController
                    let infoController = context.bindings.rootNavigation().controller as? PeerInfoController
                    let topicController = context.bindings.rootNavigation().controller as? InputDataController

                    if infoController == nil || (infoController?.peerId != peer.peer.id || infoController?.threadInfo != nil) {
                        items.append(ContextMenuItem(strings().forumTopicContextInfo, handler: {
                            ForumUI.openInfo(peer.peer.id, context: context)
                        }, itemImage: MenuAnimation.menu_show_info.value))
                    }
                    
                    if chatController == nil || (chatController?.chatInteraction.chatLocation != .peer(peer.peer.id)) {
                        items.append(ContextMenuItem(strings().forumTopicContextShowAsMessages, handler: { [weak self] in
                            self?.open(with: .chatId(.chatList(peer.peer.id), peer.peer.id, -1), forceAnimated: true)
                        }, itemImage: MenuAnimation.menu_read.value))
                    }
                    
                    if let call = self?.state?.forumPeer?.call {
                        if call.data?.groupCall == nil {
                            if let data = call.data, data.participantCount == 0 && call.activeCall.scheduleTimestamp == nil {
                                items.append(ContextMenuItem(strings().peerInfoActionVoiceChat, handler: { [weak self] in
                                    self?.takeArguments()?.joinGroupCall(call)
                                }, itemImage: MenuAnimation.menu_video_chat.value))
                            }
                        }
                    }
                    
                    if peer.peer.isAdmin && !peer.peer.hasBannedRights(.banPinMessages) {
                        if topicController?.identifier != "ForumTopic" {
                            if !items.isEmpty {
                                items.append(ContextSeparatorItem())
                            }
                            items.append(ContextMenuItem(strings().forumTopicContextNew, handler: {
                                ForumUI.createTopic(peer.peer.id, context: context)
                            }, itemImage: MenuAnimation.menu_edit.value))
                        }
                    }
                    
                    if !items.isEmpty {
                        for item in items {
                            menu.addItem(item)
                        }
                    }
                }
                
                return menu
            }
            return bar
        default:
            break
        }
        return super.getRightBarViewOnce()
    }
    
    override var defaultBarTitle: String {
        switch self.mode {
        case .folder:
            return strings().chatListArchivedChats
        case .forum:
            return state?.forumPeer?.peer.displayTitle ?? super.defaultBarTitle
        default:
            return super.defaultBarTitle
        }
    }
    
    private func checkSearchMedia() {
        let destroy:()->Void = { [weak self] in
            if let previous = self?.mediaSearchController {
                self?.context.bindings.rootNavigation().removeImmediately(previous)
            }
        }
        guard context.layout == .dual else {
            destroy()
            return
        }
        guard let _ = self.searchController else {
            destroy()
            return
        }
    }
    private weak var mediaSearchController: PeerMediaController?
    private var updateSearchMessageTags: ((MessageTags?)->Void)? = nil
    private func sharedMediaWithToken(_ tags: SearchTags) -> Void {
        
        let destroy:()->Void = { [weak self] in
            if let previous = self?.mediaSearchController {
                self?.context.bindings.rootNavigation().removeImmediately(previous)
            }
        }
        
        guard context.layout == .dual else {
            destroy()
            return
        }
        guard let searchController = self.searchController else {
            destroy()
            return
        }
        guard let messageTags = tags.messageTags else {
            destroy()
            return
        }
        if let peerId = tags.peerTag {
            
            let onDeinit: ()->Void = { [weak self] in
                self?.updateSearchMessageTags?(nil)
            }
            
            let navigation = context.bindings.rootNavigation()
            
            let signal = searchController.externalSearchMessages
                |> filter { $0 != nil && $0?.tags == messageTags }
            
            let controller = PeerMediaController(context: context, peerId: peerId, isProfileIntended: false, externalSearchData: PeerMediaExternalSearchData(initialTags: messageTags, searchResult: signal, loadMore: { }))
            
            controller.onDeinit = onDeinit
            
            navigation.push(controller, false, style: nil)
            
            if let previous = self.mediaSearchController {
                previous.onDeinit = nil
                navigation.removeImmediately(previous, depencyReady: controller)
            }
            
            self.mediaSearchController = controller
        }
    }
    
    override func requestUpdateBackBar() {
        self.leftBarView.minWidth = 70
        super.requestUpdateBackBar()
    }
    
    override func getLeftBarViewOnce() -> BarView {
        let view = BackNavigationBar(self, canBeEmpty: true)
        view.minWidth = 70
        return view
    }
    
    override func backSettings() -> (String, CGImage?) {
        return context.layout == .minimisize ? ("", theme.icons.instantViewBack) : super.backSettings()
    }
    
    
    func changeSelection(_ location: ChatLocation?) {
        if let location = location {
            var id: UIChatListEntryId
            switch location {
            case .peer:
                id = .chatId(.chatList(location.peerId), location.peerId, -1)
            case let .thread(data):
                let threadId = makeMessageThreadId(data.messageId)
                
                switch self.mode {
                case .plain, .filter, .folder:
                    id = .forum(location.peerId)
                case .forum:
                    id = .chatId(.forum(threadId), location.peerId, -1)
                }
            }
            if self.genericView.tableView.item(stableId: id) == nil {
                let fId = UIChatListEntryId.forum(location.peerId)
                if self.genericView.tableView.item(stableId: fId) != nil {
                    id = fId
                }
            }
            self.genericView.tableView.changeSelection(stableId: id)
        } else {
            self.genericView.tableView.changeSelection(stableId: nil)
        }
    }
    
    private func showSearchController(animated: Bool) {
      
        
        if searchController == nil {
            
            let initialTags: SearchTags
            let target: SearchController.Target
            switch self.mode {
            case let .forum(peerId):
                initialTags = .init(messageTags: nil, peerTag: nil)
                target = .forum(peerId)
            default:
                initialTags = .init(messageTags: nil, peerTag: nil)
                target = .common(.root)
            }
            
            let rect = self.genericView.tableView.frame
            let frame = rect
            let searchController = SearchController(context: self.context, open: { [weak self] (id, messageId, close) in
                if let id = id {
                    self?.open(with: id, messageId: messageId, close: close)
                } else {
                    self?.genericView.searchView.cancel(true)
                }
            }, options: self.searchOptions, frame: frame, target: target, tags: initialTags)
            
            searchController.pinnedItems = self.collectPinnedItems
            
            self.searchController = searchController
            
            
            searchController.defaultQuery = self.genericView.searchView.query
            searchController.navigationController = self.navigationController
            searchController.viewWillAppear(true)
            searchController.loadViewIfNeeded()
            
            let signal = searchController.ready.get() |> take(1)
            _ = signal.start(next: { [weak searchController, weak self] _ in
                if let searchController = searchController {
                    if animated {
                        searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion:{ [weak self] complete in
                            if complete {
                                self?.searchController?.viewDidAppear(animated)
                            }
                        })
                        searchController.view.layer?.animateScaleSpring(from: 1.05, to: 1.0, duration: 0.4, bounce: false)
                        searchController.view.layer?.animatePosition(from: NSMakePoint(rect.minX, rect.minY + 15), to: rect.origin, duration: 0.4, timingFunction: .spring)

                    } else {
                        searchController.viewDidAppear(animated)
                    }
                    self?.addSubview(searchController.view)
                }
            })
            
        }
    }
    
    private func hideSearchController(animated: Bool) {
        
        if let downloadsController = downloadsController {
            downloadsController.viewWillDisappear(animated)
            self.downloadsController = nil
            downloadsController.viewDidDisappear(animated)
            
            let view = downloadsController.view
            downloadsController.view.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak view] _ in
                view?.removeFromSuperview()
            })
        }
        
        if let searchController = self.searchController {
            
            let animated = animated && searchController.didSetReady
            
            searchController.viewWillDisappear(animated)
            searchController.view.layer?.opacity = animated ? 1.0 : 0.0
        
            searchController.viewDidDisappear(true)
            self.searchController = nil
            self.genericView.tableView.isHidden = false
            self.genericView.tableView.change(opacity: 1, animated: animated)
            let view = searchController.view
        
            searchController.view._change(opacity: 0, animated: animated, duration: 0.25, timingFunction: CAMediaTimingFunctionName.spring, completion: { [weak view] completed in
                view?.removeFromSuperview()
            })
            if animated {
                searchController.view.layer?.animateScaleSpring(from: 1.0, to: 1.05, duration: 0.4, removeOnCompletion: false, bounce: false)
                genericView.tableView.layer?.animateScaleSpring(from: 0.95, to: 1.00, duration: 0.4, removeOnCompletion: false, bounce: false)
            }

        }
        if let controller = mediaSearchController {
            context.bindings.rootNavigation().removeImmediately(controller, upNext: false)
        }
    }
    
    override func focusSearch(animated: Bool, text: String? = nil) {
        genericView.searchView.change(state: .Focus, animated)
        if let text = text {
            genericView.searchView.setString(text)
        }
    }
   
    
    var collectPinnedItems:[PinnedItemId] {
        return []
    }
    

    
    public override func escapeKeyAction() -> KeyHandlerResult {
        guard context.layout != .minimisize else {
            return .invoked
        }
        if genericView.tableView.highlightedItem() != nil {
            genericView.tableView.cancelHighlight()
            return .invoked
        }
        if genericView.searchView.state == .None {
            return genericView.searchView.changeResponder() ? .invoked : .rejected
        } else if genericView.searchView.state == .Focus && genericView.searchView.query.length > 0 {
            genericView.searchView.change(state: .None,  true)
            return .invoked
        }
        return .rejected
    }
    
    public override func returnKeyAction() -> KeyHandlerResult {
        if let highlighted = genericView.tableView.highlightedItem() {
            _ = genericView.tableView.select(item: highlighted)
            return .invoked
        }
        return .rejected
    }
    
    func open(with entryId: UIChatListEntryId, messageId:MessageId? = nil, initialAction: ChatInitialAction? = nil, close:Bool = true, addition: Bool = false, forceAnimated: Bool = false) ->Void {
        
        let navigation = context.bindings.rootNavigation()
        
        var addition = addition
        var close = close
        if let searchTags = self.searchController?.searchTags {
            if searchTags.peerTag != nil && searchTags.messageTags != nil {
                addition = true
            }
            if !searchTags.isEmpty {
                close = false
            }
        }
        
        switch entryId {
        case let .chatId(type, peerId, _):
            switch type {
            case let .chatList(peerId):
                if let modalAction = navigation.modalAction as? FWDNavigationAction, peerId == context.peerId {
                    _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId, replyId: nil).start()
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                    modalAction.afterInvoke()
                    navigation.removeModalAction()
                } else {
                    if let current = navigation.controller as? ChatController, peerId == current.chatInteraction.peerId, let messageId = messageId, current.mode == .history {
                        current.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
                    } else {
                        let chatLocation: ChatLocation = .peer(peerId)
                        let chat: ChatController
                        if addition {
                            chat = ChatAdditionController(context: context, chatLocation: chatLocation, messageId: messageId)
                        } else {
                            chat = ChatController(context: self.context, chatLocation: chatLocation, messageId: messageId, initialAction: initialAction)
                        }
                        let animated = context.layout == .single || forceAnimated
                        navigation.push(chat, context.layout == .single || forceAnimated, style: animated ? .push : ViewControllerStyle.none)
                    }
                }
            case let .forum(threadId):
                _ = ForumUI.openTopic(threadId, peerId: peerId, context: context, messageId: messageId).start()
            }
        case let .groupId(groupId):
            self.navigationController?.push(ChatListController(context, modal: false, mode: .folder(groupId)))
        case let .forum(peerId):
            ForumUI.open(peerId, context: context)
        case .reveal:
            break
        case .empty:
            break
        case .loading:
            break
        }
        if close {
            self.genericView.searchView.cancel(true)
        }
    }
    
    func longSelect(row: Int, item: TableRowItem) {
        
    }
    
    func selectionWillChange(row:Int, item:TableRowItem, byClick: Bool) -> Bool {
        return true
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
       
    }
    
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }

    private var effectiveTableView: TableView {
        switch genericView.searchView.state {
        case .Focus:
            return searchController?.genericView ?? genericView.tableView
        case .None:
            return genericView.tableView
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        
        if context.layout == .single && animated {
            context.globalPeerHandler.set(.single(nil))
        }
        
        context.window.set(handler: { [weak self] _ in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Escape, priority:.low)
        
        context.window.set(handler: { [weak self] _ in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Return, priority:.low)
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            if let item = self?.effectiveTableView.selectedItem(), item.index > 0 {
                self?.effectiveTableView.selectPrev()
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .medium, modifierFlags: [.option])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.effectiveTableView.selectNext()
            return .invoked
        }, with: self, for: .DownArrow, priority:.medium, modifierFlags: [.option])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.effectiveTableView.selectNext(turnDirection: false)
            return .invoked
        }, with: self, for: .Tab, priority: .modal, modifierFlags: [.control])
        
        context.window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.effectiveTableView.selectPrev(turnDirection: false)
            return .invoked
        }, with: self, for: .Tab, priority: .modal, modifierFlags: [.control, .shift])
        
    }
    

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        context.window.removeAllHandlers(for: self)

    }
    
    
}
