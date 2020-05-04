//
//  SectionViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 03/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

private final class SectionControllerArguments {
    let select:(Int)->Void
    init(select:@escaping(Int)->Void) {
        self.select = select
    }
}

public class SectionControllerView : View {
    fileprivate let header: View = View()
    fileprivate let selector:View = View()
    fileprivate let container: View = View()
    private weak var current: ViewController?
    
    public var selectorIndex:Int = 0 {
        didSet {
            if selectorIndex != oldValue {
                var index:Int = 0
                for hContainer in header.subviews {
                    for t in hContainer.subviews {
                        if let t = t as? TextView {
                            t.update(TextViewLayout(.initialize(string: t.layout?.attributedString.string, color: selectorIndex == index ? presentation.colors.accent : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle))
                        }
                        
                    }
                    index += 1
                }
            }
        }
    }
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(header)
        addSubview(container)
        addSubview(selector)
        updateLocalizationAndTheme(theme: presentation)
        needsLayout = true
    }
    
    fileprivate func layout(sections: [SectionControllerItem], selected: Int, hasHeaderView: Bool, arguments: SectionControllerArguments) {
        header.removeAllSubviews()
        header.isHidden = !hasHeaderView
        self.selectorIndex = selected
        for i in 0 ..< sections.count {
            let section = sections[i]
            let headerContainer = Control(frame: NSMakeRect(0, 0, 0, 50))
            let title: TextView = TextView()
            title.isSelectable = false
            title.userInteractionEnabled = false
            title.backgroundColor = presentation.colors.background
            title.update(TextViewLayout(.initialize(string: section.title(), color: i == selected ? presentation.colors.accent : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle))
            headerContainer.addSubview(title)
            header.addSubview(headerContainer)
            headerContainer.border = [.Bottom]
            headerContainer.set(handler: { _ in
                 arguments.select(i)
            }, for: .Click)
        }
        needsLayout = true
    }
    
    
    fileprivate func select(controller: ViewController, index: Int, animated: Bool, notifyApper: Bool = true) {
        let previousIndex = self.selectorIndex
        let previous = self.current
        self.current = controller
        selectorIndex = index
        
        controller.view.frame = container.bounds
        if notifyApper {
            previous?.viewWillDisappear(animated)
        }
        
        let duration: Double = 0.2
        
        container.addSubview(controller.view)
        
        if animated {
            CATransaction.begin()
            let container = header.subviews[index]
            selector.change(pos: NSMakePoint(container.frame.minX, selector.frame.minY), animated: animated, duration: duration, timingFunction: .spring)
            
            
            let pto: NSPoint
            let nfrom: NSPoint
            
          
            if previousIndex < index {
                pto = NSMakePoint(-container.frame.width, 0)
                nfrom = NSMakePoint(container.frame.width, 0)
            } else {
                pto = NSMakePoint(container.frame.width, 0)
                nfrom = NSMakePoint(-container.frame.width, 0)
            }
            
            previous?.view._change(pos: pto, animated: animated, duration: duration, timingFunction: CAMediaTimingFunctionName.spring, completion: { [weak previous, weak controller] complete in
                if complete {
                    previous?.view.removeFromSuperview()
                    previous?.viewDidDisappear(animated)
                    controller?.viewDidAppear(animated)
                }
            })
            controller.view.layer?.animatePosition(from: nfrom, to: NSZeroPoint, duration: duration, timingFunction: CAMediaTimingFunctionName.spring)
            CATransaction.commit()
        } else {
            container.removeAllSubviews()
            previous?.viewDidDisappear(animated)
            container.addSubview(controller.view)
            controller.viewDidAppear(animated)
        }
        needsLayout = true
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.backgroundColor = presentation.colors.background
        selector.backgroundColor = presentation.colors.accent
        container.backgroundColor = presentation.colors.background
        var index:Int = 0
        for hContainer in header.subviews {
            hContainer.background = presentation.colors.background
            for t in hContainer.subviews {
                if let t = t as? TextView {
                    let layout = TextViewLayout(.initialize(string: t.layout?.attributedString.string, color: selectorIndex == index ? presentation.colors.accent : presentation.colors.grayText, font: .medium(.title)), maximumNumberOfLines: 1, truncationType: .middle)
                    layout.measure(width: hContainer.frame.width - 20)
                    t.update(layout)
                    t.center()
                }
                
                t.background = presentation.colors.background
            }
            index += 1
        }
    }
    
    public override func layout() {
        super.layout()
        header.setFrameSize(NSMakeSize(frame.width, header.isHidden ? 0 : 50.0))
        
        let width = floorToScreenPixels(backingScaleFactor, frame.width / CGFloat(max(header.subviews.count, 3)))
        
        selector.frame = NSMakeRect(CGFloat(selectorIndex) * width, header.frame.height - .borderSize, width, .borderSize)
        container.frame = NSMakeRect(0, header.frame.maxY, frame.width, frame.height - header.frame.height)
        container.subviews.first?.frame = container.bounds

        var x:CGFloat = 0
        for i in 0 ..< header.subviews.count {
            let hContainer = header.subviews[i]
            let width = i == header.subviews.count - 1 ? frame.width - x : width
            hContainer.frame = NSMakeRect(x, 0, width, hContainer.frame.height)
            if let textView = hContainer.subviews.first as? TextView {
                textView.layout?.measure(width: width - 10)
                textView.update(textView.layout)
                textView.center()
            }
            x += width
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public class SectionControllerItem {
    let title: ()->String
    let controller: ViewController
    public init(title: @escaping()->String, controller: ViewController) {
        self.title = title
        self.controller = controller
    }
}


public class SectionViewController: GenericViewController<SectionControllerView> {

    private var sections:[SectionControllerItem] = []
    public var selectedSection:SectionControllerItem
    public private(set) var selectedIndex: Int = -1
    private let disposable = MetaDisposable()
    
    public var selectionUpdateHandler:((Int)->Void)?
    
    public func addSection(_ section: SectionControllerItem) {
        sections.append(section)
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        let arguments = SectionControllerArguments { [weak self] index in
            self?.select(index, true)
        }
        genericView.layout(sections: sections, selected: selectedIndex, hasHeaderView: self.hasHeaderView, arguments: arguments)
        genericView.updateLocalizationAndTheme(theme: theme)
    }
    
    deinit {
        disposable.dispose()
    }
    
    public func select(_ index:Int, _ animated: Bool, notifyApper: Bool = true) {
        if selectedIndex != index || !animated {
            selectedSection = sections[index]
            sections[index].controller._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
            sections[index].controller.loadViewIfNeeded()
            let controller = sections[index].controller
            selectedIndex = index
            selectionUpdateHandler?(index)
            if notifyApper {
                sections[index].controller.viewWillAppear(animated)
            }
            disposable.set((sections[index].controller.ready.get() |> filter {$0} |> take(1)).start(next: { [weak self, weak controller] ready in
                if let strongSelf = self, let controller = controller {
                    strongSelf.genericView.select(controller: controller, index: index, animated: animated, notifyApper: notifyApper)
                }
            }))
        }
    }
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectedSection.controller._frameRect = NSMakeRect(0, 0, frame.width, frame.height - 50)
        selectedSection.controller.viewWillAppear(animated)
        self.ready.set(sections[selectedIndex].controller.ready.get())
    }
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        selectedSection.controller.viewWillDisappear(animated)
        window?.remove(object: self, for: .Tab)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        selectedSection.controller.viewDidAppear(animated)
        
        window?.set(handler: { [weak self] () -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            if !self.sections.isEmpty {
                var index:Int = self.selectedIndex
                if index == self.sections.count - 1 {
                    index = 0
                } else {
                    index += 1
                }
                self.select(index, true)
            }
            
            return .invoked
        }, with: self, for: .Tab, priority: .high)
        
        
        window?.add(swipe: { [weak self] direction, _ -> SwipeHandlerResult in
            guard let `self` = self, !self.sections.isEmpty else {return .nothing}

            if !self.selectedSection.controller.supportSwipes {
                return .nothing
            }
            
            switch direction {
            case let .left(state):
                
                switch state {
                case .start:
                    if self.selectedIndex > 0 {
                        let new = self.sections[self.selectedIndex - 1].controller
                        new._frameRect = self.genericView.container.bounds
                        new.view.frame = self.genericView.container.bounds
                        new.viewWillAppear(false)
                        self.genericView.container.addSubview(new.view, positioned: .below, relativeTo: self.selectedSection.controller.view)
                        
                        return .success(new)
                    }
                case let .swiping(delta, controller):
                    
                    let delta = min(max(0, delta), controller.frame.width)
                    
                   // self.genericView.selector.change(pos: NSMakePoint(container.frame.minX, genericView.selector.frame.minY), animated: animated, timingFunction: CAMediaTimingFunctionName.spring)

                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex].frame

                    self.genericView.selector.setFrameOrigin(NSMakePoint(selectorFrame.minX - selectorFrame.width * (delta / controller.frame.width), self.genericView.selector.frame.minY))
                    self.selectedSection.controller.frame = NSMakeRect(delta, self.selectedSection.controller.frame.minY, self.selectedSection.controller.frame.width, self.selectedSection.controller.frame.height)
                    controller.frame = NSMakeRect(delta - controller.frame.width, controller.frame.minY, controller.frame.width, controller.frame.height)
                    return .deltaUpdated(available: delta)
                case let .success(_, controller):
                    controller.view._change(pos: NSMakePoint(0, controller.frame.minY), animated: true)
                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex - 1].frame
                    self.genericView.selector.change(pos: NSMakePoint(selectorFrame.minX, self.genericView.selector.frame.minY), animated: animated)
                    self.selectedSection.controller.view._change(pos: NSMakePoint(self.selectedSection.controller.frame.width, self.selectedSection.controller.frame.minY), animated: true, completion: { [weak self] completed in
                        if completed, let index = self?.sections.lastIndex(where: {$0.controller == controller}) {
                            self?.select(index, false, notifyApper: false)
                        }
                    })
                case let .failed(_, controller):
                    controller.view._change(pos: NSMakePoint(-controller.frame.width, controller.frame.minY), animated: true)
                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex].frame
                    self.genericView.selector.change(pos: NSMakePoint(selectorFrame.minX, self.genericView.selector.frame.minY), animated: animated)
                    self.selectedSection.controller.view._change(pos: NSMakePoint(0, self.selectedSection.controller.frame.minY), animated: true, completion: { [weak controller] completed in
                        if completed {
                            controller?.removeFromSuperview()
                        }
                    })
                }
                
                break
            case let .right(state):
                switch state {
                case .start:
                    if self.selectedIndex < self.sections.count - 1 {
                        let new = self.sections[self.selectedIndex + 1].controller
                        new._frameRect = self.genericView.container.bounds
                        new.view.frame = self.genericView.container.bounds
                        new.viewWillAppear(false)
                        self.genericView.container.addSubview(new.view, positioned: .below, relativeTo: self.selectedSection.controller.view)
                        return .success(new)
                    }
                case let .swiping(delta, controller):
                    
                    let delta = min(max(0, delta), controller.frame.width)
                    
                    
                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex].frame
                    self.genericView.selector.setFrameOrigin(NSMakePoint(selectorFrame.minX + selectorFrame.width * ( delta / controller.frame.width), self.genericView.selector.frame.minY))
                    
                    self.selectedSection.controller.frame = NSMakeRect(-delta, self.selectedSection.controller.frame.minY, self.selectedSection.controller.frame.width, self.selectedSection.controller.frame.height)
                    controller.frame = NSMakeRect(controller.frame.width - delta, controller.frame.minY, controller.frame.width, controller.frame.height)
                    return .deltaUpdated(available: delta)
                case let .success(_, controller):
                    controller.view._change(pos: NSMakePoint(0, controller.frame.minY), animated: true)
                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex + 1].frame
                    self.genericView.selector.change(pos: NSMakePoint(selectorFrame.minX, self.genericView.selector.frame.minY), animated: true)
                    self.selectedSection.controller.view._change(pos: NSMakePoint(-self.selectedSection.controller.frame.width, self.selectedSection.controller.frame.minY), animated: true, completion: { [weak self] completed in
                        if completed, let index = self?.sections.lastIndex(where: {$0.controller == controller}) {
                            self?.select(index, false, notifyApper: false)
                        }
                    })
                case let .failed(_, controller):
                    controller.view._change(pos: NSMakePoint(controller.frame.width, controller.frame.minY), animated: true)
                    let selectorFrame = self.genericView.header.subviews[self.selectedIndex].frame
                    self.genericView.selector.change(pos: NSMakePoint(selectorFrame.minX, self.genericView.selector.frame.minY), animated: true)
                    self.selectedSection.controller.view._change(pos: NSMakePoint(0, self.selectedSection.controller.frame.minY), animated: true, completion: { [weak controller] completed in
                        if completed {
                            controller?.removeFromSuperview()
                        }
                    })
                }
            case .none:
                break
            }
            
            return .nothing
            
        }, with: self.genericView, identifier: SwipeIdentifier("section-swipe"))
        
    }
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        selectedSection.controller.viewDidDisappear(animated)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let arguments = SectionControllerArguments { [weak self] index in
            self?.select(index, true)
        }
        genericView.layout(sections: sections, selected: selectedIndex, hasHeaderView: self.hasHeaderView, arguments: arguments)
        select(selectedIndex, false)
    }
    
    private let hasHeaderView: Bool
    
    public init(sections: [SectionControllerItem], selected: Int = 0, hasHeaderView: Bool = true) {
        assert(!sections.isEmpty)
        self.sections = sections
        self.selectedSection = sections[selected]
        self.selectedIndex = selected
        self.hasHeaderView = hasHeaderView
        super.init()
        bar = .init(height: 0)
    }
    
}
