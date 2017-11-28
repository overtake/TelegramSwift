//
//  Appearance.swift
//  Telegram
//
//  Created by keepcoder on 22/06/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

private func generateChatMention(backgroundColor: NSColor, border: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(38, 38), contextGenerator: { size, ctx in
        ctx.clear(CGRect(origin: CGPoint(), size: size))
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        ctx.setLineWidth(1.0)
        ctx.setStrokeColor(border.withAlphaComponent(0.7).cgColor)
        ctx.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))

        let icon = #imageLiteral(resourceName: "Icon_ChatMention").precomposed(foregroundColor)
        let imageRect = NSMakeRect(floorToScreenPixels((size.width - icon.backingSize.width) / 2), floorToScreenPixels((size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        
        ctx.draw(icon, in: imageRect)
    })!
}

private func generateBadgeMention(backgroundColor: NSColor, foregroundColor: NSColor) -> CGImage {
    return generateImage(NSMakeSize(20, 20), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(backgroundColor.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let icon = #imageLiteral(resourceName: "Icon_ChatListMention").precomposed(foregroundColor, flipVertical: true)
        let imageRect = NSMakeRect(floorToScreenPixels((size.width - icon.backingSize.width) / 2), floorToScreenPixels((size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}

private func generateChatGroupToggleSelected(foregroundColor: NSColor) -> CGImage {
    let icon = #imageLiteral(resourceName: "Icon_Check").precomposed(foregroundColor)
    return generateImage(NSMakeSize(icon.backingSize.width + 1, icon.backingSize.height + 1), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size, size.width/2)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
        let imageRect = NSMakeRect(floorToScreenPixels((size.width - icon.backingSize.width) / 2), floorToScreenPixels((size.height - icon.backingSize.height) / 2), icon.backingSize.width, icon.backingSize.height)
        ctx.draw(icon, in: imageRect)
    })!
}


private func deleteItemIcon(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(24,24), contextGenerator: { (size, ctx) in
        ctx.clear(NSMakeRect(0,0,size.width,size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: NSMakeRect(0,0,size.width,size.height))
        ctx.setFillColor(.white)
        ctx.fill(NSMakeRect(6,11,12,2))
    })!
}
private func generateStickerBackground(_ size: NSSize, _ color: NSColor) -> CGImage {
    return generateImage(size, contextGenerator: { size,ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.round(size)
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(0, 0, size.width, size.height))
    })!
}


private func downloadFilePauseIcon(_ color: NSColor) -> CGImage {
    return generateImage(CGSize(width: 11.0, height: 11.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
        context.fill(CGRect(x: 2.0 + 2.0 + 2.0, y: 0.0, width: 2.0, height: 11.0 - 1.0))
    })!
}


private func generateSendingFrame(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: {(size,ctx) in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(1.0)
        ctx.strokeEllipse(in: NSMakeRect(1.0, 1.0,size.width - 2,size.height - 2))
    })!
}
private func generateSendingHour(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(5,5,4,1.5))
    })!
}
private func generateSendingMin(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(12, 12), contextGenerator: { size, ctx in
        ctx.clear(NSMakeRect(0, 0, size.width, size.height))
        ctx.setFillColor(color.cgColor)
        ctx.fill(NSMakeRect(5, 5, 4, 1))
    })!
}

private func generateChatScrolldownImage(backgroundColor: NSColor, borderColor: NSColor, arrowColor: NSColor) -> CGImage {
    return generateImage(CGSize(width: 38.0, height: 38.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        context.setLineWidth(1.0)
        context.setStrokeColor(borderColor.withAlphaComponent(0.7).cgColor)
        context.strokeEllipse(in: CGRect(origin: CGPoint(x: 1.0, y: 1.0), size: CGSize(width: size.width - 2.0, height: size.height - 2.0)))
        context.setStrokeColor(arrowColor.cgColor)
        context.setLineWidth(1.0)
        
        context.setStrokeColor(arrowColor.cgColor)
        let position = CGPoint(x: 9.0 - 0.5, y: 23.0)
        context.move(to: CGPoint(x: position.x + 1.0, y: position.y - 1.0))
        context.addLine(to: CGPoint(x: position.x + 10.0, y: position.y - 10.0))
        context.addLine(to: CGPoint(x: position.x + 19.0, y: position.y - 1.0))
        context.strokePath()
    })!
}

private func generateRecentActionsTriangle(_ color: NSColor) -> CGImage {
    return generateImage(NSMakeSize(10, 8), contextGenerator: { (size, ctx) in
        let bounds = NSMakeRect(0, 0, size.width, size.height)
        ctx.clear(bounds)
        ctx.beginPath()
        ctx.move(to: NSMakePoint(bounds.minX, bounds.minY))
        ctx.addLine(to: NSMakePoint(bounds.midX, bounds.maxY))
        ctx.addLine(to: NSMakePoint(bounds.maxX, bounds.minY))
        ctx.closePath()
        
        ctx.setFillColor(color.cgColor);
        ctx.fillPath();
        
    }, opaque: false)!
}

var blueActionButton:ControlStyle {
    return ControlStyle(font: NSFont.normal(.title), foregroundColor: theme.colors.blueUI)
}
var redActionButton:ControlStyle {
    return ControlStyle(font: .normal(.title), foregroundColor: theme.colors.redUI)
}



class ActivitiesTheme {
    let text:[CGImage]
    let uploading:[CGImage]
    let recording:[CGImage]
    let textColor:NSColor
    let backgroundColor:NSColor
    init(text:[CGImage], uploading:[CGImage], recording:[CGImage], textColor:NSColor, backgroundColor:NSColor) {
        self.text = text
        self.uploading = uploading
        self.recording = recording
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }
}


