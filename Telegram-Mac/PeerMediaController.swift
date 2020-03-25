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

 

 private class PeerMediaTitleBarView : TitledBarView {
     private var search:ImageButton = ImageButton()
     init(controller: ViewController, title:NSAttributedString, handler:@escaping() ->Void) {
         super.init(controller: controller, title)
         search.set(handler: { _ in
             handler()
         }, for: .Click)
         addSubview(search)
         updateLocalizationAndTheme(theme: theme)
     }
     
     func updateSearchVisibility(_ visible: Bool) {
         search.isHidden = !visible
     }
     
     override func updateLocalizationAndTheme(theme: PresentationTheme) {
         super.updateLocalizationAndTheme(theme: theme)
         let theme = (theme as! TelegramPresentationTheme)
         search.set(image: theme.icons.chatSearch, for: .Normal)
         _ = search.sizeToFit()
         backgroundColor = theme.colors.background
         needsLayout = true
     }
     
     override func layout() {
         super.layout()
         search.centerY(x: frame.width - search.frame.width)
     }
     
     
     required init(frame frameRect: NSRect) {
         fatalError("init(frame:) has not been implemented")
     }
     
     required init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }
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
    fileprivate let segmentControl = ScrollableSegmentView(frame: NSMakeRect(0, 0, 200, 50))
    required init(frame frameRect: NSRect) {
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
        super.updateLocalizationAndTheme(theme: theme)
        segmentControl.theme = ScrollableSegmentTheme(border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.text, textFont: .normal(.text))
        borderColor = theme.colors.border
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
    fileprivate let view: PeerMediaControllerView
    required init(frame frameRect: NSRect) {
        view = PeerMediaControllerView(frame: NSMakeRect(0, sectionOffset, frameRect.width, frameRect.height - sectionOffset))
        super.init(frame: frameRect)
        addSubview(view)
        backgroundColor = theme.colors.listBackground
    }
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.listBackground
    }
    
    override func scrollWheel(with event: NSEvent) {
        view.scrollWheel(with: event)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        let blockWidth = min(600, frame.width - sectionOffset * 2)

        
        view.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - blockWidth) / 2), sectionOffset, blockWidth, frame.height - sectionOffset)
    }
    
    var mainView:NSView? {
        return self.view.mainView
    }
    
    func updateInteraction(_ chatInteraction:ChatInteraction) {
        self.view.updateInteraction(chatInteraction)
    }
    
    
    fileprivate func updateMainView(with view:NSView, animated:PeerMediaAnimationDirection?) {
        self.view.updateMainView(with: view, animated: animated)
    }
    
    func updateSearchState(_ state: MediaSearchState, updateSearchState:@escaping(SearchState)->Void) {
        self.view.updateSearchState(state, updateSearchState: updateSearchState)
    }
    
    func changeState(selectState:Bool, animated:Bool) {
        self.view.changeState(selectState: selectState, animated: animated)
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
    
    private let actionsPanelView:MessageActionsPanelView = MessageActionsPanelView(frame: NSMakeRect(0,0,0, 50))
    private let topPanelView = GeneralRowContainerView(frame: .zero)
    fileprivate let segmentPanelView: SegmentContainerView = SegmentContainerView(frame: NSZeroRect)
    fileprivate var searchPanelView: SearchContainerView?

    private(set) weak var mainView:NSView?
    
    private let topPanelSeparatorView = View()
    
    override func scrollWheel(with event: NSEvent) {
        mainView?.scrollWheel(with: event)
    }
    
    fileprivate var corners:GeneralViewItemCorners = [.topLeft, .topRight]
    
    private let separator:View = View()
    private var isSelectionState:Bool = false
    private var chatInteraction:ChatInteraction?
    private var searchState: SearchState?
    required init(frame frameRect:NSRect) {
        super.init(frame: frameRect)
        addSubview(actionsPanelView)
        
        addSubview(topPanelView)
        addSubview(separator)
        topPanelView.addSubview(segmentPanelView)
        topPanelView.addSubview(topPanelSeparatorView)
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = theme.colors.listBackground
        separator.backgroundColor = theme.colors.border
        topPanelView.backgroundColor = theme.colors.background
        topPanelSeparatorView.backgroundColor = theme.colors.border
    }
    
    func updateInteraction(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        actionsPanelView.prepare(with: chatInteraction)
    }
    
    func updateCorners(_ corners: GeneralViewItemCorners, animated: Bool) {
        self.corners = corners
        self.topPanelView.setCorners(corners, animated: animated)
        topPanelSeparatorView.isHidden = corners == .all
    }
    
    fileprivate func updateMainView(with view:NSView, animated:PeerMediaAnimationDirection?) {
        addSubview(view, positioned: .below, relativeTo: actionsPanelView)
        if let animated = animated {
            if let mainView = mainView {
                switch animated {
                case .leftToRight:
                    mainView._change(pos: NSMakePoint(-mainView.frame.width, mainView.frame.minY), animated: true, completion: { [weak mainView] _ in
                        mainView?.removeFromSuperview()
                    })
                    view.layer?.animatePosition(from: NSMakePoint(view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY))
                case .rightToLeft:
                    mainView._change(pos: NSMakePoint(mainView.frame.width, mainView.frame.minY), animated: true, completion: { [weak mainView] _ in
                        mainView?.removeFromSuperview()
                    })
                    view.layer?.animatePosition(from: NSMakePoint(-view.frame.width, mainView.frame.minY), to: NSMakePoint(0, mainView.frame.minY))
                }
            }
            self.mainView = view
        } else {
            mainView?.removeFromSuperview()
            self.mainView = view
        }
        needsLayout = true
    }
    
    func updateSearchState(_ state: MediaSearchState, updateSearchState:@escaping(SearchState)->Void) {
        self.searchState = state.state
        switch state.state.state {
        case .Focus:
            if searchPanelView == nil {
                self.searchPanelView = SearchContainerView(frame: NSMakeRect(0, -topPanelView.frame.height, topPanelView.frame.width, 50))
                
                guard let searchPanelView = self.searchPanelView else {
                    fatalError()
                }
                topPanelView.addSubview(searchPanelView, positioned: .below, relativeTo: topPanelSeparatorView)
                searchPanelView.searchView.change(state: .Focus, false)
                searchPanelView.searchView.searchInteractions = SearchInteractions({ _, _ in
                    
                }, updateSearchState)
                
                searchPanelView.close.set(handler: { _ in
                    updateSearchState(.init(state: .None, request: nil))
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
            topPanelView.addSubview(segmentPanelView, positioned: .below, relativeTo: topPanelSeparatorView)
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
        let inset:CGFloat = selectState ? 50 : 0

        actionsPanelView.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
        separator.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
        
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
        mainView?.frame = NSMakeRect(0, 50, frame.width, frame.height - inset - 50)
        actionsPanelView.frame = NSMakeRect(0, frame.height - inset, frame.width, 50)
        separator.frame = NSMakeRect(0, frame.height - inset, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

 private extension PeerMediaCollectionMode {
    var title: String {
        if self.tagsValue == .photoOrVideo {
            return L10n.peerMediaMedia
        }
        if self.tagsValue == .file {
            return L10n.peerMediaFiles
        }
        if self.tagsValue == .webPage {
            return L10n.peerMediaLinks
        }
        if self.tagsValue == .music {
            return L10n.peerMediaAudio
        }
        if self.tagsValue == .voiceOrInstantVideo {
            return L10n.peerMediaVoice
        }
        return ""
    }
 }
 
class PeerMediaController: EditableViewController<PeerMediaContainerView>, Notifable {

    private let peerId:PeerId
    private var peer:Peer?
    
    private var tagMask:MessageTags
    
    private let modeValue: ValuePromise<PeerMediaCollectionMode> = ValuePromise(.photoOrVideo, ignoreRepeated: true)
    private let tabsSignal:Promise<(tabs: [PeerMediaCollectionMode], selected: PeerMediaCollectionMode, hasLoaded: Bool)> = Promise()
    private let tabsDisposable = MetaDisposable()
    private var mode:PeerMediaCollectionMode = .photoOrVideo {
        didSet {
            modeValue.set(mode)
        }
    }
    
    private let mediaGrid:PeerMediaPhotosController
    private let listControllers:[PeerMediaListController]
    private let tagsList:[PeerMediaCollectionMode] = [.photoOrVideo, .file, .webpage, .music, .voice]
    
    
    private var currentTagListIndex: Int = -1
    private var interactions:ChatInteraction
    private let messagesActionDisposable:MetaDisposable = MetaDisposable()
    private let loadFwdMessagesDisposable = MetaDisposable()
    private let loadSelectionMessagesDisposable = MetaDisposable()
    private let searchValueDisposable = MetaDisposable()
    private let loadListsDisposable = MetaDisposable()
    private let currentModeValue:ValuePromise<PeerMediaCollectionMode> = ValuePromise(.photoOrVideo, ignoreRepeated: true)
    private var searchController: PeerMediaListController?
    
    var currentMainView:((NSView?, Bool, Bool)->Void)? = nil {
        didSet {
            if isLoaded() {
                currentMainView?(genericView.mainView, false, false)
            }
        }
    }
    
    init(context: AccountContext, peerId:PeerId, tagMask:MessageTags) {
        self.peerId = peerId
        self.tagMask = tagMask
        self.interactions = ChatInteraction(chatLocation: .peer(peerId), context: context)
        self.mediaGrid = PeerMediaPhotosController(context, chatInteraction: interactions, peerId: peerId)//PeerMediaGridController(context: context, chatLocation: .peer(peerId), messageId: nil, tagMask: tagMask, chatInteraction: interactions)
        
        var listControllers: [PeerMediaListController] = []
        for _ in tagsList {
            listControllers.append(PeerMediaListController(context: context, chatLocation: .peer(peerId), chatInteraction: interactions))
        }
        self.listControllers = listControllers
        
        
        super.init(context)
    }
    
    private var temporaryTouchBar: Any?
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        if temporaryTouchBar == nil {
            temporaryTouchBar = PeerMediaTouchBar(chatInteraction: interactions, currentMode: currentModeValue.get(), toggleMode: { [weak self] value in
                self?.toggle(with: value, animated: false)
               // self?.genericView.segmentPanelView.segmentControl.set(selected: value.rawValue)
            })
        }
        return temporaryTouchBar as? NSTouchBar
    }
    
    var isInSearch: Bool {
        return self.genericView.activePanel is SearchContainerView
    }
    
    private var navigationBarView: NavigationBarView?
    private var controllerBarView: NavigationBarView?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        interactions.add(observer: self)
        if self.mode == .photoOrVideo {
            self.mediaGrid.viewDidAppear(animated)
        } else {
            self.listControllers[currentTagListIndex].viewDidAppear(animated)
        }
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self, self.mode != .photoOrVideo else {
                return .rejected
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
        
        guard let navigationController = self.navigationController else {
            return
        }
        
        if controllerBarView == nil {
            let barView = NavigationBarView(frame: .zero)
            barView.frame = navigationController.navigationBar.frame
            barView.switchViews(left: self.leftBarView, center: self.centerBar, right: self.rightBarView, controller: self, style: .none, animationStyle: .init(duration: 0.2, function: .spring), liveSwiping: false)
            controllerBarView = barView
            navigationBarView = navigationController.navigationBar
        }
        
        guard let controllerBarView = self.controllerBarView else {
            return
        }
        navigationController.swapNavigationBar(controllerBarView, animation: .none)
       
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        interactions.remove(observer: self)
        if self.mode == .photoOrVideo {
            self.mediaGrid.viewDidDisappear(animated)
        } else {
            self.listControllers[currentTagListIndex].viewDidDisappear(animated)
            
            let controller = self.listControllers[currentTagListIndex]
            controller.searchState.set(.init(state: .None, request: nil))
            
        }
        
        guard let navigationBarView = self.navigationBarView else {
            return
        }
        if let navigationController = navigationController {
            navigationController.swapNavigationBar(navigationBarView, animation: .none)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.mode == .photoOrVideo {
            self.mediaGrid.viewWillAppear(animated)
        } else {
            self.listControllers[currentTagListIndex].viewWillAppear(animated)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
        if self.mode == .photoOrVideo {
            self.mediaGrid.viewWillDisappear(animated)
        } else {
            self.listControllers[currentTagListIndex].viewWillDisappear(animated)
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
                genericView.changeState(selectState: value.state == .selecting, animated: animated)
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
        
        let context = self.context
        
        let tabItems: [Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError>] = self.tagsList.map { tags -> Signal<(tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool), NoError> in
            return context.account.viewTracker.aroundMessageOfInterestHistoryViewForLocation(.peer(self.peerId), count: 3, tagMask: tags.tagsValue)
                |> map { (view, _, _) -> (tag: PeerMediaCollectionMode, exists: Bool, hasLoaded: Bool) in
                let hasLoaded = view.entries.count >= 3 || (!view.isLoading)
                return (tag: tags, exists: !view.entries.isEmpty, hasLoaded: hasLoaded)
            }
        }
        
        let tabSignal = combineLatest(queue: .mainQueue(), combineLatest(tabItems) |> map {
            return $0
        }, modeValue.get())
        |> map {
            (tabs: $0.0.filter { $0.exists }.map { $0.tag }, selected: $0.1, hasLoaded: $0.0.reduce(true, { $0 && $1.hasLoaded }))
        }
        
        tabsSignal.set(tabSignal)
        

        
        genericView.segmentPanelView.segmentControl.didChangeSelectedItem = { [weak self] item in
            self?.toggle(with: PeerMediaCollectionMode(rawValue: item.uniqueId)!, animated: true)
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
        }) |> map { view -> Bool in
            return true
        }
        
        let combined = combineLatest( [peerSignal |> take(1), mediaGrid.ready.get(), self.tabsSignal.get() |> map { $0.hasLoaded }] ) |> map { result -> Bool in
            return result[0] && result[1] && result[2]
        }
        
        self.ready.set(combined |> deliverOnMainQueue)
        
        let ready = self.ready.get() |> filter { $0 } |> take(1) |> deliverOnMainQueue
        
        loadListsDisposable.set(ready.start(next: { [weak self] _ in
            guard let `self` = self else {
                return
            }
            for i in 0 ..< self.listControllers.count {
                self.listControllers[i].loadViewIfNeeded(NSMakeRect(0, 0, self.bounds.width - 60, self.bounds.height))
                self.listControllers[i].load(with: self.tagsList[i].tagsValue)
            }
        }))
        
        var firstTabAppear = true
        tabsDisposable.set((self.tabsSignal.get() |> deliverOnMainQueue).start(next: { [weak self] tabs, selected, hasLoaded in
            var items:[ScrollableSegmentItem] = []
            if hasLoaded {
                let insets = NSEdgeInsets(left: 10, right: 10, bottom: 2)
                let segmentTheme = ScrollableSegmentTheme(border: .clear, selector: theme.colors.accent, inactiveText: theme.colors.grayText, activeText: theme.colors.accent, textFont: .normal(.title))
                for (i, tab)  in tabs.enumerated() {
                    items.append(ScrollableSegmentItem(title: tab.title, index: i, uniqueId: tab.rawValue, selected: selected == tab, insets: insets, icon: nil, theme: segmentTheme, equatable: nil))
                }
                self?.genericView.segmentPanelView.segmentControl.updateItems(items, animated: !firstTabAppear)
            }
            
            firstTabAppear = false
        }))
        
    }
    
    
    private var currentTable: TableView? {
        if self.mode == .photoOrVideo {
            return nil
        } else {
            return self.listControllers[currentTagListIndex].genericView
        }
    }
    override func loadView() {
        super.loadView()
 

        mediaGrid.loadViewIfNeeded(NSMakeRect(0, 0, self.bounds.width - 60, self.bounds.height))
        
        mediaGrid.viewWillAppear(false)
        genericView.updateMainView(with: mediaGrid.view, animated: nil)
        centerBar.updateSearchVisibility(false)
        mediaGrid.viewDidAppear(false)
        
        requestUpdateCenterBar()
        updateLocalizationAndTheme(theme: theme)
    }
    
    private func toggle(with mode:PeerMediaCollectionMode, animated:Bool = false) {
        currentModeValue.set(mode)
        let isUpdated = self.mode != mode
        if isUpdated {
            let oldMode = self.mode
            self.mode = mode
            if mode == .photoOrVideo {
                mediaGrid.viewWillAppear(animated)
                self.listControllers[currentTagListIndex].viewWillDisappear(animated)
                mediaGrid.view.frame = NSMakeRect(0, 0, self.bounds.width - 60, self.bounds.height)
                let animation: PeerMediaAnimationDirection?
                if animated {
                    if tagsList.contains(oldMode) {
                        animation = .rightToLeft
                    } else {
                        animation = .leftToRight
                    }
                } else {
                    animation = nil
                }
                
                genericView.updateMainView(with: mediaGrid.view, animated: animation)
                mediaGrid.viewDidAppear(animated)
                self.listControllers[currentTagListIndex].viewDidDisappear(animated)
                currentTagListIndex = -1
                searchValueDisposable.set(nil)
                centerBar.updateSearchVisibility(false)
            } else {
                let previous: ViewController
                if currentTagListIndex != -1 {
                    previous = self.listControllers[currentTagListIndex]
                } else {
                    previous = mediaGrid
                }
                self.currentTagListIndex = tagsList.firstIndex(of: mode)!
                self.listControllers[currentTagListIndex].viewWillAppear(animated)
                previous.viewWillDisappear(animated)
                self.listControllers[currentTagListIndex].view.frame = NSMakeRect(0, 0, self.bounds.width - 60, self.bounds.height)
                
                let animation: PeerMediaAnimationDirection?
                if animated {
                    if oldMode == .photoOrVideo {
                        animation = .leftToRight
                    } else {
                        let prevIndex = self.tagsList.firstIndex(where: { $0 == oldMode})!
                        if prevIndex < self.currentTagListIndex {
                            animation = .leftToRight
                        } else {
                            animation = .rightToLeft
                        }
                    }
                } else {
                    animation = nil
                }
                
                genericView.updateMainView(with: self.listControllers[currentTagListIndex].view, animated: animation)
                self.listControllers[currentTagListIndex].viewDidAppear(animated)
                previous.viewDidDisappear(animated)
                centerBar.updateSearchVisibility(true)
                
                let controller = self.listControllers[currentTagListIndex]
                
                searchValueDisposable.set(self.listControllers[currentTagListIndex].mediaSearchValue.start(next: { [weak self, weak controller] state in
                    self?.genericView.updateSearchState(state, updateSearchState: { searchState in
                        controller?.searchState.set(searchState)
                    })
                }))
            }
        }
        self.currentMainView?(genericView.mainView, animated, isUpdated)
        var firstUpdate: Bool = true
        (genericView.mainView as? TableView)?.updatedItems = { [weak self] items in
            let filter = items.filter {
                !($0 is PeerMediaEmptyRowItem) && !($0.className != "Telegram.GeneralRowItem")
            }
            self?.genericView.updateCorners(filter.isEmpty ? .all : [.topLeft, .topRight], animated: !firstUpdate)
            firstUpdate = false
        }
    }
    
    deinit {
        messagesActionDisposable.dispose()
        loadFwdMessagesDisposable.dispose()
        loadSelectionMessagesDisposable.dispose()
        loadListsDisposable.dispose()
        tabsDisposable.dispose()
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
    
    private var centerBar: PeerMediaTitleBarView {
        return centerBarView as! PeerMediaTitleBarView
    }
    
    override func getCenterBarViewOnce() -> TitledBarView {
        return PeerMediaTitleBarView(controller: self, title: .initialize(string: self.defaultBarTitle, color: theme.colors.text, font: .medium(.title)), handler: { [weak self] in
            guard let `self` = self else {
                return
            }
            self.listControllers[self.currentTagListIndex].toggleSearch()
        })
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchPanelView?.searchView.input
    }
  
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> () -> Void {
        for mediaList in listControllers {
            if mediaList.view.superview != nil {
                genericView.activePanel._change(pos: NSMakePoint(genericView.activePanel.frame.minX, current), animated: animated)
                return mediaList.navigationHeaderDidNoticeAnimation(current, previous, animated)
            }
        }
       
        if mediaGrid.view.superview != nil {
            return mediaGrid.navigationHeaderDidNoticeAnimation(current, previous, animated)
        }
        return {}
    }
    
}



