//
//  ChatHistoryEntry.swift
//  Telegram-Mac
//
//  Created by keepcoder on 13/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

import PostboxMac
import TelegramCoreMac

enum ChatHistoryEntryId : Hashable {
    case hole(MessageHistoryHole)
    case message(Message)
    case unread
    case date(MessageIndex)
    case undefined
    case maybeId(AnyHashable)
    var hashValue: Int {
        switch self {
        case let .hole(index):
            return index.stableId.hashValue
        case .message(let message):
            return message.stableId.hashValue
        case .unread:
            return 2 << 1
        case .date(let index):
            return index.hashValue
        case .undefined:
            return 3 << 1
        case .maybeId(let id):
            return id.hashValue
        }
    }
    
    static func ==(lhs:ChatHistoryEntryId, rhs: ChatHistoryEntryId) -> Bool {
        switch lhs {
        case let .hole(index):
            if case .hole(index) = rhs {
                return true
            } else {
                return false
            }
        case .message(let lhsMessage):
            if case .message(let rhsMessage) = rhs {
                return lhsMessage.stableId == rhsMessage.stableId
            } else {
                return false
            }
        case .unread:
            if case .unread = rhs {
                return true
            } else {
                return false
            }
        case .date(let index):
            if case .date(index) = rhs {
                return true
            } else {
                return false
            }
        case .maybeId(let id):
            if case .maybeId(id) = rhs {
                return true
            } else {
                return false
            }
        case .undefined:
            if case .undefined = rhs {
                return true
            } else {
                return false
            }
        }
    }
    
    var stableIndex: UInt64 {
        switch self {
        case .hole:
            return UInt64(0) << 40
        case .message:
            return UInt64(1) << 40
        case .unread:
             return UInt64(2) << 40
        case .date:
            return UInt64(3) << 40
        case .undefined:
            return UInt64(4) << 40
        case .maybeId:
            return UInt64(5) << 40
        }
    }

}

enum ChatHistoryEntry: Identifiable, Comparable {
    case HoleEntry(MessageHistoryHole)
    case MessageEntry(Message, Bool, ChatItemType, ForwardItemType?, MessageHistoryEntryLocation?)
    case UnreadEntry(MessageIndex)
    case DateEntry(MessageIndex)
    case bottom
    var message:Message? {
        switch self {
        case let .MessageEntry(message,_,_,_,_):
            return message
        default:
          return nil
        }
    }
    var location:MessageHistoryEntryLocation? {
        switch self {
        case let .MessageEntry(_,_,_,_,location):
            return location
        default:
            return nil
        }
    }
    
    
    var stableId: ChatHistoryEntryId {
        switch self {
        case let .HoleEntry(hole):
            return .hole(hole)
        case let .MessageEntry(message,_,_,_,_):
            return .message(message)
        case let .DateEntry(index):
            return .date(index)
        case .UnreadEntry:
            return .unread
        case .bottom:
            return .undefined
        }
    }
    
    var index: MessageIndex {
        switch self {
        case let .HoleEntry(hole):
            return hole.maxIndex
        case let .MessageEntry(message,_,_, _,_):
            return MessageIndex(message)
        case let .UnreadEntry(index):
            return index
        case let .DateEntry(index):
            return index
        case .bottom:
            return MessageIndex.absoluteUpperBound()
        }
    }

}

