//
//  AutoremoMessagesController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03.02.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import Postbox
import SwiftSignalKit
import SyncCore

private final class Arguments {
    let context: AccountContext
    let setTimeout:(Int32?)->Void
    init(context: AccountContext, setTimeout:@escaping(Int32?)->Void) {
        self.context = context
        self.setTimeout = setTimeout
    }
}

private struct State : Equatable {
    var autoremoveTimeout: CachedPeerAutoremoveTimeout?
}


private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_never = InputDataIdentifier("_id_never")
private let _id_day = InputDataIdentifier("_id_day")
private let _id_week = InputDataIdentifier("_id_week")
private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []

    var sectionId:Int32 = 0
    var index: Int32 = 0

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: nil, item: { initialSize, stableId in
        return AnimtedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.invitations, text: .initialize(string: "", color: theme.colors.listGrayText, font: .normal(.text)))
    }))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoremoveMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_never, data: .init(name: L10n.autoremoveMessagesNever, color: theme.colors.text, type: .selectable(state.autoremoveTimeout == nil || state.autoremoveTimeout == .unknown || state.autoremoveTimeout == .known(nil)), viewType: .firstItem, enabled: true, action: { [weak arguments] in
        arguments?.setTimeout(nil)
    })))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_day, data: .init(name: L10n.autoremoveMessagesDay, color: theme.colors.text, type: .selectable(state.autoremoveTimeout == .known(60 * 60 * 24 * 1)), viewType: .innerItem, enabled: true, action: { [weak arguments] in
        arguments?.setTimeout(60 * 60 * 24 * 1)
    })))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_week, data: .init(name: L10n.autoremoveMessagesWeek, color: theme.colors.text, type: .selectable(state.autoremoveTimeout == .known(60 * 60 * 24 * 7)), viewType: .lastItem, enabled: true, action: { [weak arguments] in
        arguments?.setTimeout(60 * 60 * 24 * 7)
    })))
    index += 1

    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.autoremoveMessagesGroupDesc), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1


    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1

    return entries
}

func AutoremoveMessagesController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, setTimeout: { timeout in
        actionsDisposable.add(setChatMessageAutoremoveTimeoutInteractively(account: context.account, peerId: peerId, timeout: timeout).start())
    })


    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }

    let controller = InputDataController(dataSignal: signal, title: L10n.autoremoveMessagesTitle, hasDone: false)


    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    actionsDisposable.add(context.account.viewTracker.peerView(peerId).start(next: { peerView in
        let autoremoveTimeout: CachedPeerAutoremoveTimeout?
        if let cachedData = peerView.cachedData as? CachedGroupData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else if let cachedData = peerView.cachedData as? CachedChannelData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else if let cachedData = peerView.cachedData as? CachedUserData {
            autoremoveTimeout = cachedData.autoremoveTimeout
        } else {
            autoremoveTimeout = nil
        }
        updateState { current in
            var current = current
            current.autoremoveTimeout = autoremoveTimeout
            return current
        }
    }))


    return controller

}

