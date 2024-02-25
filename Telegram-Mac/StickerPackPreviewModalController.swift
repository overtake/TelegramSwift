//
//  StickerPackPreviewModalController.swift
//  Telegram
//
//  Created by keepcoder on 27/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SwiftSignalKit


private enum State {
    enum Source {
        case stickers
        case emoji
    }
    struct Collection {
        let info: StickerPackCollectionInfo
        let items: [StickerPackItem]
        let installed: Bool
    }
    case loading(Source)
    case loaded(source: Source, collections: [Collection])
}



private final class StickerPackArguments {
    let context: AccountContext
    let send:(TelegramMediaFile, NSView, Bool, Bool)->Void
    let setEmoji:(TelegramMediaFile)->Void

    let addpack:(State.Source, State.Collection, Bool)->Void
    let addAll:(State.Source, [State.Collection], Bool)->Void

    let share:(String)->Void
    let close:()->Void
    let previewPremium: (TelegramMediaFile, NSView)->Void
    init(context: AccountContext, send:@escaping(Media, NSView, Bool, Bool)->Void, setEmoji:@escaping(TelegramMediaFile)->Void, addpack:@escaping(State.Source, State.Collection, Bool)->Void, addAll:@escaping(State.Source, [State.Collection], Bool)->Void, share:@escaping(String)->Void, close:@escaping()->Void, previewPremium: @escaping(TelegramMediaFile, NSView)->Void) {
        self.context = context
        self.send = send
        self.setEmoji = setEmoji
        self.addpack = addpack
        self.addAll = addAll
        self.share = share
        self.close = close
        self.previewPremium = previewPremium
    }
}

extension FeaturedStickerPackItem : Equatable {
    public static func == (lhs: FeaturedStickerPackItem, rhs: FeaturedStickerPackItem) -> Bool {
        return lhs.info == rhs.info && lhs.unread == rhs.unread && lhs.topItems == rhs.topItems
    }
}

enum StickerPackPreviewSource : Hashable {
    case stickers(StickerPackReference)
    case emoji(StickerPackReference)
    
    var reference: StickerPackReference {
        switch self {
        case let .stickers(reference):
            return reference
        case let .emoji(reference):
            return reference
        }
    }
}

private struct FeaturedEntry : TableItemListNodeEntry {
    
    let item: FeaturedStickerPackItem
    let index: Int
    let installed: Bool
    func item(_ arguments: StickerPanelArguments, initialSize: NSSize) -> TableRowItem {
        return StickerPackPanelRowItem(initialSize, context: arguments.context, arguments: arguments, files: item.topItems.map { $0.file }, packInfo: .pack(item.info, installed: installed, featured: true), collectionId: .pack(item.info.id), canSend: false)
    }
    
    var stableId: AnyHashable {
        return item.info.id
    }
    
    static func < (lhs: FeaturedEntry, rhs: FeaturedEntry) -> Bool {
        return lhs.index < rhs.index
    }
    static func == (lhs: FeaturedEntry, rhs: FeaturedEntry) -> Bool {
        return lhs.item == rhs.item && lhs.index == rhs.index && lhs.installed == rhs.installed
    }
}


private class StickersModalView : View {
    private let tableView:TableView = TableView(frame: NSZeroRect)
    private let add:TextButton = TextButton()
    private let shareView:ImageButton = ImageButton()
    private let close: ImageButton = ImageButton()
    private let headerTitle:TextView = TextView()
    private let headerSeparatorView:View = View()
    private let dismiss:ImageButton = ImageButton()
    private var indicatorView:ProgressIndicator?
    private let shadowView: ShadowView = ShadowView()
    
        
    private var premiumView: StickerPremiumHolderView? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        addSubview(tableView)
        addSubview(headerTitle)
        addSubview(shareView)
        addSubview(close)
        addSubview(headerSeparatorView)
        addSubview(dismiss)
        shadowView.shadowBackground = theme.colors.background
        shadowView.setFrameSize(frame.width, 70)
        
        addSubview(shadowView)
        
        dismiss.set(image: theme.icons.stickerPackDelete, for: .Normal)
        _ = dismiss.sizeToFit()
        add.disableActions()
        add.setFrameSize(170, 40)
        add.layer?.cornerRadius = 20
        
