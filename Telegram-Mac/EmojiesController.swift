//
//  EmojiesController.swift
//  Telegram
//
//  Created by Mike Renoir on 30.05.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings
import Postbox

//private final class WarpView: View {
//    private final class WarpPartView: View {
//        let cloneView: PortalView
//        
//        init?(contentView: PortalSourceView) {
//            guard let cloneView = PortalView(matchPosition: false) else {
//                return nil
//            }
//            self.cloneView = cloneView
//            
//            super.init(frame: CGRect())
//            
//            self.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)
//            
//            self.clipsToBounds = true
//            self.addSubview(cloneView.view)
//            contentView.addPortal(view: cloneView)
//        }
//        
//        required init?(coder: NSCoder) {
//            fatalError("init(coder:) has not been implemented")
//        }
//        
//        func update(containerSize: CGSize, rect: CGRect, transition: Transition) {
//            transition.setFrame(view: self.cloneView.view, frame: CGRect(origin: CGPoint(x: -rect.minX, y: -rect.minY), size: CGSize(width: containerSize.width, height: containerSize.height)))
//        }
//    }
//    
//    let contentView: PortalSourceView
//    
//    private let clippingView: UIView
//    private let overlayView: UIView
//    
//    private var warpViews: [WarpPartView] = []
//    
//    override init(frame: CGRect) {
//        self.contentView = PortalSourceView()
//        self.clippingView = UIView()
//        self.overlayView = UIView()
//        
//        super.init(frame: frame)
//        
//        self.clippingView.addSubview(self.contentView)
//        
//        self.clippingView.clipsToBounds = false
//        self.addSubview(self.clippingView)
//        
//        self.addSubview(self.overlayView)
//        
//        for _ in 0 ..< 8 {
//            if let warpView = WarpPartView(contentView: self.contentView) {
//                self.warpViews.append(warpView)
//                self.addSubview(warpView)
//            }
//        }
//    }
//    
//    required init?(coder: NSCoder) {
//        fatalError("init(coder:) has not been implemented")
//    }
//    
//    func update(size: CGSize, topInset: CGFloat, warpHeight: CGFloat, theme: PresentationTheme, transition: Transition) {
//        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))
//        
//        let frame = CGRect(origin: CGPoint(x: 0.0, y: -topInset), size: CGSize(width: size.width, height: size.height + topInset - warpHeight))
//        transition.setPosition(view: self.clippingView, position: frame.center)
//        transition.setBounds(view: self.clippingView, bounds: CGRect(origin: CGPoint(x: 0.0, y: -topInset + (topInset - warpHeight) * 0.5), size: size))
//        
//        let allItemsHeight = warpHeight * 0.5
//        for i in 0 ..< self.warpViews.count {
//            let itemHeight = warpHeight / CGFloat(self.warpViews.count)
//            let itemFraction = CGFloat(i + 1) / CGFloat(self.warpViews.count)
//            let _ = itemHeight
//            
//            let da = CGFloat.pi * 0.5 / CGFloat(self.warpViews.count)
//            let alpha = CGFloat.pi * 0.5 - itemFraction * CGFloat.pi * 0.5
//            let endPoint = CGPoint(x: cos(alpha), y: sin(alpha))
//            let prevAngle = alpha + da
//            let prevPt = CGPoint(x: cos(prevAngle), y: sin(prevAngle))
//            var angle: CGFloat
//            angle = -atan2(endPoint.y - prevPt.y, endPoint.x - prevPt.x)
//            
//            let itemLengthVector = CGPoint(x: endPoint.x - prevPt.x, y: endPoint.y - prevPt.y)
//            let itemLength = sqrt(itemLengthVector.x * itemLengthVector.x + itemLengthVector.y * itemLengthVector.y) * warpHeight * 0.5
//            let _ = itemLength
//            
//            var transform: CATransform3D
//            transform = CATransform3DIdentity
//            transform.m34 = 1.0 / 240.0
//            
//            transform = CATransform3DTranslate(transform, 0.0, prevPt.x * allItemsHeight, (1.0 - prevPt.y) * allItemsHeight)
//            transform = CATransform3DRotate(transform, angle, 1.0, 0.0, 0.0)
//            
//            //self.warpViews[i].backgroundColor = UIColor(red: 0.0, green: 0.0, blue: CGFloat(i) / CGFloat(self.warpViews.count - 1), alpha: 1.0)
//            //self.warpViews[i].backgroundColor = UIColor(white: 0.0, alpha: 0.5)
//            //self.warpViews[i].backgroundColor = theme.list.plainBackgroundColor
//            
//            let positionY = size.height - allItemsHeight + 4.0 + /*warpHeight * cos(alpha)*/ CGFloat(i) * itemLength
//            let rect = CGRect(origin: CGPoint(x: 0.0, y: positionY), size: CGSize(width: size.width, height: itemLength))
//            transition.setPosition(view: self.warpViews[i], position: CGPoint(x: rect.midX, y: size.height - allItemsHeight + 4.0))
//            transition.setBounds(view: self.warpViews[i], bounds: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: itemLength)))
//            transition.setTransform(view: self.warpViews[i], transform: transform)
//            self.warpViews[i].update(containerSize: size, rect: rect, transition: transition)
//        }
//        
//        self.overlayView.backgroundColor = theme.list.plainBackgroundColor
//        transition.setFrame(view: self.overlayView, frame: CGRect(origin: CGPoint(x: 0.0, y: size.height - allItemsHeight + 4.0), size: CGSize(width: size.width, height: allItemsHeight)))
//    }
//    
//    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
//        return self.contentView.hitTest(point, with: event)
//    }
//}


private extension RecentReactionItem.Content {
    var reaction: MessageReaction.Reaction {
        switch self {
        case let .custom(file):
            return .custom(file.fileId.id)
        case let .builtin(emoji):
            return .builtin(emoji)
        }
    }
}

enum EmojiSegment : Int64, Comparable  {
    case RecentAnimated = 100
    case Recent = 0
    case People = 1
    case AnimalsAndNature = 2
    case FoodAndDrink = 3
    case ActivityAndSport = 4
    case TravelAndPlaces = 5
    case Objects = 6
    case Symbols = 7
    case Flags = 8
    
