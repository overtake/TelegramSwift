//
//  BoostChannelStatsController.swift
//  Telegram
//
//  Created by Mike Renoir on 03.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox



private final class BoostRowItem : TableRowItem {
    fileprivate let context: AccountContext
    private let _stableId: AnyHashable
    fileprivate let state: State
    init(_ initialSize: NSSize, stableId: AnyHashable, state: State, context: AccountContext) {
        self.context = context
        self.state = state
        self._stableId = stableId
        super.init(initialSize)
    }
    
    var blockWidth: CGFloat {
        return min(600, self.width - 40)
    }
    
    override var stableId: AnyHashable {
        return _stableId
    }
    
    
    override var height: CGFloat {
        return 100
    }
    
    override func viewClass() -> AnyClass {
        return BoostRowItemView.self
    }
}

private final class BoostRowItemView : TableRowView {
    private let lineView = LineView(frame: .zero)
    private let top = TypeView(frame: .zero)

    
    private class LineView: View {
        
        private let currentLevel = TextView()
        private let nextLevel = TextView()

        private let nextLevel_background = View()
        private let currentLevel_background = PremiumGradientView(frame: .zero)
        
        private var state: State?
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(nextLevel_background)
            addSubview(currentLevel_background)
            addSubview(nextLevel)
            addSubview(currentLevel)
            nextLevel.userInteractionEnabled = false
            currentLevel.userInteractionEnabled = false
            
            nextLevel.isSelectable = false
            currentLevel.isSelectable = false
        }
        
        func update(_ state: State, context: AccountContext, transition: ContainedViewLayoutTransition) {
            
            self.state = state
            
            let width = frame.width * state.percentToNext

            
            var normalCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel)", color: theme.colors.text, font: .medium(13)))
            normalCountLayout.measure(width: .greatestFiniteMagnitude)
            
            if width >= 10 + normalCountLayout.layoutSize.width {
                normalCountLayout = TextViewLayout(.initialize(string: normalCountLayout.attributedString.string, color: .white, font: .medium(13)))
                normalCountLayout.measure(width: .greatestFiniteMagnitude)
            }

            currentLevel.update(normalCountLayout)

