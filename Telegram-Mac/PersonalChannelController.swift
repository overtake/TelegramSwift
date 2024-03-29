//
//  PersonalChannelController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class EmptyChannelRow : GeneralRowItem {
    let layout: TextViewLayout
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, action:@escaping()->Void) {
        let attr = parseMarkdownIntoAttributedString(strings().personalChannelEmpty, attributes: .init(body: .init(font: .normal(.text), textColor: theme.colors.listGrayText), bold: .init(font: .medium(.text), textColor: theme.colors.listGrayText), link: .init(font: .normal(.text), textColor: theme.colors.accent), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.callback(contents, { value in
                action()
            }))
        }))
        self.context = context
        self.layout = .init(attr)
        self.layout.interactions = globalLinkExecutor
        super.init(initialSize, height: 300, stableId: stableId)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        layout.measure(width: blockWidth - 40)
        
        return true
    }
    
    override var height: CGFloat {
        return 30 + 150 + 20 + layout.layoutSize.height + 50
    }
    
    override func viewClass() -> AnyClass {
        return EmptyChannelRowView.self
    }
}

private final class EmptyChannelRowView : GeneralContainableRowView {
    private let textView = TextView()
    private let stickerView = MediaAnimatedStickerView(frame: NSMakeRect(0, 0, 150, 150))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(textView)
        addSubview(stickerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? EmptyChannelRow else {
            return
        }
        textView.update(item.layout)
        stickerView.update(with: LocalAnimatedSticker.duck_empty.file, size: stickerView.frame.size, context: item.context, table: item.table, animated: animated)
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    
    override func layout() {
        super.layout()
        stickerView.centerX(y: 30)
        textView.centerX(y: stickerView.frame.maxY + 20)
        
    }
}

private final class Arguments {
    let context: AccountContext
    let select:(PeerId)->Void
    let removeSelected:()->Void
    let newChannel:()->Void
    init(context: AccountContext, select:@escaping(PeerId)->Void, removeSelected:@escaping()->Void, newChannel:@escaping()->Void) {
        self.context = context
        self.select = select
        self.removeSelected = removeSelected
        self.newChannel = newChannel
    }
}

private struct State : Equatable {
    var channels:[SendAsPeer]? = nil
    var selected: PeerId? = nil
}

private func _id_channel(_ peerId: PeerId) -> InputDataIdentifier {
    return .init("_id_channel_\(peerId.toInt64())")
}

private let _id_hide = InputDataIdentifier("_id_hide")


private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if var channels = state.channels {
        struct Tuple : Equatable {
            let channel: SendAsPeer
            let viewType: GeneralViewType
            let selected: Bool
            let status: String
        }
        
        if let index = channels.firstIndex(where: { $0.peer.id == state.selected }) {
            channels.move(at: index, to: 0)
        }
        
        if state.selected != nil {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_hide, data: .init(name: strings().personalChannelHide, color: theme.colors.accent, icon: NSImage(resource: .iconPersonalChannelOff).precomposed(theme.colors.accent), viewType: channels.isEmpty ? .singleItem : .firstItem, action: {
                arguments.removeSelected()
            }, iconTextInset: 41, iconInset: 4)))
        }
        
        var items: [Tuple] = []
        for (i, channel) in channels.enumerated() {
            var viewType: GeneralViewType
            if i == 0, state.selected != nil {
                if i == channels.count - 1 {
                    viewType = .lastItem
                } else {
                    viewType = .innerItem
                }
            } else {
                viewType = bestGeneralViewType(channels, for: i)
            }
            
            let status: String
            
            if let subscribers = channel.subscribers {
                let membersLocalized: String = strings().peerStatusSubscribersCountable(Int(subscribers))
                status = membersLocalized.replacingOccurrences(of: "\(subscribers)", with: subscribers.formattedWithSeparator)
            } else {
                status = strings().peerStatusChannel
            }
            items.append(.init(channel: channel, viewType: viewType, selected: channel.peer.id == state.selected, status: status))
        }
        
        for tuple in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel(tuple.channel.peer.id), equatable: .init(tuple), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: tuple.channel.peer, account: arguments.context.account, context: arguments.context, height: 44, photoSize: NSMakeSize(30, 30), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                    arguments.select(tuple.channel.peer.id)
                })
            }))
        }
        if items.isEmpty {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("empty"), equatable: nil, comparable: nil, item: { initialSize, stableId in
                return EmptyChannelRow(initialSize, stableId: stableId, context: arguments.context, action: arguments.newChannel)
            }))
        }
    }
    
  
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PersonalChannelController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise<State>(ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let adminedChannelsWithParticipants: Signal<[SendAsPeer], NoError> = context.engine.peers.adminedPublicChannels(scope: .forPersonalProfile)
    |> map { peers -> [SendAsPeer] in
        return peers.map({ .init(peer: $0.peer._asPeer(), subscribers: $0.subscriberCount.flatMap { Int32($0) }, isPremiumRequired: false) })

    }
    
    let selected = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.PersonalChannel(id: context.peerId))
    
    actionsDisposable.add(combineLatest(adminedChannelsWithParticipants, selected).start(next: { channels, selected in
        updateState { current in
            var current = current
            current.channels = channels
            switch selected {
            case let .known(value):
                current.selected = value?.peerId
            default:
                break
            }
            return current
        }
    }))
    
    
    let arguments = Arguments(context: context, select: { peerId in
        _ = context.engine.accountData.updatePersonalChannel(personalChannel: TelegramPersonalChannel(peerId: peerId, subscriberCount: nil, topMessageId: nil)).startStandalone()
        showModalText(for: context.window, text: strings().personalChannelTooltipUpdated)
        close?()
    }, removeSelected: {
        updateState { current in
            var current = current
            current.selected = nil
            return current
        }
        _ = context.engine.accountData.updatePersonalChannel(personalChannel: nil).startStandalone()
        showModalText(for: context.window, text: strings().personalChannelTooltipUpdated)
        close?()
    }, newChannel: {
        context.composeCreateChannel()
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: " ")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }


    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.centerModalHeader = ModalHeaderData(title: strings().personalChannelTitle, subtitle: strings().personalChannelInfo)
    
    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
}