    var localizedString: String {
        switch self {
        case .RecentAnimated: return strings().emojiRecent
        case .Recent: return strings().emojiRecentNew
        case .People: return strings().emojiSmilesAndPeople
        case .AnimalsAndNature: return strings().emojiAnimalsAndNature
        case .FoodAndDrink: return strings().emojiFoodAndDrink
        case .ActivityAndSport: return strings().emojiActivityAndSport
        case .TravelAndPlaces: return strings().emojiTravelAndPlaces
        case .Objects: return strings().emojiObjects
        case .Symbols: return strings().emojiSymbols
        case .Flags: return strings().emojiFlags
        }
    }
    
    static var all: [EmojiSegment] {
        return [.People, .AnimalsAndNature, .FoodAndDrink, .ActivityAndSport, .TravelAndPlaces, .Objects, .Symbols, .Flags]
    }
    
    var hashValue:Int {
        return Int(self.rawValue)
    }
}

func ==(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue == rhs.rawValue
}

func <(lhs:EmojiSegment, rhs:EmojiSegment) -> Bool {
    return lhs.rawValue < rhs.rawValue
}

let emojiesInstance:[EmojiSegment:[String]] = {
    assertNotOnMainThread()
    var local:[EmojiSegment:[String]] = [EmojiSegment:[String]]()
    
    let resource:URL?
    if #available(OSX 11.1, *) {
        resource = Bundle.main.url(forResource:"emoji1016", withExtension:"txt")
    } else if #available(OSX 10.14.1, *) {
        resource = Bundle.main.url(forResource:"emoji1014-1", withExtension:"txt")
    } else  if #available(OSX 10.12, *) {
        resource = Bundle.main.url(forResource:"emoji", withExtension:"txt")
    } else {
        resource = Bundle.main.url(forResource:"emoji11", withExtension:"txt")
    }
    if let resource = resource {
        
        var file:String = ""
        
        do {
            file = try String(contentsOf: resource)
            
        } catch {
            print("emoji file not loaded")
        }
        
        let segments = file.components(separatedBy: "\n\n")
        
        for segment in segments {
            
            let list = segment.components(separatedBy: " ")
            
            if let value = EmojiSegment(rawValue: Int64(local.count + 1)) {
                local[value] = list
            }
            
        }
        
    }
    
    return local
    
}()

private func segments(_ emoji: [EmojiSegment : [String]], skinModifiers: [EmojiSkinModifier]) -> [EmojiSegment:[[NSAttributedString]]] {
    var segments:[EmojiSegment:[[NSAttributedString]]] = [:]
    for (key,list) in emoji {
        
        var line:[NSAttributedString] = []
        var lines:[[NSAttributedString]] = []
        var i = 0
        
        for emoji in list {
            
            var e:String = emoji.emojiUnmodified
            for modifier in skinModifiers {
                if e == modifier.emoji {
                    if e.length == 5 {
                        let mutable = NSMutableString()
                        mutable.insert(e, at: 0)
                        mutable.insert(modifier.modifier, at: 2)
                        e = mutable as String
                    } else {
                        e = e + modifier.modifier
                    }
                }

            }
            if !line.contains(where: {$0.string == String(e.first!) }), let first = e.first {
                if String(first).length > 1 {
                    line.append(.initialize(string: String(first), font: .normal(26.0)))
                    i += 1
                }
            }
            
            
            if i == 8 {
                
                lines.append(line)
                line.removeAll()
                i = 0
            }
        }
        if line.count > 0 {
            lines.append(line)
        }
        if lines.count > 0 {
            segments[key] = lines
        }
        
    }
    return segments
}



private final class Arguments {
    let context: AccountContext
    let mode: EmojiesController.Mode
    let send:(StickerPackItem, StickerPackCollectionInfo?, Int32?)->Void
    let sendEmoji:(String)->Void
    let selectEmojiSegment:(EmojiSegment)->Void
    let viewSet:(StickerPackCollectionInfo)->Void
    let showAllItems:(Int64)->Void
    let openPremium:()->Void
    let installPack:(StickerPackCollectionInfo, [StickerPackItem])->Void
    let clearRecent:()->Void
    init(context: AccountContext, mode: EmojiesController.Mode, send:@escaping(StickerPackItem, StickerPackCollectionInfo?, Int32?)->Void, sendEmoji:@escaping(String)->Void, selectEmojiSegment:@escaping(EmojiSegment)->Void, viewSet:@escaping(StickerPackCollectionInfo)->Void, showAllItems:@escaping(Int64)->Void, openPremium:@escaping()->Void, installPack:@escaping(StickerPackCollectionInfo,  [StickerPackItem])->Void, clearRecent:@escaping()->Void) {
        self.context = context
        self.send = send
        self.sendEmoji = sendEmoji
        self.selectEmojiSegment = selectEmojiSegment
        self.viewSet = viewSet
        self.showAllItems = showAllItems
        self.openPremium = openPremium
        self.installPack = installPack
        self.mode = mode
        self.clearRecent = clearRecent
    }
}

private struct State : Equatable {

    struct EmojiState : Equatable {
        var selected: EmojiSegment?
    }
    
    struct Section : Equatable {
        var info: StickerPackCollectionInfo
        var items:[StickerPackItem]
        var installed: Bool
    }
    var sections:[Section]
    var peer: PeerEquatable?
    var emojiState: EmojiState = .init(selected: nil)
    var revealed:[Int64: Bool] = [:]
    var search: [String]? = nil
    var reactions: AvailableReactions? = nil
    var recentStatusItems: [RecentMediaItem] = []
    var featuredStatusItems: [RecentMediaItem] = []
    
    var recentReactionsItems: [RecentReactionItem] = []
    var topReactionsItems: [RecentReactionItem] = []

    
    var recent: RecentUsedEmoji = .defaultSettings
    var reactionSettings: ReactionSettings = .default
    
    var defaultStatuses:[StickerPackItem] = []
    var iconStatusEmoji: [TelegramMediaFile] = []
    var selectedItems: [EmojiesSectionRowItem.SelectedItem]
}

private func _id_section(_ id:Int64) -> InputDataIdentifier {
    return .init("_id_section_\(id)")
}
private func _id_pack(_ id: Int64) -> InputDataIdentifier {
    return .init("_id_pack_\(id)")
}
private func _id_emoji_segment(_ segment:Int64) -> InputDataIdentifier {
    return .init("_id_emoji_segment_\(segment)")
}
private func _id_aemoji_block(_ segment:Int64) -> InputDataIdentifier {
    return .init("_id_aemoji_block\(segment)")
}
private func _id_emoji_block(_ segment: Int64) -> InputDataIdentifier {
    return .init("_id_emoji_block_\(segment)")
}
private let _id_segments_pack = InputDataIdentifier("_id_segments_pack")
private let _id_recent_pack = InputDataIdentifier("_id_recent_pack")

