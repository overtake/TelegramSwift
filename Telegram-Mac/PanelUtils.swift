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

func filePanel(with exts:[String]? = nil, allowMultiple:Bool = true, canChooseDirectories: Bool = false, for window:Window, completion:@escaping ([String]?)->Void) {
    delay(0.01, closure: {
        var result:[String] = []
        let panel:NSOpenPanel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = canChooseDirectories
        
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



func alert(for window:Window, header:String = appName, info:String?, runModal: Bool = false, completion: (()->Void)? = nil, appearance: NSAppearance? = nil) {
    
    delay(0.01, closure: {
        let alert:NSAlert = NSAlert()
        alert.window.appearance = appearance ?? theme.appearance
        alert.alertStyle = .informational
        alert.messageText = header
        alert.informativeText = info ?? ""
        alert.addButton(withTitle: strings().alertOK)
        
        if runModal {
            alert.runModal()
        } else {
            alert.beginSheetModal(for: window, completionHandler: { (_) in
                completion?()
            })
        }
    })

}

func notSupported() {
    alert(for: mainWindow, header: "Not Supported", info: "This feature is not available in this app yet. Sorry! Keep calm and use the stable version.")
}

enum ConfirmResult {
    case thrid
    case basic
}

func confirm(for window:Window, header: String? = nil, information:String?, okTitle:String? = nil, cancelTitle:String = strings().alertCancel, thridTitle:String? = nil, fourTitle: String? = nil, successHandler:@escaping (ConfirmResult)->Void, cancelHandler: (()->Void)? = nil, appearance: NSAppearance? = nil) {

    delay(0.01, closure: {
        
        let alert:NSAlert = NSAlert()
        alert.window.appearance = appearance ?? theme.appearance
        alert.alertStyle = .informational
        alert.messageText = header ?? appName
        alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle ?? strings().alertOK)
        if !cancelTitle.isEmpty {
            alert.addButton(withTitle: cancelTitle)
            alert.buttons.last?.keyEquivalent = "\u{1b}"
        }


        
        if let thridTitle = thridTitle {
            alert.addButton(withTitle: thridTitle)
        }
        if let fourTitle = fourTitle {
            alert.addButton(withTitle: fourTitle)
        }
        
        
        
        alert.beginSheetModal(for: window, completionHandler: { response in
            Queue.mainQueue().justDispatch {
                if response.rawValue == 1000 {
                    successHandler(.basic)
                } else if response.rawValue == 1002 {
                    successHandler(.thrid)
                } else if response.rawValue == 1001, cancelTitle == "" {
                    successHandler(.thrid)
                } else if response.rawValue == 1001 {
                    cancelHandler?()
                }
            }
        })
    })
}

func modernConfirm(for window:Window, account: Account? = nil, peerId: PeerId? = nil, header: String = appName, information:String? = nil, okTitle:String = strings().alertOK, cancelTitle:String = strings().alertCancel, thridTitle:String? = nil, thridAutoOn: Bool = true, successHandler:@escaping(ConfirmResult)->Void, appearance: NSAppearance? = nil) {
    
    delay(0.01, closure: {
        let alert:NSAlert = NSAlert()
        alert.window.appearance = appearance ?? theme.appearance
        alert.alertStyle = .informational
        alert.messageText = header
        alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle)
        alert.addButton(withTitle: cancelTitle)
        
        
        
        if let thridTitle = thridTitle {
            alert.showsSuppressionButton = true
            alert.suppressionButton?.title = thridTitle
            alert.suppressionButton?.state = thridAutoOn ? .on : .off
          //  alert.addButton(withTitle: thridTitle)
        }
        
        var shown: Bool = false
        
        let readyToShow:() -> Void = {
            if !shown {
                shown = true
                alert.beginSheetModal(for: window, completionHandler: { [weak alert] response in
                    if let alert = alert {
                        if alert.showsSuppressionButton, let button = alert.suppressionButton, response.rawValue != 1001 {
                            switch button.state {
                            case .off:
                                successHandler(.basic)
                            case .on:
                                successHandler(.thrid)
                            default:
                                break
                            }
                        } else {
                            if response.rawValue == 1000 {
                                successHandler(.basic)
                            } else if response.rawValue == 1002 {
                                successHandler(.thrid)
                            }
                        }
                    }
                })
            }
            
        }
        
        readyToShow()

    })
    
}

func modernConfirmSignal(for window:Window, account: Account?, peerId: PeerId?, header: String = appName, information:String? = nil, okTitle:String = strings().alertOK, cancelTitle:String = strings().alertCancel, thridTitle: String? = nil, thridAutoOn: Bool = true) -> Signal<ConfirmResult, NoError> {
    let value:ValuePromise<ConfirmResult> = ValuePromise(ignoreRepeated: true)
    
    delay(0.01, closure: {
        modernConfirm(for: window, account: account, peerId: peerId, header: header, information: information, okTitle: okTitle, cancelTitle: cancelTitle, thridTitle: thridTitle, thridAutoOn: thridAutoOn, successHandler: { response in
             value.set(response)
        })
    })
    return value.get() |> take(1)
    
}

func confirmSignal(for window:Window, header: String? = nil, information:String?, okTitle:String? = nil, cancelTitle:String? = nil, appearance: NSAppearance? = nil) -> Signal<Bool, NoError> {

    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    delay(0.01, closure: {
        let alert:NSAlert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = header ?? appName
        alert.window.appearance = appearance ?? theme.appearance
        alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle ?? strings().alertOK)
        alert.addButton(withTitle: cancelTitle ?? strings().alertCancel)
        
        alert.beginSheetModal(for: window, completionHandler: { response in
            value.set(response.rawValue == 1000)
        })
    })
    return value.get() |> take(1)
}
