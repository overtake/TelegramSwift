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
    let openMessage: (StoryStatsPublicForwardsContext.State.Forward) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (StoryStatsPublicForwardsContext.State.Forward) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessage = openMessage
    }
}




private func _id_forward(_ forward: StoryStatsPublicForwardsContext.State.Forward) -> InputDataIdentifier {
    switch forward {
    case let .message(message):
        return InputDataIdentifier("_id_message_\(message.id)")
    case let .story(_, storyItem):
        return InputDataIdentifier("_id_story_item_\(storyItem.id)")
    }
}

private func _id_message(_ message: Message) -> InputDataIdentifier {
    return InputDataIdentifier("_id_message_\(message.id)")
}


private func statsEntries(_ stats: PostStats?, storyViews: EngineStoryItem.Views?, forwards: StoryStatsPublicForwardsContext.State?, _ uiState: UIStatsState, arguments: Arguments, isStory: Bool, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, accountContext: AccountContext) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0

    
    if let stats = stats {
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        var views: Int = 0
        if let stats = stats as? MessageStats {
            views = stats.views
        } else if let storyView = storyViews {
            views = Int(storyView.seenCount)
        }
        
        overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewViews, value: .initialize(string: views.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
       
        
        var publicShares: Int32?
        if let forwards = forwards {
            publicShares = forwards.count
        }

        
        if let publicShares = publicShares, publicShares > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().statsMessagePublicForwardsTitle, value: .initialize(string: Int(publicShares).formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
        }
        
        var privateForwards: Int = 0
        if let stats = stats as? MessageStats {
            privateForwards = stats.forwards
        } else if let storyView = storyViews {
            privateForwards = Int(storyView.forwardCount)
        }
        
        let header: String
        if isStory {
            header = strings().statsMessagePrivateForwardsTitle
        } else {
            header = strings().channelStatsOverviewStoryPrivateShares
        }
        overviewItems.append(ChannelOverviewItem(title: header, value: .initialize(string: "≈" + privateForwards.formattedWithSeparator, color: theme.colors.text, font: .medium(.text))))
    
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
        
        
        
        struct Tuple: Equatable {
            let target: StoryStatsPublicForwardsContext.State.Forward
            let viewType: GeneralViewType
        }
        
        
        if let forwards = forwards, !forwards.forwards.isEmpty {
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().statsMessagePublicForwardsTitleHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            var items: [Tuple] = []
            
            for (i, forward) in forwards.forwards.enumerated() {
                items.append(.init(target: forward, viewType: bestGeneralViewType(forwards.forwards, for: i)))
            }
            
            for item in items {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_forward(item.target), equatable: InputDataEquatable(item), comparable: nil, item: { initialSize, stableId in
                    return MessageSharedRowItem(initialSize, stableId: stableId, context: accountContext, forward: item.target, viewType: item.viewType, action: {
                        arguments.openMessage(item.target)
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

func MessageStatsController(_ context: AccountContext, subject: MessageStatsSubject) -> ViewController {
    
    let initialState = UIStatsState(loading: [])
    
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<PostStats?>(nil)
    let forwardsPromise = Promise<StoryStatsPublicForwardsContext.State?>(nil)


    let anyStatsContext: Any
    let dataSignal: Signal<PostStats?, NoError>
    var loadDetailedGraphImpl: ((StatsGraph, Int64) -> Signal<StatsGraph?, NoError>)?
    
    let forwardsContext: StoryStatsPublicForwardsContext

    switch subject {
    case let .messageId(id):
        let statsContext = MessageStatsContext(account: context.account, messageId: id)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
        
        forwardsContext = StoryStatsPublicForwardsContext(account: context.account, subject: .message(messageId: id))

    case let .story(storyItem, peer):
        let statsContext = StoryStatsContext(account: context.account, peerId: peer.id, storyId: storyItem.id)
        loadDetailedGraphImpl = { [weak statsContext] graph, x in
            return statsContext?.loadDetailedGraph(graph, x: x) ?? .single(nil)
        }
        dataSignal = statsContext.state
        |> map { state in
            return state.stats
        }
        dataPromise.set(.single(nil) |> then(dataSignal))
        anyStatsContext = statsContext
        
        
        forwardsContext = StoryStatsPublicForwardsContext(account: context.account, subject: .story(peerId: peer.id, id: storyItem.id))
    }

    forwardsPromise.set(forwardsContext.state |> map(Optional.init))
    
    let arguments = Arguments.init(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return loadDetailedGraphImpl?(graph, x) ?? .single(nil)
    }, openMessage: { target in
        var peers: [Peer] = []
        switch target {
        case let .message(message):
            peers = message.peers.map( { $0.1 })
            context.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(message.id.peerId), focusTarget: .init(messageId: message.id)))
        case let .story(peer, item):
            peers = [peer._asPeer()]
            StoryModalController.ShowSingleStory(context: context, storyId: .init(peerId: peer.id, id: item.id), initialId: nil)
        }
        _ = context.account.postbox.transaction ({ transaction -> Void in
            updatePeersCustom(transaction: transaction, peers: peers, update: { (_, updated) -> Peer? in
                return updated
            })
        }).startStandalone()
    })
    

    let isStory: Bool
    switch subject {
    case .messageId:
        isStory = false
    case .story:
        isStory = true
    }
    
    let signal = combineLatest(dataPromise.get(), forwardsPromise.get(), statePromise.get())
        |> deliverOnMainQueue
        |> map { data, forwards, state -> [InputDataEntry] in
            
            var storyViews: EngineStoryItem.Views?
            switch subject {
            case .messageId:
                storyViews = nil
            case let .story(storyItem, _):
                storyViews = storyItem.views
            }

            
            return statsEntries(data, storyViews: storyViews, forwards: forwards, state, arguments: arguments, isStory: isStory, updateIsLoading: { identifier, isLoading in
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
        _ = forwardsContext
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
    
    controller.didLoad = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
    }
    
    return controller
}
