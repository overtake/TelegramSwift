//
//  MediaContentNode.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
import TGUIKit
import Lottie

class ChatFileContentView: ChatMediaContentView {
    


    private var actionsLayout:TextViewLayout?
    
    private var progressView:RadialProgressView?
    private var thumbProgress: RadialProgressView?
    private let thumbView:TransformImageView = TransformImageView()
    
    private var titleNode:TextNode = TextNode()
    private var actionText:TextView = TextView()
    
    private var actionInteractions:TextViewInteractions = TextViewInteractions()
    
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let openFileDisposable = MetaDisposable()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard let context = self.context, let window = self.kitWindow, let table = self.table, media?.isGraphicFile == true, fetchStatus == .Local else {return false}
        _ = startModalPreviewHandle(table, window: window, context: context)
        return true
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        actionText.isSelectable = false
        self.addSubview(actionText)
        self.thumbView.setFrameSize(70,70)
        addSubview(thumbView)
        
        actionInteractions.processURL = {[weak self] (link) in
            if let link = link as? String, link.hasSuffix("download") {
                self?.executeInteraction(false)
            } else if let link = link as? String, link.hasSuffix("finder") {
                if let context = self?.context, let file = self?.media as? TelegramMediaFile {
                    showInFinder(file, account: context.account)
                }
            }
        }
        
    }
    
    override func mouseUp(with event: NSEvent) {
        if thumbView._mouseInside() {
            executeInteraction(false)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func fetch() {
        if let context = context, let media = media as? TelegramMediaFile {
            if let parent = parent {
                fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media)).start())
            } else {
                fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    override func open() {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent  {
            if media.isGraphicFile || media.isVideoFile {
                showChatGallery(context: context, message: parent, table, parameters as? ChatMediaGalleryParameters, type: media.isVideoFile ? .alone : .history)
            } else {
                if let _ = Animation.filepath(context.account.postbox.mediaBox.resourcePath(media.resource)) {
                    showChatGallery(context: context, message: parent, self.table, self.parameters as? ChatMediaGalleryParameters, type: .alone)
                } else {
                    if let palette = paletteFromFile(context: context, file: media) {
                        showModal(with: ThemePreviewModalController(context: context, source: .localTheme(theme.withUpdatedColors(palette))), for: context.window)
                    } else {
                        QuickLookPreview.current.show(context: context, with: media, stableId: parent.chatStableId, self.table)
                    }
                }
                
            }
        }
    }

    
    override func cancelFetching() {
        if let context = context, let media = media as? TelegramMediaFile {
            if let parent = parent {
                messageMediaFileCancelInteractiveFetch(context: context, messageId: parent.id, fileReference: FileMediaReference.message(message: MessageReference(parent), media: media))
            } else {
                cancelFreeMediaFileInteractiveFetch(context: context, resource: media.resource)
            }
            if let resource = media.resource as? LocalFileArchiveMediaResource {
                archiver.remove(.resource(resource))
            }
        }
    }
    
    override func draggingAbility(_ event:NSEvent) -> Bool {
        return NSPointInRect(convert(event.locationInWindow, from: nil), progressView?.frame ?? NSZeroRect)
    }
    
    deinit {
        openFileDisposable.dispose()
    }
    
    func actionLayout(status:MediaResourceStatus, archiveStatus: ArchiveStatus?, file:TelegramMediaFile, presentation: ChatMediaPresentation, paremeters: ChatFileLayoutParameters?) -> TextViewLayout? {
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        if let archiveStatus = archiveStatus {
            switch archiveStatus {
            case let .progress(progress):
                switch status {
                case .Fetching:
                    if parent != nil {
                        _ = attr.append(string: progress == 0 ? L10n.messageStatusArchivePreparing : L10n.messageStatusArchiving(Int(progress * 100)), color: presentation.grayText, font: .normal(.text))
                        let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                        layout.measure()
                        return layout
                    } else {
                        _ = attr.append(string: L10n.messageStatusArchived, color: presentation.grayText, font: .normal(.text))
                        let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                        layout.measure()
                        return layout
                    }
                   
                default:
                    break
                }
            case .none, .waiting:
                _ = attr.append(string: L10n.messageStatusArchivePreparing, color: presentation.grayText, font: .normal(.text))
                let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                layout.measure()
                return layout
            case .done:
                if parent == nil {
                    _ = attr.append(string: L10n.messageStatusArchived, color: presentation.grayText, font: .normal(.text))
                    let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                    layout.measure()
                    return layout
                }
            case let .fail(error):
                if parent == nil {
                    let errorText: String
                    switch error {
                    case .sizeLimit:
                        errorText = L10n.messageStatusArchiveFailedSizeLimit
                    default:
                        errorText = L10n.messageStatusArchiveFailed
                    }
                    _ = attr.append(string: errorText, color: theme.colors.redUI, font: .normal(.text))
                    let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                    layout.measure()
                    return layout
                }
            }
           
        }
        switch status {
        case let .Fetching(_, progress):
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                let _ = attr.append(string: tr(L10n.messagesFileStateFetchingOut1(Int(progress * 100.0))), color: presentation.grayText, font: .normal(.text))
            } else {
                let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress), removeToken: true)
                let size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
                let _ = attr.append(string: size, color: presentation.grayText, font: .normal(.text))
            }
            let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
            layout.measure()
            return layout
            
        case .Local:
            if let _ = archiveStatus {
                let size = L10n.messageStatusArchived
                let _ = attr.append(string: size, color: presentation.grayText, font: .normal(.text))
                let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
                layout.measure()
                return layout
            }
            return paremeters?.finderLayout
        case .Remote:
            return paremeters?.downloadLayout
        }
    }
    
    override func update(with media: Media, size:NSSize, context: AccountContext, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool, positionFlags: LayoutPositionFlags? = nil, approximateSynchronousValue: Bool = false) {
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
        let semanticMedia = self.media?.id == media.id
        
        let presentation: ChatMediaPresentation = parameters?.presentation ?? .Empty
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        var updatedStatusSignal: Signal<(MediaResourceStatus, ArchiveStatus?), NoError>?
        let parameters = parameters as? ChatFileLayoutParameters
        actionText.backgroundColor = theme.colors.background
        
        var archiveSignal:Signal<ArchiveStatus?, NoError> = .single(nil)
        if let resource = file.resource as? LocalFileArchiveMediaResource {
            archiveSignal = archiver.archive(.resource(resource)) |> map {Optional($0)}
        }
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: context.account, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id), archiveSignal)
                |> map { resourceStatus, pendingStatus, archiveStatus in
                    if let archiveStatus = archiveStatus {
                        switch archiveStatus {
                        case let .progress(progress):
                            return (.Fetching(isActive: true, progress: Float(progress)), archiveStatus)
                        default:
                            break
                        }
                    }
                    if let pendingStatus = pendingStatus.0 {
                        return (.Fetching(isActive: true, progress: pendingStatus.progress), archiveStatus)
                    } else {
                        return (resourceStatus, archiveStatus)
                    }
                } |> deliverOnMainQueue
        } else {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(account: context.account, file: file, approximateSynchronousValue: approximateSynchronousValue), archiveSignal) |> map { resourceStatus, archiveStatus in
                if let archiveStatus = archiveStatus {
                    switch archiveStatus {
                    case let .progress(progress):
                        return (.Fetching(isActive: true, progress: Float(progress)), archiveStatus)
                    default:
                        break
                    }
                }
                return (resourceStatus, archiveStatus)
                } |> deliverOnMainQueue
        }
        
        let stableId:Int64
        if let sId = parent?.stableId {
            stableId = Int64(sId)
        } else {
            stableId = file.id?.id ?? 0
        }
        
        if !file.previewRepresentations.isEmpty {
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: file.previewRepresentations[0].dimensions, boundingSize: NSMakeSize(70, 70), intrinsicInsets: NSEdgeInsets())
            thumbView.setSignal(signal: cachedMedia(messageId: stableId, arguments: arguments, scale: backingScaleFactor), clearInstantly: !semanticMedia)
            
            let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
            thumbView.setSignal(chatMessageImageFile(account: context.account, fileReference: reference, progressive: false, scale: backingScaleFactor, synchronousLoad: false), clearInstantly: false, animate: true, synchronousLoad: false, cacheImage: { [weak file] result in
                if let media = file {
                    cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                }
            })
            
            
            thumbView.set(arguments: arguments)
        } else {
            thumbView.setSignal(signal: .single(TransformImageResult(nil, false)))
        }
        
        self.setNeedsDisplay()
                
        if let updatedStatusSignal = updatedStatusSignal {
            self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self, weak file] status, archiveStatus in
                guard let `self` = self, let file = file else { return }
                let oldStatus = self.fetchStatus
                self.fetchStatus = status
                
                var statusWasUpdated: Bool = false
                if let oldStatus = oldStatus {
                    switch oldStatus {
                    case .Fetching:
                        if case .Fetching = status {} else {
                            statusWasUpdated = true
                        }
                    case .Local:
                        if case .Local = status {} else {
                            statusWasUpdated = true
                        }
                    case .Remote:
                        if case .Remote = status {} else {
                            statusWasUpdated = true
                        }
                    }
                }
                
                let layout = self.actionLayout(status: status, archiveStatus: archiveStatus, file: file, presentation: presentation, paremeters: parameters)
                if !self.actionText.isEqual(to: layout) {
                    layout?.interactions = self.actionInteractions
                    self.actionText.update(layout)
                }
                
                var removeThumbProgress: Bool = false
                if case .Local = status {
                    removeThumbProgress = true
                }
                
                if !file.previewRepresentations.isEmpty {
                    self.progressView?.removeFromSuperview()
                    self.progressView = nil
                    if !removeThumbProgress {
                        if self.thumbProgress == nil {
                            let progressView = RadialProgressView(theme:RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                            progressView.frame = CGRect(origin: CGPoint(), size: CGSize(width: 40.0, height: 40.0))
                            self.thumbProgress = progressView
                            self.addSubview(progressView)
                            let f = self.thumbView.focus(progressView.frame.size)
                            self.thumbProgress?.setFrameOrigin(f.origin)
                            progressView.fetchControls = self.fetchControls
                        }
                        switch status {
                        case .Remote:
                            self.thumbProgress?.state = .Remote
                        case let .Fetching(_, progress):
                            self.thumbProgress?.state = .Fetching(progress: progress, force: false)
                        default:
                            break
                        }
                    } else {
                        if let progressView = self.thumbProgress {
                            switch progressView.state {
                            case .Fetching:
                                progressView.state = .Fetching(progress:1.0, force: false)
                            default:
                                break
                            }
                            self.thumbProgress = nil
                            progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                                if completed {
                                    progressView?.removeFromSuperview()
                                }
                            })
                            
                        }
                    }
                    
                } else {
                    self.thumbProgress?.removeFromSuperview()
                    self.thumbProgress = nil
                    
                    if self.progressView == nil {
                        self.progressView = RadialProgressView()
                        self.addSubview(self.progressView!)
                    } else if statusWasUpdated {
                        let progressView = self.progressView
                        self.progressView = RadialProgressView()
                        self.addSubview(self.progressView!)
                        
                        progressView?.layer?.animateAlpha(from: 1, to: 0.5, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                            if completed {
                                progressView?.removeFromSuperview()
                            }
                        })
                        self.progressView?.layer?.animateAlpha(from: 0.5, to: 1, duration: 0.25, timingFunction: .linear)
                    }
                }
                
                
                guard let progressView = self.progressView else {
                    return
                }
                
                progressView.fetchControls = self.fetchControls
                
                switch status {
                case let .Fetching(_, progress):
                    var progress = progress
                    if let archiveStatus = archiveStatus {
                        switch archiveStatus {
                        case .progress:
                            if parent != nil {
                                progress = 0.1
                            }
                        default:
                            break
                        }
                    }
                    progress = max(progress, 0.1)
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil)
                    progressView.state = archiveStatus != nil && self.parent == nil ? .Icon(image: presentation.fileThumb, mode: .normal) : .Fetching(progress: progress, force: false)
                    
                case .Local:
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : .clear, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .clear, icon: nil)
                    progressView.state = !file.previewRepresentations.isEmpty ? .None : .Icon(image: presentation.fileThumb, mode: .normal)
                case .Remote:
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor: file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil)
                    progressView.state = archiveStatus != nil && self.parent == nil ? .Icon(image: presentation.fileThumb, mode: .normal) : .Remote
                }
                
                progressView.userInteractionEnabled = status != .Local
            }))
        }
        
        
    }
    
    override func layout() {
        super.layout()
        if let parameters = parameters as? ChatFileLayoutParameters {
            let center = floorToScreenPixels(backingScaleFactor, (parameters.hasThumb ? 70 : 40) / 2)
            actionText.setFrameOrigin(leftInset, parameters.hasThumb ? center + 2 : 20)
            
            if parameters.hasThumb {
                if let thumbProgress = thumbProgress {
                    let f = thumbView.focus(thumbProgress.frame.size)
                    thumbProgress.setFrameOrigin(f.origin)
                }
            } else {
                progressView?.setFrameOrigin(NSZeroPoint)
            }
        }
        
    }
    
    var leftInset:CGFloat {
        if isHasThumb {
            return 70.0 + 10.0;
        } else {
            return 40.0 + 10.0;
        }
    }
    
    var isHasThumb: Bool {
        if let file = self.media as? TelegramMediaFile, !file.previewRepresentations.isEmpty {
            return true
        } else {
            return false
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        super.draw(layer, in: ctx)
        
        let parameters = self.parameters as? ChatFileLayoutParameters

        if let name = parameters?.name {
            let center = floorToScreenPixels(backingScaleFactor, frame.height/2)
            name.1.draw(NSMakeRect(leftInset, isHasThumb ? center - name.0.size.height - 2 : 1, name.0.size.width, name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
    
    override func copy() -> Any {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView.copy()
        }
        return progressView?.copy() ?? self
    }
    
    override var contents: Any? {
        return (copy() as? NSView)?.layer?.contents
    }
    
    override var contentFrame: NSRect {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView.frame
        }
        return progressView?.frame ?? frame
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView
        }
        return progressView ?? self
    }
    
    override func setContent(size: NSSize) {
        super.setContent(size: size)
    }
    
    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func clean() {
        statusDisposable.dispose()
    }
    
}