        add.set(color: theme.colors.underSelectedColor, for: .Normal)
        add.set(font: .medium(.title), for: .Normal)
        add.set(background: theme.colors.accent, for: .Normal)
        add.set(background: theme.colors.accent, for: .Hover)
        add.set(background: theme.colors.accent, for: .Highlight)
        addSubview(add)
        add.scaleOnClick = true

        
        headerTitle.backgroundColor = theme.colors.background
        headerSeparatorView.backgroundColor = theme.colors.border
        
        shareView.set(image: theme.icons.stickersShare, for: .Normal)
        close.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = shareView.sizeToFit()
        _ = close.sizeToFit()
        
        dismiss.scaleOnClick = true
        close.scaleOnClick = true
        
    }
    
    func previewPremium(_ file: TelegramMediaFile, context: AccountContext, view: NSView, animated: Bool) {
        let current: StickerPremiumHolderView
        if let view = premiumView {
            current = view
        } else {
            current = StickerPremiumHolderView(frame: bounds)
            self.premiumView = current
            addSubview(current)
            
            if animated {
                current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            }
        }
        current.set(file: file, context: context, callback: { [weak self] in
            showModal(with: PremiumBoardingController(context: context, source: .premium_stickers), for: context.window)
            self?.closePremium()
        })
        current.close = { [weak self] in
            self?.closePremium()
        }
    }
    
    var isPremium: Bool {
        return self.premiumView != nil
    }
    
    func closePremium() {
        if let view = premiumView {
            performSubviewRemoval(view, animated: true)
            self.premiumView = nil
        }
    }
    
    
    func layout(with state: State, source controllerSource: StickerPackPreviewModalController.Source, installed: Set<StickerPackPreviewSource>, arguments: StickerPackArguments) -> Void {
        
        
        switch state {
        case .loading:
            dismiss.isHidden = true
            shareView.isHidden = true
            if self.indicatorView == nil {
                self.indicatorView = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
                addSubview(self.indicatorView!)
            }
            self.indicatorView?.center()
            add.isHidden = true
            shadowView.isHidden = true
        case let .loaded(source, collections):
            if let indicatorView = self.indicatorView {
                performSubviewRemoval(indicatorView, animated: true)
                self.indicatorView = nil
            }
            
            let isInstalled:(State.Collection)->Bool = { collection in
                if collection.installed {
                    return true
                }
                switch source {
                case .emoji:
                    return installed.contains(.emoji(.name(collection.info.shortName)))
                case .stickers:
                    return installed.contains(.stickers(.name(collection.info.shortName)))
                }
            }
            
            let allInstalled: Bool
            let notInstalledCount = collections.filter({ !isInstalled($0) }).count

            
            switch controllerSource {
            case .install:
                dismiss.isHidden = collections.count > 1 || !isInstalled(collections[0])
                shareView.isHidden = false
                
                allInstalled = !collections.contains(where: { !isInstalled($0) })
                
                add.isHidden = allInstalled
                shadowView.isHidden = allInstalled
                
                
                if !allInstalled {
                    switch source {
                    case .emoji:
                        if collections.count == 1 {
                            add.set(text: strings().emojiPackAddCountable(collections[0].items.count).uppercased(), for: .Normal)
                        } else {
                            add.set(text: strings().emojiPackSetsAddCountable(notInstalledCount).uppercased(), for: .Normal)
                        }
                    case .stickers:
                        if collections.count == 1 {
                            add.set(text: strings().stickerPackAdd1Countable(collections[0].items.count).uppercased(), for: .Normal)
                        } else {
                            add.set(text: strings().stickerPackSetsAdd1Countable(notInstalledCount).uppercased(), for: .Normal)
                        }
                    }
                    _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
                }
            default:
                dismiss.isHidden = true
                shareView.isHidden = true
                add.isHidden = false
                shadowView.isHidden = false
                
                allInstalled = false
                
                switch controllerSource {
                case .installGroupEmojiPack:
                    add.set(text: "Set as Group Emoji Pack", for: .Normal)
                case .removeGroupEmojiPack:
                    add.set(text: "Remove Group Emoji Pack", for: .Normal)
                default:
                    break
                }
                _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
            }
            
            

            let attr = NSMutableAttributedString()

            if collections.count == 1 {
                let collection = collections[0]
                _ = attr.append(string: collection.info.title, color: theme.colors.text, font: .medium(16.0))
            } else {
                switch source {
                case .emoji:
                    _ = attr.append(string: strings().stickerPackEmoji, color: theme.colors.text, font: .medium(16.0))
                case .stickers:
                    _ = attr.append(string: strings().stickerPackStickers, color: theme.colors.text, font: .medium(16.0))
                }
            }
            attr.detectLinks(type: [.Mentions], context: arguments.context, color: theme.colors.accent, openInfo: { (peerId, _, _, _) in
                _ = (arguments.context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { peer in
                    arguments.close()
                    if peer.isUser || peer.isBot {
                        let navigation = arguments.context.bindings.rootNavigation()
                        PeerInfoController.push(navigation: navigation, context: arguments.context, peerId: peerId)
                    } else {
                        arguments.context.bindings.rootNavigation().push(ChatAdditionController(context: arguments.context, chatLocation: .peer(peer.id)))
                    }
                })
            })
            let layout = TextViewLayout(attr, maximumNumberOfLines: 2, alignment: .center)
            layout.interactions = globalLinkExecutor


            layout.measure(width: frame.width - 160)
            headerTitle.update(layout)
            let context = arguments.context

            let stickerArguments = StickerPanelArguments(context: arguments.context, sendMedia: {  media, view, silent, schedule, _ in
                if let media = media as? TelegramMediaFile {
                    if media.isPremiumSticker && !context.isPremium {
                        arguments.previewPremium(media, view)
                    } else {
                        arguments.send(media, view, silent, schedule)
                    }
                }
            }, showPack: { _ in

            }, addPack: { _ in

            }, navigate: { _ in

            }, clearRecent: {

            }, removePack: { _ in

            }, closeInlineFeatured: { _ in

            }, openFeatured: { _ in

            }, selectEmojiCategory: { _ in
                
            }, mode: .common)


            let size = frame.size


            let makeItems:(State.Collection)->[TableRowItem] = { collection in
                switch source {
                case .emoji:
                    
                    let array = collection.items.chunks(32)
                    var tableItems: [TableRowItem] = []
                    for (i, items) in array.enumerated() {
                        tableItems.append(EmojiesSectionRowItem(size, stableId: arc4random64(), context: arguments.context, revealed: true, installed: isInstalled(collection), info: i != 0 ? nil : collection.info, items: items, mode: .preview, callback: { item, _, _, _ in
                            arguments.setEmoji(item.file)
                        }, installPack: { _, _ in
                            arguments.addpack(source, collection, false)
                        }))
                    }
                     return tableItems
                case .stickers:
                    let files = collection.items.map { item -> TelegramMediaFile in
                        return item.file
                    }
                    return [StickerPackPanelRowItem(size, context: arguments.context, arguments: stickerArguments, files: files, packInfo: .emojiRelated, collectionId: .pack(collection.info.id), canSend: arguments.context.bindings.rootNavigation().controller is ChatController, isPreview: true)]
                }
            }
            
            tableView.beginTableUpdates()
            tableView.removeAll()
            
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: arc4random64()))
            
            for collection in collections {
                let items = makeItems(collection)
                for item in items {
                    _ = item.makeSize(frame.width)
                    _ = tableView.addItem(item: item, animation: .none)
                }
            }
            
            if !allInstalled {
                _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 70, stableId: arc4random64()))
            }

            tableView.endTableUpdates()
            
            self.needsLayout = true
        
            
            shareView.set(handler: { _ in
                
                let shareText: String = collections.reduce("", { current, value in
                    let text: String
                    switch source {
                    case .emoji:
                        text = "https://t.me/addemoji/\(value.info.shortName)"
                    case .stickers:
                        text = "https://t.me/addstickers/\(value.info.shortName)"
                    }
                    return current + text + "\n"
                })
                arguments.share(shareText.trimmed)
                
            }, for: .SingleClick)
