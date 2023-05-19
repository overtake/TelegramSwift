//
//  MGalleryItem.swift
//  TelegramMac
//
//  Created by keepcoder on 15/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore

import SwiftSignalKit
import TGUIKit

final class GPreviewValueClass {
    let value: GPreviewValue
    init(_ value: GPreviewValue) {
        self.value = value
    }
}


enum GPreviewValue {
    case image(NSImage?, ImageOrientation?)
    case view(NSView?)
    
    var hasValue: Bool {
        switch self {
        case let .image(img, _):
            return img != nil
        case let .view(view):
            return view != nil
        }
    }
    var size: NSSize? {
        switch self {
        case let .image(img, _):
            return img?.size
        case let .view(view):
            return view?.frame.size
        }
    }
    
    var rotation: ImageOrientation? {
        switch self {
        case let .image(_, rotation):
            return rotation
        case .view:
            return nil
        }
    }
    
    var image: NSImage? {
        switch self {
        case let .image(img, _):
            return img
        case .view:
            return nil
        }
    }
    
}

func <(lhs: GalleryEntry, rhs: GalleryEntry) -> Bool {
    switch lhs {
    case .message(let lhsEntry):
        if case let .message(rhsEntry) = rhs {
            return lhsEntry < rhsEntry
        } else {
            return false
        }
    case let .secureIdDocument(_, lhsIndex):
        if case let .secureIdDocument(_, rhsIndex) = rhs {
            return lhsIndex < rhsIndex
        } else {
            return false
        }
    case let .photo(lhsIndex, _, _, _, _, _, _):
        if  case let .photo(rhsIndex, _, _, _, _, _, _) = rhs {
            return lhsIndex < rhsIndex
        } else {
            return false
        }
    case let  .instantMedia(lhsMedia, _):
        if case let .instantMedia(rhsMedia, _) = rhs {
            return lhsMedia.index < rhsMedia.index
        } else {
            return false
        }
    }
}

func ==(lhs: GalleryEntry, rhs: GalleryEntry) -> Bool {
    switch lhs {
    case .message(let lhsEntry):
        if case let .message(rhsEntry) = rhs {
            return lhsEntry.stableId == rhsEntry.stableId
        } else {
            return false
        }
    case let .secureIdDocument(lhsEntry, lhsIndex):
        if case let .secureIdDocument(rhsEntry, rhsIndex) = rhs {
            return lhsEntry.document.isEqual(to: rhsEntry.document) && lhsIndex == rhsIndex
        } else {
            return false
        }
    case let .photo(lhsIndex, lhsStableId, lhsPhoto, lhsReference, lhsPeer, _, lhsDate):
        if  case let .photo(rhsIndex, rhsStableId, rhsPhoto, rhsReference, rhsPeer, _, rhsDate) = rhs {
            return lhsIndex == rhsIndex && lhsStableId == rhsStableId && lhsPhoto.isEqual(to: rhsPhoto) && lhsReference == rhsReference && lhsPeer.isEqual(rhsPeer) && lhsDate == rhsDate
        } else {
            return false
        }
    case let  .instantMedia(lhsMedia, _):
        if case let .instantMedia(rhsMedia, _) = rhs {
            return lhsMedia == rhsMedia
        } else {
            return false
        }
    }
}
enum GalleryEntry : Comparable, Identifiable {
    case message(ChatHistoryEntry)
    case photo(index:Int, stableId:AnyHashable, photo:TelegramMediaImage, reference: TelegramMediaImageReference?, peer: Peer, message: Message?, date: TimeInterval)
    case instantMedia(InstantPageMedia, Message?)
    case secureIdDocument(SecureIdDocumentValue, Int)
    var stableId: AnyHashable {
        switch self {
        case let .message(entry):
            return entry.stableId
        case let .photo(_, stableId, _, _, _, _, _):
            return stableId
        case let .instantMedia(media, _):
            return media.index
        case let .secureIdDocument(document, _):
            return document.stableId
        }
    }
    
