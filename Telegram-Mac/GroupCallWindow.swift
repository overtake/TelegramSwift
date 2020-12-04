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

private func generatePeerControl(_ icon: CGImage, background: NSColor) -> CGImage {
    return generateImage(NSMakeSize(28, 28), contextGenerator: { size, ctx in
        let rect: NSRect = .init(origin: .zero, size: size)
        ctx.clear(rect)
        
        ctx.round(size, 4)
        ctx.setFillColor(background.cgColor)
        ctx.fill(rect)
        
        ctx.draw(icon, in: rect.focus(icon.backingSize))
    })!
}

struct GroupCallTheme {
    static let membersColor = NSColor(hexString: "#333333")!
    static let windowBackground = NSColor(hexString: "#212121")!
    static let grayStatusColor = NSColor(srgbRed: 133 / 255, green: 133 / 255, blue: 133 / 255, alpha: 1)
    static let blueStatusColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let greenStatusColor = NSColor(hexString: "#34C759")!
    static let memberSeparatorColor = NSColor(srgbRed: 58 / 255, green: 58 / 255, blue: 58 / 255, alpha: 1)
    static let speakActiveColor = NSColor(hexString: "#34C759")!
    static let speakInactiveColor = NSColor(srgbRed: 38 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
    static let speakLockedColor = NSColor(hexString: "#FF5257")!
    static let speakDisabledColor = NSColor(hexString: "#333333")!
    static let titleColor = NSColor.white
    static let declineColor = NSColor(hexString: "#FF3B30")!.withAlphaComponent(0.3)
    static let settingsColor = NSColor(hexString: "#333333")!
    
    static let settingsIcon = NSImage(named: "Icon_GroupCall_Settings")!.precomposed(.white)
    static let declineIcon = NSImage(named: "Icon_GroupCall_Decline")!.precomposed(.white)
    static let inviteIcon = NSImage(named: "Icon_GroupCall_Invite")!.precomposed(GroupCallTheme.blueStatusColor)
    static let invitedIcon = NSImage(named: "Icon_GroupCall_Invited")!.precomposed(GroupCallTheme.grayStatusColor)

    static let small_speaking = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: .clear)
    static let small_unmuted = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    static let small_muted = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    static let small_muted_locked = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: .clear)
    
    static let small_speaking_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_unmuted_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_muted_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    static let small_muted_locked_active = generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))

    
    static let big_unmuted = NSImage(named: "Icon_GroupCall_Big_Unmuted")!.precomposed(.white)
    static let big_muted = NSImage(named: "Icon_GroupCall_Big_Muted")!.precomposed(GroupCallTheme.speakLockedColor)

    

}

final class GroupCallWindow : Window {
    init() {
        let size = NSMakeSize(480, 640)
        var rect: NSRect = .init(origin: .init(x: 100, y: 100), size: size)
        if let screen = NSScreen.main {
            let x = floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2)
            let y = floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2)
            rect = .init(origin: .init(x: x, y: y), size: size)
        }

        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless, .miniaturizable, .closable, .titled], backing: .buffered, defer: true)
        self.minSize = NSMakeSize(400, 580)
        self.isOpaque = true
        self.backgroundColor = .black
        

        self.titlebarAppearsTransparent = true
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
        
        
    }
    
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        var point: NSPoint = NSMakePoint(20, 0)
        self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
        point.x += 20
        self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
    }
    
    deinit {
        
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
        self.navigation.alwaysAnimate = true
        self.navigation.cleanupAfterDeinit = false
        self.navigation.viewWillAppear(false)
        self.window.contentView = self.navigation.view
        self.navigation.viewDidAppear(false)
        removeDisposable.set((self.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.readyClose()
            }
        }))

        self.window.closeInterceptor = { [weak self] in
            self?.readyClose()
            return true
        }
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
        self.navigation.viewWillDisappear(false)
        let window: Window = self.window
        if window.isVisible {
            NSAnimationContext.runAnimationGroup({ _ in
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
        self.navigation.viewDidDisappear(false)
    }
    
    func close() {
        _ = call.sharedContext.endGroupCall(terminate: false).start()
        self.readyClose()
    }
    func leave() {
        _ = call.sharedContext.endGroupCall(terminate: false).start()
    }
    
    private func _readyPresent() {
        window.alphaValue = 1
        self.window.makeKeyAndOrderFront(nil)
        self.window.orderFrontRegardless()
    }
    
}


func applyGroupCallResult(_ sharedContext: SharedAccountContext, _ result:GroupCallContext) {
    assertOnMainThread()
    result.call.sharedContext.showGroupCall(with: result)
    result.present()
}
