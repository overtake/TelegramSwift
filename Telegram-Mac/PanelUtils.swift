//
//  InputFinderPanelUtils.swift
//  Telegram-Mac
//
//  Created by keepcoder on 24/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac
import Foundation
let mediaExts:[String] = ["png","jpg","jpeg","tiff","mp4","mov","avi", "gif"]
let photoExts:[String] = ["png","jpg","jpeg","tiff"]
let videoExts:[String] = ["mp4","mov","avi"]


func filePanel(with exts:[String]? = nil, allowMultiple:Bool = true, for window:Window, completion:@escaping ([String]?)->Void) {
    var result:[String] = []
    let panel:NSOpenPanel = NSOpenPanel()
    panel.canChooseFiles = true
    
    if let window = NSApp.window(withWindowNumber: panel.windowNumber) {
        //window.appearance = theme.appearance
    }
    
    panel.canCreateDirectories = true
    panel.allowedFileTypes = exts
    panel.allowsMultipleSelection = true
    panel.beginSheetModal(for: window) { (response) in
        if response.rawValue == NSFileHandlingPanelOKButton {
            for url in panel.urls {
                let path:String = url.path
                if let exts = exts {
                    let ext:String = path.nsstring.pathExtension.lowercased()
                    if exts.contains(ext) {
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
}

func savePanel(file:String, ext:String, for window:Window) {
    
    let savePanel:NSSavePanel = NSSavePanel()
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
    savePanel.nameFieldStringValue = "\(dateFormatter.string(from: Date())).\(ext)"
    savePanel.beginSheetModal(for: window, completionHandler: {(result) in
    
        if result == NSApplication.ModalResponse.OK, let saveUrl = savePanel.url {
            try? FileManager.default.copyItem(atPath: file, toPath: saveUrl.path)
        }
    })
}

func savePanel(file:String, named:String, for window:Window) {
    
    let savePanel:NSSavePanel = NSSavePanel()
    let dateFormatter = DateFormatter()

    savePanel.nameFieldStringValue = named
    savePanel.beginSheetModal(for: window, completionHandler: {(result) in
        
        if result == NSApplication.ModalResponse.OK, let saveUrl = savePanel.url {
            try? FileManager.default.copyItem(atPath: file, toPath: saveUrl.path)
        }
    })
}



func alert(for window:Window, header:String = appName, info:String?, completion: (()->Void)? = nil) {
    let alert:NSAlert = NSAlert()
    alert.window.appearance = theme.appearance
    alert.alertStyle = .informational
    alert.messageText = header
    alert.informativeText = info ?? ""
    alert.beginSheetModal(for: window, completionHandler: { (_) in
        completion?()
    })
}

func notSupported() {
    alert(for: mainWindow, header: "Not Supported", info: "This feature is not available in this app yet. Sorry! Keep calm and use the stable version.")
}

enum ConfirmResult {
    case thrid
    case basic
}

func confirm(for window:Window, with header:String, and information:String?, okTitle:String? = nil, cancelTitle:String? = nil, thridTitle:String? = nil, successHandler:@escaping(ConfirmResult)->Void) {
    let alert:NSAlert = NSAlert()
    alert.window.appearance = theme.appearance
    alert.alertStyle = .informational
    alert.messageText = header
    alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle ?? tr(.alertOK))
    alert.addButton(withTitle: cancelTitle ?? tr(.alertCancel))
    
    if let thridTitle = thridTitle {
        alert.addButton(withTitle: thridTitle)
    }
    
    alert.beginSheetModal(for: window, completionHandler: { (response) in
        
        if response.rawValue == 1000 {
            successHandler(.basic)
        } else if response.rawValue == 1002 {
            successHandler(.thrid)
        }
        
    })

}

func confirmSignal(for window:Window, header:String, information:String?, okTitle:String? = nil, cancelTitle:String? = nil) -> Signal<Bool, Void> {
    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    Queue.mainQueue().async {
        let alert:NSAlert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = header
        alert.window.appearance = theme.appearance
        alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle ?? tr(.alertOK))
        alert.addButton(withTitle: cancelTitle ?? tr(.alertCancel))
        
        alert.beginSheetModal(for: window, completionHandler: { response in
            value.set(response.rawValue == 1000)
        })
        
    }
    return value.get() |> take(1)
}