            var premiumCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel + 1)", color: theme.colors.text, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)
            
            if width >= frame.width - 10 {
                premiumCountLayout = TextViewLayout(.initialize(string: premiumCountLayout.attributedString.string, color: .white, font: .medium(13)))
                premiumCountLayout.measure(width: .greatestFiniteMagnitude)
            }

            nextLevel.update(premiumCountLayout)
            
            nextLevel_background.backgroundColor = theme.colors.background
            
            self.updateLayout(size: self.frame.size, transition: transition)
        }
        
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            guard let state = self.state else {
                return
            }
            
            let width = frame.width * state.percentToNext

            transition.updateFrame(view: currentLevel, frame: currentLevel.centerFrameY(x: 10))
            transition.updateFrame(view: nextLevel, frame: nextLevel.centerFrameY(x: bounds.width - 10 - nextLevel.frame.width))

            transition.updateFrame(view: nextLevel_background, frame: NSMakeRect(width, 0, size.width - width, frame.height))
            transition.updateFrame(view: currentLevel_background, frame: NSMakeRect(0, 0, width, frame.height))
            
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private class TypeView : View {
        private let backgrounView = ImageView()
        
        private let textView = DynamicCounterTextView(frame: .zero)
        private let imageView = ImageView()
        private let container = View()
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(backgrounView)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
        }
        
        override func layout() {
            super.layout()
            backgrounView.frame = bounds
            container.centerX()
            imageView.centerY(x: -3)
            textView.centerY(x: imageView.frame.maxX)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        
        func update(state: State, context: AccountContext, transition: ContainedViewLayoutTransition) -> NSSize {
            
            let dynamicValue = DynamicCounterTextView.make(for: "\(state.currentBoosts)", count: "\(state.currentBoosts)", font: .avatar(20), textColor: .white, width: .greatestFiniteMagnitude)
            
            textView.update(dynamicValue, animated: transition.isAnimated)
            transition.updateFrame(view: textView, frame: CGRect(origin: textView.frame.origin, size: dynamicValue.size))
            
            imageView.image = NSImage(named: "Icon_Boost_Lighting")?.precomposed()
            imageView.sizeToFit()
            
            container.setFrameSize(NSMakeSize(dynamicValue.size.width + imageView.frame.width, 40))
                        
            let size = NSMakeSize(container.frame.width + 20, 50)
            
            let image = generateImage(NSMakeSize(size.width, size.height - 10), contextGenerator: { size, ctx in
                ctx.clear(size.bounds)
               
                let path = CGMutablePath()
                path.addRoundedRect(in: NSMakeRect(0, 0, size.width, size.height), cornerWidth: size.height / 2, cornerHeight: size.height / 2)
                
                ctx.addPath(path)
                ctx.setFillColor(NSColor.black.cgColor)
                ctx.fillPath()
                
            })!
            
            let corner = generateImage(NSMakeSize(30, 10), contextGenerator: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.setFillColor(NSColor.black.cgColor)
                context.scaleBy(x: 0.333, y: 0.333)
                let _ = try? drawSvgPath(context, path: "M85.882251,0 C79.5170552,0 73.4125613,2.52817247 68.9116882,7.02834833 L51.4264069,24.5109211 C46.7401154,29.1964866 39.1421356,29.1964866 34.4558441,24.5109211 L16.9705627,7.02834833 C12.4696897,2.52817247 6.36519576,0 0,0 L85.882251,0 ")
                context.fillPath()
            })!

            let clipImage = generateImage(size, rotatedContext: { size, ctx in
                ctx.clear(size.bounds)
                ctx.draw(image, in: NSMakeRect(0, 0, image.backingSize.width, image.backingSize.height))
                
                ctx.draw(corner, in: NSMakeRect(size.bounds.focus(corner.backingSize).minX, image.backingSize.height, corner.backingSize.width, corner.backingSize.height))
            })!
            
            let fullImage = generateImage(size, contextGenerator: { size, ctx in
                ctx.clear(size.bounds)

                ctx.clip(to: size.bounds, mask: clipImage)
                
                let colors = premiumGradient.compactMap { $0?.cgColor } as NSArray
                
                let delta: CGFloat = 1.0 / (CGFloat(colors.count) - 1.0)
                
                var locations: [CGFloat] = []
                for i in 0 ..< colors.count {
                    locations.append(delta * CGFloat(i))
                }
                let colorSpace = deviceColorSpace
                let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: &locations)!
                
                ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: size.height), options: CGGradientDrawingOptions())
            })!
            
            self.backgrounView.image = fullImage
            
            
            needsLayout = true
            
            return size
        }

    }



    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.addSubview(top)
        self.addSubview(lineView)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? BoostRowItem else {
            return
        }
        
        lineView.setFrameSize(NSMakeSize(item.blockWidth, 30))
        lineView.layer?.cornerRadius = 10
        lineView.update(item.state, context: item.context, transition: .immediate)
        
        let size = top.update(state: item.state, context: item.context, transition: .immediate)
        top.setFrameSize(size)

        needsLayout = true
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = self.item as? BoostRowItem else {
            return
        }
    
        transition.updateFrame(view: lineView, frame: lineView.centerFrameX(y: frame.height - lineView.frame.height))
        

        let topPoint = NSMakePoint(max(min(lineView.frame.minX + lineView.frame.width * item.state.percentToNext - top.frame.width / 2, size.width - 20 - top.frame.width), lineView.frame.minX), lineView.frame.minY - top.frame.height - 10)
        transition.updateFrame(view: top, frame: CGRect(origin: topPoint, size: top.frame.size))

    }
}


