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
import SyncCore
import SwiftSignalKit
import SyncCore

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
        
        let layout = TextViewLayout(.initialize(string: L10n.chatListCloseFilter, color: .white, font: .medium(.title)))
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

class PeerListContainerView : View {
    private let backgroundView = BackgroundView(frame: NSZeroRect)
    var tableView = TableView(frame:NSZeroRect, drawBorder: true) {
        didSet {
            oldValue.removeFromSuperview()
            addSubview(tableView)
        }
    }
    private let searchContainer: View = View()
    
    let searchView:SearchView = SearchView(frame:NSMakeRect(10, 0, 0, 0))
    let compose:ImageButton = ImageButton()
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 11, 11))
    private var searchState: SearchFieldState = .None
    
    var openSharedMediaWithToken:((PeerId?, MessageTags?)->Void)? = nil

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
            needsLayout = true
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.border = [.Right]
        compose.autohighlight = false
        autoresizesSubviews = false
        addSubview(searchContainer)
        addSubview(tableView)
        searchContainer.addSubview(compose)
        searchContainer.addSubview(proxyButton)
        searchContainer.addSubview(searchView)
        proxyButton.addSubview(proxyConnecting)
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme(theme: theme)
        proxyButton.disableActions()
        addSubview(backgroundView)
        backgroundView.isHidden = true
        

        
        tableView.getBackgroundColor = {
            .clear
        }
        layout()
    }
    
    fileprivate func updateProxyPref(_ pref: ProxySettings, _ connection: ConnectionStatus) {
        proxyButton.isHidden = pref.servers.isEmpty && pref.effectiveActiveServer == nil
        switch connection {
        case .connecting, .waitingForNetwork:
            proxyConnecting.isHidden = !pref.enabled
            proxyButton.set(image: pref.enabled ? theme.icons.proxyState : theme.icons.proxyEnable, for: .Normal)
        case .online, .updating:
            proxyConnecting.isHidden = true
            if pref.enabled  {
                proxyButton.set(image: theme.icons.proxyEnabled, for: .Normal)
            } else {
                proxyButton.set(image: theme.icons.proxyEnable, for: .Normal)
            }
        }
        proxyConnecting.isEventLess = true
        proxyConnecting.userInteractionEnabled = false
        _ = proxyButton.sizeToFit()
        proxyConnecting.centerX()
        needsLayout = true
    }
    
    
    func searchStateChanged(_ state: SearchFieldState, animated: Bool, updateSearchTags: @escaping(SearchTags)->Void, updatePeerTag:@escaping(@escaping(Peer?)->Void)->Void, updateMessageTags: @escaping(@escaping(MessageTags?)->Void)->Void) {
        self.searchState = state
        searchView.change(size: NSMakeSize(state == .Focus || !mode.isPlain ? frame.width - searchView.frame.minX * 2 : (frame.width - (36 + compose.frame.width) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30), animated: animated)
        compose.change(opacity: state == .Focus ? 0 : 1, animated: animated)
        proxyButton.change(opacity: state == .Focus ? 0 : 1, animated: animated)
        
        var currentTag: MessageTags?
        var currentPeerTag: Peer?
        

        let tags:[(MessageTags?, String, CGImage)] = [(nil, L10n.searchFilterClearFilter, theme.icons.search_filter),
                                            (.photo, L10n.searchFilterPhotos, theme.icons.search_filter_media),
                                            (.video, L10n.searchFilterVideos, theme.icons.search_filter_media),
                                            (.webPage, L10n.searchFilterLinks, theme.icons.search_filter_links),
                                            (.music, L10n.searchFilterMusic, theme.icons.search_filter_music),
                                            (.voiceOrInstantVideo, L10n.searchFilterVoice, theme.icons.search_filter_music),
                                            (.gif, L10n.searchFilterGIFs, theme.icons.search_filter_media),
                                            (.file, L10n.searchFilterFiles, theme.icons.search_filter_files)]
        
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
        
        switch state {
        case .Focus:
            searchView.customSearchControl = CustomSearchController(clickHandler: { control, updateTitle in
                
                
                var items: [SPopoverItem] = []

                
                for tag in tags {
                    var append: Bool = false
                    if currentTag != tag.0 {
                        append = true
                    }
                    if append {
                        items.append(SPopoverItem(tag.1, {
                            currentTag = tag.0
                            updateSearchTags(SearchTags(messageTags: currentTag, peerTag: currentPeerTag?.id))
                            let collected = collectTags()
                            updateTitle(collected.0, collected.1)
                        }))
                    }
                }
                
                showPopover(for: control, with: SPopoverViewController(items: items, visibility: 10), edge: .maxY, inset: NSMakePoint(0, -25))
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
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let theme = (theme as! TelegramPresentationTheme)
        self.backgroundColor = theme.colors.background
        compose.background = .clear
        compose.set(background: .clear, for: .Normal)
        compose.set(background: .clear, for: .Hover)
        compose.set(background: theme.colors.accent, for: .Highlight)
        compose.set(image: theme.icons.composeNewChat, for: .Normal)
        compose.set(image: theme.icons.composeNewChatActive, for: .Highlight)
        compose.layer?.cornerRadius = .cornerRadius
        compose.setFrameSize(NSMakeSize(40, 30))
        proxyConnecting.progressColor = theme.colors.accentIcon
//        proxyConnecting.lineWidth = 1.0
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        
        var offset: CGFloat
        switch theme.controllerBackgroundMode {
        case .background:
            offset = 50
        case .tiled:
            offset = 50
        default:
            offset = 50
        }
        
        if frame.width < 200 {
            switch self.mode {
            case .folder:
                offset = 0
                
            default:
                break
            }
        }
        
        searchContainer.frame = NSMakeRect(0, 0, frame.width, offset)

        
        searchView.setFrameSize(NSMakeSize(searchState == .Focus || !mode.isPlain ? frame.width - searchView.frame.minX * 2 : (frame.width - (36 + compose.frame.width) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30))
        
        
        tableView.setFrameSize(frame.width, frame.height - offset)
        
        searchView.isHidden = frame.width < 200
        if searchView.isHidden {
            compose.center()
            proxyButton.setFrameOrigin(-proxyButton.frame.width, 0)
        } else {
            compose.setFrameOrigin(searchContainer.frame.width - 12 - compose.frame.width, floorToScreenPixels(backingScaleFactor, (searchContainer.frame.height - compose.frame.height)/2.0))
            proxyButton.setFrameOrigin(searchContainer.frame.width - 12 - compose.frame.width - proxyButton.frame.width - 6, floorToScreenPixels(backingScaleFactor, (searchContainer.frame.height - proxyButton.frame.height)/2.0))
        }
        searchView.setFrameOrigin(10, floorToScreenPixels(backingScaleFactor, (offset - searchView.frame.height)/2.0))
        tableView.setFrameOrigin(0, offset)
        
        proxyConnecting.centerX()
        proxyConnecting.centerY(addition: -(backingScaleFactor == 2.0 ? 0.5 : 0))
        
        backgroundView.frame = bounds
        
        self.needsDisplay = true
    }
    
}


enum PeerListMode {
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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.context

        
        layoutDisposable.set(context.sharedContext.layoutHandler.get().start(next: { [weak self] state in
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
            self.setCenterTitle(L10n.chatForwardActionHeader)
        }
        
        if self.navigationController?.modalAction is ShareInlineResultNavigationAction {
            self.setCenterTitle(L10n.chatShareInlineResultActionHeader)
        }
        
        genericView.tableView.delegate = self
        
        var settings:(ProxySettings, ConnectionStatus)? = nil
        
        
        
        actionsDisposable.add(combineLatest(proxySettings(accountManager: context.sharedContext.accountManager) |> mapToSignal { ps -> Signal<(ProxySettings, ConnectionStatus), NoError> in
            return context.account.network.connectionStatus |> map { status -> (ProxySettings, ConnectionStatus) in
                return (ps, status)
            }
        } |> deliverOnMainQueue, appearanceSignal |> deliverOnMainQueue).start(next: { [weak self] pref, _ in
            settings = (pref.0, pref.1)
            self?.genericView.updateProxyPref(pref.0, pref.1)
        }))
        
        let pushController:(ViewController)->Void = { [weak self] c in
            self?.context.sharedContext.bindings.rootNavigation().push(c)
        }
        
        let openProxySettings:()->Void = { [weak self] in
            if let controller = self?.context.sharedContext.bindings.rootNavigation().controller as? InputDataController {
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

                showModal(with: ShareModalController(ShareLinkObject(context, link: message)), for: mainWindow)
            }, pushController: { controller in
                 pushController(controller)
            })
            pushController(controller)
        }
        
        genericView.proxyButton.set(handler: {  _ in
            if let settings = settings {
                 openProxySettings()
            }
        }, for: .Click)
        
        genericView.compose.set(handler: { [weak self] control in
            if let strongSelf = self, !control.isSelected {
                
                let items = [SPopoverItem(tr(L10n.composePopoverNewGroup), { [weak strongSelf] in
                    guard let strongSelf = strongSelf else {return}
                    strongSelf.context.composeCreateGroup()
                }, theme.icons.composeNewGroup),SPopoverItem(tr(L10n.composePopoverNewSecretChat), { [weak strongSelf] in
                    guard let strongSelf = strongSelf else {return}
                    strongSelf.context.composeCreateSecretChat()
                }, theme.icons.composeNewSecretChat),SPopoverItem(tr(L10n.composePopoverNewChannel), { [weak strongSelf] in
                    guard let strongSelf = strongSelf else {return}
                    strongSelf.context.composeCreateChannel()
                }, theme.icons.composeNewChannel)];
                if let popover = control.popover {
                    popover.hide()
                } else {
                    showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-138,  -(strongSelf.genericView.compose.frame.maxY + 10)))
                }
            }
        }, for: .Click)
        
        
        genericView.searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            guard let `self` = self else {return}
            switch state.state {
            case .Focus:
                assert(self.searchController == nil)
                self.showSearchController(animated: animated)
                
            case .None:
                self.hideSearchController(animated: animated)
            }
            self.genericView.searchStateChanged(state.state, animated: animated, updateSearchTags: { [weak self] tags in
                self?.searchController?.updateSearchTags(tags)
                self?.sharedMediaWithToken(tags)
            }, updatePeerTag: { [weak self] f in
                self?.searchController?.setPeerAsTag = f
            }, updateMessageTags: { [weak self] f in
                self?.updateSearchMessageTags = f
            })

        }, { [weak self] state in
            guard let `self` = self else {return}
            self.searchController?.request(with: state.request)
        }, responderModified: { [weak self] state in
            self?.context.isInGlobalSearch = state.responder
        })
        
        
    }
    
    private func checkSearchMedia() {
        let destroy:()->Void = { [weak self] in
            if let previous = self?.mediaSearchController {
                self?.context.sharedContext.bindings.rootNavigation().removeImmediately(previous)
            }
        }
        guard context.sharedContext.layout == .dual else {
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
                self?.context.sharedContext.bindings.rootNavigation().removeImmediately(previous)
            }
        }
        
        guard context.sharedContext.layout == .dual else {
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
            
            let navigation = context.sharedContext.bindings.rootNavigation()
            
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
        return context.sharedContext.layout == .minimisize ? ("", theme.icons.instantViewBack) : super.backSettings()
    }
    
    
    func changeSelection(_ location: ChatLocation?) {
        if let location = location {
            switch location {
            case .peer:
                self.genericView.tableView.changeSelection(stableId: UIChatListEntryId.chatId(location.peerId, nil))
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
                        self?.open(with: .chatId(peerId, nil), messageId: messageId, close:close)
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
            context.sharedContext.bindings.rootNavigation().removeImmediately(controller, upNext: false)
        }
    }
    
    override func focusSearch(animated: Bool) {
        genericView.searchView.change(state: .Focus, animated)
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
        guard context.sharedContext.layout != .minimisize else {
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
    
    func open(with entryId: UIChatListEntryId, messageId:MessageId? = nil, initialAction: ChatInitialAction? = nil, close:Bool = true, addition: Bool = false) ->Void {
        
        let navigation = context.sharedContext.bindings.rootNavigation()
        
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
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                modalAction.afterInvoke()
                navigation.removeModalAction()
            } else {
                
                if let current = navigation.controller as? ChatController, peerId == current.chatInteraction.peerId, let messageId = messageId, current.mode == .history {
                    current.chatInteraction.focusMessageId(nil, messageId, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
                } else {
                    let chat:ChatController = addition ? ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: messageId) : ChatController(context: self.context, chatLocation: .peer(peerId), messageId: messageId, initialAction: initialAction)
                    navigation.push(chat, context.sharedContext.layout == .single)
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
        
        if context.sharedContext.layout == .single && animated {
            context.globalPeerHandler.set(.single(nil))
        }

        
        context.window.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Escape, priority:.low)
        
        context.window.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.returnKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Return, priority:.low)
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            if let item = self?.effectiveTableView.selectedItem(), item.index > 0 {
                self?.effectiveTableView.selectPrev()
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .medium, modifierFlags: [.option])
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.effectiveTableView.selectNext()
            return .invoked
        }, with: self, for: .DownArrow, priority:.medium, modifierFlags: [.option])
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.effectiveTableView.selectNext(turnDirection: false)
            return .invoked
        }, with: self, for: .Tab, priority: .modal, modifierFlags: [.control])
        
        context.window.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.effectiveTableView.selectPrev(turnDirection: false)
            return .invoked
        }, with: self, for: .Tab, priority: .modal, modifierFlags: [.control, .shift])
        
        
        
    }
    

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        context.window.removeAllHandlers(for: self)

    }
    
}
