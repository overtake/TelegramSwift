//
//  PeersListController.swift
//  TelegramMac
//
//  Created by keepcoder on 29/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac



class PeerListContainerView : View {
    let tableView = TableView(frame:NSZeroRect, drawBorder: true)
    var searchView:SearchView = SearchView(frame:NSZeroRect)
    var compose:ImageButton = ImageButton()
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 12, 12))
    private var searchState: SearchFieldState = .None
    var mode: PeerListMode = .plain {
        didSet {
            switch mode {
            case .feedChannels:
                compose.isHidden = true
            case .plain:
                compose.isHidden = false
            }
            needsLayout = true
        }
    }
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.border = [.Right]
        compose.autohighlight = false
        autoresizesSubviews = false
        addSubview(tableView)
        addSubview(compose)
        addSubview(proxyButton)
        addSubview(searchView)
        proxyButton.addSubview(proxyConnecting)
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme()
        proxyButton.disableActions()
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
        proxyConnecting.centerY(addition: -1)
        needsLayout = true
    }
    
    func searchStateChanged(_ state: SearchFieldState, animated: Bool) {
        self.searchState = state
        searchView.change(size: NSMakeSize(state == .Focus ? frame.width - searchView.frame.minX * 2 : (frame.width - (!mode.isFeedChannels ? 36 + compose.frame.width : 20) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30), animated: animated)
        compose.change(opacity: state == .Focus ? 0 : 1, animated: animated)
        proxyButton.change(opacity: state == .Focus ? 0 : 1, animated: animated)
    }
    
    override func updateLocalizationAndTheme() {
        self.backgroundColor = theme.colors.background
        compose.background = .clear
        compose.set(background: .clear, for: .Normal)
        compose.set(background: .clear, for: .Hover)
        compose.set(background: theme.colors.blueFill, for: .Highlight)
        compose.set(image: theme.icons.composeNewChat, for: .Normal)
        compose.set(image: theme.icons.composeNewChatActive, for: .Highlight)
        compose.layer?.cornerRadius = .cornerRadius
        compose.setFrameSize(NSMakeSize(40, 30))
        proxyConnecting.progressColor = theme.colors.blueIcon
        proxyConnecting.lineWidth = 1.0
        super.updateLocalizationAndTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        
        searchView.setFrameSize(NSMakeSize(searchState == .Focus ? frame.width - searchView.frame.minX * 2 : (frame.width - (!mode.isFeedChannels ? 36 + compose.frame.width : 20) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30))
        tableView.setFrameSize(frame.width, frame.height - 49)
        
        searchView.isHidden = frame.width < 200
        if searchView.isHidden {
            compose.centerX(y: floorToScreenPixels(scaleFactor: backingScaleFactor, (49 - compose.frame.height)/2.0))
            proxyButton.setFrameOrigin(-proxyButton.frame.width, 0)
        } else {
            compose.setFrameOrigin(frame.width - 12 - compose.frame.width, floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - compose.frame.height)/2.0))
            proxyButton.setFrameOrigin(frame.width - 12 - compose.frame.width - proxyButton.frame.width - 6, floorToScreenPixels(scaleFactor: backingScaleFactor, (50 - proxyButton.frame.height)/2.0))
        }
        searchView.setFrameOrigin(10, floorToScreenPixels(scaleFactor: backingScaleFactor, (49 - searchView.frame.height)/2.0))
        tableView.setFrameOrigin(0, 49)
        
        proxyConnecting.centerX()
        proxyConnecting.centerY(addition: -1 - (backingScaleFactor == 2.0 ? 0.5 : 0))
        self.needsDisplay = true
    }
}


enum PeerListMode {
    case plain
    case feedChannels(PeerGroupId)
    
    var isFeedChannels:Bool {
        switch self {
        case .feedChannels:
            return true
        default:
            return false
        }
    }
    var groupId: PeerGroupId? {
        switch self {
        case let .feedChannels(groupId):
            return groupId
        default:
            return nil
        }
    }
}