final class TelegramTabBarTheme  {
    let color: NSColor
    let selectedColor: NSColor
    let badgeTextColor: NSColor
    let badgeColor: NSColor
    private let resources: PresentationsResourceCache = PresentationsResourceCache()
    init(color: NSColor, selectedColor: NSColor, badgeTextColor: NSColor, badgeColor: NSColor) {
        self.color = color
        self.selectedColor = selectedColor
        self.badgeTextColor = badgeTextColor
        self.badgeColor = badgeColor
    }
    
    func icon(key:Int32, image: NSImage, selected: Bool) -> CGImage {
        let color = self.color
        let selectedColor = self.selectedColor
        return resources.image(key + (selected ? 10 : 0), { () -> CGImage in
            return image.precomposed(selected ? selectedColor : color)
        })
    }
}




struct TelegramIconsTheme {
    let dialogMuteImage: CGImage
    let dialogMuteImageSelected: CGImage
    let outgoingMessageImage: CGImage
    let readMessageImage: CGImage
    let outgoingMessageImageSelected: CGImage
    let readMessageImageSelected: CGImage
    let sendingImage: CGImage
    let sendingImageSelected: CGImage
    let secretImage:CGImage
    let secretImageSelected: CGImage
    let pinnedImage: CGImage
    let pinnedImageSelected: CGImage
    let verifiedImage: CGImage
    let verifiedImageSelected: CGImage
    let errorImage: CGImage
    let errorImageSelected: CGImage
    
    let chatSearch: CGImage
    let chatCall: CGImage
    let chatActions: CGImage
    
    let chatOutgoingFailedCall: CGImage
    let chatIncomingFailedCall: CGImage
    let chatOutgoingCall: CGImage
    let chatIncomingCall: CGImage
    let chatFallbackCall: CGImage
    
    let chatToggleSelected: CGImage
    let chatToggleUnselected: CGImage
    let chatShare: CGImage
    let chatMusicPlay: CGImage
    let chatMusicPause: CGImage
    
    let composeNewChat:CGImage
    let composeNewChatActive: CGImage
    let composeNewGroup:CGImage
    let composeNewSecretChat: CGImage
    let composeNewChannel: CGImage
    
    let contactsNewContact: CGImage
    
    let chatReadMark1: CGImage
    let chatReadMark2: CGImage
    let sentFailed: CGImage
    let chatChannelViews:CGImage
    
    let chatNavigationBack: CGImage
    
    let peerInfoAddMember: CGImage
    

    let chatSearchUp: CGImage
    let chatSearchUpDisabled: CGImage
    let chatSearchDown: CGImage
    let chatSearchDownDisabled: CGImage
    let chatSearchCalendar: CGImage
    
    let dismissAccessory: CGImage
    
    let chatScrollUp: CGImage
    let chatScrollUpActive: CGImage
    

    let audioPlayerPlay: CGImage
    let audioPlayerPause: CGImage
    let audioPlayerNext: CGImage
    let audioPlayerPrev: CGImage
    let auduiPlayerDismiss: CGImage
    let audioPlayerRepeat: CGImage
    let audioPlayerRepeatActive: CGImage
    
    let audioPlayerLockedPlay: CGImage
    let audioPlayerLockedNext: CGImage
    let audioPlayerLockedPrev: CGImage
    

    
    let chatSendMessage: CGImage
    let chatRecordVoice: CGImage
    let chatEntertainment: CGImage
    let chatInlineDismiss: CGImage
    let chatActiveReplyMarkup: CGImage
    let chatDisabledReplyMarkup: CGImage
    let chatSecretTimer: CGImage

    let chatForwardMessagesActive: CGImage
    let chatForwardMessagesInactive: CGImage
    let chatDeleteMessagesActive: CGImage
    let chatDeleteMessagesInactive: CGImage
    
    let generalNext: CGImage
    let generalSelect: CGImage


    let chatVoiceRecording: CGImage
    let chatVideoRecording: CGImage
    let chatRecord: CGImage
    
    let deleteItem: CGImage
    let deleteItemDisabled: CGImage
    
    let chatAttach: CGImage
    let chatAttachFile: CGImage
    let chatAttachPhoto: CGImage
    let chatAttachCamera: CGImage
    let chatAttachLocation: CGImage
    
    let mediaEmptyShared: CGImage
    let mediaEmptyFiles: CGImage
    let mediaEmptyMusic: CGImage
    let mediaEmptyLinks: CGImage
    
    let mediaDropdown: CGImage
    
    let stickersAddFeatured: CGImage
    let stickersAddedFeatured: CGImage
    let stickersRemove: CGImage
    
    let peerMediaDownloadFileStart: CGImage
    let peerMediaDownloadFilePause: CGImage
    
    let stickersShare: CGImage
    
    let emojiRecentTab: CGImage
    let emojiSmileTab: CGImage
    let emojiNatureTab: CGImage
    let emojiFoodTab: CGImage
    let emojiSportTab: CGImage
    let emojiCarTab: CGImage
    let emojiObjectsTab: CGImage
    let emojiSymbolsTab: CGImage
    let emojiFlagsTab: CGImage
    
    let emojiRecentTabActive: CGImage
    let emojiSmileTabActive: CGImage
    let emojiNatureTabActive: CGImage
    let emojiFoodTabActive: CGImage
    let emojiSportTabActive: CGImage
    let emojiCarTabActive: CGImage
    let emojiObjectsTabActive: CGImage
    let emojiSymbolsTabActive: CGImage
    let emojiFlagsTabActive: CGImage
    
    let stickerBackground: CGImage
    let stickerBackgroundActive: CGImage
    let stickersTabRecent: CGImage
    let stickersTabGIF: CGImage
    
    let chatSendingFrame: CGImage
    let chatSendingHour: CGImage
    let chatSendingMin: CGImage
    let chatActionUrl: CGImage

