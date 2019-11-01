//
//  QuickLookPreview.swift
//  Telegram-Mac
//
//  Created by keepcoder on 19/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import TGUIKit
import Quartz
import Foundation
import SyncCore

private class QuickLookPreviewItem : NSObject, QLPreviewItem {
    let media:Media
    let path:String
    init(with media:Media, path:String, ext:String = "txt") {
        self.path = path + "." + ext
        self.media = media
        do {
            try? FileManager.default.linkItem(atPath: path, toPath: self.path )
        }
    }
    
    var previewItemURL: URL! {
        return URL(fileURLWithPath: path)
    }
    
    var previewItemTitle: String! {
        if let media = media as? TelegramMediaFile {
            return media.fileName ?? tr(L10n.quickLookPreview)
        }
        return L10n.quickLookPreview
    }
}

fileprivate var preview:QuickLookPreview = {

    return QuickLookPreview()
}()

class QuickLookPreview : NSObject, QLPreviewPanelDelegate, QLPreviewPanelDataSource {
    
    private var panel:QLPreviewPanel!
   
    private weak var delegate:InteractionContentViewProtocol?
    
    private var item:QuickLookPreviewItem!
    private var context: AccountContext!
    private var media:Media!
    private var ready:Promise<(String?,String?)> = Promise()
    private let disposable:MetaDisposable = MetaDisposable()
    private let resourceDisposable:MetaDisposable = MetaDisposable()
    
    private var stableId:ChatHistoryEntryId?
    
    override init() {
        super.init()
    }
    
    public func show(context: AccountContext, with media:Media, stableId:ChatHistoryEntryId?,  _ delegate:InteractionContentViewProtocol? = nil) {
        self.context = context
        self.media = media
        self.delegate = delegate
        self.stableId = stableId
        panel = QLPreviewPanel.shared()
        
      
        
        var mimeType:String = "image/jpeg"
        var fileResource:TelegramMediaResource?
        var fileName:String? = nil
        var forceExtension: String? = nil
        
        let signal:Signal<(String?, String?), NoError>
        
        if let file = media as? TelegramMediaFile {
            fileResource = file.resource
            mimeType = file.mimeType
            fileName = file.fileName
            if let ext = fileName?.nsstring.pathExtension, !ext.isEmpty {
                forceExtension = ext
            }
            
            
            
            signal = copyToDownloads(file, postbox: context.account.postbox) |> map { path in
                return (Optional(path.nsstring.deletingPathExtension), Optional(path.nsstring.pathExtension))
            }
        } else if let image = media as? TelegramMediaImage {
            fileResource = largestImageRepresentation(image.representations)?.resource
            if let fileResource = fileResource {
                signal = combineLatest(context.account.postbox.mediaBox.resourceData(fileResource), resourceType(mimeType: mimeType))
                    |> mapToSignal({ (data) -> Signal<(String?,String?), NoError> in
                        
                        return .single((data.0.path, forceExtension ?? data.1))
                    })  |> deliverOnMainQueue
            } else {
                signal = .complete()
            }
           
        } else {
            signal = .complete()
        }
        
       self.ready.set(signal |> deliverOnMainQueue)
        
        
        disposable.set(ready.get().start(next: { [weak self] (path,ext) in
            if let strongSelf = self, let path = path {
                var ext:String? = ext
                if ext == nil || ext == "*" {
                    ext = fileName?.nsstring.pathExtension
                }
                if let ext = ext {
                    
                    let item = QuickLookPreviewItem(with: strongSelf.media, path:path, ext:ext)
                    if ext == "pkpass" || !FastSettings.openInQuickLook(ext) {
                        NSWorkspace.shared.openFile(item.path)
                        return
                    }
                    strongSelf.item = item
                    RunLoop.current.add(Timer.scheduledTimer(timeInterval: 0, target: strongSelf, selector: #selector(strongSelf.openPanelInRunLoop), userInfo: nil, repeats: false), forMode: RunLoop.Mode.modalPanel)
                }
            }
        }))
    }

    
    
    @objc func openPanelInRunLoop() {
        
        panel.updateController()
        if !isOpened() {
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.currentPreviewItemIndex = 0
        }

    }
    
    
    func isOpened() -> Bool {
        return QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
    }
    
    public static var current:QuickLookPreview! {
        return preview
    }
    
    deinit {
        disposable.dispose()
        resourceDisposable.dispose()
    }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return item
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return true
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        
        if let stableId = stableId {
            let view:NSView? = delegate?.contentInteractionView(for: stableId, animateIn: false)
            
            if let view = view, let window = view.window {
              //  let tframe = view.frame
                return  window.convertToScreen(view.convert(view.bounds, to: nil))
            }
        }
        
       return NSZeroRect
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        
        if let stableId = stableId {
            let view:NSView? = delegate?.contentInteractionView(for: stableId, animateIn: true)
            
            if let view = view?.copy() as? View, let contents = view.layer?.contents {
                return NSImage(cgImage: contents as! CGImage, size: view.frame.size)
            }
        }
        return nil //fake
    }
    
    func hide() -> Void {
        if isOpened() {
            panel.orderOut(nil)
        }
        self.context = nil
        self.media = nil
        self.stableId = nil
        self.disposable.set(nil)
        self.resourceDisposable.set(nil)
    }
    
}
