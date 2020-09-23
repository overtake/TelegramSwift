//
//  PeerPhotosMonthItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.10.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import SyncCore
import TGUIKit
import Postbox
import SwiftSignalKit

private struct LayoutItem : Equatable {
    static func == (lhs: LayoutItem, rhs: LayoutItem) -> Bool {
        return lhs.message == rhs.message && lhs.corners == rhs.corners && lhs.frame == rhs.frame
    }
    
    let message: Message
    let frame: NSRect
    let viewType:MediaCell.Type
    let corners:ImageCorners
    let chatInteraction: ChatInteraction
}

class PeerPhotosMonthItem: GeneralRowItem {
    private let items:[Message]
    fileprivate let context: AccountContext
    private var contentHeight: CGFloat = 0
    
    fileprivate private(set) var layoutItems:[LayoutItem] = []
    fileprivate private(set) var itemSize: NSSize = NSZeroSize
    fileprivate let chatInteraction: ChatInteraction
    fileprivate let gallerySupplyment: InteractionContentViewProtocol
    fileprivate let galleryType: GalleryAppearType
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, context: AccountContext, chatInteraction: ChatInteraction, gallerySupplyment: InteractionContentViewProtocol, items: [Message], galleryType: GalleryAppearType) {
        self.items = items
        self.context = context
        self.gallerySupplyment = gallerySupplyment
        self.chatInteraction = chatInteraction
        self.galleryType = galleryType
        
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets())
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        
        if !items.isEmpty {
            var t: time_t = time_t(TimeInterval(items[0].timestamp))
            var timeinfo: tm = tm()
            localtime_r(&t, &timeinfo)
            
            if timeinfo.tm_mon == 2 {
                var bp:Int = 0
                bp += 1
            }
            
        }
        
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        while true {
            let maximum = self.blockWidth - self.viewType.innerInset.left - self.viewType.innerInset.right - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        assert(rowCount >= 1)
                
        let itemSize = NSMakeSize(ceil(perWidth) + 2, ceil(perWidth) + 2)
        
        layoutItems.removeAll()
        var point: CGPoint = CGPoint(x: self.viewType.innerInset.left, y: self.viewType.innerInset.top + itemSize.height)
        for (i, message) in self.items.enumerated() {
            let viewType: MediaCell.Type
            if let file = message.media.first as? TelegramMediaFile {
                if file.isAnimated && file.isVideo {
                    viewType = MediaGifCell.self
                } else {
                    viewType = MediaVideoCell.self
                }
            } else {
                viewType = MediaPhotoCell.self
            }
            
            var topLeft: ImageCorner = .Corner(0)
            var topRight: ImageCorner = .Corner(0)
            var bottomLeft: ImageCorner = .Corner(0)
            var bottomRight: ImageCorner = .Corner(0)
            
            if self.items.count < rowCount {
                if message == self.items.first {
                    if self.viewType.position != .last {
                        topLeft = .Corner(.cornerRadius)
                    }
                    bottomLeft = .Corner(.cornerRadius)
                }
            } else if self.items.count == rowCount {
                if message == self.items.first {
                    if self.viewType.position != .last {
                        topLeft = .Corner(.cornerRadius)
                    }
                    bottomLeft = .Corner(.cornerRadius)
                } else if message == self.items.last {
                    if message == self.items.last {
                        if self.viewType.position != .last {
                            topRight = .Corner(.cornerRadius)
                        }
                        bottomRight = .Corner(.cornerRadius)
                    }
                }
            } else {
                let i = i + 1
                let firstLine = i <= rowCount
                let div = (items.count % rowCount) == 0 ? rowCount : (items.count % rowCount)
                let lastLine = i > (items.count - div)
                
                if firstLine {
                    if self.viewType.position != .last {
                        if i % rowCount == 1 {
                            topLeft = .Corner(.cornerRadius)
                        } else if i % rowCount == 0 {
                            topRight = .Corner(.cornerRadius)
                        }
                    }
                } else if lastLine {
                    if i % rowCount == 1 {
                        bottomLeft = .Corner(.cornerRadius)
                    } else if i % rowCount == 0 {
                        bottomRight = .Corner(.cornerRadius)
                    }
                }
            }
            
            
            let corners = ImageCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            self.layoutItems.append(LayoutItem(message: message, frame: CGRect(origin: point.offsetBy(dx: 0, dy: -itemSize.height), size: itemSize), viewType: viewType, corners: corners, chatInteraction: self.chatInteraction))
            point.x += itemSize.width
            if self.layoutItems.count % rowCount == 0, message != self.items.last {
                point.y += itemSize.height
                point.x = self.viewType.innerInset.left
            }
        }
        self.itemSize = itemSize
        self.contentHeight = point.y - self.viewType.innerInset.top
        return true
    }
    
    func contains(_ id: MessageId) -> Bool {
        return layoutItems.contains(where: { $0.message.id == id})
    }
    
    override var height: CGFloat {
        return self.contentHeight + self.viewType.innerInset.top + self.viewType.innerInset.bottom
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    deinit {

    }
    
    override func viewClass() -> AnyClass {
        return PeerPhotosMonthView.self
    }
    
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        var items:[ContextMenuItem] = []
        let layoutItem = layoutItems.first(where: { NSPointInRect(location, $0.frame) })
        if let layoutItem = layoutItem {
            let message = layoutItem.message
            if canForwardMessage(message, account: context.account) {
                items.append(ContextMenuItem(L10n.messageContextForward, handler: { [weak self] in
                    self?.chatInteraction.forwardMessages([message.id])
                }))
            }
            if canDeleteMessage(message, account: context.account, mode: .history) {
                items.append(ContextMenuItem(L10n.messageContextDelete, handler: { [weak self] in
                   self?.chatInteraction.deleteMessages([message.id])
                }))
            }
            items.append(ContextMenuItem(L10n.messageContextGoto, handler: { [weak self] in
                self?.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
            }))
        }
        return .single(items)
    }
}

