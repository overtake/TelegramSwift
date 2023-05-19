//
//  GroupCallStatusBar.swift
//  Telegram
//
//  Created by Mike Renoir on 04.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKit
import TGUIKit
import ColorPalette

private func generateStatus(alpha: CGFloat) -> NSImage {
    let image = generateImage(NSMakeSize(24, 20), scale: nil, rotatedContext: { size, ctx in
        ctx.clear(size.bounds)
        ctx.setFillColor(darkPalette.redUI.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: NSMakeRect(6, 5, 10, 10))
    })
    return NSImage(cgImage: image!, size: image!.systemSize)
}

final class GroupCallStatusBar {
    private let disposable = MetaDisposable()
    private let sharedContext: SharedAccountContext
    
    private var animator: DisplayLinkAnimator? = nil
    private let arguments: GroupCallUIArguments
    init(_ signal: Signal<GroupCallUIState, NoError>, arguments: GroupCallUIArguments, sharedContext: SharedAccountContext) {
        self.sharedContext = sharedContext
        self.arguments = arguments
        disposable.set(signal.start(next: { [weak self] state in
            self?.updateState(state)
        }))
    }
    private var previous: Bool? = nil
    private func updateState(_ state: GroupCallUIState) {
        let hasShare = state.hasScreencast || state.hasVideo
        
        var items:[ContextMenuItem] = []
        if state.hasScreencast {
            items.append(.init(strings().groupCallStatusBarStopScreen, handler: { [weak self] in
                self?.arguments.cancelShareScreencast()
            }, image: NSImage(named: "group_call_stop_share_screen")))
        } else if !state.cantRunVideo {
            items.append(.init(strings().groupCallStatusBarStartScreen, handler: { [weak self] in
                self?.arguments.shareSource(.screencast, true)
            }, image: NSImage(named: "group_call_share_screen")))
        }
        if state.hasVideo {
            items.append(.init(strings().groupCallStatusBarStopVideo, handler: { [weak self] in
                self?.arguments.cancelShareVideo()
            }, image: NSImage(named: "group_call_stop_share_video")))
        } else if !state.cantRunVideo {
            items.append(.init(strings().groupCallStatusBarStartVideo, handler: { [weak self] in
                self?.arguments.shareSource(.video, true)
            }, image: NSImage(named: "group_call_share_video")))
        }
        
        if !items.isEmpty {
            self.sharedContext.callStatusBarMenuItems = {
                return items
            }
        } else {
            self.sharedContext.callStatusBarMenuItems = nil
        }
        
        
        if hasShare != previous {
            if hasShare {
                self.runAnimator()
            } else {
                forceUpdateStatusBarIconByDockTile(sharedContext: sharedContext)
                self.animator = nil
            }
        }
        self.previous = hasShare
    }
    
    private func clear() {
        forceUpdateStatusBarIconByDockTile(sharedContext: sharedContext)
        self.animator = nil
        self.sharedContext.callStatusBarMenuItems = nil
    }
    

    private var reversed: Bool = false
    private func runAnimator() {
        
        self.animator = DisplayLinkAnimator(duration: 1.5, from: 0.3, to: 1, update: { [weak self] value in
            guard let reversed = self?.reversed else {
                return
            }
            DispatchQueue.global().async {
                let image = generateStatus(alpha: reversed ? ( 1 - value + 0.3) : value)
                DispatchQueue.main.async {
                    self?.sharedContext.updateStatusBarImage(image)
                }
            }
            
        }, completion: { [weak self] in
            guard let reversed = self?.reversed else {
                return
            }
            self?.reversed = !reversed
            self?.runAnimator()
        })
    }
    
    deinit {
        disposable.dispose()
        clear()
    }
}
