//
//  ChannelStatsViewController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox

import GraphCore



struct UIStatsState : Equatable {
    
    enum RevealSection : Hashable {
        case topPosters
        case topAdmins
        case topInviters
        
        var id: InputDataIdentifier {
            switch self {
            case .topPosters:
                return InputDataIdentifier("_id_top_posters")
            case .topAdmins:
                return InputDataIdentifier("_id_top_admins")
            case .topInviters:
                return InputDataIdentifier("_id_top_inviters")
            }
        }
    }
    
    let loading: Set<InputDataIdentifier>
    let revealed:Set<RevealSection>
    init(loading: Set<InputDataIdentifier>, revealed: Set<RevealSection> = Set()) {
        self.loading = loading
        self.revealed = revealed
    }
    func withAddedLoading(_ token: InputDataIdentifier) -> UIStatsState {
        var loading = self.loading
        loading.insert(token)
        return UIStatsState(loading: loading, revealed: self.revealed)
    }
    func withRemovedLoading(_ token: InputDataIdentifier) -> UIStatsState {
        var loading = self.loading
        loading.remove(token)
        return UIStatsState(loading: loading, revealed: self.revealed)
    }
    
    func withRevealedSection(_ section: RevealSection) -> UIStatsState {
        var revealed = self.revealed
        revealed.insert(section)
        return UIStatsState(loading: self.loading, revealed: revealed)
    }
}

private func _id_message(_ messageId: MessageId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_message_\(messageId)")
}

