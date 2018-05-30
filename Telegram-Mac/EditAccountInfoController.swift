//
//  EditAccountInfoController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private func valuesRequiringUpdate(state: EditInfoState, view: PeerView) -> ((fn: String, ln: String)?, about: String?) {
    if let peer = view.peers[view.peerId] as? TelegramUser {
        var names:(String, String)? = nil
        if state.firstName != peer.firstName || state.lastName != peer.lastName {
            names = (state.firstName, state.lastName)
        }
        var about: String? = nil
        
        if let cachedData = view.cachedData as? CachedUserData {
            if state.about != (cachedData.about ?? "") {
                about = state.about
            }
        }
        
        return (names, about)
    }
    return (nil, nil)
}

private final class EditInfoControllerArguments {
    let account: Account
    let uploadNewPhoto:()->Void
    let logout:()->Void
    let username:()->Void
    let changeNumber:()->Void
    init(account: Account, uploadNewPhoto:@escaping()->Void, logout:@escaping()->Void, username: @escaping()->Void, changeNumber:@escaping()->Void) {
        self.account = account
        self.logout = logout
        self.username = username
        self.changeNumber = changeNumber
        self.uploadNewPhoto = uploadNewPhoto
    }
}
struct EditInfoState : Equatable {
    let firstName: String
    let lastName: String
    let about: String
    let username: String?
    let phone: String?
    let representation:TelegramMediaImageRepresentation?
    let updatingPhotoState: PeerInfoUpdatingPhotoState?
    let stateInited: Bool
    init(stateInited: Bool = false, firstName: String = "", lastName: String = "", about: String = "", username: String? = nil, phone: String? = nil, representation: TelegramMediaImageRepresentation? = nil, updatingPhotoState: PeerInfoUpdatingPhotoState? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.about = about
        self.username = username
        self.phone = phone
        self.representation = representation
        self.updatingPhotoState = updatingPhotoState
        self.stateInited = stateInited
    }
    
    init(_ peerView: PeerView) {
        let peer = peerView.peers[peerView.peerId] as? TelegramUser
        self.firstName = peer?.firstName ?? ""
        self.lastName = peer?.lastName ?? ""
        self.username = peer?.username
        self.phone = peer?.phone
        self.about = (peerView.cachedData as? CachedUserData)?.about ?? ""
        self.representation = peer?.smallProfileImage
        self.updatingPhotoState = nil
        self.stateInited = true
    }
    
    func withUpdatedInited(_ stateInited: Bool) -> EditInfoState {
        return EditInfoState(stateInited: stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState)
    }
    func withUpdatedAbout(_ about: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState)
    }
    
    
    func withUpdatedFirstName(_ firstName: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState)
    }
    func withUpdatedLastName(_ lastName: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedPeerView(_ peerView: PeerView) -> EditInfoState {
        let peer = peerView.peers[peerView.peerId] as? TelegramUser
        let about = stateInited ? self.about : (peerView.cachedData as? CachedUserData)?.about ?? self.about
        
        return EditInfoState(stateInited: self.stateInited, firstName: stateInited ? self.firstName : peer?.firstName ?? self.firstName, lastName: stateInited ? self.lastName : peer?.lastName ?? self.lastName, about: about, username: peer?.username, phone: peer?.phone, representation: peer?.smallProfileImage, updatingPhotoState: self.updatingPhotoState)
    }
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: f(self.updatingPhotoState))
    }
    func withoutUpdatingPhotoState() -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: nil)
    }
}

private let _id_info = InputDataIdentifier("_id_info")
private let _id_about = InputDataIdentifier("_id_about")
private let _id_username = InputDataIdentifier("_id_username")
private let _id_phone = InputDataIdentifier("_id_phone")
private let _id_logout = InputDataIdentifier("_id_logout")

private func editInfoEntries(state: EditInfoState, arguments: EditInfoControllerArguments, updateState:@escaping ((EditInfoState)->EditInfoState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info, equatable: InputDataEquatable(state), item: { size, stableId -> TableRowItem in
        return EditAccountInfoItem(size, stableId: stableId, account: arguments.account, state: state, updateText: { firstName, lastName in
            updateState { current in
                return current.withUpdatedFirstName(firstName).withUpdatedLastName(lastName).withUpdatedInited(true)
            }
        }, uploadNewPhoto: {
            arguments.uploadNewPhoto()
        })
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.editAccountNameDesc, color: theme.colors.grayText, detectBold: true))
    index += 1

    
    entries.append(InputDataEntry.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.about), error: nil, identifier: _id_about, mode: .plain, placeholder: L10n.telegramBioViewController, inputPlaceholder: L10n.bioPlaceholder, filter: {$0}, limit: 70))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: L10n.bioDescription, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(InputDataEntry.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_username, name: L10n.editAccountUsername, color: theme.colors.text, icon: nil, type: .nextContext(state.username != nil ? "@\(state.username!)" : "")))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_phone, name: L10n.editAccountChangeNumber, color: theme.colors.text, icon: nil, type: .nextContext(state.phone != nil ? formatPhoneNumber(state.phone!) : "")))
    index += 1

    entries.append(InputDataEntry.sectionId(sectionId))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_logout, name: L10n.editAccountLogout, color: theme.colors.redUI, icon: nil, type: .none))
    index += 1
    
    return entries
}


