//
//  BusinessIntroController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 13.03.2024.
//  Copyright © 2024 Telegram. All rights reserved.
//

import Foundation
import Cocoa
import TGUIKit
import SwiftSignalKit
import TelegramCore

private final class PreviewRowItem : GeneralRowItem {
    let title: TextViewLayout?
    let message: TextViewLayout?
    let sticker: TelegramMediaFile?
    let context: AccountContext
    init(_ initialSize: NSSize, stableId: AnyHashable, state: State, context: AccountContext, viewType: GeneralViewType) {
        if !state.title.isEmpty {
            self.title = .init(.initialize(string: state.title, color: theme.colors.text, font: .medium(.text)), alignment: .center)
        } else {
            self.title = .init(.initialize(string: strings().businessIntroEmptyTitle, color: theme.colors.text, font: .medium(.text)), alignment: .center)
        }
        if !state.message.isEmpty {
            self.message = .init(.initialize(string: state.message, color: theme.colors.text, font: .normal(.small)), alignment: .center)
        } else {
            self.message = .init(.initialize(string: strings().businessIntroEmptyText, color: theme.colors.text, font: .normal(.text)), alignment: .center)
        }
        self.context = context
        self.sticker = state.sticker
        super.init(initialSize, stableId: stableId, viewType: viewType)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        _ = super.makeSize(width, oldWidth: oldWidth)
        
        self.title?.measure(width: 230)
        self.message?.measure(width: 230)

        return true
    }
    
    override var height: CGFloat {
        var height: CGFloat = 0
        if let title = self.title {
            height += title.layoutSize.height
            height += 5
        }
        if let message = self.message {
            height += message.layoutSize.height
            height += 5
        }
        return height + 120 + viewType.innerInset.top + viewType.innerInset.bottom
    }
    
    override func viewClass() -> AnyClass {
        return PreviewRowView.self
    }
}

private final class PreviewRowView : GeneralContainableRowView {
    
    private let backgroundView = BackgroundView(frame: .zero)
    private let container = View()
    private let stickerView = StickerMediaContentView(frame: NSMakeRect(0, 0, 100, 100))
    private var titleView: TextView?
    private var messageView: TextView?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)
        addSubview(container)
        container.addSubview(stickerView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layout() {
        super.layout()
        
    }
    
    override func updateLayout(size: NSSize, transition: ContainedViewLayoutTransition) {
        super.updateLayout(size: size, transition: transition)
        
        guard let item = item as? PreviewRowItem, let table = item.table else {
            return
        }
        
        transition.updateFrame(view: backgroundView, frame: table.frame.size.bounds)
        transition.updateFrame(view: container, frame: containerView.focus(NSMakeSize(250, containerView.frame.height - item.viewType.innerInset.top - item.viewType.innerInset.bottom)))
        
        var y: CGFloat = 10
        if let titleView {
            transition.updateFrame(view: titleView, frame: titleView.centerFrameX(y: y))
            y += titleView.frame.height + 5
        }
        if let messageView {
            transition.updateFrame(view: messageView, frame: messageView.centerFrameX(y: y))
            y += messageView.frame.height + 5
        }
        transition.updateFrame(view: stickerView, frame: stickerView.centerFrameX(y: y))
    }
    
    override func set(item: TableRowItem, animated: Bool = false) {
        super.set(item: item, animated: animated)
        
        guard let item = item as? PreviewRowItem else {
            return
        }
        
        if let sticker = item.sticker {
            stickerView.update(with: sticker, size: stickerView.frame.size, context: item.context, parent: nil, table: nil)
        }
        
        var y: CGFloat = 10
        
        if let title = item.title {
            let current: TextView
            if let view = self.titleView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                container.addSubview(current)
                self.titleView = current
                current.centerX(y: y)
            }
            y += current.frame.height + 10
            current.update(title)
            current.centerX()
        } else if let view = self.titleView {
            performSubviewRemoval(view, animated: animated)
            self.titleView = nil
        }
        
        if let message = item.message {
            let current: TextView
            if let view = self.messageView {
                current = view
            } else {
                current = TextView()
                current.userInteractionEnabled = false
                current.isSelectable = false
                container.addSubview(current)
                self.messageView = current
                current.centerX(y: y)
            }
            current.update(message)
            current.centerX()
        } else if let view = self.messageView {
            performSubviewRemoval(view, animated: animated)
            self.messageView = nil
        }
        
        
        backgroundView.backgroundMode = theme.backgroundMode
        container.backgroundColor = theme.colors.background
        
        container.layer?.cornerRadius = 10
        
        updateLayout(size: frame.size, transition: animated ? .animated(duration: 0.2, curve: .easeOut) : .immediate)
    }
}

