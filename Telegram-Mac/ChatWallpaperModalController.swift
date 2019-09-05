//
//  ChatBackgroundModalController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 11/01/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import PostboxMac
import TGUIKit
import SwiftSignalKitMac


final class ThemeGridControllerInteraction {
    let openWallpaper: (Wallpaper, TelegramWallpaper?) -> Void
    let deleteWallpaper: (Wallpaper, TelegramWallpaper) -> Void
    init(openWallpaper: @escaping (Wallpaper, TelegramWallpaper?) -> Void, deleteWallpaper: @escaping (Wallpaper, TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
        self.deleteWallpaper = deleteWallpaper
    }
}

private struct ThemeGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: Wallpaper
    let telegramWallapper: TelegramWallpaper?
    let selected: Bool

    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(account: account, wallpaper: self.wallpaper, telegramWallpaper: self.telegramWallapper, interaction: interaction, isSelected: selected)
    }
}

private struct ThemeGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedThemeGridEntryTransition(context: AccountContext, from fromEntries: [ThemeGridControllerEntry], to toEntries: [ThemeGridControllerEntry], interaction: ThemeGridControllerInteraction) -> ThemeGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: context.account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: context.account, interaction: interaction)) }
    
    return ThemeGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

private final class ChatWallpaperView : View {
    fileprivate let gridNode: GridNode = GridNode()
    fileprivate let header:TextView = TextView()
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(gridNode)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        gridNode.frame = NSMakeRect(0, 10, frame.width, frame.height - 10)
    }
}

class ChatWallpaperModalController: ModalViewController {
    private let context: AccountContext
    

    override func viewClass() -> AnyClass {
        return ChatWallpaperView.self
    }
    
    private var genericView: ChatWallpaperView {
        return self.view as! ChatWallpaperView
    }
    
    var gridNode: GridNode {
        return genericView.gridNode
    }
    
    private var queuedTransitions: [ThemeGridEntryTransition] = []
    private var disposable: Disposable?
    
    init(_ context: AccountContext) {
        self.context = context

        super.init(frame: NSMakeRect(0, 0, 380, 400))
    }
    
    override var modalInteractions: ModalInteractions? {
        let context = self.context
        let interactions = ModalInteractions(acceptTitle: L10n.chatWPSelectFromFile, accept: {
            filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { paths in
                if let path = paths?.first {
                    let size = fs(path)
                    if let size = size, size < 10 * 1024 * 1024, let image = NSImage(contentsOf: URL(fileURLWithPath: path))?.cgImage(forProposedRect: nil, context: nil, hints: nil), image.size.width > 500 && image.size.height > 500 {
                        
                        let options = NSMutableDictionary()
                        options.setValue(90 as NSNumber, forKey: kCGImageDestinationImageMaxPixelSize as String)
                        var representations: [TelegramMediaImageRepresentation] = []
                        let colorQuality: Float = 0.1
                        options.setObject(colorQuality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
                        let mutableData: CFMutableData = NSMutableData() as CFMutableData
                        
                        if let colorDestination = CGImageDestinationCreateWithData(mutableData, kUTTypeJPEG, 1, nil) {
                            CGImageDestinationAddImage(colorDestination, image, options as CFDictionary)
                            if CGImageDestinationFinalize(colorDestination) {
                                let thumdResource = LocalFileMediaResource(fileId: arc4random64())
                                context.account.postbox.mediaBox.storeResourceData(thumdResource.id, data: mutableData as Data)
                                representations.append(TelegramMediaImageRepresentation(dimensions: image.size.aspectFitted(NSMakeSize(90, 90)), resource: thumdResource))
                            }
                        }
                        
                        let resource = LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                        representations.append(TelegramMediaImageRepresentation(dimensions: image.size, resource: resource))
                        
                        showModal(with: WallpaperPreviewController(context, wallpaper: .image(representations, settings: WallpaperSettings()), source: .none), for: mainWindow)
                        
                    } else {
                        alert(for: mainWindow, header: appName, info: L10n.appearanceCustomBackgroundFileError)
                    }
                }
            })
        }, cancelTitle: L10n.modalCancel, cancel: { [weak self] in
            self?.close()
        }, drawBorder: true, height: 50, alignCancelLeft: true)
       
        return interactions
    }
    
