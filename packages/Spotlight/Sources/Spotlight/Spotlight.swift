//
//  TestSpotlight.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import CoreSpotlight

import TelegramCore
import Postbox
import SwiftSignalKit
import TGUIKit
import MurMurHash32

enum SpotlightIdentifierSource : Equatable {
    case peerId(PeerId)
    
    fileprivate var stringValue: String {
        switch self {
        case let .peerId(peerId):
            return "peerId:\(peerId.toInt64())"
        }
    }
}

struct SpotlightIdentifier : Hashable {
    let recordId: AccountRecordId
    let source:SpotlightIdentifierSource
    
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }
    
    fileprivate var stringValue: String {
        return "accountId=\(recordId.int64)&source=\(source.stringValue)"
    }
}
@available(macOS 10.13, *)
private func makeSearchItem(for peer: Peer, index: Int, accountPeer: Peer, accountId: AccountRecordId) -> SpotlightItem {
    let key = SpotlightIdentifier(recordId: accountId, source: .peerId(peer.id))
    let attributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeData as String)
    attributeSet.title = peer.displayTitle + " → \(accountPeer.addressName ?? accountPeer.displayTitle)"
    attributeSet.contentDescription = "Popular contact in telegram"
    attributeSet.thumbnailData = theme.icons.appUpdate.data
    attributeSet.creator = "Telegram"
    attributeSet.kind = "Contact"
    
    return .recentPeer(key, index, CSSearchableItem(uniqueIdentifier: key.stringValue, domainIdentifier: Bundle.main.bundleIdentifier!, attributeSet: attributeSet), peer)
}

private enum SpotlightItem : Identifiable, Comparable {
    static func == (lhs: SpotlightItem, rhs: SpotlightItem) -> Bool {
        switch lhs {
        case let .recentPeer(id, index, _, lhsPeer):
            if case .recentPeer(id, index, _, let rhsPeer) = rhs {
                return lhsPeer.isEqual(rhsPeer)
            } else {
                return false
            }
        }
    }
    
    case recentPeer(SpotlightIdentifier, Int, CSSearchableItem, Peer)

    static func < (lhs: SpotlightItem, rhs: SpotlightItem) -> Bool {
        return lhs.index < rhs.index
    }
    var index: Int {
        switch self {
        case let .recentPeer(_, index, _, _):
            return index
        }
    }
    var stableId: SpotlightIdentifier {
        switch self {
        case let .recentPeer(id, _, _, _):
            return id
        }
    }
    var item:CSSearchableItem {
        switch self {
        case let .recentPeer(_, _, item, _):
            return item
        }
    }
}



final class SpotlightContext {
    let engine: TelegramEngine
    private let disposable = MetaDisposable()
    private var previousItems:[SpotlightItem] = []
    init(engine: TelegramEngine) {
        self.engine = engine
        if #available(macOS 10.12, *) {
            let accountPeer = engine.account.postbox.loadedPeerWithId(engine.account.peerId)
            
            
            let recently = engine.peers.recentlySearchedPeers() |> map {
                $0.compactMap { $0.peer.chatMainPeer }
            } |> distinctUntilChanged(isEqual: { previous, current -> Bool in
                return previous.count == current.count
            })
            
            let peers:Signal<[Peer], NoError> = combineLatest(recently, engine.peers.recentPeers() |> mapToSignal { recent in
                switch recent {
                case .disabled:
                    return .single([])
                case let .peers(peers):
                    return .single(peers)
                }
            }) |> map {
                $0 + $1
            } |> distinctUntilChanged(isEqual: { previous, current -> Bool in
                return previous.count == current.count
            })
            
            
            
            let signal = combineLatest(queue: .mainQueue(), accountPeer, peers)
            
            
            
            disposable.set(signal.start(next: { [weak self] accountPeer, peers in
                guard let `self` = self else {
                    return
                }
                var items: [SpotlightItem] = []
                for (i, peer) in peers.enumerated() {
                    if #available(OSX 10.13, *) {
                        items.append(makeSearchItem(for: peer, index: i, accountPeer: accountPeer, accountId: engine.account.id))
                    } else {
                        // Fallback on earlier versions
                    }
                }
                
                let (delete, insert, update) = mergeListsStableWithUpdates(leftList: self.previousItems, rightList: items)
                
                if !insert.isEmpty || !update.isEmpty {
                    CSSearchableIndex.default().indexSearchableItems(insert.map { $0.1.item }, completionHandler: nil)
                    CSSearchableIndex.default().indexSearchableItems(update.map { $0.1.item }, completionHandler: nil)
                }
                
                var deleted: [SpotlightItem] = []
                for index in delete.reversed() {
                    deleted.append(self.previousItems.remove(at: index))
                }
                
                self.previousItems = items
                if !deleted.isEmpty {
                    CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: deleted.map { $0.stableId.stringValue }, completionHandler: nil)
                }
            }))
        }
       
    }
    
    deinit {
        if #available(OSX 10.12, *) {
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: previousItems.map { $0.stableId.stringValue }, completionHandler: nil)
        }
    }
}

func parseSpotlightIdentifier(_ unique: String) -> SpotlightIdentifier? {
    let (vars, _) = urlVars(with: unique)
    
    if let source = vars["source"], let rawAccountId = vars["accountId"], let int64AccountId = Int64(rawAccountId)  {
        let accountId = AccountRecordId(rawValue: int64AccountId)
        let sourceComponents = source.components(separatedBy: ":")
        if sourceComponents.count == 2 {
            switch sourceComponents[0] {
            case "peerId":
                if let id = Int64(sourceComponents[1]) {
                    let peerId = PeerId(id)
                    return SpotlightIdentifier(recordId: accountId, source: .peerId(peerId))
                }
            default:
                break
            }
        }
    }

    
    return nil
}

