//
//  MediaViewer.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
import TGUIKit
import TelegramCoreMac
import PostboxMac
import AVFoundation
final class GalleryInteractions {
    var dismiss:()->KeyHandlerResult = { return .rejected}
    var next:()->KeyHandlerResult = { return .rejected}
    var select:(MGalleryItem)->Void = { _ in}
    var previous:()->KeyHandlerResult = { return .rejected}
    var showActions:(Control)->KeyHandlerResult = {_ in return .rejected}
    var share:(Control)->Void = { _ in }
    var contextMenu:()->NSMenu? = {return nil}
    var openInfo:(PeerId)->Void = {_ in}
    var openMessage:()->Void = {}
    var showThumbsControl:(View, Bool)->Void = {_, _ in}
    var hideThumbsControl:(View, Bool)->Void = {_, _ in}
    
    var zoomIn:()->Void = {}
    var zoomOut:()->Void = {}
    var rotateLeft:()->Void = {}
    
    var fastSave:()->Void = {}
}
private(set) var viewer:GalleryViewer?

func cacheGalleryView(_ view: NSView, for item: MGalleryItem) {
    viewer?.viewCache[item.stableId] = view
}

func cachedGalleryView(for item: MGalleryItem) -> NSView? {
    return viewer?.viewCache[item.stableId]
}

let galleryButtonStyle = ControlStyle(font:.medium(.huge), foregroundColor:.white, backgroundColor:.clear, highlightColor:.grayIcon)


private func tagsForMessage(_ message: Message) -> MessageTags? {
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            return .photoOrVideo
        case let file as TelegramMediaFile:
            if file.isVideo && !file.isAnimated {
                return .photoOrVideo
            } else if file.isVoice {
                return .voiceOrInstantVideo
            } else if file.isSticker || (file.isVideo && file.isAnimated) {
                return nil
            } else {
                return .file
            }
        default:
            break
        }
    }
    return nil
}


enum GalleryAppearType {
    case alone
    case history
    case profile(PeerId)
    case secret
}

private func mediaForMessage(message: Message) -> Media? {
    for media in message.media {
        if let media = media as? TelegramMediaImage {
            return media
        } else if let file = media as? TelegramMediaFile {
            if file.mimeType.hasPrefix("image/") || file.isVideo || file.isAnimated {
                return file
            }
        } else if let webpage = media as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                if ExternalVideoLoader.isPlayable(content) {
                    return nil
                } else {
                    return content.file ?? content.image
                }
            }
        }
       
    }
    return nil
}

fileprivate func itemFor(entry: ChatHistoryEntry, account: Account, pagerSize: NSSize) -> MGalleryItem {
    switch entry {
    case let .MessageEntry(message, _, _, _, _, _, _, _):
        if let media = mediaForMessage(message: message) {
            if let _ = media as? TelegramMediaImage {
                return MGalleryPhotoItem(account, .message(entry), pagerSize)
            } else if let file = media as? TelegramMediaFile {
                if file.isVideo && !file.isAnimated {
                    return MGalleryVideoItem(account, .message(entry), pagerSize)
                } else {
                    if file.mimeType.hasPrefix("image/") {
                        return MGalleryPhotoItem(account, .message(entry), pagerSize)
                    } else if file.isVideo && file.isAnimated {
                        return MGalleryGIFItem(account, .message(entry), pagerSize)
                    }
                }
            }
        } else if !message.media.isEmpty, let webpage = message.media[0] as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                if ExternalVideoLoader.isPlayable(content) {
                    return MGalleryExternalVideoItem(account, .message(entry), pagerSize)
                }
            }
        }
    default:
        break
    }
    
    return MGalleryItem(account, .message(entry), pagerSize)
}

fileprivate func prepareEntries(from:[ChatHistoryEntry]?, to:[ChatHistoryEntry], account:Account, pagerSize:NSSize) -> Signal<UpdateTransition<MGalleryItem>, NoError> {
    return Signal { subscriber in
        
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> MGalleryItem in
           return itemFor(entry: entry, account: account, pagerSize: pagerSize)
        })
        
        subscriber.putNext(UpdateTransition(deleted: removed, inserted: inserted, updated: updated))
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(Queue.mainQueue())
}



class GalleryBehavior {
    let disposable:MetaDisposable = MetaDisposable()
    let indexDisposable:MetaDisposable = MetaDisposable()
    
    deinit {
        disposable.dispose()
        indexDisposable.dispose()
    }
}

class GalleryMessagesBehavior {
    init(message:Message) {
        
    }
}

final class GalleryBackgroundView : View {
    override func draw(_ layer: CALayer, in ctx: CGContext) {
       // super.draw(layer, in: ctx)
    }
}



private final class GalleryTouchBarController : ViewController {
    
    private let interactions: GalleryInteractions
    private let selectedItemChanged: (@escaping(MGalleryItem) -> Void)->Void
    private let transition: (@escaping(UpdateTransition<MGalleryItem>, MGalleryItem?) -> Void) -> Void
    init(interactions: GalleryInteractions, selectedItemChanged: @escaping(@escaping(MGalleryItem) -> Void) ->Void, transition: @escaping(@escaping(UpdateTransition<MGalleryItem>, MGalleryItem?) -> Void) ->Void) {
        self.interactions = interactions
        self.selectedItemChanged = selectedItemChanged
        self.transition = transition
        super.init()
    }
    private var temporaryTouchBar: Any?
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        if temporaryTouchBar == nil {
            temporaryTouchBar = GalleryTouchBar(interactions: interactions, selectedItemChanged: selectedItemChanged, transition: transition)
        }
        return temporaryTouchBar as? NSTouchBar
    }
}


