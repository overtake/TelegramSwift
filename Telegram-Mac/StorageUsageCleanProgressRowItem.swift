//
//  StorageUsageCleanProgressRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/08/2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKit

class StorageUsageCleanProgressRowItem: GeneralRowItem {
    private let task: CCTaskData
    fileprivate var currentProgress: Float
    init(_ initialSize: NSSize, stableId: AnyHashable, task: CCTaskData, viewType: GeneralViewType) {
        self.task = task
        self.currentProgress = task.currentProgress
        super.init(initialSize, height: 40, stableId: stableId, viewType: viewType)
    }
    
    override func viewClass() -> AnyClass {
        return  StorageUsageCleanProgressRowView.self
    }
    
    
    fileprivate var progress: Signal<Float, NoError> {
        return self.task.progress |> deliverOnMainQueue
    }
}


private final class StorageUsageCleanProgressRowView : GeneralContainableRowView {
    
    private let disposable = MetaDisposable()
    
    private let progressView: LinearProgressControl = LinearProgressControl(progressHeight: 4)
    
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(progressView)
    }
    
    override func layout() {
        super.layout()
        
        guard let item = item as? StorageUsageCleanProgressRowItem else {
            return
        }
        progressView.setFrameSize(NSMakeSize(item.blockWidth - item.viewType.innerInset.left  - item.viewType.innerInset.right, 4))
        progressView.center()
        
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StorageUsageCleanProgressRowItem else {
            return
        }
        progressView.style = ControlStyle(foregroundColor: theme.colors.accent, backgroundColor: theme.colors.grayUI)
        progressView.set(progress: CGFloat(item.currentProgress), animated: animated, duration: 0.2, timingFunction: .linear)
        progressView.cornerRadius = 2
        
        disposable.set(item.progress.start(next: { [weak self] value in
            self?.progressView.set(progress: CGFloat(value), animated: true, duration: 0.2, timingFunction: .linear)
        }))
        
    }
    
    deinit {
        disposable.dispose()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
