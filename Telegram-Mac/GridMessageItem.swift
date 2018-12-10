//
//  GridMessageItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 26/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private func mediaForMessage(_ message: Message) -> Media? {
    for media in message.media {
        if let media = media as? TelegramMediaImage {
            return media
        } else if let file = media as? TelegramMediaFile {
            if file.mimeType.hasPrefix("audio/") {
                return nil
            } else if !file.isVideo && file.mimeType.hasPrefix("video/") {
                return file
            } else {
                return file
            }
        }
    }
    return nil
}



final class GridMessageItemSection: GridSection {
    let height: CGFloat = 36.0
    
    
    private let roundedTimestamp: Int32
    private let month: Int32
    private let year: Int32
    private let timestamp: Int32
    var hashValue: Int {
        return self.roundedTimestamp.hashValue
    }
    
    init(timestamp: Int32) {
        self.timestamp = timestamp
        var now = time_t(timestamp)
        var timeinfoNow: tm = tm()
        localtime_r(&now, &timeinfoNow)
        
        self.roundedTimestamp = timeinfoNow.tm_year * 100 + timeinfoNow.tm_mon
        self.month = timeinfoNow.tm_mon
        self.year = timeinfoNow.tm_year
    }
    
    func isEqual(to: GridSection) -> Bool {
        if let to = to as? GridMessageItemSection {
            return self.roundedTimestamp == to.roundedTimestamp
        } else {
            return false
        }
    }
    
    func node() -> View {
        return GridMessageItemSectionNode(timestamp: self.timestamp, month: self.month, year: self.year)
    }
}

final class GridMessageItemSectionNode: View {
  //  let titleNode: ASTextNode
    private let textView: TextView = TextView()
    init(timestamp: Int32, month: Int32, year: Int32) {
      
        
    //    self.titleNode = ASTextNode()
     //   self.titleNode.isLayerBacked = true
        
        super.init()
        
        addSubview(textView)
        
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM YYYY"
        
        let layout = TextViewLayout(.initialize(string: formatter.string(from: date), color: theme.colors.text, font: .normal(.title)), maximumNumberOfLines: 1)
        
        layout.measure(width: .greatestFiniteMagnitude)
        textView.update(layout)
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        textView.centerY(x: 10, addition: -2)
        
      //  let bounds = self.bounds
        
  //      let titleSize = self.titleNode.measure(CGSize(width: bounds.size.width - 24.0, height: CGFloat.greatestFiniteMagnitude))
      //  self.titleNode.frame = CGRect(origin: CGPoint(x: 12.0, y: 8.0), size: titleSize)
    }
}

final class GridMessageItem: GridItem {
    private let account: Account
    private let message: Message
    private let chatInteraction: ChatInteraction
    
    let section: GridSection?
    fileprivate weak var grid:GridNode?
    init(account: Account, message: Message, chatInteraction: ChatInteraction) {
        self.section = GridMessageItemSection(timestamp: message.timestamp)
        self.account = account
        self.message = message
        self.chatInteraction = chatInteraction
    }
    
    
    func update(node: GridItemNode) {
        guard let node = node as? GridMessageItemNode else {
            assertionFailure()
            return
        }
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, media: media, message: self.message, chatInteraction: self.chatInteraction)
        }
    }
    
    func node(layout: GridNodeLayout, gridNode:GridNode, cachedNode: GridItemNode?) -> GridItemNode {
        let node = GridMessageItemNode(gridNode)
        if let media = mediaForMessage(self.message) {
            node.setup(account: self.account, media: media, message: self.message, chatInteraction: self.chatInteraction)
        }
        return node
    }
}