private func statsEntries(_ state: ChannelStatsContextState, uiState: UIStatsState, messages: [Message]?, interactions: [MessageId : ChannelStatsMessageInteractions]?, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, openMessage: @escaping(MessageId)->Void, context: ChannelStatsContext, accountContext: AccountContext, detailedDisposable: DisposableDict<InputDataIdentifier>) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    if state.stats == nil {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return StatisticsLoadingRowItem(initialSize, stableId: stableId, context: accountContext, text: strings().channelStatsLoading)
        }))
    } else if let stats = state.stats  {
        
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsOverview), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        if stats.followers.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewFollowers, value: stats.followers.attributedString))
        }
        if stats.enabledNotifications.total != 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewEnabledNotifications, value: stats.enabledNotifications.attributedString))
        }
        if stats.viewsPerPost.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewViewsPerPost, value: stats.viewsPerPost.attributedString))
        }
        if stats.sharesPerPost.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewSharesPerPost, value: stats.sharesPerPost.attributedString))
        }

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), comparable: nil, item: { initialSize, stableId in
            return ChannelOverviewStatsRowItem(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
        }))
        index += 1
        
        
        struct Graph {
            let graph: StatsGraph
            let title: String
            let identifier: InputDataIdentifier
            let type: ChartItemType
            let load:(InputDataIdentifier)->Void
        }
        
        var graphs: [Graph] = []
        graphs.append(Graph(graph: stats.growthGraph, title: strings().channelStatsGraphGrowth, identifier: InputDataIdentifier("growthGraph"), type: .lines, load: { identifier in
            context.loadGrowthGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.followersGraph, title: strings().channelStatsGraphFollowers, identifier: InputDataIdentifier("followersGraph"), type: .lines, load: { identifier in
            context.loadFollowersGraph()
            updateIsLoading(identifier, true)
        }))

        graphs.append(Graph(graph: stats.muteGraph, title: strings().channelStatsGraphNotifications, identifier: InputDataIdentifier("muteGraph"), type: .lines, load: { identifier in
            context.loadMuteGraph()
            updateIsLoading(identifier, true)
        }))
        
        
        graphs.append(Graph(graph: stats.topHoursGraph, title: strings().channelStatsGraphViewsByHours, identifier: InputDataIdentifier("topHoursGraph"), type: .hourlyStep, load: { identifier in
            context.loadTopHoursGraph()
            updateIsLoading(identifier, true)
        }))
        
        if !stats.viewsBySourceGraph.isEmpty {
            graphs.append(Graph(graph: stats.viewsBySourceGraph, title: strings().channelStatsGraphViewsBySource, identifier: InputDataIdentifier("viewsBySourceGraph"), type: .bars, load: { identifier in
                context.loadViewsBySourceGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        
        if !stats.newFollowersBySourceGraph.isEmpty {
            graphs.append(Graph(graph: stats.newFollowersBySourceGraph, title: strings().channelStatsGraphNewFollowersBySource, identifier: InputDataIdentifier("newFollowersBySourceGraph"), type: .bars, load: { identifier in
                context.loadNewFollowersBySourceGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        
        if !stats.languagesGraph.isEmpty {
            graphs.append(Graph(graph: stats.languagesGraph, title: strings().channelStatsGraphLanguage, identifier: InputDataIdentifier("languagesGraph"), type: .pie, load: { identifier in
                context.loadLanguagesGraph()
                updateIsLoading(identifier, true)
            }))
        }
        

    
        if !stats.interactionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.interactionsGraph, title: strings().channelStatsGraphInteractions, identifier: InputDataIdentifier("interactionsGraph"), type: .twoAxisStep, load: { identifier in
                context.loadInteractionsGraph()
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
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), comparable: nil, item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, context: accountContext, collection: collection, viewType: .singleItem, type: graph.type, getDetailsData: { date, completion in
                            detailedDisposable.set(context.loadDetailedGraph(graph.graph, x: Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                                if let graph = graph, case let .Loaded(_, data) = graph {
                                    completion(data)
                                }
                            }), forKey: graph.identifier)
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
        
        if let messages = messages, let interactions = interactions, !messages.isEmpty {
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsRecentHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for (i, message) in messages.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_message(message.id), equatable: InputDataEquatable(message), comparable: nil, item: { initialSize, stableId in
                    return ChannelRecentPostRowItem(initialSize, stableId: stableId, context: accountContext, message: message, interactions: interactions[message.id], viewType: bestGeneralViewType(messages, for: i), action: {
                        openMessage(message.id)
                    })
                }))
                index += 1
            }
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
        }
    }
    
   
    return entries
}


func ChannelStatsViewController(_ context: AccountContext, peerId: PeerId, datacenterId: Int32) -> ViewController {

    let initialState = UIStatsState(loading: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let statsContext = ChannelStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)

    
    let messagesPromise = Promise<MessageHistoryView?>(nil)

    
    let messageView = context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil)
        |> map { messageHistoryView, _, _ -> MessageHistoryView? in
            return messageHistoryView
    }
    messagesPromise.set(.single(nil) |> then(messageView))

    let openMessage: (MessageId)->Void = { messageId in
        context.bindings.rootNavigation().push(MessageStatsController(context, messageId: messageId, datacenterId: datacenterId))
    }
    
    let detailedDisposable = DisposableDict<InputDataIdentifier>()
    
    let signal = combineLatest(queue: prepareQueue, statePromise.get(), statsContext.state, messagesPromise.get()) |> map { uiState, state, messageView in
        
        
        let interactions = state.stats?.messageInteractions.reduce([MessageId : ChannelStatsMessageInteractions]()) { (map, interactions) -> [MessageId : ChannelStatsMessageInteractions] in
            var map = map
            map[interactions.messageId] = interactions
            return map
        }
        
        let messages = messageView?.entries.map { $0.message }.filter { interactions?[$0.id] != nil }.sorted(by: { (lhsMessage, rhsMessage) -> Bool in
            return lhsMessage.timestamp > rhsMessage.timestamp
        })
        

        
        return statsEntries(state, uiState: uiState, messages: messages, interactions: interactions, updateIsLoading: { identifier, isLoading in
            updateState { state in
                if isLoading {
                    return state.withAddedLoading(identifier)
                } else {
                    return state.withRemovedLoading(identifier)
                }
            }
        }, openMessage: openMessage, context: statsContext, accountContext: context, detailedDisposable: detailedDisposable)
    } |> map {
        return InputDataSignalValue(entries: $0)
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: strings().channelStatsTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.contextObject = statsContext
    controller.didLoaded = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    controller.onDeinit = {
        detailedDisposable.dispose()
    }
    
    return controller
}
