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
import SyncCore
import Postbox
import HotKey

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
    init(sharedContext: SharedAccountContext,
         toggleInputAudioDevice: @escaping(String?)->Void,
         toggleOutputAudioDevice:@escaping(String?)->Void,
         toggleInputVideoDevice:@escaping(String?)->Void,
         finishCall:@escaping()->Void,
         updateDefaultParticipantsAreMuted: @escaping(Bool)->Void,
         updateSettings:  @escaping(@escaping(VoiceCallSettings)->VoiceCallSettings)->Void,
         checkPermission:@escaping()->Void,
         showTooltip: @escaping(String)->Void) {
        self.sharedContext = sharedContext
        self.toggleInputAudioDevice = toggleInputAudioDevice
        self.toggleOutputAudioDevice = toggleOutputAudioDevice
        self.toggleInputVideoDevice = toggleInputVideoDevice
        self.finishCall = finishCall
        self.updateDefaultParticipantsAreMuted = updateDefaultParticipantsAreMuted
        self.updateSettings = updateSettings
        self.checkPermission = checkPermission
        self.showTooltip = showTooltip
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
        
        let layout = TextViewLayout.init(.initialize(string: L10n.voiceChatSettingsTitle, color: GroupCallTheme.customTheme.textColor, font: .medium(.header)))
        layout.measure(width: frame.width - 200)
        title.update(layout)
        tableView.getBackgroundColor = {
            GroupCallTheme.windowBackground
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
        title.center()
    }
}

private struct GroupCallSettingsState : Equatable {
    var hasPermission:Bool?
    var displayPeers:[PeerEquatable]
}

private let _id_leave_chat = InputDataIdentifier.init("_id_leave_chat")
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


private let _id_input_chat_title = InputDataIdentifier("_id_input_chat_title")

private let _id_listening_link = InputDataIdentifier("_id_listening_link")
private let _id_speaking_link = InputDataIdentifier("_id_speaking_link")

