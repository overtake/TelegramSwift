//
//  GroupCallPeerController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 09.03.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//


import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore
import Postbox
import SyncCore

private final class Arguments {
    let account: Account
    let openInfo:(PeerId)->Void
    let openChat:(PeerId)->Void
    let joinChannel:(PeerId)->Void
    let leaveChannel:(PeerId)->Void
    init(account: Account, openInfo: @escaping(PeerId)->Void, openChat: @escaping(PeerId)->Void, joinChannel: @escaping(PeerId)->Void, leaveChannel: @escaping(PeerId)->Void) {
        self.account = account
        self.openInfo = openInfo
        self.openChat = openChat
        self.joinChannel = joinChannel
        self.leaveChannel = leaveChannel
    }
}

private struct State : Equatable {
    static func == (lhs: State, rhs: State) -> Bool {
        if lhs.peer != rhs.peer {
            return false
        }
        if let lhsCachedData = lhs.cachedData, let rhsCachedData = rhs.cachedData {
            if !lhsCachedData.isEqual(to: rhsCachedData) {
                return false
            }
        } else if (lhs.cachedData != nil) != (rhs.cachedData != nil) {
            return false
        }
        return true
    }
    
    var peer: PeerEquatable
    var cachedData: CachedPeerData?
}

private struct ActionTuple: Equatable {
    static func == (lhs: ActionTuple, rhs: ActionTuple) -> Bool {
        return lhs.title == rhs.title && lhs.viewType == rhs.viewType
    }
    
    var title: String
    var action:()->Void
    var viewType: GeneralViewType
    
