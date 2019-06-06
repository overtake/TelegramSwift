//
//  ChannelInfoEntries.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac


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
    
    override func updateEditable(_ editable: Bool, peerView: PeerView) {
        
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
    
    func updatePhoto(_ path:String) -> Void {
        
        let updateState:((ChannelInfoState)->ChannelInfoState)->Void = { [weak self] f in
            self?.updateState(f)
        }
        
        let cancel = { [weak self] in
            self?.updatePhotoDisposable.dispose()
            updateState { state -> ChannelInfoState in
                return state.withoutUpdatingPhotoState()
            }
        }
        
        let context = self.context
        let peerId = self.peerId
        /*
         filethumb(with: URL(fileURLWithPath: path), account: account, scale: System.backingScale) |> mapToSignal { res -> Signal<String, NoError> in
         guard let image = NSImage(contentsOf: URL(fileURLWithPath: path)) else {
         return .complete()
         }
         let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: image.size, boundingSize: NSMakeSize(640, 640), intrinsicInsets: NSEdgeInsets())
         if let image = res(arguments)?.generateImage() {
         return putToTemp(image: NSImage(cgImage: image, size: image.backingSize))
         }
         return .complete()
         }
 */
        let updateSignal = Signal<String, NoError>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
        } |> beforeNext { resource in
            
            updateState { (state) -> ChannelInfoState in
                return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                    return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
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
    
    func stats() {
//        _ = showModalProgress(signal: getChannelStats(postbox: context.account.postbox, network: context.account.network, peerId) |> deliverOnMainQueue, for: arguments.context.window).start(next: { [weak self] url in
//            guard let `self` = self, let url = url else {return}
//            self.pushViewController(ChannelStatisticsController(self.context, self.peerId, statsUrl: url))
//        })
    }
    
    func report() -> Void {
        let context = self.context
        let peerId = self.peerId
        
        let report = reportReasonSelector() |> mapToSignal { reason -> Signal<Void, NoError> in
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
    case info(sectionId:Int, peerView: PeerView, editable:Bool, updatingPhotoState:PeerInfoUpdatingPhotoState?)
    case scam(sectionId:Int, text: String)
    case about(sectionId:Int, text: String)
    case userName(sectionId:Int, value: String)
    case setPhoto(sectionId:Int)
    case sharedMedia(sectionId:Int)
    case notifications(sectionId:Int, settings: PeerNotificationSettings?)
    case admins(sectionId:Int, count:Int32?)
    case blocked(sectionId:Int, count:Int32?)
    case members(sectionId:Int, count:Int32?)
    case statistics(sectionId:Int)
    case link(sectionId:Int, addressName:String)
    case discussion(sectionId:Int, group: Peer?, participantsCount: Int32?)
    case discussionDesc(sectionId: Int)
    case aboutInput(sectionId:Int, description:String)
    case aboutDesc(sectionId:Int)
    case signMessages(sectionId:Int, sign:Bool)
    case signDesc(sectionId:Int)
    case report(sectionId:Int)
    case leave(sectionId:Int, isCreator: Bool)
    case section(Int)
    

    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.stableIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? ChannelInfoEntry else {
            return false
        }
        switch self {
        case let .info(lhsSectionId, lhsPeerView, lhsEditable, lhsUpdatingPhotoState):
            switch entry {
            case let .info(rhsSectionId, rhsPeerView, rhsEditable, rhsUpdatingPhotoState):
                
                if lhsSectionId != rhsSectionId || lhsEditable != rhsEditable {
                    return false
                }
                
                if lhsUpdatingPhotoState != rhsUpdatingPhotoState {
                    return false
                }
                
                let lhsPeer = peerViewMainPeer(lhsPeerView)
                let lhsCachedData = lhsPeerView.cachedData
                
                let rhsPeer = peerViewMainPeer(rhsPeerView)
                let rhsCachedData = rhsPeerView.cachedData
                
                if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                } else if (lhsPeer == nil) != (rhsPeer != nil) {
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
        case  let .scam(sectionId, text):
            switch entry {
            case .scam(sectionId, text):
                return true
            default:
                return false
            }
        case  let .about(sectionId, text):
            switch entry {
            case .about(sectionId, text):
                return true
            default:
                return false
            }
        case let .userName(sectionId, value):
            switch entry {
            case .userName(sectionId, value):
                return true
            default:
                return false
            }
        case let .setPhoto(sectionId):
            switch entry {
            case .setPhoto(sectionId):
                return true
            default:
                return false
            }
        case let .sharedMedia(sectionId):
            switch entry {
            case .sharedMedia(sectionId):
                return true
            default:
                return false
            }
        case let .notifications(lhsSectionId, lhsSettings):
            switch entry {
            case let .notifications(rhsSectionId, rhsSettings):
                
                if lhsSectionId != rhsSectionId {
                    return false
                }
                if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else if (lhsSettings != nil) != (rhsSettings != nil) {
                    return false
                }
                return true
            default:
                return false
            }
        case .report:
            switch entry {
            case .report:
                return true
            default:
                return false
            }
        case let .admins(lhsSectionId, lhsCount):
            if case let .admins(rhsSectionId, rhsCount) = entry {
                return lhsSectionId == rhsSectionId && lhsCount == rhsCount
            } else {
                return false
            }
        case let .blocked(lhsSectionId, lhsCount):
            if case let .blocked(rhsSectionId, rhsCount) = entry {
                return lhsSectionId == rhsSectionId && lhsCount == rhsCount
            } else {
                return false
            }
        case let .members(lhsSectionId, lhsCount):
            if case let .members(rhsSectionId, rhsCount) = entry {
                return lhsSectionId == rhsSectionId && lhsCount == rhsCount
            } else {
                return false
            }
        case let .statistics(sectionId):
            if case .statistics(sectionId) = entry {
                return true
            } else {
                return false
            }
            
        case let .link(sectionId, addressName):
            if case  .link(sectionId, addressName) = entry {
                return true
            } else {
                return false
            }
        case let .discussion(sectionId, lhsGroup, participantsCount):
            if case .discussion(sectionId, let rhsGroup, participantsCount) = entry {
                if let lhsGroup = lhsGroup, let rhsGroup = rhsGroup {
                    return lhsGroup.isEqual(rhsGroup)
                } else if (lhsGroup != nil) != (rhsGroup != nil) {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .discussionDesc(sectionId):
            if case .discussionDesc(sectionId) = entry {
                return true
            } else {
                return false
            }
        case let .aboutInput(sectionId, _):
            if case .aboutInput(sectionId, _) = entry {
                return true
            } else {
                return false
            }
        case let .aboutDesc(sectionId):
            if case .aboutDesc(sectionId) = entry {
                return true
            } else {
                return false
            }
        case let .signMessages(sectionId, sign):
            if case .signMessages(sectionId, sign) = entry {
                return true
            } else {
                return false
            }
        case let .signDesc(sectionId):
            if case .signDesc(sectionId) = entry {
                return true
            } else {
                return false
            }
        case .leave:
            switch entry {
            case .leave:
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
        }
    }
    
    private var stableIndex: Int {
        switch self {
        case .info:
            return 0
        case .setPhoto:
            return 1
        case .scam:
            return 2
        case .about:
            return 3
        case .userName:
            return 4
        case .sharedMedia:
            return 5
        case .notifications:
            return 6
        case .admins:
            return 7
        case .members:
            return 8
        case .blocked:
            return 9
        case .statistics:
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
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    private var sortIndex: Int {
        switch self {
        case let .info(sectionId, _, _, _):
            return (sectionId * 1000) + stableIndex
        case let .setPhoto(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .scam(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .about(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .userName(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .sharedMedia(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .notifications(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .admins(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .blocked(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .members(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .statistics(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .link(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .discussion(sectionId, _, _):
            return (sectionId * 1000) + stableIndex
        case let .discussionDesc(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .aboutInput(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .aboutDesc(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .signMessages(sectionId, _):
            return (sectionId * 1000) + stableIndex
        case let .signDesc(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .report(sectionId):
            return (sectionId * 1000) + stableIndex
        case let .leave(sectionId, _):
            return (sectionId * 1000) + stableIndex
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
        let state = arguments.state as! ChannelInfoState
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState):
            return PeerInfoHeaderItem(initialSize, stableId: stableId.hashValue, context: arguments.context, peerView:peerView, editable: editable, updatingPhotoState: updatingPhotoState, firstNameEditableText: state.editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .scam(_, text):
            return TextAndLabelItem(initialSize, stableId:stableId.hashValue, label: L10n.peerInfoScam, labelColor: theme.colors.redUI, text: text, context: arguments.context, detectLinks:false)
        case let .about(_, text):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoInfo, text:text, context: arguments.context, detectLinks:true, openInfo: { peerId, toChat, postId, _ in
                if toChat {
                    arguments.peerChat(peerId, postId: postId)
                } else {
                    arguments.peerInfo(peerId)
                }
            }, hashtag: arguments.context.sharedContext.bindings.globalSearch)
        case let .userName(_, value):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label: L10n.peerInfoSharelink, text: link, context: arguments.context, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.context, link: link)), for: arguments.context.window)
            }, selectFullWord: true)
        case .sharedMedia:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSharedMedia, type: .none, action: { () in
                arguments.sharedMedia()
            })
        case let .notifications(_, settings):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoNotifications, type: .switchable(!((settings as? TelegramPeerNotificationSettings)?.isMuted ?? false)), action: {
               arguments.toggleNotifications()
            })
        case .report:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoReport, type: .none, action: { () in
                arguments.report()
            })
        case let .members(_, count: count):
            //, icon: theme.icons.peerInfoMembers
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSubscribers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), action: { () in
                arguments.members()
            })
        case let .admins(_, count: count):
            //, icon: theme.icons.peerInfoAdmins
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoAdministrators, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), action: { () in
                arguments.admins()
            })
        case let .blocked(_, count):
            //, icon: theme.icons.peerInfoBanned
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoRemovedUsers, type: .nextContext(count != nil && count! > 0 ? "\(count!)" : ""), action: { () in
                arguments.blocked()
            })
        case .statistics:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoStatistics, type: .next, action: { () in
                arguments.stats()
            })
        case let .link(_, addressName: addressName):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoChannelType, type: .context(addressName.isEmpty ? L10n.channelPrivate : L10n.channelPublic), action: { () in
                arguments.visibilitySetup()
            })
        case let .discussion(_, group, _):
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
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoDiscussion, type: .nextContext(title), action: { () in
                arguments.setupDiscussion()
            })
        case .discussionDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoDiscussionDesc)
        case .setPhoto:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSetChannelPhoto, nameStyle: blueActionButton, type: .none, action: {
                filePanel(with: photoExts, allowMultiple: false, canChooseDirectories: false, for: arguments.context.window, completion: { paths in
                    if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
                        _ = (putToTemp(image: image, compress: false) |> deliverOnMainQueue).start(next: { path in
                            let controller = EditImageModalController(URL(fileURLWithPath: path), settings: .disableSizes(dimensions: .square))
                            showModal(with: controller, for: arguments.context.window)
                            _ = controller.result.start(next: { url, _ in
                                arguments.updatePhoto(url.path)
                            })
                            
                            controller.onClose = {
                                removeFile(at: path)
                            }
                        })
                    }
                })
            })
        case let .aboutInput(_, text):
            return GeneralInputRowItem(initialSize, stableId: stableId.hashValue, placeholder: L10n.peerInfoAboutPlaceholder, text: text, limit: 255, insets: NSEdgeInsets(left:25,right:25,top:8,bottom:3), textChangeHandler: { updatedText in
                arguments.updateEditingDescriptionText(updatedText)
            }, font: .normal(.title))
        case .aboutDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSetAboutDescription)
        case let .signMessages(_, sign):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: L10n.peerInfoSignMessages, type: .switchable(sign), action: {
                arguments.toggleSignatures(!sign)
            })
        case .signDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: L10n.peerInfoSignMessagesDesc)
        case let .leave(_, isCreator):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isCreator ? L10n.peerInfoDeleteChannel : L10n.peerInfoLeaveChannel, nameStyle:redActionButton, type: .none, action: { () in
                arguments.delete()
            })
        case .section(_):
            return GeneralRowItem(initialSize, height:20, stableId: stableId.hashValue)
        }
    }
}

