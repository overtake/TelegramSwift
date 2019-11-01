//
//  ChannelDiscussionGroup.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit


private final class DiscussionArguments {
    let context: AccountContext
    let createGroup:()->Void
    let setup:(Peer)->Void
    let openInfo:(PeerId) -> Void
    let unlinkGroup: (Peer)->Void
    init(context: AccountContext, createGroup: @escaping()->Void, setup: @escaping(Peer)->Void, openInfo: @escaping(PeerId)->Void, unlinkGroup: @escaping(Peer)->Void) {
        self.context = context
        self.createGroup = createGroup
        self.setup = setup
        self.openInfo = openInfo
        self.unlinkGroup = unlinkGroup
    }
}

private func generateDiscussIcon() -> CGImage {
    let image: CGImage
    switch theme.colors.name {
    case systemPalette.name:
        image = NSImage(named: "DiscussDarkPreview")!.precomposed()
    case tintedNightPalette.name:
        image = NSImage(named: "DiscussDarkBluePreview")!.precomposed()
    default:
        if theme.colors.isDark {
            image = NSImage(named: "DiscussDarkBluePreview")!.precomposed()
        } else {
            image = NSImage(named: "DiscussDayPreview")!.precomposed()
        }
    }
    
    
    return generateImage(image.backingSize, contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.draw(image, in: NSMakeRect(0, 0, size.width, size.height))
        
        let palette = theme.colors
        
        let attributeString: NSAttributedString = .initialize(string: L10n.discussionControllerIconText, color: palette.accentIcon, font: .normal(12))
        
        let node = TextNode.layoutText(maybeNode: nil, attributeString, palette.background, 1, .end, NSMakeSize(size.width - 10, size.height), nil, false, .center)

        ctx.translateBy(x: size.width / 2.0, y: size.height / 2.0)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)
        
        let xpos: CGFloat = (size.width - node.0.size.width) / 2
        node.1.draw(NSMakeRect(xpos, size.height - 26, node.0.size.width, node.0.size.height), in: ctx, backingScaleFactor: System.backingScale, backgroundColor: palette.background)
    })!
}

private enum DiscussionType {
    case group
    case channel
}

private final class DiscussionState : Equatable {
    let type: DiscussionType
    let availablePeers:[Peer]
    let associatedPeer: Peer?
    let unlinkAbility: Bool
    let searchState: SearchState?
    init(type: DiscussionType, availablePeers: [Peer], associatedPeer: Peer?, unlinkAbility: Bool, searchState: SearchState?) {
        self.type = type
        self.searchState = searchState
        self.availablePeers = availablePeers
        self.associatedPeer = associatedPeer
        self.unlinkAbility = unlinkAbility
    }
    
    var filteredPeers: [Peer] {
        return self.availablePeers.filter { peer in
            if let search = self.searchState, !search.request.isEmpty {
                return peer.displayTitle.lowercased().hasPrefix(search.request.lowercased()) || !peer.displayTitle.lowercased().components(separatedBy: " ").filter {$0.hasPrefix(search.request.lowercased())}.isEmpty

            } else {
                return true
            }
        }
    }
    
    func withUpdatedassociatedPeer(_ associatedPeer: Peer?) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: self.availablePeers, associatedPeer: associatedPeer, unlinkAbility: self.unlinkAbility, searchState: self.searchState)
    }
    func withUpdatedAvailablePeers(_ availablePeers: [Peer]) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: availablePeers, associatedPeer: self.associatedPeer, unlinkAbility: self.unlinkAbility, searchState: self.searchState)
    }
    
    func withUpdatedUnlinkAbility(_ unlinkAbility: Bool) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: self.availablePeers, associatedPeer: self.associatedPeer, unlinkAbility: unlinkAbility, searchState: self.searchState)
    }
    
    func withUpdatedSearchState(_ searchState: SearchState) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: self.availablePeers, associatedPeer: self.associatedPeer, unlinkAbility: self.unlinkAbility, searchState: searchState)
    }
    
    static func == (lhs: DiscussionState, rhs: DiscussionState) -> Bool {
        if let lhsassociatedPeer = lhs.associatedPeer, let rhsassociatedPeer = rhs.associatedPeer {
            if !lhsassociatedPeer.isEqual(rhsassociatedPeer) {
                return false
            }
        } else if (lhs.associatedPeer != nil) != (rhs.associatedPeer != nil) {
            return false
        }
        
        if lhs.searchState != rhs.searchState {
            return false
        }
        
        if lhs.availablePeers.count != rhs.availablePeers.count {
            return false
        } else {
            for (i, lhsPeer) in lhs.availablePeers.enumerated() {
                if !lhsPeer.isEqual(rhs.availablePeers[i]) {
                    return false
                }
            }
        }
        return true
    }
    
}
private let _id_channel_header = InputDataIdentifier("_id_channel_header")
private let _id_group_header = InputDataIdentifier("_id_group_header")

