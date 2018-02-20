//
//  GIFViewController.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


struct RecentGifRow :Equatable {
    let entries:[RecentGifEntry]
    let results:[TelegramMediaFile]
    let sizes:[NSSize]
    
    func isFilled(for width:CGFloat) -> Bool {
        let sum:CGFloat = sizes.reduce(0, { (acc, size) -> CGFloat in
            return acc + size.width
        })
        if sum >= width {
            return true
        } else {
            return false
        }
    }
}
func ==(lhs:RecentGifRow, rhs:RecentGifRow) -> Bool {
    return lhs.entries == rhs.entries && lhs.results == rhs.results && lhs.sizes == rhs.sizes
}

func makeRecentGifEnties(_ results:[TelegramMediaFile], initialSize:NSSize) -> [RecentGifRowEntry] {
    var entries:[RecentGifEntry] = []
    var rows:[RecentGifRow] = []
    
    var dimensions:[NSSize] = []
    var results = results
    var index:Int = 0
    for result in results {
        entries.append(.gif(index: index, file: result))
        dimensions.append(result.dimensions ?? NSZeroSize)
        index += 1
    }
    
    var fitted:[[NSSize]] = []
    let f:Int = Int(round(initialSize.width / initialSize.height))
    while !dimensions.isEmpty {
        let row = fitPrettyDimensions(dimensions, isLastRow: f > dimensions.count, fitToHeight: false, perSize:initialSize)
        fitted.append(row)
        dimensions.removeSubrange(0 ..< row.count)
    }
    
    for row in fitted {
        let subentries = Array(entries.prefix(row.count))
        let subresult = Array(results.prefix(row.count))
        rows.append(RecentGifRow(entries: subentries, results: subresult, sizes: row))
        
        entries.removeSubrange(0 ..< row.count)
        results.removeSubrange(0 ..< row.count)
        
    }
    var idx:Int = 0
    return rows.map { row in
        let entry = RecentGifRowEntry.gif(index: idx, row: row)
        idx += 1
        return entry
    }
}


enum RecentGifEntry : Equatable {
    case gif(index:Int, file:TelegramMediaFile)
    var index:Int {
        switch self {
        case let .gif(index, _):
            return index
        }
    }
    
    var mediaId:MediaId {
        switch self {
        case let .gif(_, file):
            return file.id ?? MediaId(namespace: 0, id: 0)
        }
    }
}
func ==(lhs:RecentGifEntry, rhs: RecentGifEntry) -> Bool {
    switch lhs {
    case let .gif(lhsIndex, lhsFile):
        if case let .gif(rhsIndex, rhsFile) = rhs {
            return lhsIndex == rhsIndex && lhsFile.isEqual(rhsFile)
        } else {
            return false
        }
    }
}

enum RecentGifRowEntry : Comparable, Identifiable {
    case gif(index:Int, row: RecentGifRow)
    
    var index:Int {
        switch self {
        case let .gif(index, _):
            return index
        }
    }
    
    var stableId: AnyHashable {
        switch self {
        case let .gif(index: _, row: row):
            return row.entries.reduce("", { (current, row) -> String in
                return current + "index:\(row.index), id:\(row.mediaId)"
            }).hashValue
        }
    }
}
func ==(lhs:RecentGifRowEntry, rhs: RecentGifRowEntry) -> Bool {
    switch lhs {
    case let .gif(index, row):
        if case .gif(index, row) = rhs {
            return true
        } else {
            return false
        }
    }
}

func <(lhs:RecentGifRowEntry, rhs: RecentGifRowEntry) -> Bool {
    return lhs.index < rhs.index
}

private func prepareEntries(left:[RecentGifRowEntry], right:[RecentGifRowEntry], account:Account,  initialSize:NSSize, arguments: RecentGifsArguments) -> TableUpdateTransition {
   
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right, { entry -> TableRowItem in
        switch entry {
        case .gif:
            return RecentGIFRowItem(initialSize, account: account, entry: entry, arguments: arguments)
        }
    })
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated)
}

