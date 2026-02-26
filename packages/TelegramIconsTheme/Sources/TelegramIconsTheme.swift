import SwiftSignalKit
import AppKit

public final class TelegramIconsTheme {
  private var cached:Atomic<[String: CGImage]> = Atomic(value: [:])
  private var cachedWithInset:Atomic<[String: (CGImage, NSEdgeInsets)]> = Atomic(value: [:])

  public var dialogMuteImage: CGImage {
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
  public var dialogMuteImageSelected: CGImage {
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
  public var outgoingMessageImage: CGImage {
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
  public var readMessageImage: CGImage {
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
  public var outgoingMessageImageSelected: CGImage {
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
  public var readMessageImageSelected: CGImage {
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
  public var sendingImage: CGImage {
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
  public var sendingImageSelected: CGImage {
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
  public var secretImage: CGImage {
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
  public var secretImageSelected: CGImage {
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
  public var pinnedImage: CGImage {
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
  public var pinnedImageSelected: CGImage {
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
  public var verifiedImage: CGImage {
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
  public var verifiedImageSelected: CGImage {
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
  public var errorImage: CGImage {
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
  public var errorImageSelected: CGImage {
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
  public var chatSearch: CGImage {
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
  public var chatSearchActive: CGImage {
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
  public var chatCall: CGImage {
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
  public var chatCallActive: CGImage {
      if let image = cached.with({ $0["chatCallActive"] }) {
          return image
      } else {
          let image = _chatCallActive()
          _ = cached.modify { current in 
              var current = current
              current["chatCallActive"] = image
              return current
          }
          return image
      }
  }
  public var chatActions: CGImage {
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
  public var chatFailedCall_incoming: CGImage {
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
  public var chatFailedCall_outgoing: CGImage {
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
  public var chatCall_incoming: CGImage {
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
  public var chatCall_outgoing: CGImage {
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
  public var chatFailedCallBubble_incoming: CGImage {
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
  public var chatFailedCallBubble_outgoing: CGImage {
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
  public var chatCallBubble_incoming: CGImage {
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
  public var chatCallBubble_outgoing: CGImage {
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
  public var chatFallbackCall: CGImage {
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
  public var chatFallbackCallBubble_incoming: CGImage {
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
  public var chatFallbackCallBubble_outgoing: CGImage {
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
  public var chatFallbackVideoCall: CGImage {
      if let image = cached.with({ $0["chatFallbackVideoCall"] }) {
          return image
      } else {
          let image = _chatFallbackVideoCall()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackVideoCall"] = image
              return current
          }
          return image
      }
  }
  public var chatFallbackVideoCallBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatFallbackVideoCallBubble_incoming"] }) {
          return image
      } else {
          let image = _chatFallbackVideoCallBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackVideoCallBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chatFallbackVideoCallBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatFallbackVideoCallBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatFallbackVideoCallBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatFallbackVideoCallBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chatToggleSelected: CGImage {
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
  public var chatToggleUnselected: CGImage {
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
  public var chatMusicPlay: CGImage {
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
  public var chatMusicPlayBubble_incoming: CGImage {
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
  public var chatMusicPlayBubble_outgoing: CGImage {
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
  public var chatMusicPause: CGImage {
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
  public var chatMusicPauseBubble_incoming: CGImage {
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
  public var chatMusicPauseBubble_outgoing: CGImage {
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
  public var chatGradientBubble_incoming: CGImage {
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
  public var chatGradientBubble_outgoing: CGImage {
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
  public var chatBubble_none_incoming_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubble_none_outgoing_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubbleBorder_none_incoming_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubbleBorder_none_outgoing_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubble_both_incoming_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubble_both_outgoing_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubbleBorder_both_incoming_withInset: (CGImage, NSEdgeInsets) {
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
  public var chatBubbleBorder_both_outgoing_withInset: (CGImage, NSEdgeInsets) {
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
  public var composeNewChat: CGImage {
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
  public var composeNewChatActive: CGImage {
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
  public var composeNewGroup: CGImage {
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
  public var composeNewSecretChat: CGImage {
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
  public var composeNewChannel: CGImage {
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
  public var contactsNewContact: CGImage {
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
  public var chatReadMarkInBubble1_incoming: CGImage {
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
  public var chatReadMarkInBubble2_incoming: CGImage {
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
  public var chatReadMarkInBubble1_outgoing: CGImage {
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
  public var chatReadMarkInBubble2_outgoing: CGImage {
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
  public var chatReadMarkOutBubble1: CGImage {
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
  public var chatReadMarkOutBubble2: CGImage {
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
  public var chatReadMarkOverlayBubble1: CGImage {
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
  public var chatReadMarkOverlayBubble2: CGImage {
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
  public var sentFailed: CGImage {
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
  public var chatChannelViewsInBubble_incoming: CGImage {
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
  public var chatChannelViewsInBubble_outgoing: CGImage {
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
  public var chatChannelViewsOutBubble: CGImage {
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
  public var chatChannelViewsOverlayBubble: CGImage {
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
  public var chatPaidMessageInBubble_incoming: CGImage {
      if let image = cached.with({ $0["chatPaidMessageInBubble_incoming"] }) {
          return image
      } else {
          let image = _chatPaidMessageInBubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chatPaidMessageInBubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chatPaidMessageInBubble_outgoing: CGImage {
      if let image = cached.with({ $0["chatPaidMessageInBubble_outgoing"] }) {
          return image
      } else {
          let image = _chatPaidMessageInBubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chatPaidMessageInBubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chatPaidMessageOutBubble: CGImage {
      if let image = cached.with({ $0["chatPaidMessageOutBubble"] }) {
          return image
      } else {
          let image = _chatPaidMessageOutBubble()
          _ = cached.modify { current in 
              var current = current
              current["chatPaidMessageOutBubble"] = image
              return current
          }
          return image
      }
  }
  public var chatPaidMessageOverlayBubble: CGImage {
      if let image = cached.with({ $0["chatPaidMessageOverlayBubble"] }) {
          return image
      } else {
          let image = _chatPaidMessageOverlayBubble()
          _ = cached.modify { current in 
              var current = current
              current["chatPaidMessageOverlayBubble"] = image
              return current
          }
          return image
      }
  }
  public var chatNavigationBack: CGImage {
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
  public var peerInfoAddMember: CGImage {
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
  public var chatSearchUp: CGImage {
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
  public var chatSearchUpDisabled: CGImage {
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
  public var chatSearchDown: CGImage {
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
  public var chatSearchDownDisabled: CGImage {
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
  public var chatSearchCalendar: CGImage {
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
  public var dismissAccessory: CGImage {
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
  public var chatScrollUp: CGImage {
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
  public var chatScrollUpActive: CGImage {
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
  public var chatScrollDown: CGImage {
      if let image = cached.with({ $0["chatScrollDown"] }) {
          return image
      } else {
          let image = _chatScrollDown()
          _ = cached.modify { current in 
              var current = current
              current["chatScrollDown"] = image
              return current
          }
          return image
      }
  }
  public var chatScrollDownActive: CGImage {
      if let image = cached.with({ $0["chatScrollDownActive"] }) {
          return image
      } else {
          let image = _chatScrollDownActive()
          _ = cached.modify { current in 
              var current = current
              current["chatScrollDownActive"] = image
              return current
          }
          return image
      }
  }
  public var chatSendMessage: CGImage {
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
  public var chatSaveEditedMessage: CGImage {
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
  public var chatRecordVoice: CGImage {
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
  public var chatEntertainment: CGImage {
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
  public var chatInlineDismiss: CGImage {
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
  public var chatActiveReplyMarkup: CGImage {
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
  public var chatDisabledReplyMarkup: CGImage {
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
  public var chatSecretTimer: CGImage {
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
  public var chatForwardMessagesActive: CGImage {
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
  public var chatForwardMessagesInactive: CGImage {
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
  public var chatDeleteMessagesActive: CGImage {
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
  public var chatDeleteMessagesInactive: CGImage {
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
  public var generalNext: CGImage {
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
  public var generalNextActive: CGImage {
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
  public var generalSelect: CGImage {
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
  public var chatVoiceRecording: CGImage {
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
  public var chatVideoRecording: CGImage {
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
  public var chatRecord: CGImage {
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
  public var deleteItem: CGImage {
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
  public var deleteItemDisabled: CGImage {
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
  public var chatAttach: CGImage {
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
  public var chatAttachFile: CGImage {
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
  public var chatAttachPhoto: CGImage {
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
  public var chatAttachCamera: CGImage {
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
  public var chatAttachLocation: CGImage {
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
  public var chatAttachPoll: CGImage {
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
  public var mediaEmptyShared: CGImage {
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
  public var mediaEmptyFiles: CGImage {
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
  public var mediaEmptyMusic: CGImage {
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
  public var mediaEmptyLinks: CGImage {
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
  public var stickersAddFeatured: CGImage {
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
  public var stickersAddedFeatured: CGImage {
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
  public var stickersRemove: CGImage {
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
  public var peerMediaDownloadFileStart: CGImage {
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
  public var peerMediaDownloadFilePause: CGImage {
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
  public var stickersShare: CGImage {
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
  public var emojiRecentTab: CGImage {
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
  public var emojiSmileTab: CGImage {
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
  public var emojiNatureTab: CGImage {
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
  public var emojiFoodTab: CGImage {
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
  public var emojiSportTab: CGImage {
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
  public var emojiCarTab: CGImage {
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
  public var emojiObjectsTab: CGImage {
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
  public var emojiSymbolsTab: CGImage {
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
  public var emojiFlagsTab: CGImage {
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
  public var emojiRecentTabActive: CGImage {
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
  public var emojiSmileTabActive: CGImage {
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
  public var emojiNatureTabActive: CGImage {
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
  public var emojiFoodTabActive: CGImage {
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
  public var emojiSportTabActive: CGImage {
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
  public var emojiCarTabActive: CGImage {
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
  public var emojiObjectsTabActive: CGImage {
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
  public var emojiSymbolsTabActive: CGImage {
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
  public var emojiFlagsTabActive: CGImage {
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
  public var stickerBackground: CGImage {
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
  public var stickerBackgroundActive: CGImage {
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
  public var stickersTabRecent: CGImage {
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
  public var stickersTabGIF: CGImage {
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
  public var chatSendingInFrame_incoming: CGImage {
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
  public var chatSendingInHour_incoming: CGImage {
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
  public var chatSendingInMin_incoming: CGImage {
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
  public var chatSendingInFrame_outgoing: CGImage {
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
  public var chatSendingInHour_outgoing: CGImage {
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
  public var chatSendingInMin_outgoing: CGImage {
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
  public var chatSendingOutFrame: CGImage {
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
  public var chatSendingOutHour: CGImage {
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
  public var chatSendingOutMin: CGImage {
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
  public var chatSendingOverlayFrame: CGImage {
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
  public var chatSendingOverlayHour: CGImage {
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
  public var chatSendingOverlayMin: CGImage {
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
  public var chatActionUrl: CGImage {
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
  public var callInlineDecline: CGImage {
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
  public var callInlineMuted: CGImage {
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
  public var callInlineUnmuted: CGImage {
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
  public var eventLogTriangle: CGImage {
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
  public var channelIntro: CGImage {
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
  public var chatFileThumb: CGImage {
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
  public var chatFileThumbBubble_incoming: CGImage {
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
  public var chatFileThumbBubble_outgoing: CGImage {
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
  public var chatSecretThumb: CGImage {
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
  public var chatSecretThumbSmall: CGImage {
      if let image = cached.with({ $0["chatSecretThumbSmall"] }) {
          return image
      } else {
          let image = _chatSecretThumbSmall()
          _ = cached.modify { current in 
              var current = current
              current["chatSecretThumbSmall"] = image
              return current
          }
          return image
      }
  }
  public var chatMapPin: CGImage {
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
  public var chatSecretTitle: CGImage {
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
  public var emptySearch: CGImage {
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
  public var calendarBack: CGImage {
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
  public var calendarNext: CGImage {
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
  public var calendarBackDisabled: CGImage {
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
  public var calendarNextDisabled: CGImage {
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
  public var newChatCamera: CGImage {
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
  public var peerInfoVerify: CGImage {
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
  public var peerInfoVerifyProfile: CGImage {
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
  public var peerInfoCall: CGImage {
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
  public var callOutgoing: CGImage {
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
  public var recentDismiss: CGImage {
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
  public var recentDismissActive: CGImage {
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
  public var webgameShare: CGImage {
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
  public var chatSearchCancel: CGImage {
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
  public var chatSearchFrom: CGImage {
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
  public var callWindowDecline: CGImage {
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
  public var callWindowDeclineSmall: CGImage {
      if let image = cached.with({ $0["callWindowDeclineSmall"] }) {
          return image
      } else {
          let image = _callWindowDeclineSmall()
          _ = cached.modify { current in 
              var current = current
              current["callWindowDeclineSmall"] = image
              return current
          }
          return image
      }
  }
  public var callWindowAccept: CGImage {
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
  public var callWindowVideo: CGImage {
      if let image = cached.with({ $0["callWindowVideo"] }) {
          return image
      } else {
          let image = _callWindowVideo()
          _ = cached.modify { current in 
              var current = current
              current["callWindowVideo"] = image
              return current
          }
          return image
      }
  }
  public var callWindowVideoActive: CGImage {
      if let image = cached.with({ $0["callWindowVideoActive"] }) {
          return image
      } else {
          let image = _callWindowVideoActive()
          _ = cached.modify { current in 
              var current = current
              current["callWindowVideoActive"] = image
              return current
          }
          return image
      }
  }
  public var callWindowMute: CGImage {
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
  public var callWindowMuteActive: CGImage {
      if let image = cached.with({ $0["callWindowMuteActive"] }) {
          return image
      } else {
          let image = _callWindowMuteActive()
          _ = cached.modify { current in 
              var current = current
              current["callWindowMuteActive"] = image
              return current
          }
          return image
      }
  }
  public var callWindowClose: CGImage {
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
  public var callWindowDeviceSettings: CGImage {
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
  public var callSettings: CGImage {
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
  public var callWindowCancel: CGImage {
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
  public var chatActionEdit: CGImage {
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
  public var chatActionInfo: CGImage {
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
  public var chatActionMute: CGImage {
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
  public var chatActionUnmute: CGImage {
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
  public var chatActionClearHistory: CGImage {
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
  public var chatActionDeleteChat: CGImage {
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
  public var dismissPinned: CGImage {
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
  public var chatActionsActive: CGImage {
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
  public var chatEntertainmentSticker: CGImage {
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
  public var chatEmpty: CGImage {
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
  public var stickerPackClose: CGImage {
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
  public var stickerPackDelete: CGImage {
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
  public var modalShare: CGImage {
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
  public var modalClose: CGImage {
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
  public var ivChannelJoined: CGImage {
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
  public var chatListMention: CGImage {
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
  public var chatListMentionActive: CGImage {
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
  public var chatListMentionArchived: CGImage {
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
  public var chatListMentionArchivedActive: CGImage {
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
  public var chatMention: CGImage {
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
  public var chatMentionActive: CGImage {
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
  public var sliderControl: CGImage {
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
  public var sliderControlActive: CGImage {
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
  public var chatInstantView: CGImage {
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
  public var chatInstantViewBubble_incoming: CGImage {
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
  public var chatInstantViewBubble_outgoing: CGImage {
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
  public var instantViewShare: CGImage {
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
  public var instantViewActions: CGImage {
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
  public var instantViewActionsActive: CGImage {
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
  public var instantViewSafari: CGImage {
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
  public var instantViewBack: CGImage {
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
  public var instantViewCheck: CGImage {
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
  public var groupStickerNotFound: CGImage {
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
  public var settingsAskQuestion: CGImage {
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
  public var settingsFaq: CGImage {
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
  public var settingsStories: CGImage {
      if let image = cached.with({ $0["settingsStories"] }) {
          return image
      } else {
          let image = _settingsStories()
          _ = cached.modify { current in 
              var current = current
              current["settingsStories"] = image
              return current
          }
          return image
      }
  }
  public var settingsGeneral: CGImage {
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
  public var settingsLanguage: CGImage {
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
  public var settingsNotifications: CGImage {
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
  public var settingsSecurity: CGImage {
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
  public var settingsStickers: CGImage {
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
  public var settingsStorage: CGImage {
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
  public var settingsSessions: CGImage {
      if let image = cached.with({ $0["settingsSessions"] }) {
          return image
      } else {
          let image = _settingsSessions()
          _ = cached.modify { current in 
              var current = current
              current["settingsSessions"] = image
              return current
          }
          return image
      }
  }
  public var settingsProxy: CGImage {
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
  public var settingsAppearance: CGImage {
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
  public var settingsPassport: CGImage {
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
  public var settingsWallet: CGImage {
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
  public var settingsUpdate: CGImage {
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
  public var settingsFilters: CGImage {
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
  public var settingsPremium: CGImage {
      if let image = cached.with({ $0["settingsPremium"] }) {
          return image
      } else {
          let image = _settingsPremium()
          _ = cached.modify { current in 
              var current = current
              current["settingsPremium"] = image
              return current
          }
          return image
      }
  }
  public var settingsGiftPremium: CGImage {
      if let image = cached.with({ $0["settingsGiftPremium"] }) {
          return image
      } else {
          let image = _settingsGiftPremium()
          _ = cached.modify { current in 
              var current = current
              current["settingsGiftPremium"] = image
              return current
          }
          return image
      }
  }
  public var settingsAskQuestionActive: CGImage {
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
  public var settingsFaqActive: CGImage {
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
  public var settingsStoriesActive: CGImage {
      if let image = cached.with({ $0["settingsStoriesActive"] }) {
          return image
      } else {
          let image = _settingsStoriesActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsStoriesActive"] = image
              return current
          }
          return image
      }
  }
  public var settingsGeneralActive: CGImage {
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
  public var settingsLanguageActive: CGImage {
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
  public var settingsNotificationsActive: CGImage {
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
  public var settingsSecurityActive: CGImage {
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
  public var settingsStickersActive: CGImage {
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
  public var settingsStorageActive: CGImage {
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
  public var settingsSessionsActive: CGImage {
      if let image = cached.with({ $0["settingsSessionsActive"] }) {
          return image
      } else {
          let image = _settingsSessionsActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsSessionsActive"] = image
              return current
          }
          return image
      }
  }
  public var settingsProxyActive: CGImage {
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
  public var settingsAppearanceActive: CGImage {
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
  public var settingsPassportActive: CGImage {
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
  public var settingsWalletActive: CGImage {
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
  public var settingsUpdateActive: CGImage {
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
  public var settingsFiltersActive: CGImage {
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
  public var settingsProfile: CGImage {
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
  public var settingsBusiness: CGImage {
      if let image = cached.with({ $0["settingsBusiness"] }) {
          return image
      } else {
          let image = _settingsBusiness()
          _ = cached.modify { current in 
              var current = current
              current["settingsBusiness"] = image
              return current
          }
          return image
      }
  }
  public var settingsBusinessActive: CGImage {
      if let image = cached.with({ $0["settingsBusinessActive"] }) {
          return image
      } else {
          let image = _settingsBusinessActive()
          _ = cached.modify { current in 
              var current = current
              current["settingsBusinessActive"] = image
              return current
          }
          return image
      }
  }
  public var settingsStars: CGImage {
      if let image = cached.with({ $0["settingsStars"] }) {
          return image
      } else {
          let image = _settingsStars()
          _ = cached.modify { current in 
              var current = current
              current["settingsStars"] = image
              return current
          }
          return image
      }
  }
  public var generalCheck: CGImage {
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
  public var settingsAbout: CGImage {
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
  public var settingsLogout: CGImage {
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
  public var fastSettingsLock: CGImage {
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
  public var fastSettingsDark: CGImage {
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
  public var fastSettingsSunny: CGImage {
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
  public var fastSettingsMute: CGImage {
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
  public var fastSettingsUnmute: CGImage {
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
  public var chatRecordVideo: CGImage {
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
  public var inputChannelMute: CGImage {
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
  public var inputChannelUnmute: CGImage {
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
  public var changePhoneNumberIntro: CGImage {
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
  public var peerSavedMessages: CGImage {
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
  public var previewSenderCollage: CGImage {
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
  public var previewSenderPhoto: CGImage {
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
  public var previewSenderFile: CGImage {
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
  public var previewSenderCrop: CGImage {
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
  public var previewSenderDelete: CGImage {
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
  public var previewSenderDeleteFile: CGImage {
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
  public var previewSenderArchive: CGImage {
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
  public var chatGroupToggleSelected: CGImage {
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
  public var chatGroupToggleUnselected: CGImage {
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
  public var successModalProgress: CGImage {
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
  public var accentColorSelect: CGImage {
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
  public var transparentBackground: CGImage {
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
  public var lottieTransparentBackground: CGImage {
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
  public var passcodeTouchId: CGImage {
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
  public var passcodeLogin: CGImage {
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
  public var confirmDeleteMessagesAccessory: CGImage {
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
  public var alertCheckBoxSelected: CGImage {
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
  public var alertCheckBoxUnselected: CGImage {
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
  public var confirmPinAccessory: CGImage {
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
  public var confirmDeleteChatAccessory: CGImage {
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
  public var stickersEmptySearch: CGImage {
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
  public var twoStepVerificationCreateIntro: CGImage {
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
  public var secureIdAuth: CGImage {
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
  public var ivAudioPlay: CGImage {
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
  public var ivAudioPause: CGImage {
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
  public var proxyEnable: CGImage {
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
  public var proxyEnabled: CGImage {
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
  public var proxyState: CGImage {
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
  public var proxyDeleteListItem: CGImage {
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
  public var proxyInfoListItem: CGImage {
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
  public var proxyConnectedListItem: CGImage {
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
  public var proxyAddProxy: CGImage {
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
  public var proxyNextWaitingListItem: CGImage {
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
  public var passportForgotPassword: CGImage {
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
  public var confirmAppAccessoryIcon: CGImage {
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
  public var passportPassport: CGImage {
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
  public var passportIdCardReverse: CGImage {
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
  public var passportIdCard: CGImage {
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
  public var passportSelfie: CGImage {
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
  public var passportDriverLicense: CGImage {
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
  public var chatOverlayVoiceRecording: CGImage {
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
  public var chatOverlayVideoRecording: CGImage {
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
  public var chatOverlaySendRecording: CGImage {
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
  public var chatOverlayLockArrowRecording: CGImage {
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
  public var chatOverlayLockerBodyRecording: CGImage {
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
  public var chatOverlayLockerHeadRecording: CGImage {
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
  public var locationPin: CGImage {
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
  public var locationMapPin: CGImage {
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
  public var locationMapLocate: CGImage {
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
  public var locationMapLocated: CGImage {
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
  public var passportSettings: CGImage {
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
  public var passportInfo: CGImage {
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
  public var editMessageMedia: CGImage {
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
  public var playerMusicPlaceholder: CGImage {
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
  public var chatMusicPlaceholder: CGImage {
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
  public var chatMusicPlaceholderCap: CGImage {
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
  public var searchArticle: CGImage {
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
  public var searchSaved: CGImage {
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
  public var archivedChats: CGImage {
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
  public var hintPeerActive: CGImage {
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
  public var hintPeerActiveSelected: CGImage {
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
  public var chatSwiping_delete: CGImage {
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
  public var chatSwiping_mute: CGImage {
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
  public var chatSwiping_unmute: CGImage {
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
  public var chatSwiping_read: CGImage {
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
  public var chatSwiping_unread: CGImage {
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
  public var chatSwiping_pin: CGImage {
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
  public var chatSwiping_unpin: CGImage {
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
  public var chatSwiping_archive: CGImage {
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
  public var chatSwiping_unarchive: CGImage {
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
  public var galleryPrev: CGImage {
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
  public var galleryNext: CGImage {
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
  public var galleryMore: CGImage {
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
  public var galleryShare: CGImage {
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
  public var galleryFastSave: CGImage {
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
  public var galleryRotate: CGImage {
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
  public var galleryZoomIn: CGImage {
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
  public var galleryZoomOut: CGImage {
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
  public var editMessageCurrentPhoto: CGImage {
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
  public var videoPlayerPlay: CGImage {
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
  public var videoPlayerPause: CGImage {
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
  public var videoPlayerEnterFullScreen: CGImage {
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
  public var videoPlayerExitFullScreen: CGImage {
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
  public var videoPlayerPIPIn: CGImage {
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
  public var videoPlayerPIPOut: CGImage {
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
  public var videoPlayerRewind15Forward: CGImage {
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
  public var videoPlayerRewind15Backward: CGImage {
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
  public var videoPlayerVolume: CGImage {
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
  public var videoPlayerVolumeOff: CGImage {
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
  public var videoPlayerClose: CGImage {
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
  public var videoPlayerSliderInteractor: CGImage {
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
  public var streamingVideoDownload: CGImage {
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
  public var videoCompactFetching: CGImage {
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
  public var compactStreamingFetchingCancel: CGImage {
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
  public var customLocalizationDelete: CGImage {
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
  public var pollAddOption: CGImage {
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
  public var pollDeleteOption: CGImage {
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
  public var resort: CGImage {
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
  public var chatPollVoteUnselected: CGImage {
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
  public var chatPollVoteUnselectedBubble_incoming: CGImage {
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
  public var chatPollVoteUnselectedBubble_outgoing: CGImage {
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
  public var peerInfoAdmins: CGImage {
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
  public var peerInfoRecentActions: CGImage {
      if let image = cached.with({ $0["peerInfoRecentActions"] }) {
          return image
      } else {
          let image = _peerInfoRecentActions()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoRecentActions"] = image
              return current
          }
          return image
      }
  }
  public var peerInfoPermissions: CGImage {
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
  public var peerInfoBanned: CGImage {
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
  public var peerInfoMembers: CGImage {
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
  public var peerInfoStarsBalance: CGImage {
      if let image = cached.with({ $0["peerInfoStarsBalance"] }) {
          return image
      } else {
          let image = _peerInfoStarsBalance()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoStarsBalance"] = image
              return current
          }
          return image
      }
  }
  public var peerInfoBalance: CGImage {
      if let image = cached.with({ $0["peerInfoBalance"] }) {
          return image
      } else {
          let image = _peerInfoBalance()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoBalance"] = image
              return current
          }
          return image
      }
  }
  public var peerInfoTonBalance: CGImage {
      if let image = cached.with({ $0["peerInfoTonBalance"] }) {
          return image
      } else {
          let image = _peerInfoTonBalance()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoTonBalance"] = image
              return current
          }
          return image
      }
  }
  public var peerInfoBotUsername: CGImage {
      if let image = cached.with({ $0["peerInfoBotUsername"] }) {
          return image
      } else {
          let image = _peerInfoBotUsername()
          _ = cached.modify { current in 
              var current = current
              current["peerInfoBotUsername"] = image
              return current
          }
          return image
      }
  }
  public var chatUndoAction: CGImage {
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
  public var appUpdate: CGImage {
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
  public var inlineVideoSoundOff: CGImage {
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
  public var inlineVideoSoundOn: CGImage {
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
  public var logoutOptionAddAccount: CGImage {
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
  public var logoutOptionSetPasscode: CGImage {
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
  public var logoutOptionClearCache: CGImage {
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
  public var logoutOptionChangePhoneNumber: CGImage {
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
  public var logoutOptionContactSupport: CGImage {
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
  public var disableEmojiPrediction: CGImage {
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
  public var scam: CGImage {
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
  public var scamActive: CGImage {
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
  public var chatScam: CGImage {
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
  public var fake: CGImage {
      if let image = cached.with({ $0["fake"] }) {
          return image
      } else {
          let image = _fake()
          _ = cached.modify { current in 
              var current = current
              current["fake"] = image
              return current
          }
          return image
      }
  }
  public var fakeActive: CGImage {
      if let image = cached.with({ $0["fakeActive"] }) {
          return image
      } else {
          let image = _fakeActive()
          _ = cached.modify { current in 
              var current = current
              current["fakeActive"] = image
              return current
          }
          return image
      }
  }
  public var chatFake: CGImage {
      if let image = cached.with({ $0["chatFake"] }) {
          return image
      } else {
          let image = _chatFake()
          _ = cached.modify { current in 
              var current = current
              current["chatFake"] = image
              return current
          }
          return image
      }
  }
  public var chatUnarchive: CGImage {
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
  public var chatArchive: CGImage {
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
  public var privacySettings_blocked: CGImage {
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
  public var privacySettings_activeSessions: CGImage {
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
  public var privacySettings_passcode: CGImage {
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
  public var privacySettings_twoStep: CGImage {
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
  public var privacy_settings_autodelete: CGImage {
      if let image = cached.with({ $0["privacy_settings_autodelete"] }) {
          return image
      } else {
          let image = _privacy_settings_autodelete()
          _ = cached.modify { current in 
              var current = current
              current["privacy_settings_autodelete"] = image
              return current
          }
          return image
      }
  }
  public var deletedAccount: CGImage {
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
  public var stickerPackSelection: CGImage {
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
  public var stickerPackSelectionActive: CGImage {
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
  public var entertainment_Emoji: CGImage {
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
  public var entertainment_Stickers: CGImage {
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
  public var entertainment_Gifs: CGImage {
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
  public var entertainment_Search: CGImage {
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
  public var entertainment_Settings: CGImage {
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
  public var entertainment_SearchCancel: CGImage {
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
  public var entertainment_AnimatedEmoji: CGImage {
      if let image = cached.with({ $0["entertainment_AnimatedEmoji"] }) {
          return image
      } else {
          let image = _entertainment_AnimatedEmoji()
          _ = cached.modify { current in 
              var current = current
              current["entertainment_AnimatedEmoji"] = image
              return current
          }
          return image
      }
  }
  public var scheduledAvatar: CGImage {
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
  public var scheduledInputAction: CGImage {
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
  public var verifyDialog: CGImage {
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
  public var verifyDialogActive: CGImage {
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
  public var verify_dialog_left: CGImage {
      if let image = cached.with({ $0["verify_dialog_left"] }) {
          return image
      } else {
          let image = _verify_dialog_left()
          _ = cached.modify { current in 
              var current = current
              current["verify_dialog_left"] = image
              return current
          }
          return image
      }
  }
  public var verify_dialog_active_left: CGImage {
      if let image = cached.with({ $0["verify_dialog_active_left"] }) {
          return image
      } else {
          let image = _verify_dialog_active_left()
          _ = cached.modify { current in 
              var current = current
              current["verify_dialog_active_left"] = image
              return current
          }
          return image
      }
  }
  public var chatInputScheduled: CGImage {
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
  public var appearanceAddPlatformTheme: CGImage {
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
  public var wallet_close: CGImage {
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
  public var wallet_qr: CGImage {
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
  public var wallet_receive: CGImage {
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
  public var wallet_send: CGImage {
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
  public var wallet_settings: CGImage {
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
  public var wallet_update: CGImage {
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
  public var wallet_passcode_visible: CGImage {
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
  public var wallet_passcode_hidden: CGImage {
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
  public var wallpaper_color_close: CGImage {
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
  public var wallpaper_color_add: CGImage {
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
  public var wallpaper_color_swap: CGImage {
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
  public var wallpaper_color_rotate: CGImage {
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
  public var wallpaper_color_play: CGImage {
      if let image = cached.with({ $0["wallpaper_color_play"] }) {
          return image
      } else {
          let image = _wallpaper_color_play()
          _ = cached.modify { current in 
              var current = current
              current["wallpaper_color_play"] = image
              return current
          }
          return image
      }
  }
  public var login_cap: CGImage {
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
  public var login_qr_cap: CGImage {
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
  public var login_qr_empty_cap: CGImage {
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
  public var chat_failed_scroller: CGImage {
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
  public var chat_failed_scroller_active: CGImage {
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
  public var poll_quiz_unselected: CGImage {
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
  public var poll_selected: CGImage {
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
  public var poll_selection: CGImage {
      if let image = cached.with({ $0["poll_selection"] }) {
          return image
      } else {
          let image = _poll_selection()
          _ = cached.modify { current in 
              var current = current
              current["poll_selection"] = image
              return current
          }
          return image
      }
  }
  public var poll_selected_correct: CGImage {
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
  public var poll_selected_incorrect: CGImage {
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
  public var poll_selected_incoming: CGImage {
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
  public var poll_selection_incoming: CGImage {
      if let image = cached.with({ $0["poll_selection_incoming"] }) {
          return image
      } else {
          let image = _poll_selection_incoming()
          _ = cached.modify { current in 
              var current = current
              current["poll_selection_incoming"] = image
              return current
          }
          return image
      }
  }
  public var poll_selected_correct_incoming: CGImage {
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
  public var poll_selected_incorrect_incoming: CGImage {
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
  public var poll_selected_outgoing: CGImage {
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
  public var poll_selection_outgoing: CGImage {
      if let image = cached.with({ $0["poll_selection_outgoing"] }) {
          return image
      } else {
          let image = _poll_selection_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["poll_selection_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var poll_selected_correct_outgoing: CGImage {
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
  public var poll_selected_incorrect_outgoing: CGImage {
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
  public var chat_filter_edit: CGImage {
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
  public var chat_filter_add: CGImage {
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
  public var chat_filter_bots: CGImage {
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
  public var chat_filter_channels: CGImage {
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
  public var chat_filter_custom: CGImage {
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
  public var chat_filter_groups: CGImage {
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
  public var chat_filter_muted: CGImage {
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
  public var chat_filter_private_chats: CGImage {
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
  public var chat_filter_read: CGImage {
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
  public var chat_filter_secret_chats: CGImage {
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
  public var chat_filter_unmuted: CGImage {
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
  public var chat_filter_unread: CGImage {
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
  public var chat_filter_large_groups: CGImage {
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
  public var chat_filter_non_contacts: CGImage {
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
  public var chat_filter_archive: CGImage {
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
  public var chat_filter_bots_avatar: CGImage {
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
  public var chat_filter_channels_avatar: CGImage {
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
  public var chat_filter_custom_avatar: CGImage {
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
  public var chat_filter_groups_avatar: CGImage {
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
  public var chat_filter_muted_avatar: CGImage {
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
  public var chat_filter_private_chats_avatar: CGImage {
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
  public var chat_filter_read_avatar: CGImage {
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
  public var chat_filter_secret_chats_avatar: CGImage {
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
  public var chat_filter_unmuted_avatar: CGImage {
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
  public var chat_filter_unread_avatar: CGImage {
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
  public var chat_filter_large_groups_avatar: CGImage {
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
  public var chat_filter_non_contacts_avatar: CGImage {
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
  public var chat_filter_archive_avatar: CGImage {
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
  public var chat_filter_new_chats: CGImage {
      if let image = cached.with({ $0["chat_filter_new_chats"] }) {
          return image
      } else {
          let image = _chat_filter_new_chats()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_new_chats"] = image
              return current
          }
          return image
      }
  }
  public var chat_filter_existing_chats: CGImage {
      if let image = cached.with({ $0["chat_filter_existing_chats"] }) {
          return image
      } else {
          let image = _chat_filter_existing_chats()
          _ = cached.modify { current in 
              var current = current
              current["chat_filter_existing_chats"] = image
              return current
          }
          return image
      }
  }
  public var group_invite_via_link: CGImage {
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
  public var tab_contacts: CGImage {
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
  public var tab_contacts_active: CGImage {
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
  public var tab_calls: CGImage {
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
  public var tab_calls_active: CGImage {
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
  public var tab_chats: CGImage {
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
  public var tab_chats_active: CGImage {
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
  public var tab_chats_active_filters: CGImage {
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
  public var tab_settings: CGImage {
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
  public var tab_settings_active: CGImage {
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
  public var profile_add_member: CGImage {
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
  public var profile_call: CGImage {
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
  public var profile_video_call: CGImage {
      if let image = cached.with({ $0["profile_video_call"] }) {
          return image
      } else {
          let image = _profile_video_call()
          _ = cached.modify { current in 
              var current = current
              current["profile_video_call"] = image
              return current
          }
          return image
      }
  }
  public var profile_leave: CGImage {
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
  public var profile_message: CGImage {
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
  public var profile_more: CGImage {
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
  public var profile_mute: CGImage {
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
  public var profile_unmute: CGImage {
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
  public var profile_search: CGImage {
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
  public var profile_secret_chat: CGImage {
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
  public var profile_edit_photo: CGImage {
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
  public var profile_block: CGImage {
      if let image = cached.with({ $0["profile_block"] }) {
          return image
      } else {
          let image = _profile_block()
          _ = cached.modify { current in 
              var current = current
              current["profile_block"] = image
              return current
          }
          return image
      }
  }
  public var profile_report: CGImage {
      if let image = cached.with({ $0["profile_report"] }) {
          return image
      } else {
          let image = _profile_report()
          _ = cached.modify { current in 
              var current = current
              current["profile_report"] = image
              return current
          }
          return image
      }
  }
  public var profile_share: CGImage {
      if let image = cached.with({ $0["profile_share"] }) {
          return image
      } else {
          let image = _profile_share()
          _ = cached.modify { current in 
              var current = current
              current["profile_share"] = image
              return current
          }
          return image
      }
  }
  public var profile_stats: CGImage {
      if let image = cached.with({ $0["profile_stats"] }) {
          return image
      } else {
          let image = _profile_stats()
          _ = cached.modify { current in 
              var current = current
              current["profile_stats"] = image
              return current
          }
          return image
      }
  }
  public var profile_unblock: CGImage {
      if let image = cached.with({ $0["profile_unblock"] }) {
          return image
      } else {
          let image = _profile_unblock()
          _ = cached.modify { current in 
              var current = current
              current["profile_unblock"] = image
              return current
          }
          return image
      }
  }
  public var profile_translate: CGImage {
      if let image = cached.with({ $0["profile_translate"] }) {
          return image
      } else {
          let image = _profile_translate()
          _ = cached.modify { current in 
              var current = current
              current["profile_translate"] = image
              return current
          }
          return image
      }
  }
  public var profile_join_channel: CGImage {
      if let image = cached.with({ $0["profile_join_channel"] }) {
          return image
      } else {
          let image = _profile_join_channel()
          _ = cached.modify { current in 
              var current = current
              current["profile_join_channel"] = image
              return current
          }
          return image
      }
  }
  public var profile_boost: CGImage {
      if let image = cached.with({ $0["profile_boost"] }) {
          return image
      } else {
          let image = _profile_boost()
          _ = cached.modify { current in 
              var current = current
              current["profile_boost"] = image
              return current
          }
          return image
      }
  }
  public var profile_archive: CGImage {
      if let image = cached.with({ $0["profile_archive"] }) {
          return image
      } else {
          let image = _profile_archive()
          _ = cached.modify { current in 
              var current = current
              current["profile_archive"] = image
              return current
          }
          return image
      }
  }
  public var stats_boost_boost: CGImage {
      if let image = cached.with({ $0["stats_boost_boost"] }) {
          return image
      } else {
          let image = _stats_boost_boost()
          _ = cached.modify { current in 
              var current = current
              current["stats_boost_boost"] = image
              return current
          }
          return image
      }
  }
  public var stats_boost_giveaway: CGImage {
      if let image = cached.with({ $0["stats_boost_giveaway"] }) {
          return image
      } else {
          let image = _stats_boost_giveaway()
          _ = cached.modify { current in 
              var current = current
              current["stats_boost_giveaway"] = image
              return current
          }
          return image
      }
  }
  public var stats_boost_info: CGImage {
      if let image = cached.with({ $0["stats_boost_info"] }) {
          return image
      } else {
          let image = _stats_boost_info()
          _ = cached.modify { current in 
              var current = current
              current["stats_boost_info"] = image
              return current
          }
          return image
      }
  }
  public var chat_quiz_explanation: CGImage {
      if let image = cached.with({ $0["chat_quiz_explanation"] }) {
          return image
      } else {
          let image = _chat_quiz_explanation()
          _ = cached.modify { current in 
              var current = current
              current["chat_quiz_explanation"] = image
              return current
          }
          return image
      }
  }
  public var chat_quiz_explanation_bubble_incoming: CGImage {
      if let image = cached.with({ $0["chat_quiz_explanation_bubble_incoming"] }) {
          return image
      } else {
          let image = _chat_quiz_explanation_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chat_quiz_explanation_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chat_quiz_explanation_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["chat_quiz_explanation_bubble_outgoing"] }) {
          return image
      } else {
          let image = _chat_quiz_explanation_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chat_quiz_explanation_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var stickers_add_featured: CGImage {
      if let image = cached.with({ $0["stickers_add_featured"] }) {
          return image
      } else {
          let image = _stickers_add_featured()
          _ = cached.modify { current in 
              var current = current
              current["stickers_add_featured"] = image
              return current
          }
          return image
      }
  }
  public var stickers_add_featured_unread: CGImage {
      if let image = cached.with({ $0["stickers_add_featured_unread"] }) {
          return image
      } else {
          let image = _stickers_add_featured_unread()
          _ = cached.modify { current in 
              var current = current
              current["stickers_add_featured_unread"] = image
              return current
          }
          return image
      }
  }
  public var stickers_add_featured_active: CGImage {
      if let image = cached.with({ $0["stickers_add_featured_active"] }) {
          return image
      } else {
          let image = _stickers_add_featured_active()
          _ = cached.modify { current in 
              var current = current
              current["stickers_add_featured_active"] = image
              return current
          }
          return image
      }
  }
  public var stickers_add_featured_unread_active: CGImage {
      if let image = cached.with({ $0["stickers_add_featured_unread_active"] }) {
          return image
      } else {
          let image = _stickers_add_featured_unread_active()
          _ = cached.modify { current in 
              var current = current
              current["stickers_add_featured_unread_active"] = image
              return current
          }
          return image
      }
  }
  public var stickers_favorite: CGImage {
      if let image = cached.with({ $0["stickers_favorite"] }) {
          return image
      } else {
          let image = _stickers_favorite()
          _ = cached.modify { current in 
              var current = current
              current["stickers_favorite"] = image
              return current
          }
          return image
      }
  }
  public var stickers_favorite_active: CGImage {
      if let image = cached.with({ $0["stickers_favorite_active"] }) {
          return image
      } else {
          let image = _stickers_favorite_active()
          _ = cached.modify { current in 
              var current = current
              current["stickers_favorite_active"] = image
              return current
          }
          return image
      }
  }
  public var channel_info_promo: CGImage {
      if let image = cached.with({ $0["channel_info_promo"] }) {
          return image
      } else {
          let image = _channel_info_promo()
          _ = cached.modify { current in 
              var current = current
              current["channel_info_promo"] = image
              return current
          }
          return image
      }
  }
  public var channel_info_promo_bubble_incoming: CGImage {
      if let image = cached.with({ $0["channel_info_promo_bubble_incoming"] }) {
          return image
      } else {
          let image = _channel_info_promo_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["channel_info_promo_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var channel_info_promo_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["channel_info_promo_bubble_outgoing"] }) {
          return image
      } else {
          let image = _channel_info_promo_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["channel_info_promo_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_share_message: CGImage {
      if let image = cached.with({ $0["chat_share_message"] }) {
          return image
      } else {
          let image = _chat_share_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_share_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_goto_message: CGImage {
      if let image = cached.with({ $0["chat_goto_message"] }) {
          return image
      } else {
          let image = _chat_goto_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_goto_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_swipe_reply: CGImage {
      if let image = cached.with({ $0["chat_swipe_reply"] }) {
          return image
      } else {
          let image = _chat_swipe_reply()
          _ = cached.modify { current in 
              var current = current
              current["chat_swipe_reply"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_message: CGImage {
      if let image = cached.with({ $0["chat_like_message"] }) {
          return image
      } else {
          let image = _chat_like_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_message_unlike: CGImage {
      if let image = cached.with({ $0["chat_like_message_unlike"] }) {
          return image
      } else {
          let image = _chat_like_message_unlike()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_message_unlike"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside: CGImage {
      if let image = cached.with({ $0["chat_like_inside"] }) {
          return image
      } else {
          let image = _chat_like_inside()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_bubble_incoming: CGImage {
      if let image = cached.with({ $0["chat_like_inside_bubble_incoming"] }) {
          return image
      } else {
          let image = _chat_like_inside_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["chat_like_inside_bubble_outgoing"] }) {
          return image
      } else {
          let image = _chat_like_inside_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_bubble_overlay: CGImage {
      if let image = cached.with({ $0["chat_like_inside_bubble_overlay"] }) {
          return image
      } else {
          let image = _chat_like_inside_bubble_overlay()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_bubble_overlay"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_empty: CGImage {
      if let image = cached.with({ $0["chat_like_inside_empty"] }) {
          return image
      } else {
          let image = _chat_like_inside_empty()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_empty"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_empty_bubble_incoming: CGImage {
      if let image = cached.with({ $0["chat_like_inside_empty_bubble_incoming"] }) {
          return image
      } else {
          let image = _chat_like_inside_empty_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_empty_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_empty_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["chat_like_inside_empty_bubble_outgoing"] }) {
          return image
      } else {
          let image = _chat_like_inside_empty_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_empty_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_like_inside_empty_bubble_overlay: CGImage {
      if let image = cached.with({ $0["chat_like_inside_empty_bubble_overlay"] }) {
          return image
      } else {
          let image = _chat_like_inside_empty_bubble_overlay()
          _ = cached.modify { current in 
              var current = current
              current["chat_like_inside_empty_bubble_overlay"] = image
              return current
          }
          return image
      }
  }
  public var gif_trending: CGImage {
      if let image = cached.with({ $0["gif_trending"] }) {
          return image
      } else {
          let image = _gif_trending()
          _ = cached.modify { current in 
              var current = current
              current["gif_trending"] = image
              return current
          }
          return image
      }
  }
  public var gif_trending_active: CGImage {
      if let image = cached.with({ $0["gif_trending_active"] }) {
          return image
      } else {
          let image = _gif_trending_active()
          _ = cached.modify { current in 
              var current = current
              current["gif_trending_active"] = image
              return current
          }
          return image
      }
  }
  public var gif_recent: CGImage {
      if let image = cached.with({ $0["gif_recent"] }) {
          return image
      } else {
          let image = _gif_recent()
          _ = cached.modify { current in 
              var current = current
              current["gif_recent"] = image
              return current
          }
          return image
      }
  }
  public var gif_recent_active: CGImage {
      if let image = cached.with({ $0["gif_recent_active"] }) {
          return image
      } else {
          let image = _gif_recent_active()
          _ = cached.modify { current in 
              var current = current
              current["gif_recent_active"] = image
              return current
          }
          return image
      }
  }
  public var chat_list_thumb_play: CGImage {
      if let image = cached.with({ $0["chat_list_thumb_play"] }) {
          return image
      } else {
          let image = _chat_list_thumb_play()
          _ = cached.modify { current in 
              var current = current
              current["chat_list_thumb_play"] = image
              return current
          }
          return image
      }
  }
  public var call_tooltip_battery_low: CGImage {
      if let image = cached.with({ $0["call_tooltip_battery_low"] }) {
          return image
      } else {
          let image = _call_tooltip_battery_low()
          _ = cached.modify { current in 
              var current = current
              current["call_tooltip_battery_low"] = image
              return current
          }
          return image
      }
  }
  public var call_tooltip_camera_off: CGImage {
      if let image = cached.with({ $0["call_tooltip_camera_off"] }) {
          return image
      } else {
          let image = _call_tooltip_camera_off()
          _ = cached.modify { current in 
              var current = current
              current["call_tooltip_camera_off"] = image
              return current
          }
          return image
      }
  }
  public var call_tooltip_micro_off: CGImage {
      if let image = cached.with({ $0["call_tooltip_micro_off"] }) {
          return image
      } else {
          let image = _call_tooltip_micro_off()
          _ = cached.modify { current in 
              var current = current
              current["call_tooltip_micro_off"] = image
              return current
          }
          return image
      }
  }
  public var call_screen_sharing: CGImage {
      if let image = cached.with({ $0["call_screen_sharing"] }) {
          return image
      } else {
          let image = _call_screen_sharing()
          _ = cached.modify { current in 
              var current = current
              current["call_screen_sharing"] = image
              return current
          }
          return image
      }
  }
  public var call_screen_sharing_active: CGImage {
      if let image = cached.with({ $0["call_screen_sharing_active"] }) {
          return image
      } else {
          let image = _call_screen_sharing_active()
          _ = cached.modify { current in 
              var current = current
              current["call_screen_sharing_active"] = image
              return current
          }
          return image
      }
  }
  public var call_screen_settings: CGImage {
      if let image = cached.with({ $0["call_screen_settings"] }) {
          return image
      } else {
          let image = _call_screen_settings()
          _ = cached.modify { current in 
              var current = current
              current["call_screen_settings"] = image
              return current
          }
          return image
      }
  }
  public var search_filter: CGImage {
      if let image = cached.with({ $0["search_filter"] }) {
          return image
      } else {
          let image = _search_filter()
          _ = cached.modify { current in 
              var current = current
              current["search_filter"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_media: CGImage {
      if let image = cached.with({ $0["search_filter_media"] }) {
          return image
      } else {
          let image = _search_filter_media()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_media"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_files: CGImage {
      if let image = cached.with({ $0["search_filter_files"] }) {
          return image
      } else {
          let image = _search_filter_files()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_files"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_links: CGImage {
      if let image = cached.with({ $0["search_filter_links"] }) {
          return image
      } else {
          let image = _search_filter_links()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_links"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_music: CGImage {
      if let image = cached.with({ $0["search_filter_music"] }) {
          return image
      } else {
          let image = _search_filter_music()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_music"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_downloads: CGImage {
      if let image = cached.with({ $0["search_filter_downloads"] }) {
          return image
      } else {
          let image = _search_filter_downloads()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_downloads"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_add_peer: CGImage {
      if let image = cached.with({ $0["search_filter_add_peer"] }) {
          return image
      } else {
          let image = _search_filter_add_peer()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_add_peer"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_add_peer_active: CGImage {
      if let image = cached.with({ $0["search_filter_add_peer_active"] }) {
          return image
      } else {
          let image = _search_filter_add_peer_active()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_add_peer_active"] = image
              return current
          }
          return image
      }
  }
  public var search_filter_hashtag: CGImage {
      if let image = cached.with({ $0["search_filter_hashtag"] }) {
          return image
      } else {
          let image = _search_filter_hashtag()
          _ = cached.modify { current in 
              var current = current
              current["search_filter_hashtag"] = image
              return current
          }
          return image
      }
  }
  public var search_hashtag_chevron: CGImage {
      if let image = cached.with({ $0["search_hashtag_chevron"] }) {
          return image
      } else {
          let image = _search_hashtag_chevron()
          _ = cached.modify { current in 
              var current = current
              current["search_hashtag_chevron"] = image
              return current
          }
          return image
      }
  }
  public var chat_reply_count_bubble_incoming: CGImage {
      if let image = cached.with({ $0["chat_reply_count_bubble_incoming"] }) {
          return image
      } else {
          let image = _chat_reply_count_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chat_reply_count_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chat_reply_count_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["chat_reply_count_bubble_outgoing"] }) {
          return image
      } else {
          let image = _chat_reply_count_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chat_reply_count_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_reply_count: CGImage {
      if let image = cached.with({ $0["chat_reply_count"] }) {
          return image
      } else {
          let image = _chat_reply_count()
          _ = cached.modify { current in 
              var current = current
              current["chat_reply_count"] = image
              return current
          }
          return image
      }
  }
  public var chat_reply_count_overlay: CGImage {
      if let image = cached.with({ $0["chat_reply_count_overlay"] }) {
          return image
      } else {
          let image = _chat_reply_count_overlay()
          _ = cached.modify { current in 
              var current = current
              current["chat_reply_count_overlay"] = image
              return current
          }
          return image
      }
  }
  public var channel_comments_bubble: CGImage {
      if let image = cached.with({ $0["channel_comments_bubble"] }) {
          return image
      } else {
          let image = _channel_comments_bubble()
          _ = cached.modify { current in 
              var current = current
              current["channel_comments_bubble"] = image
              return current
          }
          return image
      }
  }
  public var channel_comments_bubble_next: CGImage {
      if let image = cached.with({ $0["channel_comments_bubble_next"] }) {
          return image
      } else {
          let image = _channel_comments_bubble_next()
          _ = cached.modify { current in 
              var current = current
              current["channel_comments_bubble_next"] = image
              return current
          }
          return image
      }
  }
  public var channel_comments_list: CGImage {
      if let image = cached.with({ $0["channel_comments_list"] }) {
          return image
      } else {
          let image = _channel_comments_list()
          _ = cached.modify { current in 
              var current = current
              current["channel_comments_list"] = image
              return current
          }
          return image
      }
  }
  public var channel_comments_overlay: CGImage {
      if let image = cached.with({ $0["channel_comments_overlay"] }) {
          return image
      } else {
          let image = _channel_comments_overlay()
          _ = cached.modify { current in 
              var current = current
              current["channel_comments_overlay"] = image
              return current
          }
          return image
      }
  }
  public var chat_replies_avatar: CGImage {
      if let image = cached.with({ $0["chat_replies_avatar"] }) {
          return image
      } else {
          let image = _chat_replies_avatar()
          _ = cached.modify { current in 
              var current = current
              current["chat_replies_avatar"] = image
              return current
          }
          return image
      }
  }
  public var group_selection_foreground: CGImage {
      if let image = cached.with({ $0["group_selection_foreground"] }) {
          return image
      } else {
          let image = _group_selection_foreground()
          _ = cached.modify { current in 
              var current = current
              current["group_selection_foreground"] = image
              return current
          }
          return image
      }
  }
  public var group_selection_foreground_bubble_incoming: CGImage {
      if let image = cached.with({ $0["group_selection_foreground_bubble_incoming"] }) {
          return image
      } else {
          let image = _group_selection_foreground_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["group_selection_foreground_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var group_selection_foreground_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["group_selection_foreground_bubble_outgoing"] }) {
          return image
      } else {
          let image = _group_selection_foreground_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["group_selection_foreground_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_pinned_list: CGImage {
      if let image = cached.with({ $0["chat_pinned_list"] }) {
          return image
      } else {
          let image = _chat_pinned_list()
          _ = cached.modify { current in 
              var current = current
              current["chat_pinned_list"] = image
              return current
          }
          return image
      }
  }
  public var chat_pinned_message: CGImage {
      if let image = cached.with({ $0["chat_pinned_message"] }) {
          return image
      } else {
          let image = _chat_pinned_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_pinned_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_pinned_message_bubble_incoming: CGImage {
      if let image = cached.with({ $0["chat_pinned_message_bubble_incoming"] }) {
          return image
      } else {
          let image = _chat_pinned_message_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["chat_pinned_message_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var chat_pinned_message_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["chat_pinned_message_bubble_outgoing"] }) {
          return image
      } else {
          let image = _chat_pinned_message_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["chat_pinned_message_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var chat_pinned_message_overlay_bubble: CGImage {
      if let image = cached.with({ $0["chat_pinned_message_overlay_bubble"] }) {
          return image
      } else {
          let image = _chat_pinned_message_overlay_bubble()
          _ = cached.modify { current in 
              var current = current
              current["chat_pinned_message_overlay_bubble"] = image
              return current
          }
          return image
      }
  }
  public var chat_voicechat_can_unmute: CGImage {
      if let image = cached.with({ $0["chat_voicechat_can_unmute"] }) {
          return image
      } else {
          let image = _chat_voicechat_can_unmute()
          _ = cached.modify { current in 
              var current = current
              current["chat_voicechat_can_unmute"] = image
              return current
          }
          return image
      }
  }
  public var chat_voicechat_cant_unmute: CGImage {
      if let image = cached.with({ $0["chat_voicechat_cant_unmute"] }) {
          return image
      } else {
          let image = _chat_voicechat_cant_unmute()
          _ = cached.modify { current in 
              var current = current
              current["chat_voicechat_cant_unmute"] = image
              return current
          }
          return image
      }
  }
  public var chat_voicechat_unmuted: CGImage {
      if let image = cached.with({ $0["chat_voicechat_unmuted"] }) {
          return image
      } else {
          let image = _chat_voicechat_unmuted()
          _ = cached.modify { current in 
              var current = current
              current["chat_voicechat_unmuted"] = image
              return current
          }
          return image
      }
  }
  public var profile_voice_chat: CGImage {
      if let image = cached.with({ $0["profile_voice_chat"] }) {
          return image
      } else {
          let image = _profile_voice_chat()
          _ = cached.modify { current in 
              var current = current
              current["profile_voice_chat"] = image
              return current
          }
          return image
      }
  }
  public var chat_voice_chat: CGImage {
      if let image = cached.with({ $0["chat_voice_chat"] }) {
          return image
      } else {
          let image = _chat_voice_chat()
          _ = cached.modify { current in 
              var current = current
              current["chat_voice_chat"] = image
              return current
          }
          return image
      }
  }
  public var chat_voice_chat_active: CGImage {
      if let image = cached.with({ $0["chat_voice_chat_active"] }) {
          return image
      } else {
          let image = _chat_voice_chat_active()
          _ = cached.modify { current in 
              var current = current
              current["chat_voice_chat_active"] = image
              return current
          }
          return image
      }
  }
  public var editor_draw: CGImage {
      if let image = cached.with({ $0["editor_draw"] }) {
          return image
      } else {
          let image = _editor_draw()
          _ = cached.modify { current in 
              var current = current
              current["editor_draw"] = image
              return current
          }
          return image
      }
  }
  public var editor_delete: CGImage {
      if let image = cached.with({ $0["editor_delete"] }) {
          return image
      } else {
          let image = _editor_delete()
          _ = cached.modify { current in 
              var current = current
              current["editor_delete"] = image
              return current
          }
          return image
      }
  }
  public var editor_crop: CGImage {
      if let image = cached.with({ $0["editor_crop"] }) {
          return image
      } else {
          let image = _editor_crop()
          _ = cached.modify { current in 
              var current = current
              current["editor_crop"] = image
              return current
          }
          return image
      }
  }
  public var fast_copy_link: CGImage {
      if let image = cached.with({ $0["fast_copy_link"] }) {
          return image
      } else {
          let image = _fast_copy_link()
          _ = cached.modify { current in 
              var current = current
              current["fast_copy_link"] = image
              return current
          }
          return image
      }
  }
  public var profile_channel_sign: CGImage {
      if let image = cached.with({ $0["profile_channel_sign"] }) {
          return image
      } else {
          let image = _profile_channel_sign()
          _ = cached.modify { current in 
              var current = current
              current["profile_channel_sign"] = image
              return current
          }
          return image
      }
  }
  public var profile_channel_type: CGImage {
      if let image = cached.with({ $0["profile_channel_type"] }) {
          return image
      } else {
          let image = _profile_channel_type()
          _ = cached.modify { current in 
              var current = current
              current["profile_channel_type"] = image
              return current
          }
          return image
      }
  }
  public var profile_group_type: CGImage {
      if let image = cached.with({ $0["profile_group_type"] }) {
          return image
      } else {
          let image = _profile_group_type()
          _ = cached.modify { current in 
              var current = current
              current["profile_group_type"] = image
              return current
          }
          return image
      }
  }
  public var profile_group_topics: CGImage {
      if let image = cached.with({ $0["profile_group_topics"] }) {
          return image
      } else {
          let image = _profile_group_topics()
          _ = cached.modify { current in 
              var current = current
              current["profile_group_topics"] = image
              return current
          }
          return image
      }
  }
  public var profile_group_destruct: CGImage {
      if let image = cached.with({ $0["profile_group_destruct"] }) {
          return image
      } else {
          let image = _profile_group_destruct()
          _ = cached.modify { current in 
              var current = current
              current["profile_group_destruct"] = image
              return current
          }
          return image
      }
  }
  public var profile_group_discussion: CGImage {
      if let image = cached.with({ $0["profile_group_discussion"] }) {
          return image
      } else {
          let image = _profile_group_discussion()
          _ = cached.modify { current in 
              var current = current
              current["profile_group_discussion"] = image
              return current
          }
          return image
      }
  }
  public var profile_requests: CGImage {
      if let image = cached.with({ $0["profile_requests"] }) {
          return image
      } else {
          let image = _profile_requests()
          _ = cached.modify { current in 
              var current = current
              current["profile_requests"] = image
              return current
          }
          return image
      }
  }
  public var profile_reactions: CGImage {
      if let image = cached.with({ $0["profile_reactions"] }) {
          return image
      } else {
          let image = _profile_reactions()
          _ = cached.modify { current in 
              var current = current
              current["profile_reactions"] = image
              return current
          }
          return image
      }
  }
  public var profile_channel_color: CGImage {
      if let image = cached.with({ $0["profile_channel_color"] }) {
          return image
      } else {
          let image = _profile_channel_color()
          _ = cached.modify { current in 
              var current = current
              current["profile_channel_color"] = image
              return current
          }
          return image
      }
  }
  public var profile_channel_stats: CGImage {
      if let image = cached.with({ $0["profile_channel_stats"] }) {
          return image
      } else {
          let image = _profile_channel_stats()
          _ = cached.modify { current in 
              var current = current
              current["profile_channel_stats"] = image
              return current
          }
          return image
      }
  }
  public var profile_removed: CGImage {
      if let image = cached.with({ $0["profile_removed"] }) {
          return image
      } else {
          let image = _profile_removed()
          _ = cached.modify { current in 
              var current = current
              current["profile_removed"] = image
              return current
          }
          return image
      }
  }
  public var profile_links: CGImage {
      if let image = cached.with({ $0["profile_links"] }) {
          return image
      } else {
          let image = _profile_links()
          _ = cached.modify { current in 
              var current = current
              current["profile_links"] = image
              return current
          }
          return image
      }
  }
  public var destruct_clear_history: CGImage {
      if let image = cached.with({ $0["destruct_clear_history"] }) {
          return image
      } else {
          let image = _destruct_clear_history()
          _ = cached.modify { current in 
              var current = current
              current["destruct_clear_history"] = image
              return current
          }
          return image
      }
  }
  public var chat_gigagroup_info: CGImage {
      if let image = cached.with({ $0["chat_gigagroup_info"] }) {
          return image
      } else {
          let image = _chat_gigagroup_info()
          _ = cached.modify { current in 
              var current = current
              current["chat_gigagroup_info"] = image
              return current
          }
          return image
      }
  }
  public var playlist_next: CGImage {
      if let image = cached.with({ $0["playlist_next"] }) {
          return image
      } else {
          let image = _playlist_next()
          _ = cached.modify { current in 
              var current = current
              current["playlist_next"] = image
              return current
          }
          return image
      }
  }
  public var playlist_prev: CGImage {
      if let image = cached.with({ $0["playlist_prev"] }) {
          return image
      } else {
          let image = _playlist_prev()
          _ = cached.modify { current in 
              var current = current
              current["playlist_prev"] = image
              return current
          }
          return image
      }
  }
  public var playlist_next_locked: CGImage {
      if let image = cached.with({ $0["playlist_next_locked"] }) {
          return image
      } else {
          let image = _playlist_next_locked()
          _ = cached.modify { current in 
              var current = current
              current["playlist_next_locked"] = image
              return current
          }
          return image
      }
  }
  public var playlist_prev_locked: CGImage {
      if let image = cached.with({ $0["playlist_prev_locked"] }) {
          return image
      } else {
          let image = _playlist_prev_locked()
          _ = cached.modify { current in 
              var current = current
              current["playlist_prev_locked"] = image
              return current
          }
          return image
      }
  }
  public var playlist_random: CGImage {
      if let image = cached.with({ $0["playlist_random"] }) {
          return image
      } else {
          let image = _playlist_random()
          _ = cached.modify { current in 
              var current = current
              current["playlist_random"] = image
              return current
          }
          return image
      }
  }
  public var playlist_order_normal: CGImage {
      if let image = cached.with({ $0["playlist_order_normal"] }) {
          return image
      } else {
          let image = _playlist_order_normal()
          _ = cached.modify { current in 
              var current = current
              current["playlist_order_normal"] = image
              return current
          }
          return image
      }
  }
  public var playlist_order_reversed: CGImage {
      if let image = cached.with({ $0["playlist_order_reversed"] }) {
          return image
      } else {
          let image = _playlist_order_reversed()
          _ = cached.modify { current in 
              var current = current
              current["playlist_order_reversed"] = image
              return current
          }
          return image
      }
  }
  public var playlist_order_random: CGImage {
      if let image = cached.with({ $0["playlist_order_random"] }) {
          return image
      } else {
          let image = _playlist_order_random()
          _ = cached.modify { current in 
              var current = current
              current["playlist_order_random"] = image
              return current
          }
          return image
      }
  }
  public var playlist_repeat_none: CGImage {
      if let image = cached.with({ $0["playlist_repeat_none"] }) {
          return image
      } else {
          let image = _playlist_repeat_none()
          _ = cached.modify { current in 
              var current = current
              current["playlist_repeat_none"] = image
              return current
          }
          return image
      }
  }
  public var playlist_repeat_circle: CGImage {
      if let image = cached.with({ $0["playlist_repeat_circle"] }) {
          return image
      } else {
          let image = _playlist_repeat_circle()
          _ = cached.modify { current in 
              var current = current
              current["playlist_repeat_circle"] = image
              return current
          }
          return image
      }
  }
  public var playlist_repeat_one: CGImage {
      if let image = cached.with({ $0["playlist_repeat_one"] }) {
          return image
      } else {
          let image = _playlist_repeat_one()
          _ = cached.modify { current in 
              var current = current
              current["playlist_repeat_one"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_next: CGImage {
      if let image = cached.with({ $0["audioplayer_next"] }) {
          return image
      } else {
          let image = _audioplayer_next()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_next"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_prev: CGImage {
      if let image = cached.with({ $0["audioplayer_prev"] }) {
          return image
      } else {
          let image = _audioplayer_prev()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_prev"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_dismiss: CGImage {
      if let image = cached.with({ $0["audioplayer_dismiss"] }) {
          return image
      } else {
          let image = _audioplayer_dismiss()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_dismiss"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_repeat_none: CGImage {
      if let image = cached.with({ $0["audioplayer_repeat_none"] }) {
          return image
      } else {
          let image = _audioplayer_repeat_none()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_repeat_none"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_repeat_circle: CGImage {
      if let image = cached.with({ $0["audioplayer_repeat_circle"] }) {
          return image
      } else {
          let image = _audioplayer_repeat_circle()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_repeat_circle"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_repeat_one: CGImage {
      if let image = cached.with({ $0["audioplayer_repeat_one"] }) {
          return image
      } else {
          let image = _audioplayer_repeat_one()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_repeat_one"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_locked_next: CGImage {
      if let image = cached.with({ $0["audioplayer_locked_next"] }) {
          return image
      } else {
          let image = _audioplayer_locked_next()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_locked_next"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_locked_prev: CGImage {
      if let image = cached.with({ $0["audioplayer_locked_prev"] }) {
          return image
      } else {
          let image = _audioplayer_locked_prev()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_locked_prev"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_volume: CGImage {
      if let image = cached.with({ $0["audioplayer_volume"] }) {
          return image
      } else {
          let image = _audioplayer_volume()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_volume"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_volume_off: CGImage {
      if let image = cached.with({ $0["audioplayer_volume_off"] }) {
          return image
      } else {
          let image = _audioplayer_volume_off()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_volume_off"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_speed_x1: CGImage {
      if let image = cached.with({ $0["audioplayer_speed_x1"] }) {
          return image
      } else {
          let image = _audioplayer_speed_x1()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_speed_x1"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_speed_x2: CGImage {
      if let image = cached.with({ $0["audioplayer_speed_x2"] }) {
          return image
      } else {
          let image = _audioplayer_speed_x2()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_speed_x2"] = image
              return current
          }
          return image
      }
  }
  public var audioplayer_list: CGImage {
      if let image = cached.with({ $0["audioplayer_list"] }) {
          return image
      } else {
          let image = _audioplayer_list()
          _ = cached.modify { current in 
              var current = current
              current["audioplayer_list"] = image
              return current
          }
          return image
      }
  }
  public var chat_info_voice_chat: CGImage {
      if let image = cached.with({ $0["chat_info_voice_chat"] }) {
          return image
      } else {
          let image = _chat_info_voice_chat()
          _ = cached.modify { current in 
              var current = current
              current["chat_info_voice_chat"] = image
              return current
          }
          return image
      }
  }
  public var chat_info_create_group: CGImage {
      if let image = cached.with({ $0["chat_info_create_group"] }) {
          return image
      } else {
          let image = _chat_info_create_group()
          _ = cached.modify { current in 
              var current = current
              current["chat_info_create_group"] = image
              return current
          }
          return image
      }
  }
  public var chat_info_change_colors: CGImage {
      if let image = cached.with({ $0["chat_info_change_colors"] }) {
          return image
      } else {
          let image = _chat_info_change_colors()
          _ = cached.modify { current in 
              var current = current
              current["chat_info_change_colors"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_system: CGImage {
      if let image = cached.with({ $0["empty_chat_system"] }) {
          return image
      } else {
          let image = _empty_chat_system()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_system"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_dark: CGImage {
      if let image = cached.with({ $0["empty_chat_dark"] }) {
          return image
      } else {
          let image = _empty_chat_dark()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_dark"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_light: CGImage {
      if let image = cached.with({ $0["empty_chat_light"] }) {
          return image
      } else {
          let image = _empty_chat_light()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_light"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_system_active: CGImage {
      if let image = cached.with({ $0["empty_chat_system_active"] }) {
          return image
      } else {
          let image = _empty_chat_system_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_system_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_dark_active: CGImage {
      if let image = cached.with({ $0["empty_chat_dark_active"] }) {
          return image
      } else {
          let image = _empty_chat_dark_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_dark_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_light_active: CGImage {
      if let image = cached.with({ $0["empty_chat_light_active"] }) {
          return image
      } else {
          let image = _empty_chat_light_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_light_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_clear: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_clear"] }) {
          return image
      } else {
          let image = _empty_chat_storage_clear()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_clear"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_low: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_low"] }) {
          return image
      } else {
          let image = _empty_chat_storage_low()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_low"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_medium: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_medium"] }) {
          return image
      } else {
          let image = _empty_chat_storage_medium()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_medium"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_high: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_high"] }) {
          return image
      } else {
          let image = _empty_chat_storage_high()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_high"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_low_active: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_low_active"] }) {
          return image
      } else {
          let image = _empty_chat_storage_low_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_low_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_medium_active: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_medium_active"] }) {
          return image
      } else {
          let image = _empty_chat_storage_medium_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_medium_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_storage_high_active: CGImage {
      if let image = cached.with({ $0["empty_chat_storage_high_active"] }) {
          return image
      } else {
          let image = _empty_chat_storage_high_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_storage_high_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_none: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_none"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_none()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_none"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_mysets: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_mysets"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_mysets()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_mysets"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_allsets: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_allsets"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_allsets()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_allsets"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_none_active: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_none_active"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_none_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_none_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_mysets_active: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_mysets_active"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_mysets_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_mysets_active"] = image
              return current
          }
          return image
      }
  }
  public var empty_chat_stickers_allsets_active: CGImage {
      if let image = cached.with({ $0["empty_chat_stickers_allsets_active"] }) {
          return image
      } else {
          let image = _empty_chat_stickers_allsets_active()
          _ = cached.modify { current in 
              var current = current
              current["empty_chat_stickers_allsets_active"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_dismiss: CGImage {
      if let image = cached.with({ $0["chat_action_dismiss"] }) {
          return image
      } else {
          let image = _chat_action_dismiss()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_dismiss"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_edit_message: CGImage {
      if let image = cached.with({ $0["chat_action_edit_message"] }) {
          return image
      } else {
          let image = _chat_action_edit_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_edit_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_forward_message: CGImage {
      if let image = cached.with({ $0["chat_action_forward_message"] }) {
          return image
      } else {
          let image = _chat_action_forward_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_forward_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_reply_message: CGImage {
      if let image = cached.with({ $0["chat_action_reply_message"] }) {
          return image
      } else {
          let image = _chat_action_reply_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_reply_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_url_preview: CGImage {
      if let image = cached.with({ $0["chat_action_url_preview"] }) {
          return image
      } else {
          let image = _chat_action_url_preview()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_url_preview"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_menu_update_chat: CGImage {
      if let image = cached.with({ $0["chat_action_menu_update_chat"] }) {
          return image
      } else {
          let image = _chat_action_menu_update_chat()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_menu_update_chat"] = image
              return current
          }
          return image
      }
  }
  public var chat_action_menu_selected: CGImage {
      if let image = cached.with({ $0["chat_action_menu_selected"] }) {
          return image
      } else {
          let image = _chat_action_menu_selected()
          _ = cached.modify { current in 
              var current = current
              current["chat_action_menu_selected"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_favorite: CGImage {
      if let image = cached.with({ $0["widget_peers_favorite"] }) {
          return image
      } else {
          let image = _widget_peers_favorite()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_favorite"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_recent: CGImage {
      if let image = cached.with({ $0["widget_peers_recent"] }) {
          return image
      } else {
          let image = _widget_peers_recent()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_recent"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_both: CGImage {
      if let image = cached.with({ $0["widget_peers_both"] }) {
          return image
      } else {
          let image = _widget_peers_both()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_both"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_favorite_active: CGImage {
      if let image = cached.with({ $0["widget_peers_favorite_active"] }) {
          return image
      } else {
          let image = _widget_peers_favorite_active()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_favorite_active"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_recent_active: CGImage {
      if let image = cached.with({ $0["widget_peers_recent_active"] }) {
          return image
      } else {
          let image = _widget_peers_recent_active()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_recent_active"] = image
              return current
          }
          return image
      }
  }
  public var widget_peers_both_active: CGImage {
      if let image = cached.with({ $0["widget_peers_both_active"] }) {
          return image
      } else {
          let image = _widget_peers_both_active()
          _ = cached.modify { current in 
              var current = current
              current["widget_peers_both_active"] = image
              return current
          }
          return image
      }
  }
  public var chat_reactions_add: CGImage {
      if let image = cached.with({ $0["chat_reactions_add"] }) {
          return image
      } else {
          let image = _chat_reactions_add()
          _ = cached.modify { current in 
              var current = current
              current["chat_reactions_add"] = image
              return current
          }
          return image
      }
  }
  public var chat_reactions_add_bubble: CGImage {
      if let image = cached.with({ $0["chat_reactions_add_bubble"] }) {
          return image
      } else {
          let image = _chat_reactions_add_bubble()
          _ = cached.modify { current in 
              var current = current
              current["chat_reactions_add_bubble"] = image
              return current
          }
          return image
      }
  }
  public var chat_reactions_add_active: CGImage {
      if let image = cached.with({ $0["chat_reactions_add_active"] }) {
          return image
      } else {
          let image = _chat_reactions_add_active()
          _ = cached.modify { current in 
              var current = current
              current["chat_reactions_add_active"] = image
              return current
          }
          return image
      }
  }
  public var reactions_badge: CGImage {
      if let image = cached.with({ $0["reactions_badge"] }) {
          return image
      } else {
          let image = _reactions_badge()
          _ = cached.modify { current in 
              var current = current
              current["reactions_badge"] = image
              return current
          }
          return image
      }
  }
  public var reactions_badge_active: CGImage {
      if let image = cached.with({ $0["reactions_badge_active"] }) {
          return image
      } else {
          let image = _reactions_badge_active()
          _ = cached.modify { current in 
              var current = current
              current["reactions_badge_active"] = image
              return current
          }
          return image
      }
  }
  public var reactions_badge_archive: CGImage {
      if let image = cached.with({ $0["reactions_badge_archive"] }) {
          return image
      } else {
          let image = _reactions_badge_archive()
          _ = cached.modify { current in 
              var current = current
              current["reactions_badge_archive"] = image
              return current
          }
          return image
      }
  }
  public var reactions_badge_archive_active: CGImage {
      if let image = cached.with({ $0["reactions_badge_archive_active"] }) {
          return image
      } else {
          let image = _reactions_badge_archive_active()
          _ = cached.modify { current in 
              var current = current
              current["reactions_badge_archive_active"] = image
              return current
          }
          return image
      }
  }
  public var reactions_show_more: CGImage {
      if let image = cached.with({ $0["reactions_show_more"] }) {
          return image
      } else {
          let image = _reactions_show_more()
          _ = cached.modify { current in 
              var current = current
              current["reactions_show_more"] = image
              return current
          }
          return image
      }
  }
  public var chat_reactions_badge: CGImage {
      if let image = cached.with({ $0["chat_reactions_badge"] }) {
          return image
      } else {
          let image = _chat_reactions_badge()
          _ = cached.modify { current in 
              var current = current
              current["chat_reactions_badge"] = image
              return current
          }
          return image
      }
  }
  public var chat_reactions_badge_active: CGImage {
      if let image = cached.with({ $0["chat_reactions_badge_active"] }) {
          return image
      } else {
          let image = _chat_reactions_badge_active()
          _ = cached.modify { current in 
              var current = current
              current["chat_reactions_badge_active"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_close: CGImage {
      if let image = cached.with({ $0["gallery_pip_close"] }) {
          return image
      } else {
          let image = _gallery_pip_close()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_close"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_muted: CGImage {
      if let image = cached.with({ $0["gallery_pip_muted"] }) {
          return image
      } else {
          let image = _gallery_pip_muted()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_muted"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_unmuted: CGImage {
      if let image = cached.with({ $0["gallery_pip_unmuted"] }) {
          return image
      } else {
          let image = _gallery_pip_unmuted()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_unmuted"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_out: CGImage {
      if let image = cached.with({ $0["gallery_pip_out"] }) {
          return image
      } else {
          let image = _gallery_pip_out()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_out"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_pause: CGImage {
      if let image = cached.with({ $0["gallery_pip_pause"] }) {
          return image
      } else {
          let image = _gallery_pip_pause()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_pause"] = image
              return current
          }
          return image
      }
  }
  public var gallery_pip_play: CGImage {
      if let image = cached.with({ $0["gallery_pip_play"] }) {
          return image
      } else {
          let image = _gallery_pip_play()
          _ = cached.modify { current in 
              var current = current
              current["gallery_pip_play"] = image
              return current
          }
          return image
      }
  }
  public var notification_sound_add: CGImage {
      if let image = cached.with({ $0["notification_sound_add"] }) {
          return image
      } else {
          let image = _notification_sound_add()
          _ = cached.modify { current in 
              var current = current
              current["notification_sound_add"] = image
              return current
          }
          return image
      }
  }
  public var premium_lock: CGImage {
      if let image = cached.with({ $0["premium_lock"] }) {
          return image
      } else {
          let image = _premium_lock()
          _ = cached.modify { current in 
              var current = current
              current["premium_lock"] = image
              return current
          }
          return image
      }
  }
  public var premium_lock_gray: CGImage {
      if let image = cached.with({ $0["premium_lock_gray"] }) {
          return image
      } else {
          let image = _premium_lock_gray()
          _ = cached.modify { current in 
              var current = current
              current["premium_lock_gray"] = image
              return current
          }
          return image
      }
  }
  public var premium_plus: CGImage {
      if let image = cached.with({ $0["premium_plus"] }) {
          return image
      } else {
          let image = _premium_plus()
          _ = cached.modify { current in 
              var current = current
              current["premium_plus"] = image
              return current
          }
          return image
      }
  }
  public var premium_account: CGImage {
      if let image = cached.with({ $0["premium_account"] }) {
          return image
      } else {
          let image = _premium_account()
          _ = cached.modify { current in 
              var current = current
              current["premium_account"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_active: CGImage {
      if let image = cached.with({ $0["premium_account_active"] }) {
          return image
      } else {
          let image = _premium_account_active()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_active"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_rev: CGImage {
      if let image = cached.with({ $0["premium_account_rev"] }) {
          return image
      } else {
          let image = _premium_account_rev()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_rev"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_rev_active: CGImage {
      if let image = cached.with({ $0["premium_account_rev_active"] }) {
          return image
      } else {
          let image = _premium_account_rev_active()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_rev_active"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_small: CGImage {
      if let image = cached.with({ $0["premium_account_small"] }) {
          return image
      } else {
          let image = _premium_account_small()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_small"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_small_active: CGImage {
      if let image = cached.with({ $0["premium_account_small_active"] }) {
          return image
      } else {
          let image = _premium_account_small_active()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_small_active"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_small_rev: CGImage {
      if let image = cached.with({ $0["premium_account_small_rev"] }) {
          return image
      } else {
          let image = _premium_account_small_rev()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_small_rev"] = image
              return current
          }
          return image
      }
  }
  public var premium_account_small_rev_active: CGImage {
      if let image = cached.with({ $0["premium_account_small_rev_active"] }) {
          return image
      } else {
          let image = _premium_account_small_rev_active()
          _ = cached.modify { current in 
              var current = current
              current["premium_account_small_rev_active"] = image
              return current
          }
          return image
      }
  }
  public var premium_reaction_lock: CGImage {
      if let image = cached.with({ $0["premium_reaction_lock"] }) {
          return image
      } else {
          let image = _premium_reaction_lock()
          _ = cached.modify { current in 
              var current = current
              current["premium_reaction_lock"] = image
              return current
          }
          return image
      }
  }
  public var premium_boarding_feature_next: CGImage {
      if let image = cached.with({ $0["premium_boarding_feature_next"] }) {
          return image
      } else {
          let image = _premium_boarding_feature_next()
          _ = cached.modify { current in 
              var current = current
              current["premium_boarding_feature_next"] = image
              return current
          }
          return image
      }
  }
  public var premium_stickers: CGImage {
      if let image = cached.with({ $0["premium_stickers"] }) {
          return image
      } else {
          let image = _premium_stickers()
          _ = cached.modify { current in 
              var current = current
              current["premium_stickers"] = image
              return current
          }
          return image
      }
  }
  public var premium_emoji_lock: CGImage {
      if let image = cached.with({ $0["premium_emoji_lock"] }) {
          return image
      } else {
          let image = _premium_emoji_lock()
          _ = cached.modify { current in 
              var current = current
              current["premium_emoji_lock"] = image
              return current
          }
          return image
      }
  }
  public var account_add_account: CGImage {
      if let image = cached.with({ $0["account_add_account"] }) {
          return image
      } else {
          let image = _account_add_account()
          _ = cached.modify { current in 
              var current = current
              current["account_add_account"] = image
              return current
          }
          return image
      }
  }
  public var account_set_status: CGImage {
      if let image = cached.with({ $0["account_set_status"] }) {
          return image
      } else {
          let image = _account_set_status()
          _ = cached.modify { current in 
              var current = current
              current["account_set_status"] = image
              return current
          }
          return image
      }
  }
  public var account_change_status: CGImage {
      if let image = cached.with({ $0["account_change_status"] }) {
          return image
      } else {
          let image = _account_change_status()
          _ = cached.modify { current in 
              var current = current
              current["account_change_status"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_red: CGImage {
      if let image = cached.with({ $0["chat_premium_status_red"] }) {
          return image
      } else {
          let image = _chat_premium_status_red()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_red"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_orange: CGImage {
      if let image = cached.with({ $0["chat_premium_status_orange"] }) {
          return image
      } else {
          let image = _chat_premium_status_orange()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_orange"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_violet: CGImage {
      if let image = cached.with({ $0["chat_premium_status_violet"] }) {
          return image
      } else {
          let image = _chat_premium_status_violet()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_violet"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_green: CGImage {
      if let image = cached.with({ $0["chat_premium_status_green"] }) {
          return image
      } else {
          let image = _chat_premium_status_green()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_green"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_cyan: CGImage {
      if let image = cached.with({ $0["chat_premium_status_cyan"] }) {
          return image
      } else {
          let image = _chat_premium_status_cyan()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_cyan"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_light_blue: CGImage {
      if let image = cached.with({ $0["chat_premium_status_light_blue"] }) {
          return image
      } else {
          let image = _chat_premium_status_light_blue()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_light_blue"] = image
              return current
          }
          return image
      }
  }
  public var chat_premium_status_blue: CGImage {
      if let image = cached.with({ $0["chat_premium_status_blue"] }) {
          return image
      } else {
          let image = _chat_premium_status_blue()
          _ = cached.modify { current in 
              var current = current
              current["chat_premium_status_blue"] = image
              return current
          }
          return image
      }
  }
  public var extend_content_lock: CGImage {
      if let image = cached.with({ $0["extend_content_lock"] }) {
          return image
      } else {
          let image = _extend_content_lock()
          _ = cached.modify { current in 
              var current = current
              current["extend_content_lock"] = image
              return current
          }
          return image
      }
  }
  public var chatlist_forum_closed_topic: CGImage {
      if let image = cached.with({ $0["chatlist_forum_closed_topic"] }) {
          return image
      } else {
          let image = _chatlist_forum_closed_topic()
          _ = cached.modify { current in 
              var current = current
              current["chatlist_forum_closed_topic"] = image
              return current
          }
          return image
      }
  }
  public var chatlist_forum_closed_topic_active: CGImage {
      if let image = cached.with({ $0["chatlist_forum_closed_topic_active"] }) {
          return image
      } else {
          let image = _chatlist_forum_closed_topic_active()
          _ = cached.modify { current in 
              var current = current
              current["chatlist_forum_closed_topic_active"] = image
              return current
          }
          return image
      }
  }
  public var chatlist_arrow: CGImage {
      if let image = cached.with({ $0["chatlist_arrow"] }) {
          return image
      } else {
          let image = _chatlist_arrow()
          _ = cached.modify { current in 
              var current = current
              current["chatlist_arrow"] = image
              return current
          }
          return image
      }
  }
  public var chatlist_arrow_active: CGImage {
      if let image = cached.with({ $0["chatlist_arrow_active"] }) {
          return image
      } else {
          let image = _chatlist_arrow_active()
          _ = cached.modify { current in 
              var current = current
              current["chatlist_arrow_active"] = image
              return current
          }
          return image
      }
  }
  public var dialog_auto_delete: CGImage {
      if let image = cached.with({ $0["dialog_auto_delete"] }) {
          return image
      } else {
          let image = _dialog_auto_delete()
          _ = cached.modify { current in 
              var current = current
              current["dialog_auto_delete"] = image
              return current
          }
          return image
      }
  }
  public var contact_set_photo: CGImage {
      if let image = cached.with({ $0["contact_set_photo"] }) {
          return image
      } else {
          let image = _contact_set_photo()
          _ = cached.modify { current in 
              var current = current
              current["contact_set_photo"] = image
              return current
          }
          return image
      }
  }
  public var contact_suggest_photo: CGImage {
      if let image = cached.with({ $0["contact_suggest_photo"] }) {
          return image
      } else {
          let image = _contact_suggest_photo()
          _ = cached.modify { current in 
              var current = current
              current["contact_suggest_photo"] = image
              return current
          }
          return image
      }
  }
  public var send_media_spoiler: CGImage {
      if let image = cached.with({ $0["send_media_spoiler"] }) {
          return image
      } else {
          let image = _send_media_spoiler()
          _ = cached.modify { current in 
              var current = current
              current["send_media_spoiler"] = image
              return current
          }
          return image
      }
  }
  public var general_delete: CGImage {
      if let image = cached.with({ $0["general_delete"] }) {
          return image
      } else {
          let image = _general_delete()
          _ = cached.modify { current in 
              var current = current
              current["general_delete"] = image
              return current
          }
          return image
      }
  }
  public var storage_music_play: CGImage {
      if let image = cached.with({ $0["storage_music_play"] }) {
          return image
      } else {
          let image = _storage_music_play()
          _ = cached.modify { current in 
              var current = current
              current["storage_music_play"] = image
              return current
          }
          return image
      }
  }
  public var storage_music_pause: CGImage {
      if let image = cached.with({ $0["storage_music_pause"] }) {
          return image
      } else {
          let image = _storage_music_pause()
          _ = cached.modify { current in 
              var current = current
              current["storage_music_pause"] = image
              return current
          }
          return image
      }
  }
  public var storage_media_play: CGImage {
      if let image = cached.with({ $0["storage_media_play"] }) {
          return image
      } else {
          let image = _storage_media_play()
          _ = cached.modify { current in 
              var current = current
              current["storage_media_play"] = image
              return current
          }
          return image
      }
  }
  public var general_chevron_up: CGImage {
      if let image = cached.with({ $0["general_chevron_up"] }) {
          return image
      } else {
          let image = _general_chevron_up()
          _ = cached.modify { current in 
              var current = current
              current["general_chevron_up"] = image
              return current
          }
          return image
      }
  }
  public var general_chevron_down: CGImage {
      if let image = cached.with({ $0["general_chevron_down"] }) {
          return image
      } else {
          let image = _general_chevron_down()
          _ = cached.modify { current in 
              var current = current
              current["general_chevron_down"] = image
              return current
          }
          return image
      }
  }
  public var account_settings_set_password: CGImage {
      if let image = cached.with({ $0["account_settings_set_password"] }) {
          return image
      } else {
          let image = _account_settings_set_password()
          _ = cached.modify { current in 
              var current = current
              current["account_settings_set_password"] = image
              return current
          }
          return image
      }
  }
  public var select_peer_create_channel: CGImage {
      if let image = cached.with({ $0["select_peer_create_channel"] }) {
          return image
      } else {
          let image = _select_peer_create_channel()
          _ = cached.modify { current in 
              var current = current
              current["select_peer_create_channel"] = image
              return current
          }
          return image
      }
  }
  public var select_peer_create_group: CGImage {
      if let image = cached.with({ $0["select_peer_create_group"] }) {
          return image
      } else {
          let image = _select_peer_create_group()
          _ = cached.modify { current in 
              var current = current
              current["select_peer_create_group"] = image
              return current
          }
          return image
      }
  }
  public var chat_translate: CGImage {
      if let image = cached.with({ $0["chat_translate"] }) {
          return image
      } else {
          let image = _chat_translate()
          _ = cached.modify { current in 
              var current = current
              current["chat_translate"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_activities: CGImage {
      if let image = cached.with({ $0["msg_emoji_activities"] }) {
          return image
      } else {
          let image = _msg_emoji_activities()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_activities"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_angry: CGImage {
      if let image = cached.with({ $0["msg_emoji_angry"] }) {
          return image
      } else {
          let image = _msg_emoji_angry()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_angry"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_away: CGImage {
      if let image = cached.with({ $0["msg_emoji_away"] }) {
          return image
      } else {
          let image = _msg_emoji_away()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_away"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_bath: CGImage {
      if let image = cached.with({ $0["msg_emoji_bath"] }) {
          return image
      } else {
          let image = _msg_emoji_bath()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_bath"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_busy: CGImage {
      if let image = cached.with({ $0["msg_emoji_busy"] }) {
          return image
      } else {
          let image = _msg_emoji_busy()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_busy"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_dislike: CGImage {
      if let image = cached.with({ $0["msg_emoji_dislike"] }) {
          return image
      } else {
          let image = _msg_emoji_dislike()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_dislike"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_food: CGImage {
      if let image = cached.with({ $0["msg_emoji_food"] }) {
          return image
      } else {
          let image = _msg_emoji_food()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_food"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_haha: CGImage {
      if let image = cached.with({ $0["msg_emoji_haha"] }) {
          return image
      } else {
          let image = _msg_emoji_haha()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_haha"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_happy: CGImage {
      if let image = cached.with({ $0["msg_emoji_happy"] }) {
          return image
      } else {
          let image = _msg_emoji_happy()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_happy"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_heart: CGImage {
      if let image = cached.with({ $0["msg_emoji_heart"] }) {
          return image
      } else {
          let image = _msg_emoji_heart()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_heart"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_hi2: CGImage {
      if let image = cached.with({ $0["msg_emoji_hi2"] }) {
          return image
      } else {
          let image = _msg_emoji_hi2()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_hi2"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_home: CGImage {
      if let image = cached.with({ $0["msg_emoji_home"] }) {
          return image
      } else {
          let image = _msg_emoji_home()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_home"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_like: CGImage {
      if let image = cached.with({ $0["msg_emoji_like"] }) {
          return image
      } else {
          let image = _msg_emoji_like()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_like"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_neutral: CGImage {
      if let image = cached.with({ $0["msg_emoji_neutral"] }) {
          return image
      } else {
          let image = _msg_emoji_neutral()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_neutral"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_omg: CGImage {
      if let image = cached.with({ $0["msg_emoji_omg"] }) {
          return image
      } else {
          let image = _msg_emoji_omg()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_omg"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_party: CGImage {
      if let image = cached.with({ $0["msg_emoji_party"] }) {
          return image
      } else {
          let image = _msg_emoji_party()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_party"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_recent: CGImage {
      if let image = cached.with({ $0["msg_emoji_recent"] }) {
          return image
      } else {
          let image = _msg_emoji_recent()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_recent"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_sad: CGImage {
      if let image = cached.with({ $0["msg_emoji_sad"] }) {
          return image
      } else {
          let image = _msg_emoji_sad()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_sad"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_sleep: CGImage {
      if let image = cached.with({ $0["msg_emoji_sleep"] }) {
          return image
      } else {
          let image = _msg_emoji_sleep()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_sleep"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_study: CGImage {
      if let image = cached.with({ $0["msg_emoji_study"] }) {
          return image
      } else {
          let image = _msg_emoji_study()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_study"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_tongue: CGImage {
      if let image = cached.with({ $0["msg_emoji_tongue"] }) {
          return image
      } else {
          let image = _msg_emoji_tongue()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_tongue"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_vacation: CGImage {
      if let image = cached.with({ $0["msg_emoji_vacation"] }) {
          return image
      } else {
          let image = _msg_emoji_vacation()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_vacation"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_what: CGImage {
      if let image = cached.with({ $0["msg_emoji_what"] }) {
          return image
      } else {
          let image = _msg_emoji_what()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_what"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_work: CGImage {
      if let image = cached.with({ $0["msg_emoji_work"] }) {
          return image
      } else {
          let image = _msg_emoji_work()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_work"] = image
              return current
          }
          return image
      }
  }
  public var msg_emoji_premium: CGImage {
      if let image = cached.with({ $0["msg_emoji_premium"] }) {
          return image
      } else {
          let image = _msg_emoji_premium()
          _ = cached.modify { current in 
              var current = current
              current["msg_emoji_premium"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_archive: CGImage {
      if let image = cached.with({ $0["installed_stickers_archive"] }) {
          return image
      } else {
          let image = _installed_stickers_archive()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_archive"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_custom_emoji: CGImage {
      if let image = cached.with({ $0["installed_stickers_custom_emoji"] }) {
          return image
      } else {
          let image = _installed_stickers_custom_emoji()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_custom_emoji"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_dynamic_order: CGImage {
      if let image = cached.with({ $0["installed_stickers_dynamic_order"] }) {
          return image
      } else {
          let image = _installed_stickers_dynamic_order()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_dynamic_order"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_loop: CGImage {
      if let image = cached.with({ $0["installed_stickers_loop"] }) {
          return image
      } else {
          let image = _installed_stickers_loop()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_loop"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_reactions: CGImage {
      if let image = cached.with({ $0["installed_stickers_reactions"] }) {
          return image
      } else {
          let image = _installed_stickers_reactions()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_reactions"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_suggest: CGImage {
      if let image = cached.with({ $0["installed_stickers_suggest"] }) {
          return image
      } else {
          let image = _installed_stickers_suggest()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_suggest"] = image
              return current
          }
          return image
      }
  }
  public var installed_stickers_trending: CGImage {
      if let image = cached.with({ $0["installed_stickers_trending"] }) {
          return image
      } else {
          let image = _installed_stickers_trending()
          _ = cached.modify { current in 
              var current = current
              current["installed_stickers_trending"] = image
              return current
          }
          return image
      }
  }
  public var folder_invite_link: CGImage {
      if let image = cached.with({ $0["folder_invite_link"] }) {
          return image
      } else {
          let image = _folder_invite_link()
          _ = cached.modify { current in 
              var current = current
              current["folder_invite_link"] = image
              return current
          }
          return image
      }
  }
  public var folder_invite_link_revoked: CGImage {
      if let image = cached.with({ $0["folder_invite_link_revoked"] }) {
          return image
      } else {
          let image = _folder_invite_link_revoked()
          _ = cached.modify { current in 
              var current = current
              current["folder_invite_link_revoked"] = image
              return current
          }
          return image
      }
  }
  public var folders_sidebar_edit: CGImage {
      if let image = cached.with({ $0["folders_sidebar_edit"] }) {
          return image
      } else {
          let image = _folders_sidebar_edit()
          _ = cached.modify { current in 
              var current = current
              current["folders_sidebar_edit"] = image
              return current
          }
          return image
      }
  }
  public var folders_sidebar_edit_active: CGImage {
      if let image = cached.with({ $0["folders_sidebar_edit_active"] }) {
          return image
      } else {
          let image = _folders_sidebar_edit_active()
          _ = cached.modify { current in 
              var current = current
              current["folders_sidebar_edit_active"] = image
              return current
          }
          return image
      }
  }
  public var story_unseen: CGImage {
      if let image = cached.with({ $0["story_unseen"] }) {
          return image
      } else {
          let image = _story_unseen()
          _ = cached.modify { current in 
              var current = current
              current["story_unseen"] = image
              return current
          }
          return image
      }
  }
  public var story_seen: CGImage {
      if let image = cached.with({ $0["story_seen"] }) {
          return image
      } else {
          let image = _story_seen()
          _ = cached.modify { current in 
              var current = current
              current["story_seen"] = image
              return current
          }
          return image
      }
  }
  public var story_selected: CGImage {
      if let image = cached.with({ $0["story_selected"] }) {
          return image
      } else {
          let image = _story_selected()
          _ = cached.modify { current in 
              var current = current
              current["story_selected"] = image
              return current
          }
          return image
      }
  }
  public var story_unseen_chat: CGImage {
      if let image = cached.with({ $0["story_unseen_chat"] }) {
          return image
      } else {
          let image = _story_unseen_chat()
          _ = cached.modify { current in 
              var current = current
              current["story_unseen_chat"] = image
              return current
          }
          return image
      }
  }
  public var story_seen_chat: CGImage {
      if let image = cached.with({ $0["story_seen_chat"] }) {
          return image
      } else {
          let image = _story_seen_chat()
          _ = cached.modify { current in 
              var current = current
              current["story_seen_chat"] = image
              return current
          }
          return image
      }
  }
  public var story_unseen_profile: CGImage {
      if let image = cached.with({ $0["story_unseen_profile"] }) {
          return image
      } else {
          let image = _story_unseen_profile()
          _ = cached.modify { current in 
              var current = current
              current["story_unseen_profile"] = image
              return current
          }
          return image
      }
  }
  public var story_seen_profile: CGImage {
      if let image = cached.with({ $0["story_seen_profile"] }) {
          return image
      } else {
          let image = _story_seen_profile()
          _ = cached.modify { current in 
              var current = current
              current["story_seen_profile"] = image
              return current
          }
          return image
      }
  }
  public var story_view_read: CGImage {
      if let image = cached.with({ $0["story_view_read"] }) {
          return image
      } else {
          let image = _story_view_read()
          _ = cached.modify { current in 
              var current = current
              current["story_view_read"] = image
              return current
          }
          return image
      }
  }
  public var story_view_reaction: CGImage {
      if let image = cached.with({ $0["story_view_reaction"] }) {
          return image
      } else {
          let image = _story_view_reaction()
          _ = cached.modify { current in 
              var current = current
              current["story_view_reaction"] = image
              return current
          }
          return image
      }
  }
  public var story_chatlist_reply: CGImage {
      if let image = cached.with({ $0["story_chatlist_reply"] }) {
          return image
      } else {
          let image = _story_chatlist_reply()
          _ = cached.modify { current in 
              var current = current
              current["story_chatlist_reply"] = image
              return current
          }
          return image
      }
  }
  public var story_chatlist_reply_active: CGImage {
      if let image = cached.with({ $0["story_chatlist_reply_active"] }) {
          return image
      } else {
          let image = _story_chatlist_reply_active()
          _ = cached.modify { current in 
              var current = current
              current["story_chatlist_reply_active"] = image
              return current
          }
          return image
      }
  }
  public var message_story_expired: CGImage {
      if let image = cached.with({ $0["message_story_expired"] }) {
          return image
      } else {
          let image = _message_story_expired()
          _ = cached.modify { current in 
              var current = current
              current["message_story_expired"] = image
              return current
          }
          return image
      }
  }
  public var message_story_expired_bubble_incoming: CGImage {
      if let image = cached.with({ $0["message_story_expired_bubble_incoming"] }) {
          return image
      } else {
          let image = _message_story_expired_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["message_story_expired_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var message_story_expired_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["message_story_expired_bubble_outgoing"] }) {
          return image
      } else {
          let image = _message_story_expired_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["message_story_expired_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_accent: CGImage {
      if let image = cached.with({ $0["message_quote_accent"] }) {
          return image
      } else {
          let image = _message_quote_accent()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_accent"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_red: CGImage {
      if let image = cached.with({ $0["message_quote_red"] }) {
          return image
      } else {
          let image = _message_quote_red()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_red"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_orange: CGImage {
      if let image = cached.with({ $0["message_quote_orange"] }) {
          return image
      } else {
          let image = _message_quote_orange()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_orange"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_violet: CGImage {
      if let image = cached.with({ $0["message_quote_violet"] }) {
          return image
      } else {
          let image = _message_quote_violet()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_violet"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_green: CGImage {
      if let image = cached.with({ $0["message_quote_green"] }) {
          return image
      } else {
          let image = _message_quote_green()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_green"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_cyan: CGImage {
      if let image = cached.with({ $0["message_quote_cyan"] }) {
          return image
      } else {
          let image = _message_quote_cyan()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_cyan"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_blue: CGImage {
      if let image = cached.with({ $0["message_quote_blue"] }) {
          return image
      } else {
          let image = _message_quote_blue()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_blue"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_pink: CGImage {
      if let image = cached.with({ $0["message_quote_pink"] }) {
          return image
      } else {
          let image = _message_quote_pink()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_pink"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_bubble_incoming: CGImage {
      if let image = cached.with({ $0["message_quote_bubble_incoming"] }) {
          return image
      } else {
          let image = _message_quote_bubble_incoming()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_bubble_incoming"] = image
              return current
          }
          return image
      }
  }
  public var message_quote_bubble_outgoing: CGImage {
      if let image = cached.with({ $0["message_quote_bubble_outgoing"] }) {
          return image
      } else {
          let image = _message_quote_bubble_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["message_quote_bubble_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var channel_stats_likes: CGImage {
      if let image = cached.with({ $0["channel_stats_likes"] }) {
          return image
      } else {
          let image = _channel_stats_likes()
          _ = cached.modify { current in 
              var current = current
              current["channel_stats_likes"] = image
              return current
          }
          return image
      }
  }
  public var channel_stats_shares: CGImage {
      if let image = cached.with({ $0["channel_stats_shares"] }) {
          return image
      } else {
          let image = _channel_stats_shares()
          _ = cached.modify { current in 
              var current = current
              current["channel_stats_shares"] = image
              return current
          }
          return image
      }
  }
  public var story_repost_from_white: CGImage {
      if let image = cached.with({ $0["story_repost_from_white"] }) {
          return image
      } else {
          let image = _story_repost_from_white()
          _ = cached.modify { current in 
              var current = current
              current["story_repost_from_white"] = image
              return current
          }
          return image
      }
  }
  public var story_repost_from_green: CGImage {
      if let image = cached.with({ $0["story_repost_from_green"] }) {
          return image
      } else {
          let image = _story_repost_from_green()
          _ = cached.modify { current in 
              var current = current
              current["story_repost_from_green"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_background: CGImage {
      if let image = cached.with({ $0["channel_feature_background"] }) {
          return image
      } else {
          let image = _channel_feature_background()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_background"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_background_photo: CGImage {
      if let image = cached.with({ $0["channel_feature_background_photo"] }) {
          return image
      } else {
          let image = _channel_feature_background_photo()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_background_photo"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_cover_color: CGImage {
      if let image = cached.with({ $0["channel_feature_cover_color"] }) {
          return image
      } else {
          let image = _channel_feature_cover_color()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_cover_color"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_cover_icon: CGImage {
      if let image = cached.with({ $0["channel_feature_cover_icon"] }) {
          return image
      } else {
          let image = _channel_feature_cover_icon()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_cover_icon"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_link_color: CGImage {
      if let image = cached.with({ $0["channel_feature_link_color"] }) {
          return image
      } else {
          let image = _channel_feature_link_color()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_link_color"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_link_icon: CGImage {
      if let image = cached.with({ $0["channel_feature_link_icon"] }) {
          return image
      } else {
          let image = _channel_feature_link_icon()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_link_icon"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_name_color: CGImage {
      if let image = cached.with({ $0["channel_feature_name_color"] }) {
          return image
      } else {
          let image = _channel_feature_name_color()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_name_color"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_reaction: CGImage {
      if let image = cached.with({ $0["channel_feature_reaction"] }) {
          return image
      } else {
          let image = _channel_feature_reaction()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_reaction"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_status: CGImage {
      if let image = cached.with({ $0["channel_feature_status"] }) {
          return image
      } else {
          let image = _channel_feature_status()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_status"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_stories: CGImage {
      if let image = cached.with({ $0["channel_feature_stories"] }) {
          return image
      } else {
          let image = _channel_feature_stories()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_stories"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_emoji_pack: CGImage {
      if let image = cached.with({ $0["channel_feature_emoji_pack"] }) {
          return image
      } else {
          let image = _channel_feature_emoji_pack()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_emoji_pack"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_voice_to_text: CGImage {
      if let image = cached.with({ $0["channel_feature_voice_to_text"] }) {
          return image
      } else {
          let image = _channel_feature_voice_to_text()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_voice_to_text"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_no_ads: CGImage {
      if let image = cached.with({ $0["channel_feature_no_ads"] }) {
          return image
      } else {
          let image = _channel_feature_no_ads()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_no_ads"] = image
              return current
          }
          return image
      }
  }
  public var channel_feature_autotranslate: CGImage {
      if let image = cached.with({ $0["channel_feature_autotranslate"] }) {
          return image
      } else {
          let image = _channel_feature_autotranslate()
          _ = cached.modify { current in 
              var current = current
              current["channel_feature_autotranslate"] = image
              return current
          }
          return image
      }
  }
  public var chat_hidden_author: CGImage {
      if let image = cached.with({ $0["chat_hidden_author"] }) {
          return image
      } else {
          let image = _chat_hidden_author()
          _ = cached.modify { current in 
              var current = current
              current["chat_hidden_author"] = image
              return current
          }
          return image
      }
  }
  public var chat_my_notes: CGImage {
      if let image = cached.with({ $0["chat_my_notes"] }) {
          return image
      } else {
          let image = _chat_my_notes()
          _ = cached.modify { current in 
              var current = current
              current["chat_my_notes"] = image
              return current
          }
          return image
      }
  }
  public var premium_required_forward: CGImage {
      if let image = cached.with({ $0["premium_required_forward"] }) {
          return image
      } else {
          let image = _premium_required_forward()
          _ = cached.modify { current in 
              var current = current
              current["premium_required_forward"] = image
              return current
          }
          return image
      }
  }
  public var create_new_message_general: CGImage {
      if let image = cached.with({ $0["create_new_message_general"] }) {
          return image
      } else {
          let image = _create_new_message_general()
          _ = cached.modify { current in 
              var current = current
              current["create_new_message_general"] = image
              return current
          }
          return image
      }
  }
  public var bot_manager_settings: CGImage {
      if let image = cached.with({ $0["bot_manager_settings"] }) {
          return image
      } else {
          let image = _bot_manager_settings()
          _ = cached.modify { current in 
              var current = current
              current["bot_manager_settings"] = image
              return current
          }
          return image
      }
  }
  public var preview_text_down: CGImage {
      if let image = cached.with({ $0["preview_text_down"] }) {
          return image
      } else {
          let image = _preview_text_down()
          _ = cached.modify { current in 
              var current = current
              current["preview_text_down"] = image
              return current
          }
          return image
      }
  }
  public var preview_text_up: CGImage {
      if let image = cached.with({ $0["preview_text_up"] }) {
          return image
      } else {
          let image = _preview_text_up()
          _ = cached.modify { current in 
              var current = current
              current["preview_text_up"] = image
              return current
          }
          return image
      }
  }
  public var avatar_star_badge: CGImage {
      if let image = cached.with({ $0["avatar_star_badge"] }) {
          return image
      } else {
          let image = _avatar_star_badge()
          _ = cached.modify { current in 
              var current = current
              current["avatar_star_badge"] = image
              return current
          }
          return image
      }
  }
  public var avatar_star_badge_active: CGImage {
      if let image = cached.with({ $0["avatar_star_badge_active"] }) {
          return image
      } else {
          let image = _avatar_star_badge_active()
          _ = cached.modify { current in 
              var current = current
              current["avatar_star_badge_active"] = image
              return current
          }
          return image
      }
  }
  public var avatar_star_badge_gray: CGImage {
      if let image = cached.with({ $0["avatar_star_badge_gray"] }) {
          return image
      } else {
          let image = _avatar_star_badge_gray()
          _ = cached.modify { current in 
              var current = current
              current["avatar_star_badge_gray"] = image
              return current
          }
          return image
      }
  }
  public var avatar_star_badge_large_gray: CGImage {
      if let image = cached.with({ $0["avatar_star_badge_large_gray"] }) {
          return image
      } else {
          let image = _avatar_star_badge_large_gray()
          _ = cached.modify { current in 
              var current = current
              current["avatar_star_badge_large_gray"] = image
              return current
          }
          return image
      }
  }
  public var chatlist_apps: CGImage {
      if let image = cached.with({ $0["chatlist_apps"] }) {
          return image
      } else {
          let image = _chatlist_apps()
          _ = cached.modify { current in 
              var current = current
              current["chatlist_apps"] = image
              return current
          }
          return image
      }
  }
  public var chat_input_channel_gift: CGImage {
      if let image = cached.with({ $0["chat_input_channel_gift"] }) {
          return image
      } else {
          let image = _chat_input_channel_gift()
          _ = cached.modify { current in 
              var current = current
              current["chat_input_channel_gift"] = image
              return current
          }
          return image
      }
  }
  public var chat_input_suggest_message: CGImage {
      if let image = cached.with({ $0["chat_input_suggest_message"] }) {
          return image
      } else {
          let image = _chat_input_suggest_message()
          _ = cached.modify { current in 
              var current = current
              current["chat_input_suggest_message"] = image
              return current
          }
          return image
      }
  }
  public var chat_input_send_gift: CGImage {
      if let image = cached.with({ $0["chat_input_send_gift"] }) {
          return image
      } else {
          let image = _chat_input_send_gift()
          _ = cached.modify { current in 
              var current = current
              current["chat_input_send_gift"] = image
              return current
          }
          return image
      }
  }
  public var chat_input_suggest_post: CGImage {
      if let image = cached.with({ $0["chat_input_suggest_post"] }) {
          return image
      } else {
          let image = _chat_input_suggest_post()
          _ = cached.modify { current in 
              var current = current
              current["chat_input_suggest_post"] = image
              return current
          }
          return image
      }
  }
  public var todo_selection: CGImage {
      if let image = cached.with({ $0["todo_selection"] }) {
          return image
      } else {
          let image = _todo_selection()
          _ = cached.modify { current in 
              var current = current
              current["todo_selection"] = image
              return current
          }
          return image
      }
  }
  public var todo_selected: CGImage {
      if let image = cached.with({ $0["todo_selected"] }) {
          return image
      } else {
          let image = _todo_selected()
          _ = cached.modify { current in 
              var current = current
              current["todo_selected"] = image
              return current
          }
          return image
      }
  }
  public var todo_selection_other_incoming: CGImage {
      if let image = cached.with({ $0["todo_selection_other_incoming"] }) {
          return image
      } else {
          let image = _todo_selection_other_incoming()
          _ = cached.modify { current in 
              var current = current
              current["todo_selection_other_incoming"] = image
              return current
          }
          return image
      }
  }
  public var todo_selection_other_outgoing: CGImage {
      if let image = cached.with({ $0["todo_selection_other_outgoing"] }) {
          return image
      } else {
          let image = _todo_selection_other_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["todo_selection_other_outgoing"] = image
              return current
          }
          return image
      }
  }
  public var todo_selected_other_incoming: CGImage {
      if let image = cached.with({ $0["todo_selected_other_incoming"] }) {
          return image
      } else {
          let image = _todo_selected_other_incoming()
          _ = cached.modify { current in 
              var current = current
              current["todo_selected_other_incoming"] = image
              return current
          }
          return image
      }
  }
  public var todo_selected_other_outgoing: CGImage {
      if let image = cached.with({ $0["todo_selected_other_outgoing"] }) {
          return image
      } else {
          let image = _todo_selected_other_outgoing()
          _ = cached.modify { current in 
              var current = current
              current["todo_selected_other_outgoing"] = image
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
  private let _chatCallActive: ()->CGImage
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
  private let _chatFallbackVideoCall: ()->CGImage
  private let _chatFallbackVideoCallBubble_incoming: ()->CGImage
  private let _chatFallbackVideoCallBubble_outgoing: ()->CGImage
  private let _chatToggleSelected: ()->CGImage
  private let _chatToggleUnselected: ()->CGImage
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
  private let _chatPaidMessageInBubble_incoming: ()->CGImage
  private let _chatPaidMessageInBubble_outgoing: ()->CGImage
  private let _chatPaidMessageOutBubble: ()->CGImage
  private let _chatPaidMessageOverlayBubble: ()->CGImage
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
  private let _chatScrollDown: ()->CGImage
  private let _chatScrollDownActive: ()->CGImage
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
  private let _chatSecretThumbSmall: ()->CGImage
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
  private let _callWindowDeclineSmall: ()->CGImage
  private let _callWindowAccept: ()->CGImage
  private let _callWindowVideo: ()->CGImage
  private let _callWindowVideoActive: ()->CGImage
  private let _callWindowMute: ()->CGImage
  private let _callWindowMuteActive: ()->CGImage
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
  private let _settingsStories: ()->CGImage
  private let _settingsGeneral: ()->CGImage
  private let _settingsLanguage: ()->CGImage
  private let _settingsNotifications: ()->CGImage
  private let _settingsSecurity: ()->CGImage
  private let _settingsStickers: ()->CGImage
  private let _settingsStorage: ()->CGImage
  private let _settingsSessions: ()->CGImage
  private let _settingsProxy: ()->CGImage
  private let _settingsAppearance: ()->CGImage
  private let _settingsPassport: ()->CGImage
  private let _settingsWallet: ()->CGImage
  private let _settingsUpdate: ()->CGImage
  private let _settingsFilters: ()->CGImage
  private let _settingsPremium: ()->CGImage
  private let _settingsGiftPremium: ()->CGImage
  private let _settingsAskQuestionActive: ()->CGImage
  private let _settingsFaqActive: ()->CGImage
  private let _settingsStoriesActive: ()->CGImage
  private let _settingsGeneralActive: ()->CGImage
  private let _settingsLanguageActive: ()->CGImage
  private let _settingsNotificationsActive: ()->CGImage
  private let _settingsSecurityActive: ()->CGImage
  private let _settingsStickersActive: ()->CGImage
  private let _settingsStorageActive: ()->CGImage
  private let _settingsSessionsActive: ()->CGImage
  private let _settingsProxyActive: ()->CGImage
  private let _settingsAppearanceActive: ()->CGImage
  private let _settingsPassportActive: ()->CGImage
  private let _settingsWalletActive: ()->CGImage
  private let _settingsUpdateActive: ()->CGImage
  private let _settingsFiltersActive: ()->CGImage
  private let _settingsProfile: ()->CGImage
  private let _settingsBusiness: ()->CGImage
  private let _settingsBusinessActive: ()->CGImage
  private let _settingsStars: ()->CGImage
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
  private let _chatGroupToggleSelected: ()->CGImage
  private let _chatGroupToggleUnselected: ()->CGImage
  private let _successModalProgress: ()->CGImage
  private let _accentColorSelect: ()->CGImage
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
  private let _galleryRotate: ()->CGImage
  private let _galleryZoomIn: ()->CGImage
  private let _galleryZoomOut: ()->CGImage
  private let _editMessageCurrentPhoto: ()->CGImage
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
  private let _peerInfoRecentActions: ()->CGImage
  private let _peerInfoPermissions: ()->CGImage
  private let _peerInfoBanned: ()->CGImage
  private let _peerInfoMembers: ()->CGImage
  private let _peerInfoStarsBalance: ()->CGImage
  private let _peerInfoBalance: ()->CGImage
  private let _peerInfoTonBalance: ()->CGImage
  private let _peerInfoBotUsername: ()->CGImage
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
  private let _fake: ()->CGImage
  private let _fakeActive: ()->CGImage
  private let _chatFake: ()->CGImage
  private let _chatUnarchive: ()->CGImage
  private let _chatArchive: ()->CGImage
  private let _privacySettings_blocked: ()->CGImage
  private let _privacySettings_activeSessions: ()->CGImage
  private let _privacySettings_passcode: ()->CGImage
  private let _privacySettings_twoStep: ()->CGImage
  private let _privacy_settings_autodelete: ()->CGImage
  private let _deletedAccount: ()->CGImage
  private let _stickerPackSelection: ()->CGImage
  private let _stickerPackSelectionActive: ()->CGImage
  private let _entertainment_Emoji: ()->CGImage
  private let _entertainment_Stickers: ()->CGImage
  private let _entertainment_Gifs: ()->CGImage
  private let _entertainment_Search: ()->CGImage
  private let _entertainment_Settings: ()->CGImage
  private let _entertainment_SearchCancel: ()->CGImage
  private let _entertainment_AnimatedEmoji: ()->CGImage
  private let _scheduledAvatar: ()->CGImage
  private let _scheduledInputAction: ()->CGImage
  private let _verifyDialog: ()->CGImage
  private let _verifyDialogActive: ()->CGImage
  private let _verify_dialog_left: ()->CGImage
  private let _verify_dialog_active_left: ()->CGImage
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
  private let _wallpaper_color_play: ()->CGImage
  private let _login_cap: ()->CGImage
  private let _login_qr_cap: ()->CGImage
  private let _login_qr_empty_cap: ()->CGImage
  private let _chat_failed_scroller: ()->CGImage
  private let _chat_failed_scroller_active: ()->CGImage
  private let _poll_quiz_unselected: ()->CGImage
  private let _poll_selected: ()->CGImage
  private let _poll_selection: ()->CGImage
  private let _poll_selected_correct: ()->CGImage
  private let _poll_selected_incorrect: ()->CGImage
  private let _poll_selected_incoming: ()->CGImage
  private let _poll_selection_incoming: ()->CGImage
  private let _poll_selected_correct_incoming: ()->CGImage
  private let _poll_selected_incorrect_incoming: ()->CGImage
  private let _poll_selected_outgoing: ()->CGImage
  private let _poll_selection_outgoing: ()->CGImage
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
  private let _chat_filter_new_chats: ()->CGImage
  private let _chat_filter_existing_chats: ()->CGImage
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
  private let _profile_video_call: ()->CGImage
  private let _profile_leave: ()->CGImage
  private let _profile_message: ()->CGImage
  private let _profile_more: ()->CGImage
  private let _profile_mute: ()->CGImage
  private let _profile_unmute: ()->CGImage
  private let _profile_search: ()->CGImage
  private let _profile_secret_chat: ()->CGImage
  private let _profile_edit_photo: ()->CGImage
  private let _profile_block: ()->CGImage
  private let _profile_report: ()->CGImage
  private let _profile_share: ()->CGImage
  private let _profile_stats: ()->CGImage
  private let _profile_unblock: ()->CGImage
  private let _profile_translate: ()->CGImage
  private let _profile_join_channel: ()->CGImage
  private let _profile_boost: ()->CGImage
  private let _profile_archive: ()->CGImage
  private let _stats_boost_boost: ()->CGImage
  private let _stats_boost_giveaway: ()->CGImage
  private let _stats_boost_info: ()->CGImage
  private let _chat_quiz_explanation: ()->CGImage
  private let _chat_quiz_explanation_bubble_incoming: ()->CGImage
  private let _chat_quiz_explanation_bubble_outgoing: ()->CGImage
  private let _stickers_add_featured: ()->CGImage
  private let _stickers_add_featured_unread: ()->CGImage
  private let _stickers_add_featured_active: ()->CGImage
  private let _stickers_add_featured_unread_active: ()->CGImage
  private let _stickers_favorite: ()->CGImage
  private let _stickers_favorite_active: ()->CGImage
  private let _channel_info_promo: ()->CGImage
  private let _channel_info_promo_bubble_incoming: ()->CGImage
  private let _channel_info_promo_bubble_outgoing: ()->CGImage
  private let _chat_share_message: ()->CGImage
  private let _chat_goto_message: ()->CGImage
  private let _chat_swipe_reply: ()->CGImage
  private let _chat_like_message: ()->CGImage
  private let _chat_like_message_unlike: ()->CGImage
  private let _chat_like_inside: ()->CGImage
  private let _chat_like_inside_bubble_incoming: ()->CGImage
  private let _chat_like_inside_bubble_outgoing: ()->CGImage
  private let _chat_like_inside_bubble_overlay: ()->CGImage
  private let _chat_like_inside_empty: ()->CGImage
  private let _chat_like_inside_empty_bubble_incoming: ()->CGImage
  private let _chat_like_inside_empty_bubble_outgoing: ()->CGImage
  private let _chat_like_inside_empty_bubble_overlay: ()->CGImage
  private let _gif_trending: ()->CGImage
  private let _gif_trending_active: ()->CGImage
  private let _gif_recent: ()->CGImage
  private let _gif_recent_active: ()->CGImage
  private let _chat_list_thumb_play: ()->CGImage
  private let _call_tooltip_battery_low: ()->CGImage
  private let _call_tooltip_camera_off: ()->CGImage
  private let _call_tooltip_micro_off: ()->CGImage
  private let _call_screen_sharing: ()->CGImage
  private let _call_screen_sharing_active: ()->CGImage
  private let _call_screen_settings: ()->CGImage
  private let _search_filter: ()->CGImage
  private let _search_filter_media: ()->CGImage
  private let _search_filter_files: ()->CGImage
  private let _search_filter_links: ()->CGImage
  private let _search_filter_music: ()->CGImage
  private let _search_filter_downloads: ()->CGImage
  private let _search_filter_add_peer: ()->CGImage
  private let _search_filter_add_peer_active: ()->CGImage
  private let _search_filter_hashtag: ()->CGImage
  private let _search_hashtag_chevron: ()->CGImage
  private let _chat_reply_count_bubble_incoming: ()->CGImage
  private let _chat_reply_count_bubble_outgoing: ()->CGImage
  private let _chat_reply_count: ()->CGImage
  private let _chat_reply_count_overlay: ()->CGImage
  private let _channel_comments_bubble: ()->CGImage
  private let _channel_comments_bubble_next: ()->CGImage
  private let _channel_comments_list: ()->CGImage
  private let _channel_comments_overlay: ()->CGImage
  private let _chat_replies_avatar: ()->CGImage
  private let _group_selection_foreground: ()->CGImage
  private let _group_selection_foreground_bubble_incoming: ()->CGImage
  private let _group_selection_foreground_bubble_outgoing: ()->CGImage
  private let _chat_pinned_list: ()->CGImage
  private let _chat_pinned_message: ()->CGImage
  private let _chat_pinned_message_bubble_incoming: ()->CGImage
  private let _chat_pinned_message_bubble_outgoing: ()->CGImage
  private let _chat_pinned_message_overlay_bubble: ()->CGImage
  private let _chat_voicechat_can_unmute: ()->CGImage
  private let _chat_voicechat_cant_unmute: ()->CGImage
  private let _chat_voicechat_unmuted: ()->CGImage
  private let _profile_voice_chat: ()->CGImage
  private let _chat_voice_chat: ()->CGImage
  private let _chat_voice_chat_active: ()->CGImage
  private let _editor_draw: ()->CGImage
  private let _editor_delete: ()->CGImage
  private let _editor_crop: ()->CGImage
  private let _fast_copy_link: ()->CGImage
  private let _profile_channel_sign: ()->CGImage
  private let _profile_channel_type: ()->CGImage
  private let _profile_group_type: ()->CGImage
  private let _profile_group_topics: ()->CGImage
  private let _profile_group_destruct: ()->CGImage
  private let _profile_group_discussion: ()->CGImage
  private let _profile_requests: ()->CGImage
  private let _profile_reactions: ()->CGImage
  private let _profile_channel_color: ()->CGImage
  private let _profile_channel_stats: ()->CGImage
  private let _profile_removed: ()->CGImage
  private let _profile_links: ()->CGImage
  private let _destruct_clear_history: ()->CGImage
  private let _chat_gigagroup_info: ()->CGImage
  private let _playlist_next: ()->CGImage
  private let _playlist_prev: ()->CGImage
  private let _playlist_next_locked: ()->CGImage
  private let _playlist_prev_locked: ()->CGImage
  private let _playlist_random: ()->CGImage
  private let _playlist_order_normal: ()->CGImage
  private let _playlist_order_reversed: ()->CGImage
  private let _playlist_order_random: ()->CGImage
  private let _playlist_repeat_none: ()->CGImage
  private let _playlist_repeat_circle: ()->CGImage
  private let _playlist_repeat_one: ()->CGImage
  private let _audioplayer_next: ()->CGImage
  private let _audioplayer_prev: ()->CGImage
  private let _audioplayer_dismiss: ()->CGImage
  private let _audioplayer_repeat_none: ()->CGImage
  private let _audioplayer_repeat_circle: ()->CGImage
  private let _audioplayer_repeat_one: ()->CGImage
  private let _audioplayer_locked_next: ()->CGImage
  private let _audioplayer_locked_prev: ()->CGImage
  private let _audioplayer_volume: ()->CGImage
  private let _audioplayer_volume_off: ()->CGImage
  private let _audioplayer_speed_x1: ()->CGImage
  private let _audioplayer_speed_x2: ()->CGImage
  private let _audioplayer_list: ()->CGImage
  private let _chat_info_voice_chat: ()->CGImage
  private let _chat_info_create_group: ()->CGImage
  private let _chat_info_change_colors: ()->CGImage
  private let _empty_chat_system: ()->CGImage
  private let _empty_chat_dark: ()->CGImage
  private let _empty_chat_light: ()->CGImage
  private let _empty_chat_system_active: ()->CGImage
  private let _empty_chat_dark_active: ()->CGImage
  private let _empty_chat_light_active: ()->CGImage
  private let _empty_chat_storage_clear: ()->CGImage
  private let _empty_chat_storage_low: ()->CGImage
  private let _empty_chat_storage_medium: ()->CGImage
  private let _empty_chat_storage_high: ()->CGImage
  private let _empty_chat_storage_low_active: ()->CGImage
  private let _empty_chat_storage_medium_active: ()->CGImage
  private let _empty_chat_storage_high_active: ()->CGImage
  private let _empty_chat_stickers_none: ()->CGImage
  private let _empty_chat_stickers_mysets: ()->CGImage
  private let _empty_chat_stickers_allsets: ()->CGImage
  private let _empty_chat_stickers_none_active: ()->CGImage
  private let _empty_chat_stickers_mysets_active: ()->CGImage
  private let _empty_chat_stickers_allsets_active: ()->CGImage
  private let _chat_action_dismiss: ()->CGImage
  private let _chat_action_edit_message: ()->CGImage
  private let _chat_action_forward_message: ()->CGImage
  private let _chat_action_reply_message: ()->CGImage
  private let _chat_action_url_preview: ()->CGImage
  private let _chat_action_menu_update_chat: ()->CGImage
  private let _chat_action_menu_selected: ()->CGImage
  private let _widget_peers_favorite: ()->CGImage
  private let _widget_peers_recent: ()->CGImage
  private let _widget_peers_both: ()->CGImage
  private let _widget_peers_favorite_active: ()->CGImage
  private let _widget_peers_recent_active: ()->CGImage
  private let _widget_peers_both_active: ()->CGImage
  private let _chat_reactions_add: ()->CGImage
  private let _chat_reactions_add_bubble: ()->CGImage
  private let _chat_reactions_add_active: ()->CGImage
  private let _reactions_badge: ()->CGImage
  private let _reactions_badge_active: ()->CGImage
  private let _reactions_badge_archive: ()->CGImage
  private let _reactions_badge_archive_active: ()->CGImage
  private let _reactions_show_more: ()->CGImage
  private let _chat_reactions_badge: ()->CGImage
  private let _chat_reactions_badge_active: ()->CGImage
  private let _gallery_pip_close: ()->CGImage
  private let _gallery_pip_muted: ()->CGImage
  private let _gallery_pip_unmuted: ()->CGImage
  private let _gallery_pip_out: ()->CGImage
  private let _gallery_pip_pause: ()->CGImage
  private let _gallery_pip_play: ()->CGImage
  private let _notification_sound_add: ()->CGImage
  private let _premium_lock: ()->CGImage
  private let _premium_lock_gray: ()->CGImage
  private let _premium_plus: ()->CGImage
  private let _premium_account: ()->CGImage
  private let _premium_account_active: ()->CGImage
  private let _premium_account_rev: ()->CGImage
  private let _premium_account_rev_active: ()->CGImage
  private let _premium_account_small: ()->CGImage
  private let _premium_account_small_active: ()->CGImage
  private let _premium_account_small_rev: ()->CGImage
  private let _premium_account_small_rev_active: ()->CGImage
  private let _premium_reaction_lock: ()->CGImage
  private let _premium_boarding_feature_next: ()->CGImage
  private let _premium_stickers: ()->CGImage
  private let _premium_emoji_lock: ()->CGImage
  private let _account_add_account: ()->CGImage
  private let _account_set_status: ()->CGImage
  private let _account_change_status: ()->CGImage
  private let _chat_premium_status_red: ()->CGImage
  private let _chat_premium_status_orange: ()->CGImage
  private let _chat_premium_status_violet: ()->CGImage
  private let _chat_premium_status_green: ()->CGImage
  private let _chat_premium_status_cyan: ()->CGImage
  private let _chat_premium_status_light_blue: ()->CGImage
  private let _chat_premium_status_blue: ()->CGImage
  private let _extend_content_lock: ()->CGImage
  private let _chatlist_forum_closed_topic: ()->CGImage
  private let _chatlist_forum_closed_topic_active: ()->CGImage
  private let _chatlist_arrow: ()->CGImage
  private let _chatlist_arrow_active: ()->CGImage
  private let _dialog_auto_delete: ()->CGImage
  private let _contact_set_photo: ()->CGImage
  private let _contact_suggest_photo: ()->CGImage
  private let _send_media_spoiler: ()->CGImage
  private let _general_delete: ()->CGImage
  private let _storage_music_play: ()->CGImage
  private let _storage_music_pause: ()->CGImage
  private let _storage_media_play: ()->CGImage
  private let _general_chevron_up: ()->CGImage
  private let _general_chevron_down: ()->CGImage
  private let _account_settings_set_password: ()->CGImage
  private let _select_peer_create_channel: ()->CGImage
  private let _select_peer_create_group: ()->CGImage
  private let _chat_translate: ()->CGImage
  private let _msg_emoji_activities: ()->CGImage
  private let _msg_emoji_angry: ()->CGImage
  private let _msg_emoji_away: ()->CGImage
  private let _msg_emoji_bath: ()->CGImage
  private let _msg_emoji_busy: ()->CGImage
  private let _msg_emoji_dislike: ()->CGImage
  private let _msg_emoji_food: ()->CGImage
  private let _msg_emoji_haha: ()->CGImage
  private let _msg_emoji_happy: ()->CGImage
  private let _msg_emoji_heart: ()->CGImage
  private let _msg_emoji_hi2: ()->CGImage
  private let _msg_emoji_home: ()->CGImage
  private let _msg_emoji_like: ()->CGImage
  private let _msg_emoji_neutral: ()->CGImage
  private let _msg_emoji_omg: ()->CGImage
  private let _msg_emoji_party: ()->CGImage
  private let _msg_emoji_recent: ()->CGImage
  private let _msg_emoji_sad: ()->CGImage
  private let _msg_emoji_sleep: ()->CGImage
  private let _msg_emoji_study: ()->CGImage
  private let _msg_emoji_tongue: ()->CGImage
  private let _msg_emoji_vacation: ()->CGImage
  private let _msg_emoji_what: ()->CGImage
  private let _msg_emoji_work: ()->CGImage
  private let _msg_emoji_premium: ()->CGImage
  private let _installed_stickers_archive: ()->CGImage
  private let _installed_stickers_custom_emoji: ()->CGImage
  private let _installed_stickers_dynamic_order: ()->CGImage
  private let _installed_stickers_loop: ()->CGImage
  private let _installed_stickers_reactions: ()->CGImage
  private let _installed_stickers_suggest: ()->CGImage
  private let _installed_stickers_trending: ()->CGImage
  private let _folder_invite_link: ()->CGImage
  private let _folder_invite_link_revoked: ()->CGImage
  private let _folders_sidebar_edit: ()->CGImage
  private let _folders_sidebar_edit_active: ()->CGImage
  private let _story_unseen: ()->CGImage
  private let _story_seen: ()->CGImage
  private let _story_selected: ()->CGImage
  private let _story_unseen_chat: ()->CGImage
  private let _story_seen_chat: ()->CGImage
  private let _story_unseen_profile: ()->CGImage
  private let _story_seen_profile: ()->CGImage
  private let _story_view_read: ()->CGImage
  private let _story_view_reaction: ()->CGImage
  private let _story_chatlist_reply: ()->CGImage
  private let _story_chatlist_reply_active: ()->CGImage
  private let _message_story_expired: ()->CGImage
  private let _message_story_expired_bubble_incoming: ()->CGImage
  private let _message_story_expired_bubble_outgoing: ()->CGImage
  private let _message_quote_accent: ()->CGImage
  private let _message_quote_red: ()->CGImage
  private let _message_quote_orange: ()->CGImage
  private let _message_quote_violet: ()->CGImage
  private let _message_quote_green: ()->CGImage
  private let _message_quote_cyan: ()->CGImage
  private let _message_quote_blue: ()->CGImage
  private let _message_quote_pink: ()->CGImage
  private let _message_quote_bubble_incoming: ()->CGImage
  private let _message_quote_bubble_outgoing: ()->CGImage
  private let _channel_stats_likes: ()->CGImage
  private let _channel_stats_shares: ()->CGImage
  private let _story_repost_from_white: ()->CGImage
  private let _story_repost_from_green: ()->CGImage
  private let _channel_feature_background: ()->CGImage
  private let _channel_feature_background_photo: ()->CGImage
  private let _channel_feature_cover_color: ()->CGImage
  private let _channel_feature_cover_icon: ()->CGImage
  private let _channel_feature_link_color: ()->CGImage
  private let _channel_feature_link_icon: ()->CGImage
  private let _channel_feature_name_color: ()->CGImage
  private let _channel_feature_reaction: ()->CGImage
  private let _channel_feature_status: ()->CGImage
  private let _channel_feature_stories: ()->CGImage
  private let _channel_feature_emoji_pack: ()->CGImage
  private let _channel_feature_voice_to_text: ()->CGImage
  private let _channel_feature_no_ads: ()->CGImage
  private let _channel_feature_autotranslate: ()->CGImage
  private let _chat_hidden_author: ()->CGImage
  private let _chat_my_notes: ()->CGImage
  private let _premium_required_forward: ()->CGImage
  private let _create_new_message_general: ()->CGImage
  private let _bot_manager_settings: ()->CGImage
  private let _preview_text_down: ()->CGImage
  private let _preview_text_up: ()->CGImage
  private let _avatar_star_badge: ()->CGImage
  private let _avatar_star_badge_active: ()->CGImage
  private let _avatar_star_badge_gray: ()->CGImage
  private let _avatar_star_badge_large_gray: ()->CGImage
  private let _chatlist_apps: ()->CGImage
  private let _chat_input_channel_gift: ()->CGImage
  private let _chat_input_suggest_message: ()->CGImage
  private let _chat_input_send_gift: ()->CGImage
  private let _chat_input_suggest_post: ()->CGImage
  private let _todo_selection: ()->CGImage
  private let _todo_selected: ()->CGImage
  private let _todo_selection_other_incoming: ()->CGImage
  private let _todo_selection_other_outgoing: ()->CGImage
  private let _todo_selected_other_incoming: ()->CGImage
  private let _todo_selected_other_outgoing: ()->CGImage

  public init(
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
      chatCallActive: @escaping()->CGImage,
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
      chatFallbackVideoCall: @escaping()->CGImage,
      chatFallbackVideoCallBubble_incoming: @escaping()->CGImage,
      chatFallbackVideoCallBubble_outgoing: @escaping()->CGImage,
      chatToggleSelected: @escaping()->CGImage,
      chatToggleUnselected: @escaping()->CGImage,
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
      chatPaidMessageInBubble_incoming: @escaping()->CGImage,
      chatPaidMessageInBubble_outgoing: @escaping()->CGImage,
      chatPaidMessageOutBubble: @escaping()->CGImage,
      chatPaidMessageOverlayBubble: @escaping()->CGImage,
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
      chatScrollDown: @escaping()->CGImage,
      chatScrollDownActive: @escaping()->CGImage,
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
      chatSecretThumbSmall: @escaping()->CGImage,
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
      callWindowDeclineSmall: @escaping()->CGImage,
      callWindowAccept: @escaping()->CGImage,
      callWindowVideo: @escaping()->CGImage,
      callWindowVideoActive: @escaping()->CGImage,
      callWindowMute: @escaping()->CGImage,
      callWindowMuteActive: @escaping()->CGImage,
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
      settingsStories: @escaping()->CGImage,
      settingsGeneral: @escaping()->CGImage,
      settingsLanguage: @escaping()->CGImage,
      settingsNotifications: @escaping()->CGImage,
      settingsSecurity: @escaping()->CGImage,
      settingsStickers: @escaping()->CGImage,
      settingsStorage: @escaping()->CGImage,
      settingsSessions: @escaping()->CGImage,
      settingsProxy: @escaping()->CGImage,
      settingsAppearance: @escaping()->CGImage,
      settingsPassport: @escaping()->CGImage,
      settingsWallet: @escaping()->CGImage,
      settingsUpdate: @escaping()->CGImage,
      settingsFilters: @escaping()->CGImage,
      settingsPremium: @escaping()->CGImage,
      settingsGiftPremium: @escaping()->CGImage,
      settingsAskQuestionActive: @escaping()->CGImage,
      settingsFaqActive: @escaping()->CGImage,
      settingsStoriesActive: @escaping()->CGImage,
      settingsGeneralActive: @escaping()->CGImage,
      settingsLanguageActive: @escaping()->CGImage,
      settingsNotificationsActive: @escaping()->CGImage,
      settingsSecurityActive: @escaping()->CGImage,
      settingsStickersActive: @escaping()->CGImage,
      settingsStorageActive: @escaping()->CGImage,
      settingsSessionsActive: @escaping()->CGImage,
      settingsProxyActive: @escaping()->CGImage,
      settingsAppearanceActive: @escaping()->CGImage,
      settingsPassportActive: @escaping()->CGImage,
      settingsWalletActive: @escaping()->CGImage,
      settingsUpdateActive: @escaping()->CGImage,
      settingsFiltersActive: @escaping()->CGImage,
      settingsProfile: @escaping()->CGImage,
      settingsBusiness: @escaping()->CGImage,
      settingsBusinessActive: @escaping()->CGImage,
      settingsStars: @escaping()->CGImage,
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
      chatGroupToggleSelected: @escaping()->CGImage,
      chatGroupToggleUnselected: @escaping()->CGImage,
      successModalProgress: @escaping()->CGImage,
      accentColorSelect: @escaping()->CGImage,
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
      galleryRotate: @escaping()->CGImage,
      galleryZoomIn: @escaping()->CGImage,
      galleryZoomOut: @escaping()->CGImage,
      editMessageCurrentPhoto: @escaping()->CGImage,
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
      peerInfoRecentActions: @escaping()->CGImage,
      peerInfoPermissions: @escaping()->CGImage,
      peerInfoBanned: @escaping()->CGImage,
      peerInfoMembers: @escaping()->CGImage,
      peerInfoStarsBalance: @escaping()->CGImage,
      peerInfoBalance: @escaping()->CGImage,
      peerInfoTonBalance: @escaping()->CGImage,
      peerInfoBotUsername: @escaping()->CGImage,
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
      fake: @escaping()->CGImage,
      fakeActive: @escaping()->CGImage,
      chatFake: @escaping()->CGImage,
      chatUnarchive: @escaping()->CGImage,
      chatArchive: @escaping()->CGImage,
      privacySettings_blocked: @escaping()->CGImage,
      privacySettings_activeSessions: @escaping()->CGImage,
      privacySettings_passcode: @escaping()->CGImage,
      privacySettings_twoStep: @escaping()->CGImage,
      privacy_settings_autodelete: @escaping()->CGImage,
      deletedAccount: @escaping()->CGImage,
      stickerPackSelection: @escaping()->CGImage,
      stickerPackSelectionActive: @escaping()->CGImage,
      entertainment_Emoji: @escaping()->CGImage,
      entertainment_Stickers: @escaping()->CGImage,
      entertainment_Gifs: @escaping()->CGImage,
      entertainment_Search: @escaping()->CGImage,
      entertainment_Settings: @escaping()->CGImage,
      entertainment_SearchCancel: @escaping()->CGImage,
      entertainment_AnimatedEmoji: @escaping()->CGImage,
      scheduledAvatar: @escaping()->CGImage,
      scheduledInputAction: @escaping()->CGImage,
      verifyDialog: @escaping()->CGImage,
      verifyDialogActive: @escaping()->CGImage,
      verify_dialog_left: @escaping()->CGImage,
      verify_dialog_active_left: @escaping()->CGImage,
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
      wallpaper_color_play: @escaping()->CGImage,
      login_cap: @escaping()->CGImage,
      login_qr_cap: @escaping()->CGImage,
      login_qr_empty_cap: @escaping()->CGImage,
      chat_failed_scroller: @escaping()->CGImage,
      chat_failed_scroller_active: @escaping()->CGImage,
      poll_quiz_unselected: @escaping()->CGImage,
      poll_selected: @escaping()->CGImage,
      poll_selection: @escaping()->CGImage,
      poll_selected_correct: @escaping()->CGImage,
      poll_selected_incorrect: @escaping()->CGImage,
      poll_selected_incoming: @escaping()->CGImage,
      poll_selection_incoming: @escaping()->CGImage,
      poll_selected_correct_incoming: @escaping()->CGImage,
      poll_selected_incorrect_incoming: @escaping()->CGImage,
      poll_selected_outgoing: @escaping()->CGImage,
      poll_selection_outgoing: @escaping()->CGImage,
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
      chat_filter_new_chats: @escaping()->CGImage,
      chat_filter_existing_chats: @escaping()->CGImage,
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
      profile_video_call: @escaping()->CGImage,
      profile_leave: @escaping()->CGImage,
      profile_message: @escaping()->CGImage,
      profile_more: @escaping()->CGImage,
      profile_mute: @escaping()->CGImage,
      profile_unmute: @escaping()->CGImage,
      profile_search: @escaping()->CGImage,
      profile_secret_chat: @escaping()->CGImage,
      profile_edit_photo: @escaping()->CGImage,
      profile_block: @escaping()->CGImage,
      profile_report: @escaping()->CGImage,
      profile_share: @escaping()->CGImage,
      profile_stats: @escaping()->CGImage,
      profile_unblock: @escaping()->CGImage,
      profile_translate: @escaping()->CGImage,
      profile_join_channel: @escaping()->CGImage,
      profile_boost: @escaping()->CGImage,
      profile_archive: @escaping()->CGImage,
      stats_boost_boost: @escaping()->CGImage,
      stats_boost_giveaway: @escaping()->CGImage,
      stats_boost_info: @escaping()->CGImage,
      chat_quiz_explanation: @escaping()->CGImage,
      chat_quiz_explanation_bubble_incoming: @escaping()->CGImage,
      chat_quiz_explanation_bubble_outgoing: @escaping()->CGImage,
      stickers_add_featured: @escaping()->CGImage,
      stickers_add_featured_unread: @escaping()->CGImage,
      stickers_add_featured_active: @escaping()->CGImage,
      stickers_add_featured_unread_active: @escaping()->CGImage,
      stickers_favorite: @escaping()->CGImage,
      stickers_favorite_active: @escaping()->CGImage,
      channel_info_promo: @escaping()->CGImage,
      channel_info_promo_bubble_incoming: @escaping()->CGImage,
      channel_info_promo_bubble_outgoing: @escaping()->CGImage,
      chat_share_message: @escaping()->CGImage,
      chat_goto_message: @escaping()->CGImage,
      chat_swipe_reply: @escaping()->CGImage,
      chat_like_message: @escaping()->CGImage,
      chat_like_message_unlike: @escaping()->CGImage,
      chat_like_inside: @escaping()->CGImage,
      chat_like_inside_bubble_incoming: @escaping()->CGImage,
      chat_like_inside_bubble_outgoing: @escaping()->CGImage,
      chat_like_inside_bubble_overlay: @escaping()->CGImage,
      chat_like_inside_empty: @escaping()->CGImage,
      chat_like_inside_empty_bubble_incoming: @escaping()->CGImage,
      chat_like_inside_empty_bubble_outgoing: @escaping()->CGImage,
      chat_like_inside_empty_bubble_overlay: @escaping()->CGImage,
      gif_trending: @escaping()->CGImage,
      gif_trending_active: @escaping()->CGImage,
      gif_recent: @escaping()->CGImage,
      gif_recent_active: @escaping()->CGImage,
      chat_list_thumb_play: @escaping()->CGImage,
      call_tooltip_battery_low: @escaping()->CGImage,
      call_tooltip_camera_off: @escaping()->CGImage,
      call_tooltip_micro_off: @escaping()->CGImage,
      call_screen_sharing: @escaping()->CGImage,
      call_screen_sharing_active: @escaping()->CGImage,
      call_screen_settings: @escaping()->CGImage,
      search_filter: @escaping()->CGImage,
      search_filter_media: @escaping()->CGImage,
      search_filter_files: @escaping()->CGImage,
      search_filter_links: @escaping()->CGImage,
      search_filter_music: @escaping()->CGImage,
      search_filter_downloads: @escaping()->CGImage,
      search_filter_add_peer: @escaping()->CGImage,
      search_filter_add_peer_active: @escaping()->CGImage,
      search_filter_hashtag: @escaping()->CGImage,
      search_hashtag_chevron: @escaping()->CGImage,
      chat_reply_count_bubble_incoming: @escaping()->CGImage,
      chat_reply_count_bubble_outgoing: @escaping()->CGImage,
      chat_reply_count: @escaping()->CGImage,
      chat_reply_count_overlay: @escaping()->CGImage,
      channel_comments_bubble: @escaping()->CGImage,
      channel_comments_bubble_next: @escaping()->CGImage,
      channel_comments_list: @escaping()->CGImage,
      channel_comments_overlay: @escaping()->CGImage,
      chat_replies_avatar: @escaping()->CGImage,
      group_selection_foreground: @escaping()->CGImage,
      group_selection_foreground_bubble_incoming: @escaping()->CGImage,
      group_selection_foreground_bubble_outgoing: @escaping()->CGImage,
      chat_pinned_list: @escaping()->CGImage,
      chat_pinned_message: @escaping()->CGImage,
      chat_pinned_message_bubble_incoming: @escaping()->CGImage,
      chat_pinned_message_bubble_outgoing: @escaping()->CGImage,
      chat_pinned_message_overlay_bubble: @escaping()->CGImage,
      chat_voicechat_can_unmute: @escaping()->CGImage,
      chat_voicechat_cant_unmute: @escaping()->CGImage,
      chat_voicechat_unmuted: @escaping()->CGImage,
      profile_voice_chat: @escaping()->CGImage,
      chat_voice_chat: @escaping()->CGImage,
      chat_voice_chat_active: @escaping()->CGImage,
      editor_draw: @escaping()->CGImage,
      editor_delete: @escaping()->CGImage,
      editor_crop: @escaping()->CGImage,
      fast_copy_link: @escaping()->CGImage,
      profile_channel_sign: @escaping()->CGImage,
      profile_channel_type: @escaping()->CGImage,
      profile_group_type: @escaping()->CGImage,
      profile_group_topics: @escaping()->CGImage,
      profile_group_destruct: @escaping()->CGImage,
      profile_group_discussion: @escaping()->CGImage,
      profile_requests: @escaping()->CGImage,
      profile_reactions: @escaping()->CGImage,
      profile_channel_color: @escaping()->CGImage,
      profile_channel_stats: @escaping()->CGImage,
      profile_removed: @escaping()->CGImage,
      profile_links: @escaping()->CGImage,
      destruct_clear_history: @escaping()->CGImage,
      chat_gigagroup_info: @escaping()->CGImage,
      playlist_next: @escaping()->CGImage,
      playlist_prev: @escaping()->CGImage,
      playlist_next_locked: @escaping()->CGImage,
      playlist_prev_locked: @escaping()->CGImage,
      playlist_random: @escaping()->CGImage,
      playlist_order_normal: @escaping()->CGImage,
      playlist_order_reversed: @escaping()->CGImage,
      playlist_order_random: @escaping()->CGImage,
      playlist_repeat_none: @escaping()->CGImage,
      playlist_repeat_circle: @escaping()->CGImage,
      playlist_repeat_one: @escaping()->CGImage,
      audioplayer_next: @escaping()->CGImage,
      audioplayer_prev: @escaping()->CGImage,
      audioplayer_dismiss: @escaping()->CGImage,
      audioplayer_repeat_none: @escaping()->CGImage,
      audioplayer_repeat_circle: @escaping()->CGImage,
      audioplayer_repeat_one: @escaping()->CGImage,
      audioplayer_locked_next: @escaping()->CGImage,
      audioplayer_locked_prev: @escaping()->CGImage,
      audioplayer_volume: @escaping()->CGImage,
      audioplayer_volume_off: @escaping()->CGImage,
      audioplayer_speed_x1: @escaping()->CGImage,
      audioplayer_speed_x2: @escaping()->CGImage,
      audioplayer_list: @escaping()->CGImage,
      chat_info_voice_chat: @escaping()->CGImage,
      chat_info_create_group: @escaping()->CGImage,
      chat_info_change_colors: @escaping()->CGImage,
      empty_chat_system: @escaping()->CGImage,
      empty_chat_dark: @escaping()->CGImage,
      empty_chat_light: @escaping()->CGImage,
      empty_chat_system_active: @escaping()->CGImage,
      empty_chat_dark_active: @escaping()->CGImage,
      empty_chat_light_active: @escaping()->CGImage,
      empty_chat_storage_clear: @escaping()->CGImage,
      empty_chat_storage_low: @escaping()->CGImage,
      empty_chat_storage_medium: @escaping()->CGImage,
      empty_chat_storage_high: @escaping()->CGImage,
      empty_chat_storage_low_active: @escaping()->CGImage,
      empty_chat_storage_medium_active: @escaping()->CGImage,
      empty_chat_storage_high_active: @escaping()->CGImage,
      empty_chat_stickers_none: @escaping()->CGImage,
      empty_chat_stickers_mysets: @escaping()->CGImage,
      empty_chat_stickers_allsets: @escaping()->CGImage,
      empty_chat_stickers_none_active: @escaping()->CGImage,
      empty_chat_stickers_mysets_active: @escaping()->CGImage,
      empty_chat_stickers_allsets_active: @escaping()->CGImage,
      chat_action_dismiss: @escaping()->CGImage,
      chat_action_edit_message: @escaping()->CGImage,
      chat_action_forward_message: @escaping()->CGImage,
      chat_action_reply_message: @escaping()->CGImage,
      chat_action_url_preview: @escaping()->CGImage,
      chat_action_menu_update_chat: @escaping()->CGImage,
      chat_action_menu_selected: @escaping()->CGImage,
      widget_peers_favorite: @escaping()->CGImage,
      widget_peers_recent: @escaping()->CGImage,
      widget_peers_both: @escaping()->CGImage,
      widget_peers_favorite_active: @escaping()->CGImage,
      widget_peers_recent_active: @escaping()->CGImage,
      widget_peers_both_active: @escaping()->CGImage,
      chat_reactions_add: @escaping()->CGImage,
      chat_reactions_add_bubble: @escaping()->CGImage,
      chat_reactions_add_active: @escaping()->CGImage,
      reactions_badge: @escaping()->CGImage,
      reactions_badge_active: @escaping()->CGImage,
      reactions_badge_archive: @escaping()->CGImage,
      reactions_badge_archive_active: @escaping()->CGImage,
      reactions_show_more: @escaping()->CGImage,
      chat_reactions_badge: @escaping()->CGImage,
      chat_reactions_badge_active: @escaping()->CGImage,
      gallery_pip_close: @escaping()->CGImage,
      gallery_pip_muted: @escaping()->CGImage,
      gallery_pip_unmuted: @escaping()->CGImage,
      gallery_pip_out: @escaping()->CGImage,
      gallery_pip_pause: @escaping()->CGImage,
      gallery_pip_play: @escaping()->CGImage,
      notification_sound_add: @escaping()->CGImage,
      premium_lock: @escaping()->CGImage,
      premium_lock_gray: @escaping()->CGImage,
      premium_plus: @escaping()->CGImage,
      premium_account: @escaping()->CGImage,
      premium_account_active: @escaping()->CGImage,
      premium_account_rev: @escaping()->CGImage,
      premium_account_rev_active: @escaping()->CGImage,
      premium_account_small: @escaping()->CGImage,
      premium_account_small_active: @escaping()->CGImage,
      premium_account_small_rev: @escaping()->CGImage,
      premium_account_small_rev_active: @escaping()->CGImage,
      premium_reaction_lock: @escaping()->CGImage,
      premium_boarding_feature_next: @escaping()->CGImage,
      premium_stickers: @escaping()->CGImage,
      premium_emoji_lock: @escaping()->CGImage,
      account_add_account: @escaping()->CGImage,
      account_set_status: @escaping()->CGImage,
      account_change_status: @escaping()->CGImage,
      chat_premium_status_red: @escaping()->CGImage,
      chat_premium_status_orange: @escaping()->CGImage,
      chat_premium_status_violet: @escaping()->CGImage,
      chat_premium_status_green: @escaping()->CGImage,
      chat_premium_status_cyan: @escaping()->CGImage,
      chat_premium_status_light_blue: @escaping()->CGImage,
      chat_premium_status_blue: @escaping()->CGImage,
      extend_content_lock: @escaping()->CGImage,
      chatlist_forum_closed_topic: @escaping()->CGImage,
      chatlist_forum_closed_topic_active: @escaping()->CGImage,
      chatlist_arrow: @escaping()->CGImage,
      chatlist_arrow_active: @escaping()->CGImage,
      dialog_auto_delete: @escaping()->CGImage,
      contact_set_photo: @escaping()->CGImage,
      contact_suggest_photo: @escaping()->CGImage,
      send_media_spoiler: @escaping()->CGImage,
      general_delete: @escaping()->CGImage,
      storage_music_play: @escaping()->CGImage,
      storage_music_pause: @escaping()->CGImage,
      storage_media_play: @escaping()->CGImage,
      general_chevron_up: @escaping()->CGImage,
      general_chevron_down: @escaping()->CGImage,
      account_settings_set_password: @escaping()->CGImage,
      select_peer_create_channel: @escaping()->CGImage,
      select_peer_create_group: @escaping()->CGImage,
      chat_translate: @escaping()->CGImage,
      msg_emoji_activities: @escaping()->CGImage,
      msg_emoji_angry: @escaping()->CGImage,
      msg_emoji_away: @escaping()->CGImage,
      msg_emoji_bath: @escaping()->CGImage,
      msg_emoji_busy: @escaping()->CGImage,
      msg_emoji_dislike: @escaping()->CGImage,
      msg_emoji_food: @escaping()->CGImage,
      msg_emoji_haha: @escaping()->CGImage,
      msg_emoji_happy: @escaping()->CGImage,
      msg_emoji_heart: @escaping()->CGImage,
      msg_emoji_hi2: @escaping()->CGImage,
      msg_emoji_home: @escaping()->CGImage,
      msg_emoji_like: @escaping()->CGImage,
      msg_emoji_neutral: @escaping()->CGImage,
      msg_emoji_omg: @escaping()->CGImage,
      msg_emoji_party: @escaping()->CGImage,
      msg_emoji_recent: @escaping()->CGImage,
      msg_emoji_sad: @escaping()->CGImage,
      msg_emoji_sleep: @escaping()->CGImage,
      msg_emoji_study: @escaping()->CGImage,
      msg_emoji_tongue: @escaping()->CGImage,
      msg_emoji_vacation: @escaping()->CGImage,
      msg_emoji_what: @escaping()->CGImage,
      msg_emoji_work: @escaping()->CGImage,
      msg_emoji_premium: @escaping()->CGImage,
      installed_stickers_archive: @escaping()->CGImage,
      installed_stickers_custom_emoji: @escaping()->CGImage,
      installed_stickers_dynamic_order: @escaping()->CGImage,
      installed_stickers_loop: @escaping()->CGImage,
      installed_stickers_reactions: @escaping()->CGImage,
      installed_stickers_suggest: @escaping()->CGImage,
      installed_stickers_trending: @escaping()->CGImage,
      folder_invite_link: @escaping()->CGImage,
      folder_invite_link_revoked: @escaping()->CGImage,
      folders_sidebar_edit: @escaping()->CGImage,
      folders_sidebar_edit_active: @escaping()->CGImage,
      story_unseen: @escaping()->CGImage,
      story_seen: @escaping()->CGImage,
      story_selected: @escaping()->CGImage,
      story_unseen_chat: @escaping()->CGImage,
      story_seen_chat: @escaping()->CGImage,
      story_unseen_profile: @escaping()->CGImage,
      story_seen_profile: @escaping()->CGImage,
      story_view_read: @escaping()->CGImage,
      story_view_reaction: @escaping()->CGImage,
      story_chatlist_reply: @escaping()->CGImage,
      story_chatlist_reply_active: @escaping()->CGImage,
      message_story_expired: @escaping()->CGImage,
      message_story_expired_bubble_incoming: @escaping()->CGImage,
      message_story_expired_bubble_outgoing: @escaping()->CGImage,
      message_quote_accent: @escaping()->CGImage,
      message_quote_red: @escaping()->CGImage,
      message_quote_orange: @escaping()->CGImage,
      message_quote_violet: @escaping()->CGImage,
      message_quote_green: @escaping()->CGImage,
      message_quote_cyan: @escaping()->CGImage,
      message_quote_blue: @escaping()->CGImage,
      message_quote_pink: @escaping()->CGImage,
      message_quote_bubble_incoming: @escaping()->CGImage,
      message_quote_bubble_outgoing: @escaping()->CGImage,
      channel_stats_likes: @escaping()->CGImage,
      channel_stats_shares: @escaping()->CGImage,
      story_repost_from_white: @escaping()->CGImage,
      story_repost_from_green: @escaping()->CGImage,
      channel_feature_background: @escaping()->CGImage,
      channel_feature_background_photo: @escaping()->CGImage,
      channel_feature_cover_color: @escaping()->CGImage,
      channel_feature_cover_icon: @escaping()->CGImage,
      channel_feature_link_color: @escaping()->CGImage,
      channel_feature_link_icon: @escaping()->CGImage,
      channel_feature_name_color: @escaping()->CGImage,
      channel_feature_reaction: @escaping()->CGImage,
      channel_feature_status: @escaping()->CGImage,
      channel_feature_stories: @escaping()->CGImage,
      channel_feature_emoji_pack: @escaping()->CGImage,
      channel_feature_voice_to_text: @escaping()->CGImage,
      channel_feature_no_ads: @escaping()->CGImage,
      channel_feature_autotranslate: @escaping()->CGImage,
      chat_hidden_author: @escaping()->CGImage,
      chat_my_notes: @escaping()->CGImage,
      premium_required_forward: @escaping()->CGImage,
      create_new_message_general: @escaping()->CGImage,
      bot_manager_settings: @escaping()->CGImage,
      preview_text_down: @escaping()->CGImage,
      preview_text_up: @escaping()->CGImage,
      avatar_star_badge: @escaping()->CGImage,
      avatar_star_badge_active: @escaping()->CGImage,
      avatar_star_badge_gray: @escaping()->CGImage,
      avatar_star_badge_large_gray: @escaping()->CGImage,
      chatlist_apps: @escaping()->CGImage,
      chat_input_channel_gift: @escaping()->CGImage,
      chat_input_suggest_message: @escaping()->CGImage,
      chat_input_send_gift: @escaping()->CGImage,
      chat_input_suggest_post: @escaping()->CGImage,
      todo_selection: @escaping()->CGImage,
      todo_selected: @escaping()->CGImage,
      todo_selection_other_incoming: @escaping()->CGImage,
      todo_selection_other_outgoing: @escaping()->CGImage,
      todo_selected_other_incoming: @escaping()->CGImage,
      todo_selected_other_outgoing: @escaping()->CGImage
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
      self._chatCallActive = chatCallActive
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
      self._chatFallbackVideoCall = chatFallbackVideoCall
      self._chatFallbackVideoCallBubble_incoming = chatFallbackVideoCallBubble_incoming
      self._chatFallbackVideoCallBubble_outgoing = chatFallbackVideoCallBubble_outgoing
      self._chatToggleSelected = chatToggleSelected
      self._chatToggleUnselected = chatToggleUnselected
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
      self._chatPaidMessageInBubble_incoming = chatPaidMessageInBubble_incoming
      self._chatPaidMessageInBubble_outgoing = chatPaidMessageInBubble_outgoing
      self._chatPaidMessageOutBubble = chatPaidMessageOutBubble
      self._chatPaidMessageOverlayBubble = chatPaidMessageOverlayBubble
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
      self._chatScrollDown = chatScrollDown
      self._chatScrollDownActive = chatScrollDownActive
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
      self._chatSecretThumbSmall = chatSecretThumbSmall
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
      self._callWindowDeclineSmall = callWindowDeclineSmall
      self._callWindowAccept = callWindowAccept
      self._callWindowVideo = callWindowVideo
      self._callWindowVideoActive = callWindowVideoActive
      self._callWindowMute = callWindowMute
      self._callWindowMuteActive = callWindowMuteActive
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
      self._settingsStories = settingsStories
      self._settingsGeneral = settingsGeneral
      self._settingsLanguage = settingsLanguage
      self._settingsNotifications = settingsNotifications
      self._settingsSecurity = settingsSecurity
      self._settingsStickers = settingsStickers
      self._settingsStorage = settingsStorage
      self._settingsSessions = settingsSessions
      self._settingsProxy = settingsProxy
      self._settingsAppearance = settingsAppearance
      self._settingsPassport = settingsPassport
      self._settingsWallet = settingsWallet
      self._settingsUpdate = settingsUpdate
      self._settingsFilters = settingsFilters
      self._settingsPremium = settingsPremium
      self._settingsGiftPremium = settingsGiftPremium
      self._settingsAskQuestionActive = settingsAskQuestionActive
      self._settingsFaqActive = settingsFaqActive
      self._settingsStoriesActive = settingsStoriesActive
      self._settingsGeneralActive = settingsGeneralActive
      self._settingsLanguageActive = settingsLanguageActive
      self._settingsNotificationsActive = settingsNotificationsActive
      self._settingsSecurityActive = settingsSecurityActive
      self._settingsStickersActive = settingsStickersActive
      self._settingsStorageActive = settingsStorageActive
      self._settingsSessionsActive = settingsSessionsActive
      self._settingsProxyActive = settingsProxyActive
      self._settingsAppearanceActive = settingsAppearanceActive
      self._settingsPassportActive = settingsPassportActive
      self._settingsWalletActive = settingsWalletActive
      self._settingsUpdateActive = settingsUpdateActive
      self._settingsFiltersActive = settingsFiltersActive
      self._settingsProfile = settingsProfile
      self._settingsBusiness = settingsBusiness
      self._settingsBusinessActive = settingsBusinessActive
      self._settingsStars = settingsStars
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
      self._chatGroupToggleSelected = chatGroupToggleSelected
      self._chatGroupToggleUnselected = chatGroupToggleUnselected
      self._successModalProgress = successModalProgress
      self._accentColorSelect = accentColorSelect
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
      self._galleryRotate = galleryRotate
      self._galleryZoomIn = galleryZoomIn
      self._galleryZoomOut = galleryZoomOut
      self._editMessageCurrentPhoto = editMessageCurrentPhoto
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
      self._peerInfoRecentActions = peerInfoRecentActions
      self._peerInfoPermissions = peerInfoPermissions
      self._peerInfoBanned = peerInfoBanned
      self._peerInfoMembers = peerInfoMembers
      self._peerInfoStarsBalance = peerInfoStarsBalance
      self._peerInfoBalance = peerInfoBalance
      self._peerInfoTonBalance = peerInfoTonBalance
      self._peerInfoBotUsername = peerInfoBotUsername
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
      self._fake = fake
      self._fakeActive = fakeActive
      self._chatFake = chatFake
      self._chatUnarchive = chatUnarchive
      self._chatArchive = chatArchive
      self._privacySettings_blocked = privacySettings_blocked
      self._privacySettings_activeSessions = privacySettings_activeSessions
      self._privacySettings_passcode = privacySettings_passcode
      self._privacySettings_twoStep = privacySettings_twoStep
      self._privacy_settings_autodelete = privacy_settings_autodelete
      self._deletedAccount = deletedAccount
      self._stickerPackSelection = stickerPackSelection
      self._stickerPackSelectionActive = stickerPackSelectionActive
      self._entertainment_Emoji = entertainment_Emoji
      self._entertainment_Stickers = entertainment_Stickers
      self._entertainment_Gifs = entertainment_Gifs
      self._entertainment_Search = entertainment_Search
      self._entertainment_Settings = entertainment_Settings
      self._entertainment_SearchCancel = entertainment_SearchCancel
      self._entertainment_AnimatedEmoji = entertainment_AnimatedEmoji
      self._scheduledAvatar = scheduledAvatar
      self._scheduledInputAction = scheduledInputAction
      self._verifyDialog = verifyDialog
      self._verifyDialogActive = verifyDialogActive
      self._verify_dialog_left = verify_dialog_left
      self._verify_dialog_active_left = verify_dialog_active_left
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
      self._wallpaper_color_play = wallpaper_color_play
      self._login_cap = login_cap
      self._login_qr_cap = login_qr_cap
      self._login_qr_empty_cap = login_qr_empty_cap
      self._chat_failed_scroller = chat_failed_scroller
      self._chat_failed_scroller_active = chat_failed_scroller_active
      self._poll_quiz_unselected = poll_quiz_unselected
      self._poll_selected = poll_selected
      self._poll_selection = poll_selection
      self._poll_selected_correct = poll_selected_correct
      self._poll_selected_incorrect = poll_selected_incorrect
      self._poll_selected_incoming = poll_selected_incoming
      self._poll_selection_incoming = poll_selection_incoming
      self._poll_selected_correct_incoming = poll_selected_correct_incoming
      self._poll_selected_incorrect_incoming = poll_selected_incorrect_incoming
      self._poll_selected_outgoing = poll_selected_outgoing
      self._poll_selection_outgoing = poll_selection_outgoing
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
      self._chat_filter_new_chats = chat_filter_new_chats
      self._chat_filter_existing_chats = chat_filter_existing_chats
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
      self._profile_video_call = profile_video_call
      self._profile_leave = profile_leave
      self._profile_message = profile_message
      self._profile_more = profile_more
      self._profile_mute = profile_mute
      self._profile_unmute = profile_unmute
      self._profile_search = profile_search
      self._profile_secret_chat = profile_secret_chat
      self._profile_edit_photo = profile_edit_photo
      self._profile_block = profile_block
      self._profile_report = profile_report
      self._profile_share = profile_share
      self._profile_stats = profile_stats
      self._profile_unblock = profile_unblock
      self._profile_translate = profile_translate
      self._profile_join_channel = profile_join_channel
      self._profile_boost = profile_boost
      self._profile_archive = profile_archive
      self._stats_boost_boost = stats_boost_boost
      self._stats_boost_giveaway = stats_boost_giveaway
      self._stats_boost_info = stats_boost_info
      self._chat_quiz_explanation = chat_quiz_explanation
      self._chat_quiz_explanation_bubble_incoming = chat_quiz_explanation_bubble_incoming
      self._chat_quiz_explanation_bubble_outgoing = chat_quiz_explanation_bubble_outgoing
      self._stickers_add_featured = stickers_add_featured
      self._stickers_add_featured_unread = stickers_add_featured_unread
      self._stickers_add_featured_active = stickers_add_featured_active
      self._stickers_add_featured_unread_active = stickers_add_featured_unread_active
      self._stickers_favorite = stickers_favorite
      self._stickers_favorite_active = stickers_favorite_active
      self._channel_info_promo = channel_info_promo
      self._channel_info_promo_bubble_incoming = channel_info_promo_bubble_incoming
      self._channel_info_promo_bubble_outgoing = channel_info_promo_bubble_outgoing
      self._chat_share_message = chat_share_message
      self._chat_goto_message = chat_goto_message
      self._chat_swipe_reply = chat_swipe_reply
      self._chat_like_message = chat_like_message
      self._chat_like_message_unlike = chat_like_message_unlike
      self._chat_like_inside = chat_like_inside
      self._chat_like_inside_bubble_incoming = chat_like_inside_bubble_incoming
      self._chat_like_inside_bubble_outgoing = chat_like_inside_bubble_outgoing
      self._chat_like_inside_bubble_overlay = chat_like_inside_bubble_overlay
      self._chat_like_inside_empty = chat_like_inside_empty
      self._chat_like_inside_empty_bubble_incoming = chat_like_inside_empty_bubble_incoming
      self._chat_like_inside_empty_bubble_outgoing = chat_like_inside_empty_bubble_outgoing
      self._chat_like_inside_empty_bubble_overlay = chat_like_inside_empty_bubble_overlay
      self._gif_trending = gif_trending
      self._gif_trending_active = gif_trending_active
      self._gif_recent = gif_recent
      self._gif_recent_active = gif_recent_active
      self._chat_list_thumb_play = chat_list_thumb_play
      self._call_tooltip_battery_low = call_tooltip_battery_low
      self._call_tooltip_camera_off = call_tooltip_camera_off
      self._call_tooltip_micro_off = call_tooltip_micro_off
      self._call_screen_sharing = call_screen_sharing
      self._call_screen_sharing_active = call_screen_sharing_active
      self._call_screen_settings = call_screen_settings
      self._search_filter = search_filter
      self._search_filter_media = search_filter_media
      self._search_filter_files = search_filter_files
      self._search_filter_links = search_filter_links
      self._search_filter_music = search_filter_music
      self._search_filter_downloads = search_filter_downloads
      self._search_filter_add_peer = search_filter_add_peer
      self._search_filter_add_peer_active = search_filter_add_peer_active
      self._search_filter_hashtag = search_filter_hashtag
      self._search_hashtag_chevron = search_hashtag_chevron
      self._chat_reply_count_bubble_incoming = chat_reply_count_bubble_incoming
      self._chat_reply_count_bubble_outgoing = chat_reply_count_bubble_outgoing
      self._chat_reply_count = chat_reply_count
      self._chat_reply_count_overlay = chat_reply_count_overlay
      self._channel_comments_bubble = channel_comments_bubble
      self._channel_comments_bubble_next = channel_comments_bubble_next
      self._channel_comments_list = channel_comments_list
      self._channel_comments_overlay = channel_comments_overlay
      self._chat_replies_avatar = chat_replies_avatar
      self._group_selection_foreground = group_selection_foreground
      self._group_selection_foreground_bubble_incoming = group_selection_foreground_bubble_incoming
      self._group_selection_foreground_bubble_outgoing = group_selection_foreground_bubble_outgoing
      self._chat_pinned_list = chat_pinned_list
      self._chat_pinned_message = chat_pinned_message
      self._chat_pinned_message_bubble_incoming = chat_pinned_message_bubble_incoming
      self._chat_pinned_message_bubble_outgoing = chat_pinned_message_bubble_outgoing
      self._chat_pinned_message_overlay_bubble = chat_pinned_message_overlay_bubble
      self._chat_voicechat_can_unmute = chat_voicechat_can_unmute
      self._chat_voicechat_cant_unmute = chat_voicechat_cant_unmute
      self._chat_voicechat_unmuted = chat_voicechat_unmuted
      self._profile_voice_chat = profile_voice_chat
      self._chat_voice_chat = chat_voice_chat
      self._chat_voice_chat_active = chat_voice_chat_active
      self._editor_draw = editor_draw
      self._editor_delete = editor_delete
      self._editor_crop = editor_crop
      self._fast_copy_link = fast_copy_link
      self._profile_channel_sign = profile_channel_sign
      self._profile_channel_type = profile_channel_type
      self._profile_group_type = profile_group_type
      self._profile_group_topics = profile_group_topics
      self._profile_group_destruct = profile_group_destruct
      self._profile_group_discussion = profile_group_discussion
      self._profile_requests = profile_requests
      self._profile_reactions = profile_reactions
      self._profile_channel_color = profile_channel_color
      self._profile_channel_stats = profile_channel_stats
      self._profile_removed = profile_removed
      self._profile_links = profile_links
      self._destruct_clear_history = destruct_clear_history
      self._chat_gigagroup_info = chat_gigagroup_info
      self._playlist_next = playlist_next
      self._playlist_prev = playlist_prev
      self._playlist_next_locked = playlist_next_locked
      self._playlist_prev_locked = playlist_prev_locked
      self._playlist_random = playlist_random
      self._playlist_order_normal = playlist_order_normal
      self._playlist_order_reversed = playlist_order_reversed
      self._playlist_order_random = playlist_order_random
      self._playlist_repeat_none = playlist_repeat_none
      self._playlist_repeat_circle = playlist_repeat_circle
      self._playlist_repeat_one = playlist_repeat_one
      self._audioplayer_next = audioplayer_next
      self._audioplayer_prev = audioplayer_prev
      self._audioplayer_dismiss = audioplayer_dismiss
      self._audioplayer_repeat_none = audioplayer_repeat_none
      self._audioplayer_repeat_circle = audioplayer_repeat_circle
      self._audioplayer_repeat_one = audioplayer_repeat_one
      self._audioplayer_locked_next = audioplayer_locked_next
      self._audioplayer_locked_prev = audioplayer_locked_prev
      self._audioplayer_volume = audioplayer_volume
      self._audioplayer_volume_off = audioplayer_volume_off
      self._audioplayer_speed_x1 = audioplayer_speed_x1
      self._audioplayer_speed_x2 = audioplayer_speed_x2
      self._audioplayer_list = audioplayer_list
      self._chat_info_voice_chat = chat_info_voice_chat
      self._chat_info_create_group = chat_info_create_group
      self._chat_info_change_colors = chat_info_change_colors
      self._empty_chat_system = empty_chat_system
      self._empty_chat_dark = empty_chat_dark
      self._empty_chat_light = empty_chat_light
      self._empty_chat_system_active = empty_chat_system_active
      self._empty_chat_dark_active = empty_chat_dark_active
      self._empty_chat_light_active = empty_chat_light_active
      self._empty_chat_storage_clear = empty_chat_storage_clear
      self._empty_chat_storage_low = empty_chat_storage_low
      self._empty_chat_storage_medium = empty_chat_storage_medium
      self._empty_chat_storage_high = empty_chat_storage_high
      self._empty_chat_storage_low_active = empty_chat_storage_low_active
      self._empty_chat_storage_medium_active = empty_chat_storage_medium_active
      self._empty_chat_storage_high_active = empty_chat_storage_high_active
      self._empty_chat_stickers_none = empty_chat_stickers_none
      self._empty_chat_stickers_mysets = empty_chat_stickers_mysets
      self._empty_chat_stickers_allsets = empty_chat_stickers_allsets
      self._empty_chat_stickers_none_active = empty_chat_stickers_none_active
      self._empty_chat_stickers_mysets_active = empty_chat_stickers_mysets_active
      self._empty_chat_stickers_allsets_active = empty_chat_stickers_allsets_active
      self._chat_action_dismiss = chat_action_dismiss
      self._chat_action_edit_message = chat_action_edit_message
      self._chat_action_forward_message = chat_action_forward_message
      self._chat_action_reply_message = chat_action_reply_message
      self._chat_action_url_preview = chat_action_url_preview
      self._chat_action_menu_update_chat = chat_action_menu_update_chat
      self._chat_action_menu_selected = chat_action_menu_selected
      self._widget_peers_favorite = widget_peers_favorite
      self._widget_peers_recent = widget_peers_recent
      self._widget_peers_both = widget_peers_both
      self._widget_peers_favorite_active = widget_peers_favorite_active
      self._widget_peers_recent_active = widget_peers_recent_active
      self._widget_peers_both_active = widget_peers_both_active
      self._chat_reactions_add = chat_reactions_add
      self._chat_reactions_add_bubble = chat_reactions_add_bubble
      self._chat_reactions_add_active = chat_reactions_add_active
      self._reactions_badge = reactions_badge
      self._reactions_badge_active = reactions_badge_active
      self._reactions_badge_archive = reactions_badge_archive
      self._reactions_badge_archive_active = reactions_badge_archive_active
      self._reactions_show_more = reactions_show_more
      self._chat_reactions_badge = chat_reactions_badge
      self._chat_reactions_badge_active = chat_reactions_badge_active
      self._gallery_pip_close = gallery_pip_close
      self._gallery_pip_muted = gallery_pip_muted
      self._gallery_pip_unmuted = gallery_pip_unmuted
      self._gallery_pip_out = gallery_pip_out
      self._gallery_pip_pause = gallery_pip_pause
      self._gallery_pip_play = gallery_pip_play
      self._notification_sound_add = notification_sound_add
      self._premium_lock = premium_lock
      self._premium_lock_gray = premium_lock_gray
      self._premium_plus = premium_plus
      self._premium_account = premium_account
      self._premium_account_active = premium_account_active
      self._premium_account_rev = premium_account_rev
      self._premium_account_rev_active = premium_account_rev_active
      self._premium_account_small = premium_account_small
      self._premium_account_small_active = premium_account_small_active
      self._premium_account_small_rev = premium_account_small_rev
      self._premium_account_small_rev_active = premium_account_small_rev_active
      self._premium_reaction_lock = premium_reaction_lock
      self._premium_boarding_feature_next = premium_boarding_feature_next
      self._premium_stickers = premium_stickers
      self._premium_emoji_lock = premium_emoji_lock
      self._account_add_account = account_add_account
      self._account_set_status = account_set_status
      self._account_change_status = account_change_status
      self._chat_premium_status_red = chat_premium_status_red
      self._chat_premium_status_orange = chat_premium_status_orange
      self._chat_premium_status_violet = chat_premium_status_violet
      self._chat_premium_status_green = chat_premium_status_green
      self._chat_premium_status_cyan = chat_premium_status_cyan
      self._chat_premium_status_light_blue = chat_premium_status_light_blue
      self._chat_premium_status_blue = chat_premium_status_blue
      self._extend_content_lock = extend_content_lock
      self._chatlist_forum_closed_topic = chatlist_forum_closed_topic
      self._chatlist_forum_closed_topic_active = chatlist_forum_closed_topic_active
      self._chatlist_arrow = chatlist_arrow
      self._chatlist_arrow_active = chatlist_arrow_active
      self._dialog_auto_delete = dialog_auto_delete
      self._contact_set_photo = contact_set_photo
      self._contact_suggest_photo = contact_suggest_photo
      self._send_media_spoiler = send_media_spoiler
      self._general_delete = general_delete
      self._storage_music_play = storage_music_play
      self._storage_music_pause = storage_music_pause
      self._storage_media_play = storage_media_play
      self._general_chevron_up = general_chevron_up
      self._general_chevron_down = general_chevron_down
      self._account_settings_set_password = account_settings_set_password
      self._select_peer_create_channel = select_peer_create_channel
      self._select_peer_create_group = select_peer_create_group
      self._chat_translate = chat_translate
      self._msg_emoji_activities = msg_emoji_activities
      self._msg_emoji_angry = msg_emoji_angry
      self._msg_emoji_away = msg_emoji_away
      self._msg_emoji_bath = msg_emoji_bath
      self._msg_emoji_busy = msg_emoji_busy
      self._msg_emoji_dislike = msg_emoji_dislike
      self._msg_emoji_food = msg_emoji_food
      self._msg_emoji_haha = msg_emoji_haha
      self._msg_emoji_happy = msg_emoji_happy
      self._msg_emoji_heart = msg_emoji_heart
      self._msg_emoji_hi2 = msg_emoji_hi2
      self._msg_emoji_home = msg_emoji_home
      self._msg_emoji_like = msg_emoji_like
      self._msg_emoji_neutral = msg_emoji_neutral
      self._msg_emoji_omg = msg_emoji_omg
      self._msg_emoji_party = msg_emoji_party
      self._msg_emoji_recent = msg_emoji_recent
      self._msg_emoji_sad = msg_emoji_sad
      self._msg_emoji_sleep = msg_emoji_sleep
      self._msg_emoji_study = msg_emoji_study
      self._msg_emoji_tongue = msg_emoji_tongue
      self._msg_emoji_vacation = msg_emoji_vacation
      self._msg_emoji_what = msg_emoji_what
      self._msg_emoji_work = msg_emoji_work
      self._msg_emoji_premium = msg_emoji_premium
      self._installed_stickers_archive = installed_stickers_archive
      self._installed_stickers_custom_emoji = installed_stickers_custom_emoji
      self._installed_stickers_dynamic_order = installed_stickers_dynamic_order
      self._installed_stickers_loop = installed_stickers_loop
      self._installed_stickers_reactions = installed_stickers_reactions
      self._installed_stickers_suggest = installed_stickers_suggest
      self._installed_stickers_trending = installed_stickers_trending
      self._folder_invite_link = folder_invite_link
      self._folder_invite_link_revoked = folder_invite_link_revoked
      self._folders_sidebar_edit = folders_sidebar_edit
      self._folders_sidebar_edit_active = folders_sidebar_edit_active
      self._story_unseen = story_unseen
      self._story_seen = story_seen
      self._story_selected = story_selected
      self._story_unseen_chat = story_unseen_chat
      self._story_seen_chat = story_seen_chat
      self._story_unseen_profile = story_unseen_profile
      self._story_seen_profile = story_seen_profile
      self._story_view_read = story_view_read
      self._story_view_reaction = story_view_reaction
      self._story_chatlist_reply = story_chatlist_reply
      self._story_chatlist_reply_active = story_chatlist_reply_active
      self._message_story_expired = message_story_expired
      self._message_story_expired_bubble_incoming = message_story_expired_bubble_incoming
      self._message_story_expired_bubble_outgoing = message_story_expired_bubble_outgoing
      self._message_quote_accent = message_quote_accent
      self._message_quote_red = message_quote_red
      self._message_quote_orange = message_quote_orange
      self._message_quote_violet = message_quote_violet
      self._message_quote_green = message_quote_green
      self._message_quote_cyan = message_quote_cyan
      self._message_quote_blue = message_quote_blue
      self._message_quote_pink = message_quote_pink
      self._message_quote_bubble_incoming = message_quote_bubble_incoming
      self._message_quote_bubble_outgoing = message_quote_bubble_outgoing
      self._channel_stats_likes = channel_stats_likes
      self._channel_stats_shares = channel_stats_shares
      self._story_repost_from_white = story_repost_from_white
      self._story_repost_from_green = story_repost_from_green
      self._channel_feature_background = channel_feature_background
      self._channel_feature_background_photo = channel_feature_background_photo
      self._channel_feature_cover_color = channel_feature_cover_color
      self._channel_feature_cover_icon = channel_feature_cover_icon
      self._channel_feature_link_color = channel_feature_link_color
      self._channel_feature_link_icon = channel_feature_link_icon
      self._channel_feature_name_color = channel_feature_name_color
      self._channel_feature_reaction = channel_feature_reaction
      self._channel_feature_status = channel_feature_status
      self._channel_feature_stories = channel_feature_stories
      self._channel_feature_emoji_pack = channel_feature_emoji_pack
      self._channel_feature_voice_to_text = channel_feature_voice_to_text
      self._channel_feature_no_ads = channel_feature_no_ads
      self._channel_feature_autotranslate = channel_feature_autotranslate
      self._chat_hidden_author = chat_hidden_author
      self._chat_my_notes = chat_my_notes
      self._premium_required_forward = premium_required_forward
      self._create_new_message_general = create_new_message_general
      self._bot_manager_settings = bot_manager_settings
      self._preview_text_down = preview_text_down
      self._preview_text_up = preview_text_up
      self._avatar_star_badge = avatar_star_badge
      self._avatar_star_badge_active = avatar_star_badge_active
      self._avatar_star_badge_gray = avatar_star_badge_gray
      self._avatar_star_badge_large_gray = avatar_star_badge_large_gray
      self._chatlist_apps = chatlist_apps
      self._chat_input_channel_gift = chat_input_channel_gift
      self._chat_input_suggest_message = chat_input_suggest_message
      self._chat_input_send_gift = chat_input_send_gift
      self._chat_input_suggest_post = chat_input_suggest_post
      self._todo_selection = todo_selection
      self._todo_selected = todo_selected
      self._todo_selection_other_incoming = todo_selection_other_incoming
      self._todo_selection_other_outgoing = todo_selection_other_outgoing
      self._todo_selected_other_incoming = todo_selected_other_incoming
      self._todo_selected_other_outgoing = todo_selected_other_outgoing
  }
}