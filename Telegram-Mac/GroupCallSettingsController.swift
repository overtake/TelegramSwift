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
        
        let layout = TextViewLayout.init(.initialize(string: L10n.voiceChatSettingsTitle, color: .white, font: .medium(.header)))
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
        super.updateLocalizationAndTheme(theme: theme)
        backgroundColor = GroupCallTheme.windowBackground
        titleContainer.backgroundColor = GroupCallTheme.windowBackground
        title.backgroundColor = GroupCallTheme.windowBackground
    }
    
    override func layout() {
        super.layout()
        titleContainer.frame = NSMakeRect(0, 0, frame.width, 54)
        tableView.frame = NSMakeRect(0, titleContainer.frame.maxY, frame.width, frame.height - titleContainer.frame.height)
        backButton.centerY(x: 100)
        title.center()
    }
}

private struct GroupCallSettingsState : Equatable {
    let hasPermission:Bool?
}

private let _id_leave_chat = InputDataIdentifier.init("_id_leave_chat")
private let _id_input_audio = InputDataIdentifier("_id_input_audio")
private let _id_micro = InputDataIdentifier("_id_micro")
private let _id_speak_admin_only = InputDataIdentifier("_id_speak_admin_only")
private let _id_speak_all_members = InputDataIdentifier("_id_speak_all_members")
private let _id_input_mode_always = InputDataIdentifier("_id_input_mode_always")
private let _id_input_mode_ptt = InputDataIdentifier("_id_input_mode_ptt")
private let _id_ptt = InputDataIdentifier("_id_ptt")
private let _id_input_mode_ptt_se = InputDataIdentifier("_id_input_mode_ptt_se")


private func groupCallSettingsEntries(state: PresentationGroupCallState, uiState: GroupCallSettingsState, settings: VoiceCallSettings, account: Account, peer: Peer, arguments: CallSettingsArguments, updateDefaultParticipantsAreMuted: @escaping(Bool)->Void, updateSettings: @escaping(@escaping(VoiceCallSettings)->VoiceCallSettings)->Void, checkPermission:@escaping()->Void) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    let switchAppearance = SwitchViewAppearance.init(backgroundColor: GroupCallTheme.membersColor, stateOnColor: GroupCallTheme.blueStatusColor, stateOffColor: GroupCallTheme.grayStatusColor, disabledColor: GroupCallTheme.grayStatusColor.withAlphaComponent(0.5), borderColor: GroupCallTheme.memberSeparatorColor)
    
    let theme = InputDataGeneralData.Theme(backgroundColor: GroupCallTheme.membersColor,
                                           highlightColor: GroupCallTheme.membersColor.withAlphaComponent(0.7),
                                           borderColor: GroupCallTheme.memberSeparatorColor,
                                           accentColor: GroupCallTheme.blueStatusColor,
                                           secondaryColor: GroupCallTheme.grayStatusColor,
                                           textColor: .white,
                                           appearance: darkPalette.appearance,
                                           generalCheck: NSImage(named: "Icon_Check")!.precomposed(GroupCallTheme.blueStatusColor),
                                           switchAppearance: switchAppearance)
    
    if state.canManageCall, let defaultParticipantMuteState = state.defaultParticipantMuteState {
        let isMuted = defaultParticipantMuteState == .muted
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_all_members, data: InputDataGeneralData(name: L10n.voiceChatSettingsAllMembers, color: .white, type: .selectable(!isMuted), viewType: .firstItem, enabled: true, action: {
            updateDefaultParticipantsAreMuted(false)
        }, theme: theme)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_speak_admin_only, data: InputDataGeneralData(name: L10n.voiceChatSettingsOnlyAdmins, color: .white, type: .selectable(isMuted), viewType: .innerItem, enabled: true, action: {
            updateDefaultParticipantsAreMuted(true)
        }, theme: theme)))
        index += 1
        
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_leave_chat, data: InputDataGeneralData(name: L10n.voiceChatSettingsEnd, color: GroupCallTheme.speakLockedColor, type: .none, viewType: .lastItem, enabled: true, action: arguments.finishCall, theme: theme)))
        index += 1

        entries.append(.sectionId(sectionId, type: .customModern(20)))
        sectionId += 1
    }

    
    let devices = devicesList()
    
    var microDevice = devices.audio.first(where: { $0.uniqueID == settings.audioInputDeviceId })
    
    let activeMicroDevice: AVCaptureDevice?
    if let microDevice = microDevice {
        if microDevice.isConnected && !microDevice.isSuspended {
            activeMicroDevice = microDevice
        } else {
            activeMicroDevice = nil
        }
    } else if settings.audioInputDeviceId == nil {
        activeMicroDevice = AVCaptureDevice.default(for: .audio)
    } else {
        microDevice = devices.audio.first(where: { $0.isConnected && !$0.isSuspended })
        activeMicroDevice = microDevice
    }
    
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.callSettingsInputTitle), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_audio, data: .init(name: L10n.callSettingsInputText, color: .white, type: .contextSelector(microDevice?.localizedName ?? L10n.callSettingsDeviceDefault, [SPopoverItem(L10n.callSettingsDeviceDefault, {
        arguments.toggleInputAudioDevice(nil)
    })] + devices.audio.map { value in
        return SPopoverItem(value.localizedName, {
            arguments.toggleInputAudioDevice(value.uniqueID)
        })
    }), viewType: activeMicroDevice == nil ? .singleItem : .firstItem, theme: theme)))
    index += 1
    
    if let activeMicroDevice = activeMicroDevice {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_micro, equatable: InputDataEquatable(activeMicroDevice.uniqueID), item: { initialSize, stableId -> TableRowItem in
            return MicrophonePreviewRowItem(initialSize, stableId: stableId, device: activeMicroDevice, viewType: .lastItem, theme: theme)
        }))
        index += 1
    }
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsInputMode), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .textTopItem)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_always, data: .init(name: L10n.voiceChatSettingsInputModeAlways, color: .white, type: .selectable(settings.mode == .always), viewType: .firstItem, action: {
        updateSettings {
            $0.withUpdatedMode(.always)
        }
    }, theme: theme)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_ptt, data: .init(name: L10n.voiceChatSettingsInputModePushToTalk, color: .white, type: .selectable(settings.mode == .pushToTalk), viewType: .innerItem, action: {
        updateSettings {
            $0.withUpdatedMode(.pushToTalk)
        }
    }, theme: theme)))
    index += 1
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_input_mode_ptt_se, data: .init(name: "Sound Effects", color: .white, type: .switchable(settings.pushToTalkSoundEffects), viewType: .lastItem, action: {
        updateSettings {
            $0.withUpdatedSoundEffects(!$0.pushToTalkSoundEffects)
        }
    }, theme: theme)))
    index += 1
    
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(L10n.voiceChatSettingsPushToTalk), data: .init(color: GroupCallTheme.grayStatusColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
    index += 1
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_ptt, equatable: InputDataEquatable(settings.pushToTalk), item: { initialSize, stableId -> TableRowItem in
        return PushToTalkRowItem(initialSize, stableId: stableId, settings: settings.pushToTalk, update: { value in
            updateSettings {
                $0.withUpdatedPushToTalk(value)
            }
        }, checkPermission: checkPermission, viewType: .singleItem)
    }))
    index += 1
    
    if let permission = uiState.hasPermission {
        if !permission {
            entries.append(.desc(sectionId: sectionId, index: index, text: .markdown(L10n.voiceChatSettingsPushToTalkAccess, linkHandler: { _ in
               
            }), data: .init(color: GroupCallTheme.speakLockedColor, viewType: .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 0, 0)))))
            index += 1
        }
    }
        
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    
    return entries
}

