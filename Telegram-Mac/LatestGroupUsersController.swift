//
//  LatestGroupUsersController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/06/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class LatestPeersArguments {
    let account: Account
    let peerInfo:(PeerId)->Void
    init(account: Account, peerInfo: @escaping(PeerId)->Void) {
        self.account = account
        self.peerInfo = peerInfo
    }
}


private struct LatestPeerEquatable : Equatable {
    let peer: Peer
    let presence: PeerPresence?
    let memberStatus: GroupInfoMemberStatus
    let inputActivity: PeerInputActivity?
    
    static func == (lhs: LatestPeerEquatable, rhs: LatestPeerEquatable) -> Bool {
        if !lhs.peer.isEqual(rhs.peer) {
            return false
        }
        if let lhsPresence = lhs.presence, let rhsPresence = rhs.presence {
            if !lhsPresence.isEqual(to: rhsPresence) {
                return false
            }
        } else if (lhs.presence != nil) != (rhs.presence != nil) {
            return false
        }
        if lhs.memberStatus != rhs.memberStatus {
            return false
        }
        if lhs.inputActivity != rhs.inputActivity {
            return false
        }
        
        return true
    }
}


private func latestGroupEntries(_ view: PeerView, inputActivities: [PeerId : PeerInputActivity], arguments: LatestPeersArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var index: Int32 = 0
    var sectionId: Int32 = 0
    
   
    var latestPeers:[LatestPeerEquatable] = []
    
    if let cachedGroupData = view.cachedData as? CachedGroupData, let participants = cachedGroupData.participants {
        
        var peers: [PeerId: Peer] = view.peers
        
        let sortedParticipants = participants.participants.filter({peers[$0.peerId]?.displayTitle != L10n.peerDeletedUser}).sorted(by: { lhs, rhs in
            let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
            
            let lhsActivity = inputActivities[lhs.peerId]
            let rhsActivity = inputActivities[rhs.peerId]
            
            if lhsActivity != nil && rhsActivity == nil {
                return true
            } else if rhsActivity != nil && lhsActivity == nil {
                return false
            }
            
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                return lhsPresence.status > rhsPresence.status
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }
            
            return lhs < rhs
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = view.peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                switch sortedParticipants[i] {
                case .admin, .creator:
                    memberStatus = .admin
                case .member:
                    memberStatus = .member
                }
                latestPeers.append(LatestPeerEquatable(peer: peer, presence: view.peerPresences[peer.id], memberStatus: memberStatus, inputActivity: inputActivities[peer.id]))
            }
        }
    }
    
    if let cachedGroupData = view.cachedData as? CachedChannelData, let participants = cachedGroupData.topParticipants {
        
        var peers: [PeerId: Peer] = view.peers
        
        let sortedParticipants = participants.participants.filter({peers[$0.peerId]?.displayTitle != L10n.peerDeletedUser}).sorted(by: { lhs, rhs in
            let lhsPresence = view.peerPresences[lhs.peerId] as? TelegramUserPresence
            let rhsPresence = view.peerPresences[rhs.peerId] as? TelegramUserPresence
            
//            let lhsAdmin: Int
//            switch lhs {
//            case let .member(_, _, adminInfo, _):
//                lhsAdmin = adminInfo != nil ? 1 : 0
//            case .creator:
//                lhsAdmin = 1
//            }
//            
//            let rhsAdmin: Int
//            switch rhs {
//            case let .member(_, _, adminInfo, _):
//                rhsAdmin = adminInfo != nil ? 1 : 0
//            case .creator:
//                rhsAdmin = 1
//            }
            
            
            let lhsActivity = inputActivities[lhs.peerId]
            let rhsActivity = inputActivities[rhs.peerId]
            
            if lhsActivity != nil && rhsActivity == nil {
                return true
            } else if rhsActivity != nil && lhsActivity == nil {
                return false
            }
            
            
            
            if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                return lhsPresence.status > rhsPresence.status
            } else if let _ = lhsPresence {
                return true
            } else if let _ = rhsPresence {
                return false
            }

            return lhs < rhs
        })
        
        for i in 0 ..< sortedParticipants.count {
            if let peer = view.peers[sortedParticipants[i].peerId] {
                let memberStatus: GroupInfoMemberStatus
                switch sortedParticipants[i] {
                case .creator:
                    memberStatus = .admin
                case .member(_, _, let adminRights, _):
                    memberStatus = adminRights != nil ? .admin : .member
                }
                latestPeers.append(LatestPeerEquatable(peer: peer, presence: view.peerPresences[peer.id], memberStatus: memberStatus, inputActivity: inputActivities[peer.id]))
            }
        }
    }
    
  //  entries.append(.sectionId(sectionId))
  //  sectionId += 1
    for latest in latestPeers {
        
        
        let label: String
        switch latest.memberStatus {
        case .admin:
            label = L10n.peerInfoAdminLabel
        case .member:
            label = ""
        }
        
        var string:String = L10n.peerStatusRecently
        var color:NSColor = theme.colors.grayText
        
        if let presence = latest.presence as? TelegramUserPresence {
            let timestamp = CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970
            (string, _, color) = stringAndActivityForUserPresence(presence, timeDifference: arguments.account.context.timeDifference, relativeTo: Int32(timestamp))
        } else if let peer = latest.peer as? TelegramUser, let botInfo = peer.botInfo {
            string = botInfo.flags.contains(.hasAccessToChatHistory) ? L10n.peerInfoBotStatusHasAccess : L10n.peerInfoBotStatusHasNoAccess
        }
        
        entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: InputDataIdentifier("\(latest.peer.id.hashValue)"), equatable: InputDataEquatable(latest), item: { (initialSize, stableId) -> TableRowItem in
            return ShortPeerRowItem(NSMakeSize(300, 50), peer: latest.peer, account: arguments.account, stableId: stableId, enabled: true, height: 46, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(12.5), foregroundColor: theme.colors.text), statusStyle: ControlStyle(font: .normal(12.5), foregroundColor:color), status: string, inset:NSEdgeInsets(left: 20,right: 20), interactionType: .plain, generalType: label.isEmpty ? .none : .context(label), action: {
                arguments.peerInfo(latest.peer.id)
            }, inputActivity: latest.inputActivity)
        }))
        
        
        index += 1
    }
    
  //  entries.append(.sectionId(sectionId))
   // sectionId += 1
    
    
    return entries
}

