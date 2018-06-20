//
//  TwoStepVerification.swift
//  TelegramMac
//
//  Created by keepcoder on 17/01/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import PostboxMac
import TelegramCoreMac
import SwiftSignalKitMac
import MtProtoKitMac



//func apiInputPeer(_ peer: Peer) -> Api.InputPeer? {
//
//    switch peer {
//    case let user as TelegramUser where user.accessHash != nil:
//        return Api.InputPeer.inputPeerUser(userId: user.id.id, accessHash: user.accessHash!)
//    case let group as TelegramGroup:
//        return Api.InputPeer.inputPeerChat(chatId: group.id.id)
//    case let channel as TelegramChannel:
//        if let accessHash = channel.accessHash {
//            return Api.InputPeer.inputPeerChannel(channelId: channel.id.id, accessHash: accessHash)
//        } else {
//            return nil
//        }
//    default:
//        return nil
//    }
//}
//
//func apiInputChannel(_ peer: Peer) -> Api.InputChannel? {
//    if let channel = peer as? TelegramChannel, let accessHash = channel.accessHash {
//        return Api.InputChannel.inputChannel(channelId: channel.id.id, accessHash: accessHash)
//    } else {
//        return nil
//    }
//}
//
//func apiInputUser(_ peer: Peer) -> Api.InputUser? {
//    if let user = peer as? TelegramUser, let accessHash = user.accessHash {
//        return Api.InputUser.inputUser(userId: user.id.id, accessHash: accessHash)
//    } else {
//        return nil
//    }
//}
//
//
//
//public func reportMessages(postbox: Postbox, network: Network, peerId: PeerId, messageIds: [MessageId], reason:ReportReason) -> Signal<Void, Void> {
//    return postbox.modify{ transaction -> Void in
//        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
//           // return Api.functions.messages.
//        }
//    }
//}

//public func getCountryCode(network: Network)->Signal<String, Void> {
//    return network.request(Api.functions.help.getNearestDc()) |> retryRequest |> map { value in
//        switch value {
//        case let .nearestDc(country, _, _):
//            return country
//        }
//    }
//}



//public func dropSecureId(network: Network, currentPassword: String) -> Signal<Void, AuthorizationPasswordVerificationError> {
//    return twoStepAuthData(network)
//        |> mapError { _ -> AuthorizationPasswordVerificationError in
//            return .generic
//        }
//        |> mapToSignal { authData -> Signal<Void, AuthorizationPasswordVerificationError> in
//            if let currentSalt = authData.currentSalt {
//                var data = Data()
//                data.append(currentSalt)
//                data.append(currentPassword.data(using: .utf8, allowLossyConversion: true)!)
//                data.append(currentSalt)
//                currentPasswordHash = Buffer(data: sha256Digest(data))
//            } else {
//                currentPasswordHash = Buffer(data: Data())
//            }
//            
//            let flags: Int32 = 1 << 1
//            
//            let settings = network.request(Api.functions.account.getPasswordSettings(currentPasswordHash: currentPasswordHash), automaticFloodWait: false) |> mapError {_ in return AuthorizationPasswordVerificationError.generic}
//    
//            
//            return settings |> mapToSignal { value -> Signal<Void, AuthorizationPasswordVerificationError> in
//                switch value {
//                case let .passwordSettings(email, secureSalt, _, _):
//                    return network.request(Api.functions.account.updatePasswordSettings(currentPasswordHash: currentPasswordHash, newSettings: Api.account.PasswordInputSettings.passwordInputSettings(flags: flags, newSalt: secureSalt, newPasswordHash: currentPasswordHash, hint: nil, email: email, newSecureSalt: secureSalt, newSecureSecret: nil, newSecureSecretId: nil)), automaticFloodWait: false) |> map {_ in} |> mapError {_ in return AuthorizationPasswordVerificationError.generic}
//                }
//            }
//    }
//}

