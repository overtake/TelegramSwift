//
//  AppearanceViewController.swift
//  Telegram
//
//  Created by keepcoder on 07/07/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac

private final class AppearanceViewArguments {
    let account:Account
    let togglePalette:(ColorPalette)->Void
    let toggleBubbles:(Bool)->Void
    let toggleFontSize:(Int32)->Void
    let selectAccentColor:()->Void
    init(account:Account, togglePalette: @escaping(ColorPalette)->Void, toggleBubbles: @escaping(Bool)->Void, toggleFontSize: @escaping(Int32)->Void, selectAccentColor: @escaping()->Void) {
        self.account = account
        self.togglePalette = togglePalette
        self.toggleBubbles = toggleBubbles
        self.toggleFontSize = toggleFontSize
        self.selectAccentColor = selectAccentColor
    }
}

private enum AppearanceViewEntry : TableItemListNodeEntry {
    case colorPalette(Int32, Int32, Bool, ColorPalette)
    case chatView(Int32, Int32, Bool, Bool)
    case accentColor(Int32, Int32, NSColor)
    case section(Int32)
    case preview(Int32, Int32, ChatHistoryEntry)
    case font(Int32, Int32, Int32, [Int32])
    case description(Int32, Int32, String)
    
    var stableId: Int32 {
        switch self {
        case .colorPalette(_, let index, _, _):
            return index
        case .chatView(_, let index, _, _):
            return index
        case .accentColor(_, let index, _):
            return index
        case .section(let section):
            return section + 1000
        case .font(_, let index, _, _):
            return index
        case let .preview(_, index, _):
            return index
        case let .description(section, index, _):
            return (section * 1000) + (index + 1) * 1000
        }
    }
    
    var index:Int32 {
        switch self {
        case let .colorPalette(section, index, _, _):
            return (section * 1000) + index
        case let .chatView(section, index, _, _):
            return (section * 1000) + index
        case let .accentColor(section, index, _):
            return (section * 1000) + index
        case .section(let section):
            return (section + 1) * 1000 - section
        case let .font(section, index, _, _):
            return (section * 1000) + index
        case let .preview(section, id, _):
            return (section * 1000) + id
        case let .description(section, index, _):
            return (section * 1000) + index + 2
        }
    }
    
    func item(_ arguments: AppearanceViewArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .colorPalette(_, _, selected, palette):
            let localizationKey = "AppearanceSettings.ColorTheme." + palette.name.lowercased().replacingOccurrences(of: " ", with: "_")
            let localized = _NSLocalizedString(localizationKey)
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: localized != localizationKey ? localized : palette.name, type: .selectable(stateback: { () -> Bool in
                return selected
            }), action: {
                arguments.togglePalette(palette)
            })
        case let .chatView(_, _, selected, value):
            //, description: tr(L10n.generalSettingsDarkModeDescription)
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: !value ? tr(L10n.appearanceSettingsChatViewClassic) : tr(L10n.appearanceSettingsChatViewBubbles), type: .selectable(stateback: { () -> Bool in
                return selected
            }), action: {
                arguments.toggleBubbles(value)
            })
        case let .accentColor(_, _, color):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: tr(L10n.generalSettingsAccentColor), type: .colorSelector(stateback: { () -> NSColor in
                return color
            }), action: {
                arguments.selectAccentColor()
            })
        case .description(_, _, let text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, drawCustomSeparator: true, inset: NSEdgeInsets(left: 30.0, right: 30.0, top:2, bottom:6))
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .font(_, _, current, sizes):
            return TextSizeSettingsRowItem(initialSize, stableId: stableId, current: current, sizes: sizes, selectAction: { index in
                arguments.toggleFontSize(sizes[index])
            })
        case let .preview(_, _, entry):
            let item = ChatRowItem.item(initialSize, from: entry, with: arguments.account, interaction: ChatInteraction(peerId: PeerId(0), account: arguments.account, disableSelectAbility: true))
            _ = item.makeSize(initialSize.width, oldWidth: 0)
            return item
        }
    }
}
private func ==(lhs: AppearanceViewEntry, rhs: AppearanceViewEntry) -> Bool {
    switch lhs {
    case let .colorPalette(lhsSection, lhsIndex, lhsSelected, lhsPalette):
        if case let .colorPalette(rhsSection, rhsIndex, rhsSelected, rhsPalette) = rhs {
            return lhsSection == rhsSection && lhsIndex == rhsIndex && lhsSelected == rhsSelected && lhsPalette == rhsPalette
        } else {
            return false
        }
    case let .chatView(section, index, selected, value):
        if case .chatView(section, index, selected, value) = rhs {
            return true
        } else {
            return false
        }
    case let .accentColor(section, index, color):
        if case .accentColor(section, index, color) = rhs {
            return true
        } else {
            return false
        }
    case .section(let section):
        if case .section(section) = rhs {
            return true
        } else {
            return false
        }
    case let .preview(section, index, entry):
        if case .preview(section, index, entry) = rhs {
            return true
        } else {
            return false
        }
    case let .font(section, index, current, _):
        if case .font(section, index, current, _) = rhs {
            return true
        } else {
            return false
        }
    case let .description(section, index, description):
        if case .description(section, index, description) = rhs {
            return true
        } else {
            return false
        }
    }
}
private func <(lhs: AppearanceViewEntry, rhs: AppearanceViewEntry) -> Bool {
    return lhs.index < rhs.index
}

