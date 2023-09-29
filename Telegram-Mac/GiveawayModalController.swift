//
//  GiveawayModalController.swift
//  Telegram
//
//  Created by Mike Renoir on 25.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private func generateTypeImage(_ image: NSImage, colorIndex: Int) -> CGImage {
    
   let random_colors = theme.colors.peerColors(colorIndex)
   return generateImage(NSMakeSize(35, 35), contextGenerator: { (size, ctx) in
       ctx.clear(NSMakeRect(0, 0, size.width, size.height))
       
       ctx.round(size, size.height / 2)
       
       var locations: [CGFloat] = [1.0, 0.2];
       let colorSpace = deviceColorSpace
       let gradient = CGGradient(colorsSpace: colorSpace, colors: NSArray(array: [random_colors.top.cgColor, random_colors.bottom.cgColor]), locations: &locations)!
       
       ctx.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
       
       ctx.setBlendMode(.normal)
       
       let icon = image.precomposed(.white, flipVertical: true)
       let iconSize = icon.backingSize
       let rect = NSMakeRect((size.width - iconSize.width)/2, (size.height - iconSize.height)/2, iconSize.width, iconSize.height)
       ctx.draw(icon, in: rect)
       
   })!
    
}

private final class GiveawayDurationOptionItem : GeneralRowItem {
    
    fileprivate let title: TextViewLayout
    fileprivate let desc: TextViewLayout
    fileprivate let total: TextViewLayout
    fileprivate let discount: TextViewLayout?
    fileprivate let selected: Bool
    fileprivate let option: State.PaymentOption
    fileprivate let toggleOption: (State.PaymentOption)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, option: State.PaymentOption, selected: Bool, viewType: GeneralViewType, toggleOption: @escaping(State.PaymentOption)->Void) {
        self.selected = selected
        self.option = option
        self.toggleOption = toggleOption
        self.title = .init(.initialize(string: option.title, color: theme.colors.text, font: .medium(.text)))
        self.desc = .init(.initialize(string: option.desc, color: theme.colors.grayText, font: .normal(.short)))
        self.total = .init(.initialize(string: option.total, color: theme.colors.grayText, font: .normal(.text)))
        if let discount = option.discount {
            self.discount = .init(.initialize(string: discount, color: theme.colors.underSelectedColor, font: .normal(.small)))
        } else {
            self.discount = nil
        }
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.total.measure(width: .greatestFiniteMagnitude)
        
        self.title.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right - total.layoutSize.width - viewType.innerInset.right - viewType.innerInset.right)
        
        self.desc.measure(width: self.blockWidth - viewType.innerInset.left - viewType.innerInset.right - total.layoutSize.width - viewType.innerInset.right - viewType.innerInset.right)

        self.discount?.measure(width: .greatestFiniteMagnitude)
        
        return true
    }
    
    override var height: CGFloat {
        return 42
    }
    
    override func viewClass() -> AnyClass {
        return GiveawayDurationOptionItemView.self
    }
}

private final class GiveawayDurationOptionItemView : GeneralContainableRowView {
    
    
    private final class DiscountView : View {
        private let textView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(textView)
            textView.userInteractionEnabled = false
            textView.isSelectable = false
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(_ text: TextViewLayout) {
            textView.update(text)
            self.setFrameSize(NSMakeSize(text.layoutSize.width + 4, text.layoutSize.height + 2))
        }
        
        override func layout() {
            super.layout()
            textView.center()
        }
    }
    
    private let titleView = TextView()
    private let descView = TextView()
    private let totalView = TextView()
    private var discountView: DiscountView?
    private var selectingControl = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.chatToggleSelected)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(selectingControl)
        addSubview(titleView)
        addSubview(descView)
        addSubview(totalView)
        
        titleView.userInteractionEnabled = false
        titleView.isSelectable = false
        
        descView.userInteractionEnabled = false
        descView.isSelectable = false
        
        totalView.userInteractionEnabled = false
        totalView.isSelectable = false
        
        containerView.set(handler: { [weak self] _ in
            if let item = self?.item as? GiveawayDurationOptionItem {
                item.toggleOption(item.option)
            }
        }, for: .Click)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? GiveawayDurationOptionItem else {
            return
        }
        self.titleView.update(item.title)
        self.descView.update(item.desc)
        self.totalView.update(item.total)
        
        if let discount = item.discount {
            let current: DiscountView
            if let view = self.discountView {
                current = view
            } else {
                current = DiscountView(frame: .zero)
                self.discountView = current
                self.addSubview(current)
            }
            current.backgroundColor = theme.colors.accent
            current.layer?.cornerRadius = 2
            current.update(discount)
        } else if let view = self.discountView {
            performSubviewRemoval(view, animated: animated)
            self.discountView = nil
        }
        
        selectingControl.set(selected: item.selected, animated: animated)
        
        needsLayout = true

    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GeneralRowItem else {
            return
        }
        selectingControl.centerY(x: item.viewType.innerInset.left)
        totalView.centerY(x: containerView.frame.width - totalView.frame.width - item.viewType.innerInset.right)
        titleView.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, 4))
        
        if let discount = discountView {
            discount.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, containerView.frame.height - discount.frame.height - 4))
            descView.setFrameOrigin(NSMakePoint(discount.frame.maxX + 2, containerView.frame.height - descView.frame.height - 4))
        } else {
            descView.setFrameOrigin(NSMakePoint(selectingControl.frame.maxX + item.viewType.innerInset.left, containerView.frame.height - descView.frame.height - 4))
        }
    }
}

