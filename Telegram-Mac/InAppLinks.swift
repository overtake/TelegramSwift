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
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac
private let inapp:String = "chat://"
private let tgme:String = "tg://"


enum ChatInitialActionBehavior : Equatable {
    case none
    case automatic
}

enum ChatInitialAction : Equatable {
    case start(parameter: String, behavior: ChatInitialActionBehavior)
    case inputText(text: String, behavior: ChatInitialActionBehavior)
    case files(list: [String], behavior: ChatInitialActionBehavior)
}

func ==(lhs:ChatInitialAction, rhs:ChatInitialAction) -> Bool {
    switch lhs {
    case let .start(lhsText, lhsBehavior):
        if case let .start(rhsText, rhsBehavior) = rhs, lhsText == rhsText, lhsBehavior == rhsBehavior {
            return true
        } else {
            return false
        }
    case let .inputText(lhsText, lhsBehavior):
        if case let .inputText(rhsText, rhsBehavior) = rhs, lhsText == rhsText, lhsBehavior == rhsBehavior {
            return true
        } else {
            return false
        }
    case let .files(lhsList, lhsBehavior):
        if case let .files(rhsList, rhsBehavior) = rhs, lhsList == rhsList, lhsBehavior == rhsBehavior {
            return true
        } else {
            return false
        }
    }
}

var globalLinkExecutor:TextViewInteractions {
    get {
        return TextViewInteractions(processURL:{(link) in
            if let link = link as? inAppLink {
                execute(inapp:link)
            }
        }, isDomainLink: { value in
            if !value.hasPrefix("@") && !value.hasPrefix("#") && !value.hasPrefix("/") && !value.hasPrefix("$") {
                return true
            }
            return false
        }, makeLinkType: { link, url in
            if let link = link as? inAppLink {
                switch link {
                case .botCommand:
                    return .command
                case .hashtag:
                    return .hashtag
                case .followResolvedName:
                    if url.hasPrefix("@") {
                        return .username
                    } else {
                        return .plain
                    }
                case let .external(link, _):
                    if isValidEmail(link) {
                        return .email
                    } else {
                        return .plain
                    }
                case .stickerPack:
                    return .stickerPack
                case .joinchat:
                    return .inviteLink
                default:
                    return .plain
                }
            }
            return .plain
        }, localizeLinkCopy: { type in
            return copyContextText(from: type)
        })
    }
}

func copyContextText(from type: LinkType) -> String {
    switch type {
    case .username:
        return L10n.textContextCopyUsername
    case .command:
        return L10n.textContextCopyCommand
    case .hashtag:
        return L10n.textContextCopyHashtag
    case .email:
        return L10n.textContextCopyEmail
    case .plain:
        return L10n.textContextCopyLink
    case .inviteLink:
        return L10n.textContextCopyInviteLink
    case .stickerPack:
        return L10n.textContextCopyStickerPack
    }
}

