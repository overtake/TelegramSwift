//
//  GlobalLinks.swift
//  Telegram-Mac
//
//  Created by keepcoder on 18/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Foundation
import TGUIKit
import TelegramCore
import TGModernGrowingTextView
import Postbox
import SwiftSignalKit
import MtProtoKit
import ThemeSettings
import Translate
import InputView
import TelegramMedia


private func hTmeParseDuration(_ durationStr: String) -> Int {
    // Optional hours, optional minutes, optional seconds
    let pattern = "^(?:(\\d+)h)?(?:(\\d+)m)?(?:(\\d+)s)?$"
    
    // Attempt to create the regex
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
        // If regex creation fails, fallback to integer parsing
        return Int(durationStr) ?? 0
    }
    
    // Search for a match
    let range = NSRange(durationStr.startIndex..., in: durationStr)
    if let match = regex.firstMatch(in: durationStr, options: [], range: range) {
        // Extract capture groups for hours, minutes, and seconds
        let hoursRange = match.range(at: 1)
        let minutesRange = match.range(at: 2)
        let secondsRange = match.range(at: 3)
        
        // Helper to safely extract integer from a matched range
        func intValue(_ nsRange: NSRange) -> Int {
            guard nsRange.location != NSNotFound,
                  let substringRange = Range(nsRange, in: durationStr) else {
                return 0
            }
            return Int(durationStr[substringRange]) ?? 0
        }
        
        let hours = intValue(hoursRange)
        let minutes = intValue(minutesRange)
        let seconds = intValue(secondsRange)
        
        return hours * 3600 + minutes * 60 + seconds
    }
    
    // If the string didn't match the pattern, parse it as a positive integer
    return Int(durationStr) ?? 0
}


let itunesAppLink = "https://apps.apple.com/us/app/telegram/id747648890"

let XTR: String = LocalTelegramCurrency.xtr.rawValue
let XTRSTAR: String = "⭐️"
let XTR_ICON = "Icon_Peer_Premium"
let TINY_SPACE = "\u{2009}\u{2009}"
let TINY = "\u{2009}"
var GOLD: NSColor {
    return theme.colors.isDark ? NSColor(0xF5C555) : NSColor(0xD2720B)
}
let clown: String = "🤡"

let clown_space: String = "\(clown)\(TINY_SPACE)"


let focusIntentEmoji = "⛔️"

let XTR_USD_RATE = 0.013

#if DEBUG
let star_sub_period: Int32 = 300
#else
let star_sub_period: Int32 = 2592000
#endif

let TON: String = LocalTelegramCurrency.ton.rawValue

enum LocalTelegramCurrency : String {
    case xtr = "XTR"
    case ton = "TON"
    
    var logo: LocalAnimatedSticker {
        switch self {
        case .xtr:
            return .star_currency_new
        case .ton:
            return .ton_logo
        }
    }
    
    func colored(_ color: NSColor) -> [LottieColor] {
        switch self {
        case .xtr:
            return []
        case .ton:
            return [.init(keyPath: "", color: color)]
        }
    }
}

extension ResolvePeerResult : Equatable {
    var result: EnginePeer? {
        switch self {
        case .progress:
            return nil
        case let .result(peer):
            return peer
        }
    }
    public static func ==(lhs: ResolvePeerResult, rhs: ResolvePeerResult) -> Bool {
        switch lhs {
        case .progress:
            if case .progress = rhs {
                return true
            } else {
                return false
            }
        case let .result(lhsPeer):
            if case let .result(rhsPeer) = rhs {
                return PeerEquatable(lhsPeer?._asPeer()) == PeerEquatable(rhsPeer?._asPeer())
            } else {
                return false
            }
        }
    }
}

private let inapp:String = "chat://"
private let tgme:String = "tg://"




private struct UrlHandlingConfiguration {
    static var defaultValue: UrlHandlingConfiguration {
        return UrlHandlingConfiguration(token: nil, domains: [], urlAuthDomains: [])
    }
    
    public let token: String?
    public let domains: [String]
    public let urlAuthDomains: [String]
    
    fileprivate init(token: String?, domains: [String], urlAuthDomains: [String]) {
        self.token = token
        self.domains = domains
        self.urlAuthDomains = urlAuthDomains
    }
    
    static func with(appConfiguration: AppConfiguration) -> UrlHandlingConfiguration {
        if let data = appConfiguration.data {
            let urlAuthDomains = data["url_auth_domains"] as? [String] ?? []
            if let token = data["autologin_token"] as? String, let domains = data["autologin_domains"] as? [String] {
                return UrlHandlingConfiguration(token: token, domains: domains, urlAuthDomains: urlAuthDomains)
            }
        }
        return .defaultValue
    }
}




func resolveUsername(username: String, context: AccountContext) -> Signal<Peer?, NoError> {
    if username.hasPrefix(_private_), let range = username.range(of: _private_) {
        if let channelId = Int64(username[range.upperBound...]), let id = PeerId._optionalInternalFromInt64Value(channelId) {
            let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
            
            let peerSignal: Signal<Peer?, NoError> = context.account.postbox.transaction { transaction -> Peer? in
                return transaction.getPeer(peerId)
                } |> mapToSignal { peer in
                    if let peer = peer {
                        return .single(peer)
                    } else {
                        return context.engine.peers.findChannelById(channelId: peerId.id._internalGetInt64Value()) |> map { $0?._asPeer() }
                    }
            }
            
            return peerSignal |> deliverOnMainQueue |> map { peer in
                if let peer = peer {
                    if let peer = peer as? TelegramChannel {
                        if peer.participationStatus != .member {
                            return nil
                        }
                    }
                }
                return peer
            }
        } else {
            return .single(nil)
        }
    } else {
        return context.engine.peers.resolvePeerByName(name: username, referrer: nil) |> filter { $0 != .progress } |> mapToSignal { result -> Signal<Peer?, NoError> in
            return .single(result.result?._asPeer())
        } |> deliverOnMainQueue
    }
    
}

enum InAppSettingsSection : String {
    case themes
    case devices
    case folders
    case privacy
    case phone_privacy
}

enum ChatInitialActionBehavior : Equatable {
    case none
    case automatic
}

enum ChatInitialAction : Equatable {
    case start(parameter: String, behavior: ChatInitialActionBehavior)
    case inputText(text: ChatTextInputState, behavior: ChatInitialActionBehavior)
    case files(list: [String], behavior: ChatInitialActionBehavior)
    case forward(messageIds: [MessageId], text: ChatTextInputState?, behavior: ChatInitialActionBehavior)
    case reply(EngineMessageReplySubject, behavior: ChatInitialActionBehavior)
    case ad(EngineChatList.AdditionalItem.PromoInfo.Content)
    case source(MessageId, Int32?)
    case closeAfter(Int32)
    case selectToReport(reason: ReportReasonValue)
    case joinVoiceChat(_ joinHash: String?)
    case attachBot(_ bot: String, _ payload: String?, _ choose:[String]?)
    case makeWebview(appname: String, command: String?)
    case openWebview(botPeer: PeerEquatable, botApp: BotApp, result: RequestWebViewResult)

    case openMedia(_ timemark: Int32?)
    var selectionNeeded: Bool {
        switch self {
        case .selectToReport:
            return true
        default:
            return false
        }
    }
}



var globalLinkExecutor:TextViewInteractions {
    get {
        return TextViewInteractions(processURL:{(link) in
            if let link = link as? inAppLink {
                switch link {
                case .requestSecureId:
                    break // never execute from inapp
                default:
                    execute(inapp:link)
                }
            }
        }, isDomainLink: { value, origin in
            if let value = value as? inAppLink {
                switch value {
                case .external:
                    return true
                default:
                    if let origin = origin {
                        if origin != value.link, !origin.isEmpty && origin != "‌" {
                            return true
                        }
                    }
                    return false
                }
            }
            return false
        }, makeLinkType: { link, url in
            if let link = link as? inAppLink {
                switch link {
                case .botCommand:
                    return .command
                case .hashtag:
                    return .hashtag
                case .code:
                    return .code
                case .followResolvedName:
                    if url.hasPrefix("@") {
                        return .username
                    } else {
                        return .plain
                    }
                case let .external(link, _):
                    if isValidEmail(link) {
                        return .email
                    } else if telegram_me.first(where: {link.contains($0 + "joinchat/")}) != nil {
                        return .inviteLink
                    } else {
                        return .plain
                    }
                case let .stickerPack(_, source, _, _):
                    switch source {
                    case .emoji:
                        return .emojiPack
                    case .stickers:
                        return .stickerPack
                    }
                case .joinchat:
                    return .inviteLink
                default:
                    return .plain
                }
            }
            return .plain
        }, localizeLinkCopy: { type in
            return copyContextText(from: type)
        }, resolveLink: { link in
            return (link as? inAppLink)?.link
        }, copyAttributedString: { string in
            let pb = NSPasteboard.general

 
            let modified: NSMutableAttributedString = string.mutableCopy() as! NSMutableAttributedString
            
            var replaceRanges:[(NSRange, String)] = []
            
            string.enumerateAttributes(in: string.range, options: [.reverse], using: { attr, range, _ in
                if let appLink = attr[NSAttributedString.Key.link] as? inAppLink {
                    switch appLink {
                    case .code, .hashtag, .callback:
                        break
                    default:
                        if appLink.link != modified.string.nsstring.substring(with: range) {
                            modified.addAttribute(TextInputAttributes.textUrl, value: TextInputTextUrlAttribute(url: appLink.link), range: range)
                        }
                    }
                }
                if let sticker = attr[TextInputAttributes.embedded] as? InlineStickerItem {
                    if case let .attribute(emoji) = sticker.source {
                        modified.addAttribute(TextInputAttributes.customEmoji, value: TextInputTextCustomEmojiAttribute(fileId: emoji.fileId, file: emoji.file, emoji: emoji.emoji), range: range)
                        replaceRanges.append((range, emoji.emoji))
                    }
                }
            })
            
            for range in replaceRanges.sorted(by: { $0.0.lowerBound > $1.0.lowerBound }) {
                modified.replaceCharacters(in: range.0, with: range.1)
            }
            
            //modified.removeAttribute(TextInputAttributes.quote, range: modified.range)
            modified.removeAttribute(TextInputAttributes.code, range: modified.range)
            modified.removeAttribute(TextInputAttributes.monospace, range: modified.range)

            let input = ChatTextInputState(attributedText: modified, selectionRange: 0 ..< modified.length)
            
            if !modified.string.isEmpty {
                pb.clearContents()
                let rtf = try? modified.data(from: modified.range, documentAttributes: [NSAttributedString.DocumentAttributeKey.documentType : NSAttributedString.DocumentType.rtf])
                
                
                pb.declareTypes([.rtf, .kInApp], owner: nil)

                let encoder = AdaptedPostboxEncoder()
                let encoded = try? encoder.encode(input)
                
                if let data = encoded {
                    pb.setData(data, forType: .kInApp)
                }
                if let rtf = rtf {
                    pb.setData(rtf, forType: .rtf)
                    pb.setString(modified.string, forType: .string)
                    return true
                }
            }
            
            return false
        }, translate: { text, window in
            let language = Translate.detectLanguage(for: text)
            let toLang = appAppearance.languageCode
            var current: AccountContext?
            appDelegate?.enumerateAccountContexts({ context in
                if context.window === window {
                    current = context
                }
            })
            
            if language != toLang, let context = current {
                return ContextMenuItem(strings().chatContextTranslate, handler: {
                    showModal(with: TranslateModalController(context: context, from: language, toLang: toLang, text: text), for: context.window)
                }, itemImage: MenuAnimation.menu_translate.value)
            } else {
                return nil
            }
        })
    }
}

func copyContextText(from type: LinkType) -> String {
    switch type {
    case .username:
        return strings().textContextCopyUsername
    case .command:
        return strings().textContextCopyCommand
    case .hashtag:
        return strings().textContextCopyHashtag
    case .email:
        return strings().textContextCopyEmail
    case .plain:
        return strings().textContextCopyLink
    case .inviteLink:
        return strings().textContextCopyInviteLink
    case .stickerPack:
        return strings().textContextCopyStickerPack
    case .emojiPack:
        return strings().textContextCopyEmojiPack
    case .code:
        return strings().textContextCopyCode
    }
}

