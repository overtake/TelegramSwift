//
//  StatisticRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 24.02.2020.
//  Copyright © 2020 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import GraphUI
import GraphCore
import SwiftSignalKit
public enum ChartItemType {
    case lines
    case twoAxis
    case pie
    case bars
    case step
    case twoAxisStep
    case hourlyStep
}



class StatisticRowItem: GeneralRowItem {
    let collection: ChartsCollection
    let controller: BaseChartController
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, collection: ChartsCollection, viewType: GeneralViewType, type: ChartItemType, getDetailsData: @escaping (Date, @escaping (String?) -> Void) -> Void) {
        self.collection = collection
        
        let controller: BaseChartController
        switch type {
        case .lines:
            controller = GeneralLinesChartController(chartsCollection: collection)
            controller.isZoomable = false
        case .twoAxis:
            controller = TwoAxisLinesChartController(chartsCollection: collection)
            controller.isZoomable = false
        case .pie:
            controller = PercentPieChartController(chartsCollection: collection)
        case .bars:
            controller = StackedBarsChartController(chartsCollection: collection)
            controller.isZoomable = false
        case .step:
            controller = StepBarsChartController(chartsCollection: collection)
        case .twoAxisStep:
            controller = TwoAxisStepBarsChartController(chartsCollection: collection)
        case .hourlyStep:
            controller = StepBarsChartController(chartsCollection: collection, hourly: true)
            controller.isZoomable = false
        }
        
        
        
        controller.getDetailsData = { date, completion in
            let signal:Signal<ChartsCollection?, NoError> = Signal { subscriber -> Disposable in
                var cancelled: Bool = false
                getDetailsData(date, { detailsData in
                    if let detailsData = detailsData, let data = detailsData.data(using: .utf8), !cancelled {
                        ChartsDataManager.readChart(data: data, extraCopiesCount: 0, sync: true, success: { collection in
                            if !cancelled {
                                subscriber.putNext(collection)
                                subscriber.putCompletion()
                            }
                           
                        }) { error in
                            if !cancelled {
                                subscriber.putNext(nil)
                                subscriber.putCompletion()
                            }
                        }
                    } else {
                        if !cancelled {
                            subscriber.putNext(nil)
                            subscriber.putCompletion()
                        }
                    }
                })
                
                return ActionDisposable {
                    cancelled = true
                }
            }
            
            _ = showModalProgress(signal: signal, for: context.window).start(next: { collection in
                completion(collection)
            })
        }
        self.controller = controller
        
        super.init(initialSize, stableId: stableId, viewType: viewType)
        _ = makeSize(initialSize.width, oldWidth: 0)
    }
    
    private var graphHeight: CGFloat = 0
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        graphHeight = self.controller.height(for: blockWidth - (viewType.innerInset.left + viewType.innerInset.right)) + viewType.innerInset.bottom + viewType.innerInset.top
        return true
    }
    
    override var height: CGFloat {
        return graphHeight
    }
    
    override func viewClass() -> AnyClass {
        return StatisticRowView.self
    }
    
    override var instantlyResize: Bool {
        return false
    }
}
class StatisticRowView: TableRowView {
    private let chartView: ChartStackSection = ChartStackSection()
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
        self.containerView.addSubview(chartView)
        
    }
    
    override func updateMouse() {
        super.updateMouse()
        chartView.updateMouse()
    }
    
    override var backdorColor: NSColor {
        return (theme.colors.isDark ? ChartTheme.defaultNightTheme : ChartTheme.defaultDayTheme).chartBackgroundColor
    }
    
    override func updateColors() {
        guard let item = item as? StatisticRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    override func layout() {
        super.layout()
        guard let item = item as? StatisticRowItem else {
            return
        }
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        chartView.frame = NSMakeRect(item.viewType.innerInset.left, item.viewType.innerInset.top, self.containerView.frame.width - item.viewType.innerInset.left - item.viewType.innerInset.right, self.containerView.frame.height - item.viewType.innerInset.top - item.viewType.innerInset.bottom)
        chartView.layout()
    }
    
    private var first: Bool = true

    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StatisticRowItem else {
            return
        }
        
        layout()
        
        chartView.setup(controller: item.controller, title: "Test")

        chartView.apply(theme: theme.colors.isDark ? .defaultNightTheme : .defaultDayTheme, animated: false)
        
        if first {
            chartView.layer?.animateAlpha(from: 0, to: 1, duration: 0.25)
        }
        first = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}


class StatisticLoadingRowItem: GeneralRowItem {
    fileprivate let errorTextLayout: TextViewLayout?
    init(_ initialSize: NSSize, stableId: AnyHashable, error: String?) {
        let height: CGFloat = 308 + GeneralViewType.singleItem.innerInset.bottom + GeneralViewType.singleItem.innerInset.top + 30
        if let error = error {
            self.errorTextLayout = TextViewLayout.init(.initialize(string: error, color: theme.colors.grayText, font: .normal(.text)))
        } else {
            self.errorTextLayout = nil
        }
        super.init(initialSize, height: height, stableId: stableId, viewType: .singleItem)
        _ = self.makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        errorTextLayout?.measure(width: blockWidth - viewType.innerInset.left - viewType.innerInset.right)
        return true
    }
    
    override func viewClass() -> AnyClass {
        return StatisticLoadingRowView.self
    }
    
    override var instantlyResize: Bool {
        return false
    }
}
class StatisticLoadingRowView: TableRowView {
    private let containerView = GeneralRowContainerView(frame: NSZeroRect)
    private var errorView: TextView?
    private var progressIndicator: ProgressIndicator?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(self.containerView)
        
    }
    
    override var backdorColor: NSColor {
        return theme.colors.background
    }
    
    override func updateColors() {
        guard let item = item as? StatisticLoadingRowItem else {
            return
        }
        self.backgroundColor = item.viewType.rowBackground
        self.containerView.backgroundColor = backdorColor
    }
    override func layout() {
        super.layout()
        guard let item = item as? StatisticLoadingRowItem else {
            return
        }
        
        self.containerView.frame = NSMakeRect(floorToScreenPixels(backingScaleFactor, (frame.width - item.blockWidth) / 2), item.inset.top, item.blockWidth, frame.height - item.inset.bottom - item.inset.top)
        self.containerView.setCorners(item.viewType.corners)
        
        errorView?.center()
        progressIndicator?.center()
    }
    
    
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? StatisticLoadingRowItem else {
            return
        }
        
        if let error = item.errorTextLayout {
            if self.errorView == nil {
                self.errorView = TextView()
                self.errorView?.isSelectable = false
                self.containerView.addSubview(self.errorView!)
                self.errorView?.center()
                if animated {
                    self.errorView?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            if animated {
                if let progress = self.progressIndicator {
                    self.progressIndicator = nil
                    progress.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak progress] _ in
                        progress?.removeFromSuperview()
                    })
                }
            } else {
                self.progressIndicator?.removeFromSuperview()
                self.progressIndicator = nil
            }
            self.errorView?.update(error)
        } else {
            if self.progressIndicator == nil {
                self.progressIndicator = ProgressIndicator(frame: NSMakeRect(0, 0, 30, 30))
                self.containerView.addSubview(self.progressIndicator!)
                self.errorView?.center()
                if animated {
                    self.progressIndicator?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                }
            }
            if animated {
                self.progressIndicator?.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                if let errorView = self.errorView {
                    self.errorView = nil
                    errorView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak errorView] _ in
                        errorView?.removeFromSuperview()
                    })
                }
            } else {
                self.errorView?.removeFromSuperview()
                self.errorView = nil
            }
        }
        
        needsLayout = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
