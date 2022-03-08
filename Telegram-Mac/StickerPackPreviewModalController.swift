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
    init(context: AccountContext, send:@escaping(Media, NSView, Bool, Bool)->Void, addpack:@escaping(StickerPackCollectionInfo, [ItemCollectionItem], Bool)->Void, share:@escaping(String)->Void, close:@escaping()->Void) {
        self.context = context
        self.send = send
        self.addpack = addpack
        self.share = share
        self.close = close
    }
}

extension FeaturedStickerPackItem : Equatable {
    public static func == (lhs: FeaturedStickerPackItem, rhs: FeaturedStickerPackItem) -> Bool {
        return lhs.info == rhs.info && lhs.unread == rhs.unread && lhs.topItems == rhs.topItems
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
    
    private let showMore = TitleButton()
    private var isFeaturedActive: Bool?
    
    var activateFeatured:(()->Void)? = nil
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = theme.colors.background
        addSubview(tableView)
        addSubview(headerTitle)
        addSubview(shareView)
        addSubview(close)
        addSubview(headerSeparatorView)
        addSubview(dismiss)
        addSubview(showMore)
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

        
        showMore.disableActions()
        showMore.layer?.cornerRadius = 20
        
        showMore.set(color: theme.colors.underSelectedColor, for: .Normal)
        showMore.set(font: .medium(.title), for: .Normal)
        showMore.set(background: theme.colors.accent, for: .Normal)
        showMore.set(background: theme.colors.accent, for: .Hover)
        showMore.set(background: theme.colors.accent, for: .Highlight)
        showMore.set(text: strings().stickerPackShowMore, for: .Normal)
        showMore.sizeToFit(NSMakeSize(20, 0), NSMakeSize(0, 40), thatFit: true)
        
        showMore.set(handler: { [weak self] _ in
            self?.activateFeatured?()
            
        }, for: .Click)

        showMore.scaleOnClick = true
        
        addSubview(showMore)
        headerTitle.backgroundColor = theme.colors.background
        headerSeparatorView.backgroundColor = theme.colors.border
        
        shareView.set(image: theme.icons.stickersShare, for: .Normal)
        close.set(image: theme.icons.stickerPackClose, for: .Normal)
        _ = shareView.sizeToFit()
        _ = close.sizeToFit()
        

    }
    
    private var featuredEntries:[FeaturedEntry] = []
    