func execute(inapp:inAppLink, window: Window? = nil, afterComplete: @escaping(Bool)->Void = { _ in }) {
    
    let getWindow:(AccountContext)->Window = { context in
        return window ?? context.window
    }
    
    switch inapp {
    case let .external(link, needConfirm):
        
        if link.isEmpty {
            return
        }
        var url:String = link.trimmed

        var reversedUrl = String(url.reversed())
        while reversedUrl.components(separatedBy: "#").count > 2 {
            if let index = reversedUrl.range(of: "#") {
                reversedUrl.replaceSubrange(index, with: "32%")
            }
        }
        url = String(reversedUrl.reversed())
        if isValidEmail(url) {
            if !url.hasPrefix("mailto:") {
                url = "mailto:" + url
            }
        } else if !url.hasPrefix("http") && !url.hasPrefix("ftp") {
            if let range = url.range(of: "://") {
                if url.length > 10, range.lowerBound > url.index(url.startIndex, offsetBy: 10) {
                    url = "http://" + url
                }
            } else if !url.hasPrefix("mailto:") {
                url = "http://" + url
            }
        }
        
        let urlValue = url


        let escaped = escape(with:url)
        if let urlQueryAllowed = Optional(escaped) {
            if let url = URL(string: urlQueryAllowed) ?? URL(string: urlValue) {
                var needConfirm = needConfirm || url.host != URL(string: urlValue)?.host
                
                
                if needConfirm {
                    let allowed = appDelegate?.allowedDomains ?? []
                    if let url = URL(string: urlValue) {
                        if let host = url.host, allowed.contains(host) {
                            needConfirm = false
                        }
                    }
                }

                if let withToken = appDelegate?.tryApplyAutologinToken(url.absoluteString), let url = URL(string: withToken) {
                    NSWorkspace.shared.open(url)
                    afterComplete(true)
                    return
                }
                
                let removePecentEncoding = url.host == URL(string: urlValue)?.host
                let success:()->Void = {
                    
                    var path = url.absoluteString
                    let supportSchemes:[String] = ["itunes.apple.com"]
                    for scheme in supportSchemes {
                        var url:URL? = nil
                        if path.contains(scheme) {
                            switch scheme {
                            case supportSchemes[0]: // itunes
                               path = "itms://" + path.nsstring.substring(from: path.nsstring.range(of: scheme).location)
                               url = URL(string: path)
                            default:
                                continue
                            }
                        }
                        if let url = url {
                            NSWorkspace.shared.open(url)
                            afterComplete(true)
                            return
                        }
                    }
                    afterComplete(true)
                    NSWorkspace.shared.open(url)
                }
                if needConfirm {
                    verifyAlert_button(for: mainWindow, header: strings().inAppLinksConfirmOpenExternalHeader, information: strings().inAppLinksConfirmOpenExternalNew(removePecentEncoding ? (url.absoluteString.removingPercentEncoding ?? url.absoluteString) : escaped), ok: strings().inAppLinksConfirmOpenExternalOK, successHandler: {_ in success()}, cancelHandler: { afterComplete(false) })
                } else {
                    success()
                }
            }
            
        }
    case let .peerInfo(_, peerId, action, openChat, postId, callback):
        let messageId:MessageId?
        if let postId = postId {
            messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: MessageId.Id(postId))
        } else {
            messageId = nil
        }
        callback(peerId, openChat, messageId, action)
        afterComplete(true)
    case let .comments(_, username, context, threadId, commentId):
        
        enum Error {
            case doesntExists
            case privateAccess
            case generic
        }
        
        var peerSignal: Signal<Peer, Error> = .fail(.doesntExists)
        if username.hasPrefix(_private_), let range = username.range(of: _private_) {
            if let channelId = Int64(username[range.upperBound...]), let id = PeerId._optionalInternalFromInt64Value(channelId) {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
                peerSignal = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                } |> mapToSignalPromotingError { peer in
                    if let peer = peer {
                        return .single(peer)
                    } else {
                        return context.engine.peers.findChannelById(channelId: peerId.id._internalGetInt64Value())
                            |> mapToSignalPromotingError { value in
                                if let value = value {
                                    return .single(value._asPeer())
                                } else {
                                    return .fail(.privateAccess)
                                }
                            }
                        
                    }
                }
            }
        } else {
            peerSignal = context.engine.peers.resolvePeerByName(name: username, referrer: nil) |> filter { $0 != .progress } |> mapToSignalPromotingError { result -> Signal<Peer, Error> in
                if let result = result.result {
                    return .single(result._asPeer())
                } else {
                    return .fail(.doesntExists)
                }
            } |> mapError { _ in
                return .doesntExists
            }
        }
        
        let signal:Signal<(ThreadInfo, Peer), Error> = peerSignal |> mapToSignal { peer in
            let messageId: MessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: threadId)
            return fetchAndPreloadReplyThreadInfo(context: context, subject: peer.isChannel ? .channelPost(messageId) : .groupMessage(messageId))
                |> map {
                    return ($0, peer)
                } |> mapError { error in
                    switch error {
                    case .generic:
                        return .generic
                    }
            }
        } |> deliverOnMainQueue

        
        _ = showModalProgress(signal: signal |> take(1), for: getWindow(context)).start(next: { values in
            let (result, peer) = values
            let threadMessageId: MessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: threadId)
            let navigation = context.bindings.rootNavigation()
            let current = navigation.controller as? ChatController
            
            if let current = current, current.chatInteraction.chatLocation.threadId == result.message.threadId {
                if let commentId = commentId {
                    let commentMessageId = MessageId(peerId: result.message.peerId, namespace: Namespaces.Message.Cloud, id: commentId)
                    current.chatInteraction.focusMessageId(nil, .init(messageId: commentMessageId, string: nil), .CenterEmpty)
                }
            } else {
                let mode: ReplyThreadMode
                if peer.isChannel {
                    mode = .comments(origin: threadMessageId)
                } else if peer.isForum {
                    mode = .topic(origin: threadMessageId)
                } else {
                    mode = .replies(origin: threadMessageId)
                }
                var commentMessageId: MessageId? = nil
                if let commentId = commentId {
                    commentMessageId = MessageId(peerId: result.message.peerId, namespace: Namespaces.Message.Cloud, id: commentId)
                }
                
                navigation.push(ChatAdditionController(context: context, chatLocation: .thread(result.message), mode: .thread(mode: mode), focusTarget: .init(messageId: commentMessageId), initialAction: nil, chatLocationContextHolder: result.contextHolder))
            }
        }, error: { error in
            switch error {
            case .doesntExists:
                showModalText(for: getWindow(context), text: strings().alertUserDoesntExists)
            case .privateAccess:
                showModalText(for: getWindow(context), text: strings().alertPrivateChannelAccessError)
            case .generic:
                break
            }
        })
        
        afterComplete(true)
    case let .topic(_, username, context, threadId, commentId):
        
        enum Error {
            case doesntExists
            case privateAccess
            case generic
        }
        
        var peerSignal: Signal<Peer, Error> = .fail(.doesntExists)
        if username.hasPrefix(_private_), let range = username.range(of: _private_) {
            if let channelId = Int64(username[range.upperBound...]), let id = PeerId._optionalInternalFromInt64Value(channelId) {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
                peerSignal = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                } |> mapToSignalPromotingError { peer in
                    if let peer = peer {
                        return .single(peer)
                    } else {
                        return context.engine.peers.findChannelById(channelId: peerId.id._internalGetInt64Value())
                            |> mapToSignalPromotingError { value in
                                if let value = value {
                                    return .single(value._asPeer())
                                } else {
                                    return .fail(.privateAccess)
                                }
                            }
                        
                    }
                }
            }
        } else {
            peerSignal = context.engine.peers.resolvePeerByName(name: username, referrer: nil) |> filter { $0 != .progress} |> mapToSignalPromotingError { result -> Signal<Peer, Error> in
                if let result = result.result {
                    return .single(result._asPeer())
                } else {
                    return .fail(.doesntExists)
                }
            } |> mapError { _ in
                return .doesntExists
            }
        }
        _ = (peerSignal |> deliverOnMainQueue).start(next: { peer in
            var toMessageId: MessageId? = nil
            if let commentId = commentId {
                toMessageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: commentId)
            }
            _ = ForumUI.openTopic(Int64(threadId), peerId: peer.id, context: context, messageId: toMessageId, animated: true, addition: true).start()
        }, error: { error in
            switch error {
            case .doesntExists:
                showModalText(for: getWindow(context), text: strings().alertUserDoesntExists)
            case .privateAccess:
                showModalText(for: getWindow(context), text: strings().alertPrivateChannelAccessError)
            case .generic:
                break
            }
        })

        afterComplete(true)
    case let .followResolvedName(_, username, postId, forceProfile, context, action, callback):
        
        let invokeCallback:(Peer, MessageId?, ChatInitialAction?) -> Void = { peer, messageId, action in
            if peer.isForum {
                closeAllModals(window: getWindow(context))
                if let messageId = messageId {
                    
                    _ = (context.engine.messages.getMessagesLoadIfNecessary([messageId]) |> deliverOnMainQueue).start(next: { result in
                        switch result {
                        case .progress:
                            break
                        case let .result(messages):
                            if let threadId = messages.first?.threadId {
                                _ = ForumUI.openTopic(threadId, peerId: peer.id, context: context, messageId: nil, animated: true, addition: true).start(next: { result in
                                    if !result {
                                        ForumUI.open(peer.id, addition: true, context: context)
                                    }
                                })
                            }
                        }
                        
                    })
                    
                    
                } else {
                    ForumUI.open(peer.id, addition: true, context: context)
                }
            } else {
                let openChat: Bool
                if case .inputText = action {
                    openChat = true
                } else {
                    openChat = false
                }
                callback(peer.id, (peer.isChannel || peer.isSupergroup || peer.isBot || openChat) && !forceProfile, messageId, forceProfile ? nil : action)
            }
        }
        
        if username.hasPrefix(_private_), let range = username.range(of: _private_) {
            if let channelId = Int64(username[range.upperBound...]), let id = PeerId._optionalInternalFromInt64Value(channelId) {
                let peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
                
                let peerSignal: Signal<Peer?, NoError> = context.account.postbox.transaction { transaction -> Peer? in
                    return transaction.getPeer(peerId)
                    } |> mapToSignal { peer in
                        if let peer = peer {
                            return .single(peer)
                        } else {
                            return context.engine.peers.findChannelById(channelId: peerId.id._internalGetInt64Value()) |> map { $0?._asPeer() }
                        }
                }
                
                _ = showModalProgress(signal: peerSignal |> deliverOnMainQueue, for: getWindow(context)).start(next: { peer in
                    if let peer = peer {
                        let messageId:MessageId?
                        if let postId = postId {
                            messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: postId)
                        } else {
                            messageId = nil
                        }
                        if let peer = peer as? TelegramChannel {
                            if peer.participationStatus == .kicked {
                                showModalText(for: getWindow(context), text: strings().alertPrivateChannelAccessError)
                                return
                            }
                        }
                        invokeCallback(peer, messageId, action)
                    } else {
                        showModalText(for: getWindow(context), text: strings().alertPrivateChannelAccessError)
                    }
                })
            } else {
                showModalText(for: getWindow(context), text: strings().alertPrivateChannelAccessError)
            }
        } else {
            let phone = username.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            let signal: Signal<EnginePeer?, NoError>
            if phone == username {
                signal = context.engine.peers.resolvePeerByPhone(phone: phone)
            } else {
                let referrer: String?
                if let action {
                    switch action {
                    case let .start(parameter, _):
                        let prefix = context.appConfiguration.getStringValue("starref_start_param_prefixes", orElse: "_tgref_")
                        if parameter.hasPrefix(prefix) {
                            referrer = String(parameter.suffix(parameter.length - prefix.length))
                        } else {
                            referrer = nil
                        }
                    default:
                        referrer = nil
                    }
                } else {
                    referrer = nil
                }
                signal = context.engine.peers.resolvePeerByName(name: username, referrer: referrer) |> filter { $0 != .progress } |> map { $0.result }
            }
                
            let _ = showModalProgress(signal: signal |> mapToSignal { result -> Signal<Peer?, NoError> in
                return .single(result?._asPeer())
            } |> deliverOnMainQueue, for: getWindow(context)).start(next: { peer in
                if let peer = peer {
                    let messageId:MessageId?
                    if let postId = postId {
                        messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: postId)
                    } else {
                        messageId = nil
                    }
                    
                    if peer.isBot {
                        if let action = action {
                            switch action {
                            case let .attachBot(botname, _, choose):
                                
                                let standart = ["users", "groups", "channels", "bots"]
                                
                                if let choose = choose, choose.count == 1, !choose.contains(where: { value in standart.contains(value) }) {
                                    let signal = context.engine.peers.resolvePeerByName(name: choose[0], referrer: nil) |> filter { $0 != .progress } |> deliverOnMainQueue
                                    
                                    _ = signal.start(next: { peer in
                                        if let peer = peer.result {
                                            invokeCallback(peer._asPeer(), messageId, action)
                                        }
                                    })

                                } else {
                                    let invoke:(Peer)->Void = { peer in
                                        let signal = context.engine.messages.getAttachMenuBot(botId: peer.id)
                                        let openAttach:()->Void = {
                                            let chat = context.bindings.rootNavigation().controller as? ChatController
                                            chat?.chatInteraction.invokeInitialAction(action: action)
                                        }
                                        _ = showModalProgress(signal: signal, for: getWindow(context)).start(next: { _ in
                                            openAttach()
                                        }, error: { _ in
                                            if peer.username == botname {
                                                openAttach()
                                            } else {
                                                callback(peer.id, peer.isChannel || peer.isSupergroup || peer.isBot, messageId, action)
                                            }
                                        })
                                    }
                                    if let choose = choose, !choose.isEmpty {
                                        var settings:SelectPeerSettings = .init()
                                        if choose.contains("users") {
                                            settings.insert(.contacts)
                                            settings.insert(.remote)
                                        }
                                        if choose.contains("bots") {
                                            settings.insert(.bots)
                                        }
                                        if choose.contains("groups") {
                                            settings.insert(.groups)
                                        }
                                        if choose.contains("channels") {
                                            settings.insert(.channels)
                                        }
                                        
                                        _ = selectModalPeers(window: getWindow(context), context: context, title: strings().selectPeersTitleSelectChat, limit: 1, behavior: SelectChatsBehavior(settings: settings, excludePeerIds: [], limit: 1)).start(next: { peerIds in
                                            if let peerId = peerIds.first {
                                                let signal = context.account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue
                                                _ = signal.start(next: { peer in
                                                    invoke(peer)
                                                })
                                            }
                                        })
                                    } else {
                                        invoke(peer)
                                    }
                                }
                                
                            case let .makeWebview(appname, command):
                                
                                if !appname.isEmpty  {
                                    let botApp = context.engine.messages.getBotApp(botId: peer.id, shortName: appname)
                                    
                                    let chat = context.bindings.rootNavigation().first {
                                        $0 is ChatController
                                    } as? ChatController
                                    
                                    let peerId = chat?.chatLocation.peerId ?? peer.id
                                    
                                    let openWebview:(ChatInitialAction)->Void = { action in
                                        let chat = context.bindings.rootNavigation().first {
                                            $0 is ChatController
                                        } as? ChatController
                                        
                                        if chat == nil {
                                            switch action {
                                            case let .openWebview(botPeer, botApp, result):
                                                BrowserStateContext.get(context).open(tab: .straight(bot: .init(botPeer.peer), peerId: peerId, title: botApp.title, result: result))
                                            default:
                                                break
                                            }
                                        } else {
                                            chat?.chatInteraction.invokeInitialAction(action: action)
                                        }
                                    }
                                    
                                    let makeRequestAppWebView:(BotApp, Bool)->Signal<(BotApp, RequestWebViewResult?), RequestWebViewError> = { botApp, allowWrite in
                                        return context.engine.messages.requestAppWebView(peerId: peerId, appReference: .id(id: botApp.id, accessHash: botApp.accessHash), payload: command, themeParams: generateWebAppThemeParams(theme), compact: false, fullscreen: false, allowWrite: allowWrite) |> map {
                                            return (botApp, $0)
                                        }
                                    }

                                    var signal: Signal<(BotApp, RequestWebViewResult?), RequestWebViewError> = botApp
                                    |> mapError { _ in
                                        .generic
                                    } |> mapToSignal { botApp in
                                        if botApp.flags.contains(.notActivated) {
                                            return .single((botApp, nil))
                                        } else {
                                            return makeRequestAppWebView(botApp, false)
                                        }
                                    }
                                    signal = showModalProgress(signal: signal, for: getWindow(context))
                                    _ = signal.start(next: { botApp, result in
                                        
                                        if let result = result {
                                            openWebview(.openWebview(botPeer: .init(peer), botApp: botApp, result: result))
                                        } else {
                                            
                                            var options: [ModalAlertData.Option] = []
                                            if botApp.flags.contains(.requiresWriteAccess) {
                                                options.append(.init(string: strings().botAllowSendMessages(peer.displayTitle), isSelected: true, mandatory: true))
                                            }
                                            
                                            let data = ModalAlertData(title: nil, info: strings().webAppFirstOpenTerms(strings().botInfoLaunchInfoPrivacyUrl), description: nil, ok: strings().botLaunchApp, options: options, mode: .confirm(text: strings().modalCancel, isThird: false), header: .init(value: { initialSize, stableId, presentation in
                                                return AlertHeaderItem(initialSize, stableId: stableId, presentation: presentation, context: context, peer: .init(peer), info: strings().botMoreAbout, callback: { _ in
                                                    invokeCallback(peer, nil, nil)
                                                    closeAllModals(window: getWindow(context))
                                                })
                                            }))
                                            
                                            showModalAlert(for: getWindow(context), data: data, completion: { result in
                                                FastSettings.markWebAppAsConfirmed(peer.id)
                                                
                                                let signal = showModalProgress(signal: makeRequestAppWebView(botApp, result.selected[0] ?? false), for: getWindow(context))
                                                
                                                _ = signal.start(next: { botApp, result in
                                                    if let result = result {
                                                        openWebview(.openWebview(botPeer: .init(peer), botApp: botApp, result: result))
                                                    }
                                                }, error: { error in
                                                    switch error {
                                                    case .generic:
                                                        invokeCallback(peer, messageId, nil)
                                                    }
                                                })
                                            })
                                        }
                                    }, error: { error in
                                        switch error {
                                        case .generic:
                                            invokeCallback(peer, messageId, nil)
                                        }
                                    })
                                } else {
                                    BrowserStateContext.get(context).open(tab: .mainapp(bot: .init(peer), source: .inline(startParam: command ?? "")))
                                }
                                
                               
                            default:
                                invokeCallback(peer, messageId, action)
                            }
                        } else {
                            invokeCallback(peer, messageId, action)
                        }
                    } else {
                        invokeCallback(peer, messageId, action)
                    }
                } else {
                    alert(for: getWindow(context), info: strings().alertUserDoesntExists)
                    //showModalText(for: context.window, text: strings().alertUserDoesntExists)
                }
                    
            })
        }
        afterComplete(true)
    case let .inviteBotToGroup(_, username, context, action, rights, isChannel, callback):
        let _ = showModalProgress(signal: context.engine.peers.resolvePeerByName(name: username, referrer: nil) |> filter { $0.result != nil } |> map { $0.result! } |> deliverOnMainQueue, for: getWindow(context)).start(next: { botPeerId in
            
            
            var payload: String = ""
            if let action = action {
                switch action {
                case let .start(data, _):
                    payload = data
                default:
                    break
                }
            }
            let title: String
            if isChannel {
                title = strings().selectPeersTitleSelectChannel
            } else if payload.isEmpty {
                title = strings().selectPeersTitleSelectGroupOrChannel
            } else {
                title = strings().selectPeersTitleSelectGroup
            }
            
            let result = selectModalPeers(window: getWindow(context), context: context, title: title, behavior: SelectChatsBehavior(settings: isChannel ? [.channels, .checkInvite] : payload.isEmpty ? [.groups, .channels, .checkInvite] : [.groups, .checkInvite], limit: 1), confirmation: { peerIds -> Signal<Bool, NoError> in
                return .single(true)
            })
            |> filter { $0.first != nil }
            |> map { $0.first! }
            |> mapToSignal { sourceId in
                return combineLatest( context.account.postbox.loadedPeerWithId(botPeerId._asPeer().id), context.account.postbox.loadedPeerWithId(sourceId)) |> map {
                    (dest: $0, source: $1)
                }
            } |> deliverOnMainQueue
            
                        
            _ = result.start(next: { values in
                     
                
                let add:(PeerId)->Void = { peerId in
                    if payload.isEmpty || values.dest.isChannel {
                        addBotAsMember(context: context, peer: values.source, to: values.dest, completion: { peerId in
                            callback(peerId, true, nil, action)
                        }, error: { error in
                            alert(for: getWindow(context), info: error)
                        })
                    } else {
                        let signal = showModalProgress(signal: context.engine.messages.requestStartBotInGroup(botPeerId: botPeerId._asPeer().id, groupPeerId: peerId, payload: payload), for: context.window)
                            
                        _ = signal.start(next: { result in
                            switch result {
                            case let .channelParticipant(participant):
                                context.peerChannelMemberCategoriesContextsManager.externallyAdded(peerId: peerId, participant: participant)
                            case .none:
                                break
                            }
                            callback(peerId, true, nil, nil)
                        }, error: { error in
                            alert(for: getWindow(context), info: strings().unknownError)
                        })
                    }
                    
                }
                
                let addAdmin:()->Void = {
                    showModal(with: ChannelBotAdminController(context: context, peer: values.source, admin: values.dest, rights: rights, callback: { peerId in
                        add(peerId)
                    }), for: getWindow(context))
                }
                let addSimple:()->Void = {
                    verifyAlert_button(for: getWindow(context), information: strings().confirmAddBotToGroup(values.dest.displayTitle), successHandler: { _ in
                        add(values.dest.id)
                    })
                }
                if let peer = values.source as? TelegramChannel {
                    if peer.groupAccess.isCreator {
                        addAdmin()
                    } else if let adminRights = peer.adminRights, adminRights.rights.contains(.canAddAdmins) {
                        addAdmin()
                    } else {
                        addSimple()
                    }
                } else if let peer = values.source as? TelegramGroup {
                    switch peer.role {
                    case .creator:
                        addAdmin()
                    default:
                        addSimple()
                    }
                }
            })
            
        })
        afterComplete(true)
    case let .botCommand(command, interaction):
        interaction(command)
        afterComplete(true)
    case let .hashtag(hashtag, interaction):
        interaction(hashtag)
        afterComplete(true)
    case let .joinchat(_, hash, context, interaction):
        
        let openForum:(PeerId)->Void = { peerId in
            ForumUI.open(peerId, addition: true, context: context)
        }
        
