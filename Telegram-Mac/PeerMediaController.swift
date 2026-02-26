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
 
 import SwiftSignalKit
 import Postbox
 
 
 
 
protocol PeerMediaSearchable : AnyObject {
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
 private let sectionOffset: CGFloat = 20
 
 final class PeerMediaContainerView : View {
    
    private let actionsPanelView:MessageActionsPanelView = MessageActionsPanelView(frame: NSMakeRect(0,0,0, 50))
    private let separator:View = View()
    
    fileprivate let view: PeerMediaControllerView
    fileprivate var emptyView: PeerMediaEmptyRowView?
    fileprivate var emptyItem: PeerMediaEmptyRowItem?
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
        emptyView?.frame = bounds
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
        } else if let view = self.view.mainView as? StoryMediaView {
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
     
     func updateEmpty(_ isEmpty: Bool, animated: Bool) {
         self.topPanelView.isHidden = isEmpty
         if isEmpty {
             let current: PeerMediaEmptyRowView
             if let view = self.emptyView {
                 current = view
             } else {
                 current = .init(frame: self.bounds)
                 self.emptyView = current
                 self.addSubview(current)
                 if animated {
                     self.emptyView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                 }
             }
             
             let item = self.emptyItem ?? PeerMediaEmptyRowItem(bounds.size, tags: nil)
             self.emptyItem = item
             current.set(item: item, animated: animated)
         } else if let view = emptyView {
             performSubviewRemoval(view, animated: animated)
             self.emptyView = nil
             self.emptyItem = nil
         }
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
     fileprivate var topPanelView: NSView {
         return self.view.topPanelView
     }
    fileprivate var searchPanelView: SearchContainerView? {
        return self.view.searchPanelView
    }
    
    func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
        view.updateCorners(corners, animated: animated)
    }
 }
 
 class PeerMediaControllerView : View {
    