private final class Arguments {
    let context: AccountContext
    let openStickers:()->Void
    let resetSticker:()->Void
    init(context: AccountContext, openStickers:@escaping()->Void, resetSticker:@escaping()->Void) {
        self.context = context
        self.openStickers = openStickers
        self.resetSticker = resetSticker
    }
    
    deinit {
        var bp = 0
        bp += 1
    }
}

private struct State : Equatable {
    var title: String
    var message: String
    var sticker: TelegramMediaFile?
    var random: TelegramMediaFile?
    
    var icon_sticker: CGImage?
    
    var initialIntro: TelegramBusinessIntro?
    
    var mappedIntro: TelegramBusinessIntro? {
        return .init(title: title, text: message, stickerFile: sticker?.fileId == random?.fileId ? nil : sticker)
    }
}

private let _id_preview = InputDataIdentifier("_id_preview")
private let _id_title = InputDataIdentifier("_id_title")
private let _id_message = InputDataIdentifier("_id_message")
private let _id_sticker = InputDataIdentifier("_id_sticker")
private let _id_sticker_reset = InputDataIdentifier("_id_sticker_reset")

private func entries(_ state: State, arguments: Arguments) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessIntroInfo), data: .init(color: theme.colors.listGrayText, viewType: .textTopItem)))
    index += 1
  
    entries.append(.custom(sectionId: sectionId, index: index, value: .none, identifier: _id_preview, equatable: .init(state), comparable: nil, item: { initialSize, stableId in
        return PreviewRowItem(initialSize, stableId: stableId, state: state, context: arguments.context, viewType: .firstItem)
    }))
    
    let intro_title_length_limit = arguments.context.appConfiguration.getGeneralValue("intro_title_length_limit", orElse: 32)
    let intro_description_length_limit = arguments.context.appConfiguration.getGeneralValue("intro_description_length_limit", orElse: 70)
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.title), error: nil, identifier: _id_title, mode: .plain, data: .init(viewType: .innerItem), placeholder: nil, inputPlaceholder: strings().businessIntroPlaceholderTitle, filter: { $0 }, limit: intro_title_length_limit))
    
    entries.append(.input(sectionId: sectionId, index: index, value: .string(state.message), error: nil, identifier: _id_message, mode: .plain, data: .init(viewType: .innerItem), placeholder: nil, inputPlaceholder: strings().businessIntroPlaceholderText, filter: { $0 }, limit: intro_description_length_limit))

    let type: GeneralInteractedType
    if state.sticker != state.random, let image = state.icon_sticker {
        type = .imageContext(image, "")
    } else {
        type = .context(strings().businessIntroStickerRandom)
    }
    entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sticker, data: .init(name: strings().businessIntroStickerText, color: theme.colors.text, type: type, viewType: .lastItem, action: arguments.openStickers)))
    // entries
   
    
    entries.append(.desc(sectionId: sectionId, index: index, text: .plain(strings().businessIntroStickerInfo), data: .init(color: theme.colors.listGrayText, viewType: .textBottomItem)))
    
    
    
    if state.sticker != state.random || !state.title.isEmpty || !state.message.isEmpty {
        entries.append(.sectionId(sectionId, type: .normal))
        sectionId += 1
        entries.append(.general(sectionId: sectionId, index: index, value: .none, error: nil, identifier: _id_sticker_reset, data: .init(name: strings().businessIntroReset, color: theme.colors.redUI, type: .none, viewType: .singleItem, action: arguments.resetSticker)))
    }
    
    entries.append(.sectionId(sectionId, type: .normal))
    sectionId += 1
    
    return entries
}