//
            add.removeAllHandlers()
            dismiss.removeAllHandlers()
            close.removeAllHandlers()
//
            func action(_ control:Control) {
                if collections.count == 1 {
                    arguments.addpack(source, collections[0], true)
                } else {
                    arguments.addAll(source, collections, true)
                }
            }
            
            
            add.set(handler: action, for: .SingleClick)
            dismiss.set(handler: action, for: .SingleClick)

            close.set(handler: { _ in
                arguments.close()
            }, for: .Click)
            
        }
        
       
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
        let headerHeight:CGFloat = 50
        
        tableView.frame = NSMakeRect(0, headerHeight, frame.width, frame.height - headerHeight)
        
        headerTitle.centerX(y : floorToScreenPixels(backingScaleFactor, (headerHeight - headerTitle.frame.height)/2) + 1)
        headerSeparatorView.frame = NSMakeRect(0, headerHeight - .borderSize, frame.width, .borderSize)
        shareView.setFrameOrigin(frame.width - close.frame.width - 12, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        close.setFrameOrigin(12, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2))
        add.centerX(y: frame.height - add.frame.height - 15)
        dismiss.setFrameOrigin(NSMakePoint(shareView.frame.minX - dismiss.frame.width - 15, floorToScreenPixels(backingScaleFactor, (headerHeight - shareView.frame.height)/2)))
        
        shadowView.setFrameOrigin(0, frame.height - shadowView.frame.height)
        premiumView?.frame = bounds
    }
}


