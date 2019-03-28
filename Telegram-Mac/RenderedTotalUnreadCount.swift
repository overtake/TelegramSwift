import Foundation
import PostboxMac
import SwiftSignalKitMac

enum RenderedTotalUnreadCountType {
    case raw
    case filtered
}

func renderedTotalUnreadCount(transaction: Transaction) -> (Int32, RenderedTotalUnreadCountType) {
    let totalUnreadState = transaction.getTotalUnreadState()
    let inAppSettings: InAppNotificationSettings = (transaction.getPreferencesEntry(key: ApplicationSharedPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings) ?? .defaultSettings
    let type: RenderedTotalUnreadCountType
    switch inAppSettings.totalUnreadCountDisplayStyle {
        case .raw:
            type = .raw
        case .filtered:
            type = .filtered
    }
    return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
}

func renderedTotalUnreadCount(inAppSettings: InAppNotificationSettings, totalUnreadState: ChatListTotalUnreadState) -> (Int32, RenderedTotalUnreadCountType) {
    let type: RenderedTotalUnreadCountType
    switch inAppSettings.totalUnreadCountDisplayStyle {
    case .raw:
        type = .raw
    case .filtered:
        type = .filtered
    }
    return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
}

func renderedTotalUnreadCount(accountManager: AccountManager, postbox: Postbox) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    let unreadCountsKey = PostboxViewKey.unreadCounts(items: [.total(nil)])
    return combineLatest(accountManager.sharedData(keys: [ApplicationSharedPreferencesKeys.inAppNotificationSettings]), postbox.combinedView(keys: [unreadCountsKey]))
        |> map { sharedData, view -> (Int32, RenderedTotalUnreadCountType) in
            let totalUnreadState: ChatListTotalUnreadState
            if let value = view.views[unreadCountsKey] as? UnreadMessageCountsView, let (_, total) = value.total() {
                totalUnreadState = total
            } else {
                totalUnreadState = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
            }
            
            let inAppSettings: InAppNotificationSettings
            if let value = sharedData.entries[ApplicationSharedPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                inAppSettings = value
            } else {
                inAppSettings = .defaultSettings
            }
            let type: RenderedTotalUnreadCountType
            switch inAppSettings.totalUnreadCountDisplayStyle {
            case .raw:
                type = .raw
            case .filtered:
                type = .filtered
            }
            return (totalUnreadState.count(for: inAppSettings.totalUnreadCountDisplayStyle.category, in: inAppSettings.totalUnreadCountDisplayCategory.statsType, with: inAppSettings.totalUnreadCountIncludeTags), type)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs == rhs
        })
}
