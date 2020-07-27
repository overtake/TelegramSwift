//
//  ChannelInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox
import TelegramCore
import SyncCore
import TGUIKit
import SwiftSignalKit


struct ChannelInfoEditingState: Equatable {
    let editingName: String?
    let editingDescriptionText: String
    
    init(editingName:String? = nil, editingDescriptionText:String = "") {
        self.editingName = editingName
        self.editingDescriptionText = editingDescriptionText
    }
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> ChannelInfoEditingState {
        return ChannelInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: ChannelInfoEditingState, rhs: ChannelInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}


class ChannelInfoState: PeerInfoState {
    
    let editingState: ChannelInfoEditingState?
    let savingData: Bool
    let updatingPhotoState:PeerInfoUpdatingPhotoState?
    
    init(editingState: ChannelInfoEditingState?, savingData: Bool, updatingPhotoState: PeerInfoUpdatingPhotoState?) {
        self.editingState = editingState
        self.savingData = savingData
        self.updatingPhotoState = updatingPhotoState
    }
    
    override init() {
        self.editingState = nil
        self.savingData = false
        self.updatingPhotoState = nil
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? ChannelInfoState {
            return self == to
        }
        return false
    }
    
    static func ==(lhs: ChannelInfoState, rhs: ChannelInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        
        return lhs.updatingPhotoState == rhs.updatingPhotoState
        

    }
    
    func withUpdatedEditingState(_ editingState: ChannelInfoEditingState?) -> ChannelInfoState {
        return ChannelInfoState(editingState: editingState, savingData: self.savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: savingData, updatingPhotoState: self.updatingPhotoState)
    }
    
    func withUpdatedUpdatingPhotoState(_ f: (PeerInfoUpdatingPhotoState?) -> PeerInfoUpdatingPhotoState?) -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: f(self.updatingPhotoState))
    }
    func withoutUpdatingPhotoState() -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: self.savingData, updatingPhotoState: nil)
    }
}