class PeersListController: EditableViewController<PeerListContainerView>, TableViewDelegate {
    
    
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
    private var searchController:SearchController? {
        didSet {
            if let controller = searchController {
                genericView.customHandler.size = { [weak controller] size in
                    controller?.view.setFrameSize(NSMakeSize(size.width, size.height - 50))
                }
                progressDisposable.set((controller.isLoading.get() |> deliverOnMainQueue).start(next: { [weak self] isLoading in
                    self?.genericView.searchView.isLoading = isLoading
                }))
            }
        }
    }
    
    init(_ account:Account, followGlobal:Bool = true, mode: PeerListMode = .plain, searchOptions: AppSearchOptions = [.chats, .messages]) {
        self.followGlobal = followGlobal
        self.mode = mode
        self.searchOptions = searchOptions
        super.init(account)

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
        
        
        let account = self.account
        let actionsDisposable = self.actionsDisposable
        
        actionsDisposable.add((account.context.cancelGlobalSearch.get() |> deliverOnMainQueue).start(next: { [weak self] animated in
            self?.genericView.searchView.cancel(animated)
        }))
        
        genericView.mode = mode
        
        if followGlobal, mode.groupId == nil {
            actionsDisposable.add((globalPeerHandler.get() |> deliverOnMainQueue).start(next: { [weak self] location in
                guard let `self` = self else {return}
                self.genericView.tableView.changeSelection(stableId: location)
                if location == nil {
                    if !self.genericView.searchView.isEmpty {
                        self.window?.makeFirstResponder(self.genericView.searchView.input)
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
        
        
        
        actionsDisposable.add(combineLatest(proxySettingsSignal(account.postbox) |> mapToSignal { ps -> Signal<(ProxySettings, ConnectionStatus), Void> in
            return account.network.connectionStatus |> map { status -> (ProxySettings, ConnectionStatus) in
                return (ps, status)
            }
        } |> deliverOnMainQueue, appearanceSignal |> deliverOnMainQueue).start(next: { [weak self] pref, _ in
            settings = (pref.0, pref.1)
            self?.genericView.updateProxyPref(pref.0, pref.1)
            self?.readyOnce()
        }))
        
        let pushController:(ViewController)->Void = { [weak self] c in
            self?.navigationController?.push(c)
        }
        
        let openProxySettings:()->Void = { [weak self] in
            if let controller = self?.navigationController?.controller as? InputDataController {
                if controller.identifier == "proxy" {
                    return
                }
            }
            proxyListController(postbox: account.postbox, network: account.network, share: { servers in
                var message: String = ""
                for server in servers {
                    message += server.link + "\n\n"
                }
                message = message.trimmed

                showModal(with: ShareModalController(ShareLinkObject(account, link: message)), for: mainWindow)
            })( { controller in
                pushController(controller)
            })
        }
        
        genericView.proxyButton.set(handler: {  _ in
            if let settings = settings {
                if settings.0.enabled {
                    openProxySettings()
                } else {
                    actionsDisposable.add(updateProxySettingsInteractively(postbox: account.postbox, network: account.network, { current -> ProxySettings in
                        if let first = current.servers.first {
                            return current.withUpdatedActiveServer(first).withUpdatedEnabled(true)
                        } else {
                            return current
                        }
                    }).start())
                }
            }
        }, for: .Click)
        
        
        genericView.compose.set(handler: { [weak self] control in
            if let strongSelf = self, !control.isSelected {
                
                let items = [SPopoverItem(tr(L10n.composePopoverNewGroup), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let navigation = strongSelf.navigationController {
                        createGroup(with: strongSelf.account, for: navigation)
                    }
                    
                }, theme.icons.composeNewGroup),SPopoverItem(tr(L10n.composePopoverNewSecretChat), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let account = self?.account {
                        let confirmationImpl:([PeerId])->Signal<Bool,Void> = { peerIds in
                            if let first = peerIds.first, peerIds.count == 1 {
                                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                                    return confirmSignal(for: mainWindow, information: tr(L10n.composeConfirmStartSecretChat(peer.displayTitle)))
                                }
                            }
                            return confirmSignal(for: mainWindow, information: tr(L10n.peerInfoConfirmAddMembers1Countable(peerIds.count)))
                        }
                        let select = selectModalPeers(account: account, title: tr(L10n.composeSelectSecretChat), limit: 1, confirmation: confirmationImpl)
                        
                        let create = select |> map { $0.first! } |> mapToSignal { peerId in
                            return createSecretChat(account: account, peerId: peerId) |> mapError {_ in}
                            } |> deliverOnMainQueue |> mapToSignal{ peerId -> Signal<PeerId, Void> in
                                return showModalProgress(signal: .single(peerId), for: mainWindow)
                        }
                        
                        strongSelf.createSecretChatDisposable.set(create.start(next: { [weak self] peerId in
                            self?.navigationController?.push(ChatController(account: account, chatLocation: .peer(peerId)))
                        }))
                        
                    }
                }, theme.icons.composeNewSecretChat),SPopoverItem(tr(L10n.composePopoverNewChannel), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let navigation = strongSelf.navigationController {
                        createChannel(with: strongSelf.account, for: navigation)
                    }
                }, theme.icons.composeNewChannel)];
                
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-138,  -(strongSelf.genericView.compose.frame.maxY + 10)))
            }
        }, for: .Click)
        
        
        genericView.searchView.searchInteractions = SearchInteractions({ [weak self] state in
            guard let `self` = self else {return}
            self.genericView.searchStateChanged(state.state, animated: true)
            switch state.state {
            case .Focus:
               assert(self.searchController == nil)
                switch self.mode {
                case .plain:
                    self.showSearchController(animated: true)
                case .feedChannels:
                    if state.request.isEmpty {
                        self.hideSearchController(animated: true)
                    }
                }
                
            case .None:
                self.hideSearchController(animated: true)
            }
            
        }, { [weak self] state in
            guard let `self` = self else {return}
            switch self.mode {
            case .plain:
                self.searchController?.request(with: state.request)
            case .feedChannels:
                if state.request.isEmpty {
                    self.hideSearchController(animated: true)
                } else {
                    self.showSearchController(animated: true)
                    self.searchController?.request(with: state.request)
                }
            }
            
        })
        
        
    }
    