private class MediaCell : Control {
    private var selectionView:SelectingControl?
    fileprivate let imageView: TransformImageView
    private(set) var layoutItem: LayoutItem?
    fileprivate var context: AccountContext?
    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame: NSMakeRect(1, 1, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(imageView)
        userInteractionEnabled = false
    }
    
    override func mouseMoved(with event: NSEvent) {
        superview?.superview?.mouseMoved(with: event)
    }
    override func mouseEntered(with event: NSEvent) {
        superview?.superview?.mouseEntered(with: event)
    }
    override func mouseExited(with event: NSEvent) {
        superview?.superview?.mouseExited(with: event)
    }
    func update(layout: LayoutItem, context: AccountContext, table: TableView?) {
        let previousLayout = self.layoutItem
        self.layoutItem = layout
        self.context = context
        if previousLayout != layout, !(self is MediaGifCell) {
            let media: Media
            let imageSize: NSSize
            let arguments: TransformImageArguments
            let cacheArguments: TransformImageArguments
            let signal: Signal<ImageDataTransformation, NoError>
            if let image = layout.message.media.first as? TelegramMediaImage, let largestSize = largestImageRepresentation(image.representations)?.dimensions.size {
                media = image
                imageSize = largestSize.aspectFilled(NSMakeSize(150, 150))
                arguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: layout.frame.size, intrinsicInsets: NSEdgeInsets())
                cacheArguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: NSMakeSize(150, 150), intrinsicInsets: NSEdgeInsets())
                signal = mediaGridMessagePhoto(account: context.account, imageReference: ImageMediaReference.message(message: MessageReference(layout.message), media: image), scale: backingScaleFactor)
            } else if let file = layout.message.media.first as? TelegramMediaFile {
                media = file
                let largestSize = file.previewRepresentations.last?.dimensions.size ?? file.imageSize
                imageSize = largestSize.aspectFilled(NSMakeSize(150, 150))
                arguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: layout.frame.size, intrinsicInsets: NSEdgeInsets())
                cacheArguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: NSMakeSize(150, 150), intrinsicInsets: NSEdgeInsets())
                signal = chatMessageVideo(postbox: context.account.postbox, fileReference: FileMediaReference.message(message: MessageReference(layout.message), media: file), scale: backingScaleFactor) //mediaGridMessageVideo(postbox: context.account.postbox, fileReference: FileMediaReference.message(message: MessageReference(layout.message), media: file), scale: backingScaleFactor)
            } else {
                return
            }
            
            self.imageView.set(arguments: arguments)
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: cacheArguments, scale: backingScaleFactor), clearInstantly: true)
            if !self.imageView.isFullyLoaded {
                self.imageView.setSignal(signal, animate: true, cacheImage: { [weak media] result in
                    if let media = media {
                        cacheMedia(result, media: media, arguments: cacheArguments, scale: System.backingScale)
                    }
                })
            }
        }
        updateSelectionState(animated: false)
    }
    
    override func copy() -> Any {
        return imageView.copy()
    }
    
    func innerAction() -> InvokeActionResult {
        return .gallery
    }
    
    func addAccesoryOnCopiedView(view: NSView) {
        
    }
    
    func updateMouse(_ inside: Bool) {
        
    }
    
    func updateSelectionState(animated: Bool) {
        if let layoutItem = layoutItem {
            if let selectionState = layoutItem.chatInteraction.presentation.selectionState {
                let selected = selectionState.selectedIds.contains(layoutItem.message.id)
                if let selectionView = self.selectionView {
                    selectionView.set(selected: selected, animated: animated)
                } else {
                    selectionView = SelectingControl(unselectedImage: theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected)
                   
                    addSubview(selectionView!)
                    selectionView?.set(selected: selected, animated: animated)
                    if animated {
                        selectionView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                        selectionView?.layer?.animateScaleCenter(from: 0.5, to: 1.0, duration: 0.2)
                    }
                }
            } else {
                if let selectionView = selectionView {
                    self.selectionView = nil
                    if animated {
                        selectionView.layer?.animateScaleCenter(from: 1.0, to: 0.5, duration: 0.2)
                        selectionView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak selectionView] completion in
                            selectionView?.removeFromSuperview()
                        })
                    } else {
                        selectionView.removeFromSuperview()
                    }
                }
            }
            needsLayout = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        imageView.frame = NSMakeRect(1, 1, frame.width - 2, frame.height - 2)
        
        if let selectionView = selectionView {
            selectionView.setFrameOrigin(frame.width - selectionView.frame.width - 5, 5)
        }
    }
}

