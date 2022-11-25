//
//  GlobalAutoremoveMessagesController.swift
//  Telegram
//
//  Created by Mike Renoir on 24.11.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private let full: [Int32] = [
    1 * 24 * 60 * 60,
    2 * 24 * 60 * 60,
    3 * 24 * 60 * 60,
    4 * 24 * 60 * 60,
    5 * 24 * 60 * 60,
    6 * 24 * 60 * 60,
    7 * 24 * 60 * 60,
    14 * 24 * 60 * 60,
    21 * 24 * 60 * 60,
    1 * 30 * 24 * 60 * 60,
    3 * 30 * 24 * 60 * 60,
    180 * 24 * 60 * 60,
    365 * 24 * 60 * 60
]
private let short: [Int32] = [
    0,
    1 * 24 * 60 * 60,
    7 * 24 * 60 * 60,
    1 * 30 * 24 * 60 * 60
]

private final class Arguments {
    let context: AccountContext
    let updateTime:(Int32)->Void
    let applyToExists:()->Void
    init(context: AccountContext, updateTime: @escaping(Int32)->Void, applyToExists:@escaping()->Void) {
        self.context = context
        self.updateTime = updateTime
        self.applyToExists = applyToExists
    }
}

private struct State : Equatable {
    var privacy: AccountPrivacySettings?
    var current: Int32?
}

private let _id_header = InputDataIdentifier("_id_header")
private let _id_custom = InputDataIdentifier("_id_custom")

private func _id_timer(_ time: Int32) -> InputDataIdentifier {
    return InputDataIdentifier("_id_timer_\(time)")
}


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return AnimatedStickerHeaderItem(initialSize, stableId: stableId, context: arguments.context, sticker: LocalAnimatedSticker.global_autoremove, text: .init())
    }))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().globalTimerBlockHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    
    var short = short
    if let current = state.current, !short.contains(current) {
        short.append(current)
        short.sort(by: <)
    }
    
    for (i, time) in short.enumerated() {
        let viewType: GeneralViewType
        if i == short.count - 1 {
            viewType = .innerItem
        } else {
            viewType = bestGeneralViewType(short, for: i)
        }
        let text: String
        if time == 0 {
            text = strings().globalTimerOff
        } else {
            text = timeIntervalString(Int(time))
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_timer(time), data: .init(name: text, color: theme.colors.text, type: time == state.current ? .image(theme.icons.generalSelect) : .none, viewType: viewType, action: {
            arguments.updateTime(time)
        })))
        index += 1
    }
    
    
    var items:[SPopoverItem] = []
    for time in full {
        items.append(SPopoverItem(timeIntervalString(Int(time)), {
            arguments.updateTime(time)
        }))
    }
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_custom, data: .init(name: strings().globalTimerSetCustomTime, color: theme.colors.accent, type: .contextSelector("", items), viewType: .lastItem)))
    index += 1
    
    if let current = state.current, current > 0 {
        entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().globalTimerBlockEnabledInfo, linkHandler: { _ in
            arguments.applyToExists()
        }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    } else {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().globalTimerBlockInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    }
    index += 1
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func GlobalAutoremoveMessagesController(context: AccountContext, privacy: AccountPrivacySettings?, updated:@escaping(Int32, Bool)->Void) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(privacy: privacy, current: privacy?.messageAutoremoveTimeout)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, updateTime: { time in
        let value = stateValue.with { $0.current ?? 0 }
        let update = {
            updateState { current in
                var current = current
                current.current = time
                return current
            }
        }
        if time > 0, value == 0 {
            confirm(for: context.window, header: strings().globalTimerConfirmTitle, information: strings().globalTimerConfirmText(timeIntervalString(Int(time))), okTitle: strings().globalTimerConfirmOk, successHandler: { _ in
                update()
            })
        } else {
            update()
        }
    }, applyToExists: {
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().globalTimerTitle, hasDone: false)
    
    let updateValue:(Bool)->Void = { save in
        let value = stateValue.with { $0.current }
        if let value = value {
            updated(value, save)
        }

    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
        updateValue(true)
    }
    controller.backInvocation = { data, f in
        updateValue(false)
        f(true)
    }
    
    actionsDisposable.add(context.engine.privacy.requestAccountPrivacySettings().start(next: { privacy in
        updateState { current in
            var current = current
            current.privacy = privacy
            current.current = privacy.messageAutoremoveTimeout
            return current
        }
    }))

    return controller
    
}
