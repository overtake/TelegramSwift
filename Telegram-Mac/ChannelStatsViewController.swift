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


enum StatsPostItem: Equatable {
    static func == (lhs: StatsPostItem, rhs: StatsPostItem) -> Bool {
        switch lhs {
        case let .message(lhsMessage, _):
            if case let .message(rhsMessage, _) = rhs {
                return lhsMessage.id == rhsMessage.id
            } else {
                return false
            }
        case let .story(lhsStory, _, _):
            if case let .story(rhsStory, _, _) = rhs, lhsStory == rhsStory {
                return true
            } else {
                return false
            }
        }
    }
    
    case message(Message, ChannelStatsPostInteractions)
    case story(EngineStoryItem, PeerEquatable, ChannelStatsPostInteractions)
    
    var isStory: Bool {
        if case .story = self {
            return true
        } else {
            return false
        }
    }
    
    var timestamp: Int32 {
        switch self {
        case let .message(message, _):
            return message.timestamp
        case let .story(story, _, _):
            return story.timestamp
        }
    }
    
    var identifier: InputDataIdentifier {
        switch self {
        case let .message(message, _):
            return _id_message(message.id)
        case let .story(story, _, _):
            return _id_story(story)
        }
    }
    
    var views: Int {
        switch self {
        case let .message(message, interactions):
            return Int(max(message.channelViewsCount ?? 0, interactions.views))
        case let .story(story, _, interactions):
            return Int(max(story.views?.seenCount ?? 0, Int(interactions.views)))
        }
    }
    var shares: Int {
        switch self {
        case let .message(_, interactions):
            return Int(interactions.forwards)
        case let .story(_, _, interactions):
            return Int(interactions.forwards)
        }
    }
    var likes: Int {
        switch self {
        case let .message(_, interactions):
            return Int(interactions.reactions)
        case let .story(_, _, interactions):
            return Int(interactions.reactions)
        }
    }
    
    var imageReference: ImageMediaReference? {
        if let image = self.image {
            switch self {
            case let .message(message, _):
                return ImageMediaReference.message(message: MessageReference(message), media: image)
            case let .story(story, peer, _):
                if let peerReference = PeerReference(peer.peer) {
                    return ImageMediaReference.story(peer: peerReference, id: story.id, media: image)
                }
            }
        }
        return nil
    }
    
    var image: TelegramMediaImage? {
        switch self {
        case let .message(message, _):
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    return image
                } else if let file = media as? TelegramMediaFile {
                    if file.isVideo && !file.isInstantVideo {
                        let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
                        if let iconImageRepresentation = iconImageRepresentation {
                            return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                        }
                    }
                } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                    if let image = content.image {
                        return image
                    } else if let file = content.file {
                        if file.isVideo && !file.isInstantVideo {
                            let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
                            if let iconImageRepresentation = iconImageRepresentation {
                                return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                            }
                        }
                    }
                }
            }
        case let .story(story, _, _):
            if let image = story.media._asMedia() as? TelegramMediaImage {
                return image
            } else if let file = story.media._asMedia() as? TelegramMediaFile {
                if file.isVideo && !file.isInstantVideo {
                    let iconImageRepresentation:TelegramMediaImageRepresentation? = smallestImageRepresentation(file.previewRepresentations)
                    if let iconImageRepresentation = iconImageRepresentation {
                        return TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [iconImageRepresentation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                    }
                }
            }
        }
        return nil
    }
    
    var title: String {
        switch self {
        case let .message(message, _):
            return pullText(from: message).string as String
        case .story:
            return strings().statsStoryTitle
        }
    }
}


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
private func _id_story(_ story: EngineStoryItem) -> InputDataIdentifier {
    return InputDataIdentifier("_id_story\(story.id)")
}


