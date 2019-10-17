 //
//  PeerMediaController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac

 

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


class PeerMediaControllerView : View {
    
    private let actionsPanelView:MessageActionsPanelView = MessageActionsPanelView(frame: NSMakeRect(0,0,0, 50))
    fileprivate let topPanelView: View = View()
    fileprivate let segmentControl = SegmentController(frame: NSMakeRect(0, 0, 200, 30))
    private weak var mainView:NSView?
    private let separator:View = View()
    private var isSelectionState:Bool = false
    private var chatInteraction:ChatInteraction?
    private var searchState: SearchState?
    private(set) var searchView: SearchView?
    required init(frame frameRect:NSRect) {
        super.init(frame: frameRect)
        addSubview(actionsPanelView)
        addSubview(separator)
        topPanelView.addSubview(segmentControl.view)
        addSubview(topPanelView)
        updateLocalizationAndTheme(theme: theme)
        topPanelView.border = [.Bottom]
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        separator.backgroundColor = theme.colors.border
//        mainView?.background = theme.colors.background
        segmentControl.theme = SegmentTheme(backgroundColor: theme.colors.background, foregroundColor: theme.colors.accent, textColor: theme.colors.accent)
    }
    
    func updateInteraction(_ chatInteraction:ChatInteraction) {
        self.chatInteraction = chatInteraction
        actionsPanelView.prepare(with: chatInteraction)
    }
    
    
    func updateMainView(with view:NSView, animated:Bool) {
        mainView?.removeFromSuperview()
//        mainView?.background = theme.colors.background
        self.mainView = view
        addSubview(view, positioned: .below, relativeTo: actionsPanelView)
        needsLayout = true
    }
    
    func updateSearchState(_ state: MediaSearchState) {
        self.searchState = state.state
        switch state.state.state {
        case .Focus:
            if searchView == nil {
                searchView = SearchView(frame: NSMakeRect(10, -30, frame.width - 20, 30))
                topPanelView.addSubview(searchView!)
                searchView!.change(state: .Focus, false)

                searchView?.searchInteractions = SearchInteractions({ value, _ in
                    
                }, { value in
                   state.controller.searchState.set(value)
                })
            }
            searchView?.isLoading = state.isLoading
            searchView?._change(pos: NSMakePoint(10, 10), animated: state.animated)
            segmentControl.view._change(pos: NSMakePoint(segmentControl.view.frame.minX, topPanelView.frame.height), animated: state.animated)
        case .None:
            segmentControl.view._change(pos: NSMakePoint(segmentControl.view.frame.minX, 10), animated: state.animated)
            if let searchView = self.searchView {
                self.searchView = nil
                searchView._change(pos: NSMakePoint(10, -searchView.frame.height), animated: state.animated, completion: { [weak searchView] completed in
                    searchView?.removeFromSuperview()
                })
            }
            
        }
    }
    
    func changeState(selectState:Bool, animated:Bool) {
        assert(mainView != nil)
        
        self.isSelectionState = selectState
        let inset:CGFloat = selectState ? 50 : 0

      //  mainView?.setFrameSize(NSMakeSize(frame.width, frame.height - inset))
        
        actionsPanelView.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
        separator.change(pos: NSMakePoint(0, frame.height - inset), animated: animated)
    }
    
