//
//  MultiGiftPremium.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import TelegramCore
import TGUIKit
import SwiftSignalKit
import Postbox


enum MultigiftType {
    case premium
    case stars
    case both
}

func multigift(context: AccountContext, type: MultigiftType = .both, selected: [PeerId] = []) {
    
    
    var type = type
    if context.appConfiguration.getBoolValue("stargifts_blocked", orElse: true) {
        type = .premium
    }
    
    let birthdays: Signal<[UIChatListBirthday], NoError> = context.account.stateManager.contactBirthdays |> map {
        return $0.filter {
            $0.value.isEligble
        }
    } |> take(1) |> mapToSignal { values in
        return context.account.postbox.transaction { transaction in
            var birthdays:[UIChatListBirthday] = []
            for (key, value) in values {
                if let peer = transaction.getPeer(key) {
                    birthdays.append(.init(birthday: value, peer: .init(peer)))
                }
            }
            return birthdays
        }
    } |> deliverOnMainQueue
    
    let accountHasBirthday = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Birthday(id: context.peerId)) |> map { $0 != nil }
    
    _ = combineLatest(birthdays, accountHasBirthday).startStandalone(next: { birthdays, accountHasBirthday in
        
        let today = birthdays.filter({ $0.birthday.isToday })
        let tomorrow = birthdays.filter({ $0.birthday.isTomorrow() })
        let yesterday = birthdays.filter({ $0.birthday.isYesterday() })
        var blocks: [SelectPeersBlock] = []
        blocks.append(.init(separator: strings().premiumGiftContactSelectionThisIsYou, peerIds: [context.peerId]))

        
        if !today.isEmpty {
            blocks.append(.init(separator: strings().birthdaySeparatorToday, peerIds: today.map { $0.peer.id }))
        }
        if !yesterday.isEmpty {
            blocks.append(.init(separator: strings().birthdaySeparatorYesterday, peerIds: yesterday.map { $0.peer.id }))
        }
        if !tomorrow.isEmpty {
            blocks.append(.init(separator: strings().birthdaySeparatorTomorrow, peerIds: tomorrow.map { $0.peer.id }))
        }
        
        let additionTopItem: SelectPeers_AdditionTopItem?
        if !accountHasBirthday {
            additionTopItem = .init(title: strings().birthdayAddYourBirthday, color: theme.colors.accent, icon: NSImage(resource: .iconCalendar).precomposed(theme.colors.accent, flipVertical: true), callback: {
                let controller = CalendarController(NSMakeRect(0, 0, 300, 300), context.window, current: Date(), lowYear: 1900, canBeNoYear: true, selectHandler: { date in
                    editAccountUpdateBirthday(date, context: context)
                })
                let nav = NavigationViewController(controller, context.window)
                nav._frameRect = NSMakeRect(0, 0, 300, 310)
                showModal(with: nav, for: context.window)
            })
        } else {
            additionTopItem = nil
        }
        
        let limit: Int32
        switch type {
        case .premium:
            limit = 10
        case .stars:
            limit = 1
        case .both:
            limit = 1
        }
        
        let behaviour = SelectContactsBehavior(settings: [.contacts, .remote, .excludeBots], excludePeerIds: [], limit: limit, blocks: blocks, additionTopItem: additionTopItem, defaultSelected:  selected, isLookSavedMessage: false, savedStatus: strings().premiumGiftContactSelectionBuySelf)
        
        
        let title: String
        switch type {
        case .premium:
            title = strings().premiumGiftTitle
        case .stars:
            title = strings().starsGiftTitle
        case .both:
            title = strings().giftingTitle
        }
        
        _ = selectModalPeers(window: context.window, context: context, title: title, behavior: behaviour, selectedPeerIds: Set(behaviour.defaultSelected)).start(next: { peerIds in
            switch type {
            case .premium:
                showModal(with: PremiumGiftingController(context: context, peerIds: peerIds), for: context.window)
            case .stars:
                let signal = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerIds[0])) |> deliverOnMainQueue
                _ = signal.start(next: { peer in
                    if let peer {
                        showModal(with: Star_ListScreen(context: context, source: .gift(peer)), for: context.window)
                    }
                })
            case .both:
                showModal(with: GiftingController(context: context, peerId: peerIds[0], isBirthday: true), for: context.window)
            }
        })
    })
}
