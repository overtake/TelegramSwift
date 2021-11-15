//
//  GroupCallSpeakingTooltipView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 25.05.2021.
//  Copyright © 2021 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import SwiftSignalKit

import Postbox
import TelegramCore

final class GroupCallSpeakingTooltipView: Control {
    private let nameView: TextView = TextView()
    private let avatarView = GroupCallAvatarView(frame: NSMakeRect(0, 0, 42, 42), photoSize: NSMakeSize(30, 30))
    private let backgroundView = View()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(avatarView)
        addSubview(nameView)
        
        nameView.userInteractionEnabled = false
        nameView.isSelectable = false
        avatarView.isEventLess = true
        backgroundView.isEventLess = true
        scaleOnClick = true
    }
    
    func setPeer(data: PeerGroupCallData, account: Account, audioLevel:(PeerId)->Signal<Float?, NoError>?) {
        self.avatarView.update(audioLevel, data: data, activityColor: GroupCallTheme.speakActiveColor, account: account, animated: true)
                
        
        let attr = NSMutableAttributedString()
        _ = attr.append(string: strings().voiceChatTooltipIsSpeaking(data.peer.compactDisplayTitle.prefix(25)), color: GroupCallTheme.customTheme.textColor, font: .normal(.text))
        attr.detectBoldColorInString(with: .medium(.text))
        let layout = TextViewLayout(attr, maximumNumberOfLines: 1)
        layout.measure(width: 200)
        nameView.update(layout)
                
        
        setFrameSize(NSMakeSize(30 + layout.layoutSize.width + 30, 42))
        
        backgroundView.layer?.cornerRadius = 30 / 2
        backgroundView.backgroundColor = GroupCallTheme.membersColor
    }
    
    override func layout() {
        super.layout()
        backgroundView.frame = focus(NSMakeSize(frame.width - 12, 30))
        avatarView.centerY(x: 0)
        nameView.centerY(x: 30 + 10)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