//        #if DEBUG
//        showModal(with: Star_PurschaseInApp(context: context, invoice: nil, source: .starsChatSubscription(hash: hash), type: .subscription(500)), for: getWindow(context))
//        return
//        #endif
        
        
        _ = showModalProgress(signal: context.engine.peers.joinLinkInformation(hash), for: getWindow(context)).start(next: { (result) in
            switch result {
            case let .alreadyJoined(peer):
                if peer._asPeer().isForum {
                    openForum(peer.id)
                } else {
                    interaction(peer.id, true, nil, nil)
                }
            case let .invite(state):
                if state.flags.canRefulfillSubscription {
                    _ = showModalProgress(signal: context.engine.peers.joinChannel(peerId: context.peerId, hash: hash), for: getWindow(context))
                } else if let _ = state.subscriptionPricing {
                    showModal(with: Star_PurschaseInApp(context: context, invoice: nil, source: .starsChatSubscription(hash: hash), type: .subscription(state), completion: { state in
                        switch state {
                        case let .paid(_, peerId):
                            if let peerId {
                                delay(1.0, closure: {
                                    interaction(peerId, true, nil, nil)
                                })
                            }
                        default:
                            break
                        }
                        
                    }), for: getWindow(context))
                } else if state.flags.requestNeeded {
                    showModal(with: RequestJoinChatModalController(context: context, joinhash: hash, invite: result, interaction: { peer in
                        if peer.isForum {
                            openForum(peer.id)
                        } else {
                            interaction(peer.id, true, nil, nil)
                        }
                    }), for: getWindow(context))
                } else {
                    showModal(with: JoinLinkPreviewModalController(context, hash: hash, join: result, interaction: { peer in
                        if peer.isForum {
                            openForum(peer.id)
                        } else {
                            interaction(peer.id, true, nil, nil)
                        }
                    }), for: getWindow(context))
                }
            case let .peek(peer, peek):
                if peer._asPeer().isForum {
                    openForum(peer.id)
                } else {
                    interaction(peer.id, true, nil, .closeAfter(peek))
                }
            case .invalidHash:
                showModalText(for: getWindow(context), text: strings().linkExpired)
            }
        })
        afterComplete(true)
    case let .callback(param, interaction):
        interaction(param)
        afterComplete(true)
    case let .code(param, interaction):
        interaction(param)
        afterComplete(true)
    case let .logout(interaction):
        interaction()
        afterComplete(true)
    case let .shareUrl(_, context, url, text):
        if !url.hasPrefix("@") {
            showModal(with: ShareModalController(ShareLinkObject(context, link: url, text: text)), for: getWindow(context))
        }
        afterComplete(true)
    case let .wallpaper(_, context, preview):
        switch preview {
        case let .gradient(id, colors, settings):
            let wallpaper: TelegramWallpaper = .gradient(.init(id: id, colors: colors.map { $0.argb }, settings: settings))
            showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper), source: .link(wallpaper)), for: context.window)
        case let .color(color):
            let wallpaper: TelegramWallpaper = .color(color.argb)
            showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper), source: .link(wallpaper)), for: context.window)
        case let .slug(slug, settings):
            _ = showModalProgress(signal: getWallpaper(network: context.account.network, slug: slug) |> deliverOnMainQueue, for: context.window).start(next: { wallpaper in
                showModal(with: WallpaperPreviewController(context, wallpaper: Wallpaper(wallpaper).withUpdatedSettings(settings), source: .link(wallpaper)), for: context.window)
            }, error: { error in
                switch error {
                case .generic:
                    showModalText(for: getWindow(context), text: strings().wallpaperPreviewDoesntExists)
                }
            })
        }
        afterComplete(true)
    case let .stickerPack(_, reference, context, peerId):
        showModal(with: StickerPackPreviewModalController(context, peerId: peerId, references: [reference]), for: getWindow(context))
        afterComplete(true)
    case let .confirmPhone(_, context, phone, hash):
        _ = showModalProgress(signal: context.engine.auth.requestCancelAccountResetData(hash: hash) |> deliverOnMainQueue, for: context.window).start(next: { data in
            showModal(with: cancelResetAccountController(context: context, phone: phone, data: data), for: context.window)
        }, error: { error in
            switch error {
            case .limitExceeded:
                alert(for: getWindow(context), info: strings().loginFloodWait)
            case .generic:
                alert(for: getWindow(context), info: strings().unknownError)
            }
        })
        afterComplete(true)
    case let .socks(_, settings, applyProxy):
        applyProxy(settings)
        afterComplete(true)
    case .nothing:
        afterComplete(true)
    case let .requestSecureId(_, context, value):
        if value.nonce.isEmpty {
            alert(for: getWindow(context), info: value.isModern ? "nonce is empty" : "payload is empty")
            return
        }
        _ = showModalProgress(signal: (requestSecureIdForm(accountPeerId: context.peerId, postbox: context.account.postbox, network: context.account.network, peerId: value.peerId, scope: value.scope, publicKey: value.publicKey) |> mapToSignal { form in
            return context.account.postbox.loadedPeerWithId(context.peerId) |> castError(RequestSecureIdFormError.self) |> map { peer in
                return (form, peer)
            }
        } |> deliverOnMainQueue), for: getWindow(context)).start(next: { form, peer in
            let passport = PassportWindowController(context: context, peer: peer, request: value, form: form)
            passport.show()
        }, error: { error in
            switch error {
            case .serverError(let text):
                alert(for: getWindow(context), info: text)
            case .generic:
                alert(for: getWindow(context), info: "An error occured")
            case .versionOutdated:
                updateAppAsYouWish(text: strings().secureIdAppVersionOutdated, updateApp: true)
            }
        })
        afterComplete(true)
    case let .applyLocalization(_, context, value):
        _ = showModalProgress(signal: context.engine.localization.requestLocalizationPreview(identifier: value) |> deliverOnMainQueue, for: getWindow(context)).start(next: { info in
            if appAppearance.language.primaryLanguage.languageCode == info.languageCode {
                alert(for: getWindow(context), info: strings().applyLanguageChangeLanguageAlreadyActive(info.title))
            } else if info.totalStringCount == 0 {
                verifyAlert_button(for: getWindow(context), header: strings().applyLanguageUnsufficientDataTitle, information: strings().applyLanguageUnsufficientDataText(info.title), cancel: "", option: strings().applyLanguageUnsufficientDataOpenPlatform, successHandler: { result in
                    switch result {
                    case .basic:
                        break
                    case .thrid:
                        execute(inapp: inAppLink.external(link: info.platformUrl, false))
                    }
                })
            } else {
                showModal(with: LocalizationPreviewModalController(context, info: info), for: getWindow(context))
            }
           
        }, error: { error in
            switch error {
            case .generic:
                alert(for: getWindow(context), info: strings().localizationPreviewErrorGeneric)
            }
        })
        afterComplete(true)
    case let .theme(_, context, name):
        _ = showModalProgress(signal: getTheme(account: context.account, slug: name), for: getWindow(context)).start(next: { value in
            if value.file == nil, let _ = value.settings {
                showModal(with: ThemePreviewModalController(context: context, source: .cloudTheme(value)), for: getWindow(context))
            } else if value.file == nil {
                showEditThemeModalController(context: context, theme: value)
            } else {
                showModal(with: ThemePreviewModalController(context: context, source: .cloudTheme(value)), for: getWindow(context))
            }
        }, error: { error in
            switch error {
            case .generic:
                alert(for: getWindow(context), info: strings().themeGetThemeError)
            case .unsupported:
                alert(for: getWindow(context), info: strings().themeGetThemeError)
            case .slugInvalid:
                alert(for: getWindow(context), info: strings().themeGetThemeError)
            }
        })
        afterComplete(true)
    case let .story(_, username, storyId, messageId, context):
        let signal = showModalProgress(signal: context.engine.peers.resolvePeerByName(name: username, referrer: nil) |> filter { $0 != .progress } |> map { $0.result?._asPeer() }, for: getWindow(context))
        _ = signal.start(next: { peer in
            if let peer = peer {
                let controller = context.bindings.rootNavigation().controller as? ChatController
                if let messageId = messageId, controller?.chatLocation.peerId == messageId.peerId {
                    controller?.chatInteraction.openStory(messageId, .init(peerId: peer.id, id: storyId))
                } else {
                    StoryModalController.ShowSingleStory(context: context, storyId: .init(peerId: peer.id, id: storyId), initialId: nil, emptyCallback: {
                        showModalText(for: getWindow(context), text: strings().storyErrorNotExist)
                    })
                }
            } else {
                showModalText(for: getWindow(context), text: strings().alertUserDoesntExists)
            }
        })
        afterComplete(true)
    case let .unsupportedScheme(_, context, path):
        _ = (context.engine.resolve.getDeepLinkInfo(path: path) |> deliverOnMainQueue).start(next: { info in
            if let info = info {
               updateAppAsYouWish(text: info.message, updateApp: info.updateApp)
            }
        })
        afterComplete(true)
    case .tonTransfer:
        if #available(OSX 10.12, *) {

        }
        afterComplete(true)
    case .instantView:
        afterComplete(true)
    case let .settings(_, context, section):
        let controller: ViewController
        switch section {
        case .themes:
            controller = AppAppearanceViewController(context: context)
        case .devices:
            controller = RecentSessionsController(context)
        case .folders:
            controller = ChatListFiltersListController(context: context)
        case .privacy:
            controller = PrivacyAndSecurityViewController(context, initialSettings: nil, focusOnItemTag: .autoArchive, twoStepVerificationConfiguration: nil)
        case .phone_privacy:
            let privacySignal = context.privacy |> take(1) |> deliverOnMainQueue
            
            let _ = (privacySignal
                |> deliverOnMainQueue).startStandalone(next: { info in
                if let info = info {
                    context.bindings.rootNavigation().push(SelectivePrivacySettingsController(context, kind: .birthday, current: info.birthday, callSettings: nil, phoneDiscoveryEnabled: nil, updated: { updated, updatedCallSettings, _, _ in
                        context.updatePrivacy(updated, kind: .birthday)
                    }))
                }
            })
            afterComplete(true)
            return
        }
        context.bindings.rootNavigation().push(controller)
        afterComplete(true)
    case let .joinGroupCall(_, context, peerId, callId):
        selectGroupCallJoiner(context: context, peerId: peerId, completion: { peerId, schedule, isStream in
            _ = showModalProgress(signal: requestOrJoinGroupCall(context: context, peerId: peerId, joinAs: context.peerId, initialCall: callId, reference: nil), for: getWindow(context)).start(next: { result in
                switch result {
                case let .success(callContext), let .samePeer(callContext):
                    applyGroupCallResult(context.sharedContext, callContext)
                default:
                    alert(for: getWindow(context), info: strings().errorAnError)
                }
            })
        })
       
        afterComplete(true)
    case let .invoice(_, context, slug):
        let signal = showModalProgress(signal: context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug)), for: getWindow(context))
        
        _ = signal.start(next: { invoice in
            if invoice.currency == XTR {
                showModal(with: Star_PurschaseInApp(context: context, invoice: invoice, source: .slug(slug), type: invoice.subscriptionPeriod != nil ? .botSubscription(invoice) : .bot), for: getWindow(context))
            } else {
                showModal(with: PaymentsCheckoutController(context: context, source: .slug(slug), invoice: invoice), for: getWindow(context))
            }
        }, error: { error in
            let text: String
            switch error {
            case .alreadyActive:
                text = strings().paymentsInvoiceAlreadyActive
            case .generic:
                text = strings().paymentsInvoiceNotExists
            case .noPaymentNeeded:
                text = strings().unknownError
            case .disallowedStarGift:
                text = strings().giftSendDisallowError
            case .starGiftResellTooEarly:
                text = strings().unknownError
            case .starGiftUserLimit:
                text = strings().giftOptionsGiftBuyLimitReached
            }
            showModalText(for: getWindow(context), text: text)
        })
        
        afterComplete(true)
    case let .premiumOffer(_, ref, context):
        if !context.premiumIsBlocked {
            if context.isPremium {
                showModalText(for: getWindow(context), text: strings().premiumOffsetAlreadyHave)
            } else {
                if let modal = findModal(PremiumBoardingController.self) {
                    modal.buy()
                } else {
                    prem(with: PremiumBoardingController(context: context, source: .deeplink(ref)), for: getWindow(context))
                }
            }
        }
        afterComplete(true)
    case let .restorePurchase(_, context):
        if let modal = findModal(PremiumBoardingController.self) {
            modal.restore()
        }
        afterComplete(true)
    case let .urlAuth(link, context):
        _ = showModalProgress(signal: context.engine.messages.requestMessageActionUrlAuth(subject: .url(link)), for: getWindow(context)).start(next: { result in
            switch result {
            case let .accepted(url):
                execute(inapp: .external(link: url, false))
            case .default:
                execute(inapp: .external(link: link, true))
            case let .request(requestURL, peer, writeAllowed):
                
                var options: [ModalAlertData.Option] = []
                options.append(.init(string: strings().botInlineAuthOptionLogin(requestURL, context.myPeer?.displayTitle ?? ""), isSelected: true, mandatory: false, uncheckEverything: true))
                if writeAllowed {
                    options.append(.init(string: strings().botInlineAuthOptionAllowSendMessages(peer.displayTitle), isSelected: true, mandatory: false))
                }
                
                let data = ModalAlertData(title: strings().botInlineAuthHeader, info: strings().botInlineAuthTitle(requestURL), ok: strings().botInlineAuthOpen, options: options)
                                
                showModalAlert(for: getWindow(context), data: data, completion: { result in
                    if result.selected.isEmpty {
                        execute(inapp: .external(link: link, false))
                    } else {
                        let allowWriteAccess = result.selected[1] == true
                        
                        _ = showModalProgress(signal: context.engine.messages.acceptMessageActionUrlAuth(subject: .url(link), allowWriteAccess: allowWriteAccess), for: getWindow(context)).start(next: { result in
                            switch result {
                            case .default:
                                execute(inapp: .external(link: link, true))
                            case let .accepted(url):
                                execute(inapp: .external(link: url, false))
                            default:
                                break
                            }
                        })
                    }
                })
            }
        })
        
        afterComplete(true)
    case let .folder(_, slug, context):
        loadAndShowSharedFolder(context: context, slug: slug)
        afterComplete(true)
    case let .loginCode(_, code):
        appDelegate?.applyExternalLoginCode(code)
        afterComplete(true)
    case let .boost(_, username, context):
        let signal: Signal<(Peer, ChannelBoostStatus?, MyBoostStatus?)?, NoError> = resolveUsername(username: username, context: context) |> mapToSignal { value in
            if let value = value {
                return combineLatest(context.engine.peers.getChannelBoostStatus(peerId: value.id), context.engine.peers.getMyBoostStatus()) |> map {
                    (value, $0, $1)
                }
            } else {
                return .single(nil)
            }
        }
        _ = showModalProgress(signal: signal, for: getWindow(context)).start(next: { value in
            if let value = value, let boosts = value.1 {
                showModal(with: BoostChannelModalController(context: context, peer: value.0, boosts: boosts, myStatus: value.2 ), for: getWindow(context))
            } else {
                if value == nil {
                    if username.contains(_private_) {
                        alert(for: getWindow(context), info: strings().channelBoostPrivateError)
                    } else {
                        alert(for: getWindow(context), info: strings().alertUserDoesntExists)
                    }
                } else {
                    alert(for: getWindow(context), info: strings().unknownError)
                }
                
            }
        })
        afterComplete(true)
    case let .gift(_, slug, context):
        _ = showModalProgress(signal: context.engine.payments.checkPremiumGiftCode(slug: slug), for: getWindow(context)).start(next: { info in
            if let info = info {
                showModal(with: GiftLinkModalController(context: context, info: info), for: getWindow(context))
            } else {
                alert(for: getWindow(context), info: strings().unknownError)
            }
        })
        afterComplete(true)
    case let .multigift(_, context):
        let behaviour = SelectContactsBehavior.init(settings: [.contacts, .remote, .excludeBots], excludePeerIds: [], limit: 10)
        
        _ = selectModalPeers(window: getWindow(context), context: context, title: strings().premiumGiftTitle, behavior: behaviour).start(next: { peerIds in
            
            showModal(with: PremiumGiftingController(context: context, peerIds: peerIds), for: getWindow(context))
        })
        afterComplete(true)
    case .businessLink(link: let link, slug: let slug, context: let context):
        _ = showModalProgress(signal: context.engine.peers.resolveMessageLink(slug: slug), for: getWindow(context)).startStandalone(next: { link in
            if let link {
                let navigation = context.bindings.rootNavigation()
                let current = navigation.controller as? ChatController
                let textState = ChatTextInputState(inputText: link.message, selectionRange: link.message.length ..< link.message.length, attributes: chatTextAttributes(from: TextEntitiesMessageAttribute(entities: link.entities), associatedMedia: [:]))
                if let current {
                    if current.chatLocation.peerId == link.peer.id {
                        current.chatInteraction.invokeInitialAction(action: .inputText(text: textState, behavior: .automatic))
                    } else {
                        current.chatInteraction.openInfo(link.peer.id, true, nil, .inputText(text: textState, behavior: .automatic))
                    }
                } else {
                    navigation.push(ChatAdditionController(context: context, chatLocation: .peer(link.peer.id), initialAction: .inputText(text: textState, behavior: .automatic)))
                }
            } else {
                showModalText(for: getWindow(context), text: strings().chatLinkUnavailable)
            }
        })
        afterComplete(true)
    case let .tonsite(link, context):
        BrowserStateContext.get(context).open(tab: .tonsite(url: link))
        afterComplete(true)
    case let .starsTopup(_, amount, purpose, context):
        let balance = context.starsContext.state |> map { $0?.balance } |> take(1) |> deliverOnMainQueue
        _ = balance.startStandalone(next: { balance in
            if let balance = balance {
                if balance.value > amount {
                    showModalText(for: getWindow(context), text: strings().starsYouHaveEnough, callback: { value in
                        showModal(with: Star_ListScreen(context: context, source: .buy(suffix: purpose, amount: nil)), for: getWindow(context))
                    })
                } else {
                    showModal(with: Star_ListScreen(context: context, source: .buy(suffix: purpose, amount: amount)), for: getWindow(context))
                }
            }
        })
        afterComplete(true)
    case let .nft(_, slug, context):
        _ = showModalProgress(signal: context.engine.payments.getUniqueStarGift(slug: slug), for: getWindow(context)).start(next: { gift in
            if let gift {
                showModal(with: StarGift_Nft_Controller(context: context, gift: .unique(gift), source: .quickLook(nil, gift), transaction: nil), for: getWindow(context))
            } else {
                showModalText(for: getWindow(context), text: strings().unknownError)
            }
        })
        afterComplete(true)
    case let .joinCall(_, slug, context):
                
        _ = showModalProgress(signal: context.engine.calls.getCurrentGroupCall(reference: .link(slug: slug)), for: getWindow(context)).start(next: { summary in
            if let summary {
                showModal(with: JoinGroupCallController(context: context, summary: summary, reference: .link(slug: slug)), for: getWindow(context))
            }
        }, error: { error in
            switch error {
            case .generic:
                showModalText(for: getWindow(context), text: strings().groupCallInviteLinkExpired)
            }
        })
        afterComplete(true)
    case let .starsInfo(_, context):
        showModal(with: Star_ListScreen(context: context, source: .account), for: getWindow(context))
        afterComplete(true)
    }
    
}

