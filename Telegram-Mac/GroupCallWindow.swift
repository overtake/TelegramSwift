//
//  GroupCallWindow.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/11/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

struct GroupCallTheme {
    static let membersColor = NSColor(hexString: "#333333")!
    static let windowBackground = NSColor(hexString: "#212121")!
    static let grayStatusColor = NSColor(srgbRed: 133 / 255, green: 133 / 255, blue: 133 / 255, alpha: 1)
    static let blueStatusColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let greenStatusColor = NSColor(srgbRed: 81 / 255, green: 165 / 255, blue: 113 / 255, alpha: 1)
    static let memberSeparatorColor = NSColor(srgbRed: 58 / 255, green: 58 / 255, blue: 58 / 255, alpha: 1)
    static let speakActiveColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let speakInactiveColor = NSColor(hexString: "#333333")!
    static let titleColor = NSColor.white
    static let declineColor = NSColor(hexString: "#FF3B30")!.withAlphaComponent(0.3)
    static let settingsColor = NSColor(hexString: "#333333")!
    
    static let settingsIcon = NSImage(named: "Icon_GroupCall_Settings")!.precomposed(.white)
    static let declineIcon = NSImage(named: "Icon_GroupCall_Decline")!.precomposed(.white)
    static let inviteIcon = NSImage(named: "Icon_GroupCall_Invite")!.precomposed(.white)
    static let invitedIcon = NSImage(named: "Icon_GroupCall_Invited")!.precomposed(.white)
}

final class GroupCallWindow : Window {
    init() {
        super.init(contentRect: NSMakeRect(100, 100, 480, 640), styleMask: [.fullSizeContentView, .borderless, .miniaturizable, .closable, .titled], backing: .buffered, defer: true)
        self.minSize = NSMakeSize(400, 580)
        self.isOpaque = true
        self.backgroundColor = .black
        
        if #available(OSX 10.13, *) {
            let customToolbar = NSToolbar()
            customToolbar.sizeMode = .regular
            self.titleVisibility = .hidden
            self.toolbar = customToolbar
        }
        self.titlebarAppearsTransparent = true
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
    }
    
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}


final class GroupCallContext {
    private let controller: GroupCallUIController
    private let navigation: MajorNavigationController

    let window: GroupCallWindow
    let call: PresentationGroupCall
    let peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager
    private let presentDisposable = MetaDisposable()
    private let removeDisposable = MetaDisposable()
    init(call: PresentationGroupCall, peerMemberContextsManager: PeerChannelMemberCategoriesContextsManager) {
        self.call = call
        self.peerMemberContextsManager = peerMemberContextsManager
        self.window = GroupCallWindow()
        self.controller = GroupCallUIController(.init(call: call, peerMemberContextsManager: peerMemberContextsManager))
        self.navigation = MajorNavigationController(GroupCallUIController.self, controller, self.window)
        self.window.contentView = self.navigation.view
        removeDisposable.set((self.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.readyClose()
            }
        }))
    }
    
    deinit {
        presentDisposable.dispose()
        removeDisposable.dispose()
    }
    
    func present() {
        presentDisposable.set((self.controller.ready.get() |> take(1)).start(completed: { [weak self] in
            self?._readyPresent()
        }))
    }
    
    private func readyClose() {
        let window: Window = self.window
        if window.isVisible {
            window.orderOut(nil)
        }
    }
    
    func leave() {
        _ = self.call.leave().start()
    }
    
    private func _readyPresent() {
        self.window.makeKeyAndOrderFront(nil)
        self.window.orderFrontRegardless()
    }
    
}


func applyGroupCallResult(_ sharedContext: SharedAccountContext, _ result:GroupCallContext) {
    assertOnMainThread()
    result.call.sharedContext.showGroupCall(with: result)
    result.present()
}
