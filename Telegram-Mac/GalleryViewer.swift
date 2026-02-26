//
//  MediaViewer.swift
//  Telegram-Mac
//
//  Created by keepcoder on 06/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import TGUIKit
import TelegramCore
import InAppSettings
import Postbox
import AVFoundation
import ColorPalette
import Translate
import TelegramMediaPlayer
import TelegramMedia

final class GalleryInteractions {
    var dismiss:(NSEvent)->KeyHandlerResult = { _ in return .rejected}
    var next:(NSEvent)->KeyHandlerResult = { _ in return .rejected}
    var select:(MGalleryItem)->Void = { _ in}
    var previous:(NSEvent)->KeyHandlerResult = { _ in return .rejected}
    var showActions:(Control)->KeyHandlerResult = {_ in return .rejected}
    var share:(Control)->Void = { _ in }
    var contextMenu:()->ContextMenu? = {return nil}
    var openInfo:(PeerId)->Void = {_ in}
    var openMessage:()->Void = {}
    var showThumbsControl:(View, Bool)->Void = {_, _ in}
    var hideThumbsControl:(View, Bool)->Void = {_, _ in}
    
    var zoomIn:()->Void = {}
    var zoomOut:()->Void = {}
    var rotateLeft:()->Void = {}
    
    var fastSave:()->Void = {}
    
    var canShare:()->Bool = { true }
    
    var invokeAd:(PeerId, AdMessageAttribute)->Void = { _, _ in }
}
private(set) var viewer:GalleryViewer?

func getGalleryViewer() -> GalleryViewer? {
    return viewer
}


let galleryButtonStyle = ControlStyle(font:.medium(.huge), foregroundColor:.white, backgroundColor:.clear, highlightColor:.grayIcon)


