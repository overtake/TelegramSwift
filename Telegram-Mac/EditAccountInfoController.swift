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
    let context: AccountContext
    let uploadNewPhoto:()->Void
    let logout:()->Void
    let username:()->Void
    let changeNumber:()->Void
    let addAccount: ()->Void
    init(context: AccountContext, uploadNewPhoto:@escaping()->Void, logout:@escaping()->Void, username: @escaping()->Void, changeNumber:@escaping()->Void, addAccount: @escaping() -> Void) {
        self.context = context
        self.logout = logout
        self.username = username
        self.changeNumber = changeNumber
        self.uploadNewPhoto = uploadNewPhoto
        self.addAccount = addAccount
    }
}
struct EditInfoState : Equatable {
    static func == (lhs: EditInfoState, rhs: EditInfoState) -> Bool {
        
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer != nil) != (rhs.peer != nil) {
            return false
        }
        
        return lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName && lhs.username == rhs.username && lhs.phone == rhs.phone && lhs.representation == rhs.representation && lhs.updatingPhotoState == rhs.updatingPhotoState && lhs.stateInited == rhs.stateInited && lhs.peerStatusSettings == rhs.peerStatusSettings
    }
    
    let firstName: String
    let lastName: String
    let about: String
    let username: String?
    let phone: String?
    let representation:TelegramMediaImageRepresentation?
    let updatingPhotoState: PeerInfoUpdatingPhotoState?
    let stateInited: Bool
    let peer: Peer?
    let peerStatusSettings: PeerStatusSettings?
    let addToException: Bool
    init(stateInited: Bool = false, firstName: String = "", lastName: String = "", about: String = "", username: String? = nil, phone: String? = nil, representation: TelegramMediaImageRepresentation? = nil, updatingPhotoState: PeerInfoUpdatingPhotoState? = nil, peer: Peer? = nil, peerStatusSettings: PeerStatusSettings? = nil, addToException: Bool = true) {
        self.firstName = firstName
        self.lastName = lastName
        self.about = about
        self.username = username
        self.phone = phone
        self.representation = representation
        self.updatingPhotoState = updatingPhotoState
        self.stateInited = stateInited
        self.peer = peer
        self.peerStatusSettings = peerStatusSettings
        self.addToException = addToException
    }
    
    init(_ peerView: PeerView) {
        let peer = peerView.peers[peerView.peerId] as? TelegramUser
        self.peer = peer
        self.firstName = peer?.firstName ?? ""
        self.lastName = peer?.lastName ?? ""
        self.username = peer?.username
        self.phone = peer?.phone
        self.about = (peerView.cachedData as? CachedUserData)?.about ?? ""
        self.representation = peer?.smallProfileImage
        self.updatingPhotoState = nil
        self.stateInited = true
        self.peerStatusSettings = (peerView.cachedData as? CachedUserData)?.peerStatusSettings
        self.addToException = true
    }
    
    func withUpdatedInited(_ stateInited: Bool) -> EditInfoState {
        return EditInfoState(stateInited: stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState, peer: self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    func withUpdatedAbout(_ about: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState, peer: self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    
    
    func withUpdatedFirstName(_ firstName: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState, peer: self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    func withUpdatedLastName(_ lastName: String) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState, peer: self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    
    func withUpdatedPeerView(_ peerView: PeerView) -> EditInfoState {
        let peer = peerView.peers[peerView.peerId] as? TelegramUser
        let about = stateInited ? self.about : (peerView.cachedData as? CachedUserData)?.about ?? self.about
        let peerStatusSettings = (peerView.cachedData as? CachedUserData)?.peerStatusSettings
        return EditInfoState(stateInited: true, firstName: stateInited ? self.firstName : peer?.firstName ?? self.firstName, lastName: stateInited ? self.lastName : peer?.lastName ?? self.lastName, about: about, username: peer?.username, phone: peer?.phone, representation: peer?.smallProfileImage, updatingPhotoState: self.updatingPhotoState, peer: peer, peerStatusSettings: peerStatusSettings, addToException: self.addToException)
    }
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: f(self.updatingPhotoState), peer: self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    func withoutUpdatingPhotoState() -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: nil, peer:self.peer, peerStatusSettings: self.peerStatusSettings, addToException: self.addToException)
    }
    
    func withUpdatedAddToException(_ addToException: Bool) -> EditInfoState {
        return EditInfoState(stateInited: self.stateInited, firstName: self.firstName, lastName: self.lastName, about: self.about, username: self.username, phone: self.phone, representation: self.representation, updatingPhotoState: self.updatingPhotoState, peer:self.peer, peerStatusSettings: self.peerStatusSettings, addToException: addToException)
    }
}

private let _id_info = InputDataIdentifier("_id_info")
private let _id_about = InputDataIdentifier("_id_about")
private let _id_username = InputDataIdentifier("_id_username")
private let _id_phone = InputDataIdentifier("_id_phone")
private let _id_logout = InputDataIdentifier("_id_logout")
private let _id_add_account = InputDataIdentifier("_id_add_account")

private func editInfoEntries(state: EditInfoState, arguments: EditInfoControllerArguments, activeAccounts: [AccountWithInfo], updateState:@escaping ((EditInfoState)->EditInfoState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info, equatable: InputDataEquatable(state), item: { size, stableId -> TableRowItem in
        return EditAccountInfoItem(size, stableId: stableId, account: arguments.context.account, state: state, viewType: .singleItem, updateText: { firstName, lastName in
            updateState { current in
                return current.withUpdatedFirstName(firstName).withUpdatedLastName(lastName).withUpdatedInited(true)
            }
        }, uploadNewPhoto: {
            arguments.uploadNewPhoto()
        })
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.editAccountNameDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.bioHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1

    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.about), error: nil, identifier: _id_about, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: L10n.bioPlaceholder, filter: {$0}, limit: 70))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.bioDescription), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_username, data: InputDataGeneralData(name: L10n.editAccountUsername, color: theme.colors.text, icon: nil, type: .nextContext(state.username != nil ? "@\(state.username!)" : ""), viewType: .firstItem, action: nil)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_phone, data: InputDataGeneralData(name: L10n.editAccountChangeNumber, color: theme.colors.text, icon: nil, type: .nextContext(state.phone != nil ? formatPhoneNumber(state.phone!) : ""), viewType: .lastItem, action: nil)))
    index += 1

    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if activeAccounts.count < 3 {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_account, data: InputDataGeneralData(name: L10n.editAccountAddAccount, color: theme.colors.accent, icon: nil, type: .none, viewType: .firstItem, action: {
            arguments.addAccount()
        })))
        index += 1
    }
   
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_logout, data: InputDataGeneralData(name: L10n.editAccountLogout, color: theme.colors.redUI, icon: nil, type: .none, viewType: activeAccounts.count < 3 ? .lastItem : .singleItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func EditAccountInfoController(context: AccountContext, f: @escaping((ViewController)) -> Void) -> Void {
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
    
    peerDisposable.set((context.account.postbox.peerView(id: context.peerId) |> deliverOnMainQueue).start(next: { pv in
        peerView = pv
        updateState { current in
            return current.withUpdatedPeerView(pv)
        }
    }))
    
    
    let arguments = EditInfoControllerArguments(context: context, uploadNewPhoto: {
        
        filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: mainWindow, completion: { paths in
            if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                
                let cancel = {
                    photoDisposable.dispose()
                    updateState { state -> EditInfoState in
                        return state.withoutUpdatingPhotoState()
                    }
                }
                
                _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                    let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                    showModal(with: controller, for: mainWindow)
                    
                    let updateSignal = controller.result |> map { path, _ -> TelegramMediaResource in
                        return LocalFileReferenceMediaResource(localFilePath: path.path, randomId: arc4random64())
                        } |> beforeNext { resource in
                            updateState { state -> EditInfoState in
                                return state.withUpdatedUpdatingPhotoState { _ in
                                    return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                                }
                            }
                        } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                            return updateAccountPhoto(account: context.account, resource: resource, mapResourceToAvatarSizes: { resource, representations in
                                return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                            })
                        } |> deliverOnMainQueue
                    
                    photoDisposable.set(updateSignal.start(next: { status in
                        updateState { state -> EditInfoState in
                            switch status {
                            case .complete:
                                return state.withoutUpdatingPhotoState()
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
                    

                    
                    controller.onClose = {
                        removeFile(at: path)
                    }
                })
            }
        })
        
    }, logout: {
        showModal(with: LogoutViewController(context: context, f: f), for: context.window)
    }, username: {
        f(UsernameSettingsViewController(context))
    }, changeNumber: {
        f(PhoneNumberIntroController(context))
    }, addAccount: {
        let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
    })
    
    f(InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, context.sharedContext.activeAccountsWithInfo) |> map {editInfoEntries(state: $0.0, arguments: arguments, activeAccounts: $0.2.accounts, updateState: updateState)} |> map { InputDataSignalValue(entries: $0) }, title: L10n.navigationEdit, validateData: { data -> InputDataValidation in
        
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
            let current = stateValue.modify {$0}
            if current.firstName.isEmpty {
                f(.fail(.fields([_id_info : .shake])))
            }
            var signals:[Signal<Void, NoError>] = []
            if let peerView = peerView {
                let updates = valuesRequiringUpdate(state: current, view: peerView)
                if let names = updates.0 {
                    signals.append(updateAccountPeerName(account: context.account, firstName: names.fn, lastName: names.ln))
                }
                if let about = updates.1 {
                    signals.append(updateAbout(account: context.account, about: about) |> `catch` { _ in .complete()})
                }
                updateNameDisposable.set(showModalProgress(signal: combineLatest(signals) |> deliverOnMainQueue, for: mainWindow).start(completed: {
                    updateState { $0 }
                }))
            }
        })
    }, updateDatas: { data in
        updateState { current in
            return current.withUpdatedAbout(data[_id_about]?.stringValue ?? "")
        }
        return .fail(.none)
    }, afterDisappear: {
        actionsDisposable.dispose()
    }, updateDoneValue: { data in
        return { f in
            let current = stateValue.modify {$0}
            if let peerView = peerView {
                let updates = valuesRequiringUpdate(state: current, view: peerView)
                f((updates.0 != nil || updates.1 != nil) ? .enabled(L10n.navigationDone) : .disabled(L10n.navigationDone))
            } else {
                f(.disabled(L10n.navigationDone))
            }
        }
    }, removeAfterDisappear: false, identifier: "account"))
}
