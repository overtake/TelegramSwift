// Generated using SwiftGen, by O.Halligon — https://github.com/AliSoftware/SwiftGen

import Foundation

// swiftlint:disable file_length
// swiftlint:disable line_length

// swiftlint:disable type_body_length
enum L10n {
  /// Default
  case defaultSoundName
  /// None
  case notificationSettingsToneNone
  /// incorrect password
  case passwordHashInvalid
  /// code expired
  case phoneCodeExpired
  /// phone code invalid
  case phoneCodeInvalid
  /// invalid phone number
  case phoneNumberInvalid
  /// You
  case you
  /// Check for Updates
  case _1000Title
  /// Telegram
  case _1XtHYUBwTitle
  /// Transformations
  case _2oIRnZJCTitle
  /// Enter Full Screen
  case _4J7DPTxaTitle
  /// Quit Telegram
  case _4sb4sVLiTitle
  /// About Telegram
  case _5kVVbQxSTitle
  /// Edit
  case _5QFOaP0TTitle
  /// Redo
  case _6dhZSVamTitle
  /// Correct Spelling Automatically
  case _78YHA62vTitle
  /// Substitutions
  case _9icFLObxTitle
  /// Smart Copy/Paste
  case _9yt4BNSMTitle
  /// Free messaging app for macOS based on MTProto for speed and security.
  case aboutDescription
  /// Please note that Telegram Support is done by volunteers. We try to respond as quickly as possible, but it may take a while. \n\nPlease take a look at the Telegram FAQ: it has important troubleshooting tips and answers to most questions.
  case accountConfirmAskQuestion
  /// Open FAQ
  case accountConfirmGoToFaq
  /// Log out?
  case accountConfirmLogout
  /// Remember, logging out cancels all your Secret Chats.
  case accountConfirmLogoutText
  /// New Account
  case accountsControllerNewAccount
  /// About
  case accountSettingsAbout
  /// Appearance
  case accountSettingsAppearance
  /// Ask a Question
  case accountSettingsAskQuestion
  /// Bio
  case accountSettingsBio
  /// English
  case accountSettingsCurrentLanguage
  /// Telegram FAQ
  case accountSettingsFAQ
  /// General
  case accountSettingsGeneral
  /// Language
  case accountSettingsLanguage
  /// Logout
  case accountSettingsLogout
  /// Notifications
  case accountSettingsNotifications
  /// Privacy and Security
  case accountSettingsPrivacyAndSecurity
  /// Set a Bio
  case accountSettingsSetBio
  /// Set Profile Photo
  case accountSettingsSetProfilePhoto
  /// Set a Username
  case accountSettingsSetUsername
  /// Stickers
  case accountSettingsStickers
  /// Storage
  case accountSettingsStorage
  /// Username
  case accountSettingsUsername
  /// Add Admin
  case adminsAddAdmin
  /// Admin
  case adminsAdmin
  /// CHANNEL ADMINS
  case adminsChannelAdmins
  /// You can add admins to help you manage your channel
  case adminsChannelDescription
  /// Creator
  case adminsCreator
  /// Everybody can add new members
  case adminsEverbodyCanAddMembers
  /// GROUP ADMINS
  case adminsGroupAdmins
  /// You can add admins to help you manage your group
  case adminsGroupDescription
  /// Only Admins can add new members
  case adminsOnlyAdminsCanAddMembers
  /// Contacts
  case adminsSelectNewAdminTitle
  /// Only Admins
  case adminsWhoCanInviteAdmins
  /// All Members
  case adminsWhoCanInviteEveryone
  /// Who can add members
  case adminsWhoCanInviteText
  /// Cancel
  case alertCancel
  /// OK
  case alertOK
  /// Sorry, this user doesn't seem to exist.
  case alertUserDoesntExists
  /// Can't forward messages to this conversation.
  case alertForwardError
  /// Delete
  case alertSendErrorDelete
  /// Your message could not be sent
  case alertSendErrorHeader
  /// Ignore
  case alertSendErrorIgnore
  /// Resend
  case alertSendErrorResend
  /// An error occurred while sending the previous message. Would you like to resend it ?
  case alertSendErrorText
  /// Maximum file size is 1.5 GB
  case appMaxFileSize
  /// You can have up to 200 sticker sets installed. Unused stickers are archived when you add more.
  case archivedStickersDescription
  /// Unknown Artist
  case audioUnknownArtist
  /// Untitled
  case audioUntitledSong
  /// video message
  case audioControllerVideoMessage
  /// voice message
  case audioControllerVoiceMessage
  /// Release outside of this field to cancel
  case audioRecordReleaseOut
  /// Window
  case aufd15bRTitle
  /// Any details such as age, occupation of city. Example: 23 y.o. designer from San Francisco
  case bioDescription
  /// A few words about you
  case bioPlaceholder
  /// Save
  case bioSave
  /// Blocked users can't send you messages or add you to groups. They will not see your profile pictures, online and last seen status.
  case blockedPeersEmptyDescrpition
  /// Preferences…
  case bofnm1cWTitle
  /// Transformations
  case c8aY6VQdTitle
  /// Hide Telegram
  case cagYXWT6Title
  /// %@'s app does not support calls. They need to update their app before you can call them.
  case callParticipantVersionOutdatedError(String)
  /// Sorry, %@ doesn't accept calls.
  case callPrivacyErrorMessage(String)
  /// %d
  case callShortMinutesCountable(Int)
  /// %d min
  case callShortMinutesFew(Int)
  /// %d min
  case callShortMinutesMany(Int)
  /// %d min
  case callShortMinutesOne(Int)
  /// %d min
  case callShortMinutesOther(Int)
  /// %d min
  case callShortMinutesTwo(Int)
  /// %d min
  case callShortMinutesZero(Int)
  /// %d
  case callShortSecondsCountable(Int)
  /// %d sec
  case callShortSecondsFew(Int)
  /// %d sec
  case callShortSecondsMany(Int)
  /// %d sec
  case callShortSecondsOne(Int)
  /// %d sec
  case callShortSecondsOther(Int)
  /// %d sec
  case callShortSecondsTwo(Int)
  /// %d sec
  case callShortSecondsZero(Int)
  /// Busy
  case callStatusBusy
  /// is calling you...
  case callStatusCalling
  /// Connecting...
  case callStatusConnecting
  /// Call Ended
  case callStatusEnded
  /// Call Failed
  case callStatusFailed
  /// Contacting...
  case callStatusRequesting
  /// Ringing...
  case callStatusRinging
  /// Undefined Error, please try later.
  case callUndefinedError
  /// Finish call with %@ and start a new one with %@?
  case callConfirmDiscardCurrentDescription(String, String)
  /// Call in Progress
  case callConfirmDiscardCurrentHeader
  /// Leave comment...
  case callRatingModalPlaceholder
  /// Incoming
  case callRecentIncoming
  /// Missed
  case callRecentMissed
  /// Outgoing
  case callRecentOutgoing
  /// End Call
  case callHeaderEndCall
  /// Forever
  case channelBanForever
  /// Channel Name
  case channelChannelNameHolder
  /// Create
  case channelCreate
  /// Description
  case channelDescriptionHolder
  /// You can provide an optional description for your channel.
  case channelDescriptionHolderDescrpiton
  /// People can join your channel by following this link. You can revoke the link at any time.
  case channelExportLinkAboutChannel
  /// People can join your group by following this link. You can revoke the link at any time.
  case channelExportLinkAboutGroup
  /// Channels are a tool for broadcasting your messages to large audiences.
  case channelIntroDescription
  /// What is a Channel?
  case channelIntroDescriptionHeader
  /// New Channel
  case channelNewChannel
  /// Private
  case channelPrivate
  /// Private channels can only be joined via an invite link.
  case channelPrivateAboutChannel
  /// Private groups can only be joined if you were invited or by invite link.
  case channelPrivateAboutGroup
  /// Public
  case channelPublic
  /// Public channels can be found via search, anyone can join them.
  case channelPublicAboutChannel
  /// Public groups can be found via search, chat history is available to everyone and anyone can join.
  case channelPublicAboutGroup
  /// Sorry, you have reserved too many public usernames. You can revoke the link from one of your older groups or channels, or create a private entity instead
  case channelPublicNamesLimitError
  /// CHANNEL TYPE
  case channelTypeHeaderChannel
  /// GROUP TYPE
  case channelTypeHeaderGroup
  /// People can share this link with others and find your channel using Telegram search.
  case channelUsernameAboutChannel
  /// People can share this link with others and find your group using Telegram search.
  case channelUsernameAboutGroup
  /// USER RESTRICTIONS
  case channelUserRestriction
  /// This Admin will be able to add new admins with the same (or more limited) permissions than he/she has.
  case channelAdminAdminAccess
  /// This admin will not be able to add new admins.
  case channelAdminAdminRestricted
  /// You cannot edit the rights of this admin.
  case channelAdminCantEditRights
  /// Dismiss Admin
  case channelAdminDismiss
  /// WHAT CAN THIS ADMIN DO?
  case channelAdminWhatCanAdminDo
  /// Sorry you can't promote this user to admin
  case channelAdminsAddAdminError
  /// promoted by %@
  case channelAdminsPromotedBy(String)
  /// Sorry, you can't add this user as an admin because they are in the blacklist and you can't unban them.
  case channelAdminsPromoteBannedAdminError
  /// Sorry, you can't add this user as an admin because they are not a member of this group and you are not allowed to invite them.
  case channelAdminsPromoteUnmemberAdminError
  /// blocked by %@
  case channelBlacklistBlockedBy(String)
  /// Sorry, you can't ban this user because they are an admin in this group and you are not allowed to demote them.
  case channelBlacklistDemoteAdminError
  /// restricted by %@
  case channelBlacklistRestrictedBy(String)
  /// Members
  case channelBlacklistSelectNewUserTitle
  /// Unban
  case channelBlacklistUnban
  /// Block For
  case channelBlockUserBlockFor
  /// Can Embed Links
  case channelBlockUserCanEmbedLinks
  /// Can Read Messages
  case channelBlockUserCanReadMessages
  /// Can Send Media
  case channelBlockUserCanSendMedia
  /// Can Send Messages
  case channelBlockUserCanSendMessages
  /// Can Send Stickers & GIFs
  case channelBlockUserCanSendStickers
  /// Add New Admins
  case channelEditAdminPermissionAddNewAdmins
  /// Ban Users
  case channelEditAdminPermissionBanUsers
  /// Change Channel Info
  case channelEditAdminPermissionChangeInfo
  /// Delete Messages
  case channelEditAdminPermissionDeleteMessages
  /// Edit Messages
  case channelEditAdminPermissionEditMessages
  /// Invite Users
  case channelEditAdminPermissionInviteUsers
  /// Pin Messages
  case channelEditAdminPermissionPinMessages
  /// Post Messages
  case channelEditAdminPermissionPostMessages
  /// ADMINS
  case channelEventFilterAdminsHeader
  /// EVENTS
  case channelEventFilterEventsHeader
  /// Empty
  case channelEventLogEmpty
  /// ** No events found**\n\nNo recent events that match your query have been found.
  case channelEventLogEmptySearch
  /// **No events here yet**\n\nThere were no service actions taken by the channel's members and admins for the last 48 hours.
  case channelEventLogEmptyText
  /// Original message
  case channelEventLogOriginalMessage
  /// What Is This?
  case channelEventLogWhat
  /// What is an event log?
  case channelEventLogAlertHeader
  /// This is a list of all service actions taken by the group's members and admins in the last 48 hours.
  case channelEventLogAlertInfo
  /// %@ removed channel description:
  case channelEventLogServiceAboutRemoved(String)
  /// %@ edited channel description:
  case channelEventLogServiceAboutUpdated(String)
  /// %@ disabled channel signatures
  case channelEventLogServiceDisableSignatures(String)
  /// %@ enabled channel signatures
  case channelEventLogServiceEnableSignatures(String)
  /// %@ removed channel link:
  case channelEventLogServiceLinkRemoved(String)
  /// %@ edited channel link:
  case channelEventLogServiceLinkUpdated(String)
  /// %@ removed channel photo
  case channelEventLogServicePhotoRemoved(String)
  /// %@ updated channel photo
  case channelEventLogServicePhotoUpdated(String)
  /// %@ edited channel title:
  case channelEventLogServiceTitleUpdated(String)
  /// %@ joined the channel
  case channelEventLogServiceUpdateJoin(String)
  /// %@ left the channel
  case channelEventLogServiceUpdateLeft(String)
  /// The admins of this group have restricted you from posting inline content here
  case channelPersmissionDeniedSendInlineForever
  /// The admins of this group have restricted you from posting inline content here until %@
  case channelPersmissionDeniedSendInlineUntil(String)
  /// The admins of this group have restricted you from sending media here
  case channelPersmissionDeniedSendMediaForever
  /// The admins of this group have restricted you from sending media here until %@
  case channelPersmissionDeniedSendMediaUntil(String)
  /// The admins of this group have restricted you from writing here
  case channelPersmissionDeniedSendMessagesForever
  /// The admins of this group have restricted you from writing here until %@
  case channelPersmissionDeniedSendMessagesUntil(String)
  /// The admins of this group have restricted you from sending stickers here
  case channelPersmissionDeniedSendStickersForever
  /// The admins of this group have restricted you from sending stickers here until %@
  case channelPersmissionDeniedSendStickersUntil(String)
  /// contacts
  case channelSelectPeersContacts
  /// global
  case channelSelectPeersGlobal
  /// Recent Actions
  case channelAdminsRecentActions
  /// Add Member
  case channelBlacklistAddMember
  /// BLOCKED
  case channelBlacklistBlocked
  /// Blacklisted users are removed from the group and can only come back if invited by an admin. Invite links don't work for them.
  case channelBlacklistEmptyDescrpition
  /// RESTRICTED
  case channelBlacklistRestricted
  /// Channel Info
  case channelEventFilterChannelInfo
  /// Deleted Messages
  case channelEventFilterDeletedMessages
  /// Edited Messages
  case channelEventFilterEditedMessages
  /// Group Info
  case channelEventFilterGroupInfo
  /// Members Removed
  case channelEventFilterLeavingMembers
  /// New Admins
  case channelEventFilterNewAdmins
  /// New Members
  case channelEventFilterNewMembers
  /// New Restrictions
  case channelEventFilterNewRestrictions
  /// Pinned Messages
  case channelEventFilterPinnedMessages
  /// Add Members
  case channelMembersAddMembers
  /// Invite via Link
  case channelMembersInviteLink
  /// Only channel admins can see this list.
  case channelMembersMembersListDesc
  /// Add Members
  case channelMembersSelectTitle
  /// Checking
  case channelVisibilityChecking
  /// Loading...
  case channelVisibilityLoading
  /// admin
  case chatAdminBadge
  /// Cancel
  case chatCancel
  /// without compression
  case chatDropAsFilesDesc
  /// in a quick way
  case chatDropQuickDesc
  /// Drop files here to send them
  case chatDropTitle
  /// No messages here yet
  case chatEmptyChat
  /// Forward Messages
  case chatForwardActionHeader
  /// INSTANT VIEW
  case chatInstantView
  /// %d of %d
  case chatSearchCount(Int, Int)
  /// from:
  case chatSearchFrom
  /// Share
  case chatShareInlineResultActionHeader
  /// Incoming Call
  case chatCallIncoming
  /// Outgoing Call
  case chatCallOutgoing
  /// This action can't be undone
  case chatConfirmActionUndonable
  /// Delete selected messages?
  case chatConfirmDeleteMessages
  /// Delete for All
  case chatConfirmDeleteMessagesForEveryone
  /// Would you like to unpin this message?
  case chatConfirmUnpin
  /// Connecting
  case chatConnectingStatusConnecting
  /// Connecting to proxy
  case chatConnectingStatusConnectingToProxy
  /// Updating
  case chatConnectingStatusUpdating
  /// Waiting for network
  case chatConnectingStatusWaitingNetwork
  /// Add to Favorites
  case chatContextAddFavoriteSticker
  /// Clear History
  case chatContextClearHistory
  /// Copy Preformatted Block
  case chatContextCopyBlock
  /// Unmute
  case chatContextDisableNotifications
  /// Edit (click on date)
  case chatContextEdit
  /// Mute
  case chatContextEnableNotifications
  /// Info
  case chatContextInfo
  /// Remove from Favorites
  case chatContextRemoveFavoriteSticker
  /// Pinned message
  case chatHeaderPinnedMessage
  /// Report Spam
  case chatHeaderReportSpam
  /// Delete and exit
  case chatInputDelete
  /// Join
  case chatInputJoin
  /// Mute
  case chatInputMute
  /// Return to group
  case chatInputReturn
  /// Start
  case chatInputStartBot
  /// Unblock
  case chatInputUnblock
  /// Unmute
  case chatInputUnmute
  /// Edit Message
  case chatInputAccessoryEditMessage
  /// Waiting for the user to come online...
  case chatInputSecretChatWaitingToOnline
  /// Contact
  case chatListContact
  /// GIF
  case chatListGIF
  /// Video message
  case chatListInstantVideo
  /// Location
  case chatListMap
  /// Photo
  case chatListPhoto
  /// %@ Sticker
  case chatListSticker(String)
  /// Video
  case chatListVideo
  /// Voice message
  case chatListVoice
  /// Payment: %@
  case chatListServicePaymentSent(String)
  /// edited
  case chatMessageEdited
  /// This message is not supported by your version of Telegram. Please update to the latest version from the AppStore or install it from https://macos.telegram.org
  case chatMessageUnsupported
  /// via
  case chatMessageVia
  ///  - Use end-to-end encryption
  case chatSecretChat1Feature
  ///  - Leave no trace on our servers
  case chatSecretChat2Feature
  ///  - Have a self-destruct timer
  case chatSecretChat3Feature
  ///  - Do not allow forwarding
  case chatSecretChat4Feature
  /// Secret chats:
  case chatSecretChatEmptyHeader
  /// You have just successfully transferred **%@** to **%@** for **%@**
  case chatServicePaymentSent(String, String, String)
  /// pinned message
  case chatServicePinnedMessage
  /// You
  case chatServiceYou
  /// channel photo removed
  case chatServiceChannelRemovedPhoto
  /// channel photo updated
  case chatServiceChannelUpdatedPhoto
  /// channel renamed to "%@"
  case chatServiceChannelUpdatedTitle(String)
  /// %@ invited %@
  case chatServiceGroupAddedMembers(String, String)
  /// %@ joined group
  case chatServiceGroupAddedSelf(String)
  /// %@ created the group "%@"
  case chatServiceGroupCreated(String, String)
  /// %@ joined group via invite link
  case chatServiceGroupJoinedByLink(String)
  /// This group was upgraded to a supergroup
  case chatServiceGroupMigratedToSupergroup
  /// %@ kicked %@
  case chatServiceGroupRemovedMembers(String, String)
  /// %@ removed group photo
  case chatServiceGroupRemovedPhoto(String)
  /// %@ left group
  case chatServiceGroupRemovedSelf(String)
  /// %@ took a screenshot
  case chatServiceGroupTookScreenshot(String)
  /// %@ updated group photo
  case chatServiceGroupUpdatedPhoto(String)
  /// %@ pinned "%@"
  case chatServiceGroupUpdatedPinnedMessage(String, String)
  /// %@ changed group name to "%@"
  case chatServiceGroupUpdatedTitle(String, String)
  /// %@ disabled the self-destruct timer
  case chatServiceSecretChatDisabledTimer(String)
  /// %@ set the self-destruct timer to %@
  case chatServiceSecretChatSetTimer(String, String)
  /// You disabled the self-destruct timer
  case chatServiceSecretChatDisabledTimerSelf
  /// You set the self-destruct timer to %@
  case chatServiceSecretChatSetTimerSelf(String)
  /// Your Cloud storage
  case chatTitleSelf
  /// Draft:
  case chatListDraft
  /// Message is not supported
  case chatListUnsupportedMessage
  /// You
  case chatListYou
  /// Call
  case chatListContextCall
  /// Clear History
  case chatListContextClearHistory
  /// Delete And Exit
  case chatListContextDeleteAndExit
  /// Delete Chat
  case chatListContextDeleteChat
  /// Leave Channel
  case chatListContextLeaveChannel
  /// Leave Group
  case chatListContextLeaveGroup
  /// Mute
  case chatListContextMute
  /// Pin
  case chatListContextPin
  /// Return Group
  case chatListContextReturnGroup
  /// Unmute
  case chatListContextUnmute
  /// Unpin
  case chatListContextUnpin
  /// %@ created a secret chat.
  case chatListSecretChatCreated(String)
  /// Waiting to come online
  case chatListSecretChatExKeys
  /// %@ joined your secret chat.
  case chatListSecretChatJoined(String)
  /// Secret chat cancelled
  case chatListSecretChatTerminated
  /// self-destructing photo
  case chatListServiceDestructingPhoto
  /// self-destructing video
  case chatListServiceDestructingVideo
  /// scored %d in %@
  case chatListServiceGameScored(Int, String)
  /// Cancelled Call
  case chatListServiceCallCancelled
  /// Disconnected
  case chatListServiceCallDisconnected
  /// Incoming Call (%@)
  case chatListServiceCallIncoming(String)
  /// Missed Call
  case chatListServiceCallMissed
  /// Outgoing Call (%@)
  case chatListServiceCallOutgoing(String)
  /// channel created
  case chatServiceChannelCreated
  /// Create
  case composeCreate
  /// Next
  case composeNext
  /// Select users
  case composeSelectUsers
  /// Create secret chat with "%@"
  case composeConfirmStartSecretChat(String)
  /// New Channel
  case composePopoverNewChannel
  /// New Group
  case composePopoverNewGroup
  /// New Secret Chat
  case composePopoverNewSecretChat
  /// Secret Chat
  case composeSelectSecretChat
  /// Whom would you like to message?
  case composeSelectGroupUsersPlaceholder
  /// Add the bot to "%@"?
  case confirmAddBotToGroup(String)
  /// Wait! Deleting this channel will remove all members and all messages will be lost. Delete the channel anyway?
  case confirmDeleteAdminedChannel
  /// Are you sure you want to delete all message history?\n\nThis action cannot be undone.
  case confirmDeleteChatUser
  /// Are you sure you want to leave this group?
  case confirmLeaveGroup
  /// connecting
  case connectingStatusConnecting
  /// connecting to proxy
  case connectingStatusConnectingToProxy
  /// click here to disable proxy
  case connectingStatusDisableProxy
  /// online
  case connectingStatusOnline
  /// updating
  case connectingStatusUpdating
  /// waiting for network
  case connectingStatusWaitingNetwork
  /// Add Contact
  case contactsAddContact
  /// Contacts
  case contactsContacsSeparator
  /// This contact is not registered in Telegram yet. You will be able to send them a Telegram message as soon as they sign up.
  case contactsNotRegistredDescription
  /// Not Telegram Contact
  case contactsNotRegistredTitle
  /// First Name
  case contactsFirstNamePlaceholder
  /// Last Name
  case contactsLastNamePlaceholder
  /// Phone Number
  case contactsPhoneNumberPlaceholder
  /// Save as...
  case contextCopyMedia
  /// Remove
  case contextRecentGifRemove
  /// Remove
  case contextRemoveFaveSticker
  /// Show In Finder
  case contextShowInFinder
  /// View Sticker Set
  case contextViewStickerSet
  /// Are you sure? This action cannot be undone.
  case convertToSuperGroupConfirm
  /// Something is wrong, please try again later.
  case convertToSupergroupAlertError
  /// Group Name
  case createGroupNameHolder
  /// Smart Links
  case cwLP1JidTitle
  /// Make Lower Case
  case d9MCDAMdTitle
  /// Network Usage
  case dataAndStorageNetworkUsage
  /// Storage Usage
  case dataAndStorageStorageUsage
  /// AUTOMATIC AUDIO DOWNLOAD
  case dataAndStorageAutomaticAudioDownloadHeader
  /// Groups and Channels
  case dataAndStorageAutomaticDownloadGroupsChannels
  /// AUTOMATIC PHOTO DOWNLOAD
  case dataAndStorageAutomaticPhotoDownloadHeader
  /// AUTOMATIC VIDEO DOWNLOAD
  case dataAndStorageAutomaticVideoDownloadHeader
  /// Today
  case dateToday
  /// Undo
  case drj4nYzgTitle
  /// Spelling and Grammar
  case dv1IoYv7Title
  /// Activity & Sport
  case emojiActivityAndSport
  /// Animals & Nature
  case emojiAnimalsAndNature
  /// Flags
  case emojiFlags
  /// Food & Drink
  case emojiFoodAndDrink
  /// Objects
  case emojiObjects
  /// Frequently Used
  case emojiRecent
  /// Smileys & People
  case emojiSmilesAndPeople
  /// Symbols
  case emojiSymbols
  /// Travel & Places
  case emojiTravelAndPlaces
  /// Select a chat to start messaging
  case emptyPeerDescription
  /// This image and text were derived from the encryption key for this secret chat with **%@**.\n\nIf they look the same on **%@**'s device, end-to-end encryption is guaranteed.
  case encryptionKeyDescription(String, String)
  /// EMOJI
  case entertainmentEmoji
  /// GIFs
  case entertainmentGIF
  /// STICKERS
  case entertainmentStickers
  /// Emoji
  case entertainmentSwitchEmoji
  /// Stickers & GIFs
  case entertainmentSwitchGifAndStickers
  /// This username is already taken.
  case errorUsernameAlreadyTaken
  /// This username is invalid.
  case errorUsernameInvalid
  /// A username must have at least 5 characters.
  case errorUsernameMinimumLength
  /// A username can't start with a number.
  case errorUsernameNumberStart
  /// A username can't end with an underscore.
  case errorUsernameUnderscopeEnd
  /// A username can't start with an underscore.
  case errorUsernameUnderscopeStart
  /// Banned %@ %@
  case eventLogServiceBanned(String, String)
  /// %@ changed group sticker set
  case eventLogServiceChangedStickerSet(String)
  /// %@ deleted message:
  case eventLogServiceDeletedMessage(String)
  /// restricted %@ %@ indefinitely
  case eventLogServiceDemoted(String, String)
  /// %@ edited message:
  case eventLogServiceEditedMessage(String)
  /// Previous Description
  case eventLogServicePreviousDesc
  /// Previous Link
  case eventLogServicePreviousLink
  /// Previous Title
  case eventLogServicePreviousTitle
  /// promoted %@ %@:
  case eventLogServicePromoted(String, String)
  /// %@ removed group sticker set
  case eventLogServiceRemovedStickerSet(String)
  /// %@ unpinned message
  case eventLogServiceRemovePinned(String)
  /// %@ pinned message:
  case eventLogServiceUpdatePinned(String)
  /// Embed Links
  case eventLogServiceDemoteEmbedLinks
  /// Send Inline
  case eventLogServiceDemoteSendInline
  /// Send Media
  case eventLogServiceDemoteSendMedia
  /// Send Messages
  case eventLogServiceDemoteSendMessages
  /// Send Stickers
  case eventLogServiceDemoteSendStickers
  /// changed restrictions for %@ %@ indefinitely
  case eventLogServiceDemotedChanged(String, String)
  /// restricted %@ %@ until %@
  case eventLogServiceDemotedUntil(String, String, String)
  /// changed restrictions for %@ %@ until %@
  case eventLogServiceDemotedChangedUntil(String, String, String)
  /// Add New Admins
  case eventLogServicePromoteAddNewAdmins
  /// Add Users
  case eventLogServicePromoteAddUsers
  /// Ban Users
  case eventLogServicePromoteBanUsers
  /// Change Info
  case eventLogServicePromoteChangeInfo
  /// Delete Messages
  case eventLogServicePromoteDeleteMessages
  /// Edit Messages
  case eventLogServicePromoteEditMessages
  /// Invite Users Via Link
  case eventLogServicePromoteInviteViaLink
  /// Pin Messages
  case eventLogServicePromotePinMessages
  /// Post Messages
  case eventLogServicePromotePostMessages
  /// changed privileges for %@ %@:
  case eventLogServicePromotedChanged(String, String)
  /// Disable Dark Mode
  case fastSettingsDisableDarkMode
  /// Enable Dark Mode
  case fastSettingsEnableDarkMode
  /// Lock Telegram
  case fastSettingsLockTelegram
  /// Mute For 2 Hours
  case fastSettingsMute2Hours
  /// Set a Passcode
  case fastSettingsSetPasscode
  /// Unmute
  case fastSettingsUnmute
  /// Substitutions
  case feMD8WVrTitle
  /// %d %@
  case forwardModalActionDescriptionCountable(Int, String)
  /// Select a user or chat to forward messages from %@
  case forwardModalActionDescriptionFew(String)
  /// Select a user or chat to forward messages from %@
  case forwardModalActionDescriptionMany(String)
  /// Select a user or chat to forward message from %@
  case forwardModalActionDescriptionOne(String)
  /// Select a user or chat to forward messages from %@
  case forwardModalActionDescriptionOther(String)
  /// Select a user or chat to forward messages from %@
  case forwardModalActionDescriptionTwo(String)
  /// Select a user or chat to forward messages from %@
  case forwardModalActionDescriptionZero(String)
  /// %d
  case forwardModalActionTitleCountable(Int)
  /// Forwarding messages
  case forwardModalActionTitleFew
  /// Forwarding messages
  case forwardModalActionTitleMany
  /// Forwarding message
  case forwardModalActionTitleOne
  /// Forwarding messages
  case forwardModalActionTitleOther
  /// Forwarding messages
  case forwardModalActionTitleTwo
  /// Forwarding messages
  case forwardModalActionTitleZero
  /// Delete
  case galleryContextDeletePhoto
  /// %d of %d
  case galleryCounter(Int, Int)
  /// Copy to Clipboard
  case galleryContextCopyToClipboard
  /// Save As...
  case galleryContextSaveAs
  /// Show Message
  case galleryContextShowMessage
  /// APPEARANCE SETTINGS
  case generalSettingsAppearanceSettings
  /// Dark Mode
  case generalSettingsDarkMode
  /// Automatic replace emojis
  case generalSettingsEmojiReplacements
  /// Sidebar
  case generalSettingsEnableSidebar
  /// GENERAL SETTINGS
  case generalSettingsGeneralSettings
  /// In-App Sounds
  case generalSettingsInAppSounds
  /// INPUT SETTINGS
  case generalSettingsInputSettings
  /// Large Message Font
  case generalSettingsLargeFonts
  /// Handle media keys for in-app player
  case generalSettingsMediaKeysForInAppPlayer
  /// Use ⌘ + Enter to send
  case generalSettingsSendByCmdEnter
  /// Use Enter to send
  case generalSettingsSendByEnter
  /// A color scheme for nighttime and dark desktops
  case generalSettingsDarkModeDescription
  /// Use large font for messages
  case generalSettingsFontDescription
  /// New Group
  case groupCreateGroup
  /// New Group
  case groupNewGroup
  /// Sorry, this group does not seem to exist.
  case groupUnavailable
  /// Change Group Info
  case groupEditAdminPermissionChangeInfo
  /// **No events here yet**\n\nThere were no service actions taken by the group's members and admins for the last 48 hours.
  case groupEventLogEmptyText
  /// %@ removed group description:
  case groupEventLogServiceAboutRemoved(String)
  /// %@ edited group description:
  case groupEventLogServiceAboutUpdated(String)
  /// %@ disabled group invites
  case groupEventLogServiceDisableInvites(String)
  /// %@ enabled group invites
  case groupEventLogServiceEnableInvites(String)
  /// %@ removed group link:
  case groupEventLogServiceLinkRemoved(String)
  /// %@ edited group link:
  case groupEventLogServiceLinkUpdated(String)
  /// %@ removed group photo
  case groupEventLogServicePhotoRemoved(String)
  /// %@ updated group photo
  case groupEventLogServicePhotoUpdated(String)
  /// %@ edited group title:
  case groupEventLogServiceTitleUpdated(String)
  /// %@ joined the group
  case groupEventLogServiceUpdateJoin(String)
  /// %@ left the group
  case groupEventLogServiceUpdateLeft(String)
  /// All Members Are Admins
  case groupAdminsAllMembersAdmins
  /// Only admins can add and remove members, edit name and photo of this group.
  case groupAdminsDescAdminInvites
  /// Group members can add new members, edit name and photo of this group.
  case groupAdminsDescAllInvites
  /// Anyone who has Telegram installed will be able to join your channel by following this link
  case groupInvationChannelDescription
  /// Copy Link
  case groupInvationCopyLink
  /// Anyone who has Telegram installed will be able to join your group by following this link
  case groupInvationGroupDescription
  /// Revoke
  case groupInvationRevoke
  /// Share Link
  case groupInvationShare
  /// No groups in common
  case groupsInCommonEmpty
  /// CHOOSE FROM YOUR STICKERS
  case groupStickersChooseHeader
  /// You can create your own custom sticker set using @stickers bot.
  case groupStickersCreateDescription
  /// Try again or choose from list below
  case groupStickersEmptyDesc
  /// No such sticker set found
  case groupStickersEmptyHeader
  /// Paste
  case gvau4SdLTitle
  /// View
  case h8h7bM4vTitle
  /// Show Spelling and Grammar
  case hFoCyZxITitle
  /// Text Replacement
  case hfqgknfaTitle
  /// Smart Quotes
  case hQb2vFYvTitle
  /// View
  case hyVFhRgOTitle
  /// Check Document Now
  case hz2CUCR7Title
  /// open %@?
  case inAppLinksConfirmOpenExternal(String)
  /// Select a user or chat to share content via %@
  case inlineModalActionDesc(String)
  /// Share bot content
  case inlineModalActionTitle
  /// File
  case inputAttachPopoverFile
  /// Photo Or Video
  case inputAttachPopoverPhotoOrVideo
  /// Camera
  case inputAttachPopoverPicture
  /// Archived Stickers
  case installedStickersArchived
  /// Artists are welcome to add their own sticker sets using our @stickers bot.\n\nTap on a sticker to view and add the whole set.
  case installedStickersDescrpiption
  /// STICKER SETS
  case installedStickersPacksTitle
  /// Trending Stickers
  case installedStickersTranding
  /// Delete
  case installedStickersRemoveDelete
  /// Stickers will be archived, you can quickly restore it later from the Archived Stickers section.
  case installedStickersRemoveDescription
  /// By %1$@ • %2$@
  case instantPageAuthorAndDateTitle(String, String)
  /// Join
  case ivChannelJoin
  /// Join
  case joinLinkJoin
  /// Show All
  case kd2MpPUSTitle
  /// Bring All to Front
  case le2AR0XJTitle
  /// Welcome to the new super-fast and stable Telegram for macOS, fully rewritten in Swift 3.0.
  case legacyIntroDescription1
  /// Please note that your existing secret chats will be available in read-only mode. You can of course create new ones to continue chatting.
  case legacyIntroDescription2
  /// Start Messaging
  case legacyIntroNext
  /// Are you sure you want to revoke this link? Once you do, no one will be able to join the channel using it.
  case linkInvationChannelConfirmRevoke
  /// Revoke
  case linkInvationConfirmOk
  /// Are you sure you want to revoke this link? Once you do, no one will be able to join the group using it.
  case linkInvationGroupConfirmRevoke
  /// code
  case loginCodePlaceholder
  /// Continue on English
  case loginContinueOnLanguage
  /// country
  case loginCountryLabel
  /// Please enter the code you've just received in Telegram on your other device.
  case loginEnterCodeFromApp
  /// You have enabled Two-Step Verification, your account is now protected with an additional password.
  case loginEnterPasswordDescription
  /// too many attempts, please try later.
  case loginFloodWait
  /// Invalid Country Code
  case loginInvalidCountryCode
  /// We have sent you a code via SMS. Please enter it above.
  case loginJustSentSms
  /// Next
  case loginNext
  /// password
  case loginPasswordPlaceholder
  /// We’ve just called your number. Please enter the code above.
  case loginPhoneCalledCode
  /// Telegram dialed your number
  case loginPhoneDialed
  /// phone number
  case loginPhoneFieldPlaceholder
  /// Phone number not registered. If you don't have a Telegram account yet, please sign up with your mobile device.
  case loginPhoneNumberNotRegistred
  /// Since you haven't provided a recovery e-mail during the setup of your password, your remaining options are either to remember your password or to reset your account.
  case loginRecoveryMailFailed
  /// RESET MY ACCOUNT
  case loginResetAccount
  /// All your chats and messages, along with any media and files you shared will be lost if you proceed with resetting your account.
  case loginResetAccountDescription
  /// Haven't received the code?
  case loginSendSmsIfNotReceivedAppCode
  /// Welcome to the macOS application
  case loginWelcomeDescription
  /// Telegram will call you in %d:%@
  case loginWillCall(Int, String)
  /// Telegram will send you an SMS in %d:%@
  case loginWillSendSms(Int, String)
  /// your code
  case loginYourCodeLabel
  /// your password
  case loginYourPasswordLabel
  /// your phone
  case loginYourPhoneLabel
  /// Enter Code
  case loginHeaderCode
  /// Enter Password
  case loginHeaderPassword
  /// Sign Up
  case loginHeaderSignUp
  /// %d
  case messageAccessoryPanelForwardedCountable(Int)
  /// %d forwarded messages
  case messageAccessoryPanelForwardedFew(Int)
  /// %d forwarded messages
  case messageAccessoryPanelForwardedMany(Int)
  /// %d forwarded message
  case messageAccessoryPanelForwardedOne(Int)
  /// %d forwarded messages
  case messageAccessoryPanelForwardedOther(Int)
  /// %d forwarded messages
  case messageAccessoryPanelForwardedTwo(Int)
  /// %d forwarded messages
  case messageAccessoryPanelForwardedZero(Int)
  /// Delete
  case messageActionsPanelDelete
  /// Select messages
  case messageActionsPanelEmptySelected
  /// Forward
  case messageActionsPanelForward
  /// %d
  case messageActionsPanelSelectedCountCountable(Int)
  /// %d messages selected
  case messageActionsPanelSelectedCountFew(Int)
  /// %d messages selected
  case messageActionsPanelSelectedCountMany(Int)
  /// %d message selected
  case messageActionsPanelSelectedCountOne(Int)
  /// %d messages selected
  case messageActionsPanelSelectedCountOther(Int)
  /// %d messages selected
  case messageActionsPanelSelectedCountTwo(Int)
  /// %d messages selected
  case messageActionsPanelSelectedCountZero(Int)
  /// Delete
  case messageContextDelete
  /// Edit
  case messageContextEdit
  /// Forward
  case messageContextForward
  /// Save to Cloud Storage
  case messageContextForwardToCloud
  /// Show Message
  case messageContextGoto
  /// Pin
  case messageContextPin
  /// Reply (double click)
  case messageContextReply
  /// Add GIF
  case messageContextSaveGif
  /// Select
  case messageContextSelect
  /// Pin only
  case messageContextConfirmOnlyPin
  /// Pin this message and notify all members of the group?
  case messageContextConfirmPin
  /// Copy Link
  case messageContextCopyMessageLink
  /// Deleted message
  case messagesDeletedMessage
  /// Forwarded messages
  case messagesForwardHeader
  /// Unread messages
  case messagesUnreadMark
  /// %d% downloaded
  case messagesFileStateFetchingIn1(Int)
  /// %d% uploaded
  case messagesFileStateFetchingOut1(Int)
  /// Show in Finder
  case messagesFileStateLocal
  /// Download
  case messagesFileStateRemote
  /// Write a message...
  case messagesPlaceholderSentMessage
  /// Reply
  case messagesReplyLoadingHeader
  /// Loading...
  case messagesReplyLoadingLoading
  /// Check Grammar With Spelling
  case mk62p4JGTitle
  /// Cancel
  case modalCancel
  /// Copy Link
  case modalCopyLink
  /// OK
  case modalOK
  /// Send
  case modalSend
  /// Share
  case modalShare
  /// Back
  case navigationBack
  /// Cancel
  case navigationCancel
  /// Close
  case navigationClose
  /// Done
  case navigationDone
  /// Edit
  case navigationEdit
  /// You have new message
  case notificationLockedPreview
  /// Message Preview
  case notificationSettingsMessagesPreview
  /// Notification Tone
  case notificationSettingsNotificationTone
  /// Reset Notifications
  case notificationSettingsResetNotifications
  /// You can set custom notifications for specific chats below.
  case notificationSettingsResetNotificationsText
  /// Notifications
  case notificationSettingsToggleNotifications
  /// Reset notifications
  case notificationSettingsConfirmReset
  /// Default
  case notificationSettingsToneDefault
  /// Hide
  case olwNPBQNTitle
  /// Minimize
  case oy7WFPoVTitle
  /// Delete
  case pa3QIU2kTitle
  /// Auto-Lock
  case passcodeAutolock
  /// Change passcode
  case passcodeChange
  /// Enter Current Passcode
  case passcodeEnterCurrentPlaceholder
  /// Enter New Passcode
  case passcodeEnterNewPlaceholder
  /// Enter a passcode
  case passcodeEnterPasscodePlaceholder
  /// If you don't remember your passcode, you can
  case passcodeLogoutDescription
  /// logout
  case passcodeLogoutLinkText
  /// Next
  case passcodeNext
  /// Re-enter a passcode
  case passcodeReEnterPlaceholder
  /// Turn Passcode Off
  case passcodeTurnOff
  /// Turn Passcode On
  case passcodeTurnOn
  /// When you set up an additional passcode, you can use ⌘ + L for lock.\n\nNote: if you forget the passcode, you'll need to delete and reinstall the app. All secret chats will be lost.
  case passcodeTurnOnDescription
  /// Disabled
  case passcodeAutoLockDisabled
  /// If away for %@
  case passcodeAutoLockIfAway(String)
  /// Sorry, Telegram Mac doesn't support payments yet. Please use one of our mobile apps to do this.
  case paymentsUnsupported
  /// Deleted User
  case peerDeletedUser
  /// Service Notifications
  case peerServiceNotifications
  /// %d are recording voice
  case peerActivityChatMultiRecordingAudio(Int)
  /// %d are recording video
  case peerActivityChatMultiRecordingVideo(Int)
  /// %d are sending audio
  case peerActivityChatMultiSendingAudio(Int)
  /// %d are sending file
  case peerActivityChatMultiSendingFile(Int)
  /// %d are sending photo
  case peerActivityChatMultiSendingPhoto(Int)
  /// %d are sending video
  case peerActivityChatMultiSendingVideo(Int)
  /// %d are typing
  case peerActivityChatMultiTypingText(Int)
  /// recording voice
  case peerActivityUserRecordingAudio
  /// recording video
  case peerActivityUserRecordingVideo
  /// sending file
  case peerActivityUserSendingFile
  /// sending photo
  case peerActivityUserSendingPhoto
  /// sending video
  case peerActivityUserSendingVideo
  /// typing
  case peerActivityUserTypingText
  /// You can send and receive files of any type up to 1.5 GB each and access them anywhere.
  case peerMediaSharedFilesEmptyList
  /// All links shared in this chat will appear here.
  case peerMediaSharedLinksEmptyList
  /// Share photos and videos in this chat - or this paperclip stays unhappy.
  case peerMediaSharedMediaEmptyList
  /// All music shared in this chat will appear here.
  case peerMediaSharedMusicEmptyList
  /// channel
  case peerStatusChannel
  /// group
  case peerStatusGroup
  /// last seen just now
  case peerStatusJustNow
  /// last seen within a month
  case peerStatusLastMonth
  /// last seen %@ at %@
  case peerStatusLastSeenAt(String, String)
  /// last seen within a week
  case peerStatusLastWeek
  /// %d
  case peerStatusMemberCountable(Int)
  /// %d members
  case peerStatusMemberFew(Int)
  /// %d members
  case peerStatusMemberMany(Int)
  /// %d member
  case peerStatusMemberOne(Int)
  /// %d members
  case peerStatusMemberOther(Int)
  /// %d members
  case peerStatusMemberTwo(Int)
  /// %d members
  case peerStatusMemberZero(Int)
  /// %d
  case peerStatusMinAgoCountable(Int)
  /// last seen %d minutes ago
  case peerStatusMinAgoFew(Int)
  /// last seen %d minutes ago
  case peerStatusMinAgoMany(Int)
  /// last seen %d minute ago
  case peerStatusMinAgoOne(Int)
  /// last seen %d minutes ago
  case peerStatusMinAgoOther(Int)
  /// last seen %d minutes ago
  case peerStatusMinAgoTwo(Int)
  /// last seen %d minutes ago
  case peerStatusMinAgoZero(Int)
  /// online
  case peerStatusOnline
  /// last seen recently
  case peerStatusRecently
  /// today
  case peerStatusToday
  /// yesterday
  case peerStatusYesterday
  /// %d
  case peerStatusMemberOnlineCountable(Int)
  /// %d online
  case peerStatusMemberOnlineFew(Int)
  /// %d online
  case peerStatusMemberOnlineMany(Int)
  /// %d online
  case peerStatusMemberOnlineOne(Int)
  /// %d online
  case peerStatusMemberOnlineOther(Int)
  /// %d online
  case peerStatusMemberOnlineTwo(Int)
  /// %d online
  case peerStatusMemberOnlineZero(Int)
  /// about
  case peerInfoAbout
  /// Add Contact
  case peerInfoAddContact
  /// Add member
  case peerInfoAddMember
  /// admin
  case peerInfoAdminLabel
  /// Admins
  case peerInfoAdmins
  /// bio
  case peerInfoBio
  /// Blacklist
  case peerInfoBlackList
  /// Block User
  case peerInfoBlockUser
  /// Thank You! Your report will be reviewed by our team very soon.
  case peerInfoChannelReported
  /// Channel Type
  case peerInfoChannelType
  /// Convert To Supergroup
  case peerInfoConvertToSupergroup
  /// Delete and Exit
  case peerInfoDeleteAndExit
  /// Delete Channel
  case peerInfoDeleteChannel
  /// Delete Contact
  case peerInfoDeleteContact
  /// Delete Secret Chat
  case peerInfoDeleteSecretChat
  /// Encryption Key
  case peerInfoEncryptionKey
  /// Groups In Common
  case peerInfoGroupsInCommon
  /// Group Type
  case peerInfoGroupType
  /// info
  case peerInfoInfo
  /// Invite Link
  case peerInfoInviteLink
  /// Leave Channel
  case peerInfoLeaveChannel
  /// Members
  case peerInfoMembers
  /// %d
  case peerInfoMembersHeaderCountable(Int)
  /// %d MEMBERS
  case peerInfoMembersHeaderFew(Int)
  /// %d MEMBERS
  case peerInfoMembersHeaderMany(Int)
  /// %d MEMBER
  case peerInfoMembersHeaderOne(Int)
  /// %d MEMBERS
  case peerInfoMembersHeaderOther(Int)
  /// %d MEMBERS
  case peerInfoMembersHeaderTwo(Int)
  /// %d MEMBERS
  case peerInfoMembersHeaderZero(Int)
  /// Notifications
  case peerInfoNotifications
  /// phone
  case peerInfoPhone
  /// Chat History For New Members
  case peerInfoPreHistory
  /// Report
  case peerInfoReport
  /// Send Message
  case peerInfoSendMessage
  /// You can provide an optional description for your group.
  case peerInfoSetAboutDescription
  /// Set Admins
  case peerInfoSetAdmins
  /// Set Channel Photo
  case peerInfoSetChannelPhoto
  /// Set Group Photo
  case peerInfoSetGroupPhoto
  /// Group Sticker Set
  case peerInfoSetGroupStickersSet
  /// Share Contact
  case peerInfoShareContact
  /// Shared Media
  case peerInfoSharedMedia
  /// share link
  case peerInfoSharelink
  /// Sign Messages
  case peerInfoSignMessages
  /// Start Secret Chat
  case peerInfoStartSecretChat
  /// Unblock User
  case peerInfoUnblockUser
  /// username
  case peerInfoUsername
  /// Description
  case peerInfoAboutPlaceholder
  /// has access to messages
  case peerInfoBotStatusHasAccess
  /// has no access to messages
  case peerInfoBotStatusHasNoAccess
  /// Channel Name
  case peerInfoChannelNamePlaceholder
  /// Add "%@" to group?
  case peerInfoConfirmAddMember(String)
  /// Add %d users to group?
  case peerInfoConfirmAddMembers(Int)
  /// Are you sure you want to delete all message history and leave "%@"?\n\nThis action cannot be undone.
  case peerInfoConfirmDeleteChat(String)
  /// Delete Contact?
  case peerInfoConfirmDeleteContact
  /// Are you sure you want to leave this channel?
  case peerInfoConfirmLeaveChannel
  /// Are you sure you want to leave this group?\n\nThis action cannot be undone.
  case peerInfoConfirmLeaveGroup
  /// Remove "%@" from group?
  case peerInfoConfirmRemovePeer(String)
  /// Are you sure you want to start a secret chat with "%@"?
  case peerInfoConfirmStartSecretChat(String)
  /// First Name
  case peerInfoFirstNamePlaceholder
  /// Group Name
  case peerInfoGroupNamePlaceholder
  /// Private
  case peerInfoGroupTypePrivate
  /// Public
  case peerInfoGroupTypePublic
  /// Last Name
  case peerInfoLastNamePlaceholder
  /// Hidden
  case peerInfoPreHistoryHidden
  /// Visible
  case peerInfoPreHistoryVisible
  /// Add names of the admins to the messages they post.
  case peerInfoSignMessagesDesc
  /// Shared Media
  case peerMediaSharedMedia
  /// Shared Audio
  case peerMediaPopoverSharedAudio
  /// Shared Files
  case peerMediaPopoverSharedFiles
  /// Shared Links
  case peerMediaPopoverSharedLinks
  /// Shared Media
  case peerMediaPopoverSharedMedia
  /// CHAT HISTORY FOR NEW MEMBERS
  case preHistorySettingsHeader
  /// New members won't see earlier messages.
  case preHistorySettingsDescriptionHidden
  /// New Members will see messages that were sent before they joined.
  case preHistorySettingsDescriptionVisible
  /// bot
  case presenceBot
  /// Caption...
  case previderSenderCaptionPlaceholder
  /// Send as compressed
  case previewSenderCompressFile
  /// Active Sessions
  case privacySettingsActiveSessions
  /// Blocked Users
  case privacySettingsBlockedUsers
  /// Groups
  case privacySettingsGroups
  /// Last Seen
  case privacySettingsLastSeen
  /// Passcode
  case privacySettingsPasscode
  /// PRIVACY
  case privacySettingsPrivacyHeader
  /// CONNECTION TYPE
  case privacySettingsProxyHeader
  /// SECURITY
  case privacySettingsSecurityHeader
  /// Two-Step Verification
  case privacySettingsTwoStepVerification
  /// Use Proxy
  case privacySettingsUseProxy
  /// Voice Calls
  case privacySettingsVoiceCalls
  /// Add New
  case privacySettingsPeerSelectAddNew
  /// Add Users
  case privacySettingsControllerAddUsers
  /// Always Allow
  case privacySettingsControllerAlwaysAllow
  /// Always Share
  case privacySettingsControllerAlwaysShare
  /// Always Share With
  case privacySettingsControllerAlwaysShareWith
  /// Everybody
  case privacySettingsControllerEverbody
  /// You can restrict who can add you to groups and channels with granular precision.
  case privacySettingsControllerGroupDescription
  /// WHO CAN ADD ME TO GROUP CHATS
  case privacySettingsControllerGroupHeader
  /// Last Seen
  case privacySettingsControllerHeader
  /// Important: you won't be able to see Last Seen times for people with whom you don't share your Last Seen time. Approximate last seen will be shown instead (recently, within a week, within a month).
  case privacySettingsControllerLastSeenDescription
  /// WHO CAN SEE MY TIMESTAMP
  case privacySettingsControllerLastSeenHeader
  /// My Contacts
  case privacySettingsControllerMyContacts
  /// Never Allow
  case privacySettingsControllerNeverAllow
  /// Never Share
  case privacySettingsControllerNeverShare
  /// Never Share With
  case privacySettingsControllerNeverShareWith
  /// Nobody
  case privacySettingsControllerNobody
  /// These settings will override the values above.
  case privacySettingsControllerPeerInfo
  /// You can restrict who can call you with granular precision.
  case privacySettingsControllerPhoneCallDescription
  /// WHO CAN CALL ME
  case privacySettingsControllerPhoneCallHeader
  /// %d
  case privacySettingsControllerUserCountCountable(Int)
  /// %d users
  case privacySettingsControllerUserCountFew(Int)
  /// %d users
  case privacySettingsControllerUserCountMany(Int)
  /// %d user
  case privacySettingsControllerUserCountOne(Int)
  /// %d users
  case privacySettingsControllerUserCountOther(Int)
  /// %d users
  case privacySettingsControllerUserCountTwo(Int)
  /// %d user
  case privacySettingsControllerUserCountZero(Int)
  /// Are you sure you want to disable proxy server %@?
  case proxyForceDisable(String)
  /// Are you sure you want to enable this proxy?
  case proxyForceEnableHeader
  /// You can change your proxy server later in the Settings (Privacy and Security).
  case proxyForceEnableText
  /// Server: %@
  case proxyForceEnableTextIP(String)
  /// Password: %@
  case proxyForceEnableTextPassword(String)
  /// Port: %d
  case proxyForceEnableTextPort(Int)
  /// Username: %@
  case proxyForceEnableTextUsername(String)
  /// Connection
  case proxySettingsConnectionHeader
  /// CREDENTIALS (OPTIONAL)
  case proxySettingsCredentialsHeader
  /// Disabled
  case proxySettingsDisabled
  /// If your clipboard contains socks5-link (**t.me/socks?server=127.0.0.1&port=80**) it will apply immediately
  case proxySettingsExportDescription
  /// Export link from clipboard
  case proxySettingsExportLink
  /// Password
  case proxySettingsPassword
  /// Port
  case proxySettingsPort
  /// Proxy settings not found in clipboard.
  case proxySettingsProxyNotFound
  /// Save
  case proxySettingsSave
  /// Server
  case proxySettingsServer
  /// Share this link with friends to circumvent censorship in your country
  case proxySettingsShare
  /// SOCKS5
  case proxySettingsSocks5
  /// Username
  case proxySettingsUsername
  /// Preview
  case quickLookPreview
  /// **tab** or **↑ ↓** to navigate, **⮐** to select, **esc** to dismiss
  case quickSwitcherDescription
  /// Popular
  case quickSwitcherPopular
  /// Recent
  case quickSwitcherRecently
  /// Telegram
  case qvCM9Y7gTitle
  /// Zoom
  case r4oN2Eq4Title
  /// Check Spelling While Typing
  case rbDRhWINTitle
  /// Your recent calls will appear here
  case recentCallsEmpty
  /// Revoke
  case recentSessionsRevoke
  /// Do you want to terminate this session?
  case recentSessionsConfirmRevoke
  /// Are you sure you want to terminate all other sessions?
  case recentSessionsConfirmTerminateOthers
  /// Pornography
  case reportReasonPorno
  /// Spam
  case reportReasonSpam
  /// Violence
  case reportReasonViolence
  /// Smart Dashes
  case rgMF4YcnTitle
  /// Select All
  case ruw6mB2mTitle
  /// contacts and chats
  case searchSeparatorChatsAndContacts
  /// global search
  case searchSeparatorGlobalPeers
  /// messages
  case searchSeparatorMessages
  /// People
  case searchSeparatorPopular
  /// Recent
  case searchSeparatorRecent
  /// Search
  case searchFieldSearch
  /// Off
  case secretTimerOff
  /// clear
  case separatorClear
  /// show less
  case separatorShowLess
  /// show more
  case separatorShowMore
  /// %@ sent you a self-destructing photo. Please view it on your mobile.
  case serviceMessageDesturctingPhoto(String)
  /// %@ sent you a self-destructing video. Please view it on your mobile.
  case serviceMessageDesturctingVideo(String)
  /// file has expired
  case serviceMessageExpiredFile
  /// photo has expired
  case serviceMessageExpiredPhoto
  /// video has expired
  case serviceMessageExpiredVideo
  /// %@ sent a self-destructing photo.
  case serviceMessageDesturctingPhotoYou(String)
  /// %@ sent a self-destructing video.
  case serviceMessageDesturctingVideoYou(String)
  /// ACTIVE SESSIONS
  case sessionsActiveSessionsHeader
  /// CURRENT SESSION
  case sessionsCurrentSessionHeader
  /// Logs out all devices except for this one.
  case sessionsTerminateDescription
  /// Terminate all other sessions
  case sessionsTerminateOthers
  /// Copied to Clipboard
  case shareLinkCopied
  /// Cancel
  case shareExtensionCancel
  /// Search
  case shareExtensionSearch
  /// Share
  case shareExtensionShare
  /// Next
  case shareExtensionPasscodeNext
  /// passcode
  case shareExtensionPasscodePlaceholder
  /// To share via Telegram, please open the Telegam app and log in.
  case shareExtensionUnauthorizedDescription
  /// OK
  case shareExtensionUnauthorizedOK
  /// Share to...
  case shareModalSearchPlaceholder
  /// Sidebar available in chat
  case sidebarAvalability
  /// Add %d Stickers
  case stickerPackAdd(Int)
  /// Remove %d stickers
  case stickerPackRemove(Int)
  /// GROUP STICKERS
  case stickersGroupStickers
  /// Recent
  case stickersRecent
  /// %d stickers
  case stickersSetCount(Int)
  /// Remove
  case stickerSetRemove
  /// Clear %@
  case storageClear(String)
  /// Audio
  case storageClearAudio
  /// Documents
  case storageClearDocuments
  /// Photos
  case storageClearPhotos
  /// Videos
  case storageClearVideos
  /// Calculating current cache size...
  case storageUsageCalculating
  /// CHATS
  case storageUsageChatsHeader
  /// Keep Media
  case storageUsageKeepMedia
  /// Photos, videos and other files from cloud chats that you have **not accessed** during this period will be removed from this device to save disk space.\n\nAll media will stay in the Telegram cloud and can be re-downloaded if you need it again.
  case storageUsageKeepMediaDescription
  /// Choose your language
  case suggestLocalizationHeader
  /// Other
  case suggestLocalizationOther
  /// Convert to Supergroup
  case supergroupConvertButton
  /// **In supergroups:**\n\n• New members can see the full message history\n• Deleted messages will disappear for all members\n• Admins can pin important messages\n• Creator can set a public link for the group
  case supergroupConvertDescription
  /// **Note**: This action cannot be undone.
  case supergroupConvertUndone
  /// Ban User
  case supergroupDeleteRestrictionBanUser
  /// Delete All Messages
  case supergroupDeleteRestrictionDeleteAllMessages
  /// Delete Message
  case supergroupDeleteRestrictionDeleteMessage
  /// Report Spam
  case supergroupDeleteRestrictionReportSpam
  /// Quick Search
  case sZhCtGQSTitle
  /// Window
  case td7AD5loTitle
  /// Appearance
  case telegramAppearanceViewController
  /// Archived Stickers
  case telegramArchivedStickerPacksController
  /// Bio
  case telegramBioViewController
  /// Blocked Users
  case telegramBlockedPeersViewController
  /// Admins
  case telegramChannelAdminsViewController
  /// Blacklist
  case telegramChannelBlacklistViewController
  /// All Actions
  case telegramChannelEventLogController
  /// Channel
  case telegramChannelIntroViewController
  /// Channel Members
  case telegramChannelMembersViewController
  /// Group
  case telegramChannelVisibilityController
  /// Supergroup
  case telegramConvertGroupViewController
  /// 
  case telegramEmptyChatViewController
  /// Trending Stickers
  case telegramFeaturedStickerPacksController
  /// General Settings
  case telegramGeneralSettingsViewController
  /// Admins
  case telegramGroupAdminsController
  /// Groups In Common
  case telegramGroupsInCommonViewController
  /// Group Sticker Set
  case telegramGroupStickerSetController
  /// Stickers
  case telegramInstalledStickerPacksController
  /// Language
  case telegramLanguageViewController
  /// Settings
  case telegramLayoutAccountController
  /// Recent Calls
  case telegramLayoutRecentCallsViewController
  /// Invite Link
  case telegramLinkInvationController
  /// 
  case telegramMainViewController
  /// Notifications
  case telegramNotificationSettingsViewController
  /// Passcode
  case telegramPasscodeSettingsViewController
  /// Info
  case telegramPeerInfoController
  /// Chat History Settings
  case telegramPreHistorySettingsController
  /// Privacy and Security
  case telegramPrivacyAndSecurityViewController
  /// Proxy
  case telegramProxySettingsViewController
  /// Active Sessions
  case telegramRecentSessionsController
  /// Encryption Key
  case telegramSecretChatKeyViewController
  /// Select Users
  case telegramSelectPeersController
  /// Storage Usage
  case telegramStorageUsageController
  /// Username
  case telegramUsernameSettingsViewController
  /// Copy
  case textCopy
  /// Make Bold
  case textViewTransformBold
  /// Make Monospace
  case textViewTransformCode
  /// Make Italic
  case textViewTransformItalic
  /// at
  case timeAt
  /// last seen
  case timeLastSeen
  /// today
  case timeToday
  /// yesterday
  case timeYesterday
  /// %d
  case timerDaysCountable(Int)
  /// %d days
  case timerDaysFew(Int)
  /// %d days
  case timerDaysMany(Int)
  /// %d day
  case timerDaysOne(Int)
  /// %d days
  case timerDaysOther(Int)
  /// %d days
  case timerDaysTwo(Int)
  /// %d days
  case timerDaysZero(Int)
  /// Forever
  case timerForever
  /// %d
  case timerHoursCountable(Int)
  /// %d hours
  case timerHoursFew(Int)
  /// %d hours
  case timerHoursMany(Int)
  /// %d hour
  case timerHoursOne(Int)
  /// %d hours
  case timerHoursOther(Int)
  /// %d hours
  case timerHoursTwo(Int)
  /// %d hours
  case timerHoursZero(Int)
  /// %d
  case timerMinutesCountable(Int)
  /// %d minutes
  case timerMinutesFew(Int)
  /// %d minutes
  case timerMinutesMany(Int)
  /// %d minute
  case timerMinutesOne(Int)
  /// %d minutes
  case timerMinutesOther(Int)
  /// %d minutes
  case timerMinutesTwo(Int)
  /// %d minutes
  case timerMinutesZero(Int)
  /// %d
  case timerMonthsCountable(Int)
  /// %d months
  case timerMonthsFew(Int)
  /// %d months
  case timerMonthsMany(Int)
  /// %d month
  case timerMonthsOne(Int)
  /// %d months
  case timerMonthsOther(Int)
  /// %d months
  case timerMonthsTwo(Int)
  /// %d months
  case timerMonthsZero(Int)
  /// %d
  case timerSecondsCountable(Int)
  /// %d seconds
  case timerSecondsFew(Int)
  /// %d seconds
  case timerSecondsMany(Int)
  /// %d second
  case timerSecondsOne(Int)
  /// %d seconds
  case timerSecondsOther(Int)
  /// %d seconds
  case timerSecondsTwo(Int)
  /// %d seconds
  case timerSecondsZero(Int)
  /// %d
  case timerWeeksCountable(Int)
  /// %d weeks
  case timerWeeksFew(Int)
  /// %d weeks
  case timerWeeksMany(Int)
  /// %d week
  case timerWeeksOne(Int)
  /// %d weeks
  case timerWeeksOther(Int)
  /// %d weeks
  case timerWeeksTwo(Int)
  /// %d weeks
  case timerWeeksZero(Int)
  /// %d
  case timerYearsCountable(Int)
  /// %d years
  case timerYearsFew(Int)
  /// %d years
  case timerYearsMany(Int)
  /// %d year
  case timerYearsOne(Int)
  /// %d years
  case timerYearsOther(Int)
  /// %d years
  case timerYearsTwo(Int)
  /// %d years
  case timerYearsZero(Int)
  /// Data Detectors
  case tRrPd1PSTitle
  /// Capitalize
  case uezBsLqGTitle
  /// Telegram
  case uQyDDJDrTitle
  /// Cut
  case uRlIYUnGTitle
  /// %@ is available
  case usernameSettingsAvailable(String)
  /// You can choose a username on Telegram. If you do, other people will be able to find you by this username and contact you without knowing your phone number.\n\n\nYou can use a-z, 0-9 and underscores. Minimum length is 5 characters.
  case usernameSettingsChangeDescription
  /// Done
  case usernameSettingsDone
  /// Enter your username
  case usernameSettingsInputPlaceholder
  /// Hide Others
  case vdrFpXzOTitle
  /// Make Upper Case
  case vmV6d7jITitle
  /// Edit
  case w486f4DlTitle
  /// Fri
  case weekdayShortFriday
  /// Mon
  case weekdayShortMonday
  /// Sat
  case weekdayShortSaturday
  /// Sun
  case weekdayShortSunday
  /// Thu
  case weekdayShortThursday
  /// Tue
  case weekdayShortTuesday
  /// Wed
  case weekdayShortWednesday
  /// Paste and Match Style
  case weT3VZwkTitle
  /// Copy
  case x3vGGIWUTitle
  /// Show Substitutions
  case z6FFW3nzTitle
  /// Window
  case _NS138Title
  /// View
  case _NS70Title
  /// Edit
  case _NS88Title
}
// swiftlint:enable type_body_length

