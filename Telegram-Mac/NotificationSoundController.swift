//
//  NotificationSoundController.swift
//  Telegram
//
//  Created by Mike Renoir on 29.03.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings

private final class Arguments {
    let context: AccountContext
    let selectSound:(PeerMessageSound)->Void
    let upload:()->Void
    init(context: AccountContext, selectSound:@escaping(PeerMessageSound)->Void, upload:@escaping()->Void) {
        self.context = context
        self.selectSound = selectSound
        self.upload = upload
    }
}

private struct State : Equatable {
    var tone: PeerMessageSound = .default
}

private func _id_sound(_ sound: PeerMessageSound) -> InputDataIdentifier {
    switch sound {
    case .none:
        return .init("_id_none")
    case .`default`:
        return .init("_id_default")
    case let .bundledClassic(id):
        return .init("_id_bundledClassic_\(id)")
    case let .bundledModern(id):
        return .init("_id_bundledModern_\(id)")
    }
}
private let _id_upload = InputDataIdentifier("_id_upload")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSoundTitle), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
//    index += 1
//    
//    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_upload, data: .init(name: strings().notificationSoundTonesUpload, color: theme.colors.text, icon: theme.icons.notification_sound_add, type: .none, viewType: .singleItem, action: arguments.upload)))
//    index += 1
//    
//    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSoundTonesInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
//    index += 1
//    
//    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    struct Tuple : Equatable {
        let sound: PeerMessageSound
    }
    
    var items:[Tuple] = []
    items.append(.init(sound: .default))
    items.append(.init(sound: .none))
    for i in 0 ..< 12 {
        let sound: PeerMessageSound = .bundledModern(id: Int32(i))
        items.append(.init(sound: sound))
    }
    for i in 0 ..< 8 {
        let sound: PeerMessageSound = .bundledClassic(id: Int32(i))
        items.append(.init(sound: sound))
    }

    for (i, item) in items.enumerated() {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sound(item.sound), data: .init(name: localizedPeerNotificationSoundString(sound: item.sound, default: nil), color: theme.colors.text, type: .selectable(state.tone == item.sound), viewType: bestGeneralViewType(items, for: i), action: {
            arguments.selectSound(item.sound)
        })))
        index += 1
    }
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func NotificationSoundController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, selectSound: { tone in
        if tone == .default {
            
        } else if tone != .none {
            let name = fileNameForNotificationSound(tone, defaultSound: nil)
            SoundEffectPlay.play(postbox: context.account.postbox, name: name, type: "m4a")
        }
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTone(tone)}).start()
    }, upload: {
        
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    actionsDisposable.add(appNotificationSettings(accountManager: context.sharedContext.accountManager).start(next: { value in
        updateState { current in
            var current = current
            current.tone = value.tone
            return current
        }
    }))
    
    let controller = InputDataController(dataSignal: signal, title: strings().notificationSoundTitle, removeAfterDisappear: false, hasDone: false)
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    return controller
    
}

