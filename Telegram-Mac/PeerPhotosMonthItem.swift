//
//  PeerPhotosMonthItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.10.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore
import TelegramMediaPlayer
import TGUIKit
import Postbox
import SwiftSignalKit
import TelegramMedia

private let story_privacy_some_users = NSImage(resource: .iconPeerStorySomeUsers).precomposed(.white)
private let story_privacy_contacts = NSImage(resource: .iconPeerStoryContacts).precomposed(.white)
private let story_privacy_close_friends = NSImage(resource: .iconPeerStoryCloseFriends).precomposed(.white)
private let story_privacy_everyone = NSImage(resource: .iconPeerStoryEveryone).precomposed(.white)
private let story_pinned = NSImage(resource: .iconPeerStoryPinned).precomposed(.white)

protocol MediaCellLayoutable {
    var context: AccountContext { get }
    var viewType:MediaCell.Type { get }
    var frame: NSRect { get }
    var corners:ImageCorners { get }
    var hasImmediateData: Bool { get }
    var isSecret: Bool { get }
    var isSpoiler: Bool { get }
    var isSensitive: Bool { get }
    var id: MessageId { get }
    var peerId: PeerId { get }

    var imageMedia: ImageMediaReference? { get }
    var fileMedia: FileMediaReference? { get }
    

    func isEqual(to: MediaCellLayoutable) -> Bool
    
    func makeImageReference(_ image: TelegramMediaImage) -> ImageMediaReference
    func makeFileReference(_ file: TelegramMediaFile) -> FileMediaReference

}

struct MediaCellLayoutItem : Equatable, MediaCellLayoutable {
    static func == (lhs: MediaCellLayoutItem, rhs: MediaCellLayoutItem) -> Bool {
        return lhs.message == rhs.message && lhs.corners == rhs.corners && lhs.frame == rhs.frame
    }
    
    func isEqual(to: MediaCellLayoutable) -> Bool {
        if let to = to as? MediaCellLayoutItem {
            return to == self
        } else {
            return false
        }
    }
    
    let message: Message
    let frame: NSRect
    let viewType:MediaCell.Type
    let corners:ImageCorners
    let context: AccountContext
    
    var isSecret: Bool {
        return self.message.isMediaSpoilered || self.message.containsSecretMedia
    }
    var isSpoiler: Bool {
        return self.message.isMediaSpoilered || self.message.isSensitiveContent(platform: "ios")
    }
    
    var isSensitive: Bool {
        return self.message.isSensitiveContent(platform: "ios") && !context.contentConfig.sensitiveContentEnabled
    }
    
    var id: MessageId {
        return self.message.id
    }
    var peerId: PeerId {
        return self.message.id.peerId
    }

    var imageMedia: ImageMediaReference? {
        if let media = self.message.media.first as? TelegramMediaImage {
            return .message(message: MessageReference(message), media: media)
        }
        return nil
    }
    var fileMedia: FileMediaReference? {
        if let media = self.message.media.first as? TelegramMediaFile {
            return .message(message: MessageReference(message), media: media)
        }
        return nil
    }
    
    func makeImageReference(_ image: TelegramMediaImage) -> ImageMediaReference {
        return .message(message: MessageReference(message), media: image)
    }
    func makeFileReference(_ file: TelegramMediaFile) -> FileMediaReference {
        return .message(message: MessageReference(message), media: file)
    }

    
    var hasImmediateData: Bool {
        if let image = message.media.first as? TelegramMediaImage {
            return image.immediateThumbnailData != nil
        } else if let file = message.media.first as? TelegramMediaFile {
            return file.immediateThumbnailData != nil
        }
        return false
    }
}

class PeerPhotosMonthItem: GeneralRowItem {
    let items:[Message]
    fileprivate let context: AccountContext
    private var contentHeight: CGFloat = 0
    