extension L10n: CustomStringConvertible {
  var description: String { return self.string }

  var string: String {
    switch self {
      case .defaultSoundName:
        return L10n.tr(key: "DefaultSoundName")
      case .notificationSettingsToneNone:
        return L10n.tr(key: "NotificationSettingsToneNone")
      case .passwordHashInvalid:
        return L10n.tr(key: "PASSWORD_HASH_INVALID")
      case .phoneCodeExpired:
        return L10n.tr(key: "PHONE_CODE_EXPIRED")
      case .phoneCodeInvalid:
        return L10n.tr(key: "PHONE_CODE_INVALID")
      case .phoneNumberInvalid:
        return L10n.tr(key: "PHONE_NUMBER_INVALID")
      case .you:
        return L10n.tr(key: "You")
      case ._1000Title:
        return L10n.tr(key: "1000.title")
      case ._1XtHYUBwTitle:
        return L10n.tr(key: "1Xt-HY-uBw.title")
      case ._2oIRnZJCTitle:
        return L10n.tr(key: "2oI-Rn-ZJC.title")
      case ._4J7DPTxaTitle:
        return L10n.tr(key: "4J7-dP-txa.title")
      case ._4sb4sVLiTitle:
        return L10n.tr(key: "4sb-4s-VLi.title")
      case ._5kVVbQxSTitle:
        return L10n.tr(key: "5kV-Vb-QxS.title")
      case ._5QFOaP0TTitle:
        return L10n.tr(key: "5QF-Oa-p0T.title")
      case ._6dhZSVamTitle:
        return L10n.tr(key: "6dh-zS-Vam.title")
      case ._78YHA62vTitle:
        return L10n.tr(key: "78Y-hA-62v.title")
      case ._9icFLObxTitle:
        return L10n.tr(key: "9ic-FL-obx.title")
      case ._9yt4BNSMTitle:
        return L10n.tr(key: "9yt-4B-nSM.title")
      case .aboutDescription:
        return L10n.tr(key: "About.Description")
      case .accountConfirmAskQuestion:
        return L10n.tr(key: "Account.Confirm.AskQuestion")
      case .accountConfirmGoToFaq:
        return L10n.tr(key: "Account.Confirm.GoToFaq")
      case .accountConfirmLogout:
        return L10n.tr(key: "Account.Confirm.Logout")
      case .accountConfirmLogoutText:
        return L10n.tr(key: "Account.Confirm.LogoutText")
      case .accountsControllerNewAccount:
        return L10n.tr(key: "AccountsController.NewAccount")
      case .accountSettingsAbout:
        return L10n.tr(key: "AccountSettings.About")
      case .accountSettingsAppearance:
        return L10n.tr(key: "AccountSettings.Appearance")
      case .accountSettingsAskQuestion:
        return L10n.tr(key: "AccountSettings.AskQuestion")
      case .accountSettingsBio:
        return L10n.tr(key: "AccountSettings.Bio")
      case .accountSettingsCurrentLanguage:
        return L10n.tr(key: "AccountSettings.CurrentLanguage")
      case .accountSettingsFAQ:
        return L10n.tr(key: "AccountSettings.FAQ")
      case .accountSettingsGeneral:
        return L10n.tr(key: "AccountSettings.General")
      case .accountSettingsLanguage:
        return L10n.tr(key: "AccountSettings.Language")
      case .accountSettingsLogout:
        return L10n.tr(key: "AccountSettings.Logout")
      case .accountSettingsNotifications:
        return L10n.tr(key: "AccountSettings.Notifications")
      case .accountSettingsPrivacyAndSecurity:
        return L10n.tr(key: "AccountSettings.PrivacyAndSecurity")
      case .accountSettingsSetBio:
        return L10n.tr(key: "AccountSettings.SetBio")
      case .accountSettingsSetProfilePhoto:
        return L10n.tr(key: "AccountSettings.SetProfilePhoto")
      case .accountSettingsSetUsername:
        return L10n.tr(key: "AccountSettings.SetUsername")
      case .accountSettingsStickers:
        return L10n.tr(key: "AccountSettings.Stickers")
      case .accountSettingsStorage:
        return L10n.tr(key: "AccountSettings.Storage")
      case .accountSettingsUsername:
        return L10n.tr(key: "AccountSettings.Username")
      case .adminsAddAdmin:
        return L10n.tr(key: "Admins.AddAdmin")
      case .adminsAdmin:
        return L10n.tr(key: "Admins.Admin")
      case .adminsChannelAdmins:
        return L10n.tr(key: "Admins.ChannelAdmins")
      case .adminsChannelDescription:
        return L10n.tr(key: "Admins.ChannelDescription")
      case .adminsCreator:
        return L10n.tr(key: "Admins.Creator")
      case .adminsEverbodyCanAddMembers:
        return L10n.tr(key: "Admins.EverbodyCanAddMembers")
      case .adminsGroupAdmins:
        return L10n.tr(key: "Admins.GroupAdmins")
      case .adminsGroupDescription:
        return L10n.tr(key: "Admins.GroupDescription")
      case .adminsOnlyAdminsCanAddMembers:
        return L10n.tr(key: "Admins.OnlyAdminsCanAddMembers")
      case .adminsSelectNewAdminTitle:
        return L10n.tr(key: "Admins.SelectNewAdminTitle")
      case .adminsWhoCanInviteAdmins:
        return L10n.tr(key: "Admins.WhoCanInvite.Admins")
      case .adminsWhoCanInviteEveryone:
        return L10n.tr(key: "Admins.WhoCanInvite.Everyone")
      case .adminsWhoCanInviteText:
        return L10n.tr(key: "Admins.WhoCanInvite.Text")
      case .alertCancel:
        return L10n.tr(key: "Alert.Cancel")
      case .alertOK:
        return L10n.tr(key: "Alert.OK")
      case .alertUserDoesntExists:
        return L10n.tr(key: "Alert.UserDoesntExists")
      case .alertForwardError:
        return L10n.tr(key: "Alert.Forward.Error")
      case .alertSendErrorDelete:
        return L10n.tr(key: "Alert.SendError.Delete")
      case .alertSendErrorHeader:
        return L10n.tr(key: "Alert.SendError.Header")
      case .alertSendErrorIgnore:
        return L10n.tr(key: "Alert.SendError.Ignore")
      case .alertSendErrorResend:
        return L10n.tr(key: "Alert.SendError.Resend")
      case .alertSendErrorText:
        return L10n.tr(key: "Alert.SendError.Text")
      case .appMaxFileSize:
        return L10n.tr(key: "App.MaxFileSize")
      case .archivedStickersDescription:
        return L10n.tr(key: "ArchivedStickers.Description")
      case .audioUnknownArtist:
        return L10n.tr(key: "Audio.UnknownArtist")
      case .audioUntitledSong:
        return L10n.tr(key: "Audio.UntitledSong")
      case .audioControllerVideoMessage:
        return L10n.tr(key: "AudioController.videoMessage")
      case .audioControllerVoiceMessage:
        return L10n.tr(key: "AudioController.voiceMessage")
      case .audioRecordReleaseOut:
        return L10n.tr(key: "AudioRecord.ReleaseOut")
      case .aufd15bRTitle:
        return L10n.tr(key: "aUF-d1-5bR.title")
      case .bioDescription:
        return L10n.tr(key: "Bio.Description")
      case .bioPlaceholder:
        return L10n.tr(key: "Bio.Placeholder")
      case .bioSave:
        return L10n.tr(key: "Bio.Save")
      case .blockedPeersEmptyDescrpition:
        return L10n.tr(key: "BlockedPeers.EmptyDescrpition")
      case .bofnm1cWTitle:
        return L10n.tr(key: "BOF-NM-1cW.title")
      case .c8aY6VQdTitle:
        return L10n.tr(key: "c8a-y6-VQd.title")
      case .cagYXWT6Title:
        return L10n.tr(key: "Cag-YX-WT6.title")
      case .callParticipantVersionOutdatedError(let p1):
        return L10n.tr(key: "Call.ParticipantVersionOutdatedError", p1)
      case .callPrivacyErrorMessage(let p1):
        return L10n.tr(key: "Call.PrivacyErrorMessage", p1)
      case .callShortMinutesCountable(let p1):
        return L10n.tr(key: "Call.ShortMinutes_countable", p1)
      case .callShortMinutesFew(let p1):
        return L10n.tr(key: "Call.ShortMinutes_few", p1)
      case .callShortMinutesMany(let p1):
        return L10n.tr(key: "Call.ShortMinutes_many", p1)
      case .callShortMinutesOne(let p1):
        return L10n.tr(key: "Call.ShortMinutes_one", p1)
      case .callShortMinutesOther(let p1):
        return L10n.tr(key: "Call.ShortMinutes_other", p1)
      case .callShortMinutesTwo(let p1):
        return L10n.tr(key: "Call.ShortMinutes_two", p1)
      case .callShortMinutesZero(let p1):
        return L10n.tr(key: "Call.ShortMinutes_zero", p1)
      case .callShortSecondsCountable(let p1):
        return L10n.tr(key: "Call.ShortSeconds_countable", p1)
      case .callShortSecondsFew(let p1):
        return L10n.tr(key: "Call.ShortSeconds_few", p1)
      case .callShortSecondsMany(let p1):
        return L10n.tr(key: "Call.ShortSeconds_many", p1)
      case .callShortSecondsOne(let p1):
        return L10n.tr(key: "Call.ShortSeconds_one", p1)
      case .callShortSecondsOther(let p1):
        return L10n.tr(key: "Call.ShortSeconds_other", p1)
      case .callShortSecondsTwo(let p1):
        return L10n.tr(key: "Call.ShortSeconds_two", p1)
      case .callShortSecondsZero(let p1):
        return L10n.tr(key: "Call.ShortSeconds_zero", p1)
      case .callStatusBusy:
        return L10n.tr(key: "Call.StatusBusy")
      case .callStatusCalling:
        return L10n.tr(key: "Call.StatusCalling")
      case .callStatusConnecting:
        return L10n.tr(key: "Call.StatusConnecting")
      case .callStatusEnded:
        return L10n.tr(key: "Call.StatusEnded")
      case .callStatusFailed:
        return L10n.tr(key: "Call.StatusFailed")
      case .callStatusRequesting:
        return L10n.tr(key: "Call.StatusRequesting")
      case .callStatusRinging:
        return L10n.tr(key: "Call.StatusRinging")
      case .callUndefinedError:
        return L10n.tr(key: "Call.UndefinedError")
      case .callConfirmDiscardCurrentDescription(let p1, let p2):
        return L10n.tr(key: "Call.Confirm.DiscardCurrent.Description", p1, p2)
      case .callConfirmDiscardCurrentHeader:
        return L10n.tr(key: "Call.Confirm.DiscardCurrent.Header")
      case .callRatingModalPlaceholder:
        return L10n.tr(key: "Call.RatingModal.Placeholder")
      case .callRecentIncoming:
        return L10n.tr(key: "Call.Recent.Incoming")
      case .callRecentMissed:
        return L10n.tr(key: "Call.Recent.Missed")
      case .callRecentOutgoing:
        return L10n.tr(key: "Call.Recent.Outgoing")
      case .callHeaderEndCall:
        return L10n.tr(key: "CallHeader.EndCall")
      case .channelBanForever:
        return L10n.tr(key: "Channel.BanForever")
      case .channelChannelNameHolder:
        return L10n.tr(key: "Channel.ChannelNameHolder")
      case .channelCreate:
        return L10n.tr(key: "Channel.Create")
      case .channelDescriptionHolder:
        return L10n.tr(key: "Channel.DescriptionHolder")
      case .channelDescriptionHolderDescrpiton:
        return L10n.tr(key: "Channel.DescriptionHolderDescrpiton")
      case .channelExportLinkAboutChannel:
        return L10n.tr(key: "Channel.ExportLinkAboutChannel")
      case .channelExportLinkAboutGroup:
        return L10n.tr(key: "Channel.ExportLinkAboutGroup")
      case .channelIntroDescription:
        return L10n.tr(key: "Channel.IntroDescription")
      case .channelIntroDescriptionHeader:
        return L10n.tr(key: "Channel.IntroDescriptionHeader")
      case .channelNewChannel:
        return L10n.tr(key: "Channel.NewChannel")
      case .channelPrivate:
        return L10n.tr(key: "Channel.Private")
      case .channelPrivateAboutChannel:
        return L10n.tr(key: "Channel.PrivateAboutChannel")
      case .channelPrivateAboutGroup:
        return L10n.tr(key: "Channel.PrivateAboutGroup")
      case .channelPublic:
        return L10n.tr(key: "Channel.Public")
      case .channelPublicAboutChannel:
        return L10n.tr(key: "Channel.PublicAboutChannel")
      case .channelPublicAboutGroup:
        return L10n.tr(key: "Channel.PublicAboutGroup")
      case .channelPublicNamesLimitError:
        return L10n.tr(key: "Channel.PublicNamesLimitError")
      case .channelTypeHeaderChannel:
        return L10n.tr(key: "Channel.TypeHeaderChannel")
      case .channelTypeHeaderGroup:
        return L10n.tr(key: "Channel.TypeHeaderGroup")
      case .channelUsernameAboutChannel:
        return L10n.tr(key: "Channel.UsernameAboutChannel")
      case .channelUsernameAboutGroup:
        return L10n.tr(key: "Channel.UsernameAboutGroup")
      case .channelUserRestriction:
        return L10n.tr(key: "Channel.UserRestriction")
      case .channelAdminAdminAccess:
        return L10n.tr(key: "Channel.Admin.AdminAccess")
      case .channelAdminAdminRestricted:
        return L10n.tr(key: "Channel.Admin.AdminRestricted")
      case .channelAdminCantEditRights:
        return L10n.tr(key: "Channel.Admin.CantEditRights")
      case .channelAdminDismiss:
        return L10n.tr(key: "Channel.Admin.Dismiss")
      case .channelAdminWhatCanAdminDo:
        return L10n.tr(key: "Channel.Admin.WhatCanAdminDo")
      case .channelAdminsAddAdminError:
        return L10n.tr(key: "Channel.Admins.AddAdminError")
      case .channelAdminsPromotedBy(let p1):
        return L10n.tr(key: "Channel.Admins.PromotedBy", p1)
      case .channelAdminsPromoteBannedAdminError:
        return L10n.tr(key: "Channel.Admins.Promote.BannedAdminError")
      case .channelAdminsPromoteUnmemberAdminError:
        return L10n.tr(key: "Channel.Admins.Promote.UnmemberAdminError")
      case .channelBlacklistBlockedBy(let p1):
        return L10n.tr(key: "Channel.Blacklist.BlockedBy", p1)
      case .channelBlacklistDemoteAdminError:
        return L10n.tr(key: "Channel.Blacklist.DemoteAdminError")
      case .channelBlacklistRestrictedBy(let p1):
        return L10n.tr(key: "Channel.Blacklist.RestrictedBy", p1)
      case .channelBlacklistSelectNewUserTitle:
        return L10n.tr(key: "Channel.Blacklist.SelectNewUserTitle")
      case .channelBlacklistUnban:
        return L10n.tr(key: "Channel.Blacklist.Unban")
      case .channelBlockUserBlockFor:
        return L10n.tr(key: "Channel.BlockUser.BlockFor")
      case .channelBlockUserCanEmbedLinks:
        return L10n.tr(key: "Channel.BlockUser.CanEmbedLinks")
      case .channelBlockUserCanReadMessages:
        return L10n.tr(key: "Channel.BlockUser.CanReadMessages")
      case .channelBlockUserCanSendMedia:
        return L10n.tr(key: "Channel.BlockUser.CanSendMedia")
      case .channelBlockUserCanSendMessages:
        return L10n.tr(key: "Channel.BlockUser.CanSendMessages")
      case .channelBlockUserCanSendStickers:
        return L10n.tr(key: "Channel.BlockUser.CanSendStickers")
      case .channelEditAdminPermissionAddNewAdmins:
        return L10n.tr(key: "Channel.EditAdmin.Permission.AddNewAdmins")
      case .channelEditAdminPermissionBanUsers:
        return L10n.tr(key: "Channel.EditAdmin.Permission.BanUsers")
      case .channelEditAdminPermissionChangeInfo:
        return L10n.tr(key: "Channel.EditAdmin.Permission.ChangeInfo")
      case .channelEditAdminPermissionDeleteMessages:
        return L10n.tr(key: "Channel.EditAdmin.Permission.DeleteMessages")
      case .channelEditAdminPermissionEditMessages:
        return L10n.tr(key: "Channel.EditAdmin.Permission.EditMessages")
      case .channelEditAdminPermissionInviteUsers:
        return L10n.tr(key: "Channel.EditAdmin.Permission.InviteUsers")
      case .channelEditAdminPermissionPinMessages:
        return L10n.tr(key: "Channel.EditAdmin.Permission.PinMessages")
      case .channelEditAdminPermissionPostMessages:
        return L10n.tr(key: "Channel.EditAdmin.Permission.PostMessages")
      case .channelEventFilterAdminsHeader:
        return L10n.tr(key: "Channel.EventFilter.AdminsHeader")
      case .channelEventFilterEventsHeader:
        return L10n.tr(key: "Channel.EventFilter.EventsHeader")
      case .channelEventLogEmpty:
        return L10n.tr(key: "Channel.EventLog.Empty")
      case .channelEventLogEmptySearch:
        return L10n.tr(key: "Channel.EventLog.EmptySearch")
      case .channelEventLogEmptyText:
        return L10n.tr(key: "Channel.EventLog.EmptyText")
      case .channelEventLogOriginalMessage:
        return L10n.tr(key: "Channel.EventLog.OriginalMessage")
      case .channelEventLogWhat:
        return L10n.tr(key: "Channel.EventLog.What")
      case .channelEventLogAlertHeader:
        return L10n.tr(key: "Channel.EventLog.Alert.Header")
      case .channelEventLogAlertInfo:
        return L10n.tr(key: "Channel.EventLog.Alert.Info")
      case .channelEventLogServiceAboutRemoved(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.AboutRemoved", p1)
      case .channelEventLogServiceAboutUpdated(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.AboutUpdated", p1)
      case .channelEventLogServiceDisableSignatures(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.DisableSignatures", p1)
      case .channelEventLogServiceEnableSignatures(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.EnableSignatures", p1)
      case .channelEventLogServiceLinkRemoved(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.LinkRemoved", p1)
      case .channelEventLogServiceLinkUpdated(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.LinkUpdated", p1)
      case .channelEventLogServicePhotoRemoved(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.PhotoRemoved", p1)
      case .channelEventLogServicePhotoUpdated(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.PhotoUpdated", p1)
      case .channelEventLogServiceTitleUpdated(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.TitleUpdated", p1)
      case .channelEventLogServiceUpdateJoin(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.UpdateJoin", p1)
      case .channelEventLogServiceUpdateLeft(let p1):
        return L10n.tr(key: "Channel.EventLog.Service.UpdateLeft", p1)
      case .channelPersmissionDeniedSendInlineForever:
        return L10n.tr(key: "Channel.Persmission.Denied.SendInline.Forever")
      case .channelPersmissionDeniedSendInlineUntil(let p1):
        return L10n.tr(key: "Channel.Persmission.Denied.SendInline.Until", p1)
      case .channelPersmissionDeniedSendMediaForever:
        return L10n.tr(key: "Channel.Persmission.Denied.SendMedia.Forever")
      case .channelPersmissionDeniedSendMediaUntil(let p1):
        return L10n.tr(key: "Channel.Persmission.Denied.SendMedia.Until", p1)
      case .channelPersmissionDeniedSendMessagesForever:
        return L10n.tr(key: "Channel.Persmission.Denied.SendMessages.Forever")
      case .channelPersmissionDeniedSendMessagesUntil(let p1):
        return L10n.tr(key: "Channel.Persmission.Denied.SendMessages.Until", p1)
      case .channelPersmissionDeniedSendStickersForever:
        return L10n.tr(key: "Channel.Persmission.Denied.SendStickers.Forever")
      case .channelPersmissionDeniedSendStickersUntil(let p1):
        return L10n.tr(key: "Channel.Persmission.Denied.SendStickers.Until", p1)
      case .channelSelectPeersContacts:
        return L10n.tr(key: "Channel.SelectPeers.Contacts")
      case .channelSelectPeersGlobal:
        return L10n.tr(key: "Channel.SelectPeers.Global")
      case .channelAdminsRecentActions:
        return L10n.tr(key: "ChannelAdmins.RecentActions")
      case .channelBlacklistAddMember:
        return L10n.tr(key: "ChannelBlacklist.AddMember")
      case .channelBlacklistBlocked:
        return L10n.tr(key: "ChannelBlacklist.Blocked")
      case .channelBlacklistEmptyDescrpition:
        return L10n.tr(key: "ChannelBlacklist.EmptyDescrpition")
      case .channelBlacklistRestricted:
        return L10n.tr(key: "ChannelBlacklist.Restricted")
      case .channelEventFilterChannelInfo:
        return L10n.tr(key: "ChannelEventFilter.ChannelInfo")
      case .channelEventFilterDeletedMessages:
        return L10n.tr(key: "ChannelEventFilter.DeletedMessages")
      case .channelEventFilterEditedMessages:
        return L10n.tr(key: "ChannelEventFilter.EditedMessages")
      case .channelEventFilterGroupInfo:
        return L10n.tr(key: "ChannelEventFilter.GroupInfo")
      case .channelEventFilterLeavingMembers:
        return L10n.tr(key: "ChannelEventFilter.LeavingMembers")
      case .channelEventFilterNewAdmins:
        return L10n.tr(key: "ChannelEventFilter.NewAdmins")
      case .channelEventFilterNewMembers:
        return L10n.tr(key: "ChannelEventFilter.NewMembers")
      case .channelEventFilterNewRestrictions:
        return L10n.tr(key: "ChannelEventFilter.NewRestrictions")
      case .channelEventFilterPinnedMessages:
        return L10n.tr(key: "ChannelEventFilter.PinnedMessages")
      case .channelMembersAddMembers:
        return L10n.tr(key: "ChannelMembers.AddMembers")
      case .channelMembersInviteLink:
        return L10n.tr(key: "ChannelMembers.InviteLink")
      case .channelMembersMembersListDesc:
        return L10n.tr(key: "ChannelMembers.MembersListDesc")
      case .channelMembersSelectTitle:
        return L10n.tr(key: "ChannelMembers.Select.Title")
      case .channelVisibilityChecking:
        return L10n.tr(key: "ChannelVisibility.Checking")
      case .channelVisibilityLoading:
        return L10n.tr(key: "ChannelVisibility.Loading")
      case .chatAdminBadge:
        return L10n.tr(key: "Chat.AdminBadge")
      case .chatCancel:
        return L10n.tr(key: "Chat.Cancel")
      case .chatDropAsFilesDesc:
        return L10n.tr(key: "Chat.DropAsFilesDesc")
      case .chatDropQuickDesc:
        return L10n.tr(key: "Chat.DropQuickDesc")
      case .chatDropTitle:
        return L10n.tr(key: "Chat.DropTitle")
      case .chatEmptyChat:
        return L10n.tr(key: "Chat.EmptyChat")
      case .chatForwardActionHeader:
        return L10n.tr(key: "Chat.ForwardActionHeader")
      case .chatInstantView:
        return L10n.tr(key: "Chat.InstantView")
      case .chatSearchCount(let p1, let p2):
        return L10n.tr(key: "Chat.SearchCount", p1, p2)
      case .chatSearchFrom:
        return L10n.tr(key: "Chat.SearchFrom")
      case .chatShareInlineResultActionHeader:
        return L10n.tr(key: "Chat.ShareInlineResultActionHeader")
      case .chatCallIncoming:
        return L10n.tr(key: "Chat.Call.Incoming")
      case .chatCallOutgoing:
        return L10n.tr(key: "Chat.Call.Outgoing")
      case .chatConfirmActionUndonable:
        return L10n.tr(key: "Chat.Confirm.ActionUndonable")
      case .chatConfirmDeleteMessages:
        return L10n.tr(key: "Chat.Confirm.DeleteMessages")
      case .chatConfirmDeleteMessagesForEveryone:
        return L10n.tr(key: "Chat.Confirm.DeleteMessagesForEveryone")
      case .chatConfirmUnpin:
        return L10n.tr(key: "Chat.Confirm.Unpin")
      case .chatConnectingStatusConnecting:
        return L10n.tr(key: "Chat.ConnectingStatus.connecting")
      case .chatConnectingStatusConnectingToProxy:
        return L10n.tr(key: "Chat.ConnectingStatus.connectingToProxy")
      case .chatConnectingStatusUpdating:
        return L10n.tr(key: "Chat.ConnectingStatus.updating")
      case .chatConnectingStatusWaitingNetwork:
        return L10n.tr(key: "Chat.ConnectingStatus.waitingNetwork")
      case .chatContextAddFavoriteSticker:
        return L10n.tr(key: "Chat.Context.AddFavoriteSticker")
      case .chatContextClearHistory:
        return L10n.tr(key: "Chat.Context.ClearHistory")
      case .chatContextCopyBlock:
        return L10n.tr(key: "Chat.Context.CopyBlock")
      case .chatContextDisableNotifications:
        return L10n.tr(key: "Chat.Context.DisableNotifications")
      case .chatContextEdit:
        return L10n.tr(key: "Chat.Context.Edit")
      case .chatContextEnableNotifications:
        return L10n.tr(key: "Chat.Context.EnableNotifications")
      case .chatContextInfo:
        return L10n.tr(key: "Chat.Context.Info")
      case .chatContextRemoveFavoriteSticker:
        return L10n.tr(key: "Chat.Context.RemoveFavoriteSticker")
      case .chatHeaderPinnedMessage:
        return L10n.tr(key: "Chat.Header.PinnedMessage")
      case .chatHeaderReportSpam:
        return L10n.tr(key: "Chat.Header.ReportSpam")
      case .chatInputDelete:
        return L10n.tr(key: "Chat.Input.Delete")
      case .chatInputJoin:
        return L10n.tr(key: "Chat.Input.Join")
      case .chatInputMute:
        return L10n.tr(key: "Chat.Input.Mute")
      case .chatInputReturn:
        return L10n.tr(key: "Chat.Input.Return")
      case .chatInputStartBot:
        return L10n.tr(key: "Chat.Input.StartBot")
      case .chatInputUnblock:
        return L10n.tr(key: "Chat.Input.Unblock")
      case .chatInputUnmute:
        return L10n.tr(key: "Chat.Input.Unmute")
      case .chatInputAccessoryEditMessage:
        return L10n.tr(key: "Chat.Input.Accessory.EditMessage")
      case .chatInputSecretChatWaitingToOnline:
        return L10n.tr(key: "Chat.Input.SecretChat.WaitingToOnline")
      case .chatListContact:
        return L10n.tr(key: "Chat.List.Contact")
      case .chatListGIF:
        return L10n.tr(key: "Chat.List.GIF")
      case .chatListInstantVideo:
        return L10n.tr(key: "Chat.List.InstantVideo")
      case .chatListMap:
        return L10n.tr(key: "Chat.List.Map")
      case .chatListPhoto:
        return L10n.tr(key: "Chat.List.Photo")
      case .chatListSticker(let p1):
        return L10n.tr(key: "Chat.List.Sticker", p1)
      case .chatListVideo:
        return L10n.tr(key: "Chat.List.Video")
      case .chatListVoice:
        return L10n.tr(key: "Chat.List.Voice")
      case .chatListServicePaymentSent(let p1):
        return L10n.tr(key: "Chat.List.Service.PaymentSent", p1)
      case .chatMessageEdited:
        return L10n.tr(key: "Chat.Message.edited")
      case .chatMessageUnsupported:
        return L10n.tr(key: "Chat.Message.Unsupported")
      case .chatMessageVia:
        return L10n.tr(key: "Chat.Message.Via")
      case .chatSecretChat1Feature:
        return L10n.tr(key: "Chat.SecretChat.1Feature")
      case .chatSecretChat2Feature:
        return L10n.tr(key: "Chat.SecretChat.2Feature")
      case .chatSecretChat3Feature:
        return L10n.tr(key: "Chat.SecretChat.3Feature")
      case .chatSecretChat4Feature:
        return L10n.tr(key: "Chat.SecretChat.4Feature")
      case .chatSecretChatEmptyHeader:
        return L10n.tr(key: "Chat.SecretChat.EmptyHeader")
      case .chatServicePaymentSent(let p1, let p2, let p3):
        return L10n.tr(key: "Chat.Service.PaymentSent", p1, p2, p3)
      case .chatServicePinnedMessage:
        return L10n.tr(key: "Chat.Service.PinnedMessage")
      case .chatServiceYou:
        return L10n.tr(key: "Chat.Service.You")
      case .chatServiceChannelRemovedPhoto:
        return L10n.tr(key: "Chat.Service.Channel.RemovedPhoto")
      case .chatServiceChannelUpdatedPhoto:
        return L10n.tr(key: "Chat.Service.Channel.UpdatedPhoto")
      case .chatServiceChannelUpdatedTitle(let p1):
        return L10n.tr(key: "Chat.Service.Channel.UpdatedTitle", p1)
      case .chatServiceGroupAddedMembers(let p1, let p2):
        return L10n.tr(key: "Chat.Service.Group.AddedMembers", p1, p2)
      case .chatServiceGroupAddedSelf(let p1):
        return L10n.tr(key: "Chat.Service.Group.AddedSelf", p1)
      case .chatServiceGroupCreated(let p1, let p2):
        return L10n.tr(key: "Chat.Service.Group.Created", p1, p2)
      case .chatServiceGroupJoinedByLink(let p1):
        return L10n.tr(key: "Chat.Service.Group.JoinedByLink", p1)
      case .chatServiceGroupMigratedToSupergroup:
        return L10n.tr(key: "Chat.Service.Group.MigratedToSupergroup")
      case .chatServiceGroupRemovedMembers(let p1, let p2):
        return L10n.tr(key: "Chat.Service.Group.RemovedMembers", p1, p2)
      case .chatServiceGroupRemovedPhoto(let p1):
        return L10n.tr(key: "Chat.Service.Group.RemovedPhoto", p1)
      case .chatServiceGroupRemovedSelf(let p1):
        return L10n.tr(key: "Chat.Service.Group.RemovedSelf", p1)
      case .chatServiceGroupTookScreenshot(let p1):
        return L10n.tr(key: "Chat.Service.Group.TookScreenshot", p1)
      case .chatServiceGroupUpdatedPhoto(let p1):
        return L10n.tr(key: "Chat.Service.Group.UpdatedPhoto", p1)
      case .chatServiceGroupUpdatedPinnedMessage(let p1, let p2):
        return L10n.tr(key: "Chat.Service.Group.UpdatedPinnedMessage", p1, p2)
      case .chatServiceGroupUpdatedTitle(let p1, let p2):
        return L10n.tr(key: "Chat.Service.Group.UpdatedTitle", p1, p2)
      case .chatServiceSecretChatDisabledTimer(let p1):
        return L10n.tr(key: "Chat.Service.SecretChat.DisabledTimer", p1)
      case .chatServiceSecretChatSetTimer(let p1, let p2):
        return L10n.tr(key: "Chat.Service.SecretChat.SetTimer", p1, p2)
      case .chatServiceSecretChatDisabledTimerSelf:
        return L10n.tr(key: "Chat.Service.SecretChat.DisabledTimer.Self")
      case .chatServiceSecretChatSetTimerSelf(let p1):
        return L10n.tr(key: "Chat.Service.SecretChat.SetTimer.Self", p1)
      case .chatTitleSelf:
        return L10n.tr(key: "Chat.Title.self")
      case .chatListDraft:
        return L10n.tr(key: "ChatList.Draft")
      case .chatListUnsupportedMessage:
        return L10n.tr(key: "ChatList.UnsupportedMessage")
      case .chatListYou:
        return L10n.tr(key: "ChatList.You")
      case .chatListContextCall:
        return L10n.tr(key: "ChatList.Context.Call")
      case .chatListContextClearHistory:
        return L10n.tr(key: "ChatList.Context.ClearHistory")
      case .chatListContextDeleteAndExit:
        return L10n.tr(key: "ChatList.Context.DeleteAndExit")
      case .chatListContextDeleteChat:
        return L10n.tr(key: "ChatList.Context.DeleteChat")
      case .chatListContextLeaveChannel:
        return L10n.tr(key: "ChatList.Context.LeaveChannel")
      case .chatListContextLeaveGroup:
        return L10n.tr(key: "ChatList.Context.LeaveGroup")
      case .chatListContextMute:
        return L10n.tr(key: "ChatList.Context.Mute")
      case .chatListContextPin:
        return L10n.tr(key: "ChatList.Context.Pin")
      case .chatListContextReturnGroup:
        return L10n.tr(key: "ChatList.Context.ReturnGroup")
      case .chatListContextUnmute:
        return L10n.tr(key: "ChatList.Context.Unmute")
      case .chatListContextUnpin:
        return L10n.tr(key: "ChatList.Context.Unpin")
      case .chatListSecretChatCreated(let p1):
        return L10n.tr(key: "ChatList.SecretChat.Created", p1)
      case .chatListSecretChatExKeys:
        return L10n.tr(key: "ChatList.SecretChat.ExKeys")
      case .chatListSecretChatJoined(let p1):
        return L10n.tr(key: "ChatList.SecretChat.Joined", p1)
      case .chatListSecretChatTerminated:
        return L10n.tr(key: "ChatList.SecretChat.Terminated")
      case .chatListServiceDestructingPhoto:
        return L10n.tr(key: "ChatList.Service.DestructingPhoto")
      case .chatListServiceDestructingVideo:
        return L10n.tr(key: "ChatList.Service.DestructingVideo")
      case .chatListServiceGameScored(let p1, let p2):
        return L10n.tr(key: "ChatList.Service.GameScored", p1, p2)
      case .chatListServiceCallCancelled:
        return L10n.tr(key: "ChatList.Service.Call.Cancelled")
      case .chatListServiceCallDisconnected:
        return L10n.tr(key: "ChatList.Service.Call.Disconnected")
      case .chatListServiceCallIncoming(let p1):
        return L10n.tr(key: "ChatList.Service.Call.incoming", p1)
      case .chatListServiceCallMissed:
        return L10n.tr(key: "ChatList.Service.Call.Missed")
      case .chatListServiceCallOutgoing(let p1):
        return L10n.tr(key: "ChatList.Service.Call.outgoing", p1)
      case .chatServiceChannelCreated:
        return L10n.tr(key: "ChatService.ChannelCreated")
      case .composeCreate:
        return L10n.tr(key: "Compose.Create")
      case .composeNext:
        return L10n.tr(key: "Compose.Next")
      case .composeSelectUsers:
        return L10n.tr(key: "Compose.SelectUsers")
      case .composeConfirmStartSecretChat(let p1):
        return L10n.tr(key: "Compose.Confirm.StartSecretChat", p1)
      case .composePopoverNewChannel:
        return L10n.tr(key: "Compose.Popover.NewChannel")
      case .composePopoverNewGroup:
        return L10n.tr(key: "Compose.Popover.NewGroup")
      case .composePopoverNewSecretChat:
        return L10n.tr(key: "Compose.Popover.NewSecretChat")
      case .composeSelectSecretChat:
        return L10n.tr(key: "Compose.Select.SecretChat")
      case .composeSelectGroupUsersPlaceholder:
        return L10n.tr(key: "Compose.SelectGroupUsers.Placeholder")
      case .confirmAddBotToGroup(let p1):
        return L10n.tr(key: "Confirm.AddBotToGroup", p1)
      case .confirmDeleteAdminedChannel:
        return L10n.tr(key: "Confirm.DeleteAdminedChannel")
      case .confirmDeleteChatUser:
        return L10n.tr(key: "Confirm.DeleteChatUser")
      case .confirmLeaveGroup:
        return L10n.tr(key: "Confirm.LeaveGroup")
      case .connectingStatusConnecting:
        return L10n.tr(key: "ConnectingStatus.connecting")
      case .connectingStatusConnectingToProxy:
        return L10n.tr(key: "ConnectingStatus.connectingToProxy")
      case .connectingStatusDisableProxy:
        return L10n.tr(key: "ConnectingStatus.DisableProxy")
      case .connectingStatusOnline:
        return L10n.tr(key: "ConnectingStatus.online")
      case .connectingStatusUpdating:
        return L10n.tr(key: "ConnectingStatus.updating")
      case .connectingStatusWaitingNetwork:
        return L10n.tr(key: "ConnectingStatus.waitingNetwork")
      case .contactsAddContact:
        return L10n.tr(key: "Contacts.AddContact")
      case .contactsContacsSeparator:
        return L10n.tr(key: "Contacts.ContacsSeparator")
      case .contactsNotRegistredDescription:
        return L10n.tr(key: "Contacts.NotRegistredDescription")
      case .contactsNotRegistredTitle:
        return L10n.tr(key: "Contacts.NotRegistredTitle")
      case .contactsFirstNamePlaceholder:
        return L10n.tr(key: "Contacts.FirstName.Placeholder")
      case .contactsLastNamePlaceholder:
        return L10n.tr(key: "Contacts.LastName.Placeholder")
      case .contactsPhoneNumberPlaceholder:
        return L10n.tr(key: "Contacts.PhoneNumber.Placeholder")
      case .contextCopyMedia:
        return L10n.tr(key: "Context.CopyMedia")
      case .contextRecentGifRemove:
        return L10n.tr(key: "Context.RecentGifRemove")
      case .contextRemoveFaveSticker:
        return L10n.tr(key: "Context.RemoveFaveSticker")
      case .contextShowInFinder:
        return L10n.tr(key: "Context.ShowInFinder")
      case .contextViewStickerSet:
        return L10n.tr(key: "Context.ViewStickerSet")
      case .convertToSuperGroupConfirm:
        return L10n.tr(key: "ConvertToSuperGroup.Confirm")
      case .convertToSupergroupAlertError:
        return L10n.tr(key: "ConvertToSupergroup.Alert.Error")
      case .createGroupNameHolder:
        return L10n.tr(key: "CreateGroup.NameHolder")
      case .cwLP1JidTitle:
        return L10n.tr(key: "cwL-P1-jid.title")
      case .d9MCDAMdTitle:
        return L10n.tr(key: "d9M-CD-aMd.title")
      case .dataAndStorageNetworkUsage:
        return L10n.tr(key: "DataAndStorage.NetworkUsage")
      case .dataAndStorageStorageUsage:
        return L10n.tr(key: "DataAndStorage.StorageUsage")
      case .dataAndStorageAutomaticAudioDownloadHeader:
        return L10n.tr(key: "DataAndStorage.AutomaticAudioDownload.Header")
      case .dataAndStorageAutomaticDownloadGroupsChannels:
        return L10n.tr(key: "DataAndStorage.AutomaticDownload.GroupsChannels")
      case .dataAndStorageAutomaticPhotoDownloadHeader:
        return L10n.tr(key: "DataAndStorage.AutomaticPhotoDownload.Header")
      case .dataAndStorageAutomaticVideoDownloadHeader:
        return L10n.tr(key: "DataAndStorage.AutomaticVideoDownload.Header")
      case .dateToday:
        return L10n.tr(key: "Date.Today")
      case .drj4nYzgTitle:
        return L10n.tr(key: "dRJ-4n-Yzg.title")
      case .dv1IoYv7Title:
        return L10n.tr(key: "Dv1-io-Yv7.title")
      case .emojiActivityAndSport:
        return L10n.tr(key: "Emoji.ActivityAndSport")
      case .emojiAnimalsAndNature:
        return L10n.tr(key: "Emoji.AnimalsAndNature")
      case .emojiFlags:
        return L10n.tr(key: "Emoji.Flags")
      case .emojiFoodAndDrink:
        return L10n.tr(key: "Emoji.FoodAndDrink")
      case .emojiObjects:
        return L10n.tr(key: "Emoji.Objects")
      case .emojiRecent:
        return L10n.tr(key: "Emoji.Recent")
      case .emojiSmilesAndPeople:
        return L10n.tr(key: "Emoji.SmilesAndPeople")
      case .emojiSymbols:
        return L10n.tr(key: "Emoji.Symbols")
      case .emojiTravelAndPlaces:
        return L10n.tr(key: "Emoji.TravelAndPlaces")
      case .emptyPeerDescription:
        return L10n.tr(key: "EmptyPeer.Description")
      case .encryptionKeyDescription(let p1, let p2):
        return L10n.tr(key: "EncryptionKey.Description", p1, p2)
      case .entertainmentEmoji:
        return L10n.tr(key: "Entertainment.Emoji")
      case .entertainmentGIF:
        return L10n.tr(key: "Entertainment.GIF")
      case .entertainmentStickers:
        return L10n.tr(key: "Entertainment.Stickers")
      case .entertainmentSwitchEmoji:
        return L10n.tr(key: "Entertainment.Switch.Emoji")
      case .entertainmentSwitchGifAndStickers:
        return L10n.tr(key: "Entertainment.Switch.GifAndStickers")
      case .errorUsernameAlreadyTaken:
        return L10n.tr(key: "Error.Username.AlreadyTaken")
      case .errorUsernameInvalid:
        return L10n.tr(key: "Error.Username.Invalid")
      case .errorUsernameMinimumLength:
        return L10n.tr(key: "Error.Username.MinimumLength")
      case .errorUsernameNumberStart:
        return L10n.tr(key: "Error.Username.NumberStart")
      case .errorUsernameUnderscopeEnd:
        return L10n.tr(key: "Error.Username.UnderscopeEnd")
      case .errorUsernameUnderscopeStart:
        return L10n.tr(key: "Error.Username.UnderscopeStart")
      case .eventLogServiceBanned(let p1, let p2):
        return L10n.tr(key: "EventLog.Service.Banned", p1, p2)
      case .eventLogServiceChangedStickerSet(let p1):
        return L10n.tr(key: "EventLog.Service.ChangedStickerSet", p1)
      case .eventLogServiceDeletedMessage(let p1):
        return L10n.tr(key: "EventLog.Service.DeletedMessage", p1)
      case .eventLogServiceDemoted(let p1, let p2):
        return L10n.tr(key: "EventLog.Service.Demoted", p1, p2)
      case .eventLogServiceEditedMessage(let p1):
        return L10n.tr(key: "EventLog.Service.EditedMessage", p1)
      case .eventLogServicePreviousDesc:
        return L10n.tr(key: "EventLog.Service.PreviousDesc")
      case .eventLogServicePreviousLink:
        return L10n.tr(key: "EventLog.Service.PreviousLink")
      case .eventLogServicePreviousTitle:
        return L10n.tr(key: "EventLog.Service.PreviousTitle")
      case .eventLogServicePromoted(let p1, let p2):
        return L10n.tr(key: "EventLog.Service.Promoted", p1, p2)
      case .eventLogServiceRemovedStickerSet(let p1):
        return L10n.tr(key: "EventLog.Service.RemovedStickerSet", p1)
      case .eventLogServiceRemovePinned(let p1):
        return L10n.tr(key: "EventLog.Service.RemovePinned", p1)
      case .eventLogServiceUpdatePinned(let p1):
        return L10n.tr(key: "EventLog.Service.UpdatePinned", p1)
      case .eventLogServiceDemoteEmbedLinks:
        return L10n.tr(key: "EventLog.Service.Demote.EmbedLinks")
      case .eventLogServiceDemoteSendInline:
        return L10n.tr(key: "EventLog.Service.Demote.SendInline")
      case .eventLogServiceDemoteSendMedia:
        return L10n.tr(key: "EventLog.Service.Demote.SendMedia")
      case .eventLogServiceDemoteSendMessages:
        return L10n.tr(key: "EventLog.Service.Demote.SendMessages")
      case .eventLogServiceDemoteSendStickers:
        return L10n.tr(key: "EventLog.Service.Demote.SendStickers")
      case .eventLogServiceDemotedChanged(let p1, let p2):
        return L10n.tr(key: "EventLog.Service.Demoted.Changed", p1, p2)
      case .eventLogServiceDemotedUntil(let p1, let p2, let p3):
        return L10n.tr(key: "EventLog.Service.Demoted.Until", p1, p2, p3)
      case .eventLogServiceDemotedChangedUntil(let p1, let p2, let p3):
        return L10n.tr(key: "EventLog.Service.Demoted.Changed.Until", p1, p2, p3)
      case .eventLogServicePromoteAddNewAdmins:
        return L10n.tr(key: "EventLog.Service.Promote.AddNewAdmins")
      case .eventLogServicePromoteAddUsers:
        return L10n.tr(key: "EventLog.Service.Promote.AddUsers")
      case .eventLogServicePromoteBanUsers:
        return L10n.tr(key: "EventLog.Service.Promote.BanUsers")
      case .eventLogServicePromoteChangeInfo:
        return L10n.tr(key: "EventLog.Service.Promote.ChangeInfo")
      case .eventLogServicePromoteDeleteMessages:
        return L10n.tr(key: "EventLog.Service.Promote.DeleteMessages")
      case .eventLogServicePromoteEditMessages:
        return L10n.tr(key: "EventLog.Service.Promote.EditMessages")
      case .eventLogServicePromoteInviteViaLink:
        return L10n.tr(key: "EventLog.Service.Promote.InviteViaLink")
      case .eventLogServicePromotePinMessages:
        return L10n.tr(key: "EventLog.Service.Promote.PinMessages")
      case .eventLogServicePromotePostMessages:
        return L10n.tr(key: "EventLog.Service.Promote.PostMessages")
      case .eventLogServicePromotedChanged(let p1, let p2):
        return L10n.tr(key: "EventLog.Service.Promoted.Changed", p1, p2)
      case .fastSettingsDisableDarkMode:
        return L10n.tr(key: "FastSettings.DisableDarkMode")
      case .fastSettingsEnableDarkMode:
        return L10n.tr(key: "FastSettings.EnableDarkMode")
      case .fastSettingsLockTelegram:
        return L10n.tr(key: "FastSettings.LockTelegram")
      case .fastSettingsMute2Hours:
        return L10n.tr(key: "FastSettings.Mute2Hours")
      case .fastSettingsSetPasscode:
        return L10n.tr(key: "FastSettings.SetPasscode")
      case .fastSettingsUnmute:
        return L10n.tr(key: "FastSettings.Unmute")
      case .feMD8WVrTitle:
        return L10n.tr(key: "FeM-D8-WVr.title")
      case .forwardModalActionDescriptionCountable(let p1, let p2):
        return L10n.tr(key: "ForwardModalAction.description_countable", p1, p2)
      case .forwardModalActionDescriptionFew(let p1):
        return L10n.tr(key: "ForwardModalAction.description_few", p1)
      case .forwardModalActionDescriptionMany(let p1):
        return L10n.tr(key: "ForwardModalAction.description_many", p1)
      case .forwardModalActionDescriptionOne(let p1):
        return L10n.tr(key: "ForwardModalAction.description_one", p1)
      case .forwardModalActionDescriptionOther(let p1):
        return L10n.tr(key: "ForwardModalAction.description_other", p1)
      case .forwardModalActionDescriptionTwo(let p1):
        return L10n.tr(key: "ForwardModalAction.description_two", p1)
      case .forwardModalActionDescriptionZero(let p1):
        return L10n.tr(key: "ForwardModalAction.description_zero", p1)
      case .forwardModalActionTitleCountable(let p1):
        return L10n.tr(key: "ForwardModalAction.Title_countable", p1)
      case .forwardModalActionTitleFew:
        return L10n.tr(key: "ForwardModalAction.Title_few")
      case .forwardModalActionTitleMany:
        return L10n.tr(key: "ForwardModalAction.Title_many")
      case .forwardModalActionTitleOne:
        return L10n.tr(key: "ForwardModalAction.Title_one")
      case .forwardModalActionTitleOther:
        return L10n.tr(key: "ForwardModalAction.Title_other")
      case .forwardModalActionTitleTwo:
        return L10n.tr(key: "ForwardModalAction.Title_two")
      case .forwardModalActionTitleZero:
        return L10n.tr(key: "ForwardModalAction.Title_zero")
      case .galleryContextDeletePhoto:
        return L10n.tr(key: "Gallery.ContextDeletePhoto")
      case .galleryCounter(let p1, let p2):
        return L10n.tr(key: "Gallery.Counter", p1, p2)
      case .galleryContextCopyToClipboard:
        return L10n.tr(key: "Gallery.Context.CopyToClipboard")
      case .galleryContextSaveAs:
        return L10n.tr(key: "Gallery.Context.SaveAs")
      case .galleryContextShowMessage:
        return L10n.tr(key: "Gallery.Context.ShowMessage")
      case .generalSettingsAppearanceSettings:
        return L10n.tr(key: "GeneralSettings.AppearanceSettings")
      case .generalSettingsDarkMode:
        return L10n.tr(key: "GeneralSettings.DarkMode")
      case .generalSettingsEmojiReplacements:
        return L10n.tr(key: "GeneralSettings.EmojiReplacements")
      case .generalSettingsEnableSidebar:
        return L10n.tr(key: "GeneralSettings.EnableSidebar")
      case .generalSettingsGeneralSettings:
        return L10n.tr(key: "GeneralSettings.GeneralSettings")
      case .generalSettingsInAppSounds:
        return L10n.tr(key: "GeneralSettings.InAppSounds")
      case .generalSettingsInputSettings:
        return L10n.tr(key: "GeneralSettings.InputSettings")
      case .generalSettingsLargeFonts:
        return L10n.tr(key: "GeneralSettings.LargeFonts")
      case .generalSettingsMediaKeysForInAppPlayer:
        return L10n.tr(key: "GeneralSettings.MediaKeysForInAppPlayer")
      case .generalSettingsSendByCmdEnter:
        return L10n.tr(key: "GeneralSettings.SendByCmdEnter")
      case .generalSettingsSendByEnter:
        return L10n.tr(key: "GeneralSettings.SendByEnter")
      case .generalSettingsDarkModeDescription:
        return L10n.tr(key: "GeneralSettings.DarkMode.Description")
      case .generalSettingsFontDescription:
        return L10n.tr(key: "GeneralSettings.Font.Description")
      case .groupCreateGroup:
        return L10n.tr(key: "Group.CreateGroup")
      case .groupNewGroup:
        return L10n.tr(key: "Group.NewGroup")
      case .groupUnavailable:
        return L10n.tr(key: "Group.Unavailable")
      case .groupEditAdminPermissionChangeInfo:
        return L10n.tr(key: "Group.EditAdmin.Permission.ChangeInfo")
      case .groupEventLogEmptyText:
        return L10n.tr(key: "Group.EventLog.EmptyText")
      case .groupEventLogServiceAboutRemoved(let p1):
        return L10n.tr(key: "Group.EventLog.Service.AboutRemoved", p1)
      case .groupEventLogServiceAboutUpdated(let p1):
        return L10n.tr(key: "Group.EventLog.Service.AboutUpdated", p1)
      case .groupEventLogServiceDisableInvites(let p1):
        return L10n.tr(key: "Group.EventLog.Service.DisableInvites", p1)
      case .groupEventLogServiceEnableInvites(let p1):
        return L10n.tr(key: "Group.EventLog.Service.EnableInvites", p1)
      case .groupEventLogServiceLinkRemoved(let p1):
        return L10n.tr(key: "Group.EventLog.Service.LinkRemoved", p1)
      case .groupEventLogServiceLinkUpdated(let p1):
        return L10n.tr(key: "Group.EventLog.Service.LinkUpdated", p1)
      case .groupEventLogServicePhotoRemoved(let p1):
        return L10n.tr(key: "Group.EventLog.Service.PhotoRemoved", p1)
      case .groupEventLogServicePhotoUpdated(let p1):
        return L10n.tr(key: "Group.EventLog.Service.PhotoUpdated", p1)
      case .groupEventLogServiceTitleUpdated(let p1):
        return L10n.tr(key: "Group.EventLog.Service.TitleUpdated", p1)
      case .groupEventLogServiceUpdateJoin(let p1):
        return L10n.tr(key: "Group.EventLog.Service.UpdateJoin", p1)
      case .groupEventLogServiceUpdateLeft(let p1):
        return L10n.tr(key: "Group.EventLog.Service.UpdateLeft", p1)
      case .groupAdminsAllMembersAdmins:
        return L10n.tr(key: "GroupAdmins.AllMembersAdmins")
      case .groupAdminsDescAdminInvites:
        return L10n.tr(key: "GroupAdmins.Desc.AdminInvites")
      case .groupAdminsDescAllInvites:
        return L10n.tr(key: "GroupAdmins.Desc.AllInvites")
      case .groupInvationChannelDescription:
        return L10n.tr(key: "GroupInvation.ChannelDescription")
      case .groupInvationCopyLink:
        return L10n.tr(key: "GroupInvation.CopyLink")
      case .groupInvationGroupDescription:
        return L10n.tr(key: "GroupInvation.GroupDescription")
      case .groupInvationRevoke:
        return L10n.tr(key: "GroupInvation.Revoke")
      case .groupInvationShare:
        return L10n.tr(key: "GroupInvation.Share")
      case .groupsInCommonEmpty:
        return L10n.tr(key: "GroupsInCommon.Empty")
      case .groupStickersChooseHeader:
        return L10n.tr(key: "GroupStickers.ChooseHeader")
      case .groupStickersCreateDescription:
        return L10n.tr(key: "GroupStickers.CreateDescription")
      case .groupStickersEmptyDesc:
        return L10n.tr(key: "GroupStickers.EmptyDesc")
      case .groupStickersEmptyHeader:
        return L10n.tr(key: "GroupStickers.EmptyHeader")
      case .gvau4SdLTitle:
        return L10n.tr(key: "gVA-U4-sdL.title")
      case .h8h7bM4vTitle:
        return L10n.tr(key: "H8h-7b-M4v.title")
      case .hFoCyZxITitle:
        return L10n.tr(key: "HFo-cy-zxI.title")
      case .hfqgknfaTitle:
        return L10n.tr(key: "HFQ-gK-NFA.title")
      case .hQb2vFYvTitle:
        return L10n.tr(key: "hQb-2v-fYv.title")
      case .hyVFhRgOTitle:
        return L10n.tr(key: "HyV-fh-RgO.title")
      case .hz2CUCR7Title:
        return L10n.tr(key: "hz2-CU-CR7.title")
      case .inAppLinksConfirmOpenExternal(let p1):
        return L10n.tr(key: "InAppLinks.Confirm.OpenExternal", p1)
      case .inlineModalActionDesc(let p1):
        return L10n.tr(key: "InlineModalAction.Desc", p1)
      case .inlineModalActionTitle:
        return L10n.tr(key: "InlineModalAction.Title")
      case .inputAttachPopoverFile:
        return L10n.tr(key: "InputAttach.Popover.File")
      case .inputAttachPopoverPhotoOrVideo:
        return L10n.tr(key: "InputAttach.Popover.PhotoOrVideo")
      case .inputAttachPopoverPicture:
        return L10n.tr(key: "InputAttach.Popover.Picture")
      case .installedStickersArchived:
        return L10n.tr(key: "InstalledStickers.Archived")
      case .installedStickersDescrpiption:
        return L10n.tr(key: "InstalledStickers.Descrpiption")
      case .installedStickersPacksTitle:
        return L10n.tr(key: "InstalledStickers.PacksTitle")
      case .installedStickersTranding:
        return L10n.tr(key: "InstalledStickers.Tranding")
      case .installedStickersRemoveDelete:
        return L10n.tr(key: "InstalledStickers.Remove.Delete")
      case .installedStickersRemoveDescription:
        return L10n.tr(key: "InstalledStickers.Remove.Description")
      case .instantPageAuthorAndDateTitle(let p1, let p2):
        return L10n.tr(key: "InstantPage.AuthorAndDateTitle", p1, p2)
      case .ivChannelJoin:
        return L10n.tr(key: "IV.Channel.Join")
      case .joinLinkJoin:
        return L10n.tr(key: "JoinLink.Join")
      case .kd2MpPUSTitle:
        return L10n.tr(key: "Kd2-mp-pUS.title")
      case .le2AR0XJTitle:
        return L10n.tr(key: "LE2-aR-0XJ.title")
      case .legacyIntroDescription1:
        return L10n.tr(key: "Legacy.Intro.Description1")
      case .legacyIntroDescription2:
        return L10n.tr(key: "Legacy.Intro.Description2")
      case .legacyIntroNext:
        return L10n.tr(key: "Legacy.Intro.Next")
      case .linkInvationChannelConfirmRevoke:
        return L10n.tr(key: "LinkInvation.Channel.Confirm.Revoke")
      case .linkInvationConfirmOk:
        return L10n.tr(key: "LinkInvation.Confirm.Ok")
      case .linkInvationGroupConfirmRevoke:
        return L10n.tr(key: "LinkInvation.Group.Confirm.Revoke")
      case .loginCodePlaceholder:
        return L10n.tr(key: "Login.codePlaceholder")
      case .loginContinueOnLanguage:
        return L10n.tr(key: "Login.ContinueOnLanguage")
      case .loginCountryLabel:
        return L10n.tr(key: "Login.countryLabel")
      case .loginEnterCodeFromApp:
        return L10n.tr(key: "Login.EnterCodeFromApp")
      case .loginEnterPasswordDescription:
        return L10n.tr(key: "Login.EnterPasswordDescription")
      case .loginFloodWait:
        return L10n.tr(key: "Login.FloodWait")
      case .loginInvalidCountryCode:
        return L10n.tr(key: "Login.InvalidCountryCode")
      case .loginJustSentSms:
        return L10n.tr(key: "Login.JustSentSms")
      case .loginNext:
        return L10n.tr(key: "Login.Next")
      case .loginPasswordPlaceholder:
        return L10n.tr(key: "Login.passwordPlaceholder")
      case .loginPhoneCalledCode:
        return L10n.tr(key: "Login.PhoneCalledCode")
      case .loginPhoneDialed:
        return L10n.tr(key: "Login.PhoneDialed")
      case .loginPhoneFieldPlaceholder:
        return L10n.tr(key: "Login.phoneFieldPlaceholder")
      case .loginPhoneNumberNotRegistred:
        return L10n.tr(key: "Login.PhoneNumberNotRegistred")
      case .loginRecoveryMailFailed:
        return L10n.tr(key: "Login.RecoveryMailFailed")
      case .loginResetAccount:
        return L10n.tr(key: "Login.ResetAccount")
      case .loginResetAccountDescription:
        return L10n.tr(key: "Login.ResetAccountDescription")
      case .loginSendSmsIfNotReceivedAppCode:
        return L10n.tr(key: "Login.SendSmsIfNotReceivedAppCode")
      case .loginWelcomeDescription:
        return L10n.tr(key: "Login.WelcomeDescription")
      case .loginWillCall(let p1, let p2):
        return L10n.tr(key: "Login.willCall", p1, p2)
      case .loginWillSendSms(let p1, let p2):
        return L10n.tr(key: "Login.willSendSms", p1, p2)
      case .loginYourCodeLabel:
        return L10n.tr(key: "Login.YourCodeLabel")
      case .loginYourPasswordLabel:
        return L10n.tr(key: "Login.YourPasswordLabel")
      case .loginYourPhoneLabel:
        return L10n.tr(key: "Login.YourPhoneLabel")
      case .loginHeaderCode:
        return L10n.tr(key: "Login.Header.Code")
      case .loginHeaderPassword:
        return L10n.tr(key: "Login.Header.Password")
      case .loginHeaderSignUp:
        return L10n.tr(key: "Login.Header.SignUp")
      case .messageAccessoryPanelForwardedCountable(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_countable", p1)
      case .messageAccessoryPanelForwardedFew(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_few", p1)
      case .messageAccessoryPanelForwardedMany(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_many", p1)
      case .messageAccessoryPanelForwardedOne(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_one", p1)
      case .messageAccessoryPanelForwardedOther(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_other", p1)
      case .messageAccessoryPanelForwardedTwo(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_two", p1)
      case .messageAccessoryPanelForwardedZero(let p1):
        return L10n.tr(key: "Message.AccessoryPanel.Forwarded_zero", p1)
      case .messageActionsPanelDelete:
        return L10n.tr(key: "Message.ActionsPanel.Delete")
      case .messageActionsPanelEmptySelected:
        return L10n.tr(key: "Message.ActionsPanel.EmptySelected")
      case .messageActionsPanelForward:
        return L10n.tr(key: "Message.ActionsPanel.Forward")
      case .messageActionsPanelSelectedCountCountable(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_countable", p1)
      case .messageActionsPanelSelectedCountFew(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_few", p1)
      case .messageActionsPanelSelectedCountMany(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_many", p1)
      case .messageActionsPanelSelectedCountOne(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_one", p1)
      case .messageActionsPanelSelectedCountOther(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_other", p1)
      case .messageActionsPanelSelectedCountTwo(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_two", p1)
      case .messageActionsPanelSelectedCountZero(let p1):
        return L10n.tr(key: "Message.ActionsPanel.SelectedCount_zero", p1)
      case .messageContextDelete:
        return L10n.tr(key: "Message.Context.Delete")
      case .messageContextEdit:
        return L10n.tr(key: "Message.Context.Edit")
      case .messageContextForward:
        return L10n.tr(key: "Message.Context.Forward")
      case .messageContextForwardToCloud:
        return L10n.tr(key: "Message.Context.ForwardToCloud")
      case .messageContextGoto:
        return L10n.tr(key: "Message.Context.Goto")
      case .messageContextPin:
        return L10n.tr(key: "Message.Context.Pin")
      case .messageContextReply:
        return L10n.tr(key: "Message.Context.Reply")
      case .messageContextSaveGif:
        return L10n.tr(key: "Message.Context.SaveGif")
      case .messageContextSelect:
        return L10n.tr(key: "Message.Context.Select")
      case .messageContextConfirmOnlyPin:
        return L10n.tr(key: "Message.Context.Confirm.OnlyPin")
      case .messageContextConfirmPin:
        return L10n.tr(key: "Message.Context.Confirm.Pin")
      case .messageContextCopyMessageLink:
        return L10n.tr(key: "MessageContext.CopyMessageLink")
      case .messagesDeletedMessage:
        return L10n.tr(key: "Messages.DeletedMessage")
      case .messagesForwardHeader:
        return L10n.tr(key: "Messages.ForwardHeader")
      case .messagesUnreadMark:
        return L10n.tr(key: "Messages.UnreadMark")
      case .messagesFileStateFetchingIn1(let p1):
        return L10n.tr(key: "Messages.File.State.FetchingIn_1", p1)
      case .messagesFileStateFetchingOut1(let p1):
        return L10n.tr(key: "Messages.File.State.FetchingOut_1", p1)
      case .messagesFileStateLocal:
        return L10n.tr(key: "Messages.File.State.Local")
      case .messagesFileStateRemote:
        return L10n.tr(key: "Messages.File.State.Remote")
      case .messagesPlaceholderSentMessage:
        return L10n.tr(key: "Messages.Placeholder.SentMessage")
      case .messagesReplyLoadingHeader:
        return L10n.tr(key: "Messages.ReplyLoading.Header")
      case .messagesReplyLoadingLoading:
        return L10n.tr(key: "Messages.ReplyLoading.Loading")
      case .mk62p4JGTitle:
        return L10n.tr(key: "mK6-2p-4JG.title")
      case .modalCancel:
        return L10n.tr(key: "Modal.Cancel")
      case .modalCopyLink:
        return L10n.tr(key: "Modal.CopyLink")
      case .modalOK:
        return L10n.tr(key: "Modal.OK")
      case .modalSend:
        return L10n.tr(key: "Modal.Send")
      case .modalShare:
        return L10n.tr(key: "Modal.Share")
      case .navigationBack:
        return L10n.tr(key: "Navigation.back")
      case .navigationCancel:
        return L10n.tr(key: "Navigation.Cancel")
      case .navigationClose:
        return L10n.tr(key: "Navigation.Close")
      case .navigationDone:
        return L10n.tr(key: "Navigation.Done")
      case .navigationEdit:
        return L10n.tr(key: "Navigation.Edit")
      case .notificationLockedPreview:
        return L10n.tr(key: "Notification.LockedPreview")
      case .notificationSettingsMessagesPreview:
        return L10n.tr(key: "NotificationSettings.MessagesPreview")
      case .notificationSettingsNotificationTone:
        return L10n.tr(key: "NotificationSettings.NotificationTone")
      case .notificationSettingsResetNotifications:
        return L10n.tr(key: "NotificationSettings.ResetNotifications")
      case .notificationSettingsResetNotificationsText:
        return L10n.tr(key: "NotificationSettings.ResetNotificationsText")
      case .notificationSettingsToggleNotifications:
        return L10n.tr(key: "NotificationSettings.ToggleNotifications")
      case .notificationSettingsConfirmReset:
        return L10n.tr(key: "NotificationSettings.Confirm.Reset")
      case .notificationSettingsToneDefault:
        return L10n.tr(key: "NotificationSettings.Tone.Default")
      case .olwNPBQNTitle:
        return L10n.tr(key: "Olw-nP-bQN.title")
      case .oy7WFPoVTitle:
        return L10n.tr(key: "OY7-WF-poV.title")
      case .pa3QIU2kTitle:
        return L10n.tr(key: "pa3-QI-u2k.title")
      case .passcodeAutolock:
        return L10n.tr(key: "Passcode.Autolock")
      case .passcodeChange:
        return L10n.tr(key: "Passcode.Change")
      case .passcodeEnterCurrentPlaceholder:
        return L10n.tr(key: "Passcode.EnterCurrentPlaceholder")
      case .passcodeEnterNewPlaceholder:
        return L10n.tr(key: "Passcode.EnterNewPlaceholder")
      case .passcodeEnterPasscodePlaceholder:
        return L10n.tr(key: "Passcode.EnterPasscodePlaceholder")
      case .passcodeLogoutDescription:
        return L10n.tr(key: "Passcode.LogoutDescription")
      case .passcodeLogoutLinkText:
        return L10n.tr(key: "Passcode.LogoutLinkText")
      case .passcodeNext:
        return L10n.tr(key: "Passcode.Next")
      case .passcodeReEnterPlaceholder:
        return L10n.tr(key: "Passcode.ReEnterPlaceholder")
      case .passcodeTurnOff:
        return L10n.tr(key: "Passcode.TurnOff")
      case .passcodeTurnOn:
        return L10n.tr(key: "Passcode.TurnOn")
      case .passcodeTurnOnDescription:
        return L10n.tr(key: "Passcode.TurnOnDescription")
      case .passcodeAutoLockDisabled:
        return L10n.tr(key: "Passcode.AutoLock.Disabled")
      case .passcodeAutoLockIfAway(let p1):
        return L10n.tr(key: "Passcode.AutoLock.IfAway", p1)
      case .paymentsUnsupported:
        return L10n.tr(key: "Payments.Unsupported")
      case .peerDeletedUser:
        return L10n.tr(key: "Peer.DeletedUser")
      case .peerServiceNotifications:
        return L10n.tr(key: "Peer.ServiceNotifications")
      case .peerActivityChatMultiRecordingAudio(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.RecordingAudio", p1)
      case .peerActivityChatMultiRecordingVideo(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.RecordingVideo", p1)
      case .peerActivityChatMultiSendingAudio(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.SendingAudio", p1)
      case .peerActivityChatMultiSendingFile(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.SendingFile", p1)
      case .peerActivityChatMultiSendingPhoto(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.SendingPhoto", p1)
      case .peerActivityChatMultiSendingVideo(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.SendingVideo", p1)
      case .peerActivityChatMultiTypingText(let p1):
        return L10n.tr(key: "Peer.Activity.Chat.Multi.TypingText", p1)
      case .peerActivityUserRecordingAudio:
        return L10n.tr(key: "Peer.Activity.User.RecordingAudio")
      case .peerActivityUserRecordingVideo:
        return L10n.tr(key: "Peer.Activity.User.RecordingVideo")
      case .peerActivityUserSendingFile:
        return L10n.tr(key: "Peer.Activity.User.SendingFile")
      case .peerActivityUserSendingPhoto:
        return L10n.tr(key: "Peer.Activity.User.SendingPhoto")
      case .peerActivityUserSendingVideo:
        return L10n.tr(key: "Peer.Activity.User.SendingVideo")
      case .peerActivityUserTypingText:
        return L10n.tr(key: "Peer.Activity.User.TypingText")
      case .peerMediaSharedFilesEmptyList:
        return L10n.tr(key: "Peer.Media.SharedFilesEmptyList")
      case .peerMediaSharedLinksEmptyList:
        return L10n.tr(key: "Peer.Media.SharedLinksEmptyList")
      case .peerMediaSharedMediaEmptyList:
        return L10n.tr(key: "Peer.Media.SharedMediaEmptyList")
      case .peerMediaSharedMusicEmptyList:
        return L10n.tr(key: "Peer.Media.SharedMusicEmptyList")
      case .peerStatusChannel:
        return L10n.tr(key: "Peer.Status.channel")
      case .peerStatusGroup:
        return L10n.tr(key: "Peer.Status.group")
      case .peerStatusJustNow:
        return L10n.tr(key: "Peer.Status.justNow")
      case .peerStatusLastMonth:
        return L10n.tr(key: "Peer.Status.lastMonth")
      case .peerStatusLastSeenAt(let p1, let p2):
        return L10n.tr(key: "Peer.Status.LastSeenAt", p1, p2)
      case .peerStatusLastWeek:
        return L10n.tr(key: "Peer.Status.lastWeek")
      case .peerStatusMemberCountable(let p1):
        return L10n.tr(key: "Peer.Status.Member_countable", p1)
      case .peerStatusMemberFew(let p1):
        return L10n.tr(key: "Peer.Status.Member_few", p1)
      case .peerStatusMemberMany(let p1):
        return L10n.tr(key: "Peer.Status.Member_many", p1)
      case .peerStatusMemberOne(let p1):
        return L10n.tr(key: "Peer.Status.Member_one", p1)
      case .peerStatusMemberOther(let p1):
        return L10n.tr(key: "Peer.Status.Member_other", p1)
      case .peerStatusMemberTwo(let p1):
        return L10n.tr(key: "Peer.Status.Member_two", p1)
      case .peerStatusMemberZero(let p1):
        return L10n.tr(key: "Peer.Status.Member_zero", p1)
      case .peerStatusMinAgoCountable(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_countable", p1)
      case .peerStatusMinAgoFew(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_few", p1)
      case .peerStatusMinAgoMany(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_many", p1)
      case .peerStatusMinAgoOne(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_one", p1)
      case .peerStatusMinAgoOther(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_other", p1)
      case .peerStatusMinAgoTwo(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_two", p1)
      case .peerStatusMinAgoZero(let p1):
        return L10n.tr(key: "Peer.Status.minAgo_zero", p1)
      case .peerStatusOnline:
        return L10n.tr(key: "Peer.Status.online")
      case .peerStatusRecently:
        return L10n.tr(key: "Peer.Status.recently")
      case .peerStatusToday:
        return L10n.tr(key: "Peer.Status.Today")
      case .peerStatusYesterday:
        return L10n.tr(key: "Peer.Status.Yesterday")
      case .peerStatusMemberOnlineCountable(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_countable", p1)
      case .peerStatusMemberOnlineFew(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_few", p1)
      case .peerStatusMemberOnlineMany(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_many", p1)
      case .peerStatusMemberOnlineOne(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_one", p1)
      case .peerStatusMemberOnlineOther(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_other", p1)
      case .peerStatusMemberOnlineTwo(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_two", p1)
      case .peerStatusMemberOnlineZero(let p1):
        return L10n.tr(key: "Peer.Status.Member.Online_zero", p1)
      case .peerInfoAbout:
        return L10n.tr(key: "PeerInfo.about")
      case .peerInfoAddContact:
        return L10n.tr(key: "PeerInfo.AddContact")
      case .peerInfoAddMember:
        return L10n.tr(key: "PeerInfo.AddMember")
      case .peerInfoAdminLabel:
        return L10n.tr(key: "PeerInfo.AdminLabel")
      case .peerInfoAdmins:
        return L10n.tr(key: "PeerInfo.Admins")
      case .peerInfoBio:
        return L10n.tr(key: "PeerInfo.bio")
      case .peerInfoBlackList:
        return L10n.tr(key: "PeerInfo.BlackList")
      case .peerInfoBlockUser:
        return L10n.tr(key: "PeerInfo.BlockUser")
      case .peerInfoChannelReported:
        return L10n.tr(key: "PeerInfo.ChannelReported")
      case .peerInfoChannelType:
        return L10n.tr(key: "PeerInfo.ChannelType")
      case .peerInfoConvertToSupergroup:
        return L10n.tr(key: "PeerInfo.ConvertToSupergroup")
      case .peerInfoDeleteAndExit:
        return L10n.tr(key: "PeerInfo.DeleteAndExit")
      case .peerInfoDeleteChannel:
        return L10n.tr(key: "PeerInfo.DeleteChannel")
      case .peerInfoDeleteContact:
        return L10n.tr(key: "PeerInfo.DeleteContact")
      case .peerInfoDeleteSecretChat:
        return L10n.tr(key: "PeerInfo.DeleteSecretChat")
      case .peerInfoEncryptionKey:
        return L10n.tr(key: "PeerInfo.EncryptionKey")
      case .peerInfoGroupsInCommon:
        return L10n.tr(key: "PeerInfo.GroupsInCommon")
      case .peerInfoGroupType:
        return L10n.tr(key: "PeerInfo.GroupType")
      case .peerInfoInfo:
        return L10n.tr(key: "PeerInfo.info")
      case .peerInfoInviteLink:
        return L10n.tr(key: "PeerInfo.InviteLink")
      case .peerInfoLeaveChannel:
        return L10n.tr(key: "PeerInfo.LeaveChannel")
      case .peerInfoMembers:
        return L10n.tr(key: "PeerInfo.Members")
      case .peerInfoMembersHeaderCountable(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_countable", p1)
      case .peerInfoMembersHeaderFew(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_few", p1)
      case .peerInfoMembersHeaderMany(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_many", p1)
      case .peerInfoMembersHeaderOne(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_one", p1)
      case .peerInfoMembersHeaderOther(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_other", p1)
      case .peerInfoMembersHeaderTwo(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_two", p1)
      case .peerInfoMembersHeaderZero(let p1):
        return L10n.tr(key: "PeerInfo.MembersHeader_zero", p1)
      case .peerInfoNotifications:
        return L10n.tr(key: "PeerInfo.Notifications")
      case .peerInfoPhone:
        return L10n.tr(key: "PeerInfo.Phone")
      case .peerInfoPreHistory:
        return L10n.tr(key: "PeerInfo.PreHistory")
      case .peerInfoReport:
        return L10n.tr(key: "PeerInfo.Report")
      case .peerInfoSendMessage:
        return L10n.tr(key: "PeerInfo.SendMessage")
      case .peerInfoSetAboutDescription:
        return L10n.tr(key: "PeerInfo.SetAboutDescription")
      case .peerInfoSetAdmins:
        return L10n.tr(key: "PeerInfo.SetAdmins")
      case .peerInfoSetChannelPhoto:
        return L10n.tr(key: "PeerInfo.SetChannelPhoto")
      case .peerInfoSetGroupPhoto:
        return L10n.tr(key: "PeerInfo.SetGroupPhoto")
      case .peerInfoSetGroupStickersSet:
        return L10n.tr(key: "PeerInfo.SetGroupStickersSet")
      case .peerInfoShareContact:
        return L10n.tr(key: "PeerInfo.ShareContact")
      case .peerInfoSharedMedia:
        return L10n.tr(key: "PeerInfo.SharedMedia")
      case .peerInfoSharelink:
        return L10n.tr(key: "PeerInfo.sharelink")
      case .peerInfoSignMessages:
        return L10n.tr(key: "PeerInfo.SignMessages")
      case .peerInfoStartSecretChat:
        return L10n.tr(key: "PeerInfo.StartSecretChat")
      case .peerInfoUnblockUser:
        return L10n.tr(key: "PeerInfo.UnblockUser")
      case .peerInfoUsername:
        return L10n.tr(key: "PeerInfo.username")
      case .peerInfoAboutPlaceholder:
        return L10n.tr(key: "PeerInfo.About.Placeholder")
      case .peerInfoBotStatusHasAccess:
        return L10n.tr(key: "PeerInfo.BotStatus.HasAccess")
      case .peerInfoBotStatusHasNoAccess:
        return L10n.tr(key: "PeerInfo.BotStatus.HasNoAccess")
      case .peerInfoChannelNamePlaceholder:
        return L10n.tr(key: "PeerInfo.ChannelName.Placeholder")
      case .peerInfoConfirmAddMember(let p1):
        return L10n.tr(key: "PeerInfo.Confirm.AddMember", p1)
      case .peerInfoConfirmAddMembers(let p1):
        return L10n.tr(key: "PeerInfo.Confirm.AddMembers", p1)
      case .peerInfoConfirmDeleteChat(let p1):
        return L10n.tr(key: "PeerInfo.Confirm.DeleteChat", p1)
      case .peerInfoConfirmDeleteContact:
        return L10n.tr(key: "PeerInfo.Confirm.DeleteContact")
      case .peerInfoConfirmLeaveChannel:
        return L10n.tr(key: "PeerInfo.Confirm.LeaveChannel")
      case .peerInfoConfirmLeaveGroup:
        return L10n.tr(key: "PeerInfo.Confirm.LeaveGroup")
      case .peerInfoConfirmRemovePeer(let p1):
        return L10n.tr(key: "PeerInfo.Confirm.RemovePeer", p1)
      case .peerInfoConfirmStartSecretChat(let p1):
        return L10n.tr(key: "PeerInfo.Confirm.StartSecretChat", p1)
      case .peerInfoFirstNamePlaceholder:
        return L10n.tr(key: "PeerInfo.FirstName.Placeholder")
      case .peerInfoGroupNamePlaceholder:
        return L10n.tr(key: "PeerInfo.GroupName.Placeholder")
      case .peerInfoGroupTypePrivate:
        return L10n.tr(key: "PeerInfo.GroupType.Private")
      case .peerInfoGroupTypePublic:
        return L10n.tr(key: "PeerInfo.GroupType.Public")
      case .peerInfoLastNamePlaceholder:
        return L10n.tr(key: "PeerInfo.LastName.Placeholder")
      case .peerInfoPreHistoryHidden:
        return L10n.tr(key: "PeerInfo.PreHistory.Hidden")
      case .peerInfoPreHistoryVisible:
        return L10n.tr(key: "PeerInfo.PreHistory.Visible")
      case .peerInfoSignMessagesDesc:
        return L10n.tr(key: "PeerInfo.SignMessages.Desc")
      case .peerMediaSharedMedia:
        return L10n.tr(key: "PeerMedia.SharedMedia")
      case .peerMediaPopoverSharedAudio:
        return L10n.tr(key: "PeerMedia.Popover.SharedAudio")
      case .peerMediaPopoverSharedFiles:
        return L10n.tr(key: "PeerMedia.Popover.SharedFiles")
      case .peerMediaPopoverSharedLinks:
        return L10n.tr(key: "PeerMedia.Popover.SharedLinks")
      case .peerMediaPopoverSharedMedia:
        return L10n.tr(key: "PeerMedia.Popover.SharedMedia")
      case .preHistorySettingsHeader:
        return L10n.tr(key: "PreHistorySettings.Header")
      case .preHistorySettingsDescriptionHidden:
        return L10n.tr(key: "PreHistorySettings.Description.Hidden")
      case .preHistorySettingsDescriptionVisible:
        return L10n.tr(key: "PreHistorySettings.Description.Visible")
      case .presenceBot:
        return L10n.tr(key: "Presence.bot")
      case .previderSenderCaptionPlaceholder:
        return L10n.tr(key: "PreviderSender.CaptionPlaceholder")
      case .previewSenderCompressFile:
        return L10n.tr(key: "PreviewSender.CompressFile")
      case .privacySettingsActiveSessions:
        return L10n.tr(key: "PrivacySettings.ActiveSessions")
      case .privacySettingsBlockedUsers:
        return L10n.tr(key: "PrivacySettings.BlockedUsers")
      case .privacySettingsGroups:
        return L10n.tr(key: "PrivacySettings.Groups")
      case .privacySettingsLastSeen:
        return L10n.tr(key: "PrivacySettings.LastSeen")
      case .privacySettingsPasscode:
        return L10n.tr(key: "PrivacySettings.Passcode")
      case .privacySettingsPrivacyHeader:
        return L10n.tr(key: "PrivacySettings.PrivacyHeader")
      case .privacySettingsProxyHeader:
        return L10n.tr(key: "PrivacySettings.ProxyHeader")
      case .privacySettingsSecurityHeader:
        return L10n.tr(key: "PrivacySettings.SecurityHeader")
      case .privacySettingsTwoStepVerification:
        return L10n.tr(key: "PrivacySettings.TwoStepVerification")
      case .privacySettingsUseProxy:
        return L10n.tr(key: "PrivacySettings.UseProxy")
      case .privacySettingsVoiceCalls:
        return L10n.tr(key: "PrivacySettings.VoiceCalls")
      case .privacySettingsPeerSelectAddNew:
        return L10n.tr(key: "PrivacySettings.PeerSelect.AddNew")
      case .privacySettingsControllerAddUsers:
        return L10n.tr(key: "PrivacySettingsController.AddUsers")
      case .privacySettingsControllerAlwaysAllow:
        return L10n.tr(key: "PrivacySettingsController.AlwaysAllow")
      case .privacySettingsControllerAlwaysShare:
        return L10n.tr(key: "PrivacySettingsController.AlwaysShare")
      case .privacySettingsControllerAlwaysShareWith:
        return L10n.tr(key: "PrivacySettingsController.AlwaysShareWith")
      case .privacySettingsControllerEverbody:
        return L10n.tr(key: "PrivacySettingsController.Everbody")
      case .privacySettingsControllerGroupDescription:
        return L10n.tr(key: "PrivacySettingsController.GroupDescription")
      case .privacySettingsControllerGroupHeader:
        return L10n.tr(key: "PrivacySettingsController.GroupHeader")
      case .privacySettingsControllerHeader:
        return L10n.tr(key: "PrivacySettingsController.Header")
      case .privacySettingsControllerLastSeenDescription:
        return L10n.tr(key: "PrivacySettingsController.LastSeenDescription")
      case .privacySettingsControllerLastSeenHeader:
        return L10n.tr(key: "PrivacySettingsController.LastSeenHeader")
      case .privacySettingsControllerMyContacts:
        return L10n.tr(key: "PrivacySettingsController.MyContacts")
      case .privacySettingsControllerNeverAllow:
        return L10n.tr(key: "PrivacySettingsController.NeverAllow")
      case .privacySettingsControllerNeverShare:
        return L10n.tr(key: "PrivacySettingsController.NeverShare")
      case .privacySettingsControllerNeverShareWith:
        return L10n.tr(key: "PrivacySettingsController.NeverShareWith")
      case .privacySettingsControllerNobody:
        return L10n.tr(key: "PrivacySettingsController.Nobody")
      case .privacySettingsControllerPeerInfo:
        return L10n.tr(key: "PrivacySettingsController.PeerInfo")
      case .privacySettingsControllerPhoneCallDescription:
        return L10n.tr(key: "PrivacySettingsController.PhoneCallDescription")
      case .privacySettingsControllerPhoneCallHeader:
        return L10n.tr(key: "PrivacySettingsController.PhoneCallHeader")
      case .privacySettingsControllerUserCountCountable(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_countable", p1)
      case .privacySettingsControllerUserCountFew(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_few", p1)
      case .privacySettingsControllerUserCountMany(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_many", p1)
      case .privacySettingsControllerUserCountOne(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_one", p1)
      case .privacySettingsControllerUserCountOther(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_other", p1)
      case .privacySettingsControllerUserCountTwo(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_two", p1)
      case .privacySettingsControllerUserCountZero(let p1):
        return L10n.tr(key: "PrivacySettingsController.UserCount_zero", p1)
      case .proxyForceDisable(let p1):
        return L10n.tr(key: "Proxy.ForceDisable", p1)
      case .proxyForceEnableHeader:
        return L10n.tr(key: "Proxy.ForceEnable.Header")
      case .proxyForceEnableText:
        return L10n.tr(key: "Proxy.ForceEnable.Text")
      case .proxyForceEnableTextIP(let p1):
        return L10n.tr(key: "Proxy.ForceEnable.Text.IP", p1)
      case .proxyForceEnableTextPassword(let p1):
        return L10n.tr(key: "Proxy.ForceEnable.Text.Password", p1)
      case .proxyForceEnableTextPort(let p1):
        return L10n.tr(key: "Proxy.ForceEnable.Text.Port", p1)
      case .proxyForceEnableTextUsername(let p1):
        return L10n.tr(key: "Proxy.ForceEnable.Text.Username", p1)
      case .proxySettingsConnectionHeader:
        return L10n.tr(key: "ProxySettings.ConnectionHeader")
      case .proxySettingsCredentialsHeader:
        return L10n.tr(key: "ProxySettings.CredentialsHeader")
      case .proxySettingsDisabled:
        return L10n.tr(key: "ProxySettings.Disabled")
      case .proxySettingsExportDescription:
        return L10n.tr(key: "ProxySettings.ExportDescription")
      case .proxySettingsExportLink:
        return L10n.tr(key: "ProxySettings.ExportLink")
      case .proxySettingsPassword:
        return L10n.tr(key: "ProxySettings.Password")
      case .proxySettingsPort:
        return L10n.tr(key: "ProxySettings.Port")
      case .proxySettingsProxyNotFound:
        return L10n.tr(key: "ProxySettings.ProxyNotFound")
      case .proxySettingsSave:
        return L10n.tr(key: "ProxySettings.Save")
      case .proxySettingsServer:
        return L10n.tr(key: "ProxySettings.Server")
      case .proxySettingsShare:
        return L10n.tr(key: "ProxySettings.Share")
      case .proxySettingsSocks5:
        return L10n.tr(key: "ProxySettings.Socks5")
      case .proxySettingsUsername:
        return L10n.tr(key: "ProxySettings.Username")
      case .quickLookPreview:
        return L10n.tr(key: "QuickLook.Preview")
      case .quickSwitcherDescription:
        return L10n.tr(key: "QuickSwitcher.Description")
      case .quickSwitcherPopular:
        return L10n.tr(key: "QuickSwitcher.Popular")
      case .quickSwitcherRecently:
        return L10n.tr(key: "QuickSwitcher.Recently")
      case .qvCM9Y7gTitle:
        return L10n.tr(key: "QvC-M9-y7g.title")
      case .r4oN2Eq4Title:
        return L10n.tr(key: "R4o-n2-Eq4.title")
      case .rbDRhWINTitle:
        return L10n.tr(key: "rbD-Rh-wIN.title")
      case .recentCallsEmpty:
        return L10n.tr(key: "RecentCalls.Empty")
      case .recentSessionsRevoke:
        return L10n.tr(key: "RecentSessions.Revoke")
      case .recentSessionsConfirmRevoke:
        return L10n.tr(key: "RecentSessions.Confirm.Revoke")
      case .recentSessionsConfirmTerminateOthers:
        return L10n.tr(key: "RecentSessions.Confirm.TerminateOthers")
      case .reportReasonPorno:
        return L10n.tr(key: "ReportReason.Porno")
      case .reportReasonSpam:
        return L10n.tr(key: "ReportReason.Spam")
      case .reportReasonViolence:
        return L10n.tr(key: "ReportReason.Violence")
      case .rgMF4YcnTitle:
        return L10n.tr(key: "rgM-f4-ycn.title")
      case .ruw6mB2mTitle:
        return L10n.tr(key: "Ruw-6m-B2m.title")
      case .searchSeparatorChatsAndContacts:
        return L10n.tr(key: "Search.Separator.ChatsAndContacts")
      case .searchSeparatorGlobalPeers:
        return L10n.tr(key: "Search.Separator.GlobalPeers")
      case .searchSeparatorMessages:
        return L10n.tr(key: "Search.Separator.Messages")
      case .searchSeparatorPopular:
        return L10n.tr(key: "Search.Separator.Popular")
      case .searchSeparatorRecent:
        return L10n.tr(key: "Search.Separator.Recent")
      case .searchFieldSearch:
        return L10n.tr(key: "SearchField.Search")
      case .secretTimerOff:
        return L10n.tr(key: "SecretTimer.Off")
      case .separatorClear:
        return L10n.tr(key: "Separator.Clear")
      case .separatorShowLess:
        return L10n.tr(key: "Separator.ShowLess")
      case .separatorShowMore:
        return L10n.tr(key: "Separator.ShowMore")
      case .serviceMessageDesturctingPhoto(let p1):
        return L10n.tr(key: "ServiceMessage.DesturctingPhoto", p1)
      case .serviceMessageDesturctingVideo(let p1):
        return L10n.tr(key: "ServiceMessage.DesturctingVideo", p1)
      case .serviceMessageExpiredFile:
        return L10n.tr(key: "ServiceMessage.ExpiredFile")
      case .serviceMessageExpiredPhoto:
        return L10n.tr(key: "ServiceMessage.ExpiredPhoto")
      case .serviceMessageExpiredVideo:
        return L10n.tr(key: "ServiceMessage.ExpiredVideo")
      case .serviceMessageDesturctingPhotoYou(let p1):
        return L10n.tr(key: "ServiceMessage.DesturctingPhoto.You", p1)
      case .serviceMessageDesturctingVideoYou(let p1):
        return L10n.tr(key: "ServiceMessage.DesturctingVideo.You", p1)
      case .sessionsActiveSessionsHeader:
        return L10n.tr(key: "Sessions.ActiveSessionsHeader")
      case .sessionsCurrentSessionHeader:
        return L10n.tr(key: "Sessions.CurrentSessionHeader")
      case .sessionsTerminateDescription:
        return L10n.tr(key: "Sessions.TerminateDescription")
      case .sessionsTerminateOthers:
        return L10n.tr(key: "Sessions.TerminateOthers")
      case .shareLinkCopied:
        return L10n.tr(key: "Share.Link.Copied")
      case .shareExtensionCancel:
        return L10n.tr(key: "ShareExtension.Cancel")
      case .shareExtensionSearch:
        return L10n.tr(key: "ShareExtension.Search")
      case .shareExtensionShare:
        return L10n.tr(key: "ShareExtension.Share")
      case .shareExtensionPasscodeNext:
        return L10n.tr(key: "ShareExtension.Passcode.Next")
      case .shareExtensionPasscodePlaceholder:
        return L10n.tr(key: "ShareExtension.Passcode.Placeholder")
      case .shareExtensionUnauthorizedDescription:
        return L10n.tr(key: "ShareExtension.Unauthorized.Description")
      case .shareExtensionUnauthorizedOK:
        return L10n.tr(key: "ShareExtension.Unauthorized.OK")
      case .shareModalSearchPlaceholder:
        return L10n.tr(key: "ShareModal.Search.Placeholder")
      case .sidebarAvalability:
        return L10n.tr(key: "Sidebar.Avalability")
      case .stickerPackAdd(let p1):
        return L10n.tr(key: "StickerPack.Add", p1)
      case .stickerPackRemove(let p1):
        return L10n.tr(key: "StickerPack.Remove", p1)
      case .stickersGroupStickers:
        return L10n.tr(key: "Stickers.GroupStickers")
      case .stickersRecent:
        return L10n.tr(key: "Stickers.Recent")
      case .stickersSetCount(let p1):
        return L10n.tr(key: "Stickers.Set.Count", p1)
      case .stickerSetRemove:
        return L10n.tr(key: "StickerSet.Remove")
      case .storageClear(let p1):
        return L10n.tr(key: "Storage.Clear", p1)
      case .storageClearAudio:
        return L10n.tr(key: "Storage.Clear.Audio")
      case .storageClearDocuments:
        return L10n.tr(key: "Storage.Clear.Documents")
      case .storageClearPhotos:
        return L10n.tr(key: "Storage.Clear.Photos")
      case .storageClearVideos:
        return L10n.tr(key: "Storage.Clear.Videos")
      case .storageUsageCalculating:
        return L10n.tr(key: "StorageUsage.Calculating")
      case .storageUsageChatsHeader:
        return L10n.tr(key: "StorageUsage.ChatsHeader")
      case .storageUsageKeepMedia:
        return L10n.tr(key: "StorageUsage.KeepMedia")
      case .storageUsageKeepMediaDescription:
        return L10n.tr(key: "StorageUsage.KeepMedia.Description")
      case .suggestLocalizationHeader:
        return L10n.tr(key: "Suggest.Localization.Header")
      case .suggestLocalizationOther:
        return L10n.tr(key: "Suggest.Localization.Other")
      case .supergroupConvertButton:
        return L10n.tr(key: "Supergroup.Convert.Button")
      case .supergroupConvertDescription:
        return L10n.tr(key: "Supergroup.Convert.Description")
      case .supergroupConvertUndone:
        return L10n.tr(key: "Supergroup.Convert.Undone")
      case .supergroupDeleteRestrictionBanUser:
        return L10n.tr(key: "Supergroup.DeleteRestriction.BanUser")
      case .supergroupDeleteRestrictionDeleteAllMessages:
        return L10n.tr(key: "Supergroup.DeleteRestriction.DeleteAllMessages")
      case .supergroupDeleteRestrictionDeleteMessage:
        return L10n.tr(key: "Supergroup.DeleteRestriction.DeleteMessage")
      case .supergroupDeleteRestrictionReportSpam:
        return L10n.tr(key: "Supergroup.DeleteRestriction.ReportSpam")
      case .sZhCtGQSTitle:
        return L10n.tr(key: "sZh-ct-GQS.title")
      case .td7AD5loTitle:
        return L10n.tr(key: "Td7-aD-5lo.title")
      case .telegramAppearanceViewController:
        return L10n.tr(key: "Telegram.AppearanceViewController")
      case .telegramArchivedStickerPacksController:
        return L10n.tr(key: "Telegram.ArchivedStickerPacksController")
      case .telegramBioViewController:
        return L10n.tr(key: "Telegram.BioViewController")
      case .telegramBlockedPeersViewController:
        return L10n.tr(key: "Telegram.BlockedPeersViewController")
      case .telegramChannelAdminsViewController:
        return L10n.tr(key: "Telegram.ChannelAdminsViewController")
      case .telegramChannelBlacklistViewController:
        return L10n.tr(key: "Telegram.ChannelBlacklistViewController")
      case .telegramChannelEventLogController:
        return L10n.tr(key: "Telegram.ChannelEventLogController")
      case .telegramChannelIntroViewController:
        return L10n.tr(key: "Telegram.ChannelIntroViewController")
      case .telegramChannelMembersViewController:
        return L10n.tr(key: "Telegram.ChannelMembersViewController")
      case .telegramChannelVisibilityController:
        return L10n.tr(key: "Telegram.ChannelVisibilityController")
      case .telegramConvertGroupViewController:
        return L10n.tr(key: "Telegram.ConvertGroupViewController")
      case .telegramEmptyChatViewController:
        return L10n.tr(key: "Telegram.EmptyChatViewController")
      case .telegramFeaturedStickerPacksController:
        return L10n.tr(key: "Telegram.FeaturedStickerPacksController")
      case .telegramGeneralSettingsViewController:
        return L10n.tr(key: "Telegram.GeneralSettingsViewController")
      case .telegramGroupAdminsController:
        return L10n.tr(key: "Telegram.GroupAdminsController")
      case .telegramGroupsInCommonViewController:
        return L10n.tr(key: "Telegram.GroupsInCommonViewController")
      case .telegramGroupStickerSetController:
        return L10n.tr(key: "Telegram.GroupStickerSetController")
      case .telegramInstalledStickerPacksController:
        return L10n.tr(key: "Telegram.InstalledStickerPacksController")
      case .telegramLanguageViewController:
        return L10n.tr(key: "Telegram.LanguageViewController")
      case .telegramLayoutAccountController:
        return L10n.tr(key: "Telegram.LayoutAccountController")
      case .telegramLayoutRecentCallsViewController:
        return L10n.tr(key: "Telegram.LayoutRecentCallsViewController")
      case .telegramLinkInvationController:
        return L10n.tr(key: "Telegram.LinkInvationController")
      case .telegramMainViewController:
        return L10n.tr(key: "Telegram.MainViewController")
      case .telegramNotificationSettingsViewController:
        return L10n.tr(key: "Telegram.NotificationSettingsViewController")
      case .telegramPasscodeSettingsViewController:
        return L10n.tr(key: "Telegram.PasscodeSettingsViewController")
      case .telegramPeerInfoController:
        return L10n.tr(key: "Telegram.PeerInfoController")
      case .telegramPreHistorySettingsController:
        return L10n.tr(key: "Telegram.PreHistorySettingsController")
      case .telegramPrivacyAndSecurityViewController:
        return L10n.tr(key: "Telegram.PrivacyAndSecurityViewController")
      case .telegramProxySettingsViewController:
        return L10n.tr(key: "Telegram.ProxySettingsViewController")
      case .telegramRecentSessionsController:
        return L10n.tr(key: "Telegram.RecentSessionsController")
      case .telegramSecretChatKeyViewController:
        return L10n.tr(key: "Telegram.SecretChatKeyViewController")
      case .telegramSelectPeersController:
        return L10n.tr(key: "Telegram.SelectPeersController")
      case .telegramStorageUsageController:
        return L10n.tr(key: "Telegram.StorageUsageController")
      case .telegramUsernameSettingsViewController:
        return L10n.tr(key: "Telegram.UsernameSettingsViewController")
      case .textCopy:
        return L10n.tr(key: "Text.Copy")
      case .textViewTransformBold:
        return L10n.tr(key: "TextView.Transform.Bold")
      case .textViewTransformCode:
        return L10n.tr(key: "TextView.Transform.Code")
      case .textViewTransformItalic:
        return L10n.tr(key: "TextView.Transform.Italic")
      case .timeAt:
        return L10n.tr(key: "Time.at")
      case .timeLastSeen:
        return L10n.tr(key: "Time.last_seen")
      case .timeToday:
        return L10n.tr(key: "Time.today")
      case .timeYesterday:
        return L10n.tr(key: "Time.yesterday")
      case .timerDaysCountable(let p1):
        return L10n.tr(key: "Timer.Days_countable", p1)
      case .timerDaysFew(let p1):
        return L10n.tr(key: "Timer.Days_few", p1)
      case .timerDaysMany(let p1):
        return L10n.tr(key: "Timer.Days_many", p1)
      case .timerDaysOne(let p1):
        return L10n.tr(key: "Timer.Days_one", p1)
      case .timerDaysOther(let p1):
        return L10n.tr(key: "Timer.Days_other", p1)
      case .timerDaysTwo(let p1):
        return L10n.tr(key: "Timer.Days_two", p1)
      case .timerDaysZero(let p1):
        return L10n.tr(key: "Timer.Days_zero", p1)
      case .timerForever:
        return L10n.tr(key: "Timer.Forever")
      case .timerHoursCountable(let p1):
        return L10n.tr(key: "Timer.Hours_countable", p1)
      case .timerHoursFew(let p1):
        return L10n.tr(key: "Timer.Hours_few", p1)
      case .timerHoursMany(let p1):
        return L10n.tr(key: "Timer.Hours_many", p1)
      case .timerHoursOne(let p1):
        return L10n.tr(key: "Timer.Hours_one", p1)
      case .timerHoursOther(let p1):
        return L10n.tr(key: "Timer.Hours_other", p1)
      case .timerHoursTwo(let p1):
        return L10n.tr(key: "Timer.Hours_two", p1)
      case .timerHoursZero(let p1):
        return L10n.tr(key: "Timer.Hours_zero", p1)
      case .timerMinutesCountable(let p1):
        return L10n.tr(key: "Timer.Minutes_countable", p1)
      case .timerMinutesFew(let p1):
        return L10n.tr(key: "Timer.Minutes_few", p1)
      case .timerMinutesMany(let p1):
        return L10n.tr(key: "Timer.Minutes_many", p1)
      case .timerMinutesOne(let p1):
        return L10n.tr(key: "Timer.Minutes_one", p1)
      case .timerMinutesOther(let p1):
        return L10n.tr(key: "Timer.Minutes_other", p1)
      case .timerMinutesTwo(let p1):
        return L10n.tr(key: "Timer.Minutes_two", p1)
      case .timerMinutesZero(let p1):
        return L10n.tr(key: "Timer.Minutes_zero", p1)
      case .timerMonthsCountable(let p1):
        return L10n.tr(key: "Timer.Months_countable", p1)
      case .timerMonthsFew(let p1):
        return L10n.tr(key: "Timer.Months_few", p1)
      case .timerMonthsMany(let p1):
        return L10n.tr(key: "Timer.Months_many", p1)
      case .timerMonthsOne(let p1):
        return L10n.tr(key: "Timer.Months_one", p1)
      case .timerMonthsOther(let p1):
        return L10n.tr(key: "Timer.Months_other", p1)
      case .timerMonthsTwo(let p1):
        return L10n.tr(key: "Timer.Months_two", p1)
      case .timerMonthsZero(let p1):
        return L10n.tr(key: "Timer.Months_zero", p1)
      case .timerSecondsCountable(let p1):
        return L10n.tr(key: "Timer.Seconds_countable", p1)
      case .timerSecondsFew(let p1):
        return L10n.tr(key: "Timer.Seconds_few", p1)
      case .timerSecondsMany(let p1):
        return L10n.tr(key: "Timer.Seconds_many", p1)
      case .timerSecondsOne(let p1):
        return L10n.tr(key: "Timer.Seconds_one", p1)
      case .timerSecondsOther(let p1):
        return L10n.tr(key: "Timer.Seconds_other", p1)
      case .timerSecondsTwo(let p1):
        return L10n.tr(key: "Timer.Seconds_two", p1)
      case .timerSecondsZero(let p1):
        return L10n.tr(key: "Timer.Seconds_zero", p1)
      case .timerWeeksCountable(let p1):
        return L10n.tr(key: "Timer.Weeks_countable", p1)
      case .timerWeeksFew(let p1):
        return L10n.tr(key: "Timer.Weeks_few", p1)
      case .timerWeeksMany(let p1):
        return L10n.tr(key: "Timer.Weeks_many", p1)
      case .timerWeeksOne(let p1):
        return L10n.tr(key: "Timer.Weeks_one", p1)
      case .timerWeeksOther(let p1):
        return L10n.tr(key: "Timer.Weeks_other", p1)
      case .timerWeeksTwo(let p1):
        return L10n.tr(key: "Timer.Weeks_two", p1)
      case .timerWeeksZero(let p1):
        return L10n.tr(key: "Timer.Weeks_zero", p1)
      case .timerYearsCountable(let p1):
        return L10n.tr(key: "Timer.Years_countable", p1)
      case .timerYearsFew(let p1):
        return L10n.tr(key: "Timer.Years_few", p1)
      case .timerYearsMany(let p1):
        return L10n.tr(key: "Timer.Years_many", p1)
      case .timerYearsOne(let p1):
        return L10n.tr(key: "Timer.Years_one", p1)
      case .timerYearsOther(let p1):
        return L10n.tr(key: "Timer.Years_other", p1)
      case .timerYearsTwo(let p1):
        return L10n.tr(key: "Timer.Years_two", p1)
      case .timerYearsZero(let p1):
        return L10n.tr(key: "Timer.Years_zero", p1)
      case .tRrPd1PSTitle:
        return L10n.tr(key: "tRr-pd-1PS.title")
      case .uezBsLqGTitle:
        return L10n.tr(key: "UEZ-Bs-lqG.title")
      case .uQyDDJDrTitle:
        return L10n.tr(key: "uQy-DD-JDr.title")
      case .uRlIYUnGTitle:
        return L10n.tr(key: "uRl-iY-unG.title")
      case .usernameSettingsAvailable(let p1):
        return L10n.tr(key: "UsernameSettings.available", p1)
      case .usernameSettingsChangeDescription:
        return L10n.tr(key: "UsernameSettings.ChangeDescription")
      case .usernameSettingsDone:
        return L10n.tr(key: "UsernameSettings.Done")
      case .usernameSettingsInputPlaceholder:
        return L10n.tr(key: "UsernameSettings.InputPlaceholder")
      case .vdrFpXzOTitle:
        return L10n.tr(key: "Vdr-fp-XzO.title")
      case .vmV6d7jITitle:
        return L10n.tr(key: "vmV-6d-7jI.title")
      case .w486f4DlTitle:
        return L10n.tr(key: "W48-6f-4Dl.title")
      case .weekdayShortFriday:
        return L10n.tr(key: "Weekday.ShortFriday")
      case .weekdayShortMonday:
        return L10n.tr(key: "Weekday.ShortMonday")
      case .weekdayShortSaturday:
        return L10n.tr(key: "Weekday.ShortSaturday")
      case .weekdayShortSunday:
        return L10n.tr(key: "Weekday.ShortSunday")
      case .weekdayShortThursday:
        return L10n.tr(key: "Weekday.ShortThursday")
      case .weekdayShortTuesday:
        return L10n.tr(key: "Weekday.ShortTuesday")
      case .weekdayShortWednesday:
        return L10n.tr(key: "Weekday.ShortWednesday")
      case .weT3VZwkTitle:
        return L10n.tr(key: "WeT-3V-zwk.title")
      case .x3vGGIWUTitle:
        return L10n.tr(key: "x3v-GG-iWU.title")
      case .z6FFW3nzTitle:
        return L10n.tr(key: "z6F-FW-3nz.title")
      case ._NS138Title:
        return L10n.tr(key: "_NS:138.title")
      case ._NS70Title:
        return L10n.tr(key: "_NS:70.title")
      case ._NS88Title:
        return L10n.tr(key: "_NS:88.title")
    }
  }

    private static func tr(key: String, _ args: CVarArg...) -> String {
        return translate(key: key, args)
    }
}

func tr(_ key: L10n) -> String {
  return key.string
}

private final class BundleToken {}
