//
//  WPArticleContentView.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit


class WPArticleContentView: WPContentView {
    private var durationView:VideoDurationView?
    private var progressIndicator:ProgressIndicator?
    private(set) var imageView:TransformImageView?
    private(set) var gradientView: BackgroundView?
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
    
    override func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let _ = imageView, let content = content as? WPArticleLayout, content.isFullImageSize, let image = content.content.image {
            return (.image(ImageMediaReference.webPage(webPage: WebpageReference(content.webPage), media: image), ImagePreviewModalView.self), imageView)
        }
        return nil
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard  let window = self.kitWindow, let content = content as? WPArticleLayout, content.isFullImageSize, let table = content.table, let imageView = imageView, imageView._mouseInside(), playIcon == nil, !content.hasInstantPage else {return false}
        _ = startModalPreviewHandle(table, window: window, context: content.context)
        return true
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
    
    override func updateMouse() {
        super.updateMouse()
        for content in groupedContentView.subviews.compactMap({$0 as? ChatMediaContentView}) {
            content.updateMouse()
        }
    }
    
    func open() {
        if let content = content?.content, let layout = self.content, let window = kitWindow {
            
            if layout.hasInstantPage {
                showInstantPage(InstantPageViewController(layout.context, webPage: layout.parent.media[0] as! TelegramMediaWebpage, message: layout.parent.text))
                return
            }
            
            if ExternalVideoLoader.isPlayable(content) {
                openExternalDisposable.set((sharedVideoLoader.status(for: content) |> deliverOnMainQueue).start(next: { (status) in
                    if let status = status {
                        switch status {
                        case .fail:
                            execute(inapp: .external(link: content.url, false))
                        case .loaded:
                            showChatGallery(context: layout.context, message: layout.parent, layout.table)
                        default:
                            break
                        }
                    }
                }))
                
                _ = sharedVideoLoader.fetch(for: content).start()
                return
            }
            if content.embedType == "iframe" {
                showModal(with: WebpageModalController(content:content, context: layout.context), for: window)
            } else if layout.isGalleryAssemble {
                showChatGallery(context: layout.context, message: layout.parent, layout.table, type: .alone)
            } else if let wallpaper = layout.wallpaper {
                execute(inapp: wallpaper)
            } else if let link = layout.themeLink {
                execute(inapp: link)
            } else if !content.url.isEmpty {
                execute(inapp: .external(link: content.url, false))
            }

        }
    }
    
