//
//  PeerMediaGiftsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 05.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit



private final class Arguments {
    let context: AccountContext
    let open:(ProfileGiftsContext.State.StarGift)->Void
    init(context: AccountContext, open:@escaping(ProfileGiftsContext.State.StarGift)->Void) {
        self.context = context
        self.open = open
    }
}

private struct State : Equatable {
    var gifts: [ProfileGiftsContext.State.StarGift] = []
    var perRowCount: Int = 3
    var peer: EnginePeer?
    var state: ProfileGiftsContext.State?
}

private func _id_stars_gifts(_ index: Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_stars_gifts_\(index)")
}
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
  
    let chunks = state.gifts.chunks(state.perRowCount)
    
    for (i, chunk) in chunks.enumerated() {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stars_gifts(i), equatable: .init(chunk), comparable: nil, item: { initialSize, stableId in
            return GiftOptionsRowItem(initialSize, stableId: stableId, context: arguments.context, options: chunk.map { .initialize($0) }, perRowCount: state.perRowCount, fitToSize: true, insets: NSEdgeInsets(), callback: { option in
                if let value = option.nativeProfileGift {
                    arguments.open(value)
                }
            })
        }))
        
        entries.append(.sectionId(sectionId, type: .customModern(10)))
        sectionId += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PeerMediaGiftsController(context: AccountContext, peerId: PeerId, starGiftsProfile: ProfileGiftsContext? = nil) -> InputDataController {

    let actionsDisposable = DisposableSet()

    
    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }
    
    let giftsContext = starGiftsProfile ?? ProfileGiftsContext(account: context.account, peerId: peerId)
        
    let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    actionsDisposable.add(combineLatest(giftsContext.state, peer).startStrict(next: { gifts, peer in
        updateState { current in
            var current = current
            current.gifts = gifts.filteredGifts
            current.state = gifts
            current.peer = peer
            return current
        }
    }))

    let arguments = Arguments(context: context, open: { [weak giftsContext] option in
        
        let toPeer = stateValue.with { $0.peer }
        let fromPeer = option.fromPeer
        
        let transaction = StarsContext.State.Transaction(flags: [], id: "", count: .init(value: option.gift.generic?.price ?? 0, nanos: 0), date: option.date, peer: toPeer.flatMap { .peer($0) } ?? .unsupported, title: "", description: nil, photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil, starGift: option.gift, floodskipNumber: nil, starrefCommissionPermille: nil, starrefPeerId: nil, starrefAmount: nil)
        
        
        let purpose: Star_TransactionPurpose = .starGift(gift: option.gift, convertStars: option.convertStars ?? 0, text: option.text, entities: option.entities, nameHidden: option.fromPeer != nil, savedToProfile: option.savedToProfile, converted: option.convertStars == nil, fromProfile: true, upgraded: false, transferStars: option.convertStars, canExportDate: option.canExportDate, reference: option.reference, sender: nil, saverId: nil)
        
        switch option.gift {
        case let .unique(gift):
            showModal(with: StarGift_Nft_Controller(context: context, gift: option.gift, source: .quickLook(gift), transaction: transaction, purpose: .starGift(gift: option.gift, convertStars: option.convertStars, text: option.text, entities: option.entities, nameHidden: option.nameHidden, savedToProfile: option.savedToProfile, converted: false, fromProfile: true, upgraded: false, transferStars: option.transferStars, canExportDate: option.canExportDate, reference: option.reference, sender: option.fromPeer, saverId: nil)), for: context.window)
        default:
            showModal(with: Star_TransactionScreen(context: context, fromPeerId: peerId, peer: fromPeer, transaction: transaction, purpose: purpose, reference: option.reference, profileContext: giftsContext), for: context.window)
        }
        

    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller._menuItems = { [weak giftsContext] in
        var items: [ContextMenuItem] = []
        
        let state = stateValue.with { $0 }
        
        if let peer = state.peer?._asPeer(), peer.isChannel, let notificationsEnabled = state.state?.notificationsEnabled {
            items.append(ContextMenuItem(strings().peerInfoGiftsChannelNotify, handler: {
                _ = context.engine.payments.toggleStarGiftsNotifications(peerId: peer.id, enabled: !notificationsEnabled).start()
                updateState { current in
                    var current = current
                    current.state?.notificationsEnabled = !notificationsEnabled
                    return current
                }
                showModalText(for: context.window, text: !notificationsEnabled ? strings().peerInfoGiftsChannelNotifyTooltip : strings().peerInfoGiftsChannelNotifyDisabledTooltip)
            }, state: notificationsEnabled ? .on : nil))
            
            items.append(ContextSeparatorItem())
        }
        if let peer = state.peer?._asPeer(), let giftState = state.state, peer.isChannel, peer.isAdmin {
            
            let toggleFilter: (ProfileGiftsContext.Filters) -> Void = { [weak giftsContext] value in
                var updatedFilter = giftState.filter
                if updatedFilter.contains(value) {
                    updatedFilter.remove(value)
                } else {
                    updatedFilter.insert(value)
                }
                if !updatedFilter.contains(.unlimited) && !updatedFilter.contains(.limited) && !updatedFilter.contains(.unique) {
                    updatedFilter.insert(.unlimited)
                }
                if !updatedFilter.contains(.displayed) && !updatedFilter.contains(.hidden) {
                    if value == .displayed {
                        updatedFilter.insert(.hidden)
                    } else {
                        updatedFilter.insert(.displayed)
                    }
                }
                giftsContext?.updateFilter(updatedFilter)
            }

            
            items.append(ContextMenuItem(giftState.sorting == .value ? strings().peerInfoGiftsSortByDate : strings().peerInfoGiftsSortByValue, handler: {
                giftsContext?.updateSorting(giftState.sorting == .value ? .date : .value)
            }))
            
            items.append(ContextSeparatorItem())
            
            items.append(ContextMenuItem(strings().peerInfoGiftsUnlimited, handler: {
                toggleFilter(.unlimited)
            }, state: giftState.filter.contains(.unlimited) ? .on : nil))
            
            items.append(ContextMenuItem(strings().peerInfoGiftsLimited, handler: {
                toggleFilter(.limited)
            }, state: giftState.filter.contains(.limited) ? .on : nil))
            
            items.append(ContextMenuItem(strings().peerInfoGiftsUnique, handler: {
                toggleFilter(.unique)
            }, state: giftState.filter.contains(.unique) ? .on : nil))
            
            items.append(ContextSeparatorItem())
            
            items.append(ContextMenuItem(strings().peerInfoGiftsDisplayed, handler: {
                toggleFilter(.displayed)
            }, state: giftState.filter.contains(.displayed) ? .on : nil))
            
            items.append(ContextMenuItem(strings().peerInfoGiftsHidden, handler: {
                toggleFilter(.hidden)
            }, state: giftState.filter.contains(.hidden) ? .on : nil))
        }
       
        
        return items
    }
    
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    controller.didResize = { controller in
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        let blockWidth = max(380, min(600, controller.atomicSize.with { $0.width }))
        while true {
            let maximum = blockWidth - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 110 {
                break
            } else {
                rowCount -= 1
            }
        }
        updateState { current in
            var current = current
            current.perRowCount = rowCount
            return current
        }
    }
    
    controller.didLoad = { [weak giftsContext] controller, _ in
        controller.tableView.setScrollHandler { position in
            switch position.direction {
            case .bottom:
                giftsContext?.loadMore()
            default:
                break
            }
        }
    }
    
    controller.contextObject = giftsContext

    return controller
    
}




