//
//  HLSVideoController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TGUIKit
import TelegramCore
import Postbox

private final class Arguments {
    let context: AccountContext
    init(context: AccountContext) {
        self.context = context
    }
}

private struct State : Equatable {
    var message: EngineMessage
    var quality: UniversalVideoContentVideoQuality = .auto
}

extension UniversalVideoContentVideoQuality {
    var value: Int? {
        switch self {
        case .auto:
            return nil
        case let .quality(value):
            return value
        }
    }
}

@available(macOS 14.0, *)
private final class RowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let file: TelegramMediaFile
    fileprivate let content: HLSVideoContent
    fileprivate let quality: UniversalVideoContentVideoQuality
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message, quality: UniversalVideoContentVideoQuality) {
        self.context = context
        self.message = message
        self.quality = quality
        self.file = message.media.first! as! TelegramMediaFile
        self.content = .init(id: .message(message.id, message.stableId, file.fileId), userLocation: .other, fileReference: FileMediaReference.message(message: MessageReference(message), media: file))
        
        let height = file.dimensions!.size.aspectFitted(initialSize).height

        super.init(initialSize, height: height, stableId: stableId)
    }
    
    
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}
@available(macOS 14.0, *)
private final class RowView : GeneralRowView {
    private var videoPlayer: (NSView & UniversalVideoContentView)?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? RowItem else {
            return
        }
        
        if self.videoPlayer == nil {
            let playerView = item.content.makeContentView(accountId: item.context.account.id, postbox: item.context.account.postbox)
            self.videoPlayer = playerView
            addSubview(playerView)
            playerView.play()
            
        }
        
        self.videoPlayer?.setVideoQuality(item.quality)
        needsLayout = true
    }
    override func layout() {
        super.layout()
        videoPlayer?.frame = bounds
    }
}


private final class WebviewRowItem : GeneralRowItem {
    fileprivate let context: AccountContext
    fileprivate let message: Message
    fileprivate let file: TelegramMediaFile
    fileprivate let quality: UniversalVideoContentVideoQuality
    fileprivate let source: HLSServerSource
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, message: Message, quality: UniversalVideoContentVideoQuality) {
        self.context = context
        self.message = message
        self.quality = quality
        self.file = message.media.first! as! TelegramMediaFile
        
        let height = file.dimensions!.size.aspectFitted(initialSize).height
        
        let fileReference = FileMediaReference.message(message: .init(message), media: file)
        
        var qualityFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in file.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        let _ = size
                        if let videoCodec, isVideoCodecSupported(videoCodec: videoCodec) {
                            qualityFiles[Int(size.height)] = fileReference.withMedia(alternativeFile)
                        }
                    }
                }
            }
        }
        var playlistFiles: [Int: FileMediaReference] = [:]
        for alternativeRepresentation in file.alternativeRepresentations {
            if let alternativeFile = alternativeRepresentation as? TelegramMediaFile {
                if alternativeFile.mimeType == "application/x-mpegurl" {
                    if let fileName = alternativeFile.fileName {
                        if fileName.hasPrefix("mtproto:") {
                            let fileIdString = String(fileName[fileName.index(fileName.startIndex, offsetBy: "mtproto:".count)...])
                            if let fileId = Int64(fileIdString) {
                                for (quality, file) in qualityFiles {
                                    if file.media.fileId.id == fileId {
                                        playlistFiles[quality] = fileReference.withMedia(alternativeFile)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        source = HLSServerSource(id: UUID(), postbox: context.account.postbox, userLocation: .other, playlistFiles: playlistFiles, qualityFiles: qualityFiles)
        
        super.init(initialSize, height: height, stableId: stableId)
    }
    
    
    override func viewClass() -> AnyClass {
        return WebviewRowView.self
    }
}
private final class WebviewRowView : GeneralRowView {
    private var videoPlayer: WebviewHLSView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? WebviewRowItem else {
            return
        }
        
        if videoPlayer == nil {
            let player = WebviewHLSView(frame: self.bounds, source: item.source)
            addSubview(player)
            self.videoPlayer = player
        }
        
        videoPlayer?.updateVideoQuality(to: item.quality.value)
        
        needsLayout = true
    }
    override func layout() {
        super.layout()
        videoPlayer?.frame = bounds
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    

    if #available(macOS 14.0, *) {
        entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("id"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
            return RowItem(initialSize, stableId: stableId, context: arguments.context, message: state.message._asMessage(), quality: state.quality)
        }))
    }
    
    
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: .init("id2"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return WebviewRowItem(initialSize, stableId: stableId, context: arguments.context, message: state.message._asMessage(), quality: state.quality)
    }))
    
    
  
    return entries
}

func HLSVideoController(context: AccountContext, message: Message) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(message: .init(message))
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->ViewController?)? = nil
    
    var window:Window {
        get {
            return bestWindow(context, getController?())
        }
    }

    let arguments = Arguments(context: context)
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Video")
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    let modalController = InputDataModalController(controller, modalInteractions: nil)
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    controller.rightModalHeader = ModalHeaderData(image: theme.icons.chatActions, contextMenu: {
        
        var items: [ContextMenuItem] = []
        
        
        var quality: [UniversalVideoContentVideoQuality] = [.auto]
        
        if let file = message.file  {
            for alternativeFile in file.alternativeRepresentations.compactMap({ $0 as? TelegramMediaFile }) {
                for attribute in alternativeFile.attributes {
                    if case let .Video(_, size, _, _, _, videoCodec) = attribute {
                        if let videoCodec, isVideoCodecSupported(videoCodec: videoCodec) {
                            quality.append(.quality(Int(size.height)))
                        }
                    }
                }
            }
        }
        
        for quality in quality {
            let title: String
            switch quality {
            case .auto:
                title = "Auto"
            case let .quality(height):
                title = "\(height)p"
            }
            items.append(ContextMenuItem(title, handler: {
                updateState { current in
                    var current = current
                    current.quality = quality
                    return current
                }
            }, state: quality == stateValue.with { $0.quality} ? .on : nil))
        }
        
        return items
        
    })
    
    
    return modalController
}



