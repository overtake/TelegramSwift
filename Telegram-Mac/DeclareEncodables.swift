//
//  DeclareEncodables.swift
//  Telegram-Mac
//
//  Created by keepcoder on 04/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Postbox

private var telegramUIDeclaredEncodables: Void = {
    declareEncodable(ChatInterfaceState.self, f: { ChatInterfaceState(decoder: $0) })
    declareEncodable(InAppNotificationSettings.self, f: { InAppNotificationSettings(decoder: $0) })
    declareEncodable(BaseApplicationSettings.self, f: { BaseApplicationSettings(decoder: $0) })
    declareEncodable(ThemePaletteSettings.self, f: { ThemePaletteSettings(decoder: $0) })
    declareEncodable(LocalFileGifMediaResource.self, f: { LocalFileGifMediaResource(decoder: $0) })
    declareEncodable(LocalFileVideoMediaResource.self, f: { LocalFileVideoMediaResource(decoder: $0) })
    declareEncodable(LocalFileArchiveMediaResource.self, f: { LocalFileArchiveMediaResource(decoder: $0) })
    declareEncodable(RecentUsedEmoji.self, f: { RecentUsedEmoji(decoder: $0) })
    declareEncodable(InstantViewAppearance.self, f: { InstantViewAppearance(decoder: $0) })
    declareEncodable(IVReadState.self, f: { IVReadState(decoder: $0) })
    declareEncodable(AdditionalSettings.self, f: { AdditionalSettings(decoder: $0) })
    declareEncodable(AutomaticMediaDownloadCategoryPeers.self, f: { AutomaticMediaDownloadCategoryPeers(decoder: $0) })
    declareEncodable(AutomaticMediaDownloadCategories.self, f: { AutomaticMediaDownloadCategories(decoder: $0) })
    declareEncodable(AutomaticMediaDownloadSettings.self, f: { AutomaticMediaDownloadSettings(decoder: $0) })
    declareEncodable(ReadArticle.self, f: { ReadArticle(decoder: $0) })
    declareEncodable(ReadArticlesListPreferences.self, f: { ReadArticlesListPreferences(decoder: $0) })
    declareEncodable(AutoNightThemePreferences.self, f: { AutoNightThemePreferences(decoder: $0) })
    declareEncodable(StickerSettings.self, f: { StickerSettings(decoder: $0) })
    declareEncodable(EmojiSkinModifier.self, f: { AutoNightThemePreferences(decoder: $0) })
    declareEncodable(InstantPageStoredDetailsState.self, f: { InstantPageStoredDetailsState(decoder: $0) })
    declareEncodable(CachedChannelAdminRanks.self, f: { CachedChannelAdminRanks(decoder: $0) })
    declareEncodable(LaunchSettings.self, f: { LaunchSettings(decoder: $0)})
    declareEncodable(AutoplayMediaPreferences.self, f: { AutoplayMediaPreferences(decoder: $0)})
    declareEncodable(VoiceCallSettings.self, f: { VoiceCallSettings(decoder: $0)})
    declareEncodable(LaunchNavigation.self, f: { LaunchNavigation(decoder: $0)})
    declareEncodable(DownloadedFilesPaths.self, f: { DownloadedFilesPaths(decoder: $0)})
    declareEncodable(DownloadedPath.self, f: { DownloadedPath(decoder: $0)})
    declareEncodable(LocalBundleResource.self, f: { LocalBundleResource(decoder: $0)})
    declareEncodable(AssociatedWallpaper.self, f: { AssociatedWallpaper(decoder: $0) })
    declareEncodable(ThemeWallpaper.self, f: { ThemeWallpaper(decoder: $0) })
    declareEncodable(DefaultTheme.self, f: { DefaultTheme(decoder: $0) })
    declareEncodable(DefaultCloudTheme.self, f: { DefaultCloudTheme(decoder: $0) })
    declareEncodable(LocalWallapper.self, f: { LocalWallapper(decoder: $0) })
    declareEncodable(LocalAccentColor.self, f: { LocalAccentColor(decoder: $0) })
    declareEncodable(WalletPasscodeTimeout.self, f: { WalletPasscodeTimeout(decoder: $0) })
    declareEncodable(PasscodeSettings.self, f: { PasscodeSettings(decoder: $0) })
    declareEncodable(CachedInstantPage.self, f: { CachedInstantPage(decoder: $0) })
    declareEncodable(RecentSettingsSearchQueryItem.self, f: { RecentSettingsSearchQueryItem(decoder: $0) })
    return
}()

public func telegramUIDeclareEncodables() {
    let _ = telegramUIDeclaredEncodables
}