private final class Arguments {
    let context: AccountContext
    let openPeerInfo:(PeerId)->Void
    let shareLink:(String)->Void
    let copyLink:(String)->Void
    let showMore:()->Void
    init(context: AccountContext, openPeerInfo:@escaping(PeerId)->Void, shareLink: @escaping(String)->Void, copyLink: @escaping(String)->Void, showMore:@escaping()->Void) {
        self.context = context
        self.shareLink = shareLink
        self.copyLink = copyLink
        self.openPeerInfo = openPeerInfo
        self.showMore = showMore
    }
}

private struct State : Equatable {
    var peer: PeerEquatable?
    var boostStatus: ChannelBoostStatus?
    var booster: ChannelBoostersContext.State?
    
    var revealed: Bool = false
    
    var link: String {
        if let peer = peer {
            if let address = peer.peer.addressName {
                return "https://t.me/\(address)?boost"
            } else {
                return "https://t.me/c/\(peer.peer.id.id._internalGetInt64Value())?boost"

            }
        } else {
            return ""
        }
    }
    
    var percentToNext: CGFloat {
        if let status = self.boostStatus {
            if let nextLevelBoosts = status.nextLevelBoosts {
                return CGFloat(status.boosts - status.currentLevelBoosts) / CGFloat(nextLevelBoosts - status.currentLevelBoosts)
            } else {
                return 1.0
            }
        } else {
            return 0.0
        }
        
    }
    