private func packEntries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId:Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("left"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    let hasRecent: Bool
    switch arguments.mode {
    case .status:
        hasRecent = !state.recentStatusItems.isEmpty || !state.featuredStatusItems.isEmpty
    case .emoji:
        hasRecent = true
    case .reactions:
        hasRecent = !state.recentReactionsItems.isEmpty || !state.topReactionsItems.isEmpty
    }
    if hasRecent {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_recent_pack, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return ETabRowItem(initialSize, stableId: stableId, icon: theme.icons.emojiRecentTab, iconSelected: theme.icons.emojiRecentTabActive)
        }))
        index += 1
    }
    
   

    if arguments.mode == .emoji {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_segments_pack, equatable: InputDataEquatable(state.emojiState), comparable: nil, item: { initialSize, stableId in
            return EmojiTabsItem(initialSize, stableId: stableId, segments: EmojiSegment.all, selected: state.emojiState.selected, select: arguments.selectEmojiSegment)
        }))
        index += 1
    }
    
    
    for section in state.sections {
        let isPremium = section.items.contains(where: { $0.file.isPremiumEmoji })
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_pack(section.info.id.id), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return StickerPackRowItem(initialSize, stableId: stableId, packIndex: 0, isPremium: isPremium, installed: section.installed, context: arguments.context, info: section.info, topItem: section.items.first)
        }))
        index += 1
    }
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("right"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 6, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    return entries
}



private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
//    entries.append(.sectionId(sectionId, type: .custom(10)))
//    sectionId += 1
    
    if arguments.mode != .reactions {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralRowItem(initialSize, height: 46, stableId: stableId, backgroundColor: .clear)
        }))
        index += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: .clear)
        }))
        index += 1
    }
    
    
