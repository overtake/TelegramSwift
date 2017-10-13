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
    var previous:()->KeyHandlerResult = { return .rejected}
    var showActions:(Control)->KeyHandlerResult = {_ in return .rejected}
    var contextMenu:()->NSMenu? = {return nil}
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
            if file.mimeType.hasPrefix("image/") || file.isVideo {
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


fileprivate func prepareEntries(from:[ChatHistoryEntry]?, to:[ChatHistoryEntry], account:Account, pagerSize:NSSize) -> Signal<UpdateTransition<MGalleryItem>, Void> {
    return Signal { subscriber in
        
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> MGalleryItem in
            switch entry {
            case let .MessageEntry(message, _, _, _, _):
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
    
}

class GalleryViewer: NSResponder {
    
    fileprivate var viewCache:[AnyHashable: NSView] = [:]
    
    private var window:Window
    private var controls:GalleryControls!
    private let pager:GalleryPageController
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
    let contentInteractions:ChatMediaGalleryParameters?
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    let type:GalleryAppearType
    
    private init(account:Account, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil, type: GalleryAppearType) {
        self.account = account
        self.delegate = delegate
        self.type = type
        self.contentInteractions = contentInteractions
        if let screen = NSScreen.main {
            let bounds = NSMakeRect(0, 0, screen.frame.width, screen.frame.height)
            self.window = Window(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            self.window.contentView?.wantsLayer = true
            
            self.window.level = .screenSaver
            self.window.isOpaque = false
            self.window.backgroundColor = .clear
            
            backgroundView.backgroundColor = .blackTransparent
            backgroundView.frame = bounds
            
            self.pager = GalleryPageController(frame: bounds, contentInset:NSEdgeInsets(left: 0, right: 0, top: 0, bottom: 95), interactions:interactions, window:window)
        } else {
            fatalError("main screen not found for MediaViewer")
        }
        
        super.init()
        
        window.set(responder: { [weak self] () -> NSResponder? in
            return self
        }, with: self, priority: .high)
        
        interactions.dismiss = { [weak self] () -> KeyHandlerResult in
            if let pager = self?.pager {
                if pager.isFullScreen {
                    return .invokeNext
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
        
        interactions.showActions = { [weak self] control -> KeyHandlerResult in
            self?.showControlsPopover(control)
            return .invoked
        }
        
        interactions.contextMenu = {[weak self] in
            return self?.contextMenu
        }
        
        window.set(handler: interactions.dismiss, with:self, for: .Space)
        window.set(handler: interactions.dismiss, with:self, for: .Escape)
        
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
             self.controls = GalleryGeneralControls(View(frame:NSMakeRect(0, 10, 400, 75)), interactions:interactions)
        }

        self.pager.view.addSubview(self.backgroundView)
        self.window.contentView?.addSubview(self.pager.view)
        self.window.contentView?.addSubview(self.controls.view!)
    }
    
    var pagerSize: NSSize {
        return NSMakeSize(pager.frame.size.width - pager.contentInset.right - pager.contentInset.left, pager.frame.size.height - pager.contentInset.bottom - pager.contentInset.top)
    }
    
    fileprivate convenience init(account:Account, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil) {
        self.init(account: account, delegate, contentInteractions, type: .profile(peerId))

        let pagerSize = self.pagerSize
        
        ready.set(account.postbox.modify { modifier -> Peer? in
            return modifier.getPeer(peerId)
        } |> deliverOnMainQueue |> map { [weak self] peer -> Bool in
            if let peer = peer {
                var representations:[TelegramMediaImageRepresentation] = []
                if let representation = peer.smallProfileImage {
                    representations.append(representation)
                }
                if let representation = peer.largeProfileImage {
                    representations.append(representation)
                }
                let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 0), representations: representations)
                
                _ = self?.pager.merge(with: UpdateTransition(deleted: [], inserted: [(0,MGalleryPeerPhotoItem(account, .photo(index: 0, stableId: firstStableId, photo: image, reference: .none), pagerSize))], updated: []))
                
                self?.controls.index.set(.single((1,1)))
                self?.pager.set(index: 0, animated: false)
                
                return true
            }
            return false
        })

        var totalCount:Int = 1
        
        self.disposable.set((requestPeerPhotos(account: account, peerId: peerId) |> map { photos -> (UpdateTransition<MGalleryItem>, Int) in
            
            var inserted:[(Int, MGalleryItem)] = []
            var updated:[(Int, MGalleryItem)] = []
            let deleted:[Int] = []
            if !photos.isEmpty {
                updated.append((0, MGalleryPeerPhotoItem(account, .photo(index: photos[0].index, stableId: firstStableId, photo: photos[0].image, reference: photos[0].reference), pagerSize)))
                for i in 1 ..< photos.count {
                    inserted.append((i, MGalleryPeerPhotoItem(account, .photo(index: photos[i].index, stableId: photos[i].image.imageId, photo: photos[i].image, reference: photos[i].reference), pagerSize)))
                }
            }
            return (UpdateTransition(deleted: deleted, inserted: inserted, updated: updated), max(0, photos.count))
            
        } |> deliverOnMainQueue).start(next: { [weak self] transition, total in
            totalCount = total
            self?.controls.index.set(.single((1,max(totalCount, 1))))
            _ = self?.pager.merge(with: transition)
            
        }))
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] (selectedIndex) in
            if let strongSelf = self {
                self?.controls.index.set(.single((selectedIndex + 1, strongSelf.pager.count)))
            }
        }))
    }
    
    fileprivate convenience init(account:Account, instantMedias:[InstantPageMedia], firstIndex:Int, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil) {
        self.init(account: account, delegate, contentInteractions, type: .history)
        
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
    
   
    
    fileprivate convenience init(account:Account, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil, type: GalleryAppearType = .history, item: MGalleryItem? = nil) {
        
        self.init(account: account, delegate, contentInteractions, type: type)

       
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
                
                let tags = tagsForMessage(message)
                let pullCount = tags != nil ? 50 : 1
                let view = account.viewTracker.aroundIdMessageHistoryViewForPeerId(message.id.peerId, count: pullCount, messageId: index.id, tagMask: tags, orderStatistics: [.combinedLocation])
            
                switch type {
                case .alone:
                    let entries:[ChatHistoryEntry] = [.MessageEntry(message, false, .Full(isAdmin: false), nil, nil)]
                    let previous = previous.swap(entries)
                    return prepareEntries(from: previous, to: entries, account: account, pagerSize: pagerSize) |> map { transition  in
                        return (transition,previous, entries)
                        } |> deliverOnMainQueue
                case .history:
                    return view |> mapToQueue { view, _, _ -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), Void> in
                        let entries:[ChatHistoryEntry] = messageEntries(view.entries, includeHoles : false)
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
                            entries.append(.MessageEntry(message, false, .Full(isAdmin: false), nil, nil))
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
                    _ = current.swap(new)
                    
                    var id:MessageId = message.id
                    let index = currentIndex.modify({$0})
                    if let index = index {
                        id = previous[index].message!.id
                    }

                    
                    for i in 0 ..< new.count {
                        if let message = new[i].message {
                            if message.id == id {
                                _ = currentIndex.swap(i)
                            }
                        }
                    }
                    
                    
                    
                    let isEmpty = strongSelf.pager.merge(with: transition)
                    if !isEmpty {
                        if let newIndex = currentIndex.modify({$0}) {                           
                            strongSelf.pager.selectedIndex.set(newIndex)
                            strongSelf.pager.set(index: newIndex, animated: false)
                            if let attribute = new[newIndex].message?.autoremoveAttribute {
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
            
            let current = entries[selectedIndex]
            if let location = current.location {
                self?.controls.index.set(.single((location.index + 1, location.count)))
            } else {
                self?.controls.index.set(.single((1,1)))
            }
            
            
            if let message = entries[selectedIndex].message, message.containsSecretMedia {
                _ = (markMessageContentAsConsumedInteractively(postbox: account.postbox, messageId: message.id) |> delay(0.5, queue: Queue.concurrentDefaultQueue())).start()
            }
            let indexes = indexes.modify({$0})
            
            if let pagerIndex = currentIndex.modify({$0}) {
                if selectedIndex < pagerIndex && pagerIndex < reqlimit, let earlier = indexes.earlierId {
                    request.set(.single(earlier))
                } else if selectedIndex > pagerIndex && pagerIndex > entries.count - reqlimit, let later = indexes.laterId {
                    request.set(.single(later))
                }
            }
            _ = currentIndex.swap(selectedIndex)
            
            
        }))
        
        request.set(.single(MessageIndex(message)))

    }
    
    
    
    func showControlsPopover(_ control:Control) {
        var items:[SPopoverItem] = []
        items.append(SPopoverItem(tr(.galleryContextSaveAs), {[weak self] in
            self?.saveAs()
        }))
        if let _ = self.contentInteractions, case .history = type {
            items.append(SPopoverItem(tr(.galleryContextShowMessage), {[weak self] in
                self?.showMessage()
            }))
        }
        items.append(SPopoverItem(tr(.galleryContextCopyToClipboard), {[weak self] in
            self?.copy(nil)
        }))
        
        switch type {
        case .profile(let peerId):
            if peerId == account.peerId {
                items.append(SPopoverItem(tr(.galleryContextDeletePhoto), {[weak self] in
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
                
                pager.selectedIndex.set(index - 1)
                
                if case let .photo(_, _, _, reference) = item.entry {
                    _ = removeUserPhoto(account: account, reference: index == 0 ? .none : reference).start()
                }
            }
            
        }
    }
    
    
    var contextMenu:NSMenu {
        let menu = NSMenu()
        
        if let item = self.pager.selectedItem {
            if !(item is MGalleryExternalVideoItem) {
                menu.addItem(ContextMenuItem(tr(.galleryContextSaveAs), handler: { [weak self] in
                    self?.saveAs()
                }))
            }
            
            if let _ = self.contentInteractions {
                menu.addItem(ContextMenuItem(tr(.galleryContextShowMessage), handler: { [weak self] in
                    self?.showMessage()
                }))
            }
            menu.addItem(ContextMenuItem(tr(.galleryContextCopyToClipboard), handler: { [weak self] in
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
        window.makeFirstResponder(self)
        //closePipVideo()
        backgroundView.change(opacity: 0, animated: false)
        self.readyDispose.set((self.ready.get() |> take(1) |> deliverOnMainQueue).start { [weak self] in
            if let strongSelf = self {
                strongSelf.backgroundView.change(opacity: 1, animated: animated)
                strongSelf.pager.animateIn(from: { [weak strongSelf] stableId -> NSView? in
                    if ignoreStableId != stableId {
                        return strongSelf?.delegate?.contentInteractionView(for: stableId)
                    }
                    return nil
                }, completion:{ [weak strongSelf] in
                    strongSelf?.controls.animateIn()
                })
                strongSelf.window.makeKeyAndOrderFront(nil)
            }
        });
        
    }
    
    func close(_ animated:Bool = false) -> Void {
        disposable.dispose()
        readyDispose.dispose()
        didSetReady = false
        
        if animated {
            backgroundView.change(opacity: 0, duration: 0.15, timingFunction: kCAMediaTimingFunctionSpring)
            controls.animateOut()
            self.pager.animateOut(to: {[weak self] (stableId) -> NSView? in
                return self?.delegate?.contentInteractionView(for: stableId)
            }, completion: { [weak self] in
                self?.window.orderOut(nil)
                viewer = nil
                playPipIfNeeded()
            })
        } else {
            window.orderOut(nil)
            viewer = nil
            playPipIfNeeded()
        }
        
    }
    
    deinit {
        indexDisposable.dispose()
        disposable.dispose()
        operationDisposable.dispose()
        window.removeAllHandlers(for: self)
        readyDispose.dispose()
    }
}

func closeGalleryViewer(_ animated: Bool) {
    viewer?.close(animated)
}

func showChatGallery(account:Account, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil, type: GalleryAppearType = .history) {
    if viewer == nil {
        let gallery = GalleryViewer(account: account, message: message, delegate, contentInteractions, type: type)
        gallery.show()
    }
}

func showGalleryFromPip(item: MGalleryItem, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaGalleryParameters? = nil, type: GalleryAppearType = .history) {
    if viewer == nil, let message = item.entry.message {
        let gallery = GalleryViewer(account: item.account, message: message, delegate, contentInteractions, type: type, item: item)
        gallery.show(true, item.stableId)
    }
}

func showPhotosGallery(account:Account, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil) {
    if viewer == nil {
        let gallery = GalleryViewer(account: account, peerId: peerId, firstStableId: firstStableId, delegate, contentInteractions)
        gallery.show()
    }
}

func showInstantViewGallery(account: Account, medias:[InstantPageMedia], firstIndex: Int, _ delegate: InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaGalleryParameters? = nil) {
    if viewer == nil {
        let gallery = GalleryViewer(account: account, instantMedias: medias, firstIndex: firstIndex, delegate, contentInteractions)
        gallery.show()
    }
}