private func statsEntries(_ state: ChannelStatsContextState, uiState: UIStatsState, peer: Peer, messages: [Message]?, stories: PeerStoryListContext.State?, interactions: [ChannelStatsPostInteractions.PostId : ChannelStatsPostInteractions]?, updateIsLoading: @escaping(InputDataIdentifier, Bool)->Void, openPost: @escaping(StatsPostItem)->Void, context: ChannelStatsContext, accountContext: AccountContext, detailedDisposable: DisposableDict<InputDataIdentifier>) -> [InputDataEntry] {
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
        if stats.viewsPerStory.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewViewsPerStory, value: stats.viewsPerStory.attributedString))
        }
        if stats.sharesPerPost.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewSharesPerPost, value: stats.sharesPerPost.attributedString))
        }
        if stats.sharesPerStory.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewSharesPerStory, value: stats.sharesPerStory.attributedString))
        }
        if stats.reactionsPerPost.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewReactionsPerPost, value: stats.reactionsPerPost.attributedString))
        }
        if stats.reactionsPerStory.current > 0 {
            overviewItems.append(ChannelOverviewItem(title: strings().channelStatsOverviewReactionsPerStory, value: stats.reactionsPerStory.attributedString))
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
        
        if !stats.reactionsByEmotionGraph.isEmpty {
            graphs.append(Graph(graph: stats.reactionsByEmotionGraph, title: strings().channelStatsGraphReactions, identifier: InputDataIdentifier("reactionsByEmotionGraph"), type: .bars, load: { identifier in
                context.loadReactionsByEmotionGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.storyInteractionsGraph.isEmpty {
            graphs.append(Graph(graph: stats.storyInteractionsGraph, title: strings().channelStatsGraphStories, identifier: InputDataIdentifier("storyInteractionsGraph"), type: .twoAxisStep, load: { identifier in
                context.loadStoryInteractionsGraph()
                updateIsLoading(identifier, true)
            }))
        }
        
        if !stats.storyReactionsByEmotionGraph.isEmpty {
            graphs.append(Graph(graph: stats.storyReactionsByEmotionGraph, title: strings().channelStatsGraphStoriesReactions, identifier: InputDataIdentifier("storyReactionsByEmotionGraph"), type: .bars, load: { identifier in
                context.loadStoryReactionsByEmotionGraph()
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
        
        var posts: [StatsPostItem] = []
        if let messages = messages {
            for message in messages {
                if let interactions = interactions?[.message(id: message.id)] {
                    posts.append(.message(message, interactions))
                }
            }
        }
        if let stories = stories {
            for story in stories.items {
                if let interactions = interactions?[.story(peerId: peer.id, id: story.storyItem.id)] {
                    posts.append(.story(story.storyItem, .init(peer), interactions))
                }
            }
        }
        posts.sort(by: { $0.timestamp > $1.timestamp })

        
        if !posts.isEmpty {
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().channelStatsRecentHeader), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
            index += 1
            
            for (i, postStats) in posts.enumerated() {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: postStats.identifier, equatable: InputDataEquatable(postStats), comparable: nil, item: { initialSize, stableId in
                    return ChannelRecentPostRowItem(initialSize, stableId: stableId, context: accountContext, postStats: postStats, viewType: bestGeneralViewType(posts, for: i), action: {
                        openPost(postStats)
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

private final class SegmentedBarView : BarView {
    private let segmentControl: CatalinaStyledSegmentController
    required init(frame frameRect: NSRect) {
        self.segmentControl = CatalinaStyledSegmentController(frame: NSMakeRect(0, 0, 240, 30))
        super.init(frame: frameRect)
        addSubview(segmentControl.view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


func ChannelStatsViewController(_ context: AccountContext, peerId: PeerId) -> ViewController {

    let initialState = UIStatsState(loading: [])
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((UIStatsState) -> UIStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    
    let statsContext = ChannelStatsContext(postbox: context.account.postbox, network: context.account.network, peerId: peerId)

    
    let messagesPromise = Promise<MessageHistoryView?>(nil)

    
    let messageView = context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil)
        |> map { messageHistoryView, _, _ -> MessageHistoryView? in
            return messageHistoryView
    }
    messagesPromise.set(.single(nil) |> then(messageView))

    let openPost: (StatsPostItem)->Void = { item in
        let subject: MessageStatsSubject
        switch item {
        case let .message(message, _):
            subject = .messageId(message.id)
        case let .story(story, peer, _):
            subject = .story(story, .init(peer.peer))
        }
        context.bindings.rootNavigation().push(MessageStatsController(context, subject: subject))
    }
    
    let detailedDisposable = DisposableDict<InputDataIdentifier>()
    
    let storiesPromise = Promise<PeerStoryListContext.State?>()

    let storyList = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false, folderId: nil)
    storyList.loadMore()
    storiesPromise.set(
        .single(nil)
        |> then(
            storyList.state
            |> map(Optional.init)
        )
    )
    
    let signal = combineLatest(queue: prepareQueue, statePromise.get(), statsContext.state, messagesPromise.get(), storiesPromise.get(), context.account.postbox.loadedPeerWithId(peerId)) |> map { uiState, state, messageView, stories, peer in
        
        
        let interactions = state.stats?.postInteractions.reduce([ChannelStatsPostInteractions.PostId : ChannelStatsPostInteractions]()) { (map, interactions) -> [ChannelStatsPostInteractions.PostId : ChannelStatsPostInteractions] in
            var map = map
            map[interactions.postId] = interactions
            return map
        }

        let messages = messageView?.entries.map { $0.message }.sorted(by: { (lhsMessage, rhsMessage) -> Bool in
            return lhsMessage.timestamp > rhsMessage.timestamp
        })
        
        return statsEntries(state, uiState: uiState, peer: peer, messages: messages, stories: stories, interactions: interactions, updateIsLoading: { identifier, isLoading in
            updateState { state in
                if isLoading {
                    return state.withAddedLoading(identifier)
                } else {
                    return state.withRemovedLoading(identifier)
                }
            }
        }, openPost: openPost, context: statsContext, accountContext: context, detailedDisposable: detailedDisposable)
    } |> map {
        return InputDataSignalValue(entries: $0)
    } |> afterDisposed {
        let _ = storyList.state
    }
    
    
    let controller = InputDataController(dataSignal: signal, title: strings().channelStatsTitle, removeAfterDisappear: false, hasDone: false)
    
    controller.contextObject = statsContext
    controller.didLoad = { controller, _ in
        controller.tableView.alwaysOpenRowsOnMouseUp = true
        controller.tableView.needUpdateVisibleAfterScroll = true
    }
    
    
    controller.onDeinit = {
        detailedDisposable.dispose()
    }
    
    return controller
}
