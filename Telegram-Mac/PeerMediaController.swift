 //
 //  PeerMediaController.swift
 //  Telegram-Mac
 //
 //  Created by keepcoder on 13/10/2016.
 //  Copyright © 2016 Telegram. All rights reserved.
 //
 
 import Cocoa
 import TGUIKit
 import TelegramCore
 import SyncCore
 import SwiftSignalKit
 import Postbox
 
 
 
 
 protocol PeerMediaSearchable : ViewController {
    func toggleSearch()
    func setSearchValue(_ value: Signal<SearchState, NoError>)
    func setExternalSearch(_ value: Signal<ExternalSearchMessages?, NoError>, _ loadMore: @escaping()->Void)
    var mediaSearchValue:Signal<MediaSearchState, NoError> { get }
 }

 private final class SearchContainerView : View {
    fileprivate let searchView: SearchView = SearchView(frame: NSMakeRect(0, 0, 200, 30))
    fileprivate let close: ImageButton = ImageButton()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(searchView)
        addSubview(close)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        borderColor = theme.colors.border
        backgroundColor = .clear
        close.set(image: theme.icons.dismissPinned, for: .Normal)
        _ = close.sizeToFit()
    }
    
    override func layout() {
        super.layout()
        searchView.setFrameSize(NSMakeSize(frame.width - close.frame.width - 30, 30))
        searchView.centerY(x: 10)
        close.centerY(x: searchView.frame.maxX + 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 }
 
 private final class SegmentContainerView : View {
    fileprivate let segmentControl: ScrollableSegmentView
    required init(frame frameRect: NSRect) {
        self.segmentControl = ScrollableSegmentView(frame: NSMakeRect(0, 0, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(segmentControl)
        updateLocalizationAndTheme(theme: theme)
        segmentControl.fitToWidth = true
        
    }
    
    override func layout() {
        super.layout()
        
        segmentControl.frame = bounds
        segmentControl.center()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
      //  super.updateLocalizationAndTheme(theme: theme)
        segmentControl.theme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.text, textFont: .normal(.text))
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
 }
 
 private enum PeerMediaAnimationDirection {
    case leftToRight
    case rightToLeft
 }
 private let sectionOffset: CGFloat = 30
 
 final class PeerMediaContainerView : View {
    
    private let actionsPanelView:MessageActionsPanelView = MessageActionsPanelView(frame: NSMakeRect(0,0,0, 50))
    private let separator:View = View()
    
    fileprivate let view: PeerMediaControllerView
    init(frame frameRect: NSRect, isSegmentHidden: Bool) {
        view = PeerMediaControllerView(frame: NSMakeRect(0, sectionOffset, min(600, frameRect.width - sectionOffset * 2), frameRect.height - sectionOffset), isSegmentHidden: isSegmentHidden)
        super.init(frame: frameRect)
        addSubview(view)
        addSubview(actionsPanelView)
        addSubview(separator)
        backgroundColor = theme.colors.listBackground
        layout()
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.listBackground
        separator.backgroundColor = theme.colors.border
    }
    
    override func scrollWheel(with event: NSEvent) {
        view.scrollWheel(with: event)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        let blockWidth = min(600, frame.width - sectionOffset * 2)
        
        
        view.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), sectionOffset, blockWidth, frame.height - sectionOffset)
        
        let inset:CGFloat = view.isSelectionState ? 50 : 0
        actionsPanelView.frame = NSMakeRect(0, frame.height - inset, frame.width, 50)
        separator.frame = NSMakeRect(0, frame.height - inset, frame.width, .borderSize)
        
    }
    
    var mainView:NSView? {
        return self.view.mainView
    }
    
    var mainTable: TableView? {
        if let tableView = self.view.mainView as? TableView {
            return tableView
        } else if let view = self.view.mainView as? InputDataView {
            return view.tableView
        } else if let view = self.view.mainView as? PeerMediaGifsView {
            return view.tableView
        }
        return nil
    }
    
    func updateInteraction(_ chatInteraction:ChatInteraction) {
        self.view.updateInteraction(chatInteraction)
        actionsPanelView.prepare(with: chatInteraction)
    }
    
    
    fileprivate func updateMainView(with view:NSView, animated:PeerMediaAnimationDirection?) {
        self.view.updateMainView(with: view, animated: animated)
    }
    
    func updateSearchState(_ state: MediaSearchState, updateSearchState:@escaping(SearchState)->Void, toggle:@escaping()->Void) {
        self.view.updateSearchState(state, updateSearchState: updateSearchState, toggle: toggle)
    }
    
    func changeState(selectState:Bool, animated:Bool) {
        self.view.changeState(selectState: selectState, animated: animated)
        let inset:CGFloat = selectState ? 50 : 0
        actionsPanelView.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
        separator.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
    }
    
    var activePanel: View {
        return self.view.activePanel
    }
    
    
    fileprivate var segmentPanelView: SegmentContainerView {
        return self.view.segmentPanelView
    }
    fileprivate var searchPanelView: SearchContainerView? {
        return self.view.searchPanelView
    }
    
    func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
        view.updateCorners(corners, animated: animated)
    }
 }
 
 class PeerMediaControllerView : View {
    
    private let topPanelView = GeneralRowContainerView(frame: .zero)
    fileprivate let segmentPanelView: SegmentContainerView
    fileprivate var searchPanelView: SearchContainerView?
    
    private(set) weak var mainView:NSView?
    
    private let topPanelSeparatorView = View()
    
    override func scrollWheel(with event: NSEvent) {
        mainTable?.scrollWheel(with: event)
    }
    
    var mainTable: TableView? {
        if let tableView = self.mainView as? TableView {
            return tableView
        } else if let view = self.mainView as? InputDataView {
            return view.tableView
        }
        return nil
    }
    
    fileprivate var corners:GeneralViewItemCorners = [.topLeft, .topRight]
    
    fileprivate var isSelectionState:Bool = false
    private var chatInteraction:ChatInteraction?
    private var searchState: SearchState?
    init(frame frameRect:NSRect, isSegmentHidden: Bool) {
        segmentPanelView = SegmentContainerView(frame: NSMakeRect(0, 0, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(topPanelView)
        topPanelView.isHidden = isSegmentHidden
        topPanelView.addSubview(topPanelSeparatorView)
        topPanelView.addSubview(segmentPanelView)
        updateLocalizationAndTheme(theme: theme)
        layout()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
       // super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.listBackground
        topPanelView.backgroundColor = theme.colors.background
        topPanelSeparatorView.backgroundColor = theme.colors.border
    }
    
    func updateInteraction(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
    }
    
    func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
        self.corners = corners
        self.topPanelView.setCorners(corners, animated: animated)
        topPanelSeparatorView.isHidden = corners == .all
    }
    
    fileprivate func updateMainView(with view:NSView, animated:PeerMediaAnimationDirection?) {
        addSubview(view, positioned: .below, relativeTo: topPanelView)
        
        let timingFunction: CAMediaTimingFunctionName = .spring
        let duration: TimeInterval = 0.35
        
        if let animated = animated {
            if let mainView = mainView {
                switch animated {
                case .leftToRight:
                    mainView._change(pos: NSMakePoint(-mainView.frame.width, mainView.frame.minY), animated: true, duration: duration, timingFunction: timingFunction, completion: { [weak mainView] completed in
                        if completed {
                            mainView?.removeFromSuperview()
                        }
                    })
                    view.layer?.animatePosition(from: NSMakePoint(view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY), duration: duration, timingFunction: timingFunction)
                case .rightToLeft:
                    mainView._change(pos: NSMakePoint(mainView.frame.width, mainView.frame.minY), animated: true, duration: duration, timingFunction: timingFunction, completion: { [weak mainView] completed in
                        if completed {
                            mainView?.removeFromSuperview()
                        }
                    })
                    view.layer?.animatePosition(from: NSMakePoint(-view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY), duration: duration, timingFunction: timingFunction)
                }
            }
            self.mainView = view
        } else {
            mainView?.removeFromSuperview()
            self.mainView = view
        }
        needsLayout = true
    }
    
    func updateSearchState(_ state: MediaSearchState, updateSearchState:@escaping(SearchState)->Void, toggle:@escaping()->Void) {
        self.searchState = state.state
        switch state.state.state {
        case .Focus:
            if searchPanelView == nil {
                self.searchPanelView = SearchContainerView(frame: NSMakeRect(0, -topPanelView.frame.height, topPanelView.frame.width, 50))
                
                guard let searchPanelView = self.searchPanelView else {
                    fatalError()
                }
                topPanelView.addSubview(searchPanelView, positioned: .above, relativeTo: topPanelSeparatorView)
                searchPanelView.searchView.change(state: .Focus, false)
                searchPanelView.searchView.searchInteractions = SearchInteractions({ _, _ in
                    
                }, updateSearchState)
                
                searchPanelView.close.set(handler: { _ in
                    toggle()
                }, for: .Click)
            }
            
            
            guard let searchPanelView = self.searchPanelView else {
                fatalError()
            }
            searchPanelView.searchView.isLoading = state.isLoading
            searchPanelView._change(pos: NSZeroPoint, animated: state.animated)
            segmentPanelView._change(pos: NSMakePoint(0, topPanelView.frame.height), animated: state.animated)
        case .None:
            CATransaction.begin()
            segmentPanelView.removeFromSuperview()
            topPanelView.addSubview(segmentPanelView, positioned: .above, relativeTo: topPanelSeparatorView)
            segmentPanelView._change(pos: NSZeroPoint, animated: state.animated)
            if let searchPanelView = self.searchPanelView {
                self.searchPanelView = nil
                searchPanelView._change(pos: NSMakePoint(0, -searchPanelView.frame.height), animated: state.animated, completion: { [weak searchPanelView] completed in
                    searchPanelView?.removeFromSuperview()
                })
            }
            CATransaction.commit()
        }
    }
    
    func changeState(selectState:Bool, animated:Bool) {
        assert(mainView != nil)
        
        self.isSelectionState = selectState
        
    }
    
    var activePanel: View {
        if let searchPanel = self.searchPanelView {
            return searchPanel
        } else {
            return segmentPanelView
        }
    }
    
    override func layout() {
        
        let inset:CGFloat = isSelectionState ? 50 : 0
        topPanelView.frame = NSMakeRect(0, 0, frame.width, 50)
        topPanelView.setCorners(self.corners)
        topPanelSeparatorView.frame = NSMakeRect(0, topPanelView.frame.height - .borderSize, topPanelView.frame.width, .borderSize)
        
        if let searchPanelView = self.searchPanelView {
            searchPanelView.frame = NSMakeRect(0, 0, frame.width, 50)
            segmentPanelView.frame = NSMakeRect(0, topPanelView.frame.height, frame.width, 50)
        } else {
            segmentPanelView.frame = NSMakeRect(0, 0, topPanelView.frame.width, 50)
        }
        mainView?.frame = NSMakeRect(0, topPanelView.isHidden ? 0 : topPanelView.frame.height, frame.width, frame.height - inset - (topPanelView.isHidden ? 0 : topPanelView.frame.height))
        

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
 }
 
 private extension PeerMediaCollectionMode {
    var title: String {
        if self == .members {
            return L10n.peerMediaMembers
        }
        if self == .photoOrVideo {
            return L10n.peerMediaMedia
        }
        if self == .file {
            return L10n.peerMediaFiles
        }
        if self == .webpage {
            return L10n.peerMediaLinks
        }
        if self.tagsValue == .music {
            return L10n.peerMediaAudio
        }
        if self == .voice {
            return L10n.peerMediaVoice
        }
        if self == .commonGroups {
            return L10n.peerMediaCommonGroups
        }
        if self == .gifs {
            return L10n.peerMediaGifs
        }
        return ""
    }
 }
 
 struct PeerMediaExternalSearchData {
    let searchResult: Signal<ExternalSearchMessages?, NoError>
    let loadMore:()->Void
    let initialTags: MessageTags
    init(initialTags: MessageTags, searchResult: Signal<ExternalSearchMessages?, NoError>, loadMore: @escaping()->Void) {
        self.searchResult = searchResult
        self.loadMore = loadMore
        self.initialTags = initialTags
    }
    
    
    var initialMode: PeerMediaCollectionMode {
        if initialTags == .photo || initialTags == .video || initialTags == .photoOrVideo {
            return .photoOrVideo
        } else if initialTags == .gif {
            return .gifs
        } else if initialTags == .file {
            return .file
        } else if initialTags == .voiceOrInstantVideo {
            return .voice
        } else if initialTags == .webPage {
            return .webpage
        } else if initialTags == .music {
            return .music
        }
        preconditionFailure("not supported")
    }
 }
 
 class PeerMediaController: EditableViewController<PeerMediaContainerView>, Notifable {
    
    private let peerId:PeerId
    private var peer:Peer?
    private var peerView: PeerView? {
        didSet {
            if isLoaded(), let peerView = peerView, isProfileIntended {
                let context = self.context
                
                if let cachedData = peerView.cachedData as? CachedChannelData {
                    let onlineMemberCount:Signal<Int32?, NoError>
                    if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: self.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    } else {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(postbox: context.account.postbox, network: context.account.network, accountPeerId: context.peerId, peerId: self.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    }
                    
                    self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                        guard let `self` = self else {
                            return
                        }
                        let result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: count)
                        self.centerBar.status = result.status
                        self.centerBar.text = result.title
                    }))
                } else {
                    let result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: 0)
                    self.centerBar.status = result.status
                    self.centerBar.text = result.title
                }
            }
        }
    }
    
    private let modeValue: ValuePromise<PeerMediaCollectionMode?> = ValuePromise(nil, ignoreRepeated: true)
    private let tabsSignal:Promise<(tabs: [PeerMediaCollectionMode], selected: PeerMediaCollectionMode?, hasLoaded: Bool)> = Promise()
    
    var tabsValue: Signal<PeerMediaTabsData, NoError> {
        return tabsSignal.get() |> map {
            PeerMediaTabsData(collections: $0.tabs, loaded: $0.hasLoaded)
        } |> distinctUntilChanged
    }
    
    private let tabsDisposable = MetaDisposable()
    private var mode:PeerMediaCollectionMode?
    
    private let mediaGrid:PeerMediaPhotosController
    private let gifs: PeerMediaPhotosController
    private let listControllers:[PeerMediaListController]
    private let members: ViewController
    private let commonGroups: ViewController
    
    
    private let tagsList:[PeerMediaCollectionMode] = [.members, .photoOrVideo, .file, .webpage, .music, .voice, .gifs, .commonGroups]
    
    
    private var currentTagListIndex: Int {
        if let mode = self.mode {
            return Int(mode.rawValue)
        } else {
            return 0
        }
    }
    private var interactions:ChatInteraction
    private let messagesActionDisposable:MetaDisposable = MetaDisposable()
    private let loadFwdMessagesDisposable = MetaDisposable()
    private let loadSelectionMessagesDisposable = MetaDisposable()
    private let searchValueDisposable = MetaDisposable()
    private let onlineMemberCountDisposable = MetaDisposable()
    private var searchController: PeerMediaListController?
    private let externalSearchData: PeerMediaExternalSearchData?
    private let toggleDisposable = MetaDisposable()
    private let externalDisposable = MetaDisposable()
    private var currentController: ViewController?
    
    
    
    var currentMainTableView:((TableView?, Bool, Bool)->Void)? = nil {
        didSet {
            if isLoaded() {
                currentMainTableView?(genericView.mainTable, false, false)
            }
        }
    }
    
    private let isProfileIntended: Bool
    
    private let editing: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    override var state:ViewControllerState {
        didSet {
            let newValue = state
            
            genericView.mainTable?.scroll(to: .up(true), completion: { [weak self] _ in
                self?.editing.set(newValue == .Edit)
            })
        }
    }
    
    init(context: AccountContext, peerId:PeerId, isProfileIntended:Bool = false, externalSearchData: PeerMediaExternalSearchData? = nil) {
        self.externalSearchData = externalSearchData
        self.peerId = peerId
        self.isProfileIntended = isProfileIntended
        self.interactions = ChatInteraction(chatLocation: .peer(peerId), context: context)
        self.mediaGrid = PeerMediaPhotosController(context, chatInteraction: interactions, peerId: peerId, tags: .photoOrVideo)
        
        var updateTitle:((ExternalSearchMessages)->Void)? = nil
        
        if let external = externalSearchData {
            modeValue.set(external.initialMode)
            let signal = external.searchResult |> deliverOnMainQueue
            externalDisposable.set(signal.start(next: { result in
                if let result = result {
                    updateTitle?(result)
                }
            }))
        }
        
        var listControllers: [PeerMediaListController] = []
        for _ in tagsList.filter ({ !$0.tagsValue.isEmpty }) {
            listControllers.append(PeerMediaListController(context: context, chatLocation: .peer(peerId), chatInteraction: interactions))
        }
        self.listControllers = listControllers
        
        self.members = PeerMediaGroupPeersController(context: context, peerId: peerId, editing: editing.get())
        self.commonGroups = GroupsInCommonViewController(context: context, peerId: peerId)
        self.gifs = PeerMediaPhotosController(context, chatInteraction: interactions, peerId: peerId, tags: .gif)
        super.init(context)
        
        updateTitle = { [weak self] result in
            if let title = result.title {
                self?.setCenterTitle(title)
            }
        }
    }

    var unableToHide: Bool {
        return self.genericView.activePanel is SearchContainerView || self.state != .Normal
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        interactions.add(observer: self)
        
        if let mode = self.mode {
            self.controller(for: mode).viewDidAppear(animated)
        }
        
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self, self.mode != .commonGroups, self.externalSearchData == nil else {
                return .rejected
            }
            if self.mode == .members {
                self.searchGroupUsers()
                return .invoked
            }
            self.listControllers[self.currentTagListIndex].toggleSearch()
            return .invoked
        }, with: self, for: .F, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {
                return .rejected
            }
            if self.genericView.searchPanelView != nil {
                return .rejected
            }
            //  self.genericView.segmentPanelView.segmentControl.selectNext(animated: true)
            return .invoked
        }, with: self, for: .Tab)
        
        guard let navigationController = self.navigationController, isProfileIntended else {
            return
        }
        
        navigationController.swapNavigationBar(leftView: nil, centerView: self.centerBarView, rightView: nil, animation: .crossfade)
        navigationController.swapNavigationBar(leftView: nil, centerView: nil, rightView: self.rightBarView, animation: .none)

    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        interactions.remove(observer: self)
        
        if let mode = mode {
            let controller = self.controller(for: mode)
            controller.viewDidDisappear(animated)
            if let controller = controller as? PeerMediaSearchable {
                controller.setSearchValue(.single(.init(state: .None, request: nil)))
            }
        }
        
        if let navigationController = navigationController, isProfileIntended {
            navigationController.swapNavigationBar(leftView: nil, centerView: navigationController.controller.centerBarView, rightView: nil, animation: .crossfade)
            navigationController.swapNavigationBar(leftView: nil, centerView: nil, rightView: navigationController.controller.rightBarView, animation: .none)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let mode = mode {
            let controller = self.controller(for: mode)
            controller.viewWillAppear(animated)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
        
        if let mode = mode {
            let controller = self.controller(for: mode)
            controller.viewWillDisappear(animated)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            
            let context = self.context
            if value.selectionState != oldValue.selectionState {
                if let selectionState = value.selectionState {
                    let ids = Array(selectionState.selectedIds)
                    loadSelectionMessagesDisposable.set((context.account.postbox.messagesAtIds(ids) |> deliverOnMainQueue).start( next:{ [weak self] messages in
                        var canDelete:Bool = !ids.isEmpty
                        var canForward:Bool = !ids.isEmpty
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account) {
                                canDelete = false
                            }
                            if !canForwardMessage(message, account: context.account) {
                                canForward = false
                            }
                        }
                        self?.interactions.update({$0.withUpdatedBasicActions((canDelete, canForward))})
                    }))
                } else {
                    interactions.update({$0.withUpdatedBasicActions((false, false))})
                }
            }
            
            if (value.state == .selecting) != (oldValue.state == .selecting) {
                self.state = value.state == .selecting ? .Edit : .Normal
                
                genericView.changeState(selectState: value.state == .selecting && self.mode != .members, animated: animated)
            }
            
        }
    }
    
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? PeerMediaController {
            return self == other
        }
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.updateInteraction(interactions)
        
        if externalSearchData != nil {
            centerBar.updateSearchVisibility(false, animated: false)
        }

        
        let tagsList = self.tagsList
        
        let context = self.context
        let peerId = self.peerId
        
        
        let membersTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let commonGroupsTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        
        membersTab = context.account.postbox.peerView(id: peerId) |> map { view -> (exist: Bool, loaded: Bool) in
            if let cachedData = view.cachedData as? CachedGroupData {
                return (exist: Int(cachedData.participants?.participants.count ?? 0 ) > minumimUsersBlock, loaded: true)
            } else if let cachedData = view.cachedData as? CachedChannelData {
                if let peer = peerViewMainPeer(view), peer.isSupergroup {
                    return (exist: Int32(cachedData.participantsSummary.memberCount ?? 0) > minumimUsersBlock, loaded: true)
                } else {
                    return (exist: false, loaded: true)
                }
            } else {
                return (exist: false, loaded: true)
            }
        } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
            return (tag: .members, exists: data.exist, hasLoaded: data.loaded)
        }
        
        commonGroupsTab = context.account.postbox.peerView(id: peerId) |> map { view -> (exist: Bool, loaded: Bool) in
            if let cachedData = view.cachedData as? CachedUserData {
                return (exist: cachedData.commonGroupCount > 0, loaded: true)
            } else {
                if view.peerId.namespace == Namespaces.Peer.CloudUser || view.peerId.namespace == Namespaces.Peer.SecretChat {
                    return (exist: false, loaded: false)
                }
                return (exist: false, loaded: true)
            }
        } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
            return (tag: .commonGroups, exists: data.exist, hasLoaded: data.loaded)
        }
        
        
        let tabItems: [Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>] = self.tagsList.filter { !$0.tagsValue.isEmpty }.map { tags -> Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError> in
            return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peerId), count: 3, tagMask: tags.tagsValue)
            |> map { (view, _, _) -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                let hasLoaded = view.entries.count >= 3 || (!view.isLoading)
                return (tag: tags, exists: !view.entries.isEmpty, hasLoaded: hasLoaded)
            }
            
        }
        
        let mergedTabs = combineLatest(membersTab, combineLatest(tabItems), commonGroupsTab) |> map { members, general, commonGroups -> [(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool)] in
            var general = general
            general.insert(members, at: 0)
            general.append(commonGroups)
            return general
        }
        
        let tabSignal = combineLatest(queue: .mainQueue(), mergedTabs, modeValue.get())
        |> map { tabs, selected -> (tabs: [PeerMediaCollectionMode], selected: PeerMediaCollectionMode?, hasLoaded: Bool) in
            var selectedValue = selected
            if selected == nil || !tabs.contains(where: { $0.exists && $0.tag == selected }) {
                if let selected = selected {
                    let index = tagsList.firstIndex(of: selected)!
                    var perhapsBest: PeerMediaCollectionMode?
                    for i in stride(from: index, to: -1, by: -1) {
                        if tabs.contains(where: { $0.exists && $0.tag == tagsList[i] }) {
                            perhapsBest = tagsList[i]
                            break
                        }
                    }
                    selectedValue = perhapsBest ?? tabs.filter { $0.exists }.last?.tag ?? selected
                } else {
                    selectedValue = tabs.filter { $0.exists }.first?.tag
                }
                
            }
            return (tabs: tabs.filter { $0.exists }.map { $0.tag }, selected: selectedValue, hasLoaded: tabs.reduce(true, { $0 && $1.hasLoaded }))
        }
        
        tabsSignal.set(tabSignal)
        
        let data: Signal<(tabs: [PeerMediaCollectionMode], selected: PeerMediaCollectionMode?, hasLoaded: Bool), NoError> = tabsSignal.get() |> deliverOnMainQueue |> mapToSignal { [weak self] data in
            guard let `self` = self else {
                return .complete()
            }
            if let selected = data.selected {
                switch selected {
                case .members:
                    if !self.members.isLoaded() {
                        self.members.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.members.ready.get() |> map { ready in
                        return data
                    }
                case .commonGroups:
                    if !self.commonGroups.isLoaded() {
                        self.commonGroups.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.commonGroups.ready.get() |> map { ready in
                        return data
                    }
                case .photoOrVideo:
                    if !self.mediaGrid.isLoaded() {
                        if let externalSearchData = self.externalSearchData {
                            self.mediaGrid.setExternalSearch(externalSearchData.searchResult, externalSearchData.loadMore)
                        }
                        self.mediaGrid.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.mediaGrid.ready.get() |> map { _ in
                        return data
                    }
                case .gifs:
                    if !self.gifs.isLoaded() {
                        if let externalSearchData = self.externalSearchData {
                            self.gifs.setExternalSearch(externalSearchData.searchResult, externalSearchData.loadMore)
                        }
                        self.gifs.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.gifs.ready.get() |> map { ready in
                        return data
                    }
                default:
                    if !self.listControllers[Int(selected.rawValue)].isLoaded() {
                        if let externalSearchData = self.externalSearchData {
                            self.listControllers[Int(selected.rawValue)].setExternalSearch(externalSearchData.searchResult, externalSearchData.loadMore)
                        }
                        self.listControllers[Int(selected.rawValue)].loadViewIfNeeded(self.genericView.view.bounds)
                        self.listControllers[Int(selected.rawValue)].load(with: selected.tagsValue)
                    }
                    return self.listControllers[Int(selected.rawValue)].ready.get() |> map { _ in
                        return data
                    }
                }
            } else {
                return .single(data)
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs -> Bool in
            if lhs.tabs != rhs.tabs {
                return false
            }
            if lhs.hasLoaded != rhs.hasLoaded {
                return false
            }
            if lhs.selected != rhs.selected {
                return false
            }
            return true
        })
        
        let ready = data |> map { _ in return true }
        
        genericView.segmentPanelView.segmentControl.didChangeSelectedItem = { [weak self] item in
            let newMode = PeerMediaCollectionMode(rawValue: item.uniqueId)!
            
            if newMode == self?.mode, let mainTable = self?.genericView.mainTable {
                self?.currentMainTableView?(mainTable, true, true)
            }
            self?.modeValue.set(newMode)
        }
        
        
        interactions.forwardMessages = { messageIds in
            showModal(with: ShareModalController(ForwardMessagesObject(context, messageIds: messageIds)), for: mainWindow)
        }
        
        interactions.focusMessageId = { [weak self] _, focusMessageId, animated in
            if let strongSelf = self {
                strongSelf.navigationController?.push(ChatController(context: context, chatLocation: .peer(strongSelf.peerId), messageId: focusMessageId))
            }
        }
        
        interactions.inlineAudioPlayer = { [weak self] controller in
            if let navigation = self?.navigationController, let `self` = self {
                if let header = navigation.header {
                    header.show(true)
                    if let view = header.view as? InlineAudioPlayerView {
                        let tableView = (navigation.first { $0 is ChatController} as? ChatController)?.genericView.tableView
                        view.update(with: controller, context: context, tableView: tableView, supportTableView: self.currentTable)
                    }
                }
            }
        }
        
        interactions.openInfo = { [weak self] (peerId, toChat, postId, action) in
            if let strongSelf = self {
                if toChat {
                    strongSelf.navigationController?.push(ChatController(context: context, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
                } else {
                    strongSelf.navigationController?.push(PeerInfoController(context: context, peerId: peerId))
                }
            }
        }
        
        interactions.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.peer {
                let channelAdmin:Signal<[ChannelParticipant]?, NoError> = peer.isSupergroup ? channelAdmins(account: context.account, peerId: strongSelf.interactions.peerId)
                    |> `catch` {_ in .complete()} |> map { admins -> [ChannelParticipant]? in
                        return admins.map({$0.participant})
                    } : .single(nil)
                
                
                self?.messagesActionDisposable.set(combineLatest(context.account.postbox.messagesAtIds(messageIds) |> deliverOnMainQueue, channelAdmin |> deliverOnMainQueue).start( next:{ [weak strongSelf] messages, admins in
                    if let strongSelf = strongSelf {
                        var canDelete:Bool = true
                        var canDeleteForEveryone = true
                        var otherCounter:Int32 = 0
                        var _mustDeleteForEveryoneMessage: Bool = true
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account) {
                                canDelete = false
                            }
                            if !mustDeleteForEveryoneMessage(message) {
                                _mustDeleteForEveryoneMessage = false
                            }
                            if !canDeleteForEveryoneMessage(message, context: context) {
                                canDeleteForEveryone = false
                            } else {
                                if message.effectiveAuthor?.id != context.peerId && !(context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser)  {
                                    if let peer = message.peers[message.id.peerId] as? TelegramGroup {
                                        inner: switch peer.role {
                                        case .member:
                                            otherCounter += 1
                                        default:
                                            break inner
                                        }
                                    } else {
                                        otherCounter += 1
                                    }
                                }
                            }
                        }
                        
                        if otherCounter > 0 || peer.id == context.peerId {
                            canDeleteForEveryone = false
                        }
                        if messages.isEmpty {
                            strongSelf.interactions.update({$0.withoutSelectionState()})
                            return
                        }
                        
                        if canDelete {
                            let isAdmin = admins?.filter({$0.peerId == messages[0].author?.id}).first != nil
                            if mustManageDeleteMessages(messages, for: peer, account: strongSelf.context.account), let memberId = messages[0].author?.id, !isAdmin {
                                
                                let options:[ModalOptionSet] = [ModalOptionSet(title: L10n.supergroupDeleteRestrictionDeleteMessage, selected: true, editable: true),
                                                                ModalOptionSet(title: L10n.supergroupDeleteRestrictionBanUser, selected: false, editable: true),
                                                                ModalOptionSet(title: L10n.supergroupDeleteRestrictionReportSpam, selected: false, editable: true),
                                                                ModalOptionSet(title: L10n.supergroupDeleteRestrictionDeleteAllMessages, selected: false, editable: true)]
                                showModal(with: ModalOptionSetController(context: context, options: options, actionText: (L10n.modalOK, theme.colors.accent), title: L10n.supergroupDeleteRestrictionTitle, result: { [weak strongSelf] result in
                                    
                                    var signals:[Signal<Void, NoError>] = []
                                    if result[0] == .selected {
                                        signals.append(deleteMessagesInteractively(account: context.account, messageIds: messages.map {$0.id}, type: .forEveryone))
                                    }
                                    if result[1] == .selected {
                                        signals.append(context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(account: context.account, peerId: peer.id, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)))
                                    }
                                    if result[2] == .selected {
                                        signals.append(reportSupergroupPeer(account: context.account, peerId: memberId, memberId: memberId, messageIds: messageIds))
                                    }
                                    if result[3] == .selected {
                                        signals.append(clearAuthorHistory(account: context.account, peerId: peer.id, memberId: memberId))
                                    }
                                    
                                    _ = showModalProgress(signal: combineLatest(signals), for: context.window).start()
                                    strongSelf?.interactions.update({$0.withoutSelectionState()})
                                    
                                }), for: context.window)
                            } else {
                                let thrid:String? = (canDeleteForEveryone ? peer.isUser ? L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : L10n.chatConfirmDeleteMessagesForEveryone : nil)
                                
                                modernConfirm(for: context.window, account: context.account, peerId: nil, header: thrid == nil ? L10n.chatConfirmActionUndonable : L10n.chatConfirmDeleteMessagesCountable(messages.count), information: thrid == nil ? _mustDeleteForEveryoneMessage ? L10n.chatConfirmDeleteForEveryoneCountable(messages.count) : L10n.chatConfirmDeleteMessagesCountable(messages.count) : nil, okTitle: L10n.confirmDelete, thridTitle: thrid, successHandler: { [weak strongSelf] result in
                                    
                                    guard let `strongSelf` = strongSelf else {
                                        return
                                    }
                                    let type:InteractiveMessagesDeletionType
                                    switch result {
                                    case .basic:
                                        type = .forLocalPeer
                                    case .thrid:
                                        type = .forEveryone
                                    }
                                    _ = deleteMessagesInteractively(account: strongSelf.context.account, messageIds: messageIds, type: type).start()
                                    strongSelf.interactions.update({$0.withoutSelectionState()})
                                })
                            }
                        }
                    }
                }))
            }
        }
        
        let peerSignal = context.account.viewTracker.peerView(peerId) |> deliverOnMainQueue |> beforeNext({ [weak self] peerView in
            self?.peer = peerView.peers[peerView.peerId]
            self?.peerView = peerView
        }) |> map { view -> Bool in
            return true
        }
        
        let combined = combineLatest( [peerSignal |> take(1), ready, self.tabsSignal.get() |> map { $0.hasLoaded }] ) |> map { result -> Bool in
            return result[0] && result[1] && result[2]
        }
        
        self.ready.set(combined |> deliverOnMainQueue)
        
    
        
        var firstTabAppear = true
        tabsDisposable.set((data |> deliverOnMainQueue).start(next: { [weak self] tabs, selected, hasLoaded in
            var items:[ScrollableSegmentItem] = []
            if hasLoaded, let `self` = self {
                let insets = NSEdgeInsets(left: 10, right: 10, bottom: 2)
                let segmentTheme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.accent, textFont: .normal(.title))
                for (i, tab)  in tabs.enumerated() {
                    items.append(ScrollableSegmentItem(title: tab.title, index: i, uniqueId: tab.rawValue, selected: selected == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: nil))
                }
                self.genericView.segmentPanelView.segmentControl.updateItems(items, animated: !firstTabAppear)
                if let selected = selected {
                    self.toggle(with: selected, animated: !firstTabAppear)
                }
                
                firstTabAppear = false
                
                if tabs.isEmpty, self.isProfileIntended {
                    if self.genericView.superview != nil {
                        self.viewWillDisappear(true)
                        self.genericView.removeFromSuperview()
                        self.viewDidDisappear(true)
                    }
                }
            }
        }))
    }
    
    
    private var currentTable: TableView? {
        if self.mode == .photoOrVideo || self.mode == .members {
            return nil
        } else {
            return self.listControllers[currentTagListIndex].genericView
        }
    }
    
    private func applyReadyController(mode:PeerMediaCollectionMode, animated:Bool) {
        genericView.mainTable?.updatedItems = nil
        let oldMode = self.mode
        self.mode = mode
        let previous = self.currentController
        
        let controller = self.controller(for: mode)
        
        self.currentController = controller
        controller.viewWillAppear(animated)
        previous?.viewWillDisappear(animated)
        controller.view.frame = self.genericView.view.bounds
        let animation: PeerMediaAnimationDirection?
        
        if animated, let oldMode = oldMode {
            if oldMode.rawValue > mode.rawValue {
                animation = .rightToLeft
            } else {
                animation = .leftToRight
            }
        } else {
            animation = nil
        }
        
        genericView.updateMainView(with: controller.view, animated: animation)
        controller.viewDidAppear(animated)
        previous?.viewDidDisappear(animated)
        searchValueDisposable.set(nil)
        
        
        centerBar.updateSearchVisibility(mode != .commonGroups && mode != .voice && externalSearchData == nil)
        
        
        if let controller = controller as? PeerMediaSearchable {
            
            if let externalSearchData = self.externalSearchData {
                controller.setExternalSearch(externalSearchData.searchResult, externalSearchData.loadMore)
            } else {
                searchValueDisposable.set(controller.mediaSearchValue.start(next: { [weak self, weak controller] state in
                    self?.genericView.updateSearchState(state, updateSearchState: { searchState in
                        controller?.setSearchValue(.single(searchState))
                    }, toggle: {
                        controller?.toggleSearch()
                    })
                }))
            }
        }
        
        var firstUpdate: Bool = true
        genericView.mainTable?.updatedItems = { [weak self] items in
            let filter = items.filter {
                !($0 is PeerMediaEmptyRowItem) && !($0.className == "Telegram.GeneralRowItem") && !($0 is SearchEmptyRowItem)
            }
            self?.genericView.updateCorners(filter.isEmpty ? .all : [.topLeft, .topRight], animated: !firstUpdate)
            firstUpdate = false
        }
        self.currentMainTableView?(genericView.mainTable, animated, previous != controller && genericView.segmentPanelView.segmentControl.contains(oldMode?.rawValue ?? -3))
    }
    
    func controller(for mode: PeerMediaCollectionMode) -> ViewController {
        switch mode {
        case .photoOrVideo:
            return self.mediaGrid
        case .members:
            return self.members
        case .commonGroups:
            return self.commonGroups
        case .gifs:
            return self.gifs
        default:
            return self.listControllers[Int(mode.rawValue)]
        }
    }
    
    private func toggle(with mode:PeerMediaCollectionMode, animated:Bool = false) {
        let isUpdated = self.mode != mode
        if isUpdated {
            let controller: ViewController = self.controller(for: mode)

            let ready = controller.ready.get() |> take(1)
            
            toggleDisposable.set(ready.start(next: { [weak self] _ in
                self?.applyReadyController(mode: mode, animated: animated)
            }))
        } else {
            self.currentMainTableView?(genericView.mainTable, animated, false)
        }
        self.modeValue.set(mode)
    }
    
    deinit {
        messagesActionDisposable.dispose()
        loadFwdMessagesDisposable.dispose()
        loadSelectionMessagesDisposable.dispose()
        tabsDisposable.dispose()
        toggleDisposable.dispose()
        onlineMemberCountDisposable.dispose()
        externalDisposable.dispose()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        
        for controller in self.listControllers {
            if controller.isLoaded() {
                controller.updateLocalizationAndTheme(theme: theme)
            }
        }
        
    }
    
    override public func update(with state:ViewControllerState) -> Void {
        super.update(with:state)
        interactions.update({state == .Normal ? $0.withoutSelectionState() : $0.withSelectionState()})
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.searchPanelView != nil {
            self.listControllers[self.currentTagListIndex].toggleSearch()
            return .invoked
        } else if interactions.presentation.state == .selecting {
            interactions.update { $0.withoutSelectionState() }
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    private var centerBar: SearchTitleBarView {
        return centerBarView as! SearchTitleBarView
    }
    
    private func searchGroupUsers() {
        _ = (selectModalPeers(context: context, title: L10n.selectPeersTitleSearchMembers, behavior: peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior.init(peerId: peerId, limit: 1, settings: []) : SelectChannelMembersBehavior(peerId: peerId, limit: 1, settings: [])) |> deliverOnMainQueue |> map {$0.first}).start(next: { [weak self] peerId in
            if let peerId = peerId, let context = self?.context {
                context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
            }
        })
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return SearchTitleBarView(controller: self, title:.initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title)), handler: { [weak self] in
            guard let `self` = self else {
                return
            }
            if let mode = self.mode {
                switch mode {
                case .members:
                    self.searchGroupUsers()
                case .commonGroups:
                    break
                case .photoOrVideo:
                    (self.controller(for: mode) as? PeerMediaPhotosController)?.toggleSearch()
                default:
                    (self.controller(for: mode) as? PeerMediaListController)?.toggleSearch()
                }
            }
        })
    }
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchPanelView?.searchView.input
    }
    
    override var defaultBarTitle: String {
        return super.defaultBarTitle
    }
    
    override func backSettings() -> (String, CGImage?) {
        return super.backSettings()
    }
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
    }
    
    
    
    override func initializer() -> PeerMediaContainerView {
        return PeerMediaContainerView(frame: initializationRect, isSegmentHidden: self.externalSearchData != nil)
    }
    
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> () -> Void {
        for mediaList in listControllers {
            if mediaList.view.superview != nil {
                return mediaList.navigationHeaderDidNoticeAnimation(current, previous, animated)
            }
        }
        
        if mediaGrid.view.superview != nil {
            return mediaGrid.navigationHeaderDidNoticeAnimation(current, previous, animated)
        }
        return {}
    }
    
 }
 
 
 

