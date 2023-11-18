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

import GraphCore


private final class Arguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openMessage: (EngineMessage.Id) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (EngineMessage.Id) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
    }
}




private func _id_message(_ messageId: MessageId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_message_\(messageId)")
}

private func statsEntries(_ stats: PostStats?, _ search: (SearchMessagesResult, SearchMessagesState)?, _ uiState: UIStatsState, arguments: Arguments, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, accountContext: AccountContext) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0

    
    if let stats = stats {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        overviewItems.append(ChannelOverviewItem(title: "Views", value: .initialize(string: stats.views.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
       
        if let search = search, search.0.totalCount > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsMessagePublicForwardsTitle, value: .initialize(string: Int(search.0.totalCount).formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
        }
        
        if stats.forwards > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsMessagePrivateForwardsTitle, value: .initialize(string: "≈" + stats.forwards.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
        }
    
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), comparable: nil, item: { initialSize, stableId in
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
            graphs.append(Graph(graph: stats.interactionsGraph, title: strings().statsMessageInteractionsTitle, identifier: InputDataIdentifier("interactionsGraph"), type: chartType, load: { identifier in
                updateIsLoading(identifier, true)
                let _ = arguments.loadDetailedGraph(stats.interactionsGraph, stats.interactionsGraphDelta * 1000).start(next: { graph in
                    if let graph = graph, case .Loaded = graph {
                        updateIsLoading(identifier, false)
                    }
                })
            }))
        }
        
        if !stats.reactionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.reactionsGraph, title: strings().statsMessageReactionsTitle, identifier: InputDataIdentifier("reactionsGraph"), type: .bars, load: { identifier in
                updateIsLoading(identifier, true)
                let _ = arguments.loadDetailedGraph(stats.reactionsGraph, stats.interactionsGraphDelta).start(next: { graph in
                    if let graph = graph, case .Loaded = graph {
                        updateIsLoading(identifier, false)
                    }
                })
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
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: accountContext, collection: collection, viewType: .singleItem, type: graph.type, getDetailsData: { date, completion in

                        })
                    }))
                }, failure: { error in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticLoadingRowItem(initialSize, stableId: stableId, error: error.localizedDescription)
                    }))
                })
                
                updateIsLoading(graph.identifier, false)
                
                index += 1
            case .OnDemand:
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                    return StatisticLoadingRowItem(initialSize, stableId: stableId, error: nil)
                }))
                index += 1
                if !uiState.loading.contains(graph.identifier) {
                    graph.load(graph.identifier)
                }
            case let .Failed(error):
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
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
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsMessagePublicForwardsTitleHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for (i, message) in messages.messages.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_message(message.id), equatable: InputDataEquatable(message), comparable: nil, item: { initialSize, stableId in
                    return MessageSharedRowItem(initialSize, stableId: stableId, context: accountContext, message: message, viewType: bestGeneralViewType(messages.messages, for: i), action: {
                        arguments.openMessage(message.id)
                    })
                }))
                index += 1
            }
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    } else {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return StatisticsLoadingRowItem(initialSize, stableId: stableId, context: accountContext, text: strings().channelStatsLoading)
        }))
    }
    
    
    return entries
}

protocol PostStats {
    var views: Int { get }
    var forwards: Int { get }
    var interactionsGraph: StatsGraph { get }
    var interactionsGraphDelta: Int64 { get }
    var reactionsGraph: StatsGraph { get }
}

extension MessageStats: PostStats {
    
}

extension StoryStats: PostStats {
    
}

enum MessageStatsSubject {
    case messageId(MessageId)
    case story(EngineStoryItem, EnginePeer)
}

func MessageStatsController(_ context: AccountContext, subject: MessageStatsSubject, datacenterId: Int32) -> ViewController {
    
    let initialState = UIStatsState(loading: [])
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<PostStats?>(nil)
    let messagesPromise = Promise<(SearchMessagesResult, SearchMessagesState)?>(nil)
    
    let anyStatsContext: Any
    let dataSignal: Signal<PostStats?, NoError>
    var loadDetailedGraphImpl: ((StatsGraph, Int64) -> Signal<StatsGraph?, NoError>)?
    switch subject {
    case let .messageId(messageId):
        let statsContext = MessageStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, messageId: messageId)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
    case let .story(storyItem, peer):
        let statsContext = StoryStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peer.id, storyId: storyItem.id)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
    }
    
    let arguments = Arguments.init(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return loadDetailedGraphImpl?(graph, x) ?? .single(nil)
    }, openMessage: { messageId in
        context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(messageId.peerId), focusTarget: .init(messageId: messageId)))
    })
    

    if case let .messageId(messageId) = subject {
        let searchSignal = context.engine.messages.searchMessages(location: .publicForwards(messageId: messageId, datacenterId: Int(datacenterId)), query: "", state: nil)
            |> map(Optional.init)
            |> afterNext { result in
                if let result = result {
                    for message in result.0.messages {
                        if let peer = message.peers[message.id.peerId], let peerReference = PeerReference(peer) {
                            let _ = context.engine.peers.updatedRemotePeer(peer: peerReference).start()
                        }
                    }
                }
        }
        messagesPromise.set(.single(nil) |> then(searchSignal))
    } else {
        messagesPromise.set(.single(nil))
    }
    

    
    
    let signal = combineLatest(dataPromise.get(), messagesPromise.get(), statePromise.get())
        |> deliverOnMainQueue
        |> map { data, search, state -> [InputDataEntry] in
            return statsEntries(data, search, state, arguments: arguments, updateIsLoading: { identifier, isLoading in
                updateState { state in
                    if isLoading {
                        return state.withAddedLoading(identifier)
                    } else {
                        return state.withRemovedLoading(identifier)
                    }
                }
            }, accountContext: context)
        } |> map {
            return InputDataSignalValue(entries: $0)
        }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    let title: String
    switch subject {
    case .messageId:
        title = strings().statsMessageTitle
    case .story:
        title = strings().statsMessageStatsStoryTitle
    }
    
    let controller = InputDataController(dataSignal: signal, title: title, removeAfterDisappear: false, hasDone: false)
    
    controller.contextObject = anyStatsContext
    
    controller.didLoaded = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
    }
    
    return controller
}
