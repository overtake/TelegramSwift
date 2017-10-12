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
        if let account = account, let media = media as? TelegramMediaFile {
            fetchDisposable.set((chatMessageFileInteractiveFetched(account: account, file: media) |> mapToSignal { source -> Signal<Void, NoError> in
                if source == .remote {
                    return copyToDownloads(media, account: account)
                } else {
                    return .single(Void())
                }
            }).start())
        }
    }
    
    override func open() {
        if let account = account, let media = media, let parent = parent  {
            if media.isGraphicFile {
                showChatGallery(account: account, message: parent, table, parameters as? ChatMediaGalleryParameters)
            } else {
                QuickLookPreview.current.show(account: account, with: media, stableId:parent.chatStableId, table)
            }
        }
    }

    
    override func cancelFetching() {
        if let account = account, let media = media as? TelegramMediaFile {
            chatMessageFileCancelInteractiveFetch(account: account, file: media)
        }
    }
    
    override func draggingAbility(_ event:NSEvent) -> Bool {
        return NSPointInRect(convert(event.locationInWindow, from: nil), progressView.frame)
    }
    
    func actionLayout(status:MediaResourceStatus, file:TelegramMediaFile) -> TextViewLayout {
        let attr:NSMutableAttributedString = NSMutableAttributedString()
        
        switch status {
        case let .Fetching(_, progress):
            if let parent = parent, parent.flags.contains(.Unsent) && !parent.flags.contains(.Failed) {
                let _ = attr.append(string: tr(.messagesFileStateFetchingOut1(Int(progress * 100.0))), color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
            } else {
                let _ = attr.append(string: tr(.messagesFileStateFetchingIn1(Int(progress * 100.0))), color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
            }
        case .Local:

            let _ = attr.append(string: .prettySized(with: file.elapsedSize) + " - ", color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
            
            let range = attr.append(string: tr(.messagesFileStateLocal), color: theme.colors.link, font: NSFont.normal(FontSize.text))
            attr.addAttribute(NSAttributedStringKey.link, value: "chat://file/finder", range: range)
        case .Remote:
            let _ = attr.append(string: .prettySized(with: file.elapsedSize) + " - ", color: theme.colors.grayText, font: NSFont.normal(FontSize.text))
            let range = attr.append(string: tr(.messagesFileStateRemote), color: theme.colors.link, font: NSFont.normal(FontSize.text))
            attr.addAttribute(NSAttributedStringKey.link, value: "chat://file/download", range: range)
        }

        return TextViewLayout(attr, constrainedWidth:frame.width - leftInset, maximumNumberOfLines:1)
    }
    
    override func update(with media: Media, size:NSSize, account:Account, parent:Message?, table:TableView?, parameters:ChatMediaLayoutParameters? = nil, animated: Bool) {
        
        let file:TelegramMediaFile = media as! TelegramMediaFile
        let mediaUpdated = true//self.media == nil || !self.media!.isEqual(media)
        
        super.update(with: media, size: size, account: account, parent:parent,table:table, parameters:parameters, animated: animated)
        
        var updatedStatusSignal: Signal<MediaResourceStatus, NoError>?
        let parameters = parameters as? ChatFileLayoutParameters

        
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
            
            if !file.previewRepresentations.isEmpty {
                thumbView.setSignal(account: account, signal: chatMessageImageFile(account: account, file: file, progressive: false, scale: backingScaleFactor))
                thumbView.set(arguments: TransformImageArguments(corners: ImageCorners(radius: 4), imageSize: file.previewRepresentations[0].dimensions, boundingSize: NSMakeSize(70, 70), intrinsicInsets: NSEdgeInsets()))
            } else {
                thumbView.setSignal(signal: .single(nil))
            }
           
            self.setNeedsDisplay()
        }
        
        if let updatedStatusSignal = updatedStatusSignal {
            self.statusDisposable.set((updatedStatusSignal |> deliverOnMainQueue).start(next: { [weak self] status in
                if let strongSelf = self {
                    strongSelf.fetchStatus = status
                    
                    let layout = strongSelf.actionLayout(status: status, file: file)
                    if !strongSelf.actionText.isEqual(to :layout) {
                        layout.interactions = strongSelf.actionInteractions
                        layout.measure()
                        
                        strongSelf.actionText.update(layout)
                        var width = strongSelf.leftInset + layout.layoutSize.width
                        if let name = parameters?.name {
                            width = max(width, strongSelf.leftInset + name.0.size.width)
                        }
                    }
                    switch status {
                    case let .Fetching(_, progress):
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? theme.colors.blueFill : theme.colors.blackTransparent, foregroundColor: .white, icon: nil)
                        strongSelf.progressView.state = .Fetching(progress: progress, force: false)
                    case .Local:
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? theme.colors.blueFill : .clear, foregroundColor: .white, icon: file.previewRepresentations.isEmpty ? theme.icons.chatFileThumb : nil)
                        strongSelf.progressView.state = .Play
                   case .Remote:
                        strongSelf.progressView.theme = RadialProgressTheme(backgroundColor: file.previewRepresentations.isEmpty ? theme.colors.blueFill : theme.colors.blackTransparent, foregroundColor: .white, icon: nil)
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
            let center = floorToScreenPixels((parameters.hasThumb ? 70 : 40) / 2)
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
            let center = floorToScreenPixels(frame.height/2)
            name.1.draw(NSMakeRect(leftInset, isHasThumb ? center - name.0.size.height - 2 : 1, name.0.size.width, name.0.size.height), in: ctx, backingScaleFactor: backingScaleFactor)
        }
    }
    
    override func copy() -> Any {
        if let media = media as? TelegramMediaFile, !media.previewRepresentations.isEmpty {
            return thumbView.copy()
        }
        return progressView.copy()
    }
    
    override var interactionContentView: NSView {
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
    }
    
}
