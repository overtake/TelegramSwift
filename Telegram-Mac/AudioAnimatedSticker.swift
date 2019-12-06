//
//  AudioAnimatedSticker.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06.12.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

func addAudioToSticker() {
    filePanel(with: ["tgs", "mp3"], allowMultiple: true, canChooseDirectories: false, for: mainWindow, completion: { files in
        if let files = files {
            let stickerPath = files.first(where: { $0.nsstring.pathExtension == "tgs" })
            let audioPath = files.first(where: { $0.nsstring.pathExtension == "mp3" })

            if let stickerPath = stickerPath, let audioPath = audioPath {
                
            }
            
        }
    })
}
