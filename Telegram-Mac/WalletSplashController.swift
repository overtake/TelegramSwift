//
//  WalletSplashController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19/09/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit
import WalletCore

@available (OSX 10.12, *)
enum WalletSplashMode : Equatable {
    case intro
    case createPasscode(TKKey, WalletInfo)
    case created(TKKey, WalletInfo, [String])
    case save24Words(TKKey, WalletInfo, [String], TimeInterval)
    case success(WalletInfo)
    case testWords(TKKey, WalletInfo, [String], [Int])
    case restoreFailed
    case importExist
    case unavailable
}

private final class WalletSplashArguments {
    let context: AccountContext
    let action:()->Void
    let copyWords:(String)->Void
    let openRestoreFailed:()->Void
    let openImport:()->Void
    let togglePasscodeMode:()->Void
    let updateImportWords:(InputDataIdentifier, InputDataValue)->Void
    let openTerms:()->Void
    let createNew:()->Void
    init(context: AccountContext, action: @escaping()->Void, copyWords: @escaping(String)->Void, openRestoreFailed: @escaping()->Void, openImport:@escaping()->Void, updateImportWords: @escaping(InputDataIdentifier, InputDataValue)->Void, togglePasscodeMode:@escaping()->Void, openTerms:@escaping()->Void, createNew:@escaping()->Void) {
        self.context = context
        self.action = action
        self.copyWords = copyWords
        self.openRestoreFailed = openRestoreFailed
        self.openImport = openImport
        self.updateImportWords = updateImportWords
        self.togglePasscodeMode = togglePasscodeMode
        self.openTerms = openTerms
        self.createNew = createNew
    }
}


@available (OSX 10.12, *)
private struct WalletSplashState : Equatable {
    let mode: WalletSplashMode
    let wordsValues:[InputDataIdentifier: InputDataValue]
    let errors:[InputDataIdentifier : InputDataValueError]
    let passcodeState: InputDataInputMode
    init(mode: WalletSplashMode, wordsValues: [InputDataIdentifier: InputDataValue] = [:], errors: [InputDataIdentifier : InputDataValueError], passcodeState: InputDataInputMode) {
        self.mode = mode
        self.wordsValues = wordsValues
        self.errors = errors
        self.passcodeState = passcodeState
    }
    func withUpdatedWordsValue(for key: InputDataIdentifier, value: InputDataValue) -> WalletSplashState {
        var wordsValues = self.wordsValues
        wordsValues[key] = value
        return WalletSplashState(mode: self.mode, wordsValues: wordsValues, errors: self.errors, passcodeState: self.passcodeState)
    }
    func withUpdatedPasscodeState(passcodeState: InputDataInputMode) -> WalletSplashState {
        return WalletSplashState(mode: self.mode, wordsValues: self.wordsValues, errors: self.errors, passcodeState: passcodeState)
    }
    func withUpdatedError(_ error: InputDataValueError?, for key: InputDataIdentifier) -> WalletSplashState {
        var errors = self.errors
        if let error = error {
            errors[key] = error
        } else {
            errors.removeValue(forKey: key)
        }
        return WalletSplashState(mode: self.mode, wordsValues: self.wordsValues, errors: errors, passcodeState: self.passcodeState)
    }
}

private let _id_create_intro = InputDataIdentifier("_id_create_intro")
private let _id_button = InputDataIdentifier("_id_button")
private let _id_words = InputDataIdentifier("_id_words")

private let _id_passcode_1 = InputDataIdentifier("_id_passcode_1")
private let _id_passcode_2 = InputDataIdentifier("_id_passcode_2")