//    entries.append(.sectionId(sectionId, type: .custom(46)))
//    sectionId += 1
    
    var e = emojiesInstance
    e[EmojiSegment.Recent] = state.recent.emojies
    let seg = segments(e, skinModifiers: state.recent.skinModifiers)
    let seglist = seg.map { (key,_) -> EmojiSegment in
        return key
    }.sorted(by: <)
    
    
    let isPremium = state.peer?.peer.isPremium == true
    
    let recentDict:[MediaId: StickerPackItem] = state.sections.reduce([:], { current, value in
        return current + value.items.toDictionary(with: { item in
            return item.file.fileId
        })
    })
    let recentAnimated:[StickerPackItem] = state.recent.animated.compactMap { mediaId in
        if let item = recentDict[mediaId] {
            if !item.file.isPremiumEmoji || isPremium {
                return item
            }
        }
        return nil
    }
    
    if let search = state.search {
        
        if !search.isEmpty {
            
            let lines: [[NSAttributedString]] = search.chunks(8).map {
                return $0.map { .initialize(string: $0, font: .normal(26.0)) }
            }

            
            if arguments.mode == .emoji {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_e_stick"), equatable: InputDataEquatable(search), comparable: nil, item: { initialSize, stableId in
                    return EStickItem(initialSize, stableId: stableId, segmentName: strings().emojiSearchEmoji)
                }))
                index += 1
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_e"), equatable: InputDataEquatable(search), comparable: nil, item: { initialSize, stableId in
                    return EBlockItem(initialSize, stableId: stableId, attrLines: lines, segment: .Recent, account: arguments.context.account, selectHandler: arguments.sendEmoji)
                }))
                index += 1
                
            }
            
            var animatedEmoji:[StickerPackItem] = state.sections.reduce([], { current, value in
                return current + value.items.filter { item in
                    for key in item.getStringRepresentationsOfIndexKeys() {
                        if search.contains(key) {
                            return true
                        }
                    }
                    return false
                }
            })
            
            let statuses = state.iconStatusEmoji + state.recentStatusItems.map { $0.media } + state.featuredStatusItems.map { $0.media }
            var contains:Set<MediaId> = Set()
            let normalized:[StickerPackItem] = statuses.filter { item in
                let text = item.customEmojiText ?? item.stickerText ?? ""
                if !contains.contains(item.fileId), search.contains(text) {
                    contains.insert(item.fileId)
                    return true
                }
                return false
            }.map { value in
                return StickerPackItem(index: .init(index: 0, id: 0), file: value, indexKeys: [])
            }
            for item in normalized {
                if !animatedEmoji.contains(where: { $0.file.fileId == item.file.fileId }) {
                    animatedEmoji.append(item)
                }
            }
            
            if !animatedEmoji.isEmpty {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_ae_stick"), equatable: InputDataEquatable(search), comparable: nil, item: { initialSize, stableId in
                    return EStickItem(initialSize, stableId: stableId, segmentName: strings().emojiSearchAnimatedEmoji)
                }))
                index += 1
                
                                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_ae"), equatable: InputDataEquatable(animatedEmoji), comparable: nil, item: { initialSize, stableId in
                    return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: true, installed: false, info: nil, items: animatedEmoji, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send)
                }))
                index += 1
                
            } else if arguments.mode == .status {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_empty"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                    return SearchEmptyRowItem.init(initialSize, stableId: stableId)
                }))
                index += 1
            }
        } else {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("search_empty"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
                return SearchEmptyRowItem.init(initialSize, stableId: stableId)
            }))
            index += 1
        }
        
    } else {
        for key in seglist {
            
            if key == .Recent, arguments.mode == .reactions {
                
                
                var reactionsRecent:[StickerPackItem] = []
                var reactionsPopular:[StickerPackItem] = []
                
                
                var recent:[RecentReactionItem] = []
                var popular:[RecentReactionItem] = []
                let perline: Int = 8
//                if arguments.context.isPremium {
                
                let top = state.topReactionsItems.filter { value in
                    if arguments.context.isPremium {
                        return true
                    } else {
                        return !value.content.reaction.string.isEmpty
                    }
                }
                popular = Array(top.prefix(perline * 2))
                recent = state.recentReactionsItems
                
                
                for item in state.topReactionsItems {
                    let recentContains = recent.contains(where: { $0.id.id == item.id.id })
                    let popularContains = popular.contains(where: { $0.id.id == item.id.id })
                    
                    if !recentContains && !popularContains {
                        if state.recentReactionsItems.isEmpty {
                            switch item.content {
                            case .builtin:
                                recent.append(item)
                            default:
                                break
                            }
                        } else {
                            recent.append(item)
                        }
                    }
                }
                
                if let reactions = state.reactions?.reactions {
                    for reaction in reactions {
                        let recentContains = recent.contains(where: { $0.content.reaction == reaction.value })
                        let popularContains = popular.contains(where: { $0.content.reaction == reaction.value })
                        if !recentContains && !popularContains {
                            switch reaction.value {
                            case let .builtin(emoji):
                                recent.append(.init(.builtin(emoji)))
                            default:
                                break
                            }
                        }
                    }
                }
                
                recent = Array(recent.prefix(perline * 10))
//                } else {
//                    popular = Array(state.topReactionsItems.prefix(perline * 2))
//                    for item in state.recentReactionsItems {
//                        let popularContains = popular.contains(where: { $0.id.id == item.id.id })
//
//                        if !popularContains {
//                            popular.append(item)
//                        }
//                    }
//                    for item in state.topReactionsItems {
//                        let popularContains = popular.contains(where: { $0.id.id == item.id.id })
//                        if !popularContains {
//                            popular.append(item)
//                        }
//                    }
//                    popular = Array(popular.prefix(perline * 10))
//                }
                
                let transform:(RecentReactionItem)->StickerPackItem? = { item in
                    switch item.content {
                    case let .builtin(emoji):
                        let builtin = state.reactions?.reactions.first(where: {
                            $0.value.string == emoji
                        })
                        if let builtin = builtin {
                            return .init(index: .init(index: 0, id: 0), file: builtin.selectAnimation, indexKeys: [])
                        }
                    case let .custom(file):
                        return .init(index: .init(index: -1, id: 0), file: file, indexKeys: [])
                    }
                    return nil
                }
                
                reactionsPopular.append(contentsOf: popular.compactMap(transform))
                reactionsRecent.append(contentsOf: recent.compactMap(transform))
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(EmojiSegment.RecentAnimated.rawValue), equatable: InputDataEquatable(reactionsPopular), comparable: nil, item: { initialSize, stableId in
                    return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: true, installed: true, info: nil, items: reactionsPopular, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send)
                }))
                index += 1
                
                if !reactionsRecent.isEmpty {
                    
                    let containsCustom = reactionsRecent.contains(where: { $0.index.index == -1 })
                    if containsCustom {
                        let text = strings().reactionsRecentlyUsed
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_segment(-1), equatable: InputDataEquatable(text), comparable: nil, item: { initialSize, stableId in
                            return EStickItem(initialSize, stableId: stableId, segmentName: text, clearCallback: arguments.clearRecent)
                        }))
                        index += 1
                    } else {
                        let text = strings().reactionsPopular
                        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_segment(-1), equatable: InputDataEquatable(text), comparable: nil, item: { initialSize, stableId in
                            return EStickItem(initialSize, stableId: stableId, segmentName: text )
                        }))
                        index += 1
                    }
                    
                    
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(-1), equatable: InputDataEquatable(reactionsRecent), comparable: nil, item: { initialSize, stableId in
                        return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: true, installed: true, info: nil, items: reactionsRecent, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send)
                    }))
                    index += 1
                }
                
            }
            
            let statuses = state.recentStatusItems + state.featuredStatusItems
            var contains:Set<MediaId> = Set()
            var normalized:[StickerPackItem] = statuses.filter { item in
                if !contains.contains(item.media.fileId) {
                    contains.insert(item.media.fileId)
                    return true
                }
                return false
            }.map { value in
                return StickerPackItem(index: .init(index: 0, id: 0), file: value.media, indexKeys: [])
            }
            
            
            if key == .Recent, arguments.mode == .status {
                
                let string: String
                if let expiryDate = state.peer?.peer.emojiStatus?.expirationDate {
                    string = strings().customStatusExpires(timeIntervalString(Int(expiryDate - arguments.context.timestamp)))
                } else {
                    string = strings().customStatusExpiresPromo
                }
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("_id_status_status"), equatable: .init(string), comparable: nil, item: { initialSize, stableId in
                    return EmojiStatusStatusRowItem(initialSize, stableId: stableId, status: string.uppercased(), viewType: .textTopItem)
                }))
                index += 1
                
                let def = TelegramMediaFile(fileId: .init(namespace: 0, id: 0), partialReference: nil, resource: LocalBundleResource(name: "Icon_Premium_StickerPack", ext: ""), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "bundle/jpeg", size: nil, attributes: [])
                
                normalized.insert(.init(index: .init(index: 0, id: 0), file: def, indexKeys: []), at: 0)
                
                normalized.insert(contentsOf: state.iconStatusEmoji.map {
                    .init(index: .init(index: 0, id: 0), file: $0, indexKeys: [])
                }, at: 1)
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(EmojiSegment.RecentAnimated.rawValue), equatable: InputDataEquatable(normalized), comparable: nil, item: { initialSize, stableId in
                    return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: true, installed: true, info: nil, items: normalized, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send)
                }))
                index += 1
            }
            
            if key == .Recent, !recentAnimated.isEmpty, arguments.mode == .emoji {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(EmojiSegment.RecentAnimated.rawValue), equatable: InputDataEquatable(recentAnimated), comparable: nil, item: { initialSize, stableId in
                    return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: true, installed: true, info: nil, items: recentAnimated, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send)
                }))
                index += 1
            }
            
            if key != .Recent || !recentAnimated.isEmpty, arguments.mode == .emoji {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_segment(key.rawValue), equatable: InputDataEquatable(key), comparable: nil, item: { initialSize, stableId in
                    return EStickItem(initialSize, stableId: stableId, segmentName:key.localizedString)
                }))
                index += 1
            }
            
           
            if arguments.mode == .emoji {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_emoji_block(key.rawValue), equatable: InputDataEquatable(key), comparable: nil, item: { initialSize, stableId in
                    return EBlockItem(initialSize, stableId: stableId, attrLines: seg[key]!, segment: key, account: arguments.context.account, selectHandler: arguments.sendEmoji)
                }))
                index += 1
            }
            
        }
        
        for section in state.sections {
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_aemoji_block(section.info.id.id), equatable: InputDataEquatable(section.info), comparable: nil, item: { initialSize, stableId in
                return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: .clear)
            }))
            index += 1
            
            
            struct Tuple : Equatable {
                let section: State.Section
                let isPremium: Bool
                let revealed: Bool
            }
            
            let tuple = Tuple(section: section, isPremium: state.peer?.peer.isPremium ?? false, revealed: state.revealed[section.info.id.id] != nil)
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_section(section.info.id.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return EmojiesSectionRowItem(initialSize, stableId: stableId, context: arguments.context, revealed: tuple.revealed, installed: section.installed, info: section.info, items: section.items, mode: arguments.mode.itemMode, selectedItems: state.selectedItems, callback: arguments.send, viewSet: { info in
                    arguments.viewSet(info)
                }, showAllItems: {
                    arguments.showAllItems(section.info.id.id)
                }, openPremium: arguments.openPremium, installPack: arguments.installPack)
            }))
            index += 1
        }
    }
    
    
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("bottom_section"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 10, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("bottom"), equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GeneralRowItem(initialSize, height: 46, stableId: stableId, backgroundColor: .clear)
    }))
    index += 1
    
    // entries
    
