//
//  LiteModeController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.02.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import InAppSettings
import Localization

private extension LiteModeKey {
    var title: String {
        return _NSLocalizedString("LiteMode.Key.\(self.rawValue).Title")
    }
    var info: String? {
        return _NSLocalizedString("LiteMode.Key.\(self.rawValue).Info")
    }
}

private final class Arguments {
    let context: AccountContext
    let toggleEnabled:()->Void
    let toggleLowPower:(Int32)->Void
    let toggleKey:(LiteModeKey)->Void
    let alertEnable:()->Void
    init(context: AccountContext, toggleEnabled:@escaping()->Void, toggleLowPower:@escaping(Int32)->Void, toggleKey:@escaping(LiteModeKey)->Void, alertEnable:@escaping()->Void) {
        self.context = context
        self.toggleEnabled = toggleEnabled
        self.toggleLowPower = toggleLowPower
        self.toggleKey = toggleKey
        self.alertEnable = alertEnable
    }
}

private struct State : Equatable {
    var liteMode: LiteMode = .standart
}

private let _id_enabled = InputDataIdentifier("_id_enabled")
private let _id_low_power = InputDataIdentifier("_id_low_power")

private func _id_enabled_key(_ key: LiteModeKey) -> InputDataIdentifier {
    return InputDataIdentifier("_id_enabled_key_\(key.rawValue)")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error:  nil, identifier: _id_enabled, data: .init(name: strings().liteModeEnabled, color: theme.colors.text, type: .switchable(state.liteMode.enabled), viewType: .singleItem, action: arguments.toggleEnabled)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().liteModeInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1

    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let list = LiteMode.allKeys
    for (i, key) in list.enumerated() {
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error:  nil, identifier: _id_enabled_key(key), data: .init(name: key.title, color: theme.colors.text, type: .switchable(state.liteMode.isEnabled(key: key)), viewType: bestGeneralViewType(list, for: i), enabled: state.liteMode.enabled, description: key.info, action: {
            arguments.toggleKey(key)
        }, disabledAction: arguments.alertEnable)))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if state.liteMode.enabled {
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().liteModeLowPower), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_low_power, equatable: InputDataEquatable(state.liteMode), comparable: nil, item: { initialSize, stableId in
            let sizes:[Int32] = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
            return SelectSizeRowItem(initialSize, stableId: stableId, current: state.liteMode.lowBatteryPercent, sizes: sizes, hasMarkers: false, viewType: .singleItem, selectAction: { index in
                arguments.toggleLowPower(sizes[index])
            })
        }))
        index += 1
        
        let lowPowerText: String
        if state.liteMode.lowBatteryPercent == 100 {
            lowPowerText = strings().liteModeLowPowerInfoFull
        } else {
            lowPowerText = strings().liteModeLowPowerInfo("\(state.liteMode.lowBatteryPercent)")
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(lowPowerText), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
        
    return entries
}

    /*

     */

func LiteModeController(context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let afterCompletion:()->Void = {
        delay(0.1, closure: {
            telegramUpdateTheme(theme.new(), animated: false)
        })
    }

    let arguments = Arguments(context: context, toggleEnabled: {
        _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.updateLiteMode { current in
                var current = current
                current.enabled = !current.enabled
                return current
            }
        }).start(completed: afterCompletion)
    }, toggleLowPower: { value in
        _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.updateLiteMode { current in
                var current = current
                current.lowBatteryPercent = value
                return current
            }
        }).start(completed: afterCompletion)
    }, toggleKey: { key in
        _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.updateLiteMode { current in
                var current = current
                if !current.keys.contains(key) {
                    current.keys.append(key)
                } else {
                    current.keys.removeAll(where: { $0 == key })
                }
                return current
            }
        }).start(completed: afterCompletion)
    }, alertEnable: {
        showModalText(for: context.window, text: strings().liteModeEnableAlert)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    actionsDisposable.add(baseAppSettings(accountManager: context.sharedContext.accountManager).start(next: { settings in
        updateState { current in
            var current = current
            current.liteMode = settings.liteMode
            return current
        }
    }))
    
    let controller = InputDataController(dataSignal: signal, title: strings().liteModeTitle, hasDone: false)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
