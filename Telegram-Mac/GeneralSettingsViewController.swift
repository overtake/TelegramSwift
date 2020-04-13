//
//  GeneralSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox


private enum GeneralSettingsEntry : Comparable, Identifiable {
    case section(sectionId:Int)
    case header(sectionId: Int, uniqueId:Int, text:String)
    case sidebar(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case inAppSounds(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case shortcuts(sectionId: Int, viewType: GeneralViewType)
    case enterBehavior(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case cmdEnterBehavior(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case emojiReplacements(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case predictEmoji(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case bigEmoji(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case statusBar(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case showCallsTab(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case enableRFTCopy(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case openChatAtLaunch(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case acceptSecretChats(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case forceTouchReply(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case forceTouchEdit(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case forceTouchForward(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    case forceTouchPreviewMedia(sectionId:Int, enabled: Bool, viewType: GeneralViewType)
    var stableId: Int {
        switch self {
        case let .header(_, uniqueId, _):
            return uniqueId
        case .sidebar:
            return 1
        case .emojiReplacements:
            return 2
        case .predictEmoji:
            return 3
        case .bigEmoji:
            return 4
        case .showCallsTab:
            return 5
        case .statusBar:
            return 6
        case .inAppSounds:
            return 7
        case .shortcuts:
            return 8
        case .enableRFTCopy:
            return 9
        case .openChatAtLaunch:
            return 10
        case .acceptSecretChats:
            return 11
        case .forceTouchReply:
            return 12
        case .forceTouchEdit:
            return 13
        case .forceTouchForward:
            return 14
        case .forceTouchPreviewMedia:
            return 15
        case .enterBehavior:
            return 16
        case .cmdEnterBehavior:
            return 17
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    var sortIndex:Int {
        switch self {
        case let .header(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .showCallsTab(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .enableRFTCopy(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .openChatAtLaunch(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .acceptSecretChats(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .sidebar(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .inAppSounds(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .shortcuts(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .emojiReplacements(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .predictEmoji(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .bigEmoji(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .statusBar(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .enterBehavior(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .cmdEnterBehavior(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchReply(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchEdit(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchForward(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchPreviewMedia(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    func item(_ arguments:GeneralSettingsArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId, viewType: .separator)
        case let .header(sectionId: _, uniqueId: _, text: text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0), viewType: .textTopItem)
        case let .showCallsTab(sectionId: _, enabled: enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsShowCallsTab, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleCallsTab(!enabled)
            })
        case let .enableRFTCopy(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsCopyRTF, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleRTFEnabled(!enabled)
            })
        case let .openChatAtLaunch(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsOpenLatestChatOnLaunch, type: .switchable(enabled), viewType: viewType, action: {
                arguments.openChatAtLaunch(!enabled)
            })
        case let .acceptSecretChats(_, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsAcceptSecretChats, type: .switchable(enabled), viewType: viewType, action: {
                arguments.acceptSecretChats(!enabled)
            })
        case let .sidebar(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEnableSidebar, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleSidebar(!enabled)
            })
        case let .inAppSounds(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsInAppSounds, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleInAppSounds(!enabled)
            })
        case let .shortcuts(_, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Shortcuts", type: .next, viewType: viewType, action: {
                arguments.openShortcuts()
            })
        case let .emojiReplacements(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEmojiReplacements, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleEmojiReplacements(!enabled)
            })
        case let .predictEmoji(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEmojiPrediction, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleEmojiPrediction(!enabled)
            })
        case let .bigEmoji(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsBigEmoji, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleBigEmoji(!enabled)
            })
        case let .statusBar(sectionId: _, enabled, viewType):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsStatusBarItem, type: .switchable(enabled), viewType: viewType, action: {
                arguments.toggleStatusBar(!enabled)
            })
        case let .enterBehavior(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsSendByEnter, type: .selectable(enabled), viewType: viewType, action: {
                arguments.toggleInput(.enter)
            })
        case let .cmdEnterBehavior(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsSendByCmdEnter, type: .selectable(enabled), viewType: viewType, action: {
                arguments.toggleInput(.cmdEnter)
            })
        case let .forceTouchEdit(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchEdit, type: .selectable(enabled), viewType: viewType, action: {
                arguments.toggleForceTouchAction(.edit)
            })
        case let .forceTouchReply(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchReply, type: .selectable(enabled), viewType: viewType, action: {
               arguments.toggleForceTouchAction(.reply)
            })
        case let .forceTouchForward(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchForward, type: .selectable(enabled), viewType: viewType, action: {
                arguments.toggleForceTouchAction(.forward)
            })
        case let .forceTouchPreviewMedia(sectionId: _, enabled, viewType):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchPreviewMedia, type: .selectable(enabled), viewType: viewType, action: {
                arguments.toggleForceTouchAction(.previewMedia)
            })
        }
    }
}
private func <(lhs: GeneralSettingsEntry, rhs: GeneralSettingsEntry) -> Bool {
    return lhs.sortIndex < rhs.sortIndex
}

private final class GeneralSettingsArguments {
    let context:AccountContext
    let toggleCallsTab:(Bool) -> Void
    let toggleInAppKeys:(Bool) -> Void
    let toggleInput:(SendingType)-> Void
    let toggleSidebar:(Bool) -> Void
    let toggleInAppSounds:(Bool) -> Void
    let toggleEmojiReplacements:(Bool) -> Void
    let toggleForceTouchAction:(ForceTouchAction) -> Void
	let toggleInstantViewScrollBySpace:(Bool) -> Void
    let toggleAutoplayGifs:(Bool) -> Void
    let toggleEmojiPrediction: (Bool)->Void
    let toggleBigEmoji: (Bool) -> Void
    let toggleStatusBar: (Bool) -> Void
    let toggleRTFEnabled: (Bool) -> Void
    let openChatAtLaunch:(Bool)->Void
    let acceptSecretChats:(Bool)->Void
    let toggleWorkMode:(Bool)->Void
    let openShortcuts: ()->Void
    init(context:AccountContext, toggleCallsTab:@escaping(Bool)-> Void, toggleInAppKeys: @escaping(Bool) -> Void, toggleInput: @escaping(SendingType)-> Void, toggleSidebar: @escaping (Bool) -> Void, toggleInAppSounds: @escaping (Bool) -> Void, toggleEmojiReplacements:@escaping(Bool) -> Void, toggleForceTouchAction: @escaping(ForceTouchAction)->Void, toggleInstantViewScrollBySpace: @escaping(Bool)->Void, toggleAutoplayGifs:@escaping(Bool) -> Void, toggleEmojiPrediction: @escaping(Bool) -> Void, toggleBigEmoji: @escaping(Bool) -> Void, toggleStatusBar: @escaping(Bool) -> Void, toggleRTFEnabled: @escaping(Bool)->Void, openChatAtLaunch:@escaping(Bool)->Void, acceptSecretChats: @escaping(Bool)->Void, toggleWorkMode:@escaping(Bool)->Void, openShortcuts: @escaping()->Void) {
        self.context = context
        self.toggleCallsTab = toggleCallsTab
        self.toggleInAppKeys = toggleInAppKeys
        self.toggleInput = toggleInput
        self.toggleSidebar = toggleSidebar
        self.toggleInAppSounds = toggleInAppSounds
        self.toggleEmojiReplacements = toggleEmojiReplacements
        self.toggleForceTouchAction = toggleForceTouchAction
		self.toggleInstantViewScrollBySpace = toggleInstantViewScrollBySpace
        self.toggleAutoplayGifs = toggleAutoplayGifs
        self.toggleEmojiPrediction = toggleEmojiPrediction
        self.toggleBigEmoji = toggleBigEmoji
        self.toggleStatusBar = toggleStatusBar
        self.toggleRTFEnabled = toggleRTFEnabled
        self.openChatAtLaunch = openChatAtLaunch
        self.acceptSecretChats = acceptSecretChats
        self.toggleWorkMode = toggleWorkMode
        self.openShortcuts = openShortcuts
    }
   
}

private func generalSettingsEntries(arguments:GeneralSettingsArguments, baseSettings: BaseApplicationSettings, appearance: Appearance, launchSettings: LaunchSettings, secretChatSettings: SecretChatSettings) -> [GeneralSettingsEntry] {
    var sectionId:Int = 1
    var entries:[GeneralSettingsEntry] = []
    
    var headerUnique:Int = -1
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: L10n.generalSettingsEmojiAndStickers))
    headerUnique -= 1
    
    entries.append(.sidebar(sectionId: sectionId, enabled: FastSettings.sidebarEnabled, viewType: .firstItem))
    entries.append(.emojiReplacements(sectionId: sectionId, enabled: FastSettings.isPossibleReplaceEmojies, viewType: .innerItem))
    if !baseSettings.predictEmoji {
        entries.append(.predictEmoji(sectionId: sectionId, enabled: baseSettings.predictEmoji, viewType: .innerItem))
    }
    entries.append(.bigEmoji(sectionId: sectionId, enabled: baseSettings.bigEmoji, viewType: .lastItem))

    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: L10n.generalSettingsInterfaceHeader))
    headerUnique -= 1
    entries.append(.showCallsTab(sectionId: sectionId, enabled: baseSettings.showCallsTab, viewType: .firstItem))
    entries.append(.statusBar(sectionId: sectionId, enabled: baseSettings.statusBar, viewType: .innerItem))
    entries.append(.inAppSounds(sectionId: sectionId, enabled: FastSettings.inAppSounds, viewType: .innerItem))
    entries.append(.shortcuts(sectionId: sectionId, viewType: .lastItem))


   
	
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: L10n.generalSettingsAdvancedHeader))
    headerUnique -= 1
    entries.append(.enableRFTCopy(sectionId: sectionId, enabled: FastSettings.enableRTF, viewType: .firstItem))
    entries.append(.openChatAtLaunch(sectionId: sectionId, enabled: launchSettings.openAtLaunch, viewType: .innerItem))
    entries.append(.acceptSecretChats(sectionId: sectionId, enabled: secretChatSettings.acceptOnThisDevice, viewType: .lastItem))
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: L10n.generalSettingsForceTouchHeader))
    headerUnique -= 1
    
    entries.append(.forceTouchReply(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .reply, viewType: .firstItem))
    entries.append(.forceTouchEdit(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .edit, viewType: .innerItem))
    entries.append(.forceTouchForward(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .forward, viewType: .lastItem))
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: L10n.generalSettingsInputSettings))
    headerUnique -= 1
    entries.append(.enterBehavior(sectionId: sectionId, enabled: FastSettings.sendingType == .enter, viewType: .firstItem))
    entries.append(.cmdEnterBehavior(sectionId: sectionId, enabled: FastSettings.sendingType == .cmdEnter, viewType: .lastItem))
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1

    
    return entries
}

private func prepareEntries(left: [AppearanceWrapperEntry<GeneralSettingsEntry>], right: [AppearanceWrapperEntry<GeneralSettingsEntry>], arguments: GeneralSettingsArguments, initialSize: NSSize) -> TableUpdateTransition {
    let (removed, inserted, updated)  = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class GeneralSettingsViewController: TableViewController {
    
    private let disposable = MetaDisposable()
    override var removeAfterDisapper:Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
       
        let context = self.context
        let inputPromise:ValuePromise<SendingType> = ValuePromise(FastSettings.sendingType, ignoreRepeated: true)
        
        let forceTouchPromise:ValuePromise<ForceTouchAction> = ValuePromise(FastSettings.forceTouchAction, ignoreRepeated: true)
        
        let arguments = GeneralSettingsArguments(context: context, toggleCallsTab: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedShowCallsTab(enable)
            }).start()
        }, toggleInAppKeys: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedInAppKeyHandle(enable)
            }).start()
        }, toggleInput: { input in
            FastSettings.changeSendingType(input)
            inputPromise.set(input)
        }, toggleSidebar: { enable in
            FastSettings.toggleSidebar(enable)
        }, toggleInAppSounds: { enable in
            FastSettings.toggleInAppSouds(enable)
        }, toggleEmojiReplacements: { enable in
            FastSettings.toggleAutomaticReplaceEmojies(enable)
        }, toggleForceTouchAction: { action in
            FastSettings.toggleForceTouchAction(action)
            forceTouchPromise.set(action)
		}, toggleInstantViewScrollBySpace: { enable in
			FastSettings.toggleInstantViewScrollBySpace(enable)
        }, toggleAutoplayGifs: { enable in
            FastSettings.toggleAutoPlayGifs(enable)
        }, toggleEmojiPrediction: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedPredictEmoji(enable)
            }).start()
        }, toggleBigEmoji: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedBigEmoji(enable)
            }).start()
        }, toggleStatusBar: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedStatusBar(enable)
            }).start()
        }, toggleRTFEnabled: { enable in
            FastSettings.enableRTF = enable
        }, openChatAtLaunch: { enable in
            _ = updateLaunchSettings(context.account.postbox, {
                $0.withUpdatedOpenAtLaunch(enable)
            }).start()
        }, acceptSecretChats: { enable in
            _ = context.account.postbox.transaction({ transaction -> Void in
                transaction.updatePreferencesEntry(key: PreferencesKeys.secretChatSettings, { _ in
                   return SecretChatSettings(acceptOnThisDevice: enable)
                })
            }).start()
        }, toggleWorkMode: { value in
            
        }, openShortcuts: {
            context.sharedContext.bindings.rootNavigation().push(ShortcutListController(context: context))
        })
        
