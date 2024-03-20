//
//  InputFinderPanelUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import Foundation
import Postbox
import TelegramCore


let mediaExts:[String] = ["png","jpg","jpeg","tiff", "heic","mp4","mov","avi", "gif", "m4v"]
let photoExts:[String] = ["png","jpg","jpeg","tiff", "heic"]
let videoExts:[String] = ["mp4","mov","avi", "m4v"]
let audioExts:[String] = ["mp3","wav", "m4a", "ogg"]

func filePanel(with exts:[String]? = nil, allowMultiple:Bool = true, canChooseDirectories: Bool = false, for window:Window, appearance: NSAppearance? = theme.appearance, completion:@escaping ([String]?)->Void) {
    delay(0.01, closure: {
        var result:[String] = []
        let panel:NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        panel.appearance = appearance
        panel.canCreateDirectories = true
        panel.allowedFileTypes = exts
        panel.allowsMultipleSelection = allowMultiple
        panel.beginSheetModal(for: window) { (response) in
            if response.rawValue == NSFileHandlingPanelOKButton {
                for url in panel.urls {
                    let path:String = url.path
                    if let exts = exts {
                        let ext:String = path.nsstring.pathExtension.lowercased()
                        if exts.contains(ext) || (canChooseDirectories && path.isDirectory) {
                            result.append(path)
                        }
                    } else {
                        result.append(path)
                    }
                }
                completion(result)
            } else {
                completion(nil)
            }
        }
    })
}

func selectFolder(for window:Window, completion:@escaping (String)->Void) {
    delay(0.01, closure: {
        var result:[String] = []
        let panel:NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { (response) in
            if response.rawValue == NSFileHandlingPanelOKButton {
                for url in panel.urls {
                    let path:String = url.path
                    result.append(path)
                }
                if let first = result.first {
                    completion(first)
                }
            }
        }
    })
}

func savePanel(file:String, ext:String, for window:Window, defaultName: String? = nil, completion:((String?)->Void)? = nil) {
    
    delay(0.01, closure: {
        let savePanel:NSSavePanel = NSSavePanel()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        savePanel.nameFieldStringValue = defaultName ?? "\(dateFormatter.string(from: Date())).\(ext)"
        
        let wLevel = window.level
       // if wLevel == .screenSaver {
            window.level = .normal
        //}
        
        savePanel.begin { (result) in
            if result == NSApplication.ModalResponse.OK, let saveUrl = savePanel.url {
                try? FileManager.default.removeItem(atPath: saveUrl.path)
                try? FileManager.default.copyItem(atPath: file, toPath: saveUrl.path)
                completion?(saveUrl.path)
                #if !SHARE
                delay(0.3, closure: {
                    appDelegate?.showSavedPathSuccess(saveUrl.path)
                })
                #endif
            } else {
                completion?(nil)
            }
            window.level = wLevel
        }
        
    })
}

func savePanel(file:String, named:String, for window:Window) {
    
    delay(0.01, closure: {
        let savePanel:NSSavePanel = NSSavePanel()
        let dateFormatter = DateFormatter()

        savePanel.nameFieldStringValue = named
        savePanel.beginSheetModal(for: window, completionHandler: {(result) in
            
            if result == NSApplication.ModalResponse.OK, let saveUrl = savePanel.url {
                try? FileManager.default.copyItem(atPath: file, toPath: saveUrl.path)
            }
        })
    })
    
}



