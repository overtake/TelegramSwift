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
import ColorPalette

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
    static var membersColor:NSColor {
        return darkAppearance.colors.background
    }
    static var windowBackground: NSColor {
        return darkAppearance.colors.listBackground
    }
    static var grayStatusColor: NSColor {
        return darkAppearance.colors.grayText
    }
    static var blueStatusColor: NSColor {
        return darkAppearance.colors.accent
    }
    static var greenStatusColor: NSColor {
        return darkAppearance.colors.greenUI
    }
    static var memberSeparatorColor: NSColor {
        darkAppearance.colors.border
    }
    static var speakActiveColor: NSColor {
        darkAppearance.colors.greenUI
    }
    static var speakInactiveColor: NSColor {
        darkAppearance.colors.accent
    }
    static var speakLockedColor: NSColor {
        darkAppearance.colors.redUI
    }
    static var speakDisabledColor: NSColor {
        darkAppearance.colors.grayBackground
    }
    static var titleColor: NSColor {
        return NSColor.white
    }
    static var declineColor: NSColor {
        return darkAppearance.colors.redUI.withAlphaComponent(0.3)
    }
    static var settingsColor: NSColor {
        return darkAppearance.colors.grayBackground
    }
    
    static let purple = NSColor(rgb: 0x3252ef)
    static let pink = NSColor(rgb: 0xef436c)

    
    static var accent: NSColor {
        return speakInactiveColor
    }
    static var secondary: NSColor {
        return grayStatusColor
    }
    
    static var titleSpeakingAnimation: [CGImage] {
        recordVoiceActivityAnimation(GroupCallTheme.greenStatusColor)
    }
    
    static let videoBox_video: CGImage = NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let videoBox_screencast: CGImage = NSImage(named: "Icon_GroupCall_Status_Screencast")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let closeTooltip: CGImage = NSImage(named: "Icon_VoiceChat_Tooltip_Close")!.precomposed(.white)
    static let settingsIcon: CGImage = NSImage(named: "Icon_GroupCall_Settings")!.precomposed(.white)
    static let declineIcon: CGImage = NSImage(named: "Icon_GroupCall_Decline")!.precomposed(.white)
    static let inviteIcon: CGImage = NSImage(named: "Icon_GroupCall_Invite")!.precomposed(.white)
    static let video_back = NSImage(named: "Icon_ChatNavigationBack")!.precomposed(NSColor.white)
    static let video_paused = NSImage(named: "Icon_VoiceChat_PausedVideo")!.precomposed(NSColor.white)
    static let videoBox_muted: CGImage = NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let videoBox_unmuted: CGImage = NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let videoZoomOut: CGImage = NSImage(named: "Icon_GroupCall_Video_ZoomOut")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let videoZoomIn: CGImage = NSImage(named: "Icon_GroupCall_Video_ZoomIn")!.precomposed(NSColor.white.withAlphaComponent(0.8))
    static let video_limit: CGImage = NSImage(named: "Icon_VoiceChat_VideoLimit")!.precomposed(.white)
    static let video_on: CGImage = NSImage(named: "Icon_GroupCall_VideoOn")!.precomposed(.white)
    static let video_off: CGImage = NSImage(named: "Icon_GroupCall_VideoOff")!.precomposed(.white)
    static let pin_video: CGImage = NSImage(named: "Icon_VoiceChat_PinVideo")!.precomposed(.white)
    static let unpin_video: CGImage = NSImage(named: "Icon_VoiceChat_UnpinVideo")!.precomposed(.white)
    static let pin_window: CGImage = NSImage(named: "Icon_VoiceChat_PinWindow")!.precomposed(.white)
    static let unhide_peers: CGImage = NSImage(named: "Icon_VoiceChat_HidePeers")!.precomposed(.white, flipHorizontal: true)

    
    static var video_status_muted_red: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(GroupCallTheme.speakLockedColor)
    }
    static var video_status_muted_accent: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(GroupCallTheme.greenStatusColor)
    }
    static var video_status_muted_gray: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(GroupCallTheme.grayStatusColor)
    }

    static var video_status_unmuted_green: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor)
    }
    static var video_status_unmuted_gray: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var video_status_unmuted_accent: CGImage {
        return NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.accent)
    }
    static var videoBox_muted_locked: CGImage {
        NSImage(named: "Icon_GroupCall_VideoBox_Muted")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var videoBox_unmuted_locked: CGImage {
        NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var videoBox_speaking: CGImage {
        NSImage(named: "Icon_GroupCall_VideoBox_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor.withAlphaComponent(0.8))
    }
    static var invitedIcon: CGImage {
        NSImage(named: "Icon_GroupCall_Invited")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    
    static var small_speaking: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: .clear)
    }
    static var small_unmuted: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    }
    static var small_muted: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: .clear)
    }
    static var small_muted_locked: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: .clear)
    }
    
    static var small_speaking_active: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    }
    static var small_unmuted_active: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    }
    static var small_muted_active: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.grayStatusColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    }
    static var small_muted_locked_active: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_Small_Muted")!.precomposed(GroupCallTheme.speakLockedColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    }

    
    static var small_raised_hand: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_RaiseHand_Small")!.precomposed(GroupCallTheme.customTheme.accentColor), background: .clear)
    }
    static var small_raised_hand_active: CGImage {
        generatePeerControl(NSImage(named: "Icon_GroupCall_RaiseHand_Small")!.precomposed(GroupCallTheme.customTheme.accentColor), background: GroupCallTheme.windowBackground.withAlphaComponent(0.3))
    }
    static var status_video_gray: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var status_video_accent: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.blueStatusColor)
    }
    static var status_video_green: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.greenStatusColor)
    }
    static var status_video_red: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Video")!.precomposed(GroupCallTheme.speakLockedColor)
    }
    static var status_screencast_gray: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Screencast")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var status_screencast_accent: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Screencast")!.precomposed(GroupCallTheme.blueStatusColor)
    }
    static var status_screencast_green: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Screencast")!.precomposed(GroupCallTheme.greenStatusColor)
    }
    static var status_screencast_red: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Screencast")!.precomposed(GroupCallTheme.speakLockedColor)
    }
    static var status_muted: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Muted")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var status_muted_red: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Muted")!.precomposed(GroupCallTheme.speakLockedColor)
    }
    static var status_unmuted_accent: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.blueStatusColor)
    }
    static var status_unmuted_green: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.greenStatusColor)
    }
    static var status_unmuted_gray: CGImage {
        NSImage(named: "Icon_GroupCall_Status_Unmuted")!.precomposed(GroupCallTheme.grayStatusColor)
    }
    static var invite_listener: CGImage {
        NSImage(named: "Icon_VoiceChat_InviteListener")!.precomposed(GroupCallTheme.customTheme.accentColor, flipVertical: true)
    }
    static var invite_speaker: CGImage {
        NSImage(named: "Icon_VoiceChat_InviteSpeaker")!.precomposed(customTheme.accentColor, flipVertical: true)
    }
    static var invite_link: CGImage {
        NSImage(named: "Icon_InviteViaLink")!.precomposed(GroupCallTheme.customTheme.accentColor, flipVertical: true)
    }
    static var unpin_window: CGImage {
        NSImage(named: "Icon_VoiceChat_PinWindow")!.precomposed(GroupCallTheme.customTheme.accentColor)
    }
    static var hide_peers: CGImage {
        NSImage(named: "Icon_VoiceChat_HidePeers")!.precomposed(GroupCallTheme.customTheme.accentColor, flipHorizontal: true)
    }

    static let smallTableWidth: CGFloat = 160
    static let fullScreenThreshold: CGFloat = 500

    static let tileTableWidth: CGFloat = 200
    
    static var minSize:NSSize {
        return NSMakeSize(380, 600)
    }
    static var minFullScreenSize:NSSize {
        return NSMakeSize(380, 380)
    }
    
    private static var switchAppearance: SwitchViewAppearance {
        return SwitchViewAppearance(backgroundColor: GroupCallTheme.membersColor, stateOnColor: GroupCallTheme.blueStatusColor, stateOffColor: GroupCallTheme.grayStatusColor, disabledColor: GroupCallTheme.grayStatusColor.withAlphaComponent(0.5), borderColor: GroupCallTheme.memberSeparatorColor)
    }
    
    static var customTheme: GeneralRowItem.Theme {
        GeneralRowItem.Theme(backgroundColor:                                            GroupCallTheme.membersColor,
                                        grayBackground: GroupCallTheme.windowBackground,
                                        grayForeground: GroupCallTheme.grayStatusColor,
                                        highlightColor: GroupCallTheme.membersColor.withAlphaComponent(0.7),
                                        borderColor: GroupCallTheme.memberSeparatorColor,
                                        accentColor: GroupCallTheme.blueStatusColor,
                                        secondaryColor: GroupCallTheme.grayStatusColor,
                                        textColor: NSColor(rgb: 0xffffff),
                                        grayTextColor: GroupCallTheme.grayStatusColor,
                                        underSelectedColor: NSColor(rgb: 0xffffff),
                                        accentSelectColor: GroupCallTheme.blueStatusColor.darker(),
                                        redColor: GroupCallTheme.speakLockedColor,
                                        indicatorColor: NSColor(rgb: 0xffffff),
                                        appearance: darkPalette.appearance,
                                        switchAppearance: switchAppearance,
                                        unselectedImage: generateChatGroupToggleUnselected(foregroundColor: GroupCallTheme.grayStatusColor.withAlphaComponent(0.6), backgroundColor: NSColor.black.withAlphaComponent(0.01)),
                                        selectedImage: generateChatGroupToggleSelected(foregroundColor: GroupCallTheme.blueStatusColor, backgroundColor: NSColor(rgb: 0xffffff)))
    }
        

}

