//
//  ChatPresentationInterfaceState.swift
//  Telegram-Mac
//
//  Created by keepcoder on 01/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import OpusBinding
import Postbox
import TelegramCore
import TGUIKit
import SwiftSignalKit
import TelegramMedia

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

final class ChatPinnedMessage: Equatable {
    let messageId: MessageId
    let message: Message?
    let isLatest: Bool
    let index: Int
    let totalCount: Int
    let others:[MessageId]
    init(messageId: MessageId, message: Message?, others: [MessageId] = [], isLatest: Bool, index:Int = 0, totalCount: Int = 1) {
        self.messageId = messageId
        self.message = message
        self.others = others
        self.isLatest = isLatest
        self.index = index
        self.totalCount = totalCount
    }
    
    static func ==(lhs: ChatPinnedMessage, rhs: ChatPinnedMessage) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.messageId != rhs.messageId {
            return false
        }
        if lhs.message?.id != rhs.message?.id {
            return false
        }
        if lhs.message?.stableVersion != rhs.message?.stableVersion {
            return false
        }
        if lhs.isLatest != rhs.isLatest {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.totalCount != rhs.totalCount {
            return false
        }
        return true
    }
}


struct GroupCallPanelData : Equatable {
    let peerId: PeerId
    let info: GroupCallInfo?
    let topParticipants: [GroupCallParticipantsContext.Participant]
    let participantCount: Int
    let activeSpeakers: Set<PeerId>
    private(set) weak var groupCall: GroupCallContext?
    init(
        peerId: PeerId,
        info: GroupCallInfo?,
        topParticipants: [GroupCallParticipantsContext.Participant],
        participantCount: Int,
        activeSpeakers: Set<PeerId>,
        groupCall: GroupCallContext?
    ) {
        self.peerId = peerId
        self.info = info
        self.topParticipants = topParticipants
        self.participantCount = participantCount
        self.activeSpeakers = activeSpeakers
        self.groupCall = groupCall
    }
    
    static func ==(lhs: GroupCallPanelData, rhs: GroupCallPanelData) -> Bool {
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.info != rhs.info {
            return false
        }
        if lhs.topParticipants != rhs.topParticipants {
            return false
        }
        if lhs.activeSpeakers != rhs.activeSpeakers {
            return false
        }
        if (lhs.groupCall != nil) != (rhs.groupCall != nil) {
            return false
        }
        if lhs.participantCount != rhs.participantCount {
            return false
        }
        return true
    }
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


struct ChatActiveGroupCallInfo: Equatable {
    var activeCall: CachedChannelData.ActiveCall
    let data: GroupCallPanelData?
    let callJoinPeerId: PeerId?
    let joinHash: String?
    let isLive: Bool
    init(activeCall: CachedChannelData.ActiveCall, data: GroupCallPanelData?, callJoinPeerId: PeerId?, joinHash: String?, isLive: Bool) {
        self.activeCall = activeCall
        self.data = data
        self.callJoinPeerId = callJoinPeerId
        self.joinHash = joinHash
        self.isLive = isLive
    }
    
    func withUpdatedData(_ data: GroupCallPanelData?) -> ChatActiveGroupCallInfo {
        return ChatActiveGroupCallInfo(activeCall: self.activeCall, data: data, callJoinPeerId: self.callJoinPeerId, joinHash: self.joinHash, isLive: self.isLive)
    }
    func withUpdatedActiveCall(_ activeCall: CachedChannelData.ActiveCall) -> ChatActiveGroupCallInfo {
        return ChatActiveGroupCallInfo(activeCall: activeCall, data: self.data, callJoinPeerId: self.callJoinPeerId, joinHash: self.joinHash, isLive: self.isLive)
    }
    func withUpdatedCallJoinPeerId(_ callJoinPeerId: PeerId?) -> ChatActiveGroupCallInfo {
        return ChatActiveGroupCallInfo(activeCall: activeCall, data: self.data, callJoinPeerId: callJoinPeerId, joinHash: self.joinHash, isLive: self.isLive)
    }
    func withUpdatedJoinHash(_ joinHash: String?) -> ChatActiveGroupCallInfo {
        return ChatActiveGroupCallInfo(activeCall: self.activeCall, data: self.data, callJoinPeerId: self.callJoinPeerId, joinHash: joinHash, isLive: self.isLive)
    }
}



enum ChatRecordingStatus : Equatable {
    case paused
    case recording(duration: Double)
}


class ChatRecordingState : Equatable {
  
    let autohold: Bool
    let holdpromise: ValuePromise<Bool> = ValuePromise()
    
    var isOneTime: Bool = false
    
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
    init(context: AccountContext, liveUpload:Bool, autohold: Bool) {
        let id:Int64 = arc4random64()
        self.path = NSTemporaryDirectory() + "video_message\(id).mp4"
        self.pipeline = VideoRecorderPipeline(url: URL(fileURLWithPath: path), config: VideoMessageConfig.with(appConfiguration: context.appConfiguration), liveUploading: liveUpload ? PreUploadManager(path, engine: context.engine, id: id) : nil)
        super.init(autohold: autohold)
    }
    
