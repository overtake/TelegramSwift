//
//  ChatMessageContentNode.swift
//  Telegram-Mac
//
//  Created by keepcoder on 17/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramMedia
import TGUIKit


class ChatMediaContentView: Control, NSDraggingSource, NSPasteboardItemDataProvider, PinchableView {

    
    
    
    private var acceptDragging:Bool = false
    private var inDragging:Bool = false
    private var mouseDownPoint: NSPoint = NSZeroPoint
    var parent:Message?
    var media:Media?
    var context:AccountContext?
    var parameters:ChatMediaLayoutParameters?
    private(set) var fetchControls:FetchControls!
    var fetchStatus: MediaResourceStatus? 
    var dragDisposable:MetaDisposable = MetaDisposable()
    var positionFlags: LayoutPositionFlags?
    override var backgroundColor: NSColor {
        get {
            return super.backgroundColor
        }
        set {
            super.backgroundColor = newValue
            for view in subviews {
                if !(view is TransformImageView) && !(view is SelectingControl) && !(view is GIFPlayerView) && !(view is ChatMessageAccessoryView) && !(view is MediaPreviewEditControl) && !(view is ProgressIndicator) && !(view is VoiceTranscriptionControl) {
                    if let view = view as? View, view.isDynamicColorUpdateLocked {
                        continue
                    }
                    view.background = newValue
                }
            }
        }
    }
    