    let callInlineDecline: CGImage
    let callInlineMuted: CGImage
    let callInlineUnmuted: CGImage
    let eventLogTriangle: CGImage
    let channelIntro: CGImage
    let chatFileThumb: CGImage
    let chatSecretThumb: CGImage
    let chatMapPin: CGImage
    let chatSecretTitle: CGImage
    let emptySearch: CGImage
    let calendarBack: CGImage
    let calendarNext: CGImage
    let calendarBackDisabled: CGImage
    let calendarNextDisabled: CGImage
    let newChatCamera: CGImage
    let peerInfoVerify: CGImage
    let peerInfoCall: CGImage
    let callOutgoing: CGImage
    let recentDismiss: CGImage
    let recentDismissActive: CGImage
    let webgameShare: CGImage
    
    let chatSearchCancel: CGImage
    let chatSearchFrom: CGImage
    
    let callWindowDecline: CGImage
    let callWindowAccept: CGImage
    let callWindowMute: CGImage
    let callWindowUnmute: CGImage
    let callWindowClose: CGImage
    let callWindowDeviceSettings: CGImage
    let callWindowCancel: CGImage
    
    let chatActionEdit: CGImage
    let chatActionInfo: CGImage
    let chatActionMute: CGImage
    let chatActionUnmute: CGImage
    let chatActionClearHistory: CGImage
    
    let dismissPinned: CGImage
    let chatActionsActive: CGImage
    let chatEntertainmentSticker: CGImage
    let chatEmpty: CGImage
    let stickerPackClose: CGImage
    let stickerPackDelete: CGImage
    
    let modalShare: CGImage
    let modalClose: CGImage
    
    let ivChannelJoined: CGImage
    let chatListMention: CGImage
    let chatListMentionActive: CGImage
    
    let chatMention: CGImage
    let chatMentionActive: CGImage
    
    let sliderControl: CGImage
    let sliderControlActive: CGImage
    
    let stickersTabFave: CGImage
    let chatInstantView: CGImage
    
    let instantViewShare: CGImage
    let instantViewActions: CGImage
    let instantViewActionsActive: CGImage
    let instantViewSafari: CGImage
    let instantViewBack: CGImage
    let instantViewCheck: CGImage
    
    let groupStickerNotFound: CGImage
    
    let settingsAskQuestion: CGImage
    let settingsBio: CGImage
    let settingsEditInfo: CGImage
    let settingsFaq: CGImage
    let settingsGeneral: CGImage
    let settingsLanguage: CGImage
    let settingsNotifications: CGImage
    let settingsPhoneNumber: CGImage
    let settingsSecurity: CGImage
    let settingsStickers: CGImage
    let settingsStorage: CGImage
    let settingsUsername: CGImage
    
    let generalCheck: CGImage
    let settingsAbout: CGImage
    let settingsLogout: CGImage
    
    let fastSettingsLock: CGImage
    let fastSettingsDark: CGImage
    let fastSettingsSunny: CGImage
    let fastSettingsMute: CGImage
    let fastSettingsUnmute: CGImage
    
    let chatRecordVideo: CGImage
    
    let inputChannelMute: CGImage
    let inputChannelUnmute: CGImage
    
    let changePhoneNumberIntro: CGImage
    
    let peerSavedMessages: CGImage
    
    let previewCollage: CGImage
    let chatGoMessage: CGImage
    
    let chatGroupToggleSelected: CGImage
    let chatGroupToggleUnselected: CGImage
    
    let successModalProgress: CGImage
}

final class TelegramChatListTheme {
    let selectedBackgroundColor: NSColor
    let singleLayoutSelectedBackgroundColor: NSColor
    let activeDraggingBackgroundColor: NSColor
    let pinnedBackgroundColor: NSColor
    let contextMenuBackgroundColor: NSColor
    
    let textColor: NSColor
    let grayTextColor: NSColor
    let secretChatTextColor: NSColor
    let peerTextColor: NSColor
    
    let activityColor: NSColor
    let activitySelectedColor: NSColor
    let activityContextMenuColor: NSColor
    let activityPinnedColor: NSColor
    
    let badgeTextColor: NSColor
    let badgeBackgroundColor: NSColor
    let badgeSelectedTextColor: NSColor
    let badgeSelectedBackgroundColor: NSColor
    let badgeMutedTextColor: NSColor
    let badgeMutedBackgroundColor: NSColor
    

    init(selectedBackgroundColor: NSColor, singleLayoutSelectedBackgroundColor: NSColor, activeDraggingBackgroundColor: NSColor, pinnedBackgroundColor: NSColor, contextMenuBackgroundColor: NSColor, textColor: NSColor, grayTextColor: NSColor, secretChatTextColor: NSColor, peerTextColor: NSColor, activityColor: NSColor, activitySelectedColor: NSColor, activityContextMenuColor: NSColor, activityPinnedColor: NSColor, badgeTextColor: NSColor, badgeBackgroundColor: NSColor, badgeSelectedTextColor: NSColor, badgeSelectedBackgroundColor: NSColor,  badgeMutedTextColor: NSColor, badgeMutedBackgroundColor: NSColor) {
        
        
        self.selectedBackgroundColor = selectedBackgroundColor
        self.singleLayoutSelectedBackgroundColor = singleLayoutSelectedBackgroundColor
        self.activeDraggingBackgroundColor = activeDraggingBackgroundColor
        self.pinnedBackgroundColor = pinnedBackgroundColor
        self.contextMenuBackgroundColor = contextMenuBackgroundColor
        self.textColor = textColor
        self.grayTextColor = grayTextColor
        self.secretChatTextColor = secretChatTextColor
        self.peerTextColor = peerTextColor
        
        self.activityColor = activityColor
        self.activitySelectedColor = activitySelectedColor
        self.activityPinnedColor = activityPinnedColor
        self.activityContextMenuColor = activityContextMenuColor
        
        self.badgeTextColor = badgeTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeSelectedTextColor = badgeSelectedTextColor
        self.badgeSelectedBackgroundColor = badgeSelectedBackgroundColor
        self.badgeMutedTextColor = badgeMutedTextColor
        self.badgeMutedBackgroundColor = badgeMutedBackgroundColor

    }
}