private func updateAppAsYouWish(text: String, updateApp: Bool) {
    //
    if updateApp {
        verifyAlert_button(for: mainWindow, header: appName, information: text, ok: strings().alertButtonOKUpdateApp, cancel: strings().modalCancel, option: nil, successHandler: { _ in
            if updateApp {
                #if APP_STORE
                execute(inapp: inAppLink.external(link: itunesAppLink, false))
                #else
                (NSApp.delegate as? AppDelegate)?.checkForUpdates(updateApp)
                #endif
            }
        })
    } else {
        alert(for: mainWindow, info: text, ok: strings().modalOK)
    }
    
}

func escape(with link:String, addPercent: Bool = true) -> String {
    var escaped = addPercent ? link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? link : link
    
    escaped = escaped.removingPercentEncoding ?? escaped
//    
//    escaped = escaped.replacingOccurrences(of: "%21", with: "!")
//    escaped = escaped.replacingOccurrences(of: "%24", with: "$")
//    escaped = escaped.replacingOccurrences(of: "%26", with: "&")
//    escaped = escaped.replacingOccurrences(of: "%2B", with: "+")
//    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
//    escaped = escaped.replacingOccurrences(of: "%2F", with: "/")
//    escaped = escaped.replacingOccurrences(of: "%3A", with: ":")
//    escaped = escaped.replacingOccurrences(of: "%3B", with: ";")
//    escaped = escaped.replacingOccurrences(of: "%3D", with: "=")
//    escaped = escaped.replacingOccurrences(of: "%3F", with: "?")
//    escaped = escaped.replacingOccurrences(of: "%40", with: "@")
//    escaped = escaped.replacingOccurrences(of: "%20", with: " ")
//    escaped = escaped.replacingOccurrences(of: "%09", with: "\t")
//    escaped = escaped.replacingOccurrences(of: "%23", with: "#")
//    escaped = escaped.replacingOccurrences(of: "%3C", with: "<")
//    escaped = escaped.replacingOccurrences(of: "%3E", with: ">")
//    escaped = escaped.replacingOccurrences(of: "%22", with: "\"")
//    escaped = escaped.replacingOccurrences(of: "%0A", with: "\n")
//    escaped = escaped.replacingOccurrences(of: "%25", with: "%")
//    escaped = escaped.replacingOccurrences(of: "%2E", with: ".")
//    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
//    escaped = escaped.replacingOccurrences(of: "%7D", with: "}")
//    escaped = escaped.replacingOccurrences(of: "%7B", with: "{")
//    escaped = escaped.replacingOccurrences(of: "%5B", with: "[")
//    escaped = escaped.replacingOccurrences(of: "%5D", with: "]")
    return escaped
}


