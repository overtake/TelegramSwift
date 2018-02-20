//
//  CrashHandler.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 07/02/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa

func isCrashedLastTime(_ folder: String) -> Bool {
    let url = folder + "/" + "crashhandler"
    
    if let dateString = try? String(contentsOf: URL(fileURLWithPath: url)), let time = Int32(dateString) {
        return time + 10 > Int32(Date().timeIntervalSince1970)
    }
    
    return FileManager.default.fileExists(atPath: url)
}

func crashIntermediateDate(_ folder: String) {
    let url = folder + "/" + "crashhandler"
    let time = "\(Int32(Date().timeIntervalSince1970))".data(using: .utf8)
    try? FileManager.default.removeItem(atPath: url)
    FileManager.default.createFile(atPath: url, contents: time, attributes: nil)
}

func deinitCrashHandler(_ folder: String) {
    let url = folder + "/" + "crashhandler"
    try? FileManager.default.removeItem(atPath: url)
}
