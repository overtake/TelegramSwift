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

/*
 
 class PeerListContainerView : View {
 var tableView = TableView(frame:NSZeroRect, drawBorder: true) {
 didSet {
 oldValue.removeFromSuperview()
 addSubview(tableView)
 }
 }
 let searchView:SearchView = SearchView(frame:NSZeroRect)
 fileprivate let proxyButton:ImageButton = ImageButton()
 private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 11, 11))
 
 private let titleView = TextView()
 
 private let separatorView = View()
 
 let compose:ImageButton = ImageButton()
 private let headerContainerView = View()
 private let searchContainerView = View()
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
 headerContainerView.addSubview(compose)
 headerContainerView.addSubview(proxyButton)
 headerContainerView.addSubview(titleView)
 searchContainerView.addSubview(searchView)
 addSubview(separatorView)
 addSubview(headerContainerView)
 addSubview(searchContainerView)
 
 proxyButton.addSubview(proxyConnecting)
 setFrameSize(frameRect.size)
 updateLocalizationAndTheme(theme: theme)
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
 needsLayout = true
 }
 
 func searchStateChanged(_ state: SearchFieldState, animated: Bool) {
 self.searchState = state
 
 searchContainerView.change(pos: NSMakePoint(0, state == .Focus ? 10 : headerContainerView.frame.height), animated: animated)
 headerContainerView.change(pos: NSMakePoint(0, state == .Focus ? -headerContainerView.frame.height : 0), animated: animated)
 
 //  searchView.change(size: NSMakeSize(state == .Focus ? frame.width - searchView.frame.minX * 2 : (frame.width - (!mode.isFeedChannels ? 36 + compose.frame.width : 20) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30), animated: animated)
 // compose.change(opacity: state == .Focus ? 0 : 1, animated: animated)
 // proxyButton.change(opacity: state == .Focus ? 0 : 1, animated: animated)
 }
 
 override func updateLocalizationAndTheme(theme: PresentationTheme) {
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
 proxyConnecting.lineWidth = 1.0
 
 separatorView.backgroundColor = theme.colors.border
 
 headerContainerView.border = [.Right]
 searchContainerView.border = [.Right]
 headerContainerView.backgroundColor = theme.colors.background
 searchContainerView.backgroundColor = theme.colors.background
 
 let titleLayout = TextViewLayout.init(.initialize(string: "Chats", color: theme.colors.text, font: .medium(.title)), maximumNumberOfLines: 1, alwaysStaticItems: true)
 titleLayout.measure(width: .greatestFiniteMagnitude)
 
 titleView.update(titleLayout)
 
 super.updateLocalizationAndTheme(theme: theme)
 }
 
 required init?(coder: NSCoder) {
 fatalError("init(coder:) has not been implemented")
 }
 
 override func layout() {
 super.layout()
 
 
 headerContainerView.frame = NSMakeRect(0, searchState == .Focus ? -headerContainerView.frame.height : 0, frame.width, 50)
 searchContainerView.frame = NSMakeRect(0, searchState == .Focus ? 10 : headerContainerView.frame.maxY, frame.width, 40)
 
 let offset: CGFloat = searchState == .Focus ? searchContainerView.frame.height : headerContainerView.frame.height + searchContainerView.frame.height
 
 
 searchView.frame = NSMakeRect(10, 0, searchContainerView.frame.width - 20, 30)
 
 
 tableView.frame = NSMakeRect(0, offset, frame.width, frame.height - offset)
 
 //        searchView.isHidden = frame.width < 200
 //        if searchView.isHidden {
 //            compose.centerX(y: floorToScreenPixels(backingScaleFactor, (49 - compose.frame.height)/2.0))
 //            proxyButton.setFrameOrigin(-proxyButton.frame.width, 0)
 //        } else {
 //            compose.setFrameOrigin(frame.width - 12 - compose.frame.width, floorToScreenPixels(backingScaleFactor, (offset - compose.frame.height)/2.0))
 //            proxyButton.setFrameOrigin(frame.width - 12 - compose.frame.width - proxyButton.frame.width - 6, floorToScreenPixels(backingScaleFactor, (offset - proxyButton.frame.height)/2.0))
 //        }
 
 proxyConnecting.centerX()
 proxyConnecting.centerY(addition: -(backingScaleFactor == 2.0 ? 0.5 : 0))
 
 titleView.center()
 compose.centerY(x: frame.width - compose.frame.width - 10)
 
 separatorView.frame = NSMakeRect(0, searchContainerView.frame.maxY, frame.width, .borderSize)
 
 self.needsDisplay = true
 }
 
 }

 */


