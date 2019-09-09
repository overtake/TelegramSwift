//
//  GeneralSettingsViewController.swift
//  TelegramMac
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac
import PostboxMac


private enum GeneralSettingsEntry : Comparable, Identifiable {
    case section(sectionId:Int)
    case header(sectionId: Int, uniqueId:Int, text:String)
    case handleInAppKeys(sectionId:Int, enabled:Bool)
    case darkMode(sectionId:Int, enabled: Bool)
    case sidebar(sectionId:Int, enabled: Bool)
    case autoplayGifs(sectionId:Int, enabled: Bool)
    case inAppSounds(sectionId:Int, enabled: Bool)
    case enterBehavior(sectionId:Int, enabled: Bool)
    case cmdEnterBehavior(sectionId:Int, enabled: Bool)
    case emojiReplacements(sectionId:Int, enabled: Bool)
    case predictEmoji(sectionId:Int, enabled: Bool)
    case bigEmoji(sectionId:Int, enabled: Bool)
    case statusBar(sectionId:Int, enabled: Bool)
    case showCallsTab(sectionId:Int, enabled: Bool)
    case enableRFTCopy(sectionId:Int, enabled: Bool)
    case openChatAtLaunch(sectionId:Int, enabled: Bool)
    case acceptSecretChats(sectionId:Int, enabled: Bool)
    case latestArticles(sectionId:Int, enabled: Bool)
    case forceTouchReply(sectionId:Int, enabled: Bool)
    case forceTouchEdit(sectionId:Int, enabled: Bool)
    case forceTouchForward(sectionId:Int, enabled: Bool)
    case forceTouchPreviewMedia(sectionId:Int, enabled: Bool)
	case instantViewScrollBySpace(sectionId:Int, enabled: Bool)
    var stableId: Int {
        switch self {
        case let .header(_, uniqueId, _):
            return uniqueId
        case .darkMode:
            return 0
        case .enterBehavior:
            return 1
        case .cmdEnterBehavior:
            return 2
        case .handleInAppKeys:
            return 3
        case .sidebar:
            return 4
        case .autoplayGifs:
            return 5
        case .inAppSounds:
            return 6
        case .emojiReplacements:
            return 7
        case .predictEmoji:
            return 8
        case .bigEmoji:
            return 9
        case .statusBar:
            return 10
        case .showCallsTab:
            return 11
        case .enableRFTCopy:
            return 12
        case .openChatAtLaunch:
            return 13
        case .acceptSecretChats:
            return 14
        case .latestArticles:
            return 16
        case .forceTouchReply:
            return 16
        case .forceTouchEdit:
            return 17
        case .forceTouchForward:
            return 18
        case .forceTouchPreviewMedia:
            return 19
		case .instantViewScrollBySpace:
			return 20
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    var sortIndex:Int {
        switch self {
        case let .header(sectionId, _, _):
            return (sectionId * 1000) + stableId
        case let .showCallsTab(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .enableRFTCopy(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .openChatAtLaunch(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .acceptSecretChats(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .latestArticles(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .darkMode(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .sidebar(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .autoplayGifs(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .inAppSounds(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .emojiReplacements(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .predictEmoji(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .bigEmoji(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .statusBar(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .handleInAppKeys(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .enterBehavior(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .cmdEnterBehavior(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchReply(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchEdit(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchForward(sectionId, _):
            return (sectionId * 1000) + stableId
        case let .forceTouchPreviewMedia(sectionId, _):
            return (sectionId * 1000) + stableId
		case let .instantViewScrollBySpace(sectionId, _):
			return (sectionId * 1000) + stableId
        case let .section(id):
            return (id + 1) * 1000 - id
        }
    }
    
    func item(_ arguments:GeneralSettingsArguments, initialSize:NSSize) -> TableRowItem {
        switch self {
        case .section:
            return GeneralRowItem(initialSize, height: 30, stableId: stableId)
        case let .showCallsTab(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsShowCallsTab, type: .switchable(enabled), action: {
                arguments.toggleCallsTab(!enabled)
            })
        case let .enableRFTCopy(sectionId: _, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsCopyRTF, type: .switchable(enabled), action: {
                arguments.toggleRTFEnabled(!enabled)
            })
        case let .openChatAtLaunch(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsOpenLatestChatOnLaunch, type: .switchable(enabled), action: {
                arguments.openChatAtLaunch(!enabled)
            })
        case let .acceptSecretChats(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsAcceptSecretChats, type: .switchable(enabled), action: {
                arguments.acceptSecretChats(!enabled)
            })
        case let .latestArticles(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsShowArticlesInSearch, type: .switchable(enabled), action: {
                arguments.toggleLatestArticles(!enabled)
            })
        case let .darkMode(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsDarkMode, description: L10n.generalSettingsDarkModeDescription, type: .switchable(enabled), action: {

            })
        case let .handleInAppKeys(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsMediaKeysForInAppPlayer, type: .switchable(enabled), action: {
                arguments.toggleInAppKeys(!enabled)
            })
        case let .sidebar(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEnableSidebar, type: .switchable(enabled), action: {
                arguments.toggleSidebar(!enabled)
            })
        case let .autoplayGifs(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsAutoplayGifs, type: .switchable(enabled), action: {
                arguments.toggleAutoplayGifs(!enabled)
            })
        case let .inAppSounds(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsInAppSounds, type: .switchable(enabled), action: {
                arguments.toggleInAppSounds(!enabled)
            })
        case let .emojiReplacements(sectionId: _, enabled: enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEmojiReplacements, type: .switchable(enabled), action: {
                arguments.toggleEmojiReplacements(!enabled)
            })
        case let .predictEmoji(sectionId: _, enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsEmojiPrediction, type: .switchable(enabled), action: {
                arguments.toggleEmojiPrediction(!enabled)
            })
        case let .bigEmoji(sectionId: _, enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsBigEmoji, type: .switchable(enabled), action: {
                arguments.toggleBigEmoji(!enabled)
            })
        case let .statusBar(sectionId: _, enabled):
            return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsStatusBarItem, type: .switchable(enabled), action: {
                arguments.toggleStatusBar(!enabled)
            })
        case let .header(sectionId: _, uniqueId: _, text: text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case let .enterBehavior(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsSendByEnter, type: .selectable(enabled), action: {
                arguments.toggleInput(.enter)
            })
        case let .cmdEnterBehavior(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsSendByCmdEnter, type: .selectable(enabled), action: {
                arguments.toggleInput(.cmdEnter)
            })
        case let .forceTouchEdit(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchEdit, type: .selectable(enabled), action: {
                arguments.toggleForceTouchAction(.edit)
            })
        case let .forceTouchReply(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchReply, type: .selectable(enabled), action: {
               arguments.toggleForceTouchAction(.reply)
            })
        case let .forceTouchForward(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchForward, type: .selectable(enabled), action: {
                arguments.toggleForceTouchAction(.forward)
            })
        case let .forceTouchPreviewMedia(sectionId: _, enabled: enabled):
            return GeneralInteractedRowItem(initialSize, name: L10n.generalSettingsForceTouchPreviewMedia, type: .selectable(enabled), action: {
                arguments.toggleForceTouchAction(.previewMedia)
            })
		case let .instantViewScrollBySpace(sectionId: _, enabled: enabled):
			return  GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.generalSettingsInstantViewScrollBySpace, type: .switchable(enabled), action: {
				arguments.toggleInstantViewScrollBySpace(!enabled)
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
    let toggleLatestArticles: (Bool)->Void
    let toggleEmojiPrediction: (Bool)->Void
    let toggleBigEmoji: (Bool) -> Void
    let toggleStatusBar: (Bool) -> Void
    let toggleRTFEnabled: (Bool) -> Void
    let openChatAtLaunch:(Bool)->Void
    let acceptSecretChats:(Bool)->Void
    init(context:AccountContext, toggleCallsTab:@escaping(Bool)-> Void, toggleInAppKeys: @escaping(Bool) -> Void, toggleInput: @escaping(SendingType)-> Void, toggleSidebar: @escaping (Bool) -> Void, toggleInAppSounds: @escaping (Bool) -> Void, toggleEmojiReplacements:@escaping(Bool) -> Void, toggleForceTouchAction: @escaping(ForceTouchAction)->Void, toggleInstantViewScrollBySpace: @escaping(Bool)->Void, toggleAutoplayGifs:@escaping(Bool) -> Void, toggleLatestArticles: @escaping(Bool)->Void, toggleEmojiPrediction: @escaping(Bool) -> Void, toggleBigEmoji: @escaping(Bool) -> Void, toggleStatusBar: @escaping(Bool) -> Void, toggleRTFEnabled: @escaping(Bool)->Void, openChatAtLaunch:@escaping(Bool)->Void, acceptSecretChats: @escaping(Bool)->Void) {
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
        self.toggleLatestArticles = toggleLatestArticles
        self.toggleEmojiPrediction = toggleEmojiPrediction
        self.toggleBigEmoji = toggleBigEmoji
        self.toggleStatusBar = toggleStatusBar
        self.toggleRTFEnabled = toggleRTFEnabled
        self.openChatAtLaunch = openChatAtLaunch
        self.acceptSecretChats = acceptSecretChats
    }
   
}

private func generalSettingsEntries(arguments:GeneralSettingsArguments, baseSettings: BaseApplicationSettings, appearance: Appearance, launchSettings: LaunchSettings, secretChatSettings: SecretChatSettings) -> [GeneralSettingsEntry] {
    var sectionId:Int = 1
    var entries:[GeneralSettingsEntry] = []
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    var headerUnique:Int = -1
    
    //entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: tr(L10n.generalSettingsAppearanceSettings)))
   // headerUnique -= 1
    
    //entries.append(.darkMode(sectionId: sectionId, enabled: appearance.presentation.dark))

    
   // entries.append(.section(sectionId: sectionId))
   // sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: tr(L10n.generalSettingsInputSettings)))
    headerUnique -= 1
    
    entries.append(.enterBehavior(sectionId: sectionId, enabled: FastSettings.sendingType == .enter))
    entries.append(.cmdEnterBehavior(sectionId: sectionId, enabled: FastSettings.sendingType == .cmdEnter))
    
    
    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    

    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: tr(L10n.generalSettingsGeneralSettings)))
    headerUnique -= 1
    
    
    
    
    //entries.append(.largeFonts(sectionId: sectionId, enabled: baseSettings.fontSize > 13))
    #if !APP_STORE
    if #available(OSX 10.14, *) {} else {
        entries.append(.handleInAppKeys(sectionId: sectionId, enabled: baseSettings.handleInAppKeys))
    }
    #endif
    entries.append(.sidebar(sectionId: sectionId, enabled: FastSettings.sidebarEnabled))

    entries.append(.inAppSounds(sectionId: sectionId, enabled: FastSettings.inAppSounds))
    entries.append(.emojiReplacements(sectionId: sectionId, enabled: FastSettings.isPossibleReplaceEmojies))
    if !baseSettings.predictEmoji {
        entries.append(.predictEmoji(sectionId: sectionId, enabled: baseSettings.predictEmoji))
    }
    entries.append(.bigEmoji(sectionId: sectionId, enabled: baseSettings.bigEmoji))
    entries.append(.statusBar(sectionId: sectionId, enabled: baseSettings.statusBar))

    entries.append(.showCallsTab(sectionId: sectionId, enabled: baseSettings.showCallsTab))
    entries.append(.enableRFTCopy(sectionId: sectionId, enabled: FastSettings.enableRTF))
    entries.append(.openChatAtLaunch(sectionId: sectionId, enabled: launchSettings.openAtLaunch))
    entries.append(.acceptSecretChats(sectionId: sectionId, enabled: secretChatSettings.acceptOnThisDevice))
  //  entries.append(.latestArticles(sectionId: sectionId, enabled: baseSettings.latestArticles))


    entries.append(.section(sectionId: sectionId))
    sectionId += 1
    
    entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: tr(L10n.generalSettingsForceTouchHeader)))
    headerUnique -= 1
    
    entries.append(.forceTouchReply(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .reply))
    entries.append(.forceTouchEdit(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .edit))
    entries.append(.forceTouchForward(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .forward))
   // entries.append(.forceTouchPreviewMedia(sectionId: sectionId, enabled: FastSettings.forceTouchAction == .previewMedia))

    entries.append(.section(sectionId: sectionId))
    sectionId += 1
	
	
	entries.append(.header(sectionId: sectionId, uniqueId: headerUnique, text: tr(L10n.generalSettingsInstantViewHeader)))
	entries.append(.instantViewScrollBySpace(sectionId: sectionId, enabled: FastSettings.instantViewScrollBySpace))
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
        }, toggleLatestArticles: { enable in
            _ = updateBaseAppSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings -> BaseApplicationSettings in
                return settings.withUpdatedLatestArticles(enable)
            }).start()
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
        })
        
        let initialSize = atomicSize
        
        let previos:Atomic<[AppearanceWrapperEntry<GeneralSettingsEntry>]> = Atomic(value: [])
        
        let baseSettingsSignal: Signal<BaseApplicationSettings, NoError> = .single(context.sharedContext.baseSettings) |> then(baseAppSettings(accountManager: context.sharedContext.accountManager))
        
        let signal = combineLatest(queue: .mainQueue(), baseSettingsSignal, inputPromise.get(), forceTouchPromise.get(), appearanceSignal, appLaunchSettings(postbox: context.account.postbox), context.account.postbox.preferencesView(keys: [PreferencesKeys.secretChatSettings])) |> map { settings, _, _, appearance, launchSettings, preferencesView -> TableUpdateTransition in
            
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