private final class SetPreviewController: TableViewController {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}


class StickerPackPreviewModalController: ModalViewController {
    private let context:AccountContext
    private let peerId:PeerId?
    private let references: [StickerPackPreviewSource]
    private let disposable: MetaDisposable = MetaDisposable()
    private var arguments:StickerPackArguments!
    private var onAdd:(()->Void)? = nil
    private let source: Source
    
    private let installedValue = ValuePromise<Set<StickerPackPreviewSource>>(Set(), ignoreRepeated: true)
    private var installed: Set<StickerPackPreviewSource> = Set() {
        didSet {
            installedValue.set(installed)
        }
    }
    enum Source {
        case install
        case installGroupEmojiPack
        case removeGroupEmojiPack
    }
    
    
    init(_ context: AccountContext, peerId:PeerId?, references: [StickerPackPreviewSource], onAdd:(()->Void)? = nil, source controllerSource: Source = .install) {
        self.context = context
        self.peerId = peerId
        self.references = references
        self.onAdd = onAdd
        self.source = controllerSource
        super.init(frame: NSMakeRect(0, 0, 350, 400))
        bar = .init(height: 0)
        arguments = StickerPackArguments(context: context, send: { [weak self] media, view, silent, schedule in
            let interactions = (context.bindings.rootNavigation().controller as? ChatController)?.chatInteraction
            
            if let interactions = interactions, let media = media as? TelegramMediaFile, media.maskData == nil {
                if let slowMode = interactions.presentation.slowMode, slowMode.hasLocked {
                    showSlowModeTimeoutTooltip(slowMode, for: view)
                } else {
                    interactions.sendAppFile(media, silent, nil, schedule, nil)
                    self?.close()
                }
            }
        }, setEmoji: { [weak self] file in
            let interactions = (context.bindings.rootNavigation().controller as? ChatController)?.chatInteraction
            guard let interactions = interactions else {
                return
            }
            if context.isPremium {
                if interactions.presentation.state == .normal {
                    _ = interactions.appendText(.makeAnimated(file, text: file.customEmojiText ?? ""), selectedRange: nil)
                    interactions.showEmojiUseTooltip()
                    self?.close()
                }
            } else {
                showModalText(for: context.window, text: strings().emojiPackPremiumAlert, callback: { _ in
                    showModal(with: PremiumBoardingController(context: context, source: .premium_emoji), for: context.window)
                })
            }
            
        }, addpack: { [weak self] source, collection, close in
            switch controllerSource {
            case .install:
                let title: String
                let text: String
                if !collection.installed {
                    _ = context.engine.stickers.addStickerPackInteractively(info: collection.info, items: collection.items).start()
                    switch source {
                    case .stickers:
                        title = strings().stickerPackAddedTitle
                        text = strings().stickerPackAddedInfo(collection.info.title)
                    case .emoji:
                        title = strings().emojiPackAddedTitle
                        text = strings().emojiPackAddedInfo(collection.info.title)
                    }
                } else {
                    switch source {
                    case .stickers:
                        title = strings().stickerPackRemovedTitle
                        text = strings().stickerPackRemovedInfo(collection.info.title)
                    case .emoji:
                        title = strings().emojiPackRemovedTitle
                        text = strings().emojiPackRemovedInfo(collection.info.title)
                    }
                    _ = context.engine.stickers.removeStickerPackInteractively(id: collection.info.id, option: .archive).start()
                }
                showModalText(for: context.window, text: text, title: title)

                if close {
                    self?.close()
                    self?.disposable.dispose()
                } else {
                    switch source {
                    case .emoji:
                        self?.installed.insert(.emoji(.name(collection.info.shortName)))
                    case .stickers:
                        self?.installed.insert(.emoji(.name(collection.info.shortName)))
                    }
                }
                self?.onAdd?()
            default:
                self?.close()
                self?.disposable.dispose()
                self?.onAdd?()
            }
            
            
        }, addAll: { [weak self] source, collections, close in
            
            let signals = collections.map {
                context.engine.stickers.addStickerPackInteractively(info: $0.info, items: $0.items)
            }
            _ = combineLatest(signals).start()
            
            if close {
                self?.close()
                self?.disposable.dispose()
            } else {
                for collection in collections {
                    switch source {
                    case .emoji:
                        self?.installed.insert(.emoji(.name(collection.info.shortName)))
                    case .stickers:
                        self?.installed.insert(.emoji(.name(collection.info.shortName)))
                    }
                }
                
            }
            
            self?.onAdd?()

        }, share: { [weak self] link in
            self?.close()
            showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
        }, close: { [weak self] in
            self?.close()
        }, previewPremium: { [weak self] file, view in
            self?.genericView.previewPremium(file, context: context, view: view, animated: true)
        })
    }
    