private func AppearanceViewEntries(settings: TelegramPresentationTheme, selfPeer: Peer) -> [AppearanceViewEntry] {
    var entries:[AppearanceViewEntry] = []
    
    var sectionId:Int32 = 1
    var descIndex:Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    
    var index: Int32 = 0
    
    entries.append(.description(sectionId, descIndex, tr(L10n.appearanceSettingsTextSizeHeader)))
    descIndex += 1
    
    let sizes:[Int32] = [11, 12, 13, 14, 15]
    
    let current = sizes.index(of: Int32(settings.fontSize)) ?? 2
        
    entries.append(.font(sectionId, index, Int32(current), sizes))
    index += 1
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    
    entries.append(.description(sectionId, descIndex, tr(L10n.appearanceSettingsChatPreviewHeader)))
    descIndex += 1
    
    let fromUser1 = TelegramUser(id: PeerId(1), accessHash: nil, firstName: tr(L10n.appearanceSettingsChatPreviewUserName1), lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, flags: [])
    
    let fromUser2 = TelegramUser(id: PeerId(2), accessHash: nil, firstName: tr(L10n.appearanceSettingsChatPreviewUserName2), lastName: "", username: nil, phone: nil, photo: [], botInfo: nil, flags: [])

    
    entries.append(.section(sectionId))
    sectionId += 1
    
    let replyMessage = Message(stableId: 2, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], forwardInfo: nil, author: fromUser1, text: tr(L10n.appearanceSettingsChatPreviewZeroText), attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])

    
    let firstMessage = Message(stableId: 0, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 0), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 20 + 60*60*18, flags: [.Incoming], tags: [], globalTags: [], forwardInfo: nil, author: fromUser2, text: tr(L10n.appearanceSettingsChatPreviewFirstText), attributes: [ReplyMessageAttribute(messageId: replyMessage.id)], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2]) , associatedMessages: SimpleDictionary([replyMessage.id : replyMessage]), associatedMessageIds: [])
    
    let firstEntry: ChatHistoryEntry = .MessageEntry(firstMessage, true, settings.bubbled ? .bubble : .list, .Full(isAdmin: false), nil, nil)
    
    entries.append(.preview(sectionId, index, firstEntry))
    index += 1
    
    let secondMessage = Message(stableId: 1, stableVersion: 0, id: MessageId(peerId: fromUser1.id, namespace: 0, id: 1), globallyUniqueId: 0, groupingKey: 0, groupInfo: nil, timestamp: 60 * 22 + 60*60*18, flags: [], tags: [], globalTags: [], forwardInfo: nil, author: fromUser1, text: tr(L10n.appearanceSettingsChatPreviewSecondText), attributes: [], media: [], peers:SimpleDictionary([fromUser2.id : fromUser2, fromUser1.id : fromUser1]) , associatedMessages: SimpleDictionary(), associatedMessageIds: [])
    
    let secondEntry: ChatHistoryEntry = .MessageEntry(secondMessage, true, settings.bubbled ? .bubble : .list, .Full(isAdmin: false), nil, nil)
    
    entries.append(.preview(sectionId, index, secondEntry))
    index += 1
    
    #if BETA || DEBUG
        if settings.colors == whitePalette {
            
            entries.append(.section(sectionId))
            sectionId += 1
            
            entries.append(.accentColor(sectionId, index, theme.colors.blueUI))
            index += 1
        }
    #endif
    
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, tr(L10n.appearanceSettingsColorThemeHeader)))
    descIndex += 1
    
    
    var installed:[String: ColorPalette] = [:]

    installed[whitePalette.name] = whitePalette
    installed[darkPalette.name] = darkPalette
    
    entries.append(.colorPalette(sectionId, index, settings.colors == whitePalette, whitePalette))
    index += 1
    
    entries.append(.colorPalette(sectionId, index, settings.colors == darkPalette, darkPalette))
    index += 1
    
    if installed[settings.colors.name] == nil {
        installed[settings.colors.name] = settings.colors
        entries.append(.colorPalette(sectionId, index, true, settings.colors))
        index += 1
    }
    
    
    var paths = Bundle.main.paths(forResourcesOfType: "palette", inDirectory: "palettes")
    let globalPalettes = "~/Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/Palettes/".nsstring.expandingTildeInPath + "/"
    paths += ((try? FileManager.default.contentsOfDirectory(atPath: globalPalettes)) ?? []).map({globalPalettes + $0})
    
    let palettes = paths.map{importPalette($0)}.filter{$0 != nil}.map{$0!}
    
    for palette in palettes {
        if palette != whitePalette && palette != darkPalette && palette != settings.colors, installed[palette.name] == nil {
            installed[palette.name] = palette
            entries.append(.colorPalette(sectionId, index, false, palette))
            index += 1
        }
    }
    
    var bp:Int = 0
    bp += 1
    
    entries.append(.section(sectionId))
    sectionId += 1
    
    entries.append(.description(sectionId, descIndex, tr(L10n.appearanceSettingsChatViewHeader)))
    descIndex += 1
    
    entries.append(.chatView(sectionId, index, !settings.bubbled, false))
    index += 1
    entries.append(.chatView(sectionId, index, settings.bubbled, true))
    index += 1
    

    entries.append(.section(sectionId))
    sectionId += 1

    
    
    
  
