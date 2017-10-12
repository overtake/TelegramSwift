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
        
        let account = self.account
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
            
            
            
            let updateTitle: Signal<Void, Void>
            if let titleValue = updateValues.title {
                updateTitle = updatePeerTitle(account: account, peerId: peerId, title: titleValue)
                    |> mapError { _ in return Void() }
            } else {
                updateTitle = .complete()
            }
            
            let updateDescription: Signal<Void, Void>
            if let descriptionValue = updateValues.description {
                updateDescription = updatePeerDescription(account: account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                    |> mapError { _ in return Void() }
            } else {
                updateDescription = .complete()
            }
            
            let signal = combineLatest(updateTitle, updateDescription)
            
            updatePeerNameDisposable.set(showModalProgress(signal: (signal |> deliverOnMainQueue), for: mainWindow).start(error: { _ in
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
        pushViewController(ChannelVisibilityController(account: account, peerId: peerId))
    }
    
    func toggleSignatures( _ enabled: Bool) -> Void {
        toggleSignaturesDisposable.set(toggleShouldChannelMessagesSignatures(account: account, peerId: peerId, enabled: enabled).start())
    }
    
    func members() -> Void {
        pushViewController(ChannelMembersViewController(account: account, peerId: peerId))
    }
    
    func admins() -> Void {
        pushViewController(ChannelAdminsViewController(account: account, peerId: peerId))
    }
    
    func blocked() -> Void {
        pushViewController(ChannelBlacklistViewController(account: account, peerId: peerId))
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
        
        let account = self.account
        let peerId = self.peerId
        /*
         filethumb(with: URL(fileURLWithPath: path), account: account, scale: System.backingScale) |> mapToSignal { res -> Signal<String, Void> in
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
        let updateSignal = Signal<String, Void>.single(path) |> map { path -> TelegramMediaResource in
            return LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64())
        } |> beforeNext { resource in
            
            updateState { (state) -> ChannelInfoState in
                return state.withUpdatedUpdatingPhotoState { previous -> PeerInfoUpdatingPhotoState? in
                    return PeerInfoUpdatingPhotoState(progress: 0, cancel: cancel)
                }
            }
            
        } |> mapError {_ in return UploadPeerPhotoError.generic} |> mapToSignal { resource -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> in
            return  updatePeerPhoto(account: account, peerId: peerId, resource: resource)
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
    
    func report() -> Void {
        let account = self.account
        let peerId = self.peerId
        
        let report = reportReasonSelector() |> mapToSignal { reason -> Signal<Void, Void> in
            return showModalProgress(signal: reportPeer(account: account, peerId: peerId, reason: reason), for: mainWindow)
        } |> deliverOnMainQueue
        
        reportPeerDisposable.set(report.start(next: { [weak self] in
            self?.pullNavigation()?.controller.show(toaster: ControllerToaster(text: tr(.peerInfoChannelReported)))
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
    case about(sectionId:Int, text: String)
    case userName(sectionId:Int, value: String)
    case setPhoto(sectionId:Int)
    case sharedMedia(sectionId:Int)
    case notifications(sectionId:Int, settings: PeerNotificationSettings?)
    case admins(sectionId:Int, count:Int32?)
    case blocked(sectionId:Int, count:Int32?)
    case members(sectionId:Int, count:Int32?)
    case link(sectionId:Int, addressName:String)
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
        case let .link(sectionId, addressName):
            if case  .link(sectionId, addressName) = entry {
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
        case .about:
            return 2
        case .userName:
            return 3
        case .sharedMedia:
            return 4
        case .notifications:
            return 5
        case .admins:
            return 6
        case .blocked:
            return 7
        case .members:
            return 8
        case .link:
            return 9
        case .aboutInput:
            return 10
        case .aboutDesc:
            return 11
        case .signMessages:
            return 12
        case .signDesc:
            return 13
        case .report:
            return 14
        case .leave:
            return 15
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
        case let .link(sectionId, _):
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
        return self.sortIndex > entry.sortIndex
    }
    
    func item(initialSize:NSSize, arguments:PeerInfoArguments) -> TableRowItem {
        let arguments = arguments as! ChannelInfoArguments
        let state = arguments.state as! ChannelInfoState
        switch self {
        case let .info(_, peerView, editable, updatingPhotoState):
            return PeerInfoHeaderItem(initialSize, stableId: stableId.hashValue, account:arguments.account, peerView:peerView, editable: editable, updatingPhotoState: updatingPhotoState, firstNameEditableText: state.editingState?.editingName, textChangeHandler: { name, _ in
                arguments.updateEditingName(name)
            })
        case let .about(_, text):
            return TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:tr(.peerInfoInfo), text:text, account: arguments.account, detectLinks:true, openInfo: { peerId, toChat, _, _ in
                if toChat {
                    arguments.peerChat(peerId)
                } else {
                    arguments.peerInfo(peerId)
                }
            })
        case let .userName(_, value):
            let link = "https://t.me/\(value)"
            return  TextAndLabelItem(initialSize, stableId: stableId.hashValue, label:tr(.peerInfoSharelink), text: link, account: arguments.account, isTextSelectable:false, callback:{
                showModal(with: ShareModalController(ShareLinkObject(arguments.account, link: link)), for: mainWindow)
            })
        case .sharedMedia:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSharedMedia), type: .none, action: { () in
                arguments.sharedMedia()
            })
        case let .notifications(_, settings):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoNotifications), type: .switchable(stateback: { () -> Bool in
                
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    return false
                } else {
                    return true
                }
                
            }), action: { 
               arguments.toggleNotifications()
            })
        case .report:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoReport), type: .none, action: { () in
                arguments.report()
            })
        case let .members(_, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoMembers), type: .context(stateback: { () -> String in
                if let count = count {
                    return "\(count)"
                } else {
                    return ""
                }
            }), action: { () in
                arguments.members()
            })
        case let .admins(_, count: count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoAdmins), type: .context(stateback: { () -> String in
                if let count = count {
                    return "\(count)"
                } else {
                    return ""
                }
            }), action: { () in
                arguments.admins()
            })
        case let .blocked(_, count):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoBlackList), type: .context(stateback: { () -> String in
                if let count = count {
                    return "\(count)"
                } else {
                    return ""
                }
            }), action: { () in
                arguments.blocked()
            })
        case let .link(_, addressName: addressName):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoChannelType), type: .context(stateback: { () -> String in
                return addressName.isEmpty ? tr(.channelPrivate) : tr(.channelPublic)
            }), action: { () in
                arguments.visibilitySetup()
            })
        case .setPhoto:
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSetChannelPhoto), nameStyle: blueActionButton, type: .none, action: { 
                pickImage(for: mainWindow, completion: { image in
                    if let image = image {
                        _ = (putToTemp(image: image) |> deliverOnMainQueue).start(next: { path in
                            arguments.updatePhoto(path)
                        })
                    }
                })
                
            })
        case let .aboutInput(_, text):
            return GeneralInputRowItem(initialSize, stableId: stableId.hashValue, placeholder: tr(.peerInfoAboutPlaceholder), text: text, limit: 255, insets: NSEdgeInsets(left:25,right:25,top:8,bottom:3), textChangeHandler: { updatedText in
                arguments.updateEditingDescriptionText(updatedText)
            })
        case .aboutDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: tr(.peerInfoSetAboutDescription))
        case let .signMessages(_, sign):
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: tr(.peerInfoSignMessages), type: .switchable(stateback: { () -> Bool in
                return sign
            }), action: { 
                arguments.toggleSignatures(!sign)
            })
        case .signDesc:
            return GeneralTextRowItem(initialSize, stableId: stableId.hashValue, text: tr(.peerInfoSignMessagesDesc))
        case let .leave(_, isCreator):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId.hashValue, name: isCreator ? tr(.peerInfoDeleteChannel) : tr(.peerInfoLeaveChannel), nameStyle:redActionButton, type: .none, action: { () in
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
            if channel.hasAdminRights(.canChangeInfo) {
                entries.append(ChannelInfoEntry.setPhoto(sectionId:sectionId))
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            if channel.flags.contains(.isCreator) {
                entries.append(ChannelInfoEntry.link(sectionId:sectionId, addressName: channel.username ?? ""))
            }
            
            if channel.hasAdminRights(.canChangeInfo) {
                entries.append(ChannelInfoEntry.aboutInput(sectionId:sectionId, description: editingState.editingDescriptionText))
                entries.append(ChannelInfoEntry.aboutDesc(sectionId: sectionId))
                
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
            
            if channel.hasAdminRights(.canChangeInfo) {
                entries.append(ChannelInfoEntry.signMessages(sectionId: sectionId, sign: messagesShouldHaveSignatures))
                entries.append(ChannelInfoEntry.signDesc(sectionId: sectionId))
                
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            

            entries.append(ChannelInfoEntry.leave(sectionId:sectionId, isCreator: channel.flags.contains(.isCreator)))
            
        } else {
            
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about, !about.isEmpty {
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
            
            if channel.groupAccess.canManageGroup {
                var membersCount:Int32? = nil
                var adminsCount:Int32? = nil
                var blockedCount:Int32? = nil
                if let cachedData = view.cachedData as? CachedChannelData {
                    membersCount = cachedData.participantsSummary.memberCount
                    adminsCount = cachedData.participantsSummary.adminCount
                    blockedCount = cachedData.participantsSummary.kickedCount
                }
                entries.append(ChannelInfoEntry.admins(sectionId: sectionId, count: adminsCount))
                entries.append(ChannelInfoEntry.members(sectionId: sectionId, count: membersCount))
                
                if let blockedCount = blockedCount {
                    entries.append(ChannelInfoEntry.blocked(sectionId: sectionId, count: blockedCount))
                }
                
                entries.append(ChannelInfoEntry.section(sectionId))
                sectionId += 1
            }
            
     
            
            entries.append(ChannelInfoEntry.sharedMedia(sectionId:sectionId))
            entries.append(ChannelInfoEntry.notifications(sectionId:sectionId, settings: view.notificationSettings))
            
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
