//
//  StickerGridEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 23/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac
import TGUIKit

enum ChatMediaInputGridEntryStableId : Hashable {
    
    case sticker(ItemCollectionId, ItemCollectionItemIndex.Id)
    case speficicSticker(ItemCollectionId, ItemCollectionItemIndex.Id)
    case recent(TelegramMediaFile)
    case saved(TelegramMediaFile)
    
    static func ==(lhs: ChatMediaInputGridEntryStableId, rhs: ChatMediaInputGridEntryStableId) -> Bool {
        switch lhs {
        case let .sticker(lhsItemCollectionId, lhsItemId):
            if case let .sticker(rhsItemCollectionId, rhsItemId) = rhs {
                return lhsItemCollectionId == rhsItemCollectionId && lhsItemId == rhsItemId
            } else {
                return false
            }
        case let .speficicSticker(lhsItemCollectionId, lhsItemId):
            if case let .speficicSticker(rhsItemCollectionId, rhsItemId) = rhs {
                return lhsItemCollectionId == rhsItemCollectionId && lhsItemId == rhsItemId
            } else {
                return false
            }
        case let .recent(lhsFile):
            if case let .recent(rhsFile) = rhs {
                return lhsFile.isEqual(rhsFile)
            } else {
                return false
            }
        case let .saved(lhsFile):
            if case let .saved(rhsFile) = rhs {
                return lhsFile.isEqual(rhsFile)
            } else {
                return false
            }

        }
    }
    
    var hashValue: Int {
        switch self {
        case let .sticker(_, itemId):
            return itemId.hashValue
        case let .speficicSticker(_, itemId):
            return itemId.hashValue
        case let .recent(file):
            return file.fileId.hashValue
        case let .saved(file):
            return file.fileId.hashValue
        }
       // return self.itemId.hashValue
    }
}

enum ChatMediaGridPackHeaderInfo {
    case pack(StickerPackCollectionInfo?, Bool)
    case speficicPack(StickerPackCollectionInfo?)
    case recent
    case saved
}

extension ChatMediaGridPackHeaderInfo {
    var title:String {
        switch self {
        case let .pack(info, _):
            if let info = info {
                return info.title.uppercased()
            } else {
                return ""
            }
        case .recent:
            return L10n.stickersRecent
        case .saved:
            return L10n.stickersFavorite
        case .speficicPack:
            return L10n.stickersGroupStickers
        }
    }
}

enum ChatMediaGridCollectionStableId : Hashable {
    case pack(ItemCollectionId)
    case recent
    case specificPack(ItemCollectionId)
    case saved
    
    var hashValue: Int {
        switch self {
        case let .pack(collectionId):
            return collectionId.hashValue
        case let .specificPack(collectionId):
            return collectionId.hashValue
        case .recent:
            return 1
        case .saved:
            return 2
        }
    }
    
    var itemCollectionId:ItemCollectionId? {
        switch self {
        case let .pack(collectionId):
            return collectionId
        case let .specificPack(collectionId):
            return collectionId

        default:
            return nil
        }
    }
    
    
    static func ==(lhs: ChatMediaGridCollectionStableId, rhs: ChatMediaGridCollectionStableId) -> Bool {
        switch lhs {
        case let .pack(lhsCollectionId):
            if case let .pack(rhsCollectionId) = rhs {
                return lhsCollectionId == rhsCollectionId
            } else {
                return false
            }
        case .recent:
            if case .recent = rhs {
                return true
            } else {
                return false
            }
        case .saved:
            if case .saved = rhs {
                return true
            } else {
                return false
            }
        case let .specificPack(collectionId):
            if case .specificPack(collectionId) = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

enum ChatMediaInputGridIndex : Hashable, Comparable {
    case sticker(ItemCollectionViewEntryIndex)
    case speficicSticker(ItemCollectionItemIndex)
    case recent(Int)
    case saved(Int)
    
    var packIndex:ItemCollectionViewEntryIndex {
        switch self {
        case let .sticker(index):
            return index
        case .saved(let index), .recent(let index):
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: Int32(index), collectionId: ItemCollectionId(namespace: 0, id: 0))
        case .speficicSticker:
            return ItemCollectionViewEntryIndex.lowerBound(collectionIndex: 3, collectionId: ItemCollectionId(namespace: 0, id: 0))
        }
    }
    
    
    var hashValue: Int {
        switch self {
        case let .sticker(index):
            return Int(index.itemIndex.index)
        case let .recent(index):
            return index
        case let .saved(index):
            return index
        case .speficicSticker(let index):
            return index.hashValue
        }
    }
    
    static func ==(lhs: ChatMediaInputGridIndex, rhs: ChatMediaInputGridIndex) -> Bool {
        switch lhs {
        case let .sticker(lhsIndex):
            if case let .sticker(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .recent(lhsIndex):
            if case let .recent(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        case let .speficicSticker(index):
            if case .speficicSticker(index) = rhs {
                return true
            } else {
                return false
            }
        case let .saved(lhsIndex):
            if case let .saved(rhsIndex) = rhs {
                return lhsIndex == rhsIndex
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: ChatMediaInputGridIndex, rhs: ChatMediaInputGridIndex) -> Bool {
        switch lhs {
        case let .recent(lhsIndex):
            if case let .recent(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                switch rhs {
                case .saved:
                    return false
                default:
                    return true
                }
            }
        case let .sticker(lhsIndex):
            if case let .sticker(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                switch rhs {
                case .recent, .saved:
                    return true
                default:
                    return false
                }
            }
        case let .saved(lhsIndex):
            if case let .saved(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                return true
            }
        case let .speficicSticker(lhsIndex):
            if case let .speficicSticker(rhsIndex) = rhs {
                return lhsIndex < rhsIndex
            } else {
                return true
            }
        }
    }
}

struct ChatMediaInputGridEntry: Comparable, Identifiable {
    
    
    let index: ChatMediaInputGridIndex
    let file: TelegramMediaFile
    let packInfo: ChatMediaGridPackHeaderInfo
    let _stableId:ChatMediaInputGridEntryStableId
    let collectionId:ChatMediaGridCollectionStableId
    
    var stableId: ChatMediaInputGridEntryStableId {
        return _stableId //ChatMediaInputGridEntryStableId(collectionId: self.index.collectionId, itemId: self.stickerItem.index.id)
    }
    
    static func ==(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.file.isEqual(rhs.file) && lhs.collectionId == rhs.collectionId
    }
    
    static func <(lhs: ChatMediaInputGridEntry, rhs: ChatMediaInputGridEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(account: Account, inputNodeInteraction: EStickersInteraction) -> GridItem {
        return StickerGridItem(account: account, collectionId: self.collectionId, packInfo: packInfo, index: self.index, file: self.file, inputNodeInteraction: inputNodeInteraction, selected: {  })
    }
}