    override var micLevel: Signal<Float, NoError> {
        return pipeline.powerAndDuration.get() |> map {$0.0}
    }
    
    override var status: Signal<ChatRecordingStatus, NoError> {
        return pipeline.powerAndDuration.get() |> map { .recording(duration: $0.1) }
    }
    
    override var data: Signal<[MediaSenderContainer], NoError> {
        let isOneTime = self.isOneTime
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
                return [VideoMessageSenderContainer(path: path, duration: duration, size: CGSize(width: 200, height: 200), id: id, isOneTime: isOneTime)]
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
        let isOneTime = self.isOneTime
        return recorder.takenRecordedData() |> map { value in
            if let value = value, value.duration > 0.5 {
                return [VoiceSenderContainer(data: value, id: value.id, isOneTime: isOneTime)]
            }
            return []
        }
    }
    
    var recordingState: Signal<AudioRecordingState, NoError> {
        return recorder.recordingState
    }
    
    
    
    init(context: AccountContext, liveUpload: Bool, autohold: Bool) {
        let id = arc4random64()
        let path = NSTemporaryDirectory() + "voice_message\(id).ogg"
        let uploadManager:PreUploadManager? = liveUpload ? PreUploadManager(path, engine: context.engine, id: id) : nil
        let dataItem = DataItem(path: path)
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

struct ChatSearchModeState : Equatable {
    var inSearch: Bool
    var peer: EnginePeer?
    var query: String?
    var tag: HistoryViewInputTag?
    var showAll: Bool = false
}

enum ChatState : Equatable {

    struct AdditionAction {
        let icon: CGImage
        let action: (NSView)->Void
    }

    case normal
    case selecting
    case block(String)
    case action(String, (ChatInteraction)->Void, AdditionAction?)
    case botStart(String, (ChatInteraction)->Void)
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
    case let .action(lhsAction,_, _):
        if case let .action(rhsAction, _, _) = rhs {
            return lhsAction == rhsAction
        } else {
            return false
        }
    case let .botStart(lhsAction,_):
        if case let .botStart(rhsAction, _) = rhs {
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

struct ChatPeerStatus : Equatable {
    let canAddContact: Bool
    let peerStatusSettings: PeerStatusSettings?
    init(canAddContact: Bool, peerStatusSettings: PeerStatusSettings?) {
        self.canAddContact = canAddContact
        self.peerStatusSettings = peerStatusSettings
    }
}

struct SlowMode : Equatable {
    let validUntil: Int32?
    let timeout: Int32?
    let sendingIds: [MessageId]
    init(validUntil: Int32? = nil, timeout: Int32? = nil, sendingIds: [MessageId] = []) {
        self.validUntil = validUntil
        self.timeout = timeout
        self.sendingIds = sendingIds
    }
    func withUpdatedValidUntil(_ validUntil: Int32?) -> SlowMode {
        return SlowMode(validUntil: validUntil, timeout: self.timeout, sendingIds: self.sendingIds)
    }
    func withUpdatedTimeout(_ timeout: Int32?) -> SlowMode {
        return SlowMode(validUntil: self.validUntil, timeout: timeout, sendingIds: self.sendingIds)
    }
    func withUpdatedSendingIds(_ sendingIds: [MessageId]) -> SlowMode {
        return SlowMode(validUntil: self.validUntil, timeout: self.timeout, sendingIds: sendingIds)
    }
    
    var hasLocked: Bool {
        return timeout != nil || !sendingIds.isEmpty
    }
    
    var sendingLocked: Bool {
        return timeout != nil
    }
    
    var errorText: String? {
        if let timeout = timeout {
            return slowModeTooltipText(timeout)
        } else if !sendingIds.isEmpty {
            return strings().slowModeMultipleError
        } else {
            return nil
        }
    }
}

struct SavedMessageTagsValue : Equatable {
    let tags: [SavedMessageTags.Tag]
    let files: [Int64: TelegramMediaFile]
}

class ChatPresentationInterfaceState: Equatable {
    
    struct BotMenu : Equatable {
        var commands: [BotCommand]
        var revealed: Bool
        var menuButton: BotMenuButton
        
        var isEmpty: Bool {
            switch self.menuButton {
            case .webView:
                return false
            case .commands:
                return self.commands.isEmpty
            }
        }
    }
    struct TranslateState : Equatable {
        var canTranslate: Bool
        var translate: Bool
        var from: String?
        var to: String
        var paywall: Bool
        var result:[ChatLiveTranslateContext.State.Key : ChatLiveTranslateContext.State.Result]
    }
    
    let interfaceState: ChatInterfaceState
    let peer: Peer?
    let mainPeer: Peer?
    let accountPeer: Peer?
    let chatLocation: ChatLocation
    let chatMode: ChatMode
    let searchMode: ChatSearchModeState
    let notificationSettings: TelegramPeerNotificationSettings?
    let inputQueryResult: ChatPresentationInputQueryResult?
    let keyboardButtonsMessage: Message?
    let initialAction:ChatInitialAction?
    let historyCount:Int?
    let isBlocked:Bool?
    let recordingState:ChatRecordingState?
    let peerStatus:ChatPeerStatus?
    let pinnedMessageId:ChatPinnedMessage?
    let urlPreview: (String, TelegramMediaWebpage)?
    let selectionState: ChatInterfaceSelectionState?
    let limitConfiguration: LimitsConfiguration
   
    let sidebarEnabled:Bool?
    let sidebarShown:Bool?
    let layout:SplitViewState?
    let discussionGroupId: CachedChannelData.LinkedDiscussionPeerId
    let canAddContact:Bool?
    let isEmojiSection: Bool
    let canInvokeBasicActions:(delete: Bool, forward: Bool)
    let isNotAccessible: Bool
    let hasScheduled: Bool
    let slowMode: SlowMode?
    let failedMessageIds:Set<MessageId>
    let hidePinnedMessage: Bool
    let canPinMessage: Bool
    let tempPinnedMaxId: MessageId?
    let restrictionInfo: PeerAccessRestrictionInfo?
    let groupCall: ChatActiveGroupCallInfo?
    let messageSecretTimeout: CachedPeerAutoremoveTimeout?
    let reportMode: ReportReasonValue?
    let currentSendAsPeerId: PeerId?
    let inviteRequestsPending: Int32?
    let inviteRequestsPendingPeers:[PeerInvitationImportersState.Importer]?
    let botMenu:BotMenu?
    let sendAsPeers:[SendAsPeer]?
    let allowedReactions:PeerAllowedReactions?
    let attachItems:[AttachMenuBot]
    let cachedData: CachedPeerData?
    let presence: TelegramUserPresence?
    let threadInfo: MessageHistoryThreadData?
    let translateState: TranslateState?
    let savedMessageTags: SavedMessageTagsValue?
    let displaySavedChatsAsTopics: Bool
    
    var inputContext: ChatPresentationInputQuery {
        return inputContextQueryForChatPresentationIntefaceState(self, includeContext: true)
    }
    
    var effectiveInputContext: ChatPresentationInputQuery {
        let current = inputContextQueryForChatPresentationIntefaceState(self, includeContext: true)
        if case .contextRequest = current {
            let without = inputContextQueryForChatPresentationIntefaceState(self, includeContext: false)
            
            return without
        } else {
            return current
        }
    }
    
    var isKeyboardActive:Bool {
        guard let reply = keyboardButtonsMessage?.replyMarkup else {
            return false
        }
        
        return reply.rows.count > 0 && !reply.flags.contains(.persistent)
    }
    
    var canPinMessageInPeer: Bool {
        if let peer = peer as? TelegramChannel, peer.hasPermission(.pinMessages) || (peer.isChannel && peer.hasPermission(.editAllMessages)) {
            return true
        } else if let peer = peer as? TelegramGroup, peer.canPinMessage {
            return true
        } else if let _ = peer as? TelegramSecretChat {
            return false
        } else {
            return canPinMessage
        }
    }
    
    var canReplyInRestrictedMode: Bool {
        if state == .normal {
            return true
        } else if case .restricted = state, let peer = self.peer, peer.isForum, case .history = self.chatMode {
            return true
        } else if let peer = peer, peer.isChannel {
            return peer.isChannel
        }
        return false
    }
    
    var state:ChatState {
        if self.selectionState == nil {
            if let initialAction = initialAction, case .start = initialAction  {
                return .botStart(strings().chatInputStartBot, { chatInteraction in
                    chatInteraction.invokeInitialAction()
                })
            }
            
            if let recordingState = recordingState {
                return .recording(recordingState)
            }
            
            if self.interfaceState.editState != nil {
                return .editing
            }
            if self.interfaceState.themeEditing {
                return .block("")
            }
            
            if searchMode.tag != nil {
                return .action(!searchMode.showAll ? strings().chatStateShowOtherMessages : strings().chatStateHideOtherMessages, { chatInteraction in
                    chatInteraction.update { current in
                        var search = current.searchMode
                        search.showAll = !search.showAll
                        return current.updatedSearchMode(search)
                    }
                }, nil)
            }
            
            if let peer = peer, peer.maybePremiumRequired {
                if let cachedData = cachedData as? CachedUserData, cachedData.flags.contains(.premiumRequired), accountPeer?.isPremium == false {
                    return .block(strings().chatInputPremiumRequiredState(peer.compactDisplayTitle))
                }
            }
            if chatLocation.peerId == repliesPeerId {
                return .action(notificationSettings?.isMuted ?? false ? strings().chatInputUnmute : strings().chatInputMute, { chatInteraction in
                    chatInteraction.toggleNotifications(nil)
                }, nil)
            }

            if chatMode.isSavedMessagesThread, let threadId64 = chatMode.threadId64 {
                return .action(strings().chatInputOpenChat, { chatInteraction in
                    chatInteraction.openInfo(PeerId(threadId64), true, nil, nil)
                }, nil)
            }
            
            
            if chatMode.isThreadMode, chatLocation.peerId == accountPeer?.id, let threadId64 = chatMode.threadId64 {
                return .action(strings().chatInputOpenChat, { chatInteraction in
                    chatInteraction.openInfo(PeerId(threadId64), true, nil, nil)
                }, nil)
            }
            
            switch chatMode {
            case .pinned:
                if canPinMessageInPeer {
                    return .action(strings().chatPinnedUnpinAllCountable(pinnedMessageId?.totalCount ?? 0), { chatInteraction in
                        let navigation = chatInteraction.context.bindings.rootNavigation()
                        (navigation.previousController as? ChatController)?.chatInteraction.unpinAllMessages()
                    }, nil)
                } else {
                    return .action(strings().chatPinnedDontShow, { chatInteraction in
                        let navigation = chatInteraction.context.bindings.rootNavigation()
                        (navigation.previousController as? ChatController)?.chatInteraction.unpinAllMessages()
                    }, nil)
                }
                
            default:
                break
            }
            
            if let peer = peer as? TelegramChannel {
                #if APP_STORE
                if let restrictionInfo = restrictionInfo {
                    for rule in restrictionInfo.rules {
                        if rule.platform == "ios" || rule.platform == "all" {
                            return .action(strings().chatInputClose, { chatInteraction in
                                chatInteraction.back()
                            }, nil)
                        }
                    }
                }
                #endif

                if peer.flags.contains(.isGigagroup) {
                    if peer.participationStatus == .left {
                        return .action(strings().chatInputJoin, { chatInteraction in
                            chatInteraction.joinChannel()
                        }, nil)
                    } else if peer.adminRights == nil && !peer.groupAccess.isCreator {
                        if let notificationSettings = notificationSettings {
                            return .action(notificationSettings.isMuted ? strings().chatInputUnmute : strings().chatInputMute, { chatInteraction in
                                chatInteraction.toggleNotifications(nil)
                            }, .init(icon: theme.icons.chat_gigagroup_info, action: { control in
                                tooltip(for: control, text: strings().chatGigagroupHelp)
                            }))
                        } else {
                            return .action(strings().chatInputMute, { chatInteraction in
                                chatInteraction.toggleNotifications(nil)
                            }, .init(icon: theme.icons.chat_gigagroup_info, action: { control in

                            }))
                        }
                    }

                }
                
                switch chatMode {
                case .thread:
                    if let data = threadInfo {
                        if data.isClosed, peer.adminRights == nil && !peer.flags.contains(.isCreator) && !data.isOwnedByMe {
                            return .restricted(strings().chatInputTopicClosed)
                        }
                    }
                    if peer.participationStatus == .left {
                        if peer.flags.contains(.joinToSend) || chatMode.isTopicMode {
                            return .action(strings().chatInputJoin, { chatInteraction in
                                chatInteraction.joinChannel()
                            }, nil)
                        } else {
                            return .normal
                        }
                    } else if peer.participationStatus == .kicked {
                        return .restricted(strings().chatCommentsKicked)
                    } else if peer.participationStatus == .member {
                        return .normal
                    }
                    
                case .history:
                    if peer.isForum {
                        let viewForumAsMessages = (cachedData as? CachedChannelData)?.viewForumAsMessages.knownValue
                        if viewForumAsMessages == false || viewForumAsMessages == nil {
                            if interfaceState.replyMessage == nil {
                                return .restricted(strings().chatInputReplyToAnswer)
                            }
                        }
                    }
                default:
                    break
                }
                
                
                
                if peer.participationStatus == .left {
                    return .action(strings().chatInputJoin, { chatInteraction in
                        chatInteraction.joinChannel()
                    }, nil)
                } else if peer.participationStatus == .kicked {
                    return .action(strings().chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    }, nil)
                } else if !peer.canSendMessage(chatMode.isThreadMode), let notificationSettings = notificationSettings, peer.isChannel {
                    return .action(notificationSettings.isMuted ? strings().chatInputUnmute : strings().chatInputMute, { chatInteraction in
                        chatInteraction.toggleNotifications(nil)
                    }, nil)
                }
            } else if let peer = peer as? TelegramGroup {
                if  peer.membership == .Left {
                    return .action(strings().chatInputReturn,{ chatInteraction in
                        chatInteraction.returnGroup()
                    }, nil)
                } else if peer.membership == .Removed {
                    return .action(strings().chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    }, nil)
                }
            } else if let peer = peer as? TelegramSecretChat, let mainPeer = mainPeer {
                
                switch peer.embeddedState {
                case .terminated:
                    return .action(strings().chatInputDelete, { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    }, nil)
                case .handshake:
                    return .restricted(strings().chatInputSecretChatWaitingToUserOnline(mainPeer.compactDisplayTitle))
                default:
                    break
                }
            }
            
            if let peer = peer, !peer.canSendMessage(chatMode.isThreadMode), let notificationSettings = notificationSettings, peer.isChannel {
                return .action(notificationSettings.isMuted ? strings().chatInputUnmute : strings().chatInputMute, { chatInteraction in
                    chatInteraction.toggleNotifications(nil)
                }, nil)
            }
            
            if let peer = peer as? TelegramChannel, !peer.hasPermission(.sendSomething) {
                if let text = permissionText(from: peer, for: .banSendText) {
                    return .restricted(text)
                }
            }
            
            if let blocked = isBlocked, blocked {
                
                if let peer = peer, peer.isBot {
                    return .action(strings().chatInputRestart, { chatInteraction in
                        chatInteraction.unblock()
                        chatInteraction.startBot()
                    }, nil)
                }
                
                return .action(strings().chatInputUnblock, { chatInteraction in
                    chatInteraction.unblock()
                }, nil)
            }
            
            if let peer = peer as? TelegramUser {
                if peer.botInfo != nil, let historyCount = historyCount, historyCount == 0 {
                    return .botStart(strings().chatInputStartBot, { chatInteraction in
                        chatInteraction.startBot()
                    })
                }
            }
           
            
            return .normal
        } else {
            return .selecting
        }
    }
    
    var canScheduleWhenOnline: Bool {
        if let presence = self.presence {
            switch presence.status {
            case .present:
                return true
            default:
                return false
            }
        }
        return false
    }

    var isKeyboardShown:Bool {
        if let keyboard = keyboardButtonsMessage, let attribute = keyboard.replyMarkup {
            return interfaceState.messageActionsState.closedButtonKeyboardMessageId != keyboard.id && attribute.hasButtons && state == .normal

        }
        return false
    }
    
    var isShowSidebar: Bool {
        if let sidebarEnabled = sidebarEnabled, let peer = peer, let sidebarShown = sidebarShown, let layout = layout {
            return sidebarEnabled && peer.canSendMessage(chatMode.isThreadMode) && sidebarShown && layout == .dual
        }
        return false
    }
    
    var slowModeMultipleLocked: Bool {
        if let _ = self.slowMode {
            
            var keys:[Int64:Int64] = [:]
            var forwardMessages:[Message] = []
            for message in self.interfaceState.forwardMessages {
                if let groupingKey = message.groupingKey {
                    if keys[groupingKey] == nil {
                        keys[groupingKey] = groupingKey
                        forwardMessages.append(message)
                    }
                } else {
                    forwardMessages.append(message)
                }
            }
            if forwardMessages.count > 1 || (!effectiveInput.inputText.isEmpty && forwardMessages.count == 1) {
                return true
            } else if effectiveInput.inputText.length > 4096 {
                return true
            }
        }
        return false
    }
    
    var slowModeErrorText: String? {
        if let slowMode = self.slowMode, slowMode.hasLocked {
            return slowMode.errorText
        } else if slowModeMultipleLocked {
            if effectiveInput.inputText.length > 4096 {
                return strings().slowModeTooLongError
            }
            return strings().slowModeForwardCommentError
        } else {
            return nil
        }
    }
    
    var abilityToSend:Bool {
        if state == .normal {
            if let slowMode = self.slowMode {
                if slowMode.hasLocked {
                    return false
                } else if self.slowModeMultipleLocked {
                    return false
                }
            }
            return (!effectiveInput.inputText.isEmpty || !interfaceState.forwardMessageIds.isEmpty)
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
    
    
    
    var effectiveInput:ChatTextInputState {
        if let editState = interfaceState.editState {
            return editState.inputState
        } else {
            return interfaceState.inputState
        }
    }
    
    init(chatLocation: ChatLocation, chatMode: ChatMode) {
        self.interfaceState = ChatInterfaceState()
        self.peer = nil
        self.notificationSettings = nil
        self.inputQueryResult = nil
        self.keyboardButtonsMessage = nil
        self.initialAction = nil
        self.historyCount = 0
        self.searchMode = .init(inSearch: false)
        self.recordingState = nil
        self.isBlocked = nil
        self.peerStatus = nil
        self.pinnedMessageId = nil
        self.urlPreview = nil
        self.selectionState = nil
        self.sidebarEnabled = nil
        self.sidebarShown = nil
        self.layout = nil
        self.canAddContact = nil
        self.isEmojiSection = FastSettings.entertainmentState == .emoji
        self.chatLocation = chatLocation
        self.chatMode = chatMode
        self.canInvokeBasicActions = (delete: false, forward: false)
        self.isNotAccessible = false
        self.restrictionInfo = nil
        self.mainPeer = nil
        self.limitConfiguration = LimitsConfiguration.defaultValue
        self.discussionGroupId = .unknown
        self.slowMode = nil
        self.hasScheduled = false
        self.failedMessageIds = Set()
        self.hidePinnedMessage = false
        self.canPinMessage = false
        self.tempPinnedMaxId = nil
        self.groupCall = nil
        self.messageSecretTimeout = nil
        self.reportMode = nil
        self.botMenu = nil
        self.inviteRequestsPending = nil
        self.inviteRequestsPendingPeers = nil
        self.currentSendAsPeerId = nil
        self.sendAsPeers = nil
        self.allowedReactions = nil
        self.attachItems = []
        self.cachedData = nil
        self.threadInfo = nil
        self.translateState = nil
        self.presence = nil
        self.savedMessageTags = nil
        self.accountPeer = nil
        self.displaySavedChatsAsTopics = false
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, notificationSettings:TelegramPeerNotificationSettings?, inputQueryResult: ChatPresentationInputQueryResult?, keyboardButtonsMessage:Message?, initialAction:ChatInitialAction?, historyCount:Int?, searchMode: ChatSearchModeState, recordingState: ChatRecordingState?, isBlocked:Bool?, peerStatus: ChatPeerStatus?, pinnedMessageId:ChatPinnedMessage?, urlPreview: (String, TelegramMediaWebpage)?, selectionState: ChatInterfaceSelectionState?, sidebarEnabled: Bool?, sidebarShown: Bool?, layout:SplitViewState?, canAddContact:Bool?, isEmojiSection: Bool, chatLocation: ChatLocation, chatMode: ChatMode, canInvokeBasicActions: (delete: Bool, forward: Bool), isNotAccessible: Bool, restrictionInfo: PeerAccessRestrictionInfo?, mainPeer: Peer?, limitConfiguration: LimitsConfiguration, discussionGroupId: CachedChannelData.LinkedDiscussionPeerId, slowMode: SlowMode?, hasScheduled: Bool, failedMessageIds: Set<MessageId>, hidePinnedMessage: Bool, canPinMessage: Bool, tempPinnedMaxId: MessageId?, groupCall: ChatActiveGroupCallInfo?, messageSecretTimeout: CachedPeerAutoremoveTimeout?, reportMode: ReportReasonValue?, botMenu: BotMenu?, inviteRequestsPending: Int32?, inviteRequestsPendingPeers: [PeerInvitationImportersState.Importer]?, currentSendAsPeerId: PeerId?, sendAsPeers:[SendAsPeer]?, allowedReactions:PeerAllowedReactions?, attachItems: [AttachMenuBot], cachedData: CachedPeerData?, threadInfo: MessageHistoryThreadData?, translateState: TranslateState?, presence: TelegramUserPresence?, savedMessageTags: SavedMessageTagsValue?, accountPeer: Peer?, displaySavedChatsAsTopics: Bool) {
        self.interfaceState = interfaceState
        self.peer = peer
        self.notificationSettings = notificationSettings
        self.inputQueryResult = inputQueryResult
        self.keyboardButtonsMessage = keyboardButtonsMessage
        self.initialAction = initialAction
        self.historyCount = historyCount
        self.searchMode = searchMode
        self.recordingState = recordingState
        self.isBlocked = isBlocked
        self.peerStatus = peerStatus
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
        self.mainPeer = mainPeer
        self.limitConfiguration = limitConfiguration
        self.discussionGroupId = discussionGroupId
        self.slowMode = slowMode
        self.hasScheduled = hasScheduled
        self.failedMessageIds = failedMessageIds
        self.chatMode = chatMode
        self.hidePinnedMessage = hidePinnedMessage
        self.canPinMessage = canPinMessage
        self.tempPinnedMaxId = tempPinnedMaxId
        self.groupCall = groupCall
        self.messageSecretTimeout = messageSecretTimeout
        self.reportMode = reportMode
        self.botMenu = botMenu
        self.inviteRequestsPending = inviteRequestsPending
        self.inviteRequestsPendingPeers = inviteRequestsPendingPeers
        self.currentSendAsPeerId = currentSendAsPeerId
        self.sendAsPeers = sendAsPeers
        self.allowedReactions = allowedReactions
        self.attachItems = attachItems
        self.cachedData = cachedData
        self.threadInfo = threadInfo
        self.translateState = translateState
        self.presence = presence
        self.savedMessageTags = savedMessageTags
        self.accountPeer = accountPeer
        self.displaySavedChatsAsTopics = displaySavedChatsAsTopics
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
        if lhs.translateState != rhs.translateState {
            return false
        }
        
        if let lhsPeer = lhs.mainPeer, let rhsPeer = rhs.mainPeer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.mainPeer == nil) != (rhs.mainPeer == nil) {
            return false
        }
        if let lhsPeer = lhs.accountPeer, let rhsPeer = rhs.accountPeer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.accountPeer == nil) != (rhs.accountPeer == nil) {
            return false
        }
        if lhs.tempPinnedMaxId != rhs.tempPinnedMaxId {
            return false
        }
        if lhs.inviteRequestsPending != rhs.inviteRequestsPending {
            return false
        }
        if lhs.inviteRequestsPendingPeers != rhs.inviteRequestsPendingPeers {
            return false
        }
        if lhs.restrictionInfo != rhs.restrictionInfo {
            return false
        }
        if lhs.limitConfiguration != rhs.limitConfiguration {
            return false
        }
        if lhs.botMenu != rhs.botMenu {
            return false
        }
        if lhs.chatLocation != rhs.chatLocation {
            return false
        }
        if lhs.hasScheduled != rhs.hasScheduled {
            return false
        }
        if lhs.chatMode != rhs.chatMode {
            return false
        }
        if lhs.canPinMessage != rhs.canPinMessage {
            return false
        }
        if lhs.hidePinnedMessage != rhs.hidePinnedMessage {
            return false
        }
        if lhs.state != rhs.state {
            return false
        }
        if lhs.slowMode != rhs.slowMode {
            return false
        }
        if lhs.searchMode != rhs.searchMode {
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
        if lhs.reportMode != rhs.reportMode {
            return false
        }
        
        if lhs.recordingState != rhs.recordingState {
            return false
        }
        if lhs.currentSendAsPeerId != rhs.currentSendAsPeerId {
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
        
        if lhs.peerStatus != rhs.peerStatus {
            return false
        }
        if lhs.isNotAccessible != rhs.isNotAccessible {
            return false
        }
        
        if lhs.selectionState != rhs.selectionState {
            return false
        }
        if lhs.sendAsPeers != rhs.sendAsPeers {
            return false
        }
        if lhs.groupCall != rhs.groupCall {
            return false
        }
        if lhs.messageSecretTimeout != rhs.messageSecretTimeout {
            return false
        }
        
        if lhs.pinnedMessageId != rhs.pinnedMessageId {
            return false
        }
        if lhs.isEmojiSection != rhs.isEmojiSection {
            return false
        }
        if lhs.failedMessageIds != rhs.failedMessageIds {
            return false
        }
        if lhs.allowedReactions != rhs.allowedReactions {
            return false
        }
        if lhs.savedMessageTags != rhs.savedMessageTags {
            return false
        }
        
        if lhs.displaySavedChatsAsTopics != rhs.displaySavedChatsAsTopics {
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
        
        if lhs.effectiveInput != rhs.effectiveInput {
            if lhs.inputContext != rhs.inputContext {
                return false
            }
        }
        
        if lhs.canInvokeBasicActions != rhs.canInvokeBasicActions {
            return false
        }
        
        if let lhsCachedData = lhs.cachedData, let rhsCachedData = rhs.cachedData {
            if !lhsCachedData.isEqual(to: rhsCachedData) {
                return false
            }
        } else if (lhs.cachedData != nil) != (rhs.cachedData != nil) {
            return false
        }
        
        if lhs.threadInfo != rhs.threadInfo {
            return false
        }
        if lhs.presence != rhs.presence {
            return false
        }
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
        
    }

    func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        let interface = ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:message, initialAction:self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
        
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
        if let peer = peer as? TelegramChannel, let info = peer.restrictionInfo {
            restrictionInfo = info
        }
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedMainPeer(_ mainPeer: Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, mainPeer: mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedNotificationSettings(_ notificationSettings:TelegramPeerNotificationSettings?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    
    
    func updatedHistoryCount(_ historyCount:Int?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedSearchMode(_ searchMode: ChatSearchModeState) -> ChatPresentationInterfaceState {


        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, searchMode: searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: f(self.inputQueryResult), keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedInitialAction(_ initialAction:ChatInitialAction?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    
    func withRecordingState(_ state:ChatRecordingState) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: state, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withoutRecordingState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: nil, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedBlocked(_ blocked:Bool) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: blocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedPinnedMessageId(_ pinnedMessageId:ChatPinnedMessage?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    
    func withUpdatedPeerStatusSettings(_ peerStatus:ChatPeerStatus?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
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
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
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
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState?.withUpdatedSelectedIds(selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedSelectedMessages(_ ids:Set<MessageId>) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState?.withUpdatedSelectedIds(ids), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        let isSelected: Bool = selectedIds.contains(messageId)
        if isSelected {
            let _ = selectedIds.remove(messageId)
        } else {
            if selectedIds.count < 100 {
                selectedIds.insert(messageId)
            } else {
                NSSound.beep()
            }
        }
        
        var selectionState: ChatInterfaceSelectionState = self.selectionState?.withUpdatedSelectedIds(selectedIds) ?? ChatInterfaceSelectionState(selectedIds: selectedIds, lastSelectedId: nil)
        
        if let event = NSApp.currentEvent {
            if !event.modifierFlags.contains(.shift) {
                if !isSelected {
                    selectionState = selectionState.withUpdatedLastSelected(messageId)
                } else {
                    var foundBestOption: Bool = false
                    for id in selectedIds {
                        if id > messageId {
                            selectionState = selectionState.withUpdatedLastSelected(id)
                            foundBestOption = true
                            break
                        }
                    }
                    if !foundBestOption {
                        selectionState = selectionState.withUpdatedLastSelected(messageId)
                    }
                }
            }
        }
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withRemovedSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        let _ = selectedIds.remove(messageId)
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState?.withUpdatedSelectedIds(selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    
    func withoutSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: nil, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: [], lastSelectedId: nil), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withToggledSidebarEnabled(_ enabled: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: enabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withToggledSidebarShown(_ shown: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: shown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedLayout(_ layout: SplitViewState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withoutInitialAction() -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: nil, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedContactAdding(_ canAddContact:Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedIsEmojiSection(_ isEmojiSection:Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedBasicActions(_ canInvokeBasicActions:(delete: Bool, forward: Bool)) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    
    func withUpdatedIsNotAccessible(_ isNotAccessible:Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedRestrictionInfo(_ restrictionInfo:PeerAccessRestrictionInfo?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: self.limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedLimitConfiguration(_ limitConfiguration:LimitsConfiguration) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedDiscussionGroupId(_ discussionGroupId: CachedChannelData.LinkedDiscussionPeerId) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func updateSlowMode(_ f: (SlowMode?)->SlowMode?) -> ChatPresentationInterfaceState {
        
        let updated = f(self.slowMode)
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: self.discussionGroupId, slowMode: updated, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func withUpdatedHasScheduled(_ hasScheduled: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func withUpdatedFailedMessageIds(_ failedMessageIds: Set<MessageId>) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedHidePinnedMessage(_ hidePinnedMessage: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedCanPinMessage(_ canPinMessage: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedTempPinnedMaxId(_ tempPinnedMaxId: MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func updatedGroupCall(_ f: (ChatActiveGroupCallInfo?)->ChatActiveGroupCallInfo?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: f(self.groupCall), messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withUpdatedMessageSecretTimeout(_ messageSecretTimeout: CachedPeerAutoremoveTimeout?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withUpdatedRepotMode(_ reportMode: ReportReasonValue?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedInviteRequestsPending(_ inviteRequestsPending: Int32?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func withUpdatedInviteRequestsPendingPeers(_ inviteRequestsPendingPeers: [PeerInvitationImportersState.Importer]?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedCurrentSendAsPeerId(_ currentSendAsPeerId: PeerId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withUpdatedSendAsPeers(_ sendAsPeers: [SendAsPeer]?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedAllowedReactions(_ reactions: PeerAllowedReactions?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: reactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }


    func updateBotMenu(_ f:(BotMenu?)->BotMenu?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: f(self.botMenu), inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withUpdatedAttachItems(_ attachItems: [AttachMenuBot]) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedCachedData(_ cachedData: CachedPeerData?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedThreadInfo(_ threadInfo: MessageHistoryThreadData?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    
    func withUpdatedTranslateState(_ translateState: TranslateState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }

    func withUpdatedPresence(_ presence: TelegramUserPresence?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func withUpdatedSavedMessageTags(_ savedMessageTags: SavedMessageTagsValue?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    
    func withUpdatedAccountPeer(_ accountPeer: Peer?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: accountPeer, displaySavedChatsAsTopics: self.displaySavedChatsAsTopics)
    }
    func withUpdatedDisplaySavedChatsAsTopics(_ displaySavedChatsAsTopics: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, searchMode: self.searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, peerStatus: self.peerStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation, chatMode: self.chatMode, canInvokeBasicActions: self.canInvokeBasicActions, isNotAccessible: self.isNotAccessible, restrictionInfo: self.restrictionInfo, mainPeer: self.mainPeer, limitConfiguration: limitConfiguration, discussionGroupId: discussionGroupId, slowMode: self.slowMode, hasScheduled: self.hasScheduled, failedMessageIds: self.failedMessageIds, hidePinnedMessage: self.hidePinnedMessage, canPinMessage: self.canPinMessage, tempPinnedMaxId: self.tempPinnedMaxId, groupCall: self.groupCall, messageSecretTimeout: self.messageSecretTimeout, reportMode: self.reportMode, botMenu: self.botMenu, inviteRequestsPending: self.inviteRequestsPending, inviteRequestsPendingPeers: self.inviteRequestsPendingPeers, currentSendAsPeerId: self.currentSendAsPeerId, sendAsPeers: self.sendAsPeers, allowedReactions: self.allowedReactions, attachItems: self.attachItems, cachedData: self.cachedData, threadInfo: self.threadInfo, translateState: self.translateState, presence: self.presence, savedMessageTags: self.savedMessageTags, accountPeer: self.accountPeer, displaySavedChatsAsTopics: displaySavedChatsAsTopics)
    }
}
