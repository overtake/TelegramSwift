//
//  ModalAlertController.swift
//  Telegram
//
//  Created by Mike Renoir on 07.09.2023.
//  Copyright © 2023 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let action: ()->Void
    let toggle: (Int)->Void
    init(action: @escaping()->Void, toggle: @escaping(Int)->Void) {
        self.action = action
        self.toggle = toggle
    }
}

private struct State : Equatable {
    var data: ModalAlertData
}



private final class RowItem : TableRowItem {
    struct Option {
        let selected: Bool
        let mandatory: Bool
        let text: TextViewLayout
        
        var size: NSSize {
            return NSMakeSize(text.layoutSize.width + 25 + 10, 20)
        }
    }
    struct Description {
        let onlyWhenEnabled: Bool
        let text: TextViewLayout
        
        var size: NSSize {
            return text.layoutSize
        }
    }
    fileprivate let state: State
    fileprivate let info: TextViewLayout
    fileprivate var desc: Description?
    fileprivate let options: [Option]
    fileprivate let toggle: (Int)->Void
    fileprivate let action:()->Void
    init(_ initialSize: NSSize, state: State, toggle:@escaping(Int)->Void, action: @escaping()->Void) {
        self.state = state
        self.toggle = toggle
        self.action = action
        
        let info = parseMarkdownIntoAttributedString(state.data.info, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.listGrayText), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.listGrayText), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accent), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
        })).mutableCopy() as! NSMutableAttributedString
        
        info.detectBoldColorInString(with: .medium(.text))
        
        self.info = .init(info, alignment: .center)
        
        self.info.interactions = globalLinkExecutor
        
        if let desc = state.data.description {
            let text = parseMarkdownIntoAttributedString(desc.string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
            })).mutableCopy() as! NSMutableAttributedString
            
            text.detectBoldColorInString(with: .medium(.text))
            
            self.desc = .init(onlyWhenEnabled: desc.onlyWhenEnabled, text: .init(text, alignment: .center))
        } else {
            self.desc = nil
        }
        

        var opts: [Option] = []
        for option in state.data.options {
            let text = parseMarkdownIntoAttributedString(option.string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: .normal(.text), textColor: theme.colors.text), bold: MarkdownAttributeSet(font: .bold(.text), textColor: theme.colors.text), link: MarkdownAttributeSet(font: .medium(.text), textColor: theme.colors.accent), linkAttribute: { contents in
                return (NSAttributedString.Key.link.rawValue, inAppLink.external(link: contents, false))
            }))
            
            let layout = TextViewLayout(text)
            
            layout.interactions = globalLinkExecutor
            let value = Option(selected: option.isSelected, mandatory: option.mandatory, text: layout)
            opts.append(value)
        }
        self.options = opts
        
        super.init(initialSize)
        _ = makeSize(initialSize.width)
    }
    
    override var stableId: AnyHashable {
        return 0
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        info.measure(width: width - 40)
        for option in options {
            option.text.measure(width: width - 40 - 40)
        }
        desc?.text.measure(width: width - 40)
        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
                        
        height += info.layoutSize.height
        height += 20
        
        if !options.isEmpty {
            height += 20
        }
        height += optionsSize.height
        
        if let descprion = desc {
            if !descprion.onlyWhenEnabled || actionEnabled {
                height += descprion.size.height
                height += 10
            }
        }
        
        height += 40 //button
        height += 20

        return height
    }
    
    var optionsSize: NSSize {
        var height: CGFloat = 0
        var width: CGFloat = 0
        for (i, option) in options.enumerated() {
            height += option.size.height
            if i != options.count - 1 {
                height += 10
            }
            width = max(width, option.size.width)
        }
        return NSMakeSize(width, height)
    }
    
    var actionEnabled: Bool {
        var enabled: Bool = true
        for option in options {
            if option.mandatory && !option.selected {
                enabled = false
                break
            }
        }
        return enabled
    }
    
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView : TableRowView {
   

    private final class OptionView: Control {
        private let textView = TextView()
        private let imageView = SelectingControl(unselectedImage: theme.icons.chatToggleUnselected, selectedImage: theme.icons.generalCheck)
        private var toggle:(()->Void)? = nil
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            textView.isSelectable = false
            addSubview(textView)
            addSubview(imageView)
            
            imageView.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
            
            textView.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
            
            self.set(handler: { [weak self] _ in
                self?.toggle?()
            }, for: .Click)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(option: RowItem.Option, toggle:@escaping()->Void, animated: Bool) {
            self.toggle = toggle
            self.textView.update(option.text)
            self.imageView.set(selected: option.selected, animated: animated)
        }
        
        override func layout() {
            super.layout()
            self.updateLayout(size: self.frame.size, transition: .immediate)
        }
        func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
            transition.updateFrame(view: imageView, frame: imageView.centerFrameY(x: 0))
            transition.updateFrame(view: textView, frame: textView.centerFrameY(x: imageView.frame.maxX + 10))
        }
    }
    
    private let infoView = TextView()
    private let button = TitleButton(frame: .zero)
    private let optionsView = View()
    
    private var descriptionView:TextView?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(infoView)
        addSubview(button)
        addSubview(optionsView)
                
        infoView.isSelectable = false
        
        button.set(handler: { [weak self] _ in
            if let item = self?.item as? RowItem {
                item.action()
            }
        }, for: .Click)
        
        button.scaleOnClick = true
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? RowItem else {
            return
        }
        
        let transition: ContainedViewLayoutTransition
        if animated {
            transition = .animated(duration: 0.2, curve: .easeOut)
        } else {
            transition = .immediate
        }
        
        self.infoView.update(item.info)
        
        
        self.button.userInteractionEnabled = item.actionEnabled
        self.button.isEnabled = item.actionEnabled
        self.button.alphaValue = item.actionEnabled ? 1 : 0.8
        
        
        optionsView.setFrameSize(item.optionsSize)
        
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: NSMakeRect(0, 0, optionsView.frame.width, 20)))
        }
        for (i, option) in item.options.enumerated() {
            (optionsView.subviews[i] as! OptionView).update(option: option, toggle: { [weak item] in
                item?.toggle(i)
            }, animated: animated)
        }
        
        if let desc = item.desc, !desc.onlyWhenEnabled || item.actionEnabled {
            let current: TextView
            let isNew: Bool
            if let view = self.descriptionView {
                current = view
                isNew = false
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                self.descriptionView = current
                addSubview(current)
                isNew = true
            }
            current.update(desc.text)
            if isNew {
                current.centerX(y: button.frame.minY - 10 - current.frame.height)
                if animated {
                    current.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    current.layer?.animateScaleSpring(from: 0.1, to: 1, duration: 0.2, bounce: false)
                }
            }
        } else if let view = self.descriptionView {
            performSubviewRemoval(view, animated: animated, duration: 0.2, scale: true)
            self.descriptionView = nil
        }
        
        button.set(background: theme.colors.accent, for: .Normal)
        button.set(text: item.state.data.ok, for: .Normal)
        button.set(font: .medium(.text), for: .Normal)
        button.set(color: theme.colors.underSelectedColor, for: .Normal)

        button.sizeToFit(.zero, NSMakeSize(frame.width - 40, 40), thatFit: true)
        button.layer?.cornerRadius = 10
                
      
        updateLayout(size: self.frame.size, transition: transition)
    }
    
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? RowItem else {
            return
        }
        
        transition.updateFrame(view: infoView, frame: infoView.centerFrameX(y: 0))

        transition.updateFrame(view: optionsView, frame: optionsView.centerFrameX(y: infoView.frame.maxY + 20))
        
        transition.updateFrame(view: button, frame: button.centerFrameX(y: size.height - 20 - button.frame.height))
        
        var y: CGFloat = 0
        for (i, view) in optionsView.subviews.enumerated() {
            let view = view as! OptionView
            let option = item.options[i]
            transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: 0, y: y), size: option.size))
            view.updateLayout(size: view.frame.size, transition: transition)
            y += view.frame.height
            y += 10
        }
        
        if let descriptionView = descriptionView {
            transition.updateFrame(view: descriptionView, frame: descriptionView.centerFrameX(y: button.frame.minY - 10 - descriptionView.frame.height))
        }
        
    }
}

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    entries.append(.custom(sectionId: 0, index: 0, value: .none, identifier: .init("whole"), equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, state: state, toggle: arguments.toggle, action: arguments.action)
    }))
    
    return entries
}


