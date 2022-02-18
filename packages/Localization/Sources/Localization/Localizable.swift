// Generated using SwiftGen, by O.Halligon — https://github.com/SwiftGen/SwiftGen

import Foundation

// swiftlint:disable superfluous_disable_command
// swiftlint:disable file_length

// swiftlint:disable identifier_name line_length type_body_length
public final class L10n {
  /// %1$@ sent an invoice for %3$@ to the group %2$@
  public static func chatMessageInvoice(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "CHAT_MESSAGE_INVOICE", p1, p2, p3)
  }
  /// Default
  public static var defaultSoundName: String  { return L10n.tr("Localizable", "DefaultSoundName") }
  /// %1$@ sent you an invoice for %2$@
  public static func messageInvoice(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "MESSAGE_INVOICE", p1, p2)
  }
  /// None
  public static var notificationSettingsToneNone: String  { return L10n.tr("Localizable", "NotificationSettingsToneNone") }
  /// Incorrect password
  public static var passwordHashInvalid: String  { return L10n.tr("Localizable", "PASSWORD_HASH_INVALID") }
  /// Code expired
  public static var phoneCodeExpired: String  { return L10n.tr("Localizable", "PHONE_CODE_EXPIRED") }
  /// Invalid code
  public static var phoneCodeInvalid: String  { return L10n.tr("Localizable", "PHONE_CODE_INVALID") }
  /// Invalid phone number
  public static var phoneNumberInvalid: String  { return L10n.tr("Localizable", "PHONE_NUMBER_INVALID") }
  /// %1$@ pinned an invoice
  public static func pinnedInvoice(_ p1: String) -> String {
    return L10n.tr("Localizable", "PINNED_INVOICE", p1)
  }
  /// Share Call Logs
  public static var shareCallLogs: String  { return L10n.tr("Localizable", "ShareCallLogs") }
  /// An error occurred. Please try again later
  public static var unknownError: String  { return L10n.tr("Localizable", "UnknownError") }
  /// You
  public static var you: String  { return L10n.tr("Localizable", "You") }
  /// Your card has expired.
  public static var yourCardHasExpired: String  { return L10n.tr("Localizable", "Your_card_has_expired") }
  /// Your card was declined.
  public static var yourCardWasDeclined: String  { return L10n.tr("Localizable", "Your_card_was_declined") }
  /// You've entered an invalid expiration month.
  public static var yourCardsExpirationMonthIsInvalid: String  { return L10n.tr("Localizable", "Your_cards_expiration_month_is_invalid") }
  /// You've entered an invalid expiration year.
  public static var yourCardsExpirationYearIsInvalid: String  { return L10n.tr("Localizable", "Your_cards_expiration_year_is_invalid") }
  /// You've entered an invalid card number.
  public static var yourCardsNumberIsInvalid: String  { return L10n.tr("Localizable", "Your_cards_number_is_invalid") }
  /// You've entered an invalid security code.
  public static var yourCardsSecurityCodeIsInvalid: String  { return L10n.tr("Localizable", "Your_cards_security_code_is_invalid") }
  /// You've entered an invalid zip code.
  public static var yourCardsZipCodeIsInvalid: String  { return L10n.tr("Localizable", "Your_cards_zip_code_is_invalid") }
  /// Check for Updates
  public static var _1000Title: String  { return L10n.tr("Localizable", "1000.title") }
  /// Telegram
  public static var _1XtHYUBwTitle: String  { return L10n.tr("Localizable", "1Xt-HY-uBw.title") }
  /// Transformations
  public static var _2oIRnZJCTitle: String  { return L10n.tr("Localizable", "2oI-Rn-ZJC.title") }
  /// Enter Full Screen
  public static var _4J7DPTxaTitle: String  { return L10n.tr("Localizable", "4J7-dP-txa.title") }
  /// Quit Telegram
  public static var _4sb4sVLiTitle: String  { return L10n.tr("Localizable", "4sb-4s-VLi.title") }
  /// Edit
  public static var _5QFOaP0TTitle: String  { return L10n.tr("Localizable", "5QF-Oa-p0T.title") }
  /// About Telegram
  public static var _5kVVbQxSTitle: String  { return L10n.tr("Localizable", "5kV-Vb-QxS.title") }
  /// Redo
  public static var _6dhZSVamTitle: String  { return L10n.tr("Localizable", "6dh-zS-Vam.title") }
  /// Correct Spelling Automatically
  public static var _78YHA62vTitle: String  { return L10n.tr("Localizable", "78Y-hA-62v.title") }
  /// Substitutions
  public static var _9icFLObxTitle: String  { return L10n.tr("Localizable", "9ic-FL-obx.title") }
  /// Smart Copy/Paste
  public static var _9yt4BNSMTitle: String  { return L10n.tr("Localizable", "9yt-4B-nSM.title") }
  /// Free messaging app for macOS based on MTProto for speed and security.
  public static var aboutDescription: String  { return L10n.tr("Localizable", "About.Description") }
  /// Tinted
  public static var accentColorsTinted: String  { return L10n.tr("Localizable", "AccentColors.Tinted") }
  /// Open In Window
  public static var accountOpenInWindow: String  { return L10n.tr("Localizable", "Account.OpenInWindow") }
  /// Please note that Telegram Support is run by volunteers. We try to respond as quickly as possible, but it may take a while.\n\nPlease take a look at the Telegram FAQ: it has important troubleshooting tips and answers to most questions.
  public static var accountConfirmAskQuestion: String  { return L10n.tr("Localizable", "Account.Confirm.AskQuestion") }
  /// Open FAQ
  public static var accountConfirmGoToFaq: String  { return L10n.tr("Localizable", "Account.Confirm.GoToFaq") }
  /// Log out?
  public static var accountConfirmLogout: String  { return L10n.tr("Localizable", "Account.Confirm.Logout") }
  /// Remember, logging out cancels all your Secret Chats.
  public static var accountConfirmLogoutText: String  { return L10n.tr("Localizable", "Account.Confirm.LogoutText") }
  /// About
  public static var accountSettingsAbout: String  { return L10n.tr("Localizable", "AccountSettings.About") }
  /// Add Account
  public static var accountSettingsAddAccount: String  { return L10n.tr("Localizable", "AccountSettings.AddAccount") }
  /// Ask a Question
  public static var accountSettingsAskQuestion: String  { return L10n.tr("Localizable", "AccountSettings.AskQuestion") }
  /// Bio
  public static var accountSettingsBio: String  { return L10n.tr("Localizable", "AccountSettings.Bio") }
  /// English
  public static var accountSettingsCurrentLanguage: String  { return L10n.tr("Localizable", "AccountSettings.CurrentLanguage") }
  /// Data and Storage
  public static var accountSettingsDataAndStorage: String  { return L10n.tr("Localizable", "AccountSettings.DataAndStorage") }
  /// Delete Account
  public static var accountSettingsDeleteAccount: String  { return L10n.tr("Localizable", "AccountSettings.DeleteAccount") }
  /// Telegram FAQ
  public static var accountSettingsFAQ: String  { return L10n.tr("Localizable", "AccountSettings.FAQ") }
  /// Chat Folders
  public static var accountSettingsFilters: String  { return L10n.tr("Localizable", "AccountSettings.Filters") }
  /// General
  public static var accountSettingsGeneral: String  { return L10n.tr("Localizable", "AccountSettings.General") }
  /// Language
  public static var accountSettingsLanguage: String  { return L10n.tr("Localizable", "AccountSettings.Language") }
  /// Logout
  public static var accountSettingsLogout: String  { return L10n.tr("Localizable", "AccountSettings.Logout") }
  /// Notifications
  public static var accountSettingsNotifications: String  { return L10n.tr("Localizable", "AccountSettings.Notifications") }
  /// Telegram Passport
  public static var accountSettingsPassport: String  { return L10n.tr("Localizable", "AccountSettings.Passport") }
  /// Privacy and Security
  public static var accountSettingsPrivacyAndSecurity: String  { return L10n.tr("Localizable", "AccountSettings.PrivacyAndSecurity") }
  /// Proxy
  public static var accountSettingsProxy: String  { return L10n.tr("Localizable", "AccountSettings.Proxy") }
  /// Read Articles
  public static var accountSettingsReadArticles: String  { return L10n.tr("Localizable", "AccountSettings.ReadArticles") }
  /// Set a Bio
  public static var accountSettingsSetBio: String  { return L10n.tr("Localizable", "AccountSettings.SetBio") }
  /// Set Profile Photo
  public static var accountSettingsSetProfilePhoto: String  { return L10n.tr("Localizable", "AccountSettings.SetProfilePhoto") }
  /// Set a Username
  public static var accountSettingsSetUsername: String  { return L10n.tr("Localizable", "AccountSettings.SetUsername") }
  /// Stickers
  public static var accountSettingsStickers: String  { return L10n.tr("Localizable", "AccountSettings.Stickers") }
  /// Appearance
  public static var accountSettingsTheme: String  { return L10n.tr("Localizable", "AccountSettings.Theme") }
  /// Username
  public static var accountSettingsUsername: String  { return L10n.tr("Localizable", "AccountSettings.Username") }
  /// Gram Wallet
  public static var accountSettingsWallet: String  { return L10n.tr("Localizable", "AccountSettings.Wallet") }
  /// Connected
  public static var accountSettingsProxyConnected: String  { return L10n.tr("Localizable", "AccountSettings.Proxy.Connected") }
  /// Connecting
  public static var accountSettingsProxyConnecting: String  { return L10n.tr("Localizable", "AccountSettings.Proxy.Connecting") }
  /// Disabled
  public static var accountSettingsProxyDisabled: String  { return L10n.tr("Localizable", "AccountSettings.Proxy.Disabled") }
  /// Update
  public static var accountViewControllerUpdate: String  { return L10n.tr("Localizable", "AccountViewController.Update") }
  /// failed
  public static var accountViewControllerDescFailed: String  { return L10n.tr("Localizable", "AccountViewController.Desc.Failed") }
  /// updated
  public static var accountViewControllerDescUpdated: String  { return L10n.tr("Localizable", "AccountViewController.Desc.Updated") }
  /// New Account
  public static var accountsControllerNewAccount: String  { return L10n.tr("Localizable", "AccountsController.NewAccount") }
  /// Add Admin
  public static var adminsAddAdmin: String  { return L10n.tr("Localizable", "Admins.AddAdmin") }
  /// Admin
  public static var adminsAdmin: String  { return L10n.tr("Localizable", "Admins.Admin") }
  /// CHANNEL ADMINS
  public static var adminsChannelAdmins: String  { return L10n.tr("Localizable", "Admins.ChannelAdmins") }
  /// You can add admins to help you manage your channel
  public static var adminsChannelDescription: String  { return L10n.tr("Localizable", "Admins.ChannelDescription") }
  /// Any member can add new members
  public static var adminsEverbodyCanAddMembers: String  { return L10n.tr("Localizable", "Admins.EverbodyCanAddMembers") }
  /// GROUP ADMINS
  public static var adminsGroupAdmins: String  { return L10n.tr("Localizable", "Admins.GroupAdmins") }
  /// You can add admins to help you manage your group.
  public static var adminsGroupDescription: String  { return L10n.tr("Localizable", "Admins.GroupDescription") }
  /// Only admins can add new members.
  public static var adminsOnlyAdminsCanAddMembers: String  { return L10n.tr("Localizable", "Admins.OnlyAdminsCanAddMembers") }
  /// Owner
  public static var adminsOwner: String  { return L10n.tr("Localizable", "Admins.Owner") }
  /// Contacts
  public static var adminsSelectNewAdminTitle: String  { return L10n.tr("Localizable", "Admins.SelectNewAdminTitle") }
  /// Only Admins
  public static var adminsWhoCanInviteAdmins: String  { return L10n.tr("Localizable", "Admins.WhoCanInvite.Admins") }
  /// All Members
  public static var adminsWhoCanInviteEveryone: String  { return L10n.tr("Localizable", "Admins.WhoCanInvite.Everyone") }
  /// Who can add members
  public static var adminsWhoCanInviteText: String  { return L10n.tr("Localizable", "Admins.WhoCanInvite.Text") }
  /// Cancel
  public static var alertCancel: String  { return L10n.tr("Localizable", "Alert.Cancel") }
  /// Discard
  public static var alertDiscard: String  { return L10n.tr("Localizable", "Alert.Discard") }
  /// No
  public static var alertNO: String  { return L10n.tr("Localizable", "Alert.NO") }
  /// OK
  public static var alertOK: String  { return L10n.tr("Localizable", "Alert.OK") }
  /// Sorry, this user doesn't seem to exist.
  public static var alertUserDoesntExists: String  { return L10n.tr("Localizable", "Alert.UserDoesntExists") }
  /// Yes
  public static var alertYes: String  { return L10n.tr("Localizable", "Alert.Yes") }
  /// Update App
  public static var alertButtonOKUpdateApp: String  { return L10n.tr("Localizable", "Alert.ButtonOK.UpdateApp") }
  /// Discard
  public static var alertConfirmDiscard: String  { return L10n.tr("Localizable", "Alert.Confirm.Discard") }
  /// Stop
  public static var alertConfirmStop: String  { return L10n.tr("Localizable", "Alert.Confirm.Stop") }
  /// Sorry, you can't forward messages to this conversation.
  public static var alertForwardError: String  { return L10n.tr("Localizable", "Alert.Forward.Error") }
  /// Cancel
  public static var alertHideNewChatsCancel: String  { return L10n.tr("Localizable", "Alert.HideNewChats.Cancel") }
  /// Hide new chats?
  public static var alertHideNewChatsHeader: String  { return L10n.tr("Localizable", "Alert.HideNewChats.Header") }
  /// Go to Settings
  public static var alertHideNewChatsOK: String  { return L10n.tr("Localizable", "Alert.HideNewChats.OK") }
  /// You are receiving lots of new chats from users who are not in your Contact List. Do you want to have such chats automatically muted and archived?
  public static var alertHideNewChatsText: String  { return L10n.tr("Localizable", "Alert.HideNewChats.Text") }
  /// Unfortunately, you can't access this message. You are not a member of the chat where it was posted.
  public static var alertPrivateChannelAccessError: String  { return L10n.tr("Localizable", "Alert.PrivateChannel.AccessError") }
  /// Delete
  public static var alertSendErrorDelete: String  { return L10n.tr("Localizable", "Alert.SendError.Delete") }
  /// Your message could not be sent
  public static var alertSendErrorHeader: String  { return L10n.tr("Localizable", "Alert.SendError.Header") }
  /// Ignore
  public static var alertSendErrorIgnore: String  { return L10n.tr("Localizable", "Alert.SendError.Ignore") }
  /// Resend
  public static var alertSendErrorResend: String  { return L10n.tr("Localizable", "Alert.SendError.Resend") }
  /// %d
  public static func alertSendErrorResendItemsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_countable", p1)
  }
  /// Resend %d messages
  public static func alertSendErrorResendItemsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_few", p1)
  }
  /// Resend %d messages
  public static func alertSendErrorResendItemsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_many", p1)
  }
  /// Resend %d message
  public static func alertSendErrorResendItemsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_one", p1)
  }
  /// Resend %d messages
  public static func alertSendErrorResendItemsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_other", p1)
  }
  /// Resend %d messages
  public static func alertSendErrorResendItemsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_two", p1)
  }
  /// Resend %d messages
  public static func alertSendErrorResendItemsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Alert.SendError.ResendItems_zero", p1)
  }
  /// An error occurred while sending the previous message. Would you like to try resending it?
  public static var alertSendErrorText: String  { return L10n.tr("Localizable", "Alert.SendError.Text") }
  /// Maximum file size is 2.0 GB
  public static var appMaxFileSize1: String  { return L10n.tr("Localizable", "App.MaxFileSize1") }
  /// Hold to record video. Click to switch to audio
  public static var appTooltipVideoRecord: String  { return L10n.tr("Localizable", "App.Tooltip.VideoRecord") }
  /// Hold to record audio. Click to switch to video
  public static var appTooltipVoiceRecord: String  { return L10n.tr("Localizable", "App.Tooltip.VoiceRecord") }
  /// Check for Updates
  public static var appUpdateCheckForUpdates: String  { return L10n.tr("Localizable", "AppUpdate.CheckForUpdates") }
  /// Downloading...
  public static var appUpdateDownloading: String  { return L10n.tr("Localizable", "AppUpdate.Downloading") }
  /// Download Update
  public static var appUpdateDownloadUpdate: String  { return L10n.tr("Localizable", "AppUpdate.DownloadUpdate") }
  /// Please update the app to get the latest features and improvements.
  public static var appUpdateNewestAvailable: String  { return L10n.tr("Localizable", "AppUpdate.NewestAvailable") }
  /// Retrieving Information...
  public static var appUpdateRetrievingInfo: String  { return L10n.tr("Localizable", "AppUpdate.RetrievingInfo") }
  /// Updates
  public static var appUpdateTitle: String  { return L10n.tr("Localizable", "AppUpdate.Title") }
  /// Unarchiving...
  public static var appUpdateUnarchiving: String  { return L10n.tr("Localizable", "AppUpdate.Unarchiving") }
  /// You have the latest version of Telegram.
  public static var appUpdateUptodate: String  { return L10n.tr("Localizable", "AppUpdate.Uptodate") }
  /// NEW VERSION (your version: %@)
  public static func appUpdateTitleNew(_ p1: String) -> String {
    return L10n.tr("Localizable", "AppUpdate.Title.New", p1)
  }
  /// PREVIOUS VERSIONS
  public static var appUpdateTitlePrevious: String  { return L10n.tr("Localizable", "AppUpdate.Title.Previous") }
  /// CLOUD THEMES
  public static var appearanceCloudThemes: String  { return L10n.tr("Localizable", "Appearance.CloudThemes") }
  /// Custom Background
  public static var appearanceCustomBackground: String  { return L10n.tr("Localizable", "Appearance.CustomBackground") }
  /// Export Theme
  public static var appearanceExportTheme: String  { return L10n.tr("Localizable", "Appearance.ExportTheme") }
  /// New Theme
  public static var appearanceNewTheme: String  { return L10n.tr("Localizable", "Appearance.NewTheme") }
  /// Reset to Defaults
  public static var appearanceReset: String  { return L10n.tr("Localizable", "Appearance.Reset") }
  /// Incompatible with macOS, click to edit
  public static var appearanceCloudThemeUnsupported: String  { return L10n.tr("Localizable", "Appearance.CloudTheme.Unsupported") }
  /// Remove
  public static var appearanceConfirmRemoveOK: String  { return L10n.tr("Localizable", "Appearance.Confirm.RemoveOK") }
  /// Are you sure you want to delete this theme?
  public static var appearanceConfirmRemoveText: String  { return L10n.tr("Localizable", "Appearance.Confirm.RemoveText") }
  /// Theme
  public static var appearanceConfirmRemoveTitle: String  { return L10n.tr("Localizable", "Appearance.Confirm.RemoveTitle") }
  /// The file size must not exceed 2MB and the image dimensions must not exceed 500x500px.
  public static var appearanceCustomBackgroundFileError: String  { return L10n.tr("Localizable", "Appearance.CustomBackground.FileError") }
  /// Auto-Night Mode
  public static var appearanceSettingsAutoNight: String  { return L10n.tr("Localizable", "Appearance.Settings.AutoNight") }
  /// AUTO-NIGHT MODE
  public static var appearanceSettingsAutoNightHeader: String  { return L10n.tr("Localizable", "Appearance.Settings.AutoNightHeader") }
  /// Bubbles Mode
  public static var appearanceSettingsBubblesMode: String  { return L10n.tr("Localizable", "Appearance.Settings.BubblesMode") }
  /// Dark Mode
  public static var appearanceSettingsDarkMode: String  { return L10n.tr("Localizable", "Appearance.Settings.DarkMode") }
  /// Show Less
  public static var appearanceSettingsShowLess: String  { return L10n.tr("Localizable", "Appearance.Settings.ShowLess") }
  /// Show More
  public static var appearanceSettingsShowMore: String  { return L10n.tr("Localizable", "Appearance.Settings.ShowMore") }
  /// Accent
  public static var appearanceThemeAccent: String  { return L10n.tr("Localizable", "Appearance.Theme.Accent") }
  /// Edit
  public static var appearanceThemeEdit: String  { return L10n.tr("Localizable", "Appearance.Theme.Edit") }
  /// Remove
  public static var appearanceThemeRemove: String  { return L10n.tr("Localizable", "Appearance.Theme.Remove") }
  /// Share
  public static var appearanceThemeShare: String  { return L10n.tr("Localizable", "Appearance.Theme.Share") }
  /// Messages
  public static var appearanceThemeAccentMessages: String  { return L10n.tr("Localizable", "Appearance.Theme.Accent.Messages") }
  /// Follow System Appearance
  public static var appearanceSettingsFollowSystemAppearance: String  { return L10n.tr("Localizable", "AppearanceSettings.FollowSystemAppearance") }
  /// Good morning! 👋
  public static var appearanceSettingsChatPreview1: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.1") }
  /// Do you know what time it is?
  public static var appearanceSettingsChatPreview2: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.2") }
  /// It's morning in Tokyo 😎
  public static var appearanceSettingsChatPreview3: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.3") }
  /// Ah, you kids today with techno music! You should enjoy the classics, like Hasselhoff!
  public static var appearanceSettingsChatPreviewFirstText: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.FirstText") }
  /// CHAT PREVIEW
  public static var appearanceSettingsChatPreviewHeader: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.Header") }
  /// I can't even take you seriously right now.
  public static var appearanceSettingsChatPreviewSecondText: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.SecondText") }
  /// Lucio
  public static var appearanceSettingsChatPreviewUserName1: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.UserName1") }
  /// Reinhardt
  public static var appearanceSettingsChatPreviewUserName2: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.UserName2") }
  /// Reinhardt, we need to find you some new tunes 🎶.
  public static var appearanceSettingsChatPreviewZeroText: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatPreview.ZeroText") }
  /// Bubbles
  public static var appearanceSettingsChatViewBubbles: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatView.Bubbles") }
  /// Minimalist
  public static var appearanceSettingsChatViewClassic: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatView.Classic") }
  /// CHAT VIEW
  public static var appearanceSettingsChatViewHeader: String  { return L10n.tr("Localizable", "AppearanceSettings.ChatView.Header") }
  /// Day
  public static var appearanceSettingsColorThemeDay: String  { return L10n.tr("Localizable", "AppearanceSettings.ColorTheme.day") }
  /// Day Classic
  public static var appearanceSettingsColorThemeDayClassic: String  { return L10n.tr("Localizable", "AppearanceSettings.ColorTheme.dayClassic") }
  /// COLOR THEME
  public static var appearanceSettingsColorThemeHeader: String  { return L10n.tr("Localizable", "AppearanceSettings.ColorTheme.Header") }
  /// Night Accent
  public static var appearanceSettingsColorThemeNightAccent: String  { return L10n.tr("Localizable", "AppearanceSettings.ColorTheme.nightAccent") }
  /// System
  public static var appearanceSettingsColorThemeSystem: String  { return L10n.tr("Localizable", "AppearanceSettings.ColorTheme.system") }
  /// Select default dark palette which one will be used in dark system appearance mode.
  public static var appearanceSettingsFollowSystemAppearanceDefaultDark: String  { return L10n.tr("Localizable", "AppearanceSettings.FollowSystemAppearance.DefaultDark") }
  /// Select default day palette which one will be used in light system appearance mode.
  public static var appearanceSettingsFollowSystemAppearanceDefaultDay: String  { return L10n.tr("Localizable", "AppearanceSettings.FollowSystemAppearance.DefaultDay") }
  /// DEFAULT PALETTES
  public static var appearanceSettingsFollowSystemAppearanceDefaultHeader: String  { return L10n.tr("Localizable", "AppearanceSettings.FollowSystemAppearance.DefaultHeader") }
  /// TEXT SIZE
  public static var appearanceSettingsTextSizeHeader: String  { return L10n.tr("Localizable", "AppearanceSettings.TextSize.Header") }
  /// Change
  public static var applyLanguageApplyLanguageAction: String  { return L10n.tr("Localizable", "ApplyLanguage.ApplyLanguageAction") }
  /// Change
  public static var applyLanguageChangeLanguageAction: String  { return L10n.tr("Localizable", "ApplyLanguage.ChangeLanguageAction") }
  /// The language %@ is already active.
  public static func applyLanguageChangeLanguageAlreadyActive(_ p1: String) -> String {
    return L10n.tr("Localizable", "ApplyLanguage.ChangeLanguageAlreadyActive", p1)
  }
  /// You are about to apply a language pack **%@**.\n\nThis will translate the entire interface. You can suggest corrections in the [translation panel]().\n\nYou can change your language back at any time in Settings.
  public static func applyLanguageChangeLanguageOfficialText(_ p1: String) -> String {
    return L10n.tr("Localizable", "ApplyLanguage.ChangeLanguageOfficialText", p1)
  }
  /// Change Language?
  public static var applyLanguageChangeLanguageTitle: String  { return L10n.tr("Localizable", "ApplyLanguage.ChangeLanguageTitle") }
  /// You are about to apply a custom language pack **%1$@** that is %2$@%% complete.\n\nThis will translate the entire interface. You can suggest corrections in the [translation panel]().\n\nYou can change your language back at any time in Settings.
  public static func applyLanguageChangeLanguageUnofficialText1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "ApplyLanguage.ChangeLanguageUnofficialText1", p1, p2)
  }
  /// Translation Platform
  public static var applyLanguageUnsufficientDataOpenPlatform: String  { return L10n.tr("Localizable", "ApplyLanguage.UnsufficientDataOpenPlatform") }
  /// Unfortunately, this custom language pack %@ doesn't contain data for Telegram macos. You can contribute to this language pack using the translations platform.
  public static func applyLanguageUnsufficientDataText(_ p1: String) -> String {
    return L10n.tr("Localizable", "ApplyLanguage.UnsufficientDataText", p1)
  }
  /// Insufficient Data
  public static var applyLanguageUnsufficientDataTitle: String  { return L10n.tr("Localizable", "ApplyLanguage.UnsufficientDataTitle") }
  /// unmuted chats will get unarchived if new messages arrive.
  public static var archiveTooltipFirstText: String  { return L10n.tr("Localizable", "Archive.Tooltip.First.Text") }
  /// Chat Archived
  public static var archiveTooltipFirstTitle: String  { return L10n.tr("Localizable", "Archive.Tooltip.First.Title") }
  /// Chat Archived
  public static var archiveTooltipJustArchiveTitle: String  { return L10n.tr("Localizable", "Archive.Tooltip.JustArchive.Title") }
  /// muted chats will stay archivated after new messages arrive.
  public static var archiveTooltipSecondText: String  { return L10n.tr("Localizable", "Archive.Tooltip.Second.Text") }
  /// Chat Archived
  public static var archiveTooltipSecondTitle: String  { return L10n.tr("Localizable", "Archive.Tooltip.Second.Title") }
  /// you can pin an unlimited number of archived chats on the top.
  public static var archiveTooltipThirdText: String  { return L10n.tr("Localizable", "Archive.Tooltip.Third.Text") }
  /// Chat Archived
  public static var archiveTooltipThirdTitle: String  { return L10n.tr("Localizable", "Archive.Tooltip.Third.Title") }
  /// You can have up to 200 sticker sets installed. Unused stickers are archived when you add more.
  public static var archivedStickersDescription: String  { return L10n.tr("Localizable", "ArchivedStickers.Description") }
  /// Your archived sticker packs will appear here
  public static var archivedStickersEmpty: String  { return L10n.tr("Localizable", "ArchivedStickers.Empty") }
  /// Mark As Read
  public static var articleMarkAsRead: String  { return L10n.tr("Localizable", "Article.MarkAsRead") }
  /// Mark As Unread
  public static var articleMarkAsUnread: String  { return L10n.tr("Localizable", "Article.MarkAsUnread") }
  /// READ
  public static var articleRead: String  { return L10n.tr("Localizable", "Article.Read") }
  /// Read All
  public static var articleReadAll: String  { return L10n.tr("Localizable", "Article.ReadAll") }
  /// Remove
  public static var articleRemove: String  { return L10n.tr("Localizable", "Article.Remove") }
  /// Remove All
  public static var articleRemoveAll: String  { return L10n.tr("Localizable", "Article.RemoveAll") }
  /// Unknown Artist
  public static var audioUnknownArtist: String  { return L10n.tr("Localizable", "Audio.UnknownArtist") }
  /// Untitled
  public static var audioUntitledSong: String  { return L10n.tr("Localizable", "Audio.UntitledSong") }
  /// video message
  public static var audioControllerVideoMessage: String  { return L10n.tr("Localizable", "AudioController.videoMessage") }
  /// voice message
  public static var audioControllerVoiceMessage: String  { return L10n.tr("Localizable", "AudioController.voiceMessage") }
  /// Click outside of circle to cancel
  public static var audioRecordHelpFixed: String  { return L10n.tr("Localizable", "AudioRecord.Help.Fixed") }
  /// Release outside of circle to cancel
  public static var audioRecordHelpPlain: String  { return L10n.tr("Localizable", "AudioRecord.Help.Plain") }
  /// , 
  public static var autoDownloadSettingsDelimeter: String  { return L10n.tr("Localizable", "AutoDownloadSettings.Delimeter") }
  ///  and 
  public static var autoDownloadSettingsLastDelimeter: String  { return L10n.tr("Localizable", "AutoDownloadSettings.LastDelimeter") }
  /// Off for all chats
  public static var autoDownloadSettingsOffForAll: String  { return L10n.tr("Localizable", "AutoDownloadSettings.OffForAll") }
  /// On for %@
  public static func autoDownloadSettingsOnFor(_ p1: String) -> String {
    return L10n.tr("Localizable", "AutoDownloadSettings.OnFor", p1)
  }
  /// On for all chats
  public static var autoDownloadSettingsOnForAll: String  { return L10n.tr("Localizable", "AutoDownloadSettings.OnForAll") }
  /// Channels
  public static var autoDownloadSettingsTypeChannels: String  { return L10n.tr("Localizable", "AutoDownloadSettings.TypeChannels") }
  /// Groups
  public static var autoDownloadSettingsTypeGroupChats: String  { return L10n.tr("Localizable", "AutoDownloadSettings.TypeGroupChats") }
  /// Private Chats
  public static var autoDownloadSettingsTypePrivateChats: String  { return L10n.tr("Localizable", "AutoDownloadSettings.TypePrivateChats") }
  /// Up to %@ for %@
  public static func autoDownloadSettingsUpToFor(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "AutoDownloadSettings.UpToFor", p1, p2)
  }
  /// Up to %@ for all chats
  public static func autoDownloadSettingsUpToForAll(_ p1: String) -> String {
    return L10n.tr("Localizable", "AutoDownloadSettings.UpToForAll", p1)
  }
  /// Disabled
  public static var autoNightSettingsDisabled: String  { return L10n.tr("Localizable", "AutoNight.Settings.Disabled") }
  /// From
  public static var autoNightSettingsFrom: String  { return L10n.tr("Localizable", "AutoNight.Settings.From") }
  /// PREFERRED NIGHT THEME
  public static var autoNightSettingsPreferredTheme: String  { return L10n.tr("Localizable", "AutoNight.Settings.PreferredTheme") }
  /// Scheduled
  public static var autoNightSettingsScheduled: String  { return L10n.tr("Localizable", "AutoNight.Settings.Scheduled") }
  /// Use Local Sunset & Sunrise
  public static var autoNightSettingsSunsetAndSunrise: String  { return L10n.tr("Localizable", "AutoNight.Settings.SunsetAndSunrise") }
  /// System
  public static var autoNightSettingsSystemBased: String  { return L10n.tr("Localizable", "AutoNight.Settings.SystemBased") }
  /// App interfaces will match the system appearance settings.
  public static var autoNightSettingsSystemBasedDesc: String  { return L10n.tr("Localizable", "AutoNight.Settings.SystemBasedDesc") }
  /// Auto-Night Theme
  public static var autoNightSettingsTitle: String  { return L10n.tr("Localizable", "AutoNight.Settings.Title") }
  /// To
  public static var autoNightSettingsTo: String  { return L10n.tr("Localizable", "AutoNight.Settings.To") }
  /// Update Location
  public static var autoNightSettingsUpdateLocation: String  { return L10n.tr("Localizable", "AutoNight.Settings.UpdateLocation") }
  /// Calculating sunset & sunrise times requires a one-time check of your approximate location. Note that this location is only stored locally on your device.\n\nSunset: %@\nSunrise: %@
  public static func autoNightSettingsSunriseDesc(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "AutoNight.Settings.Sunrise.Desc", p1, p2)
  }
  /// Calculating sunset & sunrise times requires a one-time check of your approximate location. Note that this location is only stored locally on your device.\n\nSunset: N/A\nSunrise: N/A
  public static var autoNightSettingsSunriseDescNA: String  { return L10n.tr("Localizable", "AutoNight.Settings.Sunrise.Desc.NA") }
  /// Can't determine your location. Please check your system settings and try again.
  public static var autoNightSettingsUpdateLocationError: String  { return L10n.tr("Localizable", "AutoNight.Settings.UpdateLocation.Error") }
  /// 1 Day
  public static var autoremoveMessagesDay1: String  { return L10n.tr("Localizable", "AutoremoveMessages.Day1") }
  /// Automatically delete messages sent in this chat after a certain period of time.
  public static var autoremoveMessagesDesc: String  { return L10n.tr("Localizable", "AutoremoveMessages.Desc") }
  /// AUTO-DELETE MESSAGES
  public static var autoremoveMessagesHeader: String  { return L10n.tr("Localizable", "AutoremoveMessages.Header") }
  /// 1 Month
  public static var autoremoveMessagesMonth1: String  { return L10n.tr("Localizable", "AutoremoveMessages.Month1") }
  /// Never
  public static var autoremoveMessagesNever: String  { return L10n.tr("Localizable", "AutoremoveMessages.Never") }
  /// Clear Chat History
  public static var autoremoveMessagesTitle: String  { return L10n.tr("Localizable", "AutoremoveMessages.Title") }
  /// 1 Week
  public static var autoremoveMessagesWeek1: String  { return L10n.tr("Localizable", "AutoremoveMessages.Week1") }
  /// Auto-Deletion
  public static var autoremoveMessagesTitleDeleteOnly: String  { return L10n.tr("Localizable", "AutoremoveMessages.Title.DeleteOnly") }
  /// Preferences…
  public static var bofnm1cWTitle: String  { return L10n.tr("Localizable", "BOF-NM-1cW.title") }
  /// Any details such as age, occupation or city.\nExample: 23 y.o. designer from San Francisco
  public static var bioDescription: String  { return L10n.tr("Localizable", "Bio.Description") }
  /// BIO
  public static var bioHeader: String  { return L10n.tr("Localizable", "Bio.Header") }
  /// A few words about you
  public static var bioPlaceholder: String  { return L10n.tr("Localizable", "Bio.Placeholder") }
  /// Save
  public static var bioSave: String  { return L10n.tr("Localizable", "Bio.Save") }
  /// Do you want to block %@ from messaging and calling you on Telegram?
  public static func blockContactTitle(_ p1: String) -> String {
    return L10n.tr("Localizable", "BlockContact.Title", p1)
  }
  /// Block %@
  public static func blockContactOptionsAction(_ p1: String) -> String {
    return L10n.tr("Localizable", "BlockContact.Options.Action", p1)
  }
  /// Delete this Chat
  public static var blockContactOptionsDeleteChat: String  { return L10n.tr("Localizable", "BlockContact.Options.DeleteChat") }
  /// Report Spam
  public static var blockContactOptionsReport: String  { return L10n.tr("Localizable", "BlockContact.Options.Report") }
  /// Manage User
  public static var blockContactOptionsTitle: String  { return L10n.tr("Localizable", "BlockContact.Options.Title") }
  /// Blocked users can't send you messages or add you to groups. They will not see your profile pictures, online and last seen status.
  public static var blockedPeersEmptyDescrpition: String  { return L10n.tr("Localizable", "BlockedPeers.EmptyDescrpition") }
  /// Open Link
  public static var botInlineAuthHeader: String  { return L10n.tr("Localizable", "Bot.InlineAuth.Header") }
  /// Open
  public static var botInlineAuthOpen: String  { return L10n.tr("Localizable", "Bot.InlineAuth.Open") }
  /// Do you want to open \n%@?
  public static func botInlineAuthTitle(_ p1: String) -> String {
    return L10n.tr("Localizable", "Bot.InlineAuth.Title", p1)
  }
  /// Allow %@ to send me messages
  public static func botInlineAuthOptionAllowSendMessages(_ p1: String) -> String {
    return L10n.tr("Localizable", "Bot.InlineAuth.Option.AllowSendMessages", p1)
  }
  /// Log in to %@ as %@
  public static func botInlineAuthOptionLogin(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Bot.InlineAuth.Option.Login", p1, p2)
  }
  /// Enable 2-Step Verification.
  public static var botTransferOwnerErrorEnable2FA: String  { return L10n.tr("Localizable", "Bot.TransferOwner.Error.Enable2FA") }
  /// Ownership transfers are only available if:\n\n• 2-Step Verification was enabled for your account more than 7 days ago.\n\n• You have logged in on this device more than 24 hours ago.\n\nPlease come back later.
  public static var botTransferOwnerErrorText: String  { return L10n.tr("Localizable", "Bot.TransferOwner.Error.Text") }
  /// Security Check
  public static var botTransferOwnerErrorTitle: String  { return L10n.tr("Localizable", "Bot.TransferOwner.Error.Title") }
  /// Please enter your 2-Step verification password to complete the transfer.
  public static var botTransferOwnershipPasswordDesc: String  { return L10n.tr("Localizable", "Bot.TransferOwnership.Password.Desc") }
  /// Two-Step Verification
  public static var botTransferOwnershipPasswordTitle: String  { return L10n.tr("Localizable", "Bot.TransferOwnership.Password.Title") }
  /// Leave as regular group
  public static var broadcastGroupsCancel: String  { return L10n.tr("Localizable", "BroadcastGroups.Cancel") }
  /// Convert to Broadcast Group
  public static var broadcastGroupsConvert: String  { return L10n.tr("Localizable", "BroadcastGroups.Convert") }
  /// • No limit on the number of members.\n\n• Only admins can post.\n\n• Can't be turned back into a regular group.
  public static var broadcastGroupsIntroText: String  { return L10n.tr("Localizable", "BroadcastGroups.IntroText") }
  /// Broadcast Groups
  public static var broadcastGroupsIntroTitle: String  { return L10n.tr("Localizable", "BroadcastGroups.IntroTitle") }
  /// Success! Now your group have not limits.
  public static var broadcastGroupsSuccess: String  { return L10n.tr("Localizable", "BroadcastGroups.Success") }
  /// Convert
  public static var broadcastGroupsConfirmationAlertConvert: String  { return L10n.tr("Localizable", "BroadcastGroups.ConfirmationAlert.Convert") }
  /// Regular members of the group (non-admins) will irrevocably lose their right to post messages in the group.\n\nThis action cannot be undone.
  public static var broadcastGroupsConfirmationAlertText: String  { return L10n.tr("Localizable", "BroadcastGroups.ConfirmationAlert.Text") }
  /// Are you sure?
  public static var broadcastGroupsConfirmationAlertTitle: String  { return L10n.tr("Localizable", "BroadcastGroups.ConfirmationAlert.Title") }
  /// Learn More
  public static var broadcastGroupsLimitAlertLearnMore: String  { return L10n.tr("Localizable", "BroadcastGroups.LimitAlert.LearnMore") }
  /// If you change your mind, go to the permission settings of your group.
  public static var broadcastGroupsLimitAlertSettingsTip: String  { return L10n.tr("Localizable", "BroadcastGroups.LimitAlert.SettingsTip") }
  /// Your group has reached a limit of %@ members.\n\nYou can increase this limit by converting the group to a broadcast group where only admins can post. Interested?
  public static func broadcastGroupsLimitAlertText(_ p1: String) -> String {
    return L10n.tr("Localizable", "BroadcastGroups.LimitAlert.Text", p1)
  }
  /// Limit Reached
  public static var broadcastGroupsLimitAlertTitle: String  { return L10n.tr("Localizable", "BroadcastGroups.LimitAlert.Title") }
  /// Hide Telegram
  public static var cagYXWT6Title: String  { return L10n.tr("Localizable", "Cag-YX-WT6.title") }
  /// F
  public static var calendarWeekDaysFriday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Friday") }
  /// M
  public static var calendarWeekDaysMonday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Monday") }
  /// S
  public static var calendarWeekDaysSaturday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Saturday") }
  /// S
  public static var calendarWeekDaysSunday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Sunday") }
  /// T
  public static var calendarWeekDaysThrusday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Thrusday") }
  /// T
  public static var calendarWeekDaysTuesday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Tuesday") }
  /// W
  public static var calendarWeekDaysWednesday: String  { return L10n.tr("Localizable", "Calendar.WeekDays.Wednesday") }
  /// Accept
  public static var callAccept: String  { return L10n.tr("Localizable", "Call.Accept") }
  /// Camera
  public static var callCamera: String  { return L10n.tr("Localizable", "Call.Camera") }
  /// Camera is unavailable\n[settings]()
  public static var callCameraUnavailable: String  { return L10n.tr("Localizable", "Call.CameraUnavailable") }
  /// Close
  public static var callClose: String  { return L10n.tr("Localizable", "Call.Close") }
  /// Decline
  public static var callDecline: String  { return L10n.tr("Localizable", "Call.Decline") }
  /// End
  public static var callEnd: String  { return L10n.tr("Localizable", "Call.End") }
  /// Mute
  public static var callMute: String  { return L10n.tr("Localizable", "Call.Mute") }
  /// %@'s app does not support calls. They need to update their app before you can call them.
  public static func callParticipantVersionOutdatedError(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.ParticipantVersionOutdatedError", p1)
  }
  /// Sorry, %@ doesn't accept calls.
  public static func callPrivacyErrorMessage(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.PrivacyErrorMessage", p1)
  }
  /// Redial
  public static var callRecall: String  { return L10n.tr("Localizable", "Call.Recall") }
  /// Screen
  public static var callScreen: String  { return L10n.tr("Localizable", "Call.Screen") }
  /// %d
  public static func callShortMinutesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_countable", p1)
  }
  /// %d min
  public static func callShortMinutesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_few", p1)
  }
  /// %d min
  public static func callShortMinutesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_many", p1)
  }
  /// %d min
  public static func callShortMinutesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_one", p1)
  }
  /// %d min
  public static func callShortMinutesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_other", p1)
  }
  /// %d min
  public static func callShortMinutesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_two", p1)
  }
  /// %d min
  public static func callShortMinutesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortMinutes_zero", p1)
  }
  /// %d
  public static func callShortSecondsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_countable", p1)
  }
  /// %d sec
  public static func callShortSecondsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_few", p1)
  }
  /// %d sec
  public static func callShortSecondsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_many", p1)
  }
  /// %d sec
  public static func callShortSecondsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_one", p1)
  }
  /// %d sec
  public static func callShortSecondsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_other", p1)
  }
  /// %d sec
  public static func callShortSecondsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_two", p1)
  }
  /// %d sec
  public static func callShortSecondsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Call.ShortSeconds_zero", p1)
  }
  /// Busy
  public static var callStatusBusy: String  { return L10n.tr("Localizable", "Call.StatusBusy") }
  /// is calling you...
  public static var callStatusCalling: String  { return L10n.tr("Localizable", "Call.StatusCalling") }
  /// is calling → %@...
  public static func callStatusCallingAccount(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.StatusCallingAccount", p1)
  }
  /// Connecting...
  public static var callStatusConnecting: String  { return L10n.tr("Localizable", "Call.StatusConnecting") }
  /// Call Ended
  public static var callStatusEnded: String  { return L10n.tr("Localizable", "Call.StatusEnded") }
  /// Call Failed
  public static var callStatusFailed: String  { return L10n.tr("Localizable", "Call.StatusFailed") }
  /// Contacting...
  public static var callStatusRequesting: String  { return L10n.tr("Localizable", "Call.StatusRequesting") }
  /// Ringing...
  public static var callStatusRinging: String  { return L10n.tr("Localizable", "Call.StatusRinging") }
  /// Undefined error, please try later.
  public static var callUndefinedError: String  { return L10n.tr("Localizable", "Call.UndefinedError") }
  /// %@'s paused video
  public static func callVideoPaused(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.VideoPaused", p1)
  }
  /// Telegram needs access to camera for Video Call.
  public static var callCameraError: String  { return L10n.tr("Localizable", "Call.Camera.Error") }
  /// Call in Progress
  public static var callConfirmDiscardCallHeader: String  { return L10n.tr("Localizable", "Call.Confirm.Discard.Call.Header") }
  /// Finish call with "%1$@" and start a new one with "%2$@"?
  public static func callConfirmDiscardCallToCallText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Call.Confirm.Discard.Call.ToCall.Text", p1, p2)
  }
  /// Finish call with "%1$@" and start a voice chat with "%2$@"?
  public static func callConfirmDiscardCallToVoiceText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Call.Confirm.Discard.Call.ToVoice.Text", p1, p2)
  }
  /// Voice Chat in Progress
  public static var callConfirmDiscardVoiceHeader: String  { return L10n.tr("Localizable", "Call.Confirm.Discard.Voice.Header") }
  /// Leave voice chat in "%1$@" and start a call with "%2$@?"
  public static func callConfirmDiscardVoiceToCallText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Call.Confirm.Discard.Voice.ToCall.Text", p1, p2)
  }
  /// Leave voice chat in "%1$@" and start a new one with "%2$@"
  public static func callConfirmDiscardVoiceToVoiceText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Call.Confirm.Discard.Voice.ToVoice.Text", p1, p2)
  }
  /// Rate This Call
  public static var callContextRate: String  { return L10n.tr("Localizable", "Call.Context.Rate") }
  /// Not Now
  public static var callRatingModalNotNow: String  { return L10n.tr("Localizable", "Call.RatingModal.NotNow") }
  /// Leave comment...
  public static var callRatingModalPlaceholder: String  { return L10n.tr("Localizable", "Call.RatingModal.Placeholder") }
  /// Please rate the quality of your Telegram call
  public static var callRatingModalText: String  { return L10n.tr("Localizable", "Call.RatingModal.Text") }
  /// Incoming
  public static var callRecentIncoming: String  { return L10n.tr("Localizable", "Call.Recent.Incoming") }
  /// Missed
  public static var callRecentMissed: String  { return L10n.tr("Localizable", "Call.Recent.Missed") }
  /// Outgoing
  public static var callRecentOutgoing: String  { return L10n.tr("Localizable", "Call.Recent.Outgoing") }
  /// Sorry, you can’t make a call between two accounts on the same device.
  public static var callSameDeviceError: String  { return L10n.tr("Localizable", "Call.SameDevice.Error") }
  /// Telegram needs access for Screen Sharing.
  public static var callScreenError: String  { return L10n.tr("Localizable", "Call.Screen.Error") }
  /// %@'s camera is off
  public static func callToastCameraOff(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.Toast.CameraOff", p1)
  }
  /// %@'s battery is low
  public static func callToastLowBattery(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.Toast.LowBattery", p1)
  }
  /// %@'s microphone is off
  public static func callToastMicroOff(_ p1: String) -> String {
    return L10n.tr("Localizable", "Call.Toast.MicroOff", p1)
  }
  /// Add an optional comment
  public static var callFeedbackAddComment: String  { return L10n.tr("Localizable", "CallFeedback.AddComment") }
  /// Include technical information
  public static var callFeedbackIncludeLogs: String  { return L10n.tr("Localizable", "CallFeedback.IncludeLogs") }
  /// This won't reveal the contents of your conversation, but will help us fix the issue sooner.
  public static var callFeedbackIncludeLogsInfo: String  { return L10n.tr("Localizable", "CallFeedback.IncludeLogsInfo") }
  /// Speech was distorted
  public static var callFeedbackReasonDistortedSpeech: String  { return L10n.tr("Localizable", "CallFeedback.ReasonDistortedSpeech") }
  /// Call ended unexpectedly
  public static var callFeedbackReasonDropped: String  { return L10n.tr("Localizable", "CallFeedback.ReasonDropped") }
  /// I heard my own voice
  public static var callFeedbackReasonEcho: String  { return L10n.tr("Localizable", "CallFeedback.ReasonEcho") }
  /// The other side kept disappearing
  public static var callFeedbackReasonInterruption: String  { return L10n.tr("Localizable", "CallFeedback.ReasonInterruption") }
  /// I heard background noise
  public static var callFeedbackReasonNoise: String  { return L10n.tr("Localizable", "CallFeedback.ReasonNoise") }
  /// I couldn't hear the other side
  public static var callFeedbackReasonSilentLocal: String  { return L10n.tr("Localizable", "CallFeedback.ReasonSilentLocal") }
  /// The other side couldn't hear me
  public static var callFeedbackReasonSilentRemote: String  { return L10n.tr("Localizable", "CallFeedback.ReasonSilentRemote") }
  /// Send
  public static var callFeedbackSend: String  { return L10n.tr("Localizable", "CallFeedback.Send") }
  /// Thanks for\nyour feedback
  public static var callFeedbackSuccess: String  { return L10n.tr("Localizable", "CallFeedback.Success") }
  /// Call Feedback
  public static var callFeedbackTitle: String  { return L10n.tr("Localizable", "CallFeedback.Title") }
  /// Video was distorted
  public static var callFeedbackVideoReasonDistorted: String  { return L10n.tr("Localizable", "CallFeedback.VideoReasonDistorted") }
  /// Video was pixelated
  public static var callFeedbackVideoReasonLowQuality: String  { return L10n.tr("Localizable", "CallFeedback.VideoReasonLowQuality") }
  /// WHAT WENT WRONG?
  public static var callFeedbackWhatWentWrong: String  { return L10n.tr("Localizable", "CallFeedback.WhatWentWrong") }
  /// End Call
  public static var callHeaderEndCall: String  { return L10n.tr("Localizable", "CallHeader.EndCall") }
  /// Input Level
  public static var callSettingsInputLevel: String  { return L10n.tr("Localizable", "CallSettings.InputLevel") }
  /// Call Settings
  public static var callSettingsTitle: String  { return L10n.tr("Localizable", "CallSettings.Title") }
  /// CAMERA
  public static var callSettingsCameraTitle: String  { return L10n.tr("Localizable", "CallSettings.Camera.Title") }
  /// Default
  public static var callSettingsDeviceDefault: String  { return L10n.tr("Localizable", "CallSettings.Device.Default") }
  /// Input Device
  public static var callSettingsInputText: String  { return L10n.tr("Localizable", "CallSettings.Input.Text") }
  /// MICROPHONE
  public static var callSettingsInputTitle: String  { return L10n.tr("Localizable", "CallSettings.Input.Title") }
  /// The deletion process was cancelled for your account %@.
  public static func cancelResetAccountSuccess(_ p1: String) -> String {
    return L10n.tr("Localizable", "CancelResetAccount.Success", p1)
  }
  /// Somebody with access to your phone number **%@** has requested to delete your Telegram account and reset your 2-Step Verification password.\n\nIf it wasn't you, please enter the code we've just sent you via SMS to your number.
  public static func cancelResetAccountTextSMS(_ p1: String) -> String {
    return L10n.tr("Localizable", "CancelResetAccount.TextSMS", p1)
  }
  /// Cancel Account Reset
  public static var cancelResetAccountTitle: String  { return L10n.tr("Localizable", "CancelResetAccount.Title") }
  /// E
  public static var canvasClear: String  { return L10n.tr("Localizable", "Canvas.Clear") }
  /// L - Line\nA - Arrow
  public static var canvasDraw: String  { return L10n.tr("Localizable", "Canvas.Draw") }
  /// ⌘⇧Z
  public static var canvasRedo: String  { return L10n.tr("Localizable", "Canvas.Redo") }
  /// ⌘Z
  public static var canvasUndo: String  { return L10n.tr("Localizable", "Canvas.Undo") }
  /// All Admins
  public static var chanelEventFilterAllAdmins: String  { return L10n.tr("Localizable", "Chanel.EventFilter.AllAdmins") }
  /// All Events
  public static var chanelEventFilterAllEvents: String  { return L10n.tr("Localizable", "Chanel.EventFilter.AllEvents") }
  /// You have changed your phone number to %@.
  public static func changeNumberConfirmCodeSuccess(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChangeNumber.ConfirmCode.Success", p1)
  }
  /// Code expired.
  public static var changeNumberConfirmCodeErrorCodeExpired: String  { return L10n.tr("Localizable", "ChangeNumber.ConfirmCode.Error.codeExpired") }
  /// An error occurred.
  public static var changeNumberConfirmCodeErrorGeneric: String  { return L10n.tr("Localizable", "ChangeNumber.ConfirmCode.Error.Generic") }
  /// Invalid code. Please try again.
  public static var changeNumberConfirmCodeErrorInvalidCode: String  { return L10n.tr("Localizable", "ChangeNumber.ConfirmCode.Error.invalidCode") }
  /// You have entered invalid code too many times. Please try again later.
  public static var changeNumberConfirmCodeErrorLimitExceeded: String  { return L10n.tr("Localizable", "ChangeNumber.ConfirmCode.Error.limitExceeded") }
  /// An error occurred. Please try again later.
  public static var changeNumberSendDataErrorGeneric: String  { return L10n.tr("Localizable", "ChangeNumber.SendData.Error.Generic") }
  /// The phone number you entered is not valid. Please enter the correct number along with your area code.
  public static var changeNumberSendDataErrorInvalidPhoneNumber: String  { return L10n.tr("Localizable", "ChangeNumber.SendData.Error.InvalidPhoneNumber") }
  /// You have requested for an authorization code too many times. Please try again later.
  public static var changeNumberSendDataErrorLimitExceeded: String  { return L10n.tr("Localizable", "ChangeNumber.SendData.Error.LimitExceeded") }
  /// The number %@ is already connected to a Telegram account. Please delete that account before migrating to the new number.
  public static func changeNumberSendDataErrorPhoneNumberOccupied(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChangeNumber.SendData.Error.PhoneNumberOccupied", p1)
  }
  /// All your Telegram contacts will get your new number added to their address book, provided they had your old number and you haven't blocked them in Telegram.
  public static var changePhoneNumberIntroAlert: String  { return L10n.tr("Localizable", "ChangePhoneNumber.Intro.Alert") }
  /// You can change your Telegram number here. Your account and all your cloud data — messages, media, contacts, etc. will be moved to the new number.\n\n**Important**: all your Telegram contacts will get your **new number** added to their address book, provided they had your old number and you haven't blocked them in Telegram.
  public static var changePhoneNumberIntroDescription: String  { return L10n.tr("Localizable", "ChangePhoneNumber.Intro.Description") }
  /// Make Admin
  public static var channelAddBotAsAdmin: String  { return L10n.tr("Localizable", "Channel.AddBotAsAdmin") }
  /// Bots can only be added as administrators.
  public static var channelAddBotErrorHaveRights: String  { return L10n.tr("Localizable", "Channel.AddBotErrorHaveRights") }
  /// Sorry, bots can only be added to channels as administrators.
  public static var channelAddBotErrorNoRights: String  { return L10n.tr("Localizable", "Channel.AddBotErrorNoRights") }
  /// Forever
  public static var channelBanForever: String  { return L10n.tr("Localizable", "Channel.BanForever") }
  /// Sorry, this bot is telling us it doesn't want to be added to groups. You can't add this bot unless its developers change their mind.
  public static var channelBotDoesntSupportGroups: String  { return L10n.tr("Localizable", "Channel.BotDoesntSupportGroups") }
  /// Channel Name
  public static var channelChannelNameHolder: String  { return L10n.tr("Localizable", "Channel.ChannelNameHolder") }
  /// Create
  public static var channelCreate: String  { return L10n.tr("Localizable", "Channel.Create") }
  /// DESCRIPTION
  public static var channelDescHeader: String  { return L10n.tr("Localizable", "Channel.DescHeader") }
  /// Description
  public static var channelDescriptionHolder: String  { return L10n.tr("Localizable", "Channel.DescriptionHolder") }
  /// You can provide an optional description for your channel.
  public static var channelDescriptionHolderDescrpiton: String  { return L10n.tr("Localizable", "Channel.DescriptionHolderDescrpiton") }
  /// Sorry, you can't add this user to channels.
  public static var channelErrorAddBlocked: String  { return L10n.tr("Localizable", "Channel.ErrorAddBlocked") }
  /// Sorry, you can only add the first 200 members to a channel. Note that an unlimited number of people may join via the channel's link.
  public static var channelErrorAddTooMuch: String  { return L10n.tr("Localizable", "Channel.ErrorAddTooMuch") }
  /// People can join your channel by following this link. You can revoke the link at any time.
  public static var channelExportLinkAboutChannel: String  { return L10n.tr("Localizable", "Channel.ExportLinkAboutChannel") }
  /// People can join your group by following this link. You can revoke the link at any time.
  public static var channelExportLinkAboutGroup: String  { return L10n.tr("Localizable", "Channel.ExportLinkAboutGroup") }
  /// Channels are a tool for broadcasting your messages to unlimited audiences.
  public static var channelIntroDescription: String  { return L10n.tr("Localizable", "Channel.IntroDescription") }
  /// What is a Channel?
  public static var channelIntroDescriptionHeader: String  { return L10n.tr("Localizable", "Channel.IntroDescriptionHeader") }
  /// CHANNEL NAME
  public static var channelNameHeader: String  { return L10n.tr("Localizable", "Channel.NameHeader") }
  /// New Channel
  public static var channelNewChannel: String  { return L10n.tr("Localizable", "Channel.NewChannel") }
  /// Private
  public static var channelPrivate: String  { return L10n.tr("Localizable", "Channel.Private") }
  /// Private channels can only be joined via an invite link.
  public static var channelPrivateAboutChannel: String  { return L10n.tr("Localizable", "Channel.PrivateAboutChannel") }
  /// Private groups can only be joined if you were invited or have an invite link.
  public static var channelPrivateAboutGroup: String  { return L10n.tr("Localizable", "Channel.PrivateAboutGroup") }
  /// Public
  public static var channelPublic: String  { return L10n.tr("Localizable", "Channel.Public") }
  /// Public channels can be found in search, anyone can join them.
  public static var channelPublicAboutChannel: String  { return L10n.tr("Localizable", "Channel.PublicAboutChannel") }
  /// Public groups can be found in search, their chat history is available to everyone and anyone can join.
  public static var channelPublicAboutGroup: String  { return L10n.tr("Localizable", "Channel.PublicAboutGroup") }
  /// Sorry, you have reserved too many public usernames. You can revoke the link from one of your older groups or channels, or create a private entity instead
  public static var channelPublicNamesLimitError: String  { return L10n.tr("Localizable", "Channel.PublicNamesLimitError") }
  /// Revoke Link
  public static var channelRevokeLink: String  { return L10n.tr("Localizable", "Channel.RevokeLink") }
  /// Sorry, there are already too many bots in this group. Please remove some of the bots you're not using first.
  public static var channelTooMuchBots: String  { return L10n.tr("Localizable", "Channel.TooMuchBots") }
  /// CHANNEL TYPE
  public static var channelTypeHeaderChannel: String  { return L10n.tr("Localizable", "Channel.TypeHeaderChannel") }
  /// GROUP TYPE
  public static var channelTypeHeaderGroup: String  { return L10n.tr("Localizable", "Channel.TypeHeaderGroup") }
  /// People can share this link with others and can find your channel using Telegram search.
  public static var channelUsernameAboutChannel: String  { return L10n.tr("Localizable", "Channel.UsernameAboutChannel") }
  /// People can share this link with others and find your group using Telegram search.
  public static var channelUsernameAboutGroup: String  { return L10n.tr("Localizable", "Channel.UsernameAboutGroup") }
  /// USER RESTRICTIONS
  public static var channelUserRestriction: String  { return L10n.tr("Localizable", "Channel.UserRestriction") }
  /// This Admin will be able to add new admins with the same (or more limited) permissions than he/she has.
  public static var channelAdminAdminAccess: String  { return L10n.tr("Localizable", "Channel.Admin.AdminAccess") }
  /// This admin will not be able to add new admins.
  public static var channelAdminAdminRestricted: String  { return L10n.tr("Localizable", "Channel.Admin.AdminRestricted") }
  /// You are not allowed to edit the rights of this admin.
  public static var channelAdminCantEdit: String  { return L10n.tr("Localizable", "Channel.Admin.CantEdit") }
  /// You cannot edit the rights of this admin.
  public static var channelAdminCantEditRights: String  { return L10n.tr("Localizable", "Channel.Admin.CantEditRights") }
  /// Dismiss Admin
  public static var channelAdminDismiss: String  { return L10n.tr("Localizable", "Channel.Admin.Dismiss") }
  /// WHAT CAN THIS ADMIN DO?
  public static var channelAdminWhatCanAdminDo: String  { return L10n.tr("Localizable", "Channel.Admin.WhatCanAdminDo") }
  /// CUSTOM TITLE
  public static var channelAdminRoleHeader: String  { return L10n.tr("Localizable", "Channel.Admin.Role.Header") }
  /// A title that will be shown instead of 'admin'.
  public static var channelAdminRoleAdminDesc: String  { return L10n.tr("Localizable", "Channel.Admin.Role.Admin.Desc") }
  /// A title that will be shown instead of 'owner'.
  public static var channelAdminRoleOwnerDesc: String  { return L10n.tr("Localizable", "Channel.Admin.Role.Owner.Desc") }
  /// admin
  public static var channelAdminRolePlaceholderAdmin: String  { return L10n.tr("Localizable", "Channel.Admin.Role.Placeholder.Admin") }
  /// owner
  public static var channelAdminRolePlaceholderOwner: String  { return L10n.tr("Localizable", "Channel.Admin.Role.Placeholder.Owner") }
  /// Transfer Channel Ownership
  public static var channelAdminTransferOwnershipChannel: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Channel") }
  /// Transfer Group Ownership
  public static var channelAdminTransferOwnershipGroup: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Group") }
  /// Change Owner
  public static var channelAdminTransferOwnershipConfirmOK: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Confirm.OK") }
  /// This will transfer the full owner rights for %@ to %@.\n\nYou will no longer be considered the creator of the channel. The new owner will be free to remove any of your admin privileges or even ban you.
  public static func channelAdminTransferOwnershipConfirmChannelText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Confirm.Channel.Text", p1, p2)
  }
  /// Transfer Channel Ownership
  public static var channelAdminTransferOwnershipConfirmChannelTitle: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Confirm.Channel.Title") }
  /// This will transfer the full owner rights for %@ to %@.\n\nYou will no longer be considered the creator of the group. The new owner will be free to remove any of your admin privileges or even ban you.
  public static func channelAdminTransferOwnershipConfirmGroupText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Confirm.Group.Text", p1, p2)
  }
  /// Transfer Group Ownership
  public static var channelAdminTransferOwnershipConfirmGroupTitle: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Confirm.Group.Title") }
  /// Please enter your 2-Step verification password to complete the transfer.
  public static var channelAdminTransferOwnershipPasswordDesc: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Password.Desc") }
  /// Two-Step Verification
  public static var channelAdminTransferOwnershipPasswordTitle: String  { return L10n.tr("Localizable", "Channel.Admin.TransferOwnership.Password.Title") }
  /// %1$@ allowed new members to speak
  public static func channelAdminLogAllowedNewMembersToSpeak(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.AllowedNewMembersToSpeak", p1)
  }
  /// %1$@ updated the list of allowed reactions to: %2$@
  public static func channelAdminLogAllowedReactionsUpdated(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.AllowedReactionsUpdated", p1, p2)
  }
  /// Invite Users via Link
  public static var channelAdminLogCanInviteUsersViaLink: String  { return L10n.tr("Localizable", "Channel.AdminLog.CanInviteUsersViaLink") }
  /// Manage Voice Chats
  public static var channelAdminLogCanManageCalls: String  { return L10n.tr("Localizable", "Channel.AdminLog.CanManageCalls") }
  /// %1$@ created invite link %2$@
  public static func channelAdminLogCreatedInviteLink(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.CreatedInviteLink", p1, p2)
  }
  /// %1$@ deleted invite link %2$@
  public static func channelAdminLogDeletedInviteLink(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.DeletedInviteLink", p1, p2)
  }
  /// %1$@ edited invite link %2$@
  public static func channelAdminLogEditedInviteLink(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.EditedInviteLink", p1, p2)
  }
  /// %1$@ ended voice chat
  public static func channelAdminLogEndedVoiceChat(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.EndedVoiceChat", p1)
  }
  /// %1$@ joined via invite link %2$@
  public static func channelAdminLogJoinedViaInviteLink(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.JoinedViaInviteLink", p1, p2)
  }
  /// %1$@ joined via invite link %2$@, approved by %3$@
  public static func channelAdminLogJoinedViaRequest(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.JoinedViaRequest", p1, p2, p3)
  }
  /// %1$@ disabled auto-remove timer
  public static func channelAdminLogMessageChangedAutoremoveTimeoutRemove(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.MessageChangedAutoremoveTimeoutRemove", p1)
  }
  /// %1$@ set auto-remove timer to %2$@
  public static func channelAdminLogMessageChangedAutoremoveTimeoutSet(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.MessageChangedAutoremoveTimeoutSet", p1, p2)
  }
  /// %1$@ muted new members
  public static func channelAdminLogMutedNewMembers(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.MutedNewMembers", p1)
  }
  /// %1$@ muted %2$@
  public static func channelAdminLogMutedParticipant(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.MutedParticipant", p1, p2)
  }
  /// %1$@ disabled reactions
  public static func channelAdminLogReactionsDisabled(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.ReactionsDisabled", p1)
  }
  /// %1$@ revoked invite link %2$@
  public static func channelAdminLogRevokedInviteLink(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.RevokedInviteLink", p1, p2)
  }
  /// %1$@ started voice chat
  public static func channelAdminLogStartedVoiceChat(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.StartedVoiceChat", p1)
  }
  /// %1$@ unmuted %2$@
  public static func channelAdminLogUnmutedMutedParticipant(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.UnmutedMutedParticipant", p1, p2)
  }
  /// %1$@ changed %2$@ volume to %3$@
  public static func channelAdminLogUpdatedParticipantVolume(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Channel.AdminLog.UpdatedParticipantVolume", p1, p2, p3)
  }
  /// Sorry, you're not allowed to promote this user to become an admin.
  public static var channelAdminsAddAdminError: String  { return L10n.tr("Localizable", "Channel.Admins.AddAdminError") }
  /// promoted by %@
  public static func channelAdminsPromotedBy(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Admins.PromotedBy", p1)
  }
  /// Sorry, you can't add this user as an admin because they are in the blacklist and you can't unban them.
  public static var channelAdminsPromoteBannedAdminError: String  { return L10n.tr("Localizable", "Channel.Admins.Promote.BannedAdminError") }
  /// Sorry, you can't add this user as an admin because they are not a member of this group and you are not allowed to invite them.
  public static var channelAdminsPromoteUnmemberAdminError: String  { return L10n.tr("Localizable", "Channel.Admins.Promote.UnmemberAdminError") }
  /// Add Members
  public static var channelBanUserPermissionAddMembers: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionAddMembers") }
  /// Change Group Info
  public static var channelBanUserPermissionChangeGroupInfo: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionChangeGroupInfo") }
  /// Can Embed Links
  public static var channelBanUserPermissionEmbedLinks: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionEmbedLinks") }
  /// Can Read Messages
  public static var channelBanUserPermissionReadMessages: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionReadMessages") }
  /// Can Send Media
  public static var channelBanUserPermissionSendMedia: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionSendMedia") }
  /// Can Send Messages
  public static var channelBanUserPermissionSendMessages: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionSendMessages") }
  /// Send Polls
  public static var channelBanUserPermissionSendPolls: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionSendPolls") }
  /// Can Send Stickers & GIFs
  public static var channelBanUserPermissionSendStickersAndGifs: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionSendStickersAndGifs") }
  /// User Restrictions
  public static var channelBanUserPermissionsHeader: String  { return L10n.tr("Localizable", "Channel.BanUser.PermissionsHeader") }
  /// Ban User
  public static var channelBanUserTitle: String  { return L10n.tr("Localizable", "Channel.BanUser.Title") }
  /// Unban
  public static var channelBanUserUnban: String  { return L10n.tr("Localizable", "Channel.BanUser.Unban") }
  /// blocked by %@
  public static func channelBlacklistBlockedBy(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Blacklist.BlockedBy", p1)
  }
  /// Sorry, you can't ban this user because they are an admin of this group and you are not allowed to demote them.
  public static var channelBlacklistDemoteAdminError: String  { return L10n.tr("Localizable", "Channel.Blacklist.DemoteAdminError") }
  /// Users removed from the channel by admins cannot rejoin via invite links.
  public static var channelBlacklistDescChannel: String  { return L10n.tr("Localizable", "Channel.Blacklist.DescChannel") }
  /// Users removed from the group by admins cannot rejoin via invite links.
  public static var channelBlacklistDescGroup: String  { return L10n.tr("Localizable", "Channel.Blacklist.DescGroup") }
  /// Remove User
  public static var channelBlacklistRemoveUser: String  { return L10n.tr("Localizable", "Channel.Blacklist.RemoveUser") }
  /// restricted by %@
  public static func channelBlacklistRestrictedBy(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Blacklist.RestrictedBy", p1)
  }
  /// Members
  public static var channelBlacklistSelectNewUserTitle: String  { return L10n.tr("Localizable", "Channel.Blacklist.SelectNewUserTitle") }
  /// Unban
  public static var channelBlacklistUnban: String  { return L10n.tr("Localizable", "Channel.Blacklist.Unban") }
  /// Add To Group
  public static var channelBlacklistContextAddToGroup: String  { return L10n.tr("Localizable", "Channel.Blacklist.Context.AddToGroup") }
  /// Remove
  public static var channelBlacklistContextRemove: String  { return L10n.tr("Localizable", "Channel.Blacklist.Context.Remove") }
  /// Block For
  public static var channelBlockUserBlockFor: String  { return L10n.tr("Localizable", "Channel.BlockUser.BlockFor") }
  /// Can Embed Links
  public static var channelBlockUserCanEmbedLinks: String  { return L10n.tr("Localizable", "Channel.BlockUser.CanEmbedLinks") }
  /// Can Read Messages
  public static var channelBlockUserCanReadMessages: String  { return L10n.tr("Localizable", "Channel.BlockUser.CanReadMessages") }
  /// Can Send Media
  public static var channelBlockUserCanSendMedia: String  { return L10n.tr("Localizable", "Channel.BlockUser.CanSendMedia") }
  /// Can Send Messages
  public static var channelBlockUserCanSendMessages: String  { return L10n.tr("Localizable", "Channel.BlockUser.CanSendMessages") }
  /// Can Send Stickers & GIFs
  public static var channelBlockUserCanSendStickers: String  { return L10n.tr("Localizable", "Channel.BlockUser.CanSendStickers") }
  /// %d
  public static func channelCommentsCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_countable", p1)
  }
  /// %d Comments
  public static func channelCommentsCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_few", p1)
  }
  /// %d Comments
  public static func channelCommentsCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_many", p1)
  }
  /// %d Comment
  public static func channelCommentsCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_one", p1)
  }
  /// %d Comments
  public static func channelCommentsCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_other", p1)
  }
  /// %d Comments
  public static func channelCommentsCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_two", p1)
  }
  /// %d Comments
  public static func channelCommentsCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Count_zero", p1)
  }
  /// Leave a Comment
  public static var channelCommentsLeaveComment: String  { return L10n.tr("Localizable", "Channel.Comments.LeaveComment") }
  /// %d
  public static func channelCommentsShortCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_countable", p1)
  }
  /// %d
  public static func channelCommentsShortCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_few", p1)
  }
  /// %d
  public static func channelCommentsShortCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_many", p1)
  }
  /// %d
  public static func channelCommentsShortCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_one", p1)
  }
  /// %d
  public static func channelCommentsShortCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_other", p1)
  }
  /// %d
  public static func channelCommentsShortCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_two", p1)
  }
  /// %d
  public static func channelCommentsShortCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Channel.Comments.Short.Count_zero", p1)
  }
  /// Comment
  public static var channelCommentsShortLeaveComment: String  { return L10n.tr("Localizable", "Channel.Comments.Short.LeaveComment") }
  /// Manage Voice Chats
  public static var channelEditAdminManageCalls: String  { return L10n.tr("Localizable", "Channel.EditAdmin.ManageCalls") }
  /// Remain Anonymous
  public static var channelEditAdminPermissionAnonymous: String  { return L10n.tr("Localizable", "Channel.EditAdmin.PermissionAnonymous") }
  /// Add Members
  public static var channelEditAdminPermissionInviteMembers: String  { return L10n.tr("Localizable", "Channel.EditAdmin.PermissionInviteMembers") }
  /// Add Subscribers
  public static var channelEditAdminPermissionInviteSubscribers: String  { return L10n.tr("Localizable", "Channel.EditAdmin.PermissionInviteSubscribers") }
  /// Invite Users via Link
  public static var channelEditAdminPermissionInviteViaLink: String  { return L10n.tr("Localizable", "Channel.EditAdmin.PermissionInviteViaLink") }
  /// Add New Admins
  public static var channelEditAdminPermissionAddNewAdmins: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.AddNewAdmins") }
  /// Ban Users
  public static var channelEditAdminPermissionBanUsers: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.BanUsers") }
  /// Change Channel Info
  public static var channelEditAdminPermissionChangeInfo: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.ChangeInfo") }
  /// Delete Messages
  public static var channelEditAdminPermissionDeleteMessages: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.DeleteMessages") }
  /// Edit Messages
  public static var channelEditAdminPermissionEditMessages: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.EditMessages") }
  /// Pin Messages
  public static var channelEditAdminPermissionPinMessages: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.PinMessages") }
  /// Post Messages
  public static var channelEditAdminPermissionPostMessages: String  { return L10n.tr("Localizable", "Channel.EditAdmin.Permission.PostMessages") }
  /// Sorry, you don't have the necessary permissions for this action.
  public static var channelErrorDontHavePermissions: String  { return L10n.tr("Localizable", "Channel.Error.DontHavePermissions") }
  /// ADMINS
  public static var channelEventFilterAdminsHeader: String  { return L10n.tr("Localizable", "Channel.EventFilter.AdminsHeader") }
  /// EVENTS
  public static var channelEventFilterEventsHeader: String  { return L10n.tr("Localizable", "Channel.EventFilter.EventsHeader") }
  /// Empty
  public static var channelEventLogEmpty: String  { return L10n.tr("Localizable", "Channel.EventLog.Empty") }
  /// ** No events found**\n\nNo recent events that match your query have been found.
  public static var channelEventLogEmptySearch: String  { return L10n.tr("Localizable", "Channel.EventLog.EmptySearch") }
  /// **No events here yet**\n\nThere were no service actions taken by the channel's members and admins for the last 48 hours.
  public static var channelEventLogEmptyText: String  { return L10n.tr("Localizable", "Channel.EventLog.EmptyText") }
  /// %@ linked this group to %@
  public static func channelEventLogMessageChangedLinkedChannel(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageChangedLinkedChannel", p1, p2)
  }
  /// %@ linked %@ as the discussion group
  public static func channelEventLogMessageChangedLinkedGroup(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageChangedLinkedGroup", p1, p2)
  }
  /// %@ unlinked this group from %@
  public static func channelEventLogMessageChangedUnlinkedChannel(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageChangedUnlinkedChannel", p1, p2)
  }
  /// %@ removed discussion group
  public static func channelEventLogMessageChangedUnlinkedGroup(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageChangedUnlinkedGroup", p1)
  }
  /// changed custom title for %@: %@
  public static func channelEventLogMessageRankName(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageRankName", p1, p2)
  }
  /// transferred ownership
  public static var channelEventLogMessageTransfered: String  { return L10n.tr("Localizable", "Channel.EventLog.MessageTransfered") }
  /// transferred ownership to %1$@ %2$@
  public static func channelEventLogMessageTransferedName1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.MessageTransferedName1", p1, p2)
  }
  /// Original message
  public static var channelEventLogOriginalMessage: String  { return L10n.tr("Localizable", "Channel.EventLog.OriginalMessage") }
  /// What Is This?
  public static var channelEventLogWhat: String  { return L10n.tr("Localizable", "Channel.EventLog.What") }
  /// What is the event log?
  public static var channelEventLogAlertHeader: String  { return L10n.tr("Localizable", "Channel.EventLog.Alert.Header") }
  /// This is a list of all service actions taken by the group's members and admins in the last 48 hours.
  public static var channelEventLogAlertInfo: String  { return L10n.tr("Localizable", "Channel.EventLog.Alert.Info") }
  /// %@ removed this channel's description:
  public static func channelEventLogServiceAboutRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.AboutRemoved", p1)
  }
  /// %@ edited this channel's description:
  public static func channelEventLogServiceAboutUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.AboutUpdated", p1)
  }
  /// %@ disabled slowmode
  public static func channelEventLogServiceDisabledSlowMode(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.DisabledSlowMode", p1)
  }
  /// %@ disabled channel signatures
  public static func channelEventLogServiceDisableSignatures(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.DisableSignatures", p1)
  }
  /// %@ enabled channel signatures
  public static func channelEventLogServiceEnableSignatures(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.EnableSignatures", p1)
  }
  /// %@ removed channel link:
  public static func channelEventLogServiceLinkRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.LinkRemoved", p1)
  }
  /// %@ edited this channel's link:
  public static func channelEventLogServiceLinkUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.LinkUpdated", p1)
  }
  /// - Title
  public static var channelEventLogServiceMinusTitle: String  { return L10n.tr("Localizable", "Channel.EventLog.Service.MinusTitle") }
  /// %@ removed channel photo
  public static func channelEventLogServicePhotoRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.PhotoRemoved", p1)
  }
  /// %@ updated this channel's photo
  public static func channelEventLogServicePhotoUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.PhotoUpdated", p1)
  }
  /// + Title: %@
  public static func channelEventLogServicePlusTitle(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.PlusTitle", p1)
  }
  /// %1$@ set slowmode to %2$@
  public static func channelEventLogServiceSetSlowMode1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.SetSlowMode1", p1, p2)
  }
  /// %@ edited this channel's title:
  public static func channelEventLogServiceTitleUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.TitleUpdated", p1)
  }
  /// %@ joined the channel
  public static func channelEventLogServiceUpdateJoin(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.UpdateJoin", p1)
  }
  /// %@ left the channel
  public static func channelEventLogServiceUpdateLeft(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.EventLog.Service.UpdateLeft", p1)
  }
  /// This option is disabled in channel Permissions for all members.
  public static var channelExceptionDisabledOptionChannel: String  { return L10n.tr("Localizable", "Channel.Exception.DisabledOption.Channel") }
  /// This option is disabled in group's Permissions for all members.
  public static var channelExceptionDisabledOptionGroup: String  { return L10n.tr("Localizable", "Channel.Exception.DisabledOption.Group") }
  /// Create Channel
  public static var channelIntroCreateChannel: String  { return L10n.tr("Localizable", "Channel.Intro.CreateChannel") }
  /// SLOW MODE
  public static var channelPermissionsSlowModeHeader: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Header") }
  /// Members will be able to send only one message per this interval.
  public static var channelPermissionsSlowModeTextOff: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Text.Off") }
  /// Members will be able to send only one message every %@
  public static func channelPermissionsSlowModeTextSelected(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Text.Selected", p1)
  }
  /// 10s
  public static var channelPermissionsSlowModeTimeout10s: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.10s") }
  /// 15m
  public static var channelPermissionsSlowModeTimeout15m: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.15m") }
  /// 1h
  public static var channelPermissionsSlowModeTimeout1h: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.1h") }
  /// 1m
  public static var channelPermissionsSlowModeTimeout1m: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.1m") }
  /// 30s
  public static var channelPermissionsSlowModeTimeout30s: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.30s") }
  /// 5m
  public static var channelPermissionsSlowModeTimeout5m: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.5m") }
  /// Off
  public static var channelPermissionsSlowModeTimeoutOff: String  { return L10n.tr("Localizable", "Channel.Permissions.SlowMode.Timeout.Off") }
  /// Sending GIFs isn't allowed in this group.
  public static var channelPersmissionDeniedSendGifsDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendGifs.DefaultRestrictedText") }
  /// The admins of this group have restricted you from sending GIFs here.
  public static var channelPersmissionDeniedSendGifsForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendGifs.Forever") }
  /// The admins of this group have restricted you from sending GIFs here until %@.
  public static func channelPersmissionDeniedSendGifsUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendGifs.Until", p1)
  }
  /// Posting inline content isn't allowed in this group.
  public static var channelPersmissionDeniedSendInlineDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendInline.DefaultRestrictedText") }
  /// The admins of this group have restricted you from posting inline content here.
  public static var channelPersmissionDeniedSendInlineForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendInline.Forever") }
  /// The admins of this group have restricted you from posting inline content here until %@.
  public static func channelPersmissionDeniedSendInlineUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendInline.Until", p1)
  }
  /// Sending media isn't allowed in this group.
  public static var channelPersmissionDeniedSendMediaDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMedia.DefaultRestrictedText") }
  /// The admins of this group have restricted you from sending media here.
  public static var channelPersmissionDeniedSendMediaForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMedia.Forever") }
  /// The admins of this group have restricted you from sending media here until %@.
  public static func channelPersmissionDeniedSendMediaUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMedia.Until", p1)
  }
  /// Writing messages isn’t allowed in this group.
  public static var channelPersmissionDeniedSendMessagesDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMessages.DefaultRestrictedText") }
  /// The admins of this group have restricted you from writing here
  public static var channelPersmissionDeniedSendMessagesForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMessages.Forever") }
  /// The admins of this group have restricted you from writing here until %@.
  public static func channelPersmissionDeniedSendMessagesUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendMessages.Until", p1)
  }
  /// Posting polls isn't allowed in this group.
  public static var channelPersmissionDeniedSendPollDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendPoll.DefaultRestrictedText") }
  /// The admins of this group have restricted you from posting polls here.
  public static var channelPersmissionDeniedSendPollForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendPoll.Forever") }
  /// The admins of this group have restricted you from posting polls here until %@.
  public static func channelPersmissionDeniedSendPollUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendPoll.Until", p1)
  }
  /// Sending stickers isn't allowed in this group.
  public static var channelPersmissionDeniedSendStickersDefaultRestrictedText: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendStickers.DefaultRestrictedText") }
  /// The admins of this group have restricted you from sending stickers here.
  public static var channelPersmissionDeniedSendStickersForever: String  { return L10n.tr("Localizable", "Channel.Persmission.Denied.SendStickers.Forever") }
  /// The admins of this group have restricted you from sending stickers here until %@.
  public static func channelPersmissionDeniedSendStickersUntil(_ p1: String) -> String {
    return L10n.tr("Localizable", "Channel.Persmission.Denied.SendStickers.Until", p1)
  }
  /// Revoke Link
  public static var channelRevokeLinkConfirmHeader: String  { return L10n.tr("Localizable", "Channel.RevokeLink.Confirm.Header") }
  /// Revoke
  public static var channelRevokeLinkConfirmOK: String  { return L10n.tr("Localizable", "Channel.RevokeLink.Confirm.OK") }
  /// Are you sure you want to revoke this link? Once you do, no one will be able to join the group using it.
  public static var channelRevokeLinkConfirmText: String  { return L10n.tr("Localizable", "Channel.RevokeLink.Confirm.Text") }
  /// contacts
  public static var channelSelectPeersContacts: String  { return L10n.tr("Localizable", "Channel.SelectPeers.Contacts") }
  /// global
  public static var channelSelectPeersGlobal: String  { return L10n.tr("Localizable", "Channel.SelectPeers.Global") }
  /// Off
  public static var channelSlowModeOff: String  { return L10n.tr("Localizable", "Channel.SlowMode.Off") }
  /// Slowmode is enabled.\nYou can send your next message in %@:%@
  public static func channelSlowModeToolTip(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Channel.SlowMode.ToolTip", p1, p2)
  }
  /// **Preparing stats**\nPlease wait a few moments while we generate your stats
  public static var channelStatsLoading: String  { return L10n.tr("Localizable", "Channel.Stats.Loading") }
  /// Sorry, this channel has too many admins and the new owner can't be added. Please remove one of the existing admins first.
  public static var channelTransferOwnerErrorAdminsTooMuch: String  { return L10n.tr("Localizable", "Channel.TransferOwner.ErrorAdminsTooMuch") }
  /// Sorry, this user is not a member of this channel and their privacy settings prevent you from adding them manually.
  public static var channelTransferOwnerErrorPrivacyRestricted: String  { return L10n.tr("Localizable", "Channel.TransferOwner.ErrorPrivacyRestricted") }
  /// Sorry, the target user has too many public groups or channels already. Please ask them to make one of their existing groups or channels private first.
  public static var channelTransferOwnerErrorPublicChannelsTooMuch: String  { return L10n.tr("Localizable", "Channel.TransferOwner.ErrorPublicChannelsTooMuch") }
  /// Enable 2-Step Verification.
  public static var channelTransferOwnerErrorEnable2FA: String  { return L10n.tr("Localizable", "Channel.TransferOwner.Error.Enable2FA") }
  /// Ownership transfers are only available if:\n\n• 2-Step Verification was enabled for your account more than 7 days ago.\n\n• You have logged in on this device more than 24 hours ago.\n\nPlease come back later.
  public static var channelTransferOwnerErrorText: String  { return L10n.tr("Localizable", "Channel.TransferOwner.Error.Text") }
  /// Security Check
  public static var channelTransferOwnerErrorTitle: String  { return L10n.tr("Localizable", "Channel.TransferOwner.Error.Title") }
  /// Recent Actions
  public static var channelAdminsRecentActions: String  { return L10n.tr("Localizable", "ChannelAdmins.RecentActions") }
  /// BLOCKED
  public static var channelBlacklistBlocked: String  { return L10n.tr("Localizable", "ChannelBlacklist.Blocked") }
  /// Blacklisted users are removed from the group and can only come back if they are invited back by an admin. Invite links won't work for blacklisted users.
  public static var channelBlacklistEmptyDescrpition: String  { return L10n.tr("Localizable", "ChannelBlacklist.EmptyDescrpition") }
  /// RESTRICTED
  public static var channelBlacklistRestricted: String  { return L10n.tr("Localizable", "ChannelBlacklist.Restricted") }
  /// Channel Info
  public static var channelEventFilterChannelInfo: String  { return L10n.tr("Localizable", "ChannelEventFilter.ChannelInfo") }
  /// Deleted Messages
  public static var channelEventFilterDeletedMessages: String  { return L10n.tr("Localizable", "ChannelEventFilter.DeletedMessages") }
  /// Edited Messages
  public static var channelEventFilterEditedMessages: String  { return L10n.tr("Localizable", "ChannelEventFilter.EditedMessages") }
  /// Group Info
  public static var channelEventFilterGroupInfo: String  { return L10n.tr("Localizable", "ChannelEventFilter.GroupInfo") }
  /// Invite Links
  public static var channelEventFilterInvites: String  { return L10n.tr("Localizable", "ChannelEventFilter.Invites") }
  /// Members Removed
  public static var channelEventFilterLeavingMembers: String  { return L10n.tr("Localizable", "ChannelEventFilter.LeavingMembers") }
  /// New Admins
  public static var channelEventFilterNewAdmins: String  { return L10n.tr("Localizable", "ChannelEventFilter.NewAdmins") }
  /// New Members
  public static var channelEventFilterNewMembers: String  { return L10n.tr("Localizable", "ChannelEventFilter.NewMembers") }
  /// New Restrictions
  public static var channelEventFilterNewRestrictions: String  { return L10n.tr("Localizable", "ChannelEventFilter.NewRestrictions") }
  /// Pinned Messages
  public static var channelEventFilterPinnedMessages: String  { return L10n.tr("Localizable", "ChannelEventFilter.PinnedMessages") }
  /// Send Messages
  public static var channelEventFilterSendMessages: String  { return L10n.tr("Localizable", "ChannelEventFilter.SendMessages") }
  /// Voice Chats
  public static var channelEventFilterVoiceChats: String  { return L10n.tr("Localizable", "ChannelEventFilter.VoiceChats") }
  /// Sorry, if a person left a channel, only a mutual contact can bring them back (they need to have your phone number, and you need theirs).
  public static var channelInfoAddUserLeftError: String  { return L10n.tr("Localizable", "ChannelInfo.AddUserLeftError") }
  /// ⚠️ Warning: Many users reported that this channel impersonates a famous person or organization.
  public static var channelInfoFakeWarning: String  { return L10n.tr("Localizable", "ChannelInfo.FakeWarning") }
  /// ⚠️ Warning: Many users reported this channel as a scam. Please be careful, especially if it asks you for money.
  public static var channelInfoScamWarning: String  { return L10n.tr("Localizable", "ChannelInfo.ScamWarning") }
  /// Add Members
  public static var channelMembersAddMembers: String  { return L10n.tr("Localizable", "ChannelMembers.AddMembers") }
  /// Add Subscribers
  public static var channelMembersAddSubscribers: String  { return L10n.tr("Localizable", "ChannelMembers.AddSubscribers") }
  /// Invite via Link
  public static var channelMembersInviteLink: String  { return L10n.tr("Localizable", "ChannelMembers.InviteLink") }
  /// Only channel admins can see this list.
  public static var channelMembersMembersListDesc: String  { return L10n.tr("Localizable", "ChannelMembers.MembersListDesc") }
  /// Add Members
  public static var channelMembersSelectTitle: String  { return L10n.tr("Localizable", "ChannelMembers.Select.Title") }
  /// OVERVIEW
  public static var channelStatsOverview: String  { return L10n.tr("Localizable", "ChannelStats.Overview") }
  /// %d
  public static func channelStatsSharesCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_countable", p1)
  }
  /// %d shares
  public static func channelStatsSharesCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_few", p1)
  }
  /// %d shares
  public static func channelStatsSharesCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_many", p1)
  }
  /// %d shares
  public static func channelStatsSharesCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_one", p1)
  }
  /// %d shares
  public static func channelStatsSharesCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_other", p1)
  }
  /// %d shares
  public static func channelStatsSharesCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.SharesCount_two", p1)
  }
  /// No shares
  public static var channelStatsSharesCountZero: String  { return L10n.tr("Localizable", "ChannelStats.SharesCount_zero") }
  /// Channel Statistics
  public static var channelStatsTitle: String  { return L10n.tr("Localizable", "ChannelStats.Title") }
  /// %d
  public static func channelStatsViewsCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_countable", p1)
  }
  /// %d views
  public static func channelStatsViewsCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_few", p1)
  }
  /// %d views
  public static func channelStatsViewsCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_many", p1)
  }
  /// %d views
  public static func channelStatsViewsCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_one", p1)
  }
  /// %d views
  public static func channelStatsViewsCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_other", p1)
  }
  /// %d views
  public static func channelStatsViewsCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChannelStats.ViewsCount_two", p1)
  }
  /// No views
  public static var channelStatsViewsCountZero: String  { return L10n.tr("Localizable", "ChannelStats.ViewsCount_zero") }
  /// FOLLOWERS
  public static var channelStatsGraphFollowers: String  { return L10n.tr("Localizable", "ChannelStats.Graph.Followers") }
  /// GROWTH
  public static var channelStatsGraphGrowth: String  { return L10n.tr("Localizable", "ChannelStats.Graph.Growth") }
  /// INTERACTIONS
  public static var channelStatsGraphInteractions: String  { return L10n.tr("Localizable", "ChannelStats.Graph.Interactions") }
  /// LANGUAGE
  public static var channelStatsGraphLanguage: String  { return L10n.tr("Localizable", "ChannelStats.Graph.Language") }
  /// FOLLOWERS BY SOURCE
  public static var channelStatsGraphNewFollowersBySource: String  { return L10n.tr("Localizable", "ChannelStats.Graph.NewFollowersBySource") }
  /// NOTIFICATIONS
  public static var channelStatsGraphNotifications: String  { return L10n.tr("Localizable", "ChannelStats.Graph.Notifications") }
  /// VIEWS BY HOURS (UTC)
  public static var channelStatsGraphViewsByHours: String  { return L10n.tr("Localizable", "ChannelStats.Graph.ViewsByHours") }
  /// VIEWS BY SOURCE
  public static var channelStatsGraphViewsBySource: String  { return L10n.tr("Localizable", "ChannelStats.Graph.ViewsBySource") }
  /// Enabled Notifications
  public static var channelStatsOverviewEnabledNotifications: String  { return L10n.tr("Localizable", "ChannelStats.Overview.EnabledNotifications") }
  /// Followers
  public static var channelStatsOverviewFollowers: String  { return L10n.tr("Localizable", "ChannelStats.Overview.Followers") }
  /// Shares Per Post
  public static var channelStatsOverviewSharesPerPost: String  { return L10n.tr("Localizable", "ChannelStats.Overview.SharesPerPost") }
  /// Views Per Post
  public static var channelStatsOverviewViewsPerPost: String  { return L10n.tr("Localizable", "ChannelStats.Overview.ViewsPerPost") }
  /// RECENT POSTS
  public static var channelStatsRecentHeader: String  { return L10n.tr("Localizable", "ChannelStats.Recent.Header") }
  /// Checking...
  public static var channelVisibilityChecking: String  { return L10n.tr("Localizable", "ChannelVisibility.Checking") }
  /// Loading...
  public static var channelVisibilityLoading: String  { return L10n.tr("Localizable", "ChannelVisibility.Loading") }
  /// Are you sure you want to make this channel private and remove its username?
  public static var channelVisibilityConfirmRevoke: String  { return L10n.tr("Localizable", "ChannelVisibility.Confirm.Revoke") }
  /// If you make this channel private, the name @%@ will be removed. Anyone else will be able to take it for their public groups or channels.
  public static func channelVisibilityConfirmMakePrivateChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChannelVisibility.Confirm.MakePrivate.Channel", p1)
  }
  /// If you make this group private, the name @%@ will be removed. Anyone else will be able to take it for their public groups or channels.
  public static func channelVisibilityConfirmMakePrivateGroup(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChannelVisibility.Confirm.MakePrivate.Group", p1)
  }
  /// Participants can forward messages from this channel and save media files.
  public static var channelVisibilityForwardingChannelInfo: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.ChannelInfo") }
  /// Forwarding From This Channel
  public static var channelVisibilityForwardingChannelTitle: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.ChannelTitle") }
  /// Restrict Forwarding
  public static var channelVisibilityForwardingDisabled: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.Disabled") }
  /// Allow Forwarding
  public static var channelVisibilityForwardingEnabled: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.Enabled") }
  /// Participants can forward messages from this group and save media files.
  public static var channelVisibilityForwardingGroupInfo: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.GroupInfo") }
  /// Forwarding From This Group
  public static var channelVisibilityForwardingGroupTitle: String  { return L10n.tr("Localizable", "ChannelVisibility.Forwarding.GroupTitle") }
  /// Manage Links
  public static var channelVisibiltiyManageLinks: String  { return L10n.tr("Localizable", "ChannelVisibiltiy.ManageLinks") }
  /// PERMANENT LINK
  public static var channelVisibiltiyPermanentLink: String  { return L10n.tr("Localizable", "ChannelVisibiltiy.PermanentLink") }
  /// Copy
  public static var channelVisibiltiyContextCopy: String  { return L10n.tr("Localizable", "ChannelVisibiltiy.Context.Copy") }
  /// Revoke
  public static var channelVisibiltiyContextRevoke: String  { return L10n.tr("Localizable", "ChannelVisibiltiy.Context.Revoke") }
  /// admin
  public static var chatAdminBadge: String  { return L10n.tr("Localizable", "Chat.AdminBadge") }
  /// ADD PROXY
  public static var chatApplyProxy: String  { return L10n.tr("Localizable", "Chat.ApplyProxy") }
  /// Cancel
  public static var chatCancel: String  { return L10n.tr("Localizable", "Chat.Cancel") }
  /// channel
  public static var chatChannelBadge: String  { return L10n.tr("Localizable", "Chat.ChannelBadge") }
  /// Copy Selected Text
  public static var chatCopySelectedText: String  { return L10n.tr("Localizable", "Chat.CopySelectedText") }
  /// without compression
  public static var chatDropAsFilesDesc: String  { return L10n.tr("Localizable", "Chat.DropAsFilesDesc") }
  /// Edit Media
  public static var chatDropEditDesc: String  { return L10n.tr("Localizable", "Chat.DropEditDesc") }
  /// Drop file there to edit media
  public static var chatDropEditTitle: String  { return L10n.tr("Localizable", "Chat.DropEditTitle") }
  /// in a quick way
  public static var chatDropQuickDesc: String  { return L10n.tr("Localizable", "Chat.DropQuickDesc") }
  /// Drop files here to send them
  public static var chatDropTitle: String  { return L10n.tr("Localizable", "Chat.DropTitle") }
  /// No messages here yet
  public static var chatEmptyChat: String  { return L10n.tr("Localizable", "Chat.EmptyChat") }
  /// Forward Messages
  public static var chatForwardActionHeader: String  { return L10n.tr("Localizable", "Chat.ForwardActionHeader") }
  /// INSTANT VIEW
  public static var chatInstantView: String  { return L10n.tr("Localizable", "Chat.InstantView") }
  /// **%1$@** is an admin of **%2$@**, a channel you requested to join.
  public static func chatInviteRequestAdminChannel(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.InviteRequestAdminChannel", p1, p2)
  }
  /// **%1$@** is an admin of **%2$@**, a group you requested to join.
  public static func chatInviteRequestAdminGroup(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.InviteRequestAdminGroup", p1, p2)
  }
  /// You received this message because you requested to join %1$@ on %2$@.
  public static func chatInviteRequestInfo(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.InviteRequestInfo", p1, p2)
  }
  /// Live Location
  public static var chatLiveLocation: String  { return L10n.tr("Localizable", "Chat.LiveLocation") }
  /// owner
  public static var chatOwnerBadge: String  { return L10n.tr("Localizable", "Chat.OwnerBadge") }
  /// %d of %d
  public static func chatSearchCount(_ p1: Int, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Chat.SearchCount", p1, p2)
  }
  /// from:
  public static var chatSearchFrom: String  { return L10n.tr("Localizable", "Chat.SearchFrom") }
  /// Sorry, you can only send messages to mutual contacts at the moment.
  public static var chatSendMessageErrorFlood: String  { return L10n.tr("Localizable", "Chat.SendMessageErrorFlood") }
  /// Sorry, you are currently restricted from posting to public groups.
  public static var chatSendMessageErrorGroupRestricted: String  { return L10n.tr("Localizable", "Chat.SendMessageErrorGroupRestricted") }
  /// Slowmode is enabled.
  public static var chatSendMessageSlowmodeError: String  { return L10n.tr("Localizable", "Chat.SendMessageSlowmodeError") }
  /// Share
  public static var chatShareInlineResultActionHeader: String  { return L10n.tr("Localizable", "Chat.ShareInlineResultActionHeader") }
  /// Feed
  public static var chatTitleFeed: String  { return L10n.tr("Localizable", "Chat.TitleFeed") }
  /// %d
  public static func chatUnpinAllMessagesConfirmationCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_countable", p1)
  }
  /// Do you want to unpin all %d messages in this chat?
  public static func chatUnpinAllMessagesConfirmationFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_few", p1)
  }
  /// Do you want to unpin all %d messages in this chat?
  public static func chatUnpinAllMessagesConfirmationMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_many", p1)
  }
  /// Do you want to unpin all %d message in this chat?
  public static func chatUnpinAllMessagesConfirmationOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_one", p1)
  }
  /// Do you want to unpin all %d messages in this chat?
  public static func chatUnpinAllMessagesConfirmationOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_other", p1)
  }
  /// Do you want to unpin all %d messages in this chat?
  public static func chatUnpinAllMessagesConfirmationTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_two", p1)
  }
  /// Do you want to unpin all %d messages in this chat?
  public static func chatUnpinAllMessagesConfirmationZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UnpinAllMessagesConfirmation_zero", p1)
  }
  /// VIEW BACKGROUND
  public static var chatViewBackground: String  { return L10n.tr("Localizable", "Chat.ViewBackground") }
  /// VIEW CONTACT
  public static var chatViewContact: String  { return L10n.tr("Localizable", "Chat.ViewContact") }
  /// %d
  public static func chatAccessoryForwardCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Forward_countable", p1)
  }
  /// Forward %d Messages
  public static func chatAccessoryForwardFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Forward_few", p1)
  }
  /// Forward %d Messages
  public static func chatAccessoryForwardMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Forward_many", p1)
  }
  /// Forward Message
  public static var chatAccessoryForwardOne: String  { return L10n.tr("Localizable", "Chat.Accessory.Forward_one") }
  /// Forward %d Messages
  public static func chatAccessoryForwardOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Forward_other", p1)
  }
  /// Forward %d Messages
  public static func chatAccessoryForwardTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Forward_two", p1)
  }
  /// Forward Messages
  public static var chatAccessoryForwardZero: String  { return L10n.tr("Localizable", "Chat.Accessory.Forward_zero") }
  /// %d
  public static func chatAccessoryHiddenCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Hidden_countable", p1)
  }
  /// Forward %d Messages (sender's names hidden)
  public static func chatAccessoryHiddenFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Hidden_few", p1)
  }
  /// Forward %d Messages (sender's names hidden)
  public static func chatAccessoryHiddenMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Hidden_many", p1)
  }
  /// Forward Message (sender's names hidden)
  public static var chatAccessoryHiddenOne: String  { return L10n.tr("Localizable", "Chat.Accessory.Hidden_one") }
  /// Forward %d Messages (sender's names hidden)
  public static func chatAccessoryHiddenOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Hidden_other", p1)
  }
  /// Forward %d Messages (sender's names hidden)
  public static func chatAccessoryHiddenTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Accessory.Hidden_two", p1)
  }
  /// Forward Messages (sender's names hidden)
  public static var chatAccessoryHiddenZero: String  { return L10n.tr("Localizable", "Chat.Accessory.Hidden_zero") }
  /// From
  public static var chatAccessoryForwardFrom: String  { return L10n.tr("Localizable", "Chat.Accessory.Forward.From") }
  /// You
  public static var chatAccessoryForwardYou: String  { return L10n.tr("Localizable", "Chat.Accessory.Forward.You") }
  /// VIEW THEME
  public static var chatActionViewTheme: String  { return L10n.tr("Localizable", "Chat.Action.ViewTheme") }
  /// %d
  public static func chatAlertForwardHeaderCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_countable", p1)
  }
  /// %d Messages
  public static func chatAlertForwardHeaderFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_few", p1)
  }
  /// %d Messages
  public static func chatAlertForwardHeaderMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_many", p1)
  }
  /// %d Message
  public static func chatAlertForwardHeaderOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_one", p1)
  }
  /// %d Messages
  public static func chatAlertForwardHeaderOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_other", p1)
  }
  /// %d Messages
  public static func chatAlertForwardHeaderTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_two", p1)
  }
  /// %d Messages
  public static func chatAlertForwardHeaderZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Header_zero", p1)
  }
  /// What would you like to do with %1$@ from %2$@?
  public static func chatAlertForwardText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text", p1, p2)
  }
  /// Forward to Another Chat
  public static var chatAlertForwardActionAnother: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Another") }
  /// Cancel Forwarding
  public static var chatAlertForwardActionCancel: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Cancel") }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide") }
  /// %d
  public static func chatAlertForwardActionHide1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_countable", p1)
  }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide1Few: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_few") }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide1Many: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_many") }
  /// Hide Sender Name
  public static var chatAlertForwardActionHide1One: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_one") }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide1Other: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_other") }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide1Two: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_two") }
  /// Hide Sender's Names
  public static var chatAlertForwardActionHide1Zero: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Hide1_zero") }
  /// %d
  public static func chatAlertForwardActionHideCaptionCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_countable", p1)
  }
  /// Hide Captions
  public static var chatAlertForwardActionHideCaptionFew: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_few") }
  /// Hide Captions
  public static var chatAlertForwardActionHideCaptionMany: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_many") }
  /// Hide Caption
  public static var chatAlertForwardActionHideCaptionOne: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_one") }
  /// Hide Captions
  public static var chatAlertForwardActionHideCaptionOther: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_other") }
  /// Hide Captions
  public static var chatAlertForwardActionHideCaptionTwo: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_two") }
  /// Hide Captions
  public static var chatAlertForwardActionHideCaptionZero: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.HideCaption_zero") }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show") }
  /// %d
  public static func chatAlertForwardActionShow1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_countable", p1)
  }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow1Few: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_few") }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow1Many: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_many") }
  /// Show Sender Name
  public static var chatAlertForwardActionShow1One: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_one") }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow1Other: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_other") }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow1Two: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_two") }
  /// Show Sender's Names
  public static var chatAlertForwardActionShow1Zero: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.Show1_zero") }
  /// %d
  public static func chatAlertForwardActionShowCaptionCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_countable", p1)
  }
  /// Show Captions
  public static var chatAlertForwardActionShowCaptionFew: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_few") }
  /// Show Captions
  public static var chatAlertForwardActionShowCaptionMany: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_many") }
  /// Show Caption
  public static var chatAlertForwardActionShowCaptionOne: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_one") }
  /// Show Captions
  public static var chatAlertForwardActionShowCaptionOther: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_other") }
  /// Show Captions
  public static var chatAlertForwardActionShowCaptionTwo: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_two") }
  /// Show Captions
  public static var chatAlertForwardActionShowCaptionZero: String  { return L10n.tr("Localizable", "Chat.Alert.Forward.Action.ShowCaption_zero") }
  /// %d
  public static func chatAlertForwardTextInnerCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_countable", p1)
  }
  /// %d messages
  public static func chatAlertForwardTextInnerFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_few", p1)
  }
  /// %d messages
  public static func chatAlertForwardTextInnerMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_many", p1)
  }
  /// %d message
  public static func chatAlertForwardTextInnerOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_one", p1)
  }
  /// %d messages
  public static func chatAlertForwardTextInnerOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_other", p1)
  }
  /// %d messages
  public static func chatAlertForwardTextInnerTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_two", p1)
  }
  /// %d messages
  public static func chatAlertForwardTextInnerZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Alert.Forward.Text.Inner_zero", p1)
  }
  /// Forwarded from: [%@]()
  public static func chatBubblesForwardedFrom(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Bubbles.ForwardedFrom", p1)
  }
  /// Incoming Call
  public static var chatCallIncoming: String  { return L10n.tr("Localizable", "Chat.Call.Incoming") }
  /// Outgoing Call
  public static var chatCallOutgoing: String  { return L10n.tr("Localizable", "Chat.Call.Outgoing") }
  /// Sorry, this channel is not accessible.
  public static var chatChannelUnaccessible: String  { return L10n.tr("Localizable", "Chat.Channel.Unaccessible") }
  /// Apply Theme
  public static var chatChatThemeApplyTheme: String  { return L10n.tr("Localizable", "Chat.ChatTheme.ApplyTheme") }
  /// Cancel
  public static var chatChatThemeCancel: String  { return L10n.tr("Localizable", "Chat.ChatTheme.Cancel") }
  /// No\nTheme
  public static var chatChatThemeNoTheme: String  { return L10n.tr("Localizable", "Chat.ChatTheme.NoTheme") }
  /// You have been blocked to posting comments.
  public static var chatCommentsKicked: String  { return L10n.tr("Localizable", "Chat.Comments.Kicked") }
  /// No comments here yet...
  public static var chatCommentsHeaderEmpty: String  { return L10n.tr("Localizable", "Chat.CommentsHeader.Empty") }
  /// Discussion started
  public static var chatCommentsHeaderFull: String  { return L10n.tr("Localizable", "Chat.CommentsHeader.Full") }
  /// This action can't be undone
  public static var chatConfirmActionUndonable: String  { return L10n.tr("Localizable", "Chat.Confirm.ActionUndonable") }
  /// %d
  public static func chatConfirmDeleteForEveryoneCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_countable", p1)
  }
  /// Are you sure you want to delete this messages for everyone?
  public static var chatConfirmDeleteForEveryoneFew: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_few") }
  /// Are you sure you want to delete this messages for everyone?
  public static var chatConfirmDeleteForEveryoneMany: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_many") }
  /// Are you sure you want to delete this message for everyone?
  public static var chatConfirmDeleteForEveryoneOne: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_one") }
  /// Are you sure you want to delete this messages for everyone?
  public static var chatConfirmDeleteForEveryoneOther: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_other") }
  /// Are you sure you want to delete this messages for everyone?
  public static var chatConfirmDeleteForEveryoneTwo: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_two") }
  /// Are you sure you want to delete this messages for everyone?
  public static var chatConfirmDeleteForEveryoneZero: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteForEveryone_zero") }
  /// %d
  public static func chatConfirmDeleteMessages1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_countable", p1)
  }
  /// Delete selected messages?
  public static var chatConfirmDeleteMessages1Few: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_few") }
  /// Delete selected messages?
  public static var chatConfirmDeleteMessages1Many: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_many") }
  /// Delete selected message?
  public static var chatConfirmDeleteMessages1One: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_one") }
  /// Delete selected messages?
  public static var chatConfirmDeleteMessages1Other: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_other") }
  /// Delete selected messages?
  public static var chatConfirmDeleteMessages1Two: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_two") }
  /// Delete selected messages?
  public static var chatConfirmDeleteMessages1Zero: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessages1_zero") }
  /// Delete for Everyone
  public static var chatConfirmDeleteMessagesForEveryone: String  { return L10n.tr("Localizable", "Chat.Confirm.DeleteMessagesForEveryone") }
  /// Pin for me and %@
  public static func chatConfirmPinFor(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Confirm.PinFor", p1)
  }
  /// Do you want to pin an older message while leaving a more recent one pinned?
  public static var chatConfirmPinOld: String  { return L10n.tr("Localizable", "Chat.Confirm.PinOld") }
  /// Report Spam?
  public static var chatConfirmReportSpam: String  { return L10n.tr("Localizable", "Chat.Confirm.ReportSpam") }
  /// Are you sure you want to report spam from this user?
  public static var chatConfirmReportSpamUser: String  { return L10n.tr("Localizable", "Chat.Confirm.ReportSpamUser") }
  /// Would you like to unpin this message?
  public static var chatConfirmUnpin: String  { return L10n.tr("Localizable", "Chat.Confirm.Unpin") }
  /// Report Spam and leave channel?
  public static var chatConfirmReportSpamChannel: String  { return L10n.tr("Localizable", "Chat.Confirm.ReportSpam.Channel") }
  /// Report Spam and leave group?
  public static var chatConfirmReportSpamGroup: String  { return L10n.tr("Localizable", "Chat.Confirm.ReportSpam.Group") }
  /// Report Spam
  public static var chatConfirmReportSpamHeader: String  { return L10n.tr("Localizable", "Chat.Confirm.ReportSpam.Header") }
  /// Unpin message
  public static var chatConfirmUnpinHeader: String  { return L10n.tr("Localizable", "Chat.Confirm.Unpin.Header") }
  /// Unpin
  public static var chatConfirmUnpinOK: String  { return L10n.tr("Localizable", "Chat.Confirm.Unpin.OK") }
  /// Connecting
  public static var chatConnectingStatusConnecting: String  { return L10n.tr("Localizable", "Chat.ConnectingStatus.connecting") }
  /// Connecting to proxy
  public static var chatConnectingStatusConnectingToProxy: String  { return L10n.tr("Localizable", "Chat.ConnectingStatus.connectingToProxy") }
  /// Updating
  public static var chatConnectingStatusUpdating: String  { return L10n.tr("Localizable", "Chat.ConnectingStatus.updating") }
  /// Waiting for network
  public static var chatConnectingStatusWaitingNetwork: String  { return L10n.tr("Localizable", "Chat.ConnectingStatus.waitingNetwork") }
  /// Add to Favorites
  public static var chatContextAddFavoriteSticker: String  { return L10n.tr("Localizable", "Chat.Context.AddFavoriteSticker") }
  /// Archive
  public static var chatContextArchive: String  { return L10n.tr("Localizable", "Chat.Context.Archive") }
  /// Auto-Delete Messages
  public static var chatContextAutoDelete: String  { return L10n.tr("Localizable", "Chat.Context.AutoDelete") }
  /// Block Group
  public static var chatContextBlockGroup: String  { return L10n.tr("Localizable", "Chat.Context.BlockGroup") }
  /// Block User
  public static var chatContextBlockUser: String  { return L10n.tr("Localizable", "Chat.Context.BlockUser") }
  /// Cancel Editing
  public static var chatContextCancelEditing: String  { return L10n.tr("Localizable", "Chat.Context.CancelEditing") }
  /// Clear Chat History
  public static var chatContextClearHistory: String  { return L10n.tr("Localizable", "Chat.Context.ClearHistory") }
  /// Clear All
  public static var chatContextClearScheduled: String  { return L10n.tr("Localizable", "Chat.Context.ClearScheduled") }
  /// Copy
  public static var chatContextCopy: String  { return L10n.tr("Localizable", "Chat.Context.Copy") }
  /// Copy Preformatted Block
  public static var chatContextCopyBlock: String  { return L10n.tr("Localizable", "Chat.Context.CopyBlock") }
  /// Copy Media
  public static var chatContextCopyMedia: String  { return L10n.tr("Localizable", "Chat.Context.CopyMedia") }
  /// Copy Text
  public static var chatContextCopyText: String  { return L10n.tr("Localizable", "Chat.Context.CopyText") }
  /// Create Group
  public static var chatContextCreateGroup: String  { return L10n.tr("Localizable", "Chat.Context.CreateGroup") }
  /// Unmute
  public static var chatContextDisableNotifications: String  { return L10n.tr("Localizable", "Chat.Context.DisableNotifications") }
  /// Edit
  public static var chatContextEdit1: String  { return L10n.tr("Localizable", "Chat.Context.Edit1") }
  /// click on date
  public static var chatContextEditHelp: String  { return L10n.tr("Localizable", "Chat.Context.EditHelp") }
  /// Mute
  public static var chatContextEnableNotifications: String  { return L10n.tr("Localizable", "Chat.Context.EnableNotifications") }
  /// Channels Info
  public static var chatContextFeedInfo: String  { return L10n.tr("Localizable", "Chat.Context.FeedInfo") }
  /// Info
  public static var chatContextInfo: String  { return L10n.tr("Localizable", "Chat.Context.Info") }
  /// %1$@/%2$@ Reacted
  public static func chatContextReacted(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Context.Reacted", p1, p2)
  }
  /// %d
  public static func chatContextReactedFastCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_countable", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_few", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_many", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_one", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_other", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_two", p1)
  }
  /// %d Reacted
  public static func chatContextReactedFastZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Context.ReactedFast_zero", p1)
  }
  /// Remove from Favorites
  public static var chatContextRemoveFavoriteSticker: String  { return L10n.tr("Localizable", "Chat.Context.RemoveFavoriteSticker") }
  /// Restrict
  public static var chatContextRestrict: String  { return L10n.tr("Localizable", "Chat.Context.Restrict") }
  /// Save as...
  public static var chatContextSaveMedia: String  { return L10n.tr("Localizable", "Chat.Context.SaveMedia") }
  /// Shared Media
  public static var chatContextSharedMedia: String  { return L10n.tr("Localizable", "Chat.Context.SharedMedia") }
  /// Translate
  public static var chatContextTranslate: String  { return L10n.tr("Localizable", "Chat.Context.Translate") }
  /// Unarchive
  public static var chatContextUnarchive: String  { return L10n.tr("Localizable", "Chat.Context.Unarchive") }
  /// Cancel
  public static var chatContextBlockGroupCancel: String  { return L10n.tr("Localizable", "Chat.Context.BlockGroup.Cancel") }
  /// Block Group
  public static var chatContextBlockGroupHeader: String  { return L10n.tr("Localizable", "Chat.Context.BlockGroup.Header") }
  /// Do you want to block messages from %@
  public static func chatContextBlockGroupInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Context.BlockGroup.Info", p1)
  }
  /// Block
  public static var chatContextBlockGroupOK: String  { return L10n.tr("Localizable", "Chat.Context.BlockGroup.OK") }
  /// Report Spam
  public static var chatContextBlockGroupThird: String  { return L10n.tr("Localizable", "Chat.Context.BlockGroup.Third") }
  /// Cancel
  public static var chatContextBlockUserCancel: String  { return L10n.tr("Localizable", "Chat.Context.BlockUser.Cancel") }
  /// Block User
  public static var chatContextBlockUserHeader: String  { return L10n.tr("Localizable", "Chat.Context.BlockUser.Header") }
  /// Do you want to block messages from %@
  public static func chatContextBlockUserInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Context.BlockUser.Info", p1)
  }
  /// Block
  public static var chatContextBlockUserOK: String  { return L10n.tr("Localizable", "Chat.Context.BlockUser.OK") }
  /// Report Spam
  public static var chatContextBlockUserThird: String  { return L10n.tr("Localizable", "Chat.Context.BlockUser.Third") }
  /// Scheduled Messages
  public static var chatContextClearScheduledConfirmHeader: String  { return L10n.tr("Localizable", "Chat.Context.ClearScheduled.Confirm.Header") }
  /// Are you sure you want to delete all scheduled messages?
  public static var chatContextClearScheduledConfirmInfo: String  { return L10n.tr("Localizable", "Chat.Context.ClearScheduled.Confirm.Info") }
  /// Clear All
  public static var chatContextClearScheduledConfirmOK: String  { return L10n.tr("Localizable", "Chat.Context.ClearScheduled.Confirm.OK") }
  /// More...
  public static var chatContextForwardMore: String  { return L10n.tr("Localizable", "Chat.Context.Forward.More") }
  /// Set As Quick
  public static var chatContextReactionQuick: String  { return L10n.tr("Localizable", "Chat.Context.Reaction.Quick") }
  /// Reschedule
  public static var chatContextScheduledReschedule: String  { return L10n.tr("Localizable", "Chat.Context.Scheduled.Reschedule") }
  /// Send Now
  public static var chatContextScheduledSendNow: String  { return L10n.tr("Localizable", "Chat.Context.Scheduled.SendNow") }
  /// Auto-Delete in %@
  public static func chatContextMenuAutoDelete(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.ContextMenu.AutoDelete", p1)
  }
  /// Copy Link to Proxy
  public static var chatCopyProxyConfiguration: String  { return L10n.tr("Localizable", "Chat.Copy.ProxyConfiguration") }
  /// Scheduled for %@
  public static func chatDateScheduledFor(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Date.ScheduledFor", p1)
  }
  /// Scheduled for today
  public static var chatDateScheduledForToday: String  { return L10n.tr("Localizable", "Chat.Date.ScheduledForToday") }
  /// Scheduled until online
  public static var chatDateScheduledUntilOnline: String  { return L10n.tr("Localizable", "Chat.Date.ScheduledUntilOnline") }
  /// Sorry, this post has been removed from the discussion group.
  public static var chatDiscussionMessageDeleted: String  { return L10n.tr("Localizable", "Chat.Discussion.MessageDeleted") }
  /// as archive
  public static var chatDropFolderDesc: String  { return L10n.tr("Localizable", "Chat.DropFolder.Desc") }
  /// Drop the folder here to send
  public static var chatDropFolderTitle: String  { return L10n.tr("Localizable", "Chat.DropFolder.Title") }
  /// Sorry, you can't attach new media while editing a message.
  public static var chatEditAttachError: String  { return L10n.tr("Localizable", "Chat.Edit.Attach.Error") }
  /// Are you sure you want to discard all changes?
  public static var chatEditCancelText: String  { return L10n.tr("Localizable", "Chat.Edit.Cancel.Text") }
  /// Click to edit Media
  public static var chatEditMessageMedia: String  { return L10n.tr("Localizable", "Chat.EditMessage.Media") }
  /// Send
  public static var chatEmojiSend: String  { return L10n.tr("Localizable", "Chat.Emoji.Send") }
  /// Send a dart emoji to try your luck.
  public static var chatEmojiDartResultNew: String  { return L10n.tr("Localizable", "Chat.Emoji.Dart.ResultNew") }
  /// Send a %@ emoji to try your luck.
  public static func chatEmojiDefResultNew(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Emoji.Def.ResultNew", p1)
  }
  /// Send a dice emoji to roll a die.
  public static var chatEmojiDiceResultNew: String  { return L10n.tr("Localizable", "Chat.Emoji.Dice.ResultNew") }
  /// No comments here yet
  public static var chatEmptyComments: String  { return L10n.tr("Localizable", "Chat.Empty.Comments") }
  /// Link Preview
  public static var chatEmptyLinkPreview: String  { return L10n.tr("Localizable", "Chat.Empty.LinkPreview") }
  /// No replies here yet
  public static var chatEmptyReplies: String  { return L10n.tr("Localizable", "Chat.Empty.Replies") }
  /// Previewing this file can potentially expose your IP address to its sender.
  public static var chatFileQuickLookSvg: String  { return L10n.tr("Localizable", "Chat.File.QuickLook.Svg") }
  /// Only admins can send messages in this group.
  public static var chatGigagroupHelp: String  { return L10n.tr("Localizable", "Chat.Gigagroup.Help") }
  /// Sorry, this group is not accessible.
  public static var chatGroupUnaccessible: String  { return L10n.tr("Localizable", "Chat.Group.Unaccessible") }
  /// JOIN
  public static var chatGroupCallJoin: String  { return L10n.tr("Localizable", "Chat.GroupCall.Join") }
  /// %d
  public static func chatGroupCallMembersCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_countable", p1)
  }
  /// %d participants
  public static func chatGroupCallMembersFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_few", p1)
  }
  /// %d participants
  public static func chatGroupCallMembersMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_many", p1)
  }
  /// %d participant
  public static func chatGroupCallMembersOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_one", p1)
  }
  /// %d participants
  public static func chatGroupCallMembersOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_other", p1)
  }
  /// %d participants
  public static func chatGroupCallMembersTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Members_two", p1)
  }
  /// Click to join
  public static var chatGroupCallMembersZero: String  { return L10n.tr("Localizable", "Chat.GroupCall.Members_zero") }
  /// %d
  public static func chatGroupCallSpeakersCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_countable", p1)
  }
  /// %d participants speaking
  public static func chatGroupCallSpeakersFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_few", p1)
  }
  /// %d participants speaking
  public static func chatGroupCallSpeakersMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_many", p1)
  }
  /// %d participant speaking
  public static func chatGroupCallSpeakersOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_one", p1)
  }
  /// %d participants speaking
  public static func chatGroupCallSpeakersOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_other", p1)
  }
  /// %d participants speaking
  public static func chatGroupCallSpeakersTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Speakers_two", p1)
  }
  /// no one speaking
  public static var chatGroupCallSpeakersZero: String  { return L10n.tr("Localizable", "Chat.GroupCall.Speakers_zero") }
  /// Voice Chat
  public static var chatGroupCallTitle: String  { return L10n.tr("Localizable", "Chat.GroupCall.Title") }
  /// Live Stream
  public static var chatGroupCallLiveTitle: String  { return L10n.tr("Localizable", "Chat.GroupCall.Live.Title") }
  /// Starts %@
  public static func chatGroupCallScheduledStatus(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.GroupCall.Scheduled.Status", p1)
  }
  /// Scheduled Voice Chat
  public static var chatGroupCallScheduledTitle: String  { return L10n.tr("Localizable", "Chat.GroupCall.Scheduled.Title") }
  /// Pinned message
  public static var chatHeaderPinnedMessage: String  { return L10n.tr("Localizable", "Chat.Header.PinnedMessage") }
  /// Pinned message #%d
  public static func chatHeaderPinnedMessageNumer(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.PinnedMessage_Numer", p1)
  }
  /// Previous message
  public static var chatHeaderPinnedPrevious: String  { return L10n.tr("Localizable", "Chat.Header.PinnedPrevious") }
  /// Report Spam
  public static var chatHeaderReportSpam: String  { return L10n.tr("Localizable", "Chat.Header.ReportSpam") }
  /// %d
  public static func chatHeaderRequestToJoinCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_countable", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_few", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_many", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_one", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_other", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_two", p1)
  }
  /// %d Requested to Join
  public static func chatHeaderRequestToJoinZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Header.RequestToJoin_zero", p1)
  }
  /// Starts in %@
  public static func chatHeaderVoiceChatStartsIn(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Header.VoiceChat.StartsIn", p1)
  }
  /// Loading...
  public static var chatInlineRequestLoading: String  { return L10n.tr("Localizable", "Chat.InlineRequest.Loading") }
  /// Close
  public static var chatInputClose: String  { return L10n.tr("Localizable", "Chat.Input.Close") }
  /// Delete and exit
  public static var chatInputDelete: String  { return L10n.tr("Localizable", "Chat.Input.Delete") }
  /// Discuss
  public static var chatInputDiscuss: String  { return L10n.tr("Localizable", "Chat.Input.Discuss") }
  /// Join
  public static var chatInputJoin: String  { return L10n.tr("Localizable", "Chat.Input.Join") }
  /// Mute
  public static var chatInputMute: String  { return L10n.tr("Localizable", "Chat.Input.Mute") }
  /// Restart
  public static var chatInputRestart: String  { return L10n.tr("Localizable", "Chat.Input.Restart") }
  /// Return to the group
  public static var chatInputReturn: String  { return L10n.tr("Localizable", "Chat.Input.Return") }
  /// Start
  public static var chatInputStartBot: String  { return L10n.tr("Localizable", "Chat.Input.StartBot") }
  /// Unblock
  public static var chatInputUnblock: String  { return L10n.tr("Localizable", "Chat.Input.Unblock") }
  /// Unmute
  public static var chatInputUnmute: String  { return L10n.tr("Localizable", "Chat.Input.Unmute") }
  /// Edit Message
  public static var chatInputAccessoryEditMessage: String  { return L10n.tr("Localizable", "Chat.Input.Accessory.EditMessage") }
  /// Messages in this chat are automatically deleted 1 day after they have been sent.
  public static var chatInputAutoDelete1Day: String  { return L10n.tr("Localizable", "Chat.Input.AutoDelete.1Day") }
  /// Messages in this chat are automatically deleted 1 week after they have been sent.
  public static var chatInputAutoDelete7Days: String  { return L10n.tr("Localizable", "Chat.Input.AutoDelete.7Days") }
  /// %d
  public static func chatInputErrorMessageTooLongCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_countable", p1)
  }
  /// Your message is too long to be saved. Please remove %d characters.
  public static func chatInputErrorMessageTooLongFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_few", p1)
  }
  /// Your message is too long to be saved. Please remove %d characters.
  public static func chatInputErrorMessageTooLongMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_many", p1)
  }
  /// Your message is too long to be saved. Please remove %d character.
  public static func chatInputErrorMessageTooLongOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_one", p1)
  }
  /// Your message is too long to be saved. Please remove %d characters.
  public static func chatInputErrorMessageTooLongOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_other", p1)
  }
  /// Your message is too long to be saved. Please remove %d characters.
  public static func chatInputErrorMessageTooLongTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_two", p1)
  }
  /// Your message is too long to be saved. Please remove %d characters.
  public static func chatInputErrorMessageTooLongZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Input.Error.MessageTooLong_zero", p1)
  }
  /// You (sender's names hidden)
  public static var chatInputForwardHidden: String  { return L10n.tr("Localizable", "Chat.Input.Forward.Hidden") }
  /// Waiting for the %@ to get online...
  public static func chatInputSecretChatWaitingToUserOnline(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Input.SecretChat.WaitingToUserOnline", p1)
  }
  /// Contact
  public static var chatListContact: String  { return L10n.tr("Localizable", "Chat.List.Contact") }
  /// GIF
  public static var chatListGIF: String  { return L10n.tr("Localizable", "Chat.List.GIF") }
  /// Video message
  public static var chatListInstantVideo: String  { return L10n.tr("Localizable", "Chat.List.InstantVideo") }
  /// Location
  public static var chatListMap: String  { return L10n.tr("Localizable", "Chat.List.Map") }
  /// Photo
  public static var chatListPhoto: String  { return L10n.tr("Localizable", "Chat.List.Photo") }
  /// %d
  public static func chatListPhoto1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_countable", p1)
  }
  /// %d Photos
  public static func chatListPhoto1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_few", p1)
  }
  /// %d Photos
  public static func chatListPhoto1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_many", p1)
  }
  /// Photo
  public static var chatListPhoto1One: String  { return L10n.tr("Localizable", "Chat.List.Photo1_one") }
  /// %d Photos
  public static func chatListPhoto1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_other", p1)
  }
  /// %d Photos
  public static func chatListPhoto1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_two", p1)
  }
  /// %d Photos
  public static func chatListPhoto1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Photo1_zero", p1)
  }
  /// %@ Sticker
  public static func chatListSticker(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.List.Sticker", p1)
  }
  /// Video
  public static var chatListVideo: String  { return L10n.tr("Localizable", "Chat.List.Video") }
  /// %d
  public static func chatListVideo1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_countable", p1)
  }
  /// %d Videos
  public static func chatListVideo1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_few", p1)
  }
  /// %d Videos
  public static func chatListVideo1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_many", p1)
  }
  /// Video
  public static var chatListVideo1One: String  { return L10n.tr("Localizable", "Chat.List.Video1_one") }
  /// %d Videos
  public static func chatListVideo1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_other", p1)
  }
  /// %d Videos
  public static func chatListVideo1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_two", p1)
  }
  /// %d Videos
  public static func chatListVideo1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.List.Video1_zero", p1)
  }
  /// Voice message
  public static var chatListVoice: String  { return L10n.tr("Localizable", "Chat.List.Voice") }
  /// Payment: %@
  public static func chatListServicePaymentSent(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.List.Service.PaymentSent", p1)
  }
  /// %d
  public static func chatLiveLocationUpdatedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_countable", p1)
  }
  /// Updated %d minutes ago
  public static func chatLiveLocationUpdatedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_few", p1)
  }
  /// Updated %d minutes ago
  public static func chatLiveLocationUpdatedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_many", p1)
  }
  /// Updated %d minute ago
  public static func chatLiveLocationUpdatedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_one", p1)
  }
  /// Updated %d minutes ago
  public static func chatLiveLocationUpdatedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_other", p1)
  }
  /// Updated %d minutes ago
  public static func chatLiveLocationUpdatedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_two", p1)
  }
  /// Updated %d minutes ago
  public static func chatLiveLocationUpdatedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.LiveLocation.Updated_zero", p1)
  }
  /// Updated just now
  public static var chatLiveLocationUpdatedNow: String  { return L10n.tr("Localizable", "Chat.LiveLocation.UpdatedNow") }
  /// Delete for everyone
  public static var chatMessageDeleteForEveryone: String  { return L10n.tr("Localizable", "Chat.Message.DeleteForEveryone") }
  /// Delete for me
  public static var chatMessageDeleteForMe: String  { return L10n.tr("Localizable", "Chat.Message.DeleteForMe") }
  /// Delete for me and %@
  public static func chatMessageDeleteForMeAndPerson(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Message.DeleteForMeAndPerson", p1)
  }
  /// edited
  public static var chatMessageEdited: String  { return L10n.tr("Localizable", "Chat.Message.edited") }
  /// %@ imported
  public static func chatMessageImported(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Message.Imported", p1)
  }
  /// imported
  public static var chatMessageImportedShort: String  { return L10n.tr("Localizable", "Chat.Message.ImportedShort") }
  /// sponsored
  public static var chatMessageSponsored: String  { return L10n.tr("Localizable", "Chat.Message.Sponsored") }
  /// %d
  public static func chatMessageUnsendMessagesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.UnsendMessages_countable", p1)
  }
  /// Unsend my messages
  public static var chatMessageUnsendMessagesFew: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_few") }
  /// Unsend my messages
  public static var chatMessageUnsendMessagesMany: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_many") }
  /// Unsend my message
  public static var chatMessageUnsendMessagesOne: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_one") }
  /// Unsend my messages
  public static var chatMessageUnsendMessagesOther: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_other") }
  /// Unsend my messages
  public static var chatMessageUnsendMessagesTwo: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_two") }
  /// Unsend my messages
  public static var chatMessageUnsendMessagesZero: String  { return L10n.tr("Localizable", "Chat.Message.UnsendMessages_zero") }
  /// This message is not supported by your version of Telegram. Please update to the latest version from the AppStore or install it from https://macos.telegram.org
  public static var chatMessageUnsupported: String  { return L10n.tr("Localizable", "Chat.Message.Unsupported") }
  /// This message is not supported by your version Telegram. Please update to the latest version.
  public static var chatMessageUnsupportedNew: String  { return L10n.tr("Localizable", "Chat.Message.UnsupportedNew") }
  /// via
  public static var chatMessageVia: String  { return L10n.tr("Localizable", "Chat.Message.Via") }
  /// VIEW BOT
  public static var chatMessageViewBot: String  { return L10n.tr("Localizable", "Chat.Message.ViewBot") }
  /// VIEW CHANNEL
  public static var chatMessageViewChannel: String  { return L10n.tr("Localizable", "Chat.Message.ViewChannel") }
  /// VIEW GROUP
  public static var chatMessageViewGroup: String  { return L10n.tr("Localizable", "Chat.Message.ViewGroup") }
  /// Read More
  public static var chatMessageAdReadMore: String  { return L10n.tr("Localizable", "Chat.Message.Ad.ReadMore") }
  /// Unlike other apps, Telegram never uses your private data to target ads. Sponsored messages on Telegram are based solely on the topic of the public channels in which they are shown. This means that no user data is mined or analyzed to display ads, and every user viewing a channel on Telegram sees the same sponsored messages.\n\nUnlike other apps, Telegram doesn't track whether you tapped on a sponsored message and doesn't profile you based on your activity. We also prevent external links in sponsored messages to ensure that third parties can’t spy on our users. We believe that everyone has the right to privacy, and technological platforms should respect that.\n\nTelegram offers a free and unlimited service to hundreds of millions of users, which involves significant server and traffic costs. In order to remain independent and stay true to its values, Telegram developed a paid tool to promote messages with user privacy in mind. We welcome responsible advertisers at:\n\n%@\n\nSponsored Messages are currently in test mode. Once they are fully launched and allow Telegram to cover its basic costs, we will start sharing ad revenue with the owners of public channels in which sponsored messages are displayed.\n\nOnline ads should no longer be synonymous with abuse of user privacy. Let us redefine how a tech company should operate – together.
  public static func chatMessageAdText(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Message.Ad.Text", p1)
  }
  /// This message was imported from another app. We can't guarantee it's real.
  public static var chatMessageImportedText: String  { return L10n.tr("Localizable", "Chat.Message.Imported.Text") }
  /// JOIN AS LISTENER
  public static var chatMessageJoinVoiceChatAsListener: String  { return L10n.tr("Localizable", "Chat.Message.JoinVoiceChat.AsListener") }
  /// JOIN AS SPEAKER
  public static var chatMessageJoinVoiceChatAsSpeaker: String  { return L10n.tr("Localizable", "Chat.Message.JoinVoiceChat.AsSpeaker") }
  /// MTProxy Configuration
  public static var chatMessageMTProxyConfig: String  { return L10n.tr("Localizable", "Chat.Message.MTProxy.Config") }
  /// Nobody Listened
  public static var chatMessageReadStatsEmptyListens: String  { return L10n.tr("Localizable", "Chat.Message.ReadStats.EmptyListens") }
  /// Nobody Viewed
  public static var chatMessageReadStatsEmptyViews: String  { return L10n.tr("Localizable", "Chat.Message.ReadStats.EmptyViews") }
  /// Nobody Viewed
  public static var chatMessageReadStatsEmptyWatches: String  { return L10n.tr("Localizable", "Chat.Message.ReadStats.EmptyWatches") }
  /// %d
  public static func chatMessageReadStatsListenedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_countable", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_few", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_many", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_one", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_other", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_two", p1)
  }
  /// %d Listened
  public static func chatMessageReadStatsListenedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Listened_zero", p1)
  }
  /// %d
  public static func chatMessageReadStatsSeenCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_countable", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_few", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_many", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_one", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_other", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_two", p1)
  }
  /// %d Seen
  public static func chatMessageReadStatsSeenZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Seen_zero", p1)
  }
  /// %d
  public static func chatMessageReadStatsWatchedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_countable", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_few", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_many", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_one", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_other", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_two", p1)
  }
  /// %d Viewed
  public static func chatMessageReadStatsWatchedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Message.ReadStats.Watched_zero", p1)
  }
  /// SOCKS5 Configuration
  public static var chatMessageSocks5Config: String  { return L10n.tr("Localizable", "Chat.Message.Socks5.Config") }
  /// https://telegram.org
  public static var chatMessageSponsoredLink: String  { return L10n.tr("Localizable", "Chat.Message.Sponsored.Link") }
  /// What are sponsored messages?
  public static var chatMessageSponsoredWhat: String  { return L10n.tr("Localizable", "Chat.Message.Sponsored.What") }
  /// SHOW MESSAGE
  public static var chatMessageActionShowMessage: String  { return L10n.tr("Localizable", "Chat.MessageAction.ShowMessage") }
  /// Messsage doesn't exist
  public static var chatOpenMessageNotExist: String  { return L10n.tr("Localizable", "Chat.Open.MessageNotExist") }
  /// Don't Show Pinned Messages
  public static var chatPinnedDontShow: String  { return L10n.tr("Localizable", "Chat.Pinned.DontShow") }
  /// %d
  public static func chatPinnedUnpinAllCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_countable", p1)
  }
  /// Unpin All %d Messages
  public static func chatPinnedUnpinAllFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_few", p1)
  }
  /// Unpin All %d Messages
  public static func chatPinnedUnpinAllMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_many", p1)
  }
  /// Unpin %d Message
  public static func chatPinnedUnpinAllOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_one", p1)
  }
  /// Unpin All %d Messages
  public static func chatPinnedUnpinAllOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_other", p1)
  }
  /// Unpin All %d Messages
  public static func chatPinnedUnpinAllTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_two", p1)
  }
  /// Unpin All %d Messages
  public static func chatPinnedUnpinAllZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Pinned.UnpinAll_zero", p1)
  }
  /// %@%%
  public static func chatPollResult(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Result", p1)
  }
  /// Stop Poll
  public static var chatPollStop: String  { return L10n.tr("Localizable", "Chat.Poll.Stop") }
  /// Vote
  public static var chatPollSubmitVote: String  { return L10n.tr("Localizable", "Chat.Poll.SubmitVote") }
  /// %d
  public static func chatPollTotalVotes1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_countable", p1)
  }
  /// %d votes
  public static func chatPollTotalVotes1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_few", p1)
  }
  /// %d votes
  public static func chatPollTotalVotes1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_many", p1)
  }
  /// %d vote
  public static func chatPollTotalVotes1One(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_one", p1)
  }
  /// %d votes
  public static func chatPollTotalVotes1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_other", p1)
  }
  /// %d votes
  public static func chatPollTotalVotes1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_two", p1)
  }
  /// %d vote
  public static func chatPollTotalVotes1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.TotalVotes1_zero", p1)
  }
  /// No votes yet
  public static var chatPollTotalVotesEmpty: String  { return L10n.tr("Localizable", "Chat.Poll.TotalVotesEmpty") }
  /// No votes
  public static var chatPollTotalVotesResultEmpty: String  { return L10n.tr("Localizable", "Chat.Poll.TotalVotesResultEmpty") }
  /// Retract Vote
  public static var chatPollUnvote: String  { return L10n.tr("Localizable", "Chat.Poll.Unvote") }
  /// View Results
  public static var chatPollViewResults: String  { return L10n.tr("Localizable", "Chat.Poll.ViewResults") }
  /// Stop Poll?
  public static var chatPollStopConfirmHeader: String  { return L10n.tr("Localizable", "Chat.Poll.Stop.Confirm.Header") }
  /// If you stop this poll now, nobody will be able to vote in it anymore. This action cannot be undone.
  public static var chatPollStopConfirmText: String  { return L10n.tr("Localizable", "Chat.Poll.Stop.Confirm.Text") }
  /// no votes
  public static var chatPollTooltipNoVotes: String  { return L10n.tr("Localizable", "Chat.Poll.Tooltip.NoVotes") }
  /// %d
  public static func chatPollTooltipVotesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_countable", p1)
  }
  /// %d votes
  public static func chatPollTooltipVotesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_few", p1)
  }
  /// %d votes
  public static func chatPollTooltipVotesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_many", p1)
  }
  /// %d vote
  public static func chatPollTooltipVotesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_one", p1)
  }
  /// %d votes
  public static func chatPollTooltipVotesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_other", p1)
  }
  /// %d votes
  public static func chatPollTooltipVotesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_two", p1)
  }
  /// %d votes
  public static func chatPollTooltipVotesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Poll.Tooltip.Votes_zero", p1)
  }
  /// Anonymous Poll
  public static var chatPollTypeAnonymous: String  { return L10n.tr("Localizable", "Chat.Poll.Type.Anonymous") }
  /// Anonymous Quiz
  public static var chatPollTypeAnonymousQuiz: String  { return L10n.tr("Localizable", "Chat.Poll.Type.AnonymousQuiz") }
  /// Final Results
  public static var chatPollTypeClosed: String  { return L10n.tr("Localizable", "Chat.Poll.Type.Closed") }
  /// Poll
  public static var chatPollTypePublic: String  { return L10n.tr("Localizable", "Chat.Poll.Type.Public") }
  /// Quiz
  public static var chatPollTypeQuiz: String  { return L10n.tr("Localizable", "Chat.Poll.Type.Quiz") }
  /// Proxy Sponsor
  public static var chatProxySponsoredAlertHeader: String  { return L10n.tr("Localizable", "Chat.ProxySponsored.AlertHeader") }
  /// Settings
  public static var chatProxySponsoredAlertSettings: String  { return L10n.tr("Localizable", "Chat.ProxySponsored.AlertSettings") }
  /// This channel is shown by your proxy server. To remove this channel from your chats list, disable the proxy in Telegram Settings.
  public static var chatProxySponsoredAlertText: String  { return L10n.tr("Localizable", "Chat.ProxySponsored.AlertText") }
  /// This channel is shown by your proxy server
  public static var chatProxySponsoredCapDesc: String  { return L10n.tr("Localizable", "Chat.ProxySponsored.CapDesc") }
  /// Proxy Sponsor
  public static var chatProxySponsoredCapTitle: String  { return L10n.tr("Localizable", "Chat.ProxySponsored.CapTitle") }
  /// Stop Quiz
  public static var chatQuizStop: String  { return L10n.tr("Localizable", "Chat.Quiz.Stop") }
  /// Quiz
  public static var chatQuizTextType: String  { return L10n.tr("Localizable", "Chat.Quiz.TextType") }
  /// %d
  public static func chatQuizTotalVotesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_countable", p1)
  }
  /// %d answers
  public static func chatQuizTotalVotesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_few", p1)
  }
  /// %d answers
  public static func chatQuizTotalVotesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_many", p1)
  }
  /// %d answer
  public static func chatQuizTotalVotesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_one", p1)
  }
  /// %d answers
  public static func chatQuizTotalVotesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_other", p1)
  }
  /// %d answers
  public static func chatQuizTotalVotesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_two", p1)
  }
  /// %d answer
  public static func chatQuizTotalVotesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.TotalVotes_zero", p1)
  }
  /// No answers yet
  public static var chatQuizTotalVotesEmpty: String  { return L10n.tr("Localizable", "Chat.Quiz.TotalVotesEmpty") }
  /// No answers
  public static var chatQuizTotalVotesResultEmpty: String  { return L10n.tr("Localizable", "Chat.Quiz.TotalVotesResultEmpty") }
  /// Stop Quiz?
  public static var chatQuizStopConfirmHeader: String  { return L10n.tr("Localizable", "Chat.Quiz.Stop.Confirm.Header") }
  /// If you stop this quiz now, nobody will be able to answer in it anymore. This action cannot be undone.
  public static var chatQuizStopConfirmText: String  { return L10n.tr("Localizable", "Chat.Quiz.Stop.Confirm.Text") }
  /// no answers
  public static var chatQuizTooltipNoVotes: String  { return L10n.tr("Localizable", "Chat.Quiz.Tooltip.NoVotes") }
  /// %d
  public static func chatQuizTooltipVotesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_countable", p1)
  }
  /// %d answers
  public static func chatQuizTooltipVotesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_few", p1)
  }
  /// %d answers
  public static func chatQuizTooltipVotesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_many", p1)
  }
  /// %d answer
  public static func chatQuizTooltipVotesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_one", p1)
  }
  /// %d answers
  public static func chatQuizTooltipVotesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_other", p1)
  }
  /// %d answers
  public static func chatQuizTooltipVotesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_two", p1)
  }
  /// %d answers
  public static func chatQuizTooltipVotesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Quiz.Tooltip.Votes_zero", p1)
  }
  /// Are you sure you want to cancel recording?
  public static var chatRecordingCancel: String  { return L10n.tr("Localizable", "Chat.Recording.Cancel") }
  /// This chat helps you keep track of replies to your comments in Channels.
  public static var chatRepliesDesc: String  { return L10n.tr("Localizable", "Chat.Replies.Desc") }
  /// Reminder
  public static var chatRightContextReminder: String  { return L10n.tr("Localizable", "Chat.Right.Context.Reminder") }
  /// Scheduled Messages
  public static var chatRightContextScheduledMessages: String  { return L10n.tr("Localizable", "Chat.Right.Context.ScheduledMessages") }
  /// The buttons will become active as soon as the message is sent.
  public static var chatScheduledInlineButtonError: String  { return L10n.tr("Localizable", "Chat.Scheduled.InlineButton.Error") }
  /// • Use end-to-end encryption
  public static var chatSecretChat1Feature: String  { return L10n.tr("Localizable", "Chat.SecretChat.1Feature") }
  /// • Leave no trace on our servers
  public static var chatSecretChat2Feature: String  { return L10n.tr("Localizable", "Chat.SecretChat.2Feature") }
  /// • Have a self-destruct timer
  public static var chatSecretChat3Feature: String  { return L10n.tr("Localizable", "Chat.SecretChat.3Feature") }
  /// • Do not allow forwarding
  public static var chatSecretChat4Feature: String  { return L10n.tr("Localizable", "Chat.SecretChat.4Feature") }
  /// Secret chats:
  public static var chatSecretChatEmptyHeader: String  { return L10n.tr("Localizable", "Chat.SecretChat.EmptyHeader") }
  /// Secret Chat
  public static var chatSecretChatPreviewHeader: String  { return L10n.tr("Localizable", "Chat.SecretChat.Preview.Header") }
  /// NO
  public static var chatSecretChatPreviewNO: String  { return L10n.tr("Localizable", "Chat.SecretChat.Preview.NO") }
  /// YES
  public static var chatSecretChatPreviewOK: String  { return L10n.tr("Localizable", "Chat.SecretChat.Preview.OK") }
  /// Would you like to enable extended link previews in Secret Chat? Note that link previews are generated on Telegram Servers.
  public static var chatSecretChatPreviewText: String  { return L10n.tr("Localizable", "Chat.SecretChat.Preview.Text") }
  /// Schedule a Message
  public static var chatSendScheduledMessage: String  { return L10n.tr("Localizable", "Chat.Send.ScheduledMessage") }
  /// Set a Reminder
  public static var chatSendSetReminder: String  { return L10n.tr("Localizable", "Chat.Send.SetReminder") }
  /// Send Without Sound
  public static var chatSendWithoutSound: String  { return L10n.tr("Localizable", "Chat.Send.WithoutSound") }
  /// %d
  public static func chatSendAsChannelCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_countable", p1)
  }
  /// %d subscribers
  public static func chatSendAsChannelFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_few", p1)
  }
  /// %d subscribers
  public static func chatSendAsChannelMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_many", p1)
  }
  /// %d subscriber
  public static func chatSendAsChannelOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_one", p1)
  }
  /// %d subscribers
  public static func chatSendAsChannelOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_other", p1)
  }
  /// %d subscribers
  public static func chatSendAsChannelTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_two", p1)
  }
  /// %d subscribers
  public static func chatSendAsChannelZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Channel_zero", p1)
  }
  /// %d
  public static func chatSendAsGroupCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_countable", p1)
  }
  /// %d members
  public static func chatSendAsGroupFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_few", p1)
  }
  /// %d members
  public static func chatSendAsGroupMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_many", p1)
  }
  /// %d member
  public static func chatSendAsGroupOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_one", p1)
  }
  /// %d members
  public static func chatSendAsGroupOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_other", p1)
  }
  /// %d members
  public static func chatSendAsGroupTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_two", p1)
  }
  /// %d members
  public static func chatSendAsGroupZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.SendAs.Group_zero", p1)
  }
  /// SEND MESSAGE AS...
  public static var chatSendAsHeader: String  { return L10n.tr("Localizable", "Chat.SendAs.Header") }
  /// personal account
  public static var chatSendAsPersonalAccount: String  { return L10n.tr("Localizable", "Chat.SendAs.PersonalAccount") }
  /// Sorry, you can only send only 100 scheduled messages.
  public static var chatSendMessageErrorTooMuchScheduled: String  { return L10n.tr("Localizable", "Chat.SendMessageError.TooMuchScheduled") }
  /// You allowed this bot to message you when you logged in on %@
  public static func chatServiceBotPermissionAllowed(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.BotPermissionAllowed", p1)
  }
  /// %1$@ disabled the chat theme
  public static func chatServiceDisabledTheme(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.DisabledTheme", p1)
  }
  /// You have successfully transferred **%1$@** to **%2$@** for **%3$@**
  public static func chatServicePaymentSent1(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.PaymentSent1", p1, p2, p3)
  }
  /// %@ joined Telegram
  public static func chatServicePeerJoinedTelegram(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.PeerJoinedTelegram", p1)
  }
  /// pinned message
  public static var chatServicePinnedMessage: String  { return L10n.tr("Localizable", "Chat.Service.PinnedMessage") }
  /// Search messages by %@
  public static func chatServiceSearchAllMessages(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.SearchAllMessages", p1)
  }
  /// %1$@ changed chat theme to %2$@
  public static func chatServiceUpdateTheme(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.UpdateTheme", p1, p2)
  }
  /// %1$@ finished voice chat (%2$@)
  public static func chatServiceVoiceChatFinished(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatFinished", p1, p2)
  }
  /// You finished voice chat (%@)
  public static func chatServiceVoiceChatFinishedYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatFinishedYou", p1)
  }
  /// %1$@ invited %2$@ to the [voice chat](open)
  public static func chatServiceVoiceChatInvitation(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatInvitation", p1, p2)
  }
  /// You invited %1$@ to the [voice chat](open)
  public static func chatServiceVoiceChatInvitationByYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatInvitationByYou", p1)
  }
  /// %1$@ invited you to the [voice chat](open)
  public static func chatServiceVoiceChatInvitationForYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatInvitationForYou", p1)
  }
  /// %1$@ scheduled a [voice chat](open) for %2$@
  public static func chatServiceVoiceChatScheduled(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatScheduled", p1, p2)
  }
  /// You scheduled a [voice chat](open) for %1$@
  public static func chatServiceVoiceChatScheduledYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatScheduledYou", p1)
  }
  /// %1$@ started a [voice chat](open)
  public static func chatServiceVoiceChatStarted(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatStarted", p1)
  }
  /// You started a [voice chat](open)
  public static var chatServiceVoiceChatStartedYou: String  { return L10n.tr("Localizable", "Chat.Service.VoiceChatStartedYou") }
  /// You
  public static var chatServiceYou: String  { return L10n.tr("Localizable", "Chat.Service.You") }
  /// Cancelled
  public static var chatServiceCallCancelled: String  { return L10n.tr("Localizable", "Chat.Service.Call.Cancelled") }
  /// Missed
  public static var chatServiceCallMissed: String  { return L10n.tr("Localizable", "Chat.Service.Call.Missed") }
  /// a group admin disabled the auto-delete timer
  public static var chatServiceChannelDisabledTimer: String  { return L10n.tr("Localizable", "Chat.Service.Channel.DisabledTimer") }
  /// channel photo removed
  public static var chatServiceChannelRemovedPhoto: String  { return L10n.tr("Localizable", "Chat.Service.Channel.RemovedPhoto") }
  /// a group admin set the messages to automatically delete after %@
  public static func chatServiceChannelSetTimer(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Channel.SetTimer", p1)
  }
  /// channel photo updated
  public static var chatServiceChannelUpdatedPhoto: String  { return L10n.tr("Localizable", "Chat.Service.Channel.UpdatedPhoto") }
  /// channel renamed to "%@"
  public static func chatServiceChannelUpdatedTitle(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Channel.UpdatedTitle", p1)
  }
  /// channel video updated
  public static var chatServiceChannelUpdatedVideo: String  { return L10n.tr("Localizable", "Chat.Service.Channel.UpdatedVideo") }
  /// You disabled the chat theme
  public static var chatServiceDisabledThemeYou: String  { return L10n.tr("Localizable", "Chat.Service.DisabledTheme.You") }
  /// %1$@ invited %2$@
  public static func chatServiceGroupAddedMembers1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.AddedMembers1", p1, p2)
  }
  /// %@ joined the group
  public static func chatServiceGroupAddedSelf(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.AddedSelf", p1)
  }
  /// %1$@ created the group "%2$@"
  public static func chatServiceGroupCreated1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.Created1", p1, p2)
  }
  /// a group admin disabled the auto-delete timer
  public static var chatServiceGroupDisabledTimer: String  { return L10n.tr("Localizable", "Chat.Service.Group.DisabledTimer") }
  /// %@ joined group via invite link
  public static func chatServiceGroupJoinedByLink(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.JoinedByLink", p1)
  }
  /// This group was upgraded to a supergroup
  public static var chatServiceGroupMigratedToSupergroup: String  { return L10n.tr("Localizable", "Chat.Service.Group.MigratedToSupergroup") }
  /// %1$@ removed %2$@
  public static func chatServiceGroupRemovedMembers1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.RemovedMembers1", p1, p2)
  }
  /// %@ removed group photo
  public static func chatServiceGroupRemovedPhoto(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.RemovedPhoto", p1)
  }
  /// %@ left the group
  public static func chatServiceGroupRemovedSelf(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.RemovedSelf", p1)
  }
  /// a group admin set the messages to automatically delete after %@
  public static func chatServiceGroupSetTimer(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.SetTimer", p1)
  }
  /// %@ took a screenshot
  public static func chatServiceGroupTookScreenshot(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.TookScreenshot", p1)
  }
  /// %@ updated group photo
  public static func chatServiceGroupUpdatedPhoto(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.UpdatedPhoto", p1)
  }
  /// %1$@ pinned "%2$@"
  public static func chatServiceGroupUpdatedPinnedMessage1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.UpdatedPinnedMessage1", p1, p2)
  }
  /// %1$@ changed the group name to "%2$@"
  public static func chatServiceGroupUpdatedTitle1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.UpdatedTitle1", p1, p2)
  }
  /// %@ updated group video
  public static func chatServiceGroupUpdatedVideo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.Group.UpdatedVideo", p1)
  }
  /// %@ disabled the auto-delete timer
  public static func chatServiceSecretChatDisabledTimer1(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.SecretChat.DisabledTimer1", p1)
  }
  /// %@ set the messages to automatically delete after %@
  public static func chatServiceSecretChatSetTimer1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.SecretChat.SetTimer1", p1, p2)
  }
  /// You disabled the auto-delete timer
  public static var chatServiceSecretChatDisabledTimerSelf1: String  { return L10n.tr("Localizable", "Chat.Service.SecretChat.DisabledTimer.Self1") }
  /// You set messages to automatically delete after %@
  public static func chatServiceSecretChatSetTimerSelf1(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.SecretChat.SetTimer.Self1", p1)
  }
  /// %@ received the following documents: %@
  public static func chatServiceSecureIdAccessGranted(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.SecureId.AccessGranted", p1, p2)
  }
  /// You changed chat theme to %@
  public static func chatServiceUpdateThemeYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.UpdateTheme.You", p1)
  }
  /// Voice chat ended (%1$@)
  public static func chatServiceVoiceChatFinishedChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatFinished.Channel", p1)
  }
  /// [Voice Chat](open) scheduled for %@
  public static func chatServiceVoiceChatScheduledChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "Chat.Service.VoiceChatScheduled.Channel", p1)
  }
  /// [Voice Chat](open) started
  public static var chatServiceVoiceChatStartedChannel: String  { return L10n.tr("Localizable", "Chat.Service.VoiceChatStarted.Channel") }
  /// %d
  public static func chatTitleCommentsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_countable", p1)
  }
  /// %d Comments
  public static func chatTitleCommentsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_few", p1)
  }
  /// %d Comments
  public static func chatTitleCommentsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_many", p1)
  }
  /// %d Comment
  public static func chatTitleCommentsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_one", p1)
  }
  /// %d Comments
  public static func chatTitleCommentsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_other", p1)
  }
  /// %d Comments
  public static func chatTitleCommentsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Comments_two", p1)
  }
  /// Comments
  public static var chatTitleCommentsZero: String  { return L10n.tr("Localizable", "Chat.Title.Comments_zero") }
  /// Discussion
  public static var chatTitleDiscussion: String  { return L10n.tr("Localizable", "Chat.Title.Discussion") }
  /// %d
  public static func chatTitlePinnedMessagesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_countable", p1)
  }
  /// %d Pinned Messages
  public static func chatTitlePinnedMessagesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_few", p1)
  }
  /// %d Pinned Messages
  public static func chatTitlePinnedMessagesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_many", p1)
  }
  /// %d Pinned Message
  public static func chatTitlePinnedMessagesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_one", p1)
  }
  /// %d Pinned Messages
  public static func chatTitlePinnedMessagesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_other", p1)
  }
  /// %d Pinned Messages
  public static func chatTitlePinnedMessagesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_two", p1)
  }
  /// %d Pinned Messages
  public static func chatTitlePinnedMessagesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.PinnedMessages_zero", p1)
  }
  /// Reminder
  public static var chatTitleReminder: String  { return L10n.tr("Localizable", "Chat.Title.Reminder") }
  /// %d
  public static func chatTitleRepliesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_countable", p1)
  }
  /// %d Replies
  public static func chatTitleRepliesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_few", p1)
  }
  /// %d Replies
  public static func chatTitleRepliesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_many", p1)
  }
  /// %d Reply
  public static func chatTitleRepliesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_one", p1)
  }
  /// %d Replies
  public static func chatTitleRepliesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_other", p1)
  }
  /// %d Replies
  public static func chatTitleRepliesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.Title.Replies_two", p1)
  }
  /// Replies
  public static var chatTitleRepliesZero: String  { return L10n.tr("Localizable", "Chat.Title.Replies_zero") }
  /// Scheduled Messages
  public static var chatTitleScheduledMessages: String  { return L10n.tr("Localizable", "Chat.Title.ScheduledMessages") }
  /// Your cloud storage
  public static var chatTitleSelf: String  { return L10n.tr("Localizable", "Chat.Title.self") }
  /// Telegram moderators will study your report. Thank You.
  public static var chatToastReportSuccess: String  { return L10n.tr("Localizable", "Chat.Toast.ReportSuccess") }
  /// The account was hidden by the user
  public static var chatTooltipHiddenForwardName: String  { return L10n.tr("Localizable", "Chat.Tooltip.HiddenForwardName") }
  /// %d
  public static func chatUndoManagerChannelDeletedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_countable", p1)
  }
  /// %d Channels Deleted
  public static func chatUndoManagerChannelDeletedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_few", p1)
  }
  /// %d Channels Deleted
  public static func chatUndoManagerChannelDeletedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_many", p1)
  }
  /// Channel Deleted
  public static var chatUndoManagerChannelDeletedOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_one") }
  /// %d Channels Deleted
  public static func chatUndoManagerChannelDeletedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_other", p1)
  }
  /// %d Channels Deleted
  public static func chatUndoManagerChannelDeletedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_two", p1)
  }
  /// %d Channels Deleted
  public static func chatUndoManagerChannelDeletedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelDeleted_zero", p1)
  }
  /// %d
  public static func chatUndoManagerChannelLeftCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_countable", p1)
  }
  /// %d Channels Left
  public static func chatUndoManagerChannelLeftFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_few", p1)
  }
  /// %d Channels Left
  public static func chatUndoManagerChannelLeftMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_many", p1)
  }
  /// Channel Left
  public static var chatUndoManagerChannelLeftOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_one") }
  /// %d Channels Left
  public static func chatUndoManagerChannelLeftOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_other", p1)
  }
  /// %d Channels Left
  public static func chatUndoManagerChannelLeftTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_two", p1)
  }
  /// %d Channels Left
  public static func chatUndoManagerChannelLeftZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChannelLeft_zero", p1)
  }
  /// %d
  public static func chatUndoManagerChatLeftCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_countable", p1)
  }
  /// %d Chats Left
  public static func chatUndoManagerChatLeftFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_few", p1)
  }
  /// %d Chats Left
  public static func chatUndoManagerChatLeftMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_many", p1)
  }
  /// Chat Left
  public static var chatUndoManagerChatLeftOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_one") }
  /// %d Chats Left
  public static func chatUndoManagerChatLeftOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_other", p1)
  }
  /// %d Chats Left
  public static func chatUndoManagerChatLeftTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_two", p1)
  }
  /// %d Chats Left
  public static func chatUndoManagerChatLeftZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatLeft_zero", p1)
  }
  /// %d
  public static func chatUndoManagerChatsArchivedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_countable", p1)
  }
  /// %d Chats Archived
  public static func chatUndoManagerChatsArchivedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_few", p1)
  }
  /// %d Chats Archived
  public static func chatUndoManagerChatsArchivedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_many", p1)
  }
  /// Chat Archived
  public static var chatUndoManagerChatsArchivedOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_one") }
  /// %d Chats Archived
  public static func chatUndoManagerChatsArchivedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_other", p1)
  }
  /// %d Chats Archived
  public static func chatUndoManagerChatsArchivedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_two", p1)
  }
  /// %d Chat Archived
  public static func chatUndoManagerChatsArchivedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsArchived_zero", p1)
  }
  /// %d
  public static func chatUndoManagerChatsDeletedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_countable", p1)
  }
  /// %d Chats Deleted
  public static func chatUndoManagerChatsDeletedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_few", p1)
  }
  /// %d Chats Deleted
  public static func chatUndoManagerChatsDeletedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_many", p1)
  }
  /// Chat Deleted
  public static var chatUndoManagerChatsDeletedOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_one") }
  /// %d Chats Deleted
  public static func chatUndoManagerChatsDeletedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_other", p1)
  }
  /// %d Chats Deleted
  public static func chatUndoManagerChatsDeletedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_two", p1)
  }
  /// %d Chat Deleted
  public static func chatUndoManagerChatsDeletedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsDeleted_zero", p1)
  }
  /// %d
  public static func chatUndoManagerChatsHistoryClearedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_countable", p1)
  }
  /// %d Chat History Cleared
  public static func chatUndoManagerChatsHistoryClearedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_few", p1)
  }
  /// %d Chat History Cleared
  public static func chatUndoManagerChatsHistoryClearedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_many", p1)
  }
  /// Chat History Cleared
  public static var chatUndoManagerChatsHistoryClearedOne: String  { return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_one") }
  /// %d Chat History Cleared
  public static func chatUndoManagerChatsHistoryClearedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_other", p1)
  }
  /// %d Chat History Cleared
  public static func chatUndoManagerChatsHistoryClearedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_two", p1)
  }
  /// %d Chat History Cleared
  public static func chatUndoManagerChatsHistoryClearedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.UndoManager.ChatsHistoryCleared_zero", p1)
  }
  /// Undo
  public static var chatUndoManagerUndo: String  { return L10n.tr("Localizable", "Chat.UndoManager.Undo") }
  /// UPDATE
  public static var chatUnsupportedUpdatedApp: String  { return L10n.tr("Localizable", "Chat.Unsupported.UpdatedApp") }
  /// processing...
  public static var chatVideoProcessing: String  { return L10n.tr("Localizable", "Chat.Video.Processing") }
  /// Incoming Video Call
  public static var chatVideoCallIncoming: String  { return L10n.tr("Localizable", "Chat.VideoCall.Incoming") }
  /// Outgoing Video Call
  public static var chatVideoCallOutgoing: String  { return L10n.tr("Localizable", "Chat.VideoCall.Outgoing") }
  /// Join
  public static var chatVoiceChatJoinLinkOK: String  { return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.OK") }
  /// %d
  public static func chatVoiceChatJoinLinkParticipantsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_countable", p1)
  }
  /// %d participants
  public static func chatVoiceChatJoinLinkParticipantsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_few", p1)
  }
  /// %d participants
  public static func chatVoiceChatJoinLinkParticipantsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_many", p1)
  }
  /// %d participant
  public static func chatVoiceChatJoinLinkParticipantsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_one", p1)
  }
  /// %d participants
  public static func chatVoiceChatJoinLinkParticipantsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_other", p1)
  }
  /// %d participants
  public static func chatVoiceChatJoinLinkParticipantsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_two", p1)
  }
  /// no one joined yet
  public static var chatVoiceChatJoinLinkParticipantsZero: String  { return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Participants_zero") }
  /// Are you sure you want to join voice chat?
  public static var chatVoiceChatJoinLinkText: String  { return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Text") }
  /// Voice Chat
  public static var chatVoiceChatJoinLinkTitle: String  { return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Title") }
  /// Voice Chat no longer available
  public static var chatVoiceChatJoinLinkUnavailable: String  { return L10n.tr("Localizable", "Chat.VoiceChat.JoinLink.Unavailable") }
  /// Chat Background
  public static var chatWPBackgroundTitle: String  { return L10n.tr("Localizable", "Chat.WP.BackgroundTitle") }
  /// Color
  public static var chatWPColor: String  { return L10n.tr("Localizable", "Chat.WP.Color") }
  /// Pinch, swipe or double tap to select a custom area for the background.
  public static var chatWPFirstMessage: String  { return L10n.tr("Localizable", "Chat.WP.FirstMessage") }
  /// Pattern Intensity
  public static var chatWPIntensity: String  { return L10n.tr("Localizable", "Chat.WP.Intensity") }
  /// Pattern
  public static var chatWPPattern: String  { return L10n.tr("Localizable", "Chat.WP.Pattern") }
  /// Pinch me, I'm dreaming!
  public static var chatWPSecondMessage: String  { return L10n.tr("Localizable", "Chat.WP.SecondMessage") }
  /// Select From File
  public static var chatWPSelectFromFile: String  { return L10n.tr("Localizable", "Chat.WP.SelectFromFile") }
  /// Voice Chat
  public static var chatWPVoiceChatTitle: String  { return L10n.tr("Localizable", "Chat.WP.VoiceChatTitle") }
  /// Press Apply to set the background
  public static var chatWPColorFirstMessage: String  { return L10n.tr("Localizable", "Chat.WP.Color.FirstMessage") }
  /// Enjoy the view
  public static var chatWPColorSecondMessage: String  { return L10n.tr("Localizable", "Chat.WP.Color.SecondMessage") }
  /// None
  public static var chatWPPatternNone: String  { return L10n.tr("Localizable", "Chat.WP.Pattern.None") }
  /// %1$d of %2$d
  public static func chatWebpageMediaCount1(_ p1: Int, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Chat.Webpage.MediaCount1", p1, p2)
  }
  /// Menu
  public static var chatInputBotMenu: String  { return L10n.tr("Localizable", "ChatInput.BotMenu") }
  /// Show Next
  public static var chatInputShowNext: String  { return L10n.tr("Localizable", "ChatInput.ShowNext") }
  /// Archived Chats
  public static var chatListArchivedChats: String  { return L10n.tr("Localizable", "ChatList.ArchivedChats") }
  /// Show All
  public static var chatListCloseFilter: String  { return L10n.tr("Localizable", "ChatList.CloseFilter") }
  /// All
  public static var chatListCloseFilterShort: String  { return L10n.tr("Localizable", "ChatList.CloseFilterShort") }
  /// Draft:
  public static var chatListDraft: String  { return L10n.tr("Localizable", "ChatList.Draft") }
  /// **You have no conversations yet**\nStart messaging by tapping the pencil button in the top right corner or got to the Contacts section.
  public static var chatListEmptyText: String  { return L10n.tr("Localizable", "ChatList.EmptyText") }
  /// Channels
  public static var chatListFeeds: String  { return L10n.tr("Localizable", "ChatList.Feeds") }
  /// Group Channel
  public static var chatListGroupChannel: String  { return L10n.tr("Localizable", "ChatList.GroupChannel") }
  /// Hide Muted
  public static var chatListHideMuted: String  { return L10n.tr("Localizable", "ChatList.HideMuted") }
  /// Proxy Sponsor
  public static var chatListSponsoredChannel: String  { return L10n.tr("Localizable", "ChatList.SponsoredChannel") }
  /// Feed
  public static var chatListTitleFeed: String  { return L10n.tr("Localizable", "ChatList.TitleFeed") }
  /// Unhide Muted
  public static var chatListUnhideMuted: String  { return L10n.tr("Localizable", "ChatList.UnhideMuted") }
  /// Message is not supported
  public static var chatListUnsupportedMessage: String  { return L10n.tr("Localizable", "ChatList.UnsupportedMessage") }
  /// You
  public static var chatListYou: String  { return L10n.tr("Localizable", "ChatList.You") }
  /// CHATS
  public static var chatListAddBottomSeparator: String  { return L10n.tr("Localizable", "ChatList.Add.BottomSeparator") }
  /// Select chats...
  public static var chatListAddPlaceholder: String  { return L10n.tr("Localizable", "ChatList.Add.Placeholder") }
  /// Add
  public static var chatListAddSave: String  { return L10n.tr("Localizable", "ChatList.Add.Save") }
  /// CHAT TYPES
  public static var chatListAddTopSeparator: String  { return L10n.tr("Localizable", "ChatList.Add.TopSeparator") }
  /// Chats
  public static var chatListArchiveBack: String  { return L10n.tr("Localizable", "ChatList.Archive.Back") }
  /// Call
  public static var chatListContextCall: String  { return L10n.tr("Localizable", "ChatList.Context.Call") }
  /// Clear History
  public static var chatListContextClearHistory: String  { return L10n.tr("Localizable", "ChatList.Context.ClearHistory") }
  /// Delete And Exit
  public static var chatListContextDeleteAndExit: String  { return L10n.tr("Localizable", "ChatList.Context.DeleteAndExit") }
  /// Delete Chat
  public static var chatListContextDeleteChat: String  { return L10n.tr("Localizable", "ChatList.Context.DeleteChat") }
  /// Hide
  public static var chatListContextHidePromo: String  { return L10n.tr("Localizable", "ChatList.Context.HidePromo") }
  /// Leave Channel
  public static var chatListContextLeaveChannel: String  { return L10n.tr("Localizable", "ChatList.Context.LeaveChannel") }
  /// Leave Group
  public static var chatListContextLeaveGroup: String  { return L10n.tr("Localizable", "ChatList.Context.LeaveGroup") }
  /// Mark As Read
  public static var chatListContextMaskAsRead: String  { return L10n.tr("Localizable", "ChatList.Context.MaskAsRead") }
  /// Mark As Unread
  public static var chatListContextMaskAsUnread: String  { return L10n.tr("Localizable", "ChatList.Context.MaskAsUnread") }
  /// Mute
  public static var chatListContextMute: String  { return L10n.tr("Localizable", "ChatList.Context.Mute") }
  /// Pin
  public static var chatListContextPin: String  { return L10n.tr("Localizable", "ChatList.Context.Pin") }
  /// Sorry, you can pin no more than 5 chats to the top.
  public static var chatListContextPinError: String  { return L10n.tr("Localizable", "ChatList.Context.PinError") }
  /// Sorry, you can only pin 5 chats to the top in the main list. More chats can be pinned in Chat Folders and your Archive.
  public static var chatListContextPinErrorNew2: String  { return L10n.tr("Localizable", "ChatList.Context.PinErrorNew2") }
  /// Preview
  public static var chatListContextPreview: String  { return L10n.tr("Localizable", "ChatList.Context.Preview") }
  /// Return to Group
  public static var chatListContextReturnGroup: String  { return L10n.tr("Localizable", "ChatList.Context.ReturnGroup") }
  /// Unmute
  public static var chatListContextUnmute: String  { return L10n.tr("Localizable", "ChatList.Context.Unmute") }
  /// Unpin
  public static var chatListContextUnpin: String  { return L10n.tr("Localizable", "ChatList.Context.Unpin") }
  /// Set Up Folders
  public static var chatListContextPinErrorNewSetupFolders: String  { return L10n.tr("Localizable", "ChatList.Context.PinErrorNew.SetupFolders") }
  /// Add Chats
  public static var chatListFilterAddChats: String  { return L10n.tr("Localizable", "ChatList.Filter.AddChats") }
  /// Add to folder...
  public static var chatListFilterAddToFolder: String  { return L10n.tr("Localizable", "ChatList.Filter.AddToFolder") }
  /// All
  public static var chatListFilterAll: String  { return L10n.tr("Localizable", "ChatList.Filter.All") }
  /// All Chats
  public static var chatListFilterAllChats: String  { return L10n.tr("Localizable", "ChatList.Filter.AllChats") }
  /// Archive
  public static var chatListFilterArchive: String  { return L10n.tr("Localizable", "ChatList.Filter.Archive") }
  /// Chats
  public static var chatListFilterBack: String  { return L10n.tr("Localizable", "ChatList.Filter.Back") }
  /// Bots
  public static var chatListFilterBots: String  { return L10n.tr("Localizable", "ChatList.Filter.Bots") }
  /// Channels
  public static var chatListFilterChannels: String  { return L10n.tr("Localizable", "ChatList.Filter.Channels") }
  /// Contacts
  public static var chatListFilterContacts: String  { return L10n.tr("Localizable", "ChatList.Filter.Contacts") }
  /// Delete
  public static var chatListFilterDelete: String  { return L10n.tr("Localizable", "ChatList.Filter.Delete") }
  /// Create
  public static var chatListFilterDone: String  { return L10n.tr("Localizable", "ChatList.Filter.Done") }
  /// Edit
  public static var chatListFilterEdit: String  { return L10n.tr("Localizable", "ChatList.Filter.Edit") }
  /// Edit Folders
  public static var chatListFilterEditFilters: String  { return L10n.tr("Localizable", "ChatList.Filter.EditFilters") }
  /// **No chats currently match this folder.**\n\n[Edit Folder](filter)
  public static var chatListFilterEmpty: String  { return L10n.tr("Localizable", "ChatList.Filter.Empty") }
  /// Exclude Muted
  public static var chatListFilterExcludeMuted: String  { return L10n.tr("Localizable", "ChatList.Filter.ExcludeMuted") }
  /// Exclude Read
  public static var chatListFilterExcludeRead: String  { return L10n.tr("Localizable", "ChatList.Filter.ExcludeRead") }
  /// Groups
  public static var chatListFilterGroups: String  { return L10n.tr("Localizable", "ChatList.Filter.Groups") }
  /// Create folders for different groups of chats and quickly switch between them.
  public static var chatListFilterHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Header") }
  /// %d
  public static func chatListFilterHideCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_countable", p1)
  }
  /// Hide %d Chats
  public static func chatListFilterHideFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_few", p1)
  }
  /// Hide %d Chats
  public static func chatListFilterHideMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_many", p1)
  }
  /// Hide %d Chat
  public static func chatListFilterHideOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_one", p1)
  }
  /// Hide %d Chats
  public static func chatListFilterHideOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_other", p1)
  }
  /// Hide %d Chats
  public static func chatListFilterHideTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_two", p1)
  }
  /// Hide %d Chats
  public static func chatListFilterHideZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.Hide_zero", p1)
  }
  /// **Adding Chats**\nPlease wait a few moments while we fill this folder for you...
  public static var chatListFilterLoading: String  { return L10n.tr("Localizable", "ChatList.Filter.Loading") }
  /// Muted
  public static var chatListFilterMutedChats: String  { return L10n.tr("Localizable", "ChatList.Filter.MutedChats") }
  /// Create Folder
  public static var chatListFilterNewTitle: String  { return L10n.tr("Localizable", "ChatList.Filter.NewTitle") }
  /// Non-Contacts
  public static var chatListFilterNonContacts: String  { return L10n.tr("Localizable", "ChatList.Filter.NonContacts") }
  /// Read
  public static var chatListFilterReadChats: String  { return L10n.tr("Localizable", "ChatList.Filter.ReadChats") }
  /// Remove From Folder
  public static var chatListFilterRemoveFromFolder: String  { return L10n.tr("Localizable", "ChatList.Filter.RemoveFromFolder") }
  /// Secret Chats
  public static var chatListFilterSecretChat: String  { return L10n.tr("Localizable", "ChatList.Filter.SecretChat") }
  /// Edit Folders
  public static var chatListFilterSetup: String  { return L10n.tr("Localizable", "ChatList.Filter.Setup") }
  /// Add Folder
  public static var chatListFilterSetupEmpty: String  { return L10n.tr("Localizable", "ChatList.Filter.SetupEmpty") }
  /// %d
  public static func chatListFilterShowMoreCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_countable", p1)
  }
  /// Show %d More Chats
  public static func chatListFilterShowMoreFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_few", p1)
  }
  /// Show %d More Chats
  public static func chatListFilterShowMoreMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_many", p1)
  }
  /// Show %d More Chat
  public static func chatListFilterShowMoreOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_one", p1)
  }
  /// Show %d More Chats
  public static func chatListFilterShowMoreOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_other", p1)
  }
  /// Show %d More Chats
  public static func chatListFilterShowMoreTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_two", p1)
  }
  /// Show %d More Chats
  public static func chatListFilterShowMoreZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ChatList.Filter.ShowMore_zero", p1)
  }
  /// Small Groups
  public static var chatListFilterSmallGroups: String  { return L10n.tr("Localizable", "ChatList.Filter.SmallGroups") }
  /// Folder
  public static var chatListFilterTitle: String  { return L10n.tr("Localizable", "ChatList.Filter.Title") }
  /// You can organize your chats by right click.
  public static var chatListFilterTooltip: String  { return L10n.tr("Localizable", "ChatList.Filter.Tooltip") }
  /// Done
  public static var chatListFilterAddDone: String  { return L10n.tr("Localizable", "ChatList.Filter.Add.Done") }
  /// INCLUDE CHAT TYPES
  public static var chatListFilterCategoriesHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Categories.Header") }
  /// Delete Folder
  public static var chatListFilterConfirmRemoveHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Confirm.Remove.Header") }
  /// Delete
  public static var chatListFilterConfirmRemoveOK: String  { return L10n.tr("Localizable", "ChatList.Filter.Confirm.Remove.OK") }
  /// Are you sure you want to delete folder?
  public static var chatListFilterConfirmRemoveText: String  { return L10n.tr("Localizable", "ChatList.Filter.Confirm.Remove.Text") }
  /// Cancel
  public static var chatListFilterDiscardCancel: String  { return L10n.tr("Localizable", "ChatList.Filter.Discard.Cancel") }
  /// Discard Changes
  public static var chatListFilterDiscardHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Discard.Header") }
  /// Discard
  public static var chatListFilterDiscardOK: String  { return L10n.tr("Localizable", "ChatList.Filter.Discard.OK") }
  /// Are you sure you want to discard all changes?
  public static var chatListFilterDiscardText: String  { return L10n.tr("Localizable", "ChatList.Filter.Discard.Text") }
  /// Please add some chats or chat types to the folder.
  public static var chatListFilterErrorEmpty: String  { return L10n.tr("Localizable", "ChatList.Filter.Error.Empty") }
  /// Can’t create a folder that includes all your chats.
  public static var chatListFilterErrorLikeChats: String  { return L10n.tr("Localizable", "ChatList.Filter.Error.LikeChats") }
  /// Add Chats
  public static var chatListFilterExcludeAddChat: String  { return L10n.tr("Localizable", "ChatList.Filter.Exclude.AddChat") }
  /// Choose chats and types of chats that will never appear in this folder
  public static var chatListFilterExcludeDesc: String  { return L10n.tr("Localizable", "ChatList.Filter.Exclude.Desc") }
  /// EXCLUDED CHATS
  public static var chatListFilterExcludeHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Exclude.Header") }
  /// Sorry, you can only add up to 100 chats.
  public static var chatListFilterExcludeLimitReached: String  { return L10n.tr("Localizable", "ChatList.Filter.Exclude.LimitReached") }
  /// Remove
  public static var chatListFilterExcludeRemoveChat: String  { return L10n.tr("Localizable", "ChatList.Filter.Exclude.RemoveChat") }
  /// Add Chats
  public static var chatListFilterIncludeAddChat: String  { return L10n.tr("Localizable", "ChatList.Filter.Include.AddChat") }
  /// Choose chats and types of chats that will appear in this folder
  public static var chatListFilterIncludeDesc: String  { return L10n.tr("Localizable", "ChatList.Filter.Include.Desc") }
  /// INCLUDED CHATS
  public static var chatListFilterIncludeHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Include.Header") }
  /// Sorry, you can only add up to 100 chats.
  public static var chatListFilterIncludeLimitReached: String  { return L10n.tr("Localizable", "ChatList.Filter.Include.LimitReached") }
  /// Remove
  public static var chatListFilterIncludeRemoveChat: String  { return L10n.tr("Localizable", "ChatList.Filter.Include.RemoveChat") }
  /// Add a Custom Folder
  public static var chatListFilterListAddNew: String  { return L10n.tr("Localizable", "ChatList.Filter.List.AddNew") }
  /// Drag and drop folders to change order. Right click to remove.
  public static var chatListFilterListDesc: String  { return L10n.tr("Localizable", "ChatList.Filter.List.Desc") }
  /// FOLDERS
  public static var chatListFilterListHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.List.Header") }
  /// Remove
  public static var chatListFilterListRemove: String  { return L10n.tr("Localizable", "ChatList.Filter.List.Remove") }
  /// Chat Folders
  public static var chatListFilterListTitle: String  { return L10n.tr("Localizable", "ChatList.Filter.List.Title") }
  /// FOLDER NAME
  public static var chatListFilterNameHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Name.Header") }
  /// Folder Name
  public static var chatListFilterNamePlaceholder: String  { return L10n.tr("Localizable", "ChatList.Filter.Name.Placeholder") }
  /// Add
  public static var chatListFilterRecommendedAdd: String  { return L10n.tr("Localizable", "ChatList.Filter.Recommended.Add") }
  /// RECOMMENDED
  public static var chatListFilterRecommendedHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.Recommended.Header") }
  /// If you have many folders, try moving tabs to the left.
  public static var chatListFilterTabBarDesc: String  { return L10n.tr("Localizable", "ChatList.Filter.TabBar.Desc") }
  /// TABS VIEW
  public static var chatListFilterTabBarHeader: String  { return L10n.tr("Localizable", "ChatList.Filter.TabBar.Header") }
  /// Tabs on the left
  public static var chatListFilterTabBarOnTheLeft: String  { return L10n.tr("Localizable", "ChatList.Filter.TabBar.OnTheLeft") }
  /// Tabs at the top
  public static var chatListFilterTabBarOnTheTop: String  { return L10n.tr("Localizable", "ChatList.Filter.TabBar.OnTheTop") }
  /// Bots
  public static var chatListFilterTilteDefaultBots: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Bots") }
  /// Channels
  public static var chatListFilterTilteDefaultChannels: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Channels") }
  /// Contacts
  public static var chatListFilterTilteDefaultContacts: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Contacts") }
  /// Groups
  public static var chatListFilterTilteDefaultGroups: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Groups") }
  /// Non-Contacts
  public static var chatListFilterTilteDefaultNonContacts: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.NonContacts") }
  /// Unmuted
  public static var chatListFilterTilteDefaultUnmuted: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Unmuted") }
  /// Unread
  public static var chatListFilterTilteDefaultUnread: String  { return L10n.tr("Localizable", "ChatList.Filter.Tilte.Default.Unread") }
  /// For 1 Day
  public static var chatListMute1Day: String  { return L10n.tr("Localizable", "ChatList.Mute.1Day") }
  /// For 1 Hour
  public static var chatListMute1Hour: String  { return L10n.tr("Localizable", "ChatList.Mute.1Hour") }
  /// For 3 Days
  public static var chatListMute3Days: String  { return L10n.tr("Localizable", "ChatList.Mute.3Days") }
  /// For 4 Hours
  public static var chatListMute4Hours: String  { return L10n.tr("Localizable", "ChatList.Mute.4Hours") }
  /// For 8 Hours
  public static var chatListMute8Hours: String  { return L10n.tr("Localizable", "ChatList.Mute.8Hours") }
  /// Forever
  public static var chatListMuteForever: String  { return L10n.tr("Localizable", "ChatList.Mute.Forever") }
  /// Are you sure you want to read all chats?
  public static var chatListPopoverConfirm: String  { return L10n.tr("Localizable", "ChatList.Popover.Confirm") }
  /// Read All
  public static var chatListPopoverReadAll: String  { return L10n.tr("Localizable", "ChatList.Popover.ReadAll") }
  /// Collapse
  public static var chatListRevealActionCollapse: String  { return L10n.tr("Localizable", "ChatList.RevealAction.Collapse") }
  /// Expand
  public static var chatListRevealActionExpand: String  { return L10n.tr("Localizable", "ChatList.RevealAction.Expand") }
  /// Hide
  public static var chatListRevealActionHide: String  { return L10n.tr("Localizable", "ChatList.RevealAction.Hide") }
  /// Pin
  public static var chatListRevealActionPin: String  { return L10n.tr("Localizable", "ChatList.RevealAction.Pin") }
  /// %@ created a secret chat.
  public static func chatListSecretChatCreated(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.SecretChat.Created", p1)
  }
  /// Waiting to come online
  public static var chatListSecretChatExKeys: String  { return L10n.tr("Localizable", "ChatList.SecretChat.ExKeys") }
  /// %@ joined your secret chat.
  public static func chatListSecretChatJoined(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.SecretChat.Joined", p1)
  }
  /// Secret chat cancelled
  public static var chatListSecretChatTerminated: String  { return L10n.tr("Localizable", "ChatList.SecretChat.Terminated") }
  /// self-destructing photo
  public static var chatListServiceDestructingPhoto: String  { return L10n.tr("Localizable", "ChatList.Service.DestructingPhoto") }
  /// self-destructing video
  public static var chatListServiceDestructingVideo: String  { return L10n.tr("Localizable", "ChatList.Service.DestructingVideo") }
  /// %d %@
  public static func chatListServiceGameScored1Countable(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_countable", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1Few(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_few", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1Many(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_many", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1One(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_one", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1Other(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_other", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1Two(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_two", p1, p2)
  }
  /// scored %d in %@
  public static func chatListServiceGameScored1Zero(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.GameScored1_zero", p1, p2)
  }
  /// %1$@ invited %2$@ to the voice chat
  public static func chatListServiceVoiceChatInvitation(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatInvitation", p1, p2)
  }
  /// You invited %1$@ to the voice chat
  public static func chatListServiceVoiceChatInvitationByYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatInvitationByYou", p1)
  }
  /// %1$@ invited you to the voice chat
  public static func chatListServiceVoiceChatInvitationForYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatInvitationForYou", p1)
  }
  /// %1$@ scheduled a voice chat for %2$@
  public static func chatListServiceVoiceChatScheduled(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatScheduled", p1, p2)
  }
  /// You scheduled a voice chat for %2$@
  public static func chatListServiceVoiceChatScheduledYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatScheduledYou", p1)
  }
  /// %1$@ started a voice chat
  public static func chatListServiceVoiceChatStarted(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatStarted", p1)
  }
  /// You started a voice chat
  public static var chatListServiceVoiceChatStartedYou: String  { return L10n.tr("Localizable", "ChatList.Service.VoiceChatStartedYou") }
  /// Cancelled Call
  public static var chatListServiceCallCancelled: String  { return L10n.tr("Localizable", "ChatList.Service.Call.Cancelled") }
  /// Incoming Call (%@)
  public static func chatListServiceCallIncoming(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.Call.incoming", p1)
  }
  /// Missed Call
  public static var chatListServiceCallMissed: String  { return L10n.tr("Localizable", "ChatList.Service.Call.Missed") }
  /// Outgoing Call (%@)
  public static func chatListServiceCallOutgoing(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.Call.outgoing", p1)
  }
  /// Cancelled Video Call
  public static var chatListServiceVideoCallCancelled: String  { return L10n.tr("Localizable", "ChatList.Service.VideoCall.Cancelled") }
  /// Incoming Video Call (%@)
  public static func chatListServiceVideoCallIncoming(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VideoCall.incoming", p1)
  }
  /// Missed Video Call
  public static var chatListServiceVideoCallMissed: String  { return L10n.tr("Localizable", "ChatList.Service.VideoCall.Missed") }
  /// Outgoing Video Call (%@)
  public static func chatListServiceVideoCallOutgoing(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VideoCall.outgoing", p1)
  }
  /// voice chat ended (%1$@)
  public static func chatListServiceVoiceChatFinishedChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatFinished.Channel", p1)
  }
  /// voice chat scheduled for %@
  public static func chatListServiceVoiceChatScheduledChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatList.Service.VoiceChatScheduled.Channel", p1)
  }
  /// voice chat started
  public static var chatListServiceVoiceChatStartedChannel: String  { return L10n.tr("Localizable", "ChatList.Service.VoiceChatStarted.Channel") }
  /// Archive
  public static var chatListSwipingArchive: String  { return L10n.tr("Localizable", "ChatList.Swiping.Archive") }
  /// Delete
  public static var chatListSwipingDelete: String  { return L10n.tr("Localizable", "ChatList.Swiping.Delete") }
  /// Mute
  public static var chatListSwipingMute: String  { return L10n.tr("Localizable", "ChatList.Swiping.Mute") }
  /// Pin
  public static var chatListSwipingPin: String  { return L10n.tr("Localizable", "ChatList.Swiping.Pin") }
  /// Read
  public static var chatListSwipingRead: String  { return L10n.tr("Localizable", "ChatList.Swiping.Read") }
  /// Unarchive
  public static var chatListSwipingUnarchive: String  { return L10n.tr("Localizable", "ChatList.Swiping.Unarchive") }
  /// Unmute
  public static var chatListSwipingUnmute: String  { return L10n.tr("Localizable", "ChatList.Swiping.Unmute") }
  /// Unpin
  public static var chatListSwipingUnpin: String  { return L10n.tr("Localizable", "ChatList.Swiping.Unpin") }
  /// Unread
  public static var chatListSwipingUnread: String  { return L10n.tr("Localizable", "ChatList.Swiping.Unread") }
  /// views
  public static var chatMessageTooltipViews: String  { return L10n.tr("Localizable", "ChatMessage.Tooltip.Views") }
  /// channel created
  public static var chatServiceChannelCreated: String  { return L10n.tr("Localizable", "ChatService.ChannelCreated") }
  /// Your request to join the channel was approved
  public static var chatServiceJoinedChannelByRequest: String  { return L10n.tr("Localizable", "ChatService.JoinedChannelByRequest") }
  /// Your request to join the group was approved
  public static var chatServiceJoinedGroupByRequest: String  { return L10n.tr("Localizable", "ChatService.JoinedGroupByRequest") }
  /// %@ joined the channel by request
  public static func chatServiceUserJoinedChannelByRequest(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatService.UserJoinedChannelByRequest", p1)
  }
  /// %@ joined the group by request
  public static func chatServiceUserJoinedGroupByRequest(_ p1: String) -> String {
    return L10n.tr("Localizable", "ChatService.UserJoinedGroupByRequest", p1)
  }
  /// Report Messages
  public static var chatTitleReportMessages: String  { return L10n.tr("Localizable", "ChatTitle.ReportMessages") }
  /// Default
  public static var chatWallpaperEmpty: String  { return L10n.tr("Localizable", "ChatWallpaper.Empty") }
  /// E-Mail
  public static var checkoutEmail: String  { return L10n.tr("Localizable", "Checkout.Email") }
  /// Enter Password
  public static var checkoutEnterPassword: String  { return L10n.tr("Localizable", "Checkout.EnterPassword") }
  /// An error occurred while processing your payment. Your card has not been billed.
  public static var checkoutErrorGeneric: String  { return L10n.tr("Localizable", "Checkout.ErrorGeneric") }
  /// You have already paid for this item.
  public static var checkoutErrorInvoiceAlreadyPaid: String  { return L10n.tr("Localizable", "Checkout.ErrorInvoiceAlreadyPaid") }
  /// Payment failed. Your card has not been billed.
  public static var checkoutErrorPaymentFailed: String  { return L10n.tr("Localizable", "Checkout.ErrorPaymentFailed") }
  /// The bot couldn't process your payment. Your card has not been billed.
  public static var checkoutErrorPrecheckoutFailed: String  { return L10n.tr("Localizable", "Checkout.ErrorPrecheckoutFailed") }
  /// This bot can't accept payments at the moment. Please try again later.
  public static var checkoutErrorProviderAccountInvalid: String  { return L10n.tr("Localizable", "Checkout.ErrorProviderAccountInvalid") }
  /// This bot can't process payments at the moment. Please try again later.
  public static var checkoutErrorProviderAccountTimeout: String  { return L10n.tr("Localizable", "Checkout.ErrorProviderAccountTimeout") }
  /// Name
  public static var checkoutName: String  { return L10n.tr("Localizable", "Checkout.Name") }
  /// Payment Method
  public static var checkoutPaymentMethod: String  { return L10n.tr("Localizable", "Checkout.PaymentMethod") }
  /// Pay
  public static var checkoutPayNone: String  { return L10n.tr("Localizable", "Checkout.PayNone") }
  /// Pay %@
  public static func checkoutPayPrice(_ p1: String) -> String {
    return L10n.tr("Localizable", "Checkout.PayPrice", p1)
  }
  /// Phone
  public static var checkoutPhone: String  { return L10n.tr("Localizable", "Checkout.Phone") }
  /// PRICE
  public static var checkoutPriceHeader: String  { return L10n.tr("Localizable", "Checkout.PriceHeader") }
  /// Would you like to save your password for %@?
  public static func checkoutSavePasswordTimeout(_ p1: String) -> String {
    return L10n.tr("Localizable", "Checkout.SavePasswordTimeout", p1)
  }
  /// Shipping Information
  public static var checkoutShippingAddress: String  { return L10n.tr("Localizable", "Checkout.ShippingAddress") }
  /// Shipping Method
  public static var checkoutShippingMethod: String  { return L10n.tr("Localizable", "Checkout.ShippingMethod") }
  /// Your payment have successfully proceeded!
  public static var checkoutSuccess: String  { return L10n.tr("Localizable", "Checkout.Success") }
  /// Checkout
  public static var checkoutTitle: String  { return L10n.tr("Localizable", "Checkout.Title") }
  /// Total
  public static var checkoutTotalAmount: String  { return L10n.tr("Localizable", "Checkout.TotalAmount") }
  /// Total Paid
  public static var checkoutTotalPaidAmount: String  { return L10n.tr("Localizable", "Checkout.TotalPaidAmount") }
  /// Saving payments details are only available with 2-Step Verification.
  public static var checkout2FAText: String  { return L10n.tr("Localizable", "Checkout.2FA.Text") }
  /// Cardholder Name
  public static var checkoutNewCardCardholderNamePlaceholder: String  { return L10n.tr("Localizable", "Checkout.NewCard.CardholderNamePlaceholder") }
  /// CARDHOLDER
  public static var checkoutNewCardCardholderNameTitle: String  { return L10n.tr("Localizable", "Checkout.NewCard.CardholderNameTitle") }
  /// PAYMENT CARD
  public static var checkoutNewCardPaymentCard: String  { return L10n.tr("Localizable", "Checkout.NewCard.PaymentCard") }
  /// Zip Code
  public static var checkoutNewCardPostcodePlaceholder: String  { return L10n.tr("Localizable", "Checkout.NewCard.PostcodePlaceholder") }
  /// BILLING ADDRESS
  public static var checkoutNewCardPostcodeTitle: String  { return L10n.tr("Localizable", "Checkout.NewCard.PostcodeTitle") }
  /// Save Payment Information
  public static var checkoutNewCardSaveInfo: String  { return L10n.tr("Localizable", "Checkout.NewCard.SaveInfo") }
  /// You can save your payment information for future use.\nPlease [turn on Two-Step Verification] to enable this.
  public static var checkoutNewCardSaveInfoEnableHelp: String  { return L10n.tr("Localizable", "Checkout.NewCard.SaveInfoEnableHelp") }
  /// You can save your payment information for future use.
  public static var checkoutNewCardSaveInfoHelp: String  { return L10n.tr("Localizable", "Checkout.NewCard.SaveInfoHelp") }
  /// New Card
  public static var checkoutNewCardTitle: String  { return L10n.tr("Localizable", "Checkout.NewCard.Title") }
  /// Pay
  public static var checkoutPasswordEntryPay: String  { return L10n.tr("Localizable", "Checkout.PasswordEntry.Pay") }
  /// Your card %@ is on file. To pay with this card, please enter your 2-Step-Verification password.
  public static func checkoutPasswordEntryText(_ p1: String) -> String {
    return L10n.tr("Localizable", "Checkout.PasswordEntry.Text", p1)
  }
  /// Payment Confirmation
  public static var checkoutPasswordEntryTitle: String  { return L10n.tr("Localizable", "Checkout.PasswordEntry.Title") }
  /// New Card...
  public static var checkoutPaymentMethodNew: String  { return L10n.tr("Localizable", "Checkout.PaymentMethod.New") }
  /// Payment Method
  public static var checkoutPaymentMethodTitle: String  { return L10n.tr("Localizable", "Checkout.PaymentMethod.Title") }
  /// Receipt
  public static var checkoutReceiptTitle: String  { return L10n.tr("Localizable", "Checkout.Receipt.Title") }
  /// Shipping Method
  public static var checkoutShippingOptionTitle: String  { return L10n.tr("Localizable", "Checkout.ShippingOption.Title") }
  /// Complete Payment
  public static var checkoutWebConfirmationTitle: String  { return L10n.tr("Localizable", "Checkout.WebConfirmation.Title") }
  /// Please enter a valid city.
  public static var checkoutInfoErrorCityInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorCityInvalid") }
  /// Please enter a valid e-mail address.
  public static var checkoutInfoErrorEmailInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorEmailInvalid") }
  /// Please enter a valid name.
  public static var checkoutInfoErrorNameInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorNameInvalid") }
  /// Please enter a valid phone number.
  public static var checkoutInfoErrorPhoneInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorPhoneInvalid") }
  /// Please enter a valid postcode.
  public static var checkoutInfoErrorPostcodeInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorPostcodeInvalid") }
  /// Shipping to the selected country is not available.
  public static var checkoutInfoErrorShippingNotAvailable: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorShippingNotAvailable") }
  /// Please enter a valid state.
  public static var checkoutInfoErrorStateInvalid: String  { return L10n.tr("Localizable", "CheckoutInfo.ErrorStateInvalid") }
  /// Pay
  public static var checkoutInfoPay: String  { return L10n.tr("Localizable", "CheckoutInfo.Pay") }
  /// Email
  public static var checkoutInfoReceiverInfoEmail: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoEmail") }
  /// Email
  public static var checkoutInfoReceiverInfoEmailPlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoEmailPlaceholder") }
  /// Name
  public static var checkoutInfoReceiverInfoName: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoName") }
  /// Name Surname
  public static var checkoutInfoReceiverInfoNamePlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoNamePlaceholder") }
  /// Phone
  public static var checkoutInfoReceiverInfoPhone: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoPhone") }
  /// RECEIVER
  public static var checkoutInfoReceiverInfoTitle: String  { return L10n.tr("Localizable", "CheckoutInfo.ReceiverInfoTitle") }
  /// Save Info
  public static var checkoutInfoSaveInfo: String  { return L10n.tr("Localizable", "CheckoutInfo.SaveInfo") }
  /// You can save your shipping information for future use.
  public static var checkoutInfoSaveInfoHelp: String  { return L10n.tr("Localizable", "CheckoutInfo.SaveInfoHelp") }
  /// Address 1
  public static var checkoutInfoShippingInfoAddress1: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoAddress1") }
  /// Address
  public static var checkoutInfoShippingInfoAddress1Placeholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoAddress1Placeholder") }
  /// Address 2
  public static var checkoutInfoShippingInfoAddress2: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoAddress2") }
  /// Address
  public static var checkoutInfoShippingInfoAddress2Placeholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoAddress2Placeholder") }
  /// City
  public static var checkoutInfoShippingInfoCity: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoCity") }
  /// City
  public static var checkoutInfoShippingInfoCityPlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoCityPlaceholder") }
  /// Country
  public static var checkoutInfoShippingInfoCountry: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoCountry") }
  /// Country
  public static var checkoutInfoShippingInfoCountryPlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoCountryPlaceholder") }
  /// Postcode
  public static var checkoutInfoShippingInfoPostcode: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoPostcode") }
  /// Postcode
  public static var checkoutInfoShippingInfoPostcodePlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoPostcodePlaceholder") }
  /// State
  public static var checkoutInfoShippingInfoState: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoState") }
  /// State
  public static var checkoutInfoShippingInfoStatePlaceholder: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoStatePlaceholder") }
  /// SHIPPING ADDRESS
  public static var checkoutInfoShippingInfoTitle: String  { return L10n.tr("Localizable", "CheckoutInfo.ShippingInfoTitle") }
  /// Shipping Information
  public static var checkoutInfoTitle: String  { return L10n.tr("Localizable", "CheckoutInfo.Title") }
  /// Create
  public static var composeCreate: String  { return L10n.tr("Localizable", "Compose.Create") }
  /// Next
  public static var composeNext: String  { return L10n.tr("Localizable", "Compose.Next") }
  /// Select users
  public static var composeSelectUsers: String  { return L10n.tr("Localizable", "Compose.SelectUsers") }
  /// Start a secret chat with "%@"
  public static func composeConfirmStartSecretChat(_ p1: String) -> String {
    return L10n.tr("Localizable", "Compose.Confirm.StartSecretChat", p1)
  }
  /// You will be able to add more users after you finish creating the group and convert it to supergroup.
  public static var composeCreateGroupLimitError: String  { return L10n.tr("Localizable", "Compose.CreateGroup.LimitError") }
  /// New Channel
  public static var composePopoverNewChannel: String  { return L10n.tr("Localizable", "Compose.Popover.NewChannel") }
  /// New Group
  public static var composePopoverNewGroup: String  { return L10n.tr("Localizable", "Compose.Popover.NewGroup") }
  /// New Secret Chat
  public static var composePopoverNewSecretChat: String  { return L10n.tr("Localizable", "Compose.Popover.NewSecretChat") }
  /// Secret Chat
  public static var composeSelectSecretChat: String  { return L10n.tr("Localizable", "Compose.Select.SecretChat") }
  /// Whom would you like to message?
  public static var composeSelectGroupUsersPlaceholder: String  { return L10n.tr("Localizable", "Compose.SelectGroupUsers.Placeholder") }
  /// Add the bot to "%@"?
  public static func confirmAddBotToGroup(_ p1: String) -> String {
    return L10n.tr("Localizable", "Confirm.AddBotToGroup", p1)
  }
  /// Delete
  public static var confirmDelete: String  { return L10n.tr("Localizable", "Confirm.Delete") }
  /// Wait! Deleting this channel will remove all of its members and all of its messages will be lost forever.\n\nAre you sure you want to continue?
  public static var confirmDeleteAdminedChannel: String  { return L10n.tr("Localizable", "Confirm.DeleteAdminedChannel") }
  /// Are you sure you want to delete all message history?
  public static var confirmDeleteChatUser: String  { return L10n.tr("Localizable", "Confirm.DeleteChatUser") }
  /// Are you sure you want to leave this group?
  public static var confirmLeaveGroup: String  { return L10n.tr("Localizable", "Confirm.LeaveGroup") }
  /// The bot will know your phone number. This can be useful for integration with other services.
  public static var confirmDescPermissionInlineBotContact: String  { return L10n.tr("Localizable", "Confirm.Desc.PermissionInlineBotContact") }
  /// Share Your Phone Number?
  public static var confirmHeaderPermissionInlineBotContact: String  { return L10n.tr("Localizable", "Confirm.Header.PermissionInlineBotContact") }
  /// connecting
  public static var connectingStatusConnecting: String  { return L10n.tr("Localizable", "ConnectingStatus.connecting") }
  /// connecting to proxy
  public static var connectingStatusConnectingToProxy: String  { return L10n.tr("Localizable", "ConnectingStatus.connectingToProxy") }
  /// click here to disable proxy
  public static var connectingStatusDisableProxy: String  { return L10n.tr("Localizable", "ConnectingStatus.DisableProxy") }
  /// online
  public static var connectingStatusOnline: String  { return L10n.tr("Localizable", "ConnectingStatus.online") }
  /// updating
  public static var connectingStatusUpdating: String  { return L10n.tr("Localizable", "ConnectingStatus.updating") }
  /// waiting for network
  public static var connectingStatusWaitingNetwork: String  { return L10n.tr("Localizable", "ConnectingStatus.waitingNetwork") }
  /// Connected
  public static var connectionStatusConnected: String  { return L10n.tr("Localizable", "ConnectionStatus.Connected") }
  /// Connecting...
  public static var connectionStatusConnecting: String  { return L10n.tr("Localizable", "ConnectionStatus.Connecting") }
  /// Connecting To Proxy...
  public static var connectionStatusConnectingToProxy: String  { return L10n.tr("Localizable", "ConnectionStatus.ConnectingToProxy") }
  /// Up to date
  public static var connectionStatusUpdated: String  { return L10n.tr("Localizable", "ConnectionStatus.Updated") }
  /// Updating...
  public static var connectionStatusUpdating: String  { return L10n.tr("Localizable", "ConnectionStatus.Updating") }
  /// Waiting For Network...
  public static var connectionStatusWaitingForNetwork: String  { return L10n.tr("Localizable", "ConnectionStatus.WaitingForNetwork") }
  /// birthday
  public static var contactInfoBirthdayLabel: String  { return L10n.tr("Localizable", "ContactInfo.BirthdayLabel") }
  /// Contact Info
  public static var contactInfoContactInfo: String  { return L10n.tr("Localizable", "ContactInfo.ContactInfo") }
  /// job
  public static var contactInfoJob: String  { return L10n.tr("Localizable", "ContactInfo.Job") }
  /// home
  public static var contactInfoPhoneLabelHome: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelHome") }
  /// home fax
  public static var contactInfoPhoneLabelHomeFax: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelHomeFax") }
  /// main
  public static var contactInfoPhoneLabelMain: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelMain") }
  /// mobile
  public static var contactInfoPhoneLabelMobile: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelMobile") }
  /// other
  public static var contactInfoPhoneLabelOther: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelOther") }
  /// pager
  public static var contactInfoPhoneLabelPager: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelPager") }
  /// work
  public static var contactInfoPhoneLabelWork: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelWork") }
  /// work fax
  public static var contactInfoPhoneLabelWorkFax: String  { return L10n.tr("Localizable", "ContactInfo.PhoneLabelWorkFax") }
  /// homepage
  public static var contactInfoURLLabelHomepage: String  { return L10n.tr("Localizable", "ContactInfo.URLLabelHomepage") }
  /// Add Contact
  public static var contactsAddContact: String  { return L10n.tr("Localizable", "Contacts.AddContact") }
  /// Contacts
  public static var contactsContacsSeparator: String  { return L10n.tr("Localizable", "Contacts.ContacsSeparator") }
  /// This person is not registered on Telegram yet.\n\nYou will be able to send them a Telegram message as soon as they sign up.
  public static var contactsNotRegistredDescription: String  { return L10n.tr("Localizable", "Contacts.NotRegistredDescription") }
  /// Not a Telegram User
  public static var contactsNotRegistredTitle: String  { return L10n.tr("Localizable", "Contacts.NotRegistredTitle") }
  /// First Name
  public static var contactsFirstNamePlaceholder: String  { return L10n.tr("Localizable", "Contacts.FirstName.Placeholder") }
  /// Last Name
  public static var contactsLastNamePlaceholder: String  { return L10n.tr("Localizable", "Contacts.LastName.Placeholder") }
  /// phone number can't be empty
  public static var contactsPhoneNumberInvalid: String  { return L10n.tr("Localizable", "Contacts.PhoneNumber.Invalid") }
  /// the person with this phone number is not registered on Telegram yet.
  public static var contactsPhoneNumberNotRegistred: String  { return L10n.tr("Localizable", "Contacts.PhoneNumber.NotRegistred") }
  /// Phone Number
  public static var contactsPhoneNumberPlaceholder: String  { return L10n.tr("Localizable", "Contacts.PhoneNumber.Placeholder") }
  /// Copy
  public static var contextCopy: String  { return L10n.tr("Localizable", "Context.Copy") }
  /// Open in Quick Look
  public static var contextOpenInQuickLook: String  { return L10n.tr("Localizable", "Context.OpenInQuickLook") }
  /// Remove
  public static var contextRecentGifRemove: String  { return L10n.tr("Localizable", "Context.RecentGifRemove") }
  /// Remove
  public static var contextRemoveFaveSticker: String  { return L10n.tr("Localizable", "Context.RemoveFaveSticker") }
  /// Save as...
  public static var contextSaveMedia: String  { return L10n.tr("Localizable", "Context.SaveMedia") }
  /// Show In Finder
  public static var contextShowInFinder: String  { return L10n.tr("Localizable", "Context.ShowInFinder") }
  /// View Sticker Set
  public static var contextViewStickerSet: String  { return L10n.tr("Localizable", "Context.ViewStickerSet") }
  /// Copied to Clipboard
  public static var contextAlertCopied: String  { return L10n.tr("Localizable", "Context.Alert.Copied") }
  /// This link will only work for members of this chat
  public static var contextAlertCopyPrivate: String  { return L10n.tr("Localizable", "Context.Alert.CopyPrivate") }
  /// Are you sure? This action cannot be undone.
  public static var convertToSuperGroupConfirm: String  { return L10n.tr("Localizable", "ConvertToSuperGroup.Confirm") }
  /// Something went wrong, sorry. Please try again later.
  public static var convertToSupergroupAlertError: String  { return L10n.tr("Localizable", "ConvertToSupergroup.Alert.Error") }
  /// Sorry, copyng from this channel is disabled by admins.
  public static var copyRestrictedChannel: String  { return L10n.tr("Localizable", "CopyRestricted.Channel") }
  /// Sorry, copyng from this channel is disabled by admins.
  public static var copyRestrictedGroup: String  { return L10n.tr("Localizable", "CopyRestricted.Group") }
  /// Cancel
  public static var crashOnLaunchCancel: String  { return L10n.tr("Localizable", "CrashOnLaunch.Cancel") }
  /// If Telegram keeps crashing immediately after you open it, click OK to log out of the app. This should solve this issue.
  public static var crashOnLaunchInformation: String  { return L10n.tr("Localizable", "CrashOnLaunch.Information") }
  /// Something’s not right.
  public static var crashOnLaunchMessage: String  { return L10n.tr("Localizable", "CrashOnLaunch.Message") }
  /// Log out
  public static var crashOnLaunchOK: String  { return L10n.tr("Localizable", "CrashOnLaunch.OK") }
  /// Sorry, you are a member of too many groups and channels. Please leave some before creating a new one.
  public static var createChannelsTooMuch: String  { return L10n.tr("Localizable", "Create.ChannelsTooMuch") }
  /// Group Name
  public static var createGroupNameHolder: String  { return L10n.tr("Localizable", "CreateGroup.NameHolder") }
  /// Night Mode
  public static var darkModeConfirmNightModeHeader: String  { return L10n.tr("Localizable", "DarkMode.Confirm.NightMode.Header") }
  /// Disable
  public static var darkModeConfirmNightModeOK: String  { return L10n.tr("Localizable", "DarkMode.Confirm.NightMode.OK") }
  /// You have enabled auto night mode. If you want to change dark mode you have to disable it.
  public static var darkModeConfirmNightModeText: String  { return L10n.tr("Localizable", "DarkMode.Confirm.NightMode.Text") }
  /// Auto-Download Media
  public static var dataAndStorageAutomaticDownload: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload") }
  /// Download Folder
  public static var dataAndStorageDownloadFolder: String  { return L10n.tr("Localizable", "DataAndStorage.DownloadFolder") }
  /// Network Usage
  public static var dataAndStorageNetworkUsage: String  { return L10n.tr("Localizable", "DataAndStorage.NetworkUsage") }
  /// Storage Usage
  public static var dataAndStorageStorageUsage: String  { return L10n.tr("Localizable", "DataAndStorage.StorageUsage") }
  /// AUTOMATIC AUDIO DOWNLOAD
  public static var dataAndStorageAutomaticAudioDownloadHeader: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticAudioDownload.Header") }
  /// Files
  public static var dataAndStorageAutomaticDownloadFiles: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Files") }
  /// GIFs
  public static var dataAndStorageAutomaticDownloadGIFs: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.GIFs") }
  /// Groups and Channels
  public static var dataAndStorageAutomaticDownloadGroupsChannels: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.GroupsChannels") }
  /// AUTOMATIC MEDIA DOWNLOAD
  public static var dataAndStorageAutomaticDownloadHeader: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Header") }
  /// Video Messages
  public static var dataAndStorageAutomaticDownloadInstantVideo: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.InstantVideo") }
  /// Photos
  public static var dataAndStorageAutomaticDownloadPhoto: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Photo") }
  /// Reset Auto-Download Settings
  public static var dataAndStorageAutomaticDownloadReset: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Reset") }
  /// Videos
  public static var dataAndStorageAutomaticDownloadVideo: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Video") }
  /// Voice Messages
  public static var dataAndStorageAutomaticDownloadVoice: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticDownload.Voice") }
  /// AUTOMATIC PHOTO DOWNLOAD
  public static var dataAndStorageAutomaticPhotoDownloadHeader: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticPhotoDownload.Header") }
  /// AUTOMATIC VIDEO DOWNLOAD
  public static var dataAndStorageAutomaticVideoDownloadHeader: String  { return L10n.tr("Localizable", "DataAndStorage.AutomaticVideoDownload.Header") }
  /// GIFs
  public static var dataAndStorageAutoplayGIFs: String  { return L10n.tr("Localizable", "DataAndStorage.Autoplay.GIFs") }
  /// AUTO-PLAY MEDIA
  public static var dataAndStorageAutoplayHeader: String  { return L10n.tr("Localizable", "DataAndStorage.Autoplay.Header") }
  /// Sound on Hover
  public static var dataAndStorageAutoplaySoundOnHover: String  { return L10n.tr("Localizable", "DataAndStorage.Autoplay.SoundOnHover") }
  /// Videos
  public static var dataAndStorageAutoplayVideos: String  { return L10n.tr("Localizable", "DataAndStorage.Autoplay.Videos") }
  /// Sound will start playing when you move your cursor over a video.
  public static var dataAndStorageAutoplaySoundOnHoverDesc: String  { return L10n.tr("Localizable", "DataAndStorage.Autoplay.SoundOnHover.Desc") }
  /// Preload Larger Videos
  public static var dataAndStorageCategoryPreloadLargeVideos: String  { return L10n.tr("Localizable", "DataAndStorage.Category.PreloadLargeVideos") }
  /// Preload first few seconds (1-2 MB) of videos large than %@ MB for instant playback.
  public static func dataAndStorageCategoryPreloadLargeVideosDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "DataAndStorage.Category.PreloadLargeVideosDesc", p1)
  }
  /// Channels
  public static var dataAndStorageCategorySettingsChannels: String  { return L10n.tr("Localizable", "DataAndStorage.CategorySettings.Channels") }
  /// Group Chats
  public static var dataAndStorageCategorySettingsGroupChats: String  { return L10n.tr("Localizable", "DataAndStorage.CategorySettings.GroupChats") }
  /// Private Chats
  public static var dataAndStorageCategorySettingsPrivateChats: String  { return L10n.tr("Localizable", "DataAndStorage.CategorySettings.PrivateChats") }
  /// Unlimited
  public static var dataAndStorageCateroryFileSizeUnlimited: String  { return L10n.tr("Localizable", "DataAndStorage.CateroryFileSize.Unlimited") }
  /// LIMIT BY SIZE
  public static var dataAndStorageCateroryFileSizeLimitHeader: String  { return L10n.tr("Localizable", "DataAndStorage.CateroryFileSizeLimit.Header") }
  /// Undo all custom auto-download settings.
  public static var dataAndStorageConfirmResetSettings: String  { return L10n.tr("Localizable", "DataAndStorage.Confirm.ResetSettings") }
  /// Today
  public static var dateToday: String  { return L10n.tr("Localizable", "Date.Today") }
  /// Delete for all members
  public static var deleteChatDeleteGroupForAll: String  { return L10n.tr("Localizable", "DeleteChat.DeleteGroupForAll") }
  /// Link Group
  public static var discussionSetModalOK: String  { return L10n.tr("Localizable", "Discussion.Set.Modal.OK") }
  /// Do you want make **%@** the discussion board for **%@**?\n\nAny member of this group will be able to see messages in the channel.
  public static func discussionSetModalTextChannelPrivateGroup(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Discussion.Set.Modal.Text.ChannelPrivateGroup", p1, p2)
  }
  /// Do you want make **%@** the discussion board for **%@**?\n\nAny member of this group will able to see all messages in the channel.
  public static func discussionSetModalTextPrivateChannelPublicGroup(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Discussion.Set.Modal.Text.PrivateChannelPublicGroup", p1, p2)
  }
  /// Do you want make **%@** the discussion board for **%@**?
  public static func discussionSetModalTextPublicChannelPublicGroup(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Discussion.Set.Modal.Text.PublicChannelPublicGroup", p1, p2)
  }
  /// Discuss
  public static var discussionControllerIconText: String  { return L10n.tr("Localizable", "DiscussionController.IconText") }
  /// private channel
  public static var discussionControllerPrivateChannel: String  { return L10n.tr("Localizable", "DiscussionController.PrivateChannel") }
  /// private group
  public static var discussionControllerPrivateGroup: String  { return L10n.tr("Localizable", "DiscussionController.PrivateGroup") }
  /// Discussion Group
  public static var discussionControllerChannelTitle: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Title") }
  /// Create a New Group
  public static var discussionControllerChannelEmptyCreateGroup: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Empty.CreateGroup") }
  /// Everything you post in channel will be forwarded to this group.
  public static var discussionControllerChannelEmptyDescription: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Empty.Description") }
  /// Select a group chat that will be used to host comments from your channel.
  public static var discussionControllerChannelEmptyHeader1: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Empty.Header1") }
  /// Everything you post in channel is forwarded to this group.
  public static var discussionControllerChannelSetDescription: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Set.Description") }
  /// **%@** is selected as the group that will be used to host comments for your channel.
  public static func discussionControllerChannelSetHeader1(_ p1: String) -> String {
    return L10n.tr("Localizable", "DiscussionController.Channel.Set.Header1", p1)
  }
  /// Unlink Group
  public static var discussionControllerChannelSetUnlinkGroup: String  { return L10n.tr("Localizable", "DiscussionController.Channel.Set.UnlinkGroup") }
  /// Are you sure you want to unlink channel from this group?
  public static var discussionControllerConfrimUnlinkChannel: String  { return L10n.tr("Localizable", "DiscussionController.Confrim.UnlinkChannel") }
  /// Are you sure you want to unlink group from this channel?
  public static var discussionControllerConfrimUnlinkGroup: String  { return L10n.tr("Localizable", "DiscussionController.Confrim.UnlinkGroup") }
  /// Proceed
  public static var discussionControllerErrorOK: String  { return L10n.tr("Localizable", "DiscussionController.Error.OK") }
  /// Warning: If you set this private group as the disccussion group for your channel, all channel subscribers will be able to access the group. "Chat history for new members" will be switched to Visible
  public static var discussionControllerErrorPreHistory: String  { return L10n.tr("Localizable", "DiscussionController.Error.PreHistory") }
  /// Linked Channel
  public static var discussionControllerGroupTitle: String  { return L10n.tr("Localizable", "DiscussionController.Group.Title") }
  /// All new messages posted in this channel are forwarded to this group.
  public static var discussionControllerGroupSetDescription: String  { return L10n.tr("Localizable", "DiscussionController.Group.Set.Description") }
  /// **%@** is linking the group as its discussion board.
  public static func discussionControllerGroupSetHeader(_ p1: String) -> String {
    return L10n.tr("Localizable", "DiscussionController.Group.Set.Header", p1)
  }
  /// Unlink Channel
  public static var discussionControllerGroupSetUnlinkChannel: String  { return L10n.tr("Localizable", "DiscussionController.Group.Set.UnlinkChannel") }
  /// The channel successfully unlinked.
  public static var discussionControllerGroupUnsetDescription: String  { return L10n.tr("Localizable", "DiscussionController.Group.Unset.Description") }
  /// You will be displayed as your personal account.
  public static var displayMeAsAlone: String  { return L10n.tr("Localizable", "DisplayMeAs.Alone") }
  /// Continue as %@
  public static func displayMeAsContinueAs(_ p1: String) -> String {
    return L10n.tr("Localizable", "DisplayMeAs.ContinueAs", p1)
  }
  /// personal account
  public static var displayMeAsPersonalAccount: String  { return L10n.tr("Localizable", "DisplayMeAs.PersonalAccount") }
  /// Scheduled Voice Chat
  public static var displayMeAsScheduled: String  { return L10n.tr("Localizable", "DisplayMeAs.Scheduled") }
  /// Choose whether you want to be displayed as your personal account or as your channel.
  public static var displayMeAsText: String  { return L10n.tr("Localizable", "DisplayMeAs.Text") }
  /// Display Me As
  public static var displayMeAsTitle: String  { return L10n.tr("Localizable", "DisplayMeAs.Title") }
  /// You can also create a public channel to participate in voice chats as a channel.
  public static var displayMeAsAloneDesc: String  { return L10n.tr("Localizable", "DisplayMeAs.Alone.Desc") }
  /// Schedule Voice Chat as %@
  public static func displayMeAsNewScheduleAs(_ p1: String) -> String {
    return L10n.tr("Localizable", "DisplayMeAs.New.ScheduleAs", p1)
  }
  /// Start Voice Chat as %@
  public static func displayMeAsNewStartAs(_ p1: String) -> String {
    return L10n.tr("Localizable", "DisplayMeAs.New.StartAs", p1)
  }
  /// New Voice Chat
  public static var displayMeAsNewTitle: String  { return L10n.tr("Localizable", "DisplayMeAs.New.Title") }
  /// Subscribers will be notified that the voice chat start in %@
  public static func displayMeAsScheduledDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "DisplayMeAs.Scheduled.Desc", p1)
  }
  /// Choose whether you want to be displayed as your personal account or as group.
  public static var displayMeAsTextGroup: String  { return L10n.tr("Localizable", "DisplayMeAs.Text.Group") }
  /// Spelling and Grammar
  public static var dv1IoYv7Title: String  { return L10n.tr("Localizable", "Dv1-io-Yv7.title") }
  /// Edit
  public static var editMessageEditCurrentPhoto: String  { return L10n.tr("Localizable", "Edit.Message.EditCurrentPhoto") }
  /// Add Account
  public static var editAccountAddAccount: String  { return L10n.tr("Localizable", "EditAccount.AddAccount") }
  /// Change Number
  public static var editAccountChangeNumber: String  { return L10n.tr("Localizable", "EditAccount.ChangeNumber") }
  /// Log Out
  public static var editAccountLogout: String  { return L10n.tr("Localizable", "EditAccount.Logout") }
  /// Enter your name and add a profile photo.
  public static var editAccountNameDesc: String  { return L10n.tr("Localizable", "EditAccount.NameDesc") }
  /// Edit Profile
  public static var editAccountTitle: String  { return L10n.tr("Localizable", "EditAccount.Title") }
  /// Username
  public static var editAccountUsername: String  { return L10n.tr("Localizable", "EditAccount.Username") }
  /// Photo or Video
  public static var editAvatarPhotoOrVideo: String  { return L10n.tr("Localizable", "EditAvatar.PhotoOrVideo") }
  /// Sticker or GIF
  public static var editAvatarStickerOrGif: String  { return L10n.tr("Localizable", "EditAvatar.StickerOrGif") }
  /// RESET
  public static var editImageControlReset: String  { return L10n.tr("Localizable", "EditImageControl.Reset") }
  /// Are you sure you want to close and discard all changes?
  public static var editImageControlConfirmDiscard: String  { return L10n.tr("Localizable", "EditImageControl.Confirm.Discard") }
  /// Edit Link
  public static var editInvitationEditTitle: String  { return L10n.tr("Localizable", "EditInvitation.EditTitle") }
  /// Enter Number
  public static var editInvitationEnterNumber: String  { return L10n.tr("Localizable", "EditInvitation.EnterNumber") }
  /// Expiry Date
  public static var editInvitationExpiryDate: String  { return L10n.tr("Localizable", "EditInvitation.ExpiryDate") }
  /// you can make the link expire after a certain time.
  public static var editInvitationExpiryDesc: String  { return L10n.tr("Localizable", "EditInvitation.ExpiryDesc") }
  /// you can make the link expire after it has been used for a certain number of times.
  public static var editInvitationLimitDesc: String  { return L10n.tr("Localizable", "EditInvitation.LimitDesc") }
  /// LIMITED BY NUMBER OF USERS
  public static var editInvitationLimitedByCount: String  { return L10n.tr("Localizable", "EditInvitation.LimitedByCount") }
  /// LIMITED BY PERIOD
  public static var editInvitationLimitedByPeriod: String  { return L10n.tr("Localizable", "EditInvitation.LimitedByPeriod") }
  /// Never
  public static var editInvitationNever: String  { return L10n.tr("Localizable", "EditInvitation.Never") }
  /// New Link
  public static var editInvitationNewTitle: String  { return L10n.tr("Localizable", "EditInvitation.NewTitle") }
  /// Number of Users
  public static var editInvitationNumberOfUsers: String  { return L10n.tr("Localizable", "EditInvitation.NumberOfUsers") }
  /// Request Admin Approval.
  public static var editInvitationRequestApproval: String  { return L10n.tr("Localizable", "EditInvitation.RequestApproval") }
  /// Save
  public static var editInvitationSave: String  { return L10n.tr("Localizable", "EditInvitation.Save") }
  /// Only you and other admins will see this name.
  public static var editInvitationTitleDesc: String  { return L10n.tr("Localizable", "EditInvitation.TitleDesc") }
  /// Link Name (Optional)
  public static var editInvitationTitlePlaceholder: String  { return L10n.tr("Localizable", "EditInvitation.TitlePlaceholder") }
  /// Unlimited
  public static var editInvitationUnlimited: String  { return L10n.tr("Localizable", "EditInvitation.Unlimited") }
  /// Create
  public static var editInvitationOKCreate: String  { return L10n.tr("Localizable", "EditInvitation.OK.Create") }
  /// Save
  public static var editInvitationOKSave: String  { return L10n.tr("Localizable", "EditInvitation.OK.Save") }
  /// New users will be able to join the channel without being approved by the admins.
  public static var editInvitationRequestApprovalChannelOff: String  { return L10n.tr("Localizable", "EditInvitation.RequestApproval.Channel.Off") }
  /// New users will be able to join the channel only after having been approved by the admins.
  public static var editInvitationRequestApprovalChannelOn: String  { return L10n.tr("Localizable", "EditInvitation.RequestApproval.Channel.On") }
  /// New users will be able to join the group without being approved by the admins.
  public static var editInvitationRequestApprovalGroupOff: String  { return L10n.tr("Localizable", "EditInvitation.RequestApproval.Group.Off") }
  /// New users will be able to join the group only after having been approved by the admins.
  public static var editInvitationRequestApprovalGroupOn: String  { return L10n.tr("Localizable", "EditInvitation.RequestApproval.Group.On") }
  /// This name is already taken.
  public static var editThameNameAlreadyTaken: String  { return L10n.tr("Localizable", "EditThame.Name.AlreadyTaken") }
  /// Save
  public static var editThemeEdit: String  { return L10n.tr("Localizable", "EditTheme.Edit") }
  /// Theme Name
  public static var editThemeNamePlaceholder: String  { return L10n.tr("Localizable", "EditTheme.NamePlaceholder") }
  /// Create from File...
  public static var editThemeSelectFile: String  { return L10n.tr("Localizable", "EditTheme.SelectFile") }
  /// This theme will be based on your current theme and wallpaper. Otherwise, you can use a custom theme file if you already have one.
  public static var editThemeSelectFileDesc: String  { return L10n.tr("Localizable", "EditTheme.SelectFileDesc") }
  /// Update from File...
  public static var editThemeSelectUpdatedFile: String  { return L10n.tr("Localizable", "EditTheme.SelectUpdatedFile") }
  /// You can update your theme for all users by uploading manual changes from a file.
  public static var editThemeSelectUpdatedFileDesc: String  { return L10n.tr("Localizable", "EditTheme.SelectUpdatedFileDesc") }
  /// Your theme will be updated for all users each time you change it. Anyone can install it using this link.\n\nTheme links must be longer than 5 characters and can use a-z, 0-9 and underscores.
  public static var editThemeSlugDesc: String  { return L10n.tr("Localizable", "EditTheme.SlugDesc") }
  /// short link
  public static var editThemeSlugPlaceholder: String  { return L10n.tr("Localizable", "EditTheme.SlugPlaceholder") }
  /// Edit Theme
  public static var editThemeTitle: String  { return L10n.tr("Localizable", "EditTheme.Title") }
  /// This link is already taken. Please try a different one.
  public static var editThemeSlugErrorAlreadyExists: String  { return L10n.tr("Localizable", "EditTheme.SlugError.AlreadyExists") }
  /// invalid format.
  public static var editThemeSlugErrorFormat: String  { return L10n.tr("Localizable", "EditTheme.SlugError.Format") }
  /// Activity & Sport
  public static var emojiActivityAndSport: String  { return L10n.tr("Localizable", "Emoji.ActivityAndSport") }
  /// Animals & Nature
  public static var emojiAnimalsAndNature: String  { return L10n.tr("Localizable", "Emoji.AnimalsAndNature") }
  /// Flags
  public static var emojiFlags: String  { return L10n.tr("Localizable", "Emoji.Flags") }
  /// Food & Drink
  public static var emojiFoodAndDrink: String  { return L10n.tr("Localizable", "Emoji.FoodAndDrink") }
  /// Objects
  public static var emojiObjects: String  { return L10n.tr("Localizable", "Emoji.Objects") }
  /// Frequently Used
  public static var emojiRecent: String  { return L10n.tr("Localizable", "Emoji.Recent") }
  /// Smileys & People
  public static var emojiSmilesAndPeople: String  { return L10n.tr("Localizable", "Emoji.SmilesAndPeople") }
  /// Symbols
  public static var emojiSymbols: String  { return L10n.tr("Localizable", "Emoji.Symbols") }
  /// Travel & Places
  public static var emojiTravelAndPlaces: String  { return L10n.tr("Localizable", "Emoji.TravelAndPlaces") }
  /// Appearance
  public static var emptyChatAppearance: String  { return L10n.tr("Localizable", "EmptyChat.Appearance") }
  /// Suggest Stickers By Emoji
  public static var emptyChatStickers: String  { return L10n.tr("Localizable", "EmptyChat.Stickers") }
  /// Storage Usage
  public static var emptyChatStorageUsage: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage") }
  /// Chat Mode
  public static var emptyChatAppearanceChatMode: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.ChatMode") }
  /// Colorful
  public static var emptyChatAppearanceColorful: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.Colorful") }
  /// Dark
  public static var emptyChatAppearanceDark: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.Dark") }
  /// You can change these parameters and many others in Settings ⟶ [Appearance](appearance).
  public static var emptyChatAppearanceDesc: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.Desc") }
  /// Light
  public static var emptyChatAppearanceLight: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.Light") }
  /// Minimalism
  public static var emptyChatAppearanceMin: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.Min") }
  /// System
  public static var emptyChatAppearanceSystem: String  { return L10n.tr("Localizable", "EmptyChat.Appearance.System") }
  /// Next Tip
  public static var emptyChatNavigationNext: String  { return L10n.tr("Localizable", "EmptyChat.Navigation.Next") }
  /// Previous Tip
  public static var emptyChatNavigationPrev: String  { return L10n.tr("Localizable", "EmptyChat.Navigation.Prev") }
  /// All Sets
  public static var emptyChatStickersAllSets: String  { return L10n.tr("Localizable", "EmptyChat.Stickers.AllSets") }
  /// More trending stickers are available in\nSettings ⟶ Stickers ⟶ [Trending Stickers](trending).
  public static var emptyChatStickersDesc: String  { return L10n.tr("Localizable", "EmptyChat.Stickers.Desc") }
  /// My Sets
  public static var emptyChatStickersMySets: String  { return L10n.tr("Localizable", "EmptyChat.Stickers.MySets") }
  /// None
  public static var emptyChatStickersNone: String  { return L10n.tr("Localizable", "EmptyChat.Stickers.None") }
  /// Trending Stickers
  public static var emptyChatStickersTrending: String  { return L10n.tr("Localizable", "EmptyChat.Stickers.Trending") }
  /// Telegram uses **%@** of your storage.
  public static func emptyChatStorageUsageCacheDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "EmptyChat.StorageUsage.CacheDesc", p1)
  }
  /// Telegram cache is empty.
  public static var emptyChatStorageUsageCacheDescEmpty: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.CacheDescEmpty") }
  /// Clear Cache
  public static var emptyChatStorageUsageClear: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Clear") }
  /// Clearing...
  public static var emptyChatStorageUsageClearing: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Clearing") }
  /// Maximum Cache Size
  public static var emptyChatStorageUsageData: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Data") }
  /// More data and storage settings are available in\nSettings ⟶ [Data And Storage](storage).
  public static var emptyChatStorageUsageDesc: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Desc") }
  /// Calculating...
  public static var emptyChatStorageUsageLoading: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Loading") }
  /// 5 GB
  public static var emptyChatStorageUsageLow: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Low") }
  /// 32 GB
  public static var emptyChatStorageUsageMedium: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.Medium") }
  /// No Limit
  public static var emptyChatStorageUsageNoLimit: String  { return L10n.tr("Localizable", "EmptyChat.StorageUsage.NoLimit") }
  /// Telegram\n%@
  public static func emptyChatStorageUsageTooltipApp(_ p1: String) -> String {
    return L10n.tr("Localizable", "EmptyChat.StorageUsage.Tooltip.App", p1)
  }
  /// System\n%@
  public static func emptyChatStorageUsageTooltipSystem(_ p1: String) -> String {
    return L10n.tr("Localizable", "EmptyChat.StorageUsage.Tooltip.System", p1)
  }
  /// • Up to %@ members
  public static func emptyGroupInfoLine1(_ p1: String) -> String {
    return L10n.tr("Localizable", "EmptyGroupInfo.Line1", p1)
  }
  /// • Persistent chat history
  public static var emptyGroupInfoLine2: String  { return L10n.tr("Localizable", "EmptyGroupInfo.Line2") }
  /// • Public links such as t.me/title
  public static var emptyGroupInfoLine3: String  { return L10n.tr("Localizable", "EmptyGroupInfo.Line3") }
  /// • Admins with different rights
  public static var emptyGroupInfoLine4: String  { return L10n.tr("Localizable", "EmptyGroupInfo.Line4") }
  /// Groups can have:
  public static var emptyGroupInfoSubtitle: String  { return L10n.tr("Localizable", "EmptyGroupInfo.Subtitle") }
  /// You have created a group
  public static var emptyGroupInfoTitle: String  { return L10n.tr("Localizable", "EmptyGroupInfo.Title") }
  /// Select a chat to start messaging
  public static var emptyPeerDescription: String  { return L10n.tr("Localizable", "EmptyPeer.Description") }
  /// This image and text were derived from the encryption key for this secret chat with **%@**.\n\nIf they look the same on **%@**'s device, end-to-end encryption is guaranteed.
  public static func encryptionKeyDescription(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EncryptionKey.Description", p1, p2)
  }
  /// EMOJI
  public static var entertainmentEmoji: String  { return L10n.tr("Localizable", "Entertainment.Emoji") }
  /// GIFs
  public static var entertainmentGIF: String  { return L10n.tr("Localizable", "Entertainment.GIF") }
  /// STICKERS
  public static var entertainmentStickers: String  { return L10n.tr("Localizable", "Entertainment.Stickers") }
  /// Emoji
  public static var entertainmentSwitchEmoji: String  { return L10n.tr("Localizable", "Entertainment.Switch.Emoji") }
  /// Stickers & GIFs
  public static var entertainmentSwitchGifAndStickers: String  { return L10n.tr("Localizable", "Entertainment.Switch.GifAndStickers") }
  /// An error occured. Please try again later.
  public static var errorAnError: String  { return L10n.tr("Localizable", "Error.AnError") }
  /// This username is already taken.
  public static var errorUsernameAlreadyTaken: String  { return L10n.tr("Localizable", "Error.Username.AlreadyTaken") }
  /// This username is invalid.
  public static var errorUsernameInvalid: String  { return L10n.tr("Localizable", "Error.Username.Invalid") }
  /// A username must have at least 5 characters.
  public static var errorUsernameMinimumLength: String  { return L10n.tr("Localizable", "Error.Username.MinimumLength") }
  /// A username can't start with a number.
  public static var errorUsernameNumberStart: String  { return L10n.tr("Localizable", "Error.Username.NumberStart") }
  /// A username can't end with an underscore.
  public static var errorUsernameUnderscopeEnd: String  { return L10n.tr("Localizable", "Error.Username.UnderscopeEnd") }
  /// A username can't start with an underscore.
  public static var errorUsernameUnderscopeStart: String  { return L10n.tr("Localizable", "Error.Username.UnderscopeStart") }
  /// Banned %1$@ %2$@
  public static func eventLogServiceBanned1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Banned1", p1, p2)
  }
  /// changed defaults rights
  public static var eventLogServiceChangedDefaultsRights: String  { return L10n.tr("Localizable", "EventLog.Service.ChangedDefaultsRights") }
  /// %@ changed group sticker set
  public static func eventLogServiceChangedStickerSet(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.ChangedStickerSet", p1)
  }
  /// %@ deleted message:
  public static func eventLogServiceDeletedMessage(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.DeletedMessage", p1)
  }
  /// restricted %1$@ %2$@ indefinitely
  public static func eventLogServiceDemoted1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Demoted1", p1, p2)
  }
  /// %@ edited caption:
  public static func eventLogServiceEditedCaption(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.EditedCaption", p1)
  }
  /// %@ edited media:
  public static func eventLogServiceEditedMedia(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.EditedMedia", p1)
  }
  /// %@ edited message:
  public static func eventLogServiceEditedMessage(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.EditedMessage", p1)
  }
  /// %@ send message:
  public static func eventLogServicePostMessage(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.PostMessage", p1)
  }
  /// Previous Description
  public static var eventLogServicePreviousDesc: String  { return L10n.tr("Localizable", "EventLog.Service.PreviousDesc") }
  /// Previous Link
  public static var eventLogServicePreviousLink: String  { return L10n.tr("Localizable", "EventLog.Service.PreviousLink") }
  /// Previous Title
  public static var eventLogServicePreviousTitle: String  { return L10n.tr("Localizable", "EventLog.Service.PreviousTitle") }
  /// promoted %1$@ %2$@:
  public static func eventLogServicePromoted1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Promoted1", p1, p2)
  }
  /// %@ removed group sticker set
  public static func eventLogServiceRemovedStickerSet(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.RemovedStickerSet", p1)
  }
  /// %@ unpinned message
  public static func eventLogServiceRemovePinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.RemovePinned", p1)
  }
  /// %@ pinned message:
  public static func eventLogServiceUpdatePinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.UpdatePinned", p1)
  }
  /// Add Members
  public static var eventLogServiceDemoteAddMembers: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.AddMembers") }
  /// Change Info
  public static var eventLogServiceDemoteChangeInfo: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.ChangeInfo") }
  /// Embed Links
  public static var eventLogServiceDemoteEmbedLinks: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.EmbedLinks") }
  /// Pin Messages
  public static var eventLogServiceDemotePinMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.PinMessages") }
  /// Post Polls
  public static var eventLogServiceDemotePostPolls: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.PostPolls") }
  /// Send GIFs
  public static var eventLogServiceDemoteSendGifs: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.SendGifs") }
  /// Send Inline
  public static var eventLogServiceDemoteSendInline: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.SendInline") }
  /// Send Media
  public static var eventLogServiceDemoteSendMedia: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.SendMedia") }
  /// Send Messages
  public static var eventLogServiceDemoteSendMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.SendMessages") }
  /// Send Stickers
  public static var eventLogServiceDemoteSendStickers: String  { return L10n.tr("Localizable", "EventLog.Service.Demote.SendStickers") }
  /// changed the restrictions for %1$@ %2$@ indefinitely
  public static func eventLogServiceDemotedChanged1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Demoted.Changed1", p1, p2)
  }
  /// restricted %1$@ %2$@ until %3$@
  public static func eventLogServiceDemotedUntil1(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Demoted.Until1", p1, p2, p3)
  }
  /// changed restrictions for %1$@ %2$@ until %3$@
  public static func eventLogServiceDemotedChangedUntil1(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Demoted.Changed.Until1", p1, p2, p3)
  }
  /// Add New Admins
  public static var eventLogServicePromoteAddNewAdmins: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.AddNewAdmins") }
  /// Add Users
  public static var eventLogServicePromoteAddUsers: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.AddUsers") }
  /// Ban Users
  public static var eventLogServicePromoteBanUsers: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.BanUsers") }
  /// Change Info
  public static var eventLogServicePromoteChangeInfo: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.ChangeInfo") }
  /// Delete Messages
  public static var eventLogServicePromoteDeleteMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.DeleteMessages") }
  /// Edit Messages
  public static var eventLogServicePromoteEditMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.EditMessages") }
  /// Invite Users Via Link
  public static var eventLogServicePromoteInviteViaLink: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.InviteViaLink") }
  /// Pin Messages
  public static var eventLogServicePromotePinMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.PinMessages") }
  /// Post Messages
  public static var eventLogServicePromotePostMessages: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.PostMessages") }
  /// Remain Anonymous
  public static var eventLogServicePromoteRemainAnonymous: String  { return L10n.tr("Localizable", "EventLog.Service.Promote.RemainAnonymous") }
  /// changed privileges for %1$@ %2$@:
  public static func eventLogServicePromotedChanged1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "EventLog.Service.Promoted.Changed1", p1, p2)
  }
  /// Done
  public static var exportedInvitationDone: String  { return L10n.tr("Localizable", "ExportedInvitation.Done") }
  /// LINK CREATED BY
  public static var exportedInvitationLinkCreatedBy: String  { return L10n.tr("Localizable", "ExportedInvitation.LinkCreatedBy") }
  /// %d
  public static func exportedInvitationPeopleJoinedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_countable", p1)
  }
  /// %d PEOPLE JOINED
  public static func exportedInvitationPeopleJoinedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_few", p1)
  }
  /// %d PEOPLE JOINED
  public static func exportedInvitationPeopleJoinedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_many", p1)
  }
  /// %d PEOPLE JOINED
  public static func exportedInvitationPeopleJoinedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_one", p1)
  }
  /// %d PEOPLE JOINED
  public static func exportedInvitationPeopleJoinedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_other", p1)
  }
  /// %d PEOPLE JOINED
  public static func exportedInvitationPeopleJoinedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_two", p1)
  }
  /// 
  public static var exportedInvitationPeopleJoinedZero: String  { return L10n.tr("Localizable", "ExportedInvitation.PeopleJoined_zero") }
  /// %d
  public static func exportedInvitationPeopleRequestedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_countable", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func exportedInvitationPeopleRequestedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_few", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func exportedInvitationPeopleRequestedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_many", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func exportedInvitationPeopleRequestedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_one", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func exportedInvitationPeopleRequestedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_other", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func exportedInvitationPeopleRequestedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_two", p1)
  }
  /// 
  public static var exportedInvitationPeopleRequestedZero: String  { return L10n.tr("Localizable", "ExportedInvitation.PeopleRequested_zero") }
  /// Invite Link
  public static var exportedInvitationTitle: String  { return L10n.tr("Localizable", "ExportedInvitation.Title") }
  /// Copy
  public static var exportedInvitationContextCopy: String  { return L10n.tr("Localizable", "ExportedInvitation.Context.Copy") }
  /// Open Profile
  public static var exportedInvitationContextOpenProfile: String  { return L10n.tr("Localizable", "ExportedInvitation.Context.OpenProfile") }
  /// expired
  public static var exportedInvitationStatusExpired: String  { return L10n.tr("Localizable", "ExportedInvitation.Status.Expired") }
  /// expires in %@
  public static func exportedInvitationStatusExpiresIn(_ p1: String) -> String {
    return L10n.tr("Localizable", "ExportedInvitation.Status.ExpiresIn", p1)
  }
  /// revoked
  public static var exportedInvitationStatusRevoked: String  { return L10n.tr("Localizable", "ExportedInvitation.Status.Revoked") }
  /// Disable Dark Mode
  public static var fastSettingsDisableDarkMode: String  { return L10n.tr("Localizable", "FastSettings.DisableDarkMode") }
  /// Enable Dark Mode
  public static var fastSettingsEnableDarkMode: String  { return L10n.tr("Localizable", "FastSettings.EnableDarkMode") }
  /// Lock Telegram
  public static var fastSettingsLockTelegram: String  { return L10n.tr("Localizable", "FastSettings.LockTelegram") }
  /// Mute For 2 Hours
  public static var fastSettingsMute2Hours: String  { return L10n.tr("Localizable", "FastSettings.Mute2Hours") }
  /// Set a Passcode
  public static var fastSettingsSetPasscode: String  { return L10n.tr("Localizable", "FastSettings.SetPasscode") }
  /// Unmute
  public static var fastSettingsUnmute: String  { return L10n.tr("Localizable", "FastSettings.Unmute") }
  /// %@ B
  public static func fileSizeB(_ p1: String) -> String {
    return L10n.tr("Localizable", "FileSize.B", p1)
  }
  /// %@ GB
  public static func fileSizeGB(_ p1: String) -> String {
    return L10n.tr("Localizable", "FileSize.GB", p1)
  }
  /// %@ KB
  public static func fileSizeKB(_ p1: String) -> String {
    return L10n.tr("Localizable", "FileSize.KB", p1)
  }
  /// %@ MB
  public static func fileSizeMB(_ p1: String) -> String {
    return L10n.tr("Localizable", "FileSize.MB", p1)
  }
  /// forward messages here for quick access
  public static var forwardToSavedMessages: String  { return L10n.tr("Localizable", "Forward.ToSavedMessages") }
  /// %d %@
  public static func forwardModalActionDescriptionCountable(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_countable", p1, p2)
  }
  /// Select a user or chat to forward messages from %@
  public static func forwardModalActionDescriptionFew(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_few", p1)
  }
  /// Select a user or chat to forward messages from %@
  public static func forwardModalActionDescriptionMany(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_many", p1)
  }
  /// Select a user or chat to forward message from %@
  public static func forwardModalActionDescriptionOne(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_one", p1)
  }
  /// Select a user or chat to forward messages from %@
  public static func forwardModalActionDescriptionOther(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_other", p1)
  }
  /// Select a user or chat to forward messages from %@
  public static func forwardModalActionDescriptionTwo(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_two", p1)
  }
  /// Select a user or chat to forward messages from %@
  public static func forwardModalActionDescriptionZero(_ p1: String) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.description_zero", p1)
  }
  /// %d
  public static func forwardModalActionTitleCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ForwardModalAction.Title_countable", p1)
  }
  /// Forwarding messages
  public static var forwardModalActionTitleFew: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_few") }
  /// Forwarding messages
  public static var forwardModalActionTitleMany: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_many") }
  /// Forwarding message
  public static var forwardModalActionTitleOne: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_one") }
  /// Forwarding messages
  public static var forwardModalActionTitleOther: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_other") }
  /// Forwarding messages
  public static var forwardModalActionTitleTwo: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_two") }
  /// Forwarding messages
  public static var forwardModalActionTitleZero: String  { return L10n.tr("Localizable", "ForwardModalAction.Title_zero") }
  /// Delete
  public static var galleryContextDeletePhoto: String  { return L10n.tr("Localizable", "Gallery.ContextDeletePhoto") }
  /// Save GIF
  public static var gallerySaveGif: String  { return L10n.tr("Localizable", "Gallery.SaveGif") }
  /// Copy to Clipboard
  public static var galleryContextCopyToClipboard: String  { return L10n.tr("Localizable", "Gallery.Context.CopyToClipboard") }
  /// Set As Main Photo
  public static var galleryContextMainPhoto: String  { return L10n.tr("Localizable", "Gallery.Context.MainPhoto") }
  /// Save As...
  public static var galleryContextSaveAs: String  { return L10n.tr("Localizable", "Gallery.Context.SaveAs") }
  /// Shared Media
  public static var galleryContextShowGallery: String  { return L10n.tr("Localizable", "Gallery.Context.ShowGallery") }
  /// Show Message
  public static var galleryContextShowMessage: String  { return L10n.tr("Localizable", "Gallery.Context.ShowMessage") }
  /// %d
  public static func galleryContextShareAllItemsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_countable", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_few", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_many", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_one", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_other", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_two", p1)
  }
  /// All %d Items
  public static func galleryContextShareAllItemsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllItems_zero", p1)
  }
  /// %d
  public static func galleryContextShareAllPhotosCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_countable", p1)
  }
  /// All %d Photos
  public static func galleryContextShareAllPhotosFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_few", p1)
  }
  /// All %d Photos
  public static func galleryContextShareAllPhotosMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_many", p1)
  }
  /// All %d Photo
  public static func galleryContextShareAllPhotosOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_one", p1)
  }
  /// All %d Photos
  public static func galleryContextShareAllPhotosOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_other", p1)
  }
  /// All %d Photos
  public static func galleryContextShareAllPhotosTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_two", p1)
  }
  /// All %d Photos
  public static func galleryContextShareAllPhotosZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllPhotos_zero", p1)
  }
  /// %d
  public static func galleryContextShareAllVideosCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_countable", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_few", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_many", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_one", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_other", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_two", p1)
  }
  /// All %d Videos
  public static func galleryContextShareAllVideosZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Gallery.Context.Share.AllVideos_zero", p1)
  }
  /// This File
  public static var galleryContextShareThisFile: String  { return L10n.tr("Localizable", "Gallery.Context.Share.ThisFile") }
  /// This Photo
  public static var galleryContextShareThisPhoto: String  { return L10n.tr("Localizable", "Gallery.Context.Share.ThisPhoto") }
  /// This Video
  public static var galleryContextShareThisVideo: String  { return L10n.tr("Localizable", "Gallery.Context.Share.ThisVideo") }
  /// Please wait for the photo to be fully downloaded.
  public static var galleryWaitDownloadPhoto: String  { return L10n.tr("Localizable", "Gallery.WaitDownload.Photo") }
  /// Please wait for the video to be fully downloaded.
  public static var galleryWaitDownloadVideo: String  { return L10n.tr("Localizable", "Gallery.WaitDownload.Video") }
  /// GIF saved to\n[Downloads]()
  public static var galleryViewFastSaveGif1: String  { return L10n.tr("Localizable", "GalleryView.FastSave.Gif1") }
  /// Image saved to\n[Downloads]()
  public static var galleryViewFastSaveImage1: String  { return L10n.tr("Localizable", "GalleryView.FastSave.Image1") }
  /// Video saved to\n[Downloads]()
  public static var galleryViewFastSaveVideo1: String  { return L10n.tr("Localizable", "GalleryView.FastSave.Video1") }
  /// Accent Color
  public static var generalSettingsAccentColor: String  { return L10n.tr("Localizable", "GeneralSettings.AccentColor") }
  /// Accept Secret Chats
  public static var generalSettingsAcceptSecretChats: String  { return L10n.tr("Localizable", "GeneralSettings.AcceptSecretChats") }
  /// ADVANCED
  public static var generalSettingsAdvancedHeader: String  { return L10n.tr("Localizable", "GeneralSettings.AdvancedHeader") }
  /// APPEARANCE SETTINGS
  public static var generalSettingsAppearanceSettings: String  { return L10n.tr("Localizable", "GeneralSettings.AppearanceSettings") }
  /// Autoplay GIFs
  public static var generalSettingsAutoplayGifs: String  { return L10n.tr("Localizable", "GeneralSettings.AutoplayGifs") }
  /// Big Emoji
  public static var generalSettingsBigEmoji: String  { return L10n.tr("Localizable", "GeneralSettings.BigEmoji") }
  /// Chat Background
  public static var generalSettingsChatBackground: String  { return L10n.tr("Localizable", "GeneralSettings.ChatBackground") }
  /// Copy Text Formatting
  public static var generalSettingsCopyRTF: String  { return L10n.tr("Localizable", "GeneralSettings.CopyRTF") }
  /// Dark Mode
  public static var generalSettingsDarkMode: String  { return L10n.tr("Localizable", "GeneralSettings.DarkMode") }
  /// EMOJI & STICKERS
  public static var generalSettingsEmojiAndStickers: String  { return L10n.tr("Localizable", "GeneralSettings.EmojiAndStickers") }
  /// Suggest Emoji
  public static var generalSettingsEmojiPrediction: String  { return L10n.tr("Localizable", "GeneralSettings.EmojiPrediction") }
  /// Automatically replace emojis
  public static var generalSettingsEmojiReplacements: String  { return L10n.tr("Localizable", "GeneralSettings.EmojiReplacements") }
  /// Sidebar
  public static var generalSettingsEnableSidebar: String  { return L10n.tr("Localizable", "GeneralSettings.EnableSidebar") }
  /// FORCE TOUCH ACTION
  public static var generalSettingsForceTouchHeader: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouchHeader") }
  /// GENERAL SETTINGS
  public static var generalSettingsGeneralSettings: String  { return L10n.tr("Localizable", "GeneralSettings.GeneralSettings") }
  /// In-App Sounds
  public static var generalSettingsInAppSounds: String  { return L10n.tr("Localizable", "GeneralSettings.InAppSounds") }
  /// INPUT SETTINGS
  public static var generalSettingsInputSettings: String  { return L10n.tr("Localizable", "GeneralSettings.InputSettings") }
  /// INSTANT VIEW
  public static var generalSettingsInstantViewHeader: String  { return L10n.tr("Localizable", "GeneralSettings.InstantViewHeader") }
  /// INTERFACE
  public static var generalSettingsInterfaceHeader: String  { return L10n.tr("Localizable", "GeneralSettings.InterfaceHeader") }
  /// Handle media keys for in-app player
  public static var generalSettingsMediaKeysForInAppPlayer: String  { return L10n.tr("Localizable", "GeneralSettings.MediaKeysForInAppPlayer") }
  /// Reopen Last Chat On Launch
  public static var generalSettingsOpenLatestChatOnLaunch: String  { return L10n.tr("Localizable", "GeneralSettings.OpenLatestChatOnLaunch") }
  /// Use ⌘ + Enter to send
  public static var generalSettingsSendByCmdEnter: String  { return L10n.tr("Localizable", "GeneralSettings.SendByCmdEnter") }
  /// Use Enter to send
  public static var generalSettingsSendByEnter: String  { return L10n.tr("Localizable", "GeneralSettings.SendByEnter") }
  /// Keyboard Shortcuts
  public static var generalSettingsShortcuts: String  { return L10n.tr("Localizable", "GeneralSettings.Shortcuts") }
  /// SHORTCUTS
  public static var generalSettingsShortcutsHeader: String  { return L10n.tr("Localizable", "GeneralSettings.ShortcutsHeader") }
  /// Suggest Articles in Search
  public static var generalSettingsShowArticlesInSearch: String  { return L10n.tr("Localizable", "GeneralSettings.ShowArticlesInSearch") }
  /// Show Calls Tab
  public static var generalSettingsShowCallsTab: String  { return L10n.tr("Localizable", "GeneralSettings.ShowCallsTab") }
  /// Menu Bar Item
  public static var generalSettingsStatusBarItem: String  { return L10n.tr("Localizable", "GeneralSettings.StatusBarItem") }
  /// CALL SETTINGS
  public static var generalSettingsCallSettingsHeader: String  { return L10n.tr("Localizable", "GeneralSettings.CallSettings.Header") }
  /// Call Settings
  public static var generalSettingsCallSettingsText: String  { return L10n.tr("Localizable", "GeneralSettings.CallSettings.Text") }
  /// A color scheme for nighttime and dark desktops
  public static var generalSettingsDarkModeDescription: String  { return L10n.tr("Localizable", "GeneralSettings.DarkMode.Description") }
  /// Disable
  public static var generalSettingsEmojiPredictionDisable: String  { return L10n.tr("Localizable", "GeneralSettings.EmojiPrediction.Disable") }
  /// Disable emoji suggestions? You can re-enable them in Settings at any time.
  public static var generalSettingsEmojiPredictionDisableText: String  { return L10n.tr("Localizable", "GeneralSettings.EmojiPrediction.DisableText") }
  /// Use large font for messages
  public static var generalSettingsFontDescription: String  { return L10n.tr("Localizable", "GeneralSettings.Font.Description") }
  /// Edit Message
  public static var generalSettingsForceTouchEdit: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouch.Edit") }
  /// Forward Message
  public static var generalSettingsForceTouchForward: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouch.Forward") }
  /// Preview Media
  public static var generalSettingsForceTouchPreviewMedia: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouch.PreviewMedia") }
  /// Add Reaction
  public static var generalSettingsForceTouchReact: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouch.React") }
  /// Reply to Message
  public static var generalSettingsForceTouchReply: String  { return L10n.tr("Localizable", "GeneralSettings.ForceTouch.Reply") }
  /// Scroll With Spacebar
  public static var generalSettingsInstantViewScrollBySpace: String  { return L10n.tr("Localizable", "GeneralSettings.InstantView.ScrollBySpace") }
  /// More Info
  public static var genericErrorMoreInfo: String  { return L10n.tr("Localizable", "Generic.ErrorMoreInfo") }
  /// REACTIONS
  public static var gifsPaneReactions: String  { return L10n.tr("Localizable", "GifsPane.Reactions") }
  /// TRENDING GIFS
  public static var gifsPaneTrending: String  { return L10n.tr("Localizable", "GifsPane.Trending") }
  /// Total
  public static var graphTotal: String  { return L10n.tr("Localizable", "Graph.Total") }
  /// Zoom Out
  public static var graphZoomOut: String  { return L10n.tr("Localizable", "Graph.ZoomOut") }
  /// New Group
  public static var groupCreateGroup: String  { return L10n.tr("Localizable", "Group.CreateGroup") }
  /// Sorry, you can't add this user to group.
  public static var groupErrorAddBlocked: String  { return L10n.tr("Localizable", "Group.ErrorAddBlocked") }
  /// New Group
  public static var groupNewGroup: String  { return L10n.tr("Localizable", "Group.NewGroup") }
  /// Sorry, this group doesn't seem to exist.
  public static var groupUnavailable: String  { return L10n.tr("Localizable", "Group.Unavailable") }
  /// Sorry, this group is full. You cannot add any more members here.
  public static var groupUsersTooMuchError: String  { return L10n.tr("Localizable", "Group.UsersTooMuchError") }
  /// Change Group Info
  public static var groupEditAdminPermissionChangeInfo: String  { return L10n.tr("Localizable", "Group.EditAdmin.Permission.ChangeInfo") }
  /// **No events here yet**\n\nThere were no service actions taken by the group's members and admins for the last 48 hours.
  public static var groupEventLogEmptyText: String  { return L10n.tr("Localizable", "Group.EventLog.EmptyText") }
  /// %@ removed the group's description:
  public static func groupEventLogServiceAboutRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.AboutRemoved", p1)
  }
  /// %@ edited the group's description:
  public static func groupEventLogServiceAboutUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.AboutUpdated", p1)
  }
  /// %@ disabled group invites
  public static func groupEventLogServiceDisableInvites(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.DisableInvites", p1)
  }
  /// %@ enabled group invites
  public static func groupEventLogServiceEnableInvites(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.EnableInvites", p1)
  }
  /// %@ removed the group's link:
  public static func groupEventLogServiceLinkRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.LinkRemoved", p1)
  }
  /// %@ edited the group's link:
  public static func groupEventLogServiceLinkUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.LinkUpdated", p1)
  }
  /// %@ removed group photo
  public static func groupEventLogServicePhotoRemoved(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.PhotoRemoved", p1)
  }
  /// %@ updated the group's photo
  public static func groupEventLogServicePhotoUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.PhotoUpdated", p1)
  }
  /// %@ edited the group's title:
  public static func groupEventLogServiceTitleUpdated(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.TitleUpdated", p1)
  }
  /// %@ joined the group
  public static func groupEventLogServiceUpdateJoin(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.UpdateJoin", p1)
  }
  /// %@ left the group
  public static func groupEventLogServiceUpdateLeft(_ p1: String) -> String {
    return L10n.tr("Localizable", "Group.EventLog.Service.UpdateLeft", p1)
  }
  /// Sorry, the target user has too many location-based groups already. Please ask them to delete or transfer one of their existing ones first.
  public static var groupOwnershipTransferErrorLocatedGroupsTooMuch: String  { return L10n.tr("Localizable", "Group.OwnershipTransfer.ErrorLocatedGroupsTooMuch") }
  /// Sorry, this group has too many admins and the new owner can't be added. Please remove one of the existing admins first.
  public static var groupTransferOwnerErrorAdminsTooMuch: String  { return L10n.tr("Localizable", "Group.TransferOwner.ErrorAdminsTooMuch") }
  /// Sorry, this user is not a member of this group and their privacy settings prevent you from adding them manually.
  public static var groupTransferOwnerErrorPrivacyRestricted: String  { return L10n.tr("Localizable", "Group.TransferOwner.ErrorPrivacyRestricted") }
  /// All Members Are Admins
  public static var groupAdminsAllMembersAdmins: String  { return L10n.tr("Localizable", "GroupAdmins.AllMembersAdmins") }
  /// Only admins can add and remove members, and can edit the group's name and photo.
  public static var groupAdminsDescAdminInvites: String  { return L10n.tr("Localizable", "GroupAdmins.Desc.AdminInvites") }
  /// Group members can add new members, and can edit the name or photo of the group.
  public static var groupAdminsDescAllInvites: String  { return L10n.tr("Localizable", "GroupAdmins.Desc.AllInvites") }
  /// Share Screen
  public static var groupCallStatusBarStartScreen: String  { return L10n.tr("Localizable", "GroupCall.StatusBar.StartScreen") }
  /// Share Video
  public static var groupCallStatusBarStartVideo: String  { return L10n.tr("Localizable", "GroupCall.StatusBar.StartVideo") }
  /// Stop Screen
  public static var groupCallStatusBarStopScreen: String  { return L10n.tr("Localizable", "GroupCall.StatusBar.StopScreen") }
  /// Stop Video
  public static var groupCallStatusBarStopVideo: String  { return L10n.tr("Localizable", "GroupCall.StatusBar.StopVideo") }
  /// Sorry, if a person left a group, only a mutual contact can bring them back (they need to have your phone number, and you need theirs).
  public static var groupInfoAddUserLeftError: String  { return L10n.tr("Localizable", "GroupInfo.AddUserLeftError") }
  /// Administrators
  public static var groupInfoAdministrators: String  { return L10n.tr("Localizable", "GroupInfo.Administrators") }
  /// ⚠️ Warning: Many users reported that this group impersonates a famous person or organization.
  public static var groupInfoFakeWarning: String  { return L10n.tr("Localizable", "GroupInfo.FakeWarning") }
  /// ⚠️ Warning: Many users reported this group as a scam. Please be careful, especially if it asks you for money.
  public static var groupInfoScamWarning: String  { return L10n.tr("Localizable", "GroupInfo.ScamWarning") }
  /// Administrators
  public static var groupInfoAdministratorsTitle: String  { return L10n.tr("Localizable", "GroupInfo.Administrators.Title") }
  /// Add Exception
  public static var groupInfoPermissionsAddException: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.AddException") }
  /// Convert to Broadcast Group
  public static var groupInfoPermissionsBroadcastConvert: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.BroadcastConvert") }
  /// Broadcast groups can have over %@ members, but only admins can send messages in them.
  public static func groupInfoPermissionsBroadcastConvertInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "GroupInfo.Permissions.BroadcastConvertInfo", p1)
  }
  /// Broadcast Group
  public static var groupInfoPermissionsBroadcastTitle: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.BroadcastTitle") }
  /// EXCEPTIONS
  public static var groupInfoPermissionsExceptions: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.Exceptions") }
  /// Removed Users
  public static var groupInfoPermissionsRemoved: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.Removed") }
  /// Search Exceptions
  public static var groupInfoPermissionsSearchPlaceholder: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.SearchPlaceholder") }
  /// WHAT CAN MEMBERS OF THIS GROUP DO?
  public static var groupInfoPermissionsSectionTitle: String  { return L10n.tr("Localizable", "GroupInfo.Permissions.SectionTitle") }
  /// Anyone who has Telegram installed will be able to join your channel by following this link
  public static var groupInvationChannelDescription: String  { return L10n.tr("Localizable", "GroupInvation.ChannelDescription") }
  /// Copy Link
  public static var groupInvationCopyLink: String  { return L10n.tr("Localizable", "GroupInvation.CopyLink") }
  /// Anyone who has Telegram installed will be able to join your group by opening this link.
  public static var groupInvationGroupDescription: String  { return L10n.tr("Localizable", "GroupInvation.GroupDescription") }
  /// Revoke
  public static var groupInvationRevoke: String  { return L10n.tr("Localizable", "GroupInvation.Revoke") }
  /// Share Link
  public static var groupInvationShare: String  { return L10n.tr("Localizable", "GroupInvation.Share") }
  /// Exception added by %@ %@
  public static func groupPermissionAddedInfo(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "GroupPermission.AddedInfo", p1, p2)
  }
  /// Exception Added
  public static var groupPermissionAddSuccess: String  { return L10n.tr("Localizable", "GroupPermission.AddSuccess") }
  /// Apply
  public static var groupPermissionApplyAlertAction: String  { return L10n.tr("Localizable", "GroupPermission.ApplyAlertAction") }
  /// You have changed this user's rights in %@.\nApply Changes?
  public static func groupPermissionApplyAlertText(_ p1: String) -> String {
    return L10n.tr("Localizable", "GroupPermission.ApplyAlertText", p1)
  }
  /// Delete Exception
  public static var groupPermissionDelete: String  { return L10n.tr("Localizable", "GroupPermission.Delete") }
  /// Duration
  public static var groupPermissionDuration: String  { return L10n.tr("Localizable", "GroupPermission.Duration") }
  /// New Exception
  public static var groupPermissionNewTitle: String  { return L10n.tr("Localizable", "GroupPermission.NewTitle") }
  /// no add
  public static var groupPermissionNoAddMembers: String  { return L10n.tr("Localizable", "GroupPermission.NoAddMembers") }
  /// no info
  public static var groupPermissionNoChangeInfo: String  { return L10n.tr("Localizable", "GroupPermission.NoChangeInfo") }
  /// no pin
  public static var groupPermissionNoPinMessages: String  { return L10n.tr("Localizable", "GroupPermission.NoPinMessages") }
  /// no GIFs
  public static var groupPermissionNoSendGifs: String  { return L10n.tr("Localizable", "GroupPermission.NoSendGifs") }
  /// no links
  public static var groupPermissionNoSendLinks: String  { return L10n.tr("Localizable", "GroupPermission.NoSendLinks") }
  /// no media
  public static var groupPermissionNoSendMedia: String  { return L10n.tr("Localizable", "GroupPermission.NoSendMedia") }
  /// no messages
  public static var groupPermissionNoSendMessages: String  { return L10n.tr("Localizable", "GroupPermission.NoSendMessages") }
  /// no polls
  public static var groupPermissionNoSendPolls: String  { return L10n.tr("Localizable", "GroupPermission.NoSendPolls") }
  /// This permission is not available in public groups.
  public static var groupPermissionNotAvailableInPublicGroups: String  { return L10n.tr("Localizable", "GroupPermission.NotAvailableInPublicGroups") }
  /// WHAT CAN THIS MEMBER DO?
  public static var groupPermissionSectionTitle: String  { return L10n.tr("Localizable", "GroupPermission.SectionTitle") }
  /// Exception
  public static var groupPermissionTitle: String  { return L10n.tr("Localizable", "GroupPermission.Title") }
  /// Group Statistics
  public static var groupStatsTitle: String  { return L10n.tr("Localizable", "GroupStats.Title") }
  /// CHOOSE FROM YOUR STICKERS
  public static var groupStickersChooseHeader: String  { return L10n.tr("Localizable", "GroupStickers.ChooseHeader") }
  /// You can create your own custom sticker set using the @stickers bot.
  public static var groupStickersCreateDescription: String  { return L10n.tr("Localizable", "GroupStickers.CreateDescription") }
  /// Try again or choose from the list below
  public static var groupStickersEmptyDesc: String  { return L10n.tr("Localizable", "GroupStickers.EmptyDesc") }
  /// No such sticker set found
  public static var groupStickersEmptyHeader: String  { return L10n.tr("Localizable", "GroupStickers.EmptyHeader") }
  /// No groups in common
  public static var groupsInCommonEmpty: String  { return L10n.tr("Localizable", "GroupsInCommon.Empty") }
  /// View
  public static var h8h7bM4vTitle: String  { return L10n.tr("Localizable", "H8h-7b-M4v.title") }
  /// Text Replacement
  public static var hfqgknfaTitle: String  { return L10n.tr("Localizable", "HFQ-gK-NFA.title") }
  /// Show Spelling and Grammar
  public static var hFoCyZxITitle: String  { return L10n.tr("Localizable", "HFo-cy-zxI.title") }
  /// View
  public static var hyVFhRgOTitle: String  { return L10n.tr("Localizable", "HyV-fh-RgO.title") }
  /// Join
  public static var ivChannelJoin: String  { return L10n.tr("Localizable", "IV.Channel.Join") }
  /// Do you want to open "%@"?
  public static func inAppLinksConfirmOpenExternalNew(_ p1: String) -> String {
    return L10n.tr("Localizable", "InAppLinks.Confirm.OpenExternalNew", p1)
  }
  /// Open Link
  public static var inAppLinksConfirmOpenExternalHeader: String  { return L10n.tr("Localizable", "InAppLinks.Confirm.OpenExternal.Header") }
  /// Open
  public static var inAppLinksConfirmOpenExternalOK: String  { return L10n.tr("Localizable", "InAppLinks.Confirm.OpenExternal.OK") }
  /// Too many groups and channels
  public static var inactiveChannelsBlockHeader: String  { return L10n.tr("Localizable", "InactiveChannels.BlockHeader") }
  /// LEAST ACTIVE
  public static var inactiveChannelsHeader: String  { return L10n.tr("Localizable", "InactiveChannels.Header") }
  /// %d
  public static func inactiveChannelsInactiveMonthCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_countable", p1)
  }
  /// inactive %d months
  public static func inactiveChannelsInactiveMonthFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_few", p1)
  }
  /// inactive %d months
  public static func inactiveChannelsInactiveMonthMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_many", p1)
  }
  /// inactive %d month
  public static func inactiveChannelsInactiveMonthOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_one", p1)
  }
  /// inactive %d months
  public static func inactiveChannelsInactiveMonthOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_other", p1)
  }
  /// inactive %d months
  public static func inactiveChannelsInactiveMonthTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_two", p1)
  }
  /// inactive %d month
  public static func inactiveChannelsInactiveMonthZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveMonth_zero", p1)
  }
  /// %d
  public static func inactiveChannelsInactiveWeekCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_countable", p1)
  }
  /// inactive %d weeks
  public static func inactiveChannelsInactiveWeekFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_few", p1)
  }
  /// inactive %d weeks
  public static func inactiveChannelsInactiveWeekMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_many", p1)
  }
  /// inactive %d week
  public static func inactiveChannelsInactiveWeekOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_one", p1)
  }
  /// inactive %d weeks
  public static func inactiveChannelsInactiveWeekOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_other", p1)
  }
  /// inactive %d weeks
  public static func inactiveChannelsInactiveWeekTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_two", p1)
  }
  /// inactive %d week
  public static func inactiveChannelsInactiveWeekZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveWeek_zero", p1)
  }
  /// %d
  public static func inactiveChannelsInactiveYearCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_countable", p1)
  }
  /// inactive %d years
  public static func inactiveChannelsInactiveYearFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_few", p1)
  }
  /// inactive %d years
  public static func inactiveChannelsInactiveYearMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_many", p1)
  }
  /// inactive %d year
  public static func inactiveChannelsInactiveYearOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_one", p1)
  }
  /// inactive %d years
  public static func inactiveChannelsInactiveYearOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_other", p1)
  }
  /// inactive %d years
  public static func inactiveChannelsInactiveYearTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_two", p1)
  }
  /// inactive %d year
  public static func inactiveChannelsInactiveYearZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InactiveChannels.InactiveYear_zero", p1)
  }
  /// Leave
  public static var inactiveChannelsOK: String  { return L10n.tr("Localizable", "InactiveChannels.OK") }
  /// Limit Reached
  public static var inactiveChannelsTitle: String  { return L10n.tr("Localizable", "InactiveChannels.Title") }
  /// Select a user or chat to share content via %@
  public static func inlineModalActionDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "InlineModalAction.Desc", p1)
  }
  /// Share bot content
  public static var inlineModalActionTitle: String  { return L10n.tr("Localizable", "InlineModalAction.Title") }
  /// File
  public static var inputAttachPopoverFile: String  { return L10n.tr("Localizable", "InputAttach.Popover.File") }
  /// Location
  public static var inputAttachPopoverLocation: String  { return L10n.tr("Localizable", "InputAttach.Popover.Location") }
  /// Audio File
  public static var inputAttachPopoverMusic: String  { return L10n.tr("Localizable", "InputAttach.Popover.Music") }
  /// Photo Or Video
  public static var inputAttachPopoverPhotoOrVideo: String  { return L10n.tr("Localizable", "InputAttach.Popover.PhotoOrVideo") }
  /// Camera
  public static var inputAttachPopoverPicture: String  { return L10n.tr("Localizable", "InputAttach.Popover.Picture") }
  /// Poll
  public static var inputAttachPopoverPoll: String  { return L10n.tr("Localizable", "InputAttach.Popover.Poll") }
  /// Day:
  public static var inputDataDateDayPlaceholder: String  { return L10n.tr("Localizable", "InputData.Date.Day.Placeholder") }
  /// Day
  public static var inputDataDateDayPlaceholder1: String  { return L10n.tr("Localizable", "InputData.Date.Day.Placeholder1") }
  /// Month:
  public static var inputDataDateMonthPlaceholder: String  { return L10n.tr("Localizable", "InputData.Date.Month.Placeholder") }
  /// Month
  public static var inputDataDateMonthPlaceholder1: String  { return L10n.tr("Localizable", "InputData.Date.Month.Placeholder1") }
  /// Year:
  public static var inputDataDateYearPlaceholder: String  { return L10n.tr("Localizable", "InputData.Date.Year.Placeholder") }
  /// Year
  public static var inputDataDateYearPlaceholder1: String  { return L10n.tr("Localizable", "InputData.Date.Year.Placeholder1") }
  /// TEXT
  public static var inputFormatterTextHeader: String  { return L10n.tr("Localizable", "InputFormatter.Text.Header") }
  /// URL
  public static var inputFormatterURLHeader: String  { return L10n.tr("Localizable", "InputFormatter.URL.Header") }
  /// URL
  public static var inputFormatterURLPlaceholder: String  { return L10n.tr("Localizable", "InputFormatter.URL.Placeholder") }
  /// Password
  public static var inputPasswordControllerPlaceholder: String  { return L10n.tr("Localizable", "InputPasswordController.Placeholder") }
  /// Invalid password. Please try again
  public static var inputPasswordControllerErrorWrongPassword: String  { return L10n.tr("Localizable", "InputPasswordController.Error.WrongPassword") }
  /// Archived Stickers
  public static var installedStickersArchived: String  { return L10n.tr("Localizable", "InstalledStickers.Archived") }
  /// Artists are welcome to add their own sticker sets using our @stickers bot.\n\nTap on a sticker to view and add the whole set.
  public static var installedStickersDescrpiption: String  { return L10n.tr("Localizable", "InstalledStickers.Descrpiption") }
  /// Loop Animated Stickers
  public static var installedStickersLoopAnimated: String  { return L10n.tr("Localizable", "InstalledStickers.LoopAnimated") }
  /// STICKER SETS
  public static var installedStickersPacksTitle: String  { return L10n.tr("Localizable", "InstalledStickers.PacksTitle") }
  /// Reactions
  public static var installedStickersQuickReaction1: String  { return L10n.tr("Localizable", "InstalledStickers.QuickReaction1") }
  /// Trending Stickers
  public static var installedStickersTranding: String  { return L10n.tr("Localizable", "InstalledStickers.Tranding") }
  /// Delete
  public static var installedStickersRemoveDelete: String  { return L10n.tr("Localizable", "InstalledStickers.Remove.Delete") }
  /// Stickers will be archived, you can quickly restore it later from the Archived Stickers section.
  public static var installedStickersRemoveDescription: String  { return L10n.tr("Localizable", "InstalledStickers.Remove.Description") }
  /// By %1$@ • %2$@
  public static func instantPageAuthorAndDateTitle(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "InstantPage.AuthorAndDateTitle", p1, p2)
  }
  /// %@ • %@
  public static func instantPageRelatedArticleAuthorAndDateTitle(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "InstantPage.RelatedArticleAuthorAndDateTitle", p1, p2)
  }
  /// Sorry, the target user is a member of too many groups and channels. Please ask them to leave some first.
  public static var inviteChannelsTooMuch: String  { return L10n.tr("Localizable", "Invite.ChannelsTooMuch") }
  /// %d
  public static func inviteLinkCanJoinCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_countable", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_few", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_many", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_one", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_other", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_two", p1)
  }
  /// %d can join
  public static func inviteLinkCanJoinZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.CanJoin_zero", p1)
  }
  /// %d
  public static func inviteLinkEmptyJoinDescCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_countable", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_few", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_many", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_one", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_other", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_two", p1)
  }
  /// %d people can join via this link
  public static func inviteLinkEmptyJoinDescZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.EmptyJoinDesc_zero", p1)
  }
  /// %d
  public static func inviteLinkJoinedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_countable", p1)
  }
  /// %d joined
  public static func inviteLinkJoinedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_few", p1)
  }
  /// %d joined
  public static func inviteLinkJoinedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_many", p1)
  }
  /// %d joined
  public static func inviteLinkJoinedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_one", p1)
  }
  /// %d joined
  public static func inviteLinkJoinedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_other", p1)
  }
  /// %d joined
  public static func inviteLinkJoinedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Joined_two", p1)
  }
  /// no one joined yet
  public static var inviteLinkJoinedZero: String  { return L10n.tr("Localizable", "InviteLink.Joined_zero") }
  /// no one joined
  public static var inviteLinkJoinedRevoked: String  { return L10n.tr("Localizable", "InviteLink.JoinedRevoked") }
  /// %d
  public static func inviteLinkRemainingCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_countable", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_few", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_many", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_one", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_other", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_two", p1)
  }
  /// • %d remaining
  public static func inviteLinkRemainingZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Remaining_zero", p1)
  }
  /// %d
  public static func inviteLinkRequestedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_countable", p1)
  }
  /// %d requested
  public static func inviteLinkRequestedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_few", p1)
  }
  /// %d requested
  public static func inviteLinkRequestedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_many", p1)
  }
  /// %d requested
  public static func inviteLinkRequestedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_one", p1)
  }
  /// %d requested
  public static func inviteLinkRequestedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_other", p1)
  }
  /// %d requested
  public static func inviteLinkRequestedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "InviteLink.Requested_two", p1)
  }
  /// no one requested yet
  public static var inviteLinkRequestedZero: String  { return L10n.tr("Localizable", "InviteLink.Requested_zero") }
  /// Share Link
  public static var inviteLinkShareLink: String  { return L10n.tr("Localizable", "InviteLink.ShareLink") }
  ///  • expired
  public static var inviteLinkStickerExpired: String  { return L10n.tr("Localizable", "InviteLink.Sticker.Expired") }
  ///  • limit reached
  public static var inviteLinkStickerLimit: String  { return L10n.tr("Localizable", "InviteLink.Sticker.Limit") }
  /// • revoked
  public static var inviteLinkStickerRevoked: String  { return L10n.tr("Localizable", "InviteLink.Sticker.Revoked") }
  /// expires in %@
  public static func inviteLinkStickerTimeLeft(_ p1: String) -> String {
    return L10n.tr("Localizable", "InviteLink.Sticker.TimeLeft", p1)
  }
  /// Sorry, you are a member of too many groups and channels. Please leave some before joining one.
  public static var joinChannelsTooMuch: String  { return L10n.tr("Localizable", "Join.ChannelsTooMuch") }
  /// Inactive Chats
  public static var joinInactiveChannels: String  { return L10n.tr("Localizable", "Join.InactiveChannels") }
  /// Limit exceeded. Please try again later.
  public static var joinLinkFloodError: String  { return L10n.tr("Localizable", "JoinLink.FloodError") }
  /// Join
  public static var joinLinkJoin: String  { return L10n.tr("Localizable", "JoinLink.Join") }
  /// Show All
  public static var kd2MpPUSTitle: String  { return L10n.tr("Localizable", "Kd2-mp-pUS.title") }
  /// Bring All to Front
  public static var le2AR0XJTitle: String  { return L10n.tr("Localizable", "LE2-aR-0XJ.title") }
  /// OFFICIAL TRANSLATIONS
  public static var languageOfficialTransationsHeader: String  { return L10n.tr("Localizable", "Language.OfficialTransationsHeader") }
  /// Are you sure you want to remove this lang-pack?
  public static var languageRemovePack: String  { return L10n.tr("Localizable", "Language.RemovePack") }
  /// %d
  public static func lastSeenHoursAgoCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_countable", p1)
  }
  /// last seen %d hours ago
  public static func lastSeenHoursAgoFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_few", p1)
  }
  /// last seen %d hours ago
  public static func lastSeenHoursAgoMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_many", p1)
  }
  /// last seen %d hour ago
  public static func lastSeenHoursAgoOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_one", p1)
  }
  /// last seen %d hours ago
  public static func lastSeenHoursAgoOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_other", p1)
  }
  /// last seen %d hours ago
  public static func lastSeenHoursAgoTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_two", p1)
  }
  /// last seen %d hour ago
  public static func lastSeenHoursAgoZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "LastSeen.HoursAgo_zero", p1)
  }
  /// Welcome to the new super-fast and stable Telegram for macOS, fully rewritten in Swift 3.0.
  public static var legacyIntroDescription1: String  { return L10n.tr("Localizable", "Legacy.Intro.Description1") }
  /// Please note that your existing secret chats will be available in read-only mode. You can of course create new ones to continue chatting.
  public static var legacyIntroDescription2: String  { return L10n.tr("Localizable", "Legacy.Intro.Description2") }
  /// Start Messaging
  public static var legacyIntroNext: String  { return L10n.tr("Localizable", "Legacy.Intro.Next") }
  /// Sorry, this link has expired.
  public static var linkExpired: String  { return L10n.tr("Localizable", "Link.Expired") }
  /// Are you sure you want to revoke this link? Once you do, no one will be able to join the channel using it.
  public static var linkInvationChannelConfirmRevoke: String  { return L10n.tr("Localizable", "LinkInvation.Channel.Confirm.Revoke") }
  /// Revoke
  public static var linkInvationConfirmOk: String  { return L10n.tr("Localizable", "LinkInvation.Confirm.Ok") }
  /// Are you sure you want to revoke this link? Once you do, no one will be able to join the group using it.
  public static var linkInvationGroupConfirmRevoke: String  { return L10n.tr("Localizable", "LinkInvation.Group.Confirm.Revoke") }
  /// Sorry, this language doesn't seem to exist.
  public static var localizationPreviewErrorGeneric: String  { return L10n.tr("Localizable", "Localization.Preview.Error.Generic") }
  /// Accurate to %@
  public static func locationSendAccurateTo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Location.Send.AccurateTo", p1)
  }
  /// Hide nearby places
  public static var locationSendHideNearby: String  { return L10n.tr("Localizable", "Location.Send.HideNearby") }
  /// Locating...
  public static var locationSendLocating: String  { return L10n.tr("Localizable", "Location.Send.Locating") }
  /// Send My Current Location
  public static var locationSendMyLocation: String  { return L10n.tr("Localizable", "Location.Send.MyLocation") }
  /// Show nearby places
  public static var locationSendShowNearby: String  { return L10n.tr("Localizable", "Location.Send.ShowNearby") }
  /// Send This Location
  public static var locationSendThisLocation: String  { return L10n.tr("Localizable", "Location.Send.ThisLocation") }
  /// Location
  public static var locationSendTitle: String  { return L10n.tr("Localizable", "Location.Send.Title") }
  /// Unknown Location
  public static var locationSendThisLocationUnknown: String  { return L10n.tr("Localizable", "Location.Send.ThisLocation.Unknown") }
  /// code
  public static var loginCodePlaceholder: String  { return L10n.tr("Localizable", "Login.codePlaceholder") }
  /// Continue in English
  public static var loginContinueOnLanguage: String  { return L10n.tr("Localizable", "Login.ContinueOnLanguage") }
  /// country
  public static var loginCountryLabel: String  { return L10n.tr("Localizable", "Login.countryLabel") }
  /// Please enter the code you've just received in Telegram on your other device.
  public static var loginEnterCodeFromApp: String  { return L10n.tr("Localizable", "Login.EnterCodeFromApp") }
  /// You have enabled Two-Step Verification, your account is now protected with an additional password.
  public static var loginEnterPasswordDescription: String  { return L10n.tr("Localizable", "Login.EnterPasswordDescription") }
  /// Too many attempts, please try again later.
  public static var loginFloodWait: String  { return L10n.tr("Localizable", "Login.FloodWait") }
  /// Invalid Country Code
  public static var loginInvalidCountryCode: String  { return L10n.tr("Localizable", "Login.InvalidCountryCode") }
  /// Invalid first name. Please try again.
  public static var loginInvalidFirstNameError: String  { return L10n.tr("Localizable", "Login.InvalidFirstNameError") }
  /// Invalid last name. Please try again.
  public static var loginInvalidLastNameError: String  { return L10n.tr("Localizable", "Login.InvalidLastNameError") }
  /// We have sent you a code via SMS. Please enter it above.
  public static var loginJustSentSms: String  { return L10n.tr("Localizable", "Login.JustSentSms") }
  /// Next
  public static var loginNext: String  { return L10n.tr("Localizable", "Login.Next") }
  /// Forgot password?
  public static var loginPasswordForgot: String  { return L10n.tr("Localizable", "Login.PasswordForgot") }
  /// password
  public static var loginPasswordPlaceholder: String  { return L10n.tr("Localizable", "Login.passwordPlaceholder") }
  /// We’ve just called your number. Please enter the code above.
  public static var loginPhoneCalledCode: String  { return L10n.tr("Localizable", "Login.PhoneCalledCode") }
  /// Telegram dialed your number
  public static var loginPhoneDialed: String  { return L10n.tr("Localizable", "Login.PhoneDialed") }
  /// phone number
  public static var loginPhoneFieldPlaceholder: String  { return L10n.tr("Localizable", "Login.phoneFieldPlaceholder") }
  /// This account is already logged in from this app.
  public static var loginPhoneNumberAlreadyAuthorized: String  { return L10n.tr("Localizable", "Login.PhoneNumberAlreadyAuthorized") }
  /// This phone number isn't registered. If you don't have a Telegram account yet, please sign up with your mobile device.
  public static var loginPhoneNumberNotRegistred: String  { return L10n.tr("Localizable", "Login.PhoneNumberNotRegistred") }
  /// Since you haven't provided a recovery e-mail when setting up your password, your remaining options are either to remember your password or to reset your account.
  public static var loginRecoveryMailFailed: String  { return L10n.tr("Localizable", "Login.RecoveryMailFailed") }
  /// RESET
  public static var loginResetAccount: String  { return L10n.tr("Localizable", "Login.ResetAccount") }
  /// If you proceed with resetting your account, all of your chats and messages along with any media and files you shared, will be lost.
  public static var loginResetAccountDescription: String  { return L10n.tr("Localizable", "Login.ResetAccountDescription") }
  /// Reset Account
  public static var loginResetAccountText: String  { return L10n.tr("Localizable", "Login.ResetAccountText") }
  /// Haven't received the code?
  public static var loginSendSmsIfNotReceivedAppCode: String  { return L10n.tr("Localizable", "Login.SendSmsIfNotReceivedAppCode") }
  /// Welcome to the macOS application
  public static var loginWelcomeDescription: String  { return L10n.tr("Localizable", "Login.WelcomeDescription") }
  /// Telegram will call you in %d:%@
  public static func loginWillCall(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "Login.willCall", p1, p2)
  }
  /// Telegram will send you an SMS in %d:%@
  public static func loginWillSendSms(_ p1: Int, _ p2: String) -> String {
    return L10n.tr("Localizable", "Login.willSendSms", p1, p2)
  }
  /// your code
  public static var loginYourCodeLabel: String  { return L10n.tr("Localizable", "Login.YourCodeLabel") }
  /// your password
  public static var loginYourPasswordLabel: String  { return L10n.tr("Localizable", "Login.YourPasswordLabel") }
  /// your phone
  public static var loginYourPhoneLabel: String  { return L10n.tr("Localizable", "Login.YourPhoneLabel") }
  /// Can't reach server
  public static var loginConnectionErrorHeader: String  { return L10n.tr("Localizable", "Login.ConnectionError.Header") }
  /// Please check your internet connection and try again.
  public static var loginConnectionErrorInfo: String  { return L10n.tr("Localizable", "Login.ConnectionError.Info") }
  /// Try Again
  public static var loginConnectionErrorTryAgain: String  { return L10n.tr("Localizable", "Login.ConnectionError.TryAgain") }
  /// Use Proxy
  public static var loginConnectionErrorUseProxy: String  { return L10n.tr("Localizable", "Login.ConnectionError.UseProxy") }
  /// Enter Code
  public static var loginHeaderCode: String  { return L10n.tr("Localizable", "Login.Header.Code") }
  /// Enter Password
  public static var loginHeaderPassword: String  { return L10n.tr("Localizable", "Login.Header.Password") }
  /// Sign Up
  public static var loginHeaderSignUp: String  { return L10n.tr("Localizable", "Login.Header.SignUp") }
  /// Your phone was banned.
  public static var loginNewPhoneBannedError: String  { return L10n.tr("Localizable", "Login.New.PhoneBannedError") }
  /// Please confirm your country code and enter your phone number.
  public static var loginNewPhoneNumber: String  { return L10n.tr("Localizable", "Login.New.PhoneNumber") }
  /// Are you sure you want to cancel log in?
  public static var loginNewCancelConfirm: String  { return L10n.tr("Localizable", "Login.New.Cancel.Confirm") }
  /// We’ve just called\non your phone **%@** · [Edit]()
  public static func loginNewCodeCallInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Login.New.Code.CallInfo", p1)
  }
  /// We’ve sent the code to the Telegram app\nfor **%@** on your device · [Edit]()
  public static func loginNewCodeCodeInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Login.New.Code.CodeInfo", p1)
  }
  /// Check your Telegram messages
  public static var loginNewCodeEnterCode: String  { return L10n.tr("Localizable", "Login.New.Code.EnterCode") }
  /// Enter Code
  public static var loginNewCodeEnterSms: String  { return L10n.tr("Localizable", "Login.New.Code.EnterSms") }
  /// We’ve sent an SMS with an activation code\non your phone **%@** · [Edit]()
  public static func loginNewCodeSmsInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Login.New.Code.SmsInfo", p1)
  }
  /// Your remaining options are either to remember your password or to reset your account.
  public static var loginNewEmailAlert: String  { return L10n.tr("Localizable", "Login.New.Email.Alert") }
  /// Unable to access [%@]()?
  public static func loginNewEmailFooter(_ p1: String) -> String {
    return L10n.tr("Localizable", "Login.New.Email.Footer", p1)
  }
  /// Email code
  public static var loginNewEmailHeader: String  { return L10n.tr("Localizable", "Login.New.Email.Header") }
  /// Please check your email and enter the 6-digit code we’ve sent there to deactivate your cloud password.
  public static var loginNewEmailInfo: String  { return L10n.tr("Localizable", "Login.New.Email.Info") }
  /// Reset Account
  public static var loginNewEmailAlertReset: String  { return L10n.tr("Localizable", "Login.New.Email.Alert.Reset") }
  /// You have two-step verification enabled, so your account is protected with an additional password.
  public static var loginNewPasswordInfo: String  { return L10n.tr("Localizable", "Login.New.Password.Info") }
  /// Your Password
  public static var loginNewPasswordLabel: String  { return L10n.tr("Localizable", "Login.New.Password.Label") }
  /// Enter Password
  public static var loginNewPasswordPlaceholder: String  { return L10n.tr("Localizable", "Login.New.Password.Placeholder") }
  /// By signing up, you agree to the [Terms of Service]()
  public static var loginNewRegisterFooter: String  { return L10n.tr("Localizable", "Login.New.Register.Footer") }
  /// Profile Info
  public static var loginNewRegisterHeader: String  { return L10n.tr("Localizable", "Login.New.Register.Header") }
  /// Enter your name and add a profile picture
  public static var loginNewRegisterInfo: String  { return L10n.tr("Localizable", "Login.New.Register.Info") }
  /// Sign Up
  public static var loginNewRegisterNext: String  { return L10n.tr("Localizable", "Login.New.Register.Next") }
  /// Remove
  public static var loginNewRegisterRemove: String  { return L10n.tr("Localizable", "Login.New.Register.Remove") }
  /// Select
  public static var loginNewRegisterSelect: String  { return L10n.tr("Localizable", "Login.New.Register.Select") }
  /// You can reset your account right now.
  public static var loginNewResetAble: String  { return L10n.tr("Localizable", "Login.New.Reset.Able") }
  /// Reset
  public static var loginNewResetButton: String  { return L10n.tr("Localizable", "Login.New.Reset.Button") }
  /// Cancel Reset
  public static var loginNewResetCancelReset: String  { return L10n.tr("Localizable", "Login.New.Reset.CancelReset") }
  /// Reset Account
  public static var loginNewResetHeader: String  { return L10n.tr("Localizable", "Login.New.Reset.Header") }
  /// Since the account **%@** is active and protected by a password, it will be deleted in 1 week. This delay is required for security purposes.\n\n%@
  public static func loginNewResetInfo(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Login.New.Reset.Info", p1, p2)
  }
  /// You'll be able to reset your account in:
  public static var loginNewResetWhen: String  { return L10n.tr("Localizable", "Login.New.Reset.When") }
  /// You'll be able to reset your account in:
  public static var loginNewResetWillAble: String  { return L10n.tr("Localizable", "Login.New.Reset.WillAble") }
  /// Switch
  public static var loginPhoneNumberAlreadyAuthorizedSwitch: String  { return L10n.tr("Localizable", "Login.PhoneNumberAlreadyAuthorized.Switch") }
  /// Log in by phone Number
  public static var loginQRCancel: String  { return L10n.tr("Localizable", "Login.QR.Cancel") }
  /// Log in by QR Code
  public static var loginQRLogin: String  { return L10n.tr("Localizable", "Login.QR.Login") }
  /// Log in to Telegram by QR Code
  public static var loginQRTitle: String  { return L10n.tr("Localizable", "Login.QR.Title") }
  /// Open Telegram on your phone
  public static var loginQR1Help1: String  { return L10n.tr("Localizable", "Login.QR1.Help1") }
  /// Go to **Settings** → **Devices** → **Scan QR**
  public static var loginQR1Help2: String  { return L10n.tr("Localizable", "Login.QR1.Help2") }
  /// Point your phone at this screen to confirm login
  public static var loginQR1Help3: String  { return L10n.tr("Localizable", "Login.QR1.Help3") }
  /// Enter your name and add a profile picture.
  public static var loginRegisterDesc: String  { return L10n.tr("Localizable", "Login.Register.Desc") }
  /// add\nphoto
  public static var loginRegisterAddPhotoPlaceholder: String  { return L10n.tr("Localizable", "Login.Register.AddPhoto.Placeholder") }
  /// First Name
  public static var loginRegisterFirstNamePlaceholder: String  { return L10n.tr("Localizable", "Login.Register.FirstName.Placeholder") }
  /// Last Name
  public static var loginRegisterLastNamePlaceholder: String  { return L10n.tr("Localizable", "Login.Register.LastName.Placeholder") }
  /// If you already signed up for Telegram, please enter the code which was sent to your mobile app via Telegram.\n\nIf you haven’t signed up yet, please register from your phone or tablet first.
  public static var loginSmsAppErr: String  { return L10n.tr("Localizable", "Login.Sms.AppErr") }
  /// Open Site
  public static var loginSmsAppErrGotoSite: String  { return L10n.tr("Localizable", "Login.Sms.AppErr.GotoSite") }
  /// Set up multiple phone numbers and easily switch between them.
  public static var logoutOptionsAddAccountText: String  { return L10n.tr("Localizable", "LogoutOptions.AddAccountText") }
  /// Add another account
  public static var logoutOptionsAddAccountTitle: String  { return L10n.tr("Localizable", "LogoutOptions.AddAccountTitle") }
  /// ALTERNATIVE OPTIONS
  public static var logoutOptionsAlternativeOptionsSection: String  { return L10n.tr("Localizable", "LogoutOptions.AlternativeOptionsSection") }
  /// Move your contacts, groups, messages and media to a new number.
  public static var logoutOptionsChangePhoneNumberText: String  { return L10n.tr("Localizable", "LogoutOptions.ChangePhoneNumberText") }
  /// Change Phone Number
  public static var logoutOptionsChangePhoneNumberTitle: String  { return L10n.tr("Localizable", "LogoutOptions.ChangePhoneNumberTitle") }
  /// Free up disk space on your device; your media will stay in the cloud.
  public static var logoutOptionsClearCacheText: String  { return L10n.tr("Localizable", "LogoutOptions.ClearCacheText") }
  /// Clear Cache
  public static var logoutOptionsClearCacheTitle: String  { return L10n.tr("Localizable", "LogoutOptions.ClearCacheTitle") }
  /// Tell us about any issues; logging out doesn't usually help.
  public static var logoutOptionsContactSupportText: String  { return L10n.tr("Localizable", "LogoutOptions.ContactSupportText") }
  /// Contact Support
  public static var logoutOptionsContactSupportTitle: String  { return L10n.tr("Localizable", "LogoutOptions.ContactSupportTitle") }
  /// Log Out
  public static var logoutOptionsLogOut: String  { return L10n.tr("Localizable", "LogoutOptions.LogOut") }
  /// Remember, logging out kills all your Secret Chats.
  public static var logoutOptionsLogOutInfo: String  { return L10n.tr("Localizable", "LogoutOptions.LogOutInfo") }
  /// Lock the app with a passcode so that others can't open it.
  public static var logoutOptionsSetPasscodeText: String  { return L10n.tr("Localizable", "LogoutOptions.SetPasscodeText") }
  /// Set a Passcode
  public static var logoutOptionsSetPasscodeTitle: String  { return L10n.tr("Localizable", "LogoutOptions.SetPasscodeTitle") }
  /// Log out
  public static var logoutOptionsTitle: String  { return L10n.tr("Localizable", "LogoutOptions.Title") }
  /// ADDITION LINKS
  public static var manageLinksAdditionLinks: String  { return L10n.tr("Localizable", "ManageLinks.AdditionLinks") }
  /// Create a New Link
  public static var manageLinksCreateNew: String  { return L10n.tr("Localizable", "ManageLinks.CreateNew") }
  /// Delete
  public static var manageLinksDelete: String  { return L10n.tr("Localizable", "ManageLinks.Delete") }
  /// Delete All Revoked Links
  public static var manageLinksDeleteAll: String  { return L10n.tr("Localizable", "ManageLinks.DeleteAll") }
  /// You can create addition invite links that have limited time or numbers of usage.
  public static var manageLinksEmptyDesc: String  { return L10n.tr("Localizable", "ManageLinks.EmptyDesc") }
  /// INVITE LINK
  public static var manageLinksInviteLink: String  { return L10n.tr("Localizable", "ManageLinks.InviteLink") }
  /// INVITE LINKS CREATED BY OTHER ADMINS
  public static var manageLinksOtherAdmins: String  { return L10n.tr("Localizable", "ManageLinks.OtherAdmins") }
  /// PERMANENT LINK
  public static var manageLinksPermanent: String  { return L10n.tr("Localizable", "ManageLinks.Permanent") }
  /// REVOKED LINKS
  public static var manageLinksRevokedLinks: String  { return L10n.tr("Localizable", "ManageLinks.RevokedLinks") }
  /// %d
  public static func manageLinksTitleCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_countable", p1)
  }
  /// %d invite links
  public static func manageLinksTitleCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_few", p1)
  }
  /// %d invite links
  public static func manageLinksTitleCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_many", p1)
  }
  /// %d invite link
  public static func manageLinksTitleCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_one", p1)
  }
  /// %d invite links
  public static func manageLinksTitleCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_other", p1)
  }
  /// %d invite links
  public static func manageLinksTitleCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_two", p1)
  }
  /// %d invite links
  public static func manageLinksTitleCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ManageLinks.TitleCount_zero", p1)
  }
  /// Invite Links
  public static var manageLinksTitleNew: String  { return L10n.tr("Localizable", "ManageLinks.TitleNew") }
  /// **%1$@** can see this link and use it to invite new members to **%2$@** 
  public static func manageLinksAdminPermanentDesc(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "ManageLinks.Admin.Permanent.Desc", p1, p2)
  }
  /// Copy Link
  public static var manageLinksContextCopy: String  { return L10n.tr("Localizable", "ManageLinks.Context.Copy") }
  /// Edit Link
  public static var manageLinksContextEdit: String  { return L10n.tr("Localizable", "ManageLinks.Context.Edit") }
  /// Revoke Link
  public static var manageLinksContextRevoke: String  { return L10n.tr("Localizable", "ManageLinks.Context.Revoke") }
  /// Share Link
  public static var manageLinksContextShare: String  { return L10n.tr("Localizable", "ManageLinks.Context.Share") }
  /// Are you sure you want to delete all revoked links?
  public static var manageLinksDeleteAllConfirm: String  { return L10n.tr("Localizable", "ManageLinks.DeleteAll.Confirm") }
  /// Anyone who has Telegram installed will be able to join your channel by following this group
  public static var manageLinksHeaderChannelDesc: String  { return L10n.tr("Localizable", "ManageLinks.Header.Channel.Desc") }
  /// Anyone who has Telegram installed will be able to join your group by following this group
  public static var manageLinksHeaderGroupDesc: String  { return L10n.tr("Localizable", "ManageLinks.Header.Group.Desc") }
  /// FAKE
  public static var markFake: String  { return L10n.tr("Localizable", "Mark.Fake") }
  /// SCAM
  public static var markScam: String  { return L10n.tr("Localizable", "Mark.Scam") }
  /// Discard Changes
  public static var mediaSenderDiscardChangesHeader: String  { return L10n.tr("Localizable", "MediaSender.DiscardChanges.Header") }
  /// Discard
  public static var mediaSenderDiscardChangesOK: String  { return L10n.tr("Localizable", "MediaSender.DiscardChanges.OK") }
  /// Are you sure you want to discard all changes?
  public static var mediaSenderDiscardChangesText: String  { return L10n.tr("Localizable", "MediaSender.DiscardChanges.Text") }
  /// INVOICE
  public static var messageInvoiceLabel: String  { return L10n.tr("Localizable", "Message.InvoiceLabel") }
  /// Payment: %@
  public static func messagePaymentSent(_ p1: String) -> String {
    return L10n.tr("Localizable", "Message.PaymentSent", p1)
  }
  /// pinned an invoice
  public static var messagePinnedInvoice: String  { return L10n.tr("Localizable", "Message.PinnedInvoice") }
  /// Show Receipt
  public static var messageReplyActionButtonShowReceipt: String  { return L10n.tr("Localizable", "Message.ReplyActionButtonShowReceipt") }
  /// %d
  public static func messageAccessoryPanelForwardedCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_countable", p1)
  }
  /// %d forwarded messages
  public static func messageAccessoryPanelForwardedFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_few", p1)
  }
  /// %d forwarded messages
  public static func messageAccessoryPanelForwardedMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_many", p1)
  }
  /// %d forwarded message
  public static func messageAccessoryPanelForwardedOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_one", p1)
  }
  /// %d forwarded messages
  public static func messageAccessoryPanelForwardedOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_other", p1)
  }
  /// %d forwarded messages
  public static func messageAccessoryPanelForwardedTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_two", p1)
  }
  /// %d forwarded messages
  public static func messageAccessoryPanelForwardedZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.AccessoryPanel.Forwarded_zero", p1)
  }
  /// Delete
  public static var messageActionsPanelDelete: String  { return L10n.tr("Localizable", "Message.ActionsPanel.Delete") }
  /// Select messages
  public static var messageActionsPanelEmptySelected: String  { return L10n.tr("Localizable", "Message.ActionsPanel.EmptySelected") }
  /// Forward
  public static var messageActionsPanelForward: String  { return L10n.tr("Localizable", "Message.ActionsPanel.Forward") }
  /// %d
  public static func messageActionsPanelSelectedCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_countable", p1)
  }
  /// %d messages selected
  public static func messageActionsPanelSelectedCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_few", p1)
  }
  /// %d messages selected
  public static func messageActionsPanelSelectedCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_many", p1)
  }
  /// %d message selected
  public static func messageActionsPanelSelectedCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_one", p1)
  }
  /// %d messages selected
  public static func messageActionsPanelSelectedCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_other", p1)
  }
  /// %d messages selected
  public static func messageActionsPanelSelectedCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_two", p1)
  }
  /// %d messages selected
  public static func messageActionsPanelSelectedCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.ActionsPanel.SelectedCount_zero", p1)
  }
  /// Delete
  public static var messageContextDelete: String  { return L10n.tr("Localizable", "Message.Context.Delete") }
  /// Edit
  public static var messageContextEdit: String  { return L10n.tr("Localizable", "Message.Context.Edit") }
  /// Forward
  public static var messageContextForward: String  { return L10n.tr("Localizable", "Message.Context.Forward") }
  /// Forward to Saved Messages
  public static var messageContextForwardToCloud: String  { return L10n.tr("Localizable", "Message.Context.ForwardToCloud") }
  /// Show Message
  public static var messageContextGoto: String  { return L10n.tr("Localizable", "Message.Context.Goto") }
  /// Open With...
  public static var messageContextOpenWith: String  { return L10n.tr("Localizable", "Message.Context.OpenWith") }
  /// Pin
  public static var messageContextPin: String  { return L10n.tr("Localizable", "Message.Context.Pin") }
  /// Remove GIF
  public static var messageContextRemoveGif: String  { return L10n.tr("Localizable", "Message.Context.RemoveGif") }
  /// Reply
  public static var messageContextReply1: String  { return L10n.tr("Localizable", "Message.Context.Reply1") }
  /// double click
  public static var messageContextReplyHelp: String  { return L10n.tr("Localizable", "Message.Context.ReplyHelp") }
  /// Report
  public static var messageContextReport: String  { return L10n.tr("Localizable", "Message.Context.Report") }
  /// Add GIF
  public static var messageContextSaveGif: String  { return L10n.tr("Localizable", "Message.Context.SaveGif") }
  /// Select
  public static var messageContextSelect: String  { return L10n.tr("Localizable", "Message.Context.Select") }
  /// Share
  public static var messageContextShare: String  { return L10n.tr("Localizable", "Message.Context.Share") }
  /// Unpin
  public static var messageContextUnpin: String  { return L10n.tr("Localizable", "Message.Context.Unpin") }
  /// %d
  public static func messageContextViewCommentsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_countable", p1)
  }
  /// View %d Comments
  public static func messageContextViewCommentsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_few", p1)
  }
  /// View %d Comments
  public static func messageContextViewCommentsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_many", p1)
  }
  /// View %d Comment
  public static func messageContextViewCommentsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_one", p1)
  }
  /// View %d Comments
  public static func messageContextViewCommentsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_other", p1)
  }
  /// View %d Comments
  public static func messageContextViewCommentsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_two", p1)
  }
  /// View %d Comments
  public static func messageContextViewCommentsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewComments_zero", p1)
  }
  /// %d
  public static func messageContextViewRepliesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_countable", p1)
  }
  /// View %d Replies
  public static func messageContextViewRepliesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_few", p1)
  }
  /// View %d Replies
  public static func messageContextViewRepliesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_many", p1)
  }
  /// View %d Reply
  public static func messageContextViewRepliesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_one", p1)
  }
  /// View %d Replies
  public static func messageContextViewRepliesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_other", p1)
  }
  /// View %d Replies
  public static func messageContextViewRepliesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_two", p1)
  }
  /// View %d Replies
  public static func messageContextViewRepliesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Context.ViewReplies_zero", p1)
  }
  /// View Thread
  public static var messageContextViewThread: String  { return L10n.tr("Localizable", "Message.Context.ViewThread") }
  /// Notify all members
  public static var messageContextConfirmNotifyPin: String  { return L10n.tr("Localizable", "Message.Context.Confirm.NotifyPin") }
  /// Would you like to pin this message?
  public static var messageContextConfirmPin1: String  { return L10n.tr("Localizable", "Message.Context.Confirm.Pin1") }
  /// Thank you! Your report will be reviewed by our team very soon.
  public static var messageContextReportAlertOK: String  { return L10n.tr("Localizable", "Message.Context.Report.AlertOK") }
  /// Edit Message...
  public static var messagePlaceholderEdit: String  { return L10n.tr("Localizable", "Message.Placeholder.Edit") }
  /// archived folder
  public static var messageStatusArchived: String  { return L10n.tr("Localizable", "Message.Status.Archived") }
  /// preparing archive
  public static var messageStatusArchivePreparing: String  { return L10n.tr("Localizable", "Message.Status.ArchivePreparing") }
  /// %d%% archiving
  public static func messageStatusArchiving(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Message.Status.Archiving", p1)
  }
  /// archivation failed
  public static var messageStatusArchiveFailed: String  { return L10n.tr("Localizable", "Message.Status.Archive.Failed") }
  /// file size limit exceeded
  public static var messageStatusArchiveFailedSizeLimit: String  { return L10n.tr("Localizable", "Message.Status.Archive.FailedSizeLimit") }
  /// Copy Music Name
  public static var messageTextCopyMusicTitle: String  { return L10n.tr("Localizable", "Message.Text.CopyMusicTitle") }
  /// Copy Message Link
  public static var messageContextCopyMessageLink1: String  { return L10n.tr("Localizable", "MessageContext.CopyMessageLink1") }
  /// %@d
  public static func messageTimerShortDays(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortDays", p1)
  }
  /// %@h
  public static func messageTimerShortHours(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortHours", p1)
  }
  /// %@m
  public static func messageTimerShortMinutes(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortMinutes", p1)
  }
  /// %@M
  public static func messageTimerShortMonths(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortMonths", p1)
  }
  /// %@s
  public static func messageTimerShortSeconds(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortSeconds", p1)
  }
  /// %@w
  public static func messageTimerShortWeeks(_ p1: String) -> String {
    return L10n.tr("Localizable", "MessageTimer.ShortWeeks", p1)
  }
  /// Deleted message
  public static var messagesDeletedMessage: String  { return L10n.tr("Localizable", "Messages.DeletedMessage") }
  /// Forwarded messages
  public static var messagesForwardHeader: String  { return L10n.tr("Localizable", "Messages.ForwardHeader") }
  /// Unread messages
  public static var messagesUnreadMark: String  { return L10n.tr("Localizable", "Messages.UnreadMark") }
  /// %d%% downloaded
  public static func messagesFileStateFetchingIn1(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Messages.File.State.FetchingIn_1", p1)
  }
  /// %d%% uploaded
  public static func messagesFileStateFetchingOut1(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Messages.File.State.FetchingOut_1", p1)
  }
  /// Show in Finder
  public static var messagesFileStateLocal: String  { return L10n.tr("Localizable", "Messages.File.State.Local") }
  /// Download
  public static var messagesFileStateRemote: String  { return L10n.tr("Localizable", "Messages.File.State.Remote") }
  /// Send Anonymously...
  public static var messagesPlaceholderAnonymous: String  { return L10n.tr("Localizable", "Messages.Placeholder.Anonymous") }
  /// Broadcast...
  public static var messagesPlaceholderBroadcast: String  { return L10n.tr("Localizable", "Messages.Placeholder.Broadcast") }
  /// Comment...
  public static var messagesPlaceholderComment: String  { return L10n.tr("Localizable", "Messages.Placeholder.Comment") }
  /// Reply...
  public static var messagesPlaceholderReply: String  { return L10n.tr("Localizable", "Messages.Placeholder.Reply") }
  /// Write a message...
  public static var messagesPlaceholderSentMessage: String  { return L10n.tr("Localizable", "Messages.Placeholder.SentMessage") }
  /// Silent Broadcast...
  public static var messagesPlaceholderSilentBroadcast: String  { return L10n.tr("Localizable", "Messages.Placeholder.SilentBroadcast") }
  /// Broadcast...
  public static var messagesPlaceholderBroadcastSmall: String  { return L10n.tr("Localizable", "Messages.Placeholder.Broadcast.Small") }
  /// Message...
  public static var messagesPlaceholderSentMessageSmall: String  { return L10n.tr("Localizable", "Messages.Placeholder.SentMessage.Small") }
  /// Reply
  public static var messagesReplyLoadingHeader: String  { return L10n.tr("Localizable", "Messages.ReplyLoading.Header") }
  /// Loading...
  public static var messagesReplyLoadingLoading: String  { return L10n.tr("Localizable", "Messages.ReplyLoading.Loading") }
  /// Apply
  public static var modalApply: String  { return L10n.tr("Localizable", "Modal.Apply") }
  /// Cancel
  public static var modalCancel: String  { return L10n.tr("Localizable", "Modal.Cancel") }
  /// Copy Link
  public static var modalCopyLink: String  { return L10n.tr("Localizable", "Modal.CopyLink") }
  /// Done
  public static var modalDone: String  { return L10n.tr("Localizable", "Modal.Done") }
  /// Not Now
  public static var modalNotNow: String  { return L10n.tr("Localizable", "Modal.NotNow") }
  /// OK
  public static var modalOK: String  { return L10n.tr("Localizable", "Modal.OK") }
  /// Report
  public static var modalReport: String  { return L10n.tr("Localizable", "Modal.Report") }
  /// Save
  public static var modalSave: String  { return L10n.tr("Localizable", "Modal.Save") }
  /// Send
  public static var modalSend: String  { return L10n.tr("Localizable", "Modal.Send") }
  /// Set
  public static var modalSet: String  { return L10n.tr("Localizable", "Modal.Set") }
  /// Share
  public static var modalShare: String  { return L10n.tr("Localizable", "Modal.Share") }
  /// YES
  public static var modalYes: String  { return L10n.tr("Localizable", "Modal.Yes") }
  /// Add
  public static var navigationAdd: String  { return L10n.tr("Localizable", "Navigation.Add") }
  /// Back
  public static var navigationBack: String  { return L10n.tr("Localizable", "Navigation.back") }
  /// Cancel
  public static var navigationCancel: String  { return L10n.tr("Localizable", "Navigation.Cancel") }
  /// Close
  public static var navigationClose: String  { return L10n.tr("Localizable", "Navigation.Close") }
  /// Done
  public static var navigationDone: String  { return L10n.tr("Localizable", "Navigation.Done") }
  /// Edit
  public static var navigationEdit: String  { return L10n.tr("Localizable", "Navigation.Edit") }
  /// Next
  public static var navigationNext: String  { return L10n.tr("Localizable", "Navigation.Next") }
  /// Bytes Received
  public static var networkUsageBytesReceived: String  { return L10n.tr("Localizable", "NetworkUsage.BytesReceived") }
  /// Bytes Sent
  public static var networkUsageBytesSent: String  { return L10n.tr("Localizable", "NetworkUsage.BytesSent") }
  /// Network Usage
  public static var networkUsageNetworkUsage: String  { return L10n.tr("Localizable", "NetworkUsage.NetworkUsage") }
  /// Network usage since %@
  public static func networkUsageNetworkUsageSince(_ p1: String) -> String {
    return L10n.tr("Localizable", "NetworkUsage.NetworkUsageSince", p1)
  }
  /// Reset Statistics
  public static var networkUsageReset: String  { return L10n.tr("Localizable", "NetworkUsage.Reset") }
  /// AUDIO
  public static var networkUsageHeaderAudio: String  { return L10n.tr("Localizable", "NetworkUsage.Header.Audio") }
  /// FILES
  public static var networkUsageHeaderFiles: String  { return L10n.tr("Localizable", "NetworkUsage.Header.Files") }
  /// MESSAGES
  public static var networkUsageHeaderGeneric: String  { return L10n.tr("Localizable", "NetworkUsage.Header.Generic") }
  /// PHOTOS
  public static var networkUsageHeaderImages: String  { return L10n.tr("Localizable", "NetworkUsage.Header.Images") }
  /// VIDEOS
  public static var networkUsageHeaderVideos: String  { return L10n.tr("Localizable", "NetworkUsage.Header.Videos") }
  /// phone number
  public static var newContactPhone: String  { return L10n.tr("Localizable", "NewContact.Phone") }
  /// New Contact
  public static var newContactTitle: String  { return L10n.tr("Localizable", "NewContact.Title") }
  /// Share My Phone Number
  public static var newContactExceptionShareMyPhoneNumber: String  { return L10n.tr("Localizable", "NewContact.Exception.ShareMyPhoneNumber") }
  /// You can make your phone visible to %@.
  public static func newContactExceptionShareMyPhoneNumberDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "NewContact.Exception.ShareMyPhoneNumber.Desc", p1)
  }
  /// Hidden
  public static var newContactPhoneHidden: String  { return L10n.tr("Localizable", "NewContact.Phone.Hidden") }
  /// Phone number will be **visible** once %@ adds you as a contact.
  public static func newContactPhoneHiddenText(_ p1: String) -> String {
    return L10n.tr("Localizable", "NewContact.Phone.Hidden.Text", p1)
  }
  /// Anonymous Voting
  public static var newPollAnonymous: String  { return L10n.tr("Localizable", "NewPoll.Anonymous") }
  /// Are you sure you want to discard this poll?
  public static var newPollDisacardConfirm: String  { return L10n.tr("Localizable", "NewPoll.DisacardConfirm") }
  /// Poll
  public static var newPollDisacardConfirmHeader: String  { return L10n.tr("Localizable", "NewPoll.DisacardConfirmHeader") }
  /// Multiple Choice
  public static var newPollMultipleChoice: String  { return L10n.tr("Localizable", "NewPoll.MultipleChoice") }
  /// Add an Option
  public static var newPollOptionsAddOption: String  { return L10n.tr("Localizable", "NewPoll.OptionsAddOption") }
  /// %d
  public static func newPollOptionsDescriptionCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_countable", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_few", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_many", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_one", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_other", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_two", p1)
  }
  /// You can add %d more options
  public static func newPollOptionsDescriptionZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescription_zero", p1)
  }
  /// You have added the maximum number of options.
  public static var newPollOptionsDescriptionLimitReached: String  { return L10n.tr("Localizable", "NewPoll.OptionsDescriptionLimitReached") }
  /// %d
  public static func newPollOptionsDescriptionMinimumCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_countable", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_few", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_many", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_one", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_other", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_two", p1)
  }
  /// Minimum %d options
  public static func newPollOptionsDescriptionMinimumZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.OptionsDescriptionMinimum_zero", p1)
  }
  /// POLL OPTIONS
  public static var newPollOptionsHeader: String  { return L10n.tr("Localizable", "NewPoll.OptionsHeader") }
  /// Option
  public static var newPollOptionsPlaceholder: String  { return L10n.tr("Localizable", "NewPoll.OptionsPlaceholder") }
  /// QUESTION
  public static var newPollQuestionHeader: String  { return L10n.tr("Localizable", "NewPoll.QuestionHeader") }
  /// QUESTION (%d)
  public static func newPollQuestionHeaderLimit(_ p1: Int) -> String {
    return L10n.tr("Localizable", "NewPoll.QuestionHeaderLimit", p1)
  }
  /// Ask a question
  public static var newPollQuestionPlaceholder: String  { return L10n.tr("Localizable", "NewPoll.QuestionPlaceholder") }
  /// Quiz Mode
  public static var newPollQuiz: String  { return L10n.tr("Localizable", "NewPoll.Quiz") }
  /// Quiz has only one right answer. You can't revoke their votes.
  public static var newPollQuizDesc: String  { return L10n.tr("Localizable", "NewPoll.QuizDesc") }
  /// Select the correct option
  public static var newPollQuizTooltip: String  { return L10n.tr("Localizable", "NewPoll.QuizTooltip") }
  /// New Poll
  public static var newPollTitle: String  { return L10n.tr("Localizable", "NewPoll.Title") }
  /// No
  public static var newPollDisacardConfirmNo: String  { return L10n.tr("Localizable", "NewPoll.DisacardConfirm.No") }
  /// Discard
  public static var newPollDisacardConfirmYes: String  { return L10n.tr("Localizable", "NewPoll.DisacardConfirm.Yes") }
  /// Users will see this comment after choosing a wrong answer, good for educational purposes.
  public static var newPollExplanationDesc: String  { return L10n.tr("Localizable", "NewPoll.Explanation.Desc") }
  /// EXPLANATION
  public static var newPollExplanationHeader: String  { return L10n.tr("Localizable", "NewPoll.Explanation.Header") }
  /// Add a Comment (Optional)
  public static var newPollExplanationPlaceholder: String  { return L10n.tr("Localizable", "NewPoll.Explanation.Placeholder") }
  /// A quiz has one correct answer.
  public static var newPollQuizMultipleError: String  { return L10n.tr("Localizable", "NewPoll.QuizMultiple.Error") }
  /// New Quiz
  public static var newPollTitleQuiz: String  { return L10n.tr("Localizable", "NewPoll.Title.Quiz") }
  /// Create
  public static var newThemeCreate: String  { return L10n.tr("Localizable", "NewTheme.Create") }
  /// This theme will be based on your current theme.
  public static var newThemeDesc: String  { return L10n.tr("Localizable", "NewTheme.Desc") }
  /// name can't be empty.
  public static var newThemeEmptyTextError: String  { return L10n.tr("Localizable", "NewTheme.EmptyTextError") }
  /// Theme name
  public static var newThemePlaceholder: String  { return L10n.tr("Localizable", "NewTheme.Placeholder") }
  /// New Theme
  public static var newThemeTitle: String  { return L10n.tr("Localizable", "NewTheme.Title") }
  /// You have a new message
  public static var notificationLockedPreview: String  { return L10n.tr("Localizable", "Notification.LockedPreview") }
  /// Mark as Read
  public static var notificationMarkAsRead: String  { return L10n.tr("Localizable", "Notification.MarkAsRead") }
  /// %1$@ is now within %2$@ from %3$@
  public static func notificationProximityReached1(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Notification.ProximityReached_1", p1, p2, p3)
  }
  /// %1$@ is now within %2$@ from you
  public static func notificationProximityReachedYou1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Notification.ProximityReachedYou_1", p1, p2)
  }
  /// You are now within %1$@ from %2$@
  public static func notificationProximityYouReached1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Notification.ProximityYouReached_1", p1, p2)
  }
  /// 📆 Reminder
  public static var notificationReminder: String  { return L10n.tr("Localizable", "Notification.Reminder") }
  /// Reply
  public static var notificationReply: String  { return L10n.tr("Localizable", "Notification.Reply") }
  /// %1$@ to your "%2$@"
  public static func notificationContactReacted(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Notification.Contact.Reacted", p1, p2)
  }
  /// %1$@: %2$@ to your "%3$@"
  public static func notificationGroupReacted(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Notification.Group.Reacted", p1, p2, p3)
  }
  /// Type message...
  public static var notificationInputReply: String  { return L10n.tr("Localizable", "Notification.Input.Reply") }
  /// Reply
  public static var notificationTitleReply: String  { return L10n.tr("Localizable", "Notification.Title.Reply") }
  /// All Accounts
  public static var notificationSettingsAllAccounts: String  { return L10n.tr("Localizable", "NotificationSettings.AllAccounts") }
  /// Switch off to show the number of unread chats instead of messages.
  public static var notificationSettingsBadgeDesc: String  { return L10n.tr("Localizable", "NotificationSettings.BadgeDesc") }
  /// Enabled
  public static var notificationSettingsBadgeEnabled: String  { return L10n.tr("Localizable", "NotificationSettings.BadgeEnabled") }
  /// BADGE COUNTER
  public static var notificationSettingsBadgeHeader: String  { return L10n.tr("Localizable", "NotificationSettings.BadgeHeader") }
  /// Bounce Dock Icon
  public static var notificationSettingsBounceDockIcon: String  { return L10n.tr("Localizable", "NotificationSettings.BounceDockIcon") }
  /// New Contacts
  public static var notificationSettingsContactJoined: String  { return L10n.tr("Localizable", "NotificationSettings.ContactJoined") }
  /// Receive notifications when one of your contacts becomes available on Telegram.
  public static var notificationSettingsContactJoinedInfo: String  { return L10n.tr("Localizable", "NotificationSettings.ContactJoinedInfo") }
  /// Count Unread Messages
  public static var notificationSettingsCountUnreadMessages: String  { return L10n.tr("Localizable", "NotificationSettings.CountUnreadMessages") }
  /// Include Channels
  public static var notificationSettingsIncludeChannels: String  { return L10n.tr("Localizable", "NotificationSettings.IncludeChannels") }
  /// Include Groups
  public static var notificationSettingsIncludeGroups: String  { return L10n.tr("Localizable", "NotificationSettings.IncludeGroups") }
  /// Include Muted Chats
  public static var notificationSettingsIncludeMutedChats: String  { return L10n.tr("Localizable", "NotificationSettings.IncludeMutedChats") }
  /// Message Preview
  public static var notificationSettingsMessagesPreview: String  { return L10n.tr("Localizable", "NotificationSettings.MessagesPreview") }
  /// Notification Tone
  public static var notificationSettingsNotificationTone: String  { return L10n.tr("Localizable", "NotificationSettings.NotificationTone") }
  /// Reset Notifications
  public static var notificationSettingsResetNotifications: String  { return L10n.tr("Localizable", "NotificationSettings.ResetNotifications") }
  /// You can set custom notifications for specific chats below.
  public static var notificationSettingsResetNotificationsText: String  { return L10n.tr("Localizable", "NotificationSettings.ResetNotificationsText") }
  /// Sent Message
  public static var notificationSettingsSendMessageEffect: String  { return L10n.tr("Localizable", "NotificationSettings.SendMessageEffect") }
  /// SHOW NOTIFICATIONS FROM
  public static var notificationSettingsShowNotificationsFrom: String  { return L10n.tr("Localizable", "NotificationSettings.ShowNotificationsFrom") }
  /// App is in Focus
  public static var notificationSettingsSnoof: String  { return L10n.tr("Localizable", "NotificationSettings.Snoof") }
  /// SHOW NOTIFICATIONS WHEN
  public static var notificationSettingsSnoofHeader: String  { return L10n.tr("Localizable", "NotificationSettings.SnoofHeader") }
  /// SOUND EFFECTS
  public static var notificationSettingsSoundEffects: String  { return L10n.tr("Localizable", "NotificationSettings.SoundEffects") }
  /// Notifications
  public static var notificationSettingsToggleNotifications: String  { return L10n.tr("Localizable", "NotificationSettings.ToggleNotifications") }
  /// Allow in System Settings
  public static var notificationSettingsTurnOn: String  { return L10n.tr("Localizable", "NotificationSettings.TurnOn") }
  /// Reset notifications
  public static var notificationSettingsConfirmReset: String  { return L10n.tr("Localizable", "NotificationSettings.Confirm.Reset") }
  /// Turn this on if you want to receive notifications from all your accounts.
  public static var notificationSettingsShowNotificationsFromOff: String  { return L10n.tr("Localizable", "NotificationSettings.ShowNotificationsFrom.Off") }
  /// Turn this off if you want to receive notifications only from your active account.
  public static var notificationSettingsShowNotificationsFromOn: String  { return L10n.tr("Localizable", "NotificationSettings.ShowNotificationsFrom.On") }
  /// Turn this on if you want to always receive notifications.
  public static var notificationSettingsSnoofOff: String  { return L10n.tr("Localizable", "NotificationSettings.Snoof.Off") }
  /// Turn this off if you want to receive notifications only when application is not in focus.
  public static var notificationSettingsSnoofOn: String  { return L10n.tr("Localizable", "NotificationSettings.Snoof.On") }
  /// NOTIFICATIONS
  public static var notificationSettingsToggleNotificationsHeader: String  { return L10n.tr("Localizable", "NotificationSettings.ToggleNotifications.Header") }
  /// Default
  public static var notificationSettingsToneDefault: String  { return L10n.tr("Localizable", "NotificationSettings.Tone.Default") }
  /// Don't miss important messages from your family and friends.
  public static var notificationSettingsTurnOnTextText: String  { return L10n.tr("Localizable", "NotificationSettings.TurnOn.Text.Text") }
  /// Allow Notifications
  public static var notificationSettingsTurnOnTextTitle: String  { return L10n.tr("Localizable", "NotificationSettings.TurnOn.Text.Title") }
  /// Mute
  public static var notificationsSnooze: String  { return L10n.tr("Localizable", "Notifications.Snooze") }
  /// Alert
  public static var notificationsSoundAlert: String  { return L10n.tr("Localizable", "NotificationsSound.Alert") }
  /// Aurora
  public static var notificationsSoundAurora: String  { return L10n.tr("Localizable", "NotificationsSound.Aurora") }
  /// Bamboo
  public static var notificationsSoundBamboo: String  { return L10n.tr("Localizable", "NotificationsSound.Bamboo") }
  /// Bell
  public static var notificationsSoundBell: String  { return L10n.tr("Localizable", "NotificationsSound.Bell") }
  /// Calypso
  public static var notificationsSoundCalypso: String  { return L10n.tr("Localizable", "NotificationsSound.Calypso") }
  /// Chime
  public static var notificationsSoundChime: String  { return L10n.tr("Localizable", "NotificationsSound.Chime") }
  /// Chord
  public static var notificationsSoundChord: String  { return L10n.tr("Localizable", "NotificationsSound.Chord") }
  /// Circles
  public static var notificationsSoundCircles: String  { return L10n.tr("Localizable", "NotificationsSound.Circles") }
  /// Complete
  public static var notificationsSoundComplete: String  { return L10n.tr("Localizable", "NotificationsSound.Complete") }
  /// Glass
  public static var notificationsSoundGlass: String  { return L10n.tr("Localizable", "NotificationsSound.Glass") }
  /// Hello
  public static var notificationsSoundHello: String  { return L10n.tr("Localizable", "NotificationsSound.Hello") }
  /// Input
  public static var notificationsSoundInput: String  { return L10n.tr("Localizable", "NotificationsSound.Input") }
  /// Keys
  public static var notificationsSoundKeys: String  { return L10n.tr("Localizable", "NotificationsSound.Keys") }
  /// None
  public static var notificationsSoundNone: String  { return L10n.tr("Localizable", "NotificationsSound.None") }
  /// Note
  public static var notificationsSoundNote: String  { return L10n.tr("Localizable", "NotificationsSound.Note") }
  /// Popcorn
  public static var notificationsSoundPopcorn: String  { return L10n.tr("Localizable", "NotificationsSound.Popcorn") }
  /// Pulse
  public static var notificationsSoundPulse: String  { return L10n.tr("Localizable", "NotificationsSound.Pulse") }
  /// Synth
  public static var notificationsSoundSynth: String  { return L10n.tr("Localizable", "NotificationsSound.Synth") }
  /// Telegraph
  public static var notificationsSoundTelegraph: String  { return L10n.tr("Localizable", "NotificationsSound.Telegraph") }
  /// Tremolo
  public static var notificationsSoundTremolo: String  { return L10n.tr("Localizable", "NotificationsSound.Tremolo") }
  /// Tri-tone
  public static var notificationsSoundTritone: String  { return L10n.tr("Localizable", "NotificationsSound.Tritone") }
  /// Minimize
  public static var oy7WFPoVTitle: String  { return L10n.tr("Localizable", "OY7-WF-poV.title") }
  /// Hide
  public static var olwNPBQNTitle: String  { return L10n.tr("Localizable", "Olw-nP-bQN.title") }
  /// Auto-Lock
  public static var passcodeAutolock: String  { return L10n.tr("Localizable", "Passcode.Autolock") }
  /// Change passcode
  public static var passcodeChange: String  { return L10n.tr("Localizable", "Passcode.Change") }
  /// Enter your current passcode
  public static var passcodeEnterCurrentPlaceholder: String  { return L10n.tr("Localizable", "Passcode.EnterCurrentPlaceholder") }
  /// Enter the new passcode
  public static var passcodeEnterNewPlaceholder: String  { return L10n.tr("Localizable", "Passcode.EnterNewPlaceholder") }
  /// Enter your passcode
  public static var passcodeEnterPasscodePlaceholder: String  { return L10n.tr("Localizable", "Passcode.EnterPasscodePlaceholder") }
  /// Next
  public static var passcodeNext: String  { return L10n.tr("Localizable", "Passcode.Next") }
  /// or
  public static var passcodeOr: String  { return L10n.tr("Localizable", "Passcode.Or") }
  /// Re-enter the passcode
  public static var passcodeReEnterPlaceholder: String  { return L10n.tr("Localizable", "Passcode.ReEnterPlaceholder") }
  /// Turn Passcode Off
  public static var passcodeTurnOff: String  { return L10n.tr("Localizable", "Passcode.TurnOff") }
  /// Turn Passcode On
  public static var passcodeTurnOn: String  { return L10n.tr("Localizable", "Passcode.TurnOn") }
  /// When you set up an additional passcode, you can use ⌘ + L for lock.\n\nNote: if you forget the passcode, you'll need to delete and reinstall the app. All secret chats will be lost.
  public static var passcodeTurnOnDescription: String  { return L10n.tr("Localizable", "Passcode.TurnOnDescription") }
  /// unlock itself
  public static var passcodeUnlockTouchIdReason: String  { return L10n.tr("Localizable", "Passcode.UnlockTouchIdReason") }
  /// Unlock with Touch ID
  public static var passcodeUseTouchId: String  { return L10n.tr("Localizable", "Passcode.UseTouchId") }
  /// Disabled
  public static var passcodeAutoLockDisabled: String  { return L10n.tr("Localizable", "Passcode.AutoLock.Disabled") }
  /// If away for %@
  public static func passcodeAutoLockIfAway(_ p1: String) -> String {
    return L10n.tr("Localizable", "Passcode.AutoLock.IfAway", p1)
  }
  /// If you don't remember your passcode, you can [log out]()
  public static var passcodeLostDescription: String  { return L10n.tr("Localizable", "Passcode.Lost.Description") }
  /// When a local passcode is set, a lock button is appears in quick settings menu. Just hover settings icon in tab bar or use ⌘ + L.\n\nNote: if you forget your local passcode you'll need to log out of Telegram Macos and log in again.
  public static var passcodeControllerText: String  { return L10n.tr("Localizable", "PasscodeController.Text") }
  /// Change Passcode
  public static var passcodeControllerChangeTitle: String  { return L10n.tr("Localizable", "PasscodeController.Change.Title") }
  /// Enter current passcode
  public static var passcodeControllerCurrentPlaceholder: String  { return L10n.tr("Localizable", "PasscodeController.Current.Placeholder") }
  /// Disable Passcode
  public static var passcodeControllerDisableTitle: String  { return L10n.tr("Localizable", "PasscodeController.Disable.Title") }
  /// Enter a passcode
  public static var passcodeControllerEnterPasscodePlaceholder: String  { return L10n.tr("Localizable", "PasscodeController.EnterPasscode.Placeholder") }
  /// invalid passcode
  public static var passcodeControllerErrorCurrent: String  { return L10n.tr("Localizable", "PasscodeController.Error.Current") }
  /// passcodes are different
  public static var passcodeControllerErrorDifferent: String  { return L10n.tr("Localizable", "PasscodeController.Error.Different") }
  /// CURRENT PASSCODE
  public static var passcodeControllerHeaderCurrent: String  { return L10n.tr("Localizable", "PasscodeController.Header.Current") }
  /// NEW PASSCODE
  public static var passcodeControllerHeaderNew: String  { return L10n.tr("Localizable", "PasscodeController.Header.New") }
  /// Passcode
  public static var passcodeControllerInstallTitle: String  { return L10n.tr("Localizable", "PasscodeController.Install.Title") }
  /// Re-enter new passcode
  public static var passcodeControllerReEnterPasscodePlaceholder: String  { return L10n.tr("Localizable", "PasscodeController.ReEnterPasscode.Placeholder") }
  /// Enter Your Passcode
  public static var passlockEnterYourPasscode: String  { return L10n.tr("Localizable", "Passlock.EnterYourPasscode") }
  /// Arabic
  public static var passportLanguageAr: String  { return L10n.tr("Localizable", "Passport.Language.ar") }
  /// Azerbaijani
  public static var passportLanguageAz: String  { return L10n.tr("Localizable", "Passport.Language.az") }
  /// Bulgarian
  public static var passportLanguageBg: String  { return L10n.tr("Localizable", "Passport.Language.bg") }
  /// Bangla
  public static var passportLanguageBn: String  { return L10n.tr("Localizable", "Passport.Language.bn") }
  /// Czech
  public static var passportLanguageCs: String  { return L10n.tr("Localizable", "Passport.Language.cs") }
  /// Danish
  public static var passportLanguageDa: String  { return L10n.tr("Localizable", "Passport.Language.da") }
  /// German
  public static var passportLanguageDe: String  { return L10n.tr("Localizable", "Passport.Language.de") }
  /// Divehi
  public static var passportLanguageDv: String  { return L10n.tr("Localizable", "Passport.Language.dv") }
  /// Dzongkha
  public static var passportLanguageDz: String  { return L10n.tr("Localizable", "Passport.Language.dz") }
  /// Greek
  public static var passportLanguageEl: String  { return L10n.tr("Localizable", "Passport.Language.el") }
  /// English
  public static var passportLanguageEn: String  { return L10n.tr("Localizable", "Passport.Language.en") }
  /// Spanish
  public static var passportLanguageEs: String  { return L10n.tr("Localizable", "Passport.Language.es") }
  /// Estonian
  public static var passportLanguageEt: String  { return L10n.tr("Localizable", "Passport.Language.et") }
  /// Persian
  public static var passportLanguageFa: String  { return L10n.tr("Localizable", "Passport.Language.fa") }
  /// French
  public static var passportLanguageFr: String  { return L10n.tr("Localizable", "Passport.Language.fr") }
  /// Hebrew
  public static var passportLanguageHe: String  { return L10n.tr("Localizable", "Passport.Language.he") }
  /// Croatian
  public static var passportLanguageHr: String  { return L10n.tr("Localizable", "Passport.Language.hr") }
  /// Hungarian
  public static var passportLanguageHu: String  { return L10n.tr("Localizable", "Passport.Language.hu") }
  /// Armenian
  public static var passportLanguageHy: String  { return L10n.tr("Localizable", "Passport.Language.hy") }
  /// Indonesian
  public static var passportLanguageId: String  { return L10n.tr("Localizable", "Passport.Language.id") }
  /// Icelandic
  public static var passportLanguageIs: String  { return L10n.tr("Localizable", "Passport.Language.is") }
  /// Italian
  public static var passportLanguageIt: String  { return L10n.tr("Localizable", "Passport.Language.it") }
  /// Japanese
  public static var passportLanguageJa: String  { return L10n.tr("Localizable", "Passport.Language.ja") }
  /// Georgian
  public static var passportLanguageKa: String  { return L10n.tr("Localizable", "Passport.Language.ka") }
  /// Khmer
  public static var passportLanguageKm: String  { return L10n.tr("Localizable", "Passport.Language.km") }
  /// Korean
  public static var passportLanguageKo: String  { return L10n.tr("Localizable", "Passport.Language.ko") }
  /// Lao
  public static var passportLanguageLo: String  { return L10n.tr("Localizable", "Passport.Language.lo") }
  /// Lithuanian
  public static var passportLanguageLt: String  { return L10n.tr("Localizable", "Passport.Language.lt") }
  /// Latvian
  public static var passportLanguageLv: String  { return L10n.tr("Localizable", "Passport.Language.lv") }
  /// Macedonian
  public static var passportLanguageMk: String  { return L10n.tr("Localizable", "Passport.Language.mk") }
  /// Mongolian
  public static var passportLanguageMn: String  { return L10n.tr("Localizable", "Passport.Language.mn") }
  /// Malay
  public static var passportLanguageMs: String  { return L10n.tr("Localizable", "Passport.Language.ms") }
  /// Burmese
  public static var passportLanguageMy: String  { return L10n.tr("Localizable", "Passport.Language.my") }
  /// Nepali
  public static var passportLanguageNe: String  { return L10n.tr("Localizable", "Passport.Language.ne") }
  /// Dutch
  public static var passportLanguageNl: String  { return L10n.tr("Localizable", "Passport.Language.nl") }
  /// Polish
  public static var passportLanguagePl: String  { return L10n.tr("Localizable", "Passport.Language.pl") }
  /// Portuguese
  public static var passportLanguagePt: String  { return L10n.tr("Localizable", "Passport.Language.pt") }
  /// Romanian
  public static var passportLanguageRo: String  { return L10n.tr("Localizable", "Passport.Language.ro") }
  /// Russian
  public static var passportLanguageRu: String  { return L10n.tr("Localizable", "Passport.Language.ru") }
  /// Slovak
  public static var passportLanguageSk: String  { return L10n.tr("Localizable", "Passport.Language.sk") }
  /// Slovenian
  public static var passportLanguageSl: String  { return L10n.tr("Localizable", "Passport.Language.sl") }
  /// Thai
  public static var passportLanguageTh: String  { return L10n.tr("Localizable", "Passport.Language.th") }
  /// Turkmen
  public static var passportLanguageTk: String  { return L10n.tr("Localizable", "Passport.Language.tk") }
  /// Turkish
  public static var passportLanguageTr: String  { return L10n.tr("Localizable", "Passport.Language.tr") }
  /// Ukrainian
  public static var passportLanguageUk: String  { return L10n.tr("Localizable", "Passport.Language.uk") }
  /// Uzbek
  public static var passportLanguageUz: String  { return L10n.tr("Localizable", "Passport.Language.uz") }
  /// Vietnamese
  public static var passportLanguageVi: String  { return L10n.tr("Localizable", "Passport.Language.vi") }
  /// Forgotten Password
  public static var passportResetPasswordConfirmHeader: String  { return L10n.tr("Localizable", "Passport.ResetPassword.Confirm.Header") }
  /// Reset
  public static var passportResetPasswordConfirmOK: String  { return L10n.tr("Localizable", "Passport.ResetPassword.Confirm.OK") }
  /// All documents uploaded to your Telegram Passport will be lost. You will be able to upload new documents.
  public static var passportResetPasswordConfirmText: String  { return L10n.tr("Localizable", "Passport.ResetPassword.Confirm.Text") }
  /// You paid %1$@ to %2$@
  public static func paymentsPaid(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Payments.Paid", p1, p2)
  }
  /// Tip (Optional)
  public static var paymentsTipLabel: String  { return L10n.tr("Localizable", "Payments.TipLabel") }
  /// Sorry, Telegram for macOS doesn't support payments yet. Please use one of our mobile apps to do this.
  public static var paymentsUnsupported: String  { return L10n.tr("Localizable", "Payments.Unsupported") }
  /// Neither Telegram nor %1$@ will have access to your credit card information. Credit card details will be handled only by the payments system, %2$@.\n\n Payments will go directly to the developer of %3$@. Telegram cannot provide any guarantees, so proceed at your own risk. In case of problems, please contact the developer of %4$@ or your bank.
  public static func paymentsWarningText(_ p1: String, _ p2: String, _ p3: String, _ p4: String) -> String {
    return L10n.tr("Localizable", "Payments.WarningText", p1, p2, p3, p4)
  }
  /// Warning
  public static var paymentsWarninTitle: String  { return L10n.tr("Localizable", "Payments.WarninTitle") }
  /// Tip
  public static var paymentsReceiptTip: String  { return L10n.tr("Localizable", "Payments.Receipt.Tip") }
  /// Deleted Account
  public static var peerDeletedUser: String  { return L10n.tr("Localizable", "Peer.DeletedUser") }
  /// Replies Notifications
  public static var peerRepliesNotifications: String  { return L10n.tr("Localizable", "Peer.RepliesNotifications") }
  /// Saved Messages
  public static var peerSavedMessages: String  { return L10n.tr("Localizable", "Peer.SavedMessages") }
  /// Service Notifications
  public static var peerServiceNotifications: String  { return L10n.tr("Localizable", "Peer.ServiceNotifications") }
  /// %@ is choosing sticker
  public static func peerActivityChatChoosingSticker(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.ChoosingSticker", p1)
  }
  /// %@ is enjoying %@ animations
  public static func peerActivityChatEnjoyingAnimations(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.EnjoyingAnimations", p1, p2)
  }
  /// %@ is playing a game
  public static func peerActivityChatPlayingGame(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.PlayingGame", p1)
  }
  /// %@ is recording voice
  public static func peerActivityChatRecordingAudio(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.RecordingAudio", p1)
  }
  /// %@ is recording video
  public static func peerActivityChatRecordingVideo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.RecordingVideo", p1)
  }
  /// %@ is sending file
  public static func peerActivityChatSendingFile(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.SendingFile", p1)
  }
  /// %@ is sending photo
  public static func peerActivityChatSendingPhoto(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.SendingPhoto", p1)
  }
  /// %@ is sending video
  public static func peerActivityChatSendingVideo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.SendingVideo", p1)
  }
  /// %@ is typing
  public static func peerActivityChatTypingText(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.TypingText", p1)
  }
  /// %@ and %d others are choosing stickers
  public static func peerActivityChatMultiChoosingSticker1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.ChoosingSticker1", p1, p2)
  }
  /// %@ and %d others are playing a games
  public static func peerActivityChatMultiPlayingGame1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.PlayingGame1", p1, p2)
  }
  /// %@ and %d others are recording voice
  public static func peerActivityChatMultiRecordingAudio1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.RecordingAudio1", p1, p2)
  }
  /// %@ and %d others are recording video
  public static func peerActivityChatMultiRecordingVideo1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.RecordingVideo1", p1, p2)
  }
  /// %@ and %d others are sending audio
  public static func peerActivityChatMultiSendingAudio1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.SendingAudio1", p1, p2)
  }
  /// %@ and %d others are sending files
  public static func peerActivityChatMultiSendingFile1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.SendingFile1", p1, p2)
  }
  /// %@ and %d others are sending photos
  public static func peerActivityChatMultiSendingPhoto1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.SendingPhoto1", p1, p2)
  }
  /// %@ and %d others are sending videos
  public static func peerActivityChatMultiSendingVideo1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.SendingVideo1", p1, p2)
  }
  /// %@ and %d others are typing
  public static func peerActivityChatMultiTypingText1(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Peer.Activity.Chat.Multi.TypingText1", p1, p2)
  }
  /// choosing sticker
  public static var peerActivityUserChoosingSticker: String  { return L10n.tr("Localizable", "Peer.Activity.User.ChoosingSticker") }
  /// enjoying %@ animations
  public static func peerActivityUserEnjoyingAnimations(_ p1: String) -> String {
    return L10n.tr("Localizable", "Peer.Activity.User.EnjoyingAnimations", p1)
  }
  /// playing a game
  public static var peerActivityUserPlayingGame: String  { return L10n.tr("Localizable", "Peer.Activity.User.PlayingGame") }
  /// recording voice
  public static var peerActivityUserRecordingAudio: String  { return L10n.tr("Localizable", "Peer.Activity.User.RecordingAudio") }
  /// recording video
  public static var peerActivityUserRecordingVideo: String  { return L10n.tr("Localizable", "Peer.Activity.User.RecordingVideo") }
  /// sending file
  public static var peerActivityUserSendingFile: String  { return L10n.tr("Localizable", "Peer.Activity.User.SendingFile") }
  /// sending a photo
  public static var peerActivityUserSendingPhoto: String  { return L10n.tr("Localizable", "Peer.Activity.User.SendingPhoto") }
  /// sending a video
  public static var peerActivityUserSendingVideo: String  { return L10n.tr("Localizable", "Peer.Activity.User.SendingVideo") }
  /// typing
  public static var peerActivityUserTypingText: String  { return L10n.tr("Localizable", "Peer.Activity.User.TypingText") }
  /// Remove photo
  public static var peerCreatePeerContextRemovePhoto: String  { return L10n.tr("Localizable", "Peer.CreatePeer.Context.RemovePhoto") }
  /// Update photo
  public static var peerCreatePeerContextUpdatePhoto: String  { return L10n.tr("Localizable", "Peer.CreatePeer.Context.UpdatePhoto") }
  /// You can send and receive files of any type up to 2.0 GB each and access them anywhere.
  public static var peerMediaSharedFilesEmptyList1: String  { return L10n.tr("Localizable", "Peer.Media.SharedFilesEmptyList1") }
  /// All links shared in this chat will appear here.
  public static var peerMediaSharedLinksEmptyList: String  { return L10n.tr("Localizable", "Peer.Media.SharedLinksEmptyList") }
  /// Share photos and videos in this chat - or this paperclip stays unhappy.
  public static var peerMediaSharedMediaEmptyList: String  { return L10n.tr("Localizable", "Peer.Media.SharedMediaEmptyList") }
  /// All music shared in this chat will appear here.
  public static var peerMediaSharedMusicEmptyList: String  { return L10n.tr("Localizable", "Peer.Media.SharedMusicEmptyList") }
  /// All voice and video messages shared in this chat will appear here.
  public static var peerMediaSharedVoiceEmptyList: String  { return L10n.tr("Localizable", "Peer.Media.SharedVoiceEmptyList") }
  /// %d
  public static func peerMediaCalendarMediaCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_countable", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_few", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_many", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_one", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_other", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_two", p1)
  }
  /// %d media
  public static func peerMediaCalendarMediaZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Media.Calendar.Media_zero", p1)
  }
  /// Calendar
  public static var peerMediaCalendarTitle: String  { return L10n.tr("Localizable", "Peer.Media.Calendar.Title") }
  /// channel
  public static var peerStatusChannel: String  { return L10n.tr("Localizable", "Peer.Status.channel") }
  /// group
  public static var peerStatusGroup: String  { return L10n.tr("Localizable", "Peer.Status.group") }
  /// last seen just now
  public static var peerStatusJustNow: String  { return L10n.tr("Localizable", "Peer.Status.justNow") }
  /// last seen within a month
  public static var peerStatusLastMonth: String  { return L10n.tr("Localizable", "Peer.Status.lastMonth") }
  /// last seen %@ at %@
  public static func peerStatusLastSeenAt(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Peer.Status.LastSeenAt", p1, p2)
  }
  /// last seen within a week
  public static var peerStatusLastWeek: String  { return L10n.tr("Localizable", "Peer.Status.lastWeek") }
  /// last seen a long time ago
  public static var peerStatusLongTimeAgo: String  { return L10n.tr("Localizable", "Peer.Status.longTimeAgo") }
  /// %d
  public static func peerStatusMemberCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_countable", p1)
  }
  /// %d members
  public static func peerStatusMemberFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_few", p1)
  }
  /// %d members
  public static func peerStatusMemberMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_many", p1)
  }
  /// %d member
  public static func peerStatusMemberOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_one", p1)
  }
  /// %d members
  public static func peerStatusMemberOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_other", p1)
  }
  /// %d members
  public static func peerStatusMemberTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_two", p1)
  }
  /// %d members
  public static func peerStatusMemberZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member_zero", p1)
  }
  /// %d
  public static func peerStatusMinAgoCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_countable", p1)
  }
  /// last seen %d minutes ago
  public static func peerStatusMinAgoFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_few", p1)
  }
  /// last seen %d minutes ago
  public static func peerStatusMinAgoMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_many", p1)
  }
  /// last seen %d minute ago
  public static func peerStatusMinAgoOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_one", p1)
  }
  /// last seen %d minutes ago
  public static func peerStatusMinAgoOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_other", p1)
  }
  /// last seen %d minutes ago
  public static func peerStatusMinAgoTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_two", p1)
  }
  /// last seen %d minutes ago
  public static func peerStatusMinAgoZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.minAgo_zero", p1)
  }
  /// online
  public static var peerStatusOnline: String  { return L10n.tr("Localizable", "Peer.Status.online") }
  /// last seen recently
  public static var peerStatusRecently: String  { return L10n.tr("Localizable", "Peer.Status.recently") }
  /// %d
  public static func peerStatusSubscribersCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_countable", p1)
  }
  /// %d subscribers
  public static func peerStatusSubscribersFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_few", p1)
  }
  /// %d subscribers
  public static func peerStatusSubscribersMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_many", p1)
  }
  /// %d subscriber
  public static func peerStatusSubscribersOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_one", p1)
  }
  /// %d subscribers
  public static func peerStatusSubscribersOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_other", p1)
  }
  /// %d subscribers
  public static func peerStatusSubscribersTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_two", p1)
  }
  /// %d subscribers
  public static func peerStatusSubscribersZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Subscribers_zero", p1)
  }
  /// today
  public static var peerStatusToday: String  { return L10n.tr("Localizable", "Peer.Status.Today") }
  /// yesterday
  public static var peerStatusYesterday: String  { return L10n.tr("Localizable", "Peer.Status.Yesterday") }
  /// %d
  public static func peerStatusMemberOnlineCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_countable", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_few", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_many", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_one", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_other", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_two", p1)
  }
  /// %d online
  public static func peerStatusMemberOnlineZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Peer.Status.Member.Online_zero", p1)
  }
  /// about
  public static var peerInfoAbout: String  { return L10n.tr("Localizable", "PeerInfo.about") }
  /// Add Contact
  public static var peerInfoAddContact: String  { return L10n.tr("Localizable", "PeerInfo.AddContact") }
  /// Add Members
  public static var peerInfoAddMember: String  { return L10n.tr("Localizable", "PeerInfo.AddMember") }
  /// Add %@ to Contacts
  public static func peerInfoAddUserToContact(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.AddUserToContact", p1)
  }
  /// Administrators
  public static var peerInfoAdministrators: String  { return L10n.tr("Localizable", "PeerInfo.Administrators") }
  /// admin
  public static var peerInfoAdminLabel: String  { return L10n.tr("Localizable", "PeerInfo.AdminLabel") }
  /// bio
  public static var peerInfoBio: String  { return L10n.tr("Localizable", "PeerInfo.bio") }
  /// Removed Users
  public static var peerInfoBlackList: String  { return L10n.tr("Localizable", "PeerInfo.BlackList") }
  /// Block User
  public static var peerInfoBlockUser: String  { return L10n.tr("Localizable", "PeerInfo.BlockUser") }
  /// Thank you! Your report will be reviewed by our team soon.
  public static var peerInfoChannelReported: String  { return L10n.tr("Localizable", "PeerInfo.ChannelReported") }
  /// Channel Type
  public static var peerInfoChannelType: String  { return L10n.tr("Localizable", "PeerInfo.ChannelType") }
  /// Change Colors
  public static var peerInfoChatColors: String  { return L10n.tr("Localizable", "PeerInfo.ChatColors") }
  /// Convert To Supergroup
  public static var peerInfoConvertToSupergroup: String  { return L10n.tr("Localizable", "PeerInfo.ConvertToSupergroup") }
  /// Delete and Exit
  public static var peerInfoDeleteAndExit: String  { return L10n.tr("Localizable", "PeerInfo.DeleteAndExit") }
  /// Delete Channel
  public static var peerInfoDeleteChannel: String  { return L10n.tr("Localizable", "PeerInfo.DeleteChannel") }
  /// Delete Contact
  public static var peerInfoDeleteContact: String  { return L10n.tr("Localizable", "PeerInfo.DeleteContact") }
  /// Delete Group
  public static var peerInfoDeleteGroup: String  { return L10n.tr("Localizable", "PeerInfo.DeleteGroup") }
  /// Delete Secret Chat
  public static var peerInfoDeleteSecretChat: String  { return L10n.tr("Localizable", "PeerInfo.DeleteSecretChat") }
  /// Discussion
  public static var peerInfoDiscussion: String  { return L10n.tr("Localizable", "PeerInfo.Discussion") }
  /// Encryption Key
  public static var peerInfoEncryptionKey: String  { return L10n.tr("Localizable", "PeerInfo.EncryptionKey") }
  /// fake
  public static var peerInfoFake: String  { return L10n.tr("Localizable", "PeerInfo.fake") }
  /// ⚠️ Warning: Many users reported that this account impersonates a famous person or organization.
  public static var peerInfoFakeWarning: String  { return L10n.tr("Localizable", "PeerInfo.FakeWarning") }
  /// Groups In Common
  public static var peerInfoGroupsInCommon: String  { return L10n.tr("Localizable", "PeerInfo.GroupsInCommon") }
  /// Group Type
  public static var peerInfoGroupType: String  { return L10n.tr("Localizable", "PeerInfo.GroupType") }
  /// info
  public static var peerInfoInfo: String  { return L10n.tr("Localizable", "PeerInfo.info") }
  /// Invite Link
  public static var peerInfoInviteLink: String  { return L10n.tr("Localizable", "PeerInfo.InviteLink") }
  /// Invite Links
  public static var peerInfoInviteLinks: String  { return L10n.tr("Localizable", "PeerInfo.InviteLinks") }
  /// Leave Channel
  public static var peerInfoLeaveChannel: String  { return L10n.tr("Localizable", "PeerInfo.LeaveChannel") }
  /// Leave Group
  public static var peerInfoLeaveGroup: String  { return L10n.tr("Localizable", "PeerInfo.LeaveGroup") }
  /// Linked Channel
  public static var peerInfoLinkedChannel: String  { return L10n.tr("Localizable", "PeerInfo.LinkedChannel") }
  /// Members
  public static var peerInfoMembers: String  { return L10n.tr("Localizable", "PeerInfo.Members") }
  /// %d
  public static func peerInfoMembersHeaderCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_countable", p1)
  }
  /// %d MEMBERS
  public static func peerInfoMembersHeaderFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_few", p1)
  }
  /// %d MEMBERS
  public static func peerInfoMembersHeaderMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_many", p1)
  }
  /// %d MEMBER
  public static func peerInfoMembersHeaderOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_one", p1)
  }
  /// %d MEMBERS
  public static func peerInfoMembersHeaderOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_other", p1)
  }
  /// %d MEMBERS
  public static func peerInfoMembersHeaderTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_two", p1)
  }
  /// %d MEMBERS
  public static func peerInfoMembersHeaderZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.MembersHeader_zero", p1)
  }
  /// Member Requests
  public static var peerInfoMembersRequest: String  { return L10n.tr("Localizable", "PeerInfo.MembersRequest") }
  /// Notifications
  public static var peerInfoNotifications: String  { return L10n.tr("Localizable", "PeerInfo.Notifications") }
  /// Default
  public static var peerInfoNotificationsDefault: String  { return L10n.tr("Localizable", "PeerInfo.NotificationsDefault") }
  /// Default (%@)
  public static func peerInfoNotificationsDefaultSound(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.NotificationsDefaultSound", p1)
  }
  /// Permissions
  public static var peerInfoPermissions: String  { return L10n.tr("Localizable", "PeerInfo.Permissions") }
  /// phone
  public static var peerInfoPhone: String  { return L10n.tr("Localizable", "PeerInfo.Phone") }
  /// Chat History For New Members
  public static var peerInfoPreHistory: String  { return L10n.tr("Localizable", "PeerInfo.PreHistory") }
  /// Reactions
  public static var peerInfoReactions: String  { return L10n.tr("Localizable", "PeerInfo.Reactions") }
  /// Removed Users
  public static var peerInfoRemovedUsers: String  { return L10n.tr("Localizable", "PeerInfo.RemovedUsers") }
  /// Report
  public static var peerInfoReport: String  { return L10n.tr("Localizable", "PeerInfo.Report") }
  /// Restart Bot
  public static var peerInfoRestartBot: String  { return L10n.tr("Localizable", "PeerInfo.RestartBot") }
  /// scam
  public static var peerInfoScam: String  { return L10n.tr("Localizable", "PeerInfo.scam") }
  /// ⚠️ Warning: Many users reported this account as a scam. Please be careful, especially if it asks you for money.
  public static var peerInfoScamWarning: String  { return L10n.tr("Localizable", "PeerInfo.ScamWarning") }
  /// Send Message
  public static var peerInfoSendMessage: String  { return L10n.tr("Localizable", "PeerInfo.SendMessage") }
  /// You can provide an optional description for your group.
  public static var peerInfoSetAboutDescription: String  { return L10n.tr("Localizable", "PeerInfo.SetAboutDescription") }
  /// Set Channel Photo
  public static var peerInfoSetChannelPhoto: String  { return L10n.tr("Localizable", "PeerInfo.SetChannelPhoto") }
  /// Set Group Photo
  public static var peerInfoSetGroupPhoto: String  { return L10n.tr("Localizable", "PeerInfo.SetGroupPhoto") }
  /// Group Sticker Set
  public static var peerInfoSetGroupStickersSet: String  { return L10n.tr("Localizable", "PeerInfo.SetGroupStickersSet") }
  /// Share Contact
  public static var peerInfoShareContact: String  { return L10n.tr("Localizable", "PeerInfo.ShareContact") }
  /// Shared Media
  public static var peerInfoSharedMedia: String  { return L10n.tr("Localizable", "PeerInfo.SharedMedia") }
  /// share link
  public static var peerInfoSharelink: String  { return L10n.tr("Localizable", "PeerInfo.sharelink") }
  /// Share My Contact Info
  public static var peerInfoShareMyInfo: String  { return L10n.tr("Localizable", "PeerInfo.ShareMyInfo") }
  /// Show More
  public static var peerInfoShowMore: String  { return L10n.tr("Localizable", "PeerInfo.ShowMore") }
  /// [more]()
  public static var peerInfoShowMoreText: String  { return L10n.tr("Localizable", "PeerInfo.ShowMoreText") }
  /// Sign Messages
  public static var peerInfoSignMessages: String  { return L10n.tr("Localizable", "PeerInfo.SignMessages") }
  /// Start Secret Chat
  public static var peerInfoStartSecretChat: String  { return L10n.tr("Localizable", "PeerInfo.StartSecretChat") }
  /// Stop Bot
  public static var peerInfoStopBot: String  { return L10n.tr("Localizable", "PeerInfo.StopBot") }
  /// Subscribers
  public static var peerInfoSubscribers: String  { return L10n.tr("Localizable", "PeerInfo.Subscribers") }
  /// Unarchive
  public static var peerInfoUnarchive: String  { return L10n.tr("Localizable", "PeerInfo.Unarchive") }
  /// Unblock User
  public static var peerInfoUnblockUser: String  { return L10n.tr("Localizable", "PeerInfo.UnblockUser") }
  /// username
  public static var peerInfoUsername: String  { return L10n.tr("Localizable", "PeerInfo.username") }
  /// Description
  public static var peerInfoAboutPlaceholder: String  { return L10n.tr("Localizable", "PeerInfo.About.Placeholder") }
  /// Add
  public static var peerInfoActionAddMembers: String  { return L10n.tr("Localizable", "PeerInfo.Action.AddMembers") }
  /// Call
  public static var peerInfoActionCall: String  { return L10n.tr("Localizable", "PeerInfo.Action.Call") }
  /// Discuss
  public static var peerInfoActionDiscussion: String  { return L10n.tr("Localizable", "PeerInfo.Action.Discussion") }
  /// Leave
  public static var peerInfoActionLeave: String  { return L10n.tr("Localizable", "PeerInfo.Action.Leave") }
  /// Live Stream
  public static var peerInfoActionLiveStream: String  { return L10n.tr("Localizable", "PeerInfo.Action.LiveStream") }
  /// Message
  public static var peerInfoActionMessage: String  { return L10n.tr("Localizable", "PeerInfo.Action.Message") }
  /// More
  public static var peerInfoActionMore: String  { return L10n.tr("Localizable", "PeerInfo.Action.More") }
  /// Mute
  public static var peerInfoActionMute: String  { return L10n.tr("Localizable", "PeerInfo.Action.Mute") }
  /// Report
  public static var peerInfoActionReport: String  { return L10n.tr("Localizable", "PeerInfo.Action.Report") }
  /// Secret
  public static var peerInfoActionSecretChat: String  { return L10n.tr("Localizable", "PeerInfo.Action.SecretChat") }
  /// Share
  public static var peerInfoActionShare: String  { return L10n.tr("Localizable", "PeerInfo.Action.Share") }
  /// Statistics
  public static var peerInfoActionStatistics: String  { return L10n.tr("Localizable", "PeerInfo.Action.Statistics") }
  /// Unmute
  public static var peerInfoActionUnmute: String  { return L10n.tr("Localizable", "PeerInfo.Action.Unmute") }
  /// Video
  public static var peerInfoActionVideoCall: String  { return L10n.tr("Localizable", "PeerInfo.Action.VideoCall") }
  /// Voice Chat
  public static var peerInfoActionVoiceChat: String  { return L10n.tr("Localizable", "PeerInfo.Action.VoiceChat") }
  /// Block User
  public static var peerInfoBlockHeader: String  { return L10n.tr("Localizable", "PeerInfo.Block.Header") }
  /// Block
  public static var peerInfoBlockOK: String  { return L10n.tr("Localizable", "PeerInfo.Block.OK") }
  /// Do you want to block %@ from messaging and calling you on Telegram?
  public static func peerInfoBlockText(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Block.Text", p1)
  }
  /// Add To Group
  public static var peerInfoBotAddToGroup: String  { return L10n.tr("Localizable", "PeerInfo.Bot.AddToGroup") }
  /// Help
  public static var peerInfoBotHelp: String  { return L10n.tr("Localizable", "PeerInfo.Bot.Help") }
  /// Privacy
  public static var peerInfoBotPrivacy: String  { return L10n.tr("Localizable", "PeerInfo.Bot.Privacy") }
  /// Settings
  public static var peerInfoBotSettings: String  { return L10n.tr("Localizable", "PeerInfo.Bot.Settings") }
  /// Share
  public static var peerInfoBotShare: String  { return L10n.tr("Localizable", "PeerInfo.Bot.Share") }
  /// has access to messages
  public static var peerInfoBotStatusHasAccess: String  { return L10n.tr("Localizable", "PeerInfo.BotStatus.HasAccess") }
  /// has no access to messages
  public static var peerInfoBotStatusHasNoAccess: String  { return L10n.tr("Localizable", "PeerInfo.BotStatus.HasNoAccess") }
  /// Channel Name
  public static var peerInfoChannelNamePlaceholder: String  { return L10n.tr("Localizable", "PeerInfo.ChannelName.Placeholder") }
  /// Channel Name
  public static var peerInfoChannelTitlePleceholder: String  { return L10n.tr("Localizable", "PeerInfo.ChannelTitle.Pleceholder") }
  /// Add
  public static var peerInfoConfirmAdd: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.Add") }
  /// Add "%@" to the group?
  public static func peerInfoConfirmAddMember(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMember", p1)
  }
  /// %d
  public static func peerInfoConfirmAddMembers1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_countable", p1)
  }
  /// Add %d users to the group?
  public static func peerInfoConfirmAddMembers1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_few", p1)
  }
  /// Add %d users to the group?
  public static func peerInfoConfirmAddMembers1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_many", p1)
  }
  /// Add %d user to the group?
  public static func peerInfoConfirmAddMembers1One(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_one", p1)
  }
  /// Add %d users to the group?
  public static func peerInfoConfirmAddMembers1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_other", p1)
  }
  /// Add %d users to the group?
  public static func peerInfoConfirmAddMembers1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_two", p1)
  }
  /// Add %d users to the group?
  public static func peerInfoConfirmAddMembers1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.AddMembers1_zero", p1)
  }
  /// Clear
  public static var peerInfoConfirmClear: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.Clear") }
  /// Are you sure you want to delete all message history and leave "%@"?
  public static func peerInfoConfirmDeleteChat(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.DeleteChat", p1)
  }
  /// Are you sure you want to delete this contact?
  public static var peerInfoConfirmDeleteContact: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.DeleteContact") }
  /// Wait! Deleting this group will remove all members and all messages will be lost. Delete the group anyway?
  public static var peerInfoConfirmDeleteGroupConfirmation: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.DeleteGroupConfirmation") }
  /// Are you sure you want to delete chat?
  public static var peerInfoConfirmDeleteUserChat: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.DeleteUserChat") }
  /// Are you sure you want to leave this channel?
  public static var peerInfoConfirmLeaveChannel: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.LeaveChannel") }
  /// Are you sure you want to leave this group?
  public static var peerInfoConfirmLeaveGroup: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.LeaveGroup") }
  /// Remove "%@" from group?
  public static func peerInfoConfirmRemovePeer(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.RemovePeer", p1)
  }
  /// Are you sure you want to share your phone number with "%@"?
  public static func peerInfoConfirmShareInfo(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.ShareInfo", p1)
  }
  /// Are you sure you want to start a secret chat with "%@"?
  public static func peerInfoConfirmStartSecretChat(_ p1: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Confirm.StartSecretChat", p1)
  }
  /// Secret Chat
  public static var peerInfoConfirmSecretChatHeader: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.SecretChat.Header") }
  /// Start
  public static var peerInfoConfirmSecretChatOK: String  { return L10n.tr("Localizable", "PeerInfo.Confirm.SecretChat.OK") }
  /// Add
  public static var peerInfoDiscussionAdd: String  { return L10n.tr("Localizable", "PeerInfo.Discussion.Add") }
  /// Add group chat for comments.
  public static var peerInfoDiscussionDesc: String  { return L10n.tr("Localizable", "PeerInfo.Discussion.Desc") }
  /// First Name
  public static var peerInfoFirstNamePlaceholder: String  { return L10n.tr("Localizable", "PeerInfo.FirstName.Placeholder") }
  /// Auto-Delete Messages
  public static var peerInfoGroupAutoDeleteMessages: String  { return L10n.tr("Localizable", "PeerInfo.Group.AutoDeleteMessages") }
  /// Delete
  public static var peerInfoGroupMenuDelete: String  { return L10n.tr("Localizable", "PeerInfo.Group.Menu.Delete") }
  /// Promote
  public static var peerInfoGroupMenuPromote: String  { return L10n.tr("Localizable", "PeerInfo.Group.Menu.Promote") }
  /// Restrict
  public static var peerInfoGroupMenuRestrict: String  { return L10n.tr("Localizable", "PeerInfo.Group.Menu.Restrict") }
  /// Never
  public static var peerInfoGroupTimerNever: String  { return L10n.tr("Localizable", "PeerInfo.Group.Timer.Never") }
  /// Group Name
  public static var peerInfoGroupNamePlaceholder: String  { return L10n.tr("Localizable", "PeerInfo.GroupName.Placeholder") }
  /// Group Name
  public static var peerInfoGroupTitlePleceholder: String  { return L10n.tr("Localizable", "PeerInfo.GroupTitle.Pleceholder") }
  /// Private
  public static var peerInfoGroupTypePrivate: String  { return L10n.tr("Localizable", "PeerInfo.GroupType.Private") }
  /// Public
  public static var peerInfoGroupTypePublic: String  { return L10n.tr("Localizable", "PeerInfo.GroupType.Public") }
  /// Sorry, you must be in this user's Telegram contacts to add them to this group.\n\nThey can also join on their own if you send them an invite link.
  public static var peerInfoInviteErrorContactNeeded: String  { return L10n.tr("Localizable", "PeerInfo.InviteError.ContactNeeded") }
  /// Last Name
  public static var peerInfoLastNamePlaceholder: String  { return L10n.tr("Localizable", "PeerInfo.LastName.Placeholder") }
  /// Hidden
  public static var peerInfoPreHistoryHidden: String  { return L10n.tr("Localizable", "PeerInfo.PreHistory.Hidden") }
  /// Visible
  public static var peerInfoPreHistoryVisible: String  { return L10n.tr("Localizable", "PeerInfo.PreHistory.Visible") }
  /// All
  public static var peerInfoReactionsAll: String  { return L10n.tr("Localizable", "PeerInfo.Reactions.All") }
  /// Disabled
  public static var peerInfoReactionsDisabled: String  { return L10n.tr("Localizable", "PeerInfo.Reactions.Disabled") }
  /// %1$@/%2$@
  public static func peerInfoReactionsPart(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "PeerInfo.Reactions.Part", p1, p2)
  }
  /// Select Messages
  public static var peerInfoReportSelectMessages: String  { return L10n.tr("Localizable", "PeerInfo.Report.SelectMessages") }
  /// Append names of the admins to the messages they post.
  public static var peerInfoSignMessagesDesc: String  { return L10n.tr("Localizable", "PeerInfo.SignMessages.Desc") }
  /// Audio
  public static var peerMediaAudio: String  { return L10n.tr("Localizable", "PeerMedia.Audio") }
  /// Groups
  public static var peerMediaCommonGroups: String  { return L10n.tr("Localizable", "PeerMedia.CommonGroups") }
  /// Docs
  public static var peerMediaFiles: String  { return L10n.tr("Localizable", "PeerMedia.Files") }
  /// GIFs
  public static var peerMediaGifs: String  { return L10n.tr("Localizable", "PeerMedia.Gifs") }
  /// Links
  public static var peerMediaLinks: String  { return L10n.tr("Localizable", "PeerMedia.Links") }
  /// Media
  public static var peerMediaMedia: String  { return L10n.tr("Localizable", "PeerMedia.Media") }
  /// Members
  public static var peerMediaMembers: String  { return L10n.tr("Localizable", "PeerMedia.Members") }
  /// Music
  public static var peerMediaMusic: String  { return L10n.tr("Localizable", "PeerMedia.Music") }
  /// Shared Media
  public static var peerMediaSharedMedia: String  { return L10n.tr("Localizable", "PeerMedia.SharedMedia") }
  /// Voicemessages
  public static var peerMediaVoice: String  { return L10n.tr("Localizable", "PeerMedia.Voice") }
  /// Shared Audio
  public static var peerMediaPopoverSharedAudio: String  { return L10n.tr("Localizable", "PeerMedia.Popover.SharedAudio") }
  /// Shared Files
  public static var peerMediaPopoverSharedFiles: String  { return L10n.tr("Localizable", "PeerMedia.Popover.SharedFiles") }
  /// Shared Links
  public static var peerMediaPopoverSharedLinks: String  { return L10n.tr("Localizable", "PeerMedia.Popover.SharedLinks") }
  /// Shared Media
  public static var peerMediaPopoverSharedMedia: String  { return L10n.tr("Localizable", "PeerMedia.Popover.SharedMedia") }
  /// %d
  public static func peerMediaTitleSearchFilesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_countable", p1)
  }
  /// %d Files
  public static func peerMediaTitleSearchFilesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_few", p1)
  }
  /// %d Files
  public static func peerMediaTitleSearchFilesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_many", p1)
  }
  /// %d File
  public static func peerMediaTitleSearchFilesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_one", p1)
  }
  /// %d Files
  public static func peerMediaTitleSearchFilesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_other", p1)
  }
  /// %d Files
  public static func peerMediaTitleSearchFilesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_two", p1)
  }
  /// %d Files
  public static func peerMediaTitleSearchFilesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Files_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchGIFsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_countable", p1)
  }
  /// %d GIFs
  public static func peerMediaTitleSearchGIFsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_few", p1)
  }
  /// %d GIFs
  public static func peerMediaTitleSearchGIFsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_many", p1)
  }
  /// %d GIF
  public static func peerMediaTitleSearchGIFsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_one", p1)
  }
  /// %d GIFs
  public static func peerMediaTitleSearchGIFsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_other", p1)
  }
  /// %d GIFs
  public static func peerMediaTitleSearchGIFsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_two", p1)
  }
  /// %d GIFs
  public static func peerMediaTitleSearchGIFsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.GIFs_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchLinksCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_countable", p1)
  }
  /// %d Links
  public static func peerMediaTitleSearchLinksFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_few", p1)
  }
  /// %d Links
  public static func peerMediaTitleSearchLinksMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_many", p1)
  }
  /// %d Link
  public static func peerMediaTitleSearchLinksOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_one", p1)
  }
  /// %d Links
  public static func peerMediaTitleSearchLinksOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_other", p1)
  }
  /// %d Links
  public static func peerMediaTitleSearchLinksTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_two", p1)
  }
  /// %d Links
  public static func peerMediaTitleSearchLinksZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Links_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchMediaCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_countable", p1)
  }
  /// %d Medias
  public static func peerMediaTitleSearchMediaFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_few", p1)
  }
  /// %d Medias
  public static func peerMediaTitleSearchMediaMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_many", p1)
  }
  /// %d Media
  public static func peerMediaTitleSearchMediaOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_one", p1)
  }
  /// %d Medias
  public static func peerMediaTitleSearchMediaOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_other", p1)
  }
  /// %d Medias
  public static func peerMediaTitleSearchMediaTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_two", p1)
  }
  /// %d Media
  public static func peerMediaTitleSearchMediaZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Media_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchMusicCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_countable", p1)
  }
  /// %d Audios
  public static func peerMediaTitleSearchMusicFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_few", p1)
  }
  /// %d Audios
  public static func peerMediaTitleSearchMusicMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_many", p1)
  }
  /// %d Audio
  public static func peerMediaTitleSearchMusicOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_one", p1)
  }
  /// %d Audios
  public static func peerMediaTitleSearchMusicOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_other", p1)
  }
  /// %d Audios
  public static func peerMediaTitleSearchMusicTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_two", p1)
  }
  /// %d Audios
  public static func peerMediaTitleSearchMusicZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Music_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchPhotosCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_countable", p1)
  }
  /// %d Photos
  public static func peerMediaTitleSearchPhotosFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_few", p1)
  }
  /// %d Photos
  public static func peerMediaTitleSearchPhotosMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_many", p1)
  }
  /// %d Photo
  public static func peerMediaTitleSearchPhotosOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_one", p1)
  }
  /// %d Photos
  public static func peerMediaTitleSearchPhotosOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_other", p1)
  }
  /// %d Photos
  public static func peerMediaTitleSearchPhotosTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_two", p1)
  }
  /// %d Photos
  public static func peerMediaTitleSearchPhotosZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Photos_zero", p1)
  }
  /// %d
  public static func peerMediaTitleSearchVideosCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_countable", p1)
  }
  /// %d Videos
  public static func peerMediaTitleSearchVideosFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_few", p1)
  }
  /// %d Videos
  public static func peerMediaTitleSearchVideosMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_many", p1)
  }
  /// %d Video
  public static func peerMediaTitleSearchVideosOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_one", p1)
  }
  /// %d Videos
  public static func peerMediaTitleSearchVideosOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_other", p1)
  }
  /// %d Videos
  public static func peerMediaTitleSearchVideosTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_two", p1)
  }
  /// %d Videos
  public static func peerMediaTitleSearchVideosZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PeerMedia.Title.Search.Videos_zero", p1)
  }
  /// Invite to Group via Link
  public static var peerSelectInviteViaLink: String  { return L10n.tr("Localizable", "PeerSelect.InviteViaLink") }
  /// Sorry, public polls can’t be forwarded to channels.
  public static var pollForwardError: String  { return L10n.tr("Localizable", "Poll.Forward.Error") }
  /// [Collapse]()
  public static var pollResultsCollapse: String  { return L10n.tr("Localizable", "PollResults.Collapse") }
  /// %d
  public static func pollResultsLoadMoreCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_countable", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_few", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_many", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_one", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_other", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_two", p1)
  }
  /// Show More (%d)
  public static func pollResultsLoadMoreZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PollResults.LoadMore_zero", p1)
  }
  /// Poll Results
  public static var pollResultsTitlePoll: String  { return L10n.tr("Localizable", "PollResults.Title.Poll") }
  /// Quiz Results
  public static var pollResultsTitleQuiz: String  { return L10n.tr("Localizable", "PollResults.Title.Quiz") }
  /// Warning, this will unlink the group from "%@"
  public static func preHistoryConfirmUnlink(_ p1: String) -> String {
    return L10n.tr("Localizable", "PreHistory.Confirm.Unlink", p1)
  }
  /// CHAT HISTORY FOR NEW MEMBERS
  public static var preHistorySettingsHeader: String  { return L10n.tr("Localizable", "PreHistorySettings.Header") }
  /// New members won't see earlier messages.
  public static var preHistorySettingsDescriptionHidden: String  { return L10n.tr("Localizable", "PreHistorySettings.Description.Hidden") }
  /// New Members will see messages that were sent before they joined.
  public static var preHistorySettingsDescriptionVisible: String  { return L10n.tr("Localizable", "PreHistorySettings.Description.Visible") }
  /// New members won't see more than 100 previous messages.
  public static var preHistorySettingsDescriptionGroupHidden: String  { return L10n.tr("Localizable", "PreHistorySettings.Description.Group.Hidden") }
  /// bot
  public static var presenceBot: String  { return L10n.tr("Localizable", "Presence.bot") }
  /// support
  public static var presenceSupport: String  { return L10n.tr("Localizable", "Presence.Support") }
  /// %d
  public static func previewDraggingAddItemsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Preview.Dragging.AddItems_countable", p1)
  }
  /// Add Items
  public static var previewDraggingAddItemsFew: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_few") }
  /// Add Items
  public static var previewDraggingAddItemsMany: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_many") }
  /// Add Item
  public static var previewDraggingAddItemsOne: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_one") }
  /// Add Items
  public static var previewDraggingAddItemsOther: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_other") }
  /// Add Items
  public static var previewDraggingAddItemsTwo: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_two") }
  /// Add Items
  public static var previewDraggingAddItemsZero: String  { return L10n.tr("Localizable", "Preview.Dragging.AddItems_zero") }
  /// Archive all media in one zip file
  public static var previewSenderArchiveTooltip: String  { return L10n.tr("Localizable", "PreviewSender.ArchiveTooltip") }
  /// Add a caption...
  public static var previewSenderCaptionPlaceholder: String  { return L10n.tr("Localizable", "PreviewSender.CaptionPlaceholder") }
  /// Group all media into one message
  public static var previewSenderCollageTooltip: String  { return L10n.tr("Localizable", "PreviewSender.CollageTooltip") }
  /// Add a comment...
  public static var previewSenderCommentPlaceholder: String  { return L10n.tr("Localizable", "PreviewSender.CommentPlaceholder") }
  /// Send compressed
  public static var previewSenderCompressFile: String  { return L10n.tr("Localizable", "PreviewSender.CompressFile") }
  /// Send without compression
  public static var previewSenderFileTooltip: String  { return L10n.tr("Localizable", "PreviewSender.FileTooltip") }
  /// Send in a quick way
  public static var previewSenderMediaTooltip: String  { return L10n.tr("Localizable", "PreviewSender.MediaTooltip") }
  /// %d
  public static func previewSenderSendAudioCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_countable", p1)
  }
  /// Send %d Audios
  public static func previewSenderSendAudioFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_few", p1)
  }
  /// Send %d Audios
  public static func previewSenderSendAudioMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_many", p1)
  }
  /// Send Audio
  public static var previewSenderSendAudioOne: String  { return L10n.tr("Localizable", "PreviewSender.SendAudio_one") }
  /// Send %d Audios
  public static func previewSenderSendAudioOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_other", p1)
  }
  /// Send %d Audios
  public static func previewSenderSendAudioTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_two", p1)
  }
  /// Send %d Audios
  public static func previewSenderSendAudioZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendAudio_zero", p1)
  }
  /// %d
  public static func previewSenderSendFileCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_countable", p1)
  }
  /// Send %d Files
  public static func previewSenderSendFileFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_few", p1)
  }
  /// Send %d Files
  public static func previewSenderSendFileMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_many", p1)
  }
  /// Send File
  public static var previewSenderSendFileOne: String  { return L10n.tr("Localizable", "PreviewSender.SendFile_one") }
  /// Send %d Files
  public static func previewSenderSendFileOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_other", p1)
  }
  /// Send %d Files
  public static func previewSenderSendFileTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_two", p1)
  }
  /// Send %d Files
  public static func previewSenderSendFileZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendFile_zero", p1)
  }
  /// %d
  public static func previewSenderSendGifCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_countable", p1)
  }
  /// Send %d GIFs
  public static func previewSenderSendGifFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_few", p1)
  }
  /// Send %d GIFs
  public static func previewSenderSendGifMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_many", p1)
  }
  /// Send GIF
  public static var previewSenderSendGifOne: String  { return L10n.tr("Localizable", "PreviewSender.SendGif_one") }
  /// Send %d GIFs
  public static func previewSenderSendGifOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_other", p1)
  }
  /// Send %d GIFs
  public static func previewSenderSendGifTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_two", p1)
  }
  /// Send %d GIFs
  public static func previewSenderSendGifZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendGif_zero", p1)
  }
  /// %d
  public static func previewSenderSendMediaCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_countable", p1)
  }
  /// Send %d Media
  public static func previewSenderSendMediaFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_few", p1)
  }
  /// Send %d Media
  public static func previewSenderSendMediaMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_many", p1)
  }
  /// Send Media
  public static var previewSenderSendMediaOne: String  { return L10n.tr("Localizable", "PreviewSender.SendMedia_one") }
  /// Send %d Media
  public static func previewSenderSendMediaOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_other", p1)
  }
  /// Send %d Media
  public static func previewSenderSendMediaTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_two", p1)
  }
  /// Send %d Media
  public static func previewSenderSendMediaZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendMedia_zero", p1)
  }
  /// %d
  public static func previewSenderSendPhotoCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_countable", p1)
  }
  /// Send %d Photos
  public static func previewSenderSendPhotoFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_few", p1)
  }
  /// Send %d Photos
  public static func previewSenderSendPhotoMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_many", p1)
  }
  /// Send Photo
  public static var previewSenderSendPhotoOne: String  { return L10n.tr("Localizable", "PreviewSender.SendPhoto_one") }
  /// Send %d Photos
  public static func previewSenderSendPhotoOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_other", p1)
  }
  /// Send %d Photos
  public static func previewSenderSendPhotoTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_two", p1)
  }
  /// Send %d Photos
  public static func previewSenderSendPhotoZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendPhoto_zero", p1)
  }
  /// %d
  public static func previewSenderSendVideoCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_countable", p1)
  }
  /// Send %d Videos
  public static func previewSenderSendVideoFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_few", p1)
  }
  /// Send %d Videos
  public static func previewSenderSendVideoMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_many", p1)
  }
  /// Send Video
  public static var previewSenderSendVideoOne: String  { return L10n.tr("Localizable", "PreviewSender.SendVideo_one") }
  /// Send %d Videos
  public static func previewSenderSendVideoOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_other", p1)
  }
  /// Send %d Videos
  public static func previewSenderSendVideoTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_two", p1)
  }
  /// Send %d Videos
  public static func previewSenderSendVideoZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PreviewSender.SendVideo_zero", p1)
  }
  /// Sorry, you can't create a group with these users due to their privacy settings.
  public static var privacyGroupsAndChannelsInviteToChannelMultipleError: String  { return L10n.tr("Localizable", "Privacy.GroupsAndChannels.InviteToChannelMultipleError") }
  /// Automatically archive and mute new chats, groups and channels from non-contacts.
  public static var privacyAndSecurityAutoArchiveDesc: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.AutoArchiveDesc") }
  /// NEW CHATS FROM UNKNOWN USERS
  public static var privacyAndSecurityAutoArchiveHeader: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.AutoArchiveHeader") }
  /// Archive and Mute
  public static var privacyAndSecurityAutoArchiveText: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.AutoArchiveText") }
  /// %@ users
  public static func privacyAndSecurityBlockedUsers(_ p1: String) -> String {
    return L10n.tr("Localizable", "PrivacyAndSecurity.BlockedUsers", p1)
  }
  /// Clear Cloud Drafts
  public static var privacyAndSecurityClearCloudDrafts: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.ClearCloudDrafts") }
  /// CHATS
  public static var privacyAndSecurityClearCloudDraftsHeader: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.ClearCloudDraftsHeader") }
  /// Display sensitive media in public channels on all your Telegram devices.
  public static var privacyAndSecuritySensitiveDesc: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SensitiveDesc") }
  /// SENSITIVE CONTENT
  public static var privacyAndSecuritySensitiveHeader: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SensitiveHeader") }
  /// Disable filtering
  public static var privacyAndSecuritySensitiveText: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SensitiveText") }
  /// CONNECTED WEBSITES
  public static var privacyAndSecurityWebAuthorizationHeader: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.WebAuthorizationHeader") }
  /// Are you sure you want to clear all cloud drafts?
  public static var privacyAndSecurityConfirmClearCloudDrafts: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.Confirm.ClearCloudDrafts") }
  /// Off
  public static var privacyAndSecurityItemOff: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.Item.Off") }
  /// On
  public static var privacyAndSecurityItemOn: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.Item.On") }
  /// Link previews will be generated on Telegram servers. We do not store data about the links you send.
  public static var privacyAndSecuritySecretChatWebPreviewDesc: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SecretChatWebPreview.Desc") }
  /// SECRET CHAT
  public static var privacyAndSecuritySecretChatWebPreviewHeader: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SecretChatWebPreview.Header") }
  /// Link Previews
  public static var privacyAndSecuritySecretChatWebPreviewText: String  { return L10n.tr("Localizable", "PrivacyAndSecurity.SecretChatWebPreview.Text") }
  /// Users who add your number to their contacts will see it on Telegram only if they are your contacts.
  public static var privacyPhoneNumberSettingsCustomDisabledHelp: String  { return L10n.tr("Localizable", "PrivacyPhoneNumberSettings.CustomDisabledHelp") }
  /// WHO CAN FIND ME BY MY NUMBER
  public static var privacyPhoneNumberSettingsDiscoveryHeader: String  { return L10n.tr("Localizable", "PrivacyPhoneNumberSettings.DiscoveryHeader") }
  /// Active Sessions
  public static var privacySettingsActiveSessions: String  { return L10n.tr("Localizable", "PrivacySettings.ActiveSessions") }
  /// Blocked Users
  public static var privacySettingsBlockedUsers: String  { return L10n.tr("Localizable", "PrivacySettings.BlockedUsers") }
  /// If Away For
  public static var privacySettingsDeleteAccount: String  { return L10n.tr("Localizable", "PrivacySettings.DeleteAccount") }
  /// If you do not come online at least once within this period, your account will be deleted along with all messages and contacts.
  public static var privacySettingsDeleteAccountDescription: String  { return L10n.tr("Localizable", "PrivacySettings.DeleteAccountDescription") }
  /// DELETE MY ACCOUNT
  public static var privacySettingsDeleteAccountHeader: String  { return L10n.tr("Localizable", "PrivacySettings.DeleteAccountHeader") }
  /// Forwarded Messages
  public static var privacySettingsForwards: String  { return L10n.tr("Localizable", "PrivacySettings.Forwards") }
  /// %d
  public static func privacySettingsGroupMembersCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_countable", p1)
  }
  /// %d members
  public static func privacySettingsGroupMembersCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_few", p1)
  }
  /// %d members
  public static func privacySettingsGroupMembersCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_many", p1)
  }
  /// %d member
  public static func privacySettingsGroupMembersCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_one", p1)
  }
  /// %d members
  public static func privacySettingsGroupMembersCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_other", p1)
  }
  /// %d members
  public static func privacySettingsGroupMembersCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_two", p1)
  }
  /// %d members
  public static func privacySettingsGroupMembersCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettings.GroupMembersCount_zero", p1)
  }
  /// Groups and Channels
  public static var privacySettingsGroups: String  { return L10n.tr("Localizable", "PrivacySettings.Groups") }
  /// Last Seen
  public static var privacySettingsLastSeen: String  { return L10n.tr("Localizable", "PrivacySettings.LastSeen") }
  /// My Contacts (-%@)
  public static func privacySettingsLastSeenContactsMinus(_ p1: String) -> String {
    return L10n.tr("Localizable", "PrivacySettings.LastSeenContactsMinus", p1)
  }
  /// My Contacts (-%@, +%@)
  public static func privacySettingsLastSeenContactsMinusPlus(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "PrivacySettings.LastSeenContactsMinusPlus", p1, p2)
  }
  /// My Contacts (+%@)
  public static func privacySettingsLastSeenContactsPlus(_ p1: String) -> String {
    return L10n.tr("Localizable", "PrivacySettings.LastSeenContactsPlus", p1)
  }
  /// Everybody (-%@)
  public static func privacySettingsLastSeenEverybodyMinus(_ p1: String) -> String {
    return L10n.tr("Localizable", "PrivacySettings.LastSeenEverybodyMinus", p1)
  }
  /// Nobody (+%@)
  public static func privacySettingsLastSeenNobodyPlus(_ p1: String) -> String {
    return L10n.tr("Localizable", "PrivacySettings.LastSeenNobodyPlus", p1)
  }
  /// Passcode
  public static var privacySettingsPasscode: String  { return L10n.tr("Localizable", "PrivacySettings.Passcode") }
  /// Phone Number
  public static var privacySettingsPhoneNumber: String  { return L10n.tr("Localizable", "PrivacySettings.PhoneNumber") }
  /// PRIVACY
  public static var privacySettingsPrivacyHeader: String  { return L10n.tr("Localizable", "PrivacySettings.PrivacyHeader") }
  /// Profile Photo
  public static var privacySettingsProfilePhoto: String  { return L10n.tr("Localizable", "PrivacySettings.ProfilePhoto") }
  /// CONNECTION TYPE
  public static var privacySettingsProxyHeader: String  { return L10n.tr("Localizable", "PrivacySettings.ProxyHeader") }
  /// SECURITY
  public static var privacySettingsSecurityHeader: String  { return L10n.tr("Localizable", "PrivacySettings.SecurityHeader") }
  /// Two-Step Verification
  public static var privacySettingsTwoStepVerification: String  { return L10n.tr("Localizable", "PrivacySettings.TwoStepVerification") }
  /// Use Proxy
  public static var privacySettingsUseProxy: String  { return L10n.tr("Localizable", "PrivacySettings.UseProxy") }
  /// Voice Calls
  public static var privacySettingsVoiceCalls: String  { return L10n.tr("Localizable", "PrivacySettings.VoiceCalls") }
  /// Add New
  public static var privacySettingsPeerSelectAddNew: String  { return L10n.tr("Localizable", "PrivacySettings.PeerSelect.AddNew") }
  /// Add Users or Groups
  public static var privacySettingsPeerSelectAddUserOrGroup: String  { return L10n.tr("Localizable", "PrivacySettings.PeerSelect.AddUserOrGroup") }
  /// Add Users
  public static var privacySettingsControllerAddUsers: String  { return L10n.tr("Localizable", "PrivacySettingsController.AddUsers") }
  /// Always Allow
  public static var privacySettingsControllerAlwaysAllow: String  { return L10n.tr("Localizable", "PrivacySettingsController.AlwaysAllow") }
  /// Always Share
  public static var privacySettingsControllerAlwaysShare: String  { return L10n.tr("Localizable", "PrivacySettingsController.AlwaysShare") }
  /// Always Share With
  public static var privacySettingsControllerAlwaysShareWith: String  { return L10n.tr("Localizable", "PrivacySettingsController.AlwaysShareWith") }
  /// Everybody
  public static var privacySettingsControllerEverbody: String  { return L10n.tr("Localizable", "PrivacySettingsController.Everbody") }
  /// You can restrict who can add you to groups and channels with granular precision.
  public static var privacySettingsControllerGroupDescription: String  { return L10n.tr("Localizable", "PrivacySettingsController.GroupDescription") }
  /// WHO CAN ADD ME TO GROUP CHATS
  public static var privacySettingsControllerGroupHeader: String  { return L10n.tr("Localizable", "PrivacySettingsController.GroupHeader") }
  /// Last Seen
  public static var privacySettingsControllerHeader: String  { return L10n.tr("Localizable", "PrivacySettingsController.Header") }
  /// Important: you won't be able to see Last Seen times for people with whom you don't share your Last Seen time. Approximate last seen will be shown instead (recently, within a week, within a month).
  public static var privacySettingsControllerLastSeenDescription: String  { return L10n.tr("Localizable", "PrivacySettingsController.LastSeenDescription") }
  /// WHO CAN SEE MY TIMESTAMP
  public static var privacySettingsControllerLastSeenHeader: String  { return L10n.tr("Localizable", "PrivacySettingsController.LastSeenHeader") }
  /// My Contacts
  public static var privacySettingsControllerMyContacts: String  { return L10n.tr("Localizable", "PrivacySettingsController.MyContacts") }
  /// Never Allow
  public static var privacySettingsControllerNeverAllow: String  { return L10n.tr("Localizable", "PrivacySettingsController.NeverAllow") }
  /// Never Share
  public static var privacySettingsControllerNeverShare: String  { return L10n.tr("Localizable", "PrivacySettingsController.NeverShare") }
  /// Never Share With
  public static var privacySettingsControllerNeverShareWith: String  { return L10n.tr("Localizable", "PrivacySettingsController.NeverShareWith") }
  /// Nobody
  public static var privacySettingsControllerNobody: String  { return L10n.tr("Localizable", "PrivacySettingsController.Nobody") }
  /// These settings will override the values above.
  public static var privacySettingsControllerPeerInfo: String  { return L10n.tr("Localizable", "PrivacySettingsController.PeerInfo") }
  /// You can restrict who can call you with granular precision.
  public static var privacySettingsControllerPhoneCallDescription: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneCallDescription") }
  /// WHO CAN CALL ME
  public static var privacySettingsControllerPhoneCallHeader: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneCallHeader") }
  /// %d
  public static func privacySettingsControllerUserCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_countable", p1)
  }
  /// %d users
  public static func privacySettingsControllerUserCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_few", p1)
  }
  /// %d users
  public static func privacySettingsControllerUserCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_many", p1)
  }
  /// %d user
  public static func privacySettingsControllerUserCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_one", p1)
  }
  /// %d users
  public static func privacySettingsControllerUserCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_other", p1)
  }
  /// %d users
  public static func privacySettingsControllerUserCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_two", p1)
  }
  /// %d users
  public static func privacySettingsControllerUserCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "PrivacySettingsController.UserCount_zero", p1)
  }
  /// When forwarded to other chats, messages you send will not link back to your account.
  public static var privacySettingsControllerForwardsCustomHelp: String  { return L10n.tr("Localizable", "PrivacySettingsController.Forwards.CustomHelp") }
  /// WHO CAN FORWARD MY MESSAGES
  public static var privacySettingsControllerForwardsWhoCanForward: String  { return L10n.tr("Localizable", "PrivacySettingsController.Forwards.WhoCanForward") }
  /// Always Allow
  public static var privacySettingsControllerForwardsAlwaysAllowTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.Forwards.AlwaysAllow.Title") }
  /// Never Allow
  public static var privacySettingsControllerForwardsNeverAllowTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.Forwards.NeverAllow.Title") }
  /// Always
  public static var privacySettingsControllerP2pAlways: String  { return L10n.tr("Localizable", "PrivacySettingsController.P2p.Always") }
  /// My Contacts
  public static var privacySettingsControllerP2pContacts: String  { return L10n.tr("Localizable", "PrivacySettingsController.P2p.Contacts") }
  /// Disabling peer-to-peer will relay all calls through Telegram servers to avoid revealing your IP address, but will slighly decrease audio quality
  public static var privacySettingsControllerP2pDesc: String  { return L10n.tr("Localizable", "PrivacySettingsController.P2p.Desc") }
  /// PEER TO PEER
  public static var privacySettingsControllerP2pHeader: String  { return L10n.tr("Localizable", "PrivacySettingsController.P2p.Header") }
  /// Never
  public static var privacySettingsControllerP2pNever: String  { return L10n.tr("Localizable", "PrivacySettingsController.P2p.Never") }
  /// Users who already have your number saved in the contacts will also see it on Telegram.
  public static var privacySettingsControllerPhoneNumberCustomHelp: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneNumber.CustomHelp") }
  /// WHO CAN SEE MY PHONE NUMBER
  public static var privacySettingsControllerPhoneNumberWhoCanSeePhoneNumber: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneNumber.WhoCanSeePhoneNumber") }
  /// Always Share With
  public static var privacySettingsControllerPhoneNumberAlwaysAllowTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneNumber.AlwaysAllow.Title") }
  /// Never Share 
  public static var privacySettingsControllerPhoneNumberNeverAllowTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.PhoneNumber.NeverAllow.Title") }
  /// You can restrict who can see your profile photo with granular precision.
  public static var privacySettingsControllerProfilePhotoCustomHelp: String  { return L10n.tr("Localizable", "PrivacySettingsController.ProfilePhoto.CustomHelp") }
  /// WHO CAN SEE MY PROFILE PHOTO
  public static var privacySettingsControllerProfilePhotoWhoCanSeeMyPhoto: String  { return L10n.tr("Localizable", "PrivacySettingsController.ProfilePhoto.WhoCanSeeMyPhoto") }
  /// Always Share With
  public static var privacySettingsControllerProfilePhotoAlwaysShareWithTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.ProfilePhoto.AlwaysShareWith.Title") }
  /// Never Share With
  public static var privacySettingsControllerProfilePhotoNeverShareWithTitle: String  { return L10n.tr("Localizable", "PrivacySettingsController.ProfilePhoto.NeverShareWith.Title") }
  /// Cancel
  public static var privateChannelPeekCancel: String  { return L10n.tr("Localizable", "PrivateChannel.Peek.Cancel") }
  /// Join Channel
  public static var privateChannelPeekHeader: String  { return L10n.tr("Localizable", "PrivateChannel.Peek.Header") }
  /// Join Channel
  public static var privateChannelPeekOK: String  { return L10n.tr("Localizable", "PrivateChannel.Peek.OK") }
  /// This channel is private. Please join it to continue viewing its content.
  public static var privateChannelPeekText: String  { return L10n.tr("Localizable", "PrivateChannel.Peek.Text") }
  /// Are you sure you want to disable proxy server %@?
  public static func proxyForceDisable(_ p1: String) -> String {
    return L10n.tr("Localizable", "Proxy.ForceDisable", p1)
  }
  /// Connect
  public static var proxyForceEnableConnect: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.Connect") }
  /// Enable Proxy
  public static var proxyForceEnableEnable: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.Enable") }
  /// Do you want to add this proxy?
  public static var proxyForceEnableHeader1: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.Header1") }
  /// This proxy may display a sponsored channel in your chat list. This doesn't reveal any of your Telegram traffic.
  public static var proxyForceEnableMTPDesc: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.MTPDesc") }
  /// Add Proxy
  public static var proxyForceEnableOK: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.OK") }
  /// You can change your proxy server later in Settings > Privacy and Security.
  public static var proxyForceEnableText: String  { return L10n.tr("Localizable", "Proxy.ForceEnable.Text") }
  /// Server: %@
  public static func proxyForceEnableTextIP(_ p1: String) -> String {
    return L10n.tr("Localizable", "Proxy.ForceEnable.Text.IP", p1)
  }
  /// Password: %@
  public static func proxyForceEnableTextPassword(_ p1: String) -> String {
    return L10n.tr("Localizable", "Proxy.ForceEnable.Text.Password", p1)
  }
  /// Port: %d
  public static func proxyForceEnableTextPort(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Proxy.ForceEnable.Text.Port", p1)
  }
  /// Secret: %@
  public static func proxyForceEnableTextSecret(_ p1: String) -> String {
    return L10n.tr("Localizable", "Proxy.ForceEnable.Text.Secret", p1)
  }
  /// Username: %@
  public static func proxyForceEnableTextUsername(_ p1: String) -> String {
    return L10n.tr("Localizable", "Proxy.ForceEnable.Text.Username", p1)
  }
  /// Add Proxy
  public static var proxySettingsAddProxy: String  { return L10n.tr("Localizable", "ProxySettings.AddProxy") }
  /// Connection
  public static var proxySettingsConnectionHeader: String  { return L10n.tr("Localizable", "ProxySettings.ConnectionHeader") }
  /// Share proxy link
  public static var proxySettingsCopyLink: String  { return L10n.tr("Localizable", "ProxySettings.CopyLink") }
  /// CREDENTIALS (OPTIONAL)
  public static var proxySettingsCredentialsHeader: String  { return L10n.tr("Localizable", "ProxySettings.CredentialsHeader") }
  /// Disabled
  public static var proxySettingsDisabled: String  { return L10n.tr("Localizable", "ProxySettings.Disabled") }
  /// Proxy
  public static var proxySettingsEnable: String  { return L10n.tr("Localizable", "ProxySettings.Enable") }
  /// If your clipboard contains socks5-link (**t.me/socks?server=127.0.0.1&port=80**) it will apply immediately
  public static var proxySettingsExportDescription: String  { return L10n.tr("Localizable", "ProxySettings.ExportDescription") }
  /// Export link from clipboard
  public static var proxySettingsExportLink: String  { return L10n.tr("Localizable", "ProxySettings.ExportLink") }
  /// Incorrect secret. Please try again.
  public static var proxySettingsIncorrectSecret: String  { return L10n.tr("Localizable", "ProxySettings.IncorrectSecret") }
  /// MTPROTO
  public static var proxySettingsMTP: String  { return L10n.tr("Localizable", "ProxySettings.MTP") }
  /// Password
  public static var proxySettingsPassword: String  { return L10n.tr("Localizable", "ProxySettings.Password") }
  /// Port
  public static var proxySettingsPort: String  { return L10n.tr("Localizable", "ProxySettings.Port") }
  /// Proxy settings not found in clipboard.
  public static var proxySettingsProxyNotFound: String  { return L10n.tr("Localizable", "ProxySettings.ProxyNotFound") }
  /// Save
  public static var proxySettingsSave: String  { return L10n.tr("Localizable", "ProxySettings.Save") }
  /// Secret
  public static var proxySettingsSecret: String  { return L10n.tr("Localizable", "ProxySettings.Secret") }
  /// Server
  public static var proxySettingsServer: String  { return L10n.tr("Localizable", "ProxySettings.Server") }
  /// Share this link with friends to circumvent censorship in your country
  public static var proxySettingsShare: String  { return L10n.tr("Localizable", "ProxySettings.Share") }
  /// Share Proxy List
  public static var proxySettingsShareProxyList: String  { return L10n.tr("Localizable", "ProxySettings.ShareProxyList") }
  /// SOCKS5
  public static var proxySettingsSocks5: String  { return L10n.tr("Localizable", "ProxySettings.Socks5") }
  /// Proxy Settings
  public static var proxySettingsTitle: String  { return L10n.tr("Localizable", "ProxySettings.Title") }
  /// Proxy Type
  public static var proxySettingsType: String  { return L10n.tr("Localizable", "ProxySettings.Type") }
  /// Use for Calls
  public static var proxySettingsUseForCalls: String  { return L10n.tr("Localizable", "ProxySettings.UseForCalls") }
  /// Username
  public static var proxySettingsUsername: String  { return L10n.tr("Localizable", "ProxySettings.Username") }
  /// available (ping: %@ ms)
  public static func proxySettingsItemAvailable(_ p1: String) -> String {
    return L10n.tr("Localizable", "ProxySettings.Item.Available", p1)
  }
  /// checking
  public static var proxySettingsItemChecking: String  { return L10n.tr("Localizable", "ProxySettings.Item.Checking") }
  /// connected
  public static var proxySettingsItemConnected: String  { return L10n.tr("Localizable", "ProxySettings.Item.Connected") }
  /// connected (ping: %@ ms)
  public static func proxySettingsItemConnectedPing(_ p1: String) -> String {
    return L10n.tr("Localizable", "ProxySettings.Item.ConnectedPing", p1)
  }
  /// last connection %@
  public static func proxySettingsItemLastConnection(_ p1: String) -> String {
    return L10n.tr("Localizable", "ProxySettings.Item.LastConnection", p1)
  }
  /// unavailable
  public static var proxySettingsItemNeverConnected: String  { return L10n.tr("Localizable", "ProxySettings.Item.NeverConnected") }
  /// The proxy may display a sponsored channel in your chat list. This doesn't reveal any of your Telegram traffic.
  public static var proxySettingsMtpSponsor: String  { return L10n.tr("Localizable", "ProxySettings.Mtp.Sponsor") }
  /// You or your friends can add this proxy by scanning this code with phone or in-app camera.
  public static var proxySettingsQRText: String  { return L10n.tr("Localizable", "ProxySettings.QR.Text") }
  /// Preview
  public static var quickLookPreview: String  { return L10n.tr("Localizable", "QuickLook.Preview") }
  /// **TAB** or **↑ ↓** to navigate, **⮐** to select, **ESC** to dismiss
  public static var quickSwitcherDescription: String  { return L10n.tr("Localizable", "QuickSwitcher.Description") }
  /// Popular
  public static var quickSwitcherPopular: String  { return L10n.tr("Localizable", "QuickSwitcher.Popular") }
  /// Recent
  public static var quickSwitcherRecently: String  { return L10n.tr("Localizable", "QuickSwitcher.Recently") }
  /// Zoom
  public static var r4oN2Eq4Title: String  { return L10n.tr("Localizable", "R4o-n2-Eq4.title") }
  /// Allow Reactions
  public static var reactionSettingsAllow: String  { return L10n.tr("Localizable", "Reaction.Settings.Allow") }
  /// Hover Reactions
  public static var reactionSettingsLegacy: String  { return L10n.tr("Localizable", "Reaction.Settings.Legacy") }
  /// Reactions
  public static var reactionSettingsTitle: String  { return L10n.tr("Localizable", "Reaction.Settings.Title") }
  /// Allow subscribers to reacts to channel posts.
  public static var reactionSettingsAllowChannelInfo: String  { return L10n.tr("Localizable", "Reaction.Settings.Allow.Channel.Info") }
  /// Allow members to reacts to messages.
  public static var reactionSettingsAllowGroupInfo: String  { return L10n.tr("Localizable", "Reaction.Settings.Allow.Group.Info") }
  /// AVAILABLE REACTIONS
  public static var reactionSettingsAvailableInfo: String  { return L10n.tr("Localizable", "Reaction.Settings.Available.Info") }
  /// Reaction button will be shown when you hover near message
  public static var reactionSettingsLegacyInfo: String  { return L10n.tr("Localizable", "Reaction.Settings.Legacy.Info") }
  /// QUICK REACTION.
  public static var reactionSettingsQuickInfo: String  { return L10n.tr("Localizable", "Reaction.Settings.Quick.Info") }
  /// Quick Reaction
  public static var reactionSettingsQuickTitle: String  { return L10n.tr("Localizable", "Reaction.Settings.Quick.Title") }
  /// Delete
  public static var recentCallsDelete: String  { return L10n.tr("Localizable", "RecentCalls.Delete") }
  /// Are you sure you want to delete call?
  public static var recentCallsDeleteCalls: String  { return L10n.tr("Localizable", "RecentCalls.DeleteCalls") }
  /// Delete for me and %@
  public static func recentCallsDeleteForMeAnd(_ p1: String) -> String {
    return L10n.tr("Localizable", "RecentCalls.DeleteForMeAnd", p1)
  }
  /// Delete
  public static var recentCallsDeleteHeader: String  { return L10n.tr("Localizable", "RecentCalls.DeleteHeader") }
  /// Your recent calls will appear here
  public static var recentCallsEmpty: String  { return L10n.tr("Localizable", "RecentCalls.Empty") }
  /// These devices have no access to your account. The code was entered correctly, but no correct password was given.
  public static var recentSessionsIncompleteAttemptDesc: String  { return L10n.tr("Localizable", "RecentSessions.IncompleteAttemptDesc") }
  /// INCOMPLETE LOGIN ATTEMPTS
  public static var recentSessionsIncompleteAttemptHeader: String  { return L10n.tr("Localizable", "RecentSessions.IncompleteAttemptHeader") }
  /// Revoke
  public static var recentSessionsRevoke: String  { return L10n.tr("Localizable", "RecentSessions.Revoke") }
  /// Do you want to terminate this session?
  public static var recentSessionsConfirmRevoke: String  { return L10n.tr("Localizable", "RecentSessions.Confirm.Revoke") }
  /// Are you sure you want to terminate all other sessions?
  public static var recentSessionsConfirmTerminateOthers: String  { return L10n.tr("Localizable", "RecentSessions.Confirm.TerminateOthers") }
  /// For security reasons, you can't terminate older sessions from a device that you've just connected. Please use an earlier connection or wait for a few hours.
  public static var recentSessionsErrorFreshReset: String  { return L10n.tr("Localizable", "RecentSessions.Error.FreshReset") }
  /// AUTOMATICALLY TERMINATE OLD SESSIONS
  public static var recentSessionsTTLHeader: String  { return L10n.tr("Localizable", "RecentSessions.TTL.Header") }
  /// If Inactive For
  public static var recentSessionsTTLText: String  { return L10n.tr("Localizable", "RecentSessions.TTL.Text") }
  /// Please enter any additional details relevant for your report.
  public static var reportAdditionText: String  { return L10n.tr("Localizable", "Report.AdditionText") }
  /// Report
  public static var reportAdditionTextButton: String  { return L10n.tr("Localizable", "Report.AdditionText.Button") }
  /// Additional details...
  public static var reportAdditionTextPlaceholder: String  { return L10n.tr("Localizable", "Report.AdditionText.Placeholder") }
  /// Child Abuse
  public static var reportReasonChildAbuse: String  { return L10n.tr("Localizable", "ReportReason.ChildAbuse") }
  /// Copyright
  public static var reportReasonCopyright: String  { return L10n.tr("Localizable", "ReportReason.Copyright") }
  /// Fake
  public static var reportReasonFake: String  { return L10n.tr("Localizable", "ReportReason.Fake") }
  /// Other
  public static var reportReasonOther: String  { return L10n.tr("Localizable", "ReportReason.Other") }
  /// Pornography
  public static var reportReasonPorno: String  { return L10n.tr("Localizable", "ReportReason.Porno") }
  /// Report
  public static var reportReasonReport: String  { return L10n.tr("Localizable", "ReportReason.Report") }
  /// Spam
  public static var reportReasonSpam: String  { return L10n.tr("Localizable", "ReportReason.Spam") }
  /// Violence
  public static var reportReasonViolence: String  { return L10n.tr("Localizable", "ReportReason.Violence") }
  /// Description
  public static var reportReasonOtherPlaceholder: String  { return L10n.tr("Localizable", "ReportReason.Other.Placeholder") }
  /// Settings
  public static var requestAccesErrorConirmSettings: String  { return L10n.tr("Localizable", "RequestAcces.Error.Conirm.Settings") }
  /// Telegram needs access to your microphone to make calls
  public static var requestAccesErrorHaveNotAccessCall: String  { return L10n.tr("Localizable", "RequestAcces.Error.HaveNotAccess.Call") }
  /// Telegram needs access to your microphone and camera to record video messages.
  public static var requestAccesErrorHaveNotAccessVideoMessages: String  { return L10n.tr("Localizable", "RequestAcces.Error.HaveNotAccess.VideoMessages") }
  /// Telegram needs access to your microphone to record voice messages.
  public static var requestAccesErrorHaveNotAccessVoiceMessages: String  { return L10n.tr("Localizable", "RequestAcces.Error.HaveNotAccess.VoiceMessages") }
  /// Request to Join
  public static var requestJoinButton: String  { return L10n.tr("Localizable", "RequestJoin.Button") }
  /// Request to join sent.
  public static var requestJoinSent: String  { return L10n.tr("Localizable", "RequestJoin.Sent") }
  /// This channel accepts new subscribtions only after they are approved by it's admins.
  public static var requestJoinDescChannel: String  { return L10n.tr("Localizable", "RequestJoin.Desc.Channel") }
  /// This group accepts new subscribtions only after they are approved by it's admins.
  public static var requestJoinDescGroup: String  { return L10n.tr("Localizable", "RequestJoin.Desc.Group") }
  /// You have already sent request to join channel
  public static var requestJoinErrorAlreadySentChannel: String  { return L10n.tr("Localizable", "RequestJoin.Error.AlreadySent.Channel") }
  /// You have already sent request to join group
  public static var requestJoinErrorAlreadySentGroup: String  { return L10n.tr("Localizable", "RequestJoin.Error.AlreadySent.Group") }
  /// Some [addition links]() are set up to accept requests to join the channel.
  public static var requestJoinListDescription: String  { return L10n.tr("Localizable", "RequestJoin.List.Description") }
  /// No Member Requests
  public static var requestJoinListEmpty1: String  { return L10n.tr("Localizable", "RequestJoin.List.Empty1") }
  /// %d
  public static func requestJoinListListHeaderCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_countable", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_few", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_many", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_one", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_other", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_two", p1)
  }
  /// %d REQUESTED TO JOIN
  public static func requestJoinListListHeaderZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.ListHeader_zero", p1)
  }
  /// There were no results for "%@".\nTry a new search.
  public static func requestJoinListSearchEmpty(_ p1: String) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.SearchEmpty", p1)
  }
  /// Members Requests
  public static var requestJoinListTitle: String  { return L10n.tr("Localizable", "RequestJoin.List.Title") }
  /// Add to Channel
  public static var requestJoinListApproveChannel: String  { return L10n.tr("Localizable", "RequestJoin.List.Approve.Channel") }
  /// Dismiss
  public static var requestJoinListApproveDismiss: String  { return L10n.tr("Localizable", "RequestJoin.List.Approve.Dismiss") }
  /// Add to Group
  public static var requestJoinListApproveGroup: String  { return L10n.tr("Localizable", "RequestJoin.List.Approve.Group") }
  /// You have no pending requests to join the channel
  public static var requestJoinListEmpty2Channel: String  { return L10n.tr("Localizable", "RequestJoin.List.Empty2.Channel") }
  /// You have no pending requests to join the group
  public static var requestJoinListEmpty2Group: String  { return L10n.tr("Localizable", "RequestJoin.List.Empty2.Group") }
  /// No Results Found
  public static var requestJoinListSearchEmptyHeader: String  { return L10n.tr("Localizable", "RequestJoin.List.SearchEmpty.Header") }
  /// **%@** has been added to the channel.
  public static func requestJoinListTooltipApprovedChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.Tooltip.Approved.Channel", p1)
  }
  /// **%@** has been added to the group.
  public static func requestJoinListTooltipApprovedGroup(_ p1: String) -> String {
    return L10n.tr("Localizable", "RequestJoin.List.Tooltip.Approved.Group", p1)
  }
  /// Select All
  public static var ruw6mB2mTitle: String  { return L10n.tr("Localizable", "Ruw-6m-B2m.title") }
  /// Saved!\n[Show In Finder]()
  public static var savedAsModalOk: String  { return L10n.tr("Localizable", "SavedAs.ModalOk") }
  /// Send on %@ at %@
  public static func scheduleSendDate(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Schedule.SendDate", p1, p2)
  }
  /// Send today at %@
  public static func scheduleSendToday(_ p1: String) -> String {
    return L10n.tr("Localizable", "Schedule.SendToday", p1)
  }
  /// Send When Online
  public static var scheduleSendWhenOnline: String  { return L10n.tr("Localizable", "Schedule.SendWhenOnline") }
  /// at
  public static var scheduleControllerAt: String  { return L10n.tr("Localizable", "ScheduleController.at") }
  /// Schedule Message
  public static var scheduleControllerTitle: String  { return L10n.tr("Localizable", "ScheduleController.Title") }
  /// Are you sure you want to clear your search history?
  public static var searchConfirmClearHistory: String  { return L10n.tr("Localizable", "Search.Confirm.ClearHistory") }
  /// Clear Filter
  public static var searchFilterClearFilter: String  { return L10n.tr("Localizable", "Search.Filter.ClearFilter") }
  /// Files
  public static var searchFilterFiles: String  { return L10n.tr("Localizable", "Search.Filter.Files") }
  /// GIFs
  public static var searchFilterGIFs: String  { return L10n.tr("Localizable", "Search.Filter.GIFs") }
  /// Links
  public static var searchFilterLinks: String  { return L10n.tr("Localizable", "Search.Filter.Links") }
  /// Music
  public static var searchFilterMusic: String  { return L10n.tr("Localizable", "Search.Filter.Music") }
  /// Photos
  public static var searchFilterPhotos: String  { return L10n.tr("Localizable", "Search.Filter.Photos") }
  /// Videos
  public static var searchFilterVideos: String  { return L10n.tr("Localizable", "Search.Filter.Videos") }
  /// Voice
  public static var searchFilterVoice: String  { return L10n.tr("Localizable", "Search.Filter.Voice") }
  /// %@ %d
  public static func searchGlobalChannel1Countable(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_countable", p1, p2)
  }
  /// %@, %d subscribers
  public static func searchGlobalChannel1Few(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_few", p1, p2)
  }
  /// %@, %d subscribers
  public static func searchGlobalChannel1Many(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_many", p1, p2)
  }
  /// %@, %d subscriber
  public static func searchGlobalChannel1One(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_one", p1, p2)
  }
  /// %@, %d subscribers
  public static func searchGlobalChannel1Other(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_other", p1, p2)
  }
  /// %@, %d subscribers
  public static func searchGlobalChannel1Two(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_two", p1, p2)
  }
  /// %@, %d subscribers
  public static func searchGlobalChannel1Zero(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Channel1_zero", p1, p2)
  }
  /// %@ %d
  public static func searchGlobalGroup1Countable(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_countable", p1, p2)
  }
  /// %@, %d members
  public static func searchGlobalGroup1Few(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_few", p1, p2)
  }
  /// %@, %d members
  public static func searchGlobalGroup1Many(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_many", p1, p2)
  }
  /// %@, %d member
  public static func searchGlobalGroup1One(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_one", p1, p2)
  }
  /// %@, %d members
  public static func searchGlobalGroup1Other(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_other", p1, p2)
  }
  /// %@, %d members
  public static func searchGlobalGroup1Two(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_two", p1, p2)
  }
  /// %@, %d members
  public static func searchGlobalGroup1Zero(_ p1: String, _ p2: Int) -> String {
    return L10n.tr("Localizable", "Search.Global.Group1_zero", p1, p2)
  }
  /// Articles
  public static var searchPopularArticles: String  { return L10n.tr("Localizable", "Search.Popular.Articles") }
  /// Delete
  public static var searchPopularDelete: String  { return L10n.tr("Localizable", "Search.Popular.Delete") }
  /// Saved
  public static var searchPopularSavedMessages: String  { return L10n.tr("Localizable", "Search.Popular.SavedMessages") }
  /// contacts and chats
  public static var searchSeparatorChatsAndContacts: String  { return L10n.tr("Localizable", "Search.Separator.ChatsAndContacts") }
  /// global search
  public static var searchSeparatorGlobalPeers: String  { return L10n.tr("Localizable", "Search.Separator.GlobalPeers") }
  /// messages
  public static var searchSeparatorMessages: String  { return L10n.tr("Localizable", "Search.Separator.Messages") }
  /// People
  public static var searchSeparatorPopular: String  { return L10n.tr("Localizable", "Search.Separator.Popular") }
  /// Recent
  public static var searchSeparatorRecent: String  { return L10n.tr("Localizable", "Search.Separator.Recent") }
  /// Search
  public static var searchFieldSearch: String  { return L10n.tr("Localizable", "SearchField.Search") }
  /// Off
  public static var secretTimerOff: String  { return L10n.tr("Localizable", "SecretTimer.Off") }
  /// Sorry, your Telegram app is out of date and can’t handle this request. Please update Telegram.
  public static var secureIdAppVersionOutdated: String  { return L10n.tr("Localizable", "SecureId.AppVersionOutdated") }
  /// Please correct errors
  public static var secureIdCorrectErrors: String  { return L10n.tr("Localizable", "SecureId.CorrectErrors") }
  /// Delete Address
  public static var secureIdDeleteAddress: String  { return L10n.tr("Localizable", "SecureId.DeleteAddress") }
  /// Delete Document
  public static var secureIdDeleteIdentity: String  { return L10n.tr("Localizable", "SecureId.DeleteIdentity") }
  /// Delete Telegram Passport
  public static var secureIdDeletePassport: String  { return L10n.tr("Localizable", "SecureId.DeletePassport") }
  /// Email Address
  public static var secureIdEmail: String  { return L10n.tr("Localizable", "SecureId.Email") }
  /// Identity Document
  public static var secureIdIdentityDocument: String  { return L10n.tr("Localizable", "SecureId.IdentityDocument") }
  /// With Telegram Passport you can easily sign up for websites and services that require identity veritification.\n\nYour information, personal data, and documents are protected by end-to-end encryption. Nobody including Telegram, can access them without your permission.
  public static var secureIdInfo: String  { return L10n.tr("Localizable", "SecureId.Info") }
  /// Please log in to your account to use Telegram Passport
  public static var secureIdLoginText: String  { return L10n.tr("Localizable", "SecureId.LoginText") }
  /// Phone Number
  public static var secureIdPhoneNumber: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber") }
  /// Password Recovery
  public static var secureIdRecoverPassword: String  { return L10n.tr("Localizable", "SecureId.RecoverPassword") }
  /// Delete Email Address?
  public static var secureIdRemoveEmail: String  { return L10n.tr("Localizable", "SecureId.RemoveEmail") }
  /// Delete Phone Number?
  public static var secureIdRemovePhoneNumber: String  { return L10n.tr("Localizable", "SecureId.RemovePhoneNumber") }
  /// Residential Address
  public static var secureIdResidentialAddress: String  { return L10n.tr("Localizable", "SecureId.ResidentialAddress") }
  /// Scan %d
  public static func secureIdScanNumber(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.ScanNumber", p1)
  }
  /// Upload Additional Scan
  public static var secureIdUploadAdditionalScan: String  { return L10n.tr("Localizable", "SecureId.UploadAdditionalScan") }
  /// Upload Scan
  public static var secureIdUploadScan: String  { return L10n.tr("Localizable", "SecureId.UploadScan") }
  /// You are sending your documents directly to **%@** and allowing their **%@** to send you messages.
  public static func secureIdAcceptHelp(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "SecureId.Accept.Help", p1, p2)
  }
  /// You accept the [Login Widget Example Privacy Policy](_applyPolicy_) and allow their **%@** to send you messages.
  public static func secureIdAcceptPolicy(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.Accept.Policy", p1)
  }
  /// Add Bank Statement
  public static var secureIdAddBankStatement: String  { return L10n.tr("Localizable", "SecureId.Add.BankStatement") }
  /// Add Driver's License
  public static var secureIdAddDriverLicense: String  { return L10n.tr("Localizable", "SecureId.Add.DriverLicense") }
  /// Add Identity Card
  public static var secureIdAddID: String  { return L10n.tr("Localizable", "SecureId.Add.ID") }
  /// Add Internal Passport
  public static var secureIdAddInternalPassport: String  { return L10n.tr("Localizable", "SecureId.Add.InternalPassport") }
  /// Add Passport
  public static var secureIdAddPassport: String  { return L10n.tr("Localizable", "SecureId.Add.Passport") }
  /// Add Passport Registration
  public static var secureIdAddPassportRegistration: String  { return L10n.tr("Localizable", "SecureId.Add.PassportRegistration") }
  /// Add Personal Details
  public static var secureIdAddPersonalDetails: String  { return L10n.tr("Localizable", "SecureId.Add.PersonalDetails") }
  /// Add Rental Agreement
  public static var secureIdAddRentalAgreement: String  { return L10n.tr("Localizable", "SecureId.Add.RentalAgreement") }
  /// Add Residential Address
  public static var secureIdAddResidentialAddress: String  { return L10n.tr("Localizable", "SecureId.Add.ResidentialAddress") }
  /// Add Temporary Registration
  public static var secureIdAddTemporaryRegistration: String  { return L10n.tr("Localizable", "SecureId.Add.TemporaryRegistration") }
  /// Add Tenancy Agreement
  public static var secureIdAddTenancyAgreement: String  { return L10n.tr("Localizable", "SecureId.Add.TenancyAgreement") }
  /// Add Utility Bill
  public static var secureIdAddUtilityBill: String  { return L10n.tr("Localizable", "SecureId.Add.UtilityBill") }
  /// ADDRESS
  public static var secureIdAddressHeader: String  { return L10n.tr("Localizable", "SecureId.Address.Header") }
  /// %d
  public static func secureIdAddressScansCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_countable", p1)
  }
  /// %d scans
  public static func secureIdAddressScansFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_few", p1)
  }
  /// %d scans
  public static func secureIdAddressScansMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_many", p1)
  }
  /// %d scan
  public static func secureIdAddressScansOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_one", p1)
  }
  /// %d scans
  public static func secureIdAddressScansOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_other", p1)
  }
  /// %d scans
  public static func secureIdAddressScansTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_two", p1)
  }
  /// %d scans
  public static func secureIdAddressScansZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "SecureId.Address.Scans_zero", p1)
  }
  /// City
  public static var secureIdAddressCityInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.City.InputPlaceholder") }
  /// City
  public static var secureIdAddressCityPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.City.Placeholder") }
  /// Country
  public static var secureIdAddressCountryPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Country.Placeholder") }
  /// Postcode
  public static var secureIdAddressPostcodeInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Postcode.InputPlaceholder") }
  /// Postcode
  public static var secureIdAddressPostcodePlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Postcode.Placeholder") }
  /// State/Republic/Region
  public static var secureIdAddressRegionInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Region.InputPlaceholder") }
  /// Region
  public static var secureIdAddressRegionPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Region.Placeholder") }
  /// Street and Number, PO Box
  public static var secureIdAddressStreetInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Street.InputPlaceholder") }
  /// Street
  public static var secureIdAddressStreetPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Street.Placeholder") }
  /// Apt, suite, unit, building, floor
  public static var secureIdAddressStreet1InputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Address.Street1.InputPlaceholder") }
  /// Are you sure you want to stop the authorization process?
  public static var secureIdConfirmCancel: String  { return L10n.tr("Localizable", "SecureId.Confirm.Cancel") }
  /// Delete Address
  public static var secureIdConfirmDeleteAddress: String  { return L10n.tr("Localizable", "SecureId.Confirm.DeleteAddress") }
  /// Are you sure you want to delete this document?
  public static var secureIdConfirmDeleteDocument: String  { return L10n.tr("Localizable", "SecureId.Confirm.DeleteDocument") }
  /// Please create a password to protect your passport info. You will also be asked to enter it when you log in to Telegram.
  public static var secureIdCreatePasswordDescription: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Description") }
  /// PASSWORD
  public static var secureIdCreatePasswordHeader: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Header") }
  /// Please create a password which will be used to encrypt your personal data.\n\nThis password will also be required whenever you log in to Telegram on a new device.
  public static var secureIdCreatePasswordIntro: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Intro") }
  /// Enter your password
  public static var secureIdCreatePasswordPasswordInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.PasswordInputPlaceholder") }
  /// Password
  public static var secureIdCreatePasswordPasswordPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.PasswordPlaceholder") }
  /// Re-Enter your password
  public static var secureIdCreatePasswordRePasswordInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.RePasswordInputPlaceholder") }
  /// Password & E-Mail
  public static var secureIdCreatePasswordTitle: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Title") }
  /// Please add your valid e-mail. It is the only way to recover a forgotten password.
  public static var secureIdCreatePasswordEmailDescription: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Email.Description") }
  /// RECOVERY E-MAIL
  public static var secureIdCreatePasswordEmailHeader: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Email.Header") }
  /// Your E-Mail
  public static var secureIdCreatePasswordEmailInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Email.InputPlaceholder") }
  /// E-Mail
  public static var secureIdCreatePasswordEmailPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Email.Placeholder") }
  /// HINT
  public static var secureIdCreatePasswordHintHeader: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Hint.Header") }
  /// Hint for your password
  public static var secureIdCreatePasswordHintInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Hint.InputPlaceholder") }
  /// Hint
  public static var secureIdCreatePasswordHintPlaceholder: String  { return L10n.tr("Localizable", "SecureId.CreatePassword.Hint.Placeholder") }
  /// **%@ requests access to your personal data**\nto sign you up for their services
  public static func secureIdCreatePasswordIntroHeader(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.CreatePassword.Intro.Header", p1)
  }
  /// Delete Personal Details
  public static var secureIdDeletePersonalDetails: String  { return L10n.tr("Localizable", "SecureId.Delete.PersonalDetails") }
  /// Are you sure you want to delete personal details?
  public static var secureIdDeleteConfirmPersonalDetails: String  { return L10n.tr("Localizable", "SecureId.Delete.Confirm.PersonalDetails") }
  /// Discard Changes
  public static var secureIdDiscardChangesHeader: String  { return L10n.tr("Localizable", "SecureId.DiscardChanges.Header") }
  /// Are you sure you want to discard all changes?
  public static var secureIdDiscardChangesText: String  { return L10n.tr("Localizable", "SecureId.DiscardChanges.Text") }
  /// Edit Bank Statement
  public static var secureIdEditBankStatement: String  { return L10n.tr("Localizable", "SecureId.Edit.BankStatement") }
  /// Edit Driver's License
  public static var secureIdEditDriverLicense: String  { return L10n.tr("Localizable", "SecureId.Edit.DriverLicense") }
  /// Edit Identity Card
  public static var secureIdEditID: String  { return L10n.tr("Localizable", "SecureId.Edit.ID") }
  /// Edit Internal Passport
  public static var secureIdEditInternalPassport: String  { return L10n.tr("Localizable", "SecureId.Edit.InternalPassport") }
  /// Edit Passport
  public static var secureIdEditPassport: String  { return L10n.tr("Localizable", "SecureId.Edit.Passport") }
  /// Edit Passport Registration
  public static var secureIdEditPassportRegistration: String  { return L10n.tr("Localizable", "SecureId.Edit.PassportRegistration") }
  /// Edit Personal Details
  public static var secureIdEditPersonalDetails: String  { return L10n.tr("Localizable", "SecureId.Edit.PersonalDetails") }
  /// Edit Rental Agreement
  public static var secureIdEditRentalAgreement: String  { return L10n.tr("Localizable", "SecureId.Edit.RentalAgreement") }
  /// Edit Residential Address
  public static var secureIdEditResidentialAddress: String  { return L10n.tr("Localizable", "SecureId.Edit.ResidentialAddress") }
  /// Edit Temporary Registration
  public static var secureIdEditTemporaryRegistration: String  { return L10n.tr("Localizable", "SecureId.Edit.TemporaryRegistration") }
  /// Edit Tenancy Agreement
  public static var secureIdEditTenancyAgreement: String  { return L10n.tr("Localizable", "SecureId.Edit.TenancyAgreement") }
  /// Edit Utility Bill
  public static var secureIdEditUtilityBill: String  { return L10n.tr("Localizable", "SecureId.Edit.UtilityBill") }
  /// Use %@
  public static func secureIdEmailUseSame(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.Email.UseSame", p1)
  }
  /// Enter your e-mail
  public static var secureIdEmailEmailInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Email.Email.InputPlaceholder") }
  /// E-Mail
  public static var secureIdEmailEmailPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Email.Email.Placeholder") }
  /// Note: You will receive a confirmation code to the e-mail address you provide.
  public static var secureIdEmailUseSameDesc: String  { return L10n.tr("Localizable", "SecureId.Email.UseSame.Desc") }
  /// Please enter the confirmation code we've just sent to %@.
  public static func secureIdEmailActivateDescription(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.EmailActivate.Description", p1)
  }
  /// Enter code
  public static var secureIdEmailActivateCodeInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.EmailActivate.Code.InputPlaceholder") }
  /// Code
  public static var secureIdEmailActivateCodePlaceholder: String  { return L10n.tr("Localizable", "SecureId.EmailActivate.Code.Placeholder") }
  /// Provide your address
  public static var secureIdEmptyDescriptionAddress: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.Address") }
  /// Upload a scan of your bank statement
  public static var secureIdEmptyDescriptionBankStatement: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.BankStatement") }
  /// Upload a scan of your driver's license
  public static var secureIdEmptyDescriptionDriversLicense: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.DriversLicense") }
  /// Upload a scan of your identity card
  public static var secureIdEmptyDescriptionIdentityCard: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.IdentityCard") }
  /// Upload a scan of your internal passport
  public static var secureIdEmptyDescriptionInternalPassport: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.InternalPassport") }
  /// Upload a scan of your passport
  public static var secureIdEmptyDescriptionPassport: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.Passport") }
  /// Upload a scan of your passport registration
  public static var secureIdEmptyDescriptionPassportRegistration: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.PassportRegistration") }
  /// Fill in your personal details
  public static var secureIdEmptyDescriptionPersonalDetails: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.PersonalDetails") }
  /// Upload a scan of your temporary registration
  public static var secureIdEmptyDescriptionTemporaryRegistration: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.TemporaryRegistration") }
  /// Upload a scan of your tenancy agreement
  public static var secureIdEmptyDescriptionTenancyAgreement: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.TenancyAgreement") }
  /// Upload a scan of your utility bill
  public static var secureIdEmptyDescriptionUtilityBill: String  { return L10n.tr("Localizable", "SecureId.EmptyDescription.UtilityBill") }
  /// You can't upload more than 20 files
  public static var secureIdErrorScansLimit: String  { return L10n.tr("Localizable", "SecureId.Error.ScansLimit") }
  /// %@%% Uploaded
  public static func secureIdFileUploadProgress(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.FileUpload.Progress", p1)
  }
  /// Female
  public static var secureIdGenderFemale: String  { return L10n.tr("Localizable", "SecureId.Gender.Female") }
  /// Male
  public static var secureIdGenderMale: String  { return L10n.tr("Localizable", "SecureId.Gender.Male") }
  /// Bank Statement
  public static var secureIdIdentityBankStatement: String  { return L10n.tr("Localizable", "SecureId.Identity.BankStatement") }
  /// DOCUMENT DETAILS
  public static var secureIdIdentityDocumentDetailsHeader: String  { return L10n.tr("Localizable", "SecureId.Identity.DocumentDetailsHeader") }
  /// Driver's License
  public static var secureIdIdentityDriverLicense: String  { return L10n.tr("Localizable", "SecureId.Identity.DriverLicense") }
  /// Identity Card
  public static var secureIdIdentityId: String  { return L10n.tr("Localizable", "SecureId.Identity.Id") }
  /// Enter your name using the Latin alphabet
  public static var secureIdIdentityNameInLatine: String  { return L10n.tr("Localizable", "SecureId.Identity.NameInLatine") }
  /// Passport
  public static var secureIdIdentityPassport: String  { return L10n.tr("Localizable", "SecureId.Identity.Passport") }
  /// Passport Registration
  public static var secureIdIdentityPassportRegistration: String  { return L10n.tr("Localizable", "SecureId.Identity.PassportRegistration") }
  /// Selfie
  public static var secureIdIdentitySelfie: String  { return L10n.tr("Localizable", "SecureId.Identity.Selfie") }
  /// Upload a photo of yourself holding your document. Make sure the ID and your face are clearly visible.
  public static var secureIdIdentitySelfieHelp: String  { return L10n.tr("Localizable", "SecureId.Identity.SelfieHelp") }
  /// SELFIE VERIFICATION
  public static var secureIdIdentitySelfieTitle: String  { return L10n.tr("Localizable", "SecureId.Identity.SelfieTitle") }
  /// Add Selfie
  public static var secureIdIdentitySelfieUpload: String  { return L10n.tr("Localizable", "SecureId.Identity.SelfieUpload") }
  /// Retake Selfie
  public static var secureIdIdentitySelfieUploadNew: String  { return L10n.tr("Localizable", "SecureId.Identity.SelfieUploadNew") }
  /// Tenancy Agreement
  public static var secureIdIdentityTenancyAgreement: String  { return L10n.tr("Localizable", "SecureId.Identity.TenancyAgreement") }
  /// Utility Bill
  public static var secureIdIdentityUtilityBill: String  { return L10n.tr("Localizable", "SecureId.Identity.UtilityBill") }
  /// Card ID
  public static var secureIdIdentityCardIdInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.CardId.InputPlaceholder") }
  /// Card ID
  public static var secureIdIdentityCardIdPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.CardId.Placeholder") }
  /// Name
  public static var secureIdIdentityInputPlaceholderFirstName: String  { return L10n.tr("Localizable", "SecureId.Identity.InputPlaceholder.FirstName") }
  /// Surname
  public static var secureIdIdentityInputPlaceholderLastName: String  { return L10n.tr("Localizable", "SecureId.Identity.InputPlaceholder.LastName") }
  /// Middle Name
  public static var secureIdIdentityInputPlaceholderMiddleName: String  { return L10n.tr("Localizable", "SecureId.Identity.InputPlaceholder.MiddleName") }
  /// License ID
  public static var secureIdIdentityLicenseInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.License.InputPlaceholder") }
  /// License ID
  public static var secureIdIdentityLicensePlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.License.Placeholder") }
  /// Document №
  public static var secureIdIdentityPassportInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.Passport.InputPlaceholder") }
  /// Document №
  public static var secureIdIdentityPassportPlaceholder: String  { return L10n.tr("Localizable", "SecureId.Identity.Passport.Placeholder") }
  /// Birthday
  public static var secureIdIdentityPlaceholderBirthday: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.Birthday") }
  /// Citizenship
  public static var secureIdIdentityPlaceholderCitizenship: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.Citizenship") }
  /// Country
  public static var secureIdIdentityPlaceholderCountry: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.Country") }
  /// Expiry Date
  public static var secureIdIdentityPlaceholderExpiryDate: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.ExpiryDate") }
  /// Name
  public static var secureIdIdentityPlaceholderFirstName: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.FirstName") }
  /// Gender
  public static var secureIdIdentityPlaceholderGender: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.Gender") }
  /// Issue Date
  public static var secureIdIdentityPlaceholderIssuedDate: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.IssuedDate") }
  /// Surname
  public static var secureIdIdentityPlaceholderLastName: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.LastName") }
  /// Middle Name
  public static var secureIdIdentityPlaceholderMiddleName: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.MiddleName") }
  /// Residence
  public static var secureIdIdentityPlaceholderResidence: String  { return L10n.tr("Localizable", "SecureId.Identity.Placeholder.Residence") }
  /// The document must contain your first and last name, your residential address, a stamp / barcode / QR code / logo, and issue date, no more than 3 month ago.
  public static var secureIdIdentityScanDescription: String  { return L10n.tr("Localizable", "SecureId.IdentityScan.Description") }
  /// Are you sure you want to delete your Telegram Passport? All details will be lost.
  public static var secureIdInfoDeletePassport: String  { return L10n.tr("Localizable", "SecureId.Info.DeletePassport") }
  /// More Info
  public static var secureIdInfoMore: String  { return L10n.tr("Localizable", "SecureId.Info.More") }
  /// What is Telegram Passport?
  public static var secureIdInfoTitle: String  { return L10n.tr("Localizable", "SecureId.Info.Title") }
  /// Please use latin characters only
  public static var secureIdInputErrorLatinOnly: String  { return L10n.tr("Localizable", "SecureId.InputError.LatinOnly") }
  /// Please enter your password to access your personal data
  public static var secureIdInsertPasswordDescription: String  { return L10n.tr("Localizable", "SecureId.InsertPassword.Description") }
  /// Next
  public static var secureIdInsertPasswordNext: String  { return L10n.tr("Localizable", "SecureId.InsertPassword.Next") }
  /// Enter your password
  public static var secureIdInsertPasswordPassword: String  { return L10n.tr("Localizable", "SecureId.InsertPassword.Password") }
  /// Please enter your Telegram password to decrypt your data
  public static var secureIdInsertPasswordSettingsDescription: String  { return L10n.tr("Localizable", "SecureId.InsertPassword.Settings.Description") }
  /// E-Mail
  public static var secureIdInstallEmailTitle: String  { return L10n.tr("Localizable", "SecureId.InstallEmail.Title") }
  /// Phone Number
  public static var secureIdInstallPhoneTitle: String  { return L10n.tr("Localizable", "SecureId.InstallPhone.Title") }
  /// YOUR NAME IN %@
  public static func secureIdNameNativeHeader(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.NameNative.Header", p1)
  }
  /// NAME IN COUNTRY OF RESIDENCE
  public static var secureIdNameNativeHeaderEmpty: String  { return L10n.tr("Localizable", "SecureId.NameNative.HeaderEmpty") }
  /// Your name in the language of your country of residence
  public static var secureIdNameNativeDescEmpty: String  { return L10n.tr("Localizable", "SecureId.NameNative.Desc.Empty") }
  /// Your name in the language of your country of residence (%@).
  public static func secureIdNameNativeDescLanguage(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.NameNative.Desc.Language", p1)
  }
  /// Invalid password. Please try again
  public static var secureIdPasswordErrorInvalid: String  { return L10n.tr("Localizable", "SecureId.Password.Error.Invalid") }
  /// Limit exceeded. Please try again later
  public static var secureIdPasswordErrorLimit: String  { return L10n.tr("Localizable", "SecureId.Password.Error.Limit") }
  /// OR ENTER ANOTHER PHONE NUMBER
  public static var secureIdPhoneNumberHeader: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber.Header") }
  /// Note: You will receive a confirmation code on the phone number you provide.
  public static var secureIdPhoneNumberNote: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber.Note") }
  /// Use %@
  public static func secureIdPhoneNumberUseSame(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.PhoneNumber.UseSame", p1)
  }
  /// Please enter the confirmation code we've just sent to %@ via SMS
  public static func secureIdPhoneNumberConfirmCodeDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.PhoneNumber.ConfirmCode.Desc", p1)
  }
  /// Enter the code
  public static var secureIdPhoneNumberConfirmCodeInputPlaceholder: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber.ConfirmCode.InputPlaceholder") }
  /// Code
  public static var secureIdPhoneNumberConfirmCodePlaceholder: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber.ConfirmCode.Placeholder") }
  /// Use the phone number you use for Telegram
  public static var secureIdPhoneNumberUseSameDesc: String  { return L10n.tr("Localizable", "SecureId.PhoneNumber.UseSame.Desc") }
  /// Code was sent to %@
  public static func secureIdRecoverPasswordSentEmailCode(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.RecoverPassword.SentEmailCode", p1)
  }
  /// Authorize
  public static var secureIdRequestAccept: String  { return L10n.tr("Localizable", "SecureId.Request.Accept") }
  /// Create a Password
  public static var secureIdRequestCreatePassword: String  { return L10n.tr("Localizable", "SecureId.Request.CreatePassword") }
  /// **%@** requests access to your personal data to sign you up for their services.
  public static func secureIdRequestHeader1(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.Request.Header1", p1)
  }
  /// Bank Statement
  public static var secureIdRequestPermissionBankStatement: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.BankStatement") }
  /// Driver's License
  public static var secureIdRequestPermissionDriversLicense: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.DriversLicense") }
  /// E-Mail
  public static var secureIdRequestPermissionEmail: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Email") }
  /// Identity Card
  public static var secureIdRequestPermissionIDCard: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.IDCard") }
  /// Identity Document
  public static var secureIdRequestPermissionIdentityDocument: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.IdentityDocument") }
  /// Internal Passport
  public static var secureIdRequestPermissionInternalPassport: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.InternalPassport") }
  /// Passport
  public static var secureIdRequestPermissionPassport: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Passport") }
  /// Passport Registration
  public static var secureIdRequestPermissionPassportRegistration: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.PassportRegistration") }
  /// Personal Details
  public static var secureIdRequestPermissionPersonalDetails: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.PersonalDetails") }
  /// Phone Number
  public static var secureIdRequestPermissionPhone: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Phone") }
  /// Residential Address
  public static var secureIdRequestPermissionResidentialAddress: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.ResidentialAddress") }
  /// Temporary Registration
  public static var secureIdRequestPermissionTemporaryRegistration: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.TemporaryRegistration") }
  /// Tenancy Agreement
  public static var secureIdRequestPermissionTenancyAgreement: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.TenancyAgreement") }
  /// Utility Bill
  public static var secureIdRequestPermissionUtilityBill: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.UtilityBill") }
  /// Upload proof of your address
  public static var secureIdRequestPermissionAddressEmpty: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Address.Empty") }
  /// Provide your contact email address
  public static var secureIdRequestPermissionEmailEmpty: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Email.Empty") }
  /// Upload a scan of your passport or other ID
  public static var secureIdRequestPermissionIdentityEmpty: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Identity.Empty") }
  /// Provide your contact phone number
  public static var secureIdRequestPermissionPhoneEmpty: String  { return L10n.tr("Localizable", "SecureId.Request.Permission.Phone.Empty") }
  /// %@ or %@
  public static func secureIdRequestTwoDocumentsTitle(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "SecureId.Request.TwoDocuments.Title", p1, p2)
  }
  /// Upload a selfie with your document
  public static var secureIdRequestUploadSelfie: String  { return L10n.tr("Localizable", "SecureId.Request.Upload.Selfie") }
  /// Upload a translation of your document
  public static var secureIdRequestUploadTranslation: String  { return L10n.tr("Localizable", "SecureId.Request.Upload.Translation") }
  /// REQUESTED INFORMATION
  public static var secureIdRequestedInformationHeader: String  { return L10n.tr("Localizable", "SecureId.RequestedInformation.Header") }
  /// SCANS
  public static var secureIdScansHeader: String  { return L10n.tr("Localizable", "SecureId.Scans.Header") }
  /// Upload scans of a certified English translation of the document.
  public static var secureIdTranslationDesc: String  { return L10n.tr("Localizable", "SecureId.Translation.Desc") }
  /// TRANSLATION
  public static var secureIdTranslationHeader: String  { return L10n.tr("Localizable", "SecureId.Translation.Header") }
  /// Upload a photo of the front side of the document
  public static var secureIdUploadFront: String  { return L10n.tr("Localizable", "SecureId.Upload.Front") }
  /// Upload the main page of the document
  public static var secureIdUploadMain: String  { return L10n.tr("Localizable", "SecureId.Upload.Main") }
  /// Upload a photo of the reverse side of the document
  public static var secureIdUploadReverse: String  { return L10n.tr("Localizable", "SecureId.Upload.Reverse") }
  /// Upload a selfie of yourself holding the document
  public static var secureIdUploadSelfie: String  { return L10n.tr("Localizable", "SecureId.Upload.Selfie") }
  /// Front Side
  public static var secureIdUploadTitleFrontSide: String  { return L10n.tr("Localizable", "SecureId.Upload.Title.FrontSide") }
  /// Main Page
  public static var secureIdUploadTitleMainPage: String  { return L10n.tr("Localizable", "SecureId.Upload.Title.MainPage") }
  /// Reverse Side
  public static var secureIdUploadTitleReverseSide: String  { return L10n.tr("Localizable", "SecureId.Upload.Title.ReverseSide") }
  /// Upload a scan of %@ or %@
  public static func secureIdUploadScanMulti(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "SecureId.UploadScan.Multi", p1, p2)
  }
  /// Upload a scan of %@
  public static func secureIdUploadScanSingle(_ p1: String) -> String {
    return L10n.tr("Localizable", "SecureId.UploadScan.Single", p1)
  }
  /// Warning! All data saved in your Telegram passport will be lost!
  public static var secureIdWarningDataLost: String  { return L10n.tr("Localizable", "SecureId.Warning.DataLost") }
  /// Since you didn't provide a recovery email when setting up your password, your remaining options are either to remember your password or to reset your account.
  public static var secureIdForgotPasswordNoEmail: String  { return L10n.tr("Localizable", "SecureId.forgotPassword.NoEmail") }
  /// None
  public static var selectAreaControlDimensionNone: String  { return L10n.tr("Localizable", "SelectAreaControl.Dimension.None") }
  /// Original
  public static var selectAreaControlDimensionOriginal: String  { return L10n.tr("Localizable", "SelectAreaControl.Dimension.Original") }
  /// Square
  public static var selectAreaControlDimensionSquare: String  { return L10n.tr("Localizable", "SelectAreaControl.Dimension.Square") }
  /// Search Members
  public static var selectPeersTitleSearchMembers: String  { return L10n.tr("Localizable", "SelectPeers.Title.SearchMembers") }
  /// Select Chat
  public static var selectPeersTitleSelectChat: String  { return L10n.tr("Localizable", "SelectPeers.Title.SelectChat") }
  /// clear
  public static var separatorClear: String  { return L10n.tr("Localizable", "Separator.Clear") }
  /// show less
  public static var separatorShowLess: String  { return L10n.tr("Localizable", "Separator.ShowLess") }
  /// show more
  public static var separatorShowMore: String  { return L10n.tr("Localizable", "Separator.ShowMore") }
  /// %@ sent you a self-destructing photo. Please view it on your mobile.
  public static func serviceMessageDesturctingPhoto(_ p1: String) -> String {
    return L10n.tr("Localizable", "ServiceMessage.DesturctingPhoto", p1)
  }
  /// %@ sent you a self-destructing video. Please view it on your mobile device.
  public static func serviceMessageDesturctingVideo(_ p1: String) -> String {
    return L10n.tr("Localizable", "ServiceMessage.DesturctingVideo", p1)
  }
  /// file has expired
  public static var serviceMessageExpiredFile: String  { return L10n.tr("Localizable", "ServiceMessage.ExpiredFile") }
  /// photo has expired
  public static var serviceMessageExpiredPhoto: String  { return L10n.tr("Localizable", "ServiceMessage.ExpiredPhoto") }
  /// video has expired
  public static var serviceMessageExpiredVideo: String  { return L10n.tr("Localizable", "ServiceMessage.ExpiredVideo") }
  /// %@ sent a self-destructing photo.
  public static func serviceMessageDesturctingPhotoYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "ServiceMessage.DesturctingPhoto.You", p1)
  }
  /// %@ sent a self-destructing video.
  public static func serviceMessageDesturctingVideoYou(_ p1: String) -> String {
    return L10n.tr("Localizable", "ServiceMessage.DesturctingVideo.You", p1)
  }
  /// ACCEPT ON THIS DEVICE
  public static var sessionPreviewAcceptHeader: String  { return L10n.tr("Localizable", "SessionPreview.AcceptHeader") }
  /// Application
  public static var sessionPreviewApp: String  { return L10n.tr("Localizable", "SessionPreview.App") }
  /// IP Address
  public static var sessionPreviewIp: String  { return L10n.tr("Localizable", "SessionPreview.Ip") }
  /// This location estimate is based on the IP address and may not always be accurate.
  public static var sessionPreviewIpDesc: String  { return L10n.tr("Localizable", "SessionPreview.IpDesc") }
  /// Location
  public static var sessionPreviewLocation: String  { return L10n.tr("Localizable", "SessionPreview.Location") }
  /// Terminate Session
  public static var sessionPreviewTerminateSession: String  { return L10n.tr("Localizable", "SessionPreview.TerminateSession") }
  /// Session
  public static var sessionPreviewTitle: String  { return L10n.tr("Localizable", "SessionPreview.Title") }
  /// Incoming Calls
  public static var sessionPreviewAcceptCalls: String  { return L10n.tr("Localizable", "SessionPreview.Accept.Calls") }
  /// Secret Chats
  public static var sessionPreviewAcceptSecret: String  { return L10n.tr("Localizable", "SessionPreview.Accept.Secret") }
  /// ACTIVE SESSIONS
  public static var sessionsActiveSessionsHeader: String  { return L10n.tr("Localizable", "Sessions.ActiveSessionsHeader") }
  /// CURRENT SESSION
  public static var sessionsCurrentSessionHeader: String  { return L10n.tr("Localizable", "Sessions.CurrentSessionHeader") }
  /// Logs out all devices except for this one.
  public static var sessionsTerminateDescription: String  { return L10n.tr("Localizable", "Sessions.TerminateDescription") }
  /// Terminate all other sessions
  public static var sessionsTerminateOthers: String  { return L10n.tr("Localizable", "Sessions.TerminateOthers") }
  /// Search results from Settings and the Telegram FAQ will appear here.
  public static var settingsSearchEmptyItem: String  { return L10n.tr("Localizable", "SettingsSearch.EmptyItem") }
  /// RECENT
  public static var settingsSearchRecent: String  { return L10n.tr("Localizable", "SettingsSearch.Recent") }
  /// clear
  public static var settingsSearchRecentClear: String  { return L10n.tr("Localizable", "SettingsSearch.Recent.Clear") }
  ///  
  public static var settingsSearchSynonymsAppLanguage: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.AppLanguage") }
  ///  
  public static var settingsSearchSynonymsFAQ: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.FAQ") }
  ///  
  public static var settingsSearchSynonymsPassport: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Passport") }
  ///  
  public static var settingsSearchSynonymsSavedMessages: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.SavedMessages") }
  /// Support
  public static var settingsSearchSynonymsSupport: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Support") }
  /// Apple Watch
  public static var settingsSearchSynonymsWatch: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Watch") }
  ///  
  public static var settingsSearchSynonymsAppearanceAutoNightTheme: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.AutoNightTheme") }
  /// Wallpaper
  public static var settingsSearchSynonymsAppearanceChatBackground: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.ChatBackground") }
  /// bubbles
  public static var settingsSearchSynonymsAppearanceChatMode: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.ChatMode") }
  ///  
  public static var settingsSearchSynonymsAppearanceColorTheme: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.ColorTheme") }
  /// font
  public static var settingsSearchSynonymsAppearanceTextSize: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.TextSize") }
  ///  
  public static var settingsSearchSynonymsAppearanceTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.Title") }
  ///  
  public static var settingsSearchSynonymsAppearanceChatBackgroundCustom: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.ChatBackground.Custom") }
  ///  
  public static var settingsSearchSynonymsAppearanceChatBackgroundSetColor: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Appearance.ChatBackground.SetColor") }
  ///  
  public static var settingsSearchSynonymsCallsCallTab: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Calls.CallTab") }
  ///  
  public static var settingsSearchSynonymsCallsTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Calls.Title") }
  ///  
  public static var settingsSearchSynonymsDataAutoDownloadReset: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.AutoDownloadReset") }
  ///  
  public static var settingsSearchSynonymsDataAutoDownloadUsingCellular: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.AutoDownloadUsingCellular") }
  ///  
  public static var settingsSearchSynonymsDataAutoDownloadUsingWifi: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.AutoDownloadUsingWifi") }
  ///  
  public static var settingsSearchSynonymsDataAutoplayGifs: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.AutoplayGifs") }
  ///  
  public static var settingsSearchSynonymsDataAutoplayVideos: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.AutoplayVideos") }
  ///  
  public static var settingsSearchSynonymsDataCallsUseLessData: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.CallsUseLessData") }
  ///  
  public static var settingsSearchSynonymsDataDownloadInBackground: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.DownloadInBackground") }
  ///  
  public static var settingsSearchSynonymsDataNetworkUsage: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.NetworkUsage") }
  ///  
  public static var settingsSearchSynonymsDataSaveEditedPhotos: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.SaveEditedPhotos") }
  ///  
  public static var settingsSearchSynonymsDataSaveIncomingPhotos: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.SaveIncomingPhotos") }
  ///  
  public static var settingsSearchSynonymsDataTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.Title") }
  ///  
  public static var settingsSearchSynonymsDataStorageClearCache: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.Storage.ClearCache") }
  ///  
  public static var settingsSearchSynonymsDataStorageKeepMedia: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.Storage.KeepMedia") }
  /// Cache
  public static var settingsSearchSynonymsDataStorageTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Data.Storage.Title") }
  ///  
  public static var settingsSearchSynonymsEditProfileAddAccount: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.AddAccount") }
  ///  
  public static var settingsSearchSynonymsEditProfileBio: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.Bio") }
  ///  
  public static var settingsSearchSynonymsEditProfileLogout: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.Logout") }
  ///  
  public static var settingsSearchSynonymsEditProfilePhoneNumber: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.PhoneNumber") }
  ///  
  public static var settingsSearchSynonymsEditProfileTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.Title") }
  /// nickname
  public static var settingsSearchSynonymsEditProfileUsername: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.EditProfile.Username") }
  ///  
  public static var settingsSearchSynonymsNotificationsBadgeCountUnreadMessages: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.BadgeCountUnreadMessages") }
  ///  
  public static var settingsSearchSynonymsNotificationsBadgeIncludeMutedChannels: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedChannels") }
  ///  
  public static var settingsSearchSynonymsNotificationsBadgeIncludeMutedChats: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedChats") }
  ///  
  public static var settingsSearchSynonymsNotificationsBadgeIncludeMutedPublicGroups: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.BadgeIncludeMutedPublicGroups") }
  ///  
  public static var settingsSearchSynonymsNotificationsChannelNotificationsAlert: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ChannelNotificationsAlert") }
  ///  
  public static var settingsSearchSynonymsNotificationsChannelNotificationsExceptions: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ChannelNotificationsExceptions") }
  ///  
  public static var settingsSearchSynonymsNotificationsChannelNotificationsPreview: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ChannelNotificationsPreview") }
  ///  
  public static var settingsSearchSynonymsNotificationsChannelNotificationsSound: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ChannelNotificationsSound") }
  ///  
  public static var settingsSearchSynonymsNotificationsContactJoined: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ContactJoined") }
  ///  
  public static var settingsSearchSynonymsNotificationsDisplayNamesOnLockScreen: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.DisplayNamesOnLockScreen") }
  ///  
  public static var settingsSearchSynonymsNotificationsGroupNotificationsAlert: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.GroupNotificationsAlert") }
  ///  
  public static var settingsSearchSynonymsNotificationsGroupNotificationsExceptions: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.GroupNotificationsExceptions") }
  ///  
  public static var settingsSearchSynonymsNotificationsGroupNotificationsPreview: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.GroupNotificationsPreview") }
  ///  
  public static var settingsSearchSynonymsNotificationsGroupNotificationsSound: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.GroupNotificationsSound") }
  ///  
  public static var settingsSearchSynonymsNotificationsInAppNotificationsPreview: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.InAppNotificationsPreview") }
  ///  
  public static var settingsSearchSynonymsNotificationsInAppNotificationsSound: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.InAppNotificationsSound") }
  ///  
  public static var settingsSearchSynonymsNotificationsInAppNotificationsVibrate: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.InAppNotificationsVibrate") }
  ///  
  public static var settingsSearchSynonymsNotificationsMessageNotificationsAlert: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.MessageNotificationsAlert") }
  ///  
  public static var settingsSearchSynonymsNotificationsMessageNotificationsExceptions: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.MessageNotificationsExceptions") }
  ///  
  public static var settingsSearchSynonymsNotificationsMessageNotificationsPreview: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.MessageNotificationsPreview") }
  ///  
  public static var settingsSearchSynonymsNotificationsMessageNotificationsSound: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.MessageNotificationsSound") }
  ///  
  public static var settingsSearchSynonymsNotificationsResetAllNotifications: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.ResetAllNotifications") }
  ///  
  public static var settingsSearchSynonymsNotificationsTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Notifications.Title") }
  ///  
  public static var settingsSearchSynonymsPrivacyAuthSessions: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.AuthSessions") }
  ///  
  public static var settingsSearchSynonymsPrivacyBlockedUsers: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.BlockedUsers") }
  ///  
  public static var settingsSearchSynonymsPrivacyCalls: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Calls") }
  ///  
  public static var settingsSearchSynonymsPrivacyDeleteAccountIfAwayFor: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.DeleteAccountIfAwayFor") }
  ///  
  public static var settingsSearchSynonymsPrivacyForwards: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Forwards") }
  ///  
  public static var settingsSearchSynonymsPrivacyGroupsAndChannels: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.GroupsAndChannels") }
  ///  
  public static var settingsSearchSynonymsPrivacyLastSeen: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.LastSeen") }
  ///  
  public static var settingsSearchSynonymsPrivacyPasscode: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Passcode") }
  ///  
  public static var settingsSearchSynonymsPrivacyPasscodeAndFaceId: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.PasscodeAndFaceId") }
  ///  
  public static var settingsSearchSynonymsPrivacyPasscodeAndTouchId: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.PasscodeAndTouchId") }
  ///  
  public static var settingsSearchSynonymsPrivacyProfilePhoto: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.ProfilePhoto") }
  ///  
  public static var settingsSearchSynonymsPrivacyTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Title") }
  /// Password
  public static var settingsSearchSynonymsPrivacyTwoStepAuth: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.TwoStepAuth") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataClearPaymentsInfo: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.ClearPaymentsInfo") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataContactsReset: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.ContactsReset") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataContactsSync: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.ContactsSync") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataDeleteDrafts: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.DeleteDrafts") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataSecretChatLinkPreview: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.SecretChatLinkPreview") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.Title") }
  ///  
  public static var settingsSearchSynonymsPrivacyDataTopPeers: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Privacy.Data.TopPeers") }
  ///  
  public static var settingsSearchSynonymsProxyAddProxy: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Proxy.AddProxy") }
  /// SOCKS5\nMTProto
  public static var settingsSearchSynonymsProxyTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Proxy.Title") }
  ///  
  public static var settingsSearchSynonymsProxyUseForCalls: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Proxy.UseForCalls") }
  ///  
  public static var settingsSearchSynonymsStickersArchivedPacks: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Stickers.ArchivedPacks") }
  ///  
  public static var settingsSearchSynonymsStickersFeaturedPacks: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Stickers.FeaturedPacks") }
  ///  
  public static var settingsSearchSynonymsStickersSuggestStickers: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Stickers.SuggestStickers") }
  ///  
  public static var settingsSearchSynonymsStickersTitle: String  { return L10n.tr("Localizable", "SettingsSearch.Synonyms.Stickers.Title") }
  /// Copied to Clipboard
  public static var shareLinkCopied: String  { return L10n.tr("Localizable", "Share.Link.Copied") }
  /// Cancel
  public static var shareExtensionCancel: String  { return L10n.tr("Localizable", "ShareExtension.Cancel") }
  /// Search
  public static var shareExtensionSearch: String  { return L10n.tr("Localizable", "ShareExtension.Search") }
  /// Share
  public static var shareExtensionShare: String  { return L10n.tr("Localizable", "ShareExtension.Share") }
  /// Next
  public static var shareExtensionPasscodeNext: String  { return L10n.tr("Localizable", "ShareExtension.Passcode.Next") }
  /// passcode
  public static var shareExtensionPasscodePlaceholder: String  { return L10n.tr("Localizable", "ShareExtension.Passcode.Placeholder") }
  /// To share via Telegram, please open the Telegam app and log in.
  public static var shareExtensionUnauthorizedDescription: String  { return L10n.tr("Localizable", "ShareExtension.Unauthorized.Description") }
  /// OK
  public static var shareExtensionUnauthorizedOK: String  { return L10n.tr("Localizable", "ShareExtension.Unauthorized.OK") }
  /// Forward to...
  public static var shareModalSearchForwardPlaceholder: String  { return L10n.tr("Localizable", "ShareModal.Search.ForwardPlaceholder") }
  /// Share to...
  public static var shareModalSearchPlaceholder: String  { return L10n.tr("Localizable", "ShareModal.Search.Placeholder") }
  /// CHAT
  public static var shortcutsControllerChat: String  { return L10n.tr("Localizable", "ShortcutsController.Chat") }
  /// GESTURES
  public static var shortcutsControllerGestures: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures") }
  /// MARKDOWN
  public static var shortcutsControllerMarkdown: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown") }
  /// MOUSE
  public static var shortcutsControllerMouse: String  { return L10n.tr("Localizable", "ShortcutsController.Mouse") }
  /// OTHERS
  public static var shortcutsControllerOthers: String  { return L10n.tr("Localizable", "ShortcutsController.Others") }
  /// SEARCH
  public static var shortcutsControllerSearch: String  { return L10n.tr("Localizable", "ShortcutsController.Search") }
  /// Shortcuts
  public static var shortcutsControllerTitle: String  { return L10n.tr("Localizable", "ShortcutsController.Title") }
  /// VIDEO CHAT
  public static var shortcutsControllerVideoChat: String  { return L10n.tr("Localizable", "ShortcutsController.VideoChat") }
  /// Edit Last Message
  public static var shortcutsControllerChatEditLastMessage: String  { return L10n.tr("Localizable", "ShortcutsController.Chat.EditLastMessage") }
  /// Open Info
  public static var shortcutsControllerChatOpenInfo: String  { return L10n.tr("Localizable", "ShortcutsController.Chat.OpenInfo") }
  /// Record Voice/Video Message
  public static var shortcutsControllerChatRecordVoiceMessage: String  { return L10n.tr("Localizable", "ShortcutsController.Chat.RecordVoiceMessage") }
  /// Search Messages
  public static var shortcutsControllerChatSearchMessages: String  { return L10n.tr("Localizable", "ShortcutsController.Chat.SearchMessages") }
  /// Select Message To Reply
  public static var shortcutsControllerChatSelectMessageToReply: String  { return L10n.tr("Localizable", "ShortcutsController.Chat.SelectMessageToReply") }
  /// Chat Actions
  public static var shortcutsControllerGesturesChatAction: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.ChatAction") }
  /// Navigation Back
  public static var shortcutsControllerGesturesNavigation: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Navigation") }
  /// Reply
  public static var shortcutsControllerGesturesReply: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Reply") }
  /// Stickers/Emoji/GIFs Panel
  public static var shortcutsControllerGesturesStickers: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Stickers") }
  /// Swipe both sides
  public static var shortcutsControllerGesturesChatActionValue: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.ChatAction.Value") }
  /// Swipe From Left To Right
  public static var shortcutsControllerGesturesNavigationsValue: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Navigations.Value") }
  /// Swipe From Right To Left
  public static var shortcutsControllerGesturesReplyValue: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Reply.Value") }
  /// Swipe both sides
  public static var shortcutsControllerGesturesStickersValue: String  { return L10n.tr("Localizable", "ShortcutsController.Gestures.Stickers.Value") }
  /// Bold
  public static var shortcutsControllerMarkdownBold: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown.Bold") }
  /// Hyperlink
  public static var shortcutsControllerMarkdownHyperlink: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown.Hyperlink") }
  /// Italic
  public static var shortcutsControllerMarkdownItalic: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown.Italic") }
  /// Monospace
  public static var shortcutsControllerMarkdownMonospace: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown.Monospace") }
  /// Strikethrough
  public static var shortcutsControllerMarkdownStrikethrough: String  { return L10n.tr("Localizable", "ShortcutsController.Markdown.Strikethrough") }
  /// Fast Reply
  public static var shortcutsControllerMouseFastReply: String  { return L10n.tr("Localizable", "ShortcutsController.Mouse.FastReply") }
  /// Schedule a message
  public static var shortcutsControllerMouseScheduleMessage: String  { return L10n.tr("Localizable", "ShortcutsController.Mouse.ScheduleMessage") }
  /// Double Click
  public static var shortcutsControllerMouseFastReplyValue: String  { return L10n.tr("Localizable", "ShortcutsController.Mouse.FastReply.Value") }
  /// Option click on 'Send Message'
  public static var shortcutsControllerMouseScheduleMessageValue: String  { return L10n.tr("Localizable", "ShortcutsController.Mouse.ScheduleMessage.Value") }
  /// Lock by Passcode
  public static var shortcutsControllerOthersLockByPasscode: String  { return L10n.tr("Localizable", "ShortcutsController.Others.LockByPasscode") }
  /// Global Search
  public static var shortcutsControllerSearchGlobalSearch: String  { return L10n.tr("Localizable", "ShortcutsController.Search.GlobalSearch") }
  /// Quick Search
  public static var shortcutsControllerSearchQuickSearch: String  { return L10n.tr("Localizable", "ShortcutsController.Search.QuickSearch") }
  /// Toggle Camera
  public static var shortcutsControllerVideoChatToggleCamera: String  { return L10n.tr("Localizable", "ShortcutsController.VideoChat.ToggleCamera") }
  /// Toggle Screen Share
  public static var shortcutsControllerVideoChatToggleScreencast: String  { return L10n.tr("Localizable", "ShortcutsController.VideoChat.ToggleScreencast") }
  /// The sidebar is only available while chatting
  public static var sidebarAvalability: String  { return L10n.tr("Localizable", "Sidebar.Avalability") }
  /// Hide Panel
  public static var sidebarHide: String  { return L10n.tr("Localizable", "Sidebar.Hide") }
  /// Sidebar is not available in this chat
  public static var sidebarPeerRestricted: String  { return L10n.tr("Localizable", "Sidebar.Peer.Restricted") }
  /// Slow mode is enabled. You can't forward a message with a comment
  public static var slowModeForwardCommentError: String  { return L10n.tr("Localizable", "SlowMode.ForwardComment.Error") }
  /// Slow mode is enabled. You can't send more than one message at a time.
  public static var slowModeMultipleError: String  { return L10n.tr("Localizable", "SlowMode.Multiple.Error") }
  /// Slowmode is Enabled.\nYou can't add comment as addition message.
  public static var slowModePreviewSenderComment: String  { return L10n.tr("Localizable", "SlowMode.PreviewSender.Comment") }
  /// Slowmode is Enabled.\nThere is no way to send multiple files at once.
  public static var slowModePreviewSenderFileTooltip: String  { return L10n.tr("Localizable", "SlowMode.PreviewSender.FileTooltip") }
  /// Slowmode is Enabled.\nThere is no way to send multiple media at once.
  public static var slowModePreviewSenderMediaTooltip: String  { return L10n.tr("Localizable", "SlowMode.PreviewSender.MediaTooltip") }
  /// Slow mode is enabled. This text is too long to send as one message.
  public static var slowModeTooLongError: String  { return L10n.tr("Localizable", "SlowMode.TooLong.Error") }
  /// ACTIONS
  public static var statsGroupActionsTitle: String  { return L10n.tr("Localizable", "Stats.GroupActionsTitle") }
  /// GROWTH
  public static var statsGroupGrowthTitle: String  { return L10n.tr("Localizable", "Stats.GroupGrowthTitle") }
  /// MEMBERS' PRIMARY LANGUAGE
  public static var statsGroupLanguagesTitle: String  { return L10n.tr("Localizable", "Stats.GroupLanguagesTitle") }
  /// Members
  public static var statsGroupMembers: String  { return L10n.tr("Localizable", "Stats.GroupMembers") }
  /// GROUP MEMBERS
  public static var statsGroupMembersTitle: String  { return L10n.tr("Localizable", "Stats.GroupMembersTitle") }
  /// Messages
  public static var statsGroupMessages: String  { return L10n.tr("Localizable", "Stats.GroupMessages") }
  /// MESSAGES
  public static var statsGroupMessagesTitle: String  { return L10n.tr("Localizable", "Stats.GroupMessagesTitle") }
  /// NEW MEMBERS BY SOURCE
  public static var statsGroupNewMembersBySourceTitle: String  { return L10n.tr("Localizable", "Stats.GroupNewMembersBySourceTitle") }
  /// OVERVIEW
  public static var statsGroupOverview: String  { return L10n.tr("Localizable", "Stats.GroupOverview") }
  /// Posting Members
  public static var statsGroupPosters: String  { return L10n.tr("Localizable", "Stats.GroupPosters") }
  /// %d
  public static func statsGroupTopAdminBansCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_countable", p1)
  }
  /// %d bans
  public static func statsGroupTopAdminBansFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_few", p1)
  }
  /// %d bans
  public static func statsGroupTopAdminBansMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_many", p1)
  }
  /// %d ban
  public static func statsGroupTopAdminBansOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_one", p1)
  }
  /// %d bans
  public static func statsGroupTopAdminBansOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_other", p1)
  }
  /// %d bans
  public static func statsGroupTopAdminBansTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_two", p1)
  }
  /// %d bans
  public static func statsGroupTopAdminBansZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminBans_zero", p1)
  }
  /// %d
  public static func statsGroupTopAdminDeletionsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_countable", p1)
  }
  /// %d deletions
  public static func statsGroupTopAdminDeletionsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_few", p1)
  }
  /// %d deletions
  public static func statsGroupTopAdminDeletionsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_many", p1)
  }
  /// %d deletion
  public static func statsGroupTopAdminDeletionsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_one", p1)
  }
  /// %d deletions
  public static func statsGroupTopAdminDeletionsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_other", p1)
  }
  /// %d deletions
  public static func statsGroupTopAdminDeletionsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_two", p1)
  }
  /// %d deletions
  public static func statsGroupTopAdminDeletionsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminDeletions_zero", p1)
  }
  /// %d
  public static func statsGroupTopAdminKicksCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_countable", p1)
  }
  /// %d kicks
  public static func statsGroupTopAdminKicksFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_few", p1)
  }
  /// %d kicks
  public static func statsGroupTopAdminKicksMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_many", p1)
  }
  /// %d kick
  public static func statsGroupTopAdminKicksOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_one", p1)
  }
  /// %d kicks
  public static func statsGroupTopAdminKicksOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_other", p1)
  }
  /// %d kicks
  public static func statsGroupTopAdminKicksTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_two", p1)
  }
  /// %d kicks
  public static func statsGroupTopAdminKicksZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopAdminKicks_zero", p1)
  }
  /// TOP ADMINS
  public static var statsGroupTopAdminsTitle: String  { return L10n.tr("Localizable", "Stats.GroupTopAdminsTitle") }
  /// TOP HOURS
  public static var statsGroupTopHoursTitle: String  { return L10n.tr("Localizable", "Stats.GroupTopHoursTitle") }
  /// %d
  public static func statsGroupTopInviterInvitesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_countable", p1)
  }
  /// %d invitations
  public static func statsGroupTopInviterInvitesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_few", p1)
  }
  /// %d invitations
  public static func statsGroupTopInviterInvitesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_many", p1)
  }
  /// %d invitation
  public static func statsGroupTopInviterInvitesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_one", p1)
  }
  /// %d invitations
  public static func statsGroupTopInviterInvitesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_other", p1)
  }
  /// %d invitations
  public static func statsGroupTopInviterInvitesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_two", p1)
  }
  /// %d invitations
  public static func statsGroupTopInviterInvitesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopInviterInvites_zero", p1)
  }
  /// TOP INVITERS
  public static var statsGroupTopInvitersTitle: String  { return L10n.tr("Localizable", "Stats.GroupTopInvitersTitle") }
  /// %d
  public static func statsGroupTopPosterCharsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_countable", p1)
  }
  /// %d symbols per message
  public static func statsGroupTopPosterCharsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_few", p1)
  }
  /// %d symbols per message
  public static func statsGroupTopPosterCharsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_many", p1)
  }
  /// %d symbol per message
  public static func statsGroupTopPosterCharsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_one", p1)
  }
  /// %d symbols per message
  public static func statsGroupTopPosterCharsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_other", p1)
  }
  /// %d symbols per message
  public static func statsGroupTopPosterCharsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_two", p1)
  }
  /// %d symbols per message
  public static func statsGroupTopPosterCharsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterChars_zero", p1)
  }
  /// %d
  public static func statsGroupTopPosterMessagesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_countable", p1)
  }
  /// %d messages
  public static func statsGroupTopPosterMessagesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_few", p1)
  }
  /// %d messages
  public static func statsGroupTopPosterMessagesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_many", p1)
  }
  /// %d message
  public static func statsGroupTopPosterMessagesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_one", p1)
  }
  /// %d messages
  public static func statsGroupTopPosterMessagesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_other", p1)
  }
  /// %d messages
  public static func statsGroupTopPosterMessagesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_two", p1)
  }
  /// %d messages
  public static func statsGroupTopPosterMessagesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.GroupTopPosterMessages_zero", p1)
  }
  /// TOP MEMBERS
  public static var statsGroupTopPostersTitle: String  { return L10n.tr("Localizable", "Stats.GroupTopPostersTitle") }
  /// TOP DAYS OF WEEK
  public static var statsGroupTopWeekdaysTitle: String  { return L10n.tr("Localizable", "Stats.GroupTopWeekdaysTitle") }
  /// Viewing Members
  public static var statsGroupViewers: String  { return L10n.tr("Localizable", "Stats.GroupViewers") }
  /// INTERACTIONS
  public static var statsMessageInteractionsTitle: String  { return L10n.tr("Localizable", "Stats.MessageInteractionsTitle") }
  /// OVERVIEW
  public static var statsMessageOverview: String  { return L10n.tr("Localizable", "Stats.MessageOverview") }
  /// Private Shares
  public static var statsMessagePrivateForwardsTitle: String  { return L10n.tr("Localizable", "Stats.MessagePrivateForwardsTitle") }
  /// Public Shares
  public static var statsMessagePublicForwardsTitle: String  { return L10n.tr("Localizable", "Stats.MessagePublicForwardsTitle") }
  /// Message Statistics
  public static var statsMessageTitle: String  { return L10n.tr("Localizable", "Stats.MessageTitle") }
  /// %d
  public static func statsShowMoreCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_countable", p1)
  }
  /// Show %d More
  public static func statsShowMoreFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_few", p1)
  }
  /// Show %d More
  public static func statsShowMoreMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_many", p1)
  }
  /// Show %d More
  public static func statsShowMoreOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_one", p1)
  }
  /// Show %d More
  public static func statsShowMoreOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_other", p1)
  }
  /// Show %d More
  public static func statsShowMoreTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_two", p1)
  }
  /// Show %d More
  public static func statsShowMoreZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stats.ShowMore_zero", p1)
  }
  /// Actions
  public static var statsGroupTopAdminActions: String  { return L10n.tr("Localizable", "Stats.GroupTopAdmin.Actions") }
  /// Promote
  public static var statsGroupTopAdminPromote: String  { return L10n.tr("Localizable", "Stats.GroupTopAdmin.Promote") }
  /// History
  public static var statsGroupTopInviterHistory: String  { return L10n.tr("Localizable", "Stats.GroupTopInviter.History") }
  /// Promote
  public static var statsGroupTopInviterPromote: String  { return L10n.tr("Localizable", "Stats.GroupTopInviter.Promote") }
  /// History
  public static var statsGroupTopPosterHistory: String  { return L10n.tr("Localizable", "Stats.GroupTopPoster.History") }
  /// Promote
  public static var statsGroupTopPosterPromote: String  { return L10n.tr("Localizable", "Stats.GroupTopPoster.Promote") }
  /// PUBLIC SHARES
  public static var statsMessagePublicForwardsTitleHeader: String  { return L10n.tr("Localizable", "Stats.MessagePublicForwardsTitle.Header") }
  /// Activate
  public static var statusBarActivate: String  { return L10n.tr("Localizable", "StatusBar.Activate") }
  /// Hide
  public static var statusBarHide: String  { return L10n.tr("Localizable", "StatusBar.Hide") }
  /// Quit
  public static var statusBarQuit: String  { return L10n.tr("Localizable", "StatusBar.Quit") }
  /// %d
  public static func stickerPackAdd1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_countable", p1)
  }
  /// Add %d Stickers
  public static func stickerPackAdd1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_few", p1)
  }
  /// Add %d Stickers
  public static func stickerPackAdd1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_many", p1)
  }
  /// Add %d Sticker
  public static func stickerPackAdd1One(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_one", p1)
  }
  /// Add %d Stickers
  public static func stickerPackAdd1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_other", p1)
  }
  /// Add %d Stickers
  public static func stickerPackAdd1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_two", p1)
  }
  /// Add %d Stickers
  public static func stickerPackAdd1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "StickerPack.Add1_zero", p1)
  }
  /// Sorry, this sticker set doesn't seem to exist.
  public static var stickerSetDontExist: String  { return L10n.tr("Localizable", "StickerSet.DontExist") }
  /// Remove
  public static var stickerSetRemove: String  { return L10n.tr("Localizable", "StickerSet.Remove") }
  /// %d
  public static func stickersCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_countable", p1)
  }
  /// %d stickers
  public static func stickersCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_few", p1)
  }
  /// %d stickers
  public static func stickersCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_many", p1)
  }
  /// %d sticker
  public static func stickersCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_one", p1)
  }
  /// %d stickers
  public static func stickersCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_other", p1)
  }
  /// %d stickers
  public static func stickersCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_two", p1)
  }
  /// %d stickers
  public static func stickersCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Count_zero", p1)
  }
  /// Favorite
  public static var stickersFavorite: String  { return L10n.tr("Localizable", "Stickers.Favorite") }
  /// GROUP STICKERS
  public static var stickersGroupStickers: String  { return L10n.tr("Localizable", "Stickers.GroupStickers") }
  /// Recent
  public static var stickersRecent: String  { return L10n.tr("Localizable", "Stickers.Recent") }
  /// Add
  public static var stickersSearchAdd: String  { return L10n.tr("Localizable", "Stickers.SearchAdd") }
  /// Added
  public static var stickersSearchAdded: String  { return L10n.tr("Localizable", "Stickers.SearchAdded") }
  /// My Sets
  public static var stickersSuggestAdded: String  { return L10n.tr("Localizable", "Stickers.SuggestAdded") }
  /// All Sets
  public static var stickersSuggestAll: String  { return L10n.tr("Localizable", "Stickers.SuggestAll") }
  /// None
  public static var stickersSuggestNone: String  { return L10n.tr("Localizable", "Stickers.SuggestNone") }
  /// Suggest Stickers by Emoji
  public static var stickersSuggestStickers: String  { return L10n.tr("Localizable", "Stickers.SuggestStickers") }
  /// Trending Stickers
  public static var stickersTrending: String  { return L10n.tr("Localizable", "Stickers.Trending") }
  /// Clear Recent Stickers
  public static var stickersConfirmClearRecentHeader: String  { return L10n.tr("Localizable", "Stickers.Confirm.ClearRecentHeader") }
  /// Clear
  public static var stickersConfirmClearRecentOK: String  { return L10n.tr("Localizable", "Stickers.Confirm.ClearRecentOK") }
  /// Are you sure you want to clear recent stickers?
  public static var stickersConfirmClearRecentText: String  { return L10n.tr("Localizable", "Stickers.Confirm.ClearRecentText") }
  /// Archive
  public static var stickersContextArchive: String  { return L10n.tr("Localizable", "Stickers.Context.Archive") }
  /// %d
  public static func stickersSetCount1Countable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_countable", p1)
  }
  /// %d stickers
  public static func stickersSetCount1Few(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_few", p1)
  }
  /// %d stickers
  public static func stickersSetCount1Many(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_many", p1)
  }
  /// %d sticker
  public static func stickersSetCount1One(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_one", p1)
  }
  /// %d stickers
  public static func stickersSetCount1Other(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_other", p1)
  }
  /// %d stickers
  public static func stickersSetCount1Two(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_two", p1)
  }
  /// %d stickers
  public static func stickersSetCount1Zero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Stickers.Set.Count1_zero", p1)
  }
  /// Clear %@
  public static func storageClear(_ p1: String) -> String {
    return L10n.tr("Localizable", "Storage.Clear", p1)
  }
  /// Clear All
  public static var storageClearAll: String  { return L10n.tr("Localizable", "Storage.ClearAll") }
  /// Audio
  public static var storageClearAudio: String  { return L10n.tr("Localizable", "Storage.Clear.Audio") }
  /// Documents
  public static var storageClearDocuments: String  { return L10n.tr("Localizable", "Storage.Clear.Documents") }
  /// Photos
  public static var storageClearPhotos: String  { return L10n.tr("Localizable", "Storage.Clear.Photos") }
  /// Videos
  public static var storageClearVideos: String  { return L10n.tr("Localizable", "Storage.Clear.Videos") }
  /// Are you sure you want to clear all cached data?
  public static var storageClearAllConfirmDescription: String  { return L10n.tr("Localizable", "Storage.ClearAll.Confirm.Description") }
  /// Telegram is calculating the current cache size.\nThis can take a few minutes.
  public static var storageUsageCalculating: String  { return L10n.tr("Localizable", "StorageUsage.Calculating") }
  /// CHATS
  public static var storageUsageChatsHeader: String  { return L10n.tr("Localizable", "StorageUsage.ChatsHeader") }
  /// Your local cache is being cleaned...
  public static var storageUsageCleaningProcess: String  { return L10n.tr("Localizable", "StorageUsage.CleaningProcess") }
  /// Clear
  public static var storageUsageClear: String  { return L10n.tr("Localizable", "StorageUsage.Clear") }
  /// Keep Media
  public static var storageUsageKeepMedia: String  { return L10n.tr("Localizable", "StorageUsage.KeepMedia") }
  /// Photos, videos and other files from cloud chats that you have **not accessed** during this period will be removed from this device to save disk space.\n\nAll media will stay in the Telegram cloud and can be re-downloaded if you need it again.
  public static var storageUsageKeepMediaDescription: String  { return L10n.tr("Localizable", "StorageUsage.KeepMedia.Description") }
  /// Photos, videos and other files from cloud chats that you have **not accessed** during this period will be removed from this device to save disk space.
  public static var storageUsageKeepMediaDescription1: String  { return L10n.tr("Localizable", "StorageUsage.KeepMedia.Description1") }
  /// If your cache size exceeds this limit, the oldest media will be deleted.\n\nAll media will stay in the Telegram cloud and can be re-downloaded if you need it again.
  public static var storageUsageLimitDesc: String  { return L10n.tr("Localizable", "StorageUsage.Limit.Desc") }
  /// MAXIMUM CACHE SIZE
  public static var storageUsageLimitHeader: String  { return L10n.tr("Localizable", "StorageUsage.Limit.Header") }
  /// No Limit
  public static var storageUsageLimitNoLimit: String  { return L10n.tr("Localizable", "StorageUsage.Limit.NoLimit") }
  /// Suggest Frequent Contacts
  public static var suggestFrequentContacts: String  { return L10n.tr("Localizable", "Suggest.Frequent.Contacts") }
  /// This will delete all data about the people you message frequently as well as the inline bots you are likely to use.
  public static var suggestFrequentContactsAlert: String  { return L10n.tr("Localizable", "Suggest.Frequent.Contacts.Alert") }
  /// Display people you message frequently at the top of the search section for quick access.
  public static var suggestFrequentContactsDesc: String  { return L10n.tr("Localizable", "Suggest.Frequent.Contacts.Desc") }
  /// Choose your language
  public static var suggestLocalizationHeader: String  { return L10n.tr("Localizable", "Suggest.Localization.Header") }
  /// Other
  public static var suggestLocalizationOther: String  { return L10n.tr("Localizable", "Suggest.Localization.Other") }
  /// Convert to Supergroup
  public static var supergroupConvertButton: String  { return L10n.tr("Localizable", "Supergroup.Convert.Button") }
  /// **In supergroups:**\n\n• New members can see the full message history\n• Deleted messages will disappear for all members\n• Admins can pin important messages\n• Creator can set a public link for the group
  public static var supergroupConvertDescription: String  { return L10n.tr("Localizable", "Supergroup.Convert.Description") }
  /// **Note**: This action cannot be undone.
  public static var supergroupConvertUndone: String  { return L10n.tr("Localizable", "Supergroup.Convert.Undone") }
  /// Ban User
  public static var supergroupDeleteRestrictionBanUser: String  { return L10n.tr("Localizable", "Supergroup.DeleteRestriction.BanUser") }
  /// Delete All Messages
  public static var supergroupDeleteRestrictionDeleteAllMessages: String  { return L10n.tr("Localizable", "Supergroup.DeleteRestriction.DeleteAllMessages") }
  /// Delete Message
  public static var supergroupDeleteRestrictionDeleteMessage: String  { return L10n.tr("Localizable", "Supergroup.DeleteRestriction.DeleteMessage") }
  /// Report Spam
  public static var supergroupDeleteRestrictionReportSpam: String  { return L10n.tr("Localizable", "Supergroup.DeleteRestriction.ReportSpam") }
  /// Manage Messages
  public static var supergroupDeleteRestrictionTitle: String  { return L10n.tr("Localizable", "Supergroup.DeleteRestriction.Title") }
  /// App Data Storage
  public static var systemMemoryWarningDataAndStorage: String  { return L10n.tr("Localizable", "System.MemoryWarning.DataAndStorage") }
  /// %d GB
  public static func systemMemoryWarningFreeSpace(_ p1: Int) -> String {
    return L10n.tr("Localizable", "System.MemoryWarning.FreeSpace", p1)
  }
  /// Warning!
  public static var systemMemoryWarningHeader: String  { return L10n.tr("Localizable", "System.MemoryWarning.Header") }
  /// Less then 1GB
  public static var systemMemoryWarningLessThen1GB: String  { return L10n.tr("Localizable", "System.MemoryWarning.LessThen1GB") }
  /// OK
  public static var systemMemoryWarningOK: String  { return L10n.tr("Localizable", "System.MemoryWarning.OK") }
  /// Your Mac is running low on disk space. Please free up some space by removing unnecessary files or changing your cache settings.\n\nFree space available: ~%@
  public static func systemMemoryWarningText(_ p1: String) -> String {
    return L10n.tr("Localizable", "System.MemoryWarning.Text", p1)
  }
  /// Window
  public static var td7AD5loTitle: String  { return L10n.tr("Localizable", "Td7-aD-5lo.title") }
  /// Appearance
  public static var telegramAppearanceViewController: String  { return L10n.tr("Localizable", "Telegram.AppearanceViewController") }
  /// Archived Stickers
  public static var telegramArchivedStickerPacksController: String  { return L10n.tr("Localizable", "Telegram.ArchivedStickerPacksController") }
  /// Bio
  public static var telegramBioViewController: String  { return L10n.tr("Localizable", "Telegram.BioViewController") }
  /// Blocked Users
  public static var telegramBlockedPeersViewController: String  { return L10n.tr("Localizable", "Telegram.BlockedPeersViewController") }
  /// Admins
  public static var telegramChannelAdminsViewController: String  { return L10n.tr("Localizable", "Telegram.ChannelAdminsViewController") }
  /// Removed Users
  public static var telegramChannelBlacklistViewController: String  { return L10n.tr("Localizable", "Telegram.ChannelBlacklistViewController") }
  /// All Actions
  public static var telegramChannelEventLogController: String  { return L10n.tr("Localizable", "Telegram.ChannelEventLogController") }
  /// Channel
  public static var telegramChannelIntroViewController: String  { return L10n.tr("Localizable", "Telegram.ChannelIntroViewController") }
  /// Channel Members
  public static var telegramChannelMembersViewController: String  { return L10n.tr("Localizable", "Telegram.ChannelMembersViewController") }
  /// Permissions
  public static var telegramChannelPermissionsController: String  { return L10n.tr("Localizable", "Telegram.ChannelPermissionsController") }
  /// Channel Stats
  public static var telegramChannelStatisticsController: String  { return L10n.tr("Localizable", "Telegram.ChannelStatisticsController") }
  /// Supergroup
  public static var telegramConvertGroupViewController: String  { return L10n.tr("Localizable", "Telegram.ConvertGroupViewController") }
  /// Data and Storage
  public static var telegramDataAndStorageViewController: String  { return L10n.tr("Localizable", "Telegram.DataAndStorageViewController") }
  /// Trending Stickers
  public static var telegramFeaturedStickerPacksController: String  { return L10n.tr("Localizable", "Telegram.FeaturedStickerPacksController") }
  /// Forward Messages
  public static var telegramForwardChatListController: String  { return L10n.tr("Localizable", "Telegram.ForwardChatListController") }
  /// General Settings
  public static var telegramGeneralSettingsViewController: String  { return L10n.tr("Localizable", "Telegram.GeneralSettingsViewController") }
  /// Admins
  public static var telegramGroupAdminsController: String  { return L10n.tr("Localizable", "Telegram.GroupAdminsController") }
  /// Groups In Common
  public static var telegramGroupsInCommonViewController: String  { return L10n.tr("Localizable", "Telegram.GroupsInCommonViewController") }
  /// Group Sticker Set
  public static var telegramGroupStickerSetController: String  { return L10n.tr("Localizable", "Telegram.GroupStickerSetController") }
  /// Stickers
  public static var telegramInstalledStickerPacksController: String  { return L10n.tr("Localizable", "Telegram.InstalledStickerPacksController") }
  /// Language
  public static var telegramLanguageViewController: String  { return L10n.tr("Localizable", "Telegram.LanguageViewController") }
  /// Settings
  public static var telegramLayoutAccountController: String  { return L10n.tr("Localizable", "Telegram.LayoutAccountController") }
  /// Recent Calls
  public static var telegramLayoutRecentCallsViewController: String  { return L10n.tr("Localizable", "Telegram.LayoutRecentCallsViewController") }
  /// Invite Link
  public static var telegramLinkInvationController: String  { return L10n.tr("Localizable", "Telegram.LinkInvationController") }
  /// Notifications
  public static var telegramNotificationSettingsViewController: String  { return L10n.tr("Localizable", "Telegram.NotificationSettingsViewController") }
  /// Passcode
  public static var telegramPasscodeSettingsViewController: String  { return L10n.tr("Localizable", "Telegram.PasscodeSettingsViewController") }
  /// Passport
  public static var telegramPassportController: String  { return L10n.tr("Localizable", "Telegram.PassportController") }
  /// Info
  public static var telegramPeerInfoController: String  { return L10n.tr("Localizable", "Telegram.PeerInfoController") }
  /// Shared Media
  public static var telegramPeerMediaController: String  { return L10n.tr("Localizable", "Telegram.PeerMediaController") }
  /// Change Number
  public static var telegramPhoneNumberConfirmController: String  { return L10n.tr("Localizable", "Telegram.PhoneNumberConfirmController") }
  /// Chat History Settings
  public static var telegramPreHistorySettingsController: String  { return L10n.tr("Localizable", "Telegram.PreHistorySettingsController") }
  /// Privacy and Security
  public static var telegramPrivacyAndSecurityViewController: String  { return L10n.tr("Localizable", "Telegram.PrivacyAndSecurityViewController") }
  /// Proxy
  public static var telegramProxySettingsViewController: String  { return L10n.tr("Localizable", "Telegram.ProxySettingsViewController") }
  /// Active Sessions
  public static var telegramRecentSessionsController: String  { return L10n.tr("Localizable", "Telegram.RecentSessionsController") }
  /// Encryption Key
  public static var telegramSecretChatKeyViewController: String  { return L10n.tr("Localizable", "Telegram.SecretChatKeyViewController") }
  /// Select Users
  public static var telegramSelectPeersController: String  { return L10n.tr("Localizable", "Telegram.SelectPeersController") }
  /// Storage Usage
  public static var telegramStorageUsageController: String  { return L10n.tr("Localizable", "Telegram.StorageUsageController") }
  /// Two-Step Verification
  public static var telegramTwoStepVerificationUnlockController: String  { return L10n.tr("Localizable", "Telegram.TwoStepVerificationUnlockController") }
  /// Username
  public static var telegramUsernameSettingsViewController: String  { return L10n.tr("Localizable", "Telegram.UsernameSettingsViewController") }
  /// Logged in with Telegram
  public static var telegramWebSessionsController: String  { return L10n.tr("Localizable", "Telegram.WebSessionsController") }
  /// Channel
  public static var telegramChannelVisibilityControllerChannel: String  { return L10n.tr("Localizable", "Telegram.ChannelVisibilityController.Channel") }
  /// Group
  public static var telegramChannelVisibilityControllerGroup: String  { return L10n.tr("Localizable", "Telegram.ChannelVisibilityController.Group") }
  /// Telegram needs to optimize its database after this update. This may take a few minutes, sorry for the inconvenience.
  public static var telegramUpgradeDatabaseText: String  { return L10n.tr("Localizable", "Telegram.UpgradeDatabase.Text") }
  /// Optimizing Database
  public static var telegramUpgradeDatabaseTitle: String  { return L10n.tr("Localizable", "Telegram.UpgradeDatabase.Title") }
  /// Agree & Continue
  public static var termsOfServiceAccept: String  { return L10n.tr("Localizable", "TermsOfService.Accept") }
  /// I confirm that I am %@ or over.
  public static func termsOfServiceConfirmAge(_ p1: String) -> String {
    return L10n.tr("Localizable", "TermsOfService.ConfirmAge", p1)
  }
  /// Decline
  public static var termsOfServiceDisagree: String  { return L10n.tr("Localizable", "TermsOfService.Disagree") }
  /// Please agree and proceed to %@.
  public static func termsOfServiceProceedBot(_ p1: String) -> String {
    return L10n.tr("Localizable", "TermsOfService.ProceedBot", p1)
  }
  /// Terms of Service
  public static var termsOfServiceTitle: String  { return L10n.tr("Localizable", "TermsOfService.Title") }
  /// Confirm
  public static var termsOfServiceAcceptConfirmAge: String  { return L10n.tr("Localizable", "TermsOfService.Accept.ConfirmAge") }
  /// Decline & Deactivate
  public static var termsOfServiceDisagreeOK: String  { return L10n.tr("Localizable", "TermsOfService.Disagree.OK") }
  /// We're very sorry, but this means we must part ways here. Unlike others, we don't use your data for ad targeting or other commercial purposes. Telegram only stores the information it needs to function as a feature-rich cloud service. You can adjust how we use your data (e.g., delete synced contacts) in Privacy & Security settings.\n\nBut if you're generally not OK with Telegram's modest requirements, it won't be possible for us to provide you with this service.
  public static var termsOfServiceDisagreeText: String  { return L10n.tr("Localizable", "TermsOfService.Disagree.Text") }
  /// Warning, this will irreversibly delete your Telegram account along with all the data you store in the Telegram cloud.\n\nImportant: You can Cancel now and export your data before deleting your account instead of losing it all. (To do this, open the latest version of Telegram Desktop and go to Settings > Export Telegram Data.)
  public static var termsOfServiceDisagreeTextLast: String  { return L10n.tr("Localizable", "TermsOfService.Disagree.Text.Last") }
  /// Delete Now
  public static var termsOfServiceDisagreeTextLastOK: String  { return L10n.tr("Localizable", "TermsOfService.Disagree.Text.Last.OK") }
  /// Copy Selected Text
  public static var textCopy: String  { return L10n.tr("Localizable", "Text.Copy") }
  /// Copy About
  public static var textCopyLabelAbout: String  { return L10n.tr("Localizable", "Text.CopyLabel_About") }
  /// Copy Bio
  public static var textCopyLabelBio: String  { return L10n.tr("Localizable", "Text.CopyLabel_Bio") }
  /// Copy Phone Number
  public static var textCopyLabelPhoneNumber: String  { return L10n.tr("Localizable", "Text.CopyLabel_PhoneNumber") }
  /// Copy Share Link
  public static var textCopyLabelShareLink: String  { return L10n.tr("Localizable", "Text.CopyLabel_ShareLink") }
  /// Copy Username
  public static var textCopyLabelUsername: String  { return L10n.tr("Localizable", "Text.CopyLabel_Username") }
  /// Copy Text
  public static var textCopyText: String  { return L10n.tr("Localizable", "Text.CopyText") }
  /// Copy Code
  public static var textContextCopyCode: String  { return L10n.tr("Localizable", "Text.Context.Copy.Code") }
  /// Copy Command
  public static var textContextCopyCommand: String  { return L10n.tr("Localizable", "Text.Context.Copy.Command") }
  /// Copy Email
  public static var textContextCopyEmail: String  { return L10n.tr("Localizable", "Text.Context.Copy.Email") }
  /// Copy Hashtag
  public static var textContextCopyHashtag: String  { return L10n.tr("Localizable", "Text.Context.Copy.Hashtag") }
  /// Copy Invite Link
  public static var textContextCopyInviteLink: String  { return L10n.tr("Localizable", "Text.Context.Copy.InviteLink") }
  /// Copy Link
  public static var textContextCopyLink: String  { return L10n.tr("Localizable", "Text.Context.Copy.Link") }
  /// Copy Sticker Pack
  public static var textContextCopyStickerPack: String  { return L10n.tr("Localizable", "Text.Context.Copy.StickerPack") }
  /// Copy Username
  public static var textContextCopyUsername: String  { return L10n.tr("Localizable", "Text.Context.Copy.Username") }
  /// Transformations
  public static var textViewTransformations: String  { return L10n.tr("Localizable", "Text.View.Transformations") }
  /// Bold
  public static var textViewTransformBold: String  { return L10n.tr("Localizable", "TextView.Transform.Bold") }
  /// Monospace
  public static var textViewTransformCode: String  { return L10n.tr("Localizable", "TextView.Transform.Code") }
  /// Italic
  public static var textViewTransformItalic: String  { return L10n.tr("Localizable", "TextView.Transform.Italic") }
  /// Clear Transformations
  public static var textViewTransformRemoveAll: String  { return L10n.tr("Localizable", "TextView.Transform.RemoveAll") }
  /// Spoiler
  public static var textViewTransformSpoiler: String  { return L10n.tr("Localizable", "TextView.Transform.Spoiler") }
  /// Strikethrough
  public static var textViewTransformStrikethrough: String  { return L10n.tr("Localizable", "TextView.Transform.Strikethrough") }
  /// Underline
  public static var textViewTransformUnderline: String  { return L10n.tr("Localizable", "TextView.Transform.Underline") }
  /// Make URL
  public static var textViewTransformURL: String  { return L10n.tr("Localizable", "TextView.Transform.URL") }
  /// Make Link
  public static var textViewTransformURL1: String  { return L10n.tr("Localizable", "TextView.Transform.URL1") }
  /// Sorry, this theme doesn't seem to exist for macOS.
  public static var themeGetThemeError: String  { return L10n.tr("Localizable", "Theme.GetTheme.Error") }
  /// Theme Preview
  public static var themePreviewTitle: String  { return L10n.tr("Localizable", "ThemePreview.Title") }
  /// %d
  public static func themePreviewUsesCountCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_countable", p1)
  }
  /// %d people are using this theme
  public static func themePreviewUsesCountFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_few", p1)
  }
  /// %d people are using this theme
  public static func themePreviewUsesCountMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_many", p1)
  }
  /// %d person is using this theme
  public static func themePreviewUsesCountOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_one", p1)
  }
  /// %d people are using this theme
  public static func themePreviewUsesCountOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_other", p1)
  }
  /// %d people are using this theme
  public static func themePreviewUsesCountTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_two", p1)
  }
  /// %d person is using this theme
  public static func themePreviewUsesCountZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "ThemePreview.UsesCount_zero", p1)
  }
  /// at
  public static var timeAt: String  { return L10n.tr("Localizable", "Time.at") }
  /// last seen
  public static var timeLastSeen: String  { return L10n.tr("Localizable", "Time.last_seen") }
  /// Jan %@, %@ at %@
  public static func timePreciseDateM1(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m1", p1, p2, p3)
  }
  /// Oct %@, %@ at %@
  public static func timePreciseDateM10(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m10", p1, p2, p3)
  }
  /// Nov %@, %@ at %@
  public static func timePreciseDateM11(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m11", p1, p2, p3)
  }
  /// Dec %@, %@ at %@
  public static func timePreciseDateM12(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m12", p1, p2, p3)
  }
  /// Feb %@, %@ at %@
  public static func timePreciseDateM2(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m2", p1, p2, p3)
  }
  /// Mar %@, %@ at %@
  public static func timePreciseDateM3(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m3", p1, p2, p3)
  }
  /// Apr %@, %@ at %@
  public static func timePreciseDateM4(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m4", p1, p2, p3)
  }
  /// May %@, %@ at %@
  public static func timePreciseDateM5(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m5", p1, p2, p3)
  }
  /// Jun %@, %@ at %@
  public static func timePreciseDateM6(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m6", p1, p2, p3)
  }
  /// Jul %@, %@ at %@
  public static func timePreciseDateM7(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m7", p1, p2, p3)
  }
  /// Aug %@, %@ at %@
  public static func timePreciseDateM8(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m8", p1, p2, p3)
  }
  /// Sep %@, %@ at %@
  public static func timePreciseDateM9(_ p1: String, _ p2: String, _ p3: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseDate_m9", p1, p2, p3)
  }
  /// Jan %@ at %@
  public static func timePreciseMediumDateM1(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m1", p1, p2)
  }
  /// Oct %@ at %@
  public static func timePreciseMediumDateM10(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m10", p1, p2)
  }
  /// Nov %@ at %@
  public static func timePreciseMediumDateM11(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m11", p1, p2)
  }
  /// Dec %@ at %@
  public static func timePreciseMediumDateM12(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m12", p1, p2)
  }
  /// Feb %@ at %@
  public static func timePreciseMediumDateM2(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m2", p1, p2)
  }
  /// Mar %@ at %@
  public static func timePreciseMediumDateM3(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m3", p1, p2)
  }
  /// Apr %@ at %@
  public static func timePreciseMediumDateM4(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m4", p1, p2)
  }
  /// May %@ at %@
  public static func timePreciseMediumDateM5(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m5", p1, p2)
  }
  /// Jun %@ at %@
  public static func timePreciseMediumDateM6(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m6", p1, p2)
  }
  /// Jul %@ at %@
  public static func timePreciseMediumDateM7(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m7", p1, p2)
  }
  /// Aug %@ at %@
  public static func timePreciseMediumDateM8(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m8", p1, p2)
  }
  /// Sep %@, at %@
  public static func timePreciseMediumDateM9(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "Time.PreciseMediumDate_m9", p1, p2)
  }
  /// today
  public static var timeToday: String  { return L10n.tr("Localizable", "Time.today") }
  /// today at %@
  public static func timeTodayAt(_ p1: String) -> String {
    return L10n.tr("Localizable", "Time.TodayAt", p1)
  }
  /// tomorrow at %@
  public static func timeTomorrow(_ p1: String) -> String {
    return L10n.tr("Localizable", "Time.tomorrow", p1)
  }
  /// tomorrow at %@
  public static func timeTomorrowAt(_ p1: String) -> String {
    return L10n.tr("Localizable", "Time.TomorrowAt", p1)
  }
  /// yesterday
  public static var timeYesterday: String  { return L10n.tr("Localizable", "Time.yesterday") }
  /// yesterday at %@
  public static func timeYesterdayAt(_ p1: String) -> String {
    return L10n.tr("Localizable", "Time.YesterdayAt", p1)
  }
  /// %d
  public static func timerDaysCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_countable", p1)
  }
  /// %d days
  public static func timerDaysFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_few", p1)
  }
  /// %d days
  public static func timerDaysMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_many", p1)
  }
  /// %d day
  public static func timerDaysOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_one", p1)
  }
  /// %d days
  public static func timerDaysOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_other", p1)
  }
  /// %d days
  public static func timerDaysTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_two", p1)
  }
  /// %d days
  public static func timerDaysZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Days_zero", p1)
  }
  /// Forever
  public static var timerForever: String  { return L10n.tr("Localizable", "Timer.Forever") }
  /// %d
  public static func timerHoursCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_countable", p1)
  }
  /// %d hours
  public static func timerHoursFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_few", p1)
  }
  /// %d hours
  public static func timerHoursMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_many", p1)
  }
  /// %d hour
  public static func timerHoursOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_one", p1)
  }
  /// %d hours
  public static func timerHoursOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_other", p1)
  }
  /// %d hours
  public static func timerHoursTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_two", p1)
  }
  /// %d hours
  public static func timerHoursZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Hours_zero", p1)
  }
  /// %d
  public static func timerMinutesCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_countable", p1)
  }
  /// %d minutes
  public static func timerMinutesFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_few", p1)
  }
  /// %d minutes
  public static func timerMinutesMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_many", p1)
  }
  /// %d minute
  public static func timerMinutesOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_one", p1)
  }
  /// %d minutes
  public static func timerMinutesOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_other", p1)
  }
  /// %d minutes
  public static func timerMinutesTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_two", p1)
  }
  /// %d minutes
  public static func timerMinutesZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Minutes_zero", p1)
  }
  /// %d
  public static func timerMonthsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_countable", p1)
  }
  /// %d months
  public static func timerMonthsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_few", p1)
  }
  /// %d months
  public static func timerMonthsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_many", p1)
  }
  /// %d month
  public static func timerMonthsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_one", p1)
  }
  /// %d months
  public static func timerMonthsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_other", p1)
  }
  /// %d months
  public static func timerMonthsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_two", p1)
  }
  /// %d months
  public static func timerMonthsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Months_zero", p1)
  }
  /// %d
  public static func timerSecondsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_countable", p1)
  }
  /// %d seconds
  public static func timerSecondsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_few", p1)
  }
  /// %d seconds
  public static func timerSecondsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_many", p1)
  }
  /// %d second
  public static func timerSecondsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_one", p1)
  }
  /// %d seconds
  public static func timerSecondsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_other", p1)
  }
  /// %d seconds
  public static func timerSecondsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_two", p1)
  }
  /// %d seconds
  public static func timerSecondsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Seconds_zero", p1)
  }
  /// %d
  public static func timerWeeksCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_countable", p1)
  }
  /// %d weeks
  public static func timerWeeksFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_few", p1)
  }
  /// %d weeks
  public static func timerWeeksMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_many", p1)
  }
  /// %d week
  public static func timerWeeksOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_one", p1)
  }
  /// %d weeks
  public static func timerWeeksOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_other", p1)
  }
  /// %d weeks
  public static func timerWeeksTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_two", p1)
  }
  /// %d weeks
  public static func timerWeeksZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Weeks_zero", p1)
  }
  /// %d
  public static func timerYearsCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_countable", p1)
  }
  /// %d years
  public static func timerYearsFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_few", p1)
  }
  /// %d years
  public static func timerYearsMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_many", p1)
  }
  /// %d year
  public static func timerYearsOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_one", p1)
  }
  /// %d years
  public static func timerYearsOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_other", p1)
  }
  /// %d years
  public static func timerYearsTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_two", p1)
  }
  /// %d years
  public static func timerYearsZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "Timer.Years_zero", p1)
  }
  /// Auto-delete timer set to 1 day.
  public static var tipAutoDeleteTimerSetForDay: String  { return L10n.tr("Localizable", "Tip.AutoDelete.TimerSetForDay") }
  /// Auto-delete timer set to 1 week.
  public static var tipAutoDeleteTimerSetForWeek: String  { return L10n.tr("Localizable", "Tip.AutoDelete.TimerSetForWeek") }
  /// Auto-delete timer is now disabled.
  public static var tipAutoDeleteTimerSetOff: String  { return L10n.tr("Localizable", "Tip.AutoDelete.TimerSetOff") }
  /// Muted
  public static var toastMuted: String  { return L10n.tr("Localizable", "Toast.Muted") }
  /// Unmuted
  public static var toastUnmuted: String  { return L10n.tr("Localizable", "Toast.Unmuted") }
  /// Attach
  public static var touchBarAttach: String  { return L10n.tr("Localizable", "TouchBar.Attach") }
  /// Call
  public static var touchBarCall: String  { return L10n.tr("Localizable", "TouchBar.Call") }
  /// Favorite
  public static var touchBarFavorite: String  { return L10n.tr("Localizable", "TouchBar.Favorite") }
  /// Recent
  public static var touchBarRecent: String  { return L10n.tr("Localizable", "TouchBar.Recent") }
  /// Recently Used
  public static var touchBarRecentlyUsed: String  { return L10n.tr("Localizable", "TouchBar.RecentlyUsed") }
  /// Search for messages or users
  public static var touchBarSearchUsersOrMessages: String  { return L10n.tr("Localizable", "TouchBar.SearchUsersOrMessages") }
  /// Start Secret Chat
  public static var touchBarStartSecretChat: String  { return L10n.tr("Localizable", "TouchBar.StartSecretChat") }
  /// Replace with File
  public static var touchBarEditMessageReplaceWithFile: String  { return L10n.tr("Localizable", "TouchBar.EditMessage.ReplaceWithFile") }
  /// Replace with Media
  public static var touchBarEditMessageReplaceWithMedia: String  { return L10n.tr("Localizable", "TouchBar.EditMessage.ReplaceWithMedia") }
  /// Chat Actions
  public static var touchBarLabelChatActions: String  { return L10n.tr("Localizable", "TouchBarLabel.ChatActions") }
  /// Emoji & Stickers
  public static var touchBarLabelEmojiAndStickers: String  { return L10n.tr("Localizable", "TouchBarLabel.EmojiAndStickers") }
  /// New Chat
  public static var touchBarLabelNewChat: String  { return L10n.tr("Localizable", "TouchBarLabel.NewChat") }
  /// FROM: %@
  public static func translateFrom(_ p1: String) -> String {
    return L10n.tr("Localizable", "Translate.From", p1)
  }
  /// more
  public static var translateShowMore: String  { return L10n.tr("Localizable", "Translate.ShowMore") }
  /// Translate
  public static var translateTitle: String  { return L10n.tr("Localizable", "Translate.Title") }
  /// TO: %@
  public static func translateTo(_ p1: String) -> String {
    return L10n.tr("Localizable", "Translate.To", p1)
  }
  /// Arabic
  public static var translateLanguageAr: String  { return L10n.tr("Localizable", "Translate.Language.ar") }
  /// Auto
  public static var translateLanguageAuto: String  { return L10n.tr("Localizable", "Translate.Language.auto") }
  /// German
  public static var translateLanguageDe: String  { return L10n.tr("Localizable", "Translate.Language.de") }
  /// English
  public static var translateLanguageEn: String  { return L10n.tr("Localizable", "Translate.Language.en") }
  /// Spanish
  public static var translateLanguageEs: String  { return L10n.tr("Localizable", "Translate.Language.es") }
  /// France
  public static var translateLanguageFr: String  { return L10n.tr("Localizable", "Translate.Language.fr") }
  /// Italian
  public static var translateLanguageIt: String  { return L10n.tr("Localizable", "Translate.Language.it") }
  /// Japanese
  public static var translateLanguageJp: String  { return L10n.tr("Localizable", "Translate.Language.jp") }
  /// Korean
  public static var translateLanguageKo: String  { return L10n.tr("Localizable", "Translate.Language.ko") }
  /// Portuguese
  public static var translateLanguagePt: String  { return L10n.tr("Localizable", "Translate.Language.pt") }
  /// Russian
  public static var translateLanguageRu: String  { return L10n.tr("Localizable", "Translate.Language.ru") }
  /// Mandarin Chinese
  public static var translateLanguageZh: String  { return L10n.tr("Localizable", "Translate.Language.zh") }
  /// Skip
  public static var twoStepAuthEmailSkip: String  { return L10n.tr("Localizable", "TwoStep.AuthEmailSkip") }
  /// An error occured. Please try again later.
  public static var twoStepAuthAnError: String  { return L10n.tr("Localizable", "TwoStepAuth.AnError") }
  /// Cancel Reset
  public static var twoStepAuthCancelReset: String  { return L10n.tr("Localizable", "TwoStepAuth.CancelReset") }
  /// Change Recovery E-Mail
  public static var twoStepAuthChangeEmail: String  { return L10n.tr("Localizable", "TwoStepAuth.ChangeEmail") }
  /// Change Password
  public static var twoStepAuthChangePassword: String  { return L10n.tr("Localizable", "TwoStepAuth.ChangePassword") }
  /// Please enter a new password which will be used to protect your data.
  public static var twoStepAuthChangePasswordDesc: String  { return L10n.tr("Localizable", "TwoStepAuth.ChangePasswordDesc") }
  /// Abort Two-Step Verification Setup
  public static var twoStepAuthConfirmationAbort: String  { return L10n.tr("Localizable", "TwoStepAuth.ConfirmationAbort") }
  /// Please check your e-mail and enter the confirmation code to complete Two-Step Verification setup. Be sure to check the spam folder as well.
  public static var twoStepAuthConfirmationTextNew: String  { return L10n.tr("Localizable", "TwoStepAuth.ConfirmationTextNew") }
  /// Please enter the code we've just emailed at %@.
  public static func twoStepAuthConfirmEmailCodeDesc(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.ConfirmEmailCodeDesc", p1)
  }
  /// E-Mail
  public static var twoStepAuthEmail: String  { return L10n.tr("Localizable", "TwoStepAuth.Email") }
  /// This confirmation code has expired. Please try again.
  public static var twoStepAuthEmailCodeExpired: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailCodeExpired") }
  /// You have entered an invalid code. Please try again.
  public static var twoStepAuthEmailCodeInvalid: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailCodeInvalid") }
  /// Please add your valid e-mail. It is the only way to recover a forgotten password.
  public static var twoStepAuthEmailHelp: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailHelp") }
  /// Please enter your new recovery email. It is the only way to recover a forgotten password.
  public static var twoStepAuthEmailHelpChange: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailHelpChange") }
  /// Invalid e-mail address. Please try again.
  public static var twoStepAuthEmailInvalid: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailInvalid") }
  /// We have sent you an e-mail to confirm your address.
  public static var twoStepAuthEmailSent: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailSent") }
  /// No, seriously.\n\nIf you forget your password, you will lose access to your Telegram account. There will be no way to restore it.
  public static var twoStepAuthEmailSkipAlert: String  { return L10n.tr("Localizable", "TwoStepAuth.EmailSkipAlert") }
  /// Enter Code
  public static var twoStepAuthEnterEmailCode: String  { return L10n.tr("Localizable", "TwoStepAuth.EnterEmailCode") }
  /// Forgot password?
  public static var twoStepAuthEnterPasswordForgot: String  { return L10n.tr("Localizable", "TwoStepAuth.EnterPasswordForgot") }
  /// You have enabled Two-Step Verification, so your account is protected with an additional password.
  public static var twoStepAuthEnterPasswordHelp: String  { return L10n.tr("Localizable", "TwoStepAuth.EnterPasswordHelp") }
  /// Hint: %@
  public static func twoStepAuthEnterPasswordHint(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.EnterPasswordHint", p1)
  }
  /// Password
  public static var twoStepAuthEnterPasswordPassword: String  { return L10n.tr("Localizable", "TwoStepAuth.EnterPasswordPassword") }
  /// Limit exceeded. Please try again later.
  public static var twoStepAuthFloodError: String  { return L10n.tr("Localizable", "TwoStepAuth.FloodError") }
  /// An error occurred. Please try again later.
  public static var twoStepAuthGenericError: String  { return L10n.tr("Localizable", "TwoStepAuth.GenericError") }
  /// You have enabled Two-Step verification.\nYou'll need the password you set up here to log in to your Telegram account.
  public static var twoStepAuthGenericHelp: String  { return L10n.tr("Localizable", "TwoStepAuth.GenericHelp") }
  /// Invalid password. Please try again.
  public static var twoStepAuthInvalidPasswordError: String  { return L10n.tr("Localizable", "TwoStepAuth.InvalidPasswordError") }
  /// Password
  public static var twoStepAuthPasswordTitle: String  { return L10n.tr("Localizable", "TwoStepAuth.PasswordTitle") }
  /// Your recovery e-mail %@ is not yet active and pending confirmation.
  public static func twoStepAuthPendingEmailHelp(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.PendingEmailHelp", p1)
  }
  /// Code
  public static var twoStepAuthRecoveryCode: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryCode") }
  /// Code Expired
  public static var twoStepAuthRecoveryCodeExpired: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryCodeExpired") }
  /// Please check your e-mail and enter the 6-digit code we've sent there to deactivate your cloud password.
  public static var twoStepAuthRecoveryCodeHelp: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryCodeHelp") }
  /// Invalid code. Please try again.
  public static var twoStepAuthRecoveryCodeInvalid: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryCodeInvalid") }
  /// Having trouble accessing your e-mail\n[%@]()?
  public static func twoStepAuthRecoveryEmailUnavailableNew(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.RecoveryEmailUnavailableNew", p1)
  }
  /// Your remaining options are either to remember your password or to reset your account.
  public static var twoStepAuthRecoveryFailed: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryFailed") }
  /// We have sent a recovery code to the e-mail you provided:\n\n%@
  public static func twoStepAuthRecoverySent(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.RecoverySent", p1)
  }
  /// E-Mail Code
  public static var twoStepAuthRecoveryTitle: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryTitle") }
  /// Since you haven't provided a recovery e-mail when setting up your password, your remaining options are either to remember your password or to reset your account.
  public static var twoStepAuthRecoveryUnavailable: String  { return L10n.tr("Localizable", "TwoStepAuth.RecoveryUnavailable") }
  /// Turn Password Off
  public static var twoStepAuthRemovePassword: String  { return L10n.tr("Localizable", "TwoStepAuth.RemovePassword") }
  /// Reset Password
  public static var twoStepAuthReset: String  { return L10n.tr("Localizable", "TwoStepAuth.Reset") }
  /// Since the account **%@** is active and protected by a password, we will delete it in 1 week for security purposes.\n\nYou can cancel this process at any time.\n\nYou'll be able to reset your account in:\n%@
  public static func twoStepAuthResetDescription(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.ResetDescription", p1, p2)
  }
  /// You can reset your password in %@.
  public static func twoStepAuthResetPending(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.ResetPending", p1)
  }
  /// You have successfully reset your password. Do you want to create a new one?
  public static var twoStepAuthResetSuccess: String  { return L10n.tr("Localizable", "TwoStepAuth.ResetSuccess") }
  /// Set Additional Password
  public static var twoStepAuthSetPassword: String  { return L10n.tr("Localizable", "TwoStepAuth.SetPassword") }
  /// You can set a password that will be required when you log in on a new device in addition to the code you get in the SMS.
  public static var twoStepAuthSetPasswordHelp: String  { return L10n.tr("Localizable", "TwoStepAuth.SetPasswordHelp") }
  /// Set Recovery E-Mail
  public static var twoStepAuthSetupEmail: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupEmail") }
  /// Recovery E-Mail
  public static var twoStepAuthSetupEmailTitle: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupEmailTitle") }
  /// You can create an optional hint for your password.
  public static var twoStepAuthSetupHintDesc: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupHintDesc") }
  /// Hint
  public static var twoStepAuthSetupHintPlaceholder: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupHintPlaceholder") }
  /// Password Hint
  public static var twoStepAuthSetupHintTitle: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupHintTitle") }
  /// Passwords don't match. Please try again.
  public static var twoStepAuthSetupPasswordConfirmFailed: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordConfirmFailed") }
  /// Re-enter your password
  public static var twoStepAuthSetupPasswordConfirmPassword: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordConfirmPassword") }
  /// Please confirm your password.
  public static var twoStepAuthSetupPasswordConfirmPasswordDesc: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordConfirmPasswordDesc") }
  /// Please create a password which will be used to protect your data.
  public static var twoStepAuthSetupPasswordDesc: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordDesc") }
  /// Enter your cloud password
  public static var twoStepAuthSetupPasswordEnterPassword: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordEnterPassword") }
  /// Enter your new password
  public static var twoStepAuthSetupPasswordEnterPasswordNew: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordEnterPasswordNew") }
  /// Your Password
  public static var twoStepAuthSetupPasswordTitle: String  { return L10n.tr("Localizable", "TwoStepAuth.SetupPasswordTitle") }
  /// Unable to reset password, please try again at %@
  public static func twoStepAuthUnableToReset(_ p1: String) -> String {
    return L10n.tr("Localizable", "TwoStepAuth.UnableToReset", p1)
  }
  /// Cancel Reset
  public static var twoStepAuthCancelResetConfirm: String  { return L10n.tr("Localizable", "TwoStepAuth.CancelReset.Confirm") }
  /// Cancel the password resetting process? If you proceed, the expired part of the 7-day delay will be lost.
  public static var twoStepAuthCancelResetText: String  { return L10n.tr("Localizable", "TwoStepAuth.CancelReset.Text") }
  /// Are you sure you want to disable your password?
  public static var twoStepAuthConfirmDisablePassword: String  { return L10n.tr("Localizable", "TwoStepAuth.Confirm.DisablePassword") }
  /// An error occured. Please try again later.
  public static var twoStepAuthErrorGeneric: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.Generic") }
  /// Since you haven't provided a recovery e-mail when setting up your password, your remaining options are either to remember your password or to reset your account.
  public static var twoStepAuthErrorHaventEmail: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.HaventEmail") }
  /// Please enter valid e-mail address.
  public static var twoStepAuthErrorInvalidEmail: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.InvalidEmail") }
  /// You have entered an invalid password too many times. Please try again later.
  public static var twoStepAuthErrorLimitExceeded: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.LimitExceeded") }
  /// Passwords don't match.\nPlease try again.
  public static var twoStepAuthErrorPasswordsDontMatch: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.PasswordsDontMatch") }
  /// Reset
  public static var twoStepAuthErrorHaventEmailReset: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.HaventEmail.Reset") }
  /// Reset Password
  public static var twoStepAuthErrorHaventEmailResetHeader: String  { return L10n.tr("Localizable", "TwoStepAuth.Error.HaventEmail.ResetHeader") }
  /// Reset Password
  public static var twoStepAuthResetSuccessHeader: String  { return L10n.tr("Localizable", "TwoStepAuth.ResetSuccess.Header") }
  /// Capitalize
  public static var uezBsLqGTitle: String  { return L10n.tr("Localizable", "UEZ-Bs-lqG.title") }
  /// Update Telegram
  public static var updateUpdateTelegram: String  { return L10n.tr("Localizable", "Update.UpdateTelegram") }
  /// Telegram Update
  public static var updateAppTelegramUpdate: String  { return L10n.tr("Localizable", "UpdateApp.TelegramUpdate") }
  /// Update Telegram
  public static var updateAppUpdateTelegram: String  { return L10n.tr("Localizable", "UpdateApp.UpdateTelegram") }
  /// Sorry, you are a member of too many groups and channels. For technical reasons, you need to leave some first before changing this setting in your groups.
  public static var upgradeChannelsTooMuch: String  { return L10n.tr("Localizable", "Upgrade.ChannelsTooMuch") }
  /// %@ is available
  public static func usernameSettingsAvailable(_ p1: String) -> String {
    return L10n.tr("Localizable", "UsernameSettings.available", p1)
  }
  /// You can choose a username on Telegram. If you do, other people will be able to find you by this username and contact you without knowing your phone number.\n\n\nYou can use a-z, 0-9 and underscores. Minimum length is 5 characters.
  public static var usernameSettingsChangeDescription: String  { return L10n.tr("Localizable", "UsernameSettings.ChangeDescription") }
  /// Done
  public static var usernameSettingsDone: String  { return L10n.tr("Localizable", "UsernameSettings.Done") }
  /// Enter your username
  public static var usernameSettingsInputPlaceholder: String  { return L10n.tr("Localizable", "UsernameSettings.InputPlaceholder") }
  /// Hide Others
  public static var vdrFpXzOTitle: String  { return L10n.tr("Localizable", "Vdr-fp-XzO.title") }
  /// Cancel
  public static var videoAvatarButtonCancel: String  { return L10n.tr("Localizable", "VideoAvatar.Button.Cancel") }
  /// Set
  public static var videoAvatarButtonSet: String  { return L10n.tr("Localizable", "VideoAvatar.Button.Set") }
  /// Choose a cover for channel video
  public static var videoAvatarChooseDescChannel: String  { return L10n.tr("Localizable", "VideoAvatar.ChooseDesc.Channel") }
  /// Choose a cover for group video
  public static var videoAvatarChooseDescGroup: String  { return L10n.tr("Localizable", "VideoAvatar.ChooseDesc.Group") }
  /// Choose a cover for your profile video
  public static var videoAvatarChooseDescProfile: String  { return L10n.tr("Localizable", "VideoAvatar.ChooseDesc.Profile") }
  /// Sorry, you can't join voice chat as an anonymous admin.
  public static var voiceChatAnonymousDisabledAlertText: String  { return L10n.tr("Localizable", "VoiceChat.AnonymousDisabledAlertText") }
  /// Sorry, this voice chat has too many participants at the moment.
  public static var voiceChatChatFullAlertText: String  { return L10n.tr("Localizable", "VoiceChat.ChatFullAlertText") }
  /// click if you want to speak
  public static var voiceChatClickToRaiseHand: String  { return L10n.tr("Localizable", "VoiceChat.ClickToRaiseHand") }
  /// Click to Unmute
  public static var voiceChatClickToUnmute: String  { return L10n.tr("Localizable", "VoiceChat.ClickToUnmute") }
  /// Connecting...
  public static var voiceChatConnecting: String  { return L10n.tr("Localizable", "VoiceChat.Connecting") }
  /// Cancel request to speak
  public static var voiceChatDownHand: String  { return L10n.tr("Localizable", "VoiceChat.DownHand") }
  /// group members
  public static var voiceChatGroupMembers: String  { return L10n.tr("Localizable", "VoiceChat.GroupMembers") }
  /// Add
  public static var voiceChatInviteMemberToGroupFirstAdd: String  { return L10n.tr("Localizable", "VoiceChat.InviteMemberToGroupFirstAdd") }
  /// %1$@ isn't a member of "%2$@" yet. Add them to the group?
  public static func voiceChatInviteMemberToGroupFirstText(_ p1: String, _ p2: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.InviteMemberToGroupFirstText", p1, p2)
  }
  /// Leave
  public static var voiceChatLeave: String  { return L10n.tr("Localizable", "VoiceChat.Leave") }
  /// Leave
  public static var voiceChatLeaveCall: String  { return L10n.tr("Localizable", "VoiceChat.LeaveCall") }
  /// You are in Listen Mode Only
  public static var voiceChatListenMode: String  { return L10n.tr("Localizable", "VoiceChat.ListenMode") }
  /// Muted By Admin
  public static var voiceChatMutedByAdmin: String  { return L10n.tr("Localizable", "VoiceChat.MutedByAdmin") }
  /// Mute For Me
  public static var voiceChatMuteForMe: String  { return L10n.tr("Localizable", "VoiceChat.MuteForMe") }
  /// Mute
  public static var voiceChatMutePeer: String  { return L10n.tr("Localizable", "VoiceChat.MutePeer") }
  /// Open Profile
  public static var voiceChatOpenProfile: String  { return L10n.tr("Localizable", "VoiceChat.OpenProfile") }
  /// Pin Screencast
  public static var voiceChatPinScreencast: String  { return L10n.tr("Localizable", "VoiceChat.PinScreencast") }
  /// Pin Video
  public static var voiceChatPinVideo: String  { return L10n.tr("Localizable", "VoiceChat.PinVideo") }
  /// Remove
  public static var voiceChatRemovePeer: String  { return L10n.tr("Localizable", "VoiceChat.RemovePeer") }
  /// Remove
  public static var voiceChatRemovePeerRemove: String  { return L10n.tr("Localizable", "VoiceChat.RemovePeerRemove") }
  /// Cancel Reminder
  public static var voiceChatRemoveReminder: String  { return L10n.tr("Localizable", "VoiceChat.RemoveReminder") }
  /// Telegram needs access to your microphone to speak
  public static var voiceChatRequestAccess: String  { return L10n.tr("Localizable", "VoiceChat.RequestAccess") }
  /// Set Reminder
  public static var voiceChatSetReminder: String  { return L10n.tr("Localizable", "VoiceChat.SetReminder") }
  /// Settings
  public static var voiceChatSettings: String  { return L10n.tr("Localizable", "VoiceChat.Settings") }
  /// Show Info
  public static var voiceChatShowInfo: String  { return L10n.tr("Localizable", "VoiceChat.ShowInfo") }
  /// Start Now
  public static var voiceChatStartNow: String  { return L10n.tr("Localizable", "VoiceChat.StartNow") }
  /// Start Recording
  public static var voiceChatStartRecording: String  { return L10n.tr("Localizable", "VoiceChat.StartRecording") }
  /// Stop Recording
  public static var voiceChatStopRecording: String  { return L10n.tr("Localizable", "VoiceChat.StopRecording") }
  /// Unmute For Me
  public static var voiceChatUnmuteForMe: String  { return L10n.tr("Localizable", "VoiceChat.UnmuteForMe") }
  /// Allow To Speak
  public static var voiceChatUnmutePeer: String  { return L10n.tr("Localizable", "VoiceChat.UnmutePeer") }
  /// Unpin Screencast
  public static var voiceChatUnpinScreencast: String  { return L10n.tr("Localizable", "VoiceChat.UnpinScreencast") }
  /// Unpin Video
  public static var voiceChatUnpinVideo: String  { return L10n.tr("Localizable", "VoiceChat.UnpinVideo") }
  /// You invited **%@** to the voice chat
  public static func voiceChatUserInvited(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.UserInvited", p1)
  }
  /// You're Live
  public static var voiceChatYouLive: String  { return L10n.tr("Localizable", "VoiceChat.YouLive") }
  /// Voice chat is being recorded.
  public static var voiceChatAlertRecording: String  { return L10n.tr("Localizable", "VoiceChat.Alert.Recording") }
  /// listening
  public static var voiceChatBlockListening: String  { return L10n.tr("Localizable", "VoiceChat.Block.Listening") }
  /// recent active
  public static var voiceChatBlockRecentActive: String  { return L10n.tr("Localizable", "VoiceChat.Block.RecentActive") }
  /// Voice chat ended.
  public static var voiceChatChatEnded: String  { return L10n.tr("Localizable", "VoiceChat.Chat.Ended") }
  /// Voice chat ended. Start a new one?
  public static var voiceChatChatStartNew: String  { return L10n.tr("Localizable", "VoiceChat.Chat.StartNew") }
  /// Start
  public static var voiceChatChatStartNewOK: String  { return L10n.tr("Localizable", "VoiceChat.Chat.StartNew.OK") }
  /// hold ⎵ or %@
  public static func voiceChatClickToUnmuteSecondaryHold(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.ClickToUnmute.Secondary.Hold", p1)
  }
  /// hold ⎵
  public static var voiceChatClickToUnmuteSecondaryHoldDefault: String  { return L10n.tr("Localizable", "VoiceChat.ClickToUnmute.Secondary.HoldDefault") }
  /// press ⎵ or %@
  public static func voiceChatClickToUnmuteSecondaryPress(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.ClickToUnmute.Secondary.Press", p1)
  }
  /// press ⎵
  public static var voiceChatClickToUnmuteSecondaryPressDefault: String  { return L10n.tr("Localizable", "VoiceChat.ClickToUnmute.Secondary.PressDefault") }
  /// Leave
  public static var voiceChatEndOK: String  { return L10n.tr("Localizable", "VoiceChat.End.OK") }
  /// Are you sure you want to leave this voice chat?
  public static var voiceChatEndText: String  { return L10n.tr("Localizable", "VoiceChat.End.Text") }
  /// End Voice Chat
  public static var voiceChatEndThird: String  { return L10n.tr("Localizable", "VoiceChat.End.Third") }
  /// Leave voice chat
  public static var voiceChatEndTitle: String  { return L10n.tr("Localizable", "VoiceChat.End.Title") }
  /// Join Channel
  public static var voiceChatInfoJoinChannel: String  { return L10n.tr("Localizable", "VoiceChat.Info.JoinChannel") }
  /// Leave Channel
  public static var voiceChatInfoLeaveChannel: String  { return L10n.tr("Localizable", "VoiceChat.Info.LeaveChannel") }
  /// Open Channel
  public static var voiceChatInfoOpenChannel: String  { return L10n.tr("Localizable", "VoiceChat.Info.OpenChannel") }
  /// Open Profile
  public static var voiceChatInfoOpenProfile: String  { return L10n.tr("Localizable", "VoiceChat.Info.OpenProfile") }
  /// Send Message
  public static var voiceChatInfoSendMessage: String  { return L10n.tr("Localizable", "VoiceChat.Info.SendMessage") }
  /// CHATS
  public static var voiceChatInviteChats: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Chats") }
  /// contacts
  public static var voiceChatInviteContacts: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Contacts") }
  /// Copy Invite Link
  public static var voiceChatInviteCopyInviteLink: String  { return L10n.tr("Localizable", "VoiceChat.Invite.CopyInviteLink") }
  /// Copy Listener Link
  public static var voiceChatInviteCopyListenersLink: String  { return L10n.tr("Localizable", "VoiceChat.Invite.CopyListenersLink") }
  /// Copy Speaker Link
  public static var voiceChatInviteCopySpeakersLink: String  { return L10n.tr("Localizable", "VoiceChat.Invite.CopySpeakersLink") }
  /// global search
  public static var voiceChatInviteGlobalSearch: String  { return L10n.tr("Localizable", "VoiceChat.Invite.GlobalSearch") }
  /// group members
  public static var voiceChatInviteGroupMembers: String  { return L10n.tr("Localizable", "VoiceChat.Invite.GroupMembers") }
  /// Send
  public static var voiceChatInviteInvite: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Invite") }
  /// Invite members
  public static var voiceChatInviteInviteMembers: String  { return L10n.tr("Localizable", "VoiceChat.Invite.InviteMembers") }
  /// Add Members
  public static var voiceChatInviteTitle: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Title") }
  /// Invite Members
  public static var voiceChatInviteChannelsTitle: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Channels.Title") }
  /// Voice Chat
  public static var voiceChatInviteConfirmHeader: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Confirm.Header") }
  /// Send
  public static var voiceChatInviteConfirmOK: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Confirm.OK") }
  /// Send Invite Link to selected chats?
  public static var voiceChatInviteConfirmText: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Confirm.Text") }
  /// Send Speaker Link
  public static var voiceChatInviteConfirmThird: String  { return L10n.tr("Localizable", "VoiceChat.Invite.Confirm.Third") }
  /// Sorry, there are too many members in this voice chat. Please try again later.
  public static var voiceChatJoinErrorTooMany: String  { return L10n.tr("Localizable", "VoiceChat.Join.Error.TooMany") }
  /// %d
  public static func voiceChatJoinAsChannelCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_countable", p1)
  }
  /// %d subscribers
  public static func voiceChatJoinAsChannelFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_few", p1)
  }
  /// %d subscribers
  public static func voiceChatJoinAsChannelMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_many", p1)
  }
  /// %d subscriber
  public static func voiceChatJoinAsChannelOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_one", p1)
  }
  /// %d subscribers
  public static func voiceChatJoinAsChannelOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_other", p1)
  }
  /// %d subscribers
  public static func voiceChatJoinAsChannelTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_two", p1)
  }
  /// %d subscribers
  public static func voiceChatJoinAsChannelZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Channel_zero", p1)
  }
  /// %d
  public static func voiceChatJoinAsGroupCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_countable", p1)
  }
  /// %d members
  public static func voiceChatJoinAsGroupFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_few", p1)
  }
  /// %d members
  public static func voiceChatJoinAsGroupMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_many", p1)
  }
  /// %d member
  public static func voiceChatJoinAsGroupOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_one", p1)
  }
  /// %d members
  public static func voiceChatJoinAsGroupOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_other", p1)
  }
  /// %d members
  public static func voiceChatJoinAsGroupTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_two", p1)
  }
  /// %d members
  public static func voiceChatJoinAsGroupZero(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.JoinAs.Group_zero", p1)
  }
  /// we let the speakers know
  public static var voiceChatRaisedHandText: String  { return L10n.tr("Localizable", "VoiceChat.RaisedHand.Text") }
  /// You asked to speak
  public static var voiceChatRaisedHandTitle: String  { return L10n.tr("Localizable", "VoiceChat.RaisedHand.Title") }
  /// Start
  public static var voiceChatRecordingStartOK: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Start.OK") }
  /// Do you want to start recording this chat and save the result into an file?\n\nOther members will see that the chat is being recorded.
  public static var voiceChatRecordingStartText1: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Start.Text1") }
  /// Start Recording
  public static var voiceChatRecordingStartTitle: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Start.Title") }
  /// Stop
  public static var voiceChatRecordingStopOK: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Stop.OK") }
  /// Are you sure to want to stop recording?
  public static var voiceChatRecordingStopText: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Stop.Text") }
  /// Stop Recording
  public static var voiceChatRecordingStopTitle: String  { return L10n.tr("Localizable", "VoiceChat.Recording.Stop.Title") }
  /// Are you sure you want to remove %1$@ from the group chat?
  public static func voiceChatRemovePeerConfirm(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.RemovePeer.Confirm", p1)
  }
  /// Cancel
  public static var voiceChatRemovePeerConfirmCancel: String  { return L10n.tr("Localizable", "VoiceChat.RemovePeer.Confirm.Cancel") }
  /// Are you sure you want to remove %1$@ from the channel?
  public static func voiceChatRemovePeerConfirmChannel(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.RemovePeer.Confirm.Channel", p1)
  }
  /// Remove
  public static var voiceChatRemovePeerConfirmOK: String  { return L10n.tr("Localizable", "VoiceChat.RemovePeer.Confirm.OK") }
  /// Starts In
  public static var voiceChatScheduledHeader: String  { return L10n.tr("Localizable", "VoiceChat.Scheduled.Header") }
  /// Late For
  public static var voiceChatScheduledHeaderLate: String  { return L10n.tr("Localizable", "VoiceChat.Scheduled.HeaderLate") }
  /// Unavailable to share your screen, please grant access is [System Settings](screen).
  public static var voiceChatScreenShareUnavailable: String  { return L10n.tr("Localizable", "VoiceChat.ScreenShare.Unavailable") }
  /// Screencast is Paused
  public static var voiceChatScreencastPaused: String  { return L10n.tr("Localizable", "VoiceChat.Screencast.Paused") }
  /// Voice Chat
  public static var voiceChatScreencastConfirmHeader: String  { return L10n.tr("Localizable", "VoiceChat.Screencast.Confirm.Header") }
  /// Continue
  public static var voiceChatScreencastConfirmOK: String  { return L10n.tr("Localizable", "VoiceChat.Screencast.Confirm.OK") }
  /// %@ is screensharing. This action will make your screencast pinned for all participants.
  public static func voiceChatScreencastConfirmText(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Screencast.Confirm.Text", p1)
  }
  /// New participants can speak
  public static var voiceChatSettingsAllMembers: String  { return L10n.tr("Localizable", "VoiceChat.Settings.AllMembers") }
  /// End Voice Chat
  public static var voiceChatSettingsEnd: String  { return L10n.tr("Localizable", "VoiceChat.Settings.End") }
  /// MODE
  public static var voiceChatSettingsInputMode: String  { return L10n.tr("Localizable", "VoiceChat.Settings.InputMode") }
  /// Noise Suppression
  public static var voiceChatSettingsNoiseSuppression: String  { return L10n.tr("Localizable", "VoiceChat.Settings.NoiseSuppression") }
  /// New participants are muted
  public static var voiceChatSettingsOnlyAdmins: String  { return L10n.tr("Localizable", "VoiceChat.Settings.OnlyAdmins") }
  /// OUTPUT
  public static var voiceChatSettingsOutput: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Output") }
  /// SHORTCUT
  public static var voiceChatSettingsPushToTalk: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk") }
  /// Reduce Motion
  public static var voiceChatSettingsReduceMotion: String  { return L10n.tr("Localizable", "VoiceChat.Settings.ReduceMotion") }
  /// Revoke Speakers Link
  public static var voiceChatSettingsResetLink: String  { return L10n.tr("Localizable", "VoiceChat.Settings.ResetLink") }
  /// VOICE CHAT TITLE
  public static var voiceChatSettingsTitle: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Title") }
  /// personal account
  public static var voiceChatSettingsDisplayAsPersonalAccount: String  { return L10n.tr("Localizable", "VoiceChat.Settings.DisplayAs.PersonalAccount") }
  /// DISPLAY ME AS
  public static var voiceChatSettingsDisplayAsTitle: String  { return L10n.tr("Localizable", "VoiceChat.Settings.DisplayAs.Title") }
  /// Are you sure you want to end this voice chat?
  public static var voiceChatSettingsEndConfirm: String  { return L10n.tr("Localizable", "VoiceChat.Settings.End.Confirm") }
  /// End
  public static var voiceChatSettingsEndConfirmOK: String  { return L10n.tr("Localizable", "VoiceChat.Settings.End.Confirm.OK") }
  /// End voice chat
  public static var voiceChatSettingsEndConfirmTitle: String  { return L10n.tr("Localizable", "VoiceChat.Settings.End.Confirm.Title") }
  /// Press and Release
  public static var voiceChatSettingsInputModeAlways: String  { return L10n.tr("Localizable", "VoiceChat.Settings.InputMode.Always") }
  /// Press and Hold
  public static var voiceChatSettingsInputModePushToTalk: String  { return L10n.tr("Localizable", "VoiceChat.Settings.InputMode.PushToTalk") }
  /// Sound Effects
  public static var voiceChatSettingsInputModeSoundEffects: String  { return L10n.tr("Localizable", "VoiceChat.Settings.InputMode.SoundEffects") }
  /// Output Device
  public static var voiceChatSettingsOutputDevice: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Output.Device") }
  /// Disabling noise suppression can increase performance.
  public static var voiceChatSettingsPerformanceDesc: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Performance.Desc") }
  /// PERFORMANCE
  public static var voiceChatSettingsPerformanceHeader: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Performance.Header") }
  /// PERMISSIONS
  public static var voiceChatSettingsPermissionsTitle: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Permissions.Title") }
  /// If you want this shortcut to work even when Telegram is not in focus\nPlease grant Telegram access to [Input Monitor](input)
  public static var voiceChatSettingsPushToTalkAccess: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Access") }
  /// When the Voice Chat window is in focus, you can also use ⎵ regardless of this setting.
  public static var voiceChatSettingsPushToTalkDesc: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Desc") }
  /// Change Key
  public static var voiceChatSettingsPushToTalkEditKeybind: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.EditKeybind") }
  /// Enabled
  public static var voiceChatSettingsPushToTalkEnabled: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Enabled") }
  /// Cancel
  public static var voiceChatSettingsPushToTalkStopRecording: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.StopRecording") }
  /// PUSH TO TALK
  public static var voiceChatSettingsPushToTalkTitle: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Title") }
  /// Undefined
  public static var voiceChatSettingsPushToTalkUndefined: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Undefined") }
  /// Please allow Accessibility for Telegram in [Privacy Settings.](access)\n\nApp restart may be required.
  public static var voiceChatSettingsPushToTalkAccessOld: String  { return L10n.tr("Localizable", "VoiceChat.Settings.PushToTalk.Access.Old") }
  /// Include Video
  public static var voiceChatSettingsRecordIncludeVideo: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Record.IncludeVideo") }
  /// Landscape
  public static var voiceChatSettingsRecordOrientationLandscape: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Record.Orientation.Landscape") }
  /// Portrait
  public static var voiceChatSettingsRecordOrientationPortrait: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Record.Orientation.Portrait") }
  /// Speaker Link has been revoked.
  public static var voiceChatSettingsResetLinkSuccess: String  { return L10n.tr("Localizable", "VoiceChat.Settings.ResetLink.Success") }
  /// Title...
  public static var voiceChatSettingsTitlePlaceholder: String  { return L10n.tr("Localizable", "VoiceChat.Settings.Title.Placeholder") }
  /// You can't share screencast right now. Please ask to speak.
  public static var voiceChatShareScreenMutedError: String  { return L10n.tr("Localizable", "VoiceChat.ShareScreen.MutedError") }
  /// You can't share video right now. Please ask to speak.
  public static var voiceChatShareVideoMutedError: String  { return L10n.tr("Localizable", "VoiceChat.ShareVideo.MutedError") }
  /// You are sharing your screen
  public static var voiceChatSharingPlaceholder: String  { return L10n.tr("Localizable", "VoiceChat.Sharing.Placeholder") }
  /// Stop
  public static var voiceChatSharingStop: String  { return L10n.tr("Localizable", "VoiceChat.Sharing.Stop") }
  /// Connecting...
  public static var voiceChatStatusConnecting: String  { return L10n.tr("Localizable", "VoiceChat.Status.Connecting") }
  /// invited
  public static var voiceChatStatusInvited: String  { return L10n.tr("Localizable", "VoiceChat.Status.Invited") }
  /// listening
  public static var voiceChatStatusListening: String  { return L10n.tr("Localizable", "VoiceChat.Status.Listening") }
  /// connecting...
  public static var voiceChatStatusLoading: String  { return L10n.tr("Localizable", "VoiceChat.Status.Loading") }
  /// %d
  public static func voiceChatStatusMembersCountable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_countable", p1)
  }
  /// %d participants
  public static func voiceChatStatusMembersFew(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_few", p1)
  }
  /// %d participants
  public static func voiceChatStatusMembersMany(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_many", p1)
  }
  /// %d participant
  public static func voiceChatStatusMembersOne(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_one", p1)
  }
  /// %d participants
  public static func voiceChatStatusMembersOther(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_other", p1)
  }
  /// %d participants
  public static func voiceChatStatusMembersTwo(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Status.Members_two", p1)
  }
  /// no participants
  public static var voiceChatStatusMembersZero: String  { return L10n.tr("Localizable", "VoiceChat.Status.Members_zero") }
  /// muted
  public static var voiceChatStatusMuted: String  { return L10n.tr("Localizable", "VoiceChat.Status.Muted") }
  /// muted for you
  public static var voiceChatStatusMutedForYou: String  { return L10n.tr("Localizable", "VoiceChat.Status.MutedForYou") }
  /// sharing screen
  public static var voiceChatStatusScreensharing: String  { return L10n.tr("Localizable", "VoiceChat.Status.Screensharing") }
  /// speaking
  public static var voiceChatStatusSpeaking: String  { return L10n.tr("Localizable", "VoiceChat.Status.Speaking") }
  /// wants to speak
  public static var voiceChatStatusWantsSpeak: String  { return L10n.tr("Localizable", "VoiceChat.Status.WantsSpeak") }
  /// This is you
  public static var voiceChatStatusYou: String  { return L10n.tr("Localizable", "VoiceChat.Status.You") }
  /// Leave
  public static var voiceChatTitleEnd: String  { return L10n.tr("Localizable", "VoiceChat.Title.End") }
  /// invited
  public static var voiceChatTitleInvited: String  { return L10n.tr("Localizable", "VoiceChat.Title.Invited") }
  /// Invite Members
  public static var voiceChatTitleInviteMembers: String  { return L10n.tr("Localizable", "VoiceChat.Title.InviteMembers") }
  /// Voice Chat
  public static var voiceChatTitleScheduled: String  { return L10n.tr("Localizable", "VoiceChat.Title.Scheduled") }
  /// scheduled
  public static var voiceChatTitleScheduledSoon: String  { return L10n.tr("Localizable", "VoiceChat.Title.Scheduled.Soon") }
  /// Audio saved to Saved Messsages.
  public static var voiceChatToastStop: String  { return L10n.tr("Localizable", "VoiceChat.Toast.Stop") }
  /// Now you can speak in the voice chat
  public static var voiceChatToastYouCanSpeak: String  { return L10n.tr("Localizable", "VoiceChat.Toast.YouCanSpeak") }
  /// Your camera is off. Click here to enable camera.
  public static var voiceChatTooltipEnableCamera: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.EnableCamera") }
  /// You are on mute. Click here to speak.
  public static var voiceChatTooltipEnableMicro: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.EnableMicro") }
  /// **%@** is speaking
  public static func voiceChatTooltipIsSpeaking(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.IsSpeaking", p1)
  }
  /// No active and connected camera was found.
  public static var voiceChatTooltipNoCameraFound: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.NoCameraFound") }
  /// Window is pinned.
  public static var voiceChatTooltipPinWindow: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.PinWindow") }
  /// An error occured. Screencast has stopped.
  public static var voiceChatTooltipScreencastFailed: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.ScreencastFailed") }
  /// %@'s screencast is pinned
  public static func voiceChatTooltipScreenPinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.ScreenPinned", p1)
  }
  /// %@'s screencast is unpinned
  public static func voiceChatTooltipScreenUnpinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.ScreenUnpinned", p1)
  }
  /// Your screen is being broadcast.
  public static var voiceChatTooltipShareScreen: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.ShareScreen") }
  /// Your video is being broadcast.
  public static var voiceChatTooltipShareVideo: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.ShareVideo") }
  /// You have stopped broadcasting screen.
  public static var voiceChatTooltipStopScreen: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.StopScreen") }
  /// You have stopped broadcasting video.
  public static var voiceChatTooltipStopVideo: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.StopVideo") }
  /// We will notify you when it starts
  public static var voiceChatTooltipSubscribe: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.Subscribe") }
  /// Window is unpinned.
  public static var voiceChatTooltipUnpinWindow: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.UnpinWindow") }
  /// An error occured. Video stream has stopped.
  public static var voiceChatTooltipVideoFailed: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.VideoFailed") }
  /// %@'s video is pinned
  public static func voiceChatTooltipVideoPinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.VideoPinned", p1)
  }
  /// %@'s video is unpinned
  public static func voiceChatTooltipVideoUnpinned(_ p1: String) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.VideoUnpinned", p1)
  }
  /// Your screencast is pinned
  public static var voiceChatTooltipYourScreenPinned: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.YourScreenPinned") }
  /// Your screencast is unpinned
  public static var voiceChatTooltipYourScreenUnpinned: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.YourScreenUnpinned") }
  /// Your video is pinned
  public static var voiceChatTooltipYourVideoPinned: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.YourVideoPinned") }
  /// Your video is unpinned
  public static var voiceChatTooltipYourVideoUnpinned: String  { return L10n.tr("Localizable", "VoiceChat.Tooltip.YourVideoUnpinned") }
  /// Screencast is only available for the first %d members.
  public static func voiceChatTooltipErrorScreenUnavailable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.Error.ScreenUnavailable", p1)
  }
  /// Video is only available for the first %d members
  public static func voiceChatTooltipErrorVideoUnavailable(_ p1: Int) -> String {
    return L10n.tr("Localizable", "VoiceChat.Tooltip.Error.VideoUnavailable", p1)
  }
  /// Video is Paused
  public static var voiceChatVideoPaused: String  { return L10n.tr("Localizable", "VoiceChat.Video.Paused") }
  /// Pin
  public static var voiceChatVideoShortPin: String  { return L10n.tr("Localizable", "VoiceChat.Video.ShortPin") }
  /// Unpin
  public static var voiceChatVideoShortUnpin: String  { return L10n.tr("Localizable", "VoiceChat.Video.ShortUnpin") }
  /// Video Source
  public static var voiceChatVideoVideoSource: String  { return L10n.tr("Localizable", "VoiceChat.Video.VideoSource") }
  /// more
  public static var voiceChatVideoStreamMore: String  { return L10n.tr("Localizable", "VoiceChat.Video.Stream.More") }
  /// screen
  public static var voiceChatVideoStreamScreencast: String  { return L10n.tr("Localizable", "VoiceChat.Video.Stream.Screencast") }
  /// video
  public static var voiceChatVideoStreamVideo: String  { return L10n.tr("Localizable", "VoiceChat.Video.Stream.Video") }
  /// Cancel
  public static var voiceChatVideoVideoSourceCancel: String  { return L10n.tr("Localizable", "VoiceChat.Video.VideoSource.Cancel") }
  /// Share
  public static var voiceChatVideoVideoSourceShare: String  { return L10n.tr("Localizable", "VoiceChat.Video.VideoSource.Share") }
  /// Unavailable to share your camera, please grant access is [System Settings](camera).
  public static var voiceChatVideoShareUnavailable: String  { return L10n.tr("Localizable", "VoiceChat.VideoShare.Unavailable") }
  /// Title (Optional)
  public static var voiecChatSettingsRecordPlaceholder1: String  { return L10n.tr("Localizable", "VoiecChat.Settings.Record.Placeholder1") }
  /// RECORD VOICE CHAT
  public static var voiecChatSettingsRecordTitle: String  { return L10n.tr("Localizable", "VoiecChat.Settings.Record.Title") }
  /// RECORD LIVE STREAM
  public static var voiecChatSettingsRecordLiveTitle: String  { return L10n.tr("Localizable", "VoiecChat.Settings.Record.Live.Title") }
  /// RECORD VIDEO CHAT
  public static var voiecChatSettingsRecordVideoTitle: String  { return L10n.tr("Localizable", "VoiecChat.Settings.Record.Video.Title") }
  /// Edit
  public static var w486f4DlTitle: String  { return L10n.tr("Localizable", "W48-6f-4Dl.title") }
  /// Apply
  public static var wallpaperPreviewApply: String  { return L10n.tr("Localizable", "WallpaperPreview.Apply") }
  /// Blurred
  public static var wallpaperPreviewBlurred: String  { return L10n.tr("Localizable", "WallpaperPreview.Blurred") }
  /// Sorry, this background doesn't seem to exist.
  public static var wallpaperPreviewDoesntExists: String  { return L10n.tr("Localizable", "WallpaperPreview.DoesntExists") }
  /// Background Preview
  public static var wallpaperPreviewHeader: String  { return L10n.tr("Localizable", "WallpaperPreview.Header") }
  /// Paste and Match Style
  public static var weT3VZwkTitle: String  { return L10n.tr("Localizable", "WeT-3V-zwk.title") }
  /// Disconnect
  public static var webAuthorizationsLogout: String  { return L10n.tr("Localizable", "WebAuthorizations.Logout") }
  /// Disconnect All Websites
  public static var webAuthorizationsLogoutAll: String  { return L10n.tr("Localizable", "WebAuthorizations.LogoutAll") }
  /// Do you want to disconnect this website?
  public static var webAuthorizationsConfirmRevoke: String  { return L10n.tr("Localizable", "WebAuthorizations.Confirm.Revoke") }
  /// Are you sure you want to disconnect all websites?
  public static var webAuthorizationsConfirmRevokeAll: String  { return L10n.tr("Localizable", "WebAuthorizations.Confirm.RevokeAll") }
  /// CONNECTED WEBSITES
  public static var webAuthorizationsLoggedInDescrpiption: String  { return L10n.tr("Localizable", "WebAuthorizations.LoggedIn.Descrpiption") }
  /// You can log in on websites that support signing in with Telegram.
  public static var webAuthorizationsLogoutAllDescription: String  { return L10n.tr("Localizable", "WebAuthorizations.LogoutAll.Description") }
  /// Fri
  public static var weekdayShortFriday: String  { return L10n.tr("Localizable", "Weekday.ShortFriday") }
  /// Mon
  public static var weekdayShortMonday: String  { return L10n.tr("Localizable", "Weekday.ShortMonday") }
  /// Sat
  public static var weekdayShortSaturday: String  { return L10n.tr("Localizable", "Weekday.ShortSaturday") }
  /// Sun
  public static var weekdayShortSunday: String  { return L10n.tr("Localizable", "Weekday.ShortSunday") }
  /// Thu
  public static var weekdayShortThursday: String  { return L10n.tr("Localizable", "Weekday.ShortThursday") }
  /// Tue
  public static var weekdayShortTuesday: String  { return L10n.tr("Localizable", "Weekday.ShortTuesday") }
  /// Wed
  public static var weekdayShortWednesday: String  { return L10n.tr("Localizable", "Weekday.ShortWednesday") }
  /// Use ⌘+K or ESC to enter [search](search) mode.
  public static var widgetRecentDesc: String  { return L10n.tr("Localizable", "Widget.Recent.Desc") }
  /// Both
  public static var widgetRecentMixed: String  { return L10n.tr("Localizable", "Widget.Recent.Mixed") }
  /// Popular
  public static var widgetRecentPopular: String  { return L10n.tr("Localizable", "Widget.Recent.Popular") }
  /// Recent
  public static var widgetRecentRecent: String  { return L10n.tr("Localizable", "Widget.Recent.Recent") }
  /// Chats
  public static var widgetRecentTitle: String  { return L10n.tr("Localizable", "Widget.Recent.Title") }
  /// Edit
  public static var ns103Title: String  { return L10n.tr("Localizable", "_NS103.title") }
  /// Window
  public static var ns167Title: String  { return L10n.tr("Localizable", "_NS167.title") }
  /// View
  public static var ns70Title: String  { return L10n.tr("Localizable", "_NS70.title") }
  /// View
  public static var ns81Title: String  { return L10n.tr("Localizable", "_NS81.title") }
  /// Edit
  public static var ns88Title: String  { return L10n.tr("Localizable", "_NS88.title") }
  /// Edit
  public static var ns104Title: String  { return L10n.tr("Localizable", "_NS:104.title") }
  /// Window
  public static var ns163Title: String  { return L10n.tr("Localizable", "_NS:163.title") }
  /// Window
  public static var ns168Title: String  { return L10n.tr("Localizable", "_NS:168.title") }
  /// View
  public static var ns77Title: String  { return L10n.tr("Localizable", "_NS:77.title") }
  /// View
  public static var ns82Title: String  { return L10n.tr("Localizable", "_NS:82.title") }
  /// Edit
  public static var ns99Title: String  { return L10n.tr("Localizable", "_NS:99.title") }
  /// Global Search
  public static var aMaRbKjVTitle: String  { return L10n.tr("Localizable", "aMa-rb-kjV.title") }
  /// Window
  public static var aufd15bRTitle: String  { return L10n.tr("Localizable", "aUF-d1-5bR.title") }
  /// Transformations
  public static var c8aY6VQdTitle: String  { return L10n.tr("Localizable", "c8a-y6-VQd.title") }
  /// Smart Links
  public static var cwLP1JidTitle: String  { return L10n.tr("Localizable", "cwL-P1-jid.title") }
  /// Make Lower Case
  public static var d9MCDAMdTitle: String  { return L10n.tr("Localizable", "d9M-CD-aMd.title") }
  /// Undo
  public static var drj4nYzgTitle: String  { return L10n.tr("Localizable", "dRJ-4n-Yzg.title") }
  /// Paste
  public static var gvau4SdLTitle: String  { return L10n.tr("Localizable", "gVA-U4-sdL.title") }
  /// Smart Quotes
  public static var hQb2vFYvTitle: String  { return L10n.tr("Localizable", "hQb-2v-fYv.title") }
  /// Check Document Now
  public static var hz2CUCR7Title: String  { return L10n.tr("Localizable", "hz2-CU-CR7.title") }
  /// Check Grammar With Spelling
  public static var mk62p4JGTitle: String  { return L10n.tr("Localizable", "mK6-2p-4JG.title") }
  /// Delete
  public static var pa3QIU2kTitle: String  { return L10n.tr("Localizable", "pa3-QI-u2k.title") }
  /// Leave
  public static var peerInfoConfirmLeave: String  { return L10n.tr("Localizable", "peerInfo.Confirm.Leave") }
  /// This will delete all messages and media in this chat from your Telegram cloud. Other members of the group will still have them.
  public static var peerInfoConfirmClearHistoryGroup: String  { return L10n.tr("Localizable", "peerInfo.Confirm.ClearHistory.Group") }
  /// This will delete all messages and media in this chat from your Telegram cloud.
  public static var peerInfoConfirmClearHistorySavedMesssages: String  { return L10n.tr("Localizable", "peerInfo.Confirm.ClearHistory.SavedMesssages") }
  /// This will delete all messages and media in this chat from your Telegram cloud. Your chat partner will still have them.
  public static var peerInfoConfirmClearHistoryUser: String  { return L10n.tr("Localizable", "peerInfo.Confirm.ClearHistory.User") }
  /// Are you sure you want to delete all messages in the chat?
  public static var peerInfoConfirmClearHistoryUserBothSides: String  { return L10n.tr("Localizable", "peerInfo.Confirm.ClearHistory.UserBothSides") }
  /// PSA
  public static var psaChatlist: String  { return L10n.tr("Localizable", "psa.chatlist") }
  /// This message provides you with a public service announcement in your chat list
  public static var psaText: String  { return L10n.tr("Localizable", "psa.text") }
  /// PSA Notification
  public static var psaTitle: String  { return L10n.tr("Localizable", "psa.title") }
  /// Public Service Announcement
  public static var psaChatTitle: String  { return L10n.tr("Localizable", "psa.chat.title") }
  /// This message provides you with a public service announcement.
  public static var psaChatTextCovid: String  { return L10n.tr("Localizable", "psa.chat.text.covid") }
  /// PSA Notification\nfrom: [%@]()
  public static func psaTitleBubbles(_ p1: String) -> String {
    return L10n.tr("Localizable", "psa.title.bubbles", p1)
  }
  /// Check Spelling While Typing
  public static var rbDRhWINTitle: String  { return L10n.tr("Localizable", "rbD-Rh-wIN.title") }
  /// Smart Dashes
  public static var rgMF4YcnTitle: String  { return L10n.tr("Localizable", "rgM-f4-ycn.title") }
  /// Quick Search
  public static var sZhCtGQSTitle: String  { return L10n.tr("Localizable", "sZh-ct-GQS.title") }
  /// Data Detectors
  public static var tRrPd1PSTitle: String  { return L10n.tr("Localizable", "tRr-pd-1PS.title") }
  /// Telegram
  public static var uQyDDJDrTitle: String  { return L10n.tr("Localizable", "uQy-DD-JDr.title") }
  /// Cut
  public static var uRlIYUnGTitle: String  { return L10n.tr("Localizable", "uRl-iY-unG.title") }
  /// Make Upper Case
  public static var vmV6d7jITitle: String  { return L10n.tr("Localizable", "vmV-6d-7jI.title") }
  /// Copy
  public static var x3vGGIWUTitle: String  { return L10n.tr("Localizable", "x3v-GG-iWU.title") }
  /// Show Substitutions
  public static var z6FFW3nzTitle: String  { return L10n.tr("Localizable", "z6F-FW-3nz.title") }
}
// swiftlint:enable identifier_name line_length type_body_length

extension L10n {
  private static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
    return translate(key: key, args)
  }
}

private final class BundleToken {}