func execute(inapp:inAppLink) {
    
    switch inapp {
    case let .external(link,needConfirm):
        var url:String = link.trimmed
        if !url.hasPrefix("http") && !url.hasPrefix("ftp") {
            if isValidEmail(link) {
                url = "mailto:" + url
            } else {
                url = "http://" + url
            }
        }
        let escaped = escape(with:url)
        if let url = URL(string: escaped) {
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
                        return
                    }
                }

                NSWorkspace.shared.open(url)
            }
            if needConfirm {
                confirm(for: mainWindow, information: tr(L10n.inAppLinksConfirmOpenExternal(url.absoluteString)), successHandler: {_ in success()})
            } else {
                success()
            }
        }
    case let .peerInfo(peerId, action, openChat, postId, callback):
        let messageId:MessageId?
        if let postId = postId {
            messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: MessageId.Id(postId))
        } else {
            messageId = nil
        }
        callback(peerId, openChat, messageId, action)
    case let .followResolvedName(username, postId, account, action, callback):
        let _ = showModalProgress(signal: resolvePeerByName(account: account, name: username) |> mapToSignal { peerId -> Signal<Peer?, Void> in
            if let peerId = peerId {
                return account.postbox.loadedPeerWithId(peerId) |> map {Optional($0)}
            }
            return .single(nil)
        } |> deliverOnMainQueue, for: mainWindow).start(next: { peer in
            if let peer = peer {
                let messageId:MessageId?
                if let postId = postId {
                    messageId = MessageId(peerId: peer.id, namespace: Namespaces.Message.Cloud, id: postId)
                } else {
                    messageId = nil
                }
                callback(peer.id, peer.isChannel || peer.isSupergroup || peer.isBot, messageId, action)
            } else {
                alert(for: mainWindow, info: tr(L10n.alertUserDoesntExists))
            }
            
        })
    case let .inviteBotToGroup(username, account, action, callback):
        
        let _ = (showModalProgress(signal: resolvePeerByName(account: account, name: username) |> filter {$0 != nil} |> map{$0!} |> deliverOnMainQueue, for: mainWindow) |> mapToSignal { memberId -> Signal<PeerId, Void> in
            
            return selectModalPeers(account: account, title: "", behavior: SelectChatsBehavior(limit: 1), confirmation: { peerIds -> Signal<Bool, Void> in
                if let peerId = peerIds.first {
                    return account.postbox.loadedPeerWithId(peerId) |> deliverOnMainQueue |> mapToSignal { peer -> Signal<Bool, Void> in
                        return confirmSignal(for: mainWindow, information: tr(L10n.confirmAddBotToGroup(peer.displayTitle)))
                    }
                }
                return .single(false)
            }) |> deliverOnMainQueue |> filter {$0.first != nil} |> map {$0.first!} |> mapToSignal { peerId in
                return showModalProgress(signal: addPeerMember(account: account, peerId: peerId, memberId: memberId), for: mainWindow) |> mapError {_ in} |> map {peerId}
            }
        }).start(next: { peerId in
            callback(peerId, true, nil, action)
        }, error: {
            
        })
    case let .botCommand(command, interaction):
        interaction(command)
    case let .hashtag(hashtag, interaction):
        interaction(hashtag)
    case let .joinchat(hash, account, interaction):
        _ = showModalProgress(signal: joinLinkInformation(hash, account: account), for: mainWindow).start(next: { (result) in
            switch result {
            case let .alreadyJoined(peerId):
                interaction(peerId, true, nil, nil)
            case .invite:
                showModal(with: JoinLinkPreviewModalController(account, hash: hash, join: result, interaction: { peerId in
                    if let peerId = peerId {
                        interaction(peerId, true, nil, nil)
                    }
                }), for: mainWindow)
            case .invalidHash:
                alert(for: mainWindow, info: tr(L10n.groupUnavailable))
            }
        })
    case let .callback(param, interaction):
        interaction(param)
    case let .logout(interaction):
        interaction()
    case let .shareUrl(account, url):
        if !url.hasPrefix("@") {
            showModal(with: ShareModalController(ShareLinkObject(account, link: url)), for: mainWindow)
        }
    case let .stickerPack(reference, account, peerId):
        showModal(with: StickersPackPreviewModalController(account, peerId: peerId, reference: reference), for: mainWindow)
    case let .socks(settings, applyProxy):
        applyProxy(settings)
    case .nothing:
        break
    case let .requestSecureId(account, value):
        _ = showModalProgress(signal: requestSecureIdForm(postbox: account.postbox, network: account.network, peerId: value.peerId, scope: value.scope, publicKey: value.publicKey) |> mapToSignal { form in
            return account.postbox.loadedPeerWithId(account.peerId) |> mapError {_ in return .generic} |> map { peer in
                return (form, peer)
        }
        } |> deliverOnMainQueue, for: mainWindow).start(next: { form, peer in
            let passport = PassportWindowController(account: account, peer: peer, request: value, passport: form)
            passport.show()
        })
    }
    
}

private func escape(with link:String, addPercent: Bool = true) -> String {
    var escaped = addPercent ? link.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? link : link
    escaped = escaped.replacingOccurrences(of: "%21", with: "!")
    escaped = escaped.replacingOccurrences(of: "%24", with: "$")
    escaped = escaped.replacingOccurrences(of: "%26", with: "&")
    escaped = escaped.replacingOccurrences(of: "%2B", with: "+")
    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
    escaped = escaped.replacingOccurrences(of: "%2F", with: "/")
    escaped = escaped.replacingOccurrences(of: "%3A", with: ":")
    escaped = escaped.replacingOccurrences(of: "%3B", with: ";")
    escaped = escaped.replacingOccurrences(of: "%3D", with: "=")
    escaped = escaped.replacingOccurrences(of: "%3F", with: "?")
    escaped = escaped.replacingOccurrences(of: "%40", with: "@")
    escaped = escaped.replacingOccurrences(of: "%20", with: " ")
    escaped = escaped.replacingOccurrences(of: "%09", with: "\t")
    escaped = escaped.replacingOccurrences(of: "%23", with: "#")
    escaped = escaped.replacingOccurrences(of: "%3C", with: "<")
    escaped = escaped.replacingOccurrences(of: "%3E", with: ">")
    escaped = escaped.replacingOccurrences(of: "%22", with: "\"")
    escaped = escaped.replacingOccurrences(of: "%0A", with: "\n")
    escaped = escaped.replacingOccurrences(of: "%25", with: "%")
    escaped = escaped.replacingOccurrences(of: "%2E", with: ".")
    escaped = escaped.replacingOccurrences(of: "%2C", with: ",")
    escaped = escaped.replacingOccurrences(of: "%7D", with: "}")
    escaped = escaped.replacingOccurrences(of: "%7B", with: "{")
    escaped = escaped.replacingOccurrences(of: "%5B", with: "[")
    escaped = escaped.replacingOccurrences(of: "%5D", with: "]")
    return escaped
}


