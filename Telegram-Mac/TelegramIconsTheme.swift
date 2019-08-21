final class TelegramIconsTheme {
  private var cached:[String: CGImage] = [:]

  var dialogMuteImage: CGImage {
      if let image = cached["dialogMuteImage"] {
          return image
      } else {
          let image = _dialogMuteImage()
          cached["(dialogMuteImage)"] = image
          return image
      }
  }
  var dialogMuteImageSelected: CGImage {
      if let image = cached["dialogMuteImageSelected"] {
          return image
      } else {
          let image = _dialogMuteImageSelected()
          cached["(dialogMuteImageSelected)"] = image
          return image
      }
  }
  var outgoingMessageImage: CGImage {
      if let image = cached["outgoingMessageImage"] {
          return image
      } else {
          let image = _outgoingMessageImage()
          cached["(outgoingMessageImage)"] = image
          return image
      }
  }
  var readMessageImage: CGImage {
      if let image = cached["readMessageImage"] {
          return image
      } else {
          let image = _readMessageImage()
          cached["(readMessageImage)"] = image
          return image
      }
  }
  var outgoingMessageImageSelected: CGImage {
      if let image = cached["outgoingMessageImageSelected"] {
          return image
      } else {
          let image = _outgoingMessageImageSelected()
          cached["(outgoingMessageImageSelected)"] = image
          return image
      }
  }
  var readMessageImageSelected: CGImage {
      if let image = cached["readMessageImageSelected"] {
          return image
      } else {
          let image = _readMessageImageSelected()
          cached["(readMessageImageSelected)"] = image
          return image
      }
  }
  var sendingImage: CGImage {
      if let image = cached["sendingImage"] {
          return image
      } else {
          let image = _sendingImage()
          cached["(sendingImage)"] = image
          return image
      }
  }
  var sendingImageSelected: CGImage {
      if let image = cached["sendingImageSelected"] {
          return image
      } else {
          let image = _sendingImageSelected()
          cached["(sendingImageSelected)"] = image
          return image
      }
  }
  var secretImage: CGImage {
      if let image = cached["secretImage"] {
          return image
      } else {
          let image = _secretImage()
          cached["(secretImage)"] = image
          return image
      }
  }
  var secretImageSelected: CGImage {
      if let image = cached["secretImageSelected"] {
          return image
      } else {
          let image = _secretImageSelected()
          cached["(secretImageSelected)"] = image
          return image
      }
  }
  var pinnedImage: CGImage {
      if let image = cached["pinnedImage"] {
          return image
      } else {
          let image = _pinnedImage()
          cached["(pinnedImage)"] = image
          return image
      }
  }
  var pinnedImageSelected: CGImage {
      if let image = cached["pinnedImageSelected"] {
          return image
      } else {
          let image = _pinnedImageSelected()
          cached["(pinnedImageSelected)"] = image
          return image
      }
  }
  var verifiedImage: CGImage {
      if let image = cached["verifiedImage"] {
          return image
      } else {
          let image = _verifiedImage()
          cached["(verifiedImage)"] = image
          return image
      }
  }
  var verifiedImageSelected: CGImage {
      if let image = cached["verifiedImageSelected"] {
          return image
      } else {
          let image = _verifiedImageSelected()
          cached["(verifiedImageSelected)"] = image
          return image
      }
  }
  var errorImage: CGImage {
      if let image = cached["errorImage"] {
          return image
      } else {
          let image = _errorImage()
          cached["(errorImage)"] = image
          return image
      }
  }
  var errorImageSelected: CGImage {
      if let image = cached["errorImageSelected"] {
          return image
      } else {
          let image = _errorImageSelected()
          cached["(errorImageSelected)"] = image
          return image
      }
  }
  var chatSearch: CGImage {
      if let image = cached["chatSearch"] {
          return image
      } else {
          let image = _chatSearch()
          cached["(chatSearch)"] = image
          return image
      }
  }
  var chatCall: CGImage {
      if let image = cached["chatCall"] {
          return image
      } else {
          let image = _chatCall()
          cached["(chatCall)"] = image
          return image
      }
  }
  var chatActions: CGImage {
      if let image = cached["chatActions"] {
          return image
      } else {
          let image = _chatActions()
          cached["(chatActions)"] = image
          return image
      }
  }
  var chatFailedCall_incoming: CGImage {
      if let image = cached["chatFailedCall_incoming"] {
          return image
      } else {
          let image = _chatFailedCall_incoming()
          cached["(chatFailedCall_incoming)"] = image
          return image
      }
  }
  var chatFailedCall_outgoing: CGImage {
      if let image = cached["chatFailedCall_outgoing"] {
          return image
      } else {
          let image = _chatFailedCall_outgoing()
          cached["(chatFailedCall_outgoing)"] = image
          return image
      }
  }
  var chatCall_incoming: CGImage {
      if let image = cached["chatCall_incoming"] {
          return image
      } else {
          let image = _chatCall_incoming()
          cached["(chatCall_incoming)"] = image
          return image
      }
  }
  var chatCall_outgoing: CGImage {
      if let image = cached["chatCall_outgoing"] {
          return image
      } else {
          let image = _chatCall_outgoing()
          cached["(chatCall_outgoing)"] = image
          return image
      }
  }
  var chatFailedCallBubble_incoming: CGImage {
      if let image = cached["chatFailedCallBubble_incoming"] {
          return image
      } else {
          let image = _chatFailedCallBubble_incoming()
          cached["(chatFailedCallBubble_incoming)"] = image
          return image
      }
  }
  var chatFailedCallBubble_outgoing: CGImage {
      if let image = cached["chatFailedCallBubble_outgoing"] {
          return image
      } else {
          let image = _chatFailedCallBubble_outgoing()
          cached["(chatFailedCallBubble_outgoing)"] = image
          return image
      }
  }
  var chatCallBubble_incoming: CGImage {
      if let image = cached["chatCallBubble_incoming"] {
          return image
      } else {
          let image = _chatCallBubble_incoming()
          cached["(chatCallBubble_incoming)"] = image
          return image
      }
  }
  var chatCallBubble_outgoing: CGImage {
      if let image = cached["chatCallBubble_outgoing"] {
          return image
      } else {
          let image = _chatCallBubble_outgoing()
          cached["(chatCallBubble_outgoing)"] = image
          return image
      }
  }
  var chatFallbackCall: CGImage {
      if let image = cached["chatFallbackCall"] {
          return image
      } else {
          let image = _chatFallbackCall()
          cached["(chatFallbackCall)"] = image
          return image
      }
  }
  var chatFallbackCallBubble_incoming: CGImage {
      if let image = cached["chatFallbackCallBubble_incoming"] {
          return image
      } else {
          let image = _chatFallbackCallBubble_incoming()
          cached["(chatFallbackCallBubble_incoming)"] = image
          return image
      }
  }
  var chatFallbackCallBubble_outgoing: CGImage {
      if let image = cached["chatFallbackCallBubble_outgoing"] {
          return image
      } else {
          let image = _chatFallbackCallBubble_outgoing()
          cached["(chatFallbackCallBubble_outgoing)"] = image
          return image
      }
  }
  var chatToggleSelected: CGImage {
      if let image = cached["chatToggleSelected"] {
          return image
      } else {
          let image = _chatToggleSelected()
          cached["(chatToggleSelected)"] = image
          return image
      }
  }
  var chatToggleUnselected: CGImage {
      if let image = cached["chatToggleUnselected"] {
          return image
      } else {
          let image = _chatToggleUnselected()
          cached["(chatToggleUnselected)"] = image
          return image
      }
  }
  var chatShare: CGImage {
      if let image = cached["chatShare"] {
          return image
      } else {
          let image = _chatShare()
          cached["(chatShare)"] = image
          return image
      }
  }
  var chatMusicPlay: CGImage {
      if let image = cached["chatMusicPlay"] {
          return image
      } else {
          let image = _chatMusicPlay()
          cached["(chatMusicPlay)"] = image
          return image
      }
  }
  var chatMusicPlayBubble_incoming: CGImage {
      if let image = cached["chatMusicPlayBubble_incoming"] {
          return image
      } else {
          let image = _chatMusicPlayBubble_incoming()
          cached["(chatMusicPlayBubble_incoming)"] = image
          return image
      }
  }
  var chatMusicPlayBubble_outgoing: CGImage {
      if let image = cached["chatMusicPlayBubble_outgoing"] {
          return image
      } else {
          let image = _chatMusicPlayBubble_outgoing()
          cached["(chatMusicPlayBubble_outgoing)"] = image
          return image
      }
  }
  var chatMusicPause: CGImage {
      if let image = cached["chatMusicPause"] {
          return image
      } else {
          let image = _chatMusicPause()
          cached["(chatMusicPause)"] = image
          return image
      }
  }
  var chatMusicPauseBubble_incoming: CGImage {
      if let image = cached["chatMusicPauseBubble_incoming"] {
          return image
      } else {
          let image = _chatMusicPauseBubble_incoming()
          cached["(chatMusicPauseBubble_incoming)"] = image
          return image
      }
  }
  var chatMusicPauseBubble_outgoing: CGImage {
      if let image = cached["chatMusicPauseBubble_outgoing"] {
          return image
      } else {
          let image = _chatMusicPauseBubble_outgoing()
          cached["(chatMusicPauseBubble_outgoing)"] = image
          return image
      }
  }
  var composeNewChat: CGImage {
      if let image = cached["composeNewChat"] {
          return image
      } else {
          let image = _composeNewChat()
          cached["(composeNewChat)"] = image
          return image
      }
  }
  var composeNewChatActive: CGImage {
      if let image = cached["composeNewChatActive"] {
          return image
      } else {
          let image = _composeNewChatActive()
          cached["(composeNewChatActive)"] = image
          return image
      }
  }
  var composeNewGroup: CGImage {
      if let image = cached["composeNewGroup"] {
          return image
      } else {
          let image = _composeNewGroup()
          cached["(composeNewGroup)"] = image
          return image
      }
  }
  var composeNewSecretChat: CGImage {
      if let image = cached["composeNewSecretChat"] {
          return image
      } else {
          let image = _composeNewSecretChat()
          cached["(composeNewSecretChat)"] = image
          return image
      }
  }
  var composeNewChannel: CGImage {
      if let image = cached["composeNewChannel"] {
          return image
      } else {
          let image = _composeNewChannel()
          cached["(composeNewChannel)"] = image
          return image
      }
  }
  var contactsNewContact: CGImage {
      if let image = cached["contactsNewContact"] {
          return image
      } else {
          let image = _contactsNewContact()
          cached["(contactsNewContact)"] = image
          return image
      }
  }
  var chatReadMarkInBubble1_incoming: CGImage {
      if let image = cached["chatReadMarkInBubble1_incoming"] {
          return image
      } else {
          let image = _chatReadMarkInBubble1_incoming()
          cached["(chatReadMarkInBubble1_incoming)"] = image
          return image
      }
  }
  var chatReadMarkInBubble2_incoming: CGImage {
      if let image = cached["chatReadMarkInBubble2_incoming"] {
          return image
      } else {
          let image = _chatReadMarkInBubble2_incoming()
          cached["(chatReadMarkInBubble2_incoming)"] = image
          return image
      }
  }
  var chatReadMarkInBubble1_outgoing: CGImage {
      if let image = cached["chatReadMarkInBubble1_outgoing"] {
          return image
      } else {
          let image = _chatReadMarkInBubble1_outgoing()
          cached["(chatReadMarkInBubble1_outgoing)"] = image
          return image
      }
  }
  var chatReadMarkInBubble2_outgoing: CGImage {
      if let image = cached["chatReadMarkInBubble2_outgoing"] {
          return image
      } else {
          let image = _chatReadMarkInBubble2_outgoing()
          cached["(chatReadMarkInBubble2_outgoing)"] = image
          return image
      }
  }
  var chatReadMarkOutBubble1: CGImage {
      if let image = cached["chatReadMarkOutBubble1"] {
          return image
      } else {
          let image = _chatReadMarkOutBubble1()
          cached["(chatReadMarkOutBubble1)"] = image
          return image
      }
  }
  var chatReadMarkOutBubble2: CGImage {
      if let image = cached["chatReadMarkOutBubble2"] {
          return image
      } else {
          let image = _chatReadMarkOutBubble2()
          cached["(chatReadMarkOutBubble2)"] = image
          return image
      }
  }
  var chatReadMarkOverlayBubble1: CGImage {
      if let image = cached["chatReadMarkOverlayBubble1"] {
          return image
      } else {
          let image = _chatReadMarkOverlayBubble1()
          cached["(chatReadMarkOverlayBubble1)"] = image
          return image
      }
  }
  var chatReadMarkOverlayBubble2: CGImage {
      if let image = cached["chatReadMarkOverlayBubble2"] {
          return image
      } else {
          let image = _chatReadMarkOverlayBubble2()
          cached["(chatReadMarkOverlayBubble2)"] = image
          return image
      }
  }
  var sentFailed: CGImage {
      if let image = cached["sentFailed"] {
          return image
      } else {
          let image = _sentFailed()
          cached["(sentFailed)"] = image
          return image
      }
  }
  var chatChannelViewsInBubble_incoming: CGImage {
      if let image = cached["chatChannelViewsInBubble_incoming"] {
          return image
      } else {
          let image = _chatChannelViewsInBubble_incoming()
          cached["(chatChannelViewsInBubble_incoming)"] = image
          return image
      }
  }
  var chatChannelViewsInBubble_outgoing: CGImage {
      if let image = cached["chatChannelViewsInBubble_outgoing"] {
          return image
      } else {
          let image = _chatChannelViewsInBubble_outgoing()
          cached["(chatChannelViewsInBubble_outgoing)"] = image
          return image
      }
  }
  var chatChannelViewsOutBubble: CGImage {
      if let image = cached["chatChannelViewsOutBubble"] {
          return image
      } else {
          let image = _chatChannelViewsOutBubble()
          cached["(chatChannelViewsOutBubble)"] = image
          return image
      }
  }
  var chatChannelViewsOverlayBubble: CGImage {
      if let image = cached["chatChannelViewsOverlayBubble"] {
          return image
      } else {
          let image = _chatChannelViewsOverlayBubble()
          cached["(chatChannelViewsOverlayBubble)"] = image
          return image
      }
  }
  var chatNavigationBack: CGImage {
      if let image = cached["chatNavigationBack"] {
          return image
      } else {
          let image = _chatNavigationBack()
          cached["(chatNavigationBack)"] = image
          return image
      }
  }
  var peerInfoAddMember: CGImage {
      if let image = cached["peerInfoAddMember"] {
          return image
      } else {
          let image = _peerInfoAddMember()
          cached["(peerInfoAddMember)"] = image
          return image
      }
  }
  var chatSearchUp: CGImage {
      if let image = cached["chatSearchUp"] {
          return image
      } else {
          let image = _chatSearchUp()
          cached["(chatSearchUp)"] = image
          return image
      }
  }
  var chatSearchUpDisabled: CGImage {
      if let image = cached["chatSearchUpDisabled"] {
          return image
      } else {
          let image = _chatSearchUpDisabled()
          cached["(chatSearchUpDisabled)"] = image
          return image
      }
  }
  var chatSearchDown: CGImage {
      if let image = cached["chatSearchDown"] {
          return image
      } else {
          let image = _chatSearchDown()
          cached["(chatSearchDown)"] = image
          return image
      }
  }
  var chatSearchDownDisabled: CGImage {
      if let image = cached["chatSearchDownDisabled"] {
          return image
      } else {
          let image = _chatSearchDownDisabled()
          cached["(chatSearchDownDisabled)"] = image
          return image
      }
  }
  var chatSearchCalendar: CGImage {
      if let image = cached["chatSearchCalendar"] {
          return image
      } else {
          let image = _chatSearchCalendar()
          cached["(chatSearchCalendar)"] = image
          return image
      }
  }
  var dismissAccessory: CGImage {
      if let image = cached["dismissAccessory"] {
          return image
      } else {
          let image = _dismissAccessory()
          cached["(dismissAccessory)"] = image
          return image
      }
  }
  var chatScrollUp: CGImage {
      if let image = cached["chatScrollUp"] {
          return image
      } else {
          let image = _chatScrollUp()
          cached["(chatScrollUp)"] = image
          return image
      }
  }
  var chatScrollUpActive: CGImage {
      if let image = cached["chatScrollUpActive"] {
          return image
      } else {
          let image = _chatScrollUpActive()
          cached["(chatScrollUpActive)"] = image
          return image
      }
  }
  var audioPlayerPlay: CGImage {
      if let image = cached["audioPlayerPlay"] {
          return image
      } else {
          let image = _audioPlayerPlay()
          cached["(audioPlayerPlay)"] = image
          return image
      }
  }
  var audioPlayerPause: CGImage {
      if let image = cached["audioPlayerPause"] {
          return image
      } else {
          let image = _audioPlayerPause()
          cached["(audioPlayerPause)"] = image
          return image
      }
  }
  var audioPlayerNext: CGImage {
      if let image = cached["audioPlayerNext"] {
          return image
      } else {
          let image = _audioPlayerNext()
          cached["(audioPlayerNext)"] = image
          return image
      }
  }
  var audioPlayerPrev: CGImage {
      if let image = cached["audioPlayerPrev"] {
          return image
      } else {
          let image = _audioPlayerPrev()
          cached["(audioPlayerPrev)"] = image
          return image
      }
  }
  var auduiPlayerDismiss: CGImage {
      if let image = cached["auduiPlayerDismiss"] {
          return image
      } else {
          let image = _auduiPlayerDismiss()
          cached["(auduiPlayerDismiss)"] = image
          return image
      }
  }
  var audioPlayerRepeat: CGImage {
      if let image = cached["audioPlayerRepeat"] {
          return image
      } else {
          let image = _audioPlayerRepeat()
          cached["(audioPlayerRepeat)"] = image
          return image
      }
  }
  var audioPlayerRepeatActive: CGImage {
      if let image = cached["audioPlayerRepeatActive"] {
          return image
      } else {
          let image = _audioPlayerRepeatActive()
          cached["(audioPlayerRepeatActive)"] = image
          return image
      }
  }
  var audioPlayerLockedPlay: CGImage {
      if let image = cached["audioPlayerLockedPlay"] {
          return image
      } else {
          let image = _audioPlayerLockedPlay()
          cached["(audioPlayerLockedPlay)"] = image
          return image
      }
  }
  var audioPlayerLockedNext: CGImage {
      if let image = cached["audioPlayerLockedNext"] {
          return image
      } else {
          let image = _audioPlayerLockedNext()
          cached["(audioPlayerLockedNext)"] = image
          return image
      }
  }
  var audioPlayerLockedPrev: CGImage {
      if let image = cached["audioPlayerLockedPrev"] {
          return image
      } else {
          let image = _audioPlayerLockedPrev()
          cached["(audioPlayerLockedPrev)"] = image
          return image
      }
  }
  var chatSendMessage: CGImage {
      if let image = cached["chatSendMessage"] {
          return image
      } else {
          let image = _chatSendMessage()
          cached["(chatSendMessage)"] = image
          return image
      }
  }
  var chatRecordVoice: CGImage {
      if let image = cached["chatRecordVoice"] {
          return image
      } else {
          let image = _chatRecordVoice()
          cached["(chatRecordVoice)"] = image
          return image
      }
  }
  var chatEntertainment: CGImage {
      if let image = cached["chatEntertainment"] {
          return image
      } else {
          let image = _chatEntertainment()
          cached["(chatEntertainment)"] = image
          return image
      }
  }
  var chatInlineDismiss: CGImage {
      if let image = cached["chatInlineDismiss"] {
          return image
      } else {
          let image = _chatInlineDismiss()
          cached["(chatInlineDismiss)"] = image
          return image
      }
  }
  var chatActiveReplyMarkup: CGImage {
      if let image = cached["chatActiveReplyMarkup"] {
          return image
      } else {
          let image = _chatActiveReplyMarkup()
          cached["(chatActiveReplyMarkup)"] = image
          return image
      }
  }
  var chatDisabledReplyMarkup: CGImage {
      if let image = cached["chatDisabledReplyMarkup"] {
          return image
      } else {
          let image = _chatDisabledReplyMarkup()
          cached["(chatDisabledReplyMarkup)"] = image
          return image
      }
  }
  var chatSecretTimer: CGImage {
      if let image = cached["chatSecretTimer"] {
          return image
      } else {
          let image = _chatSecretTimer()
          cached["(chatSecretTimer)"] = image
          return image
      }
  }
  var chatForwardMessagesActive: CGImage {
      if let image = cached["chatForwardMessagesActive"] {
          return image
      } else {
          let image = _chatForwardMessagesActive()
          cached["(chatForwardMessagesActive)"] = image
          return image
      }
  }
  var chatForwardMessagesInactive: CGImage {
      if let image = cached["chatForwardMessagesInactive"] {
          return image
      } else {
          let image = _chatForwardMessagesInactive()
          cached["(chatForwardMessagesInactive)"] = image
          return image
      }
  }
  var chatDeleteMessagesActive: CGImage {
      if let image = cached["chatDeleteMessagesActive"] {
          return image
      } else {
          let image = _chatDeleteMessagesActive()
          cached["(chatDeleteMessagesActive)"] = image
          return image
      }
  }
  var chatDeleteMessagesInactive: CGImage {
      if let image = cached["chatDeleteMessagesInactive"] {
          return image
      } else {
          let image = _chatDeleteMessagesInactive()
          cached["(chatDeleteMessagesInactive)"] = image
          return image
      }
  }
  var generalNext: CGImage {
      if let image = cached["generalNext"] {
          return image
      } else {
          let image = _generalNext()
          cached["(generalNext)"] = image
          return image
      }
  }
  var generalNextActive: CGImage {
      if let image = cached["generalNextActive"] {
          return image
      } else {
          let image = _generalNextActive()
          cached["(generalNextActive)"] = image
          return image
      }
  }
  var generalSelect: CGImage {
      if let image = cached["generalSelect"] {
          return image
      } else {
          let image = _generalSelect()
          cached["(generalSelect)"] = image
          return image
      }
  }
  var chatVoiceRecording: CGImage {
      if let image = cached["chatVoiceRecording"] {
          return image
      } else {
          let image = _chatVoiceRecording()
          cached["(chatVoiceRecording)"] = image
          return image
      }
  }
  var chatVideoRecording: CGImage {
      if let image = cached["chatVideoRecording"] {
          return image
      } else {
          let image = _chatVideoRecording()
          cached["(chatVideoRecording)"] = image
          return image
      }
  }
  var chatRecord: CGImage {
      if let image = cached["chatRecord"] {
          return image
      } else {
          let image = _chatRecord()
          cached["(chatRecord)"] = image
          return image
      }
  }
  var deleteItem: CGImage {
      if let image = cached["deleteItem"] {
          return image
      } else {
          let image = _deleteItem()
          cached["(deleteItem)"] = image
          return image
      }
  }
  var deleteItemDisabled: CGImage {
      if let image = cached["deleteItemDisabled"] {
          return image
      } else {
          let image = _deleteItemDisabled()
          cached["(deleteItemDisabled)"] = image
          return image
      }
  }
  var chatAttach: CGImage {
      if let image = cached["chatAttach"] {
          return image
      } else {
          let image = _chatAttach()
          cached["(chatAttach)"] = image
          return image
      }
  }
  var chatAttachFile: CGImage {
      if let image = cached["chatAttachFile"] {
          return image
      } else {
          let image = _chatAttachFile()
          cached["(chatAttachFile)"] = image
          return image
      }
  }
  var chatAttachPhoto: CGImage {
      if let image = cached["chatAttachPhoto"] {
          return image
      } else {
          let image = _chatAttachPhoto()
          cached["(chatAttachPhoto)"] = image
          return image
      }
  }
  var chatAttachCamera: CGImage {
      if let image = cached["chatAttachCamera"] {
          return image
      } else {
          let image = _chatAttachCamera()
          cached["(chatAttachCamera)"] = image
          return image
      }
  }
  var chatAttachLocation: CGImage {
      if let image = cached["chatAttachLocation"] {
          return image
      } else {
          let image = _chatAttachLocation()
          cached["(chatAttachLocation)"] = image
          return image
      }
  }
  var chatAttachPoll: CGImage {
      if let image = cached["chatAttachPoll"] {
          return image
      } else {
          let image = _chatAttachPoll()
          cached["(chatAttachPoll)"] = image
          return image
      }
  }
  var mediaEmptyShared: CGImage {
      if let image = cached["mediaEmptyShared"] {
          return image
      } else {
          let image = _mediaEmptyShared()
          cached["(mediaEmptyShared)"] = image
          return image
      }
  }
  var mediaEmptyFiles: CGImage {
      if let image = cached["mediaEmptyFiles"] {
          return image
      } else {
          let image = _mediaEmptyFiles()
          cached["(mediaEmptyFiles)"] = image
          return image
      }
  }
  var mediaEmptyMusic: CGImage {
      if let image = cached["mediaEmptyMusic"] {
          return image
      } else {
          let image = _mediaEmptyMusic()
          cached["(mediaEmptyMusic)"] = image
          return image
      }
  }
  var mediaEmptyLinks: CGImage {
      if let image = cached["mediaEmptyLinks"] {
          return image
      } else {
          let image = _mediaEmptyLinks()
          cached["(mediaEmptyLinks)"] = image
          return image
      }
  }
  var mediaDropdown: CGImage {
      if let image = cached["mediaDropdown"] {
          return image
      } else {
          let image = _mediaDropdown()
          cached["(mediaDropdown)"] = image
          return image
      }
  }
  var stickersAddFeatured: CGImage {
      if let image = cached["stickersAddFeatured"] {
          return image
      } else {
          let image = _stickersAddFeatured()
          cached["(stickersAddFeatured)"] = image
          return image
      }
  }
  var stickersAddedFeatured: CGImage {
      if let image = cached["stickersAddedFeatured"] {
          return image
      } else {
          let image = _stickersAddedFeatured()
          cached["(stickersAddedFeatured)"] = image
          return image
      }
  }
  var stickersRemove: CGImage {
      if let image = cached["stickersRemove"] {
          return image
      } else {
          let image = _stickersRemove()
          cached["(stickersRemove)"] = image
          return image
      }
  }
  var peerMediaDownloadFileStart: CGImage {
      if let image = cached["peerMediaDownloadFileStart"] {
          return image
      } else {
          let image = _peerMediaDownloadFileStart()
          cached["(peerMediaDownloadFileStart)"] = image
          return image
      }
  }
  var peerMediaDownloadFilePause: CGImage {
      if let image = cached["peerMediaDownloadFilePause"] {
          return image
      } else {
          let image = _peerMediaDownloadFilePause()
          cached["(peerMediaDownloadFilePause)"] = image
          return image
      }
  }
  var stickersShare: CGImage {
      if let image = cached["stickersShare"] {
          return image
      } else {
          let image = _stickersShare()
          cached["(stickersShare)"] = image
          return image
      }
  }
  var emojiRecentTab: CGImage {
      if let image = cached["emojiRecentTab"] {
          return image
      } else {
          let image = _emojiRecentTab()
          cached["(emojiRecentTab)"] = image
          return image
      }
  }
  var emojiSmileTab: CGImage {
      if let image = cached["emojiSmileTab"] {
          return image
      } else {
          let image = _emojiSmileTab()
          cached["(emojiSmileTab)"] = image
          return image
      }
  }
  var emojiNatureTab: CGImage {
      if let image = cached["emojiNatureTab"] {
          return image
      } else {
          let image = _emojiNatureTab()
          cached["(emojiNatureTab)"] = image
          return image
      }
  }
  var emojiFoodTab: CGImage {
      if let image = cached["emojiFoodTab"] {
          return image
      } else {
          let image = _emojiFoodTab()
          cached["(emojiFoodTab)"] = image
          return image
      }
  }
  var emojiSportTab: CGImage {
      if let image = cached["emojiSportTab"] {
          return image
      } else {
          let image = _emojiSportTab()
          cached["(emojiSportTab)"] = image
          return image
      }
  }
  var emojiCarTab: CGImage {
      if let image = cached["emojiCarTab"] {
          return image
      } else {
          let image = _emojiCarTab()
          cached["(emojiCarTab)"] = image
          return image
      }
  }
  var emojiObjectsTab: CGImage {
      if let image = cached["emojiObjectsTab"] {
          return image
      } else {
          let image = _emojiObjectsTab()
          cached["(emojiObjectsTab)"] = image
          return image
      }
  }
  var emojiSymbolsTab: CGImage {
      if let image = cached["emojiSymbolsTab"] {
          return image
      } else {
          let image = _emojiSymbolsTab()
          cached["(emojiSymbolsTab)"] = image
          return image
      }
  }
  var emojiFlagsTab: CGImage {
      if let image = cached["emojiFlagsTab"] {
          return image
      } else {
          let image = _emojiFlagsTab()
          cached["(emojiFlagsTab)"] = image
          return image
      }
  }
  var emojiRecentTabActive: CGImage {
      if let image = cached["emojiRecentTabActive"] {
          return image
      } else {
          let image = _emojiRecentTabActive()
          cached["(emojiRecentTabActive)"] = image
          return image
      }
  }
  var emojiSmileTabActive: CGImage {
      if let image = cached["emojiSmileTabActive"] {
          return image
      } else {
          let image = _emojiSmileTabActive()
          cached["(emojiSmileTabActive)"] = image
          return image
      }
  }
  var emojiNatureTabActive: CGImage {
      if let image = cached["emojiNatureTabActive"] {
          return image
      } else {
          let image = _emojiNatureTabActive()
          cached["(emojiNatureTabActive)"] = image
          return image
      }
  }
  var emojiFoodTabActive: CGImage {
      if let image = cached["emojiFoodTabActive"] {
          return image
      } else {
          let image = _emojiFoodTabActive()
          cached["(emojiFoodTabActive)"] = image
          return image
      }
  }
  var emojiSportTabActive: CGImage {
      if let image = cached["emojiSportTabActive"] {
          return image
      } else {
          let image = _emojiSportTabActive()
          cached["(emojiSportTabActive)"] = image
          return image
      }
  }
  var emojiCarTabActive: CGImage {
      if let image = cached["emojiCarTabActive"] {
          return image
      } else {
          let image = _emojiCarTabActive()
          cached["(emojiCarTabActive)"] = image
          return image
      }
  }
  var emojiObjectsTabActive: CGImage {
      if let image = cached["emojiObjectsTabActive"] {
          return image
      } else {
          let image = _emojiObjectsTabActive()
          cached["(emojiObjectsTabActive)"] = image
          return image
      }
  }
  var emojiSymbolsTabActive: CGImage {
      if let image = cached["emojiSymbolsTabActive"] {
          return image
      } else {
          let image = _emojiSymbolsTabActive()
          cached["(emojiSymbolsTabActive)"] = image
          return image
      }
  }
  var emojiFlagsTabActive: CGImage {
      if let image = cached["emojiFlagsTabActive"] {
          return image
      } else {
          let image = _emojiFlagsTabActive()
          cached["(emojiFlagsTabActive)"] = image
          return image
      }
  }
  var stickerBackground: CGImage {
      if let image = cached["stickerBackground"] {
          return image
      } else {
          let image = _stickerBackground()
          cached["(stickerBackground)"] = image
          return image
      }
  }
  var stickerBackgroundActive: CGImage {
      if let image = cached["stickerBackgroundActive"] {
          return image
      } else {
          let image = _stickerBackgroundActive()
          cached["(stickerBackgroundActive)"] = image
          return image
      }
  }
  var stickersTabRecent: CGImage {
      if let image = cached["stickersTabRecent"] {
          return image
      } else {
          let image = _stickersTabRecent()
          cached["(stickersTabRecent)"] = image
          return image
      }
  }
  var stickersTabGIF: CGImage {
      if let image = cached["stickersTabGIF"] {
          return image
      } else {
          let image = _stickersTabGIF()
          cached["(stickersTabGIF)"] = image
          return image
      }
  }
  var chatSendingInFrame_incoming: CGImage {
      if let image = cached["chatSendingInFrame_incoming"] {
          return image
      } else {
          let image = _chatSendingInFrame_incoming()
          cached["(chatSendingInFrame_incoming)"] = image
          return image
      }
  }
  var chatSendingInHour_incoming: CGImage {
      if let image = cached["chatSendingInHour_incoming"] {
          return image
      } else {
          let image = _chatSendingInHour_incoming()
          cached["(chatSendingInHour_incoming)"] = image
          return image
      }
  }
  var chatSendingInMin_incoming: CGImage {
      if let image = cached["chatSendingInMin_incoming"] {
          return image
      } else {
          let image = _chatSendingInMin_incoming()
          cached["(chatSendingInMin_incoming)"] = image
          return image
      }
  }
  var chatSendingInFrame_outgoing: CGImage {
      if let image = cached["chatSendingInFrame_outgoing"] {
          return image
      } else {
          let image = _chatSendingInFrame_outgoing()
          cached["(chatSendingInFrame_outgoing)"] = image
          return image
      }
  }
  var chatSendingInHour_outgoing: CGImage {
      if let image = cached["chatSendingInHour_outgoing"] {
          return image
      } else {
          let image = _chatSendingInHour_outgoing()
          cached["(chatSendingInHour_outgoing)"] = image
          return image
      }
  }
  var chatSendingInMin_outgoing: CGImage {
      if let image = cached["chatSendingInMin_outgoing"] {
          return image
      } else {
          let image = _chatSendingInMin_outgoing()
          cached["(chatSendingInMin_outgoing)"] = image
          return image
      }
  }
  var chatSendingOutFrame: CGImage {
      if let image = cached["chatSendingOutFrame"] {
          return image
      } else {
          let image = _chatSendingOutFrame()
          cached["(chatSendingOutFrame)"] = image
          return image
      }
  }
  var chatSendingOutHour: CGImage {
      if let image = cached["chatSendingOutHour"] {
          return image
      } else {
          let image = _chatSendingOutHour()
          cached["(chatSendingOutHour)"] = image
          return image
      }
  }
  var chatSendingOutMin: CGImage {
      if let image = cached["chatSendingOutMin"] {
          return image
      } else {
          let image = _chatSendingOutMin()
          cached["(chatSendingOutMin)"] = image
          return image
      }
  }
  var chatSendingOverlayFrame: CGImage {
      if let image = cached["chatSendingOverlayFrame"] {
          return image
      } else {
          let image = _chatSendingOverlayFrame()
          cached["(chatSendingOverlayFrame)"] = image
          return image
      }
  }
  var chatSendingOverlayHour: CGImage {
      if let image = cached["chatSendingOverlayHour"] {
          return image
      } else {
          let image = _chatSendingOverlayHour()
          cached["(chatSendingOverlayHour)"] = image
          return image
      }
  }
  var chatSendingOverlayMin: CGImage {
      if let image = cached["chatSendingOverlayMin"] {
          return image
      } else {
          let image = _chatSendingOverlayMin()
          cached["(chatSendingOverlayMin)"] = image
          return image
      }
  }
  var chatActionUrl: CGImage {
      if let image = cached["chatActionUrl"] {
          return image
      } else {
          let image = _chatActionUrl()
          cached["(chatActionUrl)"] = image
          return image
      }
  }
  var callInlineDecline: CGImage {
      if let image = cached["callInlineDecline"] {
          return image
      } else {
          let image = _callInlineDecline()
          cached["(callInlineDecline)"] = image
          return image
      }
  }
  var callInlineMuted: CGImage {
      if let image = cached["callInlineMuted"] {
          return image
      } else {
          let image = _callInlineMuted()
          cached["(callInlineMuted)"] = image
          return image
      }
  }
  var callInlineUnmuted: CGImage {
      if let image = cached["callInlineUnmuted"] {
          return image
      } else {
          let image = _callInlineUnmuted()
          cached["(callInlineUnmuted)"] = image
          return image
      }
  }
  var eventLogTriangle: CGImage {
      if let image = cached["eventLogTriangle"] {
          return image
      } else {
          let image = _eventLogTriangle()
          cached["(eventLogTriangle)"] = image
          return image
      }
  }
  var channelIntro: CGImage {
      if let image = cached["channelIntro"] {
          return image
      } else {
          let image = _channelIntro()
          cached["(channelIntro)"] = image
          return image
      }
  }
  var chatFileThumb: CGImage {
      if let image = cached["chatFileThumb"] {
          return image
      } else {
          let image = _chatFileThumb()
          cached["(chatFileThumb)"] = image
          return image
      }
  }
  var chatFileThumbBubble_incoming: CGImage {
      if let image = cached["chatFileThumbBubble_incoming"] {
          return image
      } else {
          let image = _chatFileThumbBubble_incoming()
          cached["(chatFileThumbBubble_incoming)"] = image
          return image
      }
  }
  var chatFileThumbBubble_outgoing: CGImage {
      if let image = cached["chatFileThumbBubble_outgoing"] {
          return image
      } else {
          let image = _chatFileThumbBubble_outgoing()
          cached["(chatFileThumbBubble_outgoing)"] = image
          return image
      }
  }
  var chatSecretThumb: CGImage {
      if let image = cached["chatSecretThumb"] {
          return image
      } else {
          let image = _chatSecretThumb()
          cached["(chatSecretThumb)"] = image
          return image
      }
  }
  var chatMapPin: CGImage {
      if let image = cached["chatMapPin"] {
          return image
      } else {
          let image = _chatMapPin()
          cached["(chatMapPin)"] = image
          return image
      }
  }
  var chatSecretTitle: CGImage {
      if let image = cached["chatSecretTitle"] {
          return image
      } else {
          let image = _chatSecretTitle()
          cached["(chatSecretTitle)"] = image
          return image
      }
  }
  var emptySearch: CGImage {
      if let image = cached["emptySearch"] {
          return image
      } else {
          let image = _emptySearch()
          cached["(emptySearch)"] = image
          return image
      }
  }
  var calendarBack: CGImage {
      if let image = cached["calendarBack"] {
          return image
      } else {
          let image = _calendarBack()
          cached["(calendarBack)"] = image
          return image
      }
  }
  var calendarNext: CGImage {
      if let image = cached["calendarNext"] {
          return image
      } else {
          let image = _calendarNext()
          cached["(calendarNext)"] = image
          return image
      }
  }
  var calendarBackDisabled: CGImage {
      if let image = cached["calendarBackDisabled"] {
          return image
      } else {
          let image = _calendarBackDisabled()
          cached["(calendarBackDisabled)"] = image
          return image
      }
  }
  var calendarNextDisabled: CGImage {
      if let image = cached["calendarNextDisabled"] {
          return image
      } else {
          let image = _calendarNextDisabled()
          cached["(calendarNextDisabled)"] = image
          return image
      }
  }
  var newChatCamera: CGImage {
      if let image = cached["newChatCamera"] {
          return image
      } else {
          let image = _newChatCamera()
          cached["(newChatCamera)"] = image
          return image
      }
  }
  var peerInfoVerify: CGImage {
      if let image = cached["peerInfoVerify"] {
          return image
      } else {
          let image = _peerInfoVerify()
          cached["(peerInfoVerify)"] = image
          return image
      }
  }
  var peerInfoCall: CGImage {
      if let image = cached["peerInfoCall"] {
          return image
      } else {
          let image = _peerInfoCall()
          cached["(peerInfoCall)"] = image
          return image
      }
  }
  var callOutgoing: CGImage {
      if let image = cached["callOutgoing"] {
          return image
      } else {
          let image = _callOutgoing()
          cached["(callOutgoing)"] = image
          return image
      }
  }
  var recentDismiss: CGImage {
      if let image = cached["recentDismiss"] {
          return image
      } else {
          let image = _recentDismiss()
          cached["(recentDismiss)"] = image
          return image
      }
  }
  var recentDismissActive: CGImage {
      if let image = cached["recentDismissActive"] {
          return image
      } else {
          let image = _recentDismissActive()
          cached["(recentDismissActive)"] = image
          return image
      }
  }
  var webgameShare: CGImage {
      if let image = cached["webgameShare"] {
          return image
      } else {
          let image = _webgameShare()
          cached["(webgameShare)"] = image
          return image
      }
  }
  var chatSearchCancel: CGImage {
      if let image = cached["chatSearchCancel"] {
          return image
      } else {
          let image = _chatSearchCancel()
          cached["(chatSearchCancel)"] = image
          return image
      }
  }
  var chatSearchFrom: CGImage {
      if let image = cached["chatSearchFrom"] {
          return image
      } else {
          let image = _chatSearchFrom()
          cached["(chatSearchFrom)"] = image
          return image
      }
  }
  var callWindowDecline: CGImage {
      if let image = cached["callWindowDecline"] {
          return image
      } else {
          let image = _callWindowDecline()
          cached["(callWindowDecline)"] = image
          return image
      }
  }
  var callWindowAccept: CGImage {
      if let image = cached["callWindowAccept"] {
          return image
      } else {
          let image = _callWindowAccept()
          cached["(callWindowAccept)"] = image
          return image
      }
  }
  var callWindowMute: CGImage {
      if let image = cached["callWindowMute"] {
          return image
      } else {
          let image = _callWindowMute()
          cached["(callWindowMute)"] = image
          return image
      }
  }
  var callWindowUnmute: CGImage {
      if let image = cached["callWindowUnmute"] {
          return image
      } else {
          let image = _callWindowUnmute()
          cached["(callWindowUnmute)"] = image
          return image
      }
  }
  var callWindowClose: CGImage {
      if let image = cached["callWindowClose"] {
          return image
      } else {
          let image = _callWindowClose()
          cached["(callWindowClose)"] = image
          return image
      }
  }
  var callWindowDeviceSettings: CGImage {
      if let image = cached["callWindowDeviceSettings"] {
          return image
      } else {
          let image = _callWindowDeviceSettings()
          cached["(callWindowDeviceSettings)"] = image
          return image
      }
  }
  var callSettings: CGImage {
      if let image = cached["callSettings"] {
          return image
      } else {
          let image = _callSettings()
          cached["(callSettings)"] = image
          return image
      }
  }
  var callWindowCancel: CGImage {
      if let image = cached["callWindowCancel"] {
          return image
      } else {
          let image = _callWindowCancel()
          cached["(callWindowCancel)"] = image
          return image
      }
  }
  var chatActionEdit: CGImage {
      if let image = cached["chatActionEdit"] {
          return image
      } else {
          let image = _chatActionEdit()
          cached["(chatActionEdit)"] = image
          return image
      }
  }
  var chatActionInfo: CGImage {
      if let image = cached["chatActionInfo"] {
          return image
      } else {
          let image = _chatActionInfo()
          cached["(chatActionInfo)"] = image
          return image
      }
  }
  var chatActionMute: CGImage {
      if let image = cached["chatActionMute"] {
          return image
      } else {
          let image = _chatActionMute()
          cached["(chatActionMute)"] = image
          return image
      }
  }
  var chatActionUnmute: CGImage {
      if let image = cached["chatActionUnmute"] {
          return image
      } else {
          let image = _chatActionUnmute()
          cached["(chatActionUnmute)"] = image
          return image
      }
  }
  var chatActionClearHistory: CGImage {
      if let image = cached["chatActionClearHistory"] {
          return image
      } else {
          let image = _chatActionClearHistory()
          cached["(chatActionClearHistory)"] = image
          return image
      }
  }
  var chatActionDeleteChat: CGImage {
      if let image = cached["chatActionDeleteChat"] {
          return image
      } else {
          let image = _chatActionDeleteChat()
          cached["(chatActionDeleteChat)"] = image
          return image
      }
  }
  var dismissPinned: CGImage {
      if let image = cached["dismissPinned"] {
          return image
      } else {
          let image = _dismissPinned()
          cached["(dismissPinned)"] = image
          return image
      }
  }
  var chatActionsActive: CGImage {
      if let image = cached["chatActionsActive"] {
          return image
      } else {
          let image = _chatActionsActive()
          cached["(chatActionsActive)"] = image
          return image
      }
  }
  var chatEntertainmentSticker: CGImage {
      if let image = cached["chatEntertainmentSticker"] {
          return image
      } else {
          let image = _chatEntertainmentSticker()
          cached["(chatEntertainmentSticker)"] = image
          return image
      }
  }
  var chatEmpty: CGImage {
      if let image = cached["chatEmpty"] {
          return image
      } else {
          let image = _chatEmpty()
          cached["(chatEmpty)"] = image
          return image
      }
  }
  var stickerPackClose: CGImage {
      if let image = cached["stickerPackClose"] {
          return image
      } else {
          let image = _stickerPackClose()
          cached["(stickerPackClose)"] = image
          return image
      }
  }
  var stickerPackDelete: CGImage {
      if let image = cached["stickerPackDelete"] {
          return image
      } else {
          let image = _stickerPackDelete()
          cached["(stickerPackDelete)"] = image
          return image
      }
  }
  var modalShare: CGImage {
      if let image = cached["modalShare"] {
          return image
      } else {
          let image = _modalShare()
          cached["(modalShare)"] = image
          return image
      }
  }
  var modalClose: CGImage {
      if let image = cached["modalClose"] {
          return image
      } else {
          let image = _modalClose()
          cached["(modalClose)"] = image
          return image
      }
  }
  var ivChannelJoined: CGImage {
      if let image = cached["ivChannelJoined"] {
          return image
      } else {
          let image = _ivChannelJoined()
          cached["(ivChannelJoined)"] = image
          return image
      }
  }
  var chatListMention: CGImage {
      if let image = cached["chatListMention"] {
          return image
      } else {
          let image = _chatListMention()
          cached["(chatListMention)"] = image
          return image
      }
  }
  var chatListMentionActive: CGImage {
      if let image = cached["chatListMentionActive"] {
          return image
      } else {
          let image = _chatListMentionActive()
          cached["(chatListMentionActive)"] = image
          return image
      }
  }
  var chatListMentionArchived: CGImage {
      if let image = cached["chatListMentionArchived"] {
          return image
      } else {
          let image = _chatListMentionArchived()
          cached["(chatListMentionArchived)"] = image
          return image
      }
  }
  var chatListMentionArchivedActive: CGImage {
      if let image = cached["chatListMentionArchivedActive"] {
          return image
      } else {
          let image = _chatListMentionArchivedActive()
          cached["(chatListMentionArchivedActive)"] = image
          return image
      }
  }
  var chatMention: CGImage {
      if let image = cached["chatMention"] {
          return image
      } else {
          let image = _chatMention()
          cached["(chatMention)"] = image
          return image
      }
  }
  var chatMentionActive: CGImage {
      if let image = cached["chatMentionActive"] {
          return image
      } else {
          let image = _chatMentionActive()
          cached["(chatMentionActive)"] = image
          return image
      }
  }
  var sliderControl: CGImage {
      if let image = cached["sliderControl"] {
          return image
      } else {
          let image = _sliderControl()
          cached["(sliderControl)"] = image
          return image
      }
  }
  var sliderControlActive: CGImage {
      if let image = cached["sliderControlActive"] {
          return image
      } else {
          let image = _sliderControlActive()
          cached["(sliderControlActive)"] = image
          return image
      }
  }
  var stickersTabFave: CGImage {
      if let image = cached["stickersTabFave"] {
          return image
      } else {
          let image = _stickersTabFave()
          cached["(stickersTabFave)"] = image
          return image
      }
  }
  var chatInstantView: CGImage {
      if let image = cached["chatInstantView"] {
          return image
      } else {
          let image = _chatInstantView()
          cached["(chatInstantView)"] = image
          return image
      }
  }
  var chatInstantViewBubble_incoming: CGImage {
      if let image = cached["chatInstantViewBubble_incoming"] {
          return image
      } else {
          let image = _chatInstantViewBubble_incoming()
          cached["(chatInstantViewBubble_incoming)"] = image
          return image
      }
  }
  var chatInstantViewBubble_outgoing: CGImage {
      if let image = cached["chatInstantViewBubble_outgoing"] {
          return image
      } else {
          let image = _chatInstantViewBubble_outgoing()
          cached["(chatInstantViewBubble_outgoing)"] = image
          return image
      }
  }
  var instantViewShare: CGImage {
      if let image = cached["instantViewShare"] {
          return image
      } else {
          let image = _instantViewShare()
          cached["(instantViewShare)"] = image
          return image
      }
  }
  var instantViewActions: CGImage {
      if let image = cached["instantViewActions"] {
          return image
      } else {
          let image = _instantViewActions()
          cached["(instantViewActions)"] = image
          return image
      }
  }
  var instantViewActionsActive: CGImage {
      if let image = cached["instantViewActionsActive"] {
          return image
      } else {
          let image = _instantViewActionsActive()
          cached["(instantViewActionsActive)"] = image
          return image
      }
  }
  var instantViewSafari: CGImage {
      if let image = cached["instantViewSafari"] {
          return image
      } else {
          let image = _instantViewSafari()
          cached["(instantViewSafari)"] = image
          return image
      }
  }
  var instantViewBack: CGImage {
      if let image = cached["instantViewBack"] {
          return image
      } else {
          let image = _instantViewBack()
          cached["(instantViewBack)"] = image
          return image
      }
  }
  var instantViewCheck: CGImage {
      if let image = cached["instantViewCheck"] {
          return image
      } else {
          let image = _instantViewCheck()
          cached["(instantViewCheck)"] = image
          return image
      }
  }
  var groupStickerNotFound: CGImage {
      if let image = cached["groupStickerNotFound"] {
          return image
      } else {
          let image = _groupStickerNotFound()
          cached["(groupStickerNotFound)"] = image
          return image
      }
  }
  var settingsAskQuestion: CGImage {
      if let image = cached["settingsAskQuestion"] {
          return image
      } else {
          let image = _settingsAskQuestion()
          cached["(settingsAskQuestion)"] = image
          return image
      }
  }
  var settingsFaq: CGImage {
      if let image = cached["settingsFaq"] {
          return image
      } else {
          let image = _settingsFaq()
          cached["(settingsFaq)"] = image
          return image
      }
  }
  var settingsGeneral: CGImage {
      if let image = cached["settingsGeneral"] {
          return image
      } else {
          let image = _settingsGeneral()
          cached["(settingsGeneral)"] = image
          return image
      }
  }
  var settingsLanguage: CGImage {
      if let image = cached["settingsLanguage"] {
          return image
      } else {
          let image = _settingsLanguage()
          cached["(settingsLanguage)"] = image
          return image
      }
  }
  var settingsNotifications: CGImage {
      if let image = cached["settingsNotifications"] {
          return image
      } else {
          let image = _settingsNotifications()
          cached["(settingsNotifications)"] = image
          return image
      }
  }
  var settingsSecurity: CGImage {
      if let image = cached["settingsSecurity"] {
          return image
      } else {
          let image = _settingsSecurity()
          cached["(settingsSecurity)"] = image
          return image
      }
  }
  var settingsStickers: CGImage {
      if let image = cached["settingsStickers"] {
          return image
      } else {
          let image = _settingsStickers()
          cached["(settingsStickers)"] = image
          return image
      }
  }
  var settingsStorage: CGImage {
      if let image = cached["settingsStorage"] {
          return image
      } else {
          let image = _settingsStorage()
          cached["(settingsStorage)"] = image
          return image
      }
  }
  var settingsProxy: CGImage {
      if let image = cached["settingsProxy"] {
          return image
      } else {
          let image = _settingsProxy()
          cached["(settingsProxy)"] = image
          return image
      }
  }
  var settingsAppearance: CGImage {
      if let image = cached["settingsAppearance"] {
          return image
      } else {
          let image = _settingsAppearance()
          cached["(settingsAppearance)"] = image
          return image
      }
  }
  var settingsPassport: CGImage {
      if let image = cached["settingsPassport"] {
          return image
      } else {
          let image = _settingsPassport()
          cached["(settingsPassport)"] = image
          return image
      }
  }
  var settingsUpdate: CGImage {
      if let image = cached["settingsUpdate"] {
          return image
      } else {
          let image = _settingsUpdate()
          cached["(settingsUpdate)"] = image
          return image
      }
  }
  var settingsAskQuestionActive: CGImage {
      if let image = cached["settingsAskQuestionActive"] {
          return image
      } else {
          let image = _settingsAskQuestionActive()
          cached["(settingsAskQuestionActive)"] = image
          return image
      }
  }
  var settingsFaqActive: CGImage {
      if let image = cached["settingsFaqActive"] {
          return image
      } else {
          let image = _settingsFaqActive()
          cached["(settingsFaqActive)"] = image
          return image
      }
  }
  var settingsGeneralActive: CGImage {
      if let image = cached["settingsGeneralActive"] {
          return image
      } else {
          let image = _settingsGeneralActive()
          cached["(settingsGeneralActive)"] = image
          return image
      }
  }
  var settingsLanguageActive: CGImage {
      if let image = cached["settingsLanguageActive"] {
          return image
      } else {
          let image = _settingsLanguageActive()
          cached["(settingsLanguageActive)"] = image
          return image
      }
  }
  var settingsNotificationsActive: CGImage {
      if let image = cached["settingsNotificationsActive"] {
          return image
      } else {
          let image = _settingsNotificationsActive()
          cached["(settingsNotificationsActive)"] = image
          return image
      }
  }
  var settingsSecurityActive: CGImage {
      if let image = cached["settingsSecurityActive"] {
          return image
      } else {
          let image = _settingsSecurityActive()
          cached["(settingsSecurityActive)"] = image
          return image
      }
  }
  var settingsStickersActive: CGImage {
      if let image = cached["settingsStickersActive"] {
          return image
      } else {
          let image = _settingsStickersActive()
          cached["(settingsStickersActive)"] = image
          return image
      }
  }
  var settingsStorageActive: CGImage {
      if let image = cached["settingsStorageActive"] {
          return image
      } else {
          let image = _settingsStorageActive()
          cached["(settingsStorageActive)"] = image
          return image
      }
  }
  var settingsProxyActive: CGImage {
      if let image = cached["settingsProxyActive"] {
          return image
      } else {
          let image = _settingsProxyActive()
          cached["(settingsProxyActive)"] = image
          return image
      }
  }
  var settingsAppearanceActive: CGImage {
      if let image = cached["settingsAppearanceActive"] {
          return image
      } else {
          let image = _settingsAppearanceActive()
          cached["(settingsAppearanceActive)"] = image
          return image
      }
  }
  var settingsPassportActive: CGImage {
      if let image = cached["settingsPassportActive"] {
          return image
      } else {
          let image = _settingsPassportActive()
          cached["(settingsPassportActive)"] = image
          return image
      }
  }
  var settingsUpdateActive: CGImage {
      if let image = cached["settingsUpdateActive"] {
          return image
      } else {
          let image = _settingsUpdateActive()
          cached["(settingsUpdateActive)"] = image
          return image
      }
  }
  var generalCheck: CGImage {
      if let image = cached["generalCheck"] {
          return image
      } else {
          let image = _generalCheck()
          cached["(generalCheck)"] = image
          return image
      }
  }
  var settingsAbout: CGImage {
      if let image = cached["settingsAbout"] {
          return image
      } else {
          let image = _settingsAbout()
          cached["(settingsAbout)"] = image
          return image
      }
  }
  var settingsLogout: CGImage {
      if let image = cached["settingsLogout"] {
          return image
      } else {
          let image = _settingsLogout()
          cached["(settingsLogout)"] = image
          return image
      }
  }
  var fastSettingsLock: CGImage {
      if let image = cached["fastSettingsLock"] {
          return image
      } else {
          let image = _fastSettingsLock()
          cached["(fastSettingsLock)"] = image
          return image
      }
  }
  var fastSettingsDark: CGImage {
      if let image = cached["fastSettingsDark"] {
          return image
      } else {
          let image = _fastSettingsDark()
          cached["(fastSettingsDark)"] = image
          return image
      }
  }
  var fastSettingsSunny: CGImage {
      if let image = cached["fastSettingsSunny"] {
          return image
      } else {
          let image = _fastSettingsSunny()
          cached["(fastSettingsSunny)"] = image
          return image
      }
  }
  var fastSettingsMute: CGImage {
      if let image = cached["fastSettingsMute"] {
          return image
      } else {
          let image = _fastSettingsMute()
          cached["(fastSettingsMute)"] = image
          return image
      }
  }
  var fastSettingsUnmute: CGImage {
      if let image = cached["fastSettingsUnmute"] {
          return image
      } else {
          let image = _fastSettingsUnmute()
          cached["(fastSettingsUnmute)"] = image
          return image
      }
  }
  var chatRecordVideo: CGImage {
      if let image = cached["chatRecordVideo"] {
          return image
      } else {
          let image = _chatRecordVideo()
          cached["(chatRecordVideo)"] = image
          return image
      }
  }
  var inputChannelMute: CGImage {
      if let image = cached["inputChannelMute"] {
          return image
      } else {
          let image = _inputChannelMute()
          cached["(inputChannelMute)"] = image
          return image
      }
  }
  var inputChannelUnmute: CGImage {
      if let image = cached["inputChannelUnmute"] {
          return image
      } else {
          let image = _inputChannelUnmute()
          cached["(inputChannelUnmute)"] = image
          return image
      }
  }
  var changePhoneNumberIntro: CGImage {
      if let image = cached["changePhoneNumberIntro"] {
          return image
      } else {
          let image = _changePhoneNumberIntro()
          cached["(changePhoneNumberIntro)"] = image
          return image
      }
  }
  var peerSavedMessages: CGImage {
      if let image = cached["peerSavedMessages"] {
          return image
      } else {
          let image = _peerSavedMessages()
          cached["(peerSavedMessages)"] = image
          return image
      }
  }
  var previewCollage: CGImage {
      if let image = cached["previewCollage"] {
          return image
      } else {
          let image = _previewCollage()
          cached["(previewCollage)"] = image
          return image
      }
  }
  var chatGoMessage: CGImage {
      if let image = cached["chatGoMessage"] {
          return image
      } else {
          let image = _chatGoMessage()
          cached["(chatGoMessage)"] = image
          return image
      }
  }
  var chatGroupToggleSelected: CGImage {
      if let image = cached["chatGroupToggleSelected"] {
          return image
      } else {
          let image = _chatGroupToggleSelected()
          cached["(chatGroupToggleSelected)"] = image
          return image
      }
  }
  var chatGroupToggleUnselected: CGImage {
      if let image = cached["chatGroupToggleUnselected"] {
          return image
      } else {
          let image = _chatGroupToggleUnselected()
          cached["(chatGroupToggleUnselected)"] = image
          return image
      }
  }
  var successModalProgress: CGImage {
      if let image = cached["successModalProgress"] {
          return image
      } else {
          let image = _successModalProgress()
          cached["(successModalProgress)"] = image
          return image
      }
  }
  var accentColorSelect: CGImage {
      if let image = cached["accentColorSelect"] {
          return image
      } else {
          let image = _accentColorSelect()
          cached["(accentColorSelect)"] = image
          return image
      }
  }
  var chatShareWallpaper: CGImage {
      if let image = cached["chatShareWallpaper"] {
          return image
      } else {
          let image = _chatShareWallpaper()
          cached["(chatShareWallpaper)"] = image
          return image
      }
  }
  var chatGotoMessageWallpaper: CGImage {
      if let image = cached["chatGotoMessageWallpaper"] {
          return image
      } else {
          let image = _chatGotoMessageWallpaper()
          cached["(chatGotoMessageWallpaper)"] = image
          return image
      }
  }
  var transparentBackground: CGImage {
      if let image = cached["transparentBackground"] {
          return image
      } else {
          let image = _transparentBackground()
          cached["(transparentBackground)"] = image
          return image
      }
  }
  var lottieTransparentBackground: CGImage {
      if let image = cached["lottieTransparentBackground"] {
          return image
      } else {
          let image = _lottieTransparentBackground()
          cached["(lottieTransparentBackground)"] = image
          return image
      }
  }
  var passcodeTouchId: CGImage {
      if let image = cached["passcodeTouchId"] {
          return image
      } else {
          let image = _passcodeTouchId()
          cached["(passcodeTouchId)"] = image
          return image
      }
  }
  var passcodeLogin: CGImage {
      if let image = cached["passcodeLogin"] {
          return image
      } else {
          let image = _passcodeLogin()
          cached["(passcodeLogin)"] = image
          return image
      }
  }
  var confirmDeleteMessagesAccessory: CGImage {
      if let image = cached["confirmDeleteMessagesAccessory"] {
          return image
      } else {
          let image = _confirmDeleteMessagesAccessory()
          cached["(confirmDeleteMessagesAccessory)"] = image
          return image
      }
  }
  var alertCheckBoxSelected: CGImage {
      if let image = cached["alertCheckBoxSelected"] {
          return image
      } else {
          let image = _alertCheckBoxSelected()
          cached["(alertCheckBoxSelected)"] = image
          return image
      }
  }
  var alertCheckBoxUnselected: CGImage {
      if let image = cached["alertCheckBoxUnselected"] {
          return image
      } else {
          let image = _alertCheckBoxUnselected()
          cached["(alertCheckBoxUnselected)"] = image
          return image
      }
  }
  var confirmPinAccessory: CGImage {
      if let image = cached["confirmPinAccessory"] {
          return image
      } else {
          let image = _confirmPinAccessory()
          cached["(confirmPinAccessory)"] = image
          return image
      }
  }
  var confirmDeleteChatAccessory: CGImage {
      if let image = cached["confirmDeleteChatAccessory"] {
          return image
      } else {
          let image = _confirmDeleteChatAccessory()
          cached["(confirmDeleteChatAccessory)"] = image
          return image
      }
  }
  var stickersEmptySearch: CGImage {
      if let image = cached["stickersEmptySearch"] {
          return image
      } else {
          let image = _stickersEmptySearch()
          cached["(stickersEmptySearch)"] = image
          return image
      }
  }
  var twoStepVerificationCreateIntro: CGImage {
      if let image = cached["twoStepVerificationCreateIntro"] {
          return image
      } else {
          let image = _twoStepVerificationCreateIntro()
          cached["(twoStepVerificationCreateIntro)"] = image
          return image
      }
  }
  var secureIdAuth: CGImage {
      if let image = cached["secureIdAuth"] {
          return image
      } else {
          let image = _secureIdAuth()
          cached["(secureIdAuth)"] = image
          return image
      }
  }
  var ivAudioPlay: CGImage {
      if let image = cached["ivAudioPlay"] {
          return image
      } else {
          let image = _ivAudioPlay()
          cached["(ivAudioPlay)"] = image
          return image
      }
  }
  var ivAudioPause: CGImage {
      if let image = cached["ivAudioPause"] {
          return image
      } else {
          let image = _ivAudioPause()
          cached["(ivAudioPause)"] = image
          return image
      }
  }
  var proxyEnable: CGImage {
      if let image = cached["proxyEnable"] {
          return image
      } else {
          let image = _proxyEnable()
          cached["(proxyEnable)"] = image
          return image
      }
  }
  var proxyEnabled: CGImage {
      if let image = cached["proxyEnabled"] {
          return image
      } else {
          let image = _proxyEnabled()
          cached["(proxyEnabled)"] = image
          return image
      }
  }
  var proxyState: CGImage {
      if let image = cached["proxyState"] {
          return image
      } else {
          let image = _proxyState()
          cached["(proxyState)"] = image
          return image
      }
  }
  var proxyDeleteListItem: CGImage {
      if let image = cached["proxyDeleteListItem"] {
          return image
      } else {
          let image = _proxyDeleteListItem()
          cached["(proxyDeleteListItem)"] = image
          return image
      }
  }
  var proxyInfoListItem: CGImage {
      if let image = cached["proxyInfoListItem"] {
          return image
      } else {
          let image = _proxyInfoListItem()
          cached["(proxyInfoListItem)"] = image
          return image
      }
  }
  var proxyConnectedListItem: CGImage {
      if let image = cached["proxyConnectedListItem"] {
          return image
      } else {
          let image = _proxyConnectedListItem()
          cached["(proxyConnectedListItem)"] = image
          return image
      }
  }
  var proxyAddProxy: CGImage {
      if let image = cached["proxyAddProxy"] {
          return image
      } else {
          let image = _proxyAddProxy()
          cached["(proxyAddProxy)"] = image
          return image
      }
  }
  var proxyNextWaitingListItem: CGImage {
      if let image = cached["proxyNextWaitingListItem"] {
          return image
      } else {
          let image = _proxyNextWaitingListItem()
          cached["(proxyNextWaitingListItem)"] = image
          return image
      }
  }
  var passportForgotPassword: CGImage {
      if let image = cached["passportForgotPassword"] {
          return image
      } else {
          let image = _passportForgotPassword()
          cached["(passportForgotPassword)"] = image
          return image
      }
  }
  var confirmAppAccessoryIcon: CGImage {
      if let image = cached["confirmAppAccessoryIcon"] {
          return image
      } else {
          let image = _confirmAppAccessoryIcon()
          cached["(confirmAppAccessoryIcon)"] = image
          return image
      }
  }
  var passportPassport: CGImage {
      if let image = cached["passportPassport"] {
          return image
      } else {
          let image = _passportPassport()
          cached["(passportPassport)"] = image
          return image
      }
  }
  var passportIdCardReverse: CGImage {
      if let image = cached["passportIdCardReverse"] {
          return image
      } else {
          let image = _passportIdCardReverse()
          cached["(passportIdCardReverse)"] = image
          return image
      }
  }
  var passportIdCard: CGImage {
      if let image = cached["passportIdCard"] {
          return image
      } else {
          let image = _passportIdCard()
          cached["(passportIdCard)"] = image
          return image
      }
  }
  var passportSelfie: CGImage {
      if let image = cached["passportSelfie"] {
          return image
      } else {
          let image = _passportSelfie()
          cached["(passportSelfie)"] = image
          return image
      }
  }
  var passportDriverLicense: CGImage {
      if let image = cached["passportDriverLicense"] {
          return image
      } else {
          let image = _passportDriverLicense()
          cached["(passportDriverLicense)"] = image
          return image
      }
  }
  var chatOverlayVoiceRecording: CGImage {
      if let image = cached["chatOverlayVoiceRecording"] {
          return image
      } else {
          let image = _chatOverlayVoiceRecording()
          cached["(chatOverlayVoiceRecording)"] = image
          return image
      }
  }
  var chatOverlayVideoRecording: CGImage {
      if let image = cached["chatOverlayVideoRecording"] {
          return image
      } else {
          let image = _chatOverlayVideoRecording()
          cached["(chatOverlayVideoRecording)"] = image
          return image
      }
  }
  var chatOverlaySendRecording: CGImage {
      if let image = cached["chatOverlaySendRecording"] {
          return image
      } else {
          let image = _chatOverlaySendRecording()
          cached["(chatOverlaySendRecording)"] = image
          return image
      }
  }
  var chatOverlayLockArrowRecording: CGImage {
      if let image = cached["chatOverlayLockArrowRecording"] {
          return image
      } else {
          let image = _chatOverlayLockArrowRecording()
          cached["(chatOverlayLockArrowRecording)"] = image
          return image
      }
  }
  var chatOverlayLockerBodyRecording: CGImage {
      if let image = cached["chatOverlayLockerBodyRecording"] {
          return image
      } else {
          let image = _chatOverlayLockerBodyRecording()
          cached["(chatOverlayLockerBodyRecording)"] = image
          return image
      }
  }
  var chatOverlayLockerHeadRecording: CGImage {
      if let image = cached["chatOverlayLockerHeadRecording"] {
          return image
      } else {
          let image = _chatOverlayLockerHeadRecording()
          cached["(chatOverlayLockerHeadRecording)"] = image
          return image
      }
  }
  var locationPin: CGImage {
      if let image = cached["locationPin"] {
          return image
      } else {
          let image = _locationPin()
          cached["(locationPin)"] = image
          return image
      }
  }
  var locationMapPin: CGImage {
      if let image = cached["locationMapPin"] {
          return image
      } else {
          let image = _locationMapPin()
          cached["(locationMapPin)"] = image
          return image
      }
  }
  var locationMapLocate: CGImage {
      if let image = cached["locationMapLocate"] {
          return image
      } else {
          let image = _locationMapLocate()
          cached["(locationMapLocate)"] = image
          return image
      }
  }
  var locationMapLocated: CGImage {
      if let image = cached["locationMapLocated"] {
          return image
      } else {
          let image = _locationMapLocated()
          cached["(locationMapLocated)"] = image
          return image
      }
  }
  var chatTabIconSelected: CGImage {
      if let image = cached["chatTabIconSelected"] {
          return image
      } else {
          let image = _chatTabIconSelected()
          cached["(chatTabIconSelected)"] = image
          return image
      }
  }
  var chatTabIconSelectedUp: CGImage {
      if let image = cached["chatTabIconSelectedUp"] {
          return image
      } else {
          let image = _chatTabIconSelectedUp()
          cached["(chatTabIconSelectedUp)"] = image
          return image
      }
  }
  var chatTabIconSelectedDown: CGImage {
      if let image = cached["chatTabIconSelectedDown"] {
          return image
      } else {
          let image = _chatTabIconSelectedDown()
          cached["(chatTabIconSelectedDown)"] = image
          return image
      }
  }
  var chatTabIcon: CGImage {
      if let image = cached["chatTabIcon"] {
          return image
      } else {
          let image = _chatTabIcon()
          cached["(chatTabIcon)"] = image
          return image
      }
  }
  var passportSettings: CGImage {
      if let image = cached["passportSettings"] {
          return image
      } else {
          let image = _passportSettings()
          cached["(passportSettings)"] = image
          return image
      }
  }
  var passportInfo: CGImage {
      if let image = cached["passportInfo"] {
          return image
      } else {
          let image = _passportInfo()
          cached["(passportInfo)"] = image
          return image
      }
  }
  var editMessageMedia: CGImage {
      if let image = cached["editMessageMedia"] {
          return image
      } else {
          let image = _editMessageMedia()
          cached["(editMessageMedia)"] = image
          return image
      }
  }
  var playerMusicPlaceholder: CGImage {
      if let image = cached["playerMusicPlaceholder"] {
          return image
      } else {
          let image = _playerMusicPlaceholder()
          cached["(playerMusicPlaceholder)"] = image
          return image
      }
  }
  var chatMusicPlaceholder: CGImage {
      if let image = cached["chatMusicPlaceholder"] {
          return image
      } else {
          let image = _chatMusicPlaceholder()
          cached["(chatMusicPlaceholder)"] = image
          return image
      }
  }
  var chatMusicPlaceholderCap: CGImage {
      if let image = cached["chatMusicPlaceholderCap"] {
          return image
      } else {
          let image = _chatMusicPlaceholderCap()
          cached["(chatMusicPlaceholderCap)"] = image
          return image
      }
  }
  var searchArticle: CGImage {
      if let image = cached["searchArticle"] {
          return image
      } else {
          let image = _searchArticle()
          cached["(searchArticle)"] = image
          return image
      }
  }
  var searchSaved: CGImage {
      if let image = cached["searchSaved"] {
          return image
      } else {
          let image = _searchSaved()
          cached["(searchSaved)"] = image
          return image
      }
  }
  var archivedChats: CGImage {
      if let image = cached["archivedChats"] {
          return image
      } else {
          let image = _archivedChats()
          cached["(archivedChats)"] = image
          return image
      }
  }
  var hintPeerActive: CGImage {
      if let image = cached["hintPeerActive"] {
          return image
      } else {
          let image = _hintPeerActive()
          cached["(hintPeerActive)"] = image
          return image
      }
  }
  var hintPeerActiveSelected: CGImage {
      if let image = cached["hintPeerActiveSelected"] {
          return image
      } else {
          let image = _hintPeerActiveSelected()
          cached["(hintPeerActiveSelected)"] = image
          return image
      }
  }
  var chatSwiping_delete: CGImage {
      if let image = cached["chatSwiping_delete"] {
          return image
      } else {
          let image = _chatSwiping_delete()
          cached["(chatSwiping_delete)"] = image
          return image
      }
  }
  var chatSwiping_mute: CGImage {
      if let image = cached["chatSwiping_mute"] {
          return image
      } else {
          let image = _chatSwiping_mute()
          cached["(chatSwiping_mute)"] = image
          return image
      }
  }
  var chatSwiping_unmute: CGImage {
      if let image = cached["chatSwiping_unmute"] {
          return image
      } else {
          let image = _chatSwiping_unmute()
          cached["(chatSwiping_unmute)"] = image
          return image
      }
  }
  var chatSwiping_read: CGImage {
      if let image = cached["chatSwiping_read"] {
          return image
      } else {
          let image = _chatSwiping_read()
          cached["(chatSwiping_read)"] = image
          return image
      }
  }
  var chatSwiping_unread: CGImage {
      if let image = cached["chatSwiping_unread"] {
          return image
      } else {
          let image = _chatSwiping_unread()
          cached["(chatSwiping_unread)"] = image
          return image
      }
  }
  var chatSwiping_pin: CGImage {
      if let image = cached["chatSwiping_pin"] {
          return image
      } else {
          let image = _chatSwiping_pin()
          cached["(chatSwiping_pin)"] = image
          return image
      }
  }
  var chatSwiping_unpin: CGImage {
      if let image = cached["chatSwiping_unpin"] {
          return image
      } else {
          let image = _chatSwiping_unpin()
          cached["(chatSwiping_unpin)"] = image
          return image
      }
  }
  var chatSwiping_archive: CGImage {
      if let image = cached["chatSwiping_archive"] {
          return image
      } else {
          let image = _chatSwiping_archive()
          cached["(chatSwiping_archive)"] = image
          return image
      }
  }
  var chatSwiping_unarchive: CGImage {
      if let image = cached["chatSwiping_unarchive"] {
          return image
      } else {
          let image = _chatSwiping_unarchive()
          cached["(chatSwiping_unarchive)"] = image
          return image
      }
  }
  var galleryPrev: CGImage {
      if let image = cached["galleryPrev"] {
          return image
      } else {
          let image = _galleryPrev()
          cached["(galleryPrev)"] = image
          return image
      }
  }
  var galleryNext: CGImage {
      if let image = cached["galleryNext"] {
          return image
      } else {
          let image = _galleryNext()
          cached["(galleryNext)"] = image
          return image
      }
  }
  var galleryMore: CGImage {
      if let image = cached["galleryMore"] {
          return image
      } else {
          let image = _galleryMore()
          cached["(galleryMore)"] = image
          return image
      }
  }
  var galleryShare: CGImage {
      if let image = cached["galleryShare"] {
          return image
      } else {
          let image = _galleryShare()
          cached["(galleryShare)"] = image
          return image
      }
  }
  var galleryFastSave: CGImage {
      if let image = cached["galleryFastSave"] {
          return image
      } else {
          let image = _galleryFastSave()
          cached["(galleryFastSave)"] = image
          return image
      }
  }
  var playingVoice1x: CGImage {
      if let image = cached["playingVoice1x"] {
          return image
      } else {
          let image = _playingVoice1x()
          cached["(playingVoice1x)"] = image
          return image
      }
  }
  var playingVoice2x: CGImage {
      if let image = cached["playingVoice2x"] {
          return image
      } else {
          let image = _playingVoice2x()
          cached["(playingVoice2x)"] = image
          return image
      }
  }
  var galleryRotate: CGImage {
      if let image = cached["galleryRotate"] {
          return image
      } else {
          let image = _galleryRotate()
          cached["(galleryRotate)"] = image
          return image
      }
  }
  var galleryZoomIn: CGImage {
      if let image = cached["galleryZoomIn"] {
          return image
      } else {
          let image = _galleryZoomIn()
          cached["(galleryZoomIn)"] = image
          return image
      }
  }
  var galleryZoomOut: CGImage {
      if let image = cached["galleryZoomOut"] {
          return image
      } else {
          let image = _galleryZoomOut()
          cached["(galleryZoomOut)"] = image
          return image
      }
  }
  var previewSenderCrop: CGImage {
      if let image = cached["previewSenderCrop"] {
          return image
      } else {
          let image = _previewSenderCrop()
          cached["(previewSenderCrop)"] = image
          return image
      }
  }
  var previewSenderDelete: CGImage {
      if let image = cached["previewSenderDelete"] {
          return image
      } else {
          let image = _previewSenderDelete()
          cached["(previewSenderDelete)"] = image
          return image
      }
  }
  var editMessageCurrentPhoto: CGImage {
      if let image = cached["editMessageCurrentPhoto"] {
          return image
      } else {
          let image = _editMessageCurrentPhoto()
          cached["(editMessageCurrentPhoto)"] = image
          return image
      }
  }
  var previewSenderDeleteFile: CGImage {
      if let image = cached["previewSenderDeleteFile"] {
          return image
      } else {
          let image = _previewSenderDeleteFile()
          cached["(previewSenderDeleteFile)"] = image
          return image
      }
  }
  var previewSenderArchive: CGImage {
      if let image = cached["previewSenderArchive"] {
          return image
      } else {
          let image = _previewSenderArchive()
          cached["(previewSenderArchive)"] = image
          return image
      }
  }
  var chatSwipeReply: CGImage {
      if let image = cached["chatSwipeReply"] {
          return image
      } else {
          let image = _chatSwipeReply()
          cached["(chatSwipeReply)"] = image
          return image
      }
  }
  var chatSwipeReplyWallpaper: CGImage {
      if let image = cached["chatSwipeReplyWallpaper"] {
          return image
      } else {
          let image = _chatSwipeReplyWallpaper()
          cached["(chatSwipeReplyWallpaper)"] = image
          return image
      }
  }
  var videoPlayerPlay: CGImage {
      if let image = cached["videoPlayerPlay"] {
          return image
      } else {
          let image = _videoPlayerPlay()
          cached["(videoPlayerPlay)"] = image
          return image
      }
  }
  var videoPlayerPause: CGImage {
      if let image = cached["videoPlayerPause"] {
          return image
      } else {
          let image = _videoPlayerPause()
          cached["(videoPlayerPause)"] = image
          return image
      }
  }
  var videoPlayerEnterFullScreen: CGImage {
      if let image = cached["videoPlayerEnterFullScreen"] {
          return image
      } else {
          let image = _videoPlayerEnterFullScreen()
          cached["(videoPlayerEnterFullScreen)"] = image
          return image
      }
  }
  var videoPlayerExitFullScreen: CGImage {
      if let image = cached["videoPlayerExitFullScreen"] {
          return image
      } else {
          let image = _videoPlayerExitFullScreen()
          cached["(videoPlayerExitFullScreen)"] = image
          return image
      }
  }
  var videoPlayerPIPIn: CGImage {
      if let image = cached["videoPlayerPIPIn"] {
          return image
      } else {
          let image = _videoPlayerPIPIn()
          cached["(videoPlayerPIPIn)"] = image
          return image
      }
  }
  var videoPlayerPIPOut: CGImage {
      if let image = cached["videoPlayerPIPOut"] {
          return image
      } else {
          let image = _videoPlayerPIPOut()
          cached["(videoPlayerPIPOut)"] = image
          return image
      }
  }
  var videoPlayerRewind15Forward: CGImage {
      if let image = cached["videoPlayerRewind15Forward"] {
          return image
      } else {
          let image = _videoPlayerRewind15Forward()
          cached["(videoPlayerRewind15Forward)"] = image
          return image
      }
  }
  var videoPlayerRewind15Backward: CGImage {
      if let image = cached["videoPlayerRewind15Backward"] {
          return image
      } else {
          let image = _videoPlayerRewind15Backward()
          cached["(videoPlayerRewind15Backward)"] = image
          return image
      }
  }
  var videoPlayerVolume: CGImage {
      if let image = cached["videoPlayerVolume"] {
          return image
      } else {
          let image = _videoPlayerVolume()
          cached["(videoPlayerVolume)"] = image
          return image
      }
  }
  var videoPlayerVolumeOff: CGImage {
      if let image = cached["videoPlayerVolumeOff"] {
          return image
      } else {
          let image = _videoPlayerVolumeOff()
          cached["(videoPlayerVolumeOff)"] = image
          return image
      }
  }
  var videoPlayerClose: CGImage {
      if let image = cached["videoPlayerClose"] {
          return image
      } else {
          let image = _videoPlayerClose()
          cached["(videoPlayerClose)"] = image
          return image
      }
  }
  var videoPlayerSliderInteractor: CGImage {
      if let image = cached["videoPlayerSliderInteractor"] {
          return image
      } else {
          let image = _videoPlayerSliderInteractor()
          cached["(videoPlayerSliderInteractor)"] = image
          return image
      }
  }
  var streamingVideoDownload: CGImage {
      if let image = cached["streamingVideoDownload"] {
          return image
      } else {
          let image = _streamingVideoDownload()
          cached["(streamingVideoDownload)"] = image
          return image
      }
  }
  var videoCompactFetching: CGImage {
      if let image = cached["videoCompactFetching"] {
          return image
      } else {
          let image = _videoCompactFetching()
          cached["(videoCompactFetching)"] = image
          return image
      }
  }
  var compactStreamingFetchingCancel: CGImage {
      if let image = cached["compactStreamingFetchingCancel"] {
          return image
      } else {
          let image = _compactStreamingFetchingCancel()
          cached["(compactStreamingFetchingCancel)"] = image
          return image
      }
  }
  var customLocalizationDelete: CGImage {
      if let image = cached["customLocalizationDelete"] {
          return image
      } else {
          let image = _customLocalizationDelete()
          cached["(customLocalizationDelete)"] = image
          return image
      }
  }
  var pollAddOption: CGImage {
      if let image = cached["pollAddOption"] {
          return image
      } else {
          let image = _pollAddOption()
          cached["(pollAddOption)"] = image
          return image
      }
  }
  var pollDeleteOption: CGImage {
      if let image = cached["pollDeleteOption"] {
          return image
      } else {
          let image = _pollDeleteOption()
          cached["(pollDeleteOption)"] = image
          return image
      }
  }
  var resort: CGImage {
      if let image = cached["resort"] {
          return image
      } else {
          let image = _resort()
          cached["(resort)"] = image
          return image
      }
  }
  var chatPollVoteUnselected: CGImage {
      if let image = cached["chatPollVoteUnselected"] {
          return image
      } else {
          let image = _chatPollVoteUnselected()
          cached["(chatPollVoteUnselected)"] = image
          return image
      }
  }
  var chatPollVoteUnselectedBubble_incoming: CGImage {
      if let image = cached["chatPollVoteUnselectedBubble_incoming"] {
          return image
      } else {
          let image = _chatPollVoteUnselectedBubble_incoming()
          cached["(chatPollVoteUnselectedBubble_incoming)"] = image
          return image
      }
  }
  var chatPollVoteUnselectedBubble_outgoing: CGImage {
      if let image = cached["chatPollVoteUnselectedBubble_outgoing"] {
          return image
      } else {
          let image = _chatPollVoteUnselectedBubble_outgoing()
          cached["(chatPollVoteUnselectedBubble_outgoing)"] = image
          return image
      }
  }
  var peerInfoAdmins: CGImage {
      if let image = cached["peerInfoAdmins"] {
          return image
      } else {
          let image = _peerInfoAdmins()
          cached["(peerInfoAdmins)"] = image
          return image
      }
  }
  var peerInfoPermissions: CGImage {
      if let image = cached["peerInfoPermissions"] {
          return image
      } else {
          let image = _peerInfoPermissions()
          cached["(peerInfoPermissions)"] = image
          return image
      }
  }
  var peerInfoBanned: CGImage {
      if let image = cached["peerInfoBanned"] {
          return image
      } else {
          let image = _peerInfoBanned()
          cached["(peerInfoBanned)"] = image
          return image
      }
  }
  var peerInfoMembers: CGImage {
      if let image = cached["peerInfoMembers"] {
          return image
      } else {
          let image = _peerInfoMembers()
          cached["(peerInfoMembers)"] = image
          return image
      }
  }
  var chatUndoAction: CGImage {
      if let image = cached["chatUndoAction"] {
          return image
      } else {
          let image = _chatUndoAction()
          cached["(chatUndoAction)"] = image
          return image
      }
  }
  var appUpdate: CGImage {
      if let image = cached["appUpdate"] {
          return image
      } else {
          let image = _appUpdate()
          cached["(appUpdate)"] = image
          return image
      }
  }
  var inlineVideoSoundOff: CGImage {
      if let image = cached["inlineVideoSoundOff"] {
          return image
      } else {
          let image = _inlineVideoSoundOff()
          cached["(inlineVideoSoundOff)"] = image
          return image
      }
  }
  var inlineVideoSoundOn: CGImage {
      if let image = cached["inlineVideoSoundOn"] {
          return image
      } else {
          let image = _inlineVideoSoundOn()
          cached["(inlineVideoSoundOn)"] = image
          return image
      }
  }
  var logoutOptionAddAccount: CGImage {
      if let image = cached["logoutOptionAddAccount"] {
          return image
      } else {
          let image = _logoutOptionAddAccount()
          cached["(logoutOptionAddAccount)"] = image
          return image
      }
  }
  var logoutOptionSetPasscode: CGImage {
      if let image = cached["logoutOptionSetPasscode"] {
          return image
      } else {
          let image = _logoutOptionSetPasscode()
          cached["(logoutOptionSetPasscode)"] = image
          return image
      }
  }
  var logoutOptionClearCache: CGImage {
      if let image = cached["logoutOptionClearCache"] {
          return image
      } else {
          let image = _logoutOptionClearCache()
          cached["(logoutOptionClearCache)"] = image
          return image
      }
  }
  var logoutOptionChangePhoneNumber: CGImage {
      if let image = cached["logoutOptionChangePhoneNumber"] {
          return image
      } else {
          let image = _logoutOptionChangePhoneNumber()
          cached["(logoutOptionChangePhoneNumber)"] = image
          return image
      }
  }
  var logoutOptionContactSupport: CGImage {
      if let image = cached["logoutOptionContactSupport"] {
          return image
      } else {
          let image = _logoutOptionContactSupport()
          cached["(logoutOptionContactSupport)"] = image
          return image
      }
  }
  var disableEmojiPrediction: CGImage {
      if let image = cached["disableEmojiPrediction"] {
          return image
      } else {
          let image = _disableEmojiPrediction()
          cached["(disableEmojiPrediction)"] = image
          return image
      }
  }
  var scam: CGImage {
      if let image = cached["scam"] {
          return image
      } else {
          let image = _scam()
          cached["(scam)"] = image
          return image
      }
  }
  var scamActive: CGImage {
      if let image = cached["scamActive"] {
          return image
      } else {
          let image = _scamActive()
          cached["(scamActive)"] = image
          return image
      }
  }
  var chatScam: CGImage {
      if let image = cached["chatScam"] {
          return image
      } else {
          let image = _chatScam()
          cached["(chatScam)"] = image
          return image
      }
  }
  var chatUnarchive: CGImage {
      if let image = cached["chatUnarchive"] {
          return image
      } else {
          let image = _chatUnarchive()
          cached["(chatUnarchive)"] = image
          return image
      }
  }
  var chatArchive: CGImage {
      if let image = cached["chatArchive"] {
          return image
      } else {
          let image = _chatArchive()
          cached["(chatArchive)"] = image
          return image
      }
  }
  var privacySettings_blocked: CGImage {
      if let image = cached["privacySettings_blocked"] {
          return image
      } else {
          let image = _privacySettings_blocked()
          cached["(privacySettings_blocked)"] = image
          return image
      }
  }
  var privacySettings_activeSessions: CGImage {
      if let image = cached["privacySettings_activeSessions"] {
          return image
      } else {
          let image = _privacySettings_activeSessions()
          cached["(privacySettings_activeSessions)"] = image
          return image
      }
  }
  var privacySettings_passcode: CGImage {
      if let image = cached["privacySettings_passcode"] {
          return image
      } else {
          let image = _privacySettings_passcode()
          cached["(privacySettings_passcode)"] = image
          return image
      }
  }
  var privacySettings_twoStep: CGImage {
      if let image = cached["privacySettings_twoStep"] {
          return image
      } else {
          let image = _privacySettings_twoStep()
          cached["(privacySettings_twoStep)"] = image
          return image
      }
  }
  var deletedAccount: CGImage {
      if let image = cached["deletedAccount"] {
          return image
      } else {
          let image = _deletedAccount()
          cached["(deletedAccount)"] = image
          return image
      }
  }
  var stickerPackSelection: CGImage {
      if let image = cached["stickerPackSelection"] {
          return image
      } else {
          let image = _stickerPackSelection()
          cached["(stickerPackSelection)"] = image
          return image
      }
  }
  var stickerPackSelectionActive: CGImage {
      if let image = cached["stickerPackSelectionActive"] {
          return image
      } else {
          let image = _stickerPackSelectionActive()
          cached["(stickerPackSelectionActive)"] = image
          return image
      }
  }
  var entertainment_Emoji: CGImage {
      if let image = cached["entertainment_Emoji"] {
          return image
      } else {
          let image = _entertainment_Emoji()
          cached["(entertainment_Emoji)"] = image
          return image
      }
  }
  var entertainment_Stickers: CGImage {
      if let image = cached["entertainment_Stickers"] {
          return image
      } else {
          let image = _entertainment_Stickers()
          cached["(entertainment_Stickers)"] = image
          return image
      }
  }
  var entertainment_Gifs: CGImage {
      if let image = cached["entertainment_Gifs"] {
          return image
      } else {
          let image = _entertainment_Gifs()
          cached["(entertainment_Gifs)"] = image
          return image
      }
  }
  var entertainment_Search: CGImage {
      if let image = cached["entertainment_Search"] {
          return image
      } else {
          let image = _entertainment_Search()
          cached["(entertainment_Search)"] = image
          return image
      }
  }
  var entertainment_Settings: CGImage {
      if let image = cached["entertainment_Settings"] {
          return image
      } else {
          let image = _entertainment_Settings()
          cached["(entertainment_Settings)"] = image
          return image
      }
  }
  var entertainment_SearchCancel: CGImage {
      if let image = cached["entertainment_SearchCancel"] {
          return image
      } else {
          let image = _entertainment_SearchCancel()
          cached["(entertainment_SearchCancel)"] = image
          return image
      }
  }
  var scheduledAvatar: CGImage {
      if let image = cached["scheduledAvatar"] {
          return image
      } else {
          let image = _scheduledAvatar()
          cached["(scheduledAvatar)"] = image
          return image
      }
  }
  var scheduledInputAction: CGImage {
      if let image = cached["scheduledInputAction"] {
          return image
      } else {
          let image = _scheduledInputAction()
          cached["(scheduledInputAction)"] = image
          return image
      }
  }

  private var _dialogMuteImage: ()->CGImage
  private var _dialogMuteImageSelected: ()->CGImage
  private var _outgoingMessageImage: ()->CGImage
  private var _readMessageImage: ()->CGImage
  private var _outgoingMessageImageSelected: ()->CGImage
  private var _readMessageImageSelected: ()->CGImage
  private var _sendingImage: ()->CGImage
  private var _sendingImageSelected: ()->CGImage
  private var _secretImage: ()->CGImage
  private var _secretImageSelected: ()->CGImage
  private var _pinnedImage: ()->CGImage
  private var _pinnedImageSelected: ()->CGImage
  private var _verifiedImage: ()->CGImage
  private var _verifiedImageSelected: ()->CGImage
  private var _errorImage: ()->CGImage
  private var _errorImageSelected: ()->CGImage
  private var _chatSearch: ()->CGImage
  private var _chatCall: ()->CGImage
  private var _chatActions: ()->CGImage
  private var _chatFailedCall_incoming: ()->CGImage
  private var _chatFailedCall_outgoing: ()->CGImage
  private var _chatCall_incoming: ()->CGImage
  private var _chatCall_outgoing: ()->CGImage
  private var _chatFailedCallBubble_incoming: ()->CGImage
  private var _chatFailedCallBubble_outgoing: ()->CGImage
  private var _chatCallBubble_incoming: ()->CGImage
  private var _chatCallBubble_outgoing: ()->CGImage
  private var _chatFallbackCall: ()->CGImage
  private var _chatFallbackCallBubble_incoming: ()->CGImage
  private var _chatFallbackCallBubble_outgoing: ()->CGImage
  private var _chatToggleSelected: ()->CGImage
  private var _chatToggleUnselected: ()->CGImage
  private var _chatShare: ()->CGImage
  private var _chatMusicPlay: ()->CGImage
  private var _chatMusicPlayBubble_incoming: ()->CGImage
  private var _chatMusicPlayBubble_outgoing: ()->CGImage
  private var _chatMusicPause: ()->CGImage
  private var _chatMusicPauseBubble_incoming: ()->CGImage
  private var _chatMusicPauseBubble_outgoing: ()->CGImage
  private var _composeNewChat: ()->CGImage
  private var _composeNewChatActive: ()->CGImage
  private var _composeNewGroup: ()->CGImage
  private var _composeNewSecretChat: ()->CGImage
  private var _composeNewChannel: ()->CGImage
  private var _contactsNewContact: ()->CGImage
  private var _chatReadMarkInBubble1_incoming: ()->CGImage
  private var _chatReadMarkInBubble2_incoming: ()->CGImage
  private var _chatReadMarkInBubble1_outgoing: ()->CGImage
  private var _chatReadMarkInBubble2_outgoing: ()->CGImage
  private var _chatReadMarkOutBubble1: ()->CGImage
  private var _chatReadMarkOutBubble2: ()->CGImage
  private var _chatReadMarkOverlayBubble1: ()->CGImage
  private var _chatReadMarkOverlayBubble2: ()->CGImage
  private var _sentFailed: ()->CGImage
  private var _chatChannelViewsInBubble_incoming: ()->CGImage
  private var _chatChannelViewsInBubble_outgoing: ()->CGImage
  private var _chatChannelViewsOutBubble: ()->CGImage
  private var _chatChannelViewsOverlayBubble: ()->CGImage
  private var _chatNavigationBack: ()->CGImage
  private var _peerInfoAddMember: ()->CGImage
  private var _chatSearchUp: ()->CGImage
  private var _chatSearchUpDisabled: ()->CGImage
  private var _chatSearchDown: ()->CGImage
  private var _chatSearchDownDisabled: ()->CGImage
  private var _chatSearchCalendar: ()->CGImage
  private var _dismissAccessory: ()->CGImage
  private var _chatScrollUp: ()->CGImage
  private var _chatScrollUpActive: ()->CGImage
  private var _audioPlayerPlay: ()->CGImage
  private var _audioPlayerPause: ()->CGImage
  private var _audioPlayerNext: ()->CGImage
  private var _audioPlayerPrev: ()->CGImage
  private var _auduiPlayerDismiss: ()->CGImage
  private var _audioPlayerRepeat: ()->CGImage
  private var _audioPlayerRepeatActive: ()->CGImage
  private var _audioPlayerLockedPlay: ()->CGImage
  private var _audioPlayerLockedNext: ()->CGImage
  private var _audioPlayerLockedPrev: ()->CGImage
  private var _chatSendMessage: ()->CGImage
  private var _chatRecordVoice: ()->CGImage
  private var _chatEntertainment: ()->CGImage
  private var _chatInlineDismiss: ()->CGImage
  private var _chatActiveReplyMarkup: ()->CGImage
  private var _chatDisabledReplyMarkup: ()->CGImage
  private var _chatSecretTimer: ()->CGImage
  private var _chatForwardMessagesActive: ()->CGImage
  private var _chatForwardMessagesInactive: ()->CGImage
  private var _chatDeleteMessagesActive: ()->CGImage
  private var _chatDeleteMessagesInactive: ()->CGImage
  private var _generalNext: ()->CGImage
  private var _generalNextActive: ()->CGImage
  private var _generalSelect: ()->CGImage
  private var _chatVoiceRecording: ()->CGImage
  private var _chatVideoRecording: ()->CGImage
  private var _chatRecord: ()->CGImage
  private var _deleteItem: ()->CGImage
  private var _deleteItemDisabled: ()->CGImage
  private var _chatAttach: ()->CGImage
  private var _chatAttachFile: ()->CGImage
  private var _chatAttachPhoto: ()->CGImage
  private var _chatAttachCamera: ()->CGImage
  private var _chatAttachLocation: ()->CGImage
  private var _chatAttachPoll: ()->CGImage
  private var _mediaEmptyShared: ()->CGImage
  private var _mediaEmptyFiles: ()->CGImage
  private var _mediaEmptyMusic: ()->CGImage
  private var _mediaEmptyLinks: ()->CGImage
  private var _mediaDropdown: ()->CGImage
  private var _stickersAddFeatured: ()->CGImage
  private var _stickersAddedFeatured: ()->CGImage
  private var _stickersRemove: ()->CGImage
  private var _peerMediaDownloadFileStart: ()->CGImage
  private var _peerMediaDownloadFilePause: ()->CGImage
  private var _stickersShare: ()->CGImage
  private var _emojiRecentTab: ()->CGImage
  private var _emojiSmileTab: ()->CGImage
  private var _emojiNatureTab: ()->CGImage
  private var _emojiFoodTab: ()->CGImage
  private var _emojiSportTab: ()->CGImage
  private var _emojiCarTab: ()->CGImage
  private var _emojiObjectsTab: ()->CGImage
  private var _emojiSymbolsTab: ()->CGImage
  private var _emojiFlagsTab: ()->CGImage
  private var _emojiRecentTabActive: ()->CGImage
  private var _emojiSmileTabActive: ()->CGImage
  private var _emojiNatureTabActive: ()->CGImage
  private var _emojiFoodTabActive: ()->CGImage
  private var _emojiSportTabActive: ()->CGImage
  private var _emojiCarTabActive: ()->CGImage
  private var _emojiObjectsTabActive: ()->CGImage
  private var _emojiSymbolsTabActive: ()->CGImage
  private var _emojiFlagsTabActive: ()->CGImage
  private var _stickerBackground: ()->CGImage
  private var _stickerBackgroundActive: ()->CGImage
  private var _stickersTabRecent: ()->CGImage
  private var _stickersTabGIF: ()->CGImage
  private var _chatSendingInFrame_incoming: ()->CGImage
  private var _chatSendingInHour_incoming: ()->CGImage
  private var _chatSendingInMin_incoming: ()->CGImage
  private var _chatSendingInFrame_outgoing: ()->CGImage
  private var _chatSendingInHour_outgoing: ()->CGImage
  private var _chatSendingInMin_outgoing: ()->CGImage
  private var _chatSendingOutFrame: ()->CGImage
  private var _chatSendingOutHour: ()->CGImage
  private var _chatSendingOutMin: ()->CGImage
  private var _chatSendingOverlayFrame: ()->CGImage
  private var _chatSendingOverlayHour: ()->CGImage
  private var _chatSendingOverlayMin: ()->CGImage
  private var _chatActionUrl: ()->CGImage
  private var _callInlineDecline: ()->CGImage
  private var _callInlineMuted: ()->CGImage
  private var _callInlineUnmuted: ()->CGImage
  private var _eventLogTriangle: ()->CGImage
  private var _channelIntro: ()->CGImage
  private var _chatFileThumb: ()->CGImage
  private var _chatFileThumbBubble_incoming: ()->CGImage
  private var _chatFileThumbBubble_outgoing: ()->CGImage
  private var _chatSecretThumb: ()->CGImage
  private var _chatMapPin: ()->CGImage
  private var _chatSecretTitle: ()->CGImage
  private var _emptySearch: ()->CGImage
  private var _calendarBack: ()->CGImage
  private var _calendarNext: ()->CGImage
  private var _calendarBackDisabled: ()->CGImage
  private var _calendarNextDisabled: ()->CGImage
  private var _newChatCamera: ()->CGImage
  private var _peerInfoVerify: ()->CGImage
  private var _peerInfoCall: ()->CGImage
  private var _callOutgoing: ()->CGImage
  private var _recentDismiss: ()->CGImage
  private var _recentDismissActive: ()->CGImage
  private var _webgameShare: ()->CGImage
  private var _chatSearchCancel: ()->CGImage
  private var _chatSearchFrom: ()->CGImage
  private var _callWindowDecline: ()->CGImage
  private var _callWindowAccept: ()->CGImage
  private var _callWindowMute: ()->CGImage
  private var _callWindowUnmute: ()->CGImage
  private var _callWindowClose: ()->CGImage
  private var _callWindowDeviceSettings: ()->CGImage
  private var _callSettings: ()->CGImage
  private var _callWindowCancel: ()->CGImage
  private var _chatActionEdit: ()->CGImage
  private var _chatActionInfo: ()->CGImage
  private var _chatActionMute: ()->CGImage
  private var _chatActionUnmute: ()->CGImage
  private var _chatActionClearHistory: ()->CGImage
  private var _chatActionDeleteChat: ()->CGImage
  private var _dismissPinned: ()->CGImage
  private var _chatActionsActive: ()->CGImage
  private var _chatEntertainmentSticker: ()->CGImage
  private var _chatEmpty: ()->CGImage
  private var _stickerPackClose: ()->CGImage
  private var _stickerPackDelete: ()->CGImage
  private var _modalShare: ()->CGImage
  private var _modalClose: ()->CGImage
  private var _ivChannelJoined: ()->CGImage
  private var _chatListMention: ()->CGImage
  private var _chatListMentionActive: ()->CGImage
  private var _chatListMentionArchived: ()->CGImage
  private var _chatListMentionArchivedActive: ()->CGImage
  private var _chatMention: ()->CGImage
  private var _chatMentionActive: ()->CGImage
  private var _sliderControl: ()->CGImage
  private var _sliderControlActive: ()->CGImage
  private var _stickersTabFave: ()->CGImage
  private var _chatInstantView: ()->CGImage
  private var _chatInstantViewBubble_incoming: ()->CGImage
  private var _chatInstantViewBubble_outgoing: ()->CGImage
  private var _instantViewShare: ()->CGImage
  private var _instantViewActions: ()->CGImage
  private var _instantViewActionsActive: ()->CGImage
  private var _instantViewSafari: ()->CGImage
  private var _instantViewBack: ()->CGImage
  private var _instantViewCheck: ()->CGImage
  private var _groupStickerNotFound: ()->CGImage
  private var _settingsAskQuestion: ()->CGImage
  private var _settingsFaq: ()->CGImage
  private var _settingsGeneral: ()->CGImage
  private var _settingsLanguage: ()->CGImage
  private var _settingsNotifications: ()->CGImage
  private var _settingsSecurity: ()->CGImage
  private var _settingsStickers: ()->CGImage
  private var _settingsStorage: ()->CGImage
  private var _settingsProxy: ()->CGImage
  private var _settingsAppearance: ()->CGImage
  private var _settingsPassport: ()->CGImage
  private var _settingsUpdate: ()->CGImage
  private var _settingsAskQuestionActive: ()->CGImage
  private var _settingsFaqActive: ()->CGImage
  private var _settingsGeneralActive: ()->CGImage
  private var _settingsLanguageActive: ()->CGImage
  private var _settingsNotificationsActive: ()->CGImage
  private var _settingsSecurityActive: ()->CGImage
  private var _settingsStickersActive: ()->CGImage
  private var _settingsStorageActive: ()->CGImage
  private var _settingsProxyActive: ()->CGImage
  private var _settingsAppearanceActive: ()->CGImage
  private var _settingsPassportActive: ()->CGImage
  private var _settingsUpdateActive: ()->CGImage
  private var _generalCheck: ()->CGImage
  private var _settingsAbout: ()->CGImage
  private var _settingsLogout: ()->CGImage
  private var _fastSettingsLock: ()->CGImage
  private var _fastSettingsDark: ()->CGImage
  private var _fastSettingsSunny: ()->CGImage
  private var _fastSettingsMute: ()->CGImage
  private var _fastSettingsUnmute: ()->CGImage
  private var _chatRecordVideo: ()->CGImage
  private var _inputChannelMute: ()->CGImage
  private var _inputChannelUnmute: ()->CGImage
  private var _changePhoneNumberIntro: ()->CGImage
  private var _peerSavedMessages: ()->CGImage
  private var _previewCollage: ()->CGImage
  private var _chatGoMessage: ()->CGImage
  private var _chatGroupToggleSelected: ()->CGImage
  private var _chatGroupToggleUnselected: ()->CGImage
  private var _successModalProgress: ()->CGImage
  private var _accentColorSelect: ()->CGImage
  private var _chatShareWallpaper: ()->CGImage
  private var _chatGotoMessageWallpaper: ()->CGImage
  private var _transparentBackground: ()->CGImage
  private var _lottieTransparentBackground: ()->CGImage
  private var _passcodeTouchId: ()->CGImage
  private var _passcodeLogin: ()->CGImage
  private var _confirmDeleteMessagesAccessory: ()->CGImage
  private var _alertCheckBoxSelected: ()->CGImage
  private var _alertCheckBoxUnselected: ()->CGImage
  private var _confirmPinAccessory: ()->CGImage
  private var _confirmDeleteChatAccessory: ()->CGImage
  private var _stickersEmptySearch: ()->CGImage
  private var _twoStepVerificationCreateIntro: ()->CGImage
  private var _secureIdAuth: ()->CGImage
  private var _ivAudioPlay: ()->CGImage
  private var _ivAudioPause: ()->CGImage
  private var _proxyEnable: ()->CGImage
  private var _proxyEnabled: ()->CGImage
  private var _proxyState: ()->CGImage
  private var _proxyDeleteListItem: ()->CGImage
  private var _proxyInfoListItem: ()->CGImage
  private var _proxyConnectedListItem: ()->CGImage
  private var _proxyAddProxy: ()->CGImage
  private var _proxyNextWaitingListItem: ()->CGImage
  private var _passportForgotPassword: ()->CGImage
  private var _confirmAppAccessoryIcon: ()->CGImage
  private var _passportPassport: ()->CGImage
  private var _passportIdCardReverse: ()->CGImage
  private var _passportIdCard: ()->CGImage
  private var _passportSelfie: ()->CGImage
  private var _passportDriverLicense: ()->CGImage
  private var _chatOverlayVoiceRecording: ()->CGImage
  private var _chatOverlayVideoRecording: ()->CGImage
  private var _chatOverlaySendRecording: ()->CGImage
  private var _chatOverlayLockArrowRecording: ()->CGImage
  private var _chatOverlayLockerBodyRecording: ()->CGImage
  private var _chatOverlayLockerHeadRecording: ()->CGImage
  private var _locationPin: ()->CGImage
  private var _locationMapPin: ()->CGImage
  private var _locationMapLocate: ()->CGImage
  private var _locationMapLocated: ()->CGImage
  private var _chatTabIconSelected: ()->CGImage
  private var _chatTabIconSelectedUp: ()->CGImage
  private var _chatTabIconSelectedDown: ()->CGImage
  private var _chatTabIcon: ()->CGImage
  private var _passportSettings: ()->CGImage
  private var _passportInfo: ()->CGImage
  private var _editMessageMedia: ()->CGImage
  private var _playerMusicPlaceholder: ()->CGImage
  private var _chatMusicPlaceholder: ()->CGImage
  private var _chatMusicPlaceholderCap: ()->CGImage
  private var _searchArticle: ()->CGImage
  private var _searchSaved: ()->CGImage
  private var _archivedChats: ()->CGImage
  private var _hintPeerActive: ()->CGImage
  private var _hintPeerActiveSelected: ()->CGImage
  private var _chatSwiping_delete: ()->CGImage
  private var _chatSwiping_mute: ()->CGImage
  private var _chatSwiping_unmute: ()->CGImage
  private var _chatSwiping_read: ()->CGImage
  private var _chatSwiping_unread: ()->CGImage
  private var _chatSwiping_pin: ()->CGImage
  private var _chatSwiping_unpin: ()->CGImage
  private var _chatSwiping_archive: ()->CGImage
  private var _chatSwiping_unarchive: ()->CGImage
  private var _galleryPrev: ()->CGImage
  private var _galleryNext: ()->CGImage
  private var _galleryMore: ()->CGImage
  private var _galleryShare: ()->CGImage
  private var _galleryFastSave: ()->CGImage
  private var _playingVoice1x: ()->CGImage
  private var _playingVoice2x: ()->CGImage
  private var _galleryRotate: ()->CGImage
  private var _galleryZoomIn: ()->CGImage
  private var _galleryZoomOut: ()->CGImage
  private var _previewSenderCrop: ()->CGImage
  private var _previewSenderDelete: ()->CGImage
  private var _editMessageCurrentPhoto: ()->CGImage
  private var _previewSenderDeleteFile: ()->CGImage
  private var _previewSenderArchive: ()->CGImage
  private var _chatSwipeReply: ()->CGImage
  private var _chatSwipeReplyWallpaper: ()->CGImage
  private var _videoPlayerPlay: ()->CGImage
  private var _videoPlayerPause: ()->CGImage
  private var _videoPlayerEnterFullScreen: ()->CGImage
  private var _videoPlayerExitFullScreen: ()->CGImage
  private var _videoPlayerPIPIn: ()->CGImage
  private var _videoPlayerPIPOut: ()->CGImage
  private var _videoPlayerRewind15Forward: ()->CGImage
  private var _videoPlayerRewind15Backward: ()->CGImage
  private var _videoPlayerVolume: ()->CGImage
  private var _videoPlayerVolumeOff: ()->CGImage
  private var _videoPlayerClose: ()->CGImage
  private var _videoPlayerSliderInteractor: ()->CGImage
  private var _streamingVideoDownload: ()->CGImage
  private var _videoCompactFetching: ()->CGImage
  private var _compactStreamingFetchingCancel: ()->CGImage
  private var _customLocalizationDelete: ()->CGImage
  private var _pollAddOption: ()->CGImage
  private var _pollDeleteOption: ()->CGImage
  private var _resort: ()->CGImage
  private var _chatPollVoteUnselected: ()->CGImage
  private var _chatPollVoteUnselectedBubble_incoming: ()->CGImage
  private var _chatPollVoteUnselectedBubble_outgoing: ()->CGImage
  private var _peerInfoAdmins: ()->CGImage
  private var _peerInfoPermissions: ()->CGImage
  private var _peerInfoBanned: ()->CGImage
  private var _peerInfoMembers: ()->CGImage
  private var _chatUndoAction: ()->CGImage
  private var _appUpdate: ()->CGImage
  private var _inlineVideoSoundOff: ()->CGImage
  private var _inlineVideoSoundOn: ()->CGImage
  private var _logoutOptionAddAccount: ()->CGImage
  private var _logoutOptionSetPasscode: ()->CGImage
  private var _logoutOptionClearCache: ()->CGImage
  private var _logoutOptionChangePhoneNumber: ()->CGImage
  private var _logoutOptionContactSupport: ()->CGImage
  private var _disableEmojiPrediction: ()->CGImage
  private var _scam: ()->CGImage
  private var _scamActive: ()->CGImage
  private var _chatScam: ()->CGImage
  private var _chatUnarchive: ()->CGImage
  private var _chatArchive: ()->CGImage
  private var _privacySettings_blocked: ()->CGImage
  private var _privacySettings_activeSessions: ()->CGImage
  private var _privacySettings_passcode: ()->CGImage
  private var _privacySettings_twoStep: ()->CGImage
  private var _deletedAccount: ()->CGImage
  private var _stickerPackSelection: ()->CGImage
  private var _stickerPackSelectionActive: ()->CGImage
  private var _entertainment_Emoji: ()->CGImage
  private var _entertainment_Stickers: ()->CGImage
  private var _entertainment_Gifs: ()->CGImage
  private var _entertainment_Search: ()->CGImage
  private var _entertainment_Settings: ()->CGImage
  private var _entertainment_SearchCancel: ()->CGImage
  private var _scheduledAvatar: ()->CGImage
  private var _scheduledInputAction: ()->CGImage

  init(
      dialogMuteImage: @escaping()->CGImage,
      dialogMuteImageSelected: @escaping()->CGImage,
      outgoingMessageImage: @escaping()->CGImage,
      readMessageImage: @escaping()->CGImage,
      outgoingMessageImageSelected: @escaping()->CGImage,
      readMessageImageSelected: @escaping()->CGImage,
      sendingImage: @escaping()->CGImage,
      sendingImageSelected: @escaping()->CGImage,
      secretImage: @escaping()->CGImage,
      secretImageSelected: @escaping()->CGImage,
      pinnedImage: @escaping()->CGImage,
      pinnedImageSelected: @escaping()->CGImage,
      verifiedImage: @escaping()->CGImage,
      verifiedImageSelected: @escaping()->CGImage,
      errorImage: @escaping()->CGImage,
      errorImageSelected: @escaping()->CGImage,
      chatSearch: @escaping()->CGImage,
      chatCall: @escaping()->CGImage,
      chatActions: @escaping()->CGImage,
      chatFailedCall_incoming: @escaping()->CGImage,
      chatFailedCall_outgoing: @escaping()->CGImage,
      chatCall_incoming: @escaping()->CGImage,
      chatCall_outgoing: @escaping()->CGImage,
      chatFailedCallBubble_incoming: @escaping()->CGImage,
      chatFailedCallBubble_outgoing: @escaping()->CGImage,
      chatCallBubble_incoming: @escaping()->CGImage,
      chatCallBubble_outgoing: @escaping()->CGImage,
      chatFallbackCall: @escaping()->CGImage,
      chatFallbackCallBubble_incoming: @escaping()->CGImage,
      chatFallbackCallBubble_outgoing: @escaping()->CGImage,
      chatToggleSelected: @escaping()->CGImage,
      chatToggleUnselected: @escaping()->CGImage,
      chatShare: @escaping()->CGImage,
      chatMusicPlay: @escaping()->CGImage,
      chatMusicPlayBubble_incoming: @escaping()->CGImage,
      chatMusicPlayBubble_outgoing: @escaping()->CGImage,
      chatMusicPause: @escaping()->CGImage,
      chatMusicPauseBubble_incoming: @escaping()->CGImage,
      chatMusicPauseBubble_outgoing: @escaping()->CGImage,
      composeNewChat: @escaping()->CGImage,
      composeNewChatActive: @escaping()->CGImage,
      composeNewGroup: @escaping()->CGImage,
      composeNewSecretChat: @escaping()->CGImage,
      composeNewChannel: @escaping()->CGImage,
      contactsNewContact: @escaping()->CGImage,
      chatReadMarkInBubble1_incoming: @escaping()->CGImage,
      chatReadMarkInBubble2_incoming: @escaping()->CGImage,
      chatReadMarkInBubble1_outgoing: @escaping()->CGImage,
      chatReadMarkInBubble2_outgoing: @escaping()->CGImage,
      chatReadMarkOutBubble1: @escaping()->CGImage,
      chatReadMarkOutBubble2: @escaping()->CGImage,
      chatReadMarkOverlayBubble1: @escaping()->CGImage,
      chatReadMarkOverlayBubble2: @escaping()->CGImage,
      sentFailed: @escaping()->CGImage,
      chatChannelViewsInBubble_incoming: @escaping()->CGImage,
      chatChannelViewsInBubble_outgoing: @escaping()->CGImage,
      chatChannelViewsOutBubble: @escaping()->CGImage,
      chatChannelViewsOverlayBubble: @escaping()->CGImage,
      chatNavigationBack: @escaping()->CGImage,
      peerInfoAddMember: @escaping()->CGImage,
      chatSearchUp: @escaping()->CGImage,
      chatSearchUpDisabled: @escaping()->CGImage,
      chatSearchDown: @escaping()->CGImage,
      chatSearchDownDisabled: @escaping()->CGImage,
      chatSearchCalendar: @escaping()->CGImage,
      dismissAccessory: @escaping()->CGImage,
      chatScrollUp: @escaping()->CGImage,
      chatScrollUpActive: @escaping()->CGImage,
      audioPlayerPlay: @escaping()->CGImage,
      audioPlayerPause: @escaping()->CGImage,
      audioPlayerNext: @escaping()->CGImage,
      audioPlayerPrev: @escaping()->CGImage,
      auduiPlayerDismiss: @escaping()->CGImage,
      audioPlayerRepeat: @escaping()->CGImage,
      audioPlayerRepeatActive: @escaping()->CGImage,
      audioPlayerLockedPlay: @escaping()->CGImage,
      audioPlayerLockedNext: @escaping()->CGImage,
      audioPlayerLockedPrev: @escaping()->CGImage,
      chatSendMessage: @escaping()->CGImage,
      chatRecordVoice: @escaping()->CGImage,
      chatEntertainment: @escaping()->CGImage,
      chatInlineDismiss: @escaping()->CGImage,
      chatActiveReplyMarkup: @escaping()->CGImage,
      chatDisabledReplyMarkup: @escaping()->CGImage,
      chatSecretTimer: @escaping()->CGImage,
      chatForwardMessagesActive: @escaping()->CGImage,
      chatForwardMessagesInactive: @escaping()->CGImage,
      chatDeleteMessagesActive: @escaping()->CGImage,
      chatDeleteMessagesInactive: @escaping()->CGImage,
      generalNext: @escaping()->CGImage,
      generalNextActive: @escaping()->CGImage,
      generalSelect: @escaping()->CGImage,
      chatVoiceRecording: @escaping()->CGImage,
      chatVideoRecording: @escaping()->CGImage,
      chatRecord: @escaping()->CGImage,
      deleteItem: @escaping()->CGImage,
      deleteItemDisabled: @escaping()->CGImage,
      chatAttach: @escaping()->CGImage,
      chatAttachFile: @escaping()->CGImage,
      chatAttachPhoto: @escaping()->CGImage,
      chatAttachCamera: @escaping()->CGImage,
      chatAttachLocation: @escaping()->CGImage,
      chatAttachPoll: @escaping()->CGImage,
      mediaEmptyShared: @escaping()->CGImage,
      mediaEmptyFiles: @escaping()->CGImage,
      mediaEmptyMusic: @escaping()->CGImage,
      mediaEmptyLinks: @escaping()->CGImage,
      mediaDropdown: @escaping()->CGImage,
      stickersAddFeatured: @escaping()->CGImage,
      stickersAddedFeatured: @escaping()->CGImage,
      stickersRemove: @escaping()->CGImage,
      peerMediaDownloadFileStart: @escaping()->CGImage,
      peerMediaDownloadFilePause: @escaping()->CGImage,
      stickersShare: @escaping()->CGImage,
      emojiRecentTab: @escaping()->CGImage,
      emojiSmileTab: @escaping()->CGImage,
      emojiNatureTab: @escaping()->CGImage,
      emojiFoodTab: @escaping()->CGImage,
      emojiSportTab: @escaping()->CGImage,
      emojiCarTab: @escaping()->CGImage,
      emojiObjectsTab: @escaping()->CGImage,
      emojiSymbolsTab: @escaping()->CGImage,
      emojiFlagsTab: @escaping()->CGImage,
      emojiRecentTabActive: @escaping()->CGImage,
      emojiSmileTabActive: @escaping()->CGImage,
      emojiNatureTabActive: @escaping()->CGImage,
      emojiFoodTabActive: @escaping()->CGImage,
      emojiSportTabActive: @escaping()->CGImage,
      emojiCarTabActive: @escaping()->CGImage,
      emojiObjectsTabActive: @escaping()->CGImage,
      emojiSymbolsTabActive: @escaping()->CGImage,
      emojiFlagsTabActive: @escaping()->CGImage,
      stickerBackground: @escaping()->CGImage,
      stickerBackgroundActive: @escaping()->CGImage,
      stickersTabRecent: @escaping()->CGImage,
      stickersTabGIF: @escaping()->CGImage,
      chatSendingInFrame_incoming: @escaping()->CGImage,
      chatSendingInHour_incoming: @escaping()->CGImage,
      chatSendingInMin_incoming: @escaping()->CGImage,
      chatSendingInFrame_outgoing: @escaping()->CGImage,
      chatSendingInHour_outgoing: @escaping()->CGImage,
      chatSendingInMin_outgoing: @escaping()->CGImage,
      chatSendingOutFrame: @escaping()->CGImage,
      chatSendingOutHour: @escaping()->CGImage,
      chatSendingOutMin: @escaping()->CGImage,
      chatSendingOverlayFrame: @escaping()->CGImage,
      chatSendingOverlayHour: @escaping()->CGImage,
      chatSendingOverlayMin: @escaping()->CGImage,
      chatActionUrl: @escaping()->CGImage,
      callInlineDecline: @escaping()->CGImage,
      callInlineMuted: @escaping()->CGImage,
      callInlineUnmuted: @escaping()->CGImage,
      eventLogTriangle: @escaping()->CGImage,
      channelIntro: @escaping()->CGImage,
      chatFileThumb: @escaping()->CGImage,
      chatFileThumbBubble_incoming: @escaping()->CGImage,
      chatFileThumbBubble_outgoing: @escaping()->CGImage,
      chatSecretThumb: @escaping()->CGImage,
      chatMapPin: @escaping()->CGImage,
      chatSecretTitle: @escaping()->CGImage,
      emptySearch: @escaping()->CGImage,
      calendarBack: @escaping()->CGImage,
      calendarNext: @escaping()->CGImage,
      calendarBackDisabled: @escaping()->CGImage,
      calendarNextDisabled: @escaping()->CGImage,
      newChatCamera: @escaping()->CGImage,
      peerInfoVerify: @escaping()->CGImage,
      peerInfoCall: @escaping()->CGImage,
      callOutgoing: @escaping()->CGImage,
      recentDismiss: @escaping()->CGImage,
      recentDismissActive: @escaping()->CGImage,
      webgameShare: @escaping()->CGImage,
      chatSearchCancel: @escaping()->CGImage,
      chatSearchFrom: @escaping()->CGImage,
      callWindowDecline: @escaping()->CGImage,
      callWindowAccept: @escaping()->CGImage,
      callWindowMute: @escaping()->CGImage,
      callWindowUnmute: @escaping()->CGImage,
      callWindowClose: @escaping()->CGImage,
      callWindowDeviceSettings: @escaping()->CGImage,
      callSettings: @escaping()->CGImage,
      callWindowCancel: @escaping()->CGImage,
      chatActionEdit: @escaping()->CGImage,
      chatActionInfo: @escaping()->CGImage,
      chatActionMute: @escaping()->CGImage,
      chatActionUnmute: @escaping()->CGImage,
      chatActionClearHistory: @escaping()->CGImage,
      chatActionDeleteChat: @escaping()->CGImage,
      dismissPinned: @escaping()->CGImage,
      chatActionsActive: @escaping()->CGImage,
      chatEntertainmentSticker: @escaping()->CGImage,
      chatEmpty: @escaping()->CGImage,
      stickerPackClose: @escaping()->CGImage,
      stickerPackDelete: @escaping()->CGImage,
      modalShare: @escaping()->CGImage,
      modalClose: @escaping()->CGImage,
      ivChannelJoined: @escaping()->CGImage,
      chatListMention: @escaping()->CGImage,
      chatListMentionActive: @escaping()->CGImage,
      chatListMentionArchived: @escaping()->CGImage,
      chatListMentionArchivedActive: @escaping()->CGImage,
      chatMention: @escaping()->CGImage,
      chatMentionActive: @escaping()->CGImage,
      sliderControl: @escaping()->CGImage,
      sliderControlActive: @escaping()->CGImage,
      stickersTabFave: @escaping()->CGImage,
      chatInstantView: @escaping()->CGImage,
      chatInstantViewBubble_incoming: @escaping()->CGImage,
      chatInstantViewBubble_outgoing: @escaping()->CGImage,
      instantViewShare: @escaping()->CGImage,
      instantViewActions: @escaping()->CGImage,
      instantViewActionsActive: @escaping()->CGImage,
      instantViewSafari: @escaping()->CGImage,
      instantViewBack: @escaping()->CGImage,
      instantViewCheck: @escaping()->CGImage,
      groupStickerNotFound: @escaping()->CGImage,
      settingsAskQuestion: @escaping()->CGImage,
      settingsFaq: @escaping()->CGImage,
      settingsGeneral: @escaping()->CGImage,
      settingsLanguage: @escaping()->CGImage,
      settingsNotifications: @escaping()->CGImage,
      settingsSecurity: @escaping()->CGImage,
      settingsStickers: @escaping()->CGImage,
      settingsStorage: @escaping()->CGImage,
      settingsProxy: @escaping()->CGImage,
      settingsAppearance: @escaping()->CGImage,
      settingsPassport: @escaping()->CGImage,
      settingsUpdate: @escaping()->CGImage,
      settingsAskQuestionActive: @escaping()->CGImage,
      settingsFaqActive: @escaping()->CGImage,
      settingsGeneralActive: @escaping()->CGImage,
      settingsLanguageActive: @escaping()->CGImage,
      settingsNotificationsActive: @escaping()->CGImage,
      settingsSecurityActive: @escaping()->CGImage,
      settingsStickersActive: @escaping()->CGImage,
      settingsStorageActive: @escaping()->CGImage,
      settingsProxyActive: @escaping()->CGImage,
      settingsAppearanceActive: @escaping()->CGImage,
      settingsPassportActive: @escaping()->CGImage,
      settingsUpdateActive: @escaping()->CGImage,
      generalCheck: @escaping()->CGImage,
      settingsAbout: @escaping()->CGImage,
      settingsLogout: @escaping()->CGImage,
      fastSettingsLock: @escaping()->CGImage,
      fastSettingsDark: @escaping()->CGImage,
      fastSettingsSunny: @escaping()->CGImage,
      fastSettingsMute: @escaping()->CGImage,
      fastSettingsUnmute: @escaping()->CGImage,
      chatRecordVideo: @escaping()->CGImage,
      inputChannelMute: @escaping()->CGImage,
      inputChannelUnmute: @escaping()->CGImage,
      changePhoneNumberIntro: @escaping()->CGImage,
      peerSavedMessages: @escaping()->CGImage,
      previewCollage: @escaping()->CGImage,
      chatGoMessage: @escaping()->CGImage,
      chatGroupToggleSelected: @escaping()->CGImage,
      chatGroupToggleUnselected: @escaping()->CGImage,
      successModalProgress: @escaping()->CGImage,
      accentColorSelect: @escaping()->CGImage,
      chatShareWallpaper: @escaping()->CGImage,
      chatGotoMessageWallpaper: @escaping()->CGImage,
      transparentBackground: @escaping()->CGImage,
      lottieTransparentBackground: @escaping()->CGImage,
      passcodeTouchId: @escaping()->CGImage,
      passcodeLogin: @escaping()->CGImage,
      confirmDeleteMessagesAccessory: @escaping()->CGImage,
      alertCheckBoxSelected: @escaping()->CGImage,
      alertCheckBoxUnselected: @escaping()->CGImage,
      confirmPinAccessory: @escaping()->CGImage,
      confirmDeleteChatAccessory: @escaping()->CGImage,
      stickersEmptySearch: @escaping()->CGImage,
      twoStepVerificationCreateIntro: @escaping()->CGImage,
      secureIdAuth: @escaping()->CGImage,
      ivAudioPlay: @escaping()->CGImage,
      ivAudioPause: @escaping()->CGImage,
      proxyEnable: @escaping()->CGImage,
      proxyEnabled: @escaping()->CGImage,
      proxyState: @escaping()->CGImage,
      proxyDeleteListItem: @escaping()->CGImage,
      proxyInfoListItem: @escaping()->CGImage,
      proxyConnectedListItem: @escaping()->CGImage,
      proxyAddProxy: @escaping()->CGImage,
      proxyNextWaitingListItem: @escaping()->CGImage,
      passportForgotPassword: @escaping()->CGImage,
      confirmAppAccessoryIcon: @escaping()->CGImage,
      passportPassport: @escaping()->CGImage,
      passportIdCardReverse: @escaping()->CGImage,
      passportIdCard: @escaping()->CGImage,
      passportSelfie: @escaping()->CGImage,
      passportDriverLicense: @escaping()->CGImage,
      chatOverlayVoiceRecording: @escaping()->CGImage,
      chatOverlayVideoRecording: @escaping()->CGImage,
      chatOverlaySendRecording: @escaping()->CGImage,
      chatOverlayLockArrowRecording: @escaping()->CGImage,
      chatOverlayLockerBodyRecording: @escaping()->CGImage,
      chatOverlayLockerHeadRecording: @escaping()->CGImage,
      locationPin: @escaping()->CGImage,
      locationMapPin: @escaping()->CGImage,
      locationMapLocate: @escaping()->CGImage,
      locationMapLocated: @escaping()->CGImage,
      chatTabIconSelected: @escaping()->CGImage,
      chatTabIconSelectedUp: @escaping()->CGImage,
      chatTabIconSelectedDown: @escaping()->CGImage,
      chatTabIcon: @escaping()->CGImage,
      passportSettings: @escaping()->CGImage,
      passportInfo: @escaping()->CGImage,
      editMessageMedia: @escaping()->CGImage,
      playerMusicPlaceholder: @escaping()->CGImage,
      chatMusicPlaceholder: @escaping()->CGImage,
      chatMusicPlaceholderCap: @escaping()->CGImage,
      searchArticle: @escaping()->CGImage,
      searchSaved: @escaping()->CGImage,
      archivedChats: @escaping()->CGImage,
      hintPeerActive: @escaping()->CGImage,
      hintPeerActiveSelected: @escaping()->CGImage,
      chatSwiping_delete: @escaping()->CGImage,
      chatSwiping_mute: @escaping()->CGImage,
      chatSwiping_unmute: @escaping()->CGImage,
      chatSwiping_read: @escaping()->CGImage,
      chatSwiping_unread: @escaping()->CGImage,
      chatSwiping_pin: @escaping()->CGImage,
      chatSwiping_unpin: @escaping()->CGImage,
      chatSwiping_archive: @escaping()->CGImage,
      chatSwiping_unarchive: @escaping()->CGImage,
      galleryPrev: @escaping()->CGImage,
      galleryNext: @escaping()->CGImage,
      galleryMore: @escaping()->CGImage,
      galleryShare: @escaping()->CGImage,
      galleryFastSave: @escaping()->CGImage,
      playingVoice1x: @escaping()->CGImage,
      playingVoice2x: @escaping()->CGImage,
      galleryRotate: @escaping()->CGImage,
      galleryZoomIn: @escaping()->CGImage,
      galleryZoomOut: @escaping()->CGImage,
      previewSenderCrop: @escaping()->CGImage,
      previewSenderDelete: @escaping()->CGImage,
      editMessageCurrentPhoto: @escaping()->CGImage,
      previewSenderDeleteFile: @escaping()->CGImage,
      previewSenderArchive: @escaping()->CGImage,
      chatSwipeReply: @escaping()->CGImage,
      chatSwipeReplyWallpaper: @escaping()->CGImage,
      videoPlayerPlay: @escaping()->CGImage,
      videoPlayerPause: @escaping()->CGImage,
      videoPlayerEnterFullScreen: @escaping()->CGImage,
      videoPlayerExitFullScreen: @escaping()->CGImage,
      videoPlayerPIPIn: @escaping()->CGImage,
      videoPlayerPIPOut: @escaping()->CGImage,
      videoPlayerRewind15Forward: @escaping()->CGImage,
      videoPlayerRewind15Backward: @escaping()->CGImage,
      videoPlayerVolume: @escaping()->CGImage,
      videoPlayerVolumeOff: @escaping()->CGImage,
      videoPlayerClose: @escaping()->CGImage,
      videoPlayerSliderInteractor: @escaping()->CGImage,
      streamingVideoDownload: @escaping()->CGImage,
      videoCompactFetching: @escaping()->CGImage,
      compactStreamingFetchingCancel: @escaping()->CGImage,
      customLocalizationDelete: @escaping()->CGImage,
      pollAddOption: @escaping()->CGImage,
      pollDeleteOption: @escaping()->CGImage,
      resort: @escaping()->CGImage,
      chatPollVoteUnselected: @escaping()->CGImage,
      chatPollVoteUnselectedBubble_incoming: @escaping()->CGImage,
      chatPollVoteUnselectedBubble_outgoing: @escaping()->CGImage,
      peerInfoAdmins: @escaping()->CGImage,
      peerInfoPermissions: @escaping()->CGImage,
      peerInfoBanned: @escaping()->CGImage,
      peerInfoMembers: @escaping()->CGImage,
      chatUndoAction: @escaping()->CGImage,
      appUpdate: @escaping()->CGImage,
      inlineVideoSoundOff: @escaping()->CGImage,
      inlineVideoSoundOn: @escaping()->CGImage,
      logoutOptionAddAccount: @escaping()->CGImage,
      logoutOptionSetPasscode: @escaping()->CGImage,
      logoutOptionClearCache: @escaping()->CGImage,
      logoutOptionChangePhoneNumber: @escaping()->CGImage,
      logoutOptionContactSupport: @escaping()->CGImage,
      disableEmojiPrediction: @escaping()->CGImage,
      scam: @escaping()->CGImage,
      scamActive: @escaping()->CGImage,
      chatScam: @escaping()->CGImage,
      chatUnarchive: @escaping()->CGImage,
      chatArchive: @escaping()->CGImage,
      privacySettings_blocked: @escaping()->CGImage,
      privacySettings_activeSessions: @escaping()->CGImage,
      privacySettings_passcode: @escaping()->CGImage,
      privacySettings_twoStep: @escaping()->CGImage,
      deletedAccount: @escaping()->CGImage,
      stickerPackSelection: @escaping()->CGImage,
      stickerPackSelectionActive: @escaping()->CGImage,
      entertainment_Emoji: @escaping()->CGImage,
      entertainment_Stickers: @escaping()->CGImage,
      entertainment_Gifs: @escaping()->CGImage,
      entertainment_Search: @escaping()->CGImage,
      entertainment_Settings: @escaping()->CGImage,
      entertainment_SearchCancel: @escaping()->CGImage,
      scheduledAvatar: @escaping()->CGImage,
      scheduledInputAction: @escaping()->CGImage
  ) {
      self._dialogMuteImage = dialogMuteImage
      self._dialogMuteImageSelected = dialogMuteImageSelected
      self._outgoingMessageImage = outgoingMessageImage
      self._readMessageImage = readMessageImage
      self._outgoingMessageImageSelected = outgoingMessageImageSelected
      self._readMessageImageSelected = readMessageImageSelected
      self._sendingImage = sendingImage
      self._sendingImageSelected = sendingImageSelected
      self._secretImage = secretImage
      self._secretImageSelected = secretImageSelected
      self._pinnedImage = pinnedImage
      self._pinnedImageSelected = pinnedImageSelected
      self._verifiedImage = verifiedImage
      self._verifiedImageSelected = verifiedImageSelected
      self._errorImage = errorImage
      self._errorImageSelected = errorImageSelected
      self._chatSearch = chatSearch
      self._chatCall = chatCall
      self._chatActions = chatActions
      self._chatFailedCall_incoming = chatFailedCall_incoming
      self._chatFailedCall_outgoing = chatFailedCall_outgoing
      self._chatCall_incoming = chatCall_incoming
      self._chatCall_outgoing = chatCall_outgoing
      self._chatFailedCallBubble_incoming = chatFailedCallBubble_incoming
      self._chatFailedCallBubble_outgoing = chatFailedCallBubble_outgoing
      self._chatCallBubble_incoming = chatCallBubble_incoming
      self._chatCallBubble_outgoing = chatCallBubble_outgoing
      self._chatFallbackCall = chatFallbackCall
      self._chatFallbackCallBubble_incoming = chatFallbackCallBubble_incoming
      self._chatFallbackCallBubble_outgoing = chatFallbackCallBubble_outgoing
      self._chatToggleSelected = chatToggleSelected
      self._chatToggleUnselected = chatToggleUnselected
      self._chatShare = chatShare
      self._chatMusicPlay = chatMusicPlay
      self._chatMusicPlayBubble_incoming = chatMusicPlayBubble_incoming
      self._chatMusicPlayBubble_outgoing = chatMusicPlayBubble_outgoing
      self._chatMusicPause = chatMusicPause
      self._chatMusicPauseBubble_incoming = chatMusicPauseBubble_incoming
      self._chatMusicPauseBubble_outgoing = chatMusicPauseBubble_outgoing
      self._composeNewChat = composeNewChat
      self._composeNewChatActive = composeNewChatActive
      self._composeNewGroup = composeNewGroup
      self._composeNewSecretChat = composeNewSecretChat
      self._composeNewChannel = composeNewChannel
      self._contactsNewContact = contactsNewContact
      self._chatReadMarkInBubble1_incoming = chatReadMarkInBubble1_incoming
      self._chatReadMarkInBubble2_incoming = chatReadMarkInBubble2_incoming
      self._chatReadMarkInBubble1_outgoing = chatReadMarkInBubble1_outgoing
      self._chatReadMarkInBubble2_outgoing = chatReadMarkInBubble2_outgoing
      self._chatReadMarkOutBubble1 = chatReadMarkOutBubble1
      self._chatReadMarkOutBubble2 = chatReadMarkOutBubble2
      self._chatReadMarkOverlayBubble1 = chatReadMarkOverlayBubble1
      self._chatReadMarkOverlayBubble2 = chatReadMarkOverlayBubble2
      self._sentFailed = sentFailed
      self._chatChannelViewsInBubble_incoming = chatChannelViewsInBubble_incoming
      self._chatChannelViewsInBubble_outgoing = chatChannelViewsInBubble_outgoing
      self._chatChannelViewsOutBubble = chatChannelViewsOutBubble
      self._chatChannelViewsOverlayBubble = chatChannelViewsOverlayBubble
      self._chatNavigationBack = chatNavigationBack
      self._peerInfoAddMember = peerInfoAddMember
      self._chatSearchUp = chatSearchUp
      self._chatSearchUpDisabled = chatSearchUpDisabled
      self._chatSearchDown = chatSearchDown
      self._chatSearchDownDisabled = chatSearchDownDisabled
      self._chatSearchCalendar = chatSearchCalendar
      self._dismissAccessory = dismissAccessory
      self._chatScrollUp = chatScrollUp
      self._chatScrollUpActive = chatScrollUpActive
      self._audioPlayerPlay = audioPlayerPlay
      self._audioPlayerPause = audioPlayerPause
      self._audioPlayerNext = audioPlayerNext
      self._audioPlayerPrev = audioPlayerPrev
      self._auduiPlayerDismiss = auduiPlayerDismiss
      self._audioPlayerRepeat = audioPlayerRepeat
      self._audioPlayerRepeatActive = audioPlayerRepeatActive
      self._audioPlayerLockedPlay = audioPlayerLockedPlay
      self._audioPlayerLockedNext = audioPlayerLockedNext
      self._audioPlayerLockedPrev = audioPlayerLockedPrev
      self._chatSendMessage = chatSendMessage
      self._chatRecordVoice = chatRecordVoice
      self._chatEntertainment = chatEntertainment
      self._chatInlineDismiss = chatInlineDismiss
      self._chatActiveReplyMarkup = chatActiveReplyMarkup
      self._chatDisabledReplyMarkup = chatDisabledReplyMarkup
      self._chatSecretTimer = chatSecretTimer
      self._chatForwardMessagesActive = chatForwardMessagesActive
      self._chatForwardMessagesInactive = chatForwardMessagesInactive
      self._chatDeleteMessagesActive = chatDeleteMessagesActive
      self._chatDeleteMessagesInactive = chatDeleteMessagesInactive
      self._generalNext = generalNext
      self._generalNextActive = generalNextActive
      self._generalSelect = generalSelect
      self._chatVoiceRecording = chatVoiceRecording
      self._chatVideoRecording = chatVideoRecording
      self._chatRecord = chatRecord
      self._deleteItem = deleteItem
      self._deleteItemDisabled = deleteItemDisabled
      self._chatAttach = chatAttach
      self._chatAttachFile = chatAttachFile
      self._chatAttachPhoto = chatAttachPhoto
      self._chatAttachCamera = chatAttachCamera
      self._chatAttachLocation = chatAttachLocation
      self._chatAttachPoll = chatAttachPoll
      self._mediaEmptyShared = mediaEmptyShared
      self._mediaEmptyFiles = mediaEmptyFiles
      self._mediaEmptyMusic = mediaEmptyMusic
      self._mediaEmptyLinks = mediaEmptyLinks
      self._mediaDropdown = mediaDropdown
      self._stickersAddFeatured = stickersAddFeatured
      self._stickersAddedFeatured = stickersAddedFeatured
      self._stickersRemove = stickersRemove
      self._peerMediaDownloadFileStart = peerMediaDownloadFileStart
      self._peerMediaDownloadFilePause = peerMediaDownloadFilePause
      self._stickersShare = stickersShare
      self._emojiRecentTab = emojiRecentTab
      self._emojiSmileTab = emojiSmileTab
      self._emojiNatureTab = emojiNatureTab
      self._emojiFoodTab = emojiFoodTab
      self._emojiSportTab = emojiSportTab
      self._emojiCarTab = emojiCarTab
      self._emojiObjectsTab = emojiObjectsTab
      self._emojiSymbolsTab = emojiSymbolsTab
      self._emojiFlagsTab = emojiFlagsTab
      self._emojiRecentTabActive = emojiRecentTabActive
      self._emojiSmileTabActive = emojiSmileTabActive
      self._emojiNatureTabActive = emojiNatureTabActive
      self._emojiFoodTabActive = emojiFoodTabActive
      self._emojiSportTabActive = emojiSportTabActive
      self._emojiCarTabActive = emojiCarTabActive
      self._emojiObjectsTabActive = emojiObjectsTabActive
      self._emojiSymbolsTabActive = emojiSymbolsTabActive
      self._emojiFlagsTabActive = emojiFlagsTabActive
      self._stickerBackground = stickerBackground
      self._stickerBackgroundActive = stickerBackgroundActive
      self._stickersTabRecent = stickersTabRecent
      self._stickersTabGIF = stickersTabGIF
      self._chatSendingInFrame_incoming = chatSendingInFrame_incoming
      self._chatSendingInHour_incoming = chatSendingInHour_incoming
      self._chatSendingInMin_incoming = chatSendingInMin_incoming
      self._chatSendingInFrame_outgoing = chatSendingInFrame_outgoing
      self._chatSendingInHour_outgoing = chatSendingInHour_outgoing
      self._chatSendingInMin_outgoing = chatSendingInMin_outgoing
      self._chatSendingOutFrame = chatSendingOutFrame
      self._chatSendingOutHour = chatSendingOutHour
      self._chatSendingOutMin = chatSendingOutMin
      self._chatSendingOverlayFrame = chatSendingOverlayFrame
      self._chatSendingOverlayHour = chatSendingOverlayHour
      self._chatSendingOverlayMin = chatSendingOverlayMin
      self._chatActionUrl = chatActionUrl
      self._callInlineDecline = callInlineDecline
      self._callInlineMuted = callInlineMuted
      self._callInlineUnmuted = callInlineUnmuted
      self._eventLogTriangle = eventLogTriangle
      self._channelIntro = channelIntro
      self._chatFileThumb = chatFileThumb
      self._chatFileThumbBubble_incoming = chatFileThumbBubble_incoming
      self._chatFileThumbBubble_outgoing = chatFileThumbBubble_outgoing
      self._chatSecretThumb = chatSecretThumb
      self._chatMapPin = chatMapPin
      self._chatSecretTitle = chatSecretTitle
      self._emptySearch = emptySearch
      self._calendarBack = calendarBack
      self._calendarNext = calendarNext
      self._calendarBackDisabled = calendarBackDisabled
      self._calendarNextDisabled = calendarNextDisabled
      self._newChatCamera = newChatCamera
      self._peerInfoVerify = peerInfoVerify
      self._peerInfoCall = peerInfoCall
      self._callOutgoing = callOutgoing
      self._recentDismiss = recentDismiss
      self._recentDismissActive = recentDismissActive
      self._webgameShare = webgameShare
      self._chatSearchCancel = chatSearchCancel
      self._chatSearchFrom = chatSearchFrom
      self._callWindowDecline = callWindowDecline
      self._callWindowAccept = callWindowAccept
      self._callWindowMute = callWindowMute
      self._callWindowUnmute = callWindowUnmute
      self._callWindowClose = callWindowClose
      self._callWindowDeviceSettings = callWindowDeviceSettings
      self._callSettings = callSettings
      self._callWindowCancel = callWindowCancel
      self._chatActionEdit = chatActionEdit
      self._chatActionInfo = chatActionInfo
      self._chatActionMute = chatActionMute
      self._chatActionUnmute = chatActionUnmute
      self._chatActionClearHistory = chatActionClearHistory
      self._chatActionDeleteChat = chatActionDeleteChat
      self._dismissPinned = dismissPinned
      self._chatActionsActive = chatActionsActive
      self._chatEntertainmentSticker = chatEntertainmentSticker
      self._chatEmpty = chatEmpty
      self._stickerPackClose = stickerPackClose
      self._stickerPackDelete = stickerPackDelete
      self._modalShare = modalShare
      self._modalClose = modalClose
      self._ivChannelJoined = ivChannelJoined
      self._chatListMention = chatListMention
      self._chatListMentionActive = chatListMentionActive
      self._chatListMentionArchived = chatListMentionArchived
      self._chatListMentionArchivedActive = chatListMentionArchivedActive
      self._chatMention = chatMention
      self._chatMentionActive = chatMentionActive
      self._sliderControl = sliderControl
      self._sliderControlActive = sliderControlActive
      self._stickersTabFave = stickersTabFave
      self._chatInstantView = chatInstantView
      self._chatInstantViewBubble_incoming = chatInstantViewBubble_incoming
      self._chatInstantViewBubble_outgoing = chatInstantViewBubble_outgoing
      self._instantViewShare = instantViewShare
      self._instantViewActions = instantViewActions
      self._instantViewActionsActive = instantViewActionsActive
      self._instantViewSafari = instantViewSafari
      self._instantViewBack = instantViewBack
      self._instantViewCheck = instantViewCheck
      self._groupStickerNotFound = groupStickerNotFound
      self._settingsAskQuestion = settingsAskQuestion
      self._settingsFaq = settingsFaq
      self._settingsGeneral = settingsGeneral
      self._settingsLanguage = settingsLanguage
      self._settingsNotifications = settingsNotifications
      self._settingsSecurity = settingsSecurity
      self._settingsStickers = settingsStickers
      self._settingsStorage = settingsStorage
      self._settingsProxy = settingsProxy
      self._settingsAppearance = settingsAppearance
      self._settingsPassport = settingsPassport
      self._settingsUpdate = settingsUpdate
      self._settingsAskQuestionActive = settingsAskQuestionActive
      self._settingsFaqActive = settingsFaqActive
      self._settingsGeneralActive = settingsGeneralActive
      self._settingsLanguageActive = settingsLanguageActive
      self._settingsNotificationsActive = settingsNotificationsActive
      self._settingsSecurityActive = settingsSecurityActive
      self._settingsStickersActive = settingsStickersActive
      self._settingsStorageActive = settingsStorageActive
      self._settingsProxyActive = settingsProxyActive
      self._settingsAppearanceActive = settingsAppearanceActive
      self._settingsPassportActive = settingsPassportActive
      self._settingsUpdateActive = settingsUpdateActive
      self._generalCheck = generalCheck
      self._settingsAbout = settingsAbout
      self._settingsLogout = settingsLogout
      self._fastSettingsLock = fastSettingsLock
      self._fastSettingsDark = fastSettingsDark
      self._fastSettingsSunny = fastSettingsSunny
      self._fastSettingsMute = fastSettingsMute
      self._fastSettingsUnmute = fastSettingsUnmute
      self._chatRecordVideo = chatRecordVideo
      self._inputChannelMute = inputChannelMute
      self._inputChannelUnmute = inputChannelUnmute
      self._changePhoneNumberIntro = changePhoneNumberIntro
      self._peerSavedMessages = peerSavedMessages
      self._previewCollage = previewCollage
      self._chatGoMessage = chatGoMessage
      self._chatGroupToggleSelected = chatGroupToggleSelected
      self._chatGroupToggleUnselected = chatGroupToggleUnselected
      self._successModalProgress = successModalProgress
      self._accentColorSelect = accentColorSelect
      self._chatShareWallpaper = chatShareWallpaper
      self._chatGotoMessageWallpaper = chatGotoMessageWallpaper
      self._transparentBackground = transparentBackground
      self._lottieTransparentBackground = lottieTransparentBackground
      self._passcodeTouchId = passcodeTouchId
      self._passcodeLogin = passcodeLogin
      self._confirmDeleteMessagesAccessory = confirmDeleteMessagesAccessory
      self._alertCheckBoxSelected = alertCheckBoxSelected
      self._alertCheckBoxUnselected = alertCheckBoxUnselected
      self._confirmPinAccessory = confirmPinAccessory
      self._confirmDeleteChatAccessory = confirmDeleteChatAccessory
      self._stickersEmptySearch = stickersEmptySearch
      self._twoStepVerificationCreateIntro = twoStepVerificationCreateIntro
      self._secureIdAuth = secureIdAuth
      self._ivAudioPlay = ivAudioPlay
      self._ivAudioPause = ivAudioPause
      self._proxyEnable = proxyEnable
      self._proxyEnabled = proxyEnabled
      self._proxyState = proxyState
      self._proxyDeleteListItem = proxyDeleteListItem
      self._proxyInfoListItem = proxyInfoListItem
      self._proxyConnectedListItem = proxyConnectedListItem
      self._proxyAddProxy = proxyAddProxy
      self._proxyNextWaitingListItem = proxyNextWaitingListItem
      self._passportForgotPassword = passportForgotPassword
      self._confirmAppAccessoryIcon = confirmAppAccessoryIcon
      self._passportPassport = passportPassport
      self._passportIdCardReverse = passportIdCardReverse
      self._passportIdCard = passportIdCard
      self._passportSelfie = passportSelfie
      self._passportDriverLicense = passportDriverLicense
      self._chatOverlayVoiceRecording = chatOverlayVoiceRecording
      self._chatOverlayVideoRecording = chatOverlayVideoRecording
      self._chatOverlaySendRecording = chatOverlaySendRecording
      self._chatOverlayLockArrowRecording = chatOverlayLockArrowRecording
      self._chatOverlayLockerBodyRecording = chatOverlayLockerBodyRecording
      self._chatOverlayLockerHeadRecording = chatOverlayLockerHeadRecording
      self._locationPin = locationPin
      self._locationMapPin = locationMapPin
      self._locationMapLocate = locationMapLocate
      self._locationMapLocated = locationMapLocated
      self._chatTabIconSelected = chatTabIconSelected
      self._chatTabIconSelectedUp = chatTabIconSelectedUp
      self._chatTabIconSelectedDown = chatTabIconSelectedDown
      self._chatTabIcon = chatTabIcon
      self._passportSettings = passportSettings
      self._passportInfo = passportInfo
      self._editMessageMedia = editMessageMedia
      self._playerMusicPlaceholder = playerMusicPlaceholder
      self._chatMusicPlaceholder = chatMusicPlaceholder
      self._chatMusicPlaceholderCap = chatMusicPlaceholderCap
      self._searchArticle = searchArticle
      self._searchSaved = searchSaved
      self._archivedChats = archivedChats
      self._hintPeerActive = hintPeerActive
      self._hintPeerActiveSelected = hintPeerActiveSelected
      self._chatSwiping_delete = chatSwiping_delete
      self._chatSwiping_mute = chatSwiping_mute
      self._chatSwiping_unmute = chatSwiping_unmute
      self._chatSwiping_read = chatSwiping_read
      self._chatSwiping_unread = chatSwiping_unread
      self._chatSwiping_pin = chatSwiping_pin
      self._chatSwiping_unpin = chatSwiping_unpin
      self._chatSwiping_archive = chatSwiping_archive
      self._chatSwiping_unarchive = chatSwiping_unarchive
      self._galleryPrev = galleryPrev
      self._galleryNext = galleryNext
      self._galleryMore = galleryMore
      self._galleryShare = galleryShare
      self._galleryFastSave = galleryFastSave
      self._playingVoice1x = playingVoice1x
      self._playingVoice2x = playingVoice2x
      self._galleryRotate = galleryRotate
      self._galleryZoomIn = galleryZoomIn
      self._galleryZoomOut = galleryZoomOut
      self._previewSenderCrop = previewSenderCrop
      self._previewSenderDelete = previewSenderDelete
      self._editMessageCurrentPhoto = editMessageCurrentPhoto
      self._previewSenderDeleteFile = previewSenderDeleteFile
      self._previewSenderArchive = previewSenderArchive
      self._chatSwipeReply = chatSwipeReply
      self._chatSwipeReplyWallpaper = chatSwipeReplyWallpaper
      self._videoPlayerPlay = videoPlayerPlay
      self._videoPlayerPause = videoPlayerPause
      self._videoPlayerEnterFullScreen = videoPlayerEnterFullScreen
      self._videoPlayerExitFullScreen = videoPlayerExitFullScreen
      self._videoPlayerPIPIn = videoPlayerPIPIn
      self._videoPlayerPIPOut = videoPlayerPIPOut
      self._videoPlayerRewind15Forward = videoPlayerRewind15Forward
      self._videoPlayerRewind15Backward = videoPlayerRewind15Backward
      self._videoPlayerVolume = videoPlayerVolume
      self._videoPlayerVolumeOff = videoPlayerVolumeOff
      self._videoPlayerClose = videoPlayerClose
      self._videoPlayerSliderInteractor = videoPlayerSliderInteractor
      self._streamingVideoDownload = streamingVideoDownload
      self._videoCompactFetching = videoCompactFetching
      self._compactStreamingFetchingCancel = compactStreamingFetchingCancel
      self._customLocalizationDelete = customLocalizationDelete
      self._pollAddOption = pollAddOption
      self._pollDeleteOption = pollDeleteOption
      self._resort = resort
      self._chatPollVoteUnselected = chatPollVoteUnselected
      self._chatPollVoteUnselectedBubble_incoming = chatPollVoteUnselectedBubble_incoming
      self._chatPollVoteUnselectedBubble_outgoing = chatPollVoteUnselectedBubble_outgoing
      self._peerInfoAdmins = peerInfoAdmins
      self._peerInfoPermissions = peerInfoPermissions
      self._peerInfoBanned = peerInfoBanned
      self._peerInfoMembers = peerInfoMembers
      self._chatUndoAction = chatUndoAction
      self._appUpdate = appUpdate
      self._inlineVideoSoundOff = inlineVideoSoundOff
      self._inlineVideoSoundOn = inlineVideoSoundOn
      self._logoutOptionAddAccount = logoutOptionAddAccount
      self._logoutOptionSetPasscode = logoutOptionSetPasscode
      self._logoutOptionClearCache = logoutOptionClearCache
      self._logoutOptionChangePhoneNumber = logoutOptionChangePhoneNumber
      self._logoutOptionContactSupport = logoutOptionContactSupport
      self._disableEmojiPrediction = disableEmojiPrediction
      self._scam = scam
      self._scamActive = scamActive
      self._chatScam = chatScam
      self._chatUnarchive = chatUnarchive
      self._chatArchive = chatArchive
      self._privacySettings_blocked = privacySettings_blocked
      self._privacySettings_activeSessions = privacySettings_activeSessions
      self._privacySettings_passcode = privacySettings_passcode
      self._privacySettings_twoStep = privacySettings_twoStep
      self._deletedAccount = deletedAccount
      self._stickerPackSelection = stickerPackSelection
      self._stickerPackSelectionActive = stickerPackSelectionActive
      self._entertainment_Emoji = entertainment_Emoji
      self._entertainment_Stickers = entertainment_Stickers
      self._entertainment_Gifs = entertainment_Gifs
      self._entertainment_Search = entertainment_Search
      self._entertainment_Settings = entertainment_Settings
      self._entertainment_SearchCancel = entertainment_SearchCancel
      self._scheduledAvatar = scheduledAvatar
      self._scheduledInputAction = scheduledInputAction
  }

  deinit {
      var bp:Int = 0
      bp += 1
  }

}