private func recentEntries(for view:OrderedItemListView?, initialSize:NSSize) -> [RecentGifRowEntry] {
    if let view = view {
        
        return makeRecentGifEnties(view.items.prefix(70).flatMap({($0.contents as? RecentMediaItem)?.media as? TelegramMediaFile}), initialSize: NSMakeSize(initialSize.width, 100))
    }
    return []
}

struct RecentGifsArguments {
    let sendGif:(TelegramMediaFile)->Void
}

final class TableContainer : View {
    fileprivate var tableView: TableView?
    fileprivate var restrictedView:RestrictionWrappedView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func updateRestricion(_ peer: Peer?) {
        if let peer = peer as? TelegramChannel {
            if peer.stickersRestricted, let bannedRights = peer.bannedRights {
                restrictedView?.removeFromSuperview()
                restrictedView = RestrictionWrappedView(bannedRights.untilDate != .max ? tr(L10n.channelPersmissionDeniedSendGifsUntil(bannedRights.formattedUntilDate)) : tr(L10n.channelPersmissionDeniedSendGifsForever))
                addSubview(restrictedView!)
            } else {
                restrictedView?.removeFromSuperview()
                restrictedView = nil
            }
        } else {
            restrictedView?.removeFromSuperview()
            restrictedView = nil
        }
        setFrameSize(frame.size)
        needsLayout = true
    }
    
    func reinstall() {
        tableView?.removeFromSuperview()
        tableView = TableView(frame: bounds)
        addSubview(tableView!)
        restrictedView?.removeFromSuperview()
        if let restrictedView = restrictedView {
            addSubview(restrictedView)
        }
    }
    

    func deinstall() {
        tableView?.removeFromSuperview()
        tableView = nil
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.restrictedView?.updateLocalizationAndTheme()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        tableView?.setFrameSize(newSize)
        restrictedView?.setFrameSize(newSize)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class GIFViewController: TelegramGenericViewController<TableContainer>, Notifable {
    private var interactions:EntertainmentInteractions?
    private var chatInteraction: ChatInteraction?
    private let disposable = MetaDisposable()
    init(account:Account) {
        super.init(account)
        bar = .init(height: 0)
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction?.remove(observer: self)
        self.chatInteraction = chatInteraction
        chatInteraction.add(observer: self)
        if isLoaded() {
            genericView.updateRestricion(chatInteraction.presentation.peer)
        }
    }
    
    func notify(with value: Any, oldValue: Any, animated: Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState, let peer = value.peer, let oldPeer = oldValue.peer {
            if peer.stickersRestricted != oldPeer.stickersRestricted {
                genericView.updateRestricion(peer)
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        return other === self
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disposable.set(nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        genericView.deinstall()
        ready.set(.single(false))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        
        genericView.reinstall()
        
        genericView.updateRestricion(chatInteraction?.presentation.peer)
        
        _ = atomicSize.swap(_frameRect.size)
        let arguments = RecentGifsArguments(sendGif: { [weak self] file in
            self?.interactions?.sendGIF(file)
        })
        
        let previous:Atomic<[RecentGifRowEntry]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let account = self.account
        
        let signal = account.postbox.combinedView(keys: [.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)]) |> deliverOn(prepareQueue) |> map { view -> TableUpdateTransition in
            let postboxView = view.views[.orderedItemList(id: Namespaces.OrderedItemList.CloudRecentGifs)] as! OrderedItemListView
            let entries = recentEntries(for: postboxView, initialSize: initialSize.modify({$0}))
            return prepareEntries(left: previous.swap(entries), right: entries, account: account, initialSize: initialSize.modify({$0}), arguments: arguments)
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.tableView?.merge(with: transition)
            self?.ready.set(.single(true))
        }))
    }
    
    
    
    deinit {
        disposable.dispose()
        chatInteraction?.remove(observer: self)
    }
    
}
