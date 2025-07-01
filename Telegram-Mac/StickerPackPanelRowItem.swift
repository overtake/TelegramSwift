//
//  StickerPackPanelRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 08/07/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit


class StickerPackPanelRowItem: TableRowItem {
    private(set) var files: [(TelegramMediaFile, NSPoint)] = []
    let packNameLayout: TextViewLayout?
    
    let context: AccountContext
    let arguments: StickerPanelArguments
    let namePoint: NSPoint
    let packInfo: StickerPackInfo
    let collectionId: StickerPackCollectionId
    let _files:[TelegramMediaFile]
    
    
    
    private var _height: CGFloat = 0
    override var stableId: AnyHashable {
        return collectionId
    }
    let packReference: StickerPackReference?
        
    private let preloadFeaturedDisposable = MetaDisposable()
    let canSend: Bool
    let playOnHover: Bool
    let isPreview: Bool
    let canSchedule: Bool
    init(_ initialSize: NSSize, context: AccountContext, arguments: StickerPanelArguments, files:[TelegramMediaFile], packInfo: StickerPackInfo, collectionId: StickerPackCollectionId, canSend: Bool, playOnHover: Bool = false, isPreview: Bool = false) {
        
        
        let files = files.sorted(by: { lhs, rhs in
            if lhs.isPremiumSticker && !rhs.isPremiumSticker {
                if lhs.isPremiumSticker {
                    return false
                } else {
                    return true
                }
            } else if !lhs.isPremiumSticker && rhs.isPremiumSticker {
                if lhs.isPremiumSticker {
                    return false
                } else {
                    return true
                }
            }
            return false
        })
        
        self.context = context
        self.arguments = arguments
        self.canSend = canSend
        self._files = files
        self.playOnHover = playOnHover
        self.isPreview = isPreview
        self.canSchedule = arguments.canSchedule()
        let title: String?
        var count: Int32 = 0
        switch packInfo {
        case let .pack(info, _, _):
            title = info?.title ?? info?.shortName ?? ""
            count = info?.count ?? 0
            if let info = info {
                self.packReference = .id(id: info.id.id, accessHash: info.accessHash)
            } else {
                self.packReference = nil
            }
        case .recent:
            title = strings().stickersRecent
            self.packReference = nil
        case .premium:
            title = strings().stickersPremium
            self.packReference = nil
        case .saved:
            title = nil
            self.packReference = nil
        case .emojiRelated:
            title = nil
            self.packReference = nil
        case let .speficicPack(info):
            title = info?.title ?? info?.shortName ?? ""
            if let info = info {
                self.packReference = .id(id: info.id.id, accessHash: info.accessHash)
            } else {
                self.packReference = nil
            }
        }
        
        if let title = title {
            let attributed = NSMutableAttributedString()
            if packInfo.featured {
                _ = attributed.append(string: title.uppercased(), color: theme.colors.text, font: .medium(14))
                _ = attributed.append(string: "\n")
                _ = attributed.append(string: strings().stickersCountCountable(Int(count)), color: theme.colors.grayText, font: .normal(12))
            } else {
                _ = attributed.append(string: title.uppercased(), color: theme.colors.grayText, font: .medium(.text))
            }
            let layout = TextViewLayout(attributed, alwaysStaticItems: true)
            layout.measure(width: 260)
            self.packNameLayout = layout
            
            self.namePoint = NSMakePoint(10, floorToScreenPixels(System.backingScale, ((packInfo.featured ? 50 : 30) - layout.layoutSize.height) / 2))
        } else {
            namePoint = NSZeroPoint
            self.packNameLayout = nil
        }
        
        self.packInfo = packInfo
        self.collectionId = collectionId
        
        
       
        
        if packInfo.featured, let id = collectionId.itemCollectionId {
            preloadFeaturedDisposable.set(preloadedFeaturedStickerSet(network: context.account.network, postbox: context.account.postbox, id: id).start())
        }

        
        super.init(initialSize)
        
        _ = makeSize(initialSize.width, oldWidth: 0)
        
    }
    
    override func makeSize(_ width: CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        let width = max(width, 350)
        
        var filesAndPoints:[(TelegramMediaFile, NSPoint)] = []

        
        let size: NSSize = NSMakeSize(60, 60)

        var point: NSPoint = NSMakePoint(5, packNameLayout == nil ? 5 : !packInfo.featured ? 35 : 55)
        var rowCount: CGFloat = 1
        var countFixed = false
                
        for file in _files {
            var filePoint = point
            let fileSize = file.dimensions?.size.aspectFitted(size) ?? size
            filePoint.y += (size.height - fileSize.height) / 2
            filePoint.x += (size.width - fileSize.width) / 2
            filesAndPoints.append((file, filePoint))

            point.x += size.width + 10
            if point.x + size.width >= width {
                point.y += size.height + 5
                point.x = 5
                countFixed = true
            }
            if !countFixed {
                rowCount += 1
            }
        }
        
        self.files = filesAndPoints


        if point.x == 5 {
            _height = point.y
        } else {
            _height = point.y + size.height + 5
        }
        

        
        return true
    }
        