//
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<AppearanceViewEntry>], right: [AppearanceWrapperEntry<AppearanceViewEntry>], initialSize:NSSize, arguments:AppearanceViewArguments) -> TableUpdateTransition {
    
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

class AppearanceViewController: TableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let account = self.account
        let arguments = AppearanceViewArguments(account: account, togglePalette: { palette in
            _ = updateThemeSettings(postbox: account.postbox, palette: palette).start()
        }, toggleBubbles: { enabled in
            _ = updateBubbledSettings(postbox: account.postbox, bubbled: enabled).start()
        }, toggleFontSize: { size in
            _ = updateApplicationFontSize(postbox: account.postbox, fontSize: CGFloat(size)).start()
        }, selectAccentColor: {
            showModal(with: AccentColorModalController(account, current: theme.colors.blueUI), for: mainWindow)
        })
        
        let initialSize = self.atomicSize

        
        let previous: Atomic<[AppearanceWrapperEntry<AppearanceViewEntry>]> = Atomic(value: [])
        genericView.merge(with: combineLatest(appearanceSignal |> deliverOnPrepareQueue, account.postbox.loadedPeerWithId(account.peerId)) |> map { appearance, selfPeer in
            let entries = AppearanceViewEntries(settings: appearance.presentation, selfPeer: selfPeer).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> deliverOnMainQueue)
        readyOnce()
        
    }
    
    override func firstResponder() -> NSResponder? {
       return genericView.item(stableId: Int32(1))?.view?.firstResponder
    }
    
}
