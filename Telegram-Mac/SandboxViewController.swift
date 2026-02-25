//
//  SandboxViewController.swift
//  Telegram-Mac
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

private final class SandboxArguments {
    let toggleHideStories: () -> Void
    let toggleHideChannelsFromSearch: () -> Void
    init(toggleHideStories: @escaping () -> Void, toggleHideChannelsFromSearch: @escaping () -> Void) {
        self.toggleHideStories = toggleHideStories
        self.toggleHideChannelsFromSearch = toggleHideChannelsFromSearch
    }
}

private enum SandboxEntryId: Hashable {
    case hideStories
    case hideChannelsFromSearch
    case section(Int32)
}

private enum SandboxEntry: TableItemListNodeEntry {
    typealias ItemGenerationArguments = SandboxArguments

    case hideStories(sectionId: Int32, enabled: Bool)
    case hideChannelsFromSearch(sectionId: Int32, enabled: Bool)
    case section(Int32)

    var stableId: SandboxEntryId {
        switch self {
        case .hideStories: return .hideStories
        case .hideChannelsFromSearch: return .hideChannelsFromSearch
        case .section(let s): return .section(s)
        }
    }

    var id: SandboxEntryId { stableId }

    var index: Int32 {
        switch self {
        case .hideStories(let sectionId, _): return sectionId * 1000
        case .hideChannelsFromSearch(let sectionId, _): return sectionId * 1000 + 1
        case .section(let sectionId): return (sectionId + 1) * 1000 - sectionId
        }
    }

    static func < (lhs: SandboxEntry, rhs: SandboxEntry) -> Bool { lhs.index < rhs.index }

    func item(_ arguments: SandboxArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .hideStories(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Скрыть сторис", type: .switchable(enabled), action: arguments.toggleHideStories)
        case let .hideChannelsFromSearch(_, enabled):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: "Скрыть каналы из поиска", type: .switchable(enabled), action: arguments.toggleHideChannelsFromSearch)
        case .section:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private func sandboxEntries() -> [SandboxEntry] {
    var entries: [SandboxEntry] = []
    var sectionId: Int32 = 1
    entries.append(.section(sectionId))
    sectionId += 1
    entries.append(.hideStories(sectionId: sectionId, enabled: FastSettings.hideStories))
    entries.append(.hideChannelsFromSearch(sectionId: sectionId, enabled: FastSettings.hideChannelsFromSearch))
    return entries
}

class SandboxViewController: TableViewController {

    init(context: AccountContext) {
        super.init(context)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        genericView.getBackgroundColor = { theme.colors.background }

        let previousEntries: Atomic<[AppearanceWrapperEntry<SandboxEntry>]> = Atomic(value: [])
        let initialSize = self.atomicSize
        let refreshCounter = Atomic<Int>(value: 0)
        let refreshPromise = ValuePromise<Int>(0, ignoreRepeated: true)
        let arguments = SandboxArguments(
            toggleHideStories: {
                FastSettings.hideStories = !FastSettings.hideStories
                refreshPromise.set(refreshCounter.modify { $0 + 1 })
            },
            toggleHideChannelsFromSearch: {
                FastSettings.hideChannelsFromSearch = !FastSettings.hideChannelsFromSearch
                refreshPromise.set(refreshCounter.modify { $0 + 1 })
            }
        )

        genericView.merge(with: combineLatest(appearanceSignal, refreshPromise.get()) |> map { (appearance: Appearance, _: Int) in
            let entries = sandboxEntries().map { AppearanceWrapperEntry(entry: $0, appearance: appearance) }
            let (removed, inserted, updated) = proccessEntriesWithoutReverse(previousEntries.swap(entries), right: entries) { entry in
                entry.entry.item(arguments, initialSize: initialSize.modify { $0 })
            }
            return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
        } |> deliverOnMainQueue)

        readyOnce()
    }

    override var defaultBarTitle: String {
        return "Sandbox"
    }
}