func editAccountInfoController(account: Account, accountManager: AccountManager, f: @escaping((ViewController)) -> Void) -> Void {
    let state: Promise<EditInfoState> = Promise()
    let stateValue: Atomic<EditInfoState> = Atomic(value: EditInfoState())
    let actionsDisposable = DisposableSet()
    let photoDisposable = MetaDisposable()
    let peerDisposable = MetaDisposable()
    let logoutDisposable = MetaDisposable()
    let updateNameDisposable = MetaDisposable()
    
    actionsDisposable.add(photoDisposable)
    actionsDisposable.add(peerDisposable)
    actionsDisposable.add(logoutDisposable)
    actionsDisposable.add(updateNameDisposable)
    let updateState:((EditInfoState)->EditInfoState)->Void = { f in
        state.set(.single(stateValue.modify(f)))
    }
    
    var peerView:PeerView? = nil
    
    peerDisposable.set((account.postbox.peerView(id: account.peerId) |> deliverOnMainQueue).start(next: { pv in
        peerView = pv
        updateState { current in
            return current.withUpdatedPeerView(pv)
        }
    }))
    
    
    let arguments = EditInfoControllerArguments(account: account, uploadNewPhoto: {
        pickImage(for: mainWindow, completion:{ image in
            if let image = image {
                
                let cancel = {
                    photoDisposable.dispose()
                    updateState { state -> EditInfoState in
                        return state.withoutUpdatingPhotoState()
                    }
                }
                
                let updateSignal = putToTemp(image: image) |> map { path -> TelegramMediaResource in
                    return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
                    } |> beforeNext { resource in
                        updateState { state -> EditInfoState in
                            return state.withUpdatedUpdatingPhotoState { _ in
                                return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                            }
                        }
                    } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                        return  updatePeerPhoto(account: account, peerId: account.peerId, resource: resource)
                    } |> deliverOnMainQueue
                
                photoDisposable.set(updateSignal.start(next: { status in
                    updateState { state -> EditInfoState in
                        switch status {
                        case .complete:
                            return state
                        case let .progress(progress):
                            return state.withUpdatedUpdatingPhotoState { current -> PeerInfoUpdatingPhotoState? in
                                return current?.withUpdatedProgress(progress)
                            }
                        }
                    }
                }, error: { error in
                    updateState { state in
                        return state.withoutUpdatingPhotoState()
                    }
                }, completed: {
                    updateState { state -> EditInfoState in
                        return state.withoutUpdatingPhotoState()
                    }
                }))
                
            }
        })
    }, logout: {
        confirm(for: mainWindow, header: L10n.accountConfirmLogout, information: L10n.accountConfirmLogoutText, successHandler: { _ in
            logoutDisposable.set(logoutFromAccount(id: account.id, accountManager: accountManager).start())
        })
    }, username: {
        f(UsernameSettingsViewController(account))
    }, changeNumber: {
        f(PhoneNumberIntroController(account))
    })
    
    f(InputDataController(dataSignal: state.get() |> map {editInfoEntries(state: $0, arguments: arguments, updateState: updateState)} |> distinctUntilChanged, title: L10n.navigationEdit, validateData: { data -> InputDataValidation in
        
        if let _ = data[_id_logout] {
            arguments.logout()
            return .fail(.none)
        }
        if let _ = data[_id_username] {
            arguments.username()
            return .fail(.none)
        }
        if let _ = data[_id_phone] {
            arguments.changeNumber()
            return .fail(.none)
        }
        
        return .fail(.doSomething { f in
            updateState { current in
                if current.firstName.isEmpty {
                    f(.fail(.fields([_id_info : .shake])))
                    return current
                }
                var signals:[Signal<Void, Void>] = []
                if let peerView = peerView {
                    let updates = valuesRequiringUpdate(state: current, view: peerView)
                    if let names = updates.0 {
                        signals.append(updateAccountPeerName(account: account, firstName: names.fn, lastName: names.ln))
                    }
                    if let about = updates.1 {
                        signals.append(updateAbout(account: account, about: about) |> mapError {_ in})
                    }
                    updateNameDisposable.set(showModalProgress(signal: combineLatest(signals) |> deliverOnMainQueue, for: mainWindow).start())
                }
                return current
            }
        })
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedAbout(data[_id_about]?.stringValue ?? "")
        }
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, updateDoneEnabled: { data in
        return { f in
            updateState { current in
                if let peerView = peerView {
                    let updates = valuesRequiringUpdate(state: current, view: peerView)
                    f(updates.0 != nil || updates.1 != nil)
                } else {
                    f(false)
                }
                return current
            }
        }
    }, removeAfterDisappear: false, identifier: "account"))
}
