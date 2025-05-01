//
//  StarUsePromoController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 19.09.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation

import Foundation
import TelegramCore
import Postbox
import TGUIKit
import SwiftSignalKit

private final class Arguments {
    let context: AccountContext
    let dismiss: ()->Void
    init(context: AccountContext, dismiss: @escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
    }
}

private struct State : Equatable {

}


private final class RowItem : GeneralRowItem {
    
    struct Option {
        let image: CGImage
        let header: TextViewLayout
        let text: TextViewLayout
        let width: CGFloat
        init(image: CGImage, header: TextViewLayout, text: TextViewLayout, width: CGFloat) {
            self.image = image
            self.header = header
            self.text = text
            self.width = width
            self.header.measure(width: width - 40)
            self.text.measure(width: width - 40)
        }
        var size: NSSize {
            return NSMakeSize(width, header.layoutSize.height + 5 + text.layoutSize.height)
        }
    }
    let context: AccountContext
    let headerLayout: TextViewLayout
    
    let options: [Option]
    let dismiss:()->Void
    init(_ initialSize: NSSize, stableId: AnyHashable, context: AccountContext, dismiss:@escaping()->Void) {
        self.context = context
        self.dismiss = dismiss
        
        let headerText = NSAttributedString.initialize(string: strings().starsPromoHeader, color: theme.colors.text, font: .medium(.title)).mutableCopy() as! NSMutableAttributedString
        
        headerText.append(string: "\n\n")
        headerText.append(string: strings().starsPromoHeaderInfo, color: theme.colors.grayText, font: .normal(.text))
        
                                                                                    
        self.headerLayout = .init(headerText, alignment: .center)
        self.headerLayout.measure(width: initialSize.width - 40)
        
        var options:[Option] = []
        
        options.append(.init(image: NSImage(resource: .iconStarInfoGift).precomposed(theme.colors.text), header: .init(.initialize(string: strings().starsPromoOption1Title, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().starsPromoOption1Info, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))
        
        
        let option2Info = parseMarkdownIntoAttributedString(strings().starsPromoOption2Info, attributes: .init(body: .init(font: .medium(.text), textColor: theme.colors.grayText), link: .init(font: .normal(.text), textColor: theme.colors.link), linkAttribute: { contents in
            return (NSAttributedString.Key.link.rawValue, contents)
        }))
        
        let option2InfoLayout = TextViewLayout(option2Info)
        
        option2InfoLayout.interactions.processURL = { _ in
            showModal(with: Star_AppExamples(context: context), for: context.window)
        }
        
        options.append(.init(image: NSImage(resource: .iconStarInfoBot).precomposed(theme.colors.text), header: .init(.initialize(string: strings().starsPromoOption2Title, color: theme.colors.text, font: .medium(.text))), text: option2InfoLayout, width: initialSize.width - 40))

        
        options.append(.init(image: NSImage(resource: .iconStarInfoLock).precomposed(theme.colors.text), header: .init(.initialize(string:  strings().starsPromoOption3Title, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().starsPromoOption3Info, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        options.append(.init(image: NSImage(resource: .iconStarInfoCash).precomposed(theme.colors.text), header: .init(.initialize(string:  strings().starsPromoOption4Title, color: theme.colors.text, font: .medium(.text))), text: .init(.initialize(string: strings().starsPromoOption4Info, color: theme.colors.grayText, font: .normal(.text))), width: initialSize.width - 40))

        
        self.options = options

        super.init(initialSize, stableId: stableId, viewType: .legacy)
    }
    
    override var height: CGFloat {
        var height: CGFloat = 150
        height += headerLayout.layoutSize.height
        height += 20
        for option in options {
            height += option.size.height
            height += 20
        }
        
        return height
    }
    override func viewClass() -> AnyClass {
        return RowView.self
    }
}

private final class RowView: GeneralContainableRowView {
    
    final class OptionView : View {
        private let imageView = ImageView()
        private let titleView = TextView()
        private let infoView = TextView()
        required init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            addSubview(imageView)
            addSubview(titleView)
            addSubview(infoView)
            
            titleView.userInteractionEnabled = false
            titleView.isSelectable = false
            
            infoView.isSelectable = false
        }
        
        func update(option: RowItem.Option) {
            self.titleView.update(option.header)
            self.infoView.update(option.text)
            self.imageView.image = option.image
            self.imageView.sizeToFit()
        }
        
        override func layout() {
            super.layout()
            titleView.setFrameOrigin(NSMakePoint(40, 0))
            infoView.setFrameOrigin(NSMakePoint(40, titleView.frame.maxY + 5))
        }
 
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    private let starScene: GoldenStarSceneView
    private let headerView = TextView()
        
    
    private let optionsView = View()
    required init(frame frameRect: NSRect) {
        starScene = GoldenStarSceneView(frame: NSMakeRect(0, 0, frameRect.width, 150))
        super.init(frame: frameRect)
        addSubview(starScene)
        addSubview(headerView)

       
        addSubview(optionsView)
        headerView.isSelectable = false

    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        starScene.centerX(y: 0)
        
        
        headerView.centerX(y: starScene.frame.maxY)
        
        optionsView.centerX(y: headerView.frame.maxY + 20)
                
        var y: CGFloat = 0
        for subview in optionsView.subviews {
            subview.centerX(y: y)
            y += subview.frame.height
            y += 20
        }
    }
    
    override var backdorColor: NSColor {
        return .clear
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        guard let item = item as? RowItem else {
            return
        }
        
        headerView.update(item.headerLayout)
        self.starScene.sceneBackground = theme.colors.background
     
    
        
        while optionsView.subviews.count > item.options.count {
            optionsView.subviews.last?.removeFromSuperview()
        }
        while optionsView.subviews.count < item.options.count {
            optionsView.addSubview(OptionView(frame: .zero))
        }
        
        var optionsSize = NSMakeSize(0, 0)
        for (i, option) in item.options.enumerated() {
            let view = optionsView.subviews[i] as! OptionView
            view.update(option: option)
            view.setFrameSize(option.size)
            optionsSize = NSMakeSize(max(option.width, optionsSize.width), option.size.height + optionsSize.height)
            if i != item.options.count - 1 {
                optionsSize.height += 20
            }
        }
        
        optionsView.setFrameSize(optionsSize)
        
        
        needsLayout = true
    }
}


private let _id_header = InputDataIdentifier("_id_header")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_header, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return RowItem(initialSize, stableId: stableId, context: arguments.context, dismiss: arguments.dismiss)
    }))
    
    entries.append(.sectionId(sectionId, type: .customModern(10)))
    sectionId += 1
    
    return entries
}
func StarUsePromoController(context: AccountContext) -> InputDataModalController {

    let actionsDisposable = DisposableSet()

    let initialState = State()
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var close:(()->Void)? = nil

    let arguments = Arguments(context: context, dismiss: {
        close?()
    })
    
    let signal = statePromise.get() |> deliverOnPrepareQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: "")
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    let modalInteractions = ModalInteractions(acceptTitle: strings().fragmentAdsInfoOK, accept: {
        close?()
    }, singleButton: true, customTheme: {
        .init(background: theme.colors.background, grayForeground: theme.colors.background, activeBackground: theme.colors.background, listBackground: theme.colors.background)
    })
    
    
    
    let modalController = InputDataModalController(controller, modalInteractions: modalInteractions, size: NSMakeSize(370, 0))
    
    controller.leftModalHeader = ModalHeaderData(image: theme.icons.modalClose, handler: { [weak modalController] in
        modalController?.close()
    })
    
    close = { [weak modalController] in
        modalController?.close()
    }
    
    controller.getBackgroundColor = {
        theme.colors.background
    }
    
    return modalController
}