func urlVars(with url: String) -> ([String: String], Set<String>) {
    var vars: [String: String] = [:]
    let range = url.nsstring.range(of: "?")
    let ns: NSString = range.location != NSNotFound ? url.nsstring.substring(from: range.location + 1).nsstring : url.nsstring

    let hashes = ns.components(separatedBy: "&")
    var emptyVars: Set<String> = Set()
    for hash in hashes {
        let param = hash.components(separatedBy: "=")
        if param.count > 1 {
            let key = param[0].lowercased()
            // Reconstruct the value by joining the remaining parts
            let value = param[1...].joined(separator: "=")
            vars[key] = value
        } else if param.count == 1 {
            emptyVars.insert(param[0])
        }
    }
    return (vars, emptyVars)
}



enum SecureIdPermission : String {
    case identity = "identity"
    case address = "address"
    case email = "email"
    case phone = "phone"
}

struct inAppSecureIdRequest {
    let peerId: PeerId
    let scope: String
    let callback: String?
    let publicKey: String
    let nonce: Data
    let isModern: Bool
}



enum WallpaperPreview {
    case color(NSColor)
    case slug(String, WallpaperSettings)
    case gradient(Int64?, [NSColor], WallpaperSettings)
}

enum inAppLink {
    
    
    case external(link:String, Bool) // link, confirm
    case tonsite(link: String, context: AccountContext)
    case peerInfo(link: String, peerId:PeerId, action:ChatInitialAction?, openChat:Bool, postId:Int32?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case followResolvedName(link: String, username:String, postId:Int32?, forceProfile: Bool, context: AccountContext, action:ChatInitialAction?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case comments(link: String, username:String, context: AccountContext, threadId: Int32, commentId: Int32?)
    case topic(link: String, username:String, context: AccountContext, threadId: Int32, commentId: Int32?)
    case inviteBotToGroup(link: String, username:String, context: AccountContext, action:ChatInitialAction?, rights: String?, isChannel: Bool, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case botCommand(String, (String)->Void)
    case callback(String, (String)->Void)
    case code(String, (String)->Void)
    case hashtag(String, (String)->Void)
    case shareUrl(link: String, AccountContext, String, String?)
    case joinchat(link: String, String, context: AccountContext, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case logout(()->Void)
    case stickerPack(link: String, StickerPackPreviewSource, context: AccountContext, peerId:PeerId?)
    case confirmPhone(link: String, context: AccountContext, phone: String, hash: String)
    case nothing
    case socks(link: String, ProxyServerSettings, applyProxy:(ProxyServerSettings)->Void)
    case requestSecureId(link: String, context: AccountContext, value: inAppSecureIdRequest)
    case unsupportedScheme(link: String, context: AccountContext, path: String)
    case applyLocalization(link: String, context: AccountContext, value: String)
    case wallpaper(link: String, context: AccountContext, preview: WallpaperPreview)
    case theme(link: String, context: AccountContext, name: String)
    case tonTransfer(link: String, context: AccountContext, data: ParsedWalletUrl)
    case instantView(link: String, webpage: TelegramMediaWebpage, anchor: String?)
    case settings(link: String, context: AccountContext, section: InAppSettingsSection)
    case joinGroupCall(link: String, context: AccountContext, peerId: PeerId, call: CachedChannelData.ActiveCall)
    case invoice(link: String, context: AccountContext, slug: String)
    case premiumOffer(link: String, ref: String?, context: AccountContext)
    case restorePurchase(link: String, context: AccountContext)
    case urlAuth(link: String, context: AccountContext)
    case loginCode(link: String, code: String)
    case folder(link: String, slug: String, context: AccountContext)
    case story(link: String, username: String, storyId: Int32, messageId: MessageId?, context: AccountContext)
    case boost(link: String, username: String, context: AccountContext)
    case gift(link: String, slug: String, context: AccountContext)
    case businessLink(link: String, slug: String, context: AccountContext)
    case starsTopup(link: String, amount: Int64, purpose: String, context: AccountContext)
    case multigift(link: String, context: AccountContext)
    case nft(link: String, slug: String, context: AccountContext)
    case joinCall(link: String, slug: String, context: AccountContext)
    case starsInfo(link: String, context: AccountContext)
    var link: String {
        switch self {
        case let .external(link,_):
            if link.hasPrefix("mailto:") {
                return link.replacingOccurrences(of: "mailto:", with: "")
            }
            return link
        case let .peerInfo(link, _, _, _, _, _):
            return link
        case let .comments(link, _, _, _, _):
            return link
        case let .topic(link, _, _, _, _):
            return link
        case let .followResolvedName(link, _, _, _, _, _, _):
            return link
        case let .inviteBotToGroup(link, _, _, _, _, _, _):
            return link
        case let .botCommand(link, _), let .callback(link, _), let .code(link, _), let .hashtag(link, _):
            return link
        case let .shareUrl(link, _, _, _):
            return link
        case let .joinchat(link, _, _, _):
            return link
        case let .stickerPack(link, _, _, _):
            return link
        case let .confirmPhone(link, _, _, _):
            return link
        case let .socks(link, _, _):
            return link
        case let .requestSecureId(link, _, _):
            return link
        case let .unsupportedScheme(link, _, _):
            return link
        case let .applyLocalization(link, _, _):
            return link
        case let .wallpaper(link, _, _):
            return link
        case let .theme(link, _, _):
            return link
        case let .tonTransfer(link, _, _):
            return link
        case let .instantView(link, _, _):
            return link
        case let .settings(link, _, _):
            return link
        case let .joinGroupCall(link, _, _, _):
            return link
        case let .invoice(link, _, _):
            return link
        case let .premiumOffer(link, _, _):
            return link
        case let .restorePurchase(link, _):
            return link
        case let .urlAuth(link, _):
            return link
        case let .folder(link, _, _):
            return link
        case let .loginCode(link, _):
            return link
        case let .story(link, _, _, _, _):
            return link
        case let .boost(link, _, _):
            return link
        case let .gift(link, _, _):
            return link
        case let .multigift(link, _):
            return link
        case let .businessLink(link, _, _):
            return link
        case let .tonsite(link, _):
            return link
        case let .starsTopup(link, _, _, _):
            return link
        case let .nft(link, _, _):
            return link
        case let .joinCall(link, _, _):
            return link
        case let .starsInfo(link, _):
            return link
        case .nothing:
            return ""
        case .logout:
            return ""
        }
    }
}

let telegram_me:[String] = ["telegram.me/","telegram.dog/","t.me/"]
let actions_me:[String] = ["joinchat/","addstickers/","addemoji/","confirmphone","socks", "proxy", "setlanguage/", "bg/", "addtheme/","invoice/", "addlist/", "boost", "giftcode/", "m/", "nft/", "call/"]

let telegram_scheme:String = "tg://"
let known_scheme:[String] = ["resolve","msg_url","join","addstickers", "addemoji","confirmphone", "socks", "proxy", "passport", "setlanguage", "bg", "privatepost", "addtheme", "settings", "invoice", "premium_offer", "restore_purchases", "login", "addlist", "boost", "giftcode", "premium_multigift", "stars_topup", "message", "nft", "call", "stars"]


let ton_scheme:String = "ton://"

private let keyURLUsername = "domain";
private let keyURLPhone = "phone";
private let keyURLPostId = "post";
private let keyURLCommentId = "comment";
private let keyURLAdmin = "admin";
private let keyURLThreadId = "thread";
private let keyURLTopicId = "topic";
private let keyURLStoryId = "story";
private let keyURLInvite = "invite";
private let keyURLUrl = "url";
private let keyURLSet = "set";
private let keyURLText = "text";
private let keyURLStart = "start";
private let keyURLVoiceChat = "voicechat";
private let keyURLStartattach = "startattach";
private let keyURLAttach = "attach";
private let keyURLStartGroup = "startgroup";
private let keyURLStartChannel = "startchannel";
private let keyURLStartAdmin = "admin";
private let keyURLSecret = "secret";
private let keyURLproxy = "proxy";
private let keyURLLivestream = "livestream";
private let keyURLRef = "ref";
private let keyURLSlug = "slug";
private let keyURLChoose = "choose";
private let keyURLLang = "lang";
private let keyURLRotation = "rotation";
private let keyURLTimecode = "t";
private let keyURLBgColor = "bg_color";
private let keyURLHash = "hash";
private let keyURLCode = "code";
private let keyURLAmount = "amount"
private let keyURLBalance = "balance"
private let keyURLPurpose = "purpose"

private let keyURLChannel = "channel";


private let keyURLAppname = "appname";
private let keyURLStartapp = "startapp";



private let keyURLHost = "server";
private let keyURLPort = "port";
private let keyURLUser = "user";
private let keyURLPass = "pass";

private let _private_ = "_private_"

let legacyPassportUsername = "telegrampassport"

func inApp(for url:NSString, context: AccountContext? = nil, peerId:PeerId? = nil, messageId: MessageId? = nil, openInfo:((PeerId, Bool, MessageId?, ChatInitialAction?)->Void)? = nil, hashtag:((String)->Void)? = nil, command:((String)->Void)? = nil, applyProxy:((ProxyServerSettings) -> Void)? = nil, confirm: Bool = false) -> inAppLink {
    
    var value = url
    let subdomainRange = url.range(of: ".t.me")
    if subdomainRange.location != NSNotFound, let subdomain = URL(string: url as String) {
        var subdomain = subdomain
        if subdomain.scheme == nil, let domain = URL(string: "https://" + subdomain.path) {
            subdomain = domain
        }
        if let host = subdomain.host {
            var components:[String] = []
            components = host.components(separatedBy: ".")
            var newValue: String = ""
            if components.count == 3, components[1] == "t", components[2] == "me" {
                newValue = "https://" + components[1] + "." + components[2] + "/" + components[0]
                let queryRange = url.range(of: host + "/?")
                if queryRange.location != NSNotFound {
                    let query = url.substring(with: NSMakeRange(queryRange.max, url.length - queryRange.max))
                    newValue += "?" + query
                } else {
                    let queryRange = url.range(of: host + "/")
                    if queryRange.location != NSNotFound {
                        let query = url.substring(with: NSMakeRange(queryRange.max, url.length - queryRange.max))
                        newValue += "/" + query
                    }
                }
            }
            if !newValue.isEmpty {
                value = newValue.nsstring
            }
        }
    }
    
    let external = value
    let urlString = external as String
    let url = value
    
    
    if let url = URL(string: url as String), url.scheme == "file" {
        return .nothing
    }
    
    if var url = URL(string: url as String) {
        let eligible = url.scheme == "tonsite"
        if let context {
            if eligible {
                return .tonsite(link: urlString, context: context)
            } else {
                if url.scheme == nil, let domain = URL(string: "https://" + url.absoluteString) {
                    url = domain
                }
                let host = urlWithoutScheme(from: url)?.host
                if let host, host.components(separatedBy: ".").last == "ton" {
                    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                    components?.scheme = "tonsite"
                    var urlString: String? = nil
                    if let url = components?.url?.absoluteString {
                        urlString = url
                    }
                    if let urlString {
                        return .tonsite(link: urlString, context: context)
                    }
                }
            }
        }
    }
    
    
    
    if let urlValue = URL(string: url as String), let host = urlValue.host?.lowercased(), let context = context {
        let urlHandlingConfiguration: UrlHandlingConfiguration = .with(appConfiguration: context.appConfiguration)
        
        if urlHandlingConfiguration.urlAuthDomains.contains(host) {
            return .urlAuth(link: url as String, context: context)
        }
    }

    
    for domain in telegram_me {
        let range = url.range(of: domain)
        if range.location != NSNotFound && (range.location == 0 || (range.location <= 8 && url.substring(from: range.location - 1).hasPrefix("/"))) {
            let string = external.substring(from: range.location + range.length)
            for action in actions_me {
                if string.hasPrefix(action) {
                    let value = String(string[string.index(string.startIndex, offsetBy: action.length) ..< string.endIndex])
                    switch action {
                    case actions_me[0]:
                        if let openInfo = openInfo, let context = context {
                            return .joinchat(link: urlString, value, context: context, callback: openInfo)
                        }
                    case actions_me[1]:
                        if let context = context {
                            return .stickerPack(link: urlString, .stickers(.name(value)), context: context, peerId: peerId)
                        }
                    case actions_me[2]:
                        if let context = context {
                            return .stickerPack(link: urlString, .emoji(.name(value)), context: context, peerId: peerId)
                        }
                    case actions_me[3]:
                        let (vars, _) = urlVars(with: string)
                        if let context = context, let phone = vars[keyURLPhone], let hash = vars[keyURLHash] {
                            return .confirmPhone(link: urlString, context: context, phone: phone, hash: hash)
                        }
                    case actions_me[4]:
                        let (vars, _) = urlVars(with: string)
                        if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                            let server = escape(with: server)
                            let username = vars[keyURLUser] != nil ? escape(with: vars[keyURLUser]!) : nil
                            let pass = vars[keyURLPass] != nil ? escape(with: vars[keyURLPass]!) : nil
                            return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .socks5(username: username, password: pass)), applyProxy: applyProxy)
                        }
                    case actions_me[5]:
                        let (vars, _) = urlVars(with: string)
                        if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret]  {
                            let server = escape(with: server)
                            if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                                return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), applyProxy: applyProxy)
                            }
                        }
                    case actions_me[6]:
                        if let context = context, !value.isEmpty {
                            return .applyLocalization(link: urlString, context: context, value: value)
                        } else {
                            
                        }
                    case actions_me[7]:
                        if !value.isEmpty {
                            var component = value
                            component = component.components(separatedBy: "?")[0]
                            
                            if let context = context {
                                let (vars, emptyVars) = urlVars(with: value)
                                var rotation:Int32? = vars[keyURLRotation] != nil ? Int32(vars[keyURLRotation]!) : nil
                                
                                if let r = rotation {
                                    let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                                    if !available.contains(r) {
                                        rotation = nil
                                    }
                                }
                                
                                
                                var blur: Bool = false
                                var intensity: Int32? = 80
                                var colors: [UInt32] = []
                                
                                if let bgcolor = vars[keyURLBgColor], !bgcolor.isEmpty {
                                    var components = bgcolor.components(separatedBy: "~")
                                    if components.count == 1 {
                                        components = bgcolor.components(separatedBy: "-")
                                        if components.count > 2 {
                                            components = []
                                        }
                                    }
                                    colors = components.compactMap {
                                        return NSColor(hexString: "#\($0)")?.argb
                                    }
                                } else {
                                    var components = component.components(separatedBy: "~")
                                    if components.count == 1 {
                                        components = component.components(separatedBy: "-")
                                        if components.count > 2 {
                                            components = []
                                        }
                                    }
                                    colors = components.compactMap {
                                        return NSColor(hexString: "#\($0)")?.argb
                                    }
                                }
                                if let intensityString = vars["intensity"] {
                                    intensity = Int32(intensityString)
                                }
                                if let mode = vars["mode"] {
                                    blur = mode.contains("blur")
                                }
                                
                                let settings: WallpaperSettings = WallpaperSettings(blur: blur, motion: false, colors: colors, intensity: intensity, rotation: rotation)
                                
                                
                                var slug = component
                                if let index = component.range(of: "?") {
                                    slug = String(component[component.startIndex ..< index.lowerBound])
                                }
                                if (slug.contains("~") || slug.length < 27) {
                                    slug = ""
                                }
                                
                                var preview: WallpaperPreview = .slug(slug, settings)
                                if !colors.isEmpty, slug == "" {
                                    preview = .gradient(nil, colors.map { NSColor(argb: $0) }, settings)
                                }

                                return .wallpaper(link: urlString, context: context, preview: preview)

                            }
                        }
                        return .external(link: urlString, false)
                    case actions_me[8]:
                        let data = string.components(separatedBy: "/")
                        if data.count == 2, let context = context {
                            return .theme(link: urlString, context: context, name: data[1])
                        }
                        return .external(link: urlString, false)
                    case actions_me[9]:
                        let data = string.components(separatedBy: "/")
                        if data.count == 2, let context = context {
                            return .invoice(link: urlString, context: context, slug: value)
                        }
                        return .external(link: urlString, false)
                    case actions_me[10]:
                        let data = string.components(separatedBy: "/")
                        if data.count == 2, let context = context {
                            return .folder(link: urlString, slug: value, context: context)
                        }
                        return .external(link: urlString, false)
                    case actions_me[11]:
                        let data = string.components(separatedBy: "/")
                        if let context = context {
                            if data.count == 2 {
                                return .boost(link: urlString, username: data[1], context: context)
                            } else {
                                let (vars, _) = urlVars(with: string)
                                if let priv = vars["c"] {
                                    return .boost(link: urlString, username: "\(_private_)\(priv)", context: context)
                                }
                            }
                        }
                    case actions_me[12]:
                        let data = string.components(separatedBy: "/")
                        if let context = context, data.count == 2 {
                            return .gift(link: urlString, slug: data[1], context: context)
                        }
                    case actions_me[13]:
                        let data = string.components(separatedBy: "/")
                        if let context = context, data.count == 2 {
                            return .businessLink(link: urlString, slug: data[1], context: context)
                        }
                    case actions_me[14]:
                        let data = string.components(separatedBy: "/")
                        if let context = context, data.count == 2 {
                            return .nft(link: urlString, slug: data[1], context: context)
                        }
                    case actions_me[15]:
                        let data = string.components(separatedBy: "/")
                        if let context = context, data.count == 2 {
                            return .joinCall(link: urlString, slug: data[1], context: context)
                        }
                    default:
                        break
                    }
                }
            }
            
            let userAndVariables = string.components(separatedBy: "?")
            let username:String = userAndVariables[0]
            if username == keyURLproxy {
                 if userAndVariables.count == 2 {
                    let (vars, _) = urlVars(with: userAndVariables[1])
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                        let server = escape(with: server)
                        return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .socks5(username: vars[keyURLUser], password: vars[keyURLPass])), applyProxy: applyProxy)
                    } else if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret] {
                        let server = escape(with: server)
                        if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                            return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), applyProxy: applyProxy)
                        }
                    }
                }
            }
            
            
             if string.range(of: "/") == nil || string.range(of: "/?") != nil {
                let userAndVariables: [String]
                 if string.range(of: "/?") != nil {
                     userAndVariables = string.components(separatedBy: "/?")
                 } else {
                     userAndVariables = string.components(separatedBy: "?")
                 }
                let username:String = userAndVariables[0]
                var action:ChatInitialAction? = nil
                if userAndVariables.count == 2 {
                    let (vars, emptyValue) = urlVars(with: userAndVariables[1])
                    
                    
                    if emptyValue.contains(keyURLStartChannel) || emptyValue.contains(keyURLStartGroup) {
                        if let openInfo = openInfo, let context = context {
                            let rights = vars[keyURLAdmin]
                            return .inviteBotToGroup(link: urlString, username: username, context: context, action: nil, rights: rights, isChannel: emptyValue.contains(keyURLStartChannel), callback: openInfo)
                        }
                    }
                    
                    loop: for (key,value) in vars {
                        switch key {
                        case keyURLStart:
                            action = .start(parameter: escape(with: value, addPercent: false), behavior: .none)
                            break loop;
                        case keyURLStartGroup, keyURLStartChannel:
                            if let openInfo = openInfo, let context = context {
                                let rights = vars[keyURLAdmin]
                                return .inviteBotToGroup(link: urlString, username: username, context: context, action: .start(parameter: value, behavior: .automatic), rights: rights, isChannel: key == keyURLStartChannel, callback: openInfo)
                            }
                            break loop;
                        case keyURLVoiceChat:
                            action = .joinVoiceChat(value)
                            break loop;
                        case keyURLAttach:
                            let choose = vars[keyURLChoose]?.split(separator: "+").compactMap { String($0) }
                            let attach = vars[keyURLAttach]?.split(separator: "+").compactMap { String($0) }
                            action = .attachBot(value, nil, attach ?? choose)
                            break loop
                        case keyURLText:
                            if let text = vars[keyURLText], !text.isEmpty {
                                action = .inputText(text: .init(inputText: escape(with: text, addPercent: false)), behavior: .automatic)
                            }
                        default:
                            break
                        }
                    }
                    if vars.isEmpty && userAndVariables[1] == keyURLVoiceChat {
                        action = .joinVoiceChat(nil)
                    }
                }
                
                 if userAndVariables.count == 2, userAndVariables[1] == keyURLStartapp {
                     action = .makeWebview(appname: "", command: nil)
                 }
            
                 
                if action == nil, let messageId = messageId {
                    action = .source(messageId, nil)
                }
                 
                 
                if let openInfo = openInfo {
                    if username == "iv" || username.isEmpty {
                        return .external(link: urlString, username.isEmpty)
                    } else if let context = context {

                        if username.hasPrefix("$") {
                            return .invoice(link: urlString, context: context, slug: String(username.suffix(username.length - 1)))
                        }
                        
                        let components = string.components(separatedBy: "?")
                        let (vars, empty) = urlVars(with: string)
                        
                        let joinKeys:[String] = ["+", "%20"]
                        let phone = username.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        if "+\(phone)" == username {
                            let forceProfile = empty.contains("profile")
                            return .followResolvedName(link: urlString, username: phone, postId: nil, forceProfile: forceProfile, context: context, action: action, callback: openInfo)
                        } else {
                            for joinKey in joinKeys {
                                if username.hasPrefix(joinKey), username.length > joinKey.length {
                                    return .joinchat(link: urlString, username.nsstring.substring(from: joinKey.length), context: context, callback: openInfo)
                                }
                            }
                        }
                       
                        if let startapp = vars[keyURLStartapp] {
                            action = .makeWebview(appname: "", command: startapp)
                        } else if vars[keyURLStartattach] != nil || empty.contains(keyURLStartattach) {
                            let choose = vars[keyURLChoose]?.split(separator: "+").compactMap { String($0) }
                            let attach = vars[keyURLAttach]?.split(separator: "+").compactMap { String($0) }
                            //?? vars[keyURLAttach].map(Array.init(_:))
                            action = .attachBot(username, vars[keyURLStartattach], choose ?? attach)
                        } else if components.contains(keyURLLivestream) {
                            action = .joinVoiceChat(nil)
                        }
                        if username.hasPrefix("$") {
                            return .invoice(link: urlString, context: context, slug: String(username.suffix(username.length - 1)))
                        }
                        
                        let forceProfile = components.contains("profile")
                        
                      
                        if components.count == 2, components[1] == "boost" {
                            return .boost(link: urlString, username: username, context: context)
                        } else if let storyId = vars[keyURLStoryId]?.nsstring.intValue {
                            return .story(link: urlString, username: username, storyId: storyId, messageId: messageId, context: context)
                        } else if let topicId = vars[keyURLTopicId]?.nsstring.intValue {
                            return .topic(link: urlString, username: username, context: context, threadId: topicId, commentId: nil)
                        } else {
                            return .followResolvedName(link: urlString, username: username, postId: nil, forceProfile: forceProfile, context: context, action: action, callback: openInfo)
                        }
                    }
                }
            } else if let openInfo = openInfo {
                let userAndPost = string.components(separatedBy: "/")
                if userAndPost.count >= 2 {
                    let name = userAndPost[0]
                    let forceProfile = false
                    if name == "c" {
                        
                        if let context = context {
                            let postIndex = userAndPost.count - 1
                            var post = userAndPost[postIndex].isEmpty ? nil : Int32(userAndPost[postIndex])
                            var username = userAndPost[1]
                            if postIndex == 1 {
                                post = nil
                            }
                            if let range = userAndPost[postIndex].range(of: "?") {
                                if postIndex == 1 {
                                    username = String(userAndPost[1][..<range.lowerBound])
                                } else {
                                    post = Int32(userAndPost[postIndex][..<range.lowerBound])
                                }
                            }
                            let (params, action) = urlVars(with: url as String)
                            if let thread = params[keyURLThreadId]?.nsstring.intValue, let post = post {
                                return .comments(link: urlString, username: "\(_private_)\(username)", context: context, threadId: thread, commentId: post)
                            } else if let topic = params[keyURLTopicId]?.nsstring.intValue {
                                return .topic(link: urlString, username: "\(_private_)\(username)", context: context, threadId: topic, commentId: post)
                            } else if userAndPost.count == 4, let threadId = Int32(userAndPost[2]) {
                                return .topic(link: urlString, username: "\(_private_)\(username)", context: context, threadId: threadId, commentId: post)
                            } else {
                                if action.first == "boost" {
                                    return .boost(link: urlString, username: "\(_private_)\(username)", context: context)
                                } else {
                                    let forceProfile = false
                                    
                                    var action: ChatInitialAction? = nil
                                    if let t = params[keyURLTimecode] {
                                        let timemark = hTmeParseDuration(t)
                                        if Int(timemark) < Int32.max {
                                            action = .openMedia(Int32(timemark))
                                        }
                                    }
                                    return .followResolvedName(link: urlString, username: "\(_private_)\(username)", postId: post, forceProfile: forceProfile, context: context, action: action, callback: openInfo)
                                }
                            }
                        }
                    } else if name == "s" {
                        return .external(link: urlString, false)
                    } else if name == "addtheme" {
                        if let context = context {
                            return .theme(link: urlString, context: context, name: userAndPost[1])
                        }
                    } else {
                        let postIndex: Int = userAndPost.count - 1
                        let postText = userAndPost[postIndex]
                        var post = postText.isEmpty ? nil : Int32(postText)
                        var storyId: Int32? = nil
                        if let range = postText.range(of: "?") {
                            post = Int32(postText[..<range.lowerBound])
                        }
                        if name.hasPrefix("iv?") {
                            return .external(link: urlString, false)
                        } else if name.hasPrefix("share?") || name == "share" {
                            let (params, _) = urlVars(with: url as String)
                            if let url = params[keyURLUrl], let context = context {
                                let url = url.nsstring.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                                let text = params[keyURLText]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                                if let url = url {
                                    return .shareUrl(link: urlString, context, url, text)
                                    
                                }
                            }
                            return .external(link: urlString, false)
                        } else if let context = context {
                            let (params, _) = urlVars(with: url as String)
                            
                            var action: ChatInitialAction? = nil
                            
                            if let t = params[keyURLTimecode] {
                                let timemark = Double(hTmeParseDuration(t))
                                if Int(timemark) < Int32.max {
                                    action = .openMedia(Int32(timemark))
                                }
                            } else if (userAndPost.count == 2 && post == nil) || (userAndPost.count == 3 && params[keyURLStartapp] != nil) {
                                var appname = userAndPost[1]
                                if let range = userAndPost[1].range(of: "?") {
                                    appname = String(userAndPost[1][..<range.lowerBound])
                                }
                                if !appname.isEmpty {
                                    action = .makeWebview(appname: appname, command: params[keyURLStartapp])
                                }
                            }
                           
                            if let t = params[keyURLTimecode], action == nil {
                                let timemark = hTmeParseDuration(t)
                                if Int(timemark) < Int32.max {
                                    action = .openMedia(Int32(timemark))
                                }
                            }
                            
                            if action == nil, let messageId = messageId {
                                action = .source(messageId, nil)
                            }
                        
                            
                            if userAndPost.count == 3, let storyId = post, userAndPost[1] == "s" {
                                return .story(link: urlString, username: name, storyId: storyId, messageId: messageId, context: context)
                            } else if let comment = params[keyURLCommentId]?.nsstring.intValue, let post = post {
                                return .comments(link: urlString, username: name, context: context, threadId: post, commentId: comment)
                            } else if let thread = params[keyURLThreadId]?.nsstring.intValue, let comment = post {
                                 return .comments(link: urlString, username: name, context: context, threadId: thread, commentId: comment)
                            } else if let topic = params[keyURLTopicId]?.nsstring.intValue {
                                return .topic(link: urlString, username: name, context: context, threadId: topic, commentId: post)
                            } else if userAndPost.count == 3, let threadId = Int32(userAndPost[1]) {
                                return .topic(link: urlString, username: name, context: context, threadId: threadId, commentId: post)
                            } else if let storyId = storyId {
                                return .story(link: urlString, username: name, storyId: storyId, messageId: messageId, context: context)
                            } else {
                                let forceProfile = userAndPost.contains("profile")
                                
                                return .followResolvedName(link: urlString, username: name, postId: post, forceProfile: forceProfile, context: context, action: action, callback: openInfo)
                            }
                        }
                    }
                }
            }
        }
    }
    
    if url.hasPrefix("@"), let openInfo = openInfo, let context = context {
        return .followResolvedName(link: urlString, username: url.substring(from: 1), postId: nil, forceProfile: false, context: context, action:nil, callback: openInfo)
    }
    
    if url.hasPrefix("/"), let command = command {
        return .botCommand(url as String, command)
    }
    if url.hasPrefix("#"), let hashtag = hashtag {
        return .hashtag(url as String, hashtag)
    }
    
    if url.hasPrefix(telegram_scheme) {
        let action = url.substring(from: telegram_scheme.length)
        
        let (vars, emptyVars) = urlVars(with: external as String)
        
        for i in 0 ..< known_scheme.count {
            let known = known_scheme[i]
            if action.hasPrefix(known) {
                
                switch known {
                case known_scheme[0]:
                    if let username = vars[keyURLUsername], let openInfo = openInfo {
                        let post = vars[keyURLPostId]?.nsstring.intValue
                        let comment = vars[keyURLCommentId]?.nsstring.intValue
                        let thread = vars[keyURLThreadId]?.nsstring.intValue
                        let topic = vars[keyURLTopicId]?.nsstring.intValue
                        let story = vars[keyURLStoryId]?.nsstring.intValue
                        var action:ChatInitialAction? = nil
                        loop: for (key,value) in vars {
                            switch key {
                            case keyURLStartapp:
                                action = .makeWebview(appname: "", command: value)
                            case keyURLStart:
                                action = .start(parameter: escape(with: value, addPercent: false), behavior: .none)
                                break loop;
                            case keyURLStartGroup, keyURLStartChannel:
                                if let context = context {
                                    let rights = vars[keyURLAdmin]
                                    return .inviteBotToGroup(link: urlString, username: username, context: context, action: .start(parameter: value, behavior: .none), rights: rights, isChannel: key == keyURLStartChannel, callback: openInfo)
                                }
                            case keyURLVoiceChat:
                                action = .joinVoiceChat(value)
                                break loop
                            case keyURLAttach:
                                let choose = vars[keyURLChoose]?.split(separator: "+").compactMap { String($0) }
                                let attach = vars[keyURLAttach]?.split(separator: "+").compactMap { String($0) }
                                action = .attachBot(value, vars[keyURLStartattach], attach ?? choose)
                                break loop
                            case keyURLAppname:
                                action = .makeWebview(appname: value, command: vars[keyURLStartapp])
                                break loop
                            case keyURLText:
                                if let text = vars[keyURLText], !text.isEmpty {
                                    action = .inputText(text: .init(inputText: escape(with: text, addPercent: false)), behavior: .automatic)
                                }
                                break loop
                            default:
                                break
                            }
                        }
                        if action == nil && emptyVars.contains(keyURLStartapp) {
                            action = .makeWebview(appname: "", command: nil)
                        } else if action == nil && emptyVars.contains(keyURLVoiceChat) {
                            action = .joinVoiceChat(nil)
                        } else if action == nil, vars[keyURLStartattach] != nil || vars[keyURLAttach] != nil {
                            let choose = vars[keyURLChoose]?.split(separator: "+").compactMap { String($0) }
                            let attach = vars[keyURLAttach]?.split(separator: "+").compactMap { String($0) }
                            action = .attachBot(username, vars[keyURLStartattach], attach ?? choose)
                        }
                        if username == legacyPassportUsername {
                            return inApp(for: external.replacingOccurrences(of: "tg://resolve", with: "tg://passport").nsstring, context: context, peerId: peerId, openInfo: openInfo, hashtag: hashtag, command: command, applyProxy: applyProxy, confirm: confirm)
                            //return inapp
                        } else if username == "addtheme", let context = context {
                            return .theme(link: urlString, context: context, name:"")
                        } else if let context = context {
                            if let comment = comment, let post = post {
                                return .comments(link: urlString, username: username, context: context, threadId: post, commentId: comment)
                            } else if let thread = thread, let comment = post {
                                return .comments(link: urlString, username: username, context: context, threadId: thread, commentId: comment)
                            } else if let topic = topic {
                                return .comments(link: urlString, username: username, context: context, threadId: topic, commentId: comment)
                            } else if let story = story {
                                return .story(link: urlString, username: username, storyId: story, messageId: messageId, context: context)
                            } else {
                                let forceProfile = emptyVars.contains("profile")
                                return .followResolvedName(link: urlString, username: username, postId: post, forceProfile: forceProfile, context: context, action: action, callback:openInfo)
                            }
                        }
                    } else if let phone = vars[keyURLPhone], let openInfo = openInfo, let context = context {
                        let forceProfile = emptyVars.contains("profile")
                        return .followResolvedName(link: urlString, username: phone, postId: nil, forceProfile: forceProfile, context: context, action: nil, callback: openInfo)
                    }
                case known_scheme[1]:
                    if let url = vars[keyURLUrl] {
                        let url = url.nsstring.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        let text = vars[keyURLText]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        if let url = url, let context = context {
                            var applied = url
                            return .shareUrl(link: urlString, context, applied, text)
                            
                        }
                    }
                case known_scheme[2]:
                    if let invite = vars[keyURLInvite], let openInfo = openInfo, let context = context {
                        return .joinchat(link: urlString, invite, context: context, callback: openInfo)
                    }
                case known_scheme[3]:
                    if let set = vars[keyURLSet], let context = context {
                        return .stickerPack(link: urlString, .stickers(.name(set)), context: context, peerId:nil)
                    }
                case known_scheme[4]:
                    if let set = vars[keyURLSet], let context = context {
                        return .stickerPack(link: urlString, .emoji(.name(set)), context: context, peerId:nil)
                    }
                case known_scheme[5]:
                    if let context = context, let phone = vars[keyURLPhone], let hash = vars[keyURLHash] {
                        return .confirmPhone(link: urlString, context: context, phone: phone, hash: hash)
                    }
                case known_scheme[6]:
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                        let server = escape(with: server)
                        return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .socks5(username: vars[keyURLUser], password: vars[keyURLPass])), applyProxy: applyProxy)
                    }
                case known_scheme[7]:
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret] {
                        let server = escape(with: server)
                        if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                            return .socks(link: urlString, ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), applyProxy: applyProxy)
                        }
                    }
                case known_scheme[8]:
                    if let scope = vars["scope"], let publicKey = vars["public_key"], let rawBotId = vars["bot_id"], let botId = Int64(rawBotId), let context = context {
                        
                        
                        let scope = escape(with: scope, addPercent: false)
                        

                        let isModern: Bool = scope.hasPrefix("{")
                        
                        let nonceString = (isModern ? vars["nonce"] : vars["payload"]) ?? ""

                        let nonce = escape(with: nonceString, addPercent: false).data(using: .utf8) ?? Data()
                        
                        let callbackUrl = vars["callback_url"] != nil ? escape(with: vars["callback_url"]!, addPercent: false) : nil
                        return .requestSecureId(link: urlString, context: context, value: inAppSecureIdRequest(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), scope: scope, callback: callbackUrl, publicKey: escape(with: publicKey, addPercent: false), nonce: nonce, isModern: isModern))
                    }
                case known_scheme[9]:
                    if let context = context, let value = vars["lang"] {
                        return .applyLocalization(link: urlString, context: context, value: value)
                    }
                case known_scheme[10]:
                    if let context = context, let value = vars[keyURLSlug] {
                        
                        var blur: Bool = false
                        var intensity: Int32? = 80
                        var colors: [UInt32] = []
                        
                        var rotation:Int32? = vars["rotation"] != nil ? Int32(vars["rotation"]!) : nil
                        
                        if let r = rotation {
                            let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                            if !available.contains(r) {
                                rotation = nil
                            }
                        }

                        
                        if let bgcolor = vars["bg_color"], !bgcolor.isEmpty {
                            var components = bgcolor.components(separatedBy: "~")
                            if components.count == 1 {
                                components = bgcolor.components(separatedBy: "-")
                                if components.count > 2 {
                                    components = []
                                }
                            }
                            colors = components.compactMap {
                                return NSColor(hexString: "#\($0)")?.argb
                            }
                        }
                        if let mode = vars["mode"] {
                            blur = mode.contains("blur")
                        }
                        if let intensityString = vars["intensity"] {
                            intensity = Int32(intensityString)
                        }
                        
                        let settings: WallpaperSettings = WallpaperSettings(blur: blur, motion: false, colors: colors, intensity: intensity, rotation: rotation)
                        
                        return .wallpaper(link: urlString, context: context, preview: .slug(value, settings))
                    }
                    if let context = context, let value = vars["color"] {
                        return .wallpaper(link: urlString, context: context, preview: .slug(value, WallpaperSettings()))
                    } else if let context = context {
                        
                        var rotation:Int32? = vars["rotation"] != nil ? Int32(vars["rotation"]!) : nil
                        
                        if let r = rotation {
                            let available:[Int32] = [0, 45, 90, 135, 180, 225, 270, 310]
                            if !available.contains(r) {
                                rotation = nil
                            }
                        }
                        
                        var components = vars["bg_color"]?.components(separatedBy: "~") ?? []
                        if components.count == 1 {
                            components = vars["bg_color"]?.components(separatedBy: "-") ?? []
                            if components.count > 2 {
                                components = []
                            }
                        }
                        let colors = components.compactMap {
                            return NSColor(hexString: "#\($0)")
                        }
                        if !colors.isEmpty  {
                            return .wallpaper(link: urlString, context: context, preview: .gradient(0, colors, WallpaperSettings(rotation: rotation)))
                        }
                    }
                case known_scheme[11]:
                    if let username = vars["channel"], let openInfo = openInfo {
                        let post = vars[keyURLPostId]?.nsstring.intValue
                        let threadId = vars[keyURLThreadId]?.nsstring.intValue
                        let topicId = vars[keyURLTopicId]?.nsstring.intValue
                        
                        if let threadId = threadId, let post = post, let context = context {
                            return .comments(link: urlString, username: "\(_private_)\(username)", context: context, threadId: threadId, commentId: post)
                        } else if let topicId = topicId, let context = context {
                            return .topic(link: urlString, username: "\(_private_)\(username)", context: context, threadId: topicId, commentId: post)
                        } else if let context = context {
                            let forceProfile = emptyVars.contains("profile")
                            return .followResolvedName(link: urlString, username: "\(_private_)\(username)", postId: post, forceProfile: forceProfile, context: context, action:nil, callback: openInfo)
                        }
                    }
                case known_scheme[12]:
                    if let context = context, let value = vars[keyURLSlug] {
                        return .theme(link: urlString, context: context, name: value)
                    }
                case known_scheme[13]:
                    if let context = context, let range = action.range(of: known_scheme[13] + "/") {
                        let section = String(action[range.upperBound...])
                        if let section = InAppSettingsSection(rawValue: section) {
                            return .settings(link: urlString, context: context, section: section)
                        }
                    }
                case known_scheme[14]:
                    if let context = context, let value = vars[keyURLSlug] {
                        return .invoice(link: urlString, context: context, slug: value)
                    }
                case known_scheme[15]:
                    if let context = context {
                        return .premiumOffer(link: urlString, ref: vars[keyURLRef], context: context)
                    }
                case known_scheme[16]:
                    if let context = context {
                        return .restorePurchase(link: urlString, context: context)
                    }
                case known_scheme[17]:
                    if let code = vars[keyURLCode] {
                        return .loginCode(link: urlString, code: code)
                    }
                case known_scheme[18]:
                    if let slug = vars[keyURLSlug], let context = context {
                        return .folder(link: urlString, slug: slug, context: context)
                    }
                case known_scheme[19]:
                    if let channelId = vars[keyURLChannel], let context = context {
                        return .boost(link: urlString, username: "\(_private_)\(channelId)", context: context)
                    } else if let username = vars[keyURLUsername], let context = context {
                        return .boost(link: urlString, username: username, context: context)
                    }
                case known_scheme[20]:
                    if let slug = vars[keyURLSlug], let context = context {
                        return .gift(link: urlString, slug: slug, context: context)
                    }
                case known_scheme[21]:
                    if let context = context {
                        return .multigift(link: urlString, context: context)
                    }
                case known_scheme[22]:
                    if let context = context, let amount = vars[keyURLBalance].flatMap ({ Int64($0) }), let purpose = vars[keyURLPurpose] {
                        return .starsTopup(link: urlString, amount: amount, purpose: purpose, context: context)
                    }
                case known_scheme[23]:
                    if let context = context, let slug = vars[keyURLSlug] {
                        return .businessLink(link: urlString, slug: slug, context: context)
                    }
                case known_scheme[24]:
                    if let context = context, let slug = vars[keyURLSlug] {
                        return .nft(link: urlString, slug: slug, context: context)
                    }
                case known_scheme[25]:
                    if let context = context, let slug = vars[keyURLSlug] {
                        return .joinCall(link: urlString, slug: slug, context: context)
                    }
                case known_scheme[26]:
                    if let context = context{
                        return .starsInfo(link: urlString, context: context)
                    }
                default:
                    break
                }
               
                return .nothing

            }
        }
        if let context = context {
            var path = url.substring(from: telegram_scheme.length)
            let qLocation = path.nsstring.range(of: "?").location
            path = path.nsstring.substring(to: qLocation != NSNotFound ? qLocation : path.length)
            return .unsupportedScheme(link: urlString, context: context, path: path)
        }
       
    }
    
    return .external(link: urlString as String, confirm)
}