func channelInfoEntries(view: PeerView, arguments:PeerInfoArguments) -> [PeerInfoEntry] {
    
    let arguments = arguments as! ChannelInfoArguments
    let state = arguments.state as! ChannelInfoState
    
    var entries: [PeerInfoEntry] = []
    
    var sectionId:Int = 1
    
    
    entries.append(ChannelInfoEntry.info(sectionId: sectionId, peerView: view, editable: state.editingState != nil, updatingPhotoState: state.updatingPhotoState))
    
    
    if let channel = peerViewMainPeer(view) as? TelegramChannel {
        
        if let editingState = state.editingState {
            if channel.hasPermission(.changeInfo) {
                entries.append(ChannelInfoEntry.setPhoto(sectionId:sectionId))
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
            if channel.hasPermission(.changeInfo) {
                entries.append(ChannelInfoEntry.aboutInput(sectionId:sectionId, description: editingState.editingDescriptionText))
                entries.append(ChannelInfoEntry.aboutDesc(sectionId: sectionId))
                
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
            var addSectionId: Bool = false
            if channel.flags.contains(.isCreator) {
                entries.append(ChannelInfoEntry.link(sectionId:sectionId, addressName: channel.username ?? ""))
                addSectionId = true
                
                let group: Peer?
                if let cachedData = view.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                    group = view.peers[linkedDiscussionPeerId]
                } else {
                    group = nil
                }
                entries.append(ChannelInfoEntry.discussion(sectionId:sectionId, group: group, participantsCount: nil))
                entries.append(ChannelInfoEntry.discussionDesc(sectionId:sectionId))
            }
            
            if addSectionId {
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
            let messagesShouldHaveSignatures:Bool
            switch channel.info {
            case let .broadcast(info):
                messagesShouldHaveSignatures = info.flags.contains(.messagesShouldHaveSignatures)
            default:
                messagesShouldHaveSignatures = false
            }
            
            if channel.hasPermission(.changeInfo) {
                entries.append(ChannelInfoEntry.signMessages(sectionId: sectionId, sign: messagesShouldHaveSignatures))
                entries.append(ChannelInfoEntry.signDesc(sectionId: sectionId))
                
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            

            entries.append(ChannelInfoEntry.leave(sectionId:sectionId, isCreator: channel.flags.contains(.isCreator)))
            
        } else {
            
            if channel.isScam {
                entries.append(ChannelInfoEntry.scam(sectionId:sectionId, text: L10n.channelInfoScamWarning))
            }
            
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about, !about.isEmpty, !channel.isScam {
                    entries.append(ChannelInfoEntry.about(sectionId:sectionId, text: about))
                }
            }
            
            if let username = channel.username, !username.isEmpty {
                entries.append(ChannelInfoEntry.userName(sectionId:sectionId, value: username))
            }
            
            if entries.count > 1 {
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
            if channel.flags.contains(.isCreator) || (channel.adminRights != nil && !channel.adminRights!.isEmpty) {
                var membersCount:Int32? = nil
                var adminsCount:Int32? = nil
                var blockedCount:Int32? = nil
                var canViewStats: Bool = false
                if let cachedData = view.cachedData as? CachedChannelData {
                    membersCount = cachedData.participantsSummary.memberCount
                    adminsCount = cachedData.participantsSummary.adminCount
                    blockedCount = cachedData.participantsSummary.kickedCount
                    canViewStats = cachedData.flags.contains(.canViewStats)
                }
                entries.append(ChannelInfoEntry.admins(sectionId: sectionId, count: adminsCount))
                entries.append(ChannelInfoEntry.members(sectionId: sectionId, count: membersCount))
                
                entries.append(ChannelInfoEntry.blocked(sectionId: sectionId, count: blockedCount))
                
                #if DEBUG
                if canViewStats {
                    entries.append(ChannelInfoEntry.statistics(sectionId: sectionId))
                }
                #endif
                
                let group: Peer?
                if let cachedData = view.cachedData as? CachedChannelData, let linkedDiscussionPeerId = cachedData.linkedDiscussionPeerId {
                    group = view.peers[linkedDiscussionPeerId]
                } else {
                    group = nil
                }
                if let group = group {
                    entries.append(ChannelInfoEntry.discussion(sectionId:sectionId, group: group, participantsCount: nil))
                }
                
                
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
     
            
            entries.append(ChannelInfoEntry.sharedMedia(sectionId:sectionId))
            if !arguments.isAd {
                entries.append(ChannelInfoEntry.notifications(sectionId:sectionId, settings: view.notificationSettings))
            }
            
            entries.append(ChannelInfoEntry.section(sectionId))
            sectionId += 1
            
            if !channel.flags.contains(.isCreator) {
                entries.append(ChannelInfoEntry.report(sectionId:sectionId))
                if channel.participationStatus == .member {
                    entries.append(ChannelInfoEntry.leave(sectionId:sectionId, isCreator: false))
                }
            }
            
        }
    }
    return entries.sorted(by: { (p1, p2) -> Bool in
        return p1.isOrderedBefore(p2)
    })
}