    weak var table:TableView?
    
    
    override init() {
        super.init()
        fetchControls = FetchControls(fetch: { [weak self] in
            self?.executeInteraction(true)
            self?.open()
        })
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        fetchControls = FetchControls(fetch: { [weak self] in
            self?.executeInteraction(true)
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func playIfNeeded(_ playSound: Bool = false) {
        
    }
    
    func willRemove() -> Void {
        //self.cancel()
    }
    
    func clean() -> Void {
        
    }
    
    func cancel() -> Void {
        
    }
    
    func delete() -> Void {
        cancel()
        let engine = context?.engine.messages
        if let parentId = parent?.id {
            _ = context?.account.postbox.transaction({ transaction -> Void in
                engine?.deleteMessages(transaction: transaction, ids: [parentId])
            }).start()
        }
    }
    
    override var allowsVibrancy: Bool {
        return true
    }
    
    func cancelFetching() {
        if let context = context, let media = media {
            if let parent = parent, let parameters = parameters {
                parameters.cancelOperation(parent, media)
            } else {
                if let media = media as? TelegramMediaFile {
                    cancelFreeMediaFileInteractiveFetch(context: context, resource: media.resource)
                } else if let media = media as? TelegramMediaImage {
                    chatMessagePhotoCancelInteractiveFetch(account: context.account, photo: media)
                }
            }
        }
    }
    
    func open() -> Void {
        
    }
    
    func fetch(userInitiated: Bool) -> Void {
        
    }
    
    func preloadStreamblePart() {
        
    }
    
    func updateMouse() {
        
    }
    
    func executeInteraction(_ isControl:Bool) -> Void {
        if let fetchStatus = self.fetchStatus, userInteractionEnabled {
            switch fetchStatus {
            case .Fetching, .Paused:
                if isControl {
                    if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                        delete()
                    }
                    cancelFetching()
                } else {
                }
            case .Remote:
                fetch(userInitiated: true)
            case .Local:
                open()
                break
            }
        }
    }
    
    func previewMediaIfPossible() -> Bool {
        return false
    }
    
    deinit {
        self.clean()
        dragDisposable.dispose()
    }
     
     func update(size: NSSize) {
         
     }
    
    func update(with media: Media, size:NSSize, context:AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool = false, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) -> Void  {
        self.setContent(size: size, animated: animated)
        self.parameters = parameters
        self.positionFlags = positionFlags
        self.context = context
        self.parent = parent
        self.table = table
                
        self.media = media
        
        if let parameters = parameters {
            if let parent = parent {
                if parameters.automaticDownloadFunc(parent) {
                    fetch(userInitiated: false)
                    preloadStreamblePart()
                } else {
                    if parameters.preload {
                        preloadStreamblePart()
                    }
                }
            } else if parameters.automaticDownload {
                fetch(userInitiated: false)
                preloadStreamblePart()
            } else if parameters.preload {
                preloadStreamblePart()
            }
            
        }
        
    }
    
    var autoDownload: Bool {
        if let parameters = parameters {
            if let parent = parent {
                if parameters.automaticDownloadFunc(parent) {
                   return true
                }
            } else if parameters.automaticDownload {
               return true
            }
        }
        return false
    }
    
    func addSublayer(_ layer:CALayer) -> Void {
        self.layer?.addSublayer(layer)
    }
    
    func setContent(size:NSSize, animated: Bool) -> Void {
        let frame = NSMakeRect(NSMinX(self.frame), NSMinY(self.frame), size.width, size.height)
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        transition.updateFrame(view: self, frame: frame)
    }
    
    override func copy() -> Any {
        let view = View()
        view.frame = self.frame
        return view
    }
    
    func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return self
    }
    
    func interactionControllerDidFinishAnimation(interactive: Bool) {
        
    }
    
    func videoTimebase() -> CMTimebase? {
        return nil
    }
    func applyTimebase(timebase: CMTimebase?) {
        
    }
    
    func addAccesoryOnCopiedView(view: NSView) {

    }
    
    func draggingAbility(_ event:NSEvent) -> Bool {
        if let superview = superview {
            return NSPointInRect(superview.convert(event.locationInWindow, from: nil), frame)
        }
        return false
    }
    
    override func mouseDown(with event: NSEvent) {
        
        if event.modifierFlags.contains(.control) {
            super.mouseDown(with: event)
            return
        }
        
        if userInteractionEnabled {
            inDragging = false
            dragpath = nil
            mouseDownPoint = convert(event.locationInWindow, from: nil)
            acceptDragging = draggingAbility(event) && parent != nil && !parent!.containsSecretMedia && !parent!.isCopyProtected()
            
            if let parent = parent, parent.id.peerId.namespace == Namespaces.Peer.SecretChat {
                acceptDragging = false
            }
        }
        
        if !acceptDragging {
            super.superview?.mouseDown(with: event)
        }
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return .copy
        case .withinApplication:
            return []
        @unknown default:
            return []
        }
    }
    private var dragpath:String? = nil
    
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if let dragpath = dragpath {
            pasteboard?.clearContents()
            pasteboard?.declareTypes([.kFilenames, .string], owner: self)
            pasteboard?.setPropertyList([dragpath], forType: .kFilenames)
            pasteboard?.setString(dragpath, forType: .string)
        }
    }
    
    
    override func layout() {
        super.layout()
        self.updateLayout(size: frame.size, transition: .immediate)
    }
    
    func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        
    }
    
    
    override func mouseDragged(with event: NSEvent) {
        if self.fetchStatus == .Local {
            if !inDragging && acceptDragging {
                let current = convert(event.locationInWindow, from: nil)
                guard abs(mouseDownPoint.x - current.x) > 10 || abs(mouseDownPoint.y - current.y) > 10 else {
                    return
                }
                
                if let context = context, let resource = mediaResource(from: media), let mimeType = mediaResourceMIMEType(from: media) {
                    let result = context.account.postbox.mediaBox.resourceData(resource) |> mapToSignal { [weak media] resource -> Signal<String?, NoError> in
                        if resource.complete {
                            return resourceType( mimeType: mimeType) |> mapToSignal { [weak media] ext -> Signal<String?, NoError> in
                                return putFileToTemp(from: resource.path, named:  mediaResourceName(from: media, ext: ext))
                            }
                        } else {
                            return .single(nil)
                        }
                        
                        } |> deliverOnMainQueue
                    
                    dragDisposable.set(result.start(next: { [weak self] path in
                        if let strongSelf = self, let path = path {
                            strongSelf.dragpath = path
                            if let cgImage = strongSelf.contents {
                                let image = NSImage(cgImage: cgImage as! CGImage, size: strongSelf.contentFrame.size)
                                
                                let writer = NSPasteboardItem()
                                
                                writer.setDataProvider(strongSelf, forTypes: [.kFileUrl])
                                let item = NSDraggingItem( pasteboardWriter: writer )
                                item.setDraggingFrame(strongSelf.contentFrame, contents: image)
                                strongSelf.beginDraggingSession(with: [item], event: event, source: strongSelf)
                                
                            }
                            strongSelf.inDragging = true
                        }
                    }))
                    
                } else {
                    super.mouseDragged(with: event)
                }
                
            } else {
                super.superview?.mouseDragged(with: event)
            }
            
        } else {
            super.mouseDragged(with: event)
        }
        
    }
    
    var canSpamClicks: Bool {
        return false
    }
    
    override func mouseUp(with event: NSEvent) {
            
        if event.modifierFlags.contains(.control) {
            super.mouseUp(with: event)
            return
        }
        
        
        if !inDragging && draggingAbility(event) && userInteractionEnabled, event.clickCount <= 1 || canSpamClicks {
            executeInteraction(false)
        } else {
            super.superview?.mouseUp(with: event)
        }
        dragpath = nil
        dragDisposable.set(nil)
        inDragging = false
        acceptDragging = false
    }
    
    var contents: Any? {
        return nil
    }
    
    
    var contentFrame: NSRect {
        return bounds
    }
    
}