func addUrlParameter(value: String, to url: String) -> String {
    if let _ = url.range(of: "?") {
        return url + "&" + value
    } else {
        if url.hasSuffix("/") {
            return url + value
        } else {
            return url + "/" + value
        }
    }
}

func makeInAppLink(with action:String, params:[String:Any]) -> String {
    var link = "chat://\(action)/?"
    var first:Bool = true
    for (key,value) in params {
        if !first {
            link += "&"
        } else {
            first = true
        }
        link += "\(key) = \(value)"
    }
    return link
}

func proxySettings(from url:String) -> (ProxyServerSettings?, Bool) {
    let url = url.nsstring
    if url.hasPrefix(telegram_scheme), let _ = URL(string: url as String) {
        let action = url.substring(from: telegram_scheme.length)
        
        let (vars, emptyVars) = urlVars(with: url as String)
        if action.hasPrefix("socks") {
            if let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                let server = escape(with: server)
                return (ProxyServerSettings(host: server, port: port, connection: .socks5(username: vars[keyURLUser], password: vars[keyURLPass])), true)
            }
            return (nil , true)
        } else if action.hasPrefix("proxy") {
            if let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort), let rawSecret = vars[keyURLSecret] {
                let server = escape(with: server)
                if let secret = MTProxySecret.parse(rawSecret)?.serialize() {
                    return (ProxyServerSettings(host: server, port: port, connection: .mtp(secret: secret)), true)
                }
            }
        }
        
    } else if let _ = URL(string: url as String) {
        let link = inApp(for: url, applyProxy: {_ in})
        switch link {
        case let .socks(_, settings, _):
            return (settings, true)
        default:
            break
        }
    }
    return (nil, false)
}