    func layout(with result: LoadedStickerPack, featured: [FeaturedStickerPackItem], showFeatured: Bool, installedIds: [ItemCollectionId], arguments: StickerPackArguments) -> Void {
        
        
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
            add.set(text: strings().stickerPackAdd1Countable(collectionItems.count).uppercased(), for: .Normal)
            _ = add.sizeToFit(NSMakeSize(20, 0), NSMakeSize(frame.width - 40, 40), thatFit: false)
            add.isHidden = installed
            shadowView.isHidden = installed
            
            if !showFeatured {
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
                
            } else {
                let attr = NSMutableAttributedString()
                _ = attr.append(string: strings().stickerPackFeaturedTitle, color: theme.colors.text, font: .medium(16.0))
                let layout = TextViewLayout(attr, maximumNumberOfLines: 1, alignment: .center)
                layout.interactions = globalLinkExecutor
                
                layout.measure(width: frame.width - 160)
                headerTitle.update(layout)
                
                self.dismiss.isHidden = true
                self.shareView.isHidden = true
            }
           
            let context = arguments.context
            
            let stickerArguments = StickerPanelArguments(context: arguments.context, sendMedia: {  media, view, silent, schedule in
                if let media = media as? TelegramMediaFile {
                    arguments.send(media, view, silent, schedule)
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
            }
            
            let allInstalled = featured.filter { !installedIds.contains($0.info.id) }.isEmpty
            if !showFeatured || allInstalled {
                
                self.featuredEntries = []
                
                let item = StickerPackPanelRowItem(frame.size, context: arguments.context, arguments: stickerArguments, files: files, packInfo: .emojiRelated, collectionId: .pack(info.id), canSend: arguments.context.bindings.rootNavigation().controller is ChatController)
                _ = item.makeSize(frame.width)
                
                tableView.beginTableUpdates()
                tableView.removeAll()
                _ = tableView.addItem(item: item, animation: .effectFade)
                
                _ = tableView.addItem(item: GeneralRowItem(frame.size, height: 70, stableId: arc4random64()))

                tableView.endTableUpdates()
            } else {
                
                let arguments = StickerPanelArguments(context: arguments.context, sendMedia: { _, _, _, _ in
                    
                }, showPack: { _ in
                    
                }, addPack: { reference in
                    _ = showModalProgress(signal: context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: false)
                        |> filter { result in
                            switch result {
                            case .result:
                                return true
                            default:
                                return false
                            }
                        }
                        |> take(1)
                        |> mapToSignal { result -> Signal<ItemCollectionId, NoError> in
                            switch result {
                            case let .result(info, items, _):
                                return context.engine.stickers.addStickerPackInteractively(info: info, items: items) |> map { info.id }
                            default:
                                return .complete()
                            }
                        }
                        |> deliverOnMainQueue, for: context.window).start(next: { _ in
                            
                        })
                }, navigate: { _ in
                    
                }, clearRecent: {
                    
                }, removePack: { _ in
                    
                }, closeInlineFeatured: { _ in
                    
                }, openFeatured: { _ in
                    
                }, mode: .common)
                
                
                tableView.beginTableUpdates()
                
                if self.featuredEntries.isEmpty {
                    self.tableView.removeAll()
                }

                var entries:[FeaturedEntry] = []
                for (i, item) in featured.enumerated() {
                    entries.append(.init(item: item, index: i, installed: installedIds.contains(item.info.id)))
                }
                
                let (delete, insert, update) = mergeListsStableWithUpdates(leftList: self.featuredEntries, rightList: entries)
                
                for index in delete.reversed() {
                    tableView.remove(at: index)
                }
                for insert in insert {
                    _ = tableView.insert(item: insert.1.item(arguments, initialSize: frame.size), at: insert.0, redraw: true, animation: .effectFade)
                }
                for update in update {
                    tableView.replace(item: update.1.item(arguments, initialSize: frame.size), at: update.0, animated: true)
                }
                self.featuredEntries = entries

                tableView.endTableUpdates()

            }
                       
            
            self.needsLayout = true
            
            if installed, !featured.isEmpty && !showFeatured {
                showMore.isHidden = false
            } else {
                showMore.isHidden = true
            }
            
            shareView.set(handler: { _ in
                arguments.share("https://t.me/addstickers/\(info.shortName)")
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
        showMore.centerX(y: frame.height - showMore.frame.height - 15)
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
    private let reference:StickerPackReference
    private let disposable: MetaDisposable = MetaDisposable()
    private var arguments:StickerPackArguments!
    private var onAdd:(()->Void)? = nil

    init(_ context: AccountContext, peerId:PeerId?, reference:StickerPackReference, onAdd:(()->Void)? = nil) {
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
            if !installed {
                _ = context.engine.stickers.addStickerPackInteractively(info: info, items: items).start()
            } else {
                _ = context.engine.stickers.removeStickerPackInteractively(id: info.id, option: .archive).start()
            }
            self?.onAdd?()
            
        }, share: { [weak self] link in
            self?.close()
            showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
        }, close: { [weak self] in
            self?.close()
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
        
        let context = self.context
        let signal = context.engine.stickers.loadedStickerPack(reference: reference, forceActualized: true)
        
        let installedIds = context.account.postbox.combinedView(keys: [.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])]) |> map { view in
            return view.views[.itemCollectionInfos(namespaces: [Namespaces.ItemCollection.CloudStickerPacks])] as? ItemCollectionInfosView
        } |> map { view in
            return view?.entriesByNamespace[Namespaces.ItemCollection.CloudStickerPacks]
        } |> map { entries -> [ItemCollectionId] in
            return entries?.map { $0.id } ?? []
        }
        
        

        let featuredView = context.account.viewTracker.featuredStickerPacks()
        
        let showFeatured: ValuePromise<Bool> = ValuePromise(false, ignoreRepeated: true)
        
        genericView.activateFeatured = {
            showFeatured.set(true)
        }

        disposable.set(combineLatest(queue: .mainQueue(), signal, featuredView, showFeatured.get(), installedIds).start(next: { [weak self] result, featured, showFeatured, installedIds in
            guard let `self` = self else {return}
            switch result {
            case .none:
                alert(for: context.window, info: strings().stickerSetDontExist)
                self.close()
            default:
                self.genericView.layout(with: result, featured: featured, showFeatured: showFeatured, installedIds: installedIds, arguments: self.arguments)
                self.readyOnce()
            }
        }))

    }
    
    
    deinit {
        disposable.dispose()
    }
    
}