extension ColorPallete {
    init(_ settings: ThemePalleteSettings) {
        self.init(background: settings.background, text: settings.text, grayText: settings.grayText, link: settings.link, blueUI: settings.blueUI, redUI: settings.redUI, greenUI: settings.greenUI, blackTransparent: settings.blackTransparent, grayTransparent: settings.grayTransparent, grayUI: settings.grayUI, darkGrayText: settings.darkGrayText, blueText: settings.blueText, blueSelect: settings.blueSelect, selectText: settings.selectText, blueFill: settings.blueFill, border: settings.border, grayBackground: settings.grayBackground, grayForeground: settings.grayForeground, grayIcon: settings.grayIcon, blueIcon: settings.blueIcon, badgeMuted: settings.badgeMuted, badge: settings.badge, indicatorColor: settings.indicatorColor, selectMessage: settings.selectMessage)
    }
}

extension TelegramPresentationTheme {
    var appearance: NSAppearance? {
        return dark ? NSAppearance(named: NSAppearance.Name.vibrantDark) : NSAppearance(named: NSAppearance.Name.vibrantLight)
    }
}

class TelegramPresentationTheme : PresentationTheme {
    let chatList:TelegramChatListTheme
    let tabBar:TelegramTabBarTheme
    let icons: TelegramIconsTheme
    let dark: Bool
    let fontSize: CGFloat
    init(colors: ColorPallete, search: SearchTheme, chatList: TelegramChatListTheme, tabBar: TelegramTabBarTheme, icons: TelegramIconsTheme, dark: Bool, fontSize: CGFloat) {
        self.chatList = chatList
        self.tabBar = tabBar
        self.icons = icons
        self.dark = dark
        self.fontSize = fontSize
        super.init(colors: colors, search: search)
    }
    
    func activity(key:Int32, foregroundColor: NSColor, backgroundColor: NSColor) -> ActivitiesTheme {
        return activityResources.object(key, { () -> AnyObject in
            return ActivitiesTheme(text: textActivityAnimation(foregroundColor), uploading: uploadFileActivityAnimation(foregroundColor, backgroundColor), recording: recordVoiceActivityAnimation(foregroundColor), textColor: foregroundColor, backgroundColor: backgroundColor)
        }) as! ActivitiesTheme
    }
    
    private let activityResources: PresentationsResourceCache = PresentationsResourceCache()
    
}

let _themeSignal:ValuePromise<TelegramPresentationTheme> = ValuePromise(ignoreRepeated: true)

var themeSignal:Signal<TelegramPresentationTheme, Void> {
    return _themeSignal.get() |> distinctUntilChanged |> deliverOnMainQueue
}




