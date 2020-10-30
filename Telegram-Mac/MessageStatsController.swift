//
//  MessageStatsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 28/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore
import GraphCore



private func _id_message(_ messageId: MessageId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_message_\(messageId)")
}

private func statsEntries(_ stats: MessageStats?, _ search: (SearchMessagesResult, SearchMessagesState)?, _ uiState: UIStatsState, openMessage: @escaping(MessageId) -> Void, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, context: MessageStatsContext, accountContext: AccountContext) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0

    
    if let stats = stats {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.channelStatsOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        overviewItems.append(ChannelOverviewItem(title: "Views", value: .initialize(string: stats.views.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
       
        if let search = search, search.0.totalCount > 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsMessagePublicForwardsTitle, value: .initialize(string: Int(search.0.totalCount).formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
        }
        
        if stats.forwards > 0 {
            overviewItems.append(ChannelOverviewItem(title: L10n.statsMessagePrivateForwardsTitle, value: .initialize(string: "≈" + stats.forwards.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
        }
    
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), item: { initialSize, stableId in
            return ChannelOverviewStatsRowItem(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
        }))
        index += 1
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        
        struct Graph {
            let graph: StatsGraph
            let title: String
            let identifier: InputDataIdentifier
            let type: ChartItemType
            let load:(InputDataIdentifier)->Void
        }
        
        var graphs: [Graph] = []
        
        var chartType: ChartItemType
        if stats.interactionsGraphDelta == 3600 {
            chartType = .twoAxisHourlyStep
        } else if stats.interactionsGraphDelta == 300 {
            chartType = .twoAxis5MinStep
        } else {
            chartType = .twoAxisStep
        }
        
        if !stats.interactionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.interactionsGraph, title: L10n.statsMessageInteractionsTitle, identifier: InputDataIdentifier("interactionsGraph"), type: chartType, load: { identifier in
              //  context.loadDetailedGraph(<#T##graph: StatsGraph##StatsGraph#>, x: <#T##Int64#>)
                updateIsLoading(identifier, true)
            }))
        }
        
        for graph in graphs {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(graph.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            switch graph.graph {
            case let .Loaded(_, string):
                ChartsDataManager.readChart(data: string.data(using: .utf8)!, sync: true, success: { collection in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: accountContext, collection: collection, viewType: .singleItem, type: graph.type, getDetailsData: { date, completion in

                        })
                    }))
                }, failure: { error in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error.localizedDescription)
                    }))
                })
                
                updateIsLoading(graph.identifier, false)
                
                index += 1
            case .OnDemand:
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                }))
                index += 1
                if !uiState.loading.contains(graph.identifier) {
                    graph.load(graph.identifier)
                }
            case let .Failed(error):
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error)
                }))
                index += 1
                updateIsLoading(graph.identifier, false)
            case .Empty:
                break
            }
        }
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        
        if let messages = search?.0, !messages.messages.isEmpty {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.statsMessagePublicForwardsTitleHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for (i, message) in messages.messages.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_message(message.id), equatable: InputDataEquatable(message), item: { initialSize, stableId in
                    return MessageSharedRowItem(initialSize, stableId: stableId, context: accountContext, message: message, viewType: bestGeneralViewType(messages.messages, for: i), action: {
                        openMessage(message.id)
                    })
                }))
                index += 1
            }
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("loading"), equatable: nil, item: { initialSize, stableId in
            return StatisticsLoadingRowItem(initialSize, stableId: stableId, context: accountContext, text: L10n.channelStatsLoading)
        }))
    }
    
    
    return entries
}


func MessageStatsController(_ context: AccountContext, messageId: MessageId, datacenterId: Int32) -> ViewController {
    
    let initialState = UIStatsState(loading: [])
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<MessageStats?>(nil)
    let messagesPromise = Promise<(SearchMessagesResult, SearchMessagesState)?>(nil)
    
    
    let statsContext = MessageStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, messageId: messageId)
    let dataSignal: Signal<MessageStats?, NoError> = statsContext.state
        |> map { state in
            return state.stats
    }
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let openMessage: (MessageId)->Void = { messageId in
        context.sharedContext.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(messageId.peerId), messageId: messageId))
    }
    
    let searchSignal = searchMessages(account: context.account, location: .publicForwards(messageId: messageId, datacenterId: Int(datacenterId)), query: "", state: nil)
        |> map(Optional.init)
        |> afterNext { result in
            if let result = result {
                for message in result.0.messages {
                    if let peer = message.peers[message.id.peerId], let peerReference = PeerReference(peer) {
                        let _ = updatedRemotePeer(postbox: context.account.postbox, network: context.account.network, peer: peerReference).start()
                    }
                }
            }
    }
    messagesPromise.set(.single(nil) |> then(searchSignal))

    
    
    let signal = combineLatest(dataPromise.get(), messagesPromise.get(), statePromise.get())
        |> deliverOnMainQueue
        |> map { data, search, state -> [InputDataEntry] in
            return statsEntries(data, search, state, openMessage: openMessage, updateIsLoading: { identifier, isLoading in
                updateState { state in
                    if isLoading {
                        return state.withAddedLoading(identifier)
                    } else {
                        return state.withRemovedLoading(identifier)
                    }
                }
            }, context: statsContext, accountContext: context)
        } |> map {
            return InputDataSignalValue(entries: $0)
        }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    
    let controller = InputDataController(dataSignal: signal, title: L10n.statsMessageTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.contextOject = statsContext
    controller.didLoaded = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
    }
    
    return controller
}
