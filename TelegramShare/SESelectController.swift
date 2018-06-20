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


extension Peer {
    
    var canSendMessage: Bool {
        if let channel = self as? TelegramChannel {
            if case .broadcast(_) = channel.info {
                return channel.hasAdminRights(.canPostMessages)
            } else if case .group(_) = channel.info  {
                return !channel.hasBannedRights(.banSendMessages)
            }
        } else if let group = self as? TelegramGroup {
            return group.membership == .Member
        } else if let secret = self as? TelegramSecretChat {
            switch secret.embeddedState {
            case .terminated:
                return false
            case .handshake:
                return false
            default:
                return true
            }
        }
        
        return true
    }
}


class ShareModalView : View {
    let searchView:SearchView = SearchView(frame: NSZeroRect)
    let tableView:TableView = TableView()
    let acceptView:TitleButton = TitleButton()
    let cancelView:TitleButton = TitleButton()
    let borderView:View = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.backgroundColor = theme.colors.background
        borderView.backgroundColor = theme.colors.border
        
        acceptView.style = ControlStyle(font: .medium(.text),foregroundColor: theme.colors.blueUI)
        acceptView.set(text: tr(L10n.shareExtensionShare), for: .Normal)
        acceptView.sizeToFit()
        
        cancelView.style = ControlStyle(font:.medium(.text),foregroundColor: theme.colors.blueUI)
        cancelView.set(text: tr(L10n.shareExtensionCancel), for: .Normal)
        cancelView.sizeToFit()
        
        addSubview(acceptView)
        addSubview(cancelView)
        addSubview(searchView)
        addSubview(tableView)
        addSubview(borderView)
    }
    
    override func layout() {
        super.layout()
        searchView.frame = NSMakeRect(10, 10, frame.width - 20, 30)
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
    let account:Account
    let context:NSExtensionContext
    init(_ account:Account, _ context:NSExtensionContext) {
        self.account = account
        self.context = context
    }
    
    private let progressView = SEModalProgressView()
    
    func perform(to entries:[PeerId], view: NSView) {
        
        var signals:[Signal<Float, Void>] = []
        
       
        
        var needWaitAsync = false
        var k:Int = 0
        let total = context.inputItems.reduce(0) { (current, item) -> Int in
            if let item = item as? NSExtensionItem {
                if let _ = item.attributedContentText?.string {
                    return current + 1
                } else if let attachments = item.attachments as? [NSItemProvider] {
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
                        self.context.completeRequest(returningItems: nil, completionHandler: nil)
                     })
                    
                    self.progressView.cancelImpl = {
                        self.cancel()
                        disposable.dispose()
                    }
 
                }
            }
        }
        
        for peerId in entries {
            for j in 0 ..< context.inputItems.count {
                if let item = context.inputItems[j] as? NSExtensionItem {
                    if let text = item.attributedContentText?.string {
                        signals.append(sendText(text, to:peerId))
                        k += 1
                        requestIfNeeded()
                    } else if let attachments = item.attachments as? [NSItemProvider] {
                        
                        for i in 0 ..< attachments.count {
                            attachments[i].loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil, completionHandler: { (coding, error) in
                                if let url = coding as? URL {
                                    if !url.isFileURL {
                                        signals.append(self.sendText(url.absoluteString, to:peerId))
                                    } else {
                                        signals.append(self.sendMedia(url, to:peerId))
                                    }
                                }
                                k += 1
                                requestIfNeeded()
                            })
                        }
                    }
                }
            }
        }
        
    }
    
    private func sendText(_ text:String, to peerId:PeerId) -> Signal<Float,Void> {
        return Signal<Float, Void>.single(0) |> then(standaloneSendMessage(account: self.account, peerId: peerId, text: text, attributes: [], media: nil, replyToMessageId: nil) |> mapError {_ in} |> map {_ in return 1})
    }
    
    private let queue:Queue = Queue(name: "proccessShareFilesQueue")
    
    private func prepareMedia(_ path: URL) -> Signal<StandaloneMedia, Void> {
        return Signal { subscriber in
            if let data = try? Data(contentsOf: path) {
                
                let mimeType = MIMEType(path.absoluteString.nsstring.pathExtension.lowercased())
                if mimeType.hasPrefix("image/") && !mimeType.hasSuffix("gif") {
                    
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
                    subscriber.putNext(StandaloneMedia.file(data: data, mimeType: mimeType, attributes: []))
                }
                
            }
            
            subscriber.putCompletion()
            return EmptyDisposable
        } |> runOn(queue)
    }
    
    
    
    private func sendMedia(_ path:URL, to peerId:PeerId) -> Signal<Float,Void> {
        return Signal<Float, Void>.single(0) |> then(prepareMedia(path) |> mapToSignal { media -> Signal<Float, Void> in
            return standaloneSendMessage(account: self.account, peerId: peerId, text: "", attributes: [], media: media, replyToMessageId: nil) |> mapError {_ in}
        })
    }
    
    func cancel() {
        let cancelError = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError, userInfo: nil)
        context.cancelRequest(withError: cancelError)
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