func latestGroupUsers(chatInteraction: ChatInteraction, f:@escaping(InputDataController)->Void) -> InputDataController {
    
    let inputActivity = chatInteraction.account.peerInputActivities(peerId: chatInteraction.peerId)
        |> map { activities -> [PeerId : PeerInputActivity] in
            return activities.reduce([:], { (current, activity) -> [PeerId : PeerInputActivity] in
                var current = current
                current[activity.0] = activity.1
                return current
            })
    }
    
    var controller: InputDataController? = nil
    
    let arguments = LatestPeersArguments(account: chatInteraction.account, peerInfo: { peerId in
        chatInteraction.openInfo(peerId, false, nil, nil)
        controller?.closePopover()
    })
    
    let inputActivityState: Promise<[PeerId : PeerInputActivity]> = Promise([:])
    
    inputActivityState.set(inputActivity)
    
    let dataSignal = combineLatest(chatInteraction.account.viewTracker.peerView(chatInteraction.peerId) |> deliverOnPrepareQueue, inputActivityState.get() |> deliverOnPrepareQueue) |> map { peerView, activities -> [InputDataEntry] in
        return latestGroupEntries(peerView, inputActivities: activities, arguments: arguments)
    }

    
    let _controller = InputDataController(dataSignal: dataSignal, title: "", afterDisappear: {
        controller = nil
    }, didLoaded: { _ in
        if let controller = controller {
            f(controller)
        }
    })
    
    
    
    controller = _controller
    
    return _controller
}
