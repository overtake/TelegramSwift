//
//  NewThemeController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/08/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import SyncCore



private let _id_input_name = InputDataIdentifier("_id_input_name")

private struct NewThemeState : Equatable {
    let name: String
    let error: InputDataValueError?
    init(name: String, error: InputDataValueError?) {
        self.name = name
        self.error = error
    }
    func withUpdatedCode(_ name: String) -> NewThemeState {
        return NewThemeState(name: name, error: self.error)
    }
    func withUpdatedError(_ error: InputDataValueError?) -> NewThemeState {
        return NewThemeState(name: self.name, error: error)
    }
}

private func newThemeEntries(state: NewThemeState) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.name), error: state.error, identifier: _id_input_name, mode: .plain, data: InputDataRowData(), placeholder: nil, inputPlaceholder: L10n.newThemePlaceholder, filter: { $0 }, limit: 100))
    index += 1
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.newThemeDesc), data: InputDataGeneralTextData()))
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func NewThemeController(context: AccountContext, palette: ColorPalette) -> InputDataModalController {
    var palette = palette
    let initialState = NewThemeState(name: findBestNameForPalette(palette), error: nil)
        
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((NewThemeState) -> NewThemeState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let disposable = MetaDisposable()
    
    var close: (() -> Void)? = nil
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: newThemeEntries(state: state))
    }
    
    func create() -> InputDataValidation {
        return .fail(.doSomething(next: { f in
            
            let name = stateValue.with { $0.name }
            
            if name.isEmpty {
                f(.fail(.fields([_id_input_name : .shake])))
                return
            }
            
            let temp = NSTemporaryDirectory() + "\(arc4random()).palette"
            try? palette.toString.write(to: URL(fileURLWithPath: temp), atomically: true, encoding: .utf8)
            let resource = LocalFileReferenceMediaResource(localFilePath: temp, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true, size: fs(temp))
            var thumbnailData: Data? = nil
            let preview = generateThemePreview(for: palette, wallpaper: theme.wallpaper.wallpaper, backgroundMode: theme.backgroundMode)
            if let mutableData = CFDataCreateMutable(nil, 0), let destination = CGImageDestinationCreateWithData(mutableData, "public.png" as CFString, 1, nil) {
                CGImageDestinationAddImage(destination, preview, nil)
                if CGImageDestinationFinalize(destination) {
                    let data = mutableData as Data
                    thumbnailData = data
                }
            }
//            let baseTheme: TelegramBaseTheme?
//            switch palette.parent {
//            case .day:
//                baseTheme = .day
//            case .dayClassic:
//                baseTheme = .classic
//            case .nightAccent:
//                baseTheme = .night
//            default:
//                baseTheme = nil
//            }
//            let settings: TelegramThemeSettings?
//            if let baseTheme = baseTheme {
//                settings = .init(baseTheme: baseTheme, accentColor: Int32(palette.accent.rgb), messageColors: (top: Int32(palette.bubbleBackground_outgoing.rgb), Int32(palette.bubbleBackground_outgoing.rgb)), wallpaper: nil)
//            } else {
//                settings = nil
//            }
//
            disposable.set(showModalProgress(signal: createTheme(account: context.account, title: name, resource: resource, thumbnailData: thumbnailData, settings: nil)
                |> filter { value in
                    switch value {
                    case .result:
                        return true
                    default:
                        return false
                    }
            } |> take(1), for: context.window).start(next: { result in
                switch result {
                case let .result(theme):
                    _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: {
                        $0.withUpdatedCloudTheme(theme)
                    }).start()
                default:
                    break
                }
                exportPalette(palette: palette.withUpdatedName(name), completion: { result in
                    if let result = result {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: result)])
                    }
                })
                f(.success(.custom {
                    delay(0.2, closure: {
                        close?()
                    })
                }))
                
            }, error: { _ in
                alert(for: context.window, info: L10n.unknownError)
            }))
        }))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.newThemeTitle, validateData: { data in
        
        let name = stateValue.with { $0.name }
        
        if name.isEmpty {
            updateState { current in
                return current.withUpdatedError(.init(description: L10n.newThemeEmptyTextError, target: .data))
            }
            return .fail(.fields([_id_input_name: .shake]))
        } else {
            return create()
        }
        
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedCode(data[_id_input_name]?.stringValue ?? current.name).withUpdatedError(nil)
        }
        return .none
    }, afterDisappear: {
        disposable.dispose()
    }, getBackgroundColor: {
        theme.colors.background
    })
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.newThemeCreate, accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, drawBorder: true, height: 50, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}