private final class MediaPhotoCell : MediaCell {
    
}

private enum InvokeActionResult {
    case nothing
    case gallery
}



private final class MediaVideoCell : MediaCell {
    
    
    private final class VideoAutoplayView {
        let mediaPlayer: MediaPlayer
        let view: MediaPlayerView
        
        fileprivate var playTimer: SwiftSignalKit.Timer?
        var status: MediaPlayerStatus?
        
        init(mediaPlayer: MediaPlayer, view: MediaPlayerView) {
            self.mediaPlayer = mediaPlayer
            self.view = view
            mediaPlayer.actionAtEnd = .loop(nil)
        }
        
        deinit {
            view.removeFromSuperview()
            playTimer?.invalidate()
        }
    }
    
    private let mediaPlayerStatusDisposable = MetaDisposable()
    
    private let progressView:RadialProgressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
    private let videoAccessory: ChatMessageAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
    private var status:MediaResourceStatus?
    private var authenticStatus: MediaResourceStatus?
    private let statusDisposable = MetaDisposable()
    private let fetchingDisposable = MetaDisposable()
    private let partDisposable = MetaDisposable()
    
    private var videoView:VideoAutoplayView?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.videoAccessory)
        self.progressView.userInteractionEnabled = false
        self.addSubview(self.progressView)
    }
    
    override func updateMouse(_ inside: Bool) {
        if let layout = self.layoutItem {
            let file = layout.message.media.first as! TelegramMediaFile
            if inside {
                if file.isStreamable {
                    if videoView == nil {
                        let context = layout.chatInteraction.context
                        let player = MediaPlayer(postbox: context.account.postbox, reference: MediaResourceReference.media(media: AnyMediaReference.message(message: MessageReference(layout.message), media: file), resource: file.resource), streamable: true, video: true, preferSoftwareDecoding: true, enableSound: false, fetchAutomatically: false)
                        videoView = MediaVideoCell.VideoAutoplayView(mediaPlayer: player, view: MediaPlayerView(backgroundThread: true))
                        
                        videoView?.view.setVideoLayerGravity(.resizeAspectFill)
                        
                        var posititionFlags: LayoutPositionFlags = []
                        if layout.corners.topLeft.corner > 0 {
                            posititionFlags.insert(.top)
                            posititionFlags.insert(.left)
                        }
                        if layout.corners.topRight.corner > 0 {
                            posititionFlags.insert(.top)
                            posititionFlags.insert(.right)
                        }
                        if layout.corners.bottomLeft.corner > 0 {
                            posititionFlags.insert(.bottom)
                            posititionFlags.insert(.left)
                        }
                        if layout.corners.bottomRight.corner > 0 {
                            posititionFlags.insert(.bottom)
                            posititionFlags.insert(.right)
                        }
                        videoView?.view.positionFlags = posititionFlags.isEmpty ? nil : posititionFlags
                        videoView?.view.frame = self.imageView.frame
                        
                        videoView!.mediaPlayer.attachPlayerView(videoView!.view)
                        
                        videoView?.mediaPlayer.play()
                        
                        
                        self.addSubview(videoView!.view, positioned: .above, relativeTo: self.imageView)
                        
                        progressView.change(opacity: 0)
                    }
                    if let videoView = videoView {
                        mediaPlayerStatusDisposable.set((videoView.mediaPlayer.status |> deliverOnMainQueue).start(next: { [weak self] status in
                            self?.updateMediaStatus(status, animated: true)
                        }))
                    }
                    
                    
                } else {
                    progressView.change(opacity: 1)
                    videoView = nil
                    mediaPlayerStatusDisposable.set(nil)
                    updateVideoAccessory(self.authenticStatus ?? .Remote, mediaPlayerStatus: nil, file: file, animated: true)
                }
            } else {
                progressView.change(opacity: 1)
                videoView = nil
                mediaPlayerStatusDisposable.set(nil)
                updateVideoAccessory(self.authenticStatus ?? .Remote, mediaPlayerStatus: nil, file: file, animated: true)
            }
        }
    }
    
    private func updateMediaStatus(_ status: MediaPlayerStatus, animated: Bool = false) {
        if let videoView = videoView, let media = self.layoutItem?.message.media.first as? TelegramMediaFile {
            videoView.status = status
            updateVideoAccessory(self.authenticStatus ?? .Local, mediaPlayerStatus: status, file: media, animated: animated)
            
            switch status.status {
            case .playing:
                videoView.playTimer?.invalidate()
                videoView.playTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                    self?.updateVideoAccessory(self?.authenticStatus ?? .Local, mediaPlayerStatus: status, file: media, animated: animated)
                }, queue: .mainQueue())
                
                videoView.playTimer?.start()
            default:
                videoView.playTimer?.invalidate()
            }
            
            
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func fetch() {
        if let context = context, let layoutItem = self.layoutItem {
            let file = layoutItem.message.media.first as! TelegramMediaFile
            fetchingDisposable.set(messageMediaFileInteractiveFetched(context: context, messageId: layoutItem.message.id, fileReference: FileMediaReference.message(message: MessageReference(layoutItem.message), media: file)).start())
        }
    }
      
    private func cancelFetching() {
        if let context = context, let layoutItem = self.layoutItem {
            let file = layoutItem.message.media.first as! TelegramMediaFile
            messageMediaFileCancelInteractiveFetch(context: context, messageId: layoutItem.message.id, fileReference: FileMediaReference.message(message: MessageReference(layoutItem.message), media: file))
        }
    }
      
    override func innerAction() -> InvokeActionResult {
        if let file = layoutItem?.message.media.first as? TelegramMediaFile, let window = self.window {
            switch progressView.state {
            case .Fetching:
                if NSPointInRect(self.convert(window.mouseLocationOutsideOfEventStream, from: nil), progressView.frame) {
                    cancelFetching()
                } else if file.isStreamable {
                    return .gallery
                }
            case .Remote:
                fetch()
            default:
                return .gallery
            }
        }
        return .nothing
    }
    
    func preloadStreamblePart() {
        if let layoutItem = self.layoutItem {
            let context = layoutItem.chatInteraction.context
            if context.autoplayMedia.preloadVideos {
                if let media = layoutItem.message.media.first as? TelegramMediaFile, let fileSize = media.size {
                    let reference = FileMediaReference.message(message: MessageReference(layoutItem.message), media: media)
                    let preload = combineLatest(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: reference.resourceReference(media.resource), range: (0 ..< Int(2.0 * 1024 * 1024), .default), statsCategory: .video), fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: reference.resourceReference(media.resource), range: (max(0, fileSize - Int(256 * 1024)) ..< Int(Int32.max), .default), statsCategory: .video))
                    partDisposable.set(preload.start())
                }
            }
        }
    }
    
    private func updateVideoAccessory(_ status: MediaResourceStatus, mediaPlayerStatus: MediaPlayerStatus? = nil, file: TelegramMediaFile, animated: Bool) {
        let maxWidth = frame.width - 10
        let text: String
        
        let status: MediaResourceStatus = .Local
        
        
        if let status = mediaPlayerStatus, status.generationTimestamp > 0, status.duration > 0 {
            text = String.durationTransformed(elapsed: Int(status.duration - (status.timestamp + (CACurrentMediaTime() - status.generationTimestamp))))
        } else {
            text = String.durationTransformed(elapsed: file.videoDuration)
        }
        
        var isBuffering: Bool = false
        if let fetchStatus = self.authenticStatus, let status = mediaPlayerStatus {
            switch status.status {
            case .buffering:
                switch fetchStatus {
                case .Local:
                    break
                default:
                    isBuffering = true
                }
            default:
                break
            }
            
        }
        
        videoAccessory.updateText(text, maxWidth: maxWidth, status: status, isStreamable: file.isStreamable, isCompact: true, isBuffering: isBuffering, animated: animated, fetch: { [weak self] in
            self?.fetch()
        }, cancelFetch: { [weak self] in
            self?.cancelFetching()
        })
        needsLayout = true
    }
    
    override func update(layout: LayoutItem, context: AccountContext, table: TableView?) {
        super.update(layout: layout, context: context, table: table)
        let file = layout.message.media.first as! TelegramMediaFile
        
         let updatedStatusSignal = chatMessageFileStatus(account: context.account, file: file) |> deliverOnMainQueue |> map { status -> (MediaResourceStatus, MediaResourceStatus) in
           if file.isStreamable && layout.message.id.peerId.namespace != Namespaces.Peer.SecretChat {
               return (.Local, status)
           }
           return (status, status)
       }  |> deliverOnMainQueue
       
       var first: Bool = true
       
       statusDisposable.set(updatedStatusSignal.start(next: { [weak self] status, authentic in
           guard let `self` = self else {return}
           
            self.updateVideoAccessory(authentic, mediaPlayerStatus: self.videoView?.status, file: file, animated: !first)
            first = false
            self.status = status
            self.authenticStatus = authentic
            let progressStatus: MediaResourceStatus
            switch authentic {
            case .Fetching:
                progressStatus = authentic
            default:
                progressStatus = status
            }
            switch progressStatus {
            case let .Fetching(_, progress):
                self.progressView.state = .Fetching(progress: progress, force: false)
            case .Remote:
                self.progressView.state = .Remote
            case .Local:
                self.progressView.state = .Play
            }
        }))
        partDisposable.set(nil)
        self.preloadStreamblePart()
    }
    
    override func addAccesoryOnCopiedView(view: NSView) {
        let videoAccessory = self.videoAccessory.copy() as! ChatMessageAccessoryView
        if visibleRect.minY < videoAccessory.frame.midY && visibleRect.minY + visibleRect.height > videoAccessory.frame.midY {
             videoAccessory.frame.origin.y = frame.height - videoAccessory.frame.maxY
             view.addSubview(videoAccessory)
         }
        
        let pView = RadialProgressView(theme: progressView.theme, twist: true)
        pView.state = progressView.state
        pView.frame = progressView.frame
        if visibleRect.minY < progressView.frame.midY && visibleRect.minY + visibleRect.height > progressView.frame.midY {
            pView.frame.origin.y = frame.height - progressView.frame.maxY
            view.addSubview(pView)
        }
    }
    
    override func layout() {
        super.layout()
        progressView.center()
        videoAccessory.setFrameOrigin(5, 5)
        videoView?.view.frame = self.imageView.frame
    }
    
    deinit {
        statusDisposable.dispose()
        fetchingDisposable.dispose()
        partDisposable.dispose()
        mediaPlayerStatusDisposable.dispose()
    }
}



