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
import SyncCore
import GraphCore

private struct UIStatsState : Equatable {
    let loading: Set<InputDataIdentifier>
    init(loading: Set<InputDataIdentifier>) {
        self.loading = loading
    }
    func withAddedLoading(_ token: InputDataIdentifier) -> UIStatsState {
        var loading = self.loading
        loading.insert(token)
        return UIStatsState(loading: loading)
    }
    func withRemovedLoading(_ token: InputDataIdentifier) -> UIStatsState {
        var loading = self.loading
        loading.remove(token)
        return UIStatsState(loading: loading)
    }
}

private func statsEntries(_ state: ChannelStatsContextState, uiState: UIStatsState, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, context: ChannelStatsContext) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    
    if state.stats == nil {
        entries.append(.loading)
    } else if let stats = state.stats  {
        
       // stats.messageInteractions.append(ChannelStatsMessageInteractions)
        
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("OVERVIEW"), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
        index += 1
        
        var overviewItems:[ChannelOverviewItem] = []
        
        overviewItems.append(ChannelOverviewItem(title: "Followers", value: stats.followers.attributedString))
        overviewItems.append(ChannelOverviewItem(title: "Enabled Notifications", value: stats.enabledNotifications.attributedString))
        overviewItems.append(ChannelOverviewItem(title: "Views Per Post", value: stats.viewsPerPost.attributedString))
        overviewItems.append(ChannelOverviewItem(title: "Shares Per Post", value: stats.sharesPerPost.attributedString))

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("overview"), equatable: InputDataEquatable(overviewItems), item: { initialSize, stableId in
            return ChannelOverviewStatsRowItem.init(initialSize, stableId: stableId, items: overviewItems, viewType: .singleItem)
        }))
        index += 1
        
        
        struct Graph {
            let graph: ChannelStatsGraph
            let title: String
            let identifier: InputDataIdentifier
            let type: ChartItemType
            let load:(InputDataIdentifier)->Void
        }
        
        var graphs: [Graph] = []
        graphs.append(Graph(graph: stats.growthGraph, title: "GROWTH", identifier: InputDataIdentifier("growthGraph"), type: .general, load: { identifier in
            context.loadGrowthGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.followersGraph, title: "FOLLOWERS", identifier: InputDataIdentifier("followersGraph"), type: .general, load: { identifier in
            context.loadFollowersGraph()
            updateIsLoading(identifier, true)
        }))

        graphs.append(Graph(graph: stats.viewsBySourceGraph, title: "VIEWS BY SOURCE", identifier: InputDataIdentifier("viewsBySourceGraph"), type: .daily, load: { identifier in
            context.loadViewsBySourceGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.newFollowersBySourceGraph, title: "NEW FOLLOWERS BY SOURCE", identifier: InputDataIdentifier("newFollowersBySourceGraph"), type: .daily, load: { identifier in
            context.loadNewFollowersBySourceGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.languagesGraph, title: "LANGUAGE", identifier: InputDataIdentifier("languagesGraph"), type: .percent, load: { identifier in
            context.loadLanguagesGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.muteGraph, title: "NOTIFICATIONS", identifier: InputDataIdentifier("muteGraph"), type: .general, load: { identifier in
            context.loadMuteGraph()
            updateIsLoading(identifier, true)
        }))
        graphs.append(Graph(graph: stats.interactionsGraph, title: "INTERACTIONS", identifier: InputDataIdentifier("interactionsGraph"), type: .general, load: { identifier in
            context.loadInteractionsGraph()
            updateIsLoading(identifier, true)
        }))

        for graph in graphs {
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(graph.title), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            switch graph.graph {
            case let .Loaded(_, string):                
                ChartsDataManager.readChart(data: string.data(using: .utf8)!, sync: true, success: { collection in
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: graph.identifier, equatable: InputDataEquatable(graph.graph), item: { initialSize, stableId in
                        return StatisticRowItem(initialSize, stableId: stableId, collection: collection, viewType: .singleItem, type: graph.type)
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

    
    
    let signal = combineLatest(queue: prepareQueue, statePromise.get(), statsContext.state) |> map { uiState, state in
        return statsEntries(state, uiState: uiState, updateIsLoading: { identifier, isLoading in
            updateState { state in
                if isLoading {
                    return state.withAddedLoading(identifier)
                } else {
                    return state.withRemovedLoading(identifier)
                }
            }
        }, context: statsContext)
    } |> map {
        return InputDataSignalValue(entries: $0)
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: "Channels Stats", hasDone: false)
    
    controller.contextOject = statsContext
    
    controller.didLoaded = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
    }
    
    return controller
}
/*
 private let peerId: PeerId
 private let statsContext: ChannelStatsContext
 init(_ context: AccountContext, peerId: PeerId, datacenterId: Int32) {
 self.peerId = peerId
 self.statsContext = ChannelStatsContext(network: context.account.network, postbox: context.account.postbox, datacenterId: datacenterId, peerId: peerId)
 super.init(context)
 }
 
 override func viewDidLoad() {
 super.viewDidLoad()
 
 readyOnce()
 
 //  self.statsContext.loadFollowersGraph()
 let signal = self.statsContext.state |> deliverOnMainQueue
 signal.start(next: { [weak self] state in
 if let state = state.stats {
 switch state.muteGraph {
 case let .Loaded(string):
 ChartsDataManager.readChart(data: string.data(using: .utf8)!, sync: false, success: { collection in
 let controller: BaseChartController
 // if bar {
 controller = DailyBarsChartController(chartsCollection: collection)
 // } else {
 // controller = GeneralLinesChartController(chartsCollection: collection)
 //  }
 self?.genericView.chartView.setup(controller: controller, title: "Mute graph")
 self?.genericView.chartView.apply(colorMode: .day, animated: false)
 
 
 }, failure: { error in
 var bp:Int = 0
 bp += 1
 })
 default:
 break
 }
 }
 })
 }
 */
