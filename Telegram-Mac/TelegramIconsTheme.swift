import SwiftSignalKit

final class TelegramIconsTheme {
  private var cached:Atomic<[String: CGImage]> = Atomic(value: [:])
  private var cachedWithInset:Atomic<[String: (CGImage, NSEdgeInsets)]> = Atomic(value: [:])

  var dialogMuteImage: CGImage {
      if let image = cached.with({ $0["dialogMuteImage"] }) {
          return image
      } else {
          let image = _dialogMuteImage()
          _ = cached.modify { current in 
              var current = current
              current["dialogMuteImage"] = image
              return current
          }
          return image
      }
  }
  var dialogMuteImageSelected: CGImage {
      if let image = cached.with({ $0["dialogMuteImageSelected"] }) {
          return image
      } else {
          let image = _dialogMuteImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["dialogMuteImageSelected"] = image
              return current
          }
          return image
      }
  }
  var outgoingMessageImage: CGImage {
      if let image = cached.with({ $0["outgoingMessageImage"] }) {
          return image
      } else {
          let image = _outgoingMessageImage()
          _ = cached.modify { current in 
              var current = current
              current["outgoingMessageImage"] = image
              return current
          }
          return image
      }
  }
  var readMessageImage: CGImage {
      if let image = cached.with({ $0["readMessageImage"] }) {
          return image
      } else {
          let image = _readMessageImage()
          _ = cached.modify { current in 
              var current = current
              current["readMessageImage"] = image
              return current
          }
          return image
      }
  }
  var outgoingMessageImageSelected: CGImage {
      if let image = cached.with({ $0["outgoingMessageImageSelected"] }) {
          return image
      } else {
          let image = _outgoingMessageImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["outgoingMessageImageSelected"] = image
              return current
          }
          return image
      }
  }
  var readMessageImageSelected: CGImage {
      if let image = cached.with({ $0["readMessageImageSelected"] }) {
          return image
      } else {
          let image = _readMessageImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["readMessageImageSelected"] = image
              return current
          }
          return image
      }
  }
  var sendingImage: CGImage {
      if let image = cached.with({ $0["sendingImage"] }) {
          return image
      } else {
          let image = _sendingImage()
          _ = cached.modify { current in 
              var current = current
              current["sendingImage"] = image
              return current
          }
          return image
      }
  }
  var sendingImageSelected: CGImage {
      if let image = cached.with({ $0["sendingImageSelected"] }) {
          return image
      } else {
          let image = _sendingImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["sendingImageSelected"] = image
              return current
          }
          return image
      }
  }
  var secretImage: CGImage {
      if let image = cached.with({ $0["secretImage"] }) {
          return image
      } else {
          let image = _secretImage()
          _ = cached.modify { current in 
              var current = current
              current["secretImage"] = image
              return current
          }
          return image
      }
  }
  var secretImageSelected: CGImage {
      if let image = cached.with({ $0["secretImageSelected"] }) {
          return image
      } else {
          let image = _secretImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["secretImageSelected"] = image
              return current
          }
          return image
      }
  }
  var pinnedImage: CGImage {
      if let image = cached.with({ $0["pinnedImage"] }) {
          return image
      } else {
          let image = _pinnedImage()
          _ = cached.modify { current in 
              var current = current
              current["pinnedImage"] = image
              return current
          }
          return image
      }
  }
  var pinnedImageSelected: CGImage {
      if let image = cached.with({ $0["pinnedImageSelected"] }) {
          return image
      } else {
          let image = _pinnedImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["pinnedImageSelected"] = image
              return current
          }
          return image
      }
  }
  var verifiedImage: CGImage {
      if let image = cached.with({ $0["verifiedImage"] }) {
          return image
      } else {
          let image = _verifiedImage()
          _ = cached.modify { current in 
              var current = current
              current["verifiedImage"] = image
              return current
          }
          return image
      }
  }
  var verifiedImageSelected: CGImage {
      if let image = cached.with({ $0["verifiedImageSelected"] }) {
          return image
      } else {
          let image = _verifiedImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["verifiedImageSelected"] = image
              return current
          }
          return image
      }
  }
  var errorImage: CGImage {
      if let image = cached.with({ $0["errorImage"] }) {
          return image
      } else {
          let image = _errorImage()
          _ = cached.modify { current in 
              var current = current
              current["errorImage"] = image
              return current
          }
          return image
      }
  }
  var errorImageSelected: CGImage {
      if let image = cached.with({ $0["errorImageSelected"] }) {
          return image
      } else {
          let image = _errorImageSelected()
          _ = cached.modify { current in 
              var current = current
              current["errorImageSelected"] = image
              return current
          }
          return image
      }
  }
  var chatSearch: CGImage {
      if let image = cached.with({ $0["chatSearch"] }) {
          return image
      } else {
          let image = _chatSearch()
          _ = cached.modify { current in 
              var current = current
              current["chatSearch"] = image
              return current
          }
          return image
      }
  }
  var chatSearchActive: CGImage {
      if let image = cached.with({ $0["chatSearchActive"] }) {
          return image
      } else {
          let image = _chatSearchActive()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchActive"] = image
              return current
          }
          return image
      }
  }
  var chatCall: CGImage {
      if let image = cached.with({ $0["chatCall"] }) {
          return image
      } else {
          let image = _chatCall()
          _ = cached.modify { current in 
              var current = current
              current["chatCall"] = image
              return current
          }
          return image
      }
  }
  var chatActions: CGImage {
      if let image = cached.with({ $0["chatActions"] }) {
          return image
      } else {
          let image = _chatActions()
          _ = cached.modify { current in 
              var current = current
              current["chatActions"] = image
              return current
          }
          return image
      }
  }
  var chatFailedCall_incoming: CGImage {
      if let image = cached.with({ $0["chatFailedCall_incoming"] }) {
          return image
      } else {
          let image = _chatFailedCall_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatFailedCall_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatFailedCall_outgoing: CGImage {
      if let image = cached.with({ $0["chatFailedCall_outgoing"] }) {
          return image
      } else {
          let image = _chatFailedCall_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatFailedCall_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatCall_incoming: CGImage {
      if let image = cached.with({ $0["chatCall_incoming"] }) {
          return image
      } else {
          let image = _chatCall_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatCall_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatCall_outgoing: CGImage {
      if let image = cached.with({ $0["chatCall_outgoing"] }) {
          return image
      } else {
          let image = _chatCall_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatCall_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatFailedCallBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatFailedCallBubble_incoming"] }) {
          return image
      } else {
          let image = _chatFailedCallBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatFailedCallBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatFailedCallBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatFailedCallBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatFailedCallBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatFailedCallBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatCallBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatCallBubble_incoming"] }) {
          return image
      } else {
          let image = _chatCallBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatCallBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatCallBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatCallBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatCallBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatCallBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatFallbackCall: CGImage {
      if let image = cached.with({ $0["chatFallbackCall"] }) {
          return image
      } else {
          let image = _chatFallbackCall()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackCall"] = image
              return current
          }
          return image
      }
  }
  var chatFallbackCallBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatFallbackCallBubble_incoming"] }) {
          return image
      } else {
          let image = _chatFallbackCallBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackCallBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatFallbackCallBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatFallbackCallBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatFallbackCallBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackCallBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatToggleSelected: CGImage {
      if let image = cached.with({ $0["chatToggleSelected"] }) {
          return image
      } else {
          let image = _chatToggleSelected()
          _ = cached.modify { current in 
              var current = current
              current["chatToggleSelected"] = image
              return current
          }
          return image
      }
  }
  var chatToggleUnselected: CGImage {
      if let image = cached.with({ $0["chatToggleUnselected"] }) {
          return image
      } else {
          let image = _chatToggleUnselected()
          _ = cached.modify { current in 
              var current = current
              current["chatToggleUnselected"] = image
              return current
          }
          return image
      }
  }
  var chatShare: CGImage {
      if let image = cached.with({ $0["chatShare"] }) {
          return image
      } else {
          let image = _chatShare()
          _ = cached.modify { current in 
              var current = current
              current["chatShare"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPlay: CGImage {
      if let image = cached.with({ $0["chatMusicPlay"] }) {
          return image
      } else {
          let image = _chatMusicPlay()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPlay"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPlayBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatMusicPlayBubble_incoming"] }) {
          return image
      } else {
          let image = _chatMusicPlayBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPlayBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPlayBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatMusicPlayBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatMusicPlayBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPlayBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPause: CGImage {
      if let image = cached.with({ $0["chatMusicPause"] }) {
          return image
      } else {
          let image = _chatMusicPause()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPause"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPauseBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatMusicPauseBubble_incoming"] }) {
          return image
      } else {
          let image = _chatMusicPauseBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPauseBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPauseBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatMusicPauseBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatMusicPauseBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPauseBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatGradientBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatGradientBubble_incoming"] }) {
          return image
      } else {
          let image = _chatGradientBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatGradientBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatGradientBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatGradientBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatGradientBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatGradientBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatBubble_none_incoming_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubble_none_incoming_withInset"] }) {
          return image
      } else {
          let image = _chatBubble_none_incoming_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubble_none_incoming_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubble_none_outgoing_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubble_none_outgoing_withInset"] }) {
          return image
      } else {
          let image = _chatBubble_none_outgoing_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubble_none_outgoing_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubbleBorder_none_incoming_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubbleBorder_none_incoming_withInset"] }) {
          return image
      } else {
          let image = _chatBubbleBorder_none_incoming_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubbleBorder_none_incoming_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubbleBorder_none_outgoing_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubbleBorder_none_outgoing_withInset"] }) {
          return image
      } else {
          let image = _chatBubbleBorder_none_outgoing_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubbleBorder_none_outgoing_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubble_both_incoming_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubble_both_incoming_withInset"] }) {
          return image
      } else {
          let image = _chatBubble_both_incoming_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubble_both_incoming_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubble_both_outgoing_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubble_both_outgoing_withInset"] }) {
          return image
      } else {
          let image = _chatBubble_both_outgoing_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubble_both_outgoing_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubbleBorder_both_incoming_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubbleBorder_both_incoming_withInset"] }) {
          return image
      } else {
          let image = _chatBubbleBorder_both_incoming_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubbleBorder_both_incoming_withInset"] = image
              return current
          }
          return image
      }
  }
  var chatBubbleBorder_both_outgoing_withInset: (CGImage, NSEdgeInsets) {
      if let image = cachedWithInset.with({ $0["chatBubbleBorder_both_outgoing_withInset"] }) {
          return image
      } else {
          let image = _chatBubbleBorder_both_outgoing_withInset()
          _ = cachedWithInset.modify { current in 
              var current = current
              current["chatBubbleBorder_both_outgoing_withInset"] = image
              return current
          }
          return image
      }
  }
  var composeNewChat: CGImage {
      if let image = cached.with({ $0["composeNewChat"] }) {
          return image
      } else {
          let image = _composeNewChat()
          _ = cached.modify { current in 
              var current = current
              current["composeNewChat"] = image
              return current
          }
          return image
      }
  }
  var composeNewChatActive: CGImage {
      if let image = cached.with({ $0["composeNewChatActive"] }) {
          return image
      } else {
          let image = _composeNewChatActive()
          _ = cached.modify { current in 
              var current = current
              current["composeNewChatActive"] = image
              return current
          }
          return image
      }
  }
  var composeNewGroup: CGImage {
      if let image = cached.with({ $0["composeNewGroup"] }) {
          return image
      } else {
          let image = _composeNewGroup()
          _ = cached.modify { current in 
              var current = current
              current["composeNewGroup"] = image
              return current
          }
          return image
      }
  }
  var composeNewSecretChat: CGImage {
      if let image = cached.with({ $0["composeNewSecretChat"] }) {
          return image
      } else {
          let image = _composeNewSecretChat()
          _ = cached.modify { current in 
              var current = current
              current["composeNewSecretChat"] = image
              return current
          }
          return image
      }
  }
  var composeNewChannel: CGImage {
      if let image = cached.with({ $0["composeNewChannel"] }) {
          return image
      } else {
          let image = _composeNewChannel()
          _ = cached.modify { current in 
              var current = current
              current["composeNewChannel"] = image
              return current
          }
          return image
      }
  }
  var contactsNewContact: CGImage {
      if let image = cached.with({ $0["contactsNewContact"] }) {
          return image
      } else {
          let image = _contactsNewContact()
          _ = cached.modify { current in 
              var current = current
              current["contactsNewContact"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkInBubble1_incoming: CGImage {
      if let image = cached.with({ $0["chatReadMarkInBubble1_incoming"] }) {
          return image
      } else {
          let image = _chatReadMarkInBubble1_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkInBubble1_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkInBubble2_incoming: CGImage {
      if let image = cached.with({ $0["chatReadMarkInBubble2_incoming"] }) {
          return image
      } else {
          let image = _chatReadMarkInBubble2_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkInBubble2_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkInBubble1_outgoing: CGImage {
      if let image = cached.with({ $0["chatReadMarkInBubble1_outgoing"] }) {
          return image
      } else {
          let image = _chatReadMarkInBubble1_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkInBubble1_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkInBubble2_outgoing: CGImage {
      if let image = cached.with({ $0["chatReadMarkInBubble2_outgoing"] }) {
          return image
      } else {
          let image = _chatReadMarkInBubble2_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkInBubble2_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkOutBubble1: CGImage {
      if let image = cached.with({ $0["chatReadMarkOutBubble1"] }) {
          return image
      } else {
          let image = _chatReadMarkOutBubble1()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkOutBubble1"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkOutBubble2: CGImage {
      if let image = cached.with({ $0["chatReadMarkOutBubble2"] }) {
          return image
      } else {
          let image = _chatReadMarkOutBubble2()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkOutBubble2"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkOverlayBubble1: CGImage {
      if let image = cached.with({ $0["chatReadMarkOverlayBubble1"] }) {
          return image
      } else {
          let image = _chatReadMarkOverlayBubble1()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkOverlayBubble1"] = image
              return current
          }
          return image
      }
  }
  var chatReadMarkOverlayBubble2: CGImage {
      if let image = cached.with({ $0["chatReadMarkOverlayBubble2"] }) {
          return image
      } else {
          let image = _chatReadMarkOverlayBubble2()
          _ = cached.modify { current in 
              var current = current
              current["chatReadMarkOverlayBubble2"] = image
              return current
          }
          return image
      }
  }
  var sentFailed: CGImage {
      if let image = cached.with({ $0["sentFailed"] }) {
          return image
      } else {
          let image = _sentFailed()
          _ = cached.modify { current in 
              var current = current
              current["sentFailed"] = image
              return current
          }
          return image
      }
  }
  var chatChannelViewsInBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatChannelViewsInBubble_incoming"] }) {
          return image
      } else {
          let image = _chatChannelViewsInBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatChannelViewsInBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatChannelViewsInBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatChannelViewsInBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatChannelViewsInBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatChannelViewsInBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatChannelViewsOutBubble: CGImage {
      if let image = cached.with({ $0["chatChannelViewsOutBubble"] }) {
          return image
      } else {
          let image = _chatChannelViewsOutBubble()
          _ = cached.modify { current in 
              var current = current
              current["chatChannelViewsOutBubble"] = image
              return current
          }
          return image
      }
  }
  var chatChannelViewsOverlayBubble: CGImage {
      if let image = cached.with({ $0["chatChannelViewsOverlayBubble"] }) {
          return image
      } else {
          let image = _chatChannelViewsOverlayBubble()
          _ = cached.modify { current in 
              var current = current
              current["chatChannelViewsOverlayBubble"] = image
              return current
          }
          return image
      }
  }
  var chatNavigationBack: CGImage {
      if let image = cached.with({ $0["chatNavigationBack"] }) {
          return image
      } else {
          let image = _chatNavigationBack()
          _ = cached.modify { current in 
              var current = current
              current["chatNavigationBack"] = image
              return current
          }
          return image
      }
  }
  var peerInfoAddMember: CGImage {
      if let image = cached.with({ $0["peerInfoAddMember"] }) {
          return image
      } else {
          let image = _peerInfoAddMember()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoAddMember"] = image
              return current
          }
          return image
      }
  }
  var chatSearchUp: CGImage {
      if let image = cached.with({ $0["chatSearchUp"] }) {
          return image
      } else {
          let image = _chatSearchUp()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchUp"] = image
              return current
          }
          return image
      }
  }
  var chatSearchUpDisabled: CGImage {
      if let image = cached.with({ $0["chatSearchUpDisabled"] }) {
          return image
      } else {
          let image = _chatSearchUpDisabled()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchUpDisabled"] = image
              return current
          }
          return image
      }
  }
  var chatSearchDown: CGImage {
      if let image = cached.with({ $0["chatSearchDown"] }) {
          return image
      } else {
          let image = _chatSearchDown()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchDown"] = image
              return current
          }
          return image
      }
  }
  var chatSearchDownDisabled: CGImage {
      if let image = cached.with({ $0["chatSearchDownDisabled"] }) {
          return image
      } else {
          let image = _chatSearchDownDisabled()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchDownDisabled"] = image
              return current
          }
          return image
      }
  }
  var chatSearchCalendar: CGImage {
      if let image = cached.with({ $0["chatSearchCalendar"] }) {
          return image
      } else {
          let image = _chatSearchCalendar()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchCalendar"] = image
              return current
          }
          return image
      }
  }
  var dismissAccessory: CGImage {
      if let image = cached.with({ $0["dismissAccessory"] }) {
          return image
      } else {
          let image = _dismissAccessory()
          _ = cached.modify { current in 
              var current = current
              current["dismissAccessory"] = image
              return current
          }
          return image
      }
  }
  var chatScrollUp: CGImage {
      if let image = cached.with({ $0["chatScrollUp"] }) {
          return image
      } else {
          let image = _chatScrollUp()
          _ = cached.modify { current in 
              var current = current
              current["chatScrollUp"] = image
              return current
          }
          return image
      }
  }
  var chatScrollUpActive: CGImage {
      if let image = cached.with({ $0["chatScrollUpActive"] }) {
          return image
      } else {
          let image = _chatScrollUpActive()
          _ = cached.modify { current in 
              var current = current
              current["chatScrollUpActive"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerPlay: CGImage {
      if let image = cached.with({ $0["audioPlayerPlay"] }) {
          return image
      } else {
          let image = _audioPlayerPlay()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerPlay"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerPause: CGImage {
      if let image = cached.with({ $0["audioPlayerPause"] }) {
          return image
      } else {
          let image = _audioPlayerPause()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerPause"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerNext: CGImage {
      if let image = cached.with({ $0["audioPlayerNext"] }) {
          return image
      } else {
          let image = _audioPlayerNext()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerNext"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerPrev: CGImage {
      if let image = cached.with({ $0["audioPlayerPrev"] }) {
          return image
      } else {
          let image = _audioPlayerPrev()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerPrev"] = image
              return current
          }
          return image
      }
  }
  var auduiPlayerDismiss: CGImage {
      if let image = cached.with({ $0["auduiPlayerDismiss"] }) {
          return image
      } else {
          let image = _auduiPlayerDismiss()
          _ = cached.modify { current in 
              var current = current
              current["auduiPlayerDismiss"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerRepeat: CGImage {
      if let image = cached.with({ $0["audioPlayerRepeat"] }) {
          return image
      } else {
          let image = _audioPlayerRepeat()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerRepeat"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerRepeatActive: CGImage {
      if let image = cached.with({ $0["audioPlayerRepeatActive"] }) {
          return image
      } else {
          let image = _audioPlayerRepeatActive()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerRepeatActive"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerLockedPlay: CGImage {
      if let image = cached.with({ $0["audioPlayerLockedPlay"] }) {
          return image
      } else {
          let image = _audioPlayerLockedPlay()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerLockedPlay"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerLockedNext: CGImage {
      if let image = cached.with({ $0["audioPlayerLockedNext"] }) {
          return image
      } else {
          let image = _audioPlayerLockedNext()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerLockedNext"] = image
              return current
          }
          return image
      }
  }
  var audioPlayerLockedPrev: CGImage {
      if let image = cached.with({ $0["audioPlayerLockedPrev"] }) {
          return image
      } else {
          let image = _audioPlayerLockedPrev()
          _ = cached.modify { current in 
              var current = current
              current["audioPlayerLockedPrev"] = image
              return current
          }
          return image
      }
  }
  var chatSendMessage: CGImage {
      if let image = cached.with({ $0["chatSendMessage"] }) {
          return image
      } else {
          let image = _chatSendMessage()
          _ = cached.modify { current in 
              var current = current
              current["chatSendMessage"] = image
              return current
          }
          return image
      }
  }
  var chatSaveEditedMessage: CGImage {
      if let image = cached.with({ $0["chatSaveEditedMessage"] }) {
          return image
      } else {
          let image = _chatSaveEditedMessage()
          _ = cached.modify { current in 
              var current = current
              current["chatSaveEditedMessage"] = image
              return current
          }
          return image
      }
  }
  var chatRecordVoice: CGImage {
      if let image = cached.with({ $0["chatRecordVoice"] }) {
          return image
      } else {
          let image = _chatRecordVoice()
          _ = cached.modify { current in 
              var current = current
              current["chatRecordVoice"] = image
              return current
          }
          return image
      }
  }
  var chatEntertainment: CGImage {
      if let image = cached.with({ $0["chatEntertainment"] }) {
          return image
      } else {
          let image = _chatEntertainment()
          _ = cached.modify { current in 
              var current = current
              current["chatEntertainment"] = image
              return current
          }
          return image
      }
  }
  var chatInlineDismiss: CGImage {
      if let image = cached.with({ $0["chatInlineDismiss"] }) {
          return image
      } else {
          let image = _chatInlineDismiss()
          _ = cached.modify { current in 
              var current = current
              current["chatInlineDismiss"] = image
              return current
          }
          return image
      }
  }
  var chatActiveReplyMarkup: CGImage {
      if let image = cached.with({ $0["chatActiveReplyMarkup"] }) {
          return image
      } else {
          let image = _chatActiveReplyMarkup()
          _ = cached.modify { current in 
              var current = current
              current["chatActiveReplyMarkup"] = image
              return current
          }
          return image
      }
  }
  var chatDisabledReplyMarkup: CGImage {
      if let image = cached.with({ $0["chatDisabledReplyMarkup"] }) {
          return image
      } else {
          let image = _chatDisabledReplyMarkup()
          _ = cached.modify { current in 
              var current = current
              current["chatDisabledReplyMarkup"] = image
              return current
          }
          return image
      }
  }
  var chatSecretTimer: CGImage {
      if let image = cached.with({ $0["chatSecretTimer"] }) {
          return image
      } else {
          let image = _chatSecretTimer()
          _ = cached.modify { current in 
              var current = current
              current["chatSecretTimer"] = image
              return current
          }
          return image
      }
  }
  var chatForwardMessagesActive: CGImage {
      if let image = cached.with({ $0["chatForwardMessagesActive"] }) {
          return image
      } else {
          let image = _chatForwardMessagesActive()
          _ = cached.modify { current in 
              var current = current
              current["chatForwardMessagesActive"] = image
              return current
          }
          return image
      }
  }
  var chatForwardMessagesInactive: CGImage {
      if let image = cached.with({ $0["chatForwardMessagesInactive"] }) {
          return image
      } else {
          let image = _chatForwardMessagesInactive()
          _ = cached.modify { current in 
              var current = current
              current["chatForwardMessagesInactive"] = image
              return current
          }
          return image
      }
  }
  var chatDeleteMessagesActive: CGImage {
      if let image = cached.with({ $0["chatDeleteMessagesActive"] }) {
          return image
      } else {
          let image = _chatDeleteMessagesActive()
          _ = cached.modify { current in 
              var current = current
              current["chatDeleteMessagesActive"] = image
              return current
          }
          return image
      }
  }
  var chatDeleteMessagesInactive: CGImage {
      if let image = cached.with({ $0["chatDeleteMessagesInactive"] }) {
          return image
      } else {
          let image = _chatDeleteMessagesInactive()
          _ = cached.modify { current in 
              var current = current
              current["chatDeleteMessagesInactive"] = image
              return current
          }
          return image
      }
  }
  var generalNext: CGImage {
      if let image = cached.with({ $0["generalNext"] }) {
          return image
      } else {
          let image = _generalNext()
          _ = cached.modify { current in 
              var current = current
              current["generalNext"] = image
              return current
          }
          return image
      }
  }
  var generalNextActive: CGImage {
      if let image = cached.with({ $0["generalNextActive"] }) {
          return image
      } else {
          let image = _generalNextActive()
          _ = cached.modify { current in 
              var current = current
              current["generalNextActive"] = image
              return current
          }
          return image
      }
  }
  var generalSelect: CGImage {
      if let image = cached.with({ $0["generalSelect"] }) {
          return image
      } else {
          let image = _generalSelect()
          _ = cached.modify { current in 
              var current = current
              current["generalSelect"] = image
              return current
          }
          return image
      }
  }
  var chatVoiceRecording: CGImage {
      if let image = cached.with({ $0["chatVoiceRecording"] }) {
          return image
      } else {
          let image = _chatVoiceRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatVoiceRecording"] = image
              return current
          }
          return image
      }
  }
  var chatVideoRecording: CGImage {
      if let image = cached.with({ $0["chatVideoRecording"] }) {
          return image
      } else {
          let image = _chatVideoRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatVideoRecording"] = image
              return current
          }
          return image
      }
  }
  var chatRecord: CGImage {
      if let image = cached.with({ $0["chatRecord"] }) {
          return image
      } else {
          let image = _chatRecord()
          _ = cached.modify { current in 
              var current = current
              current["chatRecord"] = image
              return current
          }
          return image
      }
  }
  var deleteItem: CGImage {
      if let image = cached.with({ $0["deleteItem"] }) {
          return image
      } else {
          let image = _deleteItem()
          _ = cached.modify { current in 
              var current = current
              current["deleteItem"] = image
              return current
          }
          return image
      }
  }
  var deleteItemDisabled: CGImage {
      if let image = cached.with({ $0["deleteItemDisabled"] }) {
          return image
      } else {
          let image = _deleteItemDisabled()
          _ = cached.modify { current in 
              var current = current
              current["deleteItemDisabled"] = image
              return current
          }
          return image
      }
  }
  var chatAttach: CGImage {
      if let image = cached.with({ $0["chatAttach"] }) {
          return image
      } else {
          let image = _chatAttach()
          _ = cached.modify { current in 
              var current = current
              current["chatAttach"] = image
              return current
          }
          return image
      }
  }
  var chatAttachFile: CGImage {
      if let image = cached.with({ $0["chatAttachFile"] }) {
          return image
      } else {
          let image = _chatAttachFile()
          _ = cached.modify { current in 
              var current = current
              current["chatAttachFile"] = image
              return current
          }
          return image
      }
  }
  var chatAttachPhoto: CGImage {
      if let image = cached.with({ $0["chatAttachPhoto"] }) {
          return image
      } else {
          let image = _chatAttachPhoto()
          _ = cached.modify { current in 
              var current = current
              current["chatAttachPhoto"] = image
              return current
          }
          return image
      }
  }
  var chatAttachCamera: CGImage {
      if let image = cached.with({ $0["chatAttachCamera"] }) {
          return image
      } else {
          let image = _chatAttachCamera()
          _ = cached.modify { current in 
              var current = current
              current["chatAttachCamera"] = image
              return current
          }
          return image
      }
  }
  var chatAttachLocation: CGImage {
      if let image = cached.with({ $0["chatAttachLocation"] }) {
          return image
      } else {
          let image = _chatAttachLocation()
          _ = cached.modify { current in 
              var current = current
              current["chatAttachLocation"] = image
              return current
          }
          return image
      }
  }
  var chatAttachPoll: CGImage {
      if let image = cached.with({ $0["chatAttachPoll"] }) {
          return image
      } else {
          let image = _chatAttachPoll()
          _ = cached.modify { current in 
              var current = current
              current["chatAttachPoll"] = image
              return current
          }
          return image
      }
  }
  var mediaEmptyShared: CGImage {
      if let image = cached.with({ $0["mediaEmptyShared"] }) {
          return image
      } else {
          let image = _mediaEmptyShared()
          _ = cached.modify { current in 
              var current = current
              current["mediaEmptyShared"] = image
              return current
          }
          return image
      }
  }
  var mediaEmptyFiles: CGImage {
      if let image = cached.with({ $0["mediaEmptyFiles"] }) {
          return image
      } else {
          let image = _mediaEmptyFiles()
          _ = cached.modify { current in 
              var current = current
              current["mediaEmptyFiles"] = image
              return current
          }
          return image
      }
  }
  var mediaEmptyMusic: CGImage {
      if let image = cached.with({ $0["mediaEmptyMusic"] }) {
          return image
      } else {
          let image = _mediaEmptyMusic()
          _ = cached.modify { current in 
              var current = current
              current["mediaEmptyMusic"] = image
              return current
          }
          return image
      }
  }
  var mediaEmptyLinks: CGImage {
      if let image = cached.with({ $0["mediaEmptyLinks"] }) {
          return image
      } else {
          let image = _mediaEmptyLinks()
          _ = cached.modify { current in 
              var current = current
              current["mediaEmptyLinks"] = image
              return current
          }
          return image
      }
  }
  var stickersAddFeatured: CGImage {
      if let image = cached.with({ $0["stickersAddFeatured"] }) {
          return image
      } else {
          let image = _stickersAddFeatured()
          _ = cached.modify { current in 
              var current = current
              current["stickersAddFeatured"] = image
              return current
          }
          return image
      }
  }
  var stickersAddedFeatured: CGImage {
      if let image = cached.with({ $0["stickersAddedFeatured"] }) {
          return image
      } else {
          let image = _stickersAddedFeatured()
          _ = cached.modify { current in 
              var current = current
              current["stickersAddedFeatured"] = image
              return current
          }
          return image
      }
  }
  var stickersRemove: CGImage {
      if let image = cached.with({ $0["stickersRemove"] }) {
          return image
      } else {
          let image = _stickersRemove()
          _ = cached.modify { current in 
              var current = current
              current["stickersRemove"] = image
              return current
          }
          return image
      }
  }
  var peerMediaDownloadFileStart: CGImage {
      if let image = cached.with({ $0["peerMediaDownloadFileStart"] }) {
          return image
      } else {
          let image = _peerMediaDownloadFileStart()
          _ = cached.modify { current in 
              var current = current
              current["peerMediaDownloadFileStart"] = image
              return current
          }
          return image
      }
  }
  var peerMediaDownloadFilePause: CGImage {
      if let image = cached.with({ $0["peerMediaDownloadFilePause"] }) {
          return image
      } else {
          let image = _peerMediaDownloadFilePause()
          _ = cached.modify { current in 
              var current = current
              current["peerMediaDownloadFilePause"] = image
              return current
          }
          return image
      }
  }
  var stickersShare: CGImage {
      if let image = cached.with({ $0["stickersShare"] }) {
          return image
      } else {
          let image = _stickersShare()
          _ = cached.modify { current in 
              var current = current
              current["stickersShare"] = image
              return current
          }
          return image
      }
  }
  var emojiRecentTab: CGImage {
      if let image = cached.with({ $0["emojiRecentTab"] }) {
          return image
      } else {
          let image = _emojiRecentTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiRecentTab"] = image
              return current
          }
          return image
      }
  }
  var emojiSmileTab: CGImage {
      if let image = cached.with({ $0["emojiSmileTab"] }) {
          return image
      } else {
          let image = _emojiSmileTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiSmileTab"] = image
              return current
          }
          return image
      }
  }
  var emojiNatureTab: CGImage {
      if let image = cached.with({ $0["emojiNatureTab"] }) {
          return image
      } else {
          let image = _emojiNatureTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiNatureTab"] = image
              return current
          }
          return image
      }
  }
  var emojiFoodTab: CGImage {
      if let image = cached.with({ $0["emojiFoodTab"] }) {
          return image
      } else {
          let image = _emojiFoodTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiFoodTab"] = image
              return current
          }
          return image
      }
  }
  var emojiSportTab: CGImage {
      if let image = cached.with({ $0["emojiSportTab"] }) {
          return image
      } else {
          let image = _emojiSportTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiSportTab"] = image
              return current
          }
          return image
      }
  }
  var emojiCarTab: CGImage {
      if let image = cached.with({ $0["emojiCarTab"] }) {
          return image
      } else {
          let image = _emojiCarTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiCarTab"] = image
              return current
          }
          return image
      }
  }
  var emojiObjectsTab: CGImage {
      if let image = cached.with({ $0["emojiObjectsTab"] }) {
          return image
      } else {
          let image = _emojiObjectsTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiObjectsTab"] = image
              return current
          }
          return image
      }
  }
  var emojiSymbolsTab: CGImage {
      if let image = cached.with({ $0["emojiSymbolsTab"] }) {
          return image
      } else {
          let image = _emojiSymbolsTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiSymbolsTab"] = image
              return current
          }
          return image
      }
  }
  var emojiFlagsTab: CGImage {
      if let image = cached.with({ $0["emojiFlagsTab"] }) {
          return image
      } else {
          let image = _emojiFlagsTab()
          _ = cached.modify { current in 
              var current = current
              current["emojiFlagsTab"] = image
              return current
          }
          return image
      }
  }
  var emojiRecentTabActive: CGImage {
      if let image = cached.with({ $0["emojiRecentTabActive"] }) {
          return image
      } else {
          let image = _emojiRecentTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiRecentTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiSmileTabActive: CGImage {
      if let image = cached.with({ $0["emojiSmileTabActive"] }) {
          return image
      } else {
          let image = _emojiSmileTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiSmileTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiNatureTabActive: CGImage {
      if let image = cached.with({ $0["emojiNatureTabActive"] }) {
          return image
      } else {
          let image = _emojiNatureTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiNatureTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiFoodTabActive: CGImage {
      if let image = cached.with({ $0["emojiFoodTabActive"] }) {
          return image
      } else {
          let image = _emojiFoodTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiFoodTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiSportTabActive: CGImage {
      if let image = cached.with({ $0["emojiSportTabActive"] }) {
          return image
      } else {
          let image = _emojiSportTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiSportTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiCarTabActive: CGImage {
      if let image = cached.with({ $0["emojiCarTabActive"] }) {
          return image
      } else {
          let image = _emojiCarTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiCarTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiObjectsTabActive: CGImage {
      if let image = cached.with({ $0["emojiObjectsTabActive"] }) {
          return image
      } else {
          let image = _emojiObjectsTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiObjectsTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiSymbolsTabActive: CGImage {
      if let image = cached.with({ $0["emojiSymbolsTabActive"] }) {
          return image
      } else {
          let image = _emojiSymbolsTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiSymbolsTabActive"] = image
              return current
          }
          return image
      }
  }
  var emojiFlagsTabActive: CGImage {
      if let image = cached.with({ $0["emojiFlagsTabActive"] }) {
          return image
      } else {
          let image = _emojiFlagsTabActive()
          _ = cached.modify { current in 
              var current = current
              current["emojiFlagsTabActive"] = image
              return current
          }
          return image
      }
  }
  var stickerBackground: CGImage {
      if let image = cached.with({ $0["stickerBackground"] }) {
          return image
      } else {
          let image = _stickerBackground()
          _ = cached.modify { current in 
              var current = current
              current["stickerBackground"] = image
              return current
          }
          return image
      }
  }
  var stickerBackgroundActive: CGImage {
      if let image = cached.with({ $0["stickerBackgroundActive"] }) {
          return image
      } else {
          let image = _stickerBackgroundActive()
          _ = cached.modify { current in 
              var current = current
              current["stickerBackgroundActive"] = image
              return current
          }
          return image
      }
  }
  var stickersTabRecent: CGImage {
      if let image = cached.with({ $0["stickersTabRecent"] }) {
          return image
      } else {
          let image = _stickersTabRecent()
          _ = cached.modify { current in 
              var current = current
              current["stickersTabRecent"] = image
              return current
          }
          return image
      }
  }
  var stickersTabGIF: CGImage {
      if let image = cached.with({ $0["stickersTabGIF"] }) {
          return image
      } else {
          let image = _stickersTabGIF()
          _ = cached.modify { current in 
              var current = current
              current["stickersTabGIF"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInFrame_incoming: CGImage {
      if let image = cached.with({ $0["chatSendingInFrame_incoming"] }) {
          return image
      } else {
          let image = _chatSendingInFrame_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInFrame_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInHour_incoming: CGImage {
      if let image = cached.with({ $0["chatSendingInHour_incoming"] }) {
          return image
      } else {
          let image = _chatSendingInHour_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInHour_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInMin_incoming: CGImage {
      if let image = cached.with({ $0["chatSendingInMin_incoming"] }) {
          return image
      } else {
          let image = _chatSendingInMin_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInMin_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInFrame_outgoing: CGImage {
      if let image = cached.with({ $0["chatSendingInFrame_outgoing"] }) {
          return image
      } else {
          let image = _chatSendingInFrame_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInFrame_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInHour_outgoing: CGImage {
      if let image = cached.with({ $0["chatSendingInHour_outgoing"] }) {
          return image
      } else {
          let image = _chatSendingInHour_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInHour_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatSendingInMin_outgoing: CGImage {
      if let image = cached.with({ $0["chatSendingInMin_outgoing"] }) {
          return image
      } else {
          let image = _chatSendingInMin_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingInMin_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOutFrame: CGImage {
      if let image = cached.with({ $0["chatSendingOutFrame"] }) {
          return image
      } else {
          let image = _chatSendingOutFrame()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOutFrame"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOutHour: CGImage {
      if let image = cached.with({ $0["chatSendingOutHour"] }) {
          return image
      } else {
          let image = _chatSendingOutHour()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOutHour"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOutMin: CGImage {
      if let image = cached.with({ $0["chatSendingOutMin"] }) {
          return image
      } else {
          let image = _chatSendingOutMin()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOutMin"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOverlayFrame: CGImage {
      if let image = cached.with({ $0["chatSendingOverlayFrame"] }) {
          return image
      } else {
          let image = _chatSendingOverlayFrame()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOverlayFrame"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOverlayHour: CGImage {
      if let image = cached.with({ $0["chatSendingOverlayHour"] }) {
          return image
      } else {
          let image = _chatSendingOverlayHour()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOverlayHour"] = image
              return current
          }
          return image
      }
  }
  var chatSendingOverlayMin: CGImage {
      if let image = cached.with({ $0["chatSendingOverlayMin"] }) {
          return image
      } else {
          let image = _chatSendingOverlayMin()
          _ = cached.modify { current in 
              var current = current
              current["chatSendingOverlayMin"] = image
              return current
          }
          return image
      }
  }
  var chatActionUrl: CGImage {
      if let image = cached.with({ $0["chatActionUrl"] }) {
          return image
      } else {
          let image = _chatActionUrl()
          _ = cached.modify { current in 
              var current = current
              current["chatActionUrl"] = image
              return current
          }
          return image
      }
  }
  var callInlineDecline: CGImage {
      if let image = cached.with({ $0["callInlineDecline"] }) {
          return image
      } else {
          let image = _callInlineDecline()
          _ = cached.modify { current in 
              var current = current
              current["callInlineDecline"] = image
              return current
          }
          return image
      }
  }
  var callInlineMuted: CGImage {
      if let image = cached.with({ $0["callInlineMuted"] }) {
          return image
      } else {
          let image = _callInlineMuted()
          _ = cached.modify { current in 
              var current = current
              current["callInlineMuted"] = image
              return current
          }
          return image
      }
  }
  var callInlineUnmuted: CGImage {
      if let image = cached.with({ $0["callInlineUnmuted"] }) {
          return image
      } else {
          let image = _callInlineUnmuted()
          _ = cached.modify { current in 
              var current = current
              current["callInlineUnmuted"] = image
              return current
          }
          return image
      }
  }
  var eventLogTriangle: CGImage {
      if let image = cached.with({ $0["eventLogTriangle"] }) {
          return image
      } else {
          let image = _eventLogTriangle()
          _ = cached.modify { current in 
              var current = current
              current["eventLogTriangle"] = image
              return current
          }
          return image
      }
  }
  var channelIntro: CGImage {
      if let image = cached.with({ $0["channelIntro"] }) {
          return image
      } else {
          let image = _channelIntro()
          _ = cached.modify { current in 
              var current = current
              current["channelIntro"] = image
              return current
          }
          return image
      }
  }
  var chatFileThumb: CGImage {
      if let image = cached.with({ $0["chatFileThumb"] }) {
          return image
      } else {
          let image = _chatFileThumb()
          _ = cached.modify { current in 
              var current = current
              current["chatFileThumb"] = image
              return current
          }
          return image
      }
  }
  var chatFileThumbBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatFileThumbBubble_incoming"] }) {
          return image
      } else {
          let image = _chatFileThumbBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatFileThumbBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatFileThumbBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatFileThumbBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatFileThumbBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatFileThumbBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chatSecretThumb: CGImage {
      if let image = cached.with({ $0["chatSecretThumb"] }) {
          return image
      } else {
          let image = _chatSecretThumb()
          _ = cached.modify { current in 
              var current = current
              current["chatSecretThumb"] = image
              return current
          }
          return image
      }
  }
  var chatMapPin: CGImage {
      if let image = cached.with({ $0["chatMapPin"] }) {
          return image
      } else {
          let image = _chatMapPin()
          _ = cached.modify { current in 
              var current = current
              current["chatMapPin"] = image
              return current
          }
          return image
      }
  }
  var chatSecretTitle: CGImage {
      if let image = cached.with({ $0["chatSecretTitle"] }) {
          return image
      } else {
          let image = _chatSecretTitle()
          _ = cached.modify { current in 
              var current = current
              current["chatSecretTitle"] = image
              return current
          }
          return image
      }
  }
  var emptySearch: CGImage {
      if let image = cached.with({ $0["emptySearch"] }) {
          return image
      } else {
          let image = _emptySearch()
          _ = cached.modify { current in 
              var current = current
              current["emptySearch"] = image
              return current
          }
          return image
      }
  }
  var calendarBack: CGImage {
      if let image = cached.with({ $0["calendarBack"] }) {
          return image
      } else {
          let image = _calendarBack()
          _ = cached.modify { current in 
              var current = current
              current["calendarBack"] = image
              return current
          }
          return image
      }
  }
  var calendarNext: CGImage {
      if let image = cached.with({ $0["calendarNext"] }) {
          return image
      } else {
          let image = _calendarNext()
          _ = cached.modify { current in 
              var current = current
              current["calendarNext"] = image
              return current
          }
          return image
      }
  }
  var calendarBackDisabled: CGImage {
      if let image = cached.with({ $0["calendarBackDisabled"] }) {
          return image
      } else {
          let image = _calendarBackDisabled()
          _ = cached.modify { current in 
              var current = current
              current["calendarBackDisabled"] = image
              return current
          }
          return image
      }
  }
  var calendarNextDisabled: CGImage {
      if let image = cached.with({ $0["calendarNextDisabled"] }) {
          return image
      } else {
          let image = _calendarNextDisabled()
          _ = cached.modify { current in 
              var current = current
              current["calendarNextDisabled"] = image
              return current
          }
          return image
      }
  }
  var newChatCamera: CGImage {
      if let image = cached.with({ $0["newChatCamera"] }) {
          return image
      } else {
          let image = _newChatCamera()
          _ = cached.modify { current in 
              var current = current
              current["newChatCamera"] = image
              return current
          }
          return image
      }
  }
  var peerInfoVerify: CGImage {
      if let image = cached.with({ $0["peerInfoVerify"] }) {
          return image
      } else {
          let image = _peerInfoVerify()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoVerify"] = image
              return current
          }
          return image
      }
  }
  var peerInfoVerifyProfile: CGImage {
      if let image = cached.with({ $0["peerInfoVerifyProfile"] }) {
          return image
      } else {
          let image = _peerInfoVerifyProfile()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoVerifyProfile"] = image
              return current
          }
          return image
      }
  }
  var peerInfoCall: CGImage {
      if let image = cached.with({ $0["peerInfoCall"] }) {
          return image
      } else {
          let image = _peerInfoCall()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoCall"] = image
              return current
          }
          return image
      }
  }
  var callOutgoing: CGImage {
      if let image = cached.with({ $0["callOutgoing"] }) {
          return image
      } else {
          let image = _callOutgoing()
          _ = cached.modify { current in 
              var current = current
              current["callOutgoing"] = image
              return current
          }
          return image
      }
  }
  var recentDismiss: CGImage {
      if let image = cached.with({ $0["recentDismiss"] }) {
          return image
      } else {
          let image = _recentDismiss()
          _ = cached.modify { current in 
              var current = current
              current["recentDismiss"] = image
              return current
          }
          return image
      }
  }
  var recentDismissActive: CGImage {
      if let image = cached.with({ $0["recentDismissActive"] }) {
          return image
      } else {
          let image = _recentDismissActive()
          _ = cached.modify { current in 
              var current = current
              current["recentDismissActive"] = image
              return current
          }
          return image
      }
  }
  var webgameShare: CGImage {
      if let image = cached.with({ $0["webgameShare"] }) {
          return image
      } else {
          let image = _webgameShare()
          _ = cached.modify { current in 
              var current = current
              current["webgameShare"] = image
              return current
          }
          return image
      }
  }
  var chatSearchCancel: CGImage {
      if let image = cached.with({ $0["chatSearchCancel"] }) {
          return image
      } else {
          let image = _chatSearchCancel()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchCancel"] = image
              return current
          }
          return image
      }
  }
  var chatSearchFrom: CGImage {
      if let image = cached.with({ $0["chatSearchFrom"] }) {
          return image
      } else {
          let image = _chatSearchFrom()
          _ = cached.modify { current in 
              var current = current
              current["chatSearchFrom"] = image
              return current
          }
          return image
      }
  }
  var callWindowDecline: CGImage {
      if let image = cached.with({ $0["callWindowDecline"] }) {
          return image
      } else {
          let image = _callWindowDecline()
          _ = cached.modify { current in 
              var current = current
              current["callWindowDecline"] = image
              return current
          }
          return image
      }
  }
  var callWindowAccept: CGImage {
      if let image = cached.with({ $0["callWindowAccept"] }) {
          return image
      } else {
          let image = _callWindowAccept()
          _ = cached.modify { current in 
              var current = current
              current["callWindowAccept"] = image
              return current
          }
          return image
      }
  }
  var callWindowMute: CGImage {
      if let image = cached.with({ $0["callWindowMute"] }) {
          return image
      } else {
          let image = _callWindowMute()
          _ = cached.modify { current in 
              var current = current
              current["callWindowMute"] = image
              return current
          }
          return image
      }
  }
  var callWindowUnmute: CGImage {
      if let image = cached.with({ $0["callWindowUnmute"] }) {
          return image
      } else {
          let image = _callWindowUnmute()
          _ = cached.modify { current in 
              var current = current
              current["callWindowUnmute"] = image
              return current
          }
          return image
      }
  }
  var callWindowClose: CGImage {
      if let image = cached.with({ $0["callWindowClose"] }) {
          return image
      } else {
          let image = _callWindowClose()
          _ = cached.modify { current in 
              var current = current
              current["callWindowClose"] = image
              return current
          }
          return image
      }
  }
  var callWindowDeviceSettings: CGImage {
      if let image = cached.with({ $0["callWindowDeviceSettings"] }) {
          return image
      } else {
          let image = _callWindowDeviceSettings()
          _ = cached.modify { current in 
              var current = current
              current["callWindowDeviceSettings"] = image
              return current
          }
          return image
      }
  }
  var callSettings: CGImage {
      if let image = cached.with({ $0["callSettings"] }) {
          return image
      } else {
          let image = _callSettings()
          _ = cached.modify { current in 
              var current = current
              current["callSettings"] = image
              return current
          }
          return image
      }
  }
  var callWindowCancel: CGImage {
      if let image = cached.with({ $0["callWindowCancel"] }) {
          return image
      } else {
          let image = _callWindowCancel()
          _ = cached.modify { current in 
              var current = current
              current["callWindowCancel"] = image
              return current
          }
          return image
      }
  }
  var chatActionEdit: CGImage {
      if let image = cached.with({ $0["chatActionEdit"] }) {
          return image
      } else {
          let image = _chatActionEdit()
          _ = cached.modify { current in 
              var current = current
              current["chatActionEdit"] = image
              return current
          }
          return image
      }
  }
  var chatActionInfo: CGImage {
      if let image = cached.with({ $0["chatActionInfo"] }) {
          return image
      } else {
          let image = _chatActionInfo()
          _ = cached.modify { current in 
              var current = current
              current["chatActionInfo"] = image
              return current
          }
          return image
      }
  }
  var chatActionMute: CGImage {
      if let image = cached.with({ $0["chatActionMute"] }) {
          return image
      } else {
          let image = _chatActionMute()
          _ = cached.modify { current in 
              var current = current
              current["chatActionMute"] = image
              return current
          }
          return image
      }
  }
  var chatActionUnmute: CGImage {
      if let image = cached.with({ $0["chatActionUnmute"] }) {
          return image
      } else {
          let image = _chatActionUnmute()
          _ = cached.modify { current in 
              var current = current
              current["chatActionUnmute"] = image
              return current
          }
          return image
      }
  }
  var chatActionClearHistory: CGImage {
      if let image = cached.with({ $0["chatActionClearHistory"] }) {
          return image
      } else {
          let image = _chatActionClearHistory()
          _ = cached.modify { current in 
              var current = current
              current["chatActionClearHistory"] = image
              return current
          }
          return image
      }
  }
  var chatActionDeleteChat: CGImage {
      if let image = cached.with({ $0["chatActionDeleteChat"] }) {
          return image
      } else {
          let image = _chatActionDeleteChat()
          _ = cached.modify { current in 
              var current = current
              current["chatActionDeleteChat"] = image
              return current
          }
          return image
      }
  }
  var dismissPinned: CGImage {
      if let image = cached.with({ $0["dismissPinned"] }) {
          return image
      } else {
          let image = _dismissPinned()
          _ = cached.modify { current in 
              var current = current
              current["dismissPinned"] = image
              return current
          }
          return image
      }
  }
  var chatActionsActive: CGImage {
      if let image = cached.with({ $0["chatActionsActive"] }) {
          return image
      } else {
          let image = _chatActionsActive()
          _ = cached.modify { current in 
              var current = current
              current["chatActionsActive"] = image
              return current
          }
          return image
      }
  }
  var chatEntertainmentSticker: CGImage {
      if let image = cached.with({ $0["chatEntertainmentSticker"] }) {
          return image
      } else {
          let image = _chatEntertainmentSticker()
          _ = cached.modify { current in 
              var current = current
              current["chatEntertainmentSticker"] = image
              return current
          }
          return image
      }
  }
  var chatEmpty: CGImage {
      if let image = cached.with({ $0["chatEmpty"] }) {
          return image
      } else {
          let image = _chatEmpty()
          _ = cached.modify { current in 
              var current = current
              current["chatEmpty"] = image
              return current
          }
          return image
      }
  }
  var stickerPackClose: CGImage {
      if let image = cached.with({ $0["stickerPackClose"] }) {
          return image
      } else {
          let image = _stickerPackClose()
          _ = cached.modify { current in 
              var current = current
              current["stickerPackClose"] = image
              return current
          }
          return image
      }
  }
  var stickerPackDelete: CGImage {
      if let image = cached.with({ $0["stickerPackDelete"] }) {
          return image
      } else {
          let image = _stickerPackDelete()
          _ = cached.modify { current in 
              var current = current
              current["stickerPackDelete"] = image
              return current
          }
          return image
      }
  }
  var modalShare: CGImage {
      if let image = cached.with({ $0["modalShare"] }) {
          return image
      } else {
          let image = _modalShare()
          _ = cached.modify { current in 
              var current = current
              current["modalShare"] = image
              return current
          }
          return image
      }
  }
  var modalClose: CGImage {
      if let image = cached.with({ $0["modalClose"] }) {
          return image
      } else {
          let image = _modalClose()
          _ = cached.modify { current in 
              var current = current
              current["modalClose"] = image
              return current
          }
          return image
      }
  }
  var ivChannelJoined: CGImage {
      if let image = cached.with({ $0["ivChannelJoined"] }) {
          return image
      } else {
          let image = _ivChannelJoined()
          _ = cached.modify { current in 
              var current = current
              current["ivChannelJoined"] = image
              return current
          }
          return image
      }
  }
  var chatListMention: CGImage {
      if let image = cached.with({ $0["chatListMention"] }) {
          return image
      } else {
          let image = _chatListMention()
          _ = cached.modify { current in 
              var current = current
              current["chatListMention"] = image
              return current
          }
          return image
      }
  }
  var chatListMentionActive: CGImage {
      if let image = cached.with({ $0["chatListMentionActive"] }) {
          return image
      } else {
          let image = _chatListMentionActive()
          _ = cached.modify { current in 
              var current = current
              current["chatListMentionActive"] = image
              return current
          }
          return image
      }
  }
  var chatListMentionArchived: CGImage {
      if let image = cached.with({ $0["chatListMentionArchived"] }) {
          return image
      } else {
          let image = _chatListMentionArchived()
          _ = cached.modify { current in 
              var current = current
              current["chatListMentionArchived"] = image
              return current
          }
          return image
      }
  }
  var chatListMentionArchivedActive: CGImage {
      if let image = cached.with({ $0["chatListMentionArchivedActive"] }) {
          return image
      } else {
          let image = _chatListMentionArchivedActive()
          _ = cached.modify { current in 
              var current = current
              current["chatListMentionArchivedActive"] = image
              return current
          }
          return image
      }
  }
  var chatMention: CGImage {
      if let image = cached.with({ $0["chatMention"] }) {
          return image
      } else {
          let image = _chatMention()
          _ = cached.modify { current in 
              var current = current
              current["chatMention"] = image
              return current
          }
          return image
      }
  }
  var chatMentionActive: CGImage {
      if let image = cached.with({ $0["chatMentionActive"] }) {
          return image
      } else {
          let image = _chatMentionActive()
          _ = cached.modify { current in 
              var current = current
              current["chatMentionActive"] = image
              return current
          }
          return image
      }
  }
  var sliderControl: CGImage {
      if let image = cached.with({ $0["sliderControl"] }) {
          return image
      } else {
          let image = _sliderControl()
          _ = cached.modify { current in 
              var current = current
              current["sliderControl"] = image
              return current
          }
          return image
      }
  }
  var sliderControlActive: CGImage {
      if let image = cached.with({ $0["sliderControlActive"] }) {
          return image
      } else {
          let image = _sliderControlActive()
          _ = cached.modify { current in 
              var current = current
              current["sliderControlActive"] = image
              return current
          }
          return image
      }
  }
  var stickersTabFave: CGImage {
      if let image = cached.with({ $0["stickersTabFave"] }) {
          return image
      } else {
          let image = _stickersTabFave()
          _ = cached.modify { current in 
              var current = current
              current["stickersTabFave"] = image
              return current
          }
          return image
      }
  }
  var chatInstantView: CGImage {
      if let image = cached.with({ $0["chatInstantView"] }) {
          return image
      } else {
          let image = _chatInstantView()
          _ = cached.modify { current in 
              var current = current
              current["chatInstantView"] = image
              return current
          }
          return image
      }
  }
  var chatInstantViewBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatInstantViewBubble_incoming"] }) {
          return image
      } else {
          let image = _chatInstantViewBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatInstantViewBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatInstantViewBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatInstantViewBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatInstantViewBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatInstantViewBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var instantViewShare: CGImage {
      if let image = cached.with({ $0["instantViewShare"] }) {
          return image
      } else {
          let image = _instantViewShare()
          _ = cached.modify { current in 
              var current = current
              current["instantViewShare"] = image
              return current
          }
          return image
      }
  }
  var instantViewActions: CGImage {
      if let image = cached.with({ $0["instantViewActions"] }) {
          return image
      } else {
          let image = _instantViewActions()
          _ = cached.modify { current in 
              var current = current
              current["instantViewActions"] = image
              return current
          }
          return image
      }
  }
  var instantViewActionsActive: CGImage {
      if let image = cached.with({ $0["instantViewActionsActive"] }) {
          return image
      } else {
          let image = _instantViewActionsActive()
          _ = cached.modify { current in 
              var current = current
              current["instantViewActionsActive"] = image
              return current
          }
          return image
      }
  }
  var instantViewSafari: CGImage {
      if let image = cached.with({ $0["instantViewSafari"] }) {
          return image
      } else {
          let image = _instantViewSafari()
          _ = cached.modify { current in 
              var current = current
              current["instantViewSafari"] = image
              return current
          }
          return image
      }
  }
  var instantViewBack: CGImage {
      if let image = cached.with({ $0["instantViewBack"] }) {
          return image
      } else {
          let image = _instantViewBack()
          _ = cached.modify { current in 
              var current = current
              current["instantViewBack"] = image
              return current
          }
          return image
      }
  }
  var instantViewCheck: CGImage {
      if let image = cached.with({ $0["instantViewCheck"] }) {
          return image
      } else {
          let image = _instantViewCheck()
          _ = cached.modify { current in 
              var current = current
              current["instantViewCheck"] = image
              return current
          }
          return image
      }
  }
  var groupStickerNotFound: CGImage {
      if let image = cached.with({ $0["groupStickerNotFound"] }) {
          return image
      } else {
          let image = _groupStickerNotFound()
          _ = cached.modify { current in 
              var current = current
              current["groupStickerNotFound"] = image
              return current
          }
          return image
      }
  }
  var settingsAskQuestion: CGImage {
      if let image = cached.with({ $0["settingsAskQuestion"] }) {
          return image
      } else {
          let image = _settingsAskQuestion()
          _ = cached.modify { current in 
              var current = current
              current["settingsAskQuestion"] = image
              return current
          }
          return image
      }
  }
  var settingsFaq: CGImage {
      if let image = cached.with({ $0["settingsFaq"] }) {
          return image
      } else {
          let image = _settingsFaq()
          _ = cached.modify { current in 
              var current = current
              current["settingsFaq"] = image
              return current
          }
          return image
      }
  }
  var settingsGeneral: CGImage {
      if let image = cached.with({ $0["settingsGeneral"] }) {
          return image
      } else {
          let image = _settingsGeneral()
          _ = cached.modify { current in 
              var current = current
              current["settingsGeneral"] = image
              return current
          }
          return image
      }
  }
  var settingsLanguage: CGImage {
      if let image = cached.with({ $0["settingsLanguage"] }) {
          return image
      } else {
          let image = _settingsLanguage()
          _ = cached.modify { current in 
              var current = current
              current["settingsLanguage"] = image
              return current
          }
          return image
      }
  }
  var settingsNotifications: CGImage {
      if let image = cached.with({ $0["settingsNotifications"] }) {
          return image
      } else {
          let image = _settingsNotifications()
          _ = cached.modify { current in 
              var current = current
              current["settingsNotifications"] = image
              return current
          }
          return image
      }
  }
  var settingsSecurity: CGImage {
      if let image = cached.with({ $0["settingsSecurity"] }) {
          return image
      } else {
          let image = _settingsSecurity()
          _ = cached.modify { current in 
              var current = current
              current["settingsSecurity"] = image
              return current
          }
          return image
      }
  }
  var settingsStickers: CGImage {
      if let image = cached.with({ $0["settingsStickers"] }) {
          return image
      } else {
          let image = _settingsStickers()
          _ = cached.modify { current in 
              var current = current
              current["settingsStickers"] = image
              return current
          }
          return image
      }
  }
  var settingsStorage: CGImage {
      if let image = cached.with({ $0["settingsStorage"] }) {
          return image
      } else {
          let image = _settingsStorage()
          _ = cached.modify { current in 
              var current = current
              current["settingsStorage"] = image
              return current
          }
          return image
      }
  }
  var settingsProxy: CGImage {
      if let image = cached.with({ $0["settingsProxy"] }) {
          return image
      } else {
          let image = _settingsProxy()
          _ = cached.modify { current in 
              var current = current
              current["settingsProxy"] = image
              return current
          }
          return image
      }
  }
  var settingsAppearance: CGImage {
      if let image = cached.with({ $0["settingsAppearance"] }) {
          return image
      } else {
          let image = _settingsAppearance()
          _ = cached.modify { current in 
              var current = current
              current["settingsAppearance"] = image
              return current
          }
          return image
      }
  }
  var settingsPassport: CGImage {
      if let image = cached.with({ $0["settingsPassport"] }) {
          return image
      } else {
          let image = _settingsPassport()
          _ = cached.modify { current in 
              var current = current
              current["settingsPassport"] = image
              return current
          }
          return image
      }
  }
  var settingsWallet: CGImage {
      if let image = cached.with({ $0["settingsWallet"] }) {
          return image
      } else {
          let image = _settingsWallet()
          _ = cached.modify { current in 
              var current = current
              current["settingsWallet"] = image
              return current
          }
          return image
      }
  }
  var settingsUpdate: CGImage {
      if let image = cached.with({ $0["settingsUpdate"] }) {
          return image
      } else {
          let image = _settingsUpdate()
          _ = cached.modify { current in 
              var current = current
              current["settingsUpdate"] = image
              return current
          }
          return image
      }
  }
  var settingsFilters: CGImage {
      if let image = cached.with({ $0["settingsFilters"] }) {
          return image
      } else {
          let image = _settingsFilters()
          _ = cached.modify { current in 
              var current = current
              current["settingsFilters"] = image
              return current
          }
          return image
      }
  }
  var settingsAskQuestionActive: CGImage {
      if let image = cached.with({ $0["settingsAskQuestionActive"] }) {
          return image
      } else {
          let image = _settingsAskQuestionActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsAskQuestionActive"] = image
              return current
          }
          return image
      }
  }
  var settingsFaqActive: CGImage {
      if let image = cached.with({ $0["settingsFaqActive"] }) {
          return image
      } else {
          let image = _settingsFaqActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsFaqActive"] = image
              return current
          }
          return image
      }
  }
  var settingsGeneralActive: CGImage {
      if let image = cached.with({ $0["settingsGeneralActive"] }) {
          return image
      } else {
          let image = _settingsGeneralActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsGeneralActive"] = image
              return current
          }
          return image
      }
  }
  var settingsLanguageActive: CGImage {
      if let image = cached.with({ $0["settingsLanguageActive"] }) {
          return image
      } else {
          let image = _settingsLanguageActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsLanguageActive"] = image
              return current
          }
          return image
      }
  }
  var settingsNotificationsActive: CGImage {
      if let image = cached.with({ $0["settingsNotificationsActive"] }) {
          return image
      } else {
          let image = _settingsNotificationsActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsNotificationsActive"] = image
              return current
          }
          return image
      }
  }
  var settingsSecurityActive: CGImage {
      if let image = cached.with({ $0["settingsSecurityActive"] }) {
          return image
      } else {
          let image = _settingsSecurityActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsSecurityActive"] = image
              return current
          }
          return image
      }
  }
  var settingsStickersActive: CGImage {
      if let image = cached.with({ $0["settingsStickersActive"] }) {
          return image
      } else {
          let image = _settingsStickersActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsStickersActive"] = image
              return current
          }
          return image
      }
  }
  var settingsStorageActive: CGImage {
      if let image = cached.with({ $0["settingsStorageActive"] }) {
          return image
      } else {
          let image = _settingsStorageActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsStorageActive"] = image
              return current
          }
          return image
      }
  }
  var settingsProxyActive: CGImage {
      if let image = cached.with({ $0["settingsProxyActive"] }) {
          return image
      } else {
          let image = _settingsProxyActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsProxyActive"] = image
              return current
          }
          return image
      }
  }
  var settingsAppearanceActive: CGImage {
      if let image = cached.with({ $0["settingsAppearanceActive"] }) {
          return image
      } else {
          let image = _settingsAppearanceActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsAppearanceActive"] = image
              return current
          }
          return image
      }
  }
  var settingsPassportActive: CGImage {
      if let image = cached.with({ $0["settingsPassportActive"] }) {
          return image
      } else {
          let image = _settingsPassportActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsPassportActive"] = image
              return current
          }
          return image
      }
  }
  var settingsWalletActive: CGImage {
      if let image = cached.with({ $0["settingsWalletActive"] }) {
          return image
      } else {
          let image = _settingsWalletActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsWalletActive"] = image
              return current
          }
          return image
      }
  }
  var settingsUpdateActive: CGImage {
      if let image = cached.with({ $0["settingsUpdateActive"] }) {
          return image
      } else {
          let image = _settingsUpdateActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsUpdateActive"] = image
              return current
          }
          return image
      }
  }
  var settingsFiltersActive: CGImage {
      if let image = cached.with({ $0["settingsFiltersActive"] }) {
          return image
      } else {
          let image = _settingsFiltersActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsFiltersActive"] = image
              return current
          }
          return image
      }
  }
  var settingsProfile: CGImage {
      if let image = cached.with({ $0["settingsProfile"] }) {
          return image
      } else {
          let image = _settingsProfile()
          _ = cached.modify { current in 
              var current = current
              current["settingsProfile"] = image
              return current
          }
          return image
      }
  }
  var generalCheck: CGImage {
      if let image = cached.with({ $0["generalCheck"] }) {
          return image
      } else {
          let image = _generalCheck()
          _ = cached.modify { current in 
              var current = current
              current["generalCheck"] = image
              return current
          }
          return image
      }
  }
  var settingsAbout: CGImage {
      if let image = cached.with({ $0["settingsAbout"] }) {
          return image
      } else {
          let image = _settingsAbout()
          _ = cached.modify { current in 
              var current = current
              current["settingsAbout"] = image
              return current
          }
          return image
      }
  }
  var settingsLogout: CGImage {
      if let image = cached.with({ $0["settingsLogout"] }) {
          return image
      } else {
          let image = _settingsLogout()
          _ = cached.modify { current in 
              var current = current
              current["settingsLogout"] = image
              return current
          }
          return image
      }
  }
  var fastSettingsLock: CGImage {
      if let image = cached.with({ $0["fastSettingsLock"] }) {
          return image
      } else {
          let image = _fastSettingsLock()
          _ = cached.modify { current in 
              var current = current
              current["fastSettingsLock"] = image
              return current
          }
          return image
      }
  }
  var fastSettingsDark: CGImage {
      if let image = cached.with({ $0["fastSettingsDark"] }) {
          return image
      } else {
          let image = _fastSettingsDark()
          _ = cached.modify { current in 
              var current = current
              current["fastSettingsDark"] = image
              return current
          }
          return image
      }
  }
  var fastSettingsSunny: CGImage {
      if let image = cached.with({ $0["fastSettingsSunny"] }) {
          return image
      } else {
          let image = _fastSettingsSunny()
          _ = cached.modify { current in 
              var current = current
              current["fastSettingsSunny"] = image
              return current
          }
          return image
      }
  }
  var fastSettingsMute: CGImage {
      if let image = cached.with({ $0["fastSettingsMute"] }) {
          return image
      } else {
          let image = _fastSettingsMute()
          _ = cached.modify { current in 
              var current = current
              current["fastSettingsMute"] = image
              return current
          }
          return image
      }
  }
  var fastSettingsUnmute: CGImage {
      if let image = cached.with({ $0["fastSettingsUnmute"] }) {
          return image
      } else {
          let image = _fastSettingsUnmute()
          _ = cached.modify { current in 
              var current = current
              current["fastSettingsUnmute"] = image
              return current
          }
          return image
      }
  }
  var chatRecordVideo: CGImage {
      if let image = cached.with({ $0["chatRecordVideo"] }) {
          return image
      } else {
          let image = _chatRecordVideo()
          _ = cached.modify { current in 
              var current = current
              current["chatRecordVideo"] = image
              return current
          }
          return image
      }
  }
  var inputChannelMute: CGImage {
      if let image = cached.with({ $0["inputChannelMute"] }) {
          return image
      } else {
          let image = _inputChannelMute()
          _ = cached.modify { current in 
              var current = current
              current["inputChannelMute"] = image
              return current
          }
          return image
      }
  }
  var inputChannelUnmute: CGImage {
      if let image = cached.with({ $0["inputChannelUnmute"] }) {
          return image
      } else {
          let image = _inputChannelUnmute()
          _ = cached.modify { current in 
              var current = current
              current["inputChannelUnmute"] = image
              return current
          }
          return image
      }
  }
  var changePhoneNumberIntro: CGImage {
      if let image = cached.with({ $0["changePhoneNumberIntro"] }) {
          return image
      } else {
          let image = _changePhoneNumberIntro()
          _ = cached.modify { current in 
              var current = current
              current["changePhoneNumberIntro"] = image
              return current
          }
          return image
      }
  }
  var peerSavedMessages: CGImage {
      if let image = cached.with({ $0["peerSavedMessages"] }) {
          return image
      } else {
          let image = _peerSavedMessages()
          _ = cached.modify { current in 
              var current = current
              current["peerSavedMessages"] = image
              return current
          }
          return image
      }
  }
  var previewSenderCollage: CGImage {
      if let image = cached.with({ $0["previewSenderCollage"] }) {
          return image
      } else {
          let image = _previewSenderCollage()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderCollage"] = image
              return current
          }
          return image
      }
  }
  var previewSenderPhoto: CGImage {
      if let image = cached.with({ $0["previewSenderPhoto"] }) {
          return image
      } else {
          let image = _previewSenderPhoto()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderPhoto"] = image
              return current
          }
          return image
      }
  }
  var previewSenderFile: CGImage {
      if let image = cached.with({ $0["previewSenderFile"] }) {
          return image
      } else {
          let image = _previewSenderFile()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderFile"] = image
              return current
          }
          return image
      }
  }
  var previewSenderCrop: CGImage {
      if let image = cached.with({ $0["previewSenderCrop"] }) {
          return image
      } else {
          let image = _previewSenderCrop()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderCrop"] = image
              return current
          }
          return image
      }
  }
  var previewSenderDelete: CGImage {
      if let image = cached.with({ $0["previewSenderDelete"] }) {
          return image
      } else {
          let image = _previewSenderDelete()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderDelete"] = image
              return current
          }
          return image
      }
  }
  var previewSenderDeleteFile: CGImage {
      if let image = cached.with({ $0["previewSenderDeleteFile"] }) {
          return image
      } else {
          let image = _previewSenderDeleteFile()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderDeleteFile"] = image
              return current
          }
          return image
      }
  }
  var previewSenderArchive: CGImage {
      if let image = cached.with({ $0["previewSenderArchive"] }) {
          return image
      } else {
          let image = _previewSenderArchive()
          _ = cached.modify { current in 
              var current = current
              current["previewSenderArchive"] = image
              return current
          }
          return image
      }
  }
  var chatGoMessage: CGImage {
      if let image = cached.with({ $0["chatGoMessage"] }) {
          return image
      } else {
          let image = _chatGoMessage()
          _ = cached.modify { current in 
              var current = current
              current["chatGoMessage"] = image
              return current
          }
          return image
      }
  }
  var chatGroupToggleSelected: CGImage {
      if let image = cached.with({ $0["chatGroupToggleSelected"] }) {
          return image
      } else {
          let image = _chatGroupToggleSelected()
          _ = cached.modify { current in 
              var current = current
              current["chatGroupToggleSelected"] = image
              return current
          }
          return image
      }
  }
  var chatGroupToggleUnselected: CGImage {
      if let image = cached.with({ $0["chatGroupToggleUnselected"] }) {
          return image
      } else {
          let image = _chatGroupToggleUnselected()
          _ = cached.modify { current in 
              var current = current
              current["chatGroupToggleUnselected"] = image
              return current
          }
          return image
      }
  }
  var successModalProgress: CGImage {
      if let image = cached.with({ $0["successModalProgress"] }) {
          return image
      } else {
          let image = _successModalProgress()
          _ = cached.modify { current in 
              var current = current
              current["successModalProgress"] = image
              return current
          }
          return image
      }
  }
  var accentColorSelect: CGImage {
      if let image = cached.with({ $0["accentColorSelect"] }) {
          return image
      } else {
          let image = _accentColorSelect()
          _ = cached.modify { current in 
              var current = current
              current["accentColorSelect"] = image
              return current
          }
          return image
      }
  }
  var chatShareWallpaper: CGImage {
      if let image = cached.with({ $0["chatShareWallpaper"] }) {
          return image
      } else {
          let image = _chatShareWallpaper()
          _ = cached.modify { current in 
              var current = current
              current["chatShareWallpaper"] = image
              return current
          }
          return image
      }
  }
  var chatGotoMessageWallpaper: CGImage {
      if let image = cached.with({ $0["chatGotoMessageWallpaper"] }) {
          return image
      } else {
          let image = _chatGotoMessageWallpaper()
          _ = cached.modify { current in 
              var current = current
              current["chatGotoMessageWallpaper"] = image
              return current
          }
          return image
      }
  }
  var transparentBackground: CGImage {
      if let image = cached.with({ $0["transparentBackground"] }) {
          return image
      } else {
          let image = _transparentBackground()
          _ = cached.modify { current in 
              var current = current
              current["transparentBackground"] = image
              return current
          }
          return image
      }
  }
  var lottieTransparentBackground: CGImage {
      if let image = cached.with({ $0["lottieTransparentBackground"] }) {
          return image
      } else {
          let image = _lottieTransparentBackground()
          _ = cached.modify { current in 
              var current = current
              current["lottieTransparentBackground"] = image
              return current
          }
          return image
      }
  }
  var passcodeTouchId: CGImage {
      if let image = cached.with({ $0["passcodeTouchId"] }) {
          return image
      } else {
          let image = _passcodeTouchId()
          _ = cached.modify { current in 
              var current = current
              current["passcodeTouchId"] = image
              return current
          }
          return image
      }
  }
  var passcodeLogin: CGImage {
      if let image = cached.with({ $0["passcodeLogin"] }) {
          return image
      } else {
          let image = _passcodeLogin()
          _ = cached.modify { current in 
              var current = current
              current["passcodeLogin"] = image
              return current
          }
          return image
      }
  }
  var confirmDeleteMessagesAccessory: CGImage {
      if let image = cached.with({ $0["confirmDeleteMessagesAccessory"] }) {
          return image
      } else {
          let image = _confirmDeleteMessagesAccessory()
          _ = cached.modify { current in 
              var current = current
              current["confirmDeleteMessagesAccessory"] = image
              return current
          }
          return image
      }
  }
  var alertCheckBoxSelected: CGImage {
      if let image = cached.with({ $0["alertCheckBoxSelected"] }) {
          return image
      } else {
          let image = _alertCheckBoxSelected()
          _ = cached.modify { current in 
              var current = current
              current["alertCheckBoxSelected"] = image
              return current
          }
          return image
      }
  }
  var alertCheckBoxUnselected: CGImage {
      if let image = cached.with({ $0["alertCheckBoxUnselected"] }) {
          return image
      } else {
          let image = _alertCheckBoxUnselected()
          _ = cached.modify { current in 
              var current = current
              current["alertCheckBoxUnselected"] = image
              return current
          }
          return image
      }
  }
  var confirmPinAccessory: CGImage {
      if let image = cached.with({ $0["confirmPinAccessory"] }) {
          return image
      } else {
          let image = _confirmPinAccessory()
          _ = cached.modify { current in 
              var current = current
              current["confirmPinAccessory"] = image
              return current
          }
          return image
      }
  }
  var confirmDeleteChatAccessory: CGImage {
      if let image = cached.with({ $0["confirmDeleteChatAccessory"] }) {
          return image
      } else {
          let image = _confirmDeleteChatAccessory()
          _ = cached.modify { current in 
              var current = current
              current["confirmDeleteChatAccessory"] = image
              return current
          }
          return image
      }
  }
  var stickersEmptySearch: CGImage {
      if let image = cached.with({ $0["stickersEmptySearch"] }) {
          return image
      } else {
          let image = _stickersEmptySearch()
          _ = cached.modify { current in 
              var current = current
              current["stickersEmptySearch"] = image
              return current
          }
          return image
      }
  }
  var twoStepVerificationCreateIntro: CGImage {
      if let image = cached.with({ $0["twoStepVerificationCreateIntro"] }) {
          return image
      } else {
          let image = _twoStepVerificationCreateIntro()
          _ = cached.modify { current in 
              var current = current
              current["twoStepVerificationCreateIntro"] = image
              return current
          }
          return image
      }
  }
  var secureIdAuth: CGImage {
      if let image = cached.with({ $0["secureIdAuth"] }) {
          return image
      } else {
          let image = _secureIdAuth()
          _ = cached.modify { current in 
              var current = current
              current["secureIdAuth"] = image
              return current
          }
          return image
      }
  }
  var ivAudioPlay: CGImage {
      if let image = cached.with({ $0["ivAudioPlay"] }) {
          return image
      } else {
          let image = _ivAudioPlay()
          _ = cached.modify { current in 
              var current = current
              current["ivAudioPlay"] = image
              return current
          }
          return image
      }
  }
  var ivAudioPause: CGImage {
      if let image = cached.with({ $0["ivAudioPause"] }) {
          return image
      } else {
          let image = _ivAudioPause()
          _ = cached.modify { current in 
              var current = current
              current["ivAudioPause"] = image
              return current
          }
          return image
      }
  }
  var proxyEnable: CGImage {
      if let image = cached.with({ $0["proxyEnable"] }) {
          return image
      } else {
          let image = _proxyEnable()
          _ = cached.modify { current in 
              var current = current
              current["proxyEnable"] = image
              return current
          }
          return image
      }
  }
  var proxyEnabled: CGImage {
      if let image = cached.with({ $0["proxyEnabled"] }) {
          return image
      } else {
          let image = _proxyEnabled()
          _ = cached.modify { current in 
              var current = current
              current["proxyEnabled"] = image
              return current
          }
          return image
      }
  }
  var proxyState: CGImage {
      if let image = cached.with({ $0["proxyState"] }) {
          return image
      } else {
          let image = _proxyState()
          _ = cached.modify { current in 
              var current = current
              current["proxyState"] = image
              return current
          }
          return image
      }
  }
  var proxyDeleteListItem: CGImage {
      if let image = cached.with({ $0["proxyDeleteListItem"] }) {
          return image
      } else {
          let image = _proxyDeleteListItem()
          _ = cached.modify { current in 
              var current = current
              current["proxyDeleteListItem"] = image
              return current
          }
          return image
      }
  }
  var proxyInfoListItem: CGImage {
      if let image = cached.with({ $0["proxyInfoListItem"] }) {
          return image
      } else {
          let image = _proxyInfoListItem()
          _ = cached.modify { current in 
              var current = current
              current["proxyInfoListItem"] = image
              return current
          }
          return image
      }
  }
  var proxyConnectedListItem: CGImage {
      if let image = cached.with({ $0["proxyConnectedListItem"] }) {
          return image
      } else {
          let image = _proxyConnectedListItem()
          _ = cached.modify { current in 
              var current = current
              current["proxyConnectedListItem"] = image
              return current
          }
          return image
      }
  }
  var proxyAddProxy: CGImage {
      if let image = cached.with({ $0["proxyAddProxy"] }) {
          return image
      } else {
          let image = _proxyAddProxy()
          _ = cached.modify { current in 
              var current = current
              current["proxyAddProxy"] = image
              return current
          }
          return image
      }
  }
  var proxyNextWaitingListItem: CGImage {
      if let image = cached.with({ $0["proxyNextWaitingListItem"] }) {
          return image
      } else {
          let image = _proxyNextWaitingListItem()
          _ = cached.modify { current in 
              var current = current
              current["proxyNextWaitingListItem"] = image
              return current
          }
          return image
      }
  }
  var passportForgotPassword: CGImage {
      if let image = cached.with({ $0["passportForgotPassword"] }) {
          return image
      } else {
          let image = _passportForgotPassword()
          _ = cached.modify { current in 
              var current = current
              current["passportForgotPassword"] = image
              return current
          }
          return image
      }
  }
  var confirmAppAccessoryIcon: CGImage {
      if let image = cached.with({ $0["confirmAppAccessoryIcon"] }) {
          return image
      } else {
          let image = _confirmAppAccessoryIcon()
          _ = cached.modify { current in 
              var current = current
              current["confirmAppAccessoryIcon"] = image
              return current
          }
          return image
      }
  }
  var passportPassport: CGImage {
      if let image = cached.with({ $0["passportPassport"] }) {
          return image
      } else {
          let image = _passportPassport()
          _ = cached.modify { current in 
              var current = current
              current["passportPassport"] = image
              return current
          }
          return image
      }
  }
  var passportIdCardReverse: CGImage {
      if let image = cached.with({ $0["passportIdCardReverse"] }) {
          return image
      } else {
          let image = _passportIdCardReverse()
          _ = cached.modify { current in 
              var current = current
              current["passportIdCardReverse"] = image
              return current
          }
          return image
      }
  }
  var passportIdCard: CGImage {
      if let image = cached.with({ $0["passportIdCard"] }) {
          return image
      } else {
          let image = _passportIdCard()
          _ = cached.modify { current in 
              var current = current
              current["passportIdCard"] = image
              return current
          }
          return image
      }
  }
  var passportSelfie: CGImage {
      if let image = cached.with({ $0["passportSelfie"] }) {
          return image
      } else {
          let image = _passportSelfie()
          _ = cached.modify { current in 
              var current = current
              current["passportSelfie"] = image
              return current
          }
          return image
      }
  }
  var passportDriverLicense: CGImage {
      if let image = cached.with({ $0["passportDriverLicense"] }) {
          return image
      } else {
          let image = _passportDriverLicense()
          _ = cached.modify { current in 
              var current = current
              current["passportDriverLicense"] = image
              return current
          }
          return image
      }
  }
  var chatOverlayVoiceRecording: CGImage {
      if let image = cached.with({ $0["chatOverlayVoiceRecording"] }) {
          return image
      } else {
          let image = _chatOverlayVoiceRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlayVoiceRecording"] = image
              return current
          }
          return image
      }
  }
  var chatOverlayVideoRecording: CGImage {
      if let image = cached.with({ $0["chatOverlayVideoRecording"] }) {
          return image
      } else {
          let image = _chatOverlayVideoRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlayVideoRecording"] = image
              return current
          }
          return image
      }
  }
  var chatOverlaySendRecording: CGImage {
      if let image = cached.with({ $0["chatOverlaySendRecording"] }) {
          return image
      } else {
          let image = _chatOverlaySendRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlaySendRecording"] = image
              return current
          }
          return image
      }
  }
  var chatOverlayLockArrowRecording: CGImage {
      if let image = cached.with({ $0["chatOverlayLockArrowRecording"] }) {
          return image
      } else {
          let image = _chatOverlayLockArrowRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlayLockArrowRecording"] = image
              return current
          }
          return image
      }
  }
  var chatOverlayLockerBodyRecording: CGImage {
      if let image = cached.with({ $0["chatOverlayLockerBodyRecording"] }) {
          return image
      } else {
          let image = _chatOverlayLockerBodyRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlayLockerBodyRecording"] = image
              return current
          }
          return image
      }
  }
  var chatOverlayLockerHeadRecording: CGImage {
      if let image = cached.with({ $0["chatOverlayLockerHeadRecording"] }) {
          return image
      } else {
          let image = _chatOverlayLockerHeadRecording()
          _ = cached.modify { current in 
              var current = current
              current["chatOverlayLockerHeadRecording"] = image
              return current
          }
          return image
      }
  }
  var locationPin: CGImage {
      if let image = cached.with({ $0["locationPin"] }) {
          return image
      } else {
          let image = _locationPin()
          _ = cached.modify { current in 
              var current = current
              current["locationPin"] = image
              return current
          }
          return image
      }
  }
  var locationMapPin: CGImage {
      if let image = cached.with({ $0["locationMapPin"] }) {
          return image
      } else {
          let image = _locationMapPin()
          _ = cached.modify { current in 
              var current = current
              current["locationMapPin"] = image
              return current
          }
          return image
      }
  }
  var locationMapLocate: CGImage {
      if let image = cached.with({ $0["locationMapLocate"] }) {
          return image
      } else {
          let image = _locationMapLocate()
          _ = cached.modify { current in 
              var current = current
              current["locationMapLocate"] = image
              return current
          }
          return image
      }
  }
  var locationMapLocated: CGImage {
      if let image = cached.with({ $0["locationMapLocated"] }) {
          return image
      } else {
          let image = _locationMapLocated()
          _ = cached.modify { current in 
              var current = current
              current["locationMapLocated"] = image
              return current
          }
          return image
      }
  }
  var passportSettings: CGImage {
      if let image = cached.with({ $0["passportSettings"] }) {
          return image
      } else {
          let image = _passportSettings()
          _ = cached.modify { current in 
              var current = current
              current["passportSettings"] = image
              return current
          }
          return image
      }
  }
  var passportInfo: CGImage {
      if let image = cached.with({ $0["passportInfo"] }) {
          return image
      } else {
          let image = _passportInfo()
          _ = cached.modify { current in 
              var current = current
              current["passportInfo"] = image
              return current
          }
          return image
      }
  }
  var editMessageMedia: CGImage {
      if let image = cached.with({ $0["editMessageMedia"] }) {
          return image
      } else {
          let image = _editMessageMedia()
          _ = cached.modify { current in 
              var current = current
              current["editMessageMedia"] = image
              return current
          }
          return image
      }
  }
  var playerMusicPlaceholder: CGImage {
      if let image = cached.with({ $0["playerMusicPlaceholder"] }) {
          return image
      } else {
          let image = _playerMusicPlaceholder()
          _ = cached.modify { current in 
              var current = current
              current["playerMusicPlaceholder"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPlaceholder: CGImage {
      if let image = cached.with({ $0["chatMusicPlaceholder"] }) {
          return image
      } else {
          let image = _chatMusicPlaceholder()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPlaceholder"] = image
              return current
          }
          return image
      }
  }
  var chatMusicPlaceholderCap: CGImage {
      if let image = cached.with({ $0["chatMusicPlaceholderCap"] }) {
          return image
      } else {
          let image = _chatMusicPlaceholderCap()
          _ = cached.modify { current in 
              var current = current
              current["chatMusicPlaceholderCap"] = image
              return current
          }
          return image
      }
  }
  var searchArticle: CGImage {
      if let image = cached.with({ $0["searchArticle"] }) {
          return image
      } else {
          let image = _searchArticle()
          _ = cached.modify { current in 
              var current = current
              current["searchArticle"] = image
              return current
          }
          return image
      }
  }
  var searchSaved: CGImage {
      if let image = cached.with({ $0["searchSaved"] }) {
          return image
      } else {
          let image = _searchSaved()
          _ = cached.modify { current in 
              var current = current
              current["searchSaved"] = image
              return current
          }
          return image
      }
  }
  var archivedChats: CGImage {
      if let image = cached.with({ $0["archivedChats"] }) {
          return image
      } else {
          let image = _archivedChats()
          _ = cached.modify { current in 
              var current = current
              current["archivedChats"] = image
              return current
          }
          return image
      }
  }
  var hintPeerActive: CGImage {
      if let image = cached.with({ $0["hintPeerActive"] }) {
          return image
      } else {
          let image = _hintPeerActive()
          _ = cached.modify { current in 
              var current = current
              current["hintPeerActive"] = image
              return current
          }
          return image
      }
  }
  var hintPeerActiveSelected: CGImage {
      if let image = cached.with({ $0["hintPeerActiveSelected"] }) {
          return image
      } else {
          let image = _hintPeerActiveSelected()
          _ = cached.modify { current in 
              var current = current
              current["hintPeerActiveSelected"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_delete: CGImage {
      if let image = cached.with({ $0["chatSwiping_delete"] }) {
          return image
      } else {
          let image = _chatSwiping_delete()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_delete"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_mute: CGImage {
      if let image = cached.with({ $0["chatSwiping_mute"] }) {
          return image
      } else {
          let image = _chatSwiping_mute()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_mute"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_unmute: CGImage {
      if let image = cached.with({ $0["chatSwiping_unmute"] }) {
          return image
      } else {
          let image = _chatSwiping_unmute()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_unmute"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_read: CGImage {
      if let image = cached.with({ $0["chatSwiping_read"] }) {
          return image
      } else {
          let image = _chatSwiping_read()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_read"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_unread: CGImage {
      if let image = cached.with({ $0["chatSwiping_unread"] }) {
          return image
      } else {
          let image = _chatSwiping_unread()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_unread"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_pin: CGImage {
      if let image = cached.with({ $0["chatSwiping_pin"] }) {
          return image
      } else {
          let image = _chatSwiping_pin()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_pin"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_unpin: CGImage {
      if let image = cached.with({ $0["chatSwiping_unpin"] }) {
          return image
      } else {
          let image = _chatSwiping_unpin()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_unpin"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_archive: CGImage {
      if let image = cached.with({ $0["chatSwiping_archive"] }) {
          return image
      } else {
          let image = _chatSwiping_archive()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_archive"] = image
              return current
          }
          return image
      }
  }
  var chatSwiping_unarchive: CGImage {
      if let image = cached.with({ $0["chatSwiping_unarchive"] }) {
          return image
      } else {
          let image = _chatSwiping_unarchive()
          _ = cached.modify { current in 
              var current = current
              current["chatSwiping_unarchive"] = image
              return current
          }
          return image
      }
  }
  var galleryPrev: CGImage {
      if let image = cached.with({ $0["galleryPrev"] }) {
          return image
      } else {
          let image = _galleryPrev()
          _ = cached.modify { current in 
              var current = current
              current["galleryPrev"] = image
              return current
          }
          return image
      }
  }
  var galleryNext: CGImage {
      if let image = cached.with({ $0["galleryNext"] }) {
          return image
      } else {
          let image = _galleryNext()
          _ = cached.modify { current in 
              var current = current
              current["galleryNext"] = image
              return current
          }
          return image
      }
  }
  var galleryMore: CGImage {
      if let image = cached.with({ $0["galleryMore"] }) {
          return image
      } else {
          let image = _galleryMore()
          _ = cached.modify { current in 
              var current = current
              current["galleryMore"] = image
              return current
          }
          return image
      }
  }
  var galleryShare: CGImage {
      if let image = cached.with({ $0["galleryShare"] }) {
          return image
      } else {
          let image = _galleryShare()
          _ = cached.modify { current in 
              var current = current
              current["galleryShare"] = image
              return current
          }
          return image
      }
  }
  var galleryFastSave: CGImage {
      if let image = cached.with({ $0["galleryFastSave"] }) {
          return image
      } else {
          let image = _galleryFastSave()
          _ = cached.modify { current in 
              var current = current
              current["galleryFastSave"] = image
              return current
          }
          return image
      }
  }
  var playingVoice1x: CGImage {
      if let image = cached.with({ $0["playingVoice1x"] }) {
          return image
      } else {
          let image = _playingVoice1x()
          _ = cached.modify { current in 
              var current = current
              current["playingVoice1x"] = image
              return current
          }
          return image
      }
  }
  var playingVoice2x: CGImage {
      if let image = cached.with({ $0["playingVoice2x"] }) {
          return image
      } else {
          let image = _playingVoice2x()
          _ = cached.modify { current in 
              var current = current
              current["playingVoice2x"] = image
              return current
          }
          return image
      }
  }
  var galleryRotate: CGImage {
      if let image = cached.with({ $0["galleryRotate"] }) {
          return image
      } else {
          let image = _galleryRotate()
          _ = cached.modify { current in 
              var current = current
              current["galleryRotate"] = image
              return current
          }
          return image
      }
  }
  var galleryZoomIn: CGImage {
      if let image = cached.with({ $0["galleryZoomIn"] }) {
          return image
      } else {
          let image = _galleryZoomIn()
          _ = cached.modify { current in 
              var current = current
              current["galleryZoomIn"] = image
              return current
          }
          return image
      }
  }
  var galleryZoomOut: CGImage {
      if let image = cached.with({ $0["galleryZoomOut"] }) {
          return image
      } else {
          let image = _galleryZoomOut()
          _ = cached.modify { current in 
              var current = current
              current["galleryZoomOut"] = image
              return current
          }
          return image
      }
  }
  var editMessageCurrentPhoto: CGImage {
      if let image = cached.with({ $0["editMessageCurrentPhoto"] }) {
          return image
      } else {
          let image = _editMessageCurrentPhoto()
          _ = cached.modify { current in 
              var current = current
              current["editMessageCurrentPhoto"] = image
              return current
          }
          return image
      }
  }
  var chatSwipeReply: CGImage {
      if let image = cached.with({ $0["chatSwipeReply"] }) {
          return image
      } else {
          let image = _chatSwipeReply()
          _ = cached.modify { current in 
              var current = current
              current["chatSwipeReply"] = image
              return current
          }
          return image
      }
  }
  var chatSwipeReplyWallpaper: CGImage {
      if let image = cached.with({ $0["chatSwipeReplyWallpaper"] }) {
          return image
      } else {
          let image = _chatSwipeReplyWallpaper()
          _ = cached.modify { current in 
              var current = current
              current["chatSwipeReplyWallpaper"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerPlay: CGImage {
      if let image = cached.with({ $0["videoPlayerPlay"] }) {
          return image
      } else {
          let image = _videoPlayerPlay()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerPlay"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerPause: CGImage {
      if let image = cached.with({ $0["videoPlayerPause"] }) {
          return image
      } else {
          let image = _videoPlayerPause()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerPause"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerEnterFullScreen: CGImage {
      if let image = cached.with({ $0["videoPlayerEnterFullScreen"] }) {
          return image
      } else {
          let image = _videoPlayerEnterFullScreen()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerEnterFullScreen"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerExitFullScreen: CGImage {
      if let image = cached.with({ $0["videoPlayerExitFullScreen"] }) {
          return image
      } else {
          let image = _videoPlayerExitFullScreen()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerExitFullScreen"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerPIPIn: CGImage {
      if let image = cached.with({ $0["videoPlayerPIPIn"] }) {
          return image
      } else {
          let image = _videoPlayerPIPIn()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerPIPIn"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerPIPOut: CGImage {
      if let image = cached.with({ $0["videoPlayerPIPOut"] }) {
          return image
      } else {
          let image = _videoPlayerPIPOut()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerPIPOut"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerRewind15Forward: CGImage {
      if let image = cached.with({ $0["videoPlayerRewind15Forward"] }) {
          return image
      } else {
          let image = _videoPlayerRewind15Forward()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerRewind15Forward"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerRewind15Backward: CGImage {
      if let image = cached.with({ $0["videoPlayerRewind15Backward"] }) {
          return image
      } else {
          let image = _videoPlayerRewind15Backward()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerRewind15Backward"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerVolume: CGImage {
      if let image = cached.with({ $0["videoPlayerVolume"] }) {
          return image
      } else {
          let image = _videoPlayerVolume()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerVolume"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerVolumeOff: CGImage {
      if let image = cached.with({ $0["videoPlayerVolumeOff"] }) {
          return image
      } else {
          let image = _videoPlayerVolumeOff()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerVolumeOff"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerClose: CGImage {
      if let image = cached.with({ $0["videoPlayerClose"] }) {
          return image
      } else {
          let image = _videoPlayerClose()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerClose"] = image
              return current
          }
          return image
      }
  }
  var videoPlayerSliderInteractor: CGImage {
      if let image = cached.with({ $0["videoPlayerSliderInteractor"] }) {
          return image
      } else {
          let image = _videoPlayerSliderInteractor()
          _ = cached.modify { current in 
              var current = current
              current["videoPlayerSliderInteractor"] = image
              return current
          }
          return image
      }
  }
  var streamingVideoDownload: CGImage {
      if let image = cached.with({ $0["streamingVideoDownload"] }) {
          return image
      } else {
          let image = _streamingVideoDownload()
          _ = cached.modify { current in 
              var current = current
              current["streamingVideoDownload"] = image
              return current
          }
          return image
      }
  }
  var videoCompactFetching: CGImage {
      if let image = cached.with({ $0["videoCompactFetching"] }) {
          return image
      } else {
          let image = _videoCompactFetching()
          _ = cached.modify { current in 
              var current = current
              current["videoCompactFetching"] = image
              return current
          }
          return image
      }
  }
  var compactStreamingFetchingCancel: CGImage {
      if let image = cached.with({ $0["compactStreamingFetchingCancel"] }) {
          return image
      } else {
          let image = _compactStreamingFetchingCancel()
          _ = cached.modify { current in 
              var current = current
              current["compactStreamingFetchingCancel"] = image
              return current
          }
          return image
      }
  }
  var customLocalizationDelete: CGImage {
      if let image = cached.with({ $0["customLocalizationDelete"] }) {
          return image
      } else {
          let image = _customLocalizationDelete()
          _ = cached.modify { current in 
              var current = current
              current["customLocalizationDelete"] = image
              return current
          }
          return image
      }
  }
  var pollAddOption: CGImage {
      if let image = cached.with({ $0["pollAddOption"] }) {
          return image
      } else {
          let image = _pollAddOption()
          _ = cached.modify { current in 
              var current = current
              current["pollAddOption"] = image
              return current
          }
          return image
      }
  }
  var pollDeleteOption: CGImage {
      if let image = cached.with({ $0["pollDeleteOption"] }) {
          return image
      } else {
          let image = _pollDeleteOption()
          _ = cached.modify { current in 
              var current = current
              current["pollDeleteOption"] = image
              return current
          }
          return image
      }
  }
  var resort: CGImage {
      if let image = cached.with({ $0["resort"] }) {
          return image
      } else {
          let image = _resort()
          _ = cached.modify { current in 
              var current = current
              current["resort"] = image
              return current
          }
          return image
      }
  }
  var chatPollVoteUnselected: CGImage {
      if let image = cached.with({ $0["chatPollVoteUnselected"] }) {
          return image
      } else {
          let image = _chatPollVoteUnselected()
          _ = cached.modify { current in 
              var current = current
              current["chatPollVoteUnselected"] = image
              return current
          }
          return image
      }
  }
  var chatPollVoteUnselectedBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatPollVoteUnselectedBubble_incoming"] }) {
          return image
      } else {
          let image = _chatPollVoteUnselectedBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatPollVoteUnselectedBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  var chatPollVoteUnselectedBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatPollVoteUnselectedBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatPollVoteUnselectedBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatPollVoteUnselectedBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  var peerInfoAdmins: CGImage {
      if let image = cached.with({ $0["peerInfoAdmins"] }) {
          return image
      } else {
          let image = _peerInfoAdmins()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoAdmins"] = image
              return current
          }
          return image
      }
  }
  var peerInfoPermissions: CGImage {
      if let image = cached.with({ $0["peerInfoPermissions"] }) {
          return image
      } else {
          let image = _peerInfoPermissions()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoPermissions"] = image
              return current
          }
          return image
      }
  }
  var peerInfoBanned: CGImage {
      if let image = cached.with({ $0["peerInfoBanned"] }) {
          return image
      } else {
          let image = _peerInfoBanned()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoBanned"] = image
              return current
          }
          return image
      }
  }
  var peerInfoMembers: CGImage {
      if let image = cached.with({ $0["peerInfoMembers"] }) {
          return image
      } else {
          let image = _peerInfoMembers()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoMembers"] = image
              return current
          }
          return image
      }
  }
  var chatUndoAction: CGImage {
      if let image = cached.with({ $0["chatUndoAction"] }) {
          return image
      } else {
          let image = _chatUndoAction()
          _ = cached.modify { current in 
              var current = current
              current["chatUndoAction"] = image
              return current
          }
          return image
      }
  }
  var appUpdate: CGImage {
      if let image = cached.with({ $0["appUpdate"] }) {
          return image
      } else {
          let image = _appUpdate()
          _ = cached.modify { current in 
              var current = current
              current["appUpdate"] = image
              return current
          }
          return image
      }
  }
  var inlineVideoSoundOff: CGImage {
      if let image = cached.with({ $0["inlineVideoSoundOff"] }) {
          return image
      } else {
          let image = _inlineVideoSoundOff()
          _ = cached.modify { current in 
              var current = current
              current["inlineVideoSoundOff"] = image
              return current
          }
          return image
      }
  }
  var inlineVideoSoundOn: CGImage {
      if let image = cached.with({ $0["inlineVideoSoundOn"] }) {
          return image
      } else {
          let image = _inlineVideoSoundOn()
          _ = cached.modify { current in 
              var current = current
              current["inlineVideoSoundOn"] = image
              return current
          }
          return image
      }
  }
  var logoutOptionAddAccount: CGImage {
      if let image = cached.with({ $0["logoutOptionAddAccount"] }) {
          return image
      } else {
          let image = _logoutOptionAddAccount()
          _ = cached.modify { current in 
              var current = current
              current["logoutOptionAddAccount"] = image
              return current
          }
          return image
      }
  }
  var logoutOptionSetPasscode: CGImage {
      if let image = cached.with({ $0["logoutOptionSetPasscode"] }) {
          return image
      } else {
          let image = _logoutOptionSetPasscode()
          _ = cached.modify { current in 
              var current = current
              current["logoutOptionSetPasscode"] = image
              return current
          }
          return image
      }
  }
  var logoutOptionClearCache: CGImage {
      if let image = cached.with({ $0["logoutOptionClearCache"] }) {
          return image
      } else {
          let image = _logoutOptionClearCache()
          _ = cached.modify { current in 
              var current = current
              current["logoutOptionClearCache"] = image
              return current
          }
          return image
      }
  }
  var logoutOptionChangePhoneNumber: CGImage {
      if let image = cached.with({ $0["logoutOptionChangePhoneNumber"] }) {
          return image
      } else {
          let image = _logoutOptionChangePhoneNumber()
          _ = cached.modify { current in 
              var current = current
              current["logoutOptionChangePhoneNumber"] = image
              return current
          }
          return image
      }
  }
  var logoutOptionContactSupport: CGImage {
      if let image = cached.with({ $0["logoutOptionContactSupport"] }) {
          return image
      } else {
          let image = _logoutOptionContactSupport()
          _ = cached.modify { current in 
              var current = current
              current["logoutOptionContactSupport"] = image
              return current
          }
          return image
      }
  }
  var disableEmojiPrediction: CGImage {
      if let image = cached.with({ $0["disableEmojiPrediction"] }) {
          return image
      } else {
          let image = _disableEmojiPrediction()
          _ = cached.modify { current in 
              var current = current
              current["disableEmojiPrediction"] = image
              return current
          }
          return image
      }
  }
  var scam: CGImage {
      if let image = cached.with({ $0["scam"] }) {
          return image
      } else {
          let image = _scam()
          _ = cached.modify { current in 
              var current = current
              current["scam"] = image
              return current
          }
          return image
      }
  }
  var scamActive: CGImage {
      if let image = cached.with({ $0["scamActive"] }) {
          return image
      } else {
          let image = _scamActive()
          _ = cached.modify { current in 
              var current = current
              current["scamActive"] = image
              return current
          }
          return image
      }
  }
  var chatScam: CGImage {
      if let image = cached.with({ $0["chatScam"] }) {
          return image
      } else {
          let image = _chatScam()
          _ = cached.modify { current in 
              var current = current
              current["chatScam"] = image
              return current
          }
          return image
      }
  }
  var chatUnarchive: CGImage {
      if let image = cached.with({ $0["chatUnarchive"] }) {
          return image
      } else {
          let image = _chatUnarchive()
          _ = cached.modify { current in 
              var current = current
              current["chatUnarchive"] = image
              return current
          }
          return image
      }
  }
  var chatArchive: CGImage {
      if let image = cached.with({ $0["chatArchive"] }) {
          return image
      } else {
          let image = _chatArchive()
          _ = cached.modify { current in 
              var current = current
              current["chatArchive"] = image
              return current
          }
          return image
      }
  }
  var privacySettings_blocked: CGImage {
      if let image = cached.with({ $0["privacySettings_blocked"] }) {
          return image
      } else {
          let image = _privacySettings_blocked()
          _ = cached.modify { current in 
              var current = current
              current["privacySettings_blocked"] = image
              return current
          }
          return image
      }
  }
  var privacySettings_activeSessions: CGImage {
      if let image = cached.with({ $0["privacySettings_activeSessions"] }) {
          return image
      } else {
          let image = _privacySettings_activeSessions()
          _ = cached.modify { current in 
              var current = current
              current["privacySettings_activeSessions"] = image
              return current
          }
          return image
      }
  }
  var privacySettings_passcode: CGImage {
      if let image = cached.with({ $0["privacySettings_passcode"] }) {
          return image
      } else {
          let image = _privacySettings_passcode()
          _ = cached.modify { current in 
              var current = current
              current["privacySettings_passcode"] = image
              return current
          }
          return image
      }
  }
  var privacySettings_twoStep: CGImage {
      if let image = cached.with({ $0["privacySettings_twoStep"] }) {
          return image
      } else {
          let image = _privacySettings_twoStep()
          _ = cached.modify { current in 
              var current = current
              current["privacySettings_twoStep"] = image
              return current
          }
          return image
      }
  }
  var deletedAccount: CGImage {
      if let image = cached.with({ $0["deletedAccount"] }) {
          return image
      } else {
          let image = _deletedAccount()
          _ = cached.modify { current in 
              var current = current
              current["deletedAccount"] = image
              return current
          }
          return image
      }
  }
  var stickerPackSelection: CGImage {
      if let image = cached.with({ $0["stickerPackSelection"] }) {
          return image
      } else {
          let image = _stickerPackSelection()
          _ = cached.modify { current in 
              var current = current
              current["stickerPackSelection"] = image
              return current
          }
          return image
      }
  }
  var stickerPackSelectionActive: CGImage {
      if let image = cached.with({ $0["stickerPackSelectionActive"] }) {
          return image
      } else {
          let image = _stickerPackSelectionActive()
          _ = cached.modify { current in 
              var current = current
              current["stickerPackSelectionActive"] = image
              return current
          }
          return image
      }
  }
  var entertainment_Emoji: CGImage {
      if let image = cached.with({ $0["entertainment_Emoji"] }) {
          return image
      } else {
          let image = _entertainment_Emoji()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_Emoji"] = image
              return current
          }
          return image
      }
  }
  var entertainment_Stickers: CGImage {
      if let image = cached.with({ $0["entertainment_Stickers"] }) {
          return image
      } else {
          let image = _entertainment_Stickers()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_Stickers"] = image
              return current
          }
          return image
      }
  }
  var entertainment_Gifs: CGImage {
      if let image = cached.with({ $0["entertainment_Gifs"] }) {
          return image
      } else {
          let image = _entertainment_Gifs()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_Gifs"] = image
              return current
          }
          return image
      }
  }
  var entertainment_Search: CGImage {
      if let image = cached.with({ $0["entertainment_Search"] }) {
          return image
      } else {
          let image = _entertainment_Search()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_Search"] = image
              return current
          }
          return image
      }
  }
  var entertainment_Settings: CGImage {
      if let image = cached.with({ $0["entertainment_Settings"] }) {
          return image
      } else {
          let image = _entertainment_Settings()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_Settings"] = image
              return current
          }
          return image
      }
  }
  var entertainment_SearchCancel: CGImage {
      if let image = cached.with({ $0["entertainment_SearchCancel"] }) {
          return image
      } else {
          let image = _entertainment_SearchCancel()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_SearchCancel"] = image
              return current
          }
          return image
      }
  }
  var scheduledAvatar: CGImage {
      if let image = cached.with({ $0["scheduledAvatar"] }) {
          return image
      } else {
          let image = _scheduledAvatar()
          _ = cached.modify { current in 
              var current = current
              current["scheduledAvatar"] = image
              return current
          }
          return image
      }
  }
  var scheduledInputAction: CGImage {
      if let image = cached.with({ $0["scheduledInputAction"] }) {
          return image
      } else {
          let image = _scheduledInputAction()
          _ = cached.modify { current in 
              var current = current
              current["scheduledInputAction"] = image
              return current
          }
          return image
      }
  }
  var verifyDialog: CGImage {
      if let image = cached.with({ $0["verifyDialog"] }) {
          return image
      } else {
          let image = _verifyDialog()
          _ = cached.modify { current in 
              var current = current
              current["verifyDialog"] = image
              return current
          }
          return image
      }
  }
  var verifyDialogActive: CGImage {
      if let image = cached.with({ $0["verifyDialogActive"] }) {
          return image
      } else {
          let image = _verifyDialogActive()
          _ = cached.modify { current in 
              var current = current
              current["verifyDialogActive"] = image
              return current
          }
          return image
      }
  }
  var chatInputScheduled: CGImage {
      if let image = cached.with({ $0["chatInputScheduled"] }) {
          return image
      } else {
          let image = _chatInputScheduled()
          _ = cached.modify { current in 
              var current = current
              current["chatInputScheduled"] = image
              return current
          }
          return image
      }
  }
  var appearanceAddPlatformTheme: CGImage {
      if let image = cached.with({ $0["appearanceAddPlatformTheme"] }) {
          return image
      } else {
          let image = _appearanceAddPlatformTheme()
          _ = cached.modify { current in 
              var current = current
              current["appearanceAddPlatformTheme"] = image
              return current
          }
          return image
      }
  }
  var wallet_close: CGImage {
      if let image = cached.with({ $0["wallet_close"] }) {
          return image
      } else {
          let image = _wallet_close()
          _ = cached.modify { current in 
              var current = current
              current["wallet_close"] = image
              return current
          }
          return image
      }
  }
  var wallet_qr: CGImage {
      if let image = cached.with({ $0["wallet_qr"] }) {
          return image
      } else {
          let image = _wallet_qr()
          _ = cached.modify { current in 
              var current = current
              current["wallet_qr"] = image
              return current
          }
          return image
      }
  }
  var wallet_receive: CGImage {
      if let image = cached.with({ $0["wallet_receive"] }) {
          return image
      } else {
          let image = _wallet_receive()
          _ = cached.modify { current in 
              var current = current
              current["wallet_receive"] = image
              return current
          }
          return image
      }
  }
  var wallet_send: CGImage {
      if let image = cached.with({ $0["wallet_send"] }) {
          return image
      } else {
          let image = _wallet_send()
          _ = cached.modify { current in 
              var current = current
              current["wallet_send"] = image
              return current
          }
          return image
      }
  }
  var wallet_settings: CGImage {
      if let image = cached.with({ $0["wallet_settings"] }) {
          return image
      } else {
          let image = _wallet_settings()
          _ = cached.modify { current in 
              var current = current
              current["wallet_settings"] = image
              return current
          }
          return image
      }
  }
  var wallet_update: CGImage {
      if let image = cached.with({ $0["wallet_update"] }) {
          return image
      } else {
          let image = _wallet_update()
          _ = cached.modify { current in 
              var current = current
              current["wallet_update"] = image
              return current
          }
          return image
      }
  }
  var wallet_passcode_visible: CGImage {
      if let image = cached.with({ $0["wallet_passcode_visible"] }) {
          return image
      } else {
          let image = _wallet_passcode_visible()
          _ = cached.modify { current in 
              var current = current
              current["wallet_passcode_visible"] = image
              return current
          }
          return image
      }
  }
  var wallet_passcode_hidden: CGImage {
      if let image = cached.with({ $0["wallet_passcode_hidden"] }) {
          return image
      } else {
          let image = _wallet_passcode_hidden()
          _ = cached.modify { current in 
              var current = current
              current["wallet_passcode_hidden"] = image
              return current
          }
          return image
      }
  }
  var wallpaper_color_close: CGImage {
      if let image = cached.with({ $0["wallpaper_color_close"] }) {
          return image
      } else {
          let image = _wallpaper_color_close()
          _ = cached.modify { current in 
              var current = current
              current["wallpaper_color_close"] = image
              return current
          }
          return image
      }
  }
  var wallpaper_color_add: CGImage {
      if let image = cached.with({ $0["wallpaper_color_add"] }) {
          return image
      } else {
          let image = _wallpaper_color_add()
          _ = cached.modify { current in 
              var current = current
              current["wallpaper_color_add"] = image
              return current
          }
          return image
      }
  }
  var wallpaper_color_swap: CGImage {
      if let image = cached.with({ $0["wallpaper_color_swap"] }) {
          return image
      } else {
          let image = _wallpaper_color_swap()
          _ = cached.modify { current in 
              var current = current
              current["wallpaper_color_swap"] = image
              return current
          }
          return image
      }
  }
  var wallpaper_color_rotate: CGImage {
      if let image = cached.with({ $0["wallpaper_color_rotate"] }) {
          return image
      } else {
          let image = _wallpaper_color_rotate()
          _ = cached.modify { current in 
              var current = current
              current["wallpaper_color_rotate"] = image
              return current
          }
          return image
      }
  }
  var login_cap: CGImage {
      if let image = cached.with({ $0["login_cap"] }) {
          return image
      } else {
          let image = _login_cap()
          _ = cached.modify { current in 
              var current = current
              current["login_cap"] = image
              return current
          }
          return image
      }
  }
  var login_qr_cap: CGImage {
      if let image = cached.with({ $0["login_qr_cap"] }) {
          return image
      } else {
          let image = _login_qr_cap()
          _ = cached.modify { current in 
              var current = current
              current["login_qr_cap"] = image
              return current
          }
          return image
      }
  }
  var login_qr_empty_cap: CGImage {
      if let image = cached.with({ $0["login_qr_empty_cap"] }) {
          return image
      } else {
          let image = _login_qr_empty_cap()
          _ = cached.modify { current in 
              var current = current
              current["login_qr_empty_cap"] = image
              return current
          }
          return image
      }
  }
  var chat_failed_scroller: CGImage {
      if let image = cached.with({ $0["chat_failed_scroller"] }) {
          return image
      } else {
          let image = _chat_failed_scroller()
          _ = cached.modify { current in 
              var current = current
              current["chat_failed_scroller"] = image
              return current
          }
          return image
      }
  }
  var chat_failed_scroller_active: CGImage {
      if let image = cached.with({ $0["chat_failed_scroller_active"] }) {
          return image
      } else {
          let image = _chat_failed_scroller_active()
          _ = cached.modify { current in 
              var current = current
              current["chat_failed_scroller_active"] = image
              return current
          }
          return image
      }
  }
  var poll_quiz_unselected: CGImage {
      if let image = cached.with({ $0["poll_quiz_unselected"] }) {
          return image
      } else {
          let image = _poll_quiz_unselected()
          _ = cached.modify { current in 
              var current = current
              current["poll_quiz_unselected"] = image
              return current
          }
          return image
      }
  }
  var poll_selected: CGImage {
      if let image = cached.with({ $0["poll_selected"] }) {
          return image
      } else {
          let image = _poll_selected()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_correct: CGImage {
      if let image = cached.with({ $0["poll_selected_correct"] }) {
          return image
      } else {
          let image = _poll_selected_correct()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_correct"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_incorrect: CGImage {
      if let image = cached.with({ $0["poll_selected_incorrect"] }) {
          return image
      } else {
          let image = _poll_selected_incorrect()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_incorrect"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_incoming: CGImage {
      if let image = cached.with({ $0["poll_selected_incoming"] }) {
          return image
      } else {
          let image = _poll_selected_incoming()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_incoming"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_correct_incoming: CGImage {
      if let image = cached.with({ $0["poll_selected_correct_incoming"] }) {
          return image
      } else {
          let image = _poll_selected_correct_incoming()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_correct_incoming"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_incorrect_incoming: CGImage {
      if let image = cached.with({ $0["poll_selected_incorrect_incoming"] }) {
          return image
      } else {
          let image = _poll_selected_incorrect_incoming()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_incorrect_incoming"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_outgoing: CGImage {
      if let image = cached.with({ $0["poll_selected_outgoing"] }) {
          return image
      } else {
          let image = _poll_selected_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_outgoing"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_correct_outgoing: CGImage {
      if let image = cached.with({ $0["poll_selected_correct_outgoing"] }) {
          return image
      } else {
          let image = _poll_selected_correct_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_correct_outgoing"] = image
              return current
          }
          return image
      }
  }
  var poll_selected_incorrect_outgoing: CGImage {
      if let image = cached.with({ $0["poll_selected_incorrect_outgoing"] }) {
          return image
      } else {
          let image = _poll_selected_incorrect_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["poll_selected_incorrect_outgoing"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_edit: CGImage {
      if let image = cached.with({ $0["chat_filter_edit"] }) {
          return image
      } else {
          let image = _chat_filter_edit()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_edit"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_add: CGImage {
      if let image = cached.with({ $0["chat_filter_add"] }) {
          return image
      } else {
          let image = _chat_filter_add()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_add"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_bots: CGImage {
      if let image = cached.with({ $0["chat_filter_bots"] }) {
          return image
      } else {
          let image = _chat_filter_bots()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_bots"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_channels: CGImage {
      if let image = cached.with({ $0["chat_filter_channels"] }) {
          return image
      } else {
          let image = _chat_filter_channels()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_channels"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_custom: CGImage {
      if let image = cached.with({ $0["chat_filter_custom"] }) {
          return image
      } else {
          let image = _chat_filter_custom()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_custom"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_groups: CGImage {
      if let image = cached.with({ $0["chat_filter_groups"] }) {
          return image
      } else {
          let image = _chat_filter_groups()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_groups"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_muted: CGImage {
      if let image = cached.with({ $0["chat_filter_muted"] }) {
          return image
      } else {
          let image = _chat_filter_muted()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_muted"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_private_chats: CGImage {
      if let image = cached.with({ $0["chat_filter_private_chats"] }) {
          return image
      } else {
          let image = _chat_filter_private_chats()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_private_chats"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_read: CGImage {
      if let image = cached.with({ $0["chat_filter_read"] }) {
          return image
      } else {
          let image = _chat_filter_read()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_read"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_secret_chats: CGImage {
      if let image = cached.with({ $0["chat_filter_secret_chats"] }) {
          return image
      } else {
          let image = _chat_filter_secret_chats()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_secret_chats"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_unmuted: CGImage {
      if let image = cached.with({ $0["chat_filter_unmuted"] }) {
          return image
      } else {
          let image = _chat_filter_unmuted()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_unmuted"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_unread: CGImage {
      if let image = cached.with({ $0["chat_filter_unread"] }) {
          return image
      } else {
          let image = _chat_filter_unread()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_unread"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_large_groups: CGImage {
      if let image = cached.with({ $0["chat_filter_large_groups"] }) {
          return image
      } else {
          let image = _chat_filter_large_groups()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_large_groups"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_non_contacts: CGImage {
      if let image = cached.with({ $0["chat_filter_non_contacts"] }) {
          return image
      } else {
          let image = _chat_filter_non_contacts()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_non_contacts"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_archive: CGImage {
      if let image = cached.with({ $0["chat_filter_archive"] }) {
          return image
      } else {
          let image = _chat_filter_archive()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_archive"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_bots_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_bots_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_bots_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_bots_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_channels_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_channels_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_channels_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_channels_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_custom_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_custom_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_custom_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_custom_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_groups_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_groups_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_groups_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_groups_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_muted_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_muted_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_muted_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_muted_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_private_chats_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_private_chats_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_private_chats_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_private_chats_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_read_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_read_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_read_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_read_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_secret_chats_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_secret_chats_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_secret_chats_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_secret_chats_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_unmuted_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_unmuted_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_unmuted_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_unmuted_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_unread_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_unread_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_unread_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_unread_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_large_groups_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_large_groups_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_large_groups_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_large_groups_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_non_contacts_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_non_contacts_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_non_contacts_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_non_contacts_avatar"] = image
              return current
          }
          return image
      }
  }
  var chat_filter_archive_avatar: CGImage {
      if let image = cached.with({ $0["chat_filter_archive_avatar"] }) {
          return image
      } else {
          let image = _chat_filter_archive_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_archive_avatar"] = image
              return current
          }
          return image
      }
  }
  var group_invite_via_link: CGImage {
      if let image = cached.with({ $0["group_invite_via_link"] }) {
          return image
      } else {
          let image = _group_invite_via_link()
          _ = cached.modify { current in 
              var current = current
              current["group_invite_via_link"] = image
              return current
          }
          return image
      }
  }
  var tab_contacts: CGImage {
      if let image = cached.with({ $0["tab_contacts"] }) {
          return image
      } else {
          let image = _tab_contacts()
          _ = cached.modify { current in 
              var current = current
              current["tab_contacts"] = image
              return current
          }
          return image
      }
  }
  var tab_contacts_active: CGImage {
      if let image = cached.with({ $0["tab_contacts_active"] }) {
          return image
      } else {
          let image = _tab_contacts_active()
          _ = cached.modify { current in 
              var current = current
              current["tab_contacts_active"] = image
              return current
          }
          return image
      }
  }
  var tab_calls: CGImage {
      if let image = cached.with({ $0["tab_calls"] }) {
          return image
      } else {
          let image = _tab_calls()
          _ = cached.modify { current in 
              var current = current
              current["tab_calls"] = image
              return current
          }
          return image
      }
  }
  var tab_calls_active: CGImage {
      if let image = cached.with({ $0["tab_calls_active"] }) {
          return image
      } else {
          let image = _tab_calls_active()
          _ = cached.modify { current in 
              var current = current
              current["tab_calls_active"] = image
              return current
          }
          return image
      }
  }
  var tab_chats: CGImage {
      if let image = cached.with({ $0["tab_chats"] }) {
          return image
      } else {
          let image = _tab_chats()
          _ = cached.modify { current in 
              var current = current
              current["tab_chats"] = image
              return current
          }
          return image
      }
  }
  var tab_chats_active: CGImage {
      if let image = cached.with({ $0["tab_chats_active"] }) {
          return image
      } else {
          let image = _tab_chats_active()
          _ = cached.modify { current in 
              var current = current
              current["tab_chats_active"] = image
              return current
          }
          return image
      }
  }
  var tab_chats_active_filters: CGImage {
      if let image = cached.with({ $0["tab_chats_active_filters"] }) {
          return image
      } else {
          let image = _tab_chats_active_filters()
          _ = cached.modify { current in 
              var current = current
              current["tab_chats_active_filters"] = image
              return current
          }
          return image
      }
  }
  var tab_settings: CGImage {
      if let image = cached.with({ $0["tab_settings"] }) {
          return image
      } else {
          let image = _tab_settings()
          _ = cached.modify { current in 
              var current = current
              current["tab_settings"] = image
              return current
          }
          return image
      }
  }
  var tab_settings_active: CGImage {
      if let image = cached.with({ $0["tab_settings_active"] }) {
          return image
      } else {
          let image = _tab_settings_active()
          _ = cached.modify { current in 
              var current = current
              current["tab_settings_active"] = image
              return current
          }
          return image
      }
  }
  var profile_add_member: CGImage {
      if let image = cached.with({ $0["profile_add_member"] }) {
          return image
      } else {
          let image = _profile_add_member()
          _ = cached.modify { current in 
              var current = current
              current["profile_add_member"] = image
              return current
          }
          return image
      }
  }
  var profile_call: CGImage {
      if let image = cached.with({ $0["profile_call"] }) {
          return image
      } else {
          let image = _profile_call()
          _ = cached.modify { current in 
              var current = current
              current["profile_call"] = image
              return current
          }
          return image
      }
  }
  var profile_leave: CGImage {
      if let image = cached.with({ $0["profile_leave"] }) {
          return image
      } else {
          let image = _profile_leave()
          _ = cached.modify { current in 
              var current = current
              current["profile_leave"] = image
              return current
          }
          return image
      }
  }
  var profile_message: CGImage {
      if let image = cached.with({ $0["profile_message"] }) {
          return image
      } else {
          let image = _profile_message()
          _ = cached.modify { current in 
              var current = current
              current["profile_message"] = image
              return current
          }
          return image
      }
  }
  var profile_more: CGImage {
      if let image = cached.with({ $0["profile_more"] }) {
          return image
      } else {
          let image = _profile_more()
          _ = cached.modify { current in 
              var current = current
              current["profile_more"] = image
              return current
          }
          return image
      }
  }
  var profile_mute: CGImage {
      if let image = cached.with({ $0["profile_mute"] }) {
          return image
      } else {
          let image = _profile_mute()
          _ = cached.modify { current in 
              var current = current
              current["profile_mute"] = image
              return current
          }
          return image
      }
  }
  var profile_unmute: CGImage {
      if let image = cached.with({ $0["profile_unmute"] }) {
          return image
      } else {
          let image = _profile_unmute()
          _ = cached.modify { current in 
              var current = current
              current["profile_unmute"] = image
              return current
          }
          return image
      }
  }
  var profile_search: CGImage {
      if let image = cached.with({ $0["profile_search"] }) {
          return image
      } else {
          let image = _profile_search()
          _ = cached.modify { current in 
              var current = current
              current["profile_search"] = image
              return current
          }
          return image
      }
  }
  var profile_secret_chat: CGImage {
      if let image = cached.with({ $0["profile_secret_chat"] }) {
          return image
      } else {
          let image = _profile_secret_chat()
          _ = cached.modify { current in 
              var current = current
              current["profile_secret_chat"] = image
              return current
          }
          return image
      }
  }
  var profile_edit_photo: CGImage {
      if let image = cached.with({ $0["profile_edit_photo"] }) {
          return image
      } else {
          let image = _profile_edit_photo()
          _ = cached.modify { current in 
              var current = current
              current["profile_edit_photo"] = image
              return current
          }
          return image
      }
  }

  private let _dialogMuteImage: ()->CGImage
  private let _dialogMuteImageSelected: ()->CGImage
  private let _outgoingMessageImage: ()->CGImage
  private let _readMessageImage: ()->CGImage
  private let _outgoingMessageImageSelected: ()->CGImage
  private let _readMessageImageSelected: ()->CGImage
  private let _sendingImage: ()->CGImage
  private let _sendingImageSelected: ()->CGImage
  private let _secretImage: ()->CGImage
  private let _secretImageSelected: ()->CGImage
  private let _pinnedImage: ()->CGImage
  private let _pinnedImageSelected: ()->CGImage
  private let _verifiedImage: ()->CGImage
  private let _verifiedImageSelected: ()->CGImage
  private let _errorImage: ()->CGImage
  private let _errorImageSelected: ()->CGImage
  private let _chatSearch: ()->CGImage
  private let _chatSearchActive: ()->CGImage
  private let _chatCall: ()->CGImage
  private let _chatActions: ()->CGImage
  private let _chatFailedCall_incoming: ()->CGImage
  private let _chatFailedCall_outgoing: ()->CGImage
  private let _chatCall_incoming: ()->CGImage
  private let _chatCall_outgoing: ()->CGImage
  private let _chatFailedCallBubble_incoming: ()->CGImage
  private let _chatFailedCallBubble_outgoing: ()->CGImage
  private let _chatCallBubble_incoming: ()->CGImage
  private let _chatCallBubble_outgoing: ()->CGImage
  private let _chatFallbackCall: ()->CGImage
  private let _chatFallbackCallBubble_incoming: ()->CGImage
  private let _chatFallbackCallBubble_outgoing: ()->CGImage
  private let _chatToggleSelected: ()->CGImage
  private let _chatToggleUnselected: ()->CGImage
  private let _chatShare: ()->CGImage
  private let _chatMusicPlay: ()->CGImage
  private let _chatMusicPlayBubble_incoming: ()->CGImage
  private let _chatMusicPlayBubble_outgoing: ()->CGImage
  private let _chatMusicPause: ()->CGImage
  private let _chatMusicPauseBubble_incoming: ()->CGImage
  private let _chatMusicPauseBubble_outgoing: ()->CGImage
  private let _chatGradientBubble_incoming: ()->CGImage
  private let _chatGradientBubble_outgoing: ()->CGImage
  private let _chatBubble_none_incoming_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubble_none_outgoing_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubbleBorder_none_incoming_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubbleBorder_none_outgoing_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubble_both_incoming_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubble_both_outgoing_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubbleBorder_both_incoming_withInset: ()->(CGImage, NSEdgeInsets)
  private let _chatBubbleBorder_both_outgoing_withInset: ()->(CGImage, NSEdgeInsets)
  private let _composeNewChat: ()->CGImage
  private let _composeNewChatActive: ()->CGImage
  private let _composeNewGroup: ()->CGImage
  private let _composeNewSecretChat: ()->CGImage
  private let _composeNewChannel: ()->CGImage
  private let _contactsNewContact: ()->CGImage
  private let _chatReadMarkInBubble1_incoming: ()->CGImage
  private let _chatReadMarkInBubble2_incoming: ()->CGImage
  private let _chatReadMarkInBubble1_outgoing: ()->CGImage
  private let _chatReadMarkInBubble2_outgoing: ()->CGImage
  private let _chatReadMarkOutBubble1: ()->CGImage
  private let _chatReadMarkOutBubble2: ()->CGImage
  private let _chatReadMarkOverlayBubble1: ()->CGImage
  private let _chatReadMarkOverlayBubble2: ()->CGImage
  private let _sentFailed: ()->CGImage
  private let _chatChannelViewsInBubble_incoming: ()->CGImage
  private let _chatChannelViewsInBubble_outgoing: ()->CGImage
  private let _chatChannelViewsOutBubble: ()->CGImage
  private let _chatChannelViewsOverlayBubble: ()->CGImage
  private let _chatNavigationBack: ()->CGImage
  private let _peerInfoAddMember: ()->CGImage
  private let _chatSearchUp: ()->CGImage
  private let _chatSearchUpDisabled: ()->CGImage
  private let _chatSearchDown: ()->CGImage
  private let _chatSearchDownDisabled: ()->CGImage
  private let _chatSearchCalendar: ()->CGImage
  private let _dismissAccessory: ()->CGImage
  private let _chatScrollUp: ()->CGImage
  private let _chatScrollUpActive: ()->CGImage
  private let _audioPlayerPlay: ()->CGImage
  private let _audioPlayerPause: ()->CGImage
  private let _audioPlayerNext: ()->CGImage
  private let _audioPlayerPrev: ()->CGImage
  private let _auduiPlayerDismiss: ()->CGImage
  private let _audioPlayerRepeat: ()->CGImage
  private let _audioPlayerRepeatActive: ()->CGImage
  private let _audioPlayerLockedPlay: ()->CGImage
  private let _audioPlayerLockedNext: ()->CGImage
  private let _audioPlayerLockedPrev: ()->CGImage
  private let _chatSendMessage: ()->CGImage
  private let _chatSaveEditedMessage: ()->CGImage
  private let _chatRecordVoice: ()->CGImage
  private let _chatEntertainment: ()->CGImage
  private let _chatInlineDismiss: ()->CGImage
  private let _chatActiveReplyMarkup: ()->CGImage
  private let _chatDisabledReplyMarkup: ()->CGImage
  private let _chatSecretTimer: ()->CGImage
  private let _chatForwardMessagesActive: ()->CGImage
  private let _chatForwardMessagesInactive: ()->CGImage
  private let _chatDeleteMessagesActive: ()->CGImage
  private let _chatDeleteMessagesInactive: ()->CGImage
  private let _generalNext: ()->CGImage
  private let _generalNextActive: ()->CGImage
  private let _generalSelect: ()->CGImage
  private let _chatVoiceRecording: ()->CGImage
  private let _chatVideoRecording: ()->CGImage
  private let _chatRecord: ()->CGImage
  private let _deleteItem: ()->CGImage
  private let _deleteItemDisabled: ()->CGImage
  private let _chatAttach: ()->CGImage
  private let _chatAttachFile: ()->CGImage
  private let _chatAttachPhoto: ()->CGImage
  private let _chatAttachCamera: ()->CGImage
  private let _chatAttachLocation: ()->CGImage
  private let _chatAttachPoll: ()->CGImage
  private let _mediaEmptyShared: ()->CGImage
  private let _mediaEmptyFiles: ()->CGImage
  private let _mediaEmptyMusic: ()->CGImage
  private let _mediaEmptyLinks: ()->CGImage
  private let _stickersAddFeatured: ()->CGImage
  private let _stickersAddedFeatured: ()->CGImage
  private let _stickersRemove: ()->CGImage
  private let _peerMediaDownloadFileStart: ()->CGImage
  private let _peerMediaDownloadFilePause: ()->CGImage
  private let _stickersShare: ()->CGImage
  private let _emojiRecentTab: ()->CGImage
  private let _emojiSmileTab: ()->CGImage
  private let _emojiNatureTab: ()->CGImage
  private let _emojiFoodTab: ()->CGImage
  private let _emojiSportTab: ()->CGImage
  private let _emojiCarTab: ()->CGImage
  private let _emojiObjectsTab: ()->CGImage
  private let _emojiSymbolsTab: ()->CGImage
  private let _emojiFlagsTab: ()->CGImage
  private let _emojiRecentTabActive: ()->CGImage
  private let _emojiSmileTabActive: ()->CGImage
  private let _emojiNatureTabActive: ()->CGImage
  private let _emojiFoodTabActive: ()->CGImage
  private let _emojiSportTabActive: ()->CGImage
  private let _emojiCarTabActive: ()->CGImage
  private let _emojiObjectsTabActive: ()->CGImage
  private let _emojiSymbolsTabActive: ()->CGImage
  private let _emojiFlagsTabActive: ()->CGImage
  private let _stickerBackground: ()->CGImage
  private let _stickerBackgroundActive: ()->CGImage
  private let _stickersTabRecent: ()->CGImage
  private let _stickersTabGIF: ()->CGImage
  private let _chatSendingInFrame_incoming: ()->CGImage
  private let _chatSendingInHour_incoming: ()->CGImage
  private let _chatSendingInMin_incoming: ()->CGImage
  private let _chatSendingInFrame_outgoing: ()->CGImage
  private let _chatSendingInHour_outgoing: ()->CGImage
  private let _chatSendingInMin_outgoing: ()->CGImage
  private let _chatSendingOutFrame: ()->CGImage
  private let _chatSendingOutHour: ()->CGImage
  private let _chatSendingOutMin: ()->CGImage
  private let _chatSendingOverlayFrame: ()->CGImage
  private let _chatSendingOverlayHour: ()->CGImage
  private let _chatSendingOverlayMin: ()->CGImage
  private let _chatActionUrl: ()->CGImage
  private let _callInlineDecline: ()->CGImage
  private let _callInlineMuted: ()->CGImage
  private let _callInlineUnmuted: ()->CGImage
  private let _eventLogTriangle: ()->CGImage
  private let _channelIntro: ()->CGImage
  private let _chatFileThumb: ()->CGImage
  private let _chatFileThumbBubble_incoming: ()->CGImage
  private let _chatFileThumbBubble_outgoing: ()->CGImage
  private let _chatSecretThumb: ()->CGImage
  private let _chatMapPin: ()->CGImage
  private let _chatSecretTitle: ()->CGImage
  private let _emptySearch: ()->CGImage
  private let _calendarBack: ()->CGImage
  private let _calendarNext: ()->CGImage
  private let _calendarBackDisabled: ()->CGImage
  private let _calendarNextDisabled: ()->CGImage
  private let _newChatCamera: ()->CGImage
  private let _peerInfoVerify: ()->CGImage
  private let _peerInfoVerifyProfile: ()->CGImage
  private let _peerInfoCall: ()->CGImage
  private let _callOutgoing: ()->CGImage
  private let _recentDismiss: ()->CGImage
  private let _recentDismissActive: ()->CGImage
  private let _webgameShare: ()->CGImage
  private let _chatSearchCancel: ()->CGImage
  private let _chatSearchFrom: ()->CGImage
  private let _callWindowDecline: ()->CGImage
  private let _callWindowAccept: ()->CGImage
  private let _callWindowMute: ()->CGImage
  private let _callWindowUnmute: ()->CGImage
  private let _callWindowClose: ()->CGImage
  private let _callWindowDeviceSettings: ()->CGImage
  private let _callSettings: ()->CGImage
  private let _callWindowCancel: ()->CGImage
  private let _chatActionEdit: ()->CGImage
  private let _chatActionInfo: ()->CGImage
  private let _chatActionMute: ()->CGImage
  private let _chatActionUnmute: ()->CGImage
  private let _chatActionClearHistory: ()->CGImage
  private let _chatActionDeleteChat: ()->CGImage
  private let _dismissPinned: ()->CGImage
  private let _chatActionsActive: ()->CGImage
  private let _chatEntertainmentSticker: ()->CGImage
  private let _chatEmpty: ()->CGImage
  private let _stickerPackClose: ()->CGImage
  private let _stickerPackDelete: ()->CGImage
  private let _modalShare: ()->CGImage
  private let _modalClose: ()->CGImage
  private let _ivChannelJoined: ()->CGImage
  private let _chatListMention: ()->CGImage
  private let _chatListMentionActive: ()->CGImage
  private let _chatListMentionArchived: ()->CGImage
  private let _chatListMentionArchivedActive: ()->CGImage
  private let _chatMention: ()->CGImage
  private let _chatMentionActive: ()->CGImage
  private let _sliderControl: ()->CGImage
  private let _sliderControlActive: ()->CGImage
  private let _stickersTabFave: ()->CGImage
  private let _chatInstantView: ()->CGImage
  private let _chatInstantViewBubble_incoming: ()->CGImage
  private let _chatInstantViewBubble_outgoing: ()->CGImage
  private let _instantViewShare: ()->CGImage
  private let _instantViewActions: ()->CGImage
  private let _instantViewActionsActive: ()->CGImage
  private let _instantViewSafari: ()->CGImage
  private let _instantViewBack: ()->CGImage
  private let _instantViewCheck: ()->CGImage
  private let _groupStickerNotFound: ()->CGImage
  private let _settingsAskQuestion: ()->CGImage
  private let _settingsFaq: ()->CGImage
  private let _settingsGeneral: ()->CGImage
  private let _settingsLanguage: ()->CGImage
  private let _settingsNotifications: ()->CGImage
  private let _settingsSecurity: ()->CGImage
  private let _settingsStickers: ()->CGImage
  private let _settingsStorage: ()->CGImage
  private let _settingsProxy: ()->CGImage
  private let _settingsAppearance: ()->CGImage
  private let _settingsPassport: ()->CGImage
  private let _settingsWallet: ()->CGImage
  private let _settingsUpdate: ()->CGImage
  private let _settingsFilters: ()->CGImage
  private let _settingsAskQuestionActive: ()->CGImage
  private let _settingsFaqActive: ()->CGImage
  private let _settingsGeneralActive: ()->CGImage
  private let _settingsLanguageActive: ()->CGImage
  private let _settingsNotificationsActive: ()->CGImage
  private let _settingsSecurityActive: ()->CGImage
  private let _settingsStickersActive: ()->CGImage
  private let _settingsStorageActive: ()->CGImage
  private let _settingsProxyActive: ()->CGImage
  private let _settingsAppearanceActive: ()->CGImage
  private let _settingsPassportActive: ()->CGImage
  private let _settingsWalletActive: ()->CGImage
  private let _settingsUpdateActive: ()->CGImage
  private let _settingsFiltersActive: ()->CGImage
  private let _settingsProfile: ()->CGImage
  private let _generalCheck: ()->CGImage
  private let _settingsAbout: ()->CGImage
  private let _settingsLogout: ()->CGImage
  private let _fastSettingsLock: ()->CGImage
  private let _fastSettingsDark: ()->CGImage
  private let _fastSettingsSunny: ()->CGImage
  private let _fastSettingsMute: ()->CGImage
  private let _fastSettingsUnmute: ()->CGImage
  private let _chatRecordVideo: ()->CGImage
  private let _inputChannelMute: ()->CGImage
  private let _inputChannelUnmute: ()->CGImage
  private let _changePhoneNumberIntro: ()->CGImage
  private let _peerSavedMessages: ()->CGImage
  private let _previewSenderCollage: ()->CGImage
  private let _previewSenderPhoto: ()->CGImage
  private let _previewSenderFile: ()->CGImage
  private let _previewSenderCrop: ()->CGImage
  private let _previewSenderDelete: ()->CGImage
  private let _previewSenderDeleteFile: ()->CGImage
  private let _previewSenderArchive: ()->CGImage
  private let _chatGoMessage: ()->CGImage
  private let _chatGroupToggleSelected: ()->CGImage
  private let _chatGroupToggleUnselected: ()->CGImage
  private let _successModalProgress: ()->CGImage
  private let _accentColorSelect: ()->CGImage
  private let _chatShareWallpaper: ()->CGImage
  private let _chatGotoMessageWallpaper: ()->CGImage
  private let _transparentBackground: ()->CGImage
  private let _lottieTransparentBackground: ()->CGImage
  private let _passcodeTouchId: ()->CGImage
  private let _passcodeLogin: ()->CGImage
  private let _confirmDeleteMessagesAccessory: ()->CGImage
  private let _alertCheckBoxSelected: ()->CGImage
  private let _alertCheckBoxUnselected: ()->CGImage
  private let _confirmPinAccessory: ()->CGImage
  private let _confirmDeleteChatAccessory: ()->CGImage
  private let _stickersEmptySearch: ()->CGImage
  private let _twoStepVerificationCreateIntro: ()->CGImage
  private let _secureIdAuth: ()->CGImage
  private let _ivAudioPlay: ()->CGImage
  private let _ivAudioPause: ()->CGImage
  private let _proxyEnable: ()->CGImage
  private let _proxyEnabled: ()->CGImage
  private let _proxyState: ()->CGImage
  private let _proxyDeleteListItem: ()->CGImage
  private let _proxyInfoListItem: ()->CGImage
  private let _proxyConnectedListItem: ()->CGImage
  private let _proxyAddProxy: ()->CGImage
  private let _proxyNextWaitingListItem: ()->CGImage
  private let _passportForgotPassword: ()->CGImage
  private let _confirmAppAccessoryIcon: ()->CGImage
  private let _passportPassport: ()->CGImage
  private let _passportIdCardReverse: ()->CGImage
  private let _passportIdCard: ()->CGImage
  private let _passportSelfie: ()->CGImage
  private let _passportDriverLicense: ()->CGImage
  private let _chatOverlayVoiceRecording: ()->CGImage
  private let _chatOverlayVideoRecording: ()->CGImage
  private let _chatOverlaySendRecording: ()->CGImage
  private let _chatOverlayLockArrowRecording: ()->CGImage
  private let _chatOverlayLockerBodyRecording: ()->CGImage
  private let _chatOverlayLockerHeadRecording: ()->CGImage
  private let _locationPin: ()->CGImage
  private let _locationMapPin: ()->CGImage
  private let _locationMapLocate: ()->CGImage
  private let _locationMapLocated: ()->CGImage
  private let _passportSettings: ()->CGImage
  private let _passportInfo: ()->CGImage
  private let _editMessageMedia: ()->CGImage
  private let _playerMusicPlaceholder: ()->CGImage
  private let _chatMusicPlaceholder: ()->CGImage
  private let _chatMusicPlaceholderCap: ()->CGImage
  private let _searchArticle: ()->CGImage
  private let _searchSaved: ()->CGImage
  private let _archivedChats: ()->CGImage
  private let _hintPeerActive: ()->CGImage
  private let _hintPeerActiveSelected: ()->CGImage
  private let _chatSwiping_delete: ()->CGImage
  private let _chatSwiping_mute: ()->CGImage
  private let _chatSwiping_unmute: ()->CGImage
  private let _chatSwiping_read: ()->CGImage
  private let _chatSwiping_unread: ()->CGImage
  private let _chatSwiping_pin: ()->CGImage
  private let _chatSwiping_unpin: ()->CGImage
  private let _chatSwiping_archive: ()->CGImage
  private let _chatSwiping_unarchive: ()->CGImage
  private let _galleryPrev: ()->CGImage
  private let _galleryNext: ()->CGImage
  private let _galleryMore: ()->CGImage
  private let _galleryShare: ()->CGImage
  private let _galleryFastSave: ()->CGImage
  private let _playingVoice1x: ()->CGImage
  private let _playingVoice2x: ()->CGImage
  private let _galleryRotate: ()->CGImage
  private let _galleryZoomIn: ()->CGImage
  private let _galleryZoomOut: ()->CGImage
  private let _editMessageCurrentPhoto: ()->CGImage
  private let _chatSwipeReply: ()->CGImage
  private let _chatSwipeReplyWallpaper: ()->CGImage
  private let _videoPlayerPlay: ()->CGImage
  private let _videoPlayerPause: ()->CGImage
  private let _videoPlayerEnterFullScreen: ()->CGImage
  private let _videoPlayerExitFullScreen: ()->CGImage
  private let _videoPlayerPIPIn: ()->CGImage
  private let _videoPlayerPIPOut: ()->CGImage
  private let _videoPlayerRewind15Forward: ()->CGImage
  private let _videoPlayerRewind15Backward: ()->CGImage
  private let _videoPlayerVolume: ()->CGImage
  private let _videoPlayerVolumeOff: ()->CGImage
  private let _videoPlayerClose: ()->CGImage
  private let _videoPlayerSliderInteractor: ()->CGImage
  private let _streamingVideoDownload: ()->CGImage
  private let _videoCompactFetching: ()->CGImage
  private let _compactStreamingFetchingCancel: ()->CGImage
  private let _customLocalizationDelete: ()->CGImage
  private let _pollAddOption: ()->CGImage
  private let _pollDeleteOption: ()->CGImage
  private let _resort: ()->CGImage
  private let _chatPollVoteUnselected: ()->CGImage
  private let _chatPollVoteUnselectedBubble_incoming: ()->CGImage
  private let _chatPollVoteUnselectedBubble_outgoing: ()->CGImage
  private let _peerInfoAdmins: ()->CGImage
  private let _peerInfoPermissions: ()->CGImage
  private let _peerInfoBanned: ()->CGImage
  private let _peerInfoMembers: ()->CGImage
  private let _chatUndoAction: ()->CGImage
  private let _appUpdate: ()->CGImage
  private let _inlineVideoSoundOff: ()->CGImage
  private let _inlineVideoSoundOn: ()->CGImage
  private let _logoutOptionAddAccount: ()->CGImage
  private let _logoutOptionSetPasscode: ()->CGImage
  private let _logoutOptionClearCache: ()->CGImage
  private let _logoutOptionChangePhoneNumber: ()->CGImage
  private let _logoutOptionContactSupport: ()->CGImage
  private let _disableEmojiPrediction: ()->CGImage
  private let _scam: ()->CGImage
  private let _scamActive: ()->CGImage
  private let _chatScam: ()->CGImage
  private let _chatUnarchive: ()->CGImage
  private let _chatArchive: ()->CGImage
  private let _privacySettings_blocked: ()->CGImage
  private let _privacySettings_activeSessions: ()->CGImage
  private let _privacySettings_passcode: ()->CGImage
  private let _privacySettings_twoStep: ()->CGImage
  private let _deletedAccount: ()->CGImage
  private let _stickerPackSelection: ()->CGImage
  private let _stickerPackSelectionActive: ()->CGImage
  private let _entertainment_Emoji: ()->CGImage
  private let _entertainment_Stickers: ()->CGImage
  private let _entertainment_Gifs: ()->CGImage
  private let _entertainment_Search: ()->CGImage
  private let _entertainment_Settings: ()->CGImage
  private let _entertainment_SearchCancel: ()->CGImage
  private let _scheduledAvatar: ()->CGImage
  private let _scheduledInputAction: ()->CGImage
  private let _verifyDialog: ()->CGImage
  private let _verifyDialogActive: ()->CGImage
  private let _chatInputScheduled: ()->CGImage
  private let _appearanceAddPlatformTheme: ()->CGImage
  private let _wallet_close: ()->CGImage
  private let _wallet_qr: ()->CGImage
  private let _wallet_receive: ()->CGImage
  private let _wallet_send: ()->CGImage
  private let _wallet_settings: ()->CGImage
  private let _wallet_update: ()->CGImage
  private let _wallet_passcode_visible: ()->CGImage
  private let _wallet_passcode_hidden: ()->CGImage
  private let _wallpaper_color_close: ()->CGImage
  private let _wallpaper_color_add: ()->CGImage
  private let _wallpaper_color_swap: ()->CGImage
  private let _wallpaper_color_rotate: ()->CGImage
  private let _login_cap: ()->CGImage
  private let _login_qr_cap: ()->CGImage
  private let _login_qr_empty_cap: ()->CGImage
  private let _chat_failed_scroller: ()->CGImage
  private let _chat_failed_scroller_active: ()->CGImage
  private let _poll_quiz_unselected: ()->CGImage
  private let _poll_selected: ()->CGImage
  private let _poll_selected_correct: ()->CGImage
  private let _poll_selected_incorrect: ()->CGImage
  private let _poll_selected_incoming: ()->CGImage
  private let _poll_selected_correct_incoming: ()->CGImage
  private let _poll_selected_incorrect_incoming: ()->CGImage
  private let _poll_selected_outgoing: ()->CGImage
  private let _poll_selected_correct_outgoing: ()->CGImage
  private let _poll_selected_incorrect_outgoing: ()->CGImage
  private let _chat_filter_edit: ()->CGImage
  private let _chat_filter_add: ()->CGImage
  private let _chat_filter_bots: ()->CGImage
  private let _chat_filter_channels: ()->CGImage
  private let _chat_filter_custom: ()->CGImage
  private let _chat_filter_groups: ()->CGImage
  private let _chat_filter_muted: ()->CGImage
  private let _chat_filter_private_chats: ()->CGImage
  private let _chat_filter_read: ()->CGImage
  private let _chat_filter_secret_chats: ()->CGImage
  private let _chat_filter_unmuted: ()->CGImage
  private let _chat_filter_unread: ()->CGImage
  private let _chat_filter_large_groups: ()->CGImage
  private let _chat_filter_non_contacts: ()->CGImage
  private let _chat_filter_archive: ()->CGImage
  private let _chat_filter_bots_avatar: ()->CGImage
  private let _chat_filter_channels_avatar: ()->CGImage
  private let _chat_filter_custom_avatar: ()->CGImage
  private let _chat_filter_groups_avatar: ()->CGImage
  private let _chat_filter_muted_avatar: ()->CGImage
  private let _chat_filter_private_chats_avatar: ()->CGImage
  private let _chat_filter_read_avatar: ()->CGImage
  private let _chat_filter_secret_chats_avatar: ()->CGImage
  private let _chat_filter_unmuted_avatar: ()->CGImage
  private let _chat_filter_unread_avatar: ()->CGImage
  private let _chat_filter_large_groups_avatar: ()->CGImage
  private let _chat_filter_non_contacts_avatar: ()->CGImage
  private let _chat_filter_archive_avatar: ()->CGImage
  private let _group_invite_via_link: ()->CGImage
  private let _tab_contacts: ()->CGImage
  private let _tab_contacts_active: ()->CGImage
  private let _tab_calls: ()->CGImage
  private let _tab_calls_active: ()->CGImage
  private let _tab_chats: ()->CGImage
  private let _tab_chats_active: ()->CGImage
  private let _tab_chats_active_filters: ()->CGImage
  private let _tab_settings: ()->CGImage
  private let _tab_settings_active: ()->CGImage
  private let _profile_add_member: ()->CGImage
  private let _profile_call: ()->CGImage
  private let _profile_leave: ()->CGImage
  private let _profile_message: ()->CGImage
  private let _profile_more: ()->CGImage
  private let _profile_mute: ()->CGImage
  private let _profile_unmute: ()->CGImage
  private let _profile_search: ()->CGImage
  private let _profile_secret_chat: ()->CGImage
  private let _profile_edit_photo: ()->CGImage

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
      chatSearchActive: @escaping()->CGImage,
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
      chatGradientBubble_incoming: @escaping()->CGImage,
      chatGradientBubble_outgoing: @escaping()->CGImage,
      chatBubble_none_incoming_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubble_none_outgoing_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubbleBorder_none_incoming_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubbleBorder_none_outgoing_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubble_both_incoming_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubble_both_outgoing_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubbleBorder_both_incoming_withInset: @escaping()->(CGImage, NSEdgeInsets),
      chatBubbleBorder_both_outgoing_withInset: @escaping()->(CGImage, NSEdgeInsets),
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
      chatSaveEditedMessage: @escaping()->CGImage,
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
      peerInfoVerifyProfile: @escaping()->CGImage,
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
      settingsWallet: @escaping()->CGImage,
      settingsUpdate: @escaping()->CGImage,
      settingsFilters: @escaping()->CGImage,
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
      settingsWalletActive: @escaping()->CGImage,
      settingsUpdateActive: @escaping()->CGImage,
      settingsFiltersActive: @escaping()->CGImage,
      settingsProfile: @escaping()->CGImage,
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
      previewSenderCollage: @escaping()->CGImage,
      previewSenderPhoto: @escaping()->CGImage,
      previewSenderFile: @escaping()->CGImage,
      previewSenderCrop: @escaping()->CGImage,
      previewSenderDelete: @escaping()->CGImage,
      previewSenderDeleteFile: @escaping()->CGImage,
      previewSenderArchive: @escaping()->CGImage,
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
      editMessageCurrentPhoto: @escaping()->CGImage,
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
      scheduledInputAction: @escaping()->CGImage,
      verifyDialog: @escaping()->CGImage,
      verifyDialogActive: @escaping()->CGImage,
      chatInputScheduled: @escaping()->CGImage,
      appearanceAddPlatformTheme: @escaping()->CGImage,
      wallet_close: @escaping()->CGImage,
      wallet_qr: @escaping()->CGImage,
      wallet_receive: @escaping()->CGImage,
      wallet_send: @escaping()->CGImage,
      wallet_settings: @escaping()->CGImage,
      wallet_update: @escaping()->CGImage,
      wallet_passcode_visible: @escaping()->CGImage,
      wallet_passcode_hidden: @escaping()->CGImage,
      wallpaper_color_close: @escaping()->CGImage,
      wallpaper_color_add: @escaping()->CGImage,
      wallpaper_color_swap: @escaping()->CGImage,
      wallpaper_color_rotate: @escaping()->CGImage,
      login_cap: @escaping()->CGImage,
      login_qr_cap: @escaping()->CGImage,
      login_qr_empty_cap: @escaping()->CGImage,
      chat_failed_scroller: @escaping()->CGImage,
      chat_failed_scroller_active: @escaping()->CGImage,
      poll_quiz_unselected: @escaping()->CGImage,
      poll_selected: @escaping()->CGImage,
      poll_selected_correct: @escaping()->CGImage,
      poll_selected_incorrect: @escaping()->CGImage,
      poll_selected_incoming: @escaping()->CGImage,
      poll_selected_correct_incoming: @escaping()->CGImage,
      poll_selected_incorrect_incoming: @escaping()->CGImage,
      poll_selected_outgoing: @escaping()->CGImage,
      poll_selected_correct_outgoing: @escaping()->CGImage,
      poll_selected_incorrect_outgoing: @escaping()->CGImage,
      chat_filter_edit: @escaping()->CGImage,
      chat_filter_add: @escaping()->CGImage,
      chat_filter_bots: @escaping()->CGImage,
      chat_filter_channels: @escaping()->CGImage,
      chat_filter_custom: @escaping()->CGImage,
      chat_filter_groups: @escaping()->CGImage,
      chat_filter_muted: @escaping()->CGImage,
      chat_filter_private_chats: @escaping()->CGImage,
      chat_filter_read: @escaping()->CGImage,
      chat_filter_secret_chats: @escaping()->CGImage,
      chat_filter_unmuted: @escaping()->CGImage,
      chat_filter_unread: @escaping()->CGImage,
      chat_filter_large_groups: @escaping()->CGImage,
      chat_filter_non_contacts: @escaping()->CGImage,
      chat_filter_archive: @escaping()->CGImage,
      chat_filter_bots_avatar: @escaping()->CGImage,
      chat_filter_channels_avatar: @escaping()->CGImage,
      chat_filter_custom_avatar: @escaping()->CGImage,
      chat_filter_groups_avatar: @escaping()->CGImage,
      chat_filter_muted_avatar: @escaping()->CGImage,
      chat_filter_private_chats_avatar: @escaping()->CGImage,
      chat_filter_read_avatar: @escaping()->CGImage,
      chat_filter_secret_chats_avatar: @escaping()->CGImage,
      chat_filter_unmuted_avatar: @escaping()->CGImage,
      chat_filter_unread_avatar: @escaping()->CGImage,
      chat_filter_large_groups_avatar: @escaping()->CGImage,
      chat_filter_non_contacts_avatar: @escaping()->CGImage,
      chat_filter_archive_avatar: @escaping()->CGImage,
      group_invite_via_link: @escaping()->CGImage,
      tab_contacts: @escaping()->CGImage,
      tab_contacts_active: @escaping()->CGImage,
      tab_calls: @escaping()->CGImage,
      tab_calls_active: @escaping()->CGImage,
      tab_chats: @escaping()->CGImage,
      tab_chats_active: @escaping()->CGImage,
      tab_chats_active_filters: @escaping()->CGImage,
      tab_settings: @escaping()->CGImage,
      tab_settings_active: @escaping()->CGImage,
      profile_add_member: @escaping()->CGImage,
      profile_call: @escaping()->CGImage,
      profile_leave: @escaping()->CGImage,
      profile_message: @escaping()->CGImage,
      profile_more: @escaping()->CGImage,
      profile_mute: @escaping()->CGImage,
      profile_unmute: @escaping()->CGImage,
      profile_search: @escaping()->CGImage,
      profile_secret_chat: @escaping()->CGImage,
      profile_edit_photo: @escaping()->CGImage
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
      self._chatSearchActive = chatSearchActive
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
      self._chatGradientBubble_incoming = chatGradientBubble_incoming
      self._chatGradientBubble_outgoing = chatGradientBubble_outgoing
      self._chatBubble_none_incoming_withInset = chatBubble_none_incoming_withInset
      self._chatBubble_none_outgoing_withInset = chatBubble_none_outgoing_withInset
      self._chatBubbleBorder_none_incoming_withInset = chatBubbleBorder_none_incoming_withInset
      self._chatBubbleBorder_none_outgoing_withInset = chatBubbleBorder_none_outgoing_withInset
      self._chatBubble_both_incoming_withInset = chatBubble_both_incoming_withInset
      self._chatBubble_both_outgoing_withInset = chatBubble_both_outgoing_withInset
      self._chatBubbleBorder_both_incoming_withInset = chatBubbleBorder_both_incoming_withInset
      self._chatBubbleBorder_both_outgoing_withInset = chatBubbleBorder_both_outgoing_withInset
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
      self._chatSaveEditedMessage = chatSaveEditedMessage
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
      self._peerInfoVerifyProfile = peerInfoVerifyProfile
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
      self._settingsWallet = settingsWallet
      self._settingsUpdate = settingsUpdate
      self._settingsFilters = settingsFilters
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
      self._settingsWalletActive = settingsWalletActive
      self._settingsUpdateActive = settingsUpdateActive
      self._settingsFiltersActive = settingsFiltersActive
      self._settingsProfile = settingsProfile
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
      self._previewSenderCollage = previewSenderCollage
      self._previewSenderPhoto = previewSenderPhoto
      self._previewSenderFile = previewSenderFile
      self._previewSenderCrop = previewSenderCrop
      self._previewSenderDelete = previewSenderDelete
      self._previewSenderDeleteFile = previewSenderDeleteFile
      self._previewSenderArchive = previewSenderArchive
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
      self._editMessageCurrentPhoto = editMessageCurrentPhoto
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
      self._verifyDialog = verifyDialog
      self._verifyDialogActive = verifyDialogActive
      self._chatInputScheduled = chatInputScheduled
      self._appearanceAddPlatformTheme = appearanceAddPlatformTheme
      self._wallet_close = wallet_close
      self._wallet_qr = wallet_qr
      self._wallet_receive = wallet_receive
      self._wallet_send = wallet_send
      self._wallet_settings = wallet_settings
      self._wallet_update = wallet_update
      self._wallet_passcode_visible = wallet_passcode_visible
      self._wallet_passcode_hidden = wallet_passcode_hidden
      self._wallpaper_color_close = wallpaper_color_close
      self._wallpaper_color_add = wallpaper_color_add
      self._wallpaper_color_swap = wallpaper_color_swap
      self._wallpaper_color_rotate = wallpaper_color_rotate
      self._login_cap = login_cap
      self._login_qr_cap = login_qr_cap
      self._login_qr_empty_cap = login_qr_empty_cap
      self._chat_failed_scroller = chat_failed_scroller
      self._chat_failed_scroller_active = chat_failed_scroller_active
      self._poll_quiz_unselected = poll_quiz_unselected
      self._poll_selected = poll_selected
      self._poll_selected_correct = poll_selected_correct
      self._poll_selected_incorrect = poll_selected_incorrect
      self._poll_selected_incoming = poll_selected_incoming
      self._poll_selected_correct_incoming = poll_selected_correct_incoming
      self._poll_selected_incorrect_incoming = poll_selected_incorrect_incoming
      self._poll_selected_outgoing = poll_selected_outgoing
      self._poll_selected_correct_outgoing = poll_selected_correct_outgoing
      self._poll_selected_incorrect_outgoing = poll_selected_incorrect_outgoing
      self._chat_filter_edit = chat_filter_edit
      self._chat_filter_add = chat_filter_add
      self._chat_filter_bots = chat_filter_bots
      self._chat_filter_channels = chat_filter_channels
      self._chat_filter_custom = chat_filter_custom
      self._chat_filter_groups = chat_filter_groups
      self._chat_filter_muted = chat_filter_muted
      self._chat_filter_private_chats = chat_filter_private_chats
      self._chat_filter_read = chat_filter_read
      self._chat_filter_secret_chats = chat_filter_secret_chats
      self._chat_filter_unmuted = chat_filter_unmuted
      self._chat_filter_unread = chat_filter_unread
      self._chat_filter_large_groups = chat_filter_large_groups
      self._chat_filter_non_contacts = chat_filter_non_contacts
      self._chat_filter_archive = chat_filter_archive
      self._chat_filter_bots_avatar = chat_filter_bots_avatar
      self._chat_filter_channels_avatar = chat_filter_channels_avatar
      self._chat_filter_custom_avatar = chat_filter_custom_avatar
      self._chat_filter_groups_avatar = chat_filter_groups_avatar
      self._chat_filter_muted_avatar = chat_filter_muted_avatar
      self._chat_filter_private_chats_avatar = chat_filter_private_chats_avatar
      self._chat_filter_read_avatar = chat_filter_read_avatar
      self._chat_filter_secret_chats_avatar = chat_filter_secret_chats_avatar
      self._chat_filter_unmuted_avatar = chat_filter_unmuted_avatar
      self._chat_filter_unread_avatar = chat_filter_unread_avatar
      self._chat_filter_large_groups_avatar = chat_filter_large_groups_avatar
      self._chat_filter_non_contacts_avatar = chat_filter_non_contacts_avatar
      self._chat_filter_archive_avatar = chat_filter_archive_avatar
      self._group_invite_via_link = group_invite_via_link
      self._tab_contacts = tab_contacts
      self._tab_contacts_active = tab_contacts_active
      self._tab_calls = tab_calls
      self._tab_calls_active = tab_calls_active
      self._tab_chats = tab_chats
      self._tab_chats_active = tab_chats_active
      self._tab_chats_active_filters = tab_chats_active_filters
      self._tab_settings = tab_settings
      self._tab_settings_active = tab_settings_active
      self._profile_add_member = profile_add_member
      self._profile_call = profile_call
      self._profile_leave = profile_leave
      self._profile_message = profile_message
      self._profile_more = profile_more
      self._profile_mute = profile_mute
      self._profile_unmute = profile_unmute
      self._profile_search = profile_search
      self._profile_secret_chat = profile_secret_chat
      self._profile_edit_photo = profile_edit_photo
  }
}