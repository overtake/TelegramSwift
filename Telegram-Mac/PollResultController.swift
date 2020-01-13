//
//  PollResultController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07.01.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore


private struct PollResultState : Equatable {
    let results: PollResultsState?
    let shouldLoadMore: Data?
    let poll: TelegramMediaPoll
    init(results: PollResultsState?, poll: TelegramMediaPoll, shouldLoadMore: Data?) {
        self.results = results
        self.poll = poll
        self.shouldLoadMore = nil
    }
    func withUpdatedResults(_ results: PollResultsState?) -> PollResultState {
        return PollResultState(results: results, poll: self.poll, shouldLoadMore: self.shouldLoadMore)
    }
    func withUpdatedShouldLoadMore(_ shouldLoadMore: Data?) -> PollResultState {
        return PollResultState(results: self.results, poll: self.poll, shouldLoadMore: shouldLoadMore)
    }
}
private func _id_option(_ identifier: Data, _ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_option_\(identifier.base64EncodedString())_\(peerId.toInt64())")
}
private func _id_load_more(_ identifier: Data) -> InputDataIdentifier {
    return InputDataIdentifier("_id_load_more_\(identifier.base64EncodedString())")
}
private func _id_loading_for(_ identifier: Data) -> InputDataIdentifier {
    return InputDataIdentifier("_id_loading_for_\(identifier.base64EncodedString())")
}
private let _id_loading = InputDataIdentifier("_id_loading")

private func pollResultEntries(_ state: PollResultState, context: AccountContext, openProfile:@escaping(PeerId)->Void, loadMore: @escaping(Data)->Void) -> [InputDataEntry] {
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    var entries:[InputDataEntry] = []
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(state.poll.text), data: InputDataGeneralTextData(color: theme.colors.text, detectBold: true, viewType: .modern(position: .inner, insets: NSEdgeInsetsMake(0, 16, 0, 16)), fontSize: .huge)))
    index += 1
    
    
    
    let poll = state.poll
    
    var votes:[Int] = []
    
    
    
    for option in poll.options {
        let count = Int(poll.results.voters?.first(where: {$0.opaqueIdentifier == option.opaqueIdentifier})?.count ?? 0)
        votes.append(count)
    }
    
    let percents = countNicePercent(votes: votes, total: Int(poll.results.totalVoters ?? 0))
    
    struct Option : Equatable {
        let option: TelegramMediaPollOption
        let percent: Int
        let voters:PollResultsOptionState
    }
    
    
    var options:[Option] = []
    for (i, option) in poll.options.enumerated() {
        if let voters = state.results?.options[option.opaqueIdentifier], !voters.peers.isEmpty {
            options.append(Option(option: option, percent: percents[i], voters: voters))
        }
    }
    
    if options.isEmpty {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading, equatable: nil, item: { initialSize, stableId in
            return GeneralTextRowItem(initialSize, stableId: stableId, text: "", alignment: .center, additionLoading: true, viewType: .innerItem)
        }))
    } else {
        for option in options {
            if option == options.first {
                entries.append(.sectionId(sectionId, type: .customModern(16)))
                sectionId += 1
            } else {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
            }
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(option.option.text), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem, rightItem: .init(isLoading: false, text: .initialize(string: "\(option.percent)%", color: theme.colors.listGrayText, font: .normal(11.5))))))
            index += 1
            
            for (i, voter) in option.voters.peers.enumerated() {
                if let peer = voter.peer {
                    var viewType = bestGeneralViewType(option.voters.peers, for: i)
                    if i == option.voters.peers.count - 1, option.voters.canLoadMore {
                        viewType = .innerItem
                    }
                    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_option(option.option.opaqueIdentifier, peer.id), equatable: InputDataEquatable(option), item: { initialSize, stableId in
                        return ShortPeerRowItem(initialSize, peer: peer, account: context.account, stableId: stableId, height: 46, photoSize: NSMakeSize(32, 32), inset: NSEdgeInsets(left: 30, right: 30), generalType: .none, viewType: viewType, action: {
                            openProfile(peer.id)
                        })
                    }))
                    index += 1
                }
            }
            
            if option.voters.canLoadMore {
                
                if option.voters.isLoadingMore {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_loading_for(option.option.opaqueIdentifier), equatable: nil, item: { initialSize, stableId in
                        return LoadingTableItem(initialSize, height: 41, stableId: stableId, viewType: .lastItem)
                    }))
                    index += 1
                } else {
                    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_load_more(option.option.opaqueIdentifier), equatable: nil, item: { initialSize, stableId in
                        return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.pollResultsLoadMore, nameStyle: blueActionButton, type: .none, viewType: .lastItem, action: {
                            loadMore(option.option.opaqueIdentifier)
                        }, thumb: GeneralThumbAdditional(thumb: theme.icons.chatSearchUp, textInset: 52, thumbInset: 4))
                    }))
                    index += 1
                }
                
               
            }
        }
    }
    
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func PollResultController(context: AccountContext, message: Message) -> InputDataModalController {

    let poll = message.media[0] as! TelegramMediaPoll
    
    let resultsContext: PollResultsContext = PollResultsContext(account: context.account, messageId: message.id, poll: poll)

    let initialState = PollResultState(results: nil, poll: poll, shouldLoadMore: nil)
    
    let disposable = MetaDisposable()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((PollResultState) -> PollResultState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    disposable.set(resultsContext.state.start(next: { results in
        updateState {
            $0.withUpdatedResults(results)
        }
    }))
    
    var openProfile:((PeerId)->Void)? = nil
    
    let signal = statePromise.get() |> map {
        pollResultEntries($0, context: context, openProfile: { peerId in
            openProfile?(peerId)
        }, loadMore: { opaqueIdentifier in
            updateState {
                $0.withUpdatedShouldLoadMore(opaqueIdentifier)
            }
            resultsContext.loadMore(optionOpaqueIdentifier: opaqueIdentifier)
        })
    } |> map {
        InputDataSignalValue(entries: $0, animated: true)
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.pollResultsTitle)
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    controller.contextOject = resultsContext
    
    let modalController = InputDataModalController(controller)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    controller.getBackgroundColor = {
        theme.colors.listBackground
    }
    
    openProfile = { [weak modalController] peerId in
        context.sharedContext.bindings.rootNavigation().push(PeerInfoController(context: context, peerId: peerId))
        modalController?.close()
    }
    
//    controller.didLoaded = { controller, _ in
//        controller.tableView.setScrollHandler { position in
//            switch position.direction {
//            case .bottom:
//                let shouldLoadMore = stateValue.with { $0.shouldLoadMore }
//                if let shouldLoadMore = shouldLoadMore {
//                    resultsContext.loadMore(optionOpaqueIdentifier: shouldLoadMore)
//                }
//               break
//            default:
//                break
//            }
//        }
//    }
    

    
    return modalController
}
