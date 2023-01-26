//
//  LanguageController.swift
//  Telegram
//
//  Created by Mike Renoir on 18.01.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Localization
import TelegramCore
import Postbox
import InAppSettings
import Translate

private final class Arguments {
    let context: AccountContext
    let change:(LocalizationInfo)->Void
    let delete:(LocalizationInfo)->Void
    let toggleTranslateChannels:()->Void
    let premiumAlert:()->Void
    let openPremium:()->Void
    let doNotTranslate:(String)->Void
    init(context: AccountContext, change:@escaping(LocalizationInfo)->Void, delete:@escaping(LocalizationInfo)->Void, toggleTranslateChannels: @escaping()->Void, premiumAlert:@escaping()->Void, openPremium: @escaping()->Void, doNotTranslate:@escaping(String)->Void) {
        self.context = context
        self.change = change
        self.delete = delete
        self.openPremium = openPremium
        self.premiumAlert = premiumAlert
        self.toggleTranslateChannels = toggleTranslateChannels
        self.doNotTranslate = doNotTranslate
    }
}


private struct State : Equatable {
    var localication: LocalizationListState = .defaultSettings
    var settings: BaseApplicationSettings = .defaultSettings
    var searchState: SearchState = .init(state: .None, request: nil)
    var tableSearchState: TableSearchViewState = .none({ _ in })
    var language: TelegramLocalization
    var isPremium: Bool
}

