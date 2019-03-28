//
//  SelectController.swift
//  TelegramMac
//
//  Created by keepcoder on 04/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import TelegramCoreMac
import PostboxMac

class SelectAccountView: Control {
    
    init(_ accounts: [AccountWithInfo], primary: AccountRecordId, switchAccount: @escaping(AccountRecordId) -> Void, frame: NSRect) {
        super.init(frame: frame)
        backgroundColor = NSColor.black.withAlphaComponent(0.85)
        
        if let current = accounts.first(where: {$0.account.id == primary}) {
            
            let currentControl = AvatarControl(font: .avatar(12))
            currentControl.frame = NSMakeRect(frame.width - 30 - 10, 10, 30, 30)
            currentControl.setPeer(account: current.account, peer: current.peer)
            addSubview(currentControl)
            
            
            var y: CGFloat = currentControl.frame.maxY + 10
            for current in accounts {
                if current.account.id != primary {
                    let container = Button()
                    
                    container.autohighlight = true
                    
                    container.backgroundColor = .white
                    let nameView = TextView()
                    nameView.userInteractionEnabled = false
                    nameView.isSelectable = false
                    
                    let layout = TextViewLayout(.initialize(string: current.peer.compactDisplayTitle, color: .text, font: .medium(.text)), maximumNumberOfLines: 1)
                    layout.measure(width: 150)
                    
                    nameView.background = .white
                    nameView.update(layout)
                    
                    let control = AvatarControl(font: .avatar(12))
                    control.setFrameSize(30, 30)
                    control.setPeer(account: current.account, peer: current.peer)
                    control.userInteractionEnabled = false
                    
                    container.addSubview(control)
                    
                    container.addSubview(nameView)
                    
                    container.setFrameSize(NSMakeSize(5 + nameView.frame.width + 5 + control.frame.width, 30))
                    container.layer?.cornerRadius = container.frame.height / 2
                    
                    container.frame = NSMakeRect(frame.width - container.frame.width - 10, 10, container.frame.width, container.frame.height)
                    
                    control.centerY(x: container.frame.width - control.frame.width)
                    nameView.centerY(x: 5)

                    addSubview(container)
                    
                    container.set(handler: { [weak self] _ in
                        self?.change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, timingFunction: .spring, completion: { _ in
                            switchAccount(current.account.id)
                        })
                       
                    }, for: .Click)
                    
                    container._change(pos: NSMakePoint(container.frame.minX, y), animated: true, timingFunction: .spring)
                    container.layer?.animateAlpha(from: 0, to: 1, duration: 0.2, timingFunction: .spring)
                    y += container.frame.height + 10
                }
            }
            
            set(handler: { [weak self] _ in
                self?.change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, timingFunction: .spring, completion: { [weak self] completed in
                    self?.removeFromSuperview()
                })
            }, for: .SingleClick)
        }
        
    }
    
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class ShareModalView : View {
    let searchView:SearchView = SearchView(frame: NSZeroRect)
    let tableView:TableView = TableView()
    let acceptView:TitleButton = TitleButton()
    let cancelView:TitleButton = TitleButton()
    private var photoView: AvatarControl?
    private var control: Control = Control()
    let borderView:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        borderView.backgroundColor = theme.colors.border
        
        acceptView.style = ControlStyle(font: .medium(.text),foregroundColor: theme.colors.blueUI)
        acceptView.set(text: L10n.shareExtensionShare, for: .Normal)
        _ = acceptView.sizeToFit()
        
        cancelView.style = ControlStyle(font:.medium(.text),foregroundColor: theme.colors.blueUI)
        cancelView.set(text: L10n.shareExtensionCancel, for: .Normal)
        _ = cancelView.sizeToFit()
        
        addSubview(acceptView)
        addSubview(cancelView)
        addSubview(searchView)
        addSubview(tableView)
        addSubview(borderView)
        addSubview(control)
    }
    
    func updateWithAccounts(_ accounts: (primary: AccountRecordId?, accounts: [AccountWithInfo]), context: AccountContext) -> Void {
        if accounts.accounts.count > 1, let primary = accounts.primary {
            if photoView == nil {
                photoView = AvatarControl(font: .avatar(12))
                photoView?.setFrameSize(NSMakeSize(30, 30))
                addSubview(photoView!)
            }
            if let account = accounts.accounts.first(where: {$0.account.id == primary}) {
                photoView?.setPeer(account: account.account, peer: account.peer)
            }
            photoView?.removeAllHandlers()
            
           
            
            photoView?.set(handler: { [weak self] _ in
                guard let `self` = self else {return}
                let view = SelectAccountView(accounts.accounts, primary: primary, switchAccount: { recordId in
                    context.sharedContext.switchToAccount(id: recordId, action: nil)
                }, frame: self.bounds)
                self.addSubview(view)
                view.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }, for: .Click)
        } else {
            photoView?.removeFromSuperview()
            photoView = nil
        }
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let photoView = photoView {
            photoView.setFrameOrigin(frame.width - photoView.frame.width - 10, 10)
            searchView.frame = NSMakeRect(10, 10, frame.width - 20 - photoView.frame.width - 10, 30)
        } else {
            searchView.frame = NSMakeRect(10, 10, frame.width - 20, 30)
        }
        control.frame = NSMakeRect(frame.width - 30 - 30, 10, 30, 30)
        tableView.frame = NSMakeRect(0, 50, frame.width, frame.height - 50 - 40)
        borderView.frame = NSMakeRect(0, tableView.frame.maxY, frame.width, .borderSize)
        acceptView.setFrameOrigin(frame.width - acceptView.frame.width - 30, floorToScreenPixels(scaleFactor: backingScaleFactor, tableView.frame.maxY + (40 - acceptView.frame.height) / 2.0))
        cancelView.setFrameOrigin(acceptView.frame.minX - cancelView.frame.width - 30, floorToScreenPixels(scaleFactor: backingScaleFactor, tableView.frame.maxY + (40 - cancelView.frame.height) / 2.0))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}


