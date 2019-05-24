//
//  ChatPresentationInterfaceState.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import TelegramCoreMac
import TGUIKit
import SwiftSignalKitMac

enum ChatPresentationInputContext {
    case none
    case hashtag
    case mention
    case botCommand
    case emoji
}

enum RestrictedMediaType {
    case stickers
    case media
    
}


enum ChatPresentationInputQuery: Equatable {
    case none
    case hashtag(String)
    case mention(query: String, includeRecent: Bool)
    case command(String)
    case contextRequest(addressName: String, query: String)
    case emoji(String, firstWord: Bool)
    case stickers(String)
}

enum ChatPresentationInputQueryResult: Equatable {
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case stickers([FoundStickerItem])
    case emoji([String], Bool)
    case searchMessages(([Message], SearchMessagesState?, (SearchMessagesState?)-> Void), String)
    case contextRequestResult(Peer, ChatContextResultCollection?)
    
    static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
        case let .hashtags(lhsResults):
            if case let .hashtags(rhsResults) = rhs {
                return lhsResults == rhsResults
            } else {
                return false
            }
        case let .stickers(lhsResults):
                if case let .stickers(rhsResults) = rhs {
                    return lhsResults == rhsResults
                } else {
                    return false
            }
        case let .emoji(lhsResults, lhsFirstWord):
            if case let .emoji(rhsResults, rhsFirstWord) = rhs {
                return lhsResults == rhsResults && lhsFirstWord == rhsFirstWord
            } else {
                return false
            }
        case let .searchMessages(lhsMessages, lhsSearchText):
            if case let .searchMessages(rhsMessages, rhsSearchText) = rhs {
                if lhsMessages.0.count == rhsMessages.0.count {
                    for i in 0 ..< lhsMessages.0.count {
                        if !isEqualMessages(lhsMessages.0[i], rhsMessages.0[i]) {
                            return false
                        }
                    }
                    return lhsSearchText == rhsSearchText && lhsMessages.1 == rhsMessages.1
                } else {
                    return false
                }
            } else {
                return false
            }
        case let .mentions(lhsPeers):
            if case let .mentions(rhsPeers) = rhs {
                if lhsPeers.count != rhsPeers.count {
                    return false
                } else {
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                    return true
                }
            } else {
                return false
            }
        case let .commands(lhsCommands):
            if case let .commands(rhsCommands) = rhs {
                if lhsCommands != rhsCommands {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .contextRequestResult(lhsPeer, lhsCollection):
            if case let .contextRequestResult(rhsPeer, rhsCollection) = rhs {
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsCollection != rhsCollection {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
}




enum ChatRecordingStatus : Equatable {
    case paused
    case recording(duration: Double)
}


class ChatRecordingState : Equatable {
  
    let autohold: Bool
    let holdpromise: ValuePromise<Bool> = ValuePromise()
    init(autohold: Bool) {
        self.autohold = autohold
        holdpromise.set(autohold)
    }
    
    var micLevel: Signal<Float, NoError> {
        return .complete()
    }
    var status: Signal<ChatRecordingStatus, NoError> {
        return .complete()
    }
    var data:Signal<[MediaSenderContainer], NoError>  {
        return .complete()
    }
    
    func start() {
        
    }
    func stop() {
        
    }
    func dispose() {
        
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

func ==(lhs:ChatRecordingState, rhs:ChatRecordingState) -> Bool {
    return lhs === rhs
}

final class ChatRecordingVideoState : ChatRecordingState {
    let pipeline: VideoRecorderPipeline
    private let path: String
    init(account: Account, liveUpload:Bool, autohold: Bool) {
        let id:Int64 = arc4random64()
        self.path = NSTemporaryDirectory() + "video_message\(id).mp4"
        self.pipeline = VideoRecorderPipeline(url: URL(fileURLWithPath: path), liveUploading: liveUpload ? PreUploadManager(path, account: account, id: id) : nil)
        super.init(autohold: autohold)
    }
    
    override var micLevel: Signal<Float, NoError> {
        return pipeline.powerAndDuration.get() |> map {$0.0}
    }
    
    override var status: Signal<ChatRecordingStatus, NoError> {
        return pipeline.powerAndDuration.get() |> map { .recording(duration: $0.1) }
    }
    
    override var data: Signal<[MediaSenderContainer], NoError> {
        return pipeline.statePromise.get() |> filter { state in
            switch state {
            case .finishRecording:
                return true
            default:
                return false
            }
        } |> take(1) |> map { state in
            switch state {
            case let .finishRecording(path, duration, id, _):
                return [VideoMessageSenderContainer(path: path, duration: duration, size: CGSize(width: 200, height: 200), id: id)]
            default:
                return []
            }
        }
    }
    
    override func start() {
        pipeline.start()
    }
    override func stop() {
        pipeline.stop()
    }
    override func dispose() {
        pipeline.dispose()
    }
}

final class ChatRecordingAudioState : ChatRecordingState {
    private let recorder:ManagedAudioRecorder

    
    override var micLevel: Signal<Float, NoError> {
        return recorder.micLevel
    }
    
    override var status: Signal<ChatRecordingStatus, NoError> {
        return recorder.recordingState |> map { state in
            switch state {
            case .paused:
                return .paused
            case let .recording(duration, _):
                return .recording(duration: duration)
            }
        }
    }
    
    override var data: Signal<[MediaSenderContainer], NoError> {
        return recorder.takenRecordedData() |> map { value in
            if let value = value, value.duration > 0.5 {
                return [VoiceSenderContainer(data: value, id: value.id)]
            }
            return []
        }
    }
    
    var recordingState: Signal<AudioRecordingState, NoError> {
        return recorder.recordingState
    }
    
    
    
    init(account: Account, liveUpload: Bool, autohold: Bool) {
        let id = arc4random64()
        let path = NSTemporaryDirectory() + "voice_message\(id).ogg"
        let uploadManager:PreUploadManager? = liveUpload ? PreUploadManager(path, account: account, id: id) : nil
        let dataItem = TGDataItem(filePath: path)
        
        recorder = ManagedAudioRecorder(liveUploading: uploadManager, dataItem: dataItem)
        super.init(autohold: autohold)
    }
    
    
    
    override func start() {
        recorder.start()
    }
    
    override func stop() {
        recorder.stop()
    }
    
    override func dispose() {
        recorder.stop()
        _ = data.start(next: { data in
            for container in data {
               // try? FileManager.default.removeItem(atPath: container.path)
            }
        })
    }
    
    
    deinit {
        recorder.stop()
    }
}



enum ChatState : Equatable {
    case normal
    case selecting
    case block(String)
    case action(String, (ChatInteraction)->Void)
    case channelWithDiscussion(discussionGroupId: PeerId?, leftAction: String, rightAction: String)
    case editing
    case recording(ChatRecordingState)
    case restricted(String)
}

func ==(lhs:ChatState, rhs:ChatState) -> Bool {
    switch lhs {
    case .normal:
        if case .normal = rhs {
            return true
        } else {
            return false
        }
    case let .channelWithDiscussion(discussionGroupId, leftAction, rightAction):
        if case .channelWithDiscussion(discussionGroupId, leftAction, rightAction) = rhs {
            return true
        } else {
            return false
        }
    case .selecting:
        if case .selecting = rhs {
            return true
        } else {
            return false
        }
    case .editing:
        if case .editing = rhs {
            return true
        } else {
            return false
        }
    case .recording:
        if case .recording = rhs {
            return true
        } else {
            return false
        }
    case let .block(lhsReason):
        if case let .block(rhsReason) = rhs {
            return lhsReason == rhsReason
        } else {
            return false
        }
    case let .action(lhsAction,_):
        if case let .action(rhsAction,_) = rhs {
            return lhsAction == rhsAction
        } else {
            return false
        }
    case .restricted(let text):
        if case .restricted(text) = rhs {
            return true
        } else {
            return false
        }
    }
}

struct ChatPresentationInterfaceState: Equatable {
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let mainPeer: Peer?
    let chatLocation: ChatLocation
    let isSearchMode:(Bool, Peer?)
    let notificationSettings: TelegramPeerNotificationSettings?
    let inputQueryResult: ChatPresentationInputQueryResult?
    let keyboardButtonsMessage: Message?
    let initialAction:ChatInitialAction?
    let historyCount:Int?
    let isBlocked:Bool?
    let recordingState:ChatRecordingState?
    let reportStatus:PeerReportStatus
    let pinnedMessageId:MessageId?
    let cachedPinnedMessage: Message?
    let urlPreview: (String, TelegramMediaWebpage)?
    let selectionState: ChatInterfaceSelectionState?
    let limitConfiguration: LimitsConfiguration
    
    let sidebarEnabled:Bool?
    let sidebarShown:Bool?
    let layout:SplitViewState?
    let discussionGroupId: PeerId?
    let canAddContact:Bool?
    let isEmojiSection: Bool
    
    let canInvokeBasicActions:(delete: Bool, forward: Bool)
    let isNotAccessible: Bool
    let restrictionInfo: PeerAccessRestrictionInfo?
    var inputContext: ChatPresentationInputQuery {
        return inputContextQueryForChatPresentationIntefaceState(self, includeContext: true)
    }
    
    var isKeyboardActive:Bool {
        guard let reply = keyboardButtonsMessage?.replyMarkup else {
            return false
        }
        
        return reply.rows.count > 0
    }
    
    var state:ChatState {
        if self.selectionState == nil {
            if self.interfaceState.editState != nil {
                return .editing
            }
            
            
            
          

            
            if let peer = peer as? TelegramChannel {
                if let _ = restrictionInfo {
                    return .action(L10n.chatInputClose, { chatInteraction in
                        chatInteraction.context.sharedContext.bindings.rootNavigation().back()
                    })
                }
                
                
                
                
                if peer.participationStatus == .left {
                    return .action(L10n.chatInputJoin, { chatInteraction in
                        chatInteraction.joinChannel()
                    })
                } else if peer.participationStatus == .kicked {
                    return .action(L10n.chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                } else if let permissionText = permissionText(from: peer, for: .banSendMessages) {
                    return .restricted(permissionText)
                } else if !peer.canSendMessage, let notificationSettings = notificationSettings {
                    switch peer.info {
                    case let .broadcast(info):
                        if info.flags.contains(.hasDiscussionGroup) {
                            return .channelWithDiscussion(discussionGroupId: discussionGroupId, leftAction: notificationSettings.isMuted ? L10n.chatInputUnmute : L10n.chatInputMute, rightAction: L10n.chatInputDiscuss)
                        }
                    default:
                        break
                    }
                    return .action(notificationSettings.isMuted ? L10n.chatInputUnmute : L10n.chatInputMute, { chatInteraction in
                        chatInteraction.toggleNotifications()
                    })
                }
            } else if let peer = peer as? TelegramGroup {
                if  peer.membership == .Left {
                    return .action(L10n.chatInputReturn,{ chatInteraction in
                        chatInteraction.returnGroup()
                    })
                } else if peer.membership == .Removed {
                    return .action(L10n.chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                }
            } else if let peer = peer as? TelegramSecretChat, let mainPeer = mainPeer {
                
                switch peer.embeddedState {
                case .terminated:
                    return .action(L10n.chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                case .handshake:
                    return .restricted(L10n.chatInputSecretChatWaitingToUserOnline(mainPeer.compactDisplayTitle))
                default:
                    break
                }
            }
            
            if let blocked = isBlocked, blocked {
                
                if let peer = peer, peer.isBot {
                    return .action(L10n.chatInputRestart, { chatInteraction in
                        chatInteraction.unblock()
                        chatInteraction.startBot()
                    })
                }
                
                return .action(tr(L10n.chatInputUnblock), { chatInteraction in
                    chatInteraction.unblock()
                })
            }
            
            if let peer = peer, let permissionText = permissionText(from: peer, for: .banSendMessages) {
                return .restricted(permissionText)
            }
            
            if self.interfaceState.editState != nil {
                return .editing
            }
            
            if let recordingState = recordingState {
                return .recording(recordingState)
            }

            if let initialAction = initialAction, case .start(_) = initialAction  {
                return .action(tr(L10n.chatInputStartBot), { chatInteraction in
                    chatInteraction.invokeInitialAction()
                })
            }
            
            if let peer = peer as? TelegramUser {
                
                if peer.botInfo != nil, let historyCount = historyCount, historyCount == 0 {
                    return .action(tr(L10n.chatInputStartBot), { chatInteraction in
                        chatInteraction.startBot()
                    })
                }
            }
           
            
            return .normal
        } else {
            return .selecting
        }
    }
    
    var isKeyboardShown:Bool {
        if let keyboard = keyboardButtonsMessage, let attribute = keyboard.replyMarkup {
            return interfaceState.messageActionsState.closedButtonKeyboardMessageId != keyboard.id && attribute.hasButtons && state == .normal

        }
        return false
    }
    
    var isShowSidebar: Bool {
        if let sidebarEnabled = sidebarEnabled, let peer = peer, let sidebarShown = sidebarShown, let layout = layout {
            return sidebarEnabled && peer.canSendMessage && sidebarShown && layout == .dual
        }
        return false
    }
    

    
    var abilityToSend:Bool {
        if state == .normal {
            return !effectiveInput.inputText.isEmpty || !interfaceState.forwardMessageIds.isEmpty
        } else if let editState = interfaceState.editState {
            if editState.message.media.count == 0 {
                return !effectiveInput.inputText.isEmpty
            } else {
                for media in editState.message.media {
                    if !(media is TelegramMediaWebpage) {
                        return true
                    }
                }
                return !effectiveInput.inputText.isEmpty
            }
        }
        
        return false
    }
    
    let maxInput:Int32 = 50000
    let maxShortInput:Int32 = 1024
    
    var maxInputCharacters:Int32 {
        if state == .normal {
            return maxInput
        } else if let _ = interfaceState.editState {
            return maxShortInput
//            if editState.message.media.count == 0 {
//                return maxInput
//            } else {
//                for media in editState.message.media {
//                    if !(media is TelegramMediaWebpage) {
//                        return
//                    }
//                }
//                return maxInput
//            }
        }
        
        return maxInput
    }
    
    var effectiveInput:ChatTextInputState {
        if let editState = interfaceState.editState {
            return editState.inputState
        } else {
            return interfaceState.inputState
        }
    }
    
    init(_ chatLocation: ChatLocation) {
        self.interfaceState = ChatInterfaceState()
        self.peer = nil
        self.notificationSettings = nil
        self.inputQueryResult = nil
        self.keyboardButtonsMessage = nil
        self.initialAction = nil
        self.historyCount = 0
        self.isSearchMode = (false, nil)
        self.recordingState = nil
        self.isBlocked = nil
        self.reportStatus = .unknown
        self.pinnedMessageId = nil
        self.urlPreview = nil
        self.selectionState = nil
        self.sidebarEnabled = nil
        self.sidebarShown = nil
        self.layout = nil
        self.canAddContact = nil
        self.isEmojiSection = FastSettings.entertainmentState == .emoji
        self.chatLocation = chatLocation
        self.canInvokeBasicActions = (delete: false, forward: false)
        self.isNotAccessible = false
        self.restrictionInfo = nil
        self.cachedPinnedMessage = nil
        self.mainPeer = nil
        self.limitConfiguration = LimitsConfiguration.defaultValue
        self.discussionGroupId = nil
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, notificationSettings:TelegramPeerNotificationSettings?, inputQueryResult: ChatPresentationInputQueryResult?, keyboardButtonsMessage:Message?, initialAction:ChatInitialAction?, historyCount:Int?, isSearchMode:(Bool, Peer?), recordingState: ChatRecordingState?, isBlocked:Bool?, reportStatus: PeerReportStatus, pinnedMessageId:MessageId?, urlPreview: (String, TelegramMediaWebpage)?, selectionState: ChatInterfaceSelectionState?, sidebarEnabled: Bool?, sidebarShown: Bool?, layout:SplitViewState?, canAddContact:Bool?, isEmojiSection: Bool, chatLocation: ChatLocation, canInvokeBasicActions: (delete: Bool, forward: Bool), isNotAccessible: Bool, restrictionInfo: PeerAccessRestrictionInfo?, cachedPinnedMessage: Message?, mainPeer: Peer?, limitConfiguration: LimitsConfiguration, discussionGroupId: PeerId?) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.notificationSettings = notificationSettings
        self.inputQueryResult = inputQueryResult
        self.keyboardButtonsMessage = keyboardButtonsMessage
        self.initialAction = initialAction
        self.historyCount = historyCount
        self.isSearchMode = isSearchMode
        self.recordingState = recordingState
        self.isBlocked = isBlocked
        self.reportStatus = reportStatus
        self.pinnedMessageId = pinnedMessageId
        self.urlPreview = urlPreview
        self.selectionState = selectionState
        self.sidebarEnabled = sidebarEnabled
        self.sidebarShown = sidebarShown
        self.layout = layout
        self.canAddContact = canAddContact
        self.isEmojiSection = isEmojiSection
        self.chatLocation = chatLocation
        self.canInvokeBasicActions = canInvokeBasicActions
        self.isNotAccessible = isNotAccessible
        self.restrictionInfo = restrictionInfo
        self.cachedPinnedMessage = cachedPinnedMessage
        self.mainPeer = mainPeer
        self.limitConfiguration = limitConfiguration
        self.discussionGroupId = discussionGroupId
    }
    
    static func ==(lhs: ChatPresentationInterfaceState, rhs: ChatPresentationInterfaceState) -> Bool {
        if lhs.interfaceState != rhs.interfaceState {
            return false
        }
        if lhs.discussionGroupId != rhs.discussionGroupId {
            return false
        }
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer == nil) != (rhs.peer == nil) {
            return false
        }
        
        if let lhsPeer = lhs.mainPeer, let rhsPeer = rhs.mainPeer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.mainPeer == nil) != (rhs.mainPeer == nil) {
            return false
        }
        
        if lhs.restrictionInfo != rhs.restrictionInfo {
            return false
        }
        if lhs.limitConfiguration != rhs.limitConfiguration {
            return false
        }
        
        if let lhsMessage = lhs.cachedPinnedMessage, let rhsMessage = rhs.cachedPinnedMessage {
            if !isEqualMessages(lhsMessage, rhsMessage) {
                return false
            }
        } else if (lhs.cachedPinnedMessage != nil) != (rhs.cachedPinnedMessage != nil) {
            return false
        }
        
        
        if lhs.chatLocation != rhs.chatLocation {
            return false
        }
        
        if lhs.state != rhs.state {
            return false
        }
        
        if lhs.isSearchMode.0 != rhs.isSearchMode.0 {
            return false
        }
        if lhs.sidebarEnabled != rhs.sidebarEnabled {
            return false
        }
        if lhs.sidebarShown != rhs.sidebarShown {
            return false
        }
        if lhs.layout != rhs.layout {
            return false
        }
        if lhs.canAddContact != rhs.canAddContact {
            return false
        }
        
        if lhs.recordingState != rhs.recordingState {
            return false
        }
        
        if lhs.inputQueryResult != rhs.inputQueryResult {
            return false
        }
        
        if lhs.initialAction != rhs.initialAction {
            return false
        }
        
        if lhs.historyCount != rhs.historyCount {
            return false
        }
        
        if lhs.isBlocked != rhs.isBlocked {
            return false
        }
        
        if lhs.reportStatus != rhs.reportStatus {
            return false
        }
        if lhs.isNotAccessible != rhs.isNotAccessible {
            return false
        }
        
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        
        if lhs.pinnedMessageId != rhs.pinnedMessageId {
            return false
        }
        if lhs.isEmojiSection != rhs.isEmojiSection {
            return false
        }
        
        if let lhsUrlPreview = lhs.urlPreview, let rhsUrlPreview = rhs.urlPreview {
            if lhsUrlPreview.0 != rhsUrlPreview.0 {
                return false
            }
            if !lhsUrlPreview.1.isEqual(to: rhsUrlPreview.1) {
                return false
            }
        } else if (lhs.urlPreview != nil) != (rhs.urlPreview != nil) {
            return false
        }
        
        if let lhsMessage = lhs.keyboardButtonsMessage, let rhsMessage = rhs.keyboardButtonsMessage {
            if  lhsMessage.id != rhsMessage.id || lhsMessage.stableVersion != rhsMessage.stableVersion {
                return false
            }
        } else if (lhs.keyboardButtonsMessage == nil) != (rhs.keyboardButtonsMessage == nil) {
            return false
        }
        
        if lhs.inputContext != rhs.inputContext {
            return false
        }
        if lhs.canInvokeBasicActions != rhs.canInvokeBasicActions {
            return false
        }
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
        
    }
    
    func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        let interface = ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:message, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
        
        if let peerId = peer?.id, let keyboardMessage = interface.keyboardButtonsMessage {
            if keyboardButtonsMessage?.id != keyboardMessage.id || keyboardButtonsMessage?.stableVersion != keyboardMessage.stableVersion {
                if peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                    return interface.updatedInterfaceState({$0.withUpdatedMessageActionsState({$0.withUpdatedProcessedSetupReplyMessageId(keyboardMessage.id)})})
                }
            }
            
        }
        return interface
    }
    
    func updatedPeer(_ f: (Peer?) -> Peer?) -> ChatPresentationInterfaceState {
        
        let peer = f(self.peer)
        
        var restrictionInfo: PeerAccessRestrictionInfo? = self.restrictionInfo
        if let peer = peer as? TelegramChannel, let info = peer.restrictionInfo, info.reason.hasPrefix("terms-all:") {
            restrictionInfo = info
        }
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func updatedMainPeer(_ mainPeer: Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func updatedNotificationSettings(_ notificationSettings:TelegramPeerNotificationSettings?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    
    
    func updatedHistoryCount(_ historyCount:Int?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func updatedSearchMode(_ isSearchMode: (Bool, Peer?)) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, isSearchMode: isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: f(self.inputQueryResult), keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func updatedInitialAction(_ initialAction:ChatInitialAction?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    
    func withRecordingState(_ state:ChatRecordingState) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: state, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withoutRecordingState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: nil, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedBlocked(_ blocked:Bool) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: blocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedPinnedMessageId(_ messageId:MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: messageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedCachedPinnedMessage(_ cachedPinnedMessage:Message?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedReportStatus(_ reportStatus:PeerReportStatus) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withEditMessage(_ message:Message) -> ChatPresentationInterfaceState {
        return self.updatedInterfaceState({$0.withEditMessage(message)})
    }
    
    func withoutEditMessage() -> ChatPresentationInterfaceState {
        return self.updatedInterfaceState({$0.withoutEditMessage()})
    }
    
    func withUpdatedEffectiveInputState(_ inputState: ChatTextInputState) -> ChatPresentationInterfaceState {
        return self.updatedInterfaceState({$0.withUpdatedInputState(inputState)})
    }
    
    func updatedUrlPreview(_ urlPreview: (String, TelegramMediaWebpage)?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    
    func isSelectedMessageId(_ messageId:MessageId) -> Bool {
        if let selectionState = selectionState {
            return selectionState.selectedIds.contains(messageId)
        }
        return false
    }
    
    func withUpdatedSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.count < 100 {
            selectedIds.insert(messageId)
        } else {
            NSSound.beep()
        }
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedSelectedMessages(_ ids:Set<MessageId>) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: ids), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.contains(messageId) {
            let _ = selectedIds.remove(messageId)
        } else {
            if selectedIds.count < 100 {
                selectedIds.insert(messageId)
            } else {
                NSSound.beep()
            }
        }
        
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withRemovedSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        let _ = selectedIds.remove(messageId)
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }

    
    func withoutSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState:nil, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: []), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }

    func withToggledSidebarEnabled(_ enabled: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: enabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withToggledSidebarShown(_ shown: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: shown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedLayout(_ layout: SplitViewState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withoutInitialAction() -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: nil, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedContactAdding(_ canAddContact:Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedIsEmojiSection(_ isEmojiSection:Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedBasicActions(_ canInvokeBasicActions:(delete: Bool, forward: Bool)) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }

    
    func withUpdatedIsNotAccessible(_ isNotAccessible:Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedRestrictionInfo(_ restrictionInfo:PeerAccessRestrictionInfo?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedLimitConfiguration(_ limitConfiguration:LimitsConfiguration) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: self.discussionGroupId)
    }
    
    func withUpdatedDiscussionGroupId(_ discussionGroupId: PeerId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, cachedPinnedMessage: self.cachedPinnedMessage, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId)
    }
    
    
}