private func _id_language(_ id: String) -> InputDataIdentifier {
    return .init("_id_language_\(id)")
}
private func _id_language_official(_ id: String) -> InputDataIdentifier {
    return .init("_id_language_official_\(id)")
}
private let _id_translate_channels = InputDataIdentifier("_id_translate_channels")
private let _id_do_not_translate =  InputDataIdentifier("_id_do_not_translate")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().languageTranslateMessagesHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    var ignoreCodes = state.settings.doNotTranslate.compactMap {
        Translate.find($0)
    }.sorted(by: { $0.language < $1.language })
    
    if ignoreCodes.isEmpty, let code = Translate.find(state.language.baseLanguageCode) {
        ignoreCodes.append(code)
    }

    var codes = Translate.codes.sorted(by: { lhs, rhs in
        let lhsSelected = ignoreCodes.contains(where: { $0.code == lhs.code })
        let rhsSelected = ignoreCodes.contains(where: { $0.code == rhs.code })
        if lhsSelected && !rhsSelected {
            return true
        } else if !lhsSelected && rhsSelected {
            return false
        } else {
            return lhs.language < rhs.language
        }
    })
    
    let codeIndex = codes.firstIndex(where: {
        $0.code.contains(state.language.baseLanguageCode)
    })
    if let codeIndex = codeIndex {
        codes.move(at: codeIndex, to: 0)
    }
    
    let title = ignoreCodes.isEmpty ? "" : ignoreCodes.map {
        return _NSLocalizedString("Translate.Language.\($0.language)")
    }.joined(separator: ", ")
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_do_not_translate, data: .init(name: strings().languageTranslateMessagesDoNotTranslate, color: theme.colors.text, type: .contextSelector(title, codes.map { code in
        ContextMenuItem(code.language, handler: {
            if let first = code.code.first {
                arguments.doNotTranslate(first)
            }
        }, itemImage: ignoreCodes.contains(where: { $0.language == code.language}) ? MenuAnimation.menu_check_selected.value : nil)
    }), viewType: .firstItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_translate_channels, data: .init(name: strings().languageTranslateMessagesChannel, color: theme.colors.text, type: .switchable(state.settings.translateChats), viewType: .lastItem, enabled: state.isPremium, action: arguments.toggleTranslateChannels, disabledAction: arguments.premiumAlert)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(strings().languageTranslateMessagesChannelInfo, linkHandler: { _ in
        arguments.openPremium()
    }), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let listState = state.localication
    if !listState.availableSavedLocalizations.isEmpty || !listState.availableOfficialLocalizations.isEmpty {
        
        
        let availableSavedLocalizations = listState.availableSavedLocalizations.filter({ info in !listState.availableOfficialLocalizations.contains(where: { $0.languageCode == info.languageCode }) }).filter { value in
            if state.searchState.request.isEmpty {
                return true
            } else {
                return (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
            }
        }
        
        let availableOfficialLocalizations = listState.availableOfficialLocalizations.filter { value in
            if state.searchState.request.isEmpty {
                return true
            } else {
                return (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
            }
        }
        
        var existingIds:Set<String> = Set()
        
        
        let saved = availableSavedLocalizations.filter { value in
            
            if existingIds.contains(value.languageCode) {
                return false
            }
            
            var accept: Bool = true
            if !state.searchState.request.isEmpty {
                accept = (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
            }
            return accept
        }
        
        struct Tuple : Equatable {
            var value: LocalizationInfo
            var viewType: GeneralViewType
            var selected: Bool
        }
        var items: [Tuple] = []
        for (i, value) in saved.enumerated() {
            let viewType: GeneralViewType = bestGeneralViewType(saved, for: i)
            existingIds.insert(value.languageCode)
            items.append(.init(value: value, viewType: viewType, selected: value.languageCode == state.language.primaryLanguage.languageCode))

        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_language(item.value.languageCode), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.value.title, description: item.value.localizedTitle, descTextColor: theme.colors.grayText, type: .selectable(item.selected), viewType: item.viewType, action: {
                    arguments.change(item.value)
                }, menuItems: {
                    return [ContextMenuItem(strings().messageContextDelete, handler: {
                        arguments.delete(item.value)
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)]
                })
            }))
            index += 1
        }
        
        
        
        if !availableOfficialLocalizations.isEmpty {
            
            if !availableSavedLocalizations.isEmpty {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            
            let list = listState.availableOfficialLocalizations.filter { value in
                if existingIds.contains(value.languageCode) {
                    return false
                }
                var accept: Bool = true
                if !state.searchState.request.isEmpty {
                    accept = (value.title.lowercased().range(of: state.searchState.request.lowercased()) != nil) || (value.localizedTitle.lowercased().range(of: state.searchState.request.lowercased()) != nil)
                }
                return accept
            }
            
            var items: [Tuple] = []
            for (i, value) in list.enumerated() {
                let viewType: GeneralViewType = bestGeneralViewType(list, for: i)
                existingIds.insert(value.languageCode)
                items.append(.init(value: value, viewType: viewType, selected: value.languageCode == state.language.primaryLanguage.languageCode))
            }
            
            for item in items {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_language_official(item.value.languageCode), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: item.value.title, description: item.value.localizedTitle, descTextColor: theme.colors.grayText, type: .selectable(item.selected), viewType: item.viewType, action: {
                        arguments.change(item.value)
                    })
                }))
                index += 1
            }
        }
    } else {
        entries.append(.loading)
        index += 1
    }

    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func LanguageController(_ context: AccountContext) -> InputDataController {

    let actionsDisposable = DisposableSet()

    let initialState = State(language: appCurrentLanguage, isPremium: context.isPremium)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    

    let applyDisposable = MetaDisposable()
    actionsDisposable.add(applyDisposable)

    let arguments = Arguments(context: context, change: { value in
        if value.languageCode != appCurrentLanguage.primaryLanguage.languageCode {
            applyDisposable.set(showModalProgress(signal: context.engine.localization.downloadAndApplyLocalization(accountManager: context.sharedContext.accountManager, languageCode: value.languageCode), for: context.window).start())
        }
    }, delete: { info in
        confirm(for: context.window, information: strings().languageRemovePack, successHandler: { _ in
            _ = context.engine.localization.removeSavedLocalization(languageCode: info.languageCode).start()
        })
    }, toggleTranslateChannels: {
        actionsDisposable.add(updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            return settings.withUpdatedTranslateChannels(!settings.translateChats)
        }).start())
    }, premiumAlert: {
        showModalText(for: context.window, text: strings().languageTranslateMessagesChannelPremium, callback: { _ in
            showModal(with: PremiumBoardingController(context: context, source: .translations), for: context.window)
        })
    }, openPremium: {
        showModal(with: PremiumBoardingController(context: context, source: .translations), for: context.window)
    }, doNotTranslate: { code in
        actionsDisposable.add(updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var current = settings.doNotTranslate
            if current.contains(code) {
                current.remove(code)
            } else {
                current.insert(code)
            }
            return settings.withUpdatedDoNotTranslate(current)
        }).start())
    })
    
    
    let prefs = context.account.postbox.preferencesView(keys: [PreferencesKeys.localizationListState]) |> map { value -> LocalizationListState in
        return value.values[PreferencesKeys.localizationListState]?.get(LocalizationListState.self) ?? .defaultSettings
    } |> deliverOnPrepareQueue
    
    actionsDisposable.add(combineLatest(prefs, baseAppSettings(accountManager: context.sharedContext.accountManager), appearanceSignal, context.account.postbox.loadedPeerWithId(context.peerId)).start(next: { localization, appSettings, appearance, peer in
        updateState { current in
            var current = current
            current.localication = localization
            current.settings = appSettings
            current.language = appearance.language
            current.isPremium = peer.isPremium
            return current
        }
    }))
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().telegramLanguageViewController, hasDone: false, identifier: "language")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
