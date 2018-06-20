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
    var contextMenu:()->NSMenu? = {return nil}
    
    var showThumbsControl:(View, Bool)->Void = {_, _ in}
    var hideThumbsControl:(View, Bool)->Void = {_, _ in}

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
    case let .MessageEntry(message, _, _, _, _, _):
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

fileprivate func prepareEntries(from:[ChatHistoryEntry]?, to:[ChatHistoryEntry], account:Account, pagerSize:NSSize) -> Signal<UpdateTransition<MGalleryItem>, Void> {
    return Signal { subscriber in
        
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> MGalleryItem in
           return itemFor(entry: entry, account: account, pagerSize: pagerSize)
        })
        
        subscriber.putNext(UpdateTransition(deleted: removed, inserted: inserted, updated: updated))
        subscriber.putCompletion()
        
        return EmptyDisposable
    } |> runOn(prepareQueue)
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


class GalleryViewer: NSResponder {
    
    fileprivate var viewCache:[AnyHashable: NSView] = [:]
    
    let window:Window
    private var controls:GalleryControls!
    let pager:GalleryPageController
    private let backgroundView: GalleryBackgroundView = GalleryBackgroundView()
    private let ready = Promise<Bool>()
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    private let readyDispose = MetaDisposable()
    private let operationDisposable = MetaDisposable()
    private(set) weak var delegate:InteractionContentViewProtocol?
    private let account:Account
    
    private let indexDisposable:MetaDisposable = MetaDisposable()
    
    
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
            
            self.window.level = .screenSaver
            self.window.isOpaque = false
          
            self.window.backgroundColor = .clear
            self.window.appearance = theme.appearance
            backgroundView.backgroundColor = .blackTransparent
            backgroundView.frame = bounds
            
            self.pager = GalleryPageController(frame: bounds, contentInset:NSEdgeInsets(left: 0, right: 0, top: 0, bottom: 95), interactions:interactions, window:window, reversed: reversed)
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
        
        interactions.contextMenu = {[weak self] in
            return self?.contextMenu
        }
        
