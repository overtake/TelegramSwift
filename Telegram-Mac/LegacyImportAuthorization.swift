//
//  LegacyImportAuthorization.swift
//  Telegram
//
//  Created by keepcoder on 05/03/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//


import SwiftSignalKitMac
import PostboxMac
import TelegramCoreMac
//import MtProtoKitMac
//
//enum AuthorizationLegacyData {
//    case data(masterDatacenterId: Int32, userId:Int32, groups:[String: [String: Data]], peers:[Peer], secretMessages:[StoreMessage], resources: [(MediaResource, Data)], secretState:[PeerId: SecretChatStateBridge], passcode:String?)
//    case passcodeRequired
//    case none
//}
//
//private enum LegacyGroupResult {
//    case data(NSDictionary)
//    case passcodeRequired
//    case empty
//}
//
//private func keychainData(from dictionary: NSDictionary) -> [String : Data] {
//    var data:[String: Data] = [:]
//    for (key, value) in dictionary {
//        data[key as! String] = NSKeyedArchiver.archivedData(withRootObject: value)
//    }
//    return data
//}
//
//private let keychainGroups:NSDictionary? = {
//    if let keychainData = SSKeychain.passwordData(forService: "Telegram", account: "authkeys") {
//        return NSKeyedUnarchiver.unarchiveObject(with: keychainData) as? NSDictionary
//    } else {
//        return nil
//    }
//} ()
//
//private func legacyGroupData (_ groupName: String, passcode:Data) -> LegacyGroupResult {
//    assert(passcode.count == 64)
//
//    let groupData:NSData?
//
//    #if APP_STORE
//        if let data = keychainGroups?[groupName] as? NSData {
//            groupData = data
//        } else {
//            groupData = nil
//        }
//    #else
//        let applicationSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
//        let applicationName = "Telegram"
//        let dataDirectory = applicationSupportPath + "/\(applicationName)/encrypt-mtkeychain"
//        let path = dataDirectory + "/ru.keepcoder.Telegram_\(groupName).bin"
//        NSLog("\(path)")
//
//        groupData = NSData(contentsOf: URL(fileURLWithPath: path))
//    #endif
//
//
//
//    if let groupData = groupData, groupData.length >= 8 {
//        let decrypt = NSMutableData(data: groupData.subdata(with: NSMakeRange(4, groupData.length - 8)))
//        let modifiedIv = NSMutableData(data: passcode.subdata(in: 32 ..< 64))
//        MTAesDecryptInplaceAndModifyIv(decrypt, passcode.subdata(in: 0 ..< 32), modifiedIv)
//
//        var hash:Int32 = 0
//        var length:Int32 = 0
//        groupData.getBytes(&hash, range: NSMakeRange(groupData.length - 4, 4))
//        groupData.getBytes(&length, range: NSMakeRange(0, 4))
//
//        let decryptedHash = MTMurMurHash32(decrypt.bytes, length)
//
//        if hash != decryptedHash {
//            return .passcodeRequired
//        }
//
//        let object = NSKeyedUnarchiver.unarchiveObject(with: decrypt.subdata(with: NSMakeRange(0, Int(length))))
//
//        if let object = object as? NSDictionary {
//            return .data(object)
//        }
//
//    }
//    return .empty
//}
//
//func legacyAuthData(passcode:Data, textPasscode:String? = nil) -> AuthorizationLegacyData {
//
//    var groupsData:[String : [String: Data]] = [:]
//
//    let groups:[String] = ["persistent", "primes", "temp"]
//    var masterDatacenterId:Int32?
//    var userId:Int32?
//    var sqlKey:String?
//    for group in groups {
//        switch legacyGroupData(group, passcode: passcode) {
//        case .passcodeRequired:
//            return .passcodeRequired
//        case let .data(data):
//            if let dcId = data["dc_id"] as? NSNumber, let id = data["user_id"] as? NSNumber {
//                masterDatacenterId = dcId.int32Value
//                userId = id.int32Value
//            }
//            if let ekey = data["e_key"] as? String {
//                sqlKey = ekey
//            }
//            groupsData[group] = keychainData(from : data)
//
//        default:
//            break
//        }
//    }
//
//
//
//    if let masterDatacenterId = masterDatacenterId, let userId = userId {
//
//        var peers:[Peer] = []
//        var messages:[StoreMessage] = []
//        var participantPeerIds:Set<PeerId> = Set()
//        var resources: [(MediaResource, Data)] = []
//        var secretState:[PeerId: SecretChatStateBridge] = [:]
//
//
//        if let sSize = fileSize(legacySqlPath), sSize > 0, let ySize = fileSize(legacyYapPath), ySize > 0, let sqlKey = sqlKey, let keyData = sqlKey.data(using: .utf8), FileManager.default.fileExists(atPath: legacySqlPath), FileManager.default.fileExists(atPath: legacyYapPath), let sql = SqliteInterface(databasePath: legacySqlPath), let yap = SqliteInterface(databasePath: legacyYapPath)    {
//
//
//            if sql.unlock(password: keyData) {
//
//                sql.select("select serialized from encrypted_chats", { value -> Bool in
//                    if let chat = MacosLegacy.parse(Buffer(data: value.getData(at: 0))) as? MacosLegacy.EncryptedChat {
//                        switch chat {
//                        case let .encryptedChat(chat):
//                            let secret = TelegramSecretChat(id: PeerId(namespace: Namespaces.Peer.SecretChat, id: chat.id), creationDate: chat.date, regularPeerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: chat.adminId == userId ? chat.participantId : chat.adminId), accessHash: chat.accessHash, role: chat.adminId == userId ? .creator : .participant, embeddedState: .terminated, messageAutoremoveTimeout: nil)
//                            peers.append(secret)
//                            participantPeerIds.insert(secret.regularPeerId)
//                            secretState[secret.id] = SecretChatStateBridge(role: chat.adminId == userId ? .creator : .participant)
//                        }
//                    }
//
//                    return true
//                })
//
//                var secretKeys:[Int64: SecretFileEncryptionKey] = [:]
//
//                yap.select("select data, key from database2 where collection = \"encrypted_image_collection\"", { keyIvValue -> Bool in
//                    if let dict = NSKeyedUnarchiver.unarchiveObject(with: keyIvValue.getData(at: 0)) as? NSDictionary {
//                        if let aesKey = dict["key"] as? Data, let aesIv = dict["iv"] as? Data {
//                            secretKeys[keyIvValue.getInt64(at: 1)] = SecretFileEncryptionKey(aesKey: aesKey, aesIv: aesIv)
//                        }
//                    }
//                    return true
//                })
//
//
//
//                for peer in peers {
//                    sql.select("select serialized, message_text from messages where peer_id in (\(peer.id.id))", { value -> Bool in
//
//                        var text = value.getString(at: 1)
//
//                        let message = MacosLegacy.parse(Buffer(data: value.getData(at: 0)))
//                        if let message = message as? MacosLegacy.Message {
//                            switch message {
//                            case let .destructMessage(message):
//
//                                guard message.dstate == 2 else {
//                                    break
//                                }
//
//                                var media:[Media] = []
//                                switch message.media {
//                                case let .messageMediaGeo(geo: geo):
//                                    switch geo {
//                                    case let .geoPoint(long, lat):
//                                        media.append(TelegramMediaMap(latitude: lat, longitude: long, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil))
//                                    default:
//                                        media.append(TelegramMediaMap(latitude: 0, longitude: 0, geoPlace: nil, venue: nil, liveBroadcastingTimeout: nil))
//                                    }
//                                case let .messageMediaContact(phoneNumber, firstName, lastName, userId):
//                                    let peerId:PeerId? = userId != 0 ? PeerId(namespace: Namespaces.Peer.CloudUser, id: userId) : nil
//                                    media.append(TelegramMediaContact(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, peerId: peerId))
//                                case let .messageMediaPhoto(photo, caption):
//                                    switch photo {
//                                    case let .photo(_, id, accessHash, _, sizes):
//
//                                        if let key = secretKeys[id] {
//                                            text = caption
//                                            var representations: [TelegramMediaImageRepresentation] = []
//
//                                            for size in sizes {
//                                                switch size {
//                                                case let .photoCachedSize(_, _, w, h, bytes):
//                                                    let resource = LocalFileMediaResource(fileId: arc4random64())
//                                                    representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
//                                                    resources.append((resource, bytes.makeData()))
//
//
//                                                case let .photoSize(_, location, w, h, size):
//                                                    switch location {
//                                                    case let .fileLocation(dcId, _, _, _):
//                                                        let resource = SecretFileMediaResource(fileId: id, accessHash: accessHash, size: nil, decryptedSize: size, datacenterId: Int(dcId), key: key)
//
//                                                        representations.append(TelegramMediaImageRepresentation(dimensions: NSMakeSize(CGFloat(w), CGFloat(h)), resource: resource))
//
//                                                        let image = TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudSecretImage, id: id), representations: representations, reference: nil)
//
//                                                        media.append(image)
//                                                    default:
//                                                        break
//                                                    }
//
//                                                case .photoSizeEmpty:
//                                                    break
//                                                }
//                                            }
//
//                                        }
//
//
//                                        break
//                                    default:
//                                        break
//                                    }
//                                    break
//                                case let .messageMediaDocument(document, caption):
//
//                                    switch document {
//                                    case let .document(id, accessHash, _, mimeType, size, thumb, dcId, _, attributes):
//                                        if let key = secretKeys[id] {
//                                            text = caption
//                                            var parsedAttributes: [TelegramMediaFileAttribute] = []
//                                            for attribute in attributes {
//                                                switch attribute {
//                                                case let .documentAttributeFilename(fileName):
//                                                    parsedAttributes.append(.FileName(fileName: fileName))
//                                                case let .documentAttributeSticker(_, alt, _, _):
//                                                    parsedAttributes.append(.Sticker(displayText: alt, packReference: nil, maskData: nil))
//                                                case .documentAttributeHasStickers:
//                                                    parsedAttributes.append(.HasLinkedStickers)
//                                                case let .documentAttributeImageSize(w, h):
//                                                    parsedAttributes.append(.ImageSize(size: CGSize(width: CGFloat(w), height: CGFloat(h))))
//                                                case .documentAttributeAnimated:
//                                                    parsedAttributes.append(.Animated)
//                                                case let .documentAttributeVideo(duration, w, h):
//                                                    parsedAttributes.append(.Video(duration: Int(duration), size: CGSize(width: CGFloat(w), height: CGFloat(h)), flags: []))
//                                                case let .documentAttributeAudio(flags, duration, title, performer, waveform):
//                                                    let isVoice = (flags & (1 << 10)) != 0
//                                                    var waveformBuffer: MemoryBuffer?
//                                                    if let waveform = waveform {
//                                                        waveformBuffer = MemoryBuffer(waveform)
//                                                    }
//                                                    parsedAttributes.append(.Audio(isVoice: isVoice, duration: Int(duration), title: title, performer: performer, waveform: waveformBuffer))
//                                                default:
//                                                    break
//                                                }
//                                            }
//
//                                            var previewRepresentations: [TelegramMediaImageRepresentation] = []
//
//                                            switch thumb {
//                                            case let .photoCachedSize(_, _, w, h, bytes):
//
//                                                let resource = LocalFileMediaResource(fileId: arc4random64())
//                                                previewRepresentations.append(TelegramMediaImageRepresentation(dimensions: NSMakeSize(CGFloat(w), CGFloat(h)), resource: resource))
//                                                resources.append((resource, bytes.makeData()))
//                                            default:
//                                                break
//                                            }
//
//                                            let resource = SecretFileMediaResource(fileId: id, accessHash: accessHash, size: nil, decryptedSize: size, datacenterId: Int(dcId), key: key)
//
//
//                                            let fileMedia = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.CloudSecretFile, id: id), resource: resource, previewRepresentations: previewRepresentations, mimeType: mimeType, size: Int(size), attributes: parsedAttributes)
//                                            media.append(fileMedia)
//
//                                        }
//                                    default:
//                                        break
//                                    }
//                                default:
//                                    break
//                                }
//
//                                var attributes:[MessageAttribute] = []
//
//                                if message.ttlSeconds > 0 {
//                                    var countdownBeginTime:Int32? = nil
//                                    if message.destructionTime > 0 {
//                                        countdownBeginTime = message.destructionTime - message.ttlSeconds
//                                    }
//                                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: message.ttlSeconds, countdownBeginTime: countdownBeginTime))
//                                }
//
//                                var flags:StoreMessageFlags = StoreMessageFlags()
//
//                                if message.fromId != userId {
//                                    flags.insert(.Incoming)
//                                }
//                                let tags = tagsForStoreMessage(incoming: message.fromId == peer.id.id, attributes: [], media: media, textEntities: nil)
//                                //id: MessageId, globallyUniqueId: Int64?, groupingKey: Int64?, timestamp: Int32, flags: StoreMessageFlags, tags: MessageTags, globalTags: GlobalMessageTags, localTags: LocalMessageTags, forwardInfo: StoreMessageForwardInfo?, authorId: PeerId?, text: String, attributes: [MessageAttribute], media: [Media]
//                                messages.append(StoreMessage(id: MessageId(peerId: peer.id, namespace: Namespaces.Message.SecretIncoming, id: message.id), globallyUniqueId: message.random, groupingKey: nil, timestamp: message.date, flags: flags, tags: tags.0, globalTags: tags.1, localTags: [], forwardInfo: nil, authorId: PeerId(namespace: Namespaces.Peer.CloudUser, id: message.fromId), text: text, attributes: attributes, media: media))
//                            }
//                        }
//                        return true
//                    })
//                }
//
//                let participantIds = participantPeerIds.map({String($0.id)}).joined(separator: ",")
//                sql.select("select serialized from users where n_id in (\(participantIds))", { value -> Bool in
//
//                    if let user = MacosLegacy.parse(Buffer(data: value.getData(at: 0))) as? MacosLegacy.User {
//                        switch user {
//                        case let .user(user):
//                            var representations:[TelegramMediaImageRepresentation] = []
//                            if let photo = user.photo {
//                                switch photo {
//                                case let .userProfilePhoto(photo):
//                                    if let small = mediaResourceFromApiFileLocation(photo.photoSmall, size: nil) {
//                                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 100, height: 100), resource: small))
//                                    }
//                                    if let big = mediaResourceFromApiFileLocation(photo.photoBig, size: nil) {
//                                        representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 100, height: 100), resource: big))
//                                    }
//                                default:
//                                    break
//                                }
//                            }
//                            peers.append(TelegramUser(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: user.id), accessHash: user.accessHash, firstName: user.firstName, lastName: user.lastName, username: user.username, phone: user.phone, photo: representations, botInfo: nil, restrictionInfo: nil, flags: []))
//                        default:
//                            break
//                        }
//                    }
//                    return true
//                })
//
//
//            }
//
//        }
//
//        return .data(masterDatacenterId: masterDatacenterId, userId: userId, groups: groupsData, peers: peers, secretMessages: messages, resources: resources, secretState: secretState, passcode: textPasscode)
//    }
//
//    return .none
//}
//
//private func legacyMediaImageRepresentationsFromApiSizes(_ sizes: [MacosLegacy.PhotoSize]) -> [TelegramMediaImageRepresentation] {
//    var representations: [TelegramMediaImageRepresentation] = []
//    for size in sizes {
//        switch size {
//        case let .photoCachedSize(_, location, w, h, bytes):
//            if let resource = mediaResourceFromApiFileLocation(location, size: bytes.size) {
//                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
//            }
//        case let .photoSize(_, location, w, h, size):
//            if let resource = mediaResourceFromApiFileLocation(location, size: Int(size)) {
//                representations.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(w), height: CGFloat(h)), resource: resource))
//            }
//        case .photoSizeEmpty:
//            break
//        }
//    }
//    return representations
//}
//
//private func mediaResourceFromApiFileLocation(_ fileLocation: MacosLegacy.FileLocation, size: Int?) -> TelegramMediaResource? {
//    switch fileLocation {
//    case let .fileLocation(dcId, volumeId, localId, secret):
//        return CloudFileMediaResource(datacenterId: Int(dcId), volumeId: volumeId, localId: localId, secret: secret, size: size)
//    case .fileLocationUnavailable:
//        return nil
//    }
//}
//
//private var legacySqlPath: String {
//
//    let applicationSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
//    let path =  applicationSupportPath + "/" + "Telegram" + "/database/"
//    #if APP_STORE
//        return path + "encrypted.sqlite"
//    #else
//        return path + "encrypted6.sqlite"
//    #endif
//}
//
//private var legacyYapPath: String {
//    let applicationSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
//    return applicationSupportPath + "/" + "Telegram" + "/database/" + "yap_store-t143.sqlite"
//}
//
//func clearLegacyData() {
//    let applicationSupportPath = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)[0]
//    let applicationName = "Telegram"
//    let dataDirectory = applicationSupportPath + "/\(applicationName)/encrypt-mtkeychain"
//    try? FileManager.default.removeItem(atPath: dataDirectory)
//}
//
//func emptyPasscodeData() -> Data {
//
//    var data:Data = Data()
//    var zero:UInt8 = 0
//    for _ in 0 ..< 64 {
//        data.append(&zero, count: 1)
//    }
//    return data
//}