class ShareObject {
    let context: AccountContext
    let shareContext:NSExtensionContext
    init(_ context: AccountContext, _ shareContext:NSExtensionContext) {
        self.context = context
        self.shareContext = shareContext
    }
    
    private let progressView = SEModalProgressView()
    
    func perform(to entries:[PeerId], view: NSView) {
        
        var signals:[Signal<Float, NoError>] = []
        
       
        
        var needWaitAsync = false
        var k:Int = 0
        let total = shareContext.inputItems.reduce(0) { (current, item) -> Int in
            if let item = item as? NSExtensionItem {
                if let _ = item.attributedContentText?.string {
                    return current + 1
                } else if let attachments = item.attachments {
                    return current + attachments.count
                }
            }
            return current
        }
        
        func requestIfNeeded() {
            Queue.mainQueue().async {
                if k == total {
                    self.progressView.frame = view.bounds
                    view.addSubview(self.progressView)
                    
                    
                    let signal = combineLatest(signals) |> deliverOnMainQueue
                    
                    let disposable = signal.start(next: { states in
                        
                        let progress = states.reduce(0, { (current, value) -> Float in
                            return current + value
                        })
                        
                        self.progressView.set(progress: CGFloat(min(progress / Float(total), 1)))
                     }, completed: {
                        self.shareContext.completeRequest(returningItems: nil, completionHandler: nil)
                     })
                    
                    self.progressView.cancelImpl = {
                        self.cancel()
                        disposable.dispose()
                    }
 
                }
            }
        }
        
        for peerId in entries {
            for j in 0 ..< shareContext.inputItems.count {
                if let item = shareContext.inputItems[j] as? NSExtensionItem {
                    if let text = item.attributedContentText?.string {
                        signals.append(sendText(text, to:peerId))
                        k += 1
                        requestIfNeeded()
                    } else if let attachments = item.attachments {
                        
                        for i in 0 ..< attachments.count {
                            attachments[i].loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (coding, error) in
                                if let url = coding as? URL {
                                    if !url.isFileURL {
                                        signals.append(self.sendText(url.absoluteString, to:peerId))
                                    } else {
                                        signals.append(self.sendMedia(url, to:peerId))
                                    }
                                    k += 1
                                    requestIfNeeded()
                                }
                               
                            })
                            if k != total {
                                attachments[i].loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil, completionHandler: { (coding, error) in
                                    if let data = (coding as? NSImage)?.tiffRepresentation {
                                        signals.append(self.sendMedia(nil, data, to:peerId))
                                        k += 1
                                        requestIfNeeded()
                                    }
                                })
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    private func sendText(_ text:String, to peerId:PeerId) -> Signal<Float, NoError> {
        return Signal<Float, NoError>.single(0) |> then(standaloneSendMessage(account: context.account, peerId: peerId, text: text, attributes: [], media: nil, replyToMessageId: nil) |> `catch` {_ in return .complete()} |> map {_ in return 1})
    }
    
    private let queue:Queue = Queue(name: "proccessShareFilesQueue")
    
    private func prepareMedia(_ path: URL?, _ pasteData: Data? = nil) -> Signal<StandaloneMedia, NoError> {
        return Signal { subscriber in
            
            let data = pasteData ?? (path != nil ? try? Data(contentsOf: path!) : nil)
            
            if let data = data {
                var forceImage: Bool = false
                if let _ = NSImage(data: data) {
                    if let path = path {
                        let mimeType = MIMEType(path.path)
                        if mimeType.hasPrefix("image/") && !mimeType.hasSuffix("gif") {
                            forceImage = true
                        }
                    } else {
                        forceImage = true
                    }
                }
                
                if forceImage {
                    let options = NSMutableDictionary()
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailWithTransform as String)
                    options.setValue(1280 as NSNumber, forKey: kCGImageSourceThumbnailMaxPixelSize as String)
                    options.setValue(true as NSNumber, forKey: kCGImageSourceCreateThumbnailFromImageAlways as String)

                    if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
                        let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
                        if let image = image, let data = NSImage(cgImage: image, size: image.backingSize).tiffRepresentation(using: .jpeg, factor: 0.83) {
                            let imageRep = NSBitmapImageRep(data: data)
                            if let data = imageRep?.representation(using: .jpeg, properties: [:]) {
                                subscriber.putNext(StandaloneMedia.image(data))
                            }
                        }
                    }

                } else {
                    var mimeType: String = "application/octet-stream"
                    let fileName: String
                    if let path = path {
                        mimeType = MIMEType(path.path)
                        fileName = path.path.nsstring.lastPathComponent
                    } else {
                        fileName = "Unnamed.file"
                    }
                    
                    subscriber.putNext(StandaloneMedia.file(data: data, mimeType: mimeType, attributes: [.FileName(fileName: fileName)]))
                }
                
            }
            
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(queue)
    }
    
    
    
    private func sendMedia(_ path:URL?, _ data: Data? = nil, to peerId:PeerId) -> Signal<Float, NoError> {
        return Signal<Float, NoError>.single(0) |> then(prepareMedia(path, data) |> mapToSignal { media -> Signal<Float, NoError> in
            return standaloneSendMessage(account: self.context.account, peerId: peerId, text: "", attributes: [], media: media, replyToMessageId: nil) |> `catch` {_ in return .complete()}
        })
    }
    
    func cancel() {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        shareContext.cancelRequest(withError: cancelError)
    }
}



enum SelectablePeersEntryStableId : Hashable {
    case plain(Peer)
    case emptySearch
    
    var hashValue: Int {
        switch self {
        case let .plain(peer):
            return peer.id.hashValue
        case .emptySearch:
            return 0
        }
    }
    
    static func ==(lhs:SelectablePeersEntryStableId, rhs:SelectablePeersEntryStableId) -> Bool {
        switch lhs {
        case let .plain(lhsPeer):
            if case let .plain(rhsPeer) = rhs {
                return lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        case .emptySearch:
            if case .emptySearch = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

enum SelectablePeersEntry : Comparable, Identifiable {
    case plain(Peer, ChatListIndex)
    case emptySearch
    var stableId: SelectablePeersEntryStableId {
        switch self {
        case let .plain(peer,_):
            return .plain(peer)
        case .emptySearch:
            return .emptySearch
        }
    }
    
    var index:ChatListIndex {
        switch self {
        case let .plain(_,id):
            return id
        case .emptySearch:
            return ChatListIndex(pinningIndex: nil, messageIndex: MessageIndex.absoluteLowerBound())
        }
    }
}

func <(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs:SelectablePeersEntry, rhs:SelectablePeersEntry) -> Bool {
    switch lhs {
    case let .plain(lhsPeer, lhsIndex):
        if case let .plain(rhsPeer, rhsIndex) = rhs {
            return lhsPeer.isEqual(rhsPeer) && lhsIndex == rhsIndex
        } else {
            return false
        }
    case .emptySearch:
        if case .emptySearch = rhs {
            return true
        } else {
            return false
        }
    }
}



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], account:Account, initialSize:NSSize, animated:Bool, selectInteraction:SelectPeerInteraction) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, NoError> {
    
    return Signal {subscriber in
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { entry -> TableRowItem in
            switch entry {
            case let .plain(peer, _):
                return  ShortPeerRowItem(initialSize, peer: peer, account:account, height:40, photoSize:NSMakeSize(30,30), isLookSavedMessage: true, inset:NSEdgeInsets(left: 10, right:10), interactionType:.selectable(selectInteraction))
            case .emptySearch:
                return SearchEmptyRowItem(initialSize, stableId: SelectablePeersEntryStableId.emptySearch)
            }
        })
        
        let transition = TableEntriesTransition<[SelectablePeersEntry]>(deleted: deleted, inserted: inserted, updated:updated, entries:to, animated:animated, state: .none(nil))
        
        subscriber.putNext(transition)
        subscriber.putCompletion()
        return EmptyDisposable
        
    }
    
}

fileprivate struct SearchState : Equatable {
    let state:SearchFieldState
    let request:String
    init(state:SearchFieldState, request:String?) {
        self.state = state
        self.request = request ?? ""
    }
}

fileprivate func ==(lhs:SearchState, rhs:SearchState) -> Bool {
    return lhs.state == rhs.state && lhs.request == rhs.request
}

class SESelectController: GenericViewController<ShareModalView>, Notifable {
    private let share:ShareObject
    private let selectInteractions:SelectPeerInteraction = SelectPeerInteraction()
    private let search:ValuePromise<SearchState> = ValuePromise(ignoreRepeated: true)
    private let inSearchSelected:Atomic<[PeerId]> = Atomic(value:[])
    private let disposable:MetaDisposable = MetaDisposable()
    private let accountsDisposable = MetaDisposable()
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? SelectPeerPresentation, let oldValue = oldValue as? SelectPeerPresentation {
            if genericView.searchView.state == .Focus {
                let new = value.selected.subtracting(oldValue.selected)
                _ = inSearchSelected.modify { (peers) -> [PeerId] in
                    return new + peers
                }
            } else {
                
            }
        }
    }
    
    
    
    func isEqual(to other: Notifable) -> Bool {
        return false
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let context = self.share.context
        
        accountsDisposable.set((self.share.context.sharedContext.activeAccountsWithInfo |> deliverOnMainQueue).start(next: { [weak self] accounts in
            self?.genericView.updateWithAccounts(accounts, context: context)
        }))
        
        
        search.set(SearchState(state: .None, request: nil))
        
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        let initialSize = self.atomicSize.modify({$0})
        let account = share.context.account
        let table = genericView.tableView
        let selectInteraction = self.selectInteractions
        selectInteraction.add(observer: self)
        
        let list:Signal<TableEntriesTransition<[SelectablePeersEntry]>, NoError> = search.get() |> distinctUntilChanged |> mapToSignal { [weak self] search -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, NoError> in
            
            if search.state == .None {
                let signal:Signal<(ChatListView,ViewUpdateType), NoError> = account.viewTracker.tailChatListView(groupId: nil, count: 100) |> take(1)
                
                
                return combineLatest(signal, account.postbox.loadedPeerWithId(account.peerId)) |> deliverOn(prepareQueue) |> mapToQueue { [weak self] value, mainPeer -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, NoError> in
                    if let strongSelf = self {
                        var entries:[SelectablePeersEntry] = []
                        
                        let fromSearch = strongSelf.inSearchSelected.modify({$0})
                        let fromSetIds:Set<PeerId> = Set(fromSearch)
                        var fromPeers:[PeerId:Peer] = [:]
                        var contains:[PeerId:Peer] = [:]
                        
                        entries.append(.plain(mainPeer, ChatListIndex.init(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())))
                        contains[mainPeer.id] = mainPeer
                        
                        for entry in value.0.entries {
                            switch entry {
                            case let .MessageEntry(id, _, _, _, _, renderedPeer, _):
                                if let peer = renderedPeer.chatMainPeer {
                                    if !fromSetIds.contains(peer.id), contains[peer.id] == nil {
                                        if peer.canSendMessage {
                                            entries.append(.plain(peer,id))
                                            contains[peer.id] = peer
                                        }
                                    } else {
                                        fromPeers[peer.id] = peer
                                    }
                                }
                            default:
                                break
                            }
                        }
                        
                        var i:Int32 = Int32.max
                        for peerId in fromSearch {
                            if let peer = fromPeers[peerId] , contains[peer.id] == nil {
                                let index = MessageIndex(id: MessageId(peerId: peer.id, namespace: 1, id: i), timestamp: i)
                                entries.append(.plain(peer, ChatListIndex(pinningIndex: nil, messageIndex: index)))
                                contains[peer.id] = peer
                            }
                            i -= 1
                        }
                        entries.sort(by: <)
                        
                        return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction)
                    }
                    return .never()
                }
            } else {
                
                let signal: Signal<([Peer], Peer), NoError>
                
                if search.request.isEmpty {
                    signal = combineLatest(recentPeers(account: account) |> map { recent -> [Peer] in
                        switch recent {
                        case .disabled:
                            return []
                        case let .peers(peers):
                            return peers
                        }
                        }, account.postbox.loadedPeerWithId(account.peerId))
                    |> deliverOn(prepareQueue)
                } else {
                    let foundLocalPeers = account.postbox.searchPeers(query: search.request.lowercased(), groupId: nil) |> map {$0.compactMap { $0.chatMainPeer} }
                    
                    let foundRemotePeers:Signal<[Peer], NoError> = .single([]) |> then ( searchPeers(account: account, query: search.request.lowercased()) |> map { $0.map{$0.peer} + $1.map{$0.peer} } )

                    signal = combineLatest(combineLatest(foundLocalPeers, foundRemotePeers) |> map {$0 + $1}, account.postbox.loadedPeerWithId(account.peerId))
                    
                }
                
                let assignSavedMessages:Bool
                if search.request.isEmpty {
                    assignSavedMessages = true
                } else if L10n.peerSavedMessages.lowercased().hasPrefix(search.request.lowercased()) || "Saved Messages".lowercased().hasPrefix(search.request.lowercased()) {
                    assignSavedMessages = true
                } else {
                    assignSavedMessages = false
                }

                
                return signal |> mapToSignal { peers, mainPeer in
                    var entries:[SelectablePeersEntry] = []
                    var i:Int32 = Int32.max
                    
                    var contains: Set<PeerId> = Set()
                    if assignSavedMessages {
                        entries.append(.plain(mainPeer, ChatListIndex(pinningIndex: 0, messageIndex: MessageIndex.absoluteUpperBound())))
                        contains.insert(mainPeer.id)
                    }
                   
                    
                    for peer in peers {
                        if peer.canSendMessage, !contains.contains(peer.id) {
                            let index = MessageIndex(id: MessageId(peerId: peer.id, namespace: 1, id: i), timestamp: i)
                            entries.append(.plain(peer, ChatListIndex(pinningIndex: nil, messageIndex: index)))
                            contains.insert(peer.id)
                            i -= 1
                        }
                        
                    }
                    entries.sort(by: <)
                    return prepareEntries(from: previous.swap(entries), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction)
                }
                
            }
        }
        
        disposable.set((list |> deliverOnMainQueue).start(next: { [weak self] (transition) in
            table.resetScrollNotifies()
            table.merge(with:transition)
            self?.readyOnce()
        }))
        
        self.genericView.searchView.searchInteractions = SearchInteractions({ state in
            self.search.set(SearchState(state: state.state, request: state.request))
        }, { state in
            self.search.set(SearchState(state: state.state, request: state.request))
        })
        
        self.genericView.acceptView.set(handler: { _ in
            self.share.perform(to: Array(selectInteraction.presentation.selected), view: self.view)
        }, for: .Click)
        
        self.genericView.cancelView.set(handler: { [weak self] _ in
            self?.share.cancel()
        }, for: .Click)
        
    }
    
    override var canBecomeResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool? {
        return false
    }
    
    override func firstResponder() -> NSResponder? {
        return genericView.searchView.input
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if genericView.searchView.state == .Focus {
            return genericView.searchView.changeResponder() ? .invoked : .rejected
        }
        return .rejected
    }
    
    
    init(_ share:ShareObject) {
        self.share = share
        super.init(frame: NSMakeRect(0, 0, 300, 400))
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        disposable.set(nil)
    }
    
    deinit {
        disposable.dispose()
        accountsDisposable.dispose()
    }
    
}