public struct ParsedWalletUrl {
    public let address: String
    public let amount: Int64?
    public let comment: String?
}

//
//public func parseWalletUrl(_ url: URL) -> ParsedWalletUrl? {
//    guard url.scheme == "ton" && url.host == "transfer" else {
//        return nil
//    }
//    var address: String?
//    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
//    if isValidAddress(path) {
//        address = path
//    }
//    var amount: Int64?
//    var comment: String?
//    if let query = url.query, let components = URLComponents(string: "/?" + query), let queryItems = components.queryItems {
//        for queryItem in queryItems {
//            if let value = queryItem.value {
//                if queryItem.name == "amount", !value.isEmpty, let amountValue = Int64(value) {
//                    amount = amountValue
//                } else if queryItem.name == "text", !value.isEmpty {
//                    comment = value
//                }
//            }
//        }
//    }
//    return address.flatMap { ParsedWalletUrl(address: $0, amount: amount, comment: comment) }
//}



func resolveInstantViewUrl(account: Account, url: String) -> Signal<inAppLink, NoError> {
    return webpagePreview(account: account, urls: [url]) |> filter { $0 != .progress } |> map { $0.result }
        |> mapToSignal { webpage -> Signal<inAppLink, NoError> in
            if let webpage = webpage {
                
                if case let .Loaded(content) = webpage.content {
                    if content.instantPage != nil {
                        var anchorValue: String?
                        if let anchorRange = url.range(of: "#") {
                            let anchor = url[anchorRange.upperBound...]
                            if !anchor.isEmpty {
                                anchorValue = String(anchor)
                            }
                        }
                        return .single(.instantView(link: url, webpage: webpage, anchor: anchorValue))
                    } else {
                        return .single(.external(link: url, false))
                    }
                } else {
                    return .complete()
                }
            } else {
                return .single(.external(link: url, false))
            }
    }
}


public func explicitUrl(_ url: String) -> String {
    var url = url
    if !url.hasPrefix("http") && !url.hasPrefix("https") && url.range(of: "://") == nil {
        url = "https://\(url)"
    }
    return url
}


func urlWithoutScheme(from url: URL) -> (url: String, host: String)? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
        return nil
    }
    
    guard let host = components.host else {
        return nil
    }
    
    var urlString = host
    
    if !components.path.isEmpty {
        urlString += components.path
    }
    
    if let query = components.query, !query.isEmpty {
        urlString += "?" + query
    }
    
    if let fragment = components.fragment, !fragment.isEmpty {
        urlString += "#" + fragment
    }
    
    if urlString.hasSuffix("/") {
        _ = urlString.removeLast()
    }
    
    return (url: urlString, host: host)
}
