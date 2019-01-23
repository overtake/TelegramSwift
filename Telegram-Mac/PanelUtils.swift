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
import PostboxMac
import TelegramCoreMac

let mediaExts:[String] = ["png","jpg","jpeg","tiff","mp4","mov","avi", "gif"]
let photoExts:[String] = ["png","jpg","jpeg","tiff"]
let videoExts:[String] = ["mp4","mov","avi"]


func filePanel(with exts:[String]? = nil, allowMultiple:Bool = true, canChooseDirectories: Bool = false, for window:Window, completion:@escaping ([String]?)->Void) {
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
}

func selectFolder(for window:Window, completion:@escaping (String)->Void) {
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
    
    
    if let editor = savePanel.fieldEditor(false, for: nil) {
        let exportFilename = savePanel.nameFieldStringValue
        let ext = exportFilename.nsstring.pathExtension
        if !ext.isEmpty {
            let extensionLength = exportFilename.length - ext.length - 1
            editor.selectedRange = NSMakeRange(0, extensionLength)
        }
    }
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
    
    if let editor = savePanel.fieldEditor(false, for: nil) {
        let exportFilename = savePanel.nameFieldStringValue
        let ext = exportFilename.nsstring.pathExtension
        if !ext.isEmpty {
            let extensionLength = exportFilename.length - ext.length - 1
            editor.selectedRange = NSMakeRange(0, extensionLength)
        }
    }
    
}



func alert(for window:Window, header:String = appName, info:String?, completion: (()->Void)? = nil) {
//
//    let alert = AlertController(window, header: header, text: info ?? "")
//    alert.show(completionHandler: { response in
//        completion?()
//    })

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

func confirm(for window:Window, header: String? = nil, information:String?, okTitle:String? = nil, cancelTitle:String = L10n.alertCancel, thridTitle:String? = nil, successHandler:@escaping (ConfirmResult)->Void) {

    
    let alert:NSAlert = NSAlert()
    alert.window.appearance = theme.appearance
    alert.alertStyle = .informational
    alert.messageText = header ?? appName
    alert.informativeText = information ?? ""
    alert.addButton(withTitle: okTitle ?? L10n.alertOK)
    alert.addButton(withTitle: cancelTitle)
    

    
    if let thridTitle = thridTitle {
        alert.addButton(withTitle: thridTitle)
    }
    
    
    
    alert.beginSheetModal(for: window, completionHandler: { response in
        Queue.mainQueue().justDispatch {
            if response.rawValue == 1000 {
                successHandler(.basic)
            } else if response.rawValue == 1002 {
                successHandler(.thrid)
            }
        }
    })
}

func modernConfirm(for window:Window, account: Account?, peerId: PeerId?, accessory: CGImage?, header: String = appName, information:String? = nil, okTitle:String = L10n.alertOK, cancelTitle:String = L10n.alertCancel, thridTitle:String? = nil, successHandler:@escaping(ConfirmResult)->Void) {
    //
    
    let alert:NSAlert = NSAlert()
    alert.window.appearance = theme.appearance
    alert.alertStyle = .informational
    alert.messageText = header
    alert.informativeText = information ?? ""
    alert.addButton(withTitle: okTitle)
    alert.addButton(withTitle: cancelTitle)
    
    
    
    if let thridTitle = thridTitle {
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = thridTitle
        alert.suppressionButton?.state = .on
      //  alert.addButton(withTitle: thridTitle)
    }
    
    let signal: Signal<Peer?, NoError>
    if let peerId = peerId, let account = account {
        signal = account.postbox.loadedPeerWithId(peerId) |> map(Optional.init) |> deliverOnMainQueue
    } else {
        signal = .single(nil)
    }
    
    var disposable: Disposable?
    
    var shown: Bool = false
    
    let readyToShow:() -> Void = {
        if !shown {
            shown = true
            alert.beginSheetModal(for: window, completionHandler: { [weak alert] response in
                disposable?.dispose()
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
    
    _ = signal.start(next: { peer in
        if let peer = peer, let account = account {
            alert.messageText = account.peerId == peer.id ? L10n.peerSavedMessages : peer.displayTitle
            alert.icon = nil
            if peerId == account.peerId {
                let icon = theme.icons.searchSaved
                let signal = generateEmptyPhoto(NSMakeSize(70, 70), type: .icon(colors: theme.colors.peerColors(5), icon: icon, iconSize: icon.backingSize.aspectFitted(NSMakeSize(50, 50)))) |> deliverOnMainQueue
                disposable = signal.start(next: { image in
                    if let image = image {
                        alert.icon = NSImage(cgImage: image, size: NSMakeSize(70, 70))
                        delay(0.2, closure: {
                            readyToShow()
                        })
                    }
                })

            } else {
                disposable = (peerAvatarImage(account: account, photo: PeerPhoto.peer(peer.id, peer.smallProfileImage, peer.displayLetters, nil), displayDimensions: NSMakeSize(70, 70), scale: System.backingScale, font: .avatar(30), genCap: true) |> deliverOnMainQueue).start(next: { image, _ in
                    if let image = image {
                        alert.icon = NSImage(cgImage: image, size: NSMakeSize(70, 70))
                        delay(0.2, closure: {
                            readyToShow()
                        })
                    }
                })
            }
            
        } else {
            readyToShow()
        }
        
    })
    
    
    
//    let alert = AlertController(window, account: account, peerId: peerId, header: header, text: information, okTitle: okTitle, cancelTitle: cancelTitle, thridTitle: thridTitle, accessory: accessory)
//
//    alert.show(completionHandler: { response in
//        switch response {
//        case .OK:
//            successHandler(.basic)
//        case .alertThirdButtonReturn:
//            successHandler(.thrid)
//        default:
//            break
//        }
//    })
    
}

func modernConfirmSignal(for window:Window, account: Account?, peerId: PeerId?, accessory: CGImage?, header: String = appName, information:String? = nil, okTitle:String = L10n.alertOK, cancelTitle:String = L10n.alertCancel) -> Signal<Bool, NoError> {
    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    Queue.mainQueue().async {
        modernConfirm(for: window, account: account, peerId: peerId, accessory: accessory, header: header, information: information, okTitle: okTitle, cancelTitle: cancelTitle, successHandler: { response in
             value.set(response == .basic)
        })
    }
    return value.get() |> take(1)
    
}

func confirmSignal(for window:Window, header: String? = nil, information:String?, okTitle:String? = nil, cancelTitle:String? = nil) -> Signal<Bool, NoError> {
//    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
//
//    Queue.mainQueue().async {
//        let alert = AlertController(window, header: header ?? appName, text: information ?? "", okTitle: okTitle, cancelTitle: cancelTitle ?? tr(L10n.alertCancel), swapColors: swapColors)
//        alert.show(completionHandler: { response in
//            value.set(response == .OK)
//        })
//    }
//    return value.get() |> take(1)
    
    let value:ValuePromise<Bool> = ValuePromise(ignoreRepeated: true)
    
    Queue.mainQueue().async {
        let alert:NSAlert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = header ?? appName
        alert.window.appearance = theme.appearance
        alert.informativeText = information ?? ""
        alert.addButton(withTitle: okTitle ?? tr(L10n.alertOK))
        alert.addButton(withTitle: cancelTitle ?? tr(L10n.alertCancel))
        
        alert.beginSheetModal(for: window, completionHandler: { response in
            value.set(response.rawValue == 1000)
        })
        
    }
    return value.get() |> take(1)
}