private func groupCallSettingsEntries(state: PresentationGroupCallState, devices: IODevices, uiState: GroupCallSettingsState, settings: VoiceCallSettings, account: Account, peer: Peer, arguments: Arguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    let theme = GroupCallTheme.customTheme

    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    if state.canManageCall {
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("VOICE CHAT TITLE"), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1

        //TODOLANG
        entries.append(.input(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_chat_title, mode: .plain, data: .init(viewType: .singleItem, pasteFilter: nil, customTheme: theme), placeholder: nil, inputPlaceholder: "title...", filter: { $0 }, limit: 140))
        index += 1

        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
    if state.canManageCall {
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("DISPLAY ME AS"), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1

        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_listening_link, data: InputDataGeneralData(name: "Copy Listening Link", color: theme.accentColor, type: .none, viewType: .firstItem, enabled: true, action: {
            copyToClipboard("t.me/listeninglink")
            arguments.showTooltip("Listening link successfully copied to Clipboard")
        }, theme: theme)))
        index += 1
        
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speaking_link, data: InputDataGeneralData(name: "Copy Speaking Link", color: theme.accentColor, type: .none, viewType: .lastItem, enabled: true, action: {
            copyToClipboard("t.me/speakinglink")
            arguments.showTooltip("Speaking link successfully copied to Clipboard")
        }, theme: theme)))
        index += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Use these links to invite listeners or speakers to your voice chat."), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textBottomItem)))
        index += 1


        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
    if state.canManageCall {
        //TODOLANG
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("INVITE LINKS"), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1

        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_listening_link, data: InputDataGeneralData(name: "Copy Listening Link", color: theme.accentColor, type: .none, viewType: .firstItem, enabled: true, action: {
            copyToClipboard("t.me/listeninglink")
            arguments.showTooltip("Listening link successfully copied to Clipboard")
        }, theme: theme)))
        index += 1
        
        //TODOLANG
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speaking_link, data: InputDataGeneralData(name: "Copy Speaking Link", color: theme.accentColor, type: .none, viewType: .lastItem, enabled: true, action: {
            copyToClipboard("t.me/speakinglink")
            arguments.showTooltip("Speaking link successfully copied to Clipboard")
        }, theme: theme)))
        index += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("Use these links to invite listeners or speakers to your voice chat."), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textBottomItem)))
        index += 1


        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }
    
    
    if state.canManageCall, let defaultParticipantMuteState = state.defaultParticipantMuteState {
        
        entries.append(.desc(sectionId: sectionId, index: index, text: .plain("PERMISSIONS"), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1
        
        let isMuted = defaultParticipantMuteState == .muted
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_all_members, data: InputDataGeneralData(name: L10n.voiceChatSettingsAllMembers, color: theme.textColor, type: .selectable(!isMuted), viewType: .firstItem, enabled: true, action: {
            arguments.updateDefaultParticipantsAreMuted(false)
        }, theme: theme)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_admin_only, data: InputDataGeneralData(name: L10n.voiceChatSettingsOnlyAdmins, color: theme.textColor, type: .selectable(isMuted), viewType: .innerItem, enabled: true, action: {
            arguments.updateDefaultParticipantsAreMuted(true)
        }, theme: theme)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_leave_chat, data: InputDataGeneralData(name: L10n.voiceChatSettingsEnd, color: GroupCallTheme.speakLockedColor, type: .none, viewType: .lastItem, enabled: true, action: arguments.finishCall, theme: theme)))
        index += 1

        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }

        
    let microDevice = settings.audioInputDeviceId == nil ? devices.audioInput.first : devices.audioInput.first(where: { $0.uniqueID == settings.audioInputDeviceId })
       
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.callSettingsInputTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_audio, data: .init(name: L10n.callSettingsInputText, color: theme.textColor, type: .contextSelector(settings.audioInputDeviceId == nil ? L10n.callSettingsDeviceDefault : microDevice?.localizedName ?? L10n.callSettingsDeviceDefault, [SPopoverItem(L10n.callSettingsDeviceDefault, {
        arguments.toggleInputAudioDevice(nil)
    })] + devices.audioInput.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputAudioDevice(value.uniqueID)
        })
    }), viewType: microDevice == nil ? .singleItem : .firstItem, theme: theme)))
    index += 1
    
    if let microDevice = microDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_micro, equatable: InputDataEquatable(microDevice.uniqueID), item: { initialSize, stableId -> TableRowItem in
            return MicrophonePreviewRowItem(initialSize, stableId: stableId, device: microDevice, viewType: .lastItem, customTheme: theme)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
    
    let outputDevice = devices.audioOutput.first(where: { $0.uniqueID == settings.audioOutputDeviceId })
       
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsOutput), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_output_audio, data: .init(name: L10n.voiceChatSettingsOutputDevice, color: theme.textColor, type: .contextSelector(outputDevice?.localizedName ?? L10n.callSettingsDeviceDefault, [SPopoverItem(L10n.callSettingsDeviceDefault, {
        arguments.toggleOutputAudioDevice(nil)
    })] + devices.audioOutput.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleOutputAudioDevice(value.uniqueID)
        })
    }), viewType: .singleItem, theme: theme)))
    index += 1
    

    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1


    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsPushToTalkTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1

    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_toggle, data: .init(name: L10n.voiceChatSettingsPushToTalkEnabled, color: theme.textColor, type: .switchable(settings.mode != .none), viewType: .singleItem, action: {
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


        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsInputMode), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
        index += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_always, data: .init(name: L10n.voiceChatSettingsInputModeAlways, color: theme.textColor, type: .selectable(settings.mode == .always), viewType: .firstItem, action: {
            arguments.updateSettings {
                $0.withUpdatedMode(.always)
            }
        }, theme: theme)))
        index += 1

        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_ptt, data: .init(name: L10n.voiceChatSettingsInputModePushToTalk, color: theme.textColor, type: .selectable(settings.mode == .pushToTalk), viewType: .lastItem, action: {
            arguments.updateSettings {
                $0.withUpdatedMode(.pushToTalk)
            }
        }, theme: theme)))
        index += 1



        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1

        entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsPushToTalk), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
        index += 1

        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_ptt, equatable: InputDataEquatable(settings.pushToTalk), item: { initialSize, stableId -> TableRowItem in
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
                    text = L10n.voiceChatSettingsPushToTalkAccess
                } else {
                    text = L10n.voiceChatSettingsPushToTalkAccessOld
                }

                entries.append(.desc(sectionId: sectionId, index: index, text: .customMarkdown(text, linkColor: GroupCallTheme.speakLockedColor, linkFont: .bold(11.5), linkHandler: { permission in
                    PermissionsManager.openInputMonitoringPrefs()
                }), data: .init(color: GroupCallTheme.speakLockedColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
                index += 1
            } else {
                entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsPushToTalkDesc), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
                index += 1
            }
        }
    }


        
    entries.append(.sectionId(sectionId, type: .customModern(10)))
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
    private let account: Account
    private let monitorPermissionDisposable = MetaDisposable()
    
    init(sharedContext: SharedAccountContext, account: Account, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.account = account
        self.call = call
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        _ = self.window?.makeFirstResponder(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        

        self.genericView.tableView._mouseDownCanMoveWindow = true
        
        let account = self.account
                
        let initialState = GroupCallSettingsState(hasPermission: nil, displayPeers: [])
        
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

        
        
        genericView.backButton.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        
        let sharedContext = self.sharedContext
        
        let updateSettings:(@escaping(VoiceCallSettings)->VoiceCallSettings)->Void = { f in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, f).start()
        }
        
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
            confirm(for: window, header: L10n.voiceChatSettingsEndConfirmTitle, information: L10n.voiceChatSettingsEndConfirm, okTitle: L10n.voiceChatSettingsEndConfirmOK, successHandler: { [weak self] _ in

                guard let call = self?.call, let window = self?.window else {
                    return
                }
                _ = showModalProgress(signal: call.sharedContext.endGroupCall(terminate: true), for: window).start()
            }, appearance: darkPalette.appearance)

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
        })
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let inputDataArguments = InputDataArguments(select: { _, _ in }, dataUpdated: { })
        let initialSize = self.atomicSize
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, sharedContext.devicesContext.signal, voiceCallSettings(sharedContext.accountManager), appearanceSignal, self.call.account.postbox.loadedPeerWithId(self.call.peerId), self.call.state, statePromise.get()) |> mapToQueue { devices, settings, appearance, peer, state, uiState in
            let entries = groupCallSettingsEntries(state: state, devices: devices, uiState: uiState, settings: settings, account: account, peer: peer, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previousEntries.swap(entries), right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputDataArguments, onMainQueue: false)
        } |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] value in
            self?.genericView.tableView.merge(with: value)
            self?.readyOnce()
        }))
        
    }

    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        backgroundColor = GroupCallTheme.windowBackground
    }
    
    
}