    fileprivate let topPanelView = GeneralRowContainerView(frame: .zero)
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
        } else if let view = self.mainView as? StoryMediaView {
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
     func title(_ peer: Peer?) -> String {
        if self == .members {
            return strings().peerMediaMembers
        }
        if self == .photoOrVideo {
            return strings().peerMediaMedia
        }
        if self == .file {
            return strings().peerMediaFiles
        }
        if self == .webpage {
            return strings().peerMediaLinks
        }
        if self.tagsValue == .music {
            return strings().peerMediaMusic
        }
        if self == .voice {
            return strings().peerMediaVoice
        }
        if self == .commonGroups {
            return strings().peerMediaCommonGroups
        }
         if self == .similarBots {
            return strings().peerMediaSimilarBots
        }
        if self == .similarChannels {
            return strings().peerMediaSimilarChannels
        }
        if self == .gifs {
            return strings().peerMediaGifs
        }
         if self == .gifts {
             return strings().peerMediaGifts
         }
        if self == .stories {
            if peer?.isBot == true {
                return strings().peerMediaPreview
            } else if peer is TelegramChannel {
                return strings().peerMediaPosts
            } else {
                return strings().peerMediaStories
            }
        }
        if self == .archiveStories {
             return strings().peerMediaArchivePosts
        }
        if self == .savedMessages {
            return strings().peerMediaSavedMessages
        }
        if self == .saved {
            return strings().peerMediaSaved
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
                
                if let cachedData = peerView.cachedData as? CachedChannelData, let peer = peerViewMainPeer(peerView), peer.isGroup || peer.isSupergroup || peer.isGigagroup {
                    let onlineMemberCount:Signal<Int32?, NoError>
                    if (cachedData.participantsSummary.memberCount ?? 0) > 200 {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnline(peerId: self.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    } else {
                        onlineMemberCount = context.peerChannelMemberCategoriesContextsManager.recentOnlineSmall(peerId: self.peerId)  |> map(Optional.init) |> deliverOnMainQueue
                    }
                    self.onlineMemberCountDisposable.set(onlineMemberCount.start(next: { [weak self] count in
                        guard let `self` = self else {
                            return
                        }
                        let result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: count)
                        self.centerBar.text = result.title
                        if self.mode == .members {
                            self.centerBar.status = result.status
                        }
                    }))
                } else {
                    let result = stringStatus(for: peerView, context: context, theme: PeerStatusStringTheme(titleFont: .medium(.title)), onlineMemberCount: 0)
                    self.centerBar.text = result.title
                    if self.mode == .members {
                        self.centerBar.status = result.status
                    }
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
    private let stories: StoryMediaController
    private let archiveStories: StoryMediaController?
    private let saved: InputDataController
    private var savedMessages: InputDataController?
    private var gifts: ViewController?

    private let listControllers:[PeerMediaListController]
    private let members: ViewController
    private let commonGroups: ViewController
    private let similarChannels: ViewController
    private let similarBots: ViewController

     private let statusDisposable = MetaDisposable()
    
     private let tagsList:[PeerMediaCollectionMode] = [.members, .stories, .archiveStories, .photoOrVideo, .saved, .file, .webpage, .music, .voice, .gifs, .commonGroups, .similarChannels, .similarBots, .gifts]
    
    
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
     
    private let storyListContext: StoryListContext
    private let archiveStoryListContext: StoryListContext?
    private let threadInfo: ThreadInfo?
        
    var currentMainTableView:((TableView?, Bool, Bool)->Void)? = nil {
        didSet {
            if isLoaded() {
                currentMainTableView?(genericView.mainTable, initialMode != nil, initialMode != nil)
            }
        }
    }
    
    private let isProfileIntended: Bool
     private var initialMode: PeerMediaCollectionMode?
    
    private let editing: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
    override var state:ViewControllerState {
        didSet {
            let newValue = state
            
            if newValue != oldValue {
                stories.toggleSelection()
                archiveStories?.toggleSelection()
            }
            
            genericView.mainTable?.scroll(to: .up(true), completion: { [weak self] _ in
                self?.editing.set(newValue == .Edit)
            })
        }
    }
    
     init(context: AccountContext, peerId:PeerId, threadInfo: ThreadInfo? = nil, isProfileIntended:Bool = false, externalSearchData: PeerMediaExternalSearchData? = nil, isBot: Bool, mode: PeerMediaCollectionMode? = nil, starGiftsProfile: ProfileGiftsContext? = nil) {
        self.externalSearchData = externalSearchData
        self.peerId = peerId
        self.mode = mode
        self.threadInfo = threadInfo
        self.isProfileIntended = isProfileIntended
        self.initialMode = mode
        if peerId == context.peerId, !isProfileIntended {
            self.savedMessages = SavedPeersController(context: context)
        } else {
            self.savedMessages = nil
        }
         if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel, !isBot {
             self.gifts = PeerMediaGiftsController(context: context, peerId: peerId, starGiftsProfile: starGiftsProfile)
        } else {
            self.gifts = nil
        }
        self.interactions = ChatInteraction(chatLocation: .peer(peerId), context: context)
        self.mediaGrid = PeerMediaPhotosController(context, chatInteraction: interactions, threadInfo: threadInfo, peerId: peerId, tags: .photoOrVideo)
         if isBot {
             self.storyListContext = BotPreviewStoryListContext(account: context.account, engine: context.engine, peerId: peerId, language: nil, assumeEmpty: false)
         } else {
             self.storyListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false, folderId: nil)
         }
         
        if peerId == context.peerId, threadInfo == nil, isProfileIntended {
            let archiveStoryListContext = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: true, folderId: nil)
            self.archiveStoryListContext = archiveStoryListContext
            self.archiveStories = StoryMediaController(context: context, peerId: peerId, listContext: archiveStoryListContext, isArchived: true)
        } else {
            self.archiveStoryListContext = nil
            self.archiveStories = nil
        }
        self.saved = PeerMediaSavedMessagesController(context: context, peerId: peerId)
         
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
            listControllers.append(PeerMediaListController(context: context, peerId: peerId, threadInfo: threadInfo, chatInteraction: interactions))
        }
        self.listControllers = listControllers
        
        self.members = PeerMediaGroupPeersController(context: context, peerId: peerId, editing: editing.get())
        self.commonGroups = GroupsInCommonViewController(context: context, peerId: peerId)
        self.gifs = PeerMediaPhotosController(context, chatInteraction: interactions, threadInfo: threadInfo, peerId: peerId, tags: .gif)
        self.stories = StoryMediaController(context: context, peerId: peerId, listContext: storyListContext)
        self.similarChannels = SimilarChannelsController(context: context, peerId: peerId, recommendedChannels: nil)
        self.similarBots = SimilarBotsController(context: context, peerId: peerId, recommendedBots: nil)

         
        super.init(context)
         
         self.stories.parentToggleSelection = { [weak self] in
             self?.changeState()
         }
         
         self.archiveStories?.parentToggleSelection = { [weak self] in
             self?.changeState()
         }
        
        updateTitle = { [weak self] result in
            if let title = result.title {
                self?.setCenterTitle(title)
            }
        }
         
        stories.parentController = self
        archiveStories?.parentController = self
    }

    var unableToHide: Bool {
        return self.genericView.activePanel is SearchContainerView || self.state != .Normal || !onTheTop
    }
     
     var hasSearch: Bool {
         switch mode {
         case .commonGroups:
             return false
         case .stories, .archiveStories, .gifts:
             return false
         default:
             return self.externalSearchData == nil
         }
     }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        interactions.add(observer: self)
        
        if let mode = self.mode {
            self.controller(for: mode).viewDidAppear(animated)
        }
        
        
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
            guard let `self` = self, !self.hasSearch else {
                return .rejected
            }
            if self.mode == .members {
                self.searchGroupUsers()
                return .invoked
            }
            if let mode = self.mode {
                (self.controller(for: mode) as? PeerMediaSearchable)?.toggleSearch()
            }
            return .invoked
        }, with: self, for: .F, modifierFlags: [.command])
        
        window?.set(handler: { [weak self] _ -> KeyHandlerResult in
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
        if let controller = navigationController.controller as? PeerInfoController {
            controller.swapNavigationBar(leftView: self.leftBarView, centerView: self.centerBarView, rightView: self.rightBarView, animation: .crossfade)
            
        }

    }
     
     private var editButton:ImageButton? = nil
     private var doneButton:TextButton? = nil
     
     override func requestUpdateRightBar() {
         super.requestUpdateRightBar()
         editButton?.style = navigationButtonStyle
         editButton?.set(image: theme.icons.chatActions, for: .Normal)
         editButton?.set(image: theme.icons.chatActionsActive, for: .Highlight)

         
         editButton?.setFrameSize(70, 50)
         editButton?.center()
         doneButton?.set(color: theme.colors.accent, for: .Normal)
         doneButton?.style = navigationButtonStyle
     }
     
     
     func setMode(_ mode: PeerMediaCollectionMode) {
         self.toggle(with: mode, animated: true)
     }
     
     override func getRightBarViewOnce() -> BarView {
         let back = BarView(70, controller: self)
         let editButton = ImageButton()
         back.addSubview(editButton)
         
         self.editButton = editButton
 //
         let doneButton = TextButton()
         doneButton.set(font: .medium(.text), for: .Normal)
         doneButton.set(text: strings().navigationDone, for: .Normal)
         
         
         _ = doneButton.sizeToFit()
         back.addSubview(doneButton)
         doneButton.center()
         
         self.doneButton = doneButton

         
         doneButton.set(handler: { [weak self] _ in
             self?.changeState()
         }, for: .Click)
         
         doneButton.isHidden = true
         
         
         let context = self.context
         editButton.contextMenu = { [weak self] in
             
             
             var items:[ContextMenuItem] = []
             
             if let menuItems = self?.currentController?.menuItems(), !menuItems.isEmpty {
                 items.append(ContextSeparatorItem())
                 items.append(contentsOf: menuItems)
             } else {
                 items.append(ContextMenuItem(strings().chatContextEdit1, handler: { [weak self] in
                     self?.changeState()
                 }, itemImage: MenuAnimation.menu_edit.value))
             }
             
            
             let menu = ContextMenu(betterInside: true)
             
             for item in items {
                 menu.addItem(item)
             }
             
             return menu
         }

         requestUpdateRightBar()
         return back
     }

     private func showRightControls() {
         switch state {
         case .Normal:
             break
         case .Edit:
             self.changeState()
         case .Some:
             break
         }
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
            navigationController.controller.swapNavigationBar(leftView: navigationController.controller.leftBarView, centerView: navigationController.controller.centerBarView, rightView: navigationController.controller.rightBarView, animation: .crossfade)
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
                        if let interactions = self?.interactions {
                            for message in messages {
                                if !canDeleteMessage(message, account: context.account, chatLocation: interactions.chatLocation, mode: .history) {
                                    canDelete = false
                                }
                                if !canForwardMessage(message, chatInteraction: interactions) {
                                    canForward = false
                                }
                            }
                            interactions.update({$0.withUpdatedBasicActions((canDelete, canForward))})
                        }
                       
                    }))
                } else {
                    interactions.update({$0.withUpdatedBasicActions((false, false))})
                }
            }
            
            if (value.state == .selecting) != (oldValue.state == .selecting) {
                self.state = value.state == .selecting ? .Edit : .Normal
                
                doneButton?.isHidden = value.state != .selecting
                editButton?.isHidden = value.state == .selecting

                genericView.changeState(selectState: value.state == .selecting && self.mode != .members && self.mode != .stories && self.mode != .archiveStories, animated: animated)
            }
            
        }
    }
    
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? PeerMediaController {
            return self == other
        }
        return false
    }
     
     override func readyOnce() {
         let didSetReady = self.didSetReady
         super.readyOnce()
         
         if !didSetReady, let mode = initialMode {
             self.applyReadyController(mode: mode, animated: false)
         }
         
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
        let threadInfo = self.threadInfo
        let isProfileIntended = self.isProfileIntended
        let initialMode = self.initialMode
        
        let membersTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let storiesTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let archiveStoriesTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let commonGroupsTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let similarChannels:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let similarBots:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let savedMessagesTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let giftsTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>
        let savedTab:Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>

        
        giftsTab = context.account.postbox.peerView(id: peerId) |> map { view -> (exist: Bool, loaded: Bool) in
            if let cachedData = view.cachedData as? CachedUserData {
                if let starGiftsCount = cachedData.starGiftsCount, starGiftsCount > 0 {
                    return (exist: true, loaded: true)
                }
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let starGiftsCount = cachedData.starGiftsCount, starGiftsCount > 0 {
                    return (exist: true, loaded: true)
                }
            }
            return (exist: false, loaded: true)
        } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
            return (tag: .gifts, exists: data.exist, hasLoaded: data.loaded)
        }

        
        membersTab = context.account.postbox.peerView(id: peerId) |> map { view -> (exist: Bool, loaded: Bool) in
            if threadInfo != nil {
                return (exist: false, loaded: true)
            }
            if (view.cachedData as? CachedGroupData) != nil {
                return (exist: true, loaded: true)
            } else if let _ = view.cachedData as? CachedChannelData {
                if let peer = peerViewMainPeer(view), peer.isSupergroup || peer.isGigagroup, !peer.isMonoForum {
                    return (exist: true, loaded: true)
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
            if threadInfo != nil {
                return (exist: false, loaded: true)
            }
            if view.peerId.namespace == Namespaces.Peer.SecretChat {
                return (exist: false, loaded: false)
            }
            if let cachedData = view.cachedData as? CachedUserData {
                return (exist: cachedData.commonGroupCount > 0, loaded: true)
            } else {
                return (exist: false, loaded: true)
            }
        } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
            return (tag: .commonGroups, exists: data.exist, hasLoaded: data.loaded)
        }
        
        if threadInfo == nil, peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel {
            storiesTab = storyListContext.state |> map { state -> (exist: Bool, loaded: Bool) in
                return (exist: state.totalCount > 0, loaded: true)
            } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                return (tag: .stories, exists: data.exist, hasLoaded: data.loaded)
            }
        } else {
            storiesTab = .single((tag: .stories, exists: false, hasLoaded: true))
        }
        
        if let archiveStoryListContext {
            archiveStoriesTab = archiveStoryListContext.state |> map { state -> (exist: Bool, loaded: Bool) in
                return (exist: state.totalCount > 0, loaded: true)
            } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                return (tag: .archiveStories, exists: data.exist, hasLoaded: data.loaded)
            }
        } else {
            archiveStoriesTab = .single((tag: .archiveStories, exists: false, hasLoaded: true))
        }
        
        
        if threadInfo == nil, peerId.namespace == Namespaces.Peer.CloudChannel {
            similarChannels = context.engine.peers.recommendedChannels(peerId: peerId) |> map { channels -> (exist: Bool, loaded: Bool) in
                return (exist: (channels?.channels.count ?? 0) > 0, loaded: true)
            } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                return (tag: .similarChannels, exists: data.exist, hasLoaded: data.loaded)
            }
        } else {
            similarChannels = .single((tag: .similarChannels, exists: false, hasLoaded: true))
        }
        
        if threadInfo == nil, peerId.namespace == Namespaces.Peer.CloudUser {
            similarBots = context.engine.peers.recommendedBots(peerId: peerId) |> map { bots -> (exist: Bool, loaded: Bool) in
                return (exist: (bots?.bots.count ?? 0) > 0, loaded: true)
            } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                return (tag: .similarBots, exists: data.exist, hasLoaded: data.loaded)
            }
        } else {
            similarBots = .single((tag: .similarBots, exists: false, hasLoaded: true))
        }
        
        if threadInfo == nil, peerId == context.peerId, !isProfileIntended {
            let savedKeyId = PostboxViewKey.savedMessagesIndex(peerId: context.peerId)
            let viewSignal: Signal<Int, NoError> = context.account.postbox.combinedView(keys: [savedKeyId]) |> map {
                return ($0.views[savedKeyId] as? MessageHistorySavedMessagesIndexView)?.items.count ?? 0
            }

            savedMessagesTab = viewSignal |> map { state -> (exist: Bool, loaded: Bool) in
                return (exist: state > 0, loaded: true)
            } |> map { data -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                return (tag: .savedMessages, exists: data.exist, hasLoaded: data.loaded)
            }
        } else {
            savedMessagesTab = .single((tag: .savedMessages, exists: false, hasLoaded: true))
        }
        
        if peerId != context.peerId, threadInfo == nil {
            savedTab = context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(peerId: context.peerId, threadId: peerId.toInt64()), count: 3, tag: nil)
            |> map { (view, _, _) -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                let hasLoaded = view.entries.count >= 1 || (!view.isLoading)
                return (tag: .saved, exists: !view.entries.isEmpty, hasLoaded: hasLoaded)
            }
        } else {
            savedTab = .single((tag: .saved, exists: false, hasLoaded: true))
        }
        
        
        
        let location: ChatLocationInput
        if let threadInfo = threadInfo {
            location = context.chatLocationInput(for: .thread(threadInfo.message), contextHolder: threadInfo.contextHolder)
        } else {
            location = .peer(peerId: peerId, threadId: nil)
        }
        
        let tabItems: [Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>] = self.tagsList.filter { !$0.tagsValue.isEmpty }.map { tags -> Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError> in
            return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(location, count: 3, tag: .tag(tags.tagsValue))
            |> map { (view, _, _) -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                let hasLoaded = view.entries.count >= 1 || (!view.isLoading)
                return (tag: tags, exists: !view.entries.isEmpty && (!isProfileIntended || (context.peerId != peerId)), hasLoaded: hasLoaded)
            }
        }
        
        let mergedTabs = combineLatest(membersTab, combineLatest(tabItems), commonGroupsTab, storiesTab, archiveStoriesTab, similarChannels, similarBots, savedMessagesTab, savedTab, giftsTab) |> map { members, general, commonGroups, stories, archiveStories, similarChannels, similarBots, savedMessagesTab, savedTab, giftsTab -> [(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool)] in
            var general = general
            var bestIndex: Int = 0
            for general in general {
                if general.tag == .photoOrVideo && general.exists {
                    bestIndex += 1
                    break
                }
            }
            general.insert(savedTab, at: bestIndex)
            general.insert(members, at: 0)
            general.append(commonGroups)
            general.insert(archiveStories, at: 0)
            general.insert(giftsTab, at: 0)
            general.insert(stories, at: 0)
            general.append(similarChannels)
            general.append(similarBots)
            general.insert(savedMessagesTab, at: 0)
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
                    selectedValue = initialMode ?? tabs.filter { $0.exists }.first?.tag
                }
                
            }
            return (tabs: tabs.filter { $0.exists }.map { $0.tag }, selected: selectedValue, hasLoaded: tabs.first?.hasLoaded ?? false)
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
                case .similarChannels:
                    if !self.similarChannels.isLoaded() {
                        self.similarChannels.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.similarChannels.ready.get() |> map { ready in
                        return data
                    }
                case .similarBots:
                    if !self.similarBots.isLoaded() {
                        self.similarBots.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.similarBots.ready.get() |> map { ready in
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
                case .stories:
                    if !self.stories.isLoaded() {
                        self.stories.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return self.stories.ready.get() |> map { ready in
                        return data
                    }
                case .archiveStories:
                    if let archiveStories = self.archiveStories {
                        if !archiveStories.isLoaded() {
                            archiveStories.loadViewIfNeeded(self.genericView.view.bounds)
                        }
                        return archiveStories.ready.get() |> map { ready in
                            return data
                        }
                    } else {
                        return .single(data)
                    }
                case .savedMessages:
                    if let savedMessages = self.savedMessages {
                        if !savedMessages.isLoaded() {
                            savedMessages.loadViewIfNeeded(self.genericView.view.bounds)
                        }
                        return savedMessages.ready.get() |> map { ready in
                            return data
                        }
                    } else {
                        return .single(data)
                    }
                case .saved:
                    if !saved.isLoaded() {
                        saved.loadViewIfNeeded(self.genericView.view.bounds)
                    }
                    return saved.ready.get() |> map { ready in
                        return data
                    }
                case .gifts:
                    if let gifts = self.gifts {
                        if !gifts.isLoaded() {
                            gifts.loadViewIfNeeded(self.genericView.view.bounds)
                        }
                        return gifts.ready.get() |> map { ready in
                            return data
                        }
                    } else {
                        return .single(data)
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
            let newMode = PeerMediaCollectionMode(rawValue: Int32(item.uniqueId))!
            
            if newMode == self?.mode, let mainTable = self?.genericView.mainTable {
                self?.currentMainTableView?(mainTable, true, true)
            }
            self?.modeValue.set(newMode)
        }
        
        
        interactions.forwardMessages = { messages in
            showModal(with: ShareModalController(ForwardMessagesObject(context, messages: messages)), for: context.window)
        }
        
        let openChat:(PeerId, ChatFocusTarget?)->Void = { [weak self] id, focusTarget in
            let location: ChatLocation
            let mode: ChatMode
            if let threadInfo = threadInfo, peerId == id {
            
                location = .thread(threadInfo.message)
                if threadInfo.isMonoforumPost {
                    mode = .history
                } else {
                    mode = .thread(mode: .topic(origin: threadInfo.message.effectiveTopId))
                }
            } else {
                location = .peer(id)
                mode = .history
            }
            navigateToChat(navigation: self?.navigationController, context: context, chatLocation: location, mode: mode, focusTarget: focusTarget, chatLocationContextHolder: threadInfo?.contextHolder)

        }
        
        interactions.focusMessageId = { _, focusMessageId, _ in
            openChat(peerId, focusMessageId)
        }
        
        interactions.inlineAudioPlayer = { [weak self] controller in
            guard let navigation = self?.navigationController else {
                return
            }
            let tableView = (navigation.first { $0 is ChatController} as? ChatController)?.genericView.tableView
            let object = InlineAudioPlayerView.ContextObject(controller: controller, context: context, tableView: tableView, supportTableView: self?.currentTable)
            context.sharedContext.showInlinePlayer(object)
        }
        
        interactions.openInfo = { [weak self] (peerId, toChat, postId, action) in
            if let strongSelf = self {
                if toChat {
                    openChat(peerId, .init(messageId: postId))
                } else {
                    if let navigation = strongSelf.navigationController {
                        PeerInfoController.push(navigation: navigation, context: context, peerId: peerId, threadInfo: threadInfo)
                    }
                }
            }
        }
        
        interactions.deleteMessages = { [weak self] messageIds in
            if let strongSelf = self, let peer = strongSelf.peer {
                
                let adminsPromise = ValuePromise<[RenderedChannelParticipant]>([])
                _ = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { membersState in
                    if case .loading = membersState.loadingState, membersState.list.isEmpty {
                        adminsPromise.set([])
                    } else {
                        adminsPromise.set(membersState.list)
                    }
                })
                
                
                self?.messagesActionDisposable.set(combineLatest(queue: .mainQueue(), context.account.postbox.messagesAtIds(messageIds), adminsPromise.get()).start( next:{ [weak strongSelf] messages, admins in
                    if let strongSelf = strongSelf {
                        var canDelete:Bool = true
                        var canDeleteForEveryone = true
                        var otherCounter:Int32 = 0
                        var _mustDeleteForEveryoneMessage: Bool = true
                        for message in messages {
                            if !canDeleteMessage(message, account: context.account, chatLocation: strongSelf.interactions.chatLocation, mode: .history) {
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
                        
                        let context = strongSelf.context
                        
                        if canDelete {
                            let isAdmin = admins.filter({$0.peer.id == messages[0].author?.id}).first != nil
                            if mustManageDeleteMessages(messages, for: peer, account: strongSelf.context.account), let memberId = messages[0].author?.id, !isAdmin {
                                
                                let options:[ModalOptionSet] = [ModalOptionSet(title: strings().supergroupDeleteRestrictionDeleteMessage, selected: true, editable: true),
                                                                ModalOptionSet(title: strings().supergroupDeleteRestrictionBanUser, selected: false, editable: true),
                                                                ModalOptionSet(title: strings().supergroupDeleteRestrictionReportSpam, selected: false, editable: true),
                                                                ModalOptionSet(title: strings().supergroupDeleteRestrictionDeleteAllMessages, selected: false, editable: true)]
                                showModal(with: ModalOptionSetController(context: context, options: options, actionText: (strings().modalOK, theme.colors.accent), title: strings().supergroupDeleteRestrictionTitle, result: { [weak strongSelf] result in
                                    
                                    var signals:[Signal<Void, NoError>] = []
                                    if result[0] == .selected {
                                        signals.append(context.engine.messages.deleteMessagesInteractively(messageIds: messages.map {$0.id}, type: .forEveryone))
                                    }
                                    if result[1] == .selected {
                                        signals.append(context.peerChannelMemberCategoriesContextsManager.updateMemberBannedRights(peerId: peer.id, memberId: memberId, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max)))
                                    }
                                    if result[2] == .selected {
                                        signals.append(context.engine.peers.reportPeerMessages(messageIds: messageIds, reason: .spam, message: ""))
                                    }
                                    if result[3] == .selected {
                                        signals.append(context.engine.messages.clearAuthorHistory(peerId: peer.id, memberId: memberId))
                                    }
                                    
                                    _ = showModalProgress(signal: combineLatest(signals), for: context.window).start()
                                    strongSelf?.interactions.update({$0.withoutSelectionState()})
                                    
                                }), for: context.window)
                            } else {
                                let thrid:String? = (canDeleteForEveryone ? peer.isUser ? strings().chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : strings().chatConfirmDeleteMessagesForEveryone : nil)
                                
                                verifyAlert(for: context.window, header: thrid == nil ? strings().chatConfirmActionUndonable : strings().chatConfirmDeleteMessages1Countable(messages.count), information: thrid == nil ? _mustDeleteForEveryoneMessage ? strings().chatConfirmDeleteForEveryoneCountable(messages.count) : strings().chatConfirmDeleteMessages1Countable(messages.count) : nil, ok: strings().confirmDelete, option: thrid, successHandler: { [weak strongSelf] result in
                                    
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
                                    _ = context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: type).start()
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
                let insets = NSEdgeInsets(left: 5, right: 5, bottom: 2)
                let segmentTheme = ScrollableSegmentTheme(background: .clear, border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.accent, textFont: .normal(.title))
                for (i, tab)  in tabs.enumerated() {
                    items.append(ScrollableSegmentItem(title: tab.title(self.peer), index: i, uniqueId: Int64(tab.rawValue), selected: selected == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: nil))
                }
                self.genericView.segmentPanelView.segmentControl.updateItems(items, animated: !firstTabAppear)
                self.genericView.updateEmpty(items.isEmpty, animated: !firstTabAppear)
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
                self.readyOnce()
            }
        }))
        
    
        let storiesCount = self.storyListContext.state |> map { Int32($0.totalCount) }
        let commonGroupsCount = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CommonGroupCount(id: peerId)) |> map { Int32($0 ?? 0) }
        let similarChannelsCount = context.engine.peers.recommendedChannels(peerId: peerId) |> map { $0?.count ?? 0 }
        let similarBotsCount = context.engine.peers.recommendedBots(peerId: peerId) |> map { Int32($0?.bots.count ?? 0) }

        let savedMessagesCount: Signal<Int32, NoError> = context.engine.messages.savedMessagesPeersStats() |> map { Int32($0 ?? 0) }

        
        let savedCount = self.context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: self.context.account.peerId, threadId: peerId.toInt64(), tag: [])
        ) |> map { Int32($0 ?? 0) }

        
        let archiveStoriesCount: Signal<Int32, NoError>
        if let archiveStoryListContext {
            archiveStoriesCount = archiveStoryListContext.state |> map { Int32($0.totalCount) }
        } else {
            archiveStoriesCount = .single(0)
        }
        let giftsCount: Signal<Int32, NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.StarGiftsCount(id: peerId)) |> map { $0 ?? 0 }
        
        
        
        var summaries: [MessageTags] = []
        summaries.append(.photo)
        summaries.append(.video)
        summaries.append(.gif)
        summaries.append(.file)
        summaries.append(.webPage)
        summaries.append(.voiceOrInstantVideo)
        summaries.append(.music)
        
        let mediaPeerId = threadInfo?.message.peerId ?? peerId
        let threadId = threadInfo?.message.threadId

        let counters: Signal<(PeerMediaCollectionMode?, [PeerMediaCollectionMode: Int32]), NoError> = combineLatest(self.modeValue.get(), context.engine.data.subscribe(EngineDataMap(
            summaries.map { TelegramEngine.EngineData.Item.Messages.MessageCount(peerId: mediaPeerId, threadId: threadId, tag: $0) }
        )), storiesCount, archiveStoriesCount, similarChannelsCount, similarBotsCount, commonGroupsCount, savedMessagesCount, savedCount, giftsCount)
        |> map { mode, summaries, storiesCount, archiveStoriesCount, similarChannelsCount, similarBotsCount, commonGroupsCount, savedMessagesCount, savedCount, giftsCount -> (PeerMediaCollectionMode?, [PeerMediaCollectionMode: Int32]) in
            var result: [PeerMediaCollectionMode: Int32] = [:]
            var photoOrVideo: Int32 = 0
            for (key, count) in summaries {
                switch key.tag {
                case .photo, .video:
                    photoOrVideo += count.flatMap(Int32.init) ?? 0
                case .gif:
                    result[.gifs] = count.flatMap(Int32.init) ?? 0
                case .file:
                    result[.file] = count.flatMap(Int32.init) ?? 0
                case .webPage:
                    result[.webpage] = count.flatMap(Int32.init) ?? 0
                case .voiceOrInstantVideo:
                    result[.voice] = count.flatMap(Int32.init) ?? 0
                case .music:
                    result[.music] = count.flatMap(Int32.init) ?? 0
                default:
                    break
                }
                result[.stories] = storiesCount
                result[.archiveStories] = archiveStoriesCount
                result[.similarChannels] = similarChannelsCount
                result[.commonGroups] = commonGroupsCount
                result[.photoOrVideo] = photoOrVideo
                result[.savedMessages] = savedMessagesCount
                result[.saved] = savedCount
                result[.gifts] = giftsCount
                result[.similarBots] = similarBotsCount
            }
            return (mode, result)
        } |> deliverOnMainQueue
        
                        
        statusDisposable.set(counters.start(next: { [weak self] mode, result in
            if let mode = mode, let count = result[mode].flatMap(Int.init) {
                let string: String?
                switch mode {
                case .photoOrVideo:
                    string = strings().sharedMediaMediaCountCountable(count)
                case .file:
                    string = strings().sharedMediaFileCountCountable(count)
                case .voice:
                    string = strings().sharedMediaVoiceCountCountable(count)
                case .webpage:
                    string = strings().sharedMediaLinkCountCountable(count)
                case .music:
                    string = strings().sharedMediaMusicCountCountable(count)
                case .gifs:
                    string = strings().sharedMediaGifCountCountable(count)
                case .archiveStories:
                    string = strings().sharedMediaArchiveStoryCountCountable(count)
                case .stories:
                    if self?.peer?.isBot == true {
                        string = strings().sharedMediaBotPreviewCountCountable(count)
                    } else {
                        string = strings().sharedMediaStoryCountCountable(count)
                    }
                case .commonGroups:
                    string = strings().sharedMediaCommonGroupsCountCountable(count)
                case .saved:
                    string = strings().sharedMediaSavedCountCountable(count)
                case .savedMessages:
                    string = strings().sharedMediaSavedMessagesCountCountable(count)
                case .similarChannels:
                    string = strings().sharedMediaSimilarCountCountable(count)
                case .similarBots:
                    string = strings().sharedMediaSimilarBotsCountCountable(count)
                case .members:
                    string = nil
                case .gifts:
                    string = strings().sharedMediaStarGiftsCountable(count)
                }
                if let string {
                    self?.centerBar.status = .initialize(string: string, color: theme.colors.grayText, font: .normal(.text))
                }
            } else {
                var peerView = self?.peerView
                self?.peerView = peerView
            }
        }))
        
    }
     
     override func viewDidResized(_ size: NSSize) {
         super.viewDidResized(size)
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
        
        
        centerBar.updateSearchVisibility(self.hasSearch)
        
        
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
                !($0 is PeerMediaEmptyRowItem) && !($0.className == "Telegram.GeneralRowItem")
            }
            var corners: GeneralViewItemCorners
            if items.first?.className == "Telegram.GeneralRowItem" {
                corners = .all
            } else {
                corners = filter.isEmpty ? .all : [.topLeft, .topRight]
            }
            self?.genericView.updateCorners(corners, animated: !firstUpdate)
            firstUpdate = false
        }
        self.currentMainTableView?(genericView.mainTable, animated, previous != controller && genericView.segmentPanelView.segmentControl.contains(oldMode?.rawValue ?? -3))
        
        
        
        
        //requestUpdateCenterBar()
    }
    
    func controller(for mode: PeerMediaCollectionMode) -> ViewController {
        switch mode {
        case .photoOrVideo:
            return self.mediaGrid
        case .members:
            return self.members
        case .commonGroups:
            return self.commonGroups
        case .similarChannels:
            return self.similarChannels
        case .similarBots:
            return self.similarBots
        case .gifs:
            return self.gifs
        case .stories:
            return stories
        case .archiveStories:
            if let archiveStories = self.archiveStories {
                return archiveStories
            } else {
                return ViewController()
            }
        case .savedMessages:
            if let savedMessages = self.savedMessages {
                return savedMessages
            } else {
                return ViewController()
            }
        case .saved:
            return saved
        case .gifts:
            if let gifts = self.gifts {
                return gifts
            } else {
                return ViewController()
            }
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
        statusDisposable.dispose()
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
            if let mode = self.mode {
                (self.controller(for: mode) as? PeerMediaSearchable)?.toggleSearch()
                return .invoked
            } else {
                return super.escapeKeyAction()
            }
        } else if interactions.presentation.state == .selecting {
            interactions.update { $0.withoutSelectionState() }
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
     
     var onTheTop: Bool {
         switch self.mode {
         case .photoOrVideo:
             return self.mediaGrid.onTheTop
         default:
             return true
         }
     }
    
    private var centerBar: SearchTitleBarView {
        return centerBarView as! SearchTitleBarView
    }
    
    private func searchGroupUsers() {
        _ = (selectModalPeers(window: context.window, context: context, title: strings().selectPeersTitleSearchMembers, behavior: peerId.namespace == Namespaces.Peer.CloudGroup ? SelectGroupMembersBehavior(peerId: peerId, limit: 1, settings: []) : SelectChannelMembersBehavior(peerId: peerId, peerChannelMemberContextsManager: context.peerChannelMemberCategoriesContextsManager, limit: 1, settings: [])) |> deliverOnMainQueue |> map {$0.first}).start(next: { [weak self] peerId in
            if let peerId = peerId, let context = self?.context {
                PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
            }
        })
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return SearchTitleBarView(controller: self, title:.initialize(string: defaultBarTitle, color: theme.colors.text, font: .medium(.title)), handler: { [weak self] in
            guard let `self` = self else {
                return
            }
            if let mode = self.mode, self.hasSearch {
                switch mode {
                case .members:
                    self.searchGroupUsers()
                default:
                    (self.controller(for: mode) as? PeerMediaSearchable)?.toggleSearch()
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
        if peerId == context.peerId, !isProfileIntended {
            return strings().peerSavedMessages
        } else {
            return super.defaultBarTitle
        }
    }
     
     override func setCenterTitle(_ text: String) {
         
     }
     override func setCenterStatus(_ text: String?) {
         
     }
     
     override var defaultBarStatus: String? {
         return nil
     }
    
    
    override func didRemovedFromStack() {
        super.didRemovedFromStack()
    }
    
    
    
    override func initializer() -> PeerMediaContainerView {
        return PeerMediaContainerView(frame: initializationRect, isSegmentHidden: self.externalSearchData != nil)
    }
    
 }
 
 
 

