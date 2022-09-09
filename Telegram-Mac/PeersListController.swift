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

import SwiftSignalKit


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

private struct State : Equatable {
    var proxySettings: ProxySettings
    var connectionStatus: ConnectionStatus
    var splitState: SplitViewState
    var searchState: SearchFieldState = .None
    var peer: PeerEquatable?
    var mode: PeerListMode
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
             //   proxyConnecting.isHidden = !pref.enabled
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
        
        func update(_ peer: Peer, context: AccountContext, animated: Bool) {
            let statusUpdated = self.peer?.emojiStatus?.fileId != peer.emojiStatus?.fileId && self.peer != nil
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
            
            if statusUpdated, let status = peer.emojiStatus {
                self.playStatusEffect(status, context: context)
            }
        }
        
        private func playStatusEffect(_ status: PeerEmojiStatus, context: AccountContext) -> Void {
            self.playAnimation(status.fileId, context: context)
        }
        
        private func playAnimation(_  fileId: Int64, context: AccountContext) {
            guard let control = button, visibleRect != .zero, window != nil else {
                return
            }
            
            let player = CustomReactionEffectView(frame: NSMakeSize(160, 160).bounds, context: context, fileId: fileId)
            
            player.isEventLess = true
            
            player.triggerOnFinish = { [weak player] in
                player?.removeFromSuperview()
            }
                    
            let controlRect = self.convert(control.frame, to: window?.contentView?.superview)
            
            let rect = CGRect(origin: CGPoint(x: controlRect.midX - player.frame.width / 2, y: controlRect.midY - player.frame.height / 2), size: player.frame.size)
            
            player.frame = rect
            
            window?.contentView?.superview?.addSubview(player)
            
        }
        
        override func layout() {
            super.layout()
            button?.center()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func updateLocalizationAndTheme(theme: PresentationTheme) {
            super.updateLocalizationAndTheme(theme: theme)
        }
    }

    
    private let backgroundView = BackgroundView(frame: NSZeroRect)
    
    let tableView = TableView(frame:NSZeroRect, drawBorder: true)
    private let containerView: View = View()
    
    let searchView:SearchView = SearchView(frame:NSMakeRect(10, 0, 0, 0))
    let compose:ImageButton = ImageButton()
    
    private var premiumStatus: StatusView?
    private var downloads: DownloadsControl?
    private var proxy: ProxyView?
    
    var openSharedMediaWithToken:((PeerId?, MessageTags?)->Void)? = nil
    
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
    
    private var state: State?
    
    
    var openProxy:((Control)->Void)? = nil
    var openStatus:((Control)->Void)? = nil