private final class GiveawayStarRowItem : GeneralRowItem {
    
    init(_ initialSize: NSSize, stableId: AnyHashable) {
        super.init(initialSize, height: 100, stableId: stableId)
    }
    override func viewClass() -> AnyClass {
        return GiveawayStarRowItemView.self
    }
}

private final class GiveawayStarRowItemView : TableRowView {
    private let scene: PremiumStarSceneView = PremiumStarSceneView(frame: NSMakeRect(0, 0, 300, 150))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(scene)
        scene.updateLayout(size: scene.frame.size, transition: .immediate)
        
        self.layer?.masksToBounds = false
    }
    
    override func layout() {
        super.layout()
        scene.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
}

private final class GiveawaySliderRowItem : GeneralRowItem {
    fileprivate let quantity: Int32
    fileprivate let updateQuantity:(Int32)->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, quantity: Int32, viewType: GeneralViewType, updateQuantity:@escaping(Int32)->Void) {
        self.quantity = quantity
        self.updateQuantity = updateQuantity
        super.init(initialSize, height: 30, stableId: stableId, viewType: viewType)
    }
    override func viewClass() -> AnyClass {
        return GiveawaySliderRowItemView.self
    }
}

private final class GiveawaySliderRowItemView : GeneralContainableRowView {
    let progress: LinearProgressControl = LinearProgressControl(progressHeight: 6)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        progress.roundCorners = true
        progress.alignment = .center
        progress.containerBackground = theme.colors.grayIcon.withAlphaComponent(0.6)
        progress.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: .clear, highlightColor: .clear)
        progress.scrubberImage = generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
            let rect = CGRect(origin: .zero, size: size)
            ctx.clear(rect)
            ctx.setFillColor(theme.colors.accent.cgColor)
            ctx.fillEllipse(in: rect)
        })
        addSubview(progress)
        
        progress.onUserChanged = { [weak self] value in
            guard let item = self?.item as? GiveawaySliderRowItem else {
                return
            }
            item.updateQuantity(Int32(round(value * 10)))
        }

        
        self.layer?.masksToBounds = false
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? GiveawaySliderRowItem else {
            return
        }
        progress.set(progress: CGFloat(item.quantity) / CGFloat(10.0), animated: animated)
        
    }
    
    override func layout() {
        super.layout()
        guard let item = item as? GiveawaySliderRowItem else {
            return
        }
        progress.setFrameSize(NSMakeSize(containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, 20))
        progress.centerX(y: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


private final class Arguments {
    let context: AccountContext
    let updateQuantity:(Int32)->Void
    let updateReceiver:(State.GiveawayReceiver)->Void
    let updateType:(State.GiveawayType)->Void
    let selectDate:()->Void
    let execute:(String)->Void
    let toggleOption:(State.PaymentOption)->Void
    let addChannel:()->Void
    let deleteChannel:(PeerId)->Void
    init(context: AccountContext, updateQuantity:@escaping(Int32)->Void, updateReceiver:@escaping(State.GiveawayReceiver)->Void, updateType:@escaping(State.GiveawayType)->Void, selectDate:@escaping()->Void, execute:@escaping(String)->Void, toggleOption:@escaping(State.PaymentOption)->Void, addChannel:@escaping()->Void, deleteChannel:@escaping(PeerId)->Void) {
        self.context = context
        self.updateQuantity = updateQuantity
        self.updateReceiver = updateReceiver
        self.updateType = updateType
        self.selectDate = selectDate
        self.execute = execute
        self.toggleOption = toggleOption
        self.addChannel = addChannel
        self.deleteChannel = deleteChannel
    }
}

private struct State : Equatable {
    enum GiveawayType : Equatable {
        case random
        case specific
    }
    enum GiveawayReceiver : Equatable {
        case all
        case new
    }
    struct PaymentOption : Equatable {
        var title: String
        var desc: String
        var total: String
        var discount: String?
    }
    var receiver: GiveawayReceiver = .all
    var type: GiveawayType = .random
    var quantity: Int32 = 3
    var options: [PaymentOption] = [.init(title: "3 Months", desc: "$13.99 × 3", total: "$41.99"),
                                    .init(title: "6 Months", desc: "$15.99 × 3", total: "$47.99", discount: "-15%"),
                                    .init(title: "1 Year", desc: "$29.99 × 3", total: "$89.99", discount: "-30%")]
    
    var option: PaymentOption = .init(title: "3 Months", desc: "$13.99 × 3", total: "$41.99")
    var date: Date = Date()
    var channels: [PeerEquatable]
}

private let _id_star = InputDataIdentifier("_id_star")
private let _id_giveaway = InputDataIdentifier("_id_giveaway")
private let _id_giveaway_specific = InputDataIdentifier("_id_giveaway_specific")
private let _id_size = InputDataIdentifier("_id_size")
private let _id_size_header = InputDataIdentifier("_id_size_header")
private let _id_add_channel = InputDataIdentifier("_id_add_channel")
private let _id_receiver_all = InputDataIdentifier("_id_receiver_all")
private let _id_receiver_new = InputDataIdentifier("_id_receiver_new")
private let _id_select_date = InputDataIdentifier("_id_select_date")

private func _id_peer(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_peer_\(id.toInt64())")
}
private func _id_option(_ id: String) -> InputDataIdentifier {
    return .init("_id_duration_\(id)")
}




private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_star, equatable: nil, comparable: nil, item: { initialSize, stableId in
        return GiveawayStarRowItem(initialSize, stableId: stableId)
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("**Gift Telegram Premium**"), data: .init(color: theme.colors.text, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 18, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Get more boosts for your channel by gifting"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .modern(position: .inner, insets: .init()), fontSize: 13, centerViewAlignment: true, alignment: .center)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let random_icon = generateTypeImage(NSImage(named: "Icon_Giveaway_Random")!, colorIndex: 5)
    let specific_icon = generateTypeImage(NSImage(named: "Icon_Giveaway_Specific")!, colorIndex: 6)

    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway, data: .init(name: "Create Giveaway", color: theme.colors.text, icon: random_icon, type: .selectableLeft(state.type == .random), viewType: .firstItem, enabled: true, description: "winners are chosen randomly", action: {
        arguments.updateType(.random)
    })))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_giveaway_specific, data: .init(name: "Award Specific Users", color: theme.colors.text, icon: specific_icon, type: .selectableLeft(state.type == .specific), viewType: .lastItem, enabled: true, description: "select recipients", descTextColor: theme.colors.accent, action: {
        arguments.updateType(.specific)
    })))
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("QUANTITY OF PRIZES / BOOSTS"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_size_header, equatable: .init(state.quantity), comparable: nil, item: { initialSize, stableId in
        return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .firstItem, text: "\(state.quantity) Subscriptions / Boosts", font: .normal(.text), color: theme.colors.text, centerViewAlignment: true, hasBorder: false)
    }))
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_size, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return GiveawaySliderRowItem(initialSize, stableId: stableId, quantity: state.quantity, viewType: .lastItem, updateQuantity: arguments.updateQuantity)
    }))
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Chose how many Premiums subscriptions to give away and boosts to receive."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
    
    
    if state.type == .random {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("CHANNELS INCLUDED IN THE GIVEAWAY"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        var channels: [PeerEquatable] = state.channels
        
        struct ChannelTuple: Equatable {
            let peer: PeerEquatable
            let quantity: Int32
            let viewType: GeneralViewType
            let deletable: Bool
        }
        
        var channelItems: [ChannelTuple] = []
        
        for (i, channel) in channels.enumerated() {
            var viewType = bestGeneralViewType(channels, for: i)
            if i == channels.count - 1 {
                if channels.count == 1 {
                    viewType = .firstItem
                } else {
                    viewType = .innerItem
                }
            }
            
            channelItems.append(.init(peer: channel, quantity: state.quantity, viewType: viewType, deletable: i != 0))
        }
        
        for item in channelItems {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(item.peer.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                
                return ShortPeerRowItem(initialSize, peer: item.peer.peer, account: arguments.context.account, context: nil, status: "this channel will receive \(item.quantity) boosts", inset: NSEdgeInsets(left: 20, right: 20), viewType: item.viewType, contextMenuItems: {
                    var items: [ContextMenuItem] = []
                    if item.deletable {
                        items.append(ContextMenuItem("Remove", handler: {
                            arguments.deleteChannel(item.peer.peer.id)
                        }, itemMode: .destruct, itemImage: MenuAnimation.menu_delete.value))
                    }
                    return .single(items)
                }, menuOnAction: true)
            }))
        }
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_channel, data: .init(name: "Add Channel", color: theme.colors.accent, icon: theme.icons.proxyAddProxy, viewType: .lastItem, action: arguments.addChannel)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Choose the channels users need to be subscribed to take part in the giveaway."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("USERS ELIGIBLE FOR THE GIVEAWAY"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_receiver_all, data: .init(name: "All subscribers", color: theme.colors.text, type: .selectableLeft(state.receiver == .all), viewType: .firstItem, action: {
            arguments.updateReceiver(.all)
        })))
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_receiver_new, data: .init(name: "Only new subscribers", color: theme.colors.text, type: .selectableLeft(state.receiver == .new), viewType: .lastItem, action: {
            arguments.updateReceiver(.new)
        })))

        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Choose if you want to limit the giveaway only to those who joined the channel after the giveaway started."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DATE WHEN GIVEAWAY ENDS"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
        index += 1
        

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_select_date, data: .init(name: "Ends", color: theme.colors.text, type: .nextContext(stringForFullDate(timestamp: Int32(state.date.timeIntervalSince1970))), viewType: .singleItem, action: arguments.selectDate)))
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Choose when 3 subscribers of your channel will be randomly selected to receive Telegram Premium."), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
        index += 1
    }
    
    

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DURATION OF PREMIUM SUBSCRIPTIONS"), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textTopItem)))
    index += 1
    
    
    struct PaymentTuple : Equatable {
        var option: State.PaymentOption
        var selected: Bool
        var viewType: GeneralViewType
    }
    
    var paymentOptions: [PaymentTuple] = []
    for (i, option) in state.options.enumerated() {
        paymentOptions.append(.init(option: option, selected: state.option == option, viewType: bestGeneralViewType(state.options, for: i)))
    }
    
    for option in paymentOptions {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(option.option.title), equatable: .init(option), comparable: nil, item: { initialSize, stableId in
            return GiveawayDurationOptionItem(initialSize, stableId: stableId, option: option.option, selected: option.selected, viewType: option.viewType, toggleOption: arguments.toggleOption)
        }))
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .markdown("You can review the list of features and terms of use for Telegram Premium [here](premium).", linkHandler: arguments.execute), data: .init(color: theme.colors.listGrayText, detectBold: true, viewType: .textBottomItem)))
    index += 1
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

