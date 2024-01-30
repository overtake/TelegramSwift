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
import InAppSettings

struct PeerListHiddenItems : Equatable {
    var archive: ItemHideStatus
    var generalTopic: ItemHideStatus?
    var promo: Set<PeerId>
    
    static var `default`: PeerListHiddenItems {
        return PeerListHiddenItems(archive: FastSettings.archiveStatus, generalTopic: nil, promo: Set())
    }
}


private final class Arguments {
    let context: AccountContext
    let joinGroupCall:(ChatActiveGroupCallInfo)->Void
    let joinGroup:(PeerId)->Void
    let openPendingRequests:()->Void
    let dismissPendingRequests:([PeerId])->Void
    let openStory:(StoryInitialIndex?, Bool, Bool)->Void
    let getStoryInterfaceState:()->StoryListChatListRowItem.InterfaceState
    let revealStoriesState:()->Void
    let setupFilter: (ChatListFilter)->Void
    let openFilterSettings: (ChatListFilter)->Void
    let tabsMenuItems: (ChatListFilter, Int?, Bool?)->[ContextMenuItem]
    let getController:()->ViewController?
    let navigationBarLeftPosition:()->CGFloat
    let contextMenu:()->ContextMenu
    init(context: AccountContext, joinGroupCall:@escaping(ChatActiveGroupCallInfo)->Void, joinGroup:@escaping(PeerId)->Void, openPendingRequests:@escaping()->Void, dismissPendingRequests: @escaping([PeerId])->Void, openStory:@escaping(StoryInitialIndex?, Bool, Bool)->Void, getStoryInterfaceState:@escaping()->StoryListChatListRowItem.InterfaceState, revealStoriesState:@escaping()->Void, setupFilter: @escaping(ChatListFilter)->Void, openFilterSettings: @escaping(ChatListFilter)->Void, tabsMenuItems: @escaping(ChatListFilter, Int?, Bool?)->[ContextMenuItem], getController:@escaping()->ViewController?, navigationBarLeftPosition:@escaping()->CGFloat, contextMenu: @escaping()->ContextMenu) {
        self.context = context
        self.joinGroupCall = joinGroupCall
        self.joinGroup = joinGroup
        self.openPendingRequests = openPendingRequests
        self.dismissPendingRequests = dismissPendingRequests
        self.openStory = openStory
        self.getStoryInterfaceState = getStoryInterfaceState
        self.revealStoriesState = revealStoriesState
        self.setupFilter = setupFilter
        self.openFilterSettings = openFilterSettings
        self.tabsMenuItems = tabsMenuItems
        self.getController = getController
        self.navigationBarLeftPosition = navigationBarLeftPosition
        self.contextMenu = contextMenu
    }
}


struct PeerListState : Equatable {
    
    enum AppearMode : Equatable {
        case normal
        case short
    }
    
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
            if lhs.online != rhs.online {
                return false
            }
            return true
        }
        
        var peer: TelegramChannel
        var peerView: PeerView
        var online: Int32
    }
    
    var proxySettings: ProxySettings
    var connectionStatus: ConnectionStatus
    var splitState: SplitViewState
    var searchState: SearchFieldState = .None
    var peer: PeerEquatable?
    var forumPeer: ForumData?
    var mode: PeerListMode
    var activities: InputActivities
    
    var appear: AppearMode
    var controllerAppear: AppearMode
    var hiddenItems: PeerListHiddenItems
    var selectedForum: PeerId?
    var stories: EngineStorySubscriptions?
    var isContacts: Bool
    var filterData: FilterData
    var presentation: TelegramPresentationTheme
    var privacy: GlobalPrivacySettings?
    var displaySavedAsTopics: Bool
    var hasStories: Bool {
        if let stories = self.stories, !isContacts, !mode.isForumLike {
            if self.splitState == .minimisize {
                return false
            }
            if let accountItem = stories.accountItem, accountItem.storyCount > 0, mode.groupId != .archive {
                return true
            }
            if !stories.items.isEmpty {
                return true
            }
        }
        return false
    }
    
    static func initialize(_ isContacts: Bool) -> PeerListState {
        return .init(proxySettings: .defaultSettings, connectionStatus: .waitingForNetwork, splitState: .dual, searchState: .None, peer: nil, forumPeer: nil, mode: .plain, activities: .init(activities: [:]), appear: .normal, controllerAppear: .normal, hiddenItems: .default, selectedForum: nil, stories: nil, isContacts: isContacts, filterData: FilterData(), presentation: theme, privacy: nil, displaySavedAsTopics: false)

    }
}


