//
//  ChannelDiscussionGroup.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 23/05/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac


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
    case mojavePalette.name:
        image = NSImage(named: "DiscussDarkPreview")!.precomposed()
    case nightBluePalette.name:
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
        
        let attributeString: NSAttributedString = .initialize(string: L10n.discussionControllerIconText, color: palette.blueIcon, font: .normal(12))
        
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
    init(type: DiscussionType, availablePeers: [Peer], associatedPeer: Peer?) {
        self.type = type
        self.availablePeers = availablePeers
        self.associatedPeer = associatedPeer
    }
    
    func withUpdatedassociatedPeer(_ associatedPeer: Peer?) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: self.availablePeers, associatedPeer: associatedPeer)
    }
    func withUpdatedAvailablePeers(_ availablePeers: [Peer]) -> DiscussionState {
        return DiscussionState(type: self.type, availablePeers: availablePeers, associatedPeer: self.associatedPeer)
    }
    
    
    static func == (lhs: DiscussionState, rhs: DiscussionState) -> Bool {
        if let lhsassociatedPeer = lhs.associatedPeer, let rhsassociatedPeer = rhs.associatedPeer {
            if !lhsassociatedPeer.isEqual(rhsassociatedPeer) {
                return false
            }
        } else if (lhs.associatedPeer != nil) != (rhs.associatedPeer != nil) {
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



private func channelDiscussionEntries(state: DiscussionState, arguments: DiscussionArguments) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    

    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    let applyList:()->Void = {
        for peer in state.availablePeers {
            let status = peer.addressName != nil ? "@\(peer.addressName!)" : (peer.isSupergroup ? L10n.discussionControllerPrivateGroup : L10n.discussionControllerPrivateChannel)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.id), equatable: InputDataEquatable(PeerEquatable(peer: peer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: peer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), action: {
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
            
            let status = associatedPeer.addressName != nil ? "@\(associatedPeer.addressName!)" : (associatedPeer.isSupergroup ? L10n.discussionControllerPrivateGroup : L10n.discussionControllerPrivateChannel)
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(associatedPeer.id), equatable: InputDataEquatable(PeerEquatable(peer: associatedPeer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: associatedPeer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), action: {
                    arguments.openInfo(associatedPeer.id)
                })
            }))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerChannelSetDescription), color: theme.colors.grayText, detectBold: true))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unlink_group, data: InputDataGeneralData(name: L10n.discussionControllerChannelSetUnlinkGroup, color: theme.colors.redUI, action: {
                arguments.unlinkGroup(associatedPeer)
            })))
            index += 1

            
        } else {
            let text = L10n.discussionControllerChannelEmptyHeader

            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_channel_header, equatable: InputDataEquatable(text), item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: text, color: theme.colors.grayText, font: .normal(.text))
                return DiscussionHeaderItem(initialSize, stableId: stableId, icon: generateDiscussIcon(), text: attributedString)
            }))
            
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_create_group, equatable: nil, item: { initialSize, stableId in
                return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.discussionControllerChannelEmptyCreateGroup, nameStyle: blueActionButton, action: {
                    arguments.createGroup()
                }, thumb: GeneralThumbAdditional(thumb: theme.icons.peerInfoAddMember, textInset: 33), inset:NSEdgeInsets(left: 40, right: 30))
            }))
            index += 1
            applyList()
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerChannelEmptyDescription), color: theme.colors.grayText, detectBold: true))
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
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(associatedPeer.id), equatable: InputDataEquatable(PeerEquatable(peer: associatedPeer)), item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: associatedPeer, account: arguments.context.account, status: status, inset: NSEdgeInsetsMake(0, 30, 0, 30), action: {
                    arguments.openInfo(associatedPeer.id)
                })
            }))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.discussionControllerGroupSetDescription), color: theme.colors.grayText, detectBold: true))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_unlink_group, data: InputDataGeneralData(name: L10n.discussionControllerGroupSetUnlinkChannel, color: theme.colors.redUI, action: {
                arguments.unlinkGroup(associatedPeer)
            })))
            index += 1
        } else {
            entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_group_header, equatable: nil, item: { initialSize, stableId in
                
                let attributedString = NSMutableAttributedString()
                _ = attributedString.append(string: L10n.discussionControllerGroupUnsetDescription, color: theme.colors.grayText, font: .normal(.text))
                return GeneralTextRowItem(initialSize, stableId: stableId, text: attributedString, alignment: .center, centerViewAlignment: true)
            }))
            
        }
    }
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    return entries
}

func ChannelDiscussionSetupController(context: AccountContext, peer: Peer)-> InputDataController {
    
    let initialState = DiscussionState(type: peer.isChannel ? .channel : .group, availablePeers: [], associatedPeer: nil)
    
    let stateValue: Atomic<DiscussionState> = Atomic(value: initialState)
    let statePromise:ValuePromise<DiscussionState> = ValuePromise(ignoreRepeated: true)
    
    let updateState:((DiscussionState)->DiscussionState)->Void = { f in
        statePromise.set(stateValue.modify(f))
    }
    
    let actionsDisposable = DisposableSet()

    func setup(_ channelId: PeerId, _ groupId: PeerId?) -> Void {
        actionsDisposable.add(showModalProgress(signal: updateGroupDiscussionForChannel(network: context.account.network, postbox: context.account.postbox, channelId: channelId, groupId: groupId), for: context.window).start(next: { result in
            if result && groupId == nil && initialState.type == .group {
                context.sharedContext.bindings.rootNavigation().back()
            }
        }, error: { error in
            alert(for: context.window, info: L10n.unknownError)
        }))
    }
    
    let arguments = DiscussionArguments(context: context, createGroup: {
        let controller = context.sharedContext.bindings.rootNavigation().controller
        actionsDisposable.add(createSupergroup(with: context, for: context.sharedContext.bindings.rootNavigation()).start(next: { [weak controller] peerId in
            if let peerId = peerId, let controller = controller {
                setup(peer.id, peerId)
                context.sharedContext.bindings.rootNavigation().removeUntil(InputDataController.self)
                context.sharedContext.bindings.rootNavigation().push(controller)
            }
        }))
    }, setup: { selected in
        showModal(with: DiscussionSetModalController(context: context, channel: selected, group: peer, accept: {
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
    
    
    actionsDisposable.add(context.account.postbox.peerView(id: peer.id).start(next: { peerView in
        updateState { current in
            var current = current
            if let cachedData = peerView.cachedData as? CachedChannelData, let associatedPeerId = cachedData.associatedPeerId {
                current = current.withUpdatedassociatedPeer(peerView.peers[associatedPeerId])
            } else {
                current = current.withUpdatedassociatedPeer(nil)
            }
            
            return current
        }
    }))
    
    
    let availableSignal = peer.isChannel ? availableGroupsForChannelDiscussion(network: context.account.network) : availableChannelsForGroupDiscussion(network: context.account.network)
    
    actionsDisposable.add(availableSignal.start(next: { peers in
        updateState {
            $0.withUpdatedAvailablePeers(peers)
        }
    }, error: { error in
        
    }))
    
    return InputDataController(dataSignal: dataSignal |> map { ($0, true)}, title: peer.isChannel ? L10n.discussionControllerChannelTitle : L10n.discussionControllerGroupTitle, afterDisappear: {
        actionsDisposable.dispose()
    }, removeAfterDisappear: false, hasDone: false)
}
