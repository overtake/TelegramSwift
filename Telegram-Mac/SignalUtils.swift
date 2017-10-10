//
//  SignalUtils.swift
//  TelegramMac
//
//  Created by keepcoder on 27/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

func countdown(_ count:Double, delay:Double) -> Signal<Double,Void> {
    return Signal { subscriber in
        var value:Double = count
        subscriber.putNext(value)
        var timer:SwiftSignalKitMac.Timer? = nil
        timer = SwiftSignalKitMac.Timer(timeout: delay, repeat: true, completion: {
            value -= delay
            subscriber.putNext(max(value,0))
            if value <= 0 {
                subscriber.putCompletion()
                timer?.invalidate()
                timer = nil
            }
        }, queue: Queue.mainQueue())
        timer?.start()
        return ActionDisposable(action: {
            timer?.invalidate()
        })
    }
}

public func `repeat`<T, E>(_ delay:Double, onQueue:Queue) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            
           // let disposable:MEtadi = DisposableSet()
            var timer:SwiftSignalKitMac.Timer? = nil

            timer = SwiftSignalKitMac.Timer(timeout: delay, repeat: true, completion: {
                 _ = signal.start(next: { (next) in
                    subscriber.putNext(next)
                })
            }, queue: onQueue)
             
            timer?.start()
            
            
            return ActionDisposable {
                timer?.invalidate()
            }
        }
    }
}



/*
 +(SSignal *)countdownSignal:(int)count delay:(int)delay {
 return  [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
 __block int value = count;
 [subscriber putNext:@(value)];
 STimer *timer = [[STimer alloc] initWithTimeout:delay repeat:true completion:^{
 value -= delay;
 [subscriber putNext:@(MAX(value, 0))];
 if (value <= 0) {
 [subscriber putCompletion];
 }
 } queue:[ASQueue mainQueue]];
 [timer start];
 return [[SBlockDisposable alloc] initWithBlock:^{
 [timer invalidate];
 }];
 }];
 }
 */
