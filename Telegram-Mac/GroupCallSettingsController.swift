//
//  GroupCallSettingsController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit
import TelegramCore
import InAppSettings
import Postbox
import HotKey
import ColorPalette

private final class Arguments {
    let sharedContext: SharedAccountContext
    let toggleInputAudioDevice:(String?)->Void
    let toggleOutputAudioDevice:(String?)->Void
    let toggleInputVideoDevice:(String?)->Void
    let finishCall:()->Void
    let updateDefaultParticipantsAreMuted: (Bool)->Void
    let updateSettings: (@escaping(VoiceCallSettings)->VoiceCallSettings)->Void
    let checkPermission:()->Void
    let showTooltip:(String)->Void
    let switchAccount:(PeerId)->Void
    let startRecording:()->Void
    let stopRecording:()->Void
    let resetLink:()->Void
    let setNoiseSuppression:(Bool)->Void
    let reduceMotions:(Bool)->Void
    let selectVideoRecordOrientation:(GroupCallSettingsState.VideoOrientation)->Void
    let toggleRecordVideo: ()->Void
    let copyToClipboard:(String)->Void
    let toggleHideKey:()->Void
    let revokeStreamKey: ()->Void
    init(sharedContext: SharedAccountContext,
         toggleInputAudioDevice: @escaping(String?)->Void,
         toggleOutputAudioDevice:@escaping(String?)->Void,
         toggleInputVideoDevice:@escaping(String?)->Void,
         finishCall:@escaping()->Void,
         updateDefaultParticipantsAreMuted: @escaping(Bool)->Void,
         updateSettings:  @escaping(@escaping(VoiceCallSettings)->VoiceCallSettings)->Void,
         checkPermission:@escaping()->Void,
         showTooltip: @escaping(String)->Void,
         switchAccount: @escaping(PeerId)->Void,
         startRecording: @escaping()->Void,
         stopRecording: @escaping()->Void,
         resetLink: @escaping()->Void,
         setNoiseSuppression:@escaping(Bool)->Void,
         reduceMotions:@escaping(Bool)->Void,
         selectVideoRecordOrientation:@escaping(GroupCallSettingsState.VideoOrientation)->Void,
         toggleRecordVideo: @escaping()->Void,
         copyToClipboard:@escaping(String)->Void,
         toggleHideKey:@escaping()->Void,
         revokeStreamKey: @escaping()->Void) {
        self.sharedContext = sharedContext
        self.toggleInputAudioDevice = toggleInputAudioDevice
        self.toggleOutputAudioDevice = toggleOutputAudioDevice
        self.toggleInputVideoDevice = toggleInputVideoDevice
        self.finishCall = finishCall
        self.updateDefaultParticipantsAreMuted = updateDefaultParticipantsAreMuted
        self.updateSettings = updateSettings
        self.checkPermission = checkPermission
        self.showTooltip = showTooltip
        self.switchAccount = switchAccount
        self.startRecording = startRecording
        self.stopRecording = stopRecording
        self.resetLink = resetLink
        self.setNoiseSuppression = setNoiseSuppression
        self.reduceMotions = reduceMotions
        self.selectVideoRecordOrientation = selectVideoRecordOrientation
        self.toggleRecordVideo = toggleRecordVideo
        self.copyToClipboard = copyToClipboard
        self.toggleHideKey = toggleHideKey
        self.revokeStreamKey = revokeStreamKey
    }
}

final class GroupCallSettingsView : View {
    fileprivate let tableView:TableView = TableView()
    private let titleContainer = View()
    fileprivate let backButton: ImageButton = ImageButton()
    private let title: TextView = TextView()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(titleContainer)
        titleContainer.addSubview(backButton)
        titleContainer.addSubview(title)
        let backColor = NSColor(srgbRed: 175, green: 170, blue: 172, alpha: 1.0)
        
        title.userInteractionEnabled = false
        title.isSelectable = false
        
        let icon = #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(backColor)
        let activeIcon = #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(backColor.withAlphaComponent(0.7))
        backButton.set(image: icon, for: .Normal)
        backButton.set(image: activeIcon, for: .Highlight)

        _ = backButton.sizeToFit(.zero, NSMakeSize(24, 24), thatFit: true)
        
