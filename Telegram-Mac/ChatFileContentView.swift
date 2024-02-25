//
//  MediaContentNode.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import Postbox
import TelegramCore

import TGUIKit

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
        startModalPreviewHandle(table, window: window, context: context)
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
        if thumbView._mouseInside(), userInteractionEnabled {
            executeInteraction(false)
        } else {
            super.mouseUp(with: event)
        }
    }
    
    override func fetch(userInitiated: Bool) {
        if let context = context, let media = media as? TelegramMediaFile {
            if let parent = parent {
                fetchDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: parent.id, messageReference: .init(parent), file: media, userInitiated: userInitiated).start())
            } else {
                fetchDisposable.set(freeMediaFileInteractiveFetched(context: context, fileReference: FileMediaReference.standalone(media: media)).start())
            }
        }
    }
    
    override func open() {
        if let context = context, let media = media as? TelegramMediaFile, let parent = parent  {
            if media.isGraphicFile || media.isVideoFile {
                parameters?.showMedia(parent)
            } else {
                if media.mimeType.contains("svg") || (media.fileName ?? "").hasSuffix(".svg") {
                    verifyAlert_button(for: context.window, information: strings().chatFileQuickLookSvg, successHandler: { _ in
                        QuickLookPreview.current.show(context: context, with: media, stableId: parent.chatStableId, self.table)
                    })
                } else {
                    QuickLookPreview.current.show(context: context, with: media, stableId: parent.chatStableId, self.table)
                }
            }
        }
    }

    
    override func cancelFetching() {
        if let context = context, let media = media as? TelegramMediaFile {
            if let parameters = parameters, let parent = parent {
                parameters.cancelOperation(parent, media)
            } else {
                cancelFreeMediaFileInteractiveFetch(context: context, resource: media.resource)
            }
        }
    }
    
    override func draggingAbility(_ event:NSEvent) -> Bool {
        return NSPointInRect(convert(event.locationInWindow, from: nil), self.thumbView.frame)
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
                        _ = attr.append(string: progress == 0 ? strings().messageStatusArchivePreparing : strings().messageStatusArchiving(Int(progress * 100)), color: presentation.grayText, font: .normal(.text))
                        let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
                        layout.measure()
                        return layout
                    } else {
                        _ = attr.append(string: strings().messageStatusArchived, color: presentation.grayText, font: .normal(.text))
                        let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
                        layout.measure()
                        return layout
                    }
                   
                default:
                    break
                }
            case .none, .waiting:
                _ = attr.append(string: strings().messageStatusArchivePreparing, color: presentation.grayText, font: .normal(.text))
                let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
                layout.measure()
                return layout
            case .done:
                if parent == nil {
                    _ = attr.append(string: strings().messageStatusArchived, color: presentation.grayText, font: .normal(.text))
                    let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
                    layout.measure()
                    return layout
                }
            case let .fail(error):
                if parent == nil {
                    let errorText: String
                    switch error {
                    case .sizeLimit:
                        errorText = strings().messageStatusArchiveFailedSizeLimit
                    default:
                        errorText = strings().messageStatusArchiveFailed
                    }
                    _ = attr.append(string: errorText, color: theme.colors.redUI, font: .normal(.text))
                    let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
                    layout.measure()
                    return layout
                }
            }
           
        }
        switch status {
        case let .Fetching(_, progress), let .Paused(progress):
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                let _ = attr.append(string: strings().messagesFileStateFetchingOut1(Int(progress * 100.0)), color: presentation.grayText, font: .normal(.text))
            } else {
                let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress), removeToken: false)
                let size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
                let _ = attr.append(string: size, color: presentation.grayText, font: .normal(.text))
            }
            let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
            layout.measure()
            return layout
            
        case .Local:
            if let _ = archiveStatus {
                let size = strings().messageStatusArchived
                let _ = attr.append(string: size, color: presentation.grayText, font: .normal(.text))
                let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1, alwaysStaticItems: true)
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
        var semanticMedia = self.parent?.stableId == parent?.stableId
        
        
        if parent == nil {
            semanticMedia = file.id == self.media?.id
        }
        let presentation: ChatMediaPresentation = parameters?.presentation ?? .Empty
        
        super.update(with: media, size: size, context: context, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        var updatedStatusSignal: Signal<(MediaResourceStatus, ArchiveStatus?), NoError>?
        let parameters = parameters as? ChatFileLayoutParameters
        
        var archiveSignal:Signal<ArchiveStatus?, NoError> = .single(nil)
        if let resource = file.resource as? LocalFileArchiveMediaResource {
            archiveSignal = archiver.archive(.resource(resource)) |> map {Optional($0)}
        }
        if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
            updatedStatusSignal = combineLatest(chatMessageFileStatus(context: context, message: parent, file: file), context.account.pendingMessageManager.pendingMessageStatus(parent.id), archiveSignal)
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
            let signal: Signal<MediaResourceStatus, NoError>
            if let parent = parent {
                signal = chatMessageFileStatus(context: context, message: parent, file: file, approximateSynchronousValue: approximateSynchronousValue)
            } else {
                signal = context.account.postbox.mediaBox.resourceStatus(file.resource)
            }
            updatedStatusSignal = combineLatest(signal, archiveSignal) |> map { resourceStatus, archiveStatus in
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
            
            let arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: file.previewRepresentations[0].dimensions.size, boundingSize: NSMakeSize(70, 70), intrinsicInsets: NSEdgeInsets())
            thumbView.setSignal(signal: cachedMedia(messageId: stableId, arguments: arguments, scale: backingScaleFactor), clearInstantly: !semanticMedia)
            
            let reference = parent != nil ? FileMediaReference.message(message: MessageReference(parent!), media: file) : FileMediaReference.standalone(media: file)
            
            if !thumbView.isFullyLoaded {
                thumbView.setSignal(chatMessageImageFile(account: context.account, fileReference: reference, progressive: false, scale: backingScaleFactor, synchronousLoad: false), clearInstantly: false, animate: true, synchronousLoad: false, cacheImage: { result in
                    cacheMedia(result, messageId: stableId, arguments: arguments, scale: System.backingScale)
                })
            }
            
            
            
            thumbView.set(arguments: arguments)
        } else {
            thumbView.setSignal(signal: .single(TransformImageResult(nil, false)))
        }
        
        self.setNeedsDisplay()
        
        if let signal = updatedStatusSignal, let parent = parent, let parameters = parameters {
            updatedStatusSignal = combineLatest(signal, parameters.getUpdatingMediaProgress(parent.id)) |> map { value, updating in
                if let progress = updating {
                    return (.Fetching(isActive: true, progress: progress), value.1)
                } else {
                    return value
                }
            }
        }
                
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
                    case .Paused:
                        if case .Paused = status {} else {
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
                        case let .Fetching(_, progress), let .Paused(progress):
                            let sentGrouped = parent?.groupingKey != nil && (parent!.flags.contains(.Sending) || parent!.flags.contains(.Unsent))
                            if progress == 1.0, sentGrouped {
                                self.thumbProgress?.state = .Success
                            } else {
                                self.thumbProgress?.state = .Fetching(progress: progress, force: false)
                            }
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
                case let .Fetching(_, progress), let .Paused(progress):
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
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil, blendMode: presentation.blendingMode)
                    
                    let sentGrouped = parent?.groupingKey != nil && (parent!.flags.contains(.Sending) || parent!.flags.contains(.Unsent))
                    if progress == 1.0, sentGrouped {
                        progressView.state = .Success
                    } else {
                        progressView.state = archiveStatus != nil && self.parent == nil ? .Icon(image: presentation.fileThumb) : .Fetching(progress: progress, force: false)
                    }
                case .Local:
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : .clear, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .clear, icon: nil, blendMode: presentation.blendingMode)
                    progressView.state = !file.previewRepresentations.isEmpty ? .None : .Icon(image: presentation.fileThumb)
                case .Remote:
                    progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor: file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil, blendMode: presentation.blendingMode)
                    progressView.state = archiveStatus != nil && self.parent == nil ? .Icon(image: presentation.fileThumb) : .Remote
                }
                
                progressView.userInteractionEnabled = status != .Local
            }))
        }
        
        
    }
    
    override func layout() {
        super.layout()
        let center = floorToScreenPixels(backingScaleFactor, frame.height / 2)
        actionText.setFrameOrigin(leftInset, isHasThumb ? center + 2 : 20)
        if isHasThumb {
            if let thumbProgress = thumbProgress {
                let f = thumbView.focus(thumbProgress.frame.size)
                thumbProgress.setFrameOrigin(f.origin)
            }
        } else {
            progressView?.setFrameOrigin(NSZeroPoint)
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
    

    override func cancel() {
        fetchDisposable.set(nil)
        statusDisposable.set(nil)
    }
    
    override func clean() {
        statusDisposable.dispose()
    }
    
}