//    entries.append(.sectionId(sectionId, type: .normal))
//    sectionId += 1
    
    return entries
}

final class AnimatedEmojiesView : View {
    let tableView = TableView()
    let packsView = HorizontalTableView(frame: NSZeroRect)
    private let borderView = View()
    private let tabs = View()
    private let selectionView: View = View(frame: NSMakeRect(0, 0, 36, 36))
    
    let searchView = SearchView(frame: .zero)
    private let searchContainer = View()
    private let searchBorder = View()
    
    private var mode: EmojiesController.Mode = .emoji

    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.packsView.getBackgroundColor = {
            .clear
        }
        self.tableView.getBackgroundColor = {
            .clear
        }
        addSubview(self.tableView)

        searchContainer.addSubview(searchView)
        searchContainer.addSubview(searchBorder)
        addSubview(searchContainer)
        
        tabs.addSubview(selectionView)
        tabs.addSubview(self.packsView)
        addSubview(self.borderView)
        addSubview(tabs)
        
        self.packsView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateSelectionState(animated: false)
        }))
        
        self.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: false, { [weak self] position in
            self?.updateScrollerSearch()
        }))
        
        
        self.layout()
    }
 
    
    override func layout() {
        super.layout()
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    private func updateScrollerSearch() {
        self.updateLayout(self.frame.size, transition: .immediate)
    }
    
    func updateLayout(_ size: NSSize, transition: ContainedViewLayoutTransition) {
        
        let initial: CGFloat = searchState?.state == .Focus ? -46 : 0

        transition.updateFrame(view: tabs, frame: NSMakeRect(0, initial, size.width, 46))
        transition.updateFrame(view: packsView, frame: tabs.focus(NSMakeSize(size.width, 36)))
        transition.updateFrame(view: borderView, frame: NSMakeRect(0, tabs.frame.maxY, size.width, .borderSize))

        
        let searchDest = tableView.rectOf(index: 0).minY + (tableView.clipView.destination?.y ?? tableView.documentOffset.y)
                
        transition.updateFrame(view: searchContainer, frame: NSMakeRect(0, min(max(tabs.frame.maxY - searchDest, 0), tabs.frame.maxY), size.width, 46))
        transition.updateFrame(view: searchView, frame: searchContainer.focus(NSMakeSize(size.width - 16, 30)))
        transition.updateFrame(view: searchBorder, frame: NSMakeRect(0, searchContainer.frame.height - .borderSize, size.width, .borderSize))
        
        transition.updateFrame(view: tableView, frame: NSMakeRect(0, tabs.frame.maxY, size.width, size.height))


        let alpha: CGFloat = searchState?.state == .Focus && tableView.documentOffset.y > 0 ? 1 : 0
        transition.updateAlpha(view: searchBorder, alpha: alpha)
        
        self.updateSelectionState(animated: transition.isAnimated)
        
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = mode == .reactions ? .clear : theme.colors.background
        borderView.backgroundColor = mode == .reactions ? theme.colors.grayIcon.withAlphaComponent(0.1) : theme.colors.border
        tabs.backgroundColor = mode != .reactions ? theme.colors.background : .clear
        searchContainer.backgroundColor = theme.colors.background
        searchBorder.backgroundColor = theme.colors.border
        self.searchView.updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    private var searchState: SearchState? = nil

    func updateSearchState(_ searchState: SearchState, animated: Bool) {
        self.searchState = searchState

        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        self.updateLayout(self.frame.size, transition: transition)
    }
    
    func update(sections: TableUpdateTransition, packs: TableUpdateTransition, mode: EmojiesController.Mode) {
        self.mode = mode
        self.tableView.merge(with: sections)
        self.packsView.merge(with: packs)
        
        searchContainer.isHidden = mode == .reactions
        tableView.scrollerInsets = mode == .reactions ? .init() : .init(left: 0, right: 0, top: 46, bottom: 50)

        updateSelectionState(animated: packs.animated)
        updateLocalizationAndTheme(theme: theme)
    }
    
    func updateSelectionState(animated: Bool) {
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        var animated = transition.isAnimated
        var item = packsView.selectedItem()
        if item == nil, packsView.count > 1 {
            item = packsView.item(at: 1)
            animated = false
        }

        
        guard let item = item else {
            return
        }
        let viewPoint = packsView.rectOf(item: item).origin
        
        let point = packsView.clipView.destination ?? packsView.contentOffset
        let rect = NSMakeRect(viewPoint.y - point.y, 5, item.height, packsView.frame.height)
        
        selectionView.layer?.cornerRadius = item.height == item.width && item.index != 1 ? .cornerRadius : item.width / 2
        if mode == .reactions {
            selectionView.background = theme.colors.vibrant.mixedWith(NSColor(0x000000), alpha: 0.1)
        } else {
            selectionView.background = theme.colors.grayBackground.withAlphaComponent(item.height == item.width ? 1 : 0.9)
        }
        if animated {
            selectionView.layer?.animateCornerRadius()
        }
        transition.updateFrame(view: selectionView, frame: rect)
        
    }
    
    
    func scroll(to segment: EmojiSegment, animated: Bool) {
//        if let item = packsView.item(stableId: InputDataEntryId.custom(_id_segments_pack)) {
//            _ = self.packsView.select(item: item)
//        }
        let stableId = InputDataEntryId.custom(_id_emoji_segment(segment.rawValue))
        tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
        updateSelectionState(animated: animated)
    }
    
    func findSegmentAndScroll(selected: TableRowItem, animated: Bool) -> EmojiSegment? {
        let stableId = selected.stableId as? InputDataEntryId
        var segment: EmojiSegment?
        if let identifier = stableId?.identifier {
            if identifier == _id_recent_pack {
                tableView.scroll(to: .up(animated))
            } else if identifier == _id_segments_pack {
                segment = EmojiSegment.People
                let stableId = InputDataEntryId.custom(_id_emoji_segment(EmojiSegment.People.rawValue))
                tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
            } else if identifier.identifier.hasPrefix("_id_pack_") {
                let collectionId = identifier.identifier.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
                if let collectionId = Int64(collectionId) {
                    let stableId = InputDataEntryId.custom(_id_aemoji_block(collectionId))
                    tableView.scroll(to: .top(id: stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
                    
                    let packStableId = InputDataEntryId.custom(_id_pack(collectionId))
                    packsView.scroll(to: .center(id: packStableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))

                }
            }
        }
        updateSelectionState(animated: true)
        return segment
    }
    
    func selectBestPack() -> EmojiSegment? {
        
        guard tableView.count > 1, tableView.visibleRows().location != NSNotFound else {
            return nil
        }
        
        let stableId = tableView.item(at: max(1, tableView.visibleRows().location)).stableId
        var _stableId: AnyHashable?
        var _segment: EmojiSegment?

        if let stableId = stableId as? InputDataEntryId, let identifier = stableId.identifier {
            let identifier = identifier.identifier
            
            if identifier.hasPrefix("_id_emoji_segment_") || identifier.hasPrefix("_id_emoji_block_") {
                if let segmentId = Int64(identifier.suffix(1)), let segment = EmojiSegment(rawValue: segmentId) {
                    switch segment {
                    case .Recent, .RecentAnimated:
                        _stableId = InputDataEntryId.custom(_id_recent_pack)
                    default:
                        _stableId = InputDataEntryId.custom(_id_segments_pack)
                    }
                    _segment = segment
                }
            } else if identifier.hasPrefix("_id_section_") {
                let collectionId = identifier.trimmingCharacters(in: CharacterSet(charactersIn: "1234567890").inverted)
                if let collectionId = Int64(collectionId) {
                    _stableId = InputDataEntryId.custom(_id_pack(collectionId))
                }
            }
        }
        if let stableId = _stableId, let item = packsView.item(stableId: stableId) {
            _ = self.packsView.select(item: item)
            self.packsView.scroll(to: .center(id: stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0))
        }
        updateSelectionState(animated: true)
        return _segment
    }
    
    func scroll(to info: StickerPackCollectionInfo, animated: Bool) {
        let item = self.packsView.item(stableId: InputDataEntryId.custom(_id_pack(info.id.id)))
        if let item = item {
            _ = self.packsView.select(item: item)
            self.packsView.scroll(to: .center(id: item.stableId, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
            self.tableView.scroll(to: .top(id: InputDataEntryId.custom(_id_aemoji_block(info.id.id)), innerId: nil, animated: animated, focus: .init(focus: false), inset: 0))
            
            updateSelectionState(animated: animated)

        }
    }
}

final class EmojiesController : TelegramGenericViewController<AnimatedEmojiesView>, TableViewDelegate {
    private let disposable = MetaDisposable()
    
    private var interactions: EntertainmentInteractions?
    private weak var chatInteraction: ChatInteraction?
    
    private var updateState: (((State) -> State) -> Void)? = nil
    private var scrollOnAppear:(()->Void)? = nil
    
    var makeSearchCommand:((ESearchCommand)->Void)?
    private let searchValue = ValuePromise<SearchState>(.init(state: .None, request: nil))
    private var searchState: SearchState = .init(state: .None, request: nil) {
        didSet {
            self.searchValue.set(searchState)
        }
    }
    
    
    private func updateSearchState(_ state: SearchState) {
        self.searchState = state
        if !state.request.isEmpty {
            self.makeSearchCommand?(.loading)
        }
        if self.isLoaded() == true {
            self.genericView.updateSearchState(state, animated: true)
        }
    }
    
    enum Mode {
        case emoji
        case status
        case reactions
        
        var itemMode: EmojiesSectionRowItem.Mode {
            switch self {
            case .reactions:
                return .reactions
            case .status:
                return .statuses
            default:
                return .panel
            }
        }
    }
    private let mode: Mode
    
    var closeCurrent:(()->Void)? = nil
    var animateAppearance:(([TableRowItem])->Void)? = nil
    
    private let selectedItems: [EmojiesSectionRowItem.SelectedItem]
    
    init(_ context: AccountContext, mode: Mode = .emoji, selectedItems: [EmojiesSectionRowItem.SelectedItem] = []) {
        self.mode = mode
        self.selectedItems = selectedItems
        super.init(context)
        _frameRect = NSMakeRect(0, 0, 350, 300)
        self.bar = .init(height: 0)

    }
    
    deinit {
        disposable.dispose()
    }
    
    private func updatePackReorder(_ sections: [State.Section]) {
        let resortRange: NSRange = NSMakeRange(3, genericView.packsView.count - 4 - sections.filter { !$0.installed }.count)
        
        let context = self.context
        
        if resortRange.length > 0 {
            self.genericView.packsView.resortController = TableResortController(resortRange: resortRange, start: { _ in }, resort: { _ in }, complete: { fromIndex, toIndex in
                
                if fromIndex == toIndex {
                    return
                }
                
                let fromSection = sections[fromIndex - resortRange.location]
                let toSection = sections[toIndex - resortRange.location]

                let referenceId: ItemCollectionId = toSection.info.id
                
                let _ = (context.account.postbox.transaction { transaction -> Void in
                    var infos = transaction.getItemCollectionsInfos(namespace: Namespaces.ItemCollection.CloudEmojiPacks)
                    var reorderInfo: ItemCollectionInfo?
                    for i in 0 ..< infos.count {
                        if infos[i].0 == fromSection.info.id {
                            reorderInfo = infos[i].1
                            infos.remove(at: i)
                            break
                        }
                    }
                    if let reorderInfo = reorderInfo {
                        var inserted = false
                        for i in 0 ..< infos.count {
                            if infos[i].0 == referenceId {
                                if fromIndex < toIndex {
                                    infos.insert((fromSection.info.id, reorderInfo), at: i + 1)
                                } else {
                                    infos.insert((fromSection.info.id, reorderInfo), at: i)
                                }
                                inserted = true
                                break
                            }
                        }
                        if !inserted {
                            infos.append((fromSection.info.id, reorderInfo))
                        }
                        addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: Namespaces.ItemCollection.CloudEmojiPacks, content: .sync, noDelay: false)
                        transaction.replaceItemCollectionInfos(namespace: Namespaces.ItemCollection.CloudEmojiPacks, itemCollectionInfos: infos)
                    }
                 } |> deliverOnMainQueue).start(completed: { })
                
            })
        } else {
            self.genericView.packsView.resortController = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        genericView.packsView.delegate = self
        
        let searchInteractions = SearchInteractions({ [weak self] state, _ in
            self?.updateSearchState(state)
        }, { [weak self] state in
            self?.updateSearchState(state)
        })
        
        genericView.searchView.searchInteractions = searchInteractions
        
        
        let scrollToOnNextTransaction: Atomic<StickerPackCollectionInfo?> = Atomic(value: nil)
        let scrollToOnNextAppear: Atomic<StickerPackCollectionInfo?> = Atomic(value: nil)

        let context = self.context
        let mode = self.mode
        let actionsDisposable = DisposableSet()
        
        let initialState = State(sections: [], selectedItems: self.selectedItems)
        
        let statePromise = ValuePromise<State>(ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((State) -> State) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        self.updateState = { f in
            updateState(f)
        }
        
        self.scrollOnAppear = { [weak self] in
            if let info = scrollToOnNextAppear.swap(nil) {
                self?.genericView.scroll(to: info, animated: false)
            }
        }
        
        let arguments = Arguments(context: context, mode: self.mode, send: { [weak self] item, info, timeout in
            switch mode {
            case .emoji:
                if !context.isPremium && item.file.isPremiumEmoji, context.peerId != self?.chatInteraction?.peerId {
                    showModalText(for: context.window, text: strings().emojiPackPremiumAlert, callback: { _ in
                        showModal(with: PremiumBoardingController(context: context, source: .premium_stickers), for: context.window)
                    })
                } else {
                    self?.interactions?.sendAnimatedEmoji(item, info, nil)
                }
                _ = scrollToOnNextAppear.swap(info)
            case .status:
                self?.interactions?.sendAnimatedEmoji(item, nil, timeout)
            case .reactions:
                self?.interactions?.sendAnimatedEmoji(item, nil, nil)
            }
            
        }, sendEmoji: { [weak self] emoji in
            self?.interactions?.sendEmoji(emoji)
        }, selectEmojiSegment: { [weak self] segment in
            updateState { current in
                var current = current
                current.emojiState.selected = segment
                return current
            }
            self?.genericView.scroll(to: segment, animated: true)
        }, viewSet: { info in
            showModal(with: StickerPackPreviewModalController(context, peerId: nil, references: [.emoji(.name(info.shortName))]), for: context.window)
        }, showAllItems: { id in
            updateState { current in
                var current = current
                current.revealed[id] = true
                return current
            }
        }, openPremium: { [weak self] in
            showModal(with: PremiumBoardingController(context: context, source: .premium_emoji), for: context.window)
            self?.closeCurrent?()
        }, installPack: { info, items in
            _ = scrollToOnNextTransaction.swap(info)
            let signal = context.engine.stickers.addStickerPackInteractively(info: info, items: items) |> deliverOnMainQueue
            _ = signal.start()
        }, clearRecent: {
            _ = context.engine.stickers.clearRecentlyUsedReactions().start()
        })
        
        let selectUpdater = { [weak self] in
            if self?.genericView.tableView.clipView.isAnimateScrolling == true {
                return
            }
            
            let innerSegment = self?.genericView.selectBestPack()
            
            updateState { current in
                var current = current
                current.emojiState.selected = innerSegment
                return current
            }
        }
        
        genericView.tableView.addScroll(listener: .init(dispatchWhenVisibleRangeUpdated: true, { position in
            selectUpdater()
        }))
        
        
        let search = self.searchValue.get() |> distinctUntilChanged(isEqual: { prev, new in
            return prev.request == new.request
        }) |> mapToSignal { state -> Signal<[String]?, NoError> in
            if state.request.isEmpty {
                return .single(nil)
            } else {
                return context.sharedContext.inputSource.searchEmoji(postbox: context.account.postbox, engine: context.engine, sharedContext: context.sharedContext, query: state.request, completeMatch: false, checkPrediction: false) |> map(Optional.init) |> delay(0.2, queue: .concurrentDefaultQueue())
            }
        }
        
        let combined = statePromise.get()
        
        let signal:Signal<(sections: InputDataSignalValue, packs: InputDataSignalValue, state: State), NoError> = combined |> deliverOnPrepareQueue |> map { state in
            let sections = InputDataSignalValue(entries: entries(state, arguments: arguments))
            let packs = InputDataSignalValue(entries: packEntries(state, arguments: arguments))
            return (sections: sections, packs: packs, state: state)
        }
        
        
        let previousSections: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let previousPacks: Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])

        let initialSize = self.atomicSize
        
        let onMainQueue: Atomic<Bool> = Atomic(value: false)
        
        let inputArguments = InputDataArguments(select: { _, _ in
            
        }, dataUpdated: {
            
        })
        
        let transition: Signal<(sections: TableUpdateTransition, packs: TableUpdateTransition, state: State), NoError> = combineLatest(queue: .mainQueue(), appearanceSignal, signal) |> mapToQueue { appearance, state in
            let sectionEntries = state.sections.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let packEntries = state.packs.entries.map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})

            let onMain = onMainQueue.swap(false)
            
            
            
            let sectionsTransition = prepareInputDataTransition(left: previousSections.swap(sectionEntries), right: sectionEntries, animated: state.sections.animated, searchState: state.sections.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)
            
            
            let packsTransition = prepareInputDataTransition(left: previousPacks.swap(packEntries), right: packEntries, animated: state.packs.animated, searchState: state.packs.searchState, initialSize: initialSize.modify{$0}, arguments: inputArguments, onMainQueue: onMain)

            return combineLatest(sectionsTransition, packsTransition) |> map { values in
                return (sections: values.0, packs: values.1, state: state.state)
            }
            
        } |> deliverOnMainQueue
        
        disposable.set(transition.start(next: { [weak self] values in
            self?.genericView.update(sections: values.sections, packs: values.packs, mode: mode)
            
            selectUpdater()

            if let info = scrollToOnNextTransaction.swap(nil) {
                self?.genericView.scroll(to: info, animated: false)
            }
            
            self?.updatePackReorder(values.state.sections)
            var visibleItems:[TableRowItem] = []
            if self?.didSetReady == false {
                self?.genericView.packsView.enumerateVisibleItems(with: { item in
                    visibleItems.append(item)
                    return true
                })
                self?.genericView.tableView.enumerateVisibleItems(with: { item in
                    visibleItems.append(item)
                    return true
                })
            }
            self?.readyOnce()
            if !visibleItems.isEmpty {
                self?.animateAppearance?(visibleItems)
            }
        }))
        
        let updateSearchCommand:()->Void = { [weak self] in
            self?.makeSearchCommand?(.normal)

        }
        
        /*
         public static let CloudRecentStatusEmoji: Int32 = 17
         public static let CloudFeaturedStatusEmoji: Int32 = 18

         */
        
        var orderedItemListCollectionIds: [Int32] = []
        var iconStatusEmoji: Signal<[TelegramMediaFile], NoError> = .single([])


        if mode == .status {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudFeaturedStatusEmoji)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentStatusEmoji)
            
            
            iconStatusEmoji = context.engine.stickers.loadedStickerPack(reference: .iconStatusEmoji, forceActualized: false)
            |> map { result -> [TelegramMediaFile] in
                switch result {
                case let .result(_, items, _):
                    return items.map(\.file)
                default:
                    return []
                }
            }
            |> take(1)

            
        } else if mode == .reactions {
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudRecentReactions)
            orderedItemListCollectionIds.append(Namespaces.OrderedItemList.CloudTopReactions)
        }

        
 
        let emojies = context.account.postbox.itemCollectionsView(orderedItemListCollectionIds: orderedItemListCollectionIds, namespaces: [Namespaces.ItemCollection.CloudEmojiPacks], aroundIndex: nil, count: 2000000)

        
        let reactions = context.reactions.stateValue
        
        let reactionSettings = context.account.postbox.preferencesView(keys: [PreferencesKeys.reactionSettings])
           |> map { preferencesView -> ReactionSettings in
               let reactionSettings: ReactionSettings
               if let entry = preferencesView.values[PreferencesKeys.reactionSettings], let value = entry.get(ReactionSettings.self) {
                   reactionSettings = value
               } else {
                   reactionSettings = .default
               }
               return reactionSettings
           }
        
        let emojiStatuses = context.engine.stickers.loadedStickerPack(reference: .name("StatusEmojiWhite"), forceActualized: false)
        
        actionsDisposable.add(combineLatest(emojies, context.account.viewTracker.featuredEmojiPacks(), context.account.postbox.peerView(id: context.peerId), search, reactions, recentUsedEmoji(postbox: context.account.postbox), reactionSettings, emojiStatuses, iconStatusEmoji).start(next: { view, featured, peerView, search, reactions, recentEmoji, reactionSettings, emojiStatuses, iconStatusEmoji in
            
            
            var featuredStatusEmoji: OrderedItemListView?
            var recentStatusEmoji: OrderedItemListView?
            var recentReactionsView: OrderedItemListView?
            var topReactionsView: OrderedItemListView?
            for orderedView in view.orderedItemListsViews {
                if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedStatusEmoji {
                    featuredStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudFeaturedStatusEmoji {
                    recentStatusEmoji = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudRecentReactions {
                    recentReactionsView = orderedView
                } else if orderedView.collectionId == Namespaces.OrderedItemList.CloudTopReactions {
                    topReactionsView = orderedView
                }
            }
            var recentStatusItems:[RecentMediaItem] = []
            var featuredStatusItems:[RecentMediaItem] = []
            var recentReactionsItems:[RecentReactionItem] = []
            var topReactionsItems:[RecentReactionItem] = []

            if let recentStatusEmoji = recentStatusEmoji {
                for item in recentStatusEmoji.items {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    recentStatusItems.append(item)
                }
            }
            if let featuredStatusEmoji = featuredStatusEmoji {
                for item in featuredStatusEmoji.items {
                    guard let item = item.contents.get(RecentMediaItem.self) else {
                        continue
                    }
                    featuredStatusItems.append(item)
                }
            }
            if let recentReactionsView = recentReactionsView {
                for item in recentReactionsView.items {
                    guard let item = item.contents.get(RecentReactionItem.self) else {
                        continue
                    }
                    recentReactionsItems.append(item)
                }
            }
            if let topReactionsView = topReactionsView {
                for item in topReactionsView.items {
                    guard let item = item.contents.get(RecentReactionItem.self) else {
                        continue
                    }
                    topReactionsItems.append(item)
                }
            }
            

            
            updateState { current in
                var current = current
                var sections: [State.Section] = []
                for (_, info, _) in view.collectionInfos {
                    var files: [StickerPackItem] = []
                    if let info = info as? StickerPackCollectionInfo {
                        let items = view.entries
                        for (i, entry) in items.enumerated() {
                            if entry.index.collectionId == info.id {
                                if let item = view.entries[i].item as? StickerPackItem {
                                    files.append(item)
                                }
                            }
                        }
                        if !files.isEmpty {
                            sections.append(.init(info: info, items: files, installed: true))
                        }
                    }
                }
                for item in featured {
                    let contains = sections.contains(where: { $0.info.id == item.info.id })
                    if !contains {
                        sections.append(.init(info: item.info, items: item.topItems, installed: false))
                    }
                }
                if let peer = peerView.peers[peerView.peerId] {
                    current.peer = .init(peer)
                }
                current.featuredStatusItems = featuredStatusItems
                current.recentStatusItems = recentStatusItems
                current.sections = sections
                current.search = search
                current.reactions = reactions
                current.recent = recentEmoji
                current.topReactionsItems = topReactionsItems
                current.recentReactionsItems = recentReactionsItems
                current.reactionSettings = reactionSettings
                current.iconStatusEmoji = iconStatusEmoji
                switch emojiStatuses {
                case let .result(_, items, _):
                    current.defaultStatuses = items
                default:
                    break
                }
                return current
            }
            DispatchQueue.main.async {
                updateSearchCommand()
            }
        }))
        

            
         self.onDeinit = {
             actionsDisposable.dispose()
             _ = previousSections.swap([])
             _ = previousPacks.swap([])
         }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.scrollOnAppear?()
    }
    
    func update(with interactions:EntertainmentInteractions?, chatInteraction: ChatInteraction) {
        self.interactions = interactions
        self.chatInteraction = chatInteraction
    }
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    func isSelectable(row: Int, item: TableRowItem) -> Bool {
        return true
    }
    
    func selectionWillChange(row: Int, item: TableRowItem, byClick: Bool) -> Bool {
        return !(item is GeneralRowItem)
    }
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) {
        
        if byClick {
            let segment = genericView.findSegmentAndScroll(selected: item, animated: true)
            
            updateState? { current in
                var current = current
                current.emojiState.selected = segment
                return current
            }
        }
    }
    
    override func scrollup(force: Bool = false) {
        genericView.tableView.scroll(to: .up(true))
    }
    
    override var supportSwipes: Bool {
        return !genericView.packsView._mouseInside()
    }
}
