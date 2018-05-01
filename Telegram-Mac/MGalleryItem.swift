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
    case let .photo(lhsIndex, _, _, _):
        if  case let .photo(rhsIndex, _, _, _) = rhs {
            return lhsIndex < rhsIndex
        } else {
            return false
        }
    case let  .instantMedia(lhsMedia):
        if case let .instantMedia(rhsMedia) = rhs {
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
    case let .photo(lhsIndex, lhsStableId, lhsPhoto, lhsReference):
        if  case let .photo(rhsIndex, rhsStableId, rhsPhoto, rhsReference) = rhs {
            return lhsIndex == rhsIndex && lhsStableId == rhsStableId && lhsPhoto.isEqual(rhsPhoto) && lhsReference == rhsReference
        } else {
            return false
        }
    case let  .instantMedia(lhsMedia):
        if case let .instantMedia(rhsMedia) = rhs {
            return lhsMedia == rhsMedia
        } else {
            return false
        }
    }
}
enum GalleryEntry : Comparable, Identifiable {
    case message(ChatHistoryEntry)
    case photo(index:Int, stableId:AnyHashable, photo:TelegramMediaImage, reference: TelegramMediaImageReference?)
    case instantMedia(InstantPageMedia)
    case secureIdDocument(SecureIdDocumentValue, Int)
    var stableId: AnyHashable {
        switch self {
        case let .message(entry):
            return entry.stableId
        case let .photo(_, stableId, _, _):
            return stableId
        case let .instantMedia(media):
            return media.index
        case let .secureIdDocument(document, _):
            return document.stableId
        }
    }
    
    
    
    var identifier: String {
        switch self {
        case let .message(entry):
            return "\(entry.message?.stableId ?? 0)"
        case .photo(_, let stableId, _, _):
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
        default:
            return nil
        }
    }
    var photo:TelegramMediaImage? {
        switch self {
        case .message:
            return nil
        case let .photo(_, _, photo, _):
            return photo
        default:
            return nil
        }
    }
    
    var photoReference:TelegramMediaImageReference? {
        switch self {
        case .message:
            return nil
        case let .photo(_, _, _, reference):
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
    
    let disposable:MetaDisposable = MetaDisposable()
    let fetching:MetaDisposable = MetaDisposable()
    private let magnifyDisposable = MetaDisposable()
    private let viewDisposable:MetaDisposable = MetaDisposable()
    let path:Promise<String> = Promise()
    let entry:GalleryEntry
    let account:Account
    private var _pagerSize: NSSize
    var pagerSize:NSSize {
        return _pagerSize
    }
    let caption: TextViewLayout?
    
    private(set) var modifiedSize: NSSize? = nil
    
    private(set) var magnifyValue:CGFloat = 1.0
    var stableId: AnyHashable {
        return entry.stableId
    }
    
    var identifier:NSPageController.ObjectIdentifier {
        return NSPageController.ObjectIdentifier(rawValue: entry.identifier)
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
    
    func smallestValue(for size: NSSize) -> Signal<NSSize, Void> {
        return .single(pagerSize)
    }
    
    var status:Signal<MediaResourceStatus, Void> {
        return .single(.Local)
    }
    
    init(_ account:Account, _ entry:GalleryEntry, _ pagerSize:NSSize) {
        self.entry = entry
        self.account = account
        self._pagerSize = pagerSize
        if let caption = entry.message?.text, !caption.isEmpty, !(entry.message?.media.first is TelegramMediaWebpage) {
            self.caption = TextViewLayout(.initialize(string: caption, color: .white, font: .normal(.text)), alignment: .center)
            self.caption?.measure(width: pagerSize.width - 200)
        } else {
            self.caption = nil
        }
       
        super.init()
        
        var first:Bool = true
        
        let image = combineLatest(self.image.get(), view.get()) |> map { [weak self] image, view  in
            view.layer?.contents = image
            view.layer?.backgroundColor = theme.colors.transparentBackground.cgColor

            if first, let slf = self, let magnify = view.superview?.superview as? MagnifyView {
                if let size = image?.size, size.width > 150 && size.height > 150 {
                    self?.modifiedSize = size
                    if magnify.contentSize != slf.sizeValue {
                        magnify.contentSize = slf.sizeValue
                    }
                }
            }
            
            if !first {
                view.layer?.animateContents()
            }
            first = false
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
    }
    
}



