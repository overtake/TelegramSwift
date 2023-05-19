//
//  Auth_Loading.swift
//  Telegram
//
//  Created by Mike Renoir on 14.02.2022.
//  Copyright © 2022 Telegram. All rights reserved.
//

import Foundation
import TGUIKit


final class Auth_LoadingView: View {
    private let progressView = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progressView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        progressView.progressColor = theme.colors.text
    }
    
    override func layout() {
        super.layout()
        progressView.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class Auth_Loading : GenericViewController<Auth_LoadingView> {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
