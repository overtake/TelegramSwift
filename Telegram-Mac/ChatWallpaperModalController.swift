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
    let openWallpaper: (TelegramWallpaper) -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
    }
}

private struct ThemeGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    
    static func ==(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper
    }
    
    static func <(lhs: ThemeGridControllerEntry, rhs: ThemeGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(account: Account, interaction: ThemeGridControllerInteraction) -> ThemeGridControllerItem {
        return ThemeGridControllerItem(account: account, wallpaper: self.wallpaper, interaction: interaction, isSelected: theme.wallpaper == wallpaper)
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

private func preparedThemeGridEntryTransition(account: Account, from fromEntries: [ThemeGridControllerEntry], to toEntries: [ThemeGridControllerEntry], interaction: ThemeGridControllerInteraction) -> ThemeGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(account: account, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(account: account, interaction: interaction)) }
    
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
    private let account: Account
    

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
    
    init(account: Account) {
        self.account = account

        super.init(frame: NSMakeRect(0, 0, 380, 400))
    }
    
    override var modalInteractions: ModalInteractions? {
        let postbox = account.postbox
        let interactions = ModalInteractions(acceptTitle: L10n.modalCancel, accept: { [weak self] in
            self?.close()
        }, cancelTitle: L10n.appearanceCustomBackground, cancel: { [weak self] in
            if let strongSelf = self {
                filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { [weak strongSelf] paths in
                    if let path = paths?.first {
                        let size = fs(path)
                        if let size = size, size < 10 * 1024 * 1024, let image = NSImage(contentsOf: URL(fileURLWithPath: path)), image.size.width > 500 && image.size.height > 500 {
                            _ = (moveWallpaperToCache(postbox: postbox, path, randomName: true) |> mapToSignal { path in
                                return updateApplicationWallpaper(postbox: postbox, wallpaper: .custom(path))
                                }).start()
                            strongSelf?.close()
                        } else {
                            alert(for: mainWindow, header: appName, info: L10n.appearanceCustomBackgroundFileError)
                        }
                    }
                })
            }
            
        }, drawBorder: true, height: 50, alignCancelLeft: true)
       
        return interactions
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
         self.modal?.resize(with:NSMakeSize(frame.width, size.height - 100), animated: false)
    }
    
    override func viewDidResized(_ size: NSSize) {
        containerLayoutUpdated()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        modal?.interactions?.updateDone { button in
            button.set(color: theme.colors.redUI, for: .Normal)
        }
        modal?.interactions?.updateCancel { button in
            button.set(color: theme.colors.blueUI, for: .Normal)
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
       containerLayoutUpdated()
        
        let account = self.account
        let previousEntries = Atomic<[ThemeGridControllerEntry]?>(value: nil)

        let close = { [weak self] in
            delay(0.3, closure: {
                self?.close()
            })
        }
        let interaction = ThemeGridControllerInteraction(openWallpaper: { wallpaper in
            
            switch wallpaper {
            case .image(let representations):
                if let representation = largestImageRepresentation(representations) {
                    
                    _ = showModalProgress(signal: account.postbox.mediaBox.fetchedResource(representation.resource, tag: nil, implNext: true) |> mapToSignal { source in
                        return moveWallpaperToCache(postbox: account.postbox, representation.resource)
                    } |> deliverOnMainQueue, for: mainWindow).start(next: { _ in
                        _ = updateApplicationWallpaper(postbox: account.postbox, wallpaper: wallpaper).start()
                        close()
                    })
                }
                break
            default:
                _ = updateApplicationWallpaper(postbox: account.postbox, wallpaper: wallpaper).start()
                close()
            }
            
        })
        

        let transition = telegramWallpapers(account: account)
            |> map { wallpapers -> (ThemeGridEntryTransition, Bool) in
                var entries: [ThemeGridControllerEntry] = []
                var index = 0
                for item in wallpapers {
                    entries.append(ThemeGridControllerEntry(index: index, wallpaper: item))
                    index += 1
                }
                let previous = previousEntries.swap(entries)
                return (preparedThemeGridEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
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