class GalleryViewer: NSResponder {
    
    fileprivate var viewCache:[AnyHashable: NSView] = [:]
    
    let window:Window
  //  private var controls:GalleryControls!
    private var controls: GalleryModernControls!
    let pager:GalleryPageController
    private let backgroundView: GalleryBackgroundView = GalleryBackgroundView()
    private let ready = Promise<Bool>()
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    private let readyDispose = MetaDisposable()
    private let operationDisposable = MetaDisposable()
    private(set) weak var delegate:InteractionContentViewProtocol?
    private let account:Account
    private let touchbarController: GalleryTouchBarController
    private let indexDisposable:MetaDisposable = MetaDisposable()
    private let messagesActionDisposable = MetaDisposable()
    
    let interactions:GalleryInteractions = GalleryInteractions()
    let contentInteractions:ChatMediaLayoutParameters?
    fileprivate var firstStableId: AnyHashable? = nil
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    let type:GalleryAppearType
    private let reversed: Bool
    private init(account:Account, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType, reversed:Bool = false) {
        self.account = account
        self.delegate = delegate
        self.type = type
        self.reversed = reversed
        self.contentInteractions = contentInteractions
        if let screen = NSScreen.main {
            let bounds = NSMakeRect(0, 0, screen.frame.width, screen.frame.height)
            self.window = Window(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            self.window.contentView?.wantsLayer = true
            

            self.window.level = .popUpMenu
            self.window.isOpaque = false
            self.window.backgroundColor = .clear
            self.window.appearance = theme.appearance
            backgroundView.backgroundColor = NSColor.black.withAlphaComponent(0.9)
            backgroundView.frame = bounds
            
            self.pager = GalleryPageController(frame: bounds, contentInset:NSEdgeInsets(left: 0, right: 0, top: 0, bottom: 95), interactions:interactions, window:window, reversed: reversed)
            //, selectedItemChanged: selectedItemChanged, transition: transition
            self.touchbarController = GalleryTouchBarController(interactions: interactions, selectedItemChanged: pager.selectedItemChanged, transition: pager.transition)
            self.window.rootViewController = touchbarController

        } else {
            fatalError("main screen not found for MediaViewer")
        }
        
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        
        interactions.dismiss = { [weak self] () -> KeyHandlerResult in
            if let pager = self?.pager {
                if pager.isFullScreen {
                    pager.exitFullScreen()
                    return .invoked
                }
                if !pager.lockedTransition {
                    self?.close(true)
                }
            }
            return .invoked
        }
        
        interactions.next = { [weak self] () -> KeyHandlerResult in
            self?.pager.next()
            return .invoked
        }
        
        interactions.previous = { [weak self] () -> KeyHandlerResult in
            self?.pager.prev()
            return .invoked
        }
        
        interactions.select = { [weak self] item in
            self?.pager.select(by: item)
        }
        
        interactions.showActions = { [weak self] control -> KeyHandlerResult in
            self?.showControlsPopover(control)
            return .invoked
        }
        interactions.share = { [weak self] control in
            self?.share(control)
        }
        
        interactions.openInfo = { [weak self] peerId in
            self?.openInfo(peerId)
        }
        
        interactions.openMessage = { [weak self] in
            self?.showMessage()
        }
        
        interactions.contextMenu = {[weak self] in
            return self?.contextMenu
        }
        
        interactions.zoomIn = { [weak self] in
            self?.pager.zoomIn()
        }
        interactions.zoomOut = { [weak self] in
            self?.pager.zoomOut()
        }
        interactions.rotateLeft = { [weak self] in
            self?.pager.rotateLeft()
        }
        interactions.fastSave = { [weak self] in
            self?.saveAs(true)
        }
        window.set(handler: { [weak self]  in
            guard let `self` = self else {return .rejected}
            if self.pager.selectedItem is MGalleryVideoItem || self.pager.selectedItem is MGalleryExternalVideoItem {
                self.pager.selectedItem?.togglePlayerOrPause()
                return .invoked
            } else {
                return self.interactions.dismiss()
            }
        }, with:self, for: .Space)
        
        window.set(handler: interactions.dismiss, with:self, for: .Escape)
        
        window.closeInterceptor = { [weak self] in
            _ = self?.interactions.dismiss()
            return true
        }
        
        window.set(handler: interactions.next, with:self, for: .RightArrow)
        window.set(handler: interactions.previous, with:self, for: .LeftArrow)
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.pager.zoomOut()
            return .invoked
        }, with: self, for: .Minus)
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.pager.zoomIn()
            return .invoked
        }, with: self, for: .Equal)
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.pager.rotateLeft()
            return .invoked
        }, with: self, for: .R, modifierFlags: [.command])
        
        window.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.saveAs()
            return .invoked
        }, with: self, for: .S, priority: .high, modifierFlags: [.command])
        
        window.copyhandler = { [weak self] in
            self?.copy(nil)
        }
        
        window.firstResponderFilter = { responder in
            return responder
        }
        
        self.controls = GalleryModernControls(account, interactions: interactions, frame: NSMakeRect(0, -150, window.frame.width, 150), thumbsControl: pager.thumbsControl)
        