final class GroupCallSettingsController : GenericViewController<GroupCallSettingsView> {
    fileprivate let sharedContext: SharedAccountContext
    fileprivate let call: PresentationGroupCall
    private let disposable = MetaDisposable()
    private let account: Account
    init(sharedContext: SharedAccountContext, account: Account, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
        self.account = account
        self.call = call
        super.init()
        bar = .init(height: 0)
    }
    
    override func escapeKeyAction() -> KeyHandlerResult {
        return .rejected
    }
    
    override var enableBack: Bool {
        return true
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let account = self.account
                
        let initialState = GroupCallSettingsState(hasPermission: nil)
        
        let statePromise = ValuePromise(initialState, ignoreRepeated: true)
        let stateValue = Atomic(value: initialState)
        let updateState: ((GroupCallSettingsState) -> GroupCallSettingsState) -> Void = { f in
            statePromise.set(stateValue.modify (f))
        }
        
        
        genericView.backButton.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        
        let sharedContext = self.sharedContext
        
        let deviceContextObserver = DevicesContext(VoiceCallSettings.defaultSettings)
        
        let updateSettings:(@escaping(VoiceCallSettings)->VoiceCallSettings)->Void = { f in
            _ = updateVoiceCallSettingsSettingsInteractively(accountManager: sharedContext.accountManager, f).start()
        }
        
        let arguments = CallSettingsArguments(sharedContext: sharedContext, toggleInputAudioDevice: { value in
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
            guard let call = self?.call, let window = self?.window else {
                return
            }
            _ = showModalProgress(signal: call.sharedContext.endGroupCall(terminate: true), for: window).start()
        })
        
        let updateDefaultParticipantsAreMuted:(Bool)->Void = { [weak self] value in
            self?.call.updateDefaultParticipantsAreMuted(isMuted: value)
        }
        
        let checkPermission: ()->Void = {
            updateState { _ in
                return GroupCallSettingsState(hasPermission: KeyboardGlobalHandler.hasPermission())
            }
        }
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let inputDataArguments = InputDataArguments(select: { _, _ in }, dataUpdated: { })
        let initialSize = self.atomicSize
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, deviceContextObserver.signal, voiceCallSettings(sharedContext.accountManager), appearanceSignal, self.call.account.postbox.loadedPeerWithId(self.call.peerId), self.call.state, statePromise.get()) |> mapToSignal { _, settings, appearance, peer, state, uiState in
            let entries = groupCallSettingsEntries(state: state, uiState: uiState, settings: settings, account: account, peer: peer, arguments: arguments, updateDefaultParticipantsAreMuted: updateDefaultParticipantsAreMuted, updateSettings: updateSettings, checkPermission: checkPermission).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previousEntries.swap(entries), right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputDataArguments, onMainQueue: false)
        } |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] value in
            self?.genericView.tableView.merge(with: value)
            self?.readyOnce()
        }))
        
    }
    
}