    func fetch() {
        if let layout = content as? WPArticleLayout {
            if let _ = layout.wallpaper, let file = layout.content.file {
                fetchDisposable.set(fetchedMediaResource(mediaBox: layout.context.account.postbox.mediaBox, reference: MediaResourceReference.wallpaper(resource: file.resource)).start())
            } else if let image = layout.content.image {
                fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: layout.context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(layout.webPage), media: image)).start())
            } else if layout.isTheme, let file = layout.content.file {
                fetchDisposable.set(fetchedMediaResource(mediaBox: layout.context.account.postbox.mediaBox, reference: MediaResourceReference.wallpaper(resource: file.resource)).start())
            }
        }
    }
    
    func cancelFetching() {
         if let layout = content as? WPArticleLayout {
            if let _ = layout.wallpaper, let file = layout.content.file {
                fileCancelInteractiveFetch(account: layout.context.account, file: file)
            } else if let image = layout.content.image {
                chatMessagePhotoCancelInteractiveFetch(account: layout.context.account, photo: image)
            } else if layout.isTheme, let file = layout.content.file {
                fileCancelInteractiveFetch(account: layout.context.account, file: file)
            }
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
        let newLayout = self.content !== layout
        if let layout = layout as? WPArticleLayout {
            
            let synchronousLoad = layout.approximateSynchronousValue
            
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
                    let positionFlags: LayoutPositionFlags = groupLayout.position(at: i)

                    
                    groupedContents[i].update(with: groupLayout.messages[i].media[0], size: groupLayout.frame(at: i).size, context: layout.context, parent: layout.parent.withUpdatedGroupingKey(groupLayout.messages[i].groupingKey), table: layout.table, parameters: layout.parameters[i], animated: false, positionFlags: positionFlags, approximateSynchronousValue: synchronousLoad)
                    
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
            
            var image = layout.content.image
            if layout.content.image == nil, let file = layout.content.file, let dimension = layout.imageSize {
                var representations: [TelegramMediaImageRepresentation] = []
                representations.append(contentsOf: file.previewRepresentations)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(dimension), resource: file.resource))
                image = TelegramMediaImage(imageId: file.id ?? MediaId(namespace: 0, id: arc4random64()), representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference)
                
            }
            var updateImageSignal:Signal<ImageDataTransformation, NoError>?
            if let image = image {
                if layout.wallpaper != nil || layout.isTheme {
                    updateImageSignal = chatWallpaper(account: layout.context.account, representations: image.representations, file: layout.content.file, webpage: layout.webPage, mode: .screen, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false)
                } else {
                    updateImageSignal = chatWebpageSnippetPhoto(account: layout.context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(layout.webPage), media: image), scale: backingScaleFactor, small: layout.smallThumb)
                }
                
                if imageView == nil {
                    imageView = TransformImageView()
                    self.addSubview(imageView!)
                }
                
                let closestRepresentation = image.representationForDisplayAtSize(PixelDimensions(1280, 1280))
                
                if let closestRepresentation = closestRepresentation {
                    statusDisposable.set((layout.context.account.postbox.mediaBox.resourceStatus(closestRepresentation.resource, approximateSynchronousValue: synchronousLoad) |> deliverOnMainQueue).start(next: { [weak self] status in
                        
                        guard let `self` = self else {return}
                        
                        var initProgress: Bool = false
                        var state: RadialProgressState = .None
                        switch status {
                        case .Fetching:
                            state = .Fetching(progress: 0.3, force: false)
                            initProgress = true
                        case .Local:
                            state = .Fetching(progress: 1.0, force: false)
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
                            
                            let playable = ExternalVideoLoader.isPlayable(layout.content)
                            if layout.isFullImageSize, let icon = ExternalVideoLoader.playIcon(layout.content) {
                                if self.playIcon == nil {
                                    self.playIcon = ImageView()
                                    self.imageView?.addSubview(self.playIcon!)
                                }
                                self.playIcon?.image = icon
                                self.playIcon?.sizeToFit()
                            } else {
                                self.playIcon?.removeFromSuperview()
                                self.playIcon = nil
                            }
                            
                            if let progressView = self.downloadIndicator {
                                progressView.state = state
                                
                                self.downloadIndicator = nil
                                if playable {
                                    progressView.removeFromSuperview()
                                } else {
                                    progressView.layer?.animateAlpha(from: 1, to: 0, duration: 0.25, timingFunction: .linear, removeOnCompletion: false, completion: { [weak progressView] completed in
                                        if completed {
                                            progressView?.removeFromSuperview()
                                        }
                                    })
                                }
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
                
                
                
                
                if let arguments = layout.imageArguments, let imageView = imageView {
                   imageView.set(arguments: arguments)
                   imageView.setSignal(signal: cachedMedia(media: image, arguments: arguments, scale: backingScaleFactor), clearInstantly: newLayout)
                    
                    if let updateImageSignal = updateImageSignal, !imageView.isFullyLoaded {
                        imageView.setSignal(updateImageSignal, animate: true, cacheImage: { [weak image] result in
                            if let media = image {
                                cacheMedia(result, media: media, arguments: arguments, scale: System.backingScale)
                            }
                        })
                    }
                }
                
            } else {
                
                var removeImageView: Bool = true
                var removeGradientView: Bool = true
                if let wallpaper = layout.wallpaper {
                    switch wallpaper {
                    case let .wallpaper(_, _, preview):
                        switch preview {
                        case let .color(color):
                            if imageView == nil {
                                imageView = TransformImageView()
                                self.addSubview(imageView!)
                            }
                            imageView?.layer?.cornerRadius = .cornerRadius
                            imageView?.background = color
                            removeImageView = false
                        case let .gradient(top, bottom):
                            if gradientView == nil {
                                gradientView = BackgroundView(frame: NSZeroRect)
                                self.addSubview(gradientView!)
                            }
                            gradientView?.layer?.cornerRadius = .cornerRadius
                            gradientView?.backgroundMode = .gradient(top: top, bottom: bottom)
                            removeImageView = true
                            removeGradientView = false
                        default:
                            break
                        }
                    default:
                        break
                    }
                }
                if removeImageView {
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
                if removeGradientView {
                    gradientView?.removeFromSuperview()
                    gradientView = nil
                }
                downloadIndicator?.removeFromSuperview()
                downloadIndicator = nil
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
                countAccessoryView?.updateText(L10n.chatWebpageMediaCount(1, mediaCount), maxWidth: 40, status: nil, isStreamable: false)
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
            if let gradientView = gradientView {
                if let arguments = layout.imageArguments {
                    gradientView.setFrameSize(arguments.boundingSize)
                }
                let origin:NSPoint = NSMakePoint(layout.contentRect.width - gradientView.frame.width, 0)
                gradientView.setFrameOrigin(origin.x, origin.y)
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
