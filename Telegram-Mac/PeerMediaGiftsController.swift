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
    let togglePin:(ProfileGiftsContext.State.StarGift)->Void
    let toggleWear:(ProfileGiftsContext.State.StarGift)->Void
    let transfer:(ProfileGiftsContext.State.StarGift)->Void
    let toggleVisibility:(ProfileGiftsContext.State.StarGift)->Void
    let copy:(ProfileGiftsContext.State.StarGift)->Void
    init(context: AccountContext, open:@escaping(ProfileGiftsContext.State.StarGift)->Void, togglePin:@escaping(ProfileGiftsContext.State.StarGift)->Void, toggleWear:@escaping(ProfileGiftsContext.State.StarGift)->Void, transfer:@escaping(ProfileGiftsContext.State.StarGift)->Void, toggleVisibility:@escaping(ProfileGiftsContext.State.StarGift)->Void, copy:@escaping(ProfileGiftsContext.State.StarGift)->Void) {
        self.context = context
        self.open = open
        self.togglePin = togglePin
        self.toggleWear = toggleWear
        self.transfer = transfer
        self.toggleVisibility = toggleVisibility
        self.copy = copy
    }
}

private struct State : Equatable {
    var gifts: [ProfileGiftsContext.State.StarGift] = []
    var perRowCount: Int = 3
    var peer: EnginePeer?
    var state: ProfileGiftsContext.State?
    var starsState: StarsContext.State?
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
            }, contextMenu: { option in
                if let profile = option.nativeProfileGift, let _ = profile.reference {
                    var items: [ContextMenuItem] = []
                    
                    if let unique = profile.gift.unique {
                        items.append(ContextMenuItem(!profile.pinnedToTop ? strings().chatListContextPin : strings().chatListContextUnpin, handler: {
                            arguments.togglePin(profile)
                        }, itemImage: !profile.pinnedToTop ? MenuAnimation.menu_pin.value : MenuAnimation.menu_unpin.value))
                        
                        let weared = unique.file?.fileId.id == state.peer?.emojiStatus?.fileId
                        
                        items.append(ContextMenuItem(weared ? strings().giftContextTakeOff : strings().giftContextWear, handler: {
                            arguments.toggleWear(profile)
                        }, itemImage: !weared ? MenuAnimation.menu_wear.value : MenuAnimation.menu_wearoff.value))
                        
                        items.append(ContextMenuItem(strings().modalCopyLink, handler: {
                            arguments.copy(profile)
                        }, itemImage: MenuAnimation.menu_copy.value))
                    }
                                       
                    items.append(ContextMenuItem(profile.savedToProfile ? strings().giftContextHide : strings().giftContextShow, handler: {
                        arguments.toggleVisibility(profile)
                    }, itemImage: profile.savedToProfile ? MenuAnimation.menu_show.value : MenuAnimation.menu_hide.value))
                    
                    
                    if let _ = profile.gift.unique {
                        items.append(ContextMenuItem(strings().giftContextTransfer, handler: {
                            arguments.transfer(profile)
                        }, itemImage: MenuAnimation.menu_transfer.value))
                    }
                    
                    
                    return items
                }
                return []
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
        
    let peer = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
    
    actionsDisposable.add(combineLatest(giftsContext.state, peer, context.starsContext.state).startStrict(next: { gifts, peer, starsState in
        updateState { current in
            var current = current
            current.gifts = gifts.filteredGifts
            current.state = gifts
            current.peer = peer
            current.starsState = starsState
            return current
        }
    }))

    let arguments = Arguments(context: context, open: { [weak giftsContext] option in
        
        let toPeer = stateValue.with { $0.peer }
        let fromPeer = option.fromPeer
        
        guard let toPeer else {
            return
        }
        
        let transaction = StarsContext.State.Transaction(flags: [], id: "", count: .init(amount: .init(value: option.gift.generic?.price ?? 0, nanos: 0), currency: .stars), date: option.date, peer: .peer(toPeer), title: "", description: nil, photo: nil, transactionDate: nil, transactionUrl: nil, paidMessageId: nil, giveawayMessageId: nil, media: [], subscriptionPeriod: nil, starGift: option.gift, floodskipNumber: nil, starrefCommissionPermille: nil, starrefPeerId: nil, starrefAmount: nil, paidMessageCount: nil, premiumGiftMonths: nil, adsProceedsFromDate: nil, adsProceedsToDate: nil)
        
        
        let purpose: Star_TransactionPurpose = .starGift(gift: option.gift, convertStars: option.convertStars ?? 0, text: option.text, entities: option.entities, nameHidden: option.fromPeer != nil, savedToProfile: option.savedToProfile, converted: option.convertStars == nil, fromProfile: true, upgraded: false, transferStars: option.convertStars, canExportDate: option.canExportDate, reference: option.reference, sender: nil, saverId: nil, canTransferDate: nil, canResaleDate: nil)
        
        switch option.gift {
        case let .unique(gift):
            showModal(with: StarGift_Nft_Controller(context: context, gift: option.gift, source: .quickLook(toPeer, gift), transaction: transaction, purpose: .starGift(gift: option.gift, convertStars: option.convertStars, text: option.text, entities: option.entities, nameHidden: option.nameHidden, savedToProfile: option.savedToProfile, converted: false, fromProfile: true, upgraded: false, transferStars: option.transferStars, canExportDate: option.canExportDate, reference: option.reference, sender: option.fromPeer, saverId: nil, canTransferDate: option.canTransferDate, canResaleDate: option.canResaleDate), giftsContext: giftsContext, pinnedInfo: option.reference.flatMap { .init(pinnedInfo: option.pinnedToTop, reference: $0) } ), for: context.window)
        default:
            showModal(with: Star_TransactionScreen(context: context, fromPeerId: peerId, peer: fromPeer, transaction: transaction, purpose: purpose, reference: option.reference, profileContext: giftsContext), for: context.window)
        }
        

    }, togglePin: { [weak giftsContext] option in
        if let reference = option.reference {
            giftsContext?.updateStarGiftPinnedToTop(reference: reference, pinnedToTop: !option.pinnedToTop)
        }
    }, toggleWear: { option in
        let peer = stateValue.with({ $0.peer?._asPeer() })
        if let peer {
            context.reactions.setStatus(option.gift.unique!.file!, peer: peer, timestamp: context.timestamp, timeout: nil, fromRect: nil, starGift: option.gift.unique)
        }
    }, transfer: { option in
        let state = stateValue.with { $0 }
        
        var additionalItem: SelectPeers_AdditionTopItem?
        
        
        var canExportDate: Int32? = option.canExportDate
        let transferStars: Int64? = option.transferStars
        let convertStars: Int64? = option.convertStars
        let reference: StarGiftReference? = option.reference
        
        
        if let canExportDate = canExportDate {
            additionalItem = .init(title: strings().giftTransferSendViaBlockchain, color: theme.colors.text, icon: NSImage(resource: .iconSendViaTon).precomposed(flipVertical: true), callback: {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                
                if currentTime > canExportDate, let unique = option.gift.unique, let reference {
                    
                    let data = ModalAlertData(title: nil, info: strings().giftWithdrawText(unique.title + " #\(unique.number)"), description: nil, ok: strings().giftWithdrawProceed, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                        return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: .init(context.myPeer!), context: context)
                    }))
                    
                    showModalAlert(for: window, data: data, completion: { result in
                        showModal(with: InputPasswordController(context: context, title: strings().giftWithdrawTitle, desc: strings().monetizationWithdrawEnterPasswordText, checker: { value in
                            return context.engine.payments.requestStarGiftWithdrawalUrl(reference: reference, password: value)
                            |> deliverOnMainQueue
                            |> afterNext { url in
                                execute(inapp: .external(link: url, false))
                            }
                            |> ignoreValues
                            |> mapError { error in
                                switch error {
                                case .invalidPassword:
                                    return .wrong
                                case .limitExceeded:
                                    return .custom(strings().loginFloodWait)
                                case .generic:
                                    return .generic
                                default:
                                    return .custom(strings().monetizationWithdrawErrorText)
                                }
                            }
                        }), for: context.window)
                    })
                    
                } else {
                    let delta = canExportDate - currentTime
                    let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                    alert(for: window, header: strings().giftTransferUnlockPendingTitle, info: strings().giftTransferUnlockPendingText(strings().timerDaysCountable(Int(days))))
                }
            })
        }
        
        _ = selectModalPeers(window: window, context: context, title: strings().giftTransferTitle, behavior: SelectChatsBehavior(settings: [.excludeBots, .contacts, .remote, .channels], limit: 1, additionTopItem: additionalItem)).start(next: { peerIds in
            if let peerId = peerIds.first {
                let peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)) |> deliverOnMainQueue
                
                _ = peer.startStandalone(next: { peer in
                    if let peer {
                                                
                        let info: String
                        let ok: String
                        
                        guard let reference = reference, let unique = option.gift.unique else {
                            return
                        }
                        
                        if let transferStars = transferStars, let starsState = state.starsState, starsState.balance.value < transferStars {
                            showModal(with: Star_ListScreen(context: context, source: .buy(suffix: nil, amount: transferStars)), for: window)
                            return
                        }
                        
                        if let stars = transferStars, stars > 0 {
                            info = strings().giftTransferConfirmationText("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle, strings().starListItemCountCountable(Int(stars)))
                            ok = strings().giftTransferConfirmationTransfer + " " + strings().starListItemCountCountable(Int(stars))
                        } else {
                            info = strings().giftTransferConfirmationTextFree("\(unique.title) #\(unique.number)", peer._asPeer().displayTitle)
                            ok = strings().giftTransferConfirmationTransferFree
                        }
                
                        let data = ModalAlertData(title: nil, info: info, description: nil, ok: ok, options: [], mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                            return TransferUniqueGiftHeaderItem(initialSize, stableId: stableId, gift: unique, toPeer: peer, context: context)
                        }))
                        
                        showModalAlert(for: window, data: data, completion: { result in
                            _ = giftsContext.transferStarGift(prepaid: transferStars == nil, reference: reference, peerId: peerId).startStandalone()
                            _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
                        })
                    }
                })
            }
        })
    }, toggleVisibility: { [weak giftsContext] option in
        if let reference = option.reference {
            giftsContext?.updateStarGiftAddedToProfile(reference: reference, added: !option.savedToProfile)
        }
    }, copy: { option in
        copyToClipboard(option.gift.unique!.link)
        showModalText(for: window, text: strings().contextAlertCopied)
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
        if let peer = state.peer?._asPeer(), let giftState = state.state {
            
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
            
            if peer.groupAccess.canManageGifts || peer.id == context.peerId {
                items.append(ContextSeparatorItem())
                
                items.append(ContextMenuItem(strings().peerInfoGiftsDisplayed, handler: {
                    toggleFilter(.displayed)
                }, state: giftState.filter.contains(.displayed) ? .on : nil))
                
                items.append(ContextMenuItem(strings().peerInfoGiftsHidden, handler: {
                    toggleFilter(.hidden)
                }, state: giftState.filter.contains(.hidden) ? .on : nil))
            }
           
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




