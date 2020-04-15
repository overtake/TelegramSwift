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
    
    if let dateString = try? String(contentsOf: URL(fileURLWithPath: url)) {
        let components = dateString.components(separatedBy: " ")
        if components.count == 2 {
            let initedDate = Int32(components[0]) ?? 0
            let lastSavedDate = Int32(components[1]) ?? 0
            return lastSavedDate - initedDate < 10
        } else {
            return true
        }
    }
    
    return FileManager.default.fileExists(atPath: url)
}

func crashIntermediateDate(_ folder: String) {
    let url = folder + "/" + "crashhandler"
    if let dateString = try? String(contentsOf: URL(fileURLWithPath: url)) {
        let time = "\(Int32(Date().timeIntervalSince1970))"
        var components = dateString.components(separatedBy: " ")
        if components.count == 2 {
            components[1] = time
        } else if components.count == 1 {
            components.append(time)
        }
        try? FileManager.default.removeItem(atPath: url)
        FileManager.default.createFile(atPath: url, contents: components.joined(separator: " ").data(using: .utf8), attributes: nil)

    } else {
        let time = "\(Int32(Date().timeIntervalSince1970))".data(using: .utf8)
        try? FileManager.default.removeItem(atPath: url)
        FileManager.default.createFile(atPath: url, contents: time, attributes: nil)
    }
}

func deinitCrashHandler(_ folder: String) {
    let url = folder + "/" + "crashhandler"
    try? FileManager.default.removeItem(atPath: url)
}
