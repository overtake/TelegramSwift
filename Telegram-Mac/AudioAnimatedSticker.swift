//
//  AudioAnimatedSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

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
                
                let effectString = "\"soundEffect\":{\"triggerOn\":\(90),\"data\":\"\(mp3Data.base64EncodedString())\"}"

                let range = string.range(of: "\"tgs\":1,")
                if range.location != NSNotFound {
                    string.insert(effectString + ",", at: range.max)
                }
                
                let updatedData = string.data(using: String.Encoding.utf8.rawValue)!
                
                let zipData = TGGZipData(updatedData, -1)!
                
                let output = NSTemporaryDirectory() + "\(arc4random()).tgs"
                
                try! zipData.write(to: URL(fileURLWithPath: output))
                
                
                if let controller = context.sharedContext.bindings.rootNavigation().controller as? ChatController {
                    showModal(with: PreviewSenderController.init(urls: [URL(fileURLWithPath: output)], chatInteraction: controller.chatInteraction), for: context.window)
                }
            }
            
        }
    })
}