        let layout = TextViewLayout.init(.initialize(string: strings().voiceChatSettingsTitle, color: GroupCallTheme.customTheme.textColor, font: .medium(.header)))
        layout.measure(width: frame.width - 200)
        title.update(layout)
        tableView.getBackgroundColor = {
            GroupCallTheme.windowBackground.withAlphaComponent(1)
        }
        updateLocalizationAndTheme(theme: theme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
      //  super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = GroupCallTheme.windowBackground
        titleContainer.backgroundColor = GroupCallTheme.windowBackground
        title.backgroundColor = GroupCallTheme.windowBackground
    }
    
    override func layout() {
        super.layout()
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 54)
        tableView.frame = NSMakeRect(0, titleContainer.frame.maxY, frame.width, frame.height - titleContainer.frame.height)
        backButton.centerY(x: 90)
        let f = titleContainer.focus(title.frame.size)
        title.setFrameOrigin(NSMakePoint(max(126, f.minX), f.minY))
    }
}


struct GroupCallSettingsState : Equatable {
    
    
    
    enum VideoOrientation : Equatable {
        case landscape
        case portrait
        
        var rawValue: Bool {
            switch self {
            case .portrait:
                return true
            case .landscape:
                return false
            }
        }
    }
    
    var hasPermission: Bool?
    var title: String?
    var displayAsList: [FoundPeer]?
    var recordName: String?
    var recordVideo: Bool
    var videoOrientation: VideoOrientation
    var hideKey: Bool = true
    var credentials: GroupCallStreamCredentials?
}

private let _id_leave_chat = InputDataIdentifier.init("_id_leave_chat")
private let _id_reset_link = InputDataIdentifier.init("_id_reset_link")
private let _id_input_audio = InputDataIdentifier("_id_input_audio")
private let _id_output_audio = InputDataIdentifier("_id_output_audio")
private let _id_micro = InputDataIdentifier("_id_micro")
private let _id_speak_admin_only = InputDataIdentifier("_id_speak_admin_only")
private let _id_speak_all_members = InputDataIdentifier("_id_speak_all_members")
private let _id_input_mode_always = InputDataIdentifier("_id_input_mode_always")
private let _id_input_mode_ptt = InputDataIdentifier("_id_input_mode_ptt")
private let _id_ptt = InputDataIdentifier("_id_ptt")
private let _id_input_mode_ptt_se = InputDataIdentifier("_id_input_mode_ptt_se")
private let _id_input_mode_toggle = InputDataIdentifier("_id_input_mode_toggle")
private let _id_noise_suppression =  InputDataIdentifier("_id_noise_suppression")


private let _id_server_url = InputDataIdentifier("_id_server_url")
private let _id_stream_key = InputDataIdentifier("_id_stream_key")
private let _id_revoke_stream_key = InputDataIdentifier("_id_revoke_stream_key")

private let _id_input_chat_title = InputDataIdentifier("_id_input_chat_title")
private let _id_input_record_title = InputDataIdentifier("_id_input_record_title")

private let _id_listening_link = InputDataIdentifier("_id_listening_link")
private let _id_speaking_link = InputDataIdentifier("_id_speaking_link")

private let _id_reduce_motion = InputDataIdentifier("_id_reduce_motion")

private let _id_record_video_toggle = InputDataIdentifier("_id_record_video_toggle")

private func _id_peer(_ id:PeerId) -> InputDataIdentifier {
    return InputDataIdentifier("_id_peer_\(id.toInt64())")
}