private let _id_create_group = InputDataIdentifier("_id_create_group")
private let _id_unlink_group = InputDataIdentifier("_id_unlink_group")
private func _id_peer(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())")
}
private func _id_peer_info(_ peerId: PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(peerId.toInt64())_info")
}



private func channelDiscussionEntries(state: DiscussionState, arguments: DiscussionArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    let applyList:()->Void = {
        
        let peers = state.filteredPeers
        
        for (i, peer) in peers.enumerated() {
            
            let status = peer.addressName != nil ? "@\(peer.addressName!)" : (peer.isSupergroup || peer.isGroup ? L10n.discussionControllerPrivateGroup : L10n.discussionControllerPrivateChannel)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.id), equatable: InputDataEquatable(PeerEquatable(peer: peer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: i == 0 ? .innerItem : bestGeneralViewType(peers, for: i), action: {
                    arguments.setup(peer)
                })
            }))
            index += 1
        }
    }
    
    switch state.type {
    case .channel:
        if let associatedPeer = state.associatedPeer {
            let text = L10n.discussionControllerChannelSetHeader(associatedPeer.displayTitle)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel_header, equatable: InputDataEquatable(text), item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: text, color: theme.colors.grayText, font: .normal(.text))
                attributedString.detectBoldColorInString(with: .medium(.text))
                
                return DiscussionHeaderItem(initialSize, stableId: stableId, icon: generateDiscussIcon(), text: attributedString)
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            let status = associatedPeer.addressName != nil ? "@\(associatedPeer.addressName!)" : (associatedPeer.isSupergroup ? L10n.discussionControllerPrivateGroup : L10n.discussionControllerPrivateChannel)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_info(associatedPeer.id), equatable: InputDataEquatable(PeerEquatable(peer: associatedPeer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: associatedPeer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: .singleItem, action: {
                    arguments.openInfo(associatedPeer.id)
                })
            }))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerChannelSetDescription), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
            
            if state.unlinkAbility {
                entries.append(.sectionId(sectionId, type: .normal))
                sectionId += 1
                
                entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unlink_group, data: InputDataGeneralData(name: L10n.discussionControllerChannelSetUnlinkGroup, color: theme.colors.redUI, viewType: .singleItem, action: {
                    arguments.unlinkGroup(associatedPeer)
                })))
                index += 1
            }
            
        } else {
            let text = L10n.discussionControllerChannelEmptyHeader

            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel_header, equatable: InputDataEquatable(text), item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: text, color: theme.colors.grayText, font: .normal(.text))
                return DiscussionHeaderItem(initialSize, stableId: stableId, icon: generateDiscussIcon(), text: attributedString)
            }))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            if state.searchState == nil || state.searchState!.request.isEmpty {
                
                let viewType: GeneralViewType = state.filteredPeers.isEmpty ? .singleItem : .firstItem
                
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_create_group, equatable: InputDataEquatable(viewType), item: { initialSize, stableId in
                    return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.discussionControllerChannelEmptyCreateGroup, nameStyle: blueActionButton, viewType: viewType, action: arguments.createGroup, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 52, thumbInset: 9))
                }))
                index += 1
            }
           
            applyList()
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerChannelEmptyDescription), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
            
        }
    case .group:
        if let associatedPeer = state.associatedPeer {
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel_header, equatable: nil, item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: L10n.discussionControllerGroupSetHeader(associatedPeer.displayTitle), color: theme.colors.grayText, font: .normal(.text))
                attributedString.detectBoldColorInString(with: .medium(.text))
                
                return DiscussionHeaderItem(initialSize, stableId: stableId, icon: generateDiscussIcon(), text: attributedString)
            }))
            
            index += 1
            
            let status = associatedPeer.addressName != nil ? "@\(associatedPeer.addressName!)" : (associatedPeer.isSupergroup ? L10n.discussionControllerPrivateGroup : L10n.discussionControllerPrivateChannel)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer_info(associatedPeer.id), equatable: InputDataEquatable(PeerEquatable(peer: associatedPeer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: associatedPeer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), viewType: .singleItem, action: {
                    arguments.openInfo(associatedPeer.id)
                })
            }))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerGroupSetDescription), data: InputDataGeneralTextData(viewType: .textBottomItem)))
            index += 1
            
            entries.append(.sectionId(sectionId, type: .normal))
            sectionId += 1
            
            entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unlink_group, data: InputDataGeneralData(name: L10n.discussionControllerGroupSetUnlinkChannel, color: theme.colors.redUI, viewType: .singleItem, action: {
                arguments.unlinkGroup(associatedPeer)
            })))
            index += 1
        } else {
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_group_header, equatable: nil, item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: L10n.discussionControllerGroupUnsetDescription, color: theme.colors.grayText, font: .normal(.text))
                return GeneralTextRowItem(initialSize, stableId: stableId, text: attributedString, alignment: .center, centerViewAlignment: true, viewType: .textBottomItem)
            }))
            
        }
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func ChannelDiscussionSetupController(context: AccountContext, peer: Peer)-> InputDataController {
    
    let initialState = DiscussionState(type: peer.isChannel ? .channel : .group, availablePeers: [], associatedPeer: nil, unlinkAbility: false, searchState: nil)
    
    let stateValue: Atomic<DiscussionState> = Atomic(value: initialState)
    let statePromise:ValuePromise<DiscussionState> = ValuePromise(ignoreRepeated: true)
    
    let updateState:((DiscussionState)->DiscussionState)->Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    
    let searchValue:Atomic<TableSearchViewState> = Atomic(value: .none)
    let searchPromise: ValuePromise<TableSearchViewState> = ValuePromise(.none, ignoreRepeated: true)
    let updateSearchValue:((TableSearchViewState)->TableSearchViewState)->Void = { f in
        searchPromise.set(searchValue.modify(f))
    }
    
    
    let searchData = TableSearchVisibleData(cancelImage: theme.icons.chatSearchCancel, cancel: {
        updateSearchValue { _ in
            return .none
        }
    }, updateState: { searchState in
        updateState {
            $0.withUpdatedSearchState(searchState)
        }
    })
    
    let actionsDisposable = DisposableSet()

    func setup(_ channelId: PeerId, _ groupId: PeerId?, updatePreHistory: Bool = false) -> Void {
        let signal: Signal<Bool, ChannelDiscussionGroupError>
        
        if let groupId = groupId, groupId.namespace == Namespaces.Peer.CloudGroup {
            signal = convertGroupToSupergroup(account: context.account, peerId: groupId)
                |> mapError { _ in return ChannelDiscussionGroupError.generic }
                |> mapToSignal { upgradedPeerId in
                return updateGroupDiscussionForChannel(network: context.account.network, postbox: context.account.postbox, channelId: channelId, groupId: upgradedPeerId)
            }
        } else if updatePreHistory, let groupId = groupId {
            signal = updateChannelHistoryAvailabilitySettingsInteractively(postbox: context.account.postbox, network: context.account.network, accountStateManager: context.account.stateManager, peerId: groupId, historyAvailableForNewMembers: true)
                |> mapError { error -> ChannelDiscussionGroupError in
                    switch error {
                    case .generic:
                        return .generic
                    case .hasNotPermissions:
                        return .hasNotPermissions
                    }
                } |> mapToSignal { _ in
                return updateGroupDiscussionForChannel(network: context.account.network, postbox: context.account.postbox, channelId: channelId, groupId: groupId)
            }
        } else {
            signal = updateGroupDiscussionForChannel(network: context.account.network, postbox: context.account.postbox, channelId: channelId, groupId: groupId)
        }
        
        actionsDisposable.add(showModalProgress(signal: signal |> deliverOnMainQueue, for: context.window).start(next: { result in
            if result && groupId == nil && initialState.type == .group {
                context.sharedContext.bindings.rootNavigation().back()
            }
            updateSearchValue { current in
                return .none
            }
        }, error: { error in
            switch error {
            case .groupHistoryIsCurrentlyPrivate:
                confirm(for: context.window, information: L10n.discussionControllerErrorPreHistory, okTitle: L10n.discussionControllerErrorOK, successHandler: { _ in
                    setup(channelId, groupId, updatePreHistory: true)
                })
            case .hasNotPermissions:
                alert(for: context.window, info: L10n.channelErrorDontHavePermissions)
            default:
                alert(for: context.window, info: L10n.unknownError)
            }
        }))
    }
    
    let arguments = DiscussionArguments(context: context, createGroup: {
        let controller = context.sharedContext.bindings.rootNavigation().controller
        actionsDisposable.add(createSupergroup(with: context, defaultText: peer.displayTitle + " Chat").start(next: { [weak controller] peerId in
            if let peerId = peerId, let controller = controller {
                setup(peer.id, peerId)
                context.sharedContext.bindings.rootNavigation().removeUntil(InputDataController.self)
                context.sharedContext.bindings.rootNavigation().push(controller)
            }
        }))
    }, setup: { selected in
        showModal(with: DiscussionSetModalController(context: context, channel: peer, group: selected, accept: {
            if selected.isChannel {
                setup(selected.id, peer.id)
            } else {
                setup(peer.id, selected.id)
            }
        }), for: context.window)
    }, openInfo: { peerId in
        context.sharedContext.bindings.rootNavigation().push(ChatAdditionController(context: context, chatLocation: .peer(peerId)))
    }, unlinkGroup: { associated in
        if associated.isChannel {
            confirm(for: context.window, information: L10n.discussionControllerConfrimUnlinkChannel, successHandler: { _ in
                setup(associated.id, nil)
            })
        } else {
            confirm(for: context.window, information: L10n.discussionControllerConfrimUnlinkGroup, successHandler: { _ in
                setup(peer.id, nil)
            })
        }
    })
    
    
    let dataSignal = statePromise.get() |> map { state in
        return channelDiscussionEntries(state: state, arguments: arguments)
    }
    
    var updateBarIsHidden:((Bool)->Void)? = nil

    
    actionsDisposable.add(context.account.postbox.peerView(id: peer.id).start(next: { peerView in
        updateState { current in
            var current = current
            let peer = peerViewMainPeer(peerView)
            if let cachedData = peerView.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                current = current.withUpdatedassociatedPeer(peerView.peers[linkedDiscussionPeerId])
            } else {
                current = current.withUpdatedassociatedPeer(nil)
            }
            if let linkedPeer = current.associatedPeer as? TelegramChannel, linkedPeer.isChannel {
                current = current.withUpdatedUnlinkAbility(linkedPeer.hasPermission(.pinMessages))
            } else if let peer = peer as? TelegramChannel {
                current = current.withUpdatedUnlinkAbility(peer.hasPermission(.pinMessages))
            }
            return current
        }
    }))
    
    
    let availableSignal = peer.isChannel ? availableGroupsForChannelDiscussion(postbox: context.account.postbox, network: context.account.network) : .single([])
    
    actionsDisposable.add(availableSignal.start(next: { peers in
        updateState {
            $0.withUpdatedAvailablePeers(peers)
        }
    }, error: { error in
        
    }))
    
    
   
    
    
    
    return InputDataController(dataSignal: combineLatest(dataSignal, searchPromise.get()) |> map { InputDataSignalValue(entries: $0, searchState: $1) }, title: peer.isChannel ? L10n.discussionControllerChannelTitle : L10n.discussionControllerGroupTitle, afterDisappear: {
        actionsDisposable.dispose()
    }, removeAfterDisappear: false, hasDone: false, customRightButton: { controller in
        let bar = ImageBarView(controller: controller, theme.icons.chatSearch)
        bar.button.set(handler: { _ in
            updateSearchValue { current in
                switch current {
                case .none:
                    return .visible(searchData)
                case .visible:
                    return .none
                }
            }
        }, for: .Click)
        updateBarIsHidden = { [weak bar] isHidden in
            bar?.button.alphaValue = isHidden ? 0 : 1
        }
        //let isHidden = stateValue.with {$0.associatedPeer != nil && $0.availablePeers.count > 5}
        

        return bar
    }, afterTransaction: { controller in
        
        let isHidden = stateValue.with {$0.associatedPeer != nil || $0.availablePeers.count < 5}
        updateBarIsHidden?(isHidden)
        
    }, returnKeyInvocation: { _, _  in
        let state = stateValue.with { $0 }
        
        if state.associatedPeer == nil, state.type == .channel, state.filteredPeers.count == 1, let searchState = state.searchState, !searchState.request.isEmpty {
            arguments.setup(state.filteredPeers[0])
            return .nothing
        }
        
        return .default
    }, deleteKeyInvocation: { _ in
        
        let state = stateValue.with { $0 }

        if let peer = state.associatedPeer, state.unlinkAbility {
            arguments.unlinkGroup(peer)
            return .invoked
        }
        
        return .default
    }, searchKeyInvocation: {
        
        let state = stateValue.with { $0 }

        if state.associatedPeer == nil, state.availablePeers.count > 5 {
            updateSearchValue { current in
                switch current {
                case .none:
                    return .visible(searchData)
                case .visible:
                    return .none
                }
            }
        }
        
                
        return .invoked
    })
}