    fileprivate var genericView:StickersModalView {
        return self.view as! StickersModalView
    }
    
    override func viewClass() -> AnyClass {
        return StickersModalView.self
    }
    
    
    override var dynamicSize: Bool {
        return true
    }
    
    
    override func measure(size: NSSize) {
       // self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
        func namespaceForMode(_ mode: StickerPackPreviewSource) -> ItemCollectionId.Namespace {
            switch mode {
                case .stickers:
                    return Namespaces.ItemCollection.CloudStickerPacks
                case .emoji:
                    return Namespaces.ItemCollection.CloudEmojiPacks
            }
        }
        let namespaces = self.references.map { namespaceForMode($0) }
        let namespace = namespaces[0]
        let references = self.references
        let context = self.context
        let signal = combineLatest(references.map {
            context.engine.stickers.loadedStickerPack(reference: $0.reference, forceActualized: true)
        }) |> deliverOnMainQueue
        
    
        
        
        disposable.set(combineLatest(signal, installedValue.get()).start(next: { [weak self] result, installed in
            guard let `self` = self else {return}
            let isEmpty = result.filter { value in
                switch value {
                case .none:
                    return true
                default:
                    return false
                }
            }.count == result.count
            
            let isLoaded = result.filter { value in
                switch value {
                case .fetching:
                    return true
                default:
                    return false
                }
            }.isEmpty

            
            let state: State
            
            let source: State.Source
            if namespace == Namespaces.ItemCollection.CloudEmojiPacks {
                source = .emoji
            } else {
                source = .stickers
            }
            
            let collections:[State.Collection] = result.compactMap { value in
                switch value {
                case let .result(info, items, installed):
                    return .init(info: info, items: items, installed: installed)
                default:
                    return nil
                }
            }
            
            state = isLoaded ? .loaded(source: source, collections: collections) : .loading(source)
            
            if isEmpty {
                alert(for: context.window, info: strings().stickerSetDontExist)
                self.close()
            } else {
                self.genericView.layout(with: state, source: self.source, installed: installed, arguments: self.arguments)
                self.readyOnce()
            }
        }))

    }
    
    override func becomeFirstResponder() -> Bool? {
        return nil
    }
    
    override var canBecomeResponder: Bool {
        return false
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        if self.genericView.isPremium {
            self.genericView.closePremium()
            return .invoked
        } else {
            return super.escapeKeyAction()
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
}