func GiveawayModalController(context: AccountContext, peerId: PeerId) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(channels: [.init(context.myPeer!)])
    
    var close: (()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(context: context, updateQuantity: { value in
        updateState { current in
            var current = current
            current.quantity = value
            return current
        }
    }, updateReceiver: { value in
        updateState { current in
            var current = current
            current.receiver = value
            return current
        }
    }, updateType: { value in
        updateState { current in
            var current = current
            current.type = value
            return current
        }
    }, selectDate: {
        showModal(with: DateSelectorModalController(context: context, mode: .date(title: "Giveaway", doneTitle: "OK"), selectedAt: { value in
            updateState { current in
                var current = current
                current.date = value
                return current
            }
        }), for: context.window)
    }, execute: { link in
        if link == "premium" {
            showModal(with: PremiumBoardingController(context: context), for: context.window)
        }
    }, toggleOption: { value in
        updateState { current in
            var current = current
            current.option = value
            return current
        }
    }, addChannel: {
        _ = selectModalPeers(window: context.window, context: context, title: "Select Channel", behavior: SelectChatsBehavior(settings: [.channels], excludePeerIds: stateValue.with { $0.channels.map { $0.peer.id } }, limit: 1)).start(next: { peerIds in
            let signal = context.account.postbox.loadedPeerWithId(peerIds[0]) |> deliverOnMainQueue
            _ = signal.start(next: { peer in
                updateState { current in
                    var current = current
                    current.channels.append(.init(peer))
                    return current
                }
            })
        })
    }, deleteChannel: { peerId in
        updateState { current in
            var current = current
            current.channels.removeAll(where: { $0.peer.id == peerId })
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Giveaway")
    
    
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: "Start Giveaway", accept: { [weak controller] in
        _ = controller?.returnKeyAction()
    }, singleButton: true)
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}


/*
 
 */