private func groupCallSettingsEntries(callState: GroupCallUIState, devices: IODevices, uiState: GroupCallSettingsState, settings: VoiceCallSettings, context: AccountContext, peer: Peer, accountPeer: Peer, joinAsPeerId: PeerId, arguments: Arguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    let theme = GroupCallTheme.customTheme

    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    let state = callState.state
    
    
    
    if state.canManageCall {
//        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
//        index += 1

        entries.append(.input(sectionId: sectionId, index: index, value: .string(uiState.title), error: nil, identifier: _id_input_chat_title, mode: .plain, data: .init(viewType: .singleItem, pasteFilter: nil, customTheme: theme), placeholder: nil, inputPlaceholder: strings().voiceChatSettingsTitlePlaceholder, filter: { $0 }, limit: 40))
        index += 1

    }
    
        
    if let list = uiState.displayAsList {
        
        if !list.isEmpty, !state.isStream {
            
            if case .sectionId = entries.last {
                
            } else {
                entries.append(.sectionId(sectionId, type: .customModern(20)))
                sectionId += 1
            }
            
            struct Tuple : Equatable {
                let peer: FoundPeer
                let viewType: GeneralViewType
                let selected: Bool
                let status: String?
            }            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsDisplayAsTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
            index += 1
            
            let tuple = Tuple(peer: FoundPeer(peer: accountPeer, subscribers: nil), viewType: uiState.displayAsList == nil || uiState.displayAsList?.isEmpty == false ? .firstItem : .singleItem, selected: accountPeer.id == joinAsPeerId, status: strings().voiceChatSettingsDisplayAsPersonalAccount)
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("self"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: context.account, context: context, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.title), foregroundColor: theme.textColor, highlightColor: .white), statusStyle: ControlStyle(foregroundColor: theme.grayTextColor), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                    arguments.switchAccount(tuple.peer.peer.id)
                }, customTheme: theme)
            }))
            index += 1
            
            for peer in list {
                
                var status: String?
                if let subscribers = peer.subscribers {
                    if peer.peer.isChannel {
                        status = strings().voiceChatJoinAsChannelCountable(Int(subscribers))
                    } else if peer.peer.isSupergroup || peer.peer.isGroup {
                        status = strings().voiceChatJoinAsGroupCountable(Int(subscribers))
                    }
                }
                
                var viewType = bestGeneralViewType(list, for: peer)
                if list.first == peer {
                    if list.count == 1 {
                        viewType = .lastItem
                    } else {
                        viewType = .innerItem
                    }
                }
                
                let tuple = Tuple(peer: peer, viewType: viewType, selected: peer.peer.id == joinAsPeerId, status: status)
                
                
                
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_peer(peer.peer.id), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
                    return ShortPeerRowItem(initialSize, peer: tuple.peer.peer, account: context.account, context: context, stableId: stableId, height: 50, photoSize: NSMakeSize(36, 36), titleStyle: ControlStyle(font: .medium(.title), foregroundColor: theme.textColor, highlightColor: .white), statusStyle: ControlStyle(foregroundColor: theme.grayTextColor), status: tuple.status, inset: NSEdgeInsets(left: 20, right: 20), interactionType: .plain, generalType: .selectable(tuple.selected), viewType: tuple.viewType, action: {
                        arguments.switchAccount(tuple.peer.peer.id)
                    }, customTheme: theme)

                }))
            }
        }
        
    } else {
        
        if case .sectionId = entries.last {
            
        } else {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
        }
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("loading"), equatable: nil, comparable: nil, item: { initialSize, stableId in
            return GeneralLoadingRowItem(initialSize, stableId: stableId, viewType: .lastItem)
        }))
        index += 1
    }
    
    
    if state.canManageCall && state.scheduleTimestamp == nil {
        if case .sectionId = entries.last {
            
        } else {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
        }
        
        
        let recordTitle: String
        let recordPlaceholder: String = strings().voiecChatSettingsRecordPlaceholder1
        if callState.peer.isChannel || callState.peer.isGigagroup {
            recordTitle = strings().voiecChatSettingsRecordLiveTitle
        } else if !callState.videoActive(.list).isEmpty {
            recordTitle = strings().voiecChatSettingsRecordVideoTitle
        } else {
            recordTitle = strings().voiecChatSettingsRecordTitle
        }
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(recordTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1
        
        
        
        let recordingStartTimestamp = state.recordingStartTimestamp
        
        if recordingStartTimestamp == nil {
            entries.append(.input(sectionId: sectionId, index: index, value: .string(uiState.recordName), error: nil, identifier: _id_input_record_title, mode: .plain, data: .init(viewType: .firstItem, pasteFilter: nil, customTheme: theme), placeholder: nil, inputPlaceholder: recordPlaceholder, filter: { $0 }, limit: 40))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_record_video_toggle, data: .init(name: strings().voiceChatSettingsRecordIncludeVideo, color: theme.textColor, type: .switchable(uiState.recordVideo), viewType: .innerItem, action: arguments.toggleRecordVideo, theme: theme)))
            index += 1
            
            if uiState.recordVideo {
                entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("video_orientation"), equatable: InputDataEquatable(uiState), comparable: nil, item: { initialSize, stableId in
                    return GroupCallVideoOrientationRowItem(initialSize, stableId: stableId, viewType: .innerItem, account: context.account, customTheme: theme, selected: uiState.videoOrientation, select: arguments.selectVideoRecordOrientation)
                }))
                index += 1
            }

        }
        struct Tuple : Equatable {
            let recordingStartTimestamp: Int32?
            let viewType: GeneralViewType
        }
        
        let tuple = Tuple(recordingStartTimestamp: recordingStartTimestamp, viewType: recordingStartTimestamp == nil ? .lastItem : .singleItem)
        
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("recording"), equatable: InputDataEquatable(tuple), comparable: nil, item: { initialSize, stableId in
            return GroupCallRecorderRowItem(initialSize, stableId: stableId, viewType: tuple.viewType, account: context.account, startedRecordedTime: tuple.recordingStartTimestamp, customTheme: theme, start: arguments.startRecording, stop: arguments.stopRecording)
        }))
        index += 1
        
    }
    
    
    if state.canManageCall, let defaultParticipantMuteState = state.defaultParticipantMuteState, !state.isStream {
        
        if case .sectionId = entries.last {
            
        } else {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
        }
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPermissionsTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1
        
        let isMuted = defaultParticipantMuteState == .muted
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_all_members, data: InputDataGeneralData(name: strings().voiceChatSettingsAllMembers, color: theme.textColor, type: .selectable(!isMuted), viewType: .firstItem, enabled: true, action: {
            arguments.updateDefaultParticipantsAreMuted(false)
        }, theme: theme)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_admin_only, data: InputDataGeneralData(name: strings().voiceChatSettingsOnlyAdmins, color: theme.textColor, type: .selectable(isMuted), viewType: .lastItem, enabled: true, action: {
            arguments.updateDefaultParticipantsAreMuted(true)
        }, theme: theme)))
        index += 1
        

    }

    
    if !state.isStream {
        if case .sectionId = entries.last {
            
        } else {
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
        }

            
        let microDevice = settings.audioInputDeviceId == nil ? devices.audioInput.first : devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })
           
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().callSettingsInputTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_audio, data: .init(name: strings().callSettingsInputText, color: theme.textColor, type: .contextSelector(settings.audioInputDeviceId == nil ? strings().callSettingsDeviceDefault : microDevice?.localizedName ?? strings().callSettingsDeviceDefault, [ContextMenuItem(strings().callSettingsDeviceDefault, handler: {
            arguments.toggleInputAudioDevice(nil)
        })] + devices.audioInput.map { value in
            return ContextMenuItem(value.localizedName, handler: {
                arguments.toggleInputAudioDevice(value.uniqueID)
            })
        }), viewType: microDevice == nil ? .singleItem : .firstItem, theme: theme)))
        index += 1
        
        if let microDevice = microDevice {
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_micro, equatable: InputDataEquatable(microDevice.uniqueID), comparable: nil, item: { initialSize, stableId -> TableRowItem in
                return MicrophonePreviewRowItem(initialSize, stableId: stableId, context: arguments.sharedContext, viewType: .lastItem, customTheme: theme)
            }))
            index += 1
        }
    }
    
    if case .sectionId = entries.last {
        
    } else {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
    let outputDevice = devices.audioOutput.first(where: { $0.uniqueID == settings.audioOutputDeviceId })
       
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsOutput), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_output_audio, data: .init(name: strings().voiceChatSettingsOutputDevice, color: theme.textColor, type: .contextSelector(outputDevice?.localizedName ?? strings().callSettingsDeviceDefault, [ContextMenuItem(strings().callSettingsDeviceDefault, handler: {
        arguments.toggleOutputAudioDevice(nil)
    })] + devices.audioOutput.map { value in
        return ContextMenuItem(value.localizedName, handler: {
            arguments.toggleOutputAudioDevice(value.uniqueID)
        })
    }), viewType: .singleItem, theme: theme)))
    index += 1
    
    if !state.isStream {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1


        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPushToTalkTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_toggle, data: .init(name: strings().voiceChatSettingsPushToTalkEnabled, color: theme.textColor, type: .switchable(settings.mode != .none), viewType: .singleItem, action: {
            if settings.mode == .none {
                arguments.checkPermission()
            }
            arguments.updateSettings {
                $0.withUpdatedMode($0.mode == .none ? .pushToTalk : .none)
            }
        }, theme: theme)))
        index += 1

        switch settings.mode {
        case .none:
            break
        default:
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1


            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsInputMode), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
            index += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_always, data: .init(name: strings().voiceChatSettingsInputModeAlways, color: theme.textColor, type: .selectable(settings.mode == .always), viewType: .firstItem, action: {
                arguments.updateSettings {
                    $0.withUpdatedMode(.always)
                }
            }, theme: theme)))
            index += 1

            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_ptt, data: .init(name: strings().voiceChatSettingsInputModePushToTalk, color: theme.textColor, type: .selectable(settings.mode == .pushToTalk), viewType: .lastItem, action: {
                arguments.updateSettings {
                    $0.withUpdatedMode(.pushToTalk)
                }
            }, theme: theme)))
            index += 1



            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1

            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPushToTalk), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
            index += 1

            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_ptt, equatable: InputDataEquatable(settings.pushToTalk), comparable: nil, item: { initialSize, stableId -> TableRowItem in
                return PushToTalkRowItem(initialSize, stableId: stableId, settings: settings.pushToTalk, update: { value in
                    arguments.updateSettings {
                        $0.withUpdatedPushToTalk(value)
                    }
                }, checkPermission: arguments.checkPermission, viewType: .singleItem)
            }))
            index += 1

            if let permission = uiState.hasPermission {
                if !permission {

                    let text: String
                    if #available(macOS 10.15, *) {
                        text = strings().voiceChatSettingsPushToTalkAccess
                    } else {
                        text = strings().voiceChatSettingsPushToTalkAccessOld
                    }

                    entries.append(.desc(sectionId: sectionId, index: index, text: .customMarkdown(text, linkColor: GroupCallTheme.speakLockedColor, linkFont: .bold(11.5), linkHandler: { permission in
                        PermissionsManager.openInputMonitoringPrefs()
                    }), data: .init(color: GroupCallTheme.speakLockedColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
                    index += 1
                } else {
                    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPushToTalkDesc), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
                    index += 1
                }
            }
        }
    }

    if !state.isStream {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPerformanceHeader), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_noise_suppression, data: InputDataGeneralData(name: strings().voiceChatSettingsNoiseSuppression, color: theme.textColor, type: .switchable(settings.noiseSuppression), viewType: .singleItem, enabled: true, action: {
            arguments.setNoiseSuppression(!settings.noiseSuppression)
        }, theme: theme)))
        index += 1
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsPerformanceDesc), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textBottomItem)))
        index += 1
    }
    

    if state.canManageCall, peer.groupAccess.isCreator {
        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
        
        if !state.isStream {
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_reset_link, data: InputDataGeneralData(name: strings().voiceChatSettingsResetLink, color: GroupCallTheme.customTheme.accentColor, type: .none, viewType: .firstItem, enabled: true, action: arguments.resetLink, theme: theme)))
            index += 1
        } else if let credentials = uiState.credentials {
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatSettingsRTMP), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_server_url, equatable: .init(uiState), comparable: nil, item: { initialSize, stableId in
                return TextAndLabelItem(initialSize, stableId: stableId, label: strings().voiceChatRTMPServerURL, copyMenuText: strings().textCopy, labelColor: theme.textColor, textColor: theme.accentColor, backgroundColor: theme.backgroundColor, text: credentials.url, context: nil, viewType: .firstItem, isTextSelectable: false, callback: {
                    arguments.copyToClipboard(credentials.url)
                }, selectFullWord: true, canCopy: true, _copyToClipboard: {
                    arguments.copyToClipboard(credentials.url)
                }, textFont: .code(.title), accentColor: theme.accentColor, borderColor: theme.borderColor)
            }))
            index += 1
            
            entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_stream_key, equatable: .init(uiState), comparable: nil, item: { initialSize, stableId in
                return TextAndLabelItem(initialSize, stableId: stableId, label: strings().voiceChatRTMPStreamKey, copyMenuText: strings().textCopy, labelColor: theme.textColor, textColor: theme.accentColor, backgroundColor: theme.backgroundColor, text: credentials.streamKey, context: nil, viewType: .innerItem, isTextSelectable: false, callback: {
                    arguments.copyToClipboard(credentials.streamKey)
                }, selectFullWord: true, canCopy: true, _copyToClipboard: {
                    arguments.copyToClipboard(credentials.streamKey)
                }, textFont: .code(.title), hideText: uiState.hideKey, toggleHide: arguments.toggleHideKey, accentColor: theme.accentColor, borderColor: theme.borderColor)
            }))
            index += 1
            
            entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_revoke_stream_key, data: InputDataGeneralData(name: strings().voiceChatRTMPRevoke, color: GroupCallTheme.speakLockedColor, type: .none, viewType: .lastItem, enabled: true, action: arguments.revokeStreamKey, theme: theme)))
            index += 1
            
            entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().voiceChatRTMPInfo), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textBottomItem)))
            index += 1

            
            entries.append(.sectionId(sectionId, type: .customModern(20)))
            sectionId += 1
            
        }
        
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_leave_chat, data: InputDataGeneralData(name: strings().voiceChatSettingsEnd, color: GroupCallTheme.speakLockedColor, type: .none, viewType: state.isStream ? .singleItem : .lastItem, enabled: true, action: arguments.finishCall, theme: theme)))
        index += 1
    }
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    return entries
}

