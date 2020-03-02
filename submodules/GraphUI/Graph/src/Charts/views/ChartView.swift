//
//  ChartView.swift
//  GraphTest
//
//  Created by Andrei Salavei on 4/7/19.
//  Copyright © 2019 Andrei Salavei. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphCore

class ChartView: Control {
    required init(frame: CGRect) {
        super.init(frame: frame)
        
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        setupView()
    }
    
    var chartInsets: NSEdgeInsets = NSEdgeInsets(top: 40, left: 16, bottom: 35, right: 16) {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var renderers: [ChartViewRenderer] = [] {
        willSet {
            renderers.forEach { $0.containerViews.removeAll(where: { $0 == self }) }
        }
        didSet {
            renderers.forEach { $0.containerViews.append(self) }
            setNeedsDisplay()
        }
    }
    
    var chartFrame: CGRect {
        let chartBound = self.bounds
        return CGRect(x: chartInsets.left,
                      y: chartInsets.top,
                      width: max(1, chartBound.width - chartInsets.left - chartInsets.right),
                      height: max(1, chartBound.height - chartInsets.top - chartInsets.bottom))
    }
    
    override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        let chartBounds = self.bounds
        let chartFrame = self.chartFrame
        
        for renderer in renderers {
            renderer.render(context: ctx, bounds: chartBounds, chartFrame: chartFrame)
        }
    }
    
    var userDidSelectCoordinateClosure: ((CGPoint) -> Void)?
    var userDidDeselectCoordinateClosure: (() -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        
        let point = convert(event.locationInWindow, from: nil)
        
        let fractionPoint = CGPoint(x: (point.x - chartFrame.origin.x) / chartFrame.width,
                                    y: (point.y - chartFrame.origin.y) / chartFrame.height)
        
        if NSPointInRect(point, frame) {
            userDidSelectCoordinateClosure?(fractionPoint)
        }
        
    }
    
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        let point = convert(event.locationInWindow, from: nil)
        
        let fractionPoint = CGPoint(x: (point.x - chartFrame.origin.x) / chartFrame.width,
                                    y: (point.y - chartFrame.origin.y) / chartFrame.height)
                
        if NSPointInRect(point, frame) {
            userDidSelectCoordinateClosure?(fractionPoint)
        }
    
    }
    
    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        userDidDeselectCoordinateClosure?()
    }
    
    // MARK: Details View
    
    private var detailsView: ChartDetailsView!
    private var maxDetailsViewWidth: CGFloat = 0
    func loadDetailsViewIfNeeded() {
        if detailsView == nil {
            let detailsView = ChartDetailsView(frame: bounds)
            addSubview(detailsView)
            detailsView.alphaValue = 0
            self.detailsView = detailsView
        }
    }
    
    private var detailsTableTopOffset: CGFloat = 5
    private var detailsTableLeftOffset: CGFloat = 8
    private var isDetailsViewVisible: Bool = false

    var detailsViewPosition: CGFloat = 0 {
        didSet {
            loadDetailsViewIfNeeded()
            let detailsViewSize = detailsView.intrinsicContentSize
            maxDetailsViewWidth = max(maxDetailsViewWidth, detailsViewSize.width)
            if maxDetailsViewWidth + detailsTableLeftOffset > detailsViewPosition {
                detailsView.frame = CGRect(x: floorToScreenPixels(System.backingScale, min(detailsViewPosition + detailsTableLeftOffset, bounds.width - maxDetailsViewWidth)),
                                           y: floorToScreenPixels(System.backingScale, chartInsets.top + detailsTableTopOffset),
                                           width: maxDetailsViewWidth,
                                           height: detailsViewSize.height)
            } else {
                detailsView.frame = CGRect(x: floorToScreenPixels(System.backingScale, detailsViewPosition - maxDetailsViewWidth - detailsTableLeftOffset),
                                           y: floorToScreenPixels(System.backingScale, chartInsets.top + detailsTableTopOffset),
                                           width: maxDetailsViewWidth,
                                           height: detailsViewSize.height)
            }
        }
    }
    
    func setDetailsChartVisible(_ visible: Bool, animated: Bool) {
        guard isDetailsViewVisible != visible else {
            return
        }
        isDetailsViewVisible = visible
        loadDetailsViewIfNeeded()
        detailsView.setVisible(visible, animated: animated)
        if !visible {
            maxDetailsViewWidth = 0
        }
    }
    
    func setDetailsViewModel(viewModel: ChartDetailsViewModel, animated: Bool) {
        loadDetailsViewIfNeeded()
        detailsView.setup(viewModel: viewModel, animated: animated)
        View.perform(animated: animated, animations: {
            let position = self.detailsViewPosition
            self.detailsViewPosition = position
        })
    }

    func setupView() {
        backgroundColor = .clear
        layer?.drawsAsynchronously = true
    }
}


extension ChartView: GColorModeContainer {
    func apply(colorMode: GColorMode, animated: Bool) {
        detailsView?.apply(colorMode: colorMode, animated: animated && (detailsView?.isVisibleInWindow ?? false))
    }
}