private func valuesRequiringUpdate(state: ChannelInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

class ChannelInfoArguments : PeerInfoArguments {
    
    private let reportPeerDisposable = MetaDisposable()
    private let updatePeerNameDisposable = MetaDisposable()
    private let toggleSignaturesDisposable = MetaDisposable()
    private let updatePhotoDisposable = MetaDisposable()
    func updateState(_ f: (ChannelInfoState) -> ChannelInfoState) -> Void {
        updateInfoState { state -> PeerInfoState in
            return f(state as! ChannelInfoState)
        }
    }
    
    override func dismissEdition() {
        updateState { state in
            return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
        }
    }
    
    override func updateEditable(_ editable:Bool, peerView:PeerView, controller: PeerInfoController) -> Bool {
        
        let context = self.context
        let peerId = self.peerId
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        if editable {
            if let peer = peerViewMainPeer(peerView), let cachedData = peerView.cachedData as? CachedChannelData {
                updateState { state -> ChannelInfoState in
                    return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: peer.displayTitle, editingDescriptionText: cachedData.about ?? ""))
                }
            }
        } else {
            var updateValues: (title: String?, description: String?) = (nil, nil)
            updateState { state in
                updateValues = valuesRequiringUpdate(state: state, view: peerView)
                return state
            }
            
            if let titleValue = updateValues.title, titleValue.isEmpty {
                controller.genericView.item(stableId: IntPeerInfoEntryStableId(value: 1).hashValue)?.view?.shakeView()
                return false
            }
            
            updateState { state in
                if updateValues.0 != nil || updateValues.1 != nil {
                    return state.withUpdatedSavingData(true)
                } else {
                    return state.withUpdatedEditingState(nil)
                }
            }
            let updateTitle: Signal<Void, NoError>
            if let titleValue = updateValues.title {
                updateTitle = updatePeerTitle(account: context.account, peerId: peerId, title: titleValue)
                    |> `catch` { _ in return .complete() }
            } else {
                updateTitle = .complete()
            }
            
            let updateDescription: Signal<Void, NoError>
            if let descriptionValue = updateValues.description {
                updateDescription = updatePeerDescription(account: context.account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                    |> `catch` { _ in return .complete() }
            } else {
                updateDescription = .complete()
            }
            
            let signal = combineLatest(updateTitle, updateDescription)
            
            updatePeerNameDisposable.set(showModalProgress(signal: (signal |> deliverOnMainQueue), for: context.window).start(error: { _ in
                updateState { state in
                    return state.withUpdatedSavingData(false)
                }
            }, completed: {
                updateState { state in
                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                }
            }))
        }
        return true
    }
    
    func visibilitySetup() {
        let setup = ChannelVisibilityController(context, peerId: peerId)
        _ = (setup.onComplete.get() |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.pullNavigation()?.back()
        })
        pushViewController(setup)
    }
    
    func setupDiscussion() {
        _ = (self.context.account.postbox.loadedPeerWithId(self.peerId) |> deliverOnMainQueue).start(next: { [weak self] peer in
            if let `self` = self {
                self.pushViewController(ChannelDiscussionSetupController(context: self.context, peer: peer))
            }
        })
    }
    
    func toggleSignatures( _ enabled: Bool) -> Void {
        toggleSignaturesDisposable.set(toggleShouldChannelMessagesSignatures(account: context.account, peerId: peerId, enabled: enabled).start())
    }
    
    func members() -> Void {
        pushViewController(ChannelMembersViewController(context, peerId: peerId))
    }
    
    func admins() -> Void {
        pushViewController(ChannelAdminsViewController(context, peerId: peerId))
    }
    
    func blocked() -> Void {
        pushViewController(ChannelBlacklistViewController(context, peerId: peerId))
    }
    
    func updateChannelPhoto(_ custom: NSImage?) {
        
        let context = self.context
        
        let invoke:(NSImage) -> Void = { image in
            _ = (putToTemp(image: image, compress: true) |> deliverOnMainQueue).start(next: { path in
                let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                showModal(with: controller, for: mainWindow, animationType: .scaleCenter)
                _ = controller.result.start(next: { [weak self] url, _ in
                    self?.updatePhoto(url.path)
                })
                controller.onClose = {
                    removeFile(at: path)
                }
            })
        }
        if let image = custom {
            invoke(image)
        } else {
            filePanel(with: photoExts + videoExts, allowMultiple: false, canChooseDirectories: false, for: context.window, completion: { [weak self] paths in
                if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                    invoke(image)
                } else if let path = paths?.first {
                    selectVideoAvatar(context: context, path: path, localize: L10n.videoAvatarChooseDescChannel, signal: { [weak self] signal in
                        self?.updateVideo(signal)
                    })
                }
            })
        }
    }
    
    func updateVideo(_ signal:Signal<VideoAvatarGeneratorState, NoError>) -> Void {
        
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.set(nil)
            updateState { state -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        
        
        let updateSignal: Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> = signal
            |> mapError { _ in return UploadPeerPhotoError.generic }
            |> mapToSignal { state in
                switch state {
                case .error:
                    return .fail(.generic)
                case let .start(path):
                    updateState { (state) -> ChannelInfoState in
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
                    
                    return updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: thumbResource), video: uploadedPeerVideo(postbox: context.account.postbox, network: context.account.network, messageMediaPreuploadManager: nil, resource: videoResource) |> map(Optional.init), videoStartTimestamp: keyFrame, mapResourceToAvatarSizes: { resource, representations in
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
        
        updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
            updateState { state -> ChannelInfoState in
                switch status {
                case .complete:
                    return state.withoutUpdatingPhotoState()
                case let .progress(progress):
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return previous?.withUpdatedProgress(progress)
                    }
                }
            }
        }, error: { error in
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }, completed: {
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }))
        
        
    }
    
    func updatePhoto(_ path:String) -> Void {
        
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.set(nil)
            updateState { state -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId

        let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
        } |> beforeNext { resource in
            
            updateState { (state) -> ChannelInfoState in
                return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                    return PeerInfoUpdatingPhotoState(progress: 0, image: NSImage(contentsOfFile: path)?.cgImage(forProposedRect: nil, context: nil, hints: nil), cancel: cancel)
                }
            }
            
        } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            return  updatePeerPhoto(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, accountPeerId: context.account.peerId, peerId: peerId, photo: uploadedPeerPhoto(postbox: context.account.postbox, network: context.account.network, resource: resource), mapResourceToAvatarSizes: { resource, representations in
                return mapResourceToAvatarSizes(postbox: context.account.postbox, resource: resource, representations: representations)
            })
        }
                

        updatePhotoDisposable.set((updateSignal |> deliverOnMainQueue).start(next: { status in
            updateState { state -> ChannelInfoState in
                switch status {
                case .complete:
                    return state
                case let .progress(progress):
                    return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                        return previous?.withUpdatedProgress(progress)
                    }
                }
            }
        }, error: { error in
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }, completed: { 
            updateState { (state) -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }))
        

    }
    
    func stats(_ datacenterId: Int32) {
        self.pushViewController(ChannelStatsViewController(context, peerId: peerId, datacenterId: datacenterId))
    }
    func share() {
        let peer = context.account.postbox.peerView(id: peerId) |> take(1) |> deliverOnMainQueue
        let context = self.context
        
        _ = peer.start(next: { peerView in
            if let peer = peerViewMainPeer(peerView) {
                var link: String = "https://t.me/\(peer.id.id)"
                if let address = peer.addressName, !address.isEmpty {
                    link = "https://t.me/\(address)"
                } else if let cachedData = peerView.cachedData as? CachedChannelData, let invitation = cachedData.exportedInvitation {
                    link = invitation.link
                }
                showModal(with: ShareModalController(ShareLinkObject(context, link: link)), for: context.window)
            }
           
        })
        
    }
    
    func report() -> Void {
        let context = self.context
        let peerId = self.peerId
        
        let report = reportReasonSelector(context: context) |> mapToSignal { reason -> Signal<Void, NoError> in
            return showModalProgress(signal: reportPeer(account: context.account, peerId: peerId, reason: reason), for: context.window)
        } |> deliverOnMainQueue
        
        reportPeerDisposable.set(report.start(next: { [weak self] in
            self?.pullNavigation()?.controller.show(toaster: ControllerToaster(text: L10n.peerInfoChannelReported))
        }))
    }
    
    func updateEditingDescriptionText(_ text:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }
    
    func updateEditingName(_ name:String) -> Void {
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: name, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }

    
    deinit {
        reportPeerDisposable.dispose()
        updatePeerNameDisposable.dispose()
        toggleSignaturesDisposable.dispose()
        updatePhotoDisposable.dispose()
    }
}