fileprivate func prepareEntries(from:[SelectablePeersEntry]?, to:[SelectablePeersEntry], account:Account, initialSize:NSSize, animated:Bool, selectInteraction:SelectPeerInteraction) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> {
    
    return Signal {subscriber in
        let (deleted,inserted,updated) = proccessEntries(from, right: to, { (entry) -> TableRowItem in
            
            switch entry {
            case let .plain(peer, _):
                return  ShortPeerRowItem(initialSize, peer: peer, account:account, height:40, photoSize:NSMakeSize(30,30), inset:NSEdgeInsets(left: 10, right:10), interactionType:.selectable(selectInteraction))
            case .emptySearch:
                return SearchEmptyRowItem(initialSize, stableId: SelectablePeersEntryStableId.emptySearch)
            }
            
            
        })
        
        let transition = TableEntriesTransition<[SelectablePeersEntry]>(deleted: deleted, inserted: inserted, updated:updated, entries:to, animated:animated, state: animated ? .none(nil) : .saveVisible(.lower))
        
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
        
        search.set(SearchState(state: .None, request: nil))
        
        let previous:Atomic<[SelectablePeersEntry]?> = Atomic(value: nil)
        let initialSize = self.atomicSize.modify({$0})
        let account = share.account
        let table = genericView.tableView
        let selectInteraction = self.selectInteractions
        selectInteraction.add(observer: self)
        
        let list:Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> = search.get() |> distinctUntilChanged |> mapToSignal { [weak self] search -> Signal<TableEntriesTransition<[SelectablePeersEntry]>,Void> in
            
            if search.state == .None {
                let signal:Signal<(ChatListView,ViewUpdateType),Void> = account.viewTracker.tailChatListView(groupId: nil, count: 100)
                
                
                return signal |> deliverOn(prepareQueue) |> mapToQueue { [weak self] (value) -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, Void> in
                    if let strongSelf = self {
                        var entries:[SelectablePeersEntry] = []
                        
                        let fromSearch = strongSelf.inSearchSelected.modify({$0})
                        let fromSetIds:Set<PeerId> = Set(fromSearch)
                        var fromPeers:[PeerId:Peer] = [:]
                        var contains:[PeerId:Peer] = [:]
                        
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
                        
                        return prepareEntries(from: previous.modify({$0}), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction) |> deliverOnMainQueue
                    }
                    return .never()
                }
            } else {
                return ( search.request.isEmpty ? recentPeers(account: account) |> map { recent -> [Peer] in
                    switch recent {
                    case .disabled:
                        return []
                    case let .peers(peers):
                        return peers
                    }
                    } : account.postbox.searchPeers(query: search.request.lowercased(), groupId: nil) |> map {
                        return $0.compactMap({$0.chatMainPeer}).filter({!($0 is TelegramSecretChat)}) }) |> deliverOn(prepareQueue) |> mapToSignal { peers -> Signal<TableEntriesTransition<[SelectablePeersEntry]>, Void> in
                    var entries:[SelectablePeersEntry] = []
                    var i:Int32 = Int32.max
                    for peer in peers {
                        if peer.canSendMessage {
                            let index = MessageIndex(id: MessageId(peerId: peer.id, namespace: 1, id: i), timestamp: i)
                            entries.append(.plain(peer, ChatListIndex(pinningIndex: nil, messageIndex: index)))
                            i -= 1
                        }
                        
                    }
                    if entries.isEmpty {
                        entries.append(.emptySearch)
                    }
                    entries.sort(by: <)
                    return prepareEntries(from: previous.modify({$0}), to: entries, account: account, initialSize: initialSize, animated: true, selectInteraction:selectInteraction) |> deliverOnMainQueue
                }
            }
            
        }
        
        disposable.set(list.start(next: { [weak self] (transition) in
            table.resetScrollNotifies()
            _ = previous.swap(transition.entries)
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
    }
    
}