final class GridMessageItemNode: GridItemNode {
    private var videoAccessory: ChatMessageAccessoryView?
    private var currentState: (Account, Media, CGSize)?
    private let imageView: TransformImageView
    private(set) var message: Message?
    private var chatInteraction: ChatInteraction?
    private var selectionView:SelectingControl?
    private var progressView:RadialProgressView?
    private var _status:MediaResourceStatus?
    private let statusDisposable = MetaDisposable()
    private let fetchingDisposable = MetaDisposable()
    override var stableId: AnyHashable {
        return (message?.chatStableId ?? ChatHistoryEntryId.undefined)
    }

    
    override func menu(for event: NSEvent) -> NSMenu? {
        if let message = message, let account = currentState?.0 {
            let menu = ContextMenu()


            if canForwardMessage(message, account: account) {
                menu.addItem(ContextMenuItem(tr(L10n.messageContextForward), handler: { [weak self] in
                    self?.chatInteraction?.forwardMessages([message.id])
                }))
            }
            
            if canDeleteMessage(message, account: account) {
                menu.addItem(ContextMenuItem(tr(L10n.messageContextDelete), handler: { [weak self] in
                   self?.chatInteraction?.deleteMessages([message.id])
                }))
            }
            
            menu.addItem(ContextMenuItem(tr(L10n.messageContextGoto), handler: { [weak self] in
                self?.chatInteraction?.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: true, inset: 0))
            }))
            return menu
        }
        return nil
    }
    
    override init(_ grid:GridNode) {
        self.imageView = TransformImageView()
        
        super.init(grid)
        
        self.addSubview(self.imageView)
        
    }
    
    private func fetch() {
        if let currentState = currentState, let message = message {
            if let file = message.media.first as? TelegramMediaFile {
                fetchingDisposable.set(messageMediaFileInteractiveFetched(account: currentState.0, messageId: message.id, fileReference: FileMediaReference.message(message: MessageReference(message), media: file)).start())
            }
        }
    }
    
    private func cancelFetching() {
        if let currentState = currentState, let message = message {
            if let file = message.media.first as? TelegramMediaFile {
               messageMediaFileCancelInteractiveFetch(account: currentState.0, messageId: message.id, fileReference: FileMediaReference.message(message: MessageReference(message), media: file))
            }
        }
    }
    
    
    override func mouseUp(with event: NSEvent) {
        if mouseInside() {
            if let interactions = chatInteraction, let currentState = currentState, let message = message {
                if interactions.presentation.state == .selecting {
                    interactions.update({$0.withToggledSelectedMessage(message.id)})
                    updateSelectionState(animated: true)
                } else if let file = message.media.first as? TelegramMediaFile  {
                    
                    if let progressView = progressView {
                        switch progressView.state {
                        case .Fetching:
                            if NSPointInRect(self.convert(event.locationInWindow, from: nil), progressView.frame) {
                                cancelFetching()
                            } else if file.isStreamable {
                                showChatGallery(account: currentState.0, message: message, grid, ChatMediaGalleryParameters(showMedia: { _ in}, showMessage: { [weak interactions] message in
                                    interactions?.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: true, inset: 0))
                                }, isWebpage: false, media: message.media.first!, automaticDownload: true), reversed: true)
                            }
                        case .Remote:
                            fetch()
                        default:
                            showChatGallery(account: currentState.0, message: message, grid, ChatMediaGalleryParameters(showMedia: { _ in}, showMessage: { [weak interactions] message in
                                interactions?.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: true, inset: 0))
                            }, isWebpage: false, media: message.media.first!, automaticDownload: true), reversed: true)
                        }
                        
                    }
                } else {
                    if _status == nil || _status == .Local {
                        showChatGallery(account: currentState.0, message: message, grid, ChatMediaGalleryParameters(showMedia: { _ in}, showMessage: { [weak interactions] message in
                            interactions?.focusMessageId(nil, message.id, .center(id: 0, innerId: nil, animated: false, focus: true, inset: 0))
                        }, isWebpage: false, media: message.media.first!, automaticDownload: true), reversed: true)
                    }
                }
            }
        }
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func copy() -> Any {
        return imageView.copy()
    }
    
    private func updateVideoAccessory(_ status: MediaResourceStatus, file: TelegramMediaFile) {
        let maxWidth = frame.width - 10
        let text: String
        
        
         text = String.durationTransformed(elapsed: file.videoDuration)
        
        
        videoAccessory?.updateText(text, maxWidth: maxWidth, status: status, isStreamable: file.isStreamable, isCompact: true, fetch: { [weak self] in
            self?.fetch()
        }, cancelFetch: { [weak self] in
            self?.cancelFetching()
        })
        needsLayout = true
    }
    
    
    func setup(account: Account, media: Media, message: Message, chatInteraction: ChatInteraction) {
        
        let semanticMedia = self.currentState?.1.id == media.id

        
        if self.currentState == nil || self.currentState!.0 !== account || !self.currentState!.1.isEqual(to: media) {
            var mediaDimensions: CGSize?
            backgroundColor = theme.colors.background
            statusDisposable.set(nil)

            let imageFrame = NSMakeRect(1, 1, bounds.width - 4, bounds.height - 4)

            
            if let media = media as? TelegramMediaImage, let largestSize = largestImageRepresentation(media.representations)?.dimensions {
                mediaDimensions = largestSize

                let imageSize = largestSize.aspectFilled(NSMakeSize(bounds.width - 4, bounds.height - 4))
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: NSEdgeInsets())
                self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor), clearInstantly: !semanticMedia)

                self.imageView.setSignal( mediaGridMessagePhoto(account: account, imageReference: ImageMediaReference.message(message: MessageReference(message), media: media), scale: backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { [weak self] image in
                    if let strongSelf = self {
                        return cacheMedia(signal: image, media: media, arguments: arguments, scale: strongSelf.backingScaleFactor)
                    } else {
                        return .complete()
                    }
                })
                progressView?.removeFromSuperview()
                progressView = nil
                
                self.videoAccessory?.removeFromSuperview()
                self.videoAccessory = nil
            } else if let file = media as? TelegramMediaFile, let imgSize = file.previewRepresentations.last?.dimensions {

                mediaDimensions = imgSize

                let imageSize = imgSize.aspectFilled(NSMakeSize(bounds.width, bounds.height))
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: NSEdgeInsets())

                self.imageView.setSignal(signal: cachedMedia(media: media, arguments: arguments, scale: backingScaleFactor), clearInstantly: !semanticMedia)

                self.imageView.setSignal( mediaGridMessageVideo(postbox: account.postbox, fileReference: FileMediaReference.message(message: MessageReference(message), media: file), scale: backingScaleFactor), clearInstantly: false, animate: true, cacheImage: { [weak self] image in
                    if let strongSelf = self {
                        return cacheMedia(signal: image, media: media, arguments: arguments, scale: strongSelf.backingScaleFactor)
                    } else {
                        return .complete()
                    }
                })
                
                self.imageView.set(arguments: arguments)

                let updatedStatusSignal = chatMessageFileStatus(account: account, file: file) |> deliverOnMainQueue |> map { [weak message, weak file] status -> (MediaResourceStatus, MediaResourceStatus) in
                    if let message = message, let file = file {
                        if file.isStreamable && message.id.peerId.namespace != Namespaces.Peer.SecretChat {
                            return (.Local, status)
                        }
                    }
                    return (status, status)
                }  |> deliverOnMainQueue

                statusDisposable.set(updatedStatusSignal.start(next: { [weak self] status, authentic in
                    guard let `self` = self else {return}
                    
                    if self.progressView == nil {
                        self.progressView = RadialProgressView(theme: RadialProgressTheme(backgroundColor: .blackTransparent, foregroundColor: .white, icon: playerPlayThumb))
                        self.progressView?.userInteractionEnabled = false
                        self.addSubview(self.progressView!)
                        self.progressView?.center()
                    }
                    if self.videoAccessory == nil {
                        self.videoAccessory = ChatMessageAccessoryView(frame: NSZeroRect)
                        self.addSubview(self.videoAccessory!)
                    }
                    
                    self.updateVideoAccessory(authentic, file: file)
                    
                    self._status = status
                    
                    let progressStatus: MediaResourceStatus
                    switch authentic {
                    case .Fetching:
                        progressStatus = authentic
                    default:
                        progressStatus = status
                    }
                    
                    switch progressStatus {
                    case let .Fetching(_, progress):
                        self.progressView?.state = .Fetching(progress: progress, force: false)
                    case .Remote:
                        self.progressView?.state = .Remote
                    case .Local:
                        self.progressView?.state = .Play
                    }
                }))

            }


            self.currentState = (account, media, mediaDimensions ?? NSMakeSize(100, 100))
        } else {
            needsLayout = true
        }

        self.message = message
        self.chatInteraction = chatInteraction

        self.updateSelectionState(animated: false)
        
    }
    
    override func layout() {
        super.layout()
        
        let imageFrame = NSMakeRect(1, 1, bounds.width - 4, bounds.height - 4)
        self.imageView.frame = imageFrame
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFilled(imageFrame.size)
            self.imageView.set(arguments: TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageFrame.size, intrinsicInsets: NSEdgeInsets()))
        }
        if let selectionView = selectionView {
            selectionView.setFrameOrigin(frame.width - selectionView.frame.width - 5, 5)
        }
        progressView?.center()
        videoAccessory?.setFrameOrigin(5, 5)
    }
    
    func updateSelectionState(animated: Bool) {
        if let messageId = self.message?.id, let interactions = self.chatInteraction {
            if let selectionState = interactions.presentation.selectionState {
                let selected = selectionState.selectedIds.contains(messageId)
                
                if let selectionView = self.selectionView {
                    selectionView.set(selected: selected, animated: animated)
                } else {
                    selectionView = SelectingControl(unselectedImage: theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected)
                    
                    addSubview(selectionView!)
                    selectionView?.set(selected: selected, animated: animated)
                    
                }
            } else {
                if let selectionView = selectionView {
                    self.selectionView = nil
                    if animated {
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
    
    deinit {
        statusDisposable.dispose()
    }

}
