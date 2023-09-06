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
        
        func update(_ state: State, context: AccountContext) {
            
            self.state = state
            
            let normalCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel)", color: theme.colors.text, font: .medium(13)))
            normalCountLayout.measure(width: .greatestFiniteMagnitude)

            currentLevel.update(normalCountLayout)

            
            let premiumCountLayout = TextViewLayout(.initialize(string: "Level \(state.currentLevel + 1)", color: .white, font: .medium(13)))
            premiumCountLayout.measure(width: .greatestFiniteMagnitude)

            nextLevel.update(premiumCountLayout)
            
            nextLevel_background.backgroundColor = theme.colors.grayForeground
            
            needsLayout = true
        }
        
        override func layout() {
            super.layout()
            
            guard let state = self.state else {
                return
            }
            
            let width = frame.width * state.percentToNext

            currentLevel.centerY(x: 10)
            nextLevel.centerY(x: bounds.width - 10 - nextLevel.frame.width)
            
            nextLevel_background.frame = NSMakeRect(width, 0, width, frame.height)
            currentLevel_background.frame = NSMakeRect(0, 0, width, frame.height)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
        
    private class TypeView : View {
        private let backgrounView = ImageView()
        
        private let textView = TextView()
        private let imageView = ImageView()
        private let container = View()
        
        
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(backgrounView)
            container.addSubview(textView)
            container.addSubview(imageView)
            addSubview(container)
            
            textView.userInteractionEnabled = false
            textView.isSelectable = false
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
        
        
        func update(state: State, context: AccountContext) -> NSSize {
            let layout = TextViewLayout(.initialize(string: "\(state.currentBoosts)", color: NSColor.white, font: .avatar(20)))
            layout.measure(width: .greatestFiniteMagnitude)
            textView.update(layout)
            
            imageView.image = NSImage(named: "Icon_Boost_Lighting")?.precomposed()
            imageView.sizeToFit()
            

            container.setFrameSize(NSMakeSize(layout.layoutSize.width + imageView.frame.width, 40))
            
            let canPremium = !context.premiumIsBlocked
            
            let size = NSMakeSize(container.frame.width + 20, canPremium ? 50 : 40)
            
            let image = generateImage(NSMakeSize(size.width, canPremium ? size.height - 10 : size.height), contextGenerator: { size, ctx in
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

                if !canPremium {
                    ctx.clip(to: size.bounds, mask: image)
                    ctx.setFillColor(theme.colors.accent.cgColor)
                    ctx.fill(size.bounds)
                } else {
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
                }
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
        
        lineView.update(item.state, context: item.context)
        lineView.setFrameSize(NSMakeSize(frame.width - 60, 30))
        lineView.layer?.cornerRadius = 10
        
        let size = top.update(state: item.state, context: item.context)
        top.setFrameSize(size)

        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        guard let item = self.item as? BoostRowItem else {
            return
        }
        
        lineView.centerX(y: frame.height - lineView.frame.height)
        top.setFrameOrigin(NSMakePoint(30 + lineView.frame.width * item.state.percentToNext - top.frame.width / 2, lineView.frame.minY - top.frame.height - 10))
        
    }
}


private final class Arguments {
    let context: AccountContext
    let openPeerInfo:(PeerId)->Void
    let shareLink:(String)->Void
    let copyLink:(String)->Void
    init(context: AccountContext, openPeerInfo:@escaping(PeerId)->Void, shareLink: @escaping(String)->Void, copyLink: @escaping(String)->Void) {
        self.context = context
        self.shareLink = shareLink
        self.copyLink = copyLink
        self.openPeerInfo = openPeerInfo
    }
}

private struct State : Equatable {
    var peers: [PeerEquatable] = []
    var link: String = "https://t.me/durov?boost"
    var currentLevel: Int32 = 0
    var currentBoosts: Int32 = 2
    var boostsToNextLevel: Int32 = 3
    
    var percentToNext: CGFloat {
        return CGFloat(currentBoosts) / CGFloat(boostsToNextLevel)
    }
}

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("level"), equatable: InputDataEquatable(state), comparable: nil, item: { initialSize, stableId in
        return BoostRowItem(initialSize, stableId: stableId, state: state, context: arguments.context)
    }))
    index += 1
  
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("OVERVIEW"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
    
    var overviewItems:[ChannelOverviewItem] = []
    
    overviewItems.append(ChannelOverviewItem(title: "Level", value: .initialize(string: "0", color: theme.colors.text, font: .medium(.text))))

    overviewItems.append(ChannelOverviewItem(title: "Premium Subscribers", value: .initialize(string: "~344", color: theme.colors.text, font: .medium(.text))))

    overviewItems.append(ChannelOverviewItem(title: "Current boosts", value: .initialize(string: "3", color: theme.colors.text, font: .medium(.text))))

    overviewItems.append(ChannelOverviewItem(title: "Boosts to level up", value: .initialize(string: "7", color: theme.colors.text, font: .medium(.text))))

    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), comparable: nil, item: { initialSize, stableId in
        return ChannelOverviewStatsRowItem(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
    }))
    index += 1

    if !state.peers.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("\(state.peers.count) BOOSTERS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1

        
        struct Tuple: Equatable {
            let peer: PeerEquatable
            let viewType: GeneralViewType
        }
        
        var items: [Tuple] = []
        for (i, peer) in state.peers.enumerated() {
            items.append(.init(peer: peer, viewType: bestGeneralViewType(state.peers, for: i)))
        }
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: arguments.context, status: "boost expires on 31 Aug, 2024", inset: NSEdgeInsets(left: 30, right: 30), viewType: item.viewType, action: {
                    arguments.openPeerInfo(item.peer.peer.id)
                })
            }))
            index += 1
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Your channel is currently boosted by these users."), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
        index += 1
        
        

    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("LINK FOR BOOSTERS"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
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
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
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

    actionsDisposable.add(context.account.postbox.loadedPeerWithId(context.peerId).start(next: { peer in
        
        updateState { current in
            var current = current
            current.peers = [.init(peer)]
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
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    getController = { [weak controller] in
        return controller
    }

    return controller
    
}