    var currentLevel: Int {
        if let stats = self.boostStatus {
            return stats.level
        }
        return 0
    }
    var currentBoosts: Int {
        if let stats = self.boostStatus {
            return stats.boosts - stats.currentLevelBoosts
        }
        return 0
    }
}

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}
private let _id_loading = InputDataIdentifier("_id_loading")
private let _id_empty_boosters = InputDataIdentifier("_id_empty_boosters")
private let _id_load_more = InputDataIdentifier("_id_load_more")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    if let boostStatus = state.boostStatus {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("level"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
            return BoostRowItem(initialSize, stableId: stableId, state: state, context: arguments.context)
        }))
        index += 1
      
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        overviewItems.append(ChannelOverviewItem(title: strings().statsBoostsLevel, value: .initialize(string: "\(boostStatus.level)", color: theme.colors.text, font: .medium(.text))))
        
        var premiumSubscribers: Double = 0.0
        if let premiumAudience = boostStatus.premiumAudience, premiumAudience.total > 0 {
            premiumSubscribers = premiumAudience.value / premiumAudience.total
        }
                        
        let audience: NSMutableAttributedString = NSMutableAttributedString()
        audience.append(string: "~\(Int(boostStatus.premiumAudience?.value ?? 0))", color: theme.colors.text, font: .medium(.text))
        audience.append(string: " ", color: theme.colors.text, font: .medium(.text))
        audience.append(string: String(format: "%.02f%%", premiumSubscribers * 100.0), color: theme.colors.grayText, font: .normal(.short))


        overviewItems.append(ChannelOverviewItem(title: strings().statsBoostsPremiumSubscribers, value: audience))
        
        overviewItems.append(ChannelOverviewItem(title: strings().statsBoostsExistingBoosts, value: .initialize(string: boostStatus.boosts.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))

        if let nextLevelBoosts = boostStatus.nextLevelBoosts {
            overviewItems.append(ChannelOverviewItem(title: strings().statsBoostsBoostsToLevelUp, value: .initialize(string: ("\(nextLevelBoosts - boostStatus.currentLevelBoosts)"), color: theme.colors.text, font: .medium(.text))))
        }

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), comparable: nil, item: { initialSize, stableId in
            return ChannelOverviewStatsRowItem(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
        }))
        index += 1

        if let boosters = state.booster {
           
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsBoostsBoostersCountable(Int(boosters.count))), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1

            
            if !boosters.boosters.isEmpty {
                
                struct Tuple: Equatable {
                    let booster: ChannelBoostersContext.State.Booster
                    let viewType: GeneralViewType
                }
                
                var items: [Tuple] = []
                for (i, booster) in boosters.boosters.enumerated() {
                    var viewType: GeneralViewType = bestGeneralViewType(boosters.boosters, for: i)
                    if i == boosters.boosters.count - 1, boosters.canLoadMore || boosters.isLoadingMore {
                        viewType = .innerItem
                    }
                    items.append(.init(booster: booster, viewType: viewType))
                }
                
                
                
                for item in items {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.booster.peer._asPeer().id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                        return ShortPeerRowItem(initialSize, peer: item.booster.peer._asPeer(), account: arguments.context.account, context: arguments.context, status: strings().statsBoostsExpiresOn(stringForFullDate(timestamp: item.booster.expires)), inset: NSEdgeInsets(left: 20, right: 20), viewType: item.viewType, action: {
                            arguments.openPeerInfo(item.booster.peer.id)
                        })
                    }))
                    index += 1
                }
                
                
                if boosters.canLoadMore {
                    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_load_more, data: .init(name: strings().statsBoostsShowMore, color: theme.colors.accent, viewType: .lastItem, action: arguments.showMore)))
                    index += 1
                } else if boosters.isLoadingMore {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: .init(boosters), comparable: nil, item: { initialSize, stableId in
                        return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
                    }))
                    index += 1
                }
                
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsBoostsBoostersInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
                index += 1
            } else {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_empty_boosters, equatable: nil, comparable: nil, item: { initialSize, stableId in
                    return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().statsBoostsNoBoostersYet, font: .normal(.text), color: theme.colors.grayText)
                }))
            }

        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsBoostsLinkHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("link"), equatable: InputDataEquatable(state.link), comparable: nil, item: { initialSize, stableId in
            return ExportedInvitationRowItem(initialSize, stableId: stableId, context: arguments.context, exportedLink: _ExportedInvitation.initialize(.link(link: state.link, title: nil, isPermanent: true, requestApproval: false, isRevoked: false, adminId: arguments.context.peerId, date: 0, startDate: 0, expireDate: nil, usageLimit: nil, count: nil, requestedCount: nil)), lastPeers: [], viewType: .singleItem, mode: .normal(hasUsage: false), menuItems: {
                
                var items:[ContextMenuItem] = []
                
                items.append(ContextMenuItem(strings().contextCopy, handler: {
                    arguments.copyLink(state.link)
                }, itemImage: MenuAnimation.menu_copy.value))
                
                return .single(items)
            }, share: arguments.shareLink, copyLink: arguments.copyLink)
        }))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsBoostsLinkInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
                
        // entries
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, comparable: nil, item: { initialSize, stableId in
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        }))
    }
    
    
    return entries
}

func ChannelBoostStatsController(context: AccountContext, peerId: PeerId) -> InputDataController {

    let actionsDisposable = DisposableSet()
    var getController:(()->InputDataController?)? = nil

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let boostData = context.engine.peers.getChannelBoostStatus(peerId: peerId)
    let boostersContext = ChannelBoostersContext(account: context.account, peerId: peerId)


    actionsDisposable.add(combineLatest(context.account.postbox.loadedPeerWithId(peerId), boostData, boostersContext.state).start(next: { peer, boostData, boosters in
        
        updateState { current in
            var current = current
            current.peer = .init(peer)
            current.boostStatus = boostData
            current.booster = boosters
            return current
        }
    }))
    
    let arguments = Arguments(context: context, openPeerInfo: { peerId in
        PeerInfoController.push(navigation: context.bindings.rootNavigation(), context: context, peerId: peerId)
    }, shareLink: { link in
        showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
    }, copyLink: { link in
        getController?()?.show(toaster: ControllerToaster(text: strings().shareLinkCopied))
        copyToClipboard(link)
    }, showMore: { [weak boostersContext] in
        boostersContext?.loadMore()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.contextObject = boostersContext
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }

    return controller
    
}