class PeerListContainerView : View {
    private let backgroundView = BackgroundView(frame: NSZeroRect)
    var tableView = TableView(frame:NSZeroRect, drawBorder: true) {
        didSet {
            oldValue.removeFromSuperview()
            addSubview(tableView)
        }
    }
    let searchView:SearchView = SearchView(frame:NSMakeRect(10, 0, 0, 0))
    let compose:ImageButton = ImageButton()
    fileprivate let proxyButton:ImageButton = ImageButton()
    private let proxyConnecting: ProgressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 11, 11))
    private var searchState: SearchFieldState = .None
    
    var mode: PeerListMode = .plain {
        didSet {
            switch mode {
            case .folder:
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
        updateLocalizationAndTheme(theme: theme)
        proxyButton.disableActions()
        addSubview(backgroundView)
        backgroundView.isHidden = true
        
        tableView.getBackgroundColor = {
            .clear
        }
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
    
    func searchStateChanged(_ state: SearchFieldState, animated: Bool) {
        self.searchState = state
        searchView.change(size: NSMakeSize(state == .Focus || mode.isFolder ? frame.width - searchView.frame.minX * 2 : (frame.width - (36 + compose.frame.width) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30), animated: animated)
        compose.change(opacity: state == .Focus ? 0 : 1, animated: animated)
        proxyButton.change(opacity: state == .Focus ? 0 : 1, animated: animated)
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
        
        searchView.setFrameSize(NSMakeSize(searchState == .Focus || mode.isFolder ? frame.width - searchView.frame.minX * 2 : (frame.width - (36 + compose.frame.width) - (proxyButton.isHidden ? 0 : proxyButton.frame.width + 12)), 30))
        tableView.setFrameSize(frame.width, frame.height - offset)
        
        searchView.isHidden = frame.width < 200
        if searchView.isHidden {
            compose.centerX(y: floorToScreenPixels(backingScaleFactor, (49 - compose.frame.height)/2.0))
            proxyButton.setFrameOrigin(-proxyButton.frame.width, 0)
        } else {
            compose.setFrameOrigin(frame.width - 12 - compose.frame.width, floorToScreenPixels(backingScaleFactor, (offset - compose.frame.height)/2.0))
            proxyButton.setFrameOrigin(frame.width - 12 - compose.frame.width - proxyButton.frame.width - 6, floorToScreenPixels(backingScaleFactor, (offset - proxyButton.frame.height)/2.0))
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
    
    var isFolder:Bool {
        switch self {
        case .folder:
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
        self.bar = .init(height: mode.isFolder ? 50 : 0)
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
//                if settings.0.enabled {
//
//                } else {
//                    actionsDisposable.add(updateProxySettingsInteractively(accountManager: context.sharedContext.accountManager, { current -> ProxySettings in
//                        if let first = current.servers.first {
//                            return current.withUpdatedActiveServer(first).withUpdatedEnabled(true)
//                        } else {
//                            return current
//                        }
//                    }).start())
//                }
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
                
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-138,  -(strongSelf.genericView.compose.frame.maxY + 10)))
            }
        }, for: .Click)
        
        
        genericView.searchView.searchInteractions = SearchInteractions({ [weak self] state, animated in
            guard let `self` = self else {return}
            self.genericView.searchStateChanged(state.state, animated: animated)
            switch state.state {
            case .Focus:
                assert(self.searchController == nil)
                self.showSearchController(animated: animated)
                
            case .None:
                self.hideSearchController(animated: animated)
            }
            
        }, { [weak self] state in
            guard let `self` = self else {return}
            self.searchController?.request(with: state.request)
        }, responderModified: { [weak self] state in
            self?.context.isInGlobalSearch = state.responder
        })
        
        
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
            self.genericView.tableView.changeSelection(stableId: UIChatListEntryId.chatId(location.peerId))
        } else {
            self.genericView.tableView.changeSelection(stableId: nil)
        }
    }
    
    private func showSearchController(animated: Bool) {
        if searchController == nil {
            delay(0.1, closure: {
                let rect = self.genericView.tableView.frame
                let searchController = SearchController(context: self.context, open:{ [weak self] (peerId, messageId, close) in
                    if let peerId = peerId {
                        self?.open(with: .chatId(peerId), messageId: messageId, close:close)
                    } else {
                        self?.genericView.searchView.cancel(true)
                    }
                    }, options: self.searchOptions, frame:NSMakeRect(rect.minX, rect.minY, self.frame.width, rect.height))
                
                searchController.pinnedItems = self.collectPinnedItems
                
                self.searchController = searchController
                self.genericView.tableView.change(opacity: 0, animated: animated, completion: { [weak self] _ in
                    self?.genericView.tableView.isHidden = true
                })
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
            })
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
        
        switch entryId {
        case let .chatId(peerId):
            let navigation = context.sharedContext.bindings.rootNavigation()
            
            if let modalAction = navigation.modalAction as? FWDNavigationAction, peerId == context.peerId {
                _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, context: context, peerId: context.peerId).start()
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                modalAction.afterInvoke()
                navigation.removeModalAction()
            } else {
                let chat:ChatController = addition ? ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: messageId) : ChatController(context: self.context, chatLocation: .peer(peerId), messageId: messageId, initialAction: initialAction)
                navigation.push(chat, context.sharedContext.layout == .single)
            }
        case let .groupId(groupId):
            self.navigationController?.push(ChatListController(context, modal: false, groupId: groupId))
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
