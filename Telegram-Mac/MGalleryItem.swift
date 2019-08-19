//
//  MGalleryItem.swift
//  TelegramMac
//
//  Created by keepcoder on 15/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import TGUIKit
import Lottie


enum GPreviewValue {
    case image(NSImage?)
    case view(NSView?)
    
    var hasValue: Bool {
        switch self {
        case let .image(img):
            return img != nil
        case let .view(view):
            return view != nil
        }
    }
    var size: NSSize? {
        switch self {
        case let .image(img):
            return img?.size
        case let .view(view):
            return view?.frame.size
        }
    }
    
    var image: NSImage? {
        switch self {
        case let .image(img):
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
    case let .photo(lhsIndex, _, _, _, _, _):
        if  case let .photo(rhsIndex, _, _, _, _, _) = rhs {
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
    case .lottie(_, let lhsEntry):
        if case let .lottie(_, rhsEntry) = rhs {
            return lhsEntry < rhsEntry
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
    case let .photo(lhsIndex, lhsStableId, lhsPhoto, lhsReference, lhsPeer, lhsDate):
        if  case let .photo(rhsIndex, rhsStableId, rhsPhoto, rhsReference, rhsPeer, rhsDate) = rhs {
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
    case let .lottie(_, lhsEntry):
        if case .lottie(_, let rhsEntry) = rhs {
            return lhsEntry.stableId == rhsEntry.stableId
        } else {
            return false
        }
    }
}
enum GalleryEntry : Comparable, Identifiable {
    case message(ChatHistoryEntry)
    case photo(index:Int, stableId:AnyHashable, photo:TelegramMediaImage, reference: TelegramMediaImageReference?, peer: Peer, date: TimeInterval)
    case instantMedia(InstantPageMedia, Message?)
    case secureIdDocument(SecureIdDocumentValue, Int)
    case lottie(Animation, ChatHistoryEntry)
    var stableId: AnyHashable {
        switch self {
        case let .message(entry):
            return entry.stableId
        case let .photo(_, stableId, _, _, _, _):
            return stableId
        case let .instantMedia(media, _):
            return media.index
        case let .secureIdDocument(document, _):
            return document.stableId
        case let .lottie(_, entry):
            return entry.stableId
        }
    }
    
    var canShare: Bool {
        return message != nil && !message!.isScheduledMessage
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
        case let .photo(_, _, _, _, peer, date):
            return (peer.id, date)
        default:
            return nil
        }
        return nil
    }
    
    var file:TelegramMediaFile? {
        switch self {
        case .message(let entry):
            if let media = entry.message!.media[0] as? TelegramMediaFile {
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
        case let .lottie(_, entry):
            if let media = entry.message!.media[0] as? TelegramMediaFile {
                return media
            } else if let media = entry.message!.media[0] as? TelegramMediaWebpage {
                switch media.content {
                case let .Loaded(content):
                    return content.file
                default:
                    return nil
                }
            }
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
        case .lottie:
            preconditionFailure()
        }
    }
    
    func peerPhotoResource() -> MediaResourceReference {
        switch self {
        case let .photo(_, _, image, _, peer, _):
            if let representation = image.representationForDisplayAtSize(NSMakeSize(1280, 1280)) {
                if let peerReference = PeerReference(peer) {
                    return MediaResourceReference.avatar(peer: peerReference, resource: representation.resource)
                } else {
                    return MediaResourceReference.standalone(resource: representation.resource)
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
        case .lottie:
            preconditionFailure()
        }
    }
    
    
    var identifier: String {
        switch self {
        case let .message(entry):
            return "\(entry.message?.stableId ?? 0)"
        case .photo(_, let stableId, _, _, _, _):
            return "\(stableId)"
        case .instantMedia:
            return "\(stableId)"
        case let .secureIdDocument(document, _):
            return "secureId: \(document.document.id.hashValue)"
        case let .lottie(_, entry):
            return "lottie-animation-\(entry.message?.stableId ?? 0)"
        }
    }
    
    var chatEntry: ChatHistoryEntry? {
        switch self {
        case let .message(entry):
            return entry
        case let .lottie(_, entry):
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
        case let .photo(_, _, photo, _, _, _):
            return photo
        default:
            return nil
        }
    }
    
    var photoReference:TelegramMediaImageReference? {
        switch self {
        case .message:
            return nil
        case let .photo(_, _, _, reference, _, _):
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
    let image:Promise<GPreviewValue> = Promise()
    let view:Promise<NSView> = Promise()
    let size:Promise<NSSize> = Promise()
    let magnify:Promise<CGFloat> = Promise()
    let rotate: ValuePromise<ImageOrientation?> = ValuePromise(nil, ignoreRepeated: true)
    
    let disposable:MetaDisposable = MetaDisposable()
    let fetching:MetaDisposable = MetaDisposable()
    private let magnifyDisposable = MetaDisposable()
    private let viewDisposable:MetaDisposable = MetaDisposable()
    let path:Promise<String> = Promise()
    let entry:GalleryEntry
    let context: AccountContext
    private var _pagerSize: NSSize
    var pagerSize:NSSize {
        return _pagerSize
    }
    let caption: TextViewLayout?
    
    var disableAnimations: Bool = false
    
    private(set) var modifiedSize: NSSize? = nil
    
    private(set) var magnifyValue:CGFloat = 1.0
    var stableId: AnyHashable {
        return entry.stableId
    }
    
    var identifier:NSPageController.ObjectIdentifier {
        return entry.identifier
    }
    
    var sizeValue:NSSize {
        return pagerSize
    }
    
    var minMagnify:CGFloat {
        return 1.0
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
        if let caption = entry.message?.text, !caption.isEmpty, !(entry.message?.media.first is TelegramMediaWebpage) {
            let attr = NSMutableAttributedString()
            _ = attr.append(string: caption.prefixWithDots(255), color: .white, font: .normal(.text))
            
//            attr.detectLinks(type: [.Links, .Mentions], account: account, color: .linkColor, openInfo: { peerId, _, _, _ in
//                context.sharedContext.bindings.rootNavigation().push(PeerInfoController.init(account: account, peerId: peerId))
//                viewer?.close()
//            }, hashtag: { _ in }, command: {_ in }, applyProxy: { _ in })
            
            self.caption = TextViewLayout(attr, alignment: .center)
            self.caption?.interactions = globalLinkExecutor

            
            self.caption?.measure(width: pagerSize.width - 200)
        } else {
            self.caption = nil
        }
       
        super.init()
        
        var first:Bool = true
        
        let image = combineLatest(self.image.get(), view.get()) |> map { [weak self] value, view  in
            guard let `self` = self else {return}
            view.layer?.contents = value.image
            
            if !first && !self.disableAnimations {
                view.layer?.animateContents()
            }
            self.disableAnimations = false
            first = false
            view.layer?.backgroundColor = self.backgroundColor.cgColor

            if let magnify = view.superview?.superview as? MagnifyView {
                if let size = value.size, size.width - size.height != self.sizeValue.width - self.sizeValue.height, size.width > 150 && size.height > 150 {
                    self.modifiedSize = size
                    if magnify.contentSize != self.sizeValue {
                        magnify.contentSize = self.sizeValue
                    } else {
                        let size = magnify.contentSize
                        magnify.contentSize = size
                    }
                } else {
                    let size = magnify.contentSize
                    magnify.contentSize = size
                }
            }
            
        }
        viewDisposable.set(image.start())
        
        magnifyDisposable.set(magnify.get().start(next: { [weak self] (magnify) in
            self?.magnifyValue = magnify
        }))
    }
    
    var backgroundColor: NSColor {
        return .black
    }
    
    func singleView() -> NSView {
        return MGalleryItemView()
    }
    
    func request(immediately:Bool = true) {
        
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
        
    }
    
    func disappear(for view:NSView?) {
        
    }
    
    deinit {
        disposable.dispose()
        viewDisposable.dispose()
        fetching.dispose()
        magnifyDisposable.dispose()
        assertOnMainThread()
    }
    
}