struct ModalAlertData : Equatable {
    struct Description : Equatable {
        var string: String
        var onlyWhenEnabled: Bool
    }
    struct Option : Equatable {
        var string: String
        var isSelected: Bool
        var mandatory: Bool
    }
    var title: String
    var info: String
    var description: Description? = nil
    var ok: String = strings().modalOK
    var options:[Option]
}

struct ModalAlertResult : Equatable {
    var selected: [Int : Bool] = [:]
}

private func ModalAlertController(data: ModalAlertData, completion: @escaping(ModalAlertResult)->Void, cancel:@escaping()->Void = {}) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State(data: data)
    
    var close:(()->Void)? = nil
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }

    let arguments = Arguments(action: {
        let state = stateValue.with { $0 }
        var result:[Int : Bool] = [:]
        for (i, option) in state.data.options.enumerated() {
            result[i] = option.isSelected
        }
        completion(.init(selected: result))
        close?()
    }, toggle: { index in
        updateState { current in
            var current = current
            current.data.options[index].isSelected = !current.data.options[index].isSelected
            return current
        }
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: data.title)
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }
    
    let modalController = InputDataModalController(controller, modalInteractions: nil, size: NSMakeSize(300, 300))
    
    modalController.getModalTheme = {
        return .init(text: theme.colors.text, grayText: theme.colors.grayText, background: .clear, border: .clear, accent: theme.colors.accent, grayForeground: theme.colors.grayBackground)
    }
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: {
        close?()
        cancel()
    })
    
    modalController.closableImpl = {
        cancel()
        return true
    }
    
    controller.didLoaded = { controller, _ in
        controller.tableView.verticalScrollElasticity = .none
    }

    close = { [weak modalController] in
        modalController?.modal?.close()
    }
    
    return modalController
    
}



func showModalAlert(for window: Window, data: ModalAlertData, completion: @escaping(ModalAlertResult)->Void, cancel:@escaping()->Void = {}) {
    showModal(with: ModalAlertController(data: data, completion: completion, cancel: cancel), for: window)
}