    fileprivate func updateState(_ state: State, context: AccountContext, animated: Bool) {
        
        let animated = animated && self.state?.splitState == state.splitState && self.state != nil
        self.state = state
        
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
            current.update(peer, context: context, animated: animated)
            
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
    
    
    fileprivate func searchStateChanged(_ state: State, context: AccountContext, animated: Bool, updateSearchTags: @escaping(SearchTags)->Void, updatePeerTag:@escaping(@escaping(Peer?)->Void)->Void, updateMessageTags: @escaping(@escaping(MessageTags?)->Void)->Void) {
                        
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
            searchView.customSearchControl = CustomSearchController(clickHandler: { [weak self] control, updateTitle in
                
                
                var items: [ContextMenuItem] = []

                
                items.append(ContextMenuItem.init(strings().chatListDownloadsTag, handler: { [weak self] in
                    updateSearchTags(SearchTags(messageTags: nil, peerTag: nil))
                    self?.showDownloads?()
                }, itemImage: MenuAnimation.menu_save_as.value))
                
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
        
        self.updateState(state, context: context, animated: animated)
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
            case .folder:
                offset = 0
            default:
                break
            }
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
        
        let searchRect = NSMakeRect(10, floorToScreenPixels(backingScaleFactor, (offset - componentSize.height)/2.0), searchWidth, componentSize.height)
        
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
        
        
//        if splitState == .minimisize {
//            transition.updateFrame(view: compose, frame: compose.centerFrame())
//
//            proxyButton.setFrameOrigin(-proxyButton.frame.width, 0)
//        } else {
//            compose.setFrameOrigin(containerView.frame.width - 12 - compose.frame.width, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - compose.frame.height)/2.0))
//
//            proxyButton.setFrameOrigin(containerView.frame.width - 12 - compose.frame.width - proxyButton.frame.width - 6, floorToScreenPixels(backingScaleFactor, (containerView.frame.height - proxyButton.frame.height)/2.0))
//        }
//
//        proxyConnecting.centerX()
//        proxyConnecting.centerY(addition: -(backingScaleFactor == 2.0 ? 0.5 : 0))
        
        
      
        
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
    case folder(PeerGroupId)
    case filter(Int32)
    
    var isPlain:Bool {
        switch self {
        case .plain:
            return true
        default:
            return false
        }
    }
    var groupId: PeerGroupId {
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
}


class PeersListController: TelegramGenericViewController<PeerListContainerView>, TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let progressDisposable = MetaDisposable()
    private let createSecretChatDisposable = MetaDisposable()
    private let layoutDisposable = MetaDisposable()
    private let actionsDisposable = DisposableSet()
    private let followGlobal:Bool
    private let searchOptions: AppSearchOptions
    
    private var downloadsController: ViewController?
    
    let mode:PeerListMode
    private(set) var searchController:SearchController? {
        didSet {
            if let controller = searchController {
                genericView.customHandler.size = { [weak controller] size in
                    controller?.view.setFrameSize(NSMakeSize(size.width, size.height - 49))
                }
                progressDisposable.set((controller.isLoading.get() |> deliverOnMainQueue).start(next: { [weak self] isLoading in
                    self?.genericView.searchView.isLoading = isLoading
                }))
            }
        }
    }
    
    init(_ context: AccountContext, followGlobal:Bool = true, mode: PeerListMode = .plain, searchOptions: AppSearchOptions = [.chats, .messages]) {
        self.followGlobal = followGlobal
        self.mode = mode
        self.searchOptions = searchOptions
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
        layoutDisposable.dispose()
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
        
        layoutDisposable.set(context.layoutHandler.get().start(next: { [weak self] state in
            if let strongSelf = self, case .minimisize = state {
                if strongSelf.genericView.searchView.state == .Focus {
                    strongSelf.genericView.searchView.change(state: .None,  false)
                }
            }
            self?.checkSearchMedia()
            self?.genericView.tableView.alwaysOpenRowsOnMouseUp = state == .single
            self?.genericView.tableView.reloadData()
            Queue.mainQueue().justDispatch {
                self?.requestUpdateBackBar()
            }
        }))
        
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
        
        let stateValue: Atomic<State?> = Atomic(value: nil)
        let state: ValuePromise<State?> = ValuePromise(nil, ignoreRepeated: true)
        let updateState:((State?)->State?) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        

        let layoutSignal = context.layoutHandler.get()
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
        
        actionsDisposable.add(combineLatest(queue: .mainQueue(), proxy, layoutSignal, peer, appearanceSignal).start(next: { pref, layout, peer, _ in
            updateState { state in
                let state: State = .init(proxySettings: pref.0, connectionStatus: pref.1, splitState: layout, peer: peer, mode: mode)
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
                let callback:(TelegramMediaFile, Int32?)->Void = { file, timeout in
                    let expiryDate: Int32?
                    if let timeout = timeout {
                        expiryDate = context.timestamp + timeout
                    } else {
                        expiryDate = nil
                    }
                    if file.mimeType.hasPrefix("bundle") {
                        _ = context.engine.accountData.setEmojiStatus(file: nil, expirationDate: expiryDate).start()
                    } else {
                        _ = context.engine.accountData.setEmojiStatus(file: file, expirationDate: expiryDate).start()

                    }
                    
                }
                if control.popover == nil {
                    showPopover(for: control, with: PremiumStatusController(context, callback: callback, peer: peer), edge: .maxY, inset: NSMakePoint(-80, -35), static: true, animationMode: .reveal)
                }
            }
        }
        
//        genericView.proxyButton.set(handler: {  _ in
//            if let settings = settings {
//                 openProxySettings()
//            }
//        }, for: .Click)
        
        
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
            guard let `self` = self else {return}
            switch state.state {
            case .Focus:
                assert(self.searchController == nil)
                self.showSearchController(animated: animated)
                
            case .None:
                self.hideSearchController(animated: animated)
            }
            updateState { current in
                var current = current
                current?.searchState = state.state
                return current
            }
        }, { [weak self] state in
            guard let `self` = self else {return}
            self.searchController?.request(with: state.request)
        }, responderModified: { [weak self] state in
            self?.context.isInGlobalSearch = state.responder
        })
        
        let stateSignal = state.get()
        |> filter { $0 != nil }
        |> map { $0! }
        
        actionsDisposable.add(stateSignal.start(next: { [weak self] state in
            self?.genericView.searchStateChanged(state, context: context, animated: true, updateSearchTags: { [weak self] tags in
                self?.searchController?.updateSearchTags(tags)
                self?.sharedMediaWithToken(tags)
            }, updatePeerTag: { [weak self] f in
                self?.searchController?.setPeerAsTag = f
            }, updateMessageTags: { [weak self] f in
                self?.updateSearchMessageTags = f
            })
        }))
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
            switch location {
            case .peer:
                self.genericView.tableView.changeSelection(stableId: UIChatListEntryId.chatId(location.peerId, -1))
            case .replyThread:
                self.genericView.tableView.changeSelection(stableId: nil)
            }
        } else {
            self.genericView.tableView.changeSelection(stableId: nil)
        }
    }
    
    private func showSearchController(animated: Bool) {
        if searchController == nil {
           // delay(0.15, closure: {
                let rect = self.genericView.tableView.frame
                let searchController = SearchController(context: self.context, open:{ [weak self] (peerId, messageId, close) in
                    if let peerId = peerId {
                        self?.open(with: .chatId(peerId, -1), messageId: messageId, close:close)
                    } else {
                        self?.genericView.searchView.cancel(true)
                    }
                }, options: self.searchOptions, frame:NSMakeRect(rect.minX, rect.minY, self.frame.width, rect.height))
                
                searchController.pinnedItems = self.collectPinnedItems
                
                self.searchController = searchController
//                self.genericView.tableView.change(opacity: 0, animated: animated, completion: { [weak self] _ in
//                    self?.genericView.tableView.isHidden = true
//                })
                searchController.defaultQuery = self.genericView.searchView.query
                searchController.navigationController = self.navigationController
                searchController.viewWillAppear(true)
                
                
                
                if animated {
                    searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion:{ [weak self] complete in
                        if complete {
                            self?.searchController?.viewDidAppear(animated)
                        //     self?.genericView.tableView.isHidden = true
                        }
                    })
                    searchController.view.layer?.animateScaleSpring(from: 1.05, to: 1.0, duration: 0.4, bounce: false)
                    searchController.view.layer?.animatePosition(from: NSMakePoint(rect.minX, rect.minY + 15), to: rect.origin, duration: 0.4, timingFunction: .spring)

                } else {
                    searchController.viewDidAppear(animated)
                }
                self.addSubview(searchController.view)
           // })
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
            searchController.view.layer?.animateScaleSpring(from: 1.0, to: 1.05, duration: 0.4, removeOnCompletion: false, bounce: false)
            genericView.tableView.layer?.animateScaleSpring(from: 0.95, to: 1.00, duration: 0.4, removeOnCompletion: false, bounce: false)

        }
        if let controller = mediaSearchController {
            context.bindings.rootNavigation().removeImmediately(controller, upNext: false)
        }
    }
    
    override func focusSearch(animated: Bool, text: String? = nil) {
        genericView.searchView.change(state: .Focus, animated)
        if let text = text {
            genericView.searchView.setString(text)
         //   self?.searchController?.updateSearchTags(tag)
            //genericView.searchView.updateTags(<#T##tags: [String]##[String]#>, <#T##image: CGImage##CGImage#>)
        }
    }
    
    override func navigationUndoHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> ()->Void  {
        genericView.layer?.animatePosition(from: NSMakePoint(0, previous), to: NSMakePoint(0, current), removeOnCompletion: false)
        return { [weak genericView] in
            genericView?.layer?.removeAllAnimations()
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
        case let .chatId(peerId, _):
            
            if let modalAction = navigation.modalAction as? FWDNavigationAction, peerId == context.peerId {
                _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId).start()
                _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.0).start()
                modalAction.afterInvoke()
                navigation.removeModalAction()
            } else {
                
                if let current = navigation.controller as? ChatController, peerId == current.chatInteraction.peerId, let messageId = messageId, current.mode == .history {
                    current.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
                } else {
                    let chat:ChatController = addition ? ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: messageId) : ChatController(context: self.context, chatLocation: .peer(peerId), messageId: messageId, initialAction: initialAction)
                    navigation.push(chat, context.layout == .single || forceAnimated)
                }
            }
        case let .groupId(groupId):
            self.navigationController?.push(ChatListController(context, modal: false, groupId: groupId))
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
        
        if animated {
           // genericView.tableView.layoutItems()
        }
        
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