private final class MediaGifCell : MediaCell {
    private let gifView: GIFContainerView = GIFContainerView(frame: .zero)
    private var status:MediaResourceStatus?
    private let statusDisposable = MetaDisposable()
    private let fetchingDisposable = MetaDisposable()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.gifView)

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func fetch() {
        
    }
    
    private func cancelFetching() {

    }
    
    override func innerAction() -> InvokeActionResult {
        return .gallery
    }
    

    override func copy() -> Any {
        return gifView.copy()
    }
    
    override func update(layout: LayoutItem, context: AccountContext, table: TableView?) {
        let previousLayout = self.layoutItem
        super.update(layout: layout, context: context, table: table)
        if layout != previousLayout {
            let file = layout.message.media.first as! TelegramMediaFile
            
            let messageRefence = MessageReference(layout.message)
            
            let reference = FileMediaReference.message(message: messageRefence, media: file)            
            
            var effectiveFile = reference
            if let preview = file.videoThumbnails.first {
                let updated = file.withUpdatedResource(preview.resource)
                effectiveFile = FileMediaReference.message(message: messageRefence, media: updated)
            }
            let signal = chatMessageVideo(postbox: context.account.postbox, fileReference: effectiveFile, scale: backingScaleFactor)

            
            gifView.update(with: reference, size: frame.size, viewSize: frame.size, context: context, table: nil, iconSignal: signal)
            gifView.userInteractionEnabled = false
            
        }
        
    
    }
    
    
    override func layout() {
        super.layout()
        gifView.frame = NSMakeRect(1, 1, frame.width - 2, frame.height - 2)
        
    }
    
    deinit {
        statusDisposable.dispose()
        fetchingDisposable.dispose()
    }
}


