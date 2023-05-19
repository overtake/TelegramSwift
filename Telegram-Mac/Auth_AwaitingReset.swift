//
//  Auth_AwaitingResetController.swift
//  Telegram
//
//  Created by Mike Renoir on 17.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import AppKit
import TelegramCore
import SwiftSignalKit

private func timerValueString(days: Int32, hours: Int32, minutes: Int32) -> String {
    var string = NSMutableAttributedString()
    
    var daysString = ""
    if days > 0 {
        daysString = "**" + strings().timerDaysCountable(Int(days)) + "** "
    }
    
    var hoursString = ""
    if hours > 0 || days > 0 {
        hoursString = "**" + strings().timerHoursCountable(Int(hours)) + "** "
    }
    
    let minutesString = "**" + strings().timerMinutesCountable(Int(minutes)) + "**"
    
    return daysString + hoursString + minutesString
}

private final class Auth_AwaitingResetHeaderView : View {
    private let playerView:LottiePlayerView = LottiePlayerView()
    private let header: TextView = TextView()
    private let desc: TextView = TextView()
    private var descAttr: NSAttributedString?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(playerView)
        addSubview(header)
        addSubview(desc)
        header.userInteractionEnabled = false
        header.isSelectable = false
        
        desc.userInteractionEnabled = false
        desc.isSelectable = false
        
        updateLocalizationAndTheme(theme: theme)
    }
    
    private var number: String = ""
    private var resetInText: String = ""

    func updateText(_ number: String?, resetInText: String) {
        self.resetInText = resetInText
        self.number = number ?? ""
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        let theme = theme as! TelegramPresentationTheme
        if let data = LocalAnimatedSticker.keychain.data {
            self.playerView.set(LottieAnimation(compressed: data, key: .init(key: .bundle("keychain"), size: Auth_Insets.logoSize, backingScale: Int(System.backingScale), fitzModifier: nil, colors: []), playPolicy: .onceEnd))
        }
        
        let layout = TextViewLayout(.initialize(string: strings().loginNewResetHeader, color: theme.colors.text, font: Auth_Insets.headerFont))
        layout.measure(width: frame.width)
        self.header.update(layout)
        
        let descAttr = NSMutableAttributedString()
        
        _ = descAttr.append(string: strings().loginNewResetInfo(formatPhoneNumber(self.number), self.resetInText), color: theme.colors.grayText, font: Auth_Insets.infoFont)
        descAttr.detectBoldColorInString(with: .medium(.header))
        let descLayout = TextViewLayout(descAttr, alignment: .center)
        descLayout.measure(width: frame.width)
        self.desc.update(descLayout)
        
        self.layout()
    }
    
    override func layout() {
        super.layout()
        self.playerView.setFrameSize(Auth_Insets.logoSize)
        self.playerView.centerX(y: 0)
        self.header.centerX(y: self.playerView.frame.maxY + 20)
        self.desc.centerX(y: self.header.frame.maxY + 10)

    }
    
    var height: CGFloat {
        return self.desc.frame.maxY
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func playAnimation() {
        playerView.playAgain()
    }
}

final class Auth_AwaitingResetView: View {
    private let container: View = View()
    private let header:Auth_AwaitingResetHeaderView
    private let nextView = Auth_NextView()
    private var locked: Bool = false
    
    var protectedUntil: Int32 = 0
    private var timer: SwiftSignalKit.Timer?
    
    private var takeReset:(()->Void)?
    
    private let resetIn = TextView()
    
    private var number: String?
    
    required init(frame frameRect: NSRect) {
        header = Auth_AwaitingResetHeaderView(frame: frameRect.size.bounds)
        super.init(frame: frameRect)
        container.addSubview(header)
        container.addSubview(nextView)
        container.addSubview(resetIn)
        addSubview(container)
        nextView.set(handler: { [weak self] _ in
            self?.invoke()
        }, for: .Click)
        
  
        updateLocalizationAndTheme(theme: theme)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        nextView.updateLocalizationAndTheme(theme: theme)
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        container.setFrameSize(NSMakeSize(frame.width, header.height + Auth_Insets.betweenHeader + Auth_Insets.betweenHeader + resetIn.frame.height + Auth_Insets.betweenHeader + Auth_Insets.nextHeight + Auth_Insets.betweenHeader))
        
        header.setFrameSize(NSMakeSize(frame.width, header.height))
        header.centerX(y: 0)
        resetIn.centerX(y: header.frame.maxY + Auth_Insets.betweenHeader)
        nextView.centerX(y: resetIn.frame.maxY + Auth_Insets.betweenHeader)
        container.center()
        
    }
    
    private func updateTimerValue() {
        let timerSeconds = max(0, self.protectedUntil - Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970))
        
        let secondsInAMinute: Int32 = 60
        let secondsInAnHour: Int32 = 60 * secondsInAMinute
        let secondsInADay: Int32 = 24 * secondsInAnHour
        
        let days = timerSeconds / secondsInADay
        
        let hourSeconds = timerSeconds % secondsInADay
        let hours = hourSeconds / secondsInAnHour
        
        let minuteSeconds = hourSeconds % secondsInAnHour
        var minutes = minuteSeconds / secondsInAMinute
        
        if days == 0 && hours == 0 && minutes == 0 && timerSeconds > 0 {
            minutes = 1
        }
        
        let attr = NSMutableAttributedString()
        
        _ = attr.append(string: timerValueString(days: days, hours: hours, minutes: minutes), color: theme.colors.grayText, font: .code(.title))
        attr.detectBoldColorInString(with: .bold(.text))
        
        let layout = TextViewLayout(attr, alignment: .left, alwaysStaticItems: true)
        layout.measure(width: frame.width)
        
        resetIn.update(layout)
        nextView.updateLocked(timerSeconds > 0, string: strings().loginNewResetButton)

        resetIn.change(opacity: timerSeconds > 0 ? 1 : 0)
        
        if timerSeconds <= 0 {
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            timer = .init(timeout: 1, repeat: true, completion: { [weak self] in
                self?.updateTimerValue()
            }, queue: .mainQueue())
            timer?.start()
        }
        self.header.updateText(self.number, resetInText: timerSeconds <= 0 ? strings().loginNewResetAble : strings().loginNewResetWillAble)
        needsLayout = true
    }

    
    func invoke() {
        self.takeReset?()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    func update(locked: Bool, protectedUntil: Int32?, number: String?, takeReset:@escaping()->Void) {
        self.number = number
        self.takeReset = takeReset
        self.protectedUntil = protectedUntil ?? 0
        updateTimerValue()
        needsLayout = true
    }
    
    func playAnimation() {
        header.playAnimation()
    }
}

final class Auth_AwaitingResetController : GenericViewController<Auth_AwaitingResetView> {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
    }
    
    func update(locked: Bool, protectedUntil: Int32?, number: String?, takeReset:@escaping()->Void) {
        self.genericView.update(locked: locked, protectedUntil: protectedUntil, number: number, takeReset: takeReset)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if animated {
            genericView.playAnimation()
        }
    }
}
