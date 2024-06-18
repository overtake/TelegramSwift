//
//  CheckAppStoreUpdate.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 17.06.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation



func fetchAppStoreVersion(completion: @escaping (String?) -> Void) {
    let appID = Bundle.main.infoDictionary!["CFBundleIdentifier"] as! String
    let urlString = "https://itunes.apple.com/lookup?bundleId=\(appID)"
    
    guard let url = URL(string: urlString) else {
        completion(nil)
        return
    }
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
        guard let data = data, error == nil else {
            completion(nil)
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let appStoreVersion = results.first?["version"] as? String {
                completion(appStoreVersion)
            } else {
                completion(nil)
            }
        } catch {
            completion(nil)
        }
    }
    
    task.resume()
}

func getCurrentAppVersion() -> String? {
    if let infoDictionary = Bundle.main.infoDictionary,
       let version = infoDictionary["CFBundleShortVersionString"] as? String {
        return version
    }
    return nil
}

func checkForAppstoreUpdate(completion:@escaping(Bool)->Void) {
    fetchAppStoreVersion { appStoreVersion in
        guard let appStoreVersion = appStoreVersion else {
            print("Could not fetch App Store version")
            return
        }
        DispatchQueue.main.async {
            if let currentVersion = getCurrentAppVersion(), currentVersion < appStoreVersion {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
}
