//
//  SyncCoreExtension.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 01.11.2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import SyncCore

extension PixelDimensions {
    var size: CGSize {
        return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
    }
    init(_ size: CGSize) {
        self.init(width: Int32(size.width), height: Int32(size.height))
    }
    init(_ width: Int32, _ height: Int32) {
        self.init(width: width, height: height)
    }
}
extension CGSize {
    var pixel: PixelDimensions {
        return PixelDimensions(self)
    }
}
