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




final class StickerPackArguments {
    let context: AccountContext
    let send:(TelegramMediaFile, NSView, Bool, Bool)->Void
    let addpack:(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void
    let share:(String)->Void
    let close:()->Void
    let previewPremium: (TelegramMediaFile, NSView)->Void
    init(context: AccountContext, send:@escaping(Media, NSView, Bool, Bool)->Void, addpack:@escaping(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void, share:@escaping(String)->Void, close:@escaping()->Void, previewPremium: @escaping(TelegramMediaFile, NSView)->Void) {
        self.context = context
        self.send = send
        self.addpack = addpack
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

enum StickerPackPreviewSource {
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
    private let add:TitleButton = TitleButton()
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
        add.set(text: strings().stickerPackAdd1Countable(0), for: .Normal)
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
    
    
    func layout(with result: LoadedStickerPack, source: StickerPackPreviewSource, installedIds: [ItemCollectionId], arguments: StickerPackArguments) -> Void {
        
        
        switch result {
        case .none:
            break
        case .fetching:
            dismiss.isHidden = true
            shareView.isHidden = true
            if self.indicatorView == nil {
                self.indicatorView = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
                addSubview(self.indicatorView!)
            }
            self.indicatorView?.center()
            add.isHidden = true
            shadowView.isHidden = true
        case let .result(info, collectionItems, installed):
            if let indicatorView = self.indicatorView {
                self.indicatorView = nil
                indicatorView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak indicatorView] _ in
                    indicatorView?.removeFromSuperview()
                })
            }
            dismiss.isHidden = !installed
            shareView.isHidden = false
            switch source {
            case .emoji:
                add.set(text: strings().emojiPackAddCountable(collectionItems.count).uppercased(), for: .Normal)
            case .stickers:
                add.set(text: strings().stickerPackAdd1Countable(collectionItems.count).uppercased(), for: .Normal)
            }
            _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
            add.isHidden = installed
            shadowView.isHidden = installed
            
            let attr = NSMutableAttributedString()
            
            _ = attr.append(string: info.title, color: theme.colors.text, font: .medium(16.0))
            attr.detectLinks(type: [.Mentions], context: arguments.context, color: theme.colors.accent, openInfo: { (peerId, _, _, _) in
                _ = (arguments.context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue).start(next: { peer in
                    arguments.close()
                    if peer.isUser || peer.isBot {
                        arguments.context.bindings.rootNavigation().push(PeerInfoController(context: arguments.context, peerId: peerId))
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
            
            let stickerArguments = StickerPanelArguments(context: arguments.context, sendMedia: {  media, view, silent, schedule in
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
                
            }, mode: .common)
            
            let files = collectionItems.map { item -> TelegramMediaFile in
                return item.file
            }.filter { file in
                !file.isPremiumSticker || !context.premiumIsBlocked
            }
            
            
            let item: TableRowItem
            switch source {
            case .emoji:
                item = EmojiesSectionRowItem(frame.size, stableId: 0, context: arguments.context, revealed: true, installed: true, info: info, items: collectionItems, callback: { _ in })
            case .stickers:
                item = StickerPackPanelRowItem(frame.size, context: arguments.context, arguments: stickerArguments, files: files, packInfo: .emojiRelated, collectionId: .pack(info.id), canSend: arguments.context.bindings.rootNavigation().controller is ChatController, isPreview: true)
            }
                        
            _ = item.makeSize(frame.width)
            
            tableView.beginTableUpdates()
            tableView.removeAll()
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 10, stableId: arc4random64()))
            _ = tableView.addItem(item: item, animation: .effectFade)
            
            _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 70, stableId: arc4random64()))

            tableView.endTableUpdates()
            
            self.needsLayout = true
        
            
            shareView.set(handler: { _ in
                switch source {
                case .emoji:
                    arguments.share("https://t.me/addemoji/\(info.shortName)")
                case .stickers:
                    arguments.share("https://t.me/addstickers/\(info.shortName)")
                }
            }, for: .SingleClick)
            
            add.removeAllHandlers()
            dismiss.removeAllHandlers()
            close.removeAllHandlers()
            
            func action(_ control:Control) {
                arguments.addpack(info, collectionItems, installed)
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
    private let reference:StickerPackPreviewSource
    private let disposable: MetaDisposable = MetaDisposable()
    private var arguments:StickerPackArguments!
    private var onAdd:(()->Void)? = nil

    init(_ context: AccountContext, peerId:PeerId?, reference: StickerPackPreviewSource, onAdd:(()->Void)? = nil) {
        self.context = context
        self.peerId = peerId
        self.reference = reference
        self.onAdd = onAdd

        super.init(frame: NSMakeRect(0, 0, 350, 400))
        bar = .init(height: 0)
        arguments = StickerPackArguments(context: context, send: { [weak self] media, view, silent, schedule in
            let interactions = (context.bindings.rootNavigation().controller as? ChatController)?.chatInteraction
            
            if let interactions = interactions, let media = media as? TelegramMediaFile, media.maskData == nil {
                if let slowMode = interactions.presentation.slowMode, slowMode.hasLocked {
                    showSlowModeTimeoutTooltip(slowMode, for: view)
                } else {
                    interactions.sendAppFile(media, silent, nil, schedule)
                    self?.close()
                }
            }
        }, addpack: { [weak self] info, items, installed in
            self?.close()
            self?.disposable.dispose()
            let title: String
            let text: String
            if !installed {
                _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
                switch reference {
                case .stickers:
                    title = strings().stickerPackAddedTitle
                    text = strings().stickerPackAddedInfo(info.title)
                case .emoji:
                    title = strings().emojiPackAddedTitle
                    text = strings().emojiPackAddedInfo(info.title)
                }
            } else {
                switch reference {
                case .stickers:
                    title = strings().stickerPackRemovedTitle
                    text = strings().stickerPackRemovedInfo(info.title)
                case .emoji:
                    title = strings().emojiPackRemovedTitle
                    text = strings().emojiPackRemovedInfo(info.title)
                }
                _ = context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .archive).start()
            }
            showModalText(for: context.window, text: text, title: title)

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
        let namespace = namespaceForMode(reference)

        let reference = self.reference
        let context = self.context
        let signal = context.engine.stickers.loadedStickerPack(reference: reference.reference, forceActualized: true)
        
        let installedIds = context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [namespace])]) |> map { view in
            return view.views[.itemCollectionInfos(namespaces: [namespaceForMode(reference)])] as? ItemCollectionInfosView
        } |> map { view in
            return view?.entriesByNamespace[namespace]
        } |> map { entries -> [ItemCollectionId] in
            return entries?.map { $0.id } ?? []
        }
        
        

   
        disposable.set(combineLatest(queue: .mainQueue(), signal, installedIds).start(next: { [weak self] result, installedIds in
            guard let `self` = self else {return}
            switch result {
            case .none:
                alert(for: context.window, info: strings().stickerSetDontExist)
                self.close()
            default:
                self.genericView.layout(with: result, source: reference, installedIds: installedIds, arguments: self.arguments)
                self.readyOnce()
            }
        }))

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