    var canShare: Bool {
        return message != nil && !message!.isScheduledMessage && !message!.containsSecretMedia && !message!.isCopyProtected()
    }
    
    var interfaceState:(PeerId, TimeInterval)? {
        switch self {
        case let .message(entry):
            if let peerId = entry.message!.effectiveAuthor?.id {
                return (peerId, TimeInterval(entry.message!.timestamp))
            }
        case let .instantMedia(_, message):
            if let message = message, let peerId = message.effectiveAuthor?.id {
                return (peerId, TimeInterval(message.timestamp))
            }
        case let .photo(_, _, _, _, peer, _, date):
            return (peer.id, date)
        default:
            return nil
        }
        return nil
    }
    
    var file:TelegramMediaFile? {
        switch self {
        case .message(let entry):
            if let media = entry.message!.effectiveMedia as? TelegramMediaFile {
                return media
            } else if let media = entry.message!.media[0] as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    return content.file
                default:
                    return nil
                }
            }
        case .instantMedia(let media, _):
            return media.media as? TelegramMediaFile
        default:
            return nil
        }
        
        return nil
    }
    
    var webpage: TelegramMediaWebpage? {
        switch self {
        case let .message(entry):
            return entry.message!.media[0] as? TelegramMediaWebpage
        case let .instantMedia(media, _):
            return media.media as? TelegramMediaWebpage
        default:
            return nil
        }
    }
    
    func imageReference( _ image: TelegramMediaImage) -> ImageMediaReference {
        switch self {
        case let .message(entry):
            return ImageMediaReference.message(message: MessageReference(entry.message!), media: image)
        case let .instantMedia(media, _):
            return ImageMediaReference.webPage(webPage: WebpageReference(media.webpage), media: image)
        case  .secureIdDocument:
            return ImageMediaReference.standalone(media: image)
        case .photo:
            return ImageMediaReference.standalone(media: image)
        }
    }
    
    var peer: Peer? {
        switch self {
        case let .photo(_, _, _, _, peer, _, _):
            return peer
        default:
            return nil
        }
    }
    
    func peerPhotoResource() -> MediaResourceReference {
        switch self {
        case let .photo(_, _, image, _, peer, message, _):
            if let representation = image.representationForDisplayAtSize(PixelDimensions(1280, 1280)) {
                if let message = message {
                    return .media(media: .message(message: MessageReference(message), media: image), resource: representation.resource)
                }
                if let peerReference = PeerReference(peer) {
                    return .avatar(peer: peerReference, resource: representation.resource)
                } else {
                    return .standalone(resource: representation.resource)
                }
            } else {
                 preconditionFailure()
            }
        default:
            preconditionFailure()
        }
    }
    
    func fileReference( _ file: TelegramMediaFile) -> FileMediaReference {
        switch self {
        case let .message(entry):
            return FileMediaReference.message(message: MessageReference(entry.message!), media: file)
        case let .instantMedia(media, _):
            return FileMediaReference.webPage(webPage: WebpageReference(media.webpage), media: file)
        case .secureIdDocument:
            return FileMediaReference.standalone(media: file)
        case .photo:
            return FileMediaReference.standalone(media: file)
        }
    }
    
    
    var identifier: String {
        switch self {
        case let .message(entry):
            return "\(entry.message?.stableId ?? 0)"
        case .photo(_, let stableId, _, _, _, _, _):
            return "\(stableId)"
        case .instantMedia:
            return "\(stableId)"
        case let .secureIdDocument(document, _):
            return "secureId: \(document.document.id.hashValue)"
        }
    }
    
    var chatEntry: ChatHistoryEntry? {
        switch self {
        case let .message(entry):
            return entry
        default:
            return nil
        }
    }
    
    var message:Message? {
        switch self {
        case let .message(entry):
            return entry.message
        case let .instantMedia(_, message):
            return message
        default:
            return nil
        }
    }
    var photo:TelegramMediaImage? {
        switch self {
        case .message:
            return nil
        case let .photo(_, _, photo, _, _, _, _):
            return photo
        default:
            return nil
        }
    }
    
    var photoReference:TelegramMediaImageReference? {
        switch self {
        case .message:
            return nil
        case let .photo(_, _, _, reference, _, _, _):
            return reference
        default:
            return nil
        }
    }
}

