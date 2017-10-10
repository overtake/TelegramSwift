//
//  InterfaceObserver.swift
//  Telegram-Mac
//
//  Created by keepcoder on 27/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

protocol Notifable : class {
    
    func notify(with value:Any, oldValue:Any, animated:Bool) -> Void
    
    func isEqual(to other:Notifable) -> Bool

}

private class WeakNotifable {
    
    public private(set) weak var value:Notifable?
    
    public init(value:Notifable?) {
        self.value = value
    }
}

class InterfaceObserver : NSObject  {
    private var observers:[WeakNotifable] = []

    public func add(observer:Notifable) {
        for other in observers {
            if let value = other.value {
                if value.isEqual(to: observer) {
                    return
                }
            }
            
        }
        observers.append(WeakNotifable(value: observer))
    }
    
    public func remove(observer:Notifable) {
        var copy:[WeakNotifable] = []
        for observer in observers {
            copy.append(observer)
        }
        
        for i in stride(from: copy.count - 1, to: 0, by: -1) {
            if let value = copy[i].value {
                if value.isEqual(to: observer)  {
                    observers.remove(at: i)
                }
            }
           
        }
    }
    
    func notifyObservers(value:Any, oldValue:Any, animated:Bool) {
        for observer in observers {
            if let observer = observer.value {
                observer.notify(with: value, oldValue: oldValue, animated: animated)
            }
        }
    }
    
}
