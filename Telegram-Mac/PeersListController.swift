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
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.border = [.Right]
        compose.autohighlight = false
        autoresizesSubviews = false
        addSubview(tableView)
        addSubview(searchView)
        addSubview(compose)
        setFrameSize(frameRect.size)
        updateLocalizationAndTheme()
    }
    
    override func updateLocalizationAndTheme() {
        self.backgroundColor = theme.colors.background
        compose.disableActions()
        compose.set(background: theme.colors.background, for: .Normal)
        compose.set(background: theme.colors.background, for: .Hover)
        compose.set(background: theme.colors.blueFill, for: .Highlight)
        compose.set(image: theme.icons.composeNewChat, for: .Normal)
        compose.set(image: theme.icons.composeNewChatActive, for: .Highlight)
        compose.layer?.cornerRadius = .cornerRadius
        compose.setFrameSize(NSMakeSize(40, 30))
        super.updateLocalizationAndTheme()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        searchView.setFrameSize(newSize.width - 36 - compose.frame.width, 30)
        tableView.setFrameSize(newSize.width, newSize.height - 49)
    }
    
    
    
    override func layout() {
        super.layout()
        searchView.isHidden = frame.width < 200
        if searchView.isHidden {
            compose.centerX(y: floorToScreenPixels((49 - compose.frame.height)/2.0))
        } else {
            compose.setFrameOrigin(frame.width - 12 - compose.frame.width, floorToScreenPixels((50 - compose.frame.height)/2.0))
        }
        searchView.setFrameOrigin(10, floorToScreenPixels((49 - searchView.frame.height)/2.0))
        tableView.setFrameOrigin(0, 49)
        self.needsDisplay = true
    }
}


class PeersListController: TelegramGenericViewController<PeerListContainerView>, TableViewDelegate {
    
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    
    private let globalPeerDisposable:MetaDisposable = MetaDisposable()
    private let progressDisposable = MetaDisposable()
    private let createSecretChatDisposable = MetaDisposable()
    private let layoutDisposable = MetaDisposable()
    private let followGlobal:Bool
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
    
    init(_ account:Account, followGlobal:Bool = true) {
        self.followGlobal = followGlobal
        
        super.init(account)

    }
    
    deinit {
        globalPeerDisposable.dispose()
        progressDisposable.dispose()
        createSecretChatDisposable.dispose()
        layoutDisposable.dispose()
    }
    