//        switch type {
//        case .secret:
//            self.controls = GallerySecretControls(View(frame:NSMakeRect(0, 10, 200, 75)), interactions:interactions)
//        default:
//             self.controls = GalleryGeneralControls(View(frame:NSMakeRect(0, 10, 460, 75)), interactions:interactions)
//        }
//        self.controls.view?.backgroundColor = NSColor.black.withAlphaComponent(0.8)

        self.pager.view.addSubview(self.backgroundView)
        self.window.contentView?.addSubview(self.pager.view)
        self.window.contentView?.addSubview(self.controls.view)
        
        if #available(OSX 10.12.2, *) {
            window.touchBar = window.makeTouchBar()
        }
    }
    
    @objc open func windowDidBecomeKey() {
        
    }
    
    
    @objc open func windowDidResignKey() {
        self.window.makeKeyAndOrderFront(self)
      //  window.makeFirstResponder(self)
    }
    
    var pagerSize: NSSize {
        return NSMakeSize(pager.frame.size.width - pager.contentInset.right - pager.contentInset.left, pager.frame.size.height - pager.contentInset.bottom - pager.contentInset.top)
    }
    
    fileprivate convenience init(account:Account, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, reversed:Bool = false) {
        self.init(account: account, delegate, contentInteractions, type: .profile(peerId), reversed: reversed)

        let pagerSize = self.pagerSize
        
        ready.set(account.postbox.transaction { transaction -> Peer? in
            return transaction.getPeer(peerId)
        } |> deliverOnMainQueue |> map { [weak self] peer -> Bool in
            guard let `self` = self else {return false}
            if let peer = peer {
                var representations:[TelegramMediaImageRepresentation] = []
                if let representation = peer.smallProfileImage {
                    representations.append(representation)
                }
                if let representation = peer.largeProfileImage {
                    representations.append(representation)
                }
                
                var image:TelegramMediaImage? = nil
                
                if let base = firstStableId.base as? ChatHistoryEntryId, case let .message(message) = base {
                    let action = message.media.first as! TelegramMediaAction
                    switch action.action {
                    case let .photoUpdated(updated):
                        image = updated
                    default:
                        break
                    }
                }
                
                if image == nil {
                    image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 0), representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil)
                }
                
                _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: [(0,MGalleryPeerPhotoItem(account, .photo(index: 0, stableId: firstStableId, photo: image!, reference: nil, peerId: peerId, date: 0), pagerSize))], updated: []))
                
                
                self.pager.set(index: 0, animated: false)
                self.controls.update(self.pager.selectedItem?.entry)
                return true
            }
            return false
        })

        
        self.disposable.set((requestPeerPhotos(account: account, peerId: peerId) |> map { photos -> (UpdateTransition<MGalleryItem>, Int, Int) in
            
            var inserted:[(Int, MGalleryItem)] = []
            var updated:[(Int, MGalleryItem)] = []
            var deleted:[Int] = []
            
            var currentIndex: Int = 0
            var foundIndex: Bool = peerId.namespace == Namespaces.Peer.CloudUser
            
            if !photos.isEmpty {
                
                var photosDate:[TimeInterval] = []
                
                for i in 0 ..< photos.count {
                    let photo = photos[i]
                    photosDate.append(TimeInterval(photo.date))
                    if let base = firstStableId.base as? ChatHistoryEntryId, case let .message(message) = base {
                        let action = message.media.first as! TelegramMediaAction
                        switch action.action {
                        case let .photoUpdated(updated):
                            if photo.image.id == updated?.id {
                                currentIndex = i
                                foundIndex = true
                            }
                        default: 
                            break
                        }
                    } else if let base = firstStableId.base as? String, base == largestImageRepresentation(photo.image.representations)?.resource.id.uniqueId {
                        foundIndex = true
                        currentIndex = i
                        
                    }
                }
                var index: Int = foundIndex ? 0 : 1
                for i in 0 ..< photos.count {
                    if currentIndex == i && foundIndex {
                        deleted.append(i)
                        inserted.append((i, MGalleryPeerPhotoItem(account, .photo(index: photos[i].index, stableId: firstStableId, photo: photos[i].image, reference: photos[i].reference, peerId: peerId, date: photosDate[i]), pagerSize)))
                    } else {
                        inserted.append((index, MGalleryPeerPhotoItem(account, .photo(index: photos[i].index, stableId: photos[i].image.imageId, photo: photos[i].image, reference: photos[i].reference, peerId: peerId, date: photosDate[i]), pagerSize)))
                    }
                    index += 1
                }
            }
            
            
            return (UpdateTransition(deleted: deleted, inserted: inserted, updated: updated), max(0, photos.count), currentIndex)
            
        } |> deliverOnMainQueue).start(next: { [weak self] transition, total, selected in
            guard let `self` = self else {return}
            
           // self?.controls.index.set(.single((selected + 1, max(totalCount, 1))))
            _ = self.pager.merge(with: transition, afterTransaction: { [weak self] in
                guard let `self` = self else {return}
                self.controls.update(self.pager.selectedItem?.entry)
            })
            
        }))
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem?.entry)
        }))
    }
    
    fileprivate convenience init(account:Account, instantMedias:[InstantPageMedia], firstIndex:Int, firstStableId: AnyHashable? = nil, parent: Message? = nil, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, reversed:Bool = false) {
        self.init(account: account, delegate, contentInteractions, type: .history, reversed: reversed)
        self.firstStableId = firstStableId
        let pagerSize = self.pagerSize
        

        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            
            guard let `self` = self else {return false}
            
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< instantMedias.count {
                let media = instantMedias[i]
                if media.media is TelegramMediaImage {
                    inserted.append((media.index, MGalleryPhotoItem(account, .instantMedia(media, parent), pagerSize)))
                } else if let file = media.media as? TelegramMediaFile {
                    if file.isVideo && file.isAnimated {
                        inserted.append((media.index, MGalleryGIFItem(account, .instantMedia(media, parent), pagerSize)))
                    } else if file.isVideo {
                        inserted.append((media.index, MGalleryVideoItem(account, .instantMedia(media, parent), pagerSize)))
                    }
                } else if media.media is TelegramMediaWebpage {
                    inserted.append((media.index, MGalleryExternalVideoItem(account, .instantMedia(media, parent), pagerSize)))
                }
            }
            
            _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            //self?.controls.index.set(.single((firstIndex + 1, totalCount)))
            self.pager.set(index: firstIndex, animated: false)
            self.controls.update(self.pager.selectedItem?.entry)
            return true
            
        })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem?.entry)
        }))
        
        
    }
    
    
    fileprivate convenience init(account:Account, secureIdMedias:[SecureIdDocumentValue], firstIndex:Int, _ delegate:InteractionContentViewProtocol? = nil, reversed:Bool = false) {
        self.init(account: account, delegate, nil, type: .history, reversed: reversed)
        
        let pagerSize = self.pagerSize
        
        
        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            guard let `self` = self else {return false}
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< secureIdMedias.count {
                let media = secureIdMedias[i]
                inserted.append((i, MGalleryPhotoItem(account, .secureIdDocument(media, i), pagerSize)))

            }
            
            _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            self.pager.set(index: firstIndex, animated: false)
            self.controls.update(self.pager.selectedItem?.entry)
            return true
            
            })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem?.entry)
        }))
        
        
    }
   
    
    fileprivate convenience init(account:Account, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history, item: MGalleryItem? = nil, reversed: Bool = false) {
        
        self.init(account: account, delegate, contentInteractions, type: type, reversed: reversed)

       
        let previous:Atomic<[ChatHistoryEntry]> = Atomic(value:[])
        let current:Atomic<[ChatHistoryEntry]> = Atomic(value:[])
        let currentIndex:Atomic<Int?> = Atomic(value:nil)
        let request:Promise<MessageIndex> = Promise()
        let pagerSize = self.pagerSize
        let indexes:Atomic<(earlierId: MessageIndex?, laterId: MessageIndex?)> = Atomic(value:(nil, nil))
        
        if let item = item, let entry = item.entry.chatEntry {
            _ = current.swap([entry])
            
            let transition: UpdateTransition<MGalleryItem> = UpdateTransition(deleted: [], inserted: [(0, item)], updated: [])
            
            _ = pager.merge(with: transition)
            ready.set(.single(true))
        }
        
        let signal = request.get()
            |> distinctUntilChanged
            |> mapToSignal { index -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                
                var type = type
                let tags = tagsForMessage(message)
                if tags == nil {
                   type = .alone
                }

                let view = account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(message.id.peerId), count: 50, clipHoles: true, messageId: index.id, tagMask: tags, orderStatistics: [.combinedLocation], additionalData: [])
            
                switch type {
                case .alone:
                    let entries:[ChatHistoryEntry] = [.MessageEntry(message, MessageIndex(message), false, .list, .Full(isAdmin: false), nil, nil, nil)]
                    let previous = previous.swap(entries)
                    
                    var inserted: [(Int, MGalleryItem)] = []
                    
                    inserted.insert((0, itemFor(entry: entries[0], account: account, pagerSize: pagerSize)), at: 0)

                    if let webpage = message.media.first as? TelegramMediaWebpage {
                        let instantMedias = instantPageMedias(for: webpage)
                        if instantMedias.count > 1 {
                            for i in 1 ..< instantMedias.count {
                                let media = instantMedias[i]
                                if media.media is TelegramMediaImage {
                                    inserted.append((i, MGalleryPhotoItem(account, .instantMedia(media, message), pagerSize)))
                                } else if let file = media.media as? TelegramMediaFile {
                                    if file.isVideo && file.isAnimated {
                                        inserted.append((i, MGalleryGIFItem(account, .instantMedia(media, message), pagerSize)))
                                    } else if file.isVideo {
                                        inserted.append((i, MGalleryVideoItem(account, .instantMedia(media, message), pagerSize)))
                                    }
                                } else if media.media is TelegramMediaWebpage {
                                    inserted.append((i, MGalleryExternalVideoItem(account, .instantMedia(media, message), pagerSize)))
                                }
                            }
                        }
                        
                    }
                    
                    return .single((UpdateTransition(deleted: [], inserted: inserted, updated: []), previous, entries)) |> deliverOnMainQueue

                case .history:
                    return view |> mapToSignal { view, _, _ -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                        let entries:[ChatHistoryEntry] = messageEntries(view.entries, includeHoles : false).filter { entry -> Bool in
                            switch entry {
                            case let .MessageEntry(message, _, _, _, _, _, _, _):
                                return message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia
                            default:
                                return true
                            }
                        }
                        let previous = previous.with {$0}
                        return prepareEntries(from: previous, to: entries, account: account, pagerSize: pagerSize) |> deliverOnMainQueue |> map { transition in
                            _ = indexes.swap((view.earlierId, view.laterId))
                            return (transition,previous, entries)
                        }
                    }
                case .secret:
                    return account.postbox.messageView(index.id) |> mapToSignal { view -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                        var entries:[ChatHistoryEntry] = []
                        if let message = view.message, !(message.media.first is TelegramMediaExpiredContent) {
                            entries.append(.MessageEntry(message, MessageIndex(message), false, .list, .Full(isAdmin: false), nil, nil, nil))
                        }
                        let previous = previous.with {$0}
                        return prepareEntries(from: previous, to: entries, account: account, pagerSize: pagerSize) |> map { transition in
                            return (transition,previous, entries)
                        }
                    }
                case .profile:
                    return .complete()
                }
              
            }  |> deliverOnMainQueue
            |> map { [weak self] transition, prev, new in
                if let strongSelf = self {
                    
                    _ = previous.swap(new)
                    
                    let new = reversed ? new.reversed() : new
                    
                    _ = current.swap(new)
                    
                    var id:MessageId = message.id
                    let index = currentIndex.modify({$0})
                    if let index = index {
                        id = prev[index].message!.id
                    }

                    
                    var current:Int? = currentIndex.modify({$0})
                    if current == nil || !reversed {
                        for i in 0 ..< new.count {
                            if let message = new[i].message {
                                if message.id == id {
                                    current = i
                                }
                            }
                        }
                    }
                    
//
                    
                    
                    let isEmpty = strongSelf.pager.merge(with: transition)
                    
                    if !isEmpty {
                        
                        
                        if let newIndex = current {                           
                            strongSelf.pager.selectedIndex.set(newIndex)
                            strongSelf.pager.set(index: newIndex, animated: false)
                            if !new.isEmpty && newIndex < new.count && newIndex >= 0, let attribute = new[newIndex].message?.autoremoveAttribute {
                               // (self?.controls as? GallerySecretControls)?.update(with: attribute, outgoing: !new[newIndex].message!.flags.contains(.Incoming))
                            }
                        }
                    } else {
                        strongSelf.close()
                    }
                    strongSelf.ready.set(.single(true))
                }
            }
        
        
        self.disposable.set(signal.start())
        let reqlimit:Int = 10
        self.indexDisposable.set(pager.selectedIndex.get().start(next: { [weak self] (selectedIndex) in
           
            let entries = current.modify({$0})
            let selectedIndex = min(entries.count - 1, selectedIndex)
            
            guard let `self` = self else {return}
            
            let current = entries[selectedIndex]
            if let location = current.location {
                let total = location.count
                let current = reversed ? total - location.index : location.index
                self.controls.update(self.pager.selectedItem?.entry)
            } else  {
                 self.controls.update(self.pager.selectedItem?.entry)
            }
            
            
            if let message = entries[selectedIndex].message, message.containsSecretMedia {
                _ = (markMessageContentAsConsumedInteractively(postbox: account.postbox, messageId: message.id) |> delay(0.5, queue: Queue.concurrentDefaultQueue())).start()
            }
            let indexes = indexes.modify({$0})
            
            if let pagerIndex = currentIndex.modify({$0}) {
                if selectedIndex < pagerIndex && pagerIndex < reqlimit {
                    if !reversed, let earlier = indexes.earlierId {
                        request.set(.single(earlier))
                    } else if reversed, let later = indexes.laterId {
                        request.set(.single(later))
                    }
                } else if selectedIndex > pagerIndex && pagerIndex > entries.count - reqlimit {
                    if !reversed, let later = indexes.laterId {
                        request.set(.single(later))
                    } else if reversed, let earlier = indexes.earlierId {
                        request.set(.single(earlier))
                    }
                }
            }
            _ = currentIndex.swap(selectedIndex)
            
            
        }))
        
        request.set(.single(MessageIndex(message)))

    }
    

    
    func showControlsPopover(_ control:Control) {
        var items:[SPopoverItem] = []
        items.append(SPopoverItem(L10n.galleryContextSaveAs, {[weak self] in
            self?.saveAs()
        }))
        
        let account = self.account
        if let item = pager.selectedItem as? MGalleryGIFItem {
            let file = item.media
            if file.isAnimated && file.isVideo {
                let reference = item.entry.fileReference(file)
                items.append(SPopoverItem(L10n.gallerySaveGif, {
                    let _ = addSavedGif(postbox: account.postbox, fileReference: reference).start()
                }))
            }
        }
        
        if let _ = self.contentInteractions, case .history = type {
            items.append(SPopoverItem(L10n.galleryContextShowMessage, {[weak self] in
                self?.showMessage()
            }))
            items.append(SPopoverItem(L10n.galleryContextShowGallery, {[weak self] in
                self?.showSharedMedia()
            }))
            if let message = pager.selectedItem?.entry.message {
                if canDeleteMessage(message, account: account) {
                    items.append(SPopoverItem(L10n.galleryContextDeletePhoto, {[weak self] in
                        self?.deleteMessage(control)
                    }))
                }
            }
        }
        items.append(SPopoverItem(L10n.galleryContextCopyToClipboard, {[weak self] in
            self?.copy(nil)
        }))
        
        switch type {
        case .profile(let peerId):
            if peerId == account.peerId {
                items.append(SPopoverItem(L10n.galleryContextDeletePhoto, {[weak self] in
                    self?.deletePhoto()
                }))
            }
        default:
            break
        }
        
        items.append(SPopoverItem(L10n.navigationClose, { [weak self] in
            _ = self?.interactions.dismiss()
        }))
        
        showPopover(for: control, with: SPopoverViewController(items: items, visibility: 6), inset:NSMakePoint((-105 + 14), 0), static: true)
    }
    
    private func deleteMessages(_ messages:[Message]) {
        if !messages.isEmpty, let peer = messageMainPeer(messages[0]) {
            
            let peerId = messages[0].id.peerId
            let messageIds = messages.map {$0.id}
            
            let channelAdmin:Signal<[ChannelParticipant]?, NoError> = peer.isSupergroup ? channelAdmins(account: account, peerId: peerId)
                |> `catch` {_ in return .complete()} |> map { admins -> [ChannelParticipant]? in
                    return admins.map({$0.participant})
            } : .single(nil)
            
            
            messagesActionDisposable.set((channelAdmin |> deliverOnMainQueue).start( next:{ [weak self] admins in
                guard let `self` = self else {return}
                
                var canDelete:Bool = true
                var canDeleteForEveryone = true
                
                var otherCounter:Int32 = 0
                for message in messages {
                    if !canDeleteMessage(message, account: self.account) {
                        canDelete = false
                    }
                    if !canDeleteForEveryoneMessage(message, account: self.account) {
                        canDeleteForEveryone = false
                    } else {
                        if message.author?.id != self.account.peerId {
                            otherCounter += 1
                        }
                    }
                }
                
                if otherCounter == messages.count {
                    canDeleteForEveryone = false
                }
                
                if canDelete {
                    let thrid:String? = canDeleteForEveryone ? peer.isUser ? L10n.chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : L10n.chatConfirmDeleteMessagesForEveryone : nil
                    
                    if let thrid = thrid {
                        modernConfirm(for: self.window, account: self.account, peerId: nil, accessory: theme.icons.confirmDeleteMessagesAccessory, header: L10n.chatConfirmDeleteMessages, information: nil, okTitle: L10n.confirmDelete, thridTitle: thrid, successHandler: { [weak self] result in
                            guard let `self` = self else {return}
                            
                            let type:InteractiveMessagesDeletionType
                            switch result {
                            case .basic:
                                type = .forLocalPeer
                            case .thrid:
                                type = .forEveryone
                            }
                            
                            _ = deleteMessagesInteractively(postbox: self.account.postbox, messageIds: messageIds, type: type).start()
                        })
                    } else {
                        _ = deleteMessagesInteractively(postbox: self.account.postbox, messageIds: messageIds, type: .forLocalPeer).start()
                    }
                }
            }))
        }
    }
    
    private func deleteMessage(_ control: Control) {
         if let message = self.pager.selectedItem?.entry.message {
            let messages = pager.thumbsControl.items.compactMap({$0.entry.message})
            
            if messages.count > 1 {
                
                var items:[SPopoverItem] = []
                
                let thisTitle: String
                if message.media.first is TelegramMediaImage {
                    thisTitle = L10n.galleryContextShareThisPhoto
                } else {
                    thisTitle = L10n.galleryContextShareThisVideo
                }
                items.append(SPopoverItem(thisTitle, { [weak self] in
                    self?.deleteMessages([message])
                }))
               
                
                let allTitle: String
                if messages.filter({$0.media.first is TelegramMediaImage}).count == messages.count {
                    allTitle = L10n.galleryContextShareAllPhotosCountable(messages.count)
                } else if messages.filter({$0.media.first is TelegramMediaFile}).count == messages.count {
                    allTitle = L10n.galleryContextShareAllVideosCountable(messages.count)
                } else {
                    allTitle = L10n.galleryContextShareAllItemsCountable(messages.count)
                }
                
                items.append(SPopoverItem(allTitle, { [weak self] in
                    self?.deleteMessages(messages)
                }))
                showPopover(for: control, with: SPopoverViewController(items: items), inset:NSMakePoint((-90 + 14),0), static: true)
            } else {
                deleteMessages([message])
            }
         }
    }
    
    private func deletePhoto() {
        if let item = self.pager.selectedItem {
            if let index = self.pager.index(for: item) {
                let isEmpty = pager.merge(with: UpdateTransition<MGalleryItem>(deleted: [index], inserted: [], updated: []))
                
                if isEmpty {
                    close()
                }
                
                pager.selectedIndex.set(index)
                
                if case let .photo(_, _, _, reference, _, _) = item.entry {
                    _ = removeAccountPhoto(network: account.network, reference: index == 0 ? nil : reference).start()
                }
            }
            
        }
    }
    
    
    var contextMenu:NSMenu {
        let menu = NSMenu()
        
        if let item = self.pager.selectedItem {
            if !(item is MGalleryExternalVideoItem) {
                menu.addItem(ContextMenuItem(tr(L10n.galleryContextSaveAs), handler: { [weak self] in
                    self?.saveAs()
                }))
            }
            
            if let _ = self.contentInteractions {
                menu.addItem(ContextMenuItem(tr(L10n.galleryContextShowMessage), handler: { [weak self] in
                    self?.showMessage()
                }))
            }
            menu.addItem(ContextMenuItem(tr(L10n.galleryContextCopyToClipboard), handler: { [weak self] in
                self?.copy(nil)
            }))
        }
        
        
        return menu
    }
    
    
    func saveAs(_ fast: Bool = false) -> Void {
        if let item = self.pager.selectedItem {
            if !(item is MGalleryExternalVideoItem) {
                let isPhoto = item is MGalleryPhotoItem || item is MGalleryPeerPhotoItem
                operationDisposable.set((item.realStatus |> take(1) |> deliverOnMainQueue).start(next: { [weak self] status in
                    guard let `self` = self else {return}
                    switch status {
                    case .Local:
                        self.operationDisposable.set((item.path.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] path in
                            if let strongSelf = self {
                                if fast {
                                   // let attr = NSMutableAttributedString()
                                   // attr.append(string: "File saved to your download folder", color: .white, font: .bold(18))
                                   
                                    let text: String
                                    if item is MGalleryVideoItem {
                                         text = L10n.galleryViewFastSaveVideo
                                    } else if item is MGalleryGIFItem {
                                        text = L10n.galleryViewFastSaveGif
                                    } else {
                                        text = L10n.galleryViewFastSaveImage
                                    }
                                    
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                                   
                                    
                                    let file: TelegramMediaFile?
                                    if let item = item as? MGalleryVideoItem {
                                        file = item.media
                                    } else if let item = item as? MGalleryGIFItem {
                                        file = item.media
                                    } else if let photo = item as? MGalleryPhotoItem {
                                        file = photo.entry.file ?? TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: photo.media.representations.last!.resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "photo_\(dateFormatter.string(from: Date())).jpeg")])
                                    } else if let photo = item as? MGalleryPeerPhotoItem {
                                        file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: 0), partialReference: nil, resource: photo.media.representations.last!.resource, previewRepresentations: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "photo_\(dateFormatter.string(from: Date())).jpeg")])
                                    } else {
                                        file = nil
                                    }
                                    
                                    let account = strongSelf.account
                                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .bold(18), textColor: .white), bold: MarkdownAttributeSet(font: .bold(18), textColor: .white), link: MarkdownAttributeSet(font: .bold(18), textColor: theme.colors.link), linkAttribute: { contents in
                                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in }))
                                    })).mutableCopy() as! NSMutableAttributedString
                                    
                                    let layout = TextViewLayout(attributedText, alwaysStaticItems: true)
                                    layout.interactions = TextViewInteractions.init(processURL: { [weak strongSelf] url  in
                                         if let file = file {
                                            showInFinder(file, account: account)
                                            strongSelf?.close(false)
                                        }
                                    })
                                    layout.measure(width: strongSelf.window.frame.width - 100)
                                    
                                    if let file = file {
                                        _ = (copyToDownloads(file, postbox: account.postbox) |> deliverOnMainQueue |> take(1) |> then (showModalSuccess(for: strongSelf.window, icon: theme.icons.successModalProgress, text: layout, delay: 4.0))).start()
                                    } else {
                                        savePanel(file: path.nsstring.deletingPathExtension, ext: path.nsstring.pathExtension, for: strongSelf.window)
                                    }
                                    
