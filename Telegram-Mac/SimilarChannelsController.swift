//
//  SimilarChannelsController.swift
//  Telegram
//
//  Created by Mike Renoir on 20.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation

import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    let openInfo:(PeerId)->Void
    let premium:()->Void
    init(context: AccountContext, openInfo:@escaping(PeerId)->Void, premium:@escaping()->Void) {
        self.context = context
        self.openInfo = openInfo
        self.premium = premium
    }
}

private struct State : Equatable {
    var channels: RecommendedChannels?
    var isPremium: Bool
}

private func _id_channel(_ id: PeerId) -> InputDataIdentifier {
    return .init("_id_channel_\(id.toInt64())")
}
private let _id_more = InputDataIdentifier("_id_more")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
        
    if let channels = state.channels {
        
        struct Tuple : Equatable {
            let channel: RecommendedChannels.Channel
            let viewType: GeneralViewType
            let status: String
        }
        var items: [Tuple] = []
        for (i, channel) in channels.channels.enumerated() {
            var viewType: GeneralViewType = bestGeneralViewType(channels.channels, for: i)
            if i == 0 {
                if i == channels.channels.count - 1 {
                    viewType = .lastItem
                } else {
                    viewType = .innerItem
                }
            }
            var status = strings().peerMediaStatusSubscribersCountable(Int(channel.subscribers))
            status = status.replacingOccurrences(of: "\(channel.subscribers)", with: Int(channel.subscribers).prettyNumber)
            items.append(.init(channel: channel, viewType: viewType, status: status))
        }
        
        for item in items {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel(item.channel.peer.id), equatable: .init(item), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: item.channel.peer._asPeer(), account: arguments.context.account, context: arguments.context, status: item.status, inset: .init(), viewType: item.viewType, action: {
                    arguments.openInfo(item.channel.peer.id)
                }, highlightVerified: true)
            }))
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        let limit = arguments.context.appConfiguration.getGeneralValue("recommended_channels_limit_premium", orElse: 0)
        
        if !state.isPremium {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_more, equatable: .init(state.isPremium), comparable: nil, item: { initialSize, stableId in
                return GeneralBlockTextRowItem(initialSize, stableId: stableId, viewType: .singleItem, text: strings().channelSimilarPremium(Int(limit)), font: .normal(.text), insets: .init(), centerViewAlignment: true, linkCallback: { _ in
                    arguments.premium()
                })
            }))
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }
    
    
    
    return entries
}

func SimilarChannelsController(context: AccountContext, peerId: PeerId, recommendedChannels: RecommendedChannels?) -> InputDataController {

    let actionsDisposable = DisposableSet()
    

    let initialState = State(channels: recommendedChannels, isPremium: context.isPremium)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    let isPremium = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
    |> map { peer -> Bool in
        return peer?.isPremium ?? false
    }


    actionsDisposable.add(combineLatest(context.engine.peers.recommendedChannels(peerId: peerId), isPremium).start(next: { channels, isPremium in
        updateState { current in
            var current = current
            current.channels = channels
            current.isPremium = isPremium
            return current
        }
    }))
    

    let arguments = Arguments(context: context, openInfo: { channelId in
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(channelId)))
        
        
        var jsonString: String = "{"
        jsonString += "\"ref_channel_id\": \"\(peerId.id._internalGetInt64Value())\","
        jsonString += "\"open_channel_id\": \"\(channelId.id._internalGetInt64Value())\""
        jsonString += "}"
        
        if let data = jsonString.data(using: .utf8), let json = JSON(data: data) {
            addAppLogEvent(postbox: context.account.postbox, type: "channels.open_recommended_channel", data: json)
        }
    }, premium: {
        prem(with: PremiumBoardingController(context: context, source: .recommended_channels), for: context.window)
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().peerMediaSimilarChannels)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    return controller
    
}
