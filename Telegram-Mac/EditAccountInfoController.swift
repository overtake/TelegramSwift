//
//  EditAccountInfoController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 26/04/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import Postbox
import SwiftSignalKit


enum EditSettingsEntryTag: ItemListItemTag {
    case bio
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? EditSettingsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
    var stableId: InputDataEntryId {
        switch self {
        case .bio:
            return .input(_id_about)
        }
    }
}


private func valuesRequiringUpdate(state: EditInfoState, view: PeerView) -> ((fn: String, ln: String)?, about: String?) {
    if let peer = view.peers[view.peerId] as? TelegramUser {
        var names:(String, String)? = nil
        let pf = peer.firstName ?? ""
        let pl = peer.lastName ?? ""

        if state.firstName != pf || state.lastName != pl {
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
    let uploadNewPhoto:(Control)->Void
    let logout:()->Void
    let username:()->Void
    let changeNumber:()->Void
    let addAccount: ()->Void
    let userNameColor: ()->Void
    init(context: AccountContext, uploadNewPhoto:@escaping(Control)->Void, logout:@escaping()->Void, username: @escaping()->Void, changeNumber:@escaping()->Void, addAccount: @escaping() -> Void, userNameColor: @escaping()->Void) {
        self.context = context
        self.logout = logout
        self.username = username
        self.changeNumber = changeNumber
        self.uploadNewPhoto = uploadNewPhoto
        self.addAccount = addAccount
        self.userNameColor = userNameColor
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
        self.username = peer?.usernames.first(where: { $0.isActive })?.username
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
        let username = peer?.usernames.first(where: { $0.isActive })?.username
        let peerStatusSettings = (peerView.cachedData as? CachedUserData)?.peerStatusSettings
        return EditInfoState(stateInited: true, firstName: stateInited ? self.firstName : peer?.firstName ?? self.firstName, lastName: stateInited ? self.lastName : peer?.lastName ?? self.lastName, about: about, username: username, phone: peer?.phone, representation: peer?.smallProfileImage, updatingPhotoState: self.updatingPhotoState, peer: peer, peerStatusSettings: peerStatusSettings, addToException: self.addToException)
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
private let _id_name_color = InputDataIdentifier("_id_name_color")

private func editInfoEntries(state: EditInfoState, arguments: EditInfoControllerArguments, activeAccounts: [AccountWithInfo], updateState:@escaping ((EditInfoState)->EditInfoState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_info, equatable: InputDataEquatable(state), comparable: nil, item: { size, stableId -> TableRowItem in
        return EditAccountInfoItem(size, stableId: stableId, account: arguments.context.account, state: state, viewType: .singleItem, updateText: { firstName, lastName in
            updateState { current in
                return current.withUpdatedFirstName(firstName).withUpdatedLastName(lastName).withUpdatedInited(true)
            }
        }, uploadNewPhoto: { control in
            arguments.uploadNewPhoto(control)
        })
    }))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().editAccountNameDesc), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1

    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().bioHeader), data: InputDataGeneralTextData(viewType: .textTopItem)))
    index += 1

    
    let limit = arguments.context.isPremium ? arguments.context.premiumLimits.about_length_limit_premium : arguments.context.premiumLimits.about_length_limit_default
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.about), error: nil, identifier: _id_about, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: strings().bioPlaceholder, filter: {$0}, limit: Int32(limit)))
    index += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().bioDescription), data: InputDataGeneralTextData(viewType: .textBottomItem)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    let username: String
    if let name = state.username {
        username = "@\(name)"
    } else if let name = state.peer?.username {
        username = "@\(name)"
    } else {
        username = ""
    }
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_username, data: InputDataGeneralData(name: strings().editAccountUsername, color: theme.colors.text, icon: nil, type: .nextContext(username), viewType: .firstItem, action: nil)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_phone, data: InputDataGeneralData(name: strings().editAccountChangeNumber, color: theme.colors.text, icon: nil, type: .nextContext(state.phone != nil ? formatPhoneNumber(state.phone!) : ""), viewType: .innerItem, action: nil)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_name_color, data: InputDataGeneralData(name: strings().appearanceYourNameColor, color: theme.colors.text, type: .imageContext(generateSettingsMenuPeerColorsLabelIcon(peer: state.peer, context: arguments.context), ""), viewType: .lastItem, action: arguments.userNameColor)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    if activeAccounts.count < 3 {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_add_account, data: InputDataGeneralData(name: strings().editAccountAddAccount, color: theme.colors.accent, icon: nil, type: .none, viewType: .firstItem, action: {
            arguments.addAccount()
        })))
        index += 1
    }
   
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_logout, data: InputDataGeneralData(name: strings().editAccountLogout, color: theme.colors.redUI, icon: nil, type: .none, viewType: activeAccounts.count < 3 ? .lastItem : .singleItem, action: nil)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}


