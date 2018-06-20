//
//  WPArticleContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


class WPArticleContentView: WPContentView {
    private var durationView:VideoDurationView?
    private var progressIndicator:ProgressIndicator?
    private(set) var imageView:TransformImageView?
    private var playIcon:ImageView?
    private let openExternalDisposable:MetaDisposable = MetaDisposable()
    private let loadingStatusDisposable: MetaDisposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var countAccessoryView: ChatMessageAccessoryView?
    private var downloadIndicator: RadialProgressView?
    
    private var groupedContents: [ChatMediaContentView] = []
    private let groupedContentView: View = View()
    override var backgroundColor: NSColor {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
   
    
    required public init() {
        super.init()
    }
    
    deinit {
        openExternalDisposable.dispose()
        loadingStatusDisposable.dispose()
        statusDisposable.dispose()
        fetchDisposable.dispose()
    }
    
    override func viewDidMoveToSuperview() {
        if superview == nil {
            openExternalDisposable.set(nil)
            progressIndicator?.removeFromSuperview()
            progressIndicator?.animates = false
        } else if let progressIndicator = progressIndicator {
            imageView?.addSubview(progressIndicator)
            progressIndicator.animates = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    func open() {
        if let content = content?.content, let layout = self.content, let window = kitWindow {
            
            if layout.hasInstantPage {
                showInstantPage(InstantPageViewController(layout.account, webPage: layout.parent.media[0] as! TelegramMediaWebpage, message: layout.parent.text))
                return
            }
            
            if ExternalVideoLoader.isPlayable(content) {
                openExternalDisposable.set((sharedVideoLoader.status(for: content) |> deliverOnMainQueue).start(next: { (status) in
                    if let status = status {
                        switch status {
                        case .fail:
                            execute(inapp: .external(link: content.url, false))
                        case .loaded:
                            showChatGallery(account: layout.account, message: layout.parent, layout.table)
                        default:
                            break
                        }
                    }
                }))
                
                _ = sharedVideoLoader.fetch(for: content).start()
                return
            }
            if content.embedType == "iframe" {
                showModal(with: WebpageModalController(content:content,account:layout.account), for: window)
            } else if layout.isGalleryAssemble {
                showChatGallery(account: layout.account, message: layout.parent, layout.table, type: .alone)
            } else if !content.url.isEmpty {
                execute(inapp: .external(link: content.url, false))
            }

        }
    }
    
    func fetch() {
        if let layout = content as? WPArticleLayout, let image = layout.content.image {
            fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: layout.account, photo: image).start())
        }
    }
    
    func cancelFetching() {
         if let layout = content as? WPArticleLayout, let image = layout.content.image {
            chatMessagePhotoCancelInteractiveFetch(account: layout.account, photo: image)
            fetchDisposable.set(nil)
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        if let imageView = imageView, imageView._mouseInside(), event.clickCount == 1 {
            if let downloadProgressView = downloadIndicator {
                downloadProgressView.fetchControls?.fetch()
            } else {
                open()
            }
        } else {
            super.mouseUp(with: event)
        }
    }

    
    

    
    override func update(with layout: WPLayout) {
        
        if let layout = layout as? WPArticleLayout {
            
            if let groupLayout = layout.groupLayout {
                addSubview(groupedContentView)
                groupedContentView.setFrameSize(groupLayout.dimensions)
                
                if groupedContents.count > groupLayout.count {
                    let contentCount = groupedContents.count
                    let layoutCount = groupLayout.count
                    
                    for i in layoutCount ..< contentCount {
                        groupedContents[i].removeFromSuperview()
                    }
                    groupedContents = groupedContents.subarray(with: NSMakeRange(0, layoutCount))
                    
                    for i in 0 ..< groupedContents.count {
                        if !groupedContents[i].isKind(of: groupLayout.contentNode(for: i))  {
                            let node = groupLayout.contentNode(for: i)
                            let view = node.init(frame:NSZeroRect)
                            replaceSubview(groupedContents[i], with: view)
                            groupedContents[i] = view
                        }
                    }
                } else if groupedContents.count < groupLayout.count {
                    let contentCount = groupedContents.count
                    for i in contentCount ..< groupLayout.count {
                        let node = groupLayout.contentNode(for: i)
                        let view = node.init(frame:NSZeroRect)
                        groupedContents.append(view)
                    }
                }
                
                for content in groupedContents {
                    groupedContentView.addSubview(content)
                }
                
                assert(groupedContents.count == groupLayout.count)
                
                for i in 0 ..< groupLayout.count {
                    groupedContents[i].change(size: groupLayout.frame(at: i).size, animated: false)
                    let positionFlags: GroupLayoutPositionFlags = groupLayout.position(at: i)

                    
                    groupedContents[i].update(with: groupLayout.messages[i].media[0], size: groupLayout.frame(at: i).size, account: layout.account, parent: groupLayout.messages[i], table: layout.table, parameters: layout.parameters[i], animated: false, positionFlags: positionFlags)
                    
                    groupedContents[i].change(pos: groupLayout.frame(at: i).origin, animated: false)
                }
                
            } else {
                while !groupedContents.isEmpty {
                    groupedContents[0].removeFromSuperview()
                    groupedContents.removeFirst()
                }
                groupedContentView.removeFromSuperview()
            }
            

            if ExternalVideoLoader.isPlayable(layout.content) {
                loadingStatusDisposable.set((sharedVideoLoader.status(for: layout.content) |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let status = status , let strongSelf = self {
                        switch status {
                        case .fetching:
                            if strongSelf.progressIndicator == nil {
                                strongSelf.progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 25, 25))
                               // self?.progressIndicator?.set(color: .white)
                                strongSelf.imageView?.addSubview((strongSelf.progressIndicator)!)
                            }
                            strongSelf.progressIndicator?.center()
                            strongSelf.progressIndicator?.animates = true
                        default:
                            strongSelf.progressIndicator?.animates = false
                            strongSelf.progressIndicator?.removeFromSuperview()
                            strongSelf.progressIndicator = nil
                        }
                        strongSelf.needsLayout = true
                    }
                }))
            } else {
                progressIndicator?.animates = false
                progressIndicator?.removeFromSuperview()
                progressIndicator = nil
            }
            
            
            var updateImageSignal:Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            if self.content?.content.image != layout.content.image {
                if let image = layout.content.image {
                    updateImageSignal = chatWebpageSnippetPhoto(account: layout.account, photo: image, scale: backingScaleFactor, small: layout.smallThumb)
                   
                   
                    
                    let closestRepresentation = (largestImageRepresentation(image.representations))
                    
                    if let closestRepresentation = closestRepresentation {
                        statusDisposable.set((layout.account.postbox.mediaBox.resourceStatus(closestRepresentation.resource) |> deliverOnMainQueue).start(next: { [weak self] status in
                            
                            guard let `self` = self else {return}
                            

                            var initProgress: Bool = false
                            var state: RadialProgressState = .None
                            switch status {
                            case .Fetching:
                                state = .Fetching(progress: 0.8, force: false)
                                initProgress = true
                            case .Local:
                                break
                            case .Remote:
                                initProgress = true
                                state = .Remote
                            }
                            if initProgress {
                                
                                self.playIcon?.removeFromSuperview()
                                self.playIcon = nil
                                
                                if self.downloadIndicator == nil {
                                    self.downloadIndicator = RadialProgressView()
                                }
                                self.imageView?.addSubview(self.downloadIndicator!)
                                self.downloadIndicator!.center()
                                
                            } else {
                                self.downloadIndicator?.removeFromSuperview()
                                self.downloadIndicator = nil
                                
                                if ExternalVideoLoader.isPlayable(layout.content) && layout.isFullImageSize {
                                    if self.playIcon == nil {
                                        self.playIcon = ImageView()
                                        self.imageView?.addSubview(self.playIcon!)
                                    }
                                    self.playIcon?.image = ExternalVideoLoader.playIcon(layout.content)
                                    self.playIcon?.sizeToFit()
                                } else {
                                    self.playIcon?.removeFromSuperview()
                                    self.playIcon = nil
                                }
                            }
                            
                            self.downloadIndicator?.fetchControls = FetchControls(fetch: { [weak self] in
                                switch status {
                                case .Remote:
                                    self?.fetch()
                                case .Fetching:
                                    self?.cancelFetching()
                                case .Local:
                                    self?.open()
                                }
                            })
                            
                            self.downloadIndicator?.state = state
                            self.needsLayout = true
                            
                        }))
                    } else {
                        statusDisposable.set(nil)
                        downloadIndicator?.removeFromSuperview()
                        downloadIndicator = nil
                        
                    }
                    
                    if imageView == nil {
                        imageView = TransformImageView()
                        imageView?.alphaTransitionOnFirstUpdate = true
                        self.addSubview(imageView!)
                    }
                    
                    
                    
                    if let arguments = layout.imageArguments, let imageView = imageView {
                        imageView.set(arguments: arguments)
                        imageView.setSignal(signal: cachedMedia(media: image, size: arguments.imageSize, scale: backingScaleFactor))
                        
                        if let updateImageSignal = updateImageSignal, !imageView.hasImage {
                                imageView.setSignal(updateImageSignal, clearInstantly: false, animate: true, cacheImage: { [weak self] signal in
                                    if let strongSelf = self {
                                        return cacheMedia(signal: signal, media: image, size: arguments.imageSize, scale: strongSelf.backingScaleFactor)
                                    } else {
                                        return .complete()
                                    }
                                })
                            }
                        }
                    
                } else {
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
            }
            

            if let durationNode = layout.duration {
                if durationView == nil {
                    durationView = VideoDurationView(durationNode)
                    imageView?.addSubview(durationView!)
                } else {
                    durationView?.updateNode(durationNode)
                }
                durationView?.sizeToFit()
            } else {
                durationView?.removeFromSuperview()
                durationView = nil
            }
            
            if let mediaCount = layout.mediaCount {
                if countAccessoryView == nil {
                    countAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
                    imageView?.addSubview(countAccessoryView!)
                }
                countAccessoryView?.updateText(tr(L10n.chatWebpageMediaCount(1, mediaCount)), maxWidth: 40)
            } else {
                countAccessoryView?.removeFromSuperview()
                countAccessoryView = nil
            }
           
        }
        
        super.update(with: layout)
        
        if let layout = layout as? WPArticleLayout, layout.isAutoDownloable {
            fetch()
        }
        
    }
    
