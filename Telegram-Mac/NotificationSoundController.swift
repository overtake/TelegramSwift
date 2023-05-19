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
    let removeCloudNote:(TelegramMediaFile)->Void
    init(context: AccountContext, selectSound:@escaping(PeerMessageSound)->Void, upload:@escaping()->Void, removeCloudNote:@escaping(TelegramMediaFile)->Void) {
        self.context = context
        self.selectSound = selectSound
        self.upload = upload
        self.removeCloudNote = removeCloudNote
    }
}

private struct State : Equatable {
    var tone: PeerMessageSound = .default
    var list: NotificationSoundList? = nil
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
    case let .cloud(id):
        return .init("_id_cloud_\(id)")
    }
}
private let _id_upload = InputDataIdentifier("_id_upload")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let settings = NotificationSoundSettings.extract(from: arguments.context.appConfiguration)
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSoundTonesTitle.uppercased()), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    var hasUploaded: Bool = false
    var canAdd: Bool = true
    var contains: Bool? = nil
    if let list = state.list {
        hasUploaded = !list.sounds.isEmpty
        canAdd = list.sounds.count < settings.maxSavedCount
        if case .cloud = state.tone {
            contains = list.sounds.contains(where: { .cloud(fileId: $0.file.fileId.id) == state.tone })
        }
        for (i, sound) in list.sounds.enumerated() {
            var viewType: GeneralViewType = bestGeneralViewType(list.sounds, for: i)
            if canAdd && i == list.sounds.count - 1 {
                viewType = .innerItem
            }
            if list.sounds.count == 1, canAdd {
                viewType = .firstItem
            }
            let id = sound.file.fileId.id
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sound(.cloud(fileId: id)), data: .init(name: localizedPeerNotificationSoundString(sound: .cloud(fileId: id), default: nil, list: list), color: theme.colors.text, type: .selectable(PeerMessageSound.cloud(fileId: id) == state.tone), viewType: viewType, action: {
                arguments.selectSound(.cloud(fileId: id))
            }, menuItems: {
                return [ContextMenuItem(strings().contextRemove, handler: {
                    arguments.removeCloudNote(sound.file)
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)]
                
            })))
            index += 1

        }
    }
    if canAdd {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_upload, data: .init(name: strings().notificationSoundTonesUpload, color: theme.colors.accent, icon: theme.icons.notification_sound_add, type: .none, viewType: hasUploaded ? .lastItem : .singleItem, action: arguments.upload)))
        index += 1
    }
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().notificationSoundTonesInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
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
        
        var selected = state.tone == item.sound
        if let contains = contains {
            if !contains {
                selected = item.sound == .default
            }
        }
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sound(item.sound), data: .init(name: localizedPeerNotificationSoundString(sound: item.sound, default: nil), color: theme.colors.text, type: .selectable(selected), viewType: bestGeneralViewType(items, for: i), action: {
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
    
    let selectTone:(PeerMessageSound)->Void = { tone in
        if tone == .default {
            
        } else if tone != .none {
            let path = fileNameForNotificationSound(postbox: context.account.postbox, sound: tone, defaultSound: nil, list: stateValue.with { $0.list })
            
            _ = path.start(next: { resource in
                if let resource = resource {
                    let path = resourcePath(context.account.postbox, resource)
                    SoundEffectPlay.play(postbox: context.account.postbox, path: path)
                }
            })
            
        }
        _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, {$0.withUpdatedTone(tone)}).start()
    }

    let arguments = Arguments(context: context, selectSound: selectTone, upload: {
        filePanel(with: ["mp3", "ogg"], allowMultiple: false, for: context.window, completion: { files in
            if let files = files {
                let settings = NotificationSoundSettings.extract(from: context.appConfiguration)
                var signals:[Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError>] = []
                for file in files {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: file)) {
                        if data.count < settings.maxSize {
                            signals.append(context.engine.peers.uploadNotificationSound(title: file.nsstring.lastPathComponent, data: data))
                        } else {
                            alert(for: context.window, info: strings().notificationSoundTonesSizeError(String.prettySized(with: settings.maxSize)))
                        }
                    }
                }
                if !signals.isEmpty {
                    _ = showModalProgress(signal: combineLatest(signals), for: context.window).start(next: { values in
                        if let value = values.first {
                            selectTone(.cloud(fileId: value.file.fileId.id))
                        }
                    }, error: { error in
                        alert(for: context.window, info: strings().unknownError)
                    })
                }
                
            }
            
        })
    }, removeCloudNote: { file in
        _ = showModalProgress(signal: context.engine.peers.removeNotificationSound(file: .standalone(media: file)), for: context.window).start()
    })
        
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let dataSignal = combineLatest(queue: .mainQueue(), appNotificationSettings(accountManager: context.sharedContext.accountManager), context.engine.peers.notificationSoundList())
    
    actionsDisposable.add(dataSignal.start(next: { value, list in
        updateState { current in
            var current = current
            current.tone = value.tone
            current.list = list
            return current
        }
    }))
    
    let controller = InputDataController(dataSignal: signal, title: strings().notificationSoundTitle, removeAfterDisappear: false, hasDone: false)
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    return controller
    
}