final class GroupCallWindow : Window {
    
    
    var navigation: NavigationViewController?
    
    init(isStream: Bool) {
        let size = isStream ? GroupCallTheme.minFullScreenSize : GroupCallTheme.minSize
        var rect: NSRect = .init(origin: .init(x: 100, y: 100), size: size)
        if let screen = NSScreen.main {
            let x = floorToScreenPixels(System.backingScale, (screen.frame.width - size.width) / 2)
            let y = floorToScreenPixels(System.backingScale, (screen.frame.height - size.height) / 2)
            rect = .init(origin: .init(x: x, y: y), size: size)
        }

        //
        super.init(contentRect: rect, styleMask: [.fullSizeContentView, .borderless, .miniaturizable, .closable, .titled, .resizable], backing: .buffered, defer: true)
        self.minSize = isStream ? GroupCallTheme.minFullScreenSize : GroupCallTheme.minSize
        self.name = "GroupCallWindow5"
        self.acceptFirstMouse = false
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.animationBehavior = .alertPanel
        self.isReleasedWhenClosed = false
        self.isMovableByWindowBackground = true
        self.level = .normal
        self.appearance = darkPalette.appearance
        
        
       
//        self.toolbar = NSToolbar(identifier: "window")
//        self.toolbar?.showsBaselineSeparator = false
        
        initSaver()
        
        if self.frame.width < rect.width || self.frame.height < rect.height {
            self.setFrame(rect, display: true)
        }
        
    }
    
    
    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        
        if !isFullScreen {
            var point: NSPoint = NSMakePoint(20, 4)
            self.standardWindowButton(.closeButton)?.setFrameOrigin(point)
            point.x += 20
            self.standardWindowButton(.miniaturizeButton)?.setFrameOrigin(point)
            point.x += 20
            self.standardWindowButton(.zoomButton)?.setFrameOrigin(point)
        }
       
    }
        
    deinit {
        var bp:Int = 0
        bp += 1
    }
    
    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
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
        self.window = GroupCallWindow(isStream: call.isStream)
        self.controller = GroupCallUIController(.init(call: call, peerMemberContextsManager: peerMemberContextsManager), size: window.frame.size)
        self.navigation = MajorNavigationController(GroupCallUIController.self, controller, self.window)
        self.navigation._frameRect = NSMakeRect(0, 0, window.frame.width, window.frame.height)
        self.navigation.alwaysAnimate = true
        self.navigation.cleanupAfterDeinit = true
        self.navigation.viewWillAppear(false)
        self.window.contentView = self.navigation.view
        self.window.navigation = navigation
        self.navigation.viewDidAppear(false)
        removeDisposable.set((self.call.canBeRemoved |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                self?.readyClose(last: value)
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
            guard let `self` = self else {
                return
            }
            self._readyPresent()
        }))
    }
    
    private func readyClose(last: Bool = false) {
        if window.isFullScreen {
            window.toggleFullScreen(nil)
            window._windowDidExitFullScreen = { [weak self] in
                self?.invikeClose(last: last)
            }
        } else {
            invikeClose(last: last || call.sharedContext.getCrossAccountGroupCall() == nil)
        }
        
    }
    private func invikeClose(last: Bool) {
        if last {
            call.sharedContext.updateCurrentGroupCallValue(nil)
        }
        closeAllModals(window: window)
        self.navigation.viewWillDisappear(false)
        var window: GroupCallWindow? = self.window
        if self.window.isVisible {
            NSAnimationContext.runAnimationGroup({ _ in
                window?.animator().alphaValue = 0
            }, completionHandler: {
                window?.orderOut(nil)
                if last {
                    window?.contentView?.removeFromSuperview()
                    window?.contentView = nil
                    window?.navigation = nil
                }
                window = nil
            })
        } else if last {
            window?.contentView?.removeFromSuperview()
            window?.contentView = nil
            window?.navigation = nil
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
    func leaveSignal() -> Signal<Bool, NoError> {
        self.controller.disableSounds = true
        return call.sharedContext.endGroupCall(terminate: false)
    }
    
    @objc private func _readyPresent() {
        call.sharedContext.updateCurrentGroupCallValue(self)
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