func ==(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    switch lhs {
    case let .HoleEntry(lhsHole):
        switch rhs {
        case let .HoleEntry(rhsHole) where lhsHole == rhsHole:
            return true
        default:
            return false
        }
    case let .MessageEntry(lhsMessage,lhsRead,lhsType, lhsFwdType, _):
        switch rhs {
        case let .MessageEntry(rhsMessage,rhsRead,rhsType, rhsFwdType, _) where MessageIndex(lhsMessage) == MessageIndex(rhsMessage) && lhsMessage.stableVersion == rhsMessage.stableVersion && lhsRead == rhsRead && lhsType == rhsType && lhsFwdType == rhsFwdType:
            if lhsMessage.media.count != rhsMessage.media.count {
                return false
            }
            for i in 0 ..< lhsMessage.media.count {
                if !lhsMessage.media[i].isEqual(rhsMessage.media[i]) {
                    return false
                }
            }
            
            
            if lhsMessage.associatedMessages.count != rhsMessage.associatedMessages.count {
                return false
            } else {
                for (messageId, lhsAssociatedMessage) in lhsMessage.associatedMessages {
                    if let rhsAssociatedMessage = rhsMessage.associatedMessages[messageId] {
                        if lhsAssociatedMessage.stableVersion != rhsAssociatedMessage.stableVersion {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            
            if lhsMessage.peers.count != rhsMessage.peers.count {
                return false
            } else {
                for (lhsPeerId, lhsPeer) in lhsMessage.peers {
                    if let rhsPeer = rhsMessage.peers[lhsPeerId] {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else {
                        return false
                    }
                }
            }
            
            return true
        default:
            return false
        }
    case let .UnreadEntry(lhsIndex):
        switch rhs {
        case let .UnreadEntry(rhsIndex) where lhsIndex == rhsIndex:
            return true
        default:
            return false
        }
    case let .DateEntry(lhsIndex):
        switch rhs {
        case let .DateEntry(rhsIndex) where lhsIndex == rhsIndex:
            return true
        default:
            return false
        }
    case .bottom:
        switch rhs {
        case .bottom:
            return true
        default:
            return false
        }
    }
    
}

func <(lhs: ChatHistoryEntry, rhs: ChatHistoryEntry) -> Bool {
    let lhsIndex = lhs.index
    let rhsIndex = rhs.index
    if lhsIndex == rhsIndex {
        return lhs.stableId.stableIndex < rhs.stableId.stableIndex
    } else {
        return lhsIndex < rhsIndex
    }
}


func messageEntries(_ messagesEntries: [MessageHistoryEntry], maxReadIndex:MessageIndex? = nil, includeHoles: Bool = true, dayGrouping: Bool = false, includeBottom:Bool = false, timeDifference: TimeInterval = 0, adminIds:[PeerId] = []) -> [ChatHistoryEntry] {
    var entries: [ChatHistoryEntry] = []
 
    
    var i:Int = 0
    for entry in messagesEntries {
        switch entry {
        case let .HoleEntry(hole, _):
            if includeHoles {
                entries.append(.HoleEntry(hole))
            }
        case let .MessageEntry(message,read, location, _):
            
            var disableEntry = false
            if let action = message.media.first as? TelegramMediaAction {
                switch action.action {
                case .historyCleared:
                    disableEntry = true
                default:
                    break
                }
            }
            
            if disableEntry {
                break
            }
            
            var prev:MessageHistoryEntry? = nil
            var next:MessageHistoryEntry? = nil
            
            if i > 0 {
                prev = messagesEntries[i - 1]
            }
            if i < messagesEntries.count - 1 {
                next = messagesEntries[i + 1]
            }
            
            let isAdmin = adminIds.contains(message.author?.id ?? PeerId(0))
            
            var itemType:ChatItemType = .Full(isAdmin: isAdmin)
            var fwdType:ForwardItemType? = nil
            
            
            
            
            if let prev = prev, case let .MessageEntry(prevMessage,_, _, _) = prev {
                
                
                var actionShortAccess: Bool = true
                if let action = prevMessage.media.first as? TelegramMediaAction {
                    switch action.action {
                    case .phoneCall:
                        actionShortAccess = true
                    default:
                        actionShortAccess = false
                    }
                }
                
                if message.author?.id == prevMessage.author?.id, (message.timestamp - prevMessage.timestamp) < simpleDif, actionShortAccess, let peer = message.peers[message.id.peerId] {
                    if let peer = peer as? TelegramChannel, case .broadcast(_) = peer.info {
                        itemType = .Full(isAdmin: isAdmin)
                    } else {
                        var canShort:Bool = true
                        for attr in message.attributes {
                            if !(attr is OutgoingMessageInfoAttribute) && !(attr is TextEntitiesMessageAttribute) && !(attr is EditedMessageAttribute) && !(attr is ForwardSourceInfoAttribute) && !(attr is ViewCountMessageAttribute) && !(attr is ConsumableContentMessageAttribute) && !(attr is NotificationInfoMessageAttribute) && !(attr is ChannelMessageStateVersionAttribute) {
                                canShort = false
                                break
                            }
                        }
                        itemType = !canShort ? .Full(isAdmin: isAdmin) : .Short
                        
                    }
                } else {
                    itemType = .Full(isAdmin: isAdmin)
                }
            } else {
                itemType = .Full(isAdmin: isAdmin)
            }
            
            
            if message.forwardInfo != nil {
                if case .Short = itemType {
                    if let prev = prev, case let .MessageEntry(prevMessage,_, _, _) = prev {
                        if prevMessage.forwardInfo != nil, message.timestamp - prevMessage.timestamp < simpleDif  {
                            fwdType = .Inside
                            if let next = next, case let .MessageEntry(nextMessage,_, _, _) = next  {
                                
                                if message.author?.id != nextMessage.author?.id || nextMessage.timestamp - message.timestamp > simpleDif || nextMessage.forwardInfo == nil {
                                    fwdType = .Bottom
                                }
                                
                            } else {
                                fwdType = .Bottom
                            }
                            
                        } else {
                            fwdType = .ShortHeader
                        }
                    }
                } else {
                    fwdType = .ShortHeader
                }
            }
            
            if let forwardType = fwdType, forwardType == .ShortHeader || forwardType == .FullHeader  {
                itemType = .Full(isAdmin: isAdmin)
                if forwardType == .ShortHeader {
                    if let next = next, case let .MessageEntry(nextMessage,_, _, _) = next  {
                        if nextMessage.forwardInfo != nil && (message.author?.id == nextMessage.author?.id || nextMessage.timestamp - message.timestamp < simpleDif) {
                            fwdType = .FullHeader
                        }
                        
                    }
                }
            }
            
            
            if prev == nil && dayGrouping {
                var time = TimeInterval(message.timestamp)
                time -= timeDifference
                let dateId = chatDateId(for: Int32(time))
                let index = MessageIndex(id: message.id, timestamp: Int32(dateId))
                entries.append(.DateEntry(index))
            }

            entries.append(.MessageEntry(message,read,itemType,fwdType, location))

            if let next = next, case let .MessageEntry(nextMessage,_, _, _) = next, dayGrouping {
                let dateId = chatDateId(for: message.timestamp - Int32(timeDifference))
                let nextDateId = chatDateId(for: nextMessage.timestamp - Int32(timeDifference))
                if dateId != nextDateId {
                    let index = MessageIndex(id: MessageId(peerId: message.id.peerId, namespace: message.id.namespace, id: INT_MAX), timestamp: Int32(nextDateId))
                    entries.append(.DateEntry(index))
                }
            }
      
        }
        
        i += 1
    }
    
    
    var hasUnread = false
    if let maxReadIndex = maxReadIndex {
        entries.append(.UnreadEntry(maxReadIndex))
        hasUnread = true
    }
    
    
    if includeBottom {
        entries.append(.bottom)
    }
    
    
    
    var sorted = entries.sorted()

    if hasUnread, sorted.count >= 2 {
        if  case .UnreadEntry = sorted[sorted.count - 2] {
            sorted.remove(at: sorted.count - 2)
        }
    }
    
    return sorted
}