//                                    if let file = item.entry.file {
//                                        //copyToDownloads(file, postbox: item.account.postbox)
//
//                                    }
                                } else {
                                    savePanel(file: path.nsstring.deletingPathExtension, ext: path.nsstring.pathExtension, for: strongSelf.window)
                                }
                            }
                        }))
                    default:
                        alert(for: self.window, info: isPhoto ? L10n.galleryWaitDownloadPhoto : L10n.galleryWaitDownloadVideo)
                    }
                    
                }))
                
            }
            
        }
    }
    
    func showMessage() -> Void {
        close()
        if let message = self.pager.selectedItem?.entry.message {
            contentInteractions?.showMessage(message)
        }
    }
    
    func showSharedMedia() {
        close()
        if let message = self.pager.selectedItem?.entry.message {
            account.context.mainNavigation?.push(PeerMediaController(account: account, peerId: message.id.peerId, tagMask: .photoOrVideo))
        }
    }
    
    func openInfo(_ peerId: PeerId) {
        close()
        account.context.mainNavigation?.push(PeerInfoController(account: account, peerId: peerId))
    }
    
    func share(_ control: Control) -> Void {
        if let message = self.pager.selectedItem?.entry.message {
            if message.groupInfo != nil {
                let messages = pager.thumbsControl.items.compactMap({$0.entry.message})
                var items:[SPopoverItem] = []
                
                let thisTitle: String
                if message.media.first is TelegramMediaImage {
                    thisTitle = L10n.galleryContextShareThisPhoto
                } else {
                    thisTitle = L10n.galleryContextShareThisVideo
                }
                
                items.append(SPopoverItem(thisTitle, { [weak self] in
                    guard let `self` = self else {return}
                    self.close()
                    showModal(with: ShareModalController(ShareMessageObject(self.account, message)), for: self.window)
                    
                }))
                
                let allTitle: String
                if messages.filter({$0.media.first is TelegramMediaImage}).count == messages.count {
                    allTitle = L10n.galleryContextShareAllPhotosCountable(messages.count)
                } else if messages.filter({$0.media.first is TelegramMediaFile}).count == messages.count {
                    allTitle = L10n.galleryContextShareAllVideosCountable(messages.count)
                } else {
                    allTitle = L10n.galleryContextShareAllItemsCountable(messages.count)
                }
                
                items.append(SPopoverItem(allTitle, { [weak self] in
                    guard let `self` = self else {return}
                    showModal(with: ShareModalController(ShareMessageObject(self.account, message, messages)), for: self.window)
                }))
                
                
                showPopover(for: control, with: SPopoverViewController(items: items), inset:NSMakePoint((-125 + 14),0), static: true)
            } else {
                showModal(with: ShareModalController(ShareMessageObject(self.account, message)), for: self.window)
            }
        }
    }
    
    @objc func copy(_ sender:Any? = nil) -> Void {
        if let item = self.pager.selectedItem {
            if !(item is MGalleryExternalVideoItem) {
                operationDisposable.set((item.path.get() |> take(1) |> deliverOnMainQueue).start(next: { path in
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.writeObjects([NSURL(fileURLWithPath: path)])
                }))
            } else if let item = item as? MGalleryExternalVideoItem {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.content.url, forType: .string)
                
            }
        }
    }

    
    
    
    fileprivate func show(_ animated: Bool = true, _ ignoreStableId:AnyHashable? = nil) -> Void {
        viewer = self
        mainWindow.resignFirstResponder()
        //window.makeFirstResponder(self)
        //closePipVideo()
        backgroundView.alphaValue = 0
        //backgroundView.change(opacity: 0, animated: false)
        self.readyDispose.set((self.ready.get() |> take(1) |> deliverOnMainQueue).start { [weak self] in
            if let strongSelf = self {
                
               // strongSelf.backgroundView.change(opacity: 1, animated: animated)
                strongSelf.pager.animateIn(from: { [weak strongSelf] stableId -> NSView? in
                    if let firstStableId = strongSelf?.firstStableId, let innerIndex = stableId.base as? Int {
                        if let ignore = ignoreStableId?.base as? Int, ignore == innerIndex {
                            return nil
                        }
                        let view = strongSelf?.delegate?.contentInteractionView(for: firstStableId, animateIn: false)
                        return view?.subviews[innerIndex]
                    }
                    if ignoreStableId != stableId {
                        return strongSelf?.delegate?.contentInteractionView(for: stableId, animateIn: false)
                    }

                    return nil
                }, completion:{ [weak strongSelf] in
                    strongSelf?.backgroundView.alphaValue = 1.0
                    strongSelf?.controls.animateIn()
                }, addAccesoryOnCopiedView: { stableId, view in
                    if let stableId = stableId {
                        //self?.delegate?.addAccesoryOnCopiedView(for: stableId, view: view)
                    }
                }, addVideoTimebase: { stableId, view  in
                   
                })
                strongSelf.window.makeKeyAndOrderFront(nil)
            }
        });
        
    }
    
    func close(_ animated:Bool = false) -> Void {
        disposable.dispose()
        readyDispose.dispose()
        didSetReady = false
        NotificationCenter.default.removeObserver(self)
        if animated {
            backgroundView.alphaValue = 0
            controls.animateOut()
            self.pager.animateOut(to: { [weak self] stableId in
                if let firstStableId = self?.firstStableId, let innerIndex = stableId.base as? Int {
                    let view = self?.delegate?.contentInteractionView(for: firstStableId, animateIn: false)
                    return view?.subviews[innerIndex]
                }
                return self?.delegate?.contentInteractionView(for: stableId, animateIn: true)
            }, completion: { [weak self] interactive, stableId in
               
                if let stableId = stableId {
                    self?.delegate?.interactionControllerDidFinishAnimation(interactive: interactive, for: stableId)
                }
                self?.window.orderOut(nil)
                viewer = nil
                playPipIfNeeded()
            }, addAccesoryOnCopiedView: { [weak self] stableId, view in
                if let stableId = stableId {
                    self?.delegate?.addAccesoryOnCopiedView(for: stableId, view: view)
                }
            }, addVideoTimebase: { stableId, view  in
                
            })
        } else {
            window.orderOut(nil)
            viewer = nil
            playPipIfNeeded()
        }
        
    }
    
    deinit {
        clean()
    }
    
    func clean() {
        indexDisposable.dispose()
        disposable.dispose()
        operationDisposable.dispose()
        window.removeAllHandlers(for: self)
        readyDispose.dispose()
        messagesActionDisposable.dispose()
    }
    
}


func closeGalleryViewer(_ animated: Bool) {
    viewer?.close(animated)
}

func showChatGallery(account:Account, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history, reversed: Bool = false) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(account: account, message: message, delegate, contentInteractions, type: type, reversed: reversed)
        gallery.show()
    }
}

func showGalleryFromPip(item: MGalleryItem, gallery: GalleryViewer, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history) {
    if viewer == nil {
        viewer?.clean()
        gallery.show(true, item.stableId)
    }
}

func showPhotosGallery(account:Account, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(account: account, peerId: peerId, firstStableId: firstStableId, delegate, contentInteractions)
        gallery.show()
    }
}

func showInstantViewGallery(account: Account, medias:[InstantPageMedia], firstIndex: Int, firstStableId:AnyHashable? = nil, parent: Message? = nil, _ delegate: InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(account: account, instantMedias: medias, firstIndex: firstIndex, firstStableId: firstStableId, parent: parent, delegate, contentInteractions)
        gallery.show()
    }
}


func showSecureIdDocumentsGallery(account: Account, medias:[SecureIdDocumentValue], firstIndex: Int, _ delegate: InteractionContentViewProtocol? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(account: account, secureIdMedias: medias, firstIndex: firstIndex, delegate)
        gallery.show()
    }
   
}