func BusinessIntroController(context: AccountContext) -> InputDataController {
    
    let actionsDisposable = DisposableSet()
    
    let initialState = State(title: "", message: "")
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((State) -> State) -> Void = { f in
        statePromise.set(stateValue.modify (f))
    }
    
    var getController:(()->InputDataController?)? = nil
    
    let randomSticker: Signal<FoundStickerItem?, NoError> = .single(nil) |> then(context.engine.stickers.randomGreetingSticker())
    
    actionsDisposable.add(combineLatest(randomSticker, context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BusinessIntro(id: context.peerId))).start(next: { item, intro in
        updateState { current in
            var current = current
            switch intro {
            case let .known(intro):
                current.sticker = intro?.stickerFile ?? item?.file
                current.random = item?.file
                current.title = intro?.title ?? ""
                current.message = intro?.text ?? ""
            case .unknown:
                current.sticker = item?.file
                current.random = item?.file
            }
            return current
        }
    }))
    
    var sticker: TelegramMediaFile?
    var sticker_layer: InlineStickerItemLayer?
    actionsDisposable.add(statePromise.get().start(next: { state in
        if state.sticker != sticker, let current = state.sticker {
            DispatchQueue.main.async {
                sticker_layer = InlineStickerItemLayer(account: context.account, file: current, size: NSMakeSize(25, 25))
                sticker_layer?.isPlayable = true
                
                sticker_layer?.contentDidUpdate = { image in
                    updateState { current in
                        var current = current
                        current.icon_sticker = image
                        return current
                    }
                }
            }
        }
        sticker = state.sticker
    }))
    
    
    let stickers = NStickersViewController(context)
    
    let interactions = EntertainmentInteractions(.stickers, peerId: context.peerId)
    
    interactions.sendSticker = { [weak stickers] sticker, _, _, fromRect in
        updateState { current in
            var current = current
            current.sticker = sticker
            return current
        }
        stickers?.closePopover()
    }
    stickers.update(with: interactions, chatInteraction: .init(chatLocation: .peer(context.peerId), context: context))
    
    let arguments = Arguments(context: context, openStickers: { [weak stickers] in
        guard let controller = getController?(), let stickers = stickers else {
            return
        }
        let view = controller.tableView.item(stableId: InputDataEntryId.general(_id_sticker))?.view as? GeneralInteractedRowView
        
        if let control = view?.textView {
            showPopover(for: control, with: stickers, edge: .maxY)
        }
    }, resetSticker: {
        updateState { current in
            var current = current
            current.sticker = current.random
            current.title = ""
            current.message = ""
            return current
        }
        let state = stateValue.with { $0 }
        if state.initialIntro != state.mappedIntro {
            _ = context.engine.accountData.updateBusinessIntro(intro: state.mappedIntro).startStandalone()
            showModalText(for: context.window, text: strings().businessUpdated)
        }
    })
    
    let signal = statePromise.get() |> deliverOnMainQueue |> map { state in
        return InputDataSignalValue(entries: entries(state, arguments: arguments))
    }
    
    let controller = InputDataController(dataSignal: signal, title: strings().businessIntroTitle, identifier: "business_intro")
    
    controller.updateDatas = { data in
        updateState { current in
            var current = current
            current.title = data[_id_title]?.stringValue ?? ""
            current.message = data[_id_message]?.stringValue ?? ""
            return current
        }
        return .none
    }
    
    controller.validateData = { _ in
        let state = stateValue.with { $0}
        _ = context.engine.accountData.updateBusinessIntro(intro: state.mappedIntro).startStandalone()
        showModalText(for: context.window, text: strings().businessUpdated)
        return .success(.navigationBack)
        
    }
    
    controller.updateDoneValue = { data in
        return { f in
            if stateValue.with({ $0.mappedIntro != $0.initialIntro }) {
                f(.enabled(strings().navigationDone))
            } else {
                f(.disabled(strings().navigationDone))
            }
        }
    }
        
    controller.contextObject = stickers
    
    getController = { [weak controller] in
        return controller
    }
    
    controller.onDeinit = {
        actionsDisposable.dispose()
    }

    
    return controller
    
}
