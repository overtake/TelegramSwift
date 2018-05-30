//
//  ChatStorageManagmentModalController.swift
//  Telegram
//
//  Created by keepcoder on 18/04/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


/*let controller = ActionSheetController()
 let dismissAction: () -> Void = { [weak controller] in
 controller?.dismissAnimated()
 }
 
 var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
 
 var itemIndex = 0
 
 let updateTotalSize: () -> Void = { [weak controller] in
 controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
 let title: String
 let filteredSize = sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
 
 if filteredSize == 0 {
 title = "Clear"
 } else {
 title = "Clear (\(dataSizeString(Int(filteredSize))))"
 }
 
 if let item = item as? ActionSheetButtonItem {
 return ActionSheetButtonItem(title: title, color: filteredSize != 0 ? .accent : .disabled, enabled: filteredSize != 0, action: item.action)
 }
 return item
 })
 }
 
 let toggleCheck: (PeerCacheUsageCategory, Int) -> Void = { [weak controller] category, itemIndex in
 if let (value, size) = sizeIndex[category] {
 sizeIndex[category] = (!value, size)
 }
 controller?.updateItem(groupIndex: 0, itemIndex: itemIndex, { item in
 if let item = item as? ActionSheetCheckboxItem {
 return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
 }
 return item
 })
 updateTotalSize()
 }
 var items: [ActionSheetItem] = []
 
 let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]
 
 var totalSize: Int64 = 0
 
 for categoryId in validCategories {
 if let media = categories[categoryId] {
 var categorySize: Int64 = 0
 for (_, size) in media {
 categorySize += size
 }
 sizeIndex[categoryId] = (true, categorySize)
 totalSize += categorySize
 let index = itemIndex
 items.append(ActionSheetCheckboxItem(title: stringForCategory(categoryId), label: dataSizeString(Int(categorySize)), value: true, action: { value in
 toggleCheck(categoryId, index)
 }))
 itemIndex += 1
 }
 }
 
 if !items.isEmpty {
 items.append(ActionSheetButtonItem(title: "Clear (\(dataSizeString(Int(totalSize))))", action: {
 if let statsPromise = statsPromise {
 var clearCategories = sizeIndex.keys.filter({ sizeIndex[$0]!.0 })
 //var clearSize: Int64 = 0
 
 var clearMediaIds = Set<MediaId>()
 
 var media = stats.media
 if var categories = media[peerId] {
 for category in clearCategories {
 if let contents = categories[category] {
 for (mediaId, size) in contents {
 clearMediaIds.insert(mediaId)
 //clearSize += size
 }
 }
 categories.removeValue(forKey: category)
 }
 
 media[peerId] = categories
 }
 
 var clearResourceIds = Set<WrappedMediaResourceId>()
 for id in clearMediaIds {
 if let ids = stats.mediaResourceIds[id] {
 for resourceId in ids {
 clearResourceIds.insert(WrappedMediaResourceId(resourceId))
 }
 }
 }
 
 statsPromise.set(.single(.result(CacheUsageStats(media: media, mediaResourceIds: stats.mediaResourceIds, peers: stats.peers))))
 
 clearDisposable.set(clearCachedMediaResources(account: account, mediaResourceIds: clearResourceIds).start())
 }
 
 dismissAction()
 }))
 
 controller.setItemGroups([
 ActionSheetItemGroup(items: items),
 ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
 ])
 presentControllerImpl?(controller)
 } */



class ChatStorageManagmentModalController: ModalViewController {
    private let categories:[PeerCacheUsageCategory: Dictionary<MediaId, Int64>]
    private var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
    private let clear:([PeerCacheUsageCategory: (Bool, Int64)])->Void
    init(_ categories:[PeerCacheUsageCategory: Dictionary<MediaId, Int64>], clear:@escaping([PeerCacheUsageCategory: (Bool, Int64)])->Void) {
        self.categories = categories
        self.clear = clear
        super.init(frame: NSMakeRect(0, 0, 300, CGFloat(categories.count) * 40 + 40 + 50))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let initialSize = atomicSize.modify({$0})
        
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 20, stableId: arc4random()))
        
        
        let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file]
        
        var totalSize: Int64 = 0
        
        
        var itemIndex = 0
        
        for categoryId in validCategories {
            if let media = categories[categoryId] {
                var categorySize: Int64 = 0
                for (_, size) in media {
                    categorySize += size
                }
                sizeIndex[categoryId] = (true, categorySize)
                totalSize += categorySize
                let index = itemIndex
                
                let toggleCheck: (PeerCacheUsageCategory, Int) -> Void = { [weak self] category, itemIndex in
                    if let strongSelf = self {
                        if let (value, size) = strongSelf.sizeIndex[category] {
                            strongSelf.sizeIndex[category] = (!value, size)
                        }
                        let title: String
                        let filteredSize = strongSelf.sizeIndex.values.reduce(0, { $0 + ($1.0 ? $1.1 : 0) })
                        
                        if filteredSize == 0 {
                            title = "Clear"
                        } else {
                            title = "Clear (\(dataSizeString(Int(filteredSize))))"
                        }
                        strongSelf.modal?.interactions?.updateDone( { button in
                            button.set(text: title, for: .Normal)
                        })
                        strongSelf.genericView.reloadData()
                    }
                    
                }
                
                _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: index, name: stringForCategory(categoryId) + " (\(dataSizeString(Int(categorySize))))" , type: .selectable(sizeIndex[categoryId]?.0 ?? false), action: {
                    toggleCheck(categoryId, index)
                }))
                
                itemIndex += 1
            }
        }
        
        
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 20, stableId: arc4random()))
        
        readyOnce()
    }
    
    
    private func stringForCategory(_ category: PeerCacheUsageCategory) -> String {
        switch category {
        case .image:
            return tr(L10n.storageClearPhotos)
        case .video:
            return tr(L10n.storageClearVideos)
        case .audio:
            return tr(L10n.storageClearAudio)
        case .file:
            return tr(L10n.storageClearDocuments)
        }
    }
    
    override var modalInteractions: ModalInteractions? {
        
        var totalSize: Int64 = 0
        
        for(_, media) in categories  {
            var categorySize: Int64 = 0
            for (_, size) in media {
                categorySize += size
            }
            totalSize += categorySize
        }

        
        return ModalInteractions(acceptTitle: tr(L10n.storageClear(dataSizeString(Int(totalSize)))), accept: { [weak self] in
            if let strongSelf = self {
                self?.clear(strongSelf.sizeIndex)
            }
            
            self?.close()
        }, cancelTitle: tr(L10n.modalCancel), drawBorder: true, height: 40)
    }
    
    private var genericView:TableView {
        return self.view as! TableView
    }
    
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    
}