    override func layout() {
        super.layout()
        
        if let layout = self.content as? WPArticleLayout {
            
            if !textView.isEqual(to: layout.textLayout) {
                textView.update(layout.textLayout)
            }
            
            playIcon?.isHidden = progressIndicator != nil
            
            if groupedContentView.superview != nil {
                var origin:NSPoint = NSZeroPoint
                if let textLayout = layout.textLayout {
                    origin.y += textLayout.layoutSize.height + 6.0
                }
                groupedContentView.setFrameOrigin(origin)
            }
            
            if let imageView = imageView {
                
              
                
                if let arguments = layout.imageArguments {
                    imageView.set(arguments: arguments)
                    imageView.setFrameSize(arguments.boundingSize)
                }
                
                progressIndicator?.center()
                downloadIndicator?.center()
                
                var origin:NSPoint = NSMakePoint(layout.contentRect.width - imageView.frame.width - 10, 0)
                
                if layout.textLayout?.cutout == nil {
                    var y:CGFloat = 0
                    if let textLayout = layout.textLayout {
                        y += textLayout.layoutSize.height + 6.0
                    }
                    origin = NSMakePoint(0, y)
                }
                
                imageView.setFrameOrigin(origin.x, origin.y)
                playIcon?.center()
                
                if let durationView = durationView {
                    durationView.setFrameOrigin(imageView.frame.width - durationView.frame.width - 10, imageView.frame.height - durationView.frame.height - 10)
                }
                if let countAccessoryView = countAccessoryView {
                    countAccessoryView.setFrameOrigin(imageView.frame.width - countAccessoryView.frame.width - 10, 10)
                }
            }
        }
       
        
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool ) -> NSView {
        return !groupedContentView.subviews.isEmpty ? groupedContentView : self.imageView ?? self
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        if !groupedContents.isEmpty {
            return groupedContentView.convert(point, from: nil)
        }
        return super.convertWindowPointToContent(point)
    }
    
}