private final class PeerPhotosMonthView : TableRowView, Notifable {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var contentViews:[Optional<MediaCell>] = []

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.containerView)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .Down)
        }, for: .Down)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .MouseDragging)
        }, for: .MouseDragging)
        
        containerView.set(handler: { [weak self] _ in
            self?.action(event: .Click)
        }, for: .Click)
    }
    
    private var haveToSelectOnDrag: Bool = false
    
    
    private weak var currentMouseCell: MediaCell?
    
    @objc override func updateMouse() {
        super.updateMouse()
        guard let window = self.window else {
            return
        }
        let point = self.containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let mediaCell = self.contentViews.first(where: {
            return $0 != nil && NSPointInRect(point, $0!.frame)
        })?.map { $0 }
        
        if currentMouseCell != mediaCell {
            currentMouseCell?.updateMouse(false)
        }
        currentMouseCell = mediaCell
        mediaCell?.updateMouse(window.isKeyWindow)
        
    }
    
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateMouse()
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateMouse()
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateMouse()
    }
    
    private func action(event: ControlEvent) {
        guard let item = self.item as? PeerPhotosMonthItem, let window = window else {
            return
        }
        let point = containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let layoutItem = item.layoutItems.first(where: { NSPointInRect(point, $0.frame) }) {
            if layoutItem.chatInteraction.presentation.state == .selecting {
                switch event {
                case .MouseDragging:
                    layoutItem.chatInteraction.update { current in
                        if !haveToSelectOnDrag {
                            return current.withRemovedSelectedMessage(layoutItem.message.id)
                        } else {
                            return current.withUpdatedSelectedMessage(layoutItem.message.id)
                        }
                    }
                case .Down:
                    layoutItem.chatInteraction.update { $0.withToggledSelectedMessage(layoutItem.message.id) }
                    haveToSelectOnDrag = layoutItem.chatInteraction.presentation.isSelectedMessageId(layoutItem.message.id)
                default:
                    break
                }
            } else {
                switch event {
                case .Click:
                    let view = self.contentViews.compactMap { $0 }.first(where: { $0.layoutItem == layoutItem })
                    if let view = view {
                        switch view.innerAction() {
                        case .gallery:
                            showChatGallery(context: item.context, message: layoutItem.message, item.gallerySupplyment, ChatMediaGalleryParameters(showMedia: { _ in}, showMessage: { message in
                                layoutItem.chatInteraction.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
                            }, isWebpage: false, media: layoutItem.message.media.first!, automaticDownload: true), type: item.galleryType, reversed: true)
                        case .nothing:
                            break
                        }
                    }
                default:
                    break
                }
            }
        }
    }
    
    func notify(with value: Any, oldValue:Any, animated:Bool) {
        if let value = value as? ChatPresentationInterfaceState, let oldValue = oldValue as? ChatPresentationInterfaceState {
            let views = contentViews.compactMap { $0 }
            for view in views {
                if let item = view.layoutItem {
                    if (value.state == .selecting) != (oldValue.state == .selecting) || value.isSelectedMessageId(item.message.id) != oldValue.isSelectedMessageId(item.message.id) {
                        view.updateSelectionState(animated: animated)
                    }
                }
            }
        }
    }
    
    func isEqual(to other: Notifable) -> Bool {
        if let other = other as? PeerPhotosMonthView {
            return other == self
        }
        return false
    }
       
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? PeerPhotosMonthItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        containerView.set(background: self.backdorColor, for: .Normal)
    }
    
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        updateVisibleItems()
        
        if let item = self.item as? PeerPhotosMonthItem {
            if superview == nil {
                item.chatInteraction.remove(observer: self)
            } else {
                item.chatInteraction.add(observer: self)
            }
        }
    }
    
    @objc private func updateVisibleItems() {
        layoutVisibleItems(animated: false)
    }
    
    private var previousRange: (Int, Int) = (0, 0)
    private var isCleaned: Bool = false
    
    private func layoutVisibleItems(animated: Bool) {
        guard let item = item as? PeerPhotosMonthItem else {
            return
        }
        let visibleRect = NSMakeRect(0, self.visibleRect.minY - item.itemSize.height, self.visibleRect.width, self.visibleRect.height + item.itemSize.height * 2)
        let size = item.itemSize
                
        if self.visibleRect != NSZeroRect && superview != nil && window != nil {
            let visibleRange = (Int(ceil(visibleRect.minY / (size.height))), Int(ceil(visibleRect.height / (size.height))))
            if visibleRange != self.previousRange {
                self.previousRange = visibleRange
                isCleaned = false
            } else {
                return
            }
        } else {
            self.previousRange = (0, 0)
            CATransaction.begin()
            if !isCleaned {
                for (i, view) in self.contentViews.enumerated() {
                    view?.removeFromSuperview()
                    self.contentViews[i] = nil
                }
            }
            isCleaned = true
            CATransaction.commit()
            return
        }
        

        CATransaction.begin()
          
        var unused:[MediaCell] = []
        for (i, layout) in item.layoutItems.enumerated() {
            if NSPointInRect(layout.frame.origin, visibleRect) {
                var view: MediaCell
                if self.contentViews[i] == nil || !self.contentViews[i]!.isKind(of: layout.viewType) {
                    view = layout.viewType.init(frame: layout.frame)
                    self.contentViews[i] = view
                } else {
                    view = self.contentViews[i]!
                }
                if view.layoutItem != layout {
                    view.update(layout: layout, context: item.context, table: item.table)
                }

                view.frame = layout.frame
            } else {
                if let view = self.contentViews[i] {
                    unused.append(view)
                    self.contentViews[i] = nil
                }
            }
        }
          
        for view in unused {
            view.removeFromSuperview()
        }
        
        containerView.subviews = self.contentViews.compactMap { $0 }

        CATransaction.commit()
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidMoveToWindow() {
         if window == nil {
             NotificationCenter.default.removeObserver(self)
         } else {
             NotificationCenter.default.addObserver(self, selector: #selector(updateVisibleItems), name: NSView.boundsDidChangeNotification, object: self.enclosingScrollView?.contentView)
            NotificationCenter.default.addObserver(self, selector: #selector(updateMouse), name: NSWindow.didBecomeKeyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(updateMouse), name: NSWindow.didResignKeyNotification, object: nil)
         }
         updateVisibleItems()
     }
    
    override func layout() {
        super.layout()
        guard let item = item as? PeerPhotosMonthItem else {
            return
        }
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        updateVisibleItems()
    }
    
    override func interactionContentView(for innerId: AnyHashable, animateIn: Bool) -> NSView {
        if let innerId = innerId.base as? MessageId {
            let view = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.message.id == innerId })
            return view ?? NSView()
        }
        return self
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        if let innerId = innerId.base as? MessageId {
            let cell = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.message.id == innerId })
            cell?.addAccesoryOnCopiedView(view: view)
        }
    }
    
    override func convertWindowPointToContent(_ point: NSPoint) -> NSPoint {
        return containerView.convert(point, from: nil)
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        
        super.set(item: item, animated: animated)
        
        guard let item = item as? PeerPhotosMonthItem else {
            return
        }
        
        item.chatInteraction.add(observer: self)
        
        self.previousRange = (0, 0)
        
        while self.contentViews.count > item.layoutItems.count {
            self.contentViews.removeLast()
        }
        while self.contentViews.count < item.layoutItems.count {
            self.contentViews.append(nil)
        }
        
        
        layoutVisibleItems(animated: animated)
    }
}

