//
//  File.swift
//  
//
//  Created by Mike Renoir on 05.01.2024.
//

import Foundation
import Postbox
import TelegramCore



public extension FileMediaReference {
    var userLocation: MediaResourceUserLocation {
        switch self {
        case let .message(message, _):
            if let peerId = message.id?.peerId {
                return .peer(peerId)
            } else {
                return .other
            }
        default:
            return .other
        }
    }
    var userContentType: MediaResourceUserContentType {
        return .init(file: media)
    }
}

public extension ImageMediaReference {
    var userLocation: MediaResourceUserLocation {
        switch self {
        case let .message(message, _):
            if let peerId = message.id?.peerId {
                return .peer(peerId)
            } else {
                return .other
            }
        default:
            return .other
        }
    }
    var userContentType: MediaResourceUserContentType {
        return .image
    }
}