        let initialSize = atomicSize
        
        let previos:Atomic<[AppearanceWrapperEntry<GeneralSettingsEntry>]> = Atomic(value: [])
        
        let baseSettingsSignal: Signal<BaseApplicationSettings, NoError> = .single(context.sharedContext.baseSettings) |> then(baseAppSettings(accountManager: context.sharedContext.accountManager))
        
        let signal = combineLatest(queue: prepareQueue, baseSettingsSignal, inputPromise.get(), forceTouchPromise.get(), appearanceSignal, appLaunchSettings(postbox: context.account.postbox), context.account.postbox.preferencesView(keys: [PreferencesKeys.secretChatSettings])) |> map { settings, _, _, appearance, launchSettings, preferencesView -> TableUpdateTransition in
            
            let baseSettings: BaseApplicationSettings = settings
            
            let secretChatSettings = preferencesView.values[PreferencesKeys.secretChatSettings] as? SecretChatSettings ?? SecretChatSettings.defaultSettings
            
            let entries = generalSettingsEntries(arguments: arguments, baseSettings: baseSettings, appearance: appearance, launchSettings: launchSettings, secretChatSettings: secretChatSettings).map({AppearanceWrapperEntry(entry: $0, appearance: appearance)})
            let previous = previos.swap(entries)
            return prepareEntries(left: previous, right: entries, arguments: arguments, initialSize: initialSize.modify({$0}))
            
        } |> deliverOnMainQueue
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with:  transition)
            self?.readyOnce()
        }))
                
    }
    
    private var loggerClickCount = 0

    private func incrementLogClick() {
        loggerClickCount += 1
        let context = self.context
        if loggerClickCount == 5 {
            UserDefaults.standard.set(!UserDefaults.standard.bool(forKey: "enablelogs"), forKey: "enablelogs")
            let logs = Logger.shared.collectLogs() |> deliverOnMainQueue |> mapToSignal { logs -> Signal<Void, NoError> in
                return selectModalPeers(context: context, title: "Send Logs", limit: 1, confirmation: {_ in return confirmSignal(for: mainWindow, information: "Are you sure you want send logs?")}) |> filter {!$0.isEmpty} |> map {$0.first!} |> mapToSignal { peerId -> Signal<Void, NoError> in
                    let messages = logs.map { (name, path) -> EnqueueMessage in
                        let id = arc4random64()
                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), partialReference: nil, resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], immediateThumbnailData: nil, mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                        return .message(text: "", attributes: [], mediaReference: AnyMediaReference.standalone(media: file), replyToMessageId: nil, localGroupingKey: nil)
                    }
                    return enqueueMessages(context: context, peerId: peerId, messages: messages) |> map {_ in}
                }
            }
            _ = logs.start()
        }
    }
    
    func sendLogs() {
        
    }
    
    deinit {
        disposable.dispose()
    }

    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.window?.set(handler: { [weak self] () -> KeyHandlerResult in
            self?.incrementLogClick()
            return .invoked
        }, with: self, for: .L, modifierFlags: [.control])
    }
    

    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        window?.removeAllHandlers(for: self)
    }
   
}