enum ChannelInfoEntry: PeerInfoEntry {
    case info(sectionId: ChannelInfoSection, peerView: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?, viewType: GeneralViewType)
    case scam(sectionId: ChannelInfoSection, text: String, viewType: GeneralViewType)
    case about(sectionId: ChannelInfoSection, text: String, viewType: GeneralViewType)
    case userName(sectionId: ChannelInfoSection, value: String, viewType: GeneralViewType)
    case setTitle(sectionId: ChannelInfoSection, text: String, viewType: GeneralViewType)
    case admins(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case blocked(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case members(sectionId: ChannelInfoSection, count:Int32?, viewType: GeneralViewType)
    case link(sectionId: ChannelInfoSection, addressName:String, viewType: GeneralViewType)
    case discussion(sectionId: ChannelInfoSection, group: Peer?, participantsCount: Int32?, viewType: GeneralViewType)
    case discussionDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case aboutInput(sectionId: ChannelInfoSection, description:String, viewType: GeneralViewType)
    case aboutDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case signMessages(sectionId: ChannelInfoSection, sign:Bool, viewType: GeneralViewType)
    case signDesc(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case report(sectionId: ChannelInfoSection, viewType: GeneralViewType)
    case leave(sectionId: ChannelInfoSection, isCreator: Bool, viewType: GeneralViewType)
    
    case media(sectionId: ChannelInfoSection, controller: PeerMediaController, isVisible: Bool, viewType: GeneralViewType)
    case section(Int)
    
    func withUpdatedViewType(_ viewType: GeneralViewType) -> ChannelInfoEntry {
        switch self {
        case let .info(sectionId, peerView, editable, updatingPhotoState, _): return .info(sectionId: sectionId, peerView: peerView, editable: editable, updatingPhotoState: updatingPhotoState, viewType: viewType)
        case let .scam(sectionId, text, _): return .scam(sectionId: sectionId, text: text, viewType: viewType)
        case let .about(sectionId, text, _): return .about(sectionId: sectionId, text: text, viewType: viewType)
        case let .userName(sectionId, value, _): return .userName(sectionId: sectionId, value: value, viewType: viewType)
        case let .setTitle(sectionId, text, _): return .setTitle(sectionId: sectionId, text: text, viewType: viewType)
        case let .admins(sectionId, count, _): return .admins(sectionId: sectionId, count: count, viewType: viewType)
        case let .blocked(sectionId, count, _): return .blocked(sectionId: sectionId, count: count, viewType: viewType)
        case let .members(sectionId, count, _): return .members(sectionId: sectionId, count: count, viewType: viewType)
        case let .link(sectionId, addressName, _): return .link(sectionId: sectionId, addressName: addressName, viewType: viewType)
        case let .discussion(sectionId, group, participantsCount, _): return .discussion(sectionId: sectionId, group: group, participantsCount: participantsCount, viewType: viewType)
        case let .discussionDesc(sectionId, _): return .discussionDesc(sectionId: sectionId, viewType: viewType)
        case let .aboutInput(sectionId, description, _): return .aboutInput(sectionId: sectionId, description: description, viewType: viewType)
        case let .aboutDesc(sectionId, _): return .aboutDesc(sectionId: sectionId, viewType: viewType)
        case let .signMessages(sectionId, sign, _): return .signMessages(sectionId: sectionId, sign: sign, viewType: viewType)
        case let .signDesc(sectionId, _): return .signDesc(sectionId: sectionId, viewType: viewType)
        case let .report(sectionId, _): return .report(sectionId: sectionId, viewType: viewType)
        case let .leave(sectionId, isCreator, _): return .leave(sectionId: sectionId, isCreator: isCreator, viewType: viewType)
        case let .media(sectionId, controller, isVisible, _): return .media(sectionId: sectionId, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section: return self
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.stableIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? ChannelInfoEntry else {
            return false
        }
        switch self {
        case let .info(sectionId, lhsPeerView, editable, updatingPhotoState, viewType):
            switch entry {
            case .info(sectionId, let rhsPeerView, editable, updatingPhotoState, viewType):
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                let lhsNotificationSettings = lhsPeerView.notificationSettings
                
                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                let rhsNotificationSettings = rhsPeerView.notificationSettings
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer != nil) != (rhsPeer != nil) {
                    return false
                }
                
                if let lhsNotificationSettings = lhsNotificationSettings, let rhsNotificationSettings = rhsNotificationSettings {
                    if !lhsNotificationSettings.isEqual(to: rhsNotificationSettings) {
                        return false
                    }
                } else if (lhsNotificationSettings == nil) != (rhsNotificationSettings == nil) {
                    return false
                }
                if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                    if !lhsCachedData.isEqual(to: rhsCachedData) {
                        return false
                    }
                } else if (lhsCachedData == nil) != (rhsCachedData != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case  let .scam(sectionId, text, viewType):
            switch entry {
            case .scam(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case  let .about(sectionId, text, viewType):
            switch entry {
            case .about(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .userName(sectionId, value, viewType):
            switch entry {
            case .userName(sectionId, value, viewType):
                return true
            default:
                return false
            }
        case let .setTitle(sectionId, text, viewType):
            switch entry {
            case .setTitle(sectionId, text, viewType):
                return true
            default:
                return false
            }
        case let .report(sectionId, viewType):
            switch entry {
            case .report(sectionId, viewType):
                return true
            default:
                return false
            }
        case let .admins(sectionId, count, viewType):
            if case .admins(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .blocked(sectionId, count, viewType):
            if case .blocked(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .members(sectionId, count, viewType):
            if case .members(sectionId, count, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .link(sectionId, addressName, viewType):
            if case .link(sectionId, addressName, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .discussion(sectionId, lhsGroup, participantsCount, viewType):
            if case .discussion(sectionId, let rhsGroup, participantsCount, viewType) = entry {
                if let lhsGroup = lhsGroup, let rhsGroup = rhsGroup {
                    return lhsGroup.isEqual(rhsGroup)
                } else if (lhsGroup != nil) != (rhsGroup != nil) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .discussionDesc(sectionId, viewType):
            if case .discussionDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .aboutInput(sectionId, text, viewType):
            if case .aboutInput(sectionId, text, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .aboutDesc(sectionId, viewType):
            if case .aboutDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .signMessages(sectionId, sign, viewType):
            if case .signMessages(sectionId, sign, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .signDesc(sectionId, viewType):
            if case .signDesc(sectionId, viewType) = entry {
                return true
            } else {
                return false
            }
        case let .leave(sectionId, isCreator, viewType):
            switch entry {
            case .leave(sectionId, isCreator, viewType):
                return true
            default:
                return false
            }
        case let .section(lhsId):
            switch entry {
            case let .section(rhsId):
                return lhsId == rhsId
            default:
                return false
            }
        case let .media(sectionId, _, isVisible, viewType):
            switch entry {
            case .media(sectionId, _, isVisible, viewType):
                return true
            default:
                return false
            }
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .setTitle:
            return 1
        case .scam:
            return 2
        case .about:
            return 3
        case .userName:
            return 4
        case .admins:
            return 8
        case .members:
            return 9
        case .blocked:
            return 10
        case .link:
            return 11
        case .discussion:
            return 12
        case .discussionDesc:
            return 13
        case .aboutInput:
            return 14
        case .aboutDesc:
            return 15
        case .signMessages:
            return 16
        case .signDesc:
            return 17
        case .report:
            return 18
        case .leave:
            return 19
        case .media:
            return 20
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    fileprivate var sectionId: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return sectionId.rawValue
        case let .setTitle(sectionId, _, _):
            return sectionId.rawValue
        case let .scam(sectionId, _, _):
            return sectionId.rawValue
        case let .about(sectionId, _, _):
            return sectionId.rawValue
        case let .userName(sectionId, _, _):
            return sectionId.rawValue
        case let .admins(sectionId, _, _):
            return sectionId.rawValue
        case let .blocked(sectionId, _, _):
            return sectionId.rawValue
        case let .members(sectionId, _, _):
            return sectionId.rawValue
        case let .link(sectionId, _, _):
            return sectionId.rawValue
        case let .discussion(sectionId, _, _, _):
            return sectionId.rawValue
        case let .discussionDesc(sectionId, _):
            return sectionId.rawValue
        case let .aboutInput(sectionId, _, _):
            return sectionId.rawValue
        case let .aboutDesc(sectionId, _):
            return sectionId.rawValue
        case let .signMessages(sectionId, _, _):
            return sectionId.rawValue
        case let .signDesc(sectionId, _):
            return sectionId.rawValue
        case let .report(sectionId, _):
            return sectionId.rawValue
        case let .leave(sectionId, _, _):
            return sectionId.rawValue
        case let .media(sectionId, _, _, _):
            return sectionId.rawValue
        case let .section(sectionId):
            return sectionId
        }
    }
    
    private var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .setTitle(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .scam(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .about(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .userName(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .admins(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .blocked(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .members(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .link(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .discussion(sectionId, _, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .discussionDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .aboutInput(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .aboutDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .signMessages(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .signDesc(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .report(sectionId, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .leave(sectionId, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .media(sectionId, _, _, _):
            return (sectionId.rawValue * 1000) + stableIndex
        case let .section(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let entry = entry as? ChannelInfoEntry else {
            return false
        }
        return self.sortIndex < entry.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! ChannelInfoArguments
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState, viewType):
            return PeerInfoHeadItem(initialSize, stableId: stableId.hashValue, context: arguments.context, arguments: arguments, peerView:peerView, viewType: viewType, editing: editable, updatingPhotoState: updatingPhotoState, updatePhoto: arguments.updateChannelPhoto)
        case let .scam(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, viewType: viewType, detectLinks:false)
        case let .about(_, text, viewType):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoInfo, text:text, context: arguments.context, viewType: viewType, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .userName(_, value, viewType):
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoSharelink, text: value, context: arguments.context, viewType: viewType, isTextSelectable:false, callback: arguments.share, selectFullWord: true)
        case let .report(_, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoReport, type: .none, viewType: viewType, action: { () in
                arguments.report()
            })
        case let .members(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSubscribers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.members)
        case let .admins(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAdministrators, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.admins)
        case let .blocked(_, count, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoRemovedUsers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), viewType: viewType, action: arguments.blocked)
        case let .link(_, addressName: addressName, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoChannelType, type: .context(addressName.isEmpty ? L10n.channelPrivate : L10n.channelPublic), viewType: viewType, action: arguments.visibilitySetup)
        case let .discussion(_, group, _, viewType):
            let title: String
            if let group = group {
                if let address = group.addressName {
                    title = "@\(address)"
                } else {
                    title = group.displayTitle
                }
            } else {
                title = L10n.peerInfoDiscussionAdd
            }
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDiscussion, type: .nextContext(title), viewType: viewType, action: arguments.setupDiscussion)
        case let .discussionDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoDiscussionDesc, viewType: viewType)
        case let .setTitle(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoChannelTitlePleceholder, filter: { $0 }, updated: arguments.updateEditingName, limit: 255)
        case let .aboutInput(_, text, viewType):
            return InputDataRowItem(initialSize, stableId: stableId.hashValue, mode: .plain, error: nil, viewType: viewType, currentText: text, placeholder: nil, inputPlaceholder: L10n.peerInfoAboutPlaceholder, filter: { $0 }, updated: arguments.updateEditingDescriptionText, limit: 255)
        case let .aboutDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSetAboutDescription, viewType: viewType)
        case let .signMessages(_, sign, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSignMessages, type: .switchable(sign), viewType: viewType, action: {
                arguments.toggleSignatures(!sign)
            })
        case let .signDesc(_, viewType):
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSignMessagesDesc, viewType: viewType)
        case let .leave(_, isCreator, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isCreator ? L10n.peerInfoDeleteChannel : L10n.peerInfoLeaveChannel, nameStyle:redActionButton, type: .none, viewType: viewType, action: arguments.delete)
        case let .media(_, controller, isVisible, viewType):
            return PeerMediaBlockRowItem(initialSize, stableId: stableId.hashValue, controller: controller, isVisible: isVisible, viewType: viewType)
        case .section(_):
            return GeneralRowItem(initialSize, height:30, stableId: stableId.hashValue, viewType: .separator)
        }
    }
}

enum ChannelInfoSection : Int {
    case header = 1
    case desc = 2
    case info = 3
    case type = 4
    case sign = 5
    case manage = 6
    case addition = 7
    case destruct = 8
    case media = 9
}

func channelInfoEntries(view: PeerView, arguments:PeerInfoArguments, mediaTabsData: PeerMediaTabsData) -> [PeerInfoEntry] {
    
    let arguments = arguments as! ChannelInfoArguments
    var state:ChannelInfoState {
        return arguments.state as! ChannelInfoState
    }
    var entries: [ChannelInfoEntry] = []
    
    
    
    var infoBlock:[ChannelInfoEntry] = []
    
    
    func applyBlock(_ block:[ChannelInfoEntry]) {
        var block = block
        for (i, item) in block.enumerated() {
            block[i] = item.withUpdatedViewType(bestGeneralViewType(block, for: i))
        }
        entries.append(contentsOf: block)
    }
    
    infoBlock.append(.info(sectionId: .header, peerView: view, editable: state.editingState != nil, updatingPhotoState: state.updatingPhotoState, viewType: .singleItem))

    
    if let channel = peerViewMainPeer(view) as? TelegramChannel {
        
        if let editingState = state.editingState {
            if channel.hasPermission(.changeInfo) {
                infoBlock.append(.setTitle(sectionId: .header, text: editingState.editingName ?? "", viewType: .singleItem))
            }
            
            if channel.hasPermission(.changeInfo) && !channel.isScam {
                infoBlock.append(.aboutInput(sectionId: .header, description: editingState.editingDescriptionText, viewType: .singleItem))
            }
            applyBlock(infoBlock)
            entries.append(.aboutDesc(sectionId: .header, viewType: .textBottomItem))

            if channel.adminRights?.flags.contains(.canChangeInfo) == true || channel.flags.contains(.isCreator) {
                if channel.flags.contains(.isCreator) {
                    entries.append(.link(sectionId: .type, addressName: channel.username ?? "", viewType: .firstItem))
                }
                let group: Peer?
                if let cachedData = view.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                    group = view.peers[linkedDiscussionPeerId]
                } else {
                    group = nil
                }
                entries.append(.discussion(sectionId: .type, group: group, participantsCount: nil, viewType: channel.flags.contains(.isCreator) ? .lastItem : .singleItem))
                entries.append(.discussionDesc(sectionId: .type, viewType: .textBottomItem))
            }
            
            let messagesShouldHaveSignatures:Bool
            switch channel.info {
            case let .broadcast(info):
                messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
            default:
                messagesShouldHaveSignatures = false
            }
            
            if channel.hasPermission(.changeInfo) {
                entries.append(.signMessages(sectionId: .sign, sign: messagesShouldHaveSignatures, viewType: .singleItem))
                entries.append(.signDesc(sectionId: .sign, viewType: .textBottomItem))
            }
            if channel.flags.contains(.isCreator) {
                entries.append(.leave(sectionId: .destruct, isCreator: channel.flags.contains(.isCreator), viewType: .singleItem))
            }
            
        } else {
            
             applyBlock(infoBlock)
            
            var aboutBlock:[ChannelInfoEntry] = []
            if channel.isScam {
                aboutBlock.append(.scam(sectionId: .desc, text: L10n.channelInfoScamWarning, viewType: .singleItem))
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about, !about.isEmpty, !channel.isScam {
                    aboutBlock.append(.about(sectionId: .desc, text: about, viewType: .singleItem))
                }
            }
            
            if let username = channel.username, !username.isEmpty {
                aboutBlock.append(.userName(sectionId: .desc, value: "https://t.me/\(username)", viewType: .singleItem))
            } else if let cachedData = view.cachedData as? CachedChannelData, let invitation = cachedData.exportedInvitation {
                aboutBlock.append(.userName(sectionId: .desc, value: invitation.link, viewType: .singleItem))
            }
            
            applyBlock(aboutBlock)
            
            
            if channel.flags.contains(.isCreator) || (channel.adminRights != nil && !channel.adminRights!.isEmpty) {
                var membersCount:Int32? = nil
                var adminsCount:Int32? = nil
                var blockedCount:Int32? = nil
                
                if let cachedData = view.cachedData as? CachedChannelData {
                    membersCount = cachedData.participantsSummary.memberCount
                    adminsCount = cachedData.participantsSummary.adminCount
                    blockedCount = cachedData.participantsSummary.kickedCount
                }
                entries.append(.admins(sectionId: .manage, count: adminsCount, viewType: .firstItem))
                entries.append(.members(sectionId: .manage, count: membersCount, viewType: .innerItem))
              
                entries.append(.blocked(sectionId: .manage, count: blockedCount, viewType: .lastItem))
                
            }
        }
    }
    
    if mediaTabsData.loaded && !mediaTabsData.collections.isEmpty, let controller = arguments.mediaController() {
        entries.append(.media(sectionId: ChannelInfoSection.media, controller: controller, isVisible: state.editingState == nil, viewType: .singleItem))
    }
    
    var items:[ChannelInfoEntry] = []
    var sectionId:Int = 0
    for entry in entries {
        if entry.sectionId != sectionId {
            if entry.sectionId == ChannelInfoSection.media.rawValue {
                sectionId = entry.sectionId
            } else {
                items.append(.section(sectionId))
                sectionId = entry.sectionId
            }
        }
        items.append(entry)
    }
    sectionId += 1
    items.append(.section(sectionId))
    
    
   
    
    entries = items
    
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