//    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_ptt_se, data: .init(name: "Sound Effects", color: .white, type: .switchable(settings.pushToTalkSoundEffects), viewType: .lastItem, action: {
//        updateSettings {
//            $0.withUpdatedSoundEffects(!$0.pushToTalkSoundEffects)
//        }
//    }, theme: theme)))
//    index += 1
//

final class GroupCallSettingsController : GenericViewController<GroupCallSettingsView> {
    fileprivate let sharedContext: SharedAccountContext
    fileprivate let call: PresentationGroupCall
    private let disposable = MetaDisposable()
    private let context: AccountContext
    private let monitorPermissionDisposable = MetaDisposable()
    private let actualizeTitleDisposable = MetaDisposable()
    private let displayAsPeersDisposable = MetaDisposable()
    private let credentialsDisposable = MetaDisposable()
    
    private let callState: Signal<GroupCallUIState, NoError>
    
    init(sharedContext: SharedAccountContext, context: AccountContext, callState: Signal<GroupCallUIState, NoError>, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.call = call
        self.callState = callState
        self.context = context
        super.init()
        bar = .init(height: 0)
    }
    
    private var tableView: TableView {
        return genericView.tableView
    }
    private var firstTake: Bool = true

    override func firstResponder() -> NSResponder? {
        if self.window?.firstResponder == self.window || self.window?.firstResponder == tableView.documentView {
            var first: NSResponder? = nil
            var isRecordingPushToTalk: Bool = false
            tableView.enumerateViews { view -> Bool in
                if let view = view as? PushToTalkRowView {
                    if view.mode == .editing {
                        isRecordingPushToTalk = true
                        return false
                    }
                }
                return true
            }
            if !isRecordingPushToTalk {
                tableView.enumerateViews { view -> Bool in
                    first = view.firstResponder
                    if first != nil, self.firstTake {
                        if let item = view.item as? InputDataRowDataValue {
                            switch item.value {
                            case let .string(value):
                                let value = value ?? ""
                                if !value.isEmpty {
                                    return true
                                }
                            default:
                                break
                            }
                        }
                    }
                    return first == nil
                }
                self.firstTake = false
                return first
            } else {
                return window?.firstResponder
            }
            
        }
        return window?.firstResponder
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
        monitorPermissionDisposable.dispose()
        actualizeTitleDisposable.dispose()
        displayAsPeersDisposable.dispose()
        credentialsDisposable.dispose()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = self.window?.makeFirstResponder(nil)
        
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let index = self.tableView.row(at: self.tableView.documentView!.convert(event.locationInWindow, from: nil))
            
            if index > -1, let view = self.tableView.item(at: index).view {
                if view.mouseInsideField {
                    if self.window?.firstResponder != view.firstResponder {
                        _ = self.window?.makeFirstResponder(view.firstResponder)
                        return .invoked
                    }
                }
            }
            
            return .invokeNext
        }, with: self, for: .leftMouseUp, priority: self.responderPriority)
    }
    private func fetchData() -> [InputDataIdentifier : InputDataValue] {
        var values:[InputDataIdentifier : InputDataValue] = [:]
        tableView.enumerateItems { item -> Bool in
            if let identifier = (item.stableId.base as? InputDataEntryId)?.identifier {
                if let item = item as? InputDataRowDataValue {
                    values[identifier] = item.value
                }
            }
            return true
        }
        return values
    }
    
    private var getState:(()->GroupCallSettingsState?)? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        

        self.genericView.tableView._mouseDownCanMoveWindow = true
        
        let context = self.context
        let peerId = self.call.peerId
        let initialState = GroupCallSettingsState(hasPermission: nil, title: nil, recordVideo: true, videoOrientation: .landscape)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((GroupCallSettingsState) -> GroupCallSettingsState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }

        monitorPermissionDisposable.set((KeyboardGlobalHandler.getPermission() |> deliverOnMainQueue).start(next: { value in
            updateState { current in
                var current = current
                current.hasPermission = value
                return current
            }
        }))
        
        getState = { [weak stateValue] in
            return stateValue?.with { $0 }
        }

        
        actualizeTitleDisposable.set(call.state.start(next: { state in
            updateState { current in
                var current = current
                if current.title == nil {
                    current.title = state.title
                }
                return current
            }
        }))
        
        displayAsPeersDisposable.set(combineLatest(queue: prepareQueue,call.displayAsPeers, context.account.postbox.peerView(id: context.peerId)).start(next: { list, peerView in
            updateState { current in
                var current = current
                current.displayAsList = list
                return current
            }
        }))
        
        genericView.backButton.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        
        let sharedContext = self.sharedContext
        
        
        let arguments = Arguments(sharedContext: sharedContext, toggleInputAudioDevice: { value in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
                $0.withUpdatedAudioInputDeviceId(value)
            }).start()
        }, toggleOutputAudioDevice: { value in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
                $0.withUpdatedAudioOutputDeviceId(value)
            }).start()
        }, toggleInputVideoDevice: { value in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
                $0.withUpdatedCameraInputDeviceId(value)
            }).start()
        }, finishCall: { [weak self] in
            guard let window = self?.window else {
                return
            }
            verifyAlert_button(for: window, header: strings().voiceChatSettingsEndConfirmTitle, information: strings().voiceChatSettingsEndConfirm, ok: strings().voiceChatSettingsEndConfirmOK, successHandler: { [weak self] _ in

                guard let call = self?.call, let window = self?.window else {
                    return
                }
                _ = showModalProgress(signal: call.sharedContext.endGroupCall(terminate: true), for: window).start()
            }, presentation: darkAppearance)

        }, updateDefaultParticipantsAreMuted: { [weak self] value in
            self?.call.updateDefaultParticipantsAreMuted(isMuted: value)
        }, updateSettings: { f in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, f).start()
        }, checkPermission: {
            updateState { current in
                var current = current
                current.hasPermission = KeyboardGlobalHandler.hasPermission()
                return current
            }
        }, showTooltip: { [weak self] text in
            if let window = self?.window {
                showModalText(for: window, text: text)
            }
        }, switchAccount: { [weak self] peerId in
            self?.call.reconnect(as: peerId)
        }, startRecording: { [weak self] in
            if let window = self?.window {
                verifyAlert_button(for: window, header: strings().voiceChatRecordingStartTitle, information: strings().voiceChatRecordingStartText1, ok: strings().voiceChatRecordingStartOK, successHandler: { _ in
                    self?.call.setShouldBeRecording(true, title: stateValue.with { $0.recordName }, videoOrientation: stateValue.with { $0.recordVideo ? $0.videoOrientation.rawValue : nil})
                })
            }
        }, stopRecording: { [weak self] in
            if let window = self?.window {
                verifyAlert_button(for: window, header: strings().voiceChatRecordingStopTitle, information: strings().voiceChatRecordingStopText, ok: strings().voiceChatRecordingStopOK, successHandler: { [weak window] _ in
                    self?.call.setShouldBeRecording(false, title: nil, videoOrientation: nil)
                    if let window = window {
                        showModalText(for: window, text: strings().voiceChatToastStop)
                    }
                })
            }
        }, resetLink: { [weak self] in
            self?.call.resetListenerLink()
            if let window = self?.window {
                showModalText(for: window, text: strings().voiceChatSettingsResetLinkSuccess)
            }
        }, setNoiseSuppression: { value in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
                $0.withUpdatedNoiseSuppression(value)
            }).start()
        }, reduceMotions: { value in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, {
                $0.withUpdatedVisualEffects(value)
            }).start()
        }, selectVideoRecordOrientation: { value in
            updateState { current in
                var current = current
                current.videoOrientation = value
                return current
            }
        }, toggleRecordVideo: {
            updateState { current in
                var current = current
                current.recordVideo = !current.recordVideo
                return current
            }
        }, copyToClipboard: { [weak self] value in
            copyToClipboard(value)
            if let window = self?.window {
                showModalText(for: window, text: strings().contextAlertCopied)
            }
        }, toggleHideKey: {
            updateState { current in
                var current = current
                current.hideKey = !current.hideKey
                return current
            }
        }, revokeStreamKey: { [weak self] in
            if let window = self?.window {
                verifyAlert_button(for: window, header: strings().voiceChatRTMPRevoke, information: strings().voiceChatRTMPRevokeInfo, ok: strings().alertYes, cancel: strings().alertNO, successHandler: { [weak self] _ in
                    
                    let signal = self?.call.engine.calls.getGroupCallStreamCredentials(peerId: .init(peerId.toInt64()), revokePreviousCredentials: true)
                    if let signal = signal {
                        _ = showModalProgress(signal: signal, for: window).start(next: { value in
                            updateState { current in
                                var current = current
                                current.credentials = value
                                return current
                            }
                        })
                    }
                    
                }, presentation: darkAppearance)
            }
        })
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let inputDataArguments = InputDataArguments(select: { _, _ in }, dataUpdated: { [weak self] in
            guard let `self` = self else {
                return
            }
            let data = self.fetchData()
            var previousTitle: String? = stateValue.with { $0.title }

            updateState { current in
                var current = current
                current.title = data[_id_input_chat_title]?.stringValue ?? current.title
                current.recordName = data[_id_input_record_title]?.stringValue ?? current.title
                return current
            }
            let title = stateValue.with({ $0.title })
            if previousTitle != title, let title = title {
                self.call.updateTitle(title, force: false)
            }
        })
        let initialSize = self.atomicSize
        let joinAsPeer: Signal<PeerId, NoError> = self.call.joinAsPeerIdValue
        
        
        let rtmp_credentials: Signal<GroupCallStreamCredentials?, NoError>
        
        if let peer = self.call.peer, peer.groupAccess.isCreator {
            let credentials = self.call.engine.calls.getGroupCallStreamCredentials(peerId: .init(self.call.peerId.toInt64()), revokePreviousCredentials: false)
            |> map(Optional.init)
            |> `catch` { _ -> Signal<GroupCallStreamCredentials?, NoError> in
                return .single(nil)
            }
            
           rtmp_credentials = .single(nil) |> then(credentials)
        } else {
            rtmp_credentials = .single(nil)
        }
        
        credentialsDisposable.set(rtmp_credentials.start(next: { value in
            updateState { current in
                var current = current
                current.credentials = value
                return current
            }
        }))
        
        
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, sharedContext.devicesContext.signal, voiceCallSettings(sharedContext.accountManager), appearanceSignal, self.call.account.postbox.loadedPeerWithId(self.call.peerId), self.call.account.postbox.loadedPeerWithId(context.peerId), joinAsPeer, self.callState, statePromise.get()) |> mapToQueue { devices, settings, appearance, peer, accountPeer, joinAsPeerId, state, uiState in
            let entries = groupCallSettingsEntries(callState: state, devices: devices, uiState: uiState, settings: settings, context: context, peer: peer, accountPeer: accountPeer, joinAsPeerId: joinAsPeerId, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previousEntries.swap(entries), right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputDataArguments, onMainQueue: false)
        } |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] value in
            self?.genericView.tableView.merge(with: value)
            self?.readyOnce()
        }))
        
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        backgroundColor = GroupCallTheme.windowBackground.withAlphaComponent(1)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let state = getState?(), let title = state.title {
            self.call.updateTitle(title, force: true)
        }
        self.window?.removeObserver(for: self)
    }
    
    override func backKeyAction() -> KeyHandlerResult {
        return .invokeNext
    }
    
    override func returnKeyAction() -> KeyHandlerResult {
        self.navigationController?.back()
        return super.returnKeyAction()
    }
    
}
