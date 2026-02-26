//
//  MetalEngineTestController.swift
//  Telegram
//
//  Created by Mike Renoir on 07.12.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import TGUIKit
import MetalEngine
import DustLayer
import CallVideoLayer


final class MetalEngineTestView: View {
    private let metalLayer = CallBlobsLayer()
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        background = .blue
        metalLayer.frame = NSMakeRect(50, 50, 300, 300)
        self.layer?.addSublayer(metalLayer)
        metalLayer.backgroundColor = .clear
        metalLayer.isInHierarchy = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
final class  MetalEngineTestController : GenericViewController<MetalEngineTestView> {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        readyOnce()
        
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
}