        window.set(handler: interactions.dismiss, with:self, for: .Space)
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
            self?.saveAs()
            return .invoked
        }, with: self, for: .S, priority: .high, modifierFlags: [.command])
        
        window.copyhandler = { [weak self] in
            self?.copy(nil)
        }
        
        switch type {
        case .secret:
            self.controls = GallerySecretControls(View(frame:NSMakeRect(0, 10, 200, 75)), interactions:interactions)
        default:
             self.controls = GalleryGeneralControls(View(frame:NSMakeRect(0, 10, 460, 75)), interactions:interactions)
        }
        self.controls.view?.backgroundColor = NSColor.black.withAlphaComponent(0.8)

        self.pager.view.addSubview(self.backgroundView)
        self.window.contentView?.addSubview(self.pager.view)
        self.window.contentView?.addSubview(self.controls.view!)
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
                     image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 0), representations: representations, reference: nil)
                }
                
                _ = self?.pager.merge(with: UpdateTransition(deleted: [], inserted: [(0,MGalleryPeerPhotoItem(account, .photo(index: 0, stableId: firstStableId, photo: image!, reference: nil), pagerSize))], updated: []))
                
                
                self?.controls.index.set(.single((1,1)))
                self?.pager.set(index: 0, animated: false)
                
                return true
            }
            return false
        })

        var totalCount:Int = 1
        
        self.disposable.set((requestPeerPhotos(account: account, peerId: peerId) |> map { photos -> (UpdateTransition<MGalleryItem>, Int, Int) in
            
            var inserted:[(Int, MGalleryItem)] = []
            var updated:[(Int, MGalleryItem)] = []
            let deleted:[Int] = []
            
            var currentIndex: Int = 0

            
            if !photos.isEmpty {
                
                for i in 0 ..< photos.count {
                    let photo = photos[i]
                    if let base = firstStableId.base as? ChatHistoryEntryId, case let .message(message) = base {
                        let action = message.media.first as! TelegramMediaAction
                        switch action.action {
                        case let .photoUpdated(updated):
                            if photo.image.id == updated?.id {
                                currentIndex = i
                            }
                        default:
                            break
                        }
                    }
                }
                
                for i in 0 ..< photos.count {
                    if currentIndex == i {
                        updated.append((i, MGalleryPeerPhotoItem(account, .photo(index: photos[i].index, stableId: firstStableId, photo: photos[i].image, reference: photos[i].reference), pagerSize)))
                    } else {
                        inserted.append((i, MGalleryPeerPhotoItem(account, .photo(index: photos[i].index, stableId: photos[i].image.imageId, photo: photos[i].image, reference: photos[i].reference), pagerSize)))
                    }
                }
            }
            
            
            return (UpdateTransition(deleted: deleted, inserted: inserted, updated: updated), max(0, photos.count), currentIndex)
            
        } |> deliverOnMainQueue).start(next: { [weak self] transition, total, selected in
            totalCount = total
            
            self?.controls.index.set(.single((selected + 1, max(totalCount, 1))))
            _ = self?.pager.merge(with: transition)
            
        }))
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] (selectedIndex) in
            if let strongSelf = self {
                self?.controls.index.set(.single((selectedIndex + 1, strongSelf.pager.count)))
            }
        }))
    }
    
    fileprivate convenience init(account:Account, instantMedias:[InstantPageMedia], firstIndex:Int, firstStableId: AnyHashable? = nil, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, reversed:Bool = false) {
        self.init(account: account, delegate, contentInteractions, type: .history, reversed: reversed)
        self.firstStableId = firstStableId
        let pagerSize = self.pagerSize
        
        let totalCount:Int = instantMedias.count

        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< instantMedias.count {
                let media = instantMedias[i]
                if media.media is TelegramMediaImage {
                    inserted.append((media.index, MGalleryPhotoItem(account, .instantMedia(media), pagerSize)))
                } else if let file = media.media as? TelegramMediaFile {
                    if file.isVideo && file.isAnimated {
                        inserted.append((media.index, MGalleryGIFItem(account, .instantMedia(media), pagerSize)))
                    } else if file.isVideo {
                        inserted.append((media.index, MGalleryVideoItem(account, .instantMedia(media), pagerSize)))
                    }
                }
            }
            
            _ = self?.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            self?.controls.index.set(.single((firstIndex + 1, totalCount)))
            self?.pager.set(index: firstIndex, animated: false)
            
            return true
            
        })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] (selectedIndex) in
            self?.controls.index.set(.single((selectedIndex + 1,totalCount)))
        }))
        
        
    }
    
    
    fileprivate convenience init(account:Account, secureIdMedias:[SecureIdDocumentValue], firstIndex:Int, _ delegate:InteractionContentViewProtocol? = nil, reversed:Bool = false) {
        self.init(account: account, delegate, nil, type: .history, reversed: reversed)
        
        let pagerSize = self.pagerSize
        
        let totalCount:Int = secureIdMedias.count
        
        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< secureIdMedias.count {
                let media = secureIdMedias[i]
                inserted.append((i, MGalleryPhotoItem(account, .secureIdDocument(media, i), pagerSize)))

            }
            
            _ = self?.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            self?.controls.index.set(.single((firstIndex + 1, totalCount)))
            self?.pager.set(index: firstIndex, animated: false)
            
            return true
            
            })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] (selectedIndex) in
            self?.controls.index.set(.single((selectedIndex + 1,totalCount)))
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
            |> mapToSignal { index -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), Void> in
                
                var type = type
                let tags = tagsForMessage(message)
                if tags == nil {
                   type = .alone
                }

                let view = account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(message.id.peerId), count: 50, clipHoles: true, messageId: index.id, tagMask: tags, orderStatistics: [.combinedLocation], additionalData: [])
            
                switch type {
                case .alone:
                    let entries:[ChatHistoryEntry] = [.MessageEntry(message, false, .list, .Full(isAdmin: false), nil, nil)]
                    let previous = previous.swap(entries)
                    
                    var inserted: [(Int, MGalleryItem)] = []
                    
                    inserted.insert((0, itemFor(entry: entries[0], account: account, pagerSize: pagerSize)), at: 0)

                    if let webpage = message.media.first as? TelegramMediaWebpage {
                        let instantMedias = instantPageMedias(for: webpage)
                        if instantMedias.count > 1 {
                            for i in 1 ..< instantMedias.count {
                                let media = instantMedias[i]
                                if media.media is TelegramMediaImage {
                                    inserted.append((i, MGalleryPhotoItem(account, .instantMedia(media), pagerSize)))
                                } else if let file = media.media as? TelegramMediaFile {
                                    if file.isVideo && file.isAnimated {
                                        inserted.append((i, MGalleryGIFItem(account, .instantMedia(media), pagerSize)))
                                    } else if file.isVideo {
                                        inserted.append((i, MGalleryVideoItem(account, .instantMedia(media), pagerSize)))
                                    }
                                }
                            }
                        }
                        
                    }
                    
                    return .single((UpdateTransition(deleted: [], inserted: inserted, updated: []), previous, entries)) |> deliverOnMainQueue

                case .history:
                    return view |> mapToQueue { view, _, _ -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), Void> in
                        let entries:[ChatHistoryEntry] = messageEntries(view.entries, includeHoles : false).filter { entry -> Bool in
                            switch entry {
                            case let .MessageEntry(message, _, _, _, _, _):
                                return message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia
                            default:
                                return true
                            }
                        }
                        let previous = previous.swap(entries)
                        return prepareEntries(from: previous, to: entries, account: account, pagerSize: pagerSize) |> deliverOnMainQueue |> map { transition in
                            _ = indexes.swap((view.earlierId, view.laterId))
                            return (transition,previous, entries)
                        }
                    }
                case .secret:
                    return account.postbox.messageView(index.id) |> mapToQueue { view -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), Void> in
                        var entries:[ChatHistoryEntry] = []
                        if let message = view.message, !(message.media.first is TelegramMediaExpiredContent) {
                            entries.append(.MessageEntry(message, false, .list, .Full(isAdmin: false), nil, nil))
                        }
                        let previous = previous.swap(entries)
                        return prepareEntries(from: previous, to: entries, account: account, pagerSize: pagerSize) |> map { transition in
                            return (transition,previous, entries)
                        } |> deliverOnMainQueue
                    }
                case .profile:
                    return .complete()
                }
              
            }
            |> map { [weak self] transition, previous, new in
                if let strongSelf = self {
                    
                    let new = reversed ? new.reversed() : new
                    
                    _ = current.swap(new)
                    
                    var id:MessageId = message.id
                    let index = currentIndex.modify({$0})
                    if let index = index {
                        id = previous[index].message!.id
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
                                (self?.controls as? GallerySecretControls)?.update(with: attribute, outgoing: !new[newIndex].message!.flags.contains(.Incoming))
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
                let current = reversed ? total - location.index : location.index + 1
                self.controls.index.set(.single((current, total)))
            } else  {
                self.controls.index.set(.single((self.pager.currentIndex + 1, self.pager.count)))
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
        items.append(SPopoverItem(tr(L10n.galleryContextSaveAs), {[weak self] in
            self?.saveAs()
        }))
        if let _ = self.contentInteractions, case .history = type {
            items.append(SPopoverItem(tr(L10n.galleryContextShowMessage), {[weak self] in
                self?.showMessage()
            }))
        }
        items.append(SPopoverItem(tr(L10n.galleryContextCopyToClipboard), {[weak self] in
            self?.copy(nil)
        }))
        
        switch type {
        case .profile(let peerId):
            if peerId == account.peerId {
                items.append(SPopoverItem(tr(L10n.galleryContextDeletePhoto), {[weak self] in
                    self?.deletePhoto()
                }))
            }
        default:
            break
        }
        
        showPopover(for: control, with: SPopoverViewController(items: items), inset:NSMakePoint((-125 + 14),0))
    }
    
    private func deletePhoto() {
        if let item = self.pager.selectedItem {
            if let index = self.pager.index(for: item) {
                let isEmpty = pager.merge(with: UpdateTransition<MGalleryItem>(deleted: [index], inserted: [], updated: []))
                
                if isEmpty {
                    close()
                }
                
                pager.selectedIndex.set(index)
                
                if case let .photo(_, _, _, reference) = item.entry {
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
    
    
    func saveAs() -> Void {
        if let item = self.pager.selectedItem {
            if !(item is MGalleryExternalVideoItem) {
                operationDisposable.set((item.path.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] path in
                    if let strongSelf = self {
                        savePanel(file: path.nsstring.deletingPathExtension, ext: path.nsstring.pathExtension, for: strongSelf.window)
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
        backgroundView.change(opacity: 0, animated: false)
        self.readyDispose.set((self.ready.get() |> take(1) |> deliverOnMainQueue).start { [weak self] in
            if let strongSelf = self {
                strongSelf.backgroundView.change(opacity: 1, animated: animated)
                strongSelf.pager.animateIn(from: { [weak strongSelf] stableId -> NSView? in
                    if let firstStableId = strongSelf?.firstStableId, let innerIndex = stableId.base as? Int {
                        let view = strongSelf?.delegate?.contentInteractionView(for: firstStableId, animateIn: false)
                        return view?.subviews[innerIndex]
                    }
                    if ignoreStableId != stableId {
                        return strongSelf?.delegate?.contentInteractionView(for: stableId, animateIn: false)
                    }
                    return nil
                }, completion:{ [weak strongSelf] in
                    strongSelf?.controls.animateIn()
                }, addAccesoryOnCopiedView: { [weak self] stableId, view in
                    if let stableId = stableId {
                        self?.delegate?.addAccesoryOnCopiedView(for: stableId, view: view)
                    }
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
            backgroundView.change(opacity: 0, duration: 0.15, timingFunction: kCAMediaTimingFunctionSpring)
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
    }
    
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = NSTouchBar.CustomizationIdentifier(rawValue: "Gallery")
        touchBar.defaultItemIdentifiers = [.slide]
        touchBar.customizationAllowedItemIdentifiers = [.slide]
        
        return touchBar
    }
    
}

@available(OSX 10.12.2, *)
fileprivate extension NSTouchBarItem.Identifier {
    static let slide = NSTouchBarItem.Identifier("org.telegram.TouchBar.Gallery")
}

@available(OSX 10.12.2, *)
extension GalleryViewer : NSTouchBarDelegate {
    
    @available(OSX 10.12.2, *)
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        
        switch identifier {
            
        case .slide:
            
            let popoverItem = NSPopoverTouchBarItem(identifier: identifier)
            popoverItem.customizationLabel = "Font Size"
            popoverItem.collapsedRepresentationLabel = "Font Size"
            
            let secondaryTouchBar = NSTouchBar()
            secondaryTouchBar.delegate = self
            secondaryTouchBar.defaultItemIdentifiers = [.flexibleSpace];
            
            // We can setup a different NSTouchBar instance for popoverTouchBar and pressAndHoldTouchBar property
            // Here we just use the same instance.
            //
            popoverItem.pressAndHoldTouchBar = secondaryTouchBar
            popoverItem.popoverTouchBar = secondaryTouchBar
            
            return nil
            
            
        default:
            return nil
        }
    }
}

func closeGalleryViewer(_ animated: Bool) {
    viewer?.close(animated)
}

func showChatGallery(account:Account, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history, reversed: Bool = false) {
   // if viewer == nil {
    viewer?.clean()
    let gallery = GalleryViewer(account: account, message: message, delegate, contentInteractions, type: type, reversed: reversed)
    gallery.show()
    //}
}

func showGalleryFromPip(item: MGalleryItem, gallery: GalleryViewer, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history) {
   // if viewer == nil {
    viewer?.clean()
    gallery.show(true, item.stableId)
    //}
}

func showPhotosGallery(account:Account, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
  //  if viewer == nil {
    viewer?.clean()
    let gallery = GalleryViewer(account: account, peerId: peerId, firstStableId: firstStableId, delegate, contentInteractions)
    gallery.show()
  //  }
}

func showInstantViewGallery(account: Account, medias:[InstantPageMedia], firstIndex: Int, firstStableId:AnyHashable? = nil, _ delegate: InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    //if viewer == nil {
    viewer?.clean()
    let gallery = GalleryViewer(account: account, instantMedias: medias, firstIndex: firstIndex, firstStableId: firstStableId, delegate, contentInteractions)
    gallery.show()
   // }
}


func showSecureIdDocumentsGallery(account: Account, medias:[SecureIdDocumentValue], firstIndex: Int, _ delegate: InteractionContentViewProtocol? = nil) {
    viewer?.clean()
    let gallery = GalleryViewer(account: account, secureIdMedias: medias, firstIndex: firstIndex, delegate)
    gallery.show()
}

