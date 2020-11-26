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

        _ = backButton.sizeToFit()
        
        let layout = TextViewLayout.init(.initialize(string: "Voice Chat Settings", color: .white, font: .medium(15)))
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

private let _id_leave_chat = InputDataIdentifier.init("_id_leave_chat")
private let _id_input_audio = InputDataIdentifier("_id_input_audio")
private let _id_micro = InputDataIdentifier("_id_micro")

private func groupCallSettingsEntries(settings: VoiceCallSettings, peer: Peer, arguments: CallSettingsArguments) -> [InputDataEntry] {
    
    var entries:[InputDataEntry] = []
    
    var sectionId: Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    let theme = InputDataGeneralData.Theme(backgroundColor: GroupCallTheme.membersColor,
                                           highlightColor: GroupCallTheme.membersColor.withAlphaComponent(0.7),
                                           borderColor: GroupCallTheme.memberSeparatorColor,
                                           accentColor: GroupCallTheme.blueStatusColor,
                                           secondaryColor: GroupCallTheme.grayStatusColor,
                                           textColor: .white,
                                           appearance: darkPalette.appearance)
    
    
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_leave_chat, data: InputDataGeneralData(name: "End Voice Chat", color: .redUI, type: .none, viewType: .singleItem, enabled: true, action: {}, theme: theme)))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .customModern(20)))
    sectionId += 1
    
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
    
    
    
    
    return entries
}

final class GroupCallSettingsController : GenericViewController<GroupCallSettingsView> {
    fileprivate let sharedContext: SharedAccountContext
    fileprivate let call: PresentationGroupCall
    private let disposable = MetaDisposable()
    init(sharedContext: SharedAccountContext, call: PresentationGroupCall) {
        self.sharedContext = sharedContext
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
        
        genericView.backButton.set(handler: { [weak self] _ in
            self?.navigationController?.back()
        }, for: .Click)
        
        let sharedContext = self.sharedContext
        
        let deviceContextObserver = DevicesContext(VoiceCallSettings.defaultSettings)
        
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
        })
        
        let previousEntries:Atomic<[AppearanceWrapperEntry<InputDataEntry>]> = Atomic(value: [])
        let inputDataArguments = InputDataArguments(select: { _, _ in }, dataUpdated: { })
        let initialSize = self.atomicSize
        let signal: Signal<TableUpdateTransition, NoError> = combineLatest(queue: prepareQueue, deviceContextObserver.signal, voiceCallSettings(sharedContext.accountManager), appearanceSignal, self.call.account.postbox.loadedPeerWithId(self.call.peerId)) |> mapToSignal { _, settings, appearance, peer in
            let entries = groupCallSettingsEntries(settings: settings, peer: peer, arguments: arguments).map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            return prepareInputDataTransition(left: previousEntries.swap(entries), right: entries, animated: true, searchState: nil, initialSize: initialSize.with { $0 }, arguments: inputDataArguments, onMainQueue: false)
        } |> deliverOnMainQueue

        disposable.set(signal.start(next: { [weak self] value in
            self?.genericView.tableView.merge(with: value)
            self?.readyOnce()
        }))
        
    }
    
}