private func generateIcons(from pallete: ColorPallete) -> TelegramIconsTheme {
    return TelegramIconsTheme(dialogMuteImage: #imageLiteral(resourceName: "Icon_DialogMute").precomposed(pallete.grayIcon),
                                               dialogMuteImageSelected: #imageLiteral(resourceName: "Icon_DialogMute").precomposed(.white),
                                               outgoingMessageImage: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(pallete.blueIcon, flipVertical:true),
                                               readMessageImage: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(pallete.blueIcon, flipVertical:true),
                                               outgoingMessageImageSelected: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white, flipVertical:true),
                                               readMessageImageSelected: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(.white, flipVertical:true),
                                               sendingImage: #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(pallete.grayIcon, flipVertical:true),
                                               sendingImageSelected: #imageLiteral(resourceName: "Icon_ChatStateSending").precomposed(.white, flipVertical:true),
                                               secretImage:#imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(pallete.blueIcon, flipVertical:true),
                                               secretImageSelected: #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(.white, flipVertical:true),
                                               pinnedImage: #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(pallete.grayIcon, flipVertical:true),
                                               pinnedImageSelected: #imageLiteral(resourceName: "Icon_ChatListPinned").precomposed(.white, flipVertical:true),
                                               verifiedImage: #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true),
                                               verifiedImageSelected: #imageLiteral(resourceName: "Icon_VerifyPeerActive").precomposed(flipVertical: true),
                                               errorImage: #imageLiteral(resourceName: "Icon_DialogSendingError").precomposed(flipVertical: true),
                                               errorImageSelected: #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(flipVertical: true),
                                               chatSearch: #imageLiteral(resourceName: "Icon_SearchChatMessages").precomposed(pallete.blueIcon),
                                               chatCall: #imageLiteral(resourceName: "Icon_callNavigationHeader").precomposed(pallete.blueIcon),
                                               chatActions: #imageLiteral(resourceName: "Icon_ChatActions").precomposed(pallete.blueIcon),
                                               chatOutgoingFailedCall: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(pallete.redUI),
                                               chatIncomingFailedCall: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(pallete.redUI),
                                               chatOutgoingCall: #imageLiteral(resourceName: "Icon_MessageCallOutgoing").precomposed(pallete.greenUI),
                                               chatIncomingCall: #imageLiteral(resourceName: "Icon_MessageCallIncoming").precomposed(pallete.greenUI),
                                               chatFallbackCall: #imageLiteral(resourceName: "Icon_MessageCall").precomposed(pallete.blueUI),
                                               chatToggleSelected: #imageLiteral(resourceName: "Icon_Check").precomposed(pallete.blueIcon),
                                               chatToggleUnselected: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(),
                                               chatShare: #imageLiteral(resourceName: "Icon_ChannelShare").precomposed(pallete.blueIcon),
                                               chatMusicPlay: #imageLiteral(resourceName: "Icon_ChatMusicPlay").precomposed(),
                                               chatMusicPause: #imageLiteral(resourceName: "Icon_ChatMusicPause").precomposed(),
                                               composeNewChat:#imageLiteral(resourceName: "Icon_NewMessage").precomposed(pallete.blueIcon),
                                               composeNewChatActive:#imageLiteral(resourceName: "Icon_NewMessage").precomposed(.white),
                                               composeNewGroup:#imageLiteral(resourceName: "Icon_NewGroup").precomposed(pallete.blueIcon),
                                               composeNewSecretChat: #imageLiteral(resourceName: "Icon_NewSecretChat").precomposed(pallete.blueIcon),
                                               composeNewChannel: #imageLiteral(resourceName: "Icon_NewChannel").precomposed(pallete.blueIcon),
                                               contactsNewContact: #imageLiteral(resourceName: "Icon_NewContact").precomposed(pallete.blueIcon),
                                               chatReadMark1: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(pallete.blueIcon),
                                               chatReadMark2: #imageLiteral(resourceName: "Icon_MessageCheckmark2").precomposed(pallete.blueIcon),
                                               sentFailed: #imageLiteral(resourceName: "Icon_MessageSentFailed").precomposed(),
                                               chatChannelViews: #imageLiteral(resourceName: "Icon_ChannelViews").precomposed(pallete.grayIcon, flipVertical: true),
                                               chatNavigationBack: #imageLiteral(resourceName: "Icon_ChatNavigationBack").precomposed(pallete.blueIcon),
                                               peerInfoAddMember: #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(pallete.blueIcon, flipVertical: true),
                                               chatSearchUp: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(pallete.blueIcon),
                                               chatSearchUpDisabled: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(pallete.grayIcon),
                                               chatSearchDown: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(pallete.blueIcon, flipVertical:true),
                                               chatSearchDownDisabled: #imageLiteral(resourceName: "Icon_SearchArrow").precomposed(pallete.grayIcon, flipVertical:true),
                                               chatSearchCalendar: #imageLiteral(resourceName: "Icon_Calendar").precomposed(pallete.blueIcon),
                                               dismissAccessory: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.grayIcon),
                                               chatScrollUp: generateChatScrolldownImage(backgroundColor: pallete.background, borderColor: pallete.grayIcon, arrowColor: pallete.grayIcon),
                                               chatScrollUpActive: generateChatScrolldownImage(backgroundColor: pallete.background, borderColor: pallete.blueIcon, arrowColor: pallete.blueIcon),
                                               audioPlayerPlay: #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(pallete.blueIcon),
                                               audioPlayerPause: #imageLiteral(resourceName: "Icon_InlinePlayerPause").precomposed(pallete.blueIcon),
                                               audioPlayerNext: #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(pallete.blueIcon),
                                               audioPlayerPrev: #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(pallete.blueIcon),
                                               auduiPlayerDismiss: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.blueIcon),
                                               audioPlayerRepeat: #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(pallete.grayIcon),
                                               audioPlayerRepeatActive: #imageLiteral(resourceName: "Icon_RepeatAudio").precomposed(pallete.blueIcon),
                                               audioPlayerLockedPlay: #imageLiteral(resourceName: "Icon_InlinePlayerPlay").precomposed(pallete.grayIcon),
                                               audioPlayerLockedNext: #imageLiteral(resourceName: "Icon_InlinePlayerNext").precomposed(pallete.grayIcon),
                                               audioPlayerLockedPrev: #imageLiteral(resourceName: "Icon_InlinePlayerPrevious").precomposed(pallete.grayIcon),
                                               chatSendMessage: #imageLiteral(resourceName: "Icon_SendMessage").precomposed(pallete.blueIcon),
                                               chatRecordVoice: #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(pallete.grayIcon),
                                               chatEntertainment: #imageLiteral(resourceName: "Icon_Entertainments").precomposed(pallete.grayIcon),
                                               chatInlineDismiss: #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(pallete.grayIcon),
                                               chatActiveReplyMarkup: #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(pallete.blueIcon),
                                               chatDisabledReplyMarkup: #imageLiteral(resourceName: "Icon_ReplyMarkupButton").precomposed(pallete.grayIcon),
                                               chatSecretTimer: #imageLiteral(resourceName: "Icon_SecretTimer").precomposed(pallete.grayIcon),
                                               chatForwardMessagesActive: #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(pallete.blueIcon),
                                               chatForwardMessagesInactive: #imageLiteral(resourceName: "Icon_MessageActionPanelForward").precomposed(pallete.grayIcon),
                                               chatDeleteMessagesActive: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(pallete.redUI),
                                               chatDeleteMessagesInactive: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(pallete.grayIcon),
                                               generalNext: #imageLiteral(resourceName: "Icon_GeneralNext").precomposed(pallete.grayIcon),
                                               generalSelect: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(pallete.blueIcon),
                                               chatVoiceRecording: #imageLiteral(resourceName: "Icon_RecordingVoice").precomposed(pallete.blueIcon),
                                               chatVideoRecording: #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(pallete.blueIcon),
                                               chatRecord: #imageLiteral(resourceName: "Icon_RecordVoice").precomposed(pallete.grayIcon),
                                               deleteItem: deleteItemIcon(pallete.redUI),
                                               deleteItemDisabled: deleteItemIcon(pallete.grayTransparent),
                                               chatAttach: #imageLiteral(resourceName: "Icon_ChatAttach").precomposed(pallete.grayIcon),
                                               chatAttachFile: #imageLiteral(resourceName: "Icon_AttachFile").precomposed(pallete.blueIcon),
                                               chatAttachPhoto: #imageLiteral(resourceName: "Icon_AttachPhoto").precomposed(pallete.blueIcon),
                                               chatAttachCamera: #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(pallete.blueIcon),
                                               chatAttachLocation: #imageLiteral(resourceName: "Icon_AttachLocation").precomposed(pallete.blueIcon),
                                               mediaEmptyShared: #imageLiteral(resourceName: "Icon_EmptySharedMedia").precomposed(pallete.grayIcon),
                                               mediaEmptyFiles: #imageLiteral(resourceName: "Icon_EmptySharedFiles").precomposed(),
                                               mediaEmptyMusic: #imageLiteral(resourceName: "Icon_EmptySharedMusic").precomposed(pallete.grayIcon),
                                               mediaEmptyLinks: #imageLiteral(resourceName: "Icon_EmptySharedLinks").precomposed(pallete.grayIcon),
                                               mediaDropdown: #imageLiteral(resourceName: "Icon_DropdownArrow").precomposed(pallete.blueIcon),
                                               stickersAddFeatured: #imageLiteral(resourceName: "Icon_GroupInfoAddMember").precomposed(pallete.blueIcon),
                                               stickersAddedFeatured: #imageLiteral(resourceName: "Icon_UsernameAvailability").precomposed(pallete.grayIcon),
                                               stickersRemove: #imageLiteral(resourceName: "Icon_InlineResultCancel").precomposed(pallete.grayIcon),
                                               peerMediaDownloadFileStart: #imageLiteral(resourceName: "Icon_MediaDownload").precomposed(pallete.blueIcon),
                                               peerMediaDownloadFilePause: downloadFilePauseIcon(pallete.blueIcon),
                                               stickersShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(pallete.blueIcon),
                                               emojiRecentTab: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSmileTab: #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiNatureTab: #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFoodTab: #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSportTab: #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiCarTab: #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiObjectsTab: #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSymbolsTab: #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFlagsTab: #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(pallete.grayIcon, flipVertical:true, flipHorizontal:true),
                                               emojiRecentTabActive: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSmileTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSmiles").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiNatureTabActive: #imageLiteral(resourceName: "Icon_EmojiTabNature").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFoodTabActive: #imageLiteral(resourceName: "Icon_EmojiTabFood").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSportTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSports").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiCarTabActive: #imageLiteral(resourceName: "Icon_EmojiTabCar").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiObjectsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabObjects").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiSymbolsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabSymbols").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               emojiFlagsTabActive: #imageLiteral(resourceName: "Icon_EmojiTabFlag").precomposed(pallete.blueIcon, flipVertical:true, flipHorizontal:true),
                                               stickerBackground: generateStickerBackground(NSMakeSize(83, 83), pallete.background),
                                               stickerBackgroundActive: generateStickerBackground(NSMakeSize(83, 83), pallete.grayBackground),
                                               stickersTabRecent: #imageLiteral(resourceName: "Icon_EmojiTabRecent").precomposed(pallete.grayIcon),
                                               stickersTabGIF: #imageLiteral(resourceName: "Icon_GifToggle").precomposed(pallete.grayIcon),
                                               chatSendingFrame: generateSendingFrame(pallete.grayIcon),
                                               chatSendingHour: generateSendingHour(pallete.grayIcon),
                                               chatSendingMin: generateSendingMin(pallete.grayIcon),
                                               chatActionUrl: #imageLiteral(resourceName: "Icon_InlineBotUrl").precomposed(pallete.text),
                                               callInlineDecline: #imageLiteral(resourceName: "Icon_CallDecline_Inline").precomposed(.white),
                                               callInlineMuted: #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(.white),
                                               callInlineUnmuted: #imageLiteral(resourceName: "Icon_CallUnmuted_Inline").precomposed(.white),
                                               eventLogTriangle: generateRecentActionsTriangle(pallete.text),
                                               channelIntro: #imageLiteral(resourceName: "Icon_ChannelIntro").precomposed(),
                                               chatFileThumb: #imageLiteral(resourceName: "Icon_MessageFile").precomposed(flipVertical:true),
                                               chatSecretThumb: #imageLiteral(resourceName: "Icon_SecretAutoremoveMedia").precomposed(.black, flipVertical:true),
                                               chatMapPin: #imageLiteral(resourceName: "Icon_MapPinned").precomposed(),
                                               chatSecretTitle: #imageLiteral(resourceName: "Icon_SecretChatLock").precomposed(pallete.text, flipVertical:true),
                                               emptySearch: #imageLiteral(resourceName: "Icon_EmptySearchResults").precomposed(pallete.grayIcon),
                                               calendarBack: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(pallete.blueIcon),
                                               calendarNext: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(pallete.blueIcon, flipHorizontal: true),
                                               calendarBackDisabled: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(pallete.grayIcon),
                                               calendarNextDisabled: #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(pallete.grayIcon, flipHorizontal: true),
                                               newChatCamera: #imageLiteral(resourceName: "Icon_AttachCamera").precomposed(pallete.grayIcon),
                                               peerInfoVerify: #imageLiteral(resourceName: "Icon_VerifyPeer").precomposed(flipVertical: true),
                                               peerInfoCall: #imageLiteral(resourceName: "Icon_ProfileCall").precomposed(pallete.blueUI),
                                               callOutgoing: #imageLiteral(resourceName: "Icon_CallOutgoing").precomposed(pallete.grayIcon, flipVertical: true),
                                               recentDismiss: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(pallete.grayIcon),
                                               recentDismissActive: #imageLiteral(resourceName: "Icon_SearchClear").precomposed(.white),
                                               webgameShare: #imageLiteral(resourceName: "Icon_ShareExternal").precomposed(pallete.blueIcon),
                                               chatSearchCancel: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.blueIcon),
                                               chatSearchFrom: #imageLiteral(resourceName: "Icon_ChatSearchFrom").precomposed(pallete.blueIcon),
                                               callWindowDecline: #imageLiteral(resourceName: "Icon_CallDecline_Window").precomposed(),
                                               callWindowAccept: #imageLiteral(resourceName: "Icon_CallAccept_Window").precomposed(),
                                               callWindowMute: #imageLiteral(resourceName: "Icon_CallMic_Window").precomposed(),
                                               callWindowUnmute: #imageLiteral(resourceName: "Icon_CallMute_Inline").precomposed(),
                                               callWindowClose: #imageLiteral(resourceName: "Icon_CallWindowClose").precomposed(.white),
                                               callWindowDeviceSettings: #imageLiteral(resourceName: "Icon_CallDeviceSettings").precomposed(.white),
                                               callWindowCancel: #imageLiteral(resourceName: "Icon_CallCancelIcon").precomposed(.white),
                                               chatActionEdit: #imageLiteral(resourceName: "Icon_ChatActionEdit").precomposed(pallete.blueIcon),
                                               chatActionInfo: #imageLiteral(resourceName: "Icon_ChatActionInfo").precomposed(pallete.blueIcon),
                                               chatActionMute: #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(pallete.blueIcon),
                                               chatActionUnmute: #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(pallete.blueIcon),
                                               chatActionClearHistory: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(pallete.blueIcon),
                                               dismissPinned: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.blueIcon),
                                               chatActionsActive: #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(pallete.blueIcon),
                                               chatEntertainmentSticker: #imageLiteral(resourceName: "Icon_ChatEntertainmentSticker").precomposed(pallete.grayIcon),
                                               chatEmpty: #imageLiteral(resourceName: "Icon_EmptyChat").precomposed(pallete.grayForeground),
                                               stickerPackClose: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.blueIcon),
                                               stickerPackDelete: #imageLiteral(resourceName: "Icon_MessageActionPanelDelete").precomposed(pallete.blueIcon),
                                               modalShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(pallete.blueIcon),
                                               modalClose: #imageLiteral(resourceName: "Icon_ChatSearchCancel").precomposed(pallete.blueIcon),
                                               ivChannelJoined: #imageLiteral(resourceName: "Icon_MessageCheckMark1").precomposed(.white),
                                               chatListMention: generateBadgeMention(backgroundColor: pallete.blueUI, foregroundColor: pallete.background),
                                               chatListMentionActive: generateBadgeMention(backgroundColor: pallete.background, foregroundColor: pallete.blueUI),
                                               chatMention: generateChatMention(backgroundColor: pallete.background, border: pallete.grayIcon, foregroundColor: pallete.grayIcon),
                                               chatMentionActive: generateChatMention(backgroundColor: pallete.background, border: pallete.blueIcon, foregroundColor: pallete.blueIcon),
                                               sliderControl: #imageLiteral(resourceName: "Icon_SliderNormal").precomposed(),
                                               sliderControlActive: #imageLiteral(resourceName: "Icon_SliderNormal").precomposed(),
                                               stickersTabFave: #imageLiteral(resourceName: "Icon_FaveStickers").precomposed(pallete.grayIcon),
                                               chatInstantView: #imageLiteral(resourceName: "Icon_ChatIV").precomposed(pallete.blueIcon),
                                               instantViewShare: #imageLiteral(resourceName: "Icon_ShareStickerPack").precomposed(pallete.blueIcon),
                                               instantViewActions: #imageLiteral(resourceName: "Icon_ChatActions").precomposed(pallete.blueIcon),
                                               instantViewActionsActive: #imageLiteral(resourceName: "Icon_ChatActionsActive").precomposed(pallete.blueIcon),
                                               instantViewSafari: #imageLiteral(resourceName: "Icon_InstantViewSafari").precomposed(pallete.blueIcon),
                                               instantViewBack: #imageLiteral(resourceName: "Icon_InstantViewBack").precomposed(pallete.blueIcon),
                                               instantViewCheck: #imageLiteral(resourceName: "Icon_InstantViewCheck").precomposed(pallete.blueIcon),
                                               groupStickerNotFound: #imageLiteral(resourceName: "Icon_GroupStickerNotFound").precomposed(pallete.grayIcon),
                                               settingsAskQuestion: #imageLiteral(resourceName: "Icon_SettingsAskQuestion").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsBio: #imageLiteral(resourceName: "Icon_SettingsBio").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsEditInfo: #imageLiteral(resourceName: "Icon_SettingsEditInfo").precomposed(pallete.blueIcon),
                                               settingsFaq: #imageLiteral(resourceName: "Icon_SettingsFaq").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsGeneral: #imageLiteral(resourceName: "Icon_SettingsGeneral").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsLanguage: #imageLiteral(resourceName: "Icon_SettingsLanguage").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsNotifications: #imageLiteral(resourceName: "Icon_SettingsNotifications").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsPhoneNumber: #imageLiteral(resourceName: "Icon_SettingsPhoneNumber").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsSecurity: #imageLiteral(resourceName: "Icon_SettingsSecurity").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsStickers: #imageLiteral(resourceName: "Icon_SettingsStickers").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsStorage: #imageLiteral(resourceName: "Icon_SettingsStorage").precomposed(pallete.blueIcon, flipVertical: true),
                                               settingsUsername: #imageLiteral(resourceName: "Icon_SettingsUsername").precomposed(pallete.blueIcon, flipVertical: true),
                                               generalCheck: #imageLiteral(resourceName: "Icon_Check").precomposed(pallete.blueIcon),
                                               settingsAbout: #imageLiteral(resourceName: "Icon_SettingsAbout").precomposed(pallete.blueIcon),
                                               settingsLogout: #imageLiteral(resourceName: "Icon_SettingsLogout").precomposed(pallete.redUI),
                                               fastSettingsLock: #imageLiteral(resourceName: "Icon_FastSettingsLock").precomposed(pallete.blueIcon),
                                               fastSettingsDark: #imageLiteral(resourceName: "Icon_FastSettingsDark").precomposed(pallete.blueIcon),
                                               fastSettingsSunny: #imageLiteral(resourceName: "Icon_FastSettingsSunny").precomposed(pallete.blueIcon),
                                               fastSettingsMute: #imageLiteral(resourceName: "Icon_ChatActionMute").precomposed(pallete.blueIcon),
                                               fastSettingsUnmute: #imageLiteral(resourceName: "Icon_ChatActionUnmute").precomposed(pallete.blueIcon),
                                               chatRecordVideo: #imageLiteral(resourceName: "Icon_RecordVideoMessage").precomposed(pallete.grayIcon),
                                               inputChannelMute: #imageLiteral(resourceName: "Icon_InputChannelMute").precomposed(pallete.grayIcon),
                                               inputChannelUnmute: #imageLiteral(resourceName: "Icon_InputChannelUnmute").precomposed(pallete.grayIcon),
                                               changePhoneNumberIntro: #imageLiteral(resourceName: "Icon_ChangeNumberIntro").precomposed(),
                                               peerSavedMessages: #imageLiteral(resourceName: "Icon_SavedMessages").precomposed(),
                                               previewCollage: #imageLiteral(resourceName: "Icon_PreviewCollage").precomposed(pallete.grayIcon),
                                               chatGoMessage: #imageLiteral(resourceName: "Icon_ChatGoMessage").precomposed(pallete.blueIcon),
                                               chatGroupToggleSelected: generateChatGroupToggleSelected(foregroundColor: pallete.blueIcon),
                                               chatGroupToggleUnselected: #imageLiteral(resourceName: "Icon_SelectionUncheck").precomposed(),
                                               successModalProgress: #imageLiteral(resourceName: "Icon_ProgressWindowCheck").precomposed())
}


