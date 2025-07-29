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
import InAppVideoServices
import SwiftSignalKit

private final class StickerPreviewView : View {
    private var preview: InlineStickerView?
    private var previews: [InlineStickerView] = []
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    func update(files: [TelegramMediaFile], context: AccountContext) {
        if files.count == 1 {
            if preview?.animateLayer.file?.fileId != files[0].fileId {
                if let current = preview {
                    current.removeFromSuperview()
                }
                let preview = InlineStickerView(account: context.account, file: files[0], size: NSMakeSize(50, 50), playPolicy: .loop)
                addSubview(preview)
                self.preview = preview
            }
        } else {
            while previews.count > files.count {
                previews.removeLast()
            }
            for (i, file) in files.enumerated() {
                let preview = previews.count > i ? previews[i] : nil
                if preview?.animateLayer.file?.fileId != file.fileId {
                    preview?.removeFromSuperview()
                    let current = InlineStickerView(account: context.account, file: file, size: NSMakeSize(20, 20), playPolicy: .loop)
                    if previews.count <= i {
                        previews.append(current)
                    } else {
                        previews[i] = current
                    }
                    addSubview(current)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        var x: CGFloat = 0
        var y: CGFloat = 0
        for (i, preview) in previews.enumerated() {
            preview.setFrameOrigin(x, y)
            x += preview.frame.width + 10
            if i % 2 == 1 {
                y += preview.frame.height + 10
                x = 0
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


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
    
    private var stickerPreview: StickerPreviewView?

    override func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        if let _ = imageView, let content = content as? WPArticleLayout, content.isFullImageSize, let image = content.content.image {
            if content.parent.adAttribute != nil {
                return (.image(ImageMediaReference.message(message: MessageReference(content.parent), media: image), ImagePreviewModalView.self), imageView)
            } else {
                return (.image(ImageMediaReference.webPage(webPage: WebpageReference(content.webPage), media: image), ImagePreviewModalView.self), imageView)
            }
        }
        return nil
    }
    
    override func previewMediaIfPossible() -> Bool {
        guard  let window = self._window, let content = content as? WPArticleLayout, content.isFullImageSize, let table = content.table, let imageView = imageView, imageView._mouseInside(), playIcon == nil, !content.hasInstantPage else {return false}
        startModalPreviewHandle(table, window: window, context: content.context)
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
        if let content = content?.content, let layout = self.content {
            
            if layout.hasInstantPage {
                BrowserStateContext.get(layout.context).open(tab: .instantView(url: layout.content.url, webPage: layout.parent.media[0] as! TelegramMediaWebpage, anchor: extractAnchor(from: layout.parent.text, matching: layout.content.url)))
                return
            }
            if layout.isGalleryAssemble {
                showChatGallery(context: layout.context, message: layout.parent, layout.table, type: .alone, chatMode: layout.chatInteraction.mode, chatLocation: layout.chatInteraction.chatLocation)
            } else if layout.isStory {
                layout.openStory()
            } else if let wallpaper = layout.wallpaper {
                execute(inapp: wallpaper)
            } else if let link = layout.themeLink {
                execute(inapp: link)
            } else if !content.url.isEmpty {
                let safe = layout.parent.webpagePreviewAttribute?.isSafe == true
                execute(inapp: .external(link: content.url, !safe))
            }

        }
    }
    
    func fetch() {
        if let layout = content as? WPArticleLayout {
            let mediaBox = layout.context.account.postbox.mediaBox
            if let _ = layout.wallpaper, let file = layout.content.file {
                fetchDisposable.set(fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(layout.parent.id.peerId), userContentType: .other, reference: MediaResourceReference.wallpaper(wallpaper: layout.wallpaperReference, resource: file.resource)).start())
            } else if let image = layout.content.image {
                if layout.parent.adAttribute != nil {
                    fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: layout.context.account, imageReference: ImageMediaReference.message(message: MessageReference(layout.parent), media: image)).start())
                } else {
                    fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: layout.context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(layout.webPage), media: image)).start())
                }
            } else if layout.isTheme, let file = layout.content.file {
                fetchDisposable.set(fetchedMediaResource(mediaBox: mediaBox, userLocation: .peer(layout.parent.id.peerId), userContentType: .other, reference: MediaResourceReference.wallpaper(wallpaper: layout.wallpaperReference, resource: file.resource)).start())
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
    
    override func mouseDown(with event: NSEvent) {
        if let imageView = imageView, imageView._mouseInside(), event.clickCount == 1 {
            
        } else {
            super.mouseDown(with: event)
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

    
    

    
    override func update(with layout: WPLayout, animated: Bool) {
        let newLayout = self.content?.content.displayUrl != layout.content.displayUrl
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
            
            var image = layout.groupLayout == nil ? layout.content.image : nil
            if layout.content.image == nil, let file = layout.content.file, let dimension = layout.imageSize {
                var representations: [TelegramMediaImageRepresentation] = []
                representations.append(contentsOf: file.previewRepresentations)
                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(dimension), resource: file.resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false))
                image = TelegramMediaImage(imageId: file.id ?? MediaId(namespace: 0, id: arc4random64()), representations: representations, immediateThumbnailData: file.immediateThumbnailData, reference: nil, partialReference: file.partialReference, flags: [])
                
            }
            var updateImageSignal:Signal<ImageDataTransformation, NoError>?
            if let image = image {
                if layout.wallpaper != nil || layout.isTheme {
                    let isPattern: Bool
                    if let settings = layout.content.themeSettings, let wallpaper = settings.wallpaper {
                        switch wallpaper {
                        case let .file(file):
                            isPattern = file.isPattern
                        default:
                            isPattern = false
                        }
                    } else {
                        isPattern = layout.isPatternWallpaper
                    }
                    updateImageSignal = chatWallpaper(account: layout.context.account, representations: image.representations, file: layout.content.file, webpage: layout.webPage, mode: .thumbnail, isPattern: isPattern, autoFetchFullSize: true, scale: backingScaleFactor, isBlurred: false, synchronousLoad: false)
                } else {
                    if layout.parent.adAttribute != nil {
                        updateImageSignal = chatWebpageSnippetPhoto(account: layout.context.account, imageReference: ImageMediaReference.message(message: MessageReference(layout.parent), media: image), scale: backingScaleFactor, small: layout.smallThumb)
                    } else {
                        updateImageSignal = chatWebpageSnippetPhoto(account: layout.context.account, imageReference: ImageMediaReference.webPage(webPage: WebpageReference(layout.webPage), media: image), scale: backingScaleFactor, small: layout.smallThumb)
                    }
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
                        case .Fetching, .Paused:
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
                            case .Fetching, .Paused:
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
                        imageView.setSignal(updateImageSignal, animate: true, cacheImage: { result in
                            cacheMedia(result, media: image, arguments: arguments, scale: System.backingScale)
                        })
                    }
                }
                
            } else if let palette = layout.content.crossplatformPalette, let wallpaper = layout.content.crossplatformWallpaper, let settings = layout.content.themeSettings {
                updateImageSignal = crossplatformPreview(accountContext: layout.context, palette: palette, wallpaper: wallpaper, mode: .thumbnail)
                
                
                self.playIcon?.removeFromSuperview()
                self.playIcon = nil

                
                if imageView == nil {
                    imageView = TransformImageView()
                    self.addSubview(imageView!)
                }
                
                if let arguments = layout.imageArguments, let imageView = imageView {
                    imageView.set(arguments: arguments)
                    imageView.setSignal(signal: cachedMedia(media: settings, arguments: arguments, scale: backingScaleFactor), clearInstantly: newLayout)
                    
                    if let updateImageSignal = updateImageSignal, !imageView.isFullyLoaded {
                        imageView.setSignal(updateImageSignal, animate: true, cacheImage: { result in
                            cacheMedia(result, media: settings, arguments: arguments, scale: System.backingScale)
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
                        case let .gradient(_, colors, settings):
                            if gradientView == nil {
                                gradientView = BackgroundView(frame: NSZeroRect)
                                self.addSubview(gradientView!)
                            }
                            gradientView?.layer?.cornerRadius = .cornerRadius
                            gradientView?.backgroundMode = .gradient(colors: colors, rotation: settings.rotation)
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
                countAccessoryView?.updateText(strings().chatWebpageMediaCount1(1, mediaCount), maxWidth: 40, status: nil, isStreamable: false)
            } else {
                countAccessoryView?.removeFromSuperview()
                countAccessoryView = nil
            }
            
            
            if layout.isStickerPreview, let imageSize = layout.imageSize {
                let current: StickerPreviewView
                if let view = self.stickerPreview {
                    current = view
                } else {
                    current = StickerPreviewView(frame: imageSize.bounds)
                    addSubview(current)
                    self.stickerPreview = current
                }
                current.update(files: layout.stickerFiles, context: layout.context)
            } else if let view = self.stickerPreview {
                performSubviewRemoval(view, animated: animated)
                self.stickerPreview = nil
            }
            
        }
        
        super.update(with: layout, animated: animated)
        
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
            
            if let stickerPreview {
                var origin:NSPoint = NSMakePoint(layout.contentRect.width - stickerPreview.frame.width, layout.imageInsets.top)
                if layout.textLayout?.cutout == nil {
                    var y:CGFloat = 0
                    if let textLayout = layout.textLayout {
                        y += textLayout.layoutSize.height + layout.imageInsets.top
                    }
                    origin = NSMakePoint(0, y)
                }
                stickerPreview.setFrameOrigin(origin.x, origin.y)
            }
            
            if let imageView = imageView {
                
                if let arguments = layout.imageArguments {
                    imageView.set(arguments: arguments)
                    imageView.setFrameSize(arguments.boundingSize)
                }
                
                progressIndicator?.center()
                downloadIndicator?.center()
                
                var origin:NSPoint = NSMakePoint(layout.contentRect.width - imageView.frame.width, layout.imageInsets.top)
                if layout.textLayout?.cutout == nil {
                    var y:CGFloat = 0
                    if let textLayout = layout.textLayout {
                        y += textLayout.layoutSize.height + layout.imageInsets.top
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
    
    override var mediaContentView: NSView? {
        return self.imageView
    }
    
}
