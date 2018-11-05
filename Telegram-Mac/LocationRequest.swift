//
//  LocationRequest.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24/08/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import CoreLocation
import SwiftSignalKitMac
import AVKit
enum UserLocationResult : Equatable {
    case success(CLLocation)
}
enum UserLocationError : Equatable {
    case restricted
    case notDetermined
    case denied
    case wifiRequired
    case disabled
}
private let manager: CLLocationManager = CLLocationManager()

private class UserLocationRequest : NSObject, CLLocationManagerDelegate {
    fileprivate let result: ValuePromise<UserLocationResult> = ValuePromise(ignoreRepeated: true)
    fileprivate let error: ValuePromise<UserLocationError> = ValuePromise(ignoreRepeated: true)

    override init() {
        super.init()
        
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        
        manager.delegate = self
        
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .authorizedAlways:
                manager.startUpdatingLocation()
            case .denied:
                error.set(.denied)
            case .restricted:
                error.set(.restricted)
            case .notDetermined:
                manager.startUpdatingLocation()
            }
        } else {
            error.set(.disabled)
        }
    }

    @objc func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied:
            error.set(.denied)
        case .notDetermined:
            manager.startUpdatingLocation()
        case .restricted:
            error.set(.restricted)
        case .authorizedWhenInUse:
             manager.startUpdatingLocation()
        }
    }

    @objc func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        var bp:Int = 0
        bp += 1
        self.error.set(.wifiRequired)
    }

    @objc func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if let location = locations.last {
            manager.stopUpdatingLocation()
            manager.delegate = nil;
            result.set(.success(location))
        }
    }

    deinit {
        var bp:Int = 0
        bp += 1
    }


    func stop() {
        manager.stopUpdatingLocation()
        manager.delegate = nil;
    }
}

func requestUserLocation() -> Signal<UserLocationResult, UserLocationError> {

    return Signal { subscriber -> Disposable in
        let disposable = DisposableSet()
        var manager: UserLocationRequest!
        Queue.mainQueue().async {
            manager = UserLocationRequest()

            disposable.add(manager.result.get().start(next: { result in
                subscriber.putNext(result)
            }))
            disposable.add(manager.error.get().start(next: { result in
                subscriber.putError(result)
            }))
        }
//
        return ActionDisposable {
            disposable.dispose()
            Queue.mainQueue().async {
                manager.stop()
            }
        }
    }
}