private func generateTheme(pallete: ColorPallete, dark: Bool, fontSize: CGFloat) -> TelegramPresentationTheme {
    
    let chatList = TelegramChatListTheme(selectedBackgroundColor: pallete.blueSelect,
                                         singleLayoutSelectedBackgroundColor: pallete.grayBackground,
                                         activeDraggingBackgroundColor: pallete.border,
                                         pinnedBackgroundColor: pallete.background,
                                         contextMenuBackgroundColor: pallete.background,
                                         textColor: pallete.text,
                                         grayTextColor: pallete.grayText,
                                         secretChatTextColor: pallete.blueUI,
                                         peerTextColor: pallete.text,
                                         activityColor: pallete.blueUI,
                                         activitySelectedColor: .white,
                                         activityContextMenuColor: pallete.blueUI,
                                         activityPinnedColor: pallete.blueUI,
                                         badgeTextColor: pallete.background,
                                         badgeBackgroundColor: pallete.badge,
                                         badgeSelectedTextColor: pallete.blueSelect,
                                         badgeSelectedBackgroundColor: .white,
                                         badgeMutedTextColor: .white,
                                         badgeMutedBackgroundColor: pallete.badgeMuted)
    
    let tabBar = TelegramTabBarTheme(color: pallete.grayIcon, selectedColor: pallete.blueIcon, badgeTextColor: .white, badgeColor: pallete.redUI)
    return TelegramPresentationTheme(colors: pallete, search: SearchTheme(pallete.grayBackground, #imageLiteral(resourceName: "Icon_SearchField").precomposed(pallete.grayIcon), #imageLiteral(resourceName: "Icon_SearchClear").precomposed(pallete.grayIcon), tr(.searchFieldSearch), pallete.text, pallete.grayText), chatList: chatList, tabBar: tabBar, icons: generateIcons(from: pallete), dark: dark, fontSize: fontSize)
}


func updateTheme(with settings: ThemePalleteSettings, for window: Window? = nil, animated: Bool = false) {
    telegramUpdateTheme(generateTheme(pallete: settings.dark ? darkPallete  : whitePallete, dark: settings.dark, fontSize: settings.fontSize), window: window, animated: animated)
}

private let appearanceDisposable = MetaDisposable()

private func telegramUpdateTheme(_ theme: TelegramPresentationTheme, window: Window? = nil, animated: Bool) {
    assertOnMainThread()
    updateTheme(theme)
    if let window = window {
        
        if animated, let contentView = window.contentView {
            
            var indexes:[Int] = []
            for i in 0 ..< contentView.subviews.count {
                if contentView.subviews[i] is ImageView {
                    indexes.insert(i, at: 0)
                }
            }
            
            for index in indexes {
                contentView.subviews[index].removeFromSuperview()
            }
            
            let image = window.windowImageShot()
            let imageView = ImageView()
            imageView.image = image
            imageView.frame = contentView.superview!.bounds
            contentView.addSubview(imageView)

            
            appearanceDisposable.set((Signal<Void, Void>.single(Void()) |> delay(0.3, queue: Queue.mainQueue())).start(completed: { [weak imageView] in
                if let strongImageView = imageView {
                    strongImageView.change(opacity: 0, animated: true, removeOnCompletion: false, duration: 0.2, completion: { [weak strongImageView] completed in
                        strongImageView?.removeFromSuperview()
                    })
                }
            
            }))
            
        }
        window.contentView?.background = theme.colors.background
        window.contentView?.subviews.first?.background = theme.colors.background
        window.appearance = theme.appearance
        window.backgroundColor = theme.colors.grayBackground
        window.titlebarAppearsTransparent = true//theme.dark
    }
    _themeSignal.set(theme)
}

func setDefaultTheme(for window: Window? = nil) {
    telegramUpdateTheme(generateTheme(pallete: whitePallete, dark: false, fontSize: 13.0), window: window, animated: false)
}