    var id: InputDataIdentifier {
        return .init(title)
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let theme = GroupCallTheme.customTheme
    
   
    
    struct InfoTuple : Equatable {
        var title: String
        var info: String
        var viewType:GeneralViewType
        
        var id: InputDataIdentifier {
            return .init(title)
        }
    }
    
    var info:[InfoTuple] = []
    if let user = state.peer.peer as? TelegramUser {
        let phoneNumber: String
        if let phone = user.phone {
            phoneNumber = formatPhoneNumber(phone)
        } else {
            phoneNumber = L10n.newContactPhoneHidden
        }
        info.append(.init(title: L10n.peerInfoPhone, info: phoneNumber, viewType: .singleItem))
    }
    if let addressName = state.peer.peer.addressName {
        info.append(.init(title: L10n.peerInfoUsername, info: "@\(addressName)", viewType: .singleItem))
    }
    if state.peer.peer.isScam {
        info.append(.init(title: L10n.peerInfoScam, info: L10n.peerInfoScamWarning, viewType: .singleItem))
    } else if state.peer.peer.isFake {
        info.append(.init(title: L10n.peerInfoFake, info: L10n.peerInfoFakeWarning, viewType: .singleItem))
    } else if let cachedData = state.cachedData as? CachedUserData, let about = cachedData.about, !about.isEmpty {
        info.append(.init(title: L10n.peerInfoAbout, info: about, viewType: .singleItem))
    } else if let cachedData = state.cachedData as? CachedChannelData, let about = cachedData.about, !about.isEmpty {
        info.append(.init(title: L10n.peerInfoAbout, info: about, viewType: .singleItem))
    }
    
    let viewType: GeneralViewType = info.isEmpty ? .singleItem : .firstItem
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("avatar"), equatable: InputDataEquatable(state), item: { initialSize, stableId in
        return GroupCallPeerAvatarRowItem(initialSize, stableId: stableId, account: arguments.account, peer: state.peer.peer, viewType: viewType, customTheme: theme)
    }))
    index += 1
    
    
    for i in 0 ..< info.count {
        var value = info[i]
        if i == 0 {
            if info.count == 1 {
                value.viewType = .lastItem
            } else {
                value.viewType = .innerItem
            }
        } else {
            value.viewType = bestGeneralViewType(info, for: i)
        }
        info[i] = value
    }
    
    if !info.isEmpty {
//        entries.append(.sectionId(sectionId, type: .normal))
//        sectionId += 1

        for info in info {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: info.id, equatable: InputDataEquatable(info), item: { initialSize, stableId in
                return GroupCallTextAndLabelItem(initialSize, stableId: stableId, label: info.title, text: info.info, viewType: info.viewType, customTheme: theme)
            }))
            index += 1
        }
    }
    
    var actions:[ActionTuple] = []
    
    if let peer = state.peer.peer as? TelegramUser {
        actions.append(.init(title: L10n.voiceChatInfoSendMessage, action: {
            arguments.openChat(peer.id)
        }, viewType: .singleItem))
        
        actions.append(.init(title: L10n.voiceChatInfoOpenProfile, action: {
            arguments.openInfo(peer.id)
        }, viewType: .singleItem))
    } else if let peer = state.peer.peer as? TelegramChannel {
        
        switch peer.participationStatus {
        case .kicked:
            break
        default:
            actions.append(.init(title: L10n.voiceChatInfoOpenChannel, action: {
                arguments.openChat(peer.id)
            }, viewType: .singleItem))
        }
       
        
        switch peer.participationStatus {
        case .left:
            actions.append(.init(title: L10n.voiceChatInfoJoinChannel, action: {
                arguments.joinChannel(peer.id)
            }, viewType: .singleItem))
        case .member:
            actions.append(.init(title: L10n.voiceChatInfoLeaveChannel, action: {
                arguments.leaveChannel(peer.id)
            }, viewType: .singleItem))
        case .kicked:
            break
        }
    }
   
    for i in 0 ..< actions.count {
        var value = actions[i]
        value.viewType = bestGeneralViewType(actions, for: i)
        actions[i] = value
    }
    
    if !actions.isEmpty  {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        for action in actions {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: action.id, data: .init(name: action.title, color: theme.accentColor, type: .none, viewType: action.viewType, action: action.action, theme: theme)))
            index += 1
        }
    }
    
    
    // entries
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func GroupCallPeerController(account: Account, peer: Peer) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(peer: PeerEquatable(peer))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getWindow:(()->Window?)? = nil
    
    actionsDisposable.add(account.viewTracker.peerView(peer.id, updateData: true).start(next: { peerView in
        updateState { current in
            var current = current
            if let peer = peerViewMainPeer(peerView) {
                current.peer = PeerEquatable(peer)
                current.cachedData = peerView.cachedData
            }
            return current
        }
    }))

    let arguments = Arguments(account: account, openInfo: { peerId in
        appDelegate?.navigateProfile(peerId, account: account)
    }, openChat: { peerId in
        appDelegate?.navigateChat(peerId, account: account)
    }, joinChannel: { peerId in
        if let window = getWindow?() {
            _ = showModalProgress(signal: joinChannel(account: account, peerId: peerId, hash: nil), for: window).start(error: { [weak window] error in
                let text: String
                switch error {
                case .generic:
                    text = L10n.unknownError
                case .tooMuchJoined:
                    text = L10n.joinChannelsTooMuch
                case .tooMuchUsers:
                    text = L10n.groupUsersTooMuchError
                }
                if let window = window {
                    alert(for: window, info: text, appearance: GroupCallTheme.customTheme.appearance)
                }
            })
        }

    }, leaveChannel: { peerId in
        if let window = getWindow?() {
            _ = showModalProgress(signal: removePeerChat(account: account, peerId: peerId, reportChatSpam: false, deleteGloballyIfPossible: false), for: window).start()
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: L10n.peerInfoInfo)
    
    controller.getBackgroundColor = {
        GroupCallTheme.windowBackground
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    let customTheme = GroupCallTheme.customTheme

    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(350, 300))
    
    controller.leftModalHeader = ModalHeaderData(image: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(customTheme.accentColor), handler: { [weak modalController] in
        modalController?.close()
    })
    
    
    modalController.getModalTheme = {
        .init(text: customTheme.textColor, grayText: customTheme.grayTextColor, background: customTheme.backgroundColor, border: customTheme.borderColor)
    }
    
    getWindow = { [weak modalController] in
        return modalController?.modal?.window
    }

    
    return modalController
}



