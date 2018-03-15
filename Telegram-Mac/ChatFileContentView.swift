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

class ChatFileContentView: ChatMediaContentView {
    


    var actionsLayout:TextViewLayout?
    
    let progressView:RadialProgressView = RadialProgressView()
    
    private let thumbView:TransformImageView = TransformImageView()
    
    var titleNode:TextNode = TextNode()
    var actionText:TextView = TextView()
    
    var actionInteractions:TextViewInteractions = TextViewInteractions()
    
    private let statusDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        actionText.isSelectable = false
        self.addSubview(actionText)
        self.thumbView.setFrameSize(70,70)
        addSubview(thumbView)
        
        progressView.fetchControls = fetchControls
        addSubview(progressView)
        
        actionInteractions.processURL = {[weak self] (link) in
            if let link = link as? String, link.hasSuffix("download") {
                self?.executeInteraction(false)
            } else if let link = link as? String, link.hasSuffix("finder") {
                if let account = self?.account, let file = self?.media as? TelegramMediaFile {
                    showInFinder(file, account:account)
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
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            fetchDisposable.set(messageMediaFileInteractiveFetched(account: account, messageId: parent.id, file: media).start())
        }
    }
    
    override func open() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent  {
            if media.isGraphicFile {
                showChatGallery(account: account, message: parent, table, parameters as? ChatMediaGalleryParameters)
            } else {
                QuickLookPreview.current.show(account: account, with: media, stableId:parent.chatStableId, table)
            }
        }
    }

    
    override func cancelFetching() {
        if let account = account, let media = media as? TelegramMediaFile, let parent = parent {
            messageMediaFileCancelInteractiveFetch(account: account, messageId: parent.id, file: media)
        }
    }
    
    override func draggingAbility(_ event:NSEvent) -> Bool {
        return NSPointInRect(convert(event.locationInWindow, from: nil), progressView.frame)
    }
    
    func actionLayout(status:MediaResourceStatus, file:TelegramMediaFile, presentation: ChatMediaPresentation, paremeters: ChatFileLayoutParameters?) -> TextViewLayout? {
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        
        switch status {
        case let .Fetching(_, progress):
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                let _ = attr.append(string: tr(L10n.messagesFileStateFetchingOut1(Int(progress * 100.0))), color: presentation.grayText, font: .normal(.text))
            } else {
                let current = String.prettySized(with: Int(Float(file.elapsedSize) * progress))
                let size = "\(current) / \(String.prettySized(with: file.elapsedSize))"
                let _ = attr.append(string: size, color: presentation.grayText, font: .normal(.text))
            }
            let layout = TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
            layout.measure()
            return layout
            
        case .Local:
            return paremeters?.finderLayout
        case .Remote:
            return paremeters?.downloadLayout
        }
    }
    
    override func update(with media: Media, size:NSSize, account:Account, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool, positionFlags: GroupLayoutPositionFlags? = nil) {
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
        let mediaUpdated = true//self.media == nil || !self.media!.isEqual(media)
        
        let presentation: ChatMediaPresentation = parameters?.presentation ?? .Empty
        
        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated, positionFlags: positionFlags)
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        let parameters = parameters as? ChatFileLayoutParameters
        actionText.backgroundColor = theme.colors.background
        
        if mediaUpdated {
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                updatedStatusSignal = combineLatest(chatMessageFileStatus(account: account, file: file), account.pendingMessageManager.pendingMessageStatus(parent.id))
                    |> map { resourceStatus, pendingStatus -> MediaResourceStatus in
                        if let pendingStatus = pendingStatus {
                            return .Fetching(isActive: true, progress: pendingStatus.progress)
                        } else {
                            return resourceStatus
                        }
                    } |> deliverOnMainQueue
            } else {
                updatedStatusSignal = chatMessageFileStatus(account: account, file: file) |> deliverOnMainQueue
            }
            
            let stableId:Int64
            if let sId = parent?.stableId {
                stableId = Int64(sId)
            } else {
                stableId = file.id?.id ?? 0
            }
            
            if !file.previewRepresentations.isEmpty {
                
                let arguments = TransformImageArguments(corners: ImageCorners(radius: 8), imageSize: file.previewRepresentations[0].dimensions, boundingSize: NSMakeSize(70, 70), intrinsicInsets: NSEdgeInsets())
                
                thumbView.setSignal(signal: cachedMedia(messageId: stableId, size: arguments.imageSize, scale: backingScaleFactor))
                
                if !thumbView.hasImage {
                    thumbView.setSignal( chatMessageImageFile(account: account, file: file, progressive: false, scale: backingScaleFactor), clearInstantly: false, cacheImage: { [weak self] image in
                        if let strongSelf = self {
                            return cacheMedia(signal: image, messageId: stableId, size: arguments.imageSize, scale: strongSelf.backingScaleFactor)
                        } else {
                            return .complete()
                        }
                    })
                }
                
               
                thumbView.set(arguments: arguments)
            } else {
                thumbView.setSignal(signal: .single(nil))
            }
           
            self.setNeedsDisplay()
        }
        
        progressView.isHidden = true
        
        if let updatedStatusSignal = updatedStatusSignal {
            self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.fetchStatus = status
                    
                    let layout = strongSelf.actionLayout(status: status, file: file, presentation: presentation, paremeters: parameters)
                    if !strongSelf.actionText.isEqual(to :layout) {
                        layout?.interactions = strongSelf.actionInteractions
                        
                        strongSelf.actionText.update(layout)

                    }
                    strongSelf.progressView.isHidden = false
                    switch status {
                    case let .Fetching(_, progress):
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil)
                        strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                    case .Local:
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor:  file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: file.previewRepresentations.isEmpty ? presentation.fileThumb : nil)
                        strongSelf.progressView.state = .Play
                        strongSelf.progressView.isHidden = !file.previewRepresentations.isEmpty
                   case .Remote:
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? presentation.activityBackground : theme.colors.blackTransparent, foregroundColor: file.previewRepresentations.isEmpty ? presentation.activityForeground : .white, icon: nil)
                        strongSelf.progressView.state = .Remote
                    }
                    
                    strongSelf.progressView.userInteractionEnabled = status != .Local
                }
            }))
        }
        
        
    }
    
    override func layout() {
        super.layout()
        if let parameters = parameters as? ChatFileLayoutParameters {
            let center = floorToScreenPixels(scaleFactor: backingScaleFactor, (parameters.hasThumb ? 70 : 40) / 2)
            actionText.setFrameOrigin(leftInset, parameters.hasThumb ? center + 2 : 20)
            
            if parameters.hasThumb {
                let f = thumbView.focus(progressView.frame.size)
                progressView.setFrameOrigin(f.origin)
            } else {
                progressView.setFrameOrigin(NSZeroPoint)
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
            let center = floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height/2)
            name.1.draw(NSMakeRect(leftInset, isHasThumb ? center - name.0.size.height - 2 : 1, name.0.size.width, name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
    
    override func copy() -> Any {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView.copy()
        }
        return progressView.copy()
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView
        }
        return progressView
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
        fetchDisposable.dispose()
    }
    
}
