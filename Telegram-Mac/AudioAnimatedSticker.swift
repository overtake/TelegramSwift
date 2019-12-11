//
//  AudioAnimatedSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit


private struct SelectFrameState : Equatable {
    let frame: Int32
    init(frame: Int32) {
        self.frame = frame
    }
    func withUpdatedFrame(_ frame: Int32) -> SelectFrameState {
        return SelectFrameState(frame: frame)
    }
}

private let _id_input = InputDataIdentifier("frame")

private func selectFrameEntries(_ state: SelectFrameState) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(String(state.frame)), error: nil, identifier: _id_input, mode: .plain, data: InputDataRowData(viewType: .singleItem), placeholder: nil, inputPlaceholder: "Start frame", filter: { $0 }, limit: 3))
    index += 1
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

private func selectFrameController(context: AccountContext, select:@escaping(Int32)->Void) -> InputDataModalController {
    
    
    let initialState = SelectFrameState(frame: 1)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((SelectFrameState) -> SelectFrameState) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    let signal = statePromise.get() |> map { state in
        return InputDataSignalValue(entries: selectFrameEntries(state))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "Sound Effect Frame")
    
    var close: (()->Void)? = nil
    
    let modalInteractions = ModalInteractions(acceptTitle: "Save", accept: {
        select(stateValue.with { $0.frame })
        close?()
    }, height: 50, singleButton: true)
    
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
    })
    
    controller.updateDatas = { data in
        updateState { state in
            if let rawFrame = data[_id_input]?.stringValue, let frame = Int32(rawFrame) {
                return state.withUpdatedFrame(frame)
            }
            return state
        }
        return .none
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, closeHandler: { f in f() }, size: NSMakeSize(300, 300))
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    return modalController
    
}

func addAudioToSticker(context: AccountContext) {
    filePanel(with: ["tgs", "mp3"], allowMultiple: true, canChooseDirectories: false, for: mainWindow, completion: { files in
        if let files = files {
            let stickerPath = files.first(where: { $0.nsstring.pathExtension == "tgs" })
            let audioPath = files.first(where: { $0.nsstring.pathExtension == "mp3" })

            if let stickerPath = stickerPath, let audioPath = audioPath {
                let data = try! Data(contentsOf: URL.init(fileURLWithPath: stickerPath))
                let uncompressed = TGGUnzipData(data, 8 * 1024 * 1024)!
                
                let string = NSMutableString(data: uncompressed, encoding: String.Encoding.utf8.rawValue)!
                
                let mp3Data = try! Data(contentsOf: URL(fileURLWithPath: audioPath))
                
                showModal(with: selectFrameController(context: context, select: { frame in
                    let effectString = "\"soundEffect\":{\"triggerOn\":\(frame),\"data\":\"\(mp3Data.base64EncodedString())\"}"
                    
                    let range = string.range(of: "\"tgs\":1,")
                    if range.location != NSNotFound {
                        string.insert(effectString + ",", at: range.max)
                    }
                    
                    let updatedData = string.data(using: String.Encoding.utf8.rawValue)!
                    
                    let zipData = TGGZipData(updatedData, -1)!
                    
                    let output = NSTemporaryDirectory() + "\(arc4random()).tgs"
                    
                    try! zipData.write(to: URL(fileURLWithPath: output))
                    
                    
                    
                    if let controller = context.sharedContext.bindings.rootNavigation().controller as? ChatController {
                        showModal(with: PreviewSenderController(urls: [URL(fileURLWithPath: output)], chatInteraction: controller.chatInteraction), for: context.window)
                    }
                }), for: context.window)
            }
            
        }
    })
}
