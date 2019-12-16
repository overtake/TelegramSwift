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
import SyncCore

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
        string = L10n.inactiveChannelsInactiveWeekCountable(dif)

    } else if timeinfoNow.tm_year == timeinfo.tm_year  {
        //month
        let dif = Int(timeinfoNow.tm_mon - timeinfo.tm_mon)
        string = L10n.inactiveChannelsInactiveMonthCountable(dif)
    } else {
        //year
        var dif = Int(timeinfoNow.tm_year - timeinfo.tm_year)
        
        if Int(timeinfoNow.tm_mon - timeinfo.tm_mon) > 6 {
            dif += 1
        }
        string = L10n.inactiveChannelsInactiveYearCountable(dif)
    }
    return string
}

private final class InactiveChannelsArguments  {
    let context: AccountContext
    let select: SelectPeerInteraction
    let delete: (PeerId)->Void
    init(context: AccountContext, select: SelectPeerInteraction, delete: @escaping(PeerId)->Void) {
        self.context = context
        self.select = select
        self.delete = delete
    }
}

private struct InactiveChannelsState : Equatable {
    let channels:[InactiveChannel]
    let processing:Set<PeerId>
    init(channels: [InactiveChannel], processing: Set<PeerId>) {
        self.channels = channels
        self.processing = processing
    }
    func withUpdatedChannels(_ channels: [InactiveChannel]) -> InactiveChannelsState {
        return InactiveChannelsState(channels: channels, processing: self.processing)
    }
    func withRemoveInactiveChannel(_ peerId: PeerId) -> InactiveChannelsState {
        var channels = self.channels
        if let index = channels.firstIndex(where: { $0.peer.id == peerId }) {
            _ = channels.remove(at: index)
        }
        var processing = self.processing
        processing.remove(peerId)
        return InactiveChannelsState(channels: channels, processing: processing)
    }
    func withAddToProcessing(_ peerId: PeerId) -> InactiveChannelsState {
        var processing = self.processing
        processing.insert(peerId)
        return InactiveChannelsState(channels: self.channels, processing: processing)
    }
}


private func inactiveEntries(state: InactiveChannelsState, arguments: InactiveChannelsArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_text"), equatable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem.init(initialSize, stableId: stableId, viewType: .singleItem, text: L10n.joinChannelsTooMuch, font: .normal(.text))
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.inactiveChannelsHeader), data: .init(color: theme.colors.grayText, viewType: .textTopItem)))
    index += 1
//
    for channel in state.channels {
        
        let viewType = bestGeneralViewType(state.channels, for: channel)

        struct _Equatable : Equatable {
            let channel: InactiveChannel
            let processing: Bool
            let viewType: GeneralViewType
        }
        let equatable = _Equatable(channel: channel, processing: state.processing.contains(channel.peer.id), viewType: viewType)
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("_id_peer_\(channel.peer.id.toInt64())"), equatable: InputDataEquatable(equatable), item: { initialSize, stableId in
            return ShortPeerRowItem(initialSize, peer: channel.peer, account: arguments.context.account, stableId: stableId, enabled: !equatable.processing, height: 50, photoSize: NSMakeSize(36, 36), status: localizedInactiveDate(channel.lastActivityDate), inset: NSEdgeInsets(left: 30, right: 30), interactionType: .selectable(arguments.select), viewType: viewType)
        }))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func InactiveChannelsController(context: AccountContext, inactive: [InactiveChannel]) -> InputDataModalController {
    let initialState = InactiveChannelsState(channels: inactive, processing: Set())
    let statePromise = ValuePromise<InactiveChannelsState>(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InactiveChannelsState) -> InactiveChannelsState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    

    
    let disposable = DisposableDict<PeerId>()
    
    let arguments = InactiveChannelsArguments(context: context, select: SelectPeerInteraction(), delete: { peerId in
        updateState {
            $0.withAddToProcessing(peerId)
        }
        disposable.set(removePeerChat(account: context.account, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: false).start(completed: {
            updateState {
                $0.withRemoveInactiveChannel(peerId)
            }
        }), forKey: peerId)
        
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: inactiveEntries(state: state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.inactiveChannelsTitle)
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.inactiveChannelsOK, accept: {
        close?()
        let removeSignal = combineLatest(arguments.select.presentation.selected.map { removePeerChat(account: context.account, peerId: $0, reportChatSpam: false)})
        let peers = arguments.select.presentation.peers.map { $0.value }
        let signal = context.account.postbox.transaction { transaction in
            updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                return updated
            })
        } |> mapToSignal { _ in
             return removeSignal
        }
        
        _ = showModalProgress(signal: signal, for: context.window).start()
    }, drawBorder: true, height: 50, singleButton: true)
    
    
    arguments.select.singleUpdater = { [weak modalInteractions] presentation in
        modalInteractions?.updateDone { button in
            button.isEnabled = !presentation.selected.isEmpty
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
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(350, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}



func showInactiveChannels(context: AccountContext) {
    _ = showModalProgress(signal: inactiveChannelList(network: context.account.network), for: context.window).start(next: { inactive in
        showModal(with: InactiveChannelsController(context: context, inactive: inactive), for: context.window)
    })
}