private func urlVars(with url:String) -> [String:String] {
    var vars:[String:String] = [:]
    let range = url.nsstring.range(of: "?")
    let ns:NSString = range.location != NSNotFound ? url.nsstring.substring(from: range.location + 1).nsstring : url.nsstring
    
    
    let hashes = ns.components(separatedBy: "&")
    for hash in hashes {
        let param = hash.components(separatedBy: "=")
        if param.count > 1 {
            vars[param[0]] = param[1]
        }
    }
    return vars
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
    let callback: String
    let publicKey: String
    let payload: Data
    let errors:Array<[String:String]>?
}

enum inAppLink {
    case external(link:String, Bool) // link, confirm
    case peerInfo(peerId:PeerId, action:ChatInitialAction?, openChat:Bool, postId:Int32?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case followResolvedName(username:String, postId:Int32?, account:Account, action:ChatInitialAction?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case inviteBotToGroup(username:String, account:Account, action:ChatInitialAction?, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case botCommand(String, (String)->Void)
    case callback(String, (String)->Void)
    case hashtag(String, (String)->Void)
    case shareUrl(Account, String)
    case joinchat(String, account:Account, callback:(PeerId, Bool, MessageId?, ChatInitialAction?)->Void)
    case logout(()->Void)
    case stickerPack(StickerPackReference, account:Account, peerId:PeerId?)
    case nothing
    case socks(ProxySettings, applyProxy:(ProxySettings)->Void)
    case requestSecureId(account: Account, value: inAppSecureIdRequest)
}

let telegram_me:[String] = ["telegram.me/","telegram.dog/","t.me/"]
let actions_me:[String] = ["joinchat/","addstickers/","confirmphone?","socks?"]

let telegram_scheme:String = "tg://"
let known_scheme:[String] = ["resolve?domain=","msg_url?url=","join?invite=","addstickers?set=","confirmphone", "socks?", "secureid?"]

private let keyURLUsername = "domain";
private let keyURLPostId = "post";
private let keyURLInvite = "invite";
private let keyURLUrl = "url";
private let keyURLSet = "set";
private let keyURLText = "text";
private let keyURLStart = "start";
private let keyURLStartGroup = "startgroup";


private let keyURLHost = "server";
private let keyURLPort = "port";
private let keyURLUser = "user";
private let keyURLPass = "pass";

func inApp(for url:NSString, account:Account, peerId:PeerId? = nil, openInfo:((PeerId, Bool, MessageId?, ChatInitialAction?)->Void)? = nil, hashtag:((String)->Void)? = nil, command:((String)->Void)? = nil, applyProxy:((ProxySettings) -> Void)? = nil, confirm: Bool = false) -> inAppLink {
    let external = url
    let url = url.lowercased.nsstring
    for domain in telegram_me {
        let range = url.range(of: domain)
        if range.location != NSNotFound && (range.location == 0 || url.substring(from: range.location - 1).hasPrefix("/")) {
            let string = external.substring(from: range.location + range.length)
            for action in actions_me {
                if string.hasPrefix(action) {
                    let value = string.substring(from: string.index(string.startIndex, offsetBy: action.length))
                    switch action {
                    case actions_me[0]:
                        if let openInfo = openInfo {
                            return .joinchat(value, account: account, callback: openInfo)
                        }
                    case actions_me[1]:
                        return .stickerPack(StickerPackReference.name(value), account: account, peerId: peerId)
                    case actions_me[3]:
                        let vars = urlVars(with: string)
                        if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                            let server = escape(with: server)
                            let username = vars[keyURLUser] != nil ? escape(with: vars[keyURLUser]!) : nil
                            let pass = vars[keyURLPass] != nil ? escape(with: vars[keyURLPass]!) : nil
                            return .socks(ProxySettings(host: server, port: port, username: username, password: pass, useForCalls: false), applyProxy: applyProxy)
                        }
                    default:
                        break
                    }
                }
            }
             if string.range(of: "/") == nil {
                let userAndVariables = string.components(separatedBy: "?")
                let username:String = userAndVariables[0]
                var action:ChatInitialAction? = nil
                if userAndVariables.count == 2 {
                    let vars = urlVars(with: userAndVariables[1])
                    loop: for (key,value) in vars {
                        switch key {
                        case keyURLStart:
                            action = .start(parameter: value, behavior: .none)
                            break loop;
                        case keyURLStartGroup:
                            if let openInfo = openInfo {
                                return .inviteBotToGroup(username: username, account: account, action: nil, callback: openInfo)
                            }
                            break loop;
                        default:
                            break
                        }
                    }
                }
                
                if let openInfo = openInfo {
                    if username == "iv" {
                        return .external(link: url as String, false)
                    } else {
                        return .followResolvedName(username: username, postId: nil, account: account, action: action, callback: openInfo)
                    }
                }
            } else if let openInfo = openInfo {
                let userAndPost = string.components(separatedBy: "/")
                if userAndPost.count >= 2 {
                    let name = userAndPost[0]
                    let post = userAndPost[1].isEmpty ? nil : userAndPost[1].nsstring.intValue
                    if name.hasPrefix("iv?") {
                        return .external(link: url as String, false)
                    } else if name.hasPrefix("share") {
                        let params = urlVars(with: url as String)
                        if let url = params["url"] {
                            return .shareUrl(account, url)
                        }
                        return .external(link: url as String, false)
                    } else {
                        return .followResolvedName(username: name, postId: post, account: account, action:nil, callback: openInfo)
                    }
                }
            }
        }
    }
    
    if url.hasPrefix("@"), let openInfo = openInfo {
        return .followResolvedName(username: url.substring(from: 1), postId: nil, account: account, action:nil, callback: openInfo)
    }
    
    if url.hasPrefix("/"), let command = command {
        return .botCommand(url as String, command)
    }
    if url.hasPrefix("#"), let hashtag = hashtag {
        return .hashtag(url as String, hashtag)
    }
    
    if url.hasPrefix(telegram_scheme) {
        let action = url.substring(from: telegram_scheme.length)
        
        let vars = urlVars(with: external as String)
        
        for i in 0 ..< known_scheme.count {
            let known = known_scheme[i]
            if action.hasPrefix(known) {
                
                switch known {
                case known_scheme[0]:
                    if let username = vars[keyURLUsername], let openInfo = openInfo {
                        let post = vars[keyURLPostId]?.nsstring.intValue
                        var action:ChatInitialAction? = nil
                        loop: for (key,value) in vars {
                            switch key {
                            case keyURLStart:
                                action = .start(parameter: value, behavior: .none)
                                break loop;
                            default:
                                break
                            }
                        }
                        return .followResolvedName(username: username, postId: post, account: account, action: action, callback:openInfo)
                    }
                case known_scheme[1]:
                    if let url = vars[keyURLUrl] {
                        let url = url.nsstring.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        let text = vars[keyURLText]?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding
                        if let url = url {
                            var applied = url
                            if let text = text {
                                applied += "\n" + text
                            }
                            return .shareUrl(account, applied)
                            
                        }
                    }
                case known_scheme[2]:
                    if let invite = vars[keyURLInvite], let openInfo = openInfo {
                        return .joinchat(invite, account: account, callback: openInfo)
                    }
                case known_scheme[3]:
                    if let set = vars[keyURLSet] {
                        return .stickerPack(.name(set), account:account, peerId:nil)
                    }
                case known_scheme[5]:
                    if let applyProxy = applyProxy, let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                        let server = escape(with: server)
                        return .socks(ProxySettings(host: server, port: port, username: vars[keyURLUser], password: vars[keyURLPass], useForCalls: false), applyProxy: applyProxy)
                    }
                case known_scheme[6]:
                    if let scope = vars["scope"], let callbackUrl = vars["callback_url"], let publicKey = vars["public_key"], let rawBotId = vars["bot_id"], let botId = Int32(rawBotId) {
                        let payload = vars["payload"]?.data(using: .utf8) ?? Data()
                        var errors: Array<[String:String]>?
                        if let maybeErrors = vars["errors"] {
                            let raw = escape(with: maybeErrors, addPercent: false)
                            if let data = raw.data(using: .utf8) {
                                if let json = try? JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.allowFragments) {
                                    errors = json as? Array<[String:String]>
                                }
                            }
                        }
                        return .requestSecureId(account: account, value: inAppSecureIdRequest(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: botId), scope: escape(with: scope), callback: escape(with: callbackUrl, addPercent: false), publicKey: escape(with: publicKey, addPercent: false), payload: payload, errors: errors))
                    }
                default:
                    break
                }
                
                return .nothing

            }
        }
       
    }
    
    return .external(link: external as String, confirm)
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

func proxySettings(from url:String) -> (ProxySettings?, Bool) {
    let url = url.nsstring
    if url.hasPrefix(telegram_scheme) {
        let action = url.substring(from: telegram_scheme.length)
        
        let vars = urlVars(with: url as String)
        if action.hasPrefix("socks") {
            if let server = vars[keyURLHost], let maybePort = vars[keyURLPort], let port = Int32(maybePort) {
                let server = escape(with: server)
                return (ProxySettings(host: server, port: port, username: vars[keyURLUser], password: vars[keyURLPass], useForCalls: false), true)
            }
            return (nil , true)
        }
        
    }
    return (nil, false)
}