    private func showSearchController(animated: Bool) {
        
        if searchController == nil {
            let searchController = SearchController(account: self.account, open:{ [weak self] (peerId, message, close) in
                self?.open(with: .peer(peerId), message:message, close:close)
            }, options: searchOptions, frame:genericView.tableView.frame, groupId: self.mode.groupId)
           
            self.searchController = searchController
            
            searchController.navigationController = self.navigationController
            searchController.viewWillAppear(true)
            if animated {
                searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion:{ [weak self] complete in
                    if complete {
                        self?.searchController?.viewDidAppear(animated)
                    }
                })
            } else {
                searchController.viewDidAppear(animated)
            }
            
            
            self.addSubview(searchController.view)
        }
        
       
    }
    
    private func hideSearchController(animated: Bool) {
        if let searchController = self.searchController {
            searchController.viewWillDisappear(animated)
            searchController.view.layer?.opacity = animated ? 1.0 : 0.0
            searchController.view._change(opacity: 0, animated: animated, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
              // if completed {
                    self?.searchController?.viewDidDisappear(true)
                    self?.searchController?.removeFromSuperview()
                    self?.searchController = nil
              //  }
            })
        }
    }
   
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
       
        if animated {
            genericView.tableView.layoutItems()
        }
        
        if account.context.layout == .single && animated {
            globalPeerHandler.set(.single(nil))
        }
        layoutDisposable.set(account.context.layoutHandler.get().start(next: { [weak self] state in
            if let strongSelf = self, case .minimisize = state {
                if strongSelf.genericView.searchView.state == .Focus {
                    strongSelf.genericView.searchView.change(state: .None,  false)
                }
            }
            self?.genericView.tableView.reloadData()
        }))
        
        account.context.globalSearch = { [weak self] query in
            if let strongSelf = self {
                _ = (strongSelf.account.context.layoutHandler.get() |> take(1)).start(next: { [weak strongSelf] state in
                    if let strongSelf = strongSelf {
                        
                        let invoke = { [weak strongSelf] in
                            strongSelf?.genericView.searchView.change(state: .Focus, false)
                            strongSelf?.genericView.searchView.setString(query)
                        }
                        
                        switch state {
                        case .single:
                            strongSelf.account.context.mainNavigation?.back()
                            Queue.mainQueue().justDispatch(invoke)
                        case .minimisize:
                            (strongSelf.window?.contentView?.subviews.first as? SplitView)?.needFullsize()
                            Queue.mainQueue().justDispatch {
                                if strongSelf.navigationController?.controller is ChatController {
                                    strongSelf.navigationController?.back()
                                    Queue.mainQueue().justDispatch(invoke)
                                }
                            }
                        default:
                            invoke()
                        }
                        
                    }
                })
            }
        }
        
    }
    
    public override func escapeKeyAction() -> KeyHandlerResult {
        guard account.context.layout != .minimisize else {
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
        return .rejected
    }
    
    func open(with chatLocation: ChatLocation, message:Message? = nil, initialAction: ChatInitialAction? = nil, close:Bool = true, addition: Bool = false) ->Void {
        if let navigation = navigationController {
            
            if let modalAction = navigation.modalAction as? FWDNavigationAction, chatLocation.peerId == account.peerId {
                _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, account: account, peerId: account.peerId).start()
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                modalAction.afterInvoke()
                navigation.removeModalAction()
            } else {
                let chat:ChatController = addition ? ChatAdditionController(account: self.account, chatLocation: chatLocation, messageId: message?.id) : ChatController(account: self.account, chatLocation: chatLocation, messageId: message?.id, initialAction: initialAction)
                navigation.push(chat, self.account.context.layout == .single)
            }
        }
        if close {
            self.genericView.searchView.cancel(true)
        }
    }
    
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
       
    }
    
    func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return true
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
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
        
        switch mode {
        case .plain:
            self.window?.set(handler: { [weak self] in
                if let strongSelf = self {
                    return strongSelf.escapeKeyAction()
                }
                return .invokeNext
            }, with: self, for: .Escape, priority:.low)
            
            
            self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
                if let item = self?.effectiveTableView.selectedItem(), item.index > 0 {
                    self?.effectiveTableView.selectPrev()
                }
                return .invoked
            }, with: self, for: .UpArrow, priority: .medium, modifierFlags: [.option])
            
            self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
                self?.effectiveTableView.selectNext()
                return .invoked
            }, with: self, for: .DownArrow, priority:.medium, modifierFlags: [.option])
            
            self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
                self?.effectiveTableView.selectNext()
                return .invoked
            }, with: self, for: .Tab, priority: .low, modifierFlags: [.control])
            
            self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
                self?.effectiveTableView.selectPrev()
                return .invoked
            }, with: self, for: .Tab, priority:.medium, modifierFlags: [.control, .shift])
            
            #if DEBUG
                self.window?.set(handler: { () -> KeyHandlerResult in
                    _ = updateBubbledSettings(postbox: self.account.postbox, bubbled: !theme.bubbled).start()
                    return .invoked
                }, with: self, for: .T, priority:.medium, modifierFlags: [.control])
            #endif
        default:
            break
        }
        
        
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.removeAllHandlers(for: self)

    }
    
}