private func _id_word(_ index:Int) -> InputDataIdentifier {
    return InputDataIdentifier("_id_word_\(index)")
}
@available (OSX 10.12, *)
private func splashEntries(state: WalletSplashState, arguments: WalletSplashArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("topDynamic"), equatable: InputDataEquatable(arc4random()), item: { initialSize, stableId in
        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .top)
    }))
    
  
    
    let animation: LocalAnimatedSticker?
    switch state.mode {
    case .createPasscode:
        switch state.passcodeState {
        case .secure:
            animation = LocalAnimatedSticker.keychain
        case .plain:
            animation = LocalAnimatedSticker.keychain
        }
    default:
        animation = state.mode.animation
    }
    
    if animation == nil {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    }
    
    struct WalletSplashEquatable : Equatable {
        let mode: WalletSplashMode
        let animation: LocalAnimatedSticker?
    }
    let splashEquatable = WalletSplashEquatable(mode: state.mode, animation: animation)
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_create_intro, equatable: InputDataEquatable(splashEquatable), item: { initialSize, stableId in
        return WalletSplashRowItem(initialSize, stableId: stableId, context: arguments.context, title: state.mode.title, desc: state.mode.desc, animation: animation, viewType: .modern(position: .inner, insets: NSEdgeInsets()), action: { action in
            switch action {
            case "HaventWords":
                arguments.openRestoreFailed()
            case "EnterWords":
                arguments.openImport()
            case "CreateNew":
                arguments.createNew()
            default:
                break
            }
        })
    }))
    index += 1
    
    switch state.mode {
    case let .save24Words(_, _, words, _):
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_words, equatable: InputDataEquatable(state.mode), item: { initialSize, stableId in
            return Wallet24WordsItem(initialSize, stableId: stableId, words: words, viewType: .singleItem, copy: arguments.copyWords)
        }))
        index += 1
    case let .testWords(_, _, _, indexes):
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
//        for idx in indexes {
//            entries.append(.input(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_passcode_1, mode: .plain, data: InputDataRowData(viewType: bestGeneralViewType(indexes, for: idx)), placeholder: nil, inputPlaceholder: "", filter: { $0 }, limit: 8))
//            index += 1
//
//        }
        
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_words, equatable: InputDataEquatable(state.wordsValues), item: { initialSize, stableId in
            return WalletTestWordsItem(initialSize, stableId: stableId, indexes: indexes, words: state.wordsValues, viewType: .singleItem, update: arguments.updateImportWords)
        }))
        index += 1
    case .importExist:
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_words, equatable: InputDataEquatable(state.wordsValues), item: { initialSize, stableId in
            return WalletImportWordsItem(initialSize, stableId: stableId, words: state.wordsValues, viewType: .singleItem, update: arguments.updateImportWords)
        }))
        index += 1
    case .createPasscode:
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let icon: CGImage
        switch state.passcodeState {
        case .secure:
            icon = theme.icons.wallet_passcode_visible
        case .plain:
            icon = theme.icons.wallet_passcode_hidden
        }
        
        entries.append(.input(sectionId: sectionId, index: index, value: state.wordsValues[_id_passcode_1] ?? .none, error: nil, identifier: _id_passcode_1, mode: state.passcodeState, data: InputDataRowData(viewType: .firstItem, rightItem: InputDataRightItem.action(icon, .custom(arguments.togglePasscodeMode)), maxBlockWidth: 280), placeholder: nil, inputPlaceholder: L10n.walletSplashCreatePasscodePlaceholder1, filter: { $0 }, limit: 255))
        index += 1
        
        entries.append(.input(sectionId: sectionId, index: index, value: state.wordsValues[_id_passcode_2] ?? .none, error: state.errors[_id_passcode_2], identifier: _id_passcode_2, mode: state.passcodeState, data: InputDataRowData(viewType: .lastItem, maxBlockWidth: 280), placeholder: nil, inputPlaceholder: L10n.walletSplashCreatePasscodePlaceholder2, filter: { $0 }, limit: 255))
         index += 1
    default:
        break
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
//    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_button, equatable: InputDataEquatable(state.mode), item: { initialSize, stableId in
        return WalletSplashButtonRowItem(initialSize, stableId: stableId, buttonText: state.mode.buttonText, subButtonText: state.mode.subButtonText, viewType: .lastItem, subTextAction: { action in
            switch action {
            case "HaventWords":
                arguments.openRestoreFailed()
            case "EnterWords":
                arguments.openImport()
            case "Terms":
                arguments.openTerms()
            default:
                break
            }
        }, action: arguments.action)
    }))
    index += 1
    
  
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("bottomDynamic"), equatable: InputDataEquatable(arc4random()), item: { initialSize, stableId in
        return DynamicHeightRowItem(initialSize, stableId: stableId, side: .bottom)
    }))
    
    return entries
}

