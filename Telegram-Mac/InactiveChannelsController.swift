//
//  InactiveChannelsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13/12/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Postbox
import TelegramCore


private func localizedInactiveDate(_ timestamp: Int32) -> String {
    
    let nowTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
    
    var t: time_t = time_t(TimeInterval(timestamp))
    var timeinfo: tm = tm()
    localtime_r(&t, &timeinfo)
    
    var now: time_t = time_t(nowTimestamp)
    var timeinfoNow: tm = tm()
    localtime_r(&now, &timeinfoNow)
    
    let string: String
    
    if timeinfoNow.tm_year == timeinfo.tm_year && timeinfoNow.tm_mon == timeinfo.tm_mon {
        //weeks
        let dif = Int(roundf(Float(timeinfoNow.tm_mday - timeinfo.tm_mday) / 7))
        string = strings().inactiveChannelsInactiveWeekCountable(dif)

    } else if timeinfoNow.tm_year == timeinfo.tm_year  {
        //month
        let dif = Int(timeinfoNow.tm_mon - timeinfo.tm_mon)
        string = strings().inactiveChannelsInactiveMonthCountable(dif)
    } else {
        //year
        var dif = Int(timeinfoNow.tm_year - timeinfo.tm_year)
        
        if Int(timeinfoNow.tm_mon - timeinfo.tm_mon) > 6 {
            dif += 1
        }
        string = strings().inactiveChannelsInactiveYearCountable(dif)
    }
    return string
}

private final class InactiveChannelsArguments  {
    let context: AccountContext
    let select: SelectPeerInteraction
    let premium:()->Void
    init(context: AccountContext, select: SelectPeerInteraction, premium:@escaping()->Void) {
        self.context = context
        self.select = select
        self.premium = premium
    }
}

private struct InactiveChannelsState : Equatable {
    let channels:[InactiveChannel]?
    init(channels: [InactiveChannel]?) {
        self.channels = channels
    }
    func withUpdatedChannels(_ channels: [InactiveChannel]) -> InactiveChannelsState {
        return InactiveChannelsState(channels: channels)
    }
}


private func inactiveEntries(state: InactiveChannelsState, arguments: InactiveChannelsArguments, source: InactiveSource) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    
    if arguments.context.isPremium && !arguments.context.premiumIsBlocked {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_text"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: source.localizedString, font: .normal(.text), header: GeneralBlockTextHeader(text: source.header, icon: theme.icons.sentFailed))
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }

    
    if !arguments.context.isPremium && !arguments.context.premiumIsBlocked {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_premium"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return PremiumIncreaseLimitItem(initialSize, stableId: stableId, context: arguments.context, type: .channels, counts: nil, viewType: .singleItem, callback: arguments.premium)
        }))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
  
//
    if let channels = state.channels {
        if !channels.isEmpty {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().inactiveChannelsHeader), data: .init(color: theme.colors.grayText, viewType: .textTopItem)))
            index += 1
        }
        for channel in channels {
            let viewType = bestGeneralViewType(channels, for: channel)
            struct _Equatable : Equatable {
                let channel: InactiveChannel
                let viewType: GeneralViewType
            }
            let equatable = _Equatable(channel: channel, viewType: viewType)
            
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_peer_\(channel.peer.id.toInt64())"), equatable: InputDataEquatable(equatable), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: channel.peer, account: arguments.context.account, context: arguments.context, stableId: stableId, enabled: true, height: 50, photoSize: NSMakeSize(36, 36), status: localizedInactiveDate(channel.lastActivityDate), inset: NSEdgeInsets(left: 20, right: 20), interactionType: .selectable(arguments.select, side: .right), viewType: viewType)
            }))
            index += 1
        }
        if !channels.isEmpty {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
        }
        
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().inactiveChannelsHeader), data: .init(color: theme.colors.grayText, viewType: .textTopItem)))
        index += 1
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return LoadingTableItem(initialSize, height: 42, stableId: stableId, viewType: .singleItem)
        }))
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }

    return entries
}

func InactiveChannelsController(context: AccountContext, source: InactiveSource) -> InputDataModalController {
    let initialState = InactiveChannelsState(channels: nil)
    let statePromise = ValuePromise<InactiveChannelsState>(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InactiveChannelsState) -> InactiveChannelsState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    
    let disposable = MetaDisposable()
    
    disposable.set((context.engine.peers.inactiveChannelList() |> delay(0.5, queue: .mainQueue())).start(next: { channels in
        updateState {
            $0.withUpdatedChannels(channels)
        }
    }))
    
    let arguments = InactiveChannelsArguments(context: context, select: SelectPeerInteraction(), premium: {
        showModal(with: PremiumBoardingController(context: context, source: .double_limits(.channels)), for: context.window)
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: inactiveEntries(state: state, arguments: arguments, source: source))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().inactiveChannelsTitle)
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: strings().inactiveChannelsOK, accept: {
        close?()
        
        if !arguments.select.presentation.selected.isEmpty {
            let removeSignal = combineLatest(arguments.select.presentation.selected.map { context.engine.peers.removePeerChat(peerId: $0, reportChatSpam: false)}) |> ignoreValues
            let peers = arguments.select.presentation.peers.map { $0.value }
            
            let signal = context.engine.peers.ensurePeersAreLocallyAvailable(peers: peers.map(EnginePeer.init)) |> then(removeSignal)
            
            _ = showModalProgress(signal: signal, for: context.window).start()
        }
        
    }, singleButton: true)
    
    
    arguments.select.singleUpdater = { [weak modalInteractions] presentation in
        modalInteractions?.updateDone { button in
            button.isEnabled = !presentation.selected.isEmpty
        }
    }
    
    controller.afterTransaction = { [weak modalInteractions] _ in
        modalInteractions?.updateDone { button in
            let state = stateValue.with { $0 }
            if let channels = state.channels {
                button.isEnabled = channels.isEmpty || !arguments.select.presentation.selected.isEmpty
                button.set(text: channels.isEmpty ? strings().modalOK : strings().inactiveChannelsOK, for: .Normal)
            } else {
                button.isEnabled = false
            }
        }
    }
    
   
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        return .none
    }
    controller.onDeinit = {
        disposable.dispose()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(400, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}

enum InactiveSource {
    case join
    case create
    case upgrade
    case invite
    var localizedString: String {
        switch self {
        case .join:
            return strings().joinChannelsTooMuch
        case .create:
            return strings().createChannelsTooMuch
        case .upgrade:
            return strings().upgradeChannelsTooMuch
        case .invite:
            return strings().inviteChannelsTooMuch
        }
    }
    var header: String {
        return strings().inactiveChannelsBlockHeader
    }
}

func showInactiveChannels(context: AccountContext, source: InactiveSource) {
    showModal(with: InactiveChannelsController(context: context, source: source), for: context.window)
}