    override func viewDidResized(_ size: NSSize) {
        super.viewDidResized(size)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if followGlobal {
            globalPeerDisposable.set((globalPeerHandler.get() |> deliverOnMainQueue).start(next: { [weak self] peerId in
                self?.genericView.tableView.changeSelection(stableId: peerId)
            }))
        }
        
        if self.navigationController?.modalAction is FWDNavigationAction {
            self.setCenterTitle(tr(.chatForwardActionHeader))
        }
        
        if self.navigationController?.modalAction is ShareInlineResultNavigationAction {
            self.setCenterTitle(tr(.chatShareInlineResultActionHeader))
        }
        
        genericView.tableView.delegate = self
        let table = genericView.tableView
        
        
        
        
        genericView.compose.set(handler: { [weak self] control in
            if let strongSelf = self, !control.isSelected {
                
                let items = [SPopoverItem(tr(.composePopoverNewGroup), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let navigation = strongSelf.navigationController {
                        createGroup(with: strongSelf.account, for: navigation)
                    }
                    
                }, theme.icons.composeNewGroup),SPopoverItem(tr(.composePopoverNewSecretChat), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let account = self?.account {
                        let confirmationImpl:([PeerId])->Signal<Bool,Void> = { peerIds in
                            if let first = peerIds.first, peerIds.count == 1 {
                                return account.postbox.loadedPeerWithId(first) |> deliverOnMainQueue |> mapToSignal { peer in
                                    return confirmSignal(for: mainWindow, header: appName, information: tr(.composeConfirmStartSecretChat(peer.displayTitle)))
                                }
                            }
                            return confirmSignal(for: mainWindow, header: appName, information: tr(.peerInfoConfirmAddMembers1Countable(peerIds.count)))
                        }
                        let select = selectModalPeers(account: account, title: tr(.composeSelectSecretChat), limit: 1, confirmation: confirmationImpl)
                        
                        let create = select |> map { $0.first! } |> mapToSignal { peerId in
                            return createSecretChat(account: account, peerId: peerId) |> mapError {_ in}
                            } |> deliverOnMainQueue |> mapToSignal{ peerId -> Signal<PeerId, Void> in
                                return showModalProgress(signal: .single(peerId), for: mainWindow)
                        }
                        
                        strongSelf.createSecretChatDisposable.set(create.start(next: { [weak self] peerId in
                            self?.navigationController?.push(ChatController(account: account, peerId: peerId))
                        }))
                        
                    }
                }, theme.icons.composeNewSecretChat),SPopoverItem(tr(.composePopoverNewChannel), { [weak strongSelf] in
                    if let strongSelf = strongSelf, let navigation = strongSelf.navigationController {
                        createChannel(with: strongSelf.account, for: navigation)
                    }
                }, theme.icons.composeNewChannel)];
                
                showPopover(for: control, with: SPopoverViewController(items: items), edge: .maxY, inset: NSMakePoint(-138,  -(strongSelf.genericView.compose.frame.maxY + 10)))
            }
        }, for: .Click)
        
        
        genericView.searchView.searchInteractions = SearchInteractions({[weak self] (state) in
            if let strongSelf = self {
                switch state.state {
                case .Focus:
                    
                    assert(strongSelf.searchController == nil)
                    
                    let searchController = SearchController(account: strongSelf.account, open:{ [weak strongSelf] (peerId, message, close) in
                        strongSelf?.open(with: peerId, message:message, close:close)
                    }, frame:table.frame)
                    strongSelf.searchController = searchController
                
                    searchController.navigationController = strongSelf.navigationController
                    searchController.viewWillAppear(true)
                    searchController.view.layer?.opacity = 1.0
                    searchController.view.layer?.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, completion:{[weak strongSelf](complete) in
                        strongSelf?.searchController?.viewDidAppear(true)
                    })
                    
                    strongSelf.addSubview(searchController.view)
                case .None:
                    
                    assert(strongSelf.searchController != nil)
                    
                    let searchController = strongSelf.searchController!
                    searchController.viewWillDisappear(true)
                    searchController.view.layer?.opacity = 0.0
                    searchController.view.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, completion:{[weak strongSelf](complete) in
                        
                        strongSelf?.searchController?.viewDidDisappear(true)
                        strongSelf?.searchController?.removeFromSuperview()
                        strongSelf?.searchController = nil
                        
                    })
                    
                }
            }
            
            }, { [weak self] state in
                self?.searchController?.request(with: state.request)
        })
        
        readyOnce()
        
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
    
    func open(with peerId:PeerId, peer: Peer? = nil, message:Message? = nil, close:Bool = true) ->Void {
        if let navigation = navigationController {
            
            if peer?.canSendMessage == false {
                
            }
            
            if let modalAction = navigation.modalAction as? FWDNavigationAction, peerId == account.peerId {
                _ = Sender.forwardMessages(messageIds: modalAction.messages.map{$0.id}, account: account, peerId: account.peerId).start()
                _ = showModalSuccess(for: mainWindow, icon: theme.icons.successModalProgress, delay: 1.0).start()
                modalAction.afterInvoke()
                navigation.removeModalAction()
            } else {
                let chat:ChatController = ChatController(account: self.account, peerId:peerId, messageId:message?.id)
                navigation.push(chat)
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

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.window?.set(handler: { [weak self] in
            if let strongSelf = self {
                return strongSelf.escapeKeyAction()
            }
            return .invokeNext
        }, with: self, for: .Escape, priority:.low)
        
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
            if let item = self?.genericView.tableView.selectedItem(), item.index > 0 {
                self?.genericView.tableView.selectPrev()
            }
            return .invoked
        }, with: self, for: .UpArrow, priority: .medium, modifierFlags: [.option])
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectNext()
            return .invoked
        }, with: self, for: .DownArrow, priority:.medium, modifierFlags: [.option])
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectNext()
            return .invoked
        }, with: self, for: .Tab, priority: .low, modifierFlags: [.control])
        
        self.window?.set(handler: {[weak self] () -> KeyHandlerResult in
            self?.genericView.tableView.selectPrev()
            return .invoked
        }, with: self, for: .Tab, priority:.medium, modifierFlags: [.control, .shift])
        
        //#if DEBUG
        self.window?.set(handler: { () -> KeyHandlerResult in
                _ = updateBubbledSettings(postbox: self.account.postbox, bubbled: !theme.bubbled).start()
            return .invoked
        }, with: self, for: .T, priority:.medium, modifierFlags: [.control])
        //#endif
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.window?.removeAllHandlers(for: self)

    }
    
}