private func tagsForMessage(_ message: Message) -> MessageTags? {
    for media in message.media {
        switch media {
        case _ as TelegramMediaImage:
            return .photoOrVideo
        case let file as TelegramMediaFile:
            if file.isVideo && file.isAnimated {
                return nil
            } else if file.isVideo && !file.isAnimated {
                return .photoOrVideo
            } else if file.isVoice {
                return .voiceOrInstantVideo
            } else if file.isStaticSticker || (file.isVideo && file.isAnimated) {
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


enum GalleryAppearType : Equatable {
    case alone
    case history
    case profile(PeerId)
    case secret
    case recentDownloaded
    case messages([Message])
}

private func mediaForMessage(message: Message, postbox: Postbox) -> Media? {
    for media in message.media {
        if let media = media as? TelegramMediaInvoice, let extended = media.extendedMedia {
            switch extended {
            case .preview:
                return nil
            case let .full(media):
                return media
            }
        }
        if let media = media as? TelegramMediaAction {
            switch media.action {
            case let .suggestedProfilePhoto(image):
                return image
            case let .photoUpdated(image):
                return image
            default:
                return nil
            }
        }
        if let media = media as? TelegramMediaImage {
            return media
        } else if let file = media as? TelegramMediaFile {
            if file.isGraphicFile || file.isVideo || file.isAnimated {
                return file
            } else if file.isVideoFile, FileManager.default.fileExists(atPath: postbox.mediaBox.resourcePath(file.resource)) {
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

fileprivate func itemFor(entry: ChatHistoryEntry, context: AccountContext, pagerSize: NSSize) -> MGalleryItem {
    switch entry {
    case let .MessageEntry(message, _, _, _, _, _, _):
        if let media = mediaForMessage(message: message, postbox: context.account.postbox) {
            if let _ = media as? TelegramMediaImage {
                return MGalleryPhotoItem(context, .message(entry), pagerSize)
            } else if let file = media as? TelegramMediaFile {
                if (file.isVideo && !file.isAnimated) {
                    return MGalleryVideoItem(context, .message(entry), pagerSize)
                } else {
                    if file.mimeType.hasPrefix("image/") {
                        return MGalleryPhotoItem(context, .message(entry), pagerSize)
                    } else if file.isVideo && file.isAnimated {
                        return MGalleryGIFItem(context, .message(entry), pagerSize)
                    } else if file.isVideoFile {
                        return MGalleryVideoItem(context, .message(entry), pagerSize)
                    }
                }
            }
        } else if !message.media.isEmpty, let webpage = message.media[0] as? TelegramMediaWebpage {
            if case let .Loaded(content) = webpage.content {
                if ExternalVideoLoader.isPlayable(content) {
                    return MGalleryExternalVideoItem(context, .message(entry), pagerSize)
                }
            }
        }
    default:
        break
    }
    
    return MGalleryItem(context, .message(entry), pagerSize)
}

fileprivate func prepareEntries(from:[ChatHistoryEntry]?, to:[ChatHistoryEntry], context: AccountContext, pagerSize:NSSize) -> Signal<UpdateTransition<MGalleryItem>, NoError> {
    return Signal { subscriber in
        
        let (removed, inserted, updated) = proccessEntriesWithoutReverse(from, right: to, { (entry) -> MGalleryItem in
           return itemFor(entry: entry, context: context, pagerSize: pagerSize)
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

final class GalleryBackgroundView : NSView {
    
    deinit {
        var bp:Int = 0
        bp += 1
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
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}


class GalleryViewer: NSResponder {
    
    
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
    private let context:AccountContext
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
    let chatMode: ChatMode?
    let chatLocation: ChatLocation?
    private let reversed: Bool
    
    private var liveTranslate: ChatLiveTranslateContext?
    
    private init(context: AccountContext, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType, reversed:Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?) {
        self.context = context
        self.delegate = delegate
        self.type = type
        self.chatMode = chatMode
        self.chatLocation = chatLocation
        self.reversed = reversed
        self.contentInteractions = contentInteractions
        if let screen = NSScreen.main {
            let bounds = NSMakeRect(0, 0, screen.frame.width, screen.frame.height)
            self.window = Window(contentRect: bounds, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
            self.window.contentView?.wantsLayer = true

            self.window.level = .popUpMenu
            self.window.isOpaque = false
            self.window.backgroundColor = .clear
          //  self.window.appearance = theme.appearance
            backgroundView.wantsLayer = true
            backgroundView.background = NSColor.black.withAlphaComponent(0.9)
            backgroundView.frame = bounds
            
            var topInset: CGFloat = 0
            
            if #available(macOS 12.0, *) {
                topInset = screen.safeAreaInsets.top
            }
            
            self.pager = GalleryPageController(frame: bounds, contentInset:NSEdgeInsets(left: 0, right: 0, top: topInset, bottom: 95), interactions:interactions, window:window, reversed: reversed)
            //, selectedItemChanged: selectedItemChanged, transition: transition
            self.touchbarController = GalleryTouchBarController(interactions: interactions, selectedItemChanged: pager.selectedItemChanged, transition: pager.transition)
            self.window.rootViewController = touchbarController

        } else {
            fatalError("main screen not found for MediaViewer")
        }
        
        
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey), name: NSWindow.didBecomeKeyNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidResignKey), name: NSWindow.didResignKeyNotification, object: window)
        
        
        interactions.dismiss = { [weak self] _ -> KeyHandlerResult in
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
        
        interactions.next = { [weak self] _ -> KeyHandlerResult in
            self?.pager.next()
            return .invoked
        }
        
        interactions.previous = { [weak self] _ -> KeyHandlerResult in
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
        
        interactions.invokeAd = { [weak self] peerId, adAttribute in
            
            guard let self else {
                return
            }
            self.close()
            closeAllModals(window: self.window)
            
            let link: inAppLink = inApp(for: adAttribute.url.nsstring, context: context, openInfo: { [weak self] peerId, toChat, messageId, action in
                self?.openInfo(peerId, toChat, messageId, action)
            })
            execute(inapp: link)
            
            context.engine.messages.markAdAction(opaqueId: adAttribute.opaqueId, media: true, fullscreen: true)
        }
        interactions.canShare = { [weak self] in
            let isProtected = self?.pager.selectedItem?.entry.message?.isCopyProtected() ?? false
            if isProtected {
                return false
            } else if let chatMode = chatMode {
                return !chatMode.isSavedMode && chatMode.customChatContents == nil
            } else {
                return false
            }
        }
        window.set(handler: { [weak self] event in
            guard let `self` = self else {return .rejected}
            if self.pager.selectedItem is MGalleryVideoItem || self.pager.selectedItem is MGalleryExternalVideoItem {
                self.pager.selectedItem?.togglePlayerOrPause()
                return .invoked
            } else {
                return self.interactions.dismiss(event)
            }
        }, with:self, for: .Space)
        
        window.set(handler: { [weak self] event in
            guard let `self` = self else {return .rejected}
            self.pager.toggleFullScreen()
            return .invoked
        }, with:self, for: .F)
        
        window.set(handler: interactions.dismiss, with:self, for: .Escape)
        
        window.closeInterceptor = { [weak self] in
            if let event = NSApp.currentEvent {
                _ = self?.interactions.dismiss(event)
            }
            return true
        }
        
        window.set(handler: interactions.next, with:self, for: .RightArrow)
        window.set(handler: interactions.previous, with:self, for: .LeftArrow)
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.pager.zoomOut()
            return .invoked
        }, with: self, for: .Minus)
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.pager.zoomIn()
            return .invoked
        }, with: self, for: .Equal)
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.pager.decreaseSpeed()
            return .invoked
        }, with: self, for: .Minus, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.pager.increaseSpeed()
            return .invoked
        }, with: self, for: .Equal, modifierFlags: [.command, .option])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.pager.rotateLeft()
            return .invoked
        }, with: self, for: .R, modifierFlags: [.command])
        
        window.set(handler: { [weak self] _ -> KeyHandlerResult in
            self?.saveAs()
            return .invoked
        }, with: self, for: .S, priority: .high, modifierFlags: [.command])
        
        window.copyhandler = { [weak self] in
            self?.copy(nil)
        }
        window.masterCopyhandler = { [weak self] in
            self?.copy(nil)
        }
        
        window.firstResponderFilter = { responder in
            return responder
        }
        
        self.controls = GalleryModernControls(context, interactions: interactions, frame: NSMakeRect(0, -150, window.frame.width, 150), thumbsControl: pager.thumbsControl)
        

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
    
    fileprivate convenience init(context: AccountContext, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, reversed:Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?) {
        self.init(context: context, delegate, contentInteractions, type: .profile(peerId), reversed: reversed, chatMode: chatMode, chatLocation: chatLocation)

        let pagerSize = self.pagerSize
        
        let previous: Atomic<[GalleryEntry]> = Atomic(value: [])
        
        let transaction: Signal<(UpdateTransition<MGalleryItem>, Int), NoError> = peerPhotosGalleryEntries(context: context, peerId: peerId, firstStableId: firstStableId) |> map { (entries, selected, publicPhoto) in
            let (deleted, inserted, updated) = proccessEntriesWithoutReverse(previous.swap(entries), right: entries, { entry -> MGalleryItem in
                switch entry {
                case let .photo(_, _, photo, _, _, _, _, _, _):
                    if !photo.videoRepresentations.isEmpty {
                        return MGalleryGIFItem(context, entry, pagerSize)
                    } else {
                        return MGalleryPeerPhotoItem(context, entry, pagerSize)
                    }
                default:
                    preconditionFailure()
                }
            })
            return (UpdateTransition(deleted: deleted, inserted: inserted, updated: updated), selected)
        } |> deliverOnMainQueue
        
        
        disposable.set(transaction.start(next: { [weak self] transaction, selected in
            _ = self?.pager.merge(with: transaction, afterTransaction: {
                self?.controls.update(self?.pager.selectedItem)
            })
            self?.pager.selectedIndex.set(selected)
            self?.pager.set(index: selected, animated: false)
            self?.ready.set(.single(true))

        }))
   
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem)
        }))
    }
    
    fileprivate convenience init(context: AccountContext, instantMedias:[InstantPageMedia], firstIndex:Int, firstStableId: AnyHashable? = nil, parent: Message? = nil, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, reversed: Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?) {
        self.init(context: context, delegate, contentInteractions, type: .history, reversed: reversed, chatMode: chatMode, chatLocation: chatLocation)
        self.firstStableId = firstStableId
        let pagerSize = self.pagerSize
        

        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            
            guard let `self` = self else {return false}
            
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< instantMedias.count {
                let media = instantMedias[i]
                if media.media is TelegramMediaImage {
                    inserted.append((media.index, MGalleryPhotoItem(context, .instantMedia(media, parent), pagerSize)))
                } else if let file = media.media as? TelegramMediaFile {
                    if file.isVideo && file.isAnimated {
                        inserted.append((media.index, MGalleryGIFItem(context, .instantMedia(media, parent), pagerSize)))
                    } else if file.isVideo {
                        inserted.append((media.index, MGalleryVideoItem(context, .instantMedia(media, parent), pagerSize)))
                    }
                } else if media.media is TelegramMediaWebpage {
                    inserted.append((media.index, MGalleryExternalVideoItem(context, .instantMedia(media, parent), pagerSize)))
                }
            }
            
            _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            //self?.controls.index.set(.single((firstIndex + 1, totalCount)))
            self.pager.set(index: firstIndex, animated: false)
            self.controls.update(self.pager.selectedItem)
            return true
            
        })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem)
        }))
    }
    
    fileprivate convenience init(context: AccountContext, media:[Media], firstIndex: Int, firstStableId: AnyHashable? = nil, parent: Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
        self.init(context: context, delegate, contentInteractions, type: .history, reversed: false, chatMode: nil, chatLocation: nil)
        self.firstStableId = firstStableId
        let pagerSize = self.pagerSize
        

        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            
            guard let `self` = self else {return false}
            
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< media.count {
                let media = media[i]
                if media is TelegramMediaImage {
                    inserted.append((i, MGalleryPhotoItem(context, .media(media, i, parent), pagerSize)))
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo && file.isAnimated {
                        inserted.append((i, MGalleryGIFItem(context, .media(media, i, parent), pagerSize)))
                    } else if file.isVideo {
                        inserted.append((i, MGalleryVideoItem(context, .media(media, i, parent), pagerSize)))
                    }
                }
            }
            _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            self.pager.set(index: firstIndex, animated: false)
            self.controls.update(self.pager.selectedItem)
            return true
            
        })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem)
        }))
        
        
    }
    
    
    fileprivate convenience init(context: AccountContext, secureIdMedias:[SecureIdDocumentValue], firstIndex:Int, _ delegate:InteractionContentViewProtocol? = nil, reversed:Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?) {
        self.init(context: context, delegate, nil, type: .history, reversed: reversed, chatMode: chatMode, chatLocation: chatLocation)
        
        let pagerSize = self.pagerSize
        
        
        
        ready.set(.single(true) |> map { [weak self] _ -> Bool in
            guard let `self` = self else {return false}
            var inserted: [(Int, MGalleryItem)] = []
            for i in 0 ..< secureIdMedias.count {
                let media = secureIdMedias[i]
                inserted.append((i, MGalleryPhotoItem(context, .secureIdDocument(media, i), pagerSize)))

            }
            
            _ = self.pager.merge(with: UpdateTransition(deleted: [], inserted: inserted, updated: []))
            
            self.pager.set(index: firstIndex, animated: false)
            self.controls.update(self.pager.selectedItem)
            return true
            
            })
        
        self.indexDisposable.set((pager.selectedIndex.get() |> deliverOnMainQueue).start(next: { [weak self] selectedIndex in
            guard let `self` = self else {return}
            self.controls.update(self.pager.selectedItem)
        }))
        
        
    }
   
    
    fileprivate convenience init(context: AccountContext, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history, item: MGalleryItem? = nil, reversed: Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?, contextHolder: Atomic<ChatLocationContextHolder?> = Atomic(value: nil)) {
        
        self.init(context: context, delegate, contentInteractions, type: type, reversed: reversed, chatMode: chatMode, chatLocation: chatLocation)

        let chatMode = self.chatMode
        let chatLocation = self.chatLocation
        let previous:Atomic<[ChatHistoryEntry]> = Atomic(value:[])
        let current:Atomic<[ChatHistoryEntry]> = Atomic(value:[])
        let currentIndex:Atomic<Int?> = Atomic(value:nil)
        let request:Promise<MessageIndex> = Promise()
        let pagerSize = self.pagerSize
        let indexes:Atomic<(earlierId: MessageIndex?, laterId: MessageIndex?)> = Atomic(value:(nil, nil))
        
        
        self.liveTranslate = .init(peerId: message.id.peerId, context: context)

        
        if let item = item, let entry = item.entry.chatEntry {
            _ = current.swap([entry])
            
            let transition: UpdateTransition<MGalleryItem> = UpdateTransition(deleted: [], inserted: [(0, item)], updated: [])
            
            _ = pager.merge(with: transition)
            ready.set(.single(true))
        }
        
        let translate: Signal<ChatLiveTranslateContext.State?, NoError>
        if let liveTranslate {
            translate = liveTranslate.state |> map(Optional.init)
        } else {
            translate = .single(nil)
        }
        
        let signal = combineLatest(request.get() |> distinctUntilChanged, translate |> distinctUntilChanged)
            |> mapToSignal { index, translate -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                
                var type = type
                let tags: HistoryViewInputTag? = tagsForMessage(message).flatMap { .tag($0) }
                if tags == nil {
                   type = .alone
                }
                let mode: ChatMode = chatMode ?? .history
                let chatLocation = chatLocation ?? .peer(message.id.peerId)
                
                let signal:Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
                switch mode {
                case .history, .preview:
                    signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(peerId: message.id.peerId, threadId: nil), count: 50, ignoreRelatedChats: false, messageId: index.id, tag: tags, orderStatistics: [.combinedLocation], additionalData: [])
                case .thread:
                    if case let .thread(data) = chatLocation {
                        if case let .thread(data) = chatLocation, data.effectiveTopId == message.id {
                            signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(peerId: message.id.peerId, threadId: nil), count: 50, ignoreRelatedChats: false, messageId: index.id, tag: tags, orderStatistics: [.combinedLocation], additionalData: [])
                        } else {
                            signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(context.chatLocationInput(for: .thread(data), contextHolder: contextHolder), count: 50, ignoreRelatedChats: false, messageId: index.id, tag: tags, orderStatistics: [.combinedLocation], additionalData: [])
                        }
                    } else {
                        signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(peerId: message.id.peerId, threadId: nil), count: 50, ignoreRelatedChats: false, messageId: index.id, tag: tags, orderStatistics: [.combinedLocation], additionalData: [])
                    }
                case .pinned:
                    signal = context.account.viewTracker.aroundIdMessageHistoryViewForLocation(.peer(peerId: message.id.peerId, threadId: nil), count: 50, ignoreRelatedChats: false, messageId: index.id, tag: .tag(.pinned), orderStatistics: [.combinedLocation], additionalData: [])
                case .scheduled:
                    signal = context.account.viewTracker.scheduledMessagesViewForLocation(.peer(peerId: message.id.peerId, threadId: nil))
                case let .customChatContents(contents):
                    signal = contents.historyView |> map { view in
                        return (MessageHistoryView(tag: nil, namespaces: .all, entries: view.0.entries, holeEarlier: false, holeLater: false, isLoading: false), ViewUpdateType.Generic, nil)
                    }
                case .customLink:
                    signal = .complete()
                }

            
                switch type {
                case .alone:
                    
                    
                    let message = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Messages.Message(id: message.id)) |> map {
                        $0?._asMessage()
                    }
                    return message |> map { message in
                        if let message {
                            let entries:[ChatHistoryEntry] = [.MessageEntry(message, MessageIndex(message), false, .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings))]
                            let previous = previous.swap(entries)
                            
                            var inserted: [(Int, MGalleryItem)] = []
                            
                            inserted.insert((0, itemFor(entry: entries[0], context: context, pagerSize: pagerSize)), at: 0)

                            if let webpage = message.anyMedia as? TelegramMediaWebpage {
                                let instantMedias = instantPageMedias(for: webpage)
                                if instantMedias.count > 1 {
                                    for i in 1 ..< instantMedias.count {
                                        let media = instantMedias[i]
                                        if media.media is TelegramMediaImage {
                                            inserted.append((i, MGalleryPhotoItem(context, .instantMedia(media, message), pagerSize)))
                                        } else if let file = media.media as? TelegramMediaFile {
                                            if file.isVideo && file.isAnimated {
                                                inserted.append((i, MGalleryGIFItem(context, .instantMedia(media, message), pagerSize)))
                                            } else if file.isVideo || file.isVideoFile {
                                                inserted.append((i, MGalleryVideoItem(context, .instantMedia(media, message), pagerSize)))
                                            }
                                        } else if media.media is TelegramMediaWebpage {
                                            inserted.append((i, MGalleryExternalVideoItem(context, .instantMedia(media, message), pagerSize)))
                                        }
                                    }
                                }
                            }
                            return (UpdateTransition(deleted: [], inserted: inserted, updated: []), previous, entries)
                        } else {
                            return (UpdateTransition(deleted: [0], inserted: [], updated: []), previous.with { $0 }, [])
                        }
                        
                    } |> deliverOnMainQueue
                    
                case .history:
                    return signal |> mapToSignal { view, _, _ -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                        let entries:[ChatHistoryEntry] = messageEntries(view.entries, includeHoles : false, translate: translate, contentConfig: context.contentConfig).filter { entry -> Bool in
                            switch entry {
                            case let .MessageEntry(message, _, _, _, _, _, _):
                                var firstCheck = message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia && mediaForMessage(message: message, postbox: context.account.postbox) != nil
                                
                                if !firstCheck {
                                    return false
                                }
                                if let peer = message.peers[message.id.peerId] {
                                    if let group = peer as? TelegramGroup {
                                        if group.membership == .Removed {
                                            switch group.role {
                                            case .creator:
                                                return true
                                            case .admin:
                                                return true
                                            case .member:
                                                return false
                                            }
                                        }
                                    }
                                    if let group = peer as? TelegramChannel {
                                        switch group.participationStatus {
                                        case .member, .left:
                                            return true
                                        default:
                                            return group.isAdmin
                                        }
                                    }
                                }
                                
                                return true
                            default:
                                return true
                            }
                        }
                        let previous = previous.with {$0}
                        return prepareEntries(from: previous, to: entries, context: context, pagerSize: pagerSize) |> deliverOnMainQueue |> map { transition in
                            _ = indexes.swap((view.earlierId, view.laterId))
                            return (transition,previous, entries)
                        }
                    }
                case .recentDownloaded:
                    return recentDownloadItems(postbox: context.account.postbox) |> mapToSignal { downloaded in
                        let messages = downloaded.map {
                            $0.message
                        }.map {
                            MessageHistoryEntry(message: $0, isRead: true, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))
                        }
                        let entries:[ChatHistoryEntry] = messageEntries(messages, includeHoles : false, contentConfig: context.contentConfig).filter { entry -> Bool in
                            switch entry {
                            case let .MessageEntry(message, _, _, _, _, _, _):
                                return message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia && mediaForMessage(message: message, postbox: context.account.postbox) != nil
                            default:
                                return true
                            }
                        }
                        let previous = previous.with {$0}
                        return prepareEntries(from: previous, to: entries, context: context, pagerSize: pagerSize) |> deliverOnMainQueue |> map { transition in
                            return (transition,previous, entries)
                        }
                        
                    }
                case .secret:
                    return context.account.postbox.messageView(index.id) |> mapToSignal { view -> Signal<(UpdateTransition<MGalleryItem>, [ChatHistoryEntry], [ChatHistoryEntry]), NoError> in
                        var entries:[ChatHistoryEntry] = []
                        if let message = view.message, !(message.anyMedia is TelegramMediaExpiredContent) {
                            entries.append(.MessageEntry(message, MessageIndex(message), false, .list, .Full(rank: nil, header: .normal), nil, ChatHistoryEntryData(nil, MessageEntryAdditionalData(), AutoplayMediaPreferences.defaultSettings)))
                        }
                        let previous = previous.with {$0}
                        return prepareEntries(from: previous, to: entries, context: context, pagerSize: pagerSize) |> map { transition in
                            return (transition,previous, entries)
                        }
                    }
                case .profile:
                    return .complete()
                case let .messages(messages):
                    let messages = messages.map {
                        MessageHistoryEntry(message: $0, isRead: true, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false))
                    }
                    let entries:[ChatHistoryEntry] = messageEntries(messages, includeHoles : false, contentConfig: context.contentConfig).filter { entry -> Bool in
                        switch entry {
                        case let .MessageEntry(message, _, _, _, _, _, _):
                            return message.id.peerId.namespace == Namespaces.Peer.SecretChat || !message.containsSecretMedia && mediaForMessage(message: message, postbox: context.account.postbox) != nil
                        default:
                            return true
                        }
                    }
                    let previous = previous.with {$0}
                    return prepareEntries(from: previous, to: entries, context: context, pagerSize: pagerSize) |> deliverOnMainQueue |> map { transition in
                        return (transition,previous, entries)
                    }
                }
              
            }  |> deliverOnMainQueue
            |> map { [weak self] transition, prev, new in
                if let strongSelf = self {
                    
                    _ = previous.swap(new)
                    
                    let new = reversed ? new.reversed() : new
                    
                    _ = current.swap(new)
                    
                    var id:MessageId = message.id
                    let index = currentIndex.modify({$0})
                    if let index = index, prev.count > index {
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
            
            guard let `self` = self, entries.count > 0 else {return}
            
            let current = entries[selectedIndex]
            if let location = current.location {
                let total = location.count
                let current = reversed ? total - location.index : location.index
                self.controls.update(self.pager.selectedItem)
            } else  {
                self.controls.update(self.pager.selectedItem)
            }
            
            
            if let message = entries[selectedIndex].message, message.containsSecretMedia {
                _ = (context.engine.messages.markMessageContentAsConsumedInteractively(messageId: message.id) |> delay(0.5, queue: Queue.concurrentDefaultQueue())).start()
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
    

    private func showControlsPopoverReady(_ control: Control, savedGifs: [RecentMediaItem]) {
        
        var items:[ContextMenuItem] = []
        
        let isProtected = pager.selectedItem?.entry.isProtected == true
        var keepSaveAs: Bool = true
        let context = self.context
        
        if !isProtected {
            
            
            if let item = pager.selectedItem as? MGalleryVideoItem, let message = item.entry.message {
                if let quality = item.videoQualityState() {
                    
                    let download = ContextMenuItem(strings().galleryContextSaveVideo, itemImage: MenuAnimation.menu_save_as.value)
                    let downloadMenu = ContextMenu()
                    
                    let downloadOrShow:(TelegramMediaFile)->Void = { [weak self] file in
                        
                        let status = chatMessageFileStatus(context: context, message: message, file: file)
                        |> take(1)
                        |> deliverOnMainQueue
                        
                        _ = status.startStandalone(next: { status in
                            if let window = self?.window {
                                let text: String
                                if status == .Local {
                                    text = strings().galleryContextAlertDownloaded
                                } else {
                                    _ = messageMediaFileInteractiveFetched(context: context, messageId: message.id, messageReference: .init(message), file: file, userInitiated: true).startStandalone()
                                    text = strings().galleryContextAlertDownloading
                                }
                                showModalText(for: window, text: text, callback: { _ in
                                    self?.close()
                                    if status == .Local {
                                        showInFinder(file, account: context.account)
                                    } else {
                                        context.bindings.mainController().makeDownloadSearch()
                                    }
                                })
                            }
                            
                        })
                        
                       
                    }
                    
                    
                    if context.isPremium {
                        if let size = item.media.size {
                            downloadMenu.addItem(ContextMenuItem(strings().galleryContextOriginal + " (\(String.prettySized(with: size)))", handler: {
                                downloadOrShow(item.media)
                            }))
                        }
                    }
                    for value in quality.available {
                        let q = "\(roundToStandardQuality(size: value))p"
                        
                        let file = item.media.alternativeRepresentations.compactMap({
                            $0 as? TelegramMediaFile
                        }).first(where: {
                            $0.dimensions?.height == Int32(value)
                        })
                                                
                        if let file = file, let size = file.size {
                            downloadMenu.addItem(ContextMenuItem(q + " (\(String.prettySized(with: size)))", handler: {
                                downloadOrShow(file)
                            }))
                        }
                    }
                    download.submenu = downloadMenu
                    items.append(download)
                    keepSaveAs = false
                }
            }
            if keepSaveAs {
                items.append(ContextMenuItem(strings().galleryContextSaveAs, handler: { [weak self] in
                    self?.saveAs()
                }, itemImage: MenuAnimation.menu_save_as.value))
            }
        }
        
        
        var chatMode: ChatMode = self.chatMode ?? .history
        var chatLocation = self.chatLocation ?? .peer(context.peerId)
        
        if let message = pager.selectedItem?.entry.message {
            if message.isScheduledMessage {
                chatMode = .scheduled
            }
            if self.chatLocation == nil {
                chatLocation = .peer(message.id.peerId)
            }
        }
        
        if let item = pager.selectedItem as? MGalleryGIFItem, chatMode == .history {
            let file = item.media
            if file.isAnimated && file.isVideo {
                let reference = item.entry.fileReference(file)
                if savedGifs.contains(where: { $0.media.fileId == file.fileId }) {
                    items.append(ContextMenuItem(strings().galleryRemoveGif, handler: { [weak control] in
                        _ = removeSavedGif(postbox: context.account.postbox, mediaId: file.fileId).start()
                        if let window = control?._window {
                            showModalText(for: window, text: strings().chatContextGifRemoved)
                        }
                    }, itemImage: MenuAnimation.menu_remove_gif.value))
                } else {
                    items.append(ContextMenuItem(strings().gallerySaveGif, handler: { [weak control, weak self] in
                        
                        guard let window = control?._window else {
                            return
                        }
                        
                        let limit = context.isPremium ? context.premiumLimits.saved_gifs_limit_premium : context.premiumLimits.saved_gifs_limit_default
                        if limit >= savedGifs.count, !context.isPremium {
                            showModalText(for: window, text: strings().chatContextFavoriteGifsLimitInfo("\(context.premiumLimits.saved_gifs_limit_premium)"), title: strings().chatContextFavoriteGifsLimitTitle, callback: { value in
                                showPremiumLimit(context: context, type: .savedGifs)
                                self?.close()
                            })
                            return
                        }
                        let _ = addSavedGif(postbox: context.account.postbox, fileReference: reference).start()
                        if let window = control?._window {
                            showModalText(for: window, text: strings().chatContextGifAdded)
                        }
                    }, itemImage: MenuAnimation.menu_add_gif.value))
                }
            }
        }
        
        if !isProtected, keepSaveAs {
            items.append(ContextMenuItem(strings().galleryContextCopyToClipboard, handler: { [weak self] in
                self?.copy(nil)
            }, itemImage: MenuAnimation.menu_copy.value))
        }
        
        let acceptInteractions: Bool
        switch chatMode {
        case .customChatContents(let contents):
            acceptInteractions = false
        default:
            acceptInteractions = true
        }
        
        let paidMedia = pager.selectedItem?.entry.paidMedia ?? false
        
        if let contentInteractions = self.contentInteractions, acceptInteractions {
            if let message = pager.selectedItem?.entry.message, let pageItem = pager.selectedItem {
                if self.type == .history {
                    items.append(ContextMenuItem(strings().galleryContextShowMessage, handler: { [weak self] in
                        self?.showMessage()
                    }, itemImage: MenuAnimation.menu_show_message.value))
                }
                if chatMode == .history && message.id.peerId != repliesPeerId && self.type == .history {
                    items.append(ContextMenuItem(strings().galleryContextShowGallery, handler: { [weak self] in
                        self?.showSharedMedia()
                    }, itemImage: MenuAnimation.menu_shared_media.value))
                    
                    let controller = context.bindings.rootNavigation().controller

                    
                    if let peer = message.peers[message.id.peerId], peer.canSendMessage(media: message.media.first), let controller = controller as? ChatController {
                        if let _ = message.anyMedia as? TelegramMediaImage {
                            items.append(ContextMenuItem(strings().gallerySendHere, handler: { [weak self, weak controller] in
                                
                                self?.close(false)
                                
                                let signal = pageItem.path.get()
                                |> take(1)
                                |> deliverOnMainQueue
                                _ = signal.start(next: { [weak controller] path in
                                    if let controller = controller {
                                        let preview = PreviewSenderController(urls: [.init(fileURLWithPath: path)], chatInteraction: controller.chatInteraction, asMedia: true, attributedString: nil)
                                        
                                        let ready = preview.ready.get() |> take(1)
                                        
                                        _ = ready.start(next: { [weak preview] value in
                                            delay(0.01, closure: { [weak preview] in
                                                preview?.runDrawer()
                                            })
                                        })
                                        showModal(with: preview, for: context.window)
                                    }
                                })
                            }, itemImage: MenuAnimation.menu_edit.value))
                        }
                    }
                }
                
                
                if canDeleteMessage(message, account: context.account, chatLocation: chatLocation, mode: chatMode), !paidMedia {
                    if !items.isEmpty {
                        items.append(ContextSeparatorItem())
                    }
                    
                    let item = ContextMenuItem(strings().galleryContextDeletePhoto, handler: { [weak self] in
                        self?.deleteMessages([message])
                    }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value)
                    
                    let messages = pager.thumbsControl.items.compactMap({$0.entry.message})
                    if messages.count > 1 {
                        var items:[ContextMenuItem] = []
                        
                        let thisTitle: String
                        if message.anyMedia is TelegramMediaImage {
                            thisTitle = strings().galleryContextShareThisPhoto
                        } else {
                            thisTitle = strings().galleryContextShareThisVideo
                        }
                        items.append(ContextMenuItem(thisTitle, handler: { [weak self] in
                            self?.deleteMessages([message])
                        }, itemImage: MenuAnimation.menu_select_messages.value))
                       
                        let allTitle: String
                        if messages.filter({$0.anyMedia is TelegramMediaImage}).count == messages.count {
                            allTitle = strings().galleryContextShareAllPhotosCountable(messages.count)
                        } else if messages.filter({$0.anyMedia is TelegramMediaFile}).count == messages.count {
                            allTitle = strings().galleryContextShareAllVideosCountable(messages.count)
                        } else {
                            allTitle = strings().galleryContextShareAllItemsCountable(messages.count)
                        }
                        
                        items.append(ContextMenuItem(allTitle, handler: { [weak self] in
                            self?.deleteMessages(messages)
                        }, itemImage: MenuAnimation.menu_select_multiple.value))
                        
                        let submenu = ContextMenu(presentation: .init(colors: darkPalette))
                        for item in items {
                            submenu.addItem(item)
                        }
                        item.submenu = submenu
                    }
                    
                    items.append(item)
                }
            }
        }
        
        
        switch type {
        case .profile(let peerId):
            if peerId == context.peerId {
                if pager.currentIndex != 0 {
                    items.append(ContextMenuItem(strings().galleryContextMainPhoto, handler: { [weak self] in
                        self?.updateMainPhoto()
                    }, itemImage: MenuAnimation.menu_copy_media.value))
                }
                if !items.isEmpty {
                    items.append(ContextSeparatorItem())
                }
                items.append(ContextMenuItem(strings().galleryContextDeletePhoto, handler: { [weak self] in
                    self?.deletePhoto()
                }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
            }
        default:
            break
        }
        
    
        
        let menu = ContextMenu(presentation: .current(darkPalette), betterInside: true)
        for item in items {
            menu.addItem(item)
        }
        if let event = NSApp.currentEvent {
            AppMenu.show(menu: menu, event: event, for: control)
        }
    }
    
    func showControlsPopover(_ control: Control) {
        
        let _savedGifsCount: Signal<[RecentMediaItem], NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudRecentGifs], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 100) |> take(1) |> map {
            $0.orderedItemListsViews[0].items.compactMap {
                $0.contents.get(RecentMediaItem.self)
            }
        } |> deliverOnMainQueue

        _ = _savedGifsCount.start(next: { [weak control, weak self] savedGifs in
            if let control = control {
                self?.showControlsPopoverReady(control, savedGifs: savedGifs)
            }
        })
        
    }
    
    private func deleteMessages(_ messages:[Message]) {
        if !messages.isEmpty, let peer = coreMessageMainPeer(messages[0]) {
            
            let peerId = messages[0].id.peerId
            let messageIds = messages.map {$0.id}
            
            
            var chatMode: ChatMode = self.chatMode ?? .history
            let chatLocation = self.chatLocation ?? .peer(context.peerId)
           
            
            
            let adminsPromise = ValuePromise<[RenderedChannelParticipant]>([])
            _ = context.peerChannelMemberCategoriesContextsManager.admins(peerId: peerId, updated: { membersState in
                if case .loading = membersState.loadingState, membersState.list.isEmpty {
                    adminsPromise.set([])
                } else {
                    adminsPromise.set(membersState.list)
                }
            })
            
            
            messagesActionDisposable.set((adminsPromise.get() |> deliverOnMainQueue).start( next:{ [weak self] admins in
                guard let `self` = self else {return}
                
                var canDelete:Bool = true
                var canDeleteForEveryone = true
                var otherCounter:Int32 = 0
                var _mustDeleteForEveryoneMessage: Bool = true
                for message in messages {
                    if !canDeleteMessage(message, account: self.context.account, chatLocation: chatLocation, mode: chatMode) {
                        canDelete = false
                    }
                    if !mustDeleteForEveryoneMessage(message) {
                        _mustDeleteForEveryoneMessage = false
                    }
                    if !canDeleteForEveryoneMessage(message, context: self.context) {
                        canDeleteForEveryone = false
                    } else {
                        if message.effectiveAuthor?.id != self.context.peerId && !(self.context.limitConfiguration.canRemoveIncomingMessagesInPrivateChats && message.peers[message.id.peerId] is TelegramUser)  {
                            if let peer = message.peers[message.id.peerId] as? TelegramGroup {
                                inner: switch peer.role {
                                case .member:
                                    otherCounter += 1
                                default:
                                    break inner
                                }
                            } else {
                                otherCounter += 1
                            }
                        }
                    }
                }
                
                if otherCounter == messages.count {
                    canDeleteForEveryone = false
                }
                
                if canDelete {
                    let thrid:String? = (canDeleteForEveryone ? peer.isUser ? strings().chatMessageDeleteForMeAndPerson(peer.compactDisplayTitle) : strings().chatConfirmDeleteMessagesForEveryone : nil)
                    
                    
                    if let thrid = thrid {
                        verifyAlert(for: self.window, header: strings().chatConfirmDeleteMessages1Countable(messages.count), information: nil, ok: strings().confirmDelete, option: thrid, successHandler: { [weak self] result in
                            guard let `self` = self else {return}
                            
                            let type:InteractiveMessagesDeletionType
                            switch result {
                            case .basic:
                                type = .forLocalPeer
                            case .thrid:
                                type = .forEveryone
                            }
                            _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: type).start()
                        })
                    } else {
                        _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: messageIds, type: .forLocalPeer).start()
                    }
                }
            }))
        }
    }
    
    private func deleteMessage(_ control: Control) {
         if let _ = self.pager.selectedItem?.entry.message {
            let messages = pager.thumbsControl.items.compactMap({$0.entry.message})
             self.deleteMessages(messages)
         }
    }
    
    private func updateMainPhoto() {
        if let item = self.pager.selectedItem {
            if let index = self.pager.index(for: item) {
                if case let .photo(_, _, _, reference, _, _, _, _, _) = item.entry {
                    if let reference = reference {
                        _ = context.engine.accountData.updatePeerPhotoExisting(reference: reference).start()
                        _ = pager.merge(with: UpdateTransition<MGalleryItem>(deleted: [index], inserted: [(0, item)], updated: []))
                        pager.selectedIndex.set(0)
                    }
                }
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
                
                if case let .photo(_, _, _, reference, _, _, _, _, _) = item.entry {
                    _ = context.engine.accountData.removeAccountPhoto(reference: index == 0 ? nil : reference).start()
                }
            }
            
        }
    }
    
    
    var contextMenu:ContextMenu {
        let menu = ContextMenu(presentation: .current(darkPalette), betterInside: true)
        let context = self.context
        let window = self.window

        if let item = self.pager.selectedItem, item.entry.message?.adAttribute == nil {
            if !(item is MGalleryExternalVideoItem) {
                if item.entry.message?.isCopyProtected() == true {
                    
                } else {
                    menu.addItem(ContextMenuItem(strings().galleryContextSaveAs, handler: { [weak self] in
                        self?.saveAs()
                    }, itemImage: MenuAnimation.menu_save_as.value))
                }
            }
            if item.entry.message?.isCopyProtected() == true {
                
            } else {
                if let text = self.pager.selectedText {
                    menu.addItem(ContextMenuItem(strings().chatCopySelectedText, handler: {
                        copyToClipboard(text)
                    }, itemImage: MenuAnimation.menu_copy.value))
                    
                    let fromLang = Translate.detectLanguage(for: text)
                    let toLang = context.sharedContext.baseSettings.doNotTranslate.union([appAppearance.languageCode])
                    
                    if fromLang == nil || !toLang.contains(fromLang!) {
                        menu.addItem(ContextMenuItem.init(strings().peerInfoTranslate, handler: {
                            showModal(with: TranslateModalController(context: context, from: fromLang, toLang: appAppearance.languageCode, text: text), for: window)
                        }, itemImage: MenuAnimation.menu_translate.value))
                    }
                }
            }
            
            
            if let _ = self.contentInteractions {
                menu.addItem(ContextMenuItem(strings().galleryContextShowMessage, handler: { [weak self] in
                    self?.showMessage()
                }, itemImage: MenuAnimation.menu_show_message.value))
            }
            if item.entry.isProtected == true {
                
            } else {
                menu.addItem(ContextMenuItem(strings().galleryContextCopyToClipboard, handler: { [weak self] in
                    self?.copy(nil)
                }, itemImage: MenuAnimation.menu_copy_media.value))
            }
            
            if let recognition = self.pager.recognition, self.pager.selectedText == nil {
                if #available(macOS 10.15, *) {
                    if recognition.canTranslate() {
                        let text: String = !recognition.hasTranslation() ? strings().galleryTranslate : strings().galleryHideTranslation
                        menu.addItem(ContextMenuItem.init(text, handler: { [weak recognition] in
                            recognition?.toggleTranslate(to: appAppearance.languageCode)
                        }, itemImage: MenuAnimation.menu_translate.value))
                    }
                }
            }
            
        }
        
        
        return menu
    }
    
    
    func saveAs(_ fast: Bool = false) -> Void {
        if let item = self.pager.selectedItem, item.entry.message?.adAttribute == nil {
            let isProtected = item.entry.isProtected

            if !(item is MGalleryExternalVideoItem), !isProtected {
                let isPhoto = item is MGalleryPhotoItem || item is MGalleryPeerPhotoItem
                operationDisposable.set((item.realStatus |> take(1) |> deliverOnMainQueue).start(next: { [weak self] status in
                    guard let `self` = self else {return}
                    switch status {
                    case .Local:
                        self.operationDisposable.set((item.path.get() |> take(1) |> deliverOnMainQueue).start(next: { [weak self] path in
                            if let strongSelf = self {
                                if fast {
                                   
                                    let text: String
                                    if item is MGalleryVideoItem {
                                         text = strings().galleryViewFastSaveVideo1
                                    } else if item is MGalleryGIFItem {
                                        text = strings().galleryViewFastSaveGif1
                                    } else {
                                        text = strings().galleryViewFastSaveImage1
                                    }
                                    
                                    let dateFormatter = makeNewDateFormatter()
                                    dateFormatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
                                   
                                    
                                    let file: TelegramMediaFile?
                                    if let item = item as? MGalleryVideoItem {
                                        file = item.media
                                    } else if let item = item as? MGalleryGIFItem {
                                        file = item.media
                                    } else if let photo = item as? MGalleryPhotoItem {
                                        file = photo.entry.file ?? TelegramMediaFile(fileId: MediaId(namespace: 0, id: arc4random64()), partialReference: nil, resource: photo.media.representations.last!.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "photo_\(dateFormatter.string(from: Date())).jpeg")], alternativeRepresentations: [])
                                    } else if let photo = item as? MGalleryPeerPhotoItem {
                                        file = TelegramMediaFile(fileId: MediaId(namespace: 0, id: arc4random64()), partialReference: nil, resource: photo.media.representations.last!.resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/jpeg", size: nil, attributes: [.FileName(fileName: "photo_\(dateFormatter.string(from: Date())).jpeg")], alternativeRepresentations: [])
                                    } else {
                                        file = nil
                                    }
                                    
                                    let context = strongSelf.context
                                    let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .bold(15), textColor: .white), bold: MarkdownAttributeSet(font: .bold(15), textColor: .white), link: MarkdownAttributeSet(font: .bold(15), textColor: .link), linkAttribute: { contents in
                                        return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { _ in }))
                                    })).mutableCopy() as! NSMutableAttributedString
                                    
                                    let layout = TextViewLayout(attributedText, alignment: .center, lineSpacing: 5.0, alwaysStaticItems: true)
                                    layout.interactions = TextViewInteractions(processURL: { [weak strongSelf] url  in
                                         if let file = file {
                                            showInFinder(file, account: context.account)
                                            strongSelf?.close(false)
                                        }
                                    })
                                    layout.measure(width: 160)
                                    
                                    if let file = file {
                                        
                                        _ = (copyToDownloads(file, postbox: context.account.postbox, saveAnyway: true) |> map { _ in } |> deliverOnMainQueue |> take(1) |> then (showSaveModal(for: strongSelf.window, context: context, animation: LocalAnimatedSticker.success_saved, shouldBlur: false, text: layout, delay: 3.0))).start()
                                    } else {
                                        savePanel(file: path.nsstring.deletingPathExtension, ext: path.nsstring.pathExtension, for: strongSelf.window)
                                    }
                                } else {
                                    savePanel(file: path.nsstring.deletingPathExtension, ext: path.nsstring.pathExtension, for: strongSelf.window)
                                }
                            }
                        }))
                    default:
                        alert(for: self.window, info: isPhoto ? strings().galleryWaitDownloadPhoto : strings().galleryWaitDownloadVideo)
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
            context.bindings.rootNavigation().push(PeerMediaController(context: context, peerId: message.id.peerId, isBot: false))
        }
    }
    
    func openInfo(_ peerId: PeerId, _ toChat: Bool = false, _ messageId: MessageId? = nil, _ initialAction: ChatInitialAction? = nil) {
        close()
        closeAllModals()
        if toChat {
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId), focusTarget: .init(messageId: messageId), initialAction: initialAction))
        } else {
            PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
        }
    }
    
    func share(_ control: Control) -> Void {
        let messages = pager.thumbsControl.items.compactMap { $0.entry.message }
        if let message = self.pager.selectedItem?.entry.message {
            if message.groupInfo != nil, !messages.isEmpty {
                var items:[ContextMenuItem] = []
                
                let thisTitle: String
                if message.anyMedia is TelegramMediaImage {
                    thisTitle = strings().galleryContextShareThisPhoto
                } else if message.anyMedia!.isVideoFile {
                    thisTitle = strings().galleryContextShareThisVideo
                } else if message.anyMedia!.isGraphicFile {
                    thisTitle = strings().galleryContextShareThisPhoto
                } else {
                    thisTitle = strings().galleryContextShareThisFile
                }
                
                items.append(ContextMenuItem(thisTitle, handler: { [weak self] in
                    guard let `self` = self else {return}
                    showModal(with: ShareModalController(ShareMessageObject(self.context, message)), for: self.window)
                }, itemImage: MenuAnimation.menu_share.value))
                
                let allTitle: String
                if messages.filter({$0.anyMedia is TelegramMediaImage}).count == messages.count {
                    allTitle = strings().galleryContextShareAllPhotosCountable(messages.count)
                } else if messages.filter({ $0.anyMedia!.isVideoFile }).count == messages.count {
                    allTitle = strings().galleryContextShareAllVideosCountable(messages.count)
                } else if messages.filter({ $0.anyMedia!.isGraphicFile }).count == messages.count {
                    allTitle = strings().galleryContextShareAllPhotosCountable(messages.count)
                } else {
                    allTitle = strings().galleryContextShareAllItemsCountable(messages.count)
                }
                
                items.append(ContextMenuItem(allTitle, handler: { [weak self] in
                    guard let `self` = self else {return}
                    showModal(with: ShareModalController(ShareMessageObject(self.context, message, messages)), for: self.window)
                }, itemImage: MenuAnimation.menu_share.value))
                
                let menu = ContextMenu(presentation: .current(darkPalette), betterInside: true)
                for item in items {
                    menu.addItem(item)
                }
                if let event = NSApp.currentEvent {
                    AppMenu.show(menu: menu, event: event, for: control)
                }
            } else {
                showModal(with: ShareModalController(ShareMessageObject(self.context, message)), for: self.window)
            }
        }
    }
    
    @objc func copy(_ sender:Any? = nil) -> Void {
        
        if let item = self.pager.selectedItem, !self.pager.copySelectedText() {
            if let message = item.entry.message, item.entry.isProtected {
                showProtectedCopyAlert(message, for: self.window)
            } else  if !(item is MGalleryExternalVideoItem), item.entry.message?.containsSecretMedia != true {
                operationDisposable.set((item.path.get() |> take(1) |> deliverOnMainQueue).start(next: { path in
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    var url = NSURL(fileURLWithPath: path)
                    let image = NSImage(contentsOf: url as URL)

                    let dst = try? FileManager.default.destinationOfSymbolicLink(atPath: path)
                    if let dst = dst {
                        let updated = NSTemporaryDirectory() + dst.nsstring.lastPathComponent + "." +  path.nsstring.pathExtension
                        try? FileManager.default.copyItem(atPath: dst, toPath: updated)
                        url = NSURL(fileURLWithPath: updated)
                    }
                    pb.writeObjects([url, image].compactMap { $0 })
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
        context.window.resignFirstResponder()
        self.window.makeKeyAndOrderFront(nil)
        //window.makeFirstResponder(self)
        //closePipVideo()
       // backgroundView.alphaValue = 0
        backgroundView._change(opacity: 0, animated: false)
        self.readyDispose.set((self.ready.get() |> take(1) |> deliverOnMainQueue).start(completed:  { [weak self] in
            if let strongSelf = self {
                
                if let startTime = strongSelf.contentInteractions?.timeCodeInitializer {
                    if let item = strongSelf.pager.selectedItem as? MGalleryVideoItem {
                        item.startTime = startTime
                    }
                }
                
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
                    //strongSelf?.backgroundView.alphaValue = 1.0
                    strongSelf?.controls.animateIn()
                    strongSelf?.backgroundView._change(opacity: 1, animated: true)
                }, addAccesoryOnCopiedView: { stableId, view in
                    if let stableId = stableId {
                        //self?.delegate?.addAccesoryOnCopiedView(for: stableId, view: view)
                    }
                }, addVideoTimebase: { stableId, view  in
                    
                })
            }
        }));
        
    }
    
    func close(_ animated:Bool = false) -> Void {
        disposable.dispose()
        readyDispose.dispose()
        didSetReady = false
        NotificationCenter.default.removeObserver(self)
        if animated {
            backgroundView._change(opacity: 0, animated: true)
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
        self.contentInteractions?.remove_timeCodeInitializer()
    }
    
}


func closeGalleryViewer(_ animated: Bool) {
    viewer?.close(animated)
}

func showChatGallery(context: AccountContext, message:Message, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history, reversed: Bool = false, chatMode: ChatMode?, chatLocation: ChatLocation?, contextHolder: Atomic<ChatLocationContextHolder?> = Atomic(value: nil)) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(context: context, message: message, delegate, contentInteractions, type: type, reversed: reversed, chatMode: chatMode, chatLocation: chatLocation, contextHolder: contextHolder)
        gallery.show()
    }
}

func showGalleryFromPip(item: MGalleryItem, gallery: GalleryViewer, delegate:InteractionContentViewProtocol? = nil, contentInteractions:ChatMediaLayoutParameters? = nil, type: GalleryAppearType = .history) {
    if viewer == nil {
        viewer?.clean()
        gallery.show(true, item.stableId)
    }
}

func showPhotosGallery(context: AccountContext, peerId:PeerId, firstStableId:AnyHashable, _ delegate:InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(context: context, peerId: peerId, firstStableId: firstStableId, delegate, contentInteractions, chatMode: nil, chatLocation: nil)
        gallery.show()
    }
}

func showInstantViewGallery(context: AccountContext, medias:[InstantPageMedia], firstIndex: Int, firstStableId:AnyHashable? = nil, parent: Message? = nil, _ delegate: InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(context: context, instantMedias: medias, firstIndex: firstIndex, firstStableId: firstStableId, parent: parent, delegate, contentInteractions, chatMode: nil, chatLocation: nil)
        gallery.show()
    }
}

func showPaidMedia(context: AccountContext, medias:[Media], parent: Message, firstIndex: Int, firstStableId:AnyHashable? = nil, _ delegate: InteractionContentViewProtocol? = nil, _ contentInteractions:ChatMediaLayoutParameters? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(context: context, media: medias, firstIndex: firstIndex, firstStableId: firstStableId, parent: parent, delegate, contentInteractions)
        gallery.show()
    }
}


func showSecureIdDocumentsGallery(context: AccountContext, medias:[SecureIdDocumentValue], firstIndex: Int, _ delegate: InteractionContentViewProtocol? = nil) {
    if viewer == nil {
        viewer?.clean()
        let gallery = GalleryViewer(context: context, secureIdMedias: medias, firstIndex: firstIndex, delegate, chatMode: nil, chatLocation: nil)
        gallery.show()
    }
   
}