func ==(lhs: MGalleryItem, rhs: MGalleryItem) -> Bool {
    return lhs.entry == rhs.entry
}
func <(lhs: MGalleryItem, rhs: MGalleryItem) -> Bool {
    return lhs.entry < rhs.entry
}

private final class MGalleryItemView : NSView {
    init() {
        super.init(frame: NSZeroRect)
        self.wantsLayer = true
        self.layerContentsRedrawPolicy = .never
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var isOpaque: Bool {
        return true
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

class MGalleryItem: NSObject, Comparable, Identifiable {
    let image:Promise<GPreviewValueClass> = Promise()
    let view:Promise<NSView> = Promise()
    let size:Promise<NSSize> = Promise()
    let magnify:Promise<CGFloat> = Promise(1)
    let rotate: ValuePromise<ImageOrientation?> = ValuePromise(nil, ignoreRepeated: true)
    
    private let appearSignal = ValuePromise(false, ignoreRepeated: true)
    var appearValue:Signal<Bool, NoError> {
        return appearSignal.get()
    }
    
    let disposable:MetaDisposable = MetaDisposable()
    let fetching:MetaDisposable = MetaDisposable()
    private let magnifyDisposable = MetaDisposable()
    private let viewDisposable:MetaDisposable = MetaDisposable()
    let path:Promise<String> = Promise()
    let entry:GalleryEntry
    let context: AccountContext
    private var _pagerSize: NSSize
    private var captionSeized: Bool = false
    var pagerSize:NSSize {
        var pagerSize = _pagerSize
        if let caption = caption, !captionSeized  {
            caption.measure(width: pagerSize.width - 300)
            captionSeized = true
        }
        if let caption = caption {
            pagerSize.height -= min(200, (caption.layoutSize.height + 120))
        }
        return pagerSize
    }
    let caption: TextViewLayout?
    
    var disableAnimations: Bool = false
    
    var modifiedSize: NSSize? = nil
    
    private(set) var magnifyValue:CGFloat = 1.0
    var stableId: AnyHashable {
        return entry.stableId
    }
    
    var identifier:NSPageController.ObjectIdentifier {
        return entry.identifier + self.className
    }
    
    var sizeValue:NSSize {
        return pagerSize
    }
    
    var minMagnify:CGFloat {
        return 0.25
    }
    
    var maxMagnify:CGFloat {
        return 8.0
    }
    
    func smallestValue(for size: NSSize) -> NSSize {
        return pagerSize
    }
    
    var status:Signal<MediaResourceStatus, NoError> {
        return .single(.Local)
    }
    
    var realStatus:Signal<MediaResourceStatus, NoError> {
       return self.status
    }
    
    func toggleFullScreen() {
        
    }
    func togglePlayerOrPause() {
        
    }
    func rewindBack() {
        
    }
    func rewindForward() {
        
    }
    
    init(_ context: AccountContext, _ entry:GalleryEntry, _ pagerSize:NSSize) {
        self.entry = entry
        self.context = context
        self._pagerSize = pagerSize
        if let message = entry.message, !message.text.isEmpty, !(message.effectiveMedia is TelegramMediaWebpage) {
            let caption = message.text
            let attr = NSMutableAttributedString()
            _ = attr.append(string: caption.trimmed.fullTrimmed, color: .white, font: .normal(.text))
            let controller = context.bindings.rootNavigation().controller as? ChatController

            if let peer = message.peers[message.id.peerId] {
                var type: ParsingType = [.Links, .Mentions, .Hashtags]
                if peer.isGroup || peer.isSupergroup, peer.canSendMessage() {
                    if let _ = controller {
                        type.insert(.Commands)
                    }
                }
                attr.detectLinks(type: type, context: context, color: .linkColor, openInfo: { peerId, toChat, postId, action in
                    let navigation = context.bindings.rootNavigation()
                    let controller = navigation.controller
                    if toChat {
                        if peerId == (controller as? ChatController)?.chatInteraction.peerId {
                            if let postId = postId {
                                (controller as? ChatController)?.chatInteraction.focusMessageId(nil, postId, TableScrollState.CenterEmpty)
                            }
                        } else {
                            navigation.push(ChatAdditionController(context: context, chatLocation: .peer(peerId), messageId: postId, initialAction: action))
                        }
                    } else {
                        navigation.push(PeerInfoController(context: context, peerId: peerId))
                    }
                    viewer?.close()
                }, hashtag: { hashtag in
                    context.bindings.globalSearch(hashtag)
                    viewer?.close()
                }, command: { commandText in
                    _ = Sender.enqueue(input: ChatTextInputState(inputText: commandText), context: context, peerId: peer.id, replyId: nil, atDate: nil).start()
                    viewer?.close()
                }, applyProxy: { server in
                    applyExternalProxy(server, accountManager: context.sharedContext.accountManager)
                    viewer?.close()
                })
                
            }
            
           
            
            var spoilers:[TextViewLayout.Spoiler] = []
            for attr in message.attributes {
                if let attr = attr as? TextEntitiesMessageAttribute {
                    for entity in attr.entities {
                        switch entity.type {
                        case .Spoiler:
                            let color: NSColor = NSColor.white
                            spoilers.append(.init(range: NSMakeRange(entity.range.lowerBound, entity.range.upperBound - entity.range.lowerBound), color: color, isRevealed: false))
                        default:
                            break
                        }
                    }
                }
            }
            
            self.caption = TextViewLayout(attr, alignment: .left, spoilers: spoilers)
            self.caption?.interactions = TextViewInteractions(processURL: { link in
                if let link = link as? inAppLink {
                    execute(inapp: link, afterComplete: { value in
                        if value {
                            viewer?.close()
                        }
                    })
                    
                }
            })
        } else {
            self.caption = nil
        }
       
        super.init()
        
        var first:Bool = true
        
        let image = combineLatest(self.image.get() |> map { $0.value }, view.get()) |> map { [weak self] value, view  in
            guard let `self` = self else {return}
            view.layer?.contents = value.image
            
            if !first && !self.disableAnimations {
                view.layer?.animateContents()
            }
            self.disableAnimations = false
            view.layer?.backgroundColor = self.backgroundColor.cgColor

            if let magnify = view.superview?.superview as? MagnifyView {
                var size = magnify.contentSize
                if self is MGalleryPhotoItem || self is MGalleryPeerPhotoItem {
                    if value.rotation == nil {
                        size = value.size?.aspectFitted(size) ?? size
                    } else {
                        size = value.size ?? size
                    }
                }
                magnify.contentSize = size
            }
            first = false
        }
        viewDisposable.set(image.start())
        
        magnifyDisposable.set(magnify.get().start(next: { [weak self] (magnify) in
            self?.magnifyValue = magnify
        }))
    }
    
    var backgroundColor: NSColor {
        return .black
    }
    
    var isGraphicFile: Bool {
        if self.entry.message?.effectiveMedia is TelegramMediaFile {
            return true
        } else {
            return false
        }
    }
    
    func singleView() -> NSView {
        return MGalleryItemView()
    }
    
    func request(immediately:Bool = true) {
     //   self.caption?.measure(width: sizeValue.width)
    }
    
    func fetch() {
        
    }
    
    var notFittedSize: NSSize {
        return sizeValue
    }
    
    func cancel() {
        fetching.set(nil)
    }
    
    func appear(for view:NSView?) {
        appearSignal.set(true)
    }
    
    func disappear(for view:NSView?) {
        appearSignal.set(false)
    }
    
    deinit {
        disposable.dispose()
        viewDisposable.dispose()
        fetching.dispose()
        magnifyDisposable.dispose()
    }
    
}