func EditAccountInfoController(context: AccountContext, focusOnItemTag: EditSettingsEntryTag? = nil, f: @escaping((ViewController)) -> Void) -> Void {
    
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
    
    let peerId = context.peerId
    
    
    
    let cancel = {
        photoDisposable.set(nil)
        updateState { state -> EditInfoState in
            return state.withoutUpdatingPhotoState()
        }
    }

    var close:(()->Void)? = nil
    
    let updatePhoto:(Signal<NSImage, NoError>)->Void = { image in
        let signal = image |> mapToSignal {
            putToTemp(image: $0, compress: true)
        } |> deliverOnMainQueue
        _ = signal.start(next: { path in
            let controller = EditImageModalController(URL(fileURLWithPath: path), context: context, settings: .disableSizes(dimensions: .square))
            showModal(with: controller, for: context.window, animationType: .scaleCenter)
            
            let updateSignal = controller.result |> map { path, _ -> TelegramMediaResource in
                return LocalFileReferenceMediaResource(localFilePath: path.path, randomId: arc4random64())
                } |> beforeNext { resource in
                    updateState { state -> EditInfoState in
                        return state.withUpdatedUpdatingPhotoState { _ in
                            return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                        }
                    }
                } |> castError(UploadPeerPhotoError.self) |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
                    return context.engine.accountData.updateAccountPhoto(resource: resource, videoResource: nil, videoStartTimestamp: nil, markup: nil, mapResourceToAvatarSizes: { resource, representations in
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
        })
    }
    
    
        
    let updateVideo:(Signal<VideoAvatarGeneratorState, NoError>) -> Void = { signal in
                        
        let updateSignal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> = signal
        |> castError(UploadPeerPhotoError.self)
        |> mapToSignal { state in
            switch state {
            case .error:
                return .fail(.generic)
            case let .start(path):
                updateState { (state) -> EditInfoState in
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?._cgImage, cancel: cancel)
                    }
                }
                return .next(.progress(0))
            case let .progress(value):
                return .next(.progress(value * 0.2))
            case let .complete(thumb, video, keyFrame):
                let (thumbResource, videoResource) = (LocalFileReferenceMediaResource(localFilePath: thumb, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true),
                                                      LocalFileReferenceMediaResource(localFilePath: video, randomId: arc4random64(), isUniquelyReferencedTemporaryFile: true))
                return context.engine.peers.updatePeerPhoto(peerId: peerId, photo: context.engine.peers.uploadedPeerPhoto(resource: thumbResource), video: context.engine.peers.uploadedPeerVideo(resource: videoResource) |> map(Optional.init), videoStartTimestamp: keyFrame, mapResourceToAvatarSizes: { resource, representations in
                    return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
                }) |> map { result in
                    switch result {
                    case let .progress(current):
                        return .progress(0.2 + (current * 0.8))
                    default:
                        return result
                    }
                }
            }
        }
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
    }
    
    let makeVideo:(MediaObjectToAvatar)->Void = { object in
        
        
        switch object.object.foreground.type {
        case .emoji, .sticker:
            updatePhoto(object.start() |> mapToSignal { value in
                if let result = value.result {
                    switch result {
                    case let .image(image):
                        return .single(image)
                    default:
                        return .never()
                    }
                } else {
                    return .never()
                }
            })
        default:
            let signal:Signal<VideoAvatarGeneratorState, NoError> = object.start() |> map { value in
                if let result = value.result {
                    switch result {
                    case let .video(path, thumb):
                        return .complete(thumb: thumb, video: path, keyFrame: nil)
                    default:
                        return .error
                    }
                } else if let status = value.status {
                    switch status {
                    case let .initializing(thumb):
                        return .start(thumb: thumb)
                    case let .converting(progress):
                        return .progress(progress)
                    default:
                        return .error
                    }
                } else {
                    return .error
                }
            }
            updateVideo(signal)
        }
    }
    
    let arguments = EditInfoControllerArguments(context: context, uploadNewPhoto: { control in
        
        var items:[ContextMenuItem] = []
        
        items.append(.init(strings().editAvatarPhotoOrVideo, handler: {
            filePanel(with: photoExts + videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { paths in
                if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                    updatePhoto(.single(image))
                } else if let path = paths?.first {
                    selectVideoAvatar(context: context, path: path, localize: strings().videoAvatarChooseDescProfile, signal: { signal in
                        updateVideo(signal)
                    })
                }
            })
        }, itemImage: MenuAnimation.menu_shared_media.value))
        
        items.append(.init(strings().editAvatarCustomize, handler: {
            showModal(with: AvatarConstructorController(context, target: .avatar, videoSignal: makeVideo), for: context.window)
        }, itemImage: MenuAnimation.menu_view_sticker_set.value))
        
        if let event = NSApp.currentEvent {
            let menu = ContextMenu()
            for item in items {
                menu.addItem(item)
            }
            let value = AppMenu(menu: menu)
            value.show(event: event, view: control)
        }       
    }, logout: {
        showModal(with: LogoutViewController(context: context, f: f), for: context.window)
    }, username: {
        f(UsernameController(context))
    }, changeNumber: {
        let navigation = MajorNavigationController(PhoneNumberIntroController.self, PhoneNumberIntroController(context), context.window)
        navigation.alwaysAnimate = true
        navigation._frameRect = NSMakeRect(0, 0, 350, 400)
        navigation.readyOnce()
        showModal(with: navigation, for: context.window)
    }, addAccount: {
        let testingEnvironment = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        context.sharedContext.beginNewAuth(testingEnvironment: testingEnvironment)
    }, userNameColor: {
        context.bindings.rootNavigation().push(SelectColorController(context: context, source: .account(stateValue.with { $0.peer! })))
    })
    
    let controller = InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue, context.sharedContext.activeAccountsWithInfo) |> map {editInfoEntries(state: $0.0, arguments: arguments, activeAccounts: $0.2.accounts, updateState: updateState)} |> map { InputDataSignalValue(entries: $0) }, title: strings().editAccountTitle, validateData: { data -> InputDataValidation in
        
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
        
        if let about = data[_id_about]?.stringValue {
            if context.isPremium {
                
            } else {
                if about.length > context.premiumLimits.about_length_limit_default {
                    showPremiumLimit(context: context, type: .caption(about.length))
                }
            }
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
                    
                    signals.append(context.engine.accountData.updateAccountPeerName(firstName: names.fn, lastName: names.ln))
                }
                if let about = updates.1 {
                    signals.append(context.engine.accountData.updateAbout(about: about) |> `catch` { _ in .complete()})
                }
                updateNameDisposable.set(showModalProgress(signal: combineLatest(signals) |> deliverOnMainQueue, for: context.window).start(completed: {
                    updateState { $0 }
                    close?()
                    _ = showModalSuccess(for: context.window, icon: theme.icons.successModalProgress, delay: 1.5).start()
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
                f((updates.0 != nil || updates.1 != nil) ? .enabled(strings().navigationDone) : .disabled(strings().navigationDone))
            } else {
                f(.disabled(strings().navigationDone))
            }
        }
    }, removeAfterDisappear: false, identifier: "account")
    
    controller.didLoad = { controller, _ in
        if let focusOnItemTag = focusOnItemTag {
            controller.genericView.tableView.scroll(to: .center(id: focusOnItemTag.stableId, innerId: nil, animated: true, focus: .init(focus: true), inset: 0), inset: NSEdgeInsets())
        }
    }
    
    controller.inputLimitReached = { limit in
        if !context.isPremium {
            showPremiumLimit(context: context, type: .about(context.premiumLimits.about_length_limit_default + limit))
        }
    }
    
    close = { [weak controller] in
        controller?.navigationController?.back()
    }
    
    controller.onDeinit = {
       // cancel()
    }
    
    f(controller)
}
