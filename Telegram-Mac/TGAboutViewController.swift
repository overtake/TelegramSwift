//
//  TGAboutViewController.swift
//  Telegram
//
//  Created by s0ph0s on 2019-04-06.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa

class TGAboutViewController: NSViewController {

    @IBOutlet weak var appIconImageView: NSImageView!
    @IBOutlet weak var versionLabel: NSTextField!
    let versionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1"
    let buildString = Bundle.main.infoDictionary?["CFBundleVersion"] ?? "0"
    #if STABLE
    let releaseChannel = "Stable"
    #elseif APP_STORE
    let releaseChannel = "Mac App Store"
    #else
    let releaseChannel = "Beta"
    #endif
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        versionLabel.stringValue = "Version \(versionString) (\(buildString))\n\(releaseChannel)"
        appIconImageView.image = NSImage(named: "AppIcon")
    }
    
    @IBAction func copyButtonClicked(_ sender: Any) {
        copyToClipboard("\(versionString) (\(buildString)) \(releaseChannel)")
    }
}
