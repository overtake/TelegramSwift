//
//  AppDelegate.swift
//  OHHTTPStubsDemo
//
//  Created by Olivier Halligon on 18/04/2015.
//  Copyright (c) 2015 AliSoftware. All rights reserved.
//

import UIKit

#if swift(>=4)
#else
extension UIApplication {
    typealias LaunchOptionsKey = UIApplicationLaunchOptionsKey
}
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
}

