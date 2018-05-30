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




enum ChatPresentationInputQuery: Equatable {
    case none
    case hashtag(String)
    case mention(query: String, includeRecent: Bool)
    case command(String)
    case contextRequest(addressName: String, query: String)
    case emoji(String)
    case stickers(String)
    static func ==(lhs: ChatPresentationInputQuery, rhs: ChatPresentationInputQuery) -> Bool {
        switch lhs {
        case let .hashtag(query):
            if case .hashtag(query) = rhs {
                return true
            } else {
                return false
            }
        case let .stickers(query):
            if case .stickers(query) = rhs {
                return true
            } else {
                return false
            }
        case let .emoji(query):
            if case .emoji(query) = rhs {
                return true
            } else {
                return false
            }
        case let .mention(query, includeInline):
            if case .mention(query, includeInline) = rhs {
                return true
            } else {
                return false
            }
        case let .command(query):
            if case .command(query) = rhs {
                return true
            } else {
                return false
            }
        case let .contextRequest(addressName, query):
            if case .contextRequest(addressName, query) = rhs {
                return true
            } else {
                return false
            }
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

enum ChatPresentationInputQueryResult: Equatable {
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case stickers([FoundStickerItem])
    case emoji([EmojiClue])
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
        case let .emoji(lhsResults):
            if case let .emoji(rhsResults) = rhs {
                return lhsResults == rhsResults
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

func ==(lhs: ChatRecordingStatus, rhs: ChatRecordingStatus) -> Bool {
    switch lhs {
    case .paused:
        if case .paused = rhs {
            return true
        } else {
            return false
        }
    case .recording(let duration):
        if case .recording(duration) = rhs {
            return true
        } else {
            return false
        }
    }
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
    let chatLocation: ChatLocation
    let isSearchMode:Bool
    let notificationSettings: TelegramPeerNotificationSettings?
    let inputQueryResult: ChatPresentationInputQueryResult?
    let keyboardButtonsMessage: Message?
    let initialAction:ChatInitialAction?
    let historyCount:Int?
    let isBlocked:Bool?
    let recordingState:ChatRecordingState?
    let reportStatus:PeerReportStatus
    let pinnedMessageId:MessageId?
    let urlPreview: (String, TelegramMediaWebpage)?
    let selectionState: ChatInterfaceSelectionState?
    
    let sidebarEnabled:Bool?
    let sidebarShown:Bool?
    let layout:SplitViewState?
    
    let canAddContact:Bool?
    let isEmojiSection: Bool
    
    
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
            
            switch chatLocation {
            case .group:
                return .action(L10n.chatInputShowNext, { chatInteraction in
                    chatInteraction.showNextPost()
                })
            default:
                break
            }
            
            if let peer = peer as? TelegramChannel {
                if peer.participationStatus == .left {
                    return .action(tr(L10n.chatInputJoin), { chatInteraction in
                        chatInteraction.joinChannel()
                    })
                } else if peer.participationStatus == .kicked {
                    return .action(tr(L10n.chatInputDelete), { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                } else if peer.hasBannedRights(.banSendMessages), let bannedRights = peer.bannedRights {
                    
                    return .restricted(bannedRights.untilDate != Int32.max ? tr(L10n.channelPersmissionDeniedSendMessagesUntil(bannedRights.formattedUntilDate)) : tr(L10n.channelPersmissionDeniedSendMessagesForever))
                } else if !peer.canSendMessage, let notificationSettings = notificationSettings {
                    return .action(notificationSettings.isMuted ? tr(L10n.chatInputUnmute) : tr(L10n.chatInputMute), { chatInteraction in
                        chatInteraction.toggleNotifications()
                    })
                }
            } else if let peer = peer as? TelegramGroup {
                if  peer.membership == .Left {
                    return .action(tr(L10n.chatInputReturn),{ chatInteraction in
                        chatInteraction.returnGroup()
                    })
                } else if peer.membership == .Removed {
                    return .action(tr(L10n.chatInputDelete), { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                }
            } else if let peer = peer as? TelegramSecretChat {
                
                switch peer.embeddedState {
                case .terminated:
                    return .action(tr(L10n.chatInputDelete), { chatInteraction in
                        chatInteraction.removeAndCloseChat()
                    })
                case .handshake:
                    return .action(tr(L10n.chatInputSecretChatWaitingToOnline), { chatInteraction in
                        
                    })
                default:
                    break
                }
            }
            
            if let blocked = isBlocked, blocked {
                return .action(tr(L10n.chatInputUnblock), { chatInteraction in
                    chatInteraction.unblock()
                })
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
    let maxShortInput:Int32 = 200
    
    var maxInputCharacters:Int32 {
        if state == .normal {
            return maxInput
        } else if let editState = interfaceState.editState {
            if editState.message.media.count == 0 {
                return maxInput
            } else {
                for media in editState.message.media {
                    if !(media is TelegramMediaWebpage) {
                        return maxShortInput
                    }
                }
                return maxInput
            }
        }
        
        return 0
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
        self.isSearchMode = false
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
    }
    
    init(interfaceState: ChatInterfaceState, peer: Peer?, notificationSettings:TelegramPeerNotificationSettings?, inputQueryResult: ChatPresentationInputQueryResult?, keyboardButtonsMessage:Message?, initialAction:ChatInitialAction?, historyCount:Int?, isSearchMode:Bool, recordingState: ChatRecordingState?, isBlocked:Bool?, reportStatus: PeerReportStatus, pinnedMessageId:MessageId?, urlPreview: (String, TelegramMediaWebpage)?, selectionState: ChatInterfaceSelectionState?, sidebarEnabled: Bool?, sidebarShown: Bool?, layout:SplitViewState?, canAddContact:Bool?, isEmojiSection: Bool, chatLocation: ChatLocation) {
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
    }
    
    static func ==(lhs: ChatPresentationInterfaceState, rhs: ChatPresentationInterfaceState) -> Bool {
        if lhs.interfaceState != rhs.interfaceState {
            return false
        }
        if let lhsPeer = lhs.peer, let rhsPeer = rhs.peer {
            if !lhsPeer.isEqual(rhsPeer) {
                return false
            }
        } else if (lhs.peer == nil) != (rhs.peer == nil) {
            return false
        }
        
        if lhs.chatLocation != rhs.chatLocation {
            return false
        }
        
        if lhs.state != rhs.state {
            return false
        }
        
        if lhs.isSearchMode != rhs.isSearchMode {
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
            if !lhsUrlPreview.1.isEqual(rhsUrlPreview.1) {
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
        
        return true
    }
    
    func updatedInterfaceState(_ f: (ChatInterfaceState) -> ChatInterfaceState) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: f(self.interfaceState), peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
        
    }
    
    func updatedKeyboardButtonsMessage(_ message: Message?) -> ChatPresentationInterfaceState {
        let interface = ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:message, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
        
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
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: f(self.peer), notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func updatedNotificationSettings(_ notificationSettings:TelegramPeerNotificationSettings?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    
    
    func updatedHistoryCount(_ historyCount:Int?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func updatedSearchMode(_ searchMode: Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer:self.peer, notificationSettings: notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: historyCount, isSearchMode: searchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func updatedInputQueryResult(_ f: (ChatPresentationInputQueryResult?) -> ChatPresentationInputQueryResult?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: f(self.inputQueryResult), keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func updatedInitialAction(_ initialAction:ChatInitialAction?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    
    func withRecordingState(_ state:ChatRecordingState) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: self.initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: state, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withoutRecordingState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: nil, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedBlocked(_ blocked:Bool) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: blocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedPinnedMessageId(_ messageId:MessageId?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: messageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedReportStatus(_ reportStatus:PeerReportStatus) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
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
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
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
        selectedIds.insert(messageId)
        
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedSelectedMessages(_ ids:Set<MessageId>) -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: ids), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withToggledSelectedMessage(_ messageId: MessageId) -> ChatPresentationInterfaceState {
        var selectedIds = Set<MessageId>()
        if let selectionState = self.selectionState {
            selectedIds.formUnion(selectionState.selectedIds)
        }
        if selectedIds.contains(messageId) {
            let _ = selectedIds.remove(messageId)
        } else {
            selectedIds.insert(messageId)
        }
        
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: selectedIds), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withoutSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState:nil, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withSelectionState() -> ChatPresentationInterfaceState {
         return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: ChatInterfaceSelectionState(selectedIds: []), sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }

    func withToggledSidebarEnabled(_ enabled: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: enabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withToggledSidebarShown(_ shown: Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: shown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedLayout(_ layout: SplitViewState?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withoutInitialAction() -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction: nil, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedContactAdding(_ canAddContact:Bool?) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: canAddContact, isEmojiSection: self.isEmojiSection, chatLocation: self.chatLocation)
    }
    
    func withUpdatedIsEmojiSection(_ isEmojiSection:Bool) -> ChatPresentationInterfaceState {
        return ChatPresentationInterfaceState(interfaceState: self.interfaceState, peer: self.peer, notificationSettings: self.notificationSettings, inputQueryResult: self.inputQueryResult, keyboardButtonsMessage:self.keyboardButtonsMessage, initialAction:initialAction, historyCount: self.historyCount, isSearchMode: self.isSearchMode, recordingState: self.recordingState, isBlocked: self.isBlocked, reportStatus: self.reportStatus, pinnedMessageId: self.pinnedMessageId, urlPreview: self.urlPreview, selectionState: self.selectionState, sidebarEnabled: self.sidebarEnabled, sidebarShown: self.sidebarShown, layout: self.layout, canAddContact: self.canAddContact, isEmojiSection: isEmojiSection, chatLocation: self.chatLocation)
    }

}