    override func layout() {
        
        let inset:CGFloat = isSelectionState ? 50 : 0
        topPanelView.frame = NSMakeRect(0, 0, frame.width, 50)
        
        searchView?.frame = NSMakeRect(10, 10, frame.width - 20, 30)
        
        segmentControl.view.setFrameSize(frame.width - 20, 30)
        segmentControl.view.centerX(y: searchView == nil ? 10 : topPanelView.frame.height)
        mainView?.frame = NSMakeRect(0, topPanelView.frame.height, frame.width, frame.height - inset - topPanelView.frame.maxY)
        actionsPanelView.frame = NSMakeRect(0, frame.height - inset, frame.width, 50)
        separator.frame = NSMakeRect(0, frame.height - inset, frame.width, .borderSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PeerMediaController: EditableViewController<PeerMediaControllerView>, Notifable {

    private let peerId:PeerId
    private var peer:Peer?
    
    private var tagMask:MessageTags
    private var mode:PeerMediaCollectionMode = .photoOrVideo
    
    private let mediaGrid:PeerMediaGridController
    private let listControllers:[PeerMediaListController]
    private let tagsList:[PeerMediaCollectionMode] = [.file, .webpage, .music, .voice]
    private var currentTagListIndex: Int = -1
    private var interactions:ChatInteraction
    private let messagesActionDisposable:MetaDisposable = MetaDisposable()
    private let loadFwdMessagesDisposable = MetaDisposable()
    private let loadSelectionMessagesDisposable = MetaDisposable()
    private let searchValueDisposable = MetaDisposable()
    private let currentModeValue:ValuePromise<PeerMediaCollectionMode> = ValuePromise(.photoOrVideo, ignoreRepeated: true)
    private var searchController: PeerMediaListController?
    init(context: AccountContext, peerId:PeerId, tagMask:MessageTags) {
        self.peerId = peerId
        self.tagMask = tagMask
        
        interactions = ChatInteraction(chatLocation: .peer(peerId), context: context)
        
        
        mediaGrid = PeerMediaGridController(context: context, chatLocation: .peer(peerId), messageId: nil, tagMask: tagMask, chatInteraction: interactions)
        
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
                self?.genericView.segmentControl.set(selected: value.rawValue)
            })
        }
        return temporaryTouchBar as? NSTouchBar
    }
    
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
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        interactions.remove(observer: self)
        if self.mode == .photoOrVideo {
            self.mediaGrid.viewDidDisappear(animated)
        } else {
            self.listControllers[currentTagListIndex].viewDidDisappear(animated)
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
                
                if mode == .photoOrVideo {
                    self.mediaGrid.genericView.grid.forEachItemNode { itemNode in
                        if let itemNode = itemNode as? GridMessageItemNode {
                            itemNode.updateSelectionState(animated: animated)
                        }
                    }
                }
               
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
                        
                        for message in messages {
                            if !canDeleteMessage(message, account: strongSelf.context.account) {
                                canDelete = false
                            }
                            if !canDeleteForEveryoneMessage(message, context: strongSelf.context) {
                                canDeleteForEveryone = false
                            }
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
                                           signals.append(deleteMessagesInteractively(postbox: context.account.postbox, messageIds: messages.map {$0.id}, type: .forEveryone))
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
                                let thrid:String? = canDeleteForEveryone ? peer.isUser ? tr(L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle)) : tr(L10n.chatConfirmDeleteMessagesForEveryone) : nil
                                
                                modernConfirm(for: context.window, account: context.account, peerId: nil, header: thrid == nil ? L10n.chatConfirmActionUndonable : L10n.chatConfirmDeleteMessages, information: thrid == nil ? L10n.chatConfirmDeleteMessages : nil, okTitle: L10n.confirmDelete, thridTitle: thrid, successHandler: { result in
                                    let type:InteractiveMessagesDeletionType
                                    switch result {
                                    case .basic:
                                        type = .forLocalPeer
                                    case .thrid:
                                        type = .forEveryone
                                    }
                                    _ = deleteMessagesInteractively(postbox: strongSelf.context.account.postbox, messageIds: messageIds, type: type).start()
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
        
        let combined = combineLatest( [peerSignal |> take(1), mediaGrid.ready.get()] ) |> map { result -> Bool in
            return result[0] && result[1]
        }
        
        self.ready.set(combined |> deliverOnMainQueue)
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
 
        for i in 0 ..< listControllers.count {
            listControllers[i].loadViewIfNeeded(bounds)
            listControllers[i].load(with: tagsList[i].tagsValue)
        }
        mediaGrid.loadViewIfNeeded(bounds)
        
        mediaGrid.viewWillAppear(false)
        genericView.updateMainView(with: mediaGrid.view, animated: false)
        centerBar.updateSearchVisibility(false)
        mediaGrid.viewDidAppear(false)
        
        requestUpdateCenterBar()
        updateLocalizationAndTheme(theme: theme)
    }
    
    private func toggle(with mode:PeerMediaCollectionMode, animated:Bool = false) {
        currentModeValue.set(mode)
        if self.mode != mode {
            self.mode = mode
            if mode == .photoOrVideo {
                mediaGrid.viewWillAppear(animated)
                self.listControllers[currentTagListIndex].viewWillDisappear(animated)
                mediaGrid.view.frame = bounds
                genericView.updateMainView(with: mediaGrid.view, animated: animated)
                mediaGrid.viewDidAppear(animated)
                self.listControllers[currentTagListIndex].removeFromSuperview()
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
                self.listControllers[currentTagListIndex].view.frame = bounds
                genericView.updateMainView(with: self.listControllers[currentTagListIndex].view, animated: animated)
                self.listControllers[currentTagListIndex].viewDidAppear(animated)
                previous.removeFromSuperview()
                previous.viewDidDisappear(animated)
                centerBar.updateSearchVisibility(true)
                
                searchValueDisposable.set(self.listControllers[currentTagListIndex].mediaSearchValue.start(next: { [weak self] state in
                    self?.genericView.updateSearchState(state)
                }))
            }
            
        }
        
    }
    
    deinit {
        messagesActionDisposable.dispose()
        loadFwdMessagesDisposable.dispose()
        loadSelectionMessagesDisposable.dispose()
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        genericView.segmentControl.removeAll()
        
        genericView.segmentControl.add(segment: SegmentedItem(title: L10n.peerMediaMedia, handler: { [weak self] in
            self?.toggle(with: .photoOrVideo, animated:true)
        }))
        
        genericView.segmentControl.add(segment: SegmentedItem(title: L10n.peerMediaFiles, handler: { [weak self] in
            self?.toggle(with: .file, animated:true)
        }))
        
        genericView.segmentControl.add(segment: SegmentedItem(title: L10n.peerMediaLinks, handler: { [weak self] in
            self?.toggle(with: .webpage, animated:true)
        }))
        
        genericView.segmentControl.add(segment: SegmentedItem(title: L10n.peerMediaAudio, handler: { [weak self] in
            self?.toggle(with: .music, animated:true)
        }))
        
        genericView.segmentControl.add(segment: SegmentedItem(title: L10n.peerMediaVoice, handler: { [weak self] in
            self?.toggle(with: .voice, animated:true)
        }))
    }
    
    override public func update(with state:ViewControllerState) -> Void {
        super.update(with:state)
        interactions.update({state == .Normal ? $0.withoutSelectionState() : $0.withSelectionState()})
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.searchView != nil {
            self.listControllers[self.currentTagListIndex].toggleSearch()
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
        return genericView.searchView?.input
    }
  
    override func navigationHeaderDidNoticeAnimation(_ current: CGFloat, _ previous: CGFloat, _ animated: Bool) -> () -> Void {
        for mediaList in listControllers {
            if mediaList.view.superview != nil {
                genericView.topPanelView._change(pos: NSMakePoint(genericView.topPanelView.frame.minX, current), animated: animated)
                return mediaList.navigationHeaderDidNoticeAnimation(current, previous, animated)
            }
        }
       
        if mediaGrid.view.superview != nil {
            return mediaGrid.navigationHeaderDidNoticeAnimation(current, previous, animated)
        }
        return {}
    }
    
}



