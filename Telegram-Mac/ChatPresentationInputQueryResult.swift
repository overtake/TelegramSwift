//
//  ChatPresentationInputQueryResult.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02.11.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TelegramCore

import Postbox

enum ChatPresentationInputQueryResult: Equatable {
    case hashtags([String])
    case mentions([Peer])
    case commands([PeerCommand])
    case stickers([FoundStickerItem])
    case emoji([String], Bool)
    case searchMessages(([Message], SearchMessagesState?, (SearchMessagesState?)-> Void), [Peer], String)
    case contextRequestResult(Peer, ChatContextResultCollection?)
    
    static func ==(lhs: ChatPresentationInputQueryResult, rhs: ChatPresentationInputQueryResult) -> Bool {
        switch lhs {
        case let .hashtags(lhsResults):
            if case let .hashtags(rhsResults) = rhs {
                return lhsResults == rhsResults
            } else {
                return false
            }
        case let .stickers(lhsResults):
            if case let .stickers(rhsResults) = rhs {
                return lhsResults == rhsResults
            } else {
                return false
            }
        case let .emoji(lhsResults, lhsFirstWord):
            if case let .emoji(rhsResults, rhsFirstWord) = rhs {
                return lhsResults == rhsResults && lhsFirstWord == rhsFirstWord
            } else {
                return false
            }
        case let .searchMessages(lhsMessages, lhsPeers, lhsSearchText):
            if case let .searchMessages(rhsMessages, rhsPeers, rhsSearchText) = rhs {
                if lhsPeers.count == rhsPeers.count {
                    for i in 0 ..< rhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                } else {
                    return false
                }
                if lhsMessages.0.count == rhsMessages.0.count {
                    for i in 0 ..< lhsMessages.0.count {
                        if !isEqualMessages(lhsMessages.0[i], rhsMessages.0[i]) {
                            return false
                        }
                    }
                    return lhsSearchText == rhsSearchText && lhsMessages.1 == rhsMessages.1
                } else {
                    return false
                }
            } else {
                return false
            }
        case let .mentions(lhsPeers):
            if case let .mentions(rhsPeers) = rhs {
                if lhsPeers.count != rhsPeers.count {
                    return false
                } else {
                    for i in 0 ..< lhsPeers.count {
                        if !lhsPeers[i].isEqual(rhsPeers[i]) {
                            return false
                        }
                    }
                    return true
                }
            } else {
                return false
            }
        case let .commands(lhsCommands):
            if case let .commands(rhsCommands) = rhs {
                if lhsCommands != rhsCommands {
                    return false
                }
                return true
            } else {
                return false
            }
        case let .contextRequestResult(lhsPeer, lhsCollection):
            if case let .contextRequestResult(rhsPeer, rhsCollection) = rhs {
                if !lhsPeer.isEqual(rhsPeer) {
                    return false
                }
                if lhsCollection != rhsCollection {
                    return false
                }
                return true
            } else {
                return false
            }
        }
    }
}
