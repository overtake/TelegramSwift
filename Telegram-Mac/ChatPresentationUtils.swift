//
//  ChatPresentationUtils.swift
//  Telegram
//
//  Created by keepcoder on 23/12/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox

final class ChatMediaPresentation : Equatable {
    
    private let isIncoming: Bool
    private let isBubble: Bool
    
    let activityBackground: NSColor
    let activityForeground: NSColor
    let waveformBackground: NSColor
    let waveformForeground: NSColor
    let text: NSColor
    let grayText: NSColor
    let link: NSColor
    
    init(isIncoming: Bool, isBubble: Bool, activityBackground: NSColor, activityForeground: NSColor, text: NSColor, grayText: NSColor, link: NSColor, waveformBackground: NSColor, waveformForeground: NSColor) {
        self.isIncoming = isIncoming
        self.isBubble = isBubble
        self.activityForeground = activityForeground
        self.activityBackground = activityBackground
        self.text = text
        self.grayText = grayText
        self.link = link
        self.waveformBackground = waveformBackground
        self.waveformForeground = waveformForeground
    }
    
    static func make(for message: Message, account: Account, renderType: ChatItemRenderType) -> ChatMediaPresentation {
        let isIncoming: Bool = message.isIncoming(account, renderType == .bubble)
        return ChatMediaPresentation(isIncoming: isIncoming,
                                     isBubble: renderType == .bubble,
                                     activityBackground: theme.chat.activityBackground(isIncoming, renderType == .bubble),
                                     activityForeground: theme.chat.activityForeground(isIncoming, renderType == .bubble),
                                     text: theme.chat.textColor(isIncoming, renderType == .bubble),
                                     grayText: theme.chat.grayText(isIncoming, renderType == .bubble),
                                     link: theme.chat.linkColor(isIncoming, renderType == .bubble),
                                     waveformBackground: theme.chat.waveformBackground(isIncoming, renderType == .bubble),
                                     waveformForeground: theme.chat.waveformForeground(isIncoming, renderType == .bubble))
    }
    
    static var empty: ChatMediaPresentation {
        return .init(isIncoming: true, isBubble: true, activityBackground: .clear, activityForeground: .clear, text: .clear, grayText: .clear, link: .clear, waveformBackground: .clear, waveformForeground: .clear)
    }
    
    var fileThumb: CGImage {
        if isBubble {
            return isIncoming ? theme.icons.chatFileThumbBubble_incoming : theme.icons.chatFileThumbBubble_outgoing
        } else {
            return theme.icons.chatFileThumb
        }
    }
    
    
    var pauseThumb: CGImage {
        if isBubble {
            return isIncoming ? theme.icons.chatMusicPauseBubble_incoming : theme.icons.chatMusicPauseBubble_outgoing
        } else {
            return theme.icons.chatMusicPause
        }
    }
    var playThumb: CGImage {
        if isBubble {
            return isIncoming ? theme.icons.chatMusicPlayBubble_incoming : theme.icons.chatMusicPlayBubble_outgoing
        } else {
            return theme.icons.chatMusicPlay
        }
    }
    
    static var Empty: ChatMediaPresentation {
        return ChatMediaPresentation(isIncoming: false, isBubble: false, activityBackground: theme.colors.accent, activityForeground: theme.colors.underSelectedColor, text: theme.colors.text, grayText: theme.colors.grayText, link: theme.colors.link, waveformBackground: theme.colors.waveformBackground, waveformForeground: theme.colors.waveformForeground)
    }
    
    static func ==(lhs: ChatMediaPresentation, rhs: ChatMediaPresentation) -> Bool {
        return lhs === rhs
    }
}

private func generatePercentageImage(color: NSColor, value: Int, font: NSFont) -> CGImage {
    return generateImage(CGSize(width: 36.0, height: 16.0), rotatedContext: { size, context in
    
        
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        
        let layout = TextViewLayout(.initialize(string: "\(value)%", color: color, font: font), maximumNumberOfLines: 1, alignment: .right)
        layout.measure(width: size.width)
        if !layout.lines.isEmpty {
            let line = layout.lines[0]
            context.textMatrix = CGAffineTransform(scaleX: 1.0, y: -1.0)
            let penOffset = CGFloat( CTLineGetPenOffsetForFlush(line.line, layout.penFlush, Double(size.width))) + line.frame.minX
            
            context.setAllowsFontSubpixelPositioning(true)
            context.setShouldSubpixelPositionFonts(true)
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(System.backingScale == 1.0)
            context.setShouldSmoothFonts(System.backingScale == 1.0)
            
            context.textPosition = CGPoint(x: penOffset, y: line.frame.minY)

            CTLineDraw(line.line, context)
        }
        
    })!
}