@available(OSX 10.12, *)
func WalletSplashController(context: AccountContext, tonContext: TonContext, mode: WalletSplashMode) -> InputDataController {
    
    let initialState = WalletSplashState(mode: mode, errors: [:], passcodeState: .secure)
    let state: ValuePromise<WalletSplashState> = ValuePromise(initialState)
    let stateValue: Atomic<WalletSplashState> = Atomic(value: initialState)
    
    let updateState:((WalletSplashState)->WalletSplashState) -> Void = { f in
        state.set(stateValue.modify(f))
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let validateAction:(WalletSplashMode)->InputDataValidation = { mode in
        switch mode {
        case .intro, .restoreFailed:
            let signal = TONKeychain.initializePairAndSavePublic(for: context.account)
             let create = signal
                |> filter { $0 != nil }
                |> map { $0! }
                |> mapError { _ in
                    return CreateWalletError.generic
                }
                |> mapToSignal { key in
                    return getServerWalletSalt(network: context.account.network)
                        |> mapError { _ in
                            return CreateWalletError.generic
                        }
                    |> mapToSignal { salt in
                        return createWallet(storage: tonContext.storage, tonInstance: tonContext.instance, keychain: tonContext.keychain, localPassword: salt)
                    }
                    |> map { data in
                         return (key, data)
                    }
                }
             
            _ = showModalProgress(signal: create, for: context.window).start(next: { keys, data in
                context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .created(keys, data.0, data.1)))
            }, error: { error in

            })
        case let .createPasscode(keys, info):
            let values = stateValue.with { $0.wordsValues }
            var fails:[InputDataIdentifier: InputDataValidationFailAction] = [:]
            let passcode1 = values[_id_passcode_1]?.stringValue ?? ""
            let passcode2 = values[_id_passcode_2]?.stringValue ?? ""
            
            if passcode1.isEmpty {
                return .fail(.fields([_id_passcode_1 : .shake]))
            }
            if passcode2.isEmpty {
                return .fail(.fields([_id_passcode_2 : .shake]))
            }
            
            if passcode1 != passcode2 {
                fails[_id_passcode_1] = .shake
                fails[_id_passcode_2] = .shake
            }
            
            if fails.isEmpty {
                _ = showModalProgress(signal: TONKeychain.applyKeys(keys, account: context.account, tonInstance: tonContext.instance, password: passcode1), for: context.window).start(next: { success in
                    context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .success(info)))
                })
            } else {
                updateState {
                    $0.withUpdatedError(InputDataValueError(description: L10n.walletSplashCreatePasscodeError, target: .data), for: _id_passcode_2)
                }
                return .fail(.fields(fails))
            }
            
        case let .created(keys, info, words):
            context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .save24Words(keys, info, words, Date().timeIntervalSince1970)))
        case let .save24Words(keys, info, words, time):
            var indexes:[Int] = []
            for _ in 0 ..< 3 {
                loop: while true {
                    let index = Int(arc4random()) % (words.count - 1) + 1
                    if !indexes.contains(index) {
                        indexes.append(index)
                        break loop
                    }
                }
            }
            if time + 30 > Date().timeIntervalSince1970  {
                confirm(for: context.window, header: L10n.walletSplashSave24WordsConfirmHeader, information: L10n.walletSplashSave24WordsConfirmText, okTitle: L10n.walletSplashSave24WordsConfirmOK, cancelTitle: "", thridTitle: L10n.walletSplashSave24WordsConfirmThrid, successHandler: { result in
                    switch result {
                    case .basic:
                        getController?()?.show(toaster: ControllerToaster(text: L10n.walletSplashSave24WordsConfirmApoligies))
                    case .thrid:
                        context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .testWords(keys, info, words, indexes.sorted())))
                    }
                })
            } else {
                context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .testWords(keys, info, words, indexes.sorted())))
            }
        case let .testWords(keys, info, words, indexes):
            let values = stateValue.with { $0.wordsValues }
            var fails:[InputDataIdentifier: InputDataValidationFailAction] = [:]
            var instantFail:[InputDataIdentifier: InputDataValidationFailAction] = [:]
            for index in indexes {
                let value = values[_id_word(index)]?.stringValue ?? ""
                if value != words[index - 1] {
                    fails[_id_word(index)] = .shake
                }
                if value.isEmpty || !walletPossibleWordList.contains(value) {
                    instantFail[_id_word(index)] = .shake
                }
            }
            
            if !instantFail.isEmpty {
                return .fail(.fields([_id_words: .shakeWithData(instantFail)]))
            }
            
            if fails.isEmpty {
                context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .createPasscode(keys, info)))
            } else {
                return .fail(.doSomething(next: { f in
                    confirm(for: context.window, header: L10n.walletSplashTestWordsIncorrectHeader, information: L10n.walletSplashTestWordsIncorrectText, okTitle: L10n.walletSplashTestWordsIncorrectOK, cancelTitle: "", thridTitle: L10n.walletSplashTestWordsIncorrectThrid, successHandler: { result in
                        switch result {
                        case .thrid:
                            context.sharedContext.bindings.rootNavigation().back()
                        default:
                            break
                        }
                    })
                    f(.fail(.fields([_id_words : .shakeWithData(fails)])))
                }))
            }
        case .importExist:
            return .fail(.doSomething(next: { f in
                
                let values = stateValue.with { $0.wordsValues }
                var wordList:[String] = []
                var fails:[InputDataIdentifier: InputDataValidationFailAction] = [:]
                for index in 1 ... 24 {
                    let value = values[_id_word(index)]?.stringValue ?? ""
                    if value.isEmpty || !walletPossibleWordList.contains(value) {
                        fails[_id_word(index)] = .shake
                    } else {
                        wordList.append(value)
                    }
                }
                if fails.isEmpty {
                    let signal = TONKeychain.initializePairAndSavePublic(for: context.account)
                    let create = signal
                        |> filter { $0 != nil }
                        |> map { $0! }
                        |> mapError { _ in
                            return ImportWalletError.generic
                        }
                        |> mapToSignal { key in
                            return getServerWalletSalt(network: context.account.network)
                                |> mapError { _ in
                                    return ImportWalletError.generic
                                }
                                |> mapToSignal { salt in
                                    return importWallet(storage: tonContext.storage, tonInstance: tonContext.instance, keychain: tonContext.keychain, wordList: wordList, localPassword: salt)
                                }
                                |> map { data in
                                    return (key, data)
                            }
                    }
                    _ = showModalProgress(signal: create, for: context.window).start(next: { keys, info in
                        context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .createPasscode(keys, info)))
                    }, error: { error in
                        switch error {
                        case .generic:
                            alert(for: context.window, header: L10n.walletSplashImportErrorTitle, info: L10n.walletSplashImportErrorText)
                        }
                    })
                } else {
                    f(.fail(.fields([_id_words : .shakeWithData(fails)])))
                }
                
            }))
        case let .success(info):
            let signal = getCombinedWalletState(storage: tonContext.storage, subject: .wallet(info), tonInstance: tonContext.instance)
                 |> filter { state in
                    switch state {
                    case let .cached(state):
                        return state != nil
                    case .updated:
                        return true
                    }
                } |> map { _ in
                    return info
                } |> take(1)
            
            _ = showModalProgress(signal: signal, for: context.window).start(next: { info in
                context.sharedContext.bindings.rootNavigation().push(WalletInfoController(context: context, tonContext: tonContext, walletInfo: info))
            }, error: { error in
                alert(for: context.window, info: L10n.unknownError)
            })
        case .unavailable:
            context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .importExist))
        }
        return .none
    }
    
    let arguments = WalletSplashArguments(context: context, action: {
        getController?()?.validateInputValues()
    }, copyWords: { words in
        confirm(for: context.window, header: L10n.walletSplashSave24WordsCopyHeader, information: L10n.walletSplashSave24WordsCopyText, successHandler: { _ in
            copyToClipboard(words)
            getController?()?.show(toaster: ControllerToaster(text: L10n.shareLinkCopied))
        })
    }, openRestoreFailed: {
        context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .restoreFailed))
    }, openImport: {
        context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .importExist))
    }, updateImportWords: { index, word in
        updateState {
            return $0.withUpdatedWordsValue(for: index, value: word)
        }
    }, togglePasscodeMode: {
        updateState {
            return $0.withUpdatedPasscodeState(passcodeState: $0.passcodeState == .secure ? .plain : .secure)
        }
    }, openTerms: {
        openFaq(context: context, dest: .walletTOS)
    }, createNew: {
        getController?()?.proccessValidation(validateAction(.intro))
    })
    
    let dataSignal = state.get() |> deliverOnPrepareQueue |> map { state in
        return splashEntries(state: state, arguments: arguments)
    } |> map { entries in
        return InputDataSignalValue(entries: entries, animated: true)
    }
    
    let controller = InputDataController(dataSignal: dataSignal, title: mode.header, validateData: { data in
        return validateAction(mode)
    }, updateDatas: { data in
        switch mode {
        case let .testWords(_, _, _, indexes):
            updateState { current in
               var current = current
                for index in indexes {
                    if let value = data[_id_word(index)] {
                        current = current.withUpdatedWordsValue(for: _id_word(index), value: value)
                    }
                }
                return current
            }
        case .importExist:
            updateState { current in
                var current = current
                for index in 1 ... 24 {
                    if let value = data[_id_word(index)] {
                        current = current.withUpdatedWordsValue(for: _id_word(index), value: value)
                    }
                }
                return current
            }
        case .createPasscode:
            updateState { current in
                var current = current
                current = current.withUpdatedWordsValue(for: _id_passcode_1, value: data[_id_passcode_1]!)
                current = current.withUpdatedWordsValue(for: _id_passcode_2, value: data[_id_passcode_2]!)
                current = current.withUpdatedError(nil, for: _id_passcode_1)
                current = current.withUpdatedError(nil, for: _id_passcode_2)
                return current
            }
        default:
            break
        }
        return .fail(.none)
    }, removeAfterDisappear: mode.removeAfterDisappear, hasDone: false, identifier: mode.identifier)
    
    controller.customRightButton = { controller in
        switch mode {
        case .intro:
            let barView = TextButtonBarView(controller: controller, text: L10n.walletSplashIntroImportExists, style: navigationButtonStyle, alignment: .Right)
            barView.set(handler: { _ in
                context.sharedContext.bindings.rootNavigation().push(WalletSplashController(context: context, tonContext: tonContext, mode: .importExist))
            }, for: .Click)
            return barView
        default:
            return nil
        }
    }
    
    var first: Bool = true
    controller.afterTransaction = { controller in
        if first {
            controller.keyWindowUpdate(context.window.isKeyWindow, controller)
            first = false
        }
    }
    
    controller.keyWindowUpdate = { isKeyWindow, controller in
        switch mode {
        case .importExist:
            if isKeyWindow {
                if let parsed = parseClipboardSecureWords(), !parsed.isEmpty, parsed.count == 24 {
                    let attr = NSAttributedString.initialize(string: L10n.walletSplashImportFromClipboard, color: theme.colors.link, font: .medium(.text))
                    controller.show(toaster: ControllerToaster(text: attr, action: {
                        updateState { current in
                            var current = current
                            for (index, word) in parsed {
                                current = current.withUpdatedWordsValue(for: _id_word(index), value: .string(word))
                            }
                            return current
                        }
                        controller.tableView.scroll(to: .down(true))
                    }), for: 15, animated: true)
                }
            }
        default:
            break
        }
    }
    
    controller.ignoreRightBarHandler = true
    
    controller.hasBackSwipe = {
        switch mode {
        case .created, .save24Words:
            return false
        default:
            return true
        }
    }
    
    
    controller.backInvocation = { data, f in
        switch mode {
        case .created, .save24Words:
            confirm(for: context.window, header: L10n.walletSplashCloseConfirmHeader, information: L10n.walletSplashCloseConfirmText, okTitle: L10n.walletSplashCloseConfirmOK, cancelTitle: "", thridTitle: L10n.walletSplashCloseConfirmThrid, successHandler: { result in
                switch result {
                case .basic:
                    f(false)
                case .thrid:
                    f(true)
                }
            })
        default:
            f(true)
        }
    }
    
    getController = { [weak controller] in
        return controller
    }
    return controller
}
