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
    case let .photo(lhsIndex, lhsStableId, lhsPhoto, lhsReference, lhsPeerId, lhsDate):
        if  case let .photo(rhsIndex, rhsStableId, rhsPhoto, rhsReference, rhsPeerId, rhsDate) = rhs {
            return lhsIndex == rhsIndex && lhsStableId == rhsStableId && lhsPhoto.isEqual(to: rhsPhoto) && lhsReference == rhsReference && lhsPeerId == rhsPeerId && lhsDate == rhsDate
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
    case photo(index:Int, stableId:AnyHashable, photo:TelegramMediaImage, reference: TelegramMediaImageReference?, peerId: PeerId, date: TimeInterval)
    case instantMedia(InstantPageMedia, Message?)
    case secureIdDocument(SecureIdDocumentValue, Int)
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
        }
    }
    
    var canShare: Bool {
        return message != nil
    }
    
    var interfaceState:(PeerId, TimeInterval)? {
        switch self {
        case let .message(entry):
            if let peerId = entry.message!.chatPeer?.id {
                return (peerId, TimeInterval(entry.message!.timestamp))
            }
        case let .instantMedia(_, message):
            if let message = message, let peerId = message.chatPeer?.id {
                return (peerId, TimeInterval(message.timestamp))
            }
        case let .photo(_, _, _, _, peerId, date):
            return (peerId, date)
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
        default:
            return nil
        }
        
        return nil
    }
    
    var webpage: TelegramMediaWebpage? {
        switch self {
        case let .message(entry):
            return entry.message!.media[0] as! TelegramMediaWebpage
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
        case .photo(_, let stableId, _, _, _, _):
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

class MGalleryItem: NSObject, Comparable, Identifiable {
    let image:Promise<CGImage?> = Promise()
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
    
    func smallestValue(for size: NSSize) -> Signal<NSSize, NoError> {
        return .single(pagerSize)
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
        
        let image = combineLatest(self.image.get(), view.get()) |> map { [weak self] image, view  in
            guard let `self` = self else {return}
            
            view.layer?.contents = image
            if !first && !self.disableAnimations {
                view.layer?.animateContents()
            }
            self.disableAnimations = false
            first = false
            view.layer?.backgroundColor = self is MGalleryPhotoItem ? theme.colors.transparentBackground.cgColor : .black

            if let magnify = view.superview?.superview as? MagnifyView {
                if let size = image?.size, size.width - size.height != self.sizeValue.width - self.sizeValue.height, size.width > 150 && size.height > 150 {
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
    
    func singleView() -> NSView {
        return NSView()
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



