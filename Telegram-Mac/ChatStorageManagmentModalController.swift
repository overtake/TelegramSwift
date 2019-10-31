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




class ChatStorageManagmentModalController: ModalViewController {
    private let categories:[PeerCacheUsageCategory: Dictionary<MediaId, Int64>]
    private var sizeIndex: [PeerCacheUsageCategory: (Bool, Int64)] = [:]
    private let clear:([PeerCacheUsageCategory: (Bool, Int64)])->Void
    init(_ categories:[PeerCacheUsageCategory: Dictionary<MediaId, Int64>], clear:@escaping([PeerCacheUsageCategory: (Bool, Int64)])->Void) {
        self.categories = categories
        self.clear = clear
        super.init(frame: NSMakeRect(0, 0, 300, CGFloat(categories.count) * 40 + 40 + 50))
        bar = .init(height: 0)
    }
    
    override var dynamicSize: Bool {
        return true
    }
    
    override func measure(size: NSSize) {
        self.modal?.resize(with:NSMakeSize(genericView.frame.width, min(size.height - 70, genericView.listHeight)), animated: false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        genericView.getBackgroundColor = {
            theme.colors.listBackground
        }
        reloadData()
        
        readyOnce()
    }
    
    private func reloadData() {
        let initialSize = atomicSize.modify({$0})
        
        genericView.removeAll()
        
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 30, stableId: arc4random(), viewType: .separator))
        
        
        let validCategories: [PeerCacheUsageCategory] = [.image, .video, .audio, .file].filter {
            categories[$0] != nil
        }
        
        var totalSize: Int64 = 0
        
        
        var itemIndex = 0
        for (i, categoryId) in validCategories.enumerated() {
            if let media = categories[categoryId] {
                var categorySize: Int64 = 0
                for (_, size) in media {
                    categorySize += size
                }
                sizeIndex[categoryId] = (sizeIndex[categoryId]?.0 ?? true, categorySize)
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
                            title = L10n.storageUsageClear
                        } else {
                            title = "\(L10n.storageUsageClear) (\(dataSizeString(Int(filteredSize))))"
                        }
                        strongSelf.modal?.interactions?.updateDone( { button in
                            button.set(text: title, for: .Normal)
                        })
                        strongSelf.reloadData()
                    }
                    
                }
                _ = genericView.addItem(item: GeneralInteractedRowItem(initialSize, stableId: index, name: stringForCategory(categoryId) + " (\(dataSizeString(Int(categorySize))))" , type: .selectable(sizeIndex[categoryId]?.0 ?? false), viewType: bestGeneralViewType(validCategories, for: i), action: {
                    toggleCheck(categoryId, index)
                }))
                
                itemIndex += 1
            }
        }
        
        
        _ = genericView.addItem(item: GeneralRowItem(initialSize, height: 30, stableId: arc4random(), viewType: .separator))
    }
    
    
    private func stringForCategory(_ category: PeerCacheUsageCategory) -> String {
        switch category {
        case .image:
            return L10n.storageClearPhotos
        case .video:
            return L10n.storageClearVideos
        case .audio:
            return L10n.storageClearAudio
        case .file:
            return L10n.storageClearDocuments
        }
    }
    
    override var modalHeader: (left: ModalHeaderData?, center: ModalHeaderData?, right: ModalHeaderData?)? {
        return (left: nil, center: ModalHeaderData.init(title: L10n.telegramStorageUsageController), right: nil)
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
        }, cancelTitle: L10n.modalCancel, drawBorder: true, height: 50)
    }
    
    private var genericView:TableView {
        return self.view as! TableView
    }
    
    override func viewClass() -> AnyClass {
        return TableView.self
    }
    
    
}
