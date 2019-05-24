//
//  OpmizeDatabaseView.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 22/04/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

class OpmizeDatabaseView: Control {
    private let textView = TextView()
    
    private let progressView = RadialProgressView.init(theme: RadialProgressTheme.init(backgroundColor: .clear, foregroundColor: theme.colors.text), twist: true, size: NSMakeSize(40, 40))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        addSubview(textView)
        addSubview(progressView)
        self.backgroundColor = theme.colors.background
        let attributedString = NSMutableAttributedString()
        _ = attributedString.append(string: L10n.telegramUpgradeDatabaseTitle, color: theme.colors.text, font: .medium(20))
        _ = attributedString.append(string: "\n\n", color: theme.colors.text, font: .medium(13))
        _ = attributedString.append(string: L10n.telegramUpgradeDatabaseText, color: theme.colors.text, font: .normal(14))
        
        let layout = TextViewLayout(attributedString, alignment: .center, alwaysStaticItems: true)
        layout.measure(width: 300)
        
        textView.update(layout)
        
        textView.userInteractionEnabled = false
        textView.isSelectable = false
        
        progressView.state = .ImpossibleFetching(progress: 0.2, force: true)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func layout() {
        super.layout()
        progressView.centerX(y: frame.midY - progressView.frame.height - 10)
        textView.centerX(y: frame.midY + 10)
        
    }

    func setProgress(_ progress: Float) {
        progressView.state = .ImpossibleFetching(progress: max(0.2, progress), force: true)
    }
    
}
