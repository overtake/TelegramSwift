//
//  GroupCallInv.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 12.12.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import Postbox
import SyncCore
import TelegramCore

private final class InvitationArguments {
    let account: Account
    let copyLink: (String)->Void
    let inviteGroupMember:(PeerId)->Void
    let inviteContact:(PeerId)->Void
    init(account: Account, copyLink: @escaping(String)->Void, inviteGroupMember:@escaping(PeerId)->Void, inviteContact:@escaping(PeerId)->Void) {
        self.account = account
        self.copyLink = copyLink
        self.inviteGroupMember = inviteGroupMember
        self.inviteContact = inviteContact
    }
}

private struct InvitationState : Equatable {
    var inviteLink: String?
    var groupMembers:[Peer]
    var contacts:[Peer]
    
    static func ==(lhs: InvitationState, rhs: InvitationState) -> Bool {
        if lhs.inviteLink != rhs.inviteLink {
            return false
        }
        if lhs.groupMembers.count != rhs.groupMembers.count {
            return false
        } else {
            for i in 0 ..< lhs.groupMembers.count {
                if !lhs.groupMembers[i].isEqual(rhs.groupMembers[i]) {
                    return false
                }
            }
        }
        if lhs.contacts.count != rhs.contacts.count {
            return false
        } else {
            for i in 0 ..< lhs.contacts.count {
                if !lhs.contacts[i].isEqual(rhs.contacts[i]) {
                    return false
                }
            }
        }
        return true
    }
}

private func invitationEntries(state: InvitationState, arguments: InvitationArguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    return entries
}

func GroupCallInvitation(_ data: GroupCallUIController.UIData) -> InputDataModalController {
    
    let initialState = InvitationState(inviteLink: nil, groupMembers: [], contacts: [])
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((InvitationState) -> InvitationState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = InvitationArguments(account: data.call.account, copyLink: { link in
        
    }, inviteGroupMember: { peerId in
        
    }, inviteContact: { peerId in
        
    })
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: invitationEntries(state: state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Invite Members")
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: L10n.modalSend, accept: { [weak controller] in
        controller?.validateInputValues()
        close?()
    }, height: 50, singleButton: true)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        
        return .none
    }
    
    controller.validateData = { data in
        return .success(.custom({
            close?()
        }))
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}