func alert(for window:Window, header:String? = nil, info:String?, ok: String = strings().modalOK, disclaimer: String? = nil, completion: (()->Void)? = nil, onDeinit:(()->Void)? = nil, presentation: TelegramPresentationTheme = theme) {
    
    
    let data = ModalAlertData(title: header, info: info ?? "", ok: ok, options: [], disclaimer: disclaimer)
    
    showModalAlert(for: window, data: data, completion: { _ in
        completion?()
    }, onDeinit: onDeinit, presentation: presentation)
    
//    delay(0.01, closure: {
//        let alert:NSAlert = NSAlert()
//        alert.window.appearance = appearance ?? theme.appearance
//        alert.alertStyle = .informational
//        alert.messageText = header
//        alert.informativeText = info ?? ""
//        alert.addButton(withTitle: strings().alertOK)
//
//        if runModal {
//            alert.runModal()
//        } else {
//            alert.beginSheetModal(for: window, completionHandler: { (_) in
//                completion?()
//            })
//        }
//    })

}

enum ConfirmResult {
    case thrid
    case basic
}

func verifyAlert_button(for window:Window, header: String = appName, information:String?, ok:String = strings().alertOK, cancel:String = strings().alertCancel, option:String? = nil, successHandler:@escaping (ConfirmResult)->Void, cancelHandler: @escaping()->Void = { }, presentation: TelegramPresentationTheme = theme) {

    verifyAlert(for: window, header: header, information: information, ok: ok, cancel: cancel, option: option, optionIsSelected: nil, successHandler: successHandler, cancelHandler: cancelHandler, presentation: presentation)
}

func verifyAlert(for window:Window, header: String = appName, information:String? = nil, ok:String = strings().alertOK, cancel:String = strings().alertCancel, option:String? = nil, optionIsSelected: Bool? = true, successHandler:@escaping(ConfirmResult)->Void, cancelHandler:@escaping()->Void = { }, presentation: TelegramPresentationTheme = theme) {
    
    
    var options: [ModalAlertData.Option] = []
    
    if let string = option, optionIsSelected != nil {
        options.append(.init(string: string, isSelected: optionIsSelected == true))
    }
    let mode: ModalAlertData.Mode
    if let option = option, optionIsSelected == nil {
        mode = .confirm(text: option, isThird: true)
    } else {
        mode = .confirm(text: cancel, isThird: false)
    }
    
    let data: ModalAlertData = .init(title: header, info: information ?? "", description: nil, ok: ok, options: options, mode: mode)
    
    
    showModalAlert(for: window, data: data, completion: { result in
        if result.selected.isEmpty {
            successHandler(.basic)
        } else {
            if result.selected[0] == true {
                successHandler(.thrid)
            } else {
                successHandler(.basic)
            }
        }
    }, cancel: cancelHandler, presentation: presentation)
    
}

func verifyAlertSignal(for window:Window, header: String = appName, information:String? = nil, ok:String = strings().alertOK, cancel:String = strings().alertCancel, option: String? = nil, optionIsSelected: Bool = true, presentation: TelegramPresentationTheme = theme) -> Signal<ConfirmResult?, NoError> {
    let value:ValuePromise<ConfirmResult?> = ValuePromise(ignoreRepeated: true)
    
    verifyAlert(for: window, header: header, information: information, ok: ok, cancel: cancel, option: option, optionIsSelected: optionIsSelected, successHandler: { response in
         value.set(response)
    }, cancelHandler: {
        value.set(nil)
    }, presentation: presentation)
    
    return value.get() |> take(1)
    
}

//func verifyAlertSignal(for window:Window, header: String? = nil, information:String?, okTitle:String? = nil, cancelTitle:String? = nil, appearance: NSAppearance? = nil) -> Signal<Bool, NoError> {
//
//    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
//
//    delay(0.01, closure: {
//        let alert:NSAlert = NSAlert()
//        alert.alertStyle = .informational
//        alert.messageText = header ?? appName
//        alert.window.appearance = appearance ?? theme.appearance
//        alert.informativeText = information ?? ""
//        alert.addButton(withTitle: okTitle ?? strings().alertOK)
//        alert.addButton(withTitle: cancelTitle ?? strings().alertCancel)
//
//        alert.beginSheetModal(for: window, completionHandler: { response in
//            value.set(response.rawValue == 1000)
//        })
//    })
//    return value.get() |> take(1)
//}
