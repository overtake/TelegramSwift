//
//  WindowSaver.swift
//  TGUIKit
//
//  Created by keepcoder on 07/12/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
public class WindowSaver : NSObject, NSCoding {
    var rect:NSRect
    let requiredName:String
    var isFullScreen: Bool
    private let disposable:MetaDisposable = MetaDisposable()
    init(name: String, rect:NSRect, isFullScreen: Bool) {
        self.rect = rect
        self.requiredName = name
        self.isFullScreen = isFullScreen
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.rect = aDecoder.decodeRect(forKey: "rect")
        self.requiredName = aDecoder.decodeObject(forKey: "name") as! String
        self.isFullScreen = aDecoder.decodeBool(forKey: "isFullScreen")
    }
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(rect, forKey: "rect")
        aCoder.encode(self.requiredName, forKey: "name")
        aCoder.encode(self.isFullScreen, forKey: "isFullScreen")
    }
    
    static public func find(for window:Window) -> WindowSaver {
        let user = UserDefaults.standard
        let data = user.object(forKey: "window_saver_".appending(window.name))
        var archiver: WindowSaver?
        if let data = data as? Data {
            archiver = NSKeyedUnarchiver.unarchiveObject(with: data) as? WindowSaver
        }
        if archiver == nil {
            archiver = WindowSaver(name: window.name, rect: window.frame, isFullScreen: window.isFullScreen)
        }
        return archiver!
    }
    
    public func save() {
        let single:Signal<Void,Void> = .single(Void()) |> delay(0.5, queue: Queue.mainQueue())
        
        disposable.set(single.start(next: { [weak self] in
            if let strongSelf = self {
                let user = UserDefaults.standard
                let data = NSKeyedArchiver.archivedData(withRootObject: strongSelf)
                user.set(data, forKey: "window_saver_".appending(strongSelf.requiredName))
                user.synchronize()
            }
        }))
    }
    
    deinit {
        disposable.dispose()
    }
}
