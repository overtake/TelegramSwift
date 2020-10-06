//
//  CameraPreviewRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 06/10/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

class CameraPreviewRowItem: GeneralRowItem {
    fileprivate let device: AVCaptureDevice
    fileprivate let session: AVCaptureSession
    init(_ initialSize: NSSize, stableId: AnyHashable, device: AVCaptureDevice, viewType: GeneralViewType) {
        self.device = device
        self.session = AVCaptureSession()
        let input = try? AVCaptureDeviceInput(device: device)
        if let input = input {
            self.session.addInput(input)
        }
        super.init(initialSize, height: 220, stableId: stableId, viewType: viewType)
        
        self.session.startRunning()

    }
    deinit {
    }
    
    override func viewClass() -> AnyClass {
        return CameraPreviewRowView.self
    }
}

private final class CameraPreviewRowView : GeneralContainableRowView {
    private let captureLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer()
    private let view = View()
    private let progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 40, 40))
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progressIndicator)
        addSubview(view)
        view.layer?.addSublayer(self.captureLayer)
    }
    
    override func updateColors() {
        super.updateColors()
        progressIndicator.progressColor = theme.colors.text
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? CameraPreviewRowItem else {
            return
        }
        
        captureLayer.session = item.session
        captureLayer.connection?.automaticallyAdjustsVideoMirroring = false
        captureLayer.connection?.isVideoMirrored = true
        captureLayer.videoGravity = .resizeAspectFill
        
    }
    
    override func layout() {
        super.layout()
        view.frame = containerView.bounds
        captureLayer.frame = view.bounds
        progressIndicator.center()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

