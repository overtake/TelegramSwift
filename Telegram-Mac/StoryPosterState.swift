//
//  StoryPosterState.swift
//  Telegram
//
//  Created by Mike Renoir on 22.11.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Foundation
import SwiftSignalKit
import TelegramCore
import InAppSettings

public struct StoryPosterResultPrivacy: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case sendAsPeerId
        case privacyEveryone
        case privacyContacts
        case privacyFriends
        case privacyNobody
        case selectedPrivacy
        case timeout
        case disableForwarding
        case archive
    }
    
    public var sendAsPeerId: EnginePeer.Id?
    public var privacyEveryone: EngineStoryPrivacy
    public var privacyContacts: EngineStoryPrivacy
    public var privacyFriends: EngineStoryPrivacy
    public var privacyNobody: EngineStoryPrivacy

    public var selectedPrivacy: EngineStoryPrivacy.Base
    
    public var isForwardingDisabled: Bool
    public var pin: Bool
    
    public init(
        sendAsPeerId: EnginePeer.Id?,
        privacyEveryone: EngineStoryPrivacy,
        privacyContacts: EngineStoryPrivacy,
        privacyFriends: EngineStoryPrivacy,
        privacyNobody: EngineStoryPrivacy,
        selectedPrivacy: EngineStoryPrivacy.Base,
        isForwardingDisabled: Bool,
        pin: Bool
    ) {
        self.sendAsPeerId = sendAsPeerId
        self.privacyEveryone = privacyEveryone
        self.privacyContacts = privacyContacts
        self.privacyFriends = privacyFriends
        self.privacyNobody = privacyNobody
        self.selectedPrivacy = selectedPrivacy
        self.isForwardingDisabled = isForwardingDisabled
        self.pin = pin
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.sendAsPeerId = try container.decodeIfPresent(Int64.self, forKey: .sendAsPeerId).flatMap { EnginePeer.Id($0) }
        self.privacyEveryone = try container.decode(EngineStoryPrivacy.self, forKey: .privacyEveryone)
        self.privacyContacts = try container.decode(EngineStoryPrivacy.self, forKey: .privacyContacts)
        self.privacyFriends = try container.decode(EngineStoryPrivacy.self, forKey: .privacyFriends)
        self.privacyNobody = try container.decode(EngineStoryPrivacy.self, forKey: .privacyNobody)
        self.selectedPrivacy = try container.decode(EngineStoryPrivacy.Base.self, forKey: .selectedPrivacy)

        self.isForwardingDisabled = try container.decodeIfPresent(Bool.self, forKey: .disableForwarding) ?? false
        self.pin = try container.decode(Bool.self, forKey: .archive)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
    
        try container.encodeIfPresent(self.sendAsPeerId?.toInt64(), forKey: .sendAsPeerId)
        try container.encode(self.privacyEveryone, forKey: .privacyEveryone)
        try container.encode(self.privacyContacts, forKey: .privacyContacts)
        try container.encode(self.privacyFriends, forKey: .privacyFriends)
        try container.encode(self.privacyNobody, forKey: .privacyNobody)
        try container.encode(self.selectedPrivacy, forKey: .selectedPrivacy)

        try container.encode(self.isForwardingDisabled, forKey: .disableForwarding)
        try container.encode(self.pin, forKey: .archive)
    }
}




public final class StoryPosterState: Codable {
    private enum CodingKeys: String, CodingKey {
        case privacy
    }
    
    public let privacy: StoryPosterResultPrivacy?
    
    public init(privacy: StoryPosterResultPrivacy?) {
        self.privacy = privacy
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let data = try container.decodeIfPresent(Data.self, forKey: .privacy), let privacy = try? JSONDecoder().decode(StoryPosterResultPrivacy.self, from: data) {
            self.privacy = privacy
        } else {
            self.privacy = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        if let privacy = self.privacy {
            if let data = try? JSONEncoder().encode(privacy) {
                try container.encode(data, forKey: .privacy)
            } else {
                try container.encodeNil(forKey: .privacy)
            }
        } else {
            try container.encodeNil(forKey: .privacy)
        }
    }
    
    public func withUpdatedPrivacy(_ privacy: StoryPosterResultPrivacy) -> StoryPosterState {
        return StoryPosterState(privacy: privacy)
    }
}

func storyPosterState(engine: TelegramEngine) -> Signal<StoryPosterState?, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storyPostState, id: key))
    |> map { entry -> StoryPosterState? in
        return entry?.get(StoryPosterState.self)
    }
}

func updateStoryPosterStateInteractively(engine: TelegramEngine, _ f: @escaping (StoryPosterState?) -> StoryPosterState?) -> Signal<Never, NoError> {
    let key = EngineDataBuffer(length: 4)
    key.setInt32(0, value: 0)
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.storyPostState, id: key))
    |> map { entry -> StoryPosterState? in
        return entry?.get(StoryPosterState.self)
    }
    |> mapToSignal { state -> Signal<Never, NoError> in
        if let updatedState = f(state) {
            return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.storyPostState, id: key, item: updatedState)
        } else {
            return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.storyPostState, id: key)
        }
    }
}