    fileprivate private(set) var layoutItems:[MediaCellLayoutItem] = []
    fileprivate private(set) var itemSize: NSSize = NSZeroSize
    fileprivate let chatInteraction: ChatInteraction
    fileprivate let galleryType: GalleryAppearType
    fileprivate let gallery: (Message, GalleryAppearType)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, viewType: GeneralViewType, context: AccountContext, chatInteraction: ChatInteraction, items: [Message], galleryType: GalleryAppearType, gallery: @escaping(Message, GalleryAppearType)->Void) {
        self.items = items
        self.context = context
        self.chatInteraction = chatInteraction
        self.galleryType = galleryType
        self.gallery = gallery
        super.init(initialSize, stableId: stableId, viewType: viewType, inset: NSEdgeInsets())
    }
    
    override var canBeAnchor: Bool {
        return true
    }
    
    static func rowCount(blockWidth: CGFloat, viewType: GeneralViewType) -> (Int, CGFloat) {
        var rowCount:Int = 4
        var perWidth: CGFloat = 0
        while true {
            let maximum = blockWidth - viewType.innerInset.left - viewType.innerInset.right - CGFloat(rowCount * 2)
            perWidth = maximum / CGFloat(rowCount)
            if perWidth >= 90 {
                break
            } else {
                rowCount -= 1
            }
        }
        return (rowCount, perWidth)
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
        
        let (rowCount, perWidth) = PeerPhotosMonthItem.rowCount(blockWidth: self.blockWidth, viewType: self.viewType)
        
        assert(rowCount >= 1)
                
        let itemSize = NSMakeSize(ceil(perWidth) + 2, ceil(perWidth) + 2)
        
        layoutItems.removeAll()
        var point: CGPoint = CGPoint(x: self.viewType.innerInset.left, y: self.viewType.innerInset.top + itemSize.height)
        for (i, message) in self.items.enumerated() {
            let viewType: MediaCell.Type
            if let file = message.anyMedia as? TelegramMediaFile {
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
            
            if self.viewType.position != .first && self.viewType.position != .inner {
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
            }
            let corners = ImageCorners(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
            self.layoutItems.append(MediaCellLayoutItem(message: message, frame: CGRect(origin: point.offsetBy(dx: 0, dy: -itemSize.height), size: itemSize), viewType: viewType, corners: corners, context: context))
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
        return self.contentHeight + self.viewType.innerInset.top + self.viewType.innerInset.bottom + 1
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
            if canForwardMessage(message, chatInteraction: chatInteraction) {
                items.append(ContextMenuItem(strings().messageContextForward, handler: { [weak self] in
                    self?.chatInteraction.forwardMessages([message])
                }, itemImage: MenuAnimation.menu_forward.value))
            }
            
            items.append(ContextMenuItem(strings().messageContextGoto, handler: { [weak self] in
                self?.chatInteraction.focusMessageId(nil, .init(messageId: message.id, string: nil), .center(id: 0, innerId: nil, animated: false, focus: .init(focus: true), inset: 0))
            }, itemImage: MenuAnimation.menu_show_message.value))
            
            if canDeleteMessage(message, account: context.account, chatLocation: self.chatInteraction.chatLocation, mode: .history) {
                items.append(ContextSeparatorItem())
                items.append(ContextMenuItem(strings().messageContextDelete, handler: { [weak self] in
                   self?.chatInteraction.deleteMessages([message.id])
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            }
        }
        return .single(items)
    }
}

private final class StoryViewsView: ShadowView {
    private static let icon = NSImage(named: "Icon_ChannelViews")!.precomposed(.white)
    
    private let imageView = ImageView()
    private let textView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        addSubview(textView)
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        self.isEventLess = true
        self.imageView.isEventLess = true
        self.textView.isEventLess = true
        
        self.direction = .vertical(true)
        self.shadowBackground = NSColor.black.withAlphaComponent(0.25)
    }
    
    func update(_ seenCount: Int, animated: Bool) {
        let layout = TextViewLayout.init(.initialize(string: seenCount.prettyNumber, color: .white, font: .normal(.small)))
        layout.measure(width: .greatestFiniteMagnitude)
        self.textView.update(layout)
        
        self.imageView.image = StoryViewsView.icon
        self.imageView.sizeToFit()
        
    }
    
    override func layout() {
        super.layout()
        self.imageView.centerY(x: 10)
        self.textView.centerY(x: self.imageView.frame.maxX + 5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class StoryPrivacyView: ShadowView {
    private static let icon = NSImage(resource: .iconChannelViews).precomposed(.white)
    
    private let imageView = ImageView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
        
        self.isEventLess = true
        self.imageView.isEventLess = true
        
        self.direction = .vertical(false)
        self.shadowBackground = NSColor.black.withAlphaComponent(0.25)
    }
    
    func update(_ privacy: EngineStoryPrivacy, isPinned: Bool, animated: Bool) {
        
        if isPinned {
            self.imageView.image = story_pinned
        } else {
            switch privacy.base {
            case .closeFriends:
                self.imageView.image = story_privacy_close_friends
            case .everyone:
                self.imageView.image = nil
            case .contacts:
                self.imageView.image = story_privacy_contacts
            case .nobody:
                self.imageView.image = story_privacy_some_users
            }
        }
      
        self.imageView.sizeToFit()
        
    }
    
    override func layout() {
        super.layout()
        self.imageView.centerY(x: frame.width - imageView.frame.width - 5)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class StoryHeaderView: View {
    private let avatar = AvatarControl(font: .avatar(5))
    private let nameView = TextView()
    private let shadowView = ShadowView(frame: .zero)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(shadowView)
        shadowView.direction = .vertical(false)
        shadowView.shadowBackground = NSColor.black.withAlphaComponent(0.6)
        addSubview(self.avatar)
        addSubview(self.nameView)
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        
        self.avatar.userInteractionEnabled = false
        
        self.avatar.setFrameSize(NSMakeSize(15, 15))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func set(_ peer: EnginePeer, context: AccountContext) {
        self.avatar.setPeer(account: context.account, peer: peer._asPeer())
        
        let layout = TextViewLayout(.initialize(string: peer._asPeer().displayTitle, color: NSColor.white, font: .medium(.small)), maximumNumberOfLines: 1)
        layout.measure(width: frame.width - (10 + 15 + 5))
        
        self.nameView.update(layout)
    }
    
    override func layout() {
        super.layout()
        shadowView.frame = bounds
        self.avatar.centerY(x: 5)
        self.nameView.centerY(x: avatar.frame.maxX + 5)
    }
}


class MediaCell : Control {
    
    private var selectionView:SelectingControl?
    
    var selecting: Bool? {
        return selectionView?.isSelected
    }
    
    fileprivate let imageView: TransformImageView
    private(set) var layoutItem: MediaCellLayoutable?
    fileprivate var context: AccountContext?
    
    private var unsupported: TextView?
    
    private var inkView: MediaInkView?
    

    required init(frame frameRect: NSRect) {
        imageView = TransformImageView(frame: NSMakeRect(0, 0, frameRect.width, frameRect.height))
        super.init(frame: frameRect)
        addSubview(imageView)
        userInteractionEnabled = false
    }
    private var storyViews: StoryViewsView?
    private var storyPrivacy: StoryPrivacyView?
    
    
    private var storyHeaderView: StoryHeaderView?

    override func mouseMoved(with event: NSEvent) {
        superview?.superview?.mouseMoved(with: event)
    }
    override func mouseEntered(with event: NSEvent) {
        superview?.superview?.mouseEntered(with: event)
    }
    override func mouseExited(with event: NSEvent) {
        superview?.superview?.mouseExited(with: event)
    }
    func update(layout: MediaCellLayoutable, selected: Bool?, context: AccountContext, table: TableView?, animated: Bool) {
        let previousLayout = self.layoutItem
        self.layoutItem = layout
        self.context = context
        let isUpdated = previousLayout == nil || !previousLayout!.isEqual(to: layout)
        if isUpdated, !(self is MediaGifCell) {
            let media: Media
            let imageSize: NSSize
            let cacheArguments: TransformImageArguments
            let signal: Signal<ImageDataTransformation, NoError>
            
            if let imageMedia = layout.imageMedia, let largestSize = largestImageRepresentation(imageMedia.media.representations)?.dimensions.size {
                media = imageMedia.media
                imageSize = largestSize.aspectFilled(layout.frame.size)
                cacheArguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: layout.frame.size, intrinsicInsets: NSEdgeInsets())
                
                if layout.isSecret {
                    signal = chatSecretPhoto(account: context.account, imageReference: imageMedia, scale: backingScaleFactor, synchronousLoad: false)
                } else {
                    signal = mediaGridMessagePhoto(account: context.account, imageReference: imageMedia, scale: backingScaleFactor)
                }

            } else if let fileMedia = layout.fileMedia  {
                media = fileMedia.media
                let largestSize = fileMedia.media.previewRepresentations.last?.dimensions.size ?? fileMedia.media.imageSize
                imageSize = largestSize.aspectFilled(layout.frame.size)
                cacheArguments = TransformImageArguments(corners: layout.corners, imageSize: imageSize, boundingSize: layout.frame.size, intrinsicInsets: NSEdgeInsets())
                if layout.isSecret {
                    signal = chatSecretMessageVideo(account: context.account, fileReference: fileMedia, scale: backingScaleFactor)
                } else {
                    signal = chatMessageVideo(account: context.account, fileReference: fileMedia, scale: backingScaleFactor)
                }
            } else {
                
                let current: TextView
                if let view = self.unsupported {
                    current = view
                } else {
                    current = TextView()
                    self.unsupported = current
                    current.userInteractionEnabled = false
                    current.isSelectable = false
                    addSubview(current)
                }
                let text = TextViewLayout(.initialize(string: strings().mediaCellUnsupported, color: theme.colors.listGrayText, font: .italic(.short)))
                text.measure(width: layout.frame.width - 10)
                current.update(text)
                
                self.imageView.clear()
                needsLayout = true
                return
            }
            
            if let unsupported = self.unsupported {
                performSubviewRemoval(unsupported, animated: animated)
                self.unsupported = nil
            }
            
            self.imageView.setSignal(signal: cachedMedia(media: media, arguments: cacheArguments, scale: backingScaleFactor), clearInstantly: previousLayout?.id != layout.id)
            
           
            if !self.imageView.isFullyLoaded {
                self.imageView.setSignal(signal, animate: animated, cacheImage: { result in
                    cacheMedia(result, media: media, arguments: cacheArguments, scale: System.backingScale)
                })
            }
            self.imageView.set(arguments: cacheArguments)
        }
        if layout.isSpoiler {
            let current: MediaInkView
            if let view = self.inkView {
                current = view
            } else {
                current = MediaInkView(frame: layout.frame.size.bounds)
                current.userInteractionEnabled = false
                self.inkView = current
                
                self.addSubview(current)
            }
            
            let image: TelegramMediaImage
            if let current = layout.imageMedia {
                image = current.media
            } else if let current = layout.fileMedia {
                image = TelegramMediaImage(imageId: current.media.fileId, representations: current.media.previewRepresentations, immediateThumbnailData: current.media.immediateThumbnailData, reference: nil, partialReference: nil, flags: TelegramMediaImageFlags())
            } else {
                fatalError()
            }
            let imageReference = layout.makeImageReference(image)
            current.update(isRevealed: false, updated: isUpdated, context: layout.context, imageReference: imageReference, size: layout.frame.size, positionFlags: nil, synchronousLoad: false, isSensitive: layout.isSensitive, payAmount: nil)
            current.frame = layout.frame.size.bounds
        } else {
            if let view = self.inkView {
                view.userInteractionEnabled = false
                performSubviewRemoval(view, animated: animated)
                self.inkView = nil
            }
        }
        
        if let layout = layout as? StoryCellLayoutItem, let itemPeer = layout.item.peer {
            let current: StoryHeaderView
            if let view = self.storyHeaderView {
                current = view
            } else {
                current = StoryHeaderView(frame: NSMakeRect(0, 0, frame.width, 25))
                addSubview(current)
                self.storyHeaderView = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.set(itemPeer, context: layout.context)
        } else if let view = self.storyHeaderView {
            performSubviewRemoval(view, animated: animated)
            self.storyHeaderView = nil
        }
        
        if let layout = layout as? StoryCellLayoutItem, let seenCount = layout.item.storyItem.views?.seenCount {
            let current: StoryViewsView
            if let view = self.storyViews {
                current = view
            } else {
                current = StoryViewsView(frame: NSMakeRect(0, 0, frame.width, 20))
                addSubview(current)
                self.storyViews = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(seenCount, animated: animated)
        } else if let view = self.storyViews {
            performSubviewRemoval(view, animated: animated)
            self.storyViews = nil
        }
        
        
        if let layout = layout as? StoryCellLayoutItem, let privacy = layout.item.storyItem.privacy, context.peerId == layout.peerId, selected == nil {
            let current: StoryPrivacyView
            if let view = self.storyPrivacy {
                current = view
            } else {
                current = StoryPrivacyView(frame: NSMakeRect(0, 0, frame.width, 20))
                addSubview(current)
                self.storyPrivacy = current
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            current.update(privacy, isPinned: layout.isPinned, animated: animated)
        } else if let view = self.storyPrivacy {
            performSubviewRemoval(view, animated: animated)
            self.storyPrivacy = nil
        }
        
        
        updateSelectionState(animated: animated, selected: selected)
    }
    
    override func copy() -> Any {
        return imageView.copy()
    }
    
    func innerAction() -> MediaCellInvokeActionResult {
        return .gallery
    }
    
    func addAccesoryOnCopiedView(view: NSView) {
        
    }
    
    func updateMouse(_ inside: Bool) {
        
    }
    
    func updateSelectionState(animated: Bool, selected: Bool?) {
        if let selected = selected {
            if let selectionView = self.selectionView {
                selectionView.set(selected: selected, animated: animated)
            } else {
                selectionView = SelectingControl(unselectedImage: theme.icons.chatGroupToggleUnselected, selectedImage: theme.icons.chatGroupToggleSelected)
                addSubview(selectionView!)
                selectionView?.set(selected: selected, animated: animated)
                if animated {
                    selectionView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    selectionView?.layer?.animateScaleSpring(from: 0.1, to: 1.0, duration: 0.2)
                }
            }
        } else {
            if let selectionView = selectionView {
                self.selectionView = nil
                if animated {
                    selectionView.layer?.animateScaleSpring(from: 1.0, to: 0.1, duration: 0.2)
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
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        imageView.frame = NSMakeRect(0, 0, frame.width - 1, frame.height)
        if let selectionView = selectionView {
            selectionView.setFrameOrigin(frame.width - selectionView.frame.width - 5, 5)
        }
        inkView?.frame = imageView.frame
        self.unsupported?.resize(frame.width - 10)
        self.unsupported?.center()
        
        if let storyViews = storyViews {
            storyViews.frame = NSMakeRect(0, frame.height - storyViews.frame.height, frame.width, storyViews.frame.height)
        }
    }
}

final class MediaPhotoCell : MediaCell {
    
}

enum MediaCellInvokeActionResult {
    case nothing
    case gallery
}



class MediaVideoCell : MediaCell {
    
    
    private let mediaPlayerStatusDisposable = MetaDisposable()
    
    private let videoAccessory: ChatMessageAccessoryView = ChatMessageAccessoryView(frame: NSZeroRect)
    private var status:MediaResourceStatus?
    private var authenticStatus: MediaResourceStatus?
    private let statusDisposable = MetaDisposable()
    private let fetchingDisposable = MetaDisposable()
    private let partDisposable = MetaDisposable()
        
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(self.videoAccessory)
    }
    
    override func updateMouse(_ inside: Bool) {
           
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func fetch() {
        if let context = context, let layoutItem = self.layoutItem, let file = layoutItem.fileMedia {
            fetchingDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .peer(layoutItem.peerId), userContentType: .other, reference: file.resourceReference(file.media.resource)).start())
        }
    }
      
    private func cancelFetching() {
        if let context = context, let layoutItem = self.layoutItem, let fileMedia = layoutItem.fileMedia {
            cancelFreeMediaFileInteractiveFetch(context: context, resource: fileMedia.media.resource)
        }
    }
      
    override func innerAction() -> MediaCellInvokeActionResult {
        if let file = layoutItem?.fileMedia?.media as? TelegramMediaFile, let window = self.window {
            return .gallery
        }
        return .nothing
    }
    
    func preloadStreamblePart() {
        if let layoutItem = self.layoutItem, !isLite(.any) {
            let context = layoutItem.context
            if context.autoplayMedia.preloadVideos {
                if let fileMedia = layoutItem.fileMedia {
                    
                    if isHLSVideo(file: fileMedia.media) {
                        let fetchSignal = HLSVideoContent.minimizedHLSQualityPreloadData(postbox: context.account.postbox, file: fileMedia, userLocation: .peer(layoutItem.peerId), prefixSeconds: 10, autofetchPlaylist: true, initialQuality: FastSettings.videoQuality)
                        |> mapToSignal { fileAndRange -> Signal<Never, NoError> in
                            guard let fileAndRange else {
                                return .complete()
                            }
                            return freeMediaFileResourceInteractiveFetched(postbox: context.account.postbox, userLocation: .peer(layoutItem.peerId), fileReference: fileAndRange.0, resource: fileAndRange.0.media.resource, range: (fileAndRange.1, .default))
                            |> ignoreValues
                            |> `catch` { _ -> Signal<Never, NoError> in
                                return .complete()
                            }
                        }
                        partDisposable.set(fetchSignal.start())
                    } else {
                        let preload = preloadVideoResource(postbox: context.account.postbox, userLocation: .peer(layoutItem.peerId), userContentType: .init(file: fileMedia.media), resourceReference: fileMedia.resourceReference(fileMedia.media.resource), duration: 2.5)
                        partDisposable.set(preload.start())
                    }
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
            text = String.durationTransformed(elapsed: Int(file.videoDuration))
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
    
    override func update(layout: MediaCellLayoutable, selected: Bool?, context: AccountContext, table: TableView?, animated: Bool) {
        super.update(layout: layout, selected: selected, context: context, table: table, animated: animated)
        let fileMedia = layout.fileMedia!
        
        let updatedStatusSignal = context.account.postbox.mediaBox.resourceStatus(fileMedia.media.resource) |> deliverOnMainQueue |> map { status -> (MediaResourceStatus, MediaResourceStatus) in
            if fileMedia.media.isStreamable && layout.id.peerId.namespace != Namespaces.Peer.SecretChat {
               return (.Local, status)
           }
           return (status, status)
       }  |> deliverOnMainQueue
       
       var first: Bool = true
       
       statusDisposable.set(updatedStatusSignal.start(next: { [weak self] status, authentic in
           guard let `self` = self else {return}
           
           self.updateVideoAccessory(authentic, mediaPlayerStatus: nil, file: fileMedia.media, animated: !first)
            first = false
            self.status = status
            self.authenticStatus = authentic
        }))
        partDisposable.set(nil)
    }
    
    override func addAccesoryOnCopiedView(view: NSView) {
        let videoAccessory = self.videoAccessory.copy() as! ChatMessageAccessoryView
        if visibleRect.minY < videoAccessory.frame.midY && visibleRect.minY + visibleRect.height > videoAccessory.frame.midY {
             videoAccessory.frame.origin.y = frame.height - videoAccessory.frame.maxY
             view.addSubview(videoAccessory)
         }

    }
    
    override func layout() {
        super.layout()
        videoAccessory.setFrameOrigin(5, 5)
    }
    
    deinit {
        statusDisposable.dispose()
        fetchingDisposable.dispose()
        partDisposable.dispose()
        mediaPlayerStatusDisposable.dispose()
    }
}



class MediaGifCell : MediaCell {
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
    
    override func innerAction() -> MediaCellInvokeActionResult {
        return .gallery
    }
    

    override func copy() -> Any {
        return gifView.copy()
    }
    
    override func update(layout: MediaCellLayoutable, selected: Bool?, context: AccountContext, table: TableView?, animated: Bool) {
        let previousLayout = self.layoutItem
        let isUpdated = previousLayout == nil || !previousLayout!.isEqual(to: layout)
        super.update(layout: layout, selected: selected, context: context, table: table, animated: animated)
        if isUpdated, let fileMedia = layout.fileMedia {
            let signal = chatMessageVideo(account: context.account, fileReference: fileMedia, scale: backingScaleFactor)
            gifView.update(with: fileMedia, size: frame.size, viewSize: frame.size, context: context, table: nil, iconSignal: signal)
            gifView.userInteractionEnabled = false
        }
    }
    
    
    override func layout() {
        super.layout()
        gifView.frame = NSMakeRect(0, 0, frame.width - 1, frame.height)
        
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
    
    @objc func _updateMouse() {
        super.updateMouse(animated: true)
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
        _updateMouse()
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        _updateMouse()
    }
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        _updateMouse()
    }
    
    private func action(event: ControlEvent) {
        guard let item = self.item as? PeerPhotosMonthItem, let window = window else {
            return
        }
        let point = containerView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if let layoutItem = item.layoutItems.first(where: { NSPointInRect(point, $0.frame) }) {
            if item.chatInteraction.presentation.state == .selecting {
                switch event {
                case .MouseDragging:
                    item.chatInteraction.update { current in
                        if !haveToSelectOnDrag {
                            return current.withRemovedSelectedMessage(layoutItem.message.id)
                        } else {
                            return current.withUpdatedSelectedMessage(layoutItem.message.id)
                        }
                    }
                case .Down:
                    item.chatInteraction.update { $0.withToggledSelectedMessage(layoutItem.message.id) }
                    haveToSelectOnDrag = item.chatInteraction.presentation.isSelectedMessageId(layoutItem.message.id)
                default:
                    break
                }
            } else {
                switch event {
                case .Click:
                    let view = self.contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.isEqual(to: layoutItem) == true })
                    if let view = view {
                        switch view.innerAction() {
                        case .gallery:
                            item.gallery(layoutItem.message, item.galleryType)
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
                    if (value.state == .selecting) != (oldValue.state == .selecting) || value.isSelectedMessageId(item.id) != oldValue.isSelectedMessageId(item.id) {
                        view.updateSelectionState(animated: animated, selected: value.state == .selecting ? value.isSelectedMessageId(item.id) : nil)
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
        
    }
    
    private var previousRange: (Int, Int) = (0, 0)
    private var isCleaned: Bool = false
    
    private func layoutVisibleItems(animated: Bool) {
        guard let item = item as? PeerPhotosMonthItem else {
            return
        }
                
        CATransaction.begin()
        let presentation = item.chatInteraction.presentation
        for (i, layout) in item.layoutItems.enumerated() {
            var view: MediaCell
            if self.contentViews[i] == nil || !self.contentViews[i]!.isKind(of: layout.viewType) {
                view = layout.viewType.init(frame: layout.frame)
                self.contentViews[i] = view
            } else {
                view = self.contentViews[i]!
            }
            view.update(layout: layout, selected: presentation.state == .selecting ? presentation.isSelectedMessageId(layout.message.id) : nil, context: item.context, table: item.table, animated: animated)

            view.frame = layout.frame
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
            NotificationCenter.default.addObserver(self, selector: #selector(_updateMouse), name: NSWindow.didBecomeKeyNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(_updateMouse), name: NSWindow.didResignKeyNotification, object: nil)
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
            let view = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.id == innerId })
            return view ?? NSView()
        }
        return self
    }
    
    override func addAccesoryOnCopiedView(innerId: AnyHashable, view: NSView) {
        if let innerId = innerId.base as? MessageId {
            let cell = contentViews.compactMap { $0 }.first(where: { $0.layoutItem?.id == innerId })
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