    override var dynamicSize: Bool {
        return true
    }
    public override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData(title: L10n.chatWPBackgroundTitle), right: nil)
    }
    
    override func measure(size: NSSize) {
         self.modal?.resize(with:NSMakeSize(frame.width, size.height - 150), animated: false)
    }
    
    override func viewDidResized(_ size: NSSize) {
        containerLayoutUpdated()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
       containerLayoutUpdated()
        
        let context = self.context
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)

        let close = { [weak self] in
           self?.close()
        }
        
        let deleted: Promise<[Wallpaper]> = Promise([])
        let deletedValue:Atomic<[Wallpaper]> = Atomic(value: [])
        
        let updateDeleted: (([Wallpaper]) -> [Wallpaper]) -> Void = { f in
            deleted.set(.single(deletedValue.modify(f)))
        }
        
        let interaction = ThemeGridControllerInteraction(openWallpaper: { wallpaper, telegramWallpaper in
            switch wallpaper {
            case .image, .file, .color:
                showModal(with: WallpaperPreviewController(context, wallpaper: wallpaper, source: telegramWallpaper != nil ? .gallery(telegramWallpaper!) : .none), for: context.window)
            default:
                let isOwn = wallpaper != .none
                _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: { settings in
                    return settings.updateWallpaper{ $0.withUpdatedWallpaper(wallpaper) }.withUpdatedBubbled(true)
                }).start()
                delay(0.15, closure: {
                    close()
                })
            }
            
        }, deleteWallpaper: { wallpaper, telegramWallpaper in
            if wallpaper.isSemanticallyEqual(to: theme.wallpaper.wallpaper) {
                _ = updateThemeInteractivetly(accountManager: context.sharedContext.accountManager, f: {
                    return $0.updateWallpaper({ $0.withUpdatedWallpaper(.builtin) }).withUpdatedBubbled(true)
                }).start()
            }
            
            _ = deleteWallpaper(account: context.account, wallpaper: telegramWallpaper).start()
            
            updateDeleted { current in
                return current + [wallpaper]
            }
        })
        

        let transition = combineLatest(queue: prepareQueue, telegramWallpapers(postbox: context.account.postbox, network: context.account.network), deleted.get(), appearanceSignal)
            |> map { wallpapers, deletedWallpapers, appearance -> (ThemeGridEntryTransition, Bool) in
                var entries: [ThemeGridControllerEntry] = []
                var index = 0
                
                entries.append(ThemeGridControllerEntry(index: index, wallpaper: .none, telegramWallapper: nil, selected: appearance.presentation.wallpaper.wallpaper.isSemanticallyEqual(to: .none)))
                index += 1
                
                
                let telegramWallpaper: TelegramWallpaper? = wallpapers.first(where: { wallpaper -> Bool in
                    let wallpaper: Wallpaper = Wallpaper(wallpaper)
                    return wallpaper.isSemanticallyEqual(to: theme.wallpaper.wallpaper)
                })
                let selected: Wallpaper = theme.wallpaper.wallpaper
                
                
                let wallpaper: Wallpaper
                if theme.colors.accent != theme.colors.basicAccent {
                    wallpaper  = .color(Int32(bitPattern: theme.colors.basicAccent.rgb))
                } else {
                    wallpaper = .color(Int32(bitPattern: theme.colors.basicAccent.lighter(amount: 0.25).rgb))
                }
                entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, telegramWallapper: nil, selected: theme.wallpaper.wallpaper.isSemanticallyEqual(to: wallpaper)))

                
                switch selected {
                case .none, .color:
                    break
                default:
                    entries.append(ThemeGridControllerEntry(index: index, wallpaper: selected, telegramWallapper: telegramWallpaper, selected: true))
                    index += 1
                }
                
                for item in wallpapers {
                    let wallpaper = Wallpaper(item)
                    if !deletedWallpapers.contains(where: {$0.isSemanticallyEqual(to: wallpaper)}) {
                        switch item {
                        case let .file(_, _, _, _, isPattern, _, _, _, settings):
                            if isPattern, settings.color == nil {
                                continue
                            }
                        default:
                            break
                        }
                        if selected.isSemanticallyEqual(to: wallpaper) {
                            continue
                        }
                        entries.append(ThemeGridControllerEntry(index: index, wallpaper: wallpaper, telegramWallapper: item, selected: appearance.presentation.wallpaper.wallpaper.isSemanticallyEqual(to: wallpaper)))
                        index += 1
                    }
                }
                let previous = previousEntries.swap(entries)
                return (preparedThemeGridEntryTransition(context: context, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
        }
        
        self.disposable = (transition |> deliverOnMainQueue).start(next: { [weak self] (transition, _) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    
    private func enqueueTransition(_ transition: ThemeGridEntryTransition) {
        self.queuedTransitions.append(transition)
        self.dequeueTransitions()
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { [weak self] _ in
                if let strongSelf = self {
                   strongSelf.readyOnce()
                }
            })
        }
    }
    
    func containerLayoutUpdated() {
        var insets: NSEdgeInsets = NSEdgeInsets()
        let scrollIndicatorInsets = insets
        
        let referenceImageSize = CGSize(width: 108.0, height: 163.0)
        
        let minSpacing: CGFloat = 10.0
        
        let imageCount = Int((frame.width - minSpacing * 2.0) / (referenceImageSize.width + minSpacing))
        
        let imageSize = referenceImageSize.aspectFilled(CGSize(width: floor((frame.width - CGFloat(imageCount + 1) * minSpacing) / CGFloat(imageCount)), height: referenceImageSize.height))
        
        let spacing = floor((frame.width - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount + 1))
        
        insets.top += 0
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: frame.size, insets: insets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 380, type: .fixed(itemSize: imageSize, lineSpacing: spacing)), transition: .immediate), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height)
        
        let dequeue = true
        if dequeue {
            self.dequeueTransitions()
        }
    }

    
    func scrollToTop() {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top, transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }
}
