//
//  InputPasteboardParser.swift
//  Telegram-Mac
//
//  Created by keepcoder on 02/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TGUIKit
class InputPasteboardParser: NSObject {

    
     public class func getPasteboardUrls(_ pasteboard: NSPasteboard) -> Signal<[URL], NoError> {
        let items = pasteboard.pasteboardItems
        
        if let items = items, !items.isEmpty {
            var files:[URL] = []
            
            for item in items {
                let path = item.string(forType: NSPasteboard.PasteboardType(rawValue: "public.file-url"))
                if let path = path, let url = URL(string: path) {
                    files.append(url)
                }
                
            }
            
            var image:NSImage? = nil
            
            if files.isEmpty {
                if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
                    image = images[0]
                }
            }
            
            
            files = files.filter { path -> Bool in
                if let size = fs(path.path) {
                    return size <= 2000 * 1024 * 1024
                }
                
                return false
            }
            
            
            if !files.isEmpty {
                return .single(files)
            } else if let image = image {
                return putToTemp(image: image, compress: false) |> map {[URL(fileURLWithPath: $0)]} |> deliverOnMainQueue
            }
            
        }
        
        return .single([])
    }
    
    public class func canProccessPasteboard(_ pasteboard:NSPasteboard) -> Bool {
        let items = pasteboard.pasteboardItems
        
        if let items = items, !items.isEmpty {
            var files:[URL] = []
            
            for item in items {
                let path = item.string(forType: NSPasteboard.PasteboardType(rawValue: "public.file-url"))
                if let path = path, let url = URL(string: path) {
                    files.append(url)
                }
                
            }
            
            var image:NSImage? = nil
            
            if files.isEmpty {
                if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
                    image = images[0]
                }
            }
            
            
            if let _ = items[0].types.firstIndex(of: NSPasteboard.PasteboardType(rawValue: "com.apple.traditional-mac-plain-text")) {
                return true
            }
            
            let previous = files.count
            
            files = files.filter { path -> Bool in
                if let size = fileSize(path.path) {
                    return size <= 2000 * 1024 * 1024
                }
                
                return false
            }
            
            let afterSizeCheck = files.count
            
            if afterSizeCheck == 0 && previous != afterSizeCheck {
                return false
            }
            
            if !files.isEmpty {
                
                return false
            } else if let _ = image {
                return false
            }
            
        }
        
        return true
    }
    
    public class func proccess(pasteboard:NSPasteboard, chatInteraction:ChatInteraction, window:Window) -> Bool {
        let items = pasteboard.pasteboardItems
        
        
        if let items = items, !items.isEmpty {
            var files:[URL] = []
            
            for item in items {
                let path = item.string(forType: NSPasteboard.PasteboardType(rawValue: "public.file-url"))
                if let path = path, let url = URL(string: path) {
                    files.append(url)
                }
                
            }
            
            var image:NSImage? = nil
            
            if files.isEmpty {
                if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], !images.isEmpty {
                    
                    if let representation = images[0].representations.first as? NSPDFImageRep {
                        let url = URL(fileURLWithPath: NSTemporaryDirectory() + "ios_scan_\(arc4random()).pdf")
                        
                        try? representation.pdfRepresentation.write(to: url)
                        
                        files.append(url)
                        image = nil
                    } else {
                        image = images[0]
                    }
                }
            }
            
            
            if let _ = items[0].types.firstIndex(of: NSPasteboard.PasteboardType(rawValue: "com.microsoft.appbundleid")) {
                return true
            }
            
            let previous = files.count
            
            files = files.filter { path -> Bool in
                if let size = fileSize(path.path) {
                    return size <= 2000 * 1024 * 1024
                }
                
                return false
            }
            
            let afterSizeCheck = files.count
            
            if afterSizeCheck == 0 && previous != afterSizeCheck {
                alert(for: mainWindow, info: L10n.appMaxFileSize1)
                return false
            }
            if let peer = chatInteraction.presentation.peer, let permissionText = permissionText(from: peer, for: .banSendMedia) {
                if !files.isEmpty || image != nil {
                    alert(for: mainWindow, info: permissionText)
                    return false
                }
            }
            
            if files.count == 1, let editState = chatInteraction.presentation.interfaceState.editState, editState.canEditMedia {
                _ = (Sender.generateMedia(for: MediaSenderContainer(path: files[0].path, isFile: false), account: chatInteraction.context.account, isSecretRelated: chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat) |> deliverOnMainQueue).start(next: { [weak chatInteraction] media, _ in
                    chatInteraction?.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                })
                return false
            } else if let image = image, let editState = chatInteraction.presentation.interfaceState.editState, editState.canEditMedia {
                _ = (putToTemp(image: image) |> mapToSignal {Sender.generateMedia(for: MediaSenderContainer(path: $0, isFile: false), account: chatInteraction.context.account, isSecretRelated: chatInteraction.peerId.namespace == Namespaces.Peer.SecretChat) } |> deliverOnMainQueue).start(next: { [weak chatInteraction] media, _ in
                    chatInteraction?.update({$0.updatedInterfaceState({$0.updatedEditState({$0?.withUpdatedMedia(media)})})})
                })
                return false
            }
            
            if !files.isEmpty {
                chatInteraction.showPreviewSender(files, true, nil)
                return false
            } else if let image = image {
                _ = (putToTemp(image: image, compress: false) |> deliverOnMainQueue).start(next: { (path) in
                    chatInteraction.showPreviewSender([URL(fileURLWithPath: path)], true, nil)
                })
                return false
            }
   
        }
        
        
        return true
    }
    
}