final class TelegramChatColors {
    

    
    private var _generatedPercentageAnimationImages:[CGImage]?
    private var _generatedPercentageAnimationImagesIncomingBubbled:[CGImage]?
    private var _generatedPercentageAnimationImagesOutgoingBubbled:[CGImage]?
    private var _generatedPercentageAnimationImagesPlain:[CGImage]?
    private var _generatedPercentageAnimationImagesIncomingBubbledPlain:[CGImage]?
    private var _generatedPercentageAnimationImagesOutgoingBubbledPlain:[CGImage]?
    
    private var generatedPercentageAnimationImages:[CGImage] {
        if let _generatedPercentageAnimationImages = self._generatedPercentageAnimationImages {
            return _generatedPercentageAnimationImages
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.text, value: i, font: .bold(12)))
            }
            self._generatedPercentageAnimationImages = images
            return images
        }
    }
    private var generatedPercentageAnimationImagesIncomingBubbled:[CGImage] {
        if let value = self._generatedPercentageAnimationImagesIncomingBubbled {
            return value
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.textBubble_incoming, value: i, font: .bold(12)))
            }
            self._generatedPercentageAnimationImagesIncomingBubbled = images
            return images
        }
    }
    private var generatedPercentageAnimationImagesOutgoingBubbled:[CGImage] {
        if let value = self._generatedPercentageAnimationImagesOutgoingBubbled {
            return value
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.textBubble_outgoing, value: i, font: .bold(12)))
            }
            self._generatedPercentageAnimationImagesOutgoingBubbled = images
            return images
        }
    }
    private var generatedPercentageAnimationImagesPlain:[CGImage] {
        if let value = self._generatedPercentageAnimationImagesPlain {
            return value
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.text, value: i, font: .bold(12)))
            }
            self._generatedPercentageAnimationImagesPlain = images
            return images
        }
    }
    private var generatedPercentageAnimationImagesIncomingBubbledPlain:[CGImage] {
        if let value = self._generatedPercentageAnimationImagesIncomingBubbledPlain {
            return value
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.textBubble_incoming, value: i, font: .normal(12)))
            }
            self._generatedPercentageAnimationImagesIncomingBubbledPlain = images
            return images
        }
    }
    private var generatedPercentageAnimationImagesOutgoingBubbledPlain:[CGImage] {
        if let value = self._generatedPercentageAnimationImagesOutgoingBubbledPlain {
            return value
        } else {
            var images:[CGImage] = []
            for i in 0 ... 100 {
                images.append(generatePercentageImage(color: palette.textBubble_outgoing, value: i, font: .normal(12)))
            }
            self._generatedPercentageAnimationImagesOutgoingBubbledPlain = images
            return images
        }
    }
    
    
    private let palette: ColorPalette
    init(_ palette: ColorPalette, _ bubbled: Bool) {
        self.palette = palette
    }
    
    private var cacheDict: [String: CGImage] = [:]
    
    func messageSecretTimer(_ value: String) -> CGImage {
        if let value = cacheDict[value] {
            return value
        } else {
            let node = TextNode.layoutText(.initialize(string: value, color: theme.colors.grayIcon, font: .normal(15)), nil, 1, .end, NSMakeSize(30, 30), nil, false, .left)
            
            let image = generateImage(NSMakeSize(30, 30), rotatedContext: { size, ctx in
                let rect = NSMakeRect(0, 0, size.width, size.height)
                ctx.clear(rect)
                node.1.draw(rect.focus(node.0.size), in: ctx, backingScaleFactor: 1.0, backgroundColor: .clear)
            })!
            cacheDict[value] = image
            
            return image
        }
        
    }
    
    //chatGotoMessageWallpaper / chatShareWallpaper / chatSwipeReplyWallpaper
    
    func chat_goto_message_bubble(theme: TelegramPresentationTheme) -> CGImage {
        if let value = cacheDict["chat_goto_message_bubble"] {
            return value
        } else {
            let image = NSImage(named: "Icon_GotoBubbleMessage")!.precomposed(theme.chatServiceItemTextColor)
            cacheDict["chat_goto_message_bubble"] = image
            return image
        }
    }
    func chat_share_bubble(theme: TelegramPresentationTheme) -> CGImage {
        if let value = cacheDict["chat_share_bubble"] {
            return value
        } else {
            let image = NSImage(named: "Icon_ChannelShare")!.precomposed(theme.chatServiceItemTextColor)
            cacheDict["chat_share_bubble"] = image
            return image
        }
    }
    func chat_reply_swipe_bubble(theme: TelegramPresentationTheme) -> CGImage {
        if let value = cacheDict["chat_reply_swipe_bubble"] {
            return value
        } else {
            let image = NSImage(named: "Icon_ChannelShare")!.precomposed(theme.chatServiceItemTextColor)
            cacheDict["chat_reply_swipe_bubble"] = image
            return image
        }
    }
    func chat_like_message_bubble(theme: TelegramPresentationTheme) -> CGImage {
        if let value = cacheDict["chat_like_message_bubble"] {
            return value
        } else {
            let image = NSImage(named: "Icon_Like_MessageButton")!.precomposed(theme.chatServiceItemTextColor)
            cacheDict["chat_like_message_bubble"] = image
            return image
        }
    }
    func chat_like_message_unlike_bubble(theme: TelegramPresentationTheme) -> CGImage {
        if let value = cacheDict["chat_like_message_unlike_bubble"] {
            return value
        } else {
            let image = NSImage(named: "Icon_Like_MessageButtonUnlike")!.precomposed(theme.chatServiceItemTextColor)
            cacheDict["chat_like_message_unlike_bubble"] = image
            return image
        }
    }
    
    private var _chatActionUrl: CGImage?
    func chatActionUrl(theme: TelegramPresentationTheme) -> CGImage {
        if let chatActionUrl = _chatActionUrl {
            return chatActionUrl
        } else {
            let image = #imageLiteral(resourceName: "Icon_InlineBotUrl").precomposed(theme.chatServiceItemTextColor)
            _chatActionUrl = image
            return image
        }
    }
    
    func pollPercentAnimatedIcons(_ incoming: Bool, _ bubbled: Bool, from fromValue: CGFloat, to toValue: CGFloat, duration: Double) -> [CGImage] {
        let minimumFrameDuration = 1.0 / 60
        let numberOfFrames = max(1, Int(duration / minimumFrameDuration))
        var images: [CGImage] = []
        
        let generated = bubbled ? incoming ? generatedPercentageAnimationImagesIncomingBubbledPlain : generatedPercentageAnimationImagesOutgoingBubbledPlain : generatedPercentageAnimationImagesPlain
        
        for i in 0 ..< numberOfFrames {
            let t = CGFloat(i) / CGFloat(numberOfFrames)
            let value = (1.0 - t) * fromValue + t * toValue
            images.append(generated[Int(round(value))])
        }
        return images
    }
    
    func pollPercentAnimatedIcon(_ incoming: Bool, _ bubbled: Bool, value: Int) -> CGImage {
        let generated = bubbled ? incoming ? generatedPercentageAnimationImagesIncomingBubbledPlain : generatedPercentageAnimationImagesOutgoingBubbledPlain : generatedPercentageAnimationImagesPlain
        return generated[max(min(generated.count - 1, value), 0)]
    }
    
    func activityBackground(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.fileActivityBackgroundBubble_incoming : palette.fileActivityBackgroundBubble_outgoing : palette.fileActivityBackground
    }
    func activityForeground(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.fileActivityForegroundBubble_incoming : palette.fileActivityForegroundBubble_outgoing : palette.fileActivityForeground
    }
    
    func webPreviewActivity(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.webPreviewActivityBubble_incoming : palette.webPreviewActivityBubble_outgoing : palette.webPreviewActivity
    }
    func pollOptionBorder(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return (bubbled ? incoming ?  grayText(incoming, bubbled) : grayText(incoming, bubbled) : palette.grayText).withAlphaComponent(0.2)
    }
    func pollOptionUnselectedImage(_ incoming: Bool, _ bubbled: Bool) -> CGImage {
        return bubbled ? incoming ? theme.icons.chatPollVoteUnselectedBubble_incoming :  theme.icons.chatPollVoteUnselectedBubble_outgoing : theme.icons.chatPollVoteUnselected
    }
    func waveformBackground(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.waveformBackgroundBubble_incoming : palette.waveformBackgroundBubble_outgoing : palette.waveformBackground
    }
    func waveformForeground(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.waveformForegroundBubble_incoming : palette.waveformForegroundBubble_outgoing : palette.waveformForeground
    }
    
    
    
    func backgroundColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? System.supportsTransparentFontDrawing ? .clear : palette.bubbleBackground_incoming : System.supportsTransparentFontDrawing ?  .clear : palette.bubbleBackgroundTop_outgoing.blended(withFraction: 0.5, of: palette.bubbleBackgroundBottom_outgoing)! : palette.chatBackground
    }
    
    func backgoundSelectedColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.bubbleBackgroundHighlight_incoming : palette.bubbleBackgroundHighlight_outgoing : palette.background
    }
    
    func bubbleBorderColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return incoming ? palette.bubbleBorder_incoming : palette.bubbleBorder_outgoing//.clear//palette.bubbleBorder_outgoing
    }
    func bubbleBackgroundColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.bubbleBackground_incoming : palette.bubbleBackgroundTop_outgoing : .clear//.clear//palette.bubbleBorder_outgoing
    }
    
    func textColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.textBubble_incoming : palette.textBubble_outgoing : palette.text
    }
    
    func monospacedPreColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.monospacedPreBubble_incoming : palette.monospacedPreBubble_outgoing : palette.monospacedPre
    }
    func monospacedCodeColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.monospacedCodeBubble_incoming : palette.monospacedCodeBubble_outgoing : palette.monospacedCode
    }
    
    func selectText(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.selectTextBubble_incoming : palette.selectTextBubble_outgoing : palette.selectText
    }
    
    func grayText(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.grayTextBubble_incoming : palette.grayTextBubble_outgoing : palette.grayText
    }
    func redUI(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.redBubble_incoming : palette.redBubble_outgoing : palette.redUI
    }
    func greenUI(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.greenBubble_incoming : palette.greenBubble_outgoing : palette.greenUI
    }
    func linkColor(_ incoming: Bool, _ bubbled: Bool) -> NSColor {
        return bubbled ? incoming ? palette.linkBubble_incoming : palette.linkBubble_outgoing : palette.accent
    }
    
    func pollSelected(_ incoming: Bool, _ bubbled: Bool, icons: TelegramIconsTheme) -> CGImage {
        return bubbled ? incoming ? icons.poll_selected_incoming : icons.poll_selected_outgoing : icons.poll_selected
    }
    func pollSelectedCorrect(_ incoming: Bool, _ bubbled: Bool, icons: TelegramIconsTheme) -> CGImage {
        return bubbled ? incoming ? icons.poll_selected_correct_incoming : icons.poll_selected_correct_outgoing : icons.poll_selected_correct
    }
    func pollSelectedIncorrect(_ incoming: Bool, _ bubbled: Bool, icons: TelegramIconsTheme) -> CGImage {
        return bubbled ? incoming ? icons.poll_selected_incorrect_incoming : icons.poll_selected_incorrect_outgoing : icons.poll_selected_incorrect
    }
    
    func channelInfoPromo(_ incoming: Bool, _ bubbled: Bool, icons: TelegramIconsTheme) -> CGImage {
        return bubbled ? incoming ? icons.channel_info_promo_bubble_incoming : icons.channel_info_promo_bubble_outgoing : icons.channel_info_promo
    }
    
    func channelViewsIcon(_ item: ChatRowItem) -> CGImage {
        return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatChannelViewsOverlayServiceBubble : item.presentation.icons.chatChannelViewsOverlayBubble : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatChannelViewsInBubble_incoming : item.presentation.icons.chatChannelViewsInBubble_outgoing : item.presentation.icons.chatChannelViewsOutBubble
    }
    func likedIcon(_ item: ChatRowItem) -> CGImage {
        if item.isLiked {
            return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chat_like_inside_bubble_service : item.presentation.icons.chat_like_inside_bubble_overlay : item.hasBubble ? item.isIncoming ? item.presentation.icons.chat_like_inside_bubble_incoming : item.presentation.icons.chat_like_inside_bubble_outgoing : item.presentation.icons.chat_like_inside
        } else {
            return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chat_like_inside_empty_bubble_service : item.presentation.icons.chat_like_inside_empty_bubble_overlay : item.hasBubble ? item.isIncoming ? item.presentation.icons.chat_like_inside_empty_bubble_incoming : item.presentation.icons.chat_like_inside_empty_bubble_outgoing : item.presentation.icons.chat_like_inside_empty
        }
    }

    func stateStateIcon(_ item: ChatRowItem) -> CGImage {
        return item.isFailed ? item.presentation.icons.sentFailed : (item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatReadMarkServiceOverlayBubble1 :  theme.icons.chatReadMarkOverlayBubble1 : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatReadMarkInBubble1_incoming : item.presentation.icons.chatReadMarkInBubble1_outgoing : item.presentation.icons.chatReadMarkOutBubble1)
    }
    func readStateIcon(_ item: ChatRowItem) -> CGImage {
        return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatReadMarkServiceOverlayBubble2 : item.presentation.icons.chatReadMarkOverlayBubble2 : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatReadMarkInBubble2_incoming : item.presentation.icons.chatReadMarkInBubble2_outgoing : item.presentation.icons.chatReadMarkOutBubble2
    }
    
    func quizSolution(_ item: ChatRowItem) -> CGImage {
        return item.hasBubble ? item.isIncoming ? item.presentation.icons.chat_quiz_explanation_bubble_incoming : item.presentation.icons.chat_quiz_explanation_bubble_outgoing : item.presentation.icons.chat_quiz_explanation
    }
    
    func instantPageIcon(_ incoming: Bool, _ bubbled: Bool, presentation: TelegramPresentationTheme) -> CGImage {
        return bubbled ? incoming ? presentation.icons.chatInstantViewBubble_incoming : presentation.icons.chatInstantViewBubble_outgoing : presentation.icons.chatInstantView
    }
    
    func sendingFrameIcon(_ item: ChatRowItem) -> CGImage {
        return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatSendingOverlayServiceFrame : item.presentation.icons.chatSendingOverlayFrame : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatSendingInFrame_incoming : item.presentation.icons.chatSendingInFrame_outgoing : item.presentation.icons.chatSendingOutFrame
    }
    func sendingHourIcon(_ item: ChatRowItem) -> CGImage {
        return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatSendingOverlayServiceHour : item.presentation.icons.chatSendingOverlayHour : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatSendingInHour_incoming : item.presentation.icons.chatSendingInHour_outgoing : item.presentation.icons.chatSendingOutHour
    }
    func sendingMinIcon(_ item: ChatRowItem) -> CGImage {
        return item.isStateOverlayLayout ? !item.isInteractiveMedia ? item.presentation.chatSendingOverlayServiceMin : item.presentation.icons.chatSendingOverlayMin : item.hasBubble ? item.isIncoming ? item.presentation.icons.chatSendingInMin_incoming : item.presentation.icons.chatSendingInMin_outgoing : item.presentation.icons.chatSendingOutMin
    }
    
    func chatCallIcon(_ item: ChatCallRowItem) -> CGImage {
        if item.hasBubble {
            return !item.isIncoming ? (item.failed ? item.presentation.icons.chatFailedCallBubble_outgoing : item.presentation.icons.chatCallBubble_outgoing) : (item.failed ? item.presentation.icons.chatFailedCallBubble_incoming : item.presentation.icons.chatCallBubble_outgoing)
        } else {
            return !item.isIncoming ? (item.failed ? item.presentation.icons.chatFailedCall_outgoing : item.presentation.icons.chatCall_outgoing) : (item.failed ? item.presentation.icons.chatFailedCall_incoming : item.presentation.icons.chatCall_outgoing)
        }
    }
    
    func chatCallFallbackIcon(_ item: ChatCallRowItem) -> CGImage {
        return item.hasBubble ? item.isIncoming ? item.presentation.icons.chatFallbackCallBubble_incoming : item.presentation.icons.chatFallbackCallBubble_outgoing : item.presentation.icons.chatFallbackCall
    }
    
    func peerName(_ index: Int) -> NSColor {
        let array = [theme.colors.groupPeerNameRed,
                     theme.colors.groupPeerNameOrange,
                     theme.colors.groupPeerNameViolet,
                     theme.colors.groupPeerNameGreen,
                     theme.colors.groupPeerNameCyan,
                     theme.colors.groupPeerNameLightBlue,
                     theme.colors.groupPeerNameBlue]
        
        return array[index]
    }
    
    func replyTitle(_ item: ChatRowItem) -> NSColor {
        return item.hasBubble ? (item.isIncoming ? item.presentation.colors.chatReplyTitleBubble_incoming : item.presentation.colors.chatReplyTitleBubble_outgoing) : item.presentation.colors.chatReplyTitle
    }
    func replyText(_ item: ChatRowItem) -> NSColor {
        return item.hasBubble ? (item.isIncoming ? item.presentation.colors.chatReplyTextEnabledBubble_incoming : item.presentation.colors.chatReplyTextEnabledBubble_outgoing) : item.presentation.colors.chatReplyTextEnabled
    }
    func replyDisabledText(_ item: ChatRowItem) -> NSColor {
        return item.hasBubble ? (item.isIncoming ? item.presentation.colors.chatReplyTextDisabledBubble_incoming : item.presentation.colors.chatReplyTextDisabledBubble_outgoing) : item.presentation.colors.chatReplyTextDisabled
    }
}
