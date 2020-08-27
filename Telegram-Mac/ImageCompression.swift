
//
//  ImageCompression.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 02/01/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import Mozjpeg

private let tinyThumbnailHeaderPattern = Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDACgcHiMeGSgjISMtKygwPGRBPDc3PHtYXUlkkYCZlo+AjIqgtObDoKrarYqMyP/L2u71////m8H////6/+b9//j/2wBDASstLTw1PHZBQXb4pYyl+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj4+Pj/wAARCAAAAAADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwA=")
private let tinyThumbnailFooterPattern = Data(base64Encoded: "/9k=")

public func decodeTinyThumbnail(data: Data) -> Data? {
    if data.count < 3 {
        return nil
    }
    guard let tinyThumbnailHeaderPattern = tinyThumbnailHeaderPattern, let tinyThumbnailFooterPattern = tinyThumbnailFooterPattern else {
        return nil
    }
    var version: UInt8 = 0
    data.copyBytes(to: &version, count: 1)
    if version != 1 {
        return nil
    }
    var width: UInt8 = 0
    var height: UInt8 = 0
    data.copyBytes(to: &width, from: 1 ..< 2)
    data.copyBytes(to: &height, from: 2 ..< 3)
    
    var resultData = Data()
    resultData.append(tinyThumbnailHeaderPattern)
    resultData.append(data.subdata(in: 3 ..< data.count))
    resultData.append(tinyThumbnailFooterPattern)
    resultData.withUnsafeMutableBytes({ (resultBytes: UnsafeMutablePointer<UInt8>) -> Void in
        resultBytes[164] = width
        resultBytes[166] = height
    })
    return resultData
}




public func extractImageExtraScans(_ data: Data) -> [Int] {
    return extractJPEGDataScans(data).map { item in
        return item.intValue
    }
}

public func compressImageToJPEG(_ cgImage: CGImage, quality: Float) -> Data? {
    if let result = compressJPEGData(cgImage) {
        return result
    }
    
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
        return nil
    }
    
    let options = NSMutableDictionary()
    options.setObject(quality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
    
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    if data.length == 0 {
        return nil
    }
    
    return data as Data
}



public func compressImageMiniThumbnail(_ image: CGImage) -> Data? {
    return compressMiniThumbnail(image)
}