private final class ProxyView : Control {
    fileprivate let button:ImageButton = ImageButton()
    private var connecting: ProgressIndicator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(button)
        button.userInteractionEnabled = false
        button.isEventLess = true
        self.scaleOnClick = true
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
        layer?.masksToBounds = false
    }
    
    private var peer: Peer?
    private weak var effectPanel: Window?
    
    func update(_ peer: Peer, context: AccountContext, animated: Bool) {
        
        
        var interactiveStatus: Reactions.InteractiveStatus? = nil
        if visibleRect != .zero, window != nil, let interactive = context.reactions.interactiveStatus, !context.isLite(.emoji_effects) {
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
        border = [.Top]
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

fileprivate final class TitleView : Control {
    
    enum Source {
        case contacts
        case forum
        case chats
        case archivedChats
        case savedMessages
        var text: String {
            switch self {
            case .contacts:
                return strings().peerListTitleContacts
            case .chats:
                return strings().peerListTitleChats
            case .archivedChats:
                return strings().peerListTitleArchive
            case .forum:
                return strings().peerListTitleForum
            case .savedMessages:
                return strings().peerListTitleSavedMessages
            }
        }
    }
    
    var openStatus:((Control)->Void)? = nil
    
    private let textView = TextView()
    private var premiumStatus: StatusView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        self.layer?.masksToBounds = false
    }
    
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
    }
        
    fileprivate func updateState(_ state: PeerListState, arguments: Arguments, maxWidth: CGFloat, animated: Bool) {
                
        let source: Source
        if state.mode.isSavedMessages {
            source = .savedMessages
        } else if state.isContacts {
            source = .contacts
        } else if state.mode.groupId == .archive {
            source = .archivedChats
        } else if state.mode.isForum {
            source = .forum
        } else {
            source = .chats
        }
        let text: String
        if state.mode.isForum {
            text = state.forumPeer?.peer.title ?? source.text
        } else {
            text = source.text
        }
        let layout = TextViewLayout(.initialize(string: text, color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1)
        layout.measure(width: maxWidth)
        textView.update(layout)
        
        let hasStatus = state.peer?.peer.isPremium ?? false && state.mode == .plain && source != .contacts

        if hasStatus, let peer = state.peer?.peer {
            
            let current: StatusView
            if let view = self.premiumStatus {
                current = view
            } else {
                current = StatusView(frame: CGRect(origin: NSMakePoint(textView.frame.width + 4, (frame.height - 20) / 2), size: NSMakeSize(20, 20)))
                self.premiumStatus = current
                self.addSubview(current)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
                current.set(handler: { [weak self] control in
                    self?.openStatus?(control)
                }, for: .Click)
                current.scaleOnClick = true
            }
            current.update(peer, context: arguments.context, animated: animated)
            
        } else if let view = self.premiumStatus {
            performSubviewRemoval(view, animated: animated)
            self.premiumStatus = nil
        }
    }
    
    var hasPremium: Bool {
        return premiumStatus != nil
    }
    
    var size: NSSize {
        var width: CGFloat = textView.frame.width
        if let premiumStatus = self.premiumStatus {
            width += premiumStatus.frame.width + 4
        }
        return NSMakeSize(width, 20)
    }
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(view: textView, frame: textView.centerFrameY(x: 0))
        if let premiumStatus = self.premiumStatus {
            transition.updateFrame(view: premiumStatus, frame: premiumStatus.centerFrameY(x: textView.frame.width + 4, addition: 1))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class TitleForumView : Control {
    private let title = TextView()
    private let status = TextView()
    private let settings = ImageButton()
    private var state: PeerListState?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(title)
        addSubview(status)
        addSubview(settings)
        
        title.userInteractionEnabled = false
        status.userInteractionEnabled = false
        title.isSelectable = false
        status.isSelectable = false
        
        settings.autohighlight = false
        settings.scaleOnClick = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ state: PeerListState, forumData: PeerListState.ForumData, arguments: Arguments) {
        self.state = state
        let size = self.frame.size
        let hasSidebar = state.filterData.sidebar && !state.filterData.isEmpty
        let text_w = size.width - 80 - 10 - 40

        
        let t_layout = TextViewLayout(.initialize(string: forumData.peer.displayTitle, color: theme.colors.text, font: .medium(.text)), maximumNumberOfLines: 1)
        t_layout.measure(width: text_w)
        
        let s_layout = TextViewLayout(.initialize(string: stringStatus(for: forumData.peerView, context: arguments.context).status.string, color: theme.colors.grayText, font: .normal(.text)), maximumNumberOfLines: 1)
        s_layout.measure(width: text_w)

        
        self.title.update(t_layout)
        self.status.update(s_layout)
        
        settings.set(image: theme.icons.chatActions, for: .Normal)
        settings.set(image: theme.icons.chatActionsActive, for: .Highlight)
        settings.sizeToFit(.zero, NSMakeSize(30, 30), thatFit: true)
        
        settings.contextMenu = { [weak arguments] in
            return arguments?.contextMenu()
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let state = self.state else {
            return
        }
        let text_w = frame.size.width - 80 - 10 - 40

        title.resize(text_w)
        status.resize(text_w)

        self.updateLayout(size: self.frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
        guard let state = self.state else {
            return
        }
        let hasSidebar = state.filterData.sidebar && !state.filterData.isEmpty

        let minX = !hasSidebar ? Window.controlsInset + 15 : 0
        
        var title_r = title.centerFrameX(y: 10)
        title_r.origin.x = max(title_r.minX, minX)
        
        var status_r = status.centerFrameX(y: title_r.maxY + 1)
        status_r.origin.x = max(status_r.minX, minX)

        transition.updateFrame(view: title, frame: title_r)
        transition.updateFrame(view: status, frame: status_r)
        
        transition.updateFrame(view: settings, frame: settings.centerFrameY(x: size.width - 10 - settings.frame.width))
    }
}

class PeerListContainerView : Control {
    
    
    private var downloads: DownloadsControl?
    private var proxy: ProxyView?
    private var compose:ImageButton?
    private var backButton: ImageButton?

    private var forumTitle: TitleForumView?
    

    
    let backgroundView = View(frame: NSZeroRect)
    
    let tableView = TableView(frame:NSZeroRect, drawBorder: true)
    
    
    private let containerView = Control()
    private let statusContainer = Control()
    
    let searchView:SearchView = SearchView(frame:NSMakeRect(10, 0, 0, 0))
    
    fileprivate let titleView = TitleView(frame: .zero)
    
    
    fileprivate var showDownloads:(()->Void)? = nil
    fileprivate var hideDownloads:(()->Void)? = nil
    
    
    var searchViewRect: NSRect {
        var y = navigationHeight
        if let foldersItem = foldersItem {
            y -= foldersItem.height
        }
        return NSMakeRect(0, max(0, y), frame.width, frame.height - y)
    }

    var mode: PeerListMode = .plain
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    private let borderView = View()
    
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizesSubviews = false
        
        backgroundView.layer?.opacity = 0
        
        addSubview(backgroundView)
        addSubview(tableView)
        addSubview(containerView)
        
        
        statusContainer.handleScrollEventOnInteractionEnabled = true
        statusContainer.userInteractionEnabled = false
        statusContainer.isEventLess = true
        
        searchView.externalScroll = { [weak self] event in
            self?.tableView.scrollWheel(with: event)
        }
        
        statusContainer.addSubview(titleView)
        
        containerView.addSubview(statusContainer)
        
        containerView.addSubview(searchView)
        
        addSubview(borderView)
        
        tableView.getBackgroundColor = {
            .clear
        }
        
        titleView.scaleOnClick = true
        
       
        
        updateLocalizationAndTheme(theme: theme)
        
        
    }
    
    private var state: PeerListState?
    private var arguments: Arguments?
    
    private var storiesItem: StoryListChatListRowItem?
    private var storiesView: StoryListChatListRowView?
    
    private var foldersItem: ChatListRevealItem?
    private var foldersView: ChatListRevealView?
    

    
    var openProxy:((Control)->Void)? = nil
    var openCurrentProfile:((PeerId)->Void)? = nil
    var openStatus:((Control)->Void)? = nil {
        didSet {
            titleView.openStatus = { [weak self] control in
                self?.openStatus?(control)
            }
        }
    }

    fileprivate func updateState(_ state: PeerListState, arguments: Arguments, animated: Bool) {
        
        let previous = self.state
        
        let animated = animated && self.state?.splitState == state.splitState && self.state != nil
        self.state = state
        self.arguments = arguments
        
        
        self.mode = state.mode
        
        if let stories = state.stories, state.hasStories {
            self.storiesItem = .init(frame.size, stableId: 0, context: arguments.context, isArchive: state.mode.groupId == .archive, state: stories, open: arguments.openStory, getInterfaceState: arguments.getStoryInterfaceState, reveal: arguments.revealStoriesState)
        } else {
            self.storiesItem = nil
        }
        
        if !state.filterData.isEmpty && !state.filterData.sidebar, state.splitState != .minimisize, state.mode == .plain {
            self.foldersItem = .init(frame.size, context: arguments.context, tabs: state.filterData.tabs, selected: state.filterData.filter, counters: state.filterData.badges, action: arguments.setupFilter, openSettings: {
                arguments.openFilterSettings(.allChats)
            }, menuItems: arguments.tabsMenuItems, getCurrentStoriesState: { [weak self] in
                if let state = self?.arguments?.getStoryInterfaceState(), let tableView = self?.tableView {
                    return (state, tableView)
                }
                return nil
            })
        } else {
            self.foldersItem = nil
        }

        
        let hasCompose = (state.isContacts || state.mode.isSavedMessages || state.mode == .plain || (state.mode.groupId == .archive && state.splitState != .minimisize))
        
        if hasCompose {
            let current: ImageButton
            if let view = self.compose {
                current = view
            } else {
                current = ImageButton(frame: NSMakeRect(frame.width - 10 - 40, (statusHeight - 30)/2.0, 40, 30))
                current.layer?.cornerRadius = .cornerRadius
                self.compose = current
                current.autohighlight = false
                current.animates = false
                statusContainer.addSubview(current)
            }
            if state.isContacts {
                current.set(background: .clear, for: .Highlight)
                current.set(image: theme.icons.contactsNewContact, for: .Normal)
                current.set(image: theme.icons.contactsNewContact, for: .Hover)
                current.set(image: theme.icons.contactsNewContact, for: .Highlight)
            } else if state.mode.groupId == .archive || state.mode.isSavedMessages {
                current.set(background: .clear, for: .Highlight)
                current.set(image: theme.icons.chatActions, for: .Normal)
                current.set(image: theme.icons.chatActions, for: .Hover)
                current.set(image: theme.icons.chatActionsActive, for: .Highlight)
            } else {
                current.set(background: theme.colors.accent, for: .Highlight)
                current.set(image: theme.icons.composeNewChat, for: .Normal)
                current.set(image: theme.icons.composeNewChat, for: .Hover)
                current.set(image: theme.icons.composeNewChatActive, for: .Highlight)
            }
            current.contextMenu = { [weak arguments] in
                return arguments?.contextMenu()
            }
        } else if let view = self.compose {
            performSubviewRemoval(view, animated: animated)
            self.compose = nil
        }
        
        let hasForumTitle = state.splitState != .minimisize && (delta != nil || state.appear == .short)
        
        if hasForumTitle, let forumData = state.forumPeer {
            let current: TitleForumView
            if let view = self.forumTitle {
                 current = view
            } else {
                current = TitleForumView(frame: NSMakeRect(0, 0, frame.width, 50))
                self.forumTitle = current
                statusContainer.addSubview(current)
                
                current.set(handler: { [weak self] _ in
                    self?.openCurrentProfile?(forumData.peer.id)
                }, for: .Click)
            }
            current.update(state, forumData: forumData, arguments: arguments)
            
        } else if let view = self.forumTitle {
            performSubviewRemoval(view, animated: animated)
            self.forumTitle = nil
        }
        
        self.titleView.isHidden = (state.splitState == .minimisize) || !mode.isPlain
        
        let componentSize = NSMakeSize(40, 30)
        
        var controlPoint = NSMakePoint(frame.width - 10, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - componentSize.height)/2.0))
        
        if let compose = self.compose {
            controlPoint.x -= compose.frame.width
        }
        
        let hasControls = state.splitState != .minimisize && mode.isPlain && mode == .plain
        
        let hasProxy = (!state.proxySettings.servers.isEmpty || state.proxySettings.effectiveActiveServer != nil) && hasControls && !state.isContacts
        
        
        if hasProxy {
            controlPoint.x -= componentSize.width
            
            let current: ProxyView
            if let view = self.proxy {
                current = view
            } else {
                current = ProxyView(frame: CGRect(origin: controlPoint, size: componentSize))
                self.proxy = current
                self.statusContainer.addSubview(current, positioned: .below, relativeTo: nil)
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
        
       
        if let item = self.storiesItem {
            let current: StoryListChatListRowView
            if let view = self.storiesView {
                current = view
            } else {
                current = StoryListChatListRowView(frame: NSMakeRect(0, 50, frame.width, item.height))
                containerView.addSubview(current, positioned: .below, relativeTo: statusContainer)
                self.storiesView = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.set(item: item, animated: animated)
        } else if let view = self.storiesView {
            performSubviewRemoval(view, animated: animated)
            self.storiesView = nil
        }
        
        if let item = self.foldersItem {
            let current: ChatListRevealView
            if let view = self.foldersView {
                current = view
            } else {
                current = ChatListRevealView(frame: NSMakeRect(0, navigationHeight - item.height, frame.width, item.height))
                containerView.addSubview(current, positioned: .below, relativeTo: statusContainer)
                self.foldersView = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.set(item: item, animated: animated)
        } else if let view = self.foldersView {
            performSubviewRemoval(view, animated: animated)
            self.foldersView = nil
        }
        
        if state.mode.groupId == .archive || (state.selectedForum != nil && state.splitState != .minimisize) || state.mode.isForumLike  || state.appear == .short {
            let current: ImageButton
            if let view = self.backButton {
                current = view
            } else {
                current = ImageButton(frame: NSMakeRect(10, 10, 40, 30))
                self.backButton = current
                current.animates = false
                self.backButton?.set(handler: { [weak arguments, weak self] _ in
                    arguments?.getController()?.navigationController?.back()
                    self?.searchView.cancel(true)
                }, for: .Click)
                containerView.addSubview(current, positioned: .below, relativeTo: searchView)
            }
            
            if state.splitState == .minimisize {
                current.set(image: theme.icons.instantViewBack, for: .Normal)
            } else {
                current.set(image: theme.icons.chatNavigationBack, for: .Normal)
            }
            current.sizeToFit(.zero, NSMakeSize(40, 30), thatFit: true)
        } else if let view = self.backButton {
            performSubviewRemoval(view, animated: animated)
            self.backButton = nil
        }
        
        
        
        if previous?.appear != state.appear {
            self.delta = nil
        } else if previous?.splitState != state.splitState {
            self.delta = nil
        }

        
        let transition: ContainedViewLayoutTransition
        if animated, previous?.splitState == state.splitState {
            if previous?.appear != state.appear {
                transition = .animated(duration: 0.4, curve: .spring)
            } else {
                transition = .animated(duration: 0.2, curve: .easeOut)
            }
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

                    if state.forumPeer == nil, !state.mode.isForumLike {
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
        

        borderView.backgroundColor = theme.colors.border
                
        self.backgroundColor = theme.colors.background
        self.backgroundView.backgroundColor = theme.colors.listBackground
                
        searchView.searchTheme = .init(theme.search.backgroundColor, theme.search.searchImage, theme.search.clearImage, {
            return strings().chatListSearchPlaceholder
        }, theme.search.textColor, theme.search.placeholderColor)
        
        self.containerView.backgroundColor = theme.colors.background
        
        
        super.updateLocalizationAndTheme(theme: theme)
        
        updateLayout(self.frame.size, transition: .immediate)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        self.updateLayout(frame.size, transition: .immediate)
    }
    
    private(set) var delta: CGFloat? = nil
    
    func updateSwipingState(_ state: SwipeState, controller: ViewController) -> Void {
        let transition: ContainedViewLayoutTransition
        switch state {
        case let .swiping(delta, _):
            if controller.stake.keepLeft > 0 {
                self.delta = max(0, min(delta, frame.width - controller.stake.keepLeft))
            } else {
                self.delta = nil
            }
            transition = .immediate
        case .success:
            if controller.stake.keepLeft > 0 {
                self.delta = frame.width - controller.stake.keepLeft
            } else {
                self.delta = nil
            }
            transition = .animated(duration: 0.2, curve: .easeOut)
        case .failed:
            if controller.stake.keepLeft > 0 {
                self.delta = 0
            } else {
                self.delta = nil
            }
            transition = .animated(duration: 0.2, curve: .easeOut)
        case .start:
            if controller.stake.keepLeft > 0 {
                self.delta = 0
            } else {
                self.delta = nil
            }
            transition = .immediate
        }
        if let arguments = arguments, let state = self.state {
            self.updateState(state, arguments: arguments, animated: transition.isAnimated)
        }

        self.updateLayout(frame.size, transition: transition)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        
        guard let state = self.state, let arguments = self.arguments else {
            return
        }
        
        var maxTitleWidth: CGFloat = max(size.width, 300) - 60
        if let compose = self.compose {
            maxTitleWidth -= compose.frame.width
        }
        if let proxy = self.proxy {
            maxTitleWidth -= proxy.frame.width
        }
        
        self.titleView.updateState(state, arguments: arguments, maxWidth: maxTitleWidth, animated: transition.isAnimated)
        
        var offset: CGFloat = navigationHeight
        
        let progress: CGFloat = getDeltaProgress() ?? (state.appear == .short ? 0.0 : 1.0)
        
        var inset: CGFloat = 0
        
        let containerSize = NSMakeSize(state.splitState == .minimisize ? 70 : size.width, offset)
                
        transition.updateFrame(view: self.containerView, frame: NSMakeRect(0, inset, containerSize.width, offset))
        
        
        transition.updateFrame(view: self.statusContainer, frame: NSMakeRect(0, 0, containerSize.width, statusHeight))
        
        inset = self.statusContainer.frame.maxY


        transition.updateFrame(view: self.backgroundView, frame: size.bounds)
        
        transition.updateFrame(view: self.borderView, frame: CGRect(origin: CGPoint.init(x: 0, y: navigationHeight - .borderSize), size: CGSize(width: size.width, height: .borderSize)))
        transition.updateAlpha(view: borderView, alpha: state.searchState == .Focus ? 0 : 1)


        
        let statusHeight: CGFloat = self.statusHeight


        let componentSize = NSMakeSize(40, 30)
                        
        
        var searchY: CGFloat = statusHeight
        
        if let storiesItem = storiesItem {
            searchY += (StoryListChatListRowItem.InterfaceState.revealed.height * storiesItem.progress) + 9 * storiesItem.progress
        }


        let searchRect = NSMakeRect(10, searchY, (size.width - 10 * 2), componentSize.height)
        
        
        var bottomInset: CGFloat = 0
        
        transition.updateFrame(view: searchView, frame: searchRect)
        searchView.updateLayout(size: searchRect.size, transition: transition)
        


        transition.updateFrame(view: tableView, frame: NSMakeRect(0, 0, size.width, size.height - bottomInset))
        
        
        if let downloads = downloads {
            let rect = NSMakeRect(0, size.height - downloads.frame.height, size.width - .borderSize, downloads.frame.height)
            transition.updateFrame(view: downloads, frame: rect)
        }
        
        var controlPoint = NSMakePoint(containerSize.width - 14, floorToScreenPixels(backingScaleFactor, (statusHeight - componentSize.height)/2.0))

        controlPoint.x -= componentSize.width
        
        if let compose = compose {
            transition.updateFrame(view: compose, frame: CGRect(origin: controlPoint, size: componentSize))
            if state.splitState == .minimisize {
                transition.updateAlpha(view: compose, alpha: 1)
            } else {
                transition.updateAlpha(view: compose, alpha: progress)
            }
        }
        
        if let view = forumTitle {
            transition.updateFrame(view: view, frame: CGRect(origin: .zero, size: NSMakeSize(size.width, 50)))
            transition.updateAlpha(view: view, alpha: 1 - progress)
        }
        
        if let view = proxy {
            controlPoint.x -= componentSize.width
            transition.updateFrame(view: view, frame: CGRect(origin: controlPoint, size: componentSize))
            transition.updateAlpha(view: view, alpha: progress)
        }
        
        if let view = self.backButton {
            if state.splitState == .minimisize {
                transition.updateFrame(view: view, frame: view.centerFrameX(y: 10))
                transition.updateAlpha(view: view, alpha: 1)
            } else {
                let rect = NSMakeRect(10, 10, 40, searchRect.height)
                transition.updateFrame(view: view, frame: rect)
                if state.mode.groupId == .archive || state.mode.isSavedMessages {
                    transition.updateAlpha(view: view, alpha: 1)
                } else {
                    transition.updateAlpha(view: view, alpha: 1 - progress)
                }
            }
            
        }
        

        let titlePlusStorySize = titleView.frame.width + (59)
        var titlePlusStoryStartX = (size.width - titlePlusStorySize) / 2
        titlePlusStoryStartX = max(arguments.navigationBarLeftPosition() + 20, titlePlusStoryStartX)

//        if let back = backButton {
//        }
        
        let storyXStart = titlePlusStoryStartX - 10
        let titleXStart = titlePlusStoryStartX + (59)
        
        let storyXEnd: CGFloat = 0
        let titleXEnd = (size.width - titleView.size.width) / 2
        
        
        
        var titleX: CGFloat = titleXEnd
        var storyX: CGFloat = storyXEnd
        
        if let stories = self.storiesItem {
            titleX = titleXEnd - (titleXEnd - titleXStart) * (1 - stories.progress)
            storyX = storyXEnd + (storyXStart - storyXEnd) * (1 - stories.progress)
        }


        transition.updateFrame(view: titleView, frame: CGRect(origin: CGPoint(x: titleX, y: floorToScreenPixels(bsc, (statusHeight - titleView.size.height) / 2) - 2), size: titleView.size))
        titleView.updateLayout(size: titleView.size, transition: transition)
        transition.updateAlpha(view: titleView, alpha: progress)

        if let storiesItem = storiesItem, let view = storiesView {
            let size = NSMakeSize(size.width, storiesItem.height)
                        
            var rect = CGRect(origin: NSMakePoint(storyX, 10 + storiesItem.getInterfaceState().progress * 40), size: size)
                        
            if storiesItem.itemsCount < 3 {
                rect.origin.x += (1 - storiesItem.getInterfaceState().progress) * (StoryListChatListRowItem.smallSize.width / 2 * CGFloat(3 - storiesItem.itemsCount))
            }
            transition.updateFrame(view: view, frame: rect)
            view.set(item: storiesItem, animated: transition.isAnimated)
            view.updateLayout(size: size, transition: transition)
            transition.updateAlpha(view: view, alpha: progress)
        }
        
        if let foldersItem = foldersItem, let view = foldersView {
            let controlSize = NSMakeSize(size.width, foldersItem.height)
            
            let rect = CGRect(origin: NSMakePoint(0, navigationHeight - controlSize.height), size: controlSize)
                        
            transition.updateFrame(view: view, frame: rect)
            view.set(item: foldersItem, animated: transition.isAnimated)
            
            view.updateLayout(size: size, transition: transition)
        }
        transition.updateAlpha(view: self.backgroundView, alpha: 1 - progress)

        self.updateScrollerInset(animated: transition.isAnimated)

    }
    
    func getDeltaProgress() -> CGFloat? {
        let progress: CGFloat?
        if let delta = self.delta {
            progress = delta / (frame.width - 70)
        } else {
            if let state = self.state, state.appear == .short {
                progress = 0.0
            } else {
                progress = nil
            }
        }
        return progress
    }
    
    var navigationHeight: CGFloat {
        guard let state = self.state else {
            return 50
        }
        
        if case .forum = state.mode, state.splitState != .minimisize {
            return 0
        }
        var offset: CGFloat = 50
        
        
        
        if state.splitState != .minimisize, state.mode.isPlain {

            offset += 40

            if let storiesItem = self.storiesItem {
                offset += storiesItem.navigationHeight
            }
            if let foldersItem = self.foldersItem {
                offset += foldersItem.height
            }
        } else if state.splitState == .minimisize {
//            if !state.filterData.sidebar {
//                offset += 20
//            }
        }
        return offset
    }
    var statusHeight: CGFloat {
        guard let state = self.state else {
            return 0
        }
        if !state.mode.isPlain {
            return 10
        }
        var height: CGFloat = 50
        
//        if state.splitState == .minimisize {
//            if !state.filterData.sidebar {
//                height += 40
//            }
//        }
        return height
    }
    
    func updateScrollerInset(animated: Bool) {
        var top: CGFloat = 0
        self.tableView.enumerateItems(with: { item in
            if let item = item as? ChatListSpaceItem {
                top += item.height
                item.redraw(animated: animated)
            }
            return true
        })
        tableView.scrollerInsets = .init(left: 0, right: 0, top: top, bottom: 0)
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
    
    func pushExtraController(_ controller: ViewController) {
        
    }
    
}


enum PeerListMode : Equatable {
    case plain
    case folder(EngineChatList.Group)
    case filter(Int32)
    case forum(PeerId, Bool, Bool)
    case savedMessagesChats
    
    var isForumLike: Bool {
        switch self {
        case .forum, .savedMessagesChats:
            return true
        default:
            return false
        }
    }
    
    var isPlain:Bool {
        switch self {
        case .plain:
            return true
        case .forum:
            return true
        case .savedMessagesChats:
            return true
        default:
            if self.groupId == .archive {
                return true
            } else {
                return false
            }
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
    var isSavedMessages: Bool {
        switch self {
        case .savedMessagesChats:
            return true
        default:
            return false
        }
    }
    var isForum: Bool {
        switch self {
        case .forum:
            return true
        default:
            return false
        }
    }
    var location: ChatListControllerLocation {
        switch self {
        case .plain:
            return .chatList(groupId: .root)
        case let .folder(group):
            return .chatList(groupId: group._asGroup())
        case let .forum(peerId, _, _):
            return .forum(peerId: peerId)
        case let .filter(filterId):
            return .chatList(groupId: .group(filterId))
        case .savedMessagesChats:
            return .savedMessagesChats
        }
    }
}


class PeersListController: TelegramGenericViewController<PeerListContainerView>, TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    let stateValue: Atomic<PeerListState>
    private let stateSignal: ValuePromise<PeerListState>
    var stateUpdater: Signal<PeerListState, NoError> {
        return stateSignal.get()
    }
    

    var filterSignal : Signal<FilterData, NoError> {
        return self.stateSignal.get() |> map { $0.filterData }
    }
    var filterValue: FilterData {
        return self.stateValue.with { $0.filterData }
    }

    private let forumPeerData: Promise<PeerListState.ForumData?> = Promise(nil)
    let storyList: Signal<EngineStorySubscriptions, NoError>?

    
    private let progressDisposable = MetaDisposable()
    private let createSecretChatDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let followGlobal:Bool
    private let searchOptions: AppSearchOptions
    
    private var downloadsController: ViewController?
    
    
    private var tempImportersContext: PeerInvitationImportersContext? = nil
    

    private let appearMode: ValuePromise<PeerListState.AppearMode> = ValuePromise(.normal, ignoreRepeated: true)
    private let controllerAppear: ValuePromise<PeerListState.AppearMode> = ValuePromise(.normal, ignoreRepeated: true)
    
    let mode:PeerListMode
    private(set) var searchController:SearchController? {
        didSet {
            if let controller = searchController {
                genericView.customHandler.size = { [weak controller, weak self] size in
                    let frame = self?.genericView.searchViewRect ?? size.bounds
                    controller?.view.frame = frame
                }
                progressDisposable.set((controller.isLoading.get() |> deliverOnMainQueue).start(next: { [weak self] isLoading in
                    self?.genericView.searchView.isLoading = isLoading
                }))
            }
        }
    }
    
    func updateState(_ f:(PeerListState)->PeerListState) -> Void {
        self.stateSignal.set(self.stateValue.modify(f))
    }
        
    func updateHiddenItemsState(_ f:(PeerListHiddenItems)->PeerListHiddenItems) {
        
    
        updateState { current in
            var current = current
            current.hiddenItems = f(current.hiddenItems)
            return current
        }
        
        let value = self.stateValue.with { $0.hiddenItems.archive }
        FastSettings.archiveStatus = value

    }
    
    let topics: ForumChannelTopics?
    let isContacts: Bool
    var revealListener: TableScrollListener!

    
    init(_ context: AccountContext, isContacts: Bool = false, followGlobal:Bool = true, mode: PeerListMode = .plain, searchOptions: AppSearchOptions = [.chats, .messages]) {
        self.followGlobal = followGlobal
        self.mode = mode
        self.stateValue = Atomic(value: .initialize(isContacts))
        self.stateSignal = ValuePromise(.initialize(isContacts), ignoreRepeated: true)

        self.isContacts = isContacts
        self.searchOptions = searchOptions
        switch mode {
        case let .forum(peerId, _, _):
            self.topics = ForumChannelTopics(account: context.account, peerId: peerId)
        default:
            self.topics = nil
        }
        if mode.isPlain {
            self.storyList = context.engine.messages.storySubscriptions(isHidden: isContacts || mode.groupId == .archive)
        } else {
            self.storyList = nil
        }
        super.init(context)
        
        
        self.bar = .init(height: 0)

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
        let context = self.context
        if let controller = self.searchController {
            let ready = controller.ready.get()
            |> filter { $0 }
            |> take(1)
            
            _ = ready.start(next: { [weak self] _ in
                guard let `self` = self else {
                    return
                }
                let controller: ViewController
                if let current = self.downloadsController {
                    controller = current
                } else {
                    controller = DownloadsController(context: context, searchValue: self.genericView.searchView.searchValue |> map { $0.request })
                    self.downloadsController = controller
                    
                    controller.frame = self.genericView.searchViewRect
                    self.navigationController?.addSubview(controller.view)
                    
                    if animated {
                        controller.view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        controller.view.layer?.animateScaleSpring(from: 1.1, to: 1, duration: 0.2)
                    }
                }
                self.genericView.searchView.updateTags([strings().chatListDownloadsTag], theme.icons.search_filter_downloads)
            })
        }
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
        let isContacts = self.isContacts
        
        
        
        switch mode {
        case .savedMessagesChats:
            let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.DisplaySavedChatsAsTopics()) |> deliverOnMainQueue
            actionsDisposable.add(signal.startStrict(next: { [weak self] value in
                self?.updateState { current in
                    var current = current
                    current.displaySavedAsTopics = value
                    return current
                }
            }))
        default:
            break
        }
                
        genericView.tableView._scrollDidEndLiveScrolling = { [weak self] in
            _ = self?.finishOverscroll()
        }
        
        revealListener = .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] _ in
            self?.processScroll()
        })
        
        genericView.tableView.applyExternalScroll = { [weak self] event in
            return self?.processScroll(event) ?? false
        }

        genericView.tableView.addScroll(listener: revealListener)
        
        genericView.showDownloads = { [weak self] in
            self?.showDownloads(animated: true)
        }
        genericView.hideDownloads = { [weak self] in
            self?.hideDownloads(animated: true)
        }
        
        genericView.titleView.set(handler: { [weak self] _ in
            self?.toggleStoriesState()
        }, for: .Click)
        
        
        let actionsDisposable = self.actionsDisposable
        
        actionsDisposable.add((context.cancelGlobalSearch.get() |> deliverOnMainQueue).start(next: { [weak self] animated in
            self?.genericView.searchView.cancel(animated)
        }))
        
        genericView.mode = mode
        
        if followGlobal {
            let combined = combineLatest(queue: .mainQueue(), context.globalPeerHandler.get(), context.globalForumId.get())
            
            actionsDisposable.add(combined.start(next: { [weak self] location, forumId in
                guard let `self` = self else {return}
                self.changeSelection(location, globalForumId: forumId)
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
       
        let updateState:((PeerListState)->PeerListState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        

        let layoutSignal = context.layoutValue
        
        let proxy = proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { ps -> Signal<(ProxySettings, ConnectionStatus), NoError> in
            return context.account.network.connectionStatus |> map { status -> (ProxySettings, ConnectionStatus) in
                return (ps, status)
            }
        }
        
        let peer: Signal<PeerEquatable?, NoError> = getPeerView(peerId: context.peerId, postbox: context.account.postbox) |> map { peer in
            if let peer = peer {
                return PeerEquatable(peer)
            } else {
                return nil
            }
        }
        let forumPeer: Signal<PeerListState.ForumData?, NoError> = self.forumPeerData.get()
        
        
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
        
        let isFull: Bool
        switch mode {
        case let .forum(_, value, _):
            isFull = value
        default:
            isFull = true
        }
                
        let storyList = self.storyList
        let storyState: Signal<EngineStorySubscriptions?, NoError>
        if let storyList = storyList {
            storyState = storyList |> map(Optional.init)
        } else {
            storyState = .single(nil)
        }
        
        let privacy: Promise<GlobalPrivacySettings?> = Promise(nil)
       
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), proxy, layoutSignal, peer, forumPeer, inputActivities, storyState, appearMode.get(), privacy.get(), appearanceSignal).start(next: { pref, layout, peer, forumPeer, inputActivities, storyState, appearMode, privacy, appearance in
            updateState { value in
                var current: PeerListState = value
                current.proxySettings = pref.0
                current.connectionStatus = pref.1
                current.splitState = layout
                current.controllerAppear = isFull ? .normal : .short
                current.peer = peer
                current.forumPeer = forumPeer
                current.mode = mode
                current.activities = inputActivities
                current.stories = storyState
                current.appear = layout == .minimisize ? .normal : appearMode
                current.isContacts = isContacts
                current.presentation = appearance.presentation
                current.privacy = privacy
                return current
            }
        }))
        
        if self.mode.groupId == .archive {
            privacy.set(context.engine.privacy.requestAccountPrivacySettings() |> map { $0.globalSettings } |> map(Optional.init))
        }
        
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
        
        genericView.openCurrentProfile = { peerId in
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)

        }
        
        genericView.openStatus = { control in
            let peer = stateValue.with { $0.peer?.peer }
            if let peer = peer as? TelegramUser {
                let callback:(TelegramMediaFile, Int32?, CGRect?)->Void = { file, timeout, fromRect in
                    context.reactions.setStatus(file, peer: peer, timestamp: context.timestamp, timeout: timeout, fromRect: fromRect)
                }
                if control.popover == nil {
                    showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
                }
            }
        }


        genericView.searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            updateState { current in
                var current = current
                current.searchState = state.state
                return current
            }
            switch state.state {
            case .Focus:
                assert(self?.searchController == nil)
                self?.showSearchController(animated: animated)
                
            case .None:
                self?.hideSearchController(animated: animated)
            }
        }, { [weak self] state in
            updateState { current in
                var current = current
                current.searchState = state.state
                return current
            }
            self?.searchController?.request(with: state.request)
        }, responderModified: { [weak self] state in
            self?.context.isInGlobalSearch = state.responder
        })
        
        let stateSignal = state.get()
        
        let previousState: Atomic<PeerListState?> = Atomic(value: nil)
        
        
        let arguments = Arguments(context: context, joinGroupCall: { info in
            if case let .forum(peerId, _, _) = mode {
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
        }, openPendingRequests: { [weak self] in
            if let importersContext = self?.tempImportersContext, case let .forum(peerId, _, _) = mode {
                let navigation = context.bindings.rootNavigation()
                navigation.push(RequestJoinMemberListController(context: context, peerId: peerId, manager: importersContext, openInviteLinks: { [weak navigation] in
                    navigation?.push(InviteLinksController(context: context, peerId: peerId, manager: nil))
                }))
            }
        }, dismissPendingRequests: { peerIds in
            if case let .forum(peerId, _, _) = mode {
                FastSettings.dismissPendingRequests(peerIds, for: peerId)
            }
        }, openStory: { initialId, singlePeer, isHidden in
            StoryModalController.ShowStories(context: context, isHidden: isHidden, initialId: initialId, singlePeer: singlePeer)
        }, getStoryInterfaceState: { [weak self] in
            guard let `self` = self else {
                return .empty
            }
            if self.state?.splitState == .minimisize {
                return .empty
            }
            if self.state?.hasStories == true {
                return self.storyInterfaceState
            }
            return .empty
        }, revealStoriesState: { [weak self] in
            self?.revealStoriesState()
        }, setupFilter: { [weak self] filter in
            self?.navigationController?.back()
            self?.updateState { current in
                var current = current
                current.filterData = current.filterData.withUpdatedFilter(filter)
                return current
            }
            self?.scrollup(force: true)
        }, openFilterSettings: { filter in
            if case .filter = filter {
                context.bindings.rootNavigation().push(ChatListFilterController(context: context, filter: filter))
            } else {
                context.bindings.rootNavigation().push(ChatListFiltersListController(context: context))
            }
        }, tabsMenuItems: { filter, unreadCount, allMuted in
            return filterContextMenuItems(filter, unreadCount: unreadCount, includeAllMuted: allMuted, context: context)
        }, getController: { [weak self] in
            return self
        }, navigationBarLeftPosition: { [weak self] in
            guard let state = self?.state else {
                return 0
            }
            if state.filterData.sidebar && !state.filterData.isEmpty {
                return 0
            } else {
                if case .forum = state.mode {
                    return 0
                } else {
                    if state.splitState != .minimisize {
                        return Window.controlsInset
                    } else {
                        return 0
                    }
                }
            }
        }, contextMenu: { [weak self] in
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
                        _ = context.engine.peers.updateForumViewAsMessages(peerId: peer.peer.id, value: true).start()
                    }, itemImage: MenuAnimation.menu_read.value))
                }
                if let cachedData = self?.state?.forumPeer?.peerView.cachedData as? CachedChannelData {
                    if case .thread = chatController?.chatInteraction.chatLocation {
                        
                    }
                }

                if peer.peer.hasPermission(.manageTopics) {
                    if topicController?.identifier != "ForumTopic" {
                        if !items.isEmpty {
                            items.append(ContextSeparatorItem())
                        }
                        items.append(ContextMenuItem(strings().forumTopicContextNew, handler: {
                            ForumUI.createTopic(peer.peer.id, context: context)
                        }, itemImage: MenuAnimation.menu_edit.value))
                    }
                }

                for item in items {
                    menu.addItem(item)
                }
            } else if isContacts {
                menu.addItem(ContextMenuItem(strings().newContactTitle, handler: {
                    showModal(with: AddContactModalController(context), for: context.window)
                }, itemImage: MenuAnimation.menu_add_member.value))
            } else if self?.state?.mode == .savedMessagesChats {
                
                let displayAsTopics = self?.state?.displaySavedAsTopics ?? false
                
                menu.addItem(ContextMenuItem(strings().chatSavedMessagesViewAsMessages, handler: {
                    context.engine.peers.updateSavedMessagesViewAsTopics(value: false)
                    self?.navigationController?.back()
                    context.bindings.rootNavigation().push(ChatController(context: context, chatLocation: .peer(context.peerId)))
                }, itemImage: !displayAsTopics ? MenuAnimation.menu_check_selected.value : nil))
                
                menu.addItem(ContextMenuItem(strings().chatSavedMessagesViewAsChats, handler: {
                    context.engine.peers.updateSavedMessagesViewAsTopics(value: true)
                    ForumUI.open(context.peerId, context: context)
                }, itemImage: displayAsTopics ? MenuAnimation.menu_check_selected.value : nil))
            } else if self?.state?.mode.groupId == .archive {
                menu.addItem(ContextMenuItem(strings().peerListArchiveSettings, handler: {
                    pushController(ArchiveSettingsController(context: context, privacy: self?.state?.privacy, update: { updated in
                        updateState { current in
                            var current = current
                            current.privacy = updated
                            return current
                        }
                    }))
                }, itemImage: MenuAnimation.menu_gear.value))
            } else {
                let items = [ContextMenuItem(strings().composePopoverNewGroup, handler: { [weak self] in
                    self?.context.composeCreateGroup()
                }, itemImage: MenuAnimation.menu_create_group.value),
                ContextMenuItem(strings().composePopoverNewSecretChat, handler: { [weak self] in
                    self?.context.composeCreateSecretChat()
                }, itemImage: MenuAnimation.menu_lock.value),
                ContextMenuItem(strings().composePopoverNewChannel, handler: { [weak self] in
                    self?.context.composeCreateChannel()
                }, itemImage: MenuAnimation.menu_channel.value)];

                for item in items {
                    menu.addItem(item)
                }
            }
            return menu
        })
        
        self.takeArguments = { [weak arguments] in
            return arguments
        }
        
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            CATransaction.begin()
            self?.updateState(state, previous: previousState.swap(state), arguments: arguments)
            CATransaction.commit()
        }))
        
        centerBarView.set(handler: { _ in
            switch mode {
            case let .forum(peerId, _, _):
                ForumUI.openInfo(peerId, context: context)
            default:
                break
            }
        }, for: .Click)
    }
    
    var state: PeerListState? {
        return self.stateValue.with { $0 }
    }
    
    private func updateState(_ state: PeerListState, previous: PeerListState?, arguments: Arguments) {
        if previous?.forumPeer != state.forumPeer {
            if state.forumPeer == nil {
                switch self.mode {
                case .forum:
                    self.navigationController?.back()
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
                        

            genericView.updateLayout(frame.size, transition: .immediate)
        }
                      
        let animated = state.splitState == previous?.splitState && !context.window.inLiveResize
        
        self.genericView.searchStateChanged(state, arguments: arguments, animated: animated, updateSearchTags: { [weak self] tags in
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
        
        if previous?.splitState != state.splitState {
            DispatchQueue.main.async {
                self.genericView.tableView.reloadData()
            }
        }
    }
        
    private var takeArguments:()->Arguments? = {
        return nil
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
    
    
    
    private var previousLocation: (ChatLocation?, PeerId?) = (nil, nil)
    func changeSelection(_ location: ChatLocation?, globalForumId: PeerId?) {
        if previousLocation.0 != location {
            if let location = location {
                var id: UIChatListEntryId
                switch location {
                case .peer:
                    switch self.mode {
                    case .savedMessagesChats:
                        id = .empty
                    default:
                        id = .chatId(.chatList(location.peerId), location.peerId, -1)
                    }
                case let .thread(data):
                    let threadId = data.threadId
                    
                    switch self.mode {
                    case .plain, .filter, .folder:
                        id = .forum(location.peerId)
                    case .forum:
                        id = .chatId(.forum(threadId), location.peerId, -1)
                    case .savedMessagesChats:
                        id = .chatId(.chatList(PeerId(data.threadId)), PeerId(data.threadId), -1)
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
        self.previousLocation = (location, globalForumId)
        if globalForumId != nil || location?.threadId != nil {
            self.updateHighlight(globalForumId ?? location?.peerId)
        } else {
            self.updateHighlight(nil)
        }
    }
    
    private func showSearchController(animated: Bool) {
      
        
        if searchController == nil {
            
            self.completeUndefiedStates(animated: true)

            let initialTags: SearchTags
            let target: SearchController.Target
            if let peerId = self.state?.forumPeer?.peer.id, self.state?.appear == .short {
                initialTags = .init(messageTags: nil, peerTag: nil)
                target = .forum(peerId)
            } else if mode == .savedMessagesChats {
                initialTags = .init(messageTags: nil, peerTag: nil)
                target = .savedMessages
            } else {
                initialTags = .init(messageTags: nil, peerTag: nil)
                target = .common(.root)
            }

            let rect = self.genericView.searchViewRect
            let searchController = SearchController(context: self.context, open: { [weak self] (id, messageId, close) in
                if let id = id {
                    self?.open(with: id, messageId: messageId, close: close)
                } else {
                    self?.genericView.searchView.cancel(true)
                }
            }, options: self.searchOptions, frame: rect, target: target, tags: initialTags)
            
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
                        self?.completeUndefiedStates(animated: false)
                        searchController.viewDidAppear(animated)
                    }
                    self?.navigationController?.addSubview(searchController.view)
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
            
            let animated = animated && searchController.didSetReady && !searchController.view.isHidden
            
            searchController.viewWillDisappear(animated)
            searchController.view.layer?.opacity = animated ? 1.0 : 0.0
        
            searchController.viewDidDisappear(true)
            self.searchController = nil
            self.genericView.tableView.isHidden = false
            self.genericView.tableView.change(opacity: 1, animated: animated)
            let view = searchController.view
        
            searchController.view._change(opacity: 0, animated: animated, duration: 0.25, timingFunction: .spring, completion: { [weak view] completed in
                view?.removeFromSuperview()
            })
            if animated {
                searchController.view.layer?.animateScaleSpring(from: 1.0, to: 1.05, duration: 0.4, removeOnCompletion: false, bounce: false)
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
    
    func open(with entryId: UIChatListEntryId, messageId:MessageId? = nil, initialAction: ChatInitialAction? = nil, close:Bool = true, addition: Bool = false, forceAnimated: Bool = false, threadId: Int64? = nil, openAsTopics: Bool = false) ->Void {
        
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
                
                if openAsTopics {
                    ForumUI.open(peerId, context: context, threadId: threadId)
                } else {
                    if let modalAction = navigation.modalAction as? FWDNavigationAction, peerId == context.peerId {
                        _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId, replyId: nil).start()
                        _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                        modalAction.afterInvoke()
                        navigation.removeModalAction()
                    } else {
                        if mode.isSavedMessages {
                            _ = ForumUI.openSavedMessages(peerId.toInt64(), context: context, messageId: messageId, initialAction: initialAction).start()
                        } else {
                            if let current = navigation.controller as? ChatController, peerId == current.chatInteraction.peerId, let messageId = messageId, current.mode == .history {
                                current.chatInteraction.focusMessageId(nil, .init(messageId: messageId, string: nil), .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
                            } else {
                                let chatLocation: ChatLocation = .peer(peerId)
                                let chat: ChatController
                                if addition {
                                    chat = ChatAdditionController(context: context, chatLocation: chatLocation, focusTarget: .init(messageId: messageId))
                                } else {
                                    chat = ChatController(context: self.context, chatLocation: chatLocation, focusTarget: .init(messageId: messageId), initialAction: initialAction)
                                }
                                let animated = context.layout == .single || forceAnimated
                                navigation.push(chat, context.layout == .single || forceAnimated, style: animated ? .push : ViewControllerStyle.none)
                            }
                        }
                    }
                }
                
                if self.navigationController?.controller !== self {
                    switch entryId {
                    case let .chatId(_, pid, _):
                        self.navigationController?.back()
                    default:
                        break
                    }
                }
                
            case let .forum(threadId):
                _ = ForumUI.openTopic(threadId, peerId: peerId, context: context, messageId: messageId).start()
            }
        case let .groupId(groupId):
            self.navigationController?.push(ChatListController(context, modal: false, mode: .folder(groupId)))
        case let .forum(peerId):
            let current = navigationController?.controller as? ChatListController
            if case .forum(peerId, _, _) = current?.mode {
                navigationController?.back()
            } else {
                ForumUI.open(peerId, context: context, threadId: threadId)
            }
        case .systemDeprecated, .sharedFolderUpdated, .reveal, .empty, .loading, .space, .suspicious, .savedMessageIndex:
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
    
    func updateScrollerInset(animated: Bool) {
        self.genericView.updateScrollerInset(animated: animated)
    }
    
    
    func afterTransaction(_ transition: TableUpdateTransition) {
        self.updateScrollerInset(animated: transition.animated)
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
    
    override func setToNextController(_ controller: ViewController, style: ViewControllerStyle) {
        switch style {
        case .push:
            swipeState = nil
            self.completeUndefiedStates(animated: style != .none)
            if controller.stake.isCustom {
                appearMode.set(.short)
            } else {
                appearMode.set(.normal)
            }
            
            if let controller = controller as? PeersListController {
                if case let .forum(peerId, _, _) = controller.mode {
                    self.updateHighlight(peerId)
                } else {
                    self.updateHighlight(context.globalLocationId?.peerId)
                }
            } else {
                self.updateHighlight(context.globalLocationId?.peerId)
            }
        default:
            break
        }
    }
    
    
    override func setToPreviousController(_ controller: ViewController, style: ViewControllerStyle) {
        switch style {
        case .pop:
            self.swipeState = nil
            self.appearMode.set(.normal)
            self.updateHighlight(context.globalLocationId?.peerId)
            genericView.backgroundView.change(opacity: 0, animated: true)
        default:
            break
        }
    }
    
    private func updateHighlight(_ peerId: PeerId?) -> Void {
        switch self.mode {
        case .forum, .savedMessagesChats:
            break
        default:
            self.updateState { current in
                var current = current
                current.selectedForum = peerId
                return current
            }
            let context = self.context
            let forumPeer: Signal<PeerListState.ForumData?, NoError>
            if let peerId = peerId {
                forumPeer = context.account.postbox.peerView(id: peerId) |> mapToSignal { view in
                    if let peer = peerViewMainPeer(view) as? TelegramChannel, peer.isForum {
                        return .single(.init(peer: peer, peerView: view, online: 0))
                    } else {
                        return .single(nil)
                    }
                }
            } else {
                forumPeer = .single(nil)
            }
            self.forumPeerData.set(forumPeer)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        context.window.removeAllHandlers(for: self)
        switch mode {
        case .forum:
            context.globalForumId.set(nil)
        case .savedMessagesChats:
            context.globalForumId.set(nil)
        default:
            break
        }
        self.searchController?.view._change(opacity: 0, animated: true, completion: { [weak self] completed in
            if completed {
                self?.searchController?.view.isHidden = true
            }
        })
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch mode {
        case let .forum(peerId, _, _):
            context.globalForumId.set(peerId)
        case .savedMessagesChats:
            context.globalForumId.set(context.peerId)
        default:
            break
        }
        self.searchController?.view.isHidden = false
        self.searchController?.view._change(opacity: 1, animated: true)
    }
    
    override var stake: StakeSettings {
        switch mode {
        case let .forum(_, isFull, parentIsArchive):
            if !isFull {
                return .init(keepLeft: 70, keepTop: { [weak self] in
                    guard let state = self?.state else {
                        return 0
                    }
                    var height: CGFloat = 90
                    if !state.filterData.isEmpty, state.splitState != .minimisize {
                        if !state.filterData.sidebar {
                            if !parentIsArchive {
                                height += 36
                            }
                        }
                    }
                    return height
                }, straightMove: true, keepIn: false)
            }
        case .plain:
            return .init(keepLeft: 0, keepTop: { 0}, straightMove: false, keepIn: true)
        default:
            break
        }
        return super.stake
    }
    
    private(set) var swipeState: SwipeState?
    
    func getSwipeProgress() -> CGFloat? {
        if let swipeState = swipeState {
            switch swipeState {
            case .swiping, .success, .start:
                return swipeState.delta / (frame.width - 70)
            default:
                return nil
            }
        }
        return nil
    }
    
    override func updateSwipingState(_ state: SwipeState, controller: ViewController, isPrevious: Bool) -> Void {
        
        if isPrevious, controller.stake.keepLeft > 0 {
            self.genericView.updateSwipingState(state, controller: controller)
            self.swipeState = state
            
            genericView.tableView.enumerateViews(with: { view in
                if let view = view as? ChatListRowView {
                    let animated: Bool
                    switch swipeState {
                    case .swiping, .success, .start:
                        animated = false
                    default:
                        animated = true
                    }
                    view.updateHideProgress(animated: animated)
                }
                return true
            })

            if let progress = getSwipeProgress() {
                genericView.backgroundView.layer?.opacity = Float(1 - progress)
            }
        }
    }
    
    private var deltaY: CGFloat = 0
    private var initFromEvent: Bool? = nil
    
    private var _storyInterfaceState: StoryListChatListRowItem.InterfaceState = .concealed
    private var storyInterfaceState: StoryListChatListRowItem.InterfaceState {
        get {
            if self.state?.hasStories == false {
                return .empty
            }
            return self._storyInterfaceState
            
        }
        set {
            _storyInterfaceState = newValue
        }
    }
    
    var canStoryOverscroll: Bool {
        if self.state?.splitState == .minimisize {
            return false
        }
        if state?.forumPeer != nil {
            return false
        }
        if state?.appear == .short {
            return false
        }
        return true
    }
    
    func getStoryInterfaceState() -> StoryListChatListRowItem.InterfaceState {
        return self.takeArguments()?.getStoryInterfaceState() ?? .empty
    }
    
    func getDeltaProgress() -> CGFloat? {
        genericView.getDeltaProgress()
    }
    
    @discardableResult private func updateOverscrollWithDelta(_ scrollingDeltaY: CGFloat) -> Bool {
        
        let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
        guard let item = optional, storyInterfaceState != .empty else {
            return false
        }
        
        deltaY -= scrollingDeltaY
        
        switch storyInterfaceState {
        case let .progress(_, from, fromEvent):
            
            var optimized: CGFloat = deltaY
            let autofinish: Bool
            switch from {
            case .concealed:
                
                if fromEvent {
                    let value = StoryListChatListRowItem.InterfaceState.small
                    let current = log(max(1, StoryListChatListRowItem.InterfaceState.small - optimized))
                    let result = value - current
                    optimized = result
                    autofinish = current > 5.0
                } else {
                    autofinish = optimized <= (StoryListChatListRowItem.InterfaceState.small + 10) / 2
                }
                
            case .revealed:
                autofinish = optimized >= StoryListChatListRowItem.InterfaceState.small
            }
            
            let speed = calculateScrollSpeed(scrollPositions: scrollPositions)
            
            if autofinish  {
                initFromEvent = nil
                scrollPositions = [-1000, 1000]
            }
            let progress: CGFloat = max(0.0, min(1.0 - optimized / StoryListChatListRowItem.InterfaceState.small, 1.0))
            let animated = progress != 0
            if autofinish {
                switch storyInterfaceState {
                case let .progress(_, from, _):
                    switch from {
                    case .revealed:
                        storyInterfaceState = .concealed
                    case .concealed:
                        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .drawCompleted)
                        storyInterfaceState = .revealed
                    }
                    CATransaction.begin()
                    self.genericView.updateLayout(frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
                    
                    self.genericView.tableView.reloadData(row: item.index, animated: animated)
                    CATransaction.commit()
                    
                    return false
                default:
                    return false
                }
            } else {
                storyInterfaceState = .progress(progress, from, fromEvent)
                CATransaction.begin()
                genericView.tableView.reloadData(row: item.index)
                self.genericView.updateLayout(frame.size, transition: .immediate)
                CATransaction.commit()
                return true
            }
        default:
            return false
        }
    }
    
    @discardableResult private func initOverscrollWithDelta(_ scrollingDeltaY: CGFloat, fromEvent: Bool) -> Bool {
        
        
        switch storyInterfaceState {
        case .revealed:
            deltaY = 0
            if scrollingDeltaY < 0 {
                initFromEvent = fromEvent
                self.storyInterfaceState = .progress(1.0, .revealed, fromEvent)
            } else {
                initFromEvent = nil
                return false
            }
        case .concealed:
            deltaY = StoryListChatListRowItem.InterfaceState.small
            if scrollingDeltaY > 0 {
                initFromEvent = fromEvent
                self.storyInterfaceState = .progress(0.0, .concealed, fromEvent)
            } else {
                initFromEvent = nil
                return false
            }
        case .progress:
            initFromEvent = nil
        case .empty:
            fatalError("not supported")
        }
        return true
    }
    @discardableResult private func finishOverscroll() -> Bool {
        
        let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
        guard let item = optional else {
            return false
        }
        initFromEvent = nil

        switch storyInterfaceState {
        case let .progress(value, _, _):
            if value > 0.5 {
                self.storyInterfaceState = .revealed
            } else {
                self.storyInterfaceState = .concealed
            }
            CATransaction.begin()
            self.genericView.tableView.reloadData(row: item.index, animated: true)
            self.genericView.updateLayout(frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
            CATransaction.commit()
            return true
        default:
            break
        }
        return false
    }
    
    private var scrollPositions: [CGFloat] = []
    private func processScroll() {
        
        
        guard storyInterfaceState != .empty, canStoryOverscroll, initFromEvent == nil || initFromEvent == false else {
            return
        }
        
        if searchController != nil {
            return
        }
        
        if genericView.tableView.liveScrolling {
//            let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
//            optional?.view?.layer?.removeAllAnimations()
        }
        
        if storyInterfaceState == .revealed || storyInterfaceState.toHideProgress {
            let position = genericView.tableView.documentOffset.y
            let last = scrollPositions.last ?? 0
            self.scrollPositions.append(position)
            let speed = calculateScrollSpeed(scrollPositions: scrollPositions)
            if last != position, last >= 0 {
                if position > last, let speed = speed, speed < 0 {
                    let value = last - position
                    initOverscrollWithDelta(value, fromEvent: false)
                    updateOverscrollWithDelta(value)
                }
            } else if position < last {
                self.scrollPositions = []
            }
        } else if storyInterfaceState == .concealed || storyInterfaceState.toRevealProgress {
            let position = genericView.tableView.documentOffset.y
            let last = scrollPositions.last ?? 0
            if last != position {
                self.scrollPositions.append(position)
                if position <= 0 {
                    let previous = last
                    let speed = calculateScrollSpeed(scrollPositions: scrollPositions)
                    let acceptSpeed = speed != nil && abs(speed!) < 2.5
                    if acceptSpeed || storyInterfaceState.isProgress {
                        if position == 0 {
                            finishOverscroll()
                        } else {
                            let value = previous - position
                            initOverscrollWithDelta(value, fromEvent: false)
                            updateOverscrollWithDelta(value)
                        }
                    }
                } else if position > last {
                    self.scrollPositions = []
                }
            }
        }
    }
        
     func processScroll(_ event: NSEvent) -> Bool {
         scrollPositions = []

         guard genericView.tableView.documentOffset.y == 0, canStoryOverscroll, storyInterfaceState != .empty else {
             return false
         }
         if searchController != nil {
             return false
         }
        
         switch event.phase {
         case .began, .mayBegin:
             if event.scrollingDeltaY != 0 {
                 return initOverscrollWithDelta(event.scrollingDeltaY, fromEvent: true)
             } else {
                 return false
             }
         case .changed, .stationary:
             return updateOverscrollWithDelta(event.scrollingDeltaY)
         case .ended, .cancelled:
             return finishOverscroll()
         default:
             if event.phase.rawValue == 0 {
                 return false
             }
             return finishOverscroll() || (event.phase.rawValue == 0 && event.momentumPhase != .ended)
         }
    }
    
    func toggleStoriesState() {
        
        if case let .forum(peerId, _, _) = self.mode {
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
            return
        }
        
        let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
        guard let item = optional, storyInterfaceState != .empty else {
            return
        }
        if self.storyInterfaceState == .revealed {
            self.storyInterfaceState = .concealed
        } else {
            self.storyInterfaceState = .revealed
        }
        CATransaction.begin()
        self.genericView.tableView.scroll(to: .up(false), ignoreLayerAnimation: true)
        self.genericView.tableView.reloadData(row: item.index, animated: true)
        self.genericView.updateLayout(frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
        CATransaction.commit()
    }
    
    @discardableResult func revealStoriesState() -> Bool {
        let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
        guard let item = optional, storyInterfaceState != .empty else {
            return false
        }
        
        if self.storyInterfaceState != .revealed {
            self.genericView.searchView.cancel(true)
            self.storyInterfaceState = .revealed
            CATransaction.begin()
            self.genericView.tableView.scroll(to: .up(false), ignoreLayerAnimation: true)
            self.genericView.tableView.reloadData(row: item.index, animated: true)
            self.genericView.updateLayout(frame.size, transition: .animated(duration: 0.2, curve: .easeOut))
            CATransaction.commit()
            return true
        }
        return false
    }
    
    func completeUndefiedStates(animated: Bool) {
        let optional = self.genericView.tableView.item(stableId: UIChatListEntryId.space) as? ChatListSpaceItem
        guard let item = optional, storyInterfaceState != .empty else {
            return
        }
        if self.storyInterfaceState == .revealed {
            self.storyInterfaceState = .concealed
            
            let transition: ContainedViewLayoutTransition
            if animated {
                transition = .animated(duration: 0.2, curve: .easeOut)
            } else {
                transition = .immediate
            }
            CATransaction.begin()
            self.genericView.tableView.scroll(to: .up(false), ignoreLayerAnimation: true)
            self.genericView.tableView.reloadData(row: item.index, animated: animated)
            self.genericView.updateLayout(frame.size, transition: transition)
            CATransaction.commit()
        }
    }

    
        
}