    override func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        let context = self.context
        if arguments.mode != .common {
            return .single([])
        }
        let files = self.files
        let packInfo = self.packInfo
        let canSend = self.canSend
        
        let _savedStickersCount: Signal<Int, NoError> = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: [Namespaces.OrderedItemList.CloudSavedStickers], namespaces: [Namespaces.ItemCollection.CloudStickerPacks], aroundIndex: nil, count: 100) |> take(1) |> map {
            $0.orderedItemListsViews[0].items.count
        } |> deliverOnMainQueue
        
        return _savedStickersCount |> map { [weak self] savedStickersCount in
            var items:[ContextMenuItem] = []

            for file in files {
                let rect = NSMakeRect(file.1.x, file.1.y, 60, 60)
                let file = file.0
                if NSPointInRect(location, rect) {
                    
                    if file.isPremiumSticker && !context.isPremium {
                        return []
                    }
                    
                    if NSApp.currentEvent?.modifierFlags.contains(.control) == true {
                        if file.isAnimatedSticker, let data = try? Data(contentsOf: URL(fileURLWithPath: context.account.postbox.mediaBox.resourcePath(file.resource))) {
                            items.append(ContextMenuItem("Copy thumbnail (Dev.)", handler: {
                            _ = getAnimatedStickerThumb(data: data).start(next: { path in
                                    if let path = path {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.writeObjects([NSURL(fileURLWithPath: path)])
                                    }
                                })
                            }, itemImage: MenuAnimation.menu_copy_media.value))
                        }
                    }
                    
                    inner: switch packInfo {
                    case .saved, .recent:
                        if let reference = file.stickerReference {
                            items.append(ContextMenuItem(strings().contextViewStickerSet, handler: { [weak self] in
                                self?.arguments.showPack(reference)
                            }, itemImage: MenuAnimation.menu_view_sticker_set.value))
                        }
                    default:
                        break inner
                    }
                    inner: switch packInfo {
                    case .saved:
                        if let mediaId = file.id {
                            items.append(ContextMenuItem(strings().contextRemoveFaveSticker, handler: {
                                showModalText(for: context.window, text: strings().chatContextStickerRemovedFromFavorites)
                                _ = removeSavedSticker(postbox: context.account.postbox, mediaId: mediaId).start()
                            }, itemImage: MenuAnimation.menu_remove_from_favorites.value))
                        }
                    default:
                        if packInfo.installed {
                            items.append(ContextMenuItem(strings().chatContextAddFavoriteSticker, handler: {
                                let limit = context.isPremium ? context.premiumLimits.stickers_faved_limit_premium : context.premiumLimits.stickers_faved_limit_default
                                if limit >= savedStickersCount, !context.isPremium {
                                    showModalText(for: context.window, text: strings().chatContextFavoriteStickersLimitInfo("\(context.premiumLimits.stickers_faved_limit_premium)"), title: strings().chatContextFavoriteStickersLimitTitle, callback: { value in
                                        showPremiumLimit(context: context, type: .faveStickers)
                                    })
                                } else {
                                    showModalText(for: context.window, text: strings().chatContextStickerAddedToFavorites)
                                }
                                _ = addSavedSticker(postbox: context.account.postbox, network: context.account.network, file: file).start()
                            }, itemImage: MenuAnimation.menu_add_to_favorites.value))
                        }
                    }
                    
                    if canSend {
                        items.append(ContextMenuItem(strings().chatSendWithoutSound, handler: { [weak self] in
                            guard let `self` = self else {
                                return
                            }
     
                            if let contentView = self.view {
                                self.arguments.sendMedia(file, contentView, true, false, self.collectionId.itemCollectionId)
                            }
                        }, itemImage: MenuAnimation.menu_mute.value))
                        
                        
                        if self?.canSchedule == true {
                            items.append(ContextMenuItem(strings().chatSendScheduledMessage, handler: { [weak self] in
                                guard let `self` = self else {
                                    return
                                }
                                
                                if let contentView = self.view {
                                    self.arguments.sendMedia(file, contentView, false, true, self.collectionId.itemCollectionId)
                                }
                            }, itemImage: MenuAnimation.menu_schedule_message.value))
                        }
                        
                        
                    }
                    break
                }
            }
            return items
        }
        
    }
    
    deinit {
        preloadFeaturedDisposable.dispose()
    }
    
    override var height: CGFloat {
        return _height
    }
    
    override func viewClass() -> AnyClass {
        return StickerPackPanelRowView.self
    }
}



