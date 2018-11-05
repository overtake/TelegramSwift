import Foundation
import PostboxMac
import SwiftSignalKitMac

enum RenderedTotalUnreadCountType {
    case raw
    case filtered
}

func renderedTotalUnreadCount(transaction: Transaction) -> (Int32, RenderedTotalUnreadCountType) {
    let totalUnreadState = transaction.getTotalUnreadState()
    let inAppSettings: InAppNotificationSettings = (transaction.getPreferencesEntry(key: ApplicationSpecificPreferencesKeys.inAppNotificationSettings) as? InAppNotificationSettings) ?? .defaultSettings
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

func renderedTotalUnreadCount(postbox: Postbox) -> Signal<(Int32, RenderedTotalUnreadCountType), NoError> {
    let unreadCountsKey = PostboxViewKey.unreadCounts(items: [.total(ApplicationSpecificPreferencesKeys.inAppNotificationSettings)])
    return postbox.combinedView(keys: [unreadCountsKey])
    |> map { view -> (Int32, RenderedTotalUnreadCountType) in
        let totalUnreadState: ChatListTotalUnreadState
        let inAppSettings: InAppNotificationSettings
        if let value = view.views[unreadCountsKey] as? UnreadMessageCountsView, let total = value.total() {
            totalUnreadState = total.1
            if let preferences = total.0 as? InAppNotificationSettings {
                inAppSettings = preferences
            } else {
                inAppSettings = .defaultSettings
            }
                
        } else {
            totalUnreadState = ChatListTotalUnreadState(absoluteCounters: [:], filteredCounters: [:])
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
