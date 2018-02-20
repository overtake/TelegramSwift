//
//  InstantPageChannelView.swift
//  Telegram
//
//  Created by keepcoder on 14/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac

class InstantPageChannelView : View, InstantPageView {
    private let channel: TelegramChannel
    private let overlay: Bool
    private var nameLayout:(TextNodeLayout, TextNode)
    private var joinLayout:(TextNodeLayout, TextNode)
    private var checkView: ImageView = ImageView()
    private let joinChannel:(TelegramChannel)->Void
    private let openChannel:(TelegramChannel)->Void
    
    init(frameRect: NSRect, channel: TelegramChannel, overlay: Bool, openChannel: @escaping(TelegramChannel)->Void, joinChannel: @escaping(TelegramChannel)->Void) {
        self.channel = channel
        self.overlay = overlay
        self.joinChannel = joinChannel
        self.openChannel = openChannel
        checkView.image = theme.icons.ivChannelJoined
        checkView.sizeToFit()
        joinLayout = TextNode.layoutText(.initialize(string: tr(L10n.ivChannelJoin), color: .white, font: .normal(.huge)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
        
        nameLayout = TextNode.layoutText(.initialize(string: channel.displayTitle, color: .white, font: .normal(.huge)), nil, 1, .end, NSMakeSize(frameRect.width - 40 - joinLayout.0.size.width, .greatestFiniteMagnitude), nil, false, .left)
        super.init(frame: frameRect)
        
        self.backgroundColor = overlay ? theme.colors.blackTransparent : theme.colors.grayBackground
    }
    
    override func layout() {
        super.layout()
        joinLayout = TextNode.layoutText(.initialize(string: tr(L10n.ivChannelJoin), color: overlay ? .white : theme.colors.text, font: .normal(.huge)), nil, 1, .end, NSMakeSize(.greatestFiniteMagnitude, .greatestFiniteMagnitude), nil, false, .left)
        
        nameLayout = TextNode.layoutText(.initialize(string: channel.displayTitle, color: overlay ? .white : theme.colors.text, font: .normal(.huge)), nil, 1, .end, NSMakeSize(frame.width - 40 - joinLayout.0.size.width, .greatestFiniteMagnitude), nil, false, .left)
        checkView.centerY(x: frame.width - checkView.frame.width - 20)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        let point = convert(event.locationInWindow, from: nil)
        if point.x >= 20 && point.x <= 20 + nameLayout.0.size.width {
            openChannel(channel)
        } else {
            switch channel.participationStatus {
            case .left, .kicked:
                if point.x >= frame.width - joinLayout.0.size.width - 20 && point.x <= frame.width - 20 {
                    joinChannel(channel)
                }
            default:
                break
            }
        }
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor((overlay ? theme.colors.blackTransparent : theme.colors.grayBackground).cgColor)
        ctx.fill(bounds)
        
        let f = focus(nameLayout.0.size)
        nameLayout.1.draw(NSMakeRect(40, f.minY, f.width, f.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        
        switch channel.participationStatus {
        case .member:
            checkView.isHidden = true
        default:
            checkView.isHidden = true
            let f = focus(joinLayout.0.size)
            joinLayout.1.draw(NSMakeRect(frame.width - f.width - 40, f.minY, f.width, f.height), in: ctx, backingScaleFactor: backingScaleFactor, backgroundColor: backgroundColor)
        }
    }
    
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    required init(frame frameRect: NSRect) {
        fatalError("init(frame:) has not been implemented")
    }
    
    static var height: CGFloat {
        return 40
    }
    
}