private final class StickerPackPanelRowView : TableRowView, ModalPreviewRowViewProtocol {
    
    
    private var inlineStickerItemViews: [InlineStickerItemLayer.Key: InlineStickerView] = [:]
    
    func fileAtPoint(_ point: NSPoint) -> (QuickPreviewMedia, NSView?)? {
        
        if let (view, file) = itemUnderMouse {
            let reference = file.stickerReference != nil ? FileMediaReference.stickerPack(stickerPack: file.stickerReference!, media: file) : FileMediaReference.standalone(media: file)
            if file.isVideoSticker && !file.isWebm {
                return (.file(reference, GifPreviewModalView.self), view)
            } else if file.isAnimatedSticker || file.isWebm {
                return (.file(reference, AnimatedStickerPreviewModalView.self), view)
            } else if file.isStaticSticker {
                return (.file(reference, StickerPreviewModalView.self), view)
            }

        }

        return nil
    }
    
    private let contentView:Control = Control()
    
    private let packNameView = TextView()
    private var clearRecentButton: ImageButton?
    private var addButton:TextButton?
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(contentView)
        addSubview(packNameView)
        packNameView.userInteractionEnabled = false
        packNameView.isSelectable = false
        
        contentView.set(handler: { [weak self] _ in
            self?.updateDown()
        }, for: .Down)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateDragging()
        }, for: .MouseDragging)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateUp()
        }, for: .Up)
        
        contentView.set(handler: { [weak self] _ in
            self?.updateAnimatableContent()
        }, for: .Other)
        
        contentView.set(handler: { [weak self] _ in
            let item = self?.item as? StickerPackPanelRowItem
            let table = item?.table
            let window = self?.window as? Window
            if let item = item, let table = table, let window = window {
                startModalPreviewHandle(table, window: window, context: item.context)
            }
        }, for: .LongMouseDown)
    }
    
    private var currentDownItem: (InlineStickerView, TelegramMediaFile, Bool)?
    private func updateDown() {
        if let item = itemUnderMouse {
            self.currentDownItem = (item.0, item.1, true)
        }
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
        }
    }
    private func updateDragging() {
        if let current = self.currentDownItem {
            if self.itemUnderMouse?.1 != current.1, current.2  {
                current.0.layer?.animateScaleCenter(from: 0.95, to: 1, duration: 0.2, removeOnCompletion: true)
                self.currentDownItem?.2 = false
            } else if !current.2, self.itemUnderMouse?.1 == current.1 {
                current.0.layer?.animateScaleCenter(from: 1, to: 0.95, duration: 0.2, removeOnCompletion: false)
                self.currentDownItem?.2 = true
            }
        }
            
    }
    private func updateUp() {
        if let itemUnderMouse = self.currentDownItem {
            itemUnderMouse.0.layer?.animateScaleCenter(from: 0.95, to: 1, duration: 0.2, removeOnCompletion: true)
            if itemUnderMouse.1 == self.itemUnderMouse?.1 {
                self.click()
            }
        }
        self.currentDownItem = nil
    }
    
    private func click() {
        if let item = self.item as? StickerPackPanelRowItem {
            if self.packNameView.mouseInside() {
                if let reference = item.packReference {
                    item.arguments.showPack(reference)
                }
            } else {
                if let reference = item.packReference, item.packInfo.featured {
                    item.arguments.showPack(reference)
                } else if let current = self.currentDownItem {
                    item.arguments.sendMedia(current.1, contentView, false, false, item.collectionId.itemCollectionId)
                }
            }
        }

    }
    
    private var itemUnderMouse: (InlineStickerView, TelegramMediaFile)? {
        guard let window = self.window, let item = self.item as? StickerPackPanelRowItem else {
            return nil
        }
        let point = self.contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        
        let firstItem = item.files.first(where: {
            return NSPointInRect(point, CGRect.init(origin: $0.1, size: NSMakeSize(60, 60)))
        })?.0
        let firstLayer = self.inlineStickerItemViews.first(where: { layer in
            return NSPointInRect(point, layer.1.frame)
        })?.value
        
        if let firstItem = firstItem, let firstLayer = firstLayer {
            return (firstLayer, firstItem)
        }
        
        return nil
    }
    

    override func updateAnimatableContent() -> Void {
        
    }
    
    override var isEmojiLite: Bool {
        if let item = item as? StickerPackPanelRowItem {
            return item.context.isLite(.stickers)
        }
        return super.isEmojiLite
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override func layout() {
        super.layout()
        
        guard let item = item as? StickerPackPanelRowItem else {
            return
        }
        self.packNameView.setFrameOrigin(item.namePoint)
        self.clearRecentButton?.setFrameOrigin(frame.width - 34, item.namePoint.y - 10)
        
        self.contentView.frame = bounds

    }

    override var backdorColor: NSColor {
        return .clear
    }
    

    func updateInlineStickers(context: AccountContext, contentView: NSView, items: [(TelegramMediaFile, NSPoint)], animated: Bool) {
        var validIds: [InlineStickerItemLayer.Key] = []
        var index: Int = 0

        for item in items {
            let id = InlineStickerItemLayer.Key(id: item.0.fileId.id, index: index)
            validIds.append(id)

            let rect = CGRect(origin: item.1, size: NSMakeSize(60, 60))

            let view: InlineStickerView
            if let current = self.inlineStickerItemViews[id], current.frame.size == rect.size {
                view = current
            } else {
                if let layer = self.inlineStickerItemViews[id] {
                    performSubviewRemoval(layer, animated: animated, scale: true)
                }
                view = InlineStickerView(account: context.account, file: item.0, size: rect.size)
                self.inlineStickerItemViews[id] = view
                contentView.addSubview(view)
                if animated {
                    view.layer?.animateScaleCenter(from: 0.1, to: 1, duration: 0.2)
                }
            }
            index += 1

            view.frame = rect
        }

        var removeKeys: [InlineStickerItemLayer.Key] = []
        for (key, itemLayer) in self.inlineStickerItemViews {
            if !validIds.contains(key) {
                removeKeys.append(key)
                performSubviewRemoval(itemLayer, animated: animated, scale: true)
            }
        }
        for key in removeKeys {
            self.inlineStickerItemViews.removeValue(forKey: key)
        }
        self.updateAnimatableContent()
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StickerPackPanelRowItem else {
            return
        }
        
        packNameView.update(item.packNameLayout)
        
        
        if item.arguments.mode == .common {
            switch item.packInfo {
            case .recent:
                if self.clearRecentButton == nil {
                    self.clearRecentButton = ImageButton()
                    addSubview(self.clearRecentButton!)
                }
                self.clearRecentButton?.set(image: theme.icons.wallpaper_color_close, for: .Normal)
                _ = self.clearRecentButton?.sizeToFit(NSMakeSize(5, 5), thatFit: false)
                
                self.clearRecentButton?.removeAllHandlers()
                
                self.clearRecentButton?.set(handler: { [weak item] _ in
                    item?.arguments.clearRecent()
                }, for: .Click)
            default:
                self.clearRecentButton?.removeFromSuperview()
                self.clearRecentButton = nil
            }
        } else {
            self.clearRecentButton?.removeFromSuperview()
            self.clearRecentButton = nil
        }
       
               
        self.addButton?.removeFromSuperview()
        self.addButton = nil
        
        if let reference = item.packReference, item.packInfo.featured {
            if !item.packInfo.installed {
                self.addButton = TextButton()
                self.addButton!.set(background: theme.colors.accentSelect, for: .Normal)
                self.addButton!.set(background: theme.colors.accentSelect.withAlphaComponent(0.8), for: .Highlight)
                self.addButton!.set(font: .medium(.text), for: .Normal)
                self.addButton!.set(color: theme.colors.underSelectedColor, for: .Normal)
                self.addButton!.set(text: strings().stickersSearchAdd, for: .Normal)
                _ = self.addButton!.sizeToFit(NSMakeSize(14, 8), thatFit: true)
                self.addButton!.layer?.cornerRadius = .cornerRadius
                self.addButton!.setFrameOrigin(frame.width - self.addButton!.frame.width - 10, 13)
                
                self.addButton!.set(handler: { [weak item] _ in
                    item?.arguments.addPack(reference)
                }, for: .Click)
            } else {
                self.addButton = TextButton()
                self.addButton!.set(background: theme.colors.grayForeground, for: .Normal)
                self.addButton!.set(background: theme.colors.grayForeground.withAlphaComponent(0.8), for: .Highlight)
                self.addButton!.set(font: .medium(.text), for: .Normal)
                self.addButton!.set(color: theme.colors.underSelectedColor, for: .Normal)
                self.addButton!.set(text: strings().stickersSearchAdded, for: .Normal)
                _ = self.addButton!.sizeToFit(NSMakeSize(14, 8), thatFit: true)
                self.addButton!.layer?.cornerRadius = .cornerRadius
                self.addButton!.setFrameOrigin(frame.width - self.addButton!.frame.width - 10, 13)
                
                self.addButton!.set(handler: { [weak item] _ in
                    if let item = item {
                        item.arguments.removePack(item.collectionId)
                    }
                },  for: .Click)
            }
            addSubview(addButton!)
        }
        
        self.layout()
        
        self.updateInlineStickers(context: item.context, contentView: contentView, items: item.files, animated: animated)
        
    }
    
}